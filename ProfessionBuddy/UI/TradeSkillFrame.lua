----------------------------------------------------------------------
-- ProfessionBuddy  --  UI/TradeSkillFrame.lua
-- Enhanced tradeskill window replacement (v6)
--
-- v6 changes:
--   1. Search bar moved to title row (right of profession name)
--   2. DDL labels: "Type: All", "Difficulty: All", "Sort: Category", "View: Known (7)"
--   3. Wider DDLs with more breathing room
--   4. Secondary sort (difficulty within category, etc.)
--   5. Known recipes use static DB category when available (fixes Cooking "Consumable" issue)
--   6. Tooltips for ALL recipes (known + missing) via SetItemByID fallback
--   7. Embedded item tooltip in detail panel
--   8. Shift-click to link items into chat
--   9. Window suppression via ShowUIPanel hook
----------------------------------------------------------------------

local addon = ProfBuddy
local TSF = addon:NewModule("TradeSkillFrame")

local DS   -- DataStore, set in Init
local RDB  -- RecipeDB, set in Init

----------------------------------------------------------------------
-- Dimensions
----------------------------------------------------------------------
local FRAME_W       = 740
local FRAME_H       = 540
local LIST_W        = 320
local DETAIL_W      = FRAME_W - LIST_W - 30
local ROW_H         = 20
local SKILL_BAR_H   = 22
local VISIBLE_ROWS  = 20
local CRAFT_BAR_H   = 52

----------------------------------------------------------------------
-- Colors
----------------------------------------------------------------------
local DIFF_COLORS = {
    optimal = { r = 1.0,  g = 0.5,  b = 0.25, hex = "|cffff8040" },
    medium  = { r = 1.0,  g = 1.0,  b = 0.0,  hex = "|cffffff00" },
    easy    = { r = 0.25, g = 0.75, b = 0.25, hex = "|cff40bf40" },
    trivial = { r = 0.5,  g = 0.5,  b = 0.5,  hex = "|cff808080" },
    header  = { r = 1.0,  g = 0.82, b = 0.0  },
}

local SOURCE_COLORS = {
    trainer    = "|cff00ff00",
    vendor     = "|cffffff00",
    drop       = "|cffff8800",
    quest      = "|cff4488ff",
    reputation = "|cff8844ff",
    discovery  = "|cffff44ff",
}

local DIFF_ORDER = { optimal = 1, medium = 2, easy = 3, trivial = 4 }

----------------------------------------------------------------------
-- Profession tier for tooltip sorting
-- Primary crafting = 1, Secondary (Smelting) = 2, Tertiary = 3
----------------------------------------------------------------------
local PROF_TIER = {
    ["Alchemy"]         = 1,
    ["Blacksmithing"]   = 1,
    ["Enchanting"]      = 1,
    ["Engineering"]     = 1,
    ["Jewelcrafting"]   = 1,
    ["Leatherworking"]  = 1,
    ["Tailoring"]       = 1,
    ["Smelting"]        = 2,
    ["Cooking"]         = 3,
    ["First Aid"]       = 3,
}

local function DiffColor(diff)
    return DIFF_COLORS[diff] or DIFF_COLORS.trivial
end

-- Compute difficulty tier from a skillRange array + character skill level
local function DiffFromSkillRange(sr, skill)
    if not sr or not skill then return "trivial" end
    if skill < (sr[1] or 0) then return "optimal" end
    if skill < (sr[2] or 0) then return "optimal" end
    if skill < (sr[3] or 0) then return "medium" end
    if skill < (sr[4] or 0) then return "easy" end
    return "trivial"
end

----------------------------------------------------------------------
-- Skill-range utilities
----------------------------------------------------------------------
local function GetSkillRange(recipe)
    if recipe.skillRange then
        return recipe.skillRange
    end
    if RDB and RDB.data and recipe.name then
        for _, profRecipes in pairs(RDB.data) do
            if profRecipes[recipe.name] and profRecipes[recipe.name].skillRange then
                return profRecipes[recipe.name].skillRange
            end
        end
    end
    return nil
end

local function GetSkillReq(recipe)
    if recipe.skillReq then return recipe.skillReq end
    if RDB and RDB.data and recipe.name then
        for _, profRecipes in pairs(RDB.data) do
            if profRecipes[recipe.name] and profRecipes[recipe.name].skillReq then
                return profRecipes[recipe.name].skillReq
            end
        end
    end
    return nil
end

local function SkillRangeCompact(range)
    if not range then return "" end
    return "(" .. range[1] .. "-" .. range[4] .. ")"
end

-- Maps the game's difficulty tier to the skillRange index (1=orange .. 4=grey)
local DIFF_TIER_INDEX = { optimal = 1, medium = 2, easy = 3, trivial = 4 }

-- Professions whose static skillRange NUMBERS are known-unreliable, so we
-- suppress the threshold-number DISPLAY for them (difficulty COLOR/tier
-- still comes from the live game). Empty now -- Smelting's ranges were
-- corrected from authoritative Blizzard DB2 (wago.tools, build 2.5.5.x),
-- so its numbers are trustworthy again. Re-add a profession here only if
-- its static ranges are ever found unreliable.
local RANGE_NUMBERS_HIDDEN = {}

-- knownDiff (optional): the recipe's ACTUAL difficulty tier -- from the live
-- game for your own profession, or the best-known value for a friend/alt.
-- When given, the bracketed tier follows it so the detail panel always
-- agrees with the recipe list (and the "Difficulty:" label), even if the
-- static range numbers are imperfect. Falls back to computing the tier from
-- currentSkill vs the range when not provided.
local function SkillRangeDetailed(range, currentSkill, knownDiff)
    if not range then return "" end

    local labels = { "Orange", "Yellow", "Green", "Grey" }
    local colors = {
        "|cffff8000",  -- orange
        "|cffffff00",  -- yellow
        "|cff00ff00",  -- green
        "|cff808080",  -- grey
    }

    local knownIdx = knownDiff and DIFF_TIER_INDEX[knownDiff] or nil

    local parts = {}
    for i = 1, 4 do
        local isCurrent = false
        if knownIdx then
            isCurrent = (i == knownIdx)
        elseif currentSkill then
            if i == 4 and currentSkill >= range[4] then
                isCurrent = true
            elseif i < 4 and currentSkill >= range[i] and currentSkill < range[i + 1] then
                isCurrent = true
            end
        end
        local text = labels[i] .. ": " .. range[i]
        if isCurrent then
            table.insert(parts, "|cffffffff>|r" .. colors[i] .. text .. "|r" .. "|cffffffff<|r")
        else
            table.insert(parts, colors[i] .. text .. "|r")
        end
    end

    return table.concat(parts, "  ")
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local state = {
    profName     = nil,
    skillLevel   = 0,
    maxSkill     = 375,
    recipes      = {},
    allRecipes   = {},
    recipeOrder  = {},
    selected     = nil,
    scrollOffset = 0,
    searchText   = "",
    filterDiff   = "All",
    filterCat    = "All",
    sortBy       = "Category",
    sortAsc      = true,
    showTab      = "known",
    categories   = {},
    isCraftWindow = false,
}

----------------------------------------------------------------------
-- Init + default window suppression (v6: ShowUIPanel hook)
----------------------------------------------------------------------
function TSF:Init()
    DS  = addon.DataStore
    RDB = addon.RecipeDB

    -- Lightweight per-frame bag-state tracker.  The game closes bags at
    -- the C level before any Lua event fires, so by the time we see
    -- TRADE_SKILL_SHOW the bags are already gone.  By keeping the
    -- PREVIOUS frame's snapshot we always have the last-known-open state.
    local function BagTrackerOnUpdate(tracker)
        wipe(tracker._prev)
        for k, v in pairs(tracker._cur) do tracker._prev[k] = v end
        wipe(tracker._cur)
        for bag = 0, 4 do
            if IsBagOpen(bag) then tracker._cur[bag] = true end
        end
    end
    local bagTracker = CreateFrame("Frame")
    bagTracker._cur  = {}
    bagTracker._prev = {}
    bagTracker:SetScript("OnUpdate", BagTrackerOnUpdate)
    self._bagTracker       = bagTracker
    self._bagTrackerUpdate = BagTrackerOnUpdate

    -- PB always opens on profession events regardless of setting.
    -- The setting only controls whether the default Blizzard frame
    -- is suppressed (on) or shown alongside PB (off).
    addon:RegisterEvent("TRADE_SKILL_SHOW", function()
        -- Grab the previous frame's bag state (before C-level close)
        self._savedBagState = {}
        local src = self._bagTracker._prev
        if not next(src) then src = self._bagTracker._cur end
        for k, v in pairs(src) do self._savedBagState[k] = v end
        -- Pause tracker so the snapshot isn't overwritten
        self._bagTracker:SetScript("OnUpdate", nil)
        if InCombatLockdown() then
            -- If PB is already open, update content in place (no Show needed)
            if self.frame and self.frame:IsShown() then
                C_Timer.After(0.01, function() self:OnTradeSkillShow() end)
            else
                self._pendingOpen = "trade"
            end
        else
            C_Timer.After(0.01, function() self:OnTradeSkillShow() end)
        end
    end)
    addon:RegisterEvent("TRADE_SKILL_CLOSE", function()
        if self._isMouseOverTab then return end
        -- Resume bag tracker if it was paused
        if self._bagTracker and self._bagTrackerUpdate then
            self._bagTracker:SetScript("OnUpdate", self._bagTrackerUpdate)
        end
        if not InCombatLockdown() then
            self:Hide(true)  -- from the game's close event; backend already closed
        end
    end)
    addon:RegisterEvent("TRADE_SKILL_UPDATE", function()
        if self.frame and self.frame:IsShown()
           and not (self.settingsPanel and self.settingsPanel:IsShown())
           and not state._viewCharKey then
            if self._craftingActive then
                -- During active crafting, update craftable counts and skill bar
                -- (the game has refreshed its data, safe to re-query now)
                C_Timer.After(0.05, function()
                    self:UpdateCraftableCounts()
                    -- Refresh skill bar in case we leveled up
                    local rank, maxRank
                    if state.isCraftWindow then
                        _, rank, maxRank = GetCraftDisplaySkillLine()
                    else
                        _, rank, maxRank = GetTradeSkillLine()
                    end
                    if rank and rank ~= state.skillLevel then
                        state.skillLevel = rank
                        state.maxSkill = maxRank or state.maxSkill
                        self:UpdateSkillBar()
                    end
                end)
            else
                C_Timer.After(0.05, function() self:OnTradeSkillShow() end)
            end
        end
    end)
    addon:RegisterEvent("CRAFT_SHOW", function()
        -- Same previous-frame snapshot as TRADE_SKILL_SHOW
        self._savedBagState = {}
        local src = self._bagTracker._prev
        if not next(src) then src = self._bagTracker._cur end
        for k, v in pairs(src) do self._savedBagState[k] = v end
        self._bagTracker:SetScript("OnUpdate", nil)
        if InCombatLockdown() then
            if self.frame and self.frame:IsShown() then
                C_Timer.After(0.01, function() self:OnCraftShow() end)
            else
                self._pendingOpen = "craft"
            end
        else
            C_Timer.After(0.01, function() self:OnCraftShow() end)
        end
    end)
    addon:RegisterEvent("CRAFT_CLOSE", function()
        if self._isMouseOverTab then return end
        if self._bagTracker and self._bagTrackerUpdate then
            self._bagTracker:SetScript("OnUpdate", self._bagTrackerUpdate)
        end
        if not InCombatLockdown() then
            self:Hide(true)  -- from the game's close event; backend already closed
        end
    end)
    -- Enchanting runs through the Craft API, which fires CRAFT_UPDATE
    -- (not TRADE_SKILL_UPDATE) when its data changes -- including after a
    -- skillup. Mirror the TRADE_SKILL_UPDATE handler so the skill bar and
    -- counts stay live for enchants, whether crafting a DoCraft batch
    -- (_craftingActive) or casting a single enchant via the secure button
    -- (the else branch refreshes through OnCraftShow -> UpdateSkillBar).
    addon:RegisterEvent("CRAFT_UPDATE", function()
        if self.frame and self.frame:IsShown()
           and state.isCraftWindow
           and not (self.settingsPanel and self.settingsPanel:IsShown())
           and not state._viewCharKey then
            if self._craftingActive then
                C_Timer.After(0.05, function()
                    self:UpdateCraftableCounts()
                    -- Refresh skill bar in case we leveled up mid-batch
                    local _, rank, maxRank = GetCraftDisplaySkillLine()
                    if rank and rank ~= state.skillLevel then
                        state.skillLevel = rank
                        state.maxSkill = maxRank or state.maxSkill
                        self:UpdateSkillBar()
                    end
                end)
            else
                C_Timer.After(0.05, function() self:OnCraftShow() end)
            end
        end
    end)

    -- When combat ends, open PB if a profession event fired mid-combat
    addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self._pendingOpen then
            local kind = self._pendingOpen
            self._pendingOpen = nil
            if kind == "craft" then
                self:OnCraftShow()
            else
                self:OnTradeSkillShow()
            end
        end
    end)

    -- Kill default profession frames by unregistering their events.
    -- When they never receive TRADE_SKILL_SHOW / CRAFT_SHOW, they
    -- never call ShowUIPanel, so no panel slot is claimed, no sounds
    -- play, and no taint is introduced.
    self:SuppressDefaultFrames()

    -- Hook GameTooltip to show "used in" recipe lines on item hover
    self:HookItemTooltip()

    -- Shift-compare: detect shift press/release while hovering a recipe row
    addon:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key, down)
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if not self.listRows then return end
        for _, row in ipairs(self.listRows) do
            if row._hoveredEntry and row:IsMouseOver() then
                if down == 1 then
                    if GameTooltip_ShowCompareItem then
                        GameTooltip_ShowCompareItem()
                    end
                else
                    if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
                    if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
                end
                break
            end
        end
    end)
end

