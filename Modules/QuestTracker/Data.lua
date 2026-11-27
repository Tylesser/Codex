local addonName, ns = ...
local L = ns.L

-- Quest tracker, part 1: what to show. The tracked quests (the game's watch list) in QuestOrder's order, under a
-- heading per zone (the zone you're in first), each quest's title with its level in the theme's difficulty colour,
-- its objectives (GetQuestLogLeaderBoard, as Blizzard's tracker: forever branch QuestObjectiveTrackerMixin:
-- DoQuestObjectives) or "Ready for turn-in" / "Failed", and its quest item (GetQuestLogSpecialItemInfo).
-- Every game value is read through QuestOrder's Readable helpers.

local QO = ns.QuestOrder
local QT = {}
ns.questtracker = QT

local Ask, API, Num, Str = QO.Ask, QO.API, QO.Num, QO.Str

-- Blizzard's difficulty colour names -> the theme's colour tokens (the same mapping as the tracker skin's titles)
QT.DIFFICULTY_TOKEN = { impossible = "bad", verydifficult = "orange", difficult = "warn", standard = "good",
  trivial = "muted", header = "accent", disabled = "muted" }

local function Near(a, b)
  return math.abs(a.r - b.r) < 0.03 and math.abs(a.g - b.g) < 0.03 and math.abs(a.b - b.b) < 0.03
end

-- The theme token for a quest of this level: the game's GetQuestDifficultyColor matched against
-- QuestDifficultyColors; without them, the classic rule (5+ levels above = red, 3-4 orange, within 2 yellow,
-- green down to the grey level, then grey).
function QT.DifficultyToken(level)
  level = Num(level)
  if not level then
    return "good"
  end
  local color = Ask(GetQuestDifficultyColor, level)
  if type(color) == "table" and type(QuestDifficultyColors) == "table" and Num(color.r) then
    for name, known in pairs(QuestDifficultyColors) do
      if type(known) == "table" and Num(known.r) and Near(color, known) and QT.DIFFICULTY_TOKEN[name] then
        return QT.DIFFICULTY_TOKEN[name]
      end
    end
  end
  local mine = Num(Ask(UnitLevel, "player")) or level
  local diff = level - mine
  if diff >= 5 then
    return "bad"
  elseif diff >= 3 then
    return "orange"
  elseif diff >= -2 then
    return "warn"
  end
  local grey = Num(Ask(GetQuestGreenRange)) or 8
  return -diff > grey and "muted" or "good"
end

-- The quest's item: { link, itemID, texture, charges } or nil (shown while the quest isn't complete, or when the
-- game says to show it then too, as QuestUtil.QuestShowsItemByIndex).
function QT.QuestItem(logIndex, complete)
  if not logIndex then
    return nil
  end
  local link, texture, charges, showWhenComplete = Ask(GetQuestLogSpecialItemInfo, logIndex)
  link = Str(link)
  if not link or (complete and showWhenComplete ~= true) then
    return nil
  end
  local itemID = tonumber(link:match("item:(%d+)") or "")
  if not itemID then
    return nil
  end
  return { link = link, itemID = itemID, texture = Num(texture) or Str(texture), charges = Num(charges) }
end

-- The quest's objective lines: { text, finished } (empty when the game gives none).
function QT.Objectives(logIndex)
  local list = {}
  if not logIndex then
    return list
  end
  local count = Num(Ask(GetNumQuestLeaderBoards, logIndex)) or 0
  for index = 1, count do
    local text, _, finished = Ask(GetQuestLogLeaderBoard, index, logIndex, true)
    text = Str(text)
    if text then
      list[#list + 1] = { text = text, finished = finished == true }
    end
  end
  return list
end

local function ZoneTitle(entries, here)
  if here then
    for _, entry in ipairs(entries) do
      if entry.header and QO.ZoneNames()[entry.header:lower()] then
        return entry.header
      end
    end
    return Str(Ask(GetRealZoneText)) or entries[1].header or L["Here"]
  end
  return entries[1].header or L["Other quests"]
end

-- The groups to show: { key, title, here, quests = { { id, logIndex, title, level, token, complete, failed,
-- objectives, item, focused } } }, in order.
function QT.Groups()
  local _, entries = QO.Sorted()
  local groups, current = {}, nil
  local focused = C_SuperTrack and Num(Ask(C_SuperTrack.GetSuperTrackedQuestID))
  for _, entry in ipairs(entries) do
    local key = entry.here and "here" or ("zone:" .. entry.zone)
    if not current or current.key ~= key then
      current = { key = key, here = entry.here, entries = {}, quests = {} }
      groups[#groups + 1] = current
    end
    current.entries[#current.entries + 1] = entry
    local info = entry.info or {}
    local logIndex = info.logIndex or Num(Ask(API("GetLogIndexForQuestID"), entry.id))
    local title = info.title or Str(Ask(API("GetTitleForQuestID"), entry.id)) or L["Quest %d"]:format(entry.id)
    local complete = Ask(API("IsComplete"), entry.id) == true
    local failed = Ask(API("IsFailed"), entry.id) == true
    current.quests[#current.quests + 1] = {
      id = entry.id,
      logIndex = logIndex,
      title = title,
      level = info.level,
      token = QT.DifficultyToken(info.level),
      complete = complete,
      failed = failed,
      objectives = (complete or failed) and {} or QT.Objectives(logIndex),
      completion = complete and Str(Ask(GetQuestLogCompletionText, logIndex)) or nil,
      item = QT.QuestItem(logIndex, complete),
      focused = focused ~= nil and focused == entry.id,
    }
  end
  for _, group in ipairs(groups) do
    group.title = ZoneTitle(group.entries, group.here)
    group.fold = group.here and "here" or (group.title or ""):lower()
    group.entries = nil
  end
  return groups
end

-- The rows the window draws: { kind = "zone" | "quest" | "objective" | "done" | "failed", key, text, token, ... }.
-- Folded zones show their heading with the count only; a collapsed tracker shows nothing but its header.
function QT.Rows(groups, folded, collapsed)
  local rows = {}
  if collapsed then
    return rows
  end
  for _, group in ipairs(groups) do
    local isFolded = folded and folded[group.fold] and true or false
    rows[#rows + 1] = { kind = "zone", key = "z:" .. group.key, text = group.title, count = #group.quests,
      folded = isFolded, fold = group.fold, here = group.here }
    if not isFolded then
      for _, quest in ipairs(group.quests) do
        local label = quest.level and ("[" .. quest.level .. "] " .. quest.title) or quest.title
        rows[#rows + 1] = { kind = "quest", key = "q:" .. quest.id, id = quest.id, text = label,
          token = quest.token, item = quest.item, logIndex = quest.logIndex, focused = quest.focused }
        if quest.complete then
          rows[#rows + 1] = { kind = "done", key = "d:" .. quest.id, id = quest.id,
            text = quest.completion or _G.QUEST_WATCH_QUEST_READY or "Ready for turn-in", token = "good" }
        elseif quest.failed then
          rows[#rows + 1] = { kind = "failed", key = "f:" .. quest.id, id = quest.id,
            text = _G.FAILED or "Failed", token = "bad" }
        else
          for index, objective in ipairs(quest.objectives) do
            rows[#rows + 1] = { kind = "objective", key = "o:" .. quest.id .. ":" .. index, id = quest.id,
              text = objective.text, token = objective.finished and "good" or "text", finished = objective.finished }
          end
        end
      end
    end
  end
  return rows
end

-- The rows' shape, without their texts: two lists with the same shape can be refilled in place (in a fight).
function QT.Shape(rows)
  local keys = {}
  for index, row in ipairs(rows) do
    keys[index] = row.key .. (row.item and ("#" .. row.item.itemID) or "")
  end
  return table.concat(keys, "|")
end
