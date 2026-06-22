----------------------------------------------------------------------
-- ProfessionBuddy  --  Comm.lua
-- Addon-to-addon communication for friend/group-mate data sharing.
--
-- Uses AceComm-3.0 + AceSerializer-3.0 + ChatThrottleLib for
-- reliable, throttled, chunked messaging over addon channels.
--
-- Protocol:
--   HELLO      -> broadcast on party/raid join (lightweight)
--   HELLO_ACK  -> whisper back to HELLO sender
--   SYNC_REQ   -> request full data from a player
--   SYNC_DATA  -> full character payload (professions, recipes, inventory)
--   INCR       -> incremental inventory/profession update (debounced)
----------------------------------------------------------------------

local addon = ProfBuddy
local Comm = addon:NewModule("Comm")

local AceComm
local AceSerializer

local PREFIX = "PBuddy"
local DS     -- DataStore, set in Init

-- Debounce timer for incremental updates
local incrTimer = nil
local INCR_DEBOUNCE = 5  -- seconds

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
function Comm:Init()
    DS = addon.DataStore
    if not DS then return end

    -- Acquire libraries via LibStub
    local ok, err = pcall(function()
        AceComm = LibStub("AceComm-3.0")
        AceSerializer = LibStub("AceSerializer-3.0")
    end)
    if not ok then
        -- Libraries not available -- silently disable comms
        print("|cff00ccffProfessionBuddy:|r Comm libraries not found, sync disabled.")
        return
    end

    -- Register our message prefix. AceComm uses a callback table pattern.
    -- We create a small wrapper object to receive messages.
    self._commTarget = {}
    function self._commTarget:OnCommReceived(prefix, message, distribution, sender)
        Comm:OnMessageReceived(prefix, message, distribution, sender)
    end
    AceComm.RegisterComm(self._commTarget, PREFIX)

    -- Auto-sync: broadcast HELLO when joining a group
    addon:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        self:OnGroupChanged()
    end)

    -- Auto-sync contacts on login
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(5, function()
            self:SyncOnlineContacts()
        end)
    end)

    -- Debounced incremental updates on inventory/profession changes
    addon:RegisterEvent("BAG_UPDATE", function()
        self:QueueIncrementalUpdate()
    end)

    self._inGroup = IsInGroup()
    self._ready = true
end

----------------------------------------------------------------------
-- Sending helpers
----------------------------------------------------------------------
function Comm:Send(msgType, data, channel, target)
    if not self._ready then return end

    data = data or {}
    data._type = msgType
    data._ver = addon.version
    data._from = addon:PlayerKey()

    local serialized = AceSerializer:Serialize(data)
    AceComm:SendCommMessage(PREFIX, serialized, channel, target, "NORMAL")
end

function Comm:SendWhisper(msgType, data, target)
    -- target must be a character name (no realm for same-realm)
    local name = target:match("^([^-]+)")
    self:Send(msgType, data, "WHISPER", name)
end

function Comm:SendGroup(msgType, data)
    if IsInRaid() then
        self:Send(msgType, data, "RAID")
    elseif IsInGroup() then
        self:Send(msgType, data, "PARTY")
    end
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
function Comm:OnMessageReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then return end

    -- Normalize sender to Name-Realm format
    if not sender:find("-") then
        sender = sender .. "-" .. GetRealmName()
    end

    -- Ignore our own messages
    if sender == addon:PlayerKey() then return end

    local ok, data = AceSerializer:Deserialize(message)
    if not ok or type(data) ~= "table" then return end

    local msgType = data._type
    if not msgType then return end

    if msgType == "HELLO" then
        self:HandleHello(sender, data)
    elseif msgType == "HELLO_ACK" then
        self:HandleHelloAck(sender, data)
    elseif msgType == "SYNC_REQ" then
        self:HandleSyncRequest(sender, data)
    elseif msgType == "SYNC_DATA" then
        self:HandleSyncData(sender, data)
    elseif msgType == "INCR" then
        self:HandleIncremental(sender, data)
    elseif msgType == "ORDER_NEW" then
        self:HandleOrderNew(sender, data)
    elseif msgType == "ORDER_UPDATE" then
        self:HandleOrderUpdate(sender, data)
    elseif msgType == "ORDER_ACK" then
        self:HandleOrderAck(sender, data)
    end

    -- Any message from a contact proves they're online -- deliver any
    -- order messages we had queued for them while they were offline.
    self:FlushOutbox(sender)
end

