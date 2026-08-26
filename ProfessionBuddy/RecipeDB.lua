----------------------------------------------------------------------
-- ProfessionBuddy  --  RecipeDB.lua
-- Static recipe database framework for "unknown recipe" tracking.
-- Individual profession data files register into this table.
--
-- Each recipe entry:
--   itemID       = crafted item ID
--   skillReq     = skill level required to learn
--   sources      = { { method = "trainer"|"vendor"|"drop"|"quest"|
--                      "reputation"|"discovery"|"automatic"|"undetermined",
--                      faction = "Alliance"|"Horde"|"Both",
--                      detail = "where to get it (optional)" }, ... }
--                  A recipe may have several sources; faction is per-source
--                  so the UI can show only the current character's faction.
--   source/sourceDetail = LEGACY single-source fields, auto-back-filled from
--                  sources[1] at RegisterProfession for readers not yet
--                  migrated to sources[] (UI migration = source-overhaul Inc 3).
--   reagents     = { { itemID = X, count = N }, ... }
----------------------------------------------------------------------

local addon = ProfBuddy
local RDB = addon:NewModule("RecipeDB")

-- Master table: RecipeDB.data[profName][recipeName] = { ... }
RDB.data = {}

-- Reverse lookup: itemID -> { recipeName, profName }
RDB.itemToRecipe = {}

-- Reverse lookup: locale-stable recipe spellID -> { recipeName, profName }
RDB.spellToRecipe = {}

-- Reverse lookup: recipe name -> { recipeName, profName }. Name-based fallback
-- for when a display entry has no spellID (own-view live builders). Recipe
-- names are unique across professions in practice.
RDB.nameToRecipe = {}

-- Reverse lookup: reagentItemID -> { { recipeName, profName, count, skillRange }, ... }
RDB.reagentUsedIn = {}

----------------------------------------------------------------------
-- Called by Data/*.lua files to register recipes for a profession
----------------------------------------------------------------------
function RDB:RegisterProfession(profName, recipes)
    self.data[profName] = self.data[profName] or {}

    for recipeName, info in pairs(recipes) do
        -- Back-fill legacy source/sourceDetail from the new sources[] array
        -- so readers not yet migrated to sources[] keep working. The UI
        -- switches to sources[] (per-faction) in the source-overhaul Inc 3.
        if info.sources and info.source == nil then
            local primary = info.sources[1]
            if primary then
                info.source = primary.method
                info.sourceDetail = primary.detail
            end
        end

        self.data[profName][recipeName] = info

        -- Build reverse: crafted item -> recipe
        if info.itemID then
            self.itemToRecipe[info.itemID] = {
                recipeName = recipeName,
                profName   = profName,
            }
        end

        -- Build reverse: recipe spellID -> recipe (locale-stable matching)
        if info.spellID then
            self.spellToRecipe[info.spellID] = {
                recipeName = recipeName,
                profName   = profName,
            }
        end

        -- Build reverse: recipe name -> recipe (name-based fallback)
        self.nameToRecipe[recipeName] = {
            recipeName = recipeName,
            profName   = profName,
        }

        -- Build reverse: reagent -> recipes that use it
        if info.reagents then
            for _, reagent in ipairs(info.reagents) do
                if reagent.itemID then
                    self.reagentUsedIn[reagent.itemID] = self.reagentUsedIn[reagent.itemID] or {}
                    table.insert(self.reagentUsedIn[reagent.itemID], {
                        recipeName = recipeName,
                        profName   = profName,
                        count      = reagent.count,
                        skillRange = info.skillRange,  -- {orange,yellow,green,grey} for the "Used in" tooltip skill-up range
                    })
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Query: what recipes does this character NOT know for a profession?
----------------------------------------------------------------------
function RDB:GetUnknownRecipes(charKey, profName)
    local profData = addon.DataStore:GetProfession(charKey, profName)

    local allRecipes = self.data[profName]
    if not allRecipes then return {} end

    -- If the character doesn't know this profession at all,
    -- every recipe in the static DB is unknown
    if not profData then
        local unknown = {}
        for recipeName, info in pairs(allRecipes) do
            unknown[recipeName] = info
        end
        return unknown
    end

    -- Build the set of spellIDs the character actually knows, from the
    -- scanned recipes. spellID is locale-stable; the name key is not.
    local knownSpells = {}
    -- A remote/lightweight profession record (a HELLO summary, the /pbt
    -- fixture, or a friend seen before a full SYNC_DATA) can carry
    -- skillLevel/maxSkill with NO recipes subtable. Treat a missing recipes
    -- table as empty rather than crashing pairs() -- mirrors the guard the
    -- CharacterPanel caller already has one row up.
    local knownRecipes = profData.recipes or {}
    for _, recipe in pairs(knownRecipes) do
        if recipe.spellID then
            knownSpells[recipe.spellID] = true
        end
    end

    local unknown = {}
    for recipeName, info in pairs(allRecipes) do
        -- Show ALL unknown recipes regardless of current max skill.
        -- The UI indicates which are learnable now vs need higher skill tier.
        -- Match by spellID first (locale-independent); fall back to the
        -- recipe name so enUS behaviour is identical and any recipe with a
        -- missing/unparsed spellID still resolves.
        local known = (info.spellID and knownSpells[info.spellID])
                      or (knownRecipes[recipeName] ~= nil)
        if not known then
            unknown[recipeName] = info
        end
    end
    return unknown
end

----------------------------------------------------------------------
-- Query: what recipes use this item as a reagent?
----------------------------------------------------------------------
function RDB:GetRecipesUsingReagent(itemID)
    return self.reagentUsedIn[itemID] or {}
end

----------------------------------------------------------------------
-- Query: is this item a craftable intermediate? (e.g. Bolt of Silk Cloth)
----------------------------------------------------------------------
function RDB:IsCraftable(itemID)
    return self.itemToRecipe[itemID] ~= nil
end

function RDB:GetRecipeForItem(itemID)
    return self.itemToRecipe[itemID]
end

-- Resolve a recipe's static info entry from its locale-stable spellID.
-- Returns the full info table (reagents, skillRange, itemID, skillReq, ...)
-- or nil. Used to enrich viewed-character recipes (friends / non-enUS) whose
-- names don't match the English static keys -- match on spellID instead.
function RDB:GetRecipeBySpell(spellID)
    local ref = self.spellToRecipe[spellID]
    if not ref then return nil end
    local prof = self.data[ref.profName]
    return prof and prof[ref.recipeName] or nil
end

-- Resolve a recipe's static info entry from its (English) name. Used when the
-- display entry carries no spellID (own-view live builders) or a spellID that
-- doesn't resolve. Profession-agnostic, so it works regardless of state.profName.
function RDB:GetRecipeByName(name)
    local ref = name and self.nameToRecipe[name]
    if not ref then return nil end
    local prof = self.data[ref.profName]
    return prof and prof[ref.recipeName] or nil
end

-- Static (data-file) learn level for a recipe name, or nil. Compared against
-- the authoritative GetTrainerServiceSkillReq in Scanner:ReconcileSkillReq.
function RDB:StaticSkillReq(name)
    local info = self:GetRecipeByName(name)
    return info and info.skillReq or nil
end
