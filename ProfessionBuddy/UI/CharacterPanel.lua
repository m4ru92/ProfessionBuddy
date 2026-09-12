----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/CharacterPanel.lua
-- Character overview: all alts, their professions, skill levels,
-- recipe counts, and inventory search
----------------------------------------------------------------------

local addon = ProfBuddy
local CP = addon:NewModule("CharacterPanel")

local DS   -- DataStore ref, set in Init
local RDB  -- RecipeDB ref

local ROW_HEIGHT = 20
local PROF_ROW_HEIGHT = 18
local RECIPE_ROW_HEIGHT = 16
local MAX_EXPANDED_RECIPES = 50  -- cap to avoid gigantic lists

----------------------------------------------------------------------
-- Profession icon paths
----------------------------------------------------------------------
local PROF_ICONS = {
    ["Alchemy"]         = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"]   = "Interface\\Icons\\Trade_BlackSmithing",
    ["Cooking"]         = "Interface\\Icons\\INV_Misc_Food_15",
    ["Enchanting"]      = "Interface\\Icons\\Trade_Engraving",
    ["Engineering"]     = "Interface\\Icons\\Trade_Engineering",
    ["First Aid"]       = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Herbalism"]       = "Interface\\Icons\\Trade_Herbalism",
    ["Jewelcrafting"]   = "Interface\\Icons\\INV_Misc_Gem_02",
    ["Leatherworking"]  = "Interface\\Icons\\Trade_LeatherWorking",
    ["Mining"]          = "Interface\\Icons\\Trade_Mining",
    ["Skinning"]        = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    ["Smelting"]        = "Interface\\Icons\\Spell_Fire_FlameBlades",
    ["Tailoring"]       = "Interface\\Icons\\Trade_Tailoring",
    ["Fishing"]         = "Interface\\Icons\\Trade_Fishing",
}

----------------------------------------------------------------------
-- Colors
----------------------------------------------------------------------
local COLORS = {
    header    = { r = 1, g = 0.82, b = 0 },        -- gold
    highlight = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 },
    green     = "|cff00ff00",
    yellow    = "|cffffff00",
    orange    = "|cffff8800",
    red       = "|cffff0000",
    white     = "|cffffffff",
    grey      = "|cff888888",
}

----------------------------------------------------------------------
-- Row pools
-- Frames and regions are never garbage collected, so the list is repainted
-- from per-shape pools instead of being rebuilt: ReleaseAll hides every
-- pooled object at the start of a refresh, each Acquire reuses the next
-- object of that shape and only creates one past the high-water mark. The
-- rows here are heterogeneous (buttons, frames, bare FontStrings, textures),
-- so each shape gets its own pool and they never mix. Nothing is ever
-- reparented to nil: that orphans the object instead of freeing it.
----------------------------------------------------------------------
CP._pools = {}

function CP:Acquire(kind, factory)
    local pool = self._pools[kind]
    if not pool then
        pool = { n = 0, objs = {} }
        self._pools[kind] = pool
    end
    pool.n = pool.n + 1
    local obj = pool.objs[pool.n]
    if not obj then
        obj = factory()
        pool.objs[pool.n] = obj
    end
    obj:Show()
    return obj
end

function CP:ReleaseAll()
    for _, pool in pairs(self._pools) do
        for i = 1, #pool.objs do
            pool.objs[i]:Hide()
        end
        pool.n = 0
    end
end

-- Bare text line (empty states, overflow and result counts).
function CP:AcquireLabel(text)
    local label = self:Acquire("label", function()
        local fs = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetTextColor(0.7, 0.7, 0.7)
        return fs
    end)
    label:ClearAllPoints()
    label:SetText(text)
    return label
end

----------------------------------------------------------------------
-- Item name cache. GetItemInfo is a C call that also queues a server item
-- query when the item is not cached client-side, and the search used to make
-- one call per stored item and one per static recipe on every keystroke.
-- Names never change, so a hit is kept for the session; a miss is not stored,
-- so the item is asked for again next search once the client has it.
----------------------------------------------------------------------
CP._itemNames = {}        -- itemID -> display name
CP._itemNamesLower = {}   -- itemID -> lowercased name

function CP:ItemName(itemID)
    local name = self._itemNames[itemID]
    if name then return name, self._itemNamesLower[itemID] end
    name = GetItemInfo(itemID)
    if not name then return nil, nil end
    self._itemNames[itemID] = name
    self._itemNamesLower[itemID] = name:lower()
    return name, self._itemNamesLower[itemID]
end

-- Section title inside the search results.
function CP:AcquireSectionHeader(text)
    local fs = self:Acquire("sectionHeader", function()
        local f = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f:SetTextColor(COLORS.header.r, COLORS.header.g, COLORS.header.b)
        return f
    end)
    fs:ClearAllPoints()
    fs:SetText(text)
    return fs
end

-- Hairline under a section title.
function CP:AcquireDivider()
    local tex = self:Acquire("divider", function()
        local t = self.scrollChild:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(0.4, 0.35, 0.1, 0.6)
        return t
    end)
    tex:ClearAllPoints()
    tex:SetSize(self.scrollChild:GetWidth() - 10, 1)
    return tex
end

