----------------------------------------------------------------------
-- ProfessionBuddy  --  RecipeDB.lua
-- Static recipe database framework for "unknown recipe" tracking.
-- Individual profession data files register into this table.
--
-- Each recipe entry:
--   itemID       = crafted item ID
--   skillReq     = skill level required to learn
--   source       = "trainer" | "drop" | "vendor" | "quest" | "reputation" | "discovery"
--   sourceDetail = description of where to get it (e.g. "Scryer - Honored")
--   reagents     = { { itemID = X, count = N }, ... }
----------------------------------------------------------------------

local addon = ProfBuddy
local RDB = addon:NewModule("RecipeDB")

-- Master table: RecipeDB.data[profName][recipeName] = { ... }
RDB.data = {}

-- Reverse lookup: itemID -> { recipeName, profName }
RDB.itemToRecipe = {}

-- Reverse lookup: reagentItemID -> { { recipeName, profName, count }, ... }
RDB.reagentUsedIn = {}

----------------------------------------------------------------------
-- Called by Data/*.lua files to register recipes for a profession
----------------------------------------------------------------------
function RDB:RegisterProfession(profName, recipes)
    self.data[profName] = self.data[profName] or {}

    for recipeName, info in pairs(recipes) do
        self.data[profName][recipeName] = info

        -- Build reverse: crafted item -> recipe
        if info.itemID then
            self.itemToRecipe[info.itemID] = {
                recipeName = recipeName,
                profName   = profName,
            }
        end

        -- Build reverse: reagent -> recipes that use it
        if info.reagents then
            for _, reagent in ipairs(info.reagents) do
                if reagent.itemID then
                    self.reagentUsedIn[reagent.itemID] = self.reagentUsedIn[reagent.itemID] or {}
                    table.insert(self.reagentUsedIn[reagent.itemID], {
                        recipeName = recipeName,
                        profName   = profName,
                        count      = reagent.count,
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

    local unknown = {}
    for recipeName, info in pairs(allRecipes) do
        -- Show ALL unknown recipes regardless of current max skill.
        -- The UI indicates which are learnable now vs need higher skill tier.
        if not profData.recipes[recipeName] then
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
