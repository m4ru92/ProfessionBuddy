----------------------------------------------------------------------
-- ProfessionBuddy  --  Source/Forever.lua
-- The profession seam for WoW: Forever (1.60.x, Interface 16001).
--
-- Forever has no classic trade-skill, craft or skill-line API. Everything
-- here reads the modern C_TradeSkillUI namespace instead, and answers the
-- same contract Source/Classic.lua answers, so nothing above the seam
-- needs to know which client it runs on. Checked against Blizzard's own
-- `forever` UI source and ForeverProbe runs on the Forever beta.
--
-- Differences from the Classic source that callers see:
--   * a row's index is the recipe ID, which is stable, so the stored
--     index never goes stale when the list is filtered or sorted;
--   * the recipe list arrives after TRADE_SKILL_SHOW, with
--     TRADE_SKILL_LIST_UPDATE (LIST_ARRIVES_LATE);
--   * there is no Craft channel, so every isCraft call answers "none";
--   * Mining is its own profession, with no Smelting skill line;
--   * gathering professions have recipe lists (camp objects).
----------------------------------------------------------------------

local addon  = ProfBuddy
local Source = addon.Source
Source.flavor = "forever"

-- Moved off the global table on this client; see TradeSkillFrame.lua.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local GetItemIcon = GetItemIcon or (C_Item and C_Item.GetItemIconByID)

Source.EVENT = {
    TRADE_SHOW   = "TRADE_SKILL_SHOW",
    TRADE_UPDATE = "TRADE_SKILL_LIST_UPDATE",
    TRADE_CLOSE  = "TRADE_SKILL_CLOSE",
}

Source.DEFAULT_FRAMES = {
    Blizzard_Professions = "ProfessionsFrame",
}
-- ProfessionsFrame is also the profession book the K key opens, so PB
-- gates it instead of killing it: it shows while no profession is open.
Source.SHARED_FRAMES = {
    ProfessionsFrame = true,
}

Source.MINING_IS_SMELTING    = false
Source.LIST_ARRIVES_LATE     = true
Source.GATHERING_HAS_RECIPES = true
-- Crafting through PB's window is the next increment (Phase 2b).
Source.CAN_CRAFT             = false

-- Gathering professions have recipe lists here, so they can be browsed,
-- ordered and synced like any crafting profession. Smelting does not exist.
addon.CRAFTABLE_PROFS["Smelting"]  = nil
addon.CRAFTABLE_PROFS["Mining"]    = true
addon.CRAFTABLE_PROFS["Herbalism"] = true
addon.CRAFTABLE_PROFS["Skinning"]  = true
addon.CRAFTABLE_PROFS["Fishing"]   = true

-- Profession skill lines (SkillLine DB2, build 1.60.1.70009). These are
-- the IDs C_TradeSkillUI.OpenTradeSkill takes. Opening by skill line, not
-- by /cast, because several Forever spells share a profession's name.
local SKILL_LINE = {
    ["Alchemy"]        = 171, ["Blacksmithing"] = 164, ["Cooking"]   = 185,
    ["Enchanting"]     = 333, ["Engineering"]   = 202, ["First Aid"] = 129,
    ["Fishing"]        = 356, ["Herbalism"]     = 182, ["Leatherworking"] = 165,
    ["Mining"]         = 186, ["Skinning"]      = 393, ["Tailoring"] = 197,
}

-- Enum.TradeskillRelativeDifficulty: Optimal 0, Medium 1, Easy 2, Trivial 3.
local DIFFICULTY = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

-- A recipe that cannot give a skill-up is grey, whatever its tier says.
-- This also covers the recipes with no skill-up range at all (the camp
-- abilities and the Adaptive gear), which would otherwise have no colour.
local function Difficulty(info)
    if not info.canSkillUp then return "trivial" end
    return DIFFICULTY[info.relativeDifficulty] or "trivial"
end

local function BasicReagentType()
    local e = Enum and Enum.CraftingReagentType
    return (e and e.Basic) or 1
end

