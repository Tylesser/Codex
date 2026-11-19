local addonName, ns = ...

-- Rings: saved data, what a slice is, and the premade rings. Nothing here creates frames or registers events.
--
-- CodexDB.rings (account wide; no per-character copies):
--   radius, iconSize        the ring's size (settings)
--   nextID                  the next ring id (ids are never reused: the secure frames are keyed by them)
--   list = { ring, ... }    in the order shown on the page
-- ring = { id, name, enabled, key = "SHIFT-F" or nil, auto = "mounts" / "travel" / "professions" or nil,
--          preset = the premade ring it came from or nil, slices = { slice, ... } }
-- slice = { kind = "spell" / "item" / "macro" / "mount" / "marker" / "toy" / "action", id = number or string }
--   spell id = spell ID, item / toy id = item ID, macro id = the macro's name, mount id = mount ID (mount
--   journal), marker id = 1..8 (raid target icons), action id = a key of R.ACTIONS.
-- A ring with `auto` fills its slices from what the character knows and carries each time it is built (so the
-- premade rings suit every character); changing a slot copies that list into `slices` and drops `auto`.

local R = {}
ns.rings = R

R.MAX_SLICES = 12
R.MAX_RINGS = 10
R.RADIUS = { min = 60, max = 160, step = 10 }
R.ICON = { min = 28, max = 56, step = 4 }

local DEFAULTS = { radius = 100, iconSize = 40, nextID = 1, list = {}, style = "ping" }

