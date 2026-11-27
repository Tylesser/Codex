local addonName, codex = ...
local L = codex.L
local ns = codex.buffs
local UI = codex.UI

-- "Party buffs" tab of the Buffs page. Top: the button options. Left: the group buffs you know,
-- each with an on/off box, the "every blessing" option and the low reagent warning. Right
-- (paladins): blessing per class, and per party member. Taller than the page, so it scrolls.

local ROW_HEIGHT = 24
local BUFF_ROW_HEIGHT = 38 -- two lines: the spells, then the reagent count
local LEFT_X, LEFT_WIDTH = 0, 300
local RIGHT_X, RIGHT_WIDTH = 330, 290
local HEADING_Y = -146 -- below the intro and the four check boxes
local LIST_Y = HEADING_Y - 26
local CYCLE_WIDTH = 96
local LOW_COLOR = { 1, 0.6, 0.2 } -- as on the button tooltips

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
if select(4, GetBuildInfo()) >= 30000 and select(4, GetBuildInfo()) < 40000 then
  table.insert(CLASSES, 2, "DEATHKNIGHT")
end
local UNITS = { "player", "party1", "party2", "party3", "party4" }

local panel, enabledCheck, refreshCheck, refreshButton, rangeCheck, rangeButton, allBlessingsCheck, reagentButton
local raidCheck, resCheck
local buffRows, buffEmpty = {}, nil
local blessingTitle, blessingEmpty, classRows, memberTitle, memberRows, memberEmpty = nil, nil, {}, nil, {}, nil

local function ColoredClass(class, text)
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not color then
    return text
  end
  local function Byte(value)
    return math.floor(value * 255 + 0.5)
  end
  return string.format("|cff%02x%02x%02x%s|r", Byte(color.r), Byte(color.g), Byte(color.b), text)
end

local function ClassName(class)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function BlessingLabel(key)
  local family = key and ns.FAMILY[key]
  if family then
    return family.label
  end
  return L["None"]
end

