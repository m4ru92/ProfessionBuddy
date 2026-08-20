----------------------------------------------------------------------
-- ProfessionBuddy  --  Data/RandomEnchant.lua
-- Crafted result items that carry a random enchantment ("<Random
-- enchantment>"). The game only renders that line via the trade-skill result
-- path, not from an item ID or link, so PB appends it for these items.
-- Source: cmangos-tbc item_template RandomProperty/RandomSuffix (same DB family
-- as the gather data). See DESIGN-NOTES.md.
----------------------------------------------------------------------
ProfBuddy = ProfBuddy or {}
ProfBuddy.RandomEnchantItems = {
    [3474]  = true, -- Gemmed Copper Gauntlets
    [8210]  = true, -- Wild Leather Shoulders
    [8211]  = true, -- Wild Leather Vest
    [8212]  = true, -- Wild Leather Leggings
    [8213]  = true, -- Wild Leather Boots
    [8214]  = true, -- Wild Leather Helmet
    [8215]  = true, -- Wild Leather Cloak
    [10504] = true, -- Green Lens
    [20039] = true, -- Dark Iron Boots
    [20826] = true, -- Heavy Silver Ring
    [20964] = true, -- Aquamarine Signet
    [21768] = true, -- Sapphire Signet
    [23758] = true, -- Cogspinner Goggles
}
