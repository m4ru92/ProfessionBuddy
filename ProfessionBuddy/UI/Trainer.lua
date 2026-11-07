----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/Trainer.lua
-- Skill-up ranges at a profession trainer (TRAINER-RANGES-scope.md).
-- A recipe you have not learned shows when it turns yellow, green and
-- grey, as PB's own window does for a known recipe:
--   * WoW: Forever: four colored numbers after the row's "Requires:" line
--     (Blizzard_TrainerUI Mainline, ClassTrainerFrame_InitServiceButton).
--   * TBC Anniversary: the same numbers on the selected recipe's "Requires:"
--     line (ClassTrainer_SetSelection), only when they fit on that one line:
--     the "Cost:" label sits at a fixed spot right under it.
--   * Both: a labeled line on the recipe's tooltip
--     (GameTooltip:SetTrainerService).
-- Post-hooks only. PB sets text on Blizzard's font strings and adds tooltip
-- lines; it writes no field or table entry on Blizzard's frames.
----------------------------------------------------------------------

local addon = ProfBuddy
local TR = addon:NewModule("Trainer")

-- The recipe a trainer service teaches, cached by service index and checked
-- against the service's name (the list reorders when its filters change).
-- Cleared each time a trainer opens. TRAINER_UPDATE stays unregistered on
-- WoW: Forever (only the Classic trainer scan uses it); the name check
-- covers a reordered list.
local cache = {}

local function Wanted()
    local S = addon.db and addon.db.settings
    if not (S and S.trainerShowRanges ~= false and addon.SkillRange) then return false end
    if IsTradeskillTrainer and not IsTradeskillTrainer() then return false end
    return true
end

-- Name and type ("available", "unavailable", "used") of service i, in each
-- client's return order: Forever name, type, ...; TBC Anniversary name,
-- subText, type, ...
local function ServiceInfo(i)
    local name, a, b = GetTrainerServiceInfo(i)
    if addon.Source.flavor == "classic" then return name, b end
    return name, a
end

-- { range, profName } for a recipe service you have not learned, or false.
local function Lookup(i)
    local name, category = ServiceInfo(i)
    if not name then return false end
    local hit = cache[i]
    if hit ~= nil and hit.name == name then return hit.value end
    local value = false
    local RDB = addon.RecipeDB
    if category ~= "used" and RDB then
        local skill, rank = GetTrainerServiceSkillReq(i)
        rank = tonumber(rank)
        local info, profName, spellID
        local KN = addon.Knowledge
        if KN and KN.ReadService then
            -- WoW: Forever: the recipe ID the service's tooltip carries
            spellID = KN.ReadService(i)
            local ref = spellID and RDB.spellToRecipe and RDB.spellToRecipe[spellID]
            if ref then
                profName = ref.profName
                info = RDB.data[ref.profName] and RDB.data[ref.profName][ref.recipeName]
            end
        elseif type(skill) == "string" then
            -- TBC Anniversary: the name, within the profession it requires
            info = RDB:GetRecipeByName(name, skill)
            profName = skill
        end
        if info and not (addon.CLASS_PROFS and addon.CLASS_PROFS[profName]) then
            local sr = addon.SkillRange.Get({ name = name, spellID = spellID, skillRange = info.skillRange })
            if sr then
                local range = { sr[1], sr[2], sr[3], sr[4] }
                -- the trainer's own learn level is the orange value
                if rank and rank > 0 then range[1] = rank end
                value = { range = range, profName = profName }
            end
        end
    end
    cache[i] = { name = name, value = value }
    return value
end

-- "   80  105  125  145", each in its range color
local function Numbers(range)
    local SR = addon.SkillRange
    local out = {}
    for k = 1, 4 do out[k] = SR.COLORS[k] .. tostring(SR.Num(range[k])) .. "|r" end
    return "   " .. table.concat(out, "  ")
end

-- The tooltip line, with > < around the tier the recipe would have at your
-- current skill in its profession
local function TooltipLine(hit)
    local SR = addon.SkillRange
    local prof = addon.DataStore and addon.DataStore:GetProfession(nil, hit.profName)
    local skill = prof and tonumber(prof.skillLevel)
    local diff = skill and SR.Diff(hit.range, skill) or nil
    return "Skill-ups (ProfessionBuddy): " .. SR.Detailed(hit.range, skill, diff)
end

-- WoW: Forever: a row of the trainer list
function TR:DecorateRow(button, elementData)
    if not Wanted() then return end
    elementData = elementData and (elementData.data or elementData)
    local i = type(elementData) == "table" and elementData.skillIndex
    local fs = button and button.subText
    if not (i and fs and fs.GetText) then return end
    local text = fs:GetText()
    if type(text) ~= "string" or text == "" then return end
    local hit = Lookup(i)
    if hit then fs:SetText(text .. Numbers(hit.range)) end
end

-- TBC Anniversary: the selected recipe's Requires line, only when the line
-- still fits as one line
function TR:DecorateSelection(i)
    if not Wanted() then return end
    local fs = ClassTrainerSkillRequirements
    if not (i and fs and fs.GetText) then return end
    local text = fs:GetText()
    if type(text) ~= "string" or text == "" then return end
    local hit = Lookup(i)
    if not hit then return end
    fs:SetText(text .. Numbers(hit.range))
    local width = tonumber(fs:GetWidth())
    local used = tonumber(fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth())
    if not (width and used) or used > width then fs:SetText(text) end
end

-- Both clients: the recipe's tooltip
function TR:DecorateTooltip(tip, i)
    if not (Wanted() and i) then return end
    local hit = Lookup(i)
    if not hit then return end
    tip:AddLine(TooltipLine(hit), 1, 0.82, 0)
    tip:Show()
end

local function InstallTrainerHooks()
    if TR._listHooked then return end
    if type(ClassTrainerFrame_InitServiceButton) == "function" then
        hooksecurefunc("ClassTrainerFrame_InitServiceButton", function(button, elementData)
            TR:DecorateRow(button, elementData)
        end)
        TR._listHooked = true
    elseif type(ClassTrainer_SetSelection) == "function" then
        hooksecurefunc("ClassTrainer_SetSelection", function(i) TR:DecorateSelection(i) end)
        TR._listHooked = true
    end
end

function TR:Init()
    addon:RegisterEvent("TRAINER_SHOW", function() wipe(cache) end)
    if GameTooltip and type(GameTooltip.SetTrainerService) == "function" then
        hooksecurefunc(GameTooltip, "SetTrainerService", function(tip, i) TR:DecorateTooltip(tip, i) end)
    end
    -- Blizzard's trainer window loads on demand, the first time a trainer opens
    InstallTrainerHooks()
    if not TR._listHooked then
        addon:RegisterEvent("ADDON_LOADED", function(_, name)
            if name == "Blizzard_TrainerUI" then InstallTrainerHooks() end
        end)
    end
end
