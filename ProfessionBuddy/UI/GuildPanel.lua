----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/GuildPanel.lua
-- Guild tab: your guild roster as a scrollable, column-aligned, sortable
-- table (Name, Lvl, Rank, Status, Professions). Click a column header to
-- sort by it; click again to reverse.
--
-- LOCAL-ONLY first slice: name/level/rank/online/class come from
-- GetGuildRosterInfo. The Professions column is populated only for
-- guildmates we ALREADY have character data on (your own alts in the
-- guild, or guildmates you have friend-synced): it reads addon.db.characters,
-- the shared store friends and alts use. Until the guild profession-sync arm
-- lands (a later increment, COMM_REV bump, gated on the ghost-partner
-- harness), most guildmates show no professions yet.
--
-- No cross-client sync, no trust-gate change, no COMM_REV bump here.
----------------------------------------------------------------------

local addon = ProfBuddy
local GP = addon:NewModule("GuildPanel")

local ROW_HEIGHT   = 20
local VISIBLE_ROWS = 15
local MAX_PROF_ICONS = 6

-- Profession -> icon (mirrors FriendsPanel).
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
    ["Tailoring"]       = "Interface\\Icons\\Trade_Tailoring",
    ["Fishing"]         = "Interface\\Icons\\Trade_Fishing",
}

-- Ordered column definitions. x = left offset within the row, w = text width.
-- Professions is last so its variable-width icon strip absorbs the right side.
local COLS = {
    { key = "name",        label = "Name",        x = 6,   w = 120 },
    { key = "level",       label = "Lvl",         x = 132, w = 34  },
    { key = "rank",        label = "Rank",        x = 172, w = 110 },
    { key = "status",      label = "Status",      x = 288, w = 64  },
    { key = "professions", label = "Professions", x = 356, w = 170 },
}
local COL = {}
for _, c in ipairs(COLS) do COL[c.key] = c end

-- Default sort direction the first time you click each header.
local SORT_DEFAULT_ASC = {
    name = true, level = false, rank = true, status = true, professions = false,
}

local function shortName(key)
    return (key and key:match("^([^%-]+)")) or tostring(key)
end

local function fullName(name)
    if not name then return nil end
    if not name:find("-") then
        name = name .. "-" .. GetRealmName()
    end
    return name
end

-- Sorted profession list for a stored character (Smelting folds into Mining).
local function profList(charData)
    local list = {}
    if charData and charData.professions then
        for pn in pairs(charData.professions) do
            if pn ~= "Smelting" then table.insert(list, pn) end
        end
        table.sort(list)
    end
    return list
end

----------------------------------------------------------------------
-- Init: register the tab, refresh on roster changes
----------------------------------------------------------------------
function GP:Init()
    self.sortKey = "status"   -- default: online first, then name
    self.sortAsc = true

    if addon.UI and addon.UI.AddTab then
        addon.UI:AddTab("guild", "Guild", function(parent)
            self:CreateContent(parent)
        end)
    end
    local function onRosterEvent()
        if GP.parent then GP:Refresh() end
    end
    addon:RegisterEvent("GUILD_ROSTER_UPDATE", onRosterEvent)
    addon:RegisterEvent("PLAYER_GUILD_UPDATE", onRosterEvent)
end

-- Toggle (called from /pb guild and the profession-window nav strip):
-- bring the main window forward on the Guild tab. Mirrors FriendsPanel:Toggle.
function GP:Toggle()
    if not addon.UI then return end
    if addon.TradeSkillFrame and addon.TradeSkillFrame.frame
       and addon.TradeSkillFrame.frame:IsShown() then
        addon.TradeSkillFrame:Hide()
    end
    if not addon.UI.frame:IsShown() then
        addon.UI:Show()
    end
    for i, tab in ipairs(addon.UI.frame.tabs) do
        if tab.name == "guild" then
            addon.UI:SelectTab(i)
            break
        end
    end
end

