----------------------------------------------------------------------
-- ProfessionBuddy  --  Prices.lua
-- What a craft costs and what it sells for (2.1.0, SCOPE-2.1.0.md).
--
-- An item's auction price comes from the first source with a value, in
-- this order: Auctionator, TradeSkillMaster, then the auction prices PB
-- recorded. Auctionator and TSM are read only when they are installed and
-- switched on in Settings > Prices; PB works the same without them.
-- A material a vendor sells is never priced above the vendor's price:
-- the price PB recorded at a vendor, else the baked one
-- (Data/VendorPrices.lua, Data/Forever/VendorPrices.lua, tools/vendor_db.py).
-- A material one of your characters crafts (as the Material Calculator
-- would) costs the cheaper of buying it and crafting it.
-- Prices are never sent to other players.
----------------------------------------------------------------------

local addon = ProfBuddy
local P = addon:NewModule("Prices")

-- Auctionator API v1 refuses a call without a caller name
P.CALLER = "ProfessionBuddy"
-- The auction house keeps 5% of a sale (Auctionator's own constant,
-- AfterAHCut = 0.95, on both clients)
P.AH_CUT = 0.05
-- How deep crafted materials are followed (Felsteel Bar, then its bars)
P.MAX_DEPTH = 6

local SOURCE_NAMES = {
    Auctionator = "Auctionator",
    TSM = "TSM",
    PB = "recorded by ProfessionBuddy",
    vendor = "vendor",
    vendorSeen = "vendor",
}

-- Recorded auction prices older than this are dropped at login
P.KEEP_DAYS = 30

function P:Init()
    addon:RegisterEvent("MERCHANT_SHOW", function() P:ScanMerchant() end)
    addon:RegisterEvent("MERCHANT_UPDATE", function() P:ScanMerchant() end)
    self:PruneRecorded()
end

-- Drop recorded auction prices older than KEEP_DAYS. Returns how many.
function P:PruneRecorded()
    local st = addon.db and addon.db.prices
    local cutoff = time() - self.KEEP_DAYS * 86400
    local n = 0
    for _, house in pairs(st and type(st.auction) == "table" and st.auction or {}) do
        if type(house) == "table" then
            for id, e in pairs(house) do
                if type(e) ~= "table" or not tonumber(e.t) or e.t < cutoff then
                    house[id] = nil
                    n = n + 1
                end
            end
        end
    end
    return n
end

local function Settings() return addon.db and addon.db.settings or {} end

function P:Enabled() return Settings().showPrices ~= false end

----------------------------------------------------------------------
-- Sources
----------------------------------------------------------------------

function P:HasAuctionator()
    local api = type(Auctionator) == "table" and type(Auctionator.API) == "table" and Auctionator.API.v1
    return type(api) == "table" and type(api.GetAuctionPriceByItemID) == "function"
end

function P:HasTSM()
    return type(TSM_API) == "table" and type(TSM_API.GetCustomPriceValue) == "function"
end

function P:UsesAuctionator() return Settings().priceAuctionator ~= false and self:HasAuctionator() end
function P:UsesTSM() return Settings().priceTSM ~= false and self:HasTSM() end

-- The TSM price source the player typed (Settings), DBMarket by default
function P:TSMSource()
    local s = Settings().priceTSMSource
    if type(s) ~= "string" or strtrim(s) == "" then return "DBMarket" end
    return strtrim(s)
end

-- Does TSM accept this price source? nil when TSM cannot say.
function P:TSMSourceValid(s)
    if not (self:HasTSM() and type(TSM_API.IsCustomPriceValid) == "function") then return nil end
    local ok, valid = pcall(TSM_API.IsCustomPriceValid, s)
    return ok and valid and true or false
end

-- The auction house PB records prices for: realm and faction. The neutral
-- houses are left out (Decision P8), so this is only the faction's own.
function P:HouseKey()
    local realm = GetRealmName and GetRealmName() or ""
    local faction = UnitFactionGroup and UnitFactionGroup("player") or ""
    return addon:NormRealm(realm) .. "-" .. tostring(faction)
