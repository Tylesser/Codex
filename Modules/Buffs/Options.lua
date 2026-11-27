local addonName, codex = ...
local L = codex.L
local ns = codex.buffs
local UI = codex.UI

-- The buff tracker on the Codex window's Buffs page, in three sections: "Buff tracker" (the module's own section,
-- this file: the icon row's options, the tracked buffs on the left, buffs, spells and weapon enchants to add on the
-- right), "Party buff buttons" (PartyOptions.lua) and "Dispel buttons" (DispelOptions.lua). Each is built the first
-- time its section opens; every Refresh* function returns at once while its section isn't on screen.

local ROW_HEIGHT = 26
local TRACKED_ROW_HEIGHT = 50 -- two lines: name and "when" on top, item and alert below
local LEFT_WIDTH = 300
local RIGHT_X = 330
local RIGHT_WIDTH = 300
local LIST_TOP = -120

local panel, lockCheck, clickCheck, shapeButton, sizeText, searchBox, searchHint, status, presetButton
local trackedList, pickerList, trackedEmpty, pickerEmpty
local spellbook = {}

-- Shared helpers for the three tabs ---------------------------------------------------------------

-- A section heading with a line under it.
function ns.SectionHeading(parent, text, width)
  local heading = UI.Text(parent, "head", 13, "accent")
  heading:SetText(text)
  local line = UI.Divider(parent)
  line:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3)
  line:SetWidth(width or 280)
  return heading
end

-- Small grey text that wraps at width.
function ns.HelpText(parent, text, width)
  local help = UI.Text(parent, "body", 11, "muted")
  help:SetWidth(width or 280)
  help:SetJustifyH("LEFT")
  if text then
    help:SetText(text)
  end
  return help
end

-- Only the label takes clicks, not the empty space after it (a button often sits there).
function ns.TightCheck(check)
  check:SetHitRectInsets(0, -(check.label:GetStringWidth() + 4), 0, 0)
  return check
end

-- A scrolling body for a tab taller than the page.
function ns.ScrollBody(parent, height)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  scroll:SetAllPoints()
  local body = CreateFrame("Frame", nil, scroll)
  body:SetSize(parent:GetWidth() > 0 and parent:GetWidth() or 640, height)
  scroll:SetScrollChild(body)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = math.max(0, body:GetHeight() - self:GetHeight())
    if range <= 1 then
      UI.ForwardWheel(self, delta) -- as tall as its section: the page scrolls
      return
    end
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
  end)
  parent.codexContentHeight = height
  return body, scroll
end

local function Hide()
  GameTooltip:Hide()
end

-- Tracked buffs tab -------------------------------------------------------------------------------

