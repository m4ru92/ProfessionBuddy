----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/FriendsPanel.lua
-- Friends/contacts management panel: add, remove, sync, auto-sync
----------------------------------------------------------------------

local addon = ProfBuddy
local FP = addon:NewModule("FriendsPanel")

local DS   -- DataStore ref, set in Init
local Comm -- Comm ref, set in Init

local ROW_HEIGHT = 22
local VISIBLE_ROWS = 14

----------------------------------------------------------------------
-- Profession icon paths for the summary column
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

-- Craftable professions this character has actually synced recipes for,
-- sorted alphabetically. Empty = nothing to request from them. The
-- craftable set is addon.CRAFTABLE_PROFS (Core.lua), shared with the Guild
-- tab, the order board and the profession window.
local function craftableProfs(charData)
    local list = {}
    if not charData or not charData.professions then return list end
    for pn, pdata in pairs(charData.professions) do
        if addon.CRAFTABLE_PROFS[pn] and pdata.recipes and next(pdata.recipes) then
            table.insert(list, pn)
        end
    end
    table.sort(list)
    return list
end

----------------------------------------------------------------------
-- Removing a contact deletes every recipe, bag and bank entry we hold for
-- them, so it asks first. Registered on first use, the way Core.lua
-- registers the /pb reset popup.
----------------------------------------------------------------------
local function ensureRemovePopup()
    if StaticPopupDialogs["PROFBUDDY_REMOVE_CONTACT"] then return end
    StaticPopupDialogs["PROFBUDDY_REMOVE_CONTACT"] = {
        text = "Remove %s as a contact?\nTheir synced professions, recipes and inventory are deleted with them, and they can no longer pull yours.",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self, key)
            FP:RemoveContact(key or self.data)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- A contact key we will store: "Name" or "Name-Realm", letters only, 2 to 12
