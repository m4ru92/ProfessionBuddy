----------------------------------------------------------------------
-- ProfessionBuddy  --  AuctionPrices.lua
-- Auction prices PB records itself (2.1.0, SCOPE-2.1.0.md S3 and S4).
--   * While you browse: every auction price the auction house shows for
--     an item PB's recipes use or make, the lowest per item this visit.
--   * Scan my materials: PB searches each material and product of the
--     recipes your characters know, one at a time, within the game's
--     search limits. It can be stopped.
--   * Full scan: the whole auction house at once, through the game's own
--     full-scan request, behind a warning (it can freeze the game for a
--     few seconds, and the game allows one about every 15 minutes).
-- The scan buttons show only while neither Auctionator nor TSM is
-- installed and switched on in Settings > Prices (Decision P10);
-- recording while you browse runs either way. Prices are stored per
-- realm and faction (Prices.lua); a neutral auction house, one whose
-- auctioneer is not of your faction, is not recorded (Decision P8).
-- WoW: Forever runs the modern auction house (C_AuctionHouse,
-- Blizzard_AuctionHouseUI); TBC Anniversary the classic one
-- (QueryAuctionItems, Blizzard_AuctionUI).
----------------------------------------------------------------------

local addon = ProfBuddy
local AP = addon:NewModule("AuctionPrices")

local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

AP.SEARCH_GAP = 0.7  -- seconds between searches (Forever: 100 a minute)
AP.WAIT = 5          -- seconds to wait for one search's results
AP.FULL_WAIT = 60    -- seconds to wait for a full scan's results
AP.CHUNK = 500       -- full scan auctions read per frame
AP.PAGE = 50         -- the classic auction house's page size

local function Say(text) print("|cff00ccffProfessionBuddy:|r " .. text) end

function AP:Modern() return addon.Source.flavor == "forever" end

function AP:Init()
    addon:RegisterEvent("AUCTION_HOUSE_SHOW", function() AP:OnShow() end)
    addon:RegisterEvent("AUCTION_HOUSE_CLOSED", function() AP:OnClose() end)
    if self:Modern() then
        addon:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
            AP:OnBrowse(C_AuctionHouse.GetBrowseResults())
        end)
        addon:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(_, added) AP:OnBrowse(added) end)
        addon:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) AP:OnCommodity(itemID) end)
        addon:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) AP:OnItemSearch(itemKey) end)
        addon:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", function() AP:OnReplicate() end)
    else
        addon:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", function() AP:OnList() end)
    end
end

----------------------------------------------------------------------
-- Recording
----------------------------------------------------------------------

-- An item PB has a reason to price: a material or a product of its recipes
function AP:Wanted(itemID)
    local RDB = addon.RecipeDB
    return (itemID and RDB and (RDB.reagentUsedIn[itemID] or RDB.itemToRecipe[itemID])) and true or false
end

-- One price seen: kept when it is the lowest for the item this visit
function AP:Note(itemID, unit)
    if not (self._open and self._record) then return end
    unit = tonumber(unit)
    if not (unit and unit > 0 and self:Wanted(itemID)) then return end
    local seen = self._visit[itemID]
    if seen and seen <= unit then return end
    self._visit[itemID] = unit
    local P = addon.Prices
    local store = P:Store().auction
    local key = P:HouseKey()
    store[key] = store[key] or {}
    store[key][itemID] = { p = unit, t = time() }
    self._noted = self._noted + 1
end

function AP:OnShow()
    self._open = true
    self._visit, self._noted = {}, 0
    -- a neutral auction house (Decision P8): its auctioneer is not of your faction
    local npc = UnitFactionGroup and UnitFactionGroup("npc")
    self._record = npc ~= nil and npc == UnitFactionGroup("player")
    -- the auction house window is built as it opens
    C_Timer.After(0, function() AP:UpdateBar() end)
end

function AP:OnClose()
    self._open = false
    self:StopScan(true)
    if self.bar then self.bar:Hide() end
    if (self._noted or 0) > 0 and addon.Prices then addon.Prices:Changed() end
end

-- WoW: Forever, the Browse list: one lowest price per item
function AP:OnBrowse(results)
    for _, r in ipairs(type(results) == "table" and results or {}) do
        local key = r.itemKey
        if key then self:Note(key.itemID, r.minPrice) end
    end
end

-- WoW: Forever, one commodity's auctions (materials): the lowest unit price
function AP:OnCommodity(itemID)
    local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local low
    for i = 1, math.min(n, 20) do
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        local p = info and tonumber(info.unitPrice)
        if p and p > 0 and (not low or p < low) then low = p end
    end
    if low then self:Note(itemID, low) end
    self:SearchDone(itemID)
end

