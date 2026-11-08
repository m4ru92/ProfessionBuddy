----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/Main.lua
-- Main container frame + tab system
----------------------------------------------------------------------

local addon = ProfBuddy
local Theme = addon.Theme
local UI = addon:NewModule("UI")

local FRAME_WIDTH  = 600
local FRAME_HEIGHT = 450

----------------------------------------------------------------------
-- Every floating list this window opens lives on UIParent, not on the
-- window: the dropdown lists (TradeSkillFrame owns them), the Friends
-- tab's order menu and the Guild tab's right-click menu, each with its
-- full-screen click catcher. Hiding the window or switching tabs has to
-- close them by hand or they float over the game world and swallow the
-- next click.
----------------------------------------------------------------------
function addon.CloseAllPopups()
    if addon.CloseAllDropdowns then addon.CloseAllDropdowns() end
    local fp = addon.FriendsPanel
    if fp and fp._orderMenu then fp._orderMenu:Hide() end
    local gp = addon.GuildPanel
    if gp and gp._memberMenu then gp._memberMenu:Hide() end
end

----------------------------------------------------------------------
-- Create the main frame
----------------------------------------------------------------------
function UI:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "ProfBuddyMainFrame", UIParent, "BasicFrameTemplateWithInset")
    -- Layer above other addons' default-strata frames (e.g. a stray durability
    -- or item bar) so they can't bleed over the Characters/Friends/Orders
    -- panels. Matches the profession window (also HIGH) for consistent PB
    -- layering. Child panels inherit this strata.
    f:SetFrameStrata("HIGH")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    -- a side panel open beside it stops at the screen edge with it
    f:SetScript("OnDragStop", function(fr) UI:AfterDrag(fr, UI.scaleFollowers) end)
    f:SetClampedToScreen(true)
    f:Hide()
    -- Order History and Find a Crafter, fastened to this window's right
    -- edge, add themselves here when built and scale with it
    self.scaleFollowers = {}
    self.scaleGrip = self:AddScaleGrip(f, "mainWindowScale", self.scaleFollowers)

    -- Close any open dropdown list (e.g. the Guild tab profession filter) and
    -- the Friends tab order menu when the window hides. Those lists are
    -- UIParent children, so they do not hide with the window on their own, and
    -- the order menu leaves a full-screen click catcher behind if it survives.
    f:HookScript("OnHide", function()
        addon.CloseAllPopups()
    end)

    -- Title
    f.TitleText:SetText("ProfessionBuddy")

    -- Settings gear button (title bar, left of the X close button)
    local gearBtn = CreateFrame("Button", nil, f)
    gearBtn:SetSize(18, 18)
    gearBtn:SetPoint("TOPRIGHT", -26, -4)
    gearBtn:SetFrameLevel(f:GetFrameLevel() + 5)

    local gearIcon = gearBtn:CreateTexture(nil, "ARTWORK")
    gearIcon:SetAllPoints()
    gearIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    gearIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    gearBtn.icon = gearIcon

    gearBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 0.6)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    gearBtn:SetScript("OnClick", function()
        -- Remember if the Order History panel is open so we can reopen
        -- it when settings returns here (the Hide below closes it).
        if addon.OrdersPanel then addon.OrdersPanel:CaptureHistoryState() end
        -- Hide the /pb window and open settings in the profession window
        f:Hide()
        if addon.TradeSkillFrame then
            addon.TradeSkillFrame:OpenSettings("main")
        end
    end)

    -- Make it closeable with Escape
    table.insert(UISpecialFrames, "ProfBuddyMainFrame")

    -- Tab bar container
    f.tabs = {}
    self.frame = f
    self.activeTab = nil
end

----------------------------------------------------------------------
-- Tab system (custom buttons -- no Blizzard tab templates)
----------------------------------------------------------------------
local TAB_HEIGHT = 24
local TAB_PAD    = 4