-- CHARACTERS, canonicalized to Name-Realm. Without this, anything the user
-- types (colour codes included) becomes a key in SavedVariables and a string
-- painted into a row. The realm half is checked too: it reaches the same key
-- and the same chat lines, and a realm holding junk addresses a whisper no
-- server can deliver, so that contact would silently never sync.
-- UTF-8 note: a name is up to 12 characters, which is up to 24 BYTES, so the
-- length is counted in characters (every byte that is not a continuation byte
-- \128-\191 starts one) or a Cyrillic / Hangul name is refused out of hand.
local function contactKeyFromInput(text)
    local name, realm = text:match("^([^-]+)%-?(.*)$")
    if not name then return nil end
    local chars = select(2, name:gsub("[^\128-\191]", ""))
    if chars < 2 or chars > 12 then return nil end
    if name:find("[^%a\128-\255]") then return nil end
    local first = name:sub(1, 1)
    if first:match("%l") then                       -- ASCII only; leave UTF-8 alone
        name = first:upper() .. name:sub(2)
    end
    if realm ~= "" then
        -- Letters, spaces, apostrophes and hyphens only (Kel'Thuzad, Mirage
        -- Raceway, Drak'thul), high bytes passed through for localized realms.
        local rchars = select(2, realm:gsub("[^\128-\191]", ""))
        if rchars > 32 or realm:find("[^%a '%-\128-\255]") then return nil end
        name = name .. "-" .. realm
    end
    return addon:NormKey(name)
end

----------------------------------------------------------------------
-- Lightweight popup menu for picking a profession to order from.
-- (UIDropDownMenu and EasyMenu do exist in 2.5.6, but a hand-rolled popup
-- keeps the addon clear of the dropdown taint class entirely.)
----------------------------------------------------------------------
local function ensureOrderMenu()
    if FP._orderMenu then return FP._orderMenu end

    local m = CreateFrame("Frame", "ProfBuddyOrderMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    m:SetBackdropColor(0.08, 0.08, 0.1, 0.97)
    m:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
    m:EnableMouse(true)
    -- Anchored under its row button, so the bottom rows would otherwise run
    -- off the screen.
    m:SetClampedToScreen(true)
    m:Hide()

    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.title:SetPoint("TOPLEFT", 8, -7)
    m.title:SetTextColor(1, 0.82, 0)

    m.buttons = {}

    -- Click-outside-to-close catcher (one strata below the menu). It swallows
    -- the click that dismisses the menu, so it takes any button: a right
    -- click outside has to close the menu too, not go through to the world.
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()
    catcher:SetScript("OnClick", function() m:Hide() end)
    m:SetScript("OnShow", function() catcher:Show() end)
    m:SetScript("OnHide", function() catcher:Hide() end)

    table.insert(UISpecialFrames, "ProfBuddyOrderMenu") -- Escape closes it

    FP._orderMenu = m
    return m
end

local function showOrderMenu(anchorBtn, key, profs)
    local m = ensureOrderMenu()
    m.title:SetText("Order from " .. addon:ShortName(key))

    local ROW_H = 18
    local maxW = m.title:GetStringWidth() + 16

    for i, pn in ipairs(profs) do
        local b = m.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, m)
            b:SetHeight(ROW_H)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.3, 0.3, 0.5, 0.5)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.text:SetPoint("LEFT", 8, 0)
            b.text:SetJustifyH("LEFT")
            m.buttons[i] = b
        end
        b.text:SetText(pn)
        b._key, b._prof = key, pn
        b:SetScript("OnClick", function(self)
            m:Hide()
            local tsf = addon.TradeSkillFrame
            if tsf and tsf.OpenWithCharacter then
                tsf:OpenWithCharacter(self._key, self._prof)
            end
        end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -24 - (i - 1) * ROW_H)
        b:SetPoint("RIGHT", m, "RIGHT", -4, 0)
        b:Show()
        local tw = b.text:GetStringWidth() + 28
        if tw > maxW then maxW = tw end
    end
    for i = #profs + 1, #m.buttons do m.buttons[i]:Hide() end

    m:SetWidth(math.max(130, maxW))
    m:SetHeight(24 + #profs * ROW_H + 8)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    m:Show()
end

----------------------------------------------------------------------
-- Init: register as a tab on the main UI
----------------------------------------------------------------------
function FP:Init()
    DS   = addon.DataStore
    Comm = addon.Comm

    if addon.UI and addon.UI.AddTab then
        addon.UI:AddTab("friends", "Friends", function(parent)
            self:CreateContent(parent)
        end)
    end
end

-- Toggle (called from /pb friends)
function FP:Toggle()
    if not addon.UI then return end

    -- Close profession window if open
    if addon.TradeSkillFrame and addon.TradeSkillFrame.frame
       and addon.TradeSkillFrame.frame:IsShown() then
        addon.TradeSkillFrame:Hide()
    end

    if not addon.UI.frame:IsShown() then
        addon.UI:Show()
    end
    -- Select the friends tab
    for i, tab in ipairs(addon.UI.frame.tabs) do
        if tab.name == "friends" then
            addon.UI:SelectTab(i)
            break
        end
    end
end

----------------------------------------------------------------------
-- Build the content inside our tab frame
----------------------------------------------------------------------
function FP:CreateContent(parent)
    self.parent = parent

    -- ── Add contact bar ──────────────────────────────────────────
    local addBar = CreateFrame("Frame", nil, parent)
    addBar:SetPoint("TOPLEFT", 0, 0)
    addBar:SetPoint("TOPRIGHT", 0, 0)
    addBar:SetHeight(28)

    local addLabel = addBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("LEFT", 4, 0)
    addLabel:SetText("Add contact:")

    local addBox = CreateFrame("EditBox", "ProfBuddyFriendAddBox", addBar, "InputBoxTemplate")
    addBox:SetSize(180, 20)
    addBox:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
    addBox:SetAutoFocus(false)
    addBox:SetFontObject(ChatFontNormal)
    addBox:SetTextInsets(4, 4, 0, 0)

    local addBtn = CreateFrame("Button", nil, addBar, "UIPanelButtonTemplate")
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local typed = strtrim(addBox:GetText())
        if typed == "" then return end

        -- Validate and canonicalize (letters only, capitalized name,
        -- normalized realm) so the stored key matches how this contact's
        -- messages arrive at the trust gate.
        local key = contactKeyFromInput(typed)
        if not key then
            -- There is no key to print on this path, so the RAW input is echoed
            -- back: capped first so one bad paste cannot flood the chat frame,
            -- then pipe-escaped so a typed colour code prints as text.
            print("|cff00ccffProfessionBuddy:|r " .. (typed:sub(1, 40):gsub("|", "||"))
                .. " is not a character name. Use Name or Name-Realm.")
            return
        end

        -- Don't add yourself
        if addon:SameKey(key, addon:PlayerKey()) then
            print("|cff00ccffProfessionBuddy:|r Cannot add yourself as a contact.")
            addBox:SetText("")
            addBox:ClearFocus()
            return
        end

        -- Don't add duplicates
        if addon.db.contacts[key] then
            print("|cff00ccffProfessionBuddy:|r " .. key .. " is already a contact.")
            addBox:SetText("")
            addBox:ClearFocus()
            return
        end

        -- Adding a contact is a deliberate local action, so it is trusted.
        addon.db.contacts[key] = {
            autoSync = false,
            lastSync = 0,
            trusted = true,
        }

        addBox:SetText("")
        -- Leave the box: keystrokes after an add belong to the game, not to
        -- an edit box the user is done with.
        addBox:ClearFocus()
        print("|cff00ccffProfessionBuddy:|r Added " .. key .. " as a contact.")

        -- Attempt an immediate sync
        if Comm and Comm._ready then
            Comm:RequestSync(key, true)
        end

        self:Refresh()
    end)

    addBox:SetScript("OnEnterPressed", function()
        addBtn:Click()
    end)
    addBox:SetScript("OnEscapePressed", function()
        addBox:ClearFocus()
        if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() then
            addon.UI:Hide()
        end
    end)

    -- ── Column headers ───────────────────────────────────────────
    local headerBar = CreateFrame("Frame", nil, parent)
    headerBar:SetPoint("TOPLEFT", addBar, "BOTTOMLEFT", 0, -4)
    headerBar:SetPoint("TOPRIGHT", addBar, "BOTTOMRIGHT", 0, -4)
    headerBar:SetHeight(18)

    local headerBg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    local function MakeHeader(text, x, width)
        local fs = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", x, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        return fs
    end

    MakeHeader("Name", 6, 140)
    MakeHeader("Professions", 150, 140)
    MakeHeader("Last Sync", 294, 80)
    MakeHeader("Auto-sync", 378, 60)
    -- Actions column implied at the right

    -- ── Scrollable contact list ──────────────────────────────────
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
    listFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Create row frames
    self.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = self:CreateRow(listFrame, i)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", -16, 0)
        row:SetHeight(ROW_HEIGHT)
        self.rows[i] = row
    end

    -- Scroll bar (plain Slider, not UIPanelScrollBarTemplate which
    -- requires a ScrollFrame parent)
    local scrollBar = CreateFrame("Slider", "ProfBuddyFriendsScroll", listFrame)
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

    -- Empty state. It belongs to the list frame: a string on the parent lands
    -- behind the header bar, where nothing can see it.
    self.empty = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOPLEFT", 6, -8)
    self.empty:SetText("No contacts yet. Type a name above and click Add.")
    self.empty:Hide()

    self.scrollOffset = 0
    self.contactKeys = {}

    -- The "Last Sync" column ages in place, so repaint it every 30 seconds
    -- while the tab is up. A ticker costs one call every 30 s where the old
    -- OnUpdate cost one per frame drawn.
    if not self._timeTicker and C_Timer and C_Timer.NewTicker then
        self._timeTicker = C_Timer.NewTicker(30, function()
            if self.rows and self.parent and self.parent:IsVisible() then
                self:UpdateRows()
            end
        end)
    end

    -- The tab system repaints us through this on every show (UI:AddTab's
    -- OnShow hook).
    parent.Refresh = function() self:Refresh() end

    self:Refresh()
