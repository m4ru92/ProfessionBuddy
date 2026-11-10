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
    -- TBC Anniversary: not in combat, once the strip's secure buttons make
    -- moving it a blocked action (UI:Locked)
    f:SetScript("OnDragStart", function(fr) if not UI:Locked() then fr:StartMoving() end end)
    -- a side panel open beside it stops at the screen edge with it
    f:SetScript("OnDragStop", function(fr) UI:AfterDrag(fr, UI.scaleFollowers) end)
    f:SetClampedToScreen(true)
    f:Hide()
    -- Order History and Find a Crafter, fastened to this window's right
    -- edge, add themselves here when built and scale with it
    self.scaleFollowers = {}
    self.scaleGrip = self:AddScaleGrip(f, "mainWindowScale", self.scaleFollowers)
    -- after the scale grip, whose OnShow puts the saved size back first
    self:TrackPosition(f, "main")

    -- Close any open dropdown list (e.g. the Guild tab profession filter) and
    -- the Friends tab order menu when the window hides. Those lists are
    -- UIParent children, so they do not hide with the window on their own, and
    -- the order menu leaves a full-screen click catcher behind if it survives.
    f:HookScript("OnHide", function()
        addon.CloseAllPopups()
        -- closing it while a profession is parked closes that profession
        -- too, so no hidden session stays open (TEST-c, decision D2). Not
        -- on the way to Settings, which comes back here (TEST-c2, m4ru)
        local tsf = addon.TradeSkillFrame
        if tsf and tsf._parked and not UI._toSettings then tsf:EndPark(true) end
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
    self.gearBtn = gearBtn

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
        -- Hide the /pb window and open settings in the profession window;
        -- a parked profession stays parked for the way back
        UI._toSettings = true
        UI:Hide()
        UI._toSettings = nil
        if addon.TradeSkillFrame then
            addon.TradeSkillFrame:OpenSettings("main")
        end
    end)

    -- Make it closeable with Escape
    table.insert(UISpecialFrames, "ProfBuddyMainFrame")

    self:BuildStrip(f)

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
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -UI.CONTENT_TOP)
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
        self:Hide()
    else
        self:Show()
    end
end

function UI:Show()
    if self:Locked() then return self:Defer("show") end
    self.frame:Show()
end

----------------------------------------------------------------------
-- The profession strip and Back (TEST-c, N1 and N2, Bran). The icons the
-- profession window has, in this window's top-left corner on every tab:
-- a click opens that profession (an unknown one opens its read-only list).
-- At the right end of the same row, where the profession window has its
-- search box, "Back to <profession>" while one is parked: a fixed spot
-- that never moves (decision D1; TEST-c2, m4ru). The tabs' content starts
-- below them.
----------------------------------------------------------------------
UI.CONTENT_TOP = 52        -- was 42; the strip needs the room
UI.BACK_W = 160

function UI:BuildStrip(f)
    local back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    back:SetSize(self.BACK_W, 22)
    -- "Back to Leatherworking" fits in the smaller font
    back:SetNormalFontObject(GameFontNormalSmall)
    back:SetHighlightFontObject(GameFontHighlightSmall)
    back:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -27)
    back:SetFrameLevel(f:GetFrameLevel() + 5)
    back:SetScript("OnClick", function()
        if addon.TradeSkillFrame then addon.TradeSkillFrame:Unpark() end
    end)
    back:Hide()
    self.backBtn = back
    -- The parked profession's own icon works as Back (TEST-c4, m4ru): a
    -- plain button over it, so the icon's /cast on TBC Anniversary, which
    -- closes a profession whose window is open, never runs then
    local cover = CreateFrame("Button", nil, f)
    cover:SetFrameLevel(f:GetFrameLevel() + 10)
    cover:RegisterForClicks("LeftButtonUp")
    cover:SetScript("OnClick", function()
        if addon.TradeSkillFrame then addon.TradeSkillFrame:Unpark() end
    end)
    cover:SetScript("OnEnter", function(c)
        local p = addon.TradeSkillFrame and addon.TradeSkillFrame._parked
        if not p then return end
        GameTooltip:SetOwner(c, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Back to " .. p.display)
        GameTooltip:Show()
    end)
    cover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cover:Hide()
    cover._tab = false
    self.parkedTab = cover
    local tsf = addon.TradeSkillFrame
    if not (tsf and tsf.NewProfStrip) then return end
    -- WoW: Forever opens a profession by skill line: plain buttons, so this
    -- window can still open and close in combat. TBC Anniversary casts the
    -- profession: secure buttons, and the window waits for combat to end
    -- (UI:Locked, decision D3).
    local strip = tsf:NewProfStrip(f, "ProfBuddyMainProfTab", { plain = true, isMain = true })
    strip.container:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -28)
    self.profStrip = strip
    f:HookScript("OnShow", function()
        UI:UpdateStrip()
        UI:UpdateBack()
    end)