-- Remote peers pick the profession names in their own payload, so a modified
-- client can file junk under db.characters. Only professions PB knows about
-- are rendered.
local function isKnownProf(profName)
    if PROF_ICONS[profName] then return true end
    return (addon.CRAFTABLE_PROFS and addon.CRAFTABLE_PROFS[profName]) and true or false
end

----------------------------------------------------------------------
-- Init: register as a tab on the main UI
----------------------------------------------------------------------
function CP:Init()
    DS  = addon.DataStore
    RDB = addon.RecipeDB

    -- Register our tab
    if addon.UI and addon.UI.AddTab then
        addon.UI:AddTab("characters", "Characters", function(parent)
            self:CreateContent(parent)
        end)
    end
end

-- Toggle (called from slash command /pb or /pb chars, and the bottom
-- nav strip on the profession window)
function CP:Toggle()
    if not addon.UI then return end

    local function selectCharacters()
        for i, tab in ipairs(addon.UI.frame.tabs) do
            if tab.name == "characters" then
                addon.UI:SelectTab(i)
                break
            end
        end
    end

    -- If a profession window is open (e.g. clicked from the bottom nav
    -- strip), close it and show the main window on Characters, rather
    -- than toggling the main window closed (which would leave the
    -- profession window covering it). Mirrors FriendsPanel/OrdersPanel.
    local tsf = addon.TradeSkillFrame
    if tsf and tsf.frame and tsf.frame:IsShown() then
        tsf:Hide()
        addon.UI:Show()
        selectCharacters()
        return
    end

    -- Otherwise behave as a normal open/close toggle
    if addon.UI.frame:IsShown() then
        addon.UI:Hide()
    else
        addon.UI:Show()
        selectCharacters()
    end
end