end

-- PB's own prices, created on first use: auction[house][itemID] and
-- vendor[itemID], each { p = copper per item, t = time seen }
function P:Store()
    local db = addon.db
    db.prices = type(db.prices) == "table" and db.prices or {}
    db.prices.auction = type(db.prices.auction) == "table" and db.prices.auction or {}
    db.prices.vendor = type(db.prices.vendor) == "table" and db.prices.vendor or {}
    return db.prices
end

local function Valid(e)
    return type(e) == "table" and type(e.p) == "number" and e.p > 0 and e or nil
end

-- An auction price PB recorded at this auction house
function P:Recorded(itemID)
    local st = addon.db and addon.db.prices
    local house = st and type(st.auction) == "table" and st.auction[self:HouseKey()]
    return type(house) == "table" and Valid(house[itemID]) or nil
end

-- Copper per item, the source, and its age in days (nil when unknown)
function P:AuctionPrice(itemID)
    if not itemID then return nil end
    if self:UsesAuctionator() then
        local api = Auctionator.API.v1
        local ok, price = pcall(api.GetAuctionPriceByItemID, self.CALLER, itemID)
        if ok and type(price) == "number" and price > 0 then
            local age
            if type(api.GetAuctionAgeByItemID) == "function" then
                local ok2, days = pcall(api.GetAuctionAgeByItemID, self.CALLER, itemID)
                if ok2 and type(days) == "number" then age = days end
            end
            return price, "Auctionator", age
        end
    end
    if self:UsesTSM() then
        local ok, price = pcall(TSM_API.GetCustomPriceValue, self:TSMSource(), "i:" .. itemID)
        if ok and type(price) == "number" and price > 0 then
            return price, "TSM", nil
        end
    end
    local rec = self:Recorded(itemID)
    if rec then
        local t = tonumber(rec.t)
        return rec.p, "PB", t and math.max(0, (time() - t) / 86400) or nil
    end
    return nil
end

-- What a vendor charges for one: the price PB saw at a vendor, else the
-- baked one
function P:VendorBuy(itemID)
    local st = addon.db and addon.db.prices
    local seen = st and type(st.vendor) == "table" and Valid(st.vendor[itemID])
    if seen then return seen.p, "vendorSeen" end
    local v = addon.VendorPrices and addon.VendorPrices[itemID]
    if type(v) == "number" and v > 0 then return v, "vendor" end
    return nil
end

