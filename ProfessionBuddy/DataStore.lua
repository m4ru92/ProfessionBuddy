----------------------------------------------------------------------
-- ProfessionBuddy  --  DataStore.lua
-- Persistence layer for cross-character profession and inventory data
----------------------------------------------------------------------

local addon = ProfBuddy
local DS = addon:NewModule("DataStore")

----------------------------------------------------------------------
-- Ensure the current character has a record
----------------------------------------------------------------------
function DS:EnsureCharacter()
    local key = addon:PlayerKey()
    local db = addon.db.characters

    if not db[key] then
        db[key] = {
            class       = select(2, UnitClass("player")),
            level       = UnitLevel("player"),
            faction     = UnitFactionGroup("player"),
            professions = {},
            inventory   = { bags = {}, bank = {}, bankScanned = false },
            trainerCache = {},
            lastScan    = 0,
        }
    end

    -- Always refresh volatile fields
    db[key].level = UnitLevel("player")
    return db[key]
end

----------------------------------------------------------------------
-- Getters
----------------------------------------------------------------------
function DS:GetCharacter(key)
    key = key or addon:PlayerKey()
    return addon.db.characters[key]
end

function DS:GetAllCharacters()
    return addon.db.characters
end

function DS:GetProfession(charKey, profName)
    local char = self:GetCharacter(charKey)
    return char and char.professions[profName]
end

----------------------------------------------------------------------
-- Setters (called by Scanner)
----------------------------------------------------------------------
function DS:SetProfessionData(profName, data)
    local char = self:EnsureCharacter()
    char.professions[profName] = data
    char.lastScan = time()
end

function DS:SetInventory(location, items)
    local char = self:EnsureCharacter()
    char.inventory[location] = items
    if location == "bank" then
        char.inventory.bankScanned = true
    end
    char.lastScan = time()
end

function DS:SetTrainerRecipes(profName, recipes)
    local char = self:EnsureCharacter()
    char.trainerCache[profName] = {
        recipes = recipes,
        scannedAt = time(),
    }
end

----------------------------------------------------------------------
-- Remote character management (friend/contact data from Comm)
----------------------------------------------------------------------

function DS:SetRemoteCharacter(key, data)
    data.isRemote = true
    data.lastSync = time()
    addon.db.characters[key] = data
end

function DS:IsRemote(key)
    local char = addon.db.characters[key]
    return char and char.isRemote or false
end

function DS:RemoveRemoteCharacter(key)
    local char = addon.db.characters[key]
    if char and char.isRemote then
        addon.db.characters[key] = nil
    end
end

----------------------------------------------------------------------
-- Cross-character queries
----------------------------------------------------------------------

-- Returns { [itemID] = totalCount } across all LOCAL characters (bags + bank)
-- Remote characters are excluded; use GetCalcItemCounts for setting-aware queries.
function DS:GetGlobalItemCounts()
    local totals = {}
    for _, char in pairs(addon.db.characters) do
        if not char.isRemote then
            for id, count in pairs(char.inventory.bags or {}) do
                totals[id] = (totals[id] or 0) + count
            end
            for id, count in pairs(char.inventory.bank or {}) do
                totals[id] = (totals[id] or 0) + count
            end
        end
    end
    return totals
end

-- Returns { [itemID] = totalCount } for a single character
function DS:GetCharItemCounts(charKey)
    local char = addon.db.characters[charKey]
    if not char then return {} end
    local totals = {}
    for id, count in pairs(char.inventory.bags or {}) do
        totals[id] = (totals[id] or 0) + count
    end
    for id, count in pairs(char.inventory.bank or {}) do
        totals[id] = (totals[id] or 0) + count
    end
    return totals
end

-- Returns { [itemID] = totalCount } respecting includeAltsInCalc,
-- showCrossFactionAlts, and includeRemoteInCalc settings.
function DS:GetCalcItemCounts()
    local settings = addon.db.settings
    local myKey = addon:PlayerKey()
    local myFaction = UnitFactionGroup("player")
    local crossFaction = settings.showCrossFactionAlts
    local includeAlts = settings.includeAltsInCalc
    local includeRemote = settings.includeRemoteInCalc

    local totals = {}
    for key, char in pairs(addon.db.characters) do
        local isCurrent = (key == myKey)
        -- Alt and friend inclusion are independent toggles; the current
        -- character is always counted.
        local typeOK = isCurrent
            or (char.isRemote and includeRemote)
            or (not char.isRemote and includeAlts)
        if typeOK and (isCurrent or crossFaction or char.faction == myFaction) then
            local inv = char.inventory
            for id, count in pairs(inv and inv.bags or {}) do
                totals[id] = (totals[id] or 0) + count
            end
            for id, count in pairs(inv and inv.bank or {}) do
                totals[id] = (totals[id] or 0) + count
            end
        end
    end
    return totals
end

-- Returns { charKey = count, ... } for a specific item
function DS:WhoHasItem(itemID)
    local result = {}
    for key, char in pairs(addon.db.characters) do
        local count = 0
        count = count + (char.inventory.bags[itemID] or 0)
        count = count + (char.inventory.bank[itemID] or 0)
        if count > 0 then
            result[key] = count
        end
    end
    return result
end

-- Returns { profName = { charKey1, charKey2, ... }, ... }
function DS:GetProfessionMap()
    local map = {}
    for key, char in pairs(addon.db.characters) do
        for profName, _ in pairs(char.professions) do
            map[profName] = map[profName] or {}
            table.insert(map[profName], key)
        end
    end
    return map
end

-- Can any character craft itemID? Returns { charKey = profName }
function DS:WhoCrafts(itemID)
    local crafters = {}
    for key, char in pairs(addon.db.characters) do
        for profName, profData in pairs(char.professions) do
            if profData.recipes then
                for _, recipe in pairs(profData.recipes) do
                    if recipe.itemID == itemID then
                        crafters[key] = profName
                    end
                end
            end
        end
    end
    return crafters
end