----------------------------------------------------------------------
-- Tooltip "used in" hook
----------------------------------------------------------------------
function TSF:HookItemTooltip()
    if self._hookedTooltip then return end

    -- Compact "Bob, Carol, +2" string of class-colored knower names.
    local function knowerStr(list)
        local parts = {}
        for i, k in ipairs(list) do
            if i > 3 then
                table.insert(parts, "|cff888888+" .. (#list - 3) .. "|r")
                break
            end
            table.insert(parts, k.cc .. k.name .. "|r")
        end
        return table.concat(parts, ", ")
    end

    GameTooltip:HookScript("OnTooltipSetItem", function(tip)
        if not addon.db.settings.tooltipShowUsedIn then return end
        if not RDB then return end

        local _, itemLink = tip:GetItem()
        if not itemLink then return end
        local itemID = addon:ItemIDFromLink(itemLink)
        if not itemID then return end

        local usedIn = RDB:GetRecipesUsingReagent(itemID)
        if not usedIn or #usedIn == 0 then return end

        -- Build alt-aware sorted list
        local currentKey = addon:PlayerKey()
        local currentChar = DS and DS:GetCharacter(currentKey)
        local currentFaction = currentChar and currentChar.faction
        local showCrossFaction = addon.db.settings.showCrossFactionAlts
        local allChars = DS and DS:GetAllCharacters() or {}

        local currentProfs = {}
        if currentChar and currentChar.professions then
            for profName, _ in pairs(currentChar.professions) do
                currentProfs[profName] = true
            end
        end

        -- Smelting/Mining alias for DataStore lookup
        local profAliases = { Smelting = "Mining" }
        local showAltInTooltips = addon.db.settings.showAltInTooltips

        -- Deduplicate by recipeName+profName and determine who knows each
        local seen = {}
        local entries = {}
        for _, info in ipairs(usedIn) do
            local key = info.profName .. ":" .. info.recipeName
            if not seen[key] then
                seen[key] = true
                local tier = PROF_TIER[info.profName] or 99

                -- Check: does the current character know this recipe?
                local currentKnows = false
                local profsToCheck = { info.profName }
                if profAliases[info.profName] then
                    table.insert(profsToCheck, profAliases[info.profName])
                end
                if currentChar and currentChar.professions then
                    for _, pName in ipairs(profsToCheck) do
                        local pd = currentChar.professions[pName]
                        if pd and pd.recipes and pd.recipes[info.recipeName] then
                            currentKnows = true
                            break
                        end
                    end
                end

                -- Who else knows this recipe? Split alts (local) from
                -- friends (remote) so friends are never hidden behind an
                -- alt, and the two can be shown as distinct groups.
                local altKnowers = {}
                local friendKnowers = {}
                local showRemoteInTips = addon.db.settings.showRemoteInTooltips
                if not currentKnows and (showAltInTooltips or showRemoteInTips) then
                    for charKey, charData in pairs(allChars) do
                        if charKey ~= currentKey
                           and (showCrossFaction or charData.faction == currentFaction)
                           and charData.professions then
                            local knows = false
                            for _, pName in ipairs(profsToCheck) do
                                local pd = charData.professions[pName]
                                if pd and pd.recipes and pd.recipes[info.recipeName] then
                                    knows = true
                                    break
                                end
                            end
                            if knows then
                                local short = charKey:match("^([^-]+)") or charKey
                                local cc = addon:ClassColor(charData.class or "WARRIOR")
                                if charData.isRemote then
                                    if showRemoteInTips then
                                        table.insert(friendKnowers, { name = short, cc = cc })
                                    end
                                elseif showAltInTooltips then
                                    table.insert(altKnowers, { name = short, cc = cc })
                                end
                            end
                        end
                    end
                end

                table.insert(entries, {
                    recipeName    = info.recipeName,
                    profName      = info.profName,
                    count         = info.count,
                    isCurrent     = currentProfs[info.profName] or false,
                    tier          = tier,
                    currentKnows  = currentKnows,
                    altKnowers    = altKnowers,
                    friendKnowers = friendKnowers,
                })
            end
        end

        -- Partition into tiers: you know / an alt knows / a friend knows /
        -- nobody. A recipe known by both an alt and a friend lands in both,
        -- so a friend is never hidden behind an alt (option B).
        local ownEntries = {}
        local altEntries = {}
        local friendEntries = {}
        local nobodyEntries = {}
        for _, e in ipairs(entries) do
            if e.currentKnows then
                table.insert(ownEntries, e)
            else
                local placed = false
                if #e.altKnowers > 0 then
                    table.insert(altEntries, e)
                    placed = true
                end
                if #e.friendKnowers > 0 then
                    table.insert(friendEntries, e)
                    placed = true
                end
                if not placed then
                    table.insert(nobodyEntries, e)
                end
            end
        end

        local function sortEntries(t)
            table.sort(t, function(a, b)
                if a.tier ~= b.tier then return a.tier < b.tier end
                if a.profName ~= b.profName then return a.profName < b.profName end
                return a.recipeName < b.recipeName
            end)
        end
        sortEntries(ownEntries)
        sortEntries(altEntries)
        sortEntries(friendEntries)
        sortEntries(nobodyEntries)

        local maxOwn = addon.db.settings.tooltipMaxOwn or 16
        local maxAlt = addon.db.settings.tooltipMaxAlt or 16
        local maxOther = addon.db.settings.tooltipMaxOther or 5
        -- 16+ means uncapped; friends reuse the alt cap
        local shownOwn = maxOwn >= 16 and #ownEntries or math.min(#ownEntries, maxOwn)
        local shownAlt = maxAlt >= 16 and #altEntries or math.min(#altEntries, maxAlt)
        local shownFriend = maxAlt >= 16 and #friendEntries or math.min(#friendEntries, maxAlt)
        local shownOther = math.min(#nobodyEntries, maxOther)

        if shownOwn == 0 and shownAlt == 0 and shownFriend == 0 and shownOther == 0 then return end

        tip:AddLine(" ")
        tip:AddLine("----------------", 0.3, 0.3, 0.35)
        tip:AddLine("Used in (ProfessionBuddy):", 1, 0.82, 0)

        -- Section 1: You know (green)
        if shownOwn > 0 then
            for i = 1, shownOwn do
                local e = ownEntries[i]
                local line = "|cff00ff00" .. e.profName .. "|r - " .. e.recipeName
                if e.count > 1 then
                    line = line .. " (x" .. e.count .. ")"
                end
                tip:AddLine(line, 1, 1, 1)
            end
            if #ownEntries > shownOwn then
                tip:AddLine("|cff666666... and " .. (#ownEntries - shownOwn) .. " more|r")
            end
        end

        -- Section 2: An alt knows (yellow), listing all alt knowers
        if shownAlt > 0 then
            if shownOwn > 0 then tip:AddLine(" ") end
            tip:AddLine("Alts:", 0.9, 0.82, 0.2)
            for i = 1, shownAlt do
                local e = altEntries[i]
                local line = "|cffffff00" .. e.profName .. "|r - " .. e.recipeName
                    .. "  " .. knowerStr(e.altKnowers)
                if e.count > 1 then
                    line = line .. " (x" .. e.count .. ")"
                end
                tip:AddLine(line, 1, 1, 1)
            end
            if #altEntries > shownAlt then
                tip:AddLine("|cff666666... and " .. (#altEntries - shownAlt) .. " more|r")
            end
        end

        -- Section 3: A friend knows (light blue), listing all friend knowers
        if shownFriend > 0 then
            if shownOwn > 0 or shownAlt > 0 then tip:AddLine(" ") end
            tip:AddLine("Friends:", 0.5, 0.75, 1)
            for i = 1, shownFriend do
                local e = friendEntries[i]
                local line = "|cff80c8ff" .. e.profName .. "|r - " .. e.recipeName
                    .. "  " .. knowerStr(e.friendKnowers)
                if e.count > 1 then
                    line = line .. " (x" .. e.count .. ")"
                end
                tip:AddLine(line, 1, 1, 1)
            end
            if #friendEntries > shownFriend then
                tip:AddLine("|cff666666... and " .. (#friendEntries - shownFriend) .. " more|r")
            end
        end

        -- Section 4: Nobody knows (grey)
        if shownOther > 0 then
            if shownOwn > 0 or shownAlt > 0 or shownFriend > 0 then tip:AddLine(" ") end
            for i = 1, shownOther do
                local e = nobodyEntries[i]
                local line = "|cff888888" .. e.profName .. "|r - " .. e.recipeName
                if e.count > 1 then
                    line = line .. " (x" .. e.count .. ")"
                end
                tip:AddLine(line, 1, 1, 1)
            end
            if #nobodyEntries > shownOther then
                tip:AddLine("|cff666666... and " .. (#nobodyEntries - shownOther) .. " more|r")
            end
        end

        tip:AddLine("----------------", 0.3, 0.3, 0.35)

        tip:Show()
    end)

    -- "Craftable by" tooltip: shows which alts can craft the hovered item
    GameTooltip:HookScript("OnTooltipSetItem", function(tip)
        if not (addon.db.settings.showAltInTooltips
                or addon.db.settings.showRemoteInTooltips) then return end
        if not DS then return end
        if not RDB then return end

        local _, itemLink = tip:GetItem()
        if not itemLink then return end
        local itemID = addon:ItemIDFromLink(itemLink)
        if not itemID then return end

        local recipeInfo = RDB:GetRecipeForItem(itemID)
        if not recipeInfo then return end

        local recipeName = recipeInfo.recipeName
        local profName = recipeInfo.profName
        local currentKey = addon:PlayerKey()
        local currentChar = DS:GetCharacter(currentKey)
        local currentFaction = currentChar and currentChar.faction
        local showCrossFaction = addon.db.settings.showCrossFactionAlts
        local allChars = DS:GetAllCharacters()

        -- Smelting recipes may be stored under "Mining" in DataStore
        local profAliases = { Smelting = "Mining" }
        local profsToCheck = { profName }
        if profAliases[profName] then
            table.insert(profsToCheck, profAliases[profName])
        end

        local showRemote = addon.db.settings.showRemoteInTooltips
        local showAlts = addon.db.settings.showAltInTooltips

        local crafters = {}
        for charKey, charData in pairs(allChars) do
            local isCurrent = (charKey == currentKey)
            -- Alt and friend visibility are independent; you always count.
            local typeOK = isCurrent
                or (charData.isRemote and showRemote)
                or (not charData.isRemote and showAlts)
            if typeOK
               and (isCurrent or showCrossFaction or charData.faction == currentFaction)
               and charData.professions then
                for _, pName in ipairs(profsToCheck) do
                    local profData = charData.professions[pName]
                    if profData and profData.recipes and profData.recipes[recipeName] then
                        local classColor = addon:ClassColor(charData.class or "WARRIOR")
                        table.insert(crafters, {
                            key = charKey,
                            classColor = classColor,
                            skill = profData.skillLevel or 0,
                            profDisplay = profName,
                            isCurrent = isCurrent,
                        })
                        break
                    end
                end
            end
        end

        if #crafters == 0 then return end

        -- Split into locals (you + alts) and friends, shown as groups.
        local localCrafters, friendCrafters = {}, {}
        for _, c in ipairs(crafters) do
            if DS and DS:IsRemote(c.key) then
                table.insert(friendCrafters, c)
            else
                table.insert(localCrafters, c)
            end
        end
        table.sort(localCrafters, function(a, b)
            if a.isCurrent ~= b.isCurrent then return a.isCurrent end
            return a.key < b.key
        end)
        table.sort(friendCrafters, function(a, b) return a.key < b.key end)

        tip:AddLine(" ")
        tip:AddLine("Craftable by (ProfessionBuddy):", 1, 0.82, 0)
        for _, c in ipairs(localCrafters) do
            local short = c.key:match("^([^-]+)") or c.key
            local suffix = c.isCurrent and " |cff00ff00(you)|r" or ""
            tip:AddLine("  " .. c.classColor .. short .. "|r - " .. profName .. " " .. c.skill .. suffix, 1, 1, 1)
        end
        if #friendCrafters > 0 then
            tip:AddLine("Friends:", 0.5, 0.75, 1)
            for _, c in ipairs(friendCrafters) do
                local short = c.key:match("^([^-]+)") or c.key
                tip:AddLine("  " .. c.classColor .. short .. "|r - " .. profName .. " " .. c.skill, 1, 1, 1)
            end
        end

        tip:Show()
    end)

    self._hookedTooltip = true
end

function TSF:SuppressDefaultFrames()
    if not addon.db.settings.replaceTradeSkill then return end

    local killed = {}  -- track what we've already killed

    local function DoKill(frame, frameName)
        if not frame or killed[frameName] then return end
        killed[frameName] = true
        -- 1. Strip all scripts so Hide()/Show() won't cascade into
        --    CloseTradeSkill(), play sounds, fire OnEvent, etc.
        frame:SetScript("OnShow", nil)
        frame:SetScript("OnHide", nil)
        frame:SetScript("OnEvent", nil)
        -- 2. Remove from UIPanelWindows so ShowUIPanel won't claim
        --    a panel slot for this frame.
        if UIPanelWindows then
            UIPanelWindows[frameName] = nil
        end
        -- 3. Unregister all events so Lua-side handlers never fire.
        frame:UnregisterAllEvents()
        -- 4. Override Show() so the frame can NEVER be made visible.
        frame.Show = function() end
        -- 5. Now safe to Hide() -- scripts are stripped, so no cascade.
        frame:Hide()
    end

    -- Primary kill path: ADDON_LOADED fires when on-demand addon loads.
    local killTargets = {
        Blizzard_TradeSkillUI = "TradeSkillFrame",
        Blizzard_CraftUI      = "CraftFrame",
    }
    for addonName, frameName in pairs(killTargets) do
        local frame = _G[frameName]
        if frame then
            DoKill(frame, frameName)
        else
            addon:RegisterEvent("ADDON_LOADED", function(_, name)
                if name ~= addonName then return end
                DoKill(_G[frameName], frameName)
            end)
        end
    end

    -- Safety net: if WoW dispatches TRADE_SKILL_SHOW to the default
    -- frame BEFORE our ADDON_LOADED handler fires, ShowUIPanel will
    -- have already shown it.  hooksecurefunc runs immediately after
    -- ShowUIPanel completes, so we catch and kill it with zero delay.
    -- (hooksecurefunc does NOT taint -- it appends a post-hook, unlike
    -- replacing the global function which was the previous approach.)
    hooksecurefunc("ShowUIPanel", function(frame)
        if not frame then return end
        local name = frame:GetName()
        if name == "TradeSkillFrame" or name == "CraftFrame" then
            DoKill(frame, name)
        end
    end)
end

function TSF:NukeFrame(frame)
    if not frame then return end
    frame:SetAlpha(0)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
    frame:EnableMouse(false)
    frame:EnableKeyboard(false)
end

function TSF:RestoreFrame(frame)
    if not frame then return end
    frame:SetAlpha(1)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    -- Force it visible at the restored position so the user
    -- can see the change took effect immediately
    frame:Show()
    frame:Raise()
end

----------------------------------------------------------------------
-- Custom dropdown widget (v6: supports prefix labels)
----------------------------------------------------------------------
local allDropdowns = {}

local function CloseAllDropdowns()
    for _, dd in ipairs(allDropdowns) do
        dd.listFrame:Hide()
    end
end

local function CreateDropdown(parent, width, options, defaultVal, onChange, prefix)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 20)
    container.prefix = prefix or ""

    local btn = CreateFrame("Button", nil, container)
    btn:SetSize(width, 20)
    btn:SetPoint("TOPLEFT", 0, 0)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetColorTexture(0.12, 0.12, 0.15, 1)

    local btnBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btnBorder:SetAllPoints()
    btnBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
    btnBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -14, 0)
    btnText:SetJustifyH("LEFT")

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.6, 0.6, 0.6)

    local listFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    listFrame:SetWidth(width)
    listFrame:SetFrameStrata("TOOLTIP")
    listFrame:SetFrameLevel(200)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    listFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.98)
    listFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
    listFrame:Hide()

    container.btn = btn
    container.btnText = btnText
    container.listFrame = listFrame
    container.optionBtns = {}
    container.selectedValue = defaultVal

    local function DisplayText(val)
        if container.prefix ~= "" then
            return container.prefix .. val
        end
        return val
    end

    btnText:SetText(DisplayText(defaultVal))

    function container:SetOptions(opts)
        for _, ob in ipairs(self.optionBtns) do
            ob:Hide()
            ob:SetParent(nil)
        end
        wipe(self.optionBtns)

        local maxVisible = math.min(#opts, 16)
        self.listFrame:SetHeight(maxVisible * 18 + 8)

        for i, opt in ipairs(opts) do
            if i > 16 then break end
            local optBtn = CreateFrame("Button", nil, self.listFrame)
            optBtn:SetSize(width - 8, 18)
            optBtn:SetPoint("TOPLEFT", 4, -((i - 1) * 18) - 4)

            local optHighlight = optBtn:CreateTexture(nil, "HIGHLIGHT")
            optHighlight:SetAllPoints()
            optHighlight:SetColorTexture(0.3, 0.3, 0.5, 0.5)

            local optText = optBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            optText:SetPoint("LEFT", 4, 0)
            optText:SetText(opt)
            if opt == self.selectedValue then
                optText:SetTextColor(0.3, 0.8, 1)
            else
                optText:SetTextColor(0.9, 0.9, 0.9)
            end

            optBtn:SetScript("OnClick", function()
                self.selectedValue = opt
                self.btnText:SetText(DisplayText(opt))
                self.listFrame:Hide()
                if onChange then onChange(opt) end
            end)

            table.insert(self.optionBtns, optBtn)
        end
    end

    function container:SetValue(displayVal, rawVal)
        self.selectedValue = rawVal or displayVal
        self.btnText:SetText(DisplayText(displayVal))
    end

    local function PositionList()
        local x, y = btn:GetCenter()
        local bw = btn:GetWidth()
        local left = x - bw / 2
        local bottom = select(2, btn:GetRect())
        listFrame:ClearAllPoints()
        listFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    end

    btn:SetScript("OnClick", function()
        if listFrame:IsShown() then
            listFrame:Hide()
        else
            CloseAllDropdowns()
            -- Refresh option text colors to highlight current selection
            for _, ob in ipairs(container.optionBtns) do
                local fs = select(1, ob:GetRegions())
                -- Walk regions to find the FontString
                for ri = 1, ob:GetNumRegions() do
                    local region = select(ri, ob:GetRegions())
                    if region.GetText then
                        if region:GetText() == container.selectedValue then
                            region:SetTextColor(0.3, 0.8, 1)
                        else
                            region:SetTextColor(0.9, 0.9, 0.9)
                        end
                        break
                    end
                end
            end
            PositionList()
            listFrame:Show()
        end
    end)

    table.insert(allDropdowns, container)
    container:SetOptions(options)
    return container
end

----------------------------------------------------------------------
-- Build the frame
----------------------------------------------------------------------
function TSF:EnsureFrame()
    if self.frame then return end

    local f = CreateFrame("Frame", "ProfBuddyTradeSkillFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:Hide()
    f.TitleText:SetText("Profession Buddy")

    f:SetScript("OnMouseDown", function()
        CloseAllDropdowns()
        if self.qtyBox then self.qtyBox:ClearFocus() end
        if self.composerQty then self.composerQty:ClearFocus() end
        if self.composerNote then self.composerNote:ClearFocus() end
    end)
    f:SetScript("OnLeave", function()
        if self._qtyBox and self._qtyBox:HasFocus() then
            self._qtyBox:ClearFocus()
        end
    end)
    f:SetScript("OnHide", function()
        CloseAllDropdowns()
        if self.calcPanel then self.calcPanel:Hide() end
        -- Defer RestoreContentPanels to break the taint chain -- when
        -- Blizzard's HideUIPanel triggers this OnHide, we're inside a
        -- secure execution path and any Show() call would be blocked.
        C_Timer.After(0, function() self:RestoreContentPanels() end)
        -- Close the backend trade skill so the profession icon doesn't
        -- need a double-click to reopen after closing via the X button.
        if not self._closingFromEvent then
            if state.isCraftWindow then
                CloseCraft()
            else
                CloseTradeSkill()
            end
        end
    end)

    table.insert(UISpecialFrames, "ProfBuddyTradeSkillFrame")
    self.frame = f

    self:BuildHeader(f)
    self:BuildProfessionTabs(f)

    self:BuildToolbar(f)
    self:BuildRecipeList(f)
    self:BuildDetailPanel(f)
    self:BuildCalcPanel()
    self:BuildCraftBar(f)
    self:BuildComposer(f)
    self:BuildBottomBar(f)
    self:BuildSettingsPanel(f)
    self:BuildNavStrip(f)

    -- Expose state so MaterialCalc can access live recipe data
    self.state = state
end

----------------------------------------------------------------------
-- Header (v6: title left, search right, then skill bar below)
----------------------------------------------------------------------
function TSF:BuildHeader(parent)
    -- Title text is now rendered centered on the skill bar (see UpdateSkillBar)
    -- We keep a hidden reference for compatibility
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -28)
    title:Hide()
    self.titleText = title

    -- Settings gear button (title bar, left of the X close button)
    local gearBtn = CreateFrame("Button", nil, parent)
    gearBtn:SetSize(18, 18)
    gearBtn:SetPoint("TOPRIGHT", -26, -4)
    gearBtn:SetFrameLevel(parent:GetFrameLevel() + 5)

    local gearIcon = gearBtn:CreateTexture(nil, "ARTWORK")
    gearIcon:SetAllPoints()
    gearIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    gearIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    gearBtn.icon = gearIcon

    gearBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 0.6)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:Hide()
    end)
    gearBtn:SetScript("OnClick", function()
        TSF:ToggleSettings()
    end)
    self.gearBtn = gearBtn

    -- (Friends moved to the persistent bottom nav strip; see BuildNavStrip)

    -- Search box right-aligned on the same row as title
    local search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    search:SetHeight(20)
    search:SetWidth(220)
    search:SetPoint("TOPRIGHT", -12, -28)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)

    local searchPlaceholder = search:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchPlaceholder:SetPoint("LEFT", 4, 0)
    searchPlaceholder:SetText("Search...")
    searchPlaceholder:SetTextColor(0.4, 0.4, 0.4)
    self.searchPlaceholder = searchPlaceholder

    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        state.searchText = text:lower()
        searchPlaceholder:SetShown(text == "")
        TSF:RefreshRecipeList()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnMouseDown", function() CloseAllDropdowns() end)
    self.searchBox = search

    -- Row 2: skill bar
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(FRAME_W - 24, SKILL_BAR_H)
    bar:SetPoint("TOPLEFT", 12, -52)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.45, 0.85)
    bar:SetMinMaxValues(0, 375)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.08, 0.08, 0.08, 0.9)

    local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barText:SetPoint("CENTER")

    self.skillBar = bar
    self.skillBarText = barText
end

----------------------------------------------------------------------
-- Persistent bottom nav strip (Characters / Friends / Orders)
-- Mirrors the main /pb window's bottom tabs so navigation is the same
-- everywhere. From the profession window these navigate by swapping to
-- the main window on that tab (same behavior the old top Friends icon
-- had). None is ever "active" here since the profession view is not one
-- of the three sections.
----------------------------------------------------------------------
function TSF:BuildNavStrip(parent)
    local TAB_W, TAB_H, TAB_PAD = 90, 24, 4
    local defs = {
        { text = "Characters", toggle = function()
            if addon.CharacterPanel then addon.CharacterPanel:Toggle() end
        end },
        { text = "Friends", toggle = function()
            if addon.FriendsPanel then addon.FriendsPanel:Toggle() end
        end },
        { text = "Orders", toggle = function()
            if addon.OrdersPanel then addon.OrdersPanel:Toggle() end
        end },
    }

    self.navTabs = {}
    local prev
    for i, def in ipairs(defs) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(TAB_W, TAB_H)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        btn:SetText(def.text)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

        local border = btn:CreateTexture(nil, "BORDER")
        border:SetHeight(1)
        border:SetPoint("BOTTOMLEFT")
        border:SetPoint("BOTTOMRIGHT")
        border:SetColorTexture(0.4, 0.4, 0.4, 1)

        if i == 1 then
            btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, -TAB_H - 2)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", TAB_PAD, 0)
        end

        btn:SetScript("OnClick", def.toggle)

        -- Count badge on the Orders nav button (so it's visible from the
        -- profession window too)
        if def.text == "Orders" and addon.OrdersPanel and addon.OrdersPanel.CreateBadge then
            addon.OrdersPanel:CreateBadge(btn)
        end

        prev = btn
        self.navTabs[i] = btn
    end
end

function TSF:UpdateSkillBar()
    local skill = state.skillLevel or 0
    local maxSkill = state.maxSkill or 375
    local profName = state.profName or "Unknown"
    self.titleText:SetText(profName)
    self.skillBar:SetMinMaxValues(0, maxSkill)
    self.skillBar:SetValue(skill)
    self.skillBarText:SetText(profName .. "  -  " .. skill .. " / " .. maxSkill)
    self:UpdateProfessionTabs()
end

----------------------------------------------------------------------
-- Profession tabs (icon buttons to switch between learned professions)
----------------------------------------------------------------------
local PROF_ICONS = {
    ["Alchemy"]         = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"]   = "Interface\\Icons\\Trade_BlackSmithing",
    ["Cooking"]         = "Interface\\Icons\\INV_Misc_Food_15",
    ["Enchanting"]      = "Interface\\Icons\\Trade_Engraving",
    ["Engineering"]     = "Interface\\Icons\\Trade_Engineering",
    ["First Aid"]       = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Jewelcrafting"]   = "Interface\\Icons\\INV_Misc_Gem_01",
    ["Leatherworking"]  = "Interface\\Icons\\Trade_LeatherWorking",
    ["Tailoring"]       = "Interface\\Icons\\Trade_Tailoring",
    ["Mining"]          = "Interface\\Icons\\Trade_Mining",
    ["Find Minerals"]   = "Interface\\Icons\\Spell_Nature_Earthquake",
    ["Herbalism"]       = "Interface\\Icons\\Trade_Herbalism",
    ["Skinning"]        = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    ["Fishing"]         = "Interface\\Icons\\Trade_Fishing",
}

-- Profession sort order: crafting primary first (alpha), gathering primary
-- (alpha), then secondary (alpha). Smelting counts as gathering.
local PROF_ORDER = {
    ["Alchemy"] = 10, ["Blacksmithing"] = 11, ["Enchanting"] = 12,
    ["Engineering"] = 13, ["Jewelcrafting"] = 14, ["Leatherworking"] = 15,
    ["Tailoring"] = 16,
    ["Herbalism"] = 20,
    ["Mining"] = 21, ["Find Minerals"] = 21.5, ["Skinning"] = 22,
    ["Cooking"] = 30, ["First Aid"] = 31, ["Fishing"] = 32,
}

-- All possible profession tabs, pre-built to avoid taint.
-- Mining gets two tabs: Smelting (opens the tradeskill window) and
-- Find Minerals (toggles tracking). "Find Minerals" is keyed
-- separately so it gets its own button.
local ALL_TAB_PROFS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Find Minerals", "First Aid", "Fishing",
    "Jewelcrafting", "Leatherworking", "Mining", "Skinning", "Tailoring",
}

-- Professions that have a browsable recipe window in the static DB.
-- Only these appear as unknown tabs (gathering/utility profs have no
-- recipe list to browse).
local CRAFTABLE_PROFS = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
    ["Enchanting"] = true, ["Engineering"] = true, ["First Aid"] = true,
    ["Jewelcrafting"] = true, ["Leatherworking"] = true,
    ["Smelting"] = true, ["Tailoring"] = true,
}

function TSF:BuildProfessionTabs(parent)
    self.profTabsByName = {}
    self.profTabContainer = CreateFrame("Frame", nil, parent)
    self.profTabContainer:SetSize(300, 22)
    self.profTabContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -28)
    self.profTabContainer:SetFrameLevel(parent:GetFrameLevel() + 5)

    local TAB_SIZE = 22

    -- Pre-create a secure button for every profession with attributes
    -- set NOW (at frame build time, before any taint)
    for idx, profName in ipairs(ALL_TAB_PROFS) do
        local tab = CreateFrame("Button", "ProfBuddyProfTab" .. idx, self.profTabContainer, "SecureActionButtonTemplate")
        tab:SetSize(TAB_SIZE, TAB_SIZE)

        -- Register for clicks (modern client requires explicit registration)
        tab:RegisterForClicks("AnyUp", "AnyDown")

        -- Set secure attributes at creation time -- never touched again
        -- Use macro type for reliable profession opening
        -- Gathering profs: Mining opens Smelting, Herbalism/Skinning
        -- toggle their respective spells
        local MACRO_OVERRIDES = {
            ["Mining"]        = "/cast Smelting",
            ["Find Minerals"] = "/cast Find Minerals",
            ["Herbalism"]     = "/cast Find Herbs",
        }
        tab:SetAttribute("type", "macro")
        tab:SetAttribute("macrotext", MACRO_OVERRIDES[profName] or ("/cast " .. profName))

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.12, 0.15, 0.9)
        tab.bg = bg

        local border = CreateFrame("Frame", nil, tab, "BackdropTemplate")
        border:SetAllPoints()
        border:EnableMouse(false)  -- don't eat clicks meant for the button
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
        tab.border = border

        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetSize(TAB_SIZE - 4, TAB_SIZE - 4)
        icon:SetPoint("CENTER")
        icon:SetTexture(PROF_ICONS[profName] or "Interface\\Icons\\INV_Misc_QuestionMark")
        tab.icon = icon

        tab.profName = profName

        tab:SetScript("OnEnter", function(self)
            TSF._isMouseOverTab = true
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.profName)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function()
            TSF._isMouseOverTab = false
            GameTooltip:Hide()
        end)

        -- PostClick: if this is an unknown profession, the secure macro
        -- silently fails. Open the static-only view instead.
        tab:SetScript("PostClick", function(self)
            if self._isUnknown then
                TSF:OpenWithStatic(self.profName)
            end
        end)

        tab:Hide()
        self.profTabsByName[profName] = tab
    end

    -- Separator line between known and unknown profession tabs
    local sep = self.profTabContainer:CreateTexture(nil, "ARTWORK")
    sep:SetSize(2, 20)
    sep:SetColorTexture(0.6, 0.6, 0.6, 0.8)
    sep:Hide()
    self.profTabSeparator = sep
