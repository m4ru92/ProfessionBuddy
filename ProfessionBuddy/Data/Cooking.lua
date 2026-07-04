----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Cooking.lua
-- Static recipe database for Cooking (TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
-- Categories based on Well Fed buff type from ItemEffect -> SpellEffect DB2.
-- Values sourced from SkillLineAbility + SpellReagents DB2 (build 2.5.4.44833)
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- NO BUFF
    -- ================================================================
    ["Spice Bread"] = {
        spellID = 37836,
        itemID = 30816,
        skillReq = 1,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "No Buff",
        skillRange = { 1, 30, 35, 40 },
        reagents = {
            { itemID = 30817, count = 1, name = "Simple Flour" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Brilliant Smallfish"] = {
        spellID = 7751,
        itemID = 6290,
        skillReq = 1,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Catherine Leland, Gretta Ganter +7 more" },
        },
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 6291, count = 1, name = "Raw Brilliant Smallfish" } },
    },
    ["Charred Wolf Meat"] = {
        spellID = 2538,
        itemID = 2679,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 2672, count = 1, name = "Stringy Wolf Meat" } },
    },
    ["Roasted Boar Meat"] = {
        spellID = 2540,
        itemID = 2681,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 769, count = 1, name = "Chunk of Boar Meat" } },
    },
    ["Slitherskin Mackerel"] = {
        spellID = 7752,
        itemID = 787,
        skillReq = 1,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kriggon Talsone, Martine Tramblay +3 more" },
        },
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 6303, count = 1, name = "Raw Slitherskin Mackerel" } },
    },
    ["Scorpid Surprise"] = {
        spellID = 6413,
        itemID = 5473,
        skillReq = 20,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Grimtak" },
        },
        category = "No Buff",
        skillRange = { 20, 60, 80, 100 },
        reagents = { { itemID = 5466, count = 1, name = "Scorpid Stinger" } },
    },
    ["Smoked Bear Meat"] = {
        spellID = 8607,
        itemID = 6890,
        skillReq = 40,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Andrew Hilbert, Drac Roughcut" },
        },
        category = "No Buff",
        skillRange = { 40, 80, 100, 120 },
        reagents = { { itemID = 3173, count = 1, name = "Bear Meat" } },
    },
    ["Loch Frenzy Delight"] = {
        spellID = 7754,
        itemID = 6316,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Khara Deepwater" },
        },
        category = "No Buff",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 6317, count = 1, name = "Raw Loch Frenzy" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Longjaw Mud Snapper"] = {
        spellID = 7753,
        itemID = 4592,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Harn Longcast, Khara Deepwater +6 more" },
        },
        category = "No Buff",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 6289, count = 1, name = "Raw Longjaw Mud Snapper" } },
    },
    ["Rainbow Fin Albacore"] = {
        spellID = 7827,
        itemID = 5095,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Catherine Leland, Heldan Galesong +8 more" },
        },
        category = "No Buff",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 6361, count = 1, name = "Raw Rainbow Fin Albacore" } },
    },
    ["Westfall Stew"] = {
        spellID = 2543,
        itemID = 733,
        skillReq = 75,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Westfall Stew" },
        },
        category = "No Buff",
        skillRange = { 75, 115, 135, 155 },
        reagents = {
            { itemID = 729, count = 1, name = "Stringy Vulture Meat" },
            { itemID = 730, count = 1, name = "Murloc Eye" },
            { itemID = 731, count = 1, name = "Goretusk Snout" },
        },
    },
    ["Cooked Crab Claw"] = {
        spellID = 2545,
        itemID = 2682,
        skillReq = 85,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "drop", faction = "Both" },
        },
        category = "No Buff",
        skillRange = { 85, 125, 145, 165 },
        reagents = {
            { itemID = 2675, count = 1, name = "Crawler Claw" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Clam Chowder"] = {
        spellID = 6501,
        itemID = 5526,
        skillReq = 90,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Heldan Galesong, Kriggon Talsone" },
        },
        category = "No Buff",
        skillRange = { 90, 130, 150, 170 },
        reagents = {
            { itemID = 5503, count = 1, name = "Clam Meat" },
            { itemID = 1179, count = 1, name = "Ice Cold Milk" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Dig Rat Stew"] = {
        spellID = 6417,
        itemID = 5478,
        skillReq = 90,
        sources = {
            { method = "quest", faction = "Horde", detail = "Quest: Dig Rat Stew" },
        },
        category = "No Buff",
        skillRange = { 90, 130, 150, 170 },
        reagents = { { itemID = 5051, count = 1, name = "Dig Rat" } },
    },
    ["Succulent Pork Ribs"] = {
        spellID = 2548,
        itemID = 2685,
        skillReq = 110,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "drop", faction = "Both" },
        },
        category = "No Buff",
        skillRange = { 110, 130, 150, 170 },
        reagents = {
            { itemID = 2677, count = 2, name = "Boar Ribs" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Bristle Whisker Catfish"] = {
        spellID = 7755,
        itemID = 4593,
        skillReq = 100,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Catherine Leland, Derak Nightfall +5 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 100, 140, 160, 180 },
        reagents = { { itemID = 6308, count = 1, name = "Raw Bristle Whisker Catfish" } },
    },
    ["Rockscale Cod"] = {
        spellID = 7828,
        itemID = 4594,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Heldan Galesong, Kelsey Yance +4 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 190, 210, 230 },
        reagents = { { itemID = 6362, count = 1, name = "Raw Rockscale Cod" } },
    },
    ["Mithril Headed Trout"] = {
        spellID = 20916,
        itemID = 8364,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Heldan Galesong, Kelsey Yance +4 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = { { itemID = 8365, count = 1, name = "Raw Mithril Head Trout" } },
    },
    ["Cooked Glossy Mightfish"] = {
        spellID = 18239,
        itemID = 13927,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kelsey Yance" },
        },
        category = "Stamina",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 13754, count = 1, name = "Raw Glossy Mightfish" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Filet of Redgill"] = {
        spellID = 18241,
        itemID = 13930,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kelsey Yance" },
        },
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = { { itemID = 13758, count = 1, name = "Raw Redgill" } },
    },
    ["Spotted Yellowtail"] = {
        spellID = 18238,
        itemID = 6887,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gikkix" },
        },
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = { { itemID = 4603, count = 1, name = "Raw Spotted Yellowtail" } },
    },
    ["Undermine Clam Chowder"] = {
        spellID = 20626,
        itemID = 16766,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Jabbey" },
        },
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 7974, count = 2, name = "Zesty Clam Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
            { itemID = 1179, count = 1, name = "Ice Cold Milk" },
        },
    },
    ["Hot Smoked Bass"] = {
        spellID = 18242,
        itemID = 13929,
        skillReq = 240,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kelsey Yance" },
        },
        category = "Stamina / Spirit",
        skillRange = { 240, 265, 277, 290 },
        reagents = {
            { itemID = 13756, count = 1, name = "Raw Summer Bass" },
            { itemID = 2692, count = 2, name = "Hot Spices" },
        },
    },
    ["Baked Salmon"] = {
        spellID = 18247,
        itemID = 13935,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Sheendra Tallgrass, Vivianna" },
        },
        category = "Stamina / Spirit",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 13889, count = 1, name = "Raw Whitescale Salmon" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Lobster Stew"] = {
        spellID = 18245,
        itemID = 13933,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Sheendra Tallgrass, Vivianna" },
        },
        category = "Stamina / Spirit",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 13888, count = 1, name = "Darkclaw Lobster" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Mightfish Steak"] = {
        spellID = 18246,
        itemID = 13934,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Sheendra Tallgrass, Vivianna" },
        },
        category = "Stamina",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 13893, count = 1, name = "Large Raw Mightfish" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Runn Tum Tuber Surprise"] = {
        spellID = 22761,
        itemID = 18254,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Intellect",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 18255, count = 1, name = "Runn Tum Tuber" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Blackened Trout"] = {
        spellID = 33290,
        itemID = 27661,
        skillReq = 300,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Doba, Gambarinka" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27422, count = 1, name = "Barbed Gill Trout" } },
    },
    ["Feltail Delight"] = {
        spellID = 33291,
        itemID = 27662,
        skillReq = 300,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Doba, Zurai" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27425, count = 1, name = "Spotted Feltail" } },
    },
    ["Stewed Trout"] = {
        spellID = 42296,
        itemID = 33048,
        skillReq = 335,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 27422, count = 1, name = "Barbed Gill Trout" },
            { itemID = 2593, count = 1, name = "Flask of Stormwind Tawny" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Hot Buttered Trout"] = {
        spellID = 42305,
        itemID = 33053,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 375, 375, 380, 385 },
        reagents = {
            { itemID = 27516, count = 1, name = "Enormous Barbed Gill Trout" },
            { itemID = 3713, count = 2, name = "Soothing Spices" },
        },
    },

    -- ================================================================
    -- STRENGTH
    -- ================================================================
    ["Smoked Desert Dumplings"] = {
        spellID = 24801,
        itemID = 20452,
        skillReq = 285,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Strength",
        skillRange = { 285, 310, 322, 335 },
        reagents = {
            { itemID = 20424, count = 1, name = "Sandworm Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },

    -- ================================================================
    -- MP5 (Mana per 5 sec)
    -- ================================================================
    ["Smoked Sagefish"] = {
        spellID = 25704,
        itemID = 21072,
        skillReq = 80,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Micha Yance" },
        },
        category = "MP5",
        skillRange = { 80, 120, 140, 160 },
        reagents = {
            { itemID = 21071, count = 1, name = "Raw Sagefish" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Sagefish Delight"] = {
        spellID = 25954,
        itemID = 21217,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Micha Yance" },
        },
        category = "MP5",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 21153, count = 1, name = "Raw Greater Sagefish" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Nightfin Soup"] = {
        spellID = 18243,
        itemID = 13931,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gikkix" },
        },
        category = "MP5",
        skillRange = { 250, 275, 285, 295 },
        reagents = {
            { itemID = 13759, count = 1, name = "Raw Nightfin Snapper" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },

    -- ================================================================
    -- UTILITY
    -- ================================================================
    ["Poached Sunscale Salmon"] = {
        spellID = 18244,
        itemID = 13932,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gikkix" },
        },
        category = "Utility",
        skillRange = { 250, 275, 285, 295 },
        reagents = { { itemID = 13760, count = 1, name = "Raw Sunscale Salmon" } },
    },
    ["Captain Rumsey's Lager"] = {
        spellID = 45695,
        itemID = 34832,
        skillReq = 100,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Utility",
        skillRange = { 100, 100, 105, 110 },
        reagents = {
            { itemID = 2596, count = 1, name = "Skin of Dwarven Stout" },
            { itemID = 2594, count = 1, name = "Flagon of Dwarven Honeymead" },
        },
    },
    ["Thistle Tea"] = {
        spellID = 9513,
        itemID = 7676,
        skillReq = 60,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Smudge Thunderwood" },
            { method = "quest", faction = "Both", detail = "Quest: Klaven\'s Tower" },
        },
        category = "Utility",
        skillRange = { 60, 100, 120, 140 },
        reagents = {
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Savory Deviate Delight"] = {
        spellID = 8238,
        itemID = 6657,
        skillReq = 85,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Utility",
        skillRange = { 85, 125, 145, 165 },
        reagents = {
            { itemID = 6522, count = 1, name = "Deviate Fish" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Goldthorn Tea"] = {
        spellID = 13028,
        itemID = 10841,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Utility",
        skillRange = { 175, 175, 190, 205 },
        reagents = {
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Dragonbreath Chili"] = {
        spellID = 15906,
        itemID = 12217,
        skillReq = 200,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Helenia Olden, Ogg\'marr +1 more" },
        },
        category = "Utility",
        skillRange = { 200, 225, 237, 250 },
        reagents = {
            { itemID = 12037, count = 1, name = "Mystery Meat" },
            { itemID = 4402, count = 1, name = "Small Flame Sac" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Crispy Bat Wing"] = {
        spellID = 15935,
        itemID = 12224,
        skillReq = 1,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Abigail Shiel" },
        },
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = {
            { itemID = 12223, count = 1, name = "Meaty Bat Wing" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Gingerbread Cookie"] = {
        spellID = 21143,
        itemID = 17197,
        skillReq = 1,
        sources = {
            { method = "vendor", faction = "Both", detail = "Winter Veil (seasonal)" },
        },
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = {
            { itemID = 6889, count = 1, name = "Small Egg" },
            { itemID = 17194, count = 1, name = "Holiday Spices" },
        },
    },
    ["Herb Baked Egg"] = {
        spellID = 8604,
        itemID = 6888,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both", detail = "default recipe (Alliance confirmed; Horde pending m4ru in-game check)" },
        },
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = {
            { itemID = 6889, count = 1, name = "Small Egg" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Lynx Steak"] = {
        spellID = 33276,
        itemID = 27635,
        skillReq = 1,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Landraelanis" },
        },
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 27668, count = 1, name = "Lynx Meat" } },
    },
    ["Roasted Moongraze Tenderloin"] = {
        spellID = 33277,
        itemID = 24105,
        skillReq = 1,
        sources = {
            { method = "quest", faction = "Alliance", detail = "Quest: The Great Moongraze Hunt" },
        },
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 23676, count = 1, name = "Moongraze Stag Tenderloin" } },
    },
    ["Delicious Chocolate Cake"] = {
        spellID = 43779,
        itemID = 33924,
        skillReq = 1,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 1, 50, 62, 75 },
        reagents = {
            { itemID = 30817, count = 8, name = "Simple Flour" },
            { itemID = 1179, count = 4, name = "Ice Cold Milk" },
            { itemID = 2678, count = 4, name = "Mild Spices" },
            { itemID = 6889, count = 8, name = "Small Egg" },
            { itemID = 2593, count = 1, name = "Flask of Stormwind Tawny" },
            { itemID = 785, count = 3, name = "Mageroyal" },
        },
    },
    ["Kaldorei Spider Kabob"] = {
        spellID = 6412,
        itemID = 5472,
        skillReq = 10,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Recipe of the Kaldorei" },
        },
        category = "Stamina / Spirit",
        skillRange = { 10, 50, 70, 90 },
        reagents = { { itemID = 5465, count = 1, name = "Small Spider Leg" } },
    },
    ["Spiced Wolf Meat"] = {
        spellID = 2539,
        itemID = 2680,
        skillReq = 10,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 10, 50, 70, 90 },
        reagents = {
            { itemID = 2672, count = 1, name = "Stringy Wolf Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Beer Basted Boar Ribs"] = {
        spellID = 2795,
        itemID = 2888,
        skillReq = 25,
        sources = {
            { method = "trainer", faction = "Alliance" },
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Beer Basted Boar Ribs" },
        },
        category = "Stamina / Spirit",
        skillRange = { 25, 60, 80, 100 },
        reagents = {
            { itemID = 2886, count = 1, name = "Crag Boar Rib" },
            { itemID = 2894, count = 1, name = "Rhapsody Malt" },
        },
    },
    ["Egg Nog"] = {
        spellID = 21144,
        itemID = 17198,
        skillReq = 35,
        sources = {
            { method = "vendor", faction = "Both", detail = "Winter Veil (seasonal)" },
        },
        category = "Stamina / Spirit",
        skillRange = { 35, 75, 95, 115 },
        reagents = {
            { itemID = 6889, count = 1, name = "Small Egg" },
            { itemID = 1179, count = 1, name = "Ice Cold Milk" },
            { itemID = 17196, count = 1, name = "Holiday Spirits" },
            { itemID = 17194, count = 1, name = "Holiday Spices" },
        },
    },
    ["Roasted Kodo Meat"] = {
        spellID = 6414,
        itemID = 5474,
        skillReq = 35,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Wunna Darkmane" },
        },
        category = "Stamina / Spirit",
        skillRange = { 35, 75, 95, 115 },
        reagents = {
            { itemID = 5467, count = 1, name = "Kodo Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Bat Bites"] = {
        spellID = 33278,
        itemID = 27636,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Master Chef Mouldier" },
        },
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 27669, count = 1, name = "Bat Flesh" } },
    },
    ["Boiled Clams"] = {
        spellID = 6499,
        itemID = 5525,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 5503, count = 1, name = "Clam Meat" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Coyote Steak"] = {
        spellID = 2541,
        itemID = 2684,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 2673, count = 1, name = "Coyote Meat" } },
    },
    ["Fillet of Frenzy"] = {
        spellID = 6415,
        itemID = 5476,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Laird" },
        },
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 5468, count = 1, name = "Soft Frenzy Flesh" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Goretusk Liver Pie"] = {
        spellID = 2542,
        itemID = 724,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Goretusk Liver Pie" },
        },
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 723, count = 1, name = "Goretusk Liver" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Strider Stew"] = {
        spellID = 6416,
        itemID = 5477,
        skillReq = 50,
        sources = {
            { method = "vendor", faction = "Horde", detail = "Sold by Tari\'qa" },
            { method = "quest", faction = "Alliance", detail = "Quest: Easy Strider Living" },
        },
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 5469, count = 1, name = "Strider Meat" },
            { itemID = 4536, count = 1, name = "Shiny Red Apple" },
        },
    },
    ["Blood Sausage"] = {
        spellID = 3371,
        itemID = 3220,
        skillReq = 60,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Thelsamar Blood Sausages" },
        },
        category = "Stamina / Spirit",
        skillRange = { 60, 100, 120, 140 },
        reagents = {
            { itemID = 3173, count = 1, name = "Bear Meat" },
            { itemID = 3172, count = 1, name = "Boar Intestines" },
            { itemID = 3174, count = 1, name = "Spider Ichor" },
        },
    },
    ["Crunchy Spider Surprise"] = {
        spellID = 28267,
        itemID = 22645,
        skillReq = 60,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Fazu, Master Chef Mouldier" },
            { method = "quest", faction = "Horde", detail = "Quest: Culinary Crunch" },
        },
        category = "Stamina / Spirit",
        skillRange = { 60, 100, 120, 140 },
        reagents = { { itemID = 22644, count = 1, name = "Crunchy Spider Leg" } },
    },
    ["Crab Cake"] = {
        spellID = 2544,
        itemID = 2683,
        skillReq = 75,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 75, 115, 135, 155 },
        reagents = {
            { itemID = 2674, count = 1, name = "Crawler Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Crocolisk Steak"] = {
        spellID = 3370,
        itemID = 3662,
        skillReq = 80,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Crocolisk Hunting" },
        },
        category = "Stamina / Spirit",
        skillRange = { 80, 120, 140, 160 },
        reagents = {
            { itemID = 2924, count = 1, name = "Crocolisk Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Dry Pork Ribs"] = {
        spellID = 2546,
        itemID = 2687,
        skillReq = 80,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 80, 120, 140, 160 },
        reagents = {
            { itemID = 2677, count = 1, name = "Boar Ribs" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Murloc Fin Soup"] = {
        spellID = 3372,
        itemID = 3663,
        skillReq = 90,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Selling Fish" },
        },
        category = "Stamina / Spirit",
        skillRange = { 90, 130, 150, 170 },
        reagents = {
            { itemID = 1468, count = 2, name = "Murloc Fin" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Redridge Goulash"] = {
        spellID = 2547,
        itemID = 1082,
        skillReq = 100,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Redridge Goulash" },
        },
        category = "Stamina / Spirit",
        skillRange = { 100, 135, 155, 175 },
        reagents = {
            { itemID = 1081, count = 1, name = "Crisp Spider Meat" },
            { itemID = 1080, count = 1, name = "Tough Condor Meat" },
        },
    },
    ["Crispy Lizard Tail"] = {
        spellID = 6418,
        itemID = 5479,
        skillReq = 100,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Tari\'qa" },
        },
        category = "Stamina / Spirit",
        skillRange = { 100, 140, 160, 180 },
        reagents = {
            { itemID = 5470, count = 1, name = "Thunder Lizard Tail" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Seasoned Wolf Kabob"] = {
        spellID = 2549,
        itemID = 1017,
        skillReq = 100,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Seasoned Wolf Kabobs" },
        },
        category = "Stamina / Spirit",
        skillRange = { 100, 140, 160, 180 },
        reagents = {
            { itemID = 1015, count = 2, name = "Lean Wolf Flank" },
            { itemID = 2665, count = 1, name = "Stormwind Seasoning Herbs" },
        },
    },
    ["Big Bear Steak"] = {
        spellID = 3397,
        itemID = 3726,
        skillReq = 110,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Super-Seller 680, Ulthaan" },
            { method = "quest", faction = "Horde", detail = "Quest: The Rescue" },
        },
        category = "Stamina / Spirit",
        skillRange = { 110, 150, 170, 190 },
        reagents = {
            { itemID = 3730, count = 1, name = "Big Bear Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Gooey Spider Cake"] = {
        spellID = 3377,
        itemID = 3666,
        skillReq = 110,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Dusky Crab Cakes" },
        },
        category = "Stamina / Spirit",
        skillRange = { 110, 150, 170, 190 },
        reagents = {
            { itemID = 2251, count = 2, name = "Gooey Spider Leg" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Lean Venison"] = {
        spellID = 6419,
        itemID = 5480,
        skillReq = 110,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Ulthaan, Vendor-Tron 1000" },
        },
        category = "Stamina / Spirit",
        skillRange = { 110, 150, 170, 190 },
        reagents = {
            { itemID = 5471, count = 1, name = "Stag Meat" },
            { itemID = 2678, count = 4, name = "Mild Spices" },
        },
    },
    ["Crocolisk Gumbo"] = {
        spellID = 3373,
        itemID = 3664,
        skillReq = 120,
        sources = {
            { method = "vendor", faction = "Alliance", detail = "Sold by Kendor Kabonka" },
            { method = "quest", faction = "Alliance", detail = "Quest: Apprentice\'s Duties" },
        },
        category = "Stamina / Spirit",
        skillRange = { 120, 160, 180, 200 },
        reagents = {
            { itemID = 3667, count = 1, name = "Tender Crocolisk Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Heavy Crocolisk Stew"] = {
        spellID = 24418,
        itemID = 20074,
        skillReq = 150,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Ogg\'marr" },
        },
        category = "Stamina / Spirit",
        skillRange = { 150, 160, 180, 200 },
        reagents = {
            { itemID = 3667, count = 2, name = "Tender Crocolisk Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Goblin Deviled Clams"] = {
        spellID = 6500,
        itemID = 5527,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 125, 165, 185, 205 },
        reagents = {
            { itemID = 5504, count = 1, name = "Tangy Clam Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Lean Wolf Steak"] = {
        spellID = 15853,
        itemID = 12209,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Both", detail = "Sold by Super-Seller 680" },
        },
        category = "Stamina / Spirit",
        skillRange = { 125, 165, 185, 205 },
        reagents = {
            { itemID = 1015, count = 1, name = "Lean Wolf Flank" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Curiously Tasty Omelet"] = {
        spellID = 3376,
        itemID = 3665,
        skillReq = 130,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Keena, Kendor Kabonka +1 more" },
            { method = "quest", faction = "Alliance", detail = "Quest: Ormer\'s Revenge" },
        },
        category = "Stamina / Spirit",
        skillRange = { 130, 170, 190, 210 },
        reagents = {
            { itemID = 3685, count = 1, name = "Raptor Egg" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Hot Lion Chops"] = {
        spellID = 3398,
        itemID = 3727,
        skillReq = 125,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Vendor-Tron 1000, Zargh" },
            { method = "quest", faction = "Horde", detail = "Quest: Elixir of Pain" },
        },
        category = "Stamina / Spirit",
        skillRange = { 125, 175, 195, 215 },
        reagents = {
            { itemID = 3731, count = 1, name = "Lion Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Tasty Lion Steak"] = {
        spellID = 3399,
        itemID = 3728,
        skillReq = 150,
        sources = {
            { method = "quest", faction = "Alliance", detail = "Quest: Costly Menace" },
        },
        category = "Stamina / Spirit",
        skillRange = { 150, 190, 210, 230 },
        reagents = {
            { itemID = 3731, count = 2, name = "Lion Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Barbecued Buzzard Wing"] = {
        spellID = 4094,
        itemID = 4457,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Horde" },
            { method = "vendor", faction = "Both", detail = "Sold by Narj Deepslice, Super-Seller 680" },
            { method = "quest", faction = "Both", detail = "Quest: Barbecued Buzzard Wings" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 3404, count = 1, name = "Buzzard Wing" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Carrion Surprise"] = {
        spellID = 15863,
        itemID = 12213,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Banalash, Kireena +2 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12037, count = 1, name = "Mystery Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Giant Clam Scorcho"] = {
        spellID = 7213,
        itemID = 6038,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kelsey Yance" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 4655, count = 1, name = "Giant Clam Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Hot Wolf Ribs"] = {
        spellID = 15856,
        itemID = 13851,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Both", detail = "Sold by Sheendra Tallgrass, Super-Seller 680 +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12203, count = 1, name = "Red Wolf Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Jungle Stew"] = {
        spellID = 15861,
        itemID = 12212,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Corporal Bluth, Nerrist +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12202, count = 1, name = "Tiger Meat" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
            { itemID = 4536, count = 2, name = "Shiny Red Apple" },
        },
    },
    ["Mystery Stew"] = {
        spellID = 15865,
        itemID = 12214,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Helenia Olden, Janet Hommers +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12037, count = 1, name = "Mystery Meat" },
            { itemID = 2596, count = 1, name = "Skin of Dwarven Stout" },
        },
    },
    ["Roast Raptor"] = {
        spellID = 15855,
        itemID = 12210,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Corporal Bluth, Hammon Karwn +5 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12184, count = 1, name = "Raptor Flesh" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Soothing Turtle Bisque"] = {
        spellID = 3400,
        itemID = 3729,
        skillReq = 175,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Soothing Turtle Bisque" },
        },
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 3712, count = 1, name = "Turtle Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Heavy Kodo Stew"] = {
        spellID = 15910,
        itemID = 12215,
        skillReq = 200,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Janet Hommers, Kireena +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 200, 225, 237, 250 },
        reagents = {
            { itemID = 12204, count = 2, name = "Heavy Kodo Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Spider Sausage"] = {
        spellID = 21175,
        itemID = 17222,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 200, 225, 237, 250 },
        reagents = { { itemID = 12205, count = 2, name = "White Spider Meat" } },
    },
    ["Monster Omelet"] = {
        spellID = 15933,
        itemID = 12218,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Bale, Himmik +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 12207, count = 1, name = "Giant Egg" },
            { itemID = 3713, count = 2, name = "Soothing Spices" },
        },
    },
    ["Spiced Chili Crab"] = {
        spellID = 15915,
        itemID = 12216,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Banalash, Kriggon Talsone +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 12206, count = 1, name = "Tender Crab Meat" },
            { itemID = 2692, count = 2, name = "Hot Spices" },
        },
    },
    ["Tender Wolf Steak"] = {
        spellID = 22480,
        itemID = 18045,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Both", detail = "Sold by Dirge Quikcleave, Innkeeper Fizzgrimble +1 more" },
        },
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 12208, count = 1, name = "Tender Wolf Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },

    -- ================================================================
    -- AGILITY / SPIRIT
    -- ================================================================
    ["Grilled Squid"] = {
        spellID = 18240,
        itemID = 13928,
        skillReq = 240,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gikkix" },
        },
        category = "Agility / Spirit",
        skillRange = { 240, 265, 277, 290 },
        reagents = {
            { itemID = 13755, count = 1, name = "Winter Squid" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },

    -- ================================================================
    -- ATTACK POWER / SPIRIT
    -- ================================================================
    ["Charred Bear Kabobs"] = {
        spellID = 46684,
        itemID = 35563,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Bale, Malygen" },
        },
        category = "Attack Power / Spirit",
        skillRange = { 250, 275, 285, 295 },
        reagents = { { itemID = 35562, count = 1, name = "Bear Flank" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Juicy Bear Burger"] = {
        spellID = 46688,
        itemID = 35565,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Bale, Malygen" },
        },
        category = "Spell Damage / Spirit",
        skillRange = { 250, 275, 285, 295 },
        reagents = { { itemID = 35562, count = 1, name = "Bear Flank" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Broiled Bloodfin"] = {
        spellID = 43761,
        itemID = 33867,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 33823, count = 1, name = "Bloodfin Catfish" } },
    },
    ["Buzzard Bites"] = {
        spellID = 33279,
        itemID = 27651,
        skillReq = 300,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Smooth as Butter" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27671, count = 1, name = "Buzzard Meat" } },
    },
    ["Clam Bar"] = {
        spellID = 36210,
        itemID = 30155,
        skillReq = 300,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Mycah" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 24477, count = 2, name = "Jaggal Clam Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },

    -- ================================================================
    -- ATTACK POWER / SPIRIT
    -- ================================================================
    ["Ravager Dog"] = {
        spellID = 33284,
        itemID = 27655,
        skillReq = 300,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Cookie One-Eye, Sid Limbardi" },
        },
        category = "Attack Power / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27674, count = 1, name = "Ravager Flesh" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Stormchops"] = {
        spellID = 43758,
        itemID = 33866,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 27678, count = 1, name = "Clefthoof Meat" },
            { itemID = 13757, count = 1, name = "Lightning Eel" },
        },
    },
    ["Dirge's Kickin' Chimaerok Chops"] = {
        spellID = 25659,
        itemID = 21023,
        skillReq = 300,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Dirge\'s Kickin\' Chimaerok Chops" },
        },
        category = "Stamina / Spirit",
        skillRange = { 300, 325, 337, 350 },
        reagents = {
            { itemID = 2692, count = 1, name = "Hot Spices" },
            { itemID = 9061, count = 1, name = "Goblin Rocket Fuel" },
            { itemID = 8150, count = 1, name = "Deeprock Salt" },
            { itemID = 21024, count = 1, name = "Chimaerok Tenderloin" },
        },
    },
    ["Hot Apple Cider"] = {
        spellID = 45022,
        itemID = 34411,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Penney Copperpinch, Wulmort Jinglepocket" },
        },
        category = "Stamina / Spirit",
        skillRange = { 325, 325, 325, 325 },
        reagents = {
            { itemID = 34412, count = 1, name = "Sparkling Apple Cider" },
            { itemID = 17196, count = 1, name = "Holiday Spirits" },
            { itemID = 17194, count = 1, name = "Holiday Spices" },
        },
    },
    ["Blackened Sporefish"] = {
        spellID = 33292,
        itemID = 27663,
        skillReq = 310,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Juno Dufrain" },
        },
        category = "Stamina / Spirit",
        skillRange = { 310, 330, 340, 350 },
        reagents = { { itemID = 27429, count = 1, name = "Zangarian Sporefish" } },
    },
    ["Sporeling Snack"] = {
        spellID = 33285,
        itemID = 27656,
        skillReq = 310,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Mycah" },
        },
        category = "Stamina / Spirit",
        skillRange = { 310, 330, 340, 350 },
        reagents = { { itemID = 27676, count = 1, name = "Strange Spores" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Blackened Basilisk"] = {
        spellID = 33286,
        itemID = 27657,
        skillReq = 315,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Innkeeper Grilka, Supply Officer Mills" },
        },
        category = "Spell Damage / Spirit",
        skillRange = { 315, 335, 345, 355 },
        reagents = { { itemID = 27677, count = 1, name = "Chunk o' Basilisk" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Skullfish Soup"] = {
        spellID = 43707,
        itemID = 33825,
        skillReq = 325,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 325, 335, 345, 355 },
        reagents = { { itemID = 33824, count = 1, name = "Crescent-Tail Skullfish" } },
    },
    ["Spicy Hot Talbuk"] = {
        spellID = 43765,
        itemID = 33872,
        skillReq = 325,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 325, 335, 345, 355 },
        reagents = {
            { itemID = 27682, count = 1, name = "Talbuk Venison" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },

    -- ================================================================
    -- AGILITY / SPIRIT
    -- ================================================================
    ["Grilled Mudfish"] = {
        spellID = 33293,
        itemID = 27664,
        skillReq = 320,
        sources = {
            { method = "vendor", faction = "Both", detail = "Cooking supplies" },
        },
        category = "Agility / Spirit",
        skillRange = { 320, 340, 350, 360 },
        reagents = { { itemID = 27435, count = 1, name = "Figluster's Mudfish" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Poached Bluefish"] = {
        spellID = 33294,
        itemID = 27665,
        skillReq = 320,
        sources = {
            { method = "vendor", faction = "Both", detail = "Cooking supplies" },
        },
        category = "Spell Damage / Spirit",
        skillRange = { 320, 340, 350, 360 },
        reagents = { { itemID = 27437, count = 1, name = "Icefin Bluefish" } },
    },

    -- ================================================================
    -- HEALING / SPIRIT
    -- ================================================================
    ["Golden Fish Sticks"] = {
        spellID = 33295,
        itemID = 27666,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Innkeeper Biribi, Rungor" },
        },
        category = "Healing / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27438, count = 1, name = "Golden Darter" } },
    },

    -- ================================================================
    -- STRENGTH / SPIRIT
    -- ================================================================
    ["Kibler's Bits"] = {
        spellID = 43772,
        itemID = 33874,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Strength / Spirit",
        skillRange = { 300, 345, 355, 365 },
        reagents = { { itemID = 27671, count = 1, name = "Buzzard Meat" } },
    },
    ["Roasted Clefthoof"] = {
        spellID = 33287,
        itemID = 27658,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Cooking supplies" },
        },
        category = "Strength / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27678, count = 1, name = "Clefthoof Meat" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Talbuk Steak"] = {
        spellID = 33289,
        itemID = 27660,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Cooking supplies" },
        },
        category = "Stamina / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27682, count = 1, name = "Talbuk Venison" } },
    },

    -- ================================================================
    -- AGILITY / SPIRIT
    -- ================================================================
    ["Warp Burger"] = {
        spellID = 33288,
        itemID = 27659,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Innkeeper Grilka, Supply Officer Mills" },
        },
        category = "Agility / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27681, count = 1, name = "Warped Flesh" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Crunchy Serpent"] = {
        spellID = 38868,
        itemID = 31673,
        skillReq = 335,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Sassa Weldwell, Xerintha Ravenoak" },
            { method = "quest", faction = "Horde", detail = "Quest: Mok\'Nathal Treats" },
        },
        category = "Spell Damage / Spirit",
        skillRange = { 335, 355, 365, 375 },
        reagents = { { itemID = 31671, count = 1, name = "Serpent Flesh" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Mok'Nathal Shortribs"] = {
        spellID = 38867,
        itemID = 31672,
        skillReq = 335,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Sassa Weldwell, Xerintha Ravenoak" },
            { method = "quest", faction = "Horde", detail = "Quest: Mok\'Nathal Treats" },
        },
        category = "Stamina / Spirit",
        skillRange = { 335, 355, 365, 375 },
        reagents = { { itemID = 31670, count = 1, name = "Raptor Ribs" } },
    },
    ["Spicy Crawdad"] = {
        spellID = 33296,
        itemID = 27667,
        skillReq = 350,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Innkeeper Biribi, Rungor" },
        },
        category = "Stamina / Spirit",
        skillRange = { 350, 370, 380, 390 },
        reagents = { { itemID = 27439, count = 1, name = "Furious Crawdad" } },
    },
    ["Fisherman's Feast"] = {
        spellID = 42302,
        itemID = 33052,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Stamina / Spirit",
        skillRange = { 375, 375, 380, 385 },
        reagents = {
            { itemID = 27515, count = 1, name = "Huge Spotted Feltail" },
            { itemID = 4539, count = 5, name = "Goldenbark Apple" },
            { itemID = 3713, count = 5, name = "Soothing Spices" },
        },
    },

}

RDB:RegisterProfession("Cooking", recipes)
