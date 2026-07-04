----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Alchemy.lua
-- Static recipe database for Alchemy (TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
-- Values sourced from SkillLineAbility + SpellReagents + Item DB2 (build 2.5.4.44833)
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- ELIXIR
    -- ================================================================
    -- Battle
    -- --------------------------------
    ["Adept's Elixir"] = {
        spellID = 33740,
        itemID = 28103,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Arcane Elixir"] = {
        spellID = 11461,
        itemID = 9155,
        skillReq = 235,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 235, 250, 270, 290 },
        reagents = {
            { itemID = 8839, count = 1, name = "Blindweed" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Catseye Elixir"] = {
        spellID = 12609,
        itemID = 10592,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 200, 220, 240, 260 },
        reagents = {
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3818, count = 1, name = "Fadeleaf" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Earthen Elixir"] = {
        spellID = 39637,
        itemID = 32063,
        skillReq = 320,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Friendly" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 320, 335, 342, 350 },
        reagents = {
            { itemID = 22786, count = 1, name = "Dreaming Glory" },
            { itemID = 22787, count = 2, name = "Ragveil" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Agility"] = {
        spellID = 11449,
        itemID = 8949,
        skillReq = 185,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 185, 205, 225, 245 },
        reagents = {
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Brute Force"] = {
        spellID = 17557,
        itemID = 13453,
        skillReq = 275,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 275, 290, 310, 330 },
        reagents = {
            { itemID = 8846, count = 2, name = "Gromsblood" },
            { itemID = 13466, count = 2, name = "Plaguebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Demonslaying"] = {
        spellID = 11477,
        itemID = 9224,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Nina Lightbrew, Rartar" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 250, 265, 285, 305 },
        reagents = {
            { itemID = 8846, count = 1, name = "Gromsblood" },
            { itemID = 8845, count = 1, name = "Ghost Mushroom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Empowerment"] = {
        spellID = 28578,
        itemID = 22848,
        skillReq = 365,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 365, 380, 387, 395 },
        reagents = {
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 22793, count = 1, name = "Mana Thistle" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Firepower"] = {
        spellID = 7845,
        itemID = 6373,
        skillReq = 140,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 140, 165, 185, 205 },
        reagents = {
            { itemID = 6371, count = 2, name = "Fire Oil" },
            { itemID = 3356, count = 1, name = "Kingsblood" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Frost Power"] = {
        spellID = 21923,
        itemID = 17708,
        skillReq = 190,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 190, 210, 230, 250 },
        reagents = {
            { itemID = 3819, count = 2, name = "Wintersbite" },
            { itemID = 3358, count = 1, name = "Khadgar's Whisker" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Giant Growth"] = {
        spellID = 8240,
        itemID = 6662,
        skillReq = 90,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 90, 120, 140, 160 },
        reagents = {
            { itemID = 6522, count = 1, name = "Deviate Fish" },
            { itemID = 2449, count = 1, name = "Earthroot" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Giants"] = {
        spellID = 11472,
        itemID = 9206,
        skillReq = 245,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 245, 260, 280, 300 },
        reagents = {
            { itemID = 8838, count = 1, name = "Sungrass" },
            { itemID = 8846, count = 1, name = "Gromsblood" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Greater Agility"] = {
        spellID = 11467,
        itemID = 9187,
        skillReq = 240,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 240, 255, 275, 295 },
        reagents = {
            { itemID = 8838, count = 1, name = "Sungrass" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Greater Firepower"] = {
        spellID = 26277,
        itemID = 21546,
        skillReq = 250,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 250, 265, 285, 305 },
        reagents = {
            { itemID = 6371, count = 3, name = "Fire Oil" },
            { itemID = 4625, count = 3, name = "Firebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Greater Intellect"] = {
        spellID = 11465,
        itemID = 9179,
        skillReq = 235,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 235, 250, 270, 290 },
        reagents = {
            { itemID = 8839, count = 1, name = "Blindweed" },
            { itemID = 3358, count = 1, name = "Khadgar's Whisker" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Greater Water Breathing"] = {
        spellID = 22808,
        itemID = 18294,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 215, 230, 250, 270 },
        reagents = {
            { itemID = 7972, count = 1, name = "Ichor of Undeath" },
            { itemID = 8831, count = 2, name = "Purple Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Healing Power"] = {
        spellID = 28545,
        itemID = 22825,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 310, 325, 332, 340 },
        reagents = {
            { itemID = 13464, count = 1, name = "Golden Sansam" },
            { itemID = 22786, count = 1, name = "Dreaming Glory" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Lesser Agility"] = {
        spellID = 2333,
        itemID = 3390,
        skillReq = 140,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 140, 165, 185, 205 },
        reagents = {
            { itemID = 3355, count = 1, name = "Wild Steelbloom" },
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Lion's Strength"] = {
        spellID = 2329,
        itemID = 2454,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 1, 55, 75, 95 },
        reagents = {
            { itemID = 2449, count = 1, name = "Earthroot" },
            { itemID = 765, count = 1, name = "Silverleaf" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Major Agility"] = {
        spellID = 28553,
        itemID = 22831,
        skillReq = 330,
        sources = {
            { method = "reputation", faction = "Horde", detail = "Thrallmar @ Friendly" },
            { method = "reputation", faction = "Alliance", detail = "Honor Hold @ Friendly" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 330, 345, 352, 360 },
        reagents = {
            { itemID = 22789, count = 1, name = "Terocone" },
            { itemID = 22785, count = 2, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Firepower"] = {
        spellID = 28556,
        itemID = 22833,
        skillReq = 345,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Scryers @ Honored" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 345, 360, 367, 375 },
        reagents = {
            { itemID = 22574, count = 2, name = "Mote of Fire" },
            { itemID = 22790, count = 1, name = "Ancient Lichen" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Frost Power"] = {
        spellID = 28549,
        itemID = 22827,
        skillReq = 320,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Haalrun, Seer Janidi" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 320, 335, 342, 350 },
        reagents = {
            { itemID = 22578, count = 2, name = "Mote of Water" },
            { itemID = 22790, count = 1, name = "Ancient Lichen" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Shadow Power"] = {
        spellID = 28558,
        itemID = 22835,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "Lower City @ Honored" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 22790, count = 1, name = "Ancient Lichen" },
            { itemID = 22792, count = 1, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Strength"] = {
        spellID = 28544,
        itemID = 22824,
        skillReq = 305,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 305, 320, 327, 335 },
        reagents = {
            { itemID = 13465, count = 1, name = "Mountain Silversage" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Mastery"] = {
        spellID = 33741,
        itemID = 28104,
        skillReq = 315,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 315, 330, 337, 345 },
        reagents = {
            { itemID = 22789, count = 3, name = "Terocone" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Minor Agility"] = {
        spellID = 3230,
        itemID = 2457,
        skillReq = 50,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 50, 80, 100, 120 },
        reagents = {
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 765, count = 1, name = "Silverleaf" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Ogre's Strength"] = {
        spellID = 3188,
        itemID = 3391,
        skillReq = 150,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 150, 175, 195, 215 },
        reagents = {
            { itemID = 2449, count = 1, name = "Earthroot" },
            { itemID = 3356, count = 1, name = "Kingsblood" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Shadow Power"] = {
        spellID = 11476,
        itemID = 9264,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Both", detail = "Sold by Algernon, Maria Lumere" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 250, 265, 285, 305 },
        reagents = {
            { itemID = 8845, count = 3, name = "Ghost Mushroom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Tongues"] = {
        spellID = 2336,
        itemID = 2460,
        skillReq = 70,
        sources = {
            { method = "undetermined", faction = "Both", detail = "Beta only" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 70, 100, 120, 140 },
        reagents = {
            { itemID = 2449, count = 2, name = "Earthroot" },
            { itemID = 785, count = 2, name = "Mageroyal" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Water Breathing"] = {
        spellID = 7179,
        itemID = 5996,
        skillReq = 90,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 90, 120, 140, 160 },
        reagents = {
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 6370, count = 2, name = "Blackmouth Oil" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Wisdom"] = {
        spellID = 3171,
        itemID = 3383,
        skillReq = 90,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 90, 120, 140, 160 },
        reagents = {
            { itemID = 785, count = 1, name = "Mageroyal" },
            { itemID = 2450, count = 2, name = "Briarthorn" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of the Mongoose"] = {
        spellID = 17571,
        itemID = 13452,
        skillReq = 280,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 280, 295, 315, 335 },
        reagents = {
            { itemID = 13465, count = 2, name = "Mountain Silversage" },
            { itemID = 13466, count = 2, name = "Plaguebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of the Sages"] = {
        spellID = 17555,
        itemID = 13447,
        skillReq = 270,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 270, 285, 305, 325 },
        reagents = {
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 13466, count = 2, name = "Plaguebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of the Searching Eye"] = {
        spellID = 28552,
        itemID = 22830,
        skillReq = 325,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 325, 340, 347, 355 },
        reagents = {
            { itemID = 22787, count = 2, name = "Ragveil" },
            { itemID = 22789, count = 1, name = "Terocone" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Fel Strength Elixir"] = {
        spellID = 38960,
        itemID = 31679,
        skillReq = 335,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 335, 350, 357, 365 },
        reagents = {
            { itemID = 22789, count = 1, name = "Terocone" },
            { itemID = 22792, count = 2, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Greater Arcane Elixir"] = {
        spellID = 17573,
        itemID = 13454,
        skillReq = 285,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 285, 300, 320, 340 },
        reagents = {
            { itemID = 13463, count = 3, name = "Dreamfoil" },
            { itemID = 13465, count = 1, name = "Mountain Silversage" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Onslaught Elixir"] = {
        spellID = 33738,
        itemID = 28102,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Battle",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13465, count = 1, name = "Mountain Silversage" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    -- Guardian
    -- --------------------------------
    ["Elixir of Camouflage"] = {
        spellID = 28543,
        itemID = 22823,
        skillReq = 305,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Alchemist Gribble, Altaa +3 more" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 305, 320, 327, 335 },
        reagents = {
            { itemID = 22787, count = 1, name = "Ragveil" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Defense"] = {
        spellID = 3177,
        itemID = 3389,
        skillReq = 130,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 130, 155, 175, 195 },
        reagents = {
            { itemID = 3355, count = 1, name = "Wild Steelbloom" },
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Detect Demon"] = {
        spellID = 11478,
        itemID = 9233,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 250, 265, 285, 305 },
        reagents = {
            { itemID = 8846, count = 2, name = "Gromsblood" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Detect Lesser Invisibility"] = {
        spellID = 3453,
        itemID = 3828,
        skillReq = 195,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 195, 215, 235, 255 },
        reagents = {
            { itemID = 3358, count = 1, name = "Khadgar's Whisker" },
            { itemID = 3818, count = 1, name = "Fadeleaf" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Detect Undead"] = {
        spellID = 11460,
        itemID = 9154,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 230, 245, 265, 285 },
        reagents = {
            { itemID = 8836, count = 1, name = "Arthas' Tears" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Draenic Wisdom"] = {
        spellID = 39638,
        itemID = 32067,
        skillReq = 320,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 320, 335, 342, 350 },
        reagents = {
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 22789, count = 1, name = "Terocone" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Dream Vision"] = {
        spellID = 11468,
        itemID = 9197,
        skillReq = 240,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Utility",
        skillRange = { 240, 255, 275, 295 },
        reagents = {
            { itemID = 8831, count = 3, name = "Purple Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Elixir of Fortitude"] = {
        spellID = 3450,
        itemID = 3825,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 175, 195, 215, 235 },
        reagents = {
            { itemID = 3355, count = 1, name = "Wild Steelbloom" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Greater Defense"] = {
        spellID = 11450,
        itemID = 8951,
        skillReq = 195,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 195, 215, 235, 255 },
        reagents = {
            { itemID = 3355, count = 1, name = "Wild Steelbloom" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Elixir of Ironskin"] = {
        spellID = 39639,
        itemID = 32068,
        skillReq = 330,
        sources = {
            { method = "vendor", faction = "Both", detail = "Alchemy supplies" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 330, 345, 352, 360 },
        reagents = {
            { itemID = 22790, count = 1, name = "Ancient Lichen" },
            { itemID = 22787, count = 1, name = "Ragveil" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Defense"] = {
        spellID = 28557,
        itemID = 22834,
        skillReq = 345,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Daga Ramba, Haalrun" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 345, 360, 367, 375 },
        reagents = {
            { itemID = 22790, count = 3, name = "Ancient Lichen" },
            { itemID = 22789, count = 1, name = "Terocone" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Fortitude"] = {
        spellID = 39636,
        itemID = 32062,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 310, 325, 332, 340 },
        reagents = {
            { itemID = 22787, count = 2, name = "Ragveil" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Major Mageblood"] = {
        spellID = 28570,
        itemID = 22840,
        skillReq = 355,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 355, 370, 377, 385 },
        reagents = {
            { itemID = 22790, count = 1, name = "Ancient Lichen" },
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Elixir of Minor Defense"] = {
        spellID = 7183,
        itemID = 5997,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 1, 55, 75, 95 },
        reagents = {
            { itemID = 765, count = 2, name = "Silverleaf" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Minor Fortitude"] = {
        spellID = 2334,
        itemID = 2458,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 50, 80, 100, 120 },
        reagents = {
            { itemID = 2449, count = 2, name = "Earthroot" },
            { itemID = 2447, count = 1, name = "Peacebloom" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Elixir of Superior Defense"] = {
        spellID = 17554,
        itemID = 13445,
        skillReq = 265,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kor\'geld, Soolie Berryfizz" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 265, 280, 300, 320 },
        reagents = {
            { itemID = 13423, count = 2, name = "Stonescale Oil" },
            { itemID = 8838, count = 1, name = "Sungrass" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- FLASK
    -- ================================================================
    ["Flask of Blinding Light"] = {
        spellID = 28590,
        itemID = 22861,
        skillReq = 390,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Flask",
        skillRange = { 390, 390, 397, 405 },
        reagents = {
            { itemID = 22794, count = 1, name = "Fel Lotus" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 22791, count = 7, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Flask of Chromatic Resistance"] = {
        spellID = 17638,
        itemID = 13513,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Lower City @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Flask",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13467, count = 7, name = "Icecap" },
            { itemID = 13465, count = 3, name = "Mountain Silversage" },
            { itemID = 13468, count = 1, name = "Black Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Flask of Chromatic Wonder"] = {
        spellID = 42736,
        itemID = 33208,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Violet Eye @ Friendly" },
        },
        category = "Flask",
        skillRange = { 375, 390, 397, 405 },
        reagents = {
            { itemID = 22786, count = 7, name = "Dreaming Glory" },
            { itemID = 22791, count = 3, name = "Netherbloom" },
            { itemID = 22794, count = 1, name = "Fel Lotus" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Flask of Distilled Wisdom"] = {
        spellID = 17636,
        itemID = 13511,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Flask",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13463, count = 7, name = "Dreamfoil" },
            { itemID = 13467, count = 3, name = "Icecap" },
            { itemID = 13468, count = 1, name = "Black Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Flask of Fortification"] = {
        spellID = 28587,
        itemID = 22851,
        skillReq = 390,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Flask",
        skillRange = { 390, 390, 397, 405 },
        reagents = {
            { itemID = 22794, count = 1, name = "Fel Lotus" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 22790, count = 7, name = "Ancient Lichen" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Flask of Mighty Restoration"] = {
        spellID = 28588,
        itemID = 22853,
        skillReq = 390,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Flask",
        skillRange = { 390, 390, 397, 405 },
        reagents = {
            { itemID = 22794, count = 1, name = "Fel Lotus" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 22786, count = 7, name = "Dreaming Glory" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Flask of Petrification"] = {
        spellID = 17634,
        itemID = 13506,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Flask",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13423, count = 7, name = "Stonescale Oil" },
            { itemID = 13465, count = 3, name = "Mountain Silversage" },
            { itemID = 13468, count = 1, name = "Black Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Flask of Pure Death"] = {
        spellID = 28591,
        itemID = 22866,
        skillReq = 390,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Flask",
        skillRange = { 390, 390, 397, 405 },
        reagents = {
            { itemID = 22794, count = 1, name = "Fel Lotus" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 22792, count = 7, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Flask of Relentless Assault"] = {
        spellID = 28589,
        itemID = 22854,
        skillReq = 390,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Flask",
        skillRange = { 390, 390, 397, 405 },
        reagents = {
            { itemID = 22794, count = 1, name = "Fel Lotus" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 22789, count = 7, name = "Terocone" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Flask of Supreme Power"] = {
        spellID = 17637,
        itemID = 13512,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Keepers of Time @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Flask",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13463, count = 7, name = "Dreamfoil" },
            { itemID = 13465, count = 3, name = "Mountain Silversage" },
            { itemID = 13468, count = 1, name = "Black Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Flask of the Titans"] = {
        spellID = 17635,
        itemID = 13510,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Flask",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 8846, count = 7, name = "Gromsblood" },
            { itemID = 13423, count = 3, name = "Stonescale Oil" },
            { itemID = 13468, count = 1, name = "Black Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- OIL
    -- ================================================================
    ["Blackmouth Oil"] = {
        spellID = 7836,
        itemID = 6370,
        skillReq = 80,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Oil",
        skillRange = { 80, 80, 90, 100 },
        reagents = {
            { itemID = 6358, count = 2, name = "Oily Blackmouth" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Fire Oil"] = {
        spellID = 7837,
        itemID = 6371,
        skillReq = 130,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Oil",
        skillRange = { 130, 150, 160, 170 },
        reagents = {
            { itemID = 6359, count = 2, name = "Firefin Snapper" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Frost Oil"] = {
        spellID = 3454,
        itemID = 3829,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Alliance" },
            { method = "vendor", faction = "Both", detail = "Sold by Bro\'kin" },
        },
        category = "Oil",
        skillRange = { 200, 220, 240, 260 },
        reagents = {
            { itemID = 3358, count = 4, name = "Khadgar's Whisker" },
            { itemID = 3819, count = 2, name = "Wintersbite" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Oil of Immolation"] = {
        spellID = 11451,
        itemID = 8956,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Oil",
        skillRange = { 205, 220, 240, 260 },
        reagents = {
            { itemID = 4625, count = 1, name = "Firebloom" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Shadow Oil"] = {
        spellID = 3449,
        itemID = 3824,
        skillReq = 165,
        sources = {
            { method = "trainer", faction = "Alliance" },
            { method = "vendor", faction = "Both", detail = "Sold by Bliztik, Montarr" },
        },
        category = "Oil",
        skillRange = { 165, 190, 210, 230 },
        reagents = {
            { itemID = 3818, count = 4, name = "Fadeleaf" },
            { itemID = 3369, count = 4, name = "Grave Moss" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Stonescale Oil"] = {
        spellID = 17551,
        itemID = 13423,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Oil",
        skillRange = { 250, 250, 255, 260 },
        reagents = {
            { itemID = 13422, count = 1, name = "Stonescale Eel" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },

    -- ================================================================
    -- POTION
    -- ================================================================    },    },    },    },
    -- Healing
    -- --------------------------------
    ["Discolored Healing Potion"] = {
        spellID = 4508,
        itemID = 4596,
        skillReq = 50,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Wild Hearts" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 50, 80, 100, 120 },
        reagents = {
            { itemID = 3164, count = 1, name = "Discolored Worg Heart" },
            { itemID = 2447, count = 1, name = "Peacebloom" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Fel Regeneration Potion"] = {
        spellID = 38962,
        itemID = 31676,
        skillReq = 345,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 345, 360, 367, 375 },
        reagents = {
            { itemID = 22785, count = 2, name = "Felweed" },
            { itemID = 22792, count = 3, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Greater Healing Potion"] = {
        spellID = 7181,
        itemID = 1710,
        skillReq = 155,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 155, 175, 195, 215 },
        reagents = {
            { itemID = 3357, count = 1, name = "Liferoot" },
            { itemID = 3356, count = 1, name = "Kingsblood" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Healing Potion"] = {
        spellID = 3447,
        itemID = 929,
        skillReq = 110,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 110, 135, 155, 175 },
        reagents = {
            { itemID = 2453, count = 1, name = "Bruiseweed" },
            { itemID = 2450, count = 1, name = "Briarthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Lesser Healing Potion"] = {
        spellID = 2337,
        itemID = 858,
        skillReq = 55,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 55, 85, 105, 125 },
        reagents = {
            { itemID = 118, count = 1, name = "Minor Healing Potion" },
            { itemID = 2450, count = 1, name = "Briarthorn" },
        },
    },
    ["Major Healing Potion"] = {
        spellID = 17556,
        itemID = 13446,
        skillReq = 275,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 275, 290, 310, 330 },
        reagents = {
            { itemID = 13464, count = 2, name = "Golden Sansam" },
            { itemID = 13465, count = 1, name = "Mountain Silversage" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Minor Healing Potion"] = {
        spellID = 2330,
        itemID = 118,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 1, 55, 75, 95 },
        reagents = {
            { itemID = 2447, count = 1, name = "Peacebloom" },
            { itemID = 765, count = 1, name = "Silverleaf" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Super Healing Potion"] = {
        spellID = 28551,
        itemID = 22829,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 325, 340, 347, 355 },
        reagents = {
            { itemID = 22791, count = 2, name = "Netherbloom" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Superior Healing Potion"] = {
        spellID = 11457,
        itemID = 3928,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 215, 230, 250, 270 },
        reagents = {
            { itemID = 8838, count = 1, name = "Sungrass" },
            { itemID = 3358, count = 1, name = "Khadgar's Whisker" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Volatile Healing Potion"] = {
        spellID = 33732,
        itemID = 28100,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Healing",
        skillRange = { 300, 315, 322, 330 },
        reagents = {
            { itemID = 13464, count = 1, name = "Golden Sansam" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    -- Mana
    -- --------------------------------
    ["Fel Mana Potion"] = {
        spellID = 38961,
        itemID = 31677,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 22793, count = 1, name = "Mana Thistle" },
            { itemID = 22792, count = 2, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Greater Mana Potion"] = {
        spellID = 11448,
        itemID = 6149,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 205, 220, 240, 260 },
        reagents = {
            { itemID = 3358, count = 1, name = "Khadgar's Whisker" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Lesser Mana Potion"] = {
        spellID = 3173,
        itemID = 3385,
        skillReq = 120,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 120, 145, 165, 185 },
        reagents = {
            { itemID = 785, count = 1, name = "Mageroyal" },
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Major Mana Potion"] = {
        spellID = 17580,
        itemID = 13444,
        skillReq = 295,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Magnus Frostwake" },
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 295, 310, 330, 350 },
        reagents = {
            { itemID = 13463, count = 3, name = "Dreamfoil" },
            { itemID = 13467, count = 2, name = "Icecap" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Mana Potion"] = {
        spellID = 3452,
        itemID = 3827,
        skillReq = 160,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 160, 180, 200, 220 },
        reagents = {
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 3356, count = 1, name = "Kingsblood" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Minor Mana Potion"] = {
        spellID = 2331,
        itemID = 2455,
        skillReq = 25,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 25, 65, 85, 105 },
        reagents = {
            { itemID = 785, count = 1, name = "Mageroyal" },
            { itemID = 765, count = 1, name = "Silverleaf" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Super Mana Potion"] = {
        spellID = 28555,
        itemID = 22832,
        skillReq = 340,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Daga Ramba, Haalrun" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 340, 355, 362, 370 },
        reagents = {
            { itemID = 22786, count = 2, name = "Dreaming Glory" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Superior Mana Potion"] = {
        spellID = 17553,
        itemID = 13443,
        skillReq = 260,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Alliance", detail = "Sold by Ulthir" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 260, 275, 295, 315 },
        reagents = {
            { itemID = 8838, count = 2, name = "Sungrass" },
            { itemID = 8839, count = 2, name = "Blindweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Unstable Mana Potion"] = {
        spellID = 33733,
        itemID = 28101,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Mana",
        skillRange = { 310, 325, 332, 340 },
        reagents = {
            { itemID = 22787, count = 2, name = "Ragveil" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    -- Resistance
    -- --------------------------------
    ["Cauldron of Major Arcane Protection"] = {
        spellID = 41458,
        itemID = 32839,
        skillReq = 360,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 360, 370, 380 },
        reagents = {
            { itemID = 22457, count = 2, name = "Primal Mana" },
            { itemID = 22793, count = 7, name = "Mana Thistle" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
        },
    },
    ["Cauldron of Major Fire Protection"] = {
        spellID = 41500,
        itemID = 32849,
        skillReq = 360,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 360, 370, 380 },
        reagents = {
            { itemID = 21884, count = 2, name = "Primal Fire" },
            { itemID = 22793, count = 7, name = "Mana Thistle" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
        },
    },
    ["Cauldron of Major Frost Protection"] = {
        spellID = 41501,
        itemID = 32850,
        skillReq = 360,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 360, 370, 380 },
        reagents = {
            { itemID = 21885, count = 2, name = "Primal Water" },
            { itemID = 22793, count = 7, name = "Mana Thistle" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
        },
    },
    ["Cauldron of Major Nature Protection"] = {
        spellID = 41502,
        itemID = 32851,
        skillReq = 360,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 360, 370, 380 },
        reagents = {
            { itemID = 21886, count = 2, name = "Primal Life" },
            { itemID = 22793, count = 7, name = "Mana Thistle" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
        },
    },
    ["Cauldron of Major Shadow Protection"] = {
        spellID = 41503,
        itemID = 32852,
        skillReq = 360,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 360, 370, 380 },
        reagents = {
            { itemID = 22456, count = 2, name = "Primal Shadow" },
            { itemID = 22793, count = 7, name = "Mana Thistle" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
        },
    },
    ["Fire Protection Potion"] = {
        spellID = 7257,
        itemID = 6049,
        skillReq = 165,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Jeeda, Nandar Branson" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 165, 210, 230, 250 },
        reagents = {
            { itemID = 4402, count = 1, name = "Small Flame Sac" },
            { itemID = 6371, count = 1, name = "Fire Oil" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Frost Protection Potion"] = {
        spellID = 7258,
        itemID = 6050,
        skillReq = 190,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Drovnar Strongbrew, Glyx Brewright" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 190, 205, 225, 245 },
        reagents = {
            { itemID = 3819, count = 1, name = "Wintersbite" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Greater Arcane Protection Potion"] = {
        spellID = 17577,
        itemID = 13461,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 290, 305, 325, 345 },
        reagents = {
            { itemID = 11176, count = 1, name = "Dream Dust" },
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Greater Fire Protection Potion"] = {
        spellID = 17574,
        itemID = 13457,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 290, 305, 325, 345 },
        reagents = {
            { itemID = 7068, count = 1, name = "Elemental Fire" },
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Greater Frost Protection Potion"] = {
        spellID = 17575,
        itemID = 13456,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 290, 305, 325, 345 },
        reagents = {
            { itemID = 7070, count = 1, name = "Elemental Water" },
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Greater Nature Protection Potion"] = {
        spellID = 17576,
        itemID = 13458,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 290, 305, 325, 345 },
        reagents = {
            { itemID = 7067, count = 1, name = "Elemental Earth" },
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Greater Shadow Protection Potion"] = {
        spellID = 17578,
        itemID = 13459,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 290, 305, 325, 345 },
        reagents = {
            { itemID = 3824, count = 1, name = "Shadow Oil" },
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Holy Protection Potion"] = {
        spellID = 7255,
        itemID = 6051,
        skillReq = 100,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Hula\'mahi, Kzixx +1 more" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 100, 130, 150, 170 },
        reagents = {
            { itemID = 2453, count = 1, name = "Bruiseweed" },
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Magic Resistance Potion"] = {
        spellID = 11453,
        itemID = 9036,
        skillReq = 210,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 210, 225, 245, 265 },
        reagents = {
            { itemID = 3358, count = 1, name = "Khadgar's Whisker" },
            { itemID = 8831, count = 1, name = "Purple Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Major Arcane Protection Potion"] = {
        spellID = 28575,
        itemID = 22845,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 22457, count = 1, name = "Primal Mana" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 18256, count = 5, name = "Imbued Vial" },
        },
    },
    ["Major Fire Protection Potion"] = {
        spellID = 28571,
        itemID = 22841,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 21884, count = 1, name = "Primal Fire" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 18256, count = 5, name = "Imbued Vial" },
        },
    },
    ["Major Frost Protection Potion"] = {
        spellID = 28572,
        itemID = 22842,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 21885, count = 1, name = "Primal Water" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 18256, count = 5, name = "Imbued Vial" },
        },
    },
    ["Major Holy Protection Potion"] = {
        spellID = 28577,
        itemID = 22847,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 21886, count = 1, name = "Primal Life" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 18256, count = 5, name = "Imbued Vial" },
        },
    },
    ["Major Nature Protection Potion"] = {
        spellID = 28573,
        itemID = 22844,
        skillReq = 360,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Revered" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 21886, count = 1, name = "Primal Life" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 18256, count = 5, name = "Imbued Vial" },
        },
    },
    ["Major Shadow Protection Potion"] = {
        spellID = 28576,
        itemID = 22846,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 360, 375, 382, 390 },
        reagents = {
            { itemID = 22456, count = 1, name = "Primal Shadow" },
            { itemID = 22793, count = 3, name = "Mana Thistle" },
            { itemID = 18256, count = 5, name = "Imbued Vial" },
        },
    },
    ["Minor Magic Resistance Potion"] = {
        spellID = 3172,
        itemID = 3384,
        skillReq = 110,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 110, 135, 155, 175 },
        reagents = {
            { itemID = 785, count = 3, name = "Mageroyal" },
            { itemID = 3355, count = 1, name = "Wild Steelbloom" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Nature Protection Potion"] = {
        spellID = 7259,
        itemID = 6052,
        skillReq = 190,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Alchemist Pestlezugg, Bronk +2 more" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 190, 210, 230, 250 },
        reagents = {
            { itemID = 3357, count = 1, name = "Liferoot" },
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Restorative Potion"] = {
        spellID = 11452,
        itemID = 9030,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 215, 225, 245, 265 },
        reagents = {
            { itemID = 7067, count = 1, name = "Elemental Earth" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Shadow Protection Potion"] = {
        spellID = 7256,
        itemID = 6048,
        skillReq = 135,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Christoph Jeffcoat, Harklan Moongrove" },
        },
        category = "Potion",
        subcategory = "Resistance",
        skillRange = { 135, 160, 180, 200 },
        reagents = {
            { itemID = 3369, count = 1, name = "Grave Moss" },
            { itemID = 3356, count = 1, name = "Kingsblood" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    -- Utility
    -- --------------------------------
    ["Destruction Potion"] = {
        spellID = 28565,
        itemID = 22839,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 22792, count = 2, name = "Nightmare Vine" },
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Dreamless Sleep Potion"] = {
        spellID = 15833,
        itemID = 12190,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 230, 245, 265, 285 },
        reagents = {
            { itemID = 8831, count = 3, name = "Purple Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Free Action Potion"] = {
        spellID = 6624,
        itemID = 5634,
        skillReq = 150,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kor\'geld, Soolie Berryfizz +1 more" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 150, 175, 195, 215 },
        reagents = {
            { itemID = 6370, count = 2, name = "Blackmouth Oil" },
            { itemID = 3820, count = 1, name = "Stranglekelp" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Ghost Dye"] = {
        spellID = 11473,
        itemID = 9210,
        skillReq = 245,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Both", detail = "Sold by Bronk, Logannas" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 245, 260, 280, 300 },
        reagents = {
            { itemID = 8845, count = 2, name = "Ghost Mushroom" },
            { itemID = 4342, count = 1, name = "Purple Dye" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Gift of Arthas"] = {
        spellID = 11466,
        itemID = 9088,
        skillReq = 240,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 240, 255, 275, 295 },
        reagents = {
            { itemID = 8836, count = 1, name = "Arthas' Tears" },
            { itemID = 8839, count = 1, name = "Blindweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Goblin Rocket Fuel"] = {
        spellID = 11456,
        itemID = 9061,
        skillReq = 210,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 210, 225, 245, 265 },
        reagents = {
            { itemID = 4625, count = 1, name = "Firebloom" },
            { itemID = 9260, count = 1, name = "Volatile Rum" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Great Rage Potion"] = {
        spellID = 6618,
        itemID = 5633,
        skillReq = 175,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Hagrus, Ulthir" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 175, 195, 215, 235 },
        reagents = {
            { itemID = 5637, count = 1, name = "Large Fang" },
            { itemID = 3356, count = 1, name = "Kingsblood" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Greater Dreamless Sleep Potion"] = {
        spellID = 24366,
        itemID = 20002,
        skillReq = 275,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Neutral" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 275, 290, 310, 330 },
        reagents = {
            { itemID = 13463, count = 2, name = "Dreamfoil" },
            { itemID = 13464, count = 1, name = "Golden Sansam" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Greater Stoneshield Potion"] = {
        spellID = 17570,
        itemID = 13455,
        skillReq = 280,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 280, 295, 315, 335 },
        reagents = {
            { itemID = 13423, count = 2, name = "Stonescale Oil" },
            { itemID = 10620, count = 1, name = "Thorium Ore" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Gurubashi Mojo Madness"] = {
        spellID = 24266,
        itemID = 19931,
        skillReq = 315,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 315, 315, 322, 330 },
        reagents = {
            { itemID = 12938, count = 1, name = "Blood of Heroes" },
            { itemID = 19943, count = 1, name = "Massive Mojo" },
            { itemID = 12804, count = 6, name = "Powerful Mojo" },
            { itemID = 13468, count = 1, name = "Black Lotus" },
        },
    },
    ["Haste Potion"] = {
        spellID = 28564,
        itemID = 22838,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 22789, count = 2, name = "Terocone" },
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Heroic Potion"] = {
        spellID = 28563,
        itemID = 22837,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 22789, count = 2, name = "Terocone" },
            { itemID = 22790, count = 1, name = "Ancient Lichen" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Insane Strength Potion"] = {
        spellID = 28550,
        itemID = 22828,
        skillReq = 320,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 320, 335, 342, 350 },
        reagents = {
            { itemID = 22789, count = 3, name = "Terocone" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Invisibility Potion"] = {
        spellID = 11464,
        itemID = 9172,
        skillReq = 235,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 235, 250, 270, 290 },
        reagents = {
            { itemID = 8845, count = 1, name = "Ghost Mushroom" },
            { itemID = 8838, count = 1, name = "Sungrass" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Ironshield Potion"] = {
        spellID = 28579,
        itemID = 22849,
        skillReq = 365,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 365, 380, 387, 395 },
        reagents = {
            { itemID = 22790, count = 2, name = "Ancient Lichen" },
            { itemID = 22573, count = 3, name = "Mote of Earth" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Lesser Invisibility Potion"] = {
        spellID = 3448,
        itemID = 3823,
        skillReq = 165,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 165, 185, 205, 225 },
        reagents = {
            { itemID = 3818, count = 1, name = "Fadeleaf" },
            { itemID = 3355, count = 1, name = "Wild Steelbloom" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Lesser Stoneshield Potion"] = {
        spellID = 4942,
        itemID = 4623,
        skillReq = 215,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Liquid Stone" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 215, 230, 250, 270 },
        reagents = {
            { itemID = 3858, count = 1, name = "Mithril Ore" },
            { itemID = 3821, count = 1, name = "Goldthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Limited Invulnerability Potion"] = {
        spellID = 3175,
        itemID = 3387,
        skillReq = 250,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 250, 275, 295, 315 },
        reagents = {
            { itemID = 8839, count = 2, name = "Blindweed" },
            { itemID = 8845, count = 1, name = "Ghost Mushroom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Living Action Potion"] = {
        spellID = 24367,
        itemID = 20008,
        skillReq = 285,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Revered" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 285, 300, 320, 340 },
        reagents = {
            { itemID = 13467, count = 2, name = "Icecap" },
            { itemID = 13465, count = 2, name = "Mountain Silversage" },
            { itemID = 10286, count = 2, name = "Heart of the Wild" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Mageblood Potion"] = {
        spellID = 24365,
        itemID = 20007,
        skillReq = 275,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Honored" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 275, 290, 310, 330 },
        reagents = {
            { itemID = 13463, count = 1, name = "Dreamfoil" },
            { itemID = 13466, count = 2, name = "Plaguebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Major Dreamless Sleep Potion"] = {
        spellID = 28562,
        itemID = 22836,
        skillReq = 350,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Daga Ramba, Leeli Longhaggle" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 22786, count = 1, name = "Dreaming Glory" },
            { itemID = 22792, count = 1, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Major Rejuvenation Potion"] = {
        spellID = 22732,
        itemID = 18253,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 300, 310, 320, 330 },
        reagents = {
            { itemID = 10286, count = 1, name = "Heart of the Wild" },
            { itemID = 13464, count = 4, name = "Golden Sansam" },
            { itemID = 13463, count = 4, name = "Dreamfoil" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Major Troll's Blood Potion"] = {
        spellID = 24368,
        itemID = 20004,
        skillReq = 290,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Friendly" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 290, 305, 325, 345 },
        reagents = {
            { itemID = 8846, count = 1, name = "Gromsblood" },
            { itemID = 13466, count = 2, name = "Plaguebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Mighty Rage Potion"] = {
        spellID = 17552,
        itemID = 13442,
        skillReq = 255,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 255, 270, 290, 310 },
        reagents = {
            { itemID = 8846, count = 3, name = "Gromsblood" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Mighty Troll's Blood Potion"] = {
        spellID = 3451,
        itemID = 3826,
        skillReq = 180,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 180, 200, 220, 240 },
        reagents = {
            { itemID = 3357, count = 1, name = "Liferoot" },
            { itemID = 2453, count = 1, name = "Bruiseweed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Minor Rejuvenation Potion"] = {
        spellID = 2332,
        itemID = 2456,
        skillReq = 40,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 40, 70, 90, 110 },
        reagents = {
            { itemID = 785, count = 2, name = "Mageroyal" },
            { itemID = 2447, count = 1, name = "Peacebloom" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Potion of Curing"] = {
        spellID = 3174,
        itemID = 3386,
        skillReq = 120,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 120, 145, 165, 185 },
        reagents = {
            { itemID = 1288, count = 1, name = "Large Venom Sac" },
            { itemID = 2453, count = 1, name = "Bruiseweed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Purification Potion"] = {
        spellID = 17572,
        itemID = 13462,
        skillReq = 285,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 285, 300, 320, 340 },
        reagents = {
            { itemID = 13467, count = 2, name = "Icecap" },
            { itemID = 13466, count = 2, name = "Plaguebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Rage Potion"] = {
        spellID = 6617,
        itemID = 5631,
        skillReq = 60,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Defias Profiteer, Hagrus +2 more" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 60, 90, 110, 130 },
        reagents = {
            { itemID = 5635, count = 2, name = "Sharp Claw" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Shrouding Potion"] = {
        spellID = 28554,
        itemID = 22871,
        skillReq = 335,
        sources = {
            { method = "reputation", faction = "Both", detail = "Sporeggar @ Revered" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 335, 350, 357, 365 },
        reagents = {
            { itemID = 22787, count = 3, name = "Ragveil" },
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Sneaking Potion"] = {
        spellID = 28546,
        itemID = 22826,
        skillReq = 315,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Leeli Longhaggle, Seer Janidi" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 315, 330, 337, 345 },
        reagents = {
            { itemID = 22787, count = 2, name = "Ragveil" },
            { itemID = 22785, count = 1, name = "Felweed" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Strong Troll's Blood Potion"] = {
        spellID = 3176,
        itemID = 3388,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 125, 150, 170, 190 },
        reagents = {
            { itemID = 2453, count = 2, name = "Bruiseweed" },
            { itemID = 2450, count = 2, name = "Briarthorn" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Super Rejuvenation Potion"] = {
        spellID = 28586,
        itemID = 22850,
        skillReq = 390,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 390, 390, 397, 405 },
        reagents = {
            { itemID = 22793, count = 2, name = "Mana Thistle" },
            { itemID = 22786, count = 1, name = "Dreaming Glory" },
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Swiftness Potion"] = {
        spellID = 2335,
        itemID = 2459,
        skillReq = 60,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 60, 90, 110, 130 },
        reagents = {
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 2450, count = 1, name = "Briarthorn" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Swim Speed Potion"] = {
        spellID = 7841,
        itemID = 6372,
        skillReq = 100,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 100, 130, 150, 170 },
        reagents = {
            { itemID = 2452, count = 1, name = "Swiftthistle" },
            { itemID = 6370, count = 1, name = "Blackmouth Oil" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Weak Troll's Blood Potion"] = {
        spellID = 3170,
        itemID = 3382,
        skillReq = 15,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Elixir",
        subcategory = "Guardian",
        skillRange = { 15, 60, 80, 100 },
        reagents = {
            { itemID = 2447, count = 1, name = "Peacebloom" },
            { itemID = 2449, count = 2, name = "Earthroot" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Wildvine Potion"] = {
        spellID = 11458,
        itemID = 9144,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Potion",
        subcategory = "Utility",
        skillRange = { 225, 240, 260, 280 },
        reagents = {
            { itemID = 8153, count = 1, name = "Wildvine" },
            { itemID = 8831, count = 1, name = "Purple Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- TRANSMUTE
    -- ================================================================
    -- Elemental
    -- --------------------------------
    ["Transmute: Air to Fire"] = {
        spellID = 17559,
        itemID = 7078,
        skillReq = 275,
        sources = {
            { method = "reputation", faction = "Both", detail = "Argent Dawn @ Friendly" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 7082, count = 1, name = "Essence of Air" } },
    },
    ["Transmute: Earth to Life"] = {
        spellID = 17566,
        itemID = 12803,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 7076, count = 1, name = "Essence of Earth" } },
    },
    ["Transmute: Earth to Water"] = {
        spellID = 17561,
        itemID = 7080,
        skillReq = 275,
        sources = {
            { method = "reputation", faction = "Both", detail = "Timbermaw Hold @ Neutral" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 7076, count = 1, name = "Essence of Earth" } },
    },
    ["Transmute: Earthstorm Diamond"] = {
        spellID = 32765,
        itemID = 25867,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Friendly" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 23079, count = 3, name = "Deep Peridot" },
            { itemID = 23107, count = 3, name = "Shadow Draenite" },
            { itemID = 23112, count = 3, name = "Golden Draenite" },
            { itemID = 22452, count = 2, name = "Primal Earth" },
            { itemID = 21885, count = 2, name = "Primal Water" },
        },
    },
    ["Transmute: Elemental Fire"] = {
        spellID = 25146,
        itemID = 7068,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Thorium Brotherhood @ Neutral" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 300, 301, 305, 310 },
        reagents = { { itemID = 7077, count = 1, name = "Heart of Fire" } },
    },
    ["Transmute: Fire to Earth"] = {
        spellID = 17560,
        itemID = 7076,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Plugger Spazzring" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 7078, count = 1, name = "Essence of Fire" } },
    },
    ["Transmute: Life to Earth"] = {
        spellID = 17565,
        itemID = 7076,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 12803, count = 1, name = "Living Essence" } },
    },
    ["Transmute: Skyfire Diamond"] = {
        spellID = 32766,
        itemID = 25868,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Horde", detail = "Thrallmar @ Friendly" },
            { method = "reputation", faction = "Alliance", detail = "Honor Hold @ Friendly" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 23077, count = 3, name = "Blood Garnet" },
            { itemID = 21929, count = 3, name = "Flame Spessarite" },
            { itemID = 23117, count = 3, name = "Azure Moonstone" },
            { itemID = 21884, count = 2, name = "Primal Fire" },
            { itemID = 22451, count = 2, name = "Primal Air" },
        },
    },
    ["Transmute: Undeath to Water"] = {
        spellID = 17563,
        itemID = 7080,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 12808, count = 1, name = "Essence of Undeath" } },
    },
    ["Transmute: Water to Air"] = {
        spellID = 17562,
        itemID = 7082,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Magnus Frostwake" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 7080, count = 1, name = "Essence of Water" } },
    },
    ["Transmute: Water to Undeath"] = {
        spellID = 17564,
        itemID = 12808,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Transmute",
        subcategory = "Elemental",
        skillRange = { 275, 275, 282, 290 },
        reagents = { { itemID = 7080, count = 1, name = "Essence of Water" } },
    },
    -- Metal
    -- --------------------------------
    ["Transmute: Arcanite"] = {
        spellID = 17187,
        itemID = 12360,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Alchemist Pestlezugg" },
        },
        category = "Transmute",
        subcategory = "Metal",
        skillRange = { 275, 275, 282, 290 },
        reagents = {
            { itemID = 12359, count = 1, name = "Thorium Bar" },
            { itemID = 12363, count = 1, name = "Arcane Crystal" },
        },
    },
    ["Transmute: Iron to Gold"] = {
        spellID = 11479,
        itemID = 3577,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Alliance" },
            { method = "vendor", faction = "Both", detail = "Sold by Alchemist Pestlezugg" },
        },
        category = "Transmute",
        subcategory = "Metal",
        skillRange = { 225, 240, 260, 280 },
        reagents = { { itemID = 3575, count = 1, name = "Iron Bar" } },
    },
    ["Transmute: Mithril to Truesilver"] = {
        spellID = 11480,
        itemID = 6037,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Alliance" },
            { method = "vendor", faction = "Both", detail = "Sold by Alchemist Pestlezugg" },
        },
        category = "Transmute",
        subcategory = "Metal",
        skillRange = { 225, 240, 260, 280 },
        reagents = { { itemID = 3860, count = 1, name = "Mithril Bar" } },
    },
    -- Primal
    -- --------------------------------
    ["Transmute: Primal Air to Fire"] = {
        spellID = 28566,
        itemID = 21884,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Honored" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 350, 365, 372, 380 },
        reagents = { { itemID = 22451, count = 1, name = "Primal Air" } },
    },
    ["Transmute: Primal Earth to Life"] = {
        spellID = 28585,
        itemID = 21886,
        skillReq = 385,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 385, 385, 392, 400 },
        reagents = { { itemID = 22452, count = 1, name = "Primal Earth" } },
    },
    ["Transmute: Primal Earth to Water"] = {
        spellID = 28567,
        itemID = 21885,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "Sporeggar @ Honored" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 350, 365, 372, 380 },
        reagents = { { itemID = 22452, count = 1, name = "Primal Earth" } },
    },
    ["Transmute: Primal Fire to Earth"] = {
        spellID = 28568,
        itemID = 22452,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Horde", detail = "The Mag'har @ Honored" },
            { method = "reputation", faction = "Alliance", detail = "Kurenai @ Honored" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 350, 365, 372, 380 },
        reagents = { { itemID = 21884, count = 1, name = "Primal Fire" } },
    },
    ["Transmute: Primal Fire to Mana"] = {
        spellID = 28583,
        itemID = 22457,
        skillReq = 385,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 385, 385, 392, 400 },
        reagents = { { itemID = 21884, count = 1, name = "Primal Fire" } },
    },
    ["Transmute: Primal Life to Earth"] = {
        spellID = 28584,
        itemID = 22452,
        skillReq = 385,
        sources = {
            { method = "discovery", faction = "Both", detail = "discovered while crafting" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 385, 385, 392, 400 },
        reagents = { { itemID = 21886, count = 1, name = "Primal Life" } },
    },
    ["Transmute: Primal Mana to Fire"] = {
        spellID = 28582,
        itemID = 21884,
        skillReq = 385,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 385, 385, 392, 400 },
        reagents = { { itemID = 22457, count = 1, name = "Primal Mana" } },
    },
    ["Transmute: Primal Might"] = {
        spellID = 29688,
        itemID = 23571,
        skillReq = 350,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Altaa, Melaris +1 more" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 350, 365, 372, 380 },
        reagents = {
            { itemID = 22452, count = 1, name = "Primal Earth" },
            { itemID = 21885, count = 1, name = "Primal Water" },
            { itemID = 22451, count = 1, name = "Primal Air" },
            { itemID = 21884, count = 1, name = "Primal Fire" },
            { itemID = 22457, count = 1, name = "Primal Mana" },
        },
    },
    ["Transmute: Primal Shadow to Water"] = {
        spellID = 28580,
        itemID = 21885,
        skillReq = 385,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 385, 385, 392, 400 },
        reagents = { { itemID = 22456, count = 1, name = "Primal Shadow" } },
    },
    ["Transmute: Primal Water to Air"] = {
        spellID = 28569,
        itemID = 22451,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Honored" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 350, 365, 372, 380 },
        reagents = { { itemID = 21885, count = 1, name = "Primal Water" } },
    },
    ["Transmute: Primal Water to Shadow"] = {
        spellID = 28581,
        itemID = 22456,
        skillReq = 385,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Transmute",
        subcategory = "Primal",
        skillRange = { 385, 385, 392, 400 },
        reagents = { { itemID = 21885, count = 1, name = "Primal Water" } },
    },

    -- ================================================================
    -- TRINKET
    -- ================================================================
    ["Alchemist's Stone"] = {
        spellID = 17632,
        itemID = 13503,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Honored" },
        },
        category = "Trinket",
        skillRange = { 300, 365, 372, 380 },
        reagents = {
            { itemID = 9149, count = 1, name = "Philosopher's Stone" },
            { itemID = 25867, count = 1, name = "Earthstorm Diamond" },
            { itemID = 25868, count = 1, name = "Skyfire Diamond" },
            { itemID = 22794, count = 2, name = "Fel Lotus" },
            { itemID = 23571, count = 5, name = "Primal Might" },
        },
    },
    ["Assassin's Alchemist Stone"] = {
        spellID = 47050,
        itemID = 35751,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "Shattered Sun Offensive @ Revered" },
        },
        category = "Trinket",
        skillRange = { 375, 390, 397, 405 },
        reagents = {
            { itemID = 13503, count = 1, name = "Alchemist's Stone" },
            { itemID = 22456, count = 6, name = "Primal Shadow" },
            { itemID = 30183, count = 2, name = "Nether Vortex" },
        },
    },
    ["Guardian's Alchemist Stone"] = {
        spellID = 47046,
        itemID = 35748,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "Shattered Sun Offensive @ Revered" },
        },
        category = "Trinket",
        skillRange = { 375, 390, 397, 405 },
        reagents = {
            { itemID = 13503, count = 1, name = "Alchemist's Stone" },
            { itemID = 22451, count = 6, name = "Primal Air" },
            { itemID = 30183, count = 2, name = "Nether Vortex" },
        },
    },
    ["Mad Alchemist's Potion"] = {
        spellID = 45061,
        itemID = 34440,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 325, 335, 342, 350 },
        reagents = {
            { itemID = 8925, count = 1, name = "Crystal Vial" },
            { itemID = 22787, count = 2, name = "Ragveil" },
        },
    },
    ["Mercurial Stone"] = {
        spellID = 38070,
        itemID = 31080,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 325, 340, 347, 355 },
        reagents = {
            { itemID = 22452, count = 1, name = "Primal Earth" },
            { itemID = 21886, count = 1, name = "Primal Life" },
            { itemID = 22457, count = 1, name = "Primal Mana" },
        },
    },
    ["Philosopher's Stone"] = {
        spellID = 11459,
        itemID = 9149,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "vendor", faction = "Both", detail = "Sold by Alchemist Pestlezugg" },
        },
        category = "Trinket",
        skillRange = { 225, 240, 260, 280 },
        reagents = {
            { itemID = 3575, count = 4, name = "Iron Bar" },
            { itemID = 9262, count = 1, name = "Black Vitriol" },
            { itemID = 8831, count = 4, name = "Purple Lotus" },
            { itemID = 4625, count = 4, name = "Firebloom" },
        },
    },
    ["Redeemer's Alchemist Stone"] = {
        spellID = 47049,
        itemID = 35750,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "Shattered Sun Offensive @ Revered" },
        },
        category = "Trinket",
        skillRange = { 375, 390, 397, 405 },
        reagents = {
            { itemID = 13503, count = 1, name = "Alchemist's Stone" },
            { itemID = 21886, count = 6, name = "Primal Life" },
            { itemID = 30183, count = 2, name = "Nether Vortex" },
        },
    },
    ["Sorcerer's Alchemist Stone"] = {
        spellID = 47048,
        itemID = 35749,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "Shattered Sun Offensive @ Revered" },
        },
        category = "Trinket",
        skillRange = { 375, 390, 397, 405 },
        reagents = {
            { itemID = 13503, count = 1, name = "Alchemist's Stone" },
            { itemID = 21884, count = 6, name = "Primal Fire" },
            { itemID = 30183, count = 2, name = "Nether Vortex" },
        },
    },

}

RDB:RegisterProfession("Alchemy", recipes)
