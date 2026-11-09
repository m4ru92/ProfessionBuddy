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
-- The scan buttons sit on a ProfessionBuddy tab at the end of the
-- auction house's tabs (TEST-b2; a bar under the window covered the
-- tabs). The tab shows only while neither Auctionator nor TSM is
-- installed and switched on in Settings > Prices (Decision P10);
-- recording while you browse runs either way. Prices are stored per
-- realm and faction (Prices.lua); a neutral auction house (Booty Bay,
-- Gadgetzan, Everlook) is not recorded (Decision P8).
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

-- The neutral auction houses' towns, by the game's own area names (any
-- language): Booty Bay, Gadgetzan, Everlook. Area IDs from AreaTable, the
-- same on both clients (WoW: Forever 1.60.1.69913, TBC Anniversary
-- 2.5.6.69795); no smaller area inside those towns has its own name.
AP.NEUTRAL_AREAS = { 35, 976, 2255 }

-- A neutral auction house (Decision P8). WoW: Forever's auctioneers report
-- no faction (TEST-b: UnitFactionGroup("npc") is nil there), so the town
-- decides; an auctioneer that does report a faction other than yours
-- counts too.
function AP:AtNeutralHouse()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local areaName = C_Map and C_Map.GetAreaInfo
    for _, id in ipairs(self.NEUTRAL_AREAS) do
        local name = areaName and areaName(id)
        if name and name ~= "" and (sub == name or zone == name) then return true end
    end
    local npc = UnitFactionGroup and UnitFactionGroup("npc")
    return npc ~= nil and npc ~= UnitFactionGroup("player")
end

function AP:OnShow()
    self._open = true
    self._visit, self._noted = {}, 0
    self._record = not self:AtNeutralHouse()
    -- the auction house window is built as it opens
    C_Timer.After(0, function() AP:UpdateTab() end)
end

function AP:OnClose()
    self._open = false
    self:StopScan(true)
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
            self:UpdateTab()
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
    self:UpdateTab()
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
    self:UpdateTab()
    if addon.Prices then addon.Prices:Changed() end
end

function AP:StopScan(quiet)
    if not self._scan then return end
    self._scan = nil
    if not quiet then self:Status("Scan stopped.") end
    self:UpdateTab()
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
    self:UpdateTab()
    if self:Modern() then
        C_AuctionHouse.ReplicateItems()
    else
        QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
    end
    C_Timer.After(self.FULL_WAIT, function()
        if AP._fullPending then
            AP._fullPending, AP._full = nil, nil
            AP:Status("No full scan came back (the game allows one about every 15 minutes).")
            AP:UpdateTab()
        end
    end)
end

----------------------------------------------------------------------
-- The ProfessionBuddy tab at the end of the auction house's tabs
----------------------------------------------------------------------

AP.TAB_ID = "ProfessionBuddy"
-- The tab's label, and the short one when the auction house's tabs don't
-- fit (TEST-b2: with Auctionator's four tabs and TSM's, PB's ran past the
-- window's right edge)
AP.TAB_TEXT, AP.TAB_SHORT = "ProfessionBuddy", "PB"

-- Shown while neither Auctionator nor TSM is installed and switched on (P10)
function AP:ScansShown()
    local P = addon.Prices
    return P and P:Enabled() and not (P:UsesAuctionator() or P:UsesTSM()) or false
end

function AP:Status(text)
    self._status = text
    if self.panel then self.panel.status:SetText(text or "") end
end

-- The tab's page: what the two scans do, their buttons, and the status.
-- Blizzard's own button template, as the auction house's own buttons.
function AP:BuildPanel(parent)
    local f = CreateFrame("Frame", "ProfBuddyAuctionPanel", parent)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText("ProfessionBuddy prices")
    local about = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    about:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    about:SetJustifyH("LEFT")
    about:SetText("Scan my materials searches every material and crafted item of the recipes your characters know, one at a time. You can stop it.\n\n"
        .. "Full scan reads the whole auction house at once. The game can freeze for a few seconds, and it allows one about every 15 minutes.\n\n"
        .. "ProfessionBuddy also records the prices you see while you browse.")
    local scan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scan:SetSize(160, 22)
    scan:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
    scan:SetScript("OnClick", function()
        if AP._scan then AP:StopScan() else AP:StartTargeted() end
    end)
    local full = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    full:SetSize(120, 22)
    full:SetPoint("LEFT", scan, "RIGHT", 8, 0)
    full:SetText("Full scan")
    full:SetScript("OnClick", function() AP:AskFull() end)
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    status:SetPoint("TOPLEFT", scan, "BOTTOMLEFT", 0, -12)
    status:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    status:SetJustifyH("LEFT")
    f.scan, f.full, f.status = scan, full, status
    f:Hide()
    self.panel = f
    return f
end

-- WoW: Forever, the modern auction house: LibAHTab (MIT, by plusmouse, the
-- library Auctionator uses). Adding a tab with Blizzard's PanelTemplates
-- there taints the bags into combat (LibAHTab's README); and addons share
-- one copy, so PB's tab lines up after theirs.
function AP:BuildModernTab()
    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    if not (lib and AuctionHouseFrame) then return nil end
    local panel = self:BuildPanel(AuctionHouseFrame)
    panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 24, -70)
    panel:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -24, 40)
    if not lib:DoesIDExist(self.TAB_ID) then
        lib:CreateTab(self.TAB_ID, panel, self.TAB_TEXT, "ProfessionBuddy")
    end
    return lib:GetButton(self.TAB_ID)
