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
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
FLUSH()
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

-- U2: the main window and its four tabs
local ok, err = pcall(SlashCmdList.PROFBUDDY, "")
EXPECT(ok, "/pb: " .. tostring(err))
local UI = PB.UI
EXPECT(UI.frame and UI.frame:IsShown() and #UI.frame.tabs == 4, "main window not shown with 4 tabs")
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
print("  PASS " .. TAG .. "2 /pb opens; Characters, Friends, Guild and Orders tabs all build and select; guild right-click whispers")

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
EXPECT(TSF.navTabs and #TSF.navTabs == 4, "the profession window's own tabs were not built")
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
    EXPECT(TSF.detPrice:IsShown() and line == "Cost: 30c   Sells: 50c, vendor 5c   Profit: +18c", "TBC price line: " .. line)
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

print("ALL TBC WINDOW TESTS PASS (" .. LOOK .. ", 13)")
