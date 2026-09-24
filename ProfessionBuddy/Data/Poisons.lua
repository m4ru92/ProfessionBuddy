----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Poisons.lua
-- Static recipe database for Poisons (rogue only, TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
--   orange = SkillLineAbility.MinSkillLineRank (1 for every poison)
--   yellow = SkillLineAbility.TrivialSkillLineRankLow
--   grey   = SkillLineAbility.TrivialSkillLineRankHigh
--   green  = floor((yellow + grey) / 2)
-- Recipes, reagents and ranges: client DB2, build 2.5.6.69110.
-- Learn levels and sources: rogue trainers teach every poison by CHARACTER
-- level with no Poisons skill requirement, so skillReq is 1 and the level
-- lives in reqLevel. Instant Poison comes with the Poisons skill itself.
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- INSTANT POISON
    -- ================================================================
    ["Instant Poison"] = {
        spellID = 8681,
        itemID = 6947,
        skillReq = 1,
        reqLevel = 20,
        sources = {
            { method = "automatic", faction = "Both", detail = "Learned with Poisons (level 20 rogue quest)" },
        },
        category = "Instant Poison",
        skillRange = {  1, 125, 150, 175 },
        reagents = {
            { itemID = 2928, count = 1, name = "Dust of Decay" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Instant Poison II"] = {
        spellID = 8687,
        itemID = 6949,
        skillReq = 1,
        reqLevel = 28,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 28" },
        },
        category = "Instant Poison",
        skillRange = {  1, 165, 190, 215 },
        reagents = {
            { itemID = 2928, count = 1, name = "Dust of Decay" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Instant Poison III"] = {
        spellID = 8691,
        itemID = 6950,
        skillReq = 1,
        reqLevel = 36,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 36" },
        },
        category = "Instant Poison",
        skillRange = {  1, 205, 230, 255 },
        reagents = {
            { itemID = 8924, count = 2, name = "Dust of Deterioration" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Instant Poison IV"] = {
        spellID = 11341,
        itemID = 8926,
        skillReq = 1,
        reqLevel = 44,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 44" },
        },
        category = "Instant Poison",
        skillRange = {  1, 245, 270, 295 },
        reagents = {
            { itemID = 8924, count = 1, name = "Dust of Deterioration" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Instant Poison V"] = {
        spellID = 11342,
        itemID = 8927,
        skillReq = 1,
        reqLevel = 52,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 52" },
        },
        category = "Instant Poison",
        skillRange = {  1, 285, 310, 335 },
        reagents = {
            { itemID = 8924, count = 2, name = "Dust of Deterioration" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Instant Poison VI"] = {
        spellID = 11343,
        itemID = 8928,
        skillReq = 1,
        reqLevel = 60,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 60" },
        },
        category = "Instant Poison",
        skillRange = {  1, 325, 350, 375 },
        reagents = {
            { itemID = 8924, count = 2, name = "Dust of Deterioration" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Instant Poison VII"] = {
        spellID = 26892,
        itemID = 21927,
        skillReq = 1,
        reqLevel = 68,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 68" },
        },
        category = "Instant Poison",
        skillRange = {  1, 365, 390, 415 },
        reagents = {
            { itemID = 2931, count = 1, name = "Maiden's Anguish" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- DEADLY POISON
    -- ================================================================
    ["Deadly Poison"] = {
        spellID = 2835,
        itemID = 2892,
        skillReq = 1,
        reqLevel = 30,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 30" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 175, 200, 225 },
        reagents = {
            { itemID = 5173, count = 1, name = "Deathweed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Deadly Poison II"] = {
        spellID = 2837,
        itemID = 2893,
        skillReq = 1,
        reqLevel = 38,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 38" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 215, 240, 265 },
        reagents = {
            { itemID = 5173, count = 2, name = "Deathweed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Deadly Poison III"] = {
        spellID = 11357,
        itemID = 8984,
        skillReq = 1,
        reqLevel = 46,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 46" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 255, 280, 305 },
        reagents = {
            { itemID = 5173, count = 1, name = "Deathweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Deadly Poison IV"] = {
        spellID = 11358,
        itemID = 8985,
        skillReq = 1,
        reqLevel = 54,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 54" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 295, 320, 345 },
        reagents = {
            { itemID = 5173, count = 2, name = "Deathweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Deadly Poison V"] = {
        spellID = 25347,
        itemID = 20844,
        skillReq = 1,
        reqLevel = 60,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 60" },
            { method = "drop", faction = "Both", detail = "Handbook of Deadly Poison V, Ruins of Ahn'Qiraj bosses" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 300, 325, 350 },
        reagents = {
            { itemID = 5173, count = 2, name = "Deathweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Deadly Poison VI"] = {
        spellID = 26969,
        itemID = 22053,
        skillReq = 1,
        reqLevel = 62,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 62" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 345, 365, 385 },
        reagents = {
            { itemID = 2931, count = 1, name = "Maiden's Anguish" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Deadly Poison VII"] = {
        spellID = 27282,
        itemID = 22054,
        skillReq = 1,
        reqLevel = 70,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 70" },
        },
        category = "Deadly Poison",
        skillRange = {  1, 385, 405, 425 },
        reagents = {
            { itemID = 2931, count = 1, name = "Maiden's Anguish" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- WOUND POISON
    -- ================================================================
    ["Wound Poison"] = {
        spellID = 13220,
        itemID = 10918,
        skillReq = 1,
        reqLevel = 32,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 32" },
        },
        category = "Wound Poison",
        skillRange = {  1, 185, 210, 235 },
        reagents = {
            { itemID = 2930, count = 1, name = "Essence of Pain" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Wound Poison II"] = {
        spellID = 13228,
        itemID = 10920,
        skillReq = 1,
        reqLevel = 40,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 40" },
        },
        category = "Wound Poison",
        skillRange = {  1, 225, 250, 275 },
        reagents = {
            { itemID = 2930, count = 1, name = "Essence of Pain" },
            { itemID = 5173, count = 1, name = "Deathweed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Wound Poison III"] = {
        spellID = 13229,
        itemID = 10921,
        skillReq = 1,
        reqLevel = 48,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 48" },
        },
        category = "Wound Poison",
        skillRange = {  1, 265, 290, 315 },
        reagents = {
            { itemID = 8923, count = 1, name = "Essence of Agony" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Wound Poison IV"] = {
        spellID = 13230,
        itemID = 10922,
        skillReq = 1,
        reqLevel = 56,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 56" },
        },
        category = "Wound Poison",
        skillRange = {  1, 305, 330, 355 },
        reagents = {
            { itemID = 8923, count = 1, name = "Essence of Agony" },
            { itemID = 5173, count = 1, name = "Deathweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Wound Poison V"] = {
        spellID = 27283,
        itemID = 22055,
        skillReq = 1,
        reqLevel = 64,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 64" },
        },
        category = "Wound Poison",
        skillRange = {  1, 345, 370, 395 },
        reagents = {
            { itemID = 8923, count = 2, name = "Essence of Agony" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- CRIPPLING POISON
    -- ================================================================
    ["Crippling Poison"] = {
        spellID = 3420,
        itemID = 3775,
        skillReq = 1,
        reqLevel = 20,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 20" },
        },
        category = "Crippling Poison",
        skillRange = {  1, 125, 150, 175 },
        reagents = {
            { itemID = 2930, count = 1, name = "Essence of Pain" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Crippling Poison II"] = {
        spellID = 3421,
        itemID = 3776,
        skillReq = 1,
        reqLevel = 50,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 50" },
        },
        category = "Crippling Poison",
        skillRange = {  1, 275, 300, 325 },
        reagents = {
            { itemID = 8923, count = 1, name = "Essence of Agony" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- MIND-NUMBING POISON
    -- ================================================================
    ["Mind-numbing Poison"] = {
        spellID = 5763,
        itemID = 5237,
        skillReq = 1,
        reqLevel = 24,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 24" },
        },
        category = "Mind-numbing Poison",
        skillRange = {  1, 150, 175, 200 },
        reagents = {
            { itemID = 2928, count = 1, name = "Dust of Decay" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Mind-numbing Poison II"] = {
        spellID = 8694,
        itemID = 6951,
        skillReq = 1,
        reqLevel = 38,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 38" },
        },
        category = "Mind-numbing Poison",
        skillRange = {  1, 215, 240, 265 },
        reagents = {
            { itemID = 8923, count = 1, name = "Essence of Agony" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Mind-numbing Poison III"] = {
        spellID = 11400,
        itemID = 9186,
        skillReq = 1,
        reqLevel = 52,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 52" },
        },
        category = "Mind-numbing Poison",
        skillRange = {  1, 285, 310, 335 },
        reagents = {
            { itemID = 8923, count = 1, name = "Essence of Agony" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- ANESTHETIC POISON
    -- ================================================================
    ["Anesthetic Poison"] = {
        spellID = 26786,
        itemID = 21835,
        skillReq = 1,
        reqLevel = 68,
        sources = {
            { method = "trainer", faction = "Both", detail = "Rogue trainer, level 68" },
        },
        category = "Anesthetic Poison",
        skillRange = {  1, 340, 355, 370 },
        reagents = {
            { itemID = 2931, count = 1, name = "Maiden's Anguish" },
            { itemID = 5173, count = 1, name = "Deathweed" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

}

RDB:RegisterProfession("Poisons", recipes)
