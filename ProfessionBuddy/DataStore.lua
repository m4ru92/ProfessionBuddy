----------------------------------------------------------------------
-- ProfessionBuddy  --  DataStore.lua
-- Persistence layer for cross-character profession and inventory data
----------------------------------------------------------------------

local addon = ProfBuddy
local DS = addon:NewModule("DataStore")

-- Remote records we have not heard from in this many days are dropped at
-- login (contacts are exempt; they are deliberately chosen peers).
local REMOTE_STALE_DAYS = 30

----------------------------------------------------------------------
-- Login housekeeping
----------------------------------------------------------------------
function DS:Init()
    local chars = addon.db and addon.db.characters
    if not chars then return end

    -- trainerCache was written on every trainer visit and never read by
    -- anything. Scanner no longer fills it; drop the persisted copies.
    for _, char in pairs(chars) do
        if type(char) == "table" then char.trainerCache = nil end
    end

    self:PruneRemoteCharacters()
end

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
-- Look a character up by key. The canonical spelling is the normalized one
-- (addon:NormKey), so "Bob-Old Blanchy" and "Bob-OldBlanchy" find the same
-- record. The raw key is tried first so a record written before the schema 2
-- migration, or by a peer still on the old spelling, is still reachable.
function DS:GetCharacter(key)
    if key == nil then key = addon:PlayerKey() end
    local chars = addon.db.characters
    local char = chars[key]
    if char then return char end
    local norm = addon:NormKey(key)
    return norm and chars[norm] or nil
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

----------------------------------------------------------------------
-- Remote character management (friend/contact data from Comm)
----------------------------------------------------------------------

function DS:SetRemoteCharacter(key, data)
    -- Remote data may never clobber a local alt's record.
    local existing = addon.db.characters[key]
    if existing and not existing.isRemote then return end

    local now = time()
    data.isRemote = true
    data.lastSync = now
    data.lastSeen = now      -- drives PruneRemoteCharacters
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

-- Drop remote records we have not heard from in `days` days (default 30).
-- Contacts are never pruned and a local character is never touched. A record
-- carrying no timestamp at all is stamped now so it ages out from this login
-- instead of vanishing on the spot. Returns the number removed.
function DS:PruneRemoteCharacters(days)
    days = tonumber(days) or REMOTE_STALE_DAYS
    if days <= 0 then return 0 end

    local db = addon.db
    local chars = db and db.characters
    if not chars then return 0 end
    local contacts = db.contacts or {}

    local now = time()
    local cutoff = now - days * 86400
    local removed = 0
    for key, char in pairs(chars) do
        if type(char) == "table" and char.isRemote and not contacts[key] then
            -- A non-positive stamp is ABSENT, not ancient: 1.0.3 wrote every
            -- HELLO-only guildmate as lastSync = 0 with no lastSeen, and
            -- tonumber(0) is truthy, so those records were all deleted on the
            -- first 1.1.0 login instead of being stamped.
            local seen = tonumber(char.lastSeen) or tonumber(char.lastSync)
            if not seen or seen <= 0 then
                char.lastSeen = now
            elseif seen < cutoff then
                chars[key] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end

-- /pb forget <Name-Realm>: drop one stored character, local or remote.
-- The character we are logged in as is refused: EnsureCharacter rebuilds it
-- on the next scan, so a delete would only lose the scan history.
function addon:ForgetCharacter(key)
    local chars = addon.db.characters
    local norm = addon:NormKey(key)
    -- Prefer the canonical spelling, fall back to the key exactly as given
    -- (a record written before the schema 2 migration).
    local target
    if norm and chars[norm] then
        target = norm
    elseif type(key) == "string" and chars[key] then
        target = key
    end
    if not target or addon:SameKey(target, addon:PlayerKey()) then return false end
    chars[target] = nil
    return true
end

----------------------------------------------------------------------
-- Cross-character queries
----------------------------------------------------------------------

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
        local inv = char.inventory
        local count = (inv and inv.bags and inv.bags[itemID] or 0)
                    + (inv and inv.bank and inv.bank[itemID] or 0)
        if count > 0 then
            result[key] = count
        end
    end
    return result
end
