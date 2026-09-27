----------------------------------------------------------------------
-- A fake WoW: Forever trainer for the Forever harness, replaying three of
-- m4ru's real Thunder Bluff trainer captures (ForeverProbe 1.9.3,
-- 2026-09-24/25): Mak (Leatherworking), Mooranta (Skinning), Vhan
-- (Tailoring, captured on a character with no Tailoring) and Ansekhwa
-- (weapon master, not a profession trainer).
--
-- Answers in Forever's return orders (Blizzard_TrainerUI, `forever`):
--   GetTrainerServiceInfo     name, type, texture, reqLevel, subText, category
--   GetTrainerServiceSkillReq skill, rank, hasReq
-- and C_TooltipInfo.GetTrainerService(i).id is the service's spell ID.
-- The list shows only the service types whose filter is on, as the
-- client's does. TRAINER_OPEN(npcID) opens one and fires TRAINER_SHOW.
----------------------------------------------------------------------

TRAINERS = {
    [3008] = { name = "Mak", tradeskill = true, services = {
        { id = 2108, name = "Apprentice Leatherworking", type = "used", skill = nil, rank = 0 },
        { id = 2153, name = "Handstitched Leather Pants", type = "unavailable", skill = "Leatherworking", rank = 15 },
        { id = 1229432, name = "Camp Tent", type = "unavailable", skill = "Leatherworking", rank = 20 },
        { id = 3753, name = "Handstitched Leather Belt", type = "unavailable", skill = "Leatherworking", rank = 25 },
        { id = 9060, name = "Light Leather Quiver", type = "unavailable", skill = "Leatherworking", rank = 25 },
        { id = 9062, name = "Small Leather Ammo Pouch", type = "unavailable", skill = "Leatherworking", rank = 25 },
        { id = 3816, name = "Cured Light Hide", type = "unavailable", skill = "Leatherworking", rank = 30 },
        { id = 2160, name = "Embossed Leather Vest", type = "unavailable", skill = "Leatherworking", rank = 35 },
        { id = 1255146, name = "Black Whelp Slippers", type = "unavailable", skill = "Leatherworking", rank = 35 },
        { id = 1255145, name = "Dark Leather Boots", type = "unavailable", skill = "Leatherworking", rank = 35 },
        { id = 1255143, name = "Moonglow Boots", type = "unavailable", skill = "Leatherworking", rank = 35 },
        { id = 1255144, name = "Murloc Scale Shoes", type = "unavailable", skill = "Leatherworking", rank = 35 },
        { id = 2162, name = "Embossed Leather Cloak", type = "unavailable", skill = "Leatherworking", rank = 40 },
        { id = 3756, name = "Embossed Leather Gloves", type = "unavailable", skill = "Leatherworking", rank = 40 },
        { id = 9065, name = "Light Leather Bracers", type = "unavailable", skill = "Leatherworking", rank = 45 },
        { id = 2161, name = "Embossed Leather Boots", type = "unavailable", skill = "Leatherworking", rank = 50 },
        { id = 3759, name = "Embossed Leather Pants", type = "unavailable", skill = "Leatherworking", rank = 50 },
    } },
    [7089] = { name = "Mooranta", tradeskill = true, services = {
        { id = 8613, name = "Apprentice Skinning", type = "used", skill = nil, rank = 0 },
        { id = 8617, name = "Journeyman Skinning", type = "unavailable", skill = "Skinning", rank = 50 },
        { id = 8618, name = "Expert Skinning", type = "unavailable", skill = "Skinning", rank = 125 },
        { id = 10768, name = "Artisan Skinning", type = "unavailable", skill = "Skinning", rank = 200 },
        { id = 1229517, name = "Camp Chair", type = "used", skill = "Skinning", rank = 20 },
    } },
    [11051] = { name = "Vhan", tradeskill = true, services = {
        { id = 3908, name = "Apprentice Tailoring", type = "available", skill = nil, rank = 0 },
        { id = 2393, name = "White Linen Shirt", type = "unavailable", skill = "Tailoring", rank = 1 },
        { id = 3755, name = "Linen Bag", type = "unavailable", skill = "Tailoring", rank = 5 },
        { id = 2385, name = "Brown Linen Vest", type = "unavailable", skill = "Tailoring", rank = 10 },
        { id = 8776, name = "Linen Belt", type = "unavailable", skill = "Tailoring", rank = 15 },
        { id = 12045, name = "Simple Linen Boots", type = "unavailable", skill = "Tailoring", rank = 20 },
        { id = 1229504, name = "Faction Banner", type = "unavailable", skill = "Tailoring", rank = 20 },
        { id = 2394, name = "Blue Linen Shirt", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 3914, name = "Brown Linen Pants", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 7623, name = "Brown Linen Robe", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 2392, name = "Red Linen Shirt", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 8465, name = "Simple Dress", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 7624, name = "White Linen Robe", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 3840, name = "Heavy Linen Gloves", type = "unavailable", skill = "Tailoring", rank = 25 },
        { id = 1257368, name = "Novice Arcanist's Sash", type = "unavailable", skill = "Tailoring", rank = 35 },
        { id = 1257369, name = "Novice Ardent's Sash", type = "unavailable", skill = "Tailoring", rank = 35 },
        { id = 3841, name = "Green Linen Bracers", type = "unavailable", skill = "Tailoring", rank = 35 },
        { id = 2397, name = "Reinforced Linen Cape", type = "unavailable", skill = "Tailoring", rank = 35 },
        { id = 2396, name = "Green Linen Shirt", type = "unavailable", skill = "Tailoring", rank = 40 },
        { id = 2386, name = "Linen Boots", type = "unavailable", skill = "Tailoring", rank = 40 },
        { id = 2395, name = "Barbaric Linen Vest", type = "unavailable", skill = "Tailoring", rank = 40 },
        { id = 3842, name = "Handstitched Linen Britches", type = "unavailable", skill = "Tailoring", rank = 45 },
        { id = 12046, name = "Simple Kilt", type = "unavailable", skill = "Tailoring", rank = 50 },
        { id = 2964, name = "Bolt of Woolen Cloth", type = "unavailable", skill = "Tailoring", rank = 55 },
        { id = 2402, name = "Woolen Cape", type = "unavailable", skill = "Tailoring", rank = 55 },
    } },
    [11869] = { name = "Ansekhwa", tradeskill = false, services = {
        { id = 266, name = "Guns", type = "used", skill = nil, rank = 0 },
        { id = 227, name = "Staves", type = "available", skill = nil, rank = 0 },
    } },
}

