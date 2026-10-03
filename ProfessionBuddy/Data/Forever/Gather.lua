----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/Forever/Gather.lua
-- WoW: Forever ore veins and herbs: node NAME -> the skill it needs. The
-- game's own node tooltip names the profession ("Requires Mining") but not
-- the skill, and in combat hides the whole tooltip (m4ru's /pbt tip check,
-- 2026-10-02), so PB reads the name out of combat and looks it up here.
--
-- The Classic-era rows of Data/GatherMobs.lua's node tables (TBC
-- Anniversary): node name -> lock id from cmangos gameobject names, lock
-- id -> skill from the client Lock table on wago.tools. Forever's own Lock
-- values for ore and herbs match Classic Era (research 2026-09-23). Outland
-- nodes and Bloodthistle (Eversong only) are left out. A wrong value gets
-- fixed from a player's report (m4ru's call, 2026-10-02).
----------------------------------------------------------------------
ProfBuddy = ProfBuddy or {}

ProfBuddy.MiningNodes = {
    ["Copper Vein"]=1,
    ["Dark Iron Deposit"]=230,
    ["Gold Vein"]=155,
    ["Hakkari Thorium Vein"]=275,
    ["Incendicite Mineral Vein"]=65,
    ["Indurium Mineral Vein"]=150,
    ["Iron Deposit"]=125,
    ["Large Obsidian Chunk"]=305,
    ["Lesser Bloodstone Deposit"]=75,
    ["Mithril Deposit"]=175,
    ["Ooze Covered Gold Vein"]=155,
    ["Ooze Covered Iron Deposit"]=125,
    ["Ooze Covered Mithril Deposit"]=175,
    ["Ooze Covered Rich Thorium Vein"]=275,
    ["Ooze Covered Silver Vein"]=75,
    ["Ooze Covered Thorium Vein"]=245,
    ["Ooze Covered Truesilver Deposit"]=230,
    ["Rich Thorium Vein"]=275,
    ["Silver Vein"]=75,
    ["Small Obsidian Chunk"]=305,
    ["Small Thorium Vein"]=245,
    ["Tin Vein"]=65,
    ["Truesilver Deposit"]=230,
}

ProfBuddy.HerbNodes = {
    ["Arthas' Tears"]=220,
    ["Black Lotus"]=300,
    ["Blindweed"]=235,
    ["Briarthorn"]=70,
    ["Bruiseweed"]=100,
    ["Dreamfoil"]=270,
    ["Earthroot"]=15,
    ["Fadeleaf"]=160,
    ["Firebloom"]=205,
    ["Ghost Mushroom"]=245,
    ["Golden Sansam"]=260,
    ["Goldthorn"]=170,
    ["Grave Moss"]=120,
    ["Gromsblood"]=250,
    ["Icecap"]=290,
    ["Khadgar's Whisker"]=185,
    ["Kingsblood"]=125,
    ["Liferoot"]=150,
    ["Mageroyal"]=50,
    ["Mountain Silversage"]=280,
    ["Peacebloom"]=1,
    ["Plaguebloom"]=285,
    ["Purple Lotus"]=210,
    ["Silverleaf"]=1,
    ["Stranglekelp"]=85,
    ["Sungrass"]=230,
    ["Wild Steelbloom"]=115,
    ["Wintersbite"]=195,
}