----------------------------------------------------------------------
-- One roster row: Name / Lvl / Rank / Status + a Professions icon strip
----------------------------------------------------------------------
function GP:CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)

    local function cell(col)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", col.x, 0)
        fs:SetWidth(col.w)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end

    row.nameText   = cell(COL.name)
    row.levelText  = cell(COL.level)
    row.rankText   = cell(COL.rank)
    row.statusText = cell(COL.status)

    -- Profession icons are clickable: a click opens that guildmate's profession
    -- page via TradeSkillFrame:OpenWithCharacter (the same entry point friend
    -- ordering uses). It self-guards, so a click with no synced data is a no-op.
    row.profIcons = {}
    for i = 1, MAX_PROF_ICONS do
        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(16, 16)
        btn:SetPoint("LEFT", COL.professions.x + (i - 1) * 20, 0)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = tex

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.25)

        btn:SetScript("OnClick", function(self)
            if not self._charKey or not self._profName then return end
            -- Pull this guildmate's full recipe data on demand. Guild trust is
            -- live, so this needs no persisted contact. The reply arrives async
            -- and NotifyUIRefresh updates the open profession window.
            if addon.Comm and addon.Comm.RequestGuildSync then
                addon.Comm:RequestGuildSync(self._charKey)
            end
            local tsf = addon.TradeSkillFrame
            if tsf and tsf.OpenWithCharacter then
                tsf:OpenWithCharacter(self._charKey, self._profName)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            if not self._profName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("View " .. (self._shortName or "?") .. "'s " .. self._profName)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:Hide()
        row.profIcons[i] = btn
    end

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.3, 0.3, 0.5, 0.15)
    row:EnableMouse(true)

    return row
end

----------------------------------------------------------------------
-- Build the content inside our tab frame
----------------------------------------------------------------------
function GP:CreateContent(parent)
    self.parent = parent

    self.header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.header:SetPoint("TOPLEFT", 6, -6)
    self.header:SetText("Guild")

    self.empty = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOPLEFT", 6, -34)
    self.empty:SetText("You are not in a guild.")
    self.empty:Hide()

    -- Column headers (clickable Buttons -> sort)
    local headerBar = CreateFrame("Frame", nil, parent)
    headerBar:SetPoint("TOPLEFT", 0, -26)
    headerBar:SetPoint("TOPRIGHT", 0, -26)
    headerBar:SetHeight(18)
    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    self.headerBar = headerBar

    self.headerBtns = {}
    for _, c in ipairs(COLS) do
        local btn = CreateFrame("Button", nil, headerBar)
        btn:SetPoint("LEFT", c.x, 0)
        btn:SetSize(c.w, 18)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetJustifyH("LEFT")
        btn.label = fs
        btn.colLabel = c.label
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.4, 0.4, 0.6, 0.25)
        btn:SetScript("OnClick", function() GP:SetSort(c.key) end)
        self.headerBtns[c.key] = btn
    end

    -- List area
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
    listFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    self.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = self:CreateRow(listFrame)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -16, 0)
        row:SetHeight(ROW_HEIGHT)
        self.rows[i] = row
    end

    local scrollBar = CreateFrame("Slider", "ProfBuddyGuildScroll", listFrame)
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
    bgTex:SetColorTexture(0.05, 0.05, 0.05, 0.5)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        self.scrollOffset = math.floor(value)
        self:UpdateRows()
    end)
    self.scrollBar = scrollBar

    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        local cur = scrollBar:GetValue()
        scrollBar:SetValue(cur - delta)
    end)

    self.scrollOffset = 0
    self.members = {}

    if GuildRoster then GuildRoster() end
    self:Refresh()
end

----------------------------------------------------------------------
-- Sorting
----------------------------------------------------------------------
function GP:SetSort(key)
    if self.sortKey == key then
        self.sortAsc = not self.sortAsc
    else
        self.sortKey = key
        self.sortAsc = SORT_DEFAULT_ASC[key]
    end
    self:Refresh()
end

