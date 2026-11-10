----------------------------------------------------------------------
-- WoW: Forever harness (Forever 2.0.0, Phases 0, 2a, 2b and 4a).
--
-- Loads ProfessionBuddy_Forever.toc into a modern-client stub
-- (tests/forever_env.lua) with a fake profession backend built from
-- m4ru's 2026-09-22 harvest (tests/forever_tradeskill.lua), then checks
-- that PB starts cleanly and that its own window reads Forever's
-- professions: Blizzard's window suppressed, the known recipes with
-- reagents, counts, colors and the game's categories, tabs that open by
-- skill line, Mining never filed under Smelting, crafting (Phase 2b),
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
local files, errs = LOAD_TOC("ProfessionBuddy_Forever.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
for _, f in ipairs(files) do
    EXPECT((not f:match("^Data/") or f:match("^Data/Forever/")) and f ~= "Source/Classic.lua",
           "Mainline toc loads " .. f)
end
print("  PASS F1 Mainline toc loads " .. #files .. " entries with no error, no TBC data, no Classic source")

-- F2: startup runs every module Init without error and records the professions
ProfBuddyDB = nil
FIRE("ADDON_LOADED", "ProfessionBuddy")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
for _, l in ipairs(PRINTS) do EXPECT(not l:find("failed to load", 1, true), "module init error: " .. l) end
EXPECT(PRINTED("loaded. Type /pb or /profbuddy."), "no loaded line")
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

-- F4: profession events on; TRAINER_SHOW for the Forever trainer scan
-- (Knowledge.lua) but not TRAINER_UPDATE, which only the Classic scan
-- uses; no tooltip script hooked
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE" }) do
    EXPECT(REGISTERED[e], e .. " not registered")
end
EXPECT(REGISTERED.TRAINER_SHOW, "TRAINER_SHOW not registered")
EXPECT(not REGISTERED.TRAINER_UPDATE, "TRAINER_UPDATE registered (the Classic trainer scan is on)")
for _, h in ipairs(HOOKED) do EXPECT(not h:find("OnTooltipSet", 1, true), "hooked " .. h) end
print("  PASS F4 profession events and TRAINER_SHOW registered, TRAINER_UPDATE not, no OnTooltipSet* hooks")

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

-- F8: the known recipes, with reagents, counts, colors and the game's categories
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

-- F10: crafting (Phase 2b). CraftRecipe(recipeID, n); each finished cast of
-- THAT spell ID counts the quantity box down, even when another spell has
-- the same name; an interrupt stops tracking; Craft All and the qty box are
-- capped at what you can make; a cooldown shows; an enchant that goes on
-- gear is one plain Craft, an Enchanting recipe that makes an item crafts
-- like any other
local function pick(name) st.selected = name; TSF:UpdateCraftBar() end
-- No FLUSH here: the fake C_Timer runs every pending timer at once, and
-- that would fire PB's 10-second craft watchdog mid-batch.
local function cast(event, spellID) FIRE(event, "player", "Cast-guid", spellID) end
local realSpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id)
    if id == 2881 or id == 99999 then return { name = "Light Leather", spellID = id } end
    return realSpellInfo(id)
end
pick("Light Leather")
TS_CALLS = {}
TSF:DoCraftImmediate(5)
EXPECT(called("CraftRecipe:2881x5") and TSF._craftingActive and TSF._craftSpellID == 2881, "Craft 5 did not start")
cast("UNIT_SPELLCAST_SUCCEEDED", 99999)
EXPECT(TSF._craftRemaining == 5, "a same-name spell counted as the craft")
cast("UNIT_SPELLCAST_SUCCEEDED", 2881)
EXPECT(TSF._craftRemaining == 4 and TSF.qtyBox:GetText() == "4", "the quantity did not count down")
for _ = 1, 4 do cast("UNIT_SPELLCAST_SUCCEEDED", 2881) end
EXPECT(not TSF._craftingActive and TSF.qtyBox:GetText() == "1", "tracking did not stop at zero")
TS_CALLS = {}
TSF:DoCraftImmediate("all")
EXPECT(called("CraftRecipe:2881x14"), "Craft All did not craft what you can make: " .. table.concat(TS_CALLS, ", "))
cast("UNIT_SPELLCAST_INTERRUPTED", 12345)
EXPECT(TSF._craftingActive, "another spell's interrupt stopped the craft")
cast("UNIT_SPELLCAST_INTERRUPTED", 2881)
EXPECT(not TSF._craftingActive, "an interrupt did not stop tracking")
TS_CALLS = {}
TSF.qtyBox:SetText("99")
TSF:DoCraft()
EXPECT(called("CraftRecipe:2881x14"), "the qty box was not capped at what you can make")
TSF:StopCraftTracking()
C_Spell.GetSpellInfo = realSpellInfo
TS_COOLDOWN[2881] = 3600
FIRE("TRADE_SKILL_LIST_UPDATE")
FLUSH()
EXPECT(TSF:CooldownSuffix({ name = "Light Leather" }):find("On cooldown", 1, true), "no cooldown line")
TS_COOLDOWN[2881] = nil
C_TradeSkillUI.OpenTradeSkill(333)
TS_LIST_READY()
FLUSH()
EXPECT(st.profName == "Enchanting", "Enchanting did not open")
pick("Enchant Bracer - Minor Stamina")
EXPECT(TSF.craftBtns[1]:IsShown() and not TSF.craftBtns[2]:IsShown() and not TSF.qtyBox:IsShown(),
       "the enchant does not show one plain Craft button")
TS_CALLS = {}
TSF.qtyBox:SetText("5")
TSF:DoCraft()
EXPECT(called("CraftRecipe:7457x1") and #TS_CALLS == 1, "the enchant was not one CraftRecipe: " .. table.concat(TS_CALLS, ", "))
TSF:StopCraftTracking()
pick("Lesser Magic Wand")
EXPECT(TSF.craftBtns[2]:IsShown() and TSF.qtyBox:IsShown(), "the wand lost its quantity controls")
TS_CALLS = {}
TSF:DoCraftImmediate(2)
EXPECT(called("CraftRecipe:14293x2"), "the wand did not craft 2")
TSF:StopCraftTracking()
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
print("  PASS F10 crafting: CraftRecipe with the count, countdown by spell ID, interrupt, Craft All and qty capped, cooldown line, enchant as one Craft, wand batches")

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

-- F18: the bag scan reads the reagent bag. m4ru's 2026-09-27 run: Light
-- Leather in the Skinning Satchel (reagent bag slot) read 0 on the reagent
-- lines while the game said Can make 14
ProfBuddy.Scanner:ScanInventory()
local bags = DS:GetCharacter().inventory.bags
EXPECT(bags[2934] == 3, "backpack reagent not counted")
EXPECT(bags[2318] == 14, "reagent bag not counted: " .. tostring(bags[2318]))
print("  PASS F18 the bag scan counts the backpack and the reagent bag (bag 5)")

-- F19: Phase 4a, the Forever recipe data (Data/Forever, baked from build
-- 1.60.1.70009). Every profession loads through RecipeDB with well-formed
-- rows and no TBC data; the Missing list shows the recipes you do not know
-- with m4ru's captured learn levels; a recipe whose learn level is not
-- known yet shows "?" without an error
local RDB = ProfBuddy.RecipeDB
local nProf, nRec, unknownLearn = 0, 0, nil
local METHODS = { trainer = true, automatic = true, undetermined = true }
for prof, recipes in pairs(RDB.data) do
    nProf = nProf + 1
    for name, r in pairs(recipes) do
        nRec = nRec + 1
        EXPECT(type(r.spellID) == "number" and type(r.itemID) == "number", prof .. "/" .. name .. " ids")
        local sr = r.skillRange
        if sr then
            EXPECT(sr[2] <= sr[3] and sr[3] <= sr[4], prof .. "/" .. name .. " range order")
            EXPECT((sr[1] == false) == (r.skillReq == nil), prof .. "/" .. name .. " orange vs skillReq")
            -- orange above yellow is real on Forever (28 recipes, e.g. Basic
            -- Campfire: taught at 20, yellow at 1), so it is not checked
            if sr[1] == false and prof == "Leatherworking" and not unknownLearn then unknownLearn = name end
        end
        for _, g in ipairs(r.reagents or {}) do
            EXPECT(type(g.name) == "string" and g.name ~= "", prof .. "/" .. name .. " reagent name")
        end
        EXPECT(r.sources and METHODS[r.sources[1].method], prof .. "/" .. name .. " source")
    end
end
-- 2354 at the launch build 1.60.1.70790 (Enchant Boots - Speed, and Gray
-- Leather Boots as its own recipe); 13 and 2347 without Comprehension (the
-- mage's spellbook skill, 7 entries), which has no profession window
EXPECT(nProf == 13 and nRec == 2347, "expected 13 professions / 2347 recipes, got " .. nProf .. " / " .. nRec)
-- Tanning and Gardening open the Skinning and Herbalism windows; they are
-- not recipes (the game does not list them)
EXPECT(RDB.data.Skinning.Tanning == nil and RDB.data.Herbalism.Gardening == nil, "a profession window spell baked as a recipe")
EXPECT(not RDB.data.Smelting and not RDB.data.Jewelcrafting, "TBC data loaded on Forever")
EXPECT(RDB.spellToRecipe[2881] and RDB.spellToRecipe[2881].recipeName == "Light Leather", "spell index")
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
local unknown = TSF:GetUnknownForView()
EXPECT(count(unknown) == count(RDB.data.Leatherworking) - 6, "Missing list count " .. count(unknown))
EXPECT(not unknown["Light Leather"], "a known recipe is in the Missing list")
EXPECT(unknown["Handstitched Leather Pants"].skillReq == 15 and unknown["Embossed Leather Boots"].skillReq == 50,
       "captured learn levels not used")
EXPECT(unknownLearn and unknown[unknownLearn], "no Leatherworking recipe with an unknown learn level to check")
st.showTab = "missing"
st.searchText = unknownLearn:lower()   -- so its list row is one of the rows drawn
local ok2, err2 = pcall(function()
    TSF:RefreshRecipeList()
    st.selected = unknownLearn
    TSF:RefreshDetailPanel()
    TSF:UpdateListRows()
end)
EXPECT(ok2, "Missing view with an unknown learn level errored: " .. tostring(err2))
local drawn = false
for _, r in ipairs(st.recipes) do if r.name == unknownLearn then drawn = true end end
EXPECT(drawn, "the unknown-learn recipe was not in the drawn list")
st.showTab, st.searchText = "known", ""
-- a KNOWN recipe whose learn level is unknown draws its "(?-grey)" range
local ll = RDB.data.Leatherworking["Light Leather"]
local keepOrange, keepReq = ll.skillRange[1], ll.skillReq
ll.skillRange[1], ll.skillReq = false, nil
st.searchText = "light leather"
local ok3, err3 = pcall(function()
    TSF:RefreshRecipeList()
    TSF:UpdateListRows()
end)
ll.skillRange[1], ll.skillReq, st.searchText = keepOrange, keepReq, ""
TSF:RefreshRecipeList()
EXPECT(ok3, "a known recipe with an unknown learn level errored: " .. tostring(err3))
print("  PASS F19 Forever data: 14 professions, 2352 recipes, well-formed, no TBC data; Missing list uses captured learn levels; unknown learn level (" .. unknownLearn .. ") shows without error")

-- F20: Phase 4b, the trainer scan (Knowledge.lua), fed m4ru's real Thunder
-- Bluff captures (tests/forever_trainer.lua). A profession trainer's every
-- recipe is recorded with its learn level and the trainer, including known
-- ones that only show with the "used" filter on; the filters go back after;
-- profession ranks and a weapon master are left alone; a recorded learn
-- level replaces the data's on the Missing list, in Learnable Now and in the
-- detail panel, whose Source line names the trainer
dofile("tests/forever_trainer.lua")
local KN = ProfBuddy.Knowledge
EXPECT(KN, "Knowledge module missing")
ProfBuddyDB.knowledge = nil
TRAINER_FILTER_CALLS = {}
TRAINER_OPEN(11869)                 -- Ansekhwa, weapon master
FLUSH()
EXPECT(#TRAINER_FILTER_CALLS == 0, "a weapon master's filters were changed")
EXPECT(ProfBuddyDB.knowledge == nil, "a weapon master was recorded")
TRAINER_CLOSE()

-- a trainer closed before the capture is left alone
TRAINER_OPEN(3008)
TRAINER_CLOSE()
FLUSH()
EXPECT(#TRAINER_FILTER_CALLS == 0 and ProfBuddyDB.knowledge == nil, "a closed trainer was scanned")

-- the filters switch on and back inside the capture, so the window never
-- shows the change
TRAINER_OPEN(3008)                  -- Mak, Leatherworking
EXPECT(#TRAINER_FILTER_CALLS == 0, "filters changed before the capture")
FLUSH()
EXPECT(table.concat(TRAINER_FILTER_CALLS, ",") == "used=true,used=false",
       "filter calls: " .. table.concat(TRAINER_FILTER_CALLS, ","))
EXPECT(TRAINER_FILTER.used == false and TRAINER_FILTER.available and TRAINER_FILTER.unavailable,
       "trainer filters not put back")
local K = ProfBuddyDB.knowledge
local nMak = 0
for _, sv in ipairs(TRAINERS[3008].services) do
    if RDB.spellToRecipe[sv.id] then
        nMak = nMak + 1
        local e = K[sv.id]
        EXPECT(e and e.learnLevel == sv.rank, sv.name .. " learn level " .. tostring(e and e.learnLevel))
        local t = e.teachers[3008]
        EXPECT(t and t.name == "Mak" and t.zone == "Thunder Bluff" and t.faction == "Horde", sv.name .. " teacher")
    else
        EXPECT(K[sv.id] == nil, sv.name .. " (not a recipe) was recorded")
    end
end
EXPECT(nMak == 16, "expected Mak's 16 recipes in the data, got " .. nMak)
TRAINER_CLOSE()
TRAINER_OPEN(7089)                  -- Mooranta, Skinning
FLUSH()
EXPECT(K[1229517] and K[1229517].learnLevel == 20, "Camp Chair (known, used filter) not recorded")
EXPECT(K[8617] == nil and K[8613] == nil, "a Skinning rank was recorded")
TRAINER_CLOSE()
-- Vhan, Tailoring: this character has no Tailoring, and every Tailoring
-- recipe he lists is still recorded (the capture came from such a character)
EXPECT(not DS:GetProfession(nil, "Tailoring"), "the test character knows Tailoring")
TRAINER_OPEN(11051)
FLUSH()
local nVhan = 0
for _, sv in ipairs(TRAINERS[11051].services) do
    if RDB.spellToRecipe[sv.id] then
        nVhan = nVhan + 1
        local e = K[sv.id]
        EXPECT(e and e.learnLevel == sv.rank and e.teachers[11051] and e.teachers[11051].name == "Vhan",
               sv.name .. " (Tailoring) not recorded")
    else
        EXPECT(K[sv.id] == nil, sv.name .. " (not a recipe) was recorded")
    end
end
EXPECT(nVhan == 24, "expected Vhan's 24 recipes in the data, got " .. nVhan)
EXPECT(K[3908] == nil, "Apprentice Tailoring was recorded")
TRAINER_CLOSE()

-- a recorded learn level replaces the data's: a Leatherworking recipe whose
-- learn level the data does not know, taught at 1 by a test trainer
local unk = RDB.data.Leatherworking[unknownLearn]
TRAINERS[90001] = { name = "Tester", tradeskill = true, services = {
    { id = unk.spellID, name = unknownLearn, type = "unavailable", skill = "Leatherworking", rank = 1 } } }
-- the summary line is a stub font string here, so read what is set on it
local keepSummary = TSF.summaryText
TSF.summaryText = { SetText = function(self, t) self.t = t end, GetText = function(self) return self.t end }
TSF:UpdateBottomBar()
local learnBefore = tonumber(TSF.summaryText:GetText():match("Learnable now: (%d+)"))
TRAINER_OPEN(90001)
FLUSH()
TRAINER_CLOSE()
EXPECT(K[unk.spellID].learnLevel == 1, "test trainer not recorded")
TSF:UpdateBottomBar()
local learnAfter = tonumber(TSF.summaryText:GetText():match("Learnable now: (%d+)"))
EXPECT(learnAfter == learnBefore + 1, "Learnable Now " .. tostring(learnBefore) .. " -> " .. tostring(learnAfter))
TSF.summaryText = keepSummary
st.showTab, st.searchText = "missing", unknownLearn:lower()
TSF:RefreshRecipeList()
local row
for _, r in ipairs(st.recipes) do if r.name == unknownLearn then row = r end end
EXPECT(row and row.skillReq == 1, "Missing row learn level " .. tostring(row and row.skillReq))
-- the detail panel's font strings are stubs here, so record what is set
local SHOWN = {}
for _, key in ipairs({ "detSkill", "detRange", "detSource" }) do
    rawset(TSF[key], "SetText", function(_, t) SHOWN[key] = t end)
end
local function shown(key) return type(SHOWN[key]) == "string" and SHOWN[key] or "" end
st.selected = unknownLearn
TSF:RefreshDetailPanel()
EXPECT(shown("detSkill"):find("Requires: 1 (learnable)", 1, true), "detail: " .. shown("detSkill"))
EXPECT(shown("detRange"):find("Orange: 1|r", 1, true), "detail range: " .. shown("detRange"))
EXPECT(shown("detSource"):find("Trainer - Tester (Thunder Bluff)", 1, true), "Source: " .. shown("detSource"))
EXPECT(unk.skillRange[1] == false and unk.skillReq == nil, "the static data was written to")
-- Mak's recipe names Mak
st.searchText = "handstitched leather pants"
TSF:RefreshRecipeList()
st.selected = "Handstitched Leather Pants"
TSF:RefreshDetailPanel()
EXPECT(shown("detSource"):find("Trainer - Mak (Thunder Bluff)", 1, true), "Source: " .. shown("detSource"))
-- the other faction's trainers are left out while their recipes are hidden
local pants = K[2153]
pants.teachers[1] = { name = "Aaron", zone = "Stormwind City", faction = "Alliance" }
local function trainerText(faction)
    local out = KN:MergeSources({ { method = "trainer" } }, 2153, faction)
    return out[1].detail
end
EXPECT(trainerText("Horde") == "Mak (Thunder Bluff)", "Alliance trainer shown to Horde")
EXPECT(trainerText() == "Mak (Thunder Bluff), Aaron (Stormwind City)", "all trainers: " .. tostring(trainerText()))
pants.teachers[1] = nil
-- a known recipe: the trainer on its Source line, and "Learned at" in
-- grey instead of a requirement
C_TradeSkillUI.OpenTradeSkill(393)
TS_LIST_READY()
FLUSH()
st.showTab, st.searchText = "known", ""
TSF:RefreshRecipeList()
st.selected = "Camp Chair"
TSF:RefreshDetailPanel()
EXPECT(shown("detSource"):find("Trainer - Mooranta (Thunder Bluff)", 1, true), "Camp Chair Source: " .. shown("detSource"))
EXPECT(shown("detSkill") == "|cff888888Learned at: 20|r", "Camp Chair: " .. shown("detSkill"))
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
st.showTab, st.searchText, st.selected = "known", "", nil
TSF:RefreshRecipeList()
print("  PASS F20 trainer scan: Mak's 16 recipes with his learn levels, known ones via the used filter switched on and back inside the capture, a trainer closed first left alone, Vhan's 24 Tailoring recipes on a character with no Tailoring, filters put back, ranks and a weapon master skipped; a recorded learn level drives the Missing row, Learnable Now and the detail panel; Source names the trainer; a known recipe says Learned at in grey")

-- F21: Phase 4c, vendors and recipe items (Knowledge.lua). A vendor's
-- recipe items are recorded against the recipes they teach, with where
-- and the price; a recipe item in your bags is noted; the Source line
-- shows two names at most, the current zone first then the most recent,
-- with the full list in its tooltip; a trainer window the player closed
-- before the capture is left alone
dofile("tests/forever_merchant.lua")
MERCHANT_OPEN(90101)
MERCHANT_CLOSE()
local bag = K[5244] and K[5244].vendors and K[5244].vendors[90101]
EXPECT(bag and bag.name == "Test Vendor" and bag.zone == "Thunder Bluff" and bag.itemID == 5083
       and bag.price == 1350 and bag.stock == 1, "Kodo Hide Bag vendor not recorded")
for _, id in ipairs({ 1226212, 1226211, 1226210 }) do
    EXPECT(K[id] and K[id].vendors and K[id].vendors[90101], "tinker " .. id .. " (shared recipe item) not recorded")
end
local leather = RDB.spellToRecipe[2881]
EXPECT(not (K[2881] and K[2881].vendors), "Light Leather (not a recipe item) recorded as a vendor recipe")
MERCHANT_OPEN(90102)
MERCHANT_CLOSE()
EXPECT(K[5244].vendors[90102] and K[5244].vendors[90102].zone == "Orgrimmar", "second vendor not recorded")

-- Source line: the vendors replace "Undetermined - Pattern: Kodo Hide Bag",
-- Thunder Bluff's first because the player is there
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
st.showTab, st.searchText = "missing", "kodo hide bag"
TSF:RefreshRecipeList()
st.selected = "Kodo Hide Bag"
TSF:RefreshDetailPanel()
EXPECT(shown("detSource") == "Source: |cffffff00Vendor - Test Vendor (Thunder Bluff), Other Vendor (Orgrimmar)|r",
       "Kodo Hide Bag Source: " .. shown("detSource"))
-- the most recently seen comes next; a third makes "and 1 more"
K[5244].vendors[90103] = { name = "Zeta Vendor", zone = "Durotar", faction = "Horde", seen = 9999 }
K[5244].vendors[90104] = { name = "Alliance Vendor", zone = "Stormwind City", faction = "Alliance", seen = 9999 }
TSF:RefreshDetailPanel()
EXPECT(shown("detSource") == "Source: |cffffff00Vendor - Test Vendor (Thunder Bluff), Zeta Vendor (Durotar), and 1 more|r",
       "three vendors: " .. shown("detSource"))
-- the tooltip lists every one of this faction's vendors, with the price
local tip = {}
rawset(GameTooltip, "AddLine", function(_, l) tip[#tip + 1] = l end)
rawset(GameTooltip, "SetOwner", function() end)
rawset(GameTooltip, "Show", function() end)
TSF.detSourceHover:GetScript("OnEnter")(TSF.detSourceHover)
local tipText = table.concat(tip, "\n")
EXPECT(tip[1] == "|cffffff00Vendors|r" and #tip == 4, "tooltip: " .. tipText)
EXPECT(tipText:find("Test Vendor - Thunder Bluff  MONEY:1350", 1, true) and tipText:find("Other Vendor - Orgrimmar", 1, true)
       and tipText:find("Zeta Vendor - Durotar", 1, true) and not tipText:find("Alliance", 1, true), "tooltip: " .. tipText)
K[5244].vendors[90103], K[5244].vendors[90104] = nil, nil

-- a recipe item in your bags: "Recipe item - Pattern: Guardian Belt"
BAGS[0][2] = { id = 4298, count = 1 }       -- Pattern: Guardian Belt
ProfBuddy.Scanner:ScanInventory()
BAGS[0][2] = nil
EXPECT(K[3775] and K[3775].items and K[3775].items[4298], "Pattern: Guardian Belt in the bags not noted")
EXPECT(DS:GetCharacter().inventory.bags[4298] == 1, "the bag scan itself changed")
st.searchText = "guardian belt"
TSF:RefreshRecipeList()
st.selected = "Guardian Belt"
TSF:RefreshDetailPanel()
EXPECT(shown("detSource") == "Source: |cff888888Recipe item - Pattern: Guardian Belt|r", "Guardian Belt Source: " .. shown("detSource"))
-- the list row says the same (m4ru 2026-09-29: Kodo Hide Bag's row read
-- "Undetermined" while its detail panel read "Recipe item")
local beltRow
for i, row in ipairs(TSF.listRows) do
    rawset(row.rightText, "SetText", function(_, t) if type(t) == "string" and t:find("Recipe item", 1, true) then beltRow = t end end)
end
TSF:UpdateListRows()
EXPECT(beltRow and beltRow:find("Recipe item", 1, true) and not beltRow:find("Undetermined", 1, true),
       "Guardian Belt row: " .. tostring(beltRow))
tip = {}
TSF.detSourceHover:GetScript("OnEnter")(TSF.detSourceHover)
EXPECT(tip[1] == "|cff888888Recipe item seen in your bags|r", "bag tooltip: " .. table.concat(tip, "\n"))
-- a recipe nothing was seen for keeps the data's Source line and no tooltip
st.searchText = "azure gustwoven belt"
TSF:RefreshRecipeList()
st.selected = "Azure Gustwoven Belt"
TSF:RefreshDetailPanel()
EXPECT(shown("detSource") == "Source: |cff888888Undetermined - Pattern: Azure Gustwoven Belt|r", "untouched Source: " .. shown("detSource"))
tip = {}
TSF.detSourceHover:GetScript("OnEnter")(TSF.detSourceHover)
EXPECT(#tip == 0, "a tooltip for a recipe nothing was seen for")
-- with no recipe selected, hovering shows nothing
st.searchText = "kodo hide bag"
TSF:RefreshRecipeList()
st.selected = "Kodo Hide Bag"
TSF:RefreshDetailPanel()
tip = {}
TSF.detSourceHover:GetScript("OnEnter")(TSF.detSourceHover)
EXPECT(#tip > 0, "no tooltip for Kodo Hide Bag")
st.selected = nil
TSF:RefreshDetailPanel()
tip = {}
TSF.detSourceHover:GetScript("OnEnter")(TSF.detSourceHover)
EXPECT(#tip == 0, "the tooltip outlived its recipe")

-- a trainer window the player closed before the capture is left alone,
-- even if the game has not said the trainer closed yet
TRAINER_FILTER_CALLS = {}
TRAINER_OPEN(3008)
ClassTrainerFrame:Hide()
FLUSH()
EXPECT(#TRAINER_FILTER_CALLS == 0, "a closed trainer window had its filters switched")
TRAINER_CLOSE()
-- without Blizzard's trainer window (another addon's instead), the game's
-- closed event alone stops the capture
local blizzardWindow = ClassTrainerFrame
ClassTrainerFrame = nil
TRAINER.open = 3008
FIRE("TRAINER_SHOW")
TRAINER.open = nil
FIRE("TRAINER_CLOSED")
FLUSH()
ClassTrainerFrame = blizzardWindow
EXPECT(#TRAINER_FILTER_CALLS == 0, "a closed trainer had its filters switched")
st.showTab, st.searchText, st.selected = "known", "", nil
TSF:RefreshRecipeList()
print("  PASS F21 vendors: recipe items recorded with where, price and stock (one item teaching three recipes too), others skipped; bag recipe items noted; Source line two names, here first then newest, other faction left out, full list in its tooltip; a closed trainer window left alone")

-- F22: the round after 4c. The list row and the Source filter use the
-- same sources as the detail panel, trainers and vendors seen included;
-- a recipe that comes with the profession keeps its own learn level
-- whatever a trainer lists (Basic Campfire); the bank is Forever's tab
-- bank, never the keyring or the reagent bag
st.showTab, st.searchText, st.selected = "missing", "", nil
st.filterSource = "Vendor"
TSF:RefreshRecipeList()
local inVendor = {}
for _, r in ipairs(st.recipes) do if not r.isHeader then inVendor[r.name] = true end end
EXPECT(inVendor["Kodo Hide Bag"], "the Vendor filter misses a recipe with a seen vendor")
EXPECT(not inVendor["Azure Gustwoven Belt"], "the Vendor filter shows a recipe no vendor was seen for")
st.filterSource = "All"
st.searchText = "kodo hide bag"
TSF:RefreshRecipeList()
local rowText = {}
for i, row in ipairs(TSF.listRows) do
    rawset(row.rightText, "SetText", function(_, t) rowText[i] = t end)
end
TSF:UpdateListRows()
local kodoRow
for _, t in pairs(rowText) do
    if type(t) == "string" and t:find("Vendor", 1, true) then kodoRow = t end
end
EXPECT(kodoRow == "|cffffff00Vendor|r |cffff4444[35]|r", "Kodo Hide Bag row: " .. tostring(kodoRow))

-- Basic Campfire comes with Cooking at 1; the Cooking trainer's 20 is
-- ignored for it, and still counts for a trainer recipe
local camp = RDB.data.Cooking["Basic Campfire"]
EXPECT(camp.skillReq == 1 and camp.learnFrom == "automatic" and camp.skillRange[1] == 1
       and camp.sources[1].method == "automatic", "Basic Campfire data")
EXPECT(RDB.data.Tailoring["Linen Bag"].skillReq == 1, "Linen Bag data")
ProfBuddyDB.knowledge[1229737] = { learnLevel = 20 }
EXPECT(KN:LearnLevel(1229737) == nil, "a trainer's 20 overrides Basic Campfire")
EXPECT(KN:LearnLevel(2153) == 15, "a trainer recipe lost its recorded learn level")

-- the bank: purchased character tabs only
Enum.BankType = { Character = 0, Account = 2 }
C_Bank = { FetchPurchasedBankTabIDs = function(t) return t == 0 and { 6, 7, 12 } or {} end }
BAGS[-1] = { [1] = { id = 5396, count = 1 } }     -- keyring
BAGS[6]  = { [1] = { id = 2589, count = 5 } }     -- Linen Cloth, tab 1
BAGS[12] = { [1] = { id = 2589, count = 3 }, [2] = { id = 2592, count = 2 } }  -- tab 7
FIRE("BANKFRAME_OPENED")
local bank = DS:GetCharacter().inventory.bank
EXPECT(bank[2589] == 8 and bank[2592] == 2, "bank tabs not counted: " .. tostring(bank[2589]))
EXPECT(bank[2318] == nil, "the reagent bag counted as bank")
EXPECT(bank[5396] == nil, "the keyring counted as bank")
-- a deposit shows up through BAG_UPDATE while the bank is open
BAGS[7] = { [1] = { id = 2592, count = 4 } }
FIRE("BAG_UPDATE", 7)
FLUSH()
bank = DS:GetCharacter().inventory.bank
EXPECT(bank[2592] == 6, "a deposit was not rescanned: " .. tostring(bank[2592]))
-- the bank shut: a bag change does not wipe it
FIRE("BANKFRAME_CLOSED")
FIRE("BAG_UPDATE", 0)
FLUSH()
EXPECT(DS:GetCharacter().inventory.bank[2592] == 6, "the stored bank was wiped with the bank shut")
BAGS[-1], BAGS[6], BAGS[7], BAGS[12] = nil, nil, nil, nil
st.showTab, st.searchText = "known", ""
TSF:RefreshRecipeList()
print("  PASS F22 list row and Source filter use seen vendors; Basic Campfire and Linen Bag learned at 1 and a trainer's 20 ignored; bank = purchased character tabs, not the keyring or reagent bag, rescanned on BAG_UPDATE while open, kept while shut")

-- F23: a selected Missing recipe stays selected when a filter hides it
-- (m4ru 2026-09-27: Longjaw Mud Snapper went blank while he switched the
-- Skill Up filter). Missing recipes are never in allRecipes, so only the
-- profession's data can tell PB the recipe still exists
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
local detailCleared = 0
local clear = TSF.ClearDetailPanel
st.showTab, st.searchText, st.filterDiff = "missing", "azure gustwoven belt", "All"
TSF:RefreshRecipeList()
st.selected = "Azure Gustwoven Belt"
TSF:RefreshDetailPanel()
TSF.ClearDetailPanel = function(...) detailCleared = detailCleared + 1; return clear(...) end
for _, o in ipairs(TSF.sourceDropdown.optionBtns) do
    if o.value == "Vendor" then o:GetScript("OnClick")(o) end
end
TSF.ClearDetailPanel = clear
local listed = false
for _, r in ipairs(st.recipes) do if r.name == "Azure Gustwoven Belt" then listed = true end end
EXPECT(st.filterSource == "Vendor" and not listed, "the Vendor filter did not hide the belt; the test proves nothing")
EXPECT(st.selected == "Azure Gustwoven Belt", "a filtered-out Missing recipe lost its selection")
EXPECT(detailCleared == 0, "the detail panel was cleared")
-- the game's own list updates keep coming while it is hidden (m4ru
-- 2026-09-27: it went blank "on its own"); each redraws the detail panel,
-- which must keep the hidden recipe, and so must the craft bar
local shownName
rawset(TSF.detName, "SetText", function(_, t) shownName = t end)
TS_LIST_READY()
FLUSH()
EXPECT(st.selected == "Azure Gustwoven Belt" and shownName == "Azure Gustwoven Belt",
       "a list update blanked the hidden recipe's detail panel: " .. tostring(shownName))
EXPECT(TSF:GetSelectedRecipe() and TSF:GetSelectedRecipe().name == "Azure Gustwoven Belt", "the craft bar lost the recipe")
-- back to All: listed again, still selected
for _, o in ipairs(TSF.sourceDropdown.optionBtns) do
    if o.value == "All" then o:GetScript("OnClick")(o) end
end
listed = false
for _, r in ipairs(st.recipes) do if r.name == "Azure Gustwoven Belt" then listed = true end end
EXPECT(listed and st.selected == "Azure Gustwoven Belt", "not listed and selected after All")
-- a recipe that is really gone still clears
st.selected = "No Such Recipe"
TSF:RefreshRecipeList()
EXPECT(st.selected == nil, "a recipe the profession does not have kept the selection")
st.showTab, st.searchText, st.filterDiff = "known", "", "All"
TSF:RefreshRecipeList()
print("  PASS F23 a Missing recipe hidden by a filter stays selected and its detail panel stays, through the game's list updates too; a recipe the profession lacks still clears")

-- F24: the filters split (m4ru 2026-09-27: the Skill Up dropdown held only
-- sources in the Missing view). Skill Up lists skill-up colors and shows
-- in Known and All; Source lists sources and shows in Missing and All.
-- Changing the View keeps the selected recipe when the new view has it
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
local function values(dd)
    local out = {}
    for _, o in ipairs(dd.optionBtns) do if o:IsShown() ~= false then out[#out + 1] = o.value end end
    return table.concat(out, ",")
end
local function pick(dd, v)
    for _, o in ipairs(dd.optionBtns) do if o.value == v then o:GetScript("OnClick")(o); return end end
    for i, o in ipairs(TSF.viewDropdown.optionBtns) do
        if dd == TSF.viewDropdown and o.value:match("^" .. v) then o:GetScript("OnClick")(o); return end
    end
    error("no option " .. v)
end
EXPECT(values(TSF.diffDropdown) == "All,No Gray,Orange,Yellow,Green,Gray", "Skill Up options: " .. values(TSF.diffDropdown))
EXPECT(values(TSF.sourceDropdown) == "All,Trainer,Vendor,Drop,Quest,Reputation,Discovery,Automatic,Undetermined",
       "Source options: " .. values(TSF.sourceDropdown))
st.searchText = ""
pick(TSF.viewDropdown, "Known")
EXPECT(TSF.diffDropdown:IsShown() and not TSF.sourceDropdown:IsShown(), "Known view: Skill Up only")
pick(TSF.viewDropdown, "Missing")
EXPECT(not TSF.diffDropdown:IsShown() and TSF.sourceDropdown:IsShown(), "Missing view: Source only")
pick(TSF.viewDropdown, "All")
EXPECT(TSF.diffDropdown:IsShown() and TSF.sourceDropdown:IsShown(), "All view: both")
-- All view: a Skill Up color lists only known recipes, a Source only missing ones
local function listed()
    local known, missing = 0, 0
    for _, r in ipairs(st.recipes) do
        if not r.isHeader then if r.isKnown then known = known + 1 else missing = missing + 1 end end
    end
    return known, missing
end
pick(TSF.diffDropdown, "Orange")
local k, m = listed()
EXPECT(k > 0 and m == 0, "Skill Up Orange in All: " .. k .. " known, " .. m .. " missing")
pick(TSF.diffDropdown, "All")
pick(TSF.sourceDropdown, "Vendor")
k, m = listed()
EXPECT(k == 0 and m > 0, "Source Vendor in All: " .. k .. " known, " .. m .. " missing")
-- a Source pick waits while Known hides its dropdown, and applies again in Missing
pick(TSF.viewDropdown, "Known")
k, m = listed()
EXPECT(k == 6 and st.filterSource == "Vendor", "Known view filtered by Source: " .. k)
pick(TSF.viewDropdown, "Missing")
local kodo = false
for _, r in ipairs(st.recipes) do if r.name == "Kodo Hide Bag" then kodo = true end end
EXPECT(kodo and #st.recipes < 40, "Source Vendor not applied back in Missing")
-- and a Skill Up pick waits while Missing hides its dropdown
pick(TSF.sourceDropdown, "All")
pick(TSF.viewDropdown, "Known")
pick(TSF.diffDropdown, "Orange")
pick(TSF.viewDropdown, "Missing")
k, m = listed()
EXPECT(m > 100 and st.filterDiff == "Orange", "Missing view filtered by Skill Up: " .. m)
pick(TSF.viewDropdown, "Known")
pick(TSF.diffDropdown, "All")
pick(TSF.viewDropdown, "Missing")
pick(TSF.sourceDropdown, "Vendor")
-- the View change keeps a selection the new view has, and clears one it lacks
st.selected = "Kodo Hide Bag"
TSF:RefreshDetailPanel()
local name
rawset(TSF.detName, "SetText", function(_, t) name = t end)
pick(TSF.viewDropdown, "All")
EXPECT(st.selected == "Kodo Hide Bag" and name == "Kodo Hide Bag", "Missing -> All lost the recipe: " .. tostring(name))
pick(TSF.viewDropdown, "Known")
EXPECT(st.selected == nil, "Known kept a recipe it does not have")
pick(TSF.sourceDropdown, "All")
st.selected = "Light Leather"
pick(TSF.viewDropdown, "All")
EXPECT(st.selected == "Light Leather" and name == "Light Leather", "Known -> All lost the recipe")
pick(TSF.viewDropdown, "Known")
EXPECT(st.selected == "Light Leather", "All -> Known lost a known recipe")
print("  PASS F24 Skill Up (colors; Known and All) and Source (sources; Missing and All) are separate; each filters its own recipes; a View change keeps a selection the new view has and clears one it lacks")

-- F25: Phase 4d. The first profession open asks Show everything or Learn
-- as you go (Escape asks again next session); Learn as you go lists only
-- recipes seen at a trainer, a vendor or in the bags, and the counts
-- follow; keep alts separate counts only what a character saw itself,
-- while a record from before 4d still counts for everyone; Settings
-- carries both controls on its title line
local S = ProfBuddyDB.settings
S.foreverRecipes, S.foreverAltsSeparate = nil, nil
KN._asked = nil
local shownPopup
StaticPopupDialogs = {}
StaticPopup_Show = function(which) shownPopup = which end
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
EXPECT(shownPopup == "PROFBUDDY_FOREVER_RECIPES", "no first-open prompt")
local dlg = StaticPopupDialogs.PROFBUDDY_FOREVER_RECIPES
EXPECT(dlg.button1 == "Show everything" and dlg.button2 == "Learn as you go", "prompt buttons")
EXPECT(dlg.text:find("You can change this later in Settings.", 1, true), "prompt text")
dlg.OnEscape()
EXPECT(S.foreverRecipes == nil, "Escape picked a mode")
shownPopup = nil
C_TradeSkillUI.CloseTradeSkill()
C_TradeSkillUI.OpenTradeSkill(165)
TS_LIST_READY()
FLUSH()
EXPECT(shownPopup == nil, "asked twice in one session")
-- not asked yet = Show everything
local all = count(RDB:GetAllUnknownRecipes(nil, "Leatherworking"))
EXPECT(count(RDB:GetUnknownRecipes(nil, "Leatherworking")) == all, "unpicked is not Show everything")
dlg.OnAccept()
EXPECT(S.foreverRecipes == "all", "Show everything not saved")
dlg.OnCancel()
EXPECT(S.foreverRecipes == "seen", "Learn as you go not saved")
local seen = RDB:GetUnknownRecipes(nil, "Leatherworking")
EXPECT(seen["Handstitched Leather Pants"] and seen["Kodo Hide Bag"] and seen["Guardian Belt"],
       "a trainer, vendor or bag recipe is missing from Learn as you go")
EXPECT(not seen["Azure Gustwoven Belt"] and count(seen) < all, "an unseen recipe is listed")
local keep = TSF.summaryText
local sumText
TSF.summaryText = { SetText = function(_, t) sumText = t end }
TSF:UpdateBottomBar()
TSF.summaryText = keep
EXPECT(sumText:find("Missing: " .. count(seen), 1, true), "Missing count: " .. sumText)
-- keep alts separate
local me, other = ProfBuddy:PlayerKey(), "Other-Forever"
local pants = RDB.data.Leatherworking["Handstitched Leather Pants"].spellID
EXPECT(K[pants].seenBy and K[pants].seenBy[me], "a record did not note who saw it")
local legacy = RDB.data.Leatherworking["Embossed Leather Boots"].spellID
K[legacy] = { learnLevel = 50 }                     -- recorded before 4d
S.foreverAltsSeparate = true
EXPECT(KN:Seen(pants, me) and not KN:Seen(pants, other), "separate alts: another character saw Mak's recipe")
EXPECT(KN:Seen(legacy, other), "a record from before 4d stopped counting for another character")
EXPECT(not RDB:GetUnknownRecipes(other, "Leatherworking")["Handstitched Leather Pants"],
       "separate alts: another character's Missing list has it")
-- recording again keeps an old record everyone's
TRAINERS[90002] = { name = "Again", tradeskill = true, services = {
    { id = legacy, name = "Embossed Leather Boots", type = "unavailable", skill = "Leatherworking", rank = 50 } } }
TRAINER_OPEN(90002); FLUSH(); TRAINER_CLOSE()
EXPECT(K[legacy].seenBy["*"] and K[legacy].seenBy[me] and KN:Seen(legacy, other), "re-recording took an old record away from others")
S.foreverAltsSeparate = false
EXPECT(KN:Seen(pants, other), "shared alts: another character does not see Mak's recipe")
-- Settings: the title-line controls follow the mode
TSF:OpenSettings("main")
EXPECT(TSF.foreverModeDD and TSF.foreverAltsCB, "no Forever controls in Settings")
TSF:UpdateForeverSettings()
EXPECT(TSF.foreverAltsCB:IsShown(), "alts box hidden under Learn as you go")
for _, o in ipairs(TSF.foreverModeDD.optionBtns) do
    if o.value == "Show everything" then o:GetScript("OnClick")(o) end
end
EXPECT(S.foreverRecipes == "all" and not TSF.foreverAltsCB:IsShown(), "Show everything from Settings")
EXPECT(count(RDB:GetUnknownRecipes(nil, "Leatherworking")) == all, "Show everything does not list everything")
for _, o in ipairs(TSF.foreverModeDD.optionBtns) do
    if o.value == "Learn as you go" then o:GetScript("OnClick")(o) end
end
EXPECT(S.foreverRecipes == "seen" and TSF.foreverAltsCB:IsShown(), "Learn as you go from Settings")
-- the stub check box always reads unchecked; tick it for real
rawset(TSF.foreverAltsCB, "GetChecked", function() return true end)
TSF.foreverAltsCB:GetScript("OnClick")(TSF.foreverAltsCB)
EXPECT(S.foreverAltsSeparate == true, "alts box does not save")
S.foreverRecipes, S.foreverAltsSeparate = "all", false
-- the board-post alert dropdown shows the setting and saves a choice
EXPECT(S.boardAlert == "known" and TSF.boardAlertDD
       and TSF.boardAlertDD.selectedValue == "Only recipes I know", "board alert dropdown does not show the default")
for _, o in ipairs(TSF.boardAlertDD.optionBtns) do
    if o.value == "Recipes I or my alts know" then o:GetScript("OnClick")(o) end
end
EXPECT(S.boardAlert == "alts", "board alert dropdown does not save: " .. tostring(S.boardAlert))
for _, o in ipairs(TSF.boardAlertDD.optionBtns) do
    if o.value == "Off" then o:GetScript("OnClick")(o) end
end
EXPECT(S.boardAlert == "off", "board alert Off does not save")
S.boardAlert = "known"
print("  PASS F25 first-open prompt (Escape asks again next session); Learn as you go lists only seen recipes and the counts follow; separate alts count their own sightings, pre-4d records stay everyone's; Settings title-line controls; the board-post alert dropdown")

-- F26: Phase 4e, sharing sightings (COMM_REV 8). After a rev-8 peer's
-- SYNC_DATA, PB asks once a session (KNOW_REQ, whisper, BULK) with our
-- professions; a KNOW_REQ is answered with our own records for the asked
-- professions only, rate-limited, never with sharing off; a KNOW_DATA is
-- taken only in answer to our request, sanitized, capped, stored per peer;
-- reads merge it (own learn level first, else the most recent peer's;
-- trainers and vendors from both, "(from <name>)" in the tooltip; a peer's
-- sighting counts as seen); removing the contact or 30 days drops it
local Comm = ProfBuddy.Comm
local AS = LibStub("AceSerializer-3.0")
EXPECT(ProfBuddy.COMM_REV == 12, "COMM_REV is " .. tostring(ProfBuddy.COMM_REV))
local SENT = {}
local realWhisper = Comm.SendWhisper
Comm.SendWhisper = function(_, t, d, target, prio) SENT[#SENT + 1] = { t = t, d = d, to = target, prio = prio } end
local function deliver(from, msg) Comm:OnMessageReceived("PBuddy", AS:Serialize(msg), "WHISPER", from) end
local function sentOf(t) local out = {} for _, m in ipairs(SENT) do if m.t == t then out[#out + 1] = m end end return out end
local FRIEND, OTHER = "Friend-Forever", "Other-Forever"
ProfBuddyDB.contacts[FRIEND] = { trusted = true, autoSync = false, lastSync = 0 }
ProfBuddyDB.contacts[OTHER] = { trusted = true, autoSync = false, lastSync = 0 }
local syncData = { _type = "SYNC_DATA", _commrev = 8, class = "HUNTER", level = 6,
                   faction = "Horde", professions = {}, partial = true }

-- asks after a rev-8 SYNC_DATA, once; a rev-7 peer is never asked
deliver(OTHER, { _type = "SYNC_DATA", _commrev = 7, class = "MAGE", level = 6, faction = "Horde",
                 professions = {}, partial = true })
EXPECT(#sentOf("KNOW_REQ") == 0, "a rev-7 peer was asked for knowledge")
deliver(FRIEND, syncData)
local req = sentOf("KNOW_REQ")
EXPECT(#req == 1 and req[1].to == FRIEND and req[1].prio == "BULK", "no KNOW_REQ after a rev-8 SYNC_DATA")
EXPECT(req[1].d.since == 0 and table.concat(req[1].d.profs, ",") == "Cooking,Enchanting,Leatherworking,Mining,Skinning",
       "KNOW_REQ profs: " .. table.concat(req[1].d.profs, ","))
deliver(FRIEND, syncData)
EXPECT(#sentOf("KNOW_REQ") == 1, "asked twice in one session")

-- serving: our own records for the asked professions, then a cooldown
deliver(FRIEND, { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } })
local out = sentOf("KNOW_DATA")
EXPECT(#out == 1 and out[1].to == FRIEND and out[1].prio == "BULK", "KNOW_REQ not answered")
local share = out[1].d
EXPECT(share.r[2153] and share.r[2153].l == 15 and #share.npcs > 0, "Mak's Handstitched Leather Pants not shared")
EXPECT(K[1229517] and share.r[1229517] == nil, "a Skinning record (Camp Chair) went to a Leatherworking request")
local makIdx
for i, n in ipairs(share.npcs) do if n[2] == "Mak" then makIdx = i end end
EXPECT(makIdx and share.npcs[makIdx][1] == 3008 and share.npcs[makIdx][3] == "Thunder Bluff", "Mak's NPC row")
deliver(FRIEND, { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } })
EXPECT(#sentOf("KNOW_DATA") == 1, "a second KNOW_REQ inside the cooldown was answered")
Comm._knowServed[FRIEND] = nil
deliver(FRIEND, { _type = "KNOW_REQ", since = share.at, profs = { "Leatherworking" } })
out = sentOf("KNOW_DATA")
EXPECT(#out == 2 and next(out[2].d.r) == nil, "since did not cut the answer to newer records")
-- a new sighting after that passes the since cut
local realTime = time
time = function() return realTime() + 1000 end
TRAINER_OPEN(90002); FLUSH(); TRAINER_CLOSE()
Comm._knowServed[FRIEND] = nil
deliver(FRIEND, { _type = "KNOW_REQ", since = share.at, profs = { "Leatherworking" } })
out = sentOf("KNOW_DATA")
local newer = RDB.data.Leatherworking["Embossed Leather Boots"].spellID
EXPECT(#out == 3 and out[3].d.r[newer] and not out[3].d.r[2153], "a newer sighting did not pass the since cut")
time = realTime
-- directed messages only: a KNOW_REQ on the guild channel is ignored
Comm._knowServed[FRIEND] = nil
Comm:OnMessageReceived("PBuddy", AS:Serialize({ _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } }), "GUILD", FRIEND)
EXPECT(#sentOf("KNOW_DATA") == 3, "a KNOW_REQ on the guild channel was answered")
-- a guild-tier peer pays from the guild serve budget
local realTier = Comm.TrustLevel
Comm.TrustLevel = function(_, who) if who == "Guildie-Forever" then return "guild" end return realTier(Comm, who) end
Comm._guildServes = {}
for i = 1, 10 do Comm._guildServes[i] = time() end
deliver("Guildie-Forever", { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } })
EXPECT(#sentOf("KNOW_DATA") == 3, "a guild peer was served past the guild budget")
Comm._guildServes = {}
deliver("Guildie-Forever", { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } })
EXPECT(#sentOf("KNOW_DATA") == 4 and #Comm._guildServes == 1, "a guild peer inside the budget was not served, or not counted")
Comm.TrustLevel = realTier
Comm._knowServed[FRIEND] = nil
ProfBuddyDB.settings.shareData = false
deliver(FRIEND, { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } })
ProfBuddyDB.settings.shareData = true
EXPECT(#sentOf("KNOW_DATA") == 4, "answered with sharing off")

-- the wire round trip: our own answer, taken in as if a friend sent it
Comm._knowPending[FRIEND] = time()
share._type, share._commrev = "KNOW_DATA", 8      -- what Comm:Send adds on the way out
deliver(FRIEND, share)
local fs = ProfBuddyDB.knowledgeShared and ProfBuddyDB.knowledgeShared[FRIEND]
EXPECT(fs and fs.records[2153] and fs.records[2153].learnLevel == 15
       and fs.records[2153].teachers[3008] and fs.records[2153].teachers[3008].name == "Mak",
       "round trip lost Mak's record")
EXPECT(KN:SharedSince(FRIEND) == share.at, "since not kept")
ProfBuddyDB.knowledgeShared[FRIEND] = nil

-- receiving a friend's sightings
local peerOnly
for name, r in pairs(RDB.data.Leatherworking) do
    if not K[r.spellID] and r.learnFrom ~= "automatic" and name ~= "Kodo Hide Bag" then peerOnly = r; break end
end
local kodo = RDB.data.Leatherworking["Kodo Hide Bag"].spellID
local function know(at, l, extra)
    local m = { _type = "KNOW_DATA", at = at, npcs = { { 3999, "Friend Trainer", "Orgrimmar", "", "Horde" },
                                                     { 3998, "Friend Vendor", "Orgrimmar", "Drag", "Horde" } },
                r = { [peerOnly.spellID] = { a = at, l = l, t = { 1 }, i = true },
                      [2153] = { a = at, l = 99, t = { 1 } },
                      [kodo] = { a = at, v = { { 2, 5083, 999 } } } } }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end
deliver(FRIEND, know(100, 77))
EXPECT(ProfBuddyDB.knowledgeShared == nil or ProfBuddyDB.knowledgeShared[FRIEND] == nil,
       "an unrequested KNOW_DATA was stored")
Comm._knowPending[FRIEND] = time()
deliver(FRIEND, know(100, 77))
EXPECT(ProfBuddyDB.knowledgeShared[FRIEND], "a requested KNOW_DATA was not stored")
EXPECT(KN:LearnLevel(peerOnly.spellID) == 77, "a peer's learn level not used")
EXPECT(KN:LearnLevel(2153) == 15, "a peer's learn level beat our own")
Comm._knowPending[OTHER] = time()
deliver(OTHER, know(200, 88))
EXPECT(KN:LearnLevel(peerOnly.spellID) == 88, "the most recent peer did not win")
local merged = KN:MergeSources({ { method = "trainer" } }, peerOnly.spellID, "Horde")
EXPECT(merged[1].detail == "Friend Trainer (Orgrimmar)", "peer trainer on the Source line: " .. tostring(merged[1].detail))
local tip = table.concat(KN:TooltipLines(peerOnly.spellID, "Horde"), "\n")
-- both peers saw Friend Trainer; the newer record (Other's) is credited
EXPECT(tip:find("Friend Trainer - Orgrimmar", 1, true) and tip:find("(from Other)", 1, true)
       and tip:find("Recipe item seen by Friend, Other", 1, true), "tooltip: " .. tip)
local kv = table.concat(KN:TooltipLines(kodo, "Horde"), "\n")
EXPECT(kv:find("Friend Vendor - Orgrimmar, Drag", 1, true) and kv:find("Test Vendor", 1, true), "vendors merged: " .. kv)
ProfBuddyDB.settings.foreverAltsSeparate = true
EXPECT(KN:Seen(peerOnly.spellID, "Anyone-Forever"), "a peer's sighting does not count as seen")
ProfBuddyDB.settings.foreverAltsSeparate = false

-- sanitizing and caps
local function tryFrom(msg)
    ProfBuddyDB.knowledgeShared[FRIEND] = nil
    Comm._knowPending[FRIEND] = time()
    deliver(FRIEND, msg)
    return ProfBuddyDB.knowledgeShared[FRIEND]
end
local big = know(300, 5)
for i = 1, 3001 do big.r[5000000 + i] = { a = 1 } end
EXPECT(tryFrom(big) == nil, "an oversized KNOW_DATA was stored")
local manyN = know(300, 5)
for i = 3, 601 do manyN.npcs[i] = { 4000 + i, "N" .. i, "Z", "", "Horde" } end
EXPECT(tryFrom(manyN) == nil, "601 NPCs were stored")
local manyV = know(300, 5)
manyV.r[kodo].v = {}
for i = 1, 13 do manyV.r[kodo].v[i] = { 2, 5083, 1 } end
EXPECT(tryFrom(manyV) == nil, "13 vendors on one recipe was stored")
local manyT = know(300, 5)
manyT.r[2153].t = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
EXPECT(tryFrom(manyT) == nil, "13 trainers on one recipe was stored")
EXPECT(tryFrom({ _type = "KNOW_DATA", at = 1, npcs = "x", r = {} }) == nil, "a malformed KNOW_DATA was stored")
local junk = know(300, 9999)
junk.npcs[1][2] = "Bad|cffff0000Name"
junk.npcs[1][5] = "Martian"
junk.r[9999999] = { a = 1, l = 5 }                 -- in range, but no such recipe
local got = tryFrom(junk)
EXPECT(got and got.records[9999999] == nil, "an unknown recipe was stored")
EXPECT(got.records[peerOnly.spellID].learnLevel == nil, "a learn level of 9999 was stored")
local t1 = got.records[peerOnly.spellID].teachers[3999]
EXPECT(t1.name == "Bad||cffff0000Name" and t1.faction == nil, "name or faction not sanitized")

-- your own NPC beats a peer's copy of it (no "(from)")
local mine = { _type = "KNOW_DATA", at = 400, npcs = { { 3008, "Mak", "Thunder Bluff", "", "Horde" } },
               r = { [2153] = { a = 400, t = { 1 } } } }
tryFrom(mine)
local pantsTip = table.concat(KN:TooltipLines(2153, "Horde"), "\n")
EXPECT(pantsTip:find("Mak - Thunder Bluff", 1, true) and not pantsTip:find("Mak - Thunder Bluff  |cff888888(from", 1, true),
       "a peer's copy of our own trainer shows (from): " .. pantsTip)
-- a manual sync asks for their knowledge again
deliver(FRIEND, syncData)
local before = #sentOf("KNOW_REQ")
Comm:RequestSync(FRIEND, true)
deliver(FRIEND, syncData)
EXPECT(#sentOf("KNOW_REQ") == before + 1, "a manual sync did not ask again")

-- removing the contact drops their data; a non-contact goes after 30 days
Comm:ForgetPeer(FRIEND)
EXPECT(ProfBuddyDB.knowledgeShared[FRIEND] == nil, "a removed contact's data kept")
ProfBuddyDB.knowledgeShared["Guildie-Forever"] = { at = time() - 31 * 86400, since = 1, records = {} }
ProfBuddyDB.knowledgeShared[OTHER].at = time() - 31 * 86400
KN:PrunePeers()
EXPECT(ProfBuddyDB.knowledgeShared["Guildie-Forever"] == nil, "a 31-day-old non-contact kept")
EXPECT(ProfBuddyDB.knowledgeShared[OTHER], "a contact's data dropped by age")
for i = 1, 105 do ProfBuddyDB.knowledgeShared["P" .. i .. "-Forever"] = { at = time() - i, since = 1, records = {} } end
KN:PrunePeers()
local peersLeft = 0
for _ in pairs(ProfBuddyDB.knowledgeShared) do peersLeft = peersLeft + 1 end
EXPECT(peersLeft == 100 and ProfBuddyDB.knowledgeShared["P1-Forever"] and not ProfBuddyDB.knowledgeShared["P105-Forever"],
       "peer cap: " .. peersLeft .. " left")

Comm.SendWhisper = realWhisper
ProfBuddyDB.knowledgeShared = nil
ProfBuddyDB.contacts[FRIEND], ProfBuddyDB.contacts[OTHER] = nil, nil
print("  PASS F26 knowledge sharing: asked once after a rev-8 sync; served own records for the asked professions, since-cut, rate-limited, not with sharing off; round trip; only requested KNOW_DATA stored, sanitized and capped; own learn level first then the newest peer; peer trainers and vendors merged with (from); peer sightings count as seen; forget and 30-day prune")

-- F27: WoW: Forever surnames. Everyone else knows a character as "First
-- Surname" (roster, addon senders, GetUnitName(unit, true)); UnitName gives
-- the first name and UnitFullName puts the surname in the realm slot. Our
-- own name joins the two; this character's records move from its first-name
-- key to its full key (and nobody else's); contacts take "First Surname";
-- whispers go to "First Surname"; our own echo is still ours; group trust
-- matches a surname sender
local Comm = ProfBuddy.Comm
local oldKey, newKey = "Me-Forever", "Me Surname-Forever"
EXPECT(ProfBuddy:PlayerKey() == oldKey, "no surname readable: key is " .. ProfBuddy:PlayerKey())
function UnitFullName(u) if u == "player" then return "Me", "Surname" end end
EXPECT(ProfBuddy:PlayerName() == "Me Surname" and ProfBuddy:PlayerKey() == newKey, "full name: " .. ProfBuddy:PlayerKey())
issecretvalue = function(v) return v == "Surname" end
EXPECT(ProfBuddy:PlayerName() == "Me", "a secret surname was used")
issecretvalue = nil
EXPECT(ProfBuddy:NameHint() == "First Surname", "usage hint")

-- the move: our record, orders, board, outbox and knowledge
local DB = ProfBuddyDB
local mine = DB.characters[oldKey]
EXPECT(mine and not mine.isRemote and next(mine.professions or {}), "no first-name record to move")
DB.characters[newKey] = { professions = {}, class = "HUNTER" }       -- made this load, empty
DB.orders.test1 = { id = "test1", requester = oldKey, crafter = "Other-Forever", lastSentBy = oldKey }
DB.orders.test2 = { id = "test2", requester = "Other-Forever", crafter = oldKey }
DB.orderBoard.post1 = { id = "post1", requester = oldKey }
DB.orderOutbox = DB.orderOutbox or {}
DB.orderOutbox.o1 = { target = "Other-Forever", data = { order = { requester = oldKey } } }
local kid = RDB.data.Leatherworking["Handstitched Leather Pants"].spellID
DB.knowledge[kid].seenBy[oldKey] = true
FIRE("PLAYER_LOGIN")                        -- the move runs at login
FLUSH()
EXPECT(DB.characters[oldKey] == nil and DB.characters[newKey] == mine, "record not moved, or the empty new one kept")
EXPECT(DB.orders.test1.requester == newKey and DB.orders.test1.lastSentBy == newKey
       and DB.orders.test1.crafter == "Other-Forever" and DB.orders.test2.crafter == newKey, "order fields")
EXPECT(DB.orderBoard.post1.requester == newKey and DB.orderOutbox.o1.data.order.requester == newKey, "board or outbox")
EXPECT(DB.knowledge[kid].seenBy[newKey] and not DB.knowledge[kid].seenBy[oldKey], "knowledge seenBy")
-- idempotent, and another player called "Me" is never touched
DB.characters[oldKey] = { isRemote = true, professions = {} }
ProfBuddy:MigrateToFullName()
EXPECT(DB.characters[oldKey] and DB.characters[oldKey].isRemote and DB.characters[newKey] == mine,
       "a remote first-name record was moved")
DB.characters[oldKey] = nil
DB.orders.test1, DB.orders.test2, DB.orderBoard.post1, DB.orderOutbox.o1 = nil, nil, nil, nil
-- a new-key record that already has data is kept over a stale old one
local stale = { professions = { Cooking = { skillLevel = 1 } } }
DB.characters[oldKey] = stale
ProfBuddy:MigrateToFullName()
EXPECT(DB.characters[newKey] == mine and DB.characters[oldKey] == nil, "a stale old record replaced the live one")

-- contacts: typed and normalized as "First Surname"
local FPm = ProfBuddy.FriendsPanel
EXPECT(FPm.ContactKeyFromInput("turok bokenhorn") == "Turok Bokenhorn-Forever", "Friends panel: first surname")
EXPECT(FPm.ContactKeyFromInput("Turok O'Hara") == "Turok O'Hara-Forever", "Friends panel: apostrophe in surname")
EXPECT(FPm.ContactKeyFromInput("Turok") == "Turok-Forever", "Friends panel: first name alone")
EXPECT(FPm.ContactKeyFromInput("Turok Big Horn") == nil and FPm.ContactKeyFromInput("Tu|rok Horn") == nil
       and FPm.ContactKeyFromInput("T Horn") == nil, "Friends panel: junk accepted")
EXPECT(Comm:NormalizeContactKey("turok bokenhorn") == "Turok Bokenhorn-Forever", "sync target normalized")

-- whispers go to "First Surname"
local sentTo
local realSend = Comm.Send
Comm.Send = function(_, t, d, dist, target) sentTo = target end
Comm:SendWhisper("SYNC_REQ", {}, "Turok Bokenhorn-Realm")
EXPECT(sentTo == "Turok Bokenhorn", "whisper target: " .. tostring(sentTo))
-- our own message, arriving from "Me Surname", is ours
-- (trusted, so only the self check can stop it)
sentTo = nil
ProfBuddyDB.contacts["Me Surname-Forever"] = { trusted = true, autoSync = false, lastSync = 0 }
Comm:OnMessageReceived("PBuddy", LibStub("AceSerializer-3.0"):Serialize({ _type = "SYNC_REQ" }), "WHISPER", "Me Surname")
ProfBuddyDB.contacts["Me Surname-Forever"] = nil
EXPECT(sentTo == nil, "PB answered its own message")
Comm.Send = realSend
-- group trust from GetUnitName(unit, true) matches a surname sender
local keepG, keepN, keepU = IsInGroup, GetNumSubgroupMembers, GetUnitName
IsInGroup = function() return true end
GetNumSubgroupMembers = function() return 1 end
GetUnitName = function(u, full) if u == "party1" then return "Turok Bokenhorn" end return keepU(u, full) end
EXPECT(Comm:IsGroupMember("Turok Bokenhorn") and not Comm:IsGroupMember("Turok"), "group trust with a surname")
IsInGroup, GetNumSubgroupMembers, GetUnitName = keepG, keepN, keepU
UnitFullName = nil
-- back to the no-surname character the later tests use
DB.characters[oldKey], DB.characters[newKey] = DB.characters[newKey], nil
for _, e in pairs(DB.knowledge) do
    if e.seenBy and e.seenBy[newKey] then e.seenBy[newKey] = nil; e.seenBy[oldKey] = true end
end
print("  PASS F27 surnames: own name First Surname (a secret surname falls back), own records move to the full key and nobody else's, contacts and sync take First Surname, whispers go to First Surname, own echo ignored, group trust matches")

-- F28: Phase 3, item tooltips on WoW: Forever. There is no
-- OnTooltipSetItem; PB extends GameTooltip through TooltipDataProcessor
-- post-calls on item tooltips and reads the item with
-- TooltipUtil.GetDisplayedItem. Hovering a reagent shows "Used in", a
-- crafted item "Craftable by"; another tooltip (a chat link's) is left
-- alone, and the Used-in setting still switches it off
rawset(GameTooltip, "AddLine", nil)                            -- F21 captured it
rawset(GameTooltip, "Show", nil)
local posts = 0
for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Item then posts = posts + 1 end end
EXPECT(posts == 5, "item tooltip post-calls: " .. posts)   -- Used in, Craftable by, Held by, Disenchants into, Fill cost (TEST-c)
local function has(lines, text)
    for _, l in ipairs(lines) do if type(l) == "string" and l:find(text, 1, true) then return l end end
end
local lines = SHOW_ITEM_TOOLTIP(GameTooltip, 2318)             -- Light Leather
EXPECT(has(lines, "Used in (ProfessionBuddy):"), "no Used in on Light Leather: " .. table.concat(lines, " / "))
EXPECT(has(lines, "Leatherworking|r - Handstitched Leather Boots"), "Used in lacks a known recipe that takes Light Leather")
EXPECT(has(lines, "Craftable by (ProfessionBuddy):"), "no Craftable by on Light Leather")
local other = CreateFrame("GameTooltip", "ItemRefTooltip", UIParent)
EXPECT(#SHOW_ITEM_TOOLTIP(other, 2318) == 0, "PB added lines to a tooltip other than GameTooltip")
ProfBuddyDB.settings.tooltipShowUsedIn = false
lines = SHOW_ITEM_TOOLTIP(GameTooltip, 2318)
EXPECT(not has(lines, "Used in (ProfessionBuddy):"), "Used in shown with its setting off")
ProfBuddyDB.settings.tooltipShowUsedIn = true
EXPECT(#SHOW_ITEM_TOOLTIP(GameTooltip, 999999) == 0, "lines on an item PB knows nothing about")
print("  PASS F28 item tooltips through TooltipDataProcessor: Used in and Craftable by on GameTooltip, not on other tooltips, Used in follows its setting")

-- F29: the gathering-node hook reads GameTooltip's lines 20 times a
-- second. Forever gives some tooltip text as a secret value (m4ru
-- 2026-09-29: a buff tooltip, "attempt to compare local 'nodeName' (a
-- secret string value)"). The hook must test each line with
-- issecretvalue before it compares, finds in, or looks up that text.
-- Plain Lua cannot make == on a secret fail, so the stand-in secret
-- errors on any other use and the node table records a lookup by it.
do
    local SECRET = newproxy(true)
    local mt = getmetatable(SECRET)
    local used = {}
    local function touch(what) return function() used[#used + 1] = what; error("secret " .. what, 2) end end
    mt.__index = touch("indexed"); mt.__concat = touch("concatenated"); mt.__len = touch("measured")
    mt.__eq = touch("compared"); mt.__lt = touch("compared"); mt.__le = touch("compared")
    mt.__tostring = function() return "<secret>" end
    local onUpdate = GameTooltip._h.OnUpdate
    EXPECT(type(onUpdate) == "function", "no GameTooltip OnUpdate hook")
    local lines = {}
    for i = 1, 2 do
        local fs = CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(fs, "SetText", function(self, t) self._text = t end)
        lines[i] = fs
    end
    local nLines = 1
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return nLines end)
    local added = {}
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "Show", function() end)
    local oldMining, oldHerb = ProfBuddy.MiningNodes, ProfBuddy.HerbNodes
    local lookedUpBySecret = false
    ProfBuddy.MiningNodes = setmetatable({}, { __index = function(_, k)
        if rawequal(k, SECRET) then lookedUpBySecret = true end
        if k == "Copper Vein" then return 1 end
    end })
    ProfBuddy.HerbNodes = nil
    issecretvalue = function(v) return rawequal(v, SECRET) end
    -- 1. the tooltip's title is secret: nothing is read from it
    lines[1]._text = SECRET
    local ok, err = pcall(onUpdate, GameTooltip, 1)
    EXPECT(ok, "secret title: " .. tostring(err))
    EXPECT(not lookedUpBySecret, "secret title looked up in the node table")
    EXPECT(#added == 0, "lines added for a secret title")
    -- 2. a node tooltip with a secret second line: that line is skipped,
    -- and the Requires line still goes on
    lines[1]._text = "Copper Vein"; lines[2]._text = SECRET; nLines = 2
    ok, err = pcall(onUpdate, GameTooltip, 1)
    EXPECT(ok, "secret line on a node tooltip: " .. tostring(err))
    EXPECT(#used == 0, "the secret was used: " .. table.concat(used, ", "))
    EXPECT(added[1] and added[1]:find("Requires Mining (1)", 1, true), "no Requires line: " .. tostring(added[1]))
    issecretvalue = nil
    ProfBuddy.MiningNodes, ProfBuddy.HerbNodes = oldMining, oldHerb
    rawset(GameTooltip, "AddLine", nil); rawset(GameTooltip, "Show", nil)
    rawset(GameTooltip, "GetUnit", nil); rawset(GameTooltip, "GetItem", nil); rawset(GameTooltip, "NumLines", nil)
end
print("  PASS F29 gathering-node tooltip skips secret tooltip text")

-- F30: a Missing recipe shows the color it will have once learned, not a
-- placeholder yellow (m4ru 2026-09-29: Kodo Hide Bag read "Yellow - may
-- level up" before he knew it, and will be orange when learned). Kodo
-- Hide Bag is learned at 35 with range 35/65/80/95; below 35 it reads
-- orange, the color it will have when learned at 35.
do
    C_TradeSkillUI.OpenTradeSkill(165)
    TS_LIST_READY()
    FLUSH()
    local diffText, nameColor, rowColor
    rawset(TSF.detDiff, "SetText", function(_, t) diffText = t end)
    rawset(TSF.detName, "SetTextColor", function(_, r, g, b) nameColor = string.format("%.2f,%.2f,%.2f", r, g, b) end)
    local rowRef
    for _, row in ipairs(TSF.listRows) do
        rawset(row.nameText, "SetText", function(self, t) self._t = t end)
        rawset(row.nameText, "SetTextColor", function(self, r, g, b)
            if self._t == "Kodo Hide Bag" then rowColor = string.format("%.2f,%.2f,%.2f", r, g, b) end
        end)
    end
    st.showTab, st.searchText, st.filterDiff, st.filterSource = "missing", "kodo hide bag", "All", "All"
    TSF:RefreshRecipeList()
    st.selected = "Kodo Hide Bag"
    local ORANGE, YELLOW, GREEN, GREY, WHITE = "1.00,0.50,0.25", "1.00,1.00,0.00", "0.25,0.75,0.25", "0.50,0.50,0.50", "1.00,1.00,1.00"
    local function at(skill)
        st.skillLevel = skill
        diffText, nameColor, rowColor = nil, nil, nil
        TSF:RefreshDetailPanel()
        TSF:UpdateListRows()
        return diffText, nameColor, rowColor
    end
    local cases = {
        { 1,   "Difficulty when learned: Orange: will level up", ORANGE },   -- below 35: learned at 35
        { 64,  "Difficulty when learned: Orange: will level up", ORANGE },
        { 65,  "Difficulty when learned: Yellow: may level up", YELLOW },
        { 80,  "Difficulty when learned: Green: unlikely to level", GREEN },
        { 95,  "Difficulty when learned: Gray: no skill gain", GREY },
    }
    for _, c in ipairs(cases) do
        local d, n, r = at(c[1])
        EXPECT(d == c[2], "skill " .. c[1] .. ": " .. tostring(d))
        EXPECT(n == c[3] and r == c[3], "skill " .. c[1] .. " colors: name " .. tostring(n) .. ", row " .. tostring(r))
    end
    -- no range in PB's data: "not known", in white
    local data = RDB.data.Leatherworking["Kodo Hide Bag"]
    local sr = data.skillRange
    data.skillRange = nil
    TSF:RefreshRecipeList()
    local d, n, r = at(70)
    data.skillRange = sr
    EXPECT(d == "Difficulty when learned: not known", "no range: " .. tostring(d))
    EXPECT(n == WHITE and r == WHITE, "no range colors: name " .. tostring(n) .. ", row " .. tostring(r))
    -- a known recipe keeps the game's tier
    st.showTab, st.searchText = "known", "handstitched leather boots"
    TSF:RefreshRecipeList()
    st.selected = "Handstitched Leather Boots"
    local known
    for _, e in ipairs(st.recipes) do if e.name == st.selected then known = e end end
    EXPECT(known and known.isKnown, "Handstitched Leather Boots not known here")
    local d2 = at(70)
    EXPECT(d2 and d2:find("^Difficulty: ") and not d2:find("when learned", 1, true), "known recipe: " .. tostring(d2))
    st.showTab, st.searchText, st.selected, st.skillLevel = "known", "", nil, 1
    TSF:RefreshRecipeList()
end
print("  PASS F30 a Missing recipe shows the color it will have once learned, in the detail panel and on its row")

-- F31: numbered chunks (COMM_REV 9). Forever delivers the chunks of a long
-- message out of order when they go out in a burst (m4ru's traces,
-- 2026-09-30), and AceComm joins them in arrival order. A message over
-- 255 bytes goes out as "\005<id>:<n>:<total>:<data>" through
-- ChatThrottleLib; the receiver joins by number, in any order, ignores a
-- duplicate and a malformed header, drops a partial message after a
-- minute idle, and caps what one sender, and all senders, can hold.
do
    local Comm = ProfBuddy.Comm
    local AS = LibStub("AceSerializer-3.0")
    local AC = LibStub("AceComm-3.0")
    local CTL = ChatThrottleLib
    local wire, acSent = {}, {}
    local realCTL, realAC = CTL.SendAddonMessage, AC.SendCommMessage
    CTL.SendAddonMessage = function(_, prio, prefix, text, chattype, target, queue)
        wire[#wire + 1] = { prio = prio, prefix = prefix, text = text, chattype = chattype, target = target, queue = queue }
    end
    AC.SendCommMessage = function(_, prefix, text) acSent[#acSent + 1] = text end
    local big = { names = {} }
    for i = 1, 200 do big.names[i] = "Recipe number " .. i end
    Comm:Send("SYNC_DATA", big, "WHISPER", "Pal Friend", "BULK")
    EXPECT(#acSent == 0 and #wire > 10, "long send: " .. #acSent .. " via AceComm, " .. #wire .. " numbered")
    local parts = {}
    for i, w in ipairs(wire) do
        EXPECT(#w.text <= 255 and w.prio == "BULK" and w.prefix == "PBuddy" and w.queue == "PBuddy"
               and w.chattype == "WHISPER" and w.target == "Pal Friend", "chunk " .. i .. " sent wrong")
        local _, n, total, part = w.text:match("^\005(%d+):(%d+):(%d+):(.*)$")
        EXPECT(tonumber(n) == i and tonumber(total) == #wire, "chunk " .. i .. " header: " .. w.text:sub(1, 20))
        parts[i] = part
    end
    local text = table.concat(parts)
    local ok, d = AS:Deserialize(text)
    EXPECT(ok and d._type == "SYNC_DATA" and d._commrev == ProfBuddy.COMM_REV and #d.names == 200, "joined chunks do not read back")
    local longWire = wire
    wire = {}
    Comm:Send("SYNC_REQ", {}, "WHISPER", "Pal Friend")
    EXPECT(#acSent == 1 and #wire == 0, "a short message left AceComm")
    CTL.SendAddonMessage, AC.SendCommMessage = realCTL, realAC

    -- receiving, through the real CHAT_MSG_ADDON event
    local got = {}
    local realRecv = Comm.OnMessageReceived
    Comm.OnMessageReceived = function(_, prefix, msg, dist, sender) got[#got + 1] = { msg = msg, dist = dist, sender = sender } end
    local function deliver(list, sender) for _, t in ipairs(list) do FIRE("CHAT_MSG_ADDON", "PBuddy", t, "WHISPER", sender or "Pal Friend") end end
    local texts = {}
    for i, w in ipairs(longWire) do texts[i] = w.text end
    -- reversed, with a duplicate in the middle
    local rev = {}
    for i = #texts, 1, -1 do rev[#rev + 1] = texts[i] end
    table.insert(rev, 3, texts[#texts - 2])
    deliver(rev)
    EXPECT(#got == 1 and got[1].msg == text and got[1].sender == "Pal Friend" and got[1].dist == "WHISPER",
           "reversed chunks: " .. #got .. " delivered")
    EXPECT(Comm._chunkIn == nil or next(Comm._chunkIn) == nil, "chunks left held after delivery")
    -- the sender as AceComm names it: a same-realm "-Realm" is dropped
    got = {}
    deliver(texts, "Pal Friend-Realm")
    EXPECT(#got == 1 and got[1].sender == "Pal Friend", "sender: " .. tostring(got[1] and got[1].sender))
    -- two messages from one sender, chunks interleaved
    local function chunked(id, str)
        local out, total = {}, math.ceil(#str / 238)
        for n = 1, total do out[n] = "\005" .. id .. ":" .. n .. ":" .. total .. ":" .. str:sub((n - 1) * 238 + 1, n * 238) end
        return out
    end
    local s1, s2 = AS:Serialize({ _type = "SYNC_DATA", a = string.rep("a", 600) }), AS:Serialize({ _type = "ORDER_NEW", b = string.rep("b", 500) })
    local c1, c2 = chunked(41, s1), chunked(42, s2)
    got = {}
    deliver({ c2[3], c1[1], c2[1], c1[3], c1[2], c2[2] })
    EXPECT(#got == 2 and got[1].msg == s1 and got[2].msg == s2, "interleaved: " .. #got)
    -- malformed and out-of-range headers are ignored; AceComm's own chunks are not ours
    got = {}
    deliver({ "\005x:1:2:abc", "\0057:3:2:abc", "\0057:0:2:abc", "\0057:1:1001:abc",
              "\0057:1:1:" .. string.rep("z", 239), "\001plain AceComm first chunk" })
    EXPECT(#got == 0 and (Comm._chunkIn == nil or next(Comm._chunkIn) == nil), "a bad chunk was held or delivered")
    -- a missing chunk: nothing is delivered, and the partial goes after a minute idle
    local realGetTime = GetTime
    local clock = 5000
    GetTime = function() return clock end
    got = {}
    deliver({ c1[1], c1[2] })
    EXPECT(#got == 0 and Comm._chunkIn["Pal Friend\tWHISPER"].held == 2, "partial message not held")
    clock = clock + 61
    deliver({ c2[1] })
    local box = Comm._chunkIn["Pal Friend\tWHISPER"]
    EXPECT(box.msgs[41] == nil and box.msgs[42] and box.held == 1, "idle partial not dropped")
    deliver({ c1[3] })                        -- the dropped message's last chunk alone
    EXPECT(#got == 0, "a dropped partial was delivered")
    -- caps: 4 unfinished messages per sender (the oldest goes), 16 senders
    Comm._chunkIn = nil
    for id = 1, 5 do clock = clock + 1; deliver({ "\005" .. id .. ":1:2:x" }) end
    box = Comm._chunkIn["Pal Friend\tWHISPER"]
    local held = 0
    for _ in pairs(box.msgs) do held = held + 1 end
    EXPECT(held == 4 and box.msgs[1] == nil and box.msgs[5] and box.held == 4, "per-sender cap: " .. held)
    Comm._chunkIn = nil
    for i = 1, 17 do deliver({ "\0051:1:2:x" }, "Stranger" .. i) end
    local senders = 0
    for _ in pairs(Comm._chunkIn) do senders = senders + 1 end
    EXPECT(senders == 16 and Comm._chunkIn["Stranger17\tWHISPER"] == nil, "sender cap: " .. senders)
    -- held chunks for one sender are capped: at 1200 the message still
    -- growing is dropped, the other stays
    Comm._chunkIn = nil
    got = {}
    for n = 1, 999 do deliver({ "\0051:" .. n .. ":1000:x" }, "Flood") end
    for n = 1, 201 do deliver({ "\0052:" .. n .. ":1000:x" }, "Flood") end
    box = Comm._chunkIn and Comm._chunkIn["Flood\tWHISPER"]
    EXPECT(box and box.held == 1200 and box.msgs[2], "held before the cap: " .. tostring(box and box.held))
    deliver({ "\0052:202:1000:x" }, "Flood")
    EXPECT(#got == 0 and box.msgs[2] == nil and box.msgs[1] and box.held == 999, "held cap: " .. tostring(box.held))
    Comm._chunkIn = nil
    GetTime = realGetTime
    Comm.OnMessageReceived = realRecv
end
print("  PASS F31 numbered chunks: a long message is numbered through ChatThrottleLib and joined by number in any order, duplicates and bad headers ignored, idle partials dropped, per-sender and sender caps")

-- F32: WoW: Forever names carry no realm (COMM_REV 10). The beta has
-- connected realms and every sender arrives as "First Surname", so PB's
-- keys take one fixed realm half ("Forever"): the same player is the same
-- key on every client. Whispers never carry a realm. Saved keys move once,
-- with a backup the player restores or clears (/pb realmkeys).
do
    local NK = function(k) return ProfBuddy:NormKey(k) end
    for _, k in ipairs({ "Snorlax Trainer", "Snorlax Trainer-ClassicBetaPvP", "Snorlax Trainer-ClassicBetaPvP2",
                         "Snorlax Trainer-Classic Beta PvP 2" }) do
        EXPECT(NK(k) == "Snorlax Trainer-Forever", "NormKey(" .. k .. ") = " .. tostring(NK(k)))
    end
    EXPECT(ProfBuddy:SameKey("Snorlax Trainer-ClassicBetaPvP", "Snorlax Trainer-ClassicBetaPvP2"), "the same player on two realms")
    EXPECT(not ProfBuddy:SameKey("Snorlax Trainer", "Snorlax Other"), "two players matched")
    EXPECT(ProfBuddy:PlayerKey():match("%-Forever$"), "PlayerKey " .. ProfBuddy:PlayerKey())
    -- whispers: never a realm
    local Comm = ProfBuddy.Comm
    local sentTo = {}
    local realSend = Comm.Send
    Comm.Send = function(_, t, d, chan, target) sentTo[#sentTo + 1] = target end
    Comm:SendWhisper("SYNC_REQ", {}, "Snorlax Trainer-ClassicBetaPvP2")
    Comm:SendWhisper("SYNC_REQ", {}, "Snorlax Trainer-Forever")
    Comm:SendWhisper("SYNC_REQ", {}, "Snorlax Trainer")
    Comm.Send = realSend
    EXPECT(sentTo[1] == "Snorlax Trainer" and sentTo[2] == "Snorlax Trainer" and sentTo[3] == "Snorlax Trainer",
           "whisper targets: " .. table.concat(sentTo, " / "))

    -- the one-time move, on a saved-data table as the old build left it
    local realDB = ProfBuddyDB
    local function oldData()
        return {
            settings = realDB.settings,
            characters = {
                ["Me Surname-ClassicBetaPvP"] = { professions = { Tailoring = {} }, lastScan = 50 },
                ["Snorlax Trainer-ClassicBetaPvP"] = { isRemote = true, lastSync = 5, professions = {} },
                ["Snorlax Trainer-ClassicBetaPvP2"] = { isRemote = true, lastSync = 9, professions = { Enchanting = {} } },
            },
            contacts = {
                -- the older copy holds the trust and auto-sync; the newer one says no to both
                ["Snorlax Trainer-ClassicBetaPvP"] = { trusted = true, autoSync = true, lastSync = 5 },
                ["Snorlax Trainer-ClassicBetaPvP2"] = { trusted = false, autoSync = false, lastSync = 9 },
                ["Shreks Swamp-ClassicBetaPvP"] = { trusted = true, autoSync = false, lastSync = 1 },
            },
            favorites = { contacts = { ["Snorlax Trainer-ClassicBetaPvP"] = true }, items = { [2318] = true } },
            orders = { ["Me Surname-ClassicBetaPvP-3"] = { id = "Me Surname-ClassicBetaPvP-3",
                requester = "Me Surname-ClassicBetaPvP", crafter = "Snorlax Trainer-ClassicBetaPvP", status = "pending" } },
            orderBoard = { ["Shreks Swamp-ClassicBetaPvP-1"] = { id = "Shreks Swamp-ClassicBetaPvP-1", requester = "Shreks Swamp-ClassicBetaPvP" } },
            orderOutbox = { tok = { target = "Snorlax Trainer-ClassicBetaPvP",
                data = { order = { requester = "Me Surname-ClassicBetaPvP", crafter = "Snorlax Trainer-ClassicBetaPvP" } } } },
            knowledge = { [2153] = { seenBy = { ["*"] = true, ["Me Surname-ClassicBetaPvP"] = true } } },
            knowledgeShared = { ["Alpha Stone-ClassicBetaPvP"] = { at = 5 }, ["Alpha Stone-ClassicBetaPvP2"] = { at = 9 } },
        }
    end
    local said = {}
    local realPrint = print
    local function run(fn, ...) said = {}; print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
        fn(...); print = realPrint end
    local db = oldData()
    ProfBuddyDB = db
    run(function() ProfBuddy:MigrateForeverRealms() end)
    local c, ct = db.characters, db.contacts
    EXPECT(c["Me Surname-Forever"] and c["Me Surname-Forever"].lastScan == 50, "own character not moved")
    EXPECT(c["Snorlax Trainer-Forever"] and c["Snorlax Trainer-Forever"].lastSync == 9
           and c["Snorlax Trainer-Forever"].professions.Enchanting, "the newer copy of Snorlax did not win")
    EXPECT(not c["Snorlax Trainer-ClassicBetaPvP"] and not c["Snorlax Trainer-ClassicBetaPvP2"], "old character keys left")
    EXPECT(ct["Snorlax Trainer-Forever"].trusted and ct["Snorlax Trainer-Forever"].autoSync == true
           and ct["Snorlax Trainer-Forever"].lastSync == 9, "contacts not merged (trust and auto-sync kept)")
    EXPECT(ct["Shreks Swamp-Forever"] and ct["Shreks Swamp-Forever"].trusted, "contact not moved")
    EXPECT(db.favorites.contacts["Snorlax Trainer-Forever"] and db.favorites.items[2318], "favorites")
    local o = db.orders["Me Surname-ClassicBetaPvP-3"]
    EXPECT(o and o.requester == "Me Surname-Forever" and o.crafter == "Snorlax Trainer-Forever", "order fields")
    EXPECT(db.orderBoard["Shreks Swamp-ClassicBetaPvP-1"].requester == "Shreks Swamp-Forever", "board post requester")
    EXPECT(db.orderOutbox.tok.target == "Snorlax Trainer-Forever"
           and db.orderOutbox.tok.data.order.crafter == "Snorlax Trainer-Forever", "outbox")
    EXPECT(db.knowledge[2153].seenBy["*"] and db.knowledge[2153].seenBy["Me Surname-Forever"]
           and not db.knowledge[2153].seenBy["*-Forever"], "seenBy (everyone mark kept)")
    EXPECT(db.knowledgeShared["Alpha Stone-Forever"].at == 9 and not db.knowledgeShared["Alpha Stone-ClassicBetaPvP"], "shared knowledge")
    EXPECT(#said == 1 and said[1]:find("saved names updated, 2 duplicates merged", 1, true)
           and said[1]:find("/pb realmkeys", 1, true), "move message: " .. tostring(said[1]))
    local b = db.realmKeyBackup
    EXPECT(b and b.characters["Snorlax Trainer-ClassicBetaPvP2"] and b.contacts["Shreks Swamp-ClassicBetaPvP"]
           and b.orders["Me Surname-ClassicBetaPvP-3"].crafter == "Snorlax Trainer-ClassicBetaPvP", "backup is not the old data")
    -- again: nothing to move, no message, the backup is the same one
    run(function() ProfBuddy:MigrateForeverRealms() end)
    EXPECT(#said == 0 and db.realmKeyBackup == b, "second run was not a no-op")
    -- /pb realmkeys shows it, restore puts the old data back and stops the move
    run(SlashCmdList.PROFBUDDY, "realmkeys")
    EXPECT(said[1] and said[1]:find("backup of your saved data", 1, true), "status: " .. tostring(said[1]))
    run(SlashCmdList.PROFBUDDY, "realmkeys restore")
    EXPECT(db.characters["Snorlax Trainer-ClassicBetaPvP2"] and not db.characters["Snorlax Trainer-Forever"]
           and db.realmKeysRestored and db.realmKeyBackup == nil and said[1]:find("go back to the previous build", 1, true),
           "restore: " .. tostring(said[1]))
    run(function() ProfBuddy:MigrateForeverRealms() end)
    EXPECT(#said == 0 and db.characters["Snorlax Trainer-ClassicBetaPvP2"], "moved again after a restore")
    -- clear
    db = oldData()
    ProfBuddyDB = db
    run(function() ProfBuddy:MigrateForeverRealms() end)
    run(SlashCmdList.PROFBUDDY, "realmkeys clear")
    EXPECT(db.realmKeyBackup == nil and said[1]:find("backup deleted", 1, true)
           and db.characters["Snorlax Trainer-Forever"], "clear: " .. tostring(said[1]))
    -- saved data with nothing to move: no backup, no message
    db = { settings = realDB.settings, characters = { ["Me Surname-Forever"] = {} }, contacts = {} }
    ProfBuddyDB = db
    run(function() ProfBuddy:MigrateForeverRealms() end)
    EXPECT(#said == 0 and db.realmKeyBackup == nil, "a backup with nothing to move")
    ProfBuddyDB = realDB
end
print("  PASS F32 Forever names carry no realm: one key per player across connected realms, whispers without a realm, saved names moved once with duplicates merged and a backup to restore or clear")

-- F33: Phase 3b-1, gathering tooltips on WoW: Forever (m4ru's /pbt tip
-- check, 2026-10-02). Ore veins and herbs: the game names the profession
-- but not the skill, so PB reads the node name and looks it up in
-- Data/Forever/Gather.lua (Classic-era nodes only). Corpses: the game's own
-- "Skinnable" line marks a skinnable corpse but never says whether your
-- skill is enough, so PB adds "Requires Skinning (N)" from the mob's level
-- (level 18 -> 80, level 19 -> 90: the edge he checked in game).
do
    local MN, HN = ProfBuddy.MiningNodes, ProfBuddy.HerbNodes
    EXPECT(MN and MN["Copper Vein"] == 1 and MN["Tin Vein"] == 65 and MN["Small Thorium Vein"] == 245, "mining nodes")
    EXPECT(HN and HN["Earthroot"] == 15 and HN["Peacebloom"] == 1 and HN["Black Lotus"] == 300, "herb nodes")
    EXPECT(not MN["Fel Iron Deposit"] and not MN["Khorium Vein"] and not HN["Felweed"] and not HN["Bloodthistle"],
           "Outland or Eversong nodes in the Forever table")
    -- the mob list is Forever's Classic-era one (3b-2), never TBC's
    EXPECT(ProfBuddy.SkinnableMobs and ProfBuddy.SkinnableMobs[18205] == nil and ProfBuddy.MineableMobs == nil
           and ProfBuddy.HerbableMobs == nil, "TBC mob data loaded on Forever")

    -- an ore vein out of combat: the game's red "Requires Mining" becomes PB's line
    local onUpdate = GameTooltip._h.OnUpdate
    local left = {}
    for i = 1, 3 do
        left[i] = CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(left[i], "SetText", function(self, t) self._text = t end)
    end
    local n = 2
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return n end)
    local added = {}
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "Show", function() end)
    left[1]._text, left[2]._text = "Copper Vein", "Requires Mining"
    onUpdate(GameTooltip, 1)
    EXPECT(left[2]._text:find("Requires Mining (1)", 1, true), "vein line: " .. tostring(left[2]._text))
    EXPECT(added[1] and added[1]:find("Your Mining: ", 1, true), "vein extra line: " .. tostring(added[1]))
    left[1]._text, left[2]._text = "Earthroot", "Requires Herbalism"
    added = {}
    onUpdate(GameTooltip, 1)
    EXPECT(left[2]._text:find("Requires Herbalism (15)", 1, true), "herb line: " .. tostring(left[2]._text))
    -- a node PB does not know stays the game's
    left[1]._text, left[2]._text = "Mystery Vein", "Requires Mining"
    onUpdate(GameTooltip, 1)
    EXPECT(left[2]._text == "Requires Mining", "an unknown node changed: " .. tostring(left[2]._text))
    rawset(GameTooltip, "NumLines", nil); rawset(GameTooltip, "GetItem", nil)

    -- corpses, through the unit tooltip post-call
    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    EXPECT(post, "no unit tooltip post-call on Forever")
    local real = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                   UnitGUID = UnitGUID, UnitLevel = UnitLevel }
    local mob = { dead = true, level = 19, npc = 4129 }
    UnitExists = function() return true end
    UnitCanAttack = function() return not mob.dead end
    UnitIsDead = function() return mob.dead end
    UnitGUID = function() return "Creature-0-1-2-3-" .. mob.npc .. "-0000" end
    UnitLevel = function() return mob.level end
    rawset(GameTooltip, "GetUnit", function() return "Mob", "mouseover" end)
    local function hover(lines, tip)
        added = {}
        local data = { type = Enum.TooltipDataType.Unit, lines = {} }
        for i, t in ipairs(lines) do data.lines[i] = { leftText = t } end
        post(tip or GameTooltip, data)
        return table.concat(added, " / ")
    end
    local skinnable = { "Hecklefang Snarler", "Level 19", "Corpse", "Skinnable" }
    local got = hover(skinnable)
    EXPECT(got:find("Requires Skinning (90)", 1, true) and got:find("Your Skinning: ", 1, true), "level 19 corpse: " .. got)
    mob.level = 18
    EXPECT(hover(skinnable):find("Requires Skinning (80)", 1, true), "level 18 corpse")
    mob.level = 8
    EXPECT(hover(skinnable):find("Requires Skinning (1)", 1, true), "level 8 corpse")
    EXPECT(hover({ "Razormane Dustrunner", "Level 8", "Corpse" }) == "", "a corpse the game does not mark skinnable")
    mob.dead, mob.npc = false, 3114
    EXPECT(hover({ "Razormane Battleguard", "Level 8", "Humanoid" }) == "", "a live mob off the list got lines")
    mob.dead, mob.npc = true, 4129
    local other = CreateFrame("GameTooltip", "ShoppingTooltip9", UIParent)
    rawset(other, "GetUnit", function() return "Mob", "mouseover" end)
    rawset(other, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(other, "Show", function() end)
    EXPECT(hover(skinnable, other) == "", "lines on a tooltip other than GameTooltip")
    ProfBuddyDB.settings.gatherSkillTooltip = false
    EXPECT(hover(skinnable) == "", "lines with the gather tooltip setting off")
    ProfBuddyDB.settings.gatherSkillTooltip = true
    -- a secret line is skipped without an error
    local SECRET = newproxy(true)
    getmetatable(SECRET).__index = function() error("secret indexed") end
    issecretvalue = function(v) return rawequal(v, SECRET) end
    local realType = type
    type = function(v) if rawequal(v, SECRET) then return "string" end return realType(v) end
    local okS, errS = pcall(post, GameTooltip, { type = Enum.TooltipDataType.Unit, lines = { { leftText = SECRET } } })
    -- a hidden mob GUID: no NPC ID, the game's line still gives the corpse
    UnitGUID = function() return SECRET end
    local okG, gotG = pcall(hover, skinnable)
    type = realType
    issecretvalue = nil
    EXPECT(okS, "secret line: " .. tostring(errS))
    EXPECT(okG and gotG:find("Requires Skinning (1)", 1, true), "secret GUID: " .. tostring(gotG))
    for k, v in pairs(real) do _G[k] = v end
    rawset(GameTooltip, "GetUnit", nil); rawset(GameTooltip, "AddLine", nil); rawset(GameTooltip, "Show", nil)
end
print("  PASS F33 gathering tooltips: Forever node table (Classic nodes only), vein and herb lines from it, corpse Requires Skinning from the level only when the game says Skinnable")

local fb = {}
for k in pairs(FALLBACK) do fb[#fb + 1] = k end
table.sort(fb)
print("  INFO globals PB touched that this stub does not model: " .. table.concat(fb, ", "))
-- F34: in a dungeon WoW: Forever hands the tooltip's unit back as a secret
-- value, and the unit API refuses a secret argument from addon code
-- (UnitExists, a friend's error, 2026-10-02). PB falls back to "mouseover"; a secret
-- GUID or level ends the lines instead of an error.
do
    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    local SECRET = newproxy(true)
    getmetatable(SECRET).__index = function() error("secret indexed") end
    local real = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                   UnitGUID = UnitGUID, UnitLevel = UnitLevel }
    local mob = { dead = true, level = 8 }
    local seen = {}
    local function plain(fn)
        return function(...)
            for i = 1, select("#", ...) do
                if rawequal(select(i, ...), SECRET) then
                    error("bad argument #" .. i .. ": Secret values are only allowed during untainted execution")
                end
            end
            seen[#seen + 1] = (select(1, ...))
            return fn(...)
        end
    end
    UnitExists = plain(function() return true end)
    UnitCanAttack = plain(function() return not mob.dead end)
    UnitIsDead = plain(function() return mob.dead end)
    UnitGUID = plain(function() return SECRET end)          -- identity restricted
    UnitLevel = plain(function() return mob.level end)
    issecretvalue = function(v) return rawequal(v, SECRET) end
    local realType = type
    type = function(v) if rawequal(v, SECRET) then return "string" end return realType(v) end
    local added = {}
    rawset(GameTooltip, "GetUnit", function() return SECRET, SECRET, SECRET end)
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "Show", function() end)
    local function hover(lines)
        added = {}
        local data = { type = Enum.TooltipDataType.Unit, guid = SECRET, lines = {} }
        for i, t in ipairs(lines) do data.lines[i] = { leftText = t } end
        local ok, err = pcall(post, GameTooltip, data)
        return ok, ok and table.concat(added, " / ") or tostring(err)
    end
    local ok1, got1 = hover({ "Blackfathom Snapper", "Level 8", "Corpse", "Skinnable" })
    local ok2, got2 = hover({ "Blackfathom Tide Priestess", "Level 8", "Humanoid" })
    mob.dead = false
    local ok3, got3 = hover({ "Blackfathom Snapper", "Level 8", "Beast" })
    mob.dead, mob.level = true, SECRET
    local ok4, got4 = hover({ "Blackfathom Snapper", "Level ??", "Corpse", "Skinnable" })
    type = realType
    issecretvalue = nil
    for k, v in pairs(real) do _G[k] = v end
    for _, k in ipairs({ "GetUnit", "AddLine", "Show" }) do rawset(GameTooltip, k, nil) end
    EXPECT(ok1 and got1:find("Requires Skinning (1)", 1, true), "dungeon corpse: " .. got1)
    EXPECT(ok2 and got2 == "", "dungeon corpse the game does not mark: " .. got2)
    EXPECT(ok3 and got3 == "", "dungeon live mob: " .. got3)
    EXPECT(ok4 and got4 == "", "secret level: " .. got4)
    for _, u in ipairs(seen) do EXPECT(u == "mouseover" or u == "player", "unit passed: " .. tostring(u)) end
end
print("  PASS F34 dungeon tooltips: a secret tooltip unit falls back to mouseover, a secret GUID or level adds nothing, no Lua error")

-- F35: Phase 3b-2, the Classic-era mob list and skinning loot on WoW:
-- Forever (VMaNGOS at 1.12, tools/gather_db.py --source classic). A live
-- mob on the list gets the Requires line and the loot, headed as Classic
-- data; on a corpse the game's "Skinnable" line decides: without it no
-- line (already skinned, or Forever differs), with it the lines even for
-- a mob the list misses.
do
    local SM, SL, ST, SI = ProfBuddy.SkinnableMobs, ProfBuddy.SkinLoot, ProfBuddy.SkinLootTables, ProfBuddy.SkinItems
    -- the mobs m4ru checked in game (2026-10-02), and two Wowhead Classic calls
    EXPECT(SM[3130] and SM[3247] and SM[4129] and SM[4342], "skinnable mobs missing from the Classic list")
    EXPECT(not SM[3113] and not SM[3114] and not SM[2565], "a mob that cannot be skinned is on the list")
    EXPECT(ProfBuddy.SkinLootSource == "Classic", "loot source: " .. tostring(ProfBuddy.SkinLootSource))
    local n = 0
    for npc, idx in pairs(SL) do
        n = n + 1
        EXPECT(SM[npc] and type(ST[idx]) == "table" and #ST[idx] > 0, "loot for npc " .. npc)
        for _, e in ipairs(ST[idx]) do
            EXPECT(SI[e[1]] and e[2] >= 1 and e[2] <= 100 and e[3] >= 1 and e[4] >= e[3], "loot row for npc " .. npc)
        end
    end
    for npc in pairs(SM) do EXPECT(SL[npc], "skinnable npc " .. npc .. " has no loot") end
    EXPECT(n > 800, "only " .. n .. " mobs with loot")
    EXPECT(SI[2318] and SI[2318][1] == "Light Leather", "Light Leather")

    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    local real = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                   UnitGUID = UnitGUID, UnitLevel = UnitLevel }
    local mob = { dead = false, level = 10, npc = 3130 }
    UnitExists = function() return true end
    UnitCanAttack = function() return not mob.dead end
    UnitIsDead = function() return mob.dead end
    UnitGUID = function() return "Creature-0-1-2-3-" .. mob.npc .. "-0000" end
    UnitLevel = function() return mob.level end
    local added = {}
    rawset(GameTooltip, "GetUnit", function() return "Mob", "mouseover" end)
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "AddDoubleLine", function(_, l, r) added[#added + 1] = l .. " = " .. r end)
    rawset(GameTooltip, "Show", function() end)
    local function hover(lines)
        added = {}
        local data = { type = Enum.TooltipDataType.Unit, lines = {} }
        for i, t in ipairs(lines) do data.lines[i] = { leftText = t } end
        post(GameTooltip, data)
        return table.concat(added, " / ")
    end
    local lizard = ST[SL[3130]]
    local first = SI[lizard[1][1]][1]

    -- a live Thunder Lizard: the Requires line, then its loot, marked Classic
    local got = hover({ "Thunder Lizard", "Level 10", "Beast" })
    EXPECT(got:find("Requires Skinning (1)", 1, true) and got:find("Your Skinning: 43", 1, true), "live lizard: " .. got)
    EXPECT(got:find("Skins into (Classic data):", 1, true) and got:find(first, 1, true)
           and got:find(lizard[1][2] .. "%", 1, true), "live lizard loot: " .. got)
    -- a live level-19 Hecklefang Snarler: the edge he checked in game
    mob.npc, mob.level = 4129, 19
    EXPECT(hover({ "Hecklefang Snarler", "Level 19", "Beast" }):find("Requires Skinning (90)", 1, true), "live snarler")
    -- its corpse: lines while the game says Skinnable, none once it stops
    mob.dead = true
    EXPECT(hover({ "Hecklefang Snarler", "Level 19", "Corpse", "Skinnable" }):find("Skins into (Classic data):", 1, true),
           "skinnable corpse")
    EXPECT(hover({ "Hecklefang Snarler", "Level 19", "Corpse" }) == "", "a corpse the game no longer marks skinnable")
    -- a corpse the list misses but the game marks: the Requires line, no loot
    mob.npc, mob.level = 999999, 12
    got = hover({ "Mystery Beast", "Level 12", "Corpse", "Skinnable" })
    EXPECT(got:find("Requires Skinning (20)", 1, true) and not got:find("Skins into", 1, true), "unlisted corpse: " .. got)
    -- the loot setting off keeps the Requires line
    mob.npc, mob.level, mob.dead = 3130, 10, false
    ProfBuddyDB.settings.gatherYieldTooltip = false
    got = hover({ "Thunder Lizard", "Level 10", "Beast" })
    ProfBuddyDB.settings.gatherYieldTooltip = nil
    EXPECT(got:find("Requires Skinning (1)", 1, true) and not got:find("Skins into", 1, true), "loot setting off: " .. got)
    for k, v in pairs(real) do _G[k] = v end
    for _, k in ipairs({ "GetUnit", "AddLine", "AddDoubleLine", "Show" }) do rawset(GameTooltip, k, nil) end
end
print("  PASS F35 Classic-era mob list: live mobs on it get Requires Skinning and their loot headed as Classic data, the game's Skinnable line decides on a corpse")

-- F36: Phase 3b-3, skinning loot learned as you skin. A loot window that
-- opens within 3 s of a Skinning cast succeeding (Forever's Skinning
-- spells 8613, 8617, 8618, 10768), or while that cast is under way, is the
-- skin's: each item is counted under the NPC ID the game names as the
-- loot's source, else the corpse the cast started on. Anything else is
-- left alone, and a secret value records nothing.
do
    local KN = ProfBuddy.Knowledge
    local real = { GetTime = GetTime, UnitGUID = UnitGUID, UnitIsDead = UnitIsDead,
                   GetNumLootItems = GetNumLootItems, GetLootSlotLink = GetLootSlotLink,
                   GetLootSlotInfo = GetLootSlotInfo, GetLootSourceInfo = GetLootSourceInfo }
    local now = 2000
    GetTime = function() return now end
    local corpse = "Creature-0-1-2-3-3130-0000AAAA"
    UnitGUID = function(u) if u == "mouseover" then return corpse end return "Player-1-00000001" end
    UnitIsDead = function(u) return u == "mouseover" end
    local slots, source = {}, "Creature-0-1-2-3-3130-0000BBBB"
    GetNumLootItems = function() return #slots end
    GetLootSlotLink = function(i) local e = slots[i]; return e and e.link end
    GetLootSlotInfo = function(i) local e = slots[i]; return 134251, e.name, e.qty, nil, e.q end
    GetLootSourceInfo = function() return source, 1 end
    local function item(id, name, qty) return { link = "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r", name = name, qty = qty, q = 1 } end
    local function cast(event, spell) FIRE(event, "player", "Cast-1", spell) end
    local function skin(loot, spell)
        cast("UNIT_SPELLCAST_START", spell or 8613)
        now = now + 2
        cast("UNIT_SPELLCAST_SUCCEEDED", spell or 8613)
        now = now + 0.5
        slots = loot
        FIRE("LOOT_OPENED", false, false)
        now = now + 10
    end
    ProfBuddyDB.skinLoot = nil
    skin({ item(2934, "Ruined Leather Scraps", 1), { name = "4 Copper", qty = 0 } })
    local rec = ProfBuddyDB.skinLoot and ProfBuddyDB.skinLoot[3130]
    EXPECT(rec and rec.n == 1 and rec.items[2934] and rec.items[2934].c == 1 and rec.items[2934].name == "Ruined Leather Scraps",
           "first skin not recorded")
    EXPECT(rec.seenBy[ProfBuddy:PlayerKey()] and rec.at, "seen by / at")
    -- one item in two slots counts once, both stacks together
    skin({ item(2318, "Light Leather", 1), item(2318, "Light Leather", 2) })
    EXPECT(rec.n == 2 and rec.items[2318].c == 1 and rec.items[2318].min == 3 and rec.items[2318].max == 3, "two stacks")
    -- normal corpse loot, another spell, a late window, a failed cast: nothing
    slots = { item(2318, "Light Leather", 1) }
    FIRE("LOOT_OPENED", false, false)
    skin({ item(2318, "Light Leather", 1) }, 2575)
    cast("UNIT_SPELLCAST_START", 8613); now = now + 2; cast("UNIT_SPELLCAST_SUCCEEDED", 8613)
    now = now + 4; slots = { item(2318, "Light Leather", 1) }; FIRE("LOOT_OPENED", false, false); now = now + 10
    cast("UNIT_SPELLCAST_START", 8617); now = now + 1; cast("UNIT_SPELLCAST_INTERRUPTED", 8617)
    slots = { item(2318, "Light Leather", 1) }; FIRE("LOOT_OPENED", false, false); now = now + 10
    EXPECT(rec.n == 2, "a window that was not a skin's was recorded: n = " .. rec.n)
    -- the loot window before the success: recorded once, the success after
    -- it does not claim the next window
    cast("UNIT_SPELLCAST_START", 8618); now = now + 1.5
    slots = { item(2318, "Light Leather", 1) }; FIRE("LOOT_OPENED", false, false)
    now = now + 0.2; cast("UNIT_SPELLCAST_SUCCEEDED", 8618); now = now + 1
    FIRE("LOOT_OPENED", false, false); now = now + 10
    EXPECT(rec.n == 3 and rec.items[2318].c == 2, "loot before success: n = " .. rec.n)
    -- no GetLootSourceInfo: the corpse under the cursor at the cast's start
    GetLootSourceInfo = nil
    corpse = "Creature-0-1-2-3-3247-0000CCCC"
    skin({ item(4232, "Medium Hide", 1) })
    EXPECT(ProfBuddyDB.skinLoot[3247] and ProfBuddyDB.skinLoot[3247].n == 1, "mouseover fallback")
    -- a dungeon: the source is secret, nothing is recorded, no error
    local SECRET = newproxy(true)
    getmetatable(SECRET).__index = function() error("secret indexed") end
    issecretvalue = function(v) return rawequal(v, SECRET) end
    local realType = type
    type = function(v) if rawequal(v, SECRET) then return "string" end return realType(v) end
    GetLootSourceInfo = function() return SECRET, 1 end
    corpse = SECRET
    local before = 0
    for _ in pairs(ProfBuddyDB.skinLoot) do before = before + 1 end
    local okD, errD = pcall(skin, { item(2318, "Light Leather", 1) })
    type = realType
    issecretvalue = nil
    local after = 0
    for _ in pairs(ProfBuddyDB.skinLoot) do after = after + 1 end
    EXPECT(okD and not PRINTED("Skinning loot record failed") and after == before, "secret source: " .. tostring(errD))
    for k, v in pairs(real) do _G[k] = v end
end
print("  PASS F36 skinning loot learned as you skin: a Skinning cast's loot window (after it or during it) is counted per mob, nothing else is, the corpse at the cast's start stands in for the loot source, a secret source records nothing")

-- F37: the gather tooltip lists the learned loot once a mob has 10 skins,
-- yours and your friends' together ("Skins into (seen N times):"), else
-- the Classic list.
do
    local KN = ProfBuddy.Knowledge
    ProfBuddyDB.skinLoot = { [3130] = { n = 6, at = 1, seenBy = {}, items = {
        [2934] = { c = 4, min = 1, max = 1, name = "Ruined Leather Scraps", q = 0 },
        [2318] = { c = 2, min = 1, max = 2, name = "Light Leather", q = 1 } } } }
    EXPECT(KN:LearnedLoot(3130) == nil, "learned loot under 10 skins")
    ProfBuddyDB.knowledgeShared = ProfBuddyDB.knowledgeShared or {}
    ProfBuddyDB.knowledgeShared["Pal-Forever"] = { at = time(), since = 0, records = {},
        loot = { [3130] = { at = 1, n = 4, items = { [2318] = { c = 3, min = 1, max = 3 },
                                                     [999001] = { c = 1, min = 1, max = 1 } } } } }
    local n, rows = KN:LearnedLoot(3130)
    EXPECT(n == 10 and rows[1][1] == 2318 and rows[1][2] == 50 and rows[1][3] == 1 and rows[1][4] == 3
           and rows[2][1] == 2934 and rows[2][2] == 40 and rows[3][1] == 999001 and rows[3][2] == 10,
           "learned rows")
    ProfBuddyDB.knowledgeShared["Pal-Forever"].loot[3130].n = 3
    EXPECT(KN:LearnedLoot(3130) == nil, "learned loot at 9 skins")
    ProfBuddyDB.knowledgeShared["Pal-Forever"].loot[3130].n = 4

    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    local real = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                   UnitGUID = UnitGUID, UnitLevel = UnitLevel }
    UnitExists = function() return true end
    UnitCanAttack = function() return true end
    UnitIsDead = function() return false end
    UnitGUID = function() return "Creature-0-1-2-3-3130-0000" end
    UnitLevel = function() return 10 end
    local added = {}
    rawset(GameTooltip, "GetUnit", function() return "Mob", "mouseover" end)
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "AddDoubleLine", function(_, l, r) added[#added + 1] = l .. " = " .. r end)
    rawset(GameTooltip, "Show", function() end)
    local function hover()
        added = {}
        post(GameTooltip, { type = Enum.TooltipDataType.Unit, lines = { { leftText = "Thunder Lizard" } } })
        return table.concat(added, " / ")
    end
    local got = hover()
    EXPECT(got:find("Skins into (seen 10 times):", 1, true) and got:find("Light Leather|r  x1-3 = |cffc8b08850%", 1, true)
           and got:find("item:999001", 1, true) and not got:find("Classic data", 1, true), "learned tooltip: " .. got)
    ProfBuddyDB.knowledgeShared["Pal-Forever"] = nil
    got = hover()
    EXPECT(got:find("Skins into (Classic data):", 1, true), "under 10 skins: " .. got)
    for k, v in pairs(real) do _G[k] = v end
    for _, k in ipairs({ "GetUnit", "AddLine", "AddDoubleLine", "Show" }) do rawset(GameTooltip, k, nil) end
    ProfBuddyDB.skinLoot = nil
end
print("  PASS F37 learned loot replaces the Classic list at 10 skins (yours and friends' together), percents from skins, stacks from both")

-- F38: sharing skinning loot, and friends' professions (COMM_REV 11). A
-- KNOW_REQ asks for loot (s) and names the friend's professions before
-- ours; a profession or the loot not asked for before resets `since`. A
-- KNOW_DATA carries our loot only when asked, is sanitized and capped,
-- and a rev-10 reply leaves the loot to be asked for again.
do
    local KN, Comm = ProfBuddy.Knowledge, ProfBuddy.Comm
    local AS = LibStub("AceSerializer-3.0")
    local SENT = {}
    local realWhisper = Comm.SendWhisper
    Comm.SendWhisper = function(_, t, d, target, prio) SENT[#SENT + 1] = { t = t, d = d, to = target } end
    local function deliver(from, msg) Comm:OnMessageReceived("PBuddy", AS:Serialize(msg), "WHISPER", from) end
    local function last(t) for i = #SENT, 1, -1 do if SENT[i].t == t then return SENT[i] end end end
    local PAL = "Pal-Forever"
    ProfBuddyDB.contacts[PAL] = { trusted = true, autoSync = false, lastSync = 0 }
    ProfBuddyDB.knowledgeShared[PAL] = nil
    local sync = { _type = "SYNC_DATA", _commrev = 11, class = "MAGE", level = 20, faction = "Horde", partial = true,
                   professions = { Tailoring = { skillLevel = 50, maxSkill = 75, recipeNames = {} },
                                   Enchanting = { skillLevel = 40, maxSkill = 75, recipeNames = {} } } }
    deliver(PAL, sync)
    local req = last("KNOW_REQ")
    EXPECT(req and req.to == PAL and req.d.s == true and req.d.since == 0, "KNOW_REQ without s")
    local list = table.concat(req.d.profs, ",")
    EXPECT(list:find("^Enchanting,Tailoring,Cooking,") and select(2, list:gsub("Enchanting", "")) == 1,
           "KNOW_REQ profs: " .. list)

    -- our answer carries loot only when asked
    ProfBuddyDB.skinLoot = { [3130] = { n = 3, at = 4000, seenBy = {}, items = {
        [2934] = { c = 2, min = 1, max = 1, name = "Ruined Leather Scraps" },
        [2318] = { c = 1, min = 1, max = 2, name = "Light Leather" } } } }
    Comm._knowServed = {}
    deliver(PAL, { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" } })
    EXPECT(last("KNOW_DATA").d.s == nil, "loot sent unasked")
    Comm._knowServed = {}
    deliver(PAL, { _type = "KNOW_REQ", since = 0, profs = { "Leatherworking" }, s = true })
    local share = last("KNOW_DATA").d
    local l = share.s and share.s[3130]
    EXPECT(l and l.n == 3 and l.i[1][1] == 2934 and l.i[1][2] == 2 and l.i[2][1] == 2318 and l.i[2][4] == 2
           and l.i[1].name == nil, "loot on the wire")
    EXPECT(share.at >= 4000, "share at: " .. tostring(share.at))

    -- the round trip, as if Pal sent it
    Comm._knowPending[PAL] = time()
    Comm._knowAskedProfs = { [PAL] = req.d.profs }
    share._type, share._commrev = "KNOW_DATA", 12
    deliver(PAL, share)
    local fs = ProfBuddyDB.knowledgeShared[PAL]
    EXPECT(fs and fs.loot and fs.loot[3130] and fs.loot[3130].n == 3 and fs.loot[3130].items[2318].max == 2,
           "loot round trip")
    EXPECT(fs.asked.Enchanting and fs.asked.Tailoring and fs.askedLoot == true and fs.askedNodes == true, "asked state")
    local since = KN:RequestFor(PAL)
    EXPECT(since == fs.since and since > 0, "since kept for the same ask: " .. tostring(since))
    -- Pal learns a new profession: asked from 0 again
    ProfBuddyDB.characters[PAL].professions.Alchemy = { skillLevel = 1, maxSkill = 75, recipes = {} }
    EXPECT(KN:RequestFor(PAL) == 0, "a new profession kept since")
    ProfBuddyDB.characters[PAL].professions.Alchemy = nil
    -- a rev-11 reply (skinning loot, no node loot): asked again from 0
    Comm._knowPending[PAL] = time()
    Comm._knowAskedProfs = { [PAL] = req.d.profs }
    deliver(PAL, { _type = "KNOW_DATA", _commrev = 11, at = 4050, npcs = {}, r = {} })
    EXPECT(fs.askedLoot == true and fs.askedNodes == nil and KN:RequestFor(PAL) == 0, "a rev-11 reply counted as node loot asked")
    -- a rev-10 reply: the loot is asked for again from 0
    Comm._knowPending[PAL] = time()
    Comm._knowAskedProfs = { [PAL] = req.d.profs }
    deliver(PAL, { _type = "KNOW_DATA", _commrev = 10, at = 4100, npcs = {}, r = {} })
    EXPECT(fs.askedLoot == nil and KN:RequestFor(PAL) == 0, "a rev-10 reply counted as loot asked")

    -- sanitizing and caps
    local function tryLoot(s)
        ProfBuddyDB.knowledgeShared[PAL] = nil
        Comm._knowPending[PAL] = time()
        deliver(PAL, { _type = "KNOW_DATA", _commrev = 11, at = 4200, npcs = {}, r = {}, s = s })
        return ProfBuddyDB.knowledgeShared[PAL]
    end
    local many = {}
    for i = 1, 1501 do many[i] = { a = 1, n = 1, i = {} } end
    EXPECT(tryLoot(many) == nil, "1501 mobs were stored")
    local items = {}
    for i = 1, 13 do items[i] = { 2318, 1, 1, 1 } end
    EXPECT(tryLoot({ [3130] = { a = 1, n = 20, i = items } }) == nil, "13 items on one mob were stored")
    EXPECT(tryLoot("junk") == nil, "a non-table s was stored")
    local got = tryLoot({ [3130] = { a = 1, n = 5, i = { { 2318, 9, 0, 999 }, { "x" } } }, [0] = { n = 1, i = {} },
                         [3247] = { a = 1, n = 0, i = { { 2318, 1, 1, 1 } } } })
    local e = got and got.loot[3130] and got.loot[3130].items[2318]
    EXPECT(e and e.c == 5 and e.min == 1 and e.max == 200 and got.loot[0] == nil and got.loot[3247] == nil,
           "loot clamps")
    ProfBuddyDB.knowledgeShared[PAL] = nil
    ProfBuddyDB.contacts[PAL] = nil
    ProfBuddyDB.characters[PAL] = nil
    ProfBuddyDB.skinLoot = nil
    Comm.SendWhisper = realWhisper
end
print("  PASS F38 sharing: KNOW_REQ asks for loot and names the friend's professions first, since resets for a new profession or loot; loot sent only when asked, round trip stored, rev-10 reply asks again, caps and clamps")

-- F39: a known recipe that comes with the profession (learnFrom
-- "automatic") reads "Source: Learned with <profession>" when nothing was
-- seen for it; a recipe a trainer was seen teaching keeps the trainer.
do
    local TSF, st = ProfBuddy.TradeSkillFrame, ProfBuddy.TradeSkillFrame.state
    local SHOWN = {}
    rawset(TSF.detSource, "SetText", function(_, t) SHOWN.src = t end)
    C_TradeSkillUI.OpenTradeSkill(185)
    TS_LIST_READY()
    FLUSH()
    st.showTab, st.searchText = "known", ""
    TSF:RefreshRecipeList()
    st.selected = "Charred Wolf Meat"
    TSF:RefreshDetailPanel()
    EXPECT(SHOWN.src == "Source: |cff88ccffLearned with Cooking|r", "Charred Wolf Meat: " .. tostring(SHOWN.src))
    C_TradeSkillUI.OpenTradeSkill(393)
    TS_LIST_READY()
    FLUSH()
    st.showTab, st.searchText = "known", ""
    TSF:RefreshRecipeList()
    st.selected = "Camp Chair"
    TSF:RefreshDetailPanel()
    EXPECT(SHOWN.src and SHOWN.src:find("Trainer - Mooranta", 1, true), "Camp Chair: " .. tostring(SHOWN.src))
    rawset(TSF.detSource, "SetText", nil)
end
print("  PASS F39 a known starting recipe reads Source: Learned with <profession>; a seen trainer still wins")

-- F40: mobs known from play, and the game's other corpse lines (WoW:
-- Forever). A mob off the Classic list that you or a friend skinned gets
-- the Skinning lines while alive. A corpse reading "Requires Mining",
-- "Requires Herbalism" or "Requires Engineering" (Forever's GlobalStrings
-- UNIT_SKINNABLE_ROCK, _HERB, _BOLTS) gets that profession's lines from
-- its level, and a mob mined, gathered from or salvaged with Forever's
-- corpse spells (1235230, 1235236, 1235244) is remembered for its live
-- tooltip.
do
    local KN = ProfBuddy.Knowledge
    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    local real = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                   UnitGUID = UnitGUID, UnitLevel = UnitLevel, GetTime = GetTime,
                   GetNumLootItems = GetNumLootItems, GetLootSlotLink = GetLootSlotLink,
                   GetLootSlotInfo = GetLootSlotInfo, GetLootSourceInfo = GetLootSourceInfo }
    local mob = { dead = false, level = 30, npc = 777001 }
    UnitExists = function() return true end
    UnitCanAttack = function() return not mob.dead end
    UnitIsDead = function(u) return mob.dead end
    UnitGUID = function() return "Creature-0-1-2-3-" .. mob.npc .. "-0000" end
    UnitLevel = function() return mob.level end
    local added = {}
    rawset(GameTooltip, "GetUnit", function() return "Mob", "mouseover" end)
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "AddDoubleLine", function(_, l, r) added[#added + 1] = l .. " = " .. r end)
    rawset(GameTooltip, "Show", function() end)
    local function hover(lines)
        added = {}
        local data = { type = Enum.TooltipDataType.Unit, lines = {} }
        for i, t in ipairs(lines or { "Mob" }) do data.lines[i] = { leftText = t } end
        post(GameTooltip, data)
        return table.concat(added, " / ")
    end
    EXPECT(not ProfBuddy.SkinnableMobs[777001], "777001 is on the list")
    EXPECT(hover() == "", "an unknown live mob got lines")
    -- you skinned it once: live, it now reads Skinning (no loot list yet)
    ProfBuddyDB.skinLoot = { [777001] = { n = 1, at = 1, seenBy = {}, items = { [2318] = { c = 1, min = 1, max = 1 } } } }
    local got = hover()
    EXPECT(got:find("Requires Skinning (150)", 1, true) and not got:find("Skins into", 1, true), "skinned once: " .. got)
    -- a friend's skin counts the same
    ProfBuddyDB.skinLoot = nil
    ProfBuddyDB.knowledgeShared["Pal-Forever"] = { at = time(), since = 0, records = {},
        loot = { [777001] = { at = 1, n = 2, items = {} } } }
    EXPECT(hover():find("Requires Skinning (150)", 1, true), "a friend's skin")
    ProfBuddyDB.knowledgeShared["Pal-Forever"] = nil

    -- the game's other corpse lines
    mob.dead, mob.level = true, 12
    got = hover({ "Rock Thing", "Corpse", "Requires Mining" })
    EXPECT(got:find("Requires Mining (20)", 1, true) and got:find("Your Mining: ", 1, true), "mining corpse: " .. got)
    EXPECT(hover({ "Bog Thing", "Corpse", "Requires Herbalism" }):find("Requires Herbalism (20)", 1, true), "herb corpse")
    got = hover({ "Clank Thing", "Corpse", "Requires Engineering" })
    EXPECT(got:find("Requires Engineering (20)", 1, true), "engineering corpse: " .. got)
    ProfBuddyDB.settings.gatherShowUnlearned = false
    EXPECT(hover({ "Clank Thing", "Corpse", "Requires Engineering" }) == "", "unlearned Engineering shown with the setting off")
    ProfBuddyDB.settings.gatherShowUnlearned = nil
    EXPECT(hover({ "Rock Thing", "Corpse" }) == "", "a corpse with no game line")

    -- mining a mob with Forever's spell remembers it for the live tooltip
    local now = 3000
    GetTime = function() return now end
    UnitGUID = function() return "Creature-0-1-2-3-777002-0000" end
    GetNumLootItems = function() return 1 end
    GetLootSlotLink = function() return "|cffffffff|Hitem:2770::::::::|h[Copper Ore]|h|r" end
    GetLootSlotInfo = function() return 0, "Copper Ore", 2, nil, 1 end
    GetLootSourceInfo = function() return "Creature-0-1-2-3-777002-0000", 2 end
    FIRE("UNIT_SPELLCAST_START", "player", "Cast-9", 1235230); now = now + 2
    FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 1235230); now = now + 0.5
    FIRE("LOOT_OPENED", false, false); now = now + 10
    EXPECT(ProfBuddyDB.gatheredMobs and ProfBuddyDB.gatheredMobs[777002] == "Mining"
           and (ProfBuddyDB.skinLoot == nil or ProfBuddyDB.skinLoot[777002] == nil), "mined mob not remembered as Mining")
    FIRE("UNIT_SPELLCAST_START", "player", "Cast-10", 1235236); now = now + 2
    FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-10", 1235236); now = now + 0.5
    GetLootSourceInfo = function() return "Creature-0-1-2-3-777003-0000", 1 end
    FIRE("LOOT_OPENED", false, false); now = now + 10
    EXPECT(ProfBuddyDB.gatheredMobs[777003] == "Herbalism", "herb mob not remembered")
    mob.dead, mob.level, mob.npc = false, 30, 777002
    UnitGUID = function() return "Creature-0-1-2-3-" .. mob.npc .. "-0000" end
    got = hover()
    EXPECT(got:find("Requires Mining (150)", 1, true) and not got:find("Skins into", 1, true), "live mined mob: " .. got)
    -- its corpse with no game line: the game wins
    mob.dead = true
    EXPECT(hover({ "Rock Thing", "Corpse" }) == "", "a remembered mob's corpse with no game line")
    ProfBuddyDB.gatheredMobs = nil
    for k, v in pairs(real) do _G[k] = v end
    for _, k in ipairs({ "GetUnit", "AddLine", "AddDoubleLine", "Show" }) do rawset(GameTooltip, k, nil) end
end
print("  PASS F40 mobs known from play: a mob you or a friend skinned reads Skinning alive; Requires Mining / Herbalism / Engineering corpses get their lines; mobs mined or gathered with Forever's corpse spells are remembered for the live tooltip")

-- F41: /pb bug carries the last gathering tooltip PB added lines to
-- (ProfBuddyDB.lastGather): a node from the node hook with the game's own
-- line it replaced, a mob or corpse from the unit hook with why PB showed
-- it and where the loot came from. Written only when it changes.
do
    local real = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                   UnitGUID = UnitGUID, UnitLevel = UnitLevel, UnitName = UnitName, time = time }
    ProfBuddyDB.lastGather = nil
    -- a node, through the node hook
    local onUpdate = GameTooltip._h.OnUpdate
    local left = {}
    for i = 1, 3 do
        left[i] = CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(left[i], "SetText", function(self, t) self._text = t end)
        rawset(left[i], "GetText", function(self) return self._text end)
    end
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return 2 end)
    rawset(GameTooltip, "AddLine", function() end)
    rawset(GameTooltip, "AddDoubleLine", function() end)
    rawset(GameTooltip, "Show", function() end)
    left[1]._text, left[2]._text = "Tin Vein", "Requires Mining"
    onUpdate(GameTooltip, 1)
    local g = ProfBuddyDB.lastGather
    EXPECT(g and g.kind == "node" and g.name == "Tin Vein" and g.shown == "Requires Mining (65)"
           and g.gameLine == "Requires Mining" and g.why == "node table" and g.at == 5000, "node record")
    -- the next passes (the line is PB's now) keep the record and its game line
    time = function() return 6000 end
    onUpdate(GameTooltip, 1)
    EXPECT(ProfBuddyDB.lastGather == g and g.at == 5000 and g.gameLine == "Requires Mining", "rewritten on every pass")
    -- a skill-up mid-hover rewrites it; the game's line (gone from the
    -- tooltip by then) carries over
    g.yours = "Your Mining: 0"
    onUpdate(GameTooltip, 1)
    EXPECT(ProfBuddyDB.lastGather ~= g and ProfBuddyDB.lastGather.at == 6000
           and ProfBuddyDB.lastGather.gameLine == "Requires Mining", "game line after a rewrite")
    local text = ProfBuddy.BuildBugReport()
    EXPECT(text:find("  Node: Tin Vein", 1, true) and text:find("Why: node table; the game's line: Requires Mining", 1, true),
           "report: " .. text)
    rawset(GameTooltip, "NumLines", nil); rawset(GameTooltip, "GetItem", nil)

    -- a live mob on the list, then its corpse, through the unit hook
    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    local mob = { dead = false }
    UnitExists = function() return true end
    UnitCanAttack = function() return not mob.dead end
    UnitIsDead = function() return mob.dead end
    UnitGUID = function() return "Creature-0-1-2-3-3130-0000" end
    UnitLevel = function() return 10 end
    UnitName = function(u) if u == "mouseover" then return "Thunder Lizard" end return real.UnitName(u) end
    rawset(GameTooltip, "GetUnit", function() return "Thunder Lizard", "mouseover" end)
    post(GameTooltip, { type = Enum.TooltipDataType.Unit, lines = { { leftText = "Thunder Lizard" } } })
    g = ProfBuddyDB.lastGather
    EXPECT(g.kind == "mob" and g.name == "Thunder Lizard" and g.npcID == 3130 and g.level == 10
           and g.shown == "Requires Skinning (1)" and g.yours == "Your Skinning: 43" and g.why == "mob list"
           and g.loot == "Classic data" and g.at == 6000, "mob record")
    mob.dead = true
    post(GameTooltip, { type = Enum.TooltipDataType.Unit, lines = { { leftText = "Thunder Lizard" }, { leftText = "Skinnable" } } })
    g = ProfBuddyDB.lastGather
    EXPECT(g.kind == "corpse" and g.why == "the game's corpse line" and g.gameLine == "Skinnable", "corpse record")
    text = ProfBuddy.BuildBugReport()
    EXPECT(text:find("  Mob: Thunder Lizard (NPC 3130, level 10, corpse)", 1, true)
           and text:find("PB showed: Requires Skinning (1), Your Skinning: 43, loot from Classic data", 1, true)
           and text:find("Why: the game's corpse line; the game's line: Skinnable", 1, true), "report: " .. text)
    EXPECT(text:find("corpse)\n  Where: ", 1, true), "Where line: " .. text)
    -- the window builds with it: the editbox inside a scroll frame that
    -- clips it, opened at the top with the cursor at the start
    local made, realCreate = {}, CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local fr = realCreate(kind, name, parent, template)
        made[#made + 1] = { kind = kind, template = template, f = fr }
        rawset(fr, "SetScrollChild", function(self, c) self._child = c end)
        rawset(fr, "SetVerticalScroll", function(self, v) self._scroll = v end)
        rawset(fr, "SetCursorPosition", function(self, v) self._cursor = v end)
        rawset(fr, "SetText", function(self, t) self._text = t end)
        return fr
    end
    ProfBuddy.bugFrame = nil
    local ok, err = pcall(ProfBuddy.ShowBugReport, ProfBuddy)
    CreateFrame = realCreate
    EXPECT(ok, "bug window: " .. tostring(err))
    local bf = ProfBuddy.bugFrame
    local sf, eb = bf and bf.sf, bf and bf.eb
    local sfKind
    for _, m in ipairs(made) do if m.f == sf then sfKind = m.kind .. "/" .. tostring(m.template) end end
    EXPECT(sfKind == "ScrollFrame/UIPanelScrollFrameTemplate" and sf._child == eb and eb._parent == sf,
           "editbox not in a scroll frame: " .. tostring(sfKind))
    EXPECT(sf._scroll == 0 and eb._cursor == 0 and eb._text:find("Last gathering tooltip", 1, true),
           "window not opened at the top")
    if ProfBuddy.bugFrame then ProfBuddy.bugFrame:Hide() end
    for k, v in pairs(real) do _G[k] = v end
    for _, k in ipairs({ "GetUnit", "AddLine", "AddDoubleLine", "Show" }) do rawset(GameTooltip, k, nil) end
    ProfBuddyDB.lastGather = nil
end
print("  PASS F41 /pb bug: the last node, mob or corpse PB added gathering lines to, with what it showed, why, and the game's line; kept until it changes")

-- F42: Phase 3b-4, ore vein and herb loot learned as you gather. A Mining
-- or Herbalism cast (Forever's OPEN_LOCK spells) names its node from the
-- tooltip under the cursor, else from the node tooltip PB drew in the last
-- 10 s; its loot window counts under that name. In combat (secret
-- tooltip) or for a node PB does not know, nothing is recorded, and a node
-- is never taken for a mob.
do
    local real = { GetTime = GetTime, time = time, GetNumLootItems = GetNumLootItems,
                   GetLootSlotLink = GetLootSlotLink, GetLootSlotInfo = GetLootSlotInfo,
                   GetLootSourceInfo = GetLootSourceInfo, UnitIsDead = UnitIsDead }
    local now, clock = 7000, 9000
    GetTime = function() return now end
    time = function() return clock end
    UnitIsDead = function() return false end
    local slots = {}
    GetNumLootItems = function() return #slots end
    GetLootSlotLink = function(i) return slots[i].link end
    GetLootSlotInfo = function(i) return 0, slots[i].name, slots[i].qty, nil, 1 end
    GetLootSourceInfo = function() return "GameObject-0-1-2-3-1731-0000ABCD", 1 end
    local function item(id, name, qty) return { link = "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r", name = name, qty = qty } end
    local tl1 = _G.GameTooltipTextLeft1 or CreateFrame("Frame", "GameTooltipTextLeft1")
    rawset(tl1, "GetText", function(self) return self._text end)
    local shown = true
    rawset(GameTooltip, "IsShown", function() return shown end)
    local function gather(spell, loot)
        FIRE("UNIT_SPELLCAST_START", "player", "Cast-N", spell); now = now + 2
        FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-N", spell); now = now + 0.5
        slots = loot
        FIRE("LOOT_OPENED", false, false); now = now + 10
    end
    ProfBuddyDB.nodeLoot, ProfBuddyDB.gatheredMobs, ProfBuddyDB.lastGather = nil, nil, nil
    local mobsBefore = ProfBuddyDB.skinLoot

    tl1._text = "Copper Vein"
    gather(2575, { item(2770, "Copper Ore", 1), item(2835, "Rough Stone", 2) })
    local r = ProfBuddyDB.nodeLoot and ProfBuddyDB.nodeLoot["Copper Vein"]
    EXPECT(r and r.n == 1 and r.prof == "Mining" and r.items[2770].c == 1 and r.items[2835].max == 2
           and r.seenBy[ProfBuddy:PlayerKey()], "Copper Vein gather")
    gather(10248, { item(2770, "Copper Ore", 1) })
    EXPECT(r.n == 2 and r.items[2770].c == 2 and r.items[2835].c == 1, "a second gather (another Mining rank)")
    EXPECT(ProfBuddyDB.gatheredMobs == nil and ProfBuddyDB.skinLoot == mobsBefore, "a node taken for a mob")

    -- in combat the tooltip is secret: nothing, no error
    local SECRET = newproxy(true)
    getmetatable(SECRET).__index = function() error("secret indexed") end
    issecretvalue = function(v) return rawequal(v, SECRET) end
    local realType = type
    type = function(v) if rawequal(v, SECRET) then return "string" end return realType(v) end
    tl1._text = SECRET
    local okS, errS = pcall(gather, 2575, { item(2770, "Copper Ore", 1) })
    type = realType
    issecretvalue = nil
    EXPECT(okS and r.n == 2 and ProfBuddyDB.gatheredMobs == nil, "a secret node: " .. tostring(errS))

    -- the tooltip already gone: the node PB drew moments ago
    shown = false
    ProfBuddyDB.lastGather = { kind = "node", name = "Peacebloom", seen = clock - 3 }
    gather(2366, { item(2447, "Peacebloom", 2) })
    local h = ProfBuddyDB.nodeLoot["Peacebloom"]
    EXPECT(h and h.n == 1 and h.prof == "Herbalism", "Peacebloom from the last node tooltip")
    -- too old, or the wrong profession's node: nothing
    ProfBuddyDB.lastGather.seen = clock - 30
    gather(2366, { item(2447, "Peacebloom", 2) })
    shown = true
    tl1._text = "Peacebloom"
    gather(2575, { item(2447, "Peacebloom", 2) })
    tl1._text = "Mystery Vein"
    gather(2575, { item(2770, "Copper Ore", 1) })
    EXPECT(h.n == 1 and r.n == 2 and ProfBuddyDB.nodeLoot["Mystery Vein"] == nil, "a node that should not count")
    -- an unnamed node with a corpse under the cursor and no loot source
    -- from the game: still not taken for that mob
    GetLootSourceInfo = nil
    local realGUID = UnitGUID
    UnitIsDead = function() return true end
    UnitGUID = function() return "Creature-0-1-2-3-3130-0000" end
    gather(2575, { item(2770, "Copper Ore", 1) })
    UnitGUID = realGUID
    UnitIsDead = function() return false end
    EXPECT(ProfBuddyDB.gatheredMobs == nil, "an unnamed node recorded as a mob")
    rawset(GameTooltip, "IsShown", nil)
    for k, v in pairs(real) do _G[k] = v end
end
print("  PASS F42 ore vein and herb loot learned as you gather: named from the tooltip or the last node tooltip, counted per node name, nothing in combat or for an unknown node, never taken for a mob")

-- F43: the node tooltip gets its loot list (Classic data, or "seen N
-- times" at 10 gathers, yours and friends'), once per tooltip, under the
-- Requires line. Loot shows for professions you have; "Unlearned too"
-- (gatherLootUnlearned, off by default) shows it for the others, on beasts
-- as well; "Gathering loot" off hides all of it.
do
    EXPECT(ProfBuddy.NodeLoot and ProfBuddy.NodeLoot["Copper Vein"] and ProfBuddy.NodeItems[2770]
           and ProfBuddyDB.settings.gatherLootUnlearned == false, "node data or setting default")
    local cv = ProfBuddy.NodeLootTables[ProfBuddy.NodeLoot["Copper Vein"]]
    EXPECT(cv[1][1] == 2770 and cv[1][2] == 100, "Copper Vein's first row")
    local n = 0
    for name in pairs(ProfBuddy.MiningNodes) do n = n + 1; EXPECT(ProfBuddy.NodeLoot[name], "no loot for " .. name) end
    for name in pairs(ProfBuddy.HerbNodes) do n = n + 1; EXPECT(ProfBuddy.NodeLoot[name], "no loot for " .. name) end

    -- a tooltip whose lines the hook can read back, as the game's are
    local lines = {}
    for i = 1, 30 do
        local fs = _G["GameTooltipTextLeft" .. i] or CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(fs, "SetText", function(_, t) lines[i] = t end)
        rawset(fs, "GetText", function() return lines[i] end)
    end
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return #lines end)
    rawset(GameTooltip, "AddLine", function(_, t) lines[#lines + 1] = t end)
    rawset(GameTooltip, "AddDoubleLine", function(_, l, r) lines[#lines + 1] = l .. " = " .. r end)
    rawset(GameTooltip, "Show", function() end)
    local onUpdate = GameTooltip._h.OnUpdate
    local function hover(name, game, passes)
        lines = { name, game }
        for _ = 1, passes or 1 do onUpdate(GameTooltip, 1) end
        return table.concat(lines, " / ")
    end
    -- Mining is learned in the fixture: the Classic list, once over many passes
    local got = hover("Tin Vein", "Requires Mining", 5)
    local _, heads = got:gsub("Mines into %(Classic data%):", "")
    EXPECT(got:find("Requires Mining (65)", 1, true) and heads == 1 and got:find("Tin Ore", 1, true), "Tin Vein: " .. got)
    EXPECT(ProfBuddyDB.lastGather.loot == "Classic data", "the report's loot source: " .. tostring(ProfBuddyDB.lastGather.loot))
    -- Herbalism is not: no loot until "Unlearned too"
    got = hover("Peacebloom", "Requires Herbalism")
    EXPECT(got:find("Requires Herbalism (1)", 1, true) and not got:find("Gathers into", 1, true), "unlearned herb: " .. got)
    ProfBuddyDB.settings.gatherLootUnlearned = true
    got = hover("Peacebloom", "Requires Herbalism")
    EXPECT(got:find("Gathers into (Classic data):", 1, true) and got:find("Peacebloom|r  x1-3 = ", 1, true), "Unlearned too: " .. got)
    -- "Gathering loot" off: none
    ProfBuddyDB.settings.gatherYieldTooltip = false
    EXPECT(not hover("Tin Vein", "Requires Mining"):find("Mines into", 1, true), "loot with Gathering loot off")
    ProfBuddyDB.settings.gatherYieldTooltip = true
    ProfBuddyDB.settings.gatherLootUnlearned = false
    -- 10 gathers, yours and a friend's: what they gave
    ProfBuddyDB.nodeLoot = { ["Tin Vein"] = { n = 7, at = 1, seenBy = {}, prof = "Mining",
        items = { [2771] = { c = 7, min = 1, max = 2, name = "Tin Ore" }, [1206] = { c = 1, min = 1, max = 1 } } } }
    ProfBuddyDB.knowledgeShared["Pal-Forever"] = { at = time(), since = 0, records = {},
        nodeLoot = { ["Tin Vein"] = { at = 1, n = 3, prof = "Mining", items = { [2771] = { c = 3, min = 1, max = 1 } } } } }
    got = hover("Tin Vein", "Requires Mining", 3)
    EXPECT(got:find("Mines into (seen 10 times):", 1, true) and got:find("x1-2 = |cffc8b088100%", 1, true)
           and got:find("10%", 1, true) and not got:find("Classic data", 1, true), "learned Tin Vein: " .. got)
    ProfBuddyDB.knowledgeShared["Pal-Forever"] = nil
    ProfBuddyDB.nodeLoot = nil

    -- a beast's loot follows the same rule: no Skinning, no loot unless
    -- "Unlearned too"
    local SRC = ProfBuddy.Source
    local realRead = SRC.ReadVisibleSkillLines
    SRC.ReadVisibleSkillLines = function() return {} end
    local char = ProfBuddy.DataStore:GetCharacter(ProfBuddy:PlayerKey())
    local skin = char.professions.Skinning
    char.professions.Skinning = nil
    local post
    for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Unit then post = c.fn end end
    local realU = { UnitExists = UnitExists, UnitCanAttack = UnitCanAttack, UnitIsDead = UnitIsDead,
                    UnitGUID = UnitGUID, UnitLevel = UnitLevel }
    UnitExists = function() return true end
    UnitCanAttack = function() return true end
    UnitIsDead = function() return false end
    UnitGUID = function() return "Creature-0-1-2-3-3130-0000" end
    UnitLevel = function() return 10 end
    rawset(GameTooltip, "GetUnit", function() return "Thunder Lizard", "mouseover" end)
    local function beast()
        lines = {}
        post(GameTooltip, { type = Enum.TooltipDataType.Unit, lines = { { leftText = "Thunder Lizard" } } })
        return table.concat(lines, " / ")
    end
    got = beast()
    EXPECT(got:find("Requires Skinning (1)", 1, true) and not got:find("Skins into", 1, true), "non-skinner beast: " .. got)
    ProfBuddyDB.settings.gatherLootUnlearned = true
    EXPECT(beast():find("Skins into (Classic data):", 1, true), "non-skinner beast with Unlearned too")
    ProfBuddyDB.settings.gatherLootUnlearned = false
    char.professions.Skinning = skin
    SRC.ReadVisibleSkillLines = realRead
    for k, v in pairs(realU) do _G[k] = v end
    for _, k in ipairs({ "GetUnit", "GetItem", "NumLines", "AddLine", "AddDoubleLine", "Show" }) do rawset(GameTooltip, k, nil) end
    ProfBuddyDB.lastGather = nil
end
print("  PASS F43 node loot on the tooltip: Classic list for all 51 nodes, once per tooltip, learned at 10 gathers (yours and friends'); loot only for learned professions unless Unlearned too, on beasts as well; Gathering loot off hides it")

-- F44: node loot on the wire (COMM_REV 12). KNOW_REQ asks for it (g); a
-- KNOW_DATA carries it only when asked; a known node name under its own
-- profession only; over a cap drops the message.
do
    local Comm = ProfBuddy.Comm
    local AS = LibStub("AceSerializer-3.0")
    local SENT = {}
    local realWhisper = Comm.SendWhisper
    Comm.SendWhisper = function(_, t, d, target) SENT[#SENT + 1] = { t = t, d = d, to = target } end
    local function deliver(from, msg) Comm:OnMessageReceived("PBuddy", AS:Serialize(msg), "WHISPER", from) end
    local function last(t) for i = #SENT, 1, -1 do if SENT[i].t == t then return SENT[i] end end end
    local PAL = "Pal-Forever"
    ProfBuddyDB.contacts[PAL] = { trusted = true, autoSync = false, lastSync = 0 }
    Comm._knowAsked = {}
    deliver(PAL, { _type = "SYNC_DATA", _commrev = 12, class = "MAGE", level = 20, faction = "Horde",
                   partial = true, professions = {} })
    EXPECT(last("KNOW_REQ") and last("KNOW_REQ").d.g == true, "KNOW_REQ without g")
    ProfBuddyDB.nodeLoot = { ["Copper Vein"] = { n = 4, at = 4000, seenBy = {}, prof = "Mining",
        items = { [2770] = { c = 4, min = 1, max = 1, name = "Copper Ore" } } } }
    Comm._knowServed = {}
    deliver(PAL, { _type = "KNOW_REQ", since = 0, profs = { "Mining" }, s = true })
    EXPECT(last("KNOW_DATA").d.g == nil, "node loot sent unasked")
    Comm._knowServed = {}
    deliver(PAL, { _type = "KNOW_REQ", since = 0, profs = { "Mining" }, g = true })
    local share = last("KNOW_DATA").d
    local g = share.g and share.g["Copper Vein"]
    EXPECT(g and g.n == 4 and g.p == "Mining" and g.i[1][1] == 2770 and g.i[1].name == nil, "node loot on the wire")

    local function tryNodes(gfield)
        ProfBuddyDB.knowledgeShared[PAL] = nil
        Comm._knowPending[PAL] = time()
        deliver(PAL, { _type = "KNOW_DATA", _commrev = 12, at = 4300, npcs = {}, r = {}, g = gfield })
        return ProfBuddyDB.knowledgeShared[PAL]
    end
    local got = tryNodes(share.g)
    EXPECT(got and got.nodeLoot["Copper Vein"].n == 4 and got.nodeLoot["Copper Vein"].prof == "Mining", "round trip")
    got = tryNodes({ ["Copper Vein"] = { a = 1, n = 2, p = "Herbalism", i = {} },
                     ["Mystery Vein"] = { a = 1, n = 2, p = "Mining", i = {} },
                     ["Peacebloom"] = { a = 1, n = 2, p = "Herbalism", i = { { 2447, 2, 1, 3 } } } })
    EXPECT(got and got.nodeLoot["Copper Vein"] == nil and got.nodeLoot["Mystery Vein"] == nil
           and got.nodeLoot["Peacebloom"].items[2447].max == 3, "node names and professions not checked")
    local many = {}
    for i = 1, 201 do many["Node " .. i] = { a = 1, n = 1, p = "Mining", i = {} } end
    EXPECT(tryNodes(many) == nil, "201 nodes were stored")
    EXPECT(tryNodes("junk") == nil, "a non-table g was stored")
    local items = {}
    for i = 1, 13 do items[i] = { 2770, 1, 1, 1 } end
    EXPECT(tryNodes({ ["Copper Vein"] = { a = 1, n = 20, p = "Mining", i = items } }) == nil, "13 items on one node")
    ProfBuddyDB.knowledgeShared[PAL] = nil
    ProfBuddyDB.contacts[PAL] = nil
    ProfBuddyDB.characters[PAL] = nil
    ProfBuddyDB.nodeLoot = nil
    Comm.SendWhisper = realWhisper
end
print("  PASS F44 node loot on the wire: asked with g, sent only when asked, known node names under their own profession, caps")

-- F45: Enchanting rods on WoW: Forever, as on TBC Anniversary. The bake
-- reads each recipe's required rod (SpellTotems, totem category type 3) and
-- the rods themselves (ItemSparse TotemCategoryID): Copper to Arcanite,
-- cumulative masks. The tooltip says "Tool: Runed Copper Rod", green with a
-- good enough rod in the bags or bank, red "(missing)" without.
do
    local RDB, TSF = ProfBuddy.RecipeDB, ProfBuddy.TradeSkillFrame
    local rods = ProfBuddy.EnchantingRods
    EXPECT(rods and #rods.list == 5 and rods.byName["Runed Copper Rod"].itemID == 6218
           and rods.byName["Runed Copper Rod"].mask == 1 and rods.byName["Runed Arcanite Rod"].mask == 31,
           "Forever rod list")
    local n = 0
    for _, r in pairs(RDB.data.Enchanting) do
        if r.rod then n = n + 1; EXPECT(rods.byName[r.rod], "unknown rod " .. tostring(r.rod)) end
    end
    EXPECT(n > 200, "only " .. n .. " recipes name a rod")
    EXPECT(RDB:GetRecipeBySpell(7457).rod == "Runed Copper Rod", "Minor Stamina's rod")
    local lines = {}
    local tip = { AddLine = function(_, t, r, g, b) lines[#lines + 1] = { t = t, r = r, g = g } end }
    local char = ProfBuddy.DataStore:GetCharacter(ProfBuddy:PlayerKey())
    char.inventory = char.inventory or { bags = {}, bank = {} }
    local bags = char.inventory.bags
    local keep = { bags[6218], bags[6339], bags[16207] }
    bags[6218], bags[6339], bags[16207] = nil, nil, nil
    TSF:AppendRodLine(tip, { spellID = 7457, name = "Enchant Bracer - Minor Stamina" })
    EXPECT(lines[2] and lines[2].t == "Tool: Runed Copper Rod (missing)" and lines[2].r == 1, "missing rod: " .. tostring(lines[2] and lines[2].t))
    lines = {}
    bags[16207] = 1      -- a higher rod satisfies a lower one
    TSF:AppendRodLine(tip, { spellID = 7457, name = "Enchant Bracer - Minor Stamina" })
    EXPECT(lines[2] and lines[2].t == "Tool: Runed Copper Rod" and lines[2].g == 1, "owned rod: " .. tostring(lines[2] and lines[2].t))
    lines = {}
    TSF:AppendRodLine(tip, { spellID = 2881, name = "Light Leather" })
    EXPECT(#lines == 0, "a tool line on a recipe that needs none")
    bags[6218], bags[6339], bags[16207] = keep[1], keep[2], keep[3]
end
print("  PASS F45 Enchanting rods on Forever: Copper to Arcanite with cumulative masks, the recipe's rod on its tooltip, green when owned (a higher rod counts), red (missing) without")

-- F46: the random-stats line on WoW: Forever, as on TBC Anniversary. The
-- bake lists the crafted items with an item bonus tree (17: 9 carried over
-- from Classic, 8 new Engineering belts and goggles); the line uses the
-- game's own ITEM_RANDOM_ENCHANT, "<Random additional stats>", and never
-- doubles a line the game already shows.
do
    local TSF = ProfBuddy.TradeSkillFrame
    local R = ProfBuddy.RandomEnchantItems
    local n = 0
    for _ in pairs(R or {}) do n = n + 1 end
    EXPECT(n == 17 and R[8211] and R[20039] and R[280311] and not R[2318], "random-stats list: " .. n)
    local tl = {}
    for i = 1, 5 do
        local fs = _G["PBRandTipTextLeft" .. i] or CreateFrame("Frame", "PBRandTipTextLeft" .. i)
        rawset(fs, "GetText", function() return tl[i] end)
    end
    local tip = { GetName = function() return "PBRandTip" end, NumLines = function() return #tl end,
                  AddLine = function(_, t) tl[#tl + 1] = t end }
    tl = { "Wild Leather Vest" }
    TSF:AppendRandomEnchantLine(tip, 8211)
    EXPECT(tl[2] == "<Random additional stats>", "line: " .. tostring(tl[2]))
    TSF:AppendRandomEnchantLine(tip, 8211)
    EXPECT(#tl == 2, "the line was doubled")
    tl = { "Light Leather" }
    TSF:AppendRandomEnchantLine(tip, 2318)
    EXPECT(#tl == 1, "a line on an item without random stats")
end
print("  PASS F46 random stats on Forever: 17 items from the bake, the game's own <Random additional stats> wording, never doubled")

-- F47: every other tool, on Forever as on TBC Anniversary (Data/Forever/
-- Tools.lua from SpellTotems): Blacksmith Hammer, Arclight Spanner,
-- Gyromatic Micro-Adjustor, Philosopher's Stone, and specific items (Flint
-- and Tinder for a campfire). Any item whose tool category covers the
-- required one counts (the Gnomish Army Knife is a hammer and a spanner).
do
    local TSF, RDB = ProfBuddy.TradeSkillFrame, ProfBuddy.RecipeDB
    local RT, TC = ProfBuddy.RecipeTools, ProfBuddy.ToolCategories
    local n = 0
    for _ in pairs(RT or {}) do n = n + 1 end
    EXPECT(n > 600, "only " .. n .. " recipes need a tool")
    EXPECT(TC[162] and TC[162].name == "Blacksmith Hammer" and TC[14].name == "Arclight Spanner", "tool categories")
    local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end end
    EXPECT(has(TC[162].items, 5956) and has(TC[162].items, 260811) and has(TC[14].items, 260811)
           and not has(TC[15].items, 6219), "which items satisfy a tool")
    EXPECT(RT[1229737] and RT[1229737][1] == -4471 and ProfBuddy.ToolItemNames[4471] == "Flint and Tinder", "campfire tool")
    local cop = RDB.data.Blacksmithing["Copper Chain Belt"] or RDB.data.Blacksmithing["Rough Copper Vest"]
    EXPECT(cop and RT[cop.spellID] and RT[cop.spellID][1] == 162, "a Blacksmithing recipe without its hammer")
    local lines = {}
    local tip = { AddLine = function(_, t, r, g) lines[#lines + 1] = { t = t, r = r, g = g } end }
    local char = ProfBuddy.DataStore:GetCharacter(ProfBuddy:PlayerKey())
    local bags = char.inventory.bags
    local keep = { bags[5956], bags[260811], bags[4471] }
    bags[5956], bags[260811], bags[4471] = nil, nil, nil
    TSF:AppendRodLine(tip, { spellID = cop.spellID, name = "x" })
    EXPECT(lines[1].t == " " and lines[2].t == "Tool: Blacksmith Hammer (missing)" and lines[2].r == 1, "missing hammer: " .. tostring(lines[2] and lines[2].t))
    lines = {}
    char.inventory.bank = char.inventory.bank or {}
    local bankKeep = char.inventory.bank[5956]
    char.inventory.bank[5956] = 1          -- a hammer in the bank counts
    TSF:AppendRodLine(tip, { spellID = cop.spellID, name = "x" })
    EXPECT(lines[2].t == "Tool: Blacksmith Hammer" and lines[2].g == 1, "hammer in the bank")
    char.inventory.bank[5956] = bankKeep
    lines = {}
    bags[260811] = 1     -- a Gnomish Army Knife covers the hammer
    TSF:AppendRodLine(tip, { spellID = cop.spellID, name = "x" })
    EXPECT(lines[2].t == "Tool: Blacksmith Hammer" and lines[2].g == 1, "army knife as hammer")
    lines = {}
    TSF:AppendRodLine(tip, { spellID = 1229737, name = "Basic Campfire" })
    EXPECT(lines[2] and lines[2].t == "Tool: Flint and Tinder (missing)", "campfire: " .. tostring(lines[2] and lines[2].t))
    lines = {}
    bags[4471] = 1
    TSF:AppendRodLine(tip, { spellID = 1229737, name = "Basic Campfire" })
    EXPECT(lines[2].t == "Tool: Flint and Tinder", "campfire with flint")
    bags[5956], bags[260811], bags[4471] = keep[1], keep[2], keep[3]
end
print("  PASS F47 every tool on Forever: hammer, spanner, micro-adjustor, Philosopher's Stone and specific items, red (missing) or green, an item covering the category counts")

-- F48: "Hide opposite-faction trainers and vendors" (WoW: Forever's label
-- for hideOppositeFactionRecipes). The side an NPC serves comes from the
-- game data (Data/Forever/NpcFactions.lua: its VMaNGOS faction read in
-- Forever's FactionTemplate), else the faction PB saw when it was met.
do
    local KN = ProfBuddy.Knowledge
    local SIDES = ProfBuddy.NpcSides
    local n = 0
    for _ in pairs(SIDES or {}) do n = n + 1 end
    EXPECT(n > 1400 and SIDES[3008] == "H" and SIDES[3955] == "A" and SIDES[2843] == "N", "NPC side data: " .. n)
    local spell = ProfBuddy.RecipeDB.data.Leatherworking["Handstitched Leather Pants"].spellID
    local realK = ProfBuddyDB.knowledge
    ProfBuddyDB.knowledge = { [spell] = { seenBy = { ["*"] = true }, teachers = {
        [3008] = { name = "Mak", zone = "Thunder Bluff" },                       -- no recorded faction
        [3955] = { name = "Shandrina", zone = "Ashenvale", faction = "Horde" },  -- recorded wrongly
        [2843] = { name = "Jutak", zone = "Stranglethorn Vale", faction = "Horde" },
        [999901] = { name = "Newcomer", zone = "Somewhere", faction = "Horde" }, -- not in the data
    } } }
    local function shown(faction)   -- every trainer, as the Source tooltip lists them
        return table.concat(KN:TooltipLines(spell, faction) or {}, " / ")
    end
    local a, h, all = shown("Alliance"), shown("Horde"), shown(nil)
    EXPECT(not a:find("Mak", 1, true) and a:find("Shandrina", 1, true) and a:find("Jutak", 1, true)
           and not a:find("Newcomer", 1, true), "Alliance sees: " .. a)
    EXPECT(h:find("Mak", 1, true) and not h:find("Shandrina", 1, true) and h:find("Jutak", 1, true)
           and h:find("Newcomer", 1, true), "Horde sees: " .. h)
    EXPECT(all:find("Mak", 1, true) and all:find("Shandrina", 1, true), "checkbox off hides someone: " .. all)
    ProfBuddyDB.knowledge = realK
    -- the Settings label says what it does on Forever
    local label
    for _, f in ipairs(FRAMES) do
        if rawget(f, "_text") == "Hide opposite-faction trainers and vendors" then label = true end
        if rawget(f, "_text") == "Hide opposite-faction recipes" then label = "old" end
    end
    EXPECT(label == true, "Settings label: " .. tostring(label))
end
print("  PASS F48 opposite-faction trainers and vendors: the side from the game data (Mak Horde, Shandrina Alliance, Jutak both), else what PB saw; Forever's Settings label")

-- F49: the 2026-10-09 review fixes. Numbered message ids start from the
-- clock, not 1, so a /reload cannot merge with a partial a peer holds;
-- _lastHeard is swept; a shared record with nothing in it is not stored
-- (it would only mark a recipe seen); a secret sender is dropped before
-- anything parses it; while addon chat is restricted an unacked order
-- message queues quietly and goes out when the restriction lifts; the
-- recipe list waits while the profession data is changing and keeps only
-- the open profession's recipes; the client reports WOW_PROJECT_CAMELOT.
do
    local Comm, KN = ProfBuddy.Comm, ProfBuddy.Knowledge
    local AS = LibStub("AceSerializer-3.0")
    EXPECT(WOW_PROJECT_ID == 18 and WOW_PROJECT_CAMELOT == 18 and ProfBuddyDB, "Forever's project id")

    -- message ids from the clock
    local CTL = ChatThrottleLib
    local realCTL = CTL.SendAddonMessage
    local wire = {}
    CTL.SendAddonMessage = function(_, prio, prefix, text) wire[#wire + 1] = text end
    Comm._chunkSeq = nil
    local big = { names = {} }
    for i = 1, 60 do big.names[i] = "Recipe number " .. i end
    Comm:Send("SYNC_DATA", big, "WHISPER", "Pal Friend", "BULK")
    CTL.SendAddonMessage = realCTL
    local id = wire[1] and tonumber(wire[1]:match("^\005(%d+):"))
    EXPECT(id == time() % 9999 + 1 and id ~= 1, "first id after a reload: " .. tostring(id))

    -- _lastHeard swept
    Comm._lastHeard = { ["Old Friend-Forever"] = time() - 700, ["New Friend-Forever"] = time() }
    Comm:SweepSessionTables()
    EXPECT(Comm._lastHeard["Old Friend-Forever"] == nil and Comm._lastHeard["New Friend-Forever"], "_lastHeard not swept")

    -- empty shared records
    local leather = ProfBuddy.RecipeDB.data.Leatherworking["Handstitched Leather Pants"].spellID
    local boots = ProfBuddy.RecipeDB.data.Leatherworking["Handstitched Leather Boots"].spellID
    local clean = Comm:SanitizeKnowledge({ at = 10, npcs = {}, r = { [leather] = { a = 10 }, [boots] = { a = 10, l = 15 } } })
    EXPECT(clean and clean.records[leather] == nil and clean.records[boots] and clean.records[boots].learnLevel == 15,
           "empty shared record kept")

    -- a secret sender
    local SECRET = newproxy(true)
    getmetatable(SECRET).__index = function() error("secret indexed") end
    issecretvalue = function(v) return rawequal(v, SECRET) end
    local realType = type
    type = function(v) if rawequal(v, SECRET) then return "string" end return realType(v) end
    local okS, errS = pcall(Comm.OnMessageReceived, Comm, "PBuddy", AS:Serialize({ _type = "SYNC_REQ" }), "WHISPER", SECRET)
    type = realType
    issecretvalue = nil
    EXPECT(okS, "secret sender: " .. tostring(errS))

    -- addon chat restricted: no "offline", and the queue goes out when it lifts
    local realR = rawget(_G, "C_RestrictedActions")
    local restricted = true
    C_RestrictedActions = { IsAddOnRestrictionActive = function(t) return t == 5 and restricted end }
    local realWhisper = Comm.SendWhisper
    local sent = {}
    Comm.SendWhisper = function(_, t, d, target) sent[#sent + 1] = { t = t, to = target } end
    PRINTS = {}
    Comm._lastHeard = {}
    ProfBuddyDB.orderOutbox = {}
    local PAL = "Pal Friend-Forever"
    Comm:SendOrderMessage("ORDER_UPDATE", { token = "tok-1", id = "Me-Forever-1" }, PAL, "update")
    FLUSH()
    EXPECT(not PRINTED("is offline") and ProfBuddyDB.orderOutbox["tok-1"], "restricted: offline printed or nothing queued")
    restricted = false
    sent = {}
    Comm:OnRestrictionChanged(5, 0)
    local resent = false
    for _, m in ipairs(sent) do if m.t == "ORDER_UPDATE" and m.to == PAL then resent = true end end
    EXPECT(resent, "queued order message not sent when the restriction lifted")
    Comm.SendWhisper = realWhisper
    ProfBuddyDB.orderOutbox = {}
    FLUSH()
    C_RestrictedActions = realR

    -- the recipe list: waits while the data changes, keeps the open profession's recipes
    local SRC = ProfBuddy.Source
    C_TradeSkillUI.OpenTradeSkill(165); TS_LIST_READY(); FLUSH()
    TS.changing = true
    EXPECT(SRC:OpenInfo() == nil and #SRC:ReadOpenWindow(false).rows == 0, "read while the data source was changing")
    TS.changing = false
    local n = #SRC:ReadOpenWindow(false).rows
    local realIDs = C_TradeSkillUI.GetAllRecipeIDs
    C_TradeSkillUI.GetAllRecipeIDs = function()
        local ids = realIDs()
        ids[#ids + 1] = 1229737        -- Cooking's Basic Campfire, mixed in
        return ids
    end
    local rows = SRC:ReadOpenWindow(false).rows
    local foreign = false
    for _, r in ipairs(rows) do if r.recipeID == 1229737 then foreign = true end end
    EXPECT(#rows == n and not foreign, "a Cooking recipe in the Leatherworking list")
    -- an API that answers no for everything: no filtering at all
    local realIn = C_TradeSkillUI.IsRecipeInSkillLine
    C_TradeSkillUI.IsRecipeInSkillLine = function() return false end
    EXPECT(#SRC:ReadOpenWindow(false).rows == n + 1, "a no-for-everything API emptied the list")
    C_TradeSkillUI.IsRecipeInSkillLine = realIn
    C_TradeSkillUI.GetAllRecipeIDs = realIDs
end
print("  PASS F49 review fixes: numbered ids from the clock, _lastHeard swept, empty shared records dropped, secret senders dropped, restricted chat queues quietly and resends, list read waits for the data and keeps its own profession's recipes, project id 18")

-- F50: on WoW: Forever a long whisper goes out as numbered chunks through
-- ChatThrottleLib. Each chunk carries the whisper's callback, so a chunk that
-- leaves late re-stamps it and the "no player named" line it draws is hidden.
do
    local Comm = ProfBuddy.Comm
    local CTL = ChatThrottleLib
    local wire = {}
    local realCTL = CTL.SendAddonMessage
    CTL.SendAddonMessage = function(_, prio, prefix, text, chattype, target, queue, callbackFn, callbackArg)
        wire[#wire + 1] = { target = target, cb = callbackFn, arg = callbackArg }
    end
    -- the test client stubs unknown globals with a table; the game has the string
    ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
    Comm._recentWhispers = nil
    local big = { names = {} }
    for i = 1, 200 do big.names[i] = "Recipe number " .. i end
    local t0 = os.time()
    local realTime = time
    time = function() return t0 end
    Comm:SendWhisper("SYNC_DATA", big, "Owl Milk-Forever", "BULK")
    EXPECT(#wire > 10, "long whisper: " .. #wire .. " chunks")
    for i, w in ipairs(wire) do
        EXPECT(w.target == "Owl Milk" and type(w.cb) == "function", "chunk " .. i .. " has no callback")
    end
    local line = "No player named 'Owl Milk' is currently playing."
    time = function() return t0 + 310 end
    EXPECT(Comm:OnSystemMessage(line) == false, "a line 310 s after queueing was hidden with no chunk sent")
    wire[#wire].cb(wire[#wire].arg, true, 0)          -- the last chunk leaves now
    EXPECT(Comm:OnSystemMessage(line) == true, "the line for the last chunk was shown")
    time = realTime
    Comm._recentWhispers = nil
    CTL.SendAddonMessage = realCTL
end
print("  PASS F50 a long whisper's numbered chunks each re-stamp it as they leave, so a late chunk's offline line is hidden")

-- F51: launchers. A LibDataBroker launcher and a LibDBIcon minimap button,
-- shown by default; left click runs /pb, right click /pb config; the
-- Settings box hides and shows the button and saves it; WoW: Forever's addon
-- compartment lists PB and its click does the same.
do
    local S = ProfBuddy.db.settings
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")
    local obj = LDB:GetDataObjectByName("ProfessionBuddy")
    EXPECT(obj and obj.type == "launcher" and obj.icon == "Interface\\Icons\\INV_Camelot_Camping_WelcomingCampfire", "no launcher object")
    EXPECT(icon:IsRegistered("ProfessionBuddy"), "no minimap button")
    local btn = icon:GetMinimapButton("ProfessionBuddy")
    EXPECT(type(S.minimapIcon) == "table" and not S.minimapIcon.hide, "minimap button not on by default")
    EXPECT(btn and btn:IsShown(), "minimap button hidden by default")
    local ran = {}
    local realSlash = SlashCmdList.PROFBUDDY
    SlashCmdList.PROFBUDDY = function(msg) ran[#ran + 1] = msg end
    obj.OnClick(btn, "LeftButton")
    obj.OnClick(btn, "RightButton")
    EXPECT(ran[1] == "" and ran[2] == "config", "clicks ran: " .. table.concat(ran, ","))
    local lines = {}
    obj.OnTooltipShow({ AddLine = function(_, t) lines[#lines + 1] = t end })
    EXPECT(lines[1] == "ProfessionBuddy" and lines[2]:find("Left-click", 1, true)
           and lines[3]:find("Right-click: open Settings", 1, true), "tooltip lines")
    -- compartment: one entry, its click does what the button does
    local entry
    for _, d in ipairs(AddonCompartmentFrame.registeredAddons) do
        if d.text == "ProfessionBuddy" then entry = d end
    end
    EXPECT(entry and entry.icon == obj.icon, "no addon compartment entry")
    ran = {}
    entry.func(nil, { buttonName = "RightButton" }, nil)
    EXPECT(ran[1] == "config", "compartment right click ran: " .. tostring(ran[1]))
    SlashCmdList.PROFBUDDY = realSlash
    -- the Settings box
    local TSF = ProfBuddy.TradeSkillFrame
    TSF:OpenSettings("main")
    local cb = TSF.minimapCB
    EXPECT(cb, "no Show minimap button box")
    rawset(cb, "GetChecked", function() return false end)
    cb:GetScript("OnClick")(cb)
    EXPECT(S.minimapIcon.hide == true and not btn:IsShown(), "unticking did not hide the button")
    rawset(cb, "GetChecked", function() return true end)
    cb:GetScript("OnClick")(cb)
    EXPECT(S.minimapIcon.hide == false and btn:IsShown(), "ticking did not show the button")
    TSF:CloseSettings()
    -- saved settings from before this build: no table, button shown
    S.minimapIcon = nil
    EXPECT(ProfBuddy.Launcher:IsMinimapShown(), "an upgraded install reads as hidden")
    ProfBuddy.Launcher:SetMinimapShown(true)
    EXPECT(type(S.minimapIcon) == "table" and S.minimapIcon.hide == false, "an upgraded install did not save shown")
end
print("  PASS F51 launchers: data broker launcher, minimap button shown by default, left /pb, right Settings, Settings box hides and shows it, addon compartment entry")

-- F52: the chat box's whispers (C_ChatInfo.SendChatMessage, post-hooked
-- at load) are the player's own, so the offline line for that name shows
-- even while PB whispered it too; PB's own still hides for five minutes.
do
    local Comm = ProfBuddy.Comm
    ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
    Comm._recentWhispers, Comm._playerWhispers = nil, nil
    local realCTL = ChatThrottleLib.SendAddonMessage
    ChatThrottleLib.SendAddonMessage = function() end
    Comm:SendWhisper("SYNC_REQ", {}, "Owl Milk-Forever")
    local line = "No player named 'Owl Milk' is currently playing."
    EXPECT(Comm:OnSystemMessage(line) == true, "PB's own whisper: the line was shown")
    C_ChatInfo.SendChatMessage("test", "WHISPER", nil, "Owl Milk")
    EXPECT(Comm._playerWhispers and Comm._playerWhispers["Owl Milk"], "the chat box whisper was not noted")
    EXPECT(Comm:OnSystemMessage(line) == false, "the line answering the player's own whisper was hidden")
    C_ChatInfo.SendChatMessage("hello", "SAY")
    EXPECT(not Comm._playerWhispers["Hello"], "a /say was noted as a whisper")
    Comm._recentWhispers, Comm._playerWhispers = nil, nil
    ChatThrottleLib.SendAddonMessage = realCTL
end
print("  PASS F52 the player's own whispers keep their offline line, PB's hide for five minutes")

-- F53: Battle.net auto-add on WoW: Forever (2.0.2): the Friends tab button
-- works and its tooltip explains it; a picked friend on a Forever character
-- becomes a contact under the Forever key, whatever internal realm the game
-- reports, surname whole; a friend in another game is not added. Then the
-- picker window's own logic.
do
    local BN, S = ProfBuddy.BattleNet, ProfBuddy.db.settings
    local FP = ProfBuddy.FriendsPanel
    EXPECT(BN:Available(), "Battle.net auto-add is off on Forever")
    if not FP.bnetBtn then FP:Toggle() end           -- the tab builds on first show
    local btn = FP.bnetBtn
    EXPECT(btn and btn:IsEnabled(), "the Battle.net button is greyed out on Forever")
    local tipLines = {}
    local realAdd, realSet = GameTooltip.AddLine, GameTooltip.SetText
    rawset(GameTooltip, "SetText", function(_, t) tipLines[#tipLines + 1] = t end)
    rawset(GameTooltip, "AddLine", function(_, t) tipLines[#tipLines + 1] = t end)
    btn:GetScript("OnEnter")(btn)
    rawset(GameTooltip, "SetText", realSet); rawset(GameTooltip, "AddLine", realAdd)
    EXPECT(tipLines[1] == "Battle.net friends" and tipLines[2] and tipLines[2]:find("ProfessionBuddy", 1, true),
           "tooltip: " .. tostring(tipLines[1]) .. " / " .. tostring(tipLines[2]))
    local src = assert(io.open(PB_BASE .. "/UI/FriendsPanel.lua")):read("*a")
    EXPECT(not src:find("Coming soon", 1, true), "the coming-soon text is still there")
    BNConnected = function() return true end
    local list = {
        { tag = "Zed#1", games = {} },
        -- as m4ru's live read: realmName is an internal per-character name
        { tag = "Ann#2", games = { { clientProgram = "WoW", isOnline = true, wowProjectID = WOW_PROJECT_ID,
            isInCurrentRegion = true, characterName = "Ann Wren", realmName = "CAMWOWUS1Realm4PvP", factionName = "Horde" } } },
        { tag = "Tbc#3", games = { { clientProgram = "WoW", isOnline = true, wowProjectID = 5,
            isInCurrentRegion = true, characterName = "Oldie", realmName = "Dreamscythe", factionName = "Horde" } } },
    }
    BNGetNumFriends = function() return #list end
    C_BattleNet = {
        GetFriendAccountInfo = function(i) return { battleTag = list[i].tag } end,
        GetFriendNumGameAccounts = function(i) return #list[i].games end,
        GetFriendGameAccountInfo = function(i, j) return list[i].games[j] end,
    }
    S.bnetAutoAdd, S.bnetPicks = true, { ["Ann#2"] = true, ["Tbc#3"] = true }
    BN:Scan()
    local ct = ProfBuddy.db.contacts
    EXPECT(ct["Ann Wren-Forever"] and ct["Ann Wren-Forever"].bnet == "Ann#2", "a picked Forever friend was not added")
    EXPECT(not ct["Ann Wren-CAMWOWUS1Realm4PvP"], "the internal realm went into the key")
    EXPECT(not ct["Oldie-Forever"] and not ct["Oldie-Dreamscythe"], "a friend in TBC Anniversary was added on Forever")
    ct["Ann Wren-Forever"] = nil
    -- the window
    S.bnetAutoAdd, S.bnetPicks = false, {}
    BN:ToggleWindow()
    local w = BN.window
    EXPECT(w and w:IsShown(), "the picker did not open")
    local note = rawget(w, "waitNote")       -- an unset frame field reads as a stub
    EXPECT(note and tostring(note:GetText()):find("minute or two", 1, true),
           "no note that a new contact's data takes a while")
    EXPECT(w.rows[1].label:GetText() == "Ann" and w.rows[2].label:GetText() == "Tbc"
           and w.rows[3].label:GetText() == "Zed",
           "friends in this game first, then by name; BattleTag cut at #")
    EXPECT(w.rows[1].status:GetText():find("Ann Wren", 1, true), "no 'playing' line for a friend in game")
    EXPECT(not w.trust:IsEnabled(), "Also trust them usable with auto-add off")
    rawset(w.auto, "GetChecked", function() return true end)
    w.auto:GetScript("OnClick")(w.auto)
    EXPECT(S.bnetAutoAdd == true and w.trust:IsEnabled(), "auto-add box did not save or enable trust")
    rawset(w.rows[3], "GetChecked", function() return true end)
    w.rows[3]:GetScript("OnClick")(w.rows[3])
    EXPECT(S.bnetPicks["Zed#1"] == true, "ticking a friend did not save the pick")
    rawset(w.rows[1], "GetChecked", function() return true end)
    w.rows[1]:GetScript("OnClick")(w.rows[1])
    EXPECT(ProfBuddy.db.contacts["Ann Wren-Forever"], "ticking a friend in game did not add them")
    ProfBuddy.db.contacts["Ann Wren-Forever"] = nil
    w:Hide()
    S.bnetAutoAdd, S.bnetTrust, S.bnetPicks = false, false, {}
    BNConnected, BNGetNumFriends, C_BattleNet = nil, nil, nil
end
print("  PASS F53 Battle.net on Forever: button works, picked friend added under the Forever key (internal realm ignored), other games skipped; picker lists, ticks and adds")

-- F54: Settings scroll. Both columns sit in one scroll frame (bar hidden
-- when nothing to scroll), Settings opens at the top, nothing runs past the
-- scroll area's right edge, and "Show minimap button" sits in the top
-- section, right under the faction box.
do
    local TSF = ProfBuddy.TradeSkillFrame
    TSF:OpenSettings("main")
    local sf = TSF.settingsScroll
    EXPECT(sf and rawget(sf, "scrollBarHideable") == true, "no hideable settings scroll frame")
    local content = rawget(sf, "_child")
    EXPECT(content and content:GetParent() == sf, "no scroll child")
    local byKey = {}
    for _, cb in ipairs(TSF.settingsCheckboxes) do
        EXPECT(cb:GetParent() == content, "a setting box is outside the scroll area: " .. tostring(cb.settingKey))
        byKey[cb.settingKey] = cb
    end
    local function y(f) local p = rawget(f, "_lastPoint"); return p and p[3] end
    local fy, my, ay = y(byKey.hideOppositeFactionRecipes), y(byKey.minimapShownBox), y(byKey.showAltInDetail)
    EXPECT(my == fy - 30 and my > ay, "minimap box not right under the faction box: " .. tostring(fy) .. " " .. tostring(my) .. " " .. tostring(ay))
    -- right edge and bottom
    local cw, ch = rawget(content, "_size")[1], rawget(content, "_size")[2]
    for _, f in ipairs(FRAMES) do
        if f:GetParent() == content then
            local p, sz = rawget(f, "_lastPoint"), rawget(f, "_size")
            if p and sz and sz[1] then
                local x = (type(p[2]) == "table") and p[4] or p[2]
                local py = (type(p[2]) == "table") and p[5] or p[3]
                EXPECT(x + sz[1] <= cw, "a frame runs past the right edge: x " .. x .. " + " .. sz[1] .. " > " .. cw)
                EXPECT(-py <= ch, "a frame starts below the content height")
            end
        end
    end
    -- opens at the top
    sf:SetVerticalScroll(120)
    TSF.settingsPanel:Hide()
    TSF.settingsPanel:Show()
    EXPECT(rawget(sf, "_scroll") == 0, "Settings did not reopen at the top")
    TSF:CloseSettings()
end
print("  PASS F54 Settings scroll: columns in one scroll frame, opens at the top, fits the width; minimap box in the top section")

-- F55: the 2026-10-13 fix wave, Forever side. A crafted item seen without
-- an item link (a friend's recipe, the Missing list) shows its tool line;
-- the Guild Board list has 7 rows (8 drew one below the window); a friend
-- asked for sightings is asked again once 15 minutes have passed.
do
    local TSF = ProfBuddy.TradeSkillFrame
    TSF:EnsureFrame()
    local tip = TSF.embeddedTip
    rawset(tip, "_lines", {})
    TSF:ShowEmbeddedTooltip({ name = "Greater Magic Wand", itemID = 11288, spellID = 14807 })
    local rod = false
    for _, l in ipairs(rawget(tip, "_lines")) do
        if tostring(l):find("Tool: Runed Copper Rod", 1, true) then rod = true end
    end
    EXPECT(rod, "no rod line on a wand with no item link")

    local OP = ProfBuddy.OrdersPanel
    if not OP.boardCtx then OP:Toggle() end
    EXPECT(OP.boardCtx and #OP.boardCtx.rows == 7, "board rows: " .. tostring(OP.boardCtx and #OP.boardCtx.rows))

    local Comm = ProfBuddy.Comm
    local AS = LibStub("AceSerializer-3.0")
    local peer = "Reask Pal-Forever"
    ProfBuddy.db.contacts[peer] = { trusted = true, autoSync = false, lastSync = 0, lastCommRev = 12 }
    local kinds = {}
    local realW = Comm.SendWhisper
    Comm.SendWhisper = function(_, t) kinds[#kinds + 1] = t end
    local function knowReqs() local n = 0; for _, t in ipairs(kinds) do if t == "KNOW_REQ" then n = n + 1 end end; return n end
    local function hear() Comm:OnMessageReceived("PBuddy", AS:Serialize({ _type = "ORDER_ACK", _commrev = 12 }), "WHISPER", "Reask Pal") end
    Comm._knowAsked = Comm._knowAsked or {}
    Comm._knowAsked[peer] = time() - 100
    hear()
    EXPECT(knowReqs() == 0, "asked again after 100 s")
    Comm._knowAsked[peer] = time() - 901
    hear()
    EXPECT(knowReqs() == 1, "not asked again after 15 minutes")
    hear()
    EXPECT(knowReqs() == 1, "asked twice in a row")
    Comm.SendWhisper = realW
    Comm._knowAsked[peer], Comm._knowPending[peer] = nil, nil
    ProfBuddy.db.contacts[peer] = nil
end
print("  PASS F55 fix wave: tool line without an item link, 7 board rows, sightings asked again after 15 minutes")

-- F56: no Comprehension (the WoW: Forever mage's spellbook skill, which
-- has no profession window), the seventh profession slot, and the Guild
-- Board's right-hand controls.
do
    local RDB, SC = ProfBuddy.RecipeDB, ProfBuddy.Scanner
    EXPECT(RDB.data.Comprehension == nil, "Comprehension data loaded")
    for prof, recipes in pairs(RDB.data) do
        for name, e in pairs(recipes) do EXPECT(e.ability == nil, prof .. "/" .. name .. " is an ability") end
    end
    EXPECT(ProfBuddy.CLASS_PROFS.Comprehension == nil and not ProfBuddy.CRAFTABLE_PROFS.Comprehension,
           "Comprehension is still a profession")
    EXPECT(RDB.KnownAbilities == nil and RDB.AddKnownAbilities == nil, "the abilities path is still there")

    -- the seventh slot (Forever: two primaries and up to five secondaries)
    -- is read; Comprehension's skill line (3012) is skipped in any language
    local realGP, realGPI, realSI = GetProfessions, GetProfessionInfo, C_Spell.GetSpellInfo
    local slots = {}
    GetProfessions = function() return 1, 2, 3, 4, 5, nil, 7 end
    GetProfessionInfo = function(i)
        local n = slots[i]
        if not n then return nil end
        return n[1], 0, 10, 300, 1, 0, n[2]
    end
    local base = { { "Leatherworking", 165 }, { "Skinning", 393 }, { "Cooking", 185 }, { "First Aid", 129 },
                   { "Fishing", 356 }, false }
    for i = 1, 6 do slots[i] = base[i] end
    slots[7] = { "Herbalism", 182 }
    local lines = ProfBuddy.Source:ReadProfessionSkills()
    EXPECT(#lines == 6 and lines[6].name == "Herbalism", "the seventh profession slot was not read")
    slots[7] = { "Verständnis", 3012 }
    lines = ProfBuddy.Source:ReadProfessionSkills()
    EXPECT(#lines == 5, "Comprehension's slot was read: " .. #lines)

    -- with it in a slot, an unlearned profession still leaves the record,
    -- and Comprehension is not stored
    local names = { [2108] = "Leatherworking", [8613] = "Skinning", [2550] = "Cooking", [3273] = "First Aid",
                    [7620] = "Fishing", [3908] = "Tailoring" }
    C_Spell.GetSpellInfo = function(id) return names[id] and { name = names[id] } or nil end
    local char = ProfBuddy.DataStore:GetCharacter()
    local saved = char.professions
    char.professions = { Leatherworking = { skillLevel = 10, maxSkill = 300, recipes = {} },
                         Tailoring = { skillLevel = 10, maxSkill = 300, recipes = {} } }
    SC:ScanProfessions()
    EXPECT(char.professions.Tailoring == nil, "a mage's unlearned profession was kept")
    EXPECT(char.professions.Comprehension == nil and char.professions["Verständnis"] == nil, "Comprehension stored")
    char.professions = saved
    GetProfessions, GetProfessionInfo, C_Spell.GetSpellInfo = realGP, realGPI, realSI

    -- 2.0.0 saved it for mages: loading drops it from every character
    local db = { characters = { A = { professions = { Comprehension = { skillLevel = 5 }, Tailoring = {} } },
                                B = { professions = { Comprehension = {} } }, C = {}, D = "x" } }
    ProfBuddy:DropComprehension(db)
    EXPECT(db.characters.A.professions.Comprehension == nil and db.characters.A.professions.Tailoring
           and db.characters.B.professions.Comprehension == nil, "saved Comprehension not dropped")
    local core = assert(io.open(PB_BASE .. "/Core.lua")):read("*a")
    EXPECT(core:find("addon:MigrateToFullName%(%)%s+addon:DropComprehension%(ProfBuddyDB%)"),
           "loading does not drop saved Comprehension")
    SC:ScanProfessions()

    -- the Guild Board's right-hand controls sit flush with the list's scroll bar
    local OP = ProfBuddy.OrdersPanel
    if not OP.postComposer then OP:Toggle() end
    local comp = OP.postComposer
    local function x(f) local p = rawget(f, "_lastPoint"); return p and ((type(p[2]) == "table") and p[4] or p[2]) end
    EXPECT(x(OP.findBtn) == 0 and x(comp.postBtn) == 0, "Find a crafter / Post not flush right")
    EXPECT(x(comp.qty) == -2 and x(comp.note) == -2 and x(OP.boardFilterBox) == -2, "count, note or filter not flush right")

    -- the Friends tab draws up to 7 profession icons a row (it drew 4)
    local FP = ProfBuddy.FriendsPanel
    if not FP.rows then FP:Toggle() end
    EXPECT(FP.rows and FP.rows[1] and #FP.rows[1].profIcons == 7, "Friends rows do not hold 7 profession icons")
end
print("  PASS F56 no Comprehension (no data, slot skipped by skill line, saved copies dropped), seventh profession slot, board controls flush right, 7 Friends icons")

-- F57: an unlearned profession leaves the player's record on Forever too.
-- GetProfessions lists professions only, so an unnamed slot stops the
-- removal (the name map failed), and an empty read removes nothing.
do
    local SC = ProfBuddy.Scanner
    local char = ProfBuddy.DataStore:GetCharacter()
    local saved = char.professions
    local function prof(n) return { skillLevel = n, maxSkill = 300, recipes = { ["R" .. n] = { spellID = n } } } end
    char.professions = { Leatherworking = prof(100), Skinning = prof(90), Tailoring = prof(80),
        Poisons = prof(10) }
    local realGP, realGPI, realSI = GetProfessions, GetProfessionInfo, C_Spell.GetSpellInfo
    local names = { [2108] = "Leatherworking", [8613] = "Skinning", [3908] = "Tailoring", [2550] = "Cooking",
                    [2842] = "Poisons" }
    C_Spell.GetSpellInfo = function(id) return names[id] and { name = names[id] } or nil end
    local slots = {}
    GetProfessions = function() local r = {} for i = 1, #slots do r[i] = i end return unpack(r) end
    GetProfessionInfo = function(i) return slots[i], 0, 100, 300, 1, 0, 0 end

    slots = { "Leatherworking", "Skinning" }
    SC:ScanProfessions()
    local p = char.professions
    EXPECT(p.Tailoring == nil, "an unlearned profession is still stored on Forever")
    EXPECT(p.Leatherworking and p.Leatherworking.recipes.R100 and p.Skinning, "a learned profession was touched")
    EXPECT(p.Poisons, "Poisons (a class skill) was removed")

    p.Cooking = prof(50)
    slots = { "Leatherworking", "Kochkunst" }
    SC:ScanProfessions()
    EXPECT(p.Cooking and p.Skinning, "a slot PB could not name still removed professions")

    slots = {}
    SC:ScanProfessions()
    EXPECT(p.Leatherworking and p.Cooking, "an empty profession read removed professions")

    GetProfessions, GetProfessionInfo, C_Spell.GetSpellInfo = realGP, realGPI, realSI
    char.professions = saved
end
print("  PASS F57 unlearned professions removed on Forever; class skills, unnamed slots and empty reads keep them")

-- F58: the Friends tab lists an opposite-faction contact only with
-- "Show opposite faction friends" on (Settings, Friend Data); off by default.
do
    local S = ProfBuddy.db.settings
    local FP = ProfBuddy.FriendsPanel
    local chars, contacts = ProfBuddy.db.characters, ProfBuddy.db.contacts
    local savedContacts = {}
    for k, v in pairs(contacts) do savedContacts[k] = v end
    for k in pairs(contacts) do contacts[k] = nil end
    chars["Ally Pal-Forever"] = { faction = "Alliance", isRemote = true, professions = {} }
    chars["Horde Pal-Forever"] = { faction = "Horde", isRemote = true, professions = {} }
    contacts["Ally Pal-Forever"] = { trusted = true, autoSync = false, lastSync = 0 }
    contacts["Horde Pal-Forever"] = { trusted = true, autoSync = false, lastSync = 0 }
    contacts["Never Synced-Forever"] = { trusted = true, autoSync = false, lastSync = 0 }
    EXPECT(S.showCrossFactionFriends == false, "the friends setting is not off by default")
    if not FP.rows then FP:Toggle() end
    -- a hidden tab defers its rebuild to OnShow, so show it for the test
    local realVis = rawget(FP.parent, "IsVisible")
    rawset(FP.parent, "IsVisible", function() return true end)
    FP:Refresh()
    local function listed(k) for _, key in ipairs(FP.contactKeys) do if key == k then return true end end return false end
    EXPECT(not listed("Ally Pal-Forever") and listed("Horde Pal-Forever") and listed("Never Synced-Forever"),
           "the Friends tab lists an opposite-faction contact with the setting off")

    TSF:OpenSettings("main")
    local cb = TSF.crossFriendsCB
    EXPECT(cb, "no Show opposite faction friends box in Settings")
    rawset(cb, "GetChecked", function() return true end)
    cb:GetScript("OnClick")(cb)
    EXPECT(S.showCrossFactionFriends == true, "the box did not save the setting")
    FP:Refresh()
    EXPECT(listed("Ally Pal-Forever"), "the Friends tab still hides the contact with the setting on")

    -- every contact hidden: the empty line says why, not "No contacts yet"
    S.showCrossFactionFriends = false
    contacts["Horde Pal-Forever"], contacts["Never Synced-Forever"] = nil, nil
    FP:Refresh()
    EXPECT(#FP.contactKeys == 0 and tostring(FP.empty:GetText()):find("other faction", 1, true),
           "the empty line does not say the contacts are hidden")

    for k in pairs(contacts) do contacts[k] = nil end
    for k, v in pairs(savedContacts) do contacts[k] = v end
    chars["Ally Pal-Forever"], chars["Horde Pal-Forever"] = nil, nil
    FP:Refresh()
    rawset(FP.parent, "IsVisible", realVis)
end
print("  PASS F58 opposite-faction friends: hidden from the Friends tab by default, shown with the Settings box, empty line explains")

-- F59: search by material, the Learnable now view, and Share.
do
    local st = TSF.state
    TSF:CloseSettings()                    -- F58 left Settings open over the list
    C_TradeSkillUI.OpenTradeSkill(165)
    TS_LIST_READY()
    FLUSH()
    EXPECT(st.profName == "Leatherworking", "setup: Leatherworking did not open")
    local function rows()
        local out = {}
        for _, r in ipairs(st.recipes) do if not r.isHeader then out[r.name] = r end end
        return out
    end
    local function pickView(prefix)
        for _, b in ipairs(TSF.viewDropdown.optionBtns) do
            if b:IsShown() ~= false and type(b.value) == "string" and b.value:find("^" .. prefix) then
                b:GetScript("OnClick")(b)
                return b.value
            end
        end
    end

    -- b: the Search box matches a material's name. Light Leather is made
    -- from Ruined Leather Scraps; its own name does not hold that text.
    pickView("Known")
    TSF.searchBox:SetText("ruined leather")
    st.searchText = "ruined leather"
    TSF:RefreshRecipeList()
    local found = rows()
    EXPECT(found["Light Leather"], "a recipe was not found by its material's name")
    for name in pairs(found) do
        local r = found[name]
        local hit = name:lower():find("ruined leather", 1, true)
        for _, rg in ipairs(r.reagents or {}) do
            if (rg.name or ""):lower():find("ruined leather", 1, true) then hit = true end
        end
        EXPECT(hit, name .. " matched neither by name nor by material")
    end
    st.searchText = ""
    TSF.searchBox:SetText("")

    -- c: Learnable now is the Missing list cut to what the skill allows.
    local realSkill = st.skillLevel
    st.skillLevel = 75
    pickView("Missing")
    local want, n = {}, 0
    for name, r in pairs(rows()) do
        if r.skillReq and r.skillReq <= 75 and (not r.reqLevel or r.reqLevel <= UnitLevel("player")) then
            want[name] = true
            n = n + 1
        end
    end
    EXPECT(n > 0, "setup: nothing in Missing is learnable at 75")
    local label = pickView("Learnable now")
    EXPECT(st.showTab == "learnable", "the Learnable now view did not select")
    EXPECT(label == "Learnable now (" .. n .. ")", "label " .. tostring(label) .. ", want " .. n)
    local got, m = rows(), 0
    for name, r in pairs(got) do
        m = m + 1
        EXPECT(want[name] and not r.isKnown, name .. " is not a learnable missing recipe")
    end
    EXPECT(m == n, "Learnable now lists " .. m .. ", want " .. n)
    EXPECT(not TSF.diffDropdown:IsShown() and TSF.sourceDropdown:IsShown(),
           "Learnable now shows Skill Up or hides Source")
    st.skillLevel = realSkill
    pickView("Known")

    -- f: Share opens the chat box on the channel with the recipe's link.
    local opened = {}
    local realOpen = ChatFrameUtil.OpenChat
    ChatFrameUtil.OpenChat = function(text) opened[#opened + 1] = text end
    local realLink = C_Spell.GetSpellLink
    C_Spell.GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. id .. "|h[Spell " .. id .. "]|h|r" end
    st.selected = "Light Leather"
    TSF:RefreshDetailPanel()
    EXPECT(TSF.shareBtn, "no Share button in the detail panel")
    TSF:ShowShareMenu(TSF.shareBtn)
    local menu = TSF._shareMenu
    EXPECT(menu and menu:IsShown(), "the Share menu did not open")
    local byLabel = {}
    for _, b in ipairs(menu.buttons) do byLabel[b.text:GetText()] = b end
    EXPECT(byLabel.Guild and not byLabel.Guild:IsEnabled(), "Guild is usable outside a guild")
    EXPECT(byLabel.Say and byLabel.Say:IsEnabled(), "Say is not usable")
    byLabel.Say:GetScript("OnClick")(byLabel.Say)
    EXPECT(#opened == 1 and opened[1]:find("^/s |c") and opened[1]:find("|H", 1, true),
           "Share did not open the chat box with /s and a link: " .. tostring(opened[1]))
    -- a bare "item:123" is not a link: nothing opens until a real one exists
    opened = {}
    C_Spell.GetSpellLink = function() return nil end
    local ok = TSF:RecipeChatLink({ itemLink = "item:2318", spellID = 1 })
    EXPECT(ok == nil, "a bare item string counted as a link")
    ChatFrameUtil.OpenChat, C_Spell.GetSpellLink = realOpen, realLink
    menu:Hide()
end
print("  PASS F59 search matches materials, Learnable now lists exactly the learnable missing recipes, Share opens the chat box with the link")

-- F60: Find a Crafter's "Recipe or item name" sits inside the search box as
-- placeholder text, not as a label beside the box that ran under the Sync
-- guild recipes button. It shows while the box is empty (the panel focuses
-- the box on open) and hides while there is text.
do
    local OP = ProfBuddy.OrdersPanel
    OP:ToggleFind()
    local box = OP.findBox
    EXPECT(OP.findFrame:IsShown(), "Find a Crafter did not open")
    local found = {}
    for _, fr in ipairs(FRAMES) do
        if rawget(fr, "_text") == "Recipe or item name" then found[#found + 1] = fr end
    end
    EXPECT(#found == 1, "expected one Recipe or item name text, found " .. #found)
    local ph = found[1]
    EXPECT(rawget(ph, "_parent") == box, "the placeholder is not on the search box")
    local pt = rawget(ph, "_lastPoint")
    EXPECT(pt and pt[1] == "LEFT" and pt[2] == box and pt[3] == "LEFT",
           "the placeholder is not anchored inside the box")
    for _, fr in ipairs(FRAMES) do
        local p = rawget(fr, "_lastPoint")
        EXPECT(not (p and p[2] == box and p[3] == "RIGHT"), "something is still anchored right of the box")
    end
    EXPECT(ph:IsShown(), "placeholder hidden on an empty box")
    local onChanged = box:GetScript("OnTextChanged")
    box:SetText("copper"); onChanged(box)
    EXPECT(not ph:IsShown(), "placeholder still shown with text in the box")
    box:SetText(""); onChanged(box)
    EXPECT(ph:IsShown(), "placeholder did not come back when the box was cleared")
    OP:ToggleFind()
    EXPECT(not OP.findFrame:IsShown(), "Find a Crafter did not close")
end
print("  PASS F60 Find a Crafter shows Recipe or item name inside the box while it is empty")

-- F61: 2.0.1 text pass. The Characters tab says "1 recipe", not "1 recipes",
-- and the profession bar reads "<Profession> 75/150", "<Name>: <Profession>
-- 113/150" for someone else's, and "<Profession>: Not learned", with no
-- " - " or spaced slash.
do
    local CP = ProfBuddy.CharacterPanel
    local r1 = CP:CreateProfessionRow("X-Forever", "Leatherworking",
        { skillLevel = 10, maxSkill = 75, recipes = { a = {} } }, 0, false)
    local t1 = rawget(r1.recipeText, "_text") or ""
    EXPECT(t1:find("1 recipe|r", 1, true) and not t1:find("1 recipes", 1, true), "one recipe reads " .. t1)
    local r2 = CP:CreateProfessionRow("X-Forever", "Tailoring",
        { skillLevel = 10, maxSkill = 75, recipes = { a = {}, b = {} } }, 0, false)
    local t2 = rawget(r2.recipeText, "_text") or ""
    EXPECT(t2:find("2 recipes|r", 1, true), "two recipes read " .. t2)

    local bar = TSF.skillBarText
    TSF:UpdateSkillBar()
    local own = bar:GetText()
    EXPECT(own:match("^.+ %d+/%d+$") and not own:find(" - ", 1, true) and not own:find(" / ", 1, true),
           "own profession bar reads " .. own)

    ProfBuddyDB.characters["Barpal-Forever"] = { isRemote = true, class = "MAGE", faction = "Horde",
        professions = { Tailoring = { skillLevel = 50, maxSkill = 75, recipes = { a = {} } } } }
    TSF:OpenWithCharacter("Barpal-Forever", "Tailoring")
    local other = bar:GetText()
    EXPECT(other:find("|r: Tailoring 50/75", 1, true) and not other:find(" - ", 1, true),
           "someone else's profession bar reads " .. other)

    TSF:OpenWithStatic("Alchemy")
    local unl = bar:GetText()
    EXPECT(unl:find(": Not learned", 1, true) and not unl:find(" - ", 1, true),
           "not-learned profession bar reads " .. unl)
    ProfBuddyDB.characters["Barpal-Forever"] = nil
end
print("  PASS F61 Characters tab says 1 recipe; the profession bar reads Profession 75/150 with no dash")

-- F62: Colorblind markers (2.0.1 item 10). With markers on, a recipe row
-- puts Blizzard's [+++]/[++]/[+] before the name, a missing recipe's red
-- learn tag reads [35 low], a gather line ends in its band's marker or
-- (too low), and the Characters tab's expanded list marks names too. Auto follows
-- the game's Colorblind Mode; Settings has the Auto / On / Off dropdown.
do
    local S = ProfBuddyDB.settings
    EXPECT(S.colorblindMarkers == "auto", "colorblind default: " .. tostring(S.colorblindMarkers))
    CVARS.colorblindMode = "1"
    EXPECT(ProfBuddy:ColorblindMarkers(), "Auto missed the game's Colorblind Mode")

    -- the missing Kodo Hide Bag row (F22): orange when learned, learn level 35 above your skill
    -- F61 left a static Alchemy view up: reopen your own Leatherworking
    TSF.frame:Hide()
    C_TradeSkillUI.OpenTradeSkill(165)
    FLUSH(); TS_LIST_READY(); FLUSH()
    local st = TSF.state
    EXPECT(st.profName == "Leatherworking" and not st._viewCharKey, "Leatherworking did not reopen: " .. tostring(st.profName))
    st.showTab, st.searchText, st.selected, st.filterSource = "missing", "kodo hide bag", nil, "All"
    TSF:RefreshRecipeList()
    local names, rights = {}, {}
    for i, row in ipairs(TSF.listRows) do
        rawset(row.nameText, "SetText", function(_, t) names[i] = t end)
        rawset(row.rightText, "SetText", function(_, t) rights[i] = t end)
    end
    local function kodo()
        names, rights = {}, {}
        TSF:UpdateListRows()
        for i, t in pairs(names) do
            if type(t) == "string" and t:find("Kodo Hide Bag", 1, true) then return t, rights[i] end
        end
    end
    local n, r = kodo()
    EXPECT(n == "[+++] Kodo Hide Bag", "marked missing row name: " .. tostring(n))
    EXPECT(r == "|cffffff00Vendor|r |cffff4444[35 low]|r", "marked learn tag: " .. tostring(r))
    S.colorblindMarkers = "off"
    n, r = kodo()
    EXPECT(n == "Kodo Hide Bag" and r == "|cffffff00Vendor|r |cffff4444[35]|r", "Off still marks: " .. tostring(n) .. " " .. tostring(r))
    S.colorblindMarkers = "auto"

    -- known rows: each name carries its own tier's marker
    st.showTab, st.searchText = "known", ""
    TSF:RefreshRecipeList()
    names = {}
    TSF:UpdateListRows()
    local checked = 0
    for i in ipairs(TSF.listRows) do
        local e = st.recipes[i + (st.scrollOffset or 0)]
        if e and not e.isHeader and e.isKnown and names[i] then
            EXPECT(names[i] == ProfBuddy:DiffMarker(e.difficulty) .. e.name, "known row: " .. names[i])
            checked = checked + 1
        end
    end
    EXPECT(checked > 0, "no known rows to check")
    for _, row in ipairs(TSF.listRows) do rawset(row.nameText, "SetText", nil); rawset(row.rightText, "SetText", nil) end

    -- a gather line: Copper Vein needs Mining 1
    local onUpdate = GameTooltip._h.OnUpdate
    local left = {}
    for i = 1, 3 do
        left[i] = CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(left[i], "SetText", function(self, t) self._text = t end)
    end
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return 2 end)
    local added = {}
    rawset(GameTooltip, "AddLine", function(_, t) added[#added + 1] = t end)
    rawset(GameTooltip, "Show", function() end)
    left[1]._text, left[2]._text = "Copper Vein", "Requires Mining"
    onUpdate(GameTooltip, 1)
    local have = tonumber((added[1] or ""):match("Your Mining: (%d+)"))
    EXPECT(have, "no Your Mining line: " .. tostring(added[1]))
    local d = have - 1
    local want = (d < 25 and " [+++]") or (d < 50 and " [++]") or (d < 100 and " [+]") or ""
    EXPECT(left[2]._text:find("Requires Mining (1)" .. want .. "|r", 1, true), "marked vein line: " .. tostring(left[2]._text))
    -- Small Thorium Vein needs 245: too low
    left[1]._text, left[2]._text = "Small Thorium Vein", "Requires Mining"
    added = {}
    onUpdate(GameTooltip, 1)
    EXPECT(left[2]._text:find("Requires Mining (245) (too low)|r", 1, true), "too-low vein line: " .. tostring(left[2]._text))
    CVARS.colorblindMode = "0"
    left[1]._text, left[2]._text = "Small Thorium Vein", "Requires Mining"
    onUpdate(GameTooltip, 1)
    EXPECT(left[2]._text:find("Requires Mining (245)|r", 1, true), "unmarked vein line: " .. tostring(left[2]._text))
    rawset(GameTooltip, "NumLines", nil); rawset(GameTooltip, "GetItem", nil)

    -- the Characters tab's expanded recipe list
    CVARS.colorblindMode = "1"
    local CP = ProfBuddy.CharacterPanel
    CP:ReleaseAll()
    CP:RenderExpandedRecipes("X-Forever", "Leatherworking",
        { recipes = { ["Alpha"] = { difficulty = "optimal" }, ["Beta"] = { difficulty = "easy" },
                      ["Gamma"] = { difficulty = "trivial" } } }, 0)
    local got = {}
    local pool = CP._pools.recipeRow
    for i = 1, pool.n do got[#got + 1] = rawget(pool.objs[i].nameText, "_text") end
    EXPECT(got[1] == "[+++] Alpha" and got[2] == "[+] Beta" and got[3] == "Gamma",
           "expanded list: " .. table.concat(got, " | "))
    CP:ReleaseAll()
    CVARS.colorblindMode = "0"

    -- Settings: the dropdown shows the saved choice and sets it
    S.colorblindMarkers = "off"
    TSF:OpenSettings("main")
    local dd = TSF.colorblindDD
    EXPECT(dd and rawget(dd.btnText, "_text") == "Colorblind markers: Off", "dropdown text: " .. tostring(dd and rawget(dd.btnText, "_text")))
    local on
    for _, b in ipairs(dd.optionBtns) do if b.value == "On" then on = b end end
    EXPECT(on, "no On option")
    on:GetScript("OnClick")(on)
    EXPECT(S.colorblindMarkers == "on", "choosing On saved " .. tostring(S.colorblindMarkers))
    local auto
    for _, b in ipairs(dd.optionBtns) do if b.value == "Auto (game setting)" then auto = b end end
    auto:GetScript("OnClick")(auto)
    EXPECT(S.colorblindMarkers == "auto", "choosing Auto saved " .. tostring(S.colorblindMarkers))
    TSF:CloseSettings()
end
print("  PASS F62 Colorblind markers: rows, learn tag, gather line and the Characters tab list marked; Auto follows the game; Settings dropdown")

-- F63: Window style on WoW: Forever (feature/ui-themes phase 2). Match the
-- game stays Modern here until Forever's own look exists; the Settings
-- dropdown shows the saved style, saves a new one and offers a reload, and
-- choosing the same style again offers nothing.
do
    local Theme = ProfBuddy.Theme
    local S = ProfBuddy.db.settings
    EXPECT(S.windowStyle == "modern", "default " .. tostring(S.windowStyle))
    S.windowStyle = "game"; Theme._name = nil
    EXPECT(Theme:Name() == "modern", "Match the game on Forever is " .. Theme:Name())
    S.windowStyle = "classic"; Theme._name = nil
    EXPECT(Theme:Name() == "classic", "Classic on Forever is " .. Theme:Name())
    S.windowStyle = "modern"; Theme._name = nil
    EXPECT(Theme:Name() == "modern", "session look")   -- read once, as at login
    local shown = 0
    local oldDialogs, oldShow = StaticPopupDialogs, StaticPopup_Show
    StaticPopupDialogs, StaticPopup_Show = {}, function(n) if n == "PROFBUDDY_RELOAD_STYLE" then shown = shown + 1 end end
    TSF:OpenSettings("main")
    local dd = TSF.windowStyleDD
    EXPECT(dd and rawget(dd.btnText, "_text") == "Window style: Modern", "dropdown text: " .. tostring(dd and rawget(dd.btnText, "_text")))
    local function choose(label)
        for _, b in ipairs(dd.optionBtns) do if b.value == label then b:GetScript("OnClick")(b); return end end
        error("no option " .. label)
    end
    choose("Modern")
    EXPECT(shown == 0 and S.windowStyle == "modern", "same style offered a reload")
    choose("Classic")
    EXPECT(S.windowStyle == "classic" and shown == 1, "Classic saved " .. tostring(S.windowStyle) .. ", offers " .. shown)
    -- Match the game is greyed on Forever: picking it changes nothing,
    -- offers no reload, and hovering it says why
    choose("Match the game")
    EXPECT(S.windowStyle == "classic" and shown == 1, "Match the game was picked on Forever: " .. tostring(S.windowStyle))
    local game
    for _, b in ipairs(dd.optionBtns) do if b.value == "Match the game" then game = b end end
    local col = rawget(game.text, "_color") or {}
    EXPECT(dd.disabledOpts["Match the game"] == "Coming to WoW: Forever in a later update.", "no hover note")
    local hoverText
    local keepSet, keepAdd = GameTooltip.SetText, GameTooltip.AddLine
    rawset(GameTooltip, "AddLine", function(_, t) hoverText = t end)
    game:GetScript("OnEnter")(game)
    rawset(GameTooltip, "AddLine", nil)
    EXPECT(hoverText == "Coming to WoW: Forever in a later update.", "hover note: " .. tostring(hoverText))
    EXPECT(Theme:Name() == "modern", "the session look changed before a reload")
    S.windowStyle = "modern"
    TSF:CloseSettings()
    StaticPopupDialogs, StaticPopup_Show = oldDialogs, oldShow
end
print("  PASS F63 Window style: the dropdown saves the style and offers a reload; Match the game is greyed on Forever with a hover note")

-- F64: Quantity - and + (feature/ui-themes, Zorden 11). Both quantity boxes
-- step by one between 1 and 999; the craft bar's buttons hide and show with
-- its box. Classic selection (Zorden 9): the selected recipe's bar takes the
-- recipe's difficulty color and its name turns white, back to the color
-- when deselected; Modern leaves both alone.
do
    local box, minus, plus = TSF.qtyBox, TSF.qtyMinus, TSF.qtyPlus
    EXPECT(minus and plus, "no craft quantity buttons")
    box:SetText("1")
    minus:GetScript("OnClick")(minus)
    EXPECT(box:GetText() == "1", "minus went below 1: " .. box:GetText())
    plus:GetScript("OnClick")(plus); plus:GetScript("OnClick")(plus)
    EXPECT(box:GetText() == "3", "plus twice from 1 gave " .. box:GetText())
    box:SetText("999")
    plus:GetScript("OnClick")(plus)
    EXPECT(box:GetText() == "999", "plus went past 999: " .. box:GetText())
    minus:GetScript("OnClick")(minus)
    EXPECT(box:GetText() == "998", "minus from 999 gave " .. box:GetText())
    box:SetText("")
    plus:GetScript("OnClick")(plus)
    EXPECT(box:GetText() == "2", "plus on an empty box gave " .. box:GetText())
    box:SetText("1")
    TSF:SetQtyShown(false)
    EXPECT(not box:IsShown() and not minus:IsShown() and not plus:IsShown(), "buttons stayed with the box hidden")
    TSF:SetQtyShown(true)
    EXPECT(box:IsShown() and minus:IsShown() and plus:IsShown(), "buttons did not come back with the box")
    local cq, cplus = TSF.composerQty, TSF.composerQtyPlus
    EXPECT(cq and cplus and TSF.composerQtyMinus, "no Request Craft quantity buttons")
    cq:SetText("4"); cplus:GetScript("OnClick")(cplus)
    EXPECT(cq:GetText() == "5", "Request Craft plus gave " .. cq:GetText())

    local Theme = ProfBuddy.Theme
    local got = {}
    local row = { _dc = { r = 1, g = 0.5, b = 0.25 },
        selectedBg = { Show = function() got.shown = true end, Hide = function() got.shown = false end,
                       SetVertexColor = function(_, r, g, b, a) got.bar = { r, g, b, a } end },
        nameText = { SetTextColor = function(_, r, g, b) got.text = { r, g, b } end } }
    TSF:PaintSelected(row, true)
    EXPECT(got.shown and not got.bar and not got.text, "Modern recolored the selection")
    Theme._name = "classic"
    TSF:PaintSelected(row, true)
    EXPECT(got.bar and got.bar[1] == 1 and got.bar[2] == 0.5 and got.bar[3] == 0.25, "Classic bar not in the difficulty color")
    EXPECT(got.text and got.text[1] == 1 and got.text[2] == 1 and got.text[3] == 1, "Classic selected name not white")
    TSF:PaintSelected(row, false)
    EXPECT(not got.shown and got.text[2] == 0.5, "Classic deselect did not restore the name color")
    Theme._name = nil
end
print("  PASS F64 Quantity - and +: 1 to 999 on both boxes, hidden with the box; Classic selection takes the difficulty color, name white")

-- F65: The enchant Craft button wears Blizzard's red button artwork in both
-- looks (drawn by hand: the template would kill its secure cast). It shows
-- the pressed slices while held, the disabled ones when nothing can be
-- crafted, and never takes UIPanelButtonTemplate.
do
    local eb = TSF.enchantCraftBtn
    EXPECT(eb and eb.look, "no enchant button artwork")
    EXPECT(eb.lookState == "up", "enchant button starts " .. tostring(eb.lookState))
    eb.look("disabled")
    EXPECT(eb.lookState == "disabled", "disabled look")
    local down = eb._h and eb._h.OnMouseDown
    EXPECT(down, "no pressed-state hook")
    down(eb)
    EXPECT(eb.lookState == "disabled", "a disabled button showed pressed")
    eb.look("up"); down(eb)
    EXPECT(eb.lookState == "down", "pressed look")
    eb._h.OnMouseUp(eb)
    EXPECT(eb.lookState == "up", "released look")
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find('CreateFrame%("Button", "ProfBuddyEnchantCraftBtn", parent,%s*"SecureActionButtonTemplate"%)'),
        "the enchant button's template changed")
end
print("  PASS F65 Enchant Craft button: Blizzard's red button artwork, pressed and disabled states, secure template only")

-- F66: Layout shared by both looks (phase 2e). The bottom bar spans the
-- window's inner area (Blizzard's InsetBg), 3 px in for its border, at the
-- same 6 px from the bottom as before; the craft and Request Craft bars are
-- 58 px tall so two 22 px button rows clear the border by 6 px above and
-- below, and the detail pane ends 2 px above them where it did before (90).
do
    local bar = TSF.bottomBar
    local p = bar and rawget(bar, "_lastPoint")
    EXPECT(p and p[1] == "BOTTOMRIGHT" and p[2] == TSF.frame.InsetBg and p[4] == -3 and p[5] == 2,
        "bottom bar is not on the window's inner area")
    EXPECT(rawget(TSF.craftBar, "_size")[2] == 58 and rawget(TSF.composerBar, "_size")[2] == 58,
        "craft bars are not 58 px tall")
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find('detail:SetPoint%("BOTTOMRIGHT", parent, "BOTTOMRIGHT", %-10, 30 %+ CRAFT_BAR_H %+ 2%)'),
        "the detail pane's bottom moved")
    -- The detail pane's scroll area: 4 px in for Modern, 6 for Classic's
    -- thicker border (the harness runs Modern).
    local dsf = TSF.detScrollFrame
    local dp = dsf and rawget(dsf, "_lastPoint")
    EXPECT(dp and dp[1] == "BOTTOMRIGHT" and dp[2] == -24 and dp[3] == 4, "Modern detail scroll area moved")
    EXPECT(src:find('local inset = Theme:IsClassic%(%) and 6 or 4'), "Classic detail scroll inset missing")
    local cp = rawget(TSF.craftBtn, "_lastPoint")
    EXPECT(cp and cp[5] == -6, "the craft bar's first row is not 6 px down: " .. tostring(cp and cp[5]))
end
print("  PASS F66 Bottom bar on the window's inner area; craft and Request Craft bars 58 px tall, detail pane bottom unchanged")

-- F67: Classic recipe list scroll bar, bottom tabs and watermark (Zorden 2,
-- 5 and 8). The knob is Blizzard's classic one with its TexCoords on no
-- track; Classic tabs draw Blizzard's tab pieces in an unselected and a
-- selected set; the watermark shows the profession's icon (Smelting uses
-- Mining's) and hides for anything else, and is never built on Forever.
do
    local Theme = ProfBuddy.Theme
    local cl = Theme.STYLES.classic.fill
    EXPECT(cl.scrollThumb.file == "Interface\\Buttons\\UI-ScrollBar-Knob" and cl.scrollThumb.coords[3] == 0.125,
        "Classic knob")
    EXPECT(cl.scrollTrack[4] == 0, "Classic track not clear")
    Theme._name = "classic"
    local got = {}
    local tex = setmetatable({}, { __index = function(_, m) return function(_, ...) got[m] = { ... } end end })
    Theme:Fill(tex, "scrollThumb")
    EXPECT(got.SetTexCoord and got.SetTexCoord[1] == 0.20 and got.SetTexCoord[4] == 0.875, "knob TexCoords not set")
    -- A recording stand-in for the tab button and its textures
    local rec
    local function recorder(t)
        return setmetatable(t or {}, { __index = function(_, m)
            return function(self, a, b, c, ...)
                if m == "SetTexture" then rec.files[#rec.files + 1] = a end
                if m == "SetAtlas" then rec.atlases[#rec.atlases + 1] = a .. (b and "+size" or "") end
                if m == "SetPoint" and self._piece and (a == "TOPLEFT" or a == "TOPRIGHT") and type(b) == "number" then
                    rec.points[#rec.points + 1] = a .. " " .. b .. "," .. c
                end
                if m == "SetBlendMode" then rec.blend[#rec.blend + 1] = a end
                if m == "SetAlpha" and self._piece then rec.alpha[#rec.alpha + 1] = a end
                if m == "SetPoint" and self._label then rec.textY = c end
            end
        end })
    end
    local function drawTab(flavor)
        rec = { files = {}, atlases = {}, points = {}, blend = {}, alpha = {}, layers = {}, level = nil }
        local keep = ProfBuddy.Source.flavor
        ProfBuddy.Source.flavor = flavor
        local hlTex = recorder({ _piece = true })
        local btn = recorder({
            GetWidth = function() return 90 end,
            GetFrameLevel = function() return 1 end,
            SetFrameLevel = function(_, l) rec.level = l end,
            CreateTexture = function(_, _, layer) rec.layers[#rec.layers + 1] = layer; return recorder({ _piece = true }) end,
            SetHighlightTexture = function(_, f) rec.hlFile = f end,
            GetHighlightTexture = function() return hlTex end,
            SetNormalFontObject = function(_, f) rec.font = f end,
            GetFontString = function() return recorder({ _label = true }) end,
        })
        local normal, selected = Theme:DrawClassicTab(btn)
        ProfBuddy.Source.flavor = keep
        return normal, selected
    end
    local function lastAlphas(n)
        local out = {}
        for i = #rec.alpha - n + 1, #rec.alpha do out[#out + 1] = rec.alpha[i] end
        return table.concat(out, ",")
    end

    -- WoW: Forever draws its own Character window tabs
    -- (PanelTabButtonTemplate): the uiframe-tab atlases at their own sizes,
    -- ends 3/7 out (selected 1/8), a 0.4 hover light from the same pieces,
    -- and no TBC art or button highlight texture
    local normal, selected = drawTab("forever")
    EXPECT(normal and selected and normal.Show and selected.Hide, "tab sets")
    EXPECT(table.concat(rec.atlases, " ") == "uiframe-tab-left+size uiframe-tab-right+size _uiframe-tab-center+size"
        .. " uiframe-activetab-left+size uiframe-activetab-right+size _uiframe-activetab-center+size"
        .. " uiframe-tab-left+size uiframe-tab-right+size _uiframe-tab-center+size",
        "Forever tab atlases: " .. table.concat(rec.atlases, " "))
    EXPECT(table.concat(rec.points, " ") == "TOPLEFT -3,0 TOPRIGHT 7,0 TOPLEFT -1,0 TOPRIGHT 8,0 TOPLEFT -3,0 TOPRIGHT 7,0",
        "Forever tab ends: " .. table.concat(rec.points, " "))
    EXPECT(#rec.files == 0 and rec.hlFile == nil, "Forever tab drew TBC art")
    EXPECT(table.concat(rec.layers, " ") == "BACKGROUND BACKGROUND BACKGROUND BACKGROUND BACKGROUND BACKGROUND HIGHLIGHT HIGHLIGHT HIGHLIGHT"
        and table.concat(rec.blend, " ") == "ADD ADD ADD", "Forever hover light")
    EXPECT(rec.level == 5, "tab not 4 levels above its window")
    selected:Show()
    EXPECT(rec.font == GameFontHighlightSmall and rec.textY == -3, "Forever selected label " .. tostring(rec.textY))
    EXPECT(lastAlphas(3) == "0,0,0", "the selected tab still lights on hover")
    normal:Show()
    EXPECT(rec.font == GameFontNormalSmall and rec.textY == 2, "Forever unselected label " .. tostring(rec.textY))
    EXPECT(lastAlphas(3) == "0.4,0.4,0.4", "an unselected tab does not light on hover: " .. lastAlphas(3))
    local L = Theme:TabLayout()
    EXPECT(L.firstX == 11 and L.gap == 1, "Forever tab spacing")

    -- TBC Classic Anniversary keeps Blizzard's classic tab art and layout
    normal, selected = drawTab("classic")
    EXPECT(rec.files[1] == "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab"
        and rec.files[4] == "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab" and #rec.atlases == 0, "classic tab art")
    EXPECT(table.concat(rec.points, " ") == "TOPLEFT 0,0 TOPLEFT 0,4 TOPLEFT 3,5",
        "TBC Classic Anniversary tab offsets: " .. table.concat(rec.points, " "))
    EXPECT(rec.hlFile == "Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight", "tab highlight")
    selected:Show()
    EXPECT(rec.font == GameFontHighlightSmall and rec.textY == 4, "selected tab label not white and raised")
    EXPECT(lastAlphas(1) == "0", "the selected tab still lights on hover")
    normal:Show()
    EXPECT(rec.font == GameFontNormalSmall and rec.textY == 2, "unselected tab label not gold")
    EXPECT(lastAlphas(1) == "1", "an unselected tab does not light on hover")
    local flavor = ProfBuddy.Source.flavor
    ProfBuddy.Source.flavor = "classic"
    L = Theme:TabLayout()
    ProfBuddy.Source.flavor = flavor
    EXPECT(L.firstX == 8 and L.gap == -15 and L.selectedTextY == 4, "TBC Classic Anniversary tab layout changed")

    -- Classic: the Orders count joins the tab's label ("Orders (1)", centred
    -- as one); Modern keeps a separate badge in the corner.
    local OP = ProfBuddy.OrdersPanel
    local function makeTab()
        local tab = { text = "Orders" }
        tab.GetText = function() return tab.text end
        tab.SetText = function(_, t) tab.text = t end
        tab.CreateFontString = function() return recorder({ SetPoint = function(_, a) tab.pt = a end }) end
        local n = #OP._badges
        local b = OP:CreateBadge(tab)
        table.remove(OP._badges, n + 1)
        return tab, b
    end
    local tab, b = makeTab()
    b:SetText("(1)"); b:Show()
    EXPECT(tab.text == "Orders (1)" and tab.pt == nil, "Classic count not in the label: " .. tab.text)
    b:SetText("(3)")
    EXPECT(tab.text == "Orders (3)", "Classic count did not update: " .. tab.text)
    b:Hide()
    EXPECT(tab.text == "Orders", "Classic label kept the count: " .. tab.text)
    Theme.NO_TEXTURES:Show()
    Theme._name = nil
    tab = makeTab()
    EXPECT(tab.pt == "TOPRIGHT" and tab.text == "Orders", "Modern badge moved")

    EXPECT(TSF.watermark == nil, "a watermark was built on Forever")
    local shown, texFile
    TSF.watermark = { SetTexture = function(_, f) texFile = f end,
                      Show = function() shown = true end, Hide = function() shown = false end }
    local st = TSF.state
    local keep = st.profName
    st.profName = "Smelting"; TSF:UpdateWatermark()
    EXPECT(shown and texFile == "Interface\\Icons\\Trade_Mining", "Smelting watermark: " .. tostring(texFile))
    st.profName = "Tailoring"; TSF:UpdateWatermark()
    EXPECT(shown and texFile == "Interface\\Icons\\Trade_Tailoring", "Tailoring watermark")
    st.profName = "Nothing"; TSF:UpdateWatermark()
    EXPECT(shown == false, "unknown profession kept a watermark")
    st.profName = "Tailoring"; texFile = nil
    TSF:UpdateSkillBar()
    EXPECT(texFile == "Interface\\Icons\\Trade_Tailoring", "a profession switch did not update the watermark")
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find('if Theme:IsClassic%(%) and addon%.Source%.flavor == "classic" then%s+%-%- Classic on TBC Classic Anniversary: a watermark'),
        "the watermark is not limited to Classic on TBC Classic Anniversary")
    st.profName = keep
    TSF.watermark = nil
end
print("  PASS F67 Classic knob and clear track, each client's own tab art (Forever's atlases, TBC's raised tab), profession watermark (none on Forever)")

-- F68: "Held by" on item tooltips. You first with (you), then alts, then
-- friends under their own heading, most held first; "68 (Bags 5, Bank
-- 63)" with a side that holds none dropped. The Show in tooltips boxes
-- gate alts and friends, the slider caps the lines (21 = All) with
-- "... and N more", and no row adds a second holder list.
do
    local DB, DS = ProfBuddy.db, ProfBuddy.DataStore
    local me = ProfBuddy:PlayerKey()
    local ITEM = 2318
    local keep = {}
    for k, v in pairs(DB.characters) do keep[k] = v end
    local myChar = DS:GetCharacter(me)
    local myInv = myChar.inventory
    myChar.inventory = { bags = { [ITEM] = 5 }, bank = { [ITEM] = 63 } }
    DB.characters["Altone-Forever"] = { class = "MAGE", inventory = { bags = {}, bank = { [ITEM] = 63 } } }
    DB.characters["Alttwo-Forever"] = { class = "ROGUE", inventory = { bags = { [ITEM] = 100 }, bank = {} } }
    DB.characters["Pal-Forever"] = { class = "PRIEST", isRemote = true, inventory = { bags = { [ITEM] = 7 }, bank = {} } }
    DB.characters["Empty-Forever"] = { class = "PRIEST", inventory = { bags = {}, bank = {} } }
    rawset(GameTooltip, "AddLine", nil)
    rawset(GameTooltip, "Show", nil)
    local S = DB.settings
    local keepS = { S.showAltInTooltips, S.showRemoteInTooltips, S.tooltipMaxHeldBy }
    S.showAltInTooltips, S.showRemoteInTooltips, S.tooltipMaxHeldBy = true, true, 8

    local function heldBy(lines)
        local out, on = {}, false
        for _, l in ipairs(lines) do
            if type(l) == "string" then
                if l == "Held by (ProfessionBuddy):" then on = true
                elseif on and l ~= " " then out[#out + 1] = l end
            end
        end
        return out
    end
    local h = heldBy(SHOW_ITEM_TOOLTIP(GameTooltip, ITEM))
    EXPECT(#h == 5, "Held by lines: " .. table.concat(h, " / "))
    EXPECT(h[1]:find("68 (Bags 5, Bank 63)", 1, true) and h[1]:find("(you)", 1, true), "you first: " .. tostring(h[1]))
    EXPECT(h[2]:find("Alttwo", 1, true) and h[2]:find("100 (Bags)", 1, true), "biggest alt second: " .. tostring(h[2]))
    EXPECT(h[3]:find("Altone", 1, true) and h[3]:find("63 (Bank)", 1, true), "bank-only alt: " .. tostring(h[3]))
    EXPECT(h[4] == "Friends:" and h[5]:find("Pal", 1, true) and h[5]:find("7 (Bags)", 1, true), "friend under Friends: " .. tostring(h[5]))
    for _, l in ipairs(h) do EXPECT(not l:find("Empty", 1, true), "a character holding none listed") end

    S.tooltipMaxHeldBy = 2
    h = heldBy(SHOW_ITEM_TOOLTIP(GameTooltip, ITEM))
    EXPECT(#h == 3 and h[3]:find("... and 2 more", 1, true), "cap 2: " .. table.concat(h, " / "))
    S.tooltipMaxHeldBy = 21
    h = heldBy(SHOW_ITEM_TOOLTIP(GameTooltip, ITEM))
    EXPECT(#h == 5, "All showed " .. #h)

    S.showRemoteInTooltips = false
    h = heldBy(SHOW_ITEM_TOOLTIP(GameTooltip, ITEM))
    EXPECT(#h == 3 and not table.concat(h, " "):find("Pal", 1, true), "friends with their box off: " .. table.concat(h, " / "))
    S.showAltInTooltips = false
    h = heldBy(SHOW_ITEM_TOOLTIP(GameTooltip, ITEM))
    EXPECT(#h == 0, "Held by with both boxes off")
    S.showAltInTooltips, S.showRemoteInTooltips = true, true

    -- Reagent and Material Calculator rows add no holder list of their own:
    -- hovering one shows the item tooltip and nothing else.
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(not src:find("In bags:", 1, true) and not src:find('AddLine("Held by:"', 1, true)
        and not src:find("_ownHeldBy", 1, true), "a row still adds its own holder list")

    -- Settings: the slider shows and saves the cap, 21 = All
    TSF:OpenSettings("main")
    local sl = TSF.heldBySlider
    EXPECT(sl and TSF.heldByLabel, "no Held by slider")
    sl:GetScript("OnValueChanged")(sl, 21)
    EXPECT(S.tooltipMaxHeldBy == 21 and rawget(TSF.heldByLabel, "_text") == "Held by: All", "slider All: " .. tostring(rawget(TSF.heldByLabel, "_text")))
    sl:GetScript("OnValueChanged")(sl, 5)
    EXPECT(S.tooltipMaxHeldBy == 5 and rawget(TSF.heldByLabel, "_text") == "Held by: 5", "slider 5")
    TSF:CloseSettings()

    S.showAltInTooltips, S.showRemoteInTooltips, S.tooltipMaxHeldBy = keepS[1], keepS[2], keepS[3]
    myChar.inventory = myInv
    for k in pairs(DB.characters) do if not keep[k] then DB.characters[k] = nil end end
end
print("  PASS F68 Held by on item tooltips: you, alts and friends with bag and bank counts, the cap and All, the Show in tooltips boxes, one list everywhere, Settings slider")

-- F69: the Item Info box keeps its own look under tooltip skins. It is
-- marked IsEmbedded, which ElvUI's tooltip styling skips, and PB draws the
-- tooltip border behind it (itemInfoBox), one level below the box, shown
-- and hidden with it. Match the game is greyed only on Forever.
do
    local tip, box = TSF.embeddedTip, TSF.itemInfoBox
    EXPECT(tip.IsEmbedded == true, "Item Info box not marked IsEmbedded")
    EXPECT(box, "no border frame behind the Item Info box")
    local tsrc = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(tsrc:find("embeddedTip:SetFrameLevel%(box:GetFrameLevel%(%) %+ 1%)"), "the border is not just below the box")
    tip:Show()
    if tip._h and tip._h.OnShow then tip._h.OnShow(tip) end
    EXPECT(box:IsShown(), "border not shown with the box")
    tip:Hide()
    if tip._h and tip._h.OnHide then tip._h.OnHide(tip) end
    EXPECT(not box:IsShown(), "border stayed after the box hid")
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find('if addon%.Source%.flavor == "forever" then%s+styleDD:SetOptionDisabled'), "Match the game greyed outside Forever")
end
print("  PASS F69 Item Info box marked IsEmbedded, PB's border behind it shows and hides with it; Match the game greyed on Forever only")

-- F70: the detail panel's Held by block reads like the Held by tooltip:
-- you first with (you), then alts, then friends under "Friends:", most held
-- first (Altone before Aalt), counts as "68 (Bags 5, Bank 63)"; the viewed
-- character left out.
do
    local TSF = ProfBuddy.TradeSkillFrame
    local db, S = ProfBuddy.db, ProfBuddy.db.settings
    local me = ProfBuddy:PlayerKey()
    local chars = db.characters
    local myInv, fac = chars[me].inventory, chars[me].faction
    local keepAlt, keepRemote, keepView = S.showAltInDetail, S.showRemoteInDetail, TSF.state._viewCharKey
    local added = {}
    local function add(key, t) t.faction = t.faction or fac; t.professions = {}; chars[key] = t; added[#added + 1] = key end
    chars[me].inventory = { bags = { [2589] = 2 }, bank = {} }
    add("Altone", { class = "WARRIOR", inventory = { bags = { [2589] = 5, [2592] = 3 }, bank = { [2589] = 63 } } })
    add("Aalt", { class = "MAGE", inventory = { bags = {}, bank = { [2589] = 1 } } })
    add("Pal", { class = "PRIEST", isRemote = true, inventory = { bags = { [2589] = 40 }, bank = { [2589] = 100 } } })
    add("Viewed", { class = "ROGUE", isRemote = true, inventory = { bags = { [2589] = 9 } } })
    add("Nothing", { class = "ROGUE", inventory = { bags = { [9999] = 9 } } })
    local recipe = { reagents = { { itemID = 2589, name = "Linen Cloth" }, { itemID = 2592, name = "Wool Cloth" } } }
    local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    local function show(viewKey)
        TSF.state._viewCharKey = viewKey
        TSF.altHeader:Hide()
        for _, l in ipairs(TSF.altLines) do l:Hide() end
        TSF:ShowAltMaterials(recipe)
        local out = {}
        for _, l in ipairs(TSF.altLines) do
            if l:IsShown() then
                local x = rawget(l, "_lastPoint")[4]
                out[#out + 1] = (x == 14 and "  " or "") .. plain(rawget(l, "_text"))
            end
        end
        return out, TSF.altHeader:IsShown()
    end
    local youName = ProfBuddy:ShortName(me)
    S.showAltInDetail, S.showRemoteInDetail = true, true
    local got = show("Viewed")
    local want = { "  " .. youName .. " (you)  Linen Cloth 2 (Bags)",
                   "  Altone  Linen Cloth 68 (Bags 5, Bank 63), Wool Cloth 3 (Bags)",
                   "  Aalt  Linen Cloth 1 (Bank)",
                   "Friends:",
                   "  Pal  Linen Cloth 140 (Bags 40, Bank 100)" }
    EXPECT(table.concat(got, "|") == table.concat(want, "|"), "Held by panel:\n" .. table.concat(got, "\n"))

    -- your own profession: you are the viewed character, so you are left out
    got = show(nil)
    EXPECT(got[1] == "  Altone  Linen Cloth 68 (Bags 5, Bank 63), Wool Cloth 3 (Bags)" and #got == 5
           and got[4] == "  Pal  Linen Cloth 140 (Bags 40, Bank 100)" and got[5]:find("^  Viewed"),
           "own profession:\n" .. table.concat(got, "\n"))

    -- the boxes: alts off keeps you and friends; both off hides the section
    S.showAltInDetail = false
    got = show("Viewed")
    EXPECT(#got == 3 and got[1]:find("%(you%)") and got[2] == "Friends:", "alts off:\n" .. table.concat(got, "\n"))
    S.showRemoteInDetail = false
    local shown
    got, shown = show("Viewed")
    EXPECT(#got == 0 and not shown, "both off still shows the section")
    S.showAltInDetail, S.showRemoteInDetail = true, true

    -- more characters than lines: the last line says how many are left
    for i = 1, 20 do add(string.format("Many%02d", i), { class = "MAGE", inventory = { bags = { [2589] = 1 }, bank = {} } }) end
    got = show("Viewed")
    -- you, Altone, then Aalt and Many01-Many20 (1 each, by key), Friends:
    -- and Pal: 25 lines, 24 of them characters. 13 lines show, so the last
    -- counts the 11 characters left (the heading is not one).
    EXPECT(#TSF.altLines == 14 and #got == 14 and got[13] == "  Many10  Linen Cloth 1 (Bags)"
           and got[14] == "  ... and 11 more",
           "overflow:\n" .. table.concat(got, "\n"))

    for _, k in ipairs(added) do chars[k] = nil end
    chars[me].inventory = myInv
    S.showAltInDetail, S.showRemoteInDetail, TSF.state._viewCharKey = keepAlt, keepRemote, keepView
end
print("  PASS F70 detail panel Held by: you first (you), alts, then Friends, most held first, tooltip counts; viewed character left out; boxes; overflow")

-- F71: right-click a guildmate's row for PB's own menu: Whisper and Invite
-- to group, using the roster's name; nothing on a left click or an empty row
do
    local GP = ProfBuddy.GuildPanel
    local told, invited = {}, {}
    local keepCFU, keepPI = ChatFrameUtil.SendTell, rawget(_G, "C_PartyInfo")
    ChatFrameUtil.SendTell = function(name) told[#told + 1] = name end
    C_PartyInfo = { InviteUnit = function(name) invited[#invited + 1] = name end }
    local row = GP:CreateRow(UIParent)
    local up = row:GetScript("OnMouseUp")
    EXPECT(up, "guild rows have no click handler")
    row._member = false   -- an empty row (the stub frames answer any unset field)
    up(row, "RightButton")
    EXPECT(not GP._memberMenu or not GP._memberMenu:IsShown(), "an empty row opened the menu")
    row._member = { name = "Noodle Stand", charKey = "Noodle Stand-Forever", online = true }
    up(row, "LeftButton")
    EXPECT(not GP._memberMenu or not GP._memberMenu:IsShown(), "a left click opened the menu")
    up(row, "RightButton")
    local m = GP._memberMenu
    EXPECT(m and m:IsShown(), "right-click did not open the menu")
    EXPECT(rawget(m.title, "_text") == "Noodle Stand", "menu title " .. tostring(rawget(m.title, "_text")))
    EXPECT(#m.buttons == 2 and rawget(m.buttons[1].text, "_text") == "Whisper"
           and rawget(m.buttons[2].text, "_text") == "Invite to group", "menu items")
    m.buttons[1]:GetScript("OnClick")(m.buttons[1])
    EXPECT(told[1] == "Noodle Stand" and not m:IsShown(), "Whisper: " .. tostring(told[1]))
    up(row, "RightButton")
    m.buttons[2]:GetScript("OnClick")(m.buttons[2])
    EXPECT(invited[1] == "Noodle Stand" and not m:IsShown(), "Invite: " .. tostring(invited[1]))
    up(row, "RightButton")
    ProfBuddy.CloseAllPopups()   -- the main window hiding or a tab switch
    EXPECT(not m:IsShown(), "the guild menu stays open when the window hides")
    -- greyed when they cannot work: offline, yourself, Invite when grouped
    local function usable() return m.buttons[1]:IsEnabled() and true or false, m.buttons[2]:IsEnabled() and true or false end
    up(row, "RightButton")
    local w, i = usable()
    EXPECT(w and i, "an online guildmate's actions greyed")
    m:Hide()
    row._member = { name = "Noodle Stand", charKey = "Noodle Stand-Forever", online = false }
    up(row, "RightButton"); w, i = usable()
    EXPECT(m:IsShown() and not w and not i, "an offline guildmate's Whisper or Invite not greyed")
    m:Hide()
    local me = ProfBuddy:PlayerKey()
    row._member = { name = me, charKey = me, online = true }
    up(row, "RightButton"); w, i = usable()
    EXPECT(not w and not i, "your own Whisper or Invite not greyed")
    m:Hide()
    local keepUIP, keepUIR = rawget(_G, "UnitInParty"), rawget(_G, "UnitInRaid")
    UnitInParty = function(n) return n == "Noodle Stand" end
    UnitInRaid = function() return nil end
    row._member = { name = "Noodle Stand-Forever", charKey = "Noodle Stand-Forever", online = true }
    up(row, "RightButton"); w, i = usable()
    EXPECT(w and not i, "Invite not greyed for a guildmate in your group")
    m:Hide()
    UnitInParty, UnitInRaid = keepUIP, keepUIR
    local csrc = assert(io.open(PB_BASE .. "/Core.lua")):read("*a")
    EXPECT(csrc:find('title:SetText("ProfessionBuddy Bug Report")', 1, true)
           and csrc:find('"== ProfessionBuddy Bug Report =="', 1, true), "bug report window title and text differ")
    local osrc = assert(io.open(PB_BASE .. "/UI/OrdersPanel.lua")):read("*a")
    EXPECT(osrc:find('split     = "Split or discuss"', 1, true), "order details do not say Split or discuss")
    local src = assert(io.open(PB_BASE .. "/UI/GuildPanel.lua")):read("*a")
    EXPECT(not src:find("UnitPopup", 1, true) and not src:find("ToggleDropDownMenu", 1, true),
           "the guild menu uses Blizzard's unit menu")
    ChatFrameUtil.SendTell, C_PartyInfo = keepCFU, keepPI
end
print("  PASS F71 guild row right-click: PB's menu with Whisper and Invite to group, roster name, closes after a pick and with the window, greyed offline, for yourself, and Invite when grouped")

-- F72: the profession link button (WoW: Forever), as in Blizzard's own
-- window: the bar is always shorter by its room; it shows for your own live
-- profession only; its menu lists Guild, Party, Raid and joined channels;
-- a pick opens the chat box with "/g <link>"; a click types the link only
-- into an open chat box. Then recipe-row shift-click: Share's link, or
-- Share's "still loading" line instead of selecting.
do
    local TSF = ProfBuddy.TradeSkillFrame
    local st = TSF.state
    local btn = TSF.linkButton
    EXPECT(btn, "no link button on Forever")
    local bw = rawget(TSF.skillBar, "_size")[1]
    EXPECT(bw == 740 - 24 - 27, "skill bar width " .. tostring(bw))
    local p = rawget(btn, "_lastPoint")
    EXPECT(p and p[1] == "LEFT" and p[3] == "RIGHT" and p[4] == 4, "link button not right of the bar")
    EXPECT(rawget(btn, "_size")[1] == 23, "link button size")

    local T = C_TradeSkillUI
    local keep = { T.CanTradeSkillListLink, T.GetTradeSkillListLink, T.IsNPCCrafting, T.IsTradeSkillLinked }
    local can = true
    T.CanTradeSkillListLink = function() return can end
    T.GetTradeSkillListLink = function() return "|cffffd000|Htrade:Player-1-00000001:165:393|h[Leatherworking]|h|r" end
    T.IsNPCCrafting = function() return false end
    T.IsTradeSkillLinked = function() return false end
    local save = { st._viewCharKey, st._isStaticView, st._isLinkedView, st.isCraftWindow }
    st._viewCharKey, st._isStaticView, st._isLinkedView, st.isCraftWindow = nil, false, false, false
    TSF:UpdateLinkButton()
    EXPECT(btn:IsShown(), "no link button on your own profession")
    st._viewCharKey = "Alt-Forever"; TSF:UpdateLinkButton()
    EXPECT(not btn:IsShown(), "link button on an alt's profession")
    st._viewCharKey, st._isStaticView = nil, true; TSF:UpdateLinkButton()
    EXPECT(not btn:IsShown(), "link button on a profession not learned")
    st._isStaticView, st._isLinkedView = false, true; TSF:UpdateLinkButton()
    EXPECT(not btn:IsShown(), "link button on a linked profession")
    st._isLinkedView = false; can = false; TSF:UpdateLinkButton()
    EXPECT(not btn:IsShown(), "link button when the game says it cannot link")
    can = true; TSF:UpdateLinkButton()
    EXPECT(rawget(TSF.skillBar, "_size")[1] == bw, "the skill bar width changed")

    -- the menu (the client's own strings, GlobalStrings build 70790)
    TRADESKILL_POST, GUILD, PARTY, RAID = "Post in chat", "Guild", "Party", "Raid"
    SLASH_GUILD1, SLASH_PARTY1, SLASH_RAID1 = "/g", "/p", "/raid"
    local keepG, keepCL = IsInGuild, GetChannelList
    IsInGuild = function() return true end
    GetChannelList = function() return 1, "General", false, 2, "Trade", true end
    local opened
    local keepOpen = ChatFrameUtil.OpenChat
    ChatFrameUtil.OpenChat = function(text) opened = text end
    local items, title = {}, nil
    local root = {
        CreateTitle = function(_, t) title = t end,
        CreateButton = function(_, text, fn)
            local it = { text = text, fn = fn }
            function it:SetEnabled(e) self.enabled = e end
            items[#items + 1] = it
            return it
        end,
    }
    TSF:FillLinkMenu(root)
    local names = {}
    for _, it in ipairs(items) do names[#names + 1] = tostring(it.text) .. (it.enabled and "" or "(off)") end
    EXPECT(title == "Post in chat", "menu title " .. tostring(title))
    EXPECT(#items == 5 and items[1].enabled and not items[2].enabled and not items[3].enabled
           and items[4].enabled and not items[5].enabled, "menu items: " .. table.concat(names, ", "))
    items[1].fn()
    EXPECT(opened and opened:find("^/g |cffffd000|Htrade:", 1), "Guild pick opened " .. tostring(opened))

    -- a click types the link only into an open chat box (macro editor closed)
    MacroFrameText = { IsShown = function() return false end }
    local keepAW = ChatFrameUtil.GetActiveWindow
    local n0 = 0
    for _, c in ipairs(CALLS) do if c == "ChatFrameUtil.InsertLink" then n0 = n0 + 1 end end
    ChatFrameUtil.GetActiveWindow = function() return nil end
    btn:GetScript("OnClick")(btn)
    ChatFrameUtil.GetActiveWindow = function() return {} end
    btn:GetScript("OnClick")(btn)
    local n1 = 0
    for _, c in ipairs(CALLS) do if c == "ChatFrameUtil.InsertLink" then n1 = n1 + 1 end end
    EXPECT(n1 - n0 == 1, "the click typed the link " .. (n1 - n0) .. " times")
    ChatFrameUtil.GetActiveWindow, ChatFrameUtil.OpenChat = keepAW, keepOpen
    IsInGuild, GetChannelList = keepG, keepCL
    T.CanTradeSkillListLink, T.GetTradeSkillListLink, T.IsNPCCrafting, T.IsTradeSkillLinked = keep[1], keep[2], keep[3], keep[4]
    st._viewCharKey, st._isStaticView, st._isLinkedView, st.isCraftWindow = save[1], save[2], save[3], save[4]
    TSF:UpdateLinkButton()

    -- the background fills the button and the icon is centred, as Blizzard's
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find('local bg = btn:CreateTexture%(nil, "BACKGROUND"%)%s+bg:SetAllPoints%(%)%s+local icon = btn:CreateTexture')
           and not src:find('square%-normal", true%)'), "link button background does not fill the button")
    -- shift-click on a recipe row: Share's link, or Share's loading line
    EXPECT(src:find('if IsModifiedClick%("CHATLINK"%) then%s+local chatLink = self:RecipeChatLink%(entry%)'),
           "row shift-click does not use Share's link")
    local row = TSF.listRows and TSF.listRows[1]
    local firstReal
    for idx, e in ipairs(st.recipes or {}) do if not e.isHeader then firstReal = idx; break end end
    EXPECT(row and firstReal, "no recipe row to click")
    local keepOff, keepMod, keepRCL = st.scrollOffset, IsModifiedClick, TSF.RecipeChatLink
    st.scrollOffset = firstReal - 1
    IsModifiedClick = function(k) return k == "CHATLINK" end
    TSF.RecipeChatLink = function() return nil end
    local before = st.selected
    st.selected = "nothing"
    PRINTS = {}
    row:GetScript("OnClick")(row)
    EXPECT(PRINTED("still loading; try again in a moment."), "no loading line on shift-click")
    EXPECT(st.selected == "nothing", "a loading shift-click selected the recipe")
    TSF.RecipeChatLink = keepRCL
    local n2 = 0
    for _, c in ipairs(CALLS) do if c == "ChatFrameUtil.InsertLink" then n2 = n2 + 1 end end
    row:GetScript("OnClick")(row)
    local n3 = 0
    for _, c in ipairs(CALLS) do if c == "ChatFrameUtil.InsertLink" then n3 = n3 + 1 end end
    EXPECT(n3 - n2 == 1, "shift-click did not type the link")
    -- the stub chat box takes nothing (no open chat box), so the click went
    -- on to select the recipe, as an unmodified click does
    EXPECT(st.selected == st.recipes[firstReal].name, "shift-click with no chat box did not select the recipe")
    IsModifiedClick, st.scrollOffset, st.selected = keepMod, keepOff, before
end
print("  PASS F72 profession link button: fixed bar, own live profession only, Blizzard's menu and click; row shift-click uses Share's link and loading line")

-- F73: drag to scale. Both windows have the grip; scales stay in 75-150%;
-- the top-left corner stays put; a drag scales by the farther of the two
-- directions and saves on release; right-click goes back to 100%; nothing
-- changes in combat; a saved scale is applied when the window is built, and
-- the Material Calculator follows the profession window.
do
    local UI, TSF, S = ProfBuddy.UI, ProfBuddy.TradeSkillFrame, ProfBuddy.db.settings
    EXPECT(UI.scaleGrip and TSF.scaleGrip, "a window has no scale grip")
    EXPECT(UI:ClampScale(0.5) == 0.75 and UI:ClampScale(2) == 1.5 and UI:ClampScale(1.234) == 1.23
           and UI:ClampScale(nil) == 1, "scale limits")
    local function fakeWindow(left, top, w, h)
        local f = CreateFrame("Frame", nil, UIParent)
        local st = { scale = 1, left = left, top = top }
        rawset(f, "GetScale", function() return st.scale end)
        rawset(f, "SetScale", function(_, v) st.scale = v end)
        rawset(f, "GetLeft", function() return st.left / st.scale end)
        rawset(f, "GetTop", function() return st.top / st.scale end)
        rawset(f, "GetWidth", function() return w end)
        rawset(f, "GetHeight", function() return h end)
        rawset(f, "SetPoint", function(_, p, rel, rp, x, y) st.point = { p, rp, x, y }; st.left, st.top = x * st.scale, y * st.scale end)
        return f, st
    end
    local keepW, keepH = rawget(UIParent, "GetWidth"), rawget(UIParent, "GetHeight")
    local screenW, screenH = 1920, 1080
    rawset(UIParent, "GetWidth", function() return screenW end)
    rawset(UIParent, "GetHeight", function() return screenH end)
    local follower = { SetScale = function(self, v) self.scale = v end }
    local win, st = fakeWindow(100, 500, 740, 540)
    EXPECT(UI:ApplyScale(win, 1.5, { follower }) and st.scale == 1.5 and follower.scale == 1.5, "scale not applied")
    EXPECT(st.point[1] == "TOPLEFT" and st.point[2] == "BOTTOMLEFT"
           and math.abs(st.left - 100) < 0.01 and math.abs(st.top - 500) < 0.01, "the top-left corner moved")
    local keepCombat = InCombatLockdown
    InCombatLockdown = function() return true end
    EXPECT(UI:ApplyScale(win, 1, { follower }) == false and st.scale == 1.5, "scaled in combat")
    InCombatLockdown = keepCombat

    -- a drag on a grip, then right-click
    local win2, st2 = fakeWindow(100, 500, 740, 540)
    local follower2 = { SetScale = function(self, v) self.scale = v end }
    S.testScale = nil
    local grip = UI:AddScaleGrip(win2, "testScale", { follower2 })
    rawset(UIParent, "GetEffectiveScale", function() return 1 end)
    -- pressed 7 px inside the corner, as on the grip: no change until it moves
    local cx, cy = 100 + 740 - 7, 500 - 540 + 7
    GetCursorPosition = function() return cx, cy end
    grip:GetScript("OnMouseDown")(grip, "LeftButton")
    grip:GetScript("OnUpdate")(grip)
    EXPECT(st2.scale == 1 and follower2.scale == nil, "a press without a move changed the size: " .. tostring(st2.scale))
    cx, cy = 100 + 733 * 1.2, 500 - 533 * 1.1
    grip:GetScript("OnUpdate")(grip)
    EXPECT(math.abs(st2.scale - 1.2) < 0.001 and follower2.scale == st2.scale, "drag scale " .. tostring(st2.scale))
    grip:GetScript("OnMouseUp")(grip)
    EXPECT(S.testScale == 1.2, "drag not saved: " .. tostring(S.testScale))
    -- a press and release without a move saves the size unchanged
    grip:GetScript("OnMouseDown")(grip, "LeftButton")
    grip:GetScript("OnUpdate")(grip)
    grip:GetScript("OnMouseUp")(grip)
    EXPECT(S.testScale == 1.2 and st2.scale == 1.2, "a click on the grip changed the size: " .. tostring(st2.scale))
    grip:GetScript("OnMouseDown")(grip, "LeftButton")
    cx, cy = 100 + 740 * 4, 500 - 540 * 4
    grip:GetScript("OnUpdate")(grip)
    grip:GetScript("OnMouseUp")(grip)
    EXPECT(S.testScale == 1.5, "drag past the limit saved " .. tostring(S.testScale))
    grip:GetScript("OnClick")(grip, "RightButton")
    EXPECT(st2.scale == 1 and S.testScale == 1, "right-click did not reset to 100%")
    InCombatLockdown = function() return true end
    grip:GetScript("OnMouseDown")(grip, "LeftButton")
    EXPECT(not grip:GetScript("OnUpdate"), "a drag started in combat")
    InCombatLockdown = keepCombat

    -- a saved scale applies when the window is built
    local win3, st3 = fakeWindow(100, 500, 740, 540)
    S.testScale = 1.3
    UI:AddScaleGrip(win3, "testScale")
    EXPECT(st3.scale == 1.3, "saved scale not applied at build: " .. tostring(st3.scale))
    -- built in combat: no scale then; it applies on the next open after combat
    local win4, st4 = fakeWindow(100, 500, 740, 540)
    InCombatLockdown = function() return true end
    UI:AddScaleGrip(win4, "testScale")
    EXPECT(st4.scale == 1, "scaled in combat at build")
    InCombatLockdown = keepCombat
    rawget(win4, "_h").OnShow(win4)
    EXPECT(st4.scale == 1.3, "saved scale not applied on the next open: " .. tostring(st4.scale))
    -- never bigger than the screen: 540 tall on a 768 tall screen stops at 1.42
    screenH = 768
    EXPECT(UI:FitScale(win, 1.5) == 1.42 and UI:FitScale(win, 1.2) == 1.2, "scale not capped to the screen")
    local win5, st5 = fakeWindow(100, 700, 740, 540)
    S.testScale = 1
    local grip5 = UI:AddScaleGrip(win5, "testScale")
    GetCursorPosition = function() return 100 + 733, 700 - 533 end
    grip5:GetScript("OnMouseDown")(grip5, "LeftButton")
    GetCursorPosition = function() return 100 + 733 * 1.5, 700 - 533 end   -- sideways
    grip5:GetScript("OnUpdate")(grip5)
    grip5:GetScript("OnMouseUp")(grip5)
    EXPECT(st5.scale == 1.42 and S.testScale == 1.42, "a sideways drag made the window taller than the screen: " .. tostring(st5.scale))
    S.testScale = 1.5
    rawget(win5, "_h").OnShow(win5)
    EXPECT(st5.scale == 1.42, "a saved scale bigger than the screen applied: " .. tostring(st5.scale))
    rawset(UIParent, "GetWidth", keepW); rawset(UIParent, "GetHeight", keepH)
    -- a dropdown list (UIParent's child) opens at the button and the window's
    -- size when the window is scaled
    local dd = TSF.sortDropdown
    local keepES = rawget(UIParent, "GetEffectiveScale")
    rawset(dd.btn, "GetEffectiveScale", function() return 1.5 end)
    rawset(UIParent, "GetEffectiveScale", function() return 1 end)
    rawset(dd.btn, "GetCenter", function() return 300, 400 end)
    rawset(dd.btn, "GetWidth", function() return 140 end)
    rawset(dd.btn, "GetRect", function() return 230, 390, 140, 20 end)
    local lp
    rawset(dd.listFrame, "SetPoint", function(_, ...) lp = { ... } end)
    rawset(dd.listFrame, "SetScale", function(self, v) rawset(self, "_scale", v) end)
    dd.btn:GetScript("OnClick")(dd.btn)
    EXPECT(rawget(dd.listFrame, "_scale") == 1.5 and lp and lp[4] == 230 and lp[5] == 390,
           "a dropdown list does not follow the window's scale")
    dd.listFrame:Hide()
    for _, k in ipairs({ "GetEffectiveScale", "GetCenter", "GetWidth", "GetRect" }) do rawset(dd.btn, k, nil) end
    rawset(dd.listFrame, "SetPoint", nil); rawset(dd.listFrame, "SetScale", nil)
    -- small menus take the size of the control they open from
    local menu, anchor = CreateFrame("Frame", nil, UIParent), CreateFrame("Button", nil, UIParent)
    rawset(anchor, "GetEffectiveScale", function() return 1.3 end)
    rawset(menu, "SetScale", function(self, v) rawset(self, "_scale", v) end)
    UI:MatchScale(menu, anchor)
    EXPECT(rawget(menu, "_scale") == 1.3, "a menu does not take its window's size")
    for file, n in pairs({ ["UI/TradeSkillFrame.lua"] = 1, ["UI/GuildPanel.lua"] = 1, ["UI/OrdersPanel.lua"] = 1,
                           ["UI/FriendsPanel.lua"] = 1, ["UI/MailHelper.lua"] = 1 }) do
        local fsrc = assert(io.open(PB_BASE .. "/" .. file)):read("*a")
        local _, c = fsrc:gsub("UI:MatchScale%(m, ", "")
        EXPECT(c == n, file .. ": a menu does not take its window's size")
    end
    rawset(UIParent, "GetEffectiveScale", keepES)
    -- Order History and Find a Crafter follow the main window's size
    local OP = ProfBuddy.OrdersPanel
    OP:BuildHistoryPanel(); OP:BuildFindPanel()
    local found = 0
    for _, fl in ipairs(UI.scaleFollowers) do
        if fl == OP.histFrame or fl == OP.findFrame then found = found + 1 end
    end
    EXPECT(found == 2, "Order History and Find a Crafter do not scale with the main window")
    rawset(UI.frame, "GetScale", function() return 1.3 end)
    for _, pf in ipairs({ OP.histFrame, OP.findFrame }) do
        rawset(pf, "SetScale", function(self, v) rawset(self, "_scale", v) end)
        pf:GetScript("OnShow")(pf)
        EXPECT(rawget(pf, "_scale") == 1.3, "a side panel opened at the wrong size")
        rawset(pf, "SetScale", nil)
    end
    rawset(UI.frame, "GetScale", nil)
    S.testScale = nil
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(not src:find('targetName = "grey"', 1, true) and src:find('targetName = "gray"', 1, true),
           'the Skill-ups range still reads "to grey"')
    EXPECT(src:find('AddScaleGrip%(f, "professionWindowScale", { self%.calcPanel }%)'),
           "the Material Calculator does not follow the profession window's scale")
end
print("  PASS F73 drag to scale: both windows, 75-150%, top-left kept, drag and release save, a press alone keeps the size, right-click resets, not in combat, never bigger than the screen, dropdown lists, menus and side panels follow, applied at build")

-- F74: "Disenchants into" on item tooltips (Data/Forever/Disenchant.lua,
-- from VMaNGOS): the materials with count and chance, below Held by, on
-- every character; no "Requires Enchanting" line on Forever; nothing for an
-- item the data does not list; the Settings box turns it off.
do
    local D, TSF, S = ProfBuddy.Disenchant, ProfBuddy.TradeSkillFrame, ProfBuddy.db.settings
    EXPECT(D and D.source:find("^VMaNGOS db ") and D.groups and D.materials, "Forever disenchant data not loaded")
    for _, g in pairs(D.groups) do EXPECT(g.skill == nil, "a Forever group carries a skill") end
    local g = TSF:DisenchantGroup(821)
    EXPECT(g and g.loot[1][1] == 10940, "item 821 is not in the Strange Dust group")
    rawset(GameTooltip, "AddLine", nil); rawset(GameTooltip, "AddDoubleLine", nil); rawset(GameTooltip, "Show", nil)
    local lines = SHOW_ITEM_TOOLTIP(GameTooltip, 821)
    local head, dust
    for i, l in ipairs(lines) do
        if l == "Disenchants into (ProfessionBuddy):" then head = i end
        if type(l) == "string" and l:find("Strange Dust 1-2 | 80%", 1, true) then dust = i end
    end
    EXPECT(head and dust and dust > head, "no disenchant section on item 821: " .. table.concat(lines, " / "))
    for _, l in ipairs(lines) do
        EXPECT(not tostring(l):find("Requires Enchanting", 1, true), "a skill line on Forever")
        EXPECT(not tostring(l):find("| estimate", 1, true), "a listed item says estimate")
    end
    -- an item the 1.12 database does not list, placed by Forever's own
    -- disenchant groups: the same section, marked estimate
    local estID, estGroup
    for _, eg in pairs(D.groups) do
        if eg.estimates and eg.estimates[1] then estID, estGroup = eg.estimates[1], eg; break end
    end
    EXPECT(estID, "no Forever estimates baked")
    for _, eg in pairs(D.groups) do
        for _, id in ipairs(eg.items) do EXPECT(id ~= estID, "an estimate is also listed") end
    end
    local g2, isEst = TSF:DisenchantGroup(estID)
    EXPECT(g2 == estGroup and isEst == true, "estimate not found as an estimate")
    lines = SHOW_ITEM_TOOLTIP(GameTooltip, estID)
    local estHead
    for _, l in ipairs(lines) do if l == "Disenchants into (ProfessionBuddy): | estimate" then estHead = true end end
    EXPECT(estHead, "estimate item " .. estID .. ": " .. table.concat(lines, " / "))
    lines = SHOW_ITEM_TOOLTIP(GameTooltip, 2589)
    for _, l in ipairs(lines) do EXPECT(not tostring(l):find("Disenchants into", 1, true), "Linen Cloth disenchants") end
    S.tooltipShowDisenchant = false
    lines = SHOW_ITEM_TOOLTIP(GameTooltip, 821)
    for _, l in ipairs(lines) do EXPECT(not tostring(l):find("Disenchants into", 1, true), "the setting did not turn it off") end
    S.tooltipShowDisenchant = true
    local found
    TSF:OpenSettings("main")
    for _, cb in ipairs(TSF.settingsCheckboxes) do if cb.settingKey == "tooltipShowDisenchant" then found = cb end end
    EXPECT(found, "no Show disenchant results box in Settings")
end
print("  PASS F74 Disenchants into: materials, counts and chances on every character, no skill line on Forever, Forever estimates marked, other items skipped, Settings box")

-- F75: skill-up ranges at the trainer (UI/Trainer.lua). Blizzard's row
-- builder, loaded with the trainer window, gets the four colored numbers
-- after its Requires line for a recipe you have not learned; the row's
-- tooltip gets the labeled line with your tier marked; known recipes, a
-- weapon master, a profession rank and the setting off add nothing
do
    local TR, S = ProfBuddy.Trainer, ProfBuddy.db.settings
    EXPECT(TR and S.trainerShowRanges == true, "no Trainer module or the setting is not on by default")
    -- Blizzard_TrainerUI loads: its row builder sets the Requires line
    ClassTrainerFrame_InitServiceButton = function(button, elementData)
        local i = (elementData.data or elementData).skillIndex
        local _, rank = GetTrainerServiceSkillReq(i)
        button.subText:SetText(rank and rank > 0 and ("Requires: Leatherworking (" .. rank .. ")") or "")
    end
    FIRE("ADDON_LOADED", "Blizzard_TrainerUI")
    -- the row's Requires line is 240 wide; a character is 4 wide here
    local charW = 4
    local function row(i)
        local b = CreateFrame("Button", nil, UIParent)
        local fs = b:CreateFontString()
        rawset(fs, "GetWidth", function() return 240 end)
        rawset(fs, "GetUnboundedStringWidth", function(self)
            return #(self:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * charW
        end)
        rawset(b, "subText", fs)
        ClassTrainerFrame_InitServiceButton(b, { data = { skillIndex = i } })
        return fs:GetText()
    end
    local function index(name)
        for i = 1, GetNumTrainerServices() do if GetTrainerServiceInfo(i) == name then return i end end
    end
    TRAINER_FILTER.used = true
    TRAINER_OPEN(3008)                  -- Mak, Leatherworking
    local belt = index("Handstitched Leather Belt")
    -- yellow, green and grey inside Blizzard's parentheses, after its learn level
    EXPECT(row(belt) == "Requires: Leatherworking (25 |cffffff0055|r |cff00ff0070|r |cff80808085|r)",
           "row: " .. tostring(row(belt)))
    -- the row builder runs on every scroll: the numbers never double
    EXPECT(select(2, row(belt):gsub("|cffffff00", "")) == 1, "the numbers doubled")
    -- a learn level you are below: Blizzard's red stays on its number
    local redLine
    do
        local b = CreateFrame("Button", nil, UIParent)
        local fs = b:CreateFontString()
        rawset(fs, "GetWidth", function() return 240 end)
        rawset(fs, "GetUnboundedStringWidth", function() return 150 end)
        rawset(b, "subText", fs)
        fs:SetText("Requires: Leatherworking (|cffff202025|r)")
        ProfBuddy.Trainer:DecorateRow(b, { data = { skillIndex = belt } })
        redLine = fs:GetText()
    end
    EXPECT(redLine == "Requires: Leatherworking (|cffff202025|r |cffffff0055|r |cff00ff0070|r |cff80808085|r)",
           "red learn level: " .. tostring(redLine))
    -- a later requirement in parentheses is left alone: the numbers go
    -- inside the skill's own
    do
        local b = CreateFrame("Button", nil, UIParent)
        local fs = b:CreateFontString()
        rawset(fs, "GetWidth", function() return 240 end)
        rawset(fs, "GetUnboundedStringWidth", function() return 150 end)
        rawset(b, "subText", fs)
        fs:SetText("Requires: Leatherworking (25), Tanning (Expert)")
        ProfBuddy.Trainer:DecorateRow(b, { data = { skillIndex = belt } })
        EXPECT(fs:GetText() == "Requires: Leatherworking (25 |cffffff0055|r |cff00ff0070|r |cff80808085|r), Tanning (Expert)",
               "numbers outside the skill's parentheses: " .. tostring(fs:GetText()))
        -- and an earlier one too: the skill's "(" is found by its name
        fs:SetText("Requires: Level 20 (Rested), Leatherworking (25)")
        ProfBuddy.Trainer:DecorateRow(b, { data = { skillIndex = belt } })
        EXPECT(fs:GetText() == "Requires: Level 20 (Rested), Leatherworking (25 |cffffff0055|r |cff00ff0070|r |cff80808085|r)",
               "numbers not inside the skill's own parentheses: " .. tostring(fs:GetText()))
    end
    -- a line too wide for one line keeps Blizzard's text
    charW = 7
    EXPECT(row(belt) == "Requires: Leatherworking (25)", "a too-wide row was changed: " .. tostring(row(belt)))
    charW = 4
    EXPECT(row(index("Apprentice Leatherworking")) == "", "a profession rank got numbers")
    rawset(GameTooltip, "_lines", {})
    GameTooltip:SetTrainerService(belt)
    local tl = rawget(GameTooltip, "_lines")
    EXPECT(#tl == 1 and tl[1]:find("^Skill%-ups %(ProfessionBuddy%): |cffffffff>|r|cffff8000Orange: 25|r|cffffffff<|r  |cffffff00Yellow: 55|r"),
           "tooltip: " .. tostring(tl[1]))
    -- a recipe you already know: no numbers, no tooltip line
    local kept = TRAINERS[3008].services
    for _, sv in ipairs(kept) do if sv.name == "Handstitched Leather Belt" then sv.type = "used" end end
    TRAINER_CLOSE(); TRAINER_OPEN(3008)
    belt = index("Handstitched Leather Belt")
    EXPECT(row(belt) == "Requires: Leatherworking (25)", "a known recipe got numbers: " .. tostring(row(belt)))
    rawset(GameTooltip, "_lines", {})
    GameTooltip:SetTrainerService(belt)
    EXPECT(#rawget(GameTooltip, "_lines") == 0, "a known recipe got a tooltip line")
    for _, sv in ipairs(kept) do if sv.name == "Handstitched Leather Belt" then sv.type = "unavailable" end end
    -- the setting off: nothing
    S.trainerShowRanges = false
    TRAINER_CLOSE(); TRAINER_OPEN(3008)
    belt = index("Handstitched Leather Belt")
    EXPECT(row(belt) == "Requires: Leatherworking (25)", "numbers with the setting off")
    rawset(GameTooltip, "_lines", {})
    GameTooltip:SetTrainerService(belt)
    EXPECT(#rawget(GameTooltip, "_lines") == 0, "a tooltip line with the setting off")
    S.trainerShowRanges = true
    TRAINER_CLOSE()
    -- a weapon master: nothing
    TRAINER_OPEN(11869)
    rawset(GameTooltip, "_lines", {})
    GameTooltip:SetTrainerService(2)
    EXPECT(#rawget(GameTooltip, "_lines") == 0, "a weapon master got a tooltip line")
    TRAINER_CLOSE()
    TRAINER_FILTER.used = false
    rawset(GameTooltip, "_lines", nil)
    local found
    for _, cb in ipairs(ProfBuddy.TradeSkillFrame.settingsCheckboxes or {}) do
        if cb.settingKey == "trainerShowRanges" then found = cb end
    end
    EXPECT(found, "no Show skill-up ranges at trainers box in Settings")
end
print("  PASS F75 trainer ranges: colored numbers on unlearned recipe rows, no doubling, labeled tooltip line with your tier, nothing for known recipes, ranks, a weapon master or the setting off, Settings box")

-- F76: side panels never cover their window. The size limit leaves room
-- for the widest side panel; a panel opening with no room on the right
-- moves its window left (not in combat); a drag on the grip closes an open
-- dropdown list first
do
    local UI, TSF = ProfBuddy.UI, ProfBuddy.TradeSkillFrame
    local keepW, keepH = rawget(UIParent, "GetWidth"), rawget(UIParent, "GetHeight")
    rawset(UIParent, "GetWidth", function() return 1366 end)
    rawset(UIParent, "GetHeight", function() return 768 end)
    local st = { scale = 1.3, left = 600, top = 700 }
    local win = CreateFrame("Frame", nil, UIParent)
    rawset(win, "GetScale", function() return st.scale end)
    rawset(win, "SetScale", function(_, v) st.scale = v end)
    rawset(win, "GetLeft", function() return st.left / st.scale end)
    rawset(win, "GetTop", function() return st.top / st.scale end)
    rawset(win, "GetRight", function() return st.left / st.scale + 740 end)
    rawset(win, "GetWidth", function() return 740 end)
    rawset(win, "GetHeight", function() return 540 end)
    rawset(win, "SetPoint", function(_, p, rel, rp, x, y) st.left, st.top = x * st.scale, y * st.scale end)
    local panel = CreateFrame("Frame", nil, UIParent)
    rawset(panel, "GetWidth", function() return 280 end)
    rawset(panel, "GetScale", function() return st.scale end)
    rawset(panel, "SetScale", function() end)
    -- 740 wide plus a 280 wide panel on a 1366 wide screen: 1.33, not 1.42
    EXPECT(UI:FitScale(win, 1.5) == 1.42 and UI:FitScale(win, 1.5, { panel }) == 1.33,
           "the size limit leaves no room for the side panel: " .. tostring(UI:FitScale(win, 1.5, { panel })))
    -- the panel opens past the screen's right edge: the window moves left by the overflow
    UI:MakeRoomBeside(win, panel)
    EXPECT(math.abs(st.left - (600 - ((600 / 1.3 + 744) * 1.3 + 280 * 1.3 - 1366))) < 0.01 and math.abs(st.top - 700) < 0.01,
           "window not moved left for the panel: " .. tostring(st.left))
    -- room already: it stays
    local was = st.left
    UI:MakeRoomBeside(win, panel)
    EXPECT(math.abs(st.left - was) < 0.01, "a window with room moved")
    -- never past the screen's left edge, and never in combat
    st.left = 1000
    local keepCombat = InCombatLockdown
    InCombatLockdown = function() return true end
    UI:MakeRoomBeside(win, panel)
    EXPECT(st.left == 1000, "a window moved in combat")
    InCombatLockdown = keepCombat
    st.scale = 1.5; st.left = 200
    rawset(UIParent, "GetWidth", function() return 1000 end)
    UI:MakeRoomBeside(win, panel)
    EXPECT(st.left == 0, "a window moved past the screen's left edge: " .. tostring(st.left))
    rawset(UIParent, "GetWidth", function() return 1366 end)
    -- a scale change with the panel open makes room the same way
    st.scale, st.left = 1, 600
    rawset(panel, "IsShown", function() return true end)
    UI:ApplyScale(win, 1.33, { panel })
    EXPECT(st.scale == 1.33 and st.left < 600, "a scale change with the panel open left it covering the window")
    rawset(UIParent, "GetWidth", keepW); rawset(UIParent, "GetHeight", keepH)
    -- the Material Calculator, Order History and Find a Crafter make room when they open
    local calls = {}
    local keepMR = UI.MakeRoomBeside
    UI.MakeRoomBeside = function(_, f, p) calls[#calls + 1] = { f, p } end
    local calc = TSF.calcPanel
    calc:GetScript("OnShow")(calc)
    local OP = ProfBuddy.OrdersPanel
    OP.histFrame:GetScript("OnShow")(OP.histFrame)
    OP.findFrame:GetScript("OnShow")(OP.findFrame)
    UI.MakeRoomBeside = keepMR
    EXPECT(#calls == 3 and calls[1][1] == TSF.frame and calls[1][2] == calc
           and calls[2][1] == UI.frame and calls[2][2] == OP.histFrame
           and calls[3][1] == UI.frame and calls[3][2] == OP.findFrame, "a side panel does not make room when it opens")
    -- a drag on the grip closes an open dropdown list
    local dd = TSF.sortDropdown
    dd.listFrame:Show()
    TSF.scaleGrip:GetScript("OnMouseDown")(TSF.scaleGrip, "LeftButton")
    TSF.scaleGrip:GetScript("OnMouseUp")(TSF.scaleGrip)
    EXPECT(not dd.listFrame:IsShown(), "a grip drag left a dropdown list open")

    -- dragging: while a side panel is open, the window's clamp area reaches
    -- past its right edge by the panel and the gap, so both stop at the
    -- screen edge; back to the window alone when the panel hides; not in
    -- combat; a drag's end makes room as a panel opening does
    local win2 = CreateFrame("Frame", nil, UIParent)
    local clamp
    rawset(win2, "SetClampRectInsets", function(_, l, r, t, b) clamp = { l, r, t, b } end)
    local p1, p2 = CreateFrame("Frame", nil, UIParent), CreateFrame("Frame", nil, UIParent)
    rawset(p1, "GetWidth", function() return 280 end)
    rawset(p2, "GetWidth", function() return 360 end)
    p1:Show()
    UI:UpdateSideClamp(win2, { p1, p2 })
    EXPECT(clamp and clamp[1] == 0 and clamp[2] == 284 and clamp[3] == 0 and clamp[4] == 0,
           "the clamp area does not cover the open panel: " .. tostring(clamp and clamp[2]))
    p2:Show()
    UI:UpdateSideClamp(win2, { p1, p2 })
    EXPECT(clamp[2] == 364, "the clamp area does not cover the widest open panel")
    UI:UpdateSideClamp(win2, { p1, p2 }, p2)
    EXPECT(clamp[2] == 284, "a panel being hidden still counted")
    p1:Hide(); p2:Hide()
    UI:UpdateSideClamp(win2, { p1, p2 })
    EXPECT(clamp[2] == 0, "the clamp area did not go back to the window")
    p1:Show()
    InCombatLockdown = function() return true end
    UI:UpdateSideClamp(win2, { p1 })
    InCombatLockdown = keepCombat
    EXPECT(clamp[2] == 0, "the clamp area changed in combat")
    local stopped, roomFor = false, {}
    rawset(win2, "StopMovingOrSizing", function() stopped = true end)
    local keepMR2 = UI.MakeRoomBeside
    UI.MakeRoomBeside = function(_, f, panel) roomFor[#roomFor + 1] = panel end
    p2:Hide()
    UI:AfterDrag(win2, { p1, p2 })
    UI.MakeRoomBeside = keepMR2
    EXPECT(stopped and #roomFor == 1 and roomFor[1] == p1, "a drag's end did not make room for the open panel")
    p1:Hide()
    -- Order History or Find a Crafter closing stops counting, even while it
    -- still reads as shown
    do
        local OP = ProfBuddy.OrdersPanel
        local mainClamp
        rawset(UI.frame, "SetClampRectInsets", function(_, l, r) mainClamp = r end)
        for _, h in ipairs({ OP.histFrame, OP.findFrame }) do
            rawset(h, "GetWidth", function() return 300 end)
            rawset(h, "_shown", true)
            h:GetScript("OnShow")(h)
            EXPECT(mainClamp == 304, "a side panel opening did not set the clamp area: " .. tostring(mainClamp))
            rawget(h, "_h").OnHide(h)
            EXPECT(mainClamp == 0, "a side panel closing still counted: " .. tostring(mainClamp))
            rawset(h, "_shown", false)
            rawset(h, "GetWidth", nil)
        end
        rawset(UI.frame, "SetClampRectInsets", nil)
    end
    -- both windows use it: drag stops and the panels' show and hide
    local tsrc = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    local msrc = assert(io.open(PB_BASE .. "/UI/Main.lua")):read("*a")
    local osrc = assert(io.open(PB_BASE .. "/UI/OrdersPanel.lua")):read("*a")
    EXPECT(tsrc:find("addon.UI:AfterDrag(fr, { self.calcPanel })", 1, true)
           and msrc:find("UI:AfterDrag(fr, UI.scaleFollowers)", 1, true), "a window's drag does not end with AfterDrag")
    -- the calculator's show and hide, and its Price columns widening it (2.1.0)
    EXPECT(select(2, tsrc:gsub("UpdateSideClamp%(self%.frame", "")) == 3
           and select(2, osrc:gsub("UpdateSideClamp%(addon%.UI%.frame", "")) == 4,
           "a side panel's show or hide does not update the clamp area")
end
print("  PASS F76 side panels: the size limit leaves room for the widest, opening one moves the window left by the overflow (not past the edge, not in combat), a scale change does the same, a grip drag closes dropdown lists; dragging stops window and panel at the edge together")

-- F77: a profession link opens in PB's window between PB users. The game
-- does not open other players' profession links on WoW: Forever, so PB reads
-- the poster from the link's GUID and opens their recipes: a guildmate's
-- stored recipes at once, or after asking them; a first name alone matches
-- the one guildmate with it; a group member by unit GUID; strangers, your
-- own link, modified and right clicks, and other links do nothing
do
    local PL, C, S = ProfBuddy.ProfessionLink, ProfBuddy.Comm, ProfBuddy.db
    EXPECT(PL, "no ProfessionLink module")
    local LINK = "trade:Player-6926-001E5723:2108:165"
    local keep = {
        IsInGuild = IsInGuild, GetNumGuildMembers = GetNumGuildMembers, GetGuildRosterInfo = GetGuildRosterInfo,
        GetPlayerInfoByGUID = rawget(_G, "GetPlayerInfoByGUID"), IsInGroup = IsInGroup,
        GetNumSubgroupMembers = GetNumSubgroupMembers, UnitGUID = UnitGUID, GetUnitName = GetUnitName,
        IsModifiedClick = IsModifiedClick,
    }
    local roster = { "Bran Underhill", "Noodle Stand" }
    IsInGuild = function() return true end
    GetNumGuildMembers = function() return #roster end
    GetGuildRosterInfo = function(i) return roster[i], "Member", 1, 20, nil, nil, nil, nil, true end
    C._guildSet = nil
    local infoName = "Bran Underhill"
    GetPlayerInfoByGUID = function(g) if g == "Player-6926-001E5723" then return "Warrior", "WARRIOR", "Orc", "Orc", 2, infoName, "" end end
    local opened, asked = {}, {}
    local keepOpen, keepReq = PL.Open, C.RequestGuildSync
    PL.Open = function(_, key, prof) opened[#opened + 1] = key .. "|" .. prof end
    C.RequestGuildSync = function(_, key) asked[#asked + 1] = key end
    local BRAN = ProfBuddy:NormKey("Bran Underhill")
    S.characters[BRAN] = nil
    local function click(link, button) PRINTS = {}; SetItemRef(link, "[Leatherworking]", button or "LeftButton") end

    -- a guildmate with no stored recipes: PB asks, then opens when they arrive, once
    click(LINK)
    EXPECT(#asked == 1 and asked[1] == BRAN and #opened == 0, "a guildmate's link did not ask for recipes")
    EXPECT(PRINTED("Asked Bran Underhill for their Leatherworking recipes."), "no asked line")
    S.characters[BRAN] = { isRemote = true, professions = { Leatherworking = { skillLevel = 50, maxSkill = 75,
        recipes = { ["Light Armor Kit"] = true } } } }
    C:NotifyUIRefresh()
    C:NotifyUIRefresh()
    EXPECT(#opened == 1 and opened[1] == BRAN .. "|Leatherworking", "the reply did not open the profession once: " .. #opened)
    -- stored recipes: opens at once, and still asks for fresh ones
    opened, asked = {}, {}
    click(LINK)
    EXPECT(#opened == 1 and #asked == 1, "stored recipes did not open at once")
    -- a first name alone (WoW: Forever's GetPlayerInfoByGUID) matches the one guildmate with it
    infoName = "Bran"
    opened = {}
    click(LINK)
    EXPECT(#opened == 1 and opened[1] == BRAN .. "|Leatherworking", "a first name did not match the guildmate")
    -- two guildmates with that first name: PB does not guess
    roster[3] = "Bran Otherfamily"; C._guildSet = nil
    opened = {}
    click(LINK)
    EXPECT(#opened == 0 and PRINTED("Couldn't tell whose profession link that is."), "an ambiguous first name opened something")
    roster[3] = nil; C._guildSet = nil
    infoName = "Bran Underhill"
    -- nobody answers: one line after the wait
    S.characters[BRAN] = nil
    click(LINK)
    PRINTS = {}
    FLUSH()
    EXPECT(PRINTED("Bran Underhill didn't answer (offline or not running ProfessionBuddy)."), "no line when nobody answers")
    -- a stranger: no request, and PB says who it opens links for
    roster = { "Noodle Stand" }; C._guildSet = nil
    opened, asked = {}, {}
    click(LINK)
    EXPECT(#asked == 0 and #opened == 0 and PRINTED("ProfessionBuddy opens Bran Underhill's Leatherworking when they're in your guild, your group, or your ProfessionBuddy friends."),
           "a stranger's link was requested or opened")
    -- a group member, found by their unit's GUID
    IsInGroup = function() return true end
    GetNumSubgroupMembers = function() return 1 end
    local ownGUID = "Player-1-00000001"
    UnitGUID = function(u) if u == "party1" then return "Player-6926-001E5723" end return ownGUID end
    GetUnitName = function(u) if u == "party1" then return "Sushi Cats" end return "Me" end
    GetPlayerInfoByGUID = function() return nil end
    click(LINK)
    EXPECT(#asked == 1 and asked[1] == ProfBuddy:NormKey("Sushi Cats"), "a group member's link was not asked for: " .. tostring(asked[1]))
    -- your own link, a modified click, a right click, other links and
    -- unknown skill lines: nothing (the poster is still a group member here,
    -- so each one would ask if it got through)
    local function nothing(what)
        asked = {}
        click(LINK)
        EXPECT(#asked == 1, "the group member's link stopped asking before: " .. what)
        asked = {}
    end
    nothing("own link")
    ownGUID = "Player-6926-001E5723"
    click(LINK)
    ownGUID = "Player-1-00000001"
    EXPECT(#asked == 0, "your own link asked for recipes")
    nothing("modified click")
    IsModifiedClick = function() return true end
    click(LINK)
    IsModifiedClick = keep.IsModifiedClick
    EXPECT(#asked == 0, "a modified click asked for recipes")
    nothing("right click")
    click(LINK, "RightButton")
    EXPECT(#asked == 0, "a right click asked for recipes")
    click("item:2318::::::::")
    click("trade:Player-6926-001E5723:2108:999")
    EXPECT(#asked == 0, "another link or an unknown skill line asked for recipes")
    -- the link button's tooltip says who can open it
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find("Guildmates, group members, and ProfessionBuddy friends who run ProfessionBuddy can open it.", 1, true),
           "the link button's tooltip does not say who can open it")
    PL.Open, C.RequestGuildSync = keepOpen, keepReq
    for k, v in pairs(keep) do _G[k] = v end
    C._guildSet = nil
    S.characters[BRAN] = nil
    PRINTS = {}
end
print("  PASS F77 profession links between PB users: a guildmate's recipes open at once or after asking, once; a first name matches one guildmate, never two; a group member by unit GUID; no answer says so; strangers, your own link, modified and right clicks, other links do nothing; tooltip")

-- F78: a test build's label in the login line ("v2.0.2 (TEST-g)"), set
-- only in a test zip's Core.lua; plain otherwise
do
    local PB = ProfBuddy
    EXPECT(PB.BUILD == nil, "the repo's Core.lua sets addon.BUILD")
    EXPECT(PB:LoadedLine() == "|cff00ccffProfessionBuddy|r v" .. PB.version .. " loaded. Type /pb or /profbuddy.",
           "plain login line: " .. PB:LoadedLine())
    PB.BUILD = "TEST-g"
    EXPECT(PB:LoadedLine() == "|cff00ccffProfessionBuddy|r v" .. PB.version .. " (TEST-g) loaded. Type /pb or /profbuddy.",
           "labeled login line: " .. PB:LoadedLine())
    PB.BUILD = nil
end
print("  PASS F78 login line: plain in the repo, the test label when a test zip sets addon.BUILD")

-- F79: prices (Prices.lua, 2.1.0). Handstitched Leather Cloak: 2 Light
-- Leather (crafted from 3 Ruined Leather Scraps with a known recipe) and 1
-- Coarse Thread (a vendor sells it, 10c in the baked table).
do
    local PB = ProfBuddy
    local P, S = PB.Prices, PB.db.settings
    local TSF = PB.TradeSkillFrame
    local function plain(t)
        return ((t or ""):gsub("|T[^|]*|t", function(icon)
            return icon:find("GoldIcon") and "g" or icon:find("SilverIcon") and "s" or "c"
        end):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    EXPECT(S.showPrices == true and S.priceAuctionator == true and S.priceTSM == true
           and S.priceTSMSource == "DBMarket" and S.priceStaleDays == 7 and S.priceIntermediates == "both",
           "price settings defaults")
    for _, toc in ipairs({ "ProfessionBuddy_Forever.toc", "ProfessionBuddy_Mainline.toc" }) do
        local src = assert(io.open(PB_BASE .. "/" .. toc)):read("*a")
        EXPECT(src:find("## OptionalDeps: Auctionator, TradeSkillMaster", 1, true)
               and src:find("\nData/Forever/VendorPrices.lua", 1, true) and src:find("\nPrices.lua", 1, true)
               and not src:find("\nData/VendorPrices.lua", 1, true), toc .. ": prices files or OptionalDeps")
    end
    EXPECT(PB.VendorPrices[2320] == 10 and PB.VendorPrices[2321] == 100 and PB.VendorPrices[2318] == nil,
           "baked Forever vendor prices")
    EXPECT(plain(P:Money(12345)) == "1g 23s 45c" and plain(P:Money(5)) == "5c" and plain(P:Money(0)) == "0c"
           and plain(P:Money(12345, true)) == "1g 23s" and plain(P:Money(12399, true)) == "1g 24s"
           and plain(P:SignedMoney(-150)) == "-1s 50c" and plain(P:SignedMoney(85)) == "+85c", "money text")

    C_TradeSkillUI.OpenTradeSkill(165)
    TS_LIST_READY()
    FLUSH()
    TSF.state.showTab, TSF.state.searchText = "known", ""
    TSF:RefreshRecipeList()
    local function detail(name)
        TSF.state.selected = name
        TSF:RefreshDetailPanel()
        return TSF.detPrice:IsShown() and plain(TSF.detPrice:GetText()) or nil, TSF.detPriceHover.result
    end
    local cloak = "Handstitched Leather Cloak"

    -- F21's Test Vendor sells Light Leather (55c, unlimited), so PB has
    -- recorded it as a vendor price already
    EXPECT(PB.db.prices.vendor[2318].p == 55, "F21's vendor Light Leather not recorded")
    P:ClearRecorded()
    -- neither Auctionator nor TSM, nothing recorded: the thread from the
    -- baked table, the leather has no price
    local line, r = detail(cloak)
    EXPECT(line == "Cost: 10c+ (1 material has no price)", "no auction prices: " .. tostring(line))
    EXPECT(r.missing == 1 and r.missingNames[1] == "Light Leather" and r.profit == nil, "missing material named")

    -- Auctionator: leather 50c (2 days old), scraps 10c, the cloak 3s (10
    -- days old, past the 7-day limit). Crafting the leather (3 x 10c) is
    -- cheaper than buying it. Profit = 3s less 5%, less 70c.
    local AUC = { [2318] = 50, [2934] = 10, [7276] = 300, [2320] = 25 }
    local AGE = { [2318] = 2, [7276] = 10 }
    local calls = {}
    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(caller, id) calls[#calls + 1] = caller; return AUC[id] end,
        GetAuctionAgeByItemID = function(caller, id) return AGE[id] end,
    } } }
    line, r = detail(cloak)
    EXPECT(line == "Cost: 70c   Sells: 3s   Profit: +2s 15c", "Auctionator: " .. tostring(line))
    EXPECT(TSF.detPrice:GetText():find("|cff808080" .. P:Money(300) .. "|r", 1, true), "an old sale price is not gray")
    EXPECT(calls[1] == "ProfessionBuddy", "Auctionator called without PB's name")
    local leather = r.parts[1].price
    EXPECT(leather.buy == 50 and leather.buySource == "Auctionator" and leather.craft == 30 and leather.used == "craft"
           and leather.unit == 30, "Light Leather buy 50 / craft 30")
    -- a vendor material is never priced above the vendor (25c at auction, 10c vendor)
    local thread = r.parts[2].price
    EXPECT(thread.unit == 10 and thread.buySource == "vendor", "Coarse Thread above the vendor price")
    AUC[2320] = 5
    EXPECT(P:MaterialPrice(2320).unit == 5, "an auction price below the vendor's lost")
    AUC[2320] = 25
    -- the tooltip: both prices for the crafted leather, the cheaper bright;
    -- "Cheaper price only" shows the one used
    local lines = {}
    local tt = { AddLine = function(_, t) lines[#lines + 1] = plain(t) end,
                 AddDoubleLine = function(_, a, b) lines[#lines + 1] = plain(a) .. " = " .. plain(b) end }
    P:FillTooltip(tt, r)
    local tip = table.concat(lines, "\n")
    EXPECT(tip:find("2 x Light Leather = buy 1s (Auctionator, 2 days old)  craft 60c", 1, true)
           and tip:find("1 x Coarse Thread = 10c (vendor)", 1, true)
           and tip:find("Sells at auction = 3s (Auctionator, 10 days old)", 1, true)
           and tip:find("Profit = +2s 15c", 1, true)
           and tip:find("Auction price less the 5% auction house cut, less the cost.", 1, true), "price tooltip:\n" .. tip)
    lines = {}
    P:FillTooltip({ AddLine = function(_, t) lines[#lines + 1] = t end,
                    AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. " = " .. b end }, r)
    -- the unused price is tan, not gray: gray only means an old price
    EXPECT(table.concat(lines, "\n"):find(P.TAN .. "buy " .. P:Money(100), 1, true)
           and table.concat(lines, "\n"):find("|cffffffffcraft " .. P:Money(60), 1, true), "the cheaper is not the bright one")
    S.priceIntermediates = "cheaper"
    lines = {}
    P:FillTooltip(tt, r)
    EXPECT(table.concat(lines, "\n"):find("2 x Light Leather = craft 60c", 1, true), "cheaper only:\n" .. table.concat(lines, "\n"))
    S.priceIntermediates = "both"

    -- TSM when Auctionator is switched off: the typed price source, i:<id>
    local asked = {}
    TSM_API = { GetCustomPriceValue = function(src, item) asked[#asked + 1] = src .. " " .. item
        return ({ ["i:2318"] = 40, ["i:2934"] = 20, ["i:7276"] = 500 })[item] end }
    S.priceAuctionator = false
    S.priceTSMSource = " DBMinBuyout "
    line = detail(cloak)
    EXPECT(asked[1] == "DBMinBuyout i:2318", "TSM asked: " .. tostring(asked[1]))
    EXPECT(line == "Cost: 90c   Sells: 5s   Profit: +3s 85c", "TSM: " .. tostring(line))
    S.priceTSMSource = "DBMarket"
    -- both off: PB's recorded prices (3 days old), the vendor; the cloak
    -- falls back to the vendor's price
    S.priceTSM = false
    local house = P:HouseKey()
    EXPECT(house == "Realm-Horde", "house key " .. house)
    P:Store().auction[house] = { [2934] = { p = 12, t = time() - 3 * 86400 } }
    local keepItem = C_Item.GetItemInfo
    C_Item.GetItemInfo = function(id) if id == 7276 then return "Cloak", nil, 1, 5, 1, "Armor", "Cloth", 1, "", 1, 64 end end
    line, r = detail(cloak)
    EXPECT(line == "Cost: 82c   Sells: 64c (vendor)   Profit: -18c", "recorded + vendor: " .. tostring(line))
    EXPECT(r.parts[1].price.craftParts[1].price.buySource == "PB" and math.floor(r.parts[1].price.craftParts[1].price.age) == 3,
           "recorded price source and age")
    C_Item.GetItemInfo = keepItem
    P:Store().auction[house] = nil
    S.priceAuctionator, S.priceTSM = true, true

    -- vendors: a material sold for money with unlimited stock is recorded
    -- per item (a stack of 4 for 36c is 9c each) and beats the baked price;
    -- limited stock, a token price and a pattern are not recorded
    MERCHANT_OPEN(90105)
    MERCHANT_CLOSE()
    local V = PB.db.prices.vendor
    EXPECT(V[2320] and V[2320].p == 9 and V[2321] == nil and V[2678] == nil and V[5083] == nil,
           "vendor prices recorded: " .. tostring(V[2320] and V[2320].p))
    EXPECT(P:VendorBuy(2320) == 9, "a recorded vendor price did not beat the baked one")
    line = detail(cloak)
    EXPECT(line == "Cost: 69c   Sells: 3s   Profit: +2s 16c", "recorded vendor price: " .. tostring(line))

    -- an enchant (no item): cost only
    C_TradeSkillUI.OpenTradeSkill(333)
    TS_LIST_READY()
    FLUSH()
    TSF.state.showTab = "known"
    TSF:RefreshRecipeList()
    AUC[10940] = 120
    line, r = detail("Enchant Bracer - Minor Stamina")
    EXPECT(line == "Cost: 2s 40c" and r.itemID == nil, "enchant: " .. tostring(line))
    C_TradeSkillUI.OpenTradeSkill(165)
    TS_LIST_READY()
    FLUSH()
    TSF.state.showTab = "known"
    TSF:RefreshRecipeList()

    -- the Material Calculator: Price and Cost columns widen it; To buy is
    -- the shopping list's shortfall
    TSF.state.selected = cloak
    TSF:RefreshDetailPanel()
    TSF.qtyBox:SetText("2")
    if not TSF.calcPanel then TSF:BuildCalcPanel() end
    local calcW
    rawset(TSF.calcPanel, "SetWidth", function(_, w) calcW = w end)
    rawset(TSF.calcPanel, "GetWidth", function() return calcW end)
    TSF:RefreshCalcPanel()
    EXPECT(TSF.calcPanel:GetWidth() == 404 and TSF.calcCols.price:IsShown(), "calculator not widened for prices")
    local rows = {}
    for _, row in ipairs(TSF.calcRows) do
        if row:IsShown() and row.itemID then
            rows[#rows + 1] = row.itemID .. " " .. plain(row.priceText:GetText()) .. " " .. plain(row.costText:GetText())
        end
    end
    local summary = plain(TSF.calcSummary:GetText())
    EXPECT(table.concat(rows, "|"):find("2318 30c 1s 20c", 1, true) and table.concat(rows, "|"):find("2320 9c 18c", 1, true),
           "calculator rows: " .. table.concat(rows, "|"))
    -- the character has the Light Leather, so the shopping list is the thread
    EXPECT(summary:find("To buy: 18c   All materials: 18c", 1, true), "calculator summary: " .. summary)
    -- one thread in the bags: To buy is the one still needed
    local myInv = PB.db.characters[PB:PlayerKey()].inventory
    local keepThread = myInv.bags[2320]
    myInv.bags[2320] = 1
    TSF:RefreshCalcPanel()
    summary = plain(TSF.calcSummary:GetText())
    EXPECT(summary:find("To buy: 9c   All materials: 18c", 1, true), "calculator with a thread in the bags: " .. summary)
    myInv.bags[2320] = keepThread
    TSF:RefreshCalcPanel()
    -- a material with no price: "?" and the count
    local keepBaked, keepSeen = PB.VendorPrices[2320], PB.db.prices.vendor[2320]
    PB.VendorPrices[2320], PB.db.prices.vendor[2320], AUC[2320] = nil, nil, nil
    TSF:RefreshCalcPanel()
    summary = plain(TSF.calcSummary:GetText())
    EXPECT(summary:find("To buy: ?   All materials: ?\n(1 material has no price)", 1, true), "missing in calculator: " .. summary)
    PB.VendorPrices[2320], PB.db.prices.vendor[2320], AUC[2320] = keepBaked, keepSeen, 25

    -- Show prices off: no line, the calculator back to its width
    S.showPrices = false
    line = detail(cloak)
    TSF:RefreshCalcPanel()
    EXPECT(line == nil and calcW == 280 and not TSF.calcCols.price:IsShown()
           and not plain(TSF.calcSummary:GetText()):find("To buy", 1, true), "Show prices off")
    S.showPrices = true

    -- Settings: the Prices section, Auctionator and TSM gray when not installed
    Auctionator, TSM_API = nil, nil
    EXPECT(TSF.showPricesCB and TSF.priceAucCB and TSF.priceTSMCB and TSF.priceTSMBox and TSF.priceStaleDD
           and TSF.priceInterDD and TSF.priceClearBtn, "Settings > Prices controls")
    EXPECT(not TSF.priceAucCB:IsEnabled() and not TSF.priceTSMCB:IsEnabled(), "Auctionator / TSM box usable while not installed")
    local tsrc = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(tsrc:find('"Auctionator prices (not installed)"', 1, true) and tsrc:find('"Prices turn gray after: "', 1, true),
           "Settings labels")
    P:ClearRecorded()
    EXPECT(PB.db.prices == nil, "Clear recorded prices")
    TSF.calcPanel:Hide()
    rawset(TSF.calcPanel, "SetWidth", nil)
    rawset(TSF.calcPanel, "GetWidth", nil)
end
print("  PASS F79 prices: vendor table, Auctionator (PB's name, ages, gray when old), TSM with the typed source, PB's recorded prices, vendor cap, crafted material at the cheaper of buy and craft, missing materials named, 5% cut, vendor sale fallback, enchant cost only; vendors recorded per item (unlimited, money only); calculator columns and To buy; Show prices off; Settings")

-- F80: TEST-b (2.1.0). Sale price settings, the list's Profit column,
-- sort and loss filter, plain clicks kept from other addons, the TSM box
-- on its own line, K in combat, and auction prices PB records itself
-- (browse, Scan my materials, full scan, neutral towns, the ProfessionBuddy tab).
do
    local PB = ProfBuddy
    local P, S, TSF, AP = PB.Prices, PB.db.settings, PB.TradeSkillFrame, PB.AuctionPrices
    local st = TSF.state
    local function plain(t)
        return ((t or ""):gsub("|T[^|]*|t", function(icon)
            return icon:find("GoldIcon") and "g" or icon:find("SilverIcon") and "s" or "c"
        end):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    P:ClearRecorded()
    local AUC = { [2318] = 50, [2934] = 10, [7276] = 300, [2302] = 10, [2320] = 25 }
    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(_, id) return AUC[id] end,
        GetAuctionAgeByItemID = function() return 0 end,
    } } }
    local SELL, BOP = { [7276] = 400, [2318] = 5 }, {}
    local keepItem = C_Item.GetItemInfo
    C_Item.GetItemInfo = function(id)
        if SELL[id] then return "x", nil, 1, 5, 1, "Armor", "Cloth", 1, "", 1, SELL[id], 4, 1, BOP[id] and 1 or 2 end
    end
    C_TradeSkillUI.OpenTradeSkill(165)
    TS_LIST_READY()
    FLUSH()
    st.showTab, st.searchText, st.sortBy, st.sortAsc = "known", "", "Category", true
    TSF:RefreshRecipeList()
    local cloak = "Handstitched Leather Cloak"
    local function line(name)
        st.selected = name or cloak
        TSF:RefreshDetailPanel()
        return plain(TSF.detPrice:GetText())
    end
    -- defaults: both sale prices, profit from the auction price (3s less 5%, less 70c)
    EXPECT(S.priceVendorSell == true and S.priceBetterSale == false and S.priceListProfit == false
           and S.priceHideLoss == false, "sale and list settings defaults")
    EXPECT(line() == "Cost: 70c   Sells: 3s, vendor 4s   Profit: +2s 15c", "both sale prices: " .. line())
    -- only the better: the vendor's 4s beats 3s less 5%
    S.priceBetterSale = true
    local r = P:RecipeCost(TSF:GetSelectedRecipe(), st.profName)
    EXPECT(line() == "Cost: 70c   Sells: 4s (vendor)   Profit: +3s 30c" and r.profitFrom == "vendor", "better sale price: " .. line())
    AUC[7276] = 500
    EXPECT(line() == "Cost: 70c   Sells: 5s (auction)   Profit: +4s 05c" or line() == "Cost: 70c   Sells: 5s (auction)   Profit: +4s 5c",
           "better is the auction price: " .. line())
    AUC[7276] = 300
    -- no vendor sale price anywhere
    S.priceVendorSell = false
    r = P:RecipeCost(TSF:GetSelectedRecipe(), st.profName)
    EXPECT(line() == "Cost: 70c   Sells: 3s   Profit: +2s 15c" and r.vendorSell == nil, "vendor sale price off: " .. line())
    local lines = {}
    P:FillTooltip({ AddLine = function(_, t) lines[#lines + 1] = plain(t) end,
                    AddDoubleLine = function(_, a, b) lines[#lines + 1] = plain(a) .. " = " .. plain(b) end }, r)
    EXPECT(not table.concat(lines, "\n"):find("Vendor pays", 1, true), "vendor price in the tooltip while off")
    S.priceVendorSell, S.priceBetterSale = true, false
    -- Settings: the better box is gray while the vendor box is off
    local vcb = TSF.priceVendorSellCB
    rawset(vcb, "GetChecked", function() return false end)
    vcb:GetScript("OnClick")(vcb)
    EXPECT(S.priceVendorSell == false and not TSF.priceBetterCB:IsEnabled(), "better box usable with the vendor box off")
    rawset(vcb, "GetChecked", function() return true end)
    vcb:GetScript("OnClick")(vcb)
    EXPECT(S.priceVendorSell == true and TSF.priceBetterCB:IsEnabled(), "better box gray with the vendor box on")
    rawset(vcb, "GetChecked", nil)
    -- the TSM price source sits on its own line, after its label
    EXPECT(rawget(TSF.priceTSMBox, "_lastPoint")[2] == TSF.priceTSMLabel, "TSM box not placed after its own label")

    -- the recipe list: Profit column, Profit sort, Hide crafts at a loss
    local function rowsText()
        local out = {}
        for _, row in ipairs(TSF.listRows) do
            if row:IsShown() and rawget(row.nameText, "_text") then
                out[#out + 1] = plain(rawget(row.nameText, "_text")) .. " | " .. plain(rawget(row.rightText, "_text") or "")
            end
        end
        return table.concat(out, "\n")
    end
    S.priceListProfit = true
    st.sortBy, st.sortAsc = "Profit", true
    TSF:RefreshRecipeList()
    local text = rowsText()
    local iCloak = text:find("Handstitched Leather Cloak | +2s 15c", 1, true)
    local iBoots = text:find("Handstitched Leather Boots | -", 1, true)
    EXPECT(iCloak and iBoots and iCloak < iBoots, "Profit column or sort:\n" .. text)
    EXPECT(text:find("Light Armor Kit | - ", 1, true), "a recipe with no profit has no dash:\n" .. text)
    S.priceHideLoss = true
    TSF:RefreshRecipeList()
    local found = false
    for _, e in ipairs(st.recipes) do if e.name == "Handstitched Leather Boots" then found = true end end
    EXPECT(not found, "a craft at a loss still listed")
    S.priceHideLoss, S.priceListProfit = false, false
    st.sortBy = "Category"
    TSF:RefreshRecipeList()
    EXPECT(not rowsText():find("+2s 15c", 1, true), "Profit column with the box off")

    -- TEST-b2, BoP (guild): a product that binds when picked up has no
    -- auction price (Auctionator still has 3s for it), only the vendor's;
    -- a gray BoP in the list, last in the Profit sort, and hidden at a loss
    BOP[7276] = true
    r = P:RecipeCost(TSF:GetSelectedRecipe(), st.profName)
    EXPECT(r.bop and r.sell == nil and line() == "Cost: 70c   Sells: 4s (vendor, BoP)   Profit: +3s 30c",
           "BoP detail line: " .. line())
    lines = {}
    P:FillTooltip({ AddLine = function(_, t) lines[#lines + 1] = plain(t) end,
                    AddDoubleLine = function(_, a, b) lines[#lines + 1] = plain(a) .. " = " .. plain(b) end }, r)
    local tip = table.concat(lines, "\n")
    EXPECT(tip:find("Binds when picked up", 1, true) and not tip:find("Sells at auction", 1, true)
           and tip:find("Vendor price less the cost.", 1, true), "BoP tooltip:\n" .. tip)
    S.priceVendorSell = false
    EXPECT(line() == "Cost: 70c   BoP", "BoP with the vendor price off: " .. line())
    S.priceVendorSell = true
    S.priceListProfit = true
    st.sortBy, st.sortAsc = "Profit", true
    TSF:RefreshRecipeList()
    text = rowsText()
    iCloak = text:find("Handstitched Leather Cloak | BoP", 1, true)
    iBoots = text:find("Handstitched Leather Boots | -", 1, true)
    EXPECT(iCloak and iBoots and iBoots < iCloak, "BoP not shown or not last in the Profit sort:\n" .. text)
    S.priceHideLoss = true
    TSF:RefreshRecipeList()
    found = false
    for _, e in ipairs(st.recipes) do if e.name == cloak then found = true end end
    EXPECT(found, "a BoP craft at a profit was hidden")
    SELL[7276] = 10
    TSF:RefreshRecipeList()
    found = false
    for _, e in ipairs(st.recipes) do if e.name == cloak then found = true end end
    EXPECT(not found, "a BoP craft at a loss still listed")
    SELL[7276], BOP[7276] = 400, nil
    S.priceHideLoss, S.priceListProfit = false, false
    st.sortBy = "Category"
    TSF:RefreshRecipeList()

    ;(function() -- its own function: F80's block is at Lua's 200-locals limit
    -- TEST-b2, BoP materials: never an auction price (Auctionator has 25c
    -- for the thread and 50c for the leather). A crafted one keeps its craft
    -- cost; one nothing prices reads "? (BoP)" and "binds when picked up"
    -- instead of "has no price".
    SELL[2318], SELL[2320] = 5, 1
    BOP[2318], BOP[2320] = true, true
    local mp = P:MaterialPrice(2318)
    EXPECT(mp.bop and mp.buy == nil and mp.used == "craft" and mp.unit == 30,
           "a crafted BoP material: " .. tostring(mp.buy) .. " " .. tostring(mp.used) .. " " .. tostring(mp.unit))
    local keepVP = PB.VendorPrices[2320]
    PB.VendorPrices[2320] = nil
    mp = P:MaterialPrice(2320)
    EXPECT(mp.bop and mp.unit == nil and mp.buy == nil, "a BoP material kept an auction price")
    EXPECT(plain(P:MaterialText(mp)) == "? (BoP)", "BoP material text: " .. plain(P:MaterialText(mp)))
    EXPECT(line() == "Cost: 60c+ (1 material binds when picked up)   Sells: 3s, vendor 4s", "BoP material line: " .. line())
    r = P:RecipeCost(TSF:GetSelectedRecipe(), st.profName)
    lines = {}
    P:FillTooltip({ AddLine = function(_, t) lines[#lines + 1] = plain(t) end,
                    AddDoubleLine = function(_, a, b) lines[#lines + 1] = plain(a) .. " = " .. plain(b) end }, r)
    tip = table.concat(lines, "\n")
    EXPECT(tip:find("1 x Coarse Thread = ? (BoP)", 1, true)
           and tip:find("1 material binds when picked up: Coarse Thread. It can't be bought.", 1, true)
           and tip:find("No profit shown: 1 material binds when picked up.", 1, true)
           and not tip:find("has no price", 1, true), "BoP material tooltip:\n" .. tip)
    EXPECT(P:MissingText(2, 1) == "1 material has no price, 1 material binds when picked up"
           and P:MissingText(3, 3) == "3 materials bind when picked up" and P:MissingText(2) == "2 materials have no price",
           "missing texts")
    -- the Material Calculator: BoP in its price cells, and in the summary
    if not TSF.calcPanel then TSF:BuildCalcPanel() end
    TSF.qtyBox:SetText("1")
    TSF:RefreshCalcPanel()
    local calcRows = {}
    for _, row in ipairs(TSF.calcRows) do
        if row:IsShown() and row.itemID then
            calcRows[#calcRows + 1] = row.itemID .. " " .. plain(row.priceText:GetText()) .. " " .. plain(row.costText:GetText())
        end
    end
    local sum = plain(TSF.calcSummary:GetText())
    EXPECT(table.concat(calcRows, "|"):find("2320 BoP BoP", 1, true) and sum:find("(1 material binds when picked up)", 1, true),
           "calculator BoP: " .. table.concat(calcRows, "|") .. " / " .. sum)
    -- an item the game hasn't loaded yet: PB asks for it, and the price
    -- line fills in BoP by itself shortly after
    local LOADING = { [2320] = true }
    local keepGII, keepReq = C_Item.GetItemInfo, C_Item.RequestLoadItemDataByID
    local asked = false
    C_Item.GetItemInfo = function(id) if LOADING[id] then return nil end return keepGII(id) end
    C_Item.RequestLoadItemDataByID = function(id) if id == 2320 then asked = true end end
    st.selected = cloak
    TSF:RefreshDetailPanel()
    -- until it loads PB can't tell it binds, so Auctionator's 25c shows
    EXPECT(asked and plain(TSF.detPrice:GetText()):find("Cost: 85c", 1, true),
           "an unloaded item: not asked for, or the line: " .. plain(TSF.detPrice:GetText()))
    LOADING[2320] = nil
    FLUSH()
    EXPECT(plain(TSF.detPrice:GetText()):find("(1 material binds when picked up)", 1, true),
           "the price line did not fill in BoP once the item loaded: " .. plain(TSF.detPrice:GetText()))
    -- an item that never loads: three more looks, then PB stops
    local looks = 0
    LOADING[2320] = true
    C_Item.RequestLoadItemDataByID = function(id) if id == 2320 then looks = looks + 1 end end
    TSF:RefreshDetailPanel()
    FLUSH()
    EXPECT(looks == 4, "looks for an item that never loads: " .. looks)
    C_Item.GetItemInfo, C_Item.RequestLoadItemDataByID = keepGII, keepReq
    if TSF.calcPanel then TSF.calcPanel:Hide() end
    PB.VendorPrices[2320] = keepVP
    SELL[2318], SELL[2320], BOP[2318], BOP[2320] = 5, nil, nil, nil
    end)()

    -- plain clicks stay with PB: another addon's item-click hook (TSM's
    -- Crafting window) cannot take them; with a modifier held they go there
    local handled = 0
    local keepHMIC = HandleModifiedItemClick
    HandleModifiedItemClick = function() handled = handled + 1; return true end
    local idx
    for k, e in ipairs(st.recipes) do if e.name == cloak then idx = k end end
    st.recipes[idx].itemLink = "|cffffffff|Hitem:7276::::::::|h[Handstitched Leather Cloak]|h|r"
    st.scrollOffset = idx - 1
    TSF:UpdateListRows()
    st.selected = "Light Armor Kit"
    MODIFIER_DOWN = false
    TSF.listRows[1]:GetScript("OnClick")(TSF.listRows[1])
    EXPECT(handled == 0 and st.selected == cloak, "a plain click went to the item-click handler")
    st.selected = "Light Armor Kit"
    MODIFIER_DOWN = true
    TSF.listRows[1]:GetScript("OnClick")(TSF.listRows[1])
    EXPECT(handled == 1 and st.selected == "Light Armor Kit", "a modified click did not go to the item-click handler")
    MODIFIER_DOWN = false
    HandleModifiedItemClick = keepHMIC
    st.scrollOffset = 0
    C_Item.GetItemInfo = keepItem

    -- K in combat (WoW: Forever, option C): the book's own Show in combat,
    -- PB's gate back after it; a profession opened meanwhile hides the book
    local PF = ProfessionsFrame
    local gate = rawget(PF, "Show")
    EXPECT(type(gate) == "function", "ProfessionsFrame has no PB gate")
    FIRE("PLAYER_REGEN_DISABLED")
    EXPECT(rawget(PF, "Show") == nil, "PB's gate still on the book in combat")
    rawset(PF, "_shown", true)
    FIRE("PLAYER_REGEN_ENABLED")
    EXPECT(rawget(PF, "Show") == gate and not PF:IsShown(), "after combat: gate not back, or the book over an open profession")
    C_TradeSkillUI.CloseTradeSkill()
    FLUSH()
    FIRE("PLAYER_REGEN_DISABLED")
    rawset(PF, "_shown", true)
    PF.BookPage:Hide(); PF.CraftingPage:Show()
    FIRE("PLAYER_REGEN_ENABLED")
    EXPECT(PF:IsShown() and PF.BookPage:IsShown() and not PF.CraftingPage:IsShown(),
           "a book opened in combat did not switch to the book page after it")
    PF:Hide()

    -- auction prices PB records (WoW: Forever, the modern auction house)
    local BROWSE, COMM, ITEMS, REPL = {}, {}, {}, {}
    local READY, sent, replicated = true, {}, false
    C_AuctionHouse = {
        GetBrowseResults = function() return BROWSE end,
        GetNumCommoditySearchResults = function(id) return #(COMM[id] or {}) end,
        GetCommoditySearchResultInfo = function(id, i)
            local p = COMM[id] and COMM[id][i]
            return p and { itemID = id, quantity = 5, unitPrice = p } or nil
        end,
        GetNumItemSearchResults = function(key) return #(ITEMS[key.itemID] or {}) end,
        GetItemSearchResultInfo = function(key, i)
            local e = ITEMS[key.itemID][i]
            return { itemKey = key, quantity = e[1], buyoutAmount = e[2] }
        end,
        IsThrottledMessageSystemReady = function() return READY end,
        MakeItemKey = function(id) return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 } end,
        SendSearchQuery = function(key, sorts)
            sent[#sent + 1] = key.itemID .. ":" .. tostring(sorts[1].sortOrder) .. ":" .. tostring(sorts[1].reverseSort)
            if COMM[key.itemID] then FIRE("COMMODITY_SEARCH_RESULTS_UPDATED", key.itemID)
            elseif ITEMS[key.itemID] then FIRE("ITEM_SEARCH_RESULTS_UPDATED", key) end
        end,
        ReplicateItems = function() replicated = true end,
        GetNumReplicateItems = function() return #REPL end,
        GetReplicateItemInfo = function(i)
            local e = REPL[i + 1]
            return nil, nil, e[2], 1, true, 1, nil, 0, 0, e[3], 0, nil, nil, nil, nil, 0, e[1], true
        end,
    }
    Enum = Enum or {}
    Enum.AuctionHouseSortOrder = Enum.AuctionHouseSortOrder or { Price = 0 }
    local AHF = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
    -- what LibAHTab reads: Blizzard's own tabs and the display mode
    AHF.Tabs = { CreateFrame("Button", "AHTabBuy", AHF), CreateFrame("Button", "AHTabSell", AHF) }
    rawset(AHF, "SetDisplayMode", function(f, mode) rawset(f, "_mode", mode) end)
    rawset(AHF, "SetTitle", function(f, t) rawset(f, "_title", t) end)
    local popup
    local keepPopup = StaticPopup_Show
    StaticPopup_Show = function(n) popup = n end
    Auctionator = nil
    -- WoW: Forever's auctioneer reports no faction (TEST-b: nothing was
    -- recorded); outside Booty Bay, Gadgetzan and Everlook PB records
    local baseFaction = UnitFactionGroup
    UnitFactionGroup = function(u) if u == "npc" then return nil end return baseFaction(u) end
    local SUB = ""
    local keepSub, keepZone, keepMap = GetSubZoneText, GetRealZoneText, rawget(_G, "C_Map")
    GetSubZoneText = function() return SUB end
    GetRealZoneText = function() return "Orgrimmar" end
    local AREAS = { [35] = "Booty Bay", [976] = "Gadgetzan", [2255] = "Everlook" }
    C_Map = setmetatable({ GetAreaInfo = function(id) return AREAS[id] end }, { __index = keepMap })
    local house = P:HouseKey()
    local function rec(id) local h = PB.db.prices and PB.db.prices.auction[house]; return h and h[id] and h[id].p end
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    -- the ProfessionBuddy tab, through LibAHTab, after Blizzard's tabs
    local LAT = LibStub("LibAHTab-1-0", true)
    EXPECT(LAT and AP.tab and AP.tab:IsShown() and LAT:GetButton("ProfessionBuddy") == AP.tab,
           "no ProfessionBuddy tab with neither Auctionator nor TSM")
    EXPECT(AP.panel and not AP.panel:IsShown(), "PB's page shown before its tab was clicked")
    AP.tab:GetScript("OnClick")(AP.tab)
    EXPECT(AP.panel:IsShown() and rawget(AHF, "_title") == "ProfessionBuddy", "PB's page not shown by its tab")
    EXPECT(AP.panel.scan:GetText() == "Scan my materials" and AP.panel.full:GetText() == "Full scan", "PB's page buttons")
    EXPECT(AP._record, "nothing recorded where the auctioneer reports no faction")
    -- browsing: lowest per item this visit, items PB's recipes use or make only
    BROWSE = { { itemKey = { itemID = 2934 }, minPrice = 12 }, { itemKey = { itemID = 99999 }, minPrice = 5 } }
    FIRE("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    EXPECT(rec(2934) == 12 and rec(99999) == nil, "browse prices: " .. tostring(rec(2934)))
    FIRE("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = { itemID = 2934 }, minPrice = 15 } })
    EXPECT(rec(2934) == 12, "a higher price replaced the lowest this visit")
    FIRE("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = { itemID = 2934 }, minPrice = 11 } })
    EXPECT(rec(2934) == 11, "a lower price not kept")
    -- the recorded price is what PB now uses (Auctionator gone)
    EXPECT(P:AuctionPrice(2934) == 11 and select(2, P:AuctionPrice(2934)) == "PB", "recorded price not used")
    -- Scan my materials: one search at a time, cheapest first, only when the game takes one
    COMM[2934] = { 9, 13 }
    COMM[2320] = { 30 }
    ITEMS[7276] = { { 1, 280 }, { 2, 500 } }
    READY = false
    AP:StartTargeted()
    EXPECT(#sent == 0 and AP.panel.scan:GetText() == "Stop scan", "searched before the game was ready")
    READY = true
    FLUSH()
    FLUSH()
    EXPECT(#sent > 3 and sent[1]:match(":0:false$"), "scan searches: " .. table.concat(sent, ", "))
    EXPECT(rec(2934) == 9 and rec(2320) == 30 and rec(7276) == 250, "scan prices: "
           .. tostring(rec(2934)) .. " " .. tostring(rec(2320)) .. " " .. tostring(rec(7276)))
    EXPECT(AP._scan == nil and AP.panel.scan:GetText() == "Scan my materials", "scan did not finish")
    -- stopping
    local n = #sent
    READY = false
    AP:StartTargeted()
    AP:StopScan()
    READY = true
    FLUSH()
    EXPECT(#sent == n, "a stopped scan kept searching")
    -- full scan: behind a warning, then the whole house, read from index 0
    AP.panel.full:GetScript("OnClick")(AP.panel.full)
    EXPECT(popup == "PROFBUDDY_FULL_SCAN", "no warning before a full scan")
    REPL = { { 2318, 4, 160 }, { 2318, 1, 35 }, { 12345, 1, 1 } }
    FIRE("REPLICATE_ITEM_LIST_UPDATE")
    EXPECT(rec(2318) == nil, "another addon's full scan was read")
    StaticPopupDialogs.PROFBUDDY_FULL_SCAN.OnAccept()
    EXPECT(replicated, "full scan not requested")
    FIRE("REPLICATE_ITEM_LIST_UPDATE")
    FLUSH()
    EXPECT(rec(2318) == 35 and rec(12345) == nil, "full scan prices: " .. tostring(rec(2318)))
    -- Auctionator switched on: the tab and PB's page go; recording carries on
    Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function() return nil end } } }
    P:Changed()
    EXPECT(not AP.tab:IsShown() and not AP.panel:IsShown(), "PB's tab shown with Auctionator on")
    S.priceAuctionator = false
    P:Changed()
    EXPECT(AP.tab:IsShown(), "PB's tab not back with Auctionator switched off")
    S.priceAuctionator = true
    FIRE("AUCTION_HOUSE_CLOSED")
    -- a neutral auction house is not recorded: in Booty Bay, Gadgetzan or
    -- Everlook, or where the auctioneer reports a faction not yours
    for _, town in ipairs({ "Booty Bay", "Gadgetzan", "Everlook" }) do
        SUB = town
        FIRE("AUCTION_HOUSE_SHOW")
        FLUSH()
        BROWSE = { { itemKey = { itemID = 2320 }, minPrice = 1 } }
        FIRE("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        EXPECT(not AP._record and rec(2320) == 30, town .. "'s auction house was recorded")
        FIRE("AUCTION_HOUSE_CLOSED")
    end
    SUB = ""
    UnitFactionGroup = function(u) if u == "npc" then return "Alliance" end return baseFaction(u) end
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    FIRE("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    EXPECT(rec(2320) == 30, "an auctioneer of the other faction was recorded")
    FIRE("AUCTION_HOUSE_CLOSED")
    UnitFactionGroup = baseFaction
    GetSubZoneText, GetRealZoneText, C_Map = keepSub, keepZone, keepMap
    -- recorded prices older than 30 days go at login
    PB.db.prices.auction[house][2934].t = time() - 31 * 86400
    EXPECT(P:PruneRecorded() == 1 and rec(2934) == nil, "an old recorded price not pruned")
    StaticPopup_Show = keepPopup
    UnitFactionGroup = baseFaction
    C_AuctionHouse, Auctionator = nil, nil
    P:ClearRecorded()
end
print("  PASS F80 TEST-b: sale price settings, Profit column, sort and loss filter, BoP crafts and materials, plain clicks kept from TSM, TSM box line, K in combat, auction prices recorded (browse, scan, full scan, neutral towns, PB's auction house tab, pruning)")

-- F81 TEST-b2: a profession that opens in combat (K in combat: Blizzard's
-- book reopens the last profession) leaves Blizzard's window alone; the
-- game blocks hiding it then. When combat ends it goes and PB's opens.
do
    local TSF = ProfBuddy.TradeSkillFrame
    local PF = ProfessionsFrame
    if TSF.frame:IsShown() then TSF.frame:Hide() end
    C_TradeSkillUI.CloseTradeSkill()
    FLUSH()
    local keepICL = InCombatLockdown
    FIRE("PLAYER_REGEN_DISABLED")
    InCombatLockdown = function() return true end
    local hides = 0
    rawset(PF, "Hide", function(f) hides = hides + 1 end)
    rawset(PF, "_shown", true)
    C_TradeSkillUI.OpenTradeSkill(165)
    TS_LIST_READY()
    FLUSH()
    EXPECT(hides == 0 and PF:IsShown(), "Blizzard's window hidden in combat")
    EXPECT(not TSF.frame:IsShown() and TSF._pendingOpen == "trade", "PB's window did not wait for combat to end")
    InCombatLockdown = keepICL
    rawset(PF, "Hide", nil)
    FIRE("PLAYER_REGEN_ENABLED")
    FLUSH()
    EXPECT(not PF:IsShown() and TSF.frame:IsShown(), "after combat: Blizzard's window still up or PB's not open")
    TSF.frame:Hide()
    FLUSH()
    -- combat starts after the profession opened but before its list
    -- arrived: PB's window still opens when combat ends
    C_TradeSkillUI.OpenTradeSkill(165)
    FLUSH()
    EXPECT(not TSF.frame:IsShown() and TSF._awaitingTradeList, "PB opened before its list arrived")
    FIRE("PLAYER_REGEN_DISABLED")
    InCombatLockdown = function() return true end
    TS_LIST_READY()
    FLUSH()
    EXPECT(not TSF.frame:IsShown() and TSF._pendingOpen == "trade", "a list arriving in combat: PB's window did not wait")
    InCombatLockdown = keepICL
    FIRE("PLAYER_REGEN_ENABLED")
    FLUSH()
    EXPECT(TSF.frame:IsShown() and not PF:IsShown(), "a list arriving in combat: PB's window not open after combat")
    TSF.frame:Hide()
    FLUSH()
end
print("  PASS F81 TEST-b2: a profession opened in combat leaves Blizzard's window alone until combat ends, then PB's window opens; also when combat starts before the list arrives")

-- F82 TEST-b3: the auction house tab reads PB when the tabs don't fit
-- (Auctionator's four and TSM's ran past the window's edge), with a
-- tooltip naming ProfessionBuddy; the full name comes back with room
do
    local AP = ProfBuddy.AuctionPrices
    local AHF, tab = AuctionHouseFrame, AP.tab
    EXPECT(tab and tab:GetText() == "ProfessionBuddy", "the tab before: " .. tostring(tab and tab:GetText()))
    local R, W = 0, 0
    rawset(AHF, "GetRight", function() return 975 end)
    rawset(tab, "GetRight", function() return R end)
    rawset(tab, "GetWidth", function() return W end)
    R, W = 1030, 158
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    EXPECT(tab:IsShown() and tab:GetText() == "PB" and AP._tabShort, "crowded: the label is " .. tostring(tab:GetText()))
    rawset(GameTooltip, "_text", nil)
    tab._h.OnEnter(tab)
    EXPECT(rawget(GameTooltip, "_text") == "ProfessionBuddy", "no ProfessionBuddy tooltip on the short tab")
    GameTooltip:Show()
    tab._h.OnLeave(tab)
    EXPECT(not GameTooltip:IsShown() and not AP._tabTip, "the tab's tooltip stayed after leaving it")
    FIRE("AUCTION_HOUSE_CLOSED")
    -- still no room for the full name (900 - 70 + 158 = 988, past 975)
    R, W = 900, 70
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    EXPECT(tab:GetText() == "PB", "the full name came back without room")
    FIRE("AUCTION_HOUSE_CLOSED")
    -- room again (800 - 70 + 158 = 888)
    R, W = 800, 70
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    EXPECT(tab:GetText() == "ProfessionBuddy" and not AP._tabShort, "the full name did not come back with room")
    rawset(GameTooltip, "_text", nil)
    tab._h.OnEnter(tab)
    EXPECT(rawget(GameTooltip, "_text") == nil, "a tooltip on the full-name tab")
    FIRE("AUCTION_HOUSE_CLOSED")
    rawset(AHF, "GetRight", nil); rawset(tab, "GetRight", nil); rawset(tab, "GetWidth", nil)
end
print("  PASS F82 TEST-b3: the auction house tab reads PB when the tabs don't fit, with a ProfessionBuddy tooltip; the full name comes back when it fits")

-- F83 TEST-c items 9 and 3: closing with the X (or Escape, the same
-- frame:Hide) saves the window state; states and window positions are
-- kept across a reload per character, pulled back onto the screen; the
-- Keep box is gray while Remember is off; keeping off clears them
do
    local PB = ProfBuddy
    local TSF, UI, S = PB.TradeSkillFrame, PB.UI, PB.db.settings
    local st = TSF.state
    EXPECT(S.keepWindowState == true and S.rememberWindowState == true, "keep/remember defaults")
    local function open() C_TradeSkillUI.OpenTradeSkill(165); TS_LIST_READY(); FLUSH() end
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    C_TradeSkillUI.CloseTradeSkill(); FLUSH()
    open()
    local cats = {}
    for _, r in ipairs(st.recipes) do if r.isHeader then cats[#cats + 1] = r.name end end
    st.showTab, st.filterDiff, st.filterCat, st.sortBy = "known", "No Gray", cats[2] or cats[1], "Name"
    TSF:RefreshRecipeList()
    local cat = st.filterCat
    TSF.frame:Hide(); FLUSH()                       -- the X button
    open()
    EXPECT(st.filterDiff == "No Gray" and st.filterCat == cat and st.sortBy == "Name",
           "X close lost the state: " .. tostring(st.filterDiff) .. " " .. tostring(st.filterCat) .. " " .. tostring(st.sortBy))
    -- Missing view and Source, closed with the X
    st.showTab, st.filterSource = "missing", "Trainer"
    TSF:RefreshRecipeList()
    TSF.frame:Hide(); FLUSH()
    open()
    EXPECT(st.showTab == "missing" and st.filterSource == "Trainer", "X close lost View or Source")
    st.showTab, st.filterSource = "known", "All"
    TSF:RefreshRecipeList()
    -- positions: the screen and the windows' sizes
    rawset(UIParent, "GetWidth", function() return 1920 end)
    rawset(UIParent, "GetHeight", function() return 1080 end)
    local F = TSF.frame
    rawset(F, "GetWidth", function() return 700 end)
    rawset(F, "GetHeight", function() return 500 end)
    rawset(F, "GetScale", function() return 1 end)
    rawset(F, "GetLeft", function() return 300 end)
    rawset(F, "GetTop", function() return 900 end)
    F:GetScript("OnDragStop")(F)
    local key = PB:PlayerKey()
    local w = PB.db.windows[key]
    EXPECT(w and w.pos and w.pos.profession and w.pos.profession.x == 300 and w.pos.profession.y == 900,
           "drag end did not save the position")
    -- logout: the states go into the saved settings
    FIRE("PLAYER_LOGOUT")
    EXPECT(type(w.states) == "table" and w.states["Leatherworking|self"]
           and w.states["Leatherworking|self"].filterDiff == "No Gray", "states not kept at logout")
    -- a new session: states and position come back
    TSF.frame:Hide(); FLUSH()
    TSF._savedStates, TSF._keptLoaded = {}, nil
    rawset(F, "_pbPosRestored", false)
    open()
    EXPECT(st.filterDiff == "No Gray" and st.filterCat == cat, "states not back after a reload")
    local lp = rawget(F, "_lastPoint")
    EXPECT(lp and lp[1] == "TOPLEFT" and lp[2] == UIParent and lp[4] == 300 and lp[5] == 900,
           "position not back after a reload: " .. tostring(lp and lp[4]) .. "," .. tostring(lp and lp[5]))
    -- a smaller screen: pulled back on (1920 - 700, at least the height)
    TSF.frame:Hide(); FLUSH()
    w.pos.profession = { x = 5000, y = 99 }
    rawset(F, "_pbPosRestored", false)
    open()
    lp = rawget(F, "_lastPoint")
    EXPECT(lp[4] == 1220 and lp[5] == 500, "off-screen position not pulled back: " .. tostring(lp[4]) .. "," .. tostring(lp[5]))
    -- the Keep box is gray while Remember is off
    local rcb, kcb = TSF.rememberCB, TSF.keepCB
    EXPECT(rcb and kcb and kcb:IsEnabled(), "Keep box missing or gray with Remember on")
    rawset(rcb, "GetChecked", function() return false end)
    rcb:GetScript("OnClick")(rcb)
    EXPECT(S.rememberWindowState == false and not kcb:IsEnabled(), "Keep box usable with Remember off")
    rawset(rcb, "GetChecked", function() return true end)
    rcb:GetScript("OnClick")(rcb)
    rawset(rcb, "GetChecked", nil)
    EXPECT(S.rememberWindowState == true and kcb:IsEnabled(), "Keep box gray with Remember back on")
    -- keeping off: nothing of this character's carries over
    S.keepWindowState = false
    FIRE("PLAYER_LOGOUT")
    EXPECT(w.states == nil and w.pos == nil, "kept states or positions with keeping off")
    S.keepWindowState = true
    -- the main window keeps its position too
    UI:Show()
    local M = UI.frame
    rawset(M, "GetScale", function() return 1 end)
    rawset(M, "GetLeft", function() return 40 end)
    rawset(M, "GetTop", function() return 700 end)
    M:Hide()
    EXPECT(PB.db.windows[key].pos and PB.db.windows[key].pos.main and PB.db.windows[key].pos.main.x == 40,
           "the main window's position not saved on close")
    for _, k in ipairs({ "GetWidth", "GetHeight", "GetScale", "GetLeft", "GetTop" }) do rawset(F, k, nil); rawset(M, k, nil) end
    rawset(UIParent, "GetWidth", nil); rawset(UIParent, "GetHeight", nil)
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
end
print("  PASS F83 TEST-c: X and Escape save the window state (View, Skill-up, Source, Type, Sort); states and positions kept across a reload per character, pulled onto the screen; Keep gray with Remember off; keeping off clears them; the main window's position")

-- F84 TEST-c items 1 and 2 (N1, N2): a bottom tab parks the profession
-- (session kept, state kept); Back brings it back; the park ends on the
-- close event and when the main window closes (closing the session); the
-- main window's strip is plain buttons on WoW: Forever and opens a
-- profession by skill line; the tabs' content starts below it
do
    local PB = ProfBuddy
    local TSF, UI = PB.TradeSkillFrame, PB.UI
    local st = TSF.state
    local function open() C_TradeSkillUI.OpenTradeSkill(165); TS_LIST_READY(); FLUSH() end
    local function closes() local n = 0; for _, c in ipairs(TS_CALLS) do if c == "CloseTradeSkill" then n = n + 1 end end; return n end
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    C_TradeSkillUI.CloseTradeSkill(); FLUSH()
    EXPECT(UI.profStrip and UI.profStrip.secure == false and UI.backBtn, "no plain strip or Back button in the main window")
    EXPECT(UI.CONTENT_TOP == 52, "tab content not below the strip")
    EXPECT(UI.profStrip.byName.Leatherworking and not UI.profStrip.byName["Find Minerals"] and not UI.profStrip.byName.Poisons,
           "the plain strip kept a cast-only profession")
    open()
    st.filterDiff = "No Gray"
    TSF:RefreshRecipeList()
    local before = closes()
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])        -- Characters
    FLUSH()
    EXPECT(not TSF.frame:IsShown() and UI.frame:IsShown(), "bottom tab: profession not parked or main window not shown")
    EXPECT(closes() == before and TS.open == "Leatherworking", "parking closed the game's session")
    EXPECT(TSF._parked and TSF._parked.prof == "Leatherworking" and UI.backBtn:IsShown()
           and UI.backBtn:GetText() == "Back to Leatherworking", "no Back button: " .. tostring(UI.backBtn:GetText()))
    EXPECT(UI.profStrip.byName.Leatherworking:IsShown(), "the strip has no Leatherworking icon")
    UI.backBtn:GetScript("OnClick")(UI.backBtn)
    FLUSH()
    EXPECT(TSF.frame:IsShown() and not UI.frame:IsShown() and st.filterDiff == "No Gray" and not TSF._parked,
           "Back did not bring the profession back as it was")
    -- the game closes the parked session: the park ends
    TSF.navTabs[2]:GetScript("OnClick")(TSF.navTabs[2])        -- Friends
    FLUSH()
    EXPECT(TSF._parked, "not parked from Friends")
    C_TradeSkillUI.CloseTradeSkill(); FLUSH()
    EXPECT(not TSF._parked and not UI.backBtn:IsShown(), "the park outlived the game's close event")
    -- closing the main window while parked closes the session (D2)
    open()
    TSF.navTabs[3]:GetScript("OnClick")(TSF.navTabs[3])        -- Guild
    FLUSH()
    EXPECT(TSF._parked and TS.open == "Leatherworking", "not parked from Guild")
    before = closes()
    UI:Hide()
    FLUSH()
    EXPECT(not TSF._parked and TS.open == nil and closes() == before + 1, "closing the main window left the session open")
    -- the strip opens a profession by skill line, and the main window goes
    UI:Show()
    FLUSH()
    local lw = UI.profStrip.byName.Leatherworking
    lw:GetScript("OnClick")(lw)
    TS_LIST_READY(); FLUSH()
    EXPECT(TS.open == "Leatherworking" and TSF.frame:IsShown() and not UI.frame:IsShown(),
           "the main window's Leatherworking icon did not open it")
    -- WoW: Forever: the main window is never locked in combat
    local keepICL = InCombatLockdown
    InCombatLockdown = function() return true end
    EXPECT(not UI:Locked(), "main window locked in combat on WoW: Forever")
    InCombatLockdown = keepICL
    TSF.frame:Hide(); FLUSH()
end
print("  PASS F84 TEST-c: a bottom tab parks the profession (session and state kept), Back brings it back, the park ends on the close event and closing the main window closes the session; the main window's plain strip opens a profession; content below the strip")

-- F85 TEST-c item 6 (G1): a guildmate's profession with no recipes: PB
-- asks, the icon reads as pending, and the profession opens when the
-- reply arrives, once; no answer says so after the wait; stored recipes
-- open at once and still ask
do
    local PB = ProfBuddy
    local GP, C, S = PB.GuildPanel, PB.Comm, PB.db
    local opened, asked = {}, {}
    local keepReq, keepOpen = C.RequestGuildSync, PB.TradeSkillFrame.OpenWithCharacter
    C.RequestGuildSync = function(_, key) asked[#asked + 1] = key end
    PB.TradeSkillFrame.OpenWithCharacter = function(_, key, prof) opened[#opened + 1] = key .. "|" .. prof end
    local HIR = PB:NormKey("Hircus Stone")
    S.characters[HIR] = nil
    PRINTS = {}
    EXPECT(GP:AskThenOpen(HIR, "Tailoring") == false and #asked == 1 and #opened == 0, "no recipes: did not ask, or opened")
    EXPECT(PRINTED("Asked Hircus Stone for their Tailoring recipes. They open when they arrive."), "no asked line")
    EXPECT(GP:IsPending(HIR, "Tailoring") and not GP:IsPending(HIR, "Cooking"), "not pending")
    S.characters[HIR] = { isRemote = true, lastSync = time(), professions = { Tailoring = { skillLevel = 80,
        recipes = { ["Bolt of Linen Cloth"] = true } } } }
    C:NotifyUIRefresh()
    C:NotifyUIRefresh()
    EXPECT(#opened == 1 and opened[1] == HIR .. "|Tailoring" and not GP:IsPending(HIR, "Tailoring"),
           "the reply did not open the profession once: " .. #opened)
    -- stored recipes: opens at once and still asks
    opened, asked = {}, {}
    EXPECT(GP:AskThenOpen(HIR, "Tailoring") == true and #opened == 1 and #asked == 1, "stored recipes did not open at once")
    -- nobody answers: one line after the wait, then not pending
    S.characters[HIR] = nil
    GP:AskThenOpen(HIR, "Tailoring")
    PRINTS = {}
    FLUSH()
    EXPECT(PRINTED("Hircus Stone didn't answer (offline or not running ProfessionBuddy).") and not GP:IsPending(HIR, "Tailoring"),
           "no line when nobody answers")
    C.RequestGuildSync, PB.TradeSkillFrame.OpenWithCharacter = keepReq, keepOpen
end
print("  PASS F85 TEST-c: G1, a guildmate's profession with no recipes asks, shows as pending, opens when the reply arrives (once); no answer says so; stored recipes open at once and still ask")

-- F86 TEST-c item 8 (G2): the background fill asks online guildmates who
-- run PB and have a profession page, no recipes first then the oldest,
-- one every FILL_GAP seconds, each once; skips fresh, offline, asked in
-- the last FILL_RETRY, and anyone pulled meanwhile; off with the setting;
-- starts on a roster change
do
    local PB = ProfBuddy
    local GP, C, S = PB.GuildPanel, PB.Comm, PB.db
    local keep = { IsInGuild = IsInGuild, GetNumGuildMembers = GetNumGuildMembers, GetGuildRosterInfo = GetGuildRosterInfo }
    local roster = {
        { "Amy Stitch", true }, { "Ben Hide", true }, { "Cal Fresh", true },
        { "Dot Away", false }, { "Eli Herb", true },
    }
    IsInGuild = function() return true end
    GetNumGuildMembers = function() return #roster end
    GetGuildRosterInfo = function(i) return roster[i][1], "Member", 1, 20, nil, nil, nil, nil, roster[i][2] end
    C._guildSet = nil
    local K = {}
    for _, r in ipairs(roster) do K[r[1]] = PB:NormKey(r[1]) end
    local now = time()
    local function tailor(recipes, at)
        return { isRemote = true, lastSync = at, professions = { Tailoring = { skillLevel = 80,
            recipes = recipes and { ["Bolt of Linen Cloth"] = true } or nil } } }
    end
    S.characters[K["Amy Stitch"]] = tailor(false, 0)                 -- no recipes yet
    S.characters[K["Ben Hide"]]   = tailor(true, now - 13 * 3600)     -- old
    S.characters[K["Cal Fresh"]]  = tailor(true, now - 3600)          -- fresh
    S.characters[K["Dot Away"]]   = tailor(false, 0)                  -- offline
    S.characters[K["Eli Herb"]]   = { isRemote = true, professions = {} }   -- runs PB, no professions
    local asked = {}
    local keepReq = C.RequestGuildSync
    C.RequestGuildSync = function(_, key) asked[#asked + 1] = key end
    GP._fillAsked, GP._fill, GP._lastFill, GP._fillTimer = {}, nil, nil, nil
    EXPECT(PB.db.settings.guildKeepRecipes == true, "the setting is not on by default")
    local q = GP:FillQueue()
    EXPECT(#q == 2 and q[1].key == K["Amy Stitch"] and q[2].key == K["Ben Hide"],
           "fill order: " .. #q .. " " .. tostring(q[1] and q[1].key) .. " " .. tostring(q[2] and q[2].key))
    GP:StartFill()
    EXPECT(#asked == 1 and asked[1] == K["Amy Stitch"] and GP._fill, "the fill did not ask the first guildmate at once")
    FLUSH()
    EXPECT(#asked == 2 and asked[2] == K["Ben Hide"] and not GP._fill and #GP._lastFill.asked == 2,
           "the fill did not go on to the next, or did not end")
    -- asked in the last FILL_RETRY: not again
    asked = {}
    GP:StartFill(); FLUSH()
    EXPECT(#asked == 0, "the fill asked the same guildmates again at once")
    -- pulled meanwhile (a click): skipped as fresh
    GP._fillAsked = {}
    GP:StartFill()
    S.characters[K["Ben Hide"]].lastSync = time()
    FLUSH()
    EXPECT(#asked == 1 and GP._lastFill.skipped[1] and GP._lastFill.skipped[1].why == "fresh", "a guildmate pulled meanwhile was asked")
    -- the setting off: nothing
    GP._fillAsked, asked = {}, {}
    PB.db.settings.guildKeepRecipes = false
    GP:StartFill(); FLUSH()
    EXPECT(#asked == 0, "the fill ran with the setting off")
    PB.db.settings.guildKeepRecipes = true
    -- a roster change starts one after the delay
    S.characters[K["Ben Hide"]].lastSync = now - 13 * 3600
    FIRE("GUILD_ROSTER_UPDATE")
    FLUSH()
    EXPECT(#asked == 2, "a roster change did not start a fill: " .. #asked)
    C.RequestGuildSync = keepReq
    for k, v in pairs(keep) do _G[k] = v end
    C._guildSet = nil
    for _, key in pairs(K) do S.characters[key] = nil end
    GP._fillAsked, GP._fill, GP._fillTimer = {}, nil, nil
end
print("  PASS F86 TEST-c: G2, the background fill asks online PB guildmates with a profession page, no recipes first then the oldest, one at a time, each once; skips fresh, offline, recently asked and pulled-meanwhile; off with the setting; starts on a roster change")

-- F87 TEST-c items 4 and 5: a Waylaid Supplies crate's and a
-- Craftsman's Writ's tooltip show the fill cost from Prices.lua, "?"
-- without a price, the writ's own auction price, and the gray rewards
-- line; nothing with Show prices off; the baked tables are well-formed
do
    local PB = ProfBuddy
    local P, S = PB.Prices, PB.db.settings
    local n, ok = 0, true
    for crate, e in pairs(PB.Waylaid or {}) do
        n = n + 1
        if not (type(e[1]) == "number" and e[2] >= 1 and e[3] > 0 and type(e[4]) == "string" and e[4] ~= "") then ok = false end
    end
    EXPECT(n == 104 and ok and PB.Waylaid[210771][1] == 2840 and PB.Waylaid[210771][2] == 20, "Waylaid table: " .. n)
    local w = 0
    for _, e in pairs(PB.Writs or {}) do w = w + 1; if not (e[1] > 0 and e[2] >= 1 and e[3] > 0 and type(e[4]) == "string" and e[4] ~= "") then ok = false end end
    EXPECT(w == 150 and ok and PB.Writs[264037][2] == 200, "Writs table: " .. w)
    -- every item post-call runs, as the game runs them
    local function post(tip)
        for _, c in ipairs(TOOLTIP_POSTCALLS) do if c.type == Enum.TooltipDataType.Item then c.fn(tip) end end
    end
    local function tipFor(id)
        local lines = {}
        local keepGD = TooltipUtil.GetDisplayedItem
        TooltipUtil.GetDisplayedItem = function() return "x", "|cffffffff|Hitem:" .. id .. "::::::::|h[x]|h|r" end
        rawset(GameTooltip, "AddLine", function(_, t) lines[#lines + 1] = tostring(t) end)
        rawset(GameTooltip, "AddDoubleLine", function(_, a, b) lines[#lines + 1] = tostring(a) .. " = " .. tostring(b) end)
        rawset(GameTooltip, "Show", function() end)
        post(GameTooltip)
        TooltipUtil.GetDisplayedItem = keepGD
        rawset(GameTooltip, "AddLine", nil); rawset(GameTooltip, "AddDoubleLine", nil); rawset(GameTooltip, "Show", nil)
        local plain = {}
        for _, l in ipairs(lines) do
            plain[#plain + 1] = (l:gsub("|T[^|]*|t", function(icon)
                return icon:find("GoldIcon") and "g" or icon:find("SilverIcon") and "s" or "c" end):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end
        return table.concat(plain, "\n")
    end
    P:ClearRecorded()
    local AUC = { [2840] = 30, [264037] = 4000 }
    local keepAuc = Auctionator
    Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return AUC[id] end,
                                   GetAuctionAgeByItemID = function() return 0 end } } }
    local t = tipFor(210771)
    EXPECT(t:find("Fill cost (ProfessionBuddy): = 6s", 1, true) and t:find("20 x ", 1, true)
           and t:find("Reward details: coming in a later update.", 1, true), "crate tooltip:\n" .. t)
    -- a writ: its item has no price here, and the writ's own auction price
    t = tipFor(264037)
    EXPECT(t:find("Fill cost (ProfessionBuddy): = ?", 1, true) and t:find("200 x ", 1, true)
           and t:find("Writ sells for = 40s", 1, true), "writ tooltip:\n" .. t)
    -- the item not loaded yet (m4ru, TEST-c4: "200 x item:8069"): the
    -- baked name
    local keepGII = GetItemInfo
    GetItemInfo = function(id, ...) if id == 8069 then return nil end; return keepGII(id, ...) end
    t = tipFor(264037)
    GetItemInfo = keepGII
    EXPECT(t:find("200 x Crafted Solid Shot", 1, true) and not t:find("item:", 1, true), "writ tooltip, item not loaded:\n" .. t)
    -- Show prices off: nothing
    S.showPrices = false
    t = tipFor(210771)
    EXPECT(not t:find("Fill cost", 1, true), "fill cost with Show prices off")
    S.showPrices = true
    -- an ordinary item: nothing
    EXPECT(not tipFor(2840):find("Fill cost", 1, true), "fill cost on an ordinary item")
    Auctionator = keepAuc
end
print("  PASS F87 TEST-c: Waylaid Supplies and Craftsman's Writs tooltips: fill cost from Prices.lua, ? without a price, the writ's own auction price, the rewards-later line; the baked item name before the item loads; off with Show prices; the baked tables")

-- F88 TEST-c rebuild: vendor prices only from vendors placed in the world
-- (VMaNGOS 17078, unplaced, was the only seller of Heavy Runecloth
-- Bandage); recipe names wrap to two lines at most
do
    local P = ProfBuddy.Prices
    EXPECT(P:VendorBuy(14530) == nil and P:VendorBuy(2320) == 10, "Forever vendor table")
    local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
    EXPECT(src:find("nameText:SetMaxLines(2)", 1, true), "recipe names not capped at two lines")
end
print("  PASS F88 TEST-c: vendor prices only from placed vendors; recipe names at most two lines")

-- F89 TEST-c2: m4ru's TBC Anniversary run, step A6: the /pb window came
-- back where he dragged it after a /reload with keeping off (the game's
-- own layout cache). A drag clears the game's mark; with nothing kept the
-- first open is the middle of the screen. Step 14: Back sits at the right
-- end of the icon row, the icons at the left.
local function F89()
    local PB = ProfBuddy
    local UI, S = PB.UI, PB.db.settings
    local M = UI.frame
    if M:IsShown() then M:Hide() end
    -- a drag: the game's mark is cleared at its end
    M:GetScript("OnDragStart")(M)
    EXPECT(M:IsUserPlaced(), "harness: StartMoving did not mark the window")
    M:GetScript("OnDragStop")(M)
    EXPECT(not M:IsUserPlaced(), "a drag left the window marked as placed by you")
    -- keeping off, and the game put it back from an older build's drag
    S.keepWindowState = false
    rawset(M, "_userPlaced", true)
    M:ClearAllPoints(); M:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 40, 700)
    rawset(M, "_pbPosRestored", false)
    UI:Show()
    local lp = rawget(M, "_lastPoint")
    EXPECT(lp and lp[1] == "CENTER" and rawget(M, "_points") == 1 and not M:IsUserPlaced(),
           "keeping off: the first open is not the middle: " .. tostring(lp and lp[1]))
    -- moved during the session: the next open keeps it there
    M:Hide()
    M:ClearAllPoints(); M:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 40, 700)
    UI:Show()
    lp = rawget(M, "_lastPoint")
    EXPECT(lp and lp[1] == "TOPLEFT", "a second open moved the window")
    M:Hide()
    S.keepWindowState = true
    -- Back at the right end of the row, the icons from the left
    local bp = rawget(UI.backBtn, "_lastPoint")
    EXPECT(bp and bp[1] == "TOPRIGHT" and bp[3] == "TOPRIGHT" and bp[4] == -12,
           "Back not at the right end of the row: " .. tostring(bp and bp[1]))
    local cp = rawget(UI.profStrip.container, "_lastPoint")
    EXPECT(cp and cp[1] == "TOPLEFT" and cp[4] == 12, "icons not from the left: " .. tostring(cp and cp[4]))
end
F89()
print("  PASS F89 TEST-c2: a drag clears the game's placed-by-you mark; keeping off opens the window in the middle once per session; Back at the right end of the icon row")

-- F90 TEST-c2: m4ru's TBC Anniversary run, step B5: Settings opened with
-- the main window's gear while a profession was parked closed the main
-- window, which ended the park, and Back was gone on the way back. The
-- way to Settings and back keeps the park; Settings closed with its X
-- ends it and closes the session (decision D2).
local function F90()
    local PB = ProfBuddy
    local TSF, UI = PB.TradeSkillFrame, PB.UI
    local function open() C_TradeSkillUI.OpenTradeSkill(165); TS_LIST_READY(); FLUSH() end
    local function closes() local n = 0; for _, c in ipairs(TS_CALLS) do if c == "CloseTradeSkill" then n = n + 1 end end; return n end
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI.frame:Hide(); FLUSH() end
    C_TradeSkillUI.CloseTradeSkill(); FLUSH()
    open()
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])        -- Characters
    FLUSH()
    EXPECT(TSF._parked and UI.backBtn:IsShown(), "not parked from Characters")
    local before = closes()
    UI.gearBtn:GetScript("OnClick")(UI.gearBtn)
    FLUSH()
    EXPECT(TSF.settingsPanel:IsShown() and TSF.frame:IsShown() and not UI.frame:IsShown(), "the gear did not open Settings")
    EXPECT(TSF._parked and TS.open == "Leatherworking" and closes() == before, "opening Settings ended the park")
    -- the setting he changed, then back to the main window
    PB.db.settings.showAllProfessions = true
    TSF:UpdateProfessionTabs()
    TSF:CloseSettings()
    FLUSH()
    EXPECT(UI.frame:IsShown() and not TSF.frame:IsShown(), "Settings did not go back to the main window")
    EXPECT(TSF._parked and UI.backBtn:IsShown() and UI.backBtn:GetText() == "Back to Leatherworking"
           and TS.open == "Leatherworking" and closes() == before, "Back gone after Settings")
    PB.db.settings.showAllProfessions = false
    TSF:UpdateProfessionTabs()
    UI.backBtn:GetScript("OnClick")(UI.backBtn)
    FLUSH()
    EXPECT(TSF.frame:IsShown() and not TSF._parked and TS.open == "Leatherworking", "Back after Settings did not bring it back")
    -- the same through /pb settings
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])
    FLUSH()
    SlashCmdList.PROFBUDDY("settings")
    FLUSH()
    EXPECT(TSF.settingsPanel:IsShown() and TSF._parked, "/pb settings ended the park")
    TSF:CloseSettings()
    FLUSH()
    EXPECT(UI.frame:IsShown() and TSF._parked and UI.backBtn:IsShown(), "Back gone after /pb settings")
    UI.backBtn:GetScript("OnClick")(UI.backBtn)
    FLUSH()
    -- Settings closed with its X while parked: the session closes (D2)
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])
    FLUSH()
    UI.gearBtn:GetScript("OnClick")(UI.gearBtn)
    FLUSH()
    before = closes()
    TSF.frame:Hide()
    FLUSH()
    EXPECT(not TSF._parked and TS.open == nil and closes() == before + 1, "Settings closed with the X left a hidden session open")
    TSF:RestoreContentPanels()
    if TSF.settingsPanel:IsShown() then TSF.settingsPanel:Hide() end
end
F90()
print("  PASS F90 TEST-c2: Settings from the main window's gear or /pb settings keeps a parked profession and its Back; Settings closed with the X ends the park and closes the session")

-- F91 TEST-c4: the parked profession's own icon in the main window works
-- as Back (m4ru); with keeping on and nothing saved yet, the first open
-- leaves the window where it is (a 2.0.2 window the game kept in place
-- would otherwise jump to the middle once after updating)
local function F91()
    local PB = ProfBuddy
    local TSF, UI, S = PB.TradeSkillFrame, PB.UI, PB.db.settings
    local function open() C_TradeSkillUI.OpenTradeSkill(165); TS_LIST_READY(); FLUSH() end
    local function closes() local n = 0; for _, c in ipairs(TS_CALLS) do if c == "CloseTradeSkill" then n = n + 1 end end; return n end
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI.frame:Hide(); FLUSH() end
    C_TradeSkillUI.CloseTradeSkill(); FLUSH()
    local cover, lw = UI.parkedTab, UI.profStrip.byName.Leatherworking
    EXPECT(cover and not cover:IsShown(), "the cover shows with nothing parked")
    open()
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])        -- Characters
    FLUSH()
    EXPECT(TSF._parked and cover:IsShown() and rawget(cover, "_allPoints") == lw,
           "no button over the parked Leatherworking icon")
    local opened = 0
    local keepOpen = C_TradeSkillUI.OpenTradeSkill
    C_TradeSkillUI.OpenTradeSkill = function(...) opened = opened + 1; return keepOpen(...) end
    local before = closes()
    cover:GetScript("OnClick")(cover)
    FLUSH()
    C_TradeSkillUI.OpenTradeSkill = keepOpen
    EXPECT(TSF.frame:IsShown() and not UI.frame:IsShown() and not TSF._parked and TS.open == "Leatherworking"
           and closes() == before and opened == 0, "the parked icon did not work as Back")
    -- the park ends on the game's close event: the cover goes
    TSF.navTabs[2]:GetScript("OnClick")(TSF.navTabs[2])        -- Friends
    FLUSH()
    EXPECT(cover:IsShown(), "no cover when parked from Friends")
    C_TradeSkillUI.CloseTradeSkill(); FLUSH()
    EXPECT(not TSF._parked and not cover:IsShown(), "the cover outlived the park")
    -- another profession's icon is not covered
    EXPECT(not (cover:IsShown() and rawget(cover, "_allPoints") ~= lw), "the cover sits over another icon")
    UI.frame:Hide(); FLUSH()
    -- keeping on, nothing saved: the first open leaves the window put
    local M = UI.frame
    local key = PB:PlayerKey()
    if PB.db.windows[key] then PB.db.windows[key].pos = nil end
    S.keepWindowState = true
    rawset(M, "_userPlaced", true)
    M:ClearAllPoints(); M:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 40, 700)
    rawset(M, "_pbPosRestored", false)
    UI:Show()
    local lp = rawget(M, "_lastPoint")
    EXPECT(lp and lp[1] == "TOPLEFT" and lp[4] == 40 and rawget(M, "_points") == 1 and not M:IsUserPlaced(),
           "keeping on, nothing saved: the window moved on its first open: " .. tostring(lp and lp[1]))
    M:Hide()
end
F91()
print("  PASS F91 TEST-c4: the parked profession's icon in the main window works as Back, gone when the park ends; keeping on with nothing saved leaves the window where it is")

-- F92 TEST-c6: m4ru's TEST-c5 run on TBC Anniversary: in combat, a bottom
-- tab tried to hide the profession window and the game blocked it
-- (ADDON_ACTION_BLOCKED on ProfBuddyTradeSkillFrame:Hide()). The harness
-- now blocks what the game blocks (forever_env.lua, BLOCKED). Every way PB
-- shows, hides or moves the profession window, done in combat: nothing is
-- blocked, chat says what opens when combat ends, and it does then.
local function F92()
    local PB = ProfBuddy
    local TSF, UI = PB.TradeSkillFrame, PB.UI
    local keepICL = InCombatLockdown
    local function fight(on) InCombatLockdown = on and function() return true end or keepICL end
    local function open() C_TradeSkillUI.OpenTradeSkill(165); TS_LIST_READY(); FLUSH() end
    local function clean()
        fight(false)
        if TSF.settingsPanel and TSF.settingsPanel:IsShown() then TSF:CloseSettings() end
        if TSF.frame:IsShown() then TSF.frame:Hide() end
        if UI.frame:IsShown() then UI.frame:Hide() end
        C_TradeSkillUI.CloseTradeSkill(); FLUSH()
        BLOCKED = {}
    end
    local function ended() fight(false); FIRE("PLAYER_REGEN_ENABLED"); FLUSH() end
    local function ok(label) EXPECT(#BLOCKED == 0, label .. ": the game would block " .. table.concat(BLOCKED, ", ")) end
    clean()
    -- the profession window holds secure buttons: the game protects it
    EXPECT(TSF.frame:IsProtected(), "harness: the profession window is not protected")
    -- the bottom tabs, each in combat
    local names = { "Characters", "Friends", "Guild", "Orders" }
    for i, name in ipairs(names) do
        clean(); open()
        fight(true); PRINTS = {}
        TSF.navTabs[i]:GetScript("OnClick")(TSF.navTabs[i]); FLUSH()
        ok(name .. " tab in combat")
        EXPECT(TSF.frame:IsShown() and not TSF._parked and PRINTED(name .. " opens when combat ends."),
               name .. " tab in combat: no wait, or something moved")
        ended()
        ok(name .. " tab after combat")
        EXPECT(not TSF.frame:IsShown() and TSF._parked and UI.frame:IsShown(), name .. " did not open when combat ended")
    end
    -- /pb, /pb friends with the profession window open
    -- /pb and /pb friends close the profession; the tab commands park it,
    -- as each does out of combat
    local parks = { [""] = false, friends = false, chars = true, guild = true, orders = true }
    for _, cmd in ipairs({ "", "friends", "chars", "guild", "orders" }) do
        clean(); open()
        fight(true); PRINTS = {}
        SlashCmdList.PROFBUDDY(cmd); FLUSH()
        ok("/pb " .. cmd .. " in combat")
        EXPECT(TSF.frame:IsShown() and PRINTED("when combat ends."), "/pb " .. cmd .. " in combat: no wait")
        ended()
        ok("/pb " .. cmd .. " after combat")
        EXPECT(not TSF.frame:IsShown() and UI.frame:IsShown(), "/pb " .. cmd .. " did not open when combat ended")
        EXPECT((TSF._parked and true or false) == parks[cmd], "/pb " .. cmd .. " after combat: parked " .. tostring(TSF._parked ~= nil))
    end
    -- Settings: from the profession window it changes in place; from the
    -- main window it waits, opening and closing
    clean(); open()
    fight(true)
    SlashCmdList.PROFBUDDY("settings"); FLUSH()
    ok("/pb settings in the profession window in combat")
    EXPECT(TSF.settingsPanel:IsShown(), "Settings did not open in place")
    TSF:ToggleSettings(); FLUSH()
    ok("closing Settings in the profession window in combat")
    clean()
    UI:Show(); FLUSH()
    fight(true); PRINTS = {}
    UI.gearBtn:GetScript("OnClick")(UI.gearBtn); FLUSH()
    ok("the main window's gear in combat")
    EXPECT(UI.frame:IsShown() and not TSF.frame:IsShown() and PRINTED("Settings open when combat ends."), "the gear in combat: no wait")
    ended()
    EXPECT(TSF.settingsPanel:IsShown() and TSF.frame:IsShown() and not UI.frame:IsShown(), "Settings did not open when combat ended")
    fight(true); PRINTS = {}
    TSF:CloseSettings(); FLUSH()
    ok("closing Settings to the main window in combat")
    EXPECT(TSF.frame:IsShown() and PRINTED("Settings close when combat ends."), "closing Settings in combat: no wait")
    ended()
    EXPECT(not TSF.frame:IsShown() and UI.frame:IsShown(), "Settings did not go back to the main window after combat")
    clean()
    UI:Show(); FLUSH()
    fight(true)
    SlashCmdList.PROFBUDDY("settings"); FLUSH()
    ok("/pb settings from the main window in combat")
    EXPECT(UI.frame:IsShown() and not TSF.frame:IsShown(), "/pb settings in combat closed the main window with nothing to show")
    ended()
    EXPECT(TSF.settingsPanel:IsShown() and not UI.frame:IsShown(), "/pb settings did not open when combat ended")
    -- /pb settings with no window open
    clean()
    fight(true); PRINTS = {}
    SlashCmdList.PROFBUDDY("settings"); FLUSH()
    ok("/pb settings with no window open, in combat")
    EXPECT(not TSF.frame:IsShown() and PRINTED("Settings open when combat ends."), "/pb settings, no window, in combat: no wait")
    ended()
    EXPECT(TSF.settingsPanel:IsShown() and TSF.frame:IsShown(), "/pb settings did not open when combat ended")
    -- another character's recipes and read-only lists, from a hidden
    -- window (a guildmate's arriving by themselves comes this way too)
    clean()
    fight(true); PRINTS = {}
    TSF:OpenWithCharacter(PB:PlayerKey(), "Leatherworking"); FLUSH()
    ok("a character's recipes in combat")
    EXPECT(not TSF.frame:IsShown() and PRINTED("Leatherworking opens when combat ends."), "a character's recipes in combat: no wait")
    ended()
    EXPECT(TSF.frame:IsShown(), "a character's recipes did not open when combat ended")
    clean()
    fight(true)
    TSF:OpenWithStatic("Tailoring"); FLUSH()
    ok("a read-only list in combat")
    EXPECT(not TSF.frame:IsShown(), "a read-only list showed in combat")
    ended()
    EXPECT(TSF.frame:IsShown() and TSF.state._isStaticView, "a read-only list did not open when combat ended")
    -- with the window open, another list changes in place
    fight(true)
    TSF:OpenWithStatic("Blacksmithing"); FLUSH()
    ok("another read-only list, in place, in combat")
    TSF:OpenWithCharacter(PB:PlayerKey(), "Leatherworking"); FLUSH()
    ok("a character's recipes, in place, in combat")
    -- your own profession, asked to open on a hidden window in combat
    clean(); open()
    TSF._keepSession = true; TSF.frame:Hide(); TSF._keepSession = nil; FLUSH()
    fight(true); PRINTS = {}
    TSF:OpenWith("Leatherworking", 100, 300, false); FLUSH()
    ok("your profession opening on a hidden window in combat")
    EXPECT(not TSF.frame:IsShown() and PRINTED("opens when combat ends."), "your profession in combat: no wait")
    ended()
    EXPECT(TSF.frame:IsShown(), "your profession did not open when combat ended")
    -- dragging it, and PB closing it, in combat
    fight(true)
    TSF.frame:GetScript("OnDragStart")(TSF.frame)
    TSF.frame:GetScript("OnDragStop")(TSF.frame)
    ok("dragging the profession window in combat")
    PRINTS = {}
    TSF:Hide(); FLUSH()
    ok("PB closing the profession window in combat")
    EXPECT(TSF.frame:IsShown() and PRINTED("The profession window closes when combat ends."), "closing in combat: no wait")
    ended()
    EXPECT(not TSF.frame:IsShown(), "the profession window did not close when combat ended")
    -- the bottom-tab park itself, called in combat: nothing moves
    clean(); open()
    fight(true)
    TSF:HideForMain(); FLUSH()
    ok("HideForMain in combat")
    EXPECT(TSF.frame:IsShown() and not TSF._parked, "HideForMain parked in combat")
    -- the window's X or Escape in combat (the game's own close): what PB
    -- does after it is allowed
    GAME_CLOSE(TSF.frame); FLUSH()
    ok("the profession window's X in combat")
    EXPECT(not TSF.frame:IsShown(), "harness: GAME_CLOSE did not close it")
    ended()
    ok("after the X in combat")
    clean()
end
F92()
print("  PASS F92 TEST-c6: in combat, the bottom tabs, /pb and its tab commands, Settings from either window, a character's recipes, read-only lists, dragging, PB closing the profession window, and its X: nothing the game blocks, a chat line, and each runs when combat ends")

print("ALL FOREVER TESTS PASS (92)")
