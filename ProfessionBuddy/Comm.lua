----------------------------------------------------------------------
-- ProfessionBuddy  --  Comm.lua
-- Addon-to-addon communication for friend/group-mate data sharing.
--
-- Uses AceComm-3.0 + AceSerializer-3.0 + ChatThrottleLib for
-- reliable, throttled, chunked messaging over addon channels.
--
-- Protocol:
--   HELLO      -> broadcast on party/raid join (lightweight)
--   HELLO_ACK  -> whisper back to HELLO sender
--   SYNC_REQ   -> request full data from a player
--   SYNC_DATA  -> full character payload (professions, recipes, inventory)
--   INCR       -> incremental inventory/profession update (debounced)
----------------------------------------------------------------------

local addon = ProfBuddy
local Comm = addon:NewModule("Comm")

-- Comm wire revision. Bump by 1 on ANY wire-format / payload-shape / trust-gate
-- change (see Comm-Verification-Ledger.md). Reintroduced 2026-08-20: it was
-- designed 2026-07-26 but that edit only ever lived in a Drive zip and was never
-- committed, so it fell out of the shipped code. rev 2 = last verified wire
-- (shipped 1.0.2); rev 3 = 1.0.3 order-comm changes (decline reasons + delivery
-- indicators); rev 4 = trust-gate hardening restored (realm-aware group match,
-- two-tier seen/trusted contacts, realm-aware whisper + order anti-spoof) after
-- the 1.0.1 security patch fell out of shipped code the same way COMM_REV did.
local COMM_REV = 5
addon.COMM_REV = COMM_REV

local AceComm
local AceSerializer

local PREFIX = "PBuddy"
local DS     -- DataStore, set in Init

-- Debounce timer for incremental updates
local incrTimer = nil
local INCR_DEBOUNCE = 5  -- seconds

-- Security: per-sender rate limit on expensive replies (SYNC_REQ).
local lastServed = {}          -- senderKey -> time() of last served reply
local SERVE_COOLDOWN = 30      -- seconds

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
function Comm:Init()
    DS = addon.DataStore
    if not DS then return end

    -- Acquire libraries via LibStub
    local ok, err = pcall(function()
        AceComm = LibStub("AceComm-3.0")
        AceSerializer = LibStub("AceSerializer-3.0")
    end)
    if not ok then
        -- Libraries not available -- silently disable comms
        print("|cff00ccffProfessionBuddy:|r Comm libraries not found, sync disabled.")
        return
    end

    -- Register our message prefix. AceComm uses a callback table pattern.
    -- We create a small wrapper object to receive messages.
    self._commTarget = {}
    function self._commTarget:OnCommReceived(prefix, message, distribution, sender)
        Comm:OnMessageReceived(prefix, message, distribution, sender)
    end
    AceComm.RegisterComm(self._commTarget, PREFIX)

    -- Auto-sync: broadcast HELLO when joining a group
    addon:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        self:OnGroupChanged()
    end)

    -- Auto-sync: broadcast HELLO to the guild when the roster first populates
    addon:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        self:OnGuildChanged()
    end)

    -- Auto-sync contacts on login; also announce to the guild on login/reload.
    -- Guild membership is persistent, so the not-guilded->guilded transition in
    -- OnGuildChanged may never fire on a cold login or a /reload (you are already
    -- guilded). Broadcasting here makes guild discovery reliable; BroadcastGuildHello
    -- is throttled so this and the transition path can't double-send.
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(5, function()
            self:SyncOnlineContacts()
            self:BroadcastGuildHello()
        end)
    end)

    -- Debounced incremental updates on inventory/profession changes
    addon:RegisterEvent("BAG_UPDATE", function()
        self:QueueIncrementalUpdate()
    end)

    self._inGroup = IsInGroup()
    self._inGuild = IsInGuild()
    self._ready = true
end

----------------------------------------------------------------------
-- Sending helpers
----------------------------------------------------------------------
function Comm:Send(msgType, data, channel, target)
    if not self._ready then return end

    data = data or {}
    data._type = msgType
    data._ver = addon.version
    data._commrev = COMM_REV
    data._from = addon:PlayerKey()

    local serialized = AceSerializer:Serialize(data)
    AceComm:SendCommMessage(PREFIX, serialized, channel, target, "NORMAL")
end

-- Realm names as normalized in comm sender strings: spaces, hyphens and
-- apostrophes removed ("Old Blanchy" -> "OldBlanchy").
local function normRealm(realm)
    return (realm or ""):gsub("[%s%-']", "")
end

-- Full "Name-Realm" for a trust comparison, realm normalized the way comm
-- sender strings are and a missing realm defaulted to ours. This is NOT the
-- same as normKey below (which lowercases for pending-sync bookkeeping); trust
-- compares must keep case, so they use this helper.
local function normFullKey(key)
    if type(key) ~= "string" then return nil end
    local name, realm = key:match("^([^-]+)%-?(.*)$")
    if not name then return nil end
    if realm == "" then realm = GetRealmName() end
    return name .. "-" .. normRealm(realm)
end

