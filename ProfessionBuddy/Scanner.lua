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
                local existing = DS:GetProfession(nil, name) or {}
                existing.skillLevel = rank
                existing.maxSkill   = maxRank
                existing.recipes    = existing.recipes or {}
                DS:SetProfessionData(name, existing)
            end
        end
    end
end

function Scanner:IsCraftingProfession(name)
    local crafting = {
        ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
        ["Enchanting"] = true, ["Engineering"] = true, ["Jewelcrafting"] = true,
        ["Leatherworking"] = true, ["Tailoring"] = true, ["First Aid"] = true,
    }
    return crafting[name]
end

function Scanner:IsGatheringProfession(name)
    local gathering = {
        ["Herbalism"] = true, ["Mining"] = true, ["Skinning"] = true, ["Fishing"] = true,
    }
    return gathering[name]
end

----------------------------------------------------------------------
-- TradeSkill window scanning (Alchemy, BS, Cooking, Engi, JC, LW, Tailoring)
----------------------------------------------------------------------
function Scanner:ScanCurrentTradeSkill()
    local profName, rank, maxRank = GetTradeSkillLine()
    if not profName or profName == "UNKNOWN" then return end
    -- TBCCA returns "Mining" from GetTradeSkillLine() for the Smelting window
    if profName == "Mining" then profName = "Smelting" end

    local recipes = {}
    local numRecipes = GetNumTradeSkills()

    for i = 1, numRecipes do
        local skillName, skillType, numAvail, isExpanded = GetTradeSkillInfo(i)

        -- skillType: "header", "subheader", "optimal", "medium", "easy", "trivial"
        if skillName and skillType ~= "header" and skillType ~= "subheader" then
            local itemLink = GetTradeSkillItemLink(i)
            local itemID   = addon:ItemIDFromLink(itemLink)

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

            recipes[skillName] = {
                index    = i,
                itemID   = itemID,
                itemLink = itemLink,
                icon     = icon,
                difficulty = skillType,
                numAvail = numAvail,
                reagents = reagents,
            }
        end
    end

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
    local profName, rank, maxRank = GetCraftDisplaySkillLine()
    if not profName or profName == "" then
        profName = "Enchanting"  -- Craft window is almost always Enchanting in TBC
    end

    local recipes = {}
    local numCrafts = GetNumCrafts()

    for i = 1, numCrafts do
        local craftName, _, craftType = GetCraftInfo(i)
        if craftName and craftType ~= "header" then
            local itemLink = GetCraftItemLink(i)
            local itemID   = addon:ItemIDFromLink(itemLink)
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
                itemLink = itemLink,
                icon     = icon,
                difficulty = craftType,
                reagents = reagents,
            }
        end
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
