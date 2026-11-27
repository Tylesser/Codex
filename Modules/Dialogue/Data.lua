local addonName, ns = ...
local L = ns.L

-- Reads what the game knows about the NPC talk into a plain page table, so drawing and keys never touch the game's
-- APIs (and tests can check the content). Every value goes through D.Str / D.Num: a secret or a missing function
-- gives nil, never an error. Names come from the `forever` branch of Gethe/wow-ui-source (QuestFrame.lua,
-- QuestInfo.lua, GossipFrameShared.lua, GossipInfoDocumentation.lua).
--
-- page = { kind, unit, npc, zone, text, title, level, questID, rows, objectives, group, choices, rewards, money,
--          xp, cost, spells, currencies, rep, need, completable, repeatable, autoAccept, pvp, choice }

local D = ns.dialogue

local Str, Num, Call, Raw = D.Str, D.Num, D.Call, D.Raw
local FREQUENCY_DAILY = 1

function D.Zone()
  local sub = Raw(Call(_G.GetSubZoneText))
  if D.HasText(sub) then
    return sub
  end
  return Raw(Call(_G.GetZoneText)) or ""
end

-- The quest's difficulty against the player's level, as the game colours it: red, orange, yellow, green, grey.
function D.Difficulty(level, trivial)
  if trivial then
    return "grey"
  end
  local mine = Num(Call(_G.UnitLevel, "player"))
  if not (Num(level) and mine) or level <= 0 then
    return "yellow"
  end
  local diff = level - mine
  if diff >= 5 then
    return "red"
  elseif diff >= 3 then
    return "orange"
  elseif diff >= -2 then
    return "yellow"
  end
  return "green"
end

-- "3/12" for a quest in the log with a single counted objective, else nil.
local function Progress(questID)
  if not (Num(questID) and C_QuestLog and C_QuestLog.GetQuestObjectives) then
    return nil
  end
  local objectives = Call(C_QuestLog.GetQuestObjectives, questID)
  if type(objectives) ~= "table" or #objectives ~= 1 then
    return nil
  end
  local have, need = Num(objectives[1].numFulfilled), Num(objectives[1].numRequired)
  if have and need and need > 1 then
    return ("%d/%d"):format(have, need)
  end
  return nil
end

local function QuestLevel(questID, level)
  level = Num(level)
  if level and level > 0 then
    return level
  end
  if Num(questID) and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
    level = Num(Call(C_QuestLog.GetQuestDifficultyLevel, questID))
    if level and level > 0 then
      return level
    end
  end
  return nil
end

-- Tag on the right of a quest row: Ready, Repeatable, Low level, Daily or the progress.
local function Tag(row)
  if row.active and row.complete then
    return L["Ready"], "good"
  elseif row.daily then
    return L["Daily"], "muted"
  elseif row.repeatable then
    return L["Repeatable"], "muted"
  elseif row.active then
    return Progress(row.id), "muted"
  elseif row.trivial then
    return L["Low level"], "muted"
  end
  return nil
end

local function FinishRow(row)
  row.tag, row.tagColor = Tag(row)
  row.difficulty = D.Difficulty(row.level, row.trivial)
  return row
end

