----------------------------------------------------------------------
-- WoW: Forever harness (Forever 2.0.0, Phases 0, 2a, 2b and 4a).
--
-- Loads ProfessionBuddy_Mainline.toc into a modern-client stub
-- (tests/forever_env.lua) with a fake profession backend built from
-- m4ru's 2026-09-22 harvest (tests/forever_tradeskill.lua), then checks
-- that PB starts cleanly and that its own window reads Forever's
-- professions: Blizzard's window suppressed, the known recipes with
-- reagents, counts, colours and the game's categories, tabs that open by
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
local files, errs = LOAD_TOC("ProfessionBuddy_Mainline.toc")
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
EXPECT(nProf == 13 and nRec == 2347, "expected 13 professions / 2347 recipes, got " .. nProf .. " / " .. nRec)
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
print("  PASS F19 Forever data: 13 professions, 2347 recipes, well-formed, no TBC data; Missing list uses captured learn levels; unknown learn level (" .. unknownLearn .. ") shows without error")

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
local learnBefore = tonumber(TSF.summaryText:GetText():match("Learnable Now: (%d+)"))
TRAINER_OPEN(90001)
FLUSH()
TRAINER_CLOSE()
EXPECT(K[unk.spellID].learnLevel == 1, "test trainer not recorded")
TSF:UpdateBottomBar()
local learnAfter = tonumber(TSF.summaryText:GetText():match("Learnable Now: (%d+)"))
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
-- sources in the Missing view). Skill Up lists skill-up colours and shows
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
EXPECT(values(TSF.diffDropdown) == "All,No Grey,Orange,Yellow,Green,Grey", "Skill Up options: " .. values(TSF.diffDropdown))
EXPECT(values(TSF.sourceDropdown) == "All,Trainer,Vendor,Drop,Quest,Reputation,Discovery,Automatic,Undetermined",
       "Source options: " .. values(TSF.sourceDropdown))
st.searchText = ""
pick(TSF.viewDropdown, "Known")
EXPECT(TSF.diffDropdown:IsShown() and not TSF.sourceDropdown:IsShown(), "Known view: Skill Up only")
pick(TSF.viewDropdown, "Missing")
EXPECT(not TSF.diffDropdown:IsShown() and TSF.sourceDropdown:IsShown(), "Missing view: Source only")
pick(TSF.viewDropdown, "All")
EXPECT(TSF.diffDropdown:IsShown() and TSF.sourceDropdown:IsShown(), "All view: both")
-- All view: a Skill Up colour lists only known recipes, a Source only missing ones
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
print("  PASS F24 Skill Up (colours; Known and All) and Source (sources; Missing and All) are separate; each filters its own recipes; a View change keeps a selection the new view has and clears one it lacks")

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
local me, other = ProfBuddy:PlayerKey(), "Other-Realm"
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
print("  PASS F25 first-open prompt (Escape asks again next session); Learn as you go lists only seen recipes and the counts follow; separate alts count their own sightings, pre-4d records stay everyone's; Settings title-line controls")

local fb = {}
for k in pairs(FALLBACK) do fb[#fb + 1] = k end
table.sort(fb)
print("  INFO globals PB touched that this stub does not model: " .. table.concat(fb, ", "))
print("ALL FOREVER TESTS PASS (25)")
