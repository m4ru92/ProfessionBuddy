----------------------------------------------------------------------
-- Stub environment for the TBC Classic Anniversary window harness.
--
-- forever_env.lua with the TBC client's differences: the classic API is
-- present (GetItemInfo, GetSpellInfo, the trade skill and craft calls,
-- GetSkillLineInfo), every event is known, tooltips keep OnTooltipSetItem,
-- and the game reports TBC Anniversary (2.5.6, project 5). A small
-- simulated profession list lets PB open its windows the way it does in
-- game. Any other global still resolves to a do-nothing stub and is
-- recorded in FALLBACK.
----------------------------------------------------------------------

TOOLTIP_SCRIPTS_KEEP = true
BUILD_INTERFACE = 20506
dofile("tests/forever_env.lua")

wipe(REMOVED)
wipe(UNKNOWN_EVENTS)
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
WOW_PROJECT_ID = 5
function GetBuildInfo() return "2.5.6", "70577", "Oct 1 2026", 20506 end
ITEM_RANDOM_ENCHANT = "<Random enchantment>"
function UnitClass() return "Warrior", "WARRIOR" end
function UnitLevel() return 70 end
function UnitFactionGroup() return "Alliance" end
function GetRealmName() return "Realm" end
function GetProfessions() return nil end

-- Names the game would give, by item and spell ID.
ITEM_NAMES = { [2318] = "Light Leather", [2934] = "Ruined Leather Scraps", [10940] = "Strange Dust" }
SPELL_NAMES = {
    [2259] = "Alchemy", [2018] = "Blacksmithing", [2550] = "Cooking", [7411] = "Enchanting",
    [4036] = "Engineering", [3273] = "First Aid", [7620] = "Fishing", [9134] = "Herbalism",
    [25229] = "Jewelcrafting", [2108] = "Leatherworking", [2575] = "Mining", [8613] = "Skinning",
    [3908] = "Tailoring", [2656] = "Smelting", [2842] = "Poisons",
}
function GetItemInfo(id)
    id = tonumber(type(id) == "string" and id:match("item:(%d+)") or id)
    local n = id and ITEM_NAMES[id]
    if not n then return nil end
    -- the client's 14th value, bindType: 0 for these (nothing binds)
    return n, "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. n .. "]|h|r", 1, 5, 1, "Trade Goods", "Leather", 20, "", "icon", 5, 7, 0, 0
end
function GetItemCount() return 0 end
function GetItemIcon() return "icon" end
function GetSpellInfo(id) local n = SPELL_NAMES[id]; return n, nil, "icon" end
function GetSpellLink(id) return "|cff71d5ff|Hspell:" .. tostring(id) .. "|h[spell]|h|r" end
function GetSpellTexture() return "icon" end
function GetContainerNumSlots() return 0 end
function GetContainerItemInfo() return nil end
function GetContainerItemLink() return nil end
function IsAddOnLoaded() return false end
function GetAddOnMetadata() return nil end
function ChatEdit_InsertLink() return false end
function ChatFrame_AddMessageEventFilter() end
function GuildRoster() end

-- The simulated professions: skill lines, one trade skill window
-- (Leatherworking) and one craft window (Enchanting).
TBC = {
    skillLines = {
        { "Professions", true }, { "Leatherworking", false, 75, 150 }, { "Enchanting", false, 50, 75 },
        { "Secondary Skills", true }, { "Skinning", false, 70, 75 },
    },
    trade = { "Leatherworking", 75, 150 },
    tradeRows = {
        { "Leather", "header", 0, true },
        { "Light Leather", "easy", 3, nil, ITEM_NAMES[2318] and "|cffffffff|Hitem:2318::::::::|h[Light Leather]|h|r",
          reagents = { { "Ruined Leather Scraps", 3, 2934 } } },
        { "Handstitched Leather Boots", "optimal", 0, nil, nil },
    },
    craft = { "Enchanting", 50, 75 },
    craftRows = {
        { "Enchant Bracer - Minor Health", "optimal", 1, reagents = { { "Strange Dust", 1, 10940 } } },
    },
    open = nil,
}
function GetNumSkillLines() return #TBC.skillLines end
function GetSkillLineInfo(i)
    local r = TBC.skillLines[i]
    if not r then return nil end
    return r[1], r[2], r[2] or false, r[3], 0, 0, r[4]
