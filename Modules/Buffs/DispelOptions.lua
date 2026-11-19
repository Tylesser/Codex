local addonName, codex = ...
local ns = codex.buffs
local UI = codex.UI

-- "Dispels" tab of the Buffs page: two check boxes (party frames, yourself) and the dispels you know
-- with what each removes.

local WIDTH = 600
local ROW_HEIGHT = 26

local panel, partyCheck, selfCheck, combatCheck, listTitle, listEmpty
local rows = {}

local function SpellIcon(name)
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(name)
  end
  return GetSpellTexture(name)
end

local function GetRow(index)
  local row = rows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel)
  row:SetSize(WIDTH, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -10 - (index - 1) * ROW_HEIGHT)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 0, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, "body", 12, "bright")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  rows[index] = row
  return row
end

local function Refresh()
  if not panel then
    return
  end
  partyCheck:SetChecked(ns.db.dispel.party)
  selfCheck:SetChecked(ns.db.dispel.self)
  combatCheck:SetChecked(ns.db.dispel.combat)
  local spells = ns.DispelSpells()
  for index, spell in ipairs(spells) do
    local row = GetRow(index)
    local types = {}
    for _, debuffType in ipairs(spell.typeList) do
      types[#types + 1] = ns.ColoredDebuffType(debuffType)
    end
    row.icon:SetTexture(SpellIcon(spell.name) or ns.DEFAULT_ICON)
    row.name:SetText(spell.name .. ": " .. table.concat(types, ", "))
    row:Show()
  end
  for index = #spells + 1, #rows do
    rows[index]:Hide()
  end
  listEmpty:SetShown(#spells == 0)
end

function ns.RefreshDispelOptions()
  if not (panel and panel:IsVisible()) then
    return
  end
  Refresh()
end

function ns.ShowDispelTab()
  ns.RefreshKnown()
  Refresh()
end

local function Changed()
  ns.PartyChanged()
  ns.UpdateSelfDispel()
  ns.RefreshDispelOptions()
end

function ns.BuildDispelTab(tab)
  panel = tab

  local intro = ns.HelpText(panel, "A button for each debuff you can remove, like a poison or a curse. Click it to "
    .. "cast your dispel on that player.", WIDTH)
  intro:SetPoint("TOPLEFT", 0, 0)

  partyCheck = ns.TightCheck(UI.Check(panel, "Dispel buttons next to party frames"))
  partyCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -24)
  partyCheck:SetScript("OnClick", function(self)
    ns.db.dispel.party = self:GetChecked() and true or false
    Changed()
  end)
  local partyHelp = ns.HelpText(panel, "In a party after the buff buttons, in a raid in the corner of the raid frames.",
    WIDTH - 24)
  partyHelp:SetPoint("TOPLEFT", partyCheck, "BOTTOMLEFT", 24, -2)

  selfCheck = ns.TightCheck(UI.Check(panel, "Dispel buttons for yourself, under the icon row"))
  selfCheck:SetPoint("TOPLEFT", partyHelp, "BOTTOMLEFT", -24, -10)
  selfCheck:SetScript("OnClick", function(self)
    ns.db.dispel.self = self:GetChecked() and true or false
    Changed()
  end)
  local selfHelp = ns.HelpText(panel, "Also when you play alone.", WIDTH - 24)
  selfHelp:SetPoint("TOPLEFT", selfCheck, "BOTTOMLEFT", 24, -2)

  combatCheck = ns.TightCheck(UI.Check(panel, "Show dispel icons in combat"))
  combatCheck:SetPoint("TOPLEFT", selfHelp, "BOTTOMLEFT", -24, -10)
  combatCheck:SetScript("OnClick", function(self)
    ns.db.dispel.combat = self:GetChecked() and true or false
    Changed()
  end)
  local combatHelp = ns.HelpText(panel, "During a fight the game doesn't let addons add or move clickable buttons, so "
    .. "a debuff that shows up then gets a plain icon in the same place instead. It takes no clicks. Buttons that "
    .. "were there before the fight keep working.", WIDTH - 24)
  combatHelp:SetPoint("TOPLEFT", combatCheck, "BOTTOMLEFT", 24, -2)

  listTitle = ns.SectionHeading(panel, "Your dispels", WIDTH)
  listTitle:SetPoint("TOPLEFT", combatHelp, "BOTTOMLEFT", -24, -20)

  listEmpty = ns.HelpText(panel, "You don't know a spell that removes debuffs from others yet. Paladins (Purify, "
    .. "Cleanse), priests, druids, shamans and mages learn one, and on newer game versions monks and evokers too. "
    .. "New ones show up here as you learn them.", WIDTH)
  listEmpty:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -10)

  local note = ns.HelpText(panel, "When two of your spells remove the same debuff type, the button uses the better "
    .. "one, like Cleanse over Purify. The button shows the debuff's icon, with a border in its type's color.", WIDTH)
  note:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -10 - 4 * ROW_HEIGHT - 8)
end
