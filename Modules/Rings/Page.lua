local addonName, ns = ...
local R = ns.rings
local UI = ns.UI

-- The Rings page: the list of rings (new / rename / delete / use), a key button per ring (click it, then press a
-- key; right-click clears it), the twelve slots of the selected ring (drag a spell, item, macro or mount onto a
-- slot; right-click clears it; drag a slot onto another to swap them; click an empty slot for raid markers and
-- other actions), a small preview, and the ring and icon sizes. Changing rings is out of combat only: secure
-- frames can't change during a fight.

local view = {}
R.view = view

local SLOT, GAP = 42, 8
local PREVIEW_RADIUS, PREVIEW_ICON = 58, 24
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

function R.CanEdit()
  return not InCombatLockdown()
end

local COMBAT_NOTE = "Rings can only be changed out of combat."

-- Runs a change to a ring (out of combat), then brings the secure frames and the page in step.
function R.Edit(ring, change)
  if not R.CanEdit() then
    ns.Say(COMBAT_NOTE)
    return false
  end
  local ok = change()
  if R.running then
    R.Sync()
  end
  R.RefreshPage()
  return ok ~= false
end

-- Key names -------------------------------------------------------------------------------------------------------

-- "ALT-CTRL-SHIFT-F" from a pressed key and the modifiers held.
function R.KeyWithModifiers(key)
  local prefix = ""
  if IsAltKeyDown and IsAltKeyDown() then
    prefix = prefix .. "ALT-"
  end
  if IsControlKeyDown and IsControlKeyDown() then
    prefix = prefix .. "CTRL-"
  end
  if IsShiftKeyDown and IsShiftKeyDown() then
    prefix = prefix .. "SHIFT-"
  end
  return prefix .. key
end

-- The key as the game writes it ("Shift-F", "Mouse Button 4").
function R.KeyText(key)
  if not key then
    return "No key"
  end
  local text = GetBindingText and R.Call(GetBindingText, key)
  return (type(text) == "string" and text ~= "") and text or key
end

