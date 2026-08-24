----------------------------------------------------------------------
-- ProfessionBuddy  --  Scanner.lua
-- Scans profession windows, inventories, banks, and trainers
----------------------------------------------------------------------

local addon = ProfBuddy
local Scanner = addon:NewModule("Scanner")
local DS -- set in Init (DataStore reference)

-- TBCCA uses the modern client; container APIs live under C_Container
local GetContainerNumSlots  = C_Container and C_Container.GetContainerNumSlots  or GetContainerNumSlots
local GetContainerItemLink  = C_Container and C_Container.GetContainerItemLink  or GetContainerItemLink
local GetContainerItemInfo  = C_Container and C_Container.GetContainerItemInfo  or GetContainerItemInfo

-- GetSpellInfo is a global on the Classic/Anniversary client; shim the
-- modern C_Spell form just in case a future build moves it.
local GetSpellInfo = GetSpellInfo or function(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    return info and info.name
end

-- Extract the locale-stable recipe spell ID from a trade/craft recipe link.
-- Trade & Craft recipe links are of the form |...|Henchant:SPELLID|h[Name]|h|r.
-- Returns nil if the link is missing or unparseable (callers fall back to name).
local function RecipeSpellID(link)
    if not link then return nil end
    local id = link:match("enchant:(%d+)") or link:match("spell:(%d+)")
    return id and tonumber(id) or nil
end

----------------------------------------------------------------------
-- Locale-stable profession identity (L10N item 9.5)
--
-- PB stores professions under their English names. The game's
-- skill-line / trade-window APIs return LOCALIZED names, so on a
-- non-enUS client the old English-keyed checks + the "Mining"->
-- "Smelting" string remap silently mis-bucketed or dropped
-- professions. We canonicalize back to English two ways:
--   1. Window scans: derive the profession from the SCANNED recipe
--      spellIDs via RDB.spellToRecipe (fully locale-stable; also
--      makes the Mining->Smelting remap redundant since smelting
--      recipes register under "Smelting").
--   2. Login/trainer scans (no recipe spellIDs handy): translate the
--      localized name via a runtime map built from profession spell
--      IDs. enUS self-maps, so English clients are byte-identical.
----------------------------------------------------------------------

-- Canonical English profession -> a spell whose GetSpellInfo() name
-- equals the profession's SKILL-LINE name in every locale (that's what
-- GetSkillLineInfo/GetTradeSkillLine return, so the strings must match).
-- Verified against Blizzard DB2 (build 2.5.5.68101) in enUS/deDE/frFR.
-- NOTE: Herbalism uses 9134 ("Herbalism"/"Kräuterkunde"/"Herboristerie"),
-- NOT the gathering spell 2366 -- that one is named "Herb Gathering" /
-- "Kräutersammeln" / "Cueillette" and would never match the skill line.
local PROF_SPELLS = {
    ["Alchemy"]        = 2259,  ["Blacksmithing"] = 2018,
    ["Cooking"]        = 2550,  ["Enchanting"]    = 7411,
    ["Engineering"]    = 4036,  ["First Aid"]     = 3273,
    ["Fishing"]        = 7620,  ["Herbalism"]     = 9134,
    ["Jewelcrafting"]  = 25229, ["Leatherworking"] = 2108,
    ["Mining"]         = 2575,  ["Skinning"]      = 8613,
    ["Tailoring"]      = 3908,  ["Smelting"]      = 2656,
}

local profLocaleMap  -- localizedName -> canonicalEnglish (built once, lazily)
local function BuildProfLocaleMap()
    profLocaleMap = {}
    for english, spellID in pairs(PROF_SPELLS) do
        -- enUS self-map: guarantees no behaviour change on English clients
        profLocaleMap[english] = english
        local localized = GetSpellInfo(spellID)
        if localized then profLocaleMap[localized] = english end
    end
end

-- Translate a (possibly localized) profession/skill-line name to the
-- English key PB stores under. Idempotent; returns the input unchanged
-- if we don't recognise it.
function Scanner:Canonicalize(name)
    if not name then return name end
    if not profLocaleMap then BuildProfLocaleMap() end
    return profLocaleMap[name] or name