-- The profession the window shows, or nil while the list is still loading.
-- Blizzard's own rank bar uses the same test.
function Source:OpenInfo()
    local T = C_TradeSkillUI
    if not (T and T.IsTradeSkillReady and T.IsTradeSkillReady()) then return nil end
    local info = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    if not info or not info.professionID or info.professionID == 0
       or not info.professionName or info.professionName == "" then
        return nil
    end
    return info
end

-- Is a profession open or opening? The profession is set when
-- TRADE_SKILL_SHOW fires, before its recipe list is ready.
function Source:ProfessionOpen()
    local T = C_TradeSkillUI
    local info = T and T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
    return (info and info.professionID and info.professionID ~= 0) and true or false
end

function Source:SharedFrameOpen()
    return not self:ProfessionOpen()
end

-- Taking over ProfessionsFrame as the profession book, once:
--   * Out of Blizzard's panel manager it has no position (the manager set
--     it), so it goes where the manager would put it.
--   * Every profession tab on its right casts its profession spell each
--     time the frame shows (ProfessionsLargeRightTabMixin, on
--     "ProfessionsFrame.Show"), skipping only the profession the game
--     still reports as loaded. After a profession was open the book would
--     reopen one (the last tab, Cooking) instead of showing, so the book
--     stops doing that; clicking a tab still opens its profession.
--   * K toggles the book, so with a profession open in PB's window it
--     closes that window (onToggle), as it closes Blizzard's.
function Source:AdoptSharedFrame(frame, layout, onToggle)
    if frame:GetNumPoints() == 0 then
        local left = (GetUIPanelLayoutAttribute and GetUIPanelLayoutAttribute("LEFT_OFFSET")) or 16
        local top  = (GetUIPanelLayoutAttribute and GetUIPanelLayoutAttribute("TOP_OFFSET")) or -116
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left + ((layout and layout.xoffset) or 0), top)
    end
    if EventRegistry and EventRegistry.UnregisterCallback then
        for _, tab in ipairs(frame.rightProfessionTabs or {}) do
            EventRegistry:UnregisterCallback("ProfessionsFrame.Show", tab)
        end
    end
    if onToggle and type(ToggleProfessionsBook) == "function" then
        hooksecurefunc("ToggleProfessionsBook", onToggle)
    end
end

-- Always the book page. Once Blizzard_Professions is loaded, Blizzard's
-- ToggleProfessionsBook shows the frame on whatever page it last had,
-- which after any profession window is an empty recipe page.
function Source:BeforeSharedShow(frame)
    if frame.SelectBookPage and frame.BookPage and not frame.BookPage:IsShown() then
        frame:SelectBookPage()
    end
end

