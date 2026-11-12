-- ProfessionBuddy  --  UI/CratesView.lua
-- The Shuffle tab's second view on WoW: Forever (2.2.0, Skeleton): every
-- Waylaid Supplies crate and Craftsman's Writ, what it asks for, how many
-- of that you and your alts hold, what the rest costs to buy ("To buy";
-- the crate's own tooltip keeps 2.1.0's whole "Fill cost"), who can
-- craft it, and a writ's own auction price, to plan which to fill.
-- Rewards (money, experience, reputation) have no Forever source yet, so
-- they come in a later update (WAYLAID-WRITS-PLANNING-scope.md). Data:
-- Data/Forever/Waylaid.lua and Writs.lua, Forever tocs only.

local addon = ProfBuddy
local CV = addon:NewModule("CratesView")
addon.CratesView = CV

local Theme = addon.Theme

local ROW_HEIGHT   = 20
local VISIBLE_ROWS = 14

local COLS = {
    { key = "name",  label = "Crate or writ", x = 6,   w = 168 },
    { key = "needs", label = "Needs",         x = 178, w = 132 },
    { key = "hold",  label = "You hold",      x = 314, w = 54  },
    { key = "cost",  label = "To buy",        x = 372, w = 64  },
    { key = "by",    label = "Crafted by",    x = 440, w = 70  },
    { key = "sells", label = "Writ sells",    x = 514, w = 52  },
}
local COL = {}
for _, c in ipairs(COLS) do COL[c.key] = c end

local TYPES = { "All", "Crates", "Writs" }
local NOT_CRAFTED = "Not crafted"
-- who can craft the requested item, nearest first (as the Shuffle tab)
local ORDER = { you = 1, alt = 2, friend = 3, guild = 4 }

local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local function ItemIcon(id)
    local f = GetItemIcon or (C_Item and C_Item.GetItemIconByID)
    return f and f(id) or nil
end

function CV:Init()
    self.typeFilter = "All"
    self.profFilter = nil        -- nil = every profession
    self.bagsOnly = false
    self.readyOnly = false
    self.sortKey = "cost"
end

-- Only where the crate and writ data loads (WoW: Forever)
function CV:Available()
    return (addon.Waylaid ~= nil) or (addon.Writs ~= nil)
end

----------------------------------------------------------------------
-- The numbers
----------------------------------------------------------------------

-- How many of `itemID` you and your alts hold, bags and bank (the Held by
-- data; friends' bags don't count: you can only mail to yourself)
function CV:HeldByYou(itemID)
    local DS = addon.DataStore
    local total = 0
    for key, c in pairs(DS and DS:GetAllCharacters() or {}) do
        local mine = addon:SameKey(key, addon:PlayerKey())
        if mine or (not c.isRemote and addon:ShowsFaction(c, key)) then
            local inv = c.inventory
            local bags = inv and inv.bags or {}
            local bank = inv and inv.bank or {}
            total = total + (tonumber(bags[itemID]) or 0) + (tonumber(bank[itemID]) or 0)
        end
    end
    return total
end

-- The nearest person who can craft `itemID` ({ key, rel, prof, recipe }),
-- or nil, and the profession that makes it (nil when nothing does)
function CV:CraftedBy(itemID)
    local RDB, DS, SP = addon.RecipeDB, addon.DataStore, addon.ShufflePanel
    local refs = RDB and RDB:GetRecipesForItem(itemID) or {}
    local best
    for _, ref in ipairs(refs) do
        for key, c in pairs(DS and DS:GetAllCharacters() or {}) do
            local rel = SP and SP:Relation(key, c)
            local p = c.professions and c.professions[ref.profName]
            if rel and p and p.recipes and p.recipes[ref.recipeName]
               and (rel == "you" or addon:ShowsFaction(c, key))
               and (rel == "you" or not addon.CLASS_PROFS[ref.profName]) then
                if not best or ORDER[rel] < ORDER[best.rel]
                   or (ORDER[rel] == ORDER[best.rel] and key < best.key) then
                    best = { key = key, rel = rel, prof = ref.profName, recipe = ref.recipeName }
                end
            end
        end
    end
    return best, refs[1] and refs[1].profName or nil
