----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/OrdersPanel.lua
-- Crafting orders queue: a tab on the /pb main window showing two
-- stacked sections, Incoming (requests to you) and Outgoing (your
-- orders), with role/state-appropriate action buttons per row.
--
-- The active queue and the History panel share one list component
-- (a "list context"): same row pool, scrollbar, and rendering, fed by
-- different data. Active queue = non-terminal orders. History panel =
-- terminal orders (completed/declined/cancelled) with Dismiss.
----------------------------------------------------------------------

local addon = ProfBuddy
local OP = addon:NewModule("OrdersPanel")

local ROW_HEIGHT = 36

----------------------------------------------------------------------
-- Display tables
----------------------------------------------------------------------
local PROF_ICONS = {
    ["Alchemy"]        = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"]  = "Interface\\Icons\\Trade_BlackSmithing",
    ["Cooking"]        = "Interface\\Icons\\INV_Misc_Food_15",
    ["Enchanting"]     = "Interface\\Icons\\Trade_Engraving",
    ["Engineering"]    = "Interface\\Icons\\Trade_Engineering",
    ["First Aid"]      = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Jewelcrafting"]  = "Interface\\Icons\\INV_Misc_Gem_02",
    ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
    ["Smelting"]       = "Interface\\Icons\\Spell_Fire_FlameBlades",
    ["Tailoring"]      = "Interface\\Icons\\Trade_Tailoring",
}

local STATUS_DISPLAY = {
    pending   = { text = "Pending",   r = 1.0, g = 0.82, b = 0.0 },
    accepted  = { text = "Accepted",  r = 0.4, g = 0.7,  b = 1.0 },
    crafted   = { text = "Crafted",   r = 0.3, g = 0.9,  b = 0.4 },
    completed = { text = "Completed", r = 0.5, g = 0.85, b = 0.5 },
    declined  = { text = "Declined",  r = 0.9, g = 0.4,  b = 0.4 },
    cancelled = { text = "Cancelled", r = 0.7, g = 0.5,  b = 0.4 },
}

local MATRESP_LABEL = {
    requester = "Order provides mats",
    crafter   = "Crafter provides mats",
    split     = "Split",
}

-- Compact form for the row's secondary line (full form is in the tooltip)
local MATRESP_SHORT = {
    requester = "Mats: order",
    crafter   = "Mats: crafter",
    split     = "Mats: split",
}

local ACTION_LABEL = {
    accept          = "Accept",
    decline         = "Decline",
    markCrafted     = "Crafted",
    markDelivered   = "Delivered",
    cancel          = "Cancel",
    confirmReceived = "Received",
    dismiss         = "Dismiss",
}