TRAINER = { open = nil }
TRAINER_FILTER = { available = true, unavailable = true, used = false }
TRAINER_FILTER_CALLS = {}

local function visible()
    local t = TRAINER.open and TRAINERS[TRAINER.open]
    local out = {}
    for _, s in ipairs(t and t.services or {}) do
        if TRAINER_FILTER[s.type] then out[#out + 1] = s end
    end
    return out
end

function GetNumTrainerServices() return #visible() end
function GetTrainerServiceInfo(i)
    local s = visible()[i]
    if not s then return nil end
    return s.name, s.type, 136235, 0, "", ""
end
function GetTrainerServiceSkillReq(i)
    local s = visible()[i]
    if not s then return nil end
    return s.skill, s.rank, s.skill ~= nil
end
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetTrainerService = function(i)
    local s = visible()[i]
    return s and { id = s.id, lines = {} } or nil
end
function GetTrainerServiceTypeFilter(f) return TRAINER_FILTER[f] end
function SetTrainerServiceTypeFilter(f, on)
    TRAINER_FILTER_CALLS[#TRAINER_FILTER_CALLS + 1] = f .. "=" .. tostring(on)
    TRAINER_FILTER[f] = on and true or false
end
function IsTradeskillTrainer()
    local t = TRAINER.open and TRAINERS[TRAINER.open]
    return t and t.tradeskill or false
end
function GetRealZoneText() return "Thunder Bluff" end
function GetSubZoneText() return "" end

local baseUnitName, baseUnitGUID, baseFaction = UnitName, UnitGUID, UnitFactionGroup
function UnitName(u)
    if u == "npc" then return TRAINER.open and TRAINERS[TRAINER.open].name or nil end
    return baseUnitName(u)
end
function UnitGUID(u)
    if u == "npc" then
        return TRAINER.open and ("Creature-0-1-1-1-" .. TRAINER.open .. "-00001A2B3C") or nil
    end
    return baseUnitGUID(u)
end
function UnitFactionGroup(u)
    if u == "npc" then return TRAINER.open and "Horde" or nil end
    return baseFaction(u)
end

-- Blizzard's trainer window, shown while a trainer is open.
ClassTrainerFrame = CreateFrame("Frame", "ClassTrainerFrame")

function TRAINER_OPEN(npcID)
    TRAINER.open = npcID
    ClassTrainerFrame:Show()
    FIRE("TRAINER_SHOW")
end
function TRAINER_CLOSE()
    TRAINER.open = nil
    ClassTrainerFrame:Hide()
    FIRE("TRAINER_CLOSED")
end
