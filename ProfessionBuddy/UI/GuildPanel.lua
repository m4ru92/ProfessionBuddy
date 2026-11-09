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
local Theme = addon.Theme

-- WoW: Forever moved GuildRoster to C_GuildInfo; TBC Anniversary keeps the global.
local GuildRoster = GuildRoster or (C_GuildInfo and C_GuildInfo.GuildRoster)
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
    { key = "name",        label = "Name",        x = 22,  w = 104 },
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
-- Ask, then open when the recipes arrive (TEST-c, G1). A click on a
-- guildmate's profession with no recipes asks for them and opens the
-- profession when the reply arrives, once; no answer in WAIT seconds says
-- so. Profession links (UI/ProfessionLink.lua, WoW: Forever) use the same
-- path with their own opener. No comm change: Comm:RequestGuildSync, and
-- Comm:NotifyUIRefresh when data arrives.
----------------------------------------------------------------------
-- Longer than a peer's 30 s serve cooldown, as for a manual sync
GP.WAIT = 35

local function Say(text) print("|cff00ccffProfessionBuddy:|r " .. text) end

function GP:HasRecipes(key, profName)
    local char = addon.DataStore and addon.DataStore:GetCharacter(key)
    local prof = char and char.professions and char.professions[profName]
    return (prof and type(prof.recipes) == "table" and next(prof.recipes)) and true or false
end

local function OpenRecipes(key, profName)
    local tsf = addon.TradeSkillFrame
    if tsf and tsf.OpenWithCharacter then tsf:OpenWithCharacter(key, profName) end
end

-- open(key, profName) opens it; default PB's profession window. Returns
-- true when it opened at once.
function GP:AskThenOpen(key, profName, open)
    open = open or OpenRecipes
    local C = addon.Comm
    -- ask every time: the reply refreshes an open window too
    if C and C.RequestGuildSync then C:RequestGuildSync(key) end
    if self:HasRecipes(key, profName) then
        self._pending = nil
        open(key, profName)
        return true
    end
    local who = addon:ShortName(key)
    Say("Asked " .. who .. " for their " .. profName .. " recipes. They open when they arrive.")
    local pending = { key = key, profName = profName, open = open }
    self._pending = pending
    C_Timer.After(self.WAIT, function()
        if self._pending ~= pending then return end
        self._pending = nil
        Say(who .. " didn't answer (offline or not running ProfessionBuddy).")
    end)
    return false
end

function GP:IsPending(key, profName)
    local p = self._pending
    return (p and p.key == key and p.profName == profName) and true or false
end

-- Sync data arrived: open the profession PB is waiting for, once
function GP:CheckPending()
    local p = self._pending
    if p and self:HasRecipes(p.key, p.profName) then
        self._pending = nil
        p.open(p.key, p.profName)
    end
end

----------------------------------------------------------------------
-- Keep guildmates' recipes filled in the background (TEST-c, G2,
-- GUILD-SYNC-scope.md). After login, and when guildmates come online, PB
-- asks online guildmates who run PB and have a profession with recipes
-- for them, one at a time, FILL_GAP seconds apart: guildmates it has no
-- recipes for first, then the oldest. It skips anyone pulled in the last
-- FILL_FRESH seconds, and anyone this session's fill asked in the last
-- FILL_RETRY seconds (no answer: offline or busy). Each guildmate is asked
-- once per fill, so a requester never hits a guildmate's own limit (one
-- answer per person per 2 minutes); the shared limit (10 answers a minute
-- per guildmate) only matters when many PB users log in together, and a
-- skipped guildmate comes up again in the next fill. Setting "Keep
-- guildmates' recipes up to date" (guildKeepRecipes, on). No comm change.
----------------------------------------------------------------------
GP.FILL_GAP   = 3
GP.FILL_FRESH = 12 * 3600
GP.FILL_RETRY = 600
GP.FILL_DELAY = 10      -- after login or a roster change, before the fill

function GP:FillOn()
    return addon.db and addon.db.settings and addon.db.settings.guildKeepRecipes ~= false or false
end

