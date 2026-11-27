local addonName, ns = ...
local L = ns.L

-- Quest pages (board R4-Quest): the offer ("A quest is offered"), progress ("Back before it is done") and reward
-- ("Hand it in and choose a reward"). Title in the body font, the text, then Objectives / Bring / Choose your
-- reward, reward slots with a thin ring in the item's quality colour, chips for money, experience and reputation
-- ("+75 Booty Bay", Reputation.lua). Reward choices are rows you click (Tab moves on); Stat Delta's stat changes
-- and upgrade arrow show on them while that module is on. Shift over an item shows the game's tooltip with the
-- comparison.

local D = ns.dialogue
local UI = ns.UI
local T = ns.T

local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local ARROW = "Interface\\Buttons\\Arrow-Down-Up"

local function Color(texture, color, alpha)
  texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function Hex(color)
  return ("%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
    math.floor(color[3] * 255 + 0.5))
end

local function Number(value)
  local ok, text = pcall(_G.BreakUpLargeNumbers or tostring, value)
  return ok and D.Str(text) or tostring(value)
end

-- "Feet · Leather", "One-Hand · Swords", "Consumable".
function D.ItemTypeText(link)
  if not (link and C_Item and C_Item.GetItemInfoInstant) then
    return ""
  end
  local _, itemType, subType, equipLoc = D.Call(C_Item.GetItemInfoInstant, link)
  itemType, subType, equipLoc = D.Str(itemType), D.Str(subType), D.Str(equipLoc)
  local slot = equipLoc and equipLoc ~= "" and D.Str(_G[equipLoc])
  if slot and subType and subType ~= "" and subType ~= slot then
    return slot .. " · " .. subType
  end
  return slot or subType or itemType or ""
end

