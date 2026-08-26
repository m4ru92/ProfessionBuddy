----------------------------------------------------------------------
-- ProfessionBuddy  --  Orders.lua
-- Local data model + state machine for crafting orders.
--
-- This is the LOCAL spine. It holds order records, enforces the
-- status lifecycle, and answers queries the UI renders from. It does
-- NO networking -- the (blocked) backend Comm layer will call into
-- Create/Accept/Decline/... when messages arrive over AceComm.
--
-- Because ordering from your own alts is allowed, the whole model is
-- exercisable solo: create an order from one character to another,
-- relog to the other character, and act on it.
--
-- Lifecycle:
--   Pending -> Accepted -> Crafted -> Completed
--      |          |
--      +-> Declined (crafter, pending only)
--      |
--      +----------+-> Cancelled (requester, pending/accepted only)
--
-- Transition ownership:
--   requester: Create, Cancel, Confirm received (-> Completed)
--   crafter:   Accept, Decline, Mark Crafted, Mark delivered (-> Completed)
--
-- completedBy records which side closed it ("requester" = confirmed
-- receipt, the gold standard; "crafter" = self-marked delivered, the
-- escape hatch). No escrow exists, so no time delay is needed.
----------------------------------------------------------------------

local addon = ProfBuddy
local Orders = addon:NewModule("Orders")

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
local STATUS = {
    PENDING   = "pending",
    ACCEPTED  = "accepted",
    CRAFTED   = "crafted",
    COMPLETED = "completed",
    DECLINED  = "declined",
    CANCELLED = "cancelled",
    EXPIRED   = "expired",
}
Orders.STATUS = STATUS

-- Terminal states never appear in the active queue (they live in History)
local TERMINAL = {
    [STATUS.COMPLETED] = true,
    [STATUS.DECLINED]  = true,
    [STATUS.CANCELLED] = true,
    [STATUS.EXPIRED]   = true,
}
Orders.TERMINAL = TERMINAL

-- Statuses each side may legally announce over the wire. NOT from-state-strict
-- (rank monotonicity in ApplyRemoteStatus handles ordering, and a from-state
-- check could wedge an order when queued messages arrive out of order). This
-- only stops a peer acting the WRONG ROLE (a crafter "cancelling", which is
-- requester-only).
local ROLE_STATUS = {
    requester = { cancelled = true, completed = true },
    crafter   = { accepted = true, declined = true, crafted = true, completed = true },
}

local MAT_RESP = {
    REQUESTER = "requester",  -- order provided
    CRAFTER   = "crafter",    -- crafter provided
    SPLIT     = "split",      -- informal social contract
}
Orders.MAT_RESP = MAT_RESP

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
function Orders:Init()
    -- Core.lua initializes these in ADDON_LOADED, but guard anyway
    addon.db.orders = addon.db.orders or {}
    if addon.db.orderSeq == nil then addon.db.orderSeq = 0 end
    -- Persisted outbox for order messages not yet delivered to an
    -- offline counterparty (auto-resent when they next come online).
    addon.db.orderOutbox = addon.db.orderOutbox or {}
    self:ExpireStale()
    self:PruneHistory()
end

----------------------------------------------------------------------
-- ID generation
-- requesterKey + sequence is unique per requester, and globally
-- unique once combined with the requester key -- so when networking
-- lands, the requester mints the ID and it won't collide.
----------------------------------------------------------------------
function Orders:_NewID()
    addon.db.orderSeq = (addon.db.orderSeq or 0) + 1
    return addon:PlayerKey() .. "-" .. addon.db.orderSeq
end

----------------------------------------------------------------------
-- Role helpers
----------------------------------------------------------------------
-- Which side is the current character on this order? "requester",
-- "crafter", or nil (neither -- e.g. an order between two of your alts
-- viewed while logged into a third character).
function Orders:RoleFor(order)
    local me = addon:PlayerKey()
    if order.crafter == me then return "crafter" end
    if order.requester == me then return "requester" end
    return nil
end

local function isActor(order, side)
    return Orders:RoleFor(order) == side
end

----------------------------------------------------------------------
-- Create (requester action)
-- params: crafter (charKey), item { id, name, profession }, quantity,
--         matResponsibility, note (optional)
----------------------------------------------------------------------
function Orders:Create(params)
    if not params or not params.crafter or not params.item then
        return nil, "missing required fields"
    end

    local id = self:_NewID()
    local order = {
        id        = id,
        requester = addon:PlayerKey(),
        crafter   = params.crafter,
        item = {
            id         = params.item.id,
            name       = params.item.name,
            profession = params.item.profession,
        },
        quantity          = params.quantity or 1,
        matResponsibility = params.matResponsibility or MAT_RESP.REQUESTER,
        note              = params.note,
        status            = STATUS.PENDING,
        completedBy       = nil,
        dismissed         = false,
        createdAt         = time(),
        updatedAt         = time(),
    }
    addon.db.orders[id] = order
    return order
