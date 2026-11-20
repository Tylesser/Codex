local addonName, codex = ...
local ns = codex.buffs
local UI = codex.UI

-- The "Where buffs show" window (Conditions.lua has the rules), the twin of Buff Tracker's ConditionsOptions.lua on
-- Codex's widgets: opened from "Where the row shows" above the tracked list (the whole row) and from each tracked
-- buff's "Where" button (that buff: its own rules, or the row's). Where / Group: tick what to show in; Combat: one of
-- three. A buff following the row shows the row's choices greyed.

local WIDTH, HEIGHT = 430, 300
local window

local function Target()
  return window and window.target
end

local function Conditions()
  local target = Target()
  if target == "row" then
    return ns.db.conditions
  end
  return ns.EntryConditions(target)
end

local function Editable()
  local target = Target()
  return target == "row" or (type(target) == "table" and target.conditions ~= nil)
end

local function MakeCheck(label, onClick)
  local check = ns.TightCheck(UI.Check(window, label))
  check:SetScript("OnClick", onClick)
  return check
end

local function Build()
  window = CreateFrame("Frame", "CodexBuffConditions", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  UI.Panel(window, { cornerSize = 12 })
  local title = UI.Heading(window, "Where buffs show", 15)
  title:SetPoint("TOPLEFT", 16, -14)
  local close = UI.CloseButton(window)
  close:SetPoint("TOPRIGHT", -10, -10)
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "CodexBuffConditions")
  end

  window.name = UI.Text(window, "body", 12, "bright")
  window.name:SetPoint("TOPLEFT", 16, -40)
  window.name:SetPoint("RIGHT", -16, 0)
  window.name:SetJustifyH("LEFT")

  window.own = MakeCheck("Its own rules (unticked: the same as the whole row)", function(self)
    if type(Target()) == "table" then
      ns.SetOwnConditions(Target(), self:GetChecked() and true or false)
    end
  end)
  window.own:SetPoint("TOPLEFT", 12, -58)

  local left = ns.SectionHeading(window, "Where", 190)
  left:SetPoint("TOPLEFT", 16, -90)
  window.places = {}
  local last = left
  for _, place in ipairs(ns.PLACES) do
    local check = MakeCheck(place.label, function(self)
      ns.SetCondition(Target(), "place", place.key, self:GetChecked() and true or false)
    end)
    check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == left and -4 or 0, last == left and -6 or 0)
    check.key = place.key
    window.places[#window.places + 1] = check
    last = check
  end

  local right = ns.SectionHeading(window, "Group", 190)
  right:SetPoint("TOPLEFT", 226, -90)
  window.groups = {}
  last = right
  for _, group in ipairs(ns.GROUPS) do
    local check = MakeCheck(group.label, function(self)
      ns.SetCondition(Target(), "group", group.key, self:GetChecked() and true or false)
    end)
    check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == right and -4 or 0, last == right and -6 or 0)
    check.key = group.key
    window.groups[#window.groups + 1] = check
    last = check
  end

  local combat = ns.SectionHeading(window, "Combat", 190)
  combat:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -10)
  window.combat = {}
  last = combat
  for _, choice in ipairs(ns.COMBAT) do
    local check = MakeCheck(choice.label, function()
      ns.SetCondition(Target(), "combat", choice.key)
    end)
    check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == combat and -4 or 0, last == combat and -6 or 0)
    check.key = choice.key
    window.combat[#window.combat + 1] = check
    last = check
  end

  window.summary = UI.Text(window, "body", 11, "muted")
  window.summary:SetPoint("BOTTOMLEFT", 16, 14)
  window.summary:SetPoint("BOTTOMRIGHT", -16, 14)
  window.summary:SetJustifyH("LEFT")
  window:Hide()
end

function ns.RefreshConditions()
  if not (window and window:IsShown()) then
    return
  end
  local target = Target()
  local conditions = Conditions() or {}
  local editable = Editable()
  local isEntry = type(target) == "table"
  window.own:SetShown(isEntry)
  window.own:SetChecked(isEntry and target.conditions ~= nil)
  window.name:SetText(isEntry and target.name or "The whole row (every tracked buff without its own rules)")
  local function Ready(check, on)
    check:SetChecked(on)
    check:SetEnabled(editable)
    check:SetAlpha(editable and 1 or 0.55)
  end
  for _, check in ipairs(window.places) do
    Ready(check, not (conditions.places and conditions.places[check.key] == false))
  end
  for _, check in ipairs(window.groups) do
    Ready(check, not (conditions.groups and conditions.groups[check.key] == false))
  end
  local combat = conditions.combat or "any"
  for _, check in ipairs(window.combat) do
    Ready(check, check.key == combat)
  end
  local text = ns.ConditionsText(Conditions())
  window.summary:SetText(isEntry and not editable and ("Same as the whole row: " .. text) or text)
end

-- Opens the window for "row" or a tracked entry, beside `anchor`.
function ns.OpenConditions(target, anchor)
  if not window then
    Build()
  end
  window.target = target
  window:ClearAllPoints()
  if anchor then
    window:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
  else
    window:SetPoint("CENTER")
  end
  window:Show()
  ns.RefreshConditions()
end

-- Tooltip for a "Where" button.
function ns.ConditionsTooltip(self, target)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if target == "row" then
    GameTooltip:AddLine("Where the row shows")
    GameTooltip:AddLine(ns.ConditionsText(ns.db.conditions), 1, 1, 1, true)
  else
    GameTooltip:AddLine("Where " .. target.name .. " shows")
    local text = ns.ConditionsText(ns.EntryConditions(target))
    GameTooltip:AddLine(target.conditions and text or ("Same as the whole row: " .. text), 1, 1, 1, true)
  end
  GameTooltip:AddLine("On top of Always / When active / When missing. Click to change.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end
