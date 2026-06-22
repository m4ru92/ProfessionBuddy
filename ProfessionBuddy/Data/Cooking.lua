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
        itemID = 30816,
        skillReq = 1,
        source = "trainer",
        category = "No Buff",
        skillRange = { 1, 30, 35, 40 },
        reagents = {
            { itemID = 30817, count = 1, name = "Simple Flour" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Brilliant Smallfish"] = {
        itemID = 6290,
        skillReq = 1,
        source = "vendor",
        sourceDetail = "Tharynn Bouden (A, Elwynn Forest) / Harn Longcast (H, Mulgore)",
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 6291, count = 1, name = "Raw Brilliant Smallfish" } },
    },
    ["Charred Wolf Meat"] = {
        itemID = 2679,
        skillReq = 1,
        source = "trainer",
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 2672, count = 1, name = "Stringy Wolf Meat" } },
    },
    ["Roasted Boar Meat"] = {
        itemID = 2681,
        skillReq = 1,
        source = "trainer",
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 769, count = 1, name = "Chunk of Boar Meat" } },
    },
    ["Slitherskin Mackerel"] = {
        itemID = 787,
        skillReq = 1,
        source = "trainer",
        category = "No Buff",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 6303, count = 1, name = "Raw Slitherskin Mackerel" } },
    },
    ["Scorpid Surprise"] = {
        itemID = 5473,
        skillReq = 20,
        source = "vendor",
        sourceDetail = "Grimtak, Durotar",
        category = "No Buff",
        skillRange = { 20, 60, 80, 100 },
        reagents = { { itemID = 5466, count = 1, name = "Scorpid Stinger" } },
    },
    ["Smoked Bear Meat"] = {
        itemID = 6890,
        skillReq = 40,
        source = "vendor",
        sourceDetail = "Andrew Hilbert (H, Silverpine Forest) / Drac Roughcut (A, Loch Modan)",
        category = "No Buff",
        skillRange = { 40, 80, 100, 120 },
        reagents = { { itemID = 3173, count = 1, name = "Bear Meat" } },
    },
    ["Loch Frenzy Delight"] = {
        itemID = 6316,
        skillReq = 50,
        source = "vendor",
        sourceDetail = "Khara Deepwater, Loch Modan",
        category = "No Buff",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 6317, count = 1, name = "Raw Loch Frenzy" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Longjaw Mud Snapper"] = {
        itemID = 4592,
        skillReq = 50,
        source = "vendor",
        sourceDetail = "Tharynn Bouden (A, Elwynn Forest) / Naal Mistrunner (H, Mulgore)",
        category = "No Buff",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 6289, count = 1, name = "Raw Longjaw Mud Snapper" } },
    },
    ["Rainbow Fin Albacore"] = {
        itemID = 5095,
        skillReq = 50,
        source = "vendor",
        sourceDetail = "Catherine Leland (A, Stormwind) / Shankys (H, Durotar)",
        category = "No Buff",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 6361, count = 1, name = "Raw Rainbow Fin Albacore" } },
    },
    ["Westfall Stew"] = {
        itemID = 733,
        skillReq = 75,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "No Buff",
        skillRange = { 75, 115, 135, 155 },
        reagents = {
            { itemID = 729, count = 1, name = "Stringy Vulture Meat" },
            { itemID = 730, count = 1, name = "Murloc Eye" },
            { itemID = 731, count = 1, name = "Goretusk Snout" },
        },
    },
    ["Cooked Crab Claw"] = {
        itemID = 2682,
        skillReq = 85,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "No Buff",
        skillRange = { 85, 125, 145, 165 },
        reagents = {
            { itemID = 2675, count = 1, name = "Crawler Claw" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Clam Chowder"] = {
        itemID = 5526,
        skillReq = 90,
        source = "vendor",
        sourceDetail = "Kriggon Talsone, Westfall",
        category = "No Buff",
        skillRange = { 90, 130, 150, 170 },
        reagents = {
            { itemID = 5503, count = 1, name = "Clam Meat" },
            { itemID = 1179, count = 1, name = "Ice Cold Milk" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Dig Rat Stew"] = {
        itemID = 5478,
        skillReq = 90,
        source = "trainer",
        category = "No Buff",
        skillRange = { 90, 130, 150, 170 },
        reagents = { { itemID = 5051, count = 1, name = "Dig Rat" } },
    },
    ["Succulent Pork Ribs"] = {
        itemID = 2685,
        skillReq = 110,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "No Buff",
        skillRange = { 110, 130, 150, 170 },
        reagents = {
            { itemID = 2677, count = 2, name = "Boar Ribs" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Bristle Whisker Catfish"] = {
        itemID = 4593,
        skillReq = 100,
        source = "vendor",
        sourceDetail = "Catherine Leland (A, Stormwind) / Naal Mistrunner (H, Thunder Bluff)",
        category = "Stamina / Spirit",
        skillRange = { 100, 140, 160, 180 },
        reagents = { { itemID = 6308, count = 1, name = "Raw Bristle Whisker Catfish" } },
    },
    ["Rockscale Cod"] = {
        itemID = 4594,
        skillReq = 175,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 175, 190, 210, 230 },
        reagents = { { itemID = 6362, count = 1, name = "Raw Rockscale Cod" } },
    },
    ["Mithril Headed Trout"] = {
        itemID = 8364,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Kelsey Yance (Booty Bay) / Lindea Rabonne (Hillsbrad Foothills)",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = { { itemID = 8365, count = 1, name = "Raw Mithril Head Trout" } },
    },
    ["Cooked Glossy Mightfish"] = {
        itemID = 13927,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Kelsey Yance, Booty Bay",
        category = "Stamina",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 13754, count = 1, name = "Raw Glossy Mightfish" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Filet of Redgill"] = {
        itemID = 13930,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Kelsey Yance, Booty Bay",
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = { { itemID = 13758, count = 1, name = "Raw Redgill" } },
    },
    ["Spotted Yellowtail"] = {
        itemID = 6887,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Gikkix, Tanaris",
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = { { itemID = 4603, count = 1, name = "Raw Spotted Yellowtail" } },
    },
    ["Undermine Clam Chowder"] = {
        itemID = 16766,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Jabbey, Tanaris",
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 7974, count = 2, name = "Zesty Clam Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
            { itemID = 1179, count = 1, name = "Ice Cold Milk" },
        },
    },
    ["Hot Smoked Bass"] = {
        itemID = 13929,
        skillReq = 240,
        source = "vendor",
        sourceDetail = "Kelsey Yance, Booty Bay",
        category = "Stamina / Spirit",
        skillRange = { 240, 265, 277, 290 },
        reagents = {
            { itemID = 13756, count = 1, name = "Raw Summer Bass" },
            { itemID = 2692, count = 2, name = "Hot Spices" },
        },
    },
    ["Baked Salmon"] = {
        itemID = 13935,
        skillReq = 275,
        source = "vendor",
        sourceDetail = "Vivianna (A) / Sheendra Tallgrass (H), Feralas",
        category = "Stamina / Spirit",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 13889, count = 1, name = "Raw Whitescale Salmon" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Lobster Stew"] = {
        itemID = 13933,
        skillReq = 275,
        source = "vendor",
        sourceDetail = "Vivianna (A) / Sheendra Tallgrass (H), Feralas",
        category = "Stamina / Spirit",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 13888, count = 1, name = "Darkclaw Lobster" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Mightfish Steak"] = {
        itemID = 13934,
        skillReq = 275,
        source = "vendor",
        sourceDetail = "Vivianna (A) / Sheendra Tallgrass (H), Feralas",
        category = "Stamina",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 13893, count = 1, name = "Large Raw Mightfish" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Runn Tum Tuber Surprise"] = {
        itemID = 18254,
        skillReq = 275,
        source = "drop",
        category = "Intellect",
        skillRange = { 275, 300, 312, 325 },
        reagents = {
            { itemID = 18255, count = 1, name = "Runn Tum Tuber" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Blackened Trout"] = {
        itemID = 27661,
        skillReq = 300,
        source = "vendor",
        sourceDetail = "Gambarinka (H) / Doba (A), Zangarmarsh",
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27422, count = 1, name = "Barbed Gill Trout" } },
    },
    ["Feltail Delight"] = {
        itemID = 27662,
        skillReq = 300,
        source = "vendor",
        sourceDetail = "Zurai (H) / Doba (A), Zangarmarsh",
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27425, count = 1, name = "Spotted Feltail" } },
    },
    ["Stewed Trout"] = {
        itemID = 33048,
        skillReq = 335,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 27422, count = 1, name = "Barbed Gill Trout" },
            { itemID = 2593, count = 1, name = "Flask of Stormwind Tawny" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Hot Buttered Trout"] = {
        itemID = 33053,
        skillReq = 375,
        source = "trainer",
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
        itemID = 20452,
        skillReq = 285,
        source = "quest",
        sourceDetail = "Sharing the Knowledge, Silithus",
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
        itemID = 21072,
        skillReq = 80,
        source = "vendor",
        sourceDetail = "Erika Tate (A, Stormwind) / Xen'to (H, Orgrimmar)",
        category = "MP5",
        skillRange = { 80, 120, 140, 160 },
        reagents = {
            { itemID = 21071, count = 1, name = "Raw Sagefish" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Sagefish Delight"] = {
        itemID = 21217,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Kelsey Yance (Booty Bay) / Xen'to (H, Orgrimmar)",
        category = "MP5",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 21153, count = 1, name = "Raw Greater Sagefish" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Nightfin Soup"] = {
        itemID = 13931,
        skillReq = 250,
        source = "vendor",
        sourceDetail = "Gikkix, Tanaris",
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
        itemID = 13932,
        skillReq = 250,
        source = "vendor",
        sourceDetail = "Gikkix, Tanaris",
        category = "Utility",
        skillRange = { 250, 275, 285, 295 },
        reagents = { { itemID = 13760, count = 1, name = "Raw Sunscale Salmon" } },
    },
    ["Captain Rumsey's Lager"] = {
        itemID = 34832,
        skillReq = 100,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
        category = "Utility",
        skillRange = { 100, 100, 105, 110 },
        reagents = {
            { itemID = 2596, count = 1, name = "Skin of Dwarven Stout" },
            { itemID = 2594, count = 1, name = "Flagon of Dwarven Honeymead" },
        },
    },
    ["Thistle Tea"] = {
        itemID = 7676,
        skillReq = 60,
        source = "drop",
        category = "Utility",
        skillRange = { 60, 100, 120, 140 },
        reagents = {
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Savory Deviate Delight"] = {
        itemID = 6657,
        skillReq = 85,
        source = "drop",
        category = "Utility",
        skillRange = { 85, 125, 145, 165 },
        reagents = {
            { itemID = 6522, count = 1, name = "Deviate Fish" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Goldthorn Tea"] = {
        itemID = 10841,
        skillReq = 175,
        source = "drop",
        category = "Utility",
        skillRange = { 175, 175, 190, 205 },
        reagents = {
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Dragonbreath Chili"] = {
        itemID = 12217,
        skillReq = 200,
        source = "vendor",
        sourceDetail = "Helenia Olden (A) / Ogg'marr (H), Dustwallow Marsh",
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
        itemID = 12224,
        skillReq = 1,
        source = "vendor",
        sourceDetail = "Abigail Shiel, Tirisfal Glades",
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = {
            { itemID = 12223, count = 1, name = "Meaty Bat Wing" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Gingerbread Cookie"] = {
        itemID = 17197,
        skillReq = 1,
        source = "vendor",
        sourceDetail = "Smokywood Pastures Vendor, seasonal (Winter Veil)",
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = {
            { itemID = 6889, count = 1, name = "Small Egg" },
            { itemID = 17194, count = 1, name = "Holiday Spices" },
        },
    },
    ["Herb Baked Egg"] = {
        itemID = 6888,
        skillReq = 1,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = {
            { itemID = 6889, count = 1, name = "Small Egg" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Lynx Steak"] = {
        itemID = 27635,
        skillReq = 1,
        source = "vendor",
        sourceDetail = "Landraelanis, Eversong Woods",
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 27668, count = 1, name = "Lynx Meat" } },
    },
    ["Roasted Moongraze Tenderloin"] = {
        itemID = 24105,
        skillReq = 1,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 1, 45, 65, 85 },
        reagents = { { itemID = 23676, count = 1, name = "Moongraze Stag Tenderloin" } },
    },
    ["Delicious Chocolate Cake"] = {
        itemID = 33924,
        skillReq = 1,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
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
        itemID = 5472,
        skillReq = 10,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 10, 50, 70, 90 },
        reagents = { { itemID = 5465, count = 1, name = "Small Spider Leg" } },
    },
    ["Spiced Wolf Meat"] = {
        itemID = 2680,
        skillReq = 10,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 10, 50, 70, 90 },
        reagents = {
            { itemID = 2672, count = 1, name = "Stringy Wolf Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Beer Basted Boar Ribs"] = {
        itemID = 2888,
        skillReq = 25,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 25, 60, 80, 100 },
        reagents = {
            { itemID = 2886, count = 1, name = "Crag Boar Rib" },
            { itemID = 2894, count = 1, name = "Rhapsody Malt" },
        },
    },
    ["Egg Nog"] = {
        itemID = 17198,
        skillReq = 35,
        source = "vendor",
        sourceDetail = "Smokywood Pastures Vendor, seasonal (Winter Veil)",
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
        itemID = 5474,
        skillReq = 35,
        source = "vendor",
        sourceDetail = "Wunna Darkmane, Mulgore",
        category = "Stamina / Spirit",
        skillRange = { 35, 75, 95, 115 },
        reagents = {
            { itemID = 5467, count = 1, name = "Kodo Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Bat Bites"] = {
        itemID = 27636,
        skillReq = 50,
        source = "vendor",
        sourceDetail = "Master Chef Mouldier, Ghostlands",
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 27669, count = 1, name = "Bat Flesh" } },
    },
    ["Boiled Clams"] = {
        itemID = 5525,
        skillReq = 50,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 5503, count = 1, name = "Clam Meat" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Coyote Steak"] = {
        itemID = 2684,
        skillReq = 50,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = { { itemID = 2673, count = 1, name = "Coyote Meat" } },
    },
    ["Fillet of Frenzy"] = {
        itemID = 5476,
        skillReq = 50,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 5468, count = 1, name = "Soft Frenzy Flesh" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Goretusk Liver Pie"] = {
        itemID = 724,
        skillReq = 50,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 723, count = 1, name = "Goretusk Liver" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Strider Stew"] = {
        itemID = 5477,
        skillReq = 50,
        source = "vendor",
        sourceDetail = "Tari'qa, The Barrens",
        category = "Stamina / Spirit",
        skillRange = { 50, 90, 110, 130 },
        reagents = {
            { itemID = 5469, count = 1, name = "Strider Meat" },
            { itemID = 4536, count = 1, name = "Shiny Red Apple" },
        },
    },
    ["Blood Sausage"] = {
        itemID = 3220,
        skillReq = 60,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 60, 100, 120, 140 },
        reagents = {
            { itemID = 3173, count = 1, name = "Bear Meat" },
            { itemID = 3172, count = 1, name = "Boar Intestines" },
            { itemID = 3174, count = 1, name = "Spider Ichor" },
        },
    },
    ["Crunchy Spider Surprise"] = {
        itemID = 22645,
        skillReq = 60,
        source = "vendor",
        sourceDetail = "Master Chef Mouldier (H, Ghostlands) / Fazu (A, Bloodmyst Isle)",
        category = "Stamina / Spirit",
        skillRange = { 60, 100, 120, 140 },
        reagents = { { itemID = 22644, count = 1, name = "Crunchy Spider Leg" } },
    },
    ["Crab Cake"] = {
        itemID = 2683,
        skillReq = 75,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 75, 115, 135, 155 },
        reagents = {
            { itemID = 2674, count = 1, name = "Crawler Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Crocolisk Steak"] = {
        itemID = 3662,
        skillReq = 80,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 80, 120, 140, 160 },
        reagents = {
            { itemID = 2924, count = 1, name = "Crocolisk Meat" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Dry Pork Ribs"] = {
        itemID = 2687,
        skillReq = 80,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 80, 120, 140, 160 },
        reagents = {
            { itemID = 2677, count = 1, name = "Boar Ribs" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Murloc Fin Soup"] = {
        itemID = 3663,
        skillReq = 90,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 90, 130, 150, 170 },
        reagents = {
            { itemID = 1468, count = 2, name = "Murloc Fin" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Redridge Goulash"] = {
        itemID = 1082,
        skillReq = 100,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 100, 135, 155, 175 },
        reagents = {
            { itemID = 1081, count = 1, name = "Crisp Spider Meat" },
            { itemID = 1080, count = 1, name = "Tough Condor Meat" },
        },
    },
    ["Crispy Lizard Tail"] = {
        itemID = 5479,
        skillReq = 100,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 100, 140, 160, 180 },
        reagents = {
            { itemID = 5470, count = 1, name = "Thunder Lizard Tail" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Seasoned Wolf Kabob"] = {
        itemID = 1017,
        skillReq = 100,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 100, 140, 160, 180 },
        reagents = {
            { itemID = 1015, count = 2, name = "Lean Wolf Flank" },
            { itemID = 2665, count = 1, name = "Stormwind Seasoning Herbs" },
        },
    },
    ["Big Bear Steak"] = {
        itemID = 3726,
        skillReq = 110,
        source = "vendor",
        sourceDetail = "Super-Seller 680, Desolace",
        category = "Stamina / Spirit",
        skillRange = { 110, 150, 170, 190 },
        reagents = {
            { itemID = 3730, count = 1, name = "Big Bear Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Gooey Spider Cake"] = {
        itemID = 3666,
        skillReq = 110,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 110, 150, 170, 190 },
        reagents = {
            { itemID = 2251, count = 2, name = "Gooey Spider Leg" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Lean Venison"] = {
        itemID = 5480,
        skillReq = 110,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 110, 150, 170, 190 },
        reagents = {
            { itemID = 5471, count = 1, name = "Stag Meat" },
            { itemID = 2678, count = 4, name = "Mild Spices" },
        },
    },
    ["Crocolisk Gumbo"] = {
        itemID = 3664,
        skillReq = 120,
        source = "vendor",
        sourceDetail = "Kendor Kabonka, Stormwind",
        category = "Stamina / Spirit",
        skillRange = { 120, 160, 180, 200 },
        reagents = {
            { itemID = 3667, count = 1, name = "Tender Crocolisk Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Heavy Crocolisk Stew"] = {
        itemID = 20074,
        skillReq = 150,
        source = "vendor",
        sourceDetail = "Ogg'marr, Dustwallow Marsh",
        category = "Stamina / Spirit",
        skillRange = { 150, 160, 180, 200 },
        reagents = {
            { itemID = 3667, count = 2, name = "Tender Crocolisk Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Goblin Deviled Clams"] = {
        itemID = 5527,
        skillReq = 125,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 125, 165, 185, 205 },
        reagents = {
            { itemID = 5504, count = 1, name = "Tangy Clam Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Lean Wolf Steak"] = {
        itemID = 12209,
        skillReq = 125,
        source = "vendor",
        sourceDetail = "Super-Seller 680, Desolace",
        category = "Stamina / Spirit",
        skillRange = { 125, 165, 185, 205 },
        reagents = {
            { itemID = 1015, count = 1, name = "Lean Wolf Flank" },
            { itemID = 2678, count = 1, name = "Mild Spices" },
        },
    },
    ["Curiously Tasty Omelet"] = {
        itemID = 3665,
        skillReq = 130,
        source = "vendor",
        sourceDetail = "Kendor Kabonka (A, Stormwind) / Nerrist (STV) / Keena (Arathi)",
        category = "Stamina / Spirit",
        skillRange = { 130, 170, 190, 210 },
        reagents = {
            { itemID = 3685, count = 1, name = "Raptor Egg" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Hot Lion Chops"] = {
        itemID = 3727,
        skillReq = 125,
        source = "vendor",
        sourceDetail = "Zargh (H, The Barrens) / Vendor-Tron 1000 (Desolace)",
        category = "Stamina / Spirit",
        skillRange = { 125, 175, 195, 215 },
        reagents = {
            { itemID = 3731, count = 1, name = "Lion Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Tasty Lion Steak"] = {
        itemID = 3728,
        skillReq = 150,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 150, 190, 210, 230 },
        reagents = {
            { itemID = 3731, count = 2, name = "Lion Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Barbecued Buzzard Wing"] = {
        itemID = 4457,
        skillReq = 175,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 3404, count = 1, name = "Buzzard Wing" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Carrion Surprise"] = {
        itemID = 12213,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Banalash (H, Swamp of Sorrows) / Kireena (H, Desolace) / Ogg'marr (H, Dustwallow Marsh)",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12037, count = 1, name = "Mystery Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Giant Clam Scorcho"] = {
        itemID = 6038,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Kelsey Yance, Booty Bay",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 4655, count = 1, name = "Giant Clam Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Hot Wolf Ribs"] = {
        itemID = 13851,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Sheendra Tallgrass (H) / Vivianna (A), Feralas",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12203, count = 1, name = "Red Wolf Meat" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Jungle Stew"] = {
        itemID = 12212,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Corporal Bluth / Nerrist, Stranglethorn Vale",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12202, count = 1, name = "Tiger Meat" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
            { itemID = 4536, count = 2, name = "Shiny Red Apple" },
        },
    },
    ["Mystery Stew"] = {
        itemID = 12214,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Helenia Olden (Dustwallow Marsh) / Janet Hommers (Desolace)",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12037, count = 1, name = "Mystery Meat" },
            { itemID = 2596, count = 1, name = "Skin of Dwarven Stout" },
        },
    },
    ["Roast Raptor"] = {
        itemID = 12210,
        skillReq = 175,
        source = "vendor",
        sourceDetail = "Nerrist (STV) / Hammon Karwn (Arathi) / Ogg'marr (Dustwallow Marsh)",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 12184, count = 1, name = "Raptor Flesh" },
            { itemID = 2692, count = 1, name = "Hot Spices" },
        },
    },
    ["Soothing Turtle Bisque"] = {
        itemID = 3729,
        skillReq = 175,
        source = "quest",
        sourceDetail = "Quest: Soothing Turtle Bisque",
        category = "Stamina / Spirit",
        skillRange = { 175, 215, 235, 255 },
        reagents = {
            { itemID = 3712, count = 1, name = "Turtle Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
        },
    },
    ["Heavy Kodo Stew"] = {
        itemID = 12215,
        skillReq = 200,
        source = "vendor",
        sourceDetail = "Janet Hommers (A) / Kireena (H), Desolace",
        category = "Stamina / Spirit",
        skillRange = { 200, 225, 237, 250 },
        reagents = {
            { itemID = 12204, count = 2, name = "Heavy Kodo Meat" },
            { itemID = 3713, count = 1, name = "Soothing Spices" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Spider Sausage"] = {
        itemID = 17222,
        skillReq = 200,
        source = "trainer",
        category = "Stamina / Spirit",
        skillRange = { 200, 225, 237, 250 },
        reagents = { { itemID = 12205, count = 2, name = "White Spider Meat" } },
    },
    ["Monster Omelet"] = {
        itemID = 12218,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Malyen (A, Felwood) / Himmik (Winterspring)",
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 12207, count = 1, name = "Giant Egg" },
            { itemID = 3713, count = 2, name = "Soothing Spices" },
        },
    },
    ["Spiced Chili Crab"] = {
        itemID = 12216,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Banalash (H, Swamp of Sorrows) / Kriggon Talsone (A, Westfall)",
        category = "Stamina / Spirit",
        skillRange = { 225, 250, 262, 275 },
        reagents = {
            { itemID = 12206, count = 1, name = "Tender Crab Meat" },
            { itemID = 2692, count = 2, name = "Hot Spices" },
        },
    },
    ["Tender Wolf Steak"] = {
        itemID = 18045,
        skillReq = 225,
        source = "vendor",
        sourceDetail = "Dirge Quikcleave (Tanaris) / Innkeeper Fizzgrimble (Tanaris) / Truk Wildbeard (The Hinterlands)",
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
        itemID = 13928,
        skillReq = 240,
        source = "trainer",
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
        itemID = 35563,
        skillReq = 250,
        source = "trainer",
        category = "Attack Power / Spirit",
        skillRange = { 250, 275, 285, 295 },
        reagents = { { itemID = 35562, count = 1, name = "Bear Flank" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Juicy Bear Burger"] = {
        itemID = 35565,
        skillReq = 250,
        source = "trainer",
        category = "Spell Damage / Spirit",
        skillRange = { 250, 275, 285, 295 },
        reagents = { { itemID = 35562, count = 1, name = "Bear Flank" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Broiled Bloodfin"] = {
        itemID = 33867,
        skillReq = 300,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 33823, count = 1, name = "Bloodfin Catfish" } },
    },
    ["Buzzard Bites"] = {
        itemID = 27651,
        skillReq = 300,
        source = "quest",
        sourceDetail = "Quest: Smooth as Butter, Hellfire Peninsula",
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27671, count = 1, name = "Buzzard Meat" } },
    },
    ["Clam Bar"] = {
        itemID = 30155,
        skillReq = 300,
        source = "reputation",
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
        itemID = 27655,
        skillReq = 300,
        source = "vendor",
        sourceDetail = "Cookie One-Eye (H) / Sid Limbardi (A), Hellfire Peninsula",
        category = "Attack Power / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = { { itemID = 27674, count = 1, name = "Ravager Flesh" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Stormchops"] = {
        itemID = 33866,
        skillReq = 300,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
        category = "Stamina / Spirit",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 27678, count = 1, name = "Clefthoof Meat" },
            { itemID = 13757, count = 1, name = "Lightning Eel" },
        },
    },
    ["Dirge's Kickin' Chimaerok Chops"] = {
        itemID = 21023,
        skillReq = 300,
        source = "quest",
        sourceDetail = "Quest: Dirge's Kickin' Chimaerok Chops (Tanaris, removed in Cata)",
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
        itemID = 34411,
        skillReq = 325,
        source = "vendor",
        sourceDetail = "Smokywood Pastures Vendor, seasonal (Winter Veil)",
        category = "Stamina / Spirit",
        skillRange = { 325, 325, 325, 325 },
        reagents = {
            { itemID = 34412, count = 1, name = "Sparkling Apple Cider" },
            { itemID = 17196, count = 1, name = "Holiday Spirits" },
            { itemID = 17194, count = 1, name = "Holiday Spices" },
        },
    },
    ["Blackened Sporefish"] = {
        itemID = 27663,
        skillReq = 310,
        source = "vendor",
        sourceDetail = "Juno Dufrain, Zangarmarsh",
        category = "Stamina / Spirit",
        skillRange = { 310, 330, 340, 350 },
        reagents = { { itemID = 27429, count = 1, name = "Zangarian Sporefish" } },
    },
    ["Sporeling Snack"] = {
        itemID = 27656,
        skillReq = 310,
        source = "vendor",
        sourceDetail = "Mycah (Sporeggar QM), Zangarmarsh",
        category = "Stamina / Spirit",
        skillRange = { 310, 330, 340, 350 },
        reagents = { { itemID = 27676, count = 1, name = "Strange Spores" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Blackened Basilisk"] = {
        itemID = 27657,
        skillReq = 315,
        source = "vendor",
        sourceDetail = "Innkeeper Grilka (H) / Supply Officer Mills (A), Terokkar Forest",
        category = "Spell Damage / Spirit",
        skillRange = { 315, 335, 345, 355 },
        reagents = { { itemID = 27677, count = 1, name = "Chunk o' Basilisk" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Skullfish Soup"] = {
        itemID = 33825,
        skillReq = 325,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
        category = "Stamina / Spirit",
        skillRange = { 325, 335, 345, 355 },
        reagents = { { itemID = 33824, count = 1, name = "Crescent-Tail Skullfish" } },
    },
    ["Spicy Hot Talbuk"] = {
        itemID = 33872,
        skillReq = 325,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
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
        itemID = 27664,
        skillReq = 320,
        source = "vendor",
        sourceDetail = "Uriku / Nula the Butcher, Nagrand",
        category = "Agility / Spirit",
        skillRange = { 320, 340, 350, 360 },
        reagents = { { itemID = 27435, count = 1, name = "Figluster's Mudfish" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Poached Bluefish"] = {
        itemID = 27665,
        skillReq = 320,
        source = "vendor",
        sourceDetail = "Uriku / Nula the Butcher, Nagrand",
        category = "Spell Damage / Spirit",
        skillRange = { 320, 340, 350, 360 },
        reagents = { { itemID = 27437, count = 1, name = "Icefin Bluefish" } },
    },

    -- ================================================================
    -- HEALING / SPIRIT
    -- ================================================================
    ["Golden Fish Sticks"] = {
        itemID = 27666,
        skillReq = 325,
        source = "vendor",
        sourceDetail = "Rungor (H) / Innkeeper Biribi (A), Terokkar Forest",
        category = "Healing / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27438, count = 1, name = "Golden Darter" } },
    },

    -- ================================================================
    -- STRENGTH / SPIRIT
    -- ================================================================
    ["Kibler's Bits"] = {
        itemID = 33874,
        skillReq = 300,
        source = "quest",
        sourceDetail = "Daily cooking quest reward (The Rokk, Shattrath City)",
        category = "Strength / Spirit",
        skillRange = { 300, 345, 355, 365 },
        reagents = { { itemID = 27671, count = 1, name = "Buzzard Meat" } },
    },
    ["Roasted Clefthoof"] = {
        itemID = 27658,
        skillReq = 325,
        source = "vendor",
        sourceDetail = "Uriku / Nula the Butcher, Nagrand",
        category = "Strength / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27678, count = 1, name = "Clefthoof Meat" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Talbuk Steak"] = {
        itemID = 27660,
        skillReq = 325,
        source = "vendor",
        sourceDetail = "Uriku / Nula the Butcher, Nagrand",
        category = "Stamina / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27682, count = 1, name = "Talbuk Venison" } },
    },

    -- ================================================================
    -- AGILITY / SPIRIT
    -- ================================================================
    ["Warp Burger"] = {
        itemID = 27659,
        skillReq = 325,
        source = "vendor",
        sourceDetail = "Innkeeper Grilka (H) / Supply Officer Mills (A), Terokkar Forest",
        category = "Agility / Spirit",
        skillRange = { 325, 345, 355, 365 },
        reagents = { { itemID = 27681, count = 1, name = "Warped Flesh" } },
    },

    -- ================================================================
    -- SPELL DAMAGE / SPIRIT
    -- ================================================================
    ["Crunchy Serpent"] = {
        itemID = 31673,
        skillReq = 335,
        source = "vendor",
        sourceDetail = "Sassa Weldwell (A) / Xerintha Ravenoak (H), Blade's Edge Mountains",
        category = "Spell Damage / Spirit",
        skillRange = { 335, 355, 365, 375 },
        reagents = { { itemID = 31671, count = 1, name = "Serpent Flesh" } },
    },

    -- ================================================================
    -- STAMINA / SPIRIT
    -- ================================================================
    ["Mok'Nathal Shortribs"] = {
        itemID = 31672,
        skillReq = 335,
        source = "vendor",
        sourceDetail = "Sassa Weldwell (A) / Xerintha Ravenoak (H), Blade's Edge Mountains",
        category = "Stamina / Spirit",
        skillRange = { 335, 355, 365, 375 },
        reagents = { { itemID = 31670, count = 1, name = "Raptor Ribs" } },
    },
    ["Spicy Crawdad"] = {
        itemID = 27667,
        skillReq = 350,
        source = "vendor",
        sourceDetail = "Rungor (H, Stonebreaker Hold) / Innkeeper Biribi (A, Allerian Stronghold), Terokkar Forest",
        category = "Stamina / Spirit",
        skillRange = { 350, 370, 380, 390 },
        reagents = { { itemID = 27439, count = 1, name = "Furious Crawdad" } },
    },
    ["Fisherman's Feast"] = {
        itemID = 33052,
        skillReq = 375,
        source = "trainer",
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
