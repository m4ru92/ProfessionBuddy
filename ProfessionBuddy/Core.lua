----------------------------------------------------------------------
-- ProfessionBuddy  --  Core.lua
-- Addon bootstrap, event dispatch, slash commands
----------------------------------------------------------------------

ProfBuddy = ProfBuddy or {}

local addon = ProfBuddy
addon.version = "1.1.0"
addon.modules = {}

-- Professions with a browsable recipe list in the static DB. The gathering
-- professions have no recipe list to open, so nothing routes a click or an
-- order at them. Defined once here; the panels and the profession window all
-- read this table rather than keeping their own copy.
addon.CRAFTABLE_PROFS = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
    ["Enchanting"] = true, ["Engineering"] = true, ["First Aid"] = true,
    ["Jewelcrafting"] = true, ["Leatherworking"] = true,
    ["Smelting"] = true, ["Tailoring"] = true,
}

----------------------------------------------------------------------
-- Canonical character key
-- A character is "Name-Realm" everywhere in the addon, with the realm
-- normalized the way the game normalizes it in comm sender strings:
-- spaces, hyphens and apostrophes removed, so "Old Blanchy" becomes
-- "OldBlanchy". On a single-word realm every helper here is a no-op.
----------------------------------------------------------------------

-- Realm as it appears in a canonical key. The parens keep gsub's second
-- return (the substitution count) away from the caller.
function addon:NormRealm(realm)
    return ((realm or ""):gsub("[%s%-']", ""))
end

-- "Name" -> "Name-<our realm>"; "Name-Any Realm" -> "Name-AnyRealm".
-- Anything that is not a string returns nil.
function addon:NormKey(key)
    if type(key) ~= "string" then return nil end
    local name, realm = key:match("^([^-]+)%-?(.*)$")
    if not name then return nil end
    if realm == "" then realm = GetRealmName() end
    return name .. "-" .. addon:NormRealm(realm)
end

-- Shorthand for the player's canonical key, used everywhere.
function addon:PlayerKey()
    return UnitName("player") .. "-" .. addon:NormRealm(GetRealmName())
end

-- Display half of a key. Non-strings pass straight through so callers keep
-- whatever fallback they already have.
function addon:ShortName(key)
    if type(key) ~= "string" then return key end
    return key:match("^([^-]+)") or key
end

-- Do two keys name the same character? nil matches nothing, not even nil.
function addon:SameKey(a, b)
    local ka = addon:NormKey(a)
    return ka ~= nil and ka == addon:NormKey(b)
end

----------------------------------------------------------------------
-- Schema 2 migration: canonical character keys
-- Keys used to be stored with the realm spelled exactly as GetRealmName()
-- returns it, while trust comparisons normalized it, so on a multi-word
-- realm one character could sit under two spellings and match neither.
-- Schema 2 stores the normalized spelling everywhere. Order IDs are opaque
-- and are never rewritten: the counterparty still holds the original.
----------------------------------------------------------------------

-- How recently a record was touched, for collapse tie-breaks.
local function recordStamp(rec)
    if type(rec) ~= "table" then return 0 end
    local best = tonumber(rec.lastSync) or 0
    local seen = tonumber(rec.lastSeen) or 0
    local scan = tonumber(rec.lastScan) or 0
    if seen > best then best = seen end
    if scan > best then best = scan end
    return best
end

-- When two old keys collapse onto one canonical key: a real local character
-- always beats a synced copy of itself, otherwise the newest record wins.
local function preferRecord(candidate, incumbent)
    if type(incumbent) ~= "table" then return true end
    if type(candidate) ~= "table" then return false end
    local newLocal, oldLocal = not candidate.isRemote, not incumbent.isRemote
    if newLocal ~= oldLocal then return newLocal end
    return recordStamp(candidate) > recordStamp(incumbent)
end

-- Re-key a character-keyed table in place. Collect first, then write: Lua
-- leaves pairs() undefined if you add a key during the traversal.
local function rekeyByCharacter(tbl)
    if type(tbl) ~= "table" then return end
    local moves
    for oldKey, rec in pairs(tbl) do
        local newKey = addon:NormKey(oldKey)
        if newKey and newKey ~= oldKey then
            moves = moves or {}
            table.insert(moves, { old = oldKey, new = newKey, rec = rec })
        end
    end
    if not moves then return end
    for _, m in ipairs(moves) do
        tbl[m.old] = nil
    end
    for _, m in ipairs(moves) do
        if preferRecord(m.rec, tbl[m.new]) then
            tbl[m.new] = m.rec
        end
    end
