----------------------------------------------------------------------
-- A fake WoW: Forever vendor for the Forever harness.
--
-- Answers the calls Blizzard's own vendor window makes on Forever
-- (MerchantFrame.lua and MerchantFrameDocumentation.lua, `forever`
-- branch): GetMerchantNumItems, GetMerchantItemID(i), and
-- C_MerchantFrame.GetItemInfo(i) with price and numAvailable.
-- MERCHANT_OPEN(npcID) opens one and fires MERCHANT_SHOW. The items are
-- real Forever items; the vendors are made up.
----------------------------------------------------------------------

MERCHANTS = {
    [90101] = { name = "Test Vendor", zone = "Thunder Bluff", items = {
        { id = 2318, price = 55, stock = -1 },     -- Light Leather, not a recipe item
        { id = 5083, price = 1350, stock = 1 },    -- Pattern: Kodo Hide Bag
        { id = 240018, price = 5000, stock = -1 }, -- teaches three Engineering tinkers
    } },
    [90102] = { name = "Other Vendor", zone = "Orgrimmar", items = {
        { id = 5083, price = 1400, stock = -1 },
    } },
}

MERCHANT = { open = nil }

-- Blizzard_SharedXML/FormattingUtil.lua draws coin icons; this spells it.
function GetMoneyString(copper) return "MONEY:" .. copper end

function GetMerchantNumItems()
    local m = MERCHANT.open and MERCHANTS[MERCHANT.open]
    return m and #m.items or 0
end
function GetMerchantItemID(i)
    local m = MERCHANT.open and MERCHANTS[MERCHANT.open]
    return m and m.items[i] and m.items[i].id or nil
end
C_MerchantFrame = C_MerchantFrame or {}
C_MerchantFrame.GetItemInfo = function(i)
    local m = MERCHANT.open and MERCHANTS[MERCHANT.open]
    local it = m and m.items[i]
    return it and { name = "x", texture = 1, price = it.price, stackCount = 1,
                    numAvailable = it.stock, isPurchasable = true } or nil
end

local baseUnitName, baseUnitGUID, baseFaction = UnitName, UnitGUID, UnitFactionGroup
function UnitName(u)
    if u == "npc" and MERCHANT.open then return MERCHANTS[MERCHANT.open].name end
    return baseUnitName(u)
end
function UnitGUID(u)
    if u == "npc" and MERCHANT.open then return "Creature-0-1-1-1-" .. MERCHANT.open .. "-00001A2B3C" end
    return baseUnitGUID(u)
end
function UnitFactionGroup(u)
    if u == "npc" and MERCHANT.open then return "Horde" end
    return baseFaction(u)
end

local baseZone = GetRealZoneText
function GetRealZoneText()
    if MERCHANT.open then return MERCHANTS[MERCHANT.open].zone end
    return baseZone()
end

function MERCHANT_OPEN(npcID)
    MERCHANT.open = npcID
    FIRE("MERCHANT_SHOW")
end
function MERCHANT_CLOSE()
    MERCHANT.open = nil
    FIRE("MERCHANT_CLOSED")
end