end

function TSF:UpdateProfessionTabs()
    -- Hide/Show/SetPoint on SecureActionButtonTemplate buttons is blocked
    -- during combat. Only update the active highlight (non-protected calls).
    if InCombatLockdown() then
        self:UpdateProfessionTabHighlight()
        return
    end

    local TAB_SIZE = 22
    local TAB_GAP = 2
    local SEP_W = 10  -- gap reserved for the separator line

    -- Hide all tabs and separator
    for _, tab in pairs(self.profTabsByName) do
        tab:Hide()
        tab._isUnknown = false
    end
    if self.profTabSeparator then self.profTabSeparator:Hide() end

    -- Get current character's professions from DataStore
    local char = DS:GetCharacter()
    if not char or not char.professions then return end

    -- Build known profession list (same order as before)
    local knownSet = {}
    local knownList = {}
    for profName, _ in pairs(char.professions) do
        if self.profTabsByName[profName] then
            knownSet[profName] = true
            table.insert(knownList, profName)
            if profName == "Mining" then
                knownSet["Find Minerals"] = true
                if self.profTabsByName["Find Minerals"] then
                    table.insert(knownList, "Find Minerals")
                end
                -- Mining implies Smelting is known
                knownSet["Smelting"] = true
            end
        end
    end

    table.sort(knownList, function(a, b)
        return (PROF_ORDER[a] or 99) < (PROF_ORDER[b] or 99)
    end)

    -- Build unknown craftable profession list (only if setting is on)
    local unknownList = {}
    if addon.db.settings.showAllProfessions then
        for profName in pairs(CRAFTABLE_PROFS) do
            if not knownSet[profName] and self.profTabsByName[profName] then
                table.insert(unknownList, profName)
            end
        end
        table.sort(unknownList, function(a, b)
            return (PROF_ORDER[a] or 99) < (PROF_ORDER[b] or 99)
        end)
    end

    local activeName = state.profName
    -- Smelting is displayed under the Mining tab
    if activeName == "Smelting" then activeName = "Mining" end

    local xOffset = 0

    -- Place known tabs
    for _, profName in ipairs(knownList) do
        local tab = self.profTabsByName[profName]
        tab._isUnknown = false
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", self.profTabContainer, "LEFT", xOffset, 0)

        local isActive = (profName == activeName)
            and profName ~= "Find Minerals"

        if isActive then
            tab.bg:SetColorTexture(0.2, 0.35, 0.55, 0.9)
            tab.border:SetBackdropBorderColor(0.4, 0.7, 1, 0.9)
        else
            tab.bg:SetColorTexture(0.12, 0.12, 0.15, 0.9)
            tab.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
        end
        tab.icon:SetDesaturated(false)
        tab.icon:SetAlpha(1)
        tab:Show()
        xOffset = xOffset + TAB_SIZE + TAB_GAP
    end

    -- Place separator and unknown tabs
    if #unknownList > 0 then
        local sep = self.profTabSeparator
        sep:ClearAllPoints()
        sep:SetPoint("LEFT", self.profTabContainer, "LEFT", xOffset + 4, 0)
        sep:Show()
        xOffset = xOffset + SEP_W

        for _, profName in ipairs(unknownList) do
            local tab = self.profTabsByName[profName]
            tab._isUnknown = true
            tab:ClearAllPoints()
            tab:SetPoint("LEFT", self.profTabContainer, "LEFT", xOffset, 0)

            local isActive = (profName == activeName)

            if isActive then
                tab.bg:SetColorTexture(0.2, 0.35, 0.55, 0.9)
                tab.border:SetBackdropBorderColor(0.4, 0.7, 1, 0.9)
                tab.icon:SetDesaturated(false)
                tab.icon:SetAlpha(1)
            else
                tab.bg:SetColorTexture(0.08, 0.08, 0.1, 0.9)
                tab.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.4)
                tab.icon:SetDesaturated(true)
                tab.icon:SetAlpha(0.5)
            end
            tab:Show()
            xOffset = xOffset + TAB_SIZE + TAB_GAP
        end
    end
end

-- Lightweight highlight update for use during combat.
-- Only calls non-protected methods (SetColorTexture, SetBackdropBorderColor,
-- SetDesaturated, SetAlpha on sub-textures). No Hide/Show/SetPoint.
function TSF:UpdateProfessionTabHighlight()
    local activeName = state.profName
    if activeName == "Smelting" then activeName = "Mining" end

    for _, tab in pairs(self.profTabsByName) do
        if tab:IsShown() then
            local isActive = (tab.profName == activeName)
                and tab.profName ~= "Find Minerals"

            if tab._isUnknown then
                if isActive then
                    tab.bg:SetColorTexture(0.2, 0.35, 0.55, 0.9)
                    tab.border:SetBackdropBorderColor(0.4, 0.7, 1, 0.9)
                    tab.icon:SetDesaturated(false)
                    tab.icon:SetAlpha(1)
                else
                    tab.bg:SetColorTexture(0.08, 0.08, 0.1, 0.9)
                    tab.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.4)
                    tab.icon:SetDesaturated(true)
                    tab.icon:SetAlpha(0.5)
                end
            else
                if isActive then
                    tab.bg:SetColorTexture(0.2, 0.35, 0.55, 0.9)
                    tab.border:SetBackdropBorderColor(0.4, 0.7, 1, 0.9)
                else
                    tab.bg:SetColorTexture(0.12, 0.12, 0.15, 0.9)
                    tab.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Toolbar (v6: DDLs only, search moved to header)
-- [Type: All v]  [Difficulty: All v]  [Sort: Category v]  [View: Known (7) v]
----------------------------------------------------------------------
function TSF:BuildToolbar(parent)
    local toolbarY = -80

    -- Sort dropdown (re-clicking the active sort toggles direction)
    local function SortLabel()
        local arrow = state.sortAsc and " ^" or " v"
        return "Sort: " .. state.sortBy .. arrow
    end
    self.sortDropdown = CreateDropdown(parent, 140,
        {"Category", "Skill Ups", "Name"}, "Category",
        function(val)
            if state.sortBy == val then
                state.sortAsc = not state.sortAsc
            else
                state.sortBy = val
                state.sortAsc = true
            end
            self.sortDropdown:SetValue(SortLabel(), state.sortBy)
            self:RefreshRecipeList()
        end,
        ""
    )
    self.sortDropdown:SetValue("Sort: " .. (state.sortBy or "Category") .. (state.sortAsc and " ^" or " v"), state.sortBy or "Category")
    self.sortDropdown:SetPoint("TOPLEFT", 12, toolbarY)

    -- Type dropdown
    self.catDropdown = CreateDropdown(parent, 140,
        {"All"}, "All",
        function(val)
            state.filterCat = val
            self:RefreshRecipeList()
        end,
        "Type: "
    )
    self.catDropdown:SetPoint("LEFT", self.sortDropdown, "RIGHT", 4, 0)

    -- Skill Up dropdown
    self.diffDropdown = CreateDropdown(parent, 130,
        {"All", "Orange", "Yellow", "Green", "Grey"}, "All",
        function(val)
            state.filterDiff = val
            self:RefreshRecipeList()
        end,
        "Skill Up: "
    )
    self.diffDropdown:SetPoint("LEFT", self.catDropdown, "RIGHT", 4, 0)

    -- View dropdown (right-aligned)
    self.viewDropdown = CreateDropdown(parent, 150,
        {"Known", "Missing", "All"}, "Known",
        function(val)
            local base = val:match("^(%a+)") or val
            state.showTab = base:lower()
            state.selected = nil
            state.scrollOffset = 0
            self:RefreshRecipeList()
        end,
        "View: "
    )
    self.viewDropdown:SetPoint("TOPRIGHT", -12, toolbarY)
end

function TSF:UpdateViewDropdown()
    local knownCount = 0
    for _ in pairs(state.allRecipes) do
        knownCount = knownCount + 1
    end

    local missingCount = 0
    if RDB and RDB.data[state.profName] then
        local viewChar = state._viewCharKey or addon:PlayerKey()
        local unknown = RDB:GetUnknownRecipes(viewChar, state.profName)
        for _ in pairs(unknown) do
            missingCount = missingCount + 1
        end
    end

    -- Static view (unknown profession): only show Missing
    if state._isStaticView then
        local opts = { "Missing (" .. missingCount .. ")" }
        self.viewDropdown:SetOptions(opts)
        self.viewDropdown:SetValue(opts[1])
        return
    end

    local totalCount = knownCount + missingCount

    local opts = {
        "Known (" .. knownCount .. ")",
        "Missing (" .. missingCount .. ")",
        "All (" .. totalCount .. ")",
    }
    self.viewDropdown:SetOptions(opts)

    if state.showTab == "known" then
        self.viewDropdown:SetValue(opts[1])
    elseif state.showTab == "missing" then
        self.viewDropdown:SetValue(opts[2])
    else
        self.viewDropdown:SetValue(opts[3])
    end
end

----------------------------------------------------------------------
-- Recipe list (left panel)
----------------------------------------------------------------------
function TSF:BuildRecipeList(parent)
    local topOffset = -106

    local listPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", 10, topOffset)
    listPanel:SetPoint("BOTTOMLEFT", 10, 30)
    listPanel:SetWidth(LIST_W)
    listPanel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    listPanel:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    listPanel:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.8)

    self.listRows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, listPanel)
        row:SetSize(LIST_W - 22, ROW_H)
        row:SetPoint("TOPLEFT", 4, -((i - 1) * ROW_H) - 2)

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.25, 0.3, 0.45, 0.35)

        local selectedBg = row:CreateTexture(nil, "BACKGROUND")
        selectedBg:SetAllPoints()
        selectedBg:SetColorTexture(0.18, 0.22, 0.35, 0.7)
        selectedBg:Hide()
        row.selectedBg = selectedBg

        local headerBg = row:CreateTexture(nil, "BACKGROUND")
        headerBg:SetAllPoints()
        headerBg:SetColorTexture(0.2, 0.17, 0.05, 0.6)
        headerBg:Hide()
        row.headerBg = headerBg

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ROW_H - 4, ROW_H - 4)
        icon:SetPoint("LEFT", 2, 0)
        row.icon = icon

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        nameText:SetPoint("RIGHT", -40, 0)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local rightText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rightText:SetPoint("RIGHT", -4, 0)
        rightText:SetJustifyH("RIGHT")
        row.rightText = rightText

        row:SetScript("OnClick", function(_, button)
            CloseAllDropdowns()
            local dataIdx = i + state.scrollOffset
            local entry = state.recipes[dataIdx]
            if not entry then return end

            -- Header click: toggle collapse
            if entry.isHeader and entry.headerKey then
                state.collapsed = state.collapsed or {}
                state.collapsed[entry.headerKey] = not state.collapsed[entry.headerKey]
                self:RefreshRecipeList()
                return
            end
            if entry.isHeader then return end

            -- v6: Shift-click to link into chat
            if IsModifiedClick("CHATLINK") then
                local link = entry.itemLink
                if not link and entry.itemID then
                    local itemName = GetItemInfo(entry.itemID)
                    if itemName then
                        link = select(2, GetItemInfo(entry.itemID))
                    end
                end
                if link then
                    ChatEdit_InsertLink(link)
                end
                return
            end

            state.selected = entry.name
            self:UpdateListHighlights()
            self:RefreshDetailPanel()
            self:UpdateCraftBar()
        end)

        row:SetScript("OnEnter", function()
            local dataIdx = i + state.scrollOffset
            local entry = state.recipes[dataIdx]
            if entry and not entry.isHeader then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                -- v6: tooltip for ALL recipes, not just known
                if entry.itemLink then
                    GameTooltip:SetHyperlink(entry.itemLink)
                elseif entry.itemID and entry.itemID ~= 0 then
                    GameTooltip:SetItemByID(entry.itemID)
                else
                    -- Item-less recipe (e.g. an enchant): itemID is 0 and
                    -- there's no link, so SetItemByID(0) would render a
                    -- broken tooltip. Show recipe info instead.
                    self:BuildRecipeTooltip(GameTooltip, entry)
                end
                GameTooltip:Show()
                if IsShiftKeyDown() and GameTooltip_ShowCompareItem then
                    GameTooltip_ShowCompareItem()
                end
                row._hoveredEntry = entry
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
            if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
            row._hoveredEntry = nil
        end)

        self.listRows[i] = row
    end

    -- Custom scroll slider
    local scrollBar = CreateFrame("Slider", nil, listPanel)
    scrollBar:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -3, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -3, 4)
    scrollBar:SetWidth(12)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)
    scrollBar:SetObeyStepOnDrag(true)

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 24)
    thumb:SetColorTexture(0.4, 0.4, 0.5, 0.8)
    scrollBar:SetThumbTexture(thumb)

    local trackBg = scrollBar:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.08, 0.08, 0.1, 0.6)

    scrollBar:SetValue(0)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        state.scrollOffset = math.floor(value)
        TSF:UpdateListRows()
    end)

    listPanel:SetScript("OnMouseWheel", function(_, delta)
        local cur = scrollBar:GetValue()
        scrollBar:SetValue(cur - delta * 3)
    end)

    self.listPanel = listPanel
    self.scrollBar = scrollBar
end

function TSF:UpdateListRows()
    local recipes = state.recipes
    local offset = state.scrollOffset

    for i = 1, VISIBLE_ROWS do
        local row = self.listRows[i]
        local dataIdx = i + offset
        local entry = recipes[dataIdx]

        row.selectedBg:Hide()
        row.headerBg:Hide()

        if entry then
            row:Show()

            if entry.isHeader then
                row.icon:Hide()
                local arrow = entry.isCollapsed and "|cffcccccc+ |r" or "|cffcccccc- |r"
                local indent = 4
                if entry.headerType == "subcategory" then
                    indent = 18
                    row.nameText:SetTextColor(0.8, 0.7, 0.4)
                else
                    row.nameText:SetTextColor(DIFF_COLORS.header.r, DIFF_COLORS.header.g, DIFF_COLORS.header.b)
                end
                row.nameText:SetText(arrow .. entry.name)
                row.nameText:SetPoint("LEFT", indent, 0)
                row.rightText:SetText("|cff888888(" .. entry.count .. ")|r")
                row.headerBg:Show()
            else
                -- Indent recipes under subcategories (only in Category sort)
                local recipeIndent = (state.sortBy == "Category" and entry.subcategory) and 14 or 0

                if entry.icon then
                    row.icon:SetTexture(entry.icon)
                    row.icon:SetPoint("LEFT", 2 + recipeIndent, 0)
                    row.icon:Show()
                    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
                else
                    row.icon:Hide()
                    row.nameText:SetPoint("LEFT", 4 + recipeIndent, 0)
                end

                local dc = DiffColor(entry.difficulty)
                row.nameText:SetText(entry.name)
                row.nameText:SetTextColor(dc.r, dc.g, dc.b)

                if entry.isKnown then
                    local avail = entry.numAvail or 0
                    -- Enchants (itemID 0) report no numAvail, so the list
                    -- count falls back to reagents in bags -- same as the
                    -- detail panel + craft bar. Own character only
                    -- (ReagentCraftCount reads your own bags).
                    if avail == 0 and not state._viewCharKey
                       and (not entry.itemID or entry.itemID == 0) then
                        avail = self:ReagentCraftCount(entry)
                    end
                    local rangeStr = ""
                    local sr = GetSkillRange(entry)

                    if RANGE_NUMBERS_HIDDEN[state.profName] then
                        -- Range numbers known-unreliable for this profession
                        -- (smelting); suppress until the 1.0.1 game-sourced
                        -- rework. Name color (from the game) still shows.
                        rangeStr = ""
                    elseif state.sortBy == "Skill Ups" and sr then
                        -- Show tier threshold: "310 to yellow" with colors
                        local threshold, targetName, targetHex
                        if entry.difficulty == "optimal" then
                            threshold = sr[2]
                            targetName = "yellow"
                            targetHex = DIFF_COLORS.medium.hex
                        elseif entry.difficulty == "medium" then
                            threshold = sr[3]
                            targetName = "green"
                            targetHex = DIFF_COLORS.easy.hex
                        elseif entry.difficulty == "easy" then
                            threshold = sr[4]
                            targetName = "grey"
                            targetHex = DIFF_COLORS.trivial.hex
                        end
                        if threshold then
                            rangeStr = dc.hex .. threshold .. "|r " .. targetHex .. "to " .. targetName .. "|r "
                        end
                    elseif sr then
                        rangeStr = "|cff888888" .. SkillRangeCompact(sr) .. "|r "
                    end

                    if avail > 0 then
                        row.rightText:SetText(rangeStr .. "|cff00ff00[" .. avail .. "]|r")
                    else
                        row.rightText:SetText(rangeStr)
                    end
                else
                    local src = entry.source or ""
                    local c = SOURCE_COLORS[src] or "|cff888888"
                    local displaySrc = src:sub(1,1):upper() .. src:sub(2)
                    local skillText = ""
                    local entryReq = GetSkillReq(entry)
                    if entryReq then
                        if (state.skillLevel or 0) >= entryReq then
                            skillText = " |cff00ff00[" .. entryReq .. "]|r"
                        else
                            skillText = " |cffff4444[" .. entryReq .. "]|r"
                        end
                    end
                    row.rightText:SetText(c .. displaySrc .. "|r" .. skillText)
                end

                if entry.name == state.selected then
                    row.selectedBg:Show()
                end
            end
        else
            row:Hide()
        end
    end
end

function TSF:UpdateListHighlights()
    for i = 1, VISIBLE_ROWS do
        local row = self.listRows[i]
        local dataIdx = i + state.scrollOffset
        local entry = state.recipes[dataIdx]
        if entry and not entry.isHeader and entry.name == state.selected then
            row.selectedBg:Show()
        else
            row.selectedBg:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Update craftable counts mid-batch (lightweight, no full rebuild)
----------------------------------------------------------------------
function TSF:UpdateCraftableCounts()
    if not state.recipes then return end

    -- GetCraftInfo (Enchanting) doesn't return numAvail, so only
    -- update for tradeskill professions where the API provides it
    if state.isCraftWindow then
        self:UpdateListRows()
        return
    end

    for _, entry in ipairs(state.recipes) do
        if entry.isKnown and entry.gameIndex then
            local _, skillType, numAvail = GetTradeSkillInfo(entry.gameIndex)
            entry.numAvail = numAvail or 0
            if skillType and skillType ~= "header" and skillType ~= "subheader" then
                entry.difficulty = skillType
            end

            -- Also update allRecipes so detail panel stays consistent
            if state.allRecipes[entry.name] then
                state.allRecipes[entry.name].numAvail = numAvail or 0
                if skillType and skillType ~= "header" and skillType ~= "subheader" then
                    state.allRecipes[entry.name].difficulty = skillType
                end
            end
        end
    end

    self:UpdateListRows()

    if state.selected then
        self:UpdateCraftBar()
        -- Refresh the detail panel reagent counts + "Can make" text.
        -- BAG_UPDATE fires during crafting so DataStore inventory is
        -- already current by the time TRADE_SKILL_UPDATE reaches us.
        self:RefreshDetailPanel(true)
    end

    -- Refresh material calculator if it's open
    if self.calcPanel and self.calcPanel:IsShown() then
        self:RefreshCalcPanel()
    end
end

