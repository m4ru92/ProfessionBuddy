----------------------------------------------------------------------
-- Headless test harness for ProfessionBuddy comm/order logic, plus the
-- profession scanner and the material calculator.
-- Stubs the WoW API, loads Core/DataStore/Orders/Comm/RecipeDB/Scanner/
-- MaterialCalc and four Data files, and drives the real message handlers and
-- the real window scans end to end. error() on any failed assertion.
----------------------------------------------------------------------

local BASE = assert(PB_BASE, "PB_BASE not set")

-- ── WoW API stubs ────────────────────────────────────────────────
local state = {
    inGroup = false, inRaid = false,
    partyMembers = {},        -- { "Name" or "Name-Realm", ... }
    guildMembers = {},        -- { "Name" or "Name-Realm", ... }; empty = guildless
}
local sent = {}               -- recorded SendCommMessage calls
local timers = {}             -- capturable C_Timer.NewTimer callbacks
local deferred = {}           -- C_Timer.After callbacks (not auto-run)

local frames = {}
function CreateFrame(kind, name)
    local f = { scripts = {}, events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    table.insert(frames, f)
    return f
end

function UnitName(unit)
    if unit == "player" then return "Me" end
    local i = tonumber(unit:match("^party(%d+)$") or unit:match("^raid(%d+)$"))
    local full = i and state.partyMembers[i]
    if not full then return nil end
    return full:match("^([^-]+)")
end
function GetUnitName(unit, withRealm)
    if unit == "player" then return "Me" end
    local i = tonumber(unit:match("^party(%d+)$") or unit:match("^raid(%d+)$"))
    local full = i and state.partyMembers[i]
    if not full then return nil end
    if withRealm then return full end
    return full:match("^([^-]+)")
end
function GetRealmName() return "Test Realm" end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitLevel() return 70 end
function UnitFactionGroup() return "Alliance" end
function IsInGroup() return state.inGroup end
function IsInRaid() return state.inRaid end
function GetNumGroupMembers() return #state.partyMembers end
function GetNumSubgroupMembers() return #state.partyMembers end
-- Guild-roster API (COMM_REV 5 guild arm). state.guildMembers is empty until a
-- guild test calls joinGuild(), so T1-T23 still run guildless and the guild
-- trust arm returns false for them exactly as before.
function IsInGuild() return #state.guildMembers > 0 end
function GetNumGuildMembers() return #state.guildMembers end
function GetGuildRosterInfo(i)
    local full = state.guildMembers[i]
    if not full then return nil end
    -- field 1 = name, field 9 = online (the only two Comm reads)
    return full, nil, nil, nil, nil, nil, nil, nil, true
end

C_Timer = {
    After = function(t, fn) table.insert(deferred, fn) end,
    NewTimer = function(t, fn)
        local h = { fn = fn, cancelled = false }
        function h:Cancel() self.cancelled = true end
        table.insert(timers, h)
        return h
    end,
}

time = os.time
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
format = string.format
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 0.8, b = 0.6 } }
SlashCmdList = {}
UISpecialFrames = {}

-- Ace stubs: identity "serialization" so payload tables pass through
local AceComm = {
    RegisterComm = function(target, prefix) end,
    SendCommMessage = function(self, prefix, text, channel, target, prio)
        -- prio is recorded: it is the ChatThrottleLib pipe, and a payload sent
        -- on the wrong one head-of-line blocks order traffic behind a full sync.
        table.insert(sent, { msgType = text._type, payload = text,
                             channel = channel, target = target, prio = prio })
    end,
}
local AceSerializer = {
    Serialize = function(self, d) return d end,
    Deserialize = function(self, m) return true, m end,
}
function LibStub(name)
    if name == "AceComm-3.0" then return AceComm end
    if name == "AceSerializer-3.0" then return AceSerializer end
    error("unexpected LibStub: " .. tostring(name))
end

-- ── profession / inventory window stubs (Scanner) ────────────────
-- One `sim` table drives the tradeskill, craft, skill-line and container APIs
-- the Scanner reads. Scanner binds the container functions at LOAD time, so
-- C_Container has to exist before the dofile below.
local sim = {
    linked = false, pet = false,
    tradeLine = { "Tailoring", 300, 375 },
    tradeRows = {},           -- { name, type, numAvail, isExpanded, itemLink }
    nameFilter = "",
    craftLine = { "Enchanting", 300, 375 },
    craftRows = {},           -- { name, type, numAvail }
    skillLines = {},          -- FULL list: { name, isHeader, rank, maxRank }
    collapsedHeaders = {},    -- [headerName] = true; its rows drop out of the list
    bags = {},                -- [bag] = { slots = n, [slot] = { link, count } }
    expandCalls = 0,
    collapsed = {},           -- names handed to CollapseSkillHeader, in order
}

-- Scanner throttles BAG_UPDATE off GetTime(), so the harness owns that clock.
local clock = 1000
function GetTime() return clock end
function GetLocale() return "enUS" end
function GetSpellInfo() return nil end   -- profession names self-map (enUS)

function IsTradeSkillLinked() return sim.linked end
function CraftIsPetTraining() return sim.pet end
function GetTradeSkillLine() return sim.tradeLine[1], sim.tradeLine[2], sim.tradeLine[3] end
function GetNumTradeSkills() return #sim.tradeRows end
function GetTradeSkillInfo(i)
    local r = sim.tradeRows[i]
    if not r then return nil end
    return r[1], r[2], r[3], r[4]
end
function GetTradeSkillItemLink(i) local r = sim.tradeRows[i]; return r and r[5] or nil end
function GetTradeSkillRecipeLink(i) local r = sim.tradeRows[i]; return r and r[6] or nil end
function GetTradeSkillIcon() return "icon" end
function GetTradeSkillCooldown() return 0 end
function GetTradeSkillItemNameFilter() return sim.nameFilter end
function GetTradeSkillReagentInfo() return nil end
function GetTradeSkillReagentItemLink() return nil end

function GetCraftDisplaySkillLine() return sim.craftLine[1], sim.craftLine[2], sim.craftLine[3] end
function GetNumCrafts() return #sim.craftRows end
function GetCraftInfo(i)
    local r = sim.craftRows[i]
    if not r then return nil end
    return r[1], "sub", r[2], r[3]
end
function GetCraftItemLink() return nil end
function GetCraftRecipeLink() return nil end
function GetCraftIcon() return "icon" end
function GetCraftReagentInfo() return nil end
function GetCraftReagentItemLink() return nil end

-- The skill list enumerates only the rows it is DISPLAYING, so a collapsed
-- header hides its own rows and every index below it shifts. Modelling that is
-- the whole point: it is what makes a restore by saved index land on the wrong
-- row, which is the bug the name-keyed restore exists to avoid.
local function visibleSkillLines()
    local out, hidden = {}, false
    for _, r in ipairs(sim.skillLines) do
        if r[2] then
            hidden = sim.collapsedHeaders[r[1]] == true
            table.insert(out, r)
        elseif not hidden then
            table.insert(out, r)
        end
    end
    return out
end
function GetNumSkillLines() return #visibleSkillLines() end
function GetSkillLineInfo(i)
    local r = visibleSkillLines()[i]
    if not r then return nil end
    local isExpanded = r[2] and not sim.collapsedHeaders[r[1]] or false
    return r[1], r[2], isExpanded, r[3], 0, 0, r[4]
end
function ExpandSkillHeader()
    sim.expandCalls = sim.expandCalls + 1
    sim.collapsedHeaders = {}
end
function CollapseSkillHeader(i)
    local r = visibleSkillLines()[i]
    table.insert(sim.collapsed, r and r[1] or ("?" .. i))
    if r and r[2] then sim.collapsedHeaders[r[1]] = true end
end

C_Container = {
    GetContainerNumSlots = function(bag)
        local b = sim.bags[bag]
        return b and b.slots or 0
    end,
    GetContainerItemLink = function(bag, slot)
        local b = sim.bags[bag]
        local s = b and b[slot]
        return s and s.link or nil
    end,
    GetContainerItemInfo = function(bag, slot)
        local b = sim.bags[bag]
        local s = b and b[slot]
        return s and { stackCount = s.count } or nil
    end,
}

-- The offline back-off reads this locale string and builds its pattern from it.
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."

-- ── load the addon files ─────────────────────────────────────────
dofile(BASE .. "/Core.lua")
dofile(BASE .. "/DataStore.lua")
dofile(BASE .. "/Orders.lua")
dofile(BASE .. "/Comm.lua")
dofile(BASE .. "/RecipeDB.lua")
dofile(BASE .. "/Scanner.lua")
-- The four data files the calculator and cycle tests need: Alchemy for the
-- primal transmute ring, Enchanting for the prismatic shard loop, Smelting and
-- Blacksmithing for an expandable (acyclic) intermediate chain.
for _, f in ipairs({ "Alchemy", "Enchanting", "Smelting", "Blacksmithing" }) do
    dofile(BASE .. "/Data/" .. f .. ".lua")
end
dofile(BASE .. "/MaterialCalc.lua")

local addon = ProfBuddy
local eventFrame = frames[1]
local function fire(event, ...)
    eventFrame.scripts.OnEvent(eventFrame, event, ...)
end
fire("ADDON_LOADED", "ProfessionBuddy")

local Comm, Orders, DS = addon.Comm, addon.Orders, addon.DataStore
assert(Comm._ready, "Comm did not init")

-- seed local character data
DS:EnsureCharacter()
DS:SetProfessionData("Tailoring", { skillLevel = 300, maxSkill = 375,
    recipes = { ["Bolt of Runecloth"] = { spellID = 18401 } } })
DS:SetInventory("bags", { [14047] = 20 })

local function recv(sender, payload)
    Comm:OnMessageReceived("PBuddy", payload, "WHISPER", sender)
end
-- Same, on a chosen distribution: the 1.1.0 gate drops a directed message that
-- arrives on a broadcast channel, which only a distribution-aware feed can show.
local function recvOn(sender, payload, distribution)
    Comm:OnMessageReceived("PBuddy", payload, distribution, sender)
end
local function sentOfType(t)
    local out = {}
    for _, s in ipairs(sent) do if s.msgType == t then table.insert(out, s) end end
    return out
end
local function firstOfType(t) return sentOfType(t)[1] end
local function clearSent() sent = {}; for i = #timers, 1, -1 do timers[i] = nil end end

-- C_Timer.After callbacks are captured, never auto-run: a test drives them so
-- a deferred ack can be told apart from one that never fires.
local function clearDeferred() for i = #deferred, 1, -1 do deferred[i] = nil end end
local function runDeferred()
    local q = {}
    for i, fn in ipairs(deferred) do q[i] = fn end
    clearDeferred()
    for _, fn in ipairs(q) do fn() end
end

-- Guild roster control. GUILD_ROSTER_UPDATE only invalidates the cached set,
-- so the tests do the same rather than reaching into Comm's internals.
local function joinGuild(...)
    state.guildMembers = { ... }
    Comm._guildSet = nil
end
local function leaveGuild()
    state.guildMembers = {}
    Comm._guildSet = nil
end

local pass = 0
local function passed(label) pass = pass + 1; print("  PASS " .. label) end

local ME = addon:PlayerKey()
assert(ME == "Me-TestRealm", "unexpected PlayerKey: " .. ME)   -- canonical key: realm spaces stripped

-- ── T1: stranger SYNC_REQ is ignored ─────────────────────────────
clearSent()
recv("Rando", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 0, "T1: served a stranger")

-- ── T2: group member is served while grouped ─────────────────────
clearSent()
state.inGroup = true
state.partyMembers = { "Friendo" }
recv("Friendo", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 1, "T2: group member not served")
assert(sentOfType("SYNC_DATA")[1].target == "Friendo", "T2: wrong target")

-- ── T3: after group disbands, same player is refused ─────────────
clearSent()
state.inGroup = false
state.partyMembers = {}
-- simulate the contact entry a HELLO would have auto-created (seen-only)
recv("Friendo", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 0, "T3: ex-group member still trusted")