----------------------------------------------------------------------
-- Build the content inside our tab frame
----------------------------------------------------------------------
function CP:CreateContent(parent)
    self.parent = parent

    -- Header row
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetText("Character Overview")
    header:SetTextColor(COLORS.header.r, COLORS.header.g, COLORS.header.b)

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    searchBox:SetSize(180, 20)
    searchBox:SetPoint("TOP", 0, -5)
    searchBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    searchBox:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
    searchBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    searchBox:SetTextInsets(6, 6, 2, 2)
    searchBox:SetFontObject(GameFontNormalSmall)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    searchBox:SetText("")

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText("|cff666666Search recipes / items...|r")
    self._searchPlaceholder = placeholder

    searchBox:SetScript("OnTextChanged", function(eb, userInput)
        if userInput then
            local text = eb:GetText()
            if text == "" then
                self._searchPlaceholder:Show()
            else
                self._searchPlaceholder:Hide()
            end
            self._searchText = text:lower()
            -- Debounce: a search walks every stored inventory and the whole
            -- static recipe DB, so it runs once the typing stops, not once
            -- per keystroke.
            self:QueueSearch()
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(eb)
        -- Keep the typed term (the other panels do) and close the window, so
        -- one Escape closes it from here as it does from anywhere else.
        eb:ClearFocus()
        if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() then
            addon.UI:Hide()
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
    end)
    searchBox:SetScript("OnEditFocusGained", function(eb)
        eb:HighlightText()
        if eb:GetText() == "" then
            self._searchPlaceholder:Show()
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(eb)
        eb:HighlightText(0, 0)
        if eb:GetText() == "" then
            self._searchPlaceholder:Show()
        end
    end)
    self._searchBox = searchBox

    -- Clear search focus when clicking the panel background. No OnLeave
    -- clear: OnLeave fires whenever the cursor moves onto any mouse-enabled
    -- child, so it dropped focus mid-word as soon as the mouse crossed a row.
    parent:EnableMouse(true)
    parent:SetScript("OnMouseDown", function()
        if searchBox:HasFocus() then searchBox:ClearFocus() end
    end)

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 22)
    refreshBtn:SetPoint("TOPRIGHT", -5, -2)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        if addon.Scanner then
            addon.Scanner:ScanProfessions()
            addon.Scanner:ScanInventory()
        end
        self:Refresh()
    end)

    -- Scroll frame for character list
    local scrollFrame = CreateFrame("ScrollFrame", "ProfBuddyCPScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 5)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- dynamically sized
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollChild = scrollChild

    -- Attach refresh method to parent so the tab system can call it. The
    -- content frame's OnShow hook drives every repaint, first paint included.
    parent.Refresh = function() self:Refresh() end
end

----------------------------------------------------------------------
-- Refresh the character list
----------------------------------------------------------------------
CP._factionCollapsed = {}
CP._searchFactionCollapsed = {}  -- separate state for search results
CP._profExpanded = {}  -- keyed by "charKey:profName"

-- Coalesce keystrokes into one search. Each new character cancels the
-- pending run, so the walk happens 0.3 s after the last key, not per key.
function CP:QueueSearch()
    if self._searchTimer then
        self._searchTimer:Cancel()
        self._searchTimer = nil
    end
    self._searchTimer = C_Timer.NewTimer(0.3, function()
        self._searchTimer = nil
        self:Refresh()
    end)
end

function CP:Refresh()
    if not self.scrollChild then return end

    -- Hide every pooled row; the passes below re-acquire what they need.
    self:ReleaseAll()

    local characters = DS:GetAllCharacters()

    -- Search mode: show recipe/item matches across all alts
    if self._searchText and self._searchText ~= "" and characters and next(characters) then
        self:RefreshSearchResults(characters)
        return
    end

    if not characters or not next(characters) then
        local empty = self:AcquireLabel("No character data yet. Open your professions on each character to scan them.")
        empty:SetPoint("TOPLEFT", 10, -10)
        self.scrollChild:SetHeight(30)
        return
    end

    local currentKey = addon:PlayerKey()
    local currentChar = DS:GetCharacter(currentKey)
    local currentFaction = currentChar and currentChar.faction or "Alliance"

    -- Group characters by faction (local alts) and friends (remote)
    local factions = {}
    local friends = {}
    for key, data in pairs(characters) do
        if data.isRemote then
            table.insert(friends, { key = key, data = data })
        else
            local faction = data.faction or "Unknown"
            if not factions[faction] then factions[faction] = {} end
            table.insert(factions[faction], { key = key, data = data })
        end
    end

    -- Sort within each faction: current character first, then alphabetical
    for _, chars in pairs(factions) do
        table.sort(chars, function(a, b)
            -- The equality case first: without it comp(x, x) is true for the
            -- current character, which breaks the strict weak ordering
            -- table.sort requires.
            if a.key == b.key then return false end
            if a.key == currentKey then return true end
            if b.key == currentKey then return false end
            return a.key < b.key
        end)
    end
    table.sort(friends, function(a, b) return a.key < b.key end)

    -- Build ordered faction list: current faction first, then others
    local factionOrder = {}
    if factions[currentFaction] then
        table.insert(factionOrder, currentFaction)
    end
    for faction, _ in pairs(factions) do
        if faction ~= currentFaction then
            table.insert(factionOrder, faction)
        end
    end
    -- Add "Friends" as a pseudo-faction if we have any
    if #friends > 0 then
        factions["Friends"] = friends
        table.insert(factionOrder, "Friends")
    end

    -- Default collapse state: current faction expanded, others collapsed
    for _, faction in ipairs(factionOrder) do
        if self._factionCollapsed[faction] == nil then
            self._factionCollapsed[faction] = (faction ~= currentFaction)
        end
    end

    local yOffset = 0

    for _, faction in ipairs(factionOrder) do
        local chars = factions[faction]
        local isCollapsed = self._factionCollapsed[faction]

        -- Faction header
        local factionRow = self:CreateFactionHeader(faction, #chars, isCollapsed, yOffset)
        yOffset = yOffset - ROW_HEIGHT - 4

        if not isCollapsed then
            for _, entry in ipairs(chars) do
                local charKey = entry.key
                local charData = entry.data
                local isCurrent = (charKey == currentKey)

                -- Character header row
                self:CreateCharacterRow(charKey, charData, isCurrent, yOffset)
                yOffset = yOffset - ROW_HEIGHT - 2

                -- Profession sub-rows
                if charData.professions then
                    local profsSorted = {}
                    for profName, profData in pairs(charData.professions) do
                        if isKnownProf(profName) then
                            table.insert(profsSorted, { name = profName, data = profData })
                        end
                    end
                    table.sort(profsSorted, function(a, b) return a.name < b.name end)

                    for _, prof in ipairs(profsSorted) do
                        local expandKey = charKey .. ":" .. prof.name
                        local isExpanded = self._profExpanded[expandKey]
                        self:CreateProfessionRow(charKey, prof.name, prof.data, yOffset, isExpanded)
                        yOffset = yOffset - PROF_ROW_HEIGHT - 1

                        -- Render expanded recipe list
                        if isExpanded then
                            yOffset = self:RenderExpandedRecipes(charKey, prof.name, prof.data, yOffset)
                        end
                    end
                end

                -- Spacing between characters
                yOffset = yOffset - 8
            end
        end

        -- Spacing between faction groups
        yOffset = yOffset - 4
    end

    self.scrollChild:SetHeight(math.abs(yOffset) + 20)
end

----------------------------------------------------------------------
-- Create a faction header (collapsible)
----------------------------------------------------------------------
local FACTION_COLORS = {
    Alliance = { r = 0.3, g = 0.5, b = 1.0 },
    Horde    = { r = 0.8, g = 0.2, b = 0.2 },
    Unknown  = { r = 0.6, g = 0.6, b = 0.6 },
}

function CP:CreateFactionHeader(faction, charCount, isCollapsed, yOffset)
    -- Pooled: the scripts read the row's own state so one button serves any
    -- faction it is reused for.
    local row = self:Acquire("factionHeader", function()
        local f = CreateFrame("Button", nil, self.scrollChild)

        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()

        f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.nameText:SetPoint("LEFT", 5, 0)

        f:SetScript("OnClick", function(b)
            self._factionCollapsed[b._faction] = not self._factionCollapsed[b._faction]
            self:Refresh()
        end)
        f:SetScript("OnEnter", function(b)
            local c = b._fc
            b.bg:SetColorTexture(c.r * 0.4, c.g * 0.4, c.b * 0.4, 0.9)
        end)
        f:SetScript("OnLeave", function(b)
            local c = b._fc
            b.bg:SetColorTexture(c.r * 0.3, c.g * 0.3, c.b * 0.3, 0.9)
        end)
        return f
    end)

    row:SetSize(self.scrollChild:GetWidth() - 10, ROW_HEIGHT)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, yOffset)

    local fc = FACTION_COLORS[faction] or FACTION_COLORS.Unknown
    row._faction = faction
    row._fc = fc
    row.bg:SetColorTexture(fc.r * 0.3, fc.g * 0.3, fc.b * 0.3, 0.9)

    -- Collapse arrow + faction name + count
    local arrow = isCollapsed and "+ " or "- "
    row.nameText:SetText(arrow .. faction .. "  " .. COLORS.grey .. "(" .. charCount .. ")|r")
    row.nameText:SetTextColor(fc.r, fc.g, fc.b)

    return row
end

----------------------------------------------------------------------
-- Create a character header row
----------------------------------------------------------------------
function CP:CreateCharacterRow(charKey, charData, isCurrent, yOffset)
    local row = self:Acquire("charRow", function()
        local f = CreateFrame("Frame", nil, self.scrollChild)

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

        f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.nameText:SetPoint("LEFT", 5, 0)

        f.levelText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.levelText:SetPoint("RIGHT", -5, 0)

        f.scanText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.scanText:SetPoint("RIGHT", -50, 0)
        return f
    end)

    row:SetSize(self.scrollChild:GetWidth() - 10, ROW_HEIGHT)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, yOffset)

    -- Character name with class color
    local classColor = addon:ClassColor(charData.class or "WARRIOR")
    local name = addon:ShortName(charKey)
    if isCurrent then
        name = name .. " " .. COLORS.green .. "(you)|r"
    elseif charData.isRemote then
        name = name .. " " .. COLORS.grey .. "(friend)|r"
    end
    row.nameText:SetText(classColor .. name .. "|r")

    -- Level
    row.levelText:SetText(COLORS.grey .. "Lv " .. (charData.level or "?") .. "|r")

    -- Last scan time
    if charData.lastScan and charData.lastScan > 0 then
        row.scanText:SetText(COLORS.grey .. self:TimeAgo(charData.lastScan) .. "|r")
        row.scanText:Show()
    else
        row.scanText:Hide()
    end

    return row
