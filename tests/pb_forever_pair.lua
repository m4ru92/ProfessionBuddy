----------------------------------------------------------------------
-- One node of the WoW: Forever two-client test (tests/forever_pair.py).
-- Each node is a whole PB in its own Lua state, on the Forever stub, as
-- the player NODE_NAME on "Realm". Outgoing addon messages are caught at
-- AceComm, after Comm:Send has stamped and serialized them, into OUTBOX;
-- the driver hands each one to the other node's Comm:OnMessageReceived.
----------------------------------------------------------------------
dofile("tests/forever_env.lua")
dofile("tests/forever_tradeskill.lua")
dofile("tests/forever_trainer.lua")
local baseUnitName = UnitName
function UnitName(u)
    if u == "player" then return NODE_NAME end
    return baseUnitName(u)
end
function GetUnitName(u) return UnitName(u) end
local files, errs = LOAD_TOC("ProfessionBuddy_Mainline.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
ProfBuddyDB = nil
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
EXPECT(ProfBuddy:PlayerKey() == NODE_NAME .. "-Realm", "node key " .. tostring(ProfBuddy:PlayerKey()))
OUTBOX = {}
LibStub("AceComm-3.0").SendCommMessage = function(_, prefix, text, dist, target, prio)
    OUTBOX[#OUTBOX + 1] = { prefix = prefix, text = text, dist = dist, target = target, prio = prio }
end
function NODE_RECEIVE(prefix, text, dist, from)
    ProfBuddy.Comm:OnMessageReceived(prefix, text, dist, from)
    FLUSH()
end
function NODE_TYPE(text)
    local ok, d = LibStub("AceSerializer-3.0"):Deserialize(text)
    return ok and d._type or "?"
end
