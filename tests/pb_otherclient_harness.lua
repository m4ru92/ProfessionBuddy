----------------------------------------------------------------------
-- Other-client harness (Forever 2.0.0, Phase 0).
-- R1: retail reads the _Mainline toc too; PB must say it does not support
--     the client and start nothing.
-- R2: the plain ProfessionBuddy.toc (every client with no toc of its own)
--     loads one file that only prints the "not supported yet" line.
----------------------------------------------------------------------

BUILD_INTERFACE = 120100
dofile("tests/forever_env.lua")

local _, errs = LOAD_TOC("ProfessionBuddy_Mainline.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
ProfBuddyDB = nil
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
EXPECT(PRINTED("does not support this game client."), "no retail line")
EXPECT(not PRINTED("loaded.  /pb"), "modules started on retail")
EXPECT(ProfBuddyDB == nil or ProfBuddyDB.characters == nil, "saved variables initialised on retail")
print("  PASS R1 retail (interface 120100): says it does not support the client, starts nothing")

PRINTS = {}
local files, errs2 = LOAD_TOC("ProfessionBuddy.toc")
EXPECT(#errs2 == 0, "stub load errors: " .. table.concat(errs2, " | "))
EXPECT(#files == 1 and files[1] == "ClientNotSupported.lua", "stub toc loads " .. table.concat(files, ", "))
FIRE("PLAYER_LOGIN")
EXPECT(PRINTED("does not support this game client yet."), "no stub line")
print("  PASS R2 plain toc loads only ClientNotSupported.lua and prints the line")
print("ALL OTHER-CLIENT TESTS PASS (2)")
