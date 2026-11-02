----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/Theme.lua
-- One place for the colours and backdrops PB's windows draw with.
-- Every panel fill, row stripe, hover, divider and backdrop asks
-- Theme for its role by name instead of carrying its own numbers, so
-- a second look can replace the whole set at once. Modern is the look
-- PB has always had; Classic is Blizzard's TBC trainer look.
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
        barPane = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } },
        pane = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } },
        professionTabBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
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
        guildRowHover = { 0.3, 0.3, 0.5, 0.15 },
        historyRowEven = { 0.12, 0.12, 0.12, 0.5 },
        iconButtonHover = { 1, 1, 1, 0.25 },
        listBackground = { 0.05, 0.05, 0.05, 0.5 },
        menuHover = { 0.3, 0.3, 0.5, 0.5 },
        navTab = { 0.15, 0.15, 0.15, 0.9 },
        navTabBorder = { 0.4, 0.4, 0.4, 1 },
        navTabSelected = { 0.25, 0.25, 0.3, 1 },
        orderSectionHeader = { 0.18, 0.18, 0.22, 0.95 },
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

-- Classic: Blizzard's TBC trainer look. Every file here exists on both TBC
-- Classic Anniversary and WoW: Forever (wago.tools ManifestInterfaceData,
-- builds 2.5.6.69795 and 1.60.1.70658). The dialog border and dark dialog
-- background are Blizzard's BACKDROP_DIALOG_32_32 pieces, drawn at a smaller
-- edge so they fit the space PB's own borders take; hovers are the quest
-- log's highlight and the selected recipe is the trade skill window's own
-- highlight bar. A fill is a colour, or a file with a vertex colour.
STYLES.classic = {
    backdrop = {
        calcButtonBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
        -- Blizzard's BACKDROP_DIALOG_32_32 (Blizzard_SharedXML/Backdrop.lua),
        -- as its own popups use: the /pb bug and Battle.net windows keep
        -- 14 px or more between their edge and their content.
        dialog = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileEdge = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } },
        dialogBox = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
        dropdownButtonBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
        dropdownList = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
        input = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } },
        menu = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
        -- The craft and Request Craft bars keep the thinner edge: their
        -- buttons sit 4 px from it.
        barPane = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
        -- Edge 16, not Blizzard's 32: PB's panes keep their content 2 to 4 px
        -- from the edge (20 recipe rows fill 402 of the list's 404 px).
        pane = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } },
        professionTabBorder = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 },
    },
    bg = {
        craftBarPane = { 1, 1, 1, 0.9 },
        detailPane = { 1, 1, 1, 0.9 },
        dialog = { 1, 1, 1, 1 },
        dialogBox = { 0, 0, 0, 0.6 },
        dropdownList = { 1, 1, 1, 1 },
        input = { 0, 0, 0, 0.8 },
        menu = { 1, 1, 1, 1 },
        recipeListPane = { 1, 1, 1, 0.9 },
    },
    border = {
        calcButton = { 0.7, 0.6, 0.3, 0.8 },
        calcButtonActive = { 1, 0.82, 0, 1 },
        craftBarPane = { 1, 1, 1, 1 },
        detailPane = { 1, 1, 1, 1 },
        dialog = { 1, 1, 1, 1 },
        dialogBox = { 0.6, 0.6, 0.6, 1 },
        dropdownButton = { 0.6, 0.6, 0.6, 0.9 },
        dropdownList = { 1, 1, 1, 1 },
        input = { 0.6, 0.6, 0.6, 1 },
        menu = { 1, 1, 1, 1 },
        professionTab = { 0.6, 0.5, 0.25, 0.8 },
        professionTabActive = { 1, 0.82, 0, 1 },
        professionTabDim = { 0.4, 0.33, 0.15, 0.6 },
        recipeListPane = { 1, 1, 1, 1 },
    },
    fill = {
        bottomBar = { 0.25, 0.18, 0.08, 0.95 },   -- set apart from the panes above it
        calcButton = { 0.2, 0.15, 0.08, 0.9 },
        calcButtonActive = { 0.45, 0.33, 0.08, 0.95 },
        calcButtonHover = { 0.3, 0.22, 0.1, 0.9 },
        calcColumnDivider = { 0.6, 0.5, 0.25, 0.5 },
        calcRowDivider = { 0.6, 0.5, 0.25, 0.4 },
        characterRow = { 0.18, 0.14, 0.08, 0.8 },
        columnHeader = { 0.2, 0.16, 0.08, 0.85 },
        columnHeaderHover = { file = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD", color = { 1, 1, 1, 0.6 } },
        divider = { 0.6, 0.5, 0.25, 0.6 },
        dividerFaint = { 0.6, 0.5, 0.25, 0.35 },
        dropdownButton = { 0.08, 0.07, 0.05, 1 },
        guildRowHover = { file = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD", color = { 1, 1, 1, 0.4 } },
        historyRowEven = { 1, 0.85, 0.5, 0.06 },
        iconButtonHover = { 1, 1, 1, 0.25 },
        listBackground = { file = "Interface\\FrameGeneral\\UI-Background-Rock", tile = true, color = { 0.5, 0.5, 0.5, 1 } },
        menuHover = { file = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD", color = { 1, 1, 1, 1 } },
        navTab = { 0.2, 0.15, 0.08, 0.9 },
        navTabBorder = { 0.6, 0.5, 0.25, 1 },
        navTabSelected = { 0.45, 0.33, 0.08, 1 },
        orderSectionHeader = { 0.2, 0.16, 0.08, 0.85 },
        professionRowHover = { file = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD", color = { 1, 1, 1, 0.5 } },
        professionTab = { 0.18, 0.14, 0.08, 0.9 },
        professionTabActive = { 0.45, 0.33, 0.08, 0.95 },
        professionTabDim = { 0.1, 0.08, 0.05, 0.9 },
        professionTabSeparator = { 0, 0, 0, 0 },   -- no line: the gap between the tab groups stays
        recipeCategoryHeader = { 0, 0, 0, 0 },
        recipeRowHover = { file = "Interface\\QuestFrame\\UI-QuestTitleHighlight", blend = "ADD", color = { 1, 1, 1, 0.6 } },
        recipeRowSelected = { file = "Interface\\Buttons\\UI-Listbox-Highlight2", blend = "ADD", color = { 0.9, 0.9, 0.9, 1 } },
        rowEven = { 1, 0.85, 0.5, 0.08 },
        rowOdd = { 0, 0, 0, 0.15 },
        -- Blizzard's classic scroll knob (UIPanelScrollBarTemplate's ThumbTexture,
        -- Blizzard_SharedXML SecureScrollTemplates.xml), on no track.
        scrollThumb = { file = "Interface\\Buttons\\UI-ScrollBar-Knob", coords = { 0.20, 0.80, 0.125, 0.875 }, color = { 1, 1, 1, 1 } },
        scrollTrack = { 0, 0, 0, 0 },
        sectionDivider = { 0.6, 0.5, 0.2, 0.6 },
        settingsBackground = { 0.09, 0.08, 0.06, 1 },
        -- Blizzard: TradeSkillRankFrameBackground is white at 0.2 alpha,
        -- then SetVertexColor(0, 0, 0.75, 0.5): 0.2 x 0.5 = 0.1.
        skillBarBackground = { 0, 0, 0.75, 0.1 },
        statusPill = { 0.2, 0.15, 0.08, 0.9 },
    },
    -- Faction colours carry meaning: same tint as Modern.
    tint = {
        factionHeader = { 0.3, 0.9 },
        factionHeaderHover = { 0.4, 0.9 },
    },
}

-- The look in use, from settings.windowStyle. Match the game picks
-- Blizzard's own look for the client: the TBC trainer look (Classic) on TBC
-- Classic Anniversary; on WoW: Forever, Modern until Forever's own look
-- exists. The windows are built once, so the pick holds for the session:
-- it is read on first use (after the saved settings load) and kept.
local function resolve()
    local s = addon.db and addon.db.settings
    if not s then return nil end
    local pick = s.windowStyle or "modern"
    if pick == "game" then
        pick = (addon.Source and addon.Source.flavor == "classic") and "classic" or "modern"
    end
    if not STYLES[pick] then pick = "modern" end
    return pick
end

function Theme:Name()
    if not self._name then
        local name = resolve()
        if not name then return "modern" end   -- settings not loaded yet: do not keep
        self._name = name
    end
    return self._name
end

function Theme:Style()
    return STYLES[self:Name()]
end

function Theme:IsClassic()
    return self:Name() == "classic"
end

-- A new style applies after a reload: ask once, from the Settings dropdown.
function Theme:OfferReload()
    if not StaticPopupDialogs["PROFBUDDY_RELOAD_STYLE"] then
        StaticPopupDialogs["PROFBUDDY_RELOAD_STYLE"] = {
            text = "ProfessionBuddy's new window style applies after a reload. Reload now?",
            button1 = "Reload",
            button2 = "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("PROFBUDDY_RELOAD_STYLE")
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
    if c.file then
        tex:SetTexture(c.file, c.tile and "REPEAT" or nil, c.tile and "REPEAT" or nil)
        if c.tile then
            tex:SetHorizTile(true)
            tex:SetVertTile(true)
        end
        if c.coords then tex:SetTexCoord(c.coords[1], c.coords[2], c.coords[3], c.coords[4]) end
        tex:SetBlendMode(c.blend or "BLEND")
        local v = c.color
        tex:SetVertexColor(v[1], v[2], v[3], alpha or v[4])
    else
        tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4])
    end
end

function Theme:Tint(tex, role, color)
    local t = look("tint", role)
    tex:SetColorTexture(color.r * t[1], color.g * t[1], color.b * t[1], t[2])
end

function Theme:SetBackdrop(frame, role)
    frame:SetBackdrop(look("backdrop", role))
end

-- Classic: Blizzard's classic tab, as on its TBC Character window
-- (CharacterFrameTabButtonTemplate in Blizzard_FrameXML Classic/
-- CharacterFrameTemplates.xml, which the TBC client loads; the art exists on
-- both clients): UI-Character-InActiveTab in three pieces (20 px, the
-- middle, 20 px, all 32 tall), UI-Character-ActiveTab 4 px higher for the
-- selected tab, and UI-Character-Tab-RealHighlight on hover. The art's ends
-- are clear, so tabs set 15 px into each other sit side by side. The tab
-- draws 4 levels above its window, as the template does, so the selected
-- tab covers the window's bottom edge and joins the panel. Returns the
-- unselected and selected sets; showing a set also gives the label the
-- template's colour (gold, or white when selected) and height.
local function textureGroup(list, onShow)
    return {
        Show = function()
            for _, t in ipairs(list) do t:Show() end
            if onShow then onShow() end
        end,
        Hide = function() for _, t in ipairs(list) do t:Hide() end end,
    }
end
Theme.NO_TEXTURES = textureGroup({})

local TAB_ART = "Interface\\PaperDollInfoFrame\\UI-Character-"
function Theme:DrawClassicTab(btn)
    local width = btn:GetWidth()
    local function set(file, y)
        local L = btn:CreateTexture(nil, "BACKGROUND")
        L:SetTexture(TAB_ART .. file)
        L:SetTexCoord(0, 0.15625, 0, 1)
        L:SetSize(20, 32)
        L:SetPoint("TOPLEFT", 0, y)
        local Mid = btn:CreateTexture(nil, "BACKGROUND")
        Mid:SetTexture(TAB_ART .. file)
        Mid:SetTexCoord(0.15625, 0.84375, 0, 1)
        Mid:SetSize(width - 40, 32)
        Mid:SetPoint("LEFT", L, "RIGHT")
        local R = btn:CreateTexture(nil, "BACKGROUND")
        R:SetTexture(TAB_ART .. file)
        R:SetTexCoord(0.84375, 1, 0, 1)
        R:SetSize(20, 32)
        R:SetPoint("LEFT", Mid, "RIGHT")
        return { L, Mid, R }
    end
    local normal = set("InActiveTab", 0)
    local selected = set("ActiveTab", 4)
    btn:SetHighlightTexture(TAB_ART .. "Tab-RealHighlight", "ADD")
    local hl = btn:GetHighlightTexture()
    if hl then
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", 3, 5)
        hl:SetPoint("BOTTOMRIGHT", -3, 0)
    end
    btn.tabHighlight = hl
    btn:SetFrameLevel(btn:GetFrameLevel() + 4)
    -- Blizzard disables its selected tab, so it never lights on hover; PB's
    -- stays clickable, so the selected tab hides its highlight instead (lit,
    -- it would draw a line across the tab's join with the window).
    local function label(isSelected)
        if hl then hl:SetAlpha(isSelected and 0 or 1) end
        btn:SetNormalFontObject(isSelected and GameFontHighlightSmall or GameFontNormalSmall)
        local fs = btn:GetFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", 0, isSelected and 4 or 2)
        end
    end
    return textureGroup(normal, function() label(false) end),
           textureGroup(selected, function() label(true) end)
end

-- Classic: Blizzard's +/- expand button as an inline texture, for headers
-- drawn as text.
function Theme:ExpandIcon(collapsed)
    return (collapsed and "|TInterface\\Buttons\\UI-PlusButton-Up:14:14|t "
        or "|TInterface\\Buttons\\UI-MinusButton-Up:14:14|t ")
end

function Theme:BackdropColor(frame, role)
    local c = look("bg", role)
    frame:SetBackdropColor(c[1], c[2], c[3], c[4])
end

function Theme:BorderColor(frame, role)
    local c = look("border", role)
    frame:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
end
