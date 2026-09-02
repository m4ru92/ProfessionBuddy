----------------------------------------------------------------------
-- Ghost-partner two-instance comm harness for ProfessionBuddy.
--
-- Loads TWO (or more) fully ISOLATED ProfessionBuddy instances in one Lua
-- state, each with its own ProfBuddy / ProfBuddyDB and its own WoW-API stubs,
-- and wires a ROUTER between their AceComm send and receive. That turns a real
-- cross-client conversation (HELLO handshake, SYNC request/serve, order
-- lifecycle, and later the guild trust/sync arm) into something you can drive
-- and assert end to end with NO second game client.
--
-- Companion to pb_harness.lua (single instance, hand-fed payloads). This one
-- exists for the multi-round conversations pb_harness cannot express, and is
-- the substrate the guild comm arm (COMM_REV 5) will be verified against.
--
-- Run it like pb_harness (set PB_BASE to the addon folder, execute via lupa):
--     lua.globals().PB_BASE = "ProfessionBuddy"   -- a REV-4 tree
--     lua.execute(open("pb_ghost_harness.lua").read())
-- Ends with "ALL GHOST HARNESS TESTS PASS" or error()s on the first failure.
----------------------------------------------------------------------

local BASE = assert(PB_BASE, "PB_BASE not set")

-- Load a file so its chunk runs under a custom global env `env`. Portable
-- across Lua 5.1 (setfenv) and 5.2+ (loadfile with an env arg).
local function loadFileInEnv(path, env)
    if setfenv then
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        return chunk
    end
    return assert(loadfile(path, "t", env))
end

-- Deep copy a payload on delivery. The identity AceSerializer stub passes tables
-- by reference; across two instances that would let the receiver mutate the
-- sender's table and manufacture false passes. A copy simulates the real
-- serialize/deserialize wire boundary.
local function deepcopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, val in pairs(v) do out[deepcopy(k, seen)] = deepcopy(val, seen) end
    return out
end

----------------------------------------------------------------------
-- Router: the wire between instances.
----------------------------------------------------------------------
local Router = { queue = {}, instances = {}, order = {},
                 groups = {}, guilds = {}, MAX_ROUNDS = 500 }

-- Keyed by full identity (name-realm), NOT name: same-name-different-realm
-- instances (the spoof case) must coexist as distinct wire endpoints.
function Router:register(inst)
    self.instances[inst.key] = inst
    table.insert(self.order, inst.key)
end

-- How instance `from` appears to instance `to` as a chat sender / unit name:
-- bare name on the same realm, name-realm across realms (mirrors WoW).
function Router:senderAs(from, to)
    if from.realm == to.realm then return from.name end
    return from.name .. "-" .. from.realm
end

function Router:enqueue(fromName, prefix, payload, channel, target)
    table.insert(self.queue, { from = fromName, prefix = prefix,
        payload = payload, channel = channel, target = target })
end

function Router:deliverTo(inst, msg, from)
    if inst.key == from.key then return end
    local sender = self:senderAs(from, inst)
    inst.comm:OnMessageReceived(msg.prefix, deepcopy(msg.payload), msg.channel, sender)
end

function Router:deliverOne(msg)
    local from = self.instances[msg.from]
    local ch = msg.channel
    if ch == "WHISPER" then
        -- Realm-aware match ONLY: a bare "Bob" target from a GhostRealm sender
        -- reaches Bob-GhostRealm, never Bob-EvilRealm.
        for _, key in ipairs(self.order) do
            local inst = self.instances[key]
            if inst.key ~= from.key and self:senderAs(inst, from) == msg.target then
                self:deliverTo(inst, msg, from)
            end
        end
    elseif ch == "PARTY" or ch == "RAID" then
        for _, other in ipairs(self.groups[from.key] or {}) do
            local inst = self.instances[other]
            if inst then self:deliverTo(inst, msg, from) end
        end
    elseif ch == "GUILD" then
        for _, other in ipairs(self.guilds[from.key] or {}) do
            local inst = self.instances[other]
            if inst then self:deliverTo(inst, msg, from) end
        end
    end
end

-- Drain the queue until quiescent. New messages queued during delivery (acks,
-- responses) are processed in turn. MAX_ROUNDS backstops a resend loop.
function Router:pump()
    local rounds = 0
    while #self.queue > 0 do
        rounds = rounds + 1
        if rounds > self.MAX_ROUNDS then
            error("Router:pump exceeded MAX_ROUNDS -- comm loop?")
        end
        self:deliverOne(table.remove(self.queue, 1))
    end
