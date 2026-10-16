----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/Launcher.lua
-- Ways to open PB besides /pb: a LibDataBroker launcher (for display
-- addons that list LDB launchers), a LibDBIcon minimap button on both
-- clients, and on WoW: Forever an entry in the minimap's addon
-- compartment. Left click opens PB as /pb does, right
-- click opens Settings as /pb config does.
----------------------------------------------------------------------

local addon = ProfBuddy
local Launcher = addon:NewModule("Launcher")

local NAME = "ProfessionBuddy"
-- A campfire. WoW: Forever has its own camping icons (Welcoming Campfire,
-- file 7808148); TBC Anniversary does not, so it shows Basic Campfire's
-- icon (spell 818, file 135805, on both clients). Read from each client's
-- ManifestInterfaceData and SpellMisc on wago.tools.
local ICON_FOREVER = "Interface\\Icons\\INV_Camelot_Camping_WelcomingCampfire"
local ICON_TBC     = "Interface\\Icons\\Spell_Fire_Fire"

local function runSlash(msg)
    local handler = SlashCmdList and SlashCmdList["PROFBUDDY"]
    if handler then handler(msg) end
end

function Launcher:Init()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end
    -- Knowledge.lua loads only from the Forever toc
    local icon = addon.Knowledge and ICON_FOREVER or ICON_TBC
    self.object = LDB:NewDataObject(NAME, {
        type = "launcher",
        text = NAME,
        icon = icon,
        OnClick = function(_, button)
            if button == "RightButton" then runSlash("config") else runSlash("") end
        end,
        OnTooltipShow = function(tt)
            if not tt or not tt.AddLine then return end
            tt:AddLine(NAME)
            tt:AddLine("Left-click: open ProfessionBuddy", 1, 1, 1)
            tt:AddLine("Right-click: Settings", 1, 1, 1)
        end,
    })

    local DBI = LibStub("LibDBIcon-1.0", true)
    if not (DBI and self.object) then return end
    local settings = addon.db.settings
    -- Saved settings from before this build have no table: shown, the default.
    if type(settings.minimapIcon) ~= "table" then settings.minimapIcon = { hide = false } end
    DBI:Register(NAME, self.object, settings.minimapIcon)
    self.icon = DBI
    -- WoW: Forever only: TBC Anniversary has no addon compartment, and
    -- LibDBIcon answers false there.
    if DBI.IsButtonCompartmentAvailable and DBI:IsButtonCompartmentAvailable() then
        DBI:AddButtonToCompartment(NAME)
    end
end

-- The Settings check box.
function Launcher:SetMinimapShown(shown)
    local settings = addon.db.settings
    settings.minimapIcon = settings.minimapIcon or {}
    settings.minimapIcon.hide = not shown
    if not self.icon then return end
    if shown then self.icon:Show(NAME) else self.icon:Hide(NAME) end
end

function Launcher:IsMinimapShown()
    local t = addon.db.settings.minimapIcon
    return not (type(t) == "table" and t.hide)
end
