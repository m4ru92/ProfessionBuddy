----------------------------------------------------------------------
-- ProfessionBuddy  --  Scanner.lua
-- Scans profession windows, inventories, banks, and trainers
----------------------------------------------------------------------

local addon = ProfBuddy
local Scanner = addon:NewModule("Scanner")
local DS -- set in Init (DataStore reference)

-- TBCCA uses the modern client; container APIs live under C_Container and
-- GetContainerItemInfo returns a table. If a build ever drops C_Container,
-- wrap the legacy multi-return global in the same table shape so the scan
-- loops below stay single-form.
local GetContainerNumSlots, GetContainerItemLink, GetContainerItemInfo
if C_Container then
    GetContainerNumSlots = C_Container.GetContainerNumSlots
    GetContainerItemLink = C_Container.GetContainerItemLink
    GetContainerItemInfo = C_Container.GetContainerItemInfo
else
    local legacySlots = _G.GetContainerNumSlots
    local legacyLink  = _G.GetContainerItemLink
    local legacyInfo  = _G.GetContainerItemInfo
    GetContainerNumSlots = legacySlots or function() return 0 end
    GetContainerItemLink = legacyLink or function() return nil end
    GetContainerItemInfo = legacyInfo and function(bag, slot)
        local texture, count = legacyInfo(bag, slot)
        if texture == nil and count == nil then return nil end
        return { stackCount = count }
    end or function() return nil end
end

-- BAG_UPDATE bursts (looting, mail, vendoring). Leading edge plus one
-- trailing scan: TRADE_SKILL_UPDATE consumers still see fresh counts, and a
-- repeat-craft burst cannot starve the scan by resetting the timer forever.
local BAG_THROTTLE = 0.25
-- SKILL_LINES_CHANGED fires several times for one skill-up, and ScanProfessions
-- raises it itself (see the mute window there), so the rescan is coalesced onto
-- one trailing timer the same way BAG_UPDATE is.
local SKILL_THROTTLE = 0.5
local SKILL_MUTE     = 1
local function Now()
    return (GetTime and GetTime()) or time()
end

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
    -- Rogue class skill. Spell 2842 carries the skill line's own name in
    -- enUS/deDE/frFR (DB2 2.5.6.69110: "Poisons" / "Gifte" / "Poisons").
    ["Poisons"]        = 2842,
}

-- Hoisted out of IsCraftingProfession/IsGatheringProfession: ScanProfessions
-- calls both once per skill line, 20 to 40 times per character.
local CRAFTING_PROFS = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
    ["Enchanting"] = true, ["Engineering"] = true, ["Jewelcrafting"] = true,
    ["Leatherworking"] = true, ["Tailoring"] = true, ["First Aid"] = true,
    ["Poisons"] = true,
}

local GATHERING_PROFS = {
    ["Herbalism"] = true, ["Mining"] = true, ["Skinning"] = true, ["Fishing"] = true,
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

    -- Profession window events, by role through the Source. A flavor with
    -- no such event (no Craft API on WoW: Forever) leaves it nil and it is
    -- simply not registered; registering an unknown event is a hard error.
    local E = addon.Source.EVENT
    if E.TRADE_SHOW   then addon:RegisterEvent(E.TRADE_SHOW,   function() self:ScanCurrentTradeSkill() end) end
    if E.TRADE_UPDATE then addon:RegisterEvent(E.TRADE_UPDATE, function() self:ScanCurrentTradeSkill() end) end
    if E.CRAFT_SHOW   then addon:RegisterEvent(E.CRAFT_SHOW,   function() self:ScanCurrentCraft() end) end
    if E.CRAFT_UPDATE then addon:RegisterEvent(E.CRAFT_UPDATE, function() self:ScanCurrentCraft() end) end

    -- Inventory events
    addon:RegisterEvent("BAG_UPDATE",         function() self:QueueInventoryScan() end)
    -- PLAYERBANKSLOTS_CHANGED also fires when the bank is not queryable (bank
    -- bag purchase, login). ScanBank replaces the stored bank wholesale, so it
    -- runs only between BANKFRAME_OPENED and BANKFRAME_CLOSED.
    addon:RegisterEvent("BANKFRAME_OPENED",   function()
        self._bankOpen = true
        self:ScanBank()
    end)
    addon:RegisterEvent("BANKFRAME_CLOSED",   function() self._bankOpen = false end)
    addon:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function() self:ScanBank() end)

    -- Skill lines. A gathering skill-up, or a recipe or profession learned at a
    -- trainer, moves nothing in a tradeskill window, so ScanProfessions is the
    -- only path that records it -- and Comm's own SKILL_LINES_CHANGED push reads
    -- what we stored, so without this it pushed stale professions forever.
    addon:RegisterEvent("SKILL_LINES_CHANGED", function() self:QueueProfessionScan() end)

    -- Trainer events. The scan reads GetTrainerServiceInfo in the Classic
    -- return order; WoW: Forever returns a different order, so it runs only
    -- with the Classic source loaded.
    if addon.Source.flavor == "classic" then
        addon:RegisterEvent("TRAINER_SHOW",      function() self:ScanTrainer() end)
        addon:RegisterEvent("TRAINER_UPDATE",    function() self:ScanTrainer() end)
    end

    -- Level-up
    addon:RegisterEvent("PLAYER_LEVEL_UP",   function() DS:EnsureCharacter() end)
