local addonName, ns = ...

-- Quest options that act by themselves (all off by default; hold Shift while you talk to an NPC to talk normally):
--   autoAccept  quests offered are accepted (from a list: new quests that aren't repeatable or grey; the offer
--               page: not repeatable, not a PvP quest, which asks first)
--   autoTurnIn  finished quests are handed in: never repeatables, never quests that take gold or battleground marks,
--               never when a reward must be chosen (the page then waits for you)
--   service     an NPC whose only option is a service (vendor, banker, trainer, flight master) and who has no quests
--               opens it at once (not the innkeeper's "make this inn your home": that asks a question)
-- A quest picked by itself once in a talk is not picked again for a minute, so declining or cancelling never loops.
-- These work with the game's windows too (Quest windows' "windows" option off).

local D = ns.dialogue
local A = {}
D.Auto = A

local Str, Num, Call = D.Str, D.Num, D.Call
local SERVICES = { "Banker", "Taxi", "Trainer", "Vendor" } -- Interface\GossipFrame\<name>GossipIcon
local BG_MARKS = { [20558] = true, [20559] = true, [20560] = true } -- Warsong Gulch, Arathi Basin, Alterac Valley
local tried = {} -- [key] = time picked by itself

function A.Wanted()
  local db = D.DB()
  return (db.autoAccept or db.autoTurnIn or db.service) and true or false
end

local function Shift()
  return IsShiftKeyDown and IsShiftKeyDown() or false
end

local function Fresh(key)
  local at = key and tried[key]
  return not (at and GetTime() - at < 60)
end

local function Mark(key)
  if key then
    tried[key] = GetTime()
  end
end

local serviceIcons
local function ServiceIcons()
  if serviceIcons then
    return serviceIcons
  end
  serviceIcons = {}
  for _, name in ipairs(SERVICES) do
    local path = "Interface\\GossipFrame\\" .. name .. "GossipIcon"
    serviceIcons[path:lower()] = true
    local id = type(_G.GetFileIDFromPath) == "function" and Num(Call(GetFileIDFromPath, path))
    if id then
      serviceIcons[id] = true
    end
  end
  return serviceIcons
end

function A.IsService(option)
  if type(option) ~= "table" then
    return false
  end
  local icons = ServiceIcons()
  local id, override, path = Num(option.icon), Num(option.overrideIconID), Str(option.icon)
  return (id and icons[id]) or (override and icons[override]) or (path and icons[path:lower()]) or false
end

local function Repeatable(info)
  return info.repeatable == true or (Num(info.frequency) or 0) > 0
end

function A.OnGossip()
  if Shift() or not C_GossipInfo then
    return false
  end
  local db = D.DB()
  local active = Call(C_GossipInfo.GetActiveQuests) or {}
  local available = Call(C_GossipInfo.GetAvailableQuests) or {}
  if db.autoTurnIn then
    for _, info in ipairs(active) do
      local id = type(info) == "table" and Num(info.questID)
      if id and info.isComplete == true and not Repeatable(info) and Fresh(id) then
        Mark(id)
        D.picked, D.pickedRow = true, { id = id, title = Str(info.title) or "", repeatable = false }
        pcall(C_GossipInfo.SelectActiveQuest, id)
        return true
      end
    end
  end
  if db.autoAccept then
    for _, info in ipairs(available) do
      local id = type(info) == "table" and Num(info.questID)
      if id and info.isTrivial ~= true and not Repeatable(info) and Fresh(id) then
        Mark(id)
        D.picked, D.pickedRow = true, { id = id, title = Str(info.title) or "", repeatable = false }
        pcall(C_GossipInfo.SelectAvailableQuest, id)
        return true
      end
    end
  end
  if db.service and #active == 0 and #available == 0 then
    local options = Call(C_GossipInfo.GetOptions) or {}
    if #options == 1 and A.IsService(options[1]) and Call(C_GossipInfo.ForceGossip) ~= true
      and Num(options[1].orderIndex) then
      pcall(C_GossipInfo.SelectOptionByIndex, options[1].orderIndex)
      return true
    end
  end
  return false
end

function A.OnGreeting()
  if Shift() then
    return false
  end
  local db = D.DB()
  if db.autoTurnIn then
    for index = 1, Num(Call(_G.GetNumActiveQuests)) or 0 do
      local title, complete = Call(_G.GetActiveTitle, index)
      local id = Num(Call(_G.GetActiveQuestID, index))
      local key = id or Str(title)
      local repeatable = id and C_QuestLog and Call(C_QuestLog.IsRepeatableQuest, id) == true
      if (complete == true or complete == 1) and not repeatable and Fresh(key) then
        Mark(key)
        D.picked, D.pickedRow = true, { id = id, title = Str(title) or "", repeatable = false }
        pcall(_G.SelectActiveQuest, index)
        return true
      end
    end
  end
  if db.autoAccept then
    for index = 1, Num(Call(_G.GetNumAvailableQuests)) or 0 do
      local trivial, frequency, repeatable, _, id = Call(_G.GetAvailableQuestInfo, index)
      id = Num(id)
      local key = id or Str(Call(_G.GetAvailableTitle, index))
      if trivial ~= true and repeatable ~= true and (Num(frequency) or 0) == 0 and Fresh(key) then
        Mark(key)
        D.picked, D.pickedRow = true, { id = id, title = Str(Call(_G.GetAvailableTitle, index)) or "", repeatable = false }
        pcall(_G.SelectAvailableQuest, index)
        return true
      end
    end
  end
  return false
end

local function QuestRepeatable()
  local id = Num(Call(_G.GetQuestID))
  if id and C_QuestLog and Call(C_QuestLog.IsRepeatableQuest, id) == true then
    return true
  end
  local row = D.pickedRow
  return row and row.repeatable and (not row.id or row.id == id) or false
end

function A.OnDetail()
  if Shift() or not D.DB().autoAccept then
    return false
  end
  if Call(_G.QuestGetAutoAccept) == true then
    pcall(_G.AcknowledgeAutoAcceptQuest)
    return true
  end
  if Call(_G.QuestFlagsPVP) == true or QuestRepeatable() then
    return false
  end
  if type(_G.AcceptQuest) ~= "function" then
    return false
  end
  pcall(AcceptQuest)
  return true
end

-- Does the hand-in take battleground marks?
local function TakesMarks()
  if (Num(Call(_G.GetNumQuestCurrencies)) or 0) > 0 then
    return true
  end
  for index = 1, Num(Call(_G.GetNumQuestItems)) or 0 do
    local link = Str(Call(_G.GetQuestItemLink, "required", index))
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and BG_MARKS[id] then
      return true
    end
  end
  return false
end

local function Costs()
  return (Num(Call(_G.GetQuestMoneyToGet)) or 0) > 0
end

function A.OnProgress()
  if Shift() or not D.DB().autoTurnIn then
    return false
  end
  if Call(_G.IsQuestCompletable) ~= true or QuestRepeatable() or Costs() or TakesMarks() then
    return false
  end
  if type(_G.CompleteQuest) ~= "function" then
    return false
  end
  pcall(CompleteQuest)
  return true
end

function A.OnComplete()
  if Shift() or not D.DB().autoTurnIn then
    return false
  end
  local choices = Num(Call(_G.GetNumQuestChoices)) or 0
  if choices > 1 or QuestRepeatable() or Costs() then
    return false
  end
  if type(_G.GetQuestReward) ~= "function" then
    return false
  end
  pcall(GetQuestReward, choices == 1 and 1 or 0)
  return true
end

function A.Forget()
  tried = {}
end
