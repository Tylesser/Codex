local addonName, ns = ...

-- Quest tracker, part 2: the window. `CodexQuestTracker` (LOW strata, as Blizzard's), a header ("Quests" + the
-- count, a fold arrow that collapses the whole list) and rows: zone headings (fold arrow, name, count; a click folds
-- the zone), quest titles, objective lines. Rows are Buttons of ours: clicks as Blizzard's tracker (forever branch
-- QuestObjectiveTrackerMixin:OnBlockHeaderClick): left = open the quest in the quest log / map, Shift (the
-- QUESTWATCHTOGGLE modified click) = stop tracking, with chat open = link it; right = a menu (focus / stop
-- focusing, open in the quest log, show on the map, stop tracking, share). The focused (super-tracked) quest has an
-- accent mark.
--
-- Quest items: SecureActionButtonTemplate buttons of ours (type "item", item "item:<id>"; Blizzard's own call
-- UseQuestLogSpecialItem, which is protected), parented to UIParent and anchored to their quest's row. They are
-- made, moved, shown and hidden only out of combat: in a fight the window only refills rows whose shape didn't
-- change, and the full layout waits for PLAYER_REGEN_ENABLED.
--
-- Blizzard's tracker is parked, never hidden or re-parented (FlareUI's note, forever: a hide or re-parent runs its
-- OnHide tainted, and its next update fails on secret auras): scale 0.001 with the widget's own SetScale (Edit
-- Mode overrides SetScale: SetScaleBase when there is one) and alpha 0, out of combat; post hooks on its SetScale /
-- SetAlpha park it again. It keeps running (new quests are still watched). While it has something besides quests
-- to show (a scenario, a tracked recipe or achievement, bonus objectives: a module's plain `hasContents`), it comes
-- back and this window steps aside (option `yield`), so nothing is lost.

local UI = ns.UI
local QT = ns.questtracker
local QO = ns.QuestOrder

local PAD = 10
local HEADER = 24
local ROW_GAP = { zone = 6, quest = 4, objective = 1, done = 1, failed = 1 }
local ITEM = 22
local MORE = 16 -- the "more above / below" lines
local PARKED = 0.001
local MOVER_TEXT = "Quest tracker"

-- The game's tracker modules that aren't quests (forever branch ObjectiveTrackerManager:Init)
QT.OTHER_MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "AdventureObjectiveTracker",
  "AchievementObjectiveTracker", "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker",
  "ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

local frame, header, mover
local rows, items = {}, {}
local shown = {} -- the rows drawn now (data)
local lastShape
QT.rowFrames, QT.itemButtons = rows, items

local function InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

local function Theme()
  return ns.InkTheme and ns.InkTheme() or ns.Theme()
end

local function Color(token)
  local theme = Theme()
  if token == "orange" then
    local bad, warn = theme.bad, theme.warn
    return { (bad[1] + warn[1]) / 2, (bad[2] + warn[2]) / 2, (bad[3] + warn[3]) / 2 }
  end
  return theme[token] or theme.text
end

-- Blizzard's tracker ------------------------------------------------------------------------------------------------

local parking = false
local hookedTracker = false

local function Tracker()
  local tracker = _G.ObjectiveTrackerFrame
  return type(tracker) == "table" and tracker or nil
end

-- Another addon already parked it (FlareUI's tracker): Codex stands aside.
function QT.ParkedByOther()
  local tracker = Tracker()
  if not tracker or QT.parked then
    return false
  end
  local scale = QO.Num(QO.Ask(tracker.GetScale, tracker))
  return scale ~= nil and scale < 0.01
end

-- Whether the game's tracker has something besides quests to show.
function QT.OtherObjectives()
  for _, name in ipairs(QT.OTHER_MODULES) do
    local module = _G[name]
    if type(module) == "table" then
      local has = rawget(module, "hasContents")
      if QO.Readable(has) and has == true then
        return true
      end
    end
  end
  return false
end

local function SetTrackerScale(scale)
  local tracker = Tracker()
  if not tracker then
    return
  end
  local set = tracker.SetScaleBase or tracker.SetScale
  parking = true
  pcall(set, tracker, scale)
  parking = false
end

function QT.Park()
  local tracker = Tracker()
  if not tracker or InCombat() then
    return false
  end
  if not QT.parked then
    local scale = QO.Num(QO.Ask(tracker.GetScale, tracker))
    QT.trackerScale = (scale and scale > 0.01) and scale or 1
  end
  QT.parked = true
  if (QO.Num(QO.Ask(tracker.GetScale, tracker)) or 1) > PARKED * 2 then
    SetTrackerScale(PARKED)
  end
  parking = true
  pcall(tracker.SetAlpha, tracker, 0)
  parking = false
  if not hookedTracker then
    hookedTracker = true
    local function Again()
      if parking or not QT.parked then
        return
      end
      C_Timer.After(0, function()
        if QT.parked and not InCombat() then
          QT.Park()
        end
      end)
    end
    hooksecurefunc(tracker, "SetScale", Again)
    hooksecurefunc(tracker, "SetAlpha", Again)
  end
  return true
end

function QT.Unpark()
  local tracker = Tracker()
  if not tracker or not QT.parked or InCombat() then
    return false
  end
  QT.parked = false
  SetTrackerScale(QT.trackerScale or 1)
  pcall(tracker.SetAlpha, tracker, 1)
  return true
end

-- Where Blizzard's tracker stands (its top right in UIParent's units), for the first place of ours.
function QT.TrackerSpot()
  local tracker = Tracker()
  if not tracker or QT.parked then
    return nil
  end
  local right, top = QO.Num(QO.Ask(tracker.GetRight, tracker)), QO.Num(QO.Ask(tracker.GetTop, tracker))
  local parentRight, parentTop = QO.Num(UIParent:GetRight()), QO.Num(UIParent:GetTop())
  local k = (QO.Num(QO.Ask(tracker.GetEffectiveScale, tracker)) or 1) / (QO.Num(UIParent:GetEffectiveScale()) or 1)
  if not (right and top and parentRight and parentTop) then
    return nil
  end
  return { point = "TOPRIGHT", x = right * k - parentRight, y = top * k - parentTop }
end

-- Rows ----------------------------------------------------------------------------------------------------------

local function Tooltip(row)
  local data = row.data
  if not data or data.kind == "zone" then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_LEFT")
  local link = QO.Ask(GetQuestLink, data.id)
  if not (QO.Str(link) and pcall(GameTooltip.SetHyperlink, GameTooltip, link)) then
    GameTooltip:SetText(QO.Str(QO.Ask(QO.API("GetTitleForQuestID"), data.id)) or "")
  end
  GameTooltip:AddLine("Click: open in the quest log. Shift-click: stop tracking. Right-click: more.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end

local function RowClick(row, button)
  local data = row.data
  if not data then
    return
  end
  if data.kind == "zone" then
    QT.ToggleFold(data.fold)
    return
  end
  QT.QuestClick(data.id, button, row)
end

local function MakeRow(index)
  local row = CreateFrame("Button", nil, frame)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.text = UI.Text(row, "body", 12, "text")
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(true)
  row.count = UI.Text(row, "body", 11, "muted")
  row.count:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  row.arrow = UI.FoldArrow(row)
  row.arrow:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
  row.mark = row:CreateTexture(nil, "ARTWORK")
  row.mark:SetSize(2, 12)
  row.mark:SetPoint("TOPRIGHT", row, "TOPLEFT", -3, -1)
  local hover = row:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, Theme().accent, 0.08)
  row:SetScript("OnClick", RowClick)
  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel", function(_, delta) QT.Scroll(delta) end)
  row:SetScript("OnEnter", Tooltip)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[index] = row
  return row
end

local function MakeItem(index)
  local button = CreateFrame("Button", "CodexQuestTrackerItem" .. index, UIParent, "SecureActionButtonTemplate")
  button:SetSize(ITEM, ITEM)
  button:SetFrameStrata("LOW")
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("useOnKeyDown", false)
  button:SetAttribute("type", "item")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetPoint("TOPLEFT", -1, 1)
  button.border:SetPoint("BOTTOMRIGHT", 1, -1)
  UI.SetColor(button.border, Theme().accent, 0)
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints()
  button.count = UI.Text(button, "body", 10, "bright")
  button.count:SetPoint("BOTTOMRIGHT", -1, 1)
  button:SetScript("OnEnter", function(self)
    if self.logIndex then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      if not pcall(GameTooltip.SetQuestLogSpecialItem, GameTooltip, self.logIndex) and self.link then
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
      end
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:Hide()
  items[index] = button
  return button
end

local function FillItem(button, row, data)
  local item = data.item
  button.logIndex, button.link = data.logIndex, item.link
  button:SetAttribute("item", "item:" .. item.itemID)
  if item.texture then
    button.icon:SetTexture(item.texture)
  end
  button.count:SetText(item.charges and item.charges > 1 and item.charges or "")
  button:ClearAllPoints()
  button:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 2)
  -- above the tracker's rows: a row (a Button over the whole width) under it took the click (the user's
  -- "can't click the quest item", 2026-11-21). Laid out out of combat only, so the level may change here.
  button:SetFrameLevel((QT.frame and QT.frame:GetFrameLevel() or 1) + 20)
  button:Show()
  QT.ItemCooldown(button)
