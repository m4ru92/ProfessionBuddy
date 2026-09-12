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
    OPEN      = "open",       -- posted to the guild board, no crafter yet (pre-pending)
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
    REQUESTER = "requester",  -- requester provided
    CRAFTER   = "crafter",    -- crafter provided
    SPLIT     = "split",      -- informal social contract
}
Orders.MAT_RESP = MAT_RESP

-- ONE quantity cap for every path that mints or admits an order: Create,
-- CreateOpen, the board composer (which reads Orders.MAX_QTY), and the two
-- remote-ingress clamps (UpsertFromRemote below, HandleOrderOpen in Comm.lua).
-- Three different caps used to let a claimed order disagree with its own post.
Orders.MAX_QTY = 999
local MAX_QTY = Orders.MAX_QTY

local function clampQty(v)
    v = tonumber(v) or 1
    if v ~= v then return 1 end                 -- NaN
    v = math.floor(v)
    if v < 1 then return 1 end
    if v > MAX_QTY then return MAX_QTY end
    return v
end

-- Canonical storage form of a character key. Anything NormKey cannot parse is
-- kept verbatim so a field is never lost to normalization.
local function canonKey(key)
    if key == nil then return nil end
    return addon:NormKey(key) or key
end

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
    addon.db.orderBoard = addon.db.orderBoard or {}
    -- Comm is not ready at ADDON_LOADED (and the guild roster has not loaded),
    -- so opens expired here are parked; the login sweep's ExpireStale hands them
    -- back and broadcasts ORDER_CLOSED{expired} for each.
    local _, expiredOpen = self:ExpireStale()
    self._pendingExpiredOpens = (#expiredOpen > 0) and expiredOpen or nil
    self:SweepBoard()
    self:SweepOutbox()
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
    -- SameKey, not ==: a record written before schema 2 (or handed to us by a
    -- peer) can spell the realm differently, and a raw compare would make the
    -- order invisible to the very character it belongs to.
    if addon:SameKey(order.crafter, me) then return "crafter" end
    if addon:SameKey(order.requester, me) then return "requester" end
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
        crafter   = canonKey(params.crafter),
        item = {
            id         = params.item.id,
            name       = params.item.name,
            profession = params.item.profession,
        },
        quantity          = clampQty(params.quantity),
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

-- Post an open order to the guild board: same shape as Create but with no
-- crafter yet. Status is OPEN until a guildmate's claim assigns it.
function Orders:CreateOpen(params)
    if not params or not params.item then
        return nil, "missing required fields"
    end
    local id = self:_NewID()
    local order = {
        id        = id,
        requester = addon:PlayerKey(),
        crafter   = nil,
        item = {
            id         = params.item.id,
            name       = params.item.name,
            profession = params.item.profession,
        },
        quantity          = clampQty(params.quantity),
        matResponsibility = params.matResponsibility or MAT_RESP.REQUESTER,
        note              = params.note,
        status            = STATUS.OPEN,
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

-- Requester side: a guildmate's claim on my open order wins. Assign them as the
-- crafter and move the order into the normal directed flow at ACCEPTED (claiming
-- == accepting). The requester then hands off via the existing ORDER_NEW path.
function Orders:AssignFromClaim(id, crafterKey)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.OPEN then return nil, "order is not open" end
    if not addon:SameKey(o.requester, addon:PlayerKey()) then return nil, "not my order to assign" end
    if type(crafterKey) ~= "string" or crafterKey == "" then return nil, "no crafter" end
    -- Canonical key, so the claimer's own client recognizes itself as the
    -- crafter when the handoff ORDER_NEW lands (a realm-spelled key does not).
    o.crafter = canonKey(crafterKey)
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
    -- OPEN is cancellable too: pulling your own post off the guild board before
    -- anyone claims it (the board UI broadcasts ORDER_CLOSED "cancelled" after).
    if o.status ~= STATUS.OPEN and o.status ~= STATUS.PENDING and o.status ~= STATUS.ACCEPTED then
        return nil, "cancel is only allowed while open, pending, or accepted"
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

-- Is this key one of MY characters? The retention cap is "per character of
-- mine"; grouping under remote counterparties too would multiply the stored set
-- by the number of crafting partners instead of capping it.
local function isLocalCharacter(key)
    if type(key) ~= "string" or key == "" then return false end
    if addon:SameKey(key, addon:PlayerKey()) then return true end
    local rec = addon.db.characters and addon.db.characters[canonKey(key)]
    return rec ~= nil and not rec.isRemote
end

-- Statuses PruneHistory must never delete even though it walks every order.
-- OPEN is live on the guild board and is ended by ExpireStale, not by history
-- retention; it is named here so it can never be swept in as "old enough".
local PRUNE_IMMUNE = { [STATUS.OPEN] = true }

-- Retention: cap stored history so orders never grow unbounded. Keeps, per
-- character OF MINE, the most recent `limit` TERMINAL orders that character is
-- party to, and HARD-DELETES any terminal order beyond the cap. Active
-- (non-terminal) orders are never touched. Runs at login (Init). Unlike Dismiss
-- (a hide flag), this permanently removes the record to bound the DB.
function Orders:PruneHistory(limit)
    limit = limit or (addon.db.settings and addon.db.settings.orderHistoryLimit) or 50
    if limit <= 0 then return 0 end
    local byKey = {}
    local function group(key, o)
        local k = canonKey(key)
        byKey[k] = byKey[k] or {}
        table.insert(byKey[k], o)
    end
    for _, o in pairs(addon.db.orders or {}) do
        if TERMINAL[o.status] and not PRUNE_IMMUNE[o.status] then
            -- A cancelled OPEN post is terminal with NO crafter, so only group it
            -- under the requester. Otherwise group under the crafter too, skipping
            -- a self-order (requester == crafter) so it isn't counted twice.
            local grouped = false
            if isLocalCharacter(o.requester) then group(o.requester, o); grouped = true end
            if o.crafter and not addon:SameKey(o.crafter, o.requester)
               and isLocalCharacter(o.crafter) then group(o.crafter, o); grouped = true end
            -- Neither side resolves to one of my characters (an alt deleted from
            -- db.characters, say). Group it under this character rather than let
            -- it fall out of every group and be deleted unseen.
            if not grouped then group(addon:PlayerKey(), o) end
        end
    end
    local keep = {}
    for _, list in pairs(byKey) do
        table.sort(list, function(a, b) return a.updatedAt > b.updatedAt end)
        for i = 1, math.min(#list, limit) do keep[list[i].id] = true end
    end
    local removed = 0
    for id, o in pairs(addon.db.orders or {}) do
        if TERMINAL[o.status] and not PRUNE_IMMUNE[o.status] and not keep[id] then
            addon.db.orders[id] = nil
            removed = removed + 1
        end
    end
    return removed
end

-- The shared expiry window, in days. 0 (or less) means expiry is off.
local function expiryDays(days)
    return days or (addon.db.settings and addon.db.settings.orderExpiryDays) or 14
end

-- Auto-expire stale PENDING and OPEN orders. Deterministic: computed purely from
-- createdAt + the fixed threshold, so both parties expire the same order at the
-- same wall-clock independently -- no message needed, no divergence (and the
-- login sweep runs before any UI interaction, so a stale order can't be acted
-- on after its deadline). An ACCEPTED order (crafter committed) never expires.
-- Runs at login (Init) and hourly. days <= 0 disables.
--
-- Returns (n, expiredOpenIds): how many orders expired, and the ids of the OPEN
-- board posts among them, which the caller broadcasts as ORDER_CLOSED{expired}
-- so every guildmate's board drops them. Any ids parked by the Init sweep (Comm
-- is not ready that early) are handed back on the next call.
function Orders:ExpireStale(days)
    days = expiryDays(days)
    local expiredOpen = self._pendingExpiredOpens or {}
    self._pendingExpiredOpens = nil
    if days <= 0 then return 0, expiredOpen end
    local cutoff = time() - days * 86400
    local n = 0
    for _, o in pairs(addon.db.orders or {}) do
        -- OPEN expires too: an abandoned board post is not terminal, so history
        -- retention never reclaims it and it would render forever.
        if (o.status == STATUS.PENDING or o.status == STATUS.OPEN)
           and (o.createdAt or 0) <= cutoff then
            local wasOpen = (o.status == STATUS.OPEN)
            setStatus(o, STATUS.EXPIRED)
            if wasOpen then table.insert(expiredOpen, o.id) end
            n = n + 1
        end
    end
    return n, expiredOpen
end

-- Drop guildmates' board posts older than the expiry window. The board is
-- written by any guildmate and its only other remover is a live ORDER_CLOSED,
-- which a poster who logs off (or a guildmate who was offline at the time)
-- never sends, so without this sweep db.orderBoard only grows. Returns the
-- count removed. days <= 0 disables expiry, exactly like ExpireStale.
function Orders:SweepBoard(days)
    days = expiryDays(days)
    if days <= 0 then return 0 end
    local board = addon.db.orderBoard
    if type(board) ~= "table" then return 0 end
    local cutoff = time() - days * 86400
    local n = 0
    for id, e in pairs(board) do
        if type(e) ~= "table" or (tonumber(e.postedAt) or 0) <= cutoff then
            board[id] = nil
            n = n + 1
        end
    end
    return n
end

-- Drop undeliverable order messages older than the expiry window. An entry for
-- a player who has quit the game is otherwise retried forever. Entries queued
-- by an older build carry no stamp, so stamp them on first sight and let them
-- age from there rather than deleting messages that may still be wanted.
function Orders:SweepOutbox(days)
    days = expiryDays(days)
    if days <= 0 then return 0 end
    local ob = addon.db.orderOutbox
    if type(ob) ~= "table" then return 0 end
    local now = time()
    local cutoff = now - days * 86400
    local n = 0
    for token, entry in pairs(ob) do
        if type(entry) ~= "table" then
            ob[token] = nil
            n = n + 1
        elseif tonumber(entry.queuedAt) == nil then
            entry.queuedAt = now
        elseif entry.queuedAt <= cutoff then
            ob[token] = nil
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
        return addon:SameKey(o.crafter, me) and not TERMINAL[o.status]
    end)
    table.sort(out, function(a, b) return a.createdAt < b.createdAt end)
    return out
end

-- Your active orders (you are the requester), oldest first. OPEN orders are
-- excluded here: they have no crafter yet and live on the Guild Board, not the
-- Direct queue (they rejoin this list as ACCEPTED once a claim assigns a crafter).
function Orders:GetOutgoing()
    local out = collect(function(o, me)
        return addon:SameKey(o.requester, me) and o.status ~= STATUS.OPEN and not TERMINAL[o.status]
    end)
    table.sort(out, function(a, b) return a.createdAt < b.createdAt end)
    return out
end

-- Your own open orders posted to the guild board (requester = you, no crafter
-- yet), oldest first. Board-only; the Direct queue never shows these.
function Orders:GetMyOpen()
    local out = collect(function(o, me)
        return addon:SameKey(o.requester, me) and o.status == STATUS.OPEN
    end)
    table.sort(out, function(a, b) return a.createdAt < b.createdAt end)
    return out
end

-- Terminal orders you are party to (either side), most recent first.
function Orders:GetHistory()
    local out = collect(function(o, me)
        return (addon:SameKey(o.requester, me) or addon:SameKey(o.crafter, me)) and TERMINAL[o.status]
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
            if addon:SameKey(o.crafter, me) and o.status == STATUS.PENDING then
                n = n + 1
            elseif addon:SameKey(o.requester, me) and o.status == STATUS.CRAFTED then
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
-- Control characters first (a remote name carrying \n splits the chat line the
-- panel prints into what looks like a second system message), then TRUNCATE,
-- then escape pipes: truncating after the escape can cut a "||" in half and
-- leave a dangling "|" that swallows whatever follows it. Same order as Comm's
-- sanStr, so the two ingress paths cannot drift apart again.
local function sanitize(s, maxlen)
    if type(s) ~= "string" then return nil end
    s = s:gsub("%c", " ")
    if maxlen and #s > maxlen then s = s:sub(1, maxlen) end
    return (s:gsub("|", "||"))
end

-- Clamp a remote timestamp to a sane window. A forged huge value would make
-- every future legit update look "stale" (freeze attack) and break date sorting
-- in History.
local function clampTime(v)
    local now = time()
    v = tonumber(v)
    -- NaN is reachable over the wire and every comparison against it is false,
    -- so it slips past both clamps below; a NaN createdAt makes the record
    -- unexpirable (ExpireStale's `<= cutoff` is false) and permanent.
    if not v or v ~= v then return now end
    if v > now + 300 then v = now + 300 end
    if v < 0 then v = 0 end
    return v
end

-- A remote item id: positive integer in range, or nil (0 / NaN / junk means
-- "absent"). Same shape as Comm's sanID, which the board ingress path uses.
local function clampItemID(v)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    v = math.floor(v)
    if v < 1 or v > 10 ^ 7 then return nil end
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
        -- Sanitize first (a remote string can carry escape codes), THEN
        -- canonicalize, so the stored keys match the ones RoleFor compares.
        requester   = canonKey(sanitize(remote.requester, 64)) or "?",
        crafter     = canonKey(sanitize(remote.crafter, 64)) or "?",
        item = {
            id         = clampItemID(remote.item.id),
            name       = sanitize(remote.item.name, 80) or "?",
            profession = sanitize(remote.item.profession, 40) or "?",
        },
        quantity          = clampQty(remote.quantity),
        matResponsibility = VALID_MATRESP[remote.matResponsibility] and remote.matResponsibility or "requester",
        note              = remote.note and sanitize(remote.note, 200) or nil,
        -- A handoff for a claim WE made, not an unsolicited request. Strict
        -- boolean, never a remote string; the panel picks its chat line by it.
        fromClaim         = (remote.fromClaim == true) or nil,
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
    -- can't make every future legit update look "stale" (freeze attack), and
    -- so a NaN can't slip past every comparison below into the record.
    local newU = clampTime(updatedAt)
    local curRank = STATUS_RANK[o.status] or 0
    local newRank = STATUS_RANK[newStatus] or 0
    local curU    = o.updatedAt or 0
    if curRank >= 3 then return o, false end          -- already terminal
    if newU < curU then return o, false end           -- stale
    -- Rank is checked unconditionally, not only on a timestamp tie: a
    -- counterparty sending "accepted" after "crafted" with a later updatedAt
    -- would otherwise walk the order backwards and strip the requester's
    -- Received button, wedging it.
    if newRank < curRank then return o, false end     -- never regress
    if newU == curU and newRank == curRank then       -- duplicate
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
