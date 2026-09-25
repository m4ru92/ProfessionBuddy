----------------------------------------------------------------------
-- WoW: Forever profession fixture for tests/pb_forever_harness.lua.
--
-- Generated from m4ru's ForeverProbe harvest of 2026-09-22 (build 69977,
-- ForeverProbe (3).lua): every LEARNED recipe of Leatherworking, Cooking
-- and Skinning, plus the first 6 unlearned ones of each, with the fields
-- C_TradeSkillUI returned in game. Category names are TradeSkillCategory
-- (DB2 1.60.1.70009); reagent names are ItemSparse (same build).
--
-- Mining is SYNTHETIC: no harvest exists. One recipe (Smelt Copper, 2657)
-- from SkillLineAbility 1.60.1.70009, there only to prove Mining is not
-- filed under Smelting.
----------------------------------------------------------------------
FOREVER_FIXTURE = {
    professions = {
        ["Leatherworking"] = { skillLine = 165, rank = 1, maxRank = 75, recipes = {
            { recipeID = 2881, name = "Light Leather", learned = true, categoryID = 2550, relativeDifficulty = 0, canSkillUp = true, icon = 134252, outputItemID = 2318, reagents = { { itemID = 2934, quantity = 3 } } },
            { recipeID = 9058, name = "Handstitched Leather Cloak", learned = true, categoryID = 2552, relativeDifficulty = 0, canSkillUp = true, icon = 133150, outputItemID = 7276, reagents = { { itemID = 2318, quantity = 2 }, { itemID = 2320, quantity = 1 } } },
            { recipeID = 7126, name = "Handstitched Leather Vest", learned = true, categoryID = 2555, relativeDifficulty = 0, canSkillUp = true, icon = 132760, outputItemID = 5957, reagents = { { itemID = 2318, quantity = 3 }, { itemID = 2320, quantity = 1 } } },
            { recipeID = 9059, name = "Handstitched Leather Bracers", learned = true, categoryID = 2556, relativeDifficulty = 0, canSkillUp = true, icon = 132607, outputItemID = 7277, reagents = { { itemID = 2318, quantity = 2 }, { itemID = 2320, quantity = 3 } } },
            { recipeID = 2149, name = "Handstitched Leather Boots", learned = true, categoryID = 2560, relativeDifficulty = 0, canSkillUp = true, icon = 132538, outputItemID = 2302, reagents = { { itemID = 2318, quantity = 2 }, { itemID = 2320, quantity = 1 } } },
            { recipeID = 2152, name = "Light Armor Kit", learned = true, categoryID = 2569, relativeDifficulty = 0, canSkillUp = true, icon = 133611, outputItemID = 2304, reagents = { { itemID = 2318, quantity = 1 } } },
            { recipeID = 1263079, name = "Sewing Machine", learned = false, categoryID = 2574, relativeDifficulty = 0, canSkillUp = true, icon = 3622223, outputItemID = 279945, reagents = { { itemID = 273130, quantity = 1 }, { itemID = 8170, quantity = 5 }, { itemID = 14341, quantity = 1 } } },
            { recipeID = 1263031, name = "Tanning Rack", learned = false, categoryID = 2574, relativeDifficulty = 0, canSkillUp = true, icon = 4559256, outputItemID = 279941, reagents = { { itemID = 2319, quantity = 5 }, { itemID = 2321, quantity = 3 }, { itemID = 4470, quantity = 2 } } },
            { recipeID = 1229432, name = "Camp Tent", learned = false, categoryID = 2574, relativeDifficulty = 0, canSkillUp = true, icon = 134250, outputItemID = 279978, reagents = { { itemID = 2318, quantity = 5 } } },
            { recipeID = 19047, name = "Cured Rugged Hide", learned = false, categoryID = 2550, relativeDifficulty = 0, canSkillUp = true, icon = 134355, outputItemID = 15407, reagents = { { itemID = 8171, quantity = 1 }, { itemID = 15409, quantity = 1 } } },
            { recipeID = 22331, name = "Rugged Leather", learned = false, categoryID = 2550, relativeDifficulty = 0, canSkillUp = true, icon = 134251, outputItemID = 8170, reagents = { { itemID = 4304, quantity = 6 } } },
            { recipeID = 20650, name = "Thick Leather", learned = false, categoryID = 2550, relativeDifficulty = 0, canSkillUp = true, icon = 134257, outputItemID = 4304, reagents = { { itemID = 4234, quantity = 6 } } },
        } },
        ["Cooking"] = { skillLine = 185, rank = 1, maxRank = 75, recipes = {
            { recipeID = 1229737, name = "Basic Campfire", learned = true, categoryID = 2714, relativeDifficulty = 1, canSkillUp = true, icon = 7808148, outputItemID = 279981, reagents = { { itemID = 4470, quantity = 1 } } },
            { recipeID = 2538, name = "Charred Wolf Meat", learned = true, categoryID = 2632, relativeDifficulty = 0, canSkillUp = true, icon = 133974, outputItemID = 2679, reagents = { { itemID = 2672, quantity = 1 } } },
            { recipeID = 8604, name = "Herb Baked Egg", learned = true, categoryID = 2640, relativeDifficulty = 0, canSkillUp = true, icon = 132834, outputItemID = 6888, reagents = { { itemID = 6889, quantity = 1 }, { itemID = 2678, quantity = 1 } } },
            { recipeID = 2540, name = "Roasted Boar Meat", learned = true, categoryID = 2633, relativeDifficulty = 0, canSkillUp = true, icon = 133974, outputItemID = 2681, reagents = { { itemID = 769, quantity = 1 } } },
            { recipeID = 1263067, name = "Iron Oven", learned = false, categoryID = 2714, relativeDifficulty = 0, canSkillUp = true, icon = 629055, outputItemID = 279982, reagents = { { itemID = 10284, quantity = 10 }, { itemID = 159, quantity = 5 }, { itemID = 3713, quantity = 4 } } },
            { recipeID = 1291341, name = "Expert Campfire", learned = false, categoryID = 2714, relativeDifficulty = 0, canSkillUp = true, icon = 7808148, outputItemID = 279974, reagents = { { itemID = 272941, quantity = 1 } } },
            { recipeID = 1262978, name = "Cookie's Feast", learned = false, categoryID = 2714, relativeDifficulty = 0, canSkillUp = true, icon = 2066011, outputItemID = 279957, reagents = { { itemID = 12037, quantity = 2 }, { itemID = 12204, quantity = 1 }, { itemID = 3713, quantity = 1 } } },
            { recipeID = 1283400, name = "Journeyman Campfire", learned = false, categoryID = 2714, relativeDifficulty = 0, canSkillUp = true, icon = 7808148, outputItemID = 279961, reagents = { { itemID = 11291, quantity = 1 } } },
            { recipeID = 20626, name = "Undermine Clam Chowder", learned = false, categoryID = 2632, relativeDifficulty = 0, canSkillUp = true, icon = 132804, outputItemID = 16766, reagents = { { itemID = 7974, quantity = 2 }, { itemID = 2692, quantity = 1 }, { itemID = 1179, quantity = 1 } } },
            { recipeID = 21175, name = "Spider Sausage", learned = false, categoryID = 2632, relativeDifficulty = 0, canSkillUp = true, icon = 134022, outputItemID = 17222, reagents = { { itemID = 12205, quantity = 2 } } },
        } },
        ["Skinning"] = { skillLine = 393, rank = 43, maxRank = 75, recipes = {
            { recipeID = 1229517, name = "Camp Chair", learned = true, categoryID = 2718, relativeDifficulty = 3, canSkillUp = true, icon = 132761, outputItemID = 279979, reagents = { { itemID = 2318, quantity = 3 }, { itemID = 4470, quantity = 2 } } },
            { recipeID = 1262982, name = "Trapper's Workbench", learned = false, categoryID = 2718, relativeDifficulty = 0, canSkillUp = true, icon = 5948139, outputItemID = 279938, reagents = { { itemID = 4470, quantity = 2 }, { itemID = 4234, quantity = 4 }, { itemID = 3575, quantity = 1 } } },
            { recipeID = 1262985, name = "Field Guide", learned = false, categoryID = 2718, relativeDifficulty = 0, canSkillUp = true, icon = 133735, outputItemID = 279969, reagents = { { itemID = 2319, quantity = 3 }, { itemID = 5784, quantity = 2 }, { itemID = 2321, quantity = 1 } } },
        } },
        ["Mining"] = { skillLine = 186, rank = 1, maxRank = 75, synthetic = true, recipes = {
            { recipeID = 2657, name = "Smelt Copper", learned = true, categoryID = 2575, relativeDifficulty = 0, canSkillUp = true, icon = 133217, outputItemID = 2840, reagents = { { itemID = 2770, quantity = 1 } } },
        } },
    },
    categories = {
        [2550] = "Reagents",
        [2552] = "Cloaks",
        [2555] = "Leather Chestguards",
        [2556] = "Leather Bracers",
        [2560] = "Leather Boots",
        [2569] = "Armor Kits",
        [2574] = "Camping",
        [2575] = "Smelted Bars",
        [2632] = "Everyday Meals",
        [2633] = "Strength Food",
        [2640] = "Stamina Food",
        [2714] = "Camping",
        [2718] = "Camping",
    },
    items = {
        [769] = "Chunk of Boar Meat",
        [2318] = "Light Leather",
        [2320] = "Coarse Thread",
        [2672] = "Stringy Wolf Meat",
        [2678] = "Mild Spices",
        [2770] = "Copper Ore",
        [2840] = "Copper Bar",
        [2934] = "Ruined Leather Scraps",
        [4470] = "Simple Wood",
        [6889] = "Small Egg",
    },
}
