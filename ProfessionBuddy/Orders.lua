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
}
Orders.STATUS = STATUS

-- Terminal states never appear in the active queue (they live in History)
local TERMINAL = {
    [STATUS.COMPLETED] = true,
    [STATUS.DECLINED]  = true,
    [STATUS.CANCELLED] = true,
}
Orders.TERMINAL = TERMINAL

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

function Orders:Decline(id)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    if o.status ~= STATUS.PENDING then return nil, "decline is only allowed while pending" end
    if not isActor(o, "crafter") then return nil, "only the crafter can decline" end
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
    table.sort(out, function(a, b) return a.updatedAt > b.updatedAt end)
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
}

-- Store a full order record received from the counterparty (ORDER_NEW).
-- The requester mints the order and sends it to the crafter, who has
-- no prior copy. Returns (order, applied); applied is false for a
-- duplicate (we already have it) so the caller can ack without
-- re-notifying.
function Orders:UpsertFromRemote(order)
    if not order or not order.id then return nil, "bad order record" end
    if addon.db.orders[order.id] then
        return addon.db.orders[order.id], false  -- duplicate ORDER_NEW
    end
    addon.db.orders[order.id] = order
    return order, true
end

-- Apply a remote status change to an existing order (ORDER_UPDATE).
-- Returns (order, applied): order is nil if we have no local copy;
-- applied is false for a duplicate / stale / out-of-order message
-- (the caller still acks it but skips re-notifying). Terminal orders
-- never regress.
function Orders:ApplyRemoteStatus(id, newStatus, completedBy, updatedAt)
    local o = addon.db.orders[id]
    if not o then return nil, "no such order" end
    local curRank = STATUS_RANK[o.status] or 0
    local newRank = STATUS_RANK[newStatus] or 0
    local curU    = o.updatedAt or 0
    local newU    = updatedAt or 0
    if curRank >= 3 then return o, false end          -- already terminal
    if newU < curU then return o, false end           -- stale
    if newU == curU and newRank <= curRank then       -- duplicate
        return o, false
    end
    if newStatus then o.status = newStatus end
    if completedBy ~= nil then o.completedBy = completedBy end
    o.updatedAt = updatedAt or time()
    return o, true
end
