----------------------------------------------------------------------
-- ProfessionBuddy  --  Source/Classic.lua
-- The profession seam for TBC Classic Anniversary (2.5.x).
--
-- Every function here is code MOVED out of Scanner.lua and
-- UI/TradeSkillFrame.lua, not rewritten. The call order against the game
-- API is preserved, and so are the quirks the originals documented:
--   * GetNumTradeSkillReagents is gone on the modern client, so reagents
--     are read j = 1..12 until the first nil.
--   * The skill list only enumerates DISPLAYED rows, so the login scan
--     expands every header first and re-collapses the user's by NAME.
--   * GetTradeSkillInfo returns count and tier 2nd and 3rd; GetCraftInfo
--     returns them 3rd and 4th.
-- Globals are read at call time, never cached, so a client (or a test)
-- that replaces one is always seen.
----------------------------------------------------------------------

local Source = ProfBuddy.Source
Source.flavor = "classic"

Source.EVENT = {
    TRADE_SHOW   = "TRADE_SKILL_SHOW",
    TRADE_UPDATE = "TRADE_SKILL_UPDATE",
    TRADE_CLOSE  = "TRADE_SKILL_CLOSE",
    CRAFT_SHOW   = "CRAFT_SHOW",
    CRAFT_UPDATE = "CRAFT_UPDATE",
    CRAFT_CLOSE  = "CRAFT_CLOSE",
}

Source.DEFAULT_FRAMES = {
    Blizzard_TradeSkillUI = "TradeSkillFrame",
    Blizzard_CraftUI      = "CraftFrame",
}