----------------------------------------------------------------------
-- Crafting orders (Phase 1-2 + Phase 3 public-safe slice)
-- Each side owns its transitions (Orders.lua enforces actor + state);
-- after a successful local transition the actor whispers the
-- counterparty, who mirrors the result via the Orders remote-apply
-- methods. ORDER_NEW carries the full record (the crafter has no
-- prior copy); ORDER_UPDATE carries id + new status.
--
-- Phase 3 public-safe slice:
--  * Delivery ACK: the recipient echoes ORDER_ACK for every order
--    message; if the sender gets no ack within ORDER_ACK_TIMEOUT it
--    warns that the counterparty may be offline. (Automatic
--    re-delivery / queueing is the deferred full Phase 3.)
--  * Dedup: the Orders remote-apply methods ignore duplicate / stale /
--    out-of-order messages (Orders:UpsertFromRemote / ApplyRemoteStatus).
----------------------------------------------------------------------

local ORDER_ACK_TIMEOUT = 8          -- seconds to wait for a delivery ack
local pendingOrderAck = {}           -- token -> { timer = <C_Timer> }

-- The other party on an order, from my point of view.
function Comm:OrderCounterparty(order)
    local me = addon:PlayerKey()
    if order.requester == me then return order.crafter end
    if order.crafter   == me then return order.requester end
    return nil
end

local function shortName(key)
    return (key and key:match("^([^-]+)")) or key or "?"
end

-- Send an order message to the counterparty and track delivery. If no
-- ORDER_ACK returns within the timeout, the message is parked in a
-- persisted outbox and auto-resent the next time we hear from that
-- player (any PB message proves they are online). isResend is true for
-- automatic retries and suppresses the one-time "queued" warning.
function Comm:SendOrderMessage(msgType, data, target, label, isResend)
    if not self._ready or not data or not data.token then return end
    local token = data.token
    self:SendWhisper(msgType, data, target)
    local prev = pendingOrderAck[token]
    if prev and prev.timer then prev.timer:Cancel() end
    pendingOrderAck[token] = {
        timer = C_Timer.NewTimer(ORDER_ACK_TIMEOUT, function()
            pendingOrderAck[token] = nil
            addon.db.orderOutbox = addon.db.orderOutbox or {}
            local existing = addon.db.orderOutbox[token]
            local warned = (existing and existing.warned) or false
            if not isResend and not warned then
                warned = true
                print("|cff00ccffProfessionBuddy:|r " .. shortName(target) ..
                    " is offline -- order " .. (label or "update") ..
                    " queued; it will send automatically when they are next online.")
            end
            addon.db.orderOutbox[token] = {
                msgType = msgType, data = data, target = target,
                label = label, warned = warned,
            }
        end),
    }
end

-- Recipient -> sender: confirm an order message was received.
function Comm:SendOrderAck(target, token)
    if not self._ready or not token then return end
    self:SendWhisper("ORDER_ACK", { token = token }, target)
end

function Comm:HandleOrderAck(sender, data)
    local token = data.token
    if not token then return end
    local p = pendingOrderAck[token]
    if p and p.timer then p.timer:Cancel() end
    pendingOrderAck[token] = nil
    if addon.db.orderOutbox then addon.db.orderOutbox[token] = nil end
end