end
function ExpandSkillHeader() end
function CollapseSkillHeader() end
function IsTradeSkillLinked() return false end
function CraftIsPetTraining() return false end
function CraftIsEnchanting() return true end
function GetTradeSkillLine() return TBC.trade[1], TBC.trade[2], TBC.trade[3] end
function GetNumTradeSkills() return TBC.open == "trade" and #TBC.tradeRows or 0 end
function GetTradeSkillInfo(i) local r = TBC.tradeRows[i]; if r then return r[1], r[2], r[3], r[4] end end
function GetTradeSkillItemLink(i) local r = TBC.tradeRows[i]; return r and r[5] end
function GetTradeSkillRecipeLink() return nil end
function GetTradeSkillIcon() return "icon" end
function GetTradeSkillCooldown() return nil end
function GetTradeSkillItemNameFilter() return "" end
function GetTradeSkillNumMade() return 1, 1 end
function GetTradeSkillReagentInfo(i, j)
    local g = TBC.tradeRows[i] and TBC.tradeRows[i].reagents and TBC.tradeRows[i].reagents[j]
    if g then return g[1], "icon", g[2], 0 end
end
function GetTradeSkillReagentItemLink(i, j)
    local g = TBC.tradeRows[i] and TBC.tradeRows[i].reagents and TBC.tradeRows[i].reagents[j]
    if g then return "|cffffffff|Hitem:" .. g[3] .. "::::::::|h[" .. g[1] .. "]|h|r" end
end
function GetTradeSkillTools() return nil end
function SelectTradeSkill() end
function DoTradeSkill(i, n) CALLS[#CALLS + 1] = "DoTradeSkill:" .. tostring(i) .. ":" .. tostring(n) end
function CloseTradeSkill() TBC.open = nil end
function GetCraftDisplaySkillLine() return TBC.craft[1], TBC.craft[2], TBC.craft[3] end
function GetCraftName() return TBC.craft[1] end
function GetNumCrafts() return TBC.open == "craft" and #TBC.craftRows or 0 end
function GetCraftInfo(i) local r = TBC.craftRows[i]; if r then return r[1], "sub", r[2], r[3] end end
function GetCraftItemLink() return nil end
function GetCraftRecipeLink() return nil end
function GetCraftIcon() return "icon" end
function GetCraftReagentInfo(i, j)
    local g = TBC.craftRows[i] and TBC.craftRows[i].reagents and TBC.craftRows[i].reagents[j]
    if g then return g[1], "icon", g[2], 0 end
end
function GetCraftReagentItemLink(i, j)
    local g = TBC.craftRows[i] and TBC.craftRows[i].reagents and TBC.craftRows[i].reagents[j]
    if g then return "|cffffffff|Hitem:" .. g[3] .. "::::::::|h[" .. g[1] .. "]|h|r" end
end
function GetCraftSpellFocus() return nil end
function SelectCraft() end
function DoCraft(i) CALLS[#CALLS + 1] = "DoCraft:" .. tostring(i) end
function CloseCraft() TBC.open = nil end

-- Open a profession window the way the client does.
function OPEN_TRADE()
    TBC.open = "trade"
    FIRE("TRADE_SKILL_SHOW"); FIRE("TRADE_SKILL_UPDATE"); FLUSH()
end
function OPEN_CRAFT()
    TBC.open = "craft"
    FIRE("CRAFT_SHOW"); FIRE("CRAFT_UPDATE"); FLUSH()
end
function CLOSE_TRADE() TBC.open = nil; FIRE("TRADE_SKILL_CLOSE"); FLUSH() end
function CLOSE_CRAFT() TBC.open = nil; FIRE("CRAFT_CLOSE"); FLUSH() end