-- Does this guildmate have a profession page PB can show, and recipes for
-- every one of them yet?
local function fillNeed(charData)
    if type(charData) ~= "table" then return false, false end
    local targets = clickTargets(charData, profList(charData))
    local any, all = false, true
    for _, target in pairs(targets) do
        any = true
        if not hasRecipes(charData, target) then all = false end
    end
    return any, any and all
end

-- Who to ask now, in order: { key, has, at }
function GP:FillQueue()
    local C = addon.Comm
    local set = C and C.GuildSet and C:GuildSet()
    if not set then return {} end
    local now, me = time(), addon:PlayerKey()
    self._fillAsked = self._fillAsked or {}
    local list = {}
    for key, info in pairs(set) do
        if info.online and not addon:SameKey(key, me) then
            local char = addon.DataStore and addon.DataStore:GetCharacter(key)
            local wants, has = fillNeed(char)
            local at = char and tonumber(char.lastSync) or 0
            local asked = self._fillAsked[key]
            if wants and not (has and now - at < self.FILL_FRESH)
               and not (asked and now - asked < self.FILL_RETRY) then
                list[#list + 1] = { key = key, has = has, at = at }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.has ~= b.has then return not a.has end
        if a.at ~= b.at then return a.at < b.at end
        return a.key < b.key
    end)
    return list
end

-- A fill starts FILL_DELAY seconds after login or a roster change, one at
-- a time; a change while one runs is picked up by the next
function GP:ScheduleFill()
    if not self:FillOn() or self._fillTimer or self._fill then return end
    self._fillTimer = true
    C_Timer.After(self.FILL_DELAY, function()
        GP._fillTimer = nil
        GP:StartFill()
    end)
end

function GP:StartFill()
    if not self:FillOn() or self._fill then return end
    local q = self:FillQueue()
    if #q == 0 then return end
    self._fill = { queue = q, i = 0, asked = {}, skipped = {}, started = time() }
    self:FillNext()
end

