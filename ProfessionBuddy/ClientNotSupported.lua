----------------------------------------------------------------------
-- ProfessionBuddy  --  ClientNotSupported.lua
-- Loaded only by the plain ProfessionBuddy.toc, which a client reads when
-- it has no toc of its own suffix: TBC Classic Anniversary loads
-- ProfessionBuddy_TBC.toc and WoW: Forever loads ProfessionBuddy_Mainline.toc,
-- so reaching this file means an unsupported client (Classic Era, Wrath,
-- Mists and so on). It says so once and does nothing else.
----------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    print("|cff00ccffProfessionBuddy|r does not support this game client yet.")
end)