----------------------------------------------------------------------
-- Detail panel (right side)
----------------------------------------------------------------------
function TSF:BuildDetailPanel(parent)
    local topOffset = -106

    local detail = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_W + 18, topOffset)
    detail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 30 + CRAFT_BAR_H + 4)
    detail:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    detail:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    detail:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.8)

    local placeholder = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("CENTER")
    placeholder:SetText("Select a recipe")
    placeholder:SetTextColor(0.4, 0.4, 0.4)
    self.detPlaceholder = placeholder

    -- ScrollFrame: wraps all detail content so it scrolls when
    -- the embedded tooltip + reagents exceed available height
    local scrollFrame = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(DETAIL_W - 40)
    scrollFrame:SetScrollChild(scrollChild)
    self.detScrollFrame = scrollFrame
    self.detScrollChild = scrollChild

    -- Enable mouse-wheel scrolling on the detail panel itself
    detail:EnableMouseWheel(true)
    detail:SetScript("OnMouseWheel", function(_, delta)
        local current = scrollFrame:GetVerticalScroll()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local step = 30
        local newVal = math.max(0, math.min(maxScroll, current - (delta * step)))
        scrollFrame:SetVerticalScroll(newVal)
    end)

    -- All content below is parented to scrollChild
    local sc = scrollChild

    local detIcon = sc:CreateTexture(nil, "ARTWORK")
    detIcon:SetSize(32, 32)
    detIcon:SetPoint("TOPLEFT", 6, -6)
    detIcon:Hide()
    self.detIcon = detIcon

    local detName = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detName:SetPoint("LEFT", detIcon, "RIGHT", 6, 0)
    detName:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
    detName:SetJustifyH("LEFT")
    self.detName = detName

    local nameDivider = sc:CreateTexture(nil, "ARTWORK")
    nameDivider:SetSize(DETAIL_W - 40, 1)
    nameDivider:SetPoint("TOPLEFT", detIcon, "BOTTOMLEFT", 0, -4)
    nameDivider:SetColorTexture(0.3, 0.3, 0.35, 0.6)
    self.nameDivider = nameDivider

    local detDiff = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detDiff:SetPoint("TOPLEFT", nameDivider, "BOTTOMLEFT", 0, -6)
    self.detDiff = detDiff

    local detRange = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detRange:SetPoint("TOPLEFT", detDiff, "BOTTOMLEFT", 0, -2)
    detRange:SetWidth(DETAIL_W - 40)
    detRange:SetJustifyH("LEFT")
    self.detRange = detRange

    local detSkill = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detSkill:SetPoint("TOPLEFT", detRange, "BOTTOMLEFT", 0, -2)
    self.detSkill = detSkill

    local detCat = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detCat:SetPoint("TOPLEFT", detSkill, "BOTTOMLEFT", 0, -2)
    self.detCat = detCat

    local detSource = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detSource:SetPoint("TOPLEFT", detCat, "BOTTOMLEFT", 0, -2)
    self.detSource = detSource

    local detCanMake = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detCanMake:SetPoint("TOPLEFT", detSource, "BOTTOMLEFT", 0, -8)
    self.detCanMake = detCanMake

    -- v6: Embedded item tooltip (shows item stats/effects)
    local itemTooltipHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemTooltipHeader:SetText("Item Info")
    itemTooltipHeader:SetTextColor(1, 0.82, 0)
    self.itemTooltipHeader = itemTooltipHeader

    local itemTooltipDivider = sc:CreateTexture(nil, "ARTWORK")
    itemTooltipDivider:SetSize(DETAIL_W - 40, 1)
    itemTooltipDivider:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    self.itemTooltipDivider = itemTooltipDivider

    -- We use a real GameTooltip-style frame embedded in the panel
    -- GameTooltipTemplate sets strata to TOOLTIP; override to HIGH so the
    -- transient hover GameTooltip (TOOLTIP strata) always renders on top.
    local embeddedTip = CreateFrame("GameTooltip", "ProfBuddyDetailTooltip", sc, "GameTooltipTemplate")
    embeddedTip:SetFrameStrata("HIGH")
    embeddedTip:SetOwner(sc, "ANCHOR_NONE")
    embeddedTip:SetPoint("TOPLEFT", 0, 0)
    embeddedTip:SetScale(0.9)
    embeddedTip:Hide()
    self.embeddedTip = embeddedTip

    -- Reagents
    local reagentDivider = sc:CreateTexture(nil, "ARTWORK")
    reagentDivider:SetSize(DETAIL_W - 40, 1)
    reagentDivider:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    self.reagentDivider = reagentDivider

    local reagentHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reagentHeader:SetText("Reagents")
    reagentHeader:SetTextColor(1, 0.82, 0)
    self.reagentHeader = reagentHeader

    local REAGENT_COL_W = math.floor((DETAIL_W - 44) / 2)

    self.reagentRows = {}
    for i = 1, 14 do
        local rFrame = CreateFrame("Frame", nil, sc)
        rFrame:SetSize(REAGENT_COL_W, 22)

        local rIcon = rFrame:CreateTexture(nil, "ARTWORK")
        rIcon:SetSize(18, 18)
        rIcon:SetPoint("LEFT", 0, 0)
        rFrame.icon = rIcon

        local rName = rFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rName:SetPoint("LEFT", rIcon, "RIGHT", 4, 0)
        rName:SetPoint("RIGHT", rFrame, "RIGHT", -36, 0)
        rName:SetWordWrap(false)
        rFrame.nameText = rName

        local rCount = rFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rCount:SetPoint("RIGHT", -4, 0)
        rFrame.countText = rCount

        rFrame:EnableMouse(true)
        rFrame:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                if self.inBags ~= nil then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine("In bags:", tostring(self.inBags),
                        0.8, 0.8, 0.8, 1, 1, 1)
                    GameTooltip:AddDoubleLine("In bank:", tostring(self.inBank or 0),
                        0.8, 0.8, 0.8, 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
        rFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rFrame:Hide()
        self.reagentRows[i] = rFrame
    end
    self._reagentColW = REAGENT_COL_W

    -- Alt materials
    local altDivider = sc:CreateTexture(nil, "ARTWORK")
    altDivider:SetSize(DETAIL_W - 40, 1)
    altDivider:SetColorTexture(0.3, 0.3, 0.35, 0.4)
    self.altDivider = altDivider

    local altHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    altHeader:SetText("Held by:")
    altHeader:SetTextColor(1, 0.82, 0)
    self.altHeader = altHeader

    self.altLines = {}
    for i = 1, 14 do
        local line = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:Hide()
        self.altLines[i] = line
    end

    self.detailFrame = detail
end

function TSF:UpdateScrollChildHeight()
    -- Calculate total content height and set the scroll child
    local sc = self.detScrollChild
    if not sc then return end

    -- Find the bottommost visible element
    local bottom = 0
    local function checkRegion(region)
        if region and region.IsShown and region:IsShown() and region.GetBottom and region:GetBottom() then
            local scTop = sc:GetTop()
            if scTop then
                local used = scTop - region:GetBottom()
                if used > bottom then bottom = used end
            end
        end
    end

    -- Check all known content elements
    checkRegion(self.detIcon)
    checkRegion(self.nameDivider)
    checkRegion(self.detCanMake)
    checkRegion(self.embeddedTip)
    checkRegion(self.reagentDivider)
    checkRegion(self.reagentHeader)
    for _, row in ipairs(self.reagentRows) do checkRegion(row) end
    checkRegion(self.altDivider)
    checkRegion(self.altHeader)
    for _, line in ipairs(self.altLines) do checkRegion(line) end

    -- Add padding at the bottom
    sc:SetHeight(math.max(bottom + 16, 1))
end

function TSF:ClearDetailPanel(preserveScroll)
    -- Don't hide the calc panel here -- RefreshDetailPanel will
    -- re-populate it if it's open. Track the intent instead.
    self._calcWasOpen = self.calcPanel and self.calcPanel:IsShown()
    if self.detScrollFrame then
        if preserveScroll then
            self._savedDetailScroll = self.detScrollFrame:GetVerticalScroll()
        else
            self._savedDetailScroll = nil
            self.detScrollFrame:SetVerticalScroll(0)
        end
    end
    self.detPlaceholder:Show()
    if self.detScrollFrame then self.detScrollFrame:Hide() end
    self.detIcon:Hide()
    self.detName:SetText("")
    self.detDiff:SetText("")
    self.detRange:SetText("")
    self.detSkill:SetText("")
    self.detCat:SetText("")
    self.detSource:SetText("")
    self.detCanMake:SetText("")
    self.nameDivider:Hide()
    self.itemTooltipHeader:Hide()
    self.itemTooltipDivider:Hide()
    self.embeddedTip:Hide()
    self.reagentDivider:Hide()
    self.reagentHeader:Hide()
    self.altDivider:Hide()
    self.altHeader:Hide()
    for _, row in ipairs(self.reagentRows) do row:Hide() end
    for _, line in ipairs(self.altLines) do line:Hide() end
end

function TSF:RefreshDetailPanel(preserveScroll)
    self:ClearDetailPanel(preserveScroll)
    if not state.selected then return end

    local recipe = nil
    for _, r in ipairs(state.recipes) do
        if not r.isHeader and r.name == state.selected then
            recipe = r
            break
        end
    end
    if not recipe then return end

    self.detPlaceholder:Hide()
    if self.detScrollFrame then self.detScrollFrame:Show() end
    self.nameDivider:Show()

    -- Item icon in detail header
    local iconTex = recipe.icon
    if not iconTex and recipe.itemID then
        iconTex = select(10, GetItemInfo(recipe.itemID))
    end
    if iconTex then
        self.detIcon:SetTexture(iconTex)
        self.detIcon:Show()
    else
        self.detIcon:Hide()
    end

    local dc = DiffColor(recipe.difficulty)
    self.detName:SetText(recipe.name)
    self.detName:SetTextColor(dc.r, dc.g, dc.b)

    local diffLabels = {
        optimal = "Orange - will level up",
        medium  = "Yellow - may level up",
        easy    = "Green - unlikely to level",
        trivial = "Grey - no skill gain",
    }
    self.detDiff:SetText("Difficulty: " .. (diffLabels[recipe.difficulty] or recipe.difficulty or "unknown"))
    self.detDiff:SetTextColor(dc.r, dc.g, dc.b)

    local sr = GetSkillRange(recipe)
    if sr and RANGE_NUMBERS_HIDDEN[state.profName] then
        -- Static range numbers known-unreliable for this profession
        -- (smelting) -- hide them rather than show wrong info. The
        -- game-sourced "Difficulty:" label above still shows the real tier.
        self.detRange:SetText("")
    elseif sr then
        if recipe.isKnown then
            -- Known: bracket the tier the game reports (recipe.difficulty)
            -- so the detail panel can't disagree with the recipe list,
            -- even when the static range numbers are off (e.g. smelting).
            self.detRange:SetText(SkillRangeDetailed(sr, state.skillLevel, recipe.difficulty))
        else
            -- Unlearned: difficulty is meaningless (can't craft it yet) and
            -- there's no unlearned tier in this display, so show the range
            -- with NO highlight (nil skill + nil tier brackets nothing).
            self.detRange:SetText(SkillRangeDetailed(sr, nil, nil))
        end
    else
        self.detRange:SetText("")
    end

    local sReq = GetSkillReq(recipe)
    if sReq then
        local canLearn = (state.skillLevel or 0) >= sReq
        if canLearn then
            self.detSkill:SetText("|cff00ff00Requires: " .. sReq .. " (learnable)|r")
        else
            self.detSkill:SetText("|cffff4444Requires: " .. sReq .. " (need " .. (sReq - state.skillLevel) .. " more)|r")
        end
    else
        self.detSkill:SetText("")
    end

    if recipe.category then
        self.detCat:SetText("|cff888888Category: " .. recipe.category .. "|r")
    else
        self.detCat:SetText("")
    end

    if recipe.source then
        local src = recipe.source
        local displaySrc = src:sub(1,1):upper() .. src:sub(2)
        local detail = recipe.sourceDetail
        if detail and src == "quest" then
            detail = detail:gsub("^Quest:%s*", "")
        end
        local srcText = "Source: " .. displaySrc
        if detail then
            srcText = srcText .. " - " .. detail
        end
        self.detSource:SetText((SOURCE_COLORS[src] or "") .. srcText .. "|r")
    else
        self.detSource:SetText("")
    end

    if recipe.isKnown and recipe.numAvail ~= nil then
        local avail = recipe.numAvail
        -- Enchants produce no item, so the game reports 0 available even
        -- when you have the mats. For your own known item-less recipe,
        -- count reagents directly (same fallback the craft bar uses).
        -- Skipped when viewing another character: ReagentCraftCount reads
        -- GetItemCount from YOUR bags, not theirs.
        if avail == 0 and not state._viewCharKey
           and (not recipe.itemID or recipe.itemID == 0) then
            avail = self:ReagentCraftCount(recipe)
        end
        if avail > 0 then
            self.detCanMake:SetText("|cff00ff00Can make: " .. avail .. "|r")
        else
            self.detCanMake:SetText("|cffff4444Can make: 0 (missing reagents)|r")
        end
    end

    -- v6: Show embedded item tooltip
    self:ShowEmbeddedTooltip(recipe)

    local reagents = recipe.reagents
    if reagents and #reagents > 0 then
        -- Position reagents below the embedded tooltip or below detCanMake
        local reagentAnchor = self.detCanMake
        if self.embeddedTip:IsShown() then
            reagentAnchor = self.embeddedTip
        end

        self.reagentDivider:SetPoint("TOPLEFT", reagentAnchor, "BOTTOMLEFT", 0, -8)
        self.reagentDivider:Show()
        self.reagentHeader:SetPoint("TOPLEFT", self.reagentDivider, "BOTTOMLEFT", 0, -4)
        self.reagentHeader:Show()

        local viewChar = state._viewCharKey or addon:PlayerKey()
        local charData = DS:GetCharacter(viewChar)
        local bags = charData and charData.inventory and charData.inventory.bags or {}
        local bank = charData and charData.inventory and charData.inventory.bank or {}

        local numReagents = #reagents
        local useTwoCol = numReagents >= 4
        local colW = self._reagentColW
        local perCol = useTwoCol and math.ceil(numReagents / 2) or numReagents

        for i, reagent in ipairs(reagents) do
            if i > 14 then break end
            local row = self.reagentRows[i]
            row:Show()

            -- Size: full width for single column, half for two columns
            if useTwoCol then
                row:SetWidth(colW)
            else
                row:SetWidth(colW * 2)
            end

            -- Position: two-column grid layout
            row:ClearAllPoints()
            if useTwoCol then
                local col = (i <= perCol) and 0 or 1
                local rowInCol = (i <= perCol) and (i - 1) or (i - perCol - 1)
                if rowInCol == 0 and col == 0 then
                    row:SetPoint("TOPLEFT", self.reagentHeader, "BOTTOMLEFT", 4, -4)
                elseif col == 0 then
                    row:SetPoint("TOPLEFT", self.reagentRows[i-1], "BOTTOMLEFT", 0, -2)
                elseif rowInCol == 0 then
                    row:SetPoint("TOPLEFT", self.reagentHeader, "BOTTOMLEFT", 4 + colW, -4)
                else
                    row:SetPoint("TOPLEFT", self.reagentRows[i-1], "BOTTOMLEFT", 0, -2)
                end
            else
                if i == 1 then
                    row:SetPoint("TOPLEFT", self.reagentHeader, "BOTTOMLEFT", 4, -4)
                else
                    row:SetPoint("TOPLEFT", self.reagentRows[i-1], "BOTTOMLEFT", 0, -2)
                end
            end

            if reagent.icon then
                row.icon:SetTexture(reagent.icon)
                row.icon:Show()
            elseif reagent.itemID then
                local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(reagent.itemID)
                if tex then row.icon:SetTexture(tex); row.icon:Show()
                else row.icon:Hide() end
            else
                row.icon:Hide()
            end

            row.itemID = reagent.itemID
            local need = reagent.count or 1
            local inBags, inBank = 0, 0
            if reagent.itemID then
                inBags = bags[reagent.itemID] or 0
                inBank = bank[reagent.itemID] or 0
            end
            local total = inBags + inBank
            -- stash for the row hover tooltip (exact bag/bank split)
            row.inBags, row.inBank = inBags, inBank

            row.nameText:SetText((reagent.name or "???") .. " x" .. need)

            -- Color by BAG availability -- you craft from bags, not the
            -- bank. Azure means you own enough total but some/all sits in
            -- the bank, so a green reagent list never contradicts a
            -- bags-only "Can make". Compact text (bags/need) keeps it
            -- inside the 2-column reagent layout. Exact split is on hover.
            if inBags >= need then
                row.countText:SetText("|cff00ff00" .. inBags .. "|r")
            elseif total >= need then
                row.countText:SetText("|cff3fc7ff" .. inBags .. "/" .. need .. "|r")
            elseif total > 0 then
                row.countText:SetText("|cffffff00" .. total .. "/" .. need .. "|r")
            else
                row.countText:SetText("|cffff4444" .. total .. "/" .. need .. "|r")
            end
        end

        self:ShowAltMaterials(recipe)
    end

    -- If the calc window was open before ClearDetailPanel, refresh and reshow
    if self._calcWasOpen then
        self:RefreshCalcPanel()
        self.calcPanel:Show()
        self._calcWasOpen = false
    end

    -- Update scroll child height after a brief delay to let
    -- all elements (especially the embedded tooltip) settle
    C_Timer.After(0.05, function()
        self:UpdateScrollChildHeight()
        -- Restore scroll position if we were preserving it
        if self._savedDetailScroll and self.detScrollFrame then
            local maxScroll = self.detScrollFrame:GetVerticalScrollRange()
            local restore = math.min(self._savedDetailScroll, maxScroll)
            self.detScrollFrame:SetVerticalScroll(restore)
            self._savedDetailScroll = nil
        end
    end)
end

function TSF:ShowEmbeddedTooltip(recipe)
    local tip = self.embeddedTip
    tip:Hide()
    self.itemTooltipHeader:Hide()
    self.itemTooltipDivider:Hide()

    local itemID = recipe.itemID
    -- Skip only when there's truly nothing to embed: no usable link AND no
    -- real item. An item-less recipe WITH a scanned link (alts) still shows
    -- its real tooltip; a friend's enchant (no link, itemID 0) is skipped
    -- since its reagents / skill / source already show elsewhere.
    if not recipe.itemLink and (not itemID or itemID == 0) then return end

    -- Position below detCanMake
    self.itemTooltipDivider:SetPoint("TOPLEFT", self.detCanMake, "BOTTOMLEFT", 0, -6)
    self.itemTooltipDivider:Show()
    self.itemTooltipHeader:SetPoint("TOPLEFT", self.itemTooltipDivider, "BOTTOMLEFT", 0, -4)
    self.itemTooltipHeader:Show()

    tip:SetOwner(self.detailFrame, "ANCHOR_NONE")
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", self.itemTooltipHeader, "BOTTOMLEFT", 0, -4)

    if recipe.itemLink then
        tip:SetHyperlink(recipe.itemLink)
    else
        tip:SetItemByID(itemID)
    end
    tip:Show()
end

-- Build a hover tooltip for recipes that produce no item (enchants).
-- The in-game item tooltip would be empty/broken (itemID 0), so show the
-- recipe's own info: name, skill-up thresholds, and reagents.
function TSF:BuildRecipeTooltip(tip, entry)
    tip:ClearLines()
    tip:AddLine(entry.name or "Recipe", 1, 1, 1)

    local sr = entry.skillRange
    if type(sr) == "table" and sr[1] then
        tip:AddDoubleLine("Skill ups:",
            string.format("|cffff8040%d|r |cffffff00%d|r |cff40c040%d|r |cff909090%d|r",
                sr[1] or 0, sr[2] or 0, sr[3] or 0, sr[4] or 0),
            0.8, 0.8, 0.8)
    end

    if entry.reagents and #entry.reagents > 0 then
        tip:AddLine(" ")
        tip:AddLine("Reagents:", 0.82, 0.82, 0.6)
        for _, r in ipairs(entry.reagents) do
            local nm = r.name or (r.itemID and ("Item " .. r.itemID)) or "?"
            tip:AddLine("  " .. (r.count or 1) .. "x " .. nm, 0.9, 0.9, 0.9)
        end
    end
end

function TSF:ShowAltMaterials(recipe)
    -- Alt and friend visibility are independent toggles; if neither is on
    -- nothing is collected below and the section stays hidden.
    if not recipe.reagents or not DS then return end

    local currentKey = state._viewCharKey or addon:PlayerKey()
    local currentChar = DS:GetCharacter(currentKey)
    local currentFaction = currentChar and currentChar.faction
    local allChars = DS:GetAllCharacters()

    local showCrossFaction = addon.db.settings.showCrossFactionAlts
    local showRemoteInDetail = addon.db.settings.showRemoteInDetail
    local showAltInDetail = addon.db.settings.showAltInDetail

    -- Collect into alts (local) and friends (remote); tag opposing faction.
    -- Each type is gated by its own toggle, independently.
    local alts, friends = {}, {}
    for charKey, charData in pairs(allChars) do
        local typeEnabled = (charData.isRemote and showRemoteInDetail)
                         or (not charData.isRemote and showAltInDetail)
        if charKey ~= currentKey
           and typeEnabled
           and (showCrossFaction or charData.faction == currentFaction) then
            local bags = charData.inventory and charData.inventory.bags or {}
            local bankItems = charData.inventory and charData.inventory.bank or {}
            local parts = {}

            for _, reagent in ipairs(recipe.reagents) do
                if reagent.itemID then
                    local count = (bags[reagent.itemID] or 0) + (bankItems[reagent.itemID] or 0)
                    if count > 0 then
                        table.insert(parts, (reagent.name or "?") .. ":" .. count)
                    end
                end
            end

            if #parts > 0 then
                local entry = {
                    short    = charKey:match("^([^-]+)") or charKey,
                    class    = charData.class,
                    faction  = charData.faction,
                    opposing = (charData.faction ~= currentFaction),
                    summary  = table.concat(parts, ", "),
                }
                if charData.isRemote then
                    table.insert(friends, entry)
                else
                    table.insert(alts, entry)
                end
            end
        end
    end

    if #alts == 0 and #friends == 0 then return end

    -- Sort each group: current faction first, then opposing; alpha within
    local function sortGroup(t)
        table.sort(t, function(a, b)
            if a.opposing ~= b.opposing then return not a.opposing end
            return a.short < b.short
        end)
    end
    sortGroup(alts)
    sortGroup(friends)

    -- Anchor the divider/header below the last visible reagent row
    local numReagents = recipe.reagents and #recipe.reagents or 0
    local perCol = (numReagents >= 5) and math.ceil(numReagents / 2) or numReagents
    local lastReagent = self.reagentRows[1]
    for i = 1, math.min(perCol, 14) do
        if self.reagentRows[i]:IsShown() then lastReagent = self.reagentRows[i] end
    end

    self.altDivider:ClearAllPoints()
    self.altDivider:SetPoint("TOPLEFT", lastReagent, "BOTTOMLEFT", -4, -8)
    self.altDivider:Show()
    self.altHeader:SetPoint("TOPLEFT", self.altDivider, "BOTTOMLEFT", 0, -4)
    self.altHeader:Show()

    -- Render groups (each line anchored to the header at a computed row)
    local LH = 14
    local idx = 0
    local function emit(text, indentX)
        idx = idx + 1
        if idx > #self.altLines then return false end
        local line = self.altLines[idx]
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self.altHeader, "BOTTOMLEFT", 4 + (indentX or 0), -4 - (idx - 1) * LH)
        line:SetText(text)
        line:Show()
        return true
    end

    local function emitGroup(label, labelHex, list)
        if #list == 0 then return end
        if not emit("|cff" .. labelHex .. label .. "|r", 0) then return end
        for _, e in ipairs(list) do
            local cc = addon:ClassColor(e.class or "WARRIOR")
            local tag = ""
            if e.opposing then
                tag = (e.faction == "Alliance") and "|cff4080ff[A]|r " or "|cffff4040[H]|r "
            end
            if not emit(tag .. cc .. e.short .. "|r  " .. e.summary, 10) then break end
        end
    end

    emitGroup("Alts", "ffd820", alts)
    emitGroup("Friends", "80c0ff", friends)
end

----------------------------------------------------------------------
-- Material Calculator window (standalone draggable frame)
----------------------------------------------------------------------
local CALC_W = 280
local CALC_H = FRAME_H

function TSF:BuildCalcPanel()
    local calc = CreateFrame("Frame", "ProfBuddyCalcWindow", UIParent, "BasicFrameTemplateWithInset")
    calc:SetSize(CALC_W, CALC_H)
    -- Fastened to the right edge of the profession window. Not
    -- independently movable, so it can't be dragged loose; re-anchored
    -- on every show as insurance against a stale point.
    calc:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 4, 0)
    calc:EnableMouse(true)
    calc:SetClampedToScreen(true)
    calc:SetFrameStrata("HIGH")
    calc:Hide()
    calc:SetScript("OnShow", function(s)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", self.frame, "TOPRIGHT", 4, 0)
    end)
    calc:SetScript("OnHide", function()
        self:UpdateCalcBtnState()
    end)

    calc.TitleText:SetText("Material Calculator")

    -- Header (recipe name + qty)
    local header = calc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", calc.InsetBorderTop or calc, "TOPLEFT", 10, -30)
    header:SetPoint("RIGHT", calc, "RIGHT", -10, 0)
    header:SetJustifyH("LEFT")
    header:SetTextColor(1, 0.82, 0)
    self.calcHeader = header

    -- Divider below header
    local divider = calc:CreateTexture(nil, "ARTWORK")
    divider:SetSize(CALC_W - 30, 1)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    divider:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    -- Summary line
    local summary = calc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
    summary:SetWidth(CALC_W - 30)
    summary:SetJustifyH("LEFT")
    self.calcSummary = summary

    -- Column headers
    local colHeaders = CreateFrame("Frame", nil, calc)
    colHeaders:SetSize(CALC_W - 30, 14)
    colHeaders:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -8)

    local colName = colHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colName:SetPoint("LEFT", 20, 0)
    colName:SetText("|cff888888Material|r")
    colName:SetJustifyH("LEFT")

    local colNeed = colHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colNeed:SetPoint("RIGHT", colHeaders, "RIGHT", -64, 0)
    colNeed:SetText("|cff888888Need|r")
    colNeed:SetJustifyH("RIGHT")

    local colHave = colHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colHave:SetPoint("RIGHT", colHeaders, "RIGHT", -30, 0)
    colHave:SetText("|cff888888Have|r")
    colHave:SetJustifyH("RIGHT")

    local colShort = colHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colShort:SetPoint("RIGHT", colHeaders, "RIGHT", -2, 0)
    colShort:SetText("|cff888888Left|r")
    colShort:SetJustifyH("RIGHT")

    -- Column header divider
    local colDiv = calc:CreateTexture(nil, "ARTWORK")
    colDiv:SetSize(CALC_W - 30, 1)
    colDiv:SetPoint("TOPLEFT", colHeaders, "BOTTOMLEFT", 0, -2)
    colDiv:SetColorTexture(0.25, 0.25, 0.3, 0.5)

    -- Scroll frame for material rows
    local scrollParent = CreateFrame("Frame", nil, calc)
    scrollParent:SetPoint("TOPLEFT", colDiv, "BOTTOMLEFT", 0, -2)
    scrollParent:SetPoint("BOTTOMRIGHT", calc, "BOTTOMRIGHT", -12, 8)
    scrollParent:SetClipsChildren(true)

    -- Material rows
    local CALC_ROW_H = 20
    local MAX_CALC_ROWS = 23
    self.calcRows = {}
    self.calcScrollOffset = 0
    local rowW = CALC_W - 36

    for i = 1, MAX_CALC_ROWS do
        local row = CreateFrame("Frame", nil, scrollParent)
        row:SetSize(rowW, CALC_ROW_H)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * CALC_ROW_H))

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 2, 0)
        row.icon = icon

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -100, 0)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local needText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        needText:SetPoint("RIGHT", row, "RIGHT", -64, 0)
        needText:SetJustifyH("RIGHT")
        needText:SetWidth(32)
        row.needText = needText

        local haveText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        haveText:SetPoint("RIGHT", row, "RIGHT", -30, 0)
        haveText:SetJustifyH("RIGHT")
        haveText:SetWidth(30)
        row.haveText = haveText

        local shortText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        shortText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        shortText:SetJustifyH("RIGHT")
        shortText:SetWidth(26)
        row.shortText = shortText

        -- Section divider line (shown only for section headers)
        local divLine = row:CreateTexture(nil, "ARTWORK")
        divLine:SetSize(CALC_W - 36, 1)
        divLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
        divLine:SetColorTexture(0.4, 0.38, 0.3, 0.6)
        divLine:Hide()
        row.sectionDivider = divLine

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(r)
            if r.itemID then
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(r.itemID)
                -- Append per-alt inventory breakdown
                local showAlt = addon.db.settings.showAltInDetail
                local showRemote = addon.db.settings.showRemoteInDetail
                if (showAlt or showRemote) and DS then
                    local owners = DS:WhoHasItem(r.itemID)
                    if next(owners) then
                        local ck = addon:PlayerKey()
                        local cd = DS:GetCharacter(ck)
                        local currentFaction = cd and cd.faction
                        local showCross = addon.db.settings.showCrossFactionAlts
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Held by:", 1, 0.82, 0)
                        for charKey, count in pairs(owners) do
                            local charData = DS:GetCharacter(charKey)
                            local isCurrent = (charKey == ck)
                            -- Alt and friend inclusion are independent; you always count.
                            local typeOK = isCurrent
                                or (charData and charData.isRemote and showRemote)
                                or (charData and not charData.isRemote and showAlt)
                            if charData and typeOK
                               and (isCurrent or showCross or charData.faction == currentFaction) then
                                local cc = addon:ClassColor(charData.class or "WARRIOR")
                                local charName = charKey:match("^(.+)-")
                                GameTooltip:AddDoubleLine(
                                    cc .. (charName or charKey) .. "|r",
                                    tostring(count),
                                    nil, nil, nil, 1, 1, 1)
                            end
                        end
                    end
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Hide()
        self.calcRows[i] = row
    end

    -- Scroll with mouse wheel
    scrollParent:EnableMouseWheel(true)
    scrollParent:SetScript("OnMouseWheel", function(_, delta)
        self.calcScrollOffset = math.max(0, self.calcScrollOffset - delta * 3)
        self:UpdateCalcRows()
    end)

    self.calcPanel = calc
    self.calcData = {}
