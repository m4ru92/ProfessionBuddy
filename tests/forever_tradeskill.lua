----------------------------------------------------------------------
-- A fake WoW: Forever profession backend for the Forever harness, driven
-- by tests/forever_fixture.lua (m4ru's 2026-09-22 harvest).
--
-- Models what PB's Source/Forever.lua reads, the way the client behaves:
--   * GetProfessions / GetProfessionInfo list the character's professions;
--   * C_TradeSkillUI.OpenTradeSkill runs Blizzard's TRADE_SKILL_SHOW
--     handler (ShowProfessionsFrame) and fires TRADE_SKILL_SHOW, but the
--     list is NOT ready until TS_LIST_READY() fires TRADE_SKILL_LIST_UPDATE;
--   * GetAllRecipeIDs returns learned and unlearned recipes alike;
--   * item names come from the fixture unless listed in UNCACHED, which a
--     RequestLoadItemDataByID call empties (the item "arrives").
-- TS_CALLS records OpenTradeSkill, CloseTradeSkill and CraftRecipe.
----------------------------------------------------------------------

dofile("tests/forever_fixture.lua")
local FX = FOREVER_FIXTURE

TS = { open = nil, ready = false, linked = false }
TS_CALLS = {}
UNCACHED = {}

local byRecipe = {}
for profName, prof in pairs(FX.professions) do
    for _, r in ipairs(prof.recipes) do byRecipe[r.recipeID] = { prof = profName, r = r } end
end

local function profBySkillLine(skillLine)
    for name, prof in pairs(FX.professions) do
        if prof.skillLine == skillLine then return name, prof end
    end
end

-- Profession slots: two primaries, then archaeology, fishing, cooking,
-- first aid, with nil for an empty slot.
local SLOT_ORDER = { "Leatherworking", "Skinning", false, false, "Cooking", false }
function GetProfessions()
    local out = {}
    for i, name in ipairs(SLOT_ORDER) do out[i] = name and i or nil end
    return out[1], out[2], out[3], out[4], out[5], out[6]
end
function GetProfessionInfo(slot)
    local name = SLOT_ORDER[slot]
    local prof = name and FX.professions[name]
    if not prof then return nil end
    return name, 0, prof.rank, prof.maxRank, 1, 0, prof.skillLine
end

local function fire(event, ...) FIRE(event, ...) end

C_TradeSkillUI = {}
local T = C_TradeSkillUI

function T.OpenTradeSkill(skillLine)
    TS_CALLS[#TS_CALLS + 1] = "OpenTradeSkill:" .. tostring(skillLine)
    local name = profBySkillLine(skillLine)
    if not name then return false end
    if TS.open and TS.open ~= name then fire("TRADE_SKILL_CLOSE") end
    TS.open, TS.ready = name, false
    ShowProfessionsFrame()           -- GameEvent.HandleTradeSkillShow
    fire("TRADE_SKILL_SHOW")
    return true
end

function TS_LIST_READY()
    TS.ready = true
    fire("TRADE_SKILL_LIST_UPDATE")
end

function T.CloseTradeSkill()
    TS_CALLS[#TS_CALLS + 1] = "CloseTradeSkill"
    if not TS.open then return end
    TS.open, TS.ready = nil, false
    fire("TRADE_SKILL_CLOSE")
end

function T.IsTradeSkillReady() return TS.open ~= nil and TS.ready end
function T.IsTradeSkillLinked() return TS.linked end
function T.IsTradeSkillGuild() return false end

function T.GetBaseProfessionInfo()
    local prof = TS.open and FX.professions[TS.open]
    if not prof then return { professionID = 0, skillLevel = 0, maxSkillLevel = 0 } end
    return { professionID = prof.skillLine, professionName = TS.open,
             skillLevel = prof.rank, maxSkillLevel = prof.maxRank }
end

function T.GetAllRecipeIDs()
    local prof = TS.open and FX.professions[TS.open]
    local ids = {}
    for _, r in ipairs(prof and prof.recipes or {}) do ids[#ids + 1] = r.recipeID end
    return ids
end

function T.GetRecipeInfo(id)
    local e = byRecipe[id]
    if not e then return nil end
    local r = e.r
    return { recipeID = id, name = r.name, learned = r.learned, categoryID = r.categoryID,
             relativeDifficulty = r.relativeDifficulty, canSkillUp = r.canSkillUp,
             icon = r.icon, isDummyRecipe = false }
end

function T.GetRecipeSchematic(id)
    local e = byRecipe[id]
    local slots = {}
    for i, g in ipairs(e and e.r.reagents or {}) do
        slots[i] = { required = true, reagentType = 1, quantityRequired = g.quantity,
                     reagents = { { itemID = g.itemID } } }
    end
    return { recipeID = id, outputItemID = e and e.r.outputItemID or 0, reagentSlotSchematics = slots }
end

function T.GetCategoryInfo(id)
    local name = FX.categories[id]
    return name and { categoryID = id, name = name } or nil
end

function T.GetRecipeCooldown() return nil end
function T.GetCraftableCount(id) return (id == 2881) and 14 or 0 end
function T.GetRecipeLink(id)
    local e = byRecipe[id]
    return e and ("|cffffd000|Henchant:" .. id .. "|h[" .. e.prof .. ": " .. e.r.name .. "]|h|r")
end
function T.GetRecipeItemLink(id)
    local e = byRecipe[id]
    local out = e and e.r.outputItemID
    if not out or out == 0 then return nil end
    return "|cnIQ1:|Hitem:" .. out .. "::::::::6:1485:::1:3524::::::|h[]|h|r"
end
function T.CraftRecipe(id, n)
    TS_CALLS[#TS_CALLS + 1] = "CraftRecipe:" .. tostring(id) .. "x" .. tostring(n)
end

C_Item.GetItemInfo = function(id)
    if UNCACHED[id] then return nil end
    local name = FX.items[id]
    if not name then return nil end
    return name, "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r"
end
C_Item.GetItemIconByID = function(id) return 100000 + (id or 0) end
C_Item.RequestLoadItemDataByID = function(id)
    TS_CALLS[#TS_CALLS + 1] = "RequestLoadItemDataByID:" .. tostring(id)
    UNCACHED[id] = nil
end