end

----------------------------------------------------------------------
-- Transitions
-- Each enforces (a) the current status is legal for the move and
-- (b) the current character is the correct actor. Returns order, or
-- nil + reason.
----------------------------------------------------------------------
local function setStatus(order, newStatus)
    order.status = newStatus
    order.updatedAt = time()
end

function Orders:Accept(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.PENDING then return nil, "order is not pending" end
    if not isActor(o, "crafter") then return nil, "only the crafter can accept" end
    setStatus(o, STATUS.ACCEPTED)
    return o
end

function Orders:Decline(id, reason)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.PENDING then return nil, "decline is only allowed while pending" end
    if not isActor(o, "crafter") then return nil, "only the crafter can decline" end
    -- Optional reason (trusted local text; capped). Sanitized on the requester's
    -- side when received (ApplyRemoteStatus). Blank/whitespace clears it.
    if type(reason) == "string" then
        reason = strtrim(reason)
        o.declineReason = (#reason > 0) and reason:sub(1, 150) or nil
    end
    setStatus(o, STATUS.DECLINED)
    return o
end

function Orders:MarkCrafted(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.ACCEPTED then return nil, "order is not accepted" end
    if not isActor(o, "crafter") then return nil, "only the crafter can mark crafted" end
    setStatus(o, STATUS.CRAFTED)
    return o
end

function Orders:Cancel(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.PENDING and o.status ~= STATUS.ACCEPTED then
        return nil, "cancel is only allowed while pending or accepted"
    end
    if not isActor(o, "requester") then return nil, "only the requester can cancel" end
    setStatus(o, STATUS.CANCELLED)
    return o
end

-- Requester confirms receipt: the gold-standard completion.
function Orders:ConfirmReceived(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.CRAFTED then return nil, "order is not crafted yet" end
    if not isActor(o, "requester") then return nil, "only the requester can confirm receipt" end
    o.completedBy = "requester"
    setStatus(o, STATUS.COMPLETED)
    return o
end

-- Crafter escape hatch: closes the order if the requester ghosts.
-- Weaker evidence than a requester confirmation (completedBy="crafter").
function Orders:MarkDelivered(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.CRAFTED then return nil, "order is not crafted yet" end
    if not isActor(o, "crafter") then return nil, "only the crafter can mark delivered" end
    o.completedBy = "crafter"
    setStatus(o, STATUS.COMPLETED)
    return o
end

-- Remove a terminal order from the History view. Kept as a flag (not
-- hard-deleted) so completedBy survives for any future stats feature.
function Orders:Dismiss(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if not TERMINAL[o.status] then return nil, "only terminal orders can be dismissed" end
    o.dismissed = true
    o.updatedAt = time()
    return o
end

-- Dismiss every terminal order in one History section for the current
-- character. side = "incoming" (you were the crafter) or "outgoing"
-- (you were the requester). Non-destructive (sets dismissed, keeps the
-- record). Returns how many were cleared.
function Orders:DismissHistorySide(side)
    local ids = {}
    for id, o in pairs(addon.db.orders or {}) do
        if not o.dismissed and TERMINAL[o.status] then
            local role = self:RoleFor(o)
            if (side == "incoming" and role == "crafter")
            or (side == "outgoing" and role == "requester") then
                table.insert(ids, id)
            end
        end
    end
    for _, id in ipairs(ids) do self:Dismiss(id) end
    return #ids
end

-- Retention: cap stored history so orders never grow unbounded. Keeps, per
-- character key, the most recent `limit` TERMINAL orders that key is party to,
-- and HARD-DELETES any terminal order beyond the cap for BOTH of its parties.
-- Active (non-terminal) orders are never touched. Runs at login (Init). Unlike
-- Dismiss (a hide flag), this permanently removes the record to bound the DB.
function Orders:PruneHistory(limit)
    limit = limit or (addon.db.settings and addon.db.settings.orderHistoryLimit) or 50
    if limit <= 0 then return 0 end
    local byKey = {}
    for _, o in pairs(addon.db.orders or {}) do
        if TERMINAL[o.status] then
            byKey[o.requester] = byKey[o.requester] or {}; table.insert(byKey[o.requester], o)
            -- Skip the duplicate insert for a self-order (own-alt order where
            -- requester == crafter) so it isn't counted twice toward the cap.
            if o.crafter ~= o.requester then
                byKey[o.crafter] = byKey[o.crafter] or {}; table.insert(byKey[o.crafter], o)
            end
        end
    end
    local keep = {}
    for _, list in pairs(byKey) do
        table.sort(list, function(a, b) return a.updatedAt > b.updatedAt end)
        for i = 1, math.min(#list, limit) do keep[list[i].id] = true end
    end
    local removed = 0
    for id, o in pairs(addon.db.orders or {}) do
        if TERMINAL[o.status] and not keep[id] then
            addon.db.orders[id] = nil
            removed = removed + 1
        end
    end
    return removed
end

-- Auto-expire stale PENDING orders. Deterministic: computed purely from
-- createdAt + the fixed threshold, so both parties expire the same order at the
-- same wall-clock independently -- no message needed, no divergence (and the
-- login sweep runs before any UI interaction, so a stale order can't be acted
-- on after its deadline). Only pending (unanswered) orders expire; an accepted
-- order (crafter committed) never does. Runs at login (Init). days <= 0 disables.
function Orders:ExpireStale(days)
    days = days or (addon.db.settings and addon.db.settings.orderExpiryDays) or 14
    if days <= 0 then return 0 end
    local cutoff = time() - days * 86400
    local n = 0
    for _, o in pairs(addon.db.orders or {}) do
        if o.status == STATUS.PENDING and (o.createdAt or 0) <= cutoff then
            setStatus(o, STATUS.EXPIRED)
            n = n + 1
        end
    end
    return n
end

----------------------------------------------------------------------
-- Legal actions for (current character role x order state).
-- Drives which buttons a row shows. Returns a list of action keys.
----------------------------------------------------------------------
function Orders:LegalActions(order)
    local role = self:RoleFor(order)
    if not role then return {} end

    if TERMINAL[order.status] then
        return { "dismiss" }
    end

    if role == "crafter" then
        if order.status == STATUS.PENDING  then return { "accept", "decline" } end
        if order.status == STATUS.ACCEPTED then return { "markCrafted" } end
        if order.status == STATUS.CRAFTED  then return { "markDelivered" } end
    elseif role == "requester" then
        if order.status == STATUS.PENDING  then return { "cancel" } end
        if order.status == STATUS.ACCEPTED then return { "cancel" } end
        if order.status == STATUS.CRAFTED  then return { "confirmReceived" } end
    end
    return {}
end

----------------------------------------------------------------------
-- Queries (scoped to the current character)
-- A character only sees orders it is party to. Orders to your other
-- alts surface when you log into those alts.
----------------------------------------------------------------------
local function collect(filter)
    local me = addon:PlayerKey()
    local out = {}
    for _, o in pairs(addon.db.orders or {}) do
        if not o.dismissed and filter(o, me) then
            table.insert(out, o)
        end
    end
    return out
end

-- Active requests TO you (you are the crafter), oldest first.
function Orders:GetIncoming()
    local out = collect(function(o, me)
        return o.crafter == me and not TERMINAL[o.status]
    end)
    table.sort(out, function(a, b) return a.createdAt < b.createdAt end)
    return out
end

-- Your active orders (you are the requester), oldest first.
function Orders:GetOutgoing()
    local out = collect(function(o, me)
        return o.requester == me and not TERMINAL[o.status]
    end)
    table.sort(out, function(a, b) return a.createdAt < b.createdAt end)
    return out
end

-- Terminal orders you are party to (either side), most recent first.
function Orders:GetHistory()
    local out = collect(function(o, me)
        return (o.requester == me or o.crafter == me) and TERMINAL[o.status]
    end)
    local oldestFirst = addon.db.settings and addon.db.settings.orderHistorySortOldest
    table.sort(out, function(a, b)
        if oldestFirst then return a.updatedAt < b.updatedAt end
        return a.updatedAt > b.updatedAt
    end)
    return out
end

-- Count of items needing YOUR action: incoming Pending (respond to a
-- request) + your outgoing Crafted (confirm receipt). Drives the badge.
function Orders:GetActionableCount()
    local me = addon:PlayerKey()
    local n = 0
    for _, o in pairs(addon.db.orders or {}) do
        if not o.dismissed then
            if o.crafter == me and o.status == STATUS.PENDING then
                n = n + 1
            elseif o.requester == me and o.status == STATUS.CRAFTED then
                n = n + 1
            end
        end
    end
    return n
end

----------------------------------------------------------------------
-- Remote application (networking backend, Phase 1)
-- The authoritative actor already validated the move on their own
-- client, so these mirror the result locally WITHOUT the actor/state
-- guards the local-action transitions enforce. Comm.lua calls these
-- when ORDER_NEW / ORDER_UPDATE messages arrive.
----------------------------------------------------------------------

-- Status ordering for out-of-order / duplicate detection. Terminal
-- states share the top rank and never regress.
local STATUS_RANK = {
    pending   = 0,
    accepted  = 1,
    crafted   = 2,
    completed = 3,
    declined  = 3,
    cancelled = 3,
    expired   = 3,
}

local VALID_MATRESP = { requester = true, crafter = true, split = true }

-- Neutralize WoW escape codes (|H hyperlink, |T texture, |c color) in a
-- remote string and cap its length, so a peer can't inject clickable
-- links / textures / colored text into our chat or tooltips.
local function sanitize(s, maxlen)
    if type(s) ~= "string" then return nil end
    s = s:gsub("|", "||")
    if maxlen and #s > maxlen then s = s:sub(1, maxlen) end
    return s
end

-- Clamp a remote timestamp to a sane window. A forged huge value would make
-- every future legit update look "stale" (freeze attack) and break date sorting
-- in History.
local function clampTime(v)
    local now = time()
    v = tonumber(v) or now
    if v > now + 300 then v = now + 300 end
    if v < 0 then v = 0 end
    return v
end

-- Store a full order record received from the counterparty (ORDER_NEW).
-- Builds a CLEAN copy field-by-field -- never stores the raw attacker-
-- influenced table by reference -- validating + sanitizing every field.
-- Returns (order, applied); applied is false for a duplicate.
function Orders:UpsertFromRemote(remote)
    if type(remote) ~= "table" then return nil, "bad order record" end
    local id = remote.id
    if type(id) ~= "string" or #id == 0 or #id > 64 then return nil, "bad id" end
    if not STATUS_RANK[remote.status] then return nil, "bad status" end
    if type(remote.item) ~= "table" then return nil, "bad item" end
    if addon.db.orders[id] then
        return addon.db.orders[id], false  -- duplicate ORDER_NEW
    end
    local order = {
        id          = id,
        requester   = sanitize(remote.requester, 64) or "?",
        crafter     = sanitize(remote.crafter, 64) or "?",
        item = {
            id         = tonumber(remote.item.id) or 0,
            name       = sanitize(remote.item.name, 80) or "?",
            profession = sanitize(remote.item.profession, 40) or "?",
        },
        quantity          = math.max(1, math.min(999, tonumber(remote.quantity) or 1)),
        matResponsibility = VALID_MATRESP[remote.matResponsibility] and remote.matResponsibility or "requester",
        note              = remote.note and sanitize(remote.note, 200) or nil,
        status            = remote.status,
        completedBy       = (remote.completedBy == "requester" or remote.completedBy == "crafter") and remote.completedBy or nil,
        dismissed         = false,
        createdAt         = clampTime(remote.createdAt),
        updatedAt         = clampTime(remote.updatedAt),
    }
    addon.db.orders[id] = order
    return order, true
end

-- Apply a remote status change to an existing order (ORDER_UPDATE).
-- Returns (order, applied): order is nil if we have no local copy;
-- applied is false for a duplicate / stale / out-of-order message
-- (the caller still acks it but skips re-notifying). Terminal orders
-- never regress.
function Orders:ApplyRemoteStatus(id, newStatus, completedBy, updatedAt, declineReason, senderRole)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if not STATUS_RANK[newStatus] then return nil, "bad status" end
    -- Role scoping: the sender may only announce statuses that belong to their
    -- side, and completedBy is DERIVED from who sent the close, never read off
    -- the wire (else a crafter could forge "requester confirmed receipt").
    if senderRole then
        local allowed = ROLE_STATUS[senderRole]
        if not (allowed and allowed[newStatus]) then return o, false end
        completedBy = (newStatus == STATUS.COMPLETED) and senderRole or nil
    end
    if completedBy ~= nil and completedBy ~= "requester" and completedBy ~= "crafter" then
        completedBy = nil
    end
    -- Clamp the remote timestamp to a sane window so a forged huge value
    -- can't make every future legit update look "stale" (freeze attack).
    local now = time()
    local newU = tonumber(updatedAt) or now
    if newU > now + 300 then newU = now + 300 end
    if newU < 0 then newU = 0 end
    local curRank = STATUS_RANK[o.status] or 0
    local newRank = STATUS_RANK[newStatus] or 0
    local curU    = o.updatedAt or 0
    if curRank >= 3 then return o, false end          -- already terminal
    if newU < curU then return o, false end           -- stale
    if newU == curU and newRank <= curRank then       -- duplicate
        return o, false
    end
    o.status = newStatus
    if completedBy ~= nil then o.completedBy = completedBy end
    if newStatus == STATUS.DECLINED and declineReason ~= nil then
        o.declineReason = sanitize(declineReason, 150)
    end
    o.updatedAt = newU
    return o, true
end