function GP:FillNext()
    local f = self._fill
    if not f then return end
    local C = addon.Comm
    -- off, or Comm not ready to send: stop without marking anyone asked
    if not (self:FillOn() and C and C._ready) then self._lastFill, self._fill = f, nil; return end
    f.i = f.i + 1
    local e = f.queue[f.i]
    if not e then self._lastFill, self._fill = f, nil; return end
    -- still online, and not pulled meanwhile (a click, a link)
    local set = C and C.GuildSet and C:GuildSet()
    local char = addon.DataStore and addon.DataStore:GetCharacter(e.key)
    local _, has = fillNeed(char)
    local at = char and tonumber(char.lastSync) or 0
    if not (set and set[e.key] and set[e.key].online) then
        f.skipped[#f.skipped + 1] = { key = e.key, why = "offline" }
        return self:FillNext()
    elseif has and time() - at < self.FILL_FRESH then
        f.skipped[#f.skipped + 1] = { key = e.key, why = "fresh" }
        return self:FillNext()
    end
    C:RequestGuildSync(e.key)
    self._fillAsked[e.key] = time()
    f.asked[#f.asked + 1] = { key = e.key, at = time() }
    C_Timer.After(self.FILL_GAP, function() if GP._fill == f then GP:FillNext() end end)
end

function GP:Init()
    if addon.Comm and type(addon.Comm.NotifyUIRefresh) == "function" then
        hooksecurefunc(addon.Comm, "NotifyUIRefresh", function() GP:CheckPending() end)
    end
    self.sortKey = "status"   -- default: online first, then name
    self.sortAsc = true
    self.searchText = ""
    self.filterOnlineOnly = false
    self.filterFavOnly = false   -- show only pinned guildmates
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
        -- the roster arrived (login) or someone came online: fill (G2)
        GP:ScheduleFill()
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
        addon.TradeSkillFrame:HideForMain()
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

    -- Favorite star (leading, own hit-area): toggles the pin without opening the
    -- guildmate's professions. Filled gold = favorited, which sorts to the top.
    local favBtn = CreateFrame("Button", nil, row)
    favBtn:SetSize(16, 16)
    favBtn:SetPoint("LEFT", 4, 0)
    local favTex = favBtn:CreateTexture(nil, "ARTWORK")
    favTex:SetAllPoints()
    favTex:SetTexture("Interface\\Common\\FavoritesIcon")
    favBtn.icon = favTex
    favBtn:SetScript("OnClick", function()
        if not favBtn._key then return end
        addon:ToggleFavorite(favBtn._key)
        GP:Repaint()
    end)
    favBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Favorite")
        GameTooltip:AddLine("Pin this guildmate to the top of the list.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    favBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.favBtn = favBtn

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
        Theme:Fill(hl, "iconButtonHover")
        btn.hl = hl

        btn:SetScript("OnClick", function(self)
            if not self._charKey or not self._openProf then return end
            -- Pull this guildmate's full recipe data on demand (guild trust
            -- is live, so no contact needed), and open it now or when it
            -- arrives (G1)
            GP:AskThenOpen(self._charKey, self._openProf)
        end)
        btn:SetScript("OnEnter", function(self)
            if not self._profName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not self._openProf then
                GameTooltip:SetText(self._profName)
                GameTooltip:AddLine("Gathering profession: no recipe list to open.", 1, 1, 1, true)
            elseif GP:IsPending(self._charKey, self._openProf) then
                GameTooltip:SetText(self._profName)
                GameTooltip:AddLine("Requesting... opens when it arrives.", 1, 1, 1, true)
            elseif not self._hasRecipes then
                GameTooltip:SetText(self._profName)
                GameTooltip:AddLine("No recipe data yet. Click to request it.", 1, 1, 1, true)
            else
                GameTooltip:SetText("View " .. (self._shortName or "?") .. "'s " .. self._openProf)
                -- how fresh they are (TEST-c, G1)
                local char = addon.DataStore and addon.DataStore:GetCharacter(self._charKey)
                local at = char and tonumber(char.lastSync)
                if at and at > 0 and addon.CharacterPanel and addon.CharacterPanel.TimeAgo then
                    GameTooltip:AddLine("Recipes from " .. addon.CharacterPanel:TimeAgo(at), 0.7, 0.7, 0.7)
                end
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:Hide()
        row.profIcons[i] = btn
    end

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Theme:Fill(hl, "guildRowHover")
    row:EnableMouse(true)
    -- Right-click: PB's own small menu (Whisper, Invite to group), like
    -- right-clicking a name in chat or the guild roster.
    row:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self._member then GP:ShowMemberMenu(self, self._member) end
    end)

    return row
end

----------------------------------------------------------------------
-- Right-click menu on a guildmate's row. PB's own popup, not Blizzard's
-- unit menu: that menu, opened by an addon, can leave Blizzard's protected
-- actions blocked later. Whisper and invite go through the same calls on
-- both clients (ChatFrameUtil, C_PartyInfo), with the older globals as a
-- fallback, and use the roster's own name for the guildmate. The menu
-- opens for offline guildmates too, with both actions greyed.
----------------------------------------------------------------------
local function sendTell(name)
    local f = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if f then f(name) end
end

local function invite(name)
    local f = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if f then f(name) end
end

-- Is the guildmate already in your party or raid?
local function inYourGroup(name)
    for _, n in ipairs({ name, addon:ShortName(name) }) do
        if (UnitInParty and UnitInParty(n)) or (UnitInRaid and UnitInRaid(n)) then return true end
    end
    return false
end

-- Each action greys out when it cannot work: both for an offline
-- guildmate and for yourself (Blizzard's offline guild menu has neither),
-- and Invite for someone already in your group, as Blizzard's does.
GP.MEMBER_ACTIONS = {
    { text = "Whisper", run = sendTell,
      usable = function(m, isSelf) return m.online and not isSelf end },
    { text = "Invite to group", run = invite,
      usable = function(m, isSelf) return m.online and not isSelf and not inYourGroup(m.name) end },
}

function GP:EnsureMemberMenu()
    if self._memberMenu then return self._memberMenu end
    local m = CreateFrame("Frame", "ProfBuddyGuildMemberMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    Theme:SetBackdrop(m, "menu")
    Theme:BackdropColor(m, "menu")
    Theme:BorderColor(m, "menu")
    m:EnableMouse(true)
    m:SetClampedToScreen(true)
    m:Hide()

    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.title:SetPoint("TOPLEFT", 8, -7)
    m.title:SetTextColor(1, 0.82, 0)

    m.buttons = {}
    local ROW_H = 18
    for i, action in ipairs(self.MEMBER_ACTIONS) do
        local b = CreateFrame("Button", nil, m)
        b:SetHeight(ROW_H)
        local bhl = b:CreateTexture(nil, "HIGHLIGHT")
        bhl:SetAllPoints()
        Theme:Fill(bhl, "menuHover")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.text:SetPoint("LEFT", 8, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetText(action.text)
        b:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -24 - (i - 1) * ROW_H)
        b:SetPoint("RIGHT", m, "RIGHT", -4, 0)
        b:SetScript("OnClick", function()
            m:Hide()
            if m._name then action.run(m._name) end
        end)
        m.buttons[i] = b
    end
    m:SetHeight(28 + #self.MEMBER_ACTIONS * ROW_H)

    -- A click anywhere else closes the menu, any button, as on the Friends
    -- tab's order menu.
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()
    catcher:SetScript("OnClick", function() m:Hide() end)
    m:SetScript("OnShow", function() catcher:Show() end)
    m:SetScript("OnHide", function() catcher:Hide() end)
    table.insert(UISpecialFrames, "ProfBuddyGuildMemberMenu")   -- Escape closes it

    self._memberMenu = m
    return m
end

function GP:ShowMemberMenu(row, member)
    local m = self:EnsureMemberMenu()
    m._name = member.name
    m.title:SetText(addon:ShortName(member.charKey or member.name))
    local isSelf = addon:SameKey(member.charKey or member.name, addon:PlayerKey()) and true or false
    for i, b in ipairs(m.buttons) do
        if self.MEMBER_ACTIONS[i].usable(member, isSelf) then
            b.text:SetTextColor(1, 0.82, 0)
            b:Enable()
        else
            b.text:SetTextColor(0.5, 0.5, 0.5)
            b:Disable()
        end
    end
    local w = m.title:GetStringWidth() + 16
    for _, b in ipairs(m.buttons) do w = math.max(w, b.text:GetStringWidth() + 24) end
    m:SetWidth(math.max(w, 120))
    m:ClearAllPoints()
    if addon.UI and addon.UI.MatchScale then addon.UI:MatchScale(m, row) end
    m:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 20, 0)
    m:Show()
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

    -- Favorites-only toggle: show just the pinned guildmates.
    local favCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    favCheck:SetSize(20, 20)
    favCheck:SetPoint("LEFT", self.profDD or onlineLabel, "RIGHT", 14, 0)
    favCheck:SetScript("OnClick", function(cb)
        self.filterFavOnly = cb:GetChecked() and true or false
        self:Repaint()
    end)
    local favLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    favLabel:SetPoint("LEFT", favCheck, "RIGHT", 2, 0)
    favLabel:SetText("|TInterface\\Common\\FavoritesIcon:14:14|t only")
    self.favCheck = favCheck

    -- Column headers (clickable Buttons -> sort)
    local headerBar = CreateFrame("Frame", nil, parent)
    headerBar:SetPoint("TOPLEFT", 0, -52)
    headerBar:SetPoint("TOPRIGHT", 0, -52)
    headerBar:SetHeight(18)
    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    Theme:Fill(headerBg, "columnHeader")
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
        Theme:Fill(hl, "columnHeaderHover")
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
    Theme:Fill(bgTex, "listBackground")
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
    -- Favorites always float to the top, regardless of the active sort column.
    local af = addon:IsFavorite(a.charKey) and 1 or 0
    local bf = addon:IsFavorite(b.charKey) and 1 or 0
    if af ~= bf then return af > bf end
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
                -- sanitizer. Escape the pipes so a rank cannot color the row.
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
    if self.filterFavOnly and not addon:IsFavorite(m.charKey) then return false end
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
        self.header:SetText("Guild (showing " .. #self.filtered .. " of " .. #self.members
            .. ", " .. online .. " online)" .. partial)
    else
        self.header:SetText("Guild (" .. #self.members .. " members, " .. online .. " online)" .. partial)
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

            row.favBtn._key = m.charKey
            row._member = m
            local fav = addon:IsFavorite(m.charKey)
            row.favBtn.icon:SetDesaturated(not fav)
            row.favBtn.icon:SetAlpha(fav and 1 or 0.28)

            row:Show()
        else
            row._member = nil
            row:Hide()
        end
    end
end