end

-- Populate (or refresh) the calc window for the currently selected recipe.
-- Does NOT toggle visibility -- call this when the window is already open
-- and the recipe changes.
function TSF:RefreshCalcPanel()
    if not self.calcPanel then return end

    local recipe = self:GetSelectedRecipe()
    if not recipe then
        -- Nothing selected -- clear and hide
        self.calcPanel:Hide()
        return
    end

    local MC = addon.MaterialCalc
    if not MC then return end

    local qty = tonumber(self.qtyBox:GetText()) or 1
    if qty < 1 then qty = 1 end

    local shoppingList, tree = MC:GetShoppingList(recipe.name, state.profName, qty)

    -- Build display data: tree view + shopping list
    local displayData = {}

    -- Section: Reagent Tree
    if #tree > 0 then
        table.insert(displayData, {
            isSection = true,
            text = "Reagent Breakdown",
        })

        local globalItems = DS:GetCalcItemCounts()
        for _, entry in ipairs(tree) do
            local have = entry.itemID and (globalItems[entry.itemID] or 0) or 0
            local shortfall = math.max(0, entry.need - have)
            table.insert(displayData, {
                itemID = entry.itemID,
                name = entry.name,
                need = entry.need,
                have = have,
                shortfall = shortfall,
                depth = entry.depth,
                isCraftable = entry.isCraftable,
            })
        end
    end

    -- Section: Shopping List (raw materials only)
    if #shoppingList > 0 then
        -- Spacer row before shopping list for visual separation
        if #tree > 0 then
            table.insert(displayData, { isSpacer = true })
        end
        table.insert(displayData, {
            isSection = true,
            text = "Shopping List (raw materials)",
        })

        for _, item in ipairs(shoppingList) do
            table.insert(displayData, {
                itemID = item.itemID,
                name = item.name,
                need = item.need,
                have = item.have,
                shortfall = item.shortfall,
                depth = 0,
                isCraftable = false,
                isShoppingItem = true,
            })
        end
    end

    self.calcData = displayData
    self.calcScrollOffset = 0

    -- Header
    self.calcHeader:SetText("Materials: " .. recipe.name .. " x" .. qty)

    -- Summary
    local totalShort = 0
    local totalRaw = 0
    for _, item in ipairs(shoppingList) do
        totalRaw = totalRaw + 1
        if item.shortfall > 0 then
            totalShort = totalShort + 1
        end
    end
    if totalShort == 0 then
        local scope = (addon.db.settings.includeAltsInCalc or addon.db.settings.includeRemoteInCalc)
            and "across your characters" or "on this character"
        self.calcSummary:SetText("|cff00ff00All materials available " .. scope .. "!|r")
    else
        self.calcSummary:SetText("|cffff4444Missing " .. totalShort .. " of " .. totalRaw .. " raw materials.|r")
    end

    self:UpdateCalcRows()
end

-- Toggle the calc window open/closed. If opening, populate for current recipe.
-- If already open and called from the button, close it.
function TSF:ToggleCalcPanel()
    if not self.calcPanel then
        self:BuildCalcPanel()
    end

    if self.calcPanel:IsShown() then
        self.calcPanel:Hide()
        self:UpdateCalcBtnState()
        return
    end

    self:RefreshCalcPanel()
    self.calcPanel:Show()
    self:UpdateCalcBtnState()
end

function TSF:UpdateCalcRows()
    local data = self.calcData
    local offset = self.calcScrollOffset
    local MAX_CALC_ROWS = #self.calcRows

    -- Clamp offset
    local maxOffset = math.max(0, #data - MAX_CALC_ROWS)
    if offset > maxOffset then
        offset = maxOffset
        self.calcScrollOffset = offset
    end

    for i = 1, MAX_CALC_ROWS do
        local row = self.calcRows[i]
        local idx = i + offset
        local entry = data[idx]

        if entry then
            row:Show()

            if entry.isSpacer then
                -- Empty spacer row for visual separation
                row.icon:Hide()
                row.nameText:SetText("")
                row.needText:SetText("")
                row.haveText:SetText("")
                row.shortText:SetText("")
                row.itemID = nil
                row.sectionDivider:Hide()
            elseif entry.isSection then
                -- Section header with divider
                row.icon:Hide()
                row.nameText:SetText("|cffffd100" .. entry.text .. "|r")
                row.nameText:SetPoint("LEFT", 2, 0)
                row.needText:SetText("")
                row.haveText:SetText("")
                row.shortText:SetText("")
                row.itemID = nil
                row.sectionDivider:Show()
            else
                -- Material row
                row.sectionDivider:Hide()
                local indentPx = entry.depth * 12
                row.icon:SetPoint("LEFT", 2 + indentPx, 0)

                if entry.itemID then
                    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(entry.itemID)
                    if tex then
                        row.icon:SetTexture(tex)
                        row.icon:Show()
                    else
                        row.icon:Hide()
                    end
                    row.itemID = entry.itemID
                else
                    row.icon:Hide()
                    row.itemID = nil
                end

                local namePrefix = ""
                if entry.isCraftable then
                    namePrefix = "|cff44aaff*|r "
                end
                row.nameText:SetText(namePrefix .. (entry.name or "???"))
                row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)

                row.needText:SetText(tostring(entry.need))

                -- Color code have/shortfall
                if entry.have >= entry.need then
                    row.haveText:SetText("|cff00ff00" .. entry.have .. "|r")
                    row.shortText:SetText("")
                elseif entry.have > 0 then
                    row.haveText:SetText("|cffffff00" .. entry.have .. "|r")
                    row.shortText:SetText("|cffff4444" .. entry.shortfall .. "|r")
                else
                    row.haveText:SetText("|cff888888" .. entry.have .. "|r")
                    row.shortText:SetText("|cffff4444" .. entry.shortfall .. "|r")
                end
            end
        else
            row:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Craft bar (bottom of detail panel)
----------------------------------------------------------------------
function TSF:BuildCraftBar(parent)
    local craftBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    craftBar:SetHeight(CRAFT_BAR_H)
    craftBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", LIST_W + 18, 30)
    craftBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 30)
    craftBar:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    craftBar:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    craftBar:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.8)

    -- Layout: craft bar is DETAIL_W wide (~390px after borders)
    -- Row 1: [Craft]     [qty box] [Craft 1]  [Craft 5]
    -- Row 2: [Craft All] [empty]   [Craft 10] [Craft 20]
    local BTN_H  = 22
    local BTN_W  = 88
    local GAP    = 4
    local PAD    = 8
    local ROW1_Y = -4
    local ROW2_Y = ROW1_Y - BTN_H - 2

    local x1 = PAD
    local x2 = x1 + BTN_W + GAP
    local x3 = x2 + BTN_W + GAP
    local x4 = x3 + BTN_W + GAP

    -- ---- ROW 1: [Craft] [qty box] [Craft 1] [Craft 5] ----

    local craftBtn = CreateFrame("Button", nil, craftBar, "UIPanelButtonTemplate")
    craftBtn:SetSize(BTN_W, BTN_H)
    craftBtn:SetPoint("TOPLEFT", craftBar, "TOPLEFT", x1, ROW1_Y)
    craftBtn:SetText("Craft")
    craftBtn:SetNormalFontObject(GameFontNormalSmall)
    craftBtn:SetScript("OnClick", function()
        self:DoCraft()
    end)
    self.craftBtn = craftBtn

    local qtyBox = CreateFrame("EditBox", nil, craftBar, "BackdropTemplate")
    qtyBox:SetSize(BTN_W, BTN_H)
    qtyBox:SetPoint("TOPLEFT", craftBar, "TOPLEFT", x2, ROW1_Y)
    qtyBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    qtyBox:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
    qtyBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    qtyBox:SetTextInsets(6, 6, 2, 2)
    qtyBox:SetFontObject(GameFontNormalSmall)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetMaxLetters(4)
    qtyBox:SetNumeric(true)
    qtyBox:SetText("1")
    qtyBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    qtyBox:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
        self:DoCraft()
    end)
    qtyBox:SetScript("OnTextChanged", function()
        if self.calcPanel and self.calcPanel:IsShown() then
            self:RefreshCalcPanel()
        end
    end)
    qtyBox:SetScript("OnEditFocusGained", function(eb)
        eb:HighlightText()
    end)
    qtyBox:SetScript("OnEditFocusLost", function(eb)
        eb:HighlightText(0, 0)
    end)
    self.qtyBox = qtyBox

    local function MakeCraftBtn(label, qty, xPos, yPos)
        local b = CreateFrame("Button", nil, craftBar, "UIPanelButtonTemplate")
        b:SetSize(BTN_W, BTN_H)
        b:SetPoint("TOPLEFT", craftBar, "TOPLEFT", xPos, yPos)
        b:SetText(label)
        b:SetNormalFontObject(GameFontNormalSmall)
        b:SetScript("OnClick", function()
            self:DoCraftImmediate(qty)
        end)
        return b
    end

    local craft1  = MakeCraftBtn("Craft 1",  1,  x3, ROW1_Y)
    local craft5  = MakeCraftBtn("Craft 5",  5,  x4, ROW1_Y)

    -- ---- ROW 2: [Craft All] [empty] [Craft 10] [Craft 20] ----

    local craftAll = MakeCraftBtn("Craft All", "all", x1, ROW2_Y)
    local craft10  = MakeCraftBtn("Craft 10",  10,    x3, ROW2_Y)
    local craft20  = MakeCraftBtn("Craft 20",  20,    x4, ROW2_Y)

    -- Store button references for enable/disable in UpdateCraftBar
    self.craftBtns = { craftBtn, craft1, craft5, craft10, craft20, craftAll }

    -- "Recipe unknown" label shown below qty box for unlearned recipes
    local notLearned = craftBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notLearned:SetPoint("TOP", qtyBox, "BOTTOM", 0, 0)
    notLearned:SetPoint("BOTTOM", craftBar, "BOTTOM", 0, 2)
    notLearned:SetText("|cffff2020Recipe unknown|r")
    notLearned:Hide()
    self.craftNotLearned = notLearned

    self.craftBar = craftBar
    craftBar:Hide()

    -- Click-outside focus clearing: when user clicks the craft bar
    -- background (not on a button or the edit box), clear qty focus
    craftBar:SetScript("OnMouseDown", function()
        qtyBox:ClearFocus()
    end)

    -- Store ref so the main frame OnLeave can clear qty focus
    self._qtyBox = qtyBox

    -- Secure craft button for enchanting. DoTradeSkill is a protected
    -- action for item-less recipes (enchants), so we cast the enchant via
    -- a secure macro (like /cast), which puts it on the cursor to apply to
    -- a target item. Parented to the main frame (NOT craftBar) so the craft
    -- bar stays free of secure descendants and can still be shown/hidden in
    -- combat. Visibility is managed via alpha/EnableMouse (non-protected);
    -- the macrotext is set out of combat in UpdateCraftBar.
    -- SecureActionButtonTemplate ONLY -- combining with UIPanelButtonTemplate
    -- lets its OnClick override the secure click handler, which silently
    -- kills the cast. So we style it by hand instead (like the prof tabs).
    local enchantBtn = CreateFrame("Button", "ProfBuddyEnchantCraftBtn", parent,
        "SecureActionButtonTemplate")
    enchantBtn:SetSize(BTN_W, BTN_H)
    enchantBtn:SetPoint("TOPLEFT", craftBar, "TOPLEFT", x1, ROW1_Y)
    enchantBtn:SetFrameLevel(craftBar:GetFrameLevel() + 5)

    -- Outer (border color) then an inset fill, for a simple 1px border
    local ebBg = enchantBtn:CreateTexture(nil, "BACKGROUND")
    ebBg:SetAllPoints()
    ebBg:SetColorTexture(0.4, 0.4, 0.45, 0.9)
    local ebFill = enchantBtn:CreateTexture(nil, "BORDER")
    ebFill:SetPoint("TOPLEFT", 1, -1)
    ebFill:SetPoint("BOTTOMRIGHT", -1, 1)
    ebFill:SetColorTexture(0.18, 0.18, 0.2, 1)
    local ebHi = enchantBtn:CreateTexture(nil, "HIGHLIGHT")
    ebHi:SetAllPoints()
    ebHi:SetColorTexture(0.35, 0.35, 0.45, 0.4)
    local ebText = enchantBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ebText:SetPoint("CENTER")
    ebText:SetText("Craft")

    enchantBtn:SetAttribute("type", "macro")
    -- Secure casts fire on key-DOWN on the modern engine, so the down
    -- event must be registered or the protected action never runs.
    enchantBtn:RegisterForClicks("AnyDown")
    enchantBtn:SetAlpha(0)
    enchantBtn:EnableMouse(false)
    enchantBtn:SetScript("PostClick", function()
        -- The secure macro performed the cast; set up craft tracking so the
        -- skill bar / craftable counts update like a normal craft.
        local recipe = self:GetSelectedRecipe()
        if recipe then
            self._craftingActive = true
            self._craftRemaining = 1
            self._craftSpellName = recipe.name
        end
    end)
    self.enchantCraftBtn = enchantBtn

    -- Hide the secure button whenever the craft bar is hidden
    craftBar:SetScript("OnHide", function()
        enchantBtn:SetAlpha(0)
        enchantBtn:EnableMouse(false)
    end)

    -- Register craft-completion tracking for qty countdown
    self:RegisterCraftEvents()
end