function UI:AddTab(name, displayName, createFunc)
    local tabIndex = #self.frame.tabs + 1

    -- Custom tab button
    local btn = CreateFrame("Button", "ProfBuddyTab" .. tabIndex, self.frame)
    btn:SetSize(90, TAB_HEIGHT)
    btn:SetNormalFontObject(GameFontNormalSmall)
    btn:SetHighlightFontObject(GameFontHighlightSmall)
    btn:SetText(displayName)

    if Theme:IsClassic() then
        -- Classic: the game's own bottom tabs, 32 px tall like the
        -- template, tucked 2 px under the window and spaced as its
        -- Character window tabs are (Theme:TabLayout).
        btn:SetHeight(32)
        local normal, selected = Theme:DrawClassicTab(btn)
        selected:Hide()
        btn.bgNormal, btn.bgSelected, btn.border = normal, selected, Theme.NO_TEXTURES
    else
        -- Tab background textures
        local bgNormal = btn:CreateTexture(nil, "BACKGROUND")
        bgNormal:SetAllPoints()
        Theme:Fill(bgNormal, "navTab")
        btn.bgNormal = bgNormal

        local bgSelected = btn:CreateTexture(nil, "BACKGROUND")
        bgSelected:SetAllPoints()
        Theme:Fill(bgSelected, "navTabSelected")
        bgSelected:Hide()
        btn.bgSelected = bgSelected

        -- Bottom border on unselected tabs
        local border = btn:CreateTexture(nil, "BORDER")
        border:SetHeight(1)
        border:SetPoint("BOTTOMLEFT")
        border:SetPoint("BOTTOMRIGHT")
        Theme:Fill(border, "navTabBorder")
        btn.border = border
    end

    -- Position
    if Theme:IsClassic() then
        local layout = Theme:TabLayout()
        if tabIndex == 1 then
            btn:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", layout.firstX, 2)
        else
            btn:SetPoint("TOPLEFT", self.frame.tabs[tabIndex - 1].button, "TOPRIGHT", layout.gap, 0)
        end
    elseif tabIndex == 1 then
        btn:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 8, -TAB_HEIGHT - 2)
    else
        btn:SetPoint("LEFT", self.frame.tabs[tabIndex - 1].button, "RIGHT", TAB_PAD, 0)
    end

    -- Content frame (fills the inset area). Top inset kept just below the title
    -- bar; -60 left a visibly loose gap above every tab's content.
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -42)
    content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
    content:Hide()

    -- The ONE refresh hook. A tab's content becomes visible when the window
    -- opens on it and when it is selected, and OnShow covers both, so no other
    -- path (UI:Show, UI:SelectTab, UI:Toggle) refreshes as well: they would
    -- each double-fire on every open. Panels publish their repaint as
    -- content.Refresh.
    content:SetScript("OnShow", function(c)
        if c.Refresh then c:Refresh() end
    end)

    local tabData = {
        name       = name,
        button     = btn,
        content    = content,
        created    = false,
        createFunc = createFunc,
    }

    self.frame.tabs[tabIndex] = tabData

    btn:SetScript("OnClick", function()
        self:SelectTab(tabIndex)
    end)

    -- Auto-select first tab
    if tabIndex == 1 then
        self:SelectTab(1)
    end

    return content
end

function UI:SelectTab(index)
    -- Close any open dropdown list or popup menu when switching tabs (same
    -- reason as OnHide).
    addon.CloseAllPopups()
    -- Re-selecting the tab we are already on must not hide and re-show its
    -- content. The content frame's OnShow IS the refresh hook, so the churn ran
    -- the panel's whole Refresh a SECOND time for one /pb (UI:Show fires OnShow
    -- first) or one click on the active tab.
    local active = self.frame.tabs[index]
    if self.activeTab == index and active and active.created
       and active.content:IsShown() then
        active.button.bgNormal:Hide()
        active.button.bgSelected:Show()
        active.button.border:Hide()
        return
    end

    -- Deselect all
    for _, tab in ipairs(self.frame.tabs) do
        tab.content:Hide()
        tab.button.bgNormal:Show()
        tab.button.bgSelected:Hide()
        tab.button.border:Show()
    end

    local tab = self.frame.tabs[index]
    if not tab then return end

    -- Lazy-create content on first select
    if not tab.created and tab.createFunc then
        tab.createFunc(tab.content)
        tab.created = true
    end

    tab.content:Show()
    tab.button.bgNormal:Hide()
    tab.button.bgSelected:Show()
    tab.button.border:Hide()
    self.activeTab = index
