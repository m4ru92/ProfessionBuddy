----------------------------------------------------------------------
-- ProfessionBuddy  --  Knowledge.lua
-- What this account has seen in game, on WoW: Forever.
--
-- ProfBuddyDB.knowledge, shared by every character on the account and
-- keyed by recipe ID (the recipe's spell ID; 67 Forever recipe names
-- belong to two IDs, so a name cannot key it):
--
--   [recipeID] = {
--       learnLevel = 35,   -- the skill a trainer asks for
--       teachers   = { [npcID] = { name, zone, subZone, faction, seen } },
--       vendors    = { [npcID] = { name, zone, subZone, faction, seen,
--                                  itemID, price, stock } },
--       items      = { [itemID] = true },  -- recipe items seen in your bags
--       seenBy     = { [charKey] = true },  -- who saw it; "*" = everyone
--   }
--
-- A recorded learn level beats the one in Data/Forever wherever PB shows
-- a learn level, and the detail panel's Source line names the trainers
-- and vendors. Only the Mainline toc loads this file.
--
-- Recorded from:
--   * trainer windows: every service a profession trainer lists,
--     including the ones far above your skill (moved from ForeverProbe
--     1.9.3, which read these values at 11 Thunder Bluff trainers);
--   * vendor windows: every recipe item a vendor sells;
--   * your bags: every recipe item the bag scan finds.
-- A vendor's or a bag's item is matched to its recipe through the
-- teachItems in Data/Forever.
--
-- What the Missing list shows is the player's choice (Phase 4d), asked the
-- first time a profession opens and changeable in Settings:
--   settings.foreverRecipes      "all"  Show everything: every recipe in
--                                        the data (nil, not asked yet,
--                                        behaves the same)
--                                "seen" Learn as you go: only recipes seen
--                                        at a trainer, a vendor or in bags
--   settings.foreverAltsSeparate with Learn as you go, a character counts
--                                only what it saw itself. Off by default:
--                                everything seen is shared by the account
----------------------------------------------------------------------

local addon = ProfBuddy
local KN = addon:NewModule("Knowledge")

-- Trainer list filters. All three go on for the capture so no service is
-- hidden, then each goes back to what the player had.
local FILTERS = { "available", "unavailable", "used" }
-- ForeverProbe captured one second after the trainer opened.
local CAPTURE_DELAY = 1.0
-- Trainers or vendors named on the Source line before "and N more". The
-- full list is in the Source line's tooltip.
local MAX_NAMES_SHOWN = 2

function KN:Init()
    addon:RegisterEvent("TRADE_SKILL_SHOW", function()
        if addon.db.settings.foreverRecipes == nil then
            -- after PB's window is up, so the question sits over it
            C_Timer.After(0.5, function() self:AskRecipeMode() end)
        end
    end)
    addon:RegisterEvent("TRAINER_SHOW", function() self:OnTrainerShow() end)
    addon:RegisterEvent("TRAINER_CLOSED", function() self._trainerOpen = false end)
    addon:RegisterEvent("MERCHANT_SHOW", function() self:ScanMerchant() end)
    addon:RegisterEvent("MERCHANT_UPDATE", function() self:ScanMerchant() end)

    -- Note recipe items after every bag scan. Wrapped here, not added to
    -- Scanner.lua, because TBC Anniversary does not record them.
    local SC = addon.Scanner
    if SC and SC.ScanInventory then
        local scan = SC.ScanInventory
        SC.ScanInventory = function(sc, ...)
            scan(sc, ...)
            local ok, err = pcall(self.NoteBagItems, self)
            if not ok then
                print("|cff00ccffProfessionBuddy:|r recipe item scan failed: " .. tostring(err))
            end
        end
    end
end

function KN:Get(recipeID)
    local store = recipeID and addon.db and addon.db.knowledge
    return store and store[recipeID] or nil
end

-- The record a recorder writes to, marked as seen by this character. A
-- record from before seenBy existed was the account's, so it keeps
-- counting for every character ("*").
local function Entry(recipeID)
    addon.db.knowledge = addon.db.knowledge or {}
    local store = addon.db.knowledge
    local e = store[recipeID]
    if not e then
        e = { seenBy = {} }
        store[recipeID] = e
    elseif not e.seenBy then
        e.seenBy = { ["*"] = true }
    end
    e.seenBy[addon:PlayerKey()] = true
    return e