end

----------------------------------------------------------------------
-- Create a single contact row
----------------------------------------------------------------------
function FP:CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)

    -- Alternating background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.12, 0.12, 0.12, 0.6)
    else
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
    end

    -- Name
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", 6, 0)
    name:SetWidth(140)
    name:SetJustifyH("LEFT")
    row.nameText = name

    -- Profession icons (up to 4 small icons)
    row.profIcons = {}
    for i = 1, 4 do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 150 + (i - 1) * 20, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Hide()
        row.profIcons[i] = icon
    end

    -- Last sync text
    local syncText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syncText:SetPoint("LEFT", 294, 0)
    syncText:SetWidth(80)
    syncText:SetJustifyH("LEFT")
    row.syncText = syncText

    -- Auto-sync checkbox
    local autoCB = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    autoCB:SetSize(20, 20)
    autoCB:SetPoint("LEFT", 382, 0)
    autoCB:SetScript("OnClick", function(self)
        local key = row._contactKey
        if key and addon.db.contacts[key] then
            local checked = self:GetChecked()
            addon.db.contacts[key].autoSync = checked
            -- Enabling auto-sync is a deliberate local action: it trusts them.
            if checked then addon.db.contacts[key].trusted = true end
        end
        -- The list is sorted auto-sync first, so it has to re-sort here or the
        -- rows only move on some later unrelated refresh.
        FP:Refresh()
    end)
    autoCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Auto-sync")
        GameTooltip:AddLine("Lets this contact pull your recipes and inventory automatically, "
            .. "and pushes your inventory changes to them.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    autoCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.autoCB = autoCB

    -- Sync Now button
    local syncBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    syncBtn:SetSize(44, 18)
    syncBtn:SetPoint("LEFT", 412, 0)
    syncBtn:SetText("Sync")
    syncBtn:SetNormalFontObject(GameFontNormalSmall)
    syncBtn:SetHighlightFontObject(GameFontHighlightSmall)
    syncBtn:SetScript("OnClick", function()
        local key = row._contactKey
        if key and Comm and Comm._ready then
            Comm:RequestSync(key, true)
        elseif key then
            print("|cff00ccffProfessionBuddy:|r Sync not available.")
        end
    end)
    row.syncBtn = syncBtn

    -- Remove button
    local removeBtn = CreateFrame("Button", nil, row)
    removeBtn:SetSize(16, 16)
    removeBtn:SetPoint("LEFT", 462, 0)

    local removeIcon = removeBtn:CreateTexture(nil, "ARTWORK")
    removeIcon:SetAllPoints()
    removeIcon:SetTexture("Interface\\Buttons\\UI-StopButton")
    removeBtn.icon = removeIcon

    removeBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 0.3, 0.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove contact")
        GameTooltip:Show()
    end)
    removeBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    removeBtn:SetScript("OnClick", function()
        local key = row._contactKey
        if not key then return end
        -- Confirm first: this is a 16x16 button 22 pixels from Order, and the
        -- removal takes their recipes, bags and bank with it.
        ensureRemovePopup()
        StaticPopup_Show("PROFBUDDY_REMOVE_CONTACT", addon:ShortName(key), nil, key)
    end)
    row.removeBtn = removeBtn

    -- Request Order: deep-link into this friend's profession view (the
    -- order composer). Hidden for friends with no synced craftable
    -- profession (nothing to request).
    local orderBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    orderBtn:SetSize(72, 18)
    orderBtn:SetPoint("LEFT", 484, 0)
    orderBtn:SetText("Order")
    orderBtn:SetNormalFontObject(GameFontNormalSmall)
    orderBtn:SetHighlightFontObject(GameFontHighlightSmall)
    orderBtn:SetScript("OnClick", function()
        local key = row._contactKey
        if not key then return end
        local profs = craftableProfs(addon.db.characters[key])
        if #profs == 0 then return end

        local tsf = addon.TradeSkillFrame
        if not (tsf and tsf.OpenWithCharacter) then return end

        -- Single craftable profession: open it directly.
        if #profs == 1 then
            tsf:OpenWithCharacter(key, profs[1])
            return
        end

        -- Multiple: popup to pick which profession to order from.
        showOrderMenu(orderBtn, key, profs)
    end)
    orderBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Request a craft order")
        GameTooltip:Show()
    end)
    orderBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.orderBtn = orderBtn

    return row
