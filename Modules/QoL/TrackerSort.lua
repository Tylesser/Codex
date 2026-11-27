local addonName, ns = ...
local L = ns.L

-- Quest tracker order (the user's request, 2026-11-20): the quests of the zone you're in go to the top of the game's
-- quest tracker; the others follow grouped by zone, the nearest zone first; inside each zone the nearest quest first
-- (the order itself: QuestOrder.lua).
--
-- How the tracker orders (forever branch, Blizzard_ObjectiveTracker): QuestObjectiveTrackerMixin:BuildQuestWatchInfos
-- lists C_QuestLog.GetQuestIDForQuestWatchIndex(1..GetNumQuestWatches()) and keeps that order (callings and
-- overridesSortOrder quests first). ObjectiveTrackerFrameMixin:OnEvent calls C_QuestLog.SortQuestWatches() on
-- ZONE_CHANGED_NEW_AREA and on a ZONE_CHANGED that changes the map, but on Forever that left the user's list in no
-- zone order (their screenshot, 2026-11-20). So Codex sets the watch list's own order: the watches from the first
-- one out of place on are removed and added again in the wanted order (C_QuestLog.RemoveQuestWatch /
-- AddQuestWatch(questID), Forever's takes only the ID; neither is protected). Nothing of Blizzard's tracker is
-- hooked or replaced: its quest item buttons are secure, and a tainted tracker would break them in a fight.
--
-- In the same frame the blocks still exist, so the tracker plays no "new quest" glow (OnEvent only does it for an
-- added quest without a block). Runs 0.3 s after a zone, subzone or watch change (after Blizzard's own sort), never
-- in combat (queued until it ends), and not again while its own changes come in. Idle while Codex's own quest
-- tracker (Modules/QuestTracker) runs: that one sorts and groups by itself.

local Q = ns.qol
local QO = ns.QuestOrder
local TS = {}
Q.trackerSort = TS

local KEY = "trackerSort"
local DELAY = 0.3
local QUIET = 1 -- seconds after our own changes in which watch-list events are ours

local frame
local pending = false
local afterCombat = false
local quietUntil = 0

local function CodexTracker()
  return ns.questtracker and ns.questtracker.running and true or false
end

local function On()
  return Q.On and Q.On(KEY) and not CodexTracker()
end

local function Now()
  return type(GetTime) == "function" and (QO.Num(GetTime()) or 0) or 0
end

TS.Watched = QO.Watched
TS.ZoneNames = QO.ZoneNames
TS.LogInfo = QO.LogInfo

function TS.Wanted(watched)
  return (QO.Sorted(watched))
end

-- Puts the watch list in the wanted order. Returns how many watches were moved.
function TS.Apply()
  if not On() then
    return 0
  end
  if InCombatLockdown and InCombatLockdown() then
    afterCombat = true
    return 0
  end
  local watched = TS.Watched()
  local wanted = TS.Wanted(watched)
  local first
  for index = 1, #wanted do
    if wanted[index] ~= watched[index] then
      first = index
      break
    end
  end
  if not first then
    return 0
  end
  quietUntil = Now() + QUIET
  TS.busy = true
  for index = first, #wanted do
    QO.Ask(QO.API("RemoveQuestWatch"), wanted[index])
  end
  for index = first, #wanted do
    QO.Ask(QO.API("AddQuestWatch"), wanted[index])
  end
  TS.busy = false
  TS.lastMoved = #wanted - first + 1
  return TS.lastMoved
end

function TS.Soon()
  if pending or not On() then
    return
  end
  pending = true
  C_Timer.After(DELAY, function()
    pending = false
    TS.Apply()
  end)
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
  "QUEST_ACCEPTED", "QUEST_WATCH_LIST_CHANGED", "PLAYER_REGEN_ENABLED" }

local function OnEvent(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if afterCombat then
      afterCombat = false
      TS.Soon()
    end
    return
  end
  if event == "QUEST_WATCH_LIST_CHANGED" and (TS.busy or Now() < quietUntil) then
    return -- our own changes
  end
  TS.Soon()
end

function TS.Start()
  if not frame then
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", OnEvent)
  end
  for _, event in ipairs(EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  TS.Soon()
end

function TS.Stop()
  if frame then
    frame:UnregisterAllEvents()
  end
  afterCombat = false
end

Q.AddToggle({
  key = KEY,
  name = L["Quest tracker order"],
  desc = L["The quests of the zone you're in go to the top of the game's quest tracker, nearest first; the others follow grouped by zone. Sorted again when you change zone or subzone, and never in a fight. Codex's own quest tracker (Quest tracker module) sorts by itself."],
  order = 35,
  Enable = function()
    if Q.On(KEY) then
      TS.Start()
    end
  end,
  Changed = function(on)
    if on then
      TS.Start()
    else
      TS.Stop()
    end
  end,
})
