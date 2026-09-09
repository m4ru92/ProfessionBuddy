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
    expired   = { text = "Expired",   r = 0.6, g = 0.6,  b = 0.6 },
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

-- Guild Board open-post composer options. ANY_PROF posts without a profession,
-- so anyone can claim it; a named profession gates the claim (PaintBoardRow).
local ANY_PROF = "Any profession"
local PROF_POST_LIST = {
    ANY_PROF, "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "First Aid", "Jewelcrafting", "Leatherworking", "Tailoring",
}
local POST_MATRESP_OPTIONS = {
    "Order provides mats", "Crafter provides mats", "Split / discuss",
}
local POST_MATRESP_VALUE = {
    ["Order provides mats"]   = "requester",
    ["Crafter provides mats"] = "crafter",
    ["Split / discuss"]       = "split",
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

-- Decline with an optional reason (shown to the requester). Reason is trusted
-- locally (crafter's own text); it is sanitized on the requester's side on receipt.
local function doDecline(orderID, reason)
    if addon.Orders then
        local order = addon.Orders:Decline(orderID, reason)
        if order and addon.Comm then addon.Comm:SendOrderUpdate(order) end
    end
    OP:RefreshAll()
end

StaticPopupDialogs["PROFBUDDY_DECLINE_REASON"] = {
    text = "Decline this order?\nOptional reason (shown to the requester):",
    button1 = "Decline",
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 260,
    maxLetters = 150,
    OnShow = function(self) if self.editBox then self.editBox:SetText("") end end,
    OnAccept = function(self, orderID)
        doDecline(orderID, self.editBox and self.editBox:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        doDecline(p.data, self:GetText())
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Confirm pulling your own open order off the guild board. Cancels the order
-- locally, then tells every guildmate to drop it from their board.
StaticPopupDialogs["PROFBUDDY_CANCEL_OPEN"] = {
    text = "Pull this open order off the guild board?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, orderID)
        if addon.Orders and orderID then
            local order = addon.Orders:Cancel(orderID)
            if order and addon.Comm then
                addon.Comm:BroadcastOrderClosed(orderID, "cancelled")
            end
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
                if tab and tab.name ~= "orders" then
                    if OP.histFrame and OP.histFrame:IsShown() then OP.histFrame:Hide() end
                    if OP.findFrame and OP.findFrame:IsShown() then OP.findFrame:Hide() end
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

    -- "Guild" tag on the name line for an order whose counterparty is a
    -- guildmate and not a friend. Sits in the gap between the name and the
    -- right-anchored pill. Shown per-row in PaintOrderRow.
    local guildTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    guildTag:SetPoint("TOPLEFT", 220, -6)
    guildTag:SetTextColor(0.35, 0.78, 0.35)
    guildTag:SetText("Guild")
    guildTag:Hide()
    row.guildTag = guildTag

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
            if akey == "decline" then
                StaticPopup_Show("PROFBUDDY_DECLINE_REASON", nil, nil, id)
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
        -- A cancelled OPEN post has no crafter (it was pulled before any claim).
        local crfShort = o.crafter and (o.crafter:match("^([^-]+)") or o.crafter) or "unclaimed"
        GameTooltip:AddLine("Requester: " .. reqShort, 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Crafter: " .. crfShort, 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Mats: " .. (MATRESP_LABEL[o.matResponsibility] or "?"), 0.8, 0.8, 0.8)
        local sd = STATUS_DISPLAY[o.status]
        if sd then GameTooltip:AddLine("Status: " .. sd.text, sd.r, sd.g, sd.b) end
        if addon.Orders and addon.Orders.TERMINAL[o.status] and o.updatedAt then
            GameTooltip:AddLine("Closed: " .. date("%b %d, %Y", o.updatedAt) ..
                " (" .. relativeTime(o.updatedAt) .. ")", 0.7, 0.7, 0.7)
        end
        if o.status == "declined" and o.declineReason and o.declineReason ~= "" then
            GameTooltip:AddLine("Reason: " .. o.declineReason, 0.9, 0.6, 0.6, true)
        end
        -- Only show the delivery state to the side that actually SENT the last
        -- update (the order record is account-wide, so without this the other
        -- alt would see "your last update" for an update it never sent).
        if o.lastSentBy == addon:PlayerKey() then
            if o.deliveryState == "delivered" then
                GameTooltip:AddLine("Your last update: delivered", 0.4, 0.85, 0.4)
            elseif o.deliveryState == "queued" then
                GameTooltip:AddLine("Your last update: queued (they're offline)", 0.85, 0.7, 0.3)
            elseif o.deliveryState == "sent" then
                GameTooltip:AddLine("Your last update: sent (awaiting confirmation)", 0.6, 0.6, 0.6)
            end
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
    if row.guildTag then row.guildTag:Hide() end
    for _, b in ipairs(row.actionBtns) do b:Hide() end
end

-- "Guild" tag rule: the order's counterparty (the not-me party) is a guildmate
-- and NOT also a friend. A friend, or a friend who is also a guildmate, shows no
-- tag; only a guild-only relationship does.
local function isGuildOnly(counterpartyKey)
    if not counterpartyKey or counterpartyKey == addon:PlayerKey() then return false end
    local isFriend = addon.db.contacts and addon.db.contacts[counterpartyKey] ~= nil
    if isFriend then return false end
    return addon.Comm and addon.Comm.IsGuildMember and addon.Comm:IsGuildMember(counterpartyKey) or false
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

    -- otherKey is nil for a cancelled OPEN post (requester side, never claimed);
    -- show it as headed "to the board" rather than a named counterparty.
    local otherKey = (role == "crafter") and o.requester or o.crafter
    local short = otherKey and (otherKey:match("^([^-]+)") or otherKey) or "the board"
    local cd = otherKey and addon.db.characters[otherKey]
    if cd and cd.class then
        short = addon:ClassColor(cd.class) .. short .. "|r"
    end

    if row.guildTag then
        if isGuildOnly(otherKey) then row.guildTag:Show() else row.guildTag:Hide() end
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

    -- Top bar: a Direct / Guild Board segmented control on the left, and the
    -- History button on the right (History belongs to the Direct sub-view only).
    local topBar = CreateFrame("Frame", nil, parent)
    topBar:SetPoint("TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", 0, 0)
    topBar:SetHeight(24)

    local directSeg = CreateFrame("Button", nil, topBar, "UIPanelButtonTemplate")
    directSeg:SetSize(84, 20)
    directSeg:SetPoint("LEFT", 0, 0)
    directSeg:SetText("Direct")
    directSeg:SetNormalFontObject(GameFontNormalSmall)
    directSeg:SetHighlightFontObject(GameFontHighlightSmall)
    directSeg:SetScript("OnClick", function() OP:SelectSubview("direct") end)
    self.directSeg = directSeg

    local boardSeg = CreateFrame("Button", nil, topBar, "UIPanelButtonTemplate")
    boardSeg:SetSize(100, 20)
    boardSeg:SetPoint("LEFT", directSeg, "RIGHT", 4, 0)
    boardSeg:SetText("Guild Board")
    boardSeg:SetNormalFontObject(GameFontNormalSmall)
    boardSeg:SetHighlightFontObject(GameFontHighlightSmall)
    boardSeg:SetScript("OnClick", function() OP:SelectSubview("board") end)
    self.boardSeg = boardSeg

    local histBtn = CreateFrame("Button", nil, topBar, "UIPanelButtonTemplate")
    histBtn:SetSize(80, 20)
    histBtn:SetPoint("RIGHT", -16, 0)
    histBtn:SetText("History")
    histBtn:SetNormalFontObject(GameFontNormalSmall)
    histBtn:SetHighlightFontObject(GameFontHighlightSmall)
    histBtn:SetScript("OnClick", function() OP:ToggleHistory() end)
    self.histBtn = histBtn

    -- Find a crafter: sits in the History slot but only on the Guild Board
    -- sub-view (History is Direct-only, so the two never share the corner).
    local findBtn = CreateFrame("Button", nil, topBar, "UIPanelButtonTemplate")
    findBtn:SetSize(104, 20)
    findBtn:SetPoint("RIGHT", -16, 0)
    findBtn:SetText("Find a crafter")
    findBtn:SetNormalFontObject(GameFontNormalSmall)
    findBtn:SetHighlightFontObject(GameFontHighlightSmall)
    findBtn:SetScript("OnClick", function() OP:ToggleFind() end)
    findBtn:Hide()
    self.findBtn = findBtn

    -- Direct list host (the incoming/outgoing active queue)
    local listHost = CreateFrame("Frame", nil, parent)
    listHost:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -2)
    listHost:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.directHost = listHost

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

    -- Guild Board host (open orders you can post/claim)
    local boardHost = CreateFrame("Frame", nil, parent)
    boardHost:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -2)
    boardHost:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    boardHost:Hide()
    self.boardHost = boardHost
    self:BuildBoard(boardHost)

    -- Let UI:Toggle refresh us when the window reopens
    parent.Refresh = function() OP:Refresh() end

    self.subview = "direct"
    self:SelectSubview("direct")
end

----------------------------------------------------------------------
-- Segmented sub-view switch (Direct <-> Guild Board)
----------------------------------------------------------------------
function OP:SelectSubview(name)
    self.subview = name
    local onBoard = (name == "board")

    if self.directHost then self.directHost:SetShown(not onBoard) end
    if self.boardHost then self.boardHost:SetShown(onBoard) end
    -- History is Direct-only, Find a crafter is board-only; swap the two in the
    -- top-right corner and close whichever panel does not belong to this view.
    if self.histBtn then self.histBtn:SetShown(not onBoard) end
    if self.findBtn then self.findBtn:SetShown(onBoard) end
    if onBoard and self.histFrame and self.histFrame:IsShown() then
        self.histFrame:Hide()
    end
    if not onBoard and self.findFrame and self.findFrame:IsShown() then
        self.findFrame:Hide()
    end

    -- Highlight the active segment (LockHighlight keeps the glow lit).
    if self.directSeg then
        if onBoard then self.directSeg:UnlockHighlight() else self.directSeg:LockHighlight() end
    end
    if self.boardSeg then
        if onBoard then self.boardSeg:LockHighlight() else self.boardSeg:UnlockHighlight() end
    end

    if onBoard then
        if self.boardCtx and self.boardCtx.rebuild then self.boardCtx.rebuild() end
    else
        if self.activeCtx and self.activeCtx.rebuild then self.activeCtx.rebuild() end
    end
end

----------------------------------------------------------------------
-- Guild Board sub-view
-- Two sections: your own open posts (Cancel to pull them back) and open
-- orders guildmates have posted (Claim to take one). Claiming whispers the
-- poster, who assigns the first valid claim and hands the order into the
-- normal directed flow -- so a claimed order then appears under Direct.
--
-- Self-contained list (its own row pool + scrollbar): board rows carry a
-- single action button, unlike the two-button directed rows.
----------------------------------------------------------------------
local function buildBoardItems(ctx, mine, avail)
    local items = {}
    table.insert(items, { kind = "header", section = "mine", count = #mine })
    if not ctx.collapsed.mine then
        if #mine == 0 then
            table.insert(items, { kind = "empty", text = "You have no open posts." })
        else
            for _, o in ipairs(mine) do
                table.insert(items, { kind = "board", entry = o, which = "mine" })
            end
        end
    end
    table.insert(items, { kind = "header", section = "avail", count = #avail })
    if not ctx.collapsed.avail then
        if #avail == 0 then
            table.insert(items, { kind = "empty", text = "Nothing to claim right now." })
        else
            for _, o in ipairs(avail) do
                table.insert(items, { kind = "board", entry = o, which = "avail" })
            end
        end
    end
    return items
end

function OP:CreateBoardRow(parent, index, ctx)
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

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOPLEFT", 34, -4)
    name:SetWidth(190)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.nameText = name

    local sec = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sec:SetPoint("TOPLEFT", 34, -19)
    sec:SetWidth(190)
    sec:SetJustifyH("LEFT")
    sec:SetWordWrap(false)
    row.secText = sec

    local emptyTitle = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyTitle:SetPoint("CENTER", row, "CENTER", 0, 0)
    emptyTitle:SetTextColor(0.7, 0.7, 0.7)
    emptyTitle:Hide()
    row.emptyTitle = emptyTitle

    local actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    actionBtn:SetSize(62, 18)
    actionBtn:SetPoint("RIGHT", -8, 0)
    actionBtn:SetNormalFontObject(GameFontNormalSmall)
    actionBtn:SetHighlightFontObject(GameFontHighlightSmall)
    actionBtn:Hide()
    actionBtn:SetScript("OnClick", function(b)
        local id, which = b._orderId, b._which
        if not id then return end
        if which == "mine" then
            StaticPopup_Show("PROFBUDDY_CANCEL_OPEN", nil, nil, id)
        elseif which == "avail" then
            local entry = addon.db.orderBoard and addon.db.orderBoard[id]
            if entry and addon.Comm then
                addon.Comm:ClaimOrder(entry)
                local short = entry.requester
                    and (entry.requester:match("^([^-]+)") or entry.requester) or "?"
                print(string.format(
                    "|cff00ccffProfessionBuddy:|r Claim sent to %s for %dx %s.",
                    short, entry.quantity or 1, (entry.item and entry.item.name) or "?"))
            end
            OP:RefreshAll()
        end
    end)
    -- Keep hover scripts alive while disabled so a guarded Claim can explain why.
    actionBtn:SetMotionScriptsWhileDisabled(true)
    actionBtn:SetScript("OnEnter", function(b)
        if b._disabledReason then
            GameTooltip:SetOwner(b, "ANCHOR_LEFT")
            GameTooltip:SetText(b._disabledReason, 1, 0.4, 0.4, nil, true)
            GameTooltip:Show()
        end
    end)
    actionBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.actionBtn = actionBtn

    -- Clicking a header toggles its section (per-list collapse state)
    row:SetScript("OnMouseUp", function()
        if row._isHeader and row._section then
            ctx.collapsed[row._section] = not ctx.collapsed[row._section]
            if ctx.rebuild then ctx.rebuild() end
        end
    end)

    return row
end

function OP:BuildBoardList(parent, ctx, rowCount)
    ctx.rows = {}
    ctx.items = {}
    ctx.scrollOffset = 0
    ctx.collapsed = ctx.collapsed or { mine = false, avail = false }

    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", 0, 0)
    listFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    ctx.listFrame = listFrame

    for i = 1, rowCount do
        local row = self:CreateBoardRow(listFrame, i, ctx)
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
        self:PaintBoardList(ctx)
    end)
    ctx.scrollBar = sb

    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        sb:SetValue(sb:GetValue() - delta)
    end)
end

function OP:PaintBoardList(ctx)
    for i, row in ipairs(ctx.rows) do
        local item = ctx.items[ctx.scrollOffset + i]

        row._isHeader = false
        row._section = nil
        row.headerBg:Hide()
        row.headerLabel:Hide()
        row.emptyTitle:Hide()
        row.icon:Hide()
        row.nameText:SetText("")
        row.secText:SetText("")
        row.actionBtn:Hide()
        row.bg:Show()

        if not item then
            row:Hide()
        elseif item.kind == "header" then
            row:Show()
            row.bg:Hide()
            row.headerBg:Show()
            row._isHeader = true
            row._section = item.section
            local arrow = ctx.collapsed[item.section] and "+" or "-"
            local label = (item.section == "mine") and "My open posts" or "Available to claim"
            row.headerLabel:SetText(string.format("%s  %s (%d)", arrow, label, item.count))
            row.headerLabel:Show()
        elseif item.kind == "empty" then
            row:Show()
            row.emptyTitle:SetText(item.text or "")
            row.emptyTitle:Show()
        elseif item.kind == "board" then
            row:Show()
            self:PaintBoardRow(row, item.entry, item.which)
        end
    end
end

function OP:PaintBoardRow(row, entry, which)
    local tex = entry.item and PROF_ICONS[entry.item.profession]
    if tex then
        row.icon:SetTexture(tex)
        row.icon:Show()
    else
        row.icon:Hide()
    end

    row.nameText:SetText(string.format("%s  x%d",
        (entry.item and entry.item.name) or "?", entry.quantity or 1))

    local matLbl = MATRESP_SHORT[entry.matResponsibility] or "Mats: order"
    row.actionBtn._disabledReason = nil
    if which == "mine" then
        row.secText:SetText("waiting for a claim  |cff555555.|r  " .. matLbl)
        row.actionBtn:SetText("Cancel")
        row.actionBtn:Enable()
    else
        local short = entry.requester
            and (entry.requester:match("^([^-]+)") or entry.requester) or "?"
        local cd = addon.db.characters and addon.db.characters[entry.requester]
        if cd and cd.class then
            short = addon:ClassColor(cd.class) .. short .. "|r"
        end
        row.secText:SetText("from " .. short .. "  |cff555555.|r  " .. matLbl)
        row.actionBtn:SetText("Claim")
        -- Profession guard: a named profession you do not have blocks the claim.
        -- An unnamed profession (posted as "Any profession") is claimable by all.
        local prof = entry.item and entry.item.profession
        local blocked = prof and prof ~= ""
            and not (addon.DataStore and addon.DataStore:GetProfession(addon:PlayerKey(), prof))
        if blocked then
            row.actionBtn._disabledReason = "You need " .. prof .. " to claim this order."
            row.actionBtn:Disable()
        else
            row.actionBtn:Enable()
        end
    end
    row.actionBtn._orderId = entry.id
    row.actionBtn._which = which
    row.actionBtn:Show()
end

-- Two-row open-post composer at the top of the Guild Board.
--   Row 1: [ item name .......... ] [ qty ]
--   Row 2: [ profession v ] [ mats v ]        [ Post ]
-- A named profession gates the claim (see PaintBoardRow); "Any profession"
-- posts an unguarded order. The richer recipe-picker post lands in increment 3.
function OP:BuildPostComposer(host)
    local composer = CreateFrame("Frame", nil, host)
    composer:SetPoint("TOPLEFT", 0, 0)
    composer:SetPoint("TOPRIGHT", 0, 0)
    composer:SetHeight(50)

    -- Row 1: quantity (narrow, right) then item name filling the rest
    local qty = CreateFrame("EditBox", nil, composer, "InputBoxTemplate")
    qty:SetSize(40, 20)
    qty:SetPoint("TOPRIGHT", -18, -4)
    qty:SetAutoFocus(false); qty:SetNumeric(true); qty:SetMaxLetters(4); qty:SetText("1")
    qty:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)

    local item = CreateFrame("EditBox", nil, composer, "InputBoxTemplate")
    item:SetHeight(20)
    item:SetPoint("TOPLEFT", 12, -4)
    item:SetPoint("RIGHT", qty, "LEFT", -10, 0)
    item:SetAutoFocus(false); item:SetMaxLetters(120)
    item:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)

    -- Placeholder (EditBoxes have no native one)
    local ph = composer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", item, "LEFT", 4, 0)
    ph:SetText("Item to be crafted")
    local function updatePH() if item:GetText() ~= "" then ph:Hide() else ph:Show() end end
    item:SetScript("OnTextChanged", updatePH)
    item:SetScript("OnEditFocusGained", function()
        ph:Hide()
        if addon.CloseAllDropdowns then addon.CloseAllDropdowns() end
    end)
    item:SetScript("OnEditFocusLost", updatePH)
    updatePH()

    -- Tab moves item -> quantity and back; focusing either field closes an open
    -- composer dropdown so it does not linger over the list.
    item:SetScript("OnTabPressed", function() qty:SetFocus() end)
    qty:SetScript("OnTabPressed", function() item:SetFocus() end)
    qty:SetScript("OnEditFocusGained", function()
        if addon.CloseAllDropdowns then addon.CloseAllDropdowns() end
    end)

    -- Row 2: Post button (right), profession + mat-resp dropdowns (left)
    local postBtn = CreateFrame("Button", nil, composer, "UIPanelButtonTemplate")
    postBtn:SetSize(64, 20)
    postBtn:SetPoint("TOPRIGHT", -16, -28)
    postBtn:SetText("Post")
    postBtn:SetNormalFontObject(GameFontNormalSmall)
    postBtn:SetHighlightFontObject(GameFontHighlightSmall)

    local profDrop, matDrop
    if addon.CreateDropdown then
        profDrop = addon.CreateDropdown(composer, 148, PROF_POST_LIST, ANY_PROF, nil, "")
        profDrop:SetPoint("TOPLEFT", 10, -28)
        matDrop = addon.CreateDropdown(composer, 148, POST_MATRESP_OPTIONS, POST_MATRESP_OPTIONS[1], nil, "")
        matDrop:SetPoint("LEFT", profDrop, "RIGHT", 6, 0)
    end

    postBtn:SetScript("OnClick", function()
        if addon.CloseAllDropdowns then addon.CloseAllDropdowns() end
        if not addon.Orders then return end
        local name = strtrim(item:GetText() or "")
        if name == "" then
            print("|cff00ccffProfessionBuddy:|r Enter an item name to post an order.")
            return
        end
        if not IsInGuild() then
            print("|cff00ccffProfessionBuddy:|r You are not in a guild, so there is no board to post to.")
            return
        end
        local q = tonumber(qty:GetText()) or 1
        if q < 1 then q = 1 end
        local prof = profDrop and profDrop.selectedValue
        if prof == ANY_PROF then prof = nil end
        local matVal = (matDrop and POST_MATRESP_VALUE[matDrop.selectedValue]) or "requester"
        local order = addon.Orders:CreateOpen({
            item = { name = name, profession = prof },
            quantity = q,
            matResponsibility = matVal,
        })
        if order and addon.Comm then addon.Comm:BroadcastOpenOrder(order) end
        item:SetText(""); qty:SetText("1"); item:ClearFocus(); qty:ClearFocus()
        print(string.format("|cff00ccffProfessionBuddy:|r Posted %dx %s to the guild board.", q, name))
        OP:RefreshAll()
    end)

    self.postComposer = composer
end

function OP:BuildBoard(host)
    self:BuildPostComposer(host)

    local listHost = CreateFrame("Frame", nil, host)
    listHost:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -52)
    listHost:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    self.boardListHost = listHost

    -- Shown in place of the composer and list when you are not in a guild:
    -- the board is a guild feature, so there is nothing to post to or claim.
    local guildlessMsg = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildlessMsg:SetPoint("TOP", host, "TOP", 0, -60)
    guildlessMsg:SetWidth(360)
    guildlessMsg:SetTextColor(0.75, 0.75, 0.75)
    guildlessMsg:SetText("You are not in a guild.\nThe order board is for posting to and claiming from guildmates.")
    guildlessMsg:Hide()
    self.boardGuildlessMsg = guildlessMsg

    self.boardCtx = { collapsed = { mine = false, avail = false } }
    self:BuildBoardList(listHost, self.boardCtx, 8)

    self.boardCtx.rebuild = function()
        -- Guild gate: no guild means no board. Hide the composer and list, show
        -- the note, and skip the data work.
        if not IsInGuild() then
            if self.postComposer then self.postComposer:Hide() end
            listHost:Hide()
            guildlessMsg:Show()
            return
        end
        if self.postComposer then self.postComposer:Show() end
        listHost:Show()
        guildlessMsg:Hide()

        local ctx = self.boardCtx
        local O = addon.Orders
        local mine = O and O:GetMyOpen() or {}
        local avail = {}
        for _, e in pairs(addon.db.orderBoard or {}) do
            table.insert(avail, e)
        end
        table.sort(avail, function(a, b) return (a.postedAt or 0) < (b.postedAt or 0) end)
        ctx.items = buildBoardItems(ctx, mine, avail)
        applyScrollRange(ctx)
        self:PaintBoardList(ctx)
    end

    -- Reflect joining or leaving a guild without needing a reload.
    if not self._guildEventHooked then
        self._guildEventHooked = true
        addon:RegisterEvent("PLAYER_GUILD_UPDATE", function()
            if OP.boardCtx and OP.boardCtx.rebuild then OP.boardCtx.rebuild() end
        end)
    end

    self.boardCtx.rebuild()
end

----------------------------------------------------------------------
-- Find a crafter (recipe / item search)
-- Reverse lookup across every synced character: you, your alts, friends,
-- and guildmates whose recipes have synced. Type a recipe or item name and
-- see who can make it, then click a result to open their professions and
-- place a directed order. Read-only; no wire.
----------------------------------------------------------------------
local FIND_ROW_H = 32
local REL_LABEL = {
    you    = { text = "you",    r = 0.40, g = 1.00, b = 0.40 },
    alt    = { text = "alt",    r = 0.70, g = 0.85, b = 1.00 },
    friend = { text = "friend", r = 0.50, g = 0.75, b = 1.00 },
    guild  = { text = "guild",  r = 0.35, g = 0.78, b = 0.35 },
    synced = { text = "synced", r = 0.70, g = 0.70, b = 0.70 },
}
-- Closeness order for sorting results: your own characters first, then friends,
-- then guildmates, then anyone else synced.
local REL_ORDER = { you = 1, alt = 2, friend = 3, guild = 4, synced = 5 }
local function relColor(rel)
    local r = REL_LABEL[rel] or REL_LABEL.synced
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(r.r * 255 + 0.5), math.floor(r.g * 255 + 0.5),
        math.floor(r.b * 255 + 0.5), r.text)
end

-- Which relationship is this synced character to me?
local function relationOf(charKey)
    if charKey == addon:PlayerKey() then return "you" end
    local DS = addon.DataStore
    if DS and DS.IsRemote and DS:IsRemote(charKey) then
        if addon.db.contacts and addon.db.contacts[charKey] then return "friend" end
        if addon.Comm and addon.Comm.IsGuildMember and addon.Comm:IsGuildMember(charKey) then
            return "guild"
        end
        return "synced"
    end
    return "alt"
end

-- Every (character, recipe) whose recipe name contains the query, across all
-- synced character data. Returns a list sorted by recipe then relationship.
function OP:FindCrafters(query)
    local out = {}
    query = strtrim(query or ""):lower()
    if #query < 2 then return out end
    for charKey, char in pairs(addon.db.characters or {}) do
        if char.professions then
            for profName, profData in pairs(char.professions) do
                local recipes = profData.recipes
                if recipes then
                    for rname in pairs(recipes) do
                        if type(rname) == "string" and rname:lower():find(query, 1, true) then
                            table.insert(out, {
                                charKey   = charKey,
                                short     = charKey:match("^([^-]+)") or charKey,
                                classColor = addon:ClassColor(char.class or "WARRIOR"),
                                profName  = profName,
                                skill     = profData.skillLevel or profData.level or 0,
                                recipe    = rname,
                                rel       = relationOf(charKey),
                            })
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.recipe ~= b.recipe then return a.recipe < b.recipe end
        local ra, rb = REL_ORDER[a.rel] or 9, REL_ORDER[b.rel] or 9
        if ra ~= rb then return ra < rb end
        return a.charKey < b.charKey
    end)
    return out
