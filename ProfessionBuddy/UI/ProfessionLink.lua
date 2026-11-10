----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/ProfessionLink.lua
-- WoW: Forever: open another player's profession link in PB's window.
-- The game does not open other players' profession links on Forever (2.0.2
-- tests, PROFESSION-LINK-scope.md), so PB opens links from the players it
-- already shares data with: guildmates, group members and PB friends.
-- A profession link carries the poster's GUID, the profession spell and
-- its skill line:  trade:Player-6926-001E5723:2108:165
-- PB finds the poster, opens their stored recipes, and asks them for their
-- recipes the way the Guild tab does (Comm:RequestGuildSync, SYNC_REQ, no
-- comm change), opening them when the reply arrives.
-- A post-hook on SetItemRef: Blizzard's own handling still runs first.
----------------------------------------------------------------------

local addon = ProfBuddy
local PL = addon:NewModule("ProfessionLink")


local function Say(text)
    print("|cff00ccffProfessionBuddy:|r " .. text)
end

local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function Usable(name)
    return type(name) == "string" and not Secret(name) and name ~= ""
end

-- "trade:<guid>:<spell>:<skill line>" -> guid, skill line. The link a
-- SetItemRef hook gets has no "|" codes, only the hyperlink's own text.
function PL:Parse(link)
    if type(link) ~= "string" or Secret(link) or link:sub(1, 6) ~= "trade:" then return nil end
    local guid, _, line = strsplit(":", link:sub(7))
    if not (Usable(guid) and guid:sub(1, 7) == "Player-") then return nil end
    return guid, tonumber(line)
end

-- The poster's key from their GUID: a group member by their unit's GUID,
-- then the name the game gives for the GUID. On WoW: Forever that name can
-- be the first name alone (UnitName gives only that, Core PlayerName), so a
-- first name is matched to the one guildmate or PB friend who has it.
function PL:KeyForGUID(guid)
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    for _, unit in ipairs(units) do
        local g = UnitGUID(unit)
        if g == guid and not Secret(g) then
            local full = GetUnitName(unit, true)
            if Usable(full) then return addon:NormKey(full) end
        end
    end

    local name
    if GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, n = pcall(GetPlayerInfoByGUID, guid)
        if ok and Usable(n) then name = n end
    end
    if not name then return nil end
    if not (addon.Source.FULL_NAMES and not name:find(" ", 1, true)) then
        return addon:NormKey(name)
    end

    -- A first name alone: the one guildmate or PB friend with that first name
    local found
    local function try(key)
        if not key or found == false then return end
        local first = addon:ShortName(key):match("^(%S+)")
        if first == name then
            if found and found ~= key then found = false else found = key end
        end
    end
    local C = addon.Comm
    local set = C and C.GuildSet and C:GuildSet()
    for key in pairs(set or {}) do try(key) end
    for key in pairs(addon.db and addon.db.contacts or {}) do try(addon:NormKey(key)) end
    return found or nil
end

-- Stored recipes for this profession?
function PL:HasRecipes(key, profName)
    return addon.GuildPanel and addon.GuildPanel:HasRecipes(key, profName) or false
end

function PL:Open(key, profName)
    local tsf = addon.TradeSkillFrame
    if tsf and tsf.OpenWithCharacter then tsf:OpenWithCharacter(key, profName) end
end

-- A click on a link in chat
function PL:OnLink(link, button)
    if button and button ~= "LeftButton" then return end
    if IsModifiedClick and IsModifiedClick() then return end
    local guid, line = self:Parse(link)
    if not guid then return end
    -- Your own link: the game opens it, from the recipes your client has
    if guid == UnitGUID("player") then return end
    local profName = addon.Source.ProfForSkillLine and addon.Source:ProfForSkillLine(line)
    if not profName then return end

    local key = self:KeyForGUID(guid)
    if not key then
        Say("Couldn't tell whose profession link that is.")
        return
    end
    local who = addon:ShortName(key)
    local C = addon.Comm
    if not (C and C:TrustLevel(key)) then
        Say("ProfessionBuddy opens " .. who .. "'s " .. profName
            .. " when they're in your guild, your group, or your ProfessionBuddy friends.")
        return
    end

    -- Ask, and open now or when the reply arrives, once: the Guild tab's
    -- path (GuildPanel AskThenOpen, TEST-c G1), with this module's opener
    local GP = addon.GuildPanel
    if GP and GP.AskThenOpen then
        GP:AskThenOpen(key, profName, function(k, p) PL:Open(k, p) end)
    end
end

function PL:Init()
    if addon.Source.flavor ~= "forever" then return end
    if type(SetItemRef) == "function" then
        hooksecurefunc("SetItemRef", function(link, _, button) PL:OnLink(link, button) end)
    end
end