function TSF:RegisterCraftEvents()
    if self._craftEventsRegistered then return end
    self._craftEventsRegistered = true

    -- Track craft completion to decrement qty counter.
    -- Filter by spell name so non-craft casts don't decrement.
    addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        if not self._craftingActive then return end

        -- Match spell name against the recipe we're crafting
        local spellName = GetSpellInfo(spellID)
        if spellName ~= self._craftSpellName then return end

        self._craftRemaining = (self._craftRemaining or 0) - 1
        if self._craftRemaining >= 1 then
            self.qtyBox:SetText(tostring(self._craftRemaining))
        else
            self._craftingActive = false
            self._craftRemaining = 0
            self._craftSpellName = nil
            self.qtyBox:SetText("1")
        end

        -- Craftable count updates are handled by TRADE_SKILL_UPDATE
        -- which fires after the game refreshes its internal data
    end)

    -- If the craft is interrupted (movement, esc, etc.), stop tracking
    addon:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        if not self._craftingActive then return end
        local spellName = GetSpellInfo(spellID)
        if spellName ~= self._craftSpellName then return end
        self._craftingActive = false
        self._craftSpellName = nil
        -- Leave qty at current remaining so user can see how many were left
    end)

    addon:RegisterEvent("UNIT_SPELLCAST_FAILED", function(_, unit, _, spellID)
        if unit ~= "player" then return end
        if not self._craftingActive then return end
        local spellName = GetSpellInfo(spellID)
        if spellName ~= self._craftSpellName then return end
        self._craftingActive = false
        self._craftSpellName = nil
    end)
end

function TSF:GetSelectedRecipe()
    if not state.selected then return nil end
    for _, r in ipairs(state.recipes) do
        if not r.isHeader and r.name == state.selected then
            return r
        end
    end
    return nil
end

-- How many times the current player could make this recipe based purely
-- on reagent counts in bags. Used as a fallback for enchants, whose
-- GetTradeSkillInfo numAvailable is always 0 (they produce no item).
function TSF:ReagentCraftCount(recipe)
    if not recipe.reagents or #recipe.reagents == 0 then return 0 end
    local minMake
    for _, r in ipairs(recipe.reagents) do
        if r.itemID and r.count and r.count > 0 then
            local have = GetItemCount(r.itemID) or 0
            local canMake = math.floor(have / r.count)
            if minMake == nil or canMake < minMake then minMake = canMake end
        end
    end
    return minMake or 0
end

function TSF:UpdateCraftBar()
    -- Don't show craft bar while settings view is active
    if self.settingsPanel and self.settingsPanel:IsShown() then
        self.craftBar:Hide()
        if self.composerBar then self.composerBar:Hide() end
        return
    end

    -- When viewing another character's profession, the normal craft
    -- buttons are useless (can't craft their recipes), so the order
    -- composer takes over that footprint instead.
    if state._viewCharKey then
        self.craftBar:Hide()
        self:UpdateComposer()
        return
    end

    -- Own active profession: ensure the composer is hidden
    if self.composerBar then self.composerBar:Hide() end

    local recipe = self:GetSelectedRecipe()

    if not recipe then
        self.craftBar:Hide()
        return
    end

    self.craftBar:Show()

    local isKnown = recipe.isKnown and recipe.gameIndex
    local avail = isKnown and (recipe.numAvail or 0) or 0
    -- Enchants produce no item, so the game reports 0 available even when
    -- you have the mats. For a known item-less recipe, count reagents.
    if isKnown and avail == 0 and (not recipe.itemID or recipe.itemID == 0) then
        avail = self:ReagentCraftCount(recipe)
    end
    local canCraft = avail > 0
    local itemLess = isKnown and (not recipe.itemID or recipe.itemID == 0)
    local eb = self.enchantCraftBtn

    if itemLess and eb then
        -- Enchant: use the secure cast button; the normal craft buttons
        -- and qty box don't apply (enchants are one cast per target item).
        for _, btn in ipairs(self.craftBtns) do btn:Hide() end
        if self.qtyBox then self.qtyBox:Hide() end
        -- Set the cast target (out of combat only -- secure attribute)
        if not InCombatLockdown() then
            eb:SetAttribute("macrotext", "/cast " .. recipe.name)
        end
        if canCraft then
            eb:SetAlpha(1)
            eb:EnableMouse(true)
        else
            eb:SetAlpha(0.4)
            eb:EnableMouse(false)
        end
    else
        if eb then
            eb:SetAlpha(0)
            eb:EnableMouse(false)
        end
        for _, btn in ipairs(self.craftBtns) do
            btn:Show()
            if canCraft then
                btn:Enable()
            else
                btn:Disable()
            end
        end
        if self.qtyBox then self.qtyBox:Show() end
    end

    if self.craftNotLearned then
        if isKnown then
            self.craftNotLearned:Hide()
        else
            self.craftNotLearned:SetText("|cffff2020Recipe unknown|r")
            self.craftNotLearned:Show()
        end
    end
end

----------------------------------------------------------------------
-- Crafting order composer
-- Repurposes the craft bar's footprint in the friend/alt view (where
-- the normal craft buttons are hidden, since you can't craft someone
-- else's recipes). Lets you compose and submit a craft order.
--
-- Grid (same 2x4 footprint as the craft bar):
--   Row 1: [Request Craft] [qty box]   [ Note box -------- ]
--   Row 2: [ Mat-resp dropdown (2 wide) ] [ ---- (2x2) ---- ]
----------------------------------------------------------------------
local MATRESP_OPTIONS = {
    "Order provides mats",
    "Crafter provides mats",
    "Split / discuss",
}
local MATRESP_VALUE = {
    ["Order provides mats"]   = "requester",
    ["Crafter provides mats"] = "crafter",
    ["Split / discuss"]       = "split",
}

function TSF:BuildComposer(parent)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetHeight(CRAFT_BAR_H)
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", LIST_W + 18, 30)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 30)
    bar:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bar:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    bar:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.8)

    local BTN_H  = 22
    local BTN_W  = 88
    local GAP    = 4
    local PAD    = 8
    local ROW1_Y = -4
    local ROW2_Y = ROW1_Y - BTN_H - 2

    local x1 = PAD
    local x2 = x1 + BTN_W + GAP
    local x3 = x2 + BTN_W + GAP

    -- ---- Row 1 col 1: Request Craft ----
    local requestBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    requestBtn:SetSize(BTN_W, BTN_H)
    requestBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", x1, ROW1_Y)
    requestBtn:SetText("Request Craft")
    requestBtn:SetNormalFontObject(GameFontNormalSmall)
    requestBtn:SetScript("OnClick", function() self:SubmitOrder() end)
    self.composerRequestBtn = requestBtn

    -- ---- Row 1 col 2: quantity ----
    local qty = CreateFrame("EditBox", nil, bar, "BackdropTemplate")
    qty:SetSize(BTN_W, BTN_H)
    qty:SetPoint("TOPLEFT", bar, "TOPLEFT", x2, ROW1_Y)
    qty:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    qty:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
    qty:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    qty:SetTextInsets(6, 6, 2, 2)
    qty:SetFontObject(GameFontNormalSmall)
    qty:SetAutoFocus(false)
    qty:SetMaxLetters(4)
    qty:SetNumeric(true)
    qty:SetText("1")
    qty:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    qty:SetScript("OnEnterPressed", function(eb)
        eb:ClearFocus()
        self:SubmitOrder()
    end)
    qty:SetScript("OnEditFocusGained", function(eb) eb:HighlightText() end)
    qty:SetScript("OnEditFocusLost", function(eb) eb:HighlightText(0, 0) end)
    self.composerQty = qty

    -- ---- Row 2 cols 1-2: mat-responsibility dropdown (spans 2 cells) ----
    local matDrop = CreateDropdown(bar, BTN_W * 2 + GAP, MATRESP_OPTIONS,
        MATRESP_OPTIONS[1], nil, "")
    matDrop:SetPoint("TOPLEFT", bar, "TOPLEFT", x1, ROW2_Y)
    self.composerMatDrop = matDrop

    -- ---- Cols 3-4, both rows: note box (2x2) ----
    -- A multiline EditBox auto-sizes its height to its (empty) content
    -- and collapses, so the visible bordered box is a fixed-size
    -- container frame and the EditBox fills it via two anchors.
    -- Fill from col 3 to the bar's right edge, mirroring the left
    -- side's PAD so the box width matches the controls on the left.
    local noteFrame = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    noteFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", x3, ROW1_Y)
    noteFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -PAD, 4)
    noteFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    noteFrame:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
    noteFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local note = CreateFrame("EditBox", nil, noteFrame)
    note:SetMultiLine(true)
    note:SetPoint("TOPLEFT", noteFrame, "TOPLEFT", 6, -5)
    note:SetPoint("BOTTOMRIGHT", noteFrame, "BOTTOMRIGHT", -6, 5)
    note:SetFontObject(GameFontHighlightSmall)
    note:SetAutoFocus(false)
    note:SetMaxLetters(200)
    note:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)

    -- Clicking anywhere in the bordered area focuses the edit box,
    -- including the padding around the (short) text.
    noteFrame:EnableMouse(true)
    noteFrame:SetScript("OnMouseDown", function() note:SetFocus() end)

    -- Placeholder (EditBoxes have no native placeholder)
    local ph = noteFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("TOPLEFT", 8, -6)
    ph:SetText("Add a note (optional)")
    local function updatePlaceholder()
        if note:GetText() ~= "" then ph:Hide() else ph:Show() end
    end
    note:SetScript("OnTextChanged", updatePlaceholder)
    note:SetScript("OnEditFocusGained", function() ph:Hide() end)
    note:SetScript("OnEditFocusLost", updatePlaceholder)
    updatePlaceholder()
    self.composerNote = note

    -- Clicking the bar background clears focus from the edit boxes
    bar:SetScript("OnMouseDown", function()
        qty:ClearFocus()
        note:ClearFocus()
    end)

    self.composerBar = bar
    bar:Hide()
end

-- Show/hide the composer for the current view. Visible only when
-- viewing a real character (a crafter exists) with a recipe selected.
function TSF:UpdateComposer()
    if not self.composerBar then return end
    if not state._viewCharKey then
        self.composerBar:Hide()
        return
    end
    if not self:GetSelectedRecipe() then
        self.composerBar:Hide()
        return
    end
    self.composerBar:Show()
end

-- Build an order record from the composer fields and hand it to the
-- Orders model. The cross-party notification lands in a later
-- increment; for now the requester gets a local confirmation.
function TSF:SubmitOrder()
    if not state._viewCharKey then return end
    if not addon.Orders then return end

    local recipe = self:GetSelectedRecipe()
    if not recipe or not state.selected then return end

    local qty = tonumber(self.composerQty:GetText()) or 1
    if qty < 1 then qty = 1 end

    local matVal = MATRESP_VALUE[self.composerMatDrop.selectedValue] or "requester"

    local note = strtrim(self.composerNote:GetText() or "")
    if note == "" then note = nil end

    local entry = state.allRecipes[state.selected]
    local itemID = (entry and entry.itemID) or recipe.itemID

    local order, err = addon.Orders:Create({
        crafter = state._viewCharKey,
        item = {
            id         = itemID,
            name       = state.selected,
            profession = state.profName,
        },
        quantity          = qty,
        matResponsibility = matVal,
        note              = note,
    })

    if not order then
        print("|cff00ccffProfessionBuddy:|r Could not create order: " .. tostring(err))
        return
    end

    -- Phase 1: tell the crafter about the new order.
    if addon.Comm then addon.Comm:SendOrderNew(order) end

    local crafterShort = state._viewCharKey:match("^([^-]+)") or state._viewCharKey
    print(string.format("|cff00ccffProfessionBuddy:|r Order requested: %dx %s from %s.",
        qty, state.selected, crafterShort))

    -- Refresh the Orders queue if it's built/open
    if addon.OrdersPanel and addon.OrdersPanel.Refresh then
        addon.OrdersPanel:Refresh()
    end

    -- Reset for the next order
    self.composerQty:SetText("1")
    self.composerNote:SetText("")
    self.composerNote:ClearFocus()
    self.composerQty:ClearFocus()
end

----------------------------------------------------------------------
-- Craft: uses qty from the text field
----------------------------------------------------------------------
function TSF:DoCraft()
    local recipe = self:GetSelectedRecipe()
    if not recipe or not recipe.gameIndex then return end

    local qty = tonumber(self.qtyBox:GetText()) or 1
    if qty < 1 then qty = 1 end

    -- Cap to available
    local avail = recipe.numAvail or 0
    if avail > 0 and qty > avail then qty = avail end

    self.qtyBox:ClearFocus()
    self:StartCraft(recipe, qty)
end

----------------------------------------------------------------------
-- Craft Immediate: sets qty and starts crafting in one click
----------------------------------------------------------------------
function TSF:DoCraftImmediate(qty)
    local recipe = self:GetSelectedRecipe()
    if not recipe or not recipe.gameIndex then return end

    local avail = recipe.numAvail or 0
    if avail <= 0 then return end

    if qty == "all" then
        qty = avail
    else
        -- Cap to what we can actually make
        if qty > avail then qty = avail end
    end

    self.qtyBox:SetText(tostring(qty))
    self.qtyBox:ClearFocus()
    self:StartCraft(recipe, qty)
end

----------------------------------------------------------------------
-- Start the actual craft operation
----------------------------------------------------------------------
function TSF:StartCraft(recipe, qty)
    -- Enchants (no item produced) are cast onto one target item at a time,
    -- so a batch quantity doesn't apply.
    if not recipe.itemID or recipe.itemID == 0 then qty = 1 end

    -- Set up countdown tracking
    self._craftingActive = true
    self._craftRemaining = qty
    self._craftSpellName = recipe.name

    if state.isCraftWindow then
        -- Craft API (Enchanting) doesn't support qty param,
        -- each DoCraft() call queues one cast
        for i = 1, qty do
            DoCraft(recipe.gameIndex)
        end
    else
        DoTradeSkill(recipe.gameIndex, qty)
    end
end

----------------------------------------------------------------------
-- Bottom bar
----------------------------------------------------------------------
function TSF:BuildBottomBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(FRAME_W - 20, 22)
    bar:SetPoint("BOTTOMLEFT", 10, 6)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.08, 0.08, 0.1, 0.9)

    local summary = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("LEFT", 8, 0)
    self.summaryText = summary

    -- Material Calculator toggle button (right side of bottom bar)
    local calcBtn = CreateFrame("Button", nil, bar)
    calcBtn:SetSize(120, 18)
    calcBtn:SetPoint("RIGHT", -4, 0)

    local calcBg = calcBtn:CreateTexture(nil, "BACKGROUND")
    calcBg:SetAllPoints()
    calcBg:SetColorTexture(0.15, 0.15, 0.18, 0.9)
    calcBtn.bg = calcBg

    local calcBorder = CreateFrame("Frame", nil, calcBtn, "BackdropTemplate")
    calcBorder:SetAllPoints()
    calcBorder:EnableMouse(false)
    calcBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
    calcBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    calcBtn.border = calcBorder

    local calcText = calcBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    calcText:SetPoint("CENTER")
    calcText:SetText("Material Calculator")
    calcBtn.label = calcText

    calcBtn:SetScript("OnClick", function()
        self:ToggleCalcPanel()
        self:UpdateCalcBtnState()
    end)
    calcBtn:SetScript("OnEnter", function(self)
        if not self._depressed then
            self.bg:SetColorTexture(0.22, 0.22, 0.28, 0.9)
        end
    end)
    calcBtn:SetScript("OnLeave", function(self)
        if not self._depressed then
            self.bg:SetColorTexture(0.15, 0.15, 0.18, 0.9)
        end
    end)

    self.calcBtn = calcBtn
    self.bottomBar = bar
end

function TSF:UpdateCalcBtnState()
    local btn = self.calcBtn
    if not btn then return end

    local isOpen = self.calcPanel and self.calcPanel:IsShown()
    btn._depressed = isOpen

    if isOpen then
        -- Depressed / active state
        btn.bg:SetColorTexture(0.1, 0.25, 0.45, 0.9)
        btn.border:SetBackdropBorderColor(0.4, 0.7, 1, 0.9)
        btn.label:SetTextColor(0.7, 0.85, 1)
    else
        -- Normal state
        btn.bg:SetColorTexture(0.15, 0.15, 0.18, 0.9)
        btn.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
        btn.label:SetTextColor(1, 0.82, 0)
    end
end

