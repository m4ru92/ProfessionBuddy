----------------------------------------------------------------------
-- TBC Classic Anniversary window harness.
--
-- Loads the _TBC toc in tbc_env.lua and builds every window PB has, the
-- way a player opens them: the main window and its four tabs, a trade
-- skill (Leatherworking) and a craft (Enchanting) profession window with a
-- recipe selected, Settings, the Material Calculator, and the profession
-- window's own tabs. The look is TBC_LOOK ("modern" unless a wrapper sets
-- "classic"); the windows are built once per session, as in game.
-- A Lua error anywhere stops the run with its message.
----------------------------------------------------------------------

dofile("tests/tbc_env.lua")
local LOOK = rawget(_G, "TBC_LOOK") or "modern"
local TAG = LOOK == "classic" and "C" or "U"

local files, errs = LOAD_TOC("ProfessionBuddy_TBC.toc")
EXPECT(#errs == 0, "load errors: " .. table.concat(errs, " | "))
local hasClassic = false
for _, f in ipairs(files) do
    EXPECT(not f:match("^Data/Forever/") and f ~= "Source/Forever.lua" and f ~= "Knowledge.lua",
           "the TBC toc loads " .. f)
    if f == "Source/Classic.lua" then hasClassic = true end
end
EXPECT(hasClassic, "the TBC toc does not load Source/Classic.lua")

ProfBuddyDB = { settings = { windowStyle = LOOK } }
FIRE("ADDON_LOADED", "ProfessionBuddy")
-- 2.1.1: the login line waits for PLAYER_LOGIN (ElvUI drops earlier lines)
EXPECT(not PRINTED("loaded. Type /pb or /profbuddy."), "the loaded line printed at ADDON_LOADED")
-- U31 (at the end) checks the look picker this login shows
local loginPopups = {}
local keepLoginDialogs, keepLoginShow = rawget(_G, "StaticPopupDialogs"), StaticPopup_Show
StaticPopupDialogs = {}
StaticPopup_Show = function(which) loginPopups[#loginPopups + 1] = which end
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
local loginPicker = StaticPopupDialogs.PROFBUDDY_PICK_LOOK
StaticPopupDialogs, StaticPopup_Show = keepLoginDialogs, keepLoginShow
for _, l in ipairs(PRINTS) do EXPECT(not l:find("failed to load", 1, true), "module init error: " .. l) end
EXPECT(PRINTED("loaded. Type /pb or /profbuddy."), "no loaded line")
local PB = ProfBuddy
EXPECT(PB.Source.flavor == "classic", "flavor is " .. tostring(PB.Source.flavor))
EXPECT(PB.Theme:Name() == LOOK, "look is " .. tostring(PB.Theme:Name()))
EXPECT(PB.db.settings.openBesideBlizzard == false, "a player with Replace on got Open beside Blizzard's window")
local DS = PB.DataStore
EXPECT(DS:GetProfession(nil, "Leatherworking") and DS:GetProfession(nil, "Enchanting"),
       "professions not recorded from the skill lines")
print("  PASS " .. TAG .. "1 TBC toc loads Classic source and no Forever data; every module starts; look " .. LOOK)

-- U2: the main window and its five tabs (Shuffle since 2.2.0)
local ok, err = pcall(SlashCmdList.PROFBUDDY, "")
EXPECT(ok, "/pb: " .. tostring(err))
local UI = PB.UI
EXPECT(UI.frame and UI.frame:IsShown() and #UI.frame.tabs == 5 and UI.frame.tabs[5].name == "shuffle",
       "main window not shown with 5 tabs, Shuffle last")
for i = 1, #UI.frame.tabs do
    ok, err = pcall(UI.SelectTab, UI, i)
    EXPECT(ok, "main tab " .. i .. ": " .. tostring(err))
end
local told
ChatFrameUtil.SendTell = function(name) told = name end
ok, err = pcall(function()
    local GP = PB.GuildPanel
    local row = GP:CreateRow(UIParent)
    row._member = { name = "Guildie-Realm", charKey = "Guildie-Realm" }
    row:GetScript("OnMouseUp")(row, "RightButton")
    GP._memberMenu.buttons[1]:GetScript("OnClick")(GP._memberMenu.buttons[1])
end)
EXPECT(ok and told == "Guildie-Realm", "guild right-click whisper: " .. tostring(err or told))
ok, err = pcall(UI.Hide, UI)
EXPECT(ok, "main window hide: " .. tostring(err))
print("  PASS " .. TAG .. "2 /pb opens; Characters, Friends, Guild, Orders and Shuffle tabs all build and select; guild right-click whispers")

-- U3: a trade skill profession window, a recipe selected
local TSF = PB.TradeSkillFrame
ok, err = pcall(OPEN_TRADE)
EXPECT(ok, "trade skill open: " .. tostring(err))
EXPECT(TSF.frame and TSF.frame:IsShown(), "PB's profession window did not open")
EXPECT(TSF.state.profName == "Leatherworking", "profession is " .. tostring(TSF.state.profName))
EXPECT(TSF.state.allRecipes and TSF.state.allRecipes["Light Leather"], "Light Leather not listed")
ok, err = pcall(function()
    TSF.state.selected = "Light Leather"
    TSF:RefreshDetailPanel()
    TSF:UpdateCraftBar()
    TSF:UpdateListRows()
end)
EXPECT(ok, "selecting a recipe: " .. tostring(err))
EXPECT(TSF.navTabs and #TSF.navTabs == 5, "the profession window's own tabs were not built (5 with Shuffle)")
-- no profession link on TBC Anniversary (a Wrath feature): no button, and
-- the skill bar keeps its full width
EXPECT(rawget(TSF, "linkButton") == nil, "a profession link button on TBC Anniversary")
local bw = rawget(TSF.skillBar, "_size")[1]
local fullW = LOOK == "classic" and (740 - 24 - 13 * 22 / 15) or (740 - 24)
EXPECT(math.abs(bw - fullW) < 0.01, "skill bar width " .. tostring(bw) .. ", expected " .. fullW)
-- shift-click a recipe row: Share's link, or Share's loading line
local insertedLink
local keepInsert, keepMod, keepRCL = ChatEdit_InsertLink, IsModifiedClick, TSF.RecipeChatLink
IsModifiedClick = function(k) return k == "CHATLINK" end
TSF.RecipeChatLink = function() return nil end
local firstReal
for idx, e in ipairs(TSF.state.recipes or {}) do if not e.isHeader then firstReal = idx; break end end
EXPECT(firstReal and TSF.listRows and TSF.listRows[1], "no recipe row to click")
TSF.state.scrollOffset = firstReal - 1
PRINTS = {}
TSF.listRows[1]:GetScript("OnClick")(TSF.listRows[1])
EXPECT(PRINTED("still loading; try again in a moment."), "no loading line on a TBC shift-click")
TSF.RecipeChatLink = keepRCL
IsModifiedClick, TSF.state.scrollOffset = keepMod, 0
print("  PASS " .. TAG .. "3 Leatherworking opens in PB's window; Light Leather selects; no link button, full skill bar; shift-click loading line")

-- U4: Settings and the Material Calculator
ok, err = pcall(TSF.OpenSettings, TSF, "main")
EXPECT(ok, "Settings: " .. tostring(err))
EXPECT(TSF.settingsPanel and TSF.settingsPanel:IsShown(), "Settings did not open")
ok, err = pcall(TSF.ToggleSettings, TSF)
EXPECT(ok, "Settings close: " .. tostring(err))
ok, err = pcall(TSF.ToggleCalcPanel, TSF)
EXPECT(ok, "Material Calculator: " .. tostring(err))
ok, err = pcall(TSF.ToggleCalcPanel, TSF)
EXPECT(ok, "Material Calculator close: " .. tostring(err))
EXPECT(PB.UI.scaleGrip and TSF.scaleGrip, "a window has no scale grip on TBC Anniversary")
ok, err = pcall(function() TSF.scaleGrip:GetScript("OnClick")(TSF.scaleGrip, "RightButton") end)
EXPECT(ok and PB.db.settings.professionWindowScale == 1, "scale reset on TBC: " .. tostring(err))
print("  PASS " .. TAG .. "4 Settings and the Material Calculator open and close; both windows have a scale grip")

-- U5: the craft window (Enchanting) after the trade skill closes
ok, err = pcall(CLOSE_TRADE)
EXPECT(ok, "trade skill close: " .. tostring(err))
ok, err = pcall(OPEN_CRAFT)
EXPECT(ok, "craft open: " .. tostring(err))
EXPECT(TSF.frame:IsShown() and TSF.state.profName == "Enchanting", "Enchanting did not open: "
       .. tostring(TSF.state.profName))
ok, err = pcall(function()
    TSF.state.selected = "Enchant Bracer - Minor Health"
    TSF:RefreshDetailPanel()
    TSF:UpdateCraftBar()
end)
EXPECT(ok, "selecting an enchant: " .. tostring(err))
ok, err = pcall(CLOSE_CRAFT)
EXPECT(ok, "craft close: " .. tostring(err))
print("  PASS " .. TAG .. "5 Enchanting opens through the craft window; an enchant selects; it closes cleanly")

-- U6: Replace off and "Open beside Blizzard's window" off: neither window
-- opens PB's, and both still record the recipes
local S = PB.db.settings
-- unticked this session (Reload / Later, Later): Blizzard's window is still
-- suppressed until the reload, so PB's window keeps opening
EXPECT(rawget(TSF, "_suppressed") == true, "Replace on did not suppress Blizzard's windows")
S.replaceTradeSkill, S.openBesideBlizzard = false, false
TSF.frame:Hide()
ok, err = pcall(OPEN_TRADE)
EXPECT(ok and TSF.frame:IsShown(), "unticked without a reload: no window opens: " .. tostring(err))
pcall(CLOSE_TRADE)
-- after the reload (a session that starts with Replace off): nothing is
-- suppressed, and PB stays closed
TSF._suppressed = nil
TSF.frame:Hide()
local char = DS:GetCharacter()
char.professions.Leatherworking.recipes, char.professions.Enchanting.recipes = {}, {}
ok, err = pcall(OPEN_TRADE)
EXPECT(ok, "trade skill open, setting off: " .. tostring(err))
EXPECT(not TSF.frame:IsShown(), "PB opened on the trade skill with both settings off")
EXPECT(next(char.professions.Leatherworking.recipes), "Leatherworking not recorded with PB closed")
pcall(CLOSE_TRADE)
ok, err = pcall(OPEN_CRAFT)
EXPECT(ok, "craft open, setting off: " .. tostring(err))
EXPECT(not TSF.frame:IsShown(), "PB opened on the craft window with both settings off")
EXPECT(next(char.professions.Enchanting.recipes), "Enchanting not recorded with PB closed")
pcall(CLOSE_CRAFT)
S.openBesideBlizzard = true
pcall(OPEN_TRADE)
EXPECT(TSF.frame:IsShown(), "PB did not open beside Blizzard's window with the setting on")
pcall(CLOSE_TRADE)
S.replaceTradeSkill, S.openBesideBlizzard = true, false
TSF._suppressed = true
print("  PASS " .. TAG .. "6 Replace off: PB opens until the reload, then stays closed and still records both windows; opens beside them when asked")

-- U7: "Disenchants into" on TBC Anniversary: the skill line, grey when one
-- of your characters has it (Enchanting 50 here), red when none does
local D = PB.Disenchant
EXPECT(D and D.source:find("^cmangos TBCDB ") and TSF:DisenchantGroup(821) and TSF:DisenchantGroup(21852),
       "TBC disenchant data not loaded")
local tipLines = {}
rawset(GameTooltip, "AddLine", function(_, t, r, g, b) tipLines[#tipLines + 1] = { t, r, g, b } end)
rawset(GameTooltip, "AddDoubleLine", function(_, l, rt, lr, lg, lb, rr, rg, rb) tipLines[#tipLines + 1] = { l, rt, rr, rg, rb } end)
rawset(GameTooltip, "Show", function() end)
local function hover(itemID)
    tipLines = {}
    rawset(GameTooltip, "GetItem", function() return "x", "|cffffffff|Hitem:" .. itemID .. "::::::::|h[x]|h|r" end)
    GameTooltip._h.OnTooltipSetItem(GameTooltip)
    for _, l in ipairs(tipLines) do if l[1] == "Disenchants into (ProfessionBuddy):" then return l end end
end
local h = hover(821)
EXPECT(h and h[2] == "Requires Enchanting 1" and h[3] == 0.7, "item 821 skill line: " .. tostring(h and h[2]))
-- a friend's Enchanting does not count: only your own characters
PB.db.characters["Friend-Realm"] = { isRemote = true, professions = { Enchanting = { skillLevel = 375 } } }
h = hover(21852)
EXPECT(h and h[2] == "Requires Enchanting 275" and h[3] == 1 and h[4] == 0.25, "item 21852 not red: " .. tostring(h and h[2]))
PB.db.characters["Friend-Realm"] = nil
print("  PASS " .. TAG .. "7 Disenchants into on TBC Anniversary: Requires Enchanting, grey with an Enchanter who has it, red without")

-- U8: nothing PB calls is missing on this client
local missing = {}
for _, name in ipairs({ "GetItemInfo", "GetSpellInfo", "GetTradeSkillInfo", "GetCraftInfo",
                        "GetSkillLineInfo", "C_TradeSkillUI" }) do
    if FALLBACK[name] then missing[#missing + 1] = name end
end
EXPECT(#missing == 0, "fell back to a stub for " .. table.concat(missing, ", "))
print("  PASS " .. TAG .. "8 no classic API call fell back to a stub")

-- U9: skill-up ranges at the trainer on TBC Anniversary. The selected
-- recipe's Requires line gets the numbers only when they fit on that line
-- (the Cost label sits right under it); the skill icon's tooltip always gets
-- the labeled line; a known recipe, a class trainer and the setting off add
-- nothing
do
    local S = PB.db.settings
    local services = {
        { "Embossed Leather Gloves", "unavailable", "Leatherworking", 55 },
        { "Handstitched Leather Boots", "used", "Leatherworking", 1 },
    }
    local tradeskill = true
    -- TBC order: name, subText, category
    GetTrainerServiceInfo = function(i) local v = services[i]; if v then return v[1], "", v[2], false end end
    GetTrainerServiceSkillReq = function(i) local v = services[i]; if v then return v[3], v[4], true end end
    IsTradeskillTrainer = function() return tradeskill end
    local req = CreateFrame("FontString", "ClassTrainerSkillRequirements", UIParent)
    local charW = 4
    rawset(req, "GetWidth", function() return 244 end)
    rawset(req, "GetUnboundedStringWidth", function(self)
        return #(self:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * charW
    end)
    ClassTrainer_SetSelection = function(i)
        local v = services[i]
        req:SetText("Requires: " .. v[3] .. " (" .. v[4] .. ")")
    end
    FIRE("ADDON_LOADED", "Blizzard_TrainerUI")
    FIRE("TRAINER_SHOW")
    -- U7 replaced the tooltip's AddLine; read lines into _lines again
    rawset(GameTooltip, "AddLine", function(self, t) local l = rawget(self, "_lines"); if l then l[#l + 1] = t end end)
    ClassTrainer_SetSelection(1)
    EXPECT(req:GetText() == "Requires: Leatherworking (55 |cffffff0085|r |cff00ff00100|r |cff808080115|r)",
           "Requires line: " .. tostring(req:GetText()))
    -- the TEST-f line ("(55)   55  85  100  115", 46 characters) did not fit
    -- the 244 pane in the default font; this one (38) does at 6 per character
    charW = 6
    ClassTrainer_SetSelection(1)
    EXPECT(req:GetText():find("(55 |cffffff0085|r", 1, true), "the shorter line does not fit at 6 per character")
    charW = 4
    rawset(GameTooltip, "_lines", {})
    GameTooltip:SetTrainerService(1)
    local tl = rawget(GameTooltip, "_lines")
    EXPECT(#tl == 1 and tl[1]:find("^Skill%-ups %(ProfessionBuddy%): |cffffffff>|r|cffff8000Orange: 55|r"),
           "tooltip: " .. tostring(tl[1]))
    -- too long for one line: the line stays Blizzard's, the tooltip still has it
    charW = 7
    ClassTrainer_SetSelection(1)
    EXPECT(req:GetText() == "Requires: Leatherworking (55)", "a line too long for the pane: " .. tostring(req:GetText()))
    charW = 4
    -- a recipe you know
    ClassTrainer_SetSelection(2)
    EXPECT(req:GetText() == "Requires: Leatherworking (1)", "a known recipe got numbers")
    -- the setting off, and a class trainer
    S.trainerShowRanges = false
    ClassTrainer_SetSelection(1)
    EXPECT(req:GetText() == "Requires: Leatherworking (55)", "numbers with the setting off")
    S.trainerShowRanges = true
    tradeskill = false
    rawset(GameTooltip, "_lines", {})
    GameTooltip:SetTrainerService(1)
    ClassTrainer_SetSelection(1)
    EXPECT(#rawget(GameTooltip, "_lines") == 0 and req:GetText() == "Requires: Leatherworking (55)",
           "a class trainer got skill-up ranges")
    rawset(GameTooltip, "_lines", nil)
end
print("  PASS " .. TAG .. "9 trainer ranges on TBC Anniversary: numbers on the Requires line when they fit, none when too long, tooltip line, nothing for a known recipe, the setting off or a class trainer")

-- U10: prices on TBC Anniversary (Prices.lua, 2.1.0): the TBC vendor
-- table, the classic vendor API, Auctionator, the detail line, the
-- calculator and Settings
do
    local P = PB.Prices
    EXPECT(P and PB.VendorPrices and PB.VendorPrices[2320] == 10 and PB.VendorPrices[14341] == 5000,
           "TBC vendor prices (Coarse Thread 10c, Rune Thread 50s)")
    local tocSrc = assert(io.open(PB_BASE .. "/ProfessionBuddy_TBC.toc")):read("*a")
    EXPECT(tocSrc:find("## OptionalDeps: Auctionator, TradeSkillMaster", 1, true)
           and tocSrc:find("\nData/VendorPrices.lua", 1, true) and tocSrc:find("\nPrices.lua", 1, true),
           "TBC toc: prices files or OptionalDeps")
    local function plain(t)
        return ((t or ""):gsub("|T[^|]*|t", function(icon)
            return icon:find("GoldIcon") and "g" or icon:find("SilverIcon") and "s" or "c"
        end):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    -- the classic vendor window: GetMerchantItemInfo, no C_MerchantFrame.GetItemInfo
    local ITEMS = {
        { 2320, 40, 4, -1, false },   -- Coarse Thread, a stack of 4 for 40c
        { 2321, 100, 1, 3, false },   -- Fine Thread, limited stock
        { 2604, 50, 1, -1, true },    -- Red Dye for tokens
    }
    local keep = { C_MerchantFrame = rawget(_G, "C_MerchantFrame") }
    C_MerchantFrame = { GetBuybackItemID = function() end }
    GetMerchantNumItems = function() return #ITEMS end
    GetMerchantItemID = function(i) return ITEMS[i] and ITEMS[i][1] end
    GetMerchantItemInfo = function(i)
        local it = ITEMS[i]
        return "x", "icon", it[2], it[3], it[4], true, true, it[5]
    end
    FIRE("MERCHANT_SHOW")
    local V = PB.db.prices and PB.db.prices.vendor or {}
    EXPECT(V[2320] and V[2320].p == 10 and V[2321] == nil and V[2604] == nil,
           "TBC vendor scan: " .. tostring(V[2320] and V[2320].p))
    GetMerchantNumItems = function() return 0 end
    C_MerchantFrame = keep.C_MerchantFrame

    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(_, id) return ({ [2934] = 10, [2318] = 50 })[id] end,
        GetAuctionAgeByItemID = function() return 0 end,
    } } }
    ok, err = pcall(OPEN_TRADE)
    EXPECT(ok, "trade skill reopen: " .. tostring(err))
    TSF.state.selected = "Light Leather"
    TSF:RefreshDetailPanel()
    local line = plain(TSF.detPrice:GetText())
    EXPECT(TSF.detPrice:IsShown() and line == "Cost: 30c   Auction: 50c, vendor 5c   Profit: +18c", "TBC price line: " .. line)
    ok, err = pcall(TSF.ToggleCalcPanel, TSF)
    EXPECT(ok and TSF.calcCols.price:IsShown(), "calculator with prices: " .. tostring(err))
    ok, err = pcall(TSF.ToggleCalcPanel, TSF)
    EXPECT(ok, "calculator close: " .. tostring(err))
    EXPECT(TSF.showPricesCB and TSF.priceAucCB and TSF.priceTSMBox, "Settings > Prices on TBC Anniversary")
    Auctionator = nil
    pcall(CLOSE_TRADE)
end
print("  PASS " .. TAG .. "10 prices: TBC vendor table, the classic vendor window recorded per item (unlimited, money only), Auctionator line in the detail panel, calculator columns, Settings")

-- U11: auction prices on TBC Anniversary (AuctionPrices.lua, 2.1.0):
-- the classic auction house's pages, Scan my materials by exact name with
-- cheapest first, the game's search and full-scan limits, a full scan
-- read from index 1, another addon's full scan left alone
do
    local P, AP = PB.Prices, PB.AuctionPrices
    P:ClearRecorded()
    local LIST, canQuery, canAll, queries, sorts = {}, true, false, {}, {}
    GetNumAuctionItems = function() return #LIST, #LIST end
    GetAuctionItemInfo = function(_, i)
        local e = LIST[i]
        return "x", "icon", e[2], 1, true, 1, nil, 0, 0, e[3], 0, nil, nil, nil, nil, 0, e[1], true
    end
    CanSendAuctionQuery = function() return canQuery, canAll end
    SortAuctionSetSort = function(_, how) sorts[#sorts + 1] = how end
    QueryAuctionItems = function(name, _, _, page, _, _, getAll, exact)
        queries[#queries + 1] = tostring(name) .. "|" .. tostring(page) .. "|" .. tostring(getAll) .. "|" .. tostring(exact)
        if not getAll then
            LIST = { { 2934, 5, 40 }, { 2934, 2, 30 } }
            FIRE("AUCTION_ITEM_LIST_UPDATE")
        end
    end
    local said
    local keepDialogs = rawget(_G, "StaticPopupDialogs")
    StaticPopupDialogs = {}
    local keepPopup = StaticPopup_Show
    StaticPopup_Show = function(n) said = n end
    local AF = CreateFrame("Frame", "AuctionFrame", UIParent)
    -- the classic auction house's three tabs and its tab click (Blizzard_AuctionUI)
    rawset(AF, "numTabs", 3)
    for i = 1, 3 do CreateFrame("Button", "AuctionFrameTab" .. i, AF):SetID(i) end
    local numTabs
    PanelTemplates_SetNumTabs = function(f, n) numTabs = n; rawset(f, "numTabs", n) end
    PanelTemplates_TabResize = function() end
    PanelTemplates_EnableTab = function() end
    AuctionFrameTab_OnClick = function(tab) rawset(AF, "_tab", tab:GetID()) end
    local keepSub, keepMap = GetSubZoneText, rawget(_G, "C_Map")
    local SUB = ""
    GetSubZoneText = function() return SUB end
    C_Map = setmetatable({ GetAreaInfo = function(id) return ({ [35] = "Booty Bay", [976] = "Gadgetzan", [2255] = "Everlook" })[id] end },
                         { __index = keepMap })
    local house = P:HouseKey()
    local function rec(id) local h = PB.db.prices and PB.db.prices.auction[house]; return h and h[id] and h[id].p end
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    -- the ProfessionBuddy tab: the fourth AuctionFrameTab, its page shown
    -- by Blizzard's tab click and hidden by another tab
    EXPECT(AP.tab and AP.tab == AuctionFrameTab4 and AP.tab:GetID() == 4 and numTabs == 4 and AP.tab:IsShown(),
           "no ProfessionBuddy tab on TBC Anniversary")
    AuctionFrameTab_OnClick(AP.tab)
    EXPECT(AP.panel:IsShown() and AF._tab == 4, "PB's page not shown by its tab")
    AuctionFrameTab_OnClick(AuctionFrameTab1)
    EXPECT(not AP.panel:IsShown(), "PB's page left over Browse")
    -- the tan bar over the corner art's empty button wells, on PB's page
    -- (the harness has no textures; where it sits is checked in game)
    local apSrc = assert(io.open(PB_BASE .. "/AuctionPrices.lua")):read("*a")
    EXPECT(rawget(AP.panel, "bottomBar") ~= nil and apSrc:find('bar:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 673, -411)', 1, true),
           "no bar over the bottom-right wells")
    -- TEST-b3: PB when the tabs run past the window's edge (Auctionator's)
    rawset(AF, "GetRight", function() return 840 end)
    rawset(AP.tab, "GetRight", function() return 900 end)
    rawset(AP.tab, "GetWidth", function() return 120 end)
    AP:FitTab()
    EXPECT(AP.tab:GetText() == "PB", "TBC Anniversary crowded tab: " .. tostring(AP.tab:GetText()))
    rawset(AP.tab, "GetRight", function() return 700 end)
    rawset(AP.tab, "GetWidth", function() return 60 end)
    AP:FitTab()
    EXPECT(AP.tab:GetText() == "ProfessionBuddy", "TBC Anniversary tab with room: " .. tostring(AP.tab:GetText()))
    rawset(AF, "GetRight", nil); rawset(AP.tab, "GetRight", nil); rawset(AP.tab, "GetWidth", nil)
    -- a page you browse: lowest per item (40c for 5 = 8c; 30c for 2 = 15c)
    LIST = { { 2934, 5, 40 }, { 2934, 2, 30 }, { 99999, 1, 1 } }
    FIRE("AUCTION_ITEM_LIST_UPDATE")
    EXPECT(rec(2934) == 8 and rec(99999) == nil, "page prices: " .. tostring(rec(2934)))
    -- another addon's full scan (more than a page) is left alone
    LIST = {}
    for i = 1, 60 do LIST[i] = { 2318, 1, 1 } end
    FIRE("AUCTION_ITEM_LIST_UPDATE")
    EXPECT(rec(2318) == nil, "another addon's full scan was read")
    -- Scan my materials: exact names, cheapest per item first, only when the game takes a search
    canQuery = false
    AP:StartTargeted()
    EXPECT(#queries == 0, "searched while the game refused searches")
    canQuery = true
    FLUSH()
    FLUSH()
    EXPECT(#queries > 0 and queries[1]:match("|0|false|true$") and sorts[1] == "unitprice",
           "scan queries: " .. table.concat(queries, ", ") .. " / " .. tostring(sorts[1]))
    EXPECT(AP._scan == nil, "scan did not finish")
    -- full scan: refused while the game says no, then read from index 1
    queries = {}
    StaticPopupDialogs.PROFBUDDY_FULL_SCAN = nil
    AP.panel.full:GetScript("OnClick")(AP.panel.full)
    EXPECT(said == "PROFBUDDY_FULL_SCAN", "no full scan warning")
    PRINTS = {}
    StaticPopupDialogs.PROFBUDDY_FULL_SCAN.OnAccept()
    EXPECT(#queries == 0 and PRINTED("does not allow a full scan yet"), "full scan sent while the game said no")
    canAll = true
    StaticPopupDialogs.PROFBUDDY_FULL_SCAN.OnAccept()
    EXPECT(queries[1] == "|0|true|false", "full scan query: " .. tostring(queries[1]))
    LIST = {}
    for i = 1, 120 do LIST[i] = { 2318, 2, 90 } end
    LIST[120] = { 2318, 1, 20 }
    FIRE("AUCTION_ITEM_LIST_UPDATE")
    FLUSH()
    EXPECT(rec(2318) == 20, "full scan prices: " .. tostring(rec(2318)))
    FIRE("AUCTION_HOUSE_CLOSED")
    -- Gadgetzan's neutral auction house is not recorded
    SUB = "Gadgetzan"
    FIRE("AUCTION_HOUSE_SHOW")
    FLUSH()
    LIST = { { 2934, 1, 1 } }
    FIRE("AUCTION_ITEM_LIST_UPDATE")
    EXPECT(not AP._record and rec(2934) == 8, "Gadgetzan's auction house was recorded")
    FIRE("AUCTION_HOUSE_CLOSED")
    -- BoP reads GetItemInfo's bindType on this client too
    local keepGII = GetItemInfo
    GetItemInfo = function(id) if id == 7276 then return "x", nil, 1, 5, 1, "Armor", "Cloth", 1, "", 1, 64, 4, 1, 1 end return keepGII(id) end
    EXPECT(P:IsBoP(7276) and not P:IsBoP(2934), "BoP on TBC Anniversary")
    -- TEST-c: the vendor table counts only vendors placed in the world;
    -- cmangos's test vendor 26304 had every primal at 1g 60s (TEST-b3 B10)
    EXPECT(P:VendorBuy(23572) == nil and P:VendorBuy(22450) == nil and P:VendorBuy(2320) == 10,
           "vendor table: Primal Nether, Void Crystal or Coarse Thread")
    GetItemInfo = function(id) if id == 23572 then return "Primal Nether", nil, 2, 1, 1, "Trade Goods", "Elemental", 20, "", 1, 0, 7, 0, 1 end return keepGII(id) end
    local nether = P:MaterialPrice(23572)
    EXPECT(nether.bop and nether.unit == nil, "Primal Nether is not ? (BoP)")
    GetItemInfo = keepGII
    GetSubZoneText, C_Map = keepSub, keepMap
    StaticPopup_Show, StaticPopupDialogs = keepPopup, keepDialogs
    P:ClearRecorded()
end
print("  PASS " .. TAG .. "11 auction prices on TBC Anniversary: browsed pages, Scan my materials by exact name cheapest first, the game's search and full-scan limits, full scan read from index 1, another addon's full scan left alone; PB's tab as the fourth AuctionFrameTab, PB when crowded; Gadgetzan not recorded; BoP; no vendor price from unplaced vendors")

-- U12 TEST-c (N1, N2): the main window's strip on TBC Anniversary is
-- secure buttons with the same /cast macros, so the window waits for
-- combat to end to open or close (decision D3), with one chat line; a
-- bottom tab parks the open profession and Back brings it back
do
    local UI, TSF = PB.UI, PB.TradeSkillFrame
    local strip = UI.profStrip
    EXPECT(strip and strip.secure, "no secure strip in the main window on TBC Anniversary")
    local lw = strip.byName.Leatherworking
    EXPECT(lw and lw:GetAttribute("type") == "macro" and lw:GetAttribute("macrotext") == "/cast Leatherworking",
           "the strip's Leatherworking macro: " .. tostring(lw and lw:GetAttribute("macrotext")))
    if UI.frame:IsShown() then UI:Hide() end
    local keepICL = InCombatLockdown
    InCombatLockdown = function() return true end
    PRINTS = {}
    UI:Show()
    EXPECT(not UI.frame:IsShown() and PRINTED("opens when combat ends"), "the main window opened in combat")
    UI:Show()
    local n = 0
    for _, l in ipairs(PRINTS) do if l:find("when combat ends", 1, true) then n = n + 1 end end
    EXPECT(n == 1, "the combat line said " .. n .. " times")
    InCombatLockdown = keepICL
    FIRE("PLAYER_REGEN_ENABLED")
    EXPECT(UI.frame:IsShown(), "the main window did not open when combat ended")
    InCombatLockdown = function() return true end
    UI:Hide()
    EXPECT(UI.frame:IsShown(), "the main window closed in combat")
    InCombatLockdown = keepICL
    FIRE("PLAYER_REGEN_ENABLED")
    EXPECT(not UI.frame:IsShown(), "the main window did not close when combat ended")
    EXPECT(UI.backBtn and not UI.backBtn:IsShown(), "Back shown with nothing parked")
end
-- G1 on TBC Anniversary too: the reply opens the guildmate's profession
do
    local GP, C, S = PB.GuildPanel, PB.Comm, PB.db
    local opened = 0
    local keepReq = C.RequestGuildSync
    C.RequestGuildSync = function() end
    local K = PB:NormKey("Sticker-Realm")
    S.characters[K] = nil
    GP:AskThenOpen(K, "Tailoring", function() opened = opened + 1 end)
    S.characters[K] = { isRemote = true, professions = { Tailoring = { recipes = { ["Bolt of Linen Cloth"] = true } } } }
    C:NotifyUIRefresh()
    EXPECT(opened == 1, "G1 did not open on TBC Anniversary")
    S.characters[K] = nil
    C.RequestGuildSync = keepReq
end
print("  PASS " .. TAG .. "12 the main window's strip on TBC Anniversary: secure /cast buttons; the window opens and closes when combat ends, one chat line; G1 opens a guildmate's profession when the reply arrives")

-- U13 TEST-c4: the parked profession's icon in the main window works as
-- Back. Its /cast would close a profession whose window is open, so a
-- plain button sits over it, also through combat
local function U13()
    local UI, TSF = PB.UI, PB.TradeSkillFrame
    local cover, lw = UI.parkedTab, UI.profStrip.byName.Leatherworking
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI:Hide(); FLUSH() end
    OPEN_TRADE()
    EXPECT(TSF.frame:IsShown() and TSF.state.profName == "Leatherworking", "Leatherworking did not open")
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])        -- Characters
    FLUSH()
    EXPECT(TSF._parked and UI.frame:IsShown() and lw:IsShown(), "not parked, or no Leatherworking icon")
    EXPECT(cover:IsShown() and rawget(cover, "_allPoints") == lw, "no button over the parked icon")
    cover:GetScript("OnClick")(cover)
    FLUSH()
    EXPECT(TSF.frame:IsShown() and not UI.frame:IsShown() and not TSF._parked and TBC.open == "trade",
           "the parked icon did not work as Back")
    -- in combat: the button stays over the icon and Back waits for combat
    TSF.navTabs[2]:GetScript("OnClick")(TSF.navTabs[2])        -- Friends
    FLUSH()
    local keepICL = InCombatLockdown
    InCombatLockdown = function() return true end
    UI:UpdateBack()
    EXPECT(cover:IsShown() and rawget(cover, "_allPoints") == lw, "the button left the icon in combat")
    PRINTS = {}
    cover:GetScript("OnClick")(cover)
    EXPECT(PRINTED("opens when combat ends") and TBC.open == "trade", "the parked icon in combat")
    InCombatLockdown = keepICL
    FIRE("PLAYER_REGEN_ENABLED"); FLUSH()
    EXPECT(TSF.frame:IsShown() and not TSF._parked and not UI.frame:IsShown(), "Back did not open when combat ended")
    -- the park ends: the button goes
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1])
    FLUSH()
    CLOSE_TRADE()
    EXPECT(not TSF._parked and not cover:IsShown(), "the button outlived the park")
    -- Smelting (Mining's window on TBC Anniversary) sits under the Mining icon
    local mining = UI.profStrip.byName.Mining
    local wasShown = mining:IsShown()
    rawset(mining, "_shown", true)
    TSF._parked = { prof = "Smelting", display = "Smelting", isCraft = false }
    UI:UpdateParkedTab()
    EXPECT(cover:IsShown() and rawget(cover, "_allPoints") == mining, "no button over Mining for parked Smelting")
    TSF._parked = nil
    UI:UpdateParkedTab()
    rawset(mining, "_shown", wasShown)
    EXPECT(not cover:IsShown(), "the button stayed with nothing parked")
    if UI.frame:IsShown() then UI:Hide(); FLUSH() end
end
U13()
print("  PASS " .. TAG .. "13 the parked profession's icon in the main window works as Back on TBC Anniversary, in combat too, Smelting under Mining; gone when the park ends")

-- U14 TEST-c6: m4ru's TEST-c5 run: Leatherworking open, in combat, he
-- clicked Characters, and the game blocked ProfBuddyTradeSkillFrame:Hide().
-- The harness blocks what the game blocks (BLOCKED). In combat: the
-- bottom tabs (also from Enchanting), /pb, and dragging either window.
local function U14()
    local UI, TSF = PB.UI, PB.TradeSkillFrame
    local keepICL = InCombatLockdown
    local function fight(on) InCombatLockdown = on and function() return true end or keepICL end
    local function ended() fight(false); FIRE("PLAYER_REGEN_ENABLED"); FLUSH() end
    local function ok(label) EXPECT(#BLOCKED == 0, label .. ": the game would block " .. table.concat(BLOCKED, ", ")) end
    local function clean()
        fight(false)
        if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide() end
        if UI.frame:IsShown() then UI:Hide() end
        FLUSH(); BLOCKED = {}
        if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
    end
    clean()
    EXPECT(TSF.frame:IsProtected() and UI.frame:IsProtected(), "harness: the windows are not protected")
    -- his case, and each other tab
    for i, name in ipairs({ "Characters", "Friends", "Guild", "Orders", "Shuffle" }) do
        clean(); OPEN_TRADE()
        fight(true); PRINTS = {}
        TSF.navTabs[i]:GetScript("OnClick")(TSF.navTabs[i]); FLUSH()
        ok(name .. " in combat")
        EXPECT(TSF.frame:IsShown() and not TSF._parked and not UI.frame:IsShown()
               and PRINTED(name .. " opens when combat ends."), name .. " in combat: no wait")
        ended()
        ok(name .. " after combat")
        EXPECT(not TSF.frame:IsShown() and TSF._parked and UI.frame:IsShown() and UI.backBtn:IsShown(),
               name .. " did not open, parked, when combat ended")
    end
    -- from Enchanting (the craft window)
    clean(); OPEN_CRAFT()
    EXPECT(TSF.frame:IsShown() and TSF.state.isCraftWindow, "Enchanting did not open")
    fight(true)
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1]); FLUSH()
    ok("Characters from Enchanting in combat")
    ended()
    EXPECT(TSF._parked and TSF._parked.isCraft and UI.frame:IsShown(), "Enchanting not parked after combat")
    -- /pb with the profession window open
    clean(); OPEN_TRADE()
    fight(true)
    SlashCmdList.PROFBUDDY(""); FLUSH()
    ok("/pb in combat")
    ended()
    EXPECT(not TSF.frame:IsShown() and UI.frame:IsShown(), "/pb did not open when combat ended")
    EXPECT(TSF._parked and UI.backBtn:IsShown(), "/pb closed the profession instead of keeping it behind (Back)")
    -- dragging either window in combat
    fight(true)
    UI.frame:GetScript("OnDragStart")(UI.frame); UI.frame:GetScript("OnDragStop")(UI.frame)
    ok("dragging the main window in combat")
    clean(); OPEN_TRADE()
    fight(true)
    TSF.frame:GetScript("OnDragStart")(TSF.frame); TSF.frame:GetScript("OnDragStop")(TSF.frame)
    ok("dragging the profession window in combat")
    -- each window's X or Escape in combat (the game's own close), parked too
    GAME_CLOSE(TSF.frame); FLUSH()
    ok("the profession window's X in combat")
    ended()
    clean(); OPEN_TRADE()
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1]); FLUSH()
    EXPECT(TSF._parked and UI.frame:IsShown(), "not parked before the X test")
    fight(true)
    GAME_CLOSE(UI.frame); FLUSH()
    ok("the main window's X in combat, parked")
    EXPECT(not TSF._parked, "the park outlived the main window's X in combat")
    ended()
    ok("after the main window's X in combat")
    clean()
end
U14()
print("  PASS " .. TAG .. "14 in combat on TBC Anniversary: the bottom tabs (from Enchanting too), /pb, dragging either window, and either window's X (parked too): nothing the game blocks; each runs when combat ends")

-- U15 TEST-c6: m4ru's TEST-c6 run: Leatherworking open, in combat, the
-- game's TRADE_SKILL_UPDATE redrew the craft bar and the game blocked
-- Frame:Show() 9 times (the secure Enchant button was anchored to the
-- craft bar, which protects it). His case first, then every visible
-- button of both windows in combat, with Enchanting's craft button set
-- as combat starts.
local function U15()
    local UI, TSF = PB.UI, PB.TradeSkillFrame
    local keepICL = InCombatLockdown
    local function clean()
        InCombatLockdown = keepICL
        if TSF.settingsPanel and TSF.settingsPanel:IsShown() then TSF:CloseSettings() end
        if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide() end
        if UI.frame:IsShown() then UI:Hide() end
        FLUSH(); FIRE("PLAYER_REGEN_ENABLED"); FLUSH(); BLOCKED = {}
        if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
    end
    local function none(tag, sites, errs)
        EXPECT(#sites == 0, tag .. ": the game would block:\n  " .. table.concat(sites, "\n  "))
        EXPECT(#errs == 0, tag .. ": a click errored:\n  " .. table.concat(errs, "\n  "))
    end
    -- his case
    clean(); OPEN_TRADE()
    TSF.state.selected = "Light Leather"; TSF:RefreshDetailPanel(); TSF:UpdateCraftBar()
    InCombatLockdown = function() return true end
    FIRE("TRADE_SKILL_UPDATE"); FLUSH()
    EXPECT(#BLOCKED == 0, "TRADE_SKILL_UPDATE in combat: " .. table.concat(BLOCKED, ", "))
    InCombatLockdown = keepICL
    -- the Enchant button goes off as combat starts, and back after
    clean(); OPEN_CRAFT()
    for _, e in ipairs(TSF.state.recipes or {}) do if not e.isHeader then TSF.state.selected = e.name; break end end
    TSF:RefreshDetailPanel(); TSF:UpdateCraftBar()
    TSF.enchantCraftBtn:EnableMouse(true)          -- as with materials in the bags
    FIRE("PLAYER_REGEN_DISABLED")
    EXPECT(not TSF.enchantCraftBtn:IsMouseEnabled(), "the Enchant button still takes clicks as combat starts")
    InCombatLockdown = function() return true end
    FIRE("CRAFT_UPDATE"); FLUSH()
    EXPECT(#BLOCKED == 0, "CRAFT_UPDATE in combat: " .. table.concat(BLOCKED, ", "))
    InCombatLockdown = keepICL
    -- every visible button, each window
    clean(); OPEN_TRADE(); TSF.state.selected = "Light Leather"; TSF:RefreshDetailPanel(); TSF:UpdateCraftBar()
    none("Leatherworking", COMBAT_SWEEP({ TSF.frame, TSF.calcPanel }, { "TRADE_SKILL_UPDATE", "BAG_UPDATE", "BAG_UPDATE_DELAYED" }))
    clean(); OPEN_CRAFT()
    for _, e in ipairs(TSF.state.recipes or {}) do if not e.isHeader then TSF.state.selected = e.name; break end end
    TSF:RefreshDetailPanel(); TSF:UpdateCraftBar(); FIRE("PLAYER_REGEN_DISABLED")
    none("Enchanting", COMBAT_SWEEP({ TSF.frame, TSF.calcPanel }, { "CRAFT_UPDATE", "BAG_UPDATE", "BAG_UPDATE_DELAYED" }))
    clean(); OPEN_TRADE(); TSF:OpenSettings("profession"); FLUSH()
    none("Settings", COMBAT_SWEEP({ TSF.frame }, {}))
    for i = 1, #UI.frame.tabs do
        clean(); UI:Show(); UI:SelectTab(i); FLUSH()
        none("the main window, tab " .. i, COMBAT_SWEEP({ UI.frame }, {}))
    end
    clean(); OPEN_TRADE(); TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1]); FLUSH()
    none("the main window, parked", COMBAT_SWEEP({ UI.frame }, {}))
    clean()
end
U15()
print("  PASS " .. TAG .. "15 in combat on TBC Anniversary: his TRADE_SKILL_UPDATE case, Enchanting's craft update, then every visible button of both windows (parked too) and Settings: nothing the game blocks, no errors")

-- U16 2.1.1: TBC Anniversary's recipe data had a count per craft only
-- for Smelt Bronze; 97 others read 1 (tools/yield_db.py). The data, the
-- bolts (1, not 2 and 3), a price per craft of 4, and the Material
-- Calculator planning one craft of Elemental Blasting Powder (makes 4)
-- for 3, not three
local function U16()
    local RDB, MC, TSF = PB.RecipeDB, PB.MaterialCalc, PB.TradeSkillFrame
    local E = RDB.data.Engineering
    EXPECT(E["Elemental Blasting Powder"].yield == 4 and E["Crafted Heavy Shot"].yield == 200
           and E["Coarse Dynamite"].yieldMin == 1 and E["Coarse Dynamite"].yieldMax == 3,
           "TBC counts in the data")
    EXPECT(E["Handful of Copper Bolts"].yield == nil and E["Handful of Fel Iron Bolts"].yield == nil, "the bolts make 1")
    EXPECT(RDB.data.Smelting["Smelt Bronze"].yield == 2, "Smelt Bronze still makes 2")
    -- an engineer alt who makes the powder
    local chars = PB.db.characters
    chars["Gnome-Realm"] = { professions = { Engineering = { recipes = { ["Elemental Blasting Powder"] = {} } } } }
    local list = MC:GetShoppingList("Gnomish Flame Turret", "Engineering", 1)
    local need = {}
    for _, e in ipairs(list) do need[e.itemID] = e.need end
    EXPECT(need[22574] == 1 and need[22573] == 2, "the calculator planned powder crafts: Mote of Fire "
           .. tostring(need[22574]) .. ", Mote of Earth " .. tostring(need[22573]))
    chars["Gnome-Realm"] = nil
    -- the detail panel on TBC Anniversary too
    OPEN_TRADE()
    local st = TSF.state
    local keepProf = st.profName
    st.profName = "Engineering"
    local fake = { name = "Elemental Blasting Powder", isKnown = true, numAvail = 5, itemID = 23781, spellID = 30303, category = "Parts" }
    table.insert(st.recipes, 1, fake)
    st.selected = fake.name
    TSF:RefreshDetailPanel()
    EXPECT(TSF.detCount:GetText() == "4" and (TSF.detCanMake:GetText() or ""):find("Can make: 5 (20)", 1, true),
           "TBC detail: " .. tostring(TSF.detCount:GetText()) .. " / " .. tostring(TSF.detCanMake:GetText()))
    -- TEST-a4: a long price line wraps whole pieces, his powder line
    -- (image 149) put "3c" of the profit alone on the second line
    local function plain(t)
        return ((t or ""):gsub("|T[^|]*|t", function(icon)
            return icon:find("GoldIcon") and "g" or icon:find("SilverIcon") and "s" or "c"
        end):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    local keepAuc, S = Auctionator, PB.db.settings
    local keepShow, keepAucOn = S.showPrices, S.priceAuctionator
    S.showPrices, S.priceAuctionator = true, true
    Auctionator = { API = { v1 = {
        GetAuctionPriceByItemID = function(_, id) return ({ [23781] = 29993, [22574] = 15000, [22573] = 10335 })[id] end,
        GetAuctionAgeByItemID = function() return 0 end,
    } } }
    if PB.Prices.ResetListCache then PB.Prices:ResetListCache() end
    local line, charW, width = TSF.detPrice, 4, 0
    rawset(line, "GetWidth", function() return width end)
    rawset(line, "GetUnboundedStringWidth", function(self) return #plain(self:GetText()) * charW end)
    local r = PB.Prices:RecipeCost(fake, "Engineering")
    local pc = PB.Prices:DetailPieces(r)
    -- his figures; the harness has no vendor price for the powder (F94
    -- covers the vendor piece)
    EXPECT(#pc == 3 and plain(pc[1].text) == "Cost: 3g 56s 70c" and plain(pc[2].text) == "Auction: 11g 99s 72c"
           and plain(pc[3].text) == "Profit: +7g 83s 3c",
           "the powder's pieces: " .. #pc .. " " .. plain(pc[1].text) .. " / " .. plain(pc[2].text) .. " / " .. plain(pc[#pc].text))
    local one = plain(pc[1].text .. "   " .. pc[2].text)
    -- room for everything but the profit: the profit moves down whole
    width = (#one + 4) * charW
    TSF:RefreshDetailPanel()
    EXPECT(plain(line:GetText()) == one .. "\n" .. plain(pc[3].text), "wrapped: " .. plain(line:GetText()))
    -- wide: one line, as before
    width = 1000
    TSF:RefreshDetailPanel()
    EXPECT(plain(line:GetText()) == one .. "   " .. plain(pc[3].text), "wide: " .. plain(line:GetText()))
    -- narrow: each piece on its own line
    width = 20 * charW
    TSF:RefreshDetailPanel()
    EXPECT(plain(line:GetText()) == table.concat({ plain(pc[1].text), plain(pc[2].text), plain(pc[3].text) }, "\n"),
           "narrow: " .. plain(line:GetText()))
    rawset(line, "GetWidth", nil); rawset(line, "GetUnboundedStringWidth", nil)
    Auctionator, S.showPrices, S.priceAuctionator = keepAuc, keepShow, keepAucOn
    if PB.Prices.ResetListCache then PB.Prices:ResetListCache() end
    table.remove(st.recipes, 1)
    st.profName, st.selected = keepProf, nil
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() end
end
U16()
print("  PASS " .. TAG .. "16 2.1.1: TBC Anniversary counts per craft from the game's table (powder 4, shot 200, dynamite 1-3, bolts 1), the calculator plans one powder craft for 3, the detail panel shows 4 and Can make 5 (20); a long price line wraps whole pieces (his powder: the profit moves down whole)")

-- U17 2.1.1 (m4ru 2026-11-11): on TBC Anniversary the icon's /cast
-- closed the Leatherworking session left open behind a greyed-out
-- profession, so it took a second click. The list closes the session (the
-- window stays), so the /cast opens it.
local function U17()
    local TSF = PB.TradeSkillFrame
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open then CLOSE_TRADE() end
    OPEN_TRADE()
    EXPECT(TSF.frame:IsShown() and TBC.open == "trade", "Leatherworking did not open")
    TSF:OpenWithStatic("Alchemy"); FLUSH()
    EXPECT(TSF.frame:IsShown() and TSF.state._isStaticView and TSF.state.profName == "Alchemy",
           "the greyed-out profession: " .. tostring(TSF.state.profName))
    EXPECT(TBC.open == nil, "the Leatherworking session stayed open behind it (its /cast would close it)")
    -- the game's close event can come a moment later: the list stays
    FIRE("TRADE_SKILL_CLOSE"); FLUSH()
    EXPECT(TSF.frame:IsShown() and TSF.state._isStaticView, "a late close event closed the read-only list")
    OPEN_TRADE()                        -- the icon's /cast opens it
    EXPECT(TSF.frame:IsShown() and TSF.state.profName == "Leatherworking" and not TSF.state._isStaticView,
           "Leatherworking after the greyed-out profession")
    -- Enchanting's window (the craft session) the same
    TSF.frame:Hide(); FLUSH()
    if TBC.open then CLOSE_TRADE() end
    OPEN_CRAFT()
    TSF:OpenWithStatic("Alchemy"); FLUSH()
    EXPECT(TSF.frame:IsShown() and TBC.open == nil, "the Enchanting session stayed open, or the window closed")
    -- a character's stored recipes
    TSF.frame:Hide(); FLUSH()
    OPEN_TRADE()
    TSF:OpenWithCharacter(PB:PlayerKey(), "Leatherworking"); FLUSH()
    EXPECT(TSF.frame:IsShown() and TSF.state._viewCharKey and TBC.open == nil,
           "a character's recipes left the session open, or closed the window")
    TSF.frame:Hide(); FLUSH()
end
U17()
print("  PASS " .. TAG .. "17 2.1.1: a greyed-out profession or a character's recipes closes your open profession (trade and Enchanting) and keeps the window, so its icon's /cast opens it with one click")

-- U18 2.1.1 (Sushicats): crafting stations on TBC Anniversary, from
-- Data/Tools.lua, always white: the game's GetTradeSkillTools says a
-- station is met at any distance ("Forge 1" far away and at the forge,
-- m4ru TEST-a7), so PB doesn't ask it
local function U18()
    local TSF = PB.TradeSkillFrame
    EXPECT(TSF:StationFor(2661) == "Anvil", "no Anvil for Copper Chain Belt: " .. tostring(TSF:StationFor(2661)))
    EXPECT(TSF:StationFor(2657) == "Forge", "no Forge for Smelt Copper: " .. tostring(TSF:StationFor(2657)))
    EXPECT(PB.Source.Requirements == nil, "TBC Anniversary asks the game about stations")
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open then CLOSE_TRADE() end
    OPEN_TRADE()
    local keep, keepF = GetTradeSkillTools, GetCraftSpellFocus
    GetTradeSkillTools = function() return "Anvil", nil, "Blacksmith Hammer", 1 end
    GetCraftSpellFocus = function() return "Black Forge", nil end
    local belt = { name = "Copper Chain Belt", spellID = 2661, itemID = 2851, gameIndex = 7, isKnown = true }
    EXPECT(TSF:StationMet(belt, "Anvil") == nil, "a station checked on TBC Anniversary")
    local tip, out = CreateFrame("GameTooltip"), {}
    rawset(tip, "AddLine", function(_, t, r, g, b) if t ~= " " then out[#out + 1] = { t, r, g, b } end end)
    TSF:AppendRodLine(tip, belt)
    local anvil
    for _, l in ipairs(out) do if l[1]:find("Anvil", 1, true) then anvil = l end end
    EXPECT(anvil and anvil[1] == "Tool: Anvil" and anvil[2] == 1 and anvil[3] == 1 and anvil[4] == 1,
           "the Anvil line: " .. tostring(anvil and anvil[1]))
    GetTradeSkillTools, GetCraftSpellFocus = keep, keepF
    TSF.frame:Hide(); FLUSH()
end
U18()
print("  PASS " .. TAG .. "18 2.1.1: crafting stations on TBC Anniversary (Copper Chain Belt an Anvil, Smelt Copper a Forge), always white: the game's check ignores distance, so PB doesn't ask it")

-- U19 2.2.0 TEST-a: the vendor shuffle on TBC Anniversary: the cast time
-- from GetSpellInfo's 4th value, the Shuffle tab, the profession window's
-- Vendor shuffle View, and both in combat with rows in them
local function U19()
    local UI, TSF, P, SP, S = PB.UI, PB.TradeSkillFrame, PB.Prices, PB.ShufflePanel, PB.db.settings
    local st = TSF.state
    local keepAuc, keepSpell = Auctionator, GetSpellInfo
    local keepMin, keepShow, keepAucOn = S.shuffleMinProfit, S.showPrices, S.priceAuctionator
    S.showPrices, S.priceAuctionator, S.shuffleMinProfit = true, true, 0
    -- Ruined Leather Scraps 1c at auction; Light Leather sells for 5c
    Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return ({ [2934] = 1 })[id] end,
                                   GetAuctionAgeByItemID = function() return 0 end } } }
    GetSpellInfo = function(id)
        if id == 2881 then return "Light Leather", nil, "icon", 3000 end
        return keepSpell(id)
    end
    local v = P:VendorShuffle({ name = "Light Leather" }, "Leatherworking")
    EXPECT(v and v.cost == 3 and v.sell == 5 and v.profit == 2 and v.seconds == 3.5,
           "Light Leather: " .. tostring(v and v.cost) .. " " .. tostring(v and v.sell) .. " " .. tostring(v and v.seconds))
    -- the tab
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    UI:Show()
    UI:SelectTab(5); FLUSH()
    SP.sortKey, SP.sortAsc, SP.whoFilter, SP.profFilter, SP.vendorOnly = "profit", false, "Everyone", nil, false
    SP:Refresh()
    local found = false
    for _, e in ipairs(SP.list) do if e.name == "Light Leather" then found = true end end
    EXPECT(found, "the Shuffle tab has no Light Leather")
    local sites, errs = COMBAT_SWEEP({ UI.frame }, {})
    EXPECT(#sites == 0, "the Shuffle tab in combat, the game would block:\n  " .. table.concat(sites, "\n  "))
    EXPECT(#errs == 0, "the Shuffle tab in combat, a click errored:\n  " .. table.concat(errs, "\n  "))
    FIRE("PLAYER_REGEN_ENABLED"); FLUSH()
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI:Hide() end
    -- the profession window's Vendor shuffle View
    OPEN_TRADE()
    st.showTab = "vendor"
    TSF:RefreshRecipeList()
    local names = {}
    for _, r in ipairs(st.recipes) do if not r.isHeader then names[#names + 1] = r.name end end
    EXPECT(#names == 1 and names[1] == "Light Leather", "the Vendor shuffle View lists: " .. table.concat(names, ", "))
    local sig = rawget(TSF.viewDropdown, "_optionSig") or ""
    EXPECT(sig:find("Vendor shuffle", 1, true), "no Vendor shuffle in the View menu")
    sites, errs = COMBAT_SWEEP({ TSF.frame }, { "TRADE_SKILL_UPDATE" })
    EXPECT(#sites == 0, "the Vendor shuffle View in combat, the game would block:\n  " .. table.concat(sites, "\n  "))
    EXPECT(#errs == 0, "the Vendor shuffle View in combat, a click errored:\n  " .. table.concat(errs, "\n  "))
    FIRE("PLAYER_REGEN_ENABLED"); FLUSH()
    st.showTab = "known"
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI:Hide() end
    if TBC.open == "trade" then CLOSE_TRADE() end
    Auctionator, GetSpellInfo = keepAuc, keepSpell
    S.shuffleMinProfit, S.showPrices, S.priceAuctionator = keepMin, keepShow, keepAucOn
    P:ResetListCache()
end
U19()
print("  PASS " .. TAG .. "19 2.2.0 TEST-a: vendor shuffle on TBC Anniversary: cast time from GetSpellInfo, the Shuffle tab, the Vendor shuffle View, both swept in combat with rows")

-- U20 2.2.0 TEST-a5 (m4ru): your own recipe from the Shuffle tab on TBC
-- Anniversary: the live window when the profession is open; with it
-- closed (PB can't open one from a click there), your saved list, saying
-- to open the profession, without Request Craft
local function U20()
    local TSF = PB.TradeSkillFrame
    local st = TSF.state
    local me = PB:PlayerKey()
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open then CLOSE_TRADE() end
    OPEN_TRADE()
    TSF:OpenRecipeFor(me, "Leatherworking", "Light Leather"); FLUSH()
    EXPECT(TSF.frame:IsShown() and not st._viewCharKey and st.selected == "Light Leather" and TSF.craftBar:IsShown()
           and not TSF.ownHintBar:IsShown(), "open: " .. tostring(st._viewCharKey) .. " / " .. tostring(st.selected))
    -- open, then /pb (TEST-a6: /pb closed the profession, so the row
    -- found it closed): /pb keeps it open behind, and the row shows it live
    TSF.frame:Hide(); FLUSH()
    if TBC.open then CLOSE_TRADE() end
    OPEN_TRADE()
    SlashCmdList.PROFBUDDY(""); FLUSH()
    EXPECT(TSF._parked and TBC.open == "trade" and PB.UI.frame:IsShown(), "/pb closed the open profession")
    TSF:OpenRecipeFor(me, "Leatherworking", "Light Leather"); FLUSH()
    EXPECT(TSF.frame:IsShown() and not st._viewCharKey and st.selected == "Light Leather" and TSF.craftBar:IsShown()
           and not PB.UI.frame:IsShown() and not TSF._parked, "after /pb: " .. tostring(st._viewCharKey) .. " / " .. tostring(st.selected))
    TSF.frame:Hide(); FLUSH()
    if TBC.open then CLOSE_TRADE() end
    TSF:OpenRecipeFor(me, "Leatherworking", "Light Leather"); FLUSH()
    EXPECT(TSF.frame:IsShown() and st._viewCharKey and st.selected == "Light Leather", "closed: shown " .. tostring(TSF.frame:IsShown()) .. " view " .. tostring(st._viewCharKey) .. " sel " .. tostring(st.selected) .. " tab " .. tostring(st.showTab) .. " n " .. #st.recipes)
    EXPECT(TSF.ownHintBar:IsShown() and not TSF.composerBar:IsShown() and not TSF.craftBar:IsShown(),
           "closed: hint " .. tostring(TSF.ownHintBar:IsShown()) .. ", request " .. tostring(TSF.composerBar:IsShown()))
    EXPECT((TSF.ownHintBar.text:GetText() or ""):find("Open Leatherworking from your spellbook to craft", 1, true), "hint text")
    TSF.frame:Hide(); FLUSH()
end
U20()
print("  PASS " .. TAG .. "20 2.2.0 TEST-a5: your own recipe from the Shuffle tab: the live window when open; closed, your saved list with how to craft, no Request Craft")

-- U21 2.2.0 TEST-b: TBC Anniversary has no Waylaid Supplies or Craftsman's
-- Writs: no Crates and writs view, no switch, the Shuffle tab as before
local function U21()
    local SP = PB.ShufflePanel
    EXPECT(PB.CratesView == nil and PB.Waylaid == nil and PB.Writs == nil, "crate data or the view loads on TBC Anniversary")
    if not SP.parent then
        PB.UI:Show()
        for i, tab in ipairs(PB.UI.frame.tabs) do if tab.name == "shuffle" then PB.UI:SelectTab(i) end end
        FLUSH()
    end
    EXPECT(SP.parent and SP.viewBtns == nil and rawget(SP.header, "_vis") ~= false and SP.view == "shuffle", "a view switch on TBC Anniversary")
    if PB.UI.frame:IsShown() then PB.UI:Hide(); FLUSH() end
end
U21()
print("  PASS " .. TAG .. "21 2.2.0 TEST-b: no Crates and writs view on TBC Anniversary: no switch, the heading as before")

-- U22 2.2.0 TEST-b, GitHub #12: the Item info fold and Show Item info on
-- TBC Anniversary, with an Anvil and a Blacksmith Hammer as the tool lines
local function U22()
    local TSF = PB.TradeSkillFrame
    local st, S = TSF.state, PB.db.settings
    local keepFold, keepShow = S.itemInfoFolded, S.showItemInfo
    S.itemInfoFolded, S.showItemInfo = false, true
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open then CLOSE_TRADE() end
    OPEN_TRADE()
    local belt = { name = "Copper Chain Belt", spellID = 2661, itemID = 2851, isKnown = true,
                   reagents = { { itemID = 2840, count = 6, name = "Copper Bar" } } }
    table.insert(st.recipes, 1, belt)
    st.selected = belt.name
    TSF:RefreshDetailPanel()
    EXPECT(TSF.itemTooltipHeader:GetText() == "- Item info" and TSF.itemInfoFold:IsShown(), "open")
    TSF.itemInfoFold:GetScript("OnClick")(TSF.itemInfoFold); FLUSH()
    local tools = TSF.detTools:GetText() or ""
    EXPECT(S.itemInfoFolded and not TSF.embeddedTip:IsShown() and TSF.itemTooltipHeader:GetText() == "+ Item info"
           and tools:find("Tool: Anvil", 1, true) and tools:find("Blacksmith Hammer", 1, true), "folded: " .. tools)
    TSF.itemInfoFold:GetScript("OnClick")(TSF.itemInfoFold); FLUSH()
    S.showItemInfo = false; TSF:RefreshDetailPanel()
    EXPECT(not TSF.itemTooltipHeader:IsShown() and TSF.detTools:IsShown(), "off")
    table.remove(st.recipes, 1)
    st.selected = nil
    S.itemInfoFolded, S.showItemInfo = keepFold, keepShow
    TSF.frame:Hide(); FLUSH()
end
U22()
print("  PASS " .. TAG .. "22 2.2.0 TEST-b #12: Item info fold and Show Item info on TBC Anniversary; the Anvil and Hammer lines move under the price line")

-- U23 2.2.0 TEST-c (Kluga; m4ru): on TBC Anniversary too, a batch keeps
-- counting down through every way back into its profession: Back after a
-- bottom tab and /pb, the parked icon, your own Shuffle row. The Shuffle
-- tab's columns all sort, a second click the other way, with ^ or v
local function U23()
    local UI, TSF, SP, S = PB.UI, PB.TradeSkillFrame, PB.ShufflePanel, PB.db.settings
    local st = TSF.state
    local me = PB:PlayerKey()
    -- FLUSH runs every pending timer at once, the 10-second watchdog too
    local keepArm, keepName = TSF.ArmCraftWatchdog, SPELL_NAMES[2881]
    TSF.ArmCraftWatchdog = function() end
    SPELL_NAMES[2881] = "Light Leather"   -- the cast's name: TBC Anniversary matches the craft by name
    local row = TBC.tradeRows[2]
    local keepAvail = row[3]
    row[3] = 10
    local function cast(ev) FIRE(ev or "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-guid", 2881) end
    local function clean()
        if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
        if UI.frame:IsShown() then UI:Hide(); FLUSH() end
        if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
        TSF:StopCraftTracking()
    end
    local function tab(i) return function() TSF.navTabs[i]:GetScript("OnClick")(TSF.navTabs[i]); FLUSH() end end
    local function backBtn() UI.backBtn:GetScript("OnClick")(UI.backBtn); FLUSH() end
    local function cover() UI.parkedTab:GetScript("OnClick")(UI.parkedTab); FLUSH() end
    local function run(label, leave, back)
        clean(); OPEN_TRADE()
        st.selected = "Light Leather"; TSF:UpdateCraftBar()
        TSF:DoCraftImmediate(5)
        cast()
        EXPECT(TSF._craftingActive and TSF.qtyBox:GetText() == "4", label .. ": the first craft")
        leave()
        EXPECT(TSF._parked and UI.frame:IsShown() and TBC.open == "trade", label .. ": not parked")
        cast()
        back()
        EXPECT(TSF.frame:IsShown() and not TSF._parked and TSF._craftingActive and TSF.qtyBox:GetText() == "3",
               label .. ": back stopped the count at " .. tostring(TSF.qtyBox:GetText()))
        cast()
        EXPECT(TSF.qtyBox:GetText() == "2", label .. ": the next craft after back did not count")
    end
    run("Characters tab, Back", tab(1), backBtn)
    run("Shuffle tab, Back", tab(5), backBtn)
    run("/pb, Back", function() SlashCmdList.PROFBUDDY(""); FLUSH() end, backBtn)
    run("Friends tab, the parked icon", tab(2), cover)
    run("Characters tab, your own Shuffle row", tab(1),
        function() TSF:OpenRecipeFor(me, "Leatherworking", "Light Leather"); FLUSH() end)
    -- the game closes the profession while parked: the count stops
    clean(); OPEN_TRADE()
    st.selected = "Light Leather"; TSF:UpdateCraftBar()
    TSF:DoCraftImmediate(5)
    tab(1)()
    CLOSE_TRADE()
    EXPECT(not TSF._craftingActive and not TSF._parked, "the close while parked did not stop the count")
    clean()
    row[3] = keepAvail
    TSF.ArmCraftWatchdog, SPELL_NAMES[2881] = keepArm, keepName

    -- the Shuffle tab's columns
    local keepMin = S.shuffleMinProfit
    S.shuffleMinProfit = 0
    UI:Show(); UI:SelectTab(5); FLUSH()
    local keepAll, keepBuild = SP.all, SP.Build
    SP.Build = function() end
    local function sv(name, who, cost, sell, hour)
        return { name = name, prof = "Leatherworking", who = { { key = who, rel = "alt" } },
                 v = { cost = cost, sell = sell, profit = sell - cost, perHour = hour } }
    end
    SP.all = { sv("bolt", "Zed-Realm", 50, 300, 900), sv("Armor Kit", "amy-Realm", 10, 200, 5000),
               sv("Copper Rod", "Bo-Realm", 99, 100, 10) }
    SP.whoFilter, SP.profFilter, SP.vendorOnly = "Everyone", nil, false
    SP.sortKey, SP.sortAsc = "profit", false
    SP:Repaint()
    local function click(key) SP.headerBtns[key]:GetScript("OnClick")(SP.headerBtns[key]) end
    local function order() local t = {}; for _, e in ipairs(SP.list) do t[#t + 1] = e.name end; return table.concat(t, ",") end
    EXPECT(order() == "bolt,Armor Kit,Copper Rod" and SP.headerBtns.profit.label:GetText() == "Profit v", "Profit: " .. order())
    click("recipe")
    EXPECT(order() == "Armor Kit,bolt,Copper Rod" and SP.headerBtns.recipe.label:GetText() == "Recipe ^"
           and SP.headerBtns.profit.label:GetText() == "Profit", "Recipe A to Z: " .. order())
    click("recipe")
    EXPECT(order() == "Copper Rod,bolt,Armor Kit" and SP.headerBtns.recipe.label:GetText() == "Recipe v", "Recipe Z to A: " .. order())
    click("who")
    EXPECT(order() == "Armor Kit,Copper Rod,bolt", "Who: " .. order())
    click("cost")
    EXPECT(order() == "Armor Kit,bolt,Copper Rod" and SP.headerBtns.cost.label:GetText() == "Cost ^", "Cost: " .. order())
    click("hour"); click("hour")
    EXPECT(order() == "Copper Rod,bolt,Armor Kit" and SP.headerBtns.hour.label:GetText() == "Per hour ^", "Per hour lowest first: " .. order())
    SP.all, SP.Build = keepAll, keepBuild
    SP.sortKey, SP.sortAsc = "profit", false
    S.shuffleMinProfit = keepMin
    UI:Hide(); FLUSH()
end
U23()
print("  PASS " .. TAG .. "23 2.2.0 TEST-c: the craft count keeps going through Back (bottom tab, /pb, the parked icon, your own Shuffle row) on TBC Anniversary and stops when the game closes the profession; the Shuffle tab's columns sort both ways with ^ or v")

-- U24 2.2.0 TEST-c6: the same on TBC Anniversary: the main window is the
-- profession window's 740 x 540, the Shuffle and Guild lists fill it, and
-- the Shuffle tab's heading reads Vendor
local function U24()
    local UI, TSF, SP, GP = PB.UI, PB.TradeSkillFrame, PB.ShufflePanel, PB.GuildPanel
    TSF:EnsureFrame()
    local ws, ts = rawget(UI.frame, "_size"), rawget(TSF.frame, "_size")
    EXPECT(ws and ts and ws[1] == 740 and ws[2] == 540 and ws[1] == ts[1] and ws[2] == ts[2], "main window size")
    local contentH = ws[2] - UI.CONTENT_TOP - 10
    UI:Show()
    for i in ipairs(UI.frame.tabs) do UI:SelectTab(i) end
    FLUSH()
    EXPECT(#SP.rows * 20 <= contentH - 72 and (#SP.rows + 1) * 20 > contentH - 72, "Shuffle rows: " .. #SP.rows)
    EXPECT(#GP.rows * 20 <= contentH - 72 and (#GP.rows + 1) * 20 > contentH - 72, "Guild rows: " .. #GP.rows)
    EXPECT(SP.headerBtns.sell.colLabel == "Vendor" and SP.view ~= "crates", "Vendor heading, or a Crates view on TBC Anniversary")
    UI:Hide(); FLUSH()
end
U24()
print("  PASS " .. TAG .. "24 2.2.0 TEST-c6: the main window is 740 x 540 on TBC Anniversary, the Shuffle and Guild lists fill it, the heading reads Vendor")

-- U25 2.2.0 TEST-c7: on TBC Anniversary too, the main and profession
-- windows share one size and one place: Characters opens the main window
-- where Cooking was, Back opens Cooking where the main window was
local function U25()
    local UI, TSF, S = PB.UI, PB.TradeSkillFrame, PB.db.settings
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
    EXPECT(S.mainWindowScale == nil, "the main window still has its own size setting")
    TSF:EnsureFrame()
    rawset(UIParent, "GetWidth", function() return 1920 end)
    rawset(UIParent, "GetHeight", function() return 1080 end)
    local frames = { TSF.frame, UI.frame }
    for _, f in ipairs(frames) do
        rawset(f, "GetWidth", function() return 740 end)
        rawset(f, "GetHeight", function() return 540 end)
        rawset(f, "SetScale", function(self, v) rawset(self, "_scale", v) end)
        rawset(f, "GetScale", function(self) return rawget(self, "_scale") or 1 end)
        rawset(f, "GetLeft", function(self) local p = rawget(self, "_lastPoint"); return p and p[1] == "TOPLEFT" and p[4] or 100 end)
        rawset(f, "GetTop", function(self) local p = rawget(self, "_lastPoint"); return p and p[1] == "TOPLEFT" and p[5] or 800 end)
    end
    local T, M = TSF.frame, UI.frame
    local function placed(f) local p = rawget(f, "_lastPoint"); return p and p[1] == "TOPLEFT" and p[4], p and p[5] end
    local keepScale = S.professionWindowScale
    UI._livePos = nil
    S.professionWindowScale = 1.1
    OPEN_TRADE()
    T:ClearAllPoints(); T:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 200, 700)
    T:GetScript("OnDragStop")(T)
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1]); FLUSH()
    local x, y = placed(M)
    EXPECT(M:IsShown() and math.abs(M:GetScale() - 1.1) < 0.001 and x == 200 and y == 700,
           "the main window is not where Cooking was: " .. tostring(x) .. "," .. tostring(y))
    M:ClearAllPoints(); M:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 150, 650)
    M:GetScript("OnDragStop")(M)
    UI.backBtn:GetScript("OnClick")(UI.backBtn); FLUSH()
    x, y = placed(T)
    EXPECT(T:IsShown() and x == 150 and y == 650, "Back did not open Cooking where the main window was: " .. tostring(x) .. "," .. tostring(y))
    T:Hide(); FLUSH()
    CLOSE_TRADE()
    for _, f in ipairs(frames) do
        for _, k in ipairs({ "GetWidth", "GetHeight", "SetScale", "GetScale", "GetLeft", "GetTop" }) do rawset(f, k, nil) end
    end
    rawset(UIParent, "GetWidth", nil); rawset(UIParent, "GetHeight", nil)
    S.professionWindowScale = keepScale
    UI._livePos = nil
end
U25()
print("  PASS " .. TAG .. "25 2.2.0 TEST-c7: the main and profession windows share one size and one place on TBC Anniversary: Characters and Back open each in the other's space")

-- U26 2.2.0 TEST-c9: on TBC Anniversary too, no two controls in a
-- Friends row overlap (Order sat over Sync and the Auto-sync box)
local function rowControls(FP)
    -- the stand-in's textures and font strings record no width: a fresh
    -- row is built with recorders, then each control's left and right edge
    local F = getmetatable(UIParent)
    rawset(F, "CreateTexture", function(self) return CreateFrame("Texture", nil, self) end)
    rawset(F, "SetWidth", function(self, w) local sz = rawget(self, "_size") or {}; sz[1] = w; rawset(self, "_size", sz) end)
    local row = FP:CreateRow(CreateFrame("Frame", nil, UIParent), 1)
    rawset(F, "CreateTexture", nil); rawset(F, "SetWidth", nil)
    local list = { { "favorite star", row.favBtn }, { "name", row.nameText }, { "last sync", row.syncText },
                   { "Auto-sync box", row.autoCB }, { "Sync", row.syncBtn }, { "Remove", row.removeBtn },
                   { "Order", row.orderBtn } }
    for i, icon in ipairs(row.profIcons) do list[#list + 1] = { "profession icon " .. i, icon } end
    local out = {}
    for _, c in ipairs(list) do
        local p, sz = rawget(c[2], "_lastPoint"), rawget(c[2], "_size")
        EXPECT(p and p[1] == "LEFT" and type(p[2]) == "number" and sz and type(sz[1]) == "number",
               "the Friends row's " .. c[1] .. " has no left point and width")
        out[#out + 1] = { name = c[1], l = p[2], r = p[2] + sz[1] }
    end
    return out
end
local function U26()
    -- every control, Order included (it shows for a friend with a
    -- profession to order from), ends before the next one starts, and all
    -- end before the scroll bar: 720 px of content less 16
    local c = rowControls(PB.FriendsPanel)
    for i = 1, #c do
        EXPECT(c[i].r <= 704, "the Friends row's " .. c[i].name .. " ends at " .. c[i].r .. ", under the scroll bar")
        for j = i + 1, #c do
            EXPECT(c[i].r <= c[j].l or c[j].r <= c[i].l, "the Friends row's " .. c[i].name .. " (" .. c[i].l .. " to "
                   .. c[i].r .. ") overlaps its " .. c[j].name .. " (" .. c[j].l .. " to " .. c[j].r .. ")")
        end
    end
end
U26()
print("  PASS " .. TAG .. "26 2.2.0 TEST-c9: no two controls in a Friends row overlap on TBC Anniversary, Order included")

-- U27 2.2.0 (Lucido): Can make counting your bank on TBC Anniversary too
local function U27()
    if TBC.open ~= "trade" then OPEN_TRADE() end
    local TSF, DS = PB.TradeSkillFrame, PB.DataStore
    local st = TSF.state
    local inv = DS:GetCharacter().inventory
    local keepBank, keepScanned, keepOff, keepView = inv.bank, inv.bankScanned, st.scrollOffset, st._viewCharKey
    local keepSel = st.selected
    ITEM_COUNT = {}
    inv.bank, inv.bankScanned = {}, true
    st._viewCharKey = nil
    -- a known craft that takes 1 of a material, the game's count = the bags'
    local kit = { name = "PB Test Kit", isKnown = true, numAvail = 4, itemID = 2304, spellID = 2152,
                  category = "Armor Kit", reagents = { { itemID = 2318, count = 1, name = "Light Leather" } } }
    table.insert(st.recipes, 1, kit)
    st.scrollOffset, st.selected = 0, kit.name
    local row = TSF.listRows[1]
    local function draw() TSF:UpdateListRows(); TSF:RefreshDetailPanel() end
    local function list() return row.rightText:GetText() or "" end
    local function can() return TSF.detCanMake:GetText() or "" end
    local function nameAtCounts()
        local p = rawget(row.nameText, "_lastPoint")
        return p and p[1] == "RIGHT" and p[2] == row.rightText
    end
    -- bags make 4, the bank holds 6 more: [4] [10], "4, 10 with bank"
    ITEM_COUNT[2318], inv.bank[2318] = 4, 6
    draw()
    EXPECT(list():find("|cff00ff00[4]|r |cff3fc7ff[10]|r", 1, true), "list: " .. list())
    EXPECT(can():find("|cff00ff00Can make: 4|r|cff3fc7ff, 10 with bank|r", 1, true), "Can make: " .. can())
    EXPECT(nameAtCounts(), "the name does not stop at the counts")
    -- Colorblind markers on: "[10 bank]" in the list; in the Reagents list
    -- azure reads "0/1 bank" (yellow's "x/need" reads the same without it),
    -- and the material's name stops short of it; off: as before
    local S = PB.db.settings
    local keepCBM, keepBag = S.colorblindMarkers, inv.bags[2318]
    S.colorblindMarkers = "on"
    inv.bags[2318] = 0
    draw()
    local rrow = TSF.reagentRows[1]
    local function rpoint() return rawget(rrow.nameText, "_lastPoint") or {} end
    EXPECT(list():find("|cff3fc7ff[10 bank]|r", 1, true), "markers, list: " .. list())
    EXPECT((rrow.countText:GetText() or "") == "|cff3fc7ff0/1 bank|r", "markers, Reagents: " .. tostring(rrow.countText:GetText()))
    EXPECT(rpoint()[1] == "RIGHT" and rpoint()[2] == rrow.countText, "markers: the material's name does not stop at its count")
    S.colorblindMarkers = "off"
    draw()
    EXPECT(list():find("|cff3fc7ff[10]|r", 1, true) and (rrow.countText:GetText() or "") == "|cff3fc7ff0/1|r",
           "markers off: " .. list() .. " / " .. tostring(rrow.countText:GetText()))
    EXPECT(rpoint()[1] == "RIGHT" and rpoint()[2] == rrow and rpoint()[4] == -36, "markers off: the material's name is not back at -36")
    -- the Classic look's banner behind the material's name: cropped to its
    -- drawn bar (texels 11-116 of 128) in the same place, and ending 4 px
    -- before a count wider than the art's gap ("0/1 bank" crossed it)
    if LOOK == "classic" then
        EXPECT(rawget(rrow, "banner"), "no banner behind a material in the Classic look")
        local pts = {}
        rawset(rrow.banner, "SetPoint", function(_, ...) pts[#pts + 1] = { ... } end)
        rawset(rrow.banner, "ClearAllPoints", function() pts = {} end)
        local W = TSF._reagentColW * 2          -- one material: one column, both widths
        local left = 18 - 10 * 18 / 39
        local span = W - left
        local function ends(countW)
            rawset(rrow.countText, "GetStringWidth", function() return countW end)
            draw()
            local L, R
            for _, p in ipairs(pts) do
                if p[1] == "LEFT" and p[2] == rrow then L = p[4] elseif p[1] == "RIGHT" and p[2] == rrow and p[3] == "LEFT" then R = p[4] end
            end
            return L, R
        end
        local L, R = ends(40)
        EXPECT(L and math.abs(L - (left + span * 11 / 128)) < 0.01 and R and math.abs(R - (W - 48)) < 0.01,
               "a wide count: the banner " .. tostring(L) .. " to " .. tostring(R) .. ", width " .. W)
        L, R = ends(10)
        EXPECT(L and math.abs(L - (left + span * 11 / 128)) < 0.01 and R and math.abs(R - (W - span * 11 / 128)) < 0.01,
               "a short count: the banner " .. tostring(L) .. " to " .. tostring(R) .. " (the art's own bar ends at "
               .. (W - span * 11 / 128) .. ")")
        rawset(rrow.countText, "GetStringWidth", nil)
        rawset(rrow.banner, "SetPoint", nil); rawset(rrow.banner, "ClearAllPoints", nil)
        local src = assert(io.open(PB_BASE .. "/UI/TradeSkillFrame.lua")):read("*a")
        EXPECT(src:find("banner:SetTexCoord%(BANNER_EDGE, 1 %- BANNER_EDGE, 0, 1%)") and src:find("local BANNER_EDGE   = 11 / 128", 1, true),
               "the banner is not cropped to its bar")
    end
    S.colorblindMarkers, inv.bags[2318] = keepCBM, keepBag
    -- the bags make none: the azure count alone, red 0, not "missing"
    ITEM_COUNT[2318], kit.numAvail = 0, 0
    draw()
    EXPECT(list():find("|cff3fc7ff[6]|r", 1, true) and not list():find("cff00ff00[", 1, true), "bank only list: " .. list())
    EXPECT(can():find("|cffff4444Can make: 0|r|cff3fc7ff, 6 with bank|r", 1, true) and not can():find("missing", 1, true),
           "bank only Can make: " .. can())
    -- the bank adds nothing: no azure, the name back at its own edge
    ITEM_COUNT[2318], kit.numAvail, inv.bank[2318] = 4, 4, nil
    draw()
    EXPECT(not list():find("3fc7ff", 1, true) and not can():find("with bank", 1, true), "no bank part: " .. list() .. " / " .. can())
    EXPECT(not nameAtCounts() or PB.Prices:ListProfitOn(), "the name stops at the counts with no bank count")
    -- two of a material: the bank's 3 make 1 more, a leftover 1 makes none
    kit.reagents = { { itemID = 2318, count = 2, name = "Light Leather" } }
    ITEM_COUNT[2318], kit.numAvail, inv.bank[2318] = 4, 2, 3
    draw()
    EXPECT(list():find("|cff3fc7ff[3]|r", 1, true) and can():find(", 3 with bank", 1, true), "two each: " .. list() .. " / " .. can())
    -- no bank part: never seen the bank, the game's count is not the bags'
    -- (something else limits it), on cooldown, another character's list
    inv.bankScanned = false
    EXPECT(TSF:BankCraftCount(kit, 2) == nil, "a bank PB never saw counted")
    inv.bankScanned = true
    EXPECT(TSF:BankCraftCount(kit, 1) == nil, "counted when the game's count is not the bags'")
    local keepCD = TSF.CooldownSuffix
    TSF.CooldownSuffix = function() return "\n|cffff8800On cooldown: ready in 3h|r" end
    EXPECT(TSF:BankCraftCount(kit, 2) == nil, "counted on cooldown")
    TSF.CooldownSuffix = keepCD
    st._viewCharKey = "Alt-Realm"
    EXPECT(TSF:BankCraftCount(kit, 2) == nil, "counted on another character's list")
    st._viewCharKey = nil
    kit.reagents[2] = { name = "No ID", count = 1 }
    EXPECT(TSF:BankCraftCount(kit, 2) == nil, "counted with a material that has no item ID")
    kit.reagents[2] = nil
    EXPECT(TSF:BankCraftCount(kit, 2) == 3, "the count back: " .. tostring(TSF:BankCraftCount(kit, 2)))
    -- a craft that makes 2: the items after each count
    -- (TBC Anniversary's data: Elemental Blasting Powder makes 4)
    local keepProf = st.profName
    st.profName = "Engineering"
    local hide = { name = "Elemental Blasting Powder", isKnown = true, numAvail = 3, itemID = 23781, spellID = 30303,
                   category = "Parts", reagents = { { itemID = 22574, count = 1, name = "Mote of Fire" } } }
    table.insert(st.recipes, 1, hide)
    st.selected = hide.name
    ITEM_COUNT[22574], inv.bank[22574] = 3, 2
    draw()
    EXPECT(can():find("Can make: 3 (12)|r|cff3fc7ff, 5 (20) with bank|r", 1, true), "makes 4: " .. can())
    table.remove(st.recipes, 1)
    st.profName = keepProf
    -- a recipe as the game lists it: Light Leather, 3 scraps each, the
    -- game's count 3
    local live
    for _, e in ipairs(st.recipes) do if e.name == "Light Leather" and e.isKnown then live = e end end
    EXPECT(live and live.reagents and live.reagents[1] and live.reagents[1].itemID == 2934, "the game's Light Leather has no material ID")
    ITEM_COUNT[2934], inv.bank[2934] = 9, 6
    EXPECT(TSF:BankCraftCount(live, live.numAvail) == 5, "the game's Light Leather with the bank: "
           .. tostring(TSF:BankCraftCount(live, live.numAvail)) .. " (game count " .. tostring(live.numAvail) .. ")")
    st.selected = kit.name
    table.remove(st.recipes, 1)
    inv.bank, inv.bankScanned, st.scrollOffset, st._viewCharKey, st.selected = keepBank, keepScanned, keepOff, keepView, keepSel
    ITEM_COUNT = nil
    TSF:UpdateListRows(); TSF:RefreshDetailPanel()
    CLOSE_TRADE()
end
U27()
print("  PASS " .. TAG .. "27 2.2.0: Can make counts your bank on TBC Anniversary: [4] [10], 'Can make: 4, 10 with bank', the bank alone, the items after each count; none where it would be wrong")

-- U28 2.2.0 (GitHub #13): on TBC Anniversary a click on a material made in
-- the open profession goes to its recipe and Back returns; one made by
-- another of your professions only says so (a click can't open it there)
local function U28()
    local TSF, DS, RDB = PB.TradeSkillFrame, PB.DataStore, PB.RecipeDB
    local st = TSF.state
    if TBC.open == "trade" then CLOSE_TRADE() end
    local pack = { "PB Jump Pack", "easy", 0, nil, nil,
        reagents = { { "Light Leather", 2, 2318 }, { "Copper Bar", 1, 2840 } } }
    table.insert(TBC.tradeRows, pack)
    OPEN_TRADE()
    local inv = DS:GetCharacter().inventory
    local keepBank, keepScanned = inv.bank, inv.bankScanned
    ITEM_COUNT = { [2318] = 4 }
    inv.bank, inv.bankScanned = { [2318] = 2 }, true
    local function lines(row)
        local out = {}
        rawset(GameTooltip, "AddLine", function(_, t) out[#out + 1] = tostring(t) end)
        rawset(GameTooltip, "Show", function() end)
        row:GetScript("OnEnter")(row)
        rawset(GameTooltip, "AddLine", nil); rawset(GameTooltip, "Show", nil)
        return table.concat(out, "\n")
    end
    local function click(row) row:GetScript("OnMouseUp")(row) end
    local function rowFor(itemID)
        for _, r in ipairs(TSF.reagentRows) do if r:IsShown() and r.itemID == itemID then return r end end
    end
    for _, r in ipairs(TSF.reagentRows) do
        rawset(r.hover, "Show", function(x) rawset(x, "_on", true) end)
        rawset(r.hover, "Hide", function(x) rawset(x, "_on", false) end)
    end
    local function back() TSF.detBack:GetScript("OnClick")(TSF.detBack) end
    local function pick(name)
        for idx, e in ipairs(st.recipes) do
            if not e.isHeader and e.name == name then
                st.scrollOffset = idx - 1
                TSF.listRows[1]:GetScript("OnClick")(TSF.listRows[1], "LeftButton")
                return st.selected == name
            end
        end
        return false
    end
    local function backTip()
        local out = {}
        rawset(GameTooltip, "SetText", function(_, t) out[#out + 1] = tostring(t) end)
        rawset(GameTooltip, "Show", function() end)
        TSF.detBack:GetScript("OnEnter")(TSF.detBack)
        rawset(GameTooltip, "SetText", nil); rawset(GameTooltip, "Show", nil)
        return table.concat(out, "\n")
    end
    EXPECT(TSF:SelectRecipeForView("PB Jump Pack", false), "no PB Jump Pack in the list")
    TSF.qtyBox:SetText("5")
    local t = lines(rowFor(2318))
    EXPECT(t:find("Click: go to Light Leather", 1, true) and t:find("Needs 6 crafted|cff3fc7ff, 4 with bank|r", 1, true), "hover:\n" .. t)
    click(rowFor(2318))
    EXPECT(st.selected == "Light Leather" and TSF.qtyBox:GetText() == "6", "jump: " .. tostring(st.selected))
    EXPECT(TSF.detBack:IsShown() and TSF.detBack:GetText() == "Back" and backTip() == "Back to PB Jump Pack", "no Back")
    local bp = rawget(TSF.detBack, "_lastPoint")
    EXPECT(bp and bp[1] == "TOPRIGHT" and bp[2] == TSF.shareBtn and bp[3] == "BOTTOMRIGHT" and bp[5] == -13
           and (rawget(TSF.detBack, "_size") or {})[1] == 56, "Back is not under Share")
    back()
    EXPECT(st.selected == "PB Jump Pack" and TSF.qtyBox:GetText() == "5", "Back: " .. tostring(st.selected))
    -- the bank covers it all
    inv.bank = { [2318] = 8 }
    t = lines(rowFor(2318))
    EXPECT(t:find("Needs 6 crafted|cff3fc7ff, none with bank|r", 1, true), "bank covers it:\n" .. t)
    inv.bank = { [2318] = 2 }
    -- a recipe you pick starts at 1; the window opened again too
    TSF.qtyBox:SetText("7")
    EXPECT(pick("Light Leather") and TSF.qtyBox:GetText() == "1", "a pick kept the quantity " .. tostring(TSF.qtyBox:GetText()))
    local keepRemember = PB.db.settings.rememberWindowState
    PB.db.settings.rememberWindowState = true
    TSF.qtyBox:SetText("8")
    CLOSE_TRADE()
    OPEN_TRADE()
    EXPECT(st.selected == "Light Leather" and TSF.qtyBox:GetText() == "1",
           "reopened on " .. tostring(st.selected) .. " with the quantity " .. tostring(TSF.qtyBox:GetText()))
    PB.db.settings.rememberWindowState = keepRemember
    for _, r in ipairs(TSF.reagentRows) do
        rawset(r.hover, "Show", function(x) rawset(x, "_on", true) end)
        rawset(r.hover, "Hide", function(x) rawset(x, "_on", false) end)
    end
    TSF:SelectRecipeForView("PB Jump Pack", false)
    -- Copper Bar from your Smelting: named, no click
    local me = DS:GetCharacter()
    local keepSmelt = me.professions.Smelting
    me.professions.Smelting = { skillLevel = 1, recipes = { ["Smelt Copper"] = {} } }
    local keepItr = RDB.itemToRecipe[2840]
    if not (keepItr and keepItr[1]) then RDB.itemToRecipe[2840] = { { recipeName = "Smelt Copper", profName = "Smelting" } } end
    t = lines(rowFor(2840))
    EXPECT(t:find("Made with Smelting: Smelt Copper", 1, true) and not t:find("Click", 1, true) and not rawget(rowFor(2840).hover, "_on"),
           "Copper Bar hover:\n" .. t)
    click(rowFor(2840))
    EXPECT(st.selected == "PB Jump Pack" and st.profName ~= "Smelting", "a click opened Smelting")
    RDB.itemToRecipe[2840] = keepItr
    me.professions.Smelting = keepSmelt
    inv.bank, inv.bankScanned = keepBank, keepScanned
    ITEM_COUNT = nil
    TSF._jumpStack = nil
    CLOSE_TRADE()
    for i, r in ipairs(TBC.tradeRows) do if r == pack then table.remove(TBC.tradeRows, i) break end end
end
U28()
print("  PASS " .. TAG .. "28 2.2.0 #13: on TBC Anniversary a material made in the open profession jumps with 'Needs N crafted' and Back under Share returns; a pick or a reopen starts at 1; one from another profession says 'Made with Smelting' and doesn't jump")

-- U29 2.2.0: the craft strip on TBC Anniversary, in both looks: shown from
-- the craft's first cast, the window rises above it (the Enchant button
-- too) and the list fits its rows; the main window shows it while parked;
-- gone at the end of the batch
local function U29()
    local UI, TSF, S = PB.UI, PB.TradeSkillFrame, PB.db.settings
    local st = TSF.state
    local keepArm, keepName = TSF.ArmCraftWatchdog, SPELL_NAMES[2881]
    TSF.ArmCraftWatchdog = function() end
    SPELL_NAMES[2881] = "Light Leather"   -- TBC Anniversary matches the craft by name
    local row = TBC.tradeRows[2]
    local keepAvail = row[3]
    row[3] = 10
    local function cast(ev) FIRE(ev or "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-guid", 2881) end
    local function y(frame) local p = rawget(frame, "_lastPoint"); return p and p[#p] end
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if UI.frame:IsShown() then UI:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
    TSF:StopCraftTracking()
    S.craftBarCast, S.craftBarBatch = true, true
    OPEN_TRADE()
    st.selected = "Light Leather"; TSF:UpdateCraftBar()
    TSF:DoCraftImmediate(5)
    EXPECT(TSF._craftingActive and not TSF.craftStrip:IsShown() and y(TSF.listPanel) == 30, "a strip before the first cast")
    CAST_INFO = { "Light Leather", "", 0, 999000, 1001000, true, nil, false, 2881 }
    cast("UNIT_SPELLCAST_START")
    EXPECT(TSF.craftStrip:IsShown() and TSF.craftStrip.cast:IsShown() and TSF.craftStrip.batch:IsShown()
           and y(TSF.listPanel) == 65 and y(TSF.craftBar) == 65 and y(TSF.detailFrame) == 125
           and y(TSF.enchantCraftBtn) == 117 and TSF:ListRows() == 18,
           "the window over the strip: list " .. tostring(y(TSF.listPanel)) .. ", rows " .. TSF:ListRows())
    -- TBC Anniversary's GetSpellInfo here gives no cast time: 1 s, plus 0.5
    TSF:PaintStrip(TSF.craftStrip)
    EXPECT(TSF.craftStrip.cast.text:GetText() == "Light Leather"
           and TSF.craftStrip.batch.text:GetText() == "Crafting 1 of 5, about 7s left",
           "the bars: " .. tostring(TSF.craftStrip.batch.text:GetText()))
    CAST_INFO = nil
    cast()
    TSF:PaintStrip(TSF.craftStrip)
    EXPECT(TSF.craftStrip.batch.text:GetText() == "Crafting 2 of 5, about 6s left", "after one: " .. tostring(TSF.craftStrip.batch.text:GetText()))
    -- parked on the Characters tab: the main window's strip
    TSF.navTabs[1]:GetScript("OnClick")(TSF.navTabs[1]); FLUSH()
    EXPECT(TSF._parked and TSF:MainStrip():IsShown() and y(UI.frame.tabs[1].content) == 45, "no strip in the main window")
    cast(); cast(); cast(); cast()
    EXPECT(not TSF._craftingActive and not TSF:MainStrip():IsShown() and not TSF.craftStrip:IsShown()
           and y(UI.frame.tabs[1].content) == 10, "the strip stayed after the batch")
    UI.backBtn:GetScript("OnClick")(UI.backBtn); FLUSH()
    EXPECT(TSF.frame:IsShown() and y(TSF.listPanel) == 30 and y(TSF.enchantCraftBtn) == 82 and TSF:ListRows() == 20, "the window after the batch")
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() end
    row[3] = keepAvail
    SPELL_NAMES[2881] = keepName
    TSF.ArmCraftWatchdog = keepArm
end
U29()
print("  PASS " .. TAG .. "29 2.2.0: the craft strip on TBC Anniversary from the first cast: the window and the Enchant button rise, 18 rows, 'Crafting 2 of 5, about 6s left', the main window's strip while parked; gone after the batch")

-- U30 2.2.1 (Bran): on TBC Anniversary a 25 s cast (Runecloth Belt) kept
-- the strip only 10 s until 2.2.1. Each cast moves the watchdog to that
-- cast's end plus 10 s; a refused craft still stops at 10 s.
local function U30()
    local TSF, S = PB.TradeSkillFrame, PB.db.settings
    local st = TSF.state
    local keepName = SPELL_NAMES[2881]
    SPELL_NAMES[2881] = "Light Leather"   -- TBC Anniversary matches the craft by name
    local arms = {}
    local realArm = TSF.ArmCraftWatchdog
    TSF.ArmCraftWatchdog = function(self, sec)
        local keep = C_Timer.After
        C_Timer.After = function(d, fn) arms[#arms + 1] = { sec = d, fn = fn } end
        realArm(self, sec)
        C_Timer.After = keep
    end
    local row = TBC.tradeRows[2]
    local keepAvail = row[3]
    row[3] = 10
    local function cast(ev) FIRE(ev, "player", "Cast-guid", 2881) end
    local function last() return arms[#arms].sec end
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
    TSF:StopCraftTracking()
    S.craftBarCast, S.craftBarBatch = true, true
    OPEN_TRADE()
    st.selected = "Light Leather"; TSF:UpdateCraftBar()
    TSF:DoCraftImmediate(2)
    EXPECT(last() == 10, "the watchdog at the click: " .. tostring(last()))
    local click = arms[#arms]
    CAST_INFO = { "Light Leather", "", 0, 1000000, 1025000, true, nil, false, 2881 }
    cast("UNIT_SPELLCAST_START")
    EXPECT(last() == 35, "the watchdog at the first cast: " .. tostring(last()))
    click.fn()   -- 10 s after the click, mid-cast
    EXPECT(TSF._craftingActive and TSF.craftStrip:IsShown(), "the strip went 10 s into the cast")
    cast("UNIT_SPELLCAST_SUCCEEDED")
    local between = arms[#arms]
    cast("UNIT_SPELLCAST_START")
    EXPECT(last() == 35, "the watchdog at the second cast: " .. tostring(last()))
    between.fn()
    EXPECT(TSF._craftingActive and TSF.craftStrip:IsShown(), "the strip went 10 s into the second cast")
    cast("UNIT_SPELLCAST_SUCCEEDED")
    EXPECT(not TSF._craftingActive and not TSF.craftStrip:IsShown(), "the strip after the batch")
    CAST_INFO = nil
    -- a craft the game refuses: stopped 10 s after the click
    TSF:DoCraftImmediate(2)
    EXPECT(last() == 10, "the watchdog for a refused craft: " .. tostring(last()))
    arms[#arms].fn()
    EXPECT(not TSF._craftingActive, "a refused craft still tracked")
    if TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() end
    row[3] = keepAvail
    SPELL_NAMES[2881] = keepName
    TSF.ArmCraftWatchdog = realArm
end
U30()
print("  PASS " .. TAG .. "30 2.2.1 (Bran): a 25 s cast keeps the strip past the 10-second watchdog on TBC Anniversary, every cast of the batch; a refused craft still stops at 10 s")

-- U31: 2.2.2 look picker on TBC Anniversary. Shown once at login, Match
-- the game pickable (Classic here); a pick that changes the look in use
-- reloads, the same look does not
do
    local Theme, S = PB.Theme, PB.db.settings
    EXPECT(#loginPopups == 1 and loginPopups[1] == "PROFBUDDY_PICK_LOOK",
           "login popups: " .. table.concat(loginPopups, ", "))
    local dlg = loginPicker
    EXPECT(dlg.button1 == "Classic" and dlg.button2 == "Modern" and dlg.button3 == "Match the game", "picker buttons")
    EXPECT(dlg.text:find("Match the game: the game's own look, Classic on TBC Anniversary.", 1, true), "picker text: " .. dlg.text)
    local disabled = false
    dlg.OnShow({ GetButton = function() return { Disable = function() disabled = true end } end })
    EXPECT(not disabled, "Match the game greyed on TBC Anniversary")
    local reloads = 0
    local keepReload = ReloadUI
    ReloadUI = function() reloads = reloads + 1 end
    dlg.OnButton3()
    EXPECT(S.lookAsked == 1 and S.windowStyle == "game", "Match the game not saved: " .. tostring(S.windowStyle))
    EXPECT(reloads == (LOOK == "classic" and 0 or 1), "Match the game over " .. LOOK .. ": " .. reloads .. " reloads")
    reloads = 0
    Theme._lookReloading = nil
    dlg[LOOK == "classic" and "OnButton1" or "OnButton2"]()
    EXPECT(reloads == 0 and S.windowStyle == LOOK, "the same look reloaded")
    dlg[LOOK == "classic" and "OnButton2" or "OnButton1"]()
    EXPECT(reloads == 1 and S.windowStyle ~= LOOK, "another look did not reload")
    ReloadUI = keepReload
    S.windowStyle, Theme._lookReloading = LOOK, nil
    EXPECT(Theme:Name() == LOOK, "the session look changed before the reload")
end
print("  PASS " .. TAG .. "31 2.2.2 look picker: once at login, Match the game pickable on TBC Anniversary (Classic), a new look reloads and the same look does not")

-- U32/C32 2.2.2: camp item tooltips are WoW: Forever only. TBC
-- Anniversary's data has no Camping recipes, so a "Camp Chair" tooltip gets
-- nothing even with a game that would answer.
do
    for prof, recipes in pairs(PB.RecipeDB.data) do
        for name, r in pairs(recipes) do
            EXPECT(r.category ~= "Camping", "a Camping recipe on TBC Anniversary: " .. prof .. " " .. name)
        end
    end
    local onUpdate = GameTooltip._h.OnUpdate
    EXPECT(type(onUpdate) == "function", "no GameTooltip OnUpdate hook")
    local lines, asked = {}, 0
    for i = 1, 5 do
        local fs = _G["GameTooltipTextLeft" .. i] or CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(fs, "SetText", function(_, t) lines[i] = t end)
        rawset(fs, "GetText", function() return lines[i] end)
    end
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return #lines end)
    rawset(GameTooltip, "AddLine", function(_, t) lines[#lines + 1] = t end)
    C_Item = C_Item or {}
    C_Spell = C_Spell or {}
    local keepIS, keepIN, keepSD = C_Item.GetItemSpell, C_Item.GetItemNameByID, C_Spell.GetSpellDescription
    C_Item.GetItemSpell = function() asked = asked + 1; return "Use", 1307229 end
    C_Item.GetItemNameByID = function() asked = asked + 1; return "Camp Chair" end
    C_Spell.GetSpellDescription = function() asked = asked + 1; return "Assembles a camp chair." end
    lines = { "Camp Chair" }
    for _ = 1, 3 do onUpdate(GameTooltip, 1) end
    EXPECT(#lines == 1 and asked == 0, "Camp Chair on TBC Anniversary: " .. table.concat(lines, " / ") .. ", " .. asked .. " calls")
    C_Item.GetItemSpell, C_Item.GetItemNameByID, C_Spell.GetSpellDescription = keepIS, keepIN, keepSD
end
print("  PASS " .. TAG .. "32 2.2.2: no camp item tooltip line on TBC Anniversary (no Camping recipes)")

-- U33/C33 2.2.2 TEST-d: TBC Anniversary has no camping, so Settings does
-- not show "Camp item benefits on tooltips".
do
    EXPECT(PB.CampWorld == nil, "CampWorld loads on TBC Anniversary")
    TSF:OpenSettings("main")
    for _, cb in ipairs(TSF.settingsCheckboxes or {}) do
        EXPECT(cb.settingKey ~= "campBenefitTooltip", "the camp box shows on TBC Anniversary")
    end
end
print("  PASS " .. TAG .. "33 2.2.2: no Camp item benefits box in Settings on TBC Anniversary")

-- U34/C34 2.2.2 TEST-e: Sort: Rarity on TBC Anniversary, from the baked
-- table (Data/Rarity.lua) and the game's own for an item it lacks:
-- category headers kept, best first and then worst first, no rarity last
-- (Enchanting's enchants make no item), same rarity known first, then name.
do
    local st = TSF.state
    local R = PB.Rarity
    local n = 0
    for _ in pairs(R or {}) do n = n + 1 end
    EXPECT(R and R[1251] == 1 and R[4239] == 1 and R[29525] == 4 and n > 1900,
           "TBC Anniversary rarity table: " .. n .. " items")
    local function q(e)
        local id = e.itemID
        if not id then local d = PB.RecipeDB.data[st.profName] and PB.RecipeDB.data[st.profName][e.name]; id = d and d.itemID end
        if not id or id == 0 then return nil end
        local v = R[id]
        if v == nil then v = select(3, GetItemInfo(id)) end
        return type(v) == "number" and v or nil
    end
    local function check(asc, what)
        local heads, rows, kinds, seen, lastCat, prev, nilSeen, nilRows = 0, 0, 0, {}, nil, nil, false, 0
        for _, e in ipairs(st.recipes) do
            if e.isHeader then
                heads = heads + 1
                if e.headerType ~= "subcategory" then
                    EXPECT(not lastCat or lastCat < e.name, what .. ": category order " .. tostring(lastCat) .. " / " .. e.name)
                    lastCat = e.name
                end
                prev, nilSeen = nil, false
            else
                rows = rows + 1
                local qe = q(e)
                if qe and not seen[qe] then seen[qe] = true; kinds = kinds + 1 end
                if not qe then nilRows = nilRows + 1 end
                if prev then
                    local qp = q(prev)
                    EXPECT(not (nilSeen and qe), what .. ": " .. e.name .. " after a recipe with no rarity")
                    if qp and qe and qp ~= qe then
                        EXPECT((asc and qp > qe) or (not asc and qp < qe), what .. ": " .. prev.name .. " before " .. e.name)
                    elseif qp == qe then
                        if prev.isKnown ~= e.isKnown then
                            EXPECT(prev.isKnown, what .. ": missing " .. prev.name .. " before known " .. e.name)
                        else
                            EXPECT(prev.name < e.name, what .. ": name order " .. prev.name .. " / " .. e.name)
                        end
                    end
                end
                if not qe then nilSeen = true end
                prev = e
            end
        end
        EXPECT(heads > 1 and rows > 10 and kinds >= 2, what .. ": " .. heads .. " headers, " .. rows .. " rows, " .. kinds .. " rarities")
        return nilRows
    end
    local function pick()
        local dd, btn = TSF.sortDropdown, nil
        for _, b in ipairs(dd.optionBtns) do if b.value == "Rarity" then btn = b end end
        EXPECT(btn, "no Rarity in the Sort menu")
        btn:GetScript("OnClick")(btn)
        return dd, btn
    end

    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    OPEN_TRADE()
    st.showTab, st.searchText, st.filterCat, st.filterDiff, st.collapsed = "all", "", "All", "All", {}
    st.sortBy, st.sortAsc = "Category", true
    TSF:RefreshRecipeList()
    local dd, btn = pick()
    EXPECT(st.sortBy == "Rarity" and st.sortAsc and dd.btnText:GetText() == "Sort: Rarity ^", "picking Rarity: " .. tostring(dd.btnText:GetText()))
    check(true, "Leatherworking best first")
    btn:GetScript("OnClick")(btn)
    EXPECT(not st.sortAsc and dd.btnText:GetText() == "Sort: Rarity v", "Rarity again: " .. tostring(dd.btnText:GetText()))
    check(false, "Leatherworking worst first")

    -- an item the table lacks: last until the game has it, then with its rarity
    st.sortAsc = true
    TSF:RefreshRecipeList()
    local epic
    for _, e in ipairs(st.recipes) do if not e.isHeader and q(e) == 4 then epic = e; break end end
    EXPECT(epic, "no Epic in the Leatherworking list")
    local eid = epic.itemID or PB.RecipeDB.data[st.profName][epic.name].itemID
    local keep = R[eid]
    R[eid] = nil
    TSF:RefreshRecipeList()
    local function after(name)
        for i, e in ipairs(st.recipes) do if not e.isHeader and e.name == name then return st.recipes[i + 1] end end
    end
    local nx = after(epic.name)
    EXPECT(not nx or nx.isHeader or not q(nx), epic.name .. " with no rarity is not last in its group")
    ITEM_NAMES[eid] = epic.name   -- the game now has it, as Common (the test client's)
    TSF:RefreshRecipeList()
    EXPECT(q(epic) == 1, "the game's rarity not read: " .. tostring(q(epic)))
    check(true, "the game's own rarity")
    ITEM_NAMES[eid], R[eid] = nil, keep

    -- Enchanting: enchants make no item, so they go last, both ways
    st.sortBy, st.sortAsc = "Category", true
    dd:SetValue("Sort: Category ^", "Category")
    TSF.frame:Hide(); FLUSH()
    CLOSE_TRADE()
    OPEN_CRAFT()
    st.showTab, st.searchText, st.filterCat, st.filterDiff, st.collapsed = "all", "", "All", "All", {}
    TSF:RefreshRecipeList()
    pick()
    local nils = check(true, "Enchanting best first")
    EXPECT(nils > 0, "no enchant in the Enchanting list")
    btn = nil
    for _, b in ipairs(dd.optionBtns) do if b.value == "Rarity" then btn = b end end
    btn:GetScript("OnClick")(btn)
    check(false, "Enchanting worst first")
    st.sortBy, st.sortAsc = "Category", true
    dd:SetValue("Sort: Category ^", "Category")
    TSF:RefreshRecipeList()
    TSF.frame:Hide(); FLUSH()
    CLOSE_CRAFT()
end
print("  PASS " .. TAG .. "34 2.2.2 TEST-e: Sort: Rarity on TBC Anniversary: category headers kept, best first then worst first, same rarity known first then by name, enchants last both ways; an item the table lacks is last until the game has it, then sorts by the game's rarity")

-- U35/C35 2.2.3 (Lucido): Skip vendor items on TBC Anniversary, from
-- Data/VendorPrices.lua: the checkbox left of the search box, the list's
-- count and the detail panel's line with the thread left out, the bank
-- count, nothing on a recipe without a vendor item, off as before
do
    if TBC.open ~= "trade" then OPEN_TRADE() end
    local TSF, DS = PB.TradeSkillFrame, PB.DataStore
    local st = TSF.state
    local S = PB.db.settings
    local inv = DS:GetCharacter().inventory
    local keepBank, keepScanned, keepOff, keepView, keepSel = inv.bank, inv.bankScanned, st.scrollOffset, st._viewCharKey, st.selected
    EXPECT(PB.VendorPrices and PB.VendorPrices[2320] and not PB.VendorPrices[2318], "TBC: Coarse Thread is not a vendor item, or Light Leather is")
    EXPECT(not S.skipVendorReagents, "TBC: on by default")
    ITEM_COUNT = {}
    inv.bank, inv.bankScanned = {}, true
    st._viewCharKey = nil
    local kit = { name = "PB Test Belt", isKnown = true, numAvail = 0, itemID = 4239, spellID = 3753,
                  category = "Belt", reagents = { { itemID = 2318, count = 2, name = "Light Leather" },
                                                  { itemID = 2320, count = 1, name = "Coarse Thread" } } }
    table.insert(st.recipes, 1, kit)
    st.scrollOffset, st.selected = 0, kit.name
    local row = TSF.listRows[1]
    local cb = TSF.skipVendorCB
    local function draw() TSF:UpdateListRows(); TSF:RefreshDetailPanel() end
    local function list() return row.rightText:GetText() or "" end
    local function can() return TSF.detCanMake:GetText() or "" end
    local function click(on) rawset(cb, "GetChecked", function() return on end); cb:GetScript("OnClick")(cb) end
    local p = rawget(cb, "_lastPoint")
    EXPECT(p and p[1] == "RIGHT" and p[2] == TSF.searchBox and p[3] == "LEFT" and cb:IsShown(),
           "TBC: the checkbox is not left of the search box")
    ITEM_COUNT[2318] = 10
    draw()
    EXPECT(not list():find("[", 1, true) and can() == "|cffff4444Can make: 0 (missing reagents)|r", "TBC off: " .. list() .. " / " .. can())
    click(true)
    EXPECT(S.skipVendorReagents == true and list():find("|cff00ff00[5]|r", 1, true)
           and can() == "|cff00ff00Can make: 5|r|cffa0a0a0 (vendor items skipped)|r", "TBC on: " .. list() .. " / " .. can())
    inv.bank[2318] = 4
    draw()
    EXPECT(list():find("|cff00ff00[5]|r |cff3fc7ff[7]|r", 1, true)
           and can() == "|cff00ff00Can make: 5|r|cff3fc7ff, 7 with bank|r|cffa0a0a0 (vendor items skipped)|r",
           "TBC bank: " .. list() .. " / " .. can())
    inv.bank[2318] = nil
    kit.reagents, kit.numAvail = { { itemID = 2318, count = 2, name = "Light Leather" } }, 5
    draw()
    EXPECT(can() == "|cff00ff00Can make: 5|r", "TBC no vendor item: " .. can())
    kit.reagents, kit.numAvail = { { itemID = 2318, count = 2, name = "Light Leather" }, { itemID = 2320, count = 1, name = "Coarse Thread" } }, 0
    click(false)
    EXPECT(S.skipVendorReagents == false and can() == "|cffff4444Can make: 0 (missing reagents)|r", "TBC off again: " .. can())
    table.remove(st.recipes, 1)
    inv.bank, inv.bankScanned, st.scrollOffset, st._viewCharKey, st.selected = keepBank, keepScanned, keepOff, keepView, keepSel
    ITEM_COUNT = nil
    TSF:UpdateListRows(); TSF:RefreshDetailPanel()
    TSF.frame:Hide(); FLUSH()
    CLOSE_TRADE()
end
print("  PASS " .. TAG .. "35 2.2.3: Skip vendor items on TBC Anniversary: left of the search box, off by default; on, Can make leaves Coarse Thread out in the list, the detail panel with (vendor items skipped) and the bank count; nothing on a recipe without a vendor item; off as before")

-- U36/C36 2.2.3 (m4ru 11-23): "Est." under the quantity box on TBC
-- Anniversary, at the batch bar's rate (no cast time here: 1 s plus 0.5),
-- hidden while the batch bar is on screen and back after the batch; and a
-- node's lines once per showing when PB cannot read its own lines back
do
    local TSF, S = PB.TradeSkillFrame, PB.db.settings
    local st = TSF.state
    local keepArm, keepName = TSF.ArmCraftWatchdog, SPELL_NAMES[2881]
    local keepCast, keepBatch = S.craftBarCast, S.craftBarBatch
    TSF.ArmCraftWatchdog = function() end
    SPELL_NAMES[2881] = "Light Leather"
    local row = TBC.tradeRows[2]
    local keepAvail = row[3]
    row[3] = 10
    if TSF.frame and TSF.frame:IsShown() then TSF.frame:Hide(); FLUSH() end
    if TBC.open == "trade" then CLOSE_TRADE() elseif TBC.open == "craft" then CLOSE_CRAFT() end
    TSF:StopCraftTracking()
    S.craftBarCast, S.craftBarBatch = true, true
    OPEN_TRADE()
    st.selected = "Light Leather"; TSF:UpdateCraftBar()
    local est, box = TSF.craftEstimate, TSF.qtyBox
    local function qty(v) box:SetText(v); box:GetScript("OnTextChanged")(box, false) end
    local function txt() return est:IsShown() and est:GetText() or "<hidden>" end
    local pt = rawget(est, "_lastPoint")
    EXPECT(pt and pt[1] == "CENTER" and pt[2] == TSF.craftBar, "TBC: the estimate is not on the craft bar")
    EXPECT(txt() == "Est. 2s", "TBC first draw: " .. txt())
    qty("5");  EXPECT(txt() == "Est. 8s", "TBC 5 crafts: " .. txt())
    qty("60"); EXPECT(txt() == "Est. 1m 30s", "TBC 60 crafts: " .. txt())
    qty("");   EXPECT(txt() == "<hidden>", "TBC empty box: " .. txt())
    qty("5")
    TSF:DoCraftImmediate(5)
    EXPECT(TSF._craftingActive and not TSF.craftStrip:IsShown() and txt() == "Est. 8s", "TBC before the first cast: " .. txt())
    CAST_INFO = { "Light Leather", "", 0, 999000, 1001000, true, nil, false, 2881 }
    FIRE("UNIT_SPELLCAST_START", "player", "Cast-guid", 2881)
    EXPECT(TSF.craftStrip:IsShown() and TSF.craftStrip.batch:IsShown() and txt() == "<hidden>", "TBC batch bar on screen: " .. txt())
    CAST_INFO = nil
    for _ = 1, 5 do FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-guid", 2881) end
    EXPECT(not TSF._craftingActive and not TSF.craftStrip:IsShown() and txt() == "Est. 2s", "TBC after the batch: " .. txt())
    TSF.frame:Hide(); FLUSH()
    CLOSE_TRADE()
    row[3] = keepAvail
    SPELL_NAMES[2881] = keepName
    TSF.ArmCraftWatchdog = keepArm
    S.craftBarCast, S.craftBarBatch = keepCast, keepBatch

    -- the node: every line after the name reads back as something else,
    -- so PB never finds the game's Requires line or its own lines
    local keepLoot, keepUnl, keepYield, keepSkill = S.gatherLootUnlearned, S.gatherShowUnlearned, S.gatherYieldTooltip, S.gatherSkillTooltip
    S.gatherLootUnlearned, S.gatherShowUnlearned, S.gatherYieldTooltip, S.gatherSkillTooltip = true, true, true, true
    local keepGather = PB.db.lastGather
    local lines = {}
    for i = 1, 40 do
        local fs = _G["GameTooltipTextLeft" .. i] or CreateFrame("Frame", "GameTooltipTextLeft" .. i)
        rawset(fs, "SetText", function(_, t) lines[i] = t end)
        rawset(fs, "GetText", function() return lines[i] and (i > 1 and "?" or lines[i]) end)
    end
    rawset(GameTooltip, "GetUnit", function() return nil end)
    rawset(GameTooltip, "GetItem", function() return nil end)
    rawset(GameTooltip, "NumLines", function() return #lines end)
    rawset(GameTooltip, "AddLine", function(_, t) lines[#lines + 1] = t end)
    rawset(GameTooltip, "AddDoubleLine", function(_, a) lines[#lines + 1] = a end)
    rawset(GameTooltip, "Show", function() end)
    local onUpdate = GameTooltip._h.OnUpdate
    lines = { "Copper Vein", "Requires Mining" }
    onUpdate(GameTooltip, 1)
    local n = #lines
    local found
    for i = 3, n do if lines[i]:find("Requires Mining (1)", 1, true) then found = true end end
    EXPECT(n >= 3 and found, "TBC Copper Vein: " .. table.concat(lines, " / "))
    for _ = 1, 200 do onUpdate(GameTooltip, 1) end
    EXPECT(#lines == n, "TBC node lines piled up: " .. #lines .. " vs " .. n)
    lines = { "Copper Vein", "Requires Mining" }
    for _ = 1, 50 do onUpdate(GameTooltip, 1) end
    EXPECT(#lines == n, "TBC node after a rebuild: " .. #lines .. " vs " .. n)
    for _, k in ipairs({ "GetUnit", "GetItem", "NumLines", "AddLine", "AddDoubleLine", "Show" }) do rawset(GameTooltip, k, nil) end
    for i = 1, 40 do
        local fs = _G["GameTooltipTextLeft" .. i]
        if fs then rawset(fs, "SetText", nil); rawset(fs, "GetText", nil) end
    end
    PB.db.lastGather = keepGather
    S.gatherLootUnlearned, S.gatherShowUnlearned, S.gatherYieldTooltip, S.gatherSkillTooltip = keepLoot, keepUnl, keepYield, keepSkill
end
print("  PASS " .. TAG .. "36 2.2.3: Est. under the quantity box on TBC Anniversary (2s, 8s, 1m 30s, none for an empty box); hidden while the batch bar is on screen, back after the batch; a node's lines once per showing when PB cannot read them back")

-- U37/C37 2.2.4 CD-A (m4ru 11-24): the baked cooldown table on TBC
-- Anniversary (Data/Cooldowns.lua, tools/cooldown_db.py): every entry a
-- recipe PB knows, seconds and a named shared timer or none. Anchors from
-- the game's spell tables.
do
    local C, G = PB.Cooldowns, PB.CooldownGroups
    EXPECT(type(C) == "table" and type(G) == "table", "no TBC cooldown table")
    local tocSrc = assert(io.open(PB_BASE .. "/ProfessionBuddy_TBC.toc")):read("*a")
    EXPECT(tocSrc:find("\nData/Cooldowns.lua", 1, true) and not tocSrc:find("\nData/Forever/Cooldowns.lua", 1, true),
           "TBC toc: cooldown table")
    local n = 0
    for sid, e in pairs(C) do
        n = n + 1
        EXPECT(PB.RecipeDB:GetRecipeBySpell(sid), "cooldown for spell " .. sid .. ", not a recipe")
        EXPECT(type(e[1]) == "number" and e[1] > 0 and (e[2] == nil or G[e[2]]),
               "cooldown entry for spell " .. sid)
    end
    EXPECT(n == 29, "TBC cooldown recipes: " .. n)
    -- every transmute 20h shared, the spheres 48h on their own shared
    -- timer, Primal Mooncloth 92h own
    EXPECT(C[11479][1] == 72000 and C[11479][2] == 310 and C[28566][2] == 310
           and C[28027][1] == 172800 and C[28027][2] == 1174 and C[28028][2] == 1174
           and C[26751][1] == 331200 and C[26751][2] == nil
           and G[310] == "Transmute - Alchemy" and G[1174] == "Enchanting", "TBC cooldown anchors")
end
print("  PASS " .. TAG .. "37 2.2.4 CD-A: TBC Anniversary's baked cooldown table loads from the TBC toc; 29 recipes, each a known recipe with seconds and a named shared timer or none (transmutes 20h shared, spheres 48h shared, Primal Mooncloth 92h)")

print("ALL TBC WINDOW TESTS PASS (" .. LOOK .. ", 37)")
