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
        itemID = 1251,
        skillReq = 1,
        source = "trainer",
        category = "Bandage",
        skillRange = {  1, 30, 45, 60 },
        reagents = {
            { itemID = 2589, count = 1, name = "Linen Cloth" },
        },
    },
    ["Heavy Linen Bandage"] = {
        itemID = 2581,
        skillReq = 40,
        source = "trainer",
        category = "Bandage",
        skillRange = {  40, 50, 75, 100 },
        reagents = {
            { itemID = 2589, count = 2, name = "Linen Cloth" },
        },
    },
    ["Wool Bandage"] = {
        itemID = 3530,
        skillReq = 80,
        source = "trainer",
        category = "Bandage",
        skillRange = {  80, 80, 115, 150 },
        reagents = {
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["Heavy Wool Bandage"] = {
        itemID = 3531,
        skillReq = 115,
        source = "trainer",
        category = "Bandage",
        skillRange = {  115, 115, 150, 185 },
        reagents = {
            { itemID = 2592, count = 2, name = "Wool Cloth" },
        },
    },
    ["Silk Bandage"] = {
        itemID = 6450,
        skillReq = 150,
        source = "trainer",
        category = "Bandage",
        skillRange = {  150, 150, 180, 210 },
        reagents = {
            { itemID = 4306, count = 1, name = "Silk Cloth" },
        },
    },
    ["Heavy Silk Bandage"] = {
        itemID = 6451,
        skillReq = 180,
        source = "trainer",
        category = "Bandage",
        skillRange = {  180, 180, 210, 240 },
        reagents = {
            { itemID = 4306, count = 2, name = "Silk Cloth" },
        },
    },
    ["Mageweave Bandage"] = {
        itemID = 8544,
        skillReq = 225,
        source = "trainer",
        category = "Bandage",
        skillRange = {  225, 210, 240, 270 },
        reagents = {
            { itemID = 4338, count = 1, name = "Mageweave Cloth" },
        },
    },
    ["Heavy Mageweave Bandage"] = {
        itemID = 8545,
        skillReq = 240,
        source = "trainer",
        category = "Bandage",
        skillRange = {  240, 240, 270, 300 },
        reagents = {
            { itemID = 4338, count = 2, name = "Mageweave Cloth" },
        },
    },
    ["Runecloth Bandage"] = {
        itemID = 14529,
        skillReq = 260,
        source = "trainer",
        category = "Bandage",
        skillRange = {  260, 260, 290, 320 },
        reagents = {
            { itemID = 14047, count = 1, name = "Runecloth" },
        },
    },
    ["Heavy Runecloth Bandage"] = {
        itemID = 14530,
        skillReq = 290,
        source = "trainer",
        category = "Bandage",
        skillRange = {  290, 290, 320, 350 },
        reagents = {
            { itemID = 14047, count = 2, name = "Runecloth" },
        },
    },
    ["Netherweave Bandage"] = {
        itemID = 21990,
        skillReq = 330,
        source = "vendor",
        sourceDetail = "Burko (A) / Aresella (H), Hellfire Peninsula",
        category = "Bandage",
        skillRange = {  330, 330, 360, 390 },
        reagents = {
            { itemID = 21877, count = 1, name = "Netherweave Cloth" },
        },
    },
    ["Heavy Netherweave Bandage"] = {
        itemID = 21991,
        skillReq = 350,
        source = "vendor",
        sourceDetail = "Burko (A) / Aresella (H), Hellfire Peninsula",
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
        itemID = 6452,
        skillReq = 80,
        source = "trainer",
        category = "Anti-Venom",
        skillRange = {  80, 80, 115, 150 },
        reagents = {
            { itemID = 1475, count = 1, name = "Small Venom Sac" },
        },
    },
    ["Strong Anti-Venom"] = {
        itemID = 6453,
        skillReq = 130,
        source = "drop",
        category = "Anti-Venom",
        skillRange = {  130, 130, 165, 200 },
        reagents = {
            { itemID = 1288, count = 1, name = "Large Venom Sac" },
        },
    },
    ["Powerful Anti-Venom"] = {
        itemID = 19440,
        skillReq = 300,
        source = "vendor",
        sourceDetail = "QM Miranda Breechlock, Eastern Plaguelands",
        category = "Anti-Venom",
        skillRange = {  300, 300, 330, 360 },
        reagents = {
            { itemID = 19441, count = 1, name = "Huge Venom Sac" },
        },
    },

}

RDB:RegisterProfession("First Aid", recipes)