-- WoW: Forever, one item's auctions (gear): the lowest buyout per item
function AP:OnItemSearch(itemKey)
    if not itemKey then return end
    local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local low
    for i = 1, math.min(n, 100) do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        local buyout = info and tonumber(info.buyoutAmount)
        local qty = info and tonumber(info.quantity) or 1
        if buyout and buyout > 0 and qty > 0 then
            local p = buyout / qty
            if not low or p < low then low = p end
        end
    end
    if low then self:Note(itemKey.itemID, low) end
    self:SearchDone(itemKey.itemID)
end

-- TBC Anniversary, a page of the Browse list (50 auctions). A longer list
-- is a full scan: PB's own is read in parts; another addon's is left alone.
function AP:OnList()
    local batch = GetNumAuctionItems("list") or 0
    if self._fullPending then
        self._fullPending = nil
        self:ReadFull(batch, function(i)
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
            return itemID, count, buyout
        end, 1)
        return
    end
    if batch > self.PAGE then return end
    for i = 1, batch do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
        if count and count > 0 and buyout and buyout > 0 then self:Note(itemID, buyout / count) end
    end
    self:SearchDone(nil)
end

-- WoW: Forever, PB's full scan arrived
function AP:OnReplicate()
    if not self._fullPending then return end
    self._fullPending = nil
    local n = C_AuctionHouse.GetNumReplicateItems() or 0
    self:ReadFull(n, function(i)
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
        return itemID, count, buyout
    end, 0)
end

-- Read a full scan a part per frame so the game does not stall twice
function AP:ReadFull(n, read, first)
    local i, last = first, first + n - 1
    local before = self._noted
    self:Status("Full scan: reading " .. n .. " auctions...")
    local function part()
        if not self._open then return end
        local stop = math.min(last, i + self.CHUNK - 1)
        for k = i, stop do
            local itemID, count, buyout = read(k)
            count, buyout = tonumber(count), tonumber(buyout)
            if count and count > 0 and buyout and buyout > 0 then self:Note(itemID, buyout / count) end
        end
        i = stop + 1
        if i <= last then
            C_Timer.After(0, part)
        else
            self._full = nil
            self:Status("Full scan done: " .. (self._noted - before) .. " prices recorded.")
            self:UpdateBar()
        end
    end
    part()
end

----------------------------------------------------------------------
-- Scan my materials
----------------------------------------------------------------------