end

function OP:PaintFind()
    local ctx = self.findCtx
    if not ctx then return end
    for i, row in ipairs(ctx.rows) do
        local m = ctx.items[ctx.scrollOffset + i]
        if m then
            row._match = m
            row.recText:SetText(m.recipe)
            row.whoText:SetText(m.classColor .. m.short .. "|r  (" .. relColor(m.rel)
                .. ")  |cffbbbbbb" .. m.profName .. " " .. m.skill .. "|r")
            row:Show()
        else
            row._match = nil
            row:Hide()
        end
    end
end

function OP:RefreshFind()
    local ctx = self.findCtx
    if not ctx then return end
    local q = (self.findBox and self.findBox:GetText()) or ""
    local results = self:FindCrafters(q)
    ctx.items = results
    ctx.scrollOffset = 0
    local maxScroll = math.max(0, #results - #ctx.rows)
    ctx.scrollBar:SetMinMaxValues(0, maxScroll)
    ctx.scrollBar:SetValue(0)
    if #results == 0 then
        ctx.empty:SetText(#strtrim(q) < 2
            and "Type at least two letters of a recipe or item name."
            or "No synced crafter knows a recipe matching that.")
        ctx.empty:Show()
    else
        ctx.empty:Hide()
    end
    self:PaintFind()
end

function OP:BuildFindPanel()
    if self.findFrame then return end

    local f = CreateFrame("Frame", "ProfBuddyFindCrafter", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(470, 450)
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
        addon.UI.frame:HookScript("OnHide", function() if f:IsShown() then f:Hide() end end)
    end
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:SetScript("OnShow", anchorRight)
    f.TitleText:SetText("Find a Crafter")
    f:Hide()
    table.insert(UISpecialFrames, "ProfBuddyFindCrafter")

    local box = CreateFrame("EditBox", "ProfBuddyFindSearch", f, "InputBoxTemplate")
    box:SetSize(280, 20)
    box:SetPoint("TOPLEFT", 16, -30)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
    box:SetScript("OnTextChanged", function() OP:RefreshFind() end)
    self.findBox = box

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", box, "RIGHT", 10, 0)
    hint:SetText("Recipe or item name")

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 12, -58)
    content:SetPoint("BOTTOMRIGHT", -10, 12)

    local ctx = { rows = {}, items = {}, scrollOffset = 0 }
    self.findCtx = ctx

    local listFrame = CreateFrame("Frame", nil, content)
    listFrame:SetAllPoints()
    ctx.listFrame = listFrame

    local ROWS = 12
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listFrame)
        row:SetHeight(FIND_ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * FIND_ROW_H)
        row:SetPoint("RIGHT", -16, 0)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i % 2 == 0 then bg:SetColorTexture(0.12, 0.12, 0.12, 0.5)
        else bg:SetColorTexture(0.08, 0.08, 0.08, 0.3) end
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        local rec = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rec:SetPoint("TOPLEFT", 6, -4)
        rec:SetJustifyH("LEFT"); rec:SetWidth(410); rec:SetWordWrap(false)
        row.recText = rec
        local who = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        who:SetPoint("TOPLEFT", 6, -18)
        who:SetJustifyH("LEFT"); who:SetWidth(410); who:SetWordWrap(false)
        row.whoText = who
        row:SetScript("OnClick", function(self)
            local m = self._match
            if not m then return end
            if addon.TradeSkillFrame and addon.TradeSkillFrame.OpenWithCharacter then
                addon.TradeSkillFrame:OpenWithCharacter(m.charKey, m.profName)
            end
        end)
        row:SetScript("OnEnter", function(self)
            local m = self._match
            if not m then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.recipe, 1, 1, 1)
            GameTooltip:AddLine("Open " .. m.short .. "'s " .. m.profName
                .. " to place an order", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
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
    sb:SetScript("OnValueChanged", function(_, v)
        ctx.scrollOffset = math.floor(v)
        OP:PaintFind()
    end)
    ctx.scrollBar = sb
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, d) sb:SetValue(sb:GetValue() - d) end)

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", 0, -24)
    empty:SetText("Type at least two letters of a recipe or item name.")
    ctx.empty = empty

    self.findFrame = f
