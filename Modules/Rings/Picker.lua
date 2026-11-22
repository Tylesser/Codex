local addonName, ns = ...
local R = ns.rings
local UI = ns.UI

-- The slot picker (the user's request, 2026-11-22: "show everything that user can add in UI rather than drag &
-- drop"): a click on a slot opens a small window with every kind of thing a slice can be, a search box and a list;
-- a click in the list puts that thing in the slot. Dragging onto a slot still works (Page.lua). Kinds: your
-- spells (the spellbook, C_SpellBook as Future spells reads it, passives left out), usable items in your bags (an
-- item with a use spell, C_Item.GetItemSpell), mounts (the journal's collected ones, else mount items), toys you
-- own, your macros, raid markers, actions, windows (R.PANELS) and your other rings (rings inside rings). Every
-- game value is read through R.Call / readable checks.

local WIDTH, HEIGHT, ROW = 340, 430, 26
local window

R.CHOICE_KINDS = {
  { key = "spells", name = "Spells" },
  { key = "items", name = "Items in your bags" },
  { key = "mounts", name = "Mounts" },
  { key = "toys", name = "Toys" },
  { key = "macros", name = "Macros" },
  { key = "markers", name = "Raid markers" },
  { key = "actions", name = "Actions" },
  { key = "windows", name = "Windows" },
  { key = "rings", name = "Other rings" },
}

local function Readable(value)
  return R.Readable(value) and value or nil
end

local function Add(list, seen, slice)
  local key = slice.kind .. ":" .. tostring(slice.id)
  if seen[key] then
    return
  end
  seen[key] = true
  local info = R.Info(slice)
  if info and not info.missing then
    list[#list + 1] = { slice = slice, name = info.name or key, icon = info.icon }
  end
end

local function Spells(list, seen)
  local book = C_SpellBook
  if type(book) ~= "table" then
    return
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
  for line = 1, Readable(R.Call(book.GetNumSpellBookSkillLines)) or 0 do
    local info = R.Call(book.GetSpellBookSkillLineInfo, line)
    local offset = type(info) == "table" and Readable(info.itemIndexOffset)
    local count = type(info) == "table" and Readable(info.numSpellBookItems)
    for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
      local item = R.Call(book.GetSpellBookItemInfo, slot, bank)
      local id = type(item) == "table" and Readable(item.spellID)
      if id and Readable(item.itemType) == spellType and Readable(item.isPassive) ~= true then
        Add(list, seen, { kind = "spell", id = id })
      end
    end
  end
end

local function Items(list, seen)
  if not (C_Container and C_Container.GetContainerNumSlots) then
    return
  end
  for bag = 0, 5 do
    for slot = 1, Readable(R.Call(C_Container.GetContainerNumSlots, bag)) or 0 do
      local info = R.Call(C_Container.GetContainerItemInfo, bag, slot)
      local id = type(info) == "table" and Readable(info.itemID)
      if id and C_Item and C_Item.GetItemSpell and Readable(R.Call(C_Item.GetItemSpell, id)) then
        Add(list, seen, { kind = "item", id = id })
      end
    end
  end
end

local function Mounts(list, seen)
  for _, mount in ipairs(R.JournalMounts and R.JournalMounts() or {}) do
    Add(list, seen, { kind = "mount", id = mount.id })
  end
  for _, id in ipairs(R.BagMounts and R.BagMounts() or {}) do
    Add(list, seen, { kind = "item", id = id })
  end
end

local function Toys(list, seen)
  local box = C_ToyBox
  if not (box and box.GetNumFilteredToys and box.GetToyFromIndex) then
    return
  end
  for index = 1, Readable(R.Call(box.GetNumFilteredToys)) or 0 do
    local id = Readable(R.Call(box.GetToyFromIndex, index))
    if id and (not PlayerHasToy or Readable(R.Call(PlayerHasToy, id)) == true) then
      Add(list, seen, { kind = "toy", id = id })
    end
  end
end

local function Macros(list, seen)
  if not (GetNumMacros and GetMacroInfo) then
    return
  end
  local global, own = R.Call(GetNumMacros)
  global, own = Readable(global) or 0, Readable(own) or 0
  local first = MAX_ACCOUNT_MACROS or 120
  local indices = {}
  for index = 1, global do
    indices[#indices + 1] = index
  end
  for index = first + 1, first + own do
    indices[#indices + 1] = index
  end
  for _, index in ipairs(indices) do
    local name = Readable(R.Call(GetMacroInfo, index))
    if type(name) == "string" and name ~= "" then
      Add(list, seen, { kind = "macro", id = name })
    end
  end
end

-- Everything of one kind that `ring` can take, sorted by name (markers, actions and windows in their own order).
function R.Choices(kind, ring)
  local list, seen = {}, {}
  if kind == "spells" then
    Spells(list, seen)
  elseif kind == "items" then
    Items(list, seen)
  elseif kind == "mounts" then
    Mounts(list, seen)
  elseif kind == "toys" then
    Toys(list, seen)
  elseif kind == "macros" then
    Macros(list, seen)
  elseif kind == "markers" then
    for marker = 1, 8 do
      Add(list, seen, { kind = "marker", id = marker })
    end
    Add(list, seen, { kind = "action", id = "clearmark" })
    return list
  elseif kind == "actions" then
    for _, id in ipairs(R.ACTION_ORDER) do
      if id ~= "clearmark" then
        Add(list, seen, { kind = "action", id = id })
      end
    end
    return list
  elseif kind == "windows" then
    for _, id in ipairs(R.PANEL_ORDER) do
      if R.PanelAvailable(id) then
        Add(list, seen, { kind = "action", id = id })
      end
    end
    return list
  elseif kind == "rings" then
    for _, other in ipairs(R.Rings()) do
      if not ring or tostring(other.id) ~= tostring(ring.id) then
        Add(list, seen, { kind = "ring", id = other.id })
      end
    end
  end
  table.sort(list, function(a, b)
    return tostring(a.name):lower() < tostring(b.name):lower()
  end)
  return list
end

-- The window -------------------------------------------------------------------------------------------------------

local function KindName(key)
  for _, kind in ipairs(R.CHOICE_KINDS) do
    if kind.key == key then
      return kind.name
    end
  end
  return key
end

local function Fill()
  local ring = window.ring and R.Find(window.ring)
  local all = R.Choices(window.kind, ring)
  local search = (window.search:GetText() or ""):lower()
  local shown = {}
  for _, entry in ipairs(all) do
    if search == "" or tostring(entry.name):lower():find(search, 1, true) then
      shown[#shown + 1] = entry
    end
  end
  window.list:SetItems(shown)
  window.kindPicker:SetText(KindName(window.kind))
  window.empty:SetShown(#shown == 0)
  window.empty:SetText(#all == 0 and "Nothing of this kind on this character yet." or "Nothing matches the search.")
  window.clear:SetShown(ring ~= nil and R.Slices(ring)[window.index] ~= nil)
  window.title:SetText(("Slot %d of %s"):format(window.index or 1, ring and ring.name or "the ring"))
end

local function Choose(entry)
  local ring = window.ring and R.Find(window.ring)
  if not (ring and entry) then
    return
  end
  local index = window.index
  R.Edit(ring, function()
    return R.SetSlice(ring, index, entry.slice)
  end)
  window:Hide()
end

local function Build()
  window = CreateFrame("Frame", "CodexRingPicker", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  UI.Panel(window, { cornerSize = 12 })
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "CodexRingPicker")
  end
  window.title = UI.Heading(window, "Slot", 15)
  window.title:SetPoint("TOPLEFT", 16, -14)
  window.title:SetPoint("RIGHT", -40, 0)
  window.title:SetJustifyH("LEFT")
  local close = UI.CloseButton(window)
  close:SetPoint("TOPRIGHT", -10, -10)

  window.kindPicker = UI.Picker(window, WIDTH - 32, 24)
  window.kindPicker:SetPoint("TOPLEFT", 16, -44)
  window.kindPicker:SetScript("OnClick", function(self)
    local items = {}
    for _, kind in ipairs(R.CHOICE_KINDS) do
      items[#items + 1] = { text = kind.name, checked = window.kind == kind.key, func = function()
        window.kind = kind.key
        window.list.offset = 0
        Fill()
      end }
    end
    UI.ShowMenu(self, items)
  end)
  window.search = UI.EditBox(window, WIDTH - 32, 24)
  window.search:SetPoint("TOPLEFT", window.kindPicker, "BOTTOMLEFT", 0, -8)
  window.search:SetScript("OnTextChanged", function()
    window.list.offset = 0
    Fill()
  end)
  local hint = UI.Text(window.search, "body", 12, "muted")
  hint:SetPoint("LEFT", 8, 0)
  hint:SetText("Search")
  window.search:HookScript("OnTextChanged", function(self)
    hint:SetShown((self:GetText() or "") == "")
  end)

  window.list = UI.List(window, {
    rowHeight = ROW,
    CreateRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(ROW - 6, ROW - 6)
      row.icon:SetPoint("LEFT", 4, 0)
      if row.icon.SetTexCoord then
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      row.name = UI.Text(row, "body", 13, "text")
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
      row.name:SetPoint("RIGHT", -6, 0)
      row.name:SetJustifyH("LEFT")
      row.name:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        Choose(self.item)
      end)
    end,
    UpdateRow = function(row, item)
      row.icon:SetTexture(item.icon)
      row.name:SetText(item.name)
    end,
  })
  window.list:SetPoint("TOPLEFT", window.search, "BOTTOMLEFT", 0, -8)
  window.list:SetPoint("BOTTOMRIGHT", -16, 46)
  window.list:EnableMouseWheel(true)
  window.list:SetScript("OnMouseWheel", function(self, delta)
    self.offset = self.offset - delta * 3
    self:Refresh()
  end)
  window.empty = UI.Text(window.list, "body", 12, "muted")
  window.empty:SetPoint("TOP", 0, -16)
  window.empty:SetWidth(WIDTH - 60)

  window.clear = UI.Button(window, 130, 24, "Clear this slot")
  window.clear:SetPoint("BOTTOMLEFT", 16, 14)
  window.clear:SetScript("OnClick", function()
    local ring = window.ring and R.Find(window.ring)
    if ring then
      local index = window.index
      R.Edit(ring, function()
        return R.SetSlice(ring, index, nil)
      end)
    end
    window:Hide()
  end)
  local tip = UI.Text(window, "body", 11, "muted")
  tip:SetPoint("BOTTOMRIGHT", -16, 20)
  tip:SetText("Dragging onto a slot works too.")
  window:Hide()
end

-- Opens the picker for slot `index` of `ring`, beside `anchor` (the slot).
function R.OpenPicker(anchor, ring, index)
  if not ring then
    return
  end
  if not window then
    Build()
  end
  window.ring, window.index = ring.id, index
  window.kind = window.kind or "spells"
  window.search:SetText("")
  window.list.offset = 0
  window:ClearAllPoints()
  if anchor then
    window:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 10, 0)
  else
    window:SetPoint("CENTER")
  end
  window:Show()
  Fill()
end

function R.ClosePicker()
  if window then
    window:Hide()
  end
end
