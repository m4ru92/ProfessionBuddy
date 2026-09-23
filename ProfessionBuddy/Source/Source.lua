----------------------------------------------------------------------
-- ProfessionBuddy  --  Source/Source.lua
-- The profession-API seam.
--
-- Everything PB reads from or does to a profession window goes through
-- ProfBuddy.Source. Exactly one implementation is loaded, chosen by the
-- .toc: Source/Classic.lua for TBC Classic Anniversary, a separate one
-- for WoW: Forever. Nothing above this layer calls the game's
-- trade-skill, craft or skill-line API directly.
--
-- Contract (every implementation provides all of it):
--
--   Source.flavor                 "classic" | ...
--   Source.EVENT                  role -> event name, or nil when the
--                                 flavor has no such event:
--                                 TRADE_SHOW, TRADE_UPDATE, TRADE_CLOSE,
--                                 CRAFT_SHOW, CRAFT_UPDATE, CRAFT_CLOSE
--   Source.DEFAULT_FRAMES         Blizzard LoD addon -> frame name PB hides
--   Source.SHARED_FRAMES          (optional) frame name -> true for a default
--                                 frame that also serves something PB does
--                                 NOT replace; it is gated, not killed
--
--   Source:ReadProfessionSkills() { {name, rank, maxRank}, ... }
--       every non-header skill line, headers expanded first and the
--       user's collapsed headers restored after (login path)
--   Source:ReadVisibleSkillLines() { {name, isHeader, rank}, ... }
--       the rows currently displayed, no expanding (live gather skill)
--   Source:GetOpenSkillLine(isCraft)   rawName, rank, maxRank
--   Source:IsLinked(isCraft)           true for a chat-linked window
--   Source:IsPetTraining()             true for the hunter pet trainer
--   Source:CraftCount()                number, or nil with no Craft API
--   Source:ReadOpenWindow(isCraft)     { nameFilter, collapsedHeader,
--       rows = { {name, index, difficulty, numAvail, itemLink,
--                 recipeLink, icon, cooldown, reagents =
--                 { {name, icon, count, link}, ... }}, ... } }
--       header rows are excluded; numAvail and cooldown are RAW, each
--       caller applies its own default exactly as before
--   Source:GetRowState(index, isCraft) skillType, numAvail
--   Source:Craft(index, qty, isCraft)
--   Source:CloseWindow(isCraft)
--   Source:IsSessionOpen(isCraft)      is that channel's backend session
--       open right now (it can be open with no window showing)
----------------------------------------------------------------------

local addon = ProfBuddy
local Source = addon.Source or {}
addon.Source = Source

-- Every method the contract requires. The source harness checks a loaded
-- implementation against this list, so a new flavor cannot ship half-done.
Source.CONTRACT = {
    "ReadProfessionSkills", "ReadVisibleSkillLines", "GetOpenSkillLine",
    "IsLinked", "IsPetTraining", "CraftCount", "ReadOpenWindow",
    "GetRowState", "Craft", "CloseWindow", "IsSessionOpen",
}

function Source:Missing()
    local gone = {}
    for _, m in ipairs(self.CONTRACT) do
        if type(self[m]) ~= "function" then gone[#gone + 1] = m end
    end
    if type(self.EVENT) ~= "table" then gone[#gone + 1] = "EVENT" end
    if type(self.DEFAULT_FRAMES) ~= "table" then gone[#gone + 1] = "DEFAULT_FRAMES" end
    return gone
end

-- Is this one of the Blizzard frames PB replaces? Derived from
-- DEFAULT_FRAMES so an implementation only has to list them once.
function Source:IsDefaultFrame(name)
    if not name then return false end
    for _, frameName in pairs(self.DEFAULT_FRAMES or {}) do
        if frameName == name then return true end
    end
    return false
end
