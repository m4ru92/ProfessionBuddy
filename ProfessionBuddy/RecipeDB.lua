----------------------------------------------------------------------
-- ProfessionBuddy  --  RecipeDB.lua
-- Static recipe database framework for "unknown recipe" tracking.
-- Individual profession data files register into this table.
--
-- A data file registers one table per profession, keyed by RECIPE NAME. The
-- name is the key, so an entry carries no name field of its own; the only
-- name field in the data is the display name on a reagent.
--
-- Each recipe entry:
--   spellID      = recipe spell ID. Locale-stable, and the key Scanner
--                  matches known recipes on, so it is required.
--   itemID       = crafted item ID, or 0 for a recipe that produces no item
--                  (every enchant). Required, never nil. Only itemID > 0 is
--                  registered in itemToRecipe.
--   skillReq     = skill level a trainer requires to teach it.
--   skillRange   = { orange, yellow, green, grey }, ascending. orange equals
--                  skillReq unless the recipe is not trainer-taught.
--   sources      = { { method = "trainer"|"vendor"|"drop"|"quest"|
--                      "reputation"|"discovery"|"automatic"|"undetermined",
--                      faction = "Alliance"|"Horde"|"Both",
--                      detail = "where to get it (optional)" }, ... }
--                  A recipe may have several sources; faction is per-source
--                  so the UI can show only the current character's faction.
--                  detail is printed to the player verbatim after the method
--                  name, so it holds no build-pipeline notes.
--   source/sourceDetail = LEGACY single-source fields, auto-back-filled from
--                  sources[1] at RegisterProfession for readers not yet
--                  migrated to sources[] (UI migration = source-overhaul Inc 3).
--   category     = top-level grouping shown in the browser.
--   subcategory  = optional grouping inside the category.
--   reagents     = { { itemID = X, count = N, name = "Display Name" }, ... }
--                  name is required: the material calculator shows ??? without it.
--   yield        = optional units produced per craft, greater than 0. Absent
--                  means 1.
--   rod          = optional, Enchanting only: a rod name from
--                  ProfBuddy.EnchantingRods.
--
-- .github/CONTRIBUTING.md documents the same fields for data contributors;
-- keep the two in step.
----------------------------------------------------------------------

local addon = ProfBuddy
local RDB = addon:NewModule("RecipeDB")

-- Master table: RecipeDB.data[profName][recipeName] = { ... }
RDB.data = {}

-- Reverse lookup: itemID -> { { recipeName, profName }, ... }. Multi-valued:
-- an item can be produced by more than one recipe (Large Prismatic Shard comes
-- from both "Large Prismatic Shard" and "Void Shatter"; Gold Bar from both
-- "Smelt Gold" and "Transmute: Iron to Gold"). itemID 0 means "produces no
-- item" (every enchant) and is never registered here.
RDB.itemToRecipe = {}

-- Reverse lookup: locale-stable recipe spellID -> { recipeName, profName }
RDB.spellToRecipe = {}

-- Reverse lookup: recipe name -> { { recipeName, profName }, ... }. Name-based
-- fallback for when a display entry has no spellID (own-view live builders).
-- Multi-valued: "Gordok Ogre Suit" is a distinct spell in Tailoring and in
-- Leatherworking and both are real, so a caller that knows its profession
-- passes it to GetRecipeByName.
RDB.nameToRecipe = {}

-- Reverse lookup: reagentItemID -> { { recipeName, profName, count, skillRange }, ... }
RDB.reagentUsedIn = {}