end

function QT.ItemCooldown(button)
  if not (button and button.logIndex and button:IsShown()) then
    return
  end
  local start, duration, enable = QO.Ask(GetQuestLogSpecialItemCooldown, button.logIndex)
  start, duration = QO.Num(start), QO.Num(duration)
  if start and duration and duration > 0 and enable ~= 0 then
    pcall(button.cooldown.SetCooldown, button.cooldown, start, duration)
  else
    pcall(button.cooldown.Clear, button.cooldown)
  end
end

local function FillRow(row, data)
  row.data = data
  local theme = Theme()
  local kind = data.kind
  row.text:ClearAllPoints()
  row.arrow:SetShown(kind == "zone")
  row.count:SetShown(kind == "zone")
  row.mark:SetShown(kind == "quest" and data.focused == true)
  UI.SetColor(row.mark, theme.accent)
  if kind ~= "quest" then
    row:SetHitRectInsets(0, 0, 0, 0)
  end
  if kind == "zone" then
    row.arrow:SetOpen(not data.folded)
    row.arrow:SetColor(theme.accent)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 14, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    UI.Font(row.text, "body", 12.5, "accent")
    row.count:SetText(data.count)
  elseif kind == "quest" then
    -- a quest with an item: the row's own clicks stop short of the item button
    row:SetHitRectInsets(0, data.item and (ITEM + 4) or 0, 0, 0)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 4, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", data.item and -(ITEM + 4) or 0, 0)
    UI.Font(row.text, "body", 12, "text")
  else
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 14, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    UI.Font(row.text, "body", 11.5, "text")
  end
  local text = data.text or ""
  if kind == "objective" then
    text = "- " .. text
  end
  row.text:SetText(text)
  row.text:SetTextColor(UI.Unpack(Color(data.token or "text")))