----------------------------------------------------------------------
-- Confirm dialog for the crafter escape hatch
----------------------------------------------------------------------
StaticPopupDialogs["PROFBUDDY_MARK_DELIVERED"] = {
    text = "Mark this order as delivered? This closes it.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, orderID)
        if addon.Orders then
            local order = addon.Orders:MarkDelivered(orderID)
            if order and addon.Comm then addon.Comm:SendOrderUpdate(order) end
        end
        OP:RefreshAll()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Confirm clearing one History section (Incoming / Outgoing)
StaticPopupDialogs["PROFBUDDY_CLEAR_HISTORY"] = {
    text = "Clear all completed %s orders from history?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, side)
        if addon.Orders and side then
            addon.Orders:DismissHistorySide(side)
        end
        OP:RefreshAll()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------------------------------
-- Init: register as a tab
----------------------------------------------------------------------
function OP:Init()
    if addon.UI and addon.UI.AddTab then
        addon.UI:AddTab("orders", "Orders", function(parent)
            self:CreateContent(parent)
        end)

        -- Close the History panel when navigating away from the Orders
        -- tab (it's contextual to this tab, like the Material Calc is to
        -- the profession window).
        if not self._tabHookInstalled then
            self._tabHookInstalled = true
            hooksecurefunc(addon.UI, "SelectTab", function(_, index)
                local tab = addon.UI.frame.tabs[index]
                if tab and tab.name ~= "orders"
                   and OP.histFrame and OP.histFrame:IsShown() then
                    OP.histFrame:Hide()
                end
            end)
        end

        -- Count badge on the Orders tab button
        for _, tab in ipairs(addon.UI.frame.tabs) do
            if tab.name == "orders" and tab.button and not tab.button._pbBadge then
                tab.button._pbBadge = self:CreateBadge(tab.button)
            end
        end
    end

    -- One login summary per session; also refresh the badge then
    if not self._loginRegistered then
        self._loginRegistered = true
        addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            if self._didLoginSummary then return end
            self._didLoginSummary = true
            C_Timer.After(3, function()
                self:LoginSummary()
                self:UpdateBadge()
            end)
        end)
    end
end

-- Toggle (called from /pb orders)
function OP:Toggle()
    if not addon.UI then return end
    if addon.TradeSkillFrame and addon.TradeSkillFrame.frame
       and addon.TradeSkillFrame.frame:IsShown() then
        addon.TradeSkillFrame:Hide()
    end
    if not addon.UI.frame:IsShown() then
        addon.UI:Show()
    end
    for i, tab in ipairs(addon.UI.frame.tabs) do
        if tab.name == "orders" then
            addon.UI:SelectTab(i)
            break
        end
    end
end

----------------------------------------------------------------------
-- Shared list component
-- A "ctx" holds: rows (pool), items, scrollOffset, scrollBar,
-- collapsed { incoming, outgoing }, and rebuild() (fills items from
-- the model and repaints).
----------------------------------------------------------------------
function OP:BuildList(parent, ctx, rowCount)
    ctx.rows = {}
    ctx.items = {}
    ctx.scrollOffset = 0
    ctx.collapsed = ctx.collapsed or { incoming = false, outgoing = false }

    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", 0, 0)
    listFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    ctx.listFrame = listFrame

    for i = 1, rowCount do
        local row = self:CreateRow(listFrame, i, ctx)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -16, 0)
        row:SetHeight(ROW_HEIGHT)
        ctx.rows[i] = row
    end

    local sb = CreateFrame("Slider", nil, listFrame)
    sb:SetPoint("TOPRIGHT", 0, 0)
    sb:SetPoint("BOTTOMRIGHT", 0, 0)
    sb:SetWidth(16)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    sb:SetValue(0)
    sb:SetObeyStepOnDrag(true)
    local thumb = sb:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(16, 24)
    thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    sb:SetThumbTexture(thumb)
    local sbg = sb:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    sbg:SetColorTexture(0.05, 0.05, 0.05, 0.5)
    sb:SetScript("OnValueChanged", function(_, value)
        ctx.scrollOffset = math.floor(value)
        self:PaintList(ctx)
    end)
    ctx.scrollBar = sb

    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        sb:SetValue(sb:GetValue() - delta)
    end)
end

-- Relative "x ago" for history timestamps (matches FriendsPanel style).
local function relativeTime(ts)
    if not ts or ts == 0 then return "" end
    local s = time() - ts
    if s < 0 then s = 0 end
    if s < 60 then return "Just now" end
    if s < 3600 then return math.floor(s / 60) .. "m ago" end
    if s < 86400 then return math.floor(s / 3600) .. "h ago" end
    return math.floor(s / 86400) .. "d ago"
end