end

-- One row per crate and writ
function CV:Build()
    local P = addon.Prices
    self.all = {}
    self.loading = false
    if not (P and P:Enabled()) then return end
    local function add(id, need, kind)
        local item, count = need[1], need[2]
        local name = GetItemInfo(id)
        if not name then
            self.loading = true
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            name = (kind == "writ" and "Craftsman's Writ: " or "Waylaid Supplies: ") .. (need[4] or ("item:" .. item))
        end
        local held = self:HeldByYou(item)
        local mp = P:MaterialPrice(item)
        local rest = math.max(0, count - held)
        local cost
        if rest == 0 then cost = 0
        elseif mp and mp.unit then cost = mp.unit * rest end
        local by, prof = self:CraftedBy(item)
        self.all[#self.all + 1] = {
            id = id, kind = kind, item = item, count = count, name = name,
            itemName = GetItemInfo(item) or need[4] or ("item:" .. item),
            held = held, ready = held >= count, cost = cost, partial = mp and mp.partial,
            by = by, prof = prof or NOT_CRAFTED,
            sells = kind == "writ" and P:AuctionPrice(id) or nil,
            inBags = self:HeldByYou(id) > 0,
        }
    end
    for id, need in pairs(addon.Waylaid or {}) do add(id, need, "crate") end
    for id, need in pairs(addon.Writs or {}) do add(id, need, "writ") end
end