-- Re-send any order messages queued for a player. Called when we next
-- hear from them (any PB message proves they're online). ORDER_NEW
-- flushes before updates so a create-then-change-while-offline sequence
-- lands in order; in-flight tokens (awaiting ack) are skipped.
function Comm:FlushOutbox(target)
    if not self._ready then return end
    local ob = addon.db.orderOutbox
    if not ob then return end
    local name = shortName(target)
    local due = {}
    for token, entry in pairs(ob) do
        if not pendingOrderAck[token] and shortName(entry.target) == name then
            table.insert(due, token)
        end
    end
    if #due == 0 then return end
    table.sort(due, function(a, b)
        local an = a:find(":new", 1, true) ~= nil
        local bn = b:find(":new", 1, true) ~= nil
        if an ~= bn then return an end   -- NEW before updates
        return a < b
    end)
    for _, token in ipairs(due) do
        local entry = ob[token]
        if entry then
            self:SendOrderMessage(entry.msgType, entry.data, entry.target,
                entry.label, true)
        end
    end
end

-- Requester -> crafter: a brand-new order (full record).
function Comm:SendOrderNew(order)
    if not self._ready or not order then return end
    local cp = self:OrderCounterparty(order)
    if not cp then return end
    local token = order.id .. ":new"
    self:SendOrderMessage("ORDER_NEW", { order = order, token = token }, cp,
        "request")
end

-- Either side -> counterparty: a status change on an existing order.
function Comm:SendOrderUpdate(order)
    if not self._ready or not order then return end
    local cp = self:OrderCounterparty(order)
    if not cp then return end
    local token = order.id .. ":" .. order.status .. ":" .. (order.updatedAt or 0)
    self:SendOrderMessage("ORDER_UPDATE", {
        id          = order.id,
        status      = order.status,
        completedBy = order.completedBy,
        updatedAt   = order.updatedAt,
        token       = token,
    }, cp, order.status .. " update")
end

-- A received status maps to the NotifyOrderEvent "kind" shown to the
-- counterparty. (pending isn't sent as an update -- new orders use
-- ORDER_NEW / newRequest.)
local ORDER_STATUS_KIND = {
    accepted  = "accepted",
    crafted   = "crafted",
    declined  = "declined",
    cancelled = "cancelled",
    completed = "completed",
}

function Comm:HandleOrderNew(sender, data)
    local Orders = addon.Orders
    if not Orders or type(data.order) ~= "table" then return end
    local order, applied = Orders:UpsertFromRemote(data.order)
    -- Ack even duplicates (clears the sender's offline warning); only
    -- notify on a genuinely new order so dupes don't double-chat.
    if order then self:SendOrderAck(sender, data.token) end
    if applied then self:NotifyOrders("newRequest", order) end
end

function Comm:HandleOrderUpdate(sender, data)
    local Orders = addon.Orders
    if not Orders or not data.id then return end
    local order, applied = Orders:ApplyRemoteStatus(data.id, data.status,
        data.completedBy, data.updatedAt)
    if order then self:SendOrderAck(sender, data.token) end
    if applied then self:NotifyOrders(ORDER_STATUS_KIND[order.status], order) end
end

-- Route a counterparty event through the OrdersPanel notification
-- dispatcher (chat line + badge + sound + refresh). Falls back to a
-- plain refresh if the panel/dispatcher or kind isn't available.
function Comm:NotifyOrders(kind, order)
    local OP = addon.OrdersPanel
    if not OP then return end
    if kind and order and OP.NotifyOrderEvent then
        OP:NotifyOrderEvent(kind, order)
    elseif OP.RefreshAll then
        OP:RefreshAll()
    end
end

----------------------------------------------------------------------
-- HELLO: lightweight broadcast on group join
----------------------------------------------------------------------
function Comm:BuildHelloPayload()
    local charData = DS:GetCharacter(addon:PlayerKey())
    if not charData then return nil end

    -- Only send profession names + skill, not full recipe data.
    -- NOTE: the scanner stores skill as skillLevel/maxSkill, so read those
    -- (reading level/maxLevel here was the bug that sent friends 0/375).
    local profSummary = {}
    for profName, profData in pairs(charData.professions or {}) do
        profSummary[profName] = {
            skillLevel = profData.skillLevel or 0,
            maxSkill = profData.maxSkill or 375,
        }
    end

    return {
        class = charData.class,
        level = charData.level,
        faction = charData.faction,
        professions = profSummary,
    }
end

function Comm:BroadcastHello()
    if not self._ready then return end
    if not IsInGroup() then return end

    local payload = self:BuildHelloPayload()
    if not payload then return end

    self:SendGroup("HELLO", payload)
end

function Comm:HandleHello(sender, data)
    -- Store lightweight summary so we know what they have
    self:StoreLightweight(sender, data)

    -- Send back our own summary
    local payload = self:BuildHelloPayload()
    if payload then
        self:SendWhisper("HELLO_ACK", payload, sender)
    end

    -- If they're a saved contact with autoSync, request full data
    local contact = addon.db.contacts[sender]
    if contact and contact.autoSync then
        C_Timer.After(1, function()
            self:RequestSync(sender)
        end)
    end
end

function Comm:HandleHelloAck(sender, data)
    self:StoreLightweight(sender, data)

    -- If they're a saved contact with autoSync, request full data
    local contact = addon.db.contacts[sender]
    if contact and contact.autoSync then
        C_Timer.After(1, function()
            self:RequestSync(sender)
        end)
    end
end

-- Store just the profession summary (no recipes/inventory) so the
-- friends panel can show what professions they have even before a
-- full sync.
function Comm:StoreLightweight(sender, data)
    local existing = addon.db.characters[sender]
    if existing and not existing.isRemote then
        -- Don't overwrite local alt data with remote lightweight data
        return
    end

    if not existing then
        addon.db.characters[sender] = {
            class = data.class or "UNKNOWN",
            level = data.level or 0,
            faction = data.faction or "Unknown",
            professions = {},
            inventory = { bags = {}, bank = {} },
            isRemote = true,
            lastSync = 0,
        }
    end

    local char = addon.db.characters[sender]
    char.class = data.class or char.class
    char.level = data.level or char.level
    char.faction = data.faction or char.faction

    -- Update profession summaries without wiping recipe data
    -- (a full SYNC_DATA will populate recipes later)
    if data.professions then
        for profName, summary in pairs(data.professions) do
            if not char.professions[profName] then
                char.professions[profName] = {
                    skillLevel = summary.skillLevel or 0,
                    maxSkill = summary.maxSkill or 375,
                    recipes = {},
                }
            else
                char.professions[profName].skillLevel = summary.skillLevel or char.professions[profName].skillLevel
                char.professions[profName].maxSkill = summary.maxSkill or char.professions[profName].maxSkill
            end
        end
    end

    -- Auto-create contact entry if they're in our group
    if not addon.db.contacts[sender] then
        addon.db.contacts[sender] = {
            autoSync = false,
            lastSync = 0,
        }
    end

    self:NotifyUIRefresh()
end

----------------------------------------------------------------------
-- Notify all visible UI surfaces to refresh after incoming data
----------------------------------------------------------------------
function Comm:NotifyUIRefresh()
    -- Friends panel
    if addon.FriendsPanel and addon.FriendsPanel.Refresh then
        addon.FriendsPanel:Refresh()
    end
    -- Character panel (if the main /pb window is visible)
    if addon.UI and addon.UI.frame and addon.UI.frame:IsShown()
       and addon.CharacterPanel and addon.CharacterPanel.Refresh then
        addon.CharacterPanel:Refresh()
    end
    -- Profession window detail panel + material calc
    if addon.TradeSkillFrame and addon.TradeSkillFrame.frame
       and addon.TradeSkillFrame.frame:IsShown() then
        local tsf = addon.TradeSkillFrame
        if tsf.RefreshDetailPanel then
            tsf:RefreshDetailPanel(true)
        end
        if tsf.calcFrame and tsf.calcFrame:IsShown() and tsf.RefreshCalcPanel then
            tsf:RefreshCalcPanel()
        end
    end
end

----------------------------------------------------------------------
-- SYNC_REQ / SYNC_DATA: full data exchange
----------------------------------------------------------------------
function Comm:RequestSync(target, isManual)
    if not self._ready then
        if isManual then
            print("|cff00ccffProfessionBuddy:|r Sync not available.")
        end
        return
    end

    -- Ensure contact entry exists
    if not addon.db.contacts[target] then
        addon.db.contacts[target] = {
            autoSync = false,
            lastSync = 0,
        }
    end

    -- Only manual syncs announce themselves and watch for a reply; auto
    -- syncs stay silent so they don't spam chat.
    if isManual then
        print("|cff00ccffProfessionBuddy:|r Requesting sync from " .. target .. "...")
        self._pendingSync = self._pendingSync or {}
        self._pendingSync[target] = true
        C_Timer.After(10, function()
            if self._pendingSync and self._pendingSync[target] then
                self._pendingSync[target] = nil
                print("|cff00ccffProfessionBuddy:|r " .. target
                    .. " didn't respond (offline or not running ProfessionBuddy).")
            end
        end)
    end

    self:SendWhisper("SYNC_REQ", {}, target)
end

function Comm:HandleSyncRequest(sender, data)
    -- Someone wants our full data -- send it
    local payload = self:BuildFullPayload()
    if payload then
        self:SendWhisper("SYNC_DATA", payload, sender)
    end
end

function Comm:BuildFullPayload()
    local charData = DS:GetCharacter(addon:PlayerKey())
    if not charData then return nil end

    -- Build a clean copy of profession data with recipe names only
    -- (both sides have the static RecipeDB, so we don't need to send
    -- reagents, itemIDs, etc. -- just which recipes are known)
    local professions = {}
    for profName, profData in pairs(charData.professions or {}) do
        local recipeNames = {}
        if profData.recipes then
            for recipeName, _ in pairs(profData.recipes) do
                table.insert(recipeNames, recipeName)
            end
        end
        professions[profName] = {
            skillLevel = profData.skillLevel or 0,
            maxSkill = profData.maxSkill or 375,
            recipeNames = recipeNames,
        }
    end

    -- Inventory: send itemID -> count maps
    local inventory = {
        bags = {},
        bank = {},
    }
    if charData.inventory then
        for id, count in pairs(charData.inventory.bags or {}) do
            inventory.bags[id] = count
        end
        for id, count in pairs(charData.inventory.bank or {}) do
            inventory.bank[id] = count
        end
    end

    return {
        class = charData.class,
        level = charData.level,
        faction = charData.faction,
        professions = professions,
        inventory = inventory,
    }
end

function Comm:HandleSyncData(sender, data)
    if not data then return end

    -- Was this the reply to a manual sync we initiated? If so, clear the
    -- timeout watch and confirm in chat below; background / incremental
    -- syncs stay silent so chat doesn't flood (e.g. several friends
    -- crafting at once).
    local wasManual = self._pendingSync and self._pendingSync[sender]
    if self._pendingSync then self._pendingSync[sender] = nil end

    -- Reconstruct the character record from the payload
    local charRecord = {
        class = data.class or "UNKNOWN",
        level = data.level or 0,
        faction = data.faction or "Unknown",
        professions = {},
        inventory = {
            bags = data.inventory and data.inventory.bags or {},
            bank = data.inventory and data.inventory.bank or {},
        },
        isRemote = true,
        lastSync = time(),
    }

    -- Rebuild profession data with recipe entries
    -- We store recipe names as keys pointing to minimal info
    -- (the UI will cross-reference RecipeDB for full details)
    if data.professions then
        for profName, profPayload in pairs(data.professions) do
            local recipes = {}
            if profPayload.recipeNames then
                for _, recipeName in ipairs(profPayload.recipeNames) do
                    recipes[recipeName] = { isKnown = true }
                end
            end
            charRecord.professions[profName] = {
                skillLevel = profPayload.skillLevel or 0,
                maxSkill = profPayload.maxSkill or 375,
                recipes = recipes,
            }
        end
    end

    DS:SetRemoteCharacter(sender, charRecord)

    -- Update contact metadata (always, so the Friends panel timestamp
    -- stays current even for silent background syncs)
    if addon.db.contacts[sender] then
        addon.db.contacts[sender].lastSync = time()
    end

    -- Only confirm in chat for syncs you manually requested.
    if wasManual then
        print("|cff00ccffProfessionBuddy:|r Synced data from " .. sender .. ".")
    end

    self:NotifyUIRefresh()
end

----------------------------------------------------------------------
-- INCR: incremental updates (debounced)
----------------------------------------------------------------------
function Comm:QueueIncrementalUpdate()
    if not self._ready then return end

    -- Only send if we have contacts with autoSync
    local hasAuto = false
    for _, contact in pairs(addon.db.contacts) do
        if contact.autoSync then
            hasAuto = true
            break
        end
    end
    if not hasAuto then return end

    -- Debounce: reset timer on each trigger
    if incrTimer then
        incrTimer:Cancel()
    end
    incrTimer = C_Timer.NewTimer(INCR_DEBOUNCE, function()
        incrTimer = nil
        Comm:SendIncrementalUpdate()
    end)
end

function Comm:SendIncrementalUpdate()
    if not self._ready then return end

    local payload = self:BuildFullPayload()
    if not payload then return end

    -- Send to all online contacts with autoSync
    -- We send as SYNC_DATA since the receiver handles it the same way
    for contactKey, contact in pairs(addon.db.contacts) do
        if contact.autoSync then
            self:SendWhisper("SYNC_DATA", payload, contactKey)
        end
    end
end

----------------------------------------------------------------------
-- Group join detection
----------------------------------------------------------------------
function Comm:OnGroupChanged()
    local inGroup = IsInGroup()

    -- Newly joined a group? Broadcast HELLO after a short delay
    -- to let the UI settle
    if inGroup and not self._inGroup then
        C_Timer.After(2, function()
            if IsInGroup() then
                self:BroadcastHello()
            end
        end)
    end

    self._inGroup = inGroup
end

----------------------------------------------------------------------
-- Login auto-sync for saved contacts
----------------------------------------------------------------------
function Comm:SyncOnlineContacts()
    if not self._ready then return end

    local contacts = addon.db.contacts
    if not contacts then return end

    for contactKey, contact in pairs(contacts) do
        if contact.autoSync then
            -- We can't reliably check if they're online without
            -- being in a group or having them on the friends list.
            -- Just send the request -- if they're offline, the
            -- whisper silently fails.
            self:SendWhisper("SYNC_REQ", {}, contactKey)
        end
    end
end
