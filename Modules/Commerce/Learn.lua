local addonName, ns = ...

-- Commerce module, part 4: what turn-ins really give (Favor per crate, reputation per writ, who took a writ).
-- Ported from Tylesser - Commerce Authority (same author, MIT); see Modules/Commerce/Settings.lua.

local C = ns.commerce

-- Learns what turn-ins really give, so the estimates stop being guesses.
-- Each turn-in is its own record: { questID, opened, time, before (bag counts when its dialog opened), favor,
-- writ, repDone, resolved }.
-- - Crates: Favor that arrives while the turn-in dialog is open, or up to WINDOW seconds after
--   QUEST_TURNED_IN, belongs to that turn-in. WINDOW seconds later (or as soon as the next dialog opens) the
--   bags are compared with the snapshot; exactly one crate gone = that crate. Learned per crate level and kind
--   (raw or made goods), the same key the tooltips use.
-- - Writs: the reputation message within WINDOW seconds of a writ quest's turn-in, in either order.
--   And who took the writ: the NPC of the turn-in dialog and where you stood (C.LearnCustomer).
-- Also keeps this session's totals for the window.

C.session = { favor = 0, rep = 0, crates = 0, writs = 0, bonuses = 0 }

local WINDOW = 3          -- seconds after QUEST_TURNED_IN in which Favor or reputation still belongs to it
local DIALOG_LIMIT = 120  -- a turn-in dialog left open longer than this no longer collects Favor
local dialog              -- the turn-in record whose dialog is open (QUEST_COMPLETE, no QUEST_TURNED_IN yet)
local latest              -- the last turned-in record
local lastFavor           -- Merchant's Favor last seen; nil until it is known
local pendingRep          -- { amount, time }: a Commerce Authority reputation gain not yet given to a writ

local function Now()
  return GetTime and GetTime() or 0
end

local function Learned()
  return C.db.learned
end

local function Refresh()
  if C.RequestRefresh then
    C.RequestRefresh()
  end
end

local function Record(map, key, amount)
  local seen = map[key] or { n = 0, total = 0 }
  seen.n = seen.n + 1
  seen.total = seen.total + amount
  seen.last = amount
  seen.min = seen.min and math.min(seen.min, amount) or amount
  seen.max = seen.max and math.max(seen.max, amount) or amount
  seen.values = seen.values or {}
  seen.values[amount] = (seen.values[amount] or 0) + 1
  map[key] = seen
  return seen
end

-- The one crate that left the bags between `before` and `after`, or nil (none, or more than one kind).
local function CrateGone(before, after)
  local found
  for itemID, count in pairs(before or {}) do
    if (after[itemID] or 0) < count then
      local info = C.CrateInfo(itemID)
      if info then
        if found then
          return nil
        end
        found = info
      end
    end
  end
  return found
end

local function RecordCrateFavor(crate, gained)
  local seen = Learned().crates[crate.key]
  local usual = C.UsualValue(seen)
  -- Twice the usual amount with the Performance Bonus talent: the bonus. Counted, not stored as usual.
  if C.HasPerformanceBonus() and usual and gained >= usual * 2 then
    C.session.bonuses = C.session.bonuses + 1
    Learned().bonuses = (Learned().bonuses or 0) + 1
  else
    Record(Learned().crates, crate.key, gained)
  end
end

-- Compares a turn-in's bags (with `after`, or the bags now) and learns the crate's Favor.
function C.ResolveTurnIn(turnIn, after)
  if not turnIn or turnIn.resolved then
    return
  end
  turnIn.resolved = true
  local crate = CrateGone(turnIn.before, after or C.BagCounts())
  if crate then
    C.session.crates = C.session.crates + 1
    if turnIn.favor > 0 then
      RecordCrateFavor(crate, turnIn.favor)
    end
  end
  Refresh()
end

local function NewTurnIn()
  return { opened = Now(), favor = 0 }
end

function C.OnQuestComplete()
  local before = C.BagCounts()
  -- The previous turn-in ends here: its crate has left the bags by now, and this dialog's bags are its "after".
  if latest and not latest.resolved then
    C.ResolveTurnIn(latest, before)
  end
  dialog = NewTurnIn()
  dialog.before = before
  dialog.customer = C.CurrentCustomer() -- the NPC you're talking to, in case this is a writ
end