-- The rows that pass the filters, sorted: To buy (cheapest first, no
-- price last), or ready to fill first
function CV:Filter()
    local list = {}
    for _, e in ipairs(self.all or {}) do
        if (self.typeFilter == "All" or (self.typeFilter == "Crates") == (e.kind == "crate"))
           and (not self.profFilter or e.prof == self.profFilter)
           and (not self.bagsOnly or e.inBags)
           and (not self.readyOnly or e.ready) then
            list[#list + 1] = e
        end
    end
    local readyFirst = self.sortKey == "ready"
    table.sort(list, function(a, b)
        if readyFirst and a.ready ~= b.ready then return a.ready end
        if (a.cost == nil) ~= (b.cost == nil) then return b.cost == nil end
        if a.cost and b.cost and a.cost ~= b.cost then return a.cost < b.cost end
        return a.name < b.name
    end)
    self.list = list
end

----------------------------------------------------------------------
-- Layout: built on the Shuffle tab's content frame, shown in place of the
-- shuffle list (SP:SetView)
----------------------------------------------------------------------
function CV:CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", COL.name.x, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local function cell(col, justify, x)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", x or col.x, 0)
        fs:SetWidth(col.w - ((x or col.x) - col.x))
        fs:SetJustifyH(justify or "LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    row.nameText  = cell(COL.name, "LEFT", COL.name.x + 20)
    row.needsText = cell(COL.needs)
    row.holdText  = cell(COL.hold, "RIGHT")
    row.costText  = cell(COL.cost, "RIGHT")
    row.byText    = cell(COL.by, "LEFT", COL.by.x + 6)
    row.sellsText = cell(COL.sells, "RIGHT")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Theme:Fill(hl, "guildRowHover")

    -- a click opens the requested item's recipe, when someone can craft it
    row:SetScript("OnClick", function(r)
        local e = r._entry
        local tsf = addon.TradeSkillFrame
        if e and e.by and tsf and tsf.OpenRecipeFor then
            tsf:OpenRecipeFor(e.by.key, e.by.prof, e.by.recipe, false)
        end
    end)
    row:SetScript("OnEnter", function(r)
        local e = r._entry
        if not e then return end
        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(e.id)   -- the crate's or writ's own tooltip, with its fill cost
        GameTooltip:AddLine(" ")
        -- what's left to buy after what you hold: the column; the crate's
        -- own Fill cost above is the whole fill (TEST-b review)
        local P = addon.Prices
        local toBuy = e.cost and (P:Money(e.cost) .. (e.partial and e.cost > 0 and "+" or "")) or "|cffff4444?|r"
        GameTooltip:AddDoubleLine("To buy:", toBuy, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine("You and your alts hold " .. e.held .. " of " .. e.count .. " " .. e.itemName .. ".",
            0.8, 0.8, 0.8, true)
        if e.by then
            GameTooltip:AddLine("Click to open " .. e.by.recipe .. " (" .. addon:ShortName(e.by.key) .. ").", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

function CV:Create(parent)
    if self.frame then return end
    local CreateDropdown = addon.CreateDropdown
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 0, -26)
    f:SetPoint("BOTTOMRIGHT", 0, 0)
    f:Hide()
    self.frame = f

    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetPoint("TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", 0, 0)
    filterBar:SetHeight(22)
    self.filterBar = filterBar

    if CreateDropdown then
        local typeDD = CreateDropdown(filterBar, 120, TYPES, self.typeFilter, function(val)
            self.typeFilter = val
            self:Repaint()
        end, "Type: ")
        typeDD:SetPoint("LEFT", 4, 0)
        self.typeDD = typeDD

        local profDD = CreateDropdown(filterBar, 150, { "All" }, "All", function(val)
            if val == "All" then self.profFilter = nil else self.profFilter = val end
            self:Repaint()
        end, "Prof: ")
        profDD:SetPoint("LEFT", typeDD, "RIGHT", 6, 0)
        self.profDD = profDD
    end

    local function check(label, tip, anchor, onClick)
        local cb = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", anchor or filterBar, anchor and "RIGHT" or "LEFT", anchor and 8 or 4, 0)
        cb:SetScript("OnClick", function(b) onClick(b:GetChecked() and true or false); self:Repaint() end)
        cb:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local fs = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        fs:SetText(label)
        cb.label = fs
        return cb
    end
    self.bagsCheck = check("You hold one", "Only the crates and writs you or your alts hold, in bags or bank.",
        self.profDD, function(v) self.bagsOnly = v end)
    self.readyCheck = check("Ready to fill", "Only the ones you and your alts hold enough for.",
        self.bagsCheck.label, function(v) self.readyOnly = v end)

    -- Column headers: To buy and You hold (ready first) sort
    local headerBar = CreateFrame("Frame", nil, f)
    headerBar:SetPoint("TOPLEFT", 0, -26)
    headerBar:SetPoint("TOPRIGHT", 0, -26)
    headerBar:SetHeight(18)
    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    Theme:Fill(headerBg, "columnHeader")
    self.headerBtns = {}
    for _, c in ipairs(COLS) do
        local btn = CreateFrame("Button", nil, headerBar)
        btn:SetPoint("LEFT", c.x, 0)
        btn:SetSize(c.w, 18)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        local right = c.key == "hold" or c.key == "cost" or c.key == "sells"
        fs:SetJustifyH(right and "RIGHT" or "LEFT")
        btn.label = fs
        btn.colLabel = c.label
        local sortKey = (c.key == "cost" and "cost") or (c.key == "hold" and "ready") or nil
        if sortKey then
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            Theme:Fill(hl, "columnHeaderHover")
            btn:SetScript("OnClick", function()
                self.sortKey = sortKey
                self:Repaint()
            end)
            btn.sortKey = sortKey
        end
        self.headerBtns[c.key] = btn
    end

    local listFrame = CreateFrame("Frame", nil, f)
    listFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
    listFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 18)
    self.listFrame = listFrame

    self.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = self:CreateRow(listFrame)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -16, 0)
        row:SetHeight(ROW_HEIGHT)
        self.rows[i] = row
    end

    local scrollBar = CreateFrame("Slider", "ProfBuddyCratesScroll", listFrame)
    scrollBar:SetPoint("TOPRIGHT", 0, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollBar:SetWidth(16)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetObeyStepOnDrag(true)
    local thumbTex = scrollBar:CreateTexture(nil, "ARTWORK")
    thumbTex:SetSize(16, 24)
    thumbTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    scrollBar:SetThumbTexture(thumbTex)
    local bgTex = scrollBar:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    Theme:Fill(bgTex, "listBackground")
    scrollBar:SetScript("OnValueChanged", function(_, value)
        self.scrollOffset = math.floor(value)
        self:UpdateRows()
    end)
    self.scrollBar = scrollBar
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(scrollBar:GetValue() - delta)
    end)

    self.empty = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOPLEFT", 6, -8)
    self.empty:SetPoint("RIGHT", -22, 0)
    self.empty:SetJustifyH("LEFT")
    self.empty:Hide()

    local rewards = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rewards:SetPoint("BOTTOMLEFT", 6, 2)
    rewards:SetText("Reward details (money, experience, reputation) come in a later update.")
    self.rewardsLine = rewards

    self.scrollOffset = 0
end

function CV:Show() if self.frame then self.frame:Show(); self:Refresh() end end
function CV:Hide() if self.frame then self.frame:Hide() end end

-- Work the list out again (on show, and after an item loads)
function CV:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    self:Build()
    self:SyncProfDropdown()
    self:Repaint()
    if self.loading then
        self._tries = (self._tries or 0) + 1
        if self._tries <= 3 then
            C_Timer.After(1, function()
                if CV.frame and CV.frame:IsVisible() then CV:Refresh() end
            end)
        end
    else
        self._tries = 0
    end
end

function CV:SyncProfDropdown()
    if not self.profDD then return end
    local seen, opts = {}, { "All" }
    for _, e in ipairs(self.all or {}) do
        if not seen[e.prof] then seen[e.prof] = true; opts[#opts + 1] = e.prof end
    end
    table.sort(opts, function(a, b)
        if a == "All" then return true elseif b == "All" then return false end
        if a == NOT_CRAFTED then return false elseif b == NOT_CRAFTED then return true end
        return a < b
    end)
    if self.profFilter and not seen[self.profFilter] then self.profFilter = nil end
    self.profDD:SetOptions(opts)
    self.profDD:SetValue(self.profFilter or "All")
end

function CV:Repaint()
    if not self.frame then return end
    self:Filter()
    for _, btn in pairs(self.headerBtns or {}) do
        local mark = (btn.sortKey and btn.sortKey == self.sortKey) and " v" or ""
        btn.label:SetText(btn.colLabel .. mark)
    end
    local P = addon.Prices
    local maxScroll = math.max(0, #self.list - VISIBLE_ROWS)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if (self.scrollOffset or 0) > maxScroll then self.scrollOffset = maxScroll end
    self.scrollBar:SetValue(self.scrollOffset or 0)
    if not (P and P:Enabled()) then
        self.empty:SetText("Prices are off. Select Show prices in Settings, under Prices, to see what filling each costs.")
        self.empty:Show()
    elseif #self.list == 0 then
        self.empty:SetText("No crate or writ matches these filters.")
        self.empty:Show()
    else
        self.empty:Hide()
    end
    self:UpdateRows()
end

function CV:UpdateRows()
    local P = addon.Prices
    for i, row in ipairs(self.rows or {}) do
        local e = self.list and self.list[i + (self.scrollOffset or 0)]
        row._entry = e
        if e and P then
            row.icon:SetTexture(ItemIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(e.name)
            row.needsText:SetText(e.count .. " x " .. e.itemName)
            local hold = e.held .. "/" .. e.count
            row.holdText:SetText(e.ready and ("|cff00ff00" .. hold .. "|r") or hold)
            if e.cost then
                row.costText:SetText(P:Money(e.cost, true) .. (e.partial and e.cost > 0 and "+" or ""))
            else
                row.costText:SetText("|cffff4444?|r")
            end
            row.byText:SetText(e.by and addon:ShortName(e.by.key) or "|cff808080-|r")
            row.sellsText:SetText(e.sells and P:Money(e.sells, true) or "")
            row:Show()
        else
            row:Hide()
        end
    end
end
