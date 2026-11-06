----------------------------------------------------------------------
-- WoW: Forever, "Replace default profession window" OFF (Phase 2a).
-- W1: Blizzard's ProfessionsFrame opens normally, through its own panel
--     manager, untouched; PB's window opens alongside it.
-- W2: the K key opens the profession book the normal way.
-- W7-W9 (2.0.2): "Open ProfessionBuddy beside Blizzard's window" and the
--     Reload / Later popup when Replace is unticked.
----------------------------------------------------------------------

dofile("tests/forever_env.lua")
dofile("tests/forever_tradeskill.lua")

local _, errs = LOAD_TOC("ProfessionBuddy_Forever.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
-- saved data as a pre-realm-token build left it (W3)
ProfBuddyDB = { settings = { replaceTradeSkill = false }, schemaVersion = 2,
                contacts = { ["Friend Surname-ClassicBetaPvP2"] = { trusted = true, autoSync = false, lastSync = 1 } } }
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
-- W3: saved names lose their realm when PB loads (Source.REALM_TOKEN), with
-- a backup of the old data
local ct = ProfBuddy.db.contacts
EXPECT(ct["Friend Surname-Forever"] and ct["Friend Surname-Forever"].trusted and not ct["Friend Surname-ClassicBetaPvP2"],
       "saved contact not moved at load")
EXPECT(ProfBuddyDB.realmKeyBackup and ProfBuddyDB.realmKeyBackup.contacts["Friend Surname-ClassicBetaPvP2"], "no backup at load")
print("  PASS W3 saved names lose their realm at load, with a backup")
-- W4: settings saved before 2.0.1 have no Colorblind markers choice; PB
-- gives them Auto at load and keeps the rest
EXPECT(ProfBuddyDB.settings.colorblindMarkers == "auto" and ProfBuddyDB.settings.replaceTradeSkill == false,
       "old settings: colorblindMarkers " .. tostring(ProfBuddyDB.settings.colorblindMarkers))
print("  PASS W4 settings saved before 2.0.1 get Colorblind markers Auto at load")
-- W5: settings saved before the window style existed get Modern at load
EXPECT(ProfBuddyDB.settings.windowStyle == "modern", "old settings: windowStyle " .. tostring(ProfBuddyDB.settings.windowStyle))
print("  PASS W5 settings saved before the window style get Modern at load")
-- W6: settings saved before the Held by slider existed get 8 at load
EXPECT(ProfBuddyDB.settings.tooltipMaxHeldBy == 8, "old settings: tooltipMaxHeldBy " .. tostring(ProfBuddyDB.settings.tooltipMaxHeldBy))
print("  PASS W6 settings saved before the Held by slider get 8 at load")
-- W7: a player who had Replace off before 2.0.2 keeps both windows: the new
-- setting starts on for them (W1 ran with it)
EXPECT(ProfBuddyDB.settings.openBesideBlizzard == true, "Replace-off player lost both windows: "
       .. tostring(ProfBuddyDB.settings.openBesideBlizzard))
EXPECT(ProfBuddyDB.settings.tooltipShowDisenchant == true, "old settings: Show disenchant results "
       .. tostring(ProfBuddyDB.settings.tooltipShowDisenchant))
print("  PASS W7 a player with Replace off before 2.0.2 gets Open beside Blizzard's window on; Show disenchant results on")

-- W8: with it off, Blizzard's window opens alone and PB still records the
-- recipes; with PB's window already open, PB follows the profession
local S = ProfBuddy.db.settings
S.openBesideBlizzard = false
TSF.frame:Hide()
HideUIPanel(ProfessionsFrame)
C_TradeSkillUI.CloseTradeSkill()
FLUSH()
-- (Blizzard's frame, shown again, re-opens its right-hand tabs, so the
-- profession open at the end is whichever the client reports)
for _, p in pairs(ProfBuddy.DataStore:GetCharacter().professions) do p.recipes = {} end
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
local openName = C_TradeSkillUI.GetBaseProfessionInfo().professionName
EXPECT(ProfessionsFrame:IsShown(), "Blizzard's window did not open")
EXPECT(not TSF.frame:IsShown(), "PB opened beside Blizzard's window with the setting off")
EXPECT(openName and next(ProfBuddy.DataStore:GetProfession(nil, openName).recipes),
       "recipes not recorded while PB stayed closed (" .. tostring(openName) .. ")")
C_TradeSkillUI.CloseTradeSkill()
FLUSH()
TSF.frame:Show()
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
openName = C_TradeSkillUI.GetBaseProfessionInfo().professionName
EXPECT(TSF.frame:IsShown() and TSF.state.profName == openName, "an open PB window did not follow the profession: "
       .. tostring(TSF.state.profName) .. " vs " .. tostring(openName))
print("  PASS W8 setting off: Blizzard's window opens alone, recipes still recorded; an open PB window follows")

-- W9: Settings. Unticking Replace asks Reload / Later instead of reloading;
-- the sub-setting is greyed while Replace is on and saves when ticked
StaticPopupDialogs = {}
local shown, reloaded
StaticPopup_Show = function(name) shown = name end
ReloadUI = function() reloaded = true end
TSF:OpenSettings("main")
local repl, beside = TSF.replaceCB, TSF.besideCB
EXPECT(repl and beside, "the two checkboxes were not built")
local function click(cb, checked) cb:GetScript("OnClick")(setmetatable({ GetChecked = function() return checked end }, { __index = cb })) end
click(repl, true)
EXPECT(S.replaceTradeSkill == true and not beside:IsEnabled(), "sub-setting not greyed with Replace on")
click(repl, false)
EXPECT(S.replaceTradeSkill == false and beside:IsEnabled(), "sub-setting still greyed with Replace off")
EXPECT(shown == "PROFBUDDY_RELOAD_REPLACE" and not reloaded, "unticking Replace: popup " .. tostring(shown)
       .. ", reloaded " .. tostring(reloaded))
local d = StaticPopupDialogs.PROFBUDDY_RELOAD_REPLACE
EXPECT(d and d.button1 == "Reload" and d.button2 == "Later" and d.text:find("comes back after a reload", 1, true),
       "popup text or buttons")
d.OnAccept()
EXPECT(reloaded, "Reload did not reload")
click(beside, true)
EXPECT(S.openBesideBlizzard == true, "ticking the sub-setting did not save")
local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
local replBlock = src:match('local replCB = MakeCheckbox.-yLeft = yLeft %- 30')
EXPECT(replBlock and not replBlock:find("ReloadUI", 1, true), "the Replace checkbox still reloads directly")
print("  PASS W9 unticking Replace offers Reload / Later; the sub-setting greys with Replace on and saves")
print("ALL FOREVER REPLACE-OFF TESTS PASS (9)")