-- Tooltip and Shift-click (link to chat) for a quest item slot.
local function ItemScripts(frame)
  frame:SetScript("OnEnter", function(self)
    local item = self.item
    if not item then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if item.kind == "currency" then
      if GameTooltip.SetQuestCurrency then
        pcall(GameTooltip.SetQuestCurrency, GameTooltip, "required", item.index)
      end
    elseif GameTooltip.SetQuestItem then
      pcall(GameTooltip.SetQuestItem, GameTooltip, item.kind, item.index)
    end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function ModifiedClick(item)
  if item and item.link and IsModifiedClick and IsModifiedClick() and type(_G.HandleModifiedItemClick) == "function" then
    pcall(HandleModifiedItemClick, item.link)
    return true
  end
  return false
end

-- Stat Delta's changes for a reward item: up to three { text, good }, only while that module runs.
function D.StatLines(link)
  if not (link and D.DB().statArrows and ns.ModuleOn and ns.ModuleOn("statdelta")) then
    return nil
  end
  local S = ns.statdelta
  if not (S and S.BuildComparisons and S.db) then
    return nil
  end
  local ok, comparisons = pcall(S.BuildComparisons, link)
  local first = ok and type(comparisons) == "table" and comparisons[1]
  if not first then
    return nil
  end
  local out = {}
  for _, line in ipairs(first.itemLines or {}) do
    if #out >= 3 then
      break
    end
    local label, text, value = line[1], line[2], line[3]
    if type(label) == "string" and type(text) == "string" and type(value) == "number" then
      out[#out + 1] = { text = text .. " " .. label, good = value > 0 }
    end
  end
  return #out > 0 and out or nil
end

local function Arrow(frame, link)
  local S = ns.statdelta
  if S and S.SetArrow and ns.ModuleOn and ns.ModuleOn("statdelta") and D.DB().statArrows then
    pcall(S.SetArrow, frame, link)
  elseif S and S.SetArrow then
    pcall(S.SetArrow, frame, nil)
  end
end

-- Reward slots in two columns (the offer: "not clickable, they only show what you can choose later").
local function NewGrid(content)
  local block = CreateFrame("Frame", nil, content.parent)
  block.slots = {}
  function block:Measure(width)
    local columns = 2
    local w = math.floor((width - 6) / columns)
    local shown = 0
    for index, slot in ipairs(self.slots) do
      if slot:IsShown() then
        shown = shown + 1
        local column, line = (shown - 1) % columns, math.floor((shown - 1) / columns)
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", self, "TOPLEFT", column * (w + 6), -line * 46)
        slot:SetSize(w, 40)
        slot.name:SetWidth(w - 48)
        slot.type:SetWidth(w - 48)
      end
    end
    return math.max(1, math.ceil(shown / columns)) * 46 - 6
  end
  return block
end

function D.ItemGrid(content, items)
  if #items == 0 then
    return nil
  end
  local block = content:Get("grid", NewGrid, 8)
  local palette = content.palette
  for index, item in ipairs(items) do
    local slot = block.slots[index]
    if not slot then
      slot = CreateFrame("Button", nil, block)
      slot.lines = T.Outline(slot, 0, { 1, 1, 1 }, 1, "BORDER")
      slot.icon = D.ItemIcon(slot, 34)
      slot.icon:SetPoint("LEFT", 3, 0)
      slot.name = D.Text(slot, "body", 13)
      slot.name:SetPoint("TOPLEFT", slot.icon, "TOPRIGHT", 8, -2)
      slot.name:SetWordWrap(false)
      slot.type = D.Text(slot, "body", 11)
      slot.type:SetPoint("TOPLEFT", slot.name, "BOTTOMLEFT", 0, -2)
      slot.type:SetWordWrap(false)
      ItemScripts(slot)
      slot:SetScript("OnClick", function(self)
        ModifiedClick(self.item)
      end)
      block.slots[index] = slot
    end
    slot.item = item
    T.ColorLines(slot.lines, palette.rule, palette.rule[4])
    slot.icon:Set(item.texture, item.quality, item.count)
    UI.Font(slot.name, "body", D.FontSize(-1), D.QualityColor(palette, item.quality))
    D.SetText(slot.name, item.name)
    UI.Font(slot.type, "body", D.FontSize(-3), palette.muted)
    slot.type:SetText(D.ItemTypeText(item.link))
    slot:Show()
  end
  for index = #items + 1, #block.slots do
    block.slots[index]:Hide()
  end
  return block
end

-- Reward choice rows (radio): icon, name, type, stat changes, the dot on the right.
local function NewChoice(content)
  local row = CreateFrame("Button", nil, content.parent)
  row.back = row:CreateTexture(nil, "BACKGROUND")
  row.back:SetAllPoints()
  row.lines = T.Outline(row, 0, { 1, 1, 1 }, 1, "BORDER")
  row.icon = D.ItemIcon(row, 40)
  row.icon:SetPoint("LEFT", 7, 0)
  row.name = D.Text(row, "body", 14)
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
  row.name:SetWordWrap(false)
  row.type = D.Text(row, "body", 11)
  row.type:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
  row.type:SetWordWrap(false)
  row.deltas = {}
  for index = 1, 3 do
    local delta = {}
    delta.arrow = row:CreateTexture(nil, "ARTWORK")
    delta.arrow:SetTexture(ARROW)
    delta.arrow:SetSize(9, 9)
    delta.text = D.Text(row, "body", 11)
    delta.text:SetWordWrap(false)
    row.deltas[index] = delta
  end
  row.dot = row:CreateTexture(nil, "ARTWORK")
  row.dot:SetTexture(CIRCLE)
  row.dot:SetSize(18, 18)
  row.dot:SetPoint("RIGHT", -10, 0)
  row.dotRing = row:CreateTexture(nil, "BORDER", nil, 2)
  row.dotRing:SetTexture(CIRCLE)
  row.dotRing:SetSize(18, 18)
  row.dotRing:SetPoint("RIGHT", -10, 0)
  row.dotHole = row:CreateTexture(nil, "BORDER", nil, 3)
  row.dotHole:SetTexture(CIRCLE)
  row.dotHole:SetSize(16, 16)
  row.dotHole:SetPoint("CENTER", row.dotRing, "CENTER")
  row.tick = row:CreateTexture(nil, "OVERLAY")
  row.tick:SetTexture(CHECK)
  row.tick:SetSize(18, 18)
  row.tick:SetPoint("CENTER", row.dot, "CENTER", 1, 0)
  row.tick:SetVertexColor(0.08, 0.07, 0.04, 1)
  ItemScripts(row)
  row:SetScript("OnClick", function(self)
    if ModifiedClick(self.item) then
      return
    end
    D.PickReward(self.item.index)
  end)
  function row:Paint(selected)
    local palette = self.palette
    if selected then
      Color(self.back, palette.select)
      T.ColorLines(self.lines, palette.selLine, 1)
    else
      self.back:SetColorTexture(0, 0, 0, 0)
      T.ColorLines(self.lines, palette.rule, palette.rule[4])
    end
    self.dot:SetShown(selected)
    self.tick:SetShown(selected)
    self.dotRing:SetShown(not selected)
    self.dotHole:SetShown(not selected)
    self.selected = selected
  end
  -- name and type on one line: the name gets what the type and the dot leave
  function row:Measure(width)
    local function Width(text)
      local w = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth()
      return type(w) == "number" and w > 0 and math.ceil(w) or 0
    end
    local room = width - 57 - 34
    local typeWidth = Width(self.type)
    local nameWidth = Width(self.name)
    self.name:SetWidth(math.max(60, math.min(nameWidth > 0 and nameWidth or room, room - typeWidth - 8)))
    return 54
  end
  return row
end

function D.ChoiceRows(content, page)
  local palette = content.palette
  D.choiceRows = {}
  for _, item in ipairs(page.choices) do
    local row = content:Get("choice", NewChoice, 6)
    row.item, row.palette = item, palette
    row.icon:Set(item.texture, item.quality, item.count)
    UI.Font(row.name, "body", D.FontSize(0), D.QualityColor(palette, item.quality))
    D.SetText(row.name, item.name)
    UI.Font(row.type, "body", D.FontSize(-3), palette.muted)
    row.type:SetText(D.ItemTypeText(item.link))
    Color(row.dot, palette.head)
    Color(row.dotRing, palette.muted)
    local hole = palette.ink and D.Tokens().page.to or ns.Theme().panel.to
    row.dotHole:SetVertexColor(hole[1], hole[2], hole[3], 1)
    local lines = D.StatLines(item.link) or {}
    local previous
    for index, delta in ipairs(row.deltas) do
      local line = lines[index]
      delta.arrow:ClearAllPoints()
      delta.text:ClearAllPoints()
      if line then
        local color = line.good and palette.good or palette.bad
        delta.arrow:SetVertexColor(color[1], color[2], color[3], 1)
        delta.arrow:SetTexCoord(0, 1, line.good and 1 or 0, line.good and 0 or 1)
        if previous then
          delta.arrow:SetPoint("LEFT", previous, "RIGHT", 10, 0)
        else
          delta.arrow:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
        end
        delta.text:SetPoint("LEFT", delta.arrow, "RIGHT", 2, 0)
        UI.Font(delta.text, "body", D.FontSize(-3), color)
        delta.text:SetText(line.text)
        delta.arrow:Show()
        delta.text:Show()
        previous = delta.text
      else
        delta.arrow:Hide()
        delta.text:Hide()
      end
    end
    Arrow(row.icon, item.link)
    row:Paint(page.choice == item.index)
    D.choiceRows[#D.choiceRows + 1] = row
  end
end

-- Items to bring (progress): icon with the count needed, name, "have/need" and a thin bar.
local function NewNeed(content)
  local row = CreateFrame("Button", nil, content.parent)
  row.icon = D.ItemIcon(row, 36)
  row.icon:SetPoint("LEFT", 0, 0)
  row.name = D.Text(row, "body", 14)
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -6)
  row.name:SetWordWrap(false)
  row.count = D.Text(row, "body", 13)
  row.count:SetJustifyH("RIGHT")
  row.count:SetPoint("TOPRIGHT", 0, -6)
  row.check = row:CreateTexture(nil, "ARTWORK")
  row.check:SetTexture(CHECK)
  row.check:SetSize(16, 16)
  row.check:SetPoint("RIGHT", row.count, "LEFT", -2, 0)
  row.barBack = row:CreateTexture(nil, "BORDER")
  row.barBack:SetHeight(3)
  row.barBack:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 6)
  row.barBack:SetPoint("RIGHT", 0, 0)
  row.barFill = row:CreateTexture(nil, "ARTWORK")
  row.barFill:SetHeight(3)
  row.barFill:SetPoint("LEFT", row.barBack, "LEFT")
  ItemScripts(row)
  row:SetScript("OnClick", function(self)
    ModifiedClick(self.item)
  end)
  function row:Measure(width)
    self.name:SetWidth(math.max(40, width - 36 - 10 - 70))
    local have, need = self.item.have, self.item.need or 1
    local fraction = have and need > 0 and math.min(1, have / need) or 0
    self.barFill:SetWidth(math.max(0.01, (width - 46) * fraction))
    self.barFill:SetShown(fraction > 0)
    return 40
  end
  return row
end

function D.NeedRows(content, page)
  local palette = content.palette
  for _, item in ipairs(page.need) do
    local row = content:Get("need", NewNeed, 6)
    row.item = item
    local have, need = item.have, item.need or 1
    local done = have and have >= need
    row.icon:Set(item.texture, item.quality, item.need, done and palette.good or nil)
    row.icon:SetAlpha((have or 0) > 0 and 1 or 0.55)
    UI.Font(row.name, "body", D.FontSize(0), done and palette.muted or palette.text)
    D.SetText(row.name, item.name)
    UI.Font(row.count, "body", D.FontSize(-1), done and palette.good or ((have or 0) > 0 and palette.bright or palette.muted))
    if have then
      row.count:SetText(("%d/%d"):format(math.min(have, need), need))
    else
      row.count:SetText("")
    end
    row.check:SetShown(done and true or false)
    row.check:SetVertexColor(palette.good[1], palette.good[2], palette.good[3], 1)
    Color(row.barBack, palette.bar.back)
    Color(row.barFill, done and palette.good or palette.bar.fill)
    row.barBack:SetShown(item.kind ~= "currency")
  end
end

-- Money, experience, reputation, skill, spells and currencies as chips.
function D.RewardChips(page, palette, withCost)
  local chips = {}
  local muted = "|cff" .. Hex(palette.muted)
  if (page.money or 0) > 0 then
    local text = type(_G.GetCoinTextureString) == "function" and D.Str(D.Call(_G.GetCoinTextureString, page.money))
    chips[#chips + 1] = { text = text or ns.Money(page.money), raw = ns.Money(page.money):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") }
  end
  if (page.xp or 0) > 0 then
    local number = Number(page.xp)
    chips[#chips + 1] = { text = number .. " " .. muted .. L["experience"] .. "|r", raw = number .. " " .. L["experience"] }
  end
  for _, rep in ipairs(page.rep or {}) do
    local amount = D.RepAmountText(rep.amount)
    local color = rep.amount < 0 and "|cff" .. Hex(palette.bad) or ""
    chips[#chips + 1] = { text = color .. amount .. (color ~= "" and "|r" or "") .. " " .. muted .. rep.name .. "|r",
      raw = amount .. " " .. rep.name, rep = rep }
  end
  if page.skill then
    chips[#chips + 1] = { text = "+" .. page.skill.points .. " " .. muted .. page.skill.name .. "|r",
      raw = "+" .. page.skill.points .. " " .. page.skill.name }
  end
  for _, spell in ipairs(page.spells or {}) do
    chips[#chips + 1] = { text = muted .. L["Learn"] .. "|r " .. spell.name, raw = L["Learn"] .. " " .. spell.name }
  end
  for _, currency in ipairs(page.currencies or {}) do
    chips[#chips + 1] = { text = Number(currency.amount) .. " " .. muted .. currency.name .. "|r",
      raw = currency.amount .. " " .. currency.name }
  end
  if withCost and (page.cost or 0) > 0 then
    chips[#chips + 1] = { text = muted .. L["Costs"] .. "|r " .. ns.Money(page.cost), raw = L["Costs"] .. " " .. ns.Money(page.cost):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") }
  end
  return chips
end

local function TitleBlock(content, page)
  local text = page.title or ""
  if page.repeatable and D.Str(text) then
    text = text .. "  |cff" .. Hex(content.palette.muted) .. L["Repeatable"] .. "|r"
  end
  content:Text(text, { size = D.FontSize(5), color = "bright", gap = page.kind == "detail" and 2 or 8 })
end

local function LevelLine(content, page)
  local parts = {}
  if page.level then
    parts[#parts + 1] = L["Level %d"]:format(page.level)
  end
  if (page.group or 0) > 1 then
    parts[#parts + 1] = L["Suggested players: %d"]:format(page.group)
  end
  if #parts > 0 then
    content:Text(table.concat(parts, " · "), { size = D.FontSize(-1), color = "muted", gap = 8 })
  end
end

-- Remembers the blocks that wait for the written-in text (the game hides them until it's done).
local function After(block)
  if block then
    D.afterText[#D.afterText + 1] = block
  end
  return block
end

function D.FillQuest(content, page, withText)
  local palette = content.palette
  TitleBlock(content, page)
  if page.kind == "detail" then
    LevelLine(content, page)
  end
  if withText and D.HasText(page.text) then
    D.mainTextBlock = content:Text(page.text, { size = D.FontSize(0), gap = 10 })
  end
  if page.kind == "detail" then
    if D.HasText(page.objectives) then
      After(content:Section(L["Objectives"]))
      After(content:Text(page.objectives, { size = D.FontSize(0), gap = 10 }))
    end
    local chips = D.RewardChips(page, palette, true)
    if #page.choices > 0 or #page.rewards > 0 or #chips > 0 then
      After(content:Section(L["Rewards"]))
      if #page.choices > 1 then
        After(content:Text(L["Choose one when you hand it in:"], { size = D.FontSize(-2), color = "muted", gap = 5 }))
      end
      After(D.ItemGrid(content, page.choices))
      if #page.rewards > 0 and #page.choices > 0 then
        After(content:Text(L["You will also receive:"], { size = D.FontSize(-2), color = "muted", gap = 5 }))
      end
      After(D.ItemGrid(content, page.rewards))
      After(content:Chips(chips))
    end
  elseif page.kind == "progress" then
    if #page.need > 0 then
      content:Section(L["Bring"])
      D.NeedRows(content, page)
    end
    if (page.cost or 0) > 0 then
      content:Chips({ { text = L["Costs"] .. " " .. ns.Money(page.cost), raw = L["Costs"] } })
    end
    if not page.completable then
      content:Text(L["Continue opens once you have everything."], { size = D.FontSize(-2), color = "muted" })
    end
  elseif page.kind == "reward" then
    if #page.choices > 1 then
      content:Section(L["Choose your reward"])
      D.ChoiceRows(content, page)
    else
      D.choiceRows = {}
    end
    local fixed = {}
    if #page.choices == 1 then
      fixed[1] = page.choices[1]
    end
    for _, item in ipairs(page.rewards) do
      fixed[#fixed + 1] = item
    end
    local chips = D.RewardChips(page, palette, true)
    if #fixed > 0 or #chips > 0 then
      content:Section(#page.choices > 1 and L["You will also receive"] or L["Rewards"])
      D.ItemGrid(content, fixed)
      content:Chips(chips)
    end
  end
end

-- Actions ----------------------------------------------------------------------------------------------------

local function Page(kind)
  local page = D.page
  return page and page.kind == kind and page or nil
end

-- Accept (QuestDetailAcceptButton_OnClick): a PvP quest asks first; a quest the game already took asks only for
-- the acknowledgement.
function D.Accept()
  local page = Page("detail")
  if not page then
    return false
  end
  if page.pvp and type(_G.StaticPopup_Show) == "function" then
    pcall(StaticPopup_Show, "CONFIRM_ACCEPT_PVP_QUEST")
  elseif page.autoAccept and type(_G.AcknowledgeAutoAcceptQuest) == "function" then
    pcall(AcknowledgeAutoAcceptQuest)
  elseif type(_G.AcceptQuest) == "function" then
    pcall(AcceptQuest)
  end
  return true
end

-- Decline: back to the NPC's list when the quest came from it (the game shows the list again), else close.
function D.Decline()
  local page = D.page
  if page and page.fromList and type(_G.DeclineQuest) == "function" then
    pcall(DeclineQuest)
  else
    D.Close()
  end
end

-- Escape on a quest page reached from the NPC's list (option escapeBack): back to the list.
function D.Back()
  local page = D.page
  if not (page and D.QUEST_PAGES[page.kind] and page.fromList and type(_G.DeclineQuest) == "function") then
    return false
  end
  pcall(DeclineQuest)
  return true
end

function D.Continue()
  local page = Page("progress")
  if not (page and page.completable) then
    return false
  end
  if type(_G.CompleteQuest) == "function" then
    pcall(CompleteQuest)
  end
  return true
end

-- Complete Quest (QuestRewardCompleteButton_OnClick): one choice is picked by itself; several need a pick; a quest
-- that costs money asks with the game's own popup (its OnAccept reads QuestInfoFrame.itemChoice).
function D.Complete()
  local page = Page("reward")
  if not page or D.NeedsChoice(page) then
    return false
  end
  local choice = #page.choices == 1 and 1 or (page.choice or 0)
  local money = D.Num(D.Call(_G.GetQuestMoneyToGet)) or 0
  if money > 0 and type(_G.StaticPopup_Show) == "function" then
    if type(_G.QuestInfoFrame) == "table" then
      QuestInfoFrame.itemChoice = choice
    end
    local ok, dialog = pcall(StaticPopup_Show, "CONFIRM_COMPLETE_EXPENSIVE_QUEST")
    if ok and type(dialog) == "table" and dialog.MoneyFrame and type(_G.MoneyFrame_Update) == "function" then
      pcall(MoneyFrame_Update, dialog.MoneyFrame, money)
    end
  elseif type(_G.GetQuestReward) == "function" then
    pcall(GetQuestReward, choice)
  end
  return true
end

-- Picks reward `index` (a click, or Tab).
function D.PickReward(index)
  local page = Page("reward")
  if not (page and page.choices[index]) then
    return
  end
  page.choice = index
  for _, row in ipairs(D.choiceRows or {}) do
    row:Paint(row.item.index == index)
  end
  local frame = D.frames[D.style or ""]
  if frame then
    frame.specs = D.ButtonSpecs(page)
    D.Relayout()
  end
  if D.Keys then
    D.Keys.Update()
  end
end

-- Tab: the next reward to choose (Shift+Tab the one before).
function D.NextReward(back)
  local page = Page("reward")
  if not (page and #page.choices > 1) then
    return false
  end
  local count = #page.choices
  local current = page.choice or 0
  local nextIndex
  if back then
    nextIndex = current <= 1 and count or current - 1
  else
    nextIndex = current >= count and 1 or current + 1
  end
  D.PickReward(nextIndex)
  return true
end