-- What else uses a ring's key: a list of plain sentences.
function R.KeyConflicts(ring)
  local notes = {}
  if not ring or not ring.key then
    return notes
  end
  for _, other in ipairs(R.Rings()) do
    if other ~= ring and other.key == ring.key then
      notes[#notes + 1] = ("The ring %s has this key too: only one of them can use it."):format(other.name)
    end
  end
  local action = GetBindingAction and R.Call(GetBindingAction, ring.key)
  if type(action) == "string" and action ~= "" then
    local name = GetBindingText and R.Call(GetBindingText, action, "BINDING_NAME_")
    if type(name) ~= "string" or name == "" or name == action then
      name = _G["BINDING_NAME_" .. action] or action
    end
    notes[#notes + 1] = ("In the game's key bindings this key is %s; while this ring is on, it opens the ring instead.")
      :format(name)
  end
  return notes
end

function R.SetKey(ring, key)
  return R.Edit(ring, function()
    ring.key = key
  end)
end

function R.SetEnabled(ring, on)
  return R.Edit(ring, function()
    ring.enabled = on and true or false
  end)
end

function R.SetSize(which, value)
  local limits = which == "radius" and R.RADIUS or R.ICON
  return R.Edit(nil, function()
    R.DB()[which] = math.max(limits.min, math.min(limits.max, value))
  end)
end

-- Selection and the list ------------------------------------------------------------------------------------------

local function Selected()
  local ring = view.selected and R.Find(view.selected)
  if not ring then
    ring = R.Rings()[1]
    view.selected = ring and ring.id
  end
  return ring
end
R.SelectedRing = Selected

function R.Select(id)
  view.selected = id
  view.confirmDelete = nil
  R.StopCapture()
  R.RefreshPage()
end

-- A spell, item, macro or mount dropped on a slot.
function R.DropOnSlot(index)
  local ring = Selected()
  local slice = R.FromCursor()
  if not (ring and slice) then
    return false
  end
  if ClearCursor then
    ClearCursor()
  end
  return R.Edit(ring, function()
    return R.SetSlice(ring, index, slice)
  end)
end

local function SlotUnderMouse()
  for index, slot in ipairs(view.slots or {}) do
    if slot:IsMouseOver() then
      return index
    end
  end
end

local function NewSlot(parent, index)
  local slot = CreateFrame("Button", nil, parent)
  slot:SetSize(SLOT, SLOT)
  R.DressIcon(slot, false)
  slot.index = index
  slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  slot:RegisterForDrag("LeftButton")
  slot:SetScript("OnReceiveDrag", function(self)
    R.DropOnSlot(self.index)
  end)
  slot:SetScript("OnClick", function(self, button)
    local ring = Selected()
    if not ring then
      return
    end
    if R.Call(GetCursorInfo) then
      R.DropOnSlot(self.index)
    elseif button == "RightButton" then
      R.Edit(ring, function() return R.SetSlice(ring, self.index, nil) end)
    elseif R.CanEdit() then
      R.OpenPicker(self, ring, self.index) -- everything a slot can hold (Picker.lua); dragging works too
    else
      ns.Say(COMBAT_NOTE)
    end
  end)
  slot:SetScript("OnDragStart", function(self)
    local ring = Selected()
    if ring and R.Slices(ring)[self.index] and R.CanEdit() then
      view.dragFrom = self.index
      view.ghost.art:SetTexture(self.art:GetTexture())
      view.ghost:Show()
    end
  end)
  slot:SetScript("OnDragStop", function()
    local from = view.dragFrom
    view.dragFrom = nil
    view.ghost:Hide()
    local to = SlotUnderMouse()
    local ring = Selected()
    if from and to and ring and to ~= from then
      R.Edit(ring, function() return R.MoveSlice(ring, from, to) end)
    end
  end)
  slot:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.info then
      GameTooltip:AddLine(self.info.name)
      GameTooltip:AddLine("Click to change it, drag to another slot to swap, right-click to clear.", 0.7, 0.7, 0.7, true)
    else
      GameTooltip:AddLine("Empty slot")
      GameTooltip:AddLine("Click to choose what goes here (spells, items, mounts, toys, macros, markers, actions, "
        .. "windows or another ring), or drag a spell, item, macro or mount onto it.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)
  slot:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return slot
end

-- Key capture -----------------------------------------------------------------------------------------------------

function R.StopCapture()
  if not view.capturing then
    return
  end
  view.capturing = false
  if view.key then
    view.key:EnableKeyboard(false)
  end
end

local function StartCapture()
  if not R.CanEdit() then
    ns.Say(COMBAT_NOTE)
    return
  end
  view.capturing = true
  view.key:EnableKeyboard(true)
  R.Call(view.key.SetPropagateKeyboardInput, view.key, false)
  R.RefreshPage()
end

-- A key pressed while the key button listens.
function R.CaptureKey(key)
  if not view.capturing then
    return false
  end
  if MODIFIER_KEYS[key] then
    return false
  end
  local ring = Selected()
  R.StopCapture()
  if key ~= "ESCAPE" and ring then
    R.SetKey(ring, R.KeyWithModifiers(key))
  else
    R.RefreshPage()
  end
  return true
end

-- The page --------------------------------------------------------------------------------------------------------

local function Label(parent, text)
  local label = UI.Text(parent, "body", 12, "muted")
  label:SetText(text)
  return label
end

local function Wrapped(parent, size, color, width)
  local text = UI.Text(parent, "body", size, color)
  text:SetWidth(width)
  text:SetJustifyH("LEFT")
  if text.SetWordWrap then
    text:SetWordWrap(true)
  end
  return text
end

function R.BuildPage(page)
  R.DB()
  view.page = page
  local width = ns.PAGE_WIDTH or 672
  local right = 206
  local rightWidth = width - right

  local heading = UI.Heading(page, "Rings", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)
  view.combat = UI.Text(page, "body", 12, "warn")
  view.combat:SetPoint("TOPRIGHT", 0, -4)
  view.combat:SetText(COMBAT_NOTE)

  -- the rings
  view.list = UI.List(page, {
    rowHeight = 24,
    CreateRow = function(row)
      row.name = UI.Text(row, "body", 13, "text")
      row.name:SetPoint("LEFT", 8, 0)
      row.name:SetPoint("RIGHT", -70, 0)
      row.name:SetWordWrap(false)
      row.key = UI.Text(row, "body", 11, "muted")
      row.key:SetPoint("RIGHT", -6, 0)
      row.key:SetJustifyH("RIGHT")
      row:SetScript("OnClick", function(self)
        if self.item then
          R.Select(self.item.id)
        end
      end)
    end,
    UpdateRow = function(row, ring)
      row.name:SetText(ring.name)
      row.name:SetTextColor(UI.Unpack(ring.enabled and ns.Theme().text or ns.Theme().muted))
      row.key:SetText(ring.enabled and (ring.key and R.KeyText(ring.key) or "no key") or "off")
      row.selected:SetShown(ring.id == view.selected)
    end,
  })
  view.list:SetPoint("TOPLEFT", 0, -58)
  view.list:SetSize(right - 16, 268)

  view.add = UI.Button(page, 92, 24, "New ring")
  view.add:SetPoint("TOPLEFT", view.list, "BOTTOMLEFT", 0, -8)
  view.add:SetScript("OnClick", function()
    R.Edit(nil, function()
      local ring = R.AddRing(nil)
      if not ring then
        ns.Say(("Codex keeps up to %d rings."):format(R.MAX_RINGS))
        return false
      end
      ring.enabled = true
      view.selected = ring.id
    end)
  end)
  view.delete = UI.Button(page, 92, 24, "Delete")
  view.delete:SetPoint("LEFT", view.add, "RIGHT", 6, 0)
  view.delete:SetScript("OnClick", function()
    local ring = Selected()
    if not ring then
      return
    end
    if view.confirmDelete ~= ring.id then
      view.confirmDelete = ring.id
      R.RefreshPage()
      return
    end
    R.Edit(ring, function()
      R.RemoveRing(ring.id)
      view.confirmDelete = nil
      view.selected = nil
    end)
  end)
  view.slash = Wrapped(page, 11, "muted", right - 16)
  view.slash:SetPoint("TOPLEFT", view.add, "BOTTOMLEFT", 0, -12)
  view.slash:SetText("/codex ring <name> opens a ring at the mouse, out of combat, to try it.")

  -- the selected ring
  local nameLabel = Label(page, "Name")
  nameLabel:SetPoint("TOPLEFT", right, -62)
  view.name = UI.EditBox(page, 200, 24)
  view.name:SetPoint("TOPLEFT", right + 70, -58)
  view.name:SetMaxLetters(32)
  view.name:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local ring = Selected()
    local text = strtrim(self:GetText() or "")
    if ring and text ~= "" and text ~= ring.name then
      R.Edit(ring, function()
        ring.name = text
      end)
    else
      R.RefreshPage()
    end
  end)
  view.enabled = UI.Check(page, "Use this ring")
  view.enabled:SetPoint("LEFT", view.name, "RIGHT", 16, 0)
  view.enabled:SetScript("OnClick", function(self)
    local ring = Selected()
    if ring and not R.SetEnabled(ring, self:GetChecked()) then
      self:SetChecked(ring.enabled)
    end
  end)

  local keyLabel = Label(page, "Key")
  keyLabel:SetPoint("TOPLEFT", right, -96)
  view.key = UI.Button(page, 200, 24, "")
  view.key:SetPoint("TOPLEFT", right + 70, -92)
  view.key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  view.key:SetScript("OnClick", function(_, button)
    local ring = Selected()
    if not ring then
      return
    end
    if view.capturing then
      R.StopCapture()
      R.RefreshPage()
    elseif button == "RightButton" then
      R.SetKey(ring, nil)
    else
      StartCapture()
    end
  end)
  view.key:SetScript("OnKeyDown", function(_, key)
    R.CaptureKey(key)
  end)
  view.key:SetScript("OnMouseDown", function(_, button)
    if view.capturing and MOUSE_KEYS[button] then
      R.CaptureKey(MOUSE_KEYS[button])
    end
  end)
  view.keyHint = UI.Text(page, "body", 11, "muted")
  view.keyHint:SetPoint("LEFT", view.key, "RIGHT", 10, 0)
  view.keyHint:SetPoint("RIGHT", page, "RIGHT", 0, 0) -- bound to the page: it wraps to two lines when narrow
  view.keyHint:SetJustifyH("LEFT")
  view.keyHint:SetWordWrap(true)
  view.keyHint:SetText("Click, then press a key. Right-click to clear.")
  view.conflict = Wrapped(page, 11, "warn", rightWidth)
  view.conflict:SetPoint("TOPLEFT", right, -122)

  local slicesLabel = Label(page, "Slices")
  slicesLabel:SetPoint("TOPLEFT", right, -158)
  view.slots = {}
  for index = 1, R.MAX_SLICES do
    local slot = NewSlot(page, index)
    local column, line = (index - 1) % 6, math.floor((index - 1) / 6)
    slot:SetPoint("TOPLEFT", right + column * (SLOT + GAP), -176 - line * (SLOT + GAP))
    view.slots[index] = slot
  end
  view.ghost = CreateFrame("Frame", nil, page)
  view.ghost:SetSize(SLOT, SLOT)
  view.ghost:SetFrameStrata("TOOLTIP")
  R.DressIcon(view.ghost, false)
  view.ghost:Hide()
  view.ghost:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  end)

  local gridBottom = -176 - 2 * (SLOT + GAP)
  view.auto = Wrapped(page, 11, "muted", 6 * (SLOT + GAP) - GAP)
  view.auto:SetPoint("TOPLEFT", right, gridBottom - 4)
  view.refill = UI.Button(page, 170, 22, "Fill from what you know")
  view.refill:SetPoint("TOPLEFT", right, gridBottom - 46)
  view.refill:SetScript("OnClick", function()
    local ring = Selected()
    if ring then
      R.Edit(ring, function() return R.Refill(ring) end)
    end
  end)
  view.try = UI.Button(page, 100, 22, "Try it")
  view.try:SetPoint("LEFT", view.refill, "RIGHT", 8, 0)
  view.try:SetScript("OnClick", function()
    local ring = Selected()
    if ring then
      local ok, why = R.ToggleAtCursor(ring)
      if not ok and why then
        ns.Say(why)
      end
    end
  end)
  view.hint = Wrapped(page, 11, "muted", rightWidth)
  view.hint:SetPoint("TOPLEFT", right, gridBottom - 80)
  view.hint:SetText("Click a slot to choose what goes in it: spells, items, mounts, toys, macros, raid markers, "
    .. "actions, windows or another ring (a ring inside a ring opens where you let go). Dragging a spell, item, "
    .. "macro or mount onto a slot works too. Right-click a slot to clear it, drag a slot onto another to swap "
    .. "them. In game: hold the key, point at a slice and let go to use it, or click a slice. Let go in the middle "
    .. "or far outside the ring, or press Escape, to use nothing. Slice 1 is at the top, the rest go clockwise. "
    .. "Works in combat; changes wait until the fight is over.")

  -- preview (right of the slots)
  local preview = UI.Ink(CreateFrame("Frame", nil, page)) -- a picture of the ring: on ink, as in game (Dawn)
  local diameter = 2 * (PREVIEW_RADIUS + PREVIEW_ICON)
  preview:SetSize(diameter, diameter)
  preview:SetPoint("TOPLEFT", right + 6 * (SLOT + GAP) + 10, -150)
  preview.back = preview:CreateTexture(nil, "BACKGROUND")
  preview.back:SetTexture(R.CIRCLE)
  preview.back:SetAllPoints()
  local panel = ns.InkTheme().panel
  preview.back:SetVertexColor(panel.from[1], panel.from[2], panel.from[3], 0.8)
  preview.edge = preview:CreateTexture(nil, "BORDER")
  preview.edge:SetTexture(R.RING_ART)
  preview.edge:SetAllPoints()
  local ringColor = R.RingColor()
  preview.edge:SetVertexColor(ringColor[1], ringColor[2], ringColor[3], 0.35)
  preview.top = CreateFrame("Frame", nil, preview)
  preview.top:SetAllPoints()
  preview.top:SetFrameLevel(preview:GetFrameLevel() + 10)
  preview.name = UI.Text(preview.top, "body", 11, "muted")
  preview.name:SetPoint("CENTER")
  preview.name:SetWidth(PREVIEW_RADIUS)
  preview.name:SetJustifyH("CENTER")
  preview.icons = {}
  for index = 1, R.MAX_SLICES do
    local icon = CreateFrame("Frame", nil, preview)
    icon:SetSize(PREVIEW_ICON, PREVIEW_ICON)
    R.DressIcon(icon, false)
    icon:Hide()
    preview.icons[index] = icon
  end
  view.preview = preview

  -- sizes: under the hint, however many lines it wraps to
  local radiusLabel = Label(page, "Ring size")
  radiusLabel:SetPoint("TOPLEFT", view.hint, "BOTTOMLEFT", 0, -16)
  view.radius = UI.Stepper(page, 48)
  view.radius:SetPoint("TOPLEFT", view.hint, "BOTTOMLEFT", 70, -12)
  view.radius.less:SetScript("OnClick", function()
    R.SetSize("radius", R.DB().radius - R.RADIUS.step)
  end)
  view.radius.more:SetScript("OnClick", function()
    R.SetSize("radius", R.DB().radius + R.RADIUS.step)
  end)
  local iconLabel = Label(page, "Icon size")
  iconLabel:SetPoint("LEFT", view.radius, "RIGHT", 24, 0)
  view.iconSize = UI.Stepper(page, 48)
  view.iconSize:SetPoint("LEFT", iconLabel, "RIGHT", 10, 0)
  view.iconSize.less:SetScript("OnClick", function()
    R.SetSize("iconSize", R.DB().iconSize - R.ICON.step)
  end)
  view.iconSize.more:SetScript("OnClick", function()
    R.SetSize("iconSize", R.DB().iconSize + R.ICON.step)
  end)
  -- the look: Blizzard's ping wheel (default) or Codex's own disc
  view.style = UI.Check(page, "Blizzard's ping wheel look")
  view.style:SetPoint("TOPLEFT", view.hint, "BOTTOMLEFT", 0, -42)
  view.style:SetScript("OnClick", function(self)
    local ping = self:GetChecked() and true or false
    R.Edit(nil, function()
      R.DB().style = (not ping) and "codex" or nil
    end)
    R.RefreshPage()
  end)
  view.style:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Ping wheel look")
    GameTooltip:AddLine("On: the rings look like the game's ping wheel (dark wheel, divider lines, a gold wedge on "
      .. "the slice you point at, names beside the icons, the close mark in the middle). Off: Codex's own disc "
      .. "with the name in the middle.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  view.style:SetScript("OnLeave", GameTooltip_Hide)

  R.RefreshPage()
end

function R.StatusText()
  if not R.running then
    return "Off. Switch rings on at the top of this section to use them."
  end
  local used = 0
  for _, ring in ipairs(R.Rings()) do
    if ring.enabled and ring.key then
      used = used + 1
    end
  end
  if used == 0 then
    return "On, but no ring has a key yet: pick a ring, tick \"Use this ring\" and set its key."
  end
  return ("On: %d %s with a key."):format(used, used == 1 and "ring" or "rings")
end

function R.RefreshPage()
  if not view.page then
    return
  end
  local combat = not R.CanEdit()
  view.status:SetText(R.StatusText())
  view.combat:SetShown(combat)
  view.list:SetItems(R.Rings())
  local ring = Selected()
  view.list:Refresh()
  local has = ring ~= nil
  for _, control in ipairs({ view.delete, view.key, view.enabled, view.refill, view.try }) do
    control:SetEnabled(not combat and has)
  end
  for _, control in ipairs({ view.radius.less, view.radius.more, view.iconSize.less, view.iconSize.more }) do
    control:SetEnabled(not combat)
  end
  view.add:SetEnabled(not combat and #R.Rings() < R.MAX_RINGS)
  view.delete:SetText(ring and view.confirmDelete == ring.id and "Click to delete" or "Delete")
  if not view.name:HasFocus() then
    view.name:SetText(ring and ring.name or "")
  end
  view.enabled:SetChecked(ring and ring.enabled or false)
  if view.capturing then
    view.key:SetText("Press a key (Escape cancels)")
  else
    view.key:SetText(ring and R.KeyText(ring.key) or "")
  end
  view.conflict:SetText(table.concat(R.KeyConflicts(ring), "\n"))

  local slices = ring and R.Slices(ring) or {}
  for index, slot in ipairs(view.slots) do
    local info = slices[index] and R.Info(slices[index])
    slot.info = info
    if info then
      slot.art:SetTexture(info.icon)
      slot.art:Show()
      slot.back:SetVertexColor(0, 0, 0, 0.9)
      R.Tint(slot, info.missing and "off" or nil)
    else
      slot.art:Hide()
      slot.back:SetVertexColor(0, 0, 0, 0.35)
    end
    slot.ring:SetAlpha(info and 1 or 0.4)
  end
  if ring and ring.auto then
    view.auto:SetText("Filled from what this character knows and carries. Change a slot to make the list "
      .. "your own.")
  elseif ring and ring.preset and R.Preset(ring.preset) and R.Preset(ring.preset).auto then
    view.auto:SetText("Your own list now. \"Fill from what you know\" goes back to the premade one.")
  else
    view.auto:SetText("")
  end
  view.refill:SetShown(ring ~= nil and ring.preset ~= nil)

  -- preview
  local preview = view.preview
  preview.name:SetText(ring and ring.name or "")
  local count = 0
  for index = 1, R.MAX_SLICES do
    local info = slices[index] and R.Info(slices[index])
    if info then
      count = count + 1
    end
  end
  local shown = 0
  for index, icon in ipairs(preview.icons) do
    local info = slices[index] and R.Info(slices[index])
    if info and shown < count then
      shown = shown + 1
      local x, y = R.SlicePosition(shown, count, PREVIEW_RADIUS)
      icon:ClearAllPoints()
      icon:SetPoint("CENTER", preview, "CENTER", x, y)
      icon.art:SetTexture(info.icon)
      icon:Show()
    else
      icon:Hide()
    end
  end

  local db = R.DB()
  view.radius.value:SetText(tostring(db.radius))
  view.iconSize.value:SetText(tostring(db.iconSize))
  view.style:SetChecked(R.PingStyle())
  view.style:SetEnabled(not combat)
end
