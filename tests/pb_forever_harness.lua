----------------------------------------------------------------------
-- WoW: Forever harness (Forever 2.0.0, Phases 0 and 2a).
--
-- Loads ProfessionBuddy_Mainline.toc into a modern-client stub
-- (tests/forever_env.lua) with a fake profession backend built from
-- m4ru's 2026-09-22 harvest (tests/forever_tradeskill.lua), then checks
-- that PB starts cleanly and that its own window reads Forever's
-- professions: Blizzard's window suppressed, the known recipes with
-- reagents, counts, colours and the game's categories, tabs that open by
-- skill line, Mining never filed under Smelting, crafting switched off,
-- late item names retried, a clean close and reopen, the K profession
-- book, and the edge rows the harvest has no example of.
----------------------------------------------------------------------

dofile("tests/forever_env.lua")
dofile("tests/forever_tradeskill.lua")

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function called(prefix)
    for _, c in ipairs(TS_CALLS) do if c:sub(1, #prefix) == prefix then return true end end
    return false
end

-- F1: every Mainline file loads
local files, errs = LOAD_TOC("ProfessionBuddy_Mainline.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
for _, f in ipairs(files) do
    EXPECT(not f:match("^Data/") and f ~= "Source/Classic.lua", "Mainline toc loads " .. f)
end
print("  PASS F1 Mainline toc loads " .. #files .. " entries with no error, no TBC data, no Classic source")

-- F2: startup runs every module Init without error and records the professions
ProfBuddyDB = nil
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
for _, l in ipairs(PRINTS) do EXPECT(not l:find("failed to load", 1, true), "module init error: " .. l) end
EXPECT(PRINTED("loaded.  /pb"), "no loaded line")
EXPECT(not PRINTED("not supported"), "a not-supported line is still printed")
local DS = ProfBuddy.DataStore
local lw, sk = DS:GetProfession(nil, "Leatherworking"), DS:GetProfession(nil, "Skinning")
EXPECT(lw and lw.skillLevel == 1 and lw.maxSkill == 75, "Leatherworking 1/75 not recorded")
EXPECT(sk and sk.skillLevel == 43, "Skinning 43 not recorded")
EXPECT(DS:GetProfession(nil, "Cooking"), "Cooking not recorded")
print("  PASS F2 startup: every module starts, no not-supported line, professions and skill levels recorded")

-- F3: Source/Forever.lua meets the contract with the modern events and frame
local S = ProfBuddy.Source
EXPECT(S.flavor == "forever", "flavor is " .. tostring(S.flavor))
EXPECT(#S:Missing() == 0, "Source contract gaps: " .. table.concat(S:Missing(), ", "))
EXPECT(S.EVENT.TRADE_UPDATE == "TRADE_SKILL_LIST_UPDATE" and not S.EVENT.CRAFT_SHOW, "wrong events")
EXPECT(S.DEFAULT_FRAMES.Blizzard_Professions == "ProfessionsFrame", "ProfessionsFrame not a default frame")
EXPECT(ProfBuddy.CRAFTABLE_PROFS.Mining and ProfBuddy.CRAFTABLE_PROFS.Skinning
       and not ProfBuddy.CRAFTABLE_PROFS.Smelting, "craftable set not Forever's")
print("  PASS F3 Source/Forever.lua meets the contract: modern events, ProfessionsFrame, no Craft API, no Smelting")

-- F4: profession events on, trainer events off, no tooltip script hooked
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE" }) do
    EXPECT(REGISTERED[e], e .. " not registered")
end
for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do EXPECT(not REGISTERED[e], e .. " registered") end
for _, h in ipairs(HOOKED) do EXPECT(not h:find("OnTooltipSet", 1, true), "hooked " .. h) end
print("  PASS F4 profession events registered, trainer events not, no OnTooltipSet* hooks")

-- F5: the C_ replacements are the ones in use
ProfBuddy.Scanner:ScanInventory()
local used = {}
for _, c in ipairs(CALLS) do used[c] = true end
EXPECT(used["C_Container.GetContainerNumSlots"], "bag scan did not use C_Container")
print("  PASS F5 bag scan uses C_Container; no removed global is called")

-- F6: /pb opens without error
local ok, err = pcall(SlashCmdList.PROFBUDDY, "")
EXPECT(ok, "/pb error: " .. tostring(err))
print("  PASS F6 /pb runs")

-- F7: opening Leatherworking loads Blizzard's window, PB suppresses it before
-- it shows, and PB opens once the list is ready (not before)
local TSF = ProfBuddy.TradeSkillFrame
EXPECT(TSF, "TradeSkillFrame module missing")
C_TradeSkillUI.OpenTradeSkill(165)
FLUSH()
EXPECT(ProfessionsFrame and not ProfessionsFrame:IsShown(), "Blizzard's ProfessionsFrame is showing")
EXPECT(PANEL_MANAGED[#PANEL_MANAGED] == false, "ShowUIPanel still routed ProfessionsFrame through the panel manager")
EXPECT(UIPanelWindows.ProfessionsFrame == nil, "ProfessionsFrame still registered as a UI panel")
EXPECT(not (TSF.frame and TSF.frame:IsShown()), "PB opened before the list was ready")
TS_LIST_READY()
FLUSH()
EXPECT(TSF.frame and TSF.frame:IsShown(), "PB did not open on TRADE_SKILL_LIST_UPDATE")
print("  PASS F7 Leatherworking: Blizzard's window suppressed before it shows, PB opens when the list is ready")

-- F8: the known recipes, with reagents, counts, colours and the game's categories
local st = TSF.state
EXPECT(st.profName == "Leatherworking" and st.skillLevel == 1 and st.maxSkill == 75, "skill bar state wrong")
EXPECT(count(st.allRecipes) == 6, "expected the 6 learned recipes, got " .. count(st.allRecipes))
EXPECT(not st.allRecipes["Sewing Machine"], "an unlearned recipe is listed")
local ll = st.allRecipes["Light Leather"]
EXPECT(ll and ll.index == 2881 and ll.spellID == 2881 and ll.itemID == 2318, "Light Leather ids wrong")
EXPECT(ll.difficulty == "optimal" and ll.numAvail == 14 and ll.category == "Reagents", "Light Leather row wrong")
EXPECT(#ll.reagents == 1 and ll.reagents[1].name == "Ruined Leather Scraps"
       and ll.reagents[1].count == 3 and ll.reagents[1].itemID == 2934, "Light Leather reagents wrong")
local headers = {}
for _, r in ipairs(st.recipes) do if r.isHeader then headers[r.name] = true end end
for _, h in ipairs({ "Reagents", "Cloaks", "Leather Boots", "Armor Kits" }) do
    EXPECT(headers[h], "no category header " .. h)
end
print("  PASS F8 6 learned recipes (unlearned ones left out), reagents with counts, orange, game category headers")

-- F9: the Scanner stored the list under Leatherworking, keyed for sync
local stored = DS:GetProfession(nil, "Leatherworking")
EXPECT(stored and stored.recipes["Light Leather"] and stored.recipes["Light Leather"].index == 2881,
       "Leatherworking recipes not stored")
EXPECT(count(stored.recipes) == 6, "stored " .. count(stored.recipes) .. " recipes")
print("  PASS F9 the Scanner stored the 6 recipes under Leatherworking with recipe IDs")

-- F10: crafting is off: no craft call, no craft tracking
TSF:DoCraftImmediate(1)
TSF:DoCraft()
EXPECT(not called("CraftRecipe") and not TSF._craftingActive, "a craft started")
print("  PASS F10 craft buttons and the qty box start no craft (Phase 2b)")

-- F11: tabs open by skill line; Skinning shows its camp recipe in grey
local tabs = TSF.profTabsByName
EXPECT(tabs.Skinning.skillLine == 393 and tabs.Mining.skillLine == 186 and tabs.Herbalism
       and tabs.Herbalism.skillLine == 182, "tab skill lines wrong")
EXPECT(tabs.Skinning:GetAttribute("type") == nil, "Skinning tab still has a macro")
EXPECT(tabs["Find Minerals"]:GetAttribute("macrotext") == "/cast Find Minerals", "Find Minerals macro gone")
EXPECT(tabs.Skinning:IsShown() and tabs.Leatherworking:IsShown() and tabs.Cooking:IsShown(), "known tabs hidden")
TS_CALLS = {}
tabs.Skinning:GetScript("PostClick")(tabs.Skinning)
EXPECT(called("OpenTradeSkill:393"), "Skinning tab did not open skill line 393")
TSF._isMouseOverTab = false
TS_LIST_READY()
FLUSH()
EXPECT(st.profName == "Skinning" and TSF.frame:IsShown(), "Skinning did not open in PB")
local chair = st.allRecipes["Camp Chair"]
EXPECT(chair and chair.difficulty == "trivial" and chair.category == "Camping", "Camp Chair row wrong")
print("  PASS F11 tabs open by skill line (Skinning 393, Mining 186, Herbalism 182); Skinning shows Camp Chair, grey, Camping")

-- F12: Mining stays Mining
C_TradeSkillUI.OpenTradeSkill(186)
TS_LIST_READY()
FLUSH()
EXPECT(st.profName == "Mining", "Mining opened as " .. tostring(st.profName))
EXPECT(st.allRecipes["Smelt Copper"] and st.allRecipes["Smelt Copper"].category == "Smelted Bars", "Smelt Copper row wrong")
EXPECT(DS:GetProfession(nil, "Mining").recipes["Smelt Copper"], "Mining recipes not stored under Mining")
EXPECT(not DS:GetProfession(nil, "Smelting"), "something was stored under Smelting")
print("  PASS F12 Mining opens and is stored as Mining, never Smelting")

-- F13: reagent names that arrive late are requested and filled in
local char = DS:GetCharacter()
char.professions["Leatherworking"] = nil
UNCACHED[2934] = true
TS_CALLS = {}
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
EXPECT(called("RequestLoadItemDataByID:2934"), "the missing item was not requested")
EXPECT(st.allRecipes["Light Leather"].reagents[1].name == "Ruined Leather Scraps", "reagent name never filled in")
local re = DS:GetProfession(nil, "Leatherworking")
EXPECT(re and re.recipes["Light Leather"] and re.recipes["Light Leather"].reagents[1].name == "Ruined Leather Scraps",
       "stored list missing or has the placeholder name")
print("  PASS F13 a reagent name missing from the item cache is requested, then shown and stored")

-- F14: close with PB's X, then reopen
TS_CALLS = {}
TSF.frame:Hide()
FLUSH()
EXPECT(called("CloseTradeSkill") and TS.open == nil, "closing PB did not close the profession")
EXPECT(not TSF.frame:IsShown(), "PB still shown")
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
EXPECT(TSF.frame:IsShown() and st.profName == "Leatherworking", "reopen failed")
EXPECT(not ProfessionsFrame:IsShown(), "Blizzard's window showed on reopen")
print("  PASS F14 PB's close closes the profession; reopening works and Blizzard's window stays hidden")

-- F15: rows the harvest has no example of (synthetic): a recipe that can
-- give no skill-up is grey whatever its tier; optional reagent slots are
-- left out; a second learned recipe with the same name is listed once
local T = C_TradeSkillUI
local realInfo, realSchem, realIDs = T.GetRecipeInfo, T.GetRecipeSchematic, T.GetAllRecipeIDs
T.GetRecipeInfo = function(id)
    local info = realInfo(id == 999001 and 2881 or id)
    if info and id == 2881 then info.canSkillUp = false end
    if info and id == 999001 then info.recipeID = 999001 end
    return info
end
T.GetRecipeSchematic = function(id, ...)
    local sch = realSchem(id, ...)
    if id == 2881 then
        sch.reagentSlotSchematics[#sch.reagentSlotSchematics + 1] =
            { required = false, reagentType = 0, quantityRequired = 1, reagents = { { itemID = 2320 } } }
    end
    return sch
end
T.GetAllRecipeIDs = function()
    local ids = realIDs()
    ids[#ids + 1] = 999001
    return ids
end
local win = S:ReadOpenWindow(false)
local n, lightRow = 0, nil
for _, row in ipairs(win.rows) do
    if row.name == "Light Leather" then n = n + 1; lightRow = row end
end
EXPECT(n == 1 and lightRow.recipeID == 2881, "Light Leather listed " .. n .. " times")
EXPECT(lightRow.difficulty == "trivial" and S:GetRowState(2881) == "trivial", "no-skill-up recipe not grey")
EXPECT(#lightRow.reagents == 1, "optional reagent slot listed")
T.GetRecipeInfo, T.GetRecipeSchematic, T.GetAllRecipeIDs = realInfo, realSchem, realIDs
print("  PASS F15 no-skill-up recipe is grey, optional reagents left out, a duplicate name is listed once")

-- F16: ProfessionsFrame is also the profession book (the K key): PB lets it
-- through, on its book page and in Blizzard's spot, only while no profession
-- is open, and takes it down quietly when a profession opens from it
ToggleProfessionsBook()
EXPECT(not ProfessionsFrame:IsShown(), "the book opened over PB's open profession")
TSF.frame:Hide()
FLUSH()
EXPECT(TS.open == nil, "profession still open")
ToggleProfessionsBook()
EXPECT(ProfessionsFrame:IsShown(), "K did not open the profession book")
EXPECT(ProfessionsFrame.BookPage:IsShown() and not ProfessionsFrame.CraftingPage:IsShown(),
       "the book opened on the empty recipe page")
EXPECT(ProfessionsFrame:GetNumPoints() > 0, "the book has no position")
TS_CALLS = {}
C_TradeSkillUI.OpenTradeSkill(165)
EXPECT(not ProfessionsFrame:IsShown(), "the book stayed up when a profession opened from it")
EXPECT(TS.open == "Leatherworking" and not called("CloseTradeSkill"), "hiding the book closed the profession")
TS_LIST_READY()
FLUSH()
EXPECT(TSF.frame:IsShown() and st.profName == "Leatherworking", "PB did not take the profession")
TSF.frame:Hide()
FLUSH()
ToggleProfessionsBook()
ToggleProfessionsBook()
EXPECT(not ProfessionsFrame:IsShown(), "K did not close the book")
print("  PASS F16 K opens the profession book (book page, Blizzard's spot) when no profession is open; a profession opened from it goes to PB without closing")

-- F17: m4ru's 2026-09-26 run. Once any profession has been open, every
-- later show of Blizzard's frame made its right-hand profession tabs cast
-- their spells, so K reopened the last tab's profession (Cooking) in PB
-- instead of showing the book; and K did not close PB's window
ToggleProfessionsBook()
C_TradeSkillUI.OpenTradeSkill(185)
TS_LIST_READY()
FLUSH()
EXPECT(st.profName == "Cooking" and TSF.frame:IsShown(), "Cooking from the book did not open in PB")
TSF.frame:Hide()
FLUSH()
TS_CALLS = {}
ToggleProfessionsBook()
FLUSH()
EXPECT(not called("OpenTradeSkill"), "showing the book opened a profession: " .. table.concat(TS_CALLS, ", "))
EXPECT(ProfessionsFrame:IsShown() and ProfessionsFrame.BookPage:IsShown(), "K did not show the book")
EXPECT(not TSF.frame:IsShown(), "PB opened on K")
ToggleProfessionsBook()
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
TS_CALLS = {}
ToggleProfessionsBook()
FLUSH()
EXPECT(not TSF.frame:IsShown() and called("CloseTradeSkill"), "K did not close PB's profession window")
EXPECT(not ProfessionsFrame:IsShown(), "K opened the book over the closing profession")
print("  PASS F17 after a profession was open, K shows the book and opens no profession; K closes PB's profession window")

local fb = {}
for k in pairs(FALLBACK) do fb[#fb + 1] = k end
table.sort(fb)
print("  INFO globals PB touched that this stub does not model: " .. table.concat(fb, ", "))
print("ALL FOREVER TESTS PASS (17)")
