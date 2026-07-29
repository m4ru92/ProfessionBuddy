----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Enchanting.lua
-- Static recipe database for Enchanting (TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
-- Values sourced from SkillLineAbility + SpellReagents + Item DB2 (build 2.5.4.44833)
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- ENCHANT
    -- ================================================================

    -- ================================================================
    -- ENCHANT BOOTS
    -- ================================================================
    ["Enchant Boots - Agility"] = {
        spellID = 13935,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 235,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  235, 255, 275, 295 },
        reagents = { { itemID = 11175, count = 2, name = "Greater Nether Essence" } },
    },
    ["Enchant Boots - Boar's Speed"] = {
        spellID = 34008,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 22452, count = 8, name = "Primal Earth" },
        },
    },
    ["Enchant Boots - Cat's Swiftness"] = {
        spellID = 34007,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 22451, count = 8, name = "Primal Air" },
        },
    },
    ["Enchant Boots - Dexterity"] = {
        spellID = 27951,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 340,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  340, 350, 365, 380 },
        reagents = {
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 22445, count = 8, name = "Arcane Dust" },
        },
    },
    ["Enchant Boots - Fortitude"] = {
        spellID = 27950,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 320,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  320, 330, 345, 360 },
        reagents = { { itemID = 22445, count = 12, name = "Arcane Dust" } },
    },
    ["Enchant Boots - Greater Agility"] = {
        spellID = 20023,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 295,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  295, 310, 325, 340 },
        reagents = { { itemID = 16203, count = 8, name = "Greater Eternal Essence" } },
    },
    ["Enchant Boots - Greater Stamina"] = {
        spellID = 20020,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 260,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  260, 280, 300, 320 },
        reagents = { { itemID = 11176, count = 10, name = "Dream Dust" } },
    },
    ["Enchant Boots - Lesser Agility"] = {
        spellID = 13637,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 160,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  160, 180, 200, 220 },
        reagents = {
            { itemID = 11083, count = 1, name = "Soul Dust" },
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
        },
    },
    ["Enchant Boots - Lesser Spirit"] = {
        spellID = 13687,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 190,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  190, 210, 230, 250 },
        reagents = {
            { itemID = 11135, count = 1, name = "Greater Mystic Essence" },
            { itemID = 11134, count = 2, name = "Lesser Mystic Essence" },
        },
    },
    ["Enchant Boots - Lesser Stamina"] = {
        spellID = 13644,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 170,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  170, 190, 210, 230 },
        reagents = { { itemID = 11083, count = 4, name = "Soul Dust" } },
    },
    ["Enchant Boots - Minor Agility"] = {
        spellID = 7867,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 125,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Nata Dawnstrider, Zixil" },
        },
        category = "Enchant Boots",
        skillRange = {  125, 150, 170, 190 },
        reagents = {
            { itemID = 10940, count = 6, name = "Strange Dust" },
            { itemID = 10998, count = 2, name = "Lesser Astral Essence" },
        },
    },
    ["Enchant Boots - Minor Speed"] = {
        spellID = 13890,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  225, 245, 265, 285 },
        reagents = {
            { itemID = 11177, count = 1, name = "Small Radiant Shard" },
            { itemID = 7909, count = 1, name = "Aquamarine" },
            { itemID = 11174, count = 1, name = "Lesser Nether Essence" },
        },
    },
    ["Enchant Boots - Minor Stamina"] = {
        spellID = 7863,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  125, 150, 170, 190 },
        reagents = { { itemID = 10940, count = 8, name = "Strange Dust" } },
    },
    ["Enchant Boots - Spirit"] = {
        spellID = 20024,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  275, 295, 315, 335 },
        reagents = {
            { itemID = 16203, count = 2, name = "Greater Eternal Essence" },
            { itemID = 16202, count = 1, name = "Lesser Eternal Essence" },
        },
    },
    ["Enchant Boots - Stamina"] = {
        spellID = 13836,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  215, 235, 255, 275 },
        reagents = { { itemID = 11137, count = 5, name = "Vision Dust" } },
    },
    ["Enchant Boots - Surefooted"] = {
        spellID = 27954,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 370,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  370, 380, 395, 410 },
        reagents = {
            { itemID = 22450, count = 2, name = "Void Crystal" },
            { itemID = 22449, count = 4, name = "Large Prismatic Shard" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
        },
    },
    ["Enchant Boots - Vitality"] = {
        spellID = 27948,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 305,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Boots",
        skillRange = {  305, 315, 330, 345 },
        reagents = {
            { itemID = 22445, count = 6, name = "Arcane Dust" },
            { itemID = 13446, count = 4, name = "Major Healing Potion" },
            { itemID = 13444, count = 4, name = "Major Mana Potion" },
        },
    },

    -- ================================================================
    -- ENCHANT BRACER
    -- ================================================================
    ["Enchant Bracer - Assault"] = {
        spellID = 34002,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  300, 310, 325, 340 },
        reagents = { { itemID = 22445, count = 6, name = "Arcane Dust" } },
    },
    ["Enchant Bracer - Brawn"] = {
        spellID = 27899,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 305,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  305, 315, 330, 345 },
        reagents = { { itemID = 22445, count = 6, name = "Arcane Dust" } },
    },
    ["Enchant Bracer - Deflection"] = {
        spellID = 13931,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 235,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Banalash, Mythrin\'dir" },
        },
        category = "Enchant Bracer",
        skillRange = {  235, 255, 275, 295 },
        reagents = {
            { itemID = 11175, count = 1, name = "Greater Nether Essence" },
            { itemID = 11176, count = 2, name = "Dream Dust" },
        },
    },
    ["Enchant Bracer - Fortitude"] = {
        spellID = 27914,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 1, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 10, name = "Greater Planar Essence" },
            { itemID = 22445, count = 20, name = "Arcane Dust" },
        },
    },
    ["Enchant Bracer - Greater Intellect"] = {
        spellID = 20008,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 255,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  255, 275, 295, 315 },
        reagents = { { itemID = 16202, count = 3, name = "Lesser Eternal Essence" } },
    },
    ["Enchant Bracer - Greater Spirit"] = {
        spellID = 13846,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 220,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  220, 240, 260, 280 },
        reagents = {
            { itemID = 11174, count = 3, name = "Lesser Nether Essence" },
            { itemID = 11137, count = 1, name = "Vision Dust" },
        },
    },
    ["Enchant Bracer - Greater Stamina"] = {
        spellID = 13945,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 245,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  245, 265, 285, 305 },
        reagents = { { itemID = 11176, count = 5, name = "Dream Dust" } },
    },
    ["Enchant Bracer - Greater Strength"] = {
        spellID = 13939,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 240,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  240, 260, 280, 300 },
        reagents = {
            { itemID = 11176, count = 2, name = "Dream Dust" },
            { itemID = 11175, count = 1, name = "Greater Nether Essence" },
        },
    },
    ["Enchant Bracer - Healing Power"] = {
        spellID = 23802,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Argent Dawn @ Honored" },
        },
        category = "Enchant Bracer",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
            { itemID = 16204, count = 20, name = "Illusion Dust" },
            { itemID = 16203, count = 4, name = "Greater Eternal Essence" },
            { itemID = 12803, count = 6, name = "Living Essence" },
        },
    },
    ["Enchant Bracer - Intellect"] = {
        spellID = 13822,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 210,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  210, 230, 250, 270 },
        reagents = { { itemID = 11174, count = 2, name = "Lesser Nether Essence" } },
    },
    ["Enchant Bracer - Lesser Deflection"] = {
        spellID = 13646,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 170,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Keena, Micha Yance" },
        },
        category = "Enchant Bracer",
        skillRange = {  170, 190, 210, 230 },
        reagents = {
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
            { itemID = 11083, count = 2, name = "Soul Dust" },
        },
    },
    ["Enchant Bracer - Lesser Intellect"] = {
        spellID = 13622,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  150, 175, 195, 215 },
        reagents = { { itemID = 11082, count = 2, name = "Greater Astral Essence" } },
    },
    ["Enchant Bracer - Lesser Spirit"] = {
        spellID = 7859,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 120,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  120, 145, 165, 185 },
        reagents = { { itemID = 10998, count = 2, name = "Lesser Astral Essence" } },
    },
    ["Enchant Bracer - Lesser Stamina"] = {
        spellID = 13501,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 130,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  130, 155, 175, 195 },
        reagents = { { itemID = 11083, count = 2, name = "Soul Dust" } },
    },
    ["Enchant Bracer - Lesser Strength"] = {
        spellID = 13536,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 140,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Dalria, Kulwia" },
        },
        category = "Enchant Bracer",
        skillRange = {  140, 165, 185, 205 },
        reagents = { { itemID = 11083, count = 2, name = "Soul Dust" } },
    },
    ["Enchant Bracer - Major Defense"] = {
        spellID = 27906,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 320,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  320, 330, 345, 360 },
        reagents = {
            { itemID = 22448, count = 2, name = "Small Prismatic Shard" },
            { itemID = 22445, count = 10, name = "Arcane Dust" },
        },
    },
    ["Enchant Bracer - Major Intellect"] = {
        spellID = 34001,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 305,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  305, 315, 330, 345 },
        reagents = { { itemID = 22447, count = 3, name = "Lesser Planar Essence" } },
    },
    ["Enchant Bracer - Mana Regeneration"] = {
        spellID = 23801,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 290,
        sources = {
            { method = "reputation", faction = "Both", detail = "Argent Dawn @ Friendly" },
        },
        category = "Enchant Bracer",
        skillRange = {  290, 305, 322, 340 },
        reagents = {
            { itemID = 16204, count = 16, name = "Illusion Dust" },
            { itemID = 16203, count = 4, name = "Greater Eternal Essence" },
            { itemID = 7080, count = 2, name = "Essence of Water" },
        },
    },
    ["Enchant Bracer - Minor Agility"] = {
        spellID = 7779,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 80,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  80, 115, 135, 155 },
        reagents = {
            { itemID = 10940, count = 2, name = "Strange Dust" },
            { itemID = 10939, count = 1, name = "Greater Magic Essence" },
        },
    },
    ["Enchant Bracer - Minor Deflection"] = {
        spellID = 7428,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 75,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  75, 80, 100, 120 },
        reagents = {
            { itemID = 10938, count = 1, name = "Lesser Magic Essence" },
            { itemID = 10940, count = 1, name = "Strange Dust" },
        },
    },
    ["Enchant Bracer - Minor Health"] = {
        spellID = 7418,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  1, 70, 90, 110 },
        reagents = { { itemID = 10940, count = 1, name = "Strange Dust" } },
    },
    ["Enchant Bracer - Minor Spirit"] = {
        spellID = 7766,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 60,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  60, 105, 125, 145 },
        reagents = { { itemID = 10938, count = 2, name = "Lesser Magic Essence" } },
    },
    ["Enchant Bracer - Minor Stamina"] = {
        spellID = 7457,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  50, 100, 120, 140 },
        reagents = { { itemID = 10940, count = 3, name = "Strange Dust" } },
    },
    ["Enchant Bracer - Minor Strength"] = {
        spellID = 7782,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 80,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  80, 115, 135, 155 },
        reagents = { { itemID = 10940, count = 5, name = "Strange Dust" } },
    },
    ["Enchant Bracer - Restore Mana Prime"] = {
        spellID = 27913,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 335,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  335, 345, 360, 375 },
        reagents = { { itemID = 22446, count = 8, name = "Greater Planar Essence" } },
    },
    ["Enchant Bracer - Spellpower"] = {
        spellID = 27917,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 6, name = "Large Prismatic Shard" },
            { itemID = 21884, count = 6, name = "Primal Fire" },
            { itemID = 21885, count = 6, name = "Primal Water" },
        },
    },
    ["Enchant Bracer - Spirit"] = {
        spellID = 13642,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 165,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  165, 185, 205, 225 },
        reagents = { { itemID = 11134, count = 1, name = "Lesser Mystic Essence" } },
    },
    ["Enchant Bracer - Stamina"] = {
        spellID = 13648,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 170,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  170, 190, 210, 230 },
        reagents = { { itemID = 11083, count = 6, name = "Soul Dust" } },
    },
    ["Enchant Bracer - Stats"] = {
        spellID = 27905,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 315,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  315, 325, 340, 355 },
        reagents = {
            { itemID = 22445, count = 6, name = "Arcane Dust" },
            { itemID = 22447, count = 6, name = "Lesser Planar Essence" },
        },
    },
    ["Enchant Bracer - Strength"] = {
        spellID = 13661,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 180,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  180, 200, 220, 240 },
        reagents = { { itemID = 11137, count = 1, name = "Vision Dust" } },
    },
    ["Enchant Bracer - Superior Healing"] = {
        spellID = 27911,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 325,
        sources = {
            { method = "reputation", faction = "Horde", detail = "Thrallmar @ Neutral" },
            { method = "reputation", faction = "Alliance", detail = "Honor Hold @ Neutral" },
        },
        category = "Enchant Bracer",
        skillRange = {  325, 335, 350, 365 },
        reagents = {
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
            { itemID = 21886, count = 4, name = "Primal Life" },
        },
    },
    ["Enchant Bracer - Superior Spirit"] = {
        spellID = 20009,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 270,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  270, 290, 310, 330 },
        reagents = {
            { itemID = 16202, count = 3, name = "Lesser Eternal Essence" },
            { itemID = 11176, count = 10, name = "Dream Dust" },
        },
    },
    ["Enchant Bracer - Superior Stamina"] = {
        spellID = 20011,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  300, 310, 325, 340 },
        reagents = { { itemID = 16204, count = 15, name = "Illusion Dust" } },
    },
    ["Enchant Bracer - Superior Strength"] = {
        spellID = 20010,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 295,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Bracer",
        skillRange = {  295, 310, 325, 340 },
        reagents = {
            { itemID = 16204, count = 6, name = "Illusion Dust" },
            { itemID = 16203, count = 6, name = "Greater Eternal Essence" },
        },
    },

    -- ================================================================
    -- ENCHANT CHEST
    -- ================================================================
    ["Enchant Chest - Defense"] = {
        spellID = 46594,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "reputation", faction = "Both", detail = "Shattered Sun Offensive @ Friendly" },
        },
        category = "Enchant Chest",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
            { itemID = 22445, count = 8, name = "Arcane Dust" },
            { itemID = 23427, count = 4, name = "Eternium Ore" },
        },
    },
    ["Enchant Chest - Exceptional Health"] = {
        spellID = 27957,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 315,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  315, 325, 340, 355 },
        reagents = {
            { itemID = 22445, count = 8, name = "Arcane Dust" },
            { itemID = 13446, count = 4, name = "Major Healing Potion" },
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
        },
    },
    ["Enchant Chest - Exceptional Stats"] = {
        spellID = 27960,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 345,
        sources = {
            { method = "reputation", faction = "Horde", detail = "Thrallmar @ Honored" },
            { method = "reputation", faction = "Alliance", detail = "Honor Hold @ Honored" },
        },
        category = "Enchant Chest",
        skillRange = {  345, 355, 370, 385 },
        reagents = {
            { itemID = 22449, count = 4, name = "Large Prismatic Shard" },
            { itemID = 22445, count = 4, name = "Arcane Dust" },
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
        },
    },
    ["Enchant Chest - Greater Health"] = {
        spellID = 13640,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 160,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  160, 180, 200, 220 },
        reagents = { { itemID = 11083, count = 3, name = "Soul Dust" } },
    },
    ["Enchant Chest - Greater Mana"] = {
        spellID = 13663,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 185,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  185, 205, 225, 245 },
        reagents = { { itemID = 11135, count = 1, name = "Greater Mystic Essence" } },
    },
    ["Enchant Chest - Greater Stats"] = {
        spellID = 20025,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 4, name = "Large Brilliant Shard" },
            { itemID = 16204, count = 15, name = "Illusion Dust" },
            { itemID = 16203, count = 10, name = "Greater Eternal Essence" },
        },
    },
    ["Enchant Chest - Health"] = {
        spellID = 7857,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 120,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  120, 145, 165, 185 },
        reagents = {
            { itemID = 10940, count = 4, name = "Strange Dust" },
            { itemID = 10998, count = 1, name = "Lesser Astral Essence" },
        },
    },
    ["Enchant Chest - Lesser Absorption"] = {
        spellID = 13538,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 140,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  140, 165, 185, 205 },
        reagents = {
            { itemID = 10940, count = 2, name = "Strange Dust" },
            { itemID = 11082, count = 1, name = "Greater Astral Essence" },
            { itemID = 11084, count = 1, name = "Large Glimmering Shard" },
        },
    },
    ["Enchant Chest - Lesser Health"] = {
        spellID = 7748,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 60,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  60, 105, 125, 145 },
        reagents = {
            { itemID = 10940, count = 2, name = "Strange Dust" },
            { itemID = 10938, count = 2, name = "Lesser Magic Essence" },
        },
    },
    ["Enchant Chest - Lesser Mana"] = {
        spellID = 7776,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 80,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kithas, Lilly" },
        },
        category = "Enchant Chest",
        skillRange = {  80, 115, 135, 155 },
        reagents = {
            { itemID = 10939, count = 1, name = "Greater Magic Essence" },
            { itemID = 10938, count = 1, name = "Lesser Magic Essence" },
        },
    },
    ["Enchant Chest - Lesser Stats"] = {
        spellID = 13700,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  200, 220, 240, 260 },
        reagents = {
            { itemID = 11135, count = 2, name = "Greater Mystic Essence" },
            { itemID = 11137, count = 2, name = "Vision Dust" },
            { itemID = 11139, count = 1, name = "Large Glowing Shard" },
        },
    },
    ["Enchant Chest - Major Health"] = {
        spellID = 20026,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Qia" },
        },
        category = "Enchant Chest",
        skillRange = {  275, 295, 315, 335 },
        reagents = {
            { itemID = 16204, count = 6, name = "Illusion Dust" },
            { itemID = 14343, count = 1, name = "Small Brilliant Shard" },
        },
    },
    ["Enchant Chest - Major Mana"] = {
        spellID = 20028,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 290,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  290, 305, 322, 340 },
        reagents = {
            { itemID = 16203, count = 3, name = "Greater Eternal Essence" },
            { itemID = 14343, count = 1, name = "Small Brilliant Shard" },
        },
    },
    ["Enchant Chest - Major Resilience"] = {
        spellID = 33992,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 345,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  345, 355, 370, 385 },
        reagents = {
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
            { itemID = 22445, count = 10, name = "Arcane Dust" },
        },
    },
    ["Enchant Chest - Major Spirit"] = {
        spellID = 33990,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 320,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  320, 330, 345, 360 },
        reagents = { { itemID = 22446, count = 2, name = "Greater Planar Essence" } },
    },
    ["Enchant Chest - Mana"] = {
        spellID = 13607,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 145,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  145, 170, 190, 210 },
        reagents = {
            { itemID = 11082, count = 1, name = "Greater Astral Essence" },
            { itemID = 10998, count = 2, name = "Lesser Astral Essence" },
        },
    },
    ["Enchant Chest - Minor Absorption"] = {
        spellID = 7426,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 40,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  40, 90, 110, 130 },
        reagents = {
            { itemID = 10940, count = 2, name = "Strange Dust" },
            { itemID = 10938, count = 1, name = "Lesser Magic Essence" },
        },
    },
    ["Enchant Chest - Minor Health"] = {
        spellID = 7420,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 15,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  15, 70, 90, 110 },
        reagents = { { itemID = 10940, count = 1, name = "Strange Dust" } },
    },
    ["Enchant Chest - Minor Mana"] = {
        spellID = 7443,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 20,
        sources = {
            { method = "vendor", faction = "Both", detail = "Enchanting supplies" },
        },
        category = "Enchant Chest",
        skillRange = {  20, 80, 100, 120 },
        reagents = { { itemID = 10938, count = 1, name = "Lesser Magic Essence" } },
    },
    ["Enchant Chest - Minor Stats"] = {
        spellID = 13626,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  150, 175, 195, 215 },
        reagents = {
            { itemID = 11082, count = 1, name = "Greater Astral Essence" },
            { itemID = 11083, count = 1, name = "Soul Dust" },
            { itemID = 11084, count = 1, name = "Large Glimmering Shard" },
        },
    },
    ["Enchant Chest - Restore Mana Prime"] = {
        spellID = 33991,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22447, count = 2, name = "Lesser Planar Essence" },
            { itemID = 22445, count = 2, name = "Arcane Dust" },
        },
    },
    ["Enchant Chest - Stats"] = {
        spellID = 13941,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 245,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  245, 265, 285, 305 },
        reagents = {
            { itemID = 11178, count = 1, name = "Large Radiant Shard" },
            { itemID = 11176, count = 3, name = "Dream Dust" },
            { itemID = 11175, count = 2, name = "Greater Nether Essence" },
        },
    },
    ["Enchant Chest - Superior Health"] = {
        spellID = 13858,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 220,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  220, 240, 260, 280 },
        reagents = { { itemID = 11137, count = 6, name = "Vision Dust" } },
    },
    ["Enchant Chest - Superior Mana"] = {
        spellID = 13917,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Chest",
        skillRange = {  230, 250, 270, 290 },
        reagents = {
            { itemID = 11175, count = 1, name = "Greater Nether Essence" },
            { itemID = 11174, count = 2, name = "Lesser Nether Essence" },
        },
    },

    -- ================================================================
    -- ENCHANT CLOAK
    -- ================================================================
    ["Enchant Cloak - Defense"] = {
        spellID = 13635,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 155,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  155, 175, 195, 215 },
        reagents = {
            { itemID = 11138, count = 1, name = "Small Glowing Shard" },
            { itemID = 11083, count = 3, name = "Soul Dust" },
        },
    },
    ["Enchant Cloak - Dodge"] = {
        spellID = 25086,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Lower City @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 3, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 3, name = "Greater Planar Essence" },
            { itemID = 22452, count = 8, name = "Primal Earth" },
        },
    },
    ["Enchant Cloak - Fire Resistance"] = {
        spellID = 13657,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  175, 195, 215, 235 },
        reagents = {
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
            { itemID = 7068, count = 1, name = "Elemental Fire" },
        },
    },
    ["Enchant Cloak - Greater Agility"] = {
        spellID = 34004,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  310, 320, 335, 350 },
        reagents = {
            { itemID = 22446, count = 1, name = "Greater Planar Essence" },
            { itemID = 22445, count = 4, name = "Arcane Dust" },
            { itemID = 22451, count = 1, name = "Primal Air" },
        },
    },
    ["Enchant Cloak - Greater Arcane Resistance"] = {
        spellID = 34005,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 4, name = "Large Prismatic Shard" },
            { itemID = 22457, count = 8, name = "Primal Mana" },
        },
    },
    ["Enchant Cloak - Greater Defense"] = {
        spellID = 13746,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  205, 225, 245, 265 },
        reagents = { { itemID = 11137, count = 3, name = "Vision Dust" } },
    },
    ["Enchant Cloak - Greater Fire Resistance"] = {
        spellID = 25081,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Circle @ Neutral" },
        },
        category = "Enchant Cloak",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 3, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 3, name = "Greater Planar Essence" },
            { itemID = 7078, count = 4, name = "Essence of Fire" },
        },
    },
    ["Enchant Cloak - Greater Nature Resistance"] = {
        spellID = 25082,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Circle @ Friendly" },
        },
        category = "Enchant Cloak",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 2, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 3, name = "Greater Planar Essence" },
            { itemID = 12803, count = 4, name = "Living Essence" },
        },
    },
    ["Enchant Cloak - Greater Resistance"] = {
        spellID = 20014,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 265,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  265, 285, 305, 325 },
        reagents = {
            { itemID = 16202, count = 2, name = "Lesser Eternal Essence" },
            { itemID = 7077, count = 1, name = "Heart of Fire" },
            { itemID = 7075, count = 1, name = "Core of Earth" },
            { itemID = 7079, count = 1, name = "Globe of Water" },
            { itemID = 7081, count = 1, name = "Breath of Wind" },
            { itemID = 7972, count = 1, name = "Ichor of Undeath" },
        },
    },
    ["Enchant Cloak - Greater Shadow Resistance"] = {
        spellID = 34006,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 4, name = "Large Prismatic Shard" },
            { itemID = 22456, count = 8, name = "Primal Shadow" },
        },
    },
    ["Enchant Cloak - Lesser Agility"] = {
        spellID = 13882,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  225, 245, 265, 285 },
        reagents = { { itemID = 11174, count = 2, name = "Lesser Nether Essence" } },
    },
    ["Enchant Cloak - Lesser Fire Resistance"] = {
        spellID = 7861,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  125, 150, 170, 190 },
        reagents = {
            { itemID = 6371, count = 1, name = "Fire Oil" },
            { itemID = 10998, count = 1, name = "Lesser Astral Essence" },
        },
    },
    ["Enchant Cloak - Lesser Protection"] = {
        spellID = 13421,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 115,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  115, 140, 160, 180 },
        reagents = {
            { itemID = 10940, count = 6, name = "Strange Dust" },
            { itemID = 10978, count = 1, name = "Small Glimmering Shard" },
        },
    },
    ["Enchant Cloak - Lesser Shadow Resistance"] = {
        spellID = 13522,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 135,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  135, 160, 180, 200 },
        reagents = {
            { itemID = 11082, count = 1, name = "Greater Astral Essence" },
            { itemID = 6048, count = 1, name = "Shadow Protection Potion" },
        },
    },
    ["Enchant Cloak - Major Armor"] = {
        spellID = 27961,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  310, 320, 335, 350 },
        reagents = { { itemID = 22445, count = 8, name = "Arcane Dust" } },
    },
    ["Enchant Cloak - Major Resistance"] = {
        spellID = 27962,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 330,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  330, 340, 355, 370 },
        reagents = {
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
            { itemID = 21884, count = 4, name = "Primal Fire" },
            { itemID = 22451, count = 4, name = "Primal Air" },
            { itemID = 22452, count = 4, name = "Primal Earth" },
            { itemID = 21885, count = 4, name = "Primal Water" },
        },
    },
    ["Enchant Cloak - Minor Agility"] = {
        spellID = 13419,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 110,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Dalria, Kulwia" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  110, 135, 155, 175 },
        reagents = { { itemID = 10998, count = 1, name = "Lesser Astral Essence" } },
    },
    ["Enchant Cloak - Minor Protection"] = {
        spellID = 7771,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 70,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  70, 110, 130, 150 },
        reagents = {
            { itemID = 10940, count = 3, name = "Strange Dust" },
            { itemID = 10939, count = 1, name = "Greater Magic Essence" },
        },
    },
    ["Enchant Cloak - Minor Resistance"] = {
        spellID = 7454,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 45,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  45, 95, 115, 135 },
        reagents = {
            { itemID = 10940, count = 1, name = "Strange Dust" },
            { itemID = 10938, count = 2, name = "Lesser Magic Essence" },
        },
    },
    ["Enchant Cloak - Resistance"] = {
        spellID = 13794,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  205, 225, 245, 265 },
        reagents = { { itemID = 11174, count = 1, name = "Lesser Nether Essence" } },
    },
    ["Enchant Cloak - Spell Penetration"] = {
        spellID = 34003,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 325,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Consortium @ Neutral" },
        },
        category = "Enchant Cloak",
        skillRange = {  325, 335, 350, 365 },
        reagents = {
            { itemID = 22446, count = 2, name = "Greater Planar Essence" },
            { itemID = 22445, count = 6, name = "Arcane Dust" },
            { itemID = 22457, count = 2, name = "Primal Mana" },
        },
    },
    ["Enchant Cloak - Stealth"] = {
        spellID = 25083,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 3, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 3, name = "Greater Planar Essence" },
            { itemID = 22794, count = 2, name = "Fel Lotus" },
        },
    },
    ["Enchant Cloak - Steelweave"] = {
        spellID = 47051,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Cloak",
        skillRange = {  375, 380, 395, 410 },
        reagents = {
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 22452, count = 8, name = "Primal Earth" },
        },
    },
    ["Enchant Cloak - Subtlety"] = {
        spellID = 25084,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Horde", detail = "Thrallmar @ Revered" },
            { method = "reputation", faction = "Alliance", detail = "Honor Hold @ Revered" },
        },
        category = "Enchant Cloak",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 4, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 2, name = "Greater Planar Essence" },
            { itemID = 22456, count = 8, name = "Primal Shadow" },
        },
    },
    ["Enchant Cloak - Superior Defense"] = {
        spellID = 20015,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 285,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Lorelae Wintersong" },
        },
        category = "Enchant Cloak",
        skillRange = {  285, 300, 317, 335 },
        reagents = { { itemID = 16204, count = 8, name = "Illusion Dust" } },
    },

    -- ================================================================
    -- ENCHANT GLOVES
    -- ================================================================
    ["Enchant Gloves - Advanced Herbalism"] = {
        spellID = 13868,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  225, 245, 265, 285 },
        reagents = {
            { itemID = 11137, count = 3, name = "Vision Dust" },
            { itemID = 8838, count = 3, name = "Sungrass" },
        },
    },
    ["Enchant Gloves - Advanced Mining"] = {
        spellID = 13841,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 215,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  215, 235, 255, 275 },
        reagents = {
            { itemID = 11137, count = 3, name = "Vision Dust" },
            { itemID = 6037, count = 3, name = "Truesilver Bar" },
        },
    },
    ["Enchant Gloves - Agility"] = {
        spellID = 13815,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 210,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  210, 230, 250, 270 },
        reagents = {
            { itemID = 11174, count = 1, name = "Lesser Nether Essence" },
            { itemID = 11137, count = 1, name = "Vision Dust" },
        },
    },
    ["Enchant Gloves - Assault"] = {
        spellID = 33996,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  310, 320, 335, 350 },
        reagents = { { itemID = 22445, count = 8, name = "Arcane Dust" } },
    },
    ["Enchant Gloves - Blasting"] = {
        spellID = 33993,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 305,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  305, 315, 330, 345 },
        reagents = {
            { itemID = 22447, count = 1, name = "Lesser Planar Essence" },
            { itemID = 22445, count = 4, name = "Arcane Dust" },
        },
    },
    ["Enchant Gloves - Fire Power"] = {
        spellID = 25078,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 20725, count = 2, name = "Nexus Crystal" },
            { itemID = 14344, count = 10, name = "Large Brilliant Shard" },
            { itemID = 7078, count = 4, name = "Essence of Fire" },
        },
    },
    ["Enchant Gloves - Fishing"] = {
        spellID = 13620,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 145,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  145, 170, 190, 210 },
        reagents = {
            { itemID = 11083, count = 1, name = "Soul Dust" },
            { itemID = 6370, count = 3, name = "Blackmouth Oil" },
        },
    },
    ["Enchant Gloves - Frost Power"] = {
        spellID = 25074,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 20725, count = 3, name = "Nexus Crystal" },
            { itemID = 14344, count = 10, name = "Large Brilliant Shard" },
            { itemID = 7080, count = 4, name = "Essence of Water" },
        },
    },
    ["Enchant Gloves - Greater Agility"] = {
        spellID = 20012,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 270,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  270, 290, 310, 330 },
        reagents = {
            { itemID = 16202, count = 3, name = "Lesser Eternal Essence" },
            { itemID = 16204, count = 3, name = "Illusion Dust" },
        },
    },
    ["Enchant Gloves - Greater Strength"] = {
        spellID = 20013,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 295,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  295, 310, 325, 340 },
        reagents = {
            { itemID = 16203, count = 4, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 4, name = "Illusion Dust" },
        },
    },
    ["Enchant Gloves - Healing Power"] = {
        spellID = 25079,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 20725, count = 3, name = "Nexus Crystal" },
            { itemID = 14344, count = 8, name = "Large Brilliant Shard" },
            { itemID = 12811, count = 1, name = "Righteous Orb" },
        },
    },
    ["Enchant Gloves - Herbalism"] = {
        spellID = 13617,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 145,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  145, 170, 190, 210 },
        reagents = {
            { itemID = 11083, count = 1, name = "Soul Dust" },
            { itemID = 3356, count = 3, name = "Kingsblood" },
        },
    },
    ["Enchant Gloves - Major Healing"] = {
        spellID = 33999,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Friendly" },
        },
        category = "Enchant Gloves",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22446, count = 6, name = "Greater Planar Essence" },
            { itemID = 22449, count = 6, name = "Large Prismatic Shard" },
            { itemID = 21886, count = 6, name = "Primal Life" },
        },
    },
    ["Enchant Gloves - Major Spellpower"] = {
        spellID = 33997,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "reputation", faction = "Both", detail = "Keepers of Time @ Friendly" },
        },
        category = "Enchant Gloves",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22446, count = 6, name = "Greater Planar Essence" },
            { itemID = 22449, count = 6, name = "Large Prismatic Shard" },
            { itemID = 22457, count = 6, name = "Primal Mana" },
        },
    },
    ["Enchant Gloves - Major Strength"] = {
        spellID = 33995,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 340,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  340, 350, 365, 380 },
        reagents = {
            { itemID = 22445, count = 12, name = "Arcane Dust" },
            { itemID = 22446, count = 1, name = "Greater Planar Essence" },
        },
    },
    ["Enchant Gloves - Mining"] = {
        spellID = 13612,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 145,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  145, 170, 190, 210 },
        reagents = {
            { itemID = 11083, count = 1, name = "Soul Dust" },
            { itemID = 2772, count = 3, name = "Iron Ore" },
        },
    },
    ["Enchant Gloves - Minor Haste"] = {
        spellID = 13948,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  250, 270, 290, 310 },
        reagents = {
            { itemID = 11178, count = 2, name = "Large Radiant Shard" },
            { itemID = 8153, count = 2, name = "Wildvine" },
        },
    },
    ["Enchant Gloves - Riding Skill"] = {
        spellID = 13947,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 250,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  250, 270, 290, 310 },
        reagents = {
            { itemID = 11178, count = 2, name = "Large Radiant Shard" },
            { itemID = 11176, count = 3, name = "Dream Dust" },
        },
    },
    ["Enchant Gloves - Shadow Power"] = {
        spellID = 25073,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 20725, count = 3, name = "Nexus Crystal" },
            { itemID = 14344, count = 10, name = "Large Brilliant Shard" },
            { itemID = 12808, count = 6, name = "Essence of Undeath" },
        },
    },
    ["Enchant Gloves - Skinning"] = {
        spellID = 13698,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 200,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  200, 220, 240, 260 },
        reagents = {
            { itemID = 11137, count = 1, name = "Vision Dust" },
            { itemID = 7392, count = 3, name = "Green Whelp Scale" },
        },
    },
    ["Enchant Gloves - Spell Strike"] = {
        spellID = 33994,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Honored" },
        },
        category = "Enchant Gloves",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 22445, count = 2, name = "Arcane Dust" },
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
        },
    },
    ["Enchant Gloves - Strength"] = {
        spellID = 13887,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  225, 245, 265, 285 },
        reagents = {
            { itemID = 11174, count = 2, name = "Lesser Nether Essence" },
            { itemID = 11137, count = 3, name = "Vision Dust" },
        },
    },
    ["Enchant Gloves - Superior Agility"] = {
        spellID = 25080,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Keepers of Time @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 3, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 3, name = "Greater Planar Essence" },
            { itemID = 22451, count = 2, name = "Primal Air" },
        },
    },
    ["Enchant Gloves - Threat"] = {
        spellID = 25072,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Revered" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Gloves",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 22448, count = 4, name = "Small Prismatic Shard" },
            { itemID = 22446, count = 2, name = "Greater Planar Essence" },
            { itemID = 21886, count = 8, name = "Primal Life" },
        },
    },

    -- ================================================================
    -- ENCHANT RING
    -- ================================================================
    ["Enchant Ring - Healing Power"] = {
        spellID = 27926,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 370,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Honored" },
        },
        category = "Enchant Ring",
        skillRange = {  370, 380, 395, 410 },
        reagents = {
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 3, name = "Greater Planar Essence" },
            { itemID = 22445, count = 5, name = "Arcane Dust" },
        },
    },
    ["Enchant Ring - Spellpower"] = {
        spellID = 27924,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "reputation", faction = "Both", detail = "Keepers of Time @ Friendly" },
        },
        category = "Enchant Ring",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 2, name = "Greater Planar Essence" },
        },
    },
    ["Enchant Ring - Stats"] = {
        spellID = 27927,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "Lower City @ Friendly" },
        },
        category = "Enchant Ring",
        skillRange = {  375, 385, 400, 415 },
        reagents = {
            { itemID = 22450, count = 2, name = "Void Crystal" },
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
        },
    },
    ["Enchant Ring - Striking"] = {
        spellID = 27920,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Consortium @ Honored" },
        },
        category = "Enchant Ring",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
            { itemID = 22445, count = 6, name = "Arcane Dust" },
        },
    },

    -- ================================================================
    -- ENCHANT SHIELD
    -- ================================================================
    ["Enchant Shield - Frost Resistance"] = {
        spellID = 13933,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 235,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  235, 255, 275, 295 },
        reagents = {
            { itemID = 11178, count = 1, name = "Large Radiant Shard" },
            { itemID = 3829, count = 1, name = "Frost Oil" },
        },
    },
    ["Enchant Shield - Greater Spirit"] = {
        spellID = 13905,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  230, 250, 270, 290 },
        reagents = {
            { itemID = 11175, count = 1, name = "Greater Nether Essence" },
            { itemID = 11176, count = 2, name = "Dream Dust" },
        },
    },
    ["Enchant Shield - Greater Stamina"] = {
        spellID = 20017,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 265,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Daniel Bartlett, Mythrin\'dir" },
        },
        category = "Enchant Shield",
        skillRange = {  265, 285, 305, 325 },
        reagents = { { itemID = 11176, count = 10, name = "Dream Dust" } },
    },
    ["Enchant Shield - Intellect"] = {
        spellID = 27945,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Aged Dalaran Wizard" },
        },
        category = "Enchant Shield",
        skillRange = {  325, 335, 350, 365 },
        reagents = { { itemID = 22446, count = 4, name = "Greater Planar Essence" } },
    },
    ["Enchant Shield - Lesser Block"] = {
        spellID = 13689,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 195,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  195, 215, 235, 255 },
        reagents = {
            { itemID = 11135, count = 2, name = "Greater Mystic Essence" },
            { itemID = 11137, count = 2, name = "Vision Dust" },
            { itemID = 11139, count = 1, name = "Large Glowing Shard" },
        },
    },
    ["Enchant Shield - Lesser Protection"] = {
        spellID = 13464,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 115,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  115, 140, 160, 180 },
        reagents = {
            { itemID = 10998, count = 1, name = "Lesser Astral Essence" },
            { itemID = 10940, count = 1, name = "Strange Dust" },
            { itemID = 10978, count = 1, name = "Small Glimmering Shard" },
        },
    },
    ["Enchant Shield - Lesser Spirit"] = {
        spellID = 13485,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 130,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  130, 155, 175, 195 },
        reagents = {
            { itemID = 10998, count = 2, name = "Lesser Astral Essence" },
            { itemID = 10940, count = 4, name = "Strange Dust" },
        },
    },
    ["Enchant Shield - Lesser Stamina"] = {
        spellID = 13631,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 155,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  155, 175, 195, 215 },
        reagents = {
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
            { itemID = 11083, count = 1, name = "Soul Dust" },
        },
    },
    ["Enchant Shield - Major Stamina"] = {
        spellID = 34009,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Madame Ruby" },
        },
        category = "Enchant Shield",
        skillRange = {  325, 335, 350, 365 },
        reagents = { { itemID = 22445, count = 15, name = "Arcane Dust" } },
    },
    ["Enchant Shield - Minor Stamina"] = {
        spellID = 13378,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 105,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  105, 130, 150, 170 },
        reagents = {
            { itemID = 10998, count = 1, name = "Lesser Astral Essence" },
            { itemID = 10940, count = 2, name = "Strange Dust" },
        },
    },
    ["Enchant Shield - Resilience"] = {
        spellID = 44383,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 330,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  330, 340, 355, 370 },
        reagents = {
            { itemID = 22449, count = 1, name = "Large Prismatic Shard" },
            { itemID = 22447, count = 4, name = "Lesser Planar Essence" },
        },
    },
    ["Enchant Shield - Resistance"] = {
        spellID = 27947,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
            { itemID = 22573, count = 1, name = "Mote of Earth" },
            { itemID = 22574, count = 1, name = "Mote of Fire" },
            { itemID = 22572, count = 1, name = "Mote of Air" },
            { itemID = 22578, count = 1, name = "Mote of Water" },
        },
    },
    ["Enchant Shield - Shield Block"] = {
        spellID = 27946,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 340,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  340, 350, 365, 380 },
        reagents = {
            { itemID = 22445, count = 12, name = "Arcane Dust" },
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
            { itemID = 22452, count = 10, name = "Primal Earth" },
        },
    },
    ["Enchant Shield - Spirit"] = {
        spellID = 13659,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 180,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  180, 200, 220, 240 },
        reagents = {
            { itemID = 11135, count = 1, name = "Greater Mystic Essence" },
            { itemID = 11137, count = 1, name = "Vision Dust" },
        },
    },
    ["Enchant Shield - Stamina"] = {
        spellID = 13817,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 210,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  210, 230, 250, 270 },
        reagents = { { itemID = 11137, count = 5, name = "Vision Dust" } },
    },
    ["Enchant Shield - Superior Spirit"] = {
        spellID = 20016,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 280,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  280, 300, 320, 340 },
        reagents = {
            { itemID = 16203, count = 2, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 4, name = "Illusion Dust" },
        },
    },
    ["Enchant Shield - Tough Shield"] = {
        spellID = 27944,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Shield",
        skillRange = {  310, 320, 335, 350 },
        reagents = {
            { itemID = 22445, count = 6, name = "Arcane Dust" },
            { itemID = 22452, count = 10, name = "Primal Earth" },
        },
    },

    -- ================================================================
    -- ENCHANT WEAPON
    -- ================================================================
    ["Enchant 2H Weapon - Agility"] = {
        spellID = 27837,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 290,
        sources = {
            { method = "reputation", faction = "Both", detail = "Timbermaw Hold @ Neutral" },
        },
        category = "Enchant Weapon",
        skillRange = {  290, 305, 322, 340 },
        reagents = {
            { itemID = 14344, count = 10, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 6, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 14, name = "Illusion Dust" },
            { itemID = 7082, count = 4, name = "Essence of Air" },
        },
    },
    ["Enchant 2H Weapon - Greater Impact"] = {
        spellID = 13937,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 240,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  240, 260, 280, 300 },
        reagents = {
            { itemID = 11178, count = 2, name = "Large Radiant Shard" },
            { itemID = 11176, count = 2, name = "Dream Dust" },
        },
    },
    ["Enchant 2H Weapon - Impact"] = {
        spellID = 13695,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  200, 220, 240, 260 },
        reagents = {
            { itemID = 11137, count = 4, name = "Vision Dust" },
            { itemID = 11139, count = 1, name = "Large Glowing Shard" },
        },
    },
    ["Enchant 2H Weapon - Lesser Impact"] = {
        spellID = 13529,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 145,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  145, 170, 190, 210 },
        reagents = {
            { itemID = 11083, count = 3, name = "Soul Dust" },
            { itemID = 11084, count = 1, name = "Large Glimmering Shard" },
        },
    },
    ["Enchant 2H Weapon - Lesser Intellect"] = {
        spellID = 7793,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 100,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kithas, Leo Sarn +2 more" },
        },
        category = "Enchant Weapon",
        skillRange = {  100, 130, 150, 170 },
        reagents = { { itemID = 10939, count = 3, name = "Greater Magic Essence" } },
    },
    ["Enchant 2H Weapon - Lesser Spirit"] = {
        spellID = 13380,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 110,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  110, 135, 155, 175 },
        reagents = {
            { itemID = 10998, count = 1, name = "Lesser Astral Essence" },
            { itemID = 10940, count = 6, name = "Strange Dust" },
        },
    },
    ["Enchant 2H Weapon - Major Agility"] = {
        spellID = 27977,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 6, name = "Greater Planar Essence" },
            { itemID = 22445, count = 20, name = "Arcane Dust" },
        },
    },
    ["Enchant 2H Weapon - Major Intellect"] = {
        spellID = 20036,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 16203, count = 12, name = "Greater Eternal Essence" },
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
        },
    },
    ["Enchant 2H Weapon - Major Spirit"] = {
        spellID = 20035,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 16203, count = 12, name = "Greater Eternal Essence" },
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
        },
    },
    ["Enchant 2H Weapon - Minor Impact"] = {
        spellID = 7745,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 100,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  100, 130, 150, 170 },
        reagents = {
            { itemID = 10940, count = 4, name = "Strange Dust" },
            { itemID = 10978, count = 1, name = "Small Glimmering Shard" },
        },
    },
    ["Enchant 2H Weapon - Savagery"] = {
        spellID = 27971,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 4, name = "Large Prismatic Shard" },
            { itemID = 22445, count = 40, name = "Arcane Dust" },
        },
    },
    ["Enchant 2H Weapon - Superior Impact"] = {
        spellID = 20030,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 295,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  295, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 4, name = "Large Brilliant Shard" },
            { itemID = 16204, count = 10, name = "Illusion Dust" },
        },
    },
    ["Enchant Weapon - Agility"] = {
        spellID = 23800,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 290,
        sources = {
            { method = "reputation", faction = "Both", detail = "Timbermaw Hold @ Friendly" },
        },
        category = "Enchant Weapon",
        skillRange = {  290, 305, 322, 340 },
        reagents = {
            { itemID = 14344, count = 6, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 6, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 4, name = "Illusion Dust" },
            { itemID = 7082, count = 2, name = "Essence of Air" },
        },
    },
    ["Enchant Weapon - Battlemaster"] = {
        spellID = 28004,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22450, count = 8, name = "Void Crystal" },
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 21885, count = 2, name = "Primal Water" },
        },
    },
    ["Enchant Weapon - Crusader"] = {
        spellID = 20034,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 4, name = "Large Brilliant Shard" },
            { itemID = 12811, count = 2, name = "Righteous Orb" },
        },
    },
    ["Enchant Weapon - Deathfrost"] = {
        spellID = 46578,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  350, 350, 357, 365 },
        reagents = {
            { itemID = 22456, count = 2, name = "Primal Shadow" },
            { itemID = 21885, count = 2, name = "Primal Water" },
        },
    },
    ["Enchant Weapon - Demonslaying"] = {
        spellID = 13915,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 230,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  230, 250, 270, 290 },
        reagents = {
            { itemID = 11177, count = 1, name = "Small Radiant Shard" },
            { itemID = 11176, count = 2, name = "Dream Dust" },
            { itemID = 9224, count = 1, name = "Elixir of Demonslaying" },
        },
    },
    ["Enchant Weapon - Executioner"] = {
        spellID = 42974,
        rod = "Runed Eternium Rod",
        itemID = 0,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  375, 385, 400, 415 },
        reagents = {
            { itemID = 22450, count = 6, name = "Void Crystal" },
            { itemID = 22449, count = 10, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 6, name = "Greater Planar Essence" },
            { itemID = 22445, count = 30, name = "Arcane Dust" },
            { itemID = 22824, count = 3, name = "Elixir of Major Strength" },
        },
    },
    ["Enchant Weapon - Fiery Weapon"] = {
        spellID = 13898,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 265,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  265, 285, 305, 325 },
        reagents = {
            { itemID = 11177, count = 4, name = "Small Radiant Shard" },
            { itemID = 7078, count = 1, name = "Essence of Fire" },
        },
    },
    ["Enchant Weapon - Greater Agility"] = {
        spellID = 42620,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Violet Eye @ Revered" },
        },
        category = "Enchant Weapon",
        skillRange = {  350, 360, 367, 375 },
        reagents = {
            { itemID = 22445, count = 8, name = "Arcane Dust" },
            { itemID = 22446, count = 4, name = "Greater Planar Essence" },
            { itemID = 22449, count = 6, name = "Large Prismatic Shard" },
            { itemID = 22451, count = 2, name = "Primal Air" },
        },
    },
    ["Enchant Weapon - Greater Striking"] = {
        spellID = 13943,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 245,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  245, 265, 285, 305 },
        reagents = {
            { itemID = 11178, count = 2, name = "Large Radiant Shard" },
            { itemID = 11175, count = 2, name = "Greater Nether Essence" },
        },
    },
    ["Enchant Weapon - Healing Power"] = {
        spellID = 22750,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 4, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 8, name = "Greater Eternal Essence" },
            { itemID = 12803, count = 6, name = "Living Essence" },
            { itemID = 7080, count = 6, name = "Essence of Water" },
            { itemID = 12811, count = 1, name = "Righteous Orb" },
        },
    },
    ["Enchant Weapon - Icy Chill"] = {
        spellID = 20029,
        rod = "Runed Truesilver Rod",
        itemID = 0,
        skillReq = 285,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  285, 300, 317, 335 },
        reagents = {
            { itemID = 14343, count = 4, name = "Small Brilliant Shard" },
            { itemID = 7080, count = 1, name = "Essence of Water" },
            { itemID = 7082, count = 1, name = "Essence of Air" },
            { itemID = 13467, count = 1, name = "Icecap" },
        },
    },
    ["Enchant Weapon - Lesser Beastslayer"] = {
        spellID = 13653,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 175,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  175, 195, 215, 235 },
        reagents = {
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
            { itemID = 5637, count = 2, name = "Large Fang" },
            { itemID = 11138, count = 1, name = "Small Glowing Shard" },
        },
    },
    ["Enchant Weapon - Lesser Elemental Slayer"] = {
        spellID = 13655,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 175,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  175, 195, 215, 235 },
        reagents = {
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
            { itemID = 7067, count = 1, name = "Elemental Earth" },
            { itemID = 11138, count = 1, name = "Small Glowing Shard" },
        },
    },
    ["Enchant Weapon - Lesser Striking"] = {
        spellID = 13503,
        rod = "Runed Silver Rod",
        itemID = 0,
        skillReq = 140,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  140, 165, 185, 205 },
        reagents = {
            { itemID = 11083, count = 2, name = "Soul Dust" },
            { itemID = 11084, count = 1, name = "Large Glimmering Shard" },
        },
    },
    ["Enchant Weapon - Lifestealing"] = {
        spellID = 20032,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 6, name = "Large Brilliant Shard" },
            { itemID = 12808, count = 6, name = "Essence of Undeath" },
            { itemID = 12803, count = 6, name = "Living Essence" },
        },
    },
    ["Enchant Weapon - Major Healing"] = {
        spellID = 34010,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Sha'tar @ Honored" },
        },
        category = "Enchant Weapon",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 21885, count = 8, name = "Primal Water" },
            { itemID = 21886, count = 8, name = "Primal Life" },
        },
    },
    ["Enchant Weapon - Major Intellect"] = {
        spellID = 27968,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 340,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  340, 350, 365, 380 },
        reagents = {
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 10, name = "Greater Planar Essence" },
        },
    },
    ["Enchant Weapon - Major Spellpower"] = {
        spellID = 27975,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
        },
    },
    ["Enchant Weapon - Major Striking"] = {
        spellID = 27967,
        rod = "Runed Fel Iron Rod",
        itemID = 0,
        skillReq = 340,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Consortium @ Friendly" },
        },
        category = "Enchant Weapon",
        skillRange = {  340, 350, 365, 380 },
        reagents = {
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 6, name = "Greater Planar Essence" },
            { itemID = 22445, count = 6, name = "Arcane Dust" },
        },
    },
    ["Enchant Weapon - Mighty Intellect"] = {
        spellID = 23804,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Lokhtos Darkbargainer" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 15, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 12, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 20, name = "Illusion Dust" },
        },
    },
    ["Enchant Weapon - Mighty Spirit"] = {
        spellID = 23803,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Lokhtos Darkbargainer" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 10, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 8, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 15, name = "Illusion Dust" },
        },
    },
    ["Enchant Weapon - Minor Beastslayer"] = {
        spellID = 7786,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 90,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  90, 120, 140, 160 },
        reagents = {
            { itemID = 10940, count = 4, name = "Strange Dust" },
            { itemID = 10939, count = 2, name = "Greater Magic Essence" },
        },
    },
    ["Enchant Weapon - Minor Striking"] = {
        spellID = 7788,
        rod = "Runed Copper Rod",
        itemID = 0,
        skillReq = 90,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  90, 120, 140, 160 },
        reagents = {
            { itemID = 10940, count = 2, name = "Strange Dust" },
            { itemID = 10939, count = 1, name = "Greater Magic Essence" },
            { itemID = 10978, count = 1, name = "Small Glimmering Shard" },
        },
    },
    ["Enchant Weapon - Mongoose"] = {
        spellID = 27984,
        rod = "Runed Eternium Rod",
        itemID = 0,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  375, 385, 400, 415 },
        reagents = {
            { itemID = 22450, count = 6, name = "Void Crystal" },
            { itemID = 22449, count = 10, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 22445, count = 40, name = "Arcane Dust" },
        },
    },
    ["Enchant Weapon - Potency"] = {
        spellID = 27972,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 350,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 22449, count = 4, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 5, name = "Greater Planar Essence" },
            { itemID = 22445, count = 20, name = "Arcane Dust" },
        },
    },
    ["Enchant Weapon - Soulfrost"] = {
        spellID = 27982,
        rod = "Runed Eternium Rod",
        itemID = 0,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  375, 385, 400, 415 },
        reagents = {
            { itemID = 22450, count = 12, name = "Void Crystal" },
            { itemID = 22449, count = 10, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 21885, count = 6, name = "Primal Water" },
            { itemID = 22456, count = 6, name = "Primal Shadow" },
        },
    },
    ["Enchant Weapon - Spell Power"] = {
        spellID = 22749,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 4, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 12, name = "Greater Eternal Essence" },
            { itemID = 7078, count = 4, name = "Essence of Fire" },
            { itemID = 7080, count = 4, name = "Essence of Water" },
            { itemID = 7082, count = 4, name = "Essence of Air" },
            { itemID = 13926, count = 2, name = "Golden Pearl" },
        },
    },
    ["Enchant Weapon - Spellsurge"] = {
        spellID = 28003,
        rod = "Runed Adamantite Rod",
        itemID = 0,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  360, 370, 385, 400 },
        reagents = {
            { itemID = 22449, count = 12, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 10, name = "Greater Planar Essence" },
            { itemID = 22445, count = 20, name = "Arcane Dust" },
        },
    },
    ["Enchant Weapon - Strength"] = {
        spellID = 23799,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 290,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Lokhtos Darkbargainer" },
        },
        category = "Enchant Weapon",
        skillRange = {  290, 305, 322, 340 },
        reagents = {
            { itemID = 14344, count = 6, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 6, name = "Greater Eternal Essence" },
            { itemID = 16204, count = 4, name = "Illusion Dust" },
            { itemID = 7076, count = 2, name = "Essence of Earth" },
        },
    },
    ["Enchant Weapon - Striking"] = {
        spellID = 13693,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 195,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  195, 215, 235, 255 },
        reagents = {
            { itemID = 11135, count = 2, name = "Greater Mystic Essence" },
            { itemID = 11139, count = 1, name = "Large Glowing Shard" },
        },
    },
    ["Enchant Weapon - Sunfire"] = {
        spellID = 27981,
        rod = "Runed Eternium Rod",
        itemID = 0,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  375, 385, 400, 415 },
        reagents = {
            { itemID = 22450, count = 12, name = "Void Crystal" },
            { itemID = 22449, count = 10, name = "Large Prismatic Shard" },
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 21884, count = 6, name = "Primal Fire" },
            { itemID = 23571, count = 1, name = "Primal Might" },
        },
    },
    ["Enchant Weapon - Superior Striking"] = {
        spellID = 20031,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
            { itemID = 16203, count = 10, name = "Greater Eternal Essence" },
        },
    },
    ["Enchant Weapon - Unholy Weapon"] = {
        spellID = 20033,
        rod = "Runed Arcanite Rod",
        itemID = 0,
        skillReq = 295,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  295, 310, 325, 340 },
        reagents = {
            { itemID = 14344, count = 4, name = "Large Brilliant Shard" },
            { itemID = 12808, count = 4, name = "Essence of Undeath" },
        },
    },
    ["Enchant Weapon - Winter's Might"] = {
        spellID = 21931,
        rod = "Runed Golden Rod",
        itemID = 0,
        skillReq = 190,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enchant Weapon",
        skillRange = {  190, 210, 230, 250 },
        reagents = {
            { itemID = 11135, count = 3, name = "Greater Mystic Essence" },
            { itemID = 11137, count = 3, name = "Vision Dust" },
            { itemID = 11139, count = 1, name = "Large Glowing Shard" },
            { itemID = 3819, count = 2, name = "Wintersbite" },
        },
    },

    -- ================================================================
    -- OIL
    -- ================================================================
    ["Brilliant Mana Oil"] = {
        spellID = 25130,
        rod = "Runed Arcanite Rod",
        itemID = 20748,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Neutral" },
        },
        category = "Oil",
        skillRange = {  300, 310, 320, 330 },
        reagents = {
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
            { itemID = 8831, count = 3, name = "Purple Lotus" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Brilliant Wizard Oil"] = {
        spellID = 25129,
        rod = "Runed Arcanite Rod",
        itemID = 20749,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Friendly" },
        },
        category = "Oil",
        skillRange = {  300, 310, 320, 330 },
        reagents = {
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
            { itemID = 4625, count = 3, name = "Firebloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Lesser Mana Oil"] = {
        spellID = 25127,
        rod = "Runed Truesilver Rod",
        itemID = 20747,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kania" },
        },
        category = "Oil",
        skillRange = {  250, 260, 270, 280 },
        reagents = {
            { itemID = 11176, count = 3, name = "Dream Dust" },
            { itemID = 8831, count = 2, name = "Purple Lotus" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },
    ["Lesser Wizard Oil"] = {
        spellID = 25126,
        rod = "Runed Golden Rod",
        itemID = 20746,
        skillReq = 200,
        sources = {
            { method = "vendor", faction = "Both", detail = "Enchanting supplies" },
        },
        category = "Oil",
        skillRange = {  200, 210, 220, 230 },
        reagents = {
            { itemID = 11137, count = 3, name = "Vision Dust" },
            { itemID = 17035, count = 2, name = "Stranglethorn Seed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Minor Mana Oil"] = {
        spellID = 25125,
        rod = "Runed Silver Rod",
        itemID = 20745,
        skillReq = 150,
        sources = {
            { method = "vendor", faction = "Both", detail = "Enchanting supplies" },
        },
        category = "Oil",
        skillRange = {  150, 160, 170, 180 },
        reagents = {
            { itemID = 11083, count = 3, name = "Soul Dust" },
            { itemID = 17034, count = 2, name = "Maple Seed" },
            { itemID = 3372, count = 1, name = "Leaded Vial" },
        },
    },
    ["Minor Wizard Oil"] = {
        spellID = 25124,
        rod = "Runed Copper Rod",
        itemID = 20744,
        skillReq = 45,
        sources = {
            { method = "vendor", faction = "Both", detail = "Enchanting supplies" },
        },
        category = "Oil",
        skillRange = {  45, 55, 65, 75 },
        reagents = {
            { itemID = 10940, count = 2, name = "Strange Dust" },
            { itemID = 17034, count = 1, name = "Maple Seed" },
            { itemID = 3371, count = 1, name = "Empty Vial" },
        },
    },
    ["Superior Mana Oil"] = {
        spellID = 28016,
        rod = "Runed Fel Iron Rod",
        itemID = 22521,
        skillReq = 310,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Egomis, Lyna +1 more" },
        },
        category = "Oil",
        skillRange = {  310, 310, 320, 330 },
        reagents = {
            { itemID = 22445, count = 3, name = "Arcane Dust" },
            { itemID = 22791, count = 1, name = "Netherbloom" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Superior Wizard Oil"] = {
        spellID = 28019,
        rod = "Runed Fel Iron Rod",
        itemID = 22522,
        skillReq = 340,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Egomis, Lyna +1 more" },
        },
        category = "Oil",
        skillRange = {  340, 340, 350, 360 },
        reagents = {
            { itemID = 22445, count = 3, name = "Arcane Dust" },
            { itemID = 22792, count = 1, name = "Nightmare Vine" },
            { itemID = 18256, count = 1, name = "Imbued Vial" },
        },
    },
    ["Wizard Oil"] = {
        spellID = 25128,
        rod = "Runed Truesilver Rod",
        itemID = 20750,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kania" },
        },
        category = "Oil",
        skillRange = {  275, 285, 295, 305 },
        reagents = {
            { itemID = 16204, count = 3, name = "Illusion Dust" },
            { itemID = 4625, count = 2, name = "Firebloom" },
            { itemID = 8925, count = 1, name = "Crystal Vial" },
        },
    },

    -- ================================================================
    -- ROD
    -- ================================================================
    ["Runed Adamantite Rod"] = {
        spellID = 32665,
        itemID = 22462,
        skillReq = 350,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Rungor, Vodesiin" },
        },
        category = "Rod",
        skillRange = {  350, 360, 375, 390 },
        reagents = {
            { itemID = 25844, count = 1, name = "Adamantite Rod" },
            { itemID = 22446, count = 8, name = "Greater Planar Essence" },
            { itemID = 22449, count = 8, name = "Large Prismatic Shard" },
            { itemID = 23571, count = 1, name = "Primal Might" },
            { itemID = 22461, count = 1, name = "Runed Fel Iron Rod" },
        },
    },
    ["Runed Arcanite Rod"] = {
        spellID = 20051,
        itemID = 16207,
        skillReq = 290,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Lorelae Wintersong" },
        },
        category = "Rod",
        skillRange = {  290, 305, 322, 340 },
        reagents = {
            { itemID = 16206, count = 1, name = "Arcanite Rod" },
            { itemID = 13926, count = 1, name = "Golden Pearl" },
            { itemID = 16204, count = 10, name = "Illusion Dust" },
            { itemID = 16203, count = 4, name = "Greater Eternal Essence" },
            { itemID = 11145, count = 1, name = "Runed Truesilver Rod" },
            { itemID = 14344, count = 2, name = "Large Brilliant Shard" },
        },
    },
    ["Runed Copper Rod"] = {
        spellID = 7421,
        itemID = 6218,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Rod",
        skillRange = {  1, 5, 7, 10 },
        reagents = {
            { itemID = 6217, count = 1, name = "Copper Rod" },
            { itemID = 10940, count = 1, name = "Strange Dust" },
            { itemID = 10938, count = 1, name = "Lesser Magic Essence" },
        },
    },
    ["Runed Eternium Rod"] = {
        spellID = 32667,
        itemID = 22463,
        skillReq = 375,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Madame Ruby" },
        },
        category = "Rod",
        skillRange = {  370, 370, 385, 400},
        reagents = {
            { itemID = 25845, count = 1, name = "Eternium Rod" },
            { itemID = 22446, count = 12, name = "Greater Planar Essence" },
            { itemID = 22450, count = 2, name = "Void Crystal" },
            { itemID = 23571, count = 4, name = "Primal Might" },
            { itemID = 22462, count = 1, name = "Runed Adamantite Rod" },
        },
    },
    ["Runed Fel Iron Rod"] = {
        spellID = 32664,
        itemID = 22461,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Rod",
        skillRange = {  300, 310, 325, 340 },
        reagents = {
            { itemID = 25843, count = 1, name = "Fel Iron Rod" },
            { itemID = 16203, count = 4, name = "Greater Eternal Essence" },
            { itemID = 14344, count = 6, name = "Large Brilliant Shard" },
            { itemID = 16207, count = 1, name = "Runed Arcanite Rod" },
        },
    },
    ["Runed Golden Rod"] = {
        spellID = 13628,
        itemID = 11130,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Rod",
        skillRange = {  150, 175, 195, 215 },
        reagents = {
            { itemID = 11128, count = 1, name = "Golden Rod" },
            { itemID = 5500, count = 1, name = "Iridescent Pearl" },
            { itemID = 11082, count = 2, name = "Greater Astral Essence" },
            { itemID = 11083, count = 2, name = "Soul Dust" },
            { itemID = 6339, count = 1, name = "Runed Silver Rod" },
        },
    },
    ["Runed Silver Rod"] = {
        spellID = 7795,
        itemID = 6339,
        skillReq = 100,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Rod",
        skillRange = {  100, 130, 150, 170 },
        reagents = {
            { itemID = 6338, count = 1, name = "Silver Rod" },
            { itemID = 10940, count = 6, name = "Strange Dust" },
            { itemID = 10939, count = 3, name = "Greater Magic Essence" },
            { itemID = 6218, count = 1, name = "Runed Copper Rod" },
        },
    },
    ["Runed Truesilver Rod"] = {
        spellID = 13702,
        itemID = 11145,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Rod",
        skillRange = {  200, 220, 240, 260 },
        reagents = {
            { itemID = 11144, count = 1, name = "Truesilver Rod" },
            { itemID = 7971, count = 1, name = "Black Pearl" },
            { itemID = 11135, count = 2, name = "Greater Mystic Essence" },
            { itemID = 11137, count = 2, name = "Vision Dust" },
            { itemID = 11130, count = 1, name = "Runed Golden Rod" },
        },
    },

    -- ================================================================
    -- TRADE GOOD
    -- ================================================================
    ["Enchanted Leather"] = {
        spellID = 17181,
        rod = "Runed Truesilver Rod",
        itemID = 12810,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  250, 250, 255, 260 },
        reagents = {
            { itemID = 8170, count = 1, name = "Rugged Leather" },
            { itemID = 16202, count = 1, name = "Lesser Eternal Essence" },
        },
    },
    ["Enchanted Thorium"] = {
        spellID = 17180,
        rod = "Runed Truesilver Rod",
        itemID = 12655,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  250, 250, 255, 260 },
        reagents = {
            { itemID = 12359, count = 1, name = "Thorium Bar" },
            { itemID = 11176, count = 3, name = "Dream Dust" },
        },
    },
    ["Large Prismatic Shard"] = {
        spellID = 28022,
        rod = "Runed Fel Iron Rod",
        itemID = 22449,
        skillReq = 335,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Egomis, Lyna +1 more" },
        },
        category = "Trade Good",
        skillRange = {  335, 335, 335, 335},
        reagents = { { itemID = 22448, count = 3, name = "Small Prismatic Shard" } },
    },
    ["Nexus Transformation"] = {
        spellID = 42613,
        rod = "Runed Adamantite Rod",
        itemID = 22448,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  295, 295, 300, 305},
        reagents = { { itemID = 20725, count = 1, name = "Nexus Crystal" } },
    },
    ["Prismatic Sphere"] = {
        spellID = 28027,
        rod = "Runed Fel Iron Rod",
        itemID = 22460,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  325, 325, 330, 335 },
        reagents = { { itemID = 22449, count = 4, name = "Large Prismatic Shard" } },
    },
    ["Small Prismatic Shard"] = {
        spellID = 42615,
        rod = "Runed Fel Iron Rod",
        itemID = 22448,
        skillReq = 335,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  315, 315, 325, 335},
        reagents = { { itemID = 22449, count = 1, name = "Large Prismatic Shard" } },
    },
    ["Smoking Heart of the Mountain"] = {
        spellID = 15596,
        itemID = 11811,
        skillReq = 265,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  265, 285, 305, 325 },
        reagents = {
            { itemID = 11382, count = 1, name = "Blood of the Mountain" },
            { itemID = 7078, count = 1, name = "Essence of Fire" },
            { itemID = 14343, count = 3, name = "Small Brilliant Shard" },
        },
    },
    ["Void Shatter"] = {
        spellID = 45765,
        rod = "Runed Eternium Rod",
        itemID = 22449,
        skillReq = 375,
        sources = {
            { method = "reputation", faction = "Both", detail = "Shattered Sun Offensive @ Friendly" },
        },
        category = "Trade Good",
        skillRange = {  360, 360, 362, 365},
        reagents = { { itemID = 22450, count = 1, name = "Void Crystal" } },
    },
    ["Void Sphere"] = {
        spellID = 28028,
        rod = "Runed Adamantite Rod",
        itemID = 22459,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trade Good",
        skillRange = {  350, 360, 375, 390 },
        reagents = { { itemID = 22450, count = 2, name = "Void Crystal" } },
    },

    -- ================================================================
    -- WAND
    -- ================================================================
    ["Greater Magic Wand"] = {
        spellID = 14807,
        rod = "Runed Copper Rod",
        itemID = 11288,
        skillReq = 70,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Wand",
        skillRange = {  70, 110, 130, 150 },
        reagents = {
            { itemID = 4470, count = 1, name = "Simple Wood" },
            { itemID = 10939, count = 1, name = "Greater Magic Essence" },
        },
    },
    ["Greater Mystic Wand"] = {
        spellID = 14810,
        rod = "Runed Golden Rod",
        itemID = 11290,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Wand",
        skillRange = {  175, 195, 215, 235 },
        reagents = {
            { itemID = 11291, count = 1, name = "Star Wood" },
            { itemID = 11135, count = 1, name = "Greater Mystic Essence" },
            { itemID = 11137, count = 1, name = "Vision Dust" },
        },
    },
    ["Lesser Magic Wand"] = {
        spellID = 14293,
        rod = "Runed Copper Rod",
        itemID = 11287,
        skillReq = 10,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Wand",
        skillRange = {  10, 75, 95, 115 },
        reagents = {
            { itemID = 4470, count = 1, name = "Simple Wood" },
            { itemID = 10938, count = 1, name = "Lesser Magic Essence" },
        },
    },
    ["Lesser Mystic Wand"] = {
        spellID = 14809,
        rod = "Runed Golden Rod",
        itemID = 11289,
        skillReq = 155,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Wand",
        skillRange = {  155, 175, 195, 215 },
        reagents = {
            { itemID = 11291, count = 1, name = "Star Wood" },
            { itemID = 11134, count = 1, name = "Lesser Mystic Essence" },
            { itemID = 11083, count = 1, name = "Soul Dust" },
        },
    },

}

-- Enchanting rods (the required TOOL per recipe -> `rod` field above).
-- mask = TotemCategoryMask (build 2.5.5.68101); CUMULATIVE, so a rod SATISFIES
-- a requirement when rod.mask >= requiredMask (higher rod replaces lower in TBC).
ProfBuddy.EnchantingRods = {
    list = {
        { name = "Runed Copper Rod",     itemID = 6218,  mask = 1   },
        { name = "Runed Silver Rod",     itemID = 6339,  mask = 3   },
        { name = "Runed Golden Rod",     itemID = 11130, mask = 7   },
        { name = "Runed Truesilver Rod", itemID = 11145, mask = 15  },
        { name = "Runed Arcanite Rod",   itemID = 16207, mask = 31  },
        { name = "Runed Fel Iron Rod",   itemID = 22461, mask = 63  },
        { name = "Runed Adamantite Rod", itemID = 22462, mask = 127 },
        { name = "Runed Eternium Rod",   itemID = 22463, mask = 255 },
    },
    byName = {},
}
for _, r in ipairs(ProfBuddy.EnchantingRods.list) do
    ProfBuddy.EnchantingRods.byName[r.name] = r
end

RDB:RegisterProfession("Enchanting", recipes)