end

-- Identify a profession from a freshly-scanned recipes table by
-- looking its recipe spellIDs up in the static DB (locale-stable).
-- Majority vote so a single cross-registered recipe can't mislead.
-- Returns nil if nothing resolves (caller falls back to the name path).
function Scanner:ProfessionFromRecipes(recipes)
    local RDB = addon.RecipeDB
    if not RDB or not RDB.spellToRecipe or not recipes then return nil end
    local tally = {}
    for _, r in pairs(recipes) do
        if r.spellID then
            local hit = RDB.spellToRecipe[r.spellID]
            if hit and hit.profName then
                tally[hit.profName] = (tally[hit.profName] or 0) + 1
            end
        end
    end
    local best, bestN = nil, 0
    for prof, n in pairs(tally) do
        if n > bestN then best, bestN = prof, n end
    end
    return best
end

function Scanner:Init()
    DS = addon.DataStore

    -- Profession window events
    addon:RegisterEvent("TRADE_SKILL_SHOW",  function() self:ScanCurrentTradeSkill() end)
    addon:RegisterEvent("TRADE_SKILL_UPDATE", function() self:ScanCurrentTradeSkill() end)
    addon:RegisterEvent("CRAFT_SHOW",        function() self:ScanCurrentCraft() end)
    addon:RegisterEvent("CRAFT_UPDATE",      function() self:ScanCurrentCraft() end)

    -- Inventory events
    addon:RegisterEvent("BAG_UPDATE",         function() self:ScanInventory() end)
    addon:RegisterEvent("BANKFRAME_OPENED",   function() self:ScanBank() end)
    addon:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function() self:ScanBank() end)

    -- Trainer events
    addon:RegisterEvent("TRAINER_SHOW",      function() self:ScanTrainer() end)
    addon:RegisterEvent("TRAINER_UPDATE",    function() self:ScanTrainer() end)

    -- Level-up
    addon:RegisterEvent("PLAYER_LEVEL_UP",   function() DS:EnsureCharacter() end)
end

----------------------------------------------------------------------
-- Profession scanning
----------------------------------------------------------------------
function Scanner:ScanProfessions()
    DS:EnsureCharacter()

    -- In TBC Classic, GetProfessions() doesn't exist.
    -- We scan professions when their windows open (TRADE_SKILL_SHOW).
    -- On login we can get the names + skill from the spellbook via GetSkillLineInfo.
    local numSkills = GetNumSkillLines()
    for i = 1, numSkills do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if not isHeader and name then
            local isProfession = self:IsCraftingProfession(name) or self:IsGatheringProfession(name)
            if isProfession then
                -- Store under the English key, not the localized skill-line name
                local canon = self:Canonicalize(name)
                local existing = DS:GetProfession(nil, canon) or {}
                existing.skillLevel = rank
                existing.maxSkill   = maxRank
                existing.recipes    = existing.recipes or {}
                DS:SetProfessionData(canon, existing)
            end
        end
    end
end

function Scanner:IsCraftingProfession(name)
    name = self:Canonicalize(name)
    local crafting = {
        ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
        ["Enchanting"] = true, ["Engineering"] = true, ["Jewelcrafting"] = true,
        ["Leatherworking"] = true, ["Tailoring"] = true, ["First Aid"] = true,
    }
    return crafting[name]
end

function Scanner:IsGatheringProfession(name)
    name = self:Canonicalize(name)
    local gathering = {
        ["Herbalism"] = true, ["Mining"] = true, ["Skinning"] = true, ["Fishing"] = true,
    }
    return gathering[name]
end

