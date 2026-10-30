----------------------------------------------------------------------
-- ProfessionBuddy  --  BattleNet.lua
-- Battle.net auto-add (BNET-SYNC-scope.md, decided 2026-10-11/12):
-- the player ticks Battle.net friends in a picker (PB's own picks, kept by
-- BattleTag, because TBC Anniversary does not report Blizzard favorites:
-- isFavorite read 0 of 32 there). When a picked friend is online on a
-- character in this game, region and faction, that character becomes a
-- PB contact, untrusted unless "Also trust them" is on (then trusted, with
-- Auto-sync ticked, and synced once). Removing the
-- Battle.net friend removes the contacts added this way, never a manual
-- one, and never while Battle.net is down or the list reads empty.
-- TBC Anniversary only for now: the WoW: Forever beta gives addons an
-- empty friend list (a known beta issue), so there the button is greyed
-- out and says it is coming soon.
-- Local only: no wire change. The Real ID name is never read.
----------------------------------------------------------------------

local addon = ProfBuddy
local Theme = addon.Theme
local BN = addon:NewModule("BattleNet")

local WOW = "WoW"            -- BNET_CLIENT_WOW on both clients
local SCAN_DELAY = 2         -- seconds; friend events arrive in bursts
local PREFIX = "|cff00ccffProfessionBuddy:|r "

local function plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

-- Off on WoW: Forever until its friend list works for addons (2.0.1).
function BN:Available()
    return not (addon.Source and addon.Source.flavor == "forever")
end

function BN:Settings()
    local s = addon.db.settings
    if type(s.bnetPicks) ~= "table" then s.bnetPicks = {} end
    return s
end