end

-- Model a party: sets each member's group stubs to see the others.
function Router:group(...)
    local names = { ... }
    for _, n in ipairs(names) do
        local peers = {}
        for _, m in ipairs(names) do if m ~= n then table.insert(peers, m) end end
        self.groups[n] = peers
        local inst = self.instances[n]
        inst.state.inGroup = (#peers > 0)
        inst.state.partyMembers = {}
        for _, m in ipairs(peers) do
            table.insert(inst.state.partyMembers, self:senderAs(self.instances[m], inst))
        end
    end
end

function Router:ungroupAll()
    for name, inst in pairs(self.instances) do
        self.groups[name] = {}
        inst.state.inGroup = false
        inst.state.partyMembers = {}
    end
end

-- Model a guild: records co-guild membership AND drives each member's guild
-- roster stubs so IsGuildMember sees the others. Args are full keys.
function Router:guild(...)
    local keys = { ... }
    for _, n in ipairs(keys) do
        local peers = {}
        for _, m in ipairs(keys) do if m ~= n then table.insert(peers, m) end end
        self.guilds[n] = peers
        local inst = self.instances[n]
        inst.state.guildMembers = {}
        for _, m in ipairs(peers) do
            table.insert(inst.state.guildMembers, self:senderAs(self.instances[m], inst))
        end
    end
end

----------------------------------------------------------------------
-- Build one isolated instance: its own env, WoW-API stubs, and addon copy.
----------------------------------------------------------------------
local function makeInstance(name, realm)
    local inst = { name = name, realm = realm, key = name .. "-" .. realm }
    local state = { inGroup = false, inRaid = false, partyMembers = {}, guildMembers = {} }
    local frames, timers, deferred = {}, {}, {}
    inst.state, inst.frames, inst.timers, inst.deferred = state, frames, timers, deferred

    local env = setmetatable({}, { __index = _G })   -- Lua stdlib falls through

    function env.CreateFrame(_, _)
        local f = { scripts = {}, events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:GetScript(k) return self.scripts[k] end
        function f:RegisterAllEvents() end
        function f:Show() end
        function f:Hide() end
        function f:SetSize() end
        function f:SetPoint() end
        table.insert(frames, f)
        return f
    end

    function env.UnitName(unit)
        if unit == "player" then return name end
        local i = tonumber(unit:match("^party(%d+)$") or unit:match("^raid(%d+)$"))
        local full = i and state.partyMembers[i]
        if not full then return nil end
        return full:match("^([^-]+)")
    end
    function env.GetUnitName(unit, withRealm)
        if unit == "player" then return withRealm and inst.key or name end
        local i = tonumber(unit:match("^party(%d+)$") or unit:match("^raid(%d+)$"))
        local full = i and state.partyMembers[i]
        if not full then return nil end
        if withRealm then return full end
        return full:match("^([^-]+)")
    end
    function env.GetRealmName() return realm end
    function env.UnitClass() return "Warrior", "WARRIOR" end
    function env.UnitLevel() return 70 end
    function env.UnitFactionGroup() return "Alliance" end
    function env.IsInGroup() return state.inGroup end
    function env.IsInRaid() return state.inRaid end
    function env.GetNumGroupMembers() return #state.partyMembers end
    function env.GetNumSubgroupMembers() return #state.partyMembers end
    -- Guild roster stubs (for the COMM_REV 5 guild arm). IsGuildMember reads
    -- only field 1 (name) from GetGuildRosterInfo, so that is all we return.
    function env.IsInGuild() return #state.guildMembers > 0 end
    function env.GetNumGuildMembers() return #state.guildMembers end
    function env.GetGuildRosterInfo(i) return state.guildMembers[i] end
    function env.GuildRoster() end

    env.C_Timer = {
        After = function(_, fn) table.insert(deferred, fn) end,
        NewTimer = function(_, fn)
            local h = { fn = fn, cancelled = false }
            function h:Cancel() self.cancelled = true end
            table.insert(timers, h)
            return h
        end,
    }
    env.time = os.time
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.format = string.format
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 0.8, b = 0.6 } }
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.print = function() end   -- silence the addon's load banner

    -- AceComm: SendCommMessage routes onto the shared wire, tagged with sender.
    local AceComm = {
        RegisterComm = function() end,
        SendCommMessage = function(_, prefix, text, channel, target)
            Router:enqueue(inst.key, prefix, text, channel, target)
        end,
    }
    local AceSerializer = {
        Serialize = function(_, d) return d end,
        Deserialize = function(_, m) return true, m end,
    }
    env.LibStub = function(libname)
        if libname == "AceComm-3.0" then return AceComm end
        if libname == "AceSerializer-3.0" then return AceSerializer end
        error("unexpected LibStub: " .. tostring(libname))
    end

    inst.env = env

    -- Load the addon (same files pb_harness loads) into this env, in order.
    for _, file in ipairs({ "Core", "DataStore", "Orders", "Comm", "RecipeDB" }) do
        loadFileInEnv(BASE .. "/" .. file .. ".lua", env)()
    end

    -- Fire load events on every frame that registered them.
    inst.fire = function(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    -- Run (and clear) any C_Timer.After callbacks queued so far. Lets a test
    -- drive the addon's delayed login work (SyncOnlineContacts, guild HELLO).
    inst.runDeferred = function()
        local q = {}
        for i, fn in ipairs(deferred) do q[i] = fn end
        for i = #deferred, 1, -1 do deferred[i] = nil end
        for _, fn in ipairs(q) do fn() end
    end
    inst.fire("ADDON_LOADED", "ProfessionBuddy")
    inst.fire("PLAYER_LOGIN")
    inst.fire("PLAYER_ENTERING_WORLD")
    -- Drop the deferred callbacks queued during setup so tests trigger them
    -- deliberately (the setup PLAYER_ENTERING_WORLD ran before any guild/group).
    for i = #deferred, 1, -1 do deferred[i] = nil end

    inst.addon = env.ProfBuddy
    inst.comm  = env.ProfBuddy.Comm
    inst.ds    = env.ProfBuddy.DataStore
    inst.orders = env.ProfBuddy.Orders
    assert(inst.comm and inst.comm._ready, name .. ": Comm did not init")
    assert(inst.addon:PlayerKey() == inst.key,
        name .. ": PlayerKey " .. tostring(inst.addon:PlayerKey()) .. " != " .. inst.key)

    Router:register(inst)
    return inst
end

-- Seed an instance's own character with a profession + inventory so it has
-- something real to serve on a sync.
local function seedChar(inst, prof, recipeName, spellID, itemID, count)
    local DS = inst.ds
    DS:EnsureCharacter()
    DS:SetProfessionData(prof, { skillLevel = 300, maxSkill = 375,
        recipes = { [recipeName] = { spellID = spellID } } })
    DS:SetInventory("bags", { [itemID] = count })
end

----------------------------------------------------------------------
-- Build the cast and run the ghost tests.
----------------------------------------------------------------------
local A = makeInstance("Ana", "GhostRealm")
local B = makeInstance("Bob", "GhostRealm")
local S = makeInstance("Sneaky", "GhostRealm")      -- ungrouped stranger

seedChar(A, "Tailoring",   "Bolt of Runecloth", 18401, 14047, 20)
seedChar(B, "Alchemy",     "Elixir of Fortitude", 3188, 13446, 12)

local pass = 0
local function ok(msg) pass = pass + 1; print("  PASS " .. msg) end
local function check(cond, msg) if not cond then error("GHOST FAIL: " .. msg) end end

-- ── GP1: HELLO handshake while grouped -> both see each other ────────
-- HELLO stores a lightweight CHARACTER summary (via StoreLightweight); the
-- trusted-contact entry is a separate, user-driven step (Add / sync / auto).
Router:group(A.key, B.key)
A.comm:BroadcastHello()
Router:pump()
check(B.addon.db.characters[A.key], "GP1: Bob did not record Ana from HELLO")
check(A.addon.db.characters[B.key], "GP1: Ana did not record Bob from HELLO_ACK")
ok("GP1 HELLO handshake -- both instances recorded each other (lightweight)")

-- ── GP2: SYNC round trip -> Ana ends up holding Bob's real profession ─
A.comm:RequestSync("Bob", true)     -- trusts Bob on Ana's side, sends SYNC_REQ
Router:pump()
local bobOnAna = A.addon.db.characters[B.key]
check(bobOnAna and bobOnAna.isRemote, "GP2: Ana has no remote record for Bob")
check(bobOnAna.professions and bobOnAna.professions["Alchemy"],
    "GP2: Bob's Alchemy did not sync to Ana")
check(bobOnAna.professions["Alchemy"].recipes["Elixir of Fortitude"],
    "GP2: Bob's recipe did not sync to Ana")
ok("GP2 SYNC round trip -- Bob's Alchemy synced to Ana over the wire")

-- ── GP3: an ungrouped, untrusted stranger is served nothing ──────────
S.comm:RequestSync("Ana", true)     -- Sneaky asks Ana for a sync
Router:pump()
check(S.addon.db.characters[A.key] == nil,
    "GP3: Ana served her data to an untrusted stranger")
ok("GP3 stranger refused -- Ana served nothing to an untrusted requester")

-- ── GP4: cross-realm same-name spoof is refused ──────────────────────
-- A ghost on another realm sharing Bob's NAME must not inherit Bob's trust.
local Bspoof = makeInstance("Bob", "EvilRealm")
seedChar(Bspoof, "Alchemy", "Fake Elixir", 1, 13446, 1)
Bspoof.comm:RequestSync("Ana", true)   -- spoofed Bob (other realm) asks Ana
Router:pump()
-- Ana trusts Bob-GhostRealm (from GP2), NOT Bob-EvilRealm.
check(Bspoof.addon.db.characters[A.key] == nil,
    "GP4: cross-realm same-name spoof pulled Ana's data")
ok("GP4 cross-realm spoof refused -- Bob-EvilRealm did not inherit Bob-GhostRealm's trust")

-- ── GP7: order lifecycle round trip (new -> ack -> complete) ─────────
-- Ana asks Bob to craft. Bob receives ORDER_NEW, acks it (clearing Ana's
-- retry outbox), then completes it and the terminal status propagates back.
local order = A.orders:Create({ crafter = B.key,
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" },
    quantity = 2 })
check(order, "GP7: order create failed")
A.comm:SendOrderNew(order)
Router:pump()
check(B.addon.db.orders[order.id], "GP7: Bob never received the order")
check(A.addon.db.orderOutbox[order.id .. ":new"] == nil,
    "GP7: Bob's ACK did not clear Ana's retry outbox")

local bOrder = B.addon.db.orders[order.id]
bOrder.status = "completed"
bOrder.completedBy = "crafter"
B.comm:SendOrderUpdate(bOrder)
Router:pump()
check(A.addon.db.orders[order.id].status == "completed",
    "GP7: completion did not propagate back to Ana")
ok("GP7 order lifecycle -- new/ack/complete crossed the wire both directions")

-- ── GP5: guild trust + sync (co-guilded, NOT grouped) [COMM_REV 5] ───
-- Ungroup first so trust can ONLY come from the guild arm, never a lingering
-- party. Carol and Ana share a guild but no group; guild HELLO establishes
-- mutual awareness and Carol then pulls Ana's full data over guild trust.
Router:ungroupAll()
local C = makeInstance("Carol", "GhostRealm")
seedChar(C, "Enchanting", "Runed Arcanite Rod", 22757, 12800, 5)
Router:guild(A.key, C.key)
-- Turn ON "auto-add party members" on both sides. A guild HELLO must STILL NOT
-- create a Friends contact: auto-add is for party members, and guild trust is
-- live-only. (Regression guard for the in-game bug where guildmates showed up
-- in Friends as trusted=false, autoSync=false seen entries.)
A.addon.db.settings = A.addon.db.settings or {}; A.addon.db.settings.autoAddParty = true
C.addon.db.settings = C.addon.db.settings or {}; C.addon.db.settings.autoAddParty = true
-- Spy on Carol's Guild-tab refresh: incoming guildmate data must refresh it live
-- (NotifyUIRefresh had no GuildPanel hook, so the open tab went stale in-game).
C.addon.GuildPanel = { n = 0, Refresh = function(self) self.n = self.n + 1 end }

-- Simulate a /reload: already guilded at init, so there is NO not-guilded to
-- guilded transition. The roster-load path (GUILD_ROSTER_UPDATE) must still
-- announce us. This is exactly the case that failed in-game on /reload before
-- the fix; the old transition-only broadcast would produce nothing here.
A.comm._inGuild = true
A.comm._guildHelloDone = nil
A.fire("GUILD_ROSTER_UPDATE")
A.runDeferred()          -- runs the 2s-delayed BroadcastGuildHello
Router:pump()
check(C.addon.db.characters[A.key], "GP5: guild HELLO did not fire on roster load (the /reload path)")
check(A.addon.db.characters[C.key], "GP5: Ana did not record Carol from HELLO_ACK")
check(C.addon.GuildPanel.n > 0, "GP5: incoming guild data did not refresh Carol's Guild tab")
check(C.addon.db.contacts[A.key] == nil and A.addon.db.contacts[C.key] == nil,
    "GP5: guild HELLO auto-added a Friends contact despite the sender being guild-only")
-- Announce-once: a second roster update this session must NOT re-broadcast.
A.fire("GUILD_ROSTER_UPDATE")
A.runDeferred()
check(#Router.queue == 0, "GP5: guild HELLO re-broadcast on a second roster update (announce-once failed)")
-- Use the real Guild-tab trigger: RequestGuildSync pulls full data WITHOUT
-- persisting a trusted contact (guild trust is live-only).
C.comm:RequestGuildSync(A.key)
Router:pump()
local anaOnCarol = C.addon.db.characters[A.key]
check(anaOnCarol and anaOnCarol.professions and anaOnCarol.professions["Tailoring"],
    "GP5: Ana's Tailoring did not sync to Carol over guild trust")
check(anaOnCarol.professions["Tailoring"].recipes["Bolt of Runecloth"],
    "GP5: Ana's recipe did not sync to Carol")
-- The locale-stable spellID must survive the sync (it is what resolves a
-- recipe's icon for a remote character, e.g. enchants that have no itemID).
check(anaOnCarol.professions["Tailoring"].recipes["Bolt of Runecloth"].spellID == 18401,
    "GP5: synced recipe lost its spellID over the wire")
check(C.addon.db.contacts[A.key] == nil,
    "GP5: guild sync wrongly persisted a trusted contact (trust must stay live-only)")
-- And a guildless stranger is still refused even now.
check(S.addon.db.characters[A.key] == nil, "GP5: stranger gained access via the guild arm")
ok("GP5 guild trust+sync -- co-guilded (not grouped) synced via RequestGuildSync, no persisted contact")

-- ── GP6: incremental auto-push convergence + suppression ─────────────
-- The current "delta" path: on an inventory/profession change (BAG_UPDATE),
-- debounce, then auto-push a full SYNC_DATA to autoSync contacts, suppressed by
-- a state signature so an unchanged state does not re-push. (The lightweight
-- itemID-delta with sequence numbers and gap-triggered resync is a FUTURE item,
-- not this wire, so GP6 covers what exists: convergence and suppression.)
Router:ungroupAll()
Router:group(A.key, B.key)                        -- mutual trust for the push
A.addon.db.contacts[B.key] = { trusted = true, autoSync = true, lastSync = 0 }
B.addon.db.contacts[A.key] = { trusted = true, autoSync = false, lastSync = 0 }

-- Drive the REAL path: fire BAG_UPDATE, then run the debounce timer it armed.
local function fireIncr(inst)
    local n0 = #inst.timers
    inst.fire("BAG_UPDATE")
    for i = n0 + 1, #inst.timers do
        local t = inst.timers[i]
        if t and not t.cancelled then t.fn() end
    end
end

-- Baseline: first push carries Ana's current inventory to Bob.
fireIncr(A)
Router:pump()
local aOnB = B.addon.db.characters[A.key]
check(aOnB and aOnB.inventory and aOnB.inventory.bags[14047] == 20,
    "GP6: baseline auto-push did not reach Bob")

-- Change Ana's inventory, push again -> Bob converges to the new counts.
A.ds:SetInventory("bags", { [14047] = 99, [2589] = 5 })
fireIncr(A)
Router:pump()
aOnB = B.addon.db.characters[A.key]
check(aOnB.inventory.bags[14047] == 99 and aOnB.inventory.bags[2589] == 5,
    "GP6: Bob did not converge to Ana's changed inventory")

-- Suppression: with no state change, the signature matches, so nothing pushes.
local before = #Router.queue
fireIncr(A)
check(#Router.queue == before,
    "GP6: unchanged state still re-pushed (signature suppression failed)")
ok("GP6 incremental auto-push -- converges on change, suppressed when unchanged")

print("ALL GHOST HARNESS TESTS PASS (" .. pass ..
    " groups: GP1 hello, GP2 sync, GP3 stranger, GP4 spoof, GP5 guild, GP6 delta, GP7 order loop)")
