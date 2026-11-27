local addonName, ns = ...
local L = ns.L

-- Quest info in tooltips: a mob or item that one of your active quests needs gets the quest's title (in its
-- difficulty colour) and the matching objective ("Witherbark Scalper slain: 3/10", green with a tick when done)
-- at the end of its tooltip. Bag items that start a quest get "Starts a quest" (unless the game already says so).
--
-- No quest database: the match is by name. The quest log's objective texts ("<name> slain: x/y", "<name>: x/y",
-- or "x/y <name>") are read into an index by lower-case name; QUEST_LOG_UPDATE and friends only mark it stale and
-- the next lookup rebuilds it, so a tooltip costs one table lookup. Mobs that merely drop a quest item are not
-- known this way. ns.qol.QuestIndex() is shared (the Highlight module reuses it).
-- When the game's tooltip data already carries quest lines (Enum.TooltipDataLineType.QuestObjective / QuestTitle /
-- QuestPlayer) nothing is added. Secret unit names (enemy units on Forever) are skipped.

local Q = ns.qol
local QT = {}
Q.quests = QT

local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t "

-- The quest objective index ------------------------------------------------------------------------------------

local index = { byName = {}, quests = {}, version = 0 }
local stale = true

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- "Witherbark Scalper slain: 3/10" -> "Witherbark Scalper", 3, 10.
-- The word the game puts after a creature's name in a kill objective (QUEST_MONSTERS_KILLED "%s slain: %d/%d"; in
-- German " getötet"), so other languages find the creature's name too (2026-11-27 audit). English as a fallback.
local slainFrom, slainWord
local function Slain()
  local format = QUEST_MONSTERS_KILLED
  if format ~= slainFrom then
    slainFrom = format
    local word = type(format) == "string" and format:match("^%%s(.-):")
    slainWord = word and word ~= "" and word or " slain"
  end
  return slainWord or " slain"
end
QT.Slain = Slain