end

-- TBC Anniversary, the classic auction house: one more AuctionFrameTabN,
-- as the game's own three tabs. Blizzard's AuctionFrameTab_OnClick hides
-- its three pages for any tab past the third; PB shows its page then.
function AP:BuildClassicTab()
    if not AuctionFrame then return nil end
    local index = (AuctionFrame.numTabs or 3) + 1
    local tab = CreateFrame("Button", "AuctionFrameTab" .. index, AuctionFrame, "AuctionTabTemplate")
    tab:SetID(index)
    tab:SetText(self.TAB_TEXT)
    tab:SetPoint("TOPLEFT", _G["AuctionFrameTab" .. (index - 1)], "TOPRIGHT", -8, 0)
    PanelTemplates_SetNumTabs(AuctionFrame, index)
    PanelTemplates_TabResize(tab, 0)
    PanelTemplates_EnableTab(AuctionFrame, index)
    local panel = self:BuildPanel(AuctionFrame)
    panel:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 90, -110)
    panel:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -40, 60)
    hooksecurefunc("AuctionFrameTab_OnClick", function(clicked)
        if clicked == tab then
            -- the Bids tab's plain frame art, as Blizzard sets per tab
            AuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopLeft")
            AuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top")
            AuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight")
            AuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft")
            AuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot")
            AuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight")
            panel:Show()
        else
            panel:Hide()
        end
    end)
    return tab
end

-- The auction house window the tab belongs to
function AP:Host()
    if self:Modern() then return AuctionHouseFrame end
    return AuctionFrame
end

-- The tab's label, sized as its own kind of tab sizes it (LibAHTab: 20
-- padding, 70 at least; the classic tabs: no padding)
function AP:SizeTab(short)
    local tab = self.tab
    tab:SetText(short and self.TAB_SHORT or self.TAB_TEXT)
    if self:Modern() then PanelTemplates_TabResize(tab, 20, nil, 70) else PanelTemplates_TabResize(tab, 0) end
    self._tabShort = short
end

-- Once the tabs are laid out: the short label when the full one runs past
-- the window's right edge; the full one again when it would fit. The full
-- label's width is kept from when it showed, so going back needs no try.
function AP:FitTab()
    local tab, host = self.tab, self:Host()
    if not (tab and host and tab:IsShown()) then return end
    local right, edge, width = tab:GetRight(), host:GetRight(), tab:GetWidth()
    if type(right) ~= "number" or type(edge) ~= "number" or type(width) ~= "number" then return end
    if not self._tabShort then
        self._fullWidth = width
        if right > edge then self:SizeTab(true) end
    elseif self._fullWidth and right - width + self._fullWidth <= edge then
        self:SizeTab(false)
    end
end

-- The short label names PB in a tooltip
function AP:TabTooltip(tab)
    if not self._tabShort then return end
    GameTooltip:SetOwner(tab, "ANCHOR_TOP")
    GameTooltip:SetText("ProfessionBuddy")
    GameTooltip:AddLine("Scan my materials and Full scan", 1, 1, 1)
    GameTooltip:Show()
    self._tabTip = true
end

function AP:UpdateTab()
    if not self._open then return end
    local shown = self:ScansShown()
    if not self.tab and shown then
        if self:Modern() then self.tab = self:BuildModernTab() else self.tab = self:BuildClassicTab() end
        if self.tab then
            self.tab:HookScript("OnEnter", function(t) AP:TabTooltip(t) end)
            self.tab:HookScript("OnLeave", function()
                -- only the tooltip PB showed
                if AP._tabTip then AP._tabTip = nil; GameTooltip:Hide() end
            end)
        end
    end
    if not self.tab then return end
    if shown then
        self.tab:Show()
        -- other addons add their tabs as the auction house opens: measure
        -- after this frame, and once more a moment later
        C_Timer.After(0, function() AP:FitTab() end)
        C_Timer.After(0.5, function() AP:FitTab() end)
    else
        -- the tab goes (Auctionator or TSM switched on in Settings); on the
        -- classic auction house its page goes back to Browse. The modern one
        -- is left on an empty page: clicking Blizzard's tab from PB's code
        -- would taint it (LibAHTab's README), so you pick a tab yourself.
        if self.panel and self.panel:IsShown() then
            self.panel:Hide()
            if not self:Modern() and AuctionFrameTab1 then AuctionFrameTab_OnClick(AuctionFrameTab1) end
        end
        self.tab:Hide()
    end
    local p = self.panel
    if not p then return end
    p.scan:SetText(self._scan and "Stop scan" or "Scan my materials")
    if self._full or self._scan then p.full:Disable() else p.full:Enable() end
    p.status:SetText(self._status or "")
end
