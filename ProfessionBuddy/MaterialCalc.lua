----------------------------------------------------------------------
-- ProfessionBuddy  --  MaterialCalc.lua
-- Recursive material calculator with cross-alt inventory awareness
--
-- Given a recipe and quantity, resolves the full reagent tree:
--   - Detects craftable intermediates (e.g. Felsteel Bar) and
--     expands them into their sub-reagents
--   - Accounts for existing inventory before recursing (if you
--     already have enough of an intermediate, no sub-materials
--     are needed)
--   - Tallies raw materials needed at the leaves
--   - Compares against inventory across all characters
--   - Produces a shopping list of what's still needed
----------------------------------------------------------------------

local addon = ProfBuddy
local MC = addon:NewModule("MaterialCalc")

local DS   -- DataStore, set in Init
local RDB  -- RecipeDB, set in Init

function MC:Init()
    DS  = addon.DataStore
    RDB = addon.RecipeDB
end

----------------------------------------------------------------------
-- Core: resolve a recipe into a flat list of raw materials
--
-- Returns: {
--   { itemID, name, need, depth, isCraftable, subRecipe },
--   ...
-- }
-- "depth" indicates tree level (0 = top recipe's direct reagents,
-- 1 = sub-reagent of a craftable intermediate, etc.)
--
-- The tree list preserves hierarchy for display. A separate
-- "shopping list" collapses it to raw totals.
----------------------------------------------------------------------

-- Resolve a single recipe into its tree, recursively.
-- seen        = set of itemIDs currently in the call stack (cycle guard)
-- globalItems = { [itemID] = totalCount } across all characters
-- claimed     = { [itemID] = alreadyReserved } tracks inventory consumed
--               by earlier branches so we don't double-count
function MC:ResolveTree(recipeName, profName, qty, depth, seen, globalItems, claimed)
    depth = depth or 0
    seen = seen or {}
    qty = qty or 1
    globalItems = globalItems or (DS and DS:GetCalcItemCounts()) or {}
    claimed = claimed or {}

    local tree = {}

    -- Find reagents: first check live data, then static DB
    local reagents = nil

    -- Live data from current session's scanned recipes
    if addon.TradeSkillFrame then
        local tsf = addon.TradeSkillFrame
        -- Check if we have this recipe in the current state
        if tsf.state and tsf.state.allRecipes and tsf.state.allRecipes[recipeName] then
            reagents = tsf.state.allRecipes[recipeName].reagents
        end
    end

    -- Fall back to static DB
    if not reagents and RDB and RDB.data then
        if profName and RDB.data[profName] and RDB.data[profName][recipeName] then
            reagents = RDB.data[profName][recipeName].reagents
        else
            -- Search all professions
            for _, profRecipes in pairs(RDB.data) do
                if profRecipes[recipeName] and profRecipes[recipeName].reagents then
                    reagents = profRecipes[recipeName].reagents
                    break
                end
            end
        end
    end

    if not reagents then return tree end

    for _, reagent in ipairs(reagents) do
        local totalNeed = (reagent.count or 1) * qty
        local rItemID = reagent.itemID
        local rName = reagent.name or "???"

        -- Check if this reagent is itself craftable (and not a cycle)
        local craftable = false
        local subRecipeName = nil
        local subProfName = nil
        local subYield = 1

        if rItemID and not seen[rItemID] then
            local recipeInfo = RDB:GetRecipeForItem(rItemID)
            if recipeInfo then
                craftable = true
                subRecipeName = recipeInfo.recipeName
                subProfName = recipeInfo.profName
                -- Look up yield for the sub-recipe (e.g. Smelt Bronze = 2)
                local subData = RDB.data[subProfName] and RDB.data[subProfName][subRecipeName]
                if subData and subData.yield then
                    subYield = subData.yield
                end
            end
        end

        local entry = {
            itemID = rItemID,
            name = rName,
            need = totalNeed,
            depth = depth,
            isCraftable = craftable,
            subRecipe = subRecipeName,
            subProf = subProfName,
        }
        table.insert(tree, entry)

        -- Recurse into craftable intermediates, but only for the
        -- shortfall after accounting for existing inventory.
        -- A "claimed" table tracks how much inventory has been
        -- reserved by earlier tree branches to prevent double-dipping.
        if craftable and subRecipeName then
            local available = math.max(0, (globalItems[rItemID] or 0) - (claimed[rItemID] or 0))
            local shortfall = math.max(0, totalNeed - available)
            -- Claim what we're pulling from inventory
            local consuming = math.min(totalNeed, available)
            claimed[rItemID] = (claimed[rItemID] or 0) + consuming

            if shortfall > 0 then
                seen[rItemID] = true
                local craftsNeeded = math.ceil(shortfall / subYield)
                local subTree = self:ResolveTree(subRecipeName, subProfName, craftsNeeded, depth + 1, seen, globalItems, claimed)
                for _, subEntry in ipairs(subTree) do
                    table.insert(tree, subEntry)
                end
                seen[rItemID] = nil
            end
        end
    end

    return tree