end

-- The learn level a trainer showed for this recipe, or nil. A recipe that
-- comes with the profession keeps the data's level, whatever a trainer
-- lists: the Cooking trainer lists Basic Campfire at 20, but it comes with
-- Cooking at 1.
function KN:LearnLevel(recipeID)
    local e = self:Get(recipeID)
    if not (e and e.learnLevel) then return nil end
    local r = addon.RecipeDB and addon.RecipeDB:GetRecipeBySpell(recipeID)
    if r and r.learnFrom == "automatic" then return nil end
    return e.learnLevel
end

-- recipe item ID -> { recipeID, ... }, from the teachItems in
-- Data/Forever. Built on first use, after every data file has loaded.
function KN:TeachIndex()
    if self._teach then return self._teach end
    local index = {}
    local RDB = addon.RecipeDB
    for profName, recipes in pairs(RDB and RDB.data or {}) do
        if not addon.CLASS_PROFS[profName] then
            for _, r in pairs(recipes) do
                for _, itemID in ipairs(r.teachItems or {}) do
                    index[itemID] = index[itemID] or {}
                    table.insert(index[itemID], r.spellID)
                end
            end
        end
    end
    self._teach = index
    return index
end

-- The NPC the player is talking to, or nil.
local function CurrentNpc()
    local name = UnitName("npc")
    local guid = UnitGUID("npc")
    local npcID = guid and tonumber((select(6, strsplit("-", guid))))
    local key = npcID or name
    if not key then return nil end
    return key, { name = name, zone = GetRealZoneText(), subZone = GetSubZoneText(),
                  faction = UnitFactionGroup("npc"), seen = time() }
end

local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

----------------------------------------------------------------------
-- Display
----------------------------------------------------------------------

local function ForFaction(npc, faction)
    return not faction or not npc.faction or npc.faction == faction or npc.faction == "Neutral"
end