end

----------------------------------------------------------------------
-- Profession scanning
----------------------------------------------------------------------

-- SKILL_LINES_CHANGED handler: ONE trailing scan per burst. An armed timer is
-- never re-armed while it is pending, and an event raised by our own header
-- expand/collapse (which is delivered a frame or two later, after the scan has
-- returned) is dropped by the mute window ScanProfessions sets. The window
-- expires on the clock, so a scan that errors costs one second of events, never
-- the session.
function Scanner:QueueProfessionScan()
    if self._skillTimer then return end
    if self._skillEventMuteUntil and Now() < self._skillEventMuteUntil then return end
    self._skillTimer = C_Timer.NewTimer(SKILL_THROTTLE, function()
        self._skillTimer = nil
        self:ScanProfessions()
    end)
end

function Scanner:ScanProfessions()
    DS:EnsureCharacter()

    -- ExpandSkillHeader / CollapseSkillHeader below raise SKILL_LINES_CHANGED
    -- themselves, so mute the handler around the scan (set again after the
    -- restore pass, which raises its own). Set unconditionally so both paths
    -- behave the same.
    self._skillEventMuteUntil = Now() + SKILL_MUTE

    -- The Source reads every non-header skill line, expanding collapsed
    -- headers first and re-collapsing the user's by name afterwards (see
    -- Source/Classic.lua). Those expands and collapses raise
    -- SKILL_LINES_CHANGED, which is why the mute brackets this call.
    for _, line in ipairs(addon.Source:ReadProfessionSkills()) do
        local name = line.name
        local isProfession = self:IsCraftingProfession(name) or self:IsGatheringProfession(name)
        if isProfession then
            -- Store under the English key, not the localized skill-line name
            local canon = self:Canonicalize(name)
            local existing = DS:GetProfession(nil, canon) or {}
            existing.skillLevel = line.rank
            existing.maxSkill   = line.maxRank
            existing.recipes    = existing.recipes or {}
            DS:SetProfessionData(canon, existing)
        end
    end

    self._skillEventMuteUntil = Now() + SKILL_MUTE
end

function Scanner:IsCraftingProfession(name)
    return CRAFTING_PROFS[self:Canonicalize(name)]
end

function Scanner:IsGatheringProfession(name)
    return GATHERING_PROFS[self:Canonicalize(name)]
end

----------------------------------------------------------------------
-- TradeSkill window scanning (Alchemy, BS, Cooking, Engi, JC, LW, Tailoring)
----------------------------------------------------------------------
function Scanner:ScanCurrentTradeSkill()
    -- A tradeskill link from another player drives the same window and the
    -- same APIs. Writing that to our own record would replace our recipe list,
    -- our cooldowns and our rank with theirs, and push it to the guild.
    local Source = addon.Source
    if Source:IsLinked(false) then return end

    local rawName, rank, maxRank = Source:GetOpenSkillLine(false)
    if not rawName or rawName == "UNKNOWN" then return end

    -- The window enumerates only the rows the list is currently DISPLAYING,
    -- and SetProfessionData replaces the recipe table wholesale, so a
    -- filtered or collapsed list would delete everything it hides. We cannot
    -- clear the filters ourselves: the stored `index` feeds DoTradeSkill
    -- later and changing the list desyncs it. So detect a partial view and
    -- skip the persist instead.
    local win = Source:ReadOpenWindow(false)
    local partial = false
    if win.nameFilter and win.nameFilter ~= "" then partial = true end
    if win.collapsedHeader then partial = true end   -- rows under it are not in the list

    local recipes = {}
    -- difficulty: "optimal", "medium", "easy", "trivial" (headers already excluded)
    for _, row in ipairs(win.rows) do
        local reagents = {}
        for _, rg in ipairs(row.reagents) do
            table.insert(reagents, {
                itemID = addon:ItemIDFromLink(rg.link),
                name   = rg.name,
                count  = rg.count,
                icon   = rg.icon,
            })
        end

        -- Active profession cooldown (transmutes, specialty cloths, etc.):
        -- store an ABSOLUTE ready-time so remaining stays correct across relog.
        local cd = row.cooldown

        recipes[row.name] = {
            index    = row.index,
            itemID   = addon:ItemIDFromLink(row.itemLink),
            spellID  = RecipeSpellID(row.recipeLink),
            itemLink = row.itemLink,
            icon     = row.icon,
            difficulty = row.difficulty,
            numAvail = row.numAvail,
            reagents = reagents,
            cooldownReadyAt = (cd and cd > 0) and (time() + cd) or nil,
        }
    end

    -- A partial list would delete every recipe it hid. Keep what we have.
    if partial then return end

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

    -- Before 1.1.5 a non-enUS rogue's Poisons was stored under the localized
    -- skill-line name ("Gifte"). It is canonical now, so drop that copy
    -- instead of keeping the profession twice. Only a name that canonicalizes
    -- to the profession just written is touched.
    if rawName ~= profName and self:Canonicalize(rawName) == profName then
        local char = DS:GetCharacter()
        if char and char.professions then char.professions[rawName] = nil end
    end
