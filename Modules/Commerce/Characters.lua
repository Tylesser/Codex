local addonName, ns = ...

-- Commerce module: every character at a glance. Ported from Tylesser - Commerce Authority's Characters.lua
-- (CodexDB.commerce.characters; "characters" tables are data, kept out of profiles).

local C = ns.commerce
local L = ns.L

-- Every character at a glance (2026-11-28, the user's request): each character's Commerce Authority standing,
-- Merchant's Favor and the writs and crates in its bags, saved account-wide in CodexDB.commerce.characters
-- ["Realm-Name"] when it logs in and as they change (at most every 2 s), shown on the window's Characters tab.
-- Characters with nothing to show (no reputation, no Favor, no writs or crates) are not saved.

local SAVE_DELAY = 2

local function Readable(value)
  return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- "Realm-Name" of the character you play, or nil before the game knows it.
function C.CharacterKey()
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if not (Readable(name) and Readable(realm)) or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  return realm .. "-" .. name, name, realm
end

-- This character's entry as saved (nil when it has nothing to show).
function C.CharacterRecord(counts)
  local key, name, realm = C.CharacterKey()
  if not key then
    return nil
  end
  local faction = C.Faction()
  local favor = C.Favor()
  local summary = C.BagSummary(counts or C.BagCounts())
  local bagThings = summary.writs + summary.sealedWrits + summary.crates + summary.toFill
  if not faction and (favor or 0) == 0 and bagThings == 0 then
    return nil
  end
  local _, class = UnitClass and UnitClass("player")
  return {
    name = name, realm = realm, class = Readable(class) and class or nil, side = C.Side(),
    standingID = faction and faction.standingID, value = faction and faction.value, min = faction and faction.min,
    max = faction and faction.max, favor = favor,
    writs = summary.writs, writRep = summary.writRep, sealedWrits = summary.sealedWrits,
    crates = summary.crates, crateFavor = summary.crateFavor, toFill = summary.toFill,
    time = time and time() or 0,
  }
end

function C.SaveCharacter(counts)
  local db = C.DB()
  if not db then
    return nil
  end
  db.characters = db.characters or {}
  local key = C.CharacterKey()
  local record = key and C.CharacterRecord(counts)
  if record then
    db.characters[key] = record
  end
  return record
end

-- Saves this character a little later (events come in bursts: bags, currency, reputation).
local pending = false
function C.RequestSaveCharacter()
  if not (C_Timer and C_Timer.After) then
    C.SaveCharacter()
    return
  end
  if pending then
    return
  end
  pending = true
  C_Timer.After(SAVE_DELAY, function()
    pending = false
    C.SaveCharacter()
  end)
end

function C.ForgetCharacter(key)
  local db = C.DB()
  if db and db.characters and key ~= C.CharacterKey() then
    db.characters[key] = nil
    return true
  end
  return false
end

-- The saved characters: { { key, record, current }, ... }, the one you play first, then by standing and
-- reputation, then by name.
function C.Characters()
  local list = {}
  local db = C.DB()
  local current = C.CharacterKey()
  for key, record in pairs(db and db.characters or {}) do
    if type(record) == "table" and record.name then
      list[#list + 1] = { key = key, record = record, current = key == current }
    end
  end
  table.sort(list, function(a, b)
    if a.current ~= b.current then
      return a.current
    end
    local sa, sb = a.record.standingID or 0, b.record.standingID or 0
    if sa ~= sb then
      return sa > sb
    end
    local va, vb = a.record.value or 0, b.record.value or 0
    if va ~= vb then
      return va > vb
    end
    return a.key < b.key
  end)
  return list
end

-- What every saved character holds together: { favor, writs, writRep, crates, toFill }.
function C.CharacterTotals(list)
  local totals = { favor = 0, writs = 0, writRep = 0, crates = 0, toFill = 0 }
  for _, entry in ipairs(list or C.Characters()) do
    local record = entry.record
    totals.favor = totals.favor + (record.favor or 0)
    totals.writs = totals.writs + (record.writs or 0) + (record.sealedWrits or 0)
    totals.writRep = totals.writRep + (record.writRep or 0)
    totals.crates = totals.crates + (record.crates or 0)
    totals.toFill = totals.toFill + (record.toFill or 0)
  end
  return totals
end

-- "today", "yesterday", "5 days ago"
function C.SeenText(when)
  local now = time and time() or 0
  local days = math.floor(math.max(now - (when or now), 0) / 86400)
  if days < 1 then
    return L["today"]
  elseif days == 1 then
    return L["yesterday"]
  end
  return L["%d days ago"]:format(days)
end

-- The two lines of a character's row: "Honored 1,234 / 12,000" and "3 writs (375 rep), 2 crates, 1 to fill".
function C.CharacterLines(record)
  local standing
  if record.standingID then
    local span = math.max((record.max or 0) - (record.min or 0), 0)
    local done = math.max((record.value or 0) - (record.min or 0), 0)
    standing = record.standingID >= 8 and C.StandingName(record.standingID)
      or ("%s %s / %s"):format(C.StandingName(record.standingID), C.Number(done), C.Number(span))
  else
    standing = L["no reputation yet"]
  end
  local parts = {}
  local writs = (record.writs or 0) + (record.sealedWrits or 0)
  if writs > 0 then
    parts[#parts + 1] = (writs == 1 and L["1 writ"] or L["%d writs"]:format(writs))
      .. ((record.writRep or 0) > 0 and (" " .. L["(%s rep)"]:format(C.Number(record.writRep))) or "")
  end
  if (record.crates or 0) > 0 then
    parts[#parts + 1] = record.crates == 1 and L["1 filled crate"] or L["%d filled crates"]:format(record.crates)
  end
  if (record.toFill or 0) > 0 then
    parts[#parts + 1] = L["%d to fill"]:format(record.toFill)
  end
  return standing, #parts > 0 and table.concat(parts, ", ") or L["nothing in the bags"]
end
