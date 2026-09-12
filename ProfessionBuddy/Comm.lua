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
-- rev 5 = guild arm: HELLO over the native GUILD channel plus live roster trust
-- (IsGuildMember) and guild sync-on-demand, which reuses SYNC_REQ/SYNC_DATA.
-- rev 6 = guild order board: ORDER_OPEN / ORDER_CLAIM / ORDER_CLOSED.
-- rev 7 = INCR inventory delta sync (see DELTA-SYNC-scope.md): SYNC_DATA gained
-- the `epoch` field and INCR is a new message type.
--
-- 1.1.0 adds only ADDITIVE fields, so the wire stays at rev 7: `partial` on a
-- recipes-only SYNC_DATA, `rejected` on ORDER_ACK, `fromClaim` on ORDER_NEW, and
-- `scope` on SYNC_REQ (a hint only -- the server decides what it serves from the
-- sender's trust tier). An older client ignores each of them and behaves as
-- before. `_from` and `_ver` were REMOVED from every message: a self-reported
-- identity on the wire is exactly what a future handler must never trust, and
-- nothing ever read either field.
local COMM_REV = 7
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
-- Guild trust is live rather than chosen, and a guild-tier serve is a full
-- recipe payload that owns the BULK pipe for a while, so that tier waits longer
-- AND shares one budget across every sender: per-sender limits alone are priced
-- in alts. When either is hit we simply do not reply.
local GUILD_SERVE_COOLDOWN = 120   -- seconds between serves to one guild-tier peer
local GUILD_SERVE_BUDGET   = 10    -- guild-tier serves allowed per window...
local GUILD_SERVE_WINDOW   = 60    -- ...across ALL senders

-- Session-table lifetimes. Everything keyed by peer is swept on a timer so a
-- long session in a large guild cannot accumulate entries forever.
local SESSION_TTL       = 600     -- lastServed / _guildSyncAt / _helloAckAt / _resyncAt
local PENDING_REQ_TTL   = 120     -- how long an outstanding SYNC_REQ stays honored
local RESYNC_THROTTLE   = 30      -- min seconds between gap-triggered SYNC_REQs per peer
local HELLO_ACK_FLOOR   = 60      -- min seconds between HELLO_ACKs to one sender
local HELLO_PULL_FLOOR  = 60      -- min seconds between post-HELLO pulls from one sender
local UI_REFRESH_COALESCE = 1     -- max one panel repaint per second from inbound data
local REFLEX_FLOOR      = 5       -- min seconds between reflex refusal replies to one sender
local GUILD_SYNC_COOLDOWN = 15    -- min seconds between guild pulls from one guildmate
local OFFLINE_BACKOFF   = 300     -- skip a contact this long after "no player named"
local WHISPER_MEMORY    = 10      -- a system line must follow our whisper this closely

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

    -- Auto-sync: broadcast HELLO to the guild when the roster first populates.
    -- The event fires in bursts while the roster streams in, so this only
    -- INVALIDATES the cached roster set; the next lookup rebuilds it once.
    addon:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        self._guildSet = nil
        self:OnGuildChanged()
    end)

    -- Auto-sync contacts on login, and make sure the guild roster loads so
    -- OnGuildChanged can announce us when it populates (the reliable, roster-timed
    -- trigger on both a cold login and a /reload). The delayed BroadcastGuildHello
    -- here is a fallback; BroadcastGuildHello's throttle dedups the two paths.
    -- PLAYER_ENTERING_WORLD also fires on every zone-in, dungeon, battleground and
    -- boat ride; only a real login or /reload may re-run the sync burst.
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
        if isInitialLogin == nil and isReloadingUi == nil then
            if self._didLoginSync then return end    -- client passed neither arg
            self._didLoginSync = true
        elseif not (isInitialLogin or isReloadingUi) then
            return
        end
        if GuildRoster then GuildRoster() end
        C_Timer.After(5, function()
            self:SyncOnlineContacts()
            self:BroadcastGuildHello()
            self:RunOrderMaintenance(true)
        end)
    end)

    -- Debounced incremental updates on inventory/profession changes. A learned
    -- recipe, a skill-up or a started cooldown moves no items, so BAG_UPDATE
    -- alone left peers holding stale profession data indefinitely.
    for _, event in ipairs({ "BAG_UPDATE", "SKILL_LINES_CHANGED", "TRADE_SKILL_UPDATE" }) do
        addon:RegisterEvent(event, function()
            self:QueueIncrementalUpdate()
        end)
    end

    -- Offline detection: the server answers a whisper to a logged-out player with
    -- a system line. Suppress it (we sent the whisper, not the user) and back off
    -- that contact for a while. Inert if the client never emits the line.
    if ChatFrame_AddMessageEventFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
            return Comm:OnSystemMessage(text)
        end)
    else
        addon:RegisterEvent("CHAT_MSG_SYSTEM", function(_, text)
            Comm:OnSystemMessage(text)
        end)
    end

    -- Housekeeping tickers. NewTicker is absent from the test harnesses (and from
    -- very old clients), so the sweeps are optional, never required for correctness.
    if C_Timer.NewTicker then
        C_Timer.NewTicker(SESSION_TTL, function() Comm:SweepSessionTables() end)
        C_Timer.NewTicker(3600, function() Comm:RunOrderMaintenance(false) end)
    end

    self._inGroup = IsInGroup()
    self._inGuild = IsInGuild()
    self._ready = true
end

-- Debug toggle (/pb debug, owned by Core, stored as settings.debugComm). When on,
-- a handler error prints instead of vanishing into the dispatch pcall.
function Comm:DebugEnabled()
    return (addon.db and addon.db.settings and addon.db.settings.debugComm) == true
end

----------------------------------------------------------------------
-- Sending helpers
----------------------------------------------------------------------
-- prio is the ChatThrottleLib pipe: "BULK" for payload traffic (a full sync is
-- ~80 chunks and would otherwise head-of-line block everything behind it),
-- "ALERT" for order traffic, "NORMAL" for the rest. Distinct priorities get
-- separate rings and an equal share of the byte budget.
function Comm:Send(msgType, data, channel, target, prio)
    if not self._ready then return end

    data = data or {}
    data._type = msgType
    data._commrev = COMM_REV

    local serialized = AceSerializer:Serialize(data)
    AceComm:SendCommMessage(PREFIX, serialized, channel, target, prio or "NORMAL")
end

-- Canonical "Name-Realm" for every key compare in this file. Core owns the
-- logic (addon:NormKey); this is a local alias so the call sites stay short.
local function normFullKey(key)
    return addon:NormKey(key)
end

function Comm:SendWhisper(msgType, data, target, prio)
    -- Same-realm targets are addressed by short name. A cross-realm target
    -- keeps its full Name-Realm: stripping it would deliver the payload to a
    -- same-named STRANGER on our own realm.
    if type(target) ~= "string" then return end
    local name, realm = target:match("^([^-]+)%-?(.*)$")
    if not name then return end
    -- Remember who we just whispered so the "no player named" system line can be
    -- attributed to an addon whisper rather than something the user typed.
    self._recentWhispers = self._recentWhispers or {}
    self._recentWhispers[name] = time()
    if realm ~= "" and addon:NormRealm(realm) ~= addon:NormRealm(GetRealmName()) then
        self:Send(msgType, data, "WHISPER", name .. "-" .. realm, prio)
    else
        self:Send(msgType, data, "WHISPER", name, prio)
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
-- Sized for what a real TBC character can reach (two primaries plus cooking,
-- first aid and fishing; a maxed profession lands in the low hundreds of
-- recipes), not for what the wire format allows: at 16 x 2000 one accepted
-- payload could write ~4 MB of SavedVariables for a single peer.
local MAX_PROFESSIONS      = 12    -- professions per remote character
local MAX_RECIPES_PER_PROF = 600   -- recipe names per profession
local MAX_RECIPES_TOTAL    = 3000  -- recipe names across ALL professions in one payload
local MAX_INV_ENTRIES      = 5000  -- itemID entries per bags/bank map

-- Control characters first (a remote name or note carrying \n splits into extra
-- chat lines that look like separate system messages), then TRUNCATE, then
-- escape pipes. Truncating after the escape could cut a "||" in half and leave a
-- dangling "|", which swallows whatever follows it in a concatenated chat line.
local function sanStr(s, maxLen)
    if type(s) ~= "string" or s == "" then return nil end
    s = s:gsub("%c", " ")
    if maxLen and #s > maxLen then s = s:sub(1, maxLen) end
    if s == "" then return nil end
    return (s:gsub("|", "||"))
end