-- Every Battle.net friend: { tag, name, chars = { {name, realm, faction} } }
-- where chars are only the characters PB could add right now (online, this
-- game, this region, with a realm). ok is false when the list cannot be read.
function BN:Friends()
    local out = {}
    local C = C_BattleNet
    if type(BNGetNumFriends) ~= "function" or not (C and C.GetFriendAccountInfo
       and C.GetFriendNumGameAccounts and C.GetFriendGameAccountInfo) then
        return out, false
    end
    local total = BNGetNumFriends() or 0
    for i = 1, total do
        local acc = C.GetFriendAccountInfo(i)
        local tag = acc and plain(acc.battleTag)
        if type(tag) == "string" and tag ~= "" then
            local f = { tag = tag, name = tag:match("^([^#]+)") or tag, chars = {} }
            for j = 1, (C.GetFriendNumGameAccounts(i) or 0) do
                local g = C.GetFriendGameAccountInfo(i, j)
                if g and plain(g.clientProgram) == WOW and plain(g.isOnline) == true
                   and plain(g.wowProjectID) == WOW_PROJECT_ID and plain(g.isInCurrentRegion) == true then
                    local cn, rn = plain(g.characterName), plain(g.realmName)
                    -- No realm, no key: never fill in our own realm (a friend
                    -- on another realm or game came back with realmName nil).
                    if type(cn) == "string" and cn ~= "" and type(rn) == "string" and rn ~= "" then
                        f.chars[#f.chars + 1] = { name = cn, realm = rn, faction = plain(g.factionName) }
                    end
                end
            end
            out[#out + 1] = f
        end
    end
    return out, true
end

-- Same faction as this character. factionName read English on TBCCA; the
-- localized name is accepted too in case another locale returns that.
local function sameFaction(fac)
    if type(fac) ~= "string" then return false end
    local token, localized = UnitFactionGroup("player")
    return fac == token or (localized ~= nil and fac == localized)
end

function BN:Scan()
    if not self:Available() then return end
    local s = self:Settings()
    if not s.bnetAutoAdd then return end
    if not (type(BNConnected) == "function" and BNConnected()) then return end
    local friends, ok = self:Friends()
    if not ok then return end
    local contacts = addon.db.contacts
    local me = addon:PlayerKey()
    local changed = false
    local present = {}
    for _, f in ipairs(friends) do
        present[f.tag] = true
        if s.bnetPicks[f.tag] then
            for _, c in ipairs(f.chars) do
                local key = sameFaction(c.faction) and addon:NormKey(c.name .. "-" .. c.realm)
                if key and not addon:SameKey(key, me) and not contacts[key] then
                    local trust = s.bnetTrust and true or false
                    contacts[key] = { autoSync = trust, lastSync = 0, trusted = trust, bnet = f.tag }
                    changed = true
                    print(PREFIX .. "Added " .. key .. " (Battle.net friend " .. f.name .. ").")
                    -- Trusted: sync once, as a manual add does.
                    if s.bnetTrust and addon.Comm and addon.Comm._ready then
                        addon.Comm:RequestSync(key)
                    end
                end
            end
        end
    end
    -- A Battle.net friend removed: drop the contacts that came from them.
    -- Only with a real list in hand: an empty read is not "everyone left".
    if #friends > 0 then
        for key, c in pairs(contacts) do
            if type(c) == "table" and c.bnet and not present[c.bnet] then
                self:RemoveContact(key)
                changed = true
                print(PREFIX .. "Removed " .. key .. ": no longer a Battle.net friend.")
            end
        end
    end
    if changed and addon.FriendsPanel and addon.FriendsPanel.Refresh then
        addon.FriendsPanel:Refresh()
    end
end

function BN:RemoveContact(key)
    local FP = addon.FriendsPanel
    if FP and FP.RemoveContact then return FP:RemoveContact(key) end
    addon.db.contacts[key] = nil
end

function BN:SetAutoAdd(on)
    self:Settings().bnetAutoAdd = on and true or false
    if on then self:Scan() end
end

-- "Also trust them" covers every contact added from Battle.net, now and
-- later: trusted with Auto-sync ticked, or neither (an untrusted contact is
-- never pushed to). Ticking it syncs once with each one online right now,
-- as a manual add does (m4ru 2026-10-13).
function BN:SetTrust(on)
    local s = self:Settings()
    s.bnetTrust = on and true or false
    local online = {}
    if s.bnetTrust and self:Available() and type(BNConnected) == "function" and BNConnected() then
        for _, f in ipairs((self:Friends())) do
            for _, c in ipairs(f.chars) do
                local key = addon:NormKey(c.name .. "-" .. c.realm)
                if key then online[key] = true end
            end
        end
    end
    for key, c in pairs(addon.db.contacts or {}) do
        if type(c) == "table" and c.bnet then
            c.trusted = s.bnetTrust
            c.autoSync = s.bnetTrust
            if s.bnetTrust and online[key] and addon.Comm and addon.Comm._ready then
                addon.Comm:RequestSync(key)
            end
        end
    end
    if addon.FriendsPanel and addon.FriendsPanel.Refresh then addon.FriendsPanel:Refresh() end
end

function BN:SetPicked(tag, on)
    local s = self:Settings()
    s.bnetPicks[tag] = on and true or nil
    if on then self:Scan() end
end

function BN:QueueScan()
    if self._timer then self._timer:Cancel() end
    self._timer = C_Timer.NewTimer(SCAN_DELAY, function()
        self._timer = nil
        self:Scan()
    end)
end

function BN:Init()
    self:Settings()
    if not self:Available() then return end
    for _, e in ipairs({ "PLAYER_LOGIN", "BN_CONNECTED", "BN_FRIEND_LIST_SIZE_CHANGED",
                         "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE" }) do
        addon:RegisterEvent(e, function() BN:QueueScan() end)
    end
end

----------------------------------------------------------------------
-- Picker window (Friends tab, "Battle.net" button)
----------------------------------------------------------------------
local ROW_H = 22

local function tooltip(widget, title, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function checkbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    t:SetText(label)
    t:SetTextColor(0.9, 0.9, 0.9)
    cb.label = t
    return cb
end

function BN:BuildWindow()
    local f = CreateFrame("Frame", "PBBattleNetFrame", UIParent, "BackdropTemplate")
    f:SetSize(420, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    Theme:SetBackdrop(f, "dialog")
    Theme:BackdropColor(f, "dialog")
    Theme:BorderColor(f, "dialog")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Battle.net friends")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local auto = checkbox(f, "Auto-add picked friends")
    auto:SetPoint("TOPLEFT", 14, -40)
    auto:SetScript("OnClick", function(cb)
        BN:SetAutoAdd(cb:GetChecked() and true or false)
        BN:RefreshWindow()
    end)
    tooltip(auto, "Auto-add picked friends",
        "When a friend ticked below is online on a character in this game, region, and faction, "
        .. "that character becomes a PB contact. Removing them as a Battle.net friend removes those contacts.")
    f.auto = auto

    local trust = checkbox(f, "Also trust them")
    trust:SetPoint("TOPLEFT", 34, -64)
    trust:SetScript("OnClick", function(cb) BN:SetTrust(cb:GetChecked() and true or false) end)
    tooltip(trust, "Also trust them",
        "Contacts added from Battle.net are trusted, as if you had added them yourself: "
        .. "they can sync your professions, bags, and bank. Their Auto-sync is ticked, "
        .. "and the ones online now sync once.")
    f.trust = trust

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 16, -94)
    hint:SetPoint("TOPRIGHT", -16, -94)
    hint:SetJustifyH("LEFT")
    hint:SetText("|cff888888Tick the friends to add. Their characters are added as they log in.|r")

    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 14, -112)
    box:SetPoint("BOTTOMRIGHT", -14, 46)
    Theme:SetBackdrop(box, "dialogBox")
    Theme:BackdropColor(box, "dialogBox")
    Theme:BorderColor(box, "dialogBox")

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(350, 1)
    sf:SetScrollChild(child)
    f.child, f.rows = child, {}

    local empty = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    empty:SetPoint("TOPLEFT", 4, -4)
    empty:SetText("|cff888888No Battle.net friends to show.|r")
    f.empty = empty

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(120, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 14)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- A full sync arrives in chunks, so a just-added contact's professions
    -- show up a little later; say so before it looks broken (m4ru 2026-10-14).
    local wait = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wait:SetPoint("BOTTOMLEFT", 16, 14)
    wait:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    wait:SetHeight(22)
    wait:SetJustifyH("LEFT")
    wait:SetJustifyV("MIDDLE")
    wait:SetText("|cff888888A new contact's data can take a minute or two to arrive.|r")
    f.waitNote = wait

    f:SetScript("OnShow", function() BN:RefreshWindow() end)
    tinsert(UISpecialFrames, "PBBattleNetFrame")
    self.window = f
    return f
end

function BN:RowAt(i)
    local f = self.window
    local row = f.rows[i]
    if row then return row end
    row = checkbox(f.child, "")
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
    row:SetScript("OnClick", function(cb)
        if cb.tag then BN:SetPicked(cb.tag, cb:GetChecked() and true or false) end
        BN:RefreshWindow()
    end)
    f.rows[i] = row
    return row
end

function BN:RefreshWindow()
    local f = self.window
    if not (f and f:IsShown()) then return end
    local s = self:Settings()
    f.auto:SetChecked(s.bnetAutoAdd and true or false)
    f.trust:SetChecked(s.bnetTrust and true or false)
    if s.bnetAutoAdd then
        f.trust:Enable(); f.trust:SetAlpha(1)
    else
        f.trust:Disable(); f.trust:SetAlpha(0.4)
    end
    local friends = self:Friends()
    -- friends in this game now first, then by name
    table.sort(friends, function(a, b)
        local ia, ib = #a.chars > 0, #b.chars > 0
        if ia ~= ib then return ia end
        return a.name:lower() < b.name:lower()
    end)
    for i, fr in ipairs(friends) do
        local row = self:RowAt(i)
        row.tag = fr.tag
        row.label:SetText(fr.name)
        row:SetChecked(s.bnetPicks[fr.tag] and true or false)
        local c = fr.chars[1]
        row.status:SetText(c and ("|cff888888playing " .. c.name .. " (" .. c.realm .. ")|r") or "")
        row:Show()
    end
    for i = #friends + 1, #f.rows do f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1, #friends * ROW_H))
    if #friends > 0 then f.empty:Hide() else f.empty:Show() end
end

function BN:ToggleWindow()
    if not self:Available() then return end
    local f = self.window or self:BuildWindow()
    if f:IsShown() then f:Hide() else f:Show() end
end