----------------------------------------------------------------------
-- TradeSkill window scanning (Alchemy, BS, Cooking, Engi, JC, LW, Tailoring)
----------------------------------------------------------------------
function Scanner:ScanCurrentTradeSkill()
    local rawName, rank, maxRank = GetTradeSkillLine()
    if not rawName or rawName == "UNKNOWN" then return end

    local recipes = {}
    local numRecipes = GetNumTradeSkills()

    for i = 1, numRecipes do
        local skillName, skillType, numAvail, isExpanded = GetTradeSkillInfo(i)

        -- skillType: "header", "subheader", "optimal", "medium", "easy", "trivial"
        if skillName and skillType ~= "header" and skillType ~= "subheader" then
            local itemLink = GetTradeSkillItemLink(i)
            local itemID   = addon:ItemIDFromLink(itemLink)
            local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
            local spellID  = RecipeSpellID(recipeLink)

            -- Gather reagents (iterate until nil -- GetNumTradeSkillReagents removed in modern client)
            local reagents = {}
            for j = 1, 12 do
                local rName, rTexture, rCount, rPlayerCount = GetTradeSkillReagentInfo(i, j)
                if not rName then break end
                local rLink = GetTradeSkillReagentItemLink(i, j)
                local rID   = addon:ItemIDFromLink(rLink)
                table.insert(reagents, {
                    itemID = rID,
                    name   = rName,
                    count  = rCount,
                    icon   = rTexture,
                })
            end

            local icon = GetTradeSkillIcon(i)
            -- Active profession cooldown (transmutes, specialty cloths, etc.):
            -- store an ABSOLUTE ready-time so remaining stays correct across relog.
            local cd = GetTradeSkillCooldown and GetTradeSkillCooldown(i)

            recipes[skillName] = {
                index    = i,
                itemID   = itemID,
                spellID  = spellID,
                itemLink = itemLink,
                icon     = icon,
                difficulty = skillType,
                numAvail = numAvail,
                reagents = reagents,
                cooldownReadyAt = (cd and cd > 0) and (time() + cd) or nil,
            }
        end
    end

    -- Locale-stable profession identity: derive from the scanned recipe
    -- spellIDs (smelting recipes resolve straight to "Smelting", so the
    -- old Mining->Smelting string hack is only a last-resort fallback).
    local profName = self:ProfessionFromRecipes(recipes) or self:Canonicalize(rawName)
    if profName == "Mining" then profName = "Smelting" end

    DS:SetProfessionData(profName, {
        skillLevel = rank,
        maxSkill   = maxRank,
        recipes    = recipes,
    })
end

----------------------------------------------------------------------
-- Craft window scanning (Enchanting uses the Craft API, not TradeSkill)
----------------------------------------------------------------------
function Scanner:ScanCurrentCraft()
    local rawName, rank, maxRank = GetCraftDisplaySkillLine()

    local recipes = {}
    local numCrafts = GetNumCrafts()

    for i = 1, numCrafts do
        local craftName, _, craftType = GetCraftInfo(i)
        if craftName and craftType ~= "header" then
            local itemLink = GetCraftItemLink(i)
            local itemID   = addon:ItemIDFromLink(itemLink)
            local recipeLink = GetCraftRecipeLink and GetCraftRecipeLink(i)
            local spellID  = RecipeSpellID(recipeLink)
            local icon     = GetCraftIcon(i)

            local reagents = {}
            for j = 1, 12 do
                local rName, rTexture, rCount, rPlayerCount = GetCraftReagentInfo(i, j)
                if not rName then break end
                local rLink = GetCraftReagentItemLink(i, j)
                local rID   = addon:ItemIDFromLink(rLink)
                table.insert(reagents, {
                    itemID = rID,
                    name   = rName,
                    count  = rCount,
                    icon   = rTexture,
                })
            end

            recipes[craftName] = {
                index    = i,
                itemID   = itemID,
                spellID  = spellID,
                itemLink = itemLink,
                icon     = icon,
                difficulty = craftType,
                reagents = reagents,
            }
        end
    end

    -- Derive from scanned recipe spellIDs; fall back to the (canonicalized)
    -- craft skill line, then to Enchanting (the Craft window is ~always it).
    local profName = self:ProfessionFromRecipes(recipes) or self:Canonicalize(rawName)
    if not profName or profName == "" then
        profName = "Enchanting"
    end

    DS:SetProfessionData(profName, {
        skillLevel = rank,
        maxSkill   = maxRank,
        recipes    = recipes,
    })