end

-- Lay out the strip, the parked profession highlighted
function UI:UpdateStrip()
    local strip, tsf = self.profStrip, addon.TradeSkillFrame
    if not (strip and tsf) then return end
    if strip.secure and InCombatLockdown() then
        self._stripDirty = true
    else
        self._stripDirty = nil
        tsf:LayoutProfStrip(strip, tsf._parked and tsf._parked.prof)
    end
    self:UpdateParkedTab()
end

-- The button over the parked profession's icon: on it while one is
-- parked, gone otherwise. In combat on TBC Anniversary the icons can't
-- move: a button last placed over that icon shows there again, and any
-- other case waits for the layout after combat.
function UI:UpdateParkedTab()
    local cover, strip, tsf = self.parkedTab, self.profStrip, addon.TradeSkillFrame
    if not (cover and strip and tsf) then return end
    local p = tsf._parked
    -- Smelting shows under the Mining icon
    local tab = p and (strip.byName[p.prof] or (p.prof == "Smelting" and strip.byName.Mining))
    if not (tab and tab:IsShown()) then cover:Hide(); return end
    if strip.secure and InCombatLockdown() then
        -- still anchored to that icon from the last layout
        if cover._tab == tab then cover:Show() else cover:Hide() end
        return
    end
    cover:ClearAllPoints()
    cover:SetAllPoints(tab)
    cover._tab = tab
    cover:Show()
end

function UI:UpdateBack()
    local back, tsf = self.backBtn, addon.TradeSkillFrame
    if not back then return end
    local p = tsf and tsf._parked
    if p then
        back:SetText("Back to " .. p.display)
        back:Show()
    else
        back:Hide()
    end
    if self.frame and self.frame:IsShown() then self:UpdateStrip() else self:UpdateParkedTab() end
end

-- TBC Anniversary: the strip's secure buttons make this window one the
-- game won't let an addon show, hide or move in combat
function UI:Locked()
    return (self.profStrip and self.profStrip.secure and InCombatLockdown()) and true or false
end

-- In combat: open or close when combat ends, said once per fight
function UI:Defer(action)
    self._pending = action
    if not self._saidCombat then
        self._saidCombat = true
        print("|cff00ccffProfessionBuddy:|r The ProfessionBuddy window "
            .. (action == "show" and "opens" or "closes") .. " when combat ends.")
    end
end

addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    UI._saidCombat = nil
    local act = UI._pending
    UI._pending = nil
    if UI.frame then
        if act == "show" then UI.frame:Show() elseif act == "hide" then UI.frame:Hide() end
    end
    if UI._stripDirty and UI.frame and UI.frame:IsShown() then UI:UpdateStrip() end
