----------------------------------------------------------------------
-- WoW: Forever, "Replace default profession window" OFF (Phase 2a).
-- W1: Blizzard's ProfessionsFrame opens normally, through its own panel
--     manager, untouched; PB's window opens alongside it.
-- W2: the K key opens the profession book the normal way.
----------------------------------------------------------------------

dofile("tests/forever_env.lua")
dofile("tests/forever_tradeskill.lua")

local _, errs = LOAD_TOC("ProfessionBuddy_Mainline.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
ProfBuddyDB = { settings = { replaceTradeSkill = false } }
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
EXPECT(ProfBuddy.db.settings.replaceTradeSkill == false, "setting did not stay off")

C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
EXPECT(ProfessionsFrame:IsShown(), "Blizzard's ProfessionsFrame did not open")
EXPECT(PANEL_MANAGED[#PANEL_MANAGED] == true, "ProfessionsFrame did not go through the panel manager")
EXPECT(UIPanelWindows.ProfessionsFrame ~= nil and rawget(ProfessionsFrame, "Show") == nil,
       "ProfessionsFrame was modified")
local TSF = ProfBuddy.TradeSkillFrame
EXPECT(TSF.frame and TSF.frame:IsShown() and TSF.state.profName == "Leatherworking", "PB did not open alongside")
print("  PASS W1 setting off: Blizzard's window opens through its panel manager untouched, PB opens alongside")

TSF.frame:Hide()
HideUIPanel(ProfessionsFrame)
FLUSH()
ToggleProfessionsBook()
EXPECT(ProfessionsFrame:IsShown() and PANEL_MANAGED[#PANEL_MANAGED] == true, "K did not open Blizzard's book normally")
print("  PASS W2 setting off: K opens the profession book through Blizzard's panel manager")
print("ALL FOREVER REPLACE-OFF TESTS PASS (2)")
