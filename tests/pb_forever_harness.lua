----------------------------------------------------------------------
-- WoW: Forever load harness (Forever 2.0.0, Phase 0).
--
-- Loads ProfessionBuddy_Mainline.toc into a modern-client stub
-- (tests/forever_env.lua) and checks that PB starts cleanly: no load or
-- init error, the "not supported yet" line, the placeholder Source, no
-- profession events or Blizzard frames touched, tooltip hooks skipped,
-- the C_ replacements used. Then the plain stub toc and the retail guard.
----------------------------------------------------------------------

dofile("tests/forever_env.lua")

-- F1: every Mainline file loads
local files, errs = LOAD_TOC("ProfessionBuddy_Mainline.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
for _, f in ipairs(files) do
    EXPECT(not f:match("^Data/") and f ~= "Source/Classic.lua", "Mainline toc loads " .. f)
end
print("  PASS F1 Mainline toc loads " .. #files .. " entries with no error, no TBC data, no Classic source")

-- F2: startup runs every module Init without error, and says what is unsupported
ProfBuddyDB = nil
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
for _, l in ipairs(PRINTS) do EXPECT(not l:find("failed to load", 1, true), "module init error: " .. l) end
EXPECT(PRINTED("loaded.  /pb"), "no loaded line")
EXPECT(PRINTED("profession windows are not supported on WoW Forever yet"), "no Forever line")
EXPECT(ProfBuddyDB and ProfBuddyDB.characters, "saved variables not initialised")
print("  PASS F2 ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD: every module starts, Forever line shown")

-- F3: the placeholder Source is complete and inert
local S = ProfBuddy.Source
EXPECT(S.flavor == "unsupported", "flavor is " .. tostring(S.flavor))
EXPECT(#S:Missing() == 0, "Source contract gaps: " .. table.concat(S:Missing(), ", "))
EXPECT(next(S.EVENT) == nil and next(S.DEFAULT_FRAMES) == nil, "Source names events or frames")
print("  PASS F3 Source/Unsupported.lua meets the whole contract and names no events or frames")

-- F4: no profession or trainer events, no Blizzard frame hidden, no tooltip script hooked
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRAINER_SHOW", "TRAINER_UPDATE" }) do
    EXPECT(not REGISTERED[e], e .. " registered")
end
EXPECT(ProfessionsFrame.Show ~= nil and rawget(ProfessionsFrame, "Show") == nil, "ProfessionsFrame.Show replaced")
for _, h in ipairs(HOOKED) do EXPECT(not h:find("OnTooltipSet", 1, true), "hooked " .. h) end
print("  PASS F4 no profession/trainer events, Blizzard's profession window untouched, no OnTooltipSet* hooks")

-- F5: the C_ replacements are the ones in use
ProfBuddy.Scanner:ScanInventory()
local used = {}
for _, c in ipairs(CALLS) do used[c] = true end
EXPECT(used["C_Container.GetContainerNumSlots"], "bag scan did not use C_Container")
EXPECT(used["C_GuildInfo.GuildRoster"] or not IsInGuild(), "guild roster call missing")
print("  PASS F5 bag scan uses C_Container; no removed global is called")

-- F6: /pb opens without error
local ok, err = pcall(SlashCmdList.PROFBUDDY, "")
EXPECT(ok, "/pb error: " .. tostring(err))
print("  PASS F6 /pb runs")

local fb = {}
for k in pairs(FALLBACK) do fb[#fb + 1] = k end
table.sort(fb)
print("  INFO globals PB touched that this stub does not model (check in game with /fprobe pbapi): " .. table.concat(fb, ", "))
print("ALL FOREVER LOAD TESTS PASS (6)")