-- Primary professions, then archaeology, fishing, cooking and first aid.
-- GetProfessions leaves a nil for every slot the character has not filled.
local function ProfessionLines()
    local rows = {}
    if not (GetProfessions and GetProfessionInfo) then return rows end
    local slots = { GetProfessions() }
    for i = 1, 6 do
        local slot = slots[i]
        if slot then
            local name, _, rank, maxRank = GetProfessionInfo(slot)
            if name then
                rows[#rows + 1] = { name = name, rank = rank, maxRank = maxRank }
            end
        end
    end
    return rows
end

-- There are no skill-line headers to expand here.
function Source:ReadProfessionSkills()
    return ProfessionLines()
end

function Source:ReadVisibleSkillLines()
    local rows = {}
    for _, line in ipairs(ProfessionLines()) do
        rows[#rows + 1] = { name = line.name, isHeader = false, rank = line.rank }
    end
    return rows
end

function Source:GetOpenSkillLine(isCraft)
    if isCraft then return nil end
    local info = self:OpenInfo()
    if not info then return nil end
    return info.professionName, info.skillLevel, info.maxSkillLevel
end

-- A guild member's profession opens the same window and is not ours either.
function Source:IsLinked(isCraft)
    if isCraft then return false end
    local T = C_TradeSkillUI
    if T and T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return true end
    if T and T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return true end
    return false
end

function Source:IsPetTraining() return false end
function Source:CraftCount()    return nil end

-- Required basic reagents from the recipe schematic. Names come from the
-- item cache, which can be empty for an item this session has not seen
-- yet: those are requested and reported as pending so the caller reads
-- the window again once they load.
local function ReadReagents(schematic)
    local reagents, pending = {}, false
    local basic = BasicReagentType()
    for _, slot in ipairs((schematic and schematic.reagentSlotSchematics) or {}) do
        local first = slot.reagents and slot.reagents[1]
        local itemID = first and first.itemID
        if itemID and slot.required and slot.reagentType == basic then
            local name, link = GetItemInfo(itemID)
            if not name then
                pending = true
                if C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(itemID)
                end
            end
            reagents[#reagents + 1] = {
                name  = name or ("item:" .. itemID),
                icon  = GetItemIcon and GetItemIcon(itemID),
                count = slot.quantityRequired,
                link  = link or ("item:" .. itemID),
            }
        end
    end
    return reagents, pending
end

-- Every LEARNED recipe of the open profession, as Classic lists only known
-- recipes. GetAllRecipeIDs ignores the search box and the filters of
-- Blizzard's window, so the list is never partial. A few recipe names
-- belong to two recipe IDs on Forever (an old ID beside its Forever
-- replacement); a character knows one of them, and the first learned one
-- wins, so a name is never listed twice.
function Source:ReadOpenWindow(isCraft)
    local win = { rows = {}, collapsedHeader = false }
    if isCraft or not self:OpenInfo() then return win end

    local T = C_TradeSkillUI
    local categoryName = {}
    local seen = {}
    for _, recipeID in ipairs(T.GetAllRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(recipeID)
        if info and info.learned and not info.isDummyRecipe
           and info.name and not seen[info.name] then
            seen[info.name] = true

            local schematic = T.GetRecipeSchematic(recipeID, false)
            local reagents, pending = ReadReagents(schematic)
            if pending then win.itemsPending = true end

            local catID = info.categoryID
            if catID and categoryName[catID] == nil then
                local cat = T.GetCategoryInfo and T.GetCategoryInfo(catID)
                categoryName[catID] = (cat and cat.name) or false
            end

            local cooldown = T.GetRecipeCooldown and T.GetRecipeCooldown(recipeID)
            local outputID = schematic and schematic.outputItemID
            local itemLink = T.GetRecipeItemLink and T.GetRecipeItemLink(recipeID)
            if not itemLink and outputID and outputID > 0 then
                itemLink = "item:" .. outputID
            end

            win.rows[#win.rows + 1] = {
                name       = info.name,
                index      = recipeID,
                recipeID   = recipeID,
                difficulty = Difficulty(info),
                numAvail   = T.GetCraftableCount and T.GetCraftableCount(recipeID) or 0,
                itemLink   = itemLink,
                recipeLink = (T.GetRecipeLink and T.GetRecipeLink(recipeID)) or ("enchant:" .. recipeID),
                icon       = info.icon,
                cooldown   = (type(cooldown) == "number" and cooldown > 0) and cooldown or nil,
                category   = (catID and categoryName[catID]) or nil,
                reagents   = reagents,
            }
        end
    end
    return win
end

function Source:GetRowState(index, isCraft)
    if isCraft then return nil end
    local T = C_TradeSkillUI
    local info = T.GetRecipeInfo(index)
    if not info then return nil end
    return Difficulty(info), T.GetCraftableCount and T.GetCraftableCount(index) or 0
end

-- Not built yet: CAN_CRAFT is false, so the window never offers a craft.
function Source:Craft()
end

function Source:CloseWindow(isCraft)
    if isCraft then return end
    if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
        C_TradeSkillUI.CloseTradeSkill()
    end
end

function Source:IsSessionOpen(isCraft)
    if isCraft then return false end
    return self:OpenInfo() ~= nil
end

-- The skill line a profession tab opens, or nil for a tab that is not a
-- profession window (Find Minerals).
function Source:TabSkillLine(profName)
    return SKILL_LINE[profName]
end

function Source:OpenProfession(skillLine)
    if skillLine and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        C_TradeSkillUI.OpenTradeSkill(skillLine)
    end
end
