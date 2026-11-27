local addonName, ns = ...
local L = ns.L

-- Bags module, part 3: the Codex bag window. Your own bags are real item buttons (the game's
-- ContainerFrameItemButtonTemplate under holder frames whose ID is the bag), so clicking, using, dragging and
-- splitting run the game's own code. Another character's bags, or a bank, are plain read-only icons.
-- Buttons are made, placed, shown and hidden only out of combat: during a fight the window updates the
-- buttons it already shows (icon, count, cooldown, lock) and lays itself out again after the fight.

local B = ns.bags
local UI = ns.UI
local T = ns.T

-- Sizes follow the round-2 board (R2-Bags): 40px items 6px apart, rows of sections 10px apart, 12px
-- headings with 5px under them, a 36px title bar, a 28px search row, a 34px footer band, 16px sides.
-- Sections side by side (B.Pack, option "pack") sit on the same cell grid, one item spacing apart.
-- Item size and spacing come from the options (Data.lua), read at every layout.
local SIZE, SPACING, GAP = 40, 6, 10 -- item button, space between items, space between rows of sections
local CELL = SIZE + SPACING
local HEADING = 21   -- a section heading (16) and the space under it (5)
local PAD = 16
local TITLE = 36
local ROW = 28       -- search box and icon buttons
local FOOT = 34 + 5 + 12 -- footer band, its inset, space above it
local COUNT_FONT = "Fonts\\ARIALN.TTF"

local view = { key = nil, bank = false, search = "" } -- key nil = this character
B.view = view

local frame
-- A set of live buttons: holder frames (ID = bag) under set.frame, buttons[bag][slot]. The bag window has
-- one (B.live), the bank window another (Bank.lua).
local live = { buttons = {}, holders = {} }
local made = 0 -- item buttons made, over every set (their names)
local saved = { buttons = {} }
local headings = { list = {} }

B.live = live

-- The current sizes: item, item spacing, row spacing, cell, heading, sides, title bar, search row, footer.
function B.Sizes()
  return SIZE, SPACING, GAP, CELL, HEADING, PAD, TITLE, ROW, FOOT
end

local function Theme()
  return ns.Theme()
end

local function Call(object, method, ...)
  local fn = object[method]
  if type(fn) == "function" then
    pcall(fn, object, ...)
  end
end

local function CallGlobal(name, ...)
  local fn = _G[name]
  if type(fn) == "function" then
    pcall(fn, ...)
  end
end

local function QualityColor(quality)
  return ns.QualityColor(quality)
end

-- Slot look -------------------------------------------------------------------------------------------------

