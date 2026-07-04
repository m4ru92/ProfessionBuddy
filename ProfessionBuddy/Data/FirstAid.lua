----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/FirstAid.lua
-- Static recipe database for First Aid (TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
-- Item IDs verified against Wowhead TBC Classic spell/item pages.
-- Skill levels sourced from warcraft.wiki.gg First Aid article.
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- BANDAGE
    -- ================================================================
    ["Linen Bandage"] = {
        spellID = 3275,
        itemID = 1251,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  1, 30, 45, 60 },
        reagents = {
            { itemID = 2589, count = 1, name = "Linen Cloth" },
        },
    },
    ["Heavy Linen Bandage"] = {
        spellID = 3276,
        itemID = 2581,
        skillReq = 40,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  40, 50, 75, 100 },
        reagents = {
            { itemID = 2589, count = 2, name = "Linen Cloth" },
        },
    },
    ["Wool Bandage"] = {
        spellID = 3277,
        itemID = 3530,
        skillReq = 80,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  80, 80, 115, 150 },
        reagents = {
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["Heavy Wool Bandage"] = {
        spellID = 3278,
        itemID = 3531,
        skillReq = 115,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  115, 115, 150, 185 },
        reagents = {
            { itemID = 2592, count = 2, name = "Wool Cloth" },
        },
    },
    ["Silk Bandage"] = {
        spellID = 7928,
        itemID = 6450,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  150, 150, 180, 210 },
        reagents = {
            { itemID = 4306, count = 1, name = "Silk Cloth" },
        },
    },
    ["Heavy Silk Bandage"] = {
        spellID = 7929,
        itemID = 6451,
        skillReq = 180,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Balai Lok\'Wein, Deneb Walker" },
        },
        category = "Bandage",
        skillRange = {  180, 180, 210, 240 },
        reagents = {
            { itemID = 4306, count = 2, name = "Silk Cloth" },
        },
    },
    ["Mageweave Bandage"] = {
        spellID = 10840,
        itemID = 8544,
        skillReq = 225,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Balai Lok\'Wein, Deneb Walker" },
        },
        category = "Bandage",
        skillRange = {  210, 210, 240, 270},
        reagents = {
            { itemID = 4338, count = 1, name = "Mageweave Cloth" },
        },
    },
    ["Heavy Mageweave Bandage"] = {
        spellID = 10841,
        itemID = 8545,
        skillReq = 240,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  240, 240, 270, 300 },
        reagents = {
            { itemID = 4338, count = 2, name = "Mageweave Cloth" },
        },
    },
    ["Runecloth Bandage"] = {
        spellID = 18629,
        itemID = 14529,
        skillReq = 260,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  260, 260, 290, 320 },
        reagents = {
            { itemID = 14047, count = 1, name = "Runecloth" },
        },
    },
    ["Heavy Runecloth Bandage"] = {
        spellID = 18630,
        itemID = 14530,
        skillReq = 290,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  290, 290, 320, 350 },
        reagents = {
            { itemID = 14047, count = 2, name = "Runecloth" },
        },
    },
    ["Netherweave Bandage"] = {
        spellID = 27032,
        itemID = 21990,
        skillReq = 330,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  330, 330, 360, 390 },
        reagents = {
            { itemID = 21877, count = 1, name = "Netherweave Cloth" },
        },
    },
    ["Heavy Netherweave Bandage"] = {
        spellID = 27033,
        itemID = 21991,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Bandage",
        skillRange = {  350, 360, 385, 410 },
        reagents = {
            { itemID = 21877, count = 2, name = "Netherweave Cloth" },
        },
    },

    -- ================================================================
    -- ANTI-VENOM
    -- ================================================================
    ["Anti-Venom"] = {
        spellID = 7934,
        itemID = 6452,
        skillReq = 80,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Anti-Venom",
        skillRange = {  80, 80, 115, 150 },
        reagents = {
            { itemID = 1475, count = 1, name = "Small Venom Sac" },
        },
    },
    ["Strong Anti-Venom"] = {
        spellID = 7935,
        itemID = 6453,
        skillReq = 130,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Anti-Venom",
        skillRange = {  130, 130, 165, 200 },
        reagents = {
            { itemID = 1288, count = 1, name = "Large Venom Sac" },
        },
    },
    ["Powerful Anti-Venom"] = {
        spellID = 23787,
        itemID = 19440,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Argent Dawn @ Friendly" },
        },
        category = "Anti-Venom",
        skillRange = {  300, 300, 330, 360 },
        reagents = {
            { itemID = 19441, count = 1, name = "Huge Venom Sac" },
        },
    },

}

RDB:RegisterProfession("First Aid", recipes)