----------------------------------------------------------------------
-- A single polymorphic row (renders as section header OR order)
----------------------------------------------------------------------
function OP:CreateRow(parent, index, ctx)
    local row = CreateFrame("Frame", nil, parent)
    row:EnableMouse(true)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.12, 0.12, 0.12, 0.6)
    else
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
    end
    row.bg = bg

    local hbg = row:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.18, 0.18, 0.22, 0.95)
    hbg:Hide()
    row.headerBg = hbg

    local headerLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerLabel:SetPoint("LEFT", 8, 0)
    headerLabel:Hide()
    row.headerLabel = headerLabel

    -- "Clear" button shown only on History section headers (set up in
    -- PaintList). Dismisses every terminal order in that section.
    local clearBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    clearBtn:SetSize(52, 16)
    clearBtn:SetPoint("RIGHT", -8, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetNormalFontObject(GameFontNormalSmall)
    clearBtn:SetHighlightFontObject(GameFontHighlightSmall)
    clearBtn:Hide()
    clearBtn:SetScript("OnClick", function(self)
        if self._section then
            StaticPopup_Show("PROFBUDDY_CLEAR_HISTORY", self._section, nil, self._section)
        end
    end)
    row.clearBtn = clearBtn

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOPLEFT", 34, -4)
    name:SetWidth(180)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.nameText = name

    local sec = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sec:SetPoint("TOPLEFT", 34, -19)
    sec:SetWidth(180)
    sec:SetJustifyH("LEFT")
    sec:SetWordWrap(false)
    row.secText = sec

    -- Pill is right-anchored in PaintOrderRow (left of the buttons) so
    -- the layout adapts to the panel width.
    local pillBg = row:CreateTexture(nil, "ARTWORK")
    pillBg:SetSize(72, 16)
    pillBg:SetColorTexture(0.1, 0.1, 0.12, 0.9)
    pillBg:Hide()
    row.pillBg = pillBg

    local pill = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pill:SetPoint("CENTER", pillBg, "CENTER", 0, 0)
    row.pill = pill

    -- Centered placeholder text for empty sections (title + optional hint)
    local emptyTitle = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyTitle:SetPoint("CENTER", row, "CENTER", 0, 7)
    emptyTitle:SetTextColor(0.75, 0.75, 0.75)
    emptyTitle:Hide()
    row.emptyTitle = emptyTitle

    local emptyHint = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyHint:SetPoint("CENTER", row, "CENTER", 0, -7)
    emptyHint:SetTextColor(0.55, 0.55, 0.55)
    emptyHint:Hide()
    row.emptyHint = emptyHint

    row.actionBtns = {}
    for i = 1, 2 do
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(62, 18)
        b:SetNormalFontObject(GameFontNormalSmall)
        b:SetHighlightFontObject(GameFontHighlightSmall)
        b:Hide()
        b:SetScript("OnClick", function()
            local id, akey = b._orderId, b._actionKey
            if not id or not akey then return end
            if akey == "markDelivered" then
                StaticPopup_Show("PROFBUDDY_MARK_DELIVERED", nil, nil, id)
                return
            end
            local O = addon.Orders
            if not O then return end
            local order
            if     akey == "accept"          then order = O:Accept(id)
            elseif akey == "decline"         then order = O:Decline(id)
            elseif akey == "markCrafted"     then order = O:MarkCrafted(id)
            elseif akey == "cancel"          then order = O:Cancel(id)
            elseif akey == "confirmReceived" then order = O:ConfirmReceived(id)
            elseif akey == "dismiss"         then O:Dismiss(id)
            end
            -- Mirror the transition to the counterparty. Dismiss is
            -- local-only (per-side history hide), so it leaves `order`
            -- nil and is intentionally not sent.
            if order and addon.Comm then
                addon.Comm:SendOrderUpdate(order)
            end
            OP:RefreshAll()
        end)
        row.actionBtns[i] = b
    end

    row:SetScript("OnEnter", function()
        local o = row._order
        if not o then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:AddLine(o.item.name .. "  x" .. o.quantity, 1, 1, 1)
        local reqShort = o.requester:match("^([^-]+)") or o.requester
        local crfShort = o.crafter:match("^([^-]+)") or o.crafter
        GameTooltip:AddLine("Requester: " .. reqShort, 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Crafter: " .. crfShort, 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Mats: " .. (MATRESP_LABEL[o.matResponsibility] or "?"), 0.8, 0.8, 0.8)
        local sd = STATUS_DISPLAY[o.status]
        if sd then GameTooltip:AddLine("Status: " .. sd.text, sd.r, sd.g, sd.b) end
        if addon.Orders and addon.Orders.TERMINAL[o.status] and o.updatedAt then
            GameTooltip:AddLine("Closed: " .. date("%b %d, %Y", o.updatedAt) ..
                " (" .. relativeTime(o.updatedAt) .. ")", 0.7, 0.7, 0.7)
        end
        if o.note and o.note ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Note: " .. o.note, 0.9, 0.85, 0.6, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Clicking a header row toggles its section (per-list collapse state)
    row:SetScript("OnMouseUp", function()
        if row._isHeader and row._section then
            ctx.collapsed[row._section] = not ctx.collapsed[row._section]
            if ctx.rebuild then ctx.rebuild() end
        end
    end)

    return row
end

----------------------------------------------------------------------
-- Build the flat item list helper (shared by active + history rebuilds)
-- emptyInc / emptyOut are the placeholder strings for each section.
----------------------------------------------------------------------
-- emptyInc / emptyOut are { text = ..., hint = ... } placeholders.
local function buildItems(ctx, incoming, outgoing, emptyInc, emptyOut)
    local items = {}
    table.insert(items, { kind = "header", section = "incoming", count = #incoming })
    if not ctx.collapsed.incoming then
        if #incoming == 0 then
            table.insert(items, { kind = "empty", text = emptyInc.text, hint = emptyInc.hint })
        else
            for _, o in ipairs(incoming) do
                table.insert(items, { kind = "order", order = o, role = "crafter" })
            end
        end
    end
    table.insert(items, { kind = "header", section = "outgoing", count = #outgoing })
    if not ctx.collapsed.outgoing then
        if #outgoing == 0 then
            table.insert(items, { kind = "empty", text = emptyOut.text, hint = emptyOut.hint })
        else
            for _, o in ipairs(outgoing) do
                table.insert(items, { kind = "order", order = o, role = "requester" })
            end
        end
    end
    return items
end

local function applyScrollRange(ctx)
    local maxScroll = math.max(0, #ctx.items - #ctx.rows)
    ctx.scrollBar:SetMinMaxValues(0, maxScroll)
    if ctx.scrollOffset > maxScroll then
        ctx.scrollOffset = maxScroll
        ctx.scrollBar:SetValue(maxScroll)
    end
end

----------------------------------------------------------------------
-- Paint the visible window of items onto a ctx's row pool
----------------------------------------------------------------------
local function hideOrderWidgets(row)
    row.icon:Hide()
    row.nameText:SetText("")
    row.secText:SetText("")
    row.pill:SetText("")
    row.pillBg:Hide()
    for _, b in ipairs(row.actionBtns) do b:Hide() end
end

function OP:PaintList(ctx)
    for i, row in ipairs(ctx.rows) do
        local item = ctx.items[ctx.scrollOffset + i]

        row._order = nil
        row._isHeader = false
        row._section = nil
        row.headerBg:Hide()
        row.headerLabel:Hide()
        row.clearBtn:Hide()
        row.emptyTitle:Hide()
        row.emptyHint:Hide()
        row.bg:Show()

        if not item then
            row:Hide()
            hideOrderWidgets(row)
        elseif item.kind == "header" then
            row:Show()
            hideOrderWidgets(row)
            row.bg:Hide()
            row.headerBg:Show()
            row._isHeader = true
            row._section = item.section
            local arrow = ctx.collapsed[item.section] and "+" or "-"
            local label = (item.section == "incoming") and "Incoming" or "Outgoing"
            row.headerLabel:SetText(string.format("%s  %s (%d)", arrow, label, item.count))
            row.headerLabel:Show()
            -- History sections get a "Clear" button when non-empty.
            if ctx == self.histCtx and item.count > 0 then
                row.clearBtn._section = item.section
                row.clearBtn:Show()
            end
        elseif item.kind == "empty" then
            row:Show()
            hideOrderWidgets(row)
            row.emptyTitle:SetText(item.text or "")
            row.emptyTitle:Show()
            if item.hint and item.hint ~= "" then
                row.emptyHint:SetText(item.hint)
                row.emptyHint:Show()
            end
        elseif item.kind == "order" then
            row:Show()
            self:PaintOrderRow(row, item.order, item.role)
        end
    end
end

function OP:PaintOrderRow(row, o, role)
    row._order = o

    local tex = PROF_ICONS[o.item.profession]
    if tex then
        row.icon:SetTexture(tex)
        row.icon:Show()
    else
        row.icon:Hide()
    end

    row.nameText:SetText(string.format("%s  x%d", o.item.name or "?", o.quantity or 1))

    local otherKey = (role == "crafter") and o.requester or o.crafter
    local short = otherKey:match("^([^-]+)") or otherKey
    local cd = addon.db.characters[otherKey]
    if cd and cd.class then
        short = addon:ClassColor(cd.class) .. short .. "|r"
    end
    local prefix = (role == "crafter") and "from " or "to "
    local matLbl = MATRESP_SHORT[o.matResponsibility] or "?"
    -- History (terminal) rows show "to/from X  ·  2d ago" on the
    -- secondary line (the mat-responsibility label moves to the hover
    -- tooltip there); active rows keep the mat label. Inline on the
    -- bottom-left line so it never collides with the pill or buttons.
    if addon.Orders and addon.Orders.TERMINAL[o.status] then
        row.secText:SetText(prefix .. short .. "  |cff555555.|r  |cff888888"
            .. relativeTime(o.updatedAt) .. "|r")
    else
        row.secText:SetText(prefix .. short .. "  |cff555555.|r  " .. matLbl)
    end

    -- Action buttons, right-anchored (adapts to panel width)
    local actions = addon.Orders and addon.Orders:LegalActions(o) or {}
    for _, b in ipairs(row.actionBtns) do b:Hide() end

    local n = math.min(#actions, 2)
    for i = 1, n do
        local b = row.actionBtns[i]
        local akey = actions[i]
        b:SetText(ACTION_LABEL[akey] or akey)
        b._orderId = o.id
        b._actionKey = akey
        b:ClearAllPoints()
        b:Show()
    end

    local leftmostBtn
    if n == 1 then
        row.actionBtns[1]:SetPoint("RIGHT", -8, 0)
        leftmostBtn = row.actionBtns[1]
    elseif n == 2 then
        row.actionBtns[2]:SetPoint("RIGHT", -8, 0)
        row.actionBtns[1]:SetPoint("RIGHT", row.actionBtns[2], "LEFT", -4, 0)
        leftmostBtn = row.actionBtns[1]
    end

    -- Status pill: just left of the buttons, or at the right edge if none
    row.pillBg:ClearAllPoints()
    if leftmostBtn then
        row.pillBg:SetPoint("RIGHT", leftmostBtn, "LEFT", -6, 0)
    else
        row.pillBg:SetPoint("RIGHT", -8, 0)
    end

    local sd = STATUS_DISPLAY[o.status]
    if sd then
        row.pill:SetText(sd.text)
        row.pill:SetTextColor(sd.r, sd.g, sd.b)
        row.pillBg:Show()
    else
        row.pill:SetText("")
        row.pillBg:Hide()
    end
end

----------------------------------------------------------------------
-- Active queue tab
----------------------------------------------------------------------
function OP:CreateContent(parent)
    self.parent = parent

    -- Top bar with a History button
    local topBar = CreateFrame("Frame", nil, parent)
    topBar:SetPoint("TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", 0, 0)
    topBar:SetHeight(24)

    local histBtn = CreateFrame("Button", nil, topBar, "UIPanelButtonTemplate")
    histBtn:SetSize(80, 20)
    histBtn:SetPoint("RIGHT", -16, 0)
    histBtn:SetText("History")
    histBtn:SetNormalFontObject(GameFontNormalSmall)
    histBtn:SetHighlightFontObject(GameFontHighlightSmall)
    histBtn:SetScript("OnClick", function() OP:ToggleHistory() end)

    -- List host below the top bar
    local listHost = CreateFrame("Frame", nil, parent)
    listHost:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -2)
    listHost:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    self.activeCtx = { collapsed = { incoming = false, outgoing = false } }
    self:BuildList(listHost, self.activeCtx, 9)

    self.activeCtx.rebuild = function()
        local ctx = self.activeCtx
        local O = addon.Orders
        local incoming = O and O:GetIncoming() or {}
        local outgoing = O and O:GetOutgoing() or {}
        ctx.items = buildItems(ctx, incoming, outgoing,
            { text = "No incoming requests.",
              hint = "When a friend requests a craft from you, it shows up here." },
            { text = "No outgoing orders.",
              hint = "Open a friend's professions and hit Request Craft to place one." })
        applyScrollRange(ctx)
        self:PaintList(ctx)
    end

    -- Let UI:Toggle refresh us when the window reopens
    parent.Refresh = function() OP:Refresh() end

    self.activeCtx.rebuild()
end

----------------------------------------------------------------------
-- History panel (attached draggable window, Material Calc pattern)
----------------------------------------------------------------------
function OP:BuildHistoryPanel()
    if self.histFrame then return end

    local f = CreateFrame("Frame", "ProfBuddyOrderHistory", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(470, 450)

    -- Fastened to the right edge of the main /pb window (Material Calc
    -- pattern). Not independently movable, so it can't be dragged loose;
    -- re-anchored on every show as insurance against a stale point.
    local function anchorRight()
        f:ClearAllPoints()
        if addon.UI and addon.UI.frame then
            f:SetPoint("TOPLEFT", addon.UI.frame, "TOPRIGHT", 4, 0)
        else
            f:SetPoint("CENTER")
        end
    end
    anchorRight()
    if addon.UI and addon.UI.frame then
        -- Close with the parent window
        addon.UI.frame:HookScript("OnHide", function()
            if f:IsShown() then f:Hide() end
        end)
    end

    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:SetScript("OnShow", anchorRight)
    f.TitleText:SetText("Order History")
    f:Hide()
    table.insert(UISpecialFrames, "ProfBuddyOrderHistory")

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 10, -30)
    content:SetPoint("BOTTOMRIGHT", -10, 10)

    self.histCtx = { collapsed = { incoming = false, outgoing = false } }
    self:BuildList(content, self.histCtx, 10)

    self.histCtx.rebuild = function()
        local ctx = self.histCtx
        local O = addon.Orders
        local all = O and O:GetHistory() or {}
        local incoming, outgoing = {}, {}
        for _, o in ipairs(all) do
            local role = O:RoleFor(o)
            if role == "crafter" then
                table.insert(incoming, o)
            elseif role == "requester" then
                table.insert(outgoing, o)
            end
        end
        ctx.items = buildItems(ctx, incoming, outgoing,
            { text = "No completed incoming orders." },
            { text = "No completed outgoing orders." })
        applyScrollRange(ctx)
        self:PaintList(ctx)
    end

    self.histFrame = f
end

function OP:ToggleHistory()
    self:BuildHistoryPanel()
    if self.histFrame:IsShown() then
        self.histFrame:Hide()
    else
        self.histCtx.rebuild()
        self.histFrame:Show()
    end
end

----------------------------------------------------------------------
-- Refresh entry points
----------------------------------------------------------------------
function OP:RefreshAll()
    self:UpdateBadge()
    if self.activeCtx and self.activeCtx.rebuild then self.activeCtx.rebuild() end
    if self.histCtx and self.histCtx.rebuild then self.histCtx.rebuild() end
end

-- Public alias kept for external callers (composer, UI:Toggle)
function OP:Refresh()
    self:RefreshAll()
end

----------------------------------------------------------------------
-- Preserve History across a settings round-trip
-- The main window hides (and thus hides History) on the way into
-- settings, so capture History's open state BEFORE that, then reopen
-- it when settings returns to the main window. Mirrors how the
-- Material Calc is restored after settings on the profession window.
----------------------------------------------------------------------
function OP:CaptureHistoryState()
    self._histWasOpen = (self.histFrame and self.histFrame:IsShown()) or false
end

function OP:RestoreHistoryState()
    if self._histWasOpen then
        self._histWasOpen = false
        self:BuildHistoryPanel()
        self.histCtx.rebuild()
        self.histFrame:Show()
    end
end

----------------------------------------------------------------------
-- Notifications
--   Badge:  count of items needing the current character's action,
--           shown on every registered badge (Orders tab + nav strip).
--           Always on. Works locally.
--   Login:  one summary chat line at login if anything is actionable.
--   Notify: dispatcher the (blocked) backend calls when a counterparty
--           action arrives over the network -- chat line + optional
--           sound. Dormant locally (no actor self-notify), wired ready.
----------------------------------------------------------------------
OP._badges = OP._badges or {}

-- Create a small count badge anchored to a button's top-right corner.
function OP:CreateBadge(button)
    local b = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -2)
    b:SetTextColor(1, 0.85, 0.2)
    b:Hide()
    table.insert(self._badges, b)
    self:UpdateBadge()
    return b
end

function OP:UpdateBadge()
    local count = addon.Orders and addon.Orders:GetActionableCount() or 0
    for _, b in ipairs(self._badges) do
        if count > 0 then
            b:SetText("(" .. count .. ")")
            b:Show()
        else
            b:Hide()
        end
    end
end

function OP:LoginSummary()
    if not (addon.db and addon.db.settings and addon.db.settings.orderChatMessages) then return end
    local O = addon.Orders
    if not O then return end

    local me = addon:PlayerKey()
    local pending, crafted = 0, 0
    for _, o in pairs(addon.db.orders or {}) do
        if not o.dismissed then
            if o.crafter == me and o.status == O.STATUS.PENDING then
                pending = pending + 1
            elseif o.requester == me and o.status == O.STATUS.CRAFTED then
                crafted = crafted + 1
            end
        end
    end
    if pending == 0 and crafted == 0 then return end

    local parts = {}
    if pending > 0 then
        table.insert(parts, pending .. " pending craft request" .. (pending > 1 and "s" or ""))
    end
    if crafted > 0 then
        table.insert(parts, crafted .. " order" .. (crafted > 1 and "s" or "") .. " ready to pick up")
    end
    print("|cff00ccffProfessionBuddy:|r " .. table.concat(parts, ", ") .. ".")
end

-- Backend integration point. kind: "newRequest" | "accepted" |
-- "declined" | "crafted" | "cancelled" | "completed". order is the
-- record the counterparty just acted on.
local NOTIFY_TEXT = {
    newRequest = function(o) return o.requester .. " requested " .. o.quantity .. "x " .. o.item.name end,
    accepted   = function(o) return o.crafter .. " accepted your order: " .. o.quantity .. "x " .. o.item.name end,
    declined   = function(o) return o.crafter .. " declined your order: " .. o.quantity .. "x " .. o.item.name end,
    crafted    = function(o) return o.crafter .. " crafted your order: " .. o.quantity .. "x " .. o.item.name .. " (ready to pick up)" end,
    cancelled  = function(o) return o.requester .. " cancelled their order: " .. o.quantity .. "x " .. o.item.name end,
    completed  = function(o) return "Order completed: " .. o.quantity .. "x " .. o.item.name end,
}

function OP:NotifyOrderEvent(kind, order)
    local s = addon.db and addon.db.settings or {}
    if s.orderChatMessages then
        local fn = NOTIFY_TEXT[kind]
        if fn and order then
            print("|cff00ccffProfessionBuddy:|r " .. fn(order))
        end
    end
    if kind == "newRequest" and s.orderSoundOnRequest then
        PlaySound(SOUNDKIT.TELL_MESSAGE)
    end
    self:UpdateBadge()
    self:RefreshAll()
end
