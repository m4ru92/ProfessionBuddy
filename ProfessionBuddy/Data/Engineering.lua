----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Engineering.lua
-- Static recipe database for Engineering (TBC Classic)
--
-- skillRange = { orange, yellow, green, grey }
-- Values sourced from SkillLineAbility + SpellReagents + Item DB2 (build 2.5.4.44833)
----------------------------------------------------------------------

local RDB = ProfBuddy.RecipeDB

local recipes = {

    -- ================================================================
    -- AMMUNITION
    -- ================================================================
    ["Crafted Heavy Shot"] = {
        spellID = 3930,
        itemID = 8068,
        skillReq = 75,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 75, 85, 90, 95 },
        reagents = {
            { itemID = 4364, count = 1, name = "Coarse Blasting Powder" },
            { itemID = 2840, count = 1, name = "Copper Bar" },
        },
    },
    ["Crafted Light Shot"] = {
        spellID = 3920,
        itemID = 8067,
        skillReq = 30,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 30, 30, 45, 60 },
        reagents = {
            { itemID = 4357, count = 1, name = "Rough Blasting Powder" },
            { itemID = 2840, count = 1, name = "Copper Bar" },
        },
    },
    ["Crafted Solid Shot"] = {
        spellID = 3947,
        itemID = 8069,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 125, 125, 135, 145 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 2841, count = 1, name = "Bronze Bar" },
        },
    },
    ["Fel Iron Shells"] = {
        spellID = 30346,
        itemID = 23772,
        skillReq = 310,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 310, 310, 320, 330 },
        reagents = {
            { itemID = 23445, count = 2, name = "Fel Iron Bar" },
            { itemID = 23781, count = 1, name = "Elemental Blasting Powder" },
        },
    },
    ["Hi-Impact Mithril Slugs"] = {
        spellID = 12596,
        itemID = 10512,
        skillReq = 210,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 210, 210, 230, 250 },
        reagents = {
            { itemID = 3860, count = 1, name = "Mithril Bar" },
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
        },
    },
    ["Mithril Gyro-Shot"] = {
        spellID = 12621,
        itemID = 10513,
        skillReq = 245,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 245, 245, 265, 285 },
        reagents = {
            { itemID = 3860, count = 2, name = "Mithril Bar" },
            { itemID = 10505, count = 2, name = "Solid Blasting Powder" },
        },
    },
    ["Thorium Shells"] = {
        spellID = 19800,
        itemID = 15997,
        skillReq = 285,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Ammunition",
        skillRange = { 285, 295, 300, 305 },
        reagents = {
            { itemID = 12359, count = 2, name = "Thorium Bar" },
            { itemID = 15992, count = 1, name = "Dense Blasting Powder" },
        },
    },

    -- ================================================================
    -- ARMOR
    -- ================================================================
    ["Annihilator Holo-Gogs"] = {
        spellID = 46111,
        itemID = 34847,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32494, count = 1, name = "Destruction Holo-gogs" },
            { itemID = 22456, count = 4, name = "Primal Shadow" },
            { itemID = 21884, count = 4, name = "Primal Fire" },
            { itemID = 22457, count = 4, name = "Primal Mana" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Bloodvine Goggles"] = {
        spellID = 24356,
        itemID = 19999,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Friendly" },
        },
        category = "Armor",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 19726, count = 4, name = "Bloodvine" },
            { itemID = 19774, count = 5, name = "Souldarite" },
            { itemID = 16006, count = 2, name = "Delicate Arcanite Converter" },
            { itemID = 12804, count = 8, name = "Powerful Mojo" },
            { itemID = 12810, count = 4, name = "Enchanted Leather" },
        },
    },
    ["Bloodvine Lens"] = {
        spellID = 24357,
        itemID = 19998,
        skillReq = 300,
        sources = {
            { method = "reputation", faction = "Both", detail = "Zandalar Tribe @ Neutral" },
        },
        category = "Armor",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 19726, count = 5, name = "Bloodvine" },
            { itemID = 19774, count = 5, name = "Souldarite" },
            { itemID = 16006, count = 1, name = "Delicate Arcanite Converter" },
            { itemID = 12804, count = 8, name = "Powerful Mojo" },
            { itemID = 12810, count = 4, name = "Enchanted Leather" },
        },
    },
    ["Bright-Eye Goggles"] = {
        spellID = 12587,
        itemID = 10499,
        skillReq = 175,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 175, 195, 205, 215 },
        reagents = {
            { itemID = 4234, count = 6, name = "Heavy Leather" },
            { itemID = 3864, count = 2, name = "Citrine" },
        },
    },
    ["Catseye Ultra Goggles"] = {
        spellID = 12607,
        itemID = 10501,
        skillReq = 220,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 220, 240, 250, 260 },
        reagents = {
            { itemID = 4304, count = 4, name = "Thick Leather" },
            { itemID = 7909, count = 2, name = "Aquamarine" },
            { itemID = 10592, count = 1, name = "Catseye Elixir" },
        },
    },
    ["Cogspinner Goggles"] = {
        spellID = 30316,
        itemID = 23758,
        skillReq = 340,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Lebowski, Mixie Farshot" },
        },
        category = "Armor",
        skillRange = { 340, 350, 360, 370 },
        reagents = {
            { itemID = 23793, count = 4, name = "Heavy Knothide Leather" },
            { itemID = 23077, count = 2, name = "Blood Garnet" },
            { itemID = 22445, count = 8, name = "Arcane Dust" },
        },
    },
    ["Craftsman's Monocle"] = {
        spellID = 3966,
        itemID = 4393,
        skillReq = 185,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 185, 205, 215, 225 },
        reagents = {
            { itemID = 4234, count = 6, name = "Heavy Leather" },
            { itemID = 3864, count = 2, name = "Citrine" },
        },
    },
    ["Deathblow X11 Goggles"] = {
        spellID = 41317,
        itemID = 32478,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23436, count = 2, name = "Living Ruby" },
        },
    },
    ["Deepdive Helmet"] = {
        spellID = 12617,
        itemID = 10506,
        skillReq = 230,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Jubie Gadgetspring" },
        },
        category = "Armor",
        skillRange = { 230, 250, 260, 270 },
        reagents = {
            { itemID = 3860, count = 8, name = "Mithril Bar" },
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 6037, count = 1, name = "Truesilver Bar" },
            { itemID = 818, count = 4, name = "Tigerseye" },
            { itemID = 774, count = 4, name = "Malachite" },
        },
    },
    ["Destruction Holo-gogs"] = {
        spellID = 41320,
        itemID = 32494,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23438, count = 2, name = "Star of Elune" },
        },
    },
    ["Fire Goggles"] = {
        spellID = 12594,
        itemID = 10500,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 205, 225, 235, 245 },
        reagents = {
            { itemID = 4385, count = 1, name = "Green Tinted Goggles" },
            { itemID = 3864, count = 2, name = "Citrine" },
            { itemID = 7068, count = 2, name = "Elemental Fire" },
            { itemID = 4234, count = 4, name = "Heavy Leather" },
        },
    },
    ["Flying Tiger Goggles"] = {
        spellID = 3934,
        itemID = 4368,
        skillReq = 100,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 100, 130, 145, 160 },
        reagents = {
            { itemID = 2318, count = 6, name = "Light Leather" },
            { itemID = 818, count = 2, name = "Tigerseye" },
        },
    },
    ["Foreman's Enchanted Helmet"] = {
        spellID = 30565,
        itemID = 23838,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 375, 375, 385, 395 },
        reagents = {
            { itemID = 24272, count = 4, name = "Shadowcloth" },
            { itemID = 22457, count = 12, name = "Primal Mana" },
            { itemID = 22451, count = 12, name = "Primal Air" },
        },
    },
    ["Foreman's Reinforced Helmet"] = {
        spellID = 30566,
        itemID = 23839,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 375, 375, 385, 395 },
        reagents = {
            { itemID = 23573, count = 8, name = "Hardened Adamantite Bar" },
            { itemID = 22452, count = 12, name = "Primal Earth" },
            { itemID = 21884, count = 12, name = "Primal Fire" },
        },
    },
    ["Furious Gizmatic Goggles"] = {
        spellID = 40274,
        itemID = 32461,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23436, count = 2, name = "Living Ruby" },
        },
    },
    ["Gadgetstorm Goggles"] = {
        spellID = 41315,
        itemID = 32476,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23436, count = 2, name = "Living Ruby" },
        },
    },
    ["Gnomish Battle Goggles"] = {
        spellID = 30575,
        itemID = 23829,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 375, 375, 385, 395 },
        reagents = {
            { itemID = 23793, count = 8, name = "Heavy Knothide Leather" },
            { itemID = 22456, count = 12, name = "Primal Shadow" },
            { itemID = 22452, count = 12, name = "Primal Earth" },
            { itemID = 21884, count = 12, name = "Primal Fire" },
            { itemID = 23436, count = 2, name = "Living Ruby" },
        },
    },
    ["Gnomish Goggles"] = {
        spellID = 12897,
        itemID = 10545,
        skillReq = 210,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 210, 230, 240, 250 },
        reagents = {
            { itemID = 10500, count = 1, name = "Fire Goggles" },
            { itemID = 10559, count = 1, name = "Mithril Tube" },
            { itemID = 10558, count = 2, name = "Gold Power Core" },
            { itemID = 8151, count = 2, name = "Flask of Mojo" },
            { itemID = 4234, count = 2, name = "Heavy Leather" },
        },
    },
    ["Gnomish Harm Prevention Belt"] = {
        spellID = 12903,
        itemID = 10721,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 215, 235, 245, 255 },
        reagents = {
            { itemID = 7387, count = 1, name = "Dusky Belt" },
            { itemID = 3860, count = 4, name = "Mithril Bar" },
            { itemID = 6037, count = 2, name = "Truesilver Bar" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 7909, count = 2, name = "Aquamarine" },
        },
    },
    ["Gnomish Mind Control Cap"] = {
        spellID = 12907,
        itemID = 10726,
        skillReq = 235,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 235, 255, 265, 275 },
        reagents = {
            { itemID = 3860, count = 10, name = "Mithril Bar" },
            { itemID = 6037, count = 4, name = "Truesilver Bar" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 7910, count = 2, name = "Star Ruby" },
            { itemID = 4338, count = 4, name = "Mageweave Cloth" },
        },
    },
    ["Gnomish Power Goggles"] = {
        spellID = 30574,
        itemID = 23828,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 375, 375, 385, 395 },
        reagents = {
            { itemID = 24271, count = 4, name = "Spellcloth" },
            { itemID = 21884, count = 8, name = "Primal Fire" },
            { itemID = 22451, count = 8, name = "Primal Air" },
            { itemID = 22452, count = 8, name = "Primal Earth" },
            { itemID = 21885, count = 8, name = "Primal Water" },
            { itemID = 23437, count = 2, name = "Talasite" },
        },
    },
    ["Gnomish Rocket Boots"] = {
        spellID = 12905,
        itemID = 10724,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 225, 245, 255, 265 },
        reagents = {
            { itemID = 10026, count = 1, name = "Black Mageweave Boots" },
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 4234, count = 4, name = "Heavy Leather" },
            { itemID = 10505, count = 8, name = "Solid Blasting Powder" },
            { itemID = 4389, count = 4, name = "Gyrochronatom" },
        },
    },
    ["Goblin Construction Helmet"] = {
        spellID = 12718,
        itemID = 10543,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 205, 225, 235, 245 },
        reagents = {
            { itemID = 3860, count = 8, name = "Mithril Bar" },
            { itemID = 3864, count = 1, name = "Citrine" },
            { itemID = 7068, count = 4, name = "Elemental Fire" },
        },
    },
    ["Goblin Mining Helmet"] = {
        spellID = 12717,
        itemID = 10542,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 205, 225, 235, 245 },
        reagents = {
            { itemID = 3860, count = 8, name = "Mithril Bar" },
            { itemID = 3864, count = 1, name = "Citrine" },
            { itemID = 7067, count = 4, name = "Elemental Earth" },
        },
    },
    ["Goblin Rocket Boots"] = {
        spellID = 8895,
        itemID = 7189,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 225, 245, 255, 265 },
        reagents = {
            { itemID = 10026, count = 1, name = "Black Mageweave Boots" },
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 4234, count = 4, name = "Heavy Leather" },
            { itemID = 9061, count = 2, name = "Goblin Rocket Fuel" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
        },
    },
    ["Goblin Rocket Helmet"] = {
        spellID = 12758,
        itemID = 10588,
        skillReq = 245,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 245, 265, 275, 285 },
        reagents = {
            { itemID = 10543, count = 1, name = "Goblin Construction Helmet" },
            { itemID = 9061, count = 4, name = "Goblin Rocket Fuel" },
            { itemID = 3860, count = 4, name = "Mithril Bar" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
        },
    },
    ["Green Lens"] = {
        spellID = 12622,
        itemID = 10504,
        skillReq = 245,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 245, 265, 275, 285 },
        reagents = {
            { itemID = 4304, count = 8, name = "Thick Leather" },
            { itemID = 1529, count = 3, name = "Jade" },
            { itemID = 7909, count = 3, name = "Aquamarine" },
            { itemID = 10286, count = 2, name = "Heart of the Wild" },
            { itemID = 8153, count = 2, name = "Wildvine" },
        },
    },
    ["Green Tinted Goggles"] = {
        spellID = 3956,
        itemID = 4385,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 150, 175, 187, 200 },
        reagents = {
            { itemID = 2319, count = 4, name = "Medium Leather" },
            { itemID = 1206, count = 2, name = "Moss Agate" },
            { itemID = 4368, count = 1, name = "Flying Tiger Goggles" },
        },
    },
    ["Hard Khorium Goggles"] = {
        spellID = 46115,
        itemID = 34357,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32473, count = 1, name = "Tankatronic Goggles" },
            { itemID = 35128, count = 2, name = "Hardened Khorium" },
            { itemID = 23571, count = 1, name = "Primal Might" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Hyper-Magnified Moon Specs"] = {
        spellID = 46109,
        itemID = 35182,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32480, count = 1, name = "Magnified Moon Specs" },
            { itemID = 21885, count = 6, name = "Primal Water" },
            { itemID = 21886, count = 12, name = "Primal Life" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Hyper-Vision Goggles"] = {
        spellID = 30325,
        itemID = 23763,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 360, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 4, name = "Heavy Knothide Leather" },
            { itemID = 23449, count = 2, name = "Khorium Bar" },
            { itemID = 23441, count = 2, name = "Nightseye" },
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
        },
    },
    ["Justicebringer 2000 Specs"] = {
        spellID = 41311,
        itemID = 32472,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23440, count = 2, name = "Dawnstone" },
        },
    },
    ["Justicebringer 3000 Specs"] = {
        spellID = 46107,
        itemID = 35185,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32472, count = 1, name = "Justicebringer 2000 Specs" },
            { itemID = 21886, count = 8, name = "Primal Life" },
            { itemID = 22457, count = 8, name = "Primal Mana" },
            { itemID = 22452, count = 8, name = "Primal Earth" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Lightning Etched Specs"] = {
        spellID = 46112,
        itemID = 34355,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32476, count = 1, name = "Gadgetstorm Goggles" },
            { itemID = 23571, count = 2, name = "Primal Might" },
            { itemID = 22451, count = 2, name = "Primal Air" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Living Replicator Specs"] = {
        spellID = 41316,
        itemID = 32475,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23439, count = 2, name = "Noble Topaz" },
        },
    },
    ["Magnified Moon Specs"] = {
        spellID = 41319,
        itemID = 32480,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23437, count = 2, name = "Talasite" },
        },
    },
    ["Master Engineer's Goggles"] = {
        spellID = 19825,
        itemID = 16008,
        skillReq = 290,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 290, 310, 320, 330 },
        reagents = {
            { itemID = 10500, count = 1, name = "Fire Goggles" },
            { itemID = 12364, count = 2, name = "Huge Emerald" },
            { itemID = 12810, count = 4, name = "Enchanted Leather" },
        },
    },
    ["Mayhem Projection Goggles"] = {
        spellID = 46114,
        itemID = 34354,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32461, count = 1, name = "Furious Gizmatic Goggles" },
            { itemID = 21884, count = 10, name = "Primal Fire" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Nigh-Invulnerability Belt"] = {
        spellID = 30570,
        itemID = 23825,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 350, 360, 370, 380 },
        reagents = {
            { itemID = 23793, count = 8, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 4, name = "Khorium Power Core" },
            { itemID = 21886, count = 10, name = "Primal Life" },
            { itemID = 22456, count = 10, name = "Primal Shadow" },
            { itemID = 16006, count = 2, name = "Delicate Arcanite Converter" },
        },
    },
    ["Power Amplification Goggles"] = {
        spellID = 30317,
        itemID = 23761,
        skillReq = 340,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 340, 350, 360, 370 },
        reagents = {
            { itemID = 23793, count = 4, name = "Heavy Knothide Leather" },
            { itemID = 21929, count = 2, name = "Flame Spessarite" },
            { itemID = 22445, count = 8, name = "Arcane Dust" },
        },
    },
    ["Powerheal 4000 Lens"] = {
        spellID = 41321,
        itemID = 32495,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23439, count = 2, name = "Noble Topaz" },
        },
    },
    ["Powerheal 9000 Lens"] = {
        spellID = 46108,
        itemID = 35181,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32495, count = 1, name = "Powerheal 4000 Lens" },
            { itemID = 21886, count = 8, name = "Primal Life" },
            { itemID = 22457, count = 8, name = "Primal Mana" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Primal-Attuned Goggles"] = {
        spellID = 46110,
        itemID = 35184,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32475, count = 1, name = "Living Replicator Specs" },
            { itemID = 21886, count = 5, name = "Primal Life" },
            { itemID = 22457, count = 5, name = "Primal Mana" },
            { itemID = 21885, count = 5, name = "Primal Water" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Quad Deathblow X44 Goggles"] = {
        spellID = 46116,
        itemID = 34353,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32478, count = 1, name = "Deathblow X11 Goggles" },
            { itemID = 22456, count = 12, name = "Primal Shadow" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Rocket Boots Xtreme"] = {
        spellID = 30556,
        itemID = 23824,
        skillReq = 355,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 355, 365, 375, 385 },
        reagents = {
            { itemID = 23793, count = 8, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 2, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
        },
    },
    ["Rocket Boots Xtreme Lite"] = {
        spellID = 46697,
        itemID = 35581,
        skillReq = 355,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 355, 365, 375, 385 },
        reagents = {
            { itemID = 21840, count = 8, name = "Bolt of Netherweave" },
            { itemID = 23786, count = 2, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
        },
    },
    ["Rose Colored Goggles"] = {
        spellID = 12618,
        itemID = 10503,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 230, 250, 260, 270 },
        reagents = {
            { itemID = 4304, count = 6, name = "Thick Leather" },
            { itemID = 7910, count = 2, name = "Star Ruby" },
        },
    },
    ["Shadow Goggles"] = {
        spellID = 3940,
        itemID = 4373,
        skillReq = 120,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 120, 145, 157, 170 },
        reagents = {
            { itemID = 2319, count = 4, name = "Medium Leather" },
            { itemID = 1210, count = 2, name = "Shadowgem" },
        },
    },
    ["Spellpower Goggles Xtreme"] = {
        spellID = 12615,
        itemID = 10502,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 225, 245, 255, 265 },
        reagents = {
            { itemID = 4304, count = 4, name = "Thick Leather" },
            { itemID = 7910, count = 2, name = "Star Ruby" },
        },
    },
    ["Spellpower Goggles Xtreme Plus"] = {
        spellID = 19794,
        itemID = 15999,
        skillReq = 270,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 270, 290, 300, 310 },
        reagents = {
            { itemID = 10502, count = 1, name = "Spellpower Goggles Xtreme" },
            { itemID = 7910, count = 4, name = "Star Ruby" },
            { itemID = 12810, count = 2, name = "Enchanted Leather" },
            { itemID = 14047, count = 8, name = "Runecloth" },
        },
    },
    ["Surestrike Goggles v2.0"] = {
        spellID = 41314,
        itemID = 32474,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23441, count = 2, name = "Nightseye" },
        },
    },
    ["Surestrike Goggles v3.0"] = {
        spellID = 46113,
        itemID = 34356,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32474, count = 1, name = "Surestrike Goggles v2.0" },
            { itemID = 22451, count = 12, name = "Primal Air" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },
    ["Tankatronic Goggles"] = {
        spellID = 41312,
        itemID = 32473,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23437, count = 2, name = "Talasite" },
        },
    },
    ["Ultra-Spectropic Detection Goggles"] = {
        spellID = 30318,
        itemID = 23762,
        skillReq = 350,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Captured Gnome, Lebowski" },
        },
        category = "Armor",
        skillRange = { 350, 360, 370, 380 },
        reagents = {
            { itemID = 23793, count = 4, name = "Heavy Knothide Leather" },
            { itemID = 23449, count = 2, name = "Khorium Bar" },
            { itemID = 23079, count = 2, name = "Deep Peridot" },
            { itemID = 22448, count = 2, name = "Small Prismatic Shard" },
        },
    },
    ["Wonderheal XT40 Shades"] = {
        spellID = 41318,
        itemID = 32479,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 370, 380, 390 },
        reagents = {
            { itemID = 23793, count = 6, name = "Heavy Knothide Leather" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
            { itemID = 23440, count = 2, name = "Dawnstone" },
        },
    },
    ["Wonderheal XT68 Shades"] = {
        spellID = 46106,
        itemID = 35183,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Armor",
        skillRange = { 1, 390, 410, 430 },
        reagents = {
            { itemID = 32479, count = 1, name = "Wonderheal XT40 Shades" },
            { itemID = 21885, count = 4, name = "Primal Water" },
            { itemID = 22457, count = 8, name = "Primal Mana" },
            { itemID = 23572, count = 4, name = "Primal Nether" },
        },
    },

    -- ================================================================
    -- BAG
    -- ================================================================
    ["Fel Iron Toolbox"] = {
        spellID = 30348,
        itemID = 23774,
        skillReq = 325,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Feera, Wind Trader Lathrai +1 more" },
        },
        category = "Bag",
        skillRange = { 325, 325, 335, 345 },
        reagents = {
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
            { itemID = 23445, count = 5, name = "Fel Iron Bar" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
        },
    },

    -- ================================================================
    -- COMPANION
    -- ================================================================
    ["Alarm-O-Bot"] = {
        spellID = 23096,
        itemID = 18645,
        skillReq = 265,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Companion",
        skillRange = { 265, 275, 280, 285 },
        reagents = {
            { itemID = 12359, count = 4, name = "Thorium Bar" },
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 8170, count = 4, name = "Rugged Leather" },
            { itemID = 7910, count = 1, name = "Star Ruby" },
            { itemID = 7191, count = 1, name = "Fused Wiring" },
        },
    },
    ["Crashin' Thrashin' Robot"] = {
        spellID = 30337,
        itemID = 23767,
        skillReq = 325,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Companion",
        skillRange = { 325, 335, 345, 355 },
        reagents = {
            { itemID = 23784, count = 1, name = "Adamantite Frame" },
            { itemID = 23782, count = 2, name = "Fel Iron Casing" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Field Repair Bot 110G"] = {
        spellID = 44391,
        itemID = 34113,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Companion",
        skillRange = { 360, 370, 380, 390 },
        reagents = {
            { itemID = 23446, count = 8, name = "Adamantite Bar" },
            { itemID = 23783, count = 8, name = "Handful of Fel Iron Bolts" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
        },
    },
    ["Field Repair Bot 74A"] = {
        spellID = 22704,
        itemID = 18232,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both", detail = "ground object in Blackrock Depths (300 Engineering)" },
        },
        category = "Companion",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 12359, count = 16, name = "Thorium Bar" },
            { itemID = 7191, count = 2, name = "Fused Wiring" },
        },
    },
    ["Mechanical Squirrel"] = {
        spellID = 3928,
        itemID = 4401,
        skillReq = 75,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Companion",
        skillRange = { 75, 105, 120, 135 },
        reagents = {
            { itemID = 4363, count = 1, name = "Copper Modulator" },
            { itemID = 4359, count = 1, name = "Handful of Copper Bolts" },
            { itemID = 2840, count = 1, name = "Copper Bar" },
            { itemID = 774, count = 2, name = "Malachite" },
        },
    },
    ["Tranquil Mechanical Yeti"] = {
        spellID = 26011,
        itemID = 21277,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Companion",
        skillRange = { 250, 320, 330, 340 },
        reagents = {
            { itemID = 15407, count = 1, name = "Cured Rugged Hide" },
            { itemID = 15994, count = 4, name = "Thorium Widget" },
            { itemID = 7079, count = 2, name = "Globe of Water" },
            { itemID = 18631, count = 2, name = "Truesilver Transformer" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
        },
    },

    -- ================================================================
    -- DEVICE
    -- ================================================================
    ["Adamantite Arrow Maker"] = {
        spellID = 43676,
        itemID = 20475,
        skillReq = 335,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 23446, count = 1, name = "Adamantite Bar" },
            { itemID = 4470, count = 4, name = "Simple Wood" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Adamantite Frame"] = {
        spellID = 30306,
        itemID = 23784,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 325, 325, 330, 335 },
        reagents = {
            { itemID = 23446, count = 4, name = "Adamantite Bar" },
            { itemID = 22452, count = 1, name = "Primal Earth" },
        },
    },
    ["Adamantite Shell Machine"] = {
        spellID = 30347,
        itemID = 34504,
        skillReq = 335,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Feera, Wind Trader Lathrai +1 more" },
        },
        category = "Device",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 23446, count = 1, name = "Adamantite Bar" },
            { itemID = 23781, count = 2, name = "Elemental Blasting Powder" },
            { itemID = 4470, count = 4, name = "Simple Wood" },
        },
    },
    ["Advanced Target Dummy"] = {
        spellID = 3965,
        itemID = 4392,
        skillReq = 185,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 185, 185, 205, 225 },
        reagents = {
            { itemID = 4387, count = 1, name = "Iron Strut" },
            { itemID = 4382, count = 1, name = "Bronze Framework" },
            { itemID = 4389, count = 1, name = "Gyrochronatom" },
            { itemID = 4234, count = 4, name = "Heavy Leather" },
        },
    },
    ["Aquadynamic Fish Attractor"] = {
        spellID = 9271,
        itemID = 6533,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 150, 150, 160, 170 },
        reagents = {
            { itemID = 2841, count = 2, name = "Bronze Bar" },
            { itemID = 6530, count = 1, name = "Nightcrawlers" },
            { itemID = 4364, count = 1, name = "Coarse Blasting Powder" },
        },
    },
    ["Arcanite Dragonling"] = {
        spellID = 19830,
        itemID = 0,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 300, 300, 300, 300},
    },
    ["Battle Chicken"] = {
        spellID = 13166,
        itemID = 0,
        skillReq = 230,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Device",
        skillRange = { 0, 0, 0, 0},
    },
    ["Blue Firework"] = {
        spellID = 23067,
        itemID = 9312,
        skillReq = 150,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Darian Singh, Gearcutter Cogspinner" },
        },
        category = "Device",
        skillRange = { 150, 150, 162, 175 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4234, count = 1, name = "Heavy Leather" },
        },
    },
    ["Bronze Framework"] = {
        spellID = 3953,
        itemID = 4382,
        skillReq = 145,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 145, 145, 170, 195 },
        reagents = {
            { itemID = 2841, count = 2, name = "Bronze Bar" },
            { itemID = 2319, count = 1, name = "Medium Leather" },
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["Bronze Tube"] = {
        spellID = 3938,
        itemID = 4371,
        skillReq = 105,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 105, 105, 130, 155 },
        reagents = {
            { itemID = 2841, count = 2, name = "Bronze Bar" },
            { itemID = 2880, count = 1, name = "Weak Flux" },
        },
    },
    ["Coarse Blasting Powder"] = {
        spellID = 3929,
        itemID = 4364,
        skillReq = 75,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 75, 85, 90, 95 },
        reagents = { { itemID = 2836, count = 1, name = "Coarse Stone" } },
    },
    ["Compact Harvest Reaper Kit"] = {
        spellID = 3963,
        itemID = 4391,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 175, 175, 195, 215 },
        reagents = {
            { itemID = 4387, count = 2, name = "Iron Strut" },
            { itemID = 4382, count = 1, name = "Bronze Framework" },
            { itemID = 4389, count = 2, name = "Gyrochronatom" },
            { itemID = 4234, count = 4, name = "Heavy Leather" },
        },
    },
    ["Copper Modulator"] = {
        spellID = 3926,
        itemID = 4363,
        skillReq = 65,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 65, 95, 110, 125 },
        reagents = {
            { itemID = 4359, count = 2, name = "Handful of Copper Bolts" },
            { itemID = 2840, count = 1, name = "Copper Bar" },
            { itemID = 2589, count = 2, name = "Linen Cloth" },
        },
    },
    ["Copper Tube"] = {
        spellID = 3924,
        itemID = 4361,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 50, 80, 95, 110 },
        reagents = {
            { itemID = 2840, count = 2, name = "Copper Bar" },
            { itemID = 2880, count = 1, name = "Weak Flux" },
        },
    },
    ["Delicate Arcanite Converter"] = {
        spellID = 19815,
        itemID = 16006,
        skillReq = 285,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Xizzer Fizzbolt" },
        },
        category = "Device",
        skillRange = { 285, 305, 315, 325 },
        reagents = {
            { itemID = 12360, count = 1, name = "Arcanite Bar" },
            { itemID = 14227, count = 1, name = "Ironweb Spider Silk" },
        },
    },
    ["Dense Blasting Powder"] = {
        spellID = 19788,
        itemID = 15992,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 250, 250, 255, 260 },
        reagents = { { itemID = 12365, count = 2, name = "Dense Stone" } },
    },
    ["Discombobulator Ray"] = {
        spellID = 3959,
        itemID = 4388,
        skillReq = 160,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 160, 180, 190, 200 },
        reagents = {
            { itemID = 4375, count = 3, name = "Whirring Bronze Gizmo" },
            { itemID = 4306, count = 2, name = "Silk Cloth" },
            { itemID = 1529, count = 1, name = "Jade" },
            { itemID = 4371, count = 1, name = "Bronze Tube" },
        },
    },
    ["Elemental Blasting Powder"] = {
        spellID = 30303,
        itemID = 23781,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 300, 300, 310, 320 },
        reagents = {
            { itemID = 22574, count = 1, name = "Mote of Fire" },
            { itemID = 22573, count = 2, name = "Mote of Earth" },
        },
    },
    ["Explosive Sheep"] = {
        spellID = 3955,
        itemID = 4384,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 150, 175, 187, 200 },
        reagents = {
            { itemID = 4382, count = 1, name = "Bronze Framework" },
            { itemID = 4375, count = 1, name = "Whirring Bronze Gizmo" },
            { itemID = 4377, count = 2, name = "Heavy Blasting Powder" },
            { itemID = 2592, count = 2, name = "Wool Cloth" },
        },
    },
    ["Fel Iron Casing"] = {
        spellID = 30304,
        itemID = 23782,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 300, 300, 310, 320 },
        reagents = { { itemID = 23445, count = 3, name = "Fel Iron Bar" } },
    },
    ["Felsteel Stabilizer"] = {
        spellID = 30309,
        itemID = 23787,
        skillReq = 340,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 340, 350, 360, 370 },
        reagents = { { itemID = 23448, count = 2, name = "Felsteel Bar" } },
    },
    ["Firework Cluster Launcher"] = {
        spellID = 26443,
        itemID = 21570,
        skillReq = 275,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Cluster Launcher" },
        },
        category = "Device",
        skillRange = { 275, 295, 305, 315 },
        reagents = {
            { itemID = 9060, count = 4, name = "Inlaid Mithril Cylinder" },
            { itemID = 9061, count = 4, name = "Goblin Rocket Fuel" },
            { itemID = 18631, count = 2, name = "Truesilver Transformer" },
            { itemID = 10561, count = 1, name = "Mithril Casing" },
        },
    },
    ["Firework Launcher"] = {
        spellID = 26442,
        itemID = 21569,
        skillReq = 225,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: Firework Launcher" },
        },
        category = "Device",
        skillRange = { 225, 245, 255, 265 },
        reagents = {
            { itemID = 9060, count = 1, name = "Inlaid Mithril Cylinder" },
            { itemID = 9061, count = 1, name = "Goblin Rocket Fuel" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 10561, count = 1, name = "Mithril Casing" },
        },
    },
    ["Flame Deflector"] = {
        spellID = 3944,
        itemID = 4376,
        skillReq = 125,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 125, 125, 150, 175 },
        reagents = {
            { itemID = 4375, count = 1, name = "Whirring Bronze Gizmo" },
            { itemID = 4402, count = 1, name = "Small Flame Sac" },
        },
    },
    ["Flying Machine"] = {
        spellID = 44155,
        itemID = 34060,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 350, 375, 380, 385 },
        reagents = {
            { itemID = 23784, count = 2, name = "Adamantite Frame" },
            { itemID = 23445, count = 30, name = "Fel Iron Bar" },
            { itemID = 23783, count = 8, name = "Handful of Fel Iron Bolts" },
            { itemID = 11291, count = 8, name = "Star Wood" },
            { itemID = 23446, count = 5, name = "Adamantite Bar" },
            { itemID = 23819, count = 4, name = "Elemental Seaforium Charge" },
        },
    },
    ["Force Reactive Disk"] = {
        spellID = 22797,
        itemID = 18168,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 12360, count = 6, name = "Arcanite Bar" },
            { itemID = 16006, count = 2, name = "Delicate Arcanite Converter" },
            { itemID = 7082, count = 8, name = "Essence of Air" },
            { itemID = 12803, count = 12, name = "Living Essence" },
            { itemID = 7076, count = 8, name = "Essence of Earth" },
        },
    },
    ["Fused Wiring"] = {
        spellID = 39895,
        itemID = 7191,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Viggz Shinesparked, Xizzer Fizzbolt" },
        },
        category = "Device",
        skillRange = { 275, 275, 280, 285 },
        reagents = {
            { itemID = 20816, count = 3, name = "Delicate Copper Wire" },
            { itemID = 7078, count = 2, name = "Essence of Fire" },
        },
    },
    ["Gnomish Flame Turret"] = {
        spellID = 30568,
        itemID = 23841,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 325, 335, 345, 355 },
        reagents = {
            { itemID = 23784, count = 1, name = "Adamantite Frame" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
            { itemID = 23781, count = 3, name = "Elemental Blasting Powder" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
        },
    },
    ["Goblin Land Mine"] = {
        spellID = 3968,
        itemID = 4395,
        skillReq = 195,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 195, 215, 225, 235 },
        reagents = {
            { itemID = 4377, count = 3, name = "Heavy Blasting Powder" },
            { itemID = 3575, count = 2, name = "Iron Bar" },
            { itemID = 4389, count = 1, name = "Gyrochronatom" },
        },
    },
    ["Gold Power Core"] = {
        spellID = 12584,
        itemID = 10558,
        skillReq = 150,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 150, 150, 170, 190 },
        reagents = { { itemID = 3577, count = 1, name = "Gold Bar" } },
    },
    ["Green Firework"] = {
        spellID = 23068,
        itemID = 9313,
        skillReq = 150,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Crazk Sparks, Gagsprocket" },
        },
        category = "Device",
        skillRange = { 150, 150, 162, 175 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4234, count = 1, name = "Heavy Leather" },
        },
    },
    ["Green Smoke Flare"] = {
        spellID = 30344,
        itemID = 23771,
        skillReq = 335,
        sources = {
            { method = "reputation", faction = "Both", detail = "Cenarion Expedition @ Neutral" },
        },
        category = "Device",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 23781, count = 1, name = "Elemental Blasting Powder" },
            { itemID = 21877, count = 1, name = "Netherweave Cloth" },
            { itemID = 2605, count = 1, name = "Green Dye" },
        },
    },
    ["Gyrochronatom"] = {
        spellID = 3961,
        itemID = 4389,
        skillReq = 170,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 170, 170, 190, 210 },
        reagents = {
            { itemID = 3575, count = 1, name = "Iron Bar" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
        },
    },
    ["Gyromatic Micro-Adjustor"] = {
        spellID = 12590,
        itemID = 10498,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 175, 175, 195, 215 },
        reagents = { { itemID = 3859, count = 4, name = "Steel Bar" } },
    },
    ["Handful of Copper Bolts"] = {
        spellID = 3922,
        itemID = 4359,
        skillReq = 30,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 30, 45, 52, 60 },
        yield = 2,
        reagents = { { itemID = 2840, count = 1, name = "Copper Bar" } },
    },
    ["Handful of Fel Iron Bolts"] = {
        spellID = 30305,
        itemID = 23783,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 300, 300, 305, 310 },
        yield = 3,
        reagents = { { itemID = 23445, count = 1, name = "Fel Iron Bar" } },
    },
    ["Hardened Adamantite Tube"] = {
        spellID = 30307,
        itemID = 23785,
        skillReq = 340,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 340, 350, 360, 370 },
        reagents = { { itemID = 23573, count = 3, name = "Hardened Adamantite Bar" } },
    },
    ["Healing Potion Injector"] = {
        spellID = 30551,
        itemID = 33092,
        skillReq = 330,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 330, 330, 340, 350 },
        reagents = {
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
            { itemID = 23783, count = 1, name = "Handful of Fel Iron Bolts" },
            { itemID = 21887, count = 2, name = "Knothide Leather" },
            { itemID = 22829, count = 20, name = "Super Healing Potion" },
        },
    },
    ["Heavy Blasting Powder"] = {
        spellID = 3945,
        itemID = 4377,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 125, 125, 135, 145 },
        reagents = { { itemID = 2838, count = 1, name = "Heavy Stone" } },
    },
    ["Ice Deflector"] = {
        spellID = 3957,
        itemID = 4386,
        skillReq = 155,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Rizz Loosebolt" },
        },
        category = "Device",
        skillRange = { 155, 175, 185, 195 },
        reagents = {
            { itemID = 4375, count = 1, name = "Whirring Bronze Gizmo" },
            { itemID = 3829, count = 1, name = "Frost Oil" },
        },
    },
    ["Icy Blasting Primers"] = {
        spellID = 39971,
        itemID = 32423,
        skillReq = 335,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 335, 335, 340, 345 },
        reagents = {
            { itemID = 21885, count = 1, name = "Primal Water" },
            { itemID = 23781, count = 2, name = "Elemental Blasting Powder" },
            { itemID = 21877, count = 2, name = "Netherweave Cloth" },
        },
    },
    ["Inlaid Mithril Cylinder Plans"] = {
        spellID = 12895,
        itemID = 10713,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 205, 205, 205, 205 },
        reagents = {
            { itemID = 10648, count = 1, name = "Blank Parchment" },
            { itemID = 10647, count = 1, name = "Engineer's Ink" },
        },
    },
    ["Iron Strut"] = {
        spellID = 3958,
        itemID = 4387,
        skillReq = 160,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 160, 160, 170, 180 },
        reagents = { { itemID = 3575, count = 2, name = "Iron Bar" } },
    },
    ["Khorium Power Core"] = {
        spellID = 30308,
        itemID = 23786,
        skillReq = 340,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 340, 350, 360, 370 },
        reagents = {
            { itemID = 23449, count = 3, name = "Khorium Bar" },
            { itemID = 21884, count = 1, name = "Primal Fire" },
        },
    },
    ["Lifelike Mechanical Toad"] = {
        spellID = 19793,
        itemID = 15996,
        skillReq = 265,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 265, 285, 295, 305 },
        reagents = {
            { itemID = 12803, count = 1, name = "Living Essence" },
            { itemID = 15994, count = 4, name = "Thorium Widget" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 8170, count = 1, name = "Rugged Leather" },
        },
    },
    ["Lil' Smoky"] = {
        spellID = 15633,
        itemID = 11826,
        skillReq = 205,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 205, 205, 205, 205 },
        reagents = {
            { itemID = 7075, count = 1, name = "Core of Earth" },
            { itemID = 4389, count = 2, name = "Gyrochronatom" },
            { itemID = 7191, count = 1, name = "Fused Wiring" },
            { itemID = 3860, count = 2, name = "Mithril Bar" },
            { itemID = 6037, count = 1, name = "Truesilver Bar" },
        },
    },
    ["Mana Potion Injector"] = {
        spellID = 30552,
        itemID = 33093,
        skillReq = 345,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 345, 345, 355, 365 },
        reagents = {
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
            { itemID = 23783, count = 1, name = "Handful of Fel Iron Bolts" },
            { itemID = 21887, count = 2, name = "Knothide Leather" },
            { itemID = 22832, count = 20, name = "Super Mana Potion" },
        },
    },
    ["Masterwork Target Dummy"] = {
        spellID = 19814,
        itemID = 16023,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Xizzer Fizzbolt" },
        },
        category = "Device",
        skillRange = { 275, 295, 305, 315 },
        reagents = {
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 16000, count = 1, name = "Thorium Tube" },
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 6037, count = 1, name = "Truesilver Bar" },
            { itemID = 8170, count = 2, name = "Rugged Leather" },
            { itemID = 14047, count = 4, name = "Runecloth" },
        },
    },
    ["Mechanical Dragonling"] = {
        spellID = 3969,
        itemID = 0,
        skillReq = 200,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gnaz Blunderflame" },
        },
        category = "Device",
        skillRange = { 200, 200, 200, 200},
    },
    ["Mithril Casing"] = {
        spellID = 12599,
        itemID = 10561,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 215, 215, 235, 255 },
        reagents = { { itemID = 3860, count = 3, name = "Mithril Bar" } },
    },
    ["Mithril Mechanical Dragonling"] = {
        spellID = 12624,
        itemID = 0,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Ruppo Zipcoil" },
        },
        category = "Device",
        skillRange = { 250, 250, 250, 250},
    },
    ["Mithril Tube"] = {
        spellID = 12589,
        itemID = 10559,
        skillReq = 195,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 195, 195, 215, 235 },
        reagents = { { itemID = 3860, count = 3, name = "Mithril Bar" } },
    },
    ["Ornate Spyglass"] = {
        spellID = 6458,
        itemID = 5507,
        skillReq = 135,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 135, 160, 172, 185 },
        reagents = {
            { itemID = 4371, count = 2, name = "Bronze Tube" },
            { itemID = 4375, count = 2, name = "Whirring Bronze Gizmo" },
            { itemID = 4363, count = 1, name = "Copper Modulator" },
            { itemID = 1206, count = 1, name = "Moss Agate" },
        },
    },
    ["Portable Bronze Mortar"] = {
        spellID = 3960,
        itemID = 4403,
        skillReq = 165,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 165, 185, 195, 205 },
        reagents = {
            { itemID = 4371, count = 4, name = "Bronze Tube" },
            { itemID = 4387, count = 1, name = "Iron Strut" },
            { itemID = 4377, count = 4, name = "Heavy Blasting Powder" },
            { itemID = 2319, count = 4, name = "Medium Leather" },
        },
    },
    ["Practice Lock"] = {
        spellID = 8334,
        itemID = 6712,
        skillReq = 100,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 100, 115, 122, 130 },
        reagents = {
            { itemID = 2841, count = 1, name = "Bronze Bar" },
            { itemID = 4359, count = 2, name = "Handful of Copper Bolts" },
            { itemID = 2880, count = 1, name = "Weak Flux" },
        },
    },
    ["Purple Smoke Flare"] = {
        spellID = 32814,
        itemID = 25886,
        skillReq = 335,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 23781, count = 1, name = "Elemental Blasting Powder" },
            { itemID = 21877, count = 1, name = "Netherweave Cloth" },
            { itemID = 4342, count = 1, name = "Purple Dye" },
        },
    },
    ["Red Firework"] = {
        spellID = 23066,
        itemID = 9318,
        skillReq = 150,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Sovik" },
        },
        category = "Device",
        skillRange = { 150, 150, 162, 175 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4234, count = 1, name = "Heavy Leather" },
        },
    },
    ["Rough Blasting Powder"] = {
        spellID = 3918,
        itemID = 4357,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Device",
        skillRange = { 1, 20, 30, 40 },
        reagents = { { itemID = 2835, count = 1, name = "Rough Stone" } },
    },
    ["Salt Shaker"] = {
        spellID = 19567,
        itemID = 15846,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 250, 270, 280, 290 },
        reagents = {
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 12359, count = 6, name = "Thorium Bar" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 10560, count = 4, name = "Unstable Trigger" },
        },
    },
    ["Silver Contact"] = {
        spellID = 3973,
        itemID = 4404,
        skillReq = 90,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 90, 110, 125, 140 },
        reagents = { { itemID = 2842, count = 1, name = "Silver Bar" } },
    },
    ["Snake Burst Firework"] = {
        spellID = 23507,
        itemID = 19026,
        skillReq = 250,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Zorbin Fandazzle" },
        },
        category = "Device",
        skillRange = { 250, 250, 260, 270 },
        reagents = {
            { itemID = 15992, count = 2, name = "Dense Blasting Powder" },
            { itemID = 14047, count = 2, name = "Runecloth" },
            { itemID = 8150, count = 1, name = "Deeprock Salt" },
        },
    },
    ["Snowmaster 9000"] = {
        spellID = 21940,
        itemID = 17716,
        skillReq = 190,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 190, 190, 210, 230 },
        reagents = {
            { itemID = 3860, count = 8, name = "Mithril Bar" },
            { itemID = 4389, count = 4, name = "Gyrochronatom" },
            { itemID = 17202, count = 4, name = "Snowball" },
            { itemID = 3829, count = 1, name = "Frost Oil" },
        },
    },
    ["Solid Blasting Powder"] = {
        spellID = 12585,
        itemID = 10505,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 175, 175, 185, 195 },
        reagents = { { itemID = 7912, count = 2, name = "Solid Stone" } },
    },
    ["Steam Tonk Controller"] = {
        spellID = 28327,
        itemID = 22728,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gearcutter Cogspinner, Sovik" },
            { method = "quest", faction = "Both", detail = "Quest: 40 Tickets - Schematic: Steam Tonk Controller" },
        },
        category = "Device",
        skillRange = { 275, 275, 280, 285 },
        reagents = {
            { itemID = 3860, count = 3, name = "Mithril Bar" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
        },
    },
    ["Target Dummy"] = {
        spellID = 3932,
        itemID = 4366,
        skillReq = 85,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 85, 115, 130, 145 },
        reagents = {
            { itemID = 4363, count = 1, name = "Copper Modulator" },
            { itemID = 4359, count = 2, name = "Handful of Copper Bolts" },
            { itemID = 2841, count = 1, name = "Bronze Bar" },
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["The Big One"] = {
        spellID = 12754,
        itemID = 10586,
        skillReq = 235,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 235, 235, 255, 275 },
        reagents = {
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 9061, count = 1, name = "Goblin Rocket Fuel" },
            { itemID = 10507, count = 6, name = "Solid Dynamite" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
        },
    },
    ["The Bigger One"] = {
        spellID = 30558,
        itemID = 23826,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 325, 325, 335, 345 },
        reagents = {
            { itemID = 23782, count = 3, name = "Fel Iron Casing" },
            { itemID = 23781, count = 6, name = "Elemental Blasting Powder" },
            { itemID = 17020, count = 3, name = "Arcane Powder" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Thorium Tube"] = {
        spellID = 19795,
        itemID = 16000,
        skillReq = 275,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 275, 295, 305, 315 },
        reagents = { { itemID = 12359, count = 6, name = "Thorium Bar" } },
    },
    ["Thorium Widget"] = {
        spellID = 19791,
        itemID = 15994,
        skillReq = 260,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 260, 280, 290, 300 },
        reagents = {
            { itemID = 12359, count = 3, name = "Thorium Bar" },
            { itemID = 14047, count = 1, name = "Runecloth" },
        },
    },
    ["Truesilver Transformer"] = {
        spellID = 23071,
        itemID = 18631,
        skillReq = 260,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 260, 270, 275, 280 },
        reagents = {
            { itemID = 6037, count = 2, name = "Truesilver Bar" },
            { itemID = 7067, count = 2, name = "Elemental Earth" },
            { itemID = 7069, count = 1, name = "Elemental Air" },
        },
    },
    ["Unstable Trigger"] = {
        spellID = 12591,
        itemID = 10560,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 200, 200, 220, 240 },
        reagents = {
            { itemID = 3860, count = 1, name = "Mithril Bar" },
            { itemID = 4338, count = 1, name = "Mageweave Cloth" },
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
        },
    },
    ["Voice Amplification Modulator"] = {
        spellID = 19819,
        itemID = 16009,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 290, 310, 320, 330 },
        reagents = {
            { itemID = 16006, count = 2, name = "Delicate Arcanite Converter" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 15994, count = 1, name = "Thorium Widget" },
            { itemID = 12799, count = 1, name = "Large Opal" },
        },
    },
    ["Whirring Bronze Gizmo"] = {
        spellID = 3942,
        itemID = 4375,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Device",
        skillRange = { 125, 125, 150, 175 },
        reagents = {
            { itemID = 2841, count = 2, name = "Bronze Bar" },
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["White Smoke Flare"] = {
        spellID = 30341,
        itemID = 23768,
        skillReq = 335,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Captured Gnome, Feera +2 more" },
        },
        category = "Device",
        skillRange = { 335, 335, 345, 355 },
        reagents = {
            { itemID = 23781, count = 1, name = "Elemental Blasting Powder" },
            { itemID = 21877, count = 1, name = "Netherweave Cloth" },
        },
    },
    ["World Enlarger"] = {
        spellID = 23129,
        itemID = 18660,
        skillReq = 260,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Device",
        skillRange = { 260, 260, 265, 270 },
        reagents = {
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 3864, count = 1, name = "Citrine" },
        },
    },
    ["Zapthrottle Mote Extractor"] = {
        spellID = 30548,
        itemID = 23821,
        skillReq = 305,
        sources = {
            { method = "quest", faction = "Both", detail = "Quest: The Zapthrottle Mote Extractor!" },
        },
        category = "Device",
        skillRange = { 305, 305, 315, 325 },
        reagents = {
            { itemID = 23782, count = 2, name = "Fel Iron Casing" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
            { itemID = 21886, count = 4, name = "Primal Life" },
            { itemID = 16006, count = 1, name = "Delicate Arcanite Converter" },
        },
    },

    -- ================================================================
    -- ENHANCEMENT
    -- ================================================================
    ["Accurate Scope"] = {
        spellID = 3979,
        itemID = 4407,
        skillReq = 180,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Mazk Snipeshot" },
        },
        category = "Enhancement",
        skillRange = { 180, 200, 210, 220 },
        reagents = {
            { itemID = 4371, count = 1, name = "Bronze Tube" },
            { itemID = 1529, count = 1, name = "Jade" },
            { itemID = 3864, count = 1, name = "Citrine" },
        },
    },
    ["Adamantite Scope"] = {
        spellID = 30329,
        itemID = 23764,
        skillReq = 335,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Daggle Ironshaper, Mixie Farshot" },
        },
        category = "Enhancement",
        skillRange = { 335, 345, 355, 365 },
        reagents = {
            { itemID = 23446, count = 8, name = "Adamantite Bar" },
            { itemID = 23112, count = 2, name = "Golden Draenite" },
        },
    },
    ["Biznicks 247x128 Accurascope"] = {
        spellID = 22793,
        itemID = 18283,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enhancement",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 17011, count = 2, name = "Lava Core" },
            { itemID = 7076, count = 2, name = "Essence of Earth" },
            { itemID = 16006, count = 4, name = "Delicate Arcanite Converter" },
            { itemID = 11371, count = 6, name = "Dark Iron Bar" },
            { itemID = 16000, count = 1, name = "Thorium Tube" },
        },
    },
    ["Crude Scope"] = {
        spellID = 3977,
        itemID = 4405,
        skillReq = 60,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enhancement",
        skillRange = { 60, 90, 105, 120 },
        reagents = {
            { itemID = 4361, count = 1, name = "Copper Tube" },
            { itemID = 774, count = 1, name = "Malachite" },
            { itemID = 4359, count = 1, name = "Handful of Copper Bolts" },
        },
    },
    ["Deadly Scope"] = {
        spellID = 12597,
        itemID = 10546,
        skillReq = 210,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Knaz Blunderflame, Yuka Screwspigot" },
        },
        category = "Enhancement",
        skillRange = { 210, 230, 240, 250 },
        reagents = {
            { itemID = 10559, count = 1, name = "Mithril Tube" },
            { itemID = 7909, count = 2, name = "Aquamarine" },
            { itemID = 4304, count = 2, name = "Thick Leather" },
        },
    },
    ["Khorium Scope"] = {
        spellID = 30332,
        itemID = 23765,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enhancement",
        skillRange = { 360, 370, 380, 390 },
        reagents = {
            { itemID = 23785, count = 1, name = "Hardened Adamantite Tube" },
            { itemID = 23449, count = 4, name = "Khorium Bar" },
            { itemID = 23440, count = 2, name = "Dawnstone" },
        },
    },
    ["Sniper Scope"] = {
        spellID = 12620,
        itemID = 10548,
        skillReq = 240,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enhancement",
        skillRange = { 240, 260, 270, 280 },
        reagents = {
            { itemID = 10559, count = 1, name = "Mithril Tube" },
            { itemID = 7910, count = 1, name = "Star Ruby" },
            { itemID = 6037, count = 2, name = "Truesilver Bar" },
        },
    },
    ["Stabilized Eternium Scope"] = {
        spellID = 30334,
        itemID = 23766,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Enhancement",
        skillRange = { 375, 385, 395, 405 },
        reagents = {
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 6, name = "Felsteel Stabilizer" },
            { itemID = 23438, count = 2, name = "Star of Elune" },
        },
    },
    ["Standard Scope"] = {
        spellID = 3978,
        itemID = 4406,
        skillReq = 110,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Enhancement",
        skillRange = { 110, 135, 147, 160 },
        reagents = {
            { itemID = 4371, count = 1, name = "Bronze Tube" },
            { itemID = 1206, count = 1, name = "Moss Agate" },
        },
    },

    -- ================================================================
    -- EXPLOSIVE
    -- ================================================================
    ["Adamantite Grenade"] = {
        spellID = 30311,
        itemID = 23737,
        skillReq = 325,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 325, 335, 345, 355 },
        reagents = {
            { itemID = 23446, count = 4, name = "Adamantite Bar" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
            { itemID = 23781, count = 1, name = "Elemental Blasting Powder" },
        },
    },
    ["Arcane Bomb"] = {
        spellID = 19831,
        itemID = 16040,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 16006, count = 1, name = "Delicate Arcanite Converter" },
            { itemID = 12359, count = 3, name = "Thorium Bar" },
            { itemID = 14047, count = 1, name = "Runecloth" },
        },
    },
    ["Big Bronze Bomb"] = {
        spellID = 3950,
        itemID = 4380,
        skillReq = 140,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 140, 140, 165, 190 },
        reagents = {
            { itemID = 4377, count = 2, name = "Heavy Blasting Powder" },
            { itemID = 2841, count = 3, name = "Bronze Bar" },
            { itemID = 4404, count = 1, name = "Silver Contact" },
        },
    },
    ["Big Iron Bomb"] = {
        spellID = 3967,
        itemID = 4394,
        skillReq = 190,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 190, 190, 210, 230 },
        reagents = {
            { itemID = 3575, count = 3, name = "Iron Bar" },
            { itemID = 4377, count = 3, name = "Heavy Blasting Powder" },
            { itemID = 4404, count = 1, name = "Silver Contact" },
        },
    },
    ["Coarse Dynamite"] = {
        spellID = 3931,
        itemID = 4365,
        skillReq = 75,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 75, 90, 97, 105 },
        reagents = {
            { itemID = 4364, count = 3, name = "Coarse Blasting Powder" },
            { itemID = 2589, count = 1, name = "Linen Cloth" },
        },
    },
    ["Dark Iron Bomb"] = {
        spellID = 19799,
        itemID = 16005,
        skillReq = 285,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 285, 305, 315, 325 },
        reagents = {
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 11371, count = 1, name = "Dark Iron Bar" },
            { itemID = 15992, count = 3, name = "Dense Blasting Powder" },
            { itemID = 14047, count = 3, name = "Runecloth" },
        },
    },
    ["Dense Dynamite"] = {
        spellID = 23070,
        itemID = 18641,
        skillReq = 250,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 250, 250, 260, 270 },
        reagents = {
            { itemID = 15992, count = 2, name = "Dense Blasting Powder" },
            { itemID = 14047, count = 3, name = "Runecloth" },
        },
    },
    ["EZ-Thro Dynamite"] = {
        spellID = 8339,
        itemID = 6714,
        skillReq = 100,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 100, 115, 122, 130 },
        reagents = {
            { itemID = 4364, count = 4, name = "Coarse Blasting Powder" },
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["EZ-Thro Dynamite II"] = {
        spellID = 23069,
        itemID = 18588,
        skillReq = 200,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Blizrik Buckshot" },
        },
        category = "Explosive",
        skillRange = { 200, 200, 210, 220 },
        reagents = {
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
            { itemID = 4338, count = 2, name = "Mageweave Cloth" },
        },
    },
    ["Elemental Seaforium Charge"] = {
        spellID = 30547,
        itemID = 23819,
        skillReq = 350,
        sources = {
            { method = "reputation", faction = "Both", detail = "The Consortium @ Honored" },
        },
        category = "Explosive",
        skillRange = { 350, 350, 355, 360 },
        reagents = {
            { itemID = 23781, count = 2, name = "Elemental Blasting Powder" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
            { itemID = 23783, count = 1, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Fel Iron Bomb"] = {
        spellID = 30310,
        itemID = 23736,
        skillReq = 300,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
            { itemID = 23783, count = 2, name = "Handful of Fel Iron Bolts" },
            { itemID = 23781, count = 1, name = "Elemental Blasting Powder" },
        },
    },
    ["Flash Bomb"] = {
        spellID = 8243,
        itemID = 4852,
        skillReq = 185,
        sources = {
            { method = "drop", faction = "Both" },
            { method = "quest", faction = "Both", detail = "Quest: Flash Bomb Recipe" },
        },
        category = "Explosive",
        skillRange = { 185, 185, 205, 225 },
        reagents = {
            { itemID = 4611, count = 1, name = "Blue Pearl" },
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4306, count = 1, name = "Silk Cloth" },
        },
    },
    ["Frost Grenades"] = {
        spellID = 39973,
        itemID = 32413,
        skillReq = 335,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 335, 345, 355, 365 },
        reagents = {
            { itemID = 32423, count = 1, name = "Icy Blasting Primers" },
            { itemID = 23782, count = 1, name = "Fel Iron Casing" },
            { itemID = 23783, count = 1, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Goblin Sapper Charge"] = {
        spellID = 12760,
        itemID = 10646,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 205, 205, 225, 245 },
        reagents = {
            { itemID = 4338, count = 1, name = "Mageweave Cloth" },
            { itemID = 10505, count = 3, name = "Solid Blasting Powder" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
        },
    },
    ["Heavy Dynamite"] = {
        spellID = 3946,
        itemID = 4378,
        skillReq = 125,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 125, 125, 135, 145 },
        reagents = {
            { itemID = 4377, count = 2, name = "Heavy Blasting Powder" },
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["Hi-Explosive Bomb"] = {
        spellID = 12619,
        itemID = 10562,
        skillReq = 235,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 235, 235, 255, 275 },
        reagents = {
            { itemID = 10561, count = 2, name = "Mithril Casing" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 10505, count = 2, name = "Solid Blasting Powder" },
        },
    },
    ["Iron Grenade"] = {
        spellID = 3962,
        itemID = 4390,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 175, 175, 195, 215 },
        reagents = {
            { itemID = 3575, count = 1, name = "Iron Bar" },
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4306, count = 1, name = "Silk Cloth" },
        },
    },
    ["Large Copper Bomb"] = {
        spellID = 3937,
        itemID = 4370,
        skillReq = 105,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 105, 105, 130, 155 },
        reagents = {
            { itemID = 2840, count = 3, name = "Copper Bar" },
            { itemID = 4364, count = 4, name = "Coarse Blasting Powder" },
            { itemID = 4404, count = 1, name = "Silver Contact" },
        },
    },
    ["Large Seaforium Charge"] = {
        spellID = 3972,
        itemID = 4398,
        skillReq = 200,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 200, 200, 220, 240 },
        reagents = {
            { itemID = 10505, count = 2, name = "Solid Blasting Powder" },
            { itemID = 4234, count = 2, name = "Heavy Leather" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Mithril Frag Bomb"] = {
        spellID = 12603,
        itemID = 10514,
        skillReq = 215,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 215, 215, 235, 255 },
        reagents = {
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
        },
    },
    ["Pet Bombling"] = {
        spellID = 15628,
        itemID = 11825,
        skillReq = 205,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 205, 205, 205, 205 },
        reagents = {
            { itemID = 4394, count = 1, name = "Big Iron Bomb" },
            { itemID = 7077, count = 1, name = "Heart of Fire" },
            { itemID = 7191, count = 1, name = "Fused Wiring" },
            { itemID = 3860, count = 6, name = "Mithril Bar" },
        },
    },
    ["Powerful Seaforium Charge"] = {
        spellID = 23080,
        itemID = 18594,
        skillReq = 275,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Xizzer Fizzbolt" },
        },
        category = "Explosive",
        skillRange = { 275, 275, 285, 295 },
        reagents = {
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 15992, count = 3, name = "Dense Blasting Powder" },
            { itemID = 8170, count = 2, name = "Rugged Leather" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Rough Copper Bomb"] = {
        spellID = 3923,
        itemID = 4360,
        skillReq = 30,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 30, 60, 75, 90 },
        reagents = {
            { itemID = 2840, count = 1, name = "Copper Bar" },
            { itemID = 4359, count = 1, name = "Handful of Copper Bolts" },
            { itemID = 4357, count = 2, name = "Rough Blasting Powder" },
            { itemID = 2589, count = 1, name = "Linen Cloth" },
        },
    },
    ["Rough Dynamite"] = {
        spellID = 3919,
        itemID = 4358,
        skillReq = 1,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 1, 30, 45, 60 },
        reagents = {
            { itemID = 4357, count = 2, name = "Rough Blasting Powder" },
            { itemID = 2589, count = 1, name = "Linen Cloth" },
        },
    },
    ["Small Bronze Bomb"] = {
        spellID = 3941,
        itemID = 4374,
        skillReq = 120,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 120, 120, 145, 170 },
        reagents = {
            { itemID = 4364, count = 4, name = "Coarse Blasting Powder" },
            { itemID = 2841, count = 2, name = "Bronze Bar" },
            { itemID = 4404, count = 1, name = "Silver Contact" },
            { itemID = 2592, count = 1, name = "Wool Cloth" },
        },
    },
    ["Small Seaforium Charge"] = {
        spellID = 3933,
        itemID = 4367,
        skillReq = 100,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 100, 130, 145, 160 },
        reagents = {
            { itemID = 4364, count = 2, name = "Coarse Blasting Powder" },
            { itemID = 4363, count = 1, name = "Copper Modulator" },
            { itemID = 2318, count = 1, name = "Light Leather" },
            { itemID = 159, count = 1, name = "Refreshing Spring Water" },
        },
    },
    ["Solid Dynamite"] = {
        spellID = 12586,
        itemID = 10507,
        skillReq = 175,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 175, 175, 185, 195 },
        reagents = {
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
            { itemID = 4306, count = 1, name = "Silk Cloth" },
        },
    },
    ["Summon Goblin Bomb"] = {
        spellID = 13258,
        itemID = 0,
        skillReq = 230,
        sources = {
            { method = "automatic", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 0, 0, 0, 0},
    },
    ["Super Sapper Charge"] = {
        spellID = 30560,
        itemID = 23827,
        skillReq = 340,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 340, 340, 350, 360 },
        reagents = {
            { itemID = 21877, count = 4, name = "Netherweave Cloth" },
            { itemID = 23781, count = 4, name = "Elemental Blasting Powder" },
            { itemID = 22457, count = 1, name = "Primal Mana" },
        },
    },
    ["Thorium Grenade"] = {
        spellID = 19790,
        itemID = 15993,
        skillReq = 260,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 260, 280, 290, 300 },
        reagents = {
            { itemID = 15994, count = 1, name = "Thorium Widget" },
            { itemID = 12359, count = 3, name = "Thorium Bar" },
            { itemID = 15992, count = 3, name = "Dense Blasting Powder" },
            { itemID = 14047, count = 3, name = "Runecloth" },
        },
    },
    ["Turbo-Charged Flying Machine"] = {
        spellID = 44157,
        itemID = 34061,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Explosive",
        skillRange = { 375, 385, 390, 395 },
        reagents = {
            { itemID = 34060, count = 1, name = "Flying Machine Control" },
            { itemID = 23786, count = 8, name = "Khorium Power Core" },
            { itemID = 23787, count = 8, name = "Felsteel Stabilizer" },
            { itemID = 34249, count = 1, name = "Hula Girl Doll" },
        },
    },

    -- ================================================================
    -- GADGET
    -- ================================================================
    ["Blue Rocket Cluster"] = {
        spellID = 26423,
        itemID = 21571,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 225, 225, 237, 250 },
        reagents = {
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
            { itemID = 4304, count = 1, name = "Thick Leather" },
        },
    },
    ["Goblin Jumper Cables"] = {
        spellID = 9273,
        itemID = 7148,
        skillReq = 165,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Kzixx, Veenix +1 more" },
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 160, 160, 180, 200},
        reagents = {
            { itemID = 3575, count = 6, name = "Iron Bar" },
            { itemID = 4375, count = 2, name = "Whirring Bronze Gizmo" },
            { itemID = 814, count = 2, name = "Flask of Oil" },
            { itemID = 4306, count = 2, name = "Silk Cloth" },
            { itemID = 1210, count = 2, name = "Shadowgem" },
            { itemID = 7191, count = 1, name = "Fused Wiring" },
        },
    },
    ["Goblin Jumper Cables XL"] = {
        spellID = 23078,
        itemID = 18587,
        skillReq = 265,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 265, 285, 295, 305 },
        reagents = {
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 18631, count = 2, name = "Truesilver Transformer" },
            { itemID = 7191, count = 2, name = "Fused Wiring" },
            { itemID = 14227, count = 2, name = "Ironweb Spider Silk" },
            { itemID = 7910, count = 2, name = "Star Ruby" },
        },
    },
    ["Goblin Rocket Fuel Recipe"] = {
        spellID = 12715,
        itemID = 10644,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 205, 205, 205, 205 },
        reagents = {
            { itemID = 10648, count = 1, name = "Blank Parchment" },
            { itemID = 10647, count = 1, name = "Engineer's Ink" },
        },
    },
    ["Green Rocket Cluster"] = {
        spellID = 26424,
        itemID = 21574,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 225, 225, 237, 250 },
        reagents = {
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
            { itemID = 4304, count = 1, name = "Thick Leather" },
        },
    },
    ["Large Blue Rocket"] = {
        spellID = 26420,
        itemID = 21589,
        skillReq = 175,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 175, 175, 187, 200 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4234, count = 1, name = "Heavy Leather" },
        },
    },
    ["Large Blue Rocket Cluster"] = {
        spellID = 26426,
        itemID = 21714,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 275, 275, 280, 285 },
        reagents = {
            { itemID = 15992, count = 1, name = "Dense Blasting Powder" },
            { itemID = 8170, count = 1, name = "Rugged Leather" },
        },
    },
    ["Large Green Rocket"] = {
        spellID = 26421,
        itemID = 21590,
        skillReq = 175,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 175, 175, 187, 200 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4234, count = 1, name = "Heavy Leather" },
        },
    },
    ["Large Green Rocket Cluster"] = {
        spellID = 26427,
        itemID = 21716,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 275, 275, 280, 285 },
        reagents = {
            { itemID = 15992, count = 1, name = "Dense Blasting Powder" },
            { itemID = 8170, count = 1, name = "Rugged Leather" },
        },
    },
    ["Large Red Rocket"] = {
        spellID = 26422,
        itemID = 21592,
        skillReq = 175,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 175, 175, 187, 200 },
        reagents = {
            { itemID = 4377, count = 1, name = "Heavy Blasting Powder" },
            { itemID = 4234, count = 1, name = "Heavy Leather" },
        },
    },
    ["Large Red Rocket Cluster"] = {
        spellID = 26428,
        itemID = 21718,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 275, 275, 280, 285 },
        reagents = {
            { itemID = 15992, count = 1, name = "Dense Blasting Powder" },
            { itemID = 8170, count = 1, name = "Rugged Leather" },
        },
    },
    ["Mechanical Repair Kit"] = {
        spellID = 15255,
        itemID = 11590,
        skillReq = 200,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 200, 200, 220, 240 },
        reagents = {
            { itemID = 3860, count = 1, name = "Mithril Bar" },
            { itemID = 4338, count = 1, name = "Mageweave Cloth" },
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
        },
    },
    ["Parachute Cloak"] = {
        spellID = 12616,
        itemID = 10518,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 225, 245, 255, 265 },
        reagents = {
            { itemID = 4339, count = 4, name = "Bolt of Mageweave" },
            { itemID = 10285, count = 2, name = "Shadow Silk" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 10505, count = 4, name = "Solid Blasting Powder" },
        },
    },
    ["Red Rocket Cluster"] = {
        spellID = 26425,
        itemID = 21576,
        skillReq = 225,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 225, 225, 237, 250 },
        reagents = {
            { itemID = 10505, count = 1, name = "Solid Blasting Powder" },
            { itemID = 4304, count = 1, name = "Thick Leather" },
        },
    },
    ["Small Blue Rocket"] = {
        spellID = 26416,
        itemID = 21558,
        skillReq = 125,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 125, 125, 137, 150 },
        reagents = {
            { itemID = 4364, count = 1, name = "Coarse Blasting Powder" },
            { itemID = 2319, count = 1, name = "Medium Leather" },
        },
    },
    ["Small Green Rocket"] = {
        spellID = 26417,
        itemID = 21559,
        skillReq = 125,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 125, 125, 137, 150 },
        reagents = {
            { itemID = 4364, count = 1, name = "Coarse Blasting Powder" },
            { itemID = 2319, count = 1, name = "Medium Leather" },
        },
    },
    ["Small Red Rocket"] = {
        spellID = 26418,
        itemID = 21557,
        skillReq = 125,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Gadget",
        skillRange = { 125, 125, 137, 150 },
        reagents = {
            { itemID = 4364, count = 1, name = "Coarse Blasting Powder" },
            { itemID = 2319, count = 1, name = "Medium Leather" },
        },
    },

    -- ================================================================
    -- TRINKET
    -- ================================================================
    ["Dimensional Ripper - Area 52"] = {
        spellID = 36954,
        itemID = 30542,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Trinket",
        skillRange = { 350, 350, 360, 370 },
        reagents = {
            { itemID = 23784, count = 1, name = "Adamantite Frame" },
            { itemID = 21884, count = 2, name = "Primal Fire" },
            { itemID = 23826, count = 2, name = "The Bigger One" },
            { itemID = 23783, count = 4, name = "Handful of Fel Iron Bolts" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
        },
    },
    ["Dimensional Ripper - Everlook"] = {
        spellID = 23486,
        itemID = 18984,
        skillReq = 285,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Trinket",
        skillRange = { 285, 285, 295, 305 },
        reagents = {
            { itemID = 3860, count = 10, name = "Mithril Bar" },
            { itemID = 18631, count = 1, name = "Truesilver Transformer" },
            { itemID = 7077, count = 4, name = "Heart of Fire" },
            { itemID = 7910, count = 2, name = "Star Ruby" },
            { itemID = 10586, count = 1, name = "The Big One" },
        },
    },
    ["Gnomish Battle Chicken"] = {
        spellID = 12906,
        itemID = 10725,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 230, 250, 260, 270 },
        reagents = {
            { itemID = 10561, count = 1, name = "Mithril Casing" },
            { itemID = 6037, count = 6, name = "Truesilver Bar" },
            { itemID = 3860, count = 6, name = "Mithril Bar" },
            { itemID = 9060, count = 2, name = "Inlaid Mithril Cylinder" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 1529, count = 2, name = "Jade" },
        },
    },
    ["Gnomish Cloaking Device"] = {
        spellID = 3971,
        itemID = 4397,
        skillReq = 200,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Zan Shivsproket" },
            { method = "drop", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 200, 220, 230, 240 },
        reagents = {
            { itemID = 4389, count = 4, name = "Gyrochronatom" },
            { itemID = 1529, count = 2, name = "Jade" },
            { itemID = 1705, count = 2, name = "Lesser Moonstone" },
            { itemID = 3864, count = 2, name = "Citrine" },
            { itemID = 7191, count = 1, name = "Fused Wiring" },
        },
    },
    ["Gnomish Death Ray"] = {
        spellID = 12759,
        itemID = 10645,
        skillReq = 240,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 240, 260, 270, 280 },
        reagents = {
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 12808, count = 1, name = "Essence of Undeath" },
            { itemID = 7972, count = 4, name = "Ichor of Undeath" },
            { itemID = 9060, count = 1, name = "Inlaid Mithril Cylinder" },
        },
    },
    ["Gnomish Net-o-Matic Projector"] = {
        spellID = 12902,
        itemID = 10720,
        skillReq = 210,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 210, 230, 240, 250 },
        reagents = {
            { itemID = 10559, count = 1, name = "Mithril Tube" },
            { itemID = 10285, count = 2, name = "Shadow Silk" },
            { itemID = 4337, count = 4, name = "Thick Spider's Silk" },
            { itemID = 10505, count = 2, name = "Solid Blasting Powder" },
            { itemID = 3860, count = 4, name = "Mithril Bar" },
        },
    },
    ["Gnomish Poultryizer"] = {
        spellID = 30569,
        itemID = 23835,
        skillReq = 340,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 340, 360, 370, 380 },
        reagents = {
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23786, count = 2, name = "Khorium Power Core" },
            { itemID = 22445, count = 10, name = "Arcane Dust" },
            { itemID = 22449, count = 2, name = "Large Prismatic Shard" },
        },
    },
    ["Gnomish Shrink Ray"] = {
        spellID = 12899,
        itemID = 10716,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 205, 225, 235, 245 },
        reagents = {
            { itemID = 10559, count = 1, name = "Mithril Tube" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 3860, count = 4, name = "Mithril Bar" },
            { itemID = 8151, count = 4, name = "Flask of Mojo" },
            { itemID = 1529, count = 2, name = "Jade" },
        },
    },
    ["Gnomish Universal Remote"] = {
        spellID = 9269,
        itemID = 7506,
        skillReq = 125,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Gearcutter Cogspinner, Jinky Twizzlefixxit" },
            { method = "drop", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 125, 150, 162, 175 },
        reagents = {
            { itemID = 2841, count = 6, name = "Bronze Bar" },
            { itemID = 4375, count = 1, name = "Whirring Bronze Gizmo" },
            { itemID = 814, count = 2, name = "Flask of Oil" },
            { itemID = 818, count = 1, name = "Tigerseye" },
            { itemID = 774, count = 1, name = "Malachite" },
        },
    },
    ["Goblin Bomb Dispenser"] = {
        spellID = 12755,
        itemID = 10587,
        skillReq = 230,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 230, 230, 250, 270 },
        reagents = {
            { itemID = 10561, count = 2, name = "Mithril Casing" },
            { itemID = 10505, count = 4, name = "Solid Blasting Powder" },
            { itemID = 6037, count = 6, name = "Truesilver Bar" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 4407, count = 2, name = "Accurate Scope" },
        },
    },
    ["Goblin Dragon Gun"] = {
        spellID = 12908,
        itemID = 10727,
        skillReq = 240,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 240, 260, 270, 280 },
        reagents = {
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 9061, count = 4, name = "Goblin Rocket Fuel" },
            { itemID = 3860, count = 6, name = "Mithril Bar" },
            { itemID = 6037, count = 6, name = "Truesilver Bar" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
        },
    },
    ["Goblin Mortar"] = {
        spellID = 12716,
        itemID = 10577,
        skillReq = 225,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 225, 225, 235, 245 },
        reagents = {
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 3860, count = 4, name = "Mithril Bar" },
            { itemID = 10505, count = 5, name = "Solid Blasting Powder" },
            { itemID = 10558, count = 1, name = "Gold Power Core" },
            { itemID = 7068, count = 1, name = "Elemental Fire" },
        },
    },
    ["Goblin Rocket Launcher"] = {
        spellID = 30563,
        itemID = 23836,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 350, 360, 370, 380 },
        reagents = {
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
            { itemID = 23787, count = 2, name = "Felsteel Stabilizer" },
            { itemID = 21884, count = 6, name = "Primal Fire" },
            { itemID = 22452, count = 6, name = "Primal Earth" },
            { itemID = 16006, count = 2, name = "Delicate Arcanite Converter" },
        },
    },
    ["Gyrofreeze Ice Reflector"] = {
        spellID = 23077,
        itemID = 18634,
        skillReq = 260,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Xizzer Fizzbolt" },
        },
        category = "Trinket",
        skillRange = { 260, 280, 290, 300 },
        reagents = {
            { itemID = 15994, count = 6, name = "Thorium Widget" },
            { itemID = 18631, count = 2, name = "Truesilver Transformer" },
            { itemID = 12361, count = 2, name = "Blue Sapphire" },
            { itemID = 7078, count = 4, name = "Essence of Fire" },
            { itemID = 3829, count = 2, name = "Frost Oil" },
            { itemID = 13467, count = 4, name = "Icecap" },
        },
    },
    ["Hyper-Radiant Flame Reflector"] = {
        spellID = 23081,
        itemID = 18638,
        skillReq = 290,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 290, 310, 320, 330 },
        reagents = {
            { itemID = 11371, count = 4, name = "Dark Iron Bar" },
            { itemID = 18631, count = 3, name = "Truesilver Transformer" },
            { itemID = 7080, count = 6, name = "Essence of Water" },
            { itemID = 7910, count = 4, name = "Star Ruby" },
            { itemID = 12800, count = 2, name = "Azerothian Diamond" },
        },
    },
    ["Major Recombobulator"] = {
        spellID = 23079,
        itemID = 18637,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 275, 285, 290, 295 },
        reagents = {
            { itemID = 16000, count = 2, name = "Thorium Tube" },
            { itemID = 18631, count = 1, name = "Truesilver Transformer" },
            { itemID = 14047, count = 2, name = "Runecloth" },
        },
    },
    ["Minor Recombobulator"] = {
        spellID = 3952,
        itemID = 4381,
        skillReq = 140,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Fradd Swiftgear, Gagsprocket +1 more" },
        },
        category = "Trinket",
        skillRange = { 140, 165, 177, 190 },
        reagents = {
            { itemID = 4371, count = 1, name = "Bronze Tube" },
            { itemID = 4375, count = 2, name = "Whirring Bronze Gizmo" },
            { itemID = 2319, count = 2, name = "Medium Leather" },
            { itemID = 1206, count = 1, name = "Moss Agate" },
        },
    },
    ["The Mortar: Reloaded"] = {
        spellID = 13240,
        itemID = 10577,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Trinket",
        skillRange = { 205, 205, 205, 205},
        reagents = {
            { itemID = 10577, count = 1, name = "Goblin Mortar" },
            { itemID = 3860, count = 1, name = "Mithril Bar" },
            { itemID = 10505, count = 3, name = "Solid Blasting Powder" },
        },
    },
    ["Ultra-Flash Shadow Reflector"] = {
        spellID = 23082,
        itemID = 18639,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Trinket",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 11371, count = 8, name = "Dark Iron Bar" },
            { itemID = 18631, count = 4, name = "Truesilver Transformer" },
            { itemID = 12803, count = 6, name = "Living Essence" },
            { itemID = 12808, count = 4, name = "Essence of Undeath" },
            { itemID = 12800, count = 2, name = "Azerothian Diamond" },
            { itemID = 12799, count = 2, name = "Large Opal" },
        },
    },
    ["Ultrasafe Transporter - Gadgetzan"] = {
        spellID = 23489,
        itemID = 18986,
        skillReq = 285,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Trinket",
        skillRange = { 285, 285, 295, 305 },
        reagents = {
            { itemID = 3860, count = 12, name = "Mithril Bar" },
            { itemID = 18631, count = 2, name = "Truesilver Transformer" },
            { itemID = 7075, count = 4, name = "Core of Earth" },
            { itemID = 7079, count = 2, name = "Globe of Water" },
            { itemID = 7909, count = 4, name = "Aquamarine" },
            { itemID = 9060, count = 1, name = "Inlaid Mithril Cylinder" },
        },
    },
    ["Ultrasafe Transporter - Toshley's Station"] = {
        spellID = 36955,
        itemID = 30544,
        skillReq = 350,
        sources = {
            { method = "trainer", faction = "Both", detail = "trainer (cmangos list gap; auto-confirmed via DB2)" },
        },
        category = "Trinket",
        skillRange = { 350, 350, 360, 370 },
        reagents = {
            { itemID = 23784, count = 1, name = "Adamantite Frame" },
            { itemID = 22451, count = 2, name = "Primal Air" },
            { itemID = 23787, count = 2, name = "Felsteel Stabilizer" },
            { itemID = 23783, count = 4, name = "Handful of Fel Iron Bolts" },
            { itemID = 23786, count = 1, name = "Khorium Power Core" },
        },
    },

    -- ================================================================
    -- WEAPON
    -- ================================================================
    ["Adamantite Rifle"] = {
        spellID = 30313,
        itemID = 23746,
        skillReq = 350,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Feera, Viggz Shinesparked +1 more" },
        },
        category = "Weapon",
        skillRange = { 350, 360, 370, 380 },
        reagents = {
            { itemID = 23782, count = 3, name = "Fel Iron Casing" },
            { itemID = 23784, count = 2, name = "Adamantite Frame" },
            { itemID = 23783, count = 4, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Arclight Spanner"] = {
        spellID = 7430,
        itemID = 6219,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 50, 70, 80, 90 },
        reagents = { { itemID = 2840, count = 6, name = "Copper Bar" } },
    },
    ["Core Marksman Rifle"] = {
        spellID = 22795,
        itemID = 18282,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 17010, count = 4, name = "Fiery Core" },
            { itemID = 17011, count = 2, name = "Lava Core" },
            { itemID = 12360, count = 6, name = "Arcanite Bar" },
            { itemID = 16006, count = 2, name = "Delicate Arcanite Converter" },
            { itemID = 16000, count = 2, name = "Thorium Tube" },
        },
    },
    ["Dark Iron Rifle"] = {
        spellID = 19796,
        itemID = 16004,
        skillReq = 275,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 275, 295, 305, 315 },
        reagents = {
            { itemID = 16000, count = 2, name = "Thorium Tube" },
            { itemID = 11371, count = 6, name = "Dark Iron Bar" },
            { itemID = 10546, count = 2, name = "Deadly Scope" },
            { itemID = 12361, count = 2, name = "Blue Sapphire" },
            { itemID = 12799, count = 2, name = "Large Opal" },
            { itemID = 8170, count = 4, name = "Rugged Leather" },
        },
    },
    ["Deadly Blunderbuss"] = {
        spellID = 3936,
        itemID = 4369,
        skillReq = 105,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 105, 130, 142, 155 },
        reagents = {
            { itemID = 4361, count = 2, name = "Copper Tube" },
            { itemID = 4359, count = 4, name = "Handful of Copper Bolts" },
            { itemID = 4399, count = 1, name = "Wooden Stock" },
            { itemID = 2319, count = 2, name = "Medium Leather" },
        },
    },
    ["Fel Iron Musket"] = {
        spellID = 30312,
        itemID = 23742,
        skillReq = 320,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 320, 330, 340, 350 },
        reagents = {
            { itemID = 4400, count = 1, name = "Heavy Stock" },
            { itemID = 23782, count = 3, name = "Fel Iron Casing" },
            { itemID = 23783, count = 6, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Felsteel Boomstick"] = {
        spellID = 30314,
        itemID = 23747,
        skillReq = 360,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 360, 370, 380, 390 },
        reagents = {
            { itemID = 23785, count = 1, name = "Hardened Adamantite Tube" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 23783, count = 4, name = "Handful of Fel Iron Bolts" },
        },
    },
    ["Flawless Arcanite Rifle"] = {
        spellID = 19833,
        itemID = 16007,
        skillReq = 300,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 300, 320, 330, 340 },
        reagents = {
            { itemID = 12360, count = 10, name = "Arcanite Bar" },
            { itemID = 16000, count = 2, name = "Thorium Tube" },
            { itemID = 7078, count = 2, name = "Essence of Fire" },
            { itemID = 7076, count = 2, name = "Essence of Earth" },
            { itemID = 12800, count = 2, name = "Azerothian Diamond" },
            { itemID = 12810, count = 2, name = "Enchanted Leather" },
        },
    },
    ["Gyro-balanced Khorium Destroyer"] = {
        spellID = 41307,
        itemID = 32756,
        skillReq = 375,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 375, 375, 392, 410 },
        reagents = {
            { itemID = 23785, count = 1, name = "Hardened Adamantite Tube" },
            { itemID = 23449, count = 20, name = "Khorium Bar" },
            { itemID = 23787, count = 4, name = "Felsteel Stabilizer" },
            { itemID = 21884, count = 12, name = "Primal Fire" },
            { itemID = 22451, count = 12, name = "Primal Air" },
            { itemID = 23572, count = 1, name = "Primal Nether" },
        },
    },
    ["Lovingly Crafted Boomstick"] = {
        spellID = 3939,
        itemID = 4372,
        skillReq = 120,
        sources = {
            { method = "vendor", faction = "Both", detail = "Sold by Fradd Swiftgear, Jinky Twizzlefixxit" },
        },
        category = "Weapon",
        skillRange = { 120, 145, 157, 170 },
        reagents = {
            { itemID = 4371, count = 2, name = "Bronze Tube" },
            { itemID = 4359, count = 2, name = "Handful of Copper Bolts" },
            { itemID = 4400, count = 1, name = "Heavy Stock" },
            { itemID = 1206, count = 3, name = "Moss Agate" },
        },
    },
    ["Mithril Blunderbuss"] = {
        spellID = 12595,
        itemID = 10508,
        skillReq = 205,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 205, 225, 235, 245 },
        reagents = {
            { itemID = 10559, count = 1, name = "Mithril Tube" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 4400, count = 1, name = "Heavy Stock" },
            { itemID = 3860, count = 4, name = "Mithril Bar" },
            { itemID = 7068, count = 2, name = "Elemental Fire" },
        },
    },
    ["Mithril Heavy-bore Rifle"] = {
        spellID = 12614,
        itemID = 10510,
        skillReq = 220,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 220, 240, 250, 260 },
        reagents = {
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 10560, count = 1, name = "Unstable Trigger" },
            { itemID = 4400, count = 1, name = "Heavy Stock" },
            { itemID = 3860, count = 6, name = "Mithril Bar" },
            { itemID = 3864, count = 2, name = "Citrine" },
        },
    },
    ["Moonsight Rifle"] = {
        spellID = 3954,
        itemID = 4383,
        skillReq = 145,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 145, 170, 182, 195 },
        reagents = {
            { itemID = 4371, count = 3, name = "Bronze Tube" },
            { itemID = 4375, count = 3, name = "Whirring Bronze Gizmo" },
            { itemID = 4400, count = 1, name = "Heavy Stock" },
            { itemID = 1705, count = 2, name = "Lesser Moonstone" },
        },
    },
    ["Ornate Khorium Rifle"] = {
        spellID = 30315,
        itemID = 23748,
        skillReq = 375,
        sources = {
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 375, 385, 395, 405 },
        reagents = {
            { itemID = 23785, count = 2, name = "Hardened Adamantite Tube" },
            { itemID = 23449, count = 12, name = "Khorium Bar" },
            { itemID = 23783, count = 4, name = "Handful of Fel Iron Bolts" },
            { itemID = 23439, count = 2, name = "Noble Topaz" },
        },
    },
    ["Rough Boomstick"] = {
        spellID = 3925,
        itemID = 4362,
        skillReq = 50,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 50, 80, 95, 110 },
        reagents = {
            { itemID = 4361, count = 1, name = "Copper Tube" },
            { itemID = 4359, count = 1, name = "Handful of Copper Bolts" },
            { itemID = 4399, count = 1, name = "Wooden Stock" },
        },
    },
    ["Silver-plated Shotgun"] = {
        spellID = 3949,
        itemID = 4379,
        skillReq = 130,
        sources = {
            { method = "trainer", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 130, 155, 167, 180 },
        reagents = {
            { itemID = 4371, count = 2, name = "Bronze Tube" },
            { itemID = 4375, count = 2, name = "Whirring Bronze Gizmo" },
            { itemID = 4400, count = 1, name = "Heavy Stock" },
            { itemID = 2842, count = 3, name = "Silver Bar" },
        },
    },
    ["Thorium Rifle"] = {
        spellID = 19792,
        itemID = 15995,
        skillReq = 260,
        sources = {
            { method = "trainer", faction = "Both" },
            { method = "drop", faction = "Both" },
        },
        category = "Weapon",
        skillRange = { 260, 280, 290, 300 },
        reagents = {
            { itemID = 10559, count = 2, name = "Mithril Tube" },
            { itemID = 10561, count = 2, name = "Mithril Casing" },
            { itemID = 15994, count = 2, name = "Thorium Widget" },
            { itemID = 12359, count = 4, name = "Thorium Bar" },
            { itemID = 10546, count = 1, name = "Deadly Scope" },
        },
    },

}

RDB:RegisterProfession("Engineering", recipes)