function Comm:SendWhisper(msgType, data, target)
    -- Same-realm targets are addressed by short name. A cross-realm target
    -- keeps its full Name-Realm: stripping it would deliver the payload to a
    -- same-named STRANGER on our own realm.
    local name, realm = target:match("^([^-]+)%-?(.*)$")
    if not name then return end
    if realm ~= "" and normRealm(realm) ~= normRealm(GetRealmName()) then
        self:Send(msgType, data, "WHISPER", name .. "-" .. realm)
    else
        self:Send(msgType, data, "WHISPER", name)
    end
end

function Comm:SendGroup(msgType, data)
    if IsInRaid() then
        self:Send(msgType, data, "RAID")
    elseif IsInGroup() then
        self:Send(msgType, data, "PARTY")
    end
end

----------------------------------------------------------------------
-- Ingress sanitization. Trust decides WHO we listen to; these decide
-- WHAT is allowed to reach SavedVariables and the UI: strings pipe-
-- escaped and length-capped, numbers coerced and clamped, maps size-
-- capped. A trusted peer running a hostile client is still a hostile
-- client, so remote payloads are rebuilt field-by-field, never stored
-- by reference.
----------------------------------------------------------------------
local MAX_PROFESSIONS      = 16    -- professions per remote character
local MAX_RECIPES_PER_PROF = 2000  -- recipe names per profession
local MAX_INV_ENTRIES      = 5000  -- itemID entries per bags/bank map

local function sanStr(s, maxLen)
    if type(s) ~= "string" or s == "" then return nil end
    s = s:gsub("|", "||")
    if #s > maxLen then s = s:sub(1, maxLen) end
    return s
end

local function sanInt(v, minV, maxV, default)
    v = tonumber(v)
    if not v then return default end
    v = math.floor(v)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

-- Positive integer ID within range, or nil (0 / junk means "absent").
local function sanID(v, maxV)
    v = tonumber(v)
    if not v then return nil end
    v = math.floor(v)
    if v < 1 or v > maxV then return nil end
    return v
end

-- itemID -> count map: numeric keys/values only, clamped, size-capped.
local function sanCounts(t, maxEntries)
    local out, n = {}, 0
    if type(t) ~= "table" then return out end
    for rawID, rawCount in pairs(t) do
        local id = sanID(rawID, 10^7)
        local count = tonumber(rawCount)
        if id and count and count > 0 then
            n = n + 1
            if n > maxEntries then break end
            if count > 10^6 then count = 10^6 end
            out[id] = math.floor(count)
        end
    end
    return out
end

local VALID_FACTION = { Alliance = true, Horde = true, Neutral = true }
local function sanFaction(f)
    return (type(f) == "string" and VALID_FACTION[f]) and f or "Unknown"
end

-- Class tokens are locale-independent uppercase English ("WARRIOR").
local function sanClass(c)
    if type(c) == "string" and #c <= 16 and c:match("^%u+$") then return c end
    return "UNKNOWN"
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
-- Trust gate: we only act on messages from players we chose to engage with --
-- a TRUSTED contact (created by a local action: Add contact, /pb sync, or
-- enabling auto-sync) or a CURRENT party/raid member. Random players who merely
-- know your character name are ignored, which blocks data pulls, fake orders,
-- spoofed chat lines, and malformed-payload errors right at the door.
--
-- Group members running PB still get a contact entry so the Friends panel can
-- list them, but that entry is created with trusted=false: once the group
-- disbands they can no longer pull your data. (v1.0.0 kept every past group-mate
-- trusted forever, so one battleground was enough to let strangers pull your
-- full bags+bank for all time.)
function Comm:IsGroupMember(senderKey)
    if not IsInGroup() then return false end
    -- Exact Name-Realm compare: matching on the short name alone would let
    -- "Bob-OtherRealm" ride on group-mate "Bob"'s trust (and vice versa) in any
    -- cross-realm group.
    local want = normFullKey(senderKey)
    if not want then return false end
    local prefix, n
    if IsInRaid() then prefix, n = "raid", GetNumGroupMembers()
    else prefix, n = "party", GetNumSubgroupMembers() end
    for i = 1, n do
        local full = GetUnitName(prefix .. i, true)  -- "Name" or "Name-Realm"
        if full and normFullKey(full) == want then return true end
    end
    return false
end

-- Realm-aware guild-roster membership. Mirrors IsGroupMember: guild trust is
-- LIVE (checked against the current roster), never persisted -- leaving the
-- guild ends the trust, exactly as leaving a group does.
function Comm:IsGuildMember(senderKey)
    if not IsInGuild() then return false end
    local want = normFullKey(senderKey)
    if not want then return false end
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name = GetGuildRosterInfo(i)   -- "Name" or "Name-Realm"
        if name and normFullKey(name) == want then return true end
    end
    return false
end

function Comm:IsTrusted(senderKey)
    local contact = addon.db.contacts and addon.db.contacts[senderKey]
    if contact and contact.trusted then return true end
    if self:IsGroupMember(senderKey) then return true end
    return self:IsGuildMember(senderKey)
end

-- Privacy master switch: when off, we send NO profession/inventory data
-- to anyone (gated at the two payload builders, which covers every
-- outbound path). Toggle with /pb comm on|off. Default on.
function Comm:SharingEnabled()
    return not (addon.db and addon.db.settings) or addon.db.settings.shareData ~= false
end