end

local function RowHeight(row)
  local height = QO.Num(row.text:GetStringHeight()) or 0
  if height <= 0 then
    height = 14 -- not measured yet (first draw): laid out again next frame
  end
  if row.data and row.data.kind == "quest" and row.data.item then
    height = math.max(height, ITEM - 4)
  end
  return math.ceil(height)
end

-- Window ----------------------------------------------------------------------------------------------------------

local function Place()
  local db = QT.DB()
  local spot = db.point or QT.TrackerSpot() or { point = "TOPRIGHT", x = -80, y = -260 }
  if not db.point then
    db.point = spot
  end
  frame:ClearAllPoints()
  frame:SetPoint(spot.point or "TOPRIGHT", UIParent, spot.point or "TOPRIGHT", spot.x or 0, spot.y or 0)
end

local function SavePosition()
  local right, top = QO.Num(frame:GetRight()), QO.Num(frame:GetTop())
  local parentRight, parentTop = QO.Num(UIParent:GetRight()), QO.Num(UIParent:GetTop())
  if right and top and parentRight and parentTop then
    QT.DB().point = { point = "TOPRIGHT", x = right - parentRight, y = top - parentTop }
  end
  Place()
end

function QT.ResetPosition()
  QT.DB().point = nil
  if frame and not InCombat() then
    Place()
  end
end

local function BuildMover()
  mover = CreateFrame("Button", nil, frame)
  mover:SetAllPoints()
  mover:SetFrameLevel(frame:GetFrameLevel() + 40)
  mover:RegisterForDrag("LeftButton")
  mover:RegisterForClicks("RightButtonUp")
  local fill = mover:CreateTexture(nil, "OVERLAY")
  fill:SetAllPoints()
  UI.SetColor(fill, Theme().accent, 0.18)
  local label = UI.Text(mover, "body", 12, "bright")
  label:SetPoint("CENTER")
  label:SetText(MOVER_TEXT)
  mover:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  mover:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition()
  end)
  mover:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      frame:StopMovingOrSizing()
      QT.ResetPosition()
    end
  end)
  mover:Hide()