end

----------------------------------------------------------------------
-- Remove a contact: the contact entry, their synced character record and
-- the delta-sync bookkeeping Comm keeps for them. Called from the
-- confirmation popup, never straight from the button.
----------------------------------------------------------------------
function FP:RemoveContact(key)
    key = addon:NormKey(key)
    if not key or not addon.db.contacts[key] then return end

    addon.db.contacts[key] = nil
    if DS then
        DS:RemoveRemoteCharacter(key)
    end
    -- Drop their push/receive epoch state so a later re-add starts clean.
    if addon.Comm and addon.Comm.ForgetPeer then
        addon.Comm:ForgetPeer(key)
    end
    self:Refresh()
end

----------------------------------------------------------------------
-- Refresh: rebuild the sorted contact list
----------------------------------------------------------------------
function FP:Refresh()
    if not self.rows then return end
    -- Nothing to paint behind a hidden tab; the OnShow hook rebuilds.
    if not (self.parent and self.parent:IsVisible()) then
        self._dirty = true
        return
    end
    self._dirty = false

    -- Build sorted list of contact keys
    self.contactKeys = {}
    for key, _ in pairs(addon.db.contacts or {}) do
        table.insert(self.contactKeys, key)
    end

    -- Sort: auto-sync first, then alphabetical
    table.sort(self.contactKeys, function(a, b)
        local aAuto = addon.db.contacts[a].autoSync and 1 or 0
        local bAuto = addon.db.contacts[b].autoSync and 1 or 0
        if aAuto ~= bAuto then return aAuto > bAuto end
        return a < b
    end)

    -- Update scroll range
    local maxScroll = math.max(0, #self.contactKeys - VISIBLE_ROWS)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if self.scrollOffset > maxScroll then
        self.scrollOffset = maxScroll
        self.scrollBar:SetValue(maxScroll)
    end

    -- Empty list: say so, and take the lone scroll bar off the blank area.
    local hasContacts = #self.contactKeys > 0
    self.empty:SetShown(not hasContacts)
    self.scrollBar:SetShown(hasContacts)

    self:UpdateRows()
end

----------------------------------------------------------------------
-- UpdateRows: populate visible rows from contactKeys
----------------------------------------------------------------------
function FP:UpdateRows()
    for i, row in ipairs(self.rows) do
        local idx = self.scrollOffset + i
        local key = self.contactKeys[idx]

        if key then
            row:Show()
            row._contactKey = key

            local contact = addon.db.contacts[key]
            local charData = addon.db.characters[key]

            -- Name (class-colored if we have data). The realm is not shown:
            -- it is part of the key, not of what the user reads.
            local displayName = addon:ShortName(key)
            if charData and charData.class then
                displayName = addon:ClassColor(charData.class) .. displayName .. "|r"
            end
            row.nameText:SetText(displayName)

            -- Profession icons
            local profIdx = 1
            for _, icon in ipairs(row.profIcons) do icon:Hide() end
            if charData and charData.professions then
                -- Sort professions for consistent display
                local profNames = {}
                for pn, _ in pairs(charData.professions) do
                    -- Skip Smelting (it's part of Mining)
                    if pn ~= "Smelting" then
                        table.insert(profNames, pn)
                    end
                end
                table.sort(profNames)
                for _, pn in ipairs(profNames) do
                    if profIdx <= 4 and PROF_ICONS[pn] then
                        row.profIcons[profIdx]:SetTexture(PROF_ICONS[pn])
                        row.profIcons[profIdx]:Show()
                        profIdx = profIdx + 1
                    end
                end
            end

            -- Last sync
            if contact and contact.lastSync and contact.lastSync > 0 then
                local elapsed = time() - contact.lastSync
                row.syncText:SetText(self:FormatElapsed(elapsed))
                row.syncText:SetTextColor(0.7, 0.7, 0.7)
            elseif charData and charData.lastSync and charData.lastSync > 0 then
                local elapsed = time() - charData.lastSync
                row.syncText:SetText(self:FormatElapsed(elapsed))
                row.syncText:SetTextColor(0.7, 0.7, 0.7)
            else
                row.syncText:SetText("Never")
                row.syncText:SetTextColor(0.5, 0.5, 0.5)
            end

            -- Auto-sync checkbox
            row.autoCB:SetChecked(contact and contact.autoSync)

            -- Request Order button: only if they have a synced craftable
            -- profession to order from
            if #craftableProfs(charData) > 0 then
                row.orderBtn:Show()
            else
                row.orderBtn:Hide()
            end

        else
            row:Hide()
            row._contactKey = nil
        end
    end
end

----------------------------------------------------------------------
-- Format elapsed time
----------------------------------------------------------------------
function FP:FormatElapsed(seconds)
    if seconds < 60 then
        return "Just now"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m ago"
    elseif seconds < 86400 then
        return math.floor(seconds / 3600) .. "h ago"
    else
        return math.floor(seconds / 86400) .. "d ago"
    end
end