end

----------------------------------------------------------------------
-- Craft window scanning (Enchanting uses the Craft API, not TradeSkill)
----------------------------------------------------------------------
function Scanner:ScanCurrentCraft()
    -- The Craft API backs hunter pet training as well as Enchanting, and
    -- CRAFT_SHOW fires for both. Without this a hunter opening a pet trainer
    -- stores "Beast Training" as a profession, with every pet ability as a
    -- recipe, and there is no UI to delete it again.
    local Source = addon.Source
    if Source:IsPetTraining() then return end

    local rawName, rank, maxRank = Source:GetOpenSkillLine(true)

    local recipes = {}
    for _, row in ipairs(Source:ReadOpenWindow(true).rows) do
        local reagents = {}
        for _, rg in ipairs(row.reagents) do
            table.insert(reagents, {
                itemID = addon:ItemIDFromLink(rg.link),
                name   = rg.name,
                count  = rg.count,
                icon   = rg.icon,
            })
        end

        recipes[row.name] = {
            index    = row.index,
            itemID   = addon:ItemIDFromLink(row.itemLink),
            spellID  = RecipeSpellID(row.recipeLink),
            itemLink = row.itemLink,
            icon     = row.icon,
            difficulty = row.difficulty,
            numAvail = row.numAvail,
            reagents = reagents,
        }
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
        if type(tv) == "number" and tv > 0 and ov[name] ~= tv then
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
    local available = {}
    local numServices = GetNumTrainerServices()
    local isRecipeTrainer = false
    local RDB = addon.RecipeDB

    for i = 1, numServices do
        local name, _, category = GetTrainerServiceInfo(i)
        -- category: "available", "unavailable", "used" (already known)
        if name and category ~= "used" then
            -- GetTrainerServiceSkillReq can return a non-numeric requirement
            -- (a profession name on spec trainers) AND can return multiple
            -- values (nil plus an extra on header rows). Read ONE value into a
            -- local first: tonumber() on the raw multi-return would take the
            -- extra as a base and error. Anything non-numeric then becomes 0.
            local reqRaw = GetTrainerServiceSkillReq(i)
            available[name] = {
                category  = category,       -- "available" or "unavailable"
                skillReq  = tonumber(reqRaw) or 0,
            }

            -- Is this a PROFESSION trainer? skillReqOverrides is keyed by bare
            -- recipe name, so a class, riding or weapon trainer whose service
            -- names happen to carry a skill requirement must not write into
            -- it. One service matching the static recipe DB is proof enough.
            -- A class-only profession does not count: rogue poisons are taught
            -- by the CLASS trainer by character level, with no skill
            -- requirement, so a match there would open every class-spell
            -- service to the reconcile below.
            if not isRecipeTrainer and RDB and RDB.nameToRecipe then
                for _, ref in ipairs(RDB.nameToRecipe[name] or {}) do
                    if not addon.CLASS_PROFS[ref.profName] then
                        isRecipeTrainer = true
                        break
                    end
                end
            end
        end
    end

    -- ReconcileSkillReq is profession-agnostic, so it runs whether or not a
    -- tradeskill window happens to be open (opening a trainer does not open
    -- one, which is why this path used to be dead).
    if isRecipeTrainer then
        self:ReconcileSkillReq(available)
    end
end

----------------------------------------------------------------------
-- Inventory scanning
----------------------------------------------------------------------

-- BAG_UPDATE handler: scan now if the last scan is old enough, otherwise arm
-- ONE trailing scan. An armed timer is never cancelled or restarted, so a
-- long burst still lands a scan 0.25 s after it starts.
function Scanner:QueueInventoryScan()
    if self._bagTimer then return end

    local now = Now()
    if not self._lastBagScan or (now - self._lastBagScan) >= BAG_THROTTLE then
        self._lastBagScan = now
        self:ScanInventory()
        return
    end

    self._bagTimer = C_Timer.NewTimer(BAG_THROTTLE, function()
        self._bagTimer = nil
        self._lastBagScan = Now()
        self:ScanInventory()
    end)
end

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
                local count = info and info.stackCount or nil
                if id and count then
                    items[id] = (items[id] or 0) + count
                end
            end
        end
    end

    DS:SetInventory("bags", items)
end

function Scanner:ScanBank()
    -- Every bank slot reads as empty when the bank frame is shut, and
    -- SetInventory replaces the stored table, so a scan then would wipe it.
    if not self._bankOpen then return end

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
                local count = info and info.stackCount or nil
                if id and count then
                    items[id] = (items[id] or 0) + count
                end
            end
        end
    end

    DS:SetInventory("bank", items)
end
