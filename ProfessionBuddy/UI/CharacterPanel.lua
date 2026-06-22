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
            self:Refresh()
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(eb)
        eb:SetText("")
        eb:ClearFocus()
        self._searchText = ""
        self._searchPlaceholder:Show()
        self:Refresh()
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

    -- Clear search focus when clicking the parent background or mouse leaves
    parent:EnableMouse(true)
    parent:SetScript("OnMouseDown", function()
        if searchBox:HasFocus() then searchBox:ClearFocus() end
    end)
    parent:SetScript("OnLeave", function()
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
    self.rows = {}

    -- Attach refresh method to parent so the tab system can call it
    parent.Refresh = function() self:Refresh() end

    -- Initial population
    C_Timer.After(0.1, function() self:Refresh() end)
end

----------------------------------------------------------------------
-- Refresh the character list
----------------------------------------------------------------------
CP._factionCollapsed = {}
CP._searchFactionCollapsed = {}  -- separate state for search results
CP._profExpanded = {}  -- keyed by "charKey:profName"

function CP:Refresh()
    if not self.scrollChild then return end

    -- Clear existing rows
    for _, row in ipairs(self.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(self.rows)

    local characters = DS:GetAllCharacters()

    -- Search mode: show recipe/item matches across all alts
    if self._searchText and self._searchText ~= "" and characters and next(characters) then
        self:RefreshSearchResults(characters)
        return
    end

    if not characters or not next(characters) then
        local empty = self:CreateLabel(self.scrollChild, "No character data yet. Log in on each alt to scan.")
        empty:SetPoint("TOPLEFT", 10, -10)
        table.insert(self.rows, empty)
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
                        table.insert(profsSorted, { name = profName, data = profData })
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
    local row = CreateFrame("Button", nil, self.scrollChild)
    row:SetSize(self.scrollChild:GetWidth() - 10, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, yOffset)
    table.insert(self.rows, row)

    -- Background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local fc = FACTION_COLORS[faction] or FACTION_COLORS.Unknown
    bg:SetColorTexture(fc.r * 0.3, fc.g * 0.3, fc.b * 0.3, 0.9)

    -- Collapse arrow + faction name + count
    local arrow = isCollapsed and "+ " or "- "
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 5, 0)
    nameText:SetText(arrow .. faction .. "  " .. COLORS.grey .. "(" .. charCount .. ")|r")
    nameText:SetTextColor(fc.r, fc.g, fc.b)

    -- Click to toggle
    row:SetScript("OnClick", function()
        self._factionCollapsed[faction] = not self._factionCollapsed[faction]
        self:Refresh()
    end)

    -- Hover highlight
    row:SetScript("OnEnter", function()
        bg:SetColorTexture(fc.r * 0.4, fc.g * 0.4, fc.b * 0.4, 0.9)
    end)
    row:SetScript("OnLeave", function()
        bg:SetColorTexture(fc.r * 0.3, fc.g * 0.3, fc.b * 0.3, 0.9)
    end)

    return row
end

----------------------------------------------------------------------
-- Create a character header row
----------------------------------------------------------------------
function CP:CreateCharacterRow(charKey, charData, isCurrent, yOffset)
    local row = CreateFrame("Frame", nil, self.scrollChild)
    row:SetSize(self.scrollChild:GetWidth() - 10, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, yOffset)
    table.insert(self.rows, row)

    -- Background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    -- Character name with class color
    local classColor = addon:ClassColor(charData.class or "WARRIOR")
    local name = charKey
    if isCurrent then
        name = name .. " " .. COLORS.green .. "(you)|r"
    elseif charData.isRemote then
        name = name .. " " .. COLORS.grey .. "(friend)|r"
    end

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 5, 0)
    nameText:SetText(classColor .. name .. "|r")

    -- Level
    local levelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("RIGHT", -5, 0)
    levelText:SetText(COLORS.grey .. "Lv " .. (charData.level or "?") .. "|r")

    -- Last scan time
    if charData.lastScan and charData.lastScan > 0 then
        local ago = self:TimeAgo(charData.lastScan)
        local scanText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        scanText:SetPoint("RIGHT", -50, 0)
        scanText:SetText(COLORS.grey .. ago .. "|r")
    end

    return row
end