end

----------------------------------------------------------------------
-- Trainer scanning -- "What's Training?" for professions
----------------------------------------------------------------------
-- Reconcile trainer-scanned learn levels against the static RecipeDB skillReq,
-- recording corrections/gap-fills in ProfBuddyDB.skillReqOverrides (the display
-- prefers these). Silent unless settings.skillReqNotify is set. See DESIGN-NOTES.
function Scanner:ReconcileSkillReq(recipes)
    local RDB = addon.RecipeDB
    if not (RDB and addon.db and recipes) then return end
    addon.db.skillReqOverrides = addon.db.skillReqOverrides or {}
    local ov = addon.db.skillReqOverrides
    local newCorrections = 0
    for name, info in pairs(recipes) do
        local tv = info.skillReq
        if tv and tv > 0 and ov[name] ~= tv then
            local static = RDB:StaticSkillReq(name)
            if static ~= tv then
                ov[name] = tv
                if static then newCorrections = newCorrections + 1 end   -- correction, not gap-fill
            end
        end
    end
    if newCorrections > 0 and addon.db.settings and addon.db.settings.skillReqNotify then
        print(string.format("|cff00ccffProfessionBuddy:|r reconciled %d trainer learn-level correction%s (/pb skillreq to view).",
            newCorrections, newCorrections == 1 and "" or "s"))
    end
end

function Scanner:ScanTrainer()
    -- Determine which profession this trainer teaches
    -- We check if a trade skill or craft window is also open
    local profName = GetTradeSkillLine()
    if not profName or profName == "UNKNOWN" then
        -- Try the Craft API (Enchanting trainers)
        profName = GetCraftDisplaySkillLine()
        if not profName or profName == "" then
            profName = "Unknown"
        end
    end
    -- Canonicalize the localized skill-line name to the English key
    profName = self:Canonicalize(profName)
    -- TBCCA returns "Mining" for the Smelting window
    if profName == "Mining" then profName = "Smelting" end

    local available = {}
    local numServices = GetNumTrainerServices()

    for i = 1, numServices do
        local name, _, category = GetTrainerServiceInfo(i)
        -- category: "available", "unavailable", "used" (already known)
        if name and category ~= "used" then
            local skillReq = GetTrainerServiceSkillReq(i)
            local cost = GetTrainerServiceCost(i)
            local link = GetTrainerServiceItemLink(i)

            available[name] = {
                category  = category,       -- "available" or "unavailable"
                skillReq  = skillReq or 0,
                cost      = cost or 0,
                itemLink  = link,
                itemID    = addon:ItemIDFromLink(link),
            }
        end
    end

    if profName ~= "Unknown" then
        DS:SetTrainerRecipes(profName, available)
        self:ReconcileSkillReq(available)
    end
end

----------------------------------------------------------------------
-- Inventory scanning
----------------------------------------------------------------------
function Scanner:ScanInventory()
    DS:EnsureCharacter()

    local items = {}

    -- Backpack (bag 0) + 4 regular bags
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = addon:ItemIDFromLink(link)
                local info = GetContainerItemInfo(bag, slot)
                local count = info and (info.stackCount or info.count) or nil
                if id and count then
                    items[id] = (items[id] or 0) + count
                end
            end
        end
    end

    DS:SetInventory("bags", items)
end

function Scanner:ScanBank()
    local items = {}

    -- Bank container (bag -1) + bank bags (5-11)
    local bankBags = { -1, 5, 6, 7, 8, 9, 10, 11 }
    for _, bag in ipairs(bankBags) do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = addon:ItemIDFromLink(link)
                local info = GetContainerItemInfo(bag, slot)
                local count = info and (info.stackCount or info.count) or nil
                if id and count then
                    items[id] = (items[id] or 0) + count
                end
            end
        end
    end

    DS:SetInventory("bank", items)
end
