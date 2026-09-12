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
    return addon:ShortName(key) or tostring(key)
end

-- Sorted profession list for a stored character (Smelting folds into Mining).
-- Remote peers choose the profession names in their own payload, so only
-- professions PB knows about are listed: junk cannot reach a roster row or
-- the profession filter dropdown.
local function profList(charData)
    local list = {}
    if charData and charData.professions then
        for pn in pairs(charData.professions) do
            if pn ~= "Smelting" and PROF_ICONS[pn] then table.insert(list, pn) end
        end
        table.sort(list)
    end
    return list
end

-- Which profession page a click on each icon should open, keyed by the
-- profession the icon shows. Mining's recipes live under Smelting, and the
-- gathering professions have no recipe list at all, so their icons carry no
-- click target: clicking one used to spend a SYNC_REQ whisper and open
-- nothing.
local function clickTargets(charData, profs)
    local targets = {}
    local stored = charData and charData.professions
    if not stored then return targets end
    for _, pn in ipairs(profs) do
        local target
        if addon.CRAFTABLE_PROFS[pn] then
            target = pn
        elseif pn == "Mining" and stored["Smelting"] then
            target = "Smelting"
        end
        if target and stored[target] then targets[pn] = target end
    end
    return targets
end

-- Does this character have recipes stored for that profession page yet? A
-- guildmate known only from a HELLO summary has the profession but no
-- recipes, so the click asks them for the data instead of opening an empty
-- window.
local function hasRecipes(charData, profName)
    local stored = charData and charData.professions and charData.professions[profName]
    return (stored and stored.recipes and next(stored.recipes)) and true or false
end

