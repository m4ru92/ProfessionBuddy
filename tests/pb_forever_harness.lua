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
print("  PASS F25 first-open prompt (Escape asks again next session); Learn as you go lists only seen recipes and the counts follow; separate alts count their own sightings, pre-4d records stay everyone's; Settings title-line controls")

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
EXPECT(ProfBuddy.COMM_REV == 11, "COMM_REV is " .. tostring(ProfBuddy.COMM_REV))
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
EXPECT(posts == 2, "item tooltip post-calls: " .. posts)
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

-- F30: a Missing recipe shows the colour it will have once learned, not a
-- placeholder yellow (m4ru 2026-09-29: Kodo Hide Bag read "Yellow - may
-- level up" before he knew it, and will be orange when learned). Kodo
-- Hide Bag is learned at 35 with range 35/65/80/95; below 35 it reads
-- orange, the colour it will have when learned at 35.
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
        { 1,   "Difficulty when learned: Orange - will level up", ORANGE },   -- below 35: learned at 35
        { 64,  "Difficulty when learned: Orange - will level up", ORANGE },
        { 65,  "Difficulty when learned: Yellow - may level up", YELLOW },
        { 80,  "Difficulty when learned: Green - unlikely to level", GREEN },
        { 95,  "Difficulty when learned: Grey - no skill gain", GREY },
    }
    for _, c in ipairs(cases) do
        local d, n, r = at(c[1])
        EXPECT(d == c[2], "skill " .. c[1] .. ": " .. tostring(d))
        EXPECT(n == c[3] and r == c[3], "skill " .. c[1] .. " colours: name " .. tostring(n) .. ", row " .. tostring(r))
    end
    -- no range in PB's data: "not known", in white
    local data = RDB.data.Leatherworking["Kodo Hide Bag"]
    local sr = data.skillRange
    data.skillRange = nil
    TSF:RefreshRecipeList()
    local d, n, r = at(70)
    data.skillRange = sr
    EXPECT(d == "Difficulty when learned: not known", "no range: " .. tostring(d))
    EXPECT(n == WHITE and r == WHITE, "no range colours: name " .. tostring(n) .. ", row " .. tostring(r))
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
print("  PASS F30 a Missing recipe shows the colour it will have once learned, in the detail panel and on its row")

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
    EXPECT(okD and not PRINTED("skinning loot record failed") and after == before, "secret source: " .. tostring(errD))
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
    share._type, share._commrev = "KNOW_DATA", 11
    deliver(PAL, share)
    local fs = ProfBuddyDB.knowledgeShared[PAL]
    EXPECT(fs and fs.loot and fs.loot[3130] and fs.loot[3130].n == 3 and fs.loot[3130].items[2318].max == 2,
           "loot round trip")
    EXPECT(fs.asked.Enchanting and fs.asked.Tailoring and fs.askedLoot == true, "asked state")
    local since = KN:RequestFor(PAL)
    EXPECT(since == fs.since and since > 0, "since kept for the same ask: " .. tostring(since))
    -- Pal learns a new profession: asked from 0 again
    ProfBuddyDB.characters[PAL].professions.Alchemy = { skillLevel = 1, maxSkill = 75, recipes = {} }
    EXPECT(KN:RequestFor(PAL) == 0, "a new profession kept since")
    ProfBuddyDB.characters[PAL].professions.Alchemy = nil
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

print("ALL FOREVER TESTS PASS (40)")
