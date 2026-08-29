----------------------------------------------------------------------
-- Headless test harness for ProfessionBuddy comm/order logic.
-- Stubs the WoW API, loads Core/DataStore/Orders/Comm, and drives the
-- real message handlers end to end. error() on any failed assertion.
----------------------------------------------------------------------

local BASE = assert(PB_BASE, "PB_BASE not set")

-- ── WoW API stubs ────────────────────────────────────────────────
local state = {
    inGroup = false, inRaid = false,
    partyMembers = {},        -- { "Name" or "Name-Realm", ... }
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
-- Guild-roster API (COMM_REV 5 guild arm). This harness runs guildless, so the
-- guild trust arm returns false and the single-instance tests are unaffected.
function IsInGuild() return false end
function GetNumGuildMembers() return 0 end
function GetGuildRosterInfo() return nil end

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
        table.insert(sent, { msgType = text._type, payload = text,
                             channel = channel, target = target })
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

-- ── load the addon files ─────────────────────────────────────────
dofile(BASE .. "/Core.lua")
dofile(BASE .. "/DataStore.lua")
dofile(BASE .. "/Orders.lua")
dofile(BASE .. "/Comm.lua")
dofile(BASE .. "/RecipeDB.lua")

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
local function sentOfType(t)
    local out = {}
    for _, s in ipairs(sent) do if s.msgType == t then table.insert(out, s) end end
    return out
end
local function clearSent() sent = {}; for i = #timers, 1, -1 do timers[i] = nil end end

local ME = addon:PlayerKey()
assert(ME == "Me-Test Realm", "unexpected PlayerKey: " .. ME)

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
local c = addon.db.contacts["Buddy-Test Realm"]
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
local rec = addon.db.characters["Buddy-Test Realm"]
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
assert(owners["Buddy-Test Realm"] == 42, "T6: WhoHasItem broken on remote data")

-- ── T7: full order lifecycle with acks (the regression) ──────────
clearSent()
local order = Orders:Create({ crafter = "Buddy-Test Realm",
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
local o2 = Orders:Create({ crafter = "Buddy-Test Realm",
    item = { id = 1, name = "X", profession = "Tailoring" } })
Comm:SendOrderNew(o2)
timers[#timers].fn()
local tok2 = o2.id .. ":new"
assert(addon.db.orderOutbox[tok2], "T8: not parked")
addon.db.contacts["Mallory-Test Realm"] = { trusted = true, autoSync = false, lastSync = 0 }
recv("Mallory", { _type = "ORDER_ACK", token = tok2 })
assert(addon.db.orderOutbox[tok2], "T8: wrong player cleared the token")
recv("Buddy", { _type = "ORDER_ACK", token = tok2 })
assert(addon.db.orderOutbox[tok2] == nil, "T8: right player could not clear")

-- ── T9: inbound ORDER_NEW sanitized + acked; spoof refused ───────
clearSent()
recv("Buddy", { _type = "ORDER_NEW", token = "Buddy-Test Realm-1:new", order = {
    id = "Buddy-Test Realm-1", requester = "Buddy-Test Realm", crafter = ME,
    item = { id = 555, name = "Thing|Hlink", profession = "Tailoring" },
    quantity = 5000, status = "pending", createdAt = 9e18, updatedAt = 9e18,
} })
local stored = addon.db.orders["Buddy-Test Realm-1"]
assert(stored, "T9: inbound order not stored")
assert(stored.item.name == "Thing||Hlink", "T9: item name not escaped")
assert(stored.quantity == 999, "T9: quantity not clamped")
assert(stored.updatedAt <= time() + 300, "T9: timestamp not clamped")
assert(#sentOfType("ORDER_ACK") == 1, "T9: no ack sent")
clearSent()
recv("Mallory", { _type = "ORDER_NEW", token = "spoof:new", order = {
    id = "spoof", requester = "Buddy-Test Realm", crafter = ME,
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

-- ── T11: auto-push signature suppresses duplicate pushes ─────────
clearSent()
addon.db.contacts["Buddy-Test Realm"].autoSync = true
Comm:SendIncrementalUpdate()
assert(#sentOfType("SYNC_DATA") == 1, "T11: first push missing")
clearSent()
Comm:SendIncrementalUpdate()               -- nothing changed
assert(#sentOfType("SYNC_DATA") == 0, "T11: duplicate push not suppressed")
DS:SetInventory("bags", { [14047] = 25 })  -- real change
Comm:SendIncrementalUpdate()
assert(#sentOfType("SYNC_DATA") == 1, "T11: changed push suppressed")

-- ── T12: sharing kill switch ─────────────────────────────────────
clearSent()
addon.db.settings.shareData = false
recv("Buddy", { _type = "SYNC_REQ" })
assert(#sentOfType("SYNC_DATA") == 0, "T12: shareData=false still served")
addon.db.settings.shareData = true

-- ── T13: auto-add group/raid mates gated by settings (default off) ─
clearSent()
state.inGroup = true; state.inRaid = false; state.partyMembers = { "Newbie" }
addon.db.settings.autoAddParty = false
recv("Newbie", { _type = "HELLO", professions = {} })
assert(addon.db.contacts["Newbie-Test Realm"] == nil, "T13: auto-added with setting OFF")
addon.db.settings.autoAddParty = true
recv("Newbie", { _type = "HELLO", professions = {} })
local nc = addon.db.contacts["Newbie-Test Realm"]
assert(nc and nc.trusted == false, "T13: opt-in add missing or wrongly trusted")
state.inGroup = false; state.partyMembers = {}
addon.db.settings.autoAddParty = false


-- ── T14: ORDER_UPDATE declineReason -- stored on decline, sanitized ──
addon.db.contacts["Buddy-Test Realm"] = addon.db.contacts["Buddy-Test Realm"] or { autoSync=false, lastSync=0 }
addon.db.contacts["Buddy-Test Realm"].trusted = true
clearSent()
local odA = Orders:Create({ crafter = "Buddy-Test Realm",
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" }, quantity = 1 })
recv("Buddy", { _type = "ORDER_UPDATE", id = odA.id, status = "declined",
    declineReason = "no |cffffd200mats|r", updatedAt = time() + 1, token = "t14a" })
local dA = addon.db.orders[odA.id]
assert(dA.status == "declined", "T14a: decline not applied")
assert(dA.declineReason and dA.declineReason:find("||", 1, true), "T14a: reason pipe not escaped")
local odB = Orders:Create({ crafter = "Buddy-Test Realm",
    item = { id = 14048, name = "Bolt of Runecloth", profession = "Tailoring" }, quantity = 1 })
recv("Buddy", { _type = "ORDER_UPDATE", id = odB.id, status = "declined",
    declineReason = string.rep("z", 400), updatedAt = time() + 1, token = "t14b" })
assert(#addon.db.orders[odB.id].declineReason <= 150, "T14b: reason not length-capped")
local odC = Orders:Create({ crafter = "Buddy-Test Realm",
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
local ap = addon.db.characters["Buddy-Test Realm"].professions["Alchemy"]
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
addon.db.characters["NoRec-Test Realm"] = { isRemote = true,
    professions = { Tailoring = { skillLevel = 375, maxSkill = 375 } } }
local ok, res = pcall(function() return RDB:GetUnknownRecipes("NoRec-Test Realm", "Tailoring") end)
assert(ok, "T16a: GetUnknownRecipes threw on nil recipes: " .. tostring(res))
assert(res["Linen Bag"] and res["Silk Bag"], "T16a: unknowns not all returned")
-- (b) sanity: a known recipe is still excluded (fix did not break the normal path)
addon.db.characters["HasRec-Test Realm"] = { isRemote = true,
    professions = { Tailoring = { skillLevel = 375, maxSkill = 375,
        recipes = { ["Linen Bag"] = { spellID = 111 } } } } }
local res2 = RDB:GetUnknownRecipes("HasRec-Test Realm", "Tailoring")
assert(res2["Linen Bag"] == nil, "T16b: known recipe wrongly listed as unknown")
assert(res2["Silk Bag"], "T16b: unknown recipe missing")

print("ALL 16 HARNESS TESTS PASS (T1-T13 trust/order/sanitize + T14 decline + T15 cooldown + T16 no-recipes guard)")

