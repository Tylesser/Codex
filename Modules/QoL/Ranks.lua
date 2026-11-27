local addonName, ns = ...
local L = ns.L

-- Put new spell ranks on your action bars. When you learn a higher rank of a spell (a trainer, a book), every
-- action button holding a lower rank of it gets the new one, then one chat line per spell ("Updated Fireball to
-- Rank 4 on 2 buttons."). "Update now" on the page does one pass over every spell.
--
-- Rules: only plain spell actions (GetActionInfo type "spell"; never macros, items or anything else); the same
-- spell name, a higher rank only (the number in C_Spell.GetSpellSubtext / the spellbook's subName, "Rank 4";
-- without numbers C_ActionBar.IsHighestSpellRank decides); never a downgrade. A lower rank kept beside a higher
-- one of the same spell on your bars is left alone (downranking), and so is a slot where you put a lower rank
-- back after Codex upgraded it: that slot is remembered (CodexCharDB.ranks.pinned[slot] = spell name) until it
-- holds something else or the highest rank again.
--
-- Forever facts (forever branch of Gethe/wow-ui-source): learning fires LEARNED_SPELL_IN_SKILL_LINE (spellID,
-- skillLineIndex; there is no LEARNED_SPELL_IN_TAB), then SPELLS_CHANGED. The spellbook is C_SpellBook
-- (GetNumSpellBookSkillLines, GetSpellBookSkillLineInfo, GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
-- with spellID / name / subName / itemType / isPassive). Picking up and placing: C_Spell.PickupSpell(spellID) and
-- C_ActionBar.PutActionInSlot(slot) (Blizzard's own quick-keybind code; the global PlaceAction is the fallback),
-- then ClearCursor for the old spell the slot hands back. Only out of combat (else after PLAYER_REGEN_ENABLED) and
-- only while the cursor is empty (GetCursorInfo; else when CURSOR_CHANGED says it is): never in the way of a drag.

local Q = ns.qol
local R = {}
Q.ranks = R

local KEY = "spellRanks"
R.MAX_SLOT = 180 -- every action slot the game has (bars, stance / bonus pages, the extra multi-bars)
R.LEARN_WAIT = 1 -- seconds after a learned spell before the pass runs, in case SPELLS_CHANGED doesn't come

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

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end

function R.CharDB()
  local char = ns.char or CodexCharDB
  if type(char) ~= "table" then
    CodexCharDB = {}
    char = CodexCharDB
  end
  char.ranks = type(char.ranks) == "table" and char.ranks or {}
  char.ranks.upgraded = char.ranks.upgraded or {} -- [slot] = { name, rank } we put there
  char.ranks.pinned = char.ranks.pinned or {} -- [slot] = spell name the player keeps at a lower rank
  return char.ranks
end

-- Spells ---------------------------------------------------------------------------------------------------------

function R.Name(id)
  if C_Spell and C_Spell.GetSpellName then
    return Str(Ask(C_Spell.GetSpellName, id))
  end
  return nil
end

function R.SubText(id)
  if C_Spell and C_Spell.GetSpellSubtext then
    return Str(Ask(C_Spell.GetSpellSubtext, id))
  end
  return nil
end

local function RankIn(text)
  local digits = text and text:match("(%d+)")
  return digits and tonumber(digits) or nil
end

function R.RankOf(id)
  return RankIn(R.SubText(id))
end

-- true / false, or nil when the game can't say
function R.IsHighest(id)
  if C_ActionBar and C_ActionBar.IsHighestSpellRank then
    local value = Ask(C_ActionBar.IsHighestSpellRank, id)
    if Readable(value) then
      return value and true or false
    end
  end
  return nil
end

-- The spell on a slot when it is a plain spell action, else nil (macros, items, empty).
function R.SlotSpell(slot)
  if type(GetActionInfo) ~= "function" then
    return nil
  end
  local kind, id = Pass(pcall(GetActionInfo, slot))
  if not Readable(kind) or kind ~= "spell" then
    return nil
  end
  return Num(id)
end

-- The highest known rank of every spell in the player's spellbook: [name] = { id, rank, sub }.
function R.Best()
  local best = {}
  local book = C_SpellBook
  if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo) then
    return best
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
  for line = 1, Num(Ask(book.GetNumSpellBookSkillLines)) or 0 do
    local info = Ask(book.GetSpellBookSkillLineInfo, line)
    local offset = type(info) == "table" and Num(info.itemIndexOffset)
    local count = type(info) == "table" and Num(info.numSpellBookItems)
    for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
      local item = Ask(book.GetSpellBookItemInfo, slot, bank)
      local id = type(item) == "table" and Num(item.spellID)
      local isSpell = type(item) == "table" and (spellType == nil or item.itemType == spellType)
      local passive = type(item) == "table" and item.isPassive == true
      local name = id and (Str(item.name) or R.Name(id))
      if id and isSpell and not passive and name then
        local sub = Str(item.subName) or R.SubText(id)
        local rank = RankIn(sub)
        local known = best[name]
        local better = not known
        if known then
          if rank and known.rank then
            better = rank > known.rank
          elseif rank == known.rank then
            better = R.IsHighest(id) == true and R.IsHighest(known.id) ~= true
          end
        end
        if better then
          best[name] = { id = id, rank = rank, sub = sub }
        end
      end
    end
  end
  return best
end

-- `best` is a higher rank than the spell id (rank: its number or nil).
function R.Higher(best, id, rank)
  if best.id == id then
    return false
  end
  if best.rank and rank then
    return best.rank > rank
  end
  return R.IsHighest(best.id) == true and R.IsHighest(id) == false
end

-- What a pass would do: { { slot, from, to, name, rank, sub }, ... }. names = { [name] = true } or nil for all.
function R.Plan(names)
  local db = R.CharDB()
  local best = R.Best()
  local found, order = {}, {}
  for slot = 1, R.MAX_SLOT do
    local id = R.SlotSpell(slot)
    local name = id and R.Name(id)
    if name and best[name] and (not names or names[name]) then
      if not found[name] then
        found[name] = {}
        order[#order + 1] = name
      end
      table.insert(found[name], { slot = slot, id = id, rank = R.RankOf(id) })
    end
  end
  local plan = {}
  for _, name in ipairs(order) do
    local target = best[name]
    -- the highest rank already on the bars: lower ones beside it are kept on purpose (downranking)
    local top, unknown = nil, false
    for _, entry in ipairs(found[name]) do
      if entry.rank then
        top = math.max(top or entry.rank, entry.rank)
      else
        unknown = true
      end
    end
    for _, entry in ipairs(found[name]) do
      local keep = db.pinned[entry.slot] == name
      local lowered = not unknown and top and entry.rank and entry.rank < top
      if not keep and not lowered and R.Higher(target, entry.id, entry.rank) then
        plan[#plan + 1] = { slot = entry.slot, from = entry.id, to = target.id, name = name, rank = target.rank,
          sub = target.sub }
      end
    end
  end
  return plan
end

-- The cursor --------------------------------------------------------------------------------------------------------

function R.CursorBusy()
  if type(GetCursorInfo) ~= "function" then
    return false
  end
  local kind = Ask(GetCursorInfo)
  return kind ~= nil
end

local function Pickup(id)
  local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
  if type(pickup) ~= "function" then
    return false
  end
  pcall(pickup, id)
  local kind = Ask(GetCursorInfo)
  return Readable(kind) and kind == "spell"
end

local function Place(slot)
  local place = (C_ActionBar and C_ActionBar.PutActionInSlot) or PlaceAction
  if type(place) ~= "function" then
    return false
  end
  return (pcall(place, slot))
end

local function Clear()
  if type(ClearCursor) == "function" then
    pcall(ClearCursor)
  end
end

-- Puts the new rank on one slot. True when the slot now holds it.
function R.Upgrade(item)
  if R.CursorBusy() then
    return false
  end
  if not Pickup(item.to) then
    Clear()
    return false
  end
  local db = R.CharDB()
  db.upgraded[item.slot] = { name = item.name, rank = item.rank }
  Place(item.slot)
  Clear() -- the old rank the slot handed back (or ours, if placing failed)
  if R.SlotSpell(item.slot) == item.to then
    return true
  end
  db.upgraded[item.slot] = nil
  return false
end

-- Passes ------------------------------------------------------------------------------------------------------------

local function Merge(names)
  if names == nil or R.pending == true then
    R.pending = true
    return
  end
  R.pending = R.pending or {}
  for name in pairs(names) do
    R.pending[name] = true
  end
end

function R.Line(name, sub, rank, count)
  local to = sub or (rank and L["Rank %d"]:format(rank)) or L["its new rank"]
  if count == 1 then
    return L["Updated %s to %s on 1 button."]:format(name, to)
  end
  return L["Updated %s to %s on %d buttons."]:format(name, to, count)
end

-- One pass. names: { [name] = true } or nil (every spell). manual: from "Update now" (says when nothing changed).
-- Returns the number of buttons changed, or nil when it has to wait (combat, a full cursor).
function R.Run(names, manual)
  if not Q.running then
    return nil
  end
  if InCombatLockdown() then
    Merge(names)
    R.Wait("PLAYER_REGEN_ENABLED")
    if manual then
      ns.Say(L["Your action bars get their new ranks after the fight."])
    end
    return nil
  end
  if R.CursorBusy() then
    Merge(names)
    R.Wait("CURSOR_CHANGED")
    if manual then
      ns.Say(L["Your action bars get their new ranks once your cursor is empty."])
    end
    return nil
  end
  local plan = R.Plan(names)
  local done, order = {}, {}
  local total = 0
  for _, item in ipairs(plan) do
    if R.Upgrade(item) then
      if not done[item.name] then
        done[item.name] = { count = 0, sub = item.sub, rank = item.rank }
        order[#order + 1] = item.name
      end
      done[item.name].count = done[item.name].count + 1
      total = total + 1
    elseif R.CursorBusy() or InCombatLockdown() then
      Merge(names)
      break
    end
  end
  for _, name in ipairs(order) do
    local entry = done[name]
    ns.Say(R.Line(name, entry.sub, entry.rank, entry.count))
  end
  if manual and total == 0 then
    ns.Say(L["Your action bars already have the highest ranks you know."])
  end
  return total
end

-- Runs what was waiting (after combat, once the cursor is empty).
function R.RunPending()
  local pending = R.pending
  if not pending or InCombatLockdown() or R.CursorBusy() then
    return
  end
  R.pending = nil
  R.Unwait()
  R.Run(pending ~= true and pending or nil)
end

local OnEvent -- below

-- Our event frame (made the first time it is needed: at Start, or when "Update now" has to wait).
function R.Frame()
  if not R.events then
    R.events = CreateFrame("Frame")
    R.events:SetScript("OnEvent", function(...)
      local ok, err = pcall(OnEvent, ...)
      if not ok then
        geterrorhandler()(err)
      end
    end)
  end
  return R.events
end

function R.Wait(event)
  local frame = R.Frame()
  pcall(frame.RegisterEvent, frame, event)
end

function R.Unwait()
  if R.events then
    R.events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    R.events:UnregisterEvent("CURSOR_CHANGED")
  end
end

-- Learned spells wait for the spellbook to have them (SPELLS_CHANGED, or a second later).
R.learned = {}
function R.RunLearned()
  if not next(R.learned) then
    return
  end
  local names = R.learned
  R.learned = {}
  if Q.On(KEY) then
    R.Run(names)
  end
end

function R.Learned(spellID)
  local id = Num(spellID)
  local name = id and R.Name(id)
  if not name then
    return
  end
  R.learned[name] = true
  C_Timer.After(R.LEARN_WAIT, R.RunLearned)
end

-- A slot changed: did the player put a lower rank back where we upgraded (remember it), or move on?
function R.SlotChanged(slot)
  local db = R.CharDB()
  local slots = {}
  slot = Num(slot)
  if not slot or slot == 0 then
    for known in pairs(db.upgraded) do
      slots[#slots + 1] = known
    end
    for known in pairs(db.pinned) do
      slots[#slots + 1] = known
    end
  else
    slots[1] = slot
  end
  for _, index in ipairs(slots) do
    local id = R.SlotSpell(index)
    local name = id and R.Name(id)
    local record = db.upgraded[index]
    if record then
      if name ~= record.name then
        db.upgraded[index] = nil
      else
        local rank = R.RankOf(id)
        if rank and record.rank and rank < record.rank then
          db.pinned[index] = name
          db.upgraded[index] = nil
        end
      end
    end
    local pin = db.pinned[index]
    if pin and (name ~= pin or R.IsHighest(id) == true) then
      db.pinned[index] = nil
    end
  end
end

function OnEvent(_, event, arg)
  if event == "LEARNED_SPELL_IN_SKILL_LINE" then
    if Q.On(KEY) then
      R.Learned(arg)
    end
  elseif event == "SPELLS_CHANGED" then
    R.RunLearned()
  elseif event == "ACTIONBAR_SLOT_CHANGED" then
    R.SlotChanged(arg)
  elseif event == "PLAYER_REGEN_ENABLED" or event == "CURSOR_CHANGED" then
    R.RunPending()
  end
end

function R.Start()
  if R.started then
    return
  end
  R.started = true
  local frame = R.Frame()
  for _, event in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED" }) do
    pcall(frame.RegisterEvent, frame, event)
  end
  if R.pending then
    R.Wait("PLAYER_REGEN_ENABLED")
    R.Wait("CURSOR_CHANGED")
  end
end

function R.Stop()
  if not R.started then
    return
  end
  R.started = false
  R.pending = nil
  R.learned = {}
  if R.events then
    R.events:UnregisterAllEvents()
  end
end

function R.Enable()
  if Q.DB()[KEY] then
    R.Start()
  end
end

function R.Changed(on)
  if on then
    R.Start()
  else
    R.Stop()
  end
end

function R.UpdateNow()
  if not Q.running then
    return nil
  end
  return R.Run(nil, true)
end

Q.AddToggle({
  key = KEY,
  name = L["Put new spell ranks on your action bars"],
  desc = L["When you learn a higher rank of a spell, your action buttons with a lower rank of it get the new one (after the fight if you are in one). A lower rank kept beside a higher one is left alone (for downranking), and so is a button where you put a lower rank back yourself. Macros and items are never touched."],
  order = 55,
  Enable = R.Enable,
  Changed = R.Changed,
  options = {
    { key = "spellRanksNow", kind = "button", name = L["Update now"], Click = function() R.UpdateNow() end },
  },
})
