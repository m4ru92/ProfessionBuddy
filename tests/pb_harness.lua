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

-- ── T11: auto-push -- full for an old client, suppressed when unchanged ──
-- Buddy has no COMM_REV on record (an old client), so every push is a full
-- SYNC_DATA, never a delta. Reset the delta baseline so the first push here is
-- a clean baseline (T5's serve seeded one earlier).
clearSent()
Comm._pushState = nil
addon.db.contacts["Buddy-Test Realm"].autoSync = true
addon.db.contacts["Buddy-Test Realm"].lastCommRev = nil
Comm:SendIncrementalUpdate()
assert(#sentOfType("SYNC_DATA") == 1 and #sentOfType("INCR") == 0, "T11: first push (full baseline) missing")
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
addon.db.contacts["Deltapal-Test Realm"] = { trusted = true, autoSync = true, lastSync = 0, lastCommRev = 7 }
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
addon.db.contacts["Deltamate-Test Realm"] = { trusted = true, lastSync = 0 }
recv("Deltamate", { _type = "SYNC_DATA", epoch = 4, professions = {},
    inventory = { bags = { [100] = 10, [200] = 5 }, bank = {} } })      -- baseline
recv("Deltamate", { _type = "INCR", epoch = 4, seq = 1,
    changes = { bags = { [100] = 12, [300] = 7, [200] = 0 } } })        -- change / add / remove
local dm = DS:GetCharacter("Deltamate-Test Realm").inventory.bags
assert(dm[100] == 12 and dm[300] == 7 and dm[200] == nil, "T21: INCR add/change/remove not applied correctly")

-- ── T22: a sequence gap or wrong epoch drops the delta and resyncs ───
clearSent()
recv("Deltamate", { _type = "INCR", epoch = 4, seq = 3,               -- gap: expected seq 2
    changes = { bags = { [100] = 999 } } })
assert(DS:GetCharacter("Deltamate-Test Realm").inventory.bags[100] == 12, "T22: gapped delta was wrongly applied")
assert(#sentOfType("SYNC_REQ") == 1, "T22: gap did not trigger an auto-resync SYNC_REQ")
clearSent()
recv("Deltamate", { _type = "INCR", epoch = 9, seq = 2, changes = { bags = { [100] = 1 } } })  -- wrong epoch
assert(DS:GetCharacter("Deltamate-Test Realm").inventory.bags[100] == 12, "T22: wrong-epoch delta was wrongly applied")
assert(#sentOfType("SYNC_REQ") == 1, "T22: wrong epoch did not trigger a resync")

-- ── T23: malformed INCR is rejected / sanitized ──────────────────────
recv("Deltamate", { _type = "SYNC_DATA", epoch = 5, professions = {},
    inventory = { bags = { [100] = 1 }, bank = {} } })                  -- rebaseline epoch5 seq0
recv("Deltamate", { _type = "INCR", epoch = 5, seq = 1, changes = "garbage" })   -- non-table changes
assert(DS:GetCharacter("Deltamate-Test Realm").inventory.bags[100] == 1, "T23: garbage changes altered inventory")
recv("Deltamate", { _type = "SYNC_DATA", epoch = 6, professions = {},
    inventory = { bags = { [100] = 1 }, bank = {} } })                  -- rebaseline epoch6 seq0
recv("Deltamate", { _type = "INCR", epoch = 6, seq = 1,
    changes = { bags = { ["notanid"] = 5, [100] = -3, [400] = 1e9 } } })  -- junk id, neg, oversize
local dj = DS:GetCharacter("Deltamate-Test Realm").inventory.bags
assert(dj["notanid"] == nil, "T23: non-numeric id accepted")
assert(dj[100] == 1, "T23: negative count applied (should be dropped)")
assert(dj[400] == 10^6, "T23: oversized count not clamped")

print("ALL 23 HARNESS TESTS PASS (T1-T13 trust/order/sanitize + T14 decline + T15 cooldown + T16 no-recipes guard + T17 guild-board model + T18 crafterless-terminal prune + T19-T23 INCR delta sync: send/suppress, prof-forces-full, apply add/change/remove, gap+epoch resync, malformed rejection)")