end

----------------------------------------------------------------------
-- Toggle visibility
----------------------------------------------------------------------
-- Show/hide only. Repainting is the content frame's OnShow hook (UI:AddTab),
-- which fires for this path and for every panel Toggle as well.
function UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

function UI:Show()
    self.frame:Show()
end

----------------------------------------------------------------------
-- Drag to scale (2.0.2, RESIZE-scope.md): a grip in a window's bottom-right
-- corner, with Blizzard's resize grabber art (PanelResizeButtonTemplate's
-- textures, on both clients). Dragging it scales the whole window, 75% to
-- 150% and never bigger than the screen, and keeps the window's top-left
-- corner where it is; right-click goes back to 100%. The scale is saved in
-- settings[key] and applied when the window is built. A window holding
-- secure buttons cannot be scaled in combat, so the grip does nothing
-- then. `followers` scale with the window (the profession window's
-- Material Calculator; the main window's Order History and Find a
-- Crafter). They sit beside its right edge, so the size limit leaves room
-- for the widest of them, and the window moves left when one opens with no
-- room on the right (otherwise the game pushes the panel back on screen,
-- over the window).
----------------------------------------------------------------------
UI.SCALE_MIN, UI.SCALE_MAX = 0.75, 1.5

function UI:ClampScale(s)
    s = tonumber(s) or 1
    if s < self.SCALE_MIN then s = self.SCALE_MIN end
    if s > self.SCALE_MAX then s = self.SCALE_MAX end
    return math.floor(s * 100 + 0.5) / 100
end

-- Gap between a window and a side panel fastened to its right edge
UI.SIDE_GAP = 4

-- The scale frame gets for s: within the limits, and no bigger than fits
-- on the screen, so the grip in its corner can always be reached, with room
-- beside it for the widest of its side panels.
function UI:FitScale(frame, s, followers)
    s = self:ClampScale(s)
    local sw, sh = tonumber(UIParent:GetWidth()), tonumber(UIParent:GetHeight())
    local fw, fh = tonumber(frame:GetWidth()), tonumber(frame:GetHeight())
    if sw and sh and fw and fh and fw > 0 and fh > 0 then
        local side = 0
        for _, f in ipairs(followers or {}) do
            local w = type(f.GetWidth) == "function" and tonumber(f:GetWidth())
            if w and w + self.SIDE_GAP > side then side = w + self.SIDE_GAP end
        end
        local fit = math.floor(math.min(sw / (fw + side), sh / fh) * 100) / 100
        if s > fit then s = math.max(fit, self.SCALE_MIN) end
    end
    return s
end

-- A side panel just opened (or its window grew): move the window left as
-- far as the panel runs past the screen's right edge. Not in combat: a
-- window holding secure buttons cannot move then.
function UI:MakeRoomBeside(frame, panel)
    if InCombatLockdown() or not (frame and panel) then return end
    local s = tonumber(frame:GetScale()) or 1
    local ps = tonumber(panel:GetScale()) or s
    local left, top, right = tonumber(frame:GetLeft()), tonumber(frame:GetTop()), tonumber(frame:GetRight())
    local pw, sw = tonumber(panel:GetWidth()), tonumber(UIParent:GetWidth())
    if not (left and top and right and pw and sw) then return end
    local over = (right + self.SIDE_GAP) * s + pw * ps - sw
    if over <= 0 then return end
    local newLeft = math.max(left * s - over, 0)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft / s, top)
end