local function SetIcon(texture, icon)
  texture:SetTexture(icon or ns.DEFAULT_ICON)
  texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function ModeTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["When to show this buff"])
  GameTooltip:AddLine(L["When missing: only while it's not on you."], 1, 1, 1)
  GameTooltip:AddLine(L["When active: only while it's on you."], 1, 1, 1)
  GameTooltip:AddLine(L["Always: dimmed with a red border while it's missing."], 1, 1, 1)
  GameTooltip:AddLine(L["Click to change."], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function ItemTooltip(self)
  local entry = self:GetParent().item
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Item to use"])
  GameTooltip:AddLine(L["Clicking the icon uses this item, like a food for Well Fed or an elixir."], 1, 1, 1, true)
  if entry.slot then
    GameTooltip:AddLine(L["For a weapon enchant: an oil, poison or sharpening stone, put on this weapon."], 1, 1, 1, true)
  else
    GameTooltip:AddLine(L["Without one, a bag item named after the buff is used when you don't know its spell."],
      1, 1, 1, true)
  end
  GameTooltip:AddLine(L["Click: next usable item in your bags. Right-click: none."], 0.6, 0.6, 0.6, true)
  -- (the command takes the entry's own name: for weapon enchants the English one)
  GameTooltip:AddLine(L["Or type %s = <item name>"]:format("/codex buffs item " .. entry.name), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function AlertTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Alert"])
  GameTooltip:AddLine(L["Play a sound and flash the icon when this buff drops during combat."], 1, 1, 1, true)
  GameTooltip:AddLine(L["Only works while the game lets addons see your buffs in combat."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- "Use: Roasted Quail (4)", "Use: Elixir of the Mongoose (auto)", or "Use item: none".
local function ItemLabel(entry)
  local id, auto = ns.ItemFor(entry)
  if not id then
    return L["Use item: none"]
  end
  local name = ns.ItemName(id) or L["item %s"]:format(id)
  if auto then
    return L["Use: %s (auto)"]:format(name)
  end
  return L["Use: %s (%d)"]:format(name, ns.ItemCount(id))
end

-- A tracked row (UI.List row; row.item is the tracked entry).
local function CreateTrackedRow(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("TOPLEFT", 4, -4)

  row.remove = UI.Button(row, 22, 22, "x")
  row.remove:SetPoint("TOPRIGHT", -2, -4)
  row.remove:SetScript("OnClick", function(self)
    ns.RemoveBuff(self:GetParent().item.name)
  end)

  row.mode = UI.Button(row, 100, 22)
  row.mode:SetPoint("RIGHT", row.remove, "LEFT", -2, 0)
  row.mode:SetScript("OnClick", function(self)
    ns.CycleMode(self:GetParent().item)
  end)
  row.mode:SetScript("OnEnter", ModeTooltip)
  row.mode:SetScript("OnLeave", Hide)

  row.name = UI.Text(row, "body", 12, "bright")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.mode, "LEFT", -4, 0)
  row.name:SetWordWrap(false)

  -- second line: the item a click uses, and the combat alert
  row.use = UI.Button(row, 150, 20)
  row.use:SetPoint("TOPLEFT", 30, -27)
  row.use:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.use:SetScript("OnClick", function(self, button)
    local entry = self:GetParent().item
    if button == "RightButton" then
      ns.SetItem(entry, nil)
    else
      ns.CycleItem(entry)
    end
  end)
  row.use:SetScript("OnEnter", ItemTooltip)
  row.use:SetScript("OnLeave", Hide)

  row.alert = ns.TightCheck(UI.Check(row, L["Alert"]))
  row.alert:SetPoint("LEFT", row.use, "RIGHT", 6, 0)
  row.alert:SetScript("OnClick", function(self)
    self:GetParent().item.alert = self:GetChecked() and true or nil
  end)
  row.alert:SetScript("OnEnter", AlertTooltip)
  row.alert:SetScript("OnLeave", Hide)

  -- where and when it shows (ConditionsOptions.lua): the row's rules, or its own
  row.where = UI.Button(row, 54, 20, L["Where"])
  row.where:SetPoint("TOPRIGHT", -2, -27)
  row.where:SetScript("OnClick", function(self)
    ns.OpenConditions(self:GetParent().item, self)
  end)
  row.where:SetScript("OnEnter", function(self)
    ns.ConditionsTooltip(self, self:GetParent().item)
  end)
  row.where:SetScript("OnLeave", Hide)
end

local function UpdateTrackedRow(row, entry)
  SetIcon(row.icon, ns.EntryIcon(entry))
  row.name:SetText(ns.EntryName(entry))
  row.mode:SetText(ns.MODE_LABELS[entry.mode])
  row.use:SetText(ItemLabel(entry))
  row.alert:SetChecked(entry.alert or false)
  -- the theme's good colour: the buff has its own rules (the tooltip says which)
  local theme = codex.InkTheme and codex.InkTheme() or codex.Theme()
  local color = entry.conditions and theme.good or (theme.button and theme.button.text) or theme.accent
  row.where.textColor = entry.conditions and theme.good or nil
  if row.where.label then
    row.where.label:SetTextColor(color[1], color[2], color[3])
  end
end

-- A row to add (row.item = { name, icon, tag, weaponSlot }).
local function CreatePickerRow(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 4, 0)
  row.tag = UI.Text(row, "body", 11, "good")
  row.tag:SetPoint("RIGHT", -6, 0)
  row.name = UI.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.tag, "LEFT", -4, 0)
  row.name:SetWordWrap(false)
  row:SetScript("OnClick", function(self)
    local item = self.item
    if not item then
      return
    end
    if item.weaponSlot then
      ns.AddWeapon(item.weaponSlot)
    else
      ns.AddBuff(item.name, item.icon)
    end
  end)
end

local function UpdatePickerRow(row, item)
  SetIcon(row.icon, item.icon)
  row.name:SetText(item.label or item.name)
  row.tag:SetText(item.tag)
end

local function RefreshTracked()
  local items = {}
  for index, entry in ipairs(ns.db.tracked) do
    items[index] = entry
  end
  trackedList:SetItems(items)
  trackedEmpty:SetShown(#items == 0)
end

local function RefreshPicker()
  local filter = strtrim(searchBox:GetText() or ""):lower()
  local items, seen = {}, {}

  -- label: the text shown and searched, when it differs from the name (weapon enchant entries)
  local function Add(name, icon, tag, weaponSlot, label)
    local key = name:lower()
    if seen[key] or ns.IsTracked(name) then
      return
    end
    seen[key] = true
    if filter ~= "" and not key:find(filter, 1, true) and not (label and label:lower():find(filter, 1, true)) then
      return
    end
    items[#items + 1] = { name = name, icon = icon, tag = tag, weaponSlot = weaponSlot, label = label }
  end

  for _, buff in ipairs(ns.buffs) do
    Add(buff.name, buff.icon, L["on you"])
  end
  for _, spell in ipairs(spellbook) do
    Add(spell.name, spell.icon, "")
  end
  for _, slot in ipairs(ns.WEAPON_SLOTS) do
    Add(ns.WEAPON_NAMES[slot], GetInventoryItemTexture and GetInventoryItemTexture("player", slot), L["weapon"], slot,
      ns.WEAPON_LABELS[slot])
  end
  pickerList:SetItems(items)
  pickerEmpty:SetShown(#items == 0)

  searchHint:SetShown((searchBox:GetText() or "") == "" and not searchBox:HasFocus())
  if ns.scanComplete then
    status:SetText("")
  else
    status:SetText(L["The game is hiding your buffs right now. They'll update when it stops."])
  end
end

local function RefreshMain()
  if not panel then
    return
  end
  lockCheck:SetChecked(ns.db.locked)
  clickCheck:SetChecked(ns.db.clickToCast)
  sizeText:SetText(L["Icon size: %d"]:format(ns.db.iconSize))
  shapeButton:SetText(ns.RoundFromSettings() and L["Shape: Circle (Round icons)"]
    or L["Shape: %s"]:format(ns.SHAPE_LABELS[ns.db.iconShape] or L["Square"]))
  local preset = ns.PresetBuffs()
  presetButton:SetText(L["Add %s basics"]:format(UnitClass("player") or L["class"]))
  presetButton:SetShown(preset ~= nil)
  presetButton:SetEnabled(preset ~= nil and #preset > 0)
  RefreshTracked()
  RefreshPicker()
end

function ns.RefreshOptions()
  ns.RefreshConditions()
  if not (panel and panel:IsVisible()) then
    return
  end
  RefreshMain()
end

local function PresetTooltip(self)
  local list = ns.PresetBuffs() or {}
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self:GetText())
  if #list > 0 then
    GameTooltip:AddLine(L["Adds: %s"]:format(table.concat(list, ", ")), 1, 1, 1, true)
  else
    GameTooltip:AddLine(L["You already track the basic buffs of your class that you know."], 1, 1, 1, true)
  end
  GameTooltip:Show()
end

local function AddFromSearchBox()
  local entry, reason = ns.AddBuff(searchBox:GetText())
  if entry then
    searchBox:SetText("")
    searchBox:ClearFocus()
  else
    print(ns.PREFIX .. reason)
  end
end

local function CreateSizeButton(parent, label, delta)
  local button = UI.Button(parent, 24, 22, label)
  button:SetScript("OnClick", function()
    ns.SetIconSize(ns.db.iconSize + delta)
  end)
  return button
end

local function BuildTrackedTab(tab)
  panel = tab

  lockCheck = ns.TightCheck(UI.Check(tab, L["Lock position (untick to drag the icons)"]))
  lockCheck:SetPoint("TOPLEFT", 0, -4)
  lockCheck:SetScript("OnClick", function(self)
    ns.SetLocked(self:GetChecked() and true or false)
  end)

  clickCheck = ns.TightCheck(UI.Check(tab, L["Click icons to cast (out of combat)"]))
  clickCheck:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -4)
  clickCheck:SetScript("OnClick", function(self)
    ns.SetClickToCast(self:GetChecked() and true or false)
  end)

  local smaller = CreateSizeButton(tab, "-", -2)
  smaller:SetPoint("TOPLEFT", RIGHT_X, -4)
  sizeText = UI.Text(tab, "body", 12, "text")
  sizeText:SetPoint("LEFT", smaller, "RIGHT", 6, 0)
  sizeText:SetWidth(100)
  sizeText:SetJustifyH("CENTER")
  local larger = CreateSizeButton(tab, "+", 2)
  larger:SetPoint("LEFT", sizeText, "RIGHT", 6, 0)

  -- Square or circle, for the icon row and the party buttons.
  shapeButton = UI.Button(tab, 24 + 6 + 100 + 6 + 24, 22)
  shapeButton:SetPoint("TOPLEFT", smaller, "BOTTOMLEFT", 0, -4)
  shapeButton:SetScript("OnClick", function()
    ns.CycleShape()
  end)

  status = UI.Text(tab, "body", 11, "warn")
  status:SetPoint("TOPLEFT", 0, -58)

  local trackedTitle = ns.SectionHeading(tab, L["Tracked buffs"], LEFT_WIDTH)
  trackedTitle:SetPoint("TOPLEFT", 0, -74)

  -- "Add Mage basics": the class buffs you know (Core.lua, ns.PRESETS). Hidden for other classes.
  -- where and when the whole row shows (ConditionsOptions.lua)
  local rowWhere = UI.Button(tab, 140, 22, L["Where the row shows"])
  rowWhere:SetPoint("TOPLEFT", 0, -94)
  rowWhere:SetScript("OnClick", function(self)
    ns.OpenConditions("row", self)
  end)
  rowWhere:SetScript("OnEnter", function(self)
    ns.ConditionsTooltip(self, "row")
  end)
  rowWhere:SetScript("OnLeave", Hide)
  ns.rowWhereButton = rowWhere

  presetButton = UI.Button(tab, LEFT_WIDTH - 146, 22)
  presetButton:SetPoint("TOPLEFT", 146, -94)
  presetButton:SetScript("OnClick", function()
    ns.AddPreset()
  end)
  presetButton:SetScript("OnEnter", PresetTooltip)
  presetButton:SetScript("OnLeave", Hide)

  local addTitle = ns.SectionHeading(tab, L["Add a buff"], RIGHT_WIDTH)
  addTitle:SetPoint("TOPLEFT", RIGHT_X, -74)

  searchBox = UI.EditBox(tab, RIGHT_WIDTH, 22)
  searchBox:SetPoint("TOPLEFT", RIGHT_X, -94)
  searchBox:SetScript("OnEnterPressed", AddFromSearchBox)
  searchBox:SetScript("OnTextChanged", RefreshPicker)
  searchBox:HookScript("OnEditFocusGained", RefreshPicker)
  searchBox:HookScript("OnEditFocusLost", RefreshPicker)

  searchHint = UI.Text(searchBox, "body", 11, "muted")
  searchHint:SetPoint("LEFT", 6, 0)
  searchHint:SetText(L["Search, or type a name or spell ID"])

  trackedList = UI.List(tab, { rowHeight = TRACKED_ROW_HEIGHT, CreateRow = CreateTrackedRow,
    UpdateRow = UpdateTrackedRow })
  trackedList:SetPoint("TOPLEFT", 0, LIST_TOP)
  trackedList:SetPoint("BOTTOMLEFT", 0, 0)
  trackedList:SetWidth(LEFT_WIDTH)
  trackedEmpty = ns.HelpText(trackedList, L["Nothing tracked yet. Pick a buff from the list on the right."],
    LEFT_WIDTH - 16)
  trackedEmpty:SetPoint("TOPLEFT", 8, -8)

  pickerList = UI.List(tab, { rowHeight = ROW_HEIGHT, CreateRow = CreatePickerRow, UpdateRow = UpdatePickerRow })
  pickerList:SetPoint("TOPLEFT", RIGHT_X, LIST_TOP)
  pickerList:SetPoint("BOTTOMLEFT", RIGHT_X, 0)
  pickerList:SetWidth(RIGHT_WIDTH)
  pickerEmpty = ns.HelpText(pickerList,
    L["No matches. Press Enter to track this name anyway. It must match the buff's name exactly."], RIGHT_WIDTH - 16)
  pickerEmpty:SetPoint("TOPLEFT", 8, -8)

  ns.trackedList, ns.pickerList = trackedList, pickerList
end

local function ShowTrackedTab()
  spellbook = ns.GetSpellbook()
  ns.Scan()
  RefreshMain()
end

-- The page --------------------------------------------------------------------------------------

local tabFrames = {}

-- A module that is off (or left to the standalone Buff Tracker) never ran Enable: no saved data,
-- so the section only says why.
local function BuildOffPage(page)
  local heading = UI.Heading(page, L["Buffs"], 20)
  heading:SetPoint("TOPLEFT")
  local text = UI.Text(page, "body", 12, "text")
  text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
  text:SetWidth(600)
  text:SetJustifyH("LEFT")
  if codex.ModuleState("buffs") == "standalone" then
    text:SetText(L["Buff Tracker is installed on its own, so Codex leaves buffs to it. Use %s for its options, or pick \"Use Codex's instead\" at the top of this section."]:format("/btrack"))
  else
    text:SetText(L["The buff tracker is off, or switched on since the last reload. Switch it on at the top of the Buff tracker section and reload to use it."])
  end
  return { Height = function()
    return 70
  end }
end

-- The module's own section: the icon row's options and the tracked buffs.
function ns.BuildPage(module, page)
  if not ns.db then
    return BuildOffPage(page)
  end
  local heading = UI.Heading(page, L["Buffs"], 20)
  heading:SetPoint("TOPLEFT")
  local intro = UI.Text(page, "body", 12, "muted")
  intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  intro:SetText(L["Choose the buffs to watch. The list is saved per character."])
  local tab = CreateFrame("Frame", nil, page)
  tab:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -12)
  tab:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
  tabFrames.tracked = tab
  BuildTrackedTab(tab)
  ns.tabFrames = tabFrames
end

-- Every time the section is shown: it reads everything again.
function ns.ShowPage(module, page)
  if tabFrames.tracked then
    ShowTrackedTab()
  end
end

-- The two other sections on the Buffs page (Areas.lua), under the tracker.
local function SubSection(id, key, title, order, height, estimate, build, show, keywords)
  codex.AddSection("auras", {
    id = id,
    title = title,
    order = order,
    folded = true,
    keywords = keywords,
    height = function()
      return ns.db and height or nil
    end,
    estimate = estimate,
    notice = function()
      local state = codex.ModuleState("buffs")
      if state == "off" then
        return L["The buff tracker is off (the switch of the Buff tracker section above)."]
      end
      return nil
    end,
    build = function(holder)
      if not ns.db then
        return BuildOffPage(holder)
      end
      tabFrames[key] = holder
      ns.tabFrames = tabFrames
      build(holder)
    end,
    show = function()
      if ns.db and tabFrames[key] then
        show()
      end
    end,
  })
end
SubSection("buffs-party", "party", L["Party buff buttons"], 12, 580, nil, function(holder) ns.BuildPartyTab(holder) end,
  function() ns.ShowPartyTab() end,
  { "party buffs blessings reagents range click to buff", L["party buffs blessings reagents range click to buff"] })
SubSection("buffs-dispel", "dispel", L["Dispel buttons"], 14, nil, 400, function(holder) ns.BuildDispelTab(holder) end,
  function() ns.ShowDispelTab() end, { "dispels poison curse disease magic", L["dispels poison curse disease magic"] })

-- Opens the Buffs page at a section: "tracked" (default, the buff tracker), "party" or "dispel".
local SECTION_OF = { tracked = "buffs", party = "buffs-party", dispel = "buffs-dispel" }
function ns.OpenOptions(tab)
  codex.ShowPage(SECTION_OF[tab or "tracked"] or "buffs")
end

function ns.OpenPartyOptions()
  ns.OpenOptions("party")
end

function ns.OpenDispelOptions()
  ns.OpenOptions("dispel")
end