-- NaN is reachable over the wire (AceSerializer rebuilds a float from an
-- unvalidated mantissa/exponent pair, so "^F0^f9999" deserializes to NaN) and
-- every comparison against it is false, so it slips past both clamps below. A
-- NaN epoch would wedge delta sync for that peer permanently.
local function sanInt(v, minV, maxV, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    v = math.floor(v)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

-- Positive integer ID within range, or nil (0 / junk means "absent").
local function sanID(v, maxV)
    v = tonumber(v)
    if not v or v ~= v then return nil end
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

-- Like sanCounts but a count of 0 is KEPT: in an INCR delta, 0 means "removed".
local function sanDelta(t, maxEntries)
    local out, n = {}, 0
    if type(t) ~= "table" then return out end
    for rawID, rawCount in pairs(t) do
        local id = sanID(rawID, 10^7)
        local count = tonumber(rawCount)
        if id and count and count >= 0 then
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

-- Guild roster cache. Scanning the whole roster per inbound message cost 500
-- GetGuildRosterInfo calls plus 1000 string operations per message in a large
-- guild, on the main thread inside the CHAT_MSG_ADDON handler. The set is built
-- once and invalidated (not rebuilt) by GUILD_ROSTER_UPDATE, which fires in
-- bursts while the roster streams in.
function Comm:RebuildGuildSet()
    if not IsInGuild() then
        self._guildSet = nil
        return nil
    end
    local n = GetNumGuildMembers() or 0
    -- Roster not delivered yet. Caching the empty set here would deny every
    -- guildmate until the next roster event, so leave the cache cold instead.
    if n == 0 then return nil end
    local set = {}
    for i = 1, n do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        local key = name and normFullKey(name)
        if key then set[key] = { online = online and true or false } end
    end
    self._guildSet = set
    return set
end

-- The cached set, or nil while the roster is still loading.
function Comm:GuildSet()
    if not IsInGuild() then
        self._guildSet = nil
        return nil
    end
    return self._guildSet or self:RebuildGuildSet()
end

-- Realm-aware guild-roster membership. Mirrors IsGroupMember: guild trust is
-- LIVE (checked against the current roster), never persisted -- leaving the
-- guild ends the trust, exactly as leaving a group does.
function Comm:IsGuildMember(senderKey)
    if not IsInGuild() then return false end
    local want = normFullKey(senderKey)
    if not want then return false end
    local set = self:GuildSet()
    if set then return set[want] ~= nil end
    -- Roster still loading: one direct scan, nothing cached.
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name = GetGuildRosterInfo(i)   -- "Name" or "Name-Realm"
        if name and normFullKey(name) == want then return true end
    end
    return false
end

-- Is this guildmate online right now? nil means "the roster has not loaded yet",
-- which the panels render differently from a definite false (a board entry stays
-- visible with Claim disabled rather than disappearing during a loading screen).
function Comm:GuildOnline(key)
    if not IsInGuild() then return false end
    local set = self:GuildSet()
    if not set then return nil end
    local want = normFullKey(key)
    local entry = want and set[want]
    return (entry and entry.online) == true
end

-- Trust tier, most specific first: an explicitly trusted contact, a current
-- party/raid member, a current guildmate. nil = a stranger, whose messages are
-- dropped at the door. The tier decides HOW MUCH a peer may pull, not just
-- whether we listen: see HandleSyncRequest.
function Comm:TrustLevel(senderKey)
    local key = normFullKey(senderKey)
    if not key then return nil end
    local contact = addon.db.contacts and addon.db.contacts[key]
    if contact and contact.trusted then return "contact" end
    if self:IsGroupMember(key) then return "group" end
    if self:IsGuildMember(key) then return "guild" end
    return nil
end

function Comm:IsTrusted(senderKey)
    return self:TrustLevel(senderKey) ~= nil
end

-- May this peer push us a payload we did not ask for? Any contact (the autoSync
-- baseline and the profession-change push are unsolicited by design), or a
-- current group member. A guild-only peer only while a request of ours to them
-- is still outstanding, so one guildmate cannot write a permanent character
-- record onto every PB client in the guild unasked.
function Comm:AcceptsPush(senderKey)
    local key = normFullKey(senderKey)
    if not key then return false end
    if addon.db.contacts and addon.db.contacts[key] then return true end
    if self:IsGroupMember(key) then return true end
    local due = self._pendingReq and self._pendingReq[key]
    return (due ~= nil) and (time() - due) <= PENDING_REQ_TTL
end

-- Privacy master switch: when off, we send NO profession/inventory data
-- to anyone (gated at the two payload builders, which covers every
-- outbound path). Toggle with /pb comm on|off. Default on.
function Comm:SharingEnabled()
    return not (addon.db and addon.db.settings) or addon.db.settings.shareData ~= false
end

-- Which transport each message type may legally arrive on. Everything directed
-- at one player is whisper-only: without this, ONE guild-channel SYNC_REQ pulls
-- every PB guildmate's bags and bank, and one guild-channel ORDER_NEW turns
-- every guildmate's ack-on-refusal into a reflection amplifier.
local WHISPER_ONLY  = { WHISPER = true }
local BROADCASTABLE = { WHISPER = true, PARTY = true, RAID = true, GUILD = true }
local ALLOWED_DIST = {
    SYNC_REQ     = WHISPER_ONLY,
    SYNC_DATA    = WHISPER_ONLY,
    INCR         = WHISPER_ONLY,
    HELLO_ACK    = WHISPER_ONLY,
    ORDER_NEW    = WHISPER_ONLY,
    ORDER_UPDATE = WHISPER_ONLY,
    ORDER_ACK    = WHISPER_ONLY,
    ORDER_CLAIM  = WHISPER_ONLY,
    HELLO        = BROADCASTABLE,
    ORDER_OPEN   = BROADCASTABLE,
    ORDER_CLOSED = BROADCASTABLE,
}

function Comm:OnMessageReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then return end

    -- Canonical Name-Realm: the same spelling contacts, orders and characters
    -- are keyed by, so every compare below is a plain string compare.
    sender = normFullKey(sender)
    if not sender then return end

    -- Ignore our own messages (a GUILD broadcast comes back to us)
    if addon:SameKey(sender, addon:PlayerKey()) then return end

    -- SECURITY: only process messages from known players (a saved
    -- contact, a current group member, or a current guildmate).
    if not self:IsTrusted(sender) then return end

    local ok, data = AceSerializer:Deserialize(message)
    if not ok or type(data) ~= "table" then return end

    local msgType = data._type
    if type(msgType) ~= "string" then return end

    local allowed = ALLOWED_DIST[msgType]
    if not (allowed and allowed[distribution]) then return end

    local contact = addon.db.contacts[sender]
    if contact then
        -- Remember the sender's protocol revision so we only send INCR deltas
        -- (COMM_REV 7) to peers that understand them; older peers keep full syncs.
        -- Through sanInt like every other remote number: this one is written to
        -- SavedVariables and read back as a control value (rev < 7 picks full
        -- syncs over deltas), and NaN is truthy, so an unclamped value would
        -- persist and silently route that peer down the wrong branch forever.
        -- The outer nil test stays: an absent _commrev must leave it nil.
        local rev = tonumber(data._commrev)
        if rev then contact.lastCommRev = sanInt(rev, 0, 1000, 0) end
        -- They are demonstrably online, so lift any offline back-off.
        contact.offlineUntil = nil
    end

    -- Dispatch under pcall so a malformed payload (even from a trusted
    -- player) can never throw a visible Lua error in our client. The outbox
    -- flush belongs INSIDE it: an error there is no more the user's problem
    -- than an error in a handler. /pb debug surfaces both.
    local done, err = pcall(function()
        if msgType == "HELLO" then
            self:HandleHello(sender, data, distribution)
        elseif msgType == "HELLO_ACK" then
            self:HandleHelloAck(sender, data, distribution)
        elseif msgType == "SYNC_REQ" then
            self:HandleSyncRequest(sender, data, distribution)
        elseif msgType == "SYNC_DATA" then
            self:HandleSyncData(sender, data, distribution)
        elseif msgType == "INCR" then
            self:HandleIncr(sender, data, distribution)
        elseif msgType == "ORDER_NEW" then
            self:HandleOrderNew(sender, data, distribution)
        elseif msgType == "ORDER_UPDATE" then
            self:HandleOrderUpdate(sender, data, distribution)
        elseif msgType == "ORDER_ACK" then
            self:HandleOrderAck(sender, data, distribution)
        elseif msgType == "ORDER_OPEN" then
            self:HandleOrderOpen(sender, data, distribution)
        elseif msgType == "ORDER_CLAIM" then
            self:HandleOrderClaim(sender, data, distribution)
        elseif msgType == "ORDER_CLOSED" then
            self:HandleOrderClosed(sender, data, distribution)
        end
        -- Any message from a trusted peer proves they're online -- deliver any
        -- order messages we had queued for them while offline.
        self:FlushOutbox(sender)
    end)
    if not done and self:DebugEnabled() then
        print("|cff00ccffProfessionBuddy:|r comm error handling " .. msgType
            .. " from " .. sender .. ": " .. tostring(err))
    end
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

-- 20 s, not 8: an order message can sit behind a full sync in the peer's send
-- queue. At ChatThrottleLib's 800 bytes/second an 80-chunk payload owns the pipe
-- for the better part of half a minute, and the 8 s timeout fired against
-- perfectly healthy peers, printing "is offline" for a delivered order.
local ORDER_ACK_TIMEOUT = 20         -- seconds to wait for a delivery ack
local PENDING_ACK_TTL   = 600        -- evict an ack slot whose timer never ran
local pendingOrderAck = {}           -- token -> { target, at, timer = <C_Timer> }

-- How long an undelivered order message stays queued. Orders:SweepOutbox owns
-- this window once merged; this mirrors its rule (settings.orderExpiryDays,
-- 0 = off) so the two can never disagree about what to drop.
local function outboxTTL()
    local days = (addon.db and addon.db.settings and addon.db.settings.orderExpiryDays) or 14
    if days <= 0 then return nil end
    return days * 86400
end

-- Local-only bookkeeping that must never ride the wire: the receiver would
-- store our delivery indicator as if it were theirs.
local LOCAL_ONLY_ORDER_FIELDS = {
    lastSentToken = true, deliveryState = true, lastSentBy = true, dismissed = true,
}

-- Wire copy of an order record. The outbox is persisted, so parking the LIVE
-- table there both duplicated every queued order into SavedVariables and let
-- fields written after the send ride along on the resend.
local function wireOrder(order)
    if type(order) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(order) do
        if not LOCAL_ONLY_ORDER_FIELDS[k] then out[k] = v end
    end
    if type(order.item) == "table" then
        out.item = { id = order.item.id, name = order.item.name,
                     profession = order.item.profession }
    end
    return out
end

-- The other party on an order, from my point of view.
function Comm:OrderCounterparty(order)
    local me = addon:PlayerKey()
    if addon:SameKey(order.requester, me) then return order.crafter end
    if addon:SameKey(order.crafter, me)   then return order.requester end
    return nil
end

local function shortName(key)
    return addon:ShortName(key) or "?"
end

-- Case-folded canonical key, for the manual-sync watch only. Reconciles a
-- user-typed sync target (the slash handler lowercases it and it may lack a
-- realm) with the proper-case Name-Realm form AceComm reports for the reply, so
-- the watch clears instead of firing a false "didn't respond".
local function normKey(key)
    local k = normFullKey(key)
    return k and k:lower() or nil
end

-- Send an order message to the counterparty and track delivery. If no
-- ORDER_ACK returns within the timeout, the message is parked in a
-- persisted outbox and auto-resent the next time we hear from that
-- player (any PB message proves they are online). isResend is true for
-- automatic retries and suppresses the one-time "queued" warning.
function Comm:SendOrderMessage(msgType, data, target, label, isResend)
    if not self._ready or not data or not data.token then return end
    local token = data.token
    self:SendWhisper(msgType, data, target, "ALERT")
    local prev = pendingOrderAck[token]
    if prev and prev.timer then prev.timer:Cancel() end
    pendingOrderAck[token] = {
        target = target,
        at = time(),
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
                queuedAt = (existing and existing.queuedAt) or time(),
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

-- Recipient -> sender: confirm an order message was received. rejected marks
-- "received but not applied" (failed anti-spoof, or an order we do not have):
-- the ack still drains their outbox, and the indicator tells them the truth
-- instead of showing a delivered order that the other side never stored.
function Comm:SendOrderAck(target, token, rejected)
    if not self._ready then return end
    -- The token is echoed straight back off the wire, and the refusal paths ack
    -- BEFORE anything else about the message is validated, so a peer could make
    -- us re-serialize a 60 KB string (or a table) onto the ALERT pipe for every
    -- message they send. No usable token means no ack; the message is still
    -- processed, it just goes unconfirmed.
    if type(token) ~= "string" or token == "" or #token > 64 then return end
    local payload = { token = token }
    if rejected then payload.rejected = true end
    self:SendWhisper("ORDER_ACK", payload, target, "ALERT")
end

-- One shared floor for every reply we send purely because a peer handed us
-- something we cannot use: the refused ORDER_NEW ack, the ack for an
-- ORDER_UPDATE naming an order we do not hold, and the self-heal close for a
-- claim on an id we do not hold. Each is a 1:1 whisper on the ALERT pipe that
-- needs no local state to elicit, so a flood of junk ids from one trusted peer
-- would otherwise queue ahead of our real order traffic. First reply per sender
-- always goes out; the rest of that burst is dropped.
function Comm:ReflexAllowed(sender)
    local key = normFullKey(sender)
    if not key then return false end
    self._reflexAt = self._reflexAt or {}
    local now = time()
    local last = self._reflexAt[key]
    if last and (now - last) < REFLEX_FLOOR then return false end
    self._reflexAt[key] = now
    return true
end

function Comm:HandleOrderAck(sender, data, distribution)
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
        o.deliveryState = (data.rejected == true) and "rejected" or "delivered"
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
    local want = normFullKey(target)
    if not want then return end
    local now = time()
    local ttl = outboxTTL()
    local due = {}
    for token, entry in pairs(ob) do
        if type(entry) ~= "table" then
            ob[token] = nil
        else
            -- An entry queued by an older build carries no stamp; start its
            -- clock now rather than dropping a message that may still be wanted.
            if not tonumber(entry.queuedAt) then entry.queuedAt = now end
            if ttl and (now - entry.queuedAt) > ttl then
                ob[token] = nil                   -- nobody could take delivery
            -- Full-key match: "Bob-OurRealm" coming online must not fire a
            -- resend of everything queued for "Bob-OtherRealm".
            elseif not pendingOrderAck[token] and normFullKey(entry.target) == want then
                table.insert(due, token)
            end
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
            local data = self:RefreshOutboxPayload(entry)
            if data then
                self:SendOrderMessage(entry.msgType, data, entry.target,
                    entry.label, true)
            else
                ob[token] = nil          -- the order is gone locally
            end
        end
    end
end

-- Rebuild a parked ORDER_NEW from the live record at flush time. The order may
-- have been cancelled or edited while the counterparty was offline, and a stale
-- parked copy would hand them a record we no longer hold. Status updates are a
-- flat snapshot whose token encodes the status they announce, so they resend
-- exactly as parked.
function Comm:RefreshOutboxPayload(entry)
    local data = entry.data
    if type(data) ~= "table" then return nil end
    if entry.msgType ~= "ORDER_NEW" then return data end
    local id = type(data.order) == "table" and data.order.id
    local live = id and addon.db.orders and addon.db.orders[id]
    if not live then return nil end
    data.order = wireOrder(live)
    return data
end

-- Requester -> crafter: a brand-new order (full record). fromClaim rides on the
-- ORDER record (Orders:UpsertFromRemote stores it) so the crafter's client can
-- say "your claim was accepted" instead of announcing a fresh request.
function Comm:SendOrderNew(order, fromClaim)
    if not self._ready or not order then return end
    local cp = self:OrderCounterparty(order)
    if not cp then return end
    local token = order.id .. ":new"
    local payload = { order = wireOrder(order), token = token }
    if fromClaim then payload.order.fromClaim = true end
    self:SendOrderMessage("ORDER_NEW", payload, cp, "request")
    -- Delivery indicator. "sent" -> "delivered" on ack, "rejected" if they
    -- received but refused it, "queued" on timeout.
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

-- Ingress caps for the directed path. A directed order is a permanent
-- SavedVariables key here exactly like a board post, and lands as PENDING, which
-- PruneHistory never reclaims -- only the 14-day ExpireStale does. Counted
-- before the record is built.
local REMOTE_MAX_PER_REQUESTER = 25   -- non-terminal orders one requester may hold on us
local REMOTE_MAX_TOTAL         = 300  -- records in db.orders, past which we create no more

local function orderIngressRoom(requesterKey)
    local orders = addon.db and addon.db.orders
    if not orders then return true end
    local TERMINAL = (addon.Orders and addon.Orders.TERMINAL) or {}
    local key = normFullKey(requesterKey)
    local total, mine = 0, 0
    for _, o in pairs(orders) do
        if type(o) == "table" then
            total = total + 1
            if not TERMINAL[o.status] and normFullKey(o.requester) == key then
                mine = mine + 1
            end
        end
    end
    return mine < REMOTE_MAX_PER_REQUESTER and total < REMOTE_MAX_TOTAL
end

function Comm:HandleOrderNew(sender, data, distribution)
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
    -- Bind the id to its owner, the same way the board path does. Ids are
    -- "<requesterKey>-<seq>" and so are guessable, and UpsertFromRemote treats an
    -- id it already holds as a duplicate: without this a guildmate could squat
    -- the ids someone has not minted yet and every real order of theirs would be
    -- swallowed for good, acked back to them as delivered.
    local owner = o.id:match("^(.+)%-%d+$")
    if not owner or not addon:SameKey(owner, o.requester) then
        if self:ReflexAllowed(sender) then self:SendOrderAck(sender, data.token, true) end
        return
    end
    -- Realm-aware anti-spoof: the creator must BE the sender and the order must
    -- be addressed to us. Ack even on refusal (an ack means "received", not
    -- "applied") so a rejected peer stops re-queuing and retrying forever.
    if not addon:SameKey(o.requester, sender)
       or not addon:SameKey(o.crafter, addon:PlayerKey()) then
        if self:ReflexAllowed(sender) then self:SendOrderAck(sender, data.token, true) end
        return
    end
    -- Caps apply to ids we do NOT already hold, so a resend of a known order is
    -- still idempotent (that is the outbox flush, and it must keep working).
    -- Over a cap we return with NO ack at all: the sender's outbox then keeps the
    -- entry and retries later instead of marking it permanently rejected.
    if not (addon.db.orders and addon.db.orders[o.id]) and not orderIngressRoom(o.requester) then
        return
    end
    local order, applied = Orders:UpsertFromRemote(o)
    -- Ack even duplicates and refusals (an ack means "received", not "applied",
    -- and it clears the sender's offline warning); only notify on a genuinely
    -- new order so dupes don't double-chat.
    self:SendOrderAck(sender, data.token, order == nil)
    -- One kind for both cases: the claim handoff is marked by fromClaim on the
    -- stored record, and the panel picks its wording from there.
    if applied then self:NotifyOrders("newRequest", order) end
end

function Comm:HandleOrderUpdate(sender, data, distribution)
    local Orders = addon.Orders
    if not Orders or type(data.id) ~= "string" then return end
    -- Anti-spoof: the update may only come from the order's actual
    -- counterparty. Reject updates to orders we don't have or that the
    -- sender isn't a party to (blocks strangers/others poking orders).
    local existing = addon.db.orders and addon.db.orders[data.id]
    if not existing then
        -- We don't have it (deleted, version skew). Ack so the peer stops
        -- retrying, but there is nothing to apply. Floored with the other
        -- reflex replies: this one needs no local state to elicit either.
        if self:ReflexAllowed(sender) then self:SendOrderAck(sender, data.token, true) end
        return
    end
    local cp = self:OrderCounterparty(existing)
    if not cp or not addon:SameKey(cp, sender) then return end
    -- Which side of the order is the sender? Passed down so the status change is
    -- checked against that role's legal moves and completedBy can't be forged
    -- (a crafter can't claim the requester confirmed receipt).
    local senderRole = addon:SameKey(cp, existing.requester) and "requester" or "crafter"
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
-- Guild order board (COMM_REV 6): open orders any guildmate can claim.
-- The requester is the authority for their own opens: post -> broadcast
-- ORDER_OPEN; a crafter's ORDER_CLAIM is a request TO the requester, who
-- accepts the FIRST valid claim, hands off via the existing ORDER_NEW path,
-- and broadcasts ORDER_CLOSED so everyone else drops it. Guild-trust gated.
----------------------------------------------------------------------

-- Board limits. A board entry is a permanent SavedVariables key on every
-- guildmate's client, so the ingress caps bound what one sender (and the guild
-- as a whole) can write there.
local BOARD_MAX_PER_REQUESTER = 20
local BOARD_MAX_TOTAL         = 200
local BOARD_POST_COOLDOWN     = 5    -- seconds between accepted NEW posts per sender
local BOARD_SEND_SPACING      = BOARD_POST_COOLDOWN + 1  -- our own sends, spaced past it
local VALID_MATRESP = { requester = true, crafter = true, split = true }

-- Requester -> guild: announce an open order to the board.
-- Receivers drop a second NEW post from the same sender inside
-- BOARD_POST_COOLDOWN, with no queue and no retry, so two posts composed back to
-- back left the second invisible to the whole guild until our next login
-- re-broadcast. Space our own sends the way RunOrderMaintenance spaces the login
-- burst, keeping them in order. Deferred sends are tracked by order id so a
-- close can cancel one instead of racing it.
function Comm:BroadcastOpenOrder(order)
    if not self._ready or type(order) ~= "table" then return end
    if not IsInGuild() then return end

    local id = order.id
    local now = time()
    local last = self._lastOpenSendAt or 0
    local wait = 0
    if (now - last) < BOARD_SEND_SPACING then
        wait = BOARD_SEND_SPACING - (now - last)
    end
    self._lastOpenSendAt = now + wait

    local function doSend()
        -- Re-checked at fire time: we may have left the guild or reloaded while
        -- this one waited.
        if not self._ready or not IsInGuild() then return end
        self:Send("ORDER_OPEN", { order = wireOrder(order) }, "GUILD", nil, "ALERT")
    end

    if wait <= 0 then
        doSend()
        return
    end
    self._deferredOpens = self._deferredOpens or {}
    self._deferredOpens[id] = true
    C_Timer.After(wait, function()
        if not (self._deferredOpens and self._deferredOpens[id]) then return end
        self._deferredOpens[id] = nil
        doSend()
    end)
end

-- Requester -> guild (broadcast) or a single crafter (whisper): an open order is
-- no longer available. reason = "assigned" | "cancelled" | "expired".
function Comm:BroadcastOrderClosed(orderId, reason, targetKey)
    if not self._ready or type(orderId) ~= "string" then return end
    -- A close for a post still waiting out the send spacing cancels that send.
    -- Letting the two race would put the entry on every guildmate's board with
    -- the close already gone past it, and nothing left to remove it.
    if self._deferredOpens then self._deferredOpens[orderId] = nil end
    if targetKey then
        self:SendWhisper("ORDER_CLOSED", { orderId = orderId, reason = reason }, targetKey, "ALERT")
    elseif IsInGuild() then
        self:Send("ORDER_CLOSED", { orderId = orderId, reason = reason }, "GUILD", nil, "ALERT")
    end
end

-- Make room for one new post from `key`: over that requester's own cap, drop
-- their oldest; over the board cap, drop the oldest post on the board. Returns
-- false only if the board is somehow full of nothing droppable.
local function makeBoardRoom(board, key)
    local total, mine = 0, 0
    local oldestId, oldestAt, mineId, mineAt
    for id, entry in pairs(board) do
        if type(entry) == "table" then
            local at = tonumber(entry.postedAt) or 0
            total = total + 1
            if not oldestAt or at < oldestAt then oldestId, oldestAt = id, at end
            if normFullKey(entry.requester) == key then
                mine = mine + 1
                if not mineAt or at < mineAt then mineId, mineAt = id, at end
            end
        else
            board[id] = nil
        end
    end
    if mine >= BOARD_MAX_PER_REQUESTER then
        if not mineId then return false end
        board[mineId] = nil
        total = total - 1
    end
    if total >= BOARD_MAX_TOTAL then
        if not oldestId or not board[oldestId] then return false end
        board[oldestId] = nil
    end
    return true
end

-- Receiver: store a guildmate's open order on our board. The sender IS the
-- requester (you cannot post on someone else's behalf), and only guildmates
-- can populate the board. Rebuilt field-by-field, sanitized.
function Comm:HandleOrderOpen(sender, data, distribution)
    if not self:IsGuildMember(sender) then return end
    local o = data.order
    if type(o) ~= "table" or type(o.id) ~= "string" or type(o.item) ~= "table" then return end
    local id = o.id
    -- The id becomes a permanent SavedVariables key, so bound and charset-check
    -- it. A legacy id minted on a multi-word realm contains a space.
    if #id == 0 or #id > 64 or not id:match("^[%w%-'_ ]+$") then return end
    -- Bind the id to its poster. Order ids are "<requesterKey>-<seq>" and so are
    -- guessable, and the stored requester is forced to the sender: without this
    -- check a guildmate could post "Alice-Realm-3" and take ownership of Alice's
    -- entry on every board (then close it, or collect her claims). Refusing only
    -- to OVERWRITE a different requester would still allow squatting on an id
    -- Alice has not posted yet; deriving the owner from the id closes both.
    local owner = id:match("^(.+)%-%d+$")
    if not owner or not addon:SameKey(owner, sender) then return end

    local key = normFullKey(sender)
    local board = addon.db.orderBoard or {}
    addon.db.orderBoard = board
    local prev = board[id]
    local now = time()

    if not prev then
        -- Rate limit and caps apply to NEW ids only: re-receiving a post we
        -- already hold is the login re-broadcast, and must stay idempotent.
        self._lastOpenAt = self._lastOpenAt or {}
        local last = self._lastOpenAt[key]
        if last and (now - last) < BOARD_POST_COOLDOWN then return end
        if not makeBoardRoom(board, key) then return end
        self._lastOpenAt[key] = now
    end

    -- A profession we have no static data for is stored as nil (= any crafter),
    -- never as an unrecognized label the filters would silently never match.
    local RDB = addon.RecipeDB
    local prof = sanStr(o.item.profession, 40)
    if prof and RDB and RDB.data and next(RDB.data) and not RDB.data[prof] then
        prof = nil
    end
    local matResp = sanStr(o.matResponsibility, 16)
    local maxQty = (addon.Orders and addon.Orders.MAX_QTY) or 999

    board[id] = {
        id        = id,
        requester = key,
        item = {
            id         = sanID(o.item.id, 10^7),
            name       = sanStr(o.item.name, 128) or "?",
            profession = prof,
        },
        quantity          = sanInt(o.quantity, 1, maxQty, 1),
        matResponsibility = VALID_MATRESP[matResp] and matResp or "requester",
        note              = sanStr(o.note, 256),
        status            = "open",
        -- Keep the original post time so a re-broadcast does not make an old
        -- post look new (and does not dodge the board TTL sweep).
        postedAt          = (prev and tonumber(prev.postedAt)) or now,
    }
    self:NotifyOrders()
end

-- Crafter -> requester: claim an open order off the board.
function Comm:ClaimOrder(order)
    if not self._ready or type(order) ~= "table" or type(order.requester) ~= "string" then return end
    self:SendWhisper("ORDER_CLAIM", { orderId = order.id }, order.requester, "ALERT")
end

-- Requester side: adjudicate a claim. Single authority, so the FIRST valid claim
-- wins deterministically. On assign it collapses into the directed ORDER_NEW flow.
function Comm:HandleOrderClaim(sender, data, distribution)
    if not self:IsGuildMember(sender) then return end
    local Orders = addon.Orders
    local id = data.orderId
    if not Orders or type(id) ~= "string" then return end
    local o = addon.db.orders and addon.db.orders[id]
    if not o then
        -- We have no record at all: the post expired or was pruned here while it
        -- was still on their board. Close it for them so the board self-heals
        -- instead of leaving a dead entry they keep claiming. Floored with the
        -- other reflex replies (a claim on a random id costs us a whisper).
        if self:ReflexAllowed(sender) then
            self:BroadcastOrderClosed(id, "cancelled", sender)
        end
        return
    end
    if not addon:SameKey(o.requester, addon:PlayerKey()) then return end   -- not my order
    if o.status ~= Orders.STATUS.OPEN then
        self:BroadcastOrderClosed(id, "assigned", sender)            -- already taken
        return
    end
    local order = Orders:AssignFromClaim(id, normFullKey(sender))
    if not order then return end
    self:SendOrderNew(order, true)                                   -- directed handoff (ACCEPTED)
    self:BroadcastOrderClosed(id, "assigned")                       -- everyone drops it
    self:NotifyOrders("assigned", order)
end

-- Receiver: remove a closed open order from our board. Anti-spoof: only the
-- order's own requester (the poster) may close it.
function Comm:HandleOrderClosed(sender, data, distribution)
    local id = data.orderId
    if type(id) ~= "string" then return end
    local board = addon.db.orderBoard
    if not board or not board[id] then return end
    if not addon:SameKey(board[id].requester, sender) then return end
    board[id] = nil
    self:NotifyOrders()
end

----------------------------------------------------------------------
-- Board lifecycle: expire, sweep, re-announce.
-- Runs once from the login timer (with the re-broadcast) and hourly after that
-- (without). Orders.lua owns the expiry rules; everything here is the wire half.
----------------------------------------------------------------------
function Comm:RunOrderMaintenance(isLogin)
    local Orders = addon.Orders
    if not Orders then return end

    local expiredIds
    if Orders.ExpireStale then
        local _, ids = Orders:ExpireStale()
        expiredIds = ids or {}                -- pre-merge ExpireStale returns a count only
    end
    for _, id in ipairs(expiredIds or {}) do
        self:BroadcastOrderClosed(id, "expired")
    end
    if Orders.SweepBoard then Orders:SweepBoard() end
    if Orders.SweepOutbox then Orders:SweepOutbox() end

    if not isLogin or not Orders.GetMyOpen then return end
    -- Re-announce our still-open posts so guildmates' boards repopulate. Spaced
    -- past the receiver's per-sender ORDER_OPEN cooldown, otherwise a client
    -- seeing these ids for the first time would accept only the first one.
    local mine = Orders:GetMyOpen()
    for i, order in ipairs(mine) do
        if i == 1 then
            self:BroadcastOpenOrder(order)
        else
            C_Timer.After((i - 1) * (BOARD_POST_COOLDOWN + 1), function()
                self:BroadcastOpenOrder(order)
            end)
        end
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

function Comm:SendHelloAck(target)
    local payload = self:BuildHelloPayload()
    if payload then
        self:SendWhisper("HELLO_ACK", payload, target)
    end
end

-- A contact with autoSync gets a full pull after a hello, jittered so a raid
-- night's worth of simultaneous logins does not fire every pull in one second.
function Comm:PullAfterHello(senderKey)
    local contact = addon.db.contacts[senderKey]
    if not (contact and contact.autoSync) then return end
    -- One pull per sender per minute. HELLO and HELLO_ACK are both handled here
    -- and neither is floored on ingest, so a peer looping either would otherwise
    -- have us emit a SYNC_REQ whisper of our own for every message they send.
    self._helloPullAt = self._helloPullAt or {}
    local now = time()
    local last = self._helloPullAt[senderKey]
    if last and (now - last) < HELLO_PULL_FLOOR then return end
    self._helloPullAt[senderKey] = now
    C_Timer.After(1 + math.random() * 9, function()
        self:RequestSync(senderKey)
    end)
end

function Comm:HandleHello(sender, data, distribution)
    -- Store lightweight summary so we know what they have
    self:StoreLightweight(sender, data)

    -- Answer with our own summary. The ack is how someone logging in later
    -- learns about guildmates who broadcast before they arrived, so a guild
    -- hello IS answered -- but one broadcast reaches every PB guildmate at
    -- once, so the replies are floored per sender and spread over a few
    -- seconds rather than arriving as one N-whisper burst.
    self._helloAckAt = self._helloAckAt or {}
    local last = self._helloAckAt[sender]
    if not (last and (time() - last) < HELLO_ACK_FLOOR) then
        self._helloAckAt[sender] = time()
        if distribution == "GUILD" then
            C_Timer.After(1 + math.random() * 5, function()
                self:SendHelloAck(sender)
            end)
        else
            self:SendHelloAck(sender)
        end
    end

    self:PullAfterHello(sender)
end

function Comm:HandleHelloAck(sender, data, distribution)
    self:StoreLightweight(sender, data)
    self:PullAfterHello(sender)
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
    -- Every remote write path stamps lastSeen: DataStore's 30-day sweep reads it,
    -- and a guildmate we only ever meet through HELLO has no other stamp.
    char.lastSeen = time()
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

    self:QueueUIRefresh()
end

----------------------------------------------------------------------
-- Notify all visible UI surfaces to refresh after incoming data
----------------------------------------------------------------------

-- Coalesced repaint. One HELLO on the guild channel reaches every PB client at
-- once and each summary stored here rebuilds the Friends, Guild, Find-a-Crafter
-- and Character panels, so a guildmate looping HELLO could hold the whole UI in
-- a repaint loop. One trailing timer caps it at a repaint a second, however many
-- summaries land.
function Comm:QueueUIRefresh()
    if self._uiRefreshPending then return end
    self._uiRefreshPending = C_Timer.NewTimer(UI_REFRESH_COALESCE, function()
        self._uiRefreshPending = nil
        self:NotifyUIRefresh()
    end)
end

function Comm:NotifyUIRefresh()
    -- Friends panel
    if addon.FriendsPanel and addon.FriendsPanel.Refresh then
        addon.FriendsPanel:Refresh()
    end
    -- Guild panel: refresh so incoming guildmate data (professions from a HELLO
    -- or a full sync) appears live, not only after a GUILD_ROSTER_UPDATE.
    if addon.GuildPanel and addon.GuildPanel.Refresh then
        addon.GuildPanel:Refresh()
    end
    -- Find a crafter search: refill results as guildmate recipe syncs land.
    if addon.OrdersPanel and addon.OrdersPanel.findFrame
       and addon.OrdersPanel.findFrame:IsShown()
       and addon.OrdersPanel.RefreshFind then
        addon.OrdersPanel:RefreshFind()
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
    -- Core's NormKey owns the canonical spelling and defaults a missing realm
    -- to ours, so a contact typed as "Bob-Old Blanchy" is stored under the same
    -- key the reply arrives from ("Bob-OldBlanchy").
    if realm == "" then return addon:NormKey(name) end
    return addon:NormKey(name .. "-" .. realm)
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

    -- Record the outstanding request: it is what lets a reply from a peer we
    -- have no other relationship with (a guildmate) be accepted at all.
    self._pendingReq = self._pendingReq or {}
    self._pendingReq[target] = time()

    -- Only manual syncs announce themselves and watch for a reply; auto
    -- syncs stay silent so they don't spam chat.
    if isManual then
        self._pendingSync = self._pendingSync or {}
        local pkey = normKey(target)
        if self._pendingSync[pkey] then
            -- Their serve cooldown is 30 s, so an impatient second /pb sync is
            -- normal and says nothing about them being offline.
            print("|cff00ccffProfessionBuddy:|r already requested, waiting for "
                .. shortName(target) .. ".")
            return
        end
        print("|cff00ccffProfessionBuddy:|r Requesting sync from " .. target .. "...")
        self._pendingSync[pkey] = true
        -- Longer than the peer's 30 s SERVE_COOLDOWN: a 10 s watch expired
        -- before a throttled peer could legitimately answer, so the usual
        -- outcome of a retry was a false "didn't respond".
        C_Timer.After(35, function()
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
-- A guild pull is recipes-only by definition; the panel passes scope = "recipes"
-- to say so explicitly. isManual is the single-target Guild-tab click, which
-- says so when it is throttled; the bulk "Sync guild recipes" sweep stays silent
-- so 40 throttled targets cannot produce 40 chat lines.
function Comm:RequestGuildSync(targetKey, scope, isManual)
    if not self._ready or not targetKey then return end
    local key = normFullKey(targetKey)
    if not key then return end
    self._guildSyncAt = self._guildSyncAt or {}
    local now = time()
    local last = self._guildSyncAt[key]
    if last and (now - last) < GUILD_SYNC_COOLDOWN then
        if isManual then
            print("|cff00ccffProfessionBuddy:|r already requested, waiting for "
                .. shortName(key) .. ".")
        end
        return
    end
    self._guildSyncAt[key] = now
    self._pendingReq = self._pendingReq or {}
    self._pendingReq[key] = now
    -- scope is a HINT. It cannot widen what we are served (the responder decides
    -- from our trust tier), it only says we do not want their inventory.
    self:SendWhisper("SYNC_REQ", { scope = "recipes" }, key)
end

-- Guild-tier serves share one budget across every sender, so an attacker with
-- ten characters cannot simply multiply the per-sender cooldown. Rolling window,
-- pruned on each look; `consume` stamps a serve that actually went out.
function Comm:GuildServeBudget(now, consume)
    local log = self._guildServes or {}
    local kept, n = {}, 0
    for _, at in ipairs(log) do
        if type(at) == "number" and (now - at) < GUILD_SERVE_WINDOW then
            n = n + 1
            kept[n] = at
        end
    end
    self._guildServes = kept
    if consume then
        kept[n + 1] = now
        return true
    end
    return n < GUILD_SERVE_BUDGET
end

function Comm:HandleSyncRequest(sender, data, distribution)
    -- What we serve is decided by the sender's TIER, never by the request: a
    -- contact or group member gets recipes plus inventory as before, a
    -- guild-only peer gets recipes only. A narrower scope in the request is
    -- honored (it asks for less), a wider one is ignored.
    local tier = self:TrustLevel(sender)
    if not tier then return end

    local now = time()
    -- Prune as we go: one entry per distinct sender otherwise accumulates for
    -- the whole session. The window is the LONGEST cooldown in play, or a
    -- guild-tier entry would be dropped before its own cooldown expired.
    for key, servedAt in pairs(lastServed) do
        if (now - servedAt) > GUILD_SERVE_COOLDOWN * 4 then lastServed[key] = nil end
    end
    -- Rate-limit so a SYNC_REQ flood can't make us repeatedly build and
    -- whisper our full payload. (Sharing-off is enforced in the builder.)
    local cooldown = (tier == "guild") and GUILD_SERVE_COOLDOWN or SERVE_COOLDOWN
    if lastServed[sender] and (now - lastServed[sender]) < cooldown then return end
    -- Per-sender limits are priced in alts, so the guild tier also shares one
    -- budget across every sender. Over it we simply do not reply.
    if tier == "guild" and not self:GuildServeBudget(now) then return end

    local scope
    if tier == "guild" or data.scope == "recipes" then scope = "recipes" end
    -- Route through SendFullSync so this serve (re)starts the delta epoch for
    -- this contact and stamps it on the payload, keeping full syncs and INCRs
    -- on one baseline.
    if self:SendFullSync(sender, scope) then
        lastServed[sender] = now
        if tier == "guild" then self:GuildServeBudget(now, true) end
    end
end

-- opts.inventory = false builds a recipes-only payload: no bags, no bank, and
-- partial = true so the receiver keeps whatever inventory it already holds for
-- us instead of replacing it with nothing.
function Comm:BuildFullPayload(opts)
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

    local payload = {
        class = charData.class,
        level = charData.level,
        faction = charData.faction,
        professions = professions,
    }

    if opts and opts.inventory == false then
        payload.partial = true          -- recipes only: no inventory on the wire
        return payload
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
    payload.inventory = inventory
    return payload
end

function Comm:HandleSyncData(sender, data, distribution)
    if not data then return end
    -- We either asked for this, or it comes from someone whose pushes we have
    -- already opted into. Otherwise a guildmate could write a permanent
    -- character record (16 professions x 2000 recipes, 5000 bag and 5000 bank
    -- entries) into our SavedVariables unasked.
    if not self:AcceptsPush(sender) then return end
    if self._pendingReq then self._pendingReq[sender] = nil end

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
    -- A recipes-only payload carries no inventory. Carry the stored one across
    -- instead of rebuilding the record with empty maps, or one Find a Crafter
    -- pull would erase everything we knew about a contact's bags and bank.
    local partial = (data.partial == true) or type(data.inventory) ~= "table"
    local prev = DS:GetCharacter(sender)
    local charRecord = {
        class = sanClass(data.class),
        level = sanInt(data.level, 0, 100, 0),
        faction = sanFaction(data.faction),
        professions = {},
        isRemote = true,
        lastSync = time(),
        lastSeen = time(),
    }
    if partial then
        charRecord.inventory   = (prev and prev.inventory) or { bags = {}, bank = {} }
        charRecord.lastInvSync = prev and prev.lastInvSync
    else
        charRecord.inventory = {
            bags = sanCounts(data.inventory.bags, MAX_INV_ENTRIES),
            bank = sanCounts(data.inventory.bank, MAX_INV_ENTRIES),
        }
        charRecord.lastInvSync = time()
    end

    -- Rebuild profession data with recipe entries
    -- We store recipe names as keys pointing to minimal info
    -- (the UI will cross-reference RecipeDB for full details)
    if type(data.professions) == "table" then
        local nProfs = 0
        -- Running total across professions, not just per profession: the
        -- per-profession cap alone still multiplies by the profession count.
        -- A profession that trips it is stored truncated, not dropped.
        local nRecipes = 0
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
                        if nRecipes >= MAX_RECIPES_TOTAL then break end
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
                            nRecipes = nRecipes + 1
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

    -- Adopt the delta baseline this full payload establishes: later INCRs from
    -- this sender apply on top of this epoch, starting at seq 1. A recipes-only
    -- payload carries no epoch and does not rebase the sender's delta stream,
    -- so the baseline we already hold stays put.
    if data.epoch ~= nil and not partial then
        self:SetRecvState(sender, sanInt(data.epoch, 0, 2^31 - 1, 0), 0)
    end

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

-- Receive-side delta baseline per peer. Persisted on the contact record so a
-- /reload does not cost one full resync per contact; the session table is the
-- working copy. (The SEND side stays session-local on purpose: a reload
-- re-baselines us once, which is correct.)
function Comm:RecvState(key)
    self._recvState = self._recvState or {}
    local rs = self._recvState[key]
    if not rs then
        local contact = addon.db.contacts and addon.db.contacts[key]
        local epoch = contact and tonumber(contact.recvEpoch)
        if epoch then
            rs = { epoch = epoch, seq = tonumber(contact.recvSeq) or 0 }
            self._recvState[key] = rs
        end
    end
    return rs
end

function Comm:SetRecvState(key, epoch, seq)
    self._recvState = self._recvState or {}
    self._recvState[key] = { epoch = epoch, seq = seq }
    local contact = addon.db.contacts and addon.db.contacts[key]
    if contact then
        contact.recvEpoch = epoch
        contact.recvSeq   = seq
    end
end

-- Pull a fresh baseline after a dropped / malformed / out-of-epoch delta, at
-- most once per peer per RESYNC_THROTTLE seconds: without the throttle a peer
-- whose deltas we cannot apply turns every one of their bag changes into a full
-- payload round trip.
function Comm:RequestResync(key)
    self._resyncAt = self._resyncAt or {}
    local now = time()
    local last = self._resyncAt[key]
    if last and (now - last) < RESYNC_THROTTLE then return end
    self._resyncAt[key] = now
    self._pendingReq = self._pendingReq or {}
    self._pendingReq[key] = now
    self:SendWhisper("SYNC_REQ", {}, key)
end

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
-- Snapshot copy of an inventory's bags/bank itemID:count maps. We diff against
-- these snapshots to build deltas, so they must be independent of the live data.
local function copyInv(inv)
    local out = { bags = {}, bank = {} }
    if type(inv) == "table" then
        for id, c in pairs(inv.bags or {}) do out.bags[id] = c end
        for id, c in pairs(inv.bank or {}) do out.bank[id] = c end
    end
    return out
end

-- Changed itemID:count entries between two inventory snapshots. A count of 0
-- marks a removal (the item left that location).
local function invDiff(old, new)
    local d = { bags = {}, bank = {} }
    for _, loc in ipairs({ "bags", "bank" }) do
        local o, nw = old[loc] or {}, new[loc] or {}
        for id, c in pairs(nw) do
            if o[id] ~= c then d[loc][id] = c end
        end
        for id in pairs(o) do
            if nw[id] == nil then d[loc][id] = 0 end
        end
    end
    return d
end

local function diffEmpty(d)
    return not (next(d.bags) or next(d.bank))
end

-- Signature of the NON-inventory state (skill levels, recipe set, cooldowns).
-- A change here forces a full SYNC_DATA rather than a delta, since deltas carry
-- only inventory. Catches skill-ups, learned recipes and cooldown starts.
-- The recipe NAME is folded in, not just a per-recipe constant: a count-only
-- signature matched after dropping one 300-skill profession and levelling a
-- different one to the same numbers, so peers kept showing the old profession
-- forever. Order-independent (a sum), so it does not depend on pairs() order.
local function professionSignature()
    local charData = DS and DS:GetCharacter(addon:PlayerKey())
    if not charData then return 0 end
    local sig = 0
    for profName, prof in pairs(charData.professions or {}) do
        sig = (sig + (prof.skillLevel or 0) * 131) % 2^31
        if type(profName) == "string" and #profName > 0 then
            sig = (sig + #profName * 17 + profName:byte(1)) % 2^31
        end
        for recipeName, info in pairs(prof.recipes or {}) do
            sig = (sig + 13) % 2^31
            if type(recipeName) == "string" and #recipeName > 0 then
                sig = (sig + #recipeName * 7 + recipeName:byte(1)) % 2^31
            end
            if type(info) == "table" and info.cooldownReadyAt then
                sig = (sig + math.floor(info.cooldownReadyAt / 60)) % 2^31
            end
        end
    end
    return sig
end

-- Fresh outer table around a shared payload body. The professions and inventory
-- subtables are built once per push pass and never mutated, but `epoch` and the
-- envelope fields are per target, so the outer table cannot be shared.
local function clonePayload(p)
    local out = {}
    for k, v in pairs(p) do out[k] = v end
    return out
end

-- Send a FULL baseline to one contact and (re)start their delta epoch. Every
-- full sync we emit, a manual serve or an auto baseline, goes through here so
-- the epoch the receiver adopts always matches the one our later INCRs carry.
-- Returns true if a payload was sent.
-- scope "recipes" serves a partial payload (no inventory). payload / inv /
-- profSig are the values SendIncrementalUpdate already computed for this pass;
-- without them a 20-contact push rebuilt the whole payload 20 times.
function Comm:SendFullSync(targetKey, scope, payload, inv, profSig)
    local recipesOnly = (scope == "recipes")
    if recipesOnly then
        payload = self:BuildFullPayload({ inventory = false })
        if not payload then return false end
        -- A recipes-only serve carries no inventory, so it must NOT become the
        -- delta baseline: no epoch bump, no epoch stamp, no snapshot. The
        -- receiver leaves its baseline alone to match.
        self:SendWhisper("SYNC_DATA", payload, targetKey, "BULK")
        return true
    end

    payload = payload and clonePayload(payload) or self:BuildFullPayload()
    if not payload then return false end

    local key = normFullKey(targetKey) or targetKey
    self._pushState = self._pushState or {}
    local st = self._pushState[key] or {}
    -- Seed from the clock, never from 0: a reloaded sender that restarted at 1
    -- could reissue an epoch the receiver still holds from last session, and the
    -- receiver would then apply our deltas onto a baseline that is not ours.
    st.epoch = (st.epoch or time()) + 1
    st.seq = 0
    if inv == nil then
        local charData = DS:GetCharacter(addon:PlayerKey())
        inv = copyInv(charData and charData.inventory)
    end
    st.profSig = profSig or professionSignature()
    -- Only an autoSync contact is ever sent a delta, so only they need the
    -- inventory snapshot the deltas are diffed against. A guildmate we served
    -- once keeps epoch and seq only.
    local contact = addon.db.contacts and addon.db.contacts[key]
    st.inv = (contact and contact.autoSync) and inv or nil
    self._pushState[key] = st
    payload.epoch = st.epoch
    self:SendWhisper("SYNC_DATA", payload, targetKey, "BULK")
    return true
end

-- Auto-push on a debounced BAG_UPDATE. For each autoSync contact we send the
-- smallest correct thing: a full baseline when they are pre-COMM_REV-7, have no
-- baseline yet, or their non-inventory state changed; otherwise just the changed
-- inventory entries as an INCR delta. An unchanged contact gets nothing.
function Comm:SendIncrementalUpdate()
    if not self._ready then return end
    if not self:SharingEnabled() then return end
    self._pushState = self._pushState or {}
    local charData = DS:GetCharacter(addon:PlayerKey())
    local curInv = copyInv(charData and charData.inventory)
    local curProfSig = professionSignature()
    local now = time()
    local payload   -- built at most once per pass, shared by every full sync

    -- Drop push state for peers who are no longer contacts: a removed contact,
    -- or a guildmate we served once. Only contacts are ever pushed to.
    for key in pairs(self._pushState) do
        if not (addon.db.contacts and addon.db.contacts[key]) then
            self._pushState[key] = nil
        end
    end

    for contactKey, contact in pairs(addon.db.contacts) do
        -- Skip a contact the server just told us is not logged in; any message
        -- from them clears the back-off immediately.
        local offline = contact.offlineUntil and contact.offlineUntil > now
        if contact.autoSync and not offline then
            local key = normFullKey(contactKey) or contactKey
            local rev = tonumber(contact.lastCommRev) or 0
            local st = self._pushState[key]
            if not st or not st.epoch or not st.inv then
                payload = payload or self:BuildFullPayload()
                self:SendFullSync(contactKey, nil, payload, curInv, curProfSig)
            else
                local d = invDiff(st.inv, curInv)
                local invChanged = not diffEmpty(d)
                local profChanged = st.profSig ~= curProfSig
                if rev < 7 or profChanged then
                    -- Old client, or a non-inventory change: full sync, but only
                    -- if something actually changed (suppress identical pushes).
                    if invChanged or profChanged then
                        payload = payload or self:BuildFullPayload()
                        self:SendFullSync(contactKey, nil, payload, curInv, curProfSig)
                    end
                elseif invChanged then
                    st.seq = st.seq + 1
                    self:SendWhisper("INCR",
                        { epoch = st.epoch, seq = st.seq, changes = d }, contactKey, "BULK")
                    -- curInv is rebuilt each pass and never mutated afterwards, so
                    -- every contact can share it instead of holding a copy.
                    st.inv = curInv
                end
            end
        end
    end
end

-- Apply an inventory delta from a contact. Ordered + epoch-checked: a delta that
-- is not the exact next one on the baseline we hold is DROPPED, and we pull a
-- fresh full sync so we recover instead of drifting (the required auto-resync).
function Comm:HandleIncr(sender, data, distribution)
    if not data then return end
    if not self:AcceptsPush(sender) then return end
    local rs = self:RecvState(sender)
    local epoch = sanInt(data.epoch, 0, 2^31 - 1, -1)
    local seq   = sanInt(data.seq, 0, 2^31 - 1, -1)
    local char  = DS:GetCharacter(sender)

    -- No baseline, wrong epoch, or a sequence gap: drop and auto-resync.
    if not char or not char.isRemote or not rs
       or epoch ~= rs.epoch or seq ~= rs.seq + 1 then
        self:RequestResync(sender)
        return
    end

    local changes = data.changes
    if type(changes) ~= "table" then
        -- The sender has already advanced its own seq and snapshot, so silently
        -- dropping this would leave us stale until some later delta happened to
        -- expose the gap. Pull a fresh baseline instead.
        self:RequestResync(sender)
        return
    end
    char.inventory = char.inventory or { bags = {}, bank = {} }
    for _, loc in ipairs({ "bags", "bank" }) do
        local dst = char.inventory[loc] or {}
        char.inventory[loc] = dst
        local n = 0
        for _ in pairs(dst) do n = n + 1 end
        for id, count in pairs(sanDelta(changes[loc], MAX_INV_ENTRIES)) do
            if count == 0 then
                if dst[id] ~= nil then dst[id] = nil; n = n - 1 end
            elseif dst[id] ~= nil then
                dst[id] = count
            elseif n < MAX_INV_ENTRIES then
                dst[id] = count; n = n + 1
            end
        end
    end
    char.lastSync = time()
    char.lastSeen = time()
    char.lastInvSync = time()
    self:SetRecvState(sender, rs.epoch, seq)
    if addon.db.contacts[sender] then addon.db.contacts[sender].lastSync = time() end
    self:NotifyUIRefresh()
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

    -- Announce ourselves the first time the guild roster is populated this
    -- session. GUILD_ROSTER_UPDATE fires when the roster actually loads, so this
    -- is reliably timed on a cold login AND a /reload, unlike the old
    -- not-guilded to guilded transition, which never happens on a /reload
    -- because guild data is already warm at ADDON_LOADED. The throttle in
    -- BroadcastGuildHello dedups against the login-timer fallback.
    if inGuild and not self._guildHelloDone then
        self._guildHelloDone = true
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
    local now = time()

    for contactKey, contact in pairs(contacts) do
        -- We can't reliably check if they're online without being in a group or
        -- having them on the friends list, so we just send the request and let
        -- an offline whisper fail silently -- except for contacts the server
        -- recently told us are logged out, which we skip until the back-off ends.
        local offline = contact.offlineUntil and contact.offlineUntil > now
        if contact.autoSync and not offline then
            self:SendWhisper("SYNC_REQ", {}, contactKey)
        end
    end
end

----------------------------------------------------------------------
-- Offline detection
-- The server answers a whisper to a logged-out player with a system line. We
-- sent that whisper, not the user, so the line is suppressed and the contact is
-- backed off instead. If the client never emits the line for addon whispers the
-- whole mechanism is inert and harmless.
----------------------------------------------------------------------
local notFoundPattern   -- built once, lazily (the global is locale-dependent)

local function playerNotFoundPattern()
    if notFoundPattern ~= nil then return notFoundPattern or nil end
    local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
    if type(fmt) ~= "string" then
        notFoundPattern = false
        return nil
    end
    -- Escape the magic characters, then turn the (now escaped) %s into a capture.
    local pat = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    pat = pat:gsub("%%%%s", "(.+)")
    notFoundPattern = "^" .. pat .. "$"
    return notFoundPattern
end

-- Returns true when the line was ours to swallow.
function Comm:OnSystemMessage(text)
    if type(text) ~= "string" then return false end
    local pat = playerNotFoundPattern()
    if not pat then return false end
    local who = text:match(pat)
    if not who then return false end

    local short = addon:ShortName(who)
    local at = self._recentWhispers and short and self._recentWhispers[short]
    if not at or (time() - at) > WHISPER_MEMORY then return false end
    self._recentWhispers[short] = nil

    local key = normFullKey(who)
    local contact = key and addon.db.contacts and addon.db.contacts[key]
    if contact then contact.offlineUntil = time() + OFFLINE_BACKOFF end
    return true
end

----------------------------------------------------------------------
-- Housekeeping
----------------------------------------------------------------------

-- Forget everything we hold about one peer. Called when a contact is removed
-- (Friends panel) and by /pb forget. Safe on a key we have no state for.
function Comm:ForgetPeer(key)
    local k = normFullKey(key)
    if not k then return end
    lastServed[k] = nil
    for _, name in ipairs({ "_pushState", "_recvState", "_guildSyncAt", "_resyncAt",
                            "_helloAckAt", "_helloPullAt", "_reflexAt",
                            "_pendingReq", "_lastOpenAt" }) do
        if self[name] then self[name][k] = nil end
    end
    local pkey = normKey(k)
    if self._pendingSync and pkey then self._pendingSync[pkey] = nil end
    if self._recentWhispers then self._recentWhispers[addon:ShortName(k)] = nil end
    for token, p in pairs(pendingOrderAck) do
        if p.target and normFullKey(p.target) == k then
            if p.timer then p.timer:Cancel() end
            pendingOrderAck[token] = nil
        end
    end
    local ob = addon.db.orderOutbox
    if ob then
        for token, entry in pairs(ob) do
            if type(entry) == "table" and normFullKey(entry.target) == k then
                ob[token] = nil
            end
        end
    end
end

-- TEST-ONLY. Clears the per-sender SYNC_REQ serve cooldown so the harness can
-- drive two serves to one sender inside a single wall-clock second (the whole
-- run happens in one). `lastServed` is a file-local with no other reachable
-- reset, and nothing in the addon calls this.
function Comm:_ResetServeCooldown(key)
    if key then
        local k = normFullKey(key)
        if k then lastServed[k] = nil end
        return
    end
    for k in pairs(lastServed) do lastServed[k] = nil end
end

-- Periodic sweep of everything keyed by peer, so a long session in a large
-- guild cannot grow these tables without bound.
local function sweepByAge(t, maxAge, now)
    if type(t) ~= "table" then return end
    for key, stamp in pairs(t) do
        if type(stamp) ~= "number" or (now - stamp) > maxAge then t[key] = nil end
    end
end

function Comm:SweepSessionTables()
    local now = time()
    sweepByAge(lastServed, SESSION_TTL, now)
    sweepByAge(self._guildSyncAt, SESSION_TTL, now)
    sweepByAge(self._helloAckAt, SESSION_TTL, now)
    sweepByAge(self._helloPullAt, SESSION_TTL, now)
    sweepByAge(self._reflexAt, SESSION_TTL, now)
    sweepByAge(self._resyncAt, SESSION_TTL, now)
    sweepByAge(self._lastOpenAt, SESSION_TTL, now)
    sweepByAge(self._pendingReq, PENDING_REQ_TTL, now)
    sweepByAge(self._recentWhispers, WHISPER_MEMORY * 6, now)

    -- An ack slot whose timer never ran (a cancelled timer, a reload mid-flight).
    for token, p in pairs(pendingOrderAck) do
        if (now - (p.at or now)) > PENDING_ACK_TTL then
            if p.timer then p.timer:Cancel() end
            pendingOrderAck[token] = nil
        end
    end

    -- Push state is only meaningful for contacts we actually push to.
    if self._pushState then
        for key in pairs(self._pushState) do
            local contact = addon.db.contacts and addon.db.contacts[key]
            if not (contact and contact.autoSync) then self._pushState[key] = nil end
        end
    end

    -- Order messages nobody could take delivery of for the whole expiry window.
    local Orders = addon.Orders
    if Orders and Orders.SweepOutbox then
        Orders:SweepOutbox()
        return
    end
    local ob = addon.db.orderOutbox
    local ttl = outboxTTL()
    if ob and ttl then
        for token, entry in pairs(ob) do
            if type(entry) ~= "table" then
                ob[token] = nil
            elseif not tonumber(entry.queuedAt) then
                entry.queuedAt = now
            elseif (now - entry.queuedAt) > ttl then
                ob[token] = nil
            end
        end
    end
end