-- While a side panel is open, the window and the panel stop at the screen
-- edge together: the window's clamp area reaches past its right edge by the
-- widest shown panel plus the gap (SetClampRectInsets moves each edge of the
-- clamp area; a positive right inset moves the right edge out). `except` is
-- a panel being hidden right now. SetClampRectInsets is protected, so not
-- in combat; the next show or hide out of combat catches up.
function UI:UpdateSideClamp(frame, followers, except)
    if InCombatLockdown() or not (frame and frame.SetClampRectInsets) then return end
    local side = 0
    for _, f in ipairs(followers or {}) do
        if f ~= except and type(f.IsShown) == "function" and f:IsShown() then
            local w = type(f.GetWidth) == "function" and tonumber(f:GetWidth())
            if w and w + self.SIDE_GAP > side then side = w + self.SIDE_GAP end
        end
    end
    frame:SetClampRectInsets(0, side, 0, 0)
end

-- A drag ended: an open side panel past the screen's right edge moves the
-- window left, should the clamp area not have held it (in combat, say).
function UI:AfterDrag(frame, followers)
    frame:StopMovingOrSizing()
    for _, f in ipairs(followers or {}) do
        if type(f.IsShown) == "function" and f:IsShown() then self:MakeRoomBeside(frame, f) end
    end
end

-- Scale frame (and its followers) to s, its top-left corner staying put
-- unless an open side panel needs the room.
function UI:ApplyScale(frame, s, followers)
    if InCombatLockdown() then return false end
    s = self:FitScale(frame, s, followers)
    local old = frame:GetScale() or 1
    local left, top = frame:GetLeft(), frame:GetTop()
    frame:SetScale(s)
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / s, top * old / s)
    end
    for _, f in ipairs(followers or {}) do
        f:SetScale(s)
        if type(f.IsShown) == "function" and f:IsShown() then self:MakeRoomBeside(frame, f) end
    end
    return true
end

-- A small menu on UIParent takes the scale of the control it opens from, so
-- it is the same size as the window holding that control.
function UI:MatchScale(popup, anchor)
    local es, ues = anchor and tonumber(anchor:GetEffectiveScale()), tonumber(UIParent:GetEffectiveScale())
    if es and ues and ues > 0 then popup:SetScale(es / ues) end
end

function UI:AddScaleGrip(frame, key, followers)
    local settings = addon.db.settings
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:RegisterForClicks("RightButtonUp")
    local function stop(self)
        if not self._dragging then return end
        self._dragging = false
        self:SetScript("OnUpdate", nil)
        settings[key] = UI:ClampScale(frame:GetScale())
    end
    -- The cursor, in UIParent's units
    local function cursor()
        local x, y = GetCursorPosition()
        local es = UIParent:GetEffectiveScale()
        return x / es, y / es
    end
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        -- an open dropdown list would keep its old size until the next click
        if addon.CloseAllDropdowns then addon.CloseAllDropdowns() end
        local s = frame:GetScale() or 1
        local left, top = frame:GetLeft() * s, frame:GetTop() * s
        local x, y = cursor()
        -- Scale by how far the cursor moves from where the drag began, so a
        -- press on the grip without moving leaves the size alone
        local dx, dy = math.max(x - left, 1), math.max(top - y, 1)
        self._dragging = true
        self:SetScript("OnUpdate", function()
            if InCombatLockdown() then return stop(self) end
            local cx, cy = cursor()
            local ns = s * math.max((cx - left) / dx, (top - cy) / dy)
            if UI:FitScale(frame, ns, followers) ~= UI:ClampScale(frame:GetScale()) then UI:ApplyScale(frame, ns, followers) end
        end)
    end)
    grip:SetScript("OnMouseUp", stop)
    grip:SetScript("OnHide", stop)
    grip:SetScript("OnClick", function()
        if UI:ApplyScale(frame, 1, followers) then settings[key] = 1 end
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Window size")
        GameTooltip:AddLine("Drag to make the window bigger or smaller. Right-click: back to 100%.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local saved = settings[key]
    if saved and saved ~= 1 then UI:ApplyScale(frame, saved, followers) end
    -- A window first built in combat could not take its saved size; it
    -- takes it the next time it opens out of combat.
    frame:HookScript("OnShow", function()
        local want = UI:FitScale(frame, settings[key] or 1, followers)
        if math.abs((frame:GetScale() or 1) - want) > 0.001 then UI:ApplyScale(frame, want, followers) end
    end)
    return grip
end

function UI:Hide()
    self.frame:Hide()
end