end

----------------------------------------------------------------------
-- Create a profession sub-row
----------------------------------------------------------------------
function CP:CreateProfessionRow(charKey, profName, profData, yOffset, isExpanded)
    local row = self:Acquire("profRow", function()
        local f = CreateFrame("Button", nil, self.scrollChild)

        f.highlight = f:CreateTexture(nil, "BACKGROUND")
        f.highlight:SetAllPoints()

        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(14, 14)
        f.icon:SetPoint("LEFT", 5, 0)
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        f.nameText   = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.skillText  = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.skillText:SetPoint("LEFT", 175, 0)
        f.recipeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.recipeText:SetPoint("LEFT", 260, 0)

        f:SetScript("OnEnter", function(b)
            b.highlight:SetColorTexture(COLORS.highlight.r, COLORS.highlight.g, COLORS.highlight.b, COLORS.highlight.a)
            self:ShowProfessionTooltip(b, b._charKey, b._profName, b._profData)
        end)
        f:SetScript("OnLeave", function(b)
            b.highlight:SetColorTexture(COLORS.highlight.r, COLORS.highlight.g, COLORS.highlight.b, 0)
            GameTooltip:Hide()
        end)
        f:SetScript("OnClick", function(b)
            local expandKey = b._charKey .. ":" .. b._profName
            self._profExpanded[expandKey] = not self._profExpanded[expandKey]
            self:Refresh()
        end)

        -- "View" button -- opens the PB profession window for this character.
        -- Only shown for professions with a recipe list to open.
        local viewBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        viewBtn:SetSize(36, 16)
        viewBtn:SetPoint("RIGHT", -2, 0)
        viewBtn:SetText("View")
        viewBtn:SetNormalFontObject(GameFontNormalSmall)
        viewBtn:SetHighlightFontObject(GameFontHighlightSmall)
        viewBtn:SetScript("OnClick", function()
            if addon.TradeSkillFrame then
                addon.TradeSkillFrame:OpenWithCharacter(f._charKey, f._profName)
            end
        end)
        viewBtn:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText("View " .. addon:ShortName(f._charKey) .. "'s " .. f._profName)
            GameTooltip:Show()
        end)
        viewBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        f.viewBtn = viewBtn
        return f
    end)

    row:SetSize(self.scrollChild:GetWidth() - 10, PROF_ROW_HEIGHT)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 15, yOffset)
    row._charKey  = charKey
    row._profName = profName
    row._profData = profData
    row.highlight:SetColorTexture(COLORS.highlight.r, COLORS.highlight.g, COLORS.highlight.b, 0)

    -- Profession icon
    local xCursor = 5
    local iconPath = PROF_ICONS[profName]
    if iconPath then
        row.icon:SetTexture(iconPath)
        row.icon:Show()
        xCursor = xCursor + 17
    else
        row.icon:Hide()
    end

    -- Expand/collapse arrow + profession name
    local arrow = isExpanded and "- " or "+ "
    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", xCursor, 0)
    row.nameText:SetText(COLORS.grey .. arrow .. "|r" .. profName)

    -- Skill level with color coding
    local skill = profData.skillLevel or 0
    local maxSkill = profData.maxSkill or 375
    row.skillText:SetText(self:SkillColor(skill, maxSkill) .. skill .. "/" .. maxSkill .. "|r")

    -- Recipe count
    local recipeCount = 0
    if profData.recipes then
        for _ in pairs(profData.recipes) do
            recipeCount = recipeCount + 1
        end
    end

    -- Unknown recipe count (if we have static data)
    local hasStatic = (RDB and RDB.data[profName]) and true or false
    local unknownCount = 0
    if hasStatic then
        local unknown = RDB:GetUnknownRecipes(charKey, profName)
        for _ in pairs(unknown) do
            unknownCount = unknownCount + 1
        end
    end

    if recipeCount > 0 then
        local str = COLORS.white .. recipeCount .. " recipes|r"
        if unknownCount > 0 then
            str = str .. "  " .. COLORS.orange .. unknownCount .. " missing|r"
        end
        row.recipeText:SetText(str)
    else
        -- Covers both an unscanned profession and a guildmate whose summary
        -- arrived before their recipes did.
        row.recipeText:SetText(COLORS.grey .. "no recipes yet|r")
    end

    -- Gathering professions have no recipe list, so no dead View button.
    row.viewBtn:SetShown(hasStatic)

    return row
