----------------------------------------------------------------------
-- ProfessionBuddy  --  Source/Unsupported.lua
-- The placeholder profession source for a client PB loads on but cannot
-- read professions on yet (WoW: Forever until its own Source lands).
--
-- It meets the whole Source contract with empty answers: no skills, no
-- open window, no profession events, no Blizzard frames to replace. So
-- PB never takes over the game's own profession window, and everything
-- above the seam keeps working with nothing to show.
----------------------------------------------------------------------

local addon = ProfBuddy
local Source = addon.Source

Source.flavor = "unsupported"
Source.EVENT = {}
Source.DEFAULT_FRAMES = {}
Source.SHARED_FRAMES = {}

function Source:ReadProfessionSkills()   return {} end
function Source:ReadVisibleSkillLines()  return {} end
function Source:GetOpenSkillLine()       return nil end
function Source:IsLinked()               return false end
function Source:IsPetTraining()          return false end
function Source:CraftCount()             return nil end
function Source:ReadOpenWindow()         return { rows = {} } end
function Source:GetRowState()            return nil end
function Source:Craft()                  end
function Source:CloseWindow()            end
function Source:IsSessionOpen()          return false end
