----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/MailHelper.lua
-- Mail recipient helper: a small "PB" button next to the mail "To" field opens a
-- menu of your saved contacts (favorites first) to fill the recipient without
-- typing. Attached to the default Send Mail frame; no change to the crowded
-- Friends/Guild rows.
----------------------------------------------------------------------

local addon = ProfBuddy
local MH = addon:NewModule("MailHelper")

-- Contact keys, favorites first, then alphabetical by short name.
local function contactKeys()
    local keys = {}
    for key in pairs(addon.db and addon.db.contacts or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local af = addon:IsFavorite(a) and 1 or 0
        local bf = addon:IsFavorite(b) and 1 or 0
        if af ~= bf then return af > bf end
        return addon:ShortName(a):lower() < addon:ShortName(b):lower()
    end)
    return keys
end

local function fillTo(shortName)
    if not SendMailNameEditBox then return end
    SendMailNameEditBox:SetText(shortName)
    -- Move focus onward so the user goes straight to the subject.
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus() end
end

-- Hand-rolled popup, mirroring the item-favorites / order menus, which keeps the
-- addon clear of the dropdown taint class.
local function ensureMenu()
    if MH._menu then return MH._menu end
    local m = CreateFrame("Frame", "ProfBuddyMailMenu", UIParent, "BackdropTemplate")
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
    m:SetClampedToScreen(true)
    m:Hide()
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    m.title:SetPoint("TOPLEFT", 8, -7)
    m.title:SetTextColor(1, 0.82, 0)
    m.title:SetText("Mail to a contact")
    m.buttons = {}
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()
    catcher:SetScript("OnClick", function() m:Hide() end)
    m:SetScript("OnShow", function() catcher:Show() end)
    m:SetScript("OnHide", function() catcher:Hide() end)
    table.insert(UISpecialFrames, "ProfBuddyMailMenu")
    MH._menu = m
    return m
end

local ROW_H = 18
local function menuButton(m, i)
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
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -24 - (i - 1) * ROW_H)
    b:SetPoint("RIGHT", m, "RIGHT", -4, 0)
    return b
end

local function showMenu(anchor)
    local m = ensureMenu()
    local keys = contactKeys()
    local maxW = m.title:GetStringWidth() + 16
    local n = 0
    for _, key in ipairs(keys) do
        n = n + 1
        local b = menuButton(m, n)
        local fav = addon:IsFavorite(key) and "|TInterface\\Common\\FavoritesIcon:12:12|t " or ""
        b.text:SetText(fav .. addon:ShortName(key))
        b:EnableMouse(true)
        b:SetScript("OnClick", function() m:Hide(); fillTo(addon:ShortName(key)) end)
        b:Show()
        local tw = b.text:GetStringWidth() + 28
        if tw > maxW then maxW = tw end
    end
    if n == 0 then
        n = 1
        local b = menuButton(m, 1)
        b.text:SetText("|cff888888No contacts yet|r")
        b:EnableMouse(false)
        b:SetScript("OnClick", nil)
        b:Show()
    end
    for i = n + 1, #m.buttons do m.buttons[i]:Hide() end
    m:SetWidth(math.max(150, maxW))
    m:SetHeight(24 + n * ROW_H + 8)
    m:ClearAllPoints()
    m:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    m:Show()
end

-- The PB button aligns with the To field, but the field's box geometry differs by
-- skin: the default InputBoxTemplate frame runs a little below its text (so it
-- wants a few px up), while ElvUI reskins it to a tighter box (so a plain center
-- is right). Pick per environment and re-apply on show, so it lands correctly
-- whether or not a skin loaded or reskinned the field after us.
local function positionMailButton()
    local btn = MH._btn
    if not (btn and SendMailNameEditBox) then return end
    -- Detect ElvUI by its global table (set whenever ElvUI is loaded). This does
    -- NOT use IsAddOnLoaded, which is gone from the 2.5.6 Anniversary client
    -- (moved to C_AddOns) and silently returned nil, leaving the button on the
    -- base-UI offset in ElvUI.
    local y = _G.ElvUI and 0 or 3
    btn:ClearAllPoints()
    btn:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 4, y)
end

function MH:Init()
    -- The Send Mail frame is default UI (FrameXML), present before addons load.
    -- Guard anyway so a client that renames it just leaves the feature absent.
    if not (SendMailFrame and SendMailNameEditBox) then return end
    if self._btn then return end
    local btn = CreateFrame("Button", "ProfBuddyMailButton", SendMailFrame, "UIPanelButtonTemplate")
    btn:SetSize(28, 20)
    btn:SetText("PB")
    btn:SetNormalFontObject(GameFontNormalSmall)
    btn:SetHighlightFontObject(GameFontHighlightSmall)
    btn:SetScript("OnClick", function(self) showMenu(self) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("ProfessionBuddy contacts")
        GameTooltip:AddLine("Fill the recipient from your saved contacts.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self._btn = btn
    positionMailButton()
    -- Re-apply on each open: ElvUI (or another skin) may have loaded or reskinned
    -- the To field after our Init ran.
    if SendMailFrame.HookScript then SendMailFrame:HookScript("OnShow", positionMailButton) end
end