----------------------------------------------------------------------
-- Settings panel (full-window overlay, replaces main content)
----------------------------------------------------------------------
function TSF:BuildSettingsPanel(parent)
    local topOffset = -106

    local panel = CreateFrame("Frame", "ProfBuddySettingsPanel", parent)
    panel:SetPoint("TOPLEFT", 10, topOffset)
    panel:SetPoint("BOTTOMRIGHT", -10, 6)
    panel:EnableMouse(true)
    panel:Hide()

    -- Solid background so nothing bleeds through
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 1)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Settings")
    title:SetTextColor(1, 0.82, 0)

    -- Divider
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    -- Checkbox factory (supports x offset for columns)
    local settings = addon.db.settings
    local checkboxes = {}
    local COL_LEFT = 14
    local COL_RIGHT = 370

    local function MakeCheckbox(label, settingKey, y, xOff)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", xOff or COL_LEFT, y)
        cb:SetChecked(settings[settingKey])
        cb.settingKey = settingKey

        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        text:SetText(label)
        text:SetTextColor(0.9, 0.9, 0.9)

        cb:SetScript("OnClick", function(self)
            settings[self.settingKey] = self:GetChecked()
        end)

        table.insert(checkboxes, cb)
        return cb
    end

    -- ════════════════════════════════════════════════════════════
    -- LEFT COLUMN
    -- ════════════════════════════════════════════════════════════
    local yLeft = -46

    local replCB = MakeCheckbox("Replace default profession window", "replaceTradeSkill", yLeft)
    replCB:SetScript("OnClick", function(self)
        local on = self:GetChecked()
        settings.replaceTradeSkill = on
        if on then
            TSF:SuppressDefaultFrames()
        else
            -- Restoring default frames requires re-registering events
            -- that we can't reconstruct -- reload to get a clean state.
            ReloadUI()
        end
    end)
    yLeft = yLeft - 30
    MakeCheckbox("Remember window state between opens", "rememberWindowState", yLeft)
    yLeft = yLeft - 30
    local allProfCB = MakeCheckbox("Show all professions in tabs", "showAllProfessions", yLeft)
    allProfCB:SetScript("OnClick", function(self)
        settings.showAllProfessions = self:GetChecked()
        TSF:UpdateProfessionTabs()
    end)
    yLeft = yLeft - 40

    -- ── Alt Information section ────────────────────────────────
    local altHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    altHeader:SetPoint("TOPLEFT", COL_LEFT, yLeft)
    altHeader:SetText("Alt Information")
    altHeader:SetTextColor(1, 0.82, 0)
    yLeft = yLeft - 20

    local altGroupBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    altGroupBg:SetPoint("TOPLEFT", COL_LEFT - 4, yLeft + 4)
    altGroupBg:SetSize(340, 1) -- height set below
    altGroupBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    altGroupBg:SetBackdropColor(0.1, 0.1, 0.12, 0.6)
    local altGroupTop = yLeft + 4
    yLeft = yLeft - 6

    MakeCheckbox("Show in detail panel", "showAltInDetail", yLeft)
    yLeft = yLeft - 26
    MakeCheckbox("Show in tooltips", "showAltInTooltips", yLeft)
    yLeft = yLeft - 26
    MakeCheckbox("Include in material calculator", "includeAltsInCalc", yLeft)
    yLeft = yLeft - 26
    MakeCheckbox("Show opposite faction alts", "showCrossFactionAlts", yLeft)
    yLeft = yLeft - 14

    altGroupBg:SetHeight(altGroupTop - yLeft)

    -- ── Friend Data section ──────────────────────────────────
    yLeft = yLeft - 20

    local friendHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendHeader:SetPoint("TOPLEFT", COL_LEFT, yLeft)
    friendHeader:SetText("Friend Data")
    friendHeader:SetTextColor(1, 0.82, 0)
    yLeft = yLeft - 20

    local friendGroupBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    friendGroupBg:SetPoint("TOPLEFT", COL_LEFT - 4, yLeft + 4)
    friendGroupBg:SetSize(340, 1)
    friendGroupBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    friendGroupBg:SetBackdropColor(0.1, 0.1, 0.12, 0.6)
    local friendGroupTop = yLeft + 4
    yLeft = yLeft - 6

    MakeCheckbox("Show in detail panel", "showRemoteInDetail", yLeft)
    yLeft = yLeft - 26
    MakeCheckbox("Show in tooltips", "showRemoteInTooltips", yLeft)
    yLeft = yLeft - 26
    MakeCheckbox("Include in material calculator", "includeRemoteInCalc", yLeft)
    yLeft = yLeft - 14

    friendGroupBg:SetHeight(friendGroupTop - yLeft)

    -- ════════════════════════════════════════════════════════════
    -- RIGHT COLUMN
    -- ════════════════════════════════════════════════════════════
    local yRight = -46

    -- ── Item Tooltips section ──────────────────────────────────
    local sectionHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", COL_RIGHT, yRight)
    sectionHeader:SetText("Item Tooltips")
    sectionHeader:SetTextColor(1, 0.82, 0)
    yRight = yRight - 20

    local groupBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    groupBg:SetPoint("TOPLEFT", COL_RIGHT - 4, yRight + 4)
    groupBg:SetSize(340, 1) -- height set below
    groupBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    groupBg:SetBackdropColor(0.1, 0.1, 0.12, 0.6)
    local groupTop = yRight + 4
    yRight = yRight - 6

    local usedInCB = MakeCheckbox("Show recipes used in", "tooltipShowUsedIn", yRight, COL_RIGHT)
    yRight = yRight - 30

    -- Slider width for right column
    local SLIDER_W = 290

    -- Slider 1: your professions (1-15 numeric, 16 = "All")
    local ownLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ownLabel:SetPoint("TOPLEFT", COL_RIGHT + 24, yRight)
    ownLabel:SetTextColor(0.9, 0.9, 0.9)

    local ownSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    ownSlider:SetSize(SLIDER_W, 16)
    ownSlider:SetPoint("TOPLEFT", COL_RIGHT + 24, yRight - 18)
    ownSlider:SetMinMaxValues(0, 16)
    ownSlider:SetValueStep(1)
    ownSlider:SetObeyStepOnDrag(true)
    ownSlider:SetValue(settings.tooltipMaxOwn or 16)
    ownSlider.Low:SetText("0")
    ownSlider.High:SetText("All")
    ownSlider.Text:SetText("")
    yRight = yRight - 44

    -- Slider 2: alt professions (1-15 numeric, 16 = "All")
    local altLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    altLabel:SetPoint("TOPLEFT", COL_RIGHT + 24, yRight)
    altLabel:SetTextColor(0.9, 0.9, 0.9)

    local altSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    altSlider:SetSize(SLIDER_W, 16)
    altSlider:SetPoint("TOPLEFT", COL_RIGHT + 24, yRight - 18)
    altSlider:SetMinMaxValues(0, 16)
    altSlider:SetValueStep(1)
    altSlider:SetObeyStepOnDrag(true)
    altSlider:SetValue(settings.tooltipMaxAlt or 16)
    altSlider.Low:SetText("0")
    altSlider.High:SetText("All")
    altSlider.Text:SetText("")
    yRight = yRight - 44

    -- Slider 3: other professions (1-20)
    local otherLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    otherLabel:SetPoint("TOPLEFT", COL_RIGHT + 24, yRight)
    otherLabel:SetTextColor(0.9, 0.9, 0.9)

    local otherSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
    otherSlider:SetSize(SLIDER_W, 16)
    otherSlider:SetPoint("TOPLEFT", COL_RIGHT + 24, yRight - 18)
    otherSlider:SetMinMaxValues(0, 20)
    otherSlider:SetValueStep(1)
    otherSlider:SetObeyStepOnDrag(true)
    otherSlider:SetValue(settings.tooltipMaxOther or 5)
    otherSlider.Low:SetText("0")
    otherSlider.High:SetText("20")
    otherSlider.Text:SetText("")
    yRight = yRight - 14

    groupBg:SetHeight(groupTop - yRight)

    -- Shared update function for sliders + checkbox
    local function UpdateTooltipGroup()
        local enabled = settings.tooltipShowUsedIn

        local ownVal = math.floor(ownSlider:GetValue())
        local ownText = ownVal == 0 and "Off" or (ownVal >= 16 and "All" or tostring(ownVal))
        ownLabel:SetText("Your professions: " .. ownText)

        local altVal = math.floor(altSlider:GetValue())
        local altText = altVal == 0 and "Off" or (altVal >= 16 and "All" or tostring(altVal))
        altLabel:SetText("Alt professions: " .. altText)

        local otherVal = math.floor(otherSlider:GetValue())
        local otherText = otherVal == 0 and "Off" or tostring(otherVal)
        otherLabel:SetText("Other professions: " .. otherText)

        if enabled then
            ownSlider:Enable()
            altSlider:Enable()
            otherSlider:Enable()
            ownLabel:SetTextColor(0.9, 0.9, 0.9)
            altLabel:SetTextColor(0.9, 0.9, 0.9)
            otherLabel:SetTextColor(0.9, 0.9, 0.9)
            ownSlider:SetAlpha(1)
            altSlider:SetAlpha(1)
            otherSlider:SetAlpha(1)
        else
            ownSlider:Disable()
            altSlider:Disable()
            otherSlider:Disable()
            ownLabel:SetTextColor(0.4, 0.4, 0.4)
            altLabel:SetTextColor(0.4, 0.4, 0.4)
            otherLabel:SetTextColor(0.4, 0.4, 0.4)
            ownSlider:SetAlpha(0.4)
            altSlider:SetAlpha(0.4)
            otherSlider:SetAlpha(0.4)
        end
    end
    UpdateTooltipGroup()

    -- Wire checkbox to enable/disable sliders
    usedInCB:SetScript("OnClick", function(self)
        settings.tooltipShowUsedIn = self:GetChecked()
        UpdateTooltipGroup()
    end)

    ownSlider:SetScript("OnValueChanged", function(_, val)
        settings.tooltipMaxOwn = math.floor(val)
        UpdateTooltipGroup()
    end)

    altSlider:SetScript("OnValueChanged", function(_, val)
        settings.tooltipMaxAlt = math.floor(val)
        UpdateTooltipGroup()
    end)

    otherSlider:SetScript("OnValueChanged", function(_, val)
        settings.tooltipMaxOther = math.floor(val)
        UpdateTooltipGroup()
    end)

    -- ── Crafting Order Notifications section ──────────────────
    -- Large gap to clear the third tooltip slider + its min/max labels
    yRight = yRight - 52

    local notifHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notifHeader:SetPoint("TOPLEFT", COL_RIGHT, yRight)
    notifHeader:SetText("Crafting Order Notifications")
    notifHeader:SetTextColor(1, 0.82, 0)
    yRight = yRight - 20

    local notifGroupBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    notifGroupBg:SetPoint("TOPLEFT", COL_RIGHT - 4, yRight + 4)
    notifGroupBg:SetSize(340, 1)
    notifGroupBg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    notifGroupBg:SetBackdropColor(0.1, 0.1, 0.12, 0.6)
    local notifGroupTop = yRight + 4
    yRight = yRight - 6

    MakeCheckbox("Order chat messages", "orderChatMessages", yRight, COL_RIGHT)
    yRight = yRight - 26
    MakeCheckbox("Sound on new request", "orderSoundOnRequest", yRight, COL_RIGHT)
    yRight = yRight - 26

    local notifNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notifNote:SetPoint("TOPLEFT", COL_RIGHT + 4, yRight)
    notifNote:SetText("|cff888888The Orders tab count badge is always shown.|r")
    yRight = yRight - 16

    notifGroupBg:SetHeight(notifGroupTop - yRight)

    -- Hint at the bottom
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 16)
    hint:SetText("|cff888888Click the gear icon or press Escape to return.|r")

    -- Refresh checkbox states on show + hide any panels that
    -- might have bled through from background events
    panel:SetScript("OnShow", function()
        for _, cb in ipairs(checkboxes) do
            cb:SetChecked(settings[cb.settingKey])
        end
        ownSlider:SetValue(settings.tooltipMaxOwn or 16)
        altSlider:SetValue(settings.tooltipMaxAlt or 16)
        otherSlider:SetValue(settings.tooltipMaxOther or 5)
        UpdateTooltipGroup()
        -- Belt-and-suspenders: hide content that shouldn't be visible
        if TSF.craftBar then TSF.craftBar:Hide() end
        if TSF.listPanel then TSF.listPanel:Hide() end
        if TSF.detailFrame then TSF.detailFrame:Hide() end
        if TSF.bottomBar then TSF.bottomBar:Hide() end
    end)

    self.settingsPanel = panel
    self.settingsCheckboxes = checkboxes
end

-- Open settings from a specific origin.
-- origin: "profession" (from the TSF gear icon or /pb config while
--         profession window is open), "main" (from /pb main window
--         gear icon), or "command" (from /pb config with nothing open).
function TSF:RestoreContentPanels()
    if self.settingsPanel then self.settingsPanel:Hide() end
    if self.profTabContainer and not InCombatLockdown() then self.profTabContainer:Show() end
    if self.listPanel then self.listPanel:Show() end
    if self.detailFrame then self.detailFrame:Show() end
    if self.craftBar then self.craftBar:Show() end
    if self.bottomBar then self.bottomBar:Show() end
    if self.skillBar then self.skillBar:Show() end
    if self.searchBox then self.searchBox:Show() end
    if self.catDropdown then self.catDropdown:Show() end
    if self.diffDropdown then self.diffDropdown:Show() end
    if self.sortDropdown then self.sortDropdown:Show() end
    if self.viewDropdown then self.viewDropdown:Show() end
end

function TSF:HideContentPanels()
    CloseAllDropdowns()
    if self.profTabContainer and not InCombatLockdown() then self.profTabContainer:Hide() end
    if self.listPanel then self.listPanel:Hide() end
    if self.detailFrame then self.detailFrame:Hide() end
    if self.craftBar then self.craftBar:Hide() end
    if self.composerBar then self.composerBar:Hide() end
    if self.bottomBar then self.bottomBar:Hide() end
    if self.skillBar then self.skillBar:Hide() end
    if self.searchBox then self.searchBox:Hide() end
    if self.catDropdown then self.catDropdown:Hide() end
    if self.diffDropdown then self.diffDropdown:Hide() end
    if self.sortDropdown then self.sortDropdown:Hide() end
    if self.viewDropdown then self.viewDropdown:Hide() end
    if self.calcPanel then self.calcPanel:Hide() end
end

function TSF:OpenSettings(origin)
    self:EnsureFrame()

    -- Track where we came from so we can return there
    if origin then
        self._settingsOrigin = origin
    elseif not self._settingsOrigin then
        self._settingsOrigin = "profession"
    end

    -- Make sure the profession frame is visible (settings lives inside it)
    if not self.frame:IsShown() then
        self.frame:Show()
    end

    -- If settings is already showing, this is a toggle-off
    if self.settingsPanel and self.settingsPanel:IsShown() then
        self:CloseSettings()
        return
    end

    -- Remember calc panel state before hiding content
    self._calcOpenBeforeSettings = self.calcPanel and self.calcPanel:IsShown() or false

    -- Switch to settings view
    self:HideContentPanels()
    self.settingsPanel:Show()
end

function TSF:CloseSettings()
    if not self.settingsPanel then return end

    local origin = self._settingsOrigin or "profession"
    local calcWasOpen = self._calcOpenBeforeSettings
    self._calcOpenBeforeSettings = false

    if origin == "main" or origin == "command" then
        -- Return to the /pb main window
        self:RestoreContentPanels()
        self.frame:Hide()
        if addon.UI then addon.UI:Show() end
        -- Reopen the Order History panel if it was open before settings
        if addon.OrdersPanel then addon.OrdersPanel:RestoreHistoryState() end
    else
        -- Return to the profession view
        self:RestoreContentPanels()
        self:RefreshDetailPanel()
        self:UpdateCraftBar()

        -- Restore material calc if it was open before settings
        if calcWasOpen then
            if not self.calcPanel then
                self:BuildCalcPanel()
            end
            self:RefreshCalcPanel()
            self.calcPanel:Show()
            self:UpdateCalcBtnState()
        end
    end
end

-- Legacy toggle (used by the TSF gear icon)
function TSF:ToggleSettings()
    if self.settingsPanel and self.settingsPanel:IsShown() then
        self:CloseSettings()
    else
        self:OpenSettings("profession")
    end
end

----------------------------------------------------------------------
-- Bottom bar stats
----------------------------------------------------------------------
function TSF:UpdateBottomBar()
    local knownCount = 0
    for _ in pairs(state.allRecipes) do
        knownCount = knownCount + 1
    end

    local missingCount = 0
    local trainableCount = 0
    local learnableNow = 0
    if RDB and RDB.data[state.profName] then
        local viewChar = state._viewCharKey or addon:PlayerKey()
        local unknown = RDB:GetUnknownRecipes(viewChar, state.profName)
        for _, info in pairs(unknown) do
            missingCount = missingCount + 1
            if info.source == "trainer" then
                trainableCount = trainableCount + 1
            end
            if info.skillReq and info.skillReq <= (state.skillLevel or 0) then
                learnableNow = learnableNow + 1
            end
        end
    end

    self.summaryText:SetText(
        "|cff00ff00Known: " .. knownCount .. "|r    " ..
        "|cffff8800Missing: " .. missingCount .. "|r    " ..
        "|cffffff00From Trainer: " .. trainableCount .. "|r    " ..
        "|cff44ddffLearnable Now: " .. learnableNow .. "|r"
    )
end

----------------------------------------------------------------------
-- Item category detection
----------------------------------------------------------------------
local function GetItemCategory(itemID)
    if not itemID then return "Other" end
    local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemID)
    if not itemType then return "Other" end

    if itemType == "Armor" then
        if itemSubType == "Plate" then return "Plate Armor"
        elseif itemSubType == "Mail" then return "Mail Armor"
        elseif itemSubType == "Leather" then return "Leather Armor"
        elseif itemSubType == "Cloth" then return "Cloth Armor"
        elseif itemSubType == "Shield" or itemSubType == "Shields" then return "Shield"
        else return "Armor"
        end
    elseif itemType == "Weapon" then return "Weapon"
    elseif itemType == "Consumable" then return "Consumable"
    elseif itemType == "Trade Goods" or itemType == "Tradeskill" then return "Trade Good"
    elseif itemType == "Recipe" then return "Recipe"
    elseif itemType == "Item Enhancement" then return "Enhancement"
    end
    return "Other"
end

-- v6: Get category preferring static DB over GetItemInfo
local function GetRecipeCategory(name, itemID, profName)
    -- Check static DB first for a more descriptive category
    if RDB and RDB.data then
        -- Check the specific profession first
        if profName and RDB.data[profName] and RDB.data[profName][name] then
            local cat = RDB.data[profName][name].category
            if cat then return cat end
        end
        -- Fall back to any profession
        for _, profRecipes in pairs(RDB.data) do
            if profRecipes[name] and profRecipes[name].category then
                return profRecipes[name].category
            end
        end
    end
    -- Fall back to game API category
    return GetItemCategory(itemID)
end

-- Get subcategory from static DB (may be nil)
local function GetRecipeSubcategory(name, profName)
    if RDB and RDB.data then
        if profName and RDB.data[profName] and RDB.data[profName][name] then
            return RDB.data[profName][name].subcategory
        end
        for _, profRecipes in pairs(RDB.data) do
            if profRecipes[name] and profRecipes[name].subcategory then
                return profRecipes[name].subcategory
            end
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Data pipeline
----------------------------------------------------------------------
function TSF:LoadRecipes()
    local rawList = {}
    local showKnown  = (state.showTab == "known" or state.showTab == "all")
    local showMissing = (state.showTab == "missing" or state.showTab == "all")

    -- Known recipes (from scanner)
    if showKnown then
        for idx, name in ipairs(state.recipeOrder) do
            local data = state.allRecipes[name]
            if data then
                local sr = nil
                local sReq = nil
                if RDB and RDB.data[state.profName] then
                    local dbEntry = RDB.data[state.profName][name]
                    if dbEntry then
                        if dbEntry.skillRange then sr = dbEntry.skillRange end
                        if dbEntry.skillReq then sReq = dbEntry.skillReq end
                    end
                end

                table.insert(rawList, {
                    name        = name,
                    difficulty  = data.difficulty,
                    icon        = data.icon,
                    itemID      = data.itemID,
                    itemLink    = data.itemLink,
                    numAvail    = data.numAvail or 0,
                    reagents    = data.reagents,
                    skillReq    = sReq or data.skillReq,
                    skillRange  = sr,
                    category    = GetRecipeCategory(name, data.itemID, state.profName),
                    subcategory = GetRecipeSubcategory(name, state.profName),
                    gameOrder   = idx,
                    gameIndex   = data.index,
                    isKnown     = true,
                })
            end
        end
    end

    -- Missing recipes (from static DB)
    if showMissing and RDB and RDB.data[state.profName] then
        local viewChar = state._viewCharKey or addon:PlayerKey()
        local unknown = RDB:GetUnknownRecipes(viewChar, state.profName)
        local idx = 1000
        for name, info in pairs(unknown) do
            idx = idx + 1
            local missingIcon = nil
            if info.itemID then
                missingIcon = select(10, GetItemInfo(info.itemID))
            end
            table.insert(rawList, {
                name         = name,
                difficulty   = "medium",
                icon         = missingIcon,
                itemID       = info.itemID,
                skillReq     = info.skillReq,
                skillRange   = info.skillRange,
                source       = info.source,
                sourceDetail = info.sourceDetail,
                reagents     = info.reagents,
                category     = info.category or GetItemCategory(info.itemID),
                subcategory  = info.subcategory,
                gameOrder    = idx,
                isKnown      = false,
            })
        end
    end

    -- Discover categories
    local catSet = {}
    for _, r in ipairs(rawList) do catSet[r.category or "Other"] = true end
    local cats = { "All" }
    local catsSorted = {}
    for c in pairs(catSet) do table.insert(catsSorted, c) end
    table.sort(catsSorted)
    for _, c in ipairs(catsSorted) do table.insert(cats, c) end

    if self.catDropdown then
        self.catDropdown:SetOptions(cats)
        if state.filterCat ~= "All" then
            local found = false
            for _, c in ipairs(cats) do if c == state.filterCat then found = true; break end end
            if not found then
                state.filterCat = "All"
                self.catDropdown:SetValue("All")
            end
        end
    end

    if self.diffDropdown then
        if state.showTab == "known" then
            self.diffDropdown:SetOptions({"All", "Orange", "Yellow", "Green", "Grey"})
        elseif state.showTab == "missing" then
            self.diffDropdown:SetOptions({"All", "Trainer", "Vendor", "Drop", "Quest", "Reputation", "Discovery"})
        else
            self.diffDropdown:SetOptions({"All", "Orange", "Yellow", "Green", "Grey", "Trainer", "Vendor", "Drop"})
        end
    end

    -- Filter
    local filtered = {}
    local diffMap = { Orange = "optimal", Yellow = "medium", Green = "easy", Grey = "trivial" }
    local srcMap  = { Trainer = "trainer", Vendor = "vendor", Drop = "drop", Quest = "quest", Reputation = "reputation", Discovery = "discovery" }

    for _, r in ipairs(rawList) do
        local passSearch = true
        local passDiff   = true
        local passCat    = true

        if state.searchText ~= "" then
            passSearch = r.name:lower():find(state.searchText, 1, true) ~= nil
        end
        if state.filterCat ~= "All" then
            passCat = (r.category == state.filterCat)
        end
        if state.filterDiff ~= "All" then
            if r.isKnown then
                passDiff = (r.difficulty == diffMap[state.filterDiff])
            else
                passDiff = (r.source == srcMap[state.filterDiff])
            end
        end

        if passSearch and passDiff and passCat then
            table.insert(filtered, r)
        end
    end

    -- Sort (v6: secondary sort for all modes; v9: ascending/descending toggle)
    local sortBy = state.sortBy
    local asc = state.sortAsc
    local useCategories = (sortBy == "Category")

    -- Skill Ups duration helper (shared by Category and Skill Ups sorts)
    local sk = state.skillLevel or 0
    local function getSkillUpDuration(r)
        local sr = r.skillRange
        if not sr then return 0 end
        local diff = r.difficulty
        if diff == "optimal" then return (sr[2] or 0) - sk
        elseif diff == "medium" then return (sr[3] or 0) - sk
        elseif diff == "easy" then return (sr[4] or 0) - sk
        else return 0 end
    end

    if useCategories then
        -- Category > subcategory > (known: difficulty > duration | missing: skillReq) > name
        table.sort(filtered, function(a, b)
            if a.category ~= b.category then
                if asc then return (a.category or "") < (b.category or "")
                else return (a.category or "") > (b.category or "") end
            end
            if a.subcategory ~= b.subcategory then
                if not a.subcategory then return asc end
                if not b.subcategory then return not asc end
                if asc then return a.subcategory < b.subcategory
                else return a.subcategory > b.subcategory end
            end
            -- Known recipes sort above missing within same category
            if a.isKnown ~= b.isKnown then return a.isKnown end
            -- Missing recipes: sort by learn level (lowest first)
            if not a.isKnown then
                local reqA = a.skillReq or 0
                local reqB = b.skillReq or 0
                if reqA ~= reqB then
                    if asc then return reqA < reqB else return reqA > reqB end
                end
                return a.name < b.name
            end
            -- Known recipes: difficulty color > duration > name
            local da = DIFF_ORDER[a.difficulty] or 5
            local db = DIFF_ORDER[b.difficulty] or 5
            if da ~= db then return da < db end
            local durA = getSkillUpDuration(a)
            local durB = getSkillUpDuration(b)
            if durA ~= durB then return durA > durB end
            return a.name < b.name
        end)
    else
        table.sort(filtered, function(a, b)
            if sortBy == "Skill Ups" then
                -- Known sorts above missing
                if a.isKnown ~= b.isKnown then return a.isKnown end
                -- Missing recipes: sort by learn level
                if not a.isKnown then
                    local reqA = a.skillReq or 0
                    local reqB = b.skillReq or 0
                    if reqA ~= reqB then
                        if asc then return reqA < reqB else return reqA > reqB end
                    end
                    return a.name < b.name
                end
                -- Known: difficulty color (orange > yellow > green > grey)
                local da = DIFF_ORDER[a.difficulty] or 5
                local db2 = DIFF_ORDER[b.difficulty] or 5
                if da ~= db2 then
                    if asc then return da < db2 else return da > db2 end
                end
                -- Secondary: duration remaining in current color (longest first)
                local durA = getSkillUpDuration(a)
                local durB = getSkillUpDuration(b)
                if durA ~= durB then
                    if asc then return durA > durB else return durA < durB end
                end
                -- Tertiary for grey: category sort
                if (DIFF_ORDER[a.difficulty] or 5) == 4 then
                    if (a.category or "") ~= (b.category or "") then
                        return (a.category or "") < (b.category or "")
                    end
                end
                return a.name < b.name
            elseif sortBy == "Name" then
                if asc then return a.name < b.name
                else return a.name > b.name end
            end
            return a.name < b.name
        end)
    end

    -- Category/subcategory headers with collapse support
    state.collapsed = state.collapsed or {}

    local displayList = {}
    if useCategories then
        local lastCat = nil
        local lastSubCat = "__NONE__"

        for _, r in ipairs(filtered) do
            local cat = r.category or "Other"
            local subcat = r.subcategory

            -- Category header
            if cat ~= lastCat then
                local catCount = 0
                for _, r2 in ipairs(filtered) do
                    if (r2.category or "Other") == cat then catCount = catCount + 1 end
                end
                local catKey = cat
                local isCollapsed = state.collapsed[catKey] or false
                table.insert(displayList, {
                    isHeader = true,
                    headerType = "category",
                    headerKey = catKey,
                    name = cat,
                    count = catCount,
                    isCollapsed = isCollapsed,
                })
                lastCat = cat
                lastSubCat = "__NONE__"
            end

            -- Skip recipes (and subcategory headers) if category is collapsed
            if state.collapsed[cat] then
                -- skip
            else
                -- Subcategory header
                if subcat and subcat ~= lastSubCat then
                    local subCount = 0
                    for _, r2 in ipairs(filtered) do
                        if (r2.category or "Other") == cat and r2.subcategory == subcat then
                            subCount = subCount + 1
                        end
                    end
                    local subKey = cat .. "|" .. subcat
                    local isSubCollapsed = state.collapsed[subKey] or false
                    table.insert(displayList, {
                        isHeader = true,
                        headerType = "subcategory",
                        headerKey = subKey,
                        name = subcat,
                        count = subCount,
                        isCollapsed = isSubCollapsed,
                    })
                    lastSubCat = subcat
                end

                -- Skip recipes if subcategory is collapsed
                local subKey = subcat and (cat .. "|" .. subcat) or nil
                if subKey and state.collapsed[subKey] then
                    -- skip
                else
                    table.insert(displayList, r)
                end

                -- Update lastSubCat for nil subcategory recipes
                if not subcat then
                    lastSubCat = "__NONE__"
                end
            end
        end
    else
        displayList = filtered
    end

    state.recipes = displayList