-- What a vendor pays for one (the game's own item data)
function P:VendorSell(itemID)
    local getInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if not (itemID and getInfo) then return nil end
    local sell = select(11, getInfo(itemID))
    if type(sell) == "number" and sell > 0 then return sell end
    return nil
end

-- Binds when picked up (GetItemInfo's bindType, the same on both clients):
-- it can't go to the auction house, so only a vendor buys it. Some crafts
-- are BoP on WoW: Forever that weren't in the original game, and an old
-- auction price for them made a loss look like a sale (guild, TEST-b).
-- An item the game hasn't loaded yet answers nothing: PB asks for it and
-- notes it in P._unloaded, and the detail panel's price line looks again
-- (TSF:ShowPriceLine).
P.BIND_ON_PICKUP = (Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire) or 1
function P:IsBoP(itemID)
    local getInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if not (itemID and getInfo) then return false end
    local bind = select(14, getInfo(itemID))
    if bind == nil then
        self._unloaded = true
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        return false
    end
    return bind == self.BIND_ON_PICKUP
end

----------------------------------------------------------------------
-- Vendors: record the price of every recipe material the open vendor
-- sells with unlimited stock, for money alone. Price per item (a vendor
-- sells some in stacks). Returns how many were recorded.
----------------------------------------------------------------------
function P:ScanMerchant()
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    if n == 0 or not addon.db or not GetMerchantItemID then return 0 end
    local RDB = addon.RecipeDB
    local used = RDB and RDB.reagentUsedIn or {}
    local store = self:Store().vendor
    local now = time()
    local recorded = 0
    for i = 1, n do
        local itemID = GetMerchantItemID(i)
        if itemID and used[itemID] then
            local price, stack, avail, extended
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                -- WoW: Forever
                local info = C_MerchantFrame.GetItemInfo(i)
                if info then
                    price, stack, avail, extended = info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
                end
            elseif GetMerchantItemInfo then
                -- TBC Anniversary
                local _
                _, _, price, stack, avail, _, _, extended = GetMerchantItemInfo(i)
            end
            if type(price) == "number" and price > 0 and avail == -1 and not extended then
                local unit = price / math.max(tonumber(stack) or 1, 1)
                local old = store[itemID]
                if not (type(old) == "table" and old.p == unit) then recorded = recorded + 1 end
                store[itemID] = { p = unit, t = now }
            end
        end
    end
    if recorded > 0 then self:Changed() end
    return recorded
end

-- Clear every price PB recorded (Settings > Prices)
function P:ClearRecorded()
    if addon.db then addon.db.prices = nil end
    self:Changed()
end

-- Prices or price settings changed: redraw what shows them
function P:Changed()
    self._listCache = nil
    -- the scan buttons follow the Auctionator and TSM boxes (AuctionPrices.lua)
    if addon.AuctionPrices and addon.AuctionPrices.UpdateTab then addon.AuctionPrices:UpdateTab() end
    local tsf = addon.TradeSkillFrame
    if not (tsf and tsf.frame and tsf.frame:IsShown()) then return end
    if tsf.RefreshRecipeList and tsf.scrollBar and (self:ListProfitOn() or Settings().priceHideLoss) then
        tsf:RefreshRecipeList()
    end
    if tsf.RefreshDetailPanel and tsf.state and tsf.state.selected then tsf:RefreshDetailPanel(true) end
    if tsf.calcPanel and tsf.calcPanel:IsShown() and tsf.RefreshCalcPanel then tsf:RefreshCalcPanel() end
end

----------------------------------------------------------------------
-- Craft costs
----------------------------------------------------------------------

local function StaleDays()
    local d = tonumber(Settings().priceStaleDays)
    return (d and d > 0) and d or 7
end

function P:IsStale(age)
    return type(age) == "number" and age > StaleDays()
end

-- The recipe one of your characters knows that makes this material, as
-- the Material Calculator picks it: never an item on a recipe cycle.
function P:Producer(itemID)
    local RDB = addon.RecipeDB
    if not (RDB and itemID and itemID > 0) or RDB:IsCyclicItem(itemID) then return nil end
    local info = RDB:GetRecipeForItem(itemID)
    if info and RDB:AnyoneKnows(info.recipeName, info.profName) then
        local data = RDB.data[info.profName] and RDB.data[info.profName][info.recipeName]
        if data and data.reagents then return info, data end
    end
    return nil
end

local function Yield(data)
    local y = data and tonumber(data.yield)
    return (y and y > 0) and math.floor(y) or 1
end

-- What one of this material costs:
--   unit     copper per item, or nil when nothing prices it
--   used     "buy" or "craft"
--   bop      it binds when picked up: never an auction price (TEST-b2)
--   buy, buySource, age, stale
--   craft    copper per item crafted; craftMissing = its materials with no price
--   partial  true when unit leaves out materials with no price
-- seen guards the crafting chain against loops.
function P:MaterialPrice(itemID, seen, depth)
    seen, depth = seen or {}, depth or 0
    local r = {}
    r.bop = self:IsBoP(itemID)
    -- a BoP material can't be listed, so any auction price for it is old
    -- data from when it could be traded; a vendor's price still counts
    local auction, src, age
    if not r.bop then auction, src, age = self:AuctionPrice(itemID) end
    local vendor, vsrc = self:VendorBuy(itemID)
    if auction then r.buy, r.buySource, r.age = auction, src, age end
    if vendor and (not r.buy or vendor < r.buy) then
        r.buy, r.buySource, r.age = vendor, vsrc, nil
    end
    r.stale = self:IsStale(r.age)

    if depth < self.MAX_DEPTH and not seen[itemID] then
        local _, data = self:Producer(itemID)
        if data then
            seen[itemID] = true
            local c = self:ReagentsCost(data.reagents, seen, depth + 1)
            seen[itemID] = nil
            r.craft = c.total / Yield(data)
            r.craftMissing = c.missing
            r.craftParts = c.parts
        end
    end

    if r.craft and r.craftMissing == 0 and (not r.buy or r.craft < r.buy) then
        r.unit, r.used = r.craft, "craft"
    elseif r.buy then
        r.unit, r.used = r.buy, "buy"
    elseif r.craft and r.craft > 0 then
        r.unit, r.used, r.partial = r.craft, "craft", true
    end
    return r
end

-- Sum a reagent list: total copper, how many materials have no price
-- (bopMissing of them because they bind when picked up), and one part per
-- reagent
function P:ReagentsCost(reagents, seen, depth)
    local out = { total = 0, missing = 0, missingNames = {}, bopMissing = 0, bopNames = {}, parts = {}, stale = false }
    for _, rg in ipairs(reagents or {}) do
        local cnt = tonumber(rg.count) or 1
        if cnt < 1 then cnt = 1 end
        local id = tonumber(rg.itemID)
        local mp = (id and id > 0) and self:MaterialPrice(id, seen, depth) or {}
        out.parts[#out.parts + 1] = { itemID = id, name = rg.name, count = cnt, price = mp }
        if mp.unit then out.total = out.total + mp.unit * cnt end
        if not mp.unit or mp.partial then
            out.missing = out.missing + 1
            if mp.bop and not mp.unit then
                out.bopMissing = out.bopMissing + 1
                out.bopNames[#out.bopNames + 1] = rg.name or "?"
            else
                out.missingNames[#out.missingNames + 1] = rg.name or "?"
            end
        end
        if mp.used == "buy" and mp.stale then out.stale = true end
    end
    return out
end

-- The reagents and static data for a recipe shown in the window
local function RecipeData(recipe, profName)
    local RDB = addon.RecipeDB
    local data = RDB and RDB.data and profName and RDB.data[profName] and RDB.data[profName][recipe.name]
    if not data and RDB and RDB.GetRecipeByName then
        local info = RDB:GetRecipeByName(recipe.name, profName)
        data = info and RDB.data[info.profName] and RDB.data[info.profName][info.recipeName]
    end
    local reagents = recipe.reagents
    if not (reagents and #reagents > 0) then reagents = data and data.reagents end
    return reagents, data
end

-- Cost, sale price and profit of one craft:
--   cost, missing, missingNames, bopMissing, bopNames,
--   parts, stale                                  (ReagentsCost)
--   itemID, yield
--   bop                                           the product binds when picked up
--   sell, sellSource, sellAge, sellStale          the product's auction price per item
--   vendorSell                                    what a vendor pays per item
--   profit                                        per craft; nil without a sale price
--   profitFrom                                    "auction" or "vendor"
-- nil when the recipe has no reagents.
function P:RecipeCost(recipe, profName)
    if not recipe or not recipe.name then return nil end
    local reagents, data = RecipeData(recipe, profName)
    if not (reagents and #reagents > 0) then return nil end
    local itemID = tonumber(recipe.itemID) or (data and tonumber(data.itemID))
    if itemID and itemID <= 0 then itemID = nil end
    local seen = {}
    if itemID then seen[itemID] = true end
    local r = self:ReagentsCost(reagents, seen, 0)
    r.cost = r.total
    r.itemID = itemID
    r.yield = Yield(data)
    -- a random amount (Coarse Dynamite 1 to 3): yield is the middle, so the
    -- sale and profit are for the middle; the detail panel says "priced as 2" (2.1.1)
    local lo, hi = data and tonumber(data.yieldMin), data and tonumber(data.yieldMax)
    if lo and hi and lo ~= hi then r.yieldMin, r.yieldMax = lo, hi end
    if itemID then
        r.bop = self:IsBoP(itemID)
        -- a BoP product has no auction price, whatever a price addon kept
        if not r.bop then r.sell, r.sellSource, r.sellAge = self:AuctionPrice(itemID) end
        r.sellStale = self:IsStale(r.sellAge)
        -- Settings > Prices: "Show vendor sale price" (on) and, under it,
        -- "Only show the better sale price" (off)
        local showVendor = Settings().priceVendorSell ~= false
        r.vendorSell = showVendor and self:VendorSell(itemID) or nil
        local auctionNet = r.sell and r.sell * r.yield * (1 - self.AH_CUT)
        local vendorTotal = r.vendorSell and r.vendorSell * r.yield
        r.better = showVendor and Settings().priceBetterSale == true
        if auctionNet and (not r.better or not vendorTotal or auctionNet >= vendorTotal) then
            r.profit = auctionNet - r.cost
            r.profitFrom = "auction"
        elseif vendorTotal then
            r.profit = vendorTotal - r.cost
            r.profitFrom = "vendor"
        end
    end
    return r
end

----------------------------------------------------------------------
-- The recipe list: Profit column, sort and "Hide crafts at a loss"
-- (Settings > Prices). One cost per recipe per list refresh.
----------------------------------------------------------------------

function P:ListProfitOn() return self:Enabled() and Settings().priceListProfit == true end
function P:HideLossOn() return self:Enabled() and Settings().priceHideLoss == true end

-- A new list refresh: forget the costs worked out for the last one
function P:ResetListCache() self._listCache, self._shuffleCache = nil, nil end

-- A recipe's profit per craft, or nil when it has none (no sale price, a
-- material without a price, an enchant); then whether its product binds
-- when picked up
function P:ListProfit(recipe, profName)
    if not (recipe and recipe.name) then return nil end
    self._listCache = self._listCache or {}
    local key = (profName or "") .. "|" .. recipe.name
    local v = self._listCache[key]
    if v == nil then
        local r = self:RecipeCost(recipe, profName)
        v = { p = (r and r.profit and r.missing == 0) and r.profit or nil, b = r and r.bop or false }
        self._listCache[key] = v
    end
    return v.p, v.b
end

----------------------------------------------------------------------
-- Vendor shuffle (2.2.0, Skeleton): a craft sold straight to a vendor.
-- Its profit is what the vendor pays minus the materials' cost, priced
-- as everywhere else (materials you hold count at their price, m4ru
-- V5); per hour from the craft's cast time plus a gap between casts.
----------------------------------------------------------------------
P.SHUFFLE_GAP = 0.5             -- seconds between casts (m4ru V4)
P.SHUFFLE_MIN_DEFAULT = 100     -- 1s (m4ru V3)
P.SHUFFLE_MINS = { 0, 50, 100, 500, 1000, 5000, 10000 }

-- A minimum's label: "Any profit", or the amount ("1s")
function P:ShuffleMinLabel(copper)
    if (tonumber(copper) or 0) == 0 then return "Any profit" end
    return self:Money(copper)
end

-- VendorShuffle, once per recipe per list refresh (false: none)
function P:ShuffleCached(recipe, profName)
    if not (recipe and recipe.name) then return nil end
    self._shuffleCache = self._shuffleCache or {}
    local key = (profName or "") .. "|" .. recipe.name
    local v = self._shuffleCache[key]
    if v == nil then
        v = self:VendorShuffle(recipe, profName) or false
        self._shuffleCache[key] = v
    end
    return v or nil
end

-- The minimum profit a craft needs to be listed, in copper
function P:ShuffleMin()
    local v = tonumber(Settings().shuffleMinProfit)
    if v and v >= 0 then return v end
    return self.SHUFFLE_MIN_DEFAULT
end

-- Seconds one craft takes: the cast time, at least 1 s (an instant craft
-- or a spell the game doesn't answer for still takes a global cooldown),
-- plus the gap
local function CraftSeconds(spellID)
    local castMs
    local id = tonumber(spellID)
    if id and id > 0 then
        -- the global where the client still has it (TBC Anniversary), as
        -- TradeSkillFrame.lua does; WoW: Forever only has C_Spell's
        if GetSpellInfo then
            castMs = select(4, GetSpellInfo(id))
        elseif C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(id)
            castMs = info and info.castTime
        end
    end
    local cast = (tonumber(castMs) or 0) / 1000
    if cast < 1 then cast = 1 end
    return cast + P.SHUFFLE_GAP
end

-- Every material bought from a vendor, down through crafted materials
local function FromVendors(parts)
    for _, part in ipairs(parts or {}) do
        local mp = part.price or {}
        if mp.used == "craft" then
            if not FromVendors(mp.craftParts) then return false end
        elseif not (mp.used == "buy" and (mp.buySource == "vendor" or mp.buySource == "vendorSeen")) then
            return false
        end
    end
    return true
end

-- One craft sold to a vendor:
--   cost, sell (what the vendor pays for the craft's whole yield), profit,
--   seconds (per craft), perHour (copper), fromVendors (every material from
--   a vendor), itemID, yield, parts (ReagentsCost's)
-- nil when it can't be worked out: no reagents, no product, a material with
-- no price, or no vendor price. loading = true when the product isn't
-- loaded yet (PB asked for it; look again).
function P:VendorShuffle(recipe, profName)
    if not (recipe and recipe.name) then return nil end
    local reagents, data = RecipeData(recipe, profName)
    if not (reagents and #reagents > 0) then return nil end
    local itemID = tonumber(recipe.itemID) or (data and tonumber(data.itemID))
    if not itemID or itemID <= 0 then return nil end
    local unit = self:VendorSell(itemID)
    if not unit then
        local getInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
        if getInfo and getInfo(itemID) == nil then
            self._unloaded = true
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
            return { loading = true }
        end
        return nil
    end
    local seen = { [itemID] = true }
    local r = self:ReagentsCost(reagents, seen, 0)
    if r.missing > 0 then return nil end
    local yield = Yield(data)
    local out = { cost = r.total, sell = unit * yield, itemID = itemID, yield = yield, parts = r.parts }
    -- a random amount (2.1.1): the sale is for the middle of the range
    local lo, hi = data and tonumber(data.yieldMin), data and tonumber(data.yieldMax)
    if lo and hi and lo ~= hi then out.yieldMin, out.yieldMax = lo, hi end
    out.profit = out.sell - out.cost
    out.seconds = CraftSeconds((data and data.spellID) or recipe.spellID)
    out.perHour = out.profit * 3600 / out.seconds
    out.fromVendors = FromVendors(r.parts)
    return out
end

----------------------------------------------------------------------
-- Text
----------------------------------------------------------------------

local COIN = {
    g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
    s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
    c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}

-- "1g 20s 5c" with coin icons. short: no copper once there is gold
-- (rounded to the silver), for the calculator's narrow columns.
function P:Money(copper, short)
    copper = math.floor((tonumber(copper) or 0) + 0.5)
    if short and copper >= 10000 then copper = math.floor(copper / 100 + 0.5) * 100 end
    local g = math.floor(copper / 10000)
    local s = math.floor(copper / 100) % 100
    local c = copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. COIN.g end
    if s > 0 then out[#out + 1] = s .. COIN.s end
    if c > 0 or #out == 0 then out[#out + 1] = c .. COIN.c end
    return table.concat(out, " ")
end

-- "+85s" green or "-1g 2s" red; short as Money
function P:SignedMoney(copper, short)
    copper = math.floor((tonumber(copper) or 0) + 0.5)
    if copper < 0 then return "|cffff4444-" .. self:Money(-copper, short) .. "|r" end
    return "|cff00ff00+" .. self:Money(copper, short) .. "|r"
end

local GREY = "|cff808080"

local function AgeText(age)
    if type(age) ~= "number" then return nil end
    local d = math.floor(age)
    if d < 1 then return "today" end
    return d == 1 and "1 day old" or (d .. " days old")
end
P.AgeText = AgeText

-- "Auctionator, 2 days old" for a price's source
function P:SourceText(source, age)
    local name = SOURCE_NAMES[source] or tostring(source)
    if source == "TSM" then name = "TSM " .. self:TSMSource() end
    local a = AgeText(age)
    return a and (name .. ", " .. a) or name
end

-- "1 material has no price" / "2 materials have no price"; bop of the n
-- bind when picked up and say so instead ("1 material binds when picked up")
function P:MissingText(n, bop)
    bop = bop or 0
    local plain, out = n - bop, {}
    if plain > 0 then out[#out + 1] = plain == 1 and "1 material has no price" or (plain .. " materials have no price") end
    if bop > 0 then out[#out + 1] = bop == 1 and "1 material binds when picked up" or (bop .. " materials bind when picked up") end
    return table.concat(out, ", ")
end

-- The detail panel's line under Can make:
-- "Cost: 1g 20s   Sells: 2g 5s   Profit: +85s", or with a material that
-- has no price, "Cost: 1g 20s+ (1 material has no price)" and no profit.
-- fits(text), when given, says whether text fits on one line of the panel:
-- a piece that doesn't fit starts a new line, so a price never splits
-- across two lines (TEST-a4: "Profit: +7g 83s" above "3c").
function P:DetailText(r, fits)
    local pieces = self:DetailPieces(r)
    local out, cur = pieces[1].text, pieces[1].text
    for i = 2, #pieces do
        local p = pieces[i]
        local joined = cur .. p.sep .. p.text
        if fits and not fits(joined) then
            out, cur = out .. "\n" .. p.text, p.text
        else
            out, cur = out .. p.sep .. p.text, joined
        end
    end
    return out
end

-- DetailText's pieces, in order: { text, sep }, sep being what joins the
-- piece to the one before it on the same line
function P:DetailPieces(r)
    local pieces = {}
    local function add(text, sep) pieces[#pieces + 1] = { text = text, sep = sep or "   " } end
    local cost = (r.missing > 0 and r.total == 0) and "?" or self:Money(r.cost)
    if r.missing > 0 and r.total > 0 then cost = cost .. "+" end
    if r.stale then cost = GREY .. cost .. "|r" end
    local line = "Cost: " .. cost
    if r.missing > 0 then line = line .. " " .. GREY .. "(" .. self:MissingText(r.missing, r.bopMissing) .. ")|r" end
    add(line)
    -- a random amount: the sale and profit are for the middle of the range;
    -- the Category line above says so ("Makes 1-3 (priced as 2)"), so this
    -- line carries no mark and fits on one line (TEST-a3)
    local auction = r.sell and self:Money(r.sell * r.yield)
    if auction and r.sellStale then auction = GREY .. auction .. "|r" end
    local vendor = r.vendorSell and self:Money(r.vendorSell * r.yield)
    if r.bop then
        add(vendor and ("Sells: " .. vendor .. " (vendor, BoP)") or "BoP")
    elseif r.better and auction and vendor then
        -- only the better sale price, labeled
        add("Sells: " .. (r.profitFrom == "vendor" and (vendor .. " (vendor)") or (auction .. " (auction)")))
    elseif auction then
        add("Sells: " .. auction)
        if vendor then add("vendor " .. vendor, ", ") end
    elseif vendor then
        add("Sells: " .. vendor .. " (vendor)")
    end
    if r.profit and r.missing == 0 then
        add("Profit: " .. self:SignedMoney(r.profit))
    end
    return pieces
end

-- A material you craft shows both prices: the one used bright, the other
-- muted tan. Gray only ever means an old price (TEST-a: gray for both read
-- the same).
local TAN = "|cffb59e74"
P.TAN = TAN
local function Pick(text, used, stale)
    if stale then return GREY .. text .. "|r" end
    return used and ("|cffffffff" .. text .. "|r") or (TAN .. text .. "|r")
end

-- One material's price for a tooltip line: "40s (Auctionator)" or, for a
-- material you craft, "buy 40s (Auctionator)  craft 32s" with the one used
-- bright (Settings: Crafted materials, show both) or only the one used
function P:MaterialText(mp, count)
    count = count or 1
    if not mp or not mp.unit then return (mp and mp.bop) and ("|cffff4444?|r " .. GREY .. "(BoP)|r") or "|cffff4444?|r" end
    local buy = mp.buy and (self:Money(mp.buy * count) .. " (" .. self:SourceText(mp.buySource, mp.age) .. ")")
    local craft = mp.craft and ("craft " .. self:Money(mp.craft * count) .. ((mp.craftMissing or 0) > 0 and "+" or ""))
    if buy and craft and Settings().priceIntermediates ~= "cheaper" then
        return Pick("buy " .. buy, mp.used == "buy", mp.stale) .. "  " .. Pick(craft, mp.used == "craft")
    end
    if mp.used == "craft" then return craft end
    return mp.stale and (GREY .. buy .. "|r") or buy
end

-- The detail line's tooltip: each material's price and source, then the
-- sale and the profit
function P:FillTooltip(tt, r)
    tt:AddLine("Cost of one craft", 1, 0.82, 0)
    for _, part in ipairs(r.parts) do
        tt:AddDoubleLine(part.count .. " x " .. (part.name or "?"), self:MaterialText(part.price, part.count),
            0.9, 0.9, 0.9, 1, 1, 1)
    end
    local plain = r.missing - (r.bopMissing or 0)
    if plain > 0 then
        tt:AddLine(self:MissingText(plain) .. ": " .. table.concat(r.missingNames, ", "), 1, 0.27, 0.27, true)
    end
    if (r.bopMissing or 0) > 0 then
        tt:AddLine(self:MissingText(r.bopMissing, r.bopMissing) .. ": " .. table.concat(r.bopNames, ", ")
            .. (r.bopMissing == 1 and ". It can't be bought." or ". They can't be bought."), 0.7, 0.7, 0.7, true)
    end
    if not r.itemID then return end
    tt:AddLine(" ")
    local makes = r.yield > 1 and (" (makes " .. r.yield .. ")") or ""
    if r.yieldMin then makes = " (makes " .. r.yieldMin .. "-" .. r.yieldMax .. ", about " .. r.yield .. ")" end
    if r.bop then
        tt:AddLine("Binds when picked up: it can't be sold at auction, only to a vendor.", 0.9, 0.9, 0.9, true)
    elseif r.sell then
        local t = self:Money(r.sell * r.yield) .. " (" .. self:SourceText(r.sellSource, r.sellAge) .. ")"
        if r.sellStale then t = GREY .. t .. "|r" end
        tt:AddDoubleLine("Sells at auction" .. makes, t, 0.9, 0.9, 0.9, 1, 1, 1)
    else
        tt:AddDoubleLine("Sells at auction" .. makes, "no price", 0.9, 0.9, 0.9, 0.5, 0.5, 0.5)
    end
    if r.vendorSell then
        tt:AddDoubleLine("Vendor pays", self:Money(r.vendorSell * r.yield), 0.9, 0.9, 0.9, 1, 1, 1)
    end
    -- a craft that makes more than one: what one item sells for (2.1.1,
    -- m4ru couldn't find one Elemental Blasting Powder's price)
    if r.yield > 1 and (r.sell or r.vendorSell) then
        local each = {}
        if r.sell and not r.bop then each[#each + 1] = self:Money(r.sell) .. " at auction" end
        if r.vendorSell then each[#each + 1] = self:Money(r.vendorSell) .. " from a vendor" end
        if #each > 0 then
            tt:AddLine("One item: " .. table.concat(each, ", "), 0.5, 0.5, 0.5, true)
        end
    end
    if r.profit then
        local how = r.profitFrom == "auction"
            and "Auction price less the 5% auction house cut, less the cost."
            or (r.bop and "Vendor price less the cost.")
            or (r.sell and "Vendor price less the cost (better than the auction price less its 5% cut)."
                or "Vendor price less the cost (no auction price).")
        if r.missing > 0 then
            tt:AddLine("No profit shown: " .. self:MissingText(r.missing, r.bopMissing) .. ".", 0.5, 0.5, 0.5, true)
        else
            tt:AddDoubleLine("Profit", self:SignedMoney(r.profit), 0.9, 0.9, 0.9, 1, 1, 1)
            tt:AddLine(how, 0.5, 0.5, 0.5, true)
        end
    end
end