end

local function ShowMover()
  if InCombat() then
    return
  end
  if not mover then
    BuildMover()
  end
  QT.editing = true
  frame:SetMovable(true)
  QT.Layout(true)
  mover:Show()
end

local function HideMover()
  QT.editing = false
  if mover then
    mover:Hide()
  end
  if frame then
    frame:StopMovingOrSizing()
  end
  QT.Refresh()
end

local editHooked = false
local function HookEditMode()
  local manager = _G.EditModeManagerFrame
  if editHooked or type(manager) ~= "table" or not manager.HookScript then
    return
  end
  editHooked = true
  manager:HookScript("OnShow", ShowMover)
  manager:HookScript("OnHide", HideMover)
end

local function MoreLine(parent, text, open)
  local line = CreateFrame("Frame", nil, parent)
  line:SetHeight(MORE)
  line.arrow = UI.FoldArrow(line)
  line.arrow:SetPoint("LEFT", 0, 0)
  line.arrow:SetOpen(open)
  line.text = UI.Text(line, "body", 11, "muted")
  line.text:SetPoint("LEFT", 14, 0)
  line.text:SetText(text)
  line:Hide()
  return line
end

function QT.Build()
  if frame then
    return frame
  end
  frame = UI.Ink(CreateFrame("Frame", "CodexQuestTracker", UIParent))
  frame:SetFrameStrata("LOW")
  frame:SetClampedToScreen(true)
  frame:SetSize(QT.DB().width, HEADER + PAD)
  frame.back = CreateFrame("Frame", nil, frame)
  frame.back:SetAllPoints()
  frame.back:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  UI.Ink(frame.back)
  UI.Panel(frame.back, { strip = false, shadow = false, cornerSize = 10 })
  header = CreateFrame("Button", nil, frame)
  header:SetPoint("TOPLEFT", PAD, -4)
  header:SetPoint("TOPRIGHT", -PAD, -4)
  header:SetHeight(HEADER - 4)
  header:RegisterForClicks("LeftButtonUp")
  header.arrow = UI.FoldArrow(header)
  header.arrow:SetPoint("LEFT", 0, 0)
  header.title = UI.Text(header, "body", 13, "accent")
  header.title:SetPoint("LEFT", 14, 0)
  header.title:SetText(_G.TRACKER_HEADER_QUESTS or "Quests")
  header.count = UI.Text(header, "body", 11, "muted")
  header.count:SetPoint("RIGHT", 0, 0)
  header:SetScript("OnClick", function()
    QT.ToggleCollapsed()
  end)
  header:EnableMouseWheel(true)
  header:SetScript("OnMouseWheel", function(_, delta) QT.Scroll(delta) end)
  frame:EnableMouseWheel(true)
  frame:SetScript("OnMouseWheel", function(_, delta) QT.Scroll(delta) end)
  frame.above = MoreLine(frame, "More above", false)
  frame.below = MoreLine(frame, "More below", true)
  frame.header = header
  QT.frame = frame
  Place()
  HookEditMode()
  return frame
end

-- How tall the window may get: the player's choice, else the game's tracker's own height (Blizzard keeps it at its
-- Edit Mode "Height" when moved, down to the screen's bottom in its default place: forever branch
-- ObjectiveTrackerContainerMixin:UpdateHeight), in UIParent's units (its height times its own scale), and never past
-- the screen's bottom edge.
function QT.MaxHeight()
  local db = QT.DB()
  local height = db.height
  if not height then
    local tracker = Tracker()
    local own = tracker and QO.Num(QO.Ask(tracker.GetHeight, tracker))
    height = (own and own > 50) and own * (QT.trackerScale or 1) or 600
  end
  local top = frame and QO.Num(frame:GetTop())
  local bottom = QO.Num(UIParent:GetBottom()) or 0
  if top and top - bottom > 100 then
    height = math.min(height, top - bottom - 8)
  end
  return math.max(HEADER + 60, math.floor(height))
end

-- Scrolling: the first row shown (out of combat only; the wheel over the window, 2 rows a step).
function QT.Scroll(delta)
  if InCombat() or not frame then
    return
  end
  QT.scrollRow = math.max(1, (QT.scrollRow or 1) - (delta or 0) * 2)
  QT.Layout(true)
end

local function Wheel(_, delta)
  QT.Scroll(delta)
end
QT.Wheel = Wheel

