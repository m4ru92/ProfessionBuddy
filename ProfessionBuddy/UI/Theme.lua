----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/Theme.lua
-- One place for the colours and backdrops PB's windows draw with.
-- Every panel fill, row stripe, hover, divider and backdrop asks
-- Theme for its role by name instead of carrying its own numbers, so
-- a second look can replace the whole set at once. Modern is the look
-- PB has always had; the values are the ones each call site used.
-- Colours that carry meaning (difficulty, quality, have/need counts,
-- class and faction) stay where they are.
----------------------------------------------------------------------

local addon = ProfBuddy
local Theme = {}
addon.Theme = Theme

local STYLES = {}
Theme.STYLES = STYLES

STYLES.modern = {
    -- SetBackdrop tables
    backdrop = {
        calcButtonBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
        dialog = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } },
        dialogBox = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
        dropdownButtonBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
        dropdownList = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } },
        input = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } },
        menu = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
        pane = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } },
        professionTabBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
        settingsGroup = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = nil, insets = { left = 4, right = 4, top = 4, bottom = 4 } },
    },
    -- SetBackdropColor, by role
    bg = {
        craftBarPane = { 0.08, 0.08, 0.1, 0.95 },
        detailPane = { 0.06, 0.06, 0.08, 0.95 },
        dialog = { 0.06, 0.06, 0.08, 0.97 },
        dialogBox = { 0, 0, 0, 0.5 },
        dropdownList = { 0.08, 0.08, 0.1, 0.98 },
        input = { 0.05, 0.05, 0.07, 0.9 },
        menu = { 0.08, 0.08, 0.1, 0.97 },
        recipeListPane = { 0.05, 0.05, 0.07, 0.95 },
        settingsGroup = { 0.1, 0.1, 0.12, 0.6 },
    },
    -- SetBackdropBorderColor, by role
    border = {
        calcButton = { 0.4, 0.4, 0.4, 0.6 },
        calcButtonActive = { 0.4, 0.7, 1, 0.9 },
        craftBarPane = { 0.35, 0.35, 0.4, 0.8 },
        detailPane = { 0.35, 0.35, 0.4, 0.8 },
        dialog = { 0.5, 0.5, 0.5, 0.9 },
        dialogBox = { 0.3, 0.3, 0.35, 0.9 },
        dropdownButton = { 0.4, 0.4, 0.4, 0.8 },
        dropdownList = { 0.5, 0.5, 0.5, 0.9 },
        input = { 0.4, 0.4, 0.4, 0.8 },
        menu = { 0.5, 0.5, 0.5, 0.9 },
        professionTab = { 0.4, 0.4, 0.4, 0.6 },
        professionTabActive = { 0.4, 0.7, 1, 0.9 },
        professionTabDim = { 0.3, 0.3, 0.3, 0.4 },
        recipeListPane = { 0.35, 0.35, 0.4, 0.8 },
    },
    -- SetColorTexture on plain textures, by role
    fill = {
        bottomBar = { 0.08, 0.08, 0.1, 0.9 },
        calcButton = { 0.15, 0.15, 0.18, 0.9 },
        calcButtonActive = { 0.1, 0.25, 0.45, 0.9 },
        calcButtonHover = { 0.22, 0.22, 0.28, 0.9 },
        calcColumnDivider = { 0.25, 0.25, 0.3, 0.5 },
        calcRowDivider = { 0.4, 0.38, 0.3, 0.6 },
        characterRow = { 0.15, 0.15, 0.15, 0.8 },
        columnHeader = { 0.15, 0.15, 0.15, 0.8 },
        columnHeaderHover = { 0.4, 0.4, 0.6, 0.25 },
        divider = { 0.3, 0.3, 0.35, 0.6 },
        dividerFaint = { 0.3, 0.3, 0.35, 0.4 },
        dropdownButton = { 0.12, 0.12, 0.15, 1 },
        enchantButtonEdge = { 0.4, 0.4, 0.45, 0.9 },
        enchantButtonFill = { 0.18, 0.18, 0.2, 1 },
        enchantButtonHover = { 0.35, 0.35, 0.45, 0.4 },
        guildRowHover = { 0.3, 0.3, 0.5, 0.15 },
        historyRowEven = { 0.12, 0.12, 0.12, 0.5 },
        iconButtonHover = { 1, 1, 1, 0.25 },
        listBackground = { 0.05, 0.05, 0.05, 0.5 },
        menuHover = { 0.3, 0.3, 0.5, 0.5 },
        navTab = { 0.15, 0.15, 0.15, 0.9 },
        navTabBorder = { 0.4, 0.4, 0.4, 1 },
        navTabSelected = { 0.25, 0.25, 0.3, 1 },
        orderRowSelected = { 0.18, 0.18, 0.22, 0.95 },
        professionRowHover = { 0.3, 0.3, 0.3, 0.5 },
        professionTab = { 0.12, 0.12, 0.15, 0.9 },
        professionTabActive = { 0.2, 0.35, 0.55, 0.9 },
        professionTabDim = { 0.08, 0.08, 0.1, 0.9 },
        professionTabSeparator = { 0.6, 0.6, 0.6, 0.8 },
        recipeCategoryHeader = { 0.2, 0.17, 0.05, 0.6 },
        recipeRowHover = { 0.25, 0.3, 0.45, 0.35 },
        recipeRowSelected = { 0.18, 0.22, 0.35, 0.7 },
        rowEven = { 0.12, 0.12, 0.12, 0.6 },
        rowOdd = { 0.08, 0.08, 0.08, 0.3 },
        scrollThumb = { 0.4, 0.4, 0.5, 0.8 },
        scrollTrack = { 0.08, 0.08, 0.1, 0.6 },
        sectionDivider = { 0.4, 0.35, 0.1, 0.6 },
        settingsBackground = { 0.05, 0.05, 0.07, 1 },
        skillBarBackground = { 0.08, 0.08, 0.08, 0.9 },
        statusPill = { 0.1, 0.1, 0.12, 0.9 },
    },
    -- A colour passed in (faction) scaled by the first value, alpha second
    tint = {
        factionHeader = { 0.3, 0.9 },
        factionHeaderHover = { 0.4, 0.9 },
    },
}

-- The look in use. Phase 1 has only Modern.
function Theme:Style()
    return STYLES.modern
end

-- A role missing from the look is a typo in PB, never a player's state:
-- fail at the call site instead of drawing nothing.
local function look(kind, role)
    local v = Theme:Style()[kind][role]
    if v == nil then
        error("ProfessionBuddy theme has no " .. kind .. " role " .. tostring(role), 3)
    end
    return v
end

-- alpha, when given, replaces the role's alpha (0 hides a hover fill).
function Theme:Fill(tex, role, alpha)
    local c = look("fill", role)
    tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4])
end

function Theme:Tint(tex, role, color)
    local t = look("tint", role)
    tex:SetColorTexture(color.r * t[1], color.g * t[1], color.b * t[1], t[2])
end

function Theme:SetBackdrop(frame, role)
    frame:SetBackdrop(look("backdrop", role))
end

function Theme:BackdropColor(frame, role)
    local c = look("bg", role)
    frame:SetBackdropColor(c[1], c[2], c[3], c[4])
end

function Theme:BorderColor(frame, role)
    local c = look("border", role)
    frame:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
end