----------------------------------------------------------------------
-- Called by Data/*.lua files to register recipes for a profession
----------------------------------------------------------------------
-- Append to a multi-valued reverse map, skipping a duplicate registration of
-- the same recipe (a data file loaded twice must not double the list).
local function addRef(map, key, recipeName, profName)
    local list = map[key]
    if not list then
        list = {}
        map[key] = list
    end
    for i = 1, #list do
        if list[i].recipeName == recipeName and list[i].profName == profName then return end
    end
    list[#list + 1] = { recipeName = recipeName, profName = profName }
end

function RDB:RegisterProfession(profName, recipes)
    self.data[profName] = self.data[profName] or {}
    self._cyclic = nil   -- new recipes can add edges; recompute on next query

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

        -- Build reverse: crafted item -> recipes
        if info.itemID and info.itemID > 0 then
            addRef(self.itemToRecipe, info.itemID, recipeName, profName)
        end

        -- Build reverse: recipe spellID -> recipe (locale-stable matching)
        if info.spellID then
            self.spellToRecipe[info.spellID] = {
                recipeName = recipeName,
                profName   = profName,
            }
        end

        -- Build reverse: recipe name -> recipes (name-based fallback)
        addRef(self.nameToRecipe, recipeName, recipeName, profName)

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
-- NOTE: the returned entries are the STATIC tables out of self.data, handed
-- out by reference for cheapness. Read them; never write to one, or the edit
-- is visible to every other reader for the rest of the session.
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
    local list = self.itemToRecipe[itemID]
    return list ~= nil and #list > 0
end

-- Does any LOCAL character know this recipe? Matches on the scanned name key
-- first, then on the locale-stable spellID so a non-enUS client still resolves.
function RDB:AnyoneKnows(recipeName, profName)
    local DS = addon.DataStore
    if not (DS and recipeName and profName) then return false end
    local info = self.data[profName] and self.data[profName][recipeName]
    local spellID = info and info.spellID

    for _, char in pairs(DS:GetAllCharacters()) do
        if type(char) == "table" and not char.isRemote and char.professions then
            local profData = char.professions[profName]
            local known = profData and profData.recipes
            if known then
                if known[recipeName] then return true end
                if spellID then
                    for _, recipe in pairs(known) do
                        if type(recipe) == "table" and recipe.spellID == spellID then return true end
                    end
                end
            end
        end
    end
    return false
end

-- Every recipe that produces this item, in registration order.
function RDB:GetRecipesForItem(itemID)
    return self.itemToRecipe[itemID] or {}
end

-- The single producer to show for an item: the first one a local character
-- actually knows, else the first registered. Callers that need the whole set
-- use GetRecipesForItem.
function RDB:GetRecipeForItem(itemID)
    local list = self.itemToRecipe[itemID]
    if not list then return nil end
    for i = 1, #list do
        if self:AnyoneKnows(list[i].recipeName, list[i].profName) then return list[i] end
    end
    return list[1]
end

----------------------------------------------------------------------
-- Query: is this item on a cycle in the recipe graph?
--
-- The TBC primal transmutes (Air -> Fire -> Earth -> Water -> Air), the
-- vanilla essence transmutes and the Prismatic Shard / Nexus Transformation
-- pair all produce a reagent from a reagent they are themselves made of, so
-- expanding one as an "intermediate" walks in circles and reports the wrong
-- material. An item is on a cycle when it sits in a strongly connected
-- component of size > 1 in the item -> reagent graph, or when a recipe lists
-- its own output as one of its reagents (The Mortar: Reloaded).
--
-- Computed once per session on the first query, over every registered recipe,
-- and thrown away whenever a new profession registers. O(recipes + reagents).
----------------------------------------------------------------------
local function buildCycleSet(self)
    local cyclic = {}
    local adj = {}      -- producedItemID -> { reagentItemID, ... }

    for _, recipes in pairs(self.data) do
        for _, info in pairs(recipes) do
            local out = info.itemID
            if out and out > 0 and info.reagents then
                local list = adj[out]
                if not list then
                    list = {}
                    adj[out] = list
                end
                for _, reagent in ipairs(info.reagents) do
                    local rid = reagent.itemID
                    if rid and rid > 0 then
                        if rid == out then
                            cyclic[out] = true      -- self-edge
                        else
                            list[#list + 1] = rid
                        end
                    end
                end
            end
        end
    end

    -- Tarjan's SCC, iterative: the recursive form would blow the Lua stack on
    -- a long smelting/tailoring chain and WoW gives us no stack headroom.
    local index, lowlink, onStack = {}, {}, {}
    local stack, sp = {}, 0
    local nextIndex = 1

    for root in pairs(adj) do
        if not index[root] then
            index[root], lowlink[root] = nextIndex, nextIndex
            nextIndex = nextIndex + 1
            sp = sp + 1
            stack[sp] = root
            onStack[root] = true

            local work = { { v = root, i = 1 } }
            while #work > 0 do
                local frame = work[#work]
                local v = frame.v
                local edges = adj[v]
                local n = edges and #edges or 0

                if frame.i <= n then
                    local w = edges[frame.i]
                    frame.i = frame.i + 1
                    if not index[w] then
                        index[w], lowlink[w] = nextIndex, nextIndex
                        nextIndex = nextIndex + 1
                        sp = sp + 1
                        stack[sp] = w
                        onStack[w] = true
                        work[#work + 1] = { v = w, i = 1 }
                    elseif onStack[w] and index[w] < lowlink[v] then
                        lowlink[v] = index[w]
                    end
                else
                    work[#work] = nil
                    if lowlink[v] == index[v] then
                        local members, size = {}, 0
                        repeat
                            local w = stack[sp]
                            stack[sp] = nil
                            sp = sp - 1
                            onStack[w] = false
                            size = size + 1
                            members[size] = w
                        until w == v
                        if size > 1 then
                            for i = 1, size do cyclic[members[i]] = true end
                        end
                    end
                    local parent = work[#work]
                    if parent and lowlink[v] < lowlink[parent.v] then
                        lowlink[parent.v] = lowlink[v]
                    end
                end
            end
        end
    end

    return cyclic
end

function RDB:IsCyclicItem(itemID)
    if not itemID then return false end
    if not self._cyclic then self._cyclic = buildCycleSet(self) end
    return self._cyclic[itemID] == true
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
-- doesn't resolve. Pass profName when you know it: a handful of names are
-- registered by two professions and without it you get the first registered.
function RDB:GetRecipeByName(name, profName)
    local list = name and self.nameToRecipe[name]
    if not list then return nil end
    local ref = list[1]
    if profName then
        for i = 1, #list do
            if list[i].profName == profName then
                ref = list[i]
                break
            end
        end
    end
    local prof = ref and self.data[ref.profName]
    return prof and prof[ref.recipeName] or nil
end

-- Static (data-file) learn level for a recipe name, or nil. Compared against
-- the authoritative GetTrainerServiceSkillReq in Scanner:ReconcileSkillReq.
function RDB:StaticSkillReq(name, profName)
    local info = self:GetRecipeByName(name, profName)
    return info and info.skillReq or nil
end