local function RecordWritRep(turnIn, amount)
  turnIn.repDone = true
  Record(Learned().writs, turnIn.questID, amount)
end

function C.OnQuestTurnedIn(questID)
  local turnIn = dialog or NewTurnIn()
  dialog = nil
  if latest and latest ~= turnIn and not latest.resolved then
    C.ResolveTurnIn(latest, turnIn.before)
  end
  turnIn.questID = questID
  turnIn.time = Now()
  latest = turnIn
  local writID = C.WritForQuest(questID)
  if writID and C.WritTier(writID) then
    turnIn.writ = true
    C.session.writs = C.session.writs + 1
    C.LearnCustomer(writID, turnIn.customer or C.CurrentCustomer())
    if pendingRep and turnIn.time - pendingRep.time <= WINDOW then
      RecordWritRep(turnIn, pendingRep.amount)
      pendingRep = nil
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(WINDOW, function()
      C.ResolveTurnIn(turnIn)
    end)
  end
  Refresh()
end

-- The turn-in that Favor arriving now belongs to, or nil.
local function FavorTurnIn()
  local now = Now()
  if dialog and now - dialog.opened <= DIALOG_LIMIT then
    return dialog
  end
  if latest and not latest.resolved and now - latest.time <= WINDOW then
    return latest
  end
end

-- Merchant's Favor changed: count it, and give it to the turn-in it belongs to.
function C.OnFavorChanged()
  local quantity = C.Favor()
  if not quantity then
    return
  end
  -- The first reading is the starting balance, not a gain (see C.StartFavorTracking).
  if lastFavor and quantity > lastFavor then
    local gained = quantity - lastFavor
    C.session.favor = C.session.favor + gained
    local turnIn = FavorTurnIn()
    if turnIn then
      turnIn.favor = turnIn.favor + gained
    end
  end
  lastFavor = quantity
  Refresh()
end

-- Patterns from the game's own reputation messages ("Reputation with %s increased by %d."), so they also
-- match other languages; the English one as a fallback.
local repPatterns
local function RepPatterns()
  if repPatterns then
    return repPatterns
  end
  repPatterns = {}
  for _, key in ipairs({ "FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_ACH_BONUS",
    "FACTION_STANDING_INCREASED_BONUS", "FACTION_STANDING_INCREASED_DOUBLE_BONUS" }) do
    local format = _G[key]
    if type(format) == "string" then
      -- format specifiers to markers, escape the rest, then markers to captures
      local pattern = format:gsub("%%[%d%.]*([sdf])", "\1%1")
      pattern = pattern:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
      pattern = pattern:gsub("\1s", "(.-)")
      pattern = pattern:gsub("\1d", "(%%d+)")
      pattern = pattern:gsub("\1f", "[%%d%%.]+")
      repPatterns[#repPatterns + 1] = "^" .. pattern
    end
  end
  repPatterns[#repPatterns + 1] = "^Reputation with (.-) increased by (%d+)"
  return repPatterns
end

-- Faction name and amount from a reputation message, or nil.
function C.ParseRepMessage(message)
  if type(message) ~= "string" then
    return nil
  end
  for _, pattern in ipairs(RepPatterns()) do
    local name, amount = message:match(pattern)
    if name and tonumber(amount) then
      return name, tonumber(amount)
    end
  end
end

function C.OnRepMessage(message)
  local name, amount = C.ParseRepMessage(message)
  if not (name and C.IsCommerceFaction(name)) then
    return
  end
  C.session.rep = C.session.rep + amount
  if latest and latest.writ and not latest.repDone and Now() - latest.time <= WINDOW then
    RecordWritRep(latest, amount)
  else
    -- maybe for a writ whose QUEST_TURNED_IN comes next
    pendingRep = { amount = amount, time = Now() }
  end
  Refresh()
end

-- Takes the starting balance. Called a few seconds after entering the world, when the currency has loaded
-- (right at login it can still read 0, and the load would count as a gain); until then the first
-- CURRENCY_DISPLAY_UPDATE only sets the starting balance.
function C.StartFavorTracking()
  if lastFavor == nil then
    lastFavor = C.Favor()
  end
end

-- For tests.
function C.ResetLearningState()
  dialog, latest, lastFavor, pendingRep = nil, nil, nil, nil
  C.session = { favor = 0, rep = 0, crates = 0, writs = 0, bonuses = 0 }
end