-- The theme's slot (dark fill, slot rings) on an item button, and a quality ring for uncommon and better.
local function SlotLook(button, icon)
  local slot = Theme().slot
  if type(icon) == "table" and icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if normal then
    normal:SetAlpha(0)
  end
  if type(button.IconBorder) == "table" then
    button.IconBorder:SetAlpha(0) -- the quality ring below takes its place
  end
  local text = Theme().text
  local edge = slot.rings and slot.rings[1] and slot.rings[1].color or Theme().divider
  local radius = UI.Radius("slot", Theme())
  if radius then
    -- rounded (Dusk, Dawn): fill, rings, empty look and the 2 px quality ring as rounded pieces (they take
    -- SetColorTexture like lines), the icon and its hover / pushed art cut by a rounded mask
    button.codexFillPieces = UI.RoundFill(button, button, radius, slot.fill, { sublevel = -8 })
    button.codexFill = button.codexFillPieces.middle
    button.codexRings = { UI.RoundLine(button, button, radius, (slot.rings[1] or {}).color or edge,
      { layer = "OVERLAY", sublevel = 1 }) }
    button.codexEmptyPieces = UI.RoundFill(button, button, radius, { text[1], text[2], text[3], 0.07 }, { sublevel = -8 })
    button.codexEmpty = button.codexEmptyPieces.middle
    button.codexEmptyLine = UI.RoundLine(button, button, radius, { edge[1], edge[2], edge[3], 0.4 },
      { layer = "OVERLAY", sublevel = 1 })
    local quality = UI.RoundLine(button, button, radius, { 1, 1, 1 }, { layer = "OVERLAY", sublevel = 2 })
    for _, piece in ipairs(UI.RoundLine(button, button, radius - 1, { 1, 1, 1 }, { inset = 1, layer = "OVERLAY", sublevel = 2 })) do
      quality[#quality + 1] = piece
    end
    button.codexQuality = quality
    -- ItemButton already masks its icon, normal and pushed art with its own `Mask` (common-iconmask,
    -- ItemButtonMixin:OnLoad on Forever); a second, nine-sliced mask on the same icon drew it as a few specks on
    -- black (in game, 2026-11-19), so the game's mask comes off first, as on the action buttons
    if type(button.Mask) == "table" then
      for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local ok, texture = pcall(button[getter] or function() end, button)
        if ok and type(texture) == "table" and texture.RemoveMaskTexture then
          pcall(texture.RemoveMaskTexture, texture, button.Mask)
        end
      end
      if type(icon) == "table" and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, button.Mask)
      end
    end
    local textures = { icon }
    for _, getter in ipairs({ "GetHighlightTexture", "GetPushedTexture" }) do
      local ok, texture = pcall(button[getter] or function() end, button)
      textures[#textures + 1] = ok and texture or nil
    end
    button.codexIconMask = UI.RoundMask(button, icon or button, radius, textures)
  else
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints()
    UI.SetColor(fill, slot.fill)
    button.codexFill = fill
    button.codexRings = UI.Rings(button, slot.rings, "OVERLAY", 1)
    -- an empty slot is light and see-through (board tokens "empty" = text colour at 7%, "emptyLine" = the slot's
    -- outer ring colour at 40%); no theme token for them yet
    button.codexEmpty = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    button.codexEmpty:SetAllPoints()
    button.codexEmpty:SetColorTexture(text[1], text[2], text[3], 0.07)
    button.codexEmptyLine = T.Outline(button, 0, edge, 1, "OVERLAY", 1)
    T.ColorLines(button.codexEmptyLine, edge, 0.4)
    button.codexQuality = T.Outline(button, 0, { 1, 1, 1 }, 2, "OVERLAY", 2)
  end
  for _, line in ipairs(button.codexQuality) do
    line:Hide()
  end
  -- every count is ours: 11px, bottom right, kept inside the slot (the game's own count is left empty)
  local count = button:CreateFontString(nil, "OVERLAY", nil, 7)
  if not count:SetFont(COUNT_FONT, 11, "OUTLINE") then
    count:SetFont((STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), 10, "OUTLINE")
  end
  count:SetTextColor(1, 1, 1)
  count:SetJustifyH("RIGHT")
  count:SetWordWrap(false)
  count:SetPoint("BOTTOMRIGHT", -3, 2)
  count:SetPoint("LEFT", 2, 0)
  count:Hide()
  button.codexCount = count
end
B.SlotLook = SlotLook

local function SetEmpty(button, empty)
  for _, piece in ipairs(button.codexFillPieces or { button.codexFill }) do
    piece:SetShown(not empty)
  end
  for _, piece in ipairs(button.codexEmptyPieces or { button.codexEmpty }) do
    piece:SetShown(empty)
  end
  for _, lines in ipairs(button.codexRings or {}) do
    for _, line in ipairs(lines) do
      line:SetShown(not empty)
    end
  end
  for _, line in ipairs(button.codexEmptyLine) do
    line:SetShown(empty)
  end
end
B.SetEmpty = SetEmpty

-- "49", "1.2k": always short enough for the slot.
local function CountText(count)
  if count >= 10000 then
    return ("%dk"):format(math.floor(count / 1000))
  elseif count >= 1000 then
    return (("%.1fk"):format(math.floor(count / 100) / 10):gsub("%.0k", "k"))
  end
  return tostring(count)
end
B.CountText = CountText

local function SetCount(button, count)
  local show = count ~= nil and count > 1
  button.codexCount:SetShown(show)
  if show then
    button.codexCount:SetText(CountText(count))
  end
end
B.SetCount = SetCount

local function SetQuality(button, quality)
  local color = quality and quality >= 2 and QualityColor(quality)
  for _, line in ipairs(button.codexQuality) do
    if color then
      line:SetColorTexture(color[1], color[2], color[3], 1)
      line:Show()
    else
      line:Hide()
    end
  end
end
B.SetQuality = SetQuality

-- "N in your bags (M stacks)" under a combined button's item tooltip.
-- A Free box's tooltip: which bags its count is for (2026-11-24, the user: "can't understand which free is the
-- real bag and which the reagent bag").
function B.FreeTooltip(button)
  local count = button.codexFreeCount
  if count == nil or not button.codexFree:IsShown() then
    return
  end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  if button.codexFreeKind == "reagent" then
    GameTooltip:SetText(count == 1 and L["1 free slot in your reagent bag"] or L["%d free slots in your reagent bag"]:format(count))
    GameTooltip:AddLine(L["Only reagents go in there."], 0.6, 0.6, 0.6, true)
  else
    GameTooltip:SetText(count == 1 and L["1 free slot in your bags"] or L["%d free slots in your bags"]:format(count))
  end
  GameTooltip:Show()
end

function B.AddStacksLine(button)
  local stacks = button.codexStacks
  if not stacks or stacks < 2 or not GameTooltip:IsOwned(button) then
    return
  end
  local text = button.codexSaved and L["%d here (%d stacks)"] or L["%d in your bags (%d stacks)"]
  GameTooltip:AddLine(text:format(button.codexTotal or 0, stacks), 0.6, 0.8, 1)
  GameTooltip:Show()
end

-- Live buttons ----------------------------------------------------------------------------------------------

-- A new, empty set of live buttons under parent (made out of combat).
function B.NewLiveSet(parent, name)
  local set = { buttons = {}, holders = {} }
  set.frame = CreateFrame("Frame", name, parent)
  set.frame:SetAllPoints()
  return set
end

local function Holder(set, bagID)
  local holder = set.holders[bagID]
  if not holder then
    holder = CreateFrame("Frame", nil, set.frame)
    holder:SetAllPoints()
    holder:SetID(bagID)
    set.holders[bagID] = holder
  end
  return holder
end

-- The button of a bag slot in a set; made only out of combat (nil in combat when it doesn't exist yet).
local function LiveButton(set, bagID, slot)
  local list = set.buttons[bagID]
  if not list then
    list = {}
    set.buttons[bagID] = list
  end
  local button = list[slot]
  if button or InCombatLockdown() then
    return button
  end
  made = made + 1
  button = CreateFrame("ItemButton", "CodexBagsItem" .. made, Holder(set, bagID), "ContainerFrameItemButtonTemplate")
  button:SetID(slot)
  button:SetSize(SIZE, SIZE)
  local icon = rawget(button, "icon") or button.icon
  if type(icon) ~= "table" then
    icon = _G["CodexBagsItem" .. made .. "IconTexture"]
  end
  SlotLook(button, icon)
  -- the Free box: the count over a small "free" (board: 15px bright, 10px muted)
  button.codexFree = UI.Text(button, "body", 15, "bright", "OVERLAY")
  button.codexFree:SetPoint("TOP", 0, -5)
  button.codexFreeLabel = UI.Text(button, "body", 10, "muted", "OVERLAY")
  button.codexFreeLabel:SetPoint("TOP", button.codexFree, "BOTTOM", 0, -1)
  button.codexFreeLabel:SetText(L["free##bags"])
  button.codexFree:Hide()
  button.codexFreeLabel:Hide()
  button:HookScript("OnEnter", B.AddStacksLine)
  button:HookScript("OnEnter", B.FreeTooltip)
  button:Hide()
  list[slot] = button
  return button
end

-- Every slot of the bags (default: the carried bags, in the bag window's set) gets its button now, so the
-- window can open in combat. True when every slot has one.
function B.EnsureButtons(set, bags)
  set = set or live
  if not set.frame or InCombatLockdown() then
    return false
  end
  for _, bagID in ipairs(bags or B.CarriedBags()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) or 0 do
      LiveButton(set, bagID, slot)
    end
  end
  return true
end

-- Does every slot of these bags have its button in the set?
function B.HasButtons(set, bags)
  for _, bagID in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) or 0 do
      if not (set.buttons[bagID] and set.buttons[bagID][slot]) then
        return false
      end
    end
  end
  return true
end

-- What the game's own bag update does for one button, done on ours.
local function FillLive(button, bagID, slot)
  local info = C_Container.GetContainerItemInfo(bagID, slot)
  local texture = info and info.iconFileID
  Call(button, "SetHasItem", texture)
  CallGlobal("SetItemButtonTexture", button, texture)
  -- the game's count stays empty; ours shows the stack, or a combined button's total
  CallGlobal("SetItemButtonCount", button, 0)
  SetCount(button, info and (button.codexTotal or info.stackCount) or nil)
  SetEmpty(button, not info)
  CallGlobal("SetItemButtonDesaturated", button, info and info.isLocked)
  Call(button, "UpdateNewItem", info and info.quality)
  Call(button, "UpdateCooldown", texture)
  Call(button, "SetReadable", info and info.isReadable)
  local quest = info and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bagID, slot)
  Call(button, "UpdateQuestItem", quest and quest.isQuestItem, quest and quest.questID, quest and quest.isActive)
  SetQuality(button, info and info.quality)
  local freeCount = button.codexFreeCount
  local showFree = freeCount ~= nil and not info
  button.codexFree:SetShown(showFree)
  button.codexFreeLabel:SetShown(showFree)
  if showFree then
    button.codexFree:SetText(freeCount)
    -- which bags: "bags" or "reagent" under the count (both said "free")
    button.codexFreeLabel:SetText(button.codexFreeKind == "reagent" and "reagent" or "bags")
  end
  button.codexEntry = info and { link = info.hyperlink } or nil
  -- Stat Delta's upgrade arrow, when that module runs
  local statdelta = ns.statdelta
  if statdelta and statdelta.running and statdelta.SetArrow then
    pcall(statdelta.SetArrow, button, info and info.hyperlink)
  end
  -- Highlights' quest item glow, when that module runs
  local highlight = ns.highlight
  if highlight and highlight.running and highlight.QuestMark then
    pcall(highlight.QuestMark, button, bagID, info and slot)
  end
  return info
end
B.FillLive = FillLive

-- This character's bags (default: the carried ones; the bank window passes the bank's) as entries, plus the
-- first empty slot of the ordinary bags and of the reagent bag.
function B.LiveEntries(bags)
  local entries, slots = {}, {}
  local free = { normal = { count = 0 }, reagent = { count = 0 } }
  local keyring, reagent = B.KeyringID(), B.ReagentID()
  for _, bagID in ipairs(bags or B.CarriedBags()) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) or 0 do
      local info = C_Container.GetContainerItemInfo(bagID, slot)
      local entry = { bagID = bagID, slot = slot }
      if info and info.hyperlink then
        entry.link, entry.count, entry.quality = info.hyperlink, info.stackCount, info.quality
        entry.isNew = C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bagID, slot) or false
        local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bagID, slot)
        entry.isQuest = quest and (quest.isQuestItem or quest.questID) and true or false
        entry.order = #entries + 1
        entries[#entries + 1] = entry
      elseif bagID ~= keyring then
        local kind = bagID == reagent and free.reagent or free.normal
        kind.count = kind.count + 1
        kind.first = kind.first or entry
      end
      slots[#slots + 1] = entry
    end
  end
  return entries, slots, free
end

-- Sections ---------------------------------------------------------------------------------------------------

local function MinCols(name)
  return name and math.ceil((#name * 8 + 4) / CELL) or 1
end

-- Every named section gets the columns its heading needs.
function B.SetMinCols(sections)
  for _, section in ipairs(sections) do
    section.minCols = section.name and MinCols(section.name) or nil
  end
  return sections
end

-- Category sections of live entries, the Free box(es) last.
function B.CategorySections(entries, free)
  local sections = B.Group(B.ShouldCombine() and B.Combine(entries) or entries)
  local freeEntries = {}
  for _, kind in ipairs({ free.normal, free.reagent }) do
    if kind.first then
      kind.first.free = kind.count
      kind.first.freeKind = kind == free.reagent and "reagent" or "bags"
      freeEntries[#freeEntries + 1] = kind.first
    end
  end
  if #freeEntries > 0 then
    sections[#sections + 1] = { id = "free", name = L["Free"], entries = freeEntries }
  end
  return sections
end

-- "Show keys" off: the keyring and the Keys category are left out of the window (the items stay where they are).
local function DropKeys(sections)
  if B.db.showKeys ~= false then
    return sections
  end
  local out = {}
  for _, section in ipairs(sections) do
    if section.id ~= "key" and section.id ~= "keys" then
      out[#out + 1] = section
    end
  end
  return out
end
B.DropKeys = DropKeys

-- The live view's sections: grouped, or every slot in bag order.
local function LiveSections(entries, slots, free)
  local sections
  if B.db.categories then
    sections = B.CategorySections(entries, free)
  else
    local bags, reagentSlots, keys = {}, {}, {}
    for _, entry in ipairs(slots) do
      if entry.bagID == B.KeyringID() then
        if entry.link then
          keys[#keys + 1] = entry
        end
      elseif entry.bagID == B.ReagentID() then
        reagentSlots[#reagentSlots + 1] = entry
      else
        bags[#bags + 1] = entry
      end
    end
    sections = { { id = "bags", entries = bags, wide = true } } -- the plain grid, never made narrower
    if #reagentSlots > 0 then
      sections[#sections + 1] = { id = "reagent", name = L["Reagent bag"], entries = reagentSlots }
    end
    if #keys > 0 then
      sections[#sections + 1] = { id = "keys", name = L["Keyring"], entries = keys }
    end
  end
  return DropKeys(sections)
end

local function SavedSections(entries)
  if B.db.categories then
    if B.db.combine then
      entries = B.Combine(entries)
    end
    return DropKeys(B.Group(entries))
  end
  if B.db.showKeys == false then
    local keyring, kept = B.KeyringID(), {}
    for _, entry in ipairs(entries) do
      if entry.bagID ~= keyring then
        kept[#kept + 1] = entry
      end
    end
    entries = kept
  end
  return { { id = "all", entries = entries } }
end

-- Headings ---------------------------------------------------------------------------------------------------

local function Heading(pool, content, index)
  local heading = pool.list[index]
  if not heading then
    heading = UI.Text(content, "head", 12, "accent")
    heading:SetWordWrap(false)
    pool.list[index] = heading
  end
  return heading
end

-- Places the packed sections in content: place(entry, x, y) for each entry; headings (from pool, a
-- { list = {} } per window) over named sections.
function B.PlaceBlocks(packed, pool, content, place)
  local used = 0
  for _, block in ipairs(packed.blocks) do
    local top = block.y
    if block.section.name then
      used = used + 1
      local heading = Heading(pool, content, used)
      heading:ClearAllPoints()
      heading:SetPoint("TOPLEFT", content, "TOPLEFT", block.x, -block.y)
      heading:SetWidth(math.max(CELL, block.cols * CELL - SPACING))
      heading:SetText(block.section.name)
      heading:Show()
      top = top + HEADING
    end
    for index, entry in ipairs(block.section.entries) do
      local col = (index - 1) % block.cols
      local row = math.floor((index - 1) / block.cols)
      place(entry, block.x + col * CELL, top + row * CELL)
    end
  end
  for index = used + 1, #pool.list do
    pool.list[index]:Hide()
  end
end

local function Place(packed, place)
  B.PlaceBlocks(packed, headings, frame.content, place)
end

-- A window `columns` cells wide whose content is contentHeight px tall (win.top = where the content starts).
function B.ResizeWindow(win, columns, contentHeight, extraWidth)
  local width = columns * CELL - SPACING + PAD * 2 + (extraWidth or 0)
  win:SetSize(width, win.top + math.max(CELL, contentHeight - SPACING) + FOOT)
end

local function Resize(contentHeight)
  B.ResizeWindow(frame, B.db.columns, contentHeight)
end

-- Search -----------------------------------------------------------------------------------------------------

-- Dims the shown buttons of a live set that don't match the search text.
function B.DimSet(set, search)
  if not set.frame:IsShown() then
    return
  end
  for _, list in pairs(set.buttons) do
    for _, button in pairs(list) do
      if button:IsShown() then
        local entry = button.codexEntry
        local match = search == "" or (entry and B.Matches(entry, search)) or false
        button:SetAlpha(match and 1 or 0.25)
      end
    end
  end
end

local function ApplySearch()
  local search = view.search
  B.DimSet(live, search)
  for _, button in ipairs(saved.buttons) do
    if button:IsShown() and button.entry then
      button:SetAlpha(B.Matches(button.entry, search) and 1 or 0.25)
    end
  end
end
B.ApplySearch = ApplySearch

-- Footer -----------------------------------------------------------------------------------------------------

local function ViewedKey()
  return view.key or B.PlayerKey()
end

local function UpdateFooter(freeText)
  frame.free:SetText(freeText or "")
  local char = B.Character(ViewedKey())
  local money = view.key and (char and char.money) or GetMoney()
  local _, total = B.MoneyList()
  frame.money.text:SetText(ns.Money(money or 0) .. "   |cff999999" .. L["Total"] .. "|r " .. ns.Money(total))
end

-- Every character's money, richest first, and the total.
function B.ShowMoneyTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_TOPRIGHT")
  local accent = Theme().accent
  GameTooltip:AddLine(L["Money on your characters"], accent[1], accent[2], accent[3])
  local list, total = B.MoneyList()
  for _, entry in ipairs(list) do
    GameTooltip:AddDoubleLine(B.ColoredName(entry.key), ns.Money(entry.money), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine(L["Total"], ns.Money(total), accent[1], accent[2], accent[3], 1, 1, 1)
  GameTooltip:Show()
end

-- Live view --------------------------------------------------------------------------------------------------

-- In combat: refill the buttons of a set already shown (nothing made, placed, shown or hidden); returns the
-- free slots of the bags.
function B.RefillSet(set, bags)
  bags = bags or B.CarriedBags()
  local free = 0
  -- combined buttons keep their place; their totals follow the bags
  local totals = B.CombineTotals((B.LiveEntries(bags)))
  for _, list in pairs(set.buttons) do
    for _, button in pairs(list) do
      local key = button.codexCombineKey
      if key and button:IsShown() then
        local t = totals[key]
        button.codexTotal = t and t.total or nil
        button.codexStacks = t and t.stacks or nil
      end
    end
  end
  for _, bagID in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) or 0 do
      local button = set.buttons[bagID] and set.buttons[bagID][slot]
      local info
      if button and button:IsShown() then
        info = FillLive(button, bagID, slot)
      else
        info = C_Container.GetContainerItemInfo(bagID, slot)
      end
      if not info and bagID ~= B.KeyringID() then
        free = free + 1
      end
    end
  end
  return free
end

-- In combat: refill the buttons already shown; the layout waits for the end of the fight.
local function RefillLive()
  local free = B.RefillSet(live)
  B.layoutPending = true
  ApplySearch()
  return free
end

-- Refills every shown button of a set (item lock / cooldown changes).
function B.RefillButtons(set)
  for bagID, list in pairs(set.buttons) do
    for slot, button in pairs(list) do
      if button:IsShown() then
        FillLive(button, bagID, slot)
      end
    end
  end
end

-- The sizes from the options, clamped to what the page allows.
local function ReadSizes()
  local db = B.db
  SIZE = math.max(28, math.min(44, db.itemSize or 37))
  SPACING = math.max(0, math.min(12, db.itemSpacing or 4))
  GAP = math.max(0, math.min(30, db.sectionSpacing or 12))
  CELL = SIZE + SPACING
end
B.ReadSizes = ReadSizes

-- Places a set's buttons for packed sections of live entries in content and hides the set's other buttons.
-- Out of combat only.
function B.PlaceLive(set, packed, pool, content)
  local shown = {}
  B.PlaceBlocks(packed, pool, content, function(entry, x, y)
    local button = LiveButton(set, entry.bagID, entry.slot)
    if button then
      shown[button] = true
      button.codexFreeCount, button.codexFreeKind = entry.free, entry.freeKind
      local combined = entry.stacks and entry.stacks > 1
      button.codexTotal = combined and entry.total or nil
      button.codexStacks = combined and entry.stacks or nil
      button.codexCombineKey = combined and entry.combineKey or nil
      button:ClearAllPoints()
      button:SetSize(SIZE, SIZE)
      button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
      button:Show()
      FillLive(button, entry.bagID, entry.slot)
    end
  end)
  for _, list in pairs(set.buttons) do
    for _, button in pairs(list) do
      if not shown[button] then
        button.codexFreeCount, button.codexTotal, button.codexStacks, button.codexCombineKey = nil, nil, nil, nil
        button:Hide()
      end
    end
  end
end

local function LayoutLive()
  ReadSizes()
  B.EnsureButtons()
  local entries, slots, free = B.LiveEntries()
  local sections = B.SetMinCols(LiveSections(entries, slots, free))
  local packed = B.Pack(sections, B.db.columns, CELL, HEADING, GAP, B.db.pack)
  B.PlaceLive(live, packed, headings, frame.content)
  B.layoutPending = false
  B.lastPacked = packed
  Resize(packed.height)
  ApplySearch()
  local total = free.normal.count + free.reagent.count
  return total, #slots
end

-- Saved view (another character, or a bank) -------------------------------------------------------------------

local function SavedButton(index)
  local button = saved.buttons[index]
  if button then
    return button
  end
  button = CreateFrame("Button", nil, saved.frame)
  button:SetSize(SIZE, SIZE)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  SlotLook(button, button.icon)
  SetEmpty(button, false)
  button.count = button.codexCount
  button.codexSaved = true
  button:SetScript("OnEnter", function(self)
    if self.entry then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(self.entry.link)
      GameTooltip:Show()
      B.AddStacksLine(self)
    end
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button:SetScript("OnClick", function(self)
    if self.entry and HandleModifiedItemClick then
      HandleModifiedItemClick(self.entry.link) -- shift-click links it in chat
    end
  end)
  saved.buttons[index] = button
  return button
end

local function LayoutSaved(containers)
  ReadSizes()
  local entries, free, size = B.SavedEntries(containers)
  local sections = B.SetMinCols(SavedSections(entries))
  local packed = B.Pack(sections, B.db.columns, CELL, HEADING, GAP, B.db.pack)
  local used = 0
  Place(packed, function(entry, x, y)
    used = used + 1
    local button = SavedButton(used)
    button.entry = entry
    button.icon:SetTexture(select(5, C_Item.GetItemInfoInstant(entry.link)) or 134400)
    SetCount(button, entry.total or entry.count or 1)
    button.codexTotal = entry.total
    button.codexStacks = entry.stacks
    SetQuality(button, entry.quality)
    button:SetSize(SIZE, SIZE)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame.content, "TOPLEFT", x, -y)
    button:Show()
  end)
  for index = used + 1, #saved.buttons do
    saved.buttons[index]:Hide()
    saved.buttons[index].entry = nil
  end
  Resize(packed.height)
  ApplySearch()
  return free, size
end

-- Header icon buttons: a small square in the theme's button look, the icon tinted in the button text colour
-- (accent when on); the tooltip says what it does and its state (button:TooltipLines()).
local ICON = ROW
local ICONS = {
  view = "Interface\\Icons\\INV_Misc_Note_01",
  combine = "Interface\\Icons\\INV_Misc_Coin_02",
  bank = "Interface\\Icons\\INV_Box_02",
  class = "Interface\\TargetingFrame\\UI-Classes-Circles",
  unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
  keys = "Interface\\Icons\\INV_Misc_Key_03",
}

local function IconButton(parent, texture, onClick, lines)
  local button = UI.Button(parent, ICON, ICON)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("CENTER")
  button.icon:SetSize(16, 16)
  button.icon:SetTexture(texture)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.TooltipLines = lines
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for index, line in ipairs(self:TooltipLines()) do
      if index == 1 then
        GameTooltip:AddLine(line)
      else
        GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
      end
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  return button
end

-- Tint: the button text colour, accent when on, dim when disabled. Class icons keep their colours.
local function SetIconState(button, on, enabled)
  local theme = Theme()
  button.on = on
  local icon = button.icon
  if button.keepColors then
    icon:SetDesaturated(not enabled)
    icon:SetVertexColor(1, 1, 1, enabled and 1 or 0.5)
  else
    icon:SetDesaturated(true)
    local color = on and theme.accent or theme.button.text
    icon:SetVertexColor(color[1], color[2], color[3], enabled and 1 or 0.4)
  end
end
B.IconButton, B.SetIconState, B.ICONS = IconButton, SetIconState, ICONS

local function SetClassIcon(button, class)
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then
    button.icon:SetTexture(ICONS.class)
    button.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  else
    button.icon:SetTexture(ICONS.unknown)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

-- Refresh ----------------------------------------------------------------------------------------------------

local function UpdateHeader()
  local key = ViewedKey()
  local char = B.Character(key)
  local name = char and ns.CharacterDisplayName(char) or ns.PlayerFullName()
  local title = (view.bank and L["Bank"] or L["Bags"]) .. (view.key and (" - " .. name) or "")
  frame.title:SetText(Theme().titlebar.upper and title:upper() or title)
  SetIconState(frame.mode, B.db.categories, true)
  SetIconState(frame.combine, B.ShouldCombine(), true)
  SetIconState(frame.keys, B.db.showKeys ~= false, true)
  SetClassIcon(frame.character, char and char.class)
  SetIconState(frame.character, false, true)
  local hasBank = view.bank or (char and char.bank ~= nil) or false
  SetIconState(frame.bank, view.bank, hasBank)
end

function B.Refresh()
  if not frame then
    return
  end
  B.refreshQueued = false
  UpdateHeader()
  local isLive = not view.key and not view.bank
  if isLive then
    local free, size
    if InCombatLockdown() then
      free = RefillLive()
      UpdateFooter(L["Free %d"]:format(free))
      return
    end
    live.frame:Show()
    saved.frame:Hide()
    free, size = LayoutLive()
    UpdateFooter(L["Free %d / %d"]:format(free, size))
    return
  end
  if InCombatLockdown() then
    B.layoutPending = true
    return
  end
  live.frame:Hide()
  saved.frame:Show()
  local char = B.Character(ViewedKey())
  local containers = char and (view.bank and char.bank or char.bags) or {}
  local free, size = LayoutSaved(containers)
  local stamp = char and (view.bank and char.bankUpdated or char.updated)
  UpdateFooter(L["Free %d / %d"]:format(free, size) .. "  |cff999999" .. L["%s ago"]:format(ns.Age(stamp)) .. "|r")
end

-- Coalesces bursts of bag events into one refresh, and only while the window is open.
function B.RequestRefresh()
  if not frame or not frame:IsShown() then
    B.layoutPending = true
    return
  end
  if B.refreshQueued then
    return
  end
  B.refreshQueued = true
  C_Timer.After(0.05, function()
    if B.refreshQueued then
      B.Refresh()
    end
  end)
end

-- Item lock / cooldown changes: refill the shown buttons only.
function B.RefillShown()
  if frame and frame:IsShown() and live.frame:IsShown() then
    B.RefillButtons(live)
  end
  if B.RefillBank then
    B.RefillBank()
  end
end

-- Lays out a closed window while that is still allowed, so a bag key in a fight opens it full (2026-11-22, the
-- user's "bags is not opening in combat": in a fight the window only refills buttons placed before, and a closed
-- window was never laid out: the first open after login, or after a bag change, showed no slots). Run at
-- PLAYER_REGEN_DISABLED (still out of lockdown) and once a few seconds after the window is made.
function B.PrepareForCombat()
  if not frame or InCombatLockdown() then
    return
  end
  if frame:IsShown() then
    if B.layoutPending then
      B.Refresh()
    end
    return
  end
  if view.resetOnShow then
    view.key, view.bank, view.resetOnShow = nil, false, false -- it opens on your own bags
  end
  if B.layoutPending or not B.lastPacked then
    B.Refresh()
  end
end

-- View another character (nil = yourself) or switch between bags and bank. The live buttons are hidden for
-- that, so not during a fight.
function B.View(key, bank)
  if InCombatLockdown() then
    ns.Say(L["other characters and the bank can be viewed after the fight."])
    return false
  end
  if key == B.PlayerKey() then
    key = nil
  end
  view.key = key
  local char = B.Character(key or B.PlayerKey())
  view.bank = bank and char and char.bank ~= nil or false
  B.Refresh()
  return true
end

function B.ShowCharacterMenu(anchor)
  local items = { { text = L["Characters"], title = true } }
  local mine = B.PlayerKey()
  for _, key in ipairs(B.CharacterKeys(false)) do
    local text = B.ColoredName(key) .. (key == mine and (" |cff999999" .. L["(you)"] .. "|r") or "")
    items[#items + 1] = { text = text, checked = key == ViewedKey(), func = function()
      B.View(key, false)
    end }
  end
  UI.ShowMenu(anchor, items)
end

-- Window -------------------------------------------------------------------------------------------------------

local function SavePosition(self)
  local point, _, relativePoint, x, y = self:GetPoint()
  B.db[self.codexPointKey or "point"] = { point, relativePoint, x, y }
end

-- A Codex window's title bar (emblem, title, close button; dragging moves the window and saves its place in
-- B.db[win.codexPointKey]). Sets win.title.
function B.TitleBar(win)
  local theme = Theme()
  local bar = CreateFrame("Frame", nil, win)
  local height = TITLE
  bar:SetPoint("TOPLEFT", 5, -5)
  bar:SetPoint("TOPRIGHT", -5, -5)
  bar:SetHeight(height)
  local fill = bar:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  UI.Gradient(fill, theme.titlebar.from, theme.titlebar.to)
  local line = bar:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  UI.SetColor(line, theme.titlebar.line)
  local emblem = bar:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(T.EMBLEM)
  emblem:SetSize(24, 24)
  emblem:SetPoint("LEFT", 8, 0)
  win.title = UI.Text(bar, "head", 16, "titleText")
  win.title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  local close = UI.Button(bar, 24, 24, "x")
  close:SetPoint("RIGHT", -6, 0)
  close:SetScript("OnClick", function()
    win:Hide()
  end)
  win.close = close
  -- dragging the title bar moves the window
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function()
    win:StartMoving()
  end)
  bar:SetScript("OnDragStop", function()
    win:StopMovingOrSizing()
    SavePosition(win)
  end)
  return bar, height
end

local function TitleBar()
  return B.TitleBar(frame)
end

-- A search box at the top left of a window's header row, up to rightOf; onChange(text) gets the trimmed,
-- lower-case text.
function B.SearchBox(win, rightOf, onChange)
  local search = UI.EditBox(win, 100, ROW)
  search:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -(5 + TITLE + 11))
  search:SetPoint("RIGHT", rightOf, "LEFT", -6, 0)
  search:SetTextInsets(26, 8, 0, 0)
  local glass = search:CreateTexture(nil, "OVERLAY")
  glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  glass:SetSize(14, 14)
  glass:SetPoint("LEFT", 8, -1)
  local muted = Theme().muted
  glass:SetVertexColor(muted[1], muted[2], muted[3])
  local hint = UI.Text(search, "body", 13, "muted")
  hint:SetPoint("LEFT", 26, 0)
  hint:SetText(L["Search"])
  search:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    hint:SetShown(text == "")
    onChange(strtrim(text):lower())
  end)
  search:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
  end)
  return search
end

local function HeaderRow(bar)
  frame.bank = IconButton(frame, ICONS.bank, function()
    B.View(view.key, not view.bank)
  end, function()
    if view.bank then
      return { L["Bank (saved copy)"], L["Showing the bank as it was at the last visit. Click for the bags."] }
    end
    local char = B.Character(ViewedKey())
    if not (char and char.bank) then
      return { L["Bank"], L["Not seen yet: visit the bank once with this character."] }
    end
    return { L["Bank (saved copy)"], L["Click to see the bank as it was at the last visit (%s ago)."]:format(ns.Age(char.bankUpdated)) }
  end)
  frame.bank:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(5 + TITLE + 11))
  frame.character = IconButton(frame, ICONS.unknown, function(self)
    B.ShowCharacterMenu(self)
  end, function()
    return { L["Showing: %s"]:format(B.ColoredName(ViewedKey())), L["Click to pick a character."] }
  end)
  frame.character.keepColors = true
  frame.character:SetPoint("RIGHT", frame.bank, "LEFT", -6, 0)
  frame.combine = IconButton(frame, ICONS.combine, function()
    B.db.combine = not B.db.combine
    B.Refresh()
    ns.Fire("BAGS_CHANGED", "options")
  end, function()
    local lines = { B.db.combine and L["Combine identical items: on"] or L["Combine identical items: off"],
      L["One button per item with the total. Click to switch."] }
    if B.db.combine and not B.ShouldCombine() then
      lines[#lines + 1] = B.db.categories
        and L["Shown one by one right now: a bank, trade, mail, vendor or auction window is open."]
        or L["Shown one by one in bag order."]
    end
    return lines
  end)
  frame.combine:SetPoint("RIGHT", frame.character, "LEFT", -6, 0)
  frame.mode = IconButton(frame, ICONS.view, function()
    B.db.categories = not B.db.categories
    B.Refresh()
    ns.Fire("BAGS_CHANGED", "options")
  end, function()
    if B.db.categories then
      return { L["View: Categories"], L["Click for bag order."] }
    end
    return { L["View: Bag order"], L["Click for categories."] }
  end)
  frame.mode:SetPoint("RIGHT", frame.combine, "LEFT", -6, 0)
  frame.keys = IconButton(frame, ICONS.keys, function()
    B.db.showKeys = not (B.db.showKeys ~= false)
    B.Refresh()
    ns.Fire("BAGS_CHANGED", "options")
  end, function()
    if B.db.showKeys ~= false then
      return { L["Keys: shown"], L["Your keyring and other keys. Click to hide them."] }
    end
    return { L["Keys: hidden"], L["Click to show your keyring and other keys."] }
  end)
  frame.keys:SetPoint("RIGHT", frame.mode, "LEFT", -6, 0)

  local search = B.SearchBox(frame, frame.keys, function(text)
    view.search = text
    ApplySearch()
  end)
  frame.search = search
end

-- A window's footer: a 34px band at the bottom (the sidebar fill with a divider line over it, board footer)
-- with win.free (text, left) and win.money (button with .text, right; tooltip = every character's money).
function B.Footer(win)
  local band = CreateFrame("Frame", nil, win)
  band:SetPoint("BOTTOMLEFT", 5, 5)
  band:SetPoint("BOTTOMRIGHT", -5, 5)
  band:SetHeight(34)
  local fill = band:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  UI.SetColor(fill, Theme().side)
  local line = UI.Divider(band)
  line:SetPoint("TOPLEFT")
  line:SetPoint("TOPRIGHT")
  win.free = UI.Text(band, "body", 13, "muted")
  win.free:SetPoint("LEFT", 12, 0)
  local money = CreateFrame("Button", nil, band)
  money:SetPoint("RIGHT", -12, 0)
  money:SetSize(280, 20)
  money.text = UI.Text(money, "body", 13, "bright")
  money.text:SetPoint("RIGHT")
  money.text:SetJustifyH("RIGHT")
  money:SetScript("OnEnter", B.ShowMoneyTooltip)
  money:SetScript("OnLeave", GameTooltip_Hide)
  win.money = money
  win.band = band
  return band
end

local function Footer()
  B.Footer(frame)
end

-- The frame of another Codex window in the bag window's look (bank, guild bank): movable, closes with Escape,
-- its place saved in B.db[pointKey]. Made hidden; the caller adds the title bar, header and footer.
function B.NewWindow(name, pointKey, defaultPoint)
  local win = CreateFrame("Frame", name, UIParent)
  win:SetFrameStrata("MEDIUM")
  win:SetToplevel(true)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:SetSize(400, 300)
  win.codexPointKey = pointKey
  local point = B.db[pointKey]
  if point then
    win:SetPoint(point[1], UIParent, point[2], point[3], point[4])
  else
    win:SetPoint(defaultPoint[1], UIParent, defaultPoint[2], defaultPoint[3], defaultPoint[4])
  end
  UI.Panel(win, { cornerSize = 14 })
  table.insert(UISpecialFrames, name)
  win.top = 5 + TITLE + 11 + ROW + 14
  win:Hide()
  return win
end

-- A text button in the window's header row look.
function B.TextButton(parent, width, text, onClick, lines)
  local button = UI.Button(parent, width, ROW, text)
  button:SetScript("OnClick", onClick)
  if lines then
    button.TooltipLines = lines
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      for index, line in ipairs(self:TooltipLines()) do
        if index == 1 then
          GameTooltip:AddLine(line)
        else
          GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
        end
      end
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
  end
  return button
end

-- Built once, out of combat (Enable, or after the fight Enable fell in).
function B.CreateWindow()
  if frame or InCombatLockdown() then
    return frame
  end
  B.DB()
  frame = CreateFrame("Frame", "CodexBagsFrame", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetSize(400, 300)
  local point = B.db.point
  if point then
    frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
  else
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
  end
  UI.Panel(frame, { cornerSize = 14 })
  table.insert(UISpecialFrames, "CodexBagsFrame")

  local bar, height = TitleBar()
  HeaderRow(bar)
  frame.top = 5 + height + 11 + ROW + 14 -- the board's content starts 94px down
  frame.content = CreateFrame("Frame", nil, frame)
  frame.content:SetPoint("TOPLEFT", PAD, -frame.top)
  frame.content:SetPoint("BOTTOMRIGHT", -PAD, FOOT)
  live.frame = CreateFrame("Frame", "CodexBagsLive", frame.content)
  live.frame:SetAllPoints()
  saved.frame = CreateFrame("Frame", nil, frame.content)
  saved.frame:SetAllPoints()
  saved.frame:Hide()
  Footer()

  frame:Hide()
  frame:SetScript("OnShow", function()
    if view.resetOnShow and not InCombatLockdown() then
      view.key, view.bank, view.resetOnShow = nil, false, false
    end
    B.Refresh()
  end)
  frame:SetScript("OnHide", function()
    view.resetOnShow = true
    frame.search:ClearFocus()
    UI.HideMenu()
    B.OnWindowHidden()
  end)
  B.frame = frame
  B.EnsureButtons()
  C_Timer.After(3, B.PrepareForCombat) -- placed before the first fight
  return frame
end

function B.Window()
  return frame
end

function B.Toggle()
  if not frame then
    B.CreateWindow()
  end
  if not frame then
    ns.Say(L["the bag window is made after the fight."])
    return
  end
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end
