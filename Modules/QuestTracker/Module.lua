local addonName, ns = ...

-- Quest tracker, part 3: the module (the user's request, 2026-11-20: "show the zone names as groups", option 2 =
-- Codex's own tracker). Settings `CodexDB.questtracker` (width, background, yield, foldOthers, collapsed, point),
-- folded zones per character `CodexCharDB.questtracker.folded[zone]`. Events refresh 0.1 s later; zone changes
-- re-sort. Stands aside while another addon has parked Blizzard's tracker (FlareUI's own tracker) and, with
-- `yield` on, while the game's tracker has more than quests to show.

local UI = ns.UI
local QT = ns.questtracker
local QO = ns.QuestOrder

local DEFAULTS = { width = 260, background = true, yield = true, foldOthers = false, collapsed = false }
QT.WIDTHS = { { 220, "Narrow" }, { 260, "Normal" }, { 300, "Wide" } }
-- nil = the game's tracker's own height (its Edit Mode "Height", or down to the screen's bottom in its default place)
QT.HEIGHTS = { { false, "Game's" }, { 300, "300" }, { 450, "450" }, { 600, "600" }, { 800, "800" } }

local events
local pending = false
local view = {}

function QT.DB()
  if not QT.db then
    ns.db.questtracker = ns.Fill(ns.db.questtracker or {}, DEFAULTS)
    QT.db = ns.db.questtracker
  end
  return QT.db
end

function QT.CharDB()
  if not QT.char then
    ns.char.questtracker = ns.char.questtracker or {}
    ns.char.questtracker.folded = ns.char.questtracker.folded or {}
    QT.char = ns.char.questtracker
  end
  return QT.char
end

local function InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

-- Folded zones: the player's own choice per zone; with "fold the other zones", every zone but yours starts folded
-- (a zone you unfold stays open: `opened`).
function QT.Folded()
  local char = QT.CharDB()
  local folded = {}
  for zone, on in pairs(char.folded) do
    folded[zone] = on
  end
  if QT.DB().foldOthers then
    for _, group in ipairs(QT.groups or {}) do
      if not group.here and char.folded[group.fold] == nil then
        folded[group.fold] = true
      end
    end
  end
  return folded
end

function QT.ToggleFold(zone)
  if not zone or InCombat() then
    return
  end
  local char = QT.CharDB()
  local now = QT.Folded()[zone] and true or false
  char.folded[zone] = not now
  QT.Refresh()
end

function QT.ToggleCollapsed()
  if InCombat() then
    return
  end
  local db = QT.DB()
  db.collapsed = not db.collapsed
  QT.Refresh()
end

-- Clicks on a quest, as Blizzard's tracker does them.
local function OpenQuest(questID)
  if InCombat() then
    ns.Say("The quest log opens after the fight.")
    return
  end
  if type(QuestMapFrame_OpenToQuestDetails) == "function" then
    pcall(QuestMapFrame_OpenToQuestDetails, questID)
  end
end

local function Untrack(questID)
  if QuestUtil and QuestUtil.CanRemoveQuestWatch and not QO.Ask(QuestUtil.CanRemoveQuestWatch) then
    return
  end
  QO.Ask(QO.API("RemoveQuestWatch"), questID)
end

local function LinkInChat(questID)
  if ChatFrameUtil and ChatFrameUtil.TryInsertQuestLinkForQuestID then
    return QO.Ask(ChatFrameUtil.TryInsertQuestLinkForQuestID, questID) == true
  end
  return false
end

function QT.Menu(questID, anchor)
  local title = QO.Str(QO.Ask(QO.API("GetTitleForQuestID"), questID)) or "Quest"
  local focused = C_SuperTrack and QO.Num(QO.Ask(C_SuperTrack.GetSuperTrackedQuestID)) == questID
  local list = { { text = title, title = true } }
  if C_SuperTrack then
    list[#list + 1] = { text = focused and (_G.STOP_SUPER_TRACK_QUEST or "Stop focusing")
      or (_G.SUPER_TRACK_QUEST or "Focus"), func = function()
        QO.Ask(C_SuperTrack.SetSuperTrackedQuestID, focused and 0 or questID)
      end }
  end
  if QuestUtil and QuestUtil.OpenQuestDetails then
    list[#list + 1] = { text = _G.OBJECTIVES_VIEW_IN_QUESTLOG or "Open in the quest log", func = function()
      if not InCombat() then
        pcall(QuestUtil.OpenQuestDetails, questID)
      end
    end }
  end
  list[#list + 1] = { text = _G.OBJECTIVES_SHOW_QUEST_MAP or "Show on the map", func = function()
    OpenQuest(questID)
  end }
  list[#list + 1] = { text = _G.OBJECTIVES_STOP_TRACKING or "Stop tracking", func = function()
    Untrack(questID)
  end }
  if QO.Ask(QO.API("IsPushableQuest"), questID) == true and QO.Ask(IsInGroup) == true and QuestUtil
    and QuestUtil.ShareQuest then
    list[#list + 1] = { text = _G.SHARE_QUEST or "Share", func = function()
      pcall(QuestUtil.ShareQuest, questID)
    end }
  end
  UI.ShowMenu(anchor, list)
  return list
end

function QT.QuestClick(questID, button, anchor)
  if button == "RightButton" then
    QT.Menu(questID, anchor)
    return
  end
  if LinkInChat(questID) then
    return
  end
  if IsModifiedClick and IsModifiedClick("QUESTWATCHTOGGLE") then
    Untrack(questID)
  else
    OpenQuest(questID)
  end
end

-- Hand over to the game's tracker? (another addon took it over, or it has more than quests to show)
function QT.Yielding()
  if QT.otherAddon then
    return true
  end
  return QT.DB().yield and QT.OtherObjectives() or false
end

function QT.Update()
  if not QT.running then
    return
  end
  if QT.Yielding() then
    if not InCombat() then
      QT.Unpark()
      QT.SetShown(false)
    else
      QT.afterCombat = true
    end
    return
  end
  if not QT.parked and not QT.Park() then
    QT.afterCombat = true
  end
  local db = QT.DB()
  QT.groups = QT.Groups()
  local total = 0
  for _, group in ipairs(QT.groups) do
    total = total + #group.quests
  end
  if not InCombat() then
    QT.SetShown(total > 0 or QT.editing)
  end
  QT.Show(QT.Rows(QT.groups, QT.Folded(), db.collapsed), total > 0 and tostring(total) or "")
end

function QT.Refresh()
  if not QT.running or pending then
    return
  end
  pending = true
  C_Timer.After(0.1, function()
    pending = false
    QT.Update()
  end)
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED",
  "QUEST_REMOVED", "QUEST_TURNED_IN", "SUPER_TRACKING_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
  "ZONE_CHANGED_INDOORS", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN", "UNIT_QUEST_LOG_CHANGED" }

local function OnEvent(_, event, unit)
  if event == "BAG_UPDATE_COOLDOWN" then
    for _, button in ipairs(QT.itemButtons) do
      QT.ItemCooldown(button)
    end
    return
  end
  if event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player" then
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    if not QT.afterCombat then
      return
    end
    QT.afterCombat = false
  end
  QT.Refresh()
end

function QT.Start()
  if QT.running then
    return
  end
  -- another addon already parked Blizzard's tracker (FlareUI's quest tracker): leave the quests to it
  if QT.ParkedByOther() then
    QT.otherAddon = true
    QT.running = true
    return
  end
  QT.running = true
  QT.Build()
  events = events or CreateFrame("Frame")
  events:SetScript("OnEvent", OnEvent)
  for _, event in ipairs(EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end
  -- the game's other tracker parts (a scenario starting, a recipe tracked) change without a quest event
  C_Timer.NewTicker(2, function()
    if QT.running and QT.DB().yield and (QT.OtherObjectives() ~= (QT.yielded or false)) then
      QT.yielded = QT.OtherObjectives()
      QT.Refresh()
    end
  end)
  QT.Update()
end

-- Page --------------------------------------------------------------------------------------------------------------

function QT.StatusText()
  if ns.ModuleState("questtracker") ~= "on" then
    return "Off: the game's quest tracker is shown."
  end
  if QT.otherAddon then
    return "Another addon has replaced the game's tracker, so Codex leaves the quests to it."
  end
  if QT.running and QT.Yielding() then
    return "The game's tracker is showing other objectives, so it shows your quests for now."
  end
  local count = 0
  for _, group in ipairs(QT.groups or {}) do
    count = count + #group.quests
  end
  return ("%d tracked quest%s in %d zone%s."):format(count, count == 1 and "" or "s", #(QT.groups or {}),
    #(QT.groups or {}) == 1 and "" or "s")
end

local function RefreshPage()
  if not view.page then
    return
  end
  local db = QT.DB()
  view.status:SetText(QT.StatusText())
  view.background:SetChecked(db.background ~= false)
  view.foldOthers:SetChecked(db.foldOthers and true or false)
  view.yield:SetChecked(db.yield ~= false)
  for _, button in ipairs(view.widths) do
    button:SetSelected(button.value == db.width)
  end
  for _, button in ipairs(view.heights) do
    button:SetSelected(button.value == (db.height or false))
  end
end
QT.RefreshPage = RefreshPage

local function Set(key, value)
  QT.DB()[key] = value
  QT.Refresh()
  RefreshPage()
end

function QT.BuildPage(page)
  view.page = page
  local heading = UI.Heading(page, "Codex quest tracker", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)
  view.status:SetJustifyH("LEFT")
  local about = UI.Text(page, "body", 12, "text")
  about:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -14)
  about:SetPoint("RIGHT", 0, 0)
  about:SetJustifyH("LEFT")
  about:SetText("Codex's own quest tracker shows your tracked quests under a heading per zone, the zone you're in "
    .. "first, the nearest quest first. Click a zone to fold it. Click a quest to open it in the quest log, "
    .. "Shift-click to stop tracking it, right-click for more. Quest items have their own button. Move it while "
    .. "Edit Mode is open (right-click its handle to put it back). Switching it on or off takes a reload.")

  view.background = UI.Check(page, "Background")
  view.background:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
  view.background:SetScript("OnClick", function(self) Set("background", self:GetChecked() and true or false) end)

  view.foldOthers = UI.Check(page, "Fold the zones you aren't in")
  view.foldOthers:SetPoint("TOPLEFT", view.background, "BOTTOMLEFT", 0, -8)
  view.foldOthers:SetScript("OnClick", function(self) Set("foldOthers", self:GetChecked() and true or false) end)

  view.yield = UI.Check(page, "Show the game's tracker while it has other objectives")
  view.yield:SetPoint("TOPLEFT", view.foldOthers, "BOTTOMLEFT", 0, -8)
  view.yield:SetScript("OnClick", function(self) Set("yield", self:GetChecked() and true or false) end)
  local yieldNote = UI.Text(page, "body", 11, "muted")
  yieldNote:SetPoint("TOPLEFT", view.yield, "BOTTOMLEFT", 26, -2)
  yieldNote:SetPoint("RIGHT", 0, 0)
  yieldNote:SetJustifyH("LEFT")
  yieldNote:SetText("A dungeon scenario, a tracked recipe or achievement, bonus objectives: the game's tracker comes "
    .. "back for them (with your quests) and Codex's steps aside until they're gone.")

  local widthLabel = UI.Text(page, "body", 12, "text")
  widthLabel:SetPoint("TOPLEFT", yieldNote, "BOTTOMLEFT", -26, -14)
  widthLabel:SetText("Width")
  view.widths = {}
  local last
  for _, entry in ipairs(QT.WIDTHS) do
    local button = UI.NavButton(page, 90, 24, nil, entry[2])
    button.value = entry[1]
    if last then
      button:SetPoint("LEFT", last, "RIGHT", 6, 0)
    else
      button:SetPoint("LEFT", widthLabel, "LEFT", 60, 0)
    end
    button:SetScript("OnClick", function() Set("width", entry[1]) end)
    view.widths[#view.widths + 1] = button
    last = button
  end
  local heightLabel = UI.Text(page, "body", 12, "text")
  heightLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -22)
  heightLabel:SetText("Height")
  view.heights = {}
  last = nil
  for _, entry in ipairs(QT.HEIGHTS) do
    local button = UI.NavButton(page, entry[1] and 56 or 76, 24, nil, entry[2])
    button.value = entry[1]
    if last then
      button:SetPoint("LEFT", last, "RIGHT", 6, 0)
    else
      button:SetPoint("LEFT", heightLabel, "LEFT", 60, 0)
    end
    button:SetScript("OnClick", function() Set("height", entry[1] or nil) end)
    view.heights[#view.heights + 1] = button
    last = button
  end
  local heightNote = UI.Text(page, "body", 11, "muted")
  heightNote:SetPoint("TOPLEFT", view.heights[1], "BOTTOMLEFT", 0, -6)
  heightNote:SetPoint("RIGHT", 0, 0)
  heightNote:SetJustifyH("LEFT")
  heightNote:SetText("Game's: as tall as the game's own tracker (its Edit Mode height). Quests that don't fit scroll "
    .. "with the mouse wheel over the tracker, out of combat.")
  local reset = UI.Button(page, 150, 24, "Put it back")
  reset:SetPoint("TOPLEFT", heightNote, "BOTTOMLEFT", 0, -16)
  reset:SetScript("OnClick", function()
    QT.ResetPosition()
  end)
  RefreshPage()
end

ns.RegisterModule({
  id = "questtracker",
  name = "Codex quest tracker",
  area = "quests", sectionOrder = 28, pageEstimate = 330,
  icon = "Interface\\Icons\\INV_Misc_Book_09",
  desc = "Codex's own quest tracker: your quests under a heading per zone, the zone you're in first.",
  order = 96,
  Enable = function()
    QT.DB()
    -- a second after login: by then another tracker addon has parked the game's tracker, if it does
    C_Timer.After(1, QT.Start)
  end,
  BuildPage = function(_, page)
    QT.BuildPage(page)
  end,
  ShowPage = function()
    RefreshPage()
  end,
  Status = function()
    return QT.StatusText()
  end,
})