end

-- Pull full recipe data from online guildmates so the search can find them.
-- A guildmate you have not browsed only has a lightweight profession summary
-- (no recipes), so without this the search silently misses them. RequestGuildSync
-- reuses SYNC_REQ (no wire change) and is throttled per target, and replies
-- refresh the open panel through NotifyUIRefresh -> RefreshFind.
function OP:SyncGuildForSearch()
    if not (addon.Comm and addon.Comm.RequestGuildSync and IsInGuild()) then return end
    local me = addon:PlayerKey()
    local myRealm = GetRealmName()
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online then
            local key = name:find("-") and name or (name .. "-" .. myRealm)
            if key ~= me then
                addon.Comm:RequestGuildSync(key)
            end
        end
    end
end

function OP:ToggleFind()
    self:BuildFindPanel()
    if self.findFrame:IsShown() then
        self.findFrame:Hide()
    else
        self:SyncGuildForSearch()
        self:RefreshFind()
        self.findFrame:Show()
        if self.findBox then self.findBox:SetFocus() end
    end
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

    -- Sort toggle (title bar, left of the close button): flips History between
    -- newest-closed-first and oldest-first. Global for both sections.
    local sortBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sortBtn:SetSize(92, 18)
    -- Anchor to the LEFT of the frame's close button so it lines up with it
    -- vertically and can't overlap it regardless of the template's geometry.
    local closeB = f.CloseButton or (f:GetName() and _G[f:GetName() .. "CloseButton"])
    if closeB then
        sortBtn:SetPoint("RIGHT", closeB, "LEFT", 0, 0)
    else
        sortBtn:SetPoint("TOPRIGHT", -30, -4)
    end
    sortBtn:SetNormalFontObject(GameFontNormalSmall)
    sortBtn:SetHighlightFontObject(GameFontHighlightSmall)
    local function sortLabel()
        return addon.db.settings.orderHistorySortOldest and "Oldest first" or "Newest first"
    end
    sortBtn:SetText(sortLabel())
    sortBtn:SetScript("OnClick", function(btn)
        local s = addon.db.settings
        s.orderHistorySortOldest = not s.orderHistorySortOldest
        btn:SetText(sortLabel())
        if OP.histCtx and OP.histCtx.rebuild then OP.histCtx.rebuild() end
    end)
    f.sortBtn = sortBtn

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
    if self.boardCtx and self.boardCtx.rebuild then self.boardCtx.rebuild() end
    if self.histCtx and self.histCtx.rebuild then self.histCtx.rebuild() end
end

-- Public alias kept for external callers (composer, UI:Toggle)
function OP:Refresh()
    self:RefreshAll()
end

----------------------------------------------------------------------
-- Preserve History and Find a crafter across a settings round-trip
-- The main window hides (and thus hides both attached panels) on the way
-- into settings, so capture whichever was open BEFORE that, then reopen it
-- when settings returns to the main window. Mirrors how the Material Calc is
-- restored after settings on the profession window. The two panels are
-- mutually exclusive (History is Direct-only, Find is board-only), so at most
-- one flag is ever set.
----------------------------------------------------------------------
function OP:CaptureHistoryState()
    self._histWasOpen = (self.histFrame and self.histFrame:IsShown()) or false
    self._findWasOpen = (self.findFrame and self.findFrame:IsShown()) or false
end

function OP:RestoreHistoryState()
    if self._histWasOpen then
        self._histWasOpen = false
        self:BuildHistoryPanel()
        self.histCtx.rebuild()
        self.histFrame:Show()
    end
    if self._findWasOpen then
        self._findWasOpen = false
        self:BuildFindPanel()
        self:RefreshFind()
        self.findFrame:Show()
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
