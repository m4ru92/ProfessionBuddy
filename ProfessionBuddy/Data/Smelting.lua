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
        spellID = 2657,
        itemID = 2840,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  1, 25, 47, 70 },
        reagents = {
            { itemID = 2770, count = 1, name = "Copper Ore" },
        },
    },
    ["Smelt Tin"] = {
        spellID = 3304,
        itemID = 3576,
        skillReq = 65,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  65, 65, 70, 75 },
        reagents = {
            { itemID = 2771, count = 1, name = "Tin Ore" },
        },
    },
    ["Smelt Bronze"] = {
        spellID = 2659,
        itemID = 2841,
        skillReq = 65,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  65, 65, 90, 115 },
        yield = 2,
        reagents = {
            { itemID = 2840, count = 1, name = "Copper Bar" },
            { itemID = 3576, count = 1, name = "Tin Bar" },
        },
    },
    ["Smelt Silver"] = {
        spellID = 2658,
        itemID = 2842,
        skillReq = 75,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  75, 115, 122, 130 },
        reagents = {
            { itemID = 2775, count = 1, name = "Silver Ore" },
        },
    },
    ["Smelt Iron"] = {
        spellID = 3307,
        itemID = 3575,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  125, 130, 145, 160 },
        reagents = {
            { itemID = 2772, count = 1, name = "Iron Ore" },
        },
    },
    ["Smelt Gold"] = {
        spellID = 3308,
        itemID = 3577,
        skillReq = 155,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  155, 170, 177, 185 },
        reagents = {
            { itemID = 2776, count = 1, name = "Gold Ore" },
        },
    },
    ["Smelt Steel"] = {
        spellID = 3569,
        itemID = 3859,
        skillReq = 165,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  165, 165, 165, 165 },
        reagents = {
            { itemID = 3575, count = 1, name = "Iron Bar" },
            { itemID = 3857, count = 1, name = "Coal" },
        },
    },
    ["Smelt Mithril"] = {
        spellID = 10097,
        itemID = 3860,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  175, 175, 202, 230 },
        reagents = {
            { itemID = 3858, count = 1, name = "Mithril Ore" },
        },
    },
    ["Smelt Truesilver"] = {
        spellID = 10098,
        itemID = 6037,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  230, 235, 242, 250 },
        reagents = {
            { itemID = 7911, count = 1, name = "Truesilver Ore" },
        },
    },
    ["Smelt Thorium"] = {
        spellID = 16153,
        itemID = 12359,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Classic Bar",
        skillRange = {  250, 250, 270, 290 },
        reagents = {
            { itemID = 10620, count = 1, name = "Thorium Ore" },
        },
    },
    ["Smelt Dark Iron"] = {
        spellID = 14891,
        itemID = 11371,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Classic Bar",
        skillRange = {  230, 300, 305, 310 },
        reagents = {
            { itemID = 11370, count = 8, name = "Dark Iron Ore" },
        },
    },
    ["Smelt Elementium"] = {
        spellID = 22967,
        itemID = 17771,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
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
        spellID = 29356,
        itemID = 23445,
        skillReq = 275,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Outland Bar",
        skillRange = {  275, 300, 307, 315 },
        reagents = {
            { itemID = 23424, count = 2, name = "Fel Iron Ore" },
        },
    },
    ["Smelt Adamantite"] = {
        spellID = 29358,
        itemID = 23446,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Outland Bar",
        skillRange = {  325, 325, 332, 340 },
        reagents = {
            { itemID = 23425, count = 2, name = "Adamantite Ore" },
        },
    },
    ["Smelt Eternium"] = {
        spellID = 29359,
        itemID = 23447,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Outland Bar",
        skillRange = {  350, 350, 357, 365 },
        reagents = {
            { itemID = 23427, count = 2, name = "Eternium Ore" },
        },
    },
    ["Smelt Felsteel"] = {
        spellID = 29360,
        itemID = 23448,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Outland Bar",
        skillRange = {  350, 355, 367, 380 },
        reagents = {
            { itemID = 23445, count = 3, name = "Fel Iron Bar" },
            { itemID = 23447, count = 2, name = "Eternium Bar" },
        },
    },
    ["Smelt Khorium"] = {
        spellID = 29361,
        itemID = 23449,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Outland Bar",
        skillRange = {  375, 375, 375, 375 },
        reagents = {
            { itemID = 23426, count = 2, name = "Khorium Ore" },
        },
    },
    ["Smelt Hardened Adamantite"] = {
        spellID = 29686,
        itemID = 23573,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
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
        spellID = 35750,
        itemID = 22573,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Transmute",
        skillRange = {  300, 300, 300, 300 },
        reagents = {
            { itemID = 22452, count = 1, name = "Primal Earth" },
        },
    },
    ["Fire Sunder"] = {
        spellID = 35751,
        itemID = 22574,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Transmute",
        skillRange = {  300, 300, 300, 300 },
        reagents = {
            { itemID = 21884, count = 1, name = "Primal Fire" },
        },
    },

}

RDB:RegisterProfession("Smelting", recipes)
