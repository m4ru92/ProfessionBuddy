----------------------------------------------------------------------
-- TBC Classic Anniversary window harness.
--
-- Loads the _TBC toc in tbc_env.lua and builds every window PB has, the
-- way a player opens them: the main window and its four tabs, a trade
-- skill (Leatherworking) and a craft (Enchanting) profession window with a
-- recipe selected, Settings, the Material Calculator, and the profession
-- window's own tabs. The look is TBC_LOOK ("modern" unless a wrapper sets
-- "classic"); the windows are built once per session, as in game.
-- A Lua error anywhere stops the run with its message.
----------------------------------------------------------------------

dofile("tests/tbc_env.lua")
local LOOK = rawget(_G, "TBC_LOOK") or "modern"
local TAG = LOOK == "classic" and "C" or "U"

local files, errs = LOAD_TOC("ProfessionBuddy_TBC.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
local hasClassic = false
for _, f in ipairs(files) do
    EXPECT(not f:match("^Data/Forever/") and f ~= "Source/Forever.lua" and f ~= "Knowledge.lua",
           "the TBC toc loads " .. f)
    if f == "Source/Classic.lua" then hasClassic = true end
end
EXPECT(hasClassic, "the TBC toc does not load Source/Classic.lua")

ProfBuddyDB = { settings = { windowStyle = LOOK } }
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
for _, l in ipairs(PRINTS) do EXPECT(not l:find("failed to load", 1, true), "module init error: " .. l) end
EXPECT(PRINTED("loaded. Type /pb or /profbuddy."), "no loaded line")
local PB = ProfBuddy
EXPECT(PB.Source.flavor == "classic", "flavor is " .. tostring(PB.Source.flavor))
EXPECT(PB.Theme:Name() == LOOK, "look is " .. tostring(PB.Theme:Name()))
EXPECT(PB.db.settings.openBesideBlizzard == false, "a player with Replace on got Open beside Blizzard's window")
local DS = PB.DataStore
EXPECT(DS:GetProfession(nil, "Leatherworking") and DS:GetProfession(nil, "Enchanting"),
       "professions not recorded from the skill lines")
print("  PASS " .. TAG .. "1 TBC toc loads Classic source and no Forever data; every module starts; look " .. LOOK)

-- U2: the main window and its four tabs
local ok, err = pcall(SlashCmdList.PROFBUDDY, "")
EXPECT(ok, "/pb: " .. tostring(err))
local UI = PB.UI
EXPECT(UI.frame and UI.frame:IsShown() and #UI.frame.tabs == 4, "main window not shown with 4 tabs")
for i = 1, #UI.frame.tabs do
    ok, err = pcall(UI.SelectTab, UI, i)
    EXPECT(ok, "main tab " .. i .. ": " .. tostring(err))
end
local told
ChatFrameUtil.SendTell = function(name) told = name end
ok, err = pcall(function()
    local GP = PB.GuildPanel
    local row = GP:CreateRow(UIParent)
    row._member = { name = "Guildie-Realm", charKey = "Guildie-Realm" }
    row:GetScript("OnMouseUp")(row, "RightButton")
    GP._memberMenu.buttons[1]:GetScript("OnClick")(GP._memberMenu.buttons[1])
end)
EXPECT(ok and told == "Guildie-Realm", "guild right-click whisper: " .. tostring(err or told))
ok, err = pcall(UI.Hide, UI)
EXPECT(ok, "main window hide: " .. tostring(err))
print("  PASS " .. TAG .. "2 /pb opens; Characters, Friends, Guild and Orders tabs all build and select; guild right-click whispers")

-- U3: a trade skill profession window, a recipe selected
local TSF = PB.TradeSkillFrame
ok, err = pcall(OPEN_TRADE)
EXPECT(ok, "trade skill open: " .. tostring(err))
EXPECT(TSF.frame and TSF.frame:IsShown(), "PB's profession window did not open")
EXPECT(TSF.state.profName == "Leatherworking", "profession is " .. tostring(TSF.state.profName))
EXPECT(TSF.state.allRecipes and TSF.state.allRecipes["Light Leather"], "Light Leather not listed")
ok, err = pcall(function()
    TSF.state.selected = "Light Leather"
    TSF:RefreshDetailPanel()
    TSF:UpdateCraftBar()
    TSF:UpdateListRows()
end)
EXPECT(ok, "selecting a recipe: " .. tostring(err))
EXPECT(TSF.navTabs and #TSF.navTabs == 4, "the profession window's own tabs were not built")
-- no profession link on TBC Anniversary (a Wrath feature): no button, and
-- the skill bar keeps its full width
EXPECT(rawget(TSF, "linkButton") == nil, "a profession link button on TBC Anniversary")
local bw = rawget(TSF.skillBar, "_size")[1]
local fullW = LOOK == "classic" and (740 - 24 - 13 * 22 / 15) or (740 - 24)
EXPECT(math.abs(bw - fullW) < 0.01, "skill bar width " .. tostring(bw) .. ", expected " .. fullW)
-- shift-click a recipe row: Share's link, or Share's loading line
local insertedLink
local keepInsert, keepMod, keepRCL = ChatEdit_InsertLink, IsModifiedClick, TSF.RecipeChatLink
IsModifiedClick = function(k) return k == "CHATLINK" end
TSF.RecipeChatLink = function() return nil end
local firstReal
for idx, e in ipairs(TSF.state.recipes or {}) do if not e.isHeader then firstReal = idx; break end end
EXPECT(firstReal and TSF.listRows and TSF.listRows[1], "no recipe row to click")
TSF.state.scrollOffset = firstReal - 1
PRINTS = {}
TSF.listRows[1]:GetScript("OnClick")(TSF.listRows[1])
EXPECT(PRINTED("still loading; try again in a moment."), "no loading line on a TBC shift-click")
TSF.RecipeChatLink = keepRCL
IsModifiedClick, TSF.state.scrollOffset = keepMod, 0
print("  PASS " .. TAG .. "3 Leatherworking opens in PB's window; Light Leather selects; no link button, full skill bar; shift-click loading line")

-- U4: Settings and the Material Calculator
ok, err = pcall(TSF.OpenSettings, TSF, "main")
EXPECT(ok, "Settings: " .. tostring(err))
EXPECT(TSF.settingsPanel and TSF.settingsPanel:IsShown(), "Settings did not open")
ok, err = pcall(TSF.ToggleSettings, TSF)
EXPECT(ok, "Settings close: " .. tostring(err))
ok, err = pcall(TSF.ToggleCalcPanel, TSF)
EXPECT(ok, "Material Calculator: " .. tostring(err))
ok, err = pcall(TSF.ToggleCalcPanel, TSF)
EXPECT(ok, "Material Calculator close: " .. tostring(err))
EXPECT(PB.UI.scaleGrip and TSF.scaleGrip, "a window has no scale grip on TBC Anniversary")
ok, err = pcall(function() TSF.scaleGrip:GetScript("OnClick")(TSF.scaleGrip, "RightButton") end)
EXPECT(ok and PB.db.settings.professionWindowScale == 1, "scale reset on TBC: " .. tostring(err))
print("  PASS " .. TAG .. "4 Settings and the Material Calculator open and close; both windows have a scale grip")

-- U5: the craft window (Enchanting) after the trade skill closes
ok, err = pcall(CLOSE_TRADE)
EXPECT(ok, "trade skill close: " .. tostring(err))
ok, err = pcall(OPEN_CRAFT)
EXPECT(ok, "craft open: " .. tostring(err))
EXPECT(TSF.frame:IsShown() and TSF.state.profName == "Enchanting", "Enchanting did not open: "
       .. tostring(TSF.state.profName))
ok, err = pcall(function()
    TSF.state.selected = "Enchant Bracer - Minor Health"
    TSF:RefreshDetailPanel()
    TSF:UpdateCraftBar()
end)
EXPECT(ok, "selecting an enchant: " .. tostring(err))
ok, err = pcall(CLOSE_CRAFT)
EXPECT(ok, "craft close: " .. tostring(err))
print("  PASS " .. TAG .. "5 Enchanting opens through the craft window; an enchant selects; it closes cleanly")

-- U6: Replace off and "Open beside Blizzard's window" off: neither window
-- opens PB's, and both still record the recipes
local S = PB.db.settings
S.replaceTradeSkill, S.openBesideBlizzard = false, false
TSF.frame:Hide()
local char = DS:GetCharacter()
char.professions.Leatherworking.recipes, char.professions.Enchanting.recipes = {}, {}
ok, err = pcall(OPEN_TRADE)
EXPECT(ok, "trade skill open, setting off: " .. tostring(err))
EXPECT(not TSF.frame:IsShown(), "PB opened on the trade skill with both settings off")
EXPECT(next(char.professions.Leatherworking.recipes), "Leatherworking not recorded with PB closed")
pcall(CLOSE_TRADE)
ok, err = pcall(OPEN_CRAFT)
EXPECT(ok, "craft open, setting off: " .. tostring(err))
EXPECT(not TSF.frame:IsShown(), "PB opened on the craft window with both settings off")
EXPECT(next(char.professions.Enchanting.recipes), "Enchanting not recorded with PB closed")
pcall(CLOSE_CRAFT)
S.openBesideBlizzard = true
pcall(OPEN_TRADE)
EXPECT(TSF.frame:IsShown(), "PB did not open beside Blizzard's window with the setting on")
pcall(CLOSE_TRADE)
S.replaceTradeSkill, S.openBesideBlizzard = true, false
print("  PASS " .. TAG .. "6 Replace off: PB stays closed and still records both windows; opens beside them when asked")

-- U7: "Disenchants into" on TBC Anniversary: the skill line, grey when one
-- of your characters has it (Enchanting 50 here), red when none does
local D = PB.Disenchant
EXPECT(D and D.source:find("^cmangos TBCDB ") and TSF:DisenchantGroup(821) and TSF:DisenchantGroup(21852),
       "TBC disenchant data not loaded")
local tipLines = {}
rawset(GameTooltip, "AddLine", function(_, t, r, g, b) tipLines[#tipLines + 1] = { t, r, g, b } end)
rawset(GameTooltip, "AddDoubleLine", function(_, l, rt, lr, lg, lb, rr, rg, rb) tipLines[#tipLines + 1] = { l, rt, rr, rg, rb } end)
rawset(GameTooltip, "Show", function() end)
local function hover(itemID)
    tipLines = {}
    rawset(GameTooltip, "GetItem", function() return "x", "|cffffffff|Hitem:" .. itemID .. "::::::::|h[x]|h|r" end)
    GameTooltip._h.OnTooltipSetItem(GameTooltip)
    for _, l in ipairs(tipLines) do if l[1] == "Disenchants into (ProfessionBuddy):" then return l end end
end
local h = hover(821)
EXPECT(h and h[2] == "Requires Enchanting 1" and h[3] == 0.7, "item 821 skill line: " .. tostring(h and h[2]))
-- a friend's Enchanting does not count: only your own characters
PB.db.characters["Friend-Realm"] = { isRemote = true, professions = { Enchanting = { skillLevel = 375 } } }
h = hover(21852)
EXPECT(h and h[2] == "Requires Enchanting 275" and h[3] == 1 and h[4] == 0.25, "item 21852 not red: " .. tostring(h and h[2]))
PB.db.characters["Friend-Realm"] = nil
print("  PASS " .. TAG .. "7 Disenchants into on TBC Anniversary: Requires Enchanting, grey with an Enchanter who has it, red without")

-- U8: nothing PB calls is missing on this client
local missing = {}
for _, name in ipairs({ "GetItemInfo", "GetSpellInfo", "GetTradeSkillInfo", "GetCraftInfo",
                        "GetSkillLineInfo", "C_TradeSkillUI" }) do
    if FALLBACK[name] then missing[#missing + 1] = name end
end
EXPECT(#missing == 0, "fell back to a stub for " .. table.concat(missing, ", "))
print("  PASS " .. TAG .. "8 no classic API call fell back to a stub")

print("ALL TBC WINDOW TESTS PASS (" .. LOOK .. ", 8)")