end

function TSF:RefreshRecipeList()
    self:LoadRecipes()

    local maxScroll = math.max(0, #state.recipes - VISIBLE_ROWS)
    self.scrollBar:SetMinMaxValues(0, maxScroll)
    if state.scrollOffset > maxScroll then
        state.scrollOffset = maxScroll
    end
    self.scrollBar:SetValue(state.scrollOffset)

    self:UpdateListRows()
    self:UpdateBottomBar()
    self:UpdateViewDropdown()

    if state.selected then
        local found = false
        for _, r in ipairs(state.recipes) do
            if not r.isHeader and r.name == state.selected then found = true; break end
        end
        if not found then
            -- Only clear selection if recipe is truly gone from the profession,
            -- not merely filtered out. Prevents random detail panel resets when
            -- TRADE_SKILL_UPDATE fires and difficulty/filter state diverges.
            if not state.allRecipes[state.selected] then
                state.selected = nil
                self:ClearDetailPanel()
                self:UpdateCraftBar()
            end
        end
    end
end

function TSF:RebuildAndRefresh()
    state.filterCat = "All"
    state.filterDiff = "All"
    state.sortBy = "Category"
    state.sortAsc = true
    if self.catDropdown then self.catDropdown:SetValue("All") end
    if self.diffDropdown then self.diffDropdown:SetValue("All") end
    if self.sortDropdown then self.sortDropdown:SetValue("Sort: Category ^", "Category") end
    self:RefreshRecipeList()
end

----------------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------------
function TSF:AutoSelectFirst()
    for _, r in ipairs(state.recipes) do
        if not r.isHeader then
            state.selected = r.name
            self:UpdateListHighlights()
            self:RefreshDetailPanel()
            self:UpdateCraftBar()
            return
        end
    end
end

----------------------------------------------------------------------
-- Window state preservation (per-profession)
----------------------------------------------------------------------
TSF._savedStates = {}

function TSF:SaveWindowState()
    if not addon.db.settings.rememberWindowState then return end
    local prof = state.profName
    if not prof then return end

    self._savedStates[prof] = {
        selected     = state.selected,
        scrollOffset = state.scrollOffset,
        showTab      = state.showTab,
        filterCat    = state.filterCat,
        filterDiff   = state.filterDiff,
        sortBy       = state.sortBy,
        sortAsc      = state.sortAsc,
        searchText   = state.searchText,
        collapsed    = state.collapsed,
        calcOpen     = self.calcPanel and self.calcPanel:IsShown() or false,
    }
end

function TSF:RestoreWindowState(profName)
    if not addon.db.settings.rememberWindowState then return false end
    local saved = self._savedStates[profName]
    if not saved then return false end

    state.selected     = saved.selected
    state.scrollOffset = saved.scrollOffset
    state.showTab      = saved.showTab
    state.filterCat    = saved.filterCat
    state.filterDiff   = saved.filterDiff
    state.sortBy       = saved.sortBy
    -- Migrate removed sort options from older versions
    if state.sortBy == "Skill Req" or state.sortBy == "Craftable" or state.sortBy == "Difficulty" then
        state.sortBy = "Skill Ups"
    end
    state.sortAsc      = saved.sortAsc
    state.searchText   = saved.searchText
    state.collapsed    = saved.collapsed or {}
    state._restoreCalc = saved.calcOpen or false
    return true
end

----------------------------------------------------------------------
-- Open profession window
----------------------------------------------------------------------
function TSF:OpenWith(profName, rank, maxRank, isCraft)
    -- Close the /pb main window if open (mutual exclusion)
    if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() then
        addon.UI:Hide()
    end

    -- Ensure all content panels are visible (may have been hidden
    -- by settings view in a previous session)
    self:EnsureFrame()
    self:RestoreContentPanels()

    state.profName      = profName
    state.skillLevel    = rank or 0
    state.maxSkill      = maxRank or 375
    state.isCraftWindow = isCraft or false
    state.allRecipes    = {}
    state.recipeOrder   = {}
    state._isStaticView = false
    state._viewCharKey  = nil

    -- Try to restore saved UI state for this profession
    local restored = self:RestoreWindowState(profName)
    if not restored then
        state.selected     = nil
        state.scrollOffset = 0
        state.showTab      = "known"
        state.filterCat    = "All"
        state.filterDiff   = "All"
        state.sortBy       = "Category"
        state.sortAsc      = true
        state.searchText   = ""
        state.collapsed    = {}
    end

    if isCraft then
        local numCrafts = GetNumCrafts()
        for i = 1, numCrafts do
            local craftName, _, craftType = GetCraftInfo(i)
            if craftName and craftType ~= "header" then
                local itemLink = GetCraftItemLink(i)
                local icon = GetCraftIcon(i)

                local reagents = {}
                for j = 1, 12 do
                    local rName, rTexture, rCount = GetCraftReagentInfo(i, j)
                    if not rName then break end
                    local rLink = GetCraftReagentItemLink(i, j)
                    table.insert(reagents, {
                        itemID = addon:ItemIDFromLink(rLink),
                        name   = rName,
                        count  = rCount,
                        icon   = rTexture,
                    })
                end

                state.allRecipes[craftName] = {
                    index    = i,
                    itemID   = addon:ItemIDFromLink(itemLink),
                    itemLink = itemLink,
                    icon     = icon,
                    difficulty = craftType,
                    reagents = reagents,
                }
                table.insert(state.recipeOrder, craftName)
            end
        end
    else
        local numRecipes = GetNumTradeSkills()
        for i = 1, numRecipes do
            local skillName, skillType, numAvail = GetTradeSkillInfo(i)
            if skillName and skillType ~= "header" and skillType ~= "subheader" then
                local itemLink = GetTradeSkillItemLink(i)
                local icon = GetTradeSkillIcon(i)

                local reagents = {}
                for j = 1, 12 do
                    local rName, rTexture, rCount = GetTradeSkillReagentInfo(i, j)
                    if not rName then break end
                    local rLink = GetTradeSkillReagentItemLink(i, j)
                    table.insert(reagents, {
                        itemID = addon:ItemIDFromLink(rLink),
                        name   = rName,
                        count  = rCount,
                        icon   = rTexture,
                    })
                end

                state.allRecipes[skillName] = {
                    index    = i,
                    itemID   = addon:ItemIDFromLink(itemLink),
                    itemLink = itemLink,
                    icon     = icon,
                    difficulty = skillType,
                    numAvail = numAvail,
                    reagents = reagents,
                }
                table.insert(state.recipeOrder, skillName)
            end
        end
    end

    self:UpdateSkillBar()

    -- Restore UI widgets to match state
    if self.searchBox then self.searchBox:SetText(state.searchText or "") end
    if self.catDropdown then self.catDropdown:SetValue(state.filterCat or "All") end
    if self.diffDropdown then self.diffDropdown:SetValue(state.filterDiff or "All") end
    if self.sortDropdown then
        local arrow = state.sortAsc and " ^" or " v"
        self.sortDropdown:SetValue("Sort: " .. (state.sortBy or "Category") .. arrow, state.sortBy or "Category")
    end
    self:RefreshRecipeList()

    if restored and state.selected then
        -- Verify the saved selection still exists in the recipe list
        local found = false
        for _, r in ipairs(state.recipes) do
            if not r.isHeader and r.name == state.selected then
                found = true
                break
            end
        end
        if found then
            self:UpdateListHighlights()
            self:RefreshDetailPanel()
            self:UpdateCraftBar()
            -- Restore scroll position
            if self.scrollBar then
                self.scrollBar:SetValue(state.scrollOffset or 0)
            end
        else
            state.selected = nil
            self:AutoSelectFirst()
        end
    else
        self:AutoSelectFirst()
    end

    PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    if not (InCombatLockdown() and self.frame:IsShown()) then
        self.frame:Show()
    end

    -- Restore material calc if it was open when we last closed
    if state._restoreCalc then
        state._restoreCalc = false
        if not self.calcPanel then
            self:BuildCalcPanel()
        end
        self:RefreshCalcPanel()
        self.calcPanel:Show()
        self:UpdateCalcBtnState()
    end

    -- Restore bags that were open before the profession window opened.
    -- Use OpenAllBags() rather than individual OpenBag() calls because
    -- all-in-one bag addons (ElvUI, Bagnon, etc.) hook OpenAllBags but
    -- may ignore individual OpenBag calls.
    if self._savedBagState and next(self._savedBagState) then
        self._savedBagState = nil
        C_Timer.After(0.25, function()
            OpenAllBags()
            -- Resume the bag-state tracker
            if self._bagTracker and self._bagTrackerUpdate then
                self._bagTracker:SetScript("OnUpdate", self._bagTrackerUpdate)
            end
        end)
    else
        self._savedBagState = nil
        -- Resume the bag-state tracker
        if self._bagTracker and self._bagTrackerUpdate then
            self._bagTracker:SetScript("OnUpdate", self._bagTrackerUpdate)
        end
    end
end

----------------------------------------------------------------------
-- Open a profession the player doesn't know (static DB only)
-- Shows only missing recipes, no live game data, no skill bar.
----------------------------------------------------------------------
function TSF:OpenWithStatic(profName)
    if not RDB or not RDB.data[profName] then return end

    -- Close the /pb main window if open (mutual exclusion)
    if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() then
        addon.UI:Hide()
    end

    self:EnsureFrame()
    self:RestoreContentPanels()

    state.profName      = profName
    state.skillLevel    = 0
    state.maxSkill      = 0
    state.isCraftWindow = false
    state.allRecipes    = {}
    state.recipeOrder   = {}
    state.selected      = nil
    state.scrollOffset  = 0
    state.showTab       = "missing"
    state.filterCat     = "All"
    state.filterDiff    = "All"
    state.sortBy        = "Category"
    state.sortAsc       = true
    state.searchText    = ""
    state.collapsed     = {}
    state._isStaticView = true
    state._viewCharKey  = nil

    -- Skill bar: show profession name but hide the progress bar
    if self.titleText then self.titleText:SetText(profName) end
    if self.skillBar then
        self.skillBar:SetMinMaxValues(0, 1)
        self.skillBar:SetValue(0)
        self.skillBarText:SetText(profName .. "  -  Not learned")
    end
    self:UpdateProfessionTabs()

    -- Restore UI widgets to defaults
    if self.searchBox then self.searchBox:SetText("") end
    if self.catDropdown then self.catDropdown:SetValue("All") end
    if self.diffDropdown then self.diffDropdown:SetValue("All") end
    if self.sortDropdown then
        self.sortDropdown:SetValue("Sort: Category ^", "Category")
    end
    self:RefreshRecipeList()
    self:AutoSelectFirst()

    PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    if not (InCombatLockdown() and self.frame:IsShown()) then
        self.frame:Show()
    end
end

----------------------------------------------------------------------
-- Open a profession as viewed by a specific alt or friend.
-- Loads their stored data from DataStore and renders it with
-- difficulty colors relative to their skill level.
----------------------------------------------------------------------
function TSF:OpenWithCharacter(charKey, profName)
    if not RDB or not RDB.data[profName] then return end
    if not DS then return end

    local charData = DS:GetCharacter(charKey)
    if not charData then return end
    local profData = charData.professions and charData.professions[profName]
    if not profData then return end

    -- Close the /pb main window if open (mutual exclusion)
    if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() then
        addon.UI:Hide()
    end

    self:EnsureFrame()
    self:RestoreContentPanels()

    local skill = profData.level or profData.skillLevel or 0
    local maxSkill = profData.maxLevel or profData.maxSkill or 375

    state.profName      = profName
    state.skillLevel    = skill
    state.maxSkill      = maxSkill
    state.isCraftWindow = false
    state.allRecipes    = {}
    state.recipeOrder   = {}
    state.selected      = nil
    state.scrollOffset  = 0
    state.showTab       = "known"
    state.filterCat     = "All"
    state.filterDiff    = "All"
    state.sortBy        = "Category"
    state.sortAsc       = true
    state.searchText    = ""
    state.collapsed     = {}
    state._isStaticView = false
    state._viewCharKey  = charKey

    -- Populate known recipes from stored character data
    local staticProf = RDB.data[profName] or {}
    local charBags = charData.inventory and charData.inventory.bags or {}
    local charBank = charData.inventory and charData.inventory.bank or {}

    if profData.recipes then
        for recipeName, recipeInfo in pairs(profData.recipes) do
            local staticEntry = staticProf[recipeName]
            local sr = staticEntry and staticEntry.skillRange or nil
            local diff = DiffFromSkillRange(sr, skill)

            local itemID = staticEntry and staticEntry.itemID or nil
            -- Prefer the character's own scanned icon + link (alts scan
            -- these; a friend's sync carries only recipe names). Fall back
            -- to the static item icon, then a generic icon so item-less
            -- recipes (enchants) never render as broken question marks.
            local itemLink = recipeInfo and recipeInfo.itemLink or nil
            local icon = recipeInfo and recipeInfo.icon or nil
            if not icon and itemID and itemID ~= 0 then
                icon = GetItemIcon(itemID)
            end
            if not icon then
                icon = "Interface\\Icons\\INV_Scroll_03"
            end

            -- Compute craftable count from their inventory
            local reagents = staticEntry and staticEntry.reagents or {}
            local numAvail = 999999
            if #reagents == 0 then
                numAvail = 0
            else
                for _, r in ipairs(reagents) do
                    if r.itemID and r.count and r.count > 0 then
                        local have = (charBags[r.itemID] or 0) + (charBank[r.itemID] or 0)
                        local canMake = math.floor(have / r.count)
                        if canMake < numAvail then numAvail = canMake end
                    else
                        numAvail = 0
                    end
                end
            end
            if numAvail == 999999 then numAvail = 0 end

            state.allRecipes[recipeName] = {
                difficulty  = diff,
                icon        = icon,
                itemID      = itemID,
                itemLink    = itemLink,
                numAvail    = numAvail,
                reagents    = reagents,
                skillReq    = staticEntry and staticEntry.skillReq or nil,
                skillRange  = sr,
                index       = nil, -- no live game index
                isKnown     = true,
            }
            table.insert(state.recipeOrder, recipeName)
        end
        -- Sort recipe order alphabetically for consistent display
        table.sort(state.recipeOrder)
    end

    -- Skill bar: show character name + profession + skill
    local shortName = charKey:match("^([^-]+)") or charKey
    local classColor = addon:ClassColor(charData.class or "WARRIOR")
    if self.skillBar then
        self.skillBar:SetMinMaxValues(0, maxSkill)
        self.skillBar:SetValue(skill)
        self.skillBarText:SetText(classColor .. shortName .. "|r  -  " .. profName .. "  " .. skill .. "/" .. maxSkill)
    end
    self:UpdateProfessionTabs()

    -- Restore UI widgets to defaults
    if self.searchBox then self.searchBox:SetText("") end
    if self.catDropdown then self.catDropdown:SetValue("All") end
    if self.diffDropdown then self.diffDropdown:SetValue("All") end
    if self.sortDropdown then
        self.sortDropdown:SetValue("Sort: Category ^", "Category")
    end
    self:RefreshRecipeList()
    self:AutoSelectFirst()

    PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    if not (InCombatLockdown() and self.frame:IsShown()) then
        self.frame:Show()
    end
end

function TSF:OnTradeSkillShow()
    local profName, rank, maxRank = GetTradeSkillLine()
    if not profName or profName == "UNKNOWN" then return end
    -- TBCCA returns "Mining" from GetTradeSkillLine() when the Smelting
    -- window is open. PB's static DB is registered under "Smelting".
    if profName == "Mining" then profName = "Smelting" end

    -- If already showing this profession, just refresh data in place
    -- without resetting filters/sort/scroll (TRADE_SKILL_UPDATE fires often)
    if self.frame and self.frame:IsShown() and state.profName == profName
       and not state.isCraftWindow then
        self:RefreshTradeData(profName, rank, maxRank, false)
        return
    end

    self:OpenWith(profName, rank, maxRank, false)
end

function TSF:OnCraftShow()
    local profName, rank, maxRank = GetCraftDisplaySkillLine()
    if not profName or profName == "" then profName = "Enchanting" end

    -- If already showing this profession, just refresh data in place
    if self.frame and self.frame:IsShown() and state.profName == profName
       and state.isCraftWindow then
        self:RefreshTradeData(profName, rank or 0, maxRank or 375, true)
        return
    end

    self:OpenWith(profName, rank or 0, maxRank or 375, true)
end

----------------------------------------------------------------------
-- Lightweight data refresh (preserves all UI state)
----------------------------------------------------------------------
function TSF:RefreshTradeData(profName, rank, maxRank, isCraft)
    -- Skip full rebuild while actively crafting to avoid interrupting
    -- the craft queue and resetting the UI mid-sequence
    if self._craftingActive then return end

    state.skillLevel = rank or 0
    state.maxSkill   = maxRank or 375
    state.allRecipes = {}
    state.recipeOrder = {}

    if isCraft then
        local numCrafts = GetNumCrafts()
        for i = 1, numCrafts do
            local craftName, _, craftType = GetCraftInfo(i)
            if craftName and craftType ~= "header" then
                local itemLink = GetCraftItemLink(i)
                local icon = GetCraftIcon(i)
                local reagents = {}
                for j = 1, 12 do
                    local rName, rTexture, rCount = GetCraftReagentInfo(i, j)
                    if not rName then break end
                    local rLink = GetCraftReagentItemLink(i, j)
                    table.insert(reagents, {
                        itemID = addon:ItemIDFromLink(rLink),
                        name   = rName,
                        count  = rCount,
                        icon   = rTexture,
                    })
                end
                state.allRecipes[craftName] = {
                    index    = i,
                    itemID   = addon:ItemIDFromLink(itemLink),
                    itemLink = itemLink,
                    icon     = icon,
                    difficulty = craftType,
                    reagents = reagents,
                }
                table.insert(state.recipeOrder, craftName)
            end
        end
    else
        local numRecipes = GetNumTradeSkills()
        for i = 1, numRecipes do
            local skillName, skillType, numAvail = GetTradeSkillInfo(i)
            if skillName and skillType ~= "header" and skillType ~= "subheader" then
                local itemLink = GetTradeSkillItemLink(i)
                local icon = GetTradeSkillIcon(i)
                local reagents = {}
                for j = 1, 12 do
                    local rName, rTexture, rCount = GetTradeSkillReagentInfo(i, j)
                    if not rName then break end
                    local rLink = GetTradeSkillReagentItemLink(i, j)
                    table.insert(reagents, {
                        itemID = addon:ItemIDFromLink(rLink),
                        name   = rName,
                        count  = rCount,
                        icon   = rTexture,
                    })
                end
                state.allRecipes[skillName] = {
                    index    = i,
                    itemID   = addon:ItemIDFromLink(itemLink),
                    itemLink = itemLink,
                    icon     = icon,
                    difficulty = skillType,
                    numAvail = numAvail,
                    reagents = reagents,
                }
                table.insert(state.recipeOrder, skillName)
            end
        end
    end

    self:UpdateSkillBar()
    self:RefreshRecipeList()
    self:UpdateListHighlights()
    self:RefreshDetailPanel(true)
    self:UpdateCraftBar()
end

-- fromEvent = true when called from the game's TRADE_SKILL_CLOSE /
-- CRAFT_CLOSE handler (the backend is already closed, so OnHide must NOT
-- call CloseTradeSkill again). When called from navigation (nav strip,
-- /pb, manual close), fromEvent is nil/false, so OnHide DOES close the
-- backend -- otherwise it stays open and the action-bar profession
-- button's next cast just toggles it shut instead of reopening PB.
function TSF:Hide(fromEvent)
    -- Save window state for this profession before closing
    self:SaveWindowState()

    self._closingFromEvent = fromEvent and true or false
    PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
    if self.frame then self.frame:Hide() end
    CloseAllDropdowns()
    self._closingFromEvent = false
end

function TSF:Show()
    if self.frame then self.frame:Show() end
end