-- The order of the rows (board R4-Gossip): quests ready to hand in, your other quests, new quests, then the
-- NPC's own options.
local function SortQuests(rows)
  local ready, current, new = {}, {}, {}
  for _, row in ipairs(rows) do
    if row.active and row.complete then
      ready[#ready + 1] = row
    elseif row.active then
      current[#current + 1] = row
    else
      new[#new + 1] = row
    end
  end
  local out = {}
  for _, list in ipairs({ ready, current, new }) do
    for _, row in ipairs(list) do
      out[#out + 1] = row
    end
  end
  return out
end

local function GossipQuestRow(info, active)
  if type(info) ~= "table" then
    return nil
  end
  local id = Num(info.questID)
  if not id then
    return nil
  end
  local frequency = Num(info.frequency) or 0
  return FinishRow({
    kind = "quest", from = "gossip", active = active, id = id,
    title = Raw(info.title) or "", level = QuestLevel(id, info.questLevel),
    complete = active and info.isComplete == true or false,
    trivial = info.isTrivial == true, daily = frequency == FREQUENCY_DAILY,
    repeatable = info.repeatable == true or frequency > 0, legendary = info.isLegendary == true,
  })
end

-- Option text as the game writes it: "(Quest) ..." when the option belongs to a quest.
local function OptionText(info)
  local name = Raw(info.name) or ""
  if not D.Readable(name) then
    return name -- a secret: shown as it is
  end
  local flags = Num(info.flags)
  local recFlags = Enum and Enum.GossipOptionRecFlags
  if flags and recFlags and recFlags.QuestLabelPrepend and bit and bit.band
    and bit.band(flags, recFlags.QuestLabelPrepend) ~= 0 then
    local prepend = Str(_G.QUEST_PREPEND) or "(Quest)"
    return prepend .. " " .. name
  end
  return name
end

function D.ReadGossip()
  local page = { kind = "gossip", unit = "npc", rows = {} }
  page.npc = Raw(Call(_G.UnitName, "npc")) or ""
  page.zone = D.Zone()
  page.text = Raw(C_GossipInfo and Call(C_GossipInfo.GetText)) or ""
  local quests = {}
  if C_GossipInfo then
    for _, info in ipairs(Call(C_GossipInfo.GetActiveQuests) or {}) do
      quests[#quests + 1] = GossipQuestRow(info, true)
    end
    for _, info in ipairs(Call(C_GossipInfo.GetAvailableQuests) or {}) do
      quests[#quests + 1] = GossipQuestRow(info, false)
    end
  end
  page.rows = SortQuests(quests)
  local options = {}
  for _, info in ipairs(C_GossipInfo and Call(C_GossipInfo.GetOptions) or {}) do
    if type(info) == "table" and Num(info.orderIndex) then
      options[#options + 1] = {
        kind = "option", title = OptionText(info), index = info.orderIndex, id = Num(info.gossipOptionID),
        icon = Num(info.overrideIconID) or Num(info.icon) or Str(info.icon), spellID = Num(info.spellID),
        status = Num(info.status),
      }
    end
  end
  table.sort(options, function(a, b)
    return a.index < b.index
  end)
  for _, row in ipairs(options) do
    page.rows[#page.rows + 1] = row
  end
  return page
end

function D.ReadGreeting()
  local page = { kind = "greeting", unit = "questnpc", rows = {} }
  page.npc = Raw(Call(_G.UnitName, "questnpc")) or Raw(Call(_G.UnitName, "npc")) or ""
  page.zone = D.Zone()
  page.text = Raw(Call(_G.GetGreetingText)) or ""
  local quests = {}
  for index = 1, Num(Call(_G.GetNumActiveQuests)) or 0 do
    local title, complete = Call(_G.GetActiveTitle, index)
    local id = Num(Call(_G.GetActiveQuestID, index))
    quests[#quests + 1] = FinishRow({
      kind = "quest", from = "greeting", active = true, index = index, id = id, title = Raw(title) or "",
      complete = complete == true or complete == 1, trivial = Call(_G.IsActiveQuestTrivial, index) == true,
      level = QuestLevel(id, Call(_G.GetActiveLevel, index)),
      repeatable = id and C_QuestLog and Call(C_QuestLog.IsRepeatableQuest, id) == true or false,
    })
  end
  for index = 1, Num(Call(_G.GetNumAvailableQuests)) or 0 do
    local trivial, frequency, repeatable, legendary, id = Call(_G.GetAvailableQuestInfo, index)
    id = Num(id)
    frequency = Num(frequency) or 0
    quests[#quests + 1] = FinishRow({
      kind = "quest", from = "greeting", active = false, index = index, id = id,
      title = Raw(Call(_G.GetAvailableTitle, index)) or "", trivial = trivial == true,
      daily = frequency == FREQUENCY_DAILY, repeatable = repeatable == true or frequency > 0, legendary = legendary == true,
      level = QuestLevel(id, Call(_G.GetAvailableLevel, index)),
    })
  end
  page.rows = SortQuests(quests)
  return page
end

-- Reward or choice items: { name, texture, count, quality, usable, link, type, index }.
local function Items(kind, count)
  local list = {}
  for index = 1, count or 0 do
    local name, texture, number, quality, usable = Call(_G.GetQuestItemInfo, kind, index)
    list[#list + 1] = {
      kind = kind, index = index, name = Raw(name) or "", texture = Num(texture) or Str(texture),
      count = Num(number) or 1, quality = Num(quality), usable = usable ~= false,
      link = Str(Call(_G.GetQuestItemLink, kind, index)),
    }
  end
  return list
end

local function Rewards(page)
  page.choices = Items("choice", Num(Call(_G.GetNumQuestChoices)) or 0)
  page.rewards = Items("reward", Num(Call(_G.GetNumQuestRewards)) or 0)
  page.money = Num(Call(_G.GetRewardMoney)) or 0
  page.xp = Num(Call(_G.GetRewardXP)) or 0
  local skillName, _, skillPoints = Call(_G.GetRewardSkillPoints)
  if Str(skillName) and Num(skillPoints) and skillPoints > 0 then
    page.skill = { name = skillName, points = skillPoints }
  end
  page.spells = {}
  local questID = page.questID
  if questID and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells then
    for _, spellID in ipairs(Call(C_QuestInfoSystem.GetQuestRewardSpells, questID) or {}) do
      local info = Num(spellID) and Call(C_QuestInfoSystem.GetQuestRewardSpellInfo, questID, spellID)
      if type(info) == "table" and Str(info.name) then
        page.spells[#page.spells + 1] = { name = info.name, texture = info.texture, spellID = spellID }
      end
    end
  end
  page.currencies = {}
  if questID and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardCurrencies then
    for _, info in ipairs(Call(C_QuestInfoSystem.GetQuestRewardCurrencies, questID) or {}) do
      if type(info) == "table" and Str(info.name) then
        page.currencies[#page.currencies + 1] = { name = info.name, amount = Num(info.totalRewardAmount) or Num(info.baseRewardAmount) or 0 }
      end
    end
  end
  page.rep = D.Reputation(questID)
end

local function QuestBase(kind)
  local page = { kind = kind, unit = "questnpc" }
  page.npc = Raw(Call(_G.UnitName, "questnpc")) or Raw(Call(_G.UnitName, "npc")) or ""
  page.zone = D.Zone()
  page.questID = Num(Call(_G.GetQuestID))
  page.title = Raw(Call(_G.GetTitleText)) or ""
  local row = D.pickedRow
  local rowTitle, title = D.Str(row and row.title), D.Str(page.title)
  if row and (row.id == nil or page.questID == nil or row.id == page.questID)
    and (not rowTitle or not title or rowTitle == "" or rowTitle == title) then
    page.level, page.repeatable = row.level, row.repeatable
  end
  page.level = page.level or QuestLevel(page.questID)
  if page.questID and C_QuestLog and Call(C_QuestLog.IsRepeatableQuest, page.questID) == true then
    page.repeatable = true
  end
  page.repeatable = page.repeatable or false
  page.cost = Num(Call(_G.GetQuestMoneyToGet)) or 0
  return page
end

function D.ReadDetail()
  local page = QuestBase("detail")
  page.text = Raw(Call(_G.GetQuestText)) or ""
  page.objectives = Raw(Call(_G.GetObjectiveText)) or ""
  page.group = Num(Call(_G.GetSuggestedGroupSize)) or 0
  page.autoAccept = Call(_G.QuestGetAutoAccept) == true
  page.pvp = Call(_G.QuestFlagsPVP) == true
  Rewards(page)
  return page
end

local function HaveCount(item)
  local key = item.link or D.Str(item.name)
  if not key or key == "" then
    return nil
  end
  local count
  if C_Item and C_Item.GetItemCount then
    count = Num(Call(C_Item.GetItemCount, key))
  end
  if not count and type(_G.GetItemCount) == "function" then
    count = Num(Call(_G.GetItemCount, key))
  end
  return count
end

function D.ReadProgress()
  local page = QuestBase("progress")
  page.text = Raw(Call(_G.GetProgressText)) or ""
  page.completable = Call(_G.IsQuestCompletable) == true
  page.need = {}
  local hide = C_QuestOffer and Call(C_QuestOffer.GetHideRequiredItems) == true
  if not hide then
    for _, item in ipairs(Items("required", Num(Call(_G.GetNumQuestItems)) or 0)) do
      local hidden = Num(Call(_G.IsQuestItemHidden, item.index))
      if not hidden or hidden == 0 then
        item.need = item.count
        item.have = HaveCount(item)
        page.need[#page.need + 1] = item
      end
    end
  end
  for index = 1, Num(Call(_G.GetNumQuestCurrencies)) or 0 do
    local info = C_QuestOffer and Call(C_QuestOffer.GetQuestRequiredCurrencyInfo, index)
    if type(info) == "table" and Str(info.name) then
      page.need[#page.need + 1] = { kind = "currency", index = index, name = info.name, texture = info.texture,
        need = Num(info.requiredAmount) or 1, count = Num(info.requiredAmount) or 1 }
    end
  end
  return page
end

function D.ReadReward()
  local page = QuestBase("reward")
  page.text = Raw(Call(_G.GetRewardText)) or ""
  Rewards(page)
  page.choice = #page.choices == 1 and 1 or 0
  return page
end

local READERS = { gossip = D.ReadGossip, greeting = D.ReadGreeting, detail = D.ReadDetail,
  progress = D.ReadProgress, reward = D.ReadReward }

function D.Read(kind)
  local reader = READERS[kind]
  if not reader then
    return nil
  end
  local ok, page = pcall(reader)
  if not ok then
    geterrorhandler()(page)
    return nil
  end
  return page
end

-- Several rewards to choose from and none picked yet.
function D.NeedsChoice(page)
  page = page or D.page
  return page and page.kind == "reward" and #(page.choices or {}) > 1 and (page.choice or 0) == 0 or false
end