end

----------------------------------------------------------------------
-- Profession tooltip on hover
----------------------------------------------------------------------
function CP:ShowProfessionTooltip(anchor, charKey, profName, profData)
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:SetText(profName, COLORS.header.r, COLORS.header.g, COLORS.header.b)

    local skill = profData.skillLevel or 0
    local maxSkill = profData.maxSkill or 375
    GameTooltip:AddLine("Skill: " .. skill .. " / " .. maxSkill, 1, 1, 1)

    -- Recipe breakdown by difficulty
    if profData.recipes then
        local counts = { optimal = 0, medium = 0, easy = 0, trivial = 0, other = 0 }
        for _, recipe in pairs(profData.recipes) do
            local diff = recipe.difficulty or "other"
            counts[diff] = (counts[diff] or 0) + 1
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Known Recipes:")
        if counts.optimal > 0 then
            GameTooltip:AddLine("  Orange: " .. counts.optimal, 1, 0.5, 0.25)
        end
        if counts.medium > 0 then
            GameTooltip:AddLine("  Yellow: " .. counts.medium, 1, 1, 0)
        end
        if counts.easy > 0 then
            GameTooltip:AddLine("  Green: " .. counts.easy, 0.25, 0.75, 0.25)
        end
        if counts.trivial > 0 then
            GameTooltip:AddLine("  Grey: " .. counts.trivial, 0.5, 0.5, 0.5)
        end
    end

    -- Unknown recipes summary
    if RDB and RDB.data[profName] then
        local unknown = RDB:GetUnknownRecipes(charKey, profName)
        local bySource = {}
        for recipeName, info in pairs(unknown) do
            local src = info.source or "unknown"
            bySource[src] = (bySource[src] or 0) + 1
        end

        if next(bySource) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Missing Recipes:")
            for src, count in pairs(bySource) do
                GameTooltip:AddLine("  " .. src .. ": " .. count, 1, 0.5, 0)
            end
        end
    end

    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Expanded profession recipe list (inline below the profession row)
----------------------------------------------------------------------
local DIFF_ROW_COLORS = {
    optimal = { r = 1.0, g = 0.5, b = 0.25 },
    medium  = { r = 1.0, g = 1.0, b = 0.0 },
    easy    = { r = 0.25, g = 0.75, b = 0.25 },
    trivial = { r = 0.5, g = 0.5, b = 0.5 },
}

function CP:RenderExpandedRecipes(charKey, profName, profData, yOffset)
    if not profData.recipes then return yOffset end

    -- Static recipe data for icons and tooltips
    local staticProf = RDB and RDB.data[profName] or {}

    -- Build sorted recipe list
    local recipeList = {}
    for recipeName, recipeInfo in pairs(profData.recipes) do
        local diff = "trivial"
        if type(recipeInfo) == "table" then
            diff = recipeInfo.difficulty or "trivial"
        end
        local staticInfo = staticProf[recipeName]
        local itemID = staticInfo and staticInfo.itemID or nil
        table.insert(recipeList, {
            name = recipeName,
            difficulty = diff,
            itemID = itemID,
        })
    end

    -- Sort by difficulty priority then name
    local DIFF_SORT = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
    table.sort(recipeList, function(a, b)
        local da = DIFF_SORT[a.difficulty] or 5
        local db = DIFF_SORT[b.difficulty] or 5
        if da ~= db then return da < db end
        return a.name < b.name
    end)

    -- Cap display
    local total = #recipeList
    local capped = total > MAX_EXPANDED_RECIPES
    local displayCount = capped and MAX_EXPANDED_RECIPES or total

    for i = 1, displayCount do
        local recipe = recipeList[i]
        local recipeRow = self:Acquire("recipeRow", function()
            local f = CreateFrame("Frame", nil, self.scrollChild)

            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetSize(14, 14)
            f.icon:SetPoint("LEFT", 5, 0)
            f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

            f:EnableMouse(true)
            f:SetScript("OnEnter", function(r)
                if not r._itemID then return end
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. r._itemID)
                GameTooltip:Show()
            end)
            f:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            return f
        end)

        recipeRow:SetSize(self.scrollChild:GetWidth() - 40, RECIPE_ROW_HEIGHT)
        recipeRow:ClearAllPoints()
        recipeRow:SetPoint("TOPLEFT", 30, yOffset)

        local dc = DIFF_ROW_COLORS[recipe.difficulty] or DIFF_ROW_COLORS.trivial
        local xCursor = 5

        -- Item icon. GetItemIcon may need the item to be cached; fall back to
        -- a question mark if it is not available yet.
        if recipe.itemID and recipe.itemID > 0 then
            recipeRow._itemID = recipe.itemID
            recipeRow.icon:SetTexture(GetItemIcon(recipe.itemID)
                or "Interface\\Icons\\INV_Misc_QuestionMark")
            recipeRow.icon:Show()
            xCursor = xCursor + 17
        else
            recipeRow._itemID = nil
            recipeRow.icon:Hide()
        end

        -- Recipe name
        recipeRow.nameText:ClearAllPoints()
        recipeRow.nameText:SetPoint("LEFT", xCursor, 0)
        recipeRow.nameText:SetText(recipe.name)
        recipeRow.nameText:SetTextColor(dc.r, dc.g, dc.b)

        yOffset = yOffset - RECIPE_ROW_HEIGHT - 1
    end

    -- Overflow indicator
    if capped then
        local moreLabel = self:AcquireLabel(
            COLORS.grey .. "... and " .. (total - MAX_EXPANDED_RECIPES) .. " more|r")
        moreLabel:SetPoint("TOPLEFT", 35, yOffset)
        yOffset = yOffset - RECIPE_ROW_HEIGHT - 1
    end

    return yOffset
