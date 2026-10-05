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
--       at         = time(),                -- last written, for sharing
--   }
--
-- ProfBuddyDB.knowledgeShared holds what friends and guildmates shared
-- (Phase 4e; Comm.lua carries it), one table per peer, never merged into
-- your own records:
--   [peerKey] = { at = last exchange, since = newest record they sent,
--                 records = { [recipeID] = { at, learnLevel, teachers,
--                                            vendors, items } } }
-- Reads merge it in: your own learn level wins, else the most recent a
-- peer saw; trainers and vendors are yours plus theirs; a peer's sighting
-- counts as seen for Learn as you go.
--
-- ProfBuddyDB.skinLoot holds what this account's skinning yielded (Phase
-- 3b-3), keyed by the skinned mob's NPC ID:
--   [npcID] = { n = skins, at = time(), seenBy = { [charKey] = true },
--               items = { [itemID] = { c = skins it dropped in, min, max,
--                                      name, q = quality } } }
-- Peers share theirs (knowledgeShared[peer].loot, the same shape without
-- name, q and seenBy). Once a mob has LEARNED_MIN skins, yours and peers'
-- together, the gather tooltip lists those drops instead of the Classic
-- list (TradeSkillFrame.lua AddSkinLoot).
--
-- ProfBuddyDB.nodeLoot holds the same for ore veins and herbs (Phase
-- 3b-4), keyed by node name (the loot window names no node, and one name
-- covers several game objects), with prof = "Mining" | "Herbalism".
-- Peers share theirs as knowledgeShared[peer].nodeLoot.
--
-- ProfBuddyDB.gatheredMobs[npcID] = "Mining" | "Herbalism" | "Engineering":
-- a mob this account gathered from with one of Forever's corpse gathering
-- spells other than Skinning. Local only.
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
-- Skins of one mob, yours and peers' together, before what they yielded
-- replaces the Classic list on its tooltip (m4ru's decision C, 2026-10-02).
local LEARNED_MIN = 10
-- WoW: Forever's gathering-from-a-corpse spells: every SPELL_EFFECT_SKINNING
-- (95) spell in Forever's own SpellEffect, with its skill line from
-- SkillLineAbility (wago.tools, build 1.60.1.70205). Skinning (393) has
-- four; Mining (186), Herb Gathering (182) and Engineering (202) one each,
-- new on Forever (effect misc value 2 rock, 1 herb, 3 bolts).
local GATHER_SPELLS = {
    [8613] = "Skinning", [8617] = "Skinning", [8618] = "Skinning", [10768] = "Skinning",
    [1235230] = "Mining", [1235236] = "Herbalism", [1235244] = "Engineering",
}
-- Opening an ore vein or an herb: every SPELL_EFFECT_OPEN_LOCK (33) spell
-- named Mining (lock type 3, skill line 186) or Herbalism (lock type 2,
-- skill line 182) in the same Forever tables.
local NODE_SPELLS = {
    [2575] = "Mining", [2576] = "Mining", [2577] = "Mining", [2578] = "Mining",
    [2579] = "Mining", [3564] = "Mining", [10248] = "Mining",
    [2366] = "Herbalism", [2368] = "Herbalism", [2369] = "Herbalism",
    [2371] = "Herbalism", [3570] = "Herbalism", [11993] = "Herbalism",
}
-- How recent the node tooltip PB last drew (lastGather) must be to name
-- the node a cast opens, when the tooltip is no longer showing it.
local NODE_NAME_AGE = 10
-- A loot window this long after a Skinning cast succeeds is its loot; so
-- is one that opens while the cast is still under way (no later than
-- SKIN_CAST_MAX after it started), in case the loot event comes first.
local SKIN_LOOT_WINDOW = 3
local SKIN_CAST_MAX = 5

function KN:Init()
    self:PrunePeers()
    addon:RegisterEvent("TRADE_SKILL_SHOW", function()
        if addon.db.settings.foreverRecipes == nil then
            -- after PB's window is up, so the question sits over it
            C_Timer.After(0.5, function() self:AskRecipeMode() end)
        end
    end)
    addon:RegisterEvent("TRAINER_SHOW", function() self:OnTrainerShow() end)
    addon:RegisterEvent("TRAINER_CLOSED", function() self._trainerOpen = false end)
    addon:RegisterEvent("MERCHANT_SHOW", function() self:ScanMerchant() end)
    addon:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit, _, spellID)
        if unit == "player" then self:OnSkinCast("start", spellID) end
    end)
    addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
        if unit == "player" then self:OnSkinCast("done", spellID) end
    end)
    for _, ev in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        addon:RegisterEvent(ev, function(_, unit, _, spellID)
            if unit == "player" then self:OnSkinCast("stop", spellID) end
        end)
    end
    addon:RegisterEvent("LOOT_OPENED", function()
        local ok, err = pcall(self.OnLootOpened, self)
        if not ok then
            print("|cff00ccffProfessionBuddy:|r skinning loot record failed: " .. tostring(err))
        end
    end)
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
    e.at = time()
    return e
