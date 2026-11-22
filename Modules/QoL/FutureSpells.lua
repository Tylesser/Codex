local addonName, ns = ...

-- Future spells in the spellbook (the user's ask, 2026-11-19: "add a tab to the spell window to show future spells
-- and expected prices for them"; then "add a tab to here" pointing at the spellbook's icon tabs, and "I'd like to see
-- spells for future levels"). An icon tab after the spellbook's own school tabs opens a page in the book: every
-- spell and rank you haven't learned yet, by level, with what your trainer asks for it, and totals (what you can
-- learn now, at the next level, everything; against your money).
--
-- Which spells: the game's own data (ns.CLASS_SPELLS, ClassSpellsData.lua, made by tools/data/class_spells.py from
-- Forever's SkillLineAbility / SpellLevels / Talent DB2 tables): every spell your class learns, with its level and
-- rank, for your race; higher ranks of a talent only once you know the talent. Names and icons come from the game
-- (C_Spell). Lower ranks than one you know are left out.
--
-- Where the prices come from: the game has no price table on the client; the class trainer lists every spell it
-- teaches with its level and cost (GetTrainerServiceInfo / GetTrainerServiceCost; the ones above your level only
-- with the trainer's "unavailable" filter on). So at a class trainer (C_Trainer.GetTrainerType() = General) Codex
-- reads the list, with that filter switched on for one frame if it was off and back off after, and keeps it in
-- CodexDB.trainerSpells[class] (shared by your characters of that class; not part of a profile). The spell's ID
-- comes from C_TooltipInfo.GetTrainerService(index).id. Once the trainer was seen its list is the word up to its
-- highest level; the game's data fills the levels above it.
--
-- Forever facts (forever branch of Gethe/wow-ui-source, Blizzard_PlayerSpells/Camelot): the spellbook and the
-- talents are separate windows (PlayerSpellsFrameMixin:IsTabSystemAvailable() is false: no bottom tabs). The book
-- is PlayerSpellsFrame.SpellBookFrame; its school tabs are icon tabs in .CategoryTabSystem (a TabSystemTemplate
-- layout frame), all removed and made again by CreateCategoryMixins on every UpdateAllSpellData (each show and
-- SPELLS_CHANGED), which also calls the book's SetTab. So Blizzard's tab system is never touched (adding a tab to
-- it, or calling SetSquareMode, which writes a file-local of theirs, would taint the book's spell buttons): our
-- tab is a button of our own on TabSystemButtonArtTemplate (art only, square look set up by hand) anchored after
-- the tab row; our page is a frame of ours in the book over its pages. A school tab clicked (post hook on the
-- tab system's SetTab, which only a click calls; a mouse down on their tabs, since the selected one is disabled),
-- a search, or the book closing hides our page; our tab toggles it. Nothing secure is touched.

local Q = ns.qol
local UI = ns.UI
local F = {}
Q.future = F

local KEY = "futureSpells"
F.ROW = 24
F.TAB_TEXT = "Future spells"
F.ICON = "Interface\\Icons\\INV_Misc_Book_11"

local function Readable(value)
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

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end

local function Pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return Pass(pcall(fn, ...))
end

local function Lower(text)
  return Str(text) and text:lower() or nil
end

local function Class()
  local _, class = Ask(UnitClass, "player")
  return Str(class)
end

local function Level()
  return Num(Ask(UnitLevel, "player")) or 1
end

-- The player's race as a bit of the DB2 race masks: ns.RACE_BITS (race ID -> bit; Forever's Skyborne are race 95
-- and 96 with bits 32 and 33, so not 1 << (raceID - 1)); nil when unknown.
local function RaceBit()
  local _, _, id = Ask(UnitRace, "player")
  id = Num(id)
  local bit = id and ns.RACE_BITS and ns.RACE_BITS[id]
  if not bit and id and id >= 1 and id <= 11 then
    bit = id - 1
  end
  return bit and 2 ^ bit or nil
end

local function HasBit(mask, bit)
  return math.floor(mask / bit) % 2 == 1
end

local function RankNumber(rank)
  return Str(rank) and tonumber(rank:match("(%d+)")) or nil
end

function F.On()
  return Q.DB()[KEY] ~= false
end

-- Storage -----------------------------------------------------------------------------------------------------

-- This class's trainer list: { seen = time(), spells = { [key] = { name, rank, level, cost, icon, id } } }.
function F.Store(class)
  class = class or Class() or "UNKNOWN"
  local db = ns.db
  if type(db) ~= "table" then
    return { spells = {} }
  end
  db.trainerSpells = type(db.trainerSpells) == "table" and db.trainerSpells or {}
  local store = db.trainerSpells[class]
  if type(store) ~= "table" then
    store = { spells = {} }
    db.trainerSpells[class] = store
  end
  store.spells = type(store.spells) == "table" and store.spells or {}
  return store
end

local function Key(name, rank, id)
  if id then
    return "id:" .. id
  end
  return (Lower(name) or "?") .. "|" .. (Lower(rank) or "")
end
F.Key = Key

-- Reading the trainer -----------------------------------------------------------------------------------------

function F.IsClassTrainer()
  local kind = C_Trainer and Num(Ask(C_Trainer.GetTrainerType))
  local general = Enum and Enum.TrainerType and Enum.TrainerType.General or 0
  return kind ~= nil and kind == general
end

function F.ServiceSpellID(index)
  local data = C_TooltipInfo and Ask(C_TooltipInfo.GetTrainerService, index)
  return type(data) == "table" and Num(data.id) or nil
end

-- Notes every service the trainer lists now. Returns how many.
function F.ReadTrainer()
  if not F.IsClassTrainer() then
    return 0
  end
  local count = Num(Ask(GetNumTrainerServices)) or 0
  local store, read = F.Store(), 0
  for index = 1, count do
    local name, kind, icon, level, rank = Ask(GetTrainerServiceInfo, index)
    name, kind = Str(name), Str(kind)
    if name and kind and kind ~= "header" then
      local cost = Num((Ask(GetTrainerServiceCost, index)))
      local id = F.ServiceSpellID(index)
      local entry = { name = name, rank = Str(rank), level = Num(level), cost = cost, id = id,
        icon = Num(icon) or Str(icon) }
      local key = Key(name, entry.rank, id)
      -- an entry noted by name before its ID was known goes
      store.spells[Key(name, entry.rank)] = nil
      store.spells[key] = entry
      read = read + 1
    end
  end
  if read > 0 then
    store.seen = time and time() or 0
  end
  return read
end

-- At the trainer: read, with the "unavailable" filter on for a moment so the spells above your level are listed.
function F.ScanTrainer()
  if not (F.started and F.IsClassTrainer()) then
    return
  end
  F.ReadTrainer()
  local filterOn = Ask(GetTrainerServiceTypeFilter, "unavailable")
  if Readable(filterOn) and not filterOn and type(SetTrainerServiceTypeFilter) == "function" then
    F.flipping = true
    pcall(SetTrainerServiceTypeFilter, "unavailable", true)
    F.ReadTrainer()
    local function Back()
      F.ReadTrainer()
      pcall(SetTrainerServiceTypeFilter, "unavailable", false)
      F.flipping = false
      F.Refresh()
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, Back)
    else
      Back()
    end
  end
  F.Refresh()
end

-- The spellbook ---------------------------------------------------------------------------------------------------

-- What the spellbook knows: known["name|rank"] = true, known.names[lower name] = highest rank number known (0 when
-- it has no ranks), and its future spells { name, rank, level, icon, id }.
function F.Book()
  local known, future = { names = {} }, {}
  local book = C_SpellBook
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  local types = Enum and Enum.SpellBookItemType or {}
  local spellType, futureType = types.Spell or 1, types.FutureSpell or 2
  if type(book) ~= "table" then
    return known, future
  end
  local lines = Num(Ask(book.GetNumSpellBookSkillLines)) or 0
  for line = 1, lines do
    local info = Ask(book.GetSpellBookSkillLineInfo, line)
    local offset = type(info) == "table" and Num(info.itemIndexOffset)
    local count = type(info) == "table" and Num(info.numSpellBookItems)
    if offset and count then
      for slot = offset + 1, offset + count do
        local item = Ask(book.GetSpellBookItemInfo, slot, bank)
        if type(item) == "table" then
          local kind, name, rank = Num(item.itemType), Str(item.name), Str(item.subName)
          if name and kind == spellType then
            known[Key(name, rank)] = true
            local lower = name:lower()
            known.names[lower] = math.max(known.names[lower] or 0, RankNumber(rank) or 0)
          elseif name and kind == futureType then
            future[#future + 1] = { name = name, rank = rank, id = Num(item.spellID), icon = Num(item.iconID),
              level = Num(Ask(book.GetSpellBookItemLevelLearned, slot, bank)) }
          end
        end
      end
    end
  end
  F.Mounts(known)
  return known, future
end

-- Class mounts (Summon Warhorse) live in the mount journal, not the spellbook: a collected mount counts as a known
-- spell of its name.
function F.Mounts(known)
  local journal = C_MountJournal
  if type(journal) ~= "table" then
    return
  end
  local ids = Ask(journal.GetMountIDs)
  if type(ids) ~= "table" then
    return
  end
  for _, mountID in ipairs(ids) do
    local name, _, _, _, _, _, _, _, _, _, collected = Ask(journal.GetMountInfoByID, mountID)
    name = Str(name)
    if name and collected == true then
      known[Key(name)] = true
      local lower = name:lower()
      known.names[lower] = known.names[lower] or 0
    end
  end
end

local function MountCollected(id)
  local journal = C_MountJournal
  local mountID = type(journal) == "table" and Num(Ask(journal.GetMountFromSpell, id))
  if not mountID then
    return false
  end
  local _, _, _, _, _, _, _, _, _, _, collected = Ask(journal.GetMountInfoByID, mountID)
  return collected == true
end

local KNOWN_CHECKS = { "IsPlayerSpell", "IsSpellKnown" }

function F.Known(entry, known)
  -- a lower rank than one you know (or the same) counts as known; a spell without ranks is known by its name (the
  -- game has two Summon Warhorse spells, each race gets one)
  local top = known.names and Str(entry.name) and known.names[entry.name:lower()]
  local rank = RankNumber(entry.rank)
  if top and (not rank or rank <= top) then
    return true
  end
  if entry.id then
    for _, name in ipairs(KNOWN_CHECKS) do
      if Ask(_G[name], entry.id) == true then
        return true
      end
    end
    if C_SpellBook and Ask(C_SpellBook.IsSpellKnown, entry.id) == true then
      return true
    end
    if MountCollected(entry.id) then
      return true
    end
  end
  return known[Key(entry.name, entry.rank)] == true
end

-- The game's data ---------------------------------------------------------------------------------------------------

local function SpellName(id)
  local spell = C_Spell
  if type(spell) ~= "table" then
    return nil
  end
  local name = Str(Ask(spell.GetSpellName, id))
  if not name then
    local info = Ask(spell.GetSpellInfo, id)
    name = type(info) == "table" and Str(info.name) or nil
  end
  return name
end

-- Every spell of your class from ns.CLASS_SPELLS, for your race; a talent's higher ranks only when you know the
-- talent (a spell of that name in the book). { name, rank, level, icon, id, game = true }.
function F.GameSpells(known)
  local data = type(ns.CLASS_SPELLS) == "table" and ns.CLASS_SPELLS[Class() or ""]
  local out = {}
  if type(data) ~= "table" then
    return out
  end
  local names = known and known.names or {}
  local race = RaceBit()
  for _, row in ipairs(data) do
    local id, level, rank, talent, races = row[1], row[2], row[3] or 0, row[4], row[5]
    local forRace = not races or races == 0 or not race or HasBit(races, race)
    local name = forRace and SpellName(id)
    if name and (talent ~= 1 or names[name:lower()]) then
      local rankText = rank > 0 and (C_Spell and Str(Ask(C_Spell.GetSpellSubtext, id)) or ("Rank %d"):format(rank))
        or nil
      out[#out + 1] = { id = id, level = level, name = name, rank = rankText, game = true,
        icon = C_Spell and Num(Ask(C_Spell.GetSpellTexture, id)) }
    end
  end
  return out
end

-- The list --------------------------------------------------------------------------------------------------------

-- Every spell not learned yet: the trainer's (with prices), the spellbook's future spells the trainer list lacks,
-- and the game's data (all of it before a trainer visit, after one only above the trainer's highest level).
-- Sorted by level, name, rank. Each { name, rank, level, cost, icon, id, now = learnable at your level }.
function F.List()
  local known, future = F.Book()
  local store = F.Store()
  local list, seen = {}, {}
  local level = Level()
  local function Add(entry)
    local byID = entry.id and Key(nil, nil, entry.id)
    local byName = Key(entry.name, entry.rank)
    if (byID and seen[byID]) or seen[byName] or F.Known(entry, known) then
      return
    end
    if byID then
      seen[byID] = true
    end
    seen[byName] = true
    local copy = {}
    for k, v in pairs(entry) do
      copy[k] = v
    end
    copy.now = (copy.level or 0) <= level
    list[#list + 1] = copy
  end
  local trainerTop = 0
  for _, entry in pairs(store.spells) do
    if type(entry) == "table" and Str(entry.name) then
      Add(entry)
      trainerTop = math.max(trainerTop, Num(entry.level) or 0)
    end
  end
  for _, entry in ipairs(future) do
    Add(entry)
  end
  for _, entry in ipairs(F.GameSpells(known)) do
    if not store.seen or entry.level > trainerTop then
      Add(entry)
    end
  end
  table.sort(list, function(a, b)
    local la, lb = a.level or 999, b.level or 999
    if la ~= lb then
      return la < lb
    end
    if a.name ~= b.name then
      return a.name < b.name
    end
    return (a.rank or "") < (b.rank or "")
  end)
  return list
end

-- Counts and costs: now = learnable at your level, next = the next level that has spells, all = everything.
function F.Totals(list)
  local totals = { now = { count = 0, cost = 0, unknown = 0 }, all = { count = 0, cost = 0, unknown = 0 } }
  local level = Level()
  local nextLevel
  for _, entry in ipairs(list) do
    totals.all.count = totals.all.count + 1
    totals.all.cost = totals.all.cost + (entry.cost or 0)
    if not entry.cost then
      totals.all.unknown = totals.all.unknown + 1
    end
    if entry.now then
      totals.now.count = totals.now.count + 1
      totals.now.cost = totals.now.cost + (entry.cost or 0)
      totals.now.unknown = totals.now.unknown + (entry.cost and 0 or 1)
    elseif entry.level and (not nextLevel or entry.level < nextLevel) then
      nextLevel = entry.level
    end
    totals.top = math.max(totals.top or 0, entry.level or 0)
  end
  totals.next = { level = nextLevel, count = 0, cost = 0, unknown = 0 }
  for _, entry in ipairs(list) do
    if nextLevel and entry.level == nextLevel then
      totals.next.count = totals.next.count + 1
      totals.next.cost = totals.next.cost + (entry.cost or 0)
      totals.next.unknown = totals.next.unknown + (entry.cost and 0 or 1)
    end
  end
  totals.level = level
  return totals
end

-- The page's rows: a header per level ({ header = level, count, cost }) followed by its spells.
function F.Rows(list)
  local rows, current = {}, nil
  for _, entry in ipairs(list) do
    local level = entry.level or 0
    if not current or current.header ~= level then
      current = { header = level, count = 0, cost = 0, unknown = 0, now = entry.now }
      rows[#rows + 1] = current
    end
    current.count = current.count + 1
    current.cost = current.cost + (entry.cost or 0)
    current.unknown = current.unknown + (entry.cost and 0 or 1)
    rows[#rows + 1] = entry
  end
  return rows
end

local function Spells(count)
  return count == 1 and "1 spell" or ("%d spells"):format(count)
end

-- A sum: "1g 20s", "price not seen yet" when none of it is known, "1g 20s + 2 not seen yet" when part is.
local function Cost(bucket)
  local unknown, copper = bucket.unknown or 0, bucket.cost or 0
  if unknown > 0 and unknown >= (bucket.count or 0) then
    return "price not seen yet"
  end
  local text = ns.Money(copper)
  if unknown > 0 then
    text = ("%s + %d not seen yet"):format(text, unknown)
  end
  return text
end
F.Cost = Cost

-- The summary lines over the list.
function F.Summary(list, totals)
  totals = totals or F.Totals(list)
  local lines = {}
  if totals.now.count > 0 then
    lines[#lines + 1] = ("Learn now: %s for %s"):format(Spells(totals.now.count), Cost(totals.now))
  else
    lines[#lines + 1] = "Nothing new to learn at your level."
  end
  if totals.next.level then
    lines[#lines + 1] = ("Next, at level %d: %s for %s"):format(totals.next.level, Spells(totals.next.count),
      Cost(totals.next))
  end
  if totals.all.count > 0 then
    local money = Num(Ask(GetMoney))
    lines[#lines + 1] = ("Everything to level %d: %s for %s%s"):format(totals.top or totals.level,
      Spells(totals.all.count), Cost(totals.all), money and (" (you have %s)"):format(ns.Money(money)) or "")
  end
  return lines
end

function F.Note()
  local store = F.Store()
  if not store.seen then
    return "Levels from the game's own data. Visit your class trainer once and Codex notes what each spell costs."
  end
  return ("Prices as your class trainer asked them %s ago."):format(ns.Age and ns.Age(store.seen) or "a while")
end

-- The page --------------------------------------------------------------------------------------------------------

local function Tooltip(row)
  local entry = row.item
  if not entry or entry.header or not GameTooltip then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local shown = entry.id and pcall(GameTooltip.SetSpellByID, GameTooltip, entry.id)
  if not shown then
    GameTooltip:SetText(entry.name)
    if entry.rank then
      GameTooltip:AddLine(entry.rank, 0.7, 0.7, 0.7)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(("Level %d · %s"):format(entry.level or 0, entry.cost and ns.Money(entry.cost) or
    "price not seen yet"), 1, 1, 1)
  GameTooltip:Show()
end

local function CreateRow(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(F.ROW - 4, F.ROW - 4)
  row.icon:SetPoint("LEFT", 6, 0)
  if row.icon.SetTexCoord then
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  row.name = UI.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  row.name:SetWordWrap(false)
  row.cost = UI.Text(row, "body", 12, "text")
  row.cost:SetPoint("RIGHT", -8, 0)
  row.cost:SetJustifyH("RIGHT")
  row.name:SetPoint("RIGHT", row.cost, "LEFT", -8, 0)
  row.head = UI.Text(row, "head", 13, "accent")
  row.head:SetPoint("LEFT", 6, 0)
  row:SetScript("OnEnter", Tooltip)
  row:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

local function UpdateRow(row, item)
  local theme = ns.Theme and ns.Theme() or {}
  if item.header then
    row.icon:Hide()
    row.name:SetText("")
    row.head:Show()
    row.head:SetText(("Level %d"):format(item.header) .. (item.now and "  ·  learn now" or ""))
    row.cost:SetText(("%s · %s"):format(Spells(item.count), Cost(item)))
    return
  end
  row.head:Hide()
  row.icon:Show()
  if item.icon then
    row.icon:SetTexture(item.icon)
  else
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
  local rank = item.rank and ("  |cff%s%s|r"):format(ns.Hex and ns.Hex(theme.muted) or "999999", item.rank) or ""
  row.name:SetText(item.name .. rank)
  local color = item.now and theme.accent or theme.text
  if color then
    row.name:SetTextColor(color[1], color[2], color[3])
  end
  row.cost:SetText(item.cost and ns.Money(item.cost) or "—")
end

-- The page in the book, over its pages (the school tabs, search box and settings above it stay usable).
function F.BuildPage(book)
  local page = CreateFrame("Frame", nil, book)
  page:Hide()
  page:EnableMouse(true)
  local level = book.GetFrameLevel and Num(book:GetFrameLevel())
  if page.SetFrameLevel then
    page:SetFrameLevel((level or 100) + 400) -- over the book's spell frames
  end
  local pages = rawget(book, "PagedSpellsFrame")
  local under = type(pages) == "table" and pages or book
  page:SetPoint("TOPLEFT", under, "TOPLEFT", 16, under == book and -56 or -6)
  page:SetPoint("BOTTOMRIGHT", under, "BOTTOMRIGHT", -16, 16)
  UI.Panel(page, { shadow = false, strip = false, alpha = 1 })
  page.title = UI.Text(page, "head", 18, "accent")
  page.title:SetPoint("TOPLEFT", 20, -16)
  page.title:SetText("Future spells")
  page.note = UI.Text(page, "body", 11, "muted")
  page.note:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -4)
  page.note:SetPoint("RIGHT", -20, 0)
  page.lines = {}
  local last = page.note
  for index = 1, 3 do
    local line = UI.Text(page, "body", 13, "text")
    line:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, index == 1 and -10 or -4)
    line:SetPoint("RIGHT", -20, 0)
    page.lines[index] = line
    last = line
  end
  page.list = UI.List(page, { rowHeight = F.ROW, CreateRow = CreateRow, UpdateRow = UpdateRow })
  page.list:SetPoint("TOPLEFT", last, "BOTTOMLEFT", -4, -12)
  page.list:SetPoint("BOTTOMRIGHT", -16, 16)
  page.empty = UI.Text(page.list, "body", 12, "muted")
  page.empty:SetPoint("CENTER")
  page.empty:SetText("You know every spell your class learns.")
  page:SetScript("OnShow", function()
    F.Refresh()
  end)
  F.page = page
  return page
end

function F.Refresh()
  local page = F.page
  if not (page and page:IsShown()) then
    return
  end
  local list = F.List()
  local totals = F.Totals(list)
  page.note:SetText(F.Note())
  local lines = F.Summary(list, totals)
  for index, line in ipairs(page.lines) do
    line:SetText(lines[index] or "")
  end
  page.rows = F.Rows(list)
  page.list:SetItems(page.rows)
  page.empty:SetShown(#list == 0)
end

-- The tab ---------------------------------------------------------------------------------------------------------

local hookedTabs = setmetatable({}, { __mode = "k" })

local function SpellBook()
  local frame = _G.PlayerSpellsFrame
  local book = type(frame) == "table" and rawget(frame, "SpellBookFrame")
  return type(book) == "table" and book or nil
end
F.SpellBook = SpellBook

local function TabRow(book)
  local system = book and rawget(book, "CategoryTabSystem")
  return type(system) == "table" and system or nil
end

function F.HidePage()
  if F.page then
    F.page:Hide()
  end
  if F.tab then
    F.Select(false)
  end
end

-- Selected look (Blizzard's art on our own button: SetTabSelected only reads and writes the button's own fields).
function F.Select(on)
  local tab = F.tab
  if type(tab.SetTabSelected) == "function" then
    pcall(tab.SetTabSelected, tab, on)
  end
  tab:SetEnabled(true) -- Blizzard's art disables a selected tab; ours is clicked again to close the page
end

-- A mouse down on one of the book's school tabs hides our page (the selected one is disabled and gets no click).
-- The tabs come from a pool, so each button is hooked once.
local function HookTabs(book)
  local system = TabRow(book)
  if not system or type(system.GetChildren) ~= "function" then
    return
  end
  for _, tab in ipairs({ system:GetChildren() }) do
    if tab ~= F.tab and not hookedTabs[tab] and type(tab.HookScript) == "function" then
      hookedTabs[tab] = true
      tab:HookScript("OnMouseDown", F.HidePage)
    end
  end
end

function F.ShowPage()
  local book = SpellBook()
  if not (book and F.tab) then
    return
  end
  HookTabs(book)
  local page = F.page or F.BuildPage(book)
  page:Show()
  F.Select(true)
  F.Refresh()
end

function F.Toggle()
  if F.page and F.page:IsShown() then
    F.HidePage()
  else
    F.ShowPage()
  end
end

-- Our tab right after the school tabs (the row is a layout frame as wide as its shown tabs, 1 px apart).
function F.PlaceTab()
  local book, tab = SpellBook(), F.tab
  if not (book and tab) then
    return
  end
  tab:ClearAllPoints()
  local system = TabRow(book)
  if system then
    tab:SetPoint("TOPLEFT", system, "TOPRIGHT", 1, 0)
  else
    tab:SetPoint("TOPLEFT", book, "TOPLEFT", 70, -26)
  end
end

-- The search box starts where the tab row ends (Blizzard's ResizeSearchBox); with our tab after the row it is
-- made that much narrower so the two never overlap.
function F.FitSearch()
  local book, tab = SpellBook(), F.tab
  local box = book and rawget(book, "SearchBox")
  if not (tab and tab:IsShown() and type(box) == "table" and box.GetLeft and box.SetWidth) then
    return
  end
  local left, right, width = Num(box:GetLeft()), Num(tab:GetRight()), Num(box:GetWidth())
  if left and right and width and left < right + 10 then
    box:SetWidth(math.max(1, width - (right + 10 - left)))
  end
end

-- Blizzard's square icon tab look on our own button, set up by hand: SetSquareMode would write the tab file's
-- shared spacing value from our code.
local function SquareLook(tab)
  for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight",
    "MiddleHighlight", "RightHighlight" }) do
    local texture = rawget(tab, key)
    if type(texture) == "table" and texture.Hide then
      texture:Hide()
    end
  end
  local atlases = { SquareBackground = "spellbook-Tab-Frame-C60", SquareBackgroundActive = "spellbook-Tab-Frame-Glow-C60",
    SquareBackgroundActiveGlow = "spellbook-Tab-Frame-glow-gradient-C60" }
  for key, atlas in pairs(atlases) do
    local texture = rawget(tab, key)
    if type(texture) == "table" and texture.SetAtlas then
      pcall(texture.SetAtlas, texture, atlas, true)
    end
  end
  tab.squareMode = true
end

local function TabTooltip(tab)
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
  GameTooltip:SetText(F.TAB_TEXT)
  GameTooltip:AddLine("Spells you haven't learned yet, by level, with their prices.", 1, 1, 1, true)
  GameTooltip:Show()
end

function F.Attach()
  local book = SpellBook()
  if F.tab or not book or type(book.HookScript) ~= "function" then
    return F.tab
  end
  local ok, tab = pcall(CreateFrame, "Button", nil, book, "TabSystemButtonArtTemplate")
  if not ok or not tab then
    tab = CreateFrame("Button", nil, book)
  end
  F.tab = tab
  tab:SetSize(44, 32) -- Blizzard's icon tab: the 36 px icon + 8, 32 high
  tab.isTabOnTop = true
  if type(tab.HandleRotation) == "function" then
    pcall(tab.HandleRotation, tab)
  end
  local icon = rawget(tab, "Icon")
  if type(icon) ~= "table" then
    icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 35)
    icon:SetPoint("BOTTOM")
    tab.Icon = icon
  end
  icon:SetTexture(F.ICON)
  icon:Show()
  local mask = rawget(tab, "IconMask")
  if type(mask) == "table" and mask.Show then
    mask:Show()
  end
  SquareLook(tab)
  F.Select(false)
  tab:SetScript("OnClick", F.Toggle)
  tab:SetScript("OnEnter", TabTooltip)
  tab:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  F.PlaceTab()
  book:HookScript("OnHide", F.HidePage)
  book:HookScript("OnShow", function()
    F.PlaceTab()
    F.FitSearch()
  end)
  local system = TabRow(book)
  if system and type(system.SetTab) == "function" then
    hooksecurefunc(system, "SetTab", F.HidePage) -- only a click (or the gamepad's next tab) calls it
  end
  for _, method in ipairs({ "SelectNextTab", "EnableSearchResultsMode" }) do
    if type(book[method]) == "function" then
      hooksecurefunc(book, method, F.HidePage)
    end
  end
  if type(book.ResizeSearchBox) == "function" then
    hooksecurefunc(book, "ResizeSearchBox", F.FitSearch)
  end
  -- the restyled windows: our tab in the same look as the school tabs (Codex_Skins sets SchoolTabLook on the
  -- shared API; when it loads after us it styles the tab itself through FutureSpellsTab)
  local look = ns.API and ns.API.SchoolTabLook
  if type(look) == "function" and ns.SkinPartOn and ns.SkinPartOn("windows") then
    pcall(look, tab)
  end
  tab:SetShown(F.started and true or false)
  F.FitSearch()
  return tab
end

if ns.API then
  ns.API.FutureSpellsTab = function()
    return F.tab
  end
end

-- Start / stop ------------------------------------------------------------------------------------------------------

local function OnEvent(_, event, arg)
  if event == "ADDON_LOADED" then
    if arg == "Blizzard_PlayerSpells" then
      F.Attach()
    end
  elseif event == "TRAINER_SHOW" then
    if C_Timer and C_Timer.After then
      C_Timer.After(0, F.ScanTrainer)
    else
      F.ScanTrainer()
    end
  elseif event == "TRAINER_UPDATE" then
    if not F.flipping then
      F.ReadTrainer()
      F.Refresh()
    end
  else
    F.Refresh()
  end
end

local EVENTS = { "ADDON_LOADED", "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_LEVEL_UP", "SPELLS_CHANGED",
  "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_MONEY" }

function F.Start()
  if F.started then
    return
  end
  F.started = true
  if not F.events then
    F.events = CreateFrame("Frame")
    F.events:SetScript("OnEvent", function(...)
      local ok, err = pcall(OnEvent, ...)
      if not ok then
        geterrorhandler()(err)
      end
    end)
  end
  for _, event in ipairs(EVENTS) do
    pcall(F.events.RegisterEvent, F.events, event)
  end
  F.Attach()
  if F.tab then
    F.tab:Show()
  end
end

function F.Stop()
  if not F.started then
    return
  end
  F.started = false
  if F.events then
    F.events:UnregisterAllEvents()
  end
  F.HidePage()
  if F.tab then
    F.tab:Hide()
  end
end

function F.Enable()
  if Q.DB()[KEY] then
    F.Start()
  end
end

function F.Changed(on)
  if on then
    F.Start()
  else
    F.Stop()
  end
end

Q.AddToggle({
  key = KEY,
  name = "Future spells in the spellbook",
  desc = "A tab after the spellbook's school tabs: every spell and rank your class learns that you haven't learned "
    .. "yet, by level, with what your class trainer asks for it, and what it all adds up to (what you can learn now, "
    .. "at the next level, and everything). Codex notes the prices when you visit your class trainer (shared by your "
    .. "characters of the same class); until then the list shows the spells without prices.",
  default = true,
  order = 56,
  Enable = F.Enable,
  Changed = F.Changed,
})