-- Moved from Scanner:ScanProfessions. GetSkillLineInfo only enumerates the
-- rows the skill list is currently showing, so a collapsed "Professions"
-- header hides the professions underneath it. Expand everything, read,
-- then put the user's headers back the way they were. Indices shift on
-- every expand and collapse, so the restore matches on NAME and walks
-- backwards. (Scanner mutes its own SKILL_LINES_CHANGED handler around
-- this call; that stays in Scanner.)
function Source:ReadProfessionSkills()
    local rows = {}

    local canExpand = ExpandSkillHeader and CollapseSkillHeader
    local wasCollapsed
    if canExpand then
        wasCollapsed = {}
        for i = 1, GetNumSkillLines() do
            local name, isHeader, isExpanded = GetSkillLineInfo(i)
            if isHeader and name and not isExpanded then
                wasCollapsed[name] = true
            end
        end
        ExpandSkillHeader(0)
    end

    -- Guarded: a client without the skill-line API degrades to "no
    -- professions found" instead of a hard error.
    local numSkills = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, numSkills do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if not isHeader and name then
            rows[#rows + 1] = { name = name, rank = rank, maxRank = maxRank }
        end
    end

    if canExpand and next(wasCollapsed) then
        for i = GetNumSkillLines(), 1, -1 do
            local name, isHeader = GetSkillLineInfo(i)
            if isHeader and name and wasCollapsed[name] then
                CollapseSkillHeader(i)
            end
        end
    end

    return rows
end

-- Moved from TradeSkillFrame's PlayerGatherSkill: the displayed rows only,
-- no expanding (that lookup is a cheap live read, and a miss falls back to
-- DataStore).
function Source:ReadVisibleSkillLines()
    local rows = {}
    if GetNumSkillLines then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            rows[#rows + 1] = { name = name, isHeader = isHeader, rank = rank }
        end
    end
    return rows
end

function Source:GetOpenSkillLine(isCraft)
    if isCraft then
        return GetCraftDisplaySkillLine()
    end
    return GetTradeSkillLine()
end

-- A chat-linked view of somebody else's profession drives the same window
-- and the same APIs. Nothing in it is craftable, and it must never be
-- written to the local character.
function Source:IsLinked(isCraft)
    if isCraft then
        return (IsCraftLinked and IsCraftLinked()) and true or false
    end
    return (IsTradeSkillLinked and IsTradeSkillLinked()) and true or false
end

-- The Craft API backs hunter pet training as well as Enchanting, and
-- CRAFT_SHOW fires for both.
function Source:IsPetTraining()
    return (CraftIsPetTraining and CraftIsPetTraining()) and true or false
end

-- nil (not 0) when the client has no Craft API, so callers that guarded
-- on the function existing keep exactly the same truthiness.
function Source:CraftCount()
    if not GetNumCrafts then return nil end
    return GetNumCrafts()
end

-- The recipe loop Scanner and TradeSkillFrame each carried their own copy
-- of. Header rows are excluded with the same tests both copies used:
-- tradeskill drops "header" and "subheader", the Craft API only "header".
-- `collapsedHeader` reports a tradeskill header whose rows are hidden, so
-- Scanner can refuse to persist a partial list.
function Source:ReadOpenWindow(isCraft)
    local win = { rows = {}, collapsedHeader = false }

    if isCraft then
        for i = 1, GetNumCrafts() do
            local craftName, _, craftType, numAvail = GetCraftInfo(i)
            if craftName and craftType ~= "header" then
                local reagents = {}
                for j = 1, 12 do
                    local rName, rTexture, rCount = GetCraftReagentInfo(i, j)
                    if not rName then break end
                    reagents[#reagents + 1] = {
                        name  = rName,
                        icon  = rTexture,
                        count = rCount,
                        link  = GetCraftReagentItemLink(i, j),
                    }
                end
                local recipeLink = GetCraftRecipeLink and GetCraftRecipeLink(i)
                win.rows[#win.rows + 1] = {
                    name       = craftName,
                    index      = i,
                    difficulty = craftType,
                    numAvail   = numAvail,
                    itemLink   = GetCraftItemLink(i),
                    recipeLink = recipeLink,
                    icon       = GetCraftIcon(i),
                    reagents   = reagents,
                }
            end
        end
        return win
    end

    win.nameFilter = GetTradeSkillItemNameFilter and GetTradeSkillItemNameFilter()

    for i = 1, GetNumTradeSkills() do
        local skillName, skillType, numAvail, isExpanded = GetTradeSkillInfo(i)

        if (skillType == "header" or skillType == "subheader") and isExpanded == false then
            win.collapsedHeader = true
        end

        if skillName and skillType ~= "header" and skillType ~= "subheader" then
            local reagents = {}
            for j = 1, 12 do
                local rName, rTexture, rCount = GetTradeSkillReagentInfo(i, j)
                if not rName then break end
                reagents[#reagents + 1] = {
                    name  = rName,
                    icon  = rTexture,
                    count = rCount,
                    link  = GetTradeSkillReagentItemLink(i, j),
                }
            end
            local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
            local cooldown   = GetTradeSkillCooldown and GetTradeSkillCooldown(i)
            win.rows[#win.rows + 1] = {
                name       = skillName,
                index      = i,
                difficulty = skillType,
                numAvail   = numAvail,
                itemLink   = GetTradeSkillItemLink(i),
                recipeLink = recipeLink,
                icon       = GetTradeSkillIcon(i),
                cooldown   = cooldown,
                reagents   = reagents,
            }
        end
    end

    return win
end

-- Moved from TradeSkillFrame:UpdateCraftableCounts: the live tier and count
-- of one row, for the cheap mid-batch refresh.
function Source:GetRowState(index, isCraft)
    if isCraft then
        return select(3, GetCraftInfo(index))
    end
    return select(2, GetTradeSkillInfo(index))
end

-- The Craft API takes no quantity: DoCraft casts once. TradeSkillFrame
-- already forces qty to 1 for the craft window; qty is ignored here.
function Source:Craft(index, qty, isCraft)
    if isCraft then
        DoCraft(index)
    else
        DoTradeSkill(index, qty)
    end
end

function Source:CloseWindow(isCraft)
    if isCraft then
        CloseCraft()
    else
        CloseTradeSkill()
    end
end

-- The trade-skill session (Tailoring, Blacksmithing...) and the Craft
-- session (Enchanting) are independent: opening one does NOT close the
-- other, so both can be live at once with only one of them on screen.
-- Measured with /pbt windows: after TRADE_SKILL_CLOSE, GetNumTradeSkills()
-- still reports the old count and only the skill-line name flips to
-- "UNKNOWN", so the NAME is the open test. For the Craft API, PB already
-- treats GetNumCrafts() == 0 as "no session" (OnCraftShow).
function Source:IsSessionOpen(isCraft)
    if isCraft then
        return ((GetNumCrafts and GetNumCrafts()) or 0) > 0
    end
    local name = GetTradeSkillLine and GetTradeSkillLine()
    return name ~= nil and name ~= "" and name ~= "UNKNOWN"
end
