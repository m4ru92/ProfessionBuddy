----------------------------------------------------------------------
-- Shared stub environment for the WoW: Forever load harnesses.
--
-- Models what matters for "does PB load cleanly on a modern client":
--   * the 11 legacy globals WoW: Forever removed are ABSENT (ForeverProbe,
--     2026-09-22), plus ChatEdit_InsertLink, ChatFrame_AddMessageEventFilter
--     and GuildRoster, which only exist there as deprecated fallbacks;
--   * their C_ replacements are PRESENT and record their calls;
--   * GameTooltip has no OnTooltipSetItem / OnTooltipSetUnit script, and
--     hooking a missing script raises an error, as on the client;
--   * registering an event the Forever client does not know raises an
--     error (TRADE_SKILL_UPDATE, CRAFT_*, UPDATE_TRADESKILL_RECAST: probe);
--   * Blizzard_Professions loads on demand, and ProfessionsFrame opens
--     through ShowUIPanel, as in Blizzard's own `forever` UI source.
-- Any other global a file touches resolves to a do-nothing stub value and
-- is recorded in FALLBACK, so a real missing function shows up there
-- instead of passing silently.
----------------------------------------------------------------------

local BASE = assert(PB_BASE, "PB_BASE not set")

PRINTS = {}
local realPrint = print
function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local line = table.concat(t, " ")
    PRINTS[#PRINTS + 1] = line
    realPrint(line)
end

-- Globals that must NOT exist on Forever. Reading one gives nil.
REMOVED = {
    GetItemInfo = true, GetItemCount = true, GetItemIcon = true,
    GetSpellInfo = true, GetSpellLink = true, GetSpellTexture = true,
    GetContainerNumSlots = true, GetContainerItemInfo = true, GetContainerItemLink = true,
    IsAddOnLoaded = true, GetAddOnMetadata = true,
    ChatEdit_InsertLink = true, ChatFrame_AddMessageEventFilter = true, GuildRoster = true,
    -- the classic profession API, which only Source/Classic.lua may touch
    GetTradeSkillLine = true, GetNumTradeSkills = true, GetTradeSkillInfo = true,
    GetNumCrafts = true, GetCraftInfo = true, GetCraftDisplaySkillLine = true,
    GetNumSkillLines = true, GetSkillLineInfo = true, CloseTradeSkill = true, CloseCraft = true,
    DoTradeSkill = true, DoCraft = true, CraftIsEnchanting = true, CraftIsPetTraining = true,
}
UNKNOWN_EVENTS = {
    TRADE_SKILL_UPDATE = true, CRAFT_SHOW = true, CRAFT_UPDATE = true, CRAFT_CLOSE = true,
    UPDATE_TRADESKILL_RECAST = true,
}

-- A value that is callable, indexable and arithmetic-safe, for UI calls
-- nobody asserts on.
local W = {}
W.__index = function(t, k) local v = setmetatable({}, W); rawset(t, k, v); return v end
W.__call = function() return setmetatable({}, W) end
W.__add = function() return 0 end; W.__sub = W.__add; W.__mul = W.__add; W.__div = W.__add
W.__unm = W.__add; W.__mod = W.__add; W.__pow = W.__add
W.__concat = function(a, b) return (type(a) == "string" and a or "") .. (type(b) == "string" and b or "") end
W.__lt = function() return false end; W.__le = function() return false end
W.__len = function() return 0 end
function NEW() return setmetatable({}, W) end

FALLBACK = {}
-- Globals a file tests for before creating them (libraries, the saved
-- variable) must read nil.
local NOT_YET = { LibStub = true, ChatThrottleLib = true, ProfBuddyDB = true, ProfBuddy = true, ElvUI = true,
                  ProfessionsFrame = true }
setmetatable(_G, { __index = function(_, k)
    if REMOVED[k] or NOT_YET[k] then return nil end
    FALLBACK[k] = true
    local v = NEW(); rawset(_G, k, v); return v
end })

-- ------------------------------------------------------------ frames
FRAMES = {}
REGISTERED = {}
HOOKED = {}
local F = {}
F.__index = function(t, k)
    local m = rawget(F, k); if m then return m end
    local v = NEW(); rawset(t, k, v); return v
end
local TOOLTIP_SCRIPTS_GONE = { OnTooltipSetItem = true, OnTooltipSetUnit = true, OnTooltipSetSpell = true }
function F:SetScript(s, fn) self._s[s] = fn end
function F:GetScript(s) return self._s[s] end
function F:HasScript(s) return not (self._tooltip and TOOLTIP_SCRIPTS_GONE[s]) end
function F:HookScript(s, fn)
    if self._tooltip and TOOLTIP_SCRIPTS_GONE[s] then
        error(("%s doesn't have a \"%s\" script"):format(tostring(self._name), s))
    end
    HOOKED[#HOOKED + 1] = tostring(self._name) .. ":" .. s
    self._h[s] = fn
end
function F:RegisterEvent(e)
    if UNKNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
    REGISTERED[e] = true
    self._ev[e] = true
end
function F:UnregisterEvent(e) self._ev[e] = nil end
function F:UnregisterAllEvents() self._ev = {} end
function F:Show() if not self._shown then self._shown = true
    if self._s.OnShow then self._s.OnShow(self) end end end
function F:Hide() if self._shown then self._shown = false
    if self._s.OnHide then self._s.OnHide(self) end end end
function F:IsShown() return self._shown end
function F:IsVisible() return self._shown end
function F:GetName() return self._name end
function F:SetAttribute(k, v) self._attr[k] = v end
function F:GetAttribute(k) return self._attr[k] end
function F:GetFrameLevel() return 1 end
function F:GetText() return self._text or "" end
function F:SetText(t) self._text = t end
function F:GetWidth() return 100 end
function F:GetHeight() return 100 end
function F:GetVerticalScroll() return 0 end
function F:GetVerticalScrollRange() return 0 end
function F:SetPoint(...) rawset(self, "_points", (rawget(self, "_points") or 0) + 1) end
function F:ClearAllPoints() rawset(self, "_points", 0) end
function F:GetNumPoints() return rawget(self, "_points") or 0 end
function F:IsMouseOver() return false end
function F:GetChecked() return false end
function F:GetValue() return 0 end
function F:GetMinMaxValues() return 0, 0 end
function F:GetParent() return self._parent end
function F:GetChildren() return end
function F:GetRegions() return end
function CreateFrame(kind, name, parent)
    local f = setmetatable({ _s = {}, _h = {}, _attr = {}, _ev = {}, _name = name, _shown = false,
        _parent = parent, _tooltip = (kind == "GameTooltip") }, F)
    FRAMES[#FRAMES + 1] = f
    if name then rawset(_G, name, f) end
    return f
end
UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
UISpecialFrames = {}
UIPanelWindows = {}

-- Blizzard's panel manager, reduced to the branch PB depends on: a frame
-- with a UIPanelWindows entry is laid out by the (secure) manager, any
-- other frame is simply shown. PANEL_MANAGED records which branch ran.
PANEL_MANAGED = {}
function ShowUIPanel(f)
    if not f or f:IsShown() then return end
    PANEL_MANAGED[#PANEL_MANAGED + 1] = UIPanelWindows[f:GetName()] ~= nil
    f:Show()
end
function HideUIPanel(f)
    if not f or not f:IsShown() then return end
    f:Hide()
end

-- Blizzard_UIParentPanelManager/Shared/UIPanelLayoutFrame.lua values.
function GetUIPanelLayoutAttribute(name)
    return ({ TOP_OFFSET = -116, LEFT_OFFSET = 16 })[name]
end

-- EventRegistry, reduced to callbacks keyed by owner.
EventRegistry = { _cb = {} }
function EventRegistry:RegisterCallback(event, fn, owner)
    self._cb[event] = self._cb[event] or {}
    self._cb[event][owner or fn] = fn
end
function EventRegistry:UnregisterCallback(event, owner)
    if self._cb[event] then self._cb[event][owner] = nil end
end
function EventRegistry:TriggerEvent(event, ...)
    local list = {}
    for owner, fn in pairs(self._cb[event] or {}) do list[#list + 1] = { owner, fn } end
    table.sort(list, function(a, b) return (a[1].order or 0) < (b[1].order or 0) end)
    for _, e in ipairs(list) do e[2](...) end
end

function ToggleFrame(f)
    if f:IsShown() then HideUIPanel(f) else ShowUIPanel(f) end
end

-- Blizzard_Professions is load-on-demand: ProfessionsFrame does not exist
-- until the first profession window opens (Blizzard_Professions_Bootstrap:
-- ShowProfessionsFrame loads the addon, which registers the panel and
-- fires ADDON_LOADED, then calls ShowUIPanel). On Forever the same frame
-- is the profession book: a BookPage and a CraftingPage, and hiding it
-- closes the open profession (ProfessionsMixin:OnHide).
function ShowProfessionsFrame()
    if not rawget(_G, "ProfessionsFrame") then
        local f = CreateFrame("Frame", "ProfessionsFrame", UIParent)
        f.BookPage = CreateFrame("Frame", nil, f)
        f.CraftingPage = CreateFrame("Frame", nil, f)
        f.CraftingPage:Show()
        function f:SelectBookPage() self.BookPage:Show(); self.CraftingPage:Hide() end
        -- The profession tabs on the right (Camelot ProfessionsFrame.xml:
        -- LW, Skinning, Cooking here). Each casts its profession on
        -- "ProfessionsFrame.Show" unless it is the one still loaded
        -- (ProfessionsLargeRightTabMixin); the frame fills spellOffsetIndex in
        -- RefreshRightTabs, AFTER that event, so the first show casts nothing.
        f.rightProfessionTabs = {}
        for i, sl in ipairs({ 165, 393, 185 }) do
            local tab = CreateFrame("Frame", nil, f)
            tab.order, tab.skillLine = i, sl
            EventRegistry:RegisterCallback("ProfessionsFrame.Show", function()
                local info = C_TradeSkillUI.GetBaseProfessionInfo()
                if rawget(tab, "spellOffsetIndex") and info.professionID ~= tab.skillLine then
                    C_TradeSkillUI.OpenTradeSkill(tab.skillLine)   -- CastSpellBookItem
                end
            end, tab)
            f.rightProfessionTabs[i] = tab
        end
        f:SetScript("OnShow", function(self)
            EventRegistry:TriggerEvent("ProfessionsFrame.Show")
            for _, tab in ipairs(self.rightProfessionTabs) do tab.spellOffsetIndex = 1 end
        end)
        f:SetScript("OnHide", function() C_TradeSkillUI.CloseTradeSkill() end)
        f:SetScript("OnEvent", function(self, event)
            if event == "TRADE_SKILL_SHOW" then self.BookPage:Hide(); self.CraftingPage:Show() end
        end)
        f:RegisterEvent("TRADE_SKILL_SHOW")
        UIPanelWindows.ProfessionsFrame = { area = "left", pushable = 1, xoffset = 35 }
        FIRE("ADDON_LOADED", "Blizzard_Professions")
    end
    ShowUIPanel(ProfessionsFrame)
end

-- The K key (Blizzard_ProfessionsBook_Bootstrap.lua, forever branch).
function ToggleProfessionsBook()
    if rawget(_G, "ProfessionsFrame") then
        ToggleFrame(ProfessionsFrame)
    else
        ShowProfessionsFrame()
        if ProfessionsFrame and ProfessionsFrame.SelectBookPage then ProfessionsFrame:SelectBookPage() end
    end
end
SOUNDKIT = setmetatable({}, { __index = function() return 0 end })

-- ------------------------------------------------------------ client
WOW_PROJECT_ID = 1
WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
BUILD_INTERFACE = rawget(_G, "BUILD_INTERFACE") or 16001
function GetBuildInfo() return "1.60.1", "69977", "Sep 22 2026", BUILD_INTERFACE end
function PlaySound() end
function InCombatLockdown() return false end
-- Post-hook a global function, as the client does.
function hooksecurefunc(name, fn)
    if type(name) ~= "string" then return end
    local orig = rawget(_G, name)
    if type(orig) ~= "function" then return end
    rawset(_G, name, function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end)
end
Enum = { CraftingReagentType = { Basic = 1 } }
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s or ""):match("^%s*(.-)%s*$") end
function strsplit(sep, s) local out = {}
    for p in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = p end
    return unpack(out) end
function GetTime() return 1000 end
function time() return 5000 end
function date() return "2026-09-24" end
function GetLocale() return "enUS" end
function GetRealmName() return "Realm" end
function UnitName() return "Me" end
function GetUnitName() return "Me" end
function UnitClass() return "Hunter", "HUNTER" end
function UnitRace() return "Tauren", "Tauren" end
function UnitLevel() return 6 end
function UnitFactionGroup() return "Horde" end
function UnitGUID() return "Player-1-00000001" end
function IsShiftKeyDown() return false end
function IsModifiedClick() return false end
function IsInGuild() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
function GetNumSubgroupMembers() return 0 end
function GetNumGuildMembers() return 0 end
function GetProfessions() return nil end
function GetNumTrainerServices() return 0 end

CALLS = {}
local function rec(name, ret) return function(...) CALLS[#CALLS + 1] = name; return ret end end
C_Item = { GetItemInfo = rec("C_Item.GetItemInfo"), GetItemCount = rec("C_Item.GetItemCount", 0),
           GetItemIconByID = rec("C_Item.GetItemIconByID") }
C_Spell = { GetSpellInfo = rec("C_Spell.GetSpellInfo"), GetSpellLink = rec("C_Spell.GetSpellLink"),
            GetSpellTexture = rec("C_Spell.GetSpellTexture") }
C_Container = { GetContainerNumSlots = rec("C_Container.GetContainerNumSlots", 0),
                GetContainerItemInfo = rec("C_Container.GetContainerItemInfo"),
                GetContainerItemLink = rec("C_Container.GetContainerItemLink") }
C_AddOns = { IsAddOnLoaded = rec("C_AddOns.IsAddOnLoaded", false), GetAddOnMetadata = rec("C_AddOns.GetAddOnMetadata") }
C_GuildInfo = { GuildRoster = rec("C_GuildInfo.GuildRoster") }
C_ChatInfo = { SendAddonMessage = rec("C_ChatInfo.SendAddonMessage", 0),
               RegisterAddonMessagePrefix = rec("C_ChatInfo.RegisterAddonMessagePrefix", true),
               IsAddonMessagePrefixRegistered = rec("C_ChatInfo.IsAddonMessagePrefixRegistered", false) }
ChatFrameUtil = { InsertLink = rec("ChatFrameUtil.InsertLink"),
                  AddMessageEventFilter = rec("ChatFrameUtil.AddMessageEventFilter") }
PENDING = {}
C_Timer = { After = function(_, fn) PENDING[#PENDING + 1] = fn end,
            NewTimer = function(_, fn) PENDING[#PENDING + 1] = fn; return { Cancel = function() end } end,
            NewTicker = function() return { Cancel = function() end } end }
function FLUSH() local n = 0
    while #PENDING > 0 and n < 200 do n = n + 1; local fn = table.remove(PENDING, 1); fn() end end

-- ------------------------------------------------------------ loader
-- Load one toc's files in order, the way the client does. libs.xml is
-- expanded to its <Script file="..."/> entries.
function LOAD_TOC(tocName)
    local errs = {}
    local fh = assert(io.open(BASE .. "/" .. tocName, "r"), "no " .. tocName)
    local files = {}
    for line in fh:lines() do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then files[#files + 1] = line end
    end
    fh:close()
    for _, rel in ipairs(files) do
        if rel:match("%.xml$") then
            local dir = rel:match("^(.*)/") or ""
            local x = assert(io.open(BASE .. "/" .. rel, "r"))
            local body = x:read("*a"); x:close()
            for f in body:gmatch('<Script file="([^"]+)"') do
                local p = BASE .. "/" .. dir .. "/" .. f:gsub("\\", "/")
                local ok, err = pcall(dofile, p)
                if not ok then errs[#errs + 1] = p .. ": " .. tostring(err) end
            end
        else
            local ok, err = pcall(dofile, BASE .. "/" .. rel)
            if not ok then errs[#errs + 1] = rel .. ": " .. tostring(err) end
        end
    end
    return files, errs
end

-- Fire an event at every frame registered for it, the way the client does.
function FIRE(event, ...)
    for _, f in ipairs(FRAMES) do
        if f._s.OnEvent and f._ev[event] then f._s.OnEvent(f, event, ...) end
    end
end

function EXPECT(cond, msg) if not cond then error("FAIL: " .. msg, 2) end end
function PRINTED(pat) for _, l in ipairs(PRINTS) do if l:find(pat, 1, true) then return true end end return false end