end

-- The learn level a trainer showed for this recipe, or nil. A recipe that
-- comes with the profession keeps the data's level, whatever a trainer
-- lists: the Cooking trainer lists Basic Campfire at 20, but it comes with
-- Cooking at 1.
-- With no sighting of your own, the most recent one a peer shared.
function KN:LearnLevel(recipeID)
    if not recipeID then return nil end
    local r = addon.RecipeDB and addon.RecipeDB:GetRecipeBySpell(recipeID)
    if r and r.learnFrom == "automatic" then return nil end
    local e = self:Get(recipeID)
    if e and e.learnLevel then return e.learnLevel end
    local best, bestAt
    for _, shared in pairs(addon.db and addon.db.knowledgeShared or {}) do
        local p = shared.records and shared.records[recipeID]
        if p and p.learnLevel and (not bestAt or (p.at or 0) > bestAt) then
            best, bestAt = p.learnLevel, p.at or 0
        end
    end
    return best
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

-- Your own trainers or vendors (`field` "teachers" or "vendors") for this
-- recipe plus every peer's, one per NPC, yours kept where both have one. A
-- peer's copy carries `from`, the peer's name; when several peers saw the
-- same NPC, the one with the most recent record is credited. nil when
-- there are none.
local function Combined(recipeID, field)
    local own = KN:Get(recipeID)
    local out, any = {}, false
    for k, v in pairs(own and own[field] or {}) do out[k] = v; any = true end
    for peer, shared in pairs(addon.db.knowledgeShared or {}) do
        local p = shared.records and shared.records[recipeID]
        for k, v in pairs(p and p[field] or {}) do
            local have = out[k]
            local at = p.at or 0
            if have == nil or (have.from and (at > have._at
                    or (at == have._at and addon:ShortName(peer) < have.from))) then
                local c = Copy(v)
                c.from, c._at = addon:ShortName(peer), at
                out[k] = c
                any = true
            end
        end
    end
    return any and out or nil
end