end

-- Character-key fields on an order, a board post, or an outbox order copy.
-- A field the shape does not carry stays nil.
local function rekeyOrderFields(o)
    if type(o) ~= "table" then return end
    o.requester  = addon:NormKey(o.requester) or o.requester
    o.crafter    = addon:NormKey(o.crafter) or o.crafter
    o.lastSentBy = addon:NormKey(o.lastSentBy) or o.lastSentBy
end

local function migrateToSchema2(db)
    rekeyByCharacter(db.characters)
    rekeyByCharacter(db.contacts)

    -- The guild echo bug could file our own character as a remote record.
    -- Re-keying already collapsed it onto our key and kept the local copy;
    -- if the phantom is all that survived, it is still our data, so drop the
    -- remote marks rather than the character.
    local myRec = db.characters and db.characters[addon:PlayerKey()]
    if type(myRec) == "table" and myRec.isRemote then
        myRec.isRemote = nil
        myRec.lastSync = nil
    end

    for _, o in pairs(db.orders or {}) do
        rekeyOrderFields(o)
    end
    -- db.orderBoard is keyed by order ID, not by character key, so only the
    -- fields inside each post move.
    for _, post in pairs(db.orderBoard or {}) do
        rekeyOrderFields(post)
    end
    for _, entry in pairs(db.orderOutbox or {}) do
        if type(entry) == "table" then
            entry.target = addon:NormKey(entry.target) or entry.target
            if type(entry.data) == "table" then
                rekeyOrderFields(entry.data.order)
            end
        end
    end
end

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------
local frame = CreateFrame("Frame", "ProfBuddyEventFrame")
local handlers = {}

