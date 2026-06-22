----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/Main.lua
-- Main container frame + tab system
----------------------------------------------------------------------

local addon = ProfBuddy
local UI = addon:NewModule("UI")

local FRAME_WIDTH  = 600
local FRAME_HEIGHT = 450

----------------------------------------------------------------------
-- Create the main frame
----------------------------------------------------------------------
function UI:Init()
    if self.frame then return end

    local f = CreateFrame("Frame", "ProfBuddyMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

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

    -- Tab background textures
    local bgNormal = btn:CreateTexture(nil, "BACKGROUND")
    bgNormal:SetAllPoints()
    bgNormal:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    btn.bgNormal = bgNormal

    local bgSelected = btn:CreateTexture(nil, "BACKGROUND")
    bgSelected:SetAllPoints()
    bgSelected:SetColorTexture(0.25, 0.25, 0.3, 1)
    bgSelected:Hide()
    btn.bgSelected = bgSelected

    -- Bottom border on unselected tabs
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetHeight(1)
    border:SetPoint("BOTTOMLEFT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetColorTexture(0.4, 0.4, 0.4, 1)
    btn.border = border

    -- Position
    if tabIndex == 1 then
        btn:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 8, -TAB_HEIGHT - 2)
    else
        btn:SetPoint("LEFT", self.frame.tabs[tabIndex - 1].button, "RIGHT", TAB_PAD, 0)
    end

    -- Content frame (fills the inset area)
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -60)
    content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
    content:Hide()

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
function UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        -- Refresh active tab
        if self.activeTab and self.frame.tabs[self.activeTab] then
            local tab = self.frame.tabs[self.activeTab]
            if tab.content.Refresh then
                tab.content:Refresh()
            end
        end
    end
end

function UI:Show()
    self.frame:Show()
end

function UI:Hide()
    self.frame:Hide()
end