end

----------------------------------------------------------------------
-- Search: find recipes/items across all alts
----------------------------------------------------------------------
function CP:RefreshSearchResults(characters)
    local query = self._searchText
    local currentKey = addon:PlayerKey()
    local currentChar = DS:GetCharacter(currentKey)
    local currentFaction = currentChar and currentChar.faction
    local showCrossFaction = addon.db.settings.showCrossFactionAlts
    local profAliases = { Smelting = "Mining" }

    -- ── INVENTORY SEARCH ──
    local invResults = {}
    for charKey, charData in pairs(characters) do
        if not showCrossFaction and charData.faction ~= currentFaction then
            -- skip
        elseif charData.inventory then
            local bags = charData.inventory.bags or {}
            local bank = charData.inventory.bank or {}

            -- Search bags
            for itemID, count in pairs(bags) do
                local itemName, itemLower = self:ItemName(itemID)
                if itemName and itemLower:find(query, 1, true) and count > 0 then
                    table.insert(invResults, {
                        charKey = charKey,
                        charData = charData,
                        itemName = itemName,
                        count = count,
                        location = "bags",
                        isCurrent = (charKey == currentKey),
                    })
                end
            end

            -- Search bank
            for itemID, count in pairs(bank) do
                local itemName, itemLower = self:ItemName(itemID)
                if itemName and itemLower:find(query, 1, true) and count > 0 then
                    -- Check if already found in bags (combine)
                    local found = false
                    for _, existing in ipairs(invResults) do
                        if existing.charKey == charKey and existing.itemName == itemName then
                            existing.bankCount = count
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(invResults, {
                            charKey = charKey,
                            charData = charData,
                            itemName = itemName,
                            count = 0,
                            bankCount = count,
                            location = "bank",
                            isCurrent = (charKey == currentKey),
                        })
                    end
                end
            end
        end
    end

    -- Sort inventory: current first, then by character, then item name
    table.sort(invResults, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent end
        if a.charKey ~= b.charKey then return a.charKey < b.charKey end
        return a.itemName < b.itemName
    end)

    -- ── RECIPE/CRAFT SEARCH ──
    local craftResults = {}

    -- Search through all characters' known recipes by recipe name
    for charKey, charData in pairs(characters) do
        if not showCrossFaction and charData.faction ~= currentFaction then
            -- skip
        elseif charData.professions then
            for profName, profData in pairs(charData.professions) do
                if isKnownProf(profName) and profData.recipes then
                    for recipeName, _ in pairs(profData.recipes) do
                        if recipeName:lower():find(query, 1, true) then
                            table.insert(craftResults, {
                                charKey = charKey,
                                charData = charData,
                                profName = profName,
                                recipeName = recipeName,
                                skill = profData.skillLevel or 0,
                                isCurrent = (charKey == currentKey),
                            })
                        end
                    end
                end
            end
        end
    end

    -- Also search static DB for item names that match (recipe produces the item)
    if RDB and RDB.data then
        for profName, recipes in pairs(RDB.data) do
            for recipeName, info in pairs(recipes) do
                if info.itemID then
                    local itemName, itemLower = self:ItemName(info.itemID)
                    if itemName and itemLower:find(query, 1, true)
                       and not recipeName:lower():find(query, 1, true) then
                        for charKey, charData in pairs(characters) do
                            if (showCrossFaction or charData.faction == currentFaction) and charData.professions then
                                local profsToCheck = { profName }
                                if profAliases[profName] then
                                    table.insert(profsToCheck, profAliases[profName])
                                end
                                for _, pName in ipairs(profsToCheck) do
                                    local profData = charData.professions[pName]
                                    if profData and profData.recipes and profData.recipes[recipeName] then
                                        table.insert(craftResults, {
                                            charKey = charKey,
                                            charData = charData,
                                            profName = profName,
                                            recipeName = recipeName,
                                            itemName = itemName,
                                            skill = profData.skillLevel or 0,
                                            isCurrent = (charKey == currentKey),
                                        })
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Deduplicate craft results
    local seen = {}
    local unique = {}
    for _, r in ipairs(craftResults) do
        local key = r.charKey .. ":" .. r.profName .. ":" .. r.recipeName
        if not seen[key] then
            seen[key] = true
            table.insert(unique, r)
        end
    end
    craftResults = unique

    -- Sort craft results: current first, then by character, then recipe
    table.sort(craftResults, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent end
        if a.charKey ~= b.charKey then return a.charKey < b.charKey end
        return a.recipeName < b.recipeName
    end)

    -- ── RENDER ──
    local yOffset = 0
    local totalResults = #invResults + #craftResults

    if totalResults == 0 then
        local noResults = self:AcquireLabel("No results found.")
        noResults:SetPoint("TOPLEFT", 10, yOffset)
        self.scrollChild:SetHeight(30)
        return
    end

    -- Helper: group results by faction, then by character
    local function groupByFaction(results)
        local groups = {}
        for _, r in ipairs(results) do
            local faction = r.charData.faction or "Unknown"
            if not groups[faction] then groups[faction] = {} end
            table.insert(groups[faction], r)
        end
        return groups
    end

    -- Helper: get ordered faction list (current first)
    local function getFactionOrder(groups)
        local order = {}
        if groups[currentFaction] then
            table.insert(order, currentFaction)
        end
        for faction, _ in pairs(groups) do
            if faction ~= currentFaction then
                table.insert(order, faction)
            end
        end
        return order
    end

    -- Helper: render a search faction header
    local function renderSearchFactionHeader(faction, count, collapseKey, yOff)
        local isCollapsed = self._searchFactionCollapsed[collapseKey]
        if isCollapsed == nil then
            isCollapsed = (faction ~= currentFaction)
            self._searchFactionCollapsed[collapseKey] = isCollapsed
        end

        local fRow = self:Acquire("searchFactionHeader", function()
            local f = CreateFrame("Button", nil, self.scrollChild)

            f.bg = f:CreateTexture(nil, "BACKGROUND")
            f.bg:SetAllPoints()

            f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f.nameText:SetPoint("LEFT", 5, 0)

            f:SetScript("OnClick", function(b)
                self._searchFactionCollapsed[b._collapseKey] = not self._searchFactionCollapsed[b._collapseKey]
                self:Refresh()
            end)
            f:SetScript("OnEnter", function(b)
                local c = b._fc
                b.bg:SetColorTexture(c.r * 0.4, c.g * 0.4, c.b * 0.4, 0.9)
            end)
            f:SetScript("OnLeave", function(b)
                local c = b._fc
                b.bg:SetColorTexture(c.r * 0.3, c.g * 0.3, c.b * 0.3, 0.9)
            end)
            return f
        end)

        fRow:SetSize(self.scrollChild:GetWidth() - 20, ROW_HEIGHT)
        fRow:ClearAllPoints()
        fRow:SetPoint("TOPLEFT", 10, yOff)

        local fc = FACTION_COLORS[faction] or FACTION_COLORS.Unknown
        fRow._fc = fc
        fRow._collapseKey = collapseKey
        fRow.bg:SetColorTexture(fc.r * 0.3, fc.g * 0.3, fc.b * 0.3, 0.9)

        local arrow = isCollapsed and "+ " or "- "
        fRow.nameText:SetText(arrow .. faction .. "  " .. COLORS.grey .. "(" .. count .. ")|r")
        fRow.nameText:SetTextColor(fc.r, fc.g, fc.b)

        return isCollapsed
    end

    -- Helper: the "Character" band that heads each character's results
    local function renderResultCharRow(r, yOff)
        local charRow = self:Acquire("searchCharRow", function()
            local f = CreateFrame("Frame", nil, self.scrollChild)
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f.nameText:SetPoint("LEFT", 5, 0)
            return f
        end)
        charRow:SetSize(self.scrollChild:GetWidth() - 30, ROW_HEIGHT)
        charRow:ClearAllPoints()
        charRow:SetPoint("TOPLEFT", 20, yOff)

        local classColor = addon:ClassColor(r.charData.class or "WARRIOR")
        local suffix = r.isCurrent and " " .. COLORS.green .. "(you)|r" or ""
        charRow.nameText:SetText(classColor .. addon:ShortName(r.charKey) .. "|r" .. suffix)
        return charRow
    end

    -- Inventory section
    if #invResults > 0 then
        self:AcquireSectionHeader("Has in inventory"):SetPoint("TOPLEFT", 5, yOffset)
        yOffset = yOffset - 18

        self:AcquireDivider():SetPoint("TOPLEFT", 5, yOffset)
        yOffset = yOffset - 6

        local factionGroups = groupByFaction(invResults)
        local factionOrder = getFactionOrder(factionGroups)

        for _, faction in ipairs(factionOrder) do
            local factionResults = factionGroups[faction]

            -- Count unique characters in this faction
            local charSet = {}
            for _, r in ipairs(factionResults) do charSet[r.charKey] = true end
            local charCount = 0
            for _ in pairs(charSet) do charCount = charCount + 1 end

            local collapseKey = "inv:" .. faction
            local isCollapsed = renderSearchFactionHeader(faction, charCount, collapseKey, yOffset)
            yOffset = yOffset - ROW_HEIGHT - 2

            if not isCollapsed then
                local lastChar = nil
                for _, r in ipairs(factionResults) do
                    if r.charKey ~= lastChar then
                        lastChar = r.charKey
                        renderResultCharRow(r, yOffset)
                        yOffset = yOffset - ROW_HEIGHT - 2
                    end

                    -- Item row
                    local itemRow = self:Acquire("itemRow", function()
                        local f = CreateFrame("Frame", nil, self.scrollChild)
                        f.itemText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        f.itemText:SetPoint("LEFT", 5, 0)
                        f.countText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        f.countText:SetPoint("RIGHT", -5, 0)
                        return f
                    end)
                    itemRow:SetSize(self.scrollChild:GetWidth() - 40, PROF_ROW_HEIGHT)
                    itemRow:ClearAllPoints()
                    itemRow:SetPoint("TOPLEFT", 30, yOffset)
                    itemRow.itemText:SetText(r.itemName)

                    -- Count display
                    local countStr = ""
                    local bagCount = r.count or 0
                    local bankCount = r.bankCount or 0
                    if bagCount > 0 and bankCount > 0 then
                        countStr = COLORS.green .. "x" .. bagCount .. "|r " .. COLORS.grey .. "(bags)|r  " .. COLORS.yellow .. "x" .. bankCount .. "|r " .. COLORS.grey .. "(bank)|r"
                    elseif bagCount > 0 then
                        countStr = COLORS.green .. "x" .. bagCount .. "|r " .. COLORS.grey .. "(bags)|r"
                    else
                        countStr = COLORS.yellow .. "x" .. bankCount .. "|r " .. COLORS.grey .. "(bank)|r"
                    end

                    itemRow.countText:SetText(countStr)

                    yOffset = yOffset - PROF_ROW_HEIGHT - 1
                end
            end

            yOffset = yOffset - 4
        end

        yOffset = yOffset - 6
    end

    -- Craft section
    if #craftResults > 0 then
        self:AcquireSectionHeader("Can craft"):SetPoint("TOPLEFT", 5, yOffset)
        yOffset = yOffset - 18

        self:AcquireDivider():SetPoint("TOPLEFT", 5, yOffset)
        yOffset = yOffset - 6

        local factionGroups = groupByFaction(craftResults)
        local factionOrder = getFactionOrder(factionGroups)

        for _, faction in ipairs(factionOrder) do
            local factionResults = factionGroups[faction]

            local charSet = {}
            for _, r in ipairs(factionResults) do charSet[r.charKey] = true end
            local charCount = 0
            for _ in pairs(charSet) do charCount = charCount + 1 end

            local collapseKey = "craft:" .. faction
            local isCollapsed = renderSearchFactionHeader(faction, charCount, collapseKey, yOffset)
            yOffset = yOffset - ROW_HEIGHT - 2

            if not isCollapsed then
                local lastChar = nil
                for _, r in ipairs(factionResults) do
                    if r.charKey ~= lastChar then
                        lastChar = r.charKey
                        renderResultCharRow(r, yOffset)
                        yOffset = yOffset - ROW_HEIGHT - 2
                    end

                    -- Recipe row
                    local recipeRow = self:Acquire("searchRecipeRow", function()
                        local f = CreateFrame("Frame", nil, self.scrollChild)
                        f.recipeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        f.recipeText:SetPoint("LEFT", 5, 0)
                        f.profText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        f.profText:SetPoint("RIGHT", -5, 0)
                        return f
                    end)
                    recipeRow:SetSize(self.scrollChild:GetWidth() - 40, PROF_ROW_HEIGHT)
                    recipeRow:ClearAllPoints()
                    recipeRow:SetPoint("TOPLEFT", 30, yOffset)

                    local display = r.recipeName
                    if r.itemName and r.itemName ~= r.recipeName then
                        display = r.recipeName .. " (" .. r.itemName .. ")"
                    end
                    recipeRow.recipeText:SetText(display)
                    recipeRow.profText:SetText(COLORS.grey .. r.profName .. "|r")

                    yOffset = yOffset - PROF_ROW_HEIGHT - 1
                end
            end

            yOffset = yOffset - 4
        end
    end

    -- Total result count
    yOffset = yOffset - 8
    local countLabel = self:AcquireLabel(COLORS.grey .. totalResults .. " results|r")
    countLabel:SetPoint("TOPLEFT", 5, yOffset)

    self.scrollChild:SetHeight(math.abs(yOffset) + 30)
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
function CP:SkillColor(skill, maxSkill)
    local pct = skill / maxSkill
    if pct >= 1 then return COLORS.green end
    if pct >= 0.75 then return COLORS.yellow end
    if pct >= 0.5 then return COLORS.orange end
    return COLORS.red
end

function CP:TimeAgo(timestamp)
    local diff = time() - timestamp
    if diff < 60 then return "just now" end
    if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
    if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
    return math.floor(diff / 86400) .. "d ago"
end
