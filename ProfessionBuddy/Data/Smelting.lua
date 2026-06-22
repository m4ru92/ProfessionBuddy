----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Smelting.lua
-- Static recipe database for Smelting (TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
-- Item IDs verified against Wowhead TBC Classic spell/item pages.
-- Skill levels sourced from warcraft.wiki.gg Smelting article.
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- CLASSIC BAR
    -- ================================================================
    ["Smelt Copper"] = {
        itemID = 2840,
        skillReq = 1,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  1, 25, 47, 70 },
        reagents = {
            { itemID = 2770, count = 1, name = "Copper Ore" },
        },
    },
    ["Smelt Tin"] = {
        itemID = 3576,
        skillReq = 65,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  65, 65, 70, 75 },
        reagents = {
            { itemID = 2771, count = 1, name = "Tin Ore" },
        },
    },
    ["Smelt Bronze"] = {
        itemID = 2841,
        skillReq = 65,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  65, 65, 90, 115 },
        yield = 2,
        reagents = {
            { itemID = 2840, count = 1, name = "Copper Bar" },
            { itemID = 3576, count = 1, name = "Tin Bar" },
        },
    },
    ["Smelt Silver"] = {
        itemID = 2842,
        skillReq = 75,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  75, 115, 122, 130 },
        reagents = {
            { itemID = 2775, count = 1, name = "Silver Ore" },
        },
    },
    ["Smelt Iron"] = {
        itemID = 3575,
        skillReq = 125,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  125, 130, 145, 160 },
        reagents = {
            { itemID = 2772, count = 1, name = "Iron Ore" },
        },
    },
    ["Smelt Gold"] = {
        itemID = 3577,
        skillReq = 155,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  155, 170, 177, 185 },
        reagents = {
            { itemID = 2776, count = 1, name = "Gold Ore" },
        },
    },
    ["Smelt Steel"] = {
        itemID = 3859,
        skillReq = 165,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  165, 165, 165, 165 },
        reagents = {
            { itemID = 3575, count = 1, name = "Iron Bar" },
            { itemID = 3857, count = 1, name = "Coal" },
        },
    },
    ["Smelt Mithril"] = {
        itemID = 3860,
        skillReq = 175,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  175, 175, 202, 230 },
        reagents = {
            { itemID = 3858, count = 1, name = "Mithril Ore" },
        },
    },
    ["Smelt Truesilver"] = {
        itemID = 6037,
        skillReq = 230,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  230, 235, 242, 250 },
        reagents = {
            { itemID = 7911, count = 1, name = "Truesilver Ore" },
        },
    },
    ["Smelt Thorium"] = {
        itemID = 12359,
        skillReq = 250,
        source = "trainer",
        category = "Classic Bar",
        skillRange = {  250, 250, 270, 290 },
        reagents = {
            { itemID = 10620, count = 1, name = "Thorium Ore" },
        },
    },
    ["Smelt Dark Iron"] = {
        itemID = 11371,
        skillReq = 230,
        source = "quest",
        category = "Classic Bar",
        skillRange = {  230, 300, 305, 310 },
        reagents = {
            { itemID = 11370, count = 8, name = "Dark Iron Ore" },
        },
    },
    ["Smelt Elementium"] = {
        itemID = 17771,
        skillReq = 350,
        source = "drop",
        category = "Classic Bar",
        skillRange = { 350, 350, 362, 375 },
        reagents = {
            { itemID = 18562, count = 1, name = "Elementium Ore" },
            { itemID = 12360, count = 10, name = "Arcanite Bar" },
            { itemID = 17010, count = 1, name = "Fiery Core" },
            { itemID = 18567, count = 3, name = "Elemental Flux" },
        },
    },
    -- NOTE: "Smelt Enchanted Thorium" intentionally NOT here -- it
    -- became a Mining/Smelting recipe only in WotLK 3.3.0. In TBC
    -- (2.5.x) Enchanted Thorium Bar is an ENCHANTING recipe; see the
    -- Enchanting data backlog item.

    -- ================================================================
    -- OUTLAND BAR
    -- ================================================================
    ["Smelt Fel Iron"] = {
        itemID = 23445,
        skillReq = 275,
        source = "trainer",
        category = "Outland Bar",
        skillRange = {  275, 300, 307, 315 },
        reagents = {
            { itemID = 23424, count = 2, name = "Fel Iron Ore" },
        },
    },
    ["Smelt Adamantite"] = {
        itemID = 23446,
        skillReq = 325,
        source = "trainer",
        category = "Outland Bar",
        skillRange = {  325, 325, 332, 340 },
        reagents = {
            { itemID = 23425, count = 2, name = "Adamantite Ore" },
        },
    },
    ["Smelt Eternium"] = {
        itemID = 23447,
        skillReq = 350,
        source = "trainer",
        category = "Outland Bar",
        skillRange = {  350, 350, 357, 365 },
        reagents = {
            { itemID = 23427, count = 2, name = "Eternium Ore" },
        },
    },
    ["Smelt Felsteel"] = {
        itemID = 23448,
        skillReq = 350,
        source = "trainer",
        category = "Outland Bar",
        skillRange = {  350, 355, 367, 380 },
        reagents = {
            { itemID = 23445, count = 3, name = "Fel Iron Bar" },
            { itemID = 23447, count = 2, name = "Eternium Bar" },
        },
    },
    ["Smelt Khorium"] = {
        itemID = 23449,
        skillReq = 375,
        source = "trainer",
        category = "Outland Bar",
        skillRange = {  375, 375, 375, 375 },
        reagents = {
            { itemID = 23426, count = 2, name = "Khorium Ore" },
        },
    },
    ["Smelt Hardened Adamantite"] = {
        itemID = 23573,
        skillReq = 375,
        source = "trainer",
        category = "Outland Bar",
        skillRange = {  375, 375, 375, 375 },
        reagents = {
            { itemID = 23446, count = 10, name = "Adamantite Bar" },
        },
    },

    -- ================================================================
    -- TRANSMUTE (Primal -> Motes, Mining-exclusive)
    -- ================================================================
    ["Earth Shatter"] = {
        itemID = 22573,
        skillReq = 300,
        source = "trainer",
        category = "Transmute",
        skillRange = {  300, 300, 300, 300 },
        reagents = {
            { itemID = 22452, count = 1, name = "Primal Earth" },
        },
    },
    ["Fire Sunder"] = {
        itemID = 22574,
        skillReq = 300,
        source = "trainer",
        category = "Transmute",
        skillRange = {  300, 300, 300, 300 },
        reagents = {
            { itemID = 21884, count = 1, name = "Primal Fire" },
        },
    },

}

RDB:RegisterProfession("Smelting", recipes)