----------------------------------------------------------------------
-- Init: register the tab, refresh on roster changes
----------------------------------------------------------------------
function GP:Init()
    self.sortKey = "status"   -- default: online first, then name
    self.sortAsc = true
    self.searchText = ""
    self.filterOnlineOnly = false
    self.filterProf = nil       -- nil = all professions

    if addon.UI and addon.UI.AddTab then
        addon.UI:AddTab("guild", "Guild", function(parent)
            self:CreateContent(parent)
        end)
    end
    -- Roster events fire while the tab is hidden, in combat, and repeatedly
    -- while roster data streams in, so they only mark the list stale. The
    -- rebuild happens on the next show (the tab's OnShow calls Refresh).
    local function onRosterEvent()
        GP._dirty = true
        if GP.parent and GP.parent:IsVisible() then GP:Refresh() end
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

    -- Profession icons open that guildmate's profession page via
    -- TradeSkillFrame:OpenWithCharacter (the same entry point friend ordering
    -- uses). An icon only carries a click target when there is a page behind
    -- it (_openProf, set in UpdateRows); a gathering profession renders as
    -- plain art with no highlight and no whisper.
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
        btn.hl = hl

        btn:SetScript("OnClick", function(self)
            if not self._charKey or not self._openProf then return end
            -- Pull this guildmate's full recipe data on demand. Guild trust is
            -- live, so this needs no persisted contact. The reply arrives async
            -- and NotifyUIRefresh updates the open profession window.
            if addon.Comm and addon.Comm.RequestGuildSync then
                addon.Comm:RequestGuildSync(self._charKey)
            end
            if not self._hasRecipes then
                print("|cff00ccffProfessionBuddy:|r Asked " .. (self._shortName or "?")
                    .. " for their " .. self._openProf .. " recipes.")
                return
            end
            local tsf = addon.TradeSkillFrame
            if tsf and tsf.OpenWithCharacter then
                tsf:OpenWithCharacter(self._charKey, self._openProf)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            if not self._profName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not self._openProf then
                GameTooltip:SetText(self._profName)
                GameTooltip:AddLine("Gathering profession: no recipe list to open.", 1, 1, 1, true)
            elseif not self._hasRecipes then
                GameTooltip:SetText(self._profName)
                GameTooltip:AddLine("No recipe data yet. Click to request it.", 1, 1, 1, true)
            else
                GameTooltip:SetText("View " .. (self._shortName or "?") .. "'s " .. self._openProf)
            end
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

    -- Filter bar: name search + online-only toggle + profession filter
    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetPoint("TOPLEFT", 0, -26)
    filterBar:SetPoint("TOPRIGHT", 0, -26)
    filterBar:SetHeight(22)
    self.filterBar = filterBar

    local findLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    findLabel:SetPoint("LEFT", 6, 0)
    findLabel:SetText("Search")

    local searchBox = CreateFrame("EditBox", "ProfBuddyGuildSearch", filterBar, "InputBoxTemplate")
    searchBox:SetSize(120, 18)
    searchBox:SetPoint("LEFT", findLabel, "RIGHT", 10, 0)
    searchBox:SetAutoFocus(false)
    -- Filtering is a repaint of the cached roster, never a roster rebuild.
    searchBox:SetScript("OnTextChanged", function(box)
        self.searchText = box:GetText() or ""
        self:Repaint()
    end)
    searchBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() then
            addon.UI:Hide()
        end
    end)
    self.searchBox = searchBox

    local onlineCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    onlineCheck:SetSize(20, 20)
    onlineCheck:SetPoint("LEFT", searchBox, "RIGHT", 14, 0)
    onlineCheck:SetScript("OnClick", function(cb)
        self.filterOnlineOnly = cb:GetChecked() and true or false
        self:Repaint()
    end)
    local onlineLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    onlineLabel:SetPoint("LEFT", onlineCheck, "RIGHT", 2, 0)
    onlineLabel:SetText("Online only")

    -- Profession filter: reuse the profession-view dropdown control for a
    -- consistent look and single-select behavior.
    if addon.CreateDropdown then
        local profDD = addon.CreateDropdown(filterBar, 150, { "All" }, "All", function(val)
            self.filterProf = (val == "All") and nil or val
            self:Repaint()
        end, "Prof: ")
        profDD:SetPoint("LEFT", onlineLabel, "RIGHT", 14, 0)
        self.profDD = profDD
    end

    -- Column headers (clickable Buttons -> sort)
    local headerBar = CreateFrame("Frame", nil, parent)
    headerBar:SetPoint("TOPLEFT", 0, -52)
    headerBar:SetPoint("TOPRIGHT", 0, -52)
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
    self._dirty = true

    -- The tab system repaints us through this on every show (UI:AddTab's
    -- OnShow hook), which is also where the first roster build happens.
    parent.Refresh = function() self:Refresh() end

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
    self:Repaint()
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
    -- GetGuildRosterInfo indexes the client's FILTERED roster, so with the
    -- Blizzard show-offline toggle off the offline half simply is not there.
    -- Record that and say so in the header rather than claiming a complete
    -- roster; the user's own setting is left alone.
    self.rosterShowOffline = true
    if GetGuildRosterShowOffline then
        self.rosterShowOffline = GetGuildRosterShowOffline() and true or false
    end

    if not IsInGuild() then return end
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, rank, rankIndex, level, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if name then
            local key = addon:NormKey(name)
            local charData = addon.db and addon.db.characters and addon.db.characters[key]
            local profs = profList(charData)
            table.insert(self.members, {
                name      = name,
                charKey   = key,   -- for click-through to their profession page
                charData  = charData,
                level     = level or 0,
                -- Rank names are authored by the guild master, and this is the
                -- one displayed string here that never went through a
                -- sanitizer. Escape the pipes so a rank cannot colour the row.
                rank      = ((rank or ""):gsub("|", "||")),
                rankIndex = rankIndex or 99,
                classFile = classFile,
                online    = online and true or false,
                profs     = profs,
                profTargets = clickTargets(charData, profs),
                profCount = #profs,
            })
        end
    end

    -- Union of professions present across the roster (for the profession filter).
    local seen, present = {}, {}
    for _, m in ipairs(self.members) do
        for _, pn in ipairs(m.profs) do
            if not seen[pn] then seen[pn] = true; table.insert(present, pn) end
        end
    end
    table.sort(present)
    self.profsPresent = present
end

----------------------------------------------------------------------
-- Filtering: name search + online-only + profession
----------------------------------------------------------------------
function GP:PassesFilter(m)
    local q = self.searchText
    if q and q ~= "" then
        if not shortName(m.name):lower():find(q:lower(), 1, true) then return false end
    end
    if self.filterOnlineOnly and not m.online then return false end
    if self.filterProf then
        local has = false
        for _, pn in ipairs(m.profs) do
            if pn == self.filterProf then has = true; break end
        end
        if not has then return false end
    end
    return true
end

function GP:BuildFiltered()
    self.filtered = {}
    for _, m in ipairs(self.members) do
        if self:PassesFilter(m) then table.insert(self.filtered, m) end
    end
end

-- Sync the profession dropdown's options + current selection with the roster.
-- Rebuilds the option list only when the set of professions changes.
function GP:SyncProfDropdown()
    if not self.profDD then return end
    local sig = "All|" .. table.concat(self.profsPresent or {}, "|")
    if sig ~= self._profOptSig then
        self._profOptSig = sig
        local opts = { "All" }
        for _, pn in ipairs(self.profsPresent or {}) do opts[#opts + 1] = pn end
        self.profDD:SetOptions(opts)
    end
    self.profDD:SetValue(self.filterProf or "All", self.filterProf or "All")
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

-- Refresh is the visible-surface entry point: the tab's OnShow hook and
-- inbound comm data both land here. A hidden panel only records that the
-- roster moved, so the walk of a 400-member roster happens once, when the tab
-- is next shown, instead of on every event that fires behind it.
function GP:Refresh()
    if not self.rows then return end
    if not (self.parent and self.parent:IsVisible()) then
        self._dirty = true
        return
    end
    if self._dirty then
        self:BuildList()
        self._dirty = false
    end
    self:Repaint()
end

-- Repaint serves the search box, the online-only checkbox, the profession
-- filter and the sort headers: filter, sort and paint the cached roster with
-- no roster API calls at all.
function GP:Repaint()
    if not self.rows then return end

    -- Drop a profession filter that is no longer present in the roster.
    if self.filterProf then
        local ok = false
        for _, p in ipairs(self.profsPresent or {}) do if p == self.filterProf then ok = true; break end end
        if not ok then self.filterProf = nil end
    end
    self:SyncProfDropdown()

    self:BuildFiltered()
    table.sort(self.filtered, function(a, b) return self:Less(a, b) end)

    local inGuild = IsInGuild()
    self.empty:SetShown(not inGuild)
    self.headerBar:SetShown(inGuild)
    if self.filterBar then self.filterBar:SetShown(inGuild) end

    local online = 0
    for _, m in ipairs(self.members) do
        if m.online then online = online + 1 end
    end
    local partial = self.rosterShowOffline == false and "  (online members only)" or ""
    if not inGuild then
        self.header:SetText("Guild")
    elseif #self.filtered ~= #self.members then
        self.header:SetText("Guild  (showing " .. #self.filtered .. " of " .. #self.members
            .. ", " .. online .. " online)" .. partial)
    else
        self.header:SetText("Guild  (" .. #self.members .. " members, " .. online .. " online)" .. partial)
    end

    local maxScroll = math.max(0, #self.filtered - VISIBLE_ROWS)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if (self.scrollOffset or 0) > maxScroll then
        self.scrollOffset = maxScroll
        self.scrollBar:SetValue(maxScroll)
    end
    -- No lone slider next to "You are not in a guild.", and none on a list
    -- that fits.
    self.scrollBar:SetShown(inGuild and maxScroll > 0)

    self:UpdateHeaders()
    self:UpdateRows()
end

----------------------------------------------------------------------
-- UpdateRows: paint the visible window from the sorted member list
----------------------------------------------------------------------
function GP:UpdateRows()
    local members = self.filtered or {}
    local offset = self.scrollOffset or 0
    for i, row in ipairs(self.rows) do
        local m = members[offset + i]
        if m then
            -- Profession data lands asynchronously (a guildmate's sync reply
            -- can arrive while the tab is open), so the painted rows read the
            -- store instead of the snapshot taken when the roster was last
            -- walked. Only the rows on screen, so this is 15 lookups rather
            -- than a roster rebuild.
            local charData = addon.db and addon.db.characters and addon.db.characters[m.charKey]
            m.charData    = charData
            m.profs       = profList(charData)
            m.profCount   = #m.profs
            m.profTargets = clickTargets(charData, m.profs)

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
                ic:Hide(); ic._charKey = nil; ic._profName = nil; ic._openProf = nil
            end
            local shown = 0
            for _, pn in ipairs(m.profs) do
                if shown < MAX_PROF_ICONS and PROF_ICONS[pn] then
                    shown = shown + 1
                    local ic = row.profIcons[shown]
                    local openProf = m.profTargets and m.profTargets[pn]
                    local recipes = openProf and hasRecipes(m.charData, openProf) or false
                    ic.icon:SetTexture(PROF_ICONS[pn])
                    local alpha = m.online and 1 or 0.5
                    if openProf and not recipes then alpha = alpha * 0.6 end
                    ic:SetAlpha(alpha)
                    -- No click target, no hover highlight: the icon reads as
                    -- the label it is.
                    ic.hl:SetAlpha(openProf and 1 or 0)
                    ic._charKey    = m.charKey
                    ic._profName   = pn
                    ic._openProf   = openProf
                    ic._hasRecipes = recipes
                    ic._shortName  = nm
                    ic:Show()
                end
            end

            row:Show()
        else
            row:Hide()
        end
    end
end
