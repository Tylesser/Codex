local addonName, codex = ...
local L = codex.L
local ns = codex.buffs
local UI = codex.UI

-- The "Where buffs show" window (Conditions.lua has the rules), the twin of Buff Tracker's ConditionsOptions.lua on
-- Codex's widgets: opened from "Where the row shows" above the tracked list (the whole row) and from each tracked
-- buff's "Where" button (that buff: its own rules, or the row's). Where / Talents (dual spec) / Group: tick what to
-- show in (Role: group roles, under Group); Combat: one of three. A buff following the row shows the row's
-- choices greyed.

local WIDTH, HEIGHT = 430, 330
local TALENTS_HEIGHT = 64 -- the Talents section, where the game has dual spec
local ROLES_HEIGHT = 90 -- the Role section (group roles), under Group
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
  window:SetSize(WIDTH, HEIGHT + (ns.HasTalentGroups() and TALENTS_HEIGHT or 0) + (ns.HasRoles() and ROLES_HEIGHT or 0))
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  UI.Panel(window, { cornerSize = 12 })
  local title = UI.Heading(window, L["Where buffs show"], 15)
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

  window.own = MakeCheck(L["Its own rules (unticked: the same as the whole row)"], function(self)
    if type(Target()) == "table" then
      ns.SetOwnConditions(Target(), self:GetChecked() and true or false)
    end
  end)
  window.own:SetPoint("TOPLEFT", 12, -58)

  local left = ns.SectionHeading(window, L["Where"], 190)
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

  -- dual spec (Conditions.lua ns.TALENTS), under Where; only where the game has two talent groups
  window.talents = {}
  if ns.HasTalentGroups() then
    local talents = ns.SectionHeading(window, L["Talents"], 190)
    talents:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -10)
    last = talents
    for _, choice in ipairs(ns.TALENTS) do
      local check = MakeCheck(choice.label, function(self)
        ns.SetCondition(Target(), "talents", choice.key, self:GetChecked() and true or false)
      end)
      check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == talents and -4 or 0, last == talents and -6 or 0)
      check.key = choice.key
      window.talents[#window.talents + 1] = check
      last = check
    end
  end

  local right = ns.SectionHeading(window, L["Group"], 190)
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

  -- group role (Conditions.lua ns.ROLES), under Group; only where the game has roles
  window.roles = {}
  if ns.HasRoles() then
    local roles = ns.SectionHeading(window, L["Role"], 190)
    roles:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -10)
    last = roles
    for _, role in ipairs(ns.ROLES) do
      local check = MakeCheck(role.label, function(self)
        ns.SetCondition(Target(), "role", role.key, self:GetChecked() and true or false)
      end)
      check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", last == roles and -4 or 0, last == roles and -6 or 0)
      check.key = role.key
      window.roles[#window.roles + 1] = check
      last = check
    end
  end

  local combat = ns.SectionHeading(window, L["Combat"], 190)
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

  -- one setting for every buff (Conditions.lua ns.Unwanted): off by default
  window.warn = MakeCheck(L["Warn me when a buff with rules is on where they say no"], function(self)
    ns.SetWarnUnwanted(self:GetChecked() and true or false)
  end)
  window.warn:SetPoint("BOTTOMLEFT", 12, 32)
  window.warn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Warn me to remove it"])
    GameTooltip:AddLine(L["A tracked buff with rules (its own or the row's) that is on where they say no shows in the row with \"remove\" under it, and chat names it once. Click the icon to remove the buff (out of combat). For all buffs."],
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  window.warn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

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
  window.name:SetText(isEntry and ns.EntryName(target) or L["The whole row (every tracked buff without its own rules)"])
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
  for _, check in ipairs(window.talents) do
    Ready(check, not (conditions.talents and conditions.talents[check.key] == false))
  end
  for _, check in ipairs(window.roles) do
    Ready(check, not (conditions.roles and conditions.roles[check.key] == false))
  end
  local combat = conditions.combat or "any"
  for _, check in ipairs(window.combat) do
    Ready(check, check.key == combat)
  end
  window.warn:SetChecked(ns.db.warnUnwanted and true or false)
  local text = ns.ConditionsText(Conditions())
  window.summary:SetText(isEntry and not editable and L["Same as the whole row: %s"]:format(text) or text)
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
    GameTooltip:AddLine(L["Where the row shows"])
    GameTooltip:AddLine(ns.ConditionsText(ns.db.conditions), 1, 1, 1, true)
  else
    GameTooltip:AddLine(L["Where %s shows"]:format(ns.EntryName(target)))
    local text = ns.ConditionsText(ns.EntryConditions(target))
    GameTooltip:AddLine(target.conditions and text or L["Same as the whole row: %s"]:format(text), 1, 1, 1, true)
  end
  GameTooltip:AddLine(L["On top of Always / When active / When missing. Click to change."], 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end
