-- ProfessionBuddy  --  UI/ShufflePanel.lua
-- The Shuffle tab (2.2.0, Skeleton): crafts a vendor pays more for than
-- their materials cost, best first, for your characters, your friends and
-- your guildmates. Prices.lua works out each one (P:VendorShuffle): cost
-- as everywhere else, the vendor's price for the craft's yield, and profit
-- per hour from the cast time plus a gap between casts.

local addon = ProfBuddy
local SP = addon:NewModule("ShufflePanel")
addon.ShufflePanel = SP

local Theme = addon.Theme

local ROW_HEIGHT   = 20
local VISIBLE_ROWS = 15

local COLS = {
    { key = "recipe", label = "Recipe",      x = 6,   w = 172 },
    { key = "who",    label = "Who",         x = 182, w = 86  },
    { key = "cost",   label = "Cost",        x = 272, w = 68  },
    { key = "sell",   label = "Vendor pays", x = 344, w = 68  },
    { key = "profit", label = "Profit",      x = 416, w = 68  },
    { key = "hour",   label = "Per hour",    x = 488, w = 74  },
}
local COL = {}
for _, c in ipairs(COLS) do COL[c.key] = c end

-- Who knows a recipe, nearest first
local WHO_ORDER = { you = 1, alt = 2, friend = 3, guild = 4 }
local WHO_FILTERS = { "Everyone", "You and alts", "Friends", "Guild" }
local WHO_ALLOWS = {
    ["Everyone"]     = { you = true, alt = true, friend = true, guild = true },
    ["You and alts"] = { you = true, alt = true },
    ["Friends"]      = { friend = true },
    ["Guild"]        = { guild = true },
}

-- "1s" style label for a minimum in copper (Prices.lua)
local function MinLabel(copper)
    local P = addon.Prices
    return P and P:ShuffleMinLabel(copper) or tostring(copper)
end

function SP:Init()
    self.whoFilter = "Everyone"
    self.profFilter = nil        -- nil = every profession
    self.vendorOnly = false
    self.sortKey = "profit"
    if addon.UI and addon.UI.AddTab then
        addon.UI:AddTab("shuffle", "Shuffle", function(parent)
            self:CreateContent(parent)
        end)
    end
end

-- The profession window's Shuffle bottom tab: the main window on this tab,
-- with the profession kept open behind it, as the other bottom tabs do
function SP:Toggle()
    if not addon.UI then return end
    local tsf = addon.TradeSkillFrame
    if tsf and tsf.frame and tsf.frame:IsShown() then
        -- in combat the game blocks hiding it: when combat ends (TEST-c6)
        if tsf:WaitForCombat("Shuffle opens", function() SP:Toggle() end) then return end
        tsf:HideForMain()
    end
    if not addon.UI.frame:IsShown() then
        addon.UI:Show()
    end
    for i, tab in ipairs(addon.UI.frame.tabs) do
        if tab.name == "shuffle" then
            addon.UI:SelectTab(i)
            break
        end
    end
end

-- How `key` relates to you: "you", "alt", "friend", "guild", or nil for a
-- character PB keeps data for that is neither (a past group member)
function SP:Relation(key, charData)
    if addon:SameKey(key, addon:PlayerKey()) then return "you" end
    if not charData.isRemote then return "alt" end
    if addon.db.contacts and addon.db.contacts[key] then return "friend" end
    local C = addon.Comm
    if C and C.IsGuildMember and C:IsGuildMember(key) then return "guild" end
    return nil
end