-- Next value in: [by class], none, then each known blessing.
local function NextBlessing(current, withClassOption)
  local order = {}
  if withClassOption then
    order[#order + 1] = false
  end
  order[#order + 1] = "none"
  for _, family in ipairs(ns.KnownBlessings()) do
    order[#order + 1] = family.key
  end
  local currentValue = current
  if currentValue == nil then
    currentValue = withClassOption and false
  end
  if currentValue == nil or currentValue == false and not withClassOption then
    currentValue = "none"
  end
  for index, value in ipairs(order) do
    if value == currentValue then
      return order[index % #order + 1] or nil
    end
  end
  return order[1] or nil
end

local function CycleButton(parent)
  return UI.Button(parent, CYCLE_WIDTH, 22)
end

local function GetBuffRow(index)
  local row = buffRows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(LEFT_WIDTH, BUFF_ROW_HEIGHT - 2)
  row:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, LIST_Y - (index - 1) * BUFF_ROW_HEIGHT)
  row.check = UI.Check(row)
  row.check:SetHitRectInsets(0, 0, 0, 0)
  row.check:SetPoint("TOPLEFT", 0, 0)
  row.check:SetScript("OnClick", function(self)
    ns.db.party.off[self:GetParent().family.key] = not self:GetChecked() or nil
    ns.PartyChanged()
  end)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, "body", 12, "bright")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.reagent = UI.Text(row, "body", 11, "muted")
  row.reagent:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
  buffRows[index] = row
  return row
end

local function SpellIcon(name)
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(name)
  end
  return GetSpellTexture(name)
end

local function RefreshBuffs()
  local used = 0
  for _, family in ipairs(ns.GROUP_BUFFS) do
    if ns.KnowsFamily(family) then
      used = used + 1
      local row = GetBuffRow(used)
      row.family = family
      row.check:SetChecked(ns.FamilyEnabled(family))
      local names = {}
      for _, spell in ipairs(family.spells) do
        if ns.KnowsSpell(spell.name) then
          names[#names + 1] = spell.name
        end
      end
      row.icon:SetTexture(SpellIcon(names[1]) or ns.DEFAULT_ICON)
      local text = names[1] or ""
      for index = 2, #names do
        text = L["%s, or %s"]:format(text, names[index])
      end
      row.name:SetText(text)
      local first = family.spells[1]
      if ns.KnowsSpell(first.name) and first.reagents then
        row.reagent:SetText((ns.ReagentName(first) or L["Reagent"]) .. ": " .. ns.ReagentCount(first))
        row.reagent:SetTextColor(UI.Unpack(ns.ReagentLow(first) and LOW_COLOR or codex.Theme().muted))
      else
        row.reagent:SetText("")
      end
      row:Show()
    end
  end
  for index = used + 1, #buffRows do
    buffRows[index]:Hide()
  end
  buffEmpty:SetShown(used == 0)
end

local function GetClassRow(index)
  local row = classRows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(RIGHT_WIDTH, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, LIST_Y - (index - 1) * ROW_HEIGHT)
  row.button = CycleButton(row)
  row.button:SetPoint("RIGHT", 0, 0)
  row.button:SetScript("OnClick", function(self)
    local class = self:GetParent().class
    local classes = ns.db.party.classes
    local current = classes[class] or ns.DEFAULT_BLESSINGS[class] or "none"
    classes[class] = NextBlessing(current, false) or "none"
    ns.PartyChanged()
  end)
  row.name = UI.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", 4, 0)
  classRows[index] = row
  return row
end

local function GetMemberRow(index)
  local row = memberRows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(RIGHT_WIDTH, ROW_HEIGHT)
  row.button = CycleButton(row)
  row.button:SetPoint("RIGHT", 0, 0)
  row.button:SetScript("OnClick", function(self)
    local members = ns.db.party.members
    local name = self:GetParent().memberName
    members[name] = NextBlessing(members[name], true)
    ns.PartyChanged()
  end)
  row.name = UI.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", 4, 0)
  row.name:SetPoint("RIGHT", row.button, "LEFT", -4, 0)
  row.name:SetWordWrap(false)
  memberRows[index] = row
  return row
end

local function RefreshBlessings()
  local known = #ns.KnownBlessings() > 0
  blessingEmpty:SetShown(not known)
  memberTitle:SetShown(known)
  local classes = ns.db.party.classes
  for index, class in ipairs(CLASSES) do
    local row = GetClassRow(index)
    row.class = class
    row.name:SetText(ColoredClass(class, ClassName(class)))
    row.button:SetText(BlessingLabel(classes[class] or ns.DEFAULT_BLESSINGS[class]))
    row:SetShown(known)
  end
  memberTitle:ClearAllPoints()
  memberTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, LIST_Y - #CLASSES * ROW_HEIGHT - 12)

  local used = 0
  if known then
    for _, unit in ipairs(UNITS) do
      local name = UnitExists(unit) and GetUnitName(unit, true)
      if name then
        used = used + 1
        local row = GetMemberRow(used)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", memberTitle, "BOTTOMLEFT", 0, -8 - (used - 1) * ROW_HEIGHT)
        row.memberName = name
        local _, class = UnitClass(unit)
        row.name:SetText(ColoredClass(class, name))
        local own = ns.db.party.members[name]
        if own then
          row.button:SetText(BlessingLabel(own))
        else
          local byClass = ns.db.party.classes[class] or ns.DEFAULT_BLESSINGS[class]
          row.button:SetText(L["Class: %s"]:format(BlessingLabel(byClass)))
        end
        row:Show()
      end
    end
  end
  for index = used + 1, #memberRows do
    memberRows[index]:Hide()
  end
  memberEmpty:SetShown(known and used <= 1 and not IsInGroup())
end

local function Refresh()
  if not panel then
    return
  end
  enabledCheck:SetChecked(ns.db.party.enabled)
  refreshCheck:SetChecked(ns.db.party.refresh)
  allBlessingsCheck:SetChecked(ns.db.party.allBlessings)
  raidCheck:SetChecked(ns.db.party.raid)
  resCheck:SetChecked(ns.db.party.res ~= false)
  refreshButton:SetText(ns.FormatSeconds(ns.db.party.refreshSeconds))
  refreshButton:SetEnabled(ns.db.party.refresh)
  rangeCheck:SetChecked(ns.db.party.range)
  rangeButton:SetText(L["%d yd"]:format(ns.db.party.rangeYards))
  rangeButton:SetEnabled(ns.db.party.range)
  local warn = ns.db.party.reagentWarn
  reagentButton:SetText(warn > 0 and tostring(warn) or L["Off"])
  RefreshBuffs()
  RefreshBlessings()
end

function ns.RefreshPartyOptions()
  if not (panel and panel:IsVisible()) then
    return
  end
  Refresh()
end

function ns.ShowPartyTab()
  ns.RefreshKnown()
  Refresh()
end

function ns.BuildPartyTab(tab)
  panel = ns.ScrollBody(tab, 580)

  local intro = ns.HelpText(panel, L["Buttons next to your party frames for buffs a member is missing. Click one to cast it on them. Buttons can't appear or move during combat, so they update when combat ends."], 620)
  intro:SetPoint("TOPLEFT", 0, 0)

  enabledCheck = ns.TightCheck(UI.Check(panel, L["Show buff buttons next to party frames"]))
  enabledCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, -34)
  enabledCheck:SetScript("OnClick", function(self)
    ns.db.party.enabled = self:GetChecked() and true or false
    ns.PartyChanged()
  end)

  refreshCheck = ns.TightCheck(UI.Check(panel, L["Also show buffs that end within"]))
  refreshCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, -4)
  refreshCheck:SetScript("OnClick", function(self)
    ns.db.party.refresh = self:GetChecked() and true or false
    ns.PartyChanged()
  end)

  -- Cycles through ns.REFRESH_CHOICES.
  refreshButton = UI.Button(panel, 64, 20)
  refreshButton:SetPoint("LEFT", refreshCheck.label, "RIGHT", 8, 0)
  refreshButton:SetScript("OnClick", function()
    local party = ns.db.party
    local nextValue = ns.REFRESH_CHOICES[1]
    for _, seconds in ipairs(ns.REFRESH_CHOICES) do
      if seconds > party.refreshSeconds then
        nextValue = seconds
        break
      end
    end
    party.refreshSeconds = nextValue
    ns.PartyChanged()
  end)

  raidCheck = ns.TightCheck(UI.Check(panel, L["Buttons on raid frames"]))
  raidCheck:SetPoint("TOPLEFT", refreshCheck, "BOTTOMLEFT", 0, -4)
  raidCheck:SetScript("OnClick", function(self)
    ns.db.party.raid = self:GetChecked() and true or false
    ns.PartyChanged()
  end)
  raidCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Buttons on raid frames"])
    GameTooltip:AddLine(L["In a raid, small buttons in the top right corner of each raid frame. They hide during combat, so a click there always reaches the raid frame."],
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  raidCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  resCheck = ns.TightCheck(UI.Check(panel, L["Resurrect the dead"]))
  resCheck:SetPoint("TOPLEFT", raidCheck, "BOTTOMLEFT", 0, -4)
  resCheck:SetScript("OnClick", function(self)
    ns.db.party.res = self:GetChecked() and true or false
    ns.PartyChanged()
  end)
  resCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Resurrect the dead"])
    GameTooltip:AddLine(L["A dead party or raid member (not released) gets a button with your class's resurrection spell instead of their buff buttons. Dimmed while someone is already resurrecting them. Out of combat, like every button here."],
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  resCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Right column, beside the boxes above: a distance limit, cycling through ns.RANGE_CHOICES.
  rangeCheck = ns.TightCheck(UI.Check(panel, L["Hide when farther than"]))
  rangeCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, -34)
  rangeCheck:SetScript("OnClick", function(self)
    ns.db.party.range = self:GetChecked() and true or false
    ns.PartyChanged()
  end)

  rangeButton = UI.Button(panel, 56, 20)
  rangeButton:SetPoint("LEFT", rangeCheck.label, "RIGHT", 8, 0)
  rangeButton:SetScript("OnClick", function()
    local party = ns.db.party
    local nextValue = ns.RANGE_CHOICES[1]
    for _, yards in ipairs(ns.RANGE_CHOICES) do
      if yards > party.rangeYards then
        nextValue = yards
        break
      end
    end
    party.rangeYards = nextValue
    ns.PartyChanged()
  end)

  local rangeHelp = ns.HelpText(panel, L["Closer members keep their buttons, red while out of spell range."],
    RIGHT_WIDTH - 24)
  rangeHelp:SetPoint("TOPLEFT", rangeCheck, "BOTTOMLEFT", 24, -2)

  local buffTitle = ns.SectionHeading(panel, L["Your group buffs"], LEFT_WIDTH)
  buffTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, HEADING_Y)

  buffEmpty = ns.HelpText(panel, L["You don't know any group buffs yet (%s)."]:format(table.concat({
    ns.LocalSpell("Arcane Intellect"), ns.LocalSpell("Power Word: Fortitude"), ns.LocalSpell("Divine Spirit"),
    ns.LocalSpell("Shadow Protection"), ns.LocalSpell("Mark of the Wild") }, ", ")), LEFT_WIDTH)
  buffEmpty:SetPoint("TOPLEFT", buffTitle, "BOTTOMLEFT", 0, -10)

  local note = ns.HelpText(panel, L["The group spell is used when you can cast it. Without its reagent, the button casts the single-target spell instead."], LEFT_WIDTH)
  note:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT_X, LIST_Y - #ns.GROUP_BUFFS * BUFF_ROW_HEIGHT - 4)

  allBlessingsCheck = ns.TightCheck(UI.Check(panel, L["Paladins: show every blessing they're missing"]))
  allBlessingsCheck:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
  allBlessingsCheck:SetScript("OnClick", function(self)
    ns.db.party.allBlessings = self:GetChecked() and true or false
    ns.PartyChanged()
  end)

  local allBlessingsHelp = ns.HelpText(panel, L["When a member has no blessing, or another paladin already gave them the one chosen on the right, show a button for each blessing they don't have yet, not only the chosen one."],
    LEFT_WIDTH - 24)
  allBlessingsHelp:SetPoint("TOPLEFT", allBlessingsCheck, "BOTTOMLEFT", 24, -2)

  -- Low reagent warning, cycling through ns.REAGENT_CHOICES (0 = off).
  local reagentLabel = UI.Text(panel, "body", 12, "text")
  reagentLabel:SetPoint("TOPLEFT", allBlessingsHelp, "BOTTOMLEFT", -24, -14)
  reagentLabel:SetText(L["Warn when reagents drop to"])

  reagentButton = UI.Button(panel, 48, 20)
  reagentButton:SetPoint("LEFT", reagentLabel, "RIGHT", 8, 0)
  reagentButton:SetScript("OnClick", function()
    local party = ns.db.party
    local nextValue = ns.REAGENT_CHOICES[1]
    for _, count in ipairs(ns.REAGENT_CHOICES) do
      if count > party.reagentWarn then
        nextValue = count
        break
      end
    end
    party.reagentWarn = nextValue
    ns.PartyChanged()
  end)

  local reagentHelp = ns.HelpText(panel, L["A chat message each time a reagent of your group buffs goes down to this many or fewer. The button tooltips show the count in orange."], LEFT_WIDTH)
  reagentHelp:SetPoint("TOPLEFT", reagentLabel, "BOTTOMLEFT", 0, -6)

  blessingTitle = ns.SectionHeading(panel, L["Blessings by class"], RIGHT_WIDTH)
  blessingTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", RIGHT_X, HEADING_Y)

  blessingEmpty = ns.HelpText(panel, L["For paladins: choose a blessing for each class and party member."], RIGHT_WIDTH)
  blessingEmpty:SetPoint("TOPLEFT", blessingTitle, "BOTTOMLEFT", 0, -10)

  memberTitle = ns.SectionHeading(panel, L["Party members"], RIGHT_WIDTH)

  memberEmpty = ns.HelpText(panel, L["Join a group to choose a blessing for each member. Their choice is kept by name."],
    RIGHT_WIDTH)
  memberEmpty:SetPoint("TOPLEFT", memberTitle, "BOTTOMLEFT", 0, -8 - ROW_HEIGHT)
end