-- The attributes a slice may set on a secure action button (the ring's button copies these on release).
R.ATTR_KEYS = { "type", "spell", "item", "macro", "macrotext", "marker", "action", "unit", "toy" }

-- Readable values only (Forever has secret values) ------------------------------------------------------------

function R.Readable(value)
  if value == nil then
    return false
  end
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end

local function Results(ok, ...)
  if not ok then
    return nil
  end
  return ...
end

-- fn(...) caught; every result, or nothing when it failed.
function R.Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return Results(pcall(fn, ...))
end

local function Plain(value)
  return R.Readable(value) and value or nil
end

-- Saved data ----------------------------------------------------------------------------------------------------

function R.DB()
  if not R.db or R.db ~= ns.db.rings then
    ns.db.rings = ns.Fill(type(ns.db.rings) == "table" and ns.db.rings or {}, DEFAULTS)
    R.db = ns.db.rings
    if not R.db.presets then
      R.db.presets = true
      for _, preset in ipairs(R.PRESETS) do
        R.AddRing(preset.name, preset)
      end
    end
  end
  return R.db
end

function R.Rings()
  return R.DB().list
end

function R.Find(id)
  for index, ring in ipairs(R.Rings()) do
    if ring.id == id then
      return ring, index
    end
  end
end

-- By name, ignoring case ("/codex ring mounts").
function R.FindByName(name)
  name = strtrim(tostring(name or "")):lower()
  for _, ring in ipairs(R.Rings()) do
    if ring.name:lower() == name then
      return ring
    end
  end
end

function R.AddRing(name, preset)
  local db = R.DB()
  if #db.list >= R.MAX_RINGS then
    return nil
  end
  local ring = { id = db.nextID, name = name or ("Ring " .. db.nextID), enabled = false, slices = {} }
  db.nextID = db.nextID + 1
  if preset then
    ring.preset = preset.id
    ring.auto = preset.auto
    for _, slice in ipairs(preset.slices or {}) do
      ring.slices[#ring.slices + 1] = { kind = slice.kind, id = slice.id }
    end
  end
  table.insert(db.list, ring)
  return ring
end

function R.RemoveRing(id)
  local ring, index = R.Find(id)
  if ring then
    table.remove(R.Rings(), index)
  end
  return ring
end

-- Slices --------------------------------------------------------------------------------------------------------

local MARKER_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
R.MARKER_NAMES = MARKER_NAMES

function R.MarkerName(index)
  local name = _G["RAID_TARGET_" .. index]
  return (type(name) == "string" and name ~= "") and name or MARKER_NAMES[index] or ("Marker " .. index)
end

-- Built-in actions: { name, icon, attrs }.
R.ACTIONS = {
  clearmark = { name = "Clear the target's marker", icon = "Interface\\Buttons\\UI-StopButton",
    attrs = { type = "raidtarget", action = "clear", unit = "target" } },
  dismount = { name = "Dismount", icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
    attrs = { type = "macro", macrotext = "/dismount" } },
  sit = { name = "Sit or stand", icon = "Interface\\Icons\\Spell_Nature_Sleep",
    attrs = { type = "macro", macrotext = "/sit" } },
  stopcasting = { name = "Stop casting", icon = "Interface\\Icons\\Spell_Holy_Silence",
    attrs = { type = "macro", macrotext = "/stopcasting" } },
  cancelform = { name = "Leave your form", icon = "Interface\\Icons\\Ability_Druid_CatForm",
    attrs = { type = "macro", macrotext = "/cancelform" } },
}
R.ACTION_ORDER = { "clearmark", "dismount", "sit", "stopcasting", "cancelform" }

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function SpellName(id)
  local name = C_Spell and C_Spell.GetSpellName and Plain(R.Call(C_Spell.GetSpellName, id))
  if not name and C_Spell and C_Spell.GetSpellInfo then
    local info = R.Call(C_Spell.GetSpellInfo, id)
    name = type(info) == "table" and Plain(info.name) or nil
  end
  if not name and GetSpellInfo then
    name = Plain(R.Call(GetSpellInfo, id))
  end
  return name
end
R.SpellName = SpellName

local function SpellIcon(id)
  local icon = C_Spell and C_Spell.GetSpellTexture and Plain(R.Call(C_Spell.GetSpellTexture, id))
  if not icon and C_Spell and C_Spell.GetSpellInfo then
    local info = R.Call(C_Spell.GetSpellInfo, id)
    icon = type(info) == "table" and Plain(info.iconID) or nil
  end
  return icon
end

local function ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and Plain(R.Call(C_Item.GetItemNameByID, id))
  if not name and C_Item and C_Item.GetItemInfo then
    name = Plain(R.Call(C_Item.GetItemInfo, id))
  end
  return name
end

local function ItemIcon(id)
  local icon = C_Item and C_Item.GetItemIconByID and Plain(R.Call(C_Item.GetItemIconByID, id))
  if not icon and C_Item and C_Item.GetItemInfoInstant then
    icon = Plain(select(5, R.Call(C_Item.GetItemInfoInstant, id)))
  end
  return icon
end

function R.ItemCount(id)
  local count = (C_Item and C_Item.GetItemCount) or GetItemCount
  local value = R.Call(count, id)
  return R.Readable(value) and type(value) == "number" and value or 0
end

local function MountInfo(id)
  if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then
    return nil
  end
  local name, spellID, icon, _, isUsable, _, isFavorite, _, _, hideOnChar, isCollected =
    R.Call(C_MountJournal.GetMountInfoByID, id)
  if not Plain(name) then
    return nil
  end
  return { name = name, spellID = Plain(spellID), icon = Plain(icon), usable = isUsable and true or false,
    favorite = isFavorite and true or false, hidden = hideOnChar and true or false,
    collected = isCollected and true or false }
end
R.MountInfo = MountInfo

-- What a slice shows and does: { name, icon, attrs, spell = id, item = id } (nil for a slice it can't use).
function R.Info(slice)
  if type(slice) ~= "table" then
    return nil
  end
  local kind, id = slice.kind, slice.id
  if kind == "spell" then
    local name = SpellName(id)
    return { name = name or ("Spell " .. tostring(id)), icon = SpellIcon(id) or QUESTION, spell = id,
      attrs = { type = "spell", spell = name or id } }
  elseif kind == "item" then
    return { name = ItemName(id) or ("Item " .. tostring(id)), icon = ItemIcon(id) or QUESTION, item = id,
      attrs = { type = "item", item = "item:" .. tostring(id) } }
  elseif kind == "toy" then
    local name, icon
    if C_ToyBox and C_ToyBox.GetToyInfo then
      local _, toyName, toyIcon = R.Call(C_ToyBox.GetToyInfo, id)
      name, icon = Plain(toyName), Plain(toyIcon)
    end
    return { name = name or ItemName(id) or ("Toy " .. tostring(id)), icon = icon or ItemIcon(id) or QUESTION,
      item = id, attrs = { type = "toy", toy = id } }
  elseif kind == "macro" then
    local name, icon = R.Call(GetMacroInfo, id)
    if not Plain(name) then
      return { name = tostring(id) .. " (macro gone)", icon = QUESTION, missing = true, attrs = {} }
    end
    return { name = name, icon = Plain(icon) or QUESTION, attrs = { type = "macro", macro = name } }
  elseif kind == "mount" then
    local info = MountInfo(id)
    if not (info and info.spellID) then
      return { name = "Mount " .. tostring(id), icon = QUESTION, missing = true, attrs = {} }
    end
    return { name = info.name, icon = info.icon or SpellIcon(info.spellID) or QUESTION, spell = info.spellID,
      attrs = { type = "spell", spell = info.spellID } }
  elseif kind == "marker" then
    local index = tonumber(id) or 1
    return { name = R.MarkerName(index), icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index,
      marker = index, attrs = { type = "raidtarget", marker = index, action = "toggle", unit = "target" } }
  elseif kind == "action" then
    local action = R.ACTIONS[id]
    if not action then
      return nil
    end
    local attrs = {}
    for key, value in pairs(action.attrs) do
      attrs[key] = value
    end
    return { name = action.name, icon = action.icon, attrs = attrs }
  end
  return nil
end

-- The slice on the game's cursor (dragged from the spellbook, bags, macro window or mount journal), or nil.
function R.FromCursor()
  local kind, a, b, c = R.Call(GetCursorInfo)
  if kind == "spell" then
    local spellID = type(c) == "number" and c or nil
    if not spellID and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
      local info = R.Call(C_SpellBook.GetSpellBookItemInfo, a, b)
      spellID = type(info) == "table" and Plain(info.spellID) or nil
    end
    return spellID and { kind = "spell", id = spellID } or nil
  elseif kind == "item" and type(a) == "number" then
    if C_ToyBox and C_ToyBox.GetToyInfo and R.Call(C_ToyBox.GetToyInfo, a) and PlayerHasToy
      and R.Call(PlayerHasToy, a) then
      return { kind = "toy", id = a }
    end
    return { kind = "item", id = a }
  elseif kind == "toy" and type(a) == "number" then
    return { kind = "toy", id = a }
  elseif kind == "macro" then
    local name = Plain(R.Call(GetMacroInfo, a))
    return name and { kind = "macro", id = name } or nil
  elseif kind == "mount" and type(a) == "number" then
    return MountInfo(a) and { kind = "mount", id = a } or nil
  end
  return nil
end

-- Premade rings -------------------------------------------------------------------------------------------------

local function Known(spellID)
  for _, test in ipairs({ C_SpellBook and C_SpellBook.IsSpellKnown or false, IsPlayerSpell or false,
    IsSpellKnown or false }) do
    if test and R.Call(test, spellID) == true then
      return true
    end
  end
  return false
end
R.Known = Known

-- The first known spell of a list (the ranks of one profession).
local function FirstKnown(ids)
  for index = #ids, 1, -1 do
    if Known(ids[index]) then
      return ids[index]
    end
  end
end

local function AddSpell(list, ids)
  local id = FirstKnown(type(ids) == "table" and ids or { ids })
  if id and #list < R.MAX_SLICES then
    list[#list + 1] = { kind = "spell", id = id }
  end
end

local function AddItem(list, id)
  if R.ItemCount(id) > 0 and #list < R.MAX_SLICES then
    list[#list + 1] = { kind = "item", id = id }
  end
end

-- Spells that open a profession (every rank), then the tracking spells used while gathering.
R.PROFESSION_SPELLS = {
  { 2259, 3101, 3464, 11611 }, -- Alchemy
  { 2018, 3100, 3538, 9785 }, -- Blacksmithing
  { 7411, 7412, 7413, 13920 }, -- Enchanting
  { 4036, 4037, 4038, 12656 }, -- Engineering
  { 2108, 3104, 3811, 10662 }, -- Leatherworking
  { 3908, 3909, 3910, 12180 }, -- Tailoring
  { 2656 }, -- Smelting (Mining)
  { 2550, 3102, 3413, 18260 }, -- Cooking
  { 3273, 3274, 7924, 10846 }, -- First Aid
  { 7620, 7731, 7732, 18248 }, -- Fishing
  { 13262 }, -- Disenchant
  { 2842 }, -- Poisons
  { 2383 }, -- Find Herbs
  { 2580 }, -- Find Minerals
  { 2481 }, -- Find Treasure
}

R.TRAVEL_ITEMS = { 6948, 18986, 18984 } -- Hearthstone, Ultrasafe Transporter: Gadgetzan, Dimensional Ripper - Everlook
R.TRAVEL_SPELLS = {
  556, -- Astral Recall
  18960, -- Teleport: Moonglade
  3561, 3562, 3565, 3567, 3563, 3566, -- Teleport: Stormwind, Ironforge, Darnassus, Orgrimmar, Undercity, Thunder Bluff
  10059, 11416, 11419, 11417, 11418, 11420, -- the same cities' portals
}

-- Class spells that are a mount or move you faster: Warhorse, Charger, Felsteed, Dreadsteed, Ghost Wolf, Travel
-- Form, Aquatic Form, Aspect of the Cheetah, Aspect of the Pack.
R.MOUNT_SPELLS = { 13819, 23214, 5784, 23161, 2645, 783, 1066, 5118, 13159 }

local MOUNT_CLASS, MOUNT_SUBCLASS = 15, 5 -- Miscellaneous > Mount

-- Mount items in the bags (Classic mounts are items), by item ID.
local function BagMounts()
  local found, seen = {}, {}
  if not (C_Container and C_Container.GetContainerNumSlots and C_Item and C_Item.GetItemInfoInstant) then
    return found
  end
  for bag = 0, 4 do
    for slot = 1, (R.Call(C_Container.GetContainerNumSlots, bag) or 0) do
      local info = R.Call(C_Container.GetContainerItemInfo, bag, slot)
      local itemID = type(info) == "table" and Plain(info.itemID) or nil
      if itemID and not seen[itemID] then
        seen[itemID] = true
        local _, _, _, _, _, classID, subclassID = R.Call(C_Item.GetItemInfoInstant, itemID)
        if classID == MOUNT_CLASS and subclassID == MOUNT_SUBCLASS then
          found[#found + 1] = itemID
        end
      end
    end
  end
  return found
end

-- Collected mounts from the mount journal (favourites first), when Forever's journal has any.
local function JournalMounts()
  local list = {}
  if not (C_MountJournal and C_MountJournal.GetMountIDs) then
    return list
  end
  local ids = R.Call(C_MountJournal.GetMountIDs)
  for _, id in ipairs(type(ids) == "table" and ids or {}) do
    local info = MountInfo(id)
    if info and info.collected and not info.hidden and info.spellID then
      info.id = id
      list[#list + 1] = info
    end
  end
  table.sort(list, function(a, b)
    if a.favorite ~= b.favorite then
      return a.favorite
    end
    return a.name < b.name
  end)
  return list
end

R.AUTO = {
  mounts = function()
    local list = {}
    for _, info in ipairs(JournalMounts()) do
      if #list < R.MAX_SLICES then
        list[#list + 1] = { kind = "mount", id = info.id }
      end
    end
    for _, itemID in ipairs(BagMounts()) do
      AddItem(list, itemID)
    end
    for _, id in ipairs(R.MOUNT_SPELLS) do
      AddSpell(list, id)
    end
    return list
  end,
  travel = function()
    local list = {}
    for _, id in ipairs(R.TRAVEL_ITEMS) do
      AddItem(list, id)
    end
    for _, id in ipairs(R.TRAVEL_SPELLS) do
      AddSpell(list, id)
    end
    return list
  end,
  professions = function()
    local list = {}
    for _, ids in ipairs(R.PROFESSION_SPELLS) do
      AddSpell(list, ids)
    end
    return list
  end,
}

local MARKERS = {}
for index = 1, 8 do
  MARKERS[index] = { kind = "marker", id = index }
end
MARKERS[9] = { kind = "action", id = "clearmark" }

R.PRESETS = {
  { id = "mounts", name = "Mounts", auto = "mounts" },
  { id = "travel", name = "Travel", auto = "travel" },
  { id = "professions", name = "Professions", auto = "professions" },
  { id = "markers", name = "Markers", slices = MARKERS },
}

function R.Preset(id)
  for _, preset in ipairs(R.PRESETS) do
    if preset.id == id then
      return preset
    end
  end
end

-- The slices a ring has now (an `auto` ring: built from what this character knows).
function R.Slices(ring)
  if ring.auto and R.AUTO[ring.auto] then
    local ok, list = pcall(R.AUTO[ring.auto])
    return ok and list or {}
  end
  return ring.slices
end

-- An `auto` ring becomes a plain list (before the player changes a slot).
function R.MakeOwn(ring)
  if ring.auto then
    ring.slices = R.Slices(ring)
    ring.auto = nil
  end
end

-- Puts the premade list back (an `auto` ring fills itself again).
function R.Refill(ring)
  local preset = ring.preset and R.Preset(ring.preset)
  if not preset then
    return false
  end
  ring.auto = preset.auto
  ring.slices = {}
  for _, slice in ipairs(preset.slices or {}) do
    ring.slices[#ring.slices + 1] = { kind = slice.kind, id = slice.id }
  end
  return true
end

-- Slots on the page are 1..MAX_SLICES; a ring's slices are packed (no gaps) in the order of its slots.
function R.SetSlice(ring, index, slice)
  R.MakeOwn(ring)
  local list = ring.slices
  if slice then
    if index > #list then
      index = #list + 1
    end
    if index > R.MAX_SLICES then
      return false
    end
    list[index] = { kind = slice.kind, id = slice.id }
  elseif list[index] then
    table.remove(list, index)
  end
  return true
end

-- Moves a slice to another slot (swapping with the one there).
function R.MoveSlice(ring, from, to)
  R.MakeOwn(ring)
  local list = ring.slices
  if not list[from] or from == to then
    return false
  end
  if to > #list then
    to = #list
  end
  list[from], list[to] = list[to], list[from]
  return true
end

-- Which slice points at (dx, dy) from the ring's centre: slice 1 at the top, the rest clockwise, each owning an
-- equal wedge; nil inside the dead zone and outside the ring (beyond `outer`). The restricted snippet (Secure.lua)
-- does the same sums.
function R.PickIndex(dx, dy, count, deadzone, outer)
  local distance = dx * dx + dy * dy
  if not count or count < 1 or distance < deadzone * deadzone or (outer and distance > outer * outer) then
    return nil
  end
  local step = 360 / count
  local angle = math.deg((math.atan2 or math.atan)(dy, dx))
  local around = (90 - angle) % 360
  return math.floor(around / step + 0.5) % count + 1
end

-- Where slice `index` of `count` sits, as an offset from the centre.
function R.SlicePosition(index, count, radius)
  local angle = math.rad(90 - (index - 1) * 360 / count)
  return math.cos(angle) * radius, math.sin(angle) * radius
end

function R.DeadZone()
  return math.max(16, math.floor(R.DB().radius * 0.3))
end

-- Letting go further out than this (well past the icons) uses nothing.
function R.OuterLimit()
  local db = R.DB()
  return db.radius + 2 * db.iconSize
end