----------------------------------------------------------------------
-- The list: one row per recipe that a vendor pays a profit for, naming
-- the nearest person who knows it (you, an alt, a friend, a guildmate)
----------------------------------------------------------------------
function SP:Build()
    local P, DS = addon.Prices, addon.DataStore
    self.all = {}
    self.loading = false
    if not (P and P:Enabled() and DS) then return end
    P._unloaded = nil
    local byRecipe = {}
    for key, charData in pairs(DS:GetAllCharacters() or {}) do
        local rel = self:Relation(key, charData)
        if rel and charData.professions
           and (rel == "you" or addon:ShowsFaction(charData, key)) then
            for profName, prof in pairs(charData.professions) do
                if prof.recipes and (rel == "you" or not addon.CLASS_PROFS[profName]) then
                    for name in pairs(prof.recipes) do
                        local id = profName .. "|" .. name
                        local e = byRecipe[id]
                        if not e then
                            e = { name = name, prof = profName, who = {} }
                            byRecipe[id] = e
                        end
                        e.who[#e.who + 1] = { key = key, rel = rel }
                    end
                end
            end
        end
    end
    for _, e in pairs(byRecipe) do
        local v = P:VendorShuffle({ name = e.name }, e.prof)
        if v and v.loading then
            self.loading = true
        elseif v then
            table.sort(e.who, function(a, b)
                if WHO_ORDER[a.rel] ~= WHO_ORDER[b.rel] then return WHO_ORDER[a.rel] < WHO_ORDER[b.rel] end
                return a.key < b.key
            end)
            e.v = v
            self.all[#self.all + 1] = e
        end
    end
    if P._unloaded then self.loading = true end
end

-- The rows that pass the filters, sorted
function SP:Filter()
    local P = addon.Prices
    local min = P and P:ShuffleMin() or 0
    local allow = WHO_ALLOWS[self.whoFilter] or WHO_ALLOWS["Everyone"]
    local list = {}
    for _, e in ipairs(self.all or {}) do
        local whoOK = false
        for _, w in ipairs(e.who) do
            if allow[w.rel] then whoOK = true; break end
        end
        if whoOK and e.v.profit >= min
           and (not self.profFilter or e.prof == self.profFilter)
           and (not self.vendorOnly or e.v.fromVendors) then
            list[#list + 1] = e
        end
    end
    local byHour = self.sortKey == "hour"
    table.sort(list, function(a, b)
        local x, y = a.v.profit, b.v.profit
        if byHour then x, y = a.v.perHour, b.v.perHour end
        if x ~= y then return x > y end
        return a.name < b.name
    end)
    self.list = list
end

-- The first person in `e` the Who filter allows: who a click opens
function SP:Shown(e)
    local allow = WHO_ALLOWS[self.whoFilter] or WHO_ALLOWS["Everyone"]
    for _, w in ipairs(e.who) do
        if allow[w.rel] then return w end
    end
    return e.who[1]
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
function SP:CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp")

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", COL.recipe.x, 0)
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
    row.nameText   = cell(COL.recipe, "LEFT", COL.recipe.x + 20)
    row.whoText    = cell(COL.who)
    row.costText   = cell(COL.cost, "RIGHT")
    row.sellText   = cell(COL.sell, "RIGHT")
    row.profitText = cell(COL.profit, "RIGHT")
    row.hourText   = cell(COL.hour, "RIGHT")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Theme:Fill(hl, "guildRowHover")

    row:SetScript("OnClick", function(r)
        local e = r._entry
        if not e then return end
        local w = SP:Shown(e)
        if w and addon.TradeSkillFrame and addon.TradeSkillFrame.OpenRecipeFor then
            addon.TradeSkillFrame:OpenRecipeFor(w.key, e.prof, e.name)
        end
    end)
    row:SetScript("OnEnter", function(r) SP:ShowRowTip(r) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

-- A row's tooltip: each material's price and where it came from, the
-- sale, the time per craft, and who knows the recipe
function SP:ShowRowTip(row)
    local e = row._entry
    local P = addon.Prices
    if not (e and P) then return end
    local v = e.v
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.name, 1, 1, 1)
    GameTooltip:AddLine(e.prof, 0.7, 0.7, 0.7)
    for _, part in ipairs(v.parts or {}) do
        local mp = part.price or {}
        GameTooltip:AddDoubleLine("  " .. (part.count or 1) .. " x " .. (part.name or "?"),
            P:MaterialText(mp, part.count or 1), 0.9, 0.9, 0.9, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Cost", P:Money(v.cost), 1, 0.82, 0, 1, 1, 1)
    -- the count per craft as the detail panel words it (2.1.1): "(makes 4)",
    -- or for a random amount "(makes 1-3, priced as 2)"
    local sellLabel = "Vendor pays"
    if v.yieldMin then
        sellLabel = sellLabel .. " (makes " .. v.yieldMin .. "-" .. v.yieldMax .. ", priced as " .. v.yield .. ")"
    elseif (v.yield or 1) > 1 then
        sellLabel = sellLabel .. " (makes " .. v.yield .. ")"
    end
    GameTooltip:AddDoubleLine(sellLabel, P:Money(v.sell), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Profit", P:SignedMoney(v.profit), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Per hour, about", P:Money(v.perHour, true), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(string.format("About %.1f s a craft: the cast time plus %.1f s between casts.",
        v.seconds, P.SHUFFLE_GAP), 0.6, 0.6, 0.6, true)
    if v.fromVendors then
        GameTooltip:AddLine("Every material comes from a vendor.", 0.6, 0.6, 0.6, true)
    end
    local names = {}
    for _, w in ipairs(e.who) do names[#names + 1] = addon:ShortName(w.key) end
    GameTooltip:AddLine("Known by: " .. table.concat(names, ", "), 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Click to open it.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

function SP:CreateContent(parent)
    self.parent = parent
    local CreateDropdown = addon.CreateDropdown

    self.header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.header:SetPoint("TOPLEFT", 6, -6)
    self.header:SetText("Vendor shuffle")

    local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("LEFT", self.header, "RIGHT", 10, 0)
    sub:SetText("Crafts a vendor pays more for than their materials cost.")
    self.sub = sub

    -- WoW: Forever: a second view, Crates and writs (UI/CratesView.lua),
    -- switched by two buttons in place of the heading
    local CV = addon.CratesView
    if CV and CV:Available() then
        self.header:Hide()
        local function viewBtn(label, w, view)
            local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            b:SetSize(w, 20)
            b:SetText(label)
            b:SetNormalFontObject(GameFontNormalSmall)
            b:SetHighlightFontObject(GameFontHighlightSmall)
            b:SetScript("OnClick", function() self:SetView(view) end)
            return b
        end
        local shuffleBtn = viewBtn("Vendor shuffle", 104, "shuffle")
        shuffleBtn:SetPoint("TOPLEFT", 4, -2)
        local cratesBtn = viewBtn("Crates and writs", 116, "crates")
        cratesBtn:SetPoint("LEFT", shuffleBtn, "RIGHT", 4, 0)
        self.viewBtns = { shuffle = shuffleBtn, crates = cratesBtn }
        sub:ClearAllPoints()
        sub:SetPoint("LEFT", cratesBtn, "RIGHT", 10, 0)
        sub:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        CV:Create(parent)
    end

    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetPoint("TOPLEFT", 0, -26)
    filterBar:SetPoint("TOPRIGHT", 0, -26)
    filterBar:SetHeight(22)
    self.filterBar = filterBar

    if CreateDropdown then
        local whoDD = CreateDropdown(filterBar, 140, WHO_FILTERS, self.whoFilter, function(val)
            self.whoFilter = val
            self:Repaint()
        end, "Who: ")
        whoDD:SetPoint("LEFT", 4, 0)
        self.whoDD = whoDD

        local profDD = CreateDropdown(filterBar, 150, { "All" }, "All", function(val)
            -- not `(val == "All") and nil or val`: that always gives val, so
            -- "All" filtered on a profession named "All" and emptied the
            -- list (TEST-a3, m4ru)
            if val == "All" then self.profFilter = nil else self.profFilter = val end
            self:Repaint()
        end, "Prof: ")
        profDD:SetPoint("LEFT", whoDD, "RIGHT", 6, 0)
        self.profDD = profDD

        local P = addon.Prices
        local minOpts = {}
        for i, c in ipairs(P and P.SHUFFLE_MINS or { 0 }) do minOpts[i] = MinLabel(c) end
        local minDD = CreateDropdown(filterBar, 110, minOpts, MinLabel(P and P:ShuffleMin() or 0), function(val)
            for _, c in ipairs(P.SHUFFLE_MINS) do
                if MinLabel(c) == val then addon.db.settings.shuffleMinProfit = c end
            end
            if addon.TradeSkillFrame and addon.TradeSkillFrame.SyncShuffleMin then
                addon.TradeSkillFrame:SyncShuffleMin()
            end
            self:Repaint()
        end, "Min: ")
        minDD:SetPoint("LEFT", profDD, "RIGHT", 6, 0)
        minDD:HookScript("OnEnter", function(dd)
            GameTooltip:SetOwner(dd, "ANCHOR_TOP")
            GameTooltip:SetText("Minimum profit per craft")
            GameTooltip:AddLine("Also in Settings, under Prices.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        minDD:HookScript("OnLeave", function() GameTooltip:Hide() end)
        self.minDD = minDD
    end

    local vendorCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    vendorCheck:SetSize(20, 20)
    vendorCheck:SetPoint("LEFT", self.minDD or filterBar, self.minDD and "RIGHT" or "LEFT", 8, 0)
    vendorCheck:SetScript("OnClick", function(cb)
        self.vendorOnly = cb:GetChecked() and true or false
        self:Repaint()
    end)
    vendorCheck:SetScript("OnEnter", function(cb)
        GameTooltip:SetOwner(cb, "ANCHOR_TOP")
        GameTooltip:SetText("Vendor materials only")
        GameTooltip:AddLine("Only crafts whose every material is bought from a vendor, so no auction price can move.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    vendorCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local vendorLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    vendorLabel:SetPoint("LEFT", vendorCheck, "RIGHT", 2, 0)
    vendorLabel:SetText("Vendor materials")
    self.vendorCheck = vendorCheck

    -- Column headers: Profit and Per hour sort
    local headerBar = CreateFrame("Frame", nil, parent)
    headerBar:SetPoint("TOPLEFT", 0, -52)
    headerBar:SetPoint("TOPRIGHT", 0, -52)
    headerBar:SetHeight(18)
    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    Theme:Fill(headerBg, "columnHeader")
    self.headerBar = headerBar
    self.headerBtns = {}
    for _, c in ipairs(COLS) do
        local btn = CreateFrame("Button", nil, headerBar)
        btn:SetPoint("LEFT", c.x, 0)
        btn:SetSize(c.w, 18)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetJustifyH((c.key == "recipe" or c.key == "who") and "LEFT" or "RIGHT")
        btn.label = fs
        btn.colLabel = c.label
        if c.key == "profit" or c.key == "hour" then
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            Theme:Fill(hl, "columnHeaderHover")
            btn:SetScript("OnClick", function()
                self.sortKey = c.key
                self:Repaint()
            end)
        end
        if c.key == "hour" then
            btn:SetScript("OnEnter", function(b)
                GameTooltip:SetOwner(b, "ANCHOR_TOP")
                GameTooltip:SetText("Per hour, about")
                GameTooltip:AddLine("Profit over each craft's cast time plus "
                    .. string.format("%.1f", addon.Prices and addon.Prices.SHUFFLE_GAP or 0.5)
                    .. " s between casts. Buying and selling time not counted.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        self.headerBtns[c.key] = btn
    end

    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
    listFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.listFrame = listFrame

    self.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = self:CreateRow(listFrame)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -16, 0)
        row:SetHeight(ROW_HEIGHT)
        self.rows[i] = row
    end

    local scrollBar = CreateFrame("Slider", "ProfBuddyShuffleScroll", listFrame)
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

    self.scrollOffset = 0
    parent.Refresh = function() self:Refresh() end
    self:SetView(self.view or "shuffle")
end

-- The Shuffle tab's view: "shuffle" (this file) or "crates" (Crates and
-- writs, WoW: Forever only). The choice stays while PB runs.
function SP:SetView(view)
    local CV = addon.CratesView
    if view ~= "crates" or not (CV and CV.frame) then view = "shuffle" end
    self.view = view
    local shuffle = view == "shuffle"
    for _, w in ipairs({ self.filterBar, self.headerBar, self.listFrame }) do
        if shuffle then w:Show() else w:Hide() end
    end
    if self.viewBtns then
        for v, b in pairs(self.viewBtns) do
            if v == view then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    if self.sub then
        self.sub:SetText(shuffle and "Crafts a vendor pays more for than their materials cost."
            or "What filling each costs, from what you and your alts hold.")
    end
    if shuffle then
        if CV then CV:Hide() end
        self:Refresh()
    else
        CV:Show()
    end
end

-- Work the list out again (on show, and after a product loads)
function SP:Refresh()
    if not self.parent then return end
    if self.view == "crates" and addon.CratesView then return addon.CratesView:Refresh() end
    self:Build()
    self:SyncProfDropdown()
    self:Repaint()
    -- a product the game hadn't loaded: look again, up to 3 times
    if self.loading then
        self._tries = (self._tries or 0) + 1
        if self._tries <= 3 then
            C_Timer.After(1, function()
                if SP.parent and SP.parent:IsVisible() then SP:Refresh() end
            end)
        end
    else
        self._tries = 0
    end
end

function SP:SyncProfDropdown()
    if not self.profDD then return end
    local seen, opts = {}, { "All" }
    for _, e in ipairs(self.all or {}) do
        if not seen[e.prof] then seen[e.prof] = true; opts[#opts + 1] = e.prof end
    end
    table.sort(opts, function(a, b)
        if a == "All" then return true elseif b == "All" then return false end
        return a < b
    end)
    if self.profFilter and not seen[self.profFilter] then self.profFilter = nil end
    self.profDD:SetOptions(opts)
    self.profDD:SetValue(self.profFilter or "All")
end

-- Filters, sort, headers and rows from the list worked out last
function SP:Repaint()
    if not self.parent then return end
    self:Filter()
    for key, btn in pairs(self.headerBtns or {}) do
        local mark = (key == self.sortKey) and " v" or ""
        btn.label:SetText(btn.colLabel .. mark)
    end
    if self.minDD and addon.Prices then self.minDD:SetValue(MinLabel(addon.Prices:ShuffleMin())) end
    local P = addon.Prices
    local maxScroll = math.max(0, #self.list - VISIBLE_ROWS)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if (self.scrollOffset or 0) > maxScroll then self.scrollOffset = maxScroll end
    self.scrollBar:SetValue(self.scrollOffset or 0)
    if not (P and P:Enabled()) then
        self.empty:SetText("Prices are off. Select Show prices in Settings, under Prices, to see which crafts a vendor pays a profit for.")
        self.empty:Show()
    elseif #self.list == 0 then
        local min = P:ShuffleMin()
        local none = (min == 0) and "No craft here earns a profit from a vendor."
            or ("No craft here earns at least " .. MinLabel(min) .. " from a vendor. Lower the minimum, or change Who or Prof.")
        self.empty:SetText(self.loading and "Loading item data..." or none)
        self.empty:Show()
    else
        self.empty:Hide()
    end
    self:UpdateRows()
end

function SP:UpdateRows()
    local P = addon.Prices
    for i, row in ipairs(self.rows or {}) do
        local e = self.list and self.list[i + (self.scrollOffset or 0)]
        row._entry = e
        if e and P then
            local w = self:Shown(e)
            local icon = e.v.itemID and (GetItemIcon or (C_Item and C_Item.GetItemIconByID))
            row.icon:SetTexture(icon and icon(e.v.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(e.name)
            local who = w and addon:ShortName(w.key) or "?"
            if #e.who > 1 then who = who .. " +" .. (#e.who - 1) end
            row.whoText:SetText(who)
            row.costText:SetText(P:Money(e.v.cost, true))
            row.sellText:SetText(P:Money(e.v.sell, true))
            row.profitText:SetText(P:SignedMoney(e.v.profit, true))
            row.hourText:SetText(P:Money(e.v.perHour, true))
            row:Show()
        else
            row:Hide()
        end
    end
end