-- ── T4: cross-realm same-name spoof is refused ───────────────────
clearSent()
state.inGroup = true
state.partyMembers = { "Friendo" }   -- same realm as us
recv("Friendo-OtherRealm", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 0, "T4: cross-realm spoof trusted")
state.inGroup = false
state.partyMembers = {}

-- ── T5: /pb sync canonicalizes and trusts; reply then served ─────
clearSent()
Comm:RequestSync("buddy", true)          -- lowercase, no realm
local c = addon.db.contacts["Buddy-TestRealm"]
assert(c and c.trusted, "T5: contact not canonicalized/trusted")
assert(#sentOfType("SYNC_REQ") == 1, "T5: no SYNC_REQ sent")
clearSent()
recv("Buddy", { _type = "SYNC_REQ" })    -- they can pull ours now
assert(#sentOfType("SYNC_DATA") == 1, "T5: trusted contact refused")

-- ── T6: SYNC_DATA ingress sanitization ───────────────────────────
recv("Buddy", { _type = "SYNC_DATA",
    class = "war|rior", level = 9999, faction = "Pirates",
    inventory = { bags = { [2840] = "junk", evil = 10, [123] = 42.7, [999] = 1e12 },
                  bank = "not a table" },
    professions = {
        ["Tail|oring"] = { skillLevel = "9999", maxSkill = {},
            recipeNames = { "Good Recipe", "|Hbad|h", 77 },
            recipeSpells = { 0, 55, 88 } },
    },
})
local rec = addon.db.characters["Buddy-TestRealm"]
assert(rec and rec.isRemote, "T6: record not stored")
assert(rec.class == "UNKNOWN", "T6: class not sanitized: " .. tostring(rec.class))
assert(rec.level == 100, "T6: level not clamped: " .. tostring(rec.level))
assert(rec.faction == "Unknown", "T6: faction not whitelisted")
assert(rec.inventory.bags[123] == 42, "T6: count not floored")
assert(rec.inventory.bags[999] == 1000000, "T6: count not clamped")
assert(rec.inventory.bags[2840] == nil, "T6: junk count kept")
assert(rec.inventory.bags.evil == nil, "T6: non-numeric key kept")
assert(next(rec.inventory.bank) == nil, "T6: bad bank not emptied")
local prof = rec.professions["Tail||oring"]
assert(prof, "T6: profession name not pipe-escaped")
assert(prof.skillLevel == 500, "T6: skill not clamped")
assert(prof.recipes["||Hbad||h"], "T6: recipe name not escaped")
assert(prof.recipes["||Hbad||h"].spellID == 55, "T6: aligned spellID lost")
assert(prof.recipes["Good Recipe"].spellID == nil, "T6: spellID 0 not nil")
assert(prof.recipes[77] == nil and prof.recipes["77"] == nil, "T6: non-string recipe kept")
-- poisoned data must not break the consumers that crashed pre-patch
local owners = DS:WhoHasItem(123)
assert(owners["Buddy-TestRealm"] == 42, "T6: WhoHasItem broken on remote data")

-- ── T7: full order lifecycle with acks (the regression) ──────────
clearSent()
local order = Orders:Create({ crafter = "Buddy-TestRealm",
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" },
    quantity = 2 })
assert(order, "T7: create failed")
Comm:SendOrderNew(order)
assert(#sentOfType("ORDER_NEW") == 1, "T7: ORDER_NEW not sent")
assert(#timers == 1, "T7: no ack timer armed")
-- counterparty offline: fire the 8s timeout -> parked in outbox
timers[1].fn()
local token = order.id .. ":new"
assert(addon.db.orderOutbox[token], "T7: not parked in outbox")
-- they come online and message us -> outbox flush resends
clearSent()
recv("Buddy", { _type = "HELLO", professions = {} })
assert(#sentOfType("ORDER_NEW") == 1, "T7: outbox did not flush")
-- their ack arrives -> outbox must clear (nil-global ackToken bug broke this)
recv("Buddy", { _type = "ORDER_ACK", token = token })
assert(addon.db.orderOutbox[token] == nil, "T7: ACK did not clear outbox (ackToken regression)")

-- ── T8: ack from the wrong player does not clear ─────────────────
clearSent()
local o2 = Orders:Create({ crafter = "Buddy-TestRealm",
    item = { id = 1, name = "X", profession = "Tailoring" } })
Comm:SendOrderNew(o2)
timers[#timers].fn()
local tok2 = o2.id .. ":new"
assert(addon.db.orderOutbox[tok2], "T8: not parked")
addon.db.contacts["Mallory-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
recv("Mallory", { _type = "ORDER_ACK", token = tok2 })
assert(addon.db.orderOutbox[tok2], "T8: wrong player cleared the token")
recv("Buddy", { _type = "ORDER_ACK", token = tok2 })
assert(addon.db.orderOutbox[tok2] == nil, "T8: right player could not clear")

-- ── T9: inbound ORDER_NEW sanitized + acked; spoof refused ───────
clearSent()
recv("Buddy", { _type = "ORDER_NEW", token = "Buddy-TestRealm-1:new", order = {
    id = "Buddy-TestRealm-1", requester = "Buddy-TestRealm", crafter = ME,
    item = { id = 555, name = "Thing|Hlink", profession = "Tailoring" },
    quantity = 5000, status = "pending", createdAt = 9e18, updatedAt = 9e18,
} })
local stored = addon.db.orders["Buddy-TestRealm-1"]
assert(stored, "T9: inbound order not stored")
assert(stored.item.name == "Thing||Hlink", "T9: item name not escaped")
assert(stored.quantity == 999, "T9: quantity not clamped")
assert(stored.updatedAt <= time() + 300, "T9: timestamp not clamped")
assert(#sentOfType("ORDER_ACK") == 1, "T9: no ack sent")
clearSent()
recv("Mallory", { _type = "ORDER_NEW", token = "spoof:new", order = {
    id = "spoof", requester = "Buddy-TestRealm", crafter = ME,
    item = { id = 1, name = "s", profession = "T" }, status = "pending",
} })
assert(addon.db.orders["spoof"] == nil, "T9: forged requester accepted")
assert(#sentOfType("ORDER_ACK") == 1, "T9: refusal not acked (retry loop)")

-- ── T10: role-checked status + derived completedBy ───────────────
-- Buddy (crafter) tries "cancelled" (requester-only): refused
recv("Buddy", { _type = "ORDER_UPDATE", id = order.id, status = "cancelled",
    updatedAt = time() + 1, token = "t10a" })
assert(addon.db.orders[order.id].status == "pending", "T10: crafter cancelled")
-- Buddy sends completed forging completedBy=requester: stored as crafter
recv("Buddy", { _type = "ORDER_UPDATE", id = order.id, status = "completed",
    completedBy = "requester", updatedAt = time() + 2, token = "t10b" })
local fin = addon.db.orders[order.id]
assert(fin.status == "completed", "T10: completed not applied")
assert(fin.completedBy == "crafter", "T10: completedBy forged as " .. tostring(fin.completedBy))

-- ── T11: auto-push -- full for an old client, suppressed when unchanged ──
-- Buddy has no COMM_REV on record (an old client), so every push is a full
-- SYNC_DATA, never a delta. Reset the delta baseline so the first push here is
-- a clean baseline (T5's serve seeded one earlier).
clearSent()
Comm._pushState = nil
addon.db.contacts["Buddy-TestRealm"].autoSync = true
addon.db.contacts["Buddy-TestRealm"].lastCommRev = nil
Comm:SendIncrementalUpdate()
assert(#sentOfType("SYNC_DATA") == 1 and #sentOfType("INCR") == 0, "T11: first push (full baseline) missing")
clearSent()
Comm:SendIncrementalUpdate()               -- nothing changed
assert(#sentOfType("SYNC_DATA") == 0, "T11: duplicate push not suppressed")
DS:SetInventory("bags", { [14047] = 25 })  -- real change
Comm:SendIncrementalUpdate()
assert(#sentOfType("SYNC_DATA") == 1, "T11: changed push suppressed")

-- ── T12: sharing kill switch ─────────────────────────────────────
-- Both halves matter. The whole harness runs inside one wall-clock second and
-- T5 already served Buddy, so the 30 s per-sender serve cooldown (not the kill
-- switch) would answer the "no data" half on its own, and the test would pass
-- with the switch wired to nothing. Clear the cooldown around each serve so the
-- switch is what is actually under test, then prove the ON case serves.
clearSent()
addon.db.settings.shareData = false
Comm:_ResetServeCooldown()
recv("Buddy", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 0, "T12: shareData=false still served")
addon.db.settings.shareData = true
Comm:_ResetServeCooldown()
recv("Buddy", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 1, "T12: shareData=true refused a trusted contact")
passed("T12 shareData kill switch -- 0 sends off, 1 send on, cooldown cleared both ways")

-- ── T13: auto-add group/raid mates gated by settings (default off) ─
clearSent()
state.inGroup = true; state.inRaid = false; state.partyMembers = { "Newbie" }
addon.db.settings.autoAddParty = false
recv("Newbie", { _type = "HELLO", professions = {} })
assert(addon.db.contacts["Newbie-TestRealm"] == nil, "T13: auto-added with setting OFF")
addon.db.settings.autoAddParty = true
recv("Newbie", { _type = "HELLO", professions = {} })
local nc = addon.db.contacts["Newbie-TestRealm"]
assert(nc and nc.trusted == false, "T13: opt-in add missing or wrongly trusted")
state.inGroup = false; state.partyMembers = {}
addon.db.settings.autoAddParty = false


-- ── T14: ORDER_UPDATE declineReason -- stored on decline, sanitized ──
addon.db.contacts["Buddy-TestRealm"] = addon.db.contacts["Buddy-TestRealm"] or { autoSync=false, lastSync=0 }
addon.db.contacts["Buddy-TestRealm"].trusted = true
clearSent()
local odA = Orders:Create({ crafter = "Buddy-TestRealm",
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" }, quantity = 1 })
recv("Buddy", { _type = "ORDER_UPDATE", id = odA.id, status = "declined",
    declineReason = "no |cffffd200mats|r", updatedAt = time() + 1, token = "t14a" })
local dA = addon.db.orders[odA.id]
assert(dA.status == "declined", "T14a: decline not applied")
assert(dA.declineReason and dA.declineReason:find("||", 1, true), "T14a: reason pipe not escaped")
local odB = Orders:Create({ crafter = "Buddy-TestRealm",
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" }, quantity = 1 })
recv("Buddy", { _type = "ORDER_UPDATE", id = odB.id, status = "declined",
    declineReason = string.rep("z", 400), updatedAt = time() + 1, token = "t14b" })
assert(#addon.db.orders[odB.id].declineReason <= 150, "T14b: reason not length-capped")
local odC = Orders:Create({ crafter = "Buddy-TestRealm",
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" }, quantity = 1 })
recv("Buddy", { _type = "ORDER_UPDATE", id = odC.id, status = "accepted",
    declineReason = "sneaky", updatedAt = time() + 1, token = "t14c" })
assert(addon.db.orders[odC.id].declineReason == nil, "T14c: reason wrongly stored on non-decline")

-- ── T15: SYNC_DATA recipeCooldowns[] clamped on receipt ──────────
local nowT = time()
recv("Buddy", { _type = "SYNC_DATA", class = "MAGE", level = 70, faction = "Alliance",
    professions = { ["Alchemy"] = { skillLevel = 375, maxSkill = 375,
        recipeNames = { "Valid CD", "Past CD", "FarFuture CD", "Junk CD" },
        recipeSpells = { 0, 0, 0, 0 },
        recipeCooldowns = { nowT + 3600, nowT - 100, nowT + 40*86400, "abc" } } } })
local ap = addon.db.characters["Buddy-TestRealm"].professions["Alchemy"]
assert(ap.recipes["Valid CD"].cooldownReadyAt == nowT + 3600, "T15: valid cooldown not kept")
assert(ap.recipes["Past CD"].cooldownReadyAt == nil, "T15: past cooldown not dropped")
assert(ap.recipes["FarFuture CD"].cooldownReadyAt == nil, "T15: >30d cooldown not dropped")
assert(ap.recipes["Junk CD"].cooldownReadyAt == nil, "T15: non-numeric cooldown not dropped")

-- ── T16: GetUnknownRecipes tolerates a profession with no recipes table ──
-- Regression for RecipeDB.lua "bad argument #1 to 'pairs' (table expected,
-- got nil)". A remote/lightweight/fixture profession record can carry
-- skillLevel/maxSkill with NO .recipes subtable (e.g. /pbt fixture, or a
-- friend seen via HELLO before a full SYNC_DATA).
local RDB = addon.RecipeDB
assert(RDB, "T16: RecipeDB module missing")
RDB.data["Tailoring"] = {
    ["Linen Bag"] = { spellID = 111 },
    ["Silk Bag"]  = { spellID = 222 },
}
-- (a) no .recipes at all -> must not error; every static recipe is unknown
addon.db.characters["NoRec-TestRealm"] = { isRemote = true,
    professions = { Tailoring = { skillLevel = 375, maxSkill = 375 } } }
local ok, res = pcall(function() return RDB:GetUnknownRecipes("NoRec-TestRealm", "Tailoring") end)
assert(ok, "T16a: GetUnknownRecipes threw on nil recipes: " .. tostring(res))
assert(res["Linen Bag"] and res["Silk Bag"], "T16a: unknowns not all returned")
-- (b) sanity: a known recipe is still excluded (fix did not break the normal path)
addon.db.characters["HasRec-TestRealm"] = { isRemote = true,
    professions = { Tailoring = { skillLevel = 375, maxSkill = 375,
        recipes = { ["Linen Bag"] = { spellID = 111 } } } } }
local res2 = RDB:GetUnknownRecipes("HasRec-TestRealm", "Tailoring")
assert(res2["Linen Bag"] == nil, "T16b: known recipe wrongly listed as unknown")
assert(res2["Silk Bag"], "T16b: unknown recipe missing")

-- ── T17: guild-board Orders model (CreateOpen / GetMyOpen / Cancel-open) ──
-- The board UI (increment 2) reads these. An OPEN order has no crafter and must
-- stay OUT of the Direct outgoing queue, show up under GetMyOpen, and be
-- cancellable by its poster (which the board's Cancel button drives).
local myOpen = Orders:CreateOpen({
    item = { id = 21841, name = "Netherweave Bag", profession = "Tailoring" },
    quantity = 3,
})
assert(myOpen, "T17: CreateOpen failed")
assert(myOpen.status == Orders.STATUS.OPEN, "T17: open order not OPEN")
assert(myOpen.crafter == nil, "T17: open order has a crafter")
assert(myOpen.requester == ME, "T17: open order requester is not me")
assert(myOpen.matResponsibility == "requester", "T17: mat default not requester")
-- GetMyOpen returns it; GetOutgoing (the Direct queue) must not.
local mine = Orders:GetMyOpen()
local function listHas(list, id)
    for _, o in ipairs(list) do if o.id == id then return true end end
    return false
end
assert(listHas(mine, myOpen.id), "T17: GetMyOpen missing the open order")
assert(not listHas(Orders:GetOutgoing(), myOpen.id), "T17: open order leaked into Direct outgoing")
-- Cancel it (poster pulls the post): OPEN -> CANCELLED, then it drops off GetMyOpen.
local cancelled = Orders:Cancel(myOpen.id)
assert(cancelled and cancelled.status == Orders.STATUS.CANCELLED, "T17: cancel-open did not cancel")
assert(not listHas(Orders:GetMyOpen(), myOpen.id), "T17: cancelled open still on the board list")

-- ── T18: a cancelled OPEN order (crafter == nil) survives PruneHistory ──
-- Regression: cancelling an unclaimed board post makes a TERMINAL record with no
-- crafter, which byKey[o.crafter] used to index nil ("table index is nil" at
-- login). PruneHistory (and the history display) must tolerate a nil crafter.
assert(cancelled.crafter == nil, "T18: cancelled open unexpectedly has a crafter")
local okPrune, errPrune = pcall(function() return Orders:PruneHistory() end)
assert(okPrune, "T18: PruneHistory threw on a crafterless terminal order: " .. tostring(errPrune))
-- It is grouped under the requester and kept (well within the cap).
assert(addon.db.orders[cancelled.id] ~= nil, "T18: crafterless terminal order wrongly pruned")

-- ── T19: rev-7 contact gets an INCR delta on an inventory change ─────
-- Isolate the auto-push to one rev-7 contact so the send counts are exact.
for _, c in pairs(addon.db.contacts) do c.autoSync = false end
Comm._pushState = nil
addon.db.contacts["Deltapal-TestRealm"] = { trusted = true, autoSync = true, lastSync = 0, lastCommRev = 7 }
clearSent()
DS:SetInventory("bags", { [111] = 5 })
Comm:SendIncrementalUpdate()                       -- first push = full baseline
assert(#sentOfType("SYNC_DATA") == 1 and #sentOfType("INCR") == 0, "T19: baseline should be a full sync")
assert(sentOfType("SYNC_DATA")[1].payload.epoch ~= nil, "T19: baseline SYNC_DATA missing epoch stamp")
clearSent()
DS:SetInventory("bags", { [111] = 5, [222] = 9 })  -- inventory-only change
Comm:SendIncrementalUpdate()
assert(#sentOfType("INCR") == 1 and #sentOfType("SYNC_DATA") == 0, "T19: rev-7 inventory change should be an INCR delta")
local d19 = sentOfType("INCR")[1].payload
assert(d19.changes and d19.changes.bags and d19.changes.bags[222] == 9, "T19: delta missing the changed item")
assert(d19.changes.bags[111] == nil, "T19: delta re-sent an unchanged item")

-- ── T20: a profession change forces a full sync, not a delta ─────────
clearSent()
DS:SetProfessionData("Tailoring", { skillLevel = 301, maxSkill = 375, recipes = {} })
Comm:SendIncrementalUpdate()
assert(#sentOfType("SYNC_DATA") == 1 and #sentOfType("INCR") == 0, "T20: profession change should force a full sync")

-- ── T21: receiver applies an INCR (add / change / remove) ────────────
addon.db.contacts["Deltamate-TestRealm"] = { trusted = true, lastSync = 0 }
recv("Deltamate", { _type = "SYNC_DATA", epoch = 4, professions = {},
    inventory = { bags = { [100] = 10, [200] = 5 }, bank = {} } })      -- baseline
recv("Deltamate", { _type = "INCR", epoch = 4, seq = 1,
    changes = { bags = { [100] = 12, [300] = 7, [200] = 0 } } })        -- change / add / remove
local dm = DS:GetCharacter("Deltamate-TestRealm").inventory.bags
assert(dm[100] == 12 and dm[300] == 7 and dm[200] == nil, "T21: INCR add/change/remove not applied correctly")

-- ── T22: a sequence gap or wrong epoch drops the delta and resyncs ───
clearSent()
recv("Deltamate", { _type = "INCR", epoch = 4, seq = 3,               -- gap: expected seq 2
    changes = { bags = { [100] = 999 } } })
assert(DS:GetCharacter("Deltamate-TestRealm").inventory.bags[100] == 12, "T22: gapped delta was wrongly applied")
assert(#sentOfType("SYNC_REQ") == 1, "T22: gap did not trigger an auto-resync SYNC_REQ")
clearSent()
-- The gap resync is throttled to one SYNC_REQ per sender per 30s, and both
-- cases here run inside the same second, so clear the stamp to test the second
-- trigger (wrong epoch) on its own.
Comm._resyncAt = nil
recv("Deltamate", { _type = "INCR", epoch = 9, seq = 2, changes = { bags = { [100] = 1 } } })  -- wrong epoch
assert(DS:GetCharacter("Deltamate-TestRealm").inventory.bags[100] == 12, "T22: wrong-epoch delta was wrongly applied")
assert(#sentOfType("SYNC_REQ") == 1, "T22: wrong epoch did not trigger a resync")

-- ── T23: malformed INCR is rejected / sanitized ──────────────────────
recv("Deltamate", { _type = "SYNC_DATA", epoch = 5, professions = {},
    inventory = { bags = { [100] = 1 }, bank = {} } })                  -- rebaseline epoch5 seq0
recv("Deltamate", { _type = "INCR", epoch = 5, seq = 1, changes = "garbage" })   -- non-table changes
assert(DS:GetCharacter("Deltamate-TestRealm").inventory.bags[100] == 1, "T23: garbage changes altered inventory")
recv("Deltamate", { _type = "SYNC_DATA", epoch = 6, professions = {},
    inventory = { bags = { [100] = 1 }, bank = {} } })                  -- rebaseline epoch6 seq0
recv("Deltamate", { _type = "INCR", epoch = 6, seq = 1,
    changes = { bags = { ["notanid"] = 5, [100] = -3, [400] = 1e9 } } })  -- junk id, neg, oversize
local dj = DS:GetCharacter("Deltamate-TestRealm").inventory.bags
assert(dj["notanid"] == nil, "T23: non-numeric id accepted")
assert(dj[100] == 1, "T23: negative count applied (should be dropped)")
assert(dj[400] == 10^6, "T23: oversized count not clamped")

----------------------------------------------------------------------
-- 1.1.0 additions (T24-T54): canonical keys, distribution gating, guild
-- scope, board lifecycle, delta hardening, then the Scanner / RecipeDB /
-- MaterialCalc arm. T1-T23 above are unchanged.
----------------------------------------------------------------------

-- Is a plain value in an array? (T17's listHas walks order records.)
local function hasValue(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

local ITEM = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" }
local function boardOpen(id, requester, qty)
    return { _type = "ORDER_OPEN", order = {
        id = id, requester = requester, status = "open", quantity = qty or 1,
        item = { id = ITEM.id, name = ITEM.name, profession = ITEM.profession },
    } }
end
local function boardCount(requesterKey)
    local n = 0
    for _, e in pairs(addon.db.orderBoard or {}) do
        if not requesterKey or e.requester == requesterKey then n = n + 1 end
    end
    return n
end

-- ── T24: canonical key on a multi-word realm ─────────────────────
-- The realm here is "Test Realm", so every key crosses the normalization
-- boundary: AceComm hands us "Name-TestRealm" (Ambiguate strips the space)
-- while a pre-schema-2 record spells it "Name-Test Realm".
do
    -- (a) The sender arrives Ambiguate-normalized ("Ambi-TestRealm") while the
    -- record they hand us still spells the realm out, which is what a peer on an
    -- older build sends. Both must land on the canonical key, and RoleFor has to
    -- see us as the crafter either way.
    addon.db.contacts["Ambi-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    clearSent()
    recv("Ambi-TestRealm", { _type = "ORDER_NEW", token = "Ambi-TestRealm-1:new", order = {
        id = "Ambi-TestRealm-1", requester = "Ambi-Test Realm", crafter = "Me-Test Realm",
        item = ITEM, quantity = 1, status = "pending",
        createdAt = time(), updatedAt = time(),
    } })
    local amb = addon.db.orders["Ambi-TestRealm-1"]
    assert(amb, "T24a: order from an Ambiguate-normalized sender not stored")
    assert(amb.crafter == "Me-TestRealm", "T24a: crafter stored as " .. tostring(amb.crafter))
    assert(amb.requester == "Ambi-TestRealm", "T24a: requester stored as " .. tostring(amb.requester))
    assert(Orders:RoleFor(amb) == "crafter", "T24a: RoleFor did not see me as the crafter")
    amb.crafter = "Me-Test Realm"                 -- a pre-schema-2 record on disk
    assert(Orders:RoleFor(amb) == "crafter", "T24a: raw-realm crafter key lost the role")
    assert(listHas(Orders:GetIncoming(), amb.id),
        "T24a: a raw-realm order is invisible to the character it belongs to")
    amb.crafter = "Me-TestRealm"

    -- (b) our own GUILD broadcast comes back to us and must be dropped, in
    -- either spelling (the echo used to file us as a remote character).
    clearSent(); clearDeferred()
    recvOn(ME, { _type = "HELLO", professions = {} }, "GUILD")
    recvOn("Me-Test Realm", { _type = "HELLO", professions = {} }, "GUILD")
    assert(#sentOfType("HELLO_ACK") == 0, "T24b: acked our own guild HELLO")
    assert(#deferred == 0, "T24b: queued a deferred ack to ourselves")
    assert(not addon.db.characters[ME].isRemote, "T24b: our own record went remote")

    -- (c) /pb sync canonicalization, and the reply from the short name finds it.
    assert(Comm:NormalizeContactKey("bob-Test Realm") == "Bob-TestRealm",
        "T24c: NormalizeContactKey kept the space in the realm")
    assert(Comm:NormalizeContactKey("bob") == "Bob-TestRealm",
        "T24c: NormalizeContactKey did not default the realm")
    clearSent()
    Comm:RequestSync("ambi-Test Realm")
    assert(addon.db.contacts["Ambi-TestRealm"], "T24c: contact not stored under the canonical key")
    assert(firstOfType("SYNC_REQ").target == "Ambi", "T24c: same-realm target not shortened")
    recv("Ambi", { _type = "SYNC_DATA", professions = {},
        inventory = { bags = { [2589] = 3 }, bank = {} } })
    assert(DS:GetCharacter("Ambi-TestRealm").inventory.bags[2589] == 3,
        "T24c: reply from the short name missed the contact")
end
passed("T24 canonical key on a multi-word realm -- RoleFor, self-echo filter, contacts lookup")

-- ── T25: a directed message on a broadcast channel is dropped ────
do
    clearSent()
    Comm:_ResetServeCooldown()
    recvOn("Buddy", { _type = "SYNC_REQ" }, "GUILD")
    assert(#sent == 0, "T25: a GUILD-channel SYNC_REQ was answered (one message pulls the guild)")
    local held = DS:GetCharacter("Buddy-TestRealm").inventory.bags[123]
    recvOn("Buddy", { _type = "SYNC_DATA", professions = {},
        inventory = { bags = {}, bank = {} } }, "GUILD")
    assert(DS:GetCharacter("Buddy-TestRealm").inventory.bags[123] == held,
        "T25: a GUILD-channel SYNC_DATA was applied")
end
passed("T25 distribution gating -- SYNC_REQ and SYNC_DATA on GUILD are ignored, 0 sends")

-- ── T26: a guild-tier SYNC_REQ is served recipes only ────────────
do
    joinGuild("Guildie")
    clearSent()
    recv("Guildie", { _type = "SYNC_REQ" })
    local sd = firstOfType("SYNC_DATA")
    assert(sd, "T26: a guildmate was not served at all")
    assert(sd.payload.partial == true, "T26: the guild serve is not marked partial")
    assert(sd.payload.inventory == nil, "T26: the guild serve carried inventory")
    assert(sd.payload.epoch == nil, "T26: a recipes-only serve rebased the delta epoch")
    assert(sd.payload.professions and next(sd.payload.professions), "T26: no recipes served")
    assert(addon.db.contacts["Guildie-TestRealm"] == nil, "T26: a guild serve persisted a contact")
end
passed("T26 guild tier -- SYNC_REQ served with no inventory key and partial=true")

-- ── T27: a partial SYNC_DATA keeps the stored inventory ──────────
do
    addon.db.contacts["Partpal-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    recv("Partpal", { _type = "SYNC_DATA", epoch = 11, professions = {},
        inventory = { bags = { [77] = 4 }, bank = { [88] = 1 } } })
    local inv = DS:GetCharacter("Partpal-TestRealm").inventory
    assert(inv.bags[77] == 4 and inv.bank[88] == 1, "T27: the full payload did not land")
    recv("Partpal", { _type = "SYNC_DATA", partial = true, professions = {
        Tailoring = { skillLevel = 300, maxSkill = 375, recipeNames = { "Bolt of Runecloth" } } } })
    local rec = DS:GetCharacter("Partpal-TestRealm")
    assert(rec.inventory.bags[77] == 4 and rec.inventory.bank[88] == 1,
        "T27: a recipes-only payload wiped the stored inventory")
    assert(rec.professions.Tailoring.recipes["Bolt of Runecloth"], "T27: the recipes did not land")
    -- The partial must not rebase the delta stream either.
    recv("Partpal", { _type = "INCR", epoch = 11, seq = 1, changes = { bags = { [77] = 9 } } })
    assert(DS:GetCharacter("Partpal-TestRealm").inventory.bags[77] == 9,
        "T27: the partial payload moved the delta baseline")
end
passed("T27 partial SYNC_DATA -- stored inventory and delta baseline both survive")

-- ── T28: unsolicited push from a guild-only sender ───────────────
do
    clearSent()
    local push = { _type = "SYNC_DATA", class = "MAGE", level = 70, faction = "Alliance",
        professions = { Alchemy = { skillLevel = 375, maxSkill = 375,
            recipeNames = { "Elixir of Fortitude" }, recipeSpells = { 3188 } } },
        inventory = { bags = { [13446] = 12 }, bank = {} } }
    recv("Guildie", push)
    assert(DS:GetCharacter("Guildie-TestRealm") == nil,
        "T28: a guild-only sender wrote a character record unasked")
    Comm:RequestGuildSync("Guildie-TestRealm")
    recv("Guildie", push)
    local g = DS:GetCharacter("Guildie-TestRealm")
    assert(g and g.professions.Alchemy, "T28: the reply to our own request was dropped")
    assert(Comm._pendingReq["Guildie-TestRealm"] == nil, "T28: pending request not cleared on receipt")
end
passed("T28 guild-only push -- dropped unsolicited, accepted after RequestGuildSync")

-- ── T29: a guild HELLO is acked late, and only once per 60 s ─────
do
    clearSent(); clearDeferred()
    recvOn("Guildie", { _type = "HELLO",
        professions = { Alchemy = { skillLevel = 375, maxSkill = 375 } } }, "GUILD")
    assert(#sentOfType("HELLO_ACK") == 0, "T29: a guild HELLO was acked immediately (N-whisper burst)")
    assert(#deferred == 1, "T29: no deferred ack was queued")
    runDeferred()
    assert(#sentOfType("HELLO_ACK") == 1, "T29: the deferred ack never sent")
    recvOn("Guildie", { _type = "HELLO", professions = {} }, "GUILD")
    assert(#deferred == 0, "T29: a second HELLO inside the 60 s floor queued another ack")
    runDeferred()
    assert(#sentOfType("HELLO_ACK") == 1, "T29: acked the same sender twice inside 60 s")
end
passed("T29 guild HELLO -- acked only after the deferred delay, never twice in 60 s")

-- ── T30: ORDER_OPEN ids are bound to their poster ────────────────
do
    addon.db.orderBoard = {}
    joinGuild("Guildie", "Buddy")
    Comm._lastOpenAt = nil
    -- A legacy id minted on a multi-word realm carries a space; its owner may post it.
    recvOn("Buddy", boardOpen("Buddy-Test Realm-90", "Buddy-TestRealm"), "GUILD")
    assert(addon.db.orderBoard["Buddy-Test Realm-90"], "T30: legacy multi-word-realm id refused")
    Comm._lastOpenAt = nil
    recvOn("Buddy", boardOpen("Buddy-TestRealm-91", "Buddy-TestRealm"), "GUILD")
    assert(addon.db.orderBoard["Buddy-TestRealm-91"], "T30: the owner's own post was refused")
    -- Hijack: overwrite an id someone else posted.
    Comm._lastOpenAt = nil
    recvOn("Guildie", boardOpen("Buddy-TestRealm-91", "Guildie-TestRealm"), "GUILD")
    assert(addon.db.orderBoard["Buddy-TestRealm-91"].requester == "Buddy-TestRealm",
        "T30: another guildmate took over an id already on the board")
    -- Squat: claim an id its owner has not posted yet.
    Comm._lastOpenAt = nil
    recvOn("Guildie", boardOpen("Buddy-TestRealm-92", "Guildie-TestRealm"), "GUILD")
    assert(addon.db.orderBoard["Buddy-TestRealm-92"] == nil,
        "T30: a guildmate squatted on an id belonging to someone else")
end
passed("T30 board anti-spoof -- an id not derived from the sender is dropped (hijack and squat)")

-- ── T31: board caps and the per-sender post cooldown ─────────────
do
    addon.db.orderBoard = {}
    Comm._lastOpenAt = nil
    recvOn("Buddy", boardOpen("Buddy-TestRealm-100"), "GUILD")
    recvOn("Buddy", boardOpen("Buddy-TestRealm-101"), "GUILD")
    assert(addon.db.orderBoard["Buddy-TestRealm-100"], "T31: the first post was refused")
    assert(addon.db.orderBoard["Buddy-TestRealm-101"] == nil, "T31: the 5 s post cooldown is not enforced")
    -- A re-broadcast of a post we already hold is idempotent and keeps postedAt.
    addon.db.orderBoard["Buddy-TestRealm-100"].postedAt = 12345
    recvOn("Buddy", boardOpen("Buddy-TestRealm-100"), "GUILD")
    assert(addon.db.orderBoard["Buddy-TestRealm-100"].postedAt == 12345,
        "T31: a login re-broadcast reset postedAt (it would dodge the TTL sweep)")

    -- 20 open posts per requester.
    addon.db.orderBoard = {}
    for i = 1, 21 do
        Comm._lastOpenAt = nil
        recvOn("Buddy", boardOpen("Buddy-TestRealm-" .. (200 + i)), "GUILD")
    end
    assert(boardCount("Buddy-TestRealm") == 20,
        "T31: per-requester cap is " .. boardCount("Buddy-TestRealm") .. ", want 20")
    assert(addon.db.orderBoard["Buddy-TestRealm-221"], "T31: the newest post was evicted, not the oldest")

    -- 200 posts total, oldest postedAt evicted first.
    addon.db.orderBoard = {}
    for i = 1, 199 do
        local fid = "Filler-TestRealm-" .. i
        addon.db.orderBoard[fid] = { id = fid, requester = "Filler-TestRealm", status = "open",
            item = { id = 1, name = "x" }, quantity = 1, postedAt = time() - i }
    end
    Comm._lastOpenAt = nil
    recvOn("Guildie", boardOpen("Guildie-TestRealm-1"), "GUILD")
    assert(boardCount() == 200, "T31: board holds " .. boardCount() .. " before the cap, want 200")
    Comm._lastOpenAt = nil
    recvOn("Guildie", boardOpen("Guildie-TestRealm-2"), "GUILD")
    assert(boardCount() == 200, "T31: board grew past the 200 cap to " .. boardCount())
    assert(addon.db.orderBoard["Filler-TestRealm-199"] == nil, "T31: the oldest post was not evicted")
    assert(addon.db.orderBoard["Guildie-TestRealm-2"], "T31: the new post was not stored")
    addon.db.orderBoard = {}
end
passed("T31 board caps -- 20 per requester, 200 total, one accepted new post per sender per 5 s")

-- ── T32: SweepBoard drops stale posts, days <= 0 disables it ─────
do
    local function seedBoard()
        addon.db.orderBoard = {
            old   = { id = "old",   requester = "Buddy-TestRealm", status = "open",
                      item = { id = 1, name = "x" }, quantity = 1, postedAt = time() - 100 * 86400 },
            fresh = { id = "fresh", requester = "Buddy-TestRealm", status = "open",
                      item = { id = 1, name = "x" }, quantity = 1, postedAt = time() },
        }
    end
    seedBoard()
    assert(Orders:SweepBoard() == 1, "T32: the sweep did not drop exactly the stale post")
    assert(addon.db.orderBoard.old == nil and addon.db.orderBoard.fresh, "T32: the wrong entry was swept")
    seedBoard()
    addon.db.settings.orderExpiryDays = 0
    assert(Orders:SweepBoard() == 0, "T32: days <= 0 did not disable the sweep")
    assert(addon.db.orderBoard.old, "T32: expiry is off but the post was swept anyway")
    addon.db.settings.orderExpiryDays = 14
    addon.db.orderBoard = {}
end
passed("T32 SweepBoard -- an old postedAt is dropped, orderExpiryDays = 0 turns it off")

-- ── T33: OPEN orders expire and the board is told ────────────────
do
    local o33 = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    o33.createdAt = time() - 20 * 86400
    local n33, ids33 = Orders:ExpireStale()
    assert(n33 >= 1, "T33: a stale OPEN post did not expire")
    assert(hasValue(ids33, o33.id), "T33: ExpireStale did not return the expired OPEN id")
    assert(addon.db.orders[o33.id].status == "expired", "T33: the record is not EXPIRED")

    local o33b = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    o33b.createdAt = time() - 20 * 86400
    clearSent()
    Comm:RunOrderMaintenance(false)
    local closed = firstOfType("ORDER_CLOSED")
    assert(closed, "T33: maintenance broadcast no ORDER_CLOSED for the expired post")
    assert(closed.payload.orderId == o33b.id, "T33: the wrong id was closed")
    assert(closed.payload.reason == "expired", "T33: reason is " .. tostring(closed.payload.reason))
    assert(closed.channel == "GUILD", "T33: the close did not go to the guild")
end
passed("T33 expiry -- ExpireStale returns OPEN ids and maintenance broadcasts ORDER_CLOSED{expired}")

-- ── T34: a claim on an order we no longer have ───────────────────
do
    clearSent()
    recv("Guildie", { _type = "ORDER_CLAIM", orderId = "Ghost-TestRealm-7" })
    local cl = firstOfType("ORDER_CLOSED")
    assert(cl, "T34: an unknown claim was answered with nothing (their board stays dead)")
    assert(cl.payload.orderId == "Ghost-TestRealm-7", "T34: the wrong id was closed")
    assert(cl.payload.reason == "cancelled", "T34: reason is " .. tostring(cl.payload.reason))
    assert(cl.channel == "WHISPER" and cl.target == "Guildie", "T34: the close was not targeted at the claimer")
end
passed("T34 unknown claim -- answered with a targeted ORDER_CLOSED so the board self-heals")

-- ── T35: a status regression is refused however new it claims to be ──
do
    local o35 = Orders:Create({ crafter = "Buddy-TestRealm", item = ITEM, quantity = 1 })
    o35.status = "crafted"
    o35.updatedAt = time()
    local _, applied = Orders:ApplyRemoteStatus(o35.id, "accepted", nil, time() + 120, nil, "crafter")
    assert(applied == false, "T35: a rank regression carrying a later updatedAt was applied")
    assert(addon.db.orders[o35.id].status == "crafted", "T35: the order walked backwards")
    local _, fwd = Orders:ApplyRemoteStatus(o35.id, "completed", "requester", time() + 121, nil, "crafter")
    assert(fwd == true and addon.db.orders[o35.id].status == "completed",
        "T35: a legal forward move was refused")
    assert(addon.db.orders[o35.id].completedBy == "crafter",
        "T35: completedBy was read off the wire instead of derived from the sender role")
end
passed("T35 ApplyRemoteStatus -- a later updatedAt cannot regress the rank")

-- ── T36: cancelling after a claim goes out as ORDER_UPDATE ───────
do
    local o36 = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    clearSent()
    Comm:SendOrderUpdate(o36)
    assert(#sentOfType("ORDER_UPDATE") == 0,
        "T36: an unclaimed OPEN post has no counterparty, so it must close on the board instead")
    assert(Orders:AssignFromClaim(o36.id, "Buddy-TestRealm"), "T36: the claim did not assign")
    local cancelled = Orders:Cancel(o36.id)
    assert(cancelled and cancelled.status == "cancelled", "T36: the requester could not cancel")
    clearSent()
    Comm:SendOrderUpdate(cancelled)
    local up = firstOfType("ORDER_UPDATE")
    assert(up, "T36: the assigned crafter was never told the order was cancelled")
    assert(up.target == "Buddy", "T36: the update went to " .. tostring(up.target))
    assert(up.payload.status == "cancelled", "T36: wrong status on the wire")
end
passed("T36 cancel after claim -- the assigned crafter gets ORDER_UPDATE, not a board close")

-- ── T37: NaN is rejected by sanInt and sanID ─────────────────────
do
    local nan = 0 / 0
    assert(nan ~= nan, "T37: this VM did not produce a NaN")
    addon.db.contacts["Nanpal-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    recv("Nanpal", { _type = "SYNC_DATA", class = "MAGE", level = nan, faction = "Alliance",
        epoch = nan,
        professions = { Alchemy = { skillLevel = nan, maxSkill = nan,
            recipeNames = { "Nan Recipe" }, recipeSpells = { nan } } },
        inventory = { bags = { [55] = 4 }, bank = {} } })
    local rec = DS:GetCharacter("Nanpal-TestRealm")
    assert(rec.level == 0, "T37: a NaN level slipped past sanInt as " .. tostring(rec.level))
    assert(rec.professions.Alchemy.skillLevel == 0, "T37: a NaN skill level slipped past sanInt")
    assert(rec.professions.Alchemy.maxSkill == 375, "T37: a NaN maxSkill did not fall back to the default")
    assert(rec.professions.Alchemy.recipes["Nan Recipe"].spellID == nil,
        "T37: a NaN spellID slipped past sanID")
    -- A NaN epoch would wedge delta sync for this peer forever; it defaults to 0.
    recv("Nanpal", { _type = "INCR", epoch = 0, seq = 1, changes = { bags = { [55] = 9 } } })
    assert(DS:GetCharacter("Nanpal-TestRealm").inventory.bags[55] == 9,
        "T37: the NaN epoch was stored instead of defaulted")
end
passed("T37 NaN ingress -- sanInt and sanID return their defaults, delta sync stays usable")

-- ── T38: the delta epoch is clock-seeded, never restarted ────────
do
    Comm._pushState = nil
    assert(Comm:SendFullSync("Epochpal-TestRealm"), "T38: the full sync was refused")
    local e1 = Comm._pushState["Epochpal-TestRealm"].epoch
    assert(e1 > 10 ^ 9, "T38: the epoch is not clock-seeded (" .. tostring(e1) .. ")")
    Comm._pushState = nil                       -- a /reload drops the send state
    local realTime = time
    time = function() return realTime() + 60 end -- and the clock moved on meanwhile
    Comm:SendFullSync("Epochpal-TestRealm")
    local e2 = Comm._pushState["Epochpal-TestRealm"].epoch
    time = realTime
    assert(e2 > e1, "T38: a reloaded sender reissued epoch " .. e2 .. " over " .. e1)
end
passed("T38 epoch hygiene -- a reloaded sender never reissues an epoch the receiver may hold")

-- ── T39: the gap resync is throttled per sender ──────────────────
do
    addon.db.contacts["Throttle-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    recv("Throttle", { _type = "SYNC_DATA", epoch = 21, professions = {},
        inventory = { bags = { [9] = 1 }, bank = {} } })
    Comm._resyncAt = nil
    clearSent()
    recv("Throttle", { _type = "INCR", epoch = 21, seq = 5, changes = { bags = { [9] = 2 } } })
    recv("Throttle", { _type = "INCR", epoch = 21, seq = 6, changes = { bags = { [9] = 3 } } })
    assert(#sentOfType("SYNC_REQ") == 1,
        "T39: two gaps in one second produced " .. #sentOfType("SYNC_REQ") .. " SYNC_REQs")
    assert(DS:GetCharacter("Throttle-TestRealm").inventory.bags[9] == 1, "T39: a gapped delta was applied")
end
passed("T39 resync throttle -- two gaps inside one second send exactly one SYNC_REQ")

-- ── T40: the ChatThrottleLib pipe each message rides ─────────────
do
    clearSent()
    local pk = "Priopal-TestRealm"
    Comm:SendFullSync(pk)
    Comm:SendWhisper("SYNC_REQ", {}, pk)
    Comm:SendHelloAck(pk)
    Comm:SendOrderAck(pk, "tok:prio")
    local o40 = Orders:Create({ crafter = pk, item = ITEM, quantity = 1 })
    Comm:SendOrderNew(o40)
    Comm:SendOrderUpdate(o40)
    Comm:BroadcastOpenOrder(o40)
    Comm:BroadcastOrderClosed(o40.id, "cancelled")
    assert(firstOfType("SYNC_DATA").prio == "BULK", "T40: SYNC_DATA is not on the BULK pipe")
    assert(firstOfType("SYNC_REQ").prio == "NORMAL", "T40: SYNC_REQ is not on the NORMAL pipe")
    assert(firstOfType("HELLO_ACK").prio == "NORMAL", "T40: HELLO_ACK is not on the NORMAL pipe")
    for _, t in ipairs({ "ORDER_ACK", "ORDER_NEW", "ORDER_UPDATE", "ORDER_OPEN", "ORDER_CLOSED" }) do
        local s = firstOfType(t)
        assert(s, "T40: no " .. t .. " was sent")
        assert(s.prio == "ALERT", "T40: " .. t .. " rides " .. tostring(s.prio) .. ", want ALERT")
    end
    -- INCR rides BULK with the rest of the payload traffic.
    for _, c in pairs(addon.db.contacts) do c.autoSync = false end
    Comm._pushState = nil
    addon.db.contacts[pk] = { trusted = true, autoSync = true, lastSync = 0, lastCommRev = 7 }
    DS:SetInventory("bags", { [777] = 1 })
    Comm:SendIncrementalUpdate()                    -- full baseline
    clearSent()
    DS:SetInventory("bags", { [777] = 2 })
    Comm:SendIncrementalUpdate()                    -- delta
    assert(firstOfType("INCR"), "T40: the inventory change did not produce a delta")
    assert(firstOfType("INCR").prio == "BULK", "T40: INCR is not on the BULK pipe")
end
passed("T40 priorities -- BULK for SYNC_DATA and INCR, ALERT for ORDER_*, NORMAL for the rest")

-- ── T41: one quantity cap on every minting path ──────────────────
do
    assert(Orders.MAX_QTY == 999, "T41: the single quantity cap moved")
    assert(Orders:Create({ crafter = "Buddy-TestRealm", item = ITEM, quantity = 5000 }).quantity == 999,
        "T41: Create did not clamp to 999")
    assert(Orders:CreateOpen({ item = ITEM, quantity = 10 ^ 9 }).quantity == 999,
        "T41: CreateOpen did not clamp to 999")
    assert(Orders:CreateOpen({ item = ITEM, quantity = 0 }).quantity == 1,
        "T41: CreateOpen did not clamp up to 1")
    -- The remote ingress clamp is the one bounding attacker-controlled input.
    addon.db.orderBoard = {}
    Comm._lastOpenAt = nil
    recvOn("Buddy", boardOpen("Buddy-TestRealm-300", nil, 99999), "GUILD")
    assert(addon.db.orderBoard["Buddy-TestRealm-300"].quantity == 999,
        "T41: the board ingress clamp is gone")
    addon.db.orderBoard = {}
end
passed("T41 quantity clamp -- 999 from Create, CreateOpen and the board ingress")

-- ── T42: a rejected ack shows as rejected, not delivered ─────────
do
    clearSent()
    local o42 = Orders:Create({ crafter = "Buddy-TestRealm", item = ITEM, quantity = 1 })
    Comm:SendOrderNew(o42)
    assert(o42.deliveryState == "sent", "T42: the indicator did not start at sent")
    recv("Buddy", { _type = "ORDER_ACK", token = o42.id .. ":new", rejected = true })
    assert(addon.db.orders[o42.id].deliveryState == "rejected",
        "T42: a refused order still reads as delivered")
    local o42b = Orders:Create({ crafter = "Buddy-TestRealm", item = ITEM, quantity = 1 })
    Comm:SendOrderNew(o42b)
    recv("Buddy", { _type = "ORDER_ACK", token = o42b.id .. ":new" })
    assert(addon.db.orders[o42b.id].deliveryState == "delivered", "T42: a plain ack lost its meaning")
end
passed("T42 ack-on-refusal -- rejected=true sets deliveryState \"rejected\"")

-- ── T43: an offline contact is backed off and skipped ────────────
do
    for _, c in pairs(addon.db.contacts) do c.autoSync = false end
    Comm._pushState = nil
    addon.db.contacts["Offliner-TestRealm"] = { trusted = true, autoSync = true, lastSync = 0 }
    clearSent()
    DS:SetInventory("bags", { [888] = 1 })
    Comm:SendIncrementalUpdate()
    assert(#sentOfType("SYNC_DATA") == 1, "T43: the baseline push never went out")
    assert(Comm:OnSystemMessage("No player named 'Offliner' is currently playing.") == true,
        "T43: the not-found line was not attributed to our own whisper")
    local oc = addon.db.contacts["Offliner-TestRealm"]
    assert(oc.offlineUntil and oc.offlineUntil > time(), "T43: the contact was not backed off")
    clearSent()
    DS:SetInventory("bags", { [888] = 2 })
    Comm:SendIncrementalUpdate()
    assert(#sent == 0, "T43: pushed to a contact the server says is not logged in")
    recv("Offliner", { _type = "HELLO", professions = {} })
    assert(addon.db.contacts["Offliner-TestRealm"].offlineUntil == nil,
        "T43: an inbound message did not lift the back-off")
end
passed("T43 offline back-off -- OnSystemMessage marks the contact, the next push skips them")

-- ── T44: ForgetPeer clears every session table ───────────────────
do
    local FK = "Forgetful-TestRealm"
    local SESSION = { "_pushState", "_recvState", "_guildSyncAt", "_resyncAt",
                      "_helloAckAt", "_pendingReq", "_lastOpenAt" }
    joinGuild("Guildie", "Buddy", "Forgetful")
    addon.db.contacts[FK] = { trusted = true, autoSync = true, lastSync = 0, lastCommRev = 7 }
    Comm:_ResetServeCooldown()
    clearSent()
    recv("Forgetful", { _type = "SYNC_REQ" })                 -- lastServed + _pushState
    assert(#sentOfType("SYNC_DATA") == 1, "T44: setup serve missing")
    clearSent()
    recv("Forgetful", { _type = "SYNC_REQ" })
    assert(#sentOfType("SYNC_DATA") == 0, "T44: the serve cooldown is not armed")
    recv("Forgetful", { _type = "SYNC_DATA", epoch = 31, professions = {},
        inventory = { bags = {}, bank = {} } })               -- _recvState
    Comm:RequestGuildSync(FK)                                 -- _guildSyncAt + _pendingReq
    Comm._resyncAt = nil
    recv("Forgetful", { _type = "INCR", epoch = 31, seq = 4, changes = { bags = {} } })  -- _resyncAt
    recv("Forgetful", { _type = "HELLO", professions = {} })  -- _helloAckAt
    Comm._lastOpenAt = nil
    recvOn("Forgetful", boardOpen(FK .. "-1"), "GUILD")       -- _lastOpenAt
    clearSent()
    local o44 = Orders:Create({ crafter = FK, item = ITEM, quantity = 1 })
    Comm:SendOrderNew(o44)
    timers[#timers].fn()                                      -- ack timeout parks it
    local tok44 = o44.id .. ":new"
    assert(addon.db.orderOutbox[tok44], "T44: setup outbox entry missing")
    for _, name in ipairs(SESSION) do
        assert(Comm[name] and Comm[name][FK] ~= nil, "T44: setup did not populate " .. name)
    end
    Comm:ForgetPeer(FK)
    for _, name in ipairs(SESSION) do
        assert(Comm[name][FK] == nil, "T44: ForgetPeer left " .. name)
    end
    assert(addon.db.orderOutbox[tok44] == nil, "T44: ForgetPeer left the queued order message")
    clearSent()
    recv("Forgetful", { _type = "SYNC_REQ" })
    assert(#sentOfType("SYNC_DATA") == 1, "T44: ForgetPeer did not clear the serve cooldown")
    addon.db.contacts[FK].autoSync = false
    addon.db.orderBoard = {}
end
passed("T44 ForgetPeer -- every peer-keyed session table, the outbox and lastServed are cleared")

----------------------------------------------------------------------
-- Scanner / RecipeDB / MaterialCalc. These drive the profession windows
-- through the same event frame the comm tests use, so the local character
-- record below is rewritten from here on.
----------------------------------------------------------------------
local Scanner, RDB, MC = addon.Scanner, addon.RecipeDB, addon.MaterialCalc
assert(Scanner and RDB and MC, "harness: Scanner / RecipeDB / MaterialCalc not loaded")

-- ── T45: a linked profession window writes nothing ───────────────
do
    DS:SetProfessionData("Tailoring", { skillLevel = 300, maxSkill = 375,
        recipes = { ["Mine"] = { spellID = 1 } } })
    sim.linked = true
    sim.tradeLine = { "Leatherworking", 375, 375 }
    sim.tradeRows = { { "Their Recipe", "optimal", 1, true } }
    fire("TRADE_SKILL_SHOW")
    local profs = DS:GetCharacter(ME).professions
    assert(profs.Leatherworking == nil, "T45: a linked window created a profession")
    assert(profs.Tailoring.recipes["Mine"], "T45: a linked window clobbered our own recipes")
    sim.linked = false
end
passed("T45 linked window -- another player's tradeskill link is never written to us")

-- ── T46: pet training is not a profession ────────────────────────
do
    sim.pet = true
    sim.craftLine = { "Beast Training", 0, 0 }
    sim.craftRows = { { "Growl", "trivial", 1 } }
    fire("CRAFT_SHOW")
    assert(DS:GetCharacter(ME).professions["Beast Training"] == nil,
        "T46: a pet trainer stored Beast Training as a profession")
    sim.pet = false
end
passed("T46 pet training -- the Craft window for a hunter pet writes nothing")

-- ── T47: a partial recipe list never shrinks the record ──────────
do
    sim.tradeLine = { "Tailoring", 301, 375 }
    sim.tradeRows = { { "Bolt of Linen Cloth", "optimal", 1, true } }
    sim.nameFilter = "linen"
    fire("TRADE_SKILL_UPDATE")
    assert(DS:GetCharacter(ME).professions.Tailoring.recipes["Mine"],
        "T47: a name filter wiped every recipe it hid")
    sim.nameFilter = ""
    sim.tradeRows = {
        { "Cloth", "header", nil, false },
        { "Bolt of Linen Cloth", "optimal", 1, true },
    }
    fire("TRADE_SKILL_UPDATE")
    assert(DS:GetCharacter(ME).professions.Tailoring.recipes["Mine"],
        "T47: a collapsed header wiped every recipe under it")
    -- A complete list still replaces the table, numAvail included.
    sim.tradeRows = {
        { "Cloth", "header", nil, true },
        { "Bolt of Linen Cloth", "optimal", 3, true },
    }
    fire("TRADE_SKILL_UPDATE")
    local tl = DS:GetCharacter(ME).professions.Tailoring
    assert(tl.recipes["Bolt of Linen Cloth"], "T47: a full list was not persisted")
    assert(tl.recipes["Mine"] == nil, "T47: a full list did not replace the recipe table")
    assert(tl.recipes["Bolt of Linen Cloth"].numAvail == 3, "T47: numAvail was not captured")
end
passed("T47 partial list -- a name filter or collapsed header skips the persist, a full list writes")

-- ── T48: the bank is only scanned while it is open ───────────────
do
    sim.bags = { [-1] = { slots = 1, [1] = { link = "|Hitem:2589:0|h[Linen Cloth]|h", count = 5 } } }
    fire("BANKFRAME_OPENED")
    assert(DS:GetCharacter(ME).inventory.bank[2589] == 5, "T48: the bank was not scanned while open")
    fire("BANKFRAME_CLOSED")
    sim.bags = {}                                   -- every slot reads empty once shut
    fire("PLAYERBANKSLOTS_CHANGED")
    assert(DS:GetCharacter(ME).inventory.bank[2589] == 5,
        "T48: a scan with the bank shut wiped the stored bank")
end
passed("T48 bank gate -- PLAYERBANKSLOTS_CHANGED outside BANKFRAME_OPENED cannot wipe the bank")

-- ── T49: BAG_UPDATE throttles to leading plus one trailing scan ──
do
    -- No autoSync contact, so Comm's own debounce arms nothing here and every
    -- timer counted below is the Scanner's.
    for _, c in pairs(addon.db.contacts) do c.autoSync = false end
    local scans = 0
    local realScan = Scanner.ScanInventory
    Scanner.ScanInventory = function() scans = scans + 1 end
    Scanner._lastBagScan, Scanner._bagTimer = nil, nil
    local before = #timers
    for _ = 1, 20 do fire("BAG_UPDATE") end
    assert(scans == 1, "T49: expected 1 leading scan, got " .. scans)
    local armed = 0
    for i = before + 1, #timers do
        if not timers[i].cancelled then armed = armed + 1 end
    end
    assert(armed == 1, "T49: the burst armed " .. armed .. " trailing scans, want 1")
    assert(Scanner._bagTimer, "T49: no trailing scan was armed")
    clock = clock + 1
    Scanner._bagTimer.fn()
    assert(scans == 2, "T49: the trailing scan never ran")
    clock = clock + 1                               -- past the throttle window
    for _ = 1, 5 do fire("BAG_UPDATE") end
    assert(scans == 3, "T49: a scan past the throttle window did not run immediately")
    Scanner.ScanInventory = realScan
end
passed("T49 bag throttle -- a 20-event burst is one leading scan plus one trailing scan")

-- ── T50: ScanProfessions restores collapsed headers by name ──────
do
    -- Two collapsed headers, so expanding them shifts every index below the
    -- first one: a restore by SAVED INDEX lands on "Tailoring" instead of
    -- "Secondary Skills" and leaves the user's list wrong.
    sim.skillLines = {
        { "Professions", true },
        { "Tailoring", false, 305, 375 },
        { "Mining", false, 120, 375 },
        { "Secondary Skills", true },
        { "First Aid", false, 225, 300 },
        { "Weapon Skills", true },
        { "Swords", false, 350, 350 },
    }
    sim.collapsedHeaders = { ["Professions"] = true, ["Secondary Skills"] = true }
    sim.expandCalls = 0
    sim.collapsed = {}
    Scanner:ScanProfessions()
    assert(sim.expandCalls == 1, "T50: the headers were not expanded before the scan")
    assert(#sim.collapsed == 2, "T50: restored " .. #sim.collapsed .. " headers, want 2")
    local back = {}
    for _, n in ipairs(sim.collapsed) do back[n] = true end
    assert(back["Professions"] and back["Secondary Skills"],
        "T50: restored by index, not by name: " .. table.concat(sim.collapsed, ", "))
    assert(sim.collapsedHeaders["Professions"] and sim.collapsedHeaders["Secondary Skills"],
        "T50: the user's collapsed headers were left open")
    assert(not sim.collapsedHeaders["Weapon Skills"], "T50: a header the user had open was collapsed")
    local profs = DS:GetCharacter(ME).professions
    assert(profs.Tailoring.skillLevel == 305, "T50: the rank under a collapsed header was not read")
    assert(profs["First Aid"] and profs["First Aid"].skillLevel == 225,
        "T50: a profession under the second collapsed header was never scanned")
end
passed("T50 skill headers -- expand, scan, then re-collapse the user's headers by name")

-- ── T51: multi-valued RecipeDB maps, itemID 0 guarded ────────────
do
    RDB:RegisterProfession("Leatherworking",
        { ["Gordok Ogre Suit"] = { spellID = 22815, itemID = 18258, reagents = {} } })
    RDB:RegisterProfession("Tailoring",
        { ["Gordok Ogre Suit"] = { spellID = 22813, itemID = 18258, reagents = {} } })
    assert(#RDB:GetRecipesForItem(18258) == 2, "T51: itemToRecipe is not multi-valued")
    assert(RDB:GetRecipeByName("Gordok Ogre Suit", "Tailoring").spellID == 22813,
        "T51: the name map ignored profName")
    assert(RDB:GetRecipeByName("Gordok Ogre Suit", "Leatherworking").spellID == 22815,
        "T51: the name map ignored profName")
    RDB:RegisterProfession("Enchanting",
        { ["PB Test Enchant"] = { spellID = 999010, itemID = 0, reagents = {} } })
    assert(RDB.itemToRecipe[0] == nil, "T51: itemID 0 (an enchant produces no item) was registered")
    assert(not RDB:IsCraftable(0), "T51: item 0 reads as craftable")
end
passed("T51 RecipeDB -- itemToRecipe holds every producer, itemID 0 is never registered")

-- ── T52: cycle detection over the real recipe graph ──────────────
do
    assert(RDB:IsCyclicItem(22451) == true, "T52: Primal Air is not on a cycle (the transmute ring)")
    assert(RDB:IsCyclicItem(23445) == false, "T52: Fel Iron Bar reads as cyclic")
end
passed("T52 IsCyclicItem -- true for Primal Air, false for Fel Iron Bar")

-- ── T53: the calculator buys cycles and expands known smelts ─────
do
    DS:SetInventory("bags", {})
    DS:SetInventory("bank", {})
    DS:SetProfessionData("Alchemy", { skillLevel = 375, maxSkill = 375,
        recipes = { ["Transmute: Primal Water to Air"] = { spellID = 28569 } } })
    DS:SetProfessionData("Smelting", { skillLevel = 375, maxSkill = 375,
        recipes = { ["Smelt Fel Iron"] = { spellID = 29356 } } })
    local need = {}
    for _, row in ipairs(MC:GetShoppingList("Stormforged Hauberk", "Blacksmithing", 1)) do
        need[row.name] = row.need
    end
    assert(need["Primal Air"] == 2,
        "T53: Primal Air is not on the shopping list as a purchase (" .. tostring(need["Primal Air"]) .. ")")
    assert(need["Primal Water"] == 2, "T53: the transmute ring was walked instead of bought")
    need = {}
    for _, row in ipairs(MC:GetShoppingList("Fel Iron Chain Tunic", "Blacksmithing", 1)) do
        need[row.name] = row.need
    end
    assert(need["Fel Iron Ore"] == 18, "T53: a known smelt did not expand (9 bars at 2 ore each)")
    assert(need["Fel Iron Bar"] == nil, "T53: the expanded intermediate stayed on the shopping list")
end
passed("T53 MaterialCalc -- Primal Air is bought even though we know a transmute, the smelt expands")

-- ── T54: yield rounding and the yield clamp ──────────────────────
do
    RDB:RegisterProfession("Smelting", {
        ["PB Smelt Test Bar"] = { spellID = 999002, itemID = 999002, yield = 2,
            reagents = { { itemID = 999003, count = 1, name = "PB Test Ore" } } },
        ["PB Bad Yield"] = { spellID = 999006, itemID = 999006, yield = 0,
            reagents = { { itemID = 999003, count = 1, name = "PB Test Ore" } } },
    })
    RDB:RegisterProfession("Blacksmithing", {
        ["PB Test Widget"] = { spellID = 999004, itemID = 999004,
            reagents = { { itemID = 999002, count = 3, name = "PB Test Bar" } } },
        ["PB Bad Yield User"] = { spellID = 999007, itemID = 999007,
            reagents = { { itemID = 999006, count = 5, name = "PB Bad Yield Item" } } },
    })
    DS:SetProfessionData("Smelting", { skillLevel = 375, maxSkill = 375, recipes = {
        ["Smelt Fel Iron"]     = { spellID = 29356 },
        ["PB Smelt Test Bar"]  = { spellID = 999002 },
        ["PB Bad Yield"]       = { spellID = 999006 },
    } })
    local ore = 0
    for _, row in ipairs(MC:GetShoppingList("PB Test Widget", "Blacksmithing", 1)) do
        if row.itemID == 999003 then ore = row.need end
    end
    assert(ore == 2, "T54: yield 2 did not round 3 bars up to 2 smelts, got " .. ore)
    for _, row in ipairs(MC:GetShoppingList("PB Bad Yield User", "Blacksmithing", 1)) do
        assert(row.need == row.need and row.need < math.huge, "T54: yield 0 produced an infinite need")
    end
end
passed("T54 yield -- ceil against the real yield, and yield 0 clamps to 1 instead of dividing by it")

----------------------------------------------------------------------
-- Post-review hardening (T55-T66): remote-record prune, order ingress
-- binding and caps, token and timestamp validation, reflex-reply floor,
-- guild serve budget, board send spacing, sync-payload caps and the
-- skill-line rescan trigger.
----------------------------------------------------------------------

-- ── T55: a HELLO-only remote record is stamped, not deleted ──────
do
    -- 1.0.3's StoreLightweight wrote every guildmate as lastSync = 0 with no
    -- lastSeen, and tonumber(0) is truthy, so the first 1.1.0 login deleted the
    -- lot: the Guild tab's professions column went blank across the guild.
    local fresh, stale = "Lastseen-TestRealm", "Ancient-TestRealm"
    addon.db.characters[fresh] = { isRemote = true, lastSync = 0, professions = {} }
    addon.db.characters[stale] = { isRemote = true, lastSync = time() - 60 * 86400,
                                   professions = {} }
    local removed = DS:PruneRemoteCharacters(30)
    assert(addon.db.characters[fresh], "T55: a lastSync = 0 record was deleted as ancient")
    assert(addon.db.characters[fresh].lastSeen, "T55: the stampless record was not stamped")
    assert(addon.db.characters[stale] == nil, "T55: a genuinely 60-day-old record survived")
    assert(removed == 1, "T55: prune removed " .. removed .. " records, want 1")
    addon.db.characters[fresh] = nil
end
passed("T55 remote prune -- lastSync = 0 reads as NO stamp (stamped now), a 60-day record is dropped")

-- ── T56: order strings lose control chars, cut before escaping ───
do
    clearSent()
    recv("Buddy", { _type = "ORDER_NEW", token = "Buddy-TestRealm-56:new", order = {
        id = "Buddy-TestRealm-56", requester = "Buddy-TestRealm", crafter = ME,
        item = { id = 555, name = "Flask\n[System] your account is flagged",
                 profession = "Tail\ring" },
        quantity = 1, status = "pending", createdAt = time(), updatedAt = time() } })
    local s56 = addon.db.orders["Buddy-TestRealm-56"]
    assert(s56, "T56: the order was not stored")
    assert(not s56.item.name:find("%c"),
        "T56: a control character survived into the name the panel prints to chat")
    assert(not s56.item.profession:find("%c"), "T56: a control character survived in profession")
    -- Truncate BEFORE escaping, so the cut can never land inside a "||".
    recv("Buddy", { _type = "ORDER_NEW", token = "Buddy-TestRealm-57:new", order = {
        id = "Buddy-TestRealm-57", requester = "Buddy-TestRealm", crafter = ME,
        item = { id = 555, name = string.rep("A", 79) .. "|Hitem:1|h[x]|h",
                 profession = "Tailoring" },
        quantity = 1, status = "pending", createdAt = time(), updatedAt = time() } })
    local trailing = addon.db.orders["Buddy-TestRealm-57"].item.name:match("(|*)$")
    assert(#trailing % 2 == 0,
        "T56: truncation left " .. #trailing .. " trailing pipes (a dangling escape eats the line)")
end
passed("T56 Orders.sanitize -- control chars stripped, truncate then escape (no dangling pipe)")

-- ── T57: a directed order id is bound to its owner ───────────────
do
    clearSent()
    Comm._reflexAt = nil          -- the 5 s reflex floor; the whole run is one second
    addon.db.contacts["Eve-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    -- Eve names herself as the requester (so the old anti-spoof passes) but uses
    -- an id belonging to Buddy. Stored, it would swallow Buddy's real order as a
    -- duplicate forever, acked back to him as delivered.
    recv("Eve", { _type = "ORDER_NEW", token = "Buddy-TestRealm-77:new", order = {
        id = "Buddy-TestRealm-77", requester = "Eve-TestRealm", crafter = ME,
        item = ITEM, quantity = 1, status = "pending",
        createdAt = time(), updatedAt = time() } })
    assert(addon.db.orders["Buddy-TestRealm-77"] == nil, "T57: a squatted order id was stored")
    assert(#sentOfType("ORDER_ACK") == 1, "T57: the refusal was not acked")
    assert(firstOfType("ORDER_ACK").payload.rejected == true, "T57: the refusal acked as accepted")
    -- The owner's own order for that id still lands.
    clearSent()
    recv("Buddy", { _type = "ORDER_NEW", token = "Buddy-TestRealm-77:new", order = {
        id = "Buddy-TestRealm-77", requester = "Buddy-TestRealm", crafter = ME,
        item = ITEM, quantity = 1, status = "pending",
        createdAt = time(), updatedAt = time() } })
    assert(addon.db.orders["Buddy-TestRealm-77"], "T57: the owner's own order was refused")
    -- An id with no "<owner>-<seq>" half at all is refused outright.
    recv("Eve", { _type = "ORDER_NEW", token = "nostructure:new", order = {
        id = "nostructure", requester = "Eve-TestRealm", crafter = ME,
        item = ITEM, quantity = 1, status = "pending" } })
    assert(addon.db.orders["nostructure"] == nil, "T57: an id with no owner half was stored")
end
passed("T57 directed order binding -- an id not derived from the requester is refused (squat)")

-- ── T58: ingress caps on remote-created orders ───────────────────
do
    Comm._reflexAt = nil
    addon.db.contacts["Flooder-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    local function flood(id, status)
        addon.db.orders[id] = { id = id, requester = "Flooder-TestRealm", crafter = ME,
            item = { id = 1, name = "x" }, quantity = 1, status = status or "pending",
            createdAt = time(), updatedAt = time() }
    end
    local function newFrom(n)
        local id = "Flooder-TestRealm-" .. n
        recv("Flooder", { _type = "ORDER_NEW", token = id .. ":new", order = {
            id = id, requester = "Flooder-TestRealm", crafter = ME, item = ITEM,
            quantity = 1, status = "pending", createdAt = time(), updatedAt = time() } })
        return id
    end
    for i = 1, 25 do flood("Flooder-TestRealm-" .. i) end
    clearSent()
    assert(addon.db.orders[newFrom(26)] == nil,
        "T58: a 26th pending order from one requester was stored")
    assert(#sentOfType("ORDER_ACK") == 0,
        "T58: a capped order was acked -- the sender drops it instead of retrying")
    -- An id we already hold skips the caps entirely (that is the outbox resend).
    clearSent()
    newFrom(1)
    assert(#sentOfType("ORDER_ACK") == 1, "T58: a resend of a known id was not acked")
    -- Terminal orders do not hold a slot.
    addon.db.orders["Flooder-TestRealm-1"].status = "completed"
    assert(addon.db.orders[newFrom(27)], "T58: a terminal order counted against the live cap")
    -- 300 records in db.orders total, whatever their requester.
    local filler, n = {}, 0
    for _ in pairs(addon.db.orders) do n = n + 1 end
    for i = n + 1, 300 do
        local fid = "Bulk-TestRealm-" .. i
        addon.db.orders[fid] = { id = fid, requester = "Bulk-TestRealm", crafter = ME,
            item = { id = 1, name = "x" }, quantity = 1, status = "completed",
            createdAt = time(), updatedAt = time() }
        filler[#filler + 1] = fid
    end
    assert(addon.db.orders[newFrom(28)] == nil, "T58: the 300-record total cap did not hold")
    for _, fid in ipairs(filler) do addon.db.orders[fid] = nil end
    for i = 1, 28 do addon.db.orders["Flooder-TestRealm-" .. i] = nil end
end
passed("T58 order ingress caps -- 25 live per requester, 300 records total, known ids exempt")

-- ── T59: the ack echoes only a sane token ────────────────────────
do
    clearSent()
    Comm:SendOrderAck("Buddy-TestRealm", string.rep("t", 65))
    assert(#sentOfType("ORDER_ACK") == 0, "T59: a 65-byte token was echoed back")
    Comm:SendOrderAck("Buddy-TestRealm", { forged = true })
    assert(#sentOfType("ORDER_ACK") == 0, "T59: a table token was echoed back")
    Comm:SendOrderAck("Buddy-TestRealm", "")
    assert(#sentOfType("ORDER_ACK") == 0, "T59: an empty token was echoed back")
    Comm:SendOrderAck("Buddy-TestRealm", "sane:token")
    assert(#sentOfType("ORDER_ACK") == 1, "T59: a well-formed token was refused")
    -- Through the handler: the message is still processed, it just goes unacked.
    clearSent()
    Comm._reflexAt = nil
    recv("Eve", { _type = "ORDER_NEW", token = string.rep("z", 5000), order = {
        id = "Buddy-TestRealm-78", requester = "Eve-TestRealm", crafter = ME,
        item = ITEM, quantity = 1, status = "pending" } })
    assert(addon.db.orders["Buddy-TestRealm-78"] == nil, "T59: the squatted order was stored")
    assert(#sentOfType("ORDER_ACK") == 0, "T59: a 5000-byte token was reflected onto the ALERT pipe")
end
passed("T59 ack token -- a non-string, empty or over-64-byte token is never echoed back")

-- ── T60: NaN timestamps and item id cannot reach the record ──────
do
    local nan = 0 / 0
    assert(nan ~= nan, "T60: this VM did not produce a NaN")
    recv("Buddy", { _type = "ORDER_NEW", token = "Buddy-TestRealm-60:new", order = {
        id = "Buddy-TestRealm-60", requester = "Buddy-TestRealm", crafter = ME,
        item = { id = nan, name = "NaN thing", profession = "Tailoring" },
        quantity = 1, status = "pending", createdAt = nan, updatedAt = nan } })
    local s60 = addon.db.orders["Buddy-TestRealm-60"]
    assert(s60, "T60: the order was not stored")
    assert(s60.createdAt == s60.createdAt, "T60: a NaN createdAt was stored")
    assert(s60.updatedAt == s60.updatedAt, "T60: a NaN updatedAt was stored")
    assert(s60.item.id == nil, "T60: a NaN item id was stored as " .. tostring(s60.item.id))
    -- The point of the clamp: the record can still be reclaimed. Every compare
    -- against NaN is false, so ExpireStale used to skip it forever.
    s60.createdAt = time() - 20 * 86400
    Orders:ExpireStale()
    assert(addon.db.orders["Buddy-TestRealm-60"].status == "expired",
        "T60: the record still cannot be expired")
    -- ApplyRemoteStatus shares the same clamp.
    local o60 = Orders:Create({ crafter = "Buddy-TestRealm", item = ITEM, quantity = 1 })
    o60.updatedAt = time() - 100
    Orders:ApplyRemoteStatus(o60.id, "accepted", nil, nan, nil, "crafter")
    local a60 = addon.db.orders[o60.id]
    assert(a60.status == "accepted", "T60: the update was not applied")
    assert(a60.updatedAt == a60.updatedAt, "T60: ApplyRemoteStatus stored a NaN updatedAt")
end
passed("T60 NaN order ingress -- timestamps fall back to now, item id to nil, the record expires")

-- ── T61: guild-tier serve cooldown and the shared budget ─────────
do
    Comm:_ResetServeCooldown()
    Comm._guildServes = nil
    clearSent()
    recv("Guildie", { _type = "SYNC_REQ" })
    assert(#sentOfType("SYNC_DATA") == 1, "T61: the first guild-tier serve was refused")
    clearSent()
    recv("Guildie", { _type = "SYNC_REQ" })
    assert(#sentOfType("SYNC_DATA") == 0,
        "T61: a guild-tier peer was served twice inside the 120 s cooldown")
    -- The per-sender cooldown alone is priced in alts, so the tier shares one
    -- budget: 12 different guildmates get 10 serves, not 12.
    Comm:_ResetServeCooldown()
    Comm._guildServes = nil
    local alts = {}
    for i = 1, 12 do alts[i] = "Alt" .. i end
    joinGuild(unpack(alts))
    local served = 0
    for i = 1, 12 do
        clearSent()
        recv(alts[i], { _type = "SYNC_REQ" })
        served = served + #sentOfType("SYNC_DATA")
    end
    assert(served == 10, "T61: the guild budget served " .. served .. " peers per minute, want 10")
    joinGuild("Guildie", "Buddy", "Forgetful")      -- restore the roster below
    Comm._guildServes = nil
end
passed("T61 guild serve limits -- 120 s per sender and 10 serves a minute across all senders")

-- ── T62: lastCommRev goes through sanInt ─────────────────────────
do
    local nan = 0 / 0
    local RK = "Revpal-TestRealm"
    addon.db.contacts[RK] = { trusted = true, autoSync = false, lastSync = 0 }
    recv("Revpal", { _type = "HELLO", professions = {}, _commrev = nan })
    assert(addon.db.contacts[RK].lastCommRev == 0,
        "T62: a NaN _commrev was stored as " .. tostring(addon.db.contacts[RK].lastCommRev))
    recv("Revpal", { _type = "HELLO", professions = {}, _commrev = 10 ^ 9 })
    assert(addon.db.contacts[RK].lastCommRev == 1000, "T62: a huge _commrev was not clamped")
    recv("Revpal", { _type = "HELLO", professions = {}, _commrev = 7 })
    assert(addon.db.contacts[RK].lastCommRev == 7, "T62: an honest rev was altered")
    -- An absent _commrev must still read as an old client (nil), not as 0.
    addon.db.contacts["Oldpal-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    recv("Oldpal", { _type = "HELLO", professions = {} })
    assert(addon.db.contacts["Oldpal-TestRealm"].lastCommRev == nil,
        "T62: an absent _commrev was written as a number")
end
passed("T62 lastCommRev -- NaN defaults to 0, a huge value clamps to 1000, absent stays nil")

-- ── T63: our own board posts are spaced, and a close cancels ─────
do
    addon.db.orderBoard = {}
    Comm._lastOpenSendAt, Comm._deferredOpens = nil, nil
    clearSent(); clearDeferred()
    local p1 = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    local p2 = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    Comm:BroadcastOpenOrder(p1)
    Comm:BroadcastOpenOrder(p2)
    assert(#sentOfType("ORDER_OPEN") == 1,
        "T63: both posts went out inside the receiver's 5 s cooldown (the second is dropped guild-wide)")
    assert(#deferred == 1, "T63: the second post was not deferred")
    runDeferred()
    local opens = sentOfType("ORDER_OPEN")
    assert(#opens == 2, "T63: the deferred post never went out")
    assert(opens[1].payload.order.id == p1.id and opens[2].payload.order.id == p2.id,
        "T63: the deferred sends went out of order")
    -- A close for a post still waiting cancels that send instead of racing it.
    Comm._lastOpenSendAt = nil
    clearSent(); clearDeferred()
    local p3 = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    local p4 = Orders:CreateOpen({ item = ITEM, quantity = 1 })
    Comm:BroadcastOpenOrder(p3)
    Comm:BroadcastOpenOrder(p4)
    Comm:BroadcastOrderClosed(p4.id, "cancelled")
    runDeferred()
    for _, s in ipairs(sentOfType("ORDER_OPEN")) do
        assert(s.payload.order.id ~= p4.id,
            "T63: a cancelled post was broadcast after its close (a zombie entry on every board)")
    end
    addon.db.orderBoard = {}
end
passed("T63 board send spacing -- posts are spaced past the receiver cooldown, a close cancels one")

-- ── T64: SYNC_DATA caps, including the running recipe total ──────
do
    addon.db.contacts["Bulkpal-TestRealm"] = { trusted = true, autoSync = false, lastSync = 0 }
    local profs = {}
    for p = 1, 14 do
        local names = {}
        for r = 1, 700 do names[r] = "P" .. p .. " Recipe " .. r end
        profs["Prof" .. p] = { skillLevel = 375, maxSkill = 375, recipeNames = names }
    end
    recv("Bulkpal", { _type = "SYNC_DATA", class = "MAGE", level = 70, faction = "Alliance",
        professions = profs, inventory = { bags = {}, bank = {} } })
    local rec = DS:GetCharacter("Bulkpal-TestRealm")
    local nProfs, nRecipes = 0, 0
    for _, pr in pairs(rec.professions) do
        nProfs = nProfs + 1
        for _ in pairs(pr.recipes) do nRecipes = nRecipes + 1 end
    end
    assert(nProfs == 12, "T64: stored " .. nProfs .. " professions, cap is 12")
    assert(nRecipes == 3000,
        "T64: stored " .. nRecipes .. " recipes, the running total across professions caps at 3000")
    addon.db.characters["Bulkpal-TestRealm"] = nil
    addon.db.contacts["Bulkpal-TestRealm"] = nil
end
passed("T64 SYNC_DATA caps -- 12 professions, 600 per profession, 3000 recipes per payload")

-- ── T65: SKILL_LINES_CHANGED drives a debounced rescan ───────────
do
    -- A gathering skill-up opens no window, so ScanProfessions is the only path
    -- that records it -- and Comm's push reads what we stored, so without this
    -- registration the profession push it added was inert.
    sim.skillLines = {
        { "Professions", true },
        { "Tailoring", false, 305, 375 },
        { "Mining", false, 121, 375 },
    }
    sim.collapsedHeaders = {}
    Scanner._skillTimer, Scanner._skillEventMuteUntil = nil, nil
    fire("SKILL_LINES_CHANGED")
    local armed = Scanner._skillTimer
    assert(armed, "T65: the skill-line change armed no rescan")
    fire("SKILL_LINES_CHANGED")
    assert(Scanner._skillTimer == armed, "T65: a second event re-armed the pending rescan")
    armed.fn()
    local mining = DS:GetCharacter(ME).professions.Mining
    assert(mining and mining.skillLevel == 121, "T65: the rescan did not record the skill-up")
    -- The scan's own expand/collapse re-fires the event a frame later; the mute
    -- window it sets is what stops that from driving itself forever.
    fire("SKILL_LINES_CHANGED")
    assert(Scanner._skillTimer == nil,
        "T65: an event inside the mute window armed another scan (feedback loop)")
    clock = clock + 2                                  -- past the mute window
    fire("SKILL_LINES_CHANGED")
    assert(Scanner._skillTimer, "T65: the handler stayed muted past its window")
    Scanner._skillTimer = nil
end
passed("T65 skill lines -- one debounced rescan per burst, self-fired events muted for a second")

-- ── T66: one shared floor on the reflex refusal replies ──────────
do
    clearSent()
    Comm._reflexAt = nil
    recv("Guildie", { _type = "ORDER_CLAIM", orderId = "Nosuch-TestRealm-1" })
    assert(#sentOfType("ORDER_CLOSED") == 1, "T66: the first self-heal close was not sent")
    recv("Guildie", { _type = "ORDER_CLAIM", orderId = "Nosuch-TestRealm-2" })
    assert(#sentOfType("ORDER_CLOSED") == 1, "T66: a claim flood kept answering inside the 5 s floor")
    -- Same floor, different handler: the ack for an id we do not hold.
    recv("Guildie", { _type = "ORDER_UPDATE", id = "Nosuch-TestRealm-3", status = "accepted",
        updatedAt = time(), token = "t66a" })
    assert(#sentOfType("ORDER_ACK") == 0,
        "T66: the unknown-id ack ignored the shared floor (it is the same reflection)")
    -- Another sender is unaffected: the floor is per sender, not global.
    recv("Buddy", { _type = "ORDER_UPDATE", id = "Nosuch-TestRealm-4", status = "accepted",
        updatedAt = time(), token = "t66b" })
    assert(#sentOfType("ORDER_ACK") == 1, "T66: the floor is global instead of per sender")
    assert(Comm._reflexAt["Guildie-TestRealm"], "T66: the reflex stamp is not keyed by sender")
    Comm:ForgetPeer("Guildie-TestRealm")
    assert(Comm._reflexAt["Guildie-TestRealm"] == nil, "T66: ForgetPeer left the reflex stamp")
end
passed("T66 reflex floor -- one refusal reply per sender per 5 s across claim, update and new")

leaveGuild()
print("ALL 66 HARNESS TESTS PASS (T1-T13 trust/order/sanitize + T14 decline + T15 cooldown"
    .. " + T16 no-recipes guard + T17 guild-board model + T18 crafterless-terminal prune"
    .. " + T19-T23 INCR delta sync + T24-T29 canonical key, distribution gating and guild scope"
    .. " + T30-T36 board lifecycle + T37-T44 delta hardening, priorities and session hygiene"
    .. " + T45-T50 Scanner + T51-T54 RecipeDB and MaterialCalc"
    .. " + T55-T66 post-review hardening: remote prune, order id binding and caps,"
    .. " token and timestamp validation, guild serve budget, board send spacing,"
    .. " payload caps, skill-line rescan and the reflex-reply floor; "
    .. pass .. " of them print a PASS line above)")

