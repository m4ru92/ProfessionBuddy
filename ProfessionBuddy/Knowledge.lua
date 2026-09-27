----------------------------------------------------------------------
-- ProfessionBuddy  --  Knowledge.lua
-- What this account has seen in game, on WoW: Forever.
--
-- ProfBuddyDB.knowledge, shared by every character on the account and
-- keyed by recipe ID (the recipe's spell ID; 67 Forever recipe names
-- belong to two IDs, so a name cannot key it):
--
--   [recipeID] = {
--       learnLevel = 35,   -- the skill a trainer asks for
--       teachers   = { [npcID] = { name, zone, subZone, faction, seen } },
--   }
--
-- A recorded learn level beats the one in Data/Forever wherever PB shows
-- a learn level. Only the Mainline toc loads this file.
--
-- Recorded from trainer windows: every service a profession trainer
-- lists, including the ones far above your skill. The capture is moved
-- from ForeverProbe 1.9.3, which read these values at 11 Thunder Bluff
-- trainers on the Forever beta.
----------------------------------------------------------------------

local addon = ProfBuddy
local KN = addon:NewModule("Knowledge")

-- Trainer list filters. All three go on for the capture so no service is
-- hidden, then each goes back to what the player had.
local FILTERS = { "available", "unavailable", "used" }
-- The list refreshes after a filter change; ForeverProbe captured after
-- one second.
local CAPTURE_DELAY = 1.0
-- Teachers named on the Source line before "and N more".
local MAX_TEACHERS_SHOWN = 3

function KN:Init()
    addon:RegisterEvent("TRAINER_SHOW", function() self:OnTrainerShow() end)
end

function KN:Get(recipeID)
    local store = recipeID and addon.db and addon.db.knowledge
    return store and store[recipeID] or nil
end

-- The learn level a trainer showed for this recipe, or nil.
function KN:LearnLevel(recipeID)
    local e = self:Get(recipeID)
    return e and e.learnLevel or nil
end

-- "Mak (Thunder Bluff), Vhan (Thunder Bluff)" for the trainers seen
-- teaching this recipe, or nil. With faction, trainers of the other
-- faction are left out; a trainer with no faction counts for both.
function KN:TeacherText(recipeID, faction)
    local e = self:Get(recipeID)
    if not (e and e.teachers) then return nil end
    local names = {}
    for _, t in pairs(e.teachers) do
        if not faction or not t.faction or t.faction == faction
           or t.faction == "Neutral" then
            local label = t.name or "?"
            if t.zone and t.zone ~= "" then label = label .. " (" .. t.zone .. ")" end
            names[#names + 1] = label
        end
    end
    if #names == 0 then return nil end
    table.sort(names)
    local more = #names - MAX_TEACHERS_SHOWN
    if more > 0 then
        for i = #names, MAX_TEACHERS_SHOWN + 1, -1 do names[i] = nil end
        names[#names + 1] = "and " .. more .. " more"
    end
    return table.concat(names, ", ")
end

----------------------------------------------------------------------
-- Trainer scan
----------------------------------------------------------------------

-- One trainer service, in Forever's return orders (Blizzard_TrainerUI,
-- `forever` branch):
--   GetTrainerServiceInfo     name, type, texture, reqLevel, subText, category
--   GetTrainerServiceSkillReq skill, rank, hasReq
-- The recipe ID comes from the service's tooltip data.
local function ReadService(i)
    local _, rank = GetTrainerServiceSkillReq(i)
    local id
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, data = pcall(C_TooltipInfo.GetTrainerService, i)
        if ok and type(data) == "table" and type(data.id) == "number" then id = data.id end
    end
    return id, tonumber(rank)
end

-- Record every recipe the open trainer lists. Returns how many.
function KN:CaptureTrainer()
    local n = GetNumTrainerServices() or 0
    local RDB = addon.RecipeDB
    if n == 0 or not (RDB and addon.db) then return 0 end
    local npcName = UnitName("npc")
    local guid = UnitGUID("npc")
    local npcID = guid and tonumber((select(6, strsplit("-", guid))))
    local key = npcID or npcName
    if not key then return 0 end
    local zone, subZone = GetRealZoneText(), GetSubZoneText()
    local faction = UnitFactionGroup("npc")
    local now = time()

    addon.db.knowledge = addon.db.knowledge or {}
    local store = addon.db.knowledge
    local recorded = 0
    for i = 1, n do
        local id, rank = ReadService(i)
        -- Only a recipe PB has data for: a trainer also lists profession
        -- ranks ("Journeyman Tailoring") and, on a class trainer, spells.
        local ref = id and RDB.spellToRecipe[id]
        if ref and not addon.CLASS_PROFS[ref.profName] then
            local e = store[id] or {}
            store[id] = e
            if rank and rank > 0 then e.learnLevel = rank end
            e.teachers = e.teachers or {}
            e.teachers[key] = { name = npcName, zone = zone, subZone = subZone,
                                faction = faction, seen = now }
            recorded = recorded + 1
        end
    end
    return recorded
end

-- Show every service (all three filters on), wait for the list to
-- refresh, capture, then put the filters back. Class, weapon and pet
-- trainers are skipped, so their lists never change under the player.
function KN:OnTrainerShow()
    if IsTradeskillTrainer and not IsTradeskillTrainer() then return end
    local prev = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, f in ipairs(FILTERS) do
            prev[f] = GetTrainerServiceTypeFilter(f) and true or false
            if not prev[f] then SetTrainerServiceTypeFilter(f, true) end
        end
    end
    C_Timer.After(CAPTURE_DELAY, function()
        local ok, err = pcall(self.CaptureTrainer, self)
        if SetTrainerServiceTypeFilter then
            for f, was in pairs(prev) do
                if not was then SetTrainerServiceTypeFilter(f, false) end
            end
        end
        if not ok then
            print("|cff00ccffProfessionBuddy:|r trainer scan failed: " .. tostring(err))
        end
    end)
end