-- The peers who shared seeing this recipe's item in their bags.
local function PeerItems(recipeID)
    local names
    for peer, shared in pairs(addon.db.knowledgeShared or {}) do
        local p = shared.records and shared.records[recipeID]
        if p and p.items then
            names = names or {}
            names[#names + 1] = addon:ShortName(peer)
        end
    end
    if names then table.sort(names) end
    return names
end

-- The recipe's sources as the Source line shows them: what this account
-- and its peers have seen first, then the data's own. Seen trainers fill in the data's
-- trainer source; a seen vendor stands in for the data's recipe item
-- ("Undetermined - Pattern: X"), and an item seen in your bags relabels
-- it "Recipe item". With faction, the other faction's NPCs are left out.
-- Returns the data's sources untouched when nothing was seen.
function KN:MergeSources(sources, recipeID, faction)
    local e = self:Get(recipeID)
    local trainers = Names(Combined(recipeID, "teachers"), faction)
    local vendors = Names(Combined(recipeID, "vendors"), faction)
    local inBags = (e and e.items and next(e.items) ~= nil) or PeerItems(recipeID) ~= nil
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
    local lines = {}
    local function place(npc)
        local where = npc.zone or ""
        if npc.subZone and npc.subZone ~= "" then where = where .. ", " .. npc.subZone end
        local from = npc.from and ("  |cff888888(from " .. npc.from .. ")|r") or ""
        return (npc.name or "?") .. (where ~= "" and (" - " .. where) or "") .. from
    end
    local trainers = Sorted(Combined(recipeID, "teachers"), faction)
    if #trainers > 0 then
        lines[#lines + 1] = "|cff00ff00Trainers|r"
        for _, npc in ipairs(trainers) do lines[#lines + 1] = "  " .. place(npc) end
    end
    local vendors = Sorted(Combined(recipeID, "vendors"), faction)
    if #vendors > 0 then
        lines[#lines + 1] = "|cffffff00Vendors|r"
        for _, npc in ipairs(vendors) do
            local price = Money(npc.price)
            lines[#lines + 1] = "  " .. place(npc) .. (price and ("  " .. price) or "")
        end
    end
    if e and e.items and next(e.items) then
        lines[#lines + 1] = "|cff888888Recipe item seen in your bags|r"
    end
    local peers = PeerItems(recipeID)
    if peers then
        lines[#lines + 1] = "|cff888888Recipe item seen by " .. table.concat(peers, ", ") .. "|r"
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
-- A peer's sighting counts for every one of your characters.
function KN:Seen(recipeID, charKey)
    local e = self:Get(recipeID)
    if e then
        if not addon.db.settings.foreverAltsSeparate then return true end
        local by = e.seenBy
        if not by or by["*"] or (charKey and by[charKey]) then return true end
    end
    for _, shared in pairs(addon.db.knowledgeShared or {}) do
        if shared.records and shared.records[recipeID] then return true end
    end
    return false
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
-- Skinning loot learned as you skin (Phase 3b-3)
----------------------------------------------------------------------

-- WoW: Forever hands addons some values as secrets (in a dungeon, the
-- mob's GUID); comparing or parsing one is a Lua error.
local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function NpcIDOf(guid)
    if type(guid) ~= "string" or IsSecret(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

-- A Skinning cast: at its start the corpse is still under the cursor
-- (the fallback when the game cannot name a loot slot's source); when it
-- succeeds, the next loot window is the skin's.
-- The node a Mining or Herbalism cast is opening: the name on the game
-- tooltip under the cursor (out of combat; in combat it is secret), else
-- the node PB drew its lines on moments ago. nil when neither is a node
-- PB knows for that profession.
local function NodeUnderCursor(prof)
    local known = (prof == "Mining") and addon.MiningNodes or addon.HerbNodes
    if not known then return nil end
    local fs = GameTooltip and GameTooltip:IsShown() and _G.GameTooltipTextLeft1
    local name = fs and fs:GetText()
    if type(name) == "string" and not IsSecret(name) and known[name] then return name end
    local g = addon.db and addon.db.lastGather
    if g and g.kind == "node" and known[g.name] and g.seen and (time() - g.seen) <= NODE_NAME_AGE then
        return g.name
    end
    return nil
end

function KN:OnSkinCast(phase, spellID)
    if IsSecret(spellID) then return end
    local nodeProf = NODE_SPELLS[spellID]
    if not (GATHER_SPELLS[spellID] or nodeProf) then return end
    if phase == "start" then
        local guid = UnitGUID("mouseover")
        self._skinGUID = (UnitIsDead("mouseover") and not IsSecret(guid)) and guid or nil
        self._skinStart = GetTime()
        self._skinProf = GATHER_SPELLS[spellID] or nodeProf
        self._skinNode = nodeProf and NodeUnderCursor(nodeProf) or nil
        self._skinIsNode = nodeProf and true or nil
    elseif phase == "done" then
        -- its loot window already came, while the cast was under way
        local used = self._skinUsed
        self._skinUsed, self._skinStart = nil, nil
        if used and (GetTime() - used) <= SKIN_CAST_MAX then return end
        self._skinDone = GetTime()
    else
        self._skinStart, self._skinGUID, self._skinNode, self._skinIsNode = nil, nil, nil, nil
    end
end

-- The NPC ID the loot window's items came from: the game's own answer for
-- the first item slot, else the corpse the cast started on.
local function LootSource(slots)
    if GetLootSourceInfo then
        for _, slot in ipairs(slots) do
            local id = NpcIDOf((GetLootSourceInfo(slot)))
            if id then return id end
        end
    end
    return NpcIDOf(KN._skinGUID)
end

function KN:OnLootOpened()
    local now, done, start = GetTime(), self._skinDone, self._skinStart
    local afterCast = done and (now - done) <= SKIN_LOOT_WINDOW
    local duringCast = start and (now - start) <= SKIN_CAST_MAX
    if not (afterCast or duringCast) then return end
    if not afterCast then self._skinUsed = now end
    self._skinDone, self._skinStart = nil, nil
    local items, slots = {}, {}
    for slot = 1, (GetNumLootItems() or 0) do
        local link = GetLootSlotLink(slot)
        if type(link) == "string" and not IsSecret(link) then
            local itemID = tonumber(link:match("item:(%d+)"))
            local _, name, qty, _, quality = GetLootSlotInfo(slot)
            if IsSecret(name) then name = nil end
            if IsSecret(qty) then qty = nil end
            if IsSecret(quality) then quality = nil end
            if itemID then
                items[#items + 1] = { itemID, tonumber(qty) or 1, name, quality }
                slots[#slots + 1] = slot
            end
        end
    end
    local prof, node = self._skinProf or "Skinning", self._skinNode
    self._skinProf, self._skinNode = nil, nil
    if node then
        self._skinGUID, self._skinIsNode = nil, nil
        if #items > 0 then self:RecordNode(node, prof, items) end
        return
    end
    if self._skinIsNode then
        -- a node PB could not name (in combat, or one it does not know)
        self._skinIsNode, self._skinGUID = nil, nil
        return
    end
    local npcID = LootSource(slots)
    self._skinGUID = nil
    if not npcID then return end
    if prof == "Skinning" then
        if #items > 0 then self:RecordSkin(npcID, items) end
    else
        -- a mob you mined, gathered herbs from or salvaged: remembered so
        -- its live tooltip names that profession (no list has these mobs)
        addon.db.gatheredMobs = addon.db.gatheredMobs or {}
        addon.db.gatheredMobs[npcID] = prof
    end
end

-- One gather from `key` in the store addon.db[storeName] that yielded
-- `items`: { { itemID, quantity, name, quality }, ... }. An item in two
-- slots counts once, with both stacks.
local function RecordLoot(storeName, key, items)
    addon.db[storeName] = addon.db[storeName] or {}
    local rec = addon.db[storeName][key]
    if not rec then
        rec = { n = 0, items = {}, seenBy = {} }
        addon.db[storeName][key] = rec
    end
    local got = {}
    for _, it in ipairs(items) do
        local id, qty = it[1], it[2]
        got[id] = got[id] or { qty = 0 }
        got[id].qty = got[id].qty + qty
        got[id].name, got[id].q = it[3] or got[id].name, it[4] or got[id].q
    end
    rec.n = rec.n + 1
    for id, g in pairs(got) do
        local e = rec.items[id]
        if not e then
            e = { c = 0, min = g.qty, max = g.qty }
            rec.items[id] = e
        end
        e.c = e.c + 1
        if g.qty < e.min then e.min = g.qty end
        if g.qty > e.max then e.max = g.qty end
        e.name, e.q = g.name or e.name, g.q or e.q
    end
    rec.seenBy[addon:PlayerKey()] = true
    rec.at = time()
    return rec
end

-- One skin of `npcID`.
function KN:RecordSkin(npcID, items)
    RecordLoot("skinLoot", npcID, items)
end

-- One gather from the ore vein or herb named `name` (Phase 3b-4).
function KN:RecordNode(name, prof, items)
    RecordLoot("nodeLoot", name, items).prof = prof
end

-- What skinning `npcID` yields, from your skins and peers' together, once
-- there are LEARNED_MIN of them: n, then one row per item, most frequent
-- first, in the Classic list's shape ({ itemID, pct, min, max }) plus
-- name and q (quality) from the loot window when known. nil below that.
-- With kind "node", the same for the ore vein or herb named `npcID`
-- (nodeLoot, and peers' nodeLoot).
function KN:LearnedLoot(npcID, kind)
    if not npcID then return nil end
    local ownStore, sharedField = "skinLoot", "loot"
    if kind == "node" then ownStore, sharedField = "nodeLoot", "nodeLoot" end
    local recs = {}
    local own = addon.db and addon.db[ownStore] and addon.db[ownStore][npcID]
    if own then recs[#recs + 1] = own end
    for _, shared in pairs(addon.db and addon.db.knowledgeShared or {}) do
        local p = shared[sharedField] and shared[sharedField][npcID]
        if p then recs[#recs + 1] = p end
    end
    local n, byItem = 0, {}
    for _, r in ipairs(recs) do
        n = n + (r.n or 0)
        for id, e in pairs(r.items or {}) do
            local b = byItem[id]
            if not b then
                b = { c = 0, min = e.min, max = e.max }
                byItem[id] = b
            end
            b.c = b.c + (e.c or 0)
            if e.min and (not b.min or e.min < b.min) then b.min = e.min end
            if e.max and (not b.max or e.max > b.max) then b.max = e.max end
            b.name, b.q = b.name or e.name, b.q or e.q
        end
    end
    if n < LEARNED_MIN then return nil end
    local rows = {}
    for id, b in pairs(byItem) do
        local pct = math.floor(math.min(b.c, n) * 100 / n + 0.5)
        rows[#rows + 1] = { id, math.max(pct, 1), b.min or 1, b.max or 1, name = b.name, q = b.q, c = b.c }
    end
    table.sort(rows, function(a, b)
        if a.c ~= b.c then return a.c > b.c end
        return a[1] < b[1]
    end)
    return n, rows
end

-- The gathering profession a mob is known for from play, or nil: one you
-- or a friend skinned (skinLoot), or one you mined, gathered herbs from
-- or salvaged (gatheredMobs). Fills in the live tooltip where the Classic
-- list has no entry for the mob.
function KN:GatheredProf(npcID)
    if not (npcID and addon.db) then return nil end
    local own = addon.db.skinLoot and addon.db.skinLoot[npcID]
    if own and (own.n or 0) > 0 then return "Skinning" end
    for _, shared in pairs(addon.db.knowledgeShared or {}) do
        local p = shared.loot and shared.loot[npcID]
        if p and (p.n or 0) > 0 then return "Skinning" end
    end
    return addon.db.gatheredMobs and addon.db.gatheredMobs[npcID] or nil
end

----------------------------------------------------------------------
-- Sharing (Phase 4e). Comm.lua carries it: KNOW_REQ asks, KNOW_DATA
-- answers. What we send is our own records only, never what peers shared.
----------------------------------------------------------------------

-- A peer who has not exchanged with us for this long is dropped, unless
-- they are a contact (a contact goes when removed; Comm:ForgetPeer).
local SHARED_TTL = 30 * 86400
local MAX_SHARED_PEERS = 100

-- The newest record a peer already sent us, so they send only newer ones.
function KN:SharedSince(peer)
    local shared = addon.db.knowledgeShared and addon.db.knowledgeShared[peer]
    return shared and shared.since or 0
end

-- Every profession any of our own characters has.
function KN:OurProfessions()
    local out, seen = {}, {}
    for _, char in pairs(addon.db.characters or {}) do
        if not char.isRemote then
            for prof in pairs(char.professions or {}) do
                if not seen[prof] then seen[prof] = true; out[#out + 1] = prof end
            end
        end
    end
    table.sort(out)
    return out
end

-- What to ask `peer` for (Phase 3b-3): the professions that peer has
-- (from their synced record) and then ours, so viewing a friend's
-- profession shows the trainers they saw; whether we want their skinning
-- loot; and `since`, the newest record they sent us. A profession or the
-- loot (skinning, or nodes since 3b-4) we have not asked them for before
-- resets `since` to 0, or their older records for it would never come.
function KN:RequestFor(peer)
    local profs, seen = {}, {}
    local function add(prof)
        if not seen[prof] then seen[prof] = true; profs[#profs + 1] = prof end
    end
    local theirs = {}
    local char = addon.db.characters and addon.db.characters[peer]
    for prof in pairs(char and char.isRemote and char.professions or {}) do
        theirs[#theirs + 1] = prof
    end
    table.sort(theirs)
    for _, prof in ipairs(theirs) do add(prof) end
    for _, prof in ipairs(self:OurProfessions()) do add(prof) end
    local shared = addon.db.knowledgeShared and addon.db.knowledgeShared[peer]
    local since = shared and shared.since or 0
    if not (shared and shared.asked and shared.askedLoot and shared.askedNodes) then
        since = 0
    else
        for _, prof in ipairs(profs) do
            if not shared.asked[prof] then since = 0; break end
        end
    end
    return since, profs
end

-- Our records for `profs` (a set of profession names) written after
-- `since`, in the compact wire shape: NPCs once in `npcs`, referenced by
-- index from each recipe. `at` is the newest record sent. With maxMobs,
-- also our skinning loot (Phase 3b-3), at most maxItems items a mob, the
-- most frequent first; with maxNodes, our ore vein and herb loot (3b-4).
--   { at, npcs = { { npcID, name, zone, subZone, faction } },
--     r = { [recipeID] = { a = at, l = learnLevel, t = { npc index },
--                          v = { { npc index, itemID, price } }, i = true } },
--     s = { [npcID] = { a = at, n = skins, i = { { itemID, c, min, max } } } },
--     g = { [node name] = { a = at, n = gathers, p = prof, i = { ... } } } }
function KN:BuildShare(since, profs, maxRecipes, maxPerRecipe, maxMobs, maxItems, maxNodes)
    local RDB = addon.RecipeDB
    local npcs, index, r, newest, n = {}, {}, {}, since, 0
    local function ref(key, npc)
        local k = tostring(key)
        if not index[k] then
            npcs[#npcs + 1] = { type(key) == "number" and key or nil, npc.name, npc.zone,
                                npc.subZone, npc.faction }
            index[k] = #npcs
        end
        return index[k]
    end
    for id, e in pairs(addon.db.knowledge or {}) do
        local recipe = RDB and RDB.spellToRecipe[id]
        local at = e.at or 1
        if recipe and profs[recipe.profName] and at > since then
            n = n + 1
            if n > maxRecipes then break end
            local out = { a = at, l = e.learnLevel }
            for key, t in pairs(e.teachers or {}) do
                out.t = out.t or {}
                if #out.t < maxPerRecipe then out.t[#out.t + 1] = ref(key, t) end
            end
            for key, v in pairs(e.vendors or {}) do
                out.v = out.v or {}
                if #out.v < maxPerRecipe then out.v[#out.v + 1] = { ref(key, v), v.itemID, v.price } end
            end
            if e.items and next(e.items) then out.i = true end
            r[id] = out
            if at > newest then newest = at end
        end
    end
    local share = { at = newest, npcs = npcs, r = r }
    -- one store's records written after `since`, in the wire shape
    local function lootOf(store, max, withProf)
        local loot, m = {}, 0
        for key, rec in pairs(store or {}) do
            local at = rec.at or 1
            if at > since and (rec.n or 0) > 0 then
                m = m + 1
                if m > max then break end
                local items = {}
                for itemID, e in pairs(rec.items or {}) do
                    items[#items + 1] = { itemID, e.c, e.min, e.max }
                end
                table.sort(items, function(a, b)
                    if a[2] ~= b[2] then return a[2] > b[2] end
                    return a[1] < b[1]
                end)
                for i = #items, maxItems + 1, -1 do items[i] = nil end
                loot[key] = { a = at, n = rec.n, i = items, p = withProf and rec.prof or nil }
                if at > share.at then share.at = at end
            end
        end
        return loot
    end
    if maxMobs then share.s = lootOf(addon.db.skinLoot, maxMobs) end
    if maxNodes then share.g = lootOf(addon.db.nodeLoot, maxNodes, true) end
    return share
end

-- A sanitized KNOW_DATA (Comm:SanitizeKnowledge) from `peer`. `asked`,
-- what our request named: { profs = { name, ... }, loot = true when the
-- peer can send skinning loot, nodes = true when it can send node loot }.
function KN:StoreShared(peer, clean, asked)
    addon.db.knowledgeShared = addon.db.knowledgeShared or {}
    local all = addon.db.knowledgeShared
    local shared = all[peer] or { records = {}, since = 0 }
    all[peer] = shared
    for id, rec in pairs(clean.records) do shared.records[id] = rec end
    if clean.loot then
        shared.loot = shared.loot or {}
        for npcID, rec in pairs(clean.loot) do shared.loot[npcID] = rec end
    end
    if clean.nodeLoot then
        shared.nodeLoot = shared.nodeLoot or {}
        for name, rec in pairs(clean.nodeLoot) do shared.nodeLoot[name] = rec end
    end
    if asked then
        shared.asked = {}
        for _, prof in ipairs(asked.profs or {}) do shared.asked[prof] = true end
        shared.askedLoot = asked.loot or nil
        shared.askedNodes = asked.nodes or nil
    end
    shared.at = time()
    if (clean.at or 0) > (shared.since or 0) then shared.since = clean.at end
    self:PrunePeers()
end

function KN:ForgetPeer(peer)
    if addon.db and addon.db.knowledgeShared then addon.db.knowledgeShared[peer] = nil end
end

-- Drop peers past SHARED_TTL (contacts excepted), then the oldest beyond
-- MAX_SHARED_PEERS.
function KN:PrunePeers()
    local all = addon.db and addon.db.knowledgeShared
    if not all then return end
    local now, contacts, kept = time(), addon.db.contacts or {}, {}
    for peer, shared in pairs(all) do
        if not contacts[peer] and (now - (shared.at or 0)) > SHARED_TTL then
            all[peer] = nil
        else
            kept[#kept + 1] = peer
        end
    end
    if #kept > MAX_SHARED_PEERS then
        table.sort(kept, function(a, b) return (all[a].at or 0) > (all[b].at or 0) end)
        for i = MAX_SHARED_PEERS + 1, #kept do all[kept[i]] = nil end
    end
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