function addon:RegisterEvent(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    frame:RegisterEvent(event)
end

frame:SetScript("OnEvent", function(self, event, ...)
    if handlers[event] then
        for _, fn in ipairs(handlers[event]) do
            fn(event, ...)
        end
    end
end)

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
addon:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= "ProfessionBuddy" then return end

    -- Init saved variables
    ProfBuddyDB = ProfBuddyDB or {}
    ProfBuddyDB.characters = ProfBuddyDB.characters or {}
    ProfBuddyDB.contacts = ProfBuddyDB.contacts or {}
    ProfBuddyDB.orders = ProfBuddyDB.orders or {}
    ProfBuddyDB.orderBoard = ProfBuddyDB.orderBoard or {}  -- open orders posted by guildmates
    ProfBuddyDB.skillReqOverrides = ProfBuddyDB.skillReqOverrides or {}
    if ProfBuddyDB.orderSeq == nil then ProfBuddyDB.orderSeq = 0 end
    ProfBuddyDB.schemaVersion = tonumber(ProfBuddyDB.schemaVersion) or 1
    ProfBuddyDB.settings = ProfBuddyDB.settings or {
        tooltipShowUsedIn   = true,
        tooltipShowSkillRange = true,  -- colored skill-up range on each "Used in" line
        gatherSkillTooltip  = true,  -- required skin/mine/herb skill on mob + node tooltips
        gatherShowUnlearned = true,  -- show gather info for professions you have not learned
        skillReqNotify      = false, -- dev-only: chat alert when a trainer learn-level correction is found
        tooltipMaxOwn       = 16,   -- 16 = "All" (uncapped)
        tooltipMaxAlt       = 16,   -- 16 = "All" (uncapped)
        tooltipMaxOther     = 5,
        showAltInDetail     = true,
        showAltInTooltips   = true,
        showCrossFactionAlts = false,
        replaceTradeSkill   = true,
        rememberWindowState = true,
        showAllProfessions  = false,
        includeAltsInCalc   = true,
        showRemoteInDetail  = true,
        showRemoteInTooltips = true,
        includeRemoteInCalc = false,
        orderChatMessages   = true,
        orderSoundOnRequest = false,
        shareData           = true,  -- master switch for AceComm data sharing
        orderHistoryLimit   = 50,    -- keep the most recent N terminal orders per character (hard-pruned)
        orderHistorySortOldest = false, -- History sort: false = newest-closed first
        orderExpiryDays     = 14,    -- auto-expire pending orders older than N days (0 = off)
        autoAddParty        = false, -- add party members as contacts automatically
    }
    -- Migrate old single-slider setting
    if ProfBuddyDB.settings.tooltipMaxRecipes then
        ProfBuddyDB.settings.tooltipMaxOwn   = 16
        ProfBuddyDB.settings.tooltipMaxOther = ProfBuddyDB.settings.tooltipMaxRecipes
        ProfBuddyDB.settings.tooltipMaxRecipes = nil
    end
    -- Migrate showAltInventory -> showAltInDetail
    if ProfBuddyDB.settings.showAltInventory ~= nil then
        ProfBuddyDB.settings.showAltInDetail = ProfBuddyDB.settings.showAltInventory
        ProfBuddyDB.settings.showAltInventory = nil
    end
    -- Ensure new keys exist for pre-existing SavedVariables
    if ProfBuddyDB.settings.showAltInDetail == nil then
        ProfBuddyDB.settings.showAltInDetail = true
    end
    if ProfBuddyDB.settings.showAltInTooltips == nil then
        ProfBuddyDB.settings.showAltInTooltips = true
    end
    if ProfBuddyDB.settings.tooltipShowSkillRange == nil then
        ProfBuddyDB.settings.tooltipShowSkillRange = true
    end
    if ProfBuddyDB.settings.gatherSkillTooltip == nil then
        ProfBuddyDB.settings.gatherSkillTooltip = true
    end
    if ProfBuddyDB.settings.gatherShowUnlearned == nil then
        ProfBuddyDB.settings.gatherShowUnlearned = true
    end
    if ProfBuddyDB.settings.tooltipMaxAlt == nil then
        ProfBuddyDB.settings.tooltipMaxAlt = 16
    end
    if ProfBuddyDB.settings.tooltipMaxOwn == nil then
        ProfBuddyDB.settings.tooltipMaxOwn = 16
    end
    if ProfBuddyDB.settings.tooltipMaxOther == nil then
        ProfBuddyDB.settings.tooltipMaxOther = 5
    end
    if ProfBuddyDB.settings.showAllProfessions == nil then
        ProfBuddyDB.settings.showAllProfessions = false
    end
    if ProfBuddyDB.settings.orderHistoryLimit == nil then
        ProfBuddyDB.settings.orderHistoryLimit = 50
    end
    if ProfBuddyDB.settings.orderHistorySortOldest == nil then
        ProfBuddyDB.settings.orderHistorySortOldest = false
    end
    if ProfBuddyDB.settings.orderExpiryDays == nil then
        ProfBuddyDB.settings.orderExpiryDays = 14
    end
    if ProfBuddyDB.settings.includeAltsInCalc == nil then
        ProfBuddyDB.settings.includeAltsInCalc = true
    end
    if ProfBuddyDB.settings.showRemoteInDetail == nil then
        ProfBuddyDB.settings.showRemoteInDetail = true
    end
    if ProfBuddyDB.settings.showRemoteInTooltips == nil then
        ProfBuddyDB.settings.showRemoteInTooltips = true
    end
    if ProfBuddyDB.settings.includeRemoteInCalc == nil then
        ProfBuddyDB.settings.includeRemoteInCalc = false
    end
    if ProfBuddyDB.settings.orderChatMessages == nil then
        ProfBuddyDB.settings.orderChatMessages = true
    end
    if ProfBuddyDB.settings.orderSoundOnRequest == nil then
        ProfBuddyDB.settings.orderSoundOnRequest = false
    end
    if ProfBuddyDB.settings.shareData == nil then
        ProfBuddyDB.settings.shareData = true
    end
    if ProfBuddyDB.settings.autoAddParty == nil then
        ProfBuddyDB.settings.autoAddParty = false
    end

    -- Trust migration: `trusted` now gates serving full data (see Comm.lua).
    -- Earlier builds auto-created a contact for every group-mate ever seen, so a
    -- pre-existing entry proves nothing by itself; autoSync is the only reliable
    -- signal of a deliberately chosen peer. Everyone else re-earns trust with one
    -- Add/Sync action or by being grouped.
    for _, contact in pairs(ProfBuddyDB.contacts) do
        if contact.trusted == nil then
            contact.trusted = contact.autoSync == true
        end
    end

    addon.db = ProfBuddyDB

    -- Canonical character keys. Runs once, with the defaults already in
    -- place and before any module Init reads a key.
    if ProfBuddyDB.schemaVersion < 2 then
        migrateToSchema2(ProfBuddyDB)
        ProfBuddyDB.schemaVersion = 2
    end

    -- Init modules in declared order. A module that errors here must not
    -- take the rest of the addon down with it.
    for _, mod in ipairs(addon.modules) do
        if mod.Init then
            local ok, err = pcall(mod.Init, mod)
            if not ok then
                print("|cff00ccffProfessionBuddy:|r " .. tostring(mod.name)
                    .. " failed to load: " .. tostring(err))
            end
        end
    end

    print("|cff00ccffProfessionBuddy|r v" .. addon.version .. " loaded.  /pb  or  /profbuddy")
end)