-- Every material and product of the recipes your own characters know,
-- with the name the classic auction house searches by
function AP:MaterialList()
    local RDB, DS = addon.RecipeDB, addon.DataStore
    local list, seen = {}, {}
    local function add(id, name)
        id = tonumber(id)
        if not id or id <= 0 or seen[id] then return end
        name = name or (GetItemInfo and (GetItemInfo(id)))
        seen[id] = true
        list[#list + 1] = { id = id, name = name }
    end
    for _, char in pairs(DS and DS:GetAllCharacters() or {}) do
        if type(char) == "table" and not char.isRemote and type(char.professions) == "table" then
            for profName, prof in pairs(char.professions) do
                local data = RDB and RDB.data[profName]
                for recipeName in pairs(type(prof.recipes) == "table" and prof.recipes or {}) do
                    local r = data and data[recipeName]
                    if r then
                        for _, rg in ipairs(r.reagents or {}) do add(rg.itemID, rg.name) end
                        add(r.itemID)
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function AP:StartTargeted()
    if self._scan or self._full then return end
    local list = self:MaterialList()
    if not self:Modern() then
        -- the classic auction house searches by name
        local named = {}
        for _, e in ipairs(list) do if e.name then named[#named + 1] = e end end
        list = named
    end
    if #list == 0 then
        Say("No materials to scan yet: open your professions once so ProfessionBuddy knows your recipes.")
        return
    end
    self._scan = { list = list, i = 0, before = self._noted }
    self:UpdateBar()
    self:NextSearch()
end

function AP:NextSearch()
    local sc = self._scan
    if not sc then return end
    if not self._open then self:StopScan(true); return end
    -- the game's search limit: wait until it takes another search
    local ready
    if self:Modern() then
        ready = C_AuctionHouse.IsThrottledMessageSystemReady()
    else
        ready = CanSendAuctionQuery()
    end
    if not ready then
        C_Timer.After(0.3, function() if AP._scan == sc then AP:NextSearch() end end)
        return
    end
    sc.i = sc.i + 1
    local e = sc.list[sc.i]
    if not e then self:FinishScan(); return end
    sc.waiting = e.id
    self:Status("Scanning " .. sc.i .. " of " .. #sc.list .. "...")
    if self:Modern() then
        local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
        C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(e.id), { { sortOrder = order, reverseSort = false } }, false)
    else
        -- cheapest per item first, exact name
        SortAuctionSetSort("list", "unitprice")
        QueryAuctionItems(e.name, nil, nil, 0, nil, nil, false, true, nil)
    end
    local at = sc.i
    C_Timer.After(self.WAIT, function()
        if AP._scan == sc and sc.i == at and sc.waiting then AP:SearchDone(nil, true) end
    end)
end

-- One search answered (or timed out): on to the next
function AP:SearchDone(itemID, timedOut)
    local sc = self._scan
    if not (sc and sc.waiting) then return end
    if itemID and itemID ~= sc.waiting and not timedOut then return end
    sc.waiting = nil
    C_Timer.After(self.SEARCH_GAP, function() if AP._scan == sc then AP:NextSearch() end end)
end

function AP:FinishScan()
    local sc = self._scan
    self._scan = nil
    self:Status("Scan done: " .. (self._noted - (sc and sc.before or 0)) .. " prices recorded.")
    self:UpdateBar()
    if addon.Prices then addon.Prices:Changed() end
end

function AP:StopScan(quiet)
    if not self._scan then return end
    self._scan = nil
    if not quiet then self:Status("Scan stopped.") end
    self:UpdateBar()
end

----------------------------------------------------------------------
-- Full scan
----------------------------------------------------------------------

function AP:AskFull()
    if not StaticPopupDialogs["PROFBUDDY_FULL_SCAN"] then
        StaticPopupDialogs["PROFBUDDY_FULL_SCAN"] = {
            text = "A full scan reads the whole auction house at once. The game can freeze for a few seconds, and on classic clients it has disconnected some players. The game allows one about every 15 minutes, and other addons share that wait. Run it?",
            button1 = "Scan",
            button2 = "Cancel",
            OnAccept = function() AP:StartFull() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("PROFBUDDY_FULL_SCAN")
end

function AP:StartFull()
    if self._scan or self._full or not self._open then return end
    if not self:Modern() then
        local _, canAll = CanSendAuctionQuery()
        if not canAll then
            Say("The game does not allow a full scan yet (about one every 15 minutes, shared with other addons).")
            return
        end
    end
    self._full, self._fullPending = true, true
    self:Status("Full scan: waiting for the auction house...")
    self:UpdateBar()
    if self:Modern() then
        C_AuctionHouse.ReplicateItems()
    else
        QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
    end
    C_Timer.After(self.FULL_WAIT, function()
        if AP._fullPending then
            AP._fullPending, AP._full = nil, nil
            AP:Status("No full scan came back (the game allows one about every 15 minutes).")
            AP:UpdateBar()
        end
    end)
end

----------------------------------------------------------------------
-- The scan bar under the auction house window
----------------------------------------------------------------------

-- Hidden while Auctionator or TSM is installed and switched on (P10)
function AP:ScansShown()
    local P = addon.Prices
    return P and P:Enabled() and not (P:UsesAuctionator() or P:UsesTSM()) or false
end

function AP:Status(text)
    self._status = text
    if self.bar then self.bar.status:SetText(text or "") end
end

function AP:BuildBar()
    local f = CreateFrame("Frame", "ProfBuddyAuctionBar", UIParent, "BackdropTemplate")
    f:SetSize(460, 30)
    f:SetFrameStrata("HIGH")
    if addon.Theme and addon.Theme.SetBackdrop then
        addon.Theme:SetBackdrop(f, "dropdownList")
        addon.Theme:BackdropColor(f, "dropdownList")
        addon.Theme:BorderColor(f, "dropdownList")
    end
    local scan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scan:SetSize(140, 22)
    scan:SetPoint("LEFT", 6, 0)
    scan:SetScript("OnClick", function()
        if AP._scan then AP:StopScan() else AP:StartTargeted() end
    end)
    local full = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    full:SetSize(80, 22)
    full:SetPoint("LEFT", scan, "RIGHT", 4, 0)
    full:SetText("Full scan")
    full:SetScript("OnClick", function() AP:AskFull() end)
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("LEFT", full, "RIGHT", 8, 0)
    status:SetPoint("RIGHT", -6, 0)
    status:SetJustifyH("LEFT")
    f.scan, f.full, f.status = scan, full, status
    f:Hide()
    self.bar = f
end

function AP:UpdateBar()
    if not self._open or not self:ScansShown() then
        if self.bar then self.bar:Hide() end
        return
    end
    local ah = AuctionHouseFrame or AuctionFrame
    if not ah then return end
    if not self.bar then self:BuildBar() end
    local f = self.bar
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", ah, "BOTTOMLEFT", 0, -2)
    f.scan:SetText(self._scan and "Stop scan" or "Scan my materials")
    if self._full then f.full:Disable() else f.full:Enable() end
    if self._scan then f.full:Disable() end
    f.status:SetText(self._status or "ProfessionBuddy prices")
    f:Show()
end