function Comm:OnMessageReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then return end

    -- Normalize sender to Name-Realm format
    if not sender:find("-") then
        sender = sender .. "-" .. GetRealmName()
    end

    -- Ignore our own messages
    if sender == addon:PlayerKey() then return end

    -- SECURITY: only process messages from known players (a saved
    -- contact or a current group member). Everyone else is ignored.
    if not self:IsTrusted(sender) then return end

    local ok, data = AceSerializer:Deserialize(message)
    if not ok or type(data) ~= "table" then return end

    local msgType = data._type
    if type(msgType) ~= "string" then return end

    -- Dispatch under pcall so a malformed payload (even from a trusted
    -- player) can never throw a visible Lua error in our client.
    pcall(function()
        if msgType == "HELLO" then
            self:HandleHello(sender, data)
        elseif msgType == "HELLO_ACK" then
            self:HandleHelloAck(sender, data)
        elseif msgType == "SYNC_REQ" then
            self:HandleSyncRequest(sender, data)
        elseif msgType == "SYNC_DATA" then
            self:HandleSyncData(sender, data)
        elseif msgType == "ORDER_NEW" then
            self:HandleOrderNew(sender, data)
        elseif msgType == "ORDER_UPDATE" then
            self:HandleOrderUpdate(sender, data)
        elseif msgType == "ORDER_ACK" then
            self:HandleOrderAck(sender, data)
        end
    end)

    -- Any message from a (trusted) contact proves they're online --
    -- deliver any order messages we had queued for them while offline.
    self:FlushOutbox(sender)
end

----------------------------------------------------------------------
-- Crafting orders (Phase 1-2 + Phase 3 public-safe slice)
-- Each side owns its transitions (Orders.lua enforces actor + state);
-- after a successful local transition the actor whispers the
-- counterparty, who mirrors the result via the Orders remote-apply
-- methods. ORDER_NEW carries the full record (the crafter has no
-- prior copy); ORDER_UPDATE carries id + new status.
--
-- Phase 3 public-safe slice:
--  * Delivery ACK: the recipient echoes ORDER_ACK for every order
--    message; if the sender gets no ack within ORDER_ACK_TIMEOUT it
--    warns that the counterparty may be offline. (Automatic
--    re-delivery / queueing is the deferred full Phase 3.)
--  * Dedup: the Orders remote-apply methods ignore duplicate / stale /
--    out-of-order messages (Orders:UpsertFromRemote / ApplyRemoteStatus).
----------------------------------------------------------------------

local ORDER_ACK_TIMEOUT = 8          -- seconds to wait for a delivery ack
local pendingOrderAck = {}           -- token -> { timer = <C_Timer> }

-- The other party on an order, from my point of view.
function Comm:OrderCounterparty(order)
    local me = addon:PlayerKey()
    if order.requester == me then return order.crafter end
    if order.crafter   == me then return order.requester end
    return nil
end

local function shortName(key)
    return (key and key:match("^([^-]+)")) or key or "?"
end

-- Canonical key for matching a player name regardless of letter case or a
-- missing realm suffix. Reconciles a user-typed sync target (which the slash
-- handler lowercases and may lack a realm) with the proper-case Name-Realm
-- form AceComm reports for the reply, so the manual-sync watch clears
-- correctly instead of firing a false "didn't respond".
local function normKey(key)
    if not key or key == "" then return nil end
    if not key:find("-") then key = key .. "-" .. GetRealmName() end
    return key:lower()
end

-- Send an order message to the counterparty and track delivery. If no
-- ORDER_ACK returns within the timeout, the message is parked in a
-- persisted outbox and auto-resent the next time we hear from that
-- player (any PB message proves they are online). isResend is true for
-- automatic retries and suppresses the one-time "queued" warning.
function Comm:SendOrderMessage(msgType, data, target, label, isResend)
    if not self._ready or not data or not data.token then return end
    local token = data.token
    self:SendWhisper(msgType, data, target)
    local prev = pendingOrderAck[token]
    if prev and prev.timer then prev.timer:Cancel() end
    pendingOrderAck[token] = {
        target = target,
        timer = C_Timer.NewTimer(ORDER_ACK_TIMEOUT, function()
            pendingOrderAck[token] = nil
            addon.db.orderOutbox = addon.db.orderOutbox or {}
            local existing = addon.db.orderOutbox[token]
            local warned = (existing and existing.warned) or false
            if not isResend and not warned then
                warned = true
                print("|cff00ccffProfessionBuddy:|r " .. shortName(target) ..
                    " is offline -- order " .. (label or "update") ..
                    " queued; it will send automatically when they are next online.")
            end
            addon.db.orderOutbox[token] = {
                msgType = msgType, data = data, target = target,
                label = label, warned = warned,
            }
            -- Delivery indicator: no ack in time -> they're offline, mark queued.
            local oid = data.id or (data.order and data.order.id)
            local o = oid and addon.db.orders and addon.db.orders[oid]
            if o and o.lastSentToken == token then
                o.deliveryState = "queued"
                if addon.OrdersPanel and addon.OrdersPanel.RefreshAll then addon.OrdersPanel:RefreshAll() end
            end
        end),
    }
end

-- Recipient -> sender: confirm an order message was received.
function Comm:SendOrderAck(target, token)
    if not self._ready or not token then return end
    self:SendWhisper("ORDER_ACK", { token = token }, target)
end