end)

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
    -- a drag marks the window as placed by you, and the game then puts it
    -- back after a /reload by itself, past "Keep after a reload or logout"
    -- (TEST-c, m4ru's step A6). PB keeps positions itself (SavePosition).
    if not InCombatLockdown() then frame:SetUserPlaced(false) end
    for _, f in ipairs(followers or {}) do
        if type(f.IsShown) == "function" and f:IsShown() then self:MakeRoomBeside(frame, f) end
    end
    self:SavePosition(frame)
end

----------------------------------------------------------------------
-- Window state and positions kept across a /reload or logout (TEST-c,
-- Hircus and Sticker): per character in ProfBuddyDB.windows, while both
-- "Remember window state between opens" and "Keep after a reload or
-- logout" are on. Not in the character record, which friends receive.
----------------------------------------------------------------------
function UI:KeepOn()
    local s = addon.db and addon.db.settings
    return (s and s.rememberWindowState ~= false and s.keepWindowState ~= false) and true or false
end

-- This character's table, made on first use
function UI:CharWindows()
    local db = addon.db
    db.windows = db.windows or {}
    local key = addon:PlayerKey()
    if not key then return nil end
    db.windows[key] = db.windows[key] or {}
    return db.windows[key]
end

-- The window's top-left corner in UIParent's units (its own units times
-- its scale), so a scale change does not move it
function UI:SavePosition(frame)
    local key = frame and frame._pbPosKey
    if not (key and self:KeepOn()) then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return end
    local w = self:CharWindows()
    if not w then return end
    local s = frame:GetScale() or 1
    w.pos = w.pos or {}
    w.pos[key] = { x = left * s, y = top * s }
end

-- Back where it was, pulled onto the screen if the screen got smaller.
-- True when it put the window somewhere.
function UI:RestorePosition(frame)
    local key = frame and frame._pbPosKey
    if not (key and self:KeepOn()) then return false end
    local w = addon.db.windows and addon.db.windows[addon:PlayerKey() or ""]
    local p = w and w.pos and w.pos[key]
    local x, y = p and tonumber(p.x), p and tonumber(p.y)
    if not (x and y) then return false end
    local s = frame:GetScale() or 1
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local fw, fh = (frame:GetWidth() or 0) * s, (frame:GetHeight() or 0) * s
    if type(sw) == "number" and type(sh) == "number" then
        x = math.max(0, math.min(x, sw - fw))
        y = math.min(sh, math.max(y, fh))
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
    return true
end

-- Keep this window's position under key: put back the first time it
-- shows, saved when it hides, a drag ends (AfterDrag) or you log out
function UI:TrackPosition(frame, key)
    frame._pbPosKey = key
    frame._pbPosRestored = false
    self._tracked = self._tracked or {}
    self._tracked[#self._tracked + 1] = frame
    frame:HookScript("OnShow", function(f)
        -- moving it in combat is blocked on TBC Anniversary: the next open
        if f._pbPosRestored or InCombatLockdown() then return end
        f._pbPosRestored = true
        if UI:RestorePosition(f) then return end
        f:SetUserPlaced(false)
        -- Keep on with nothing saved yet (first open after updating): it
        -- stays where it is, where the game may have kept it from your
        -- last drag; PB saves it from here (TEST-c4). Keep off: the middle
        -- of the screen, also over a spot the game kept (see UI:AfterDrag)
        if UI:KeepOn() then return end
        f:ClearAllPoints()
        f:SetPoint("CENTER")
    end)
    frame:HookScript("OnHide", function(f) UI:SavePosition(f) end)
end

-- At logout and /reload, before the game writes the saved settings
function UI:SaveAllPositions()
    if not self:KeepOn() then
        -- keeping is off: nothing of this character's carries over
        local w = addon.db.windows and addon.db.windows[addon:PlayerKey() or ""]
        if type(w) == "table" then w.pos = nil end
        return
    end
    for _, f in ipairs(self._tracked or {}) do
        if f:IsShown() then self:SavePosition(f) end
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
    if self:Locked() then return self:Defer("hide") end
    self.frame:Hide()
end