-- The NPCs of `faction` (plus neutral ones) in a teachers or vendors
-- table, the current zone first, then the most recently seen.
local function Sorted(list, faction)
    local out = {}
    for _, npc in pairs(list or {}) do
        if ForFaction(npc, faction) then out[#out + 1] = npc end
    end
    local here = GetRealZoneText()
    table.sort(out, function(a, b)
        local ah, bh = a.zone == here, b.zone == here
        if ah ~= bh then return ah end
        if (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

local function Label(npc)
    local label = npc.name or "?"
    if npc.zone and npc.zone ~= "" then label = label .. " (" .. npc.zone .. ")" end
    return label
end

-- "Mak (Thunder Bluff), Vhan (Thunder Bluff), and 3 more", or nil.
local function Names(list, faction)
    local npcs = Sorted(list, faction)
    if #npcs == 0 then return nil end
    local names = {}
    for i = 1, math.min(#npcs, MAX_NAMES_SHOWN) do names[i] = Label(npcs[i]) end
    local more = #npcs - MAX_NAMES_SHOWN
    if more > 0 then names[#names + 1] = "and " .. more .. " more" end
    return table.concat(names, ", ")
end

-- The recipe's sources as the Source line shows them: what this account
-- has seen first, then the data's own. Seen trainers fill in the data's
-- trainer source; a seen vendor stands in for the data's recipe item
-- ("Undetermined - Pattern: X"), and an item seen in your bags relabels
-- it "Recipe item". With faction, the other faction's NPCs are left out.
-- Returns the data's sources untouched when nothing was seen.
function KN:MergeSources(sources, recipeID, faction)
    local e = self:Get(recipeID)
    if not e then return sources end
    local trainers = Names(e.teachers, faction)
    local vendors = Names(e.vendors, faction)
    local inBags = e.items and next(e.items) ~= nil
    if not (trainers or vendors or inBags) then return sources end
    local out = {}
    if trainers then out[#out + 1] = { method = "trainer", detail = trainers } end
    if vendors then out[#out + 1] = { method = "vendor", detail = vendors } end
    for _, s in ipairs(sources or {}) do
        if s.method == "trainer" then
            if not trainers then out[#out + 1] = s end
        elseif s.method == "undetermined" and (vendors or inBags) then
            if not vendors then
                out[#out + 1] = { method = "undetermined", label = "Recipe item", detail = s.detail }
            end
        else
            out[#out + 1] = s
        end
    end
    return out
end

local function Money(copper)
    if not copper or copper <= 0 then return nil end
    if GetMoneyString then return GetMoneyString(copper) end
    return copper .. "c"
end

-- Every trainer and vendor seen for this recipe, one per line, for the
-- Source line's tooltip. nil when nothing was seen.
function KN:TooltipLines(recipeID, faction)
    local e = self:Get(recipeID)
    if not e then return nil end
    local lines = {}
    local function place(npc)
        local where = npc.zone or ""
        if npc.subZone and npc.subZone ~= "" then where = where .. ", " .. npc.subZone end
        return (npc.name or "?") .. (where ~= "" and (" - " .. where) or "")
    end
    local trainers = Sorted(e.teachers, faction)
    if #trainers > 0 then
        lines[#lines + 1] = "|cff00ff00Trainers|r"
        for _, npc in ipairs(trainers) do lines[#lines + 1] = "  " .. place(npc) end
    end
    local vendors = Sorted(e.vendors, faction)
    if #vendors > 0 then
        lines[#lines + 1] = "|cffffff00Vendors|r"
        for _, npc in ipairs(vendors) do
            local price = Money(npc.price)
            lines[#lines + 1] = "  " .. place(npc) .. (price and ("  " .. price) or "")
        end
    end
    if e.items and next(e.items) then
        lines[#lines + 1] = "|cff888888Recipe item seen in your bags|r"
    end
    if #lines == 0 then return nil end
    return lines
end

----------------------------------------------------------------------
-- Show everything or Learn as you go
----------------------------------------------------------------------

function KN:LearnAsYouGo()
    local st = addon.db and addon.db.settings
    return (st and st.foreverRecipes == "seen") or false
end

-- Has this recipe been seen at a trainer, a vendor or in the bags: by any
-- character, or with alts kept separate by `charKey` itself?
function KN:Seen(recipeID, charKey)
    local e = self:Get(recipeID)
    if not e then return false end
    if not addon.db.settings.foreverAltsSeparate then return true end
    local by = e.seenBy
    return not by or by["*"] or (charKey and by[charKey]) or false
end

-- The unknown recipes the Missing list shows: all of them, or with Learn
-- as you go the ones seen. `unknown` is keyed by recipe name.
function KN:FilterUnknown(unknown, charKey)
    if not self:LearnAsYouGo() then return unknown end
    charKey = charKey or addon:PlayerKey()
    local out = {}
    for name, info in pairs(unknown) do
        if info.spellID and self:Seen(info.spellID, charKey) then out[name] = info end
    end
    return out
end

function KN:SetRecipeMode(mode)
    addon.db.settings.foreverRecipes = mode
    local tsf = addon.TradeSkillFrame
    if tsf and tsf.UpdateForeverSettings then tsf:UpdateForeverSettings() end
    if tsf and tsf.scrollBar then tsf:RefreshRecipeList() end
end

local PROMPT = "PROFBUDDY_FOREVER_RECIPES"

-- Asked once a session until the player picks. Escape leaves it unpicked
-- (Show everything meanwhile) and it asks again next session.
function KN:AskRecipeMode()
    if self._asked or addon.db.settings.foreverRecipes ~= nil then return end
    self._asked = true
    if not StaticPopupDialogs[PROMPT] then
        StaticPopupDialogs[PROMPT] = {
            text = "How should ProfessionBuddy show recipes you haven't learned?\n\n"
                .. "Show everything: every recipe in the game. PB adds trainers, "
                .. "vendors and learn levels as you play.\n\n"
                .. "Learn as you go: only recipes you've found at a trainer, a vendor, "
                .. "or as a recipe item in your bags. The list grows as you explore.\n\n"
                .. "You can change this later in Settings.",
            button1 = "Show everything",
            button2 = "Learn as you go",
            OnAccept = function() KN:SetRecipeMode("all") end,
            OnCancel = function() KN:SetRecipeMode("seen") end,
            OnEscape = function() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show(PROMPT)
end

----------------------------------------------------------------------
-- Trainer scan
----------------------------------------------------------------------

-- One trainer service, in Forever's return orders (Blizzard_TrainerUI,
-- `forever` branch):
--   GetTrainerServiceInfo     name, type, texture, reqLevel, subText, category
--   GetTrainerServiceSkillReq skill, rank, hasReq
-- The recipe ID comes from the service's tooltip data.
local function ReadService(i)
    local _, rank = GetTrainerServiceSkillReq(i)
    local id
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, data = pcall(C_TooltipInfo.GetTrainerService, i)
        if ok and type(data) == "table" and type(data.id) == "number" then id = data.id end
    end
    return id, tonumber(rank)
end

-- Record every recipe the open trainer lists. Returns how many.
function KN:CaptureTrainer()
    local n = GetNumTrainerServices() or 0
    local RDB = addon.RecipeDB
    if n == 0 or not (RDB and addon.db) then return 0 end
    local key, npc = CurrentNpc()
    if not key then return 0 end
    local recorded = 0
    for i = 1, n do
        local id, rank = ReadService(i)
        -- Only a recipe PB has data for: a trainer also lists profession
        -- ranks ("Journeyman Tailoring") and, on a class trainer, spells.
        local ref = id and RDB.spellToRecipe[id]
        if ref and not addon.CLASS_PROFS[ref.profName] then
            local e = Entry(id)
            if rank and rank > 0 then e.learnLevel = rank end
            e.teachers = e.teachers or {}
            e.teachers[key] = Copy(npc)
            recorded = recorded + 1
        end
    end
    return recorded
end

-- Capture a second after a profession trainer opens. Class, weapon and
-- pet trainers are skipped. A window the player already closed is left
-- alone: switching its filters can make it open again.
function KN:OnTrainerShow()
    if IsTradeskillTrainer and not IsTradeskillTrainer() then return end
    self._trainerOpen = true
    C_Timer.After(CAPTURE_DELAY, function()
        if not self._trainerOpen then return end
        if ClassTrainerFrame and not ClassTrainerFrame:IsShown() then return end
        self:ScanTrainer()
    end)
end

-- Show every service (all three filters on), capture, then put each filter
-- back. The game refilters the list the moment a filter changes (m4ru
-- checked 2026-09-27: 15 services, then 17 with "used" on), so all of this
-- runs in one frame and the trainer window never shows the change.
function KN:ScanTrainer()
    local prev = {}
    if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
        for _, f in ipairs(FILTERS) do
            prev[f] = GetTrainerServiceTypeFilter(f) and true or false
            if not prev[f] then SetTrainerServiceTypeFilter(f, true) end
        end
    end
    local ok, err = pcall(self.CaptureTrainer, self)
    if SetTrainerServiceTypeFilter then
        for f, was in pairs(prev) do
            if not was then SetTrainerServiceTypeFilter(f, false) end
        end
    end
    if not ok then
        print("|cff00ccffProfessionBuddy:|r trainer scan failed: " .. tostring(err))
    end
end

----------------------------------------------------------------------
-- Vendor scan
----------------------------------------------------------------------

-- Record every recipe item the open vendor sells: the vendor, where, the
-- price and the stock. Returns how many recipes. Reads the list as the
-- vendor window shows it.
function KN:ScanMerchant()
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    if n == 0 or not addon.db then return 0 end
    local key, npc = CurrentNpc()
    if not key then return 0 end
    local index = self:TeachIndex()
    local recorded = 0
    for i = 1, n do
        local itemID = GetMerchantItemID(i)
        local recipes = itemID and index[itemID]
        if recipes then
            local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo
                and C_MerchantFrame.GetItemInfo(i)
            for _, id in ipairs(recipes) do
                local e = Entry(id)
                e.vendors = e.vendors or {}
                local v = Copy(npc)
                v.itemID = itemID
                v.price = info and info.price
                v.stock = info and info.numAvailable
                e.vendors[key] = v
                recorded = recorded + 1
            end
        end
    end
    return recorded
end

----------------------------------------------------------------------
-- Recipe items in your bags
----------------------------------------------------------------------

-- Note every recipe item in the bags the Scanner just stored. Returns how
-- many recipes.
function KN:NoteBagItems()
    local char = addon.DataStore and addon.DataStore:GetCharacter(addon:PlayerKey())
    local bags = char and char.inventory and char.inventory.bags
    if not bags then return 0 end
    local index = self:TeachIndex()
    local noted = 0
    for itemID in pairs(bags) do
        for _, id in ipairs(index[itemID] or {}) do
            local e = Entry(id)
            e.items = e.items or {}
            e.items[itemID] = true
            noted = noted + 1
        end
    end
    return noted
end