-- Full scan on login / reload only. Zoning, instance entry and every other
-- loading screen fire this event too, and a rescan on each one is wasted work.
local didLoginScan = false
addon:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    if isInitialLogin == nil and isReloadingUi == nil then
        if didLoginScan then return end          -- client passed neither arg
        didLoginScan = true
    elseif not (isInitialLogin or isReloadingUi) then
        return
    end

    C_Timer.After(2, function()
        if addon.Scanner then
            addon.Scanner:ScanProfessions()
            addon.Scanner:ScanInventory()
        end
    end)
end)

----------------------------------------------------------------------
-- Module registration helper
----------------------------------------------------------------------
function addon:NewModule(name)
    local mod = { name = name }
    addon[name] = mod
    table.insert(addon.modules, mod)
    return mod
end

----------------------------------------------------------------------
-- /pb reset confirmation. The popup is registered on first use, the same
-- way the bug report frame below is built on first use.
----------------------------------------------------------------------
local function ConfirmReset()
    if not StaticPopupDialogs["PROFBUDDY_CONFIRM_RESET"] then
        StaticPopupDialogs["PROFBUDDY_CONFIRM_RESET"] = {
            text = "Erase all ProfessionBuddy data (characters, contacts, orders and settings) and reload the UI?",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                ProfBuddyDB = nil
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("PROFBUDDY_CONFIRM_RESET")
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_PROFBUDDY1 = "/pb"
SLASH_PROFBUDDY2 = "/profbuddy"

SlashCmdList["PROFBUDDY"] = function(msg)
    local rawMsg = strtrim(msg or "")   -- original case, for name args
    msg = rawMsg:lower()

    if msg == "scan" then
        addon.Scanner:ScanProfessions()
        addon.Scanner:ScanInventory()
        print("|cff00ccffProfessionBuddy:|r Manual scan complete.")

    elseif msg == "chars" then
        addon.CharacterPanel:Toggle()

    elseif msg == "reset" then
        ConfirmReset()

    elseif msg:sub(1, 6) == "forget" then
        -- Take the name from the raw message: lowercasing it would look for
        -- "bob-Realm" while the record is stored as "Bob-Realm".
        local key = addon:NormKey(strtrim(rawMsg:sub(7)))
        local rec = key and addon.db.characters[key]
        if not key then
            print("|cff00ccffProfessionBuddy:|r Usage: /pb forget PlayerName-Realm")
        elseif not rec then
            print("|cff00ccffProfessionBuddy:|r No stored character " .. key .. ".")
        else
            local what = rec.isRemote and "remote" or "local"
            if addon.ForgetCharacter then
                addon:ForgetCharacter(key)          -- DataStore owns the removal
            else
                addon.db.characters[key] = nil
            end
            -- Drop the sync state we hold for that peer as well, or a stale
            -- epoch/seq would make their next update look like a gap.
            if addon.Comm and addon.Comm.ForgetPeer then
                addon.Comm:ForgetPeer(key)
            end
            if addon.db.characters[key] then
                print("|cff00ccffProfessionBuddy:|r Could not forget " .. key .. ".")
            else
                print("|cff00ccffProfessionBuddy:|r Forgot " .. what .. " character " .. key .. ".")
            end
        end

    elseif msg == "friends" then
        -- Close profession window if open
        if addon.TradeSkillFrame and addon.TradeSkillFrame.frame
           and addon.TradeSkillFrame.frame:IsShown() then
            addon.TradeSkillFrame:Hide()
        end
        if addon.FriendsPanel then
            addon.FriendsPanel:Toggle()
        end

    elseif msg == "orders" then
        if addon.OrdersPanel then
            addon.OrdersPanel:Toggle()
        end

    elseif msg == "guild" then
        if addon.GuildPanel then
            addon.GuildPanel:Toggle()
        end

    elseif msg:sub(1, 4) == "comm" or msg:sub(1, 5) == "share" then
        local arg = msg:match("(%a+)$")
        local s = ProfBuddyDB.settings
        if arg == "on" then s.shareData = true
        elseif arg == "off" then s.shareData = false
        else s.shareData = not s.shareData end
        print("|cff00ccffProfessionBuddy:|r data sharing is now "
            .. (s.shareData and "ON." or "OFF (no profession/inventory data sent to others)."))

    elseif msg == "debug" then
        local s = ProfBuddyDB.settings
        s.debugComm = not s.debugComm
        print("|cff00ccffProfessionBuddy:|r comm debug is now "
            .. (s.debugComm and "ON." or "OFF."))

    elseif msg:sub(1, 4) == "sync" then
        -- Take the target from the raw message: lowercasing the name would save
        -- the contact as "bob-Realm" while replies arrive from "Bob-Realm".
        local target = strtrim(rawMsg:sub(5))
        if target == "" then
            print("|cff00ccffProfessionBuddy:|r Usage: /pb sync PlayerName-Realm")
        elseif addon.Comm then
            addon.Comm:RequestSync(target, true)
        end

    elseif msg == "config" or msg == "settings" then
        if addon.TradeSkillFrame then
            local tsf = addon.TradeSkillFrame
            local tsfOpen = tsf.frame and tsf.frame:IsShown()
            local mainOpen = addon.UI and addon.UI.frame and addon.UI.frame:IsShown()

            if tsfOpen and tsf.settingsPanel and tsf.settingsPanel:IsShown() then
                -- Already in settings, toggle it off
                tsf:ToggleSettings()
            elseif tsfOpen then
                tsf:OpenSettings("profession")
            elseif mainOpen then
                if addon.OrdersPanel then addon.OrdersPanel:CaptureHistoryState() end
                addon.UI:Hide()
                tsf:OpenSettings("main")
            else
                tsf:OpenSettings("main")
            end
        end

    elseif msg == "bug" or msg == "report" then
        addon:ShowBugReport()

    elseif msg == "skillreq" then
        local ov = ProfBuddyDB.skillReqOverrides or {}
        local RDB = addon.RecipeDB
        local n = 0
        print("|cff00ccffProfessionBuddy:|r trainer-scanned learn-level reconciliations:")
        for name, tv in pairs(ov) do
            n = n + 1
            local static = RDB and RDB:StaticSkillReq(name)
            if static and static ~= tv then
                print(string.format("  %s: static %d -> trainer %d  (correction)", name, static, tv))
            else
                print(string.format("  %s: trainer %d  (gap-fill; static had none)", name, tv))
            end
        end
        if n == 0 then print("  (none yet -- visit profession trainers to build this up)") end

    else
        -- Default: open the /pb main window.
        -- Close profession window / settings if open first.
        if addon.TradeSkillFrame then
            local tsf = addon.TradeSkillFrame
            if tsf.frame and tsf.frame:IsShown() then
                tsf:Hide()
            end
        end
        if addon.CharacterPanel then
            addon.CharacterPanel:Toggle()
        else
            print("|cff00ccffProfessionBuddy:|r Use /pb chars, /pb scan, /pb forget, /pb reset, /pb bug")
        end
    end
end

----------------------------------------------------------------------
-- /pb bug -- pre-fills safe context + a template into a selectable editbox to
-- copy into a GitHub issue (WoW has no clipboard API). Deliberately no
-- BugGrabber auto-pull -- it'd grab whatever unrelated error was last caught.
----------------------------------------------------------------------
local BUG_URL = "https://github.com/m4ru92/ProfessionBuddy/issues"

local function BuildBugReport()
    local wv, wb, _, wtoc = GetBuildInfo()

    -- Known professions (name + skill) from THIS character's scanned data --
    -- highly relevant for a profession addon, and it's the user's own char.
    local profStr = "(none scanned yet -- open your professions, then re-run)"
    local key = addon.PlayerKey and addon:PlayerKey()
    local ds = addon.DataStore
    local char = key and ds and ds.GetCharacter and ds:GetCharacter(key)
    if char and char.professions then
        local names = {}
        for pname, pdata in pairs(char.professions) do
            names[#names + 1] = pname .. " " .. (pdata.skillLevel or 0)
        end
        table.sort(names)
        if #names > 0 then profStr = table.concat(names, ", ") end
    end

    local _, class = UnitClass("player")
    return table.concat({
        "== ProfessionBuddy Bug Report ==",
        "PB version: " .. (addon.version or "?"),
        "WoW: " .. (wv or "?") .. " (" .. (wb or "?") .. ") interface " .. (wtoc or "?"),
        "Locale: " .. GetLocale(),
        "Character: level " .. UnitLevel("player") .. " " .. (UnitRace("player") or "?")
            .. " " .. (class or "?") .. " (" .. (UnitFactionGroup("player") or "?") .. ")",
        "Professions: " .. profStr,
        "",
        "What happened:",
        "",
        "",
        "What I expected:",
        "",
        "",
        "Steps to reproduce:",
        "1. ",
        "2. ",
        "3. ",
        "",
        "Other addons possibly involved (optional):",
        "",
        "ProfessionBuddy Lua errors (if applicable -- paste from BugSack / BugGrabber):",
        "",
    }, "\n")
end

function addon:ShowBugReport()
    local f = addon.bugFrame
    if not f then
        f = CreateFrame("Frame", "PBBugReportFrame", UIParent, "BackdropTemplate")
        addon.bugFrame = f
        f:SetSize(480, 440)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        title:SetText("ProfessionBuddy  \226\128\148  Bug Report")

        local instr = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instr:SetPoint("TOPLEFT", 16, -40)
        instr:SetPoint("TOPRIGHT", -16, -40)
        instr:SetJustifyH("LEFT")
        instr:SetText("Fill in the blanks, press |cffffd100Ctrl+C|r to copy, then paste into a new issue at:\n|cff33ccffgithub.com/m4ru92/ProfessionBuddy/issues|r")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)

        -- Bordered box holding a multiline editbox. No ScrollFrame: HighlightText
        -- copies the whole buffer regardless of what's scrolled into view, and a
        -- plain multiline editbox scrolls to the cursor while editing.
        local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
        box:SetPoint("TOPLEFT", 14, -80)
        box:SetPoint("BOTTOMRIGHT", -14, 46)
        box:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.5)
        box:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.9)

        local eb = CreateFrame("EditBox", nil, box)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(false)
        eb:SetPoint("TOPLEFT", 8, -8)
        eb:SetPoint("BOTTOMRIGHT", -8, 8)
        eb:SetJustifyH("LEFT")
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f.eb = eb

        local selBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selBtn:SetSize(120, 22)
        selBtn:SetPoint("BOTTOMLEFT", 14, 14)
        selBtn:SetText("Select All")
        selBtn:SetScript("OnClick", function() eb:SetFocus(); eb:HighlightText() end)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(120, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", -14, 14)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        tinsert(UISpecialFrames, "PBBugReportFrame") -- Esc closes it
    end

    f.eb:SetText(BuildBugReport())
    f:Show()
    f.eb:SetFocus()
    f.eb:HighlightText()
end

----------------------------------------------------------------------
-- Utility: safe item ID extraction from a link
----------------------------------------------------------------------
function addon:ItemIDFromLink(link)
    if not link then return nil end
    local id = link:match("item:(%d+)")
    return id and tonumber(id) or nil
end

----------------------------------------------------------------------
-- Utility: class color for display
----------------------------------------------------------------------
function addon:ClassColor(class)
    local colors = RAID_CLASS_COLORS[class]
    if colors then
        return format("|cff%02x%02x%02x", colors.r * 255, colors.g * 255, colors.b * 255)
    end
    return "|cffffffff"
end
