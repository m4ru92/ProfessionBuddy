----------------------------------------------------------------------
-- ProfessionBuddy  --  Core.lua
-- Addon bootstrap, event dispatch, slash commands
----------------------------------------------------------------------

ProfBuddy = ProfBuddy or {}

local addon = ProfBuddy
addon.version = "1.0.0"
addon.modules = {}

-- Shorthand for the player's "Name-Realm" key used everywhere
function addon:PlayerKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
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
    if ProfBuddyDB.orderSeq == nil then ProfBuddyDB.orderSeq = 0 end
    ProfBuddyDB.settings = ProfBuddyDB.settings or {
        tooltipShowUsedIn   = true,
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

    addon.db = ProfBuddyDB

    -- Init modules in declared order
    for _, mod in ipairs(addon.modules) do
        if mod.Init then mod:Init() end
    end

    print("|cff00ccffProfessionBuddy|r v" .. addon.version .. " loaded.  /pb  or  /profbuddy")
end)

addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    -- Trigger a full scan on login / reload
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
-- Slash commands
----------------------------------------------------------------------
SLASH_PROFBUDDY1 = "/pb"
SLASH_PROFBUDDY2 = "/profbuddy"

SlashCmdList["PROFBUDDY"] = function(msg)
    msg = strtrim(msg):lower()

    if msg == "scan" then
        addon.Scanner:ScanProfessions()
        addon.Scanner:ScanInventory()
        print("|cff00ccffProfessionBuddy:|r Manual scan complete.")

    elseif msg == "chars" then
        addon.CharacterPanel:Toggle()

    elseif msg == "reset" then
        ProfBuddyDB = nil
        ReloadUI()

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

    elseif msg:sub(1, 4) == "sync" then
        local target = strtrim(msg:sub(5))
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
            print("|cff00ccffProfessionBuddy:|r Use /pb chars, /pb scan, /pb reset")
        end
    end
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