function GP:Less(a, b)
    local key, asc = self.sortKey, self.sortAsc
    local an, bn = shortName(a.name):lower(), shortName(b.name):lower()
    if key == "status" then
        if a.online ~= b.online then
            if asc then return a.online else return b.online end
        end
        return an < bn
    elseif key == "name" then
        if an ~= bn then
            if asc then return an < bn else return an > bn end
        end
        return false
    elseif key == "level" then
        if a.level ~= b.level then
            if asc then return a.level < b.level else return a.level > b.level end
        end
        return an < bn
    elseif key == "rank" then
        if a.rankIndex ~= b.rankIndex then
            if asc then return a.rankIndex < b.rankIndex else return a.rankIndex > b.rankIndex end
        end
        return an < bn
    elseif key == "professions" then
        if a.profCount ~= b.profCount then
            if asc then return a.profCount < b.profCount else return a.profCount > b.profCount end
        end
        return an < bn
    end
    return an < bn
end

----------------------------------------------------------------------
-- Refresh: rebuild the member list, sort, repaint
----------------------------------------------------------------------
function GP:BuildList()
    self.members = {}
    if not IsInGuild() then return end
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, rank, rankIndex, level, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if name then
            local key = fullName(name)
            local charData = addon.db and addon.db.characters and addon.db.characters[key]
            local profs = profList(charData)
            table.insert(self.members, {
                name      = name,
                charKey   = key,   -- for click-through to their profession page
                level     = level or 0,
                rank      = rank or "",
                rankIndex = rankIndex or 99,
                classFile = classFile,
                online    = online and true or false,
                profs     = profs,
                profCount = #profs,
            })
        end
    end
end

function GP:UpdateHeaders()
    for _, c in ipairs(COLS) do
        local btn = self.headerBtns[c.key]
        if btn then
            if self.sortKey == c.key then
                local arrow = self.sortAsc and "^" or "v"
                btn.label:SetText(c.label .. " |cffffd200" .. arrow .. "|r")
            else
                btn.label:SetText(c.label)
            end
        end
    end
end

function GP:Refresh()
    if not self.rows then return end
    self:BuildList()
    table.sort(self.members, function(a, b) return self:Less(a, b) end)

    local inGuild = IsInGuild()
    self.empty:SetShown(not inGuild)
    self.headerBar:SetShown(inGuild)

    local online = 0
    for _, m in ipairs(self.members) do
        if m.online then online = online + 1 end
    end
    if inGuild then
        self.header:SetText("Guild  (" .. #self.members .. " members, " .. online .. " online)")
    else
        self.header:SetText("Guild")
    end

    local maxScroll = math.max(0, #self.members - VISIBLE_ROWS)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if (self.scrollOffset or 0) > maxScroll then
        self.scrollOffset = maxScroll
        self.scrollBar:SetValue(maxScroll)
    end

    self:UpdateHeaders()
    self:UpdateRows()
end

----------------------------------------------------------------------
-- UpdateRows: paint the visible window from the sorted member list
----------------------------------------------------------------------
function GP:UpdateRows()
    local members = self.members or {}
    local offset = self.scrollOffset or 0
    for i, row in ipairs(self.rows) do
        local m = members[offset + i]
        if m then
            local nm = shortName(m.name)
            if m.online then
                local cc = (m.classFile and addon:ClassColor(m.classFile)) or "|cffffffff"
                row.nameText:SetText(cc .. nm .. "|r")
                row.levelText:SetText("|cffffffff" .. m.level .. "|r")
                row.rankText:SetText("|cffd0d0d0" .. m.rank .. "|r")
                row.statusText:SetText("|cff40c040Online|r")
            else
                row.nameText:SetText("|cff808080" .. nm .. "|r")
                row.levelText:SetText("|cff707070" .. m.level .. "|r")
                row.rankText:SetText("|cff707070" .. m.rank .. "|r")
                row.statusText:SetText("|cff707070Offline|r")
            end

            for _, ic in ipairs(row.profIcons) do
                ic:Hide(); ic._charKey = nil; ic._profName = nil
            end
            local shown = 0
            for _, pn in ipairs(m.profs) do
                if shown < MAX_PROF_ICONS and PROF_ICONS[pn] then
                    shown = shown + 1
                    local ic = row.profIcons[shown]
                    ic.icon:SetTexture(PROF_ICONS[pn])
                    ic:SetAlpha(m.online and 1 or 0.5)
                    ic._charKey   = m.charKey
                    ic._profName  = pn
                    ic._shortName = nm
                    ic:Show()
                end
            end

            row:Show()
        else
            row:Hide()
        end
    end
end