end

----------------------------------------------------------------------
-- Shopping list: collapse the tree to raw materials only
-- (items that are NOT craftable, i.e. the leaves)
--
-- Returns: {
--   { itemID, name, need, have, shortfall },
--   ...
-- }
-- Sorted by shortfall descending (most-needed first).
----------------------------------------------------------------------
function MC:GetShoppingList(recipeName, profName, qty)
    local globalItems = DS and DS:GetCalcItemCounts() or {}
    local claimed = {}
    local tree = self:ResolveTree(recipeName, profName, qty, nil, nil, globalItems, claimed)
    if #tree == 0 then return {}, tree end

    -- Collect raw materials (non-craftable leaves)
    local rawTotals = {}  -- itemID -> { name, need }
    for _, entry in ipairs(tree) do
        if not entry.isCraftable and entry.itemID then
            if not rawTotals[entry.itemID] then
                rawTotals[entry.itemID] = { name = entry.name, need = 0 }
            end
            rawTotals[entry.itemID].need = rawTotals[entry.itemID].need + entry.need
        end
    end

    -- Compare against cross-alt inventory
    local list = {}
    for itemID, info in pairs(rawTotals) do
        local have = globalItems[itemID] or 0
        local shortfall = math.max(0, info.need - have)
        table.insert(list, {
            itemID = itemID,
            name = info.name,
            need = info.need,
            have = have,
            shortfall = shortfall,
        })
    end

    -- Sort: items you're short on first, then alphabetical
    table.sort(list, function(a, b)
        if a.shortfall ~= b.shortfall then return a.shortfall > b.shortfall end
        return a.name < b.name
    end)

    return list, tree
end

----------------------------------------------------------------------
-- Convenience: can we craft N of this right now?
----------------------------------------------------------------------
function MC:CanCraft(recipeName, profName, qty)
    local list = self:GetShoppingList(recipeName, profName, qty)
    for _, item in ipairs(list) do
        if item.shortfall > 0 then return false end
    end
    return true
end

----------------------------------------------------------------------
-- Convenience: max craftable from current inventory
----------------------------------------------------------------------
function MC:MaxCraftable(recipeName, profName)
    local globalItems = DS and DS:GetCalcItemCounts() or {}
    local tree = self:ResolveTree(recipeName, profName, 1, nil, nil, globalItems, {})
    if #tree == 0 then return 0 end

    local maxQty = 999999

    -- Only look at raw (non-craftable) materials
    local rawNeeds = {}
    for _, entry in ipairs(tree) do
        if not entry.isCraftable and entry.itemID then
            rawNeeds[entry.itemID] = (rawNeeds[entry.itemID] or 0) + entry.need
        end
    end

    for itemID, needPer in pairs(rawNeeds) do
        local have = globalItems[itemID] or 0
        local canMake = math.floor(have / needPer)
        if canMake < maxQty then
            maxQty = canMake
        end
    end

    return maxQty == 999999 and 0 or maxQty
end