function Comm:HandleOrderAck(sender, data)
    local token = data.token
    if type(token) ~= "string" or token == "" then return end
    -- Anti-spoof: only the player we actually sent this token to may ack it.
    -- Otherwise any trusted peer could clear our outbox or flip the delivery
    -- indicator for an order they are not part of.
    local senderNorm = normFullKey(sender)
    local p = pendingOrderAck[token]
    if p then
        if p.target and normFullKey(p.target) ~= senderNorm then return end
        if p.timer then p.timer:Cancel() end
        pendingOrderAck[token] = nil
    end
    local ob = addon.db.orderOutbox
    if ob and ob[token] then
        if ob[token].target and normFullKey(ob[token].target) ~= senderNorm then return end
        ob[token] = nil
    end
    -- Delivery indicator: the counterparty's client confirmed receipt.
    local oid = token:match("^(.-):")
    local o = oid and addon.db.orders and addon.db.orders[oid]
    if o and o.lastSentToken == token then
        o.deliveryState = "delivered"
        if addon.OrdersPanel and addon.OrdersPanel.RefreshAll then addon.OrdersPanel:RefreshAll() end
    end
end

-- Re-send any order messages queued for a player. Called when we next
-- hear from them (any PB message proves they're online). ORDER_NEW
-- flushes before updates so a create-then-change-while-offline sequence
-- lands in order; in-flight tokens (awaiting ack) are skipped.
function Comm:FlushOutbox(target)
    if not self._ready then return end
    local ob = addon.db.orderOutbox
    if not ob then return end
    local name = shortName(target)
    local due = {}
    for token, entry in pairs(ob) do
        if not pendingOrderAck[token] and shortName(entry.target) == name then
            table.insert(due, token)
        end
    end
    if #due == 0 then return end
    table.sort(due, function(a, b)
        local an = a:find(":new", 1, true) ~= nil
        local bn = b:find(":new", 1, true) ~= nil
        if an ~= bn then return an end   -- NEW before updates
        return a < b
    end)
    for _, token in ipairs(due) do
        local entry = ob[token]
        if entry then
            self:SendOrderMessage(entry.msgType, entry.data, entry.target,
                entry.label, true)
        end
    end
end

-- Requester -> crafter: a brand-new order (full record).
function Comm:SendOrderNew(order)
    if not self._ready or not order then return end
    local cp = self:OrderCounterparty(order)
    if not cp then return end
    local token = order.id .. ":new"
    self:SendOrderMessage("ORDER_NEW", { order = order, token = token }, cp,
        "request")
    -- Delivery indicator (set AFTER the send so these local-only fields don't
    -- ride in the payload). "sent" -> "delivered" on ack, "queued" on timeout.
    order.lastSentToken = token
    order.deliveryState = "sent"
    order.lastSentBy = addon:PlayerKey()  -- so the indicator only shows to the sender
end

-- Either side -> counterparty: a status change on an existing order.
function Comm:SendOrderUpdate(order)
    if not self._ready or not order then return end
    local cp = self:OrderCounterparty(order)
    if not cp then return end
    local token = order.id .. ":" .. order.status .. ":" .. (order.updatedAt or 0)
    self:SendOrderMessage("ORDER_UPDATE", {
        id           = order.id,
        status       = order.status,
        completedBy  = order.completedBy,
        updatedAt    = order.updatedAt,
        declineReason = order.declineReason,  -- optional; only set on a decline
        token        = token,
    }, cp, order.status .. " update")
    order.lastSentToken = token
    order.deliveryState = "sent"
    order.lastSentBy = addon:PlayerKey()  -- so the indicator only shows to the sender
end

-- A received status maps to the NotifyOrderEvent "kind" shown to the
-- counterparty. (pending isn't sent as an update -- new orders use
-- ORDER_NEW / newRequest.)
local ORDER_STATUS_KIND = {
    accepted  = "accepted",
    crafted   = "crafted",
    declined  = "declined",
    cancelled = "cancelled",
    completed = "completed",
}

function Comm:HandleOrderNew(sender, data)
    local Orders = addon.Orders
    if not Orders or type(data.order) ~= "table" then return end
    local o = data.order
    -- Validate shape + anti-spoof: required fields must be the right
    -- type, the creator must BE the sender (can't forge "requester"),
    -- and the order must be addressed to US.
    if type(o.id) ~= "string" or type(o.requester) ~= "string"
       or type(o.crafter) ~= "string" or type(o.item) ~= "table" then
        return
    end
    -- Realm-aware anti-spoof: the creator must BE the sender and the order must
    -- be addressed to us. Ack even on refusal (an ack means "received", not
    -- "applied") so a rejected peer stops re-queuing and retrying forever.
    if normFullKey(o.requester) ~= normFullKey(sender)
       or normFullKey(o.crafter) ~= normFullKey(addon:PlayerKey()) then
        self:SendOrderAck(sender, data.token)
        return
    end
    local order, applied = Orders:UpsertFromRemote(o)
    -- Ack even duplicates (clears the sender's offline warning); only
    -- notify on a genuinely new order so dupes don't double-chat.
    if order then self:SendOrderAck(sender, data.token) end
    if applied then self:NotifyOrders("newRequest", order) end
end

function Comm:HandleOrderUpdate(sender, data)
    local Orders = addon.Orders
    if not Orders or type(data.id) ~= "string" then return end
    -- Anti-spoof: the update may only come from the order's actual
    -- counterparty. Reject updates to orders we don't have or that the
    -- sender isn't a party to (blocks strangers/others poking orders).
    local existing = addon.db.orders and addon.db.orders[data.id]
    if not existing then
        -- We don't have it (deleted, version skew). Ack so the peer stops
        -- retrying, but there is nothing to apply.
        self:SendOrderAck(sender, data.token)
        return
    end
    local cp = self:OrderCounterparty(existing)
    if not cp or normFullKey(cp) ~= normFullKey(sender) then return end
    -- Which side of the order is the sender? Passed down so the status change is
    -- checked against that role's legal moves and completedBy can't be forged
    -- (a crafter can't claim the requester confirmed receipt).
    local senderRole = (cp == existing.requester) and "requester" or "crafter"
    local order, applied = Orders:ApplyRemoteStatus(data.id, data.status,
        data.completedBy, data.updatedAt, data.declineReason, senderRole)
    if order then self:SendOrderAck(sender, data.token) end
    if order and applied then self:NotifyOrders(ORDER_STATUS_KIND[order.status], order) end
end

-- Route a counterparty event through the OrdersPanel notification
-- dispatcher (chat line + badge + sound + refresh). Falls back to a
-- plain refresh if the panel/dispatcher or kind isn't available.
function Comm:NotifyOrders(kind, order)
    local OP = addon.OrdersPanel
    if not OP then return end
    if kind and order and OP.NotifyOrderEvent then
        OP:NotifyOrderEvent(kind, order)
    elseif OP.RefreshAll then
        OP:RefreshAll()
    end
end

----------------------------------------------------------------------
-- HELLO: lightweight broadcast on group join
----------------------------------------------------------------------
function Comm:BuildHelloPayload()
    if not self:SharingEnabled() then return nil end
    local charData = DS:GetCharacter(addon:PlayerKey())
    if not charData then return nil end

    -- Only send profession names + skill, not full recipe data.
    -- NOTE: the scanner stores skill as skillLevel/maxSkill, so read those
    -- (reading level/maxLevel here was the bug that sent friends 0/375).
    local profSummary = {}
    for profName, profData in pairs(charData.professions or {}) do
        profSummary[profName] = {
            skillLevel = profData.skillLevel or 0,
            maxSkill = profData.maxSkill or 375,
        }
    end

    return {
        class = charData.class,
        level = charData.level,
        faction = charData.faction,
        professions = profSummary,
    }
end

function Comm:BroadcastHello()
    if not self._ready then return end
    if not IsInGroup() then return end

    local payload = self:BuildHelloPayload()
    if not payload then return end

    self:SendGroup("HELLO", payload)
end

-- Broadcast HELLO once to every online guildmate over the native GUILD channel
-- (one message, not N whispers). Ships only the lightweight summary; full data
-- stays on-demand, so this stays privacy-conservative. Gated by BuildHelloPayload,
-- which honors the /pb comm off master switch.
function Comm:BroadcastGuildHello()
    if not self._ready then return end
    if not IsInGuild() then return end

    -- Throttle: the join transition (OnGuildChanged) and login/reload
    -- (PLAYER_ENTERING_WORLD) can both call this; don't broadcast twice in
    -- quick succession. Only stamp the time when we actually send.
    local now = time()
    if self._lastGuildHelloAt and (now - self._lastGuildHelloAt) < 30 then return end

    local payload = self:BuildHelloPayload()
    if not payload then return end

    self._lastGuildHelloAt = now
    self:Send("HELLO", payload, "GUILD")
end

function Comm:HandleHello(sender, data)
    -- Store lightweight summary so we know what they have
    self:StoreLightweight(sender, data)

    -- Send back our own summary
    local payload = self:BuildHelloPayload()
    if payload then
        self:SendWhisper("HELLO_ACK", payload, sender)
    end

    -- If they're a saved contact with autoSync, request full data
    local contact = addon.db.contacts[sender]
    if contact and contact.autoSync then
        C_Timer.After(1, function()
            self:RequestSync(sender)
        end)
    end
end

function Comm:HandleHelloAck(sender, data)
    self:StoreLightweight(sender, data)

    -- If they're a saved contact with autoSync, request full data
    local contact = addon.db.contacts[sender]
    if contact and contact.autoSync then
        C_Timer.After(1, function()
            self:RequestSync(sender)
        end)
    end
end

-- Store just the profession summary (no recipes/inventory) so the
-- friends panel can show what professions they have even before a
-- full sync.
function Comm:StoreLightweight(sender, data)
    local existing = addon.db.characters[sender]
    if existing and not existing.isRemote then
        -- Don't overwrite local alt data with remote lightweight data
        return
    end

    if not existing then
        addon.db.characters[sender] = {
            class = sanClass(data.class),
            level = sanInt(data.level, 0, 100, 0),
            faction = sanFaction(data.faction),
            professions = {},
            inventory = { bags = {}, bank = {} },
            isRemote = true,
            lastSync = 0,
        }
    end

    local char = addon.db.characters[sender]
    if data.class ~= nil then char.class = sanClass(data.class) end
    if data.level ~= nil then char.level = sanInt(data.level, 0, 100, char.level or 0) end
    if data.faction ~= nil then char.faction = sanFaction(data.faction) end

    -- Update profession summaries without wiping recipe data
    -- (a full SYNC_DATA will populate recipes later)
    if type(data.professions) == "table" then
        local nProfs = 0
        for rawProfName, summary in pairs(data.professions) do
            local profName = sanStr(rawProfName, 40)
            if profName and type(summary) == "table" then
                nProfs = nProfs + 1
                if nProfs > MAX_PROFESSIONS then break end
                if not char.professions[profName] then
                    char.professions[profName] = {
                        skillLevel = sanInt(summary.skillLevel, 0, 500, 0),
                        maxSkill = sanInt(summary.maxSkill, 1, 500, 375),
                        recipes = {},
                    }
                else
                    char.professions[profName].skillLevel = sanInt(summary.skillLevel, 0, 500, char.professions[profName].skillLevel or 0)
                    char.professions[profName].maxSkill = sanInt(summary.maxSkill, 1, 500, char.professions[profName].maxSkill or 375)
                end
            end
        end
    end

    -- Track group-mates as contacts (so the Friends panel lists them) only when
    -- the user opted in via "Auto-add party members". The entry is trusted=false:
    -- being seen in a group is not consent to serve data after it ends; trust is
    -- only ever set by a local action (Add contact, /pb sync, auto-sync checkbox).
    -- Gate on IsGroupMember: this is "auto-add PARTY members", so a HELLO from a
    -- guildmate (guild trust is live, not persisted) must not create a contact.
    if addon.db.settings and addon.db.settings.autoAddParty
       and self:IsGroupMember(sender)
       and not addon.db.contacts[sender] then
        addon.db.contacts[sender] = {
            autoSync = false,
            lastSync = 0,
            trusted = false,
            seenAt = time(),
        }
    end

    self:NotifyUIRefresh()
end

----------------------------------------------------------------------
-- Notify all visible UI surfaces to refresh after incoming data
----------------------------------------------------------------------
function Comm:NotifyUIRefresh()
    -- Friends panel
    if addon.FriendsPanel and addon.FriendsPanel.Refresh then
        addon.FriendsPanel:Refresh()
    end
    -- Character panel (if the main /pb window is visible)
    if addon.UI and addon.UI.frame and addon.UI.frame:IsShown()
       and addon.CharacterPanel and addon.CharacterPanel.Refresh then
        addon.CharacterPanel:Refresh()
    end
    -- Profession window detail panel + material calc
    if addon.TradeSkillFrame and addon.TradeSkillFrame.frame
       and addon.TradeSkillFrame.frame:IsShown() then
        local tsf = addon.TradeSkillFrame
        if tsf.RefreshDetailPanel then
            tsf:RefreshDetailPanel(true)
        end
        if tsf.calcFrame and tsf.calcFrame:IsShown() and tsf.RefreshCalcPanel then
            tsf:RefreshCalcPanel()
        end
    end
end

----------------------------------------------------------------------
-- SYNC_REQ / SYNC_DATA: full data exchange
----------------------------------------------------------------------
-- Canonicalize a user-typed contact key: capitalize the name the way the
-- server stores it and default a missing realm to ours. Without this, "/pb sync
-- bob" saves the contact as "bob-Realm" while the reply arrives from
-- "Bob-Realm", failing the trust gate, so the sync data would be silently dropped.
function Comm:NormalizeContactKey(key)
    if type(key) ~= "string" or key == "" then return nil end
    local name, realm = key:match("^([^-]+)%-?(.*)$")
    if not name then return nil end
    local first = name:sub(1, 1)
    if first:match("%l") then           -- ASCII only; leave UTF-8 names alone
        name = first:upper() .. name:sub(2)
    end
    if realm == "" then
        realm = GetRealmName()
    elseif normRealm(realm):lower() == normRealm(GetRealmName()):lower() then
        realm = GetRealmName()          -- same realm: adopt canonical spelling
    end
    return name .. "-" .. realm
end

function Comm:RequestSync(target, isManual)
    if not self._ready then
        if isManual then
            print("|cff00ccffProfessionBuddy:|r Sync not available.")
        end
        return
    end

    target = self:NormalizeContactKey(target)
    if not target then return end

    -- Ensure contact entry exists; requesting a sync is a deliberate local
    -- action, so it marks the contact trusted (we are willing to serve their
    -- SYNC_REQ in return -- sharing is mutual).
    if not addon.db.contacts[target] then
        addon.db.contacts[target] = {
            autoSync = false,
            lastSync = 0,
        }
    end
    addon.db.contacts[target].trusted = true

    -- Only manual syncs announce themselves and watch for a reply; auto
    -- syncs stay silent so they don't spam chat.
    if isManual then
        print("|cff00ccffProfessionBuddy:|r Requesting sync from " .. target .. "...")
        self._pendingSync = self._pendingSync or {}
        local pkey = normKey(target)
        self._pendingSync[pkey] = true
        C_Timer.After(10, function()
            if self._pendingSync and self._pendingSync[pkey] then
                self._pendingSync[pkey] = nil
                print("|cff00ccffProfessionBuddy:|r " .. target
                    .. " didn't respond (offline or not running ProfessionBuddy).")
            end
        end)
    end

    self:SendWhisper("SYNC_REQ", {}, target)
end

-- Guild sync-on-demand (Guild tab -> pull a guildmate's full recipe data).
-- Unlike RequestSync this creates NO persisted contact: guild trust is LIVE
-- (roster-based), so the guildmate serves us because we're in their roster and
-- we store their reply because they're in ours. Throttled per target so rapid
-- clicks don't spam. Reuses the existing SYNC_REQ message, so COMM_REV is
-- unchanged (no wire change).
function Comm:RequestGuildSync(targetKey)
    if not self._ready or not targetKey then return end
    local key = normFullKey(targetKey)
    if not key then return end
    self._guildSyncAt = self._guildSyncAt or {}
    local now = time()
    local last = self._guildSyncAt[key]
    if last and (now - last) < 15 then return end   -- 15s per guildmate
    self._guildSyncAt[key] = now
    self:SendWhisper("SYNC_REQ", {}, key)
end

function Comm:HandleSyncRequest(sender, data)
    -- Rate-limit so a SYNC_REQ flood can't make us repeatedly build and
    -- whisper our full payload. (Sharing-off is enforced in the builder.)
    local now = time()
    if lastServed[sender] and (now - lastServed[sender]) < SERVE_COOLDOWN then return end
    local payload = self:BuildFullPayload()
    if payload then
        lastServed[sender] = now
        self:SendWhisper("SYNC_DATA", payload, sender)
    end
end

function Comm:BuildFullPayload()
    if not self:SharingEnabled() then return nil end
    local charData = DS:GetCharacter(addon:PlayerKey())
    if not charData then return nil end

    -- Build a clean copy of profession data with recipe names only
    -- (both sides have the static RecipeDB, so we don't need to send
    -- reagents, itemIDs, etc. -- just which recipes are known)
    local professions = {}
    for profName, profData in pairs(charData.professions or {}) do
        -- Build recipeNames and recipeSpells in lockstep (same loop, so the
        -- two arrays stay index-aligned). spellID is locale-stable; the name
        -- is kept for backward compat with clients that lack spellID matching.
        local recipeNames = {}
        local recipeSpells = {}
        local recipeCooldowns = {}   -- index-aligned; 0 = no active cooldown
        if profData.recipes then
            for recipeName, info in pairs(profData.recipes) do
                table.insert(recipeNames, recipeName)
                recipeSpells[#recipeNames] = info.spellID or 0
                recipeCooldowns[#recipeNames] =
                    (info.cooldownReadyAt and info.cooldownReadyAt > time()) and info.cooldownReadyAt or 0
            end
        end
        professions[profName] = {
            skillLevel = profData.skillLevel or 0,
            maxSkill = profData.maxSkill or 375,
            recipeNames = recipeNames,
            recipeSpells = recipeSpells,
            recipeCooldowns = recipeCooldowns,
        }
    end

    -- Inventory: send itemID -> count maps
    local inventory = {
        bags = {},
        bank = {},
    }
    if charData.inventory then
        for id, count in pairs(charData.inventory.bags or {}) do
            inventory.bags[id] = count
        end
        for id, count in pairs(charData.inventory.bank or {}) do
            inventory.bank[id] = count
        end
    end

    return {
        class = charData.class,
        level = charData.level,
        faction = charData.faction,
        professions = professions,
        inventory = inventory,
    }
end

function Comm:HandleSyncData(sender, data)
    if not data then return end

    -- Was this the reply to a manual sync we initiated? If so, clear the
    -- timeout watch and confirm in chat below; background / incremental
    -- syncs stay silent so chat doesn't flood (e.g. several friends
    -- crafting at once).
    local pkey = normKey(sender)
    local wasManual = self._pendingSync and self._pendingSync[pkey]
    if self._pendingSync then self._pendingSync[pkey] = nil end

    -- Reconstruct the character record from the payload with a field-by-field
    -- copy: never store remote tables by reference. The raw payload can hold
    -- anything -- pipe escape codes in strings (rendered by the panels and
    -- tooltips), non-numeric inventory counts (arithmetic errors in the
    -- calculator and WhoHasItem), or unbounded junk that lands in
    -- SavedVariables forever.
    local charRecord = {
        class = sanClass(data.class),
        level = sanInt(data.level, 0, 100, 0),
        faction = sanFaction(data.faction),
        professions = {},
        inventory = {
            bags = sanCounts(type(data.inventory) == "table" and data.inventory.bags,
                             MAX_INV_ENTRIES),
            bank = sanCounts(type(data.inventory) == "table" and data.inventory.bank,
                             MAX_INV_ENTRIES),
        },
        isRemote = true,
        lastSync = time(),
    }

    -- Rebuild profession data with recipe entries
    -- We store recipe names as keys pointing to minimal info
    -- (the UI will cross-reference RecipeDB for full details)
    if type(data.professions) == "table" then
        local nProfs = 0
        for rawProfName, profPayload in pairs(data.professions) do
            local profName = sanStr(rawProfName, 40)
            if profName and type(profPayload) == "table" then
                nProfs = nProfs + 1
                if nProfs > MAX_PROFESSIONS then break end
                local recipes = {}
                if type(profPayload.recipeNames) == "table" then
                    local spells = type(profPayload.recipeSpells) == "table"
                                   and profPayload.recipeSpells or nil
                    local cds = type(profPayload.recipeCooldowns) == "table"
                                   and profPayload.recipeCooldowns or nil
                    local now = time()
                    for idx, rawRecipeName in ipairs(profPayload.recipeNames) do
                        if idx > MAX_RECIPES_PER_PROF then break end
                        local recipeName = sanStr(rawRecipeName, 120)
                        if recipeName then
                            -- carry the locale-stable spellID when present so
                            -- remote recipes match the static DB across locales
                            -- (sanID maps 0 / junk back to nil = absent)
                            local sid = spells and sanID(spells[idx], 10^7)
                            local rec = { isKnown = true, spellID = sid }
                            -- friend cooldown ready-time, clamped to a sane window
                            -- so a forged value can't show an absurd countdown
                            local cd = cds and tonumber(cds[idx])
                            if cd and cd > now and cd <= now + 30 * 86400 then
                                rec.cooldownReadyAt = cd
                            end
                            recipes[recipeName] = rec
                        end
                    end
                end
                charRecord.professions[profName] = {
                    skillLevel = sanInt(profPayload.skillLevel, 0, 500, 0),
                    maxSkill = sanInt(profPayload.maxSkill, 1, 500, 375),
                    recipes = recipes,
                }
            end
        end
    end

    DS:SetRemoteCharacter(sender, charRecord)

    -- Update contact metadata (always, so the Friends panel timestamp
    -- stays current even for silent background syncs)
    if addon.db.contacts[sender] then
        addon.db.contacts[sender].lastSync = time()
    end

    -- Only confirm in chat for syncs you manually requested.
    if wasManual then
        print("|cff00ccffProfessionBuddy:|r Synced data from " .. sender .. ".")
    end

    self:NotifyUIRefresh()
end

----------------------------------------------------------------------
-- INCR: incremental updates (debounced)
----------------------------------------------------------------------
function Comm:QueueIncrementalUpdate()
    if not self._ready then return end

    -- Only send if we have contacts with autoSync
    local hasAuto = false
    for _, contact in pairs(addon.db.contacts) do
        if contact.autoSync then
            hasAuto = true
            break
        end
    end
    if not hasAuto then return end

    -- Debounce: reset timer on each trigger
    if incrTimer then
        incrTimer:Cancel()
    end
    incrTimer = C_Timer.NewTimer(INCR_DEBOUNCE, function()
        incrTimer = nil
        Comm:SendIncrementalUpdate()
    end)
end

-- Cheap order-independent signature of what a full payload would carry.
-- BAG_UPDATE fires for every bag interaction, including moving a stack between
-- slots; without this, each shuffle re-whispered the identical full payload
-- (all recipes + inventory) to every autoSync contact.
local function payloadSignature()
    local charData = DS and DS:GetCharacter(addon:PlayerKey())
    if not charData then return 0 end
    local sig = 0
    local inv = charData.inventory or {}
    for _, loc in ipairs({ "bags", "bank" }) do
        for id, count in pairs(inv[loc] or {}) do
            sig = (sig + id * 31 + count * 7) % 2^31
        end
    end
    for _, prof in pairs(charData.professions or {}) do
        sig = (sig + (prof.skillLevel or 0) * 131) % 2^31
        local n = 0
        for _ in pairs(prof.recipes or {}) do n = n + 1 end
        sig = (sig + n * 17) % 2^31
    end
    return sig
end

function Comm:SendIncrementalUpdate()
    if not self._ready then return end

    -- Skip contacts who already have this exact state (per-contact so a newly
    -- enabled autoSync contact still gets a first push).
    self._lastPushSig = self._lastPushSig or {}
    local sig = payloadSignature()

    local payload
    for contactKey, contact in pairs(addon.db.contacts) do
        if contact.autoSync and self._lastPushSig[contactKey] ~= sig then
            -- Send as SYNC_DATA; the receiver handles it the same way
            payload = payload or self:BuildFullPayload()
            if not payload then return end   -- sharing off / no data
            self._lastPushSig[contactKey] = sig
            self:SendWhisper("SYNC_DATA", payload, contactKey)
        end
    end
end

----------------------------------------------------------------------
-- Group join detection
----------------------------------------------------------------------
function Comm:OnGroupChanged()
    local inGroup = IsInGroup()

    -- Newly joined a group? Broadcast HELLO after a short delay
    -- to let the UI settle
    if inGroup and not self._inGroup then
        C_Timer.After(2, function()
            if IsInGroup() then
                self:BroadcastHello()
            end
        end)
    end

    self._inGroup = inGroup
end

-- Guild analog of OnGroupChanged: broadcast a guild HELLO once when the roster
-- first populates (login / joining a guild), not on every GUILD_ROSTER_UPDATE
-- tick. Guildmates who log in later announce themselves with their own HELLO.
function Comm:OnGuildChanged()
    local inGuild = IsInGuild()

    if inGuild and not self._inGuild then
        C_Timer.After(2, function()
            if IsInGuild() then
                self:BroadcastGuildHello()
            end
        end)
    end

    self._inGuild = inGuild
end

----------------------------------------------------------------------
-- Login auto-sync for saved contacts
----------------------------------------------------------------------
function Comm:SyncOnlineContacts()
    if not self._ready then return end

    local contacts = addon.db.contacts
    if not contacts then return end

    for contactKey, contact in pairs(contacts) do
        if contact.autoSync then
            -- We can't reliably check if they're online without
            -- being in a group or having them on the friends list.
            -- Just send the request -- if they're offline, the
            -- whisper silently fails.
            self:SendWhisper("SYNC_REQ", {}, contactKey)
        end
    end
end