-- Lays the rows out from `shown`: every row measured, then placed from the scroll position until the height runs
-- out; rows above and below are hidden (and their item buttons), with a "more" line where rows are cut off.
function QT.Layout(force)
  if not frame then
    return
  end
  local db = QT.DB()
  local width = db.width
  local inner = width - PAD * 2
  local theme = Theme()
  frame.back:SetShown(db.background ~= false)
  header.arrow:SetColor(theme.accent)
  header.arrow:SetOpen(not db.collapsed)
  header.count:SetText(QT.countText or "")
  frame.above.arrow:SetColor(theme.muted)
  frame.below.arrow:SetColor(theme.muted)
  local heights, gaps = {}, {}
  for index, data in ipairs(shown) do
    local row = rows[index] or MakeRow(index)
    FillRow(row, data)
    row:SetWidth(inner)
    heights[index] = RowHeight(row)
    gaps[index] = ROW_GAP[data.kind] or 2
  end
  local room = QT.MaxHeight() - HEADER - PAD
  local count = #shown
  -- the last row that fits from `first`, with room kept for the "more" lines
  local function Last(first)
    local used = first > 1 and MORE or 0
    local last = first - 1
    for index = first, count do
      local need = heights[index] + (index == first and 2 or gaps[index])
      local below = index < count and MORE or 0
      if used + need + below > room and index > first then
        break
      end
      used = used + need
      last = index
    end
    return last, used
  end
  local first = math.min(math.max(1, QT.scrollRow or 1), math.max(1, count))
  -- scrolled too far: come back up while the earlier rows still fit
  while first > 1 do
    local last = Last(first - 1)
    if last < count then
      break
    end
    first = first - 1
  end
  local last = Last(first)
  QT.scrollRow = first
  QT.firstRow, QT.lastRow = first, last
  local y = -HEADER
  if first > 1 then
    frame.above:ClearAllPoints()
    frame.above:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
    frame.above:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame.above:Show()
    y = y - MORE
  else
    frame.above:Hide()
  end
  local used = 0
  local visible = frame:IsShown()
  for index, data in ipairs(shown) do
    local row = rows[index]
    row:ClearAllPoints()
    if index >= first and index <= last then
      y = y - (index == first and 2 or gaps[index])
      row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
      row:SetHeight(heights[index])
      row:Show()
      y = y - heights[index]
      if visible and data.kind == "quest" and data.item then
        used = used + 1
        FillItem(items[used] or MakeItem(used), row, data)
      end
    else
      row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, 0)
      row:Hide()
    end
  end
  if last < count then
    frame.below:ClearAllPoints()
    frame.below:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y - 2)
    frame.below:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame.below:Show()
    y = y - MORE - 2
  else
    frame.below:Hide()
  end
  for index = #shown + 1, #rows do
    rows[index]:Hide()
    rows[index].data = nil
  end
  for index = used + 1, #items do
    items[index]:Hide()
    items[index].logIndex = nil
  end
  frame:SetWidth(width)
  frame:SetHeight(math.max(HEADER + 4, -y + PAD - 2))
  lastShape = QT.Shape(shown) .. "@" .. first .. "-" .. last
end

-- New data. Out of combat: a full layout (and again next frame, once the texts are measured). In a fight: rows of
-- the same shape are refilled in place; any other change waits for the fight to end.
function QT.Show(data, countText)
  if not frame then
    return
  end
  QT.countText = countText
  if InCombat() then
    if QT.Shape(data) .. "@" .. (QT.firstRow or 1) .. "-" .. (QT.lastRow or 0) == lastShape then
      for index, item in ipairs(data) do
        if rows[index] then
          shown[index] = item
          FillRow(rows[index], item)
        end
      end
      header.count:SetText(countText or "")
    else
      QT.afterCombat = true
    end
    return
  end
  for index = 1, math.max(#shown, #data) do
    shown[index] = data[index]
  end
  QT.Layout(true)
  C_Timer.After(0, function()
    if not InCombat() then
      QT.Layout(true)
    end
  end)
end

-- Shows or hides the whole window (out of combat only: its item buttons are secure).
function QT.SetShown(on)
  if not frame or InCombat() then
    QT.afterCombat = true
    return
  end
  frame:SetShown(on)
  if not on then
    for _, button in ipairs(items) do
      button:Hide()
    end
  end
end

function QT.IsShown()
  return frame ~= nil and frame:IsShown()
end