----------------------------------------------------------------------
-- Create a profession sub-row
----------------------------------------------------------------------
function CP:CreateProfessionRow(charKey, profName, profData, yOffset, isExpanded)
    local row = CreateFrame("Button", nil, self.scrollChild)
    row:SetSize(self.scrollChild:GetWidth() - 10, PROF_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 15, yOffset)
    table.insert(self.rows, row)

    -- Hover highlight
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(COLORS.highlight.r, COLORS.highlight.g, COLORS.highlight.b, 0)

    row:SetScript("OnEnter", function()
        highlight:SetColorTexture(COLORS.highlight.r, COLORS.highlight.g, COLORS.highlight.b, COLORS.highlight.a)
        self:ShowProfessionTooltip(row, charKey, profName, profData)
    end)
    row:SetScript("OnLeave", function()
        highlight:SetColorTexture(COLORS.highlight.r, COLORS.highlight.g, COLORS.highlight.b, 0)
        GameTooltip:Hide()
    end)

    -- Click to expand/collapse
    local expandKey = charKey .. ":" .. profName
    row:SetScript("OnClick", function()
        self._profExpanded[expandKey] = not self._profExpanded[expandKey]
        self:Refresh()
    end)

    -- Profession icon
    local xCursor = 5
    local iconPath = PROF_ICONS[profName]
    if iconPath then
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", xCursor, 0)
        icon:SetTexture(iconPath)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        xCursor = xCursor + 17
    end

    -- Expand/collapse arrow + profession name
    local arrow = isExpanded and "- " or "+ "
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", xCursor, 0)
    nameText:SetText(COLORS.grey .. arrow .. "|r" .. profName)

    -- Skill level with color coding
    local skill = profData.skillLevel or 0
    local maxSkill = profData.maxSkill or 375
    local skillColor = self:SkillColor(skill, maxSkill)

    local skillText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillText:SetPoint("LEFT", 175, 0)
    skillText:SetText(skillColor .. skill .. "/" .. maxSkill .. "|r")

    -- Recipe count
    local recipeCount = 0
    if profData.recipes then
        for _ in pairs(profData.recipes) do
            recipeCount = recipeCount + 1
        end
    end

    -- Unknown recipe count (if we have static data)
    local unknownCount = 0
    if RDB and RDB.data[profName] then
        local unknown = RDB:GetUnknownRecipes(charKey, profName)
        for _ in pairs(unknown) do
            unknownCount = unknownCount + 1
        end
    end

    local recipeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recipeText:SetPoint("LEFT", 260, 0)
    if recipeCount > 0 then
        local str = COLORS.white .. recipeCount .. " recipes|r"
        if unknownCount > 0 then
            str = str .. "  " .. COLORS.orange .. unknownCount .. " missing|r"
        end
        recipeText:SetText(str)
    else
        recipeText:SetText(COLORS.grey .. "not scanned|r")
    end

    -- "View" button -- opens PB profession window for this character
    local viewBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    viewBtn:SetSize(36, 16)
    viewBtn:SetPoint("RIGHT", -2, 0)
    viewBtn:SetText("View")
    viewBtn:SetNormalFontObject(GameFontNormalSmall)
    viewBtn:SetHighlightFontObject(GameFontHighlightSmall)
    viewBtn:SetScript("OnClick", function()
        if addon.TradeSkillFrame then
            addon.TradeSkillFrame:OpenWithCharacter(charKey, profName)
        end
    end)
    local viewCharKey = charKey
    local viewProfName = profName
    viewBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shortName = viewCharKey:match("^([^-]+)") or viewCharKey
        GameTooltip:SetText("View " .. shortName .. "'s " .. viewProfName)
        GameTooltip:Show()
    end)
    viewBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
        local recipeRow = CreateFrame("Frame", nil, self.scrollChild)
        recipeRow:SetSize(self.scrollChild:GetWidth() - 40, RECIPE_ROW_HEIGHT)
        recipeRow:SetPoint("TOPLEFT", 30, yOffset)
        table.insert(self.rows, recipeRow)

        local dc = DIFF_ROW_COLORS[recipe.difficulty] or DIFF_ROW_COLORS.trivial
        local xCursor = 5

        -- Item icon
        if recipe.itemID and recipe.itemID > 0 then
            local icon = recipeRow:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("LEFT", xCursor, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- GetItemIcon may need the item to be cached; fall back to
            -- a question mark if not available yet
            local iconTex = GetItemIcon(recipe.itemID)
            if iconTex then
                icon:SetTexture(iconTex)
            else
                icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            xCursor = xCursor + 17
        end

        -- Recipe name
        local nameText = recipeRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", xCursor, 0)
        nameText:SetText(recipe.name)
        nameText:SetTextColor(dc.r, dc.g, dc.b)

        -- Hoverable tooltip for the item
        if recipe.itemID and recipe.itemID > 0 then
            recipeRow:EnableMouse(true)
            local itemID = recipe.itemID
            recipeRow:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. itemID)
                GameTooltip:Show()
            end)
            recipeRow:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        yOffset = yOffset - RECIPE_ROW_HEIGHT - 1
    end

    -- Overflow indicator
    if capped then
        local moreLabel = self:CreateLabel(self.scrollChild,
            COLORS.grey .. "... and " .. (total - MAX_EXPANDED_RECIPES) .. " more|r")
        moreLabel:SetPoint("TOPLEFT", 35, yOffset)
        table.insert(self.rows, moreLabel)
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
                local itemName = GetItemInfo(itemID)
                if itemName and itemName:lower():find(query, 1, true) and count > 0 then
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
                local itemName = GetItemInfo(itemID)
                if itemName and itemName:lower():find(query, 1, true) and count > 0 then
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
                if profData.recipes then
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
                    local itemName = GetItemInfo(info.itemID)
                    if itemName and itemName:lower():find(query, 1, true)
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
        local noResults = self:CreateLabel(self.scrollChild, "No results found.")
        noResults:SetPoint("TOPLEFT", 10, yOffset)
        table.insert(self.rows, noResults)
        self.scrollChild:SetHeight(30)
        return
    end

    -- Helper: group results by faction, then by character
    local function groupByFaction(results, factionField)
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

        local fRow = CreateFrame("Button", nil, self.scrollChild)
        fRow:SetSize(self.scrollChild:GetWidth() - 20, ROW_HEIGHT)
        fRow:SetPoint("TOPLEFT", 10, yOff)
        table.insert(self.rows, fRow)

        local fc = FACTION_COLORS[faction] or FACTION_COLORS.Unknown
        local bg = fRow:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(fc.r * 0.3, fc.g * 0.3, fc.b * 0.3, 0.9)

        local arrow = isCollapsed and "+ " or "- "
        local nameText = fRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", 5, 0)
        nameText:SetText(arrow .. faction .. "  " .. COLORS.grey .. "(" .. count .. ")|r")
        nameText:SetTextColor(fc.r, fc.g, fc.b)

        fRow:SetScript("OnClick", function()
            self._searchFactionCollapsed[collapseKey] = not self._searchFactionCollapsed[collapseKey]
            self:Refresh()
        end)
        fRow:SetScript("OnEnter", function()
            bg:SetColorTexture(fc.r * 0.4, fc.g * 0.4, fc.b * 0.4, 0.9)
        end)
        fRow:SetScript("OnLeave", function()
            bg:SetColorTexture(fc.r * 0.3, fc.g * 0.3, fc.b * 0.3, 0.9)
        end)

        return isCollapsed
    end

    -- Inventory section
    if #invResults > 0 then
        local sectionHeader = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sectionHeader:SetPoint("TOPLEFT", 5, yOffset)
        sectionHeader:SetText("Has in inventory")
        sectionHeader:SetTextColor(COLORS.header.r, COLORS.header.g, COLORS.header.b)
        table.insert(self.rows, sectionHeader)
        yOffset = yOffset - 18

        local divider = self.scrollChild:CreateTexture(nil, "ARTWORK")
        divider:SetSize(self.scrollChild:GetWidth() - 10, 1)
        divider:SetPoint("TOPLEFT", 5, yOffset)
        divider:SetColorTexture(0.4, 0.35, 0.1, 0.6)
        table.insert(self.rows, divider)
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
                        local charRow = CreateFrame("Frame", nil, self.scrollChild)
                        charRow:SetSize(self.scrollChild:GetWidth() - 30, ROW_HEIGHT)
                        charRow:SetPoint("TOPLEFT", 20, yOffset)
                        table.insert(self.rows, charRow)

                        local bg = charRow:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

                        local classColor = addon:ClassColor(r.charData.class or "WARRIOR")
                        local suffix = r.isCurrent and " " .. COLORS.green .. "(you)|r" or ""
                        local nameText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        nameText:SetPoint("LEFT", 5, 0)
                        nameText:SetText(classColor .. r.charKey .. "|r" .. suffix)

                        yOffset = yOffset - ROW_HEIGHT - 2
                    end

                    -- Item row
                    local itemRow = CreateFrame("Frame", nil, self.scrollChild)
                    itemRow:SetSize(self.scrollChild:GetWidth() - 40, PROF_ROW_HEIGHT)
                    itemRow:SetPoint("TOPLEFT", 30, yOffset)
                    table.insert(self.rows, itemRow)

                    local itemText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    itemText:SetPoint("LEFT", 5, 0)
                    itemText:SetText(r.itemName)

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

                    local countText = itemRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    countText:SetPoint("RIGHT", -5, 0)
                    countText:SetText(countStr)

                    yOffset = yOffset - PROF_ROW_HEIGHT - 1
                end
            end

            yOffset = yOffset - 4
        end

        yOffset = yOffset - 6
    end

    -- Craft section
    if #craftResults > 0 then
        local sectionHeader = self.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sectionHeader:SetPoint("TOPLEFT", 5, yOffset)
        sectionHeader:SetText("Can craft")
        sectionHeader:SetTextColor(COLORS.header.r, COLORS.header.g, COLORS.header.b)
        table.insert(self.rows, sectionHeader)
        yOffset = yOffset - 18

        local divider = self.scrollChild:CreateTexture(nil, "ARTWORK")
        divider:SetSize(self.scrollChild:GetWidth() - 10, 1)
        divider:SetPoint("TOPLEFT", 5, yOffset)
        divider:SetColorTexture(0.4, 0.35, 0.1, 0.6)
        table.insert(self.rows, divider)
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
                        local charRow = CreateFrame("Frame", nil, self.scrollChild)
                        charRow:SetSize(self.scrollChild:GetWidth() - 30, ROW_HEIGHT)
                        charRow:SetPoint("TOPLEFT", 20, yOffset)
                        table.insert(self.rows, charRow)

                        local bg = charRow:CreateTexture(nil, "BACKGROUND")
                        bg:SetAllPoints()
                        bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

                        local classColor = addon:ClassColor(r.charData.class or "WARRIOR")
                        local suffix = r.isCurrent and " " .. COLORS.green .. "(you)|r" or ""
                        local nameText = charRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        nameText:SetPoint("LEFT", 5, 0)
                        nameText:SetText(classColor .. r.charKey .. "|r" .. suffix)

                        yOffset = yOffset - ROW_HEIGHT - 2
                    end

                    -- Recipe row
                    local recipeRow = CreateFrame("Frame", nil, self.scrollChild)
                    recipeRow:SetSize(self.scrollChild:GetWidth() - 40, PROF_ROW_HEIGHT)
                    recipeRow:SetPoint("TOPLEFT", 30, yOffset)
                    table.insert(self.rows, recipeRow)

                    local recipeText = recipeRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    recipeText:SetPoint("LEFT", 5, 0)
                    local display = r.recipeName
                    if r.itemName and r.itemName ~= r.recipeName then
                        display = r.recipeName .. " (" .. r.itemName .. ")"
                    end
                    recipeText:SetText(display)

                    local profText = recipeRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    profText:SetPoint("RIGHT", -5, 0)
                    profText:SetText(COLORS.grey .. r.profName .. "|r")

                    yOffset = yOffset - PROF_ROW_HEIGHT - 1
                end
            end

            yOffset = yOffset - 4
        end
    end

    -- Total result count
    yOffset = yOffset - 8
    local countLabel = self:CreateLabel(self.scrollChild, COLORS.grey .. totalResults .. " results|r")
    countLabel:SetPoint("TOPLEFT", 5, yOffset)
    table.insert(self.rows, countLabel)

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

function CP:CreateLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    label:SetTextColor(0.7, 0.7, 0.7)
    return label
end