function QT.ParseObjective(text)
  if type(text) ~= "string" then
    return nil
  end
  local name, have, need = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
  if not name then
    have, need, name = text:match("^%s*(%d+)%s*/%s*(%d+)%s+(.-)%s*$")
  end
  if not name then
    return nil
  end
  local slain = Slain()
  if name:sub(-#slain) == slain then
    name = name:sub(1, -#slain - 1)
  end
  name = name:gsub("%s+slain$", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return nil
  end
  return name, tonumber(have), tonumber(need)
end

-- Every quest in the log: { questID, title, level, objectives = { { text, type, finished } } }.
local function ReadLog()
  local quests = {}
  local log = C_QuestLog
  if log and log.GetNumQuestLogEntries and log.GetInfo and log.GetQuestObjectives then
    for i = 1, log.GetNumQuestLogEntries() or 0 do
      local info = log.GetInfo(i)
      if type(info) == "table" and not info.isHeader and not info.isHidden and info.questID then
        quests[#quests + 1] = { questID = info.questID, title = info.title, level = info.level or info.difficultyLevel,
          objectives = log.GetQuestObjectives(info.questID) or {} }
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local title, level, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
      if title and not isHeader then
        local objectives = {}
        for j = 1, (GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i)) or 0 do
          local text, kind, finished = GetQuestLogLeaderBoard(j, i)
          objectives[#objectives + 1] = { text = text, type = kind, finished = finished }
        end
        quests[#quests + 1] = { questID = questID, title = title, level = level, objectives = objectives }
      end
    end
  end
  return quests
end

local function Rebuild()
  stale = false
  local byName = {}
  local quests = ReadLog()
  for _, quest in ipairs(quests) do
    for n, objective in ipairs(quest.objectives) do
      local name, have, need = QT.ParseObjective(objective.text)
      if name then
        local key = name:lower()
        byName[key] = byName[key] or {}
        table.insert(byName[key], { quest = quest, index = n, name = name, text = objective.text,
          type = objective.type, have = have, need = need,
          done = objective.finished and true or (have and need and have >= need) or false })
      end
    end
  end
  index = { byName = byName, quests = quests, version = index.version + 1 }
end

-- { byName = { [lower-case name] = { { quest, index, name, text, type, have, need, done }, ... } },
--   quests = { ... }, version = n } (version goes up on every rebuild).
function Q.QuestIndex()
  if stale then
    Rebuild()
  end
  return index
end

function QT.MarkStale()
  stale = true
end

function QT.Lookup(name)
  if not Readable(name) or type(name) ~= "string" or name == "" then
    return nil
  end
  return Q.QuestIndex().byName[name:lower()]
end

-- Tooltip lines ------------------------------------------------------------------------------------------------

local function QuestColor(level)
  if level and GetQuestDifficultyColor then
    local color = GetQuestDifficultyColor(level)
    if type(color) == "table" and color.r then
      return color.r, color.g, color.b
    end
  end
  return 1, 0.82, 0
end

-- The lines for a list of matches: per quest its title, then its objectives.
function QT.Lines(matches)
  local lines, seen = {}, {}
  for _, match in ipairs(matches) do
    local quest = match.quest
    if not seen[quest] then
      seen[quest] = true
      local r, g, b = QuestColor(quest.level)
      local title = quest.level and ("[" .. quest.level .. "] " .. (quest.title or "")) or (quest.title or "")
      lines[#lines + 1] = { title, r, g, b }
      for _, other in ipairs(matches) do
        if other.quest == quest then
          if other.done then
            lines[#lines + 1] = { "  " .. TICK .. other.text, 0.25, 1, 0.25 }
          else
            lines[#lines + 1] = { "  " .. other.text, 1, 1, 1 }
          end
        end
      end
    end
  end
  return lines
end

local QUEST_LINE_TYPES = { "QuestObjective", "QuestTitle", "QuestPlayer" }

-- The game's tooltip data already lists quest lines (or says the item starts a quest).
local function GameHasQuestLines(data)
  if type(data) ~= "table" or type(data.lines) ~= "table" then
    return false, false
  end
  local types = Enum and Enum.TooltipDataLineType
  local quest, starts = false, false
  for _, line in ipairs(data.lines) do
    if types then
      for _, name in ipairs(QUEST_LINE_TYPES) do
        if types[name] ~= nil and line.type == types[name] then
          quest = true
        end
      end
    end
    local text = line.leftText
    if ITEM_STARTS_QUEST and Readable(text) and text == ITEM_STARTS_QUEST then
      starts = true
    end
  end
  return quest, starts
end

local added = setmetatable({}, { __mode = "k" }) -- [tooltip] = what we added since it was last cleared
local hooked = setmetatable({}, { __mode = "k" })

local function Usable(tooltip)
  if tooltip.IsForbidden and tooltip:IsForbidden() then
    return false
  end
  if tooltip.GetWidth and canaccessvalue and not canaccessvalue(tooltip:GetWidth()) then
    return false -- secret width
  end
  local name = tooltip.GetName and tooltip:GetName()
  if name ~= nil and (not Readable(name) or name:find("^ShoppingTooltip")) then
    return false
  end
  return true
end

local function Add(tooltip, key, lines)
  if #lines == 0 or added[tooltip] == key then
    return
  end
  if not hooked[tooltip] and tooltip.HookScript then
    hooked[tooltip] = true
    tooltip:HookScript("OnTooltipCleared", function(self)
      added[self] = nil
    end)
  end
  added[tooltip] = key
  -- the "Quest" section heading of the tooltip skin (TylesserCodex.TooltipSection), when it is on
  if ns.API.TooltipSection then
    ns.API.TooltipSection(tooltip, L["Quest"])
  end
  for _, line in ipairs(lines) do
    tooltip:AddLine(line[1], line[2], line[3], line[4])
  end
  if tooltip.Show and tooltip.IsShown and tooltip:IsShown() then
    tooltip:Show() -- resize
  end
end

local function UnitName_(tooltip, data)
  if tooltip.GetUnit then
    local name = tooltip:GetUnit()
    if name ~= nil then
      return name
    end
  end
  local first = type(data) == "table" and type(data.lines) == "table" and data.lines[1]
  return first and first.leftText or nil
end

function QT.OnUnit(tooltip, data)
  if not Q.On("questTooltips") or not Usable(tooltip) then
    return
  end
  if (GameHasQuestLines(data)) then
    return
  end
  local name = UnitName_(tooltip, data)
  if not Readable(name) then
    return -- secret name
  end
  local matches = QT.Lookup(name)
  if matches then
    Add(tooltip, "unit:" .. name, QT.Lines(matches))
  end
end

local function ItemOf(tooltip, data)
  local id = type(data) == "table" and data.id
  if Readable(id) and type(id) == "number" then
    return id
  end
  if tooltip.GetItem then
    local _, link = tooltip:GetItem()
    if Readable(link) and type(link) == "string" then
      return tonumber(link:match("item:(%d+)"))
    end
  end
  return nil
end

-- A bag item the tooltip is shown for: its quest info from the container API.
local function BagQuestInfo(tooltip)
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  if type(owner) ~= "table" or not (C_Container and C_Container.GetContainerItemQuestInfo) then
    return nil
  end
  local bag = owner.GetBagID and owner:GetBagID()
  if bag == nil and owner.GetParent then
    local parent = owner:GetParent()
    bag = parent and parent.GetID and parent:GetID()
  end
  local slot = owner.GetID and owner:GetID()
  if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 then
    return nil
  end
  local ok, info = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
  return ok and type(info) == "table" and info or nil
end

function QT.OnItem(tooltip, data)
  if not Q.On("questTooltips") or not Usable(tooltip) then
    return
  end
  local gameQuest, gameStarts = GameHasQuestLines(data)
  if gameQuest then
    return
  end
  local id = ItemOf(tooltip, data)
  if not id then
    return
  end
  local lines = {}
  local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
    or (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id))
  local matches = QT.Lookup(name)
  if matches then
    lines = QT.Lines(matches)
  end
  if not gameStarts then
    local info = BagQuestInfo(tooltip)
    if info and info.questID and not info.isActive then
      lines[#lines + 1] = { L["Starts a quest"], 1, 0.82, 0 }
    end
  end
  Add(tooltip, "item:" .. id, lines)
end

local function Safe(fn)
  return function(tooltip, data)
    local ok, err = pcall(fn, tooltip, data)
    if not ok then
      geterrorhandler()(err)
    end
  end
end

function QT.Enable()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function()
    stale = true
  end)
  for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
    events:RegisterEvent(event)
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Safe(QT.OnUnit))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Safe(QT.OnItem))
  end
end

function QT.Elsewhere()
  if ns.IsAddOnLoaded("Questie") then
    return "Questie"
  end
  return nil
end

Q.AddToggle({
  key = "questTooltips",
  name = L["Quest info in tooltips"],
  desc = L["Mobs and items your quests need show the quest and your progress (\"Witherbark Scalper slain: 3/10\"); bag items that start a quest say so."],
  order = 20,
  Enable = QT.Enable,
  Elsewhere = QT.Elsewhere,
})
