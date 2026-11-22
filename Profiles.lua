local addonName, ns = ...

-- Profiles (board R3-Setup): named copies of Codex's settings - modules on or off, theme, fonts, look, the
-- interface parts and every module's options. Never the data: auction prices and scans, shopping lists, bag
-- contents, characters' recipes, vendor prices, the CVars Highlight keeps, window and frame positions.
--
-- CodexDB.profiles = { [name] = { settings = { ... }, class = "Paladin", owner = "Realm-Name", time = time() } }
-- CodexDB.profileActive = the profile whose settings are in CodexDB right now
-- CodexDB.sharedProfile = the profile of every character without its own ("All characters"), default "Default"
-- CodexCharDB.profile   = this character's own profile ("This character"), nil = the shared one
--
-- CodexDB holds one set of settings for the account. A character that wants another profile gets it at
-- ADDON_LOADED, before the theme loads (ns.ApplyCharacterProfile, called from Events.lua): the settings in
-- CodexDB go back into their profile first. Switching in Settings does the same and then asks for a reload.
--
-- Export strings: "CDX1:" + base64 of our own plain serialization + ":" + an 8-digit checksum. Import parses
-- with our own parser (never loadstring), keeps only plain values, checks every key and type against this
-- install, and makes a new profile. Edit Mode layouts belong to the game and are not included.

local UI = ns.UI
local P = {}
ns.profilesAPI = P

P.DEFAULT = "Default"
P.PREFIX = "CDX1:"
P.VERSION = 1
local MAX_DEPTH = 16
local MAX_NODES = 20000
local MAX_STRING = 4000
local MAX_TEXT = 300000
local MAX_NAME = 32

-- What is never part of a profile -------------------------------------------------------------------------

local SKIP_TOP = { profiles = true, profileActive = true, sharedProfile = true, setupDone = true, setupStep = true, whatsNewSeen = true,
  window = true, folded = true, areaTabs = true, trainerSpells = true }
-- folded: which sections of the Codex window are folded (Areas.lua), not a setting; trainerSpells: the prices your
-- class trainers asked (Modules/QoL/FutureSpells.lua), data
local SKIP_PATH = {
  ["minimap.angle"] = true, -- where the button sits
  ["auction.realms"] = true, ["auction.lists"] = true,
  ["bags.characters"] = true, ["bags.hidden"] = true, ["bags.layout2"] = true,
  ["professions.characters"] = true, ["professions.vendor"] = true, ["professions.queue"] = true,
  ["highlight.saved"] = true, -- the player's own CVars
  ["movewindows.positions"] = true,
  ["skins.frames"] = true, ["skins.told"] = true, -- unit frame positions, a one-time hint
  ["skins.frameScale"] = true, -- unit frame sizes (Edit Mode, with the positions)
  -- Commerce: what turn-ins gave, faction IDs, window places (data, not settings)
  ["commerce.learned"] = true, ["commerce.factionIDs"] = true, ["commerce.position"] = true,
  ["commerce.npcPosition"] = true, ["vendorsearch.boxOffset"] = true,
  ["commerce.npcFolded"] = true,
}
-- data tables by name, wherever a module keeps them
local SKIP_ANY = { characters = true, realms = true, saved = true, positions = true }

local function Join(path, key)
  return path == "" and tostring(key) or (path .. "." .. tostring(key))
end

local function Skipped(path, key)
  local kind = type(key)
  if kind ~= "string" and kind ~= "number" then
    return true
  end
  if SKIP_ANY[key] then
    return true
  end
  if path == "" then
    return SKIP_TOP[key] or false
  end
  return SKIP_PATH[Join(path, key)] or false
end
P.Skipped = Skipped

local function Plain(value)
  local kind = type(value)
  if kind == "string" or kind == "boolean" then
    return true
  end
  return kind == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- A copy of the settings below `path` (plain values and tables only).
local function Copy(value, path, depth)
  if type(value) ~= "table" then
    if Plain(value) then
      return value -- false too
    end
    return nil
  end
  if depth > MAX_DEPTH then
    return nil
  end
  local out = {}
  for key, item in pairs(value) do
    if not Skipped(path, key) then
      out[key] = Copy(item, Join(path, key), depth + 1)
    end
  end
  return out
end

-- The settings in CodexDB now.
function P.Snapshot()
  return Copy(ns.db, "", 0)
end

local function Keys(source)
  local keys = {}
  for key in pairs(source) do
    keys[#keys + 1] = key
  end
  return keys
end

-- Puts `snap`'s settings into `target`: settings it lacks go (the defaults come back), data stays.
local function Merge(target, snap, path)
  for _, key in ipairs(Keys(target)) do
    if not Skipped(path, key) then
      local here, want = target[key], snap[key]
      if type(here) == "table" and (want == nil or type(want) == "table") then
        Merge(here, want or {}, Join(path, key)) -- the same table stays: modules keep their reference
      else
        target[key] = Copy(want, Join(path, key), 1)
      end
    end
  end
  for key, want in pairs(snap) do
    if target[key] == nil and not Skipped(path, key) then
      target[key] = Copy(want, Join(path, key), 1)
    end
  end
end
P.Merge = Merge

-- Profile records --------------------------------------------------------------------------------------

local function List()
  return ns.db.profiles
end

local function CharacterKey()
  return ns.CharacterKey()
end

-- The settings in CodexDB go back into their profile when the player logs out (only once profiles are used).
local saver
local function WatchLogout()
  if saver then
    return
  end
  saver = CreateFrame("Frame")
  saver:RegisterEvent("PLAYER_LOGOUT")
  saver:SetScript("OnEvent", function()
    if ns.db and type(ns.db.profiles) == "table" then
      P.Save()
    end
  end)
end

-- Makes the profile tables (the first time profiles are used) and repairs broken entries.
function P.Init()
  WatchLogout()
  local db = ns.db
  if type(db.profiles) ~= "table" then
    db.profiles = {}
  end
  for name, record in pairs(db.profiles) do
    if type(name) ~= "string" or type(record) ~= "table" or type(record.settings) ~= "table" then
      db.profiles[name] = nil
    end
  end
  if type(db.profileActive) ~= "string" then
    db.profileActive = P.DEFAULT
  end
  if type(db.sharedProfile) ~= "string" or not db.profiles[db.sharedProfile] then
    db.sharedProfile = db.profiles[P.DEFAULT] and P.DEFAULT or db.profileActive
  end
  if not db.profiles[db.profileActive] then
    db.profiles[db.profileActive] = { settings = P.Snapshot(), time = time() }
  end
  if ns.char and ns.char.profile ~= nil and not (type(ns.char.profile) == "string" and db.profiles[ns.char.profile]) then
    ns.char.profile = nil
  end
end

function P.Active()
  return ns.db.profileActive or P.DEFAULT
end

-- "character" when this character has its own profile, else "shared".
function P.Scope()
  local own = ns.char and ns.char.profile
  return (type(own) == "string" and List() and List()[own]) and "character" or "shared"
end

-- The profile this character should be using.
function P.Wanted()
  local list = List() or {}
  local own = ns.char and ns.char.profile
  if type(own) == "string" and list[own] then
    return own
  end
  local shared = ns.db.sharedProfile
  if type(shared) == "string" and list[shared] then
    return shared
  end
  return P.Active()
end

-- Stores the settings in CodexDB into the active profile.
function P.Save()
  local list = List()
  if type(list) ~= "table" then
    return
  end
  local name = P.Active()
  local record = list[name] or { time = time() }
  record.settings = P.Snapshot()
  list[name] = record
end

-- Puts a profile's settings into CodexDB (the current ones are saved first unless `noSave`).
function P.Load(name, noSave)
  local record = List()[name]
  if not record then
    return false
  end
  if not noSave then
    P.Save()
  end
  Merge(ns.db, record.settings, "")
  ns.db.profileActive = name
  ns.SetupDB() -- fills the defaults back in for every setting the profile doesn't set
  return true
end

local function Reload()
  if type(ns.NeedsReload) == "function" then
    ns.NeedsReload()
  else
    ns.pendingReload = true
    ns.Fire("RELOAD_STATE")
  end
end

-- Switches to another profile now; it takes full effect after a reload.
function P.SwitchTo(name)
  if name == P.Active() or not List()[name] then
    return false
  end
  P.Load(name)
  Reload()
  ns.Fire("PROFILE_CHANGED")
  return true
end

-- At ADDON_LOADED, before the theme loads: this character's profile, if it isn't the one in CodexDB.
function ns.ApplyCharacterProfile()
  if type(ns.db.profiles) ~= "table" then
    return -- profiles never used: nothing to do
  end
  P.Init()
  local wanted = P.Wanted()
  if wanted ~= P.Active() then
    P.Load(wanted)
  end
end

-- A name a player typed: trimmed, short, no escape codes. Returns the name or nil, why.
function P.CleanName(text)
  if type(text) ~= "string" then
    return nil, "Type a name first."
  end
  text = text:gsub("|", ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    return nil, "Type a name first."
  end
  if #text > MAX_NAME then
    text = text:sub(1, MAX_NAME):gsub("[\128-\191]+$", ""):gsub("[\192-\255]$", ""):gsub("%s+$", "")
  end
  return text
end

local function UniqueName(name)
  local list = List()
  if not list[name] then
    return name
  end
  for number = 2, 999 do
    local candidate = ("%s %d"):format(name, number)
    if not list[candidate] then
      return candidate
    end
  end
  return name .. " " .. tostring(time())
end

-- This character's own profile name (its name; with the realm when another character has that name).
function P.CharacterProfileName()
  local name = (UnitName and UnitName("player")) or "Character"
  local record = List()[name]
  if record and record.owner and ns.NormalizeCharacterKey(record.owner) ~= CharacterKey() then
    name = name .. " - " .. ns.RealmName()
  end
  return name
end

-- The scope switch: "character" gives this character its own profile (a copy of the settings it uses now,
-- or the one it had before), "shared" puts it back on the shared profile.
function P.SetScope(scope)
  P.Init()
  if scope == "character" then
    if P.Scope() == "character" then
      return false
    end
    local name = P.CharacterProfileName()
    ns.char.profile = name
    if List()[name] then
      return P.SwitchTo(name) -- the one it had before
    end
    -- a copy of the settings in use: nothing changes, so no reload
    P.Save()
    List()[name] = { settings = P.Snapshot(), class = UnitClass and (UnitClass("player")) or nil,
      owner = CharacterKey(), time = time() }
    ns.db.profileActive = name
    ns.Fire("PROFILE_CHANGED")
    return false
  end
  ns.char.profile = nil
  return P.SwitchTo(P.Wanted())
end

-- Picks a profile for this character (or for every character without its own).
function P.Pick(name)
  P.Init()
  if not List()[name] then
    return false
  end
  if P.Scope() == "character" then
    ns.char.profile = name
  else
    ns.db.sharedProfile = name
  end
  return P.SwitchTo(name)
end

-- New (the default settings) or a copy of the settings in use. Returns the name or nil, why.
function P.Create(text, copy)
  P.Init()
  local name, why = P.CleanName(text)
  if not name then
    return nil, why
  end
  if List()[name] then
    return nil, ("There is already a profile called %s."):format(name)
  end
  P.Save()
  List()[name] = { settings = copy and P.Snapshot() or {}, time = time() }
  if copy then
    -- the same settings: no reload, just follow the new name
    if P.Scope() == "character" then
      ns.char.profile = name
    else
      ns.db.sharedProfile = name
    end
    ns.db.profileActive = name
    ns.Fire("PROFILE_CHANGED")
  else
    P.Pick(name)
  end
  return name
end

-- The profile in use back to the default settings (data stays).
function P.Reset()
  P.Init()
  local record = List()[P.Active()]
  record.settings = {}
  Merge(ns.db, {}, "")
  ns.SetupDB()
  Reload()
  ns.Fire("PROFILE_CHANGED")
  return true
end

-- Deletes the profile in use and goes back to the shared one (or Default). Default itself stays.
function P.Delete()
  P.Init()
  local name = P.Active()
  if name == P.DEFAULT then
    return false
  end
  local list = List()
  if not list[P.DEFAULT] then
    list[P.DEFAULT] = { settings = {}, time = time() }
  end
  local target = ns.db.sharedProfile
  if target == name or not list[target] then
    target = P.DEFAULT
  end
  list[name] = nil
  if ns.char.profile == name then
    ns.char.profile = nil
  end
  if ns.db.sharedProfile == name then
    ns.db.sharedProfile = target
  end
  P.Load(target, true)
  Reload()
  ns.Fire("PROFILE_CHANGED")
  return true
end

-- Serializer: S<length>:<bytes>  N<number>;  B1 / B0  T<key><value>...E ------------------------------------

local function NumberText(n)
  if n == math.floor(n) and n > -2147483648 and n < 2147483648 then
    return ("%d"):format(n)
  end
  return ("%.17g"):format(n)
end

local function KeyOrder(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then
    return ta == "number"
  end
  return a < b
end

local function Write(value, out, depth)
  local kind = type(value)
  if kind == "string" then
    out[#out + 1] = "S" .. #value .. ":" .. value
  elseif kind == "number" then
    if not Plain(value) then
      return false
    end
    out[#out + 1] = "N" .. NumberText(value) .. ";"
  elseif kind == "boolean" then
    out[#out + 1] = value and "B1" or "B0"
  elseif kind == "table" then
    if depth >= MAX_DEPTH then
      return false
    end
    out[#out + 1] = "T"
    local keys = {}
    for key in pairs(value) do
      local keyKind = type(key)
      if keyKind == "string" or (keyKind == "number" and Plain(key)) then
        keys[#keys + 1] = key
      end
    end
    table.sort(keys, KeyOrder) -- the same settings give the same string
    for _, key in ipairs(keys) do
      local mark = #out
      if not (Write(key, out, depth + 1) and Write(value[key], out, depth + 1)) then
        for index = #out, mark + 1, -1 do
          out[index] = nil -- functions and the like are left out
        end
      end
    end
    out[#out + 1] = "E"
  else
    return false
  end
  return true
end

function P.Serialize(value)
  local out = {}
  if not Write(value, out, 0) then
    return nil
  end
  return table.concat(out)
end

local function Read(raw, pos, depth, budget)
  budget.nodes = budget.nodes + 1
  if budget.nodes > MAX_NODES then
    return nil
  end
  local tag = raw:sub(pos, pos)
  if tag == "S" then
    local digits, start = raw:match("^(%d+):()", pos + 1)
    if not digits or #digits > 7 then
      return nil
    end
    local stop = start + tonumber(digits) - 1
    if stop > #raw then
      return nil
    end
    return raw:sub(start, stop), stop + 1
  elseif tag == "N" then
    local digits, after = raw:match("^([%-%+%d%.eE]+);()", pos + 1)
    local number = digits and #digits <= 32 and tonumber(digits)
    if not number or not Plain(number) then
      return nil
    end
    return number, after
  elseif tag == "B" then
    local flag = raw:sub(pos + 1, pos + 1)
    if flag == "1" then
      return true, pos + 2
    elseif flag == "0" then
      return false, pos + 2
    end
    return nil
  elseif tag == "T" then
    if depth >= MAX_DEPTH then
      return nil
    end
    local out = {}
    pos = pos + 1
    while true do
      local mark = raw:sub(pos, pos)
      if mark == "E" then
        return out, pos + 1
      elseif mark == "" then
        return nil
      end
      local key, value
      key, pos = Read(raw, pos, depth + 1, budget)
      if type(key) ~= "string" and type(key) ~= "number" then
        return nil
      end
      value, pos = Read(raw, pos, depth + 1, budget)
      if value == nil then
        return nil
      end
      out[key] = value
    end
  end
  return nil
end

-- The value of a serialized string, or nil when it is not exactly one well-formed value.
function P.Deserialize(raw)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end
  local value, after = Read(raw, 1, 0, { nodes = 0 })
  if value == nil or after ~= #raw + 1 then
    return nil
  end
  return value
end

-- Base64 and a checksum (arithmetic only: the game's Lua has no bit operators) --------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local CHAR, INDEX = {}, {}
for index = 1, 64 do
  local char = ALPHABET:sub(index, index)
  CHAR[index - 1] = char
  INDEX[char] = index - 1
end

local function Encode64(raw)
  local out = {}
  for index = 1, #raw, 3 do
    local a, b, c = raw:byte(index, index + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    out[#out + 1] = CHAR[math.floor(n / 262144)] .. CHAR[math.floor(n / 4096) % 64]
      .. (b and CHAR[math.floor(n / 64) % 64] or "=") .. (c and CHAR[n % 64] or "=")
  end
  return table.concat(out)
end

local function Decode64(text)
  if #text == 0 then
    return ""
  end
  if #text % 4 ~= 0 then
    return nil
  end
  local out = {}
  for index = 1, #text, 4 do
    local s3, s4 = text:sub(index + 2, index + 2), text:sub(index + 3, index + 3)
    local v1, v2 = INDEX[text:sub(index, index)], INDEX[text:sub(index + 1, index + 1)]
    local v3, v4 = INDEX[s3], INDEX[s4]
    local last = index + 3 == #text
    if not v1 or not v2 then
      return nil
    end
    if not v3 and not (last and s3 == "=" and s4 == "=") then
      return nil
    end
    if not v4 and not (last and s4 == "=") then
      return nil
    end
    local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
    out[#out + 1] = string.char(math.floor(n / 65536)) .. (v3 and string.char(math.floor(n / 256) % 256) or "")
      .. (v4 and string.char(n % 256) or "")
  end
  return table.concat(out)
end

local function Checksum(raw)
  local a, b = 1, 0
  for index = 1, #raw do
    a = (a + raw:byte(index)) % 65521
    b = (b + a) % 65521
  end
  return ("%04x%04x"):format(b, a)
end

P.Encode64, P.Decode64, P.Checksum = Encode64, Decode64, Checksum

-- Any plain value to an export string.
function P.Encode(value)
  local raw = P.Serialize(value)
  if not raw then
    return nil
  end
  return P.PREFIX .. Encode64(raw) .. ":" .. Checksum(raw)
end

local DAMAGED = "The string is damaged: copy the whole string again."

-- An export string back to its value, or nil, why.
function P.Decode(text)
  if type(text) ~= "string" then
    return nil, "Paste a Codex profile string first."
  end
  text = text:gsub("%s+", "") -- line breaks and spaces from pasting
  if text == "" then
    return nil, "Paste a Codex profile string first."
  end
  if #text > MAX_TEXT then
    return nil, "That is too long to be a Codex profile."
  end
  local version = text:match("^CDX(%d+):")
  if not version then
    return nil, "That isn't a Codex profile string (they start with CDX1:)."
  end
  if tonumber(version) ~= P.VERSION then
    return nil, "That profile comes from a newer Codex. Update Codex and try again."
  end
  local body, sum = text:sub(#P.PREFIX + 1):match("^([A-Za-z0-9%+/=]+):(%x%x%x%x%x%x%x%x)$")
  if not body then
    return nil, DAMAGED
  end
  local raw = Decode64(body)
  if not raw or Checksum(raw) ~= sum:lower() then
    return nil, DAMAGED
  end
  local value = P.Deserialize(raw)
  if value == nil then
    return nil, DAMAGED
  end
  return value
end

-- Import checks ------------------------------------------------------------------------------------------

local CORE_KEYS = { theme = true, modules = true, minimap = true, skins = true, scale = true, fonts = true, look = true }
local LOOK_VALUES = { accent = { theme = true, class = true }, shadows = "boolean", strips = "boolean" }
local SHAPES = { round = true, square = true, header = true }
local FRAME_STYLES = { compact = true, panel = true, bars = true }

-- `value` from an import; `current` is what this install has in the same place (nil when it has nothing).
local function Clean(value, current, path, depth)
  if type(value) == "table" then
    if (current ~= nil and type(current) ~= "table") or depth > MAX_DEPTH then
      return nil
    end
    local out = {}
    for key, item in pairs(value) do
      local keyOk = (type(key) == "string" and #key <= 64) or (type(key) == "number" and Plain(key))
      if keyOk and not Skipped(path, key) then
        out[key] = Clean(item, type(current) == "table" and current[key] or nil, Join(path, key), depth + 1)
      end
    end
    return out
  end
  if not Plain(value) or type(current) == "table" then
    return nil
  end
  if current ~= nil and type(current) ~= type(value) then
    return nil -- a number where this install keeps a switch, and so on
  end
  if type(value) == "string" and #value > MAX_STRING then
    return nil
  end
  return value
end

-- An imported settings table, reduced to what this install knows, with the right types.
function P.Sanitize(settings)
  local out = {}
  if type(settings) ~= "table" then
    return out
  end
  for key, value in pairs(settings) do
    if type(key) == "string" and (CORE_KEYS[key] or ns.modules[key] or ns.db[key] ~= nil) and not Skipped("", key) then
      out[key] = Clean(value, ns.db[key], key, 1)
    end
  end
  if out.theme ~= nil and not (type(out.theme) == "string" and ns.ThemeInfo(out.theme)) then
    out.theme = nil
  end
  if out.scale ~= nil and not (type(out.scale) == "number" and out.scale >= 0.7 and out.scale <= 1.4) then
    out.scale = nil
  end
  if type(out.fonts) == "table" then
    for slot, key in pairs(out.fonts) do
      if type(key) ~= "string" or ns.FontInfo(key).key ~= key then
        out.fonts[slot] = nil
      end
    end
  end
  if type(out.modules) == "table" then
    for id, on in pairs(out.modules) do
      if type(on) ~= "boolean" then
        out.modules[id] = nil
      end
    end
  end
  if type(out.look) == "table" then
    for key, value in pairs(out.look) do
      local allowed = LOOK_VALUES[key]
      if allowed == "boolean" and type(value) ~= "boolean" or type(allowed) == "table" and not allowed[value] then
        out.look[key] = nil
      end
    end
  end
  if type(out.skins) == "table" then
    if out.skins.minimapShape ~= nil and not SHAPES[out.skins.minimapShape] then
      out.skins.minimapShape = nil
    end
    if out.skins.frameStyle ~= nil and not FRAME_STYLES[out.skins.frameStyle] then
      out.skins.frameStyle = nil
    end
    if out.skins.healthColor ~= nil and out.skins.healthColor ~= "class" then
      out.skins.healthColor = nil
    end
    if type(out.skins.auraPos) == "table" then
      for unit, place in pairs(out.skins.auraPos) do
        if place ~= "above" and place ~= "right" and place ~= "left" then
          out.skins.auraPos[unit] = nil
        end
      end
    elseif out.skins.auraPos ~= nil then
      out.skins.auraPos = nil
    end
    if out.skins.nameplateGlow ~= nil and out.skins.nameplateGlow ~= false then
      out.skins.nameplateGlow = nil
    end
    if out.skins.firstNameOnly ~= nil and out.skins.firstNameOnly ~= true then
      out.skins.firstNameOnly = nil
    end
    if out.skins.enabled ~= nil and type(out.skins.enabled) ~= "boolean" then
      out.skins.enabled = nil
    end
    if type(out.skins.parts) == "table" then
      for id, on in pairs(out.skins.parts) do
        if type(on) ~= "boolean" then
          out.skins.parts[id] = nil
        end
      end
    end
  end
  return out
end

-- The export string of a profile (the one in use: its live settings).
function P.Export(name)
  P.Init()
  name = name or P.Active()
  local settings = name == P.Active() and P.Snapshot() or (List()[name] and List()[name].settings)
  if not settings then
    return nil
  end
  return P.Encode({ v = P.VERSION, name = name, settings = settings })
end

-- Makes a new profile from an export string. Returns its name, or nil, why.
function P.Import(text)
  local data, why = P.Decode(text)
  if not data then
    return nil, why
  end
  if type(data) ~= "table" or data.v ~= P.VERSION or type(data.settings) ~= "table" then
    return nil, "That isn't a Codex profile string."
  end
  P.Init()
  local name = UniqueName(P.CleanName(data.name) or "Imported")
  List()[name] = { settings = P.Sanitize(data.settings), time = time(), imported = true }
  ns.Fire("PROFILE_CHANGED")
  return name
end

-- The profile names, Default first.
function P.Names()
  local names = {}
  for name in pairs(List() or {}) do
    if name ~= P.DEFAULT then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b)
    return a:lower() < b:lower()
  end)
  if List() and List()[P.DEFAULT] then
    table.insert(names, 1, P.DEFAULT)
  end
  return names
end


-- Settings > Profiles ----------------------------------------------------------------------------------

-- A multi-line text field that scrolls inside a box.
local function TextArea(parent, width, height)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width, height)
  UI.Inset(parent, holder)
  local scroll = CreateFrame("ScrollFrame", nil, holder)
  scroll:SetPoint("TOPLEFT", 7, -5)
  scroll:SetPoint("BOTTOMRIGHT", -7, 5)
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetMaxLetters(0)
  box:SetSize(width - 14, height - 10)
  UI.Font(box, "body", 11, "text")
  scroll:SetScrollChild(box)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  box:SetScript("OnCursorChanged", function(_, _, y, _, lineHeight)
    local offset = scroll:GetVerticalScroll() or 0
    local visible = scroll:GetHeight() or height
    local top = -(y or 0)
    if top < offset then
      scroll:SetVerticalScroll(top)
    elseif top + (lineHeight or 0) > offset + visible then
      scroll:SetVerticalScroll(top + (lineHeight or 0) - visible)
    end
  end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 30)))
  end)
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function()
    box:SetFocus()
  end)
  holder.box = box
  return holder
end

-- A button that asks once more before it acts ("Sure?" for four seconds).
local function Confirming(button, label, action)
  button:SetScript("OnClick", function(self)
    if self.armed and GetTime() - self.armed < 4 then
      self.armed = nil
      self:SetText(label)
      action()
    else
      self.armed = GetTime()
      self:SetText("Sure?")
      C_Timer.After(4, function()
        if self.armed and GetTime() - self.armed >= 3.9 then
          self.armed = nil
          self:SetText(label)
        end
      end)
    end
  end)
end

function ns.BuildProfiles(body, width, register)
  P.Init()
  local leftWidth = math.floor((width - 28) * 0.48)
  local rightX = leftWidth + 28
  local rightWidth = width - rightX
  local refreshers = {}
  local function RefreshAll()
    for _, refresh in ipairs(refreshers) do
      refresh()
    end
  end

  -- who uses the profile
  local useLabel = UI.Section(body, "Who uses it")
  useLabel:SetPoint("TOPLEFT")
  local scope = ns.Segmented(body, { { key = "character", name = "This character" }, { key = "shared", name = "All characters" } },
    P.Scope, function(key)
      P.SetScope(key)
      RefreshAll()
    end, leftWidth)
  scope:SetPoint("TOPLEFT", useLabel, "BOTTOMLEFT", 0, -8)
  local scopeText = UI.Text(body, "body", 12, "muted")
  scopeText:SetPoint("TOPLEFT", scope, "BOTTOMLEFT", 0, -6)
  scopeText:SetWidth(leftWidth)
  scopeText:SetJustifyH("LEFT")
  refreshers[#refreshers + 1] = function()
    scope:Refresh()
    if P.Scope() == "character" then
      scopeText:SetText(("%s keeps its own settings."):format((UnitName and UnitName("player")) or "This character"))
    else
      scopeText:SetText("Every character without its own profile uses the one picked below.")
    end
  end

  -- the profiles
  local listLabel = UI.Section(body, "Profile")
  listLabel:SetPoint("TOPLEFT", scope, "BOTTOMLEFT", 0, -46)
  local list = UI.List(body, {
    rowHeight = 28,
    CreateRow = function(row)
      row.dot = row:CreateTexture(nil, "ARTWORK")
      row.dot:SetTexture("Interface\\AddOns\\Codex\\Media\\Circle")
      row.dot:SetSize(10, 10)
      row.dot:SetPoint("LEFT", 9, 0)
      row.ring = row:CreateTexture(nil, "BORDER")
      row.ring:SetTexture("Interface\\AddOns\\Codex\\Media\\Circle")
      row.ring:SetSize(14, 14)
      row.ring:SetPoint("CENTER", row.dot)
      row.name = UI.Text(row, "body", 13, "text")
      row.name:SetPoint("LEFT", row.dot, "RIGHT", 9, 0)
      row.name:SetWordWrap(false)
      row.note = UI.Text(row, "body", 11, "muted")
      row.note:SetPoint("RIGHT", -8, 0)
      row.name:SetPoint("RIGHT", row.note, "LEFT", -6, 0)
      local line = UI.Divider(row)
      line:SetPoint("BOTTOMLEFT")
      line:SetPoint("BOTTOMRIGHT")
      row:SetScript("OnClick", function(self)
        if self.item and P.Pick(self.item) then
          RefreshAll()
        end
      end)
    end,
    UpdateRow = function(row, name)
      local theme = ns.Theme()
      local inUse = name == P.Active()
      row.selected:SetShown(inUse)
      row.dot:SetVertexColor(UI.Unpack(inUse and theme.accent or { 0, 0, 0, 0.7 }))
      row.ring:SetVertexColor(UI.Unpack(theme.button.line))
      row.name:SetText(name)
      row.name:SetTextColor(UI.Unpack(inUse and theme.bright or theme.text))
      local note = ""
      if ns.char.profile == name then
        note = "this character"
      elseif ns.db.sharedProfile == name then
        note = "shared"
      elseif List()[name] then
        note = List()[name].class or (List()[name].imported and "imported") or ""
      end
      row.note:SetText(note)
    end,
  })
  list:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
  list:SetSize(leftWidth, 28 * 6 + 4)
  refreshers[#refreshers + 1] = function()
    list:SetItems(P.Names())
  end

  local buttons = {}
  local buttonWidth = math.floor((leftWidth - 18) / 4)
  for index, label in ipairs({ "New", "Copy", "Reset", "Delete" }) do
    local button = UI.Button(body, buttonWidth, 24, label)
    button:SetPoint("TOPLEFT", list, "BOTTOMLEFT", (index - 1) * (buttonWidth + 6), -8)
    buttons[label] = button
  end
  body.profileButtons = buttons

  local status = UI.Text(body, "body", 12, "muted")
  status:SetWidth(leftWidth)
  status:SetJustifyH("LEFT")
  local function Say(text, kind)
    status:SetText(text or "")
    status:SetTextColor(UI.Unpack(ns.Theme()[kind or "muted"] or ns.Theme().muted))
  end

  -- the name row for New and Copy
  local nameRow = CreateFrame("Frame", nil, body)
  nameRow:SetPoint("TOPLEFT", buttons.New, "BOTTOMLEFT", 0, -8)
  nameRow:SetSize(leftWidth, 24)
  local nameBox = UI.EditBox(nameRow, leftWidth - 2 * (buttonWidth + 6), 24)
  nameBox:SetPoint("LEFT")
  nameBox:SetMaxLetters(MAX_NAME)
  local create = UI.Button(nameRow, buttonWidth, 24, "Create")
  create:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
  local cancel = UI.Button(nameRow, buttonWidth, 24, "Cancel")
  cancel:SetPoint("LEFT", create, "RIGHT", 6, 0)
  nameRow:Hide()
  status:SetPoint("TOPLEFT", nameRow, "BOTTOMLEFT", 0, -6)
  local mode
  local function AskName(how)
    mode = how
    nameRow:Show()
    nameBox:SetText(how == "copy" and (P.Active() .. " copy") or "")
    nameBox:SetFocus()
    nameBox:HighlightText()
    Say(how == "copy" and "A copy of the settings you use now." or "A new profile starts with the default settings.")
  end
  local function Create()
    local name, why = P.Create(nameBox:GetText(), mode == "copy")
    if not name then
      Say(why, "warn")
      return
    end
    nameRow:Hide()
    nameBox:ClearFocus()
    Say(mode == "copy" and ("%s made and in use."):format(name) or ("%s made. It takes effect after a reload."):format(name))
    RefreshAll()
  end
  create:SetScript("OnClick", Create)
  nameBox:SetScript("OnEnterPressed", Create)
  cancel:SetScript("OnClick", function()
    nameRow:Hide()
    nameBox:ClearFocus()
    Say("")
  end)
  buttons.New:SetScript("OnClick", function()
    AskName("new")
  end)
  buttons.Copy:SetScript("OnClick", function()
    AskName("copy")
  end)
  Confirming(buttons.Reset, "Reset", function()
    P.Reset()
    Say(("%s is back to the default settings after a reload."):format(P.Active()))
    RefreshAll()
  end)
  Confirming(buttons.Delete, "Delete", function()
    local name = P.Active()
    if P.Delete() then
      Say(("%s deleted. %s takes over after a reload."):format(name, P.Active()))
    end
    RefreshAll()
  end)
  refreshers[#refreshers + 1] = function()
    buttons.Delete:SetEnabled(P.Active() ~= P.DEFAULT)
  end

  -- export
  local exportLabel = UI.Section(body, "Export")
  exportLabel:SetPoint("TOPLEFT", body, "TOPLEFT", rightX, 0)
  local export = TextArea(body, rightWidth, 96)
  export:SetPoint("TOPLEFT", exportLabel, "BOTTOMLEFT", 0, -8)
  local exportText = ""
  export.box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self:GetText() ~= exportText then
      self:SetText(exportText) -- read only
      self:HighlightText()
    end
  end)
  export.box:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  local selectAll = UI.Button(body, 100, 24, "Select all")
  selectAll:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -6)
  selectAll:SetScript("OnClick", function()
    export.box:SetFocus()
    export.box:HighlightText()
  end)
  local copyHint = UI.Text(body, "body", 12, "muted")
  copyHint:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
  copyHint:SetText("then press Ctrl+C to copy it.")
  body.exportBox = export.box
  refreshers[#refreshers + 1] = function()
    exportText = P.Export() or ""
    export.box:SetText(exportText)
    export.box:SetCursorPosition(0)
  end

  -- import
  local importLabel = UI.Section(body, "Import")
  importLabel:SetPoint("TOPLEFT", selectAll, "BOTTOMLEFT", 0, -18)
  local import = TextArea(body, rightWidth, 72)
  import:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -8)
  local placeholder = UI.Text(import, "body", 11, "muted")
  placeholder:SetPoint("TOPLEFT", 8, -6)
  placeholder:SetText("Paste a Codex profile string")
  import.box:SetScript("OnTextChanged", function(self)
    placeholder:SetShown((self:GetText() or "") == "")
  end)
  local importButton = UI.Button(body, 170, 26, "Import as new profile")
  importButton:SetPoint("TOPLEFT", import, "BOTTOMLEFT", 0, -6)
  local importNote = UI.Text(body, "body", 12, "muted")
  importNote:SetPoint("LEFT", importButton, "RIGHT", 8, 0)
  importNote:SetPoint("RIGHT", body, "RIGHT", 0, 0)
  importNote:SetJustifyH("LEFT")
  importNote:SetWordWrap(true)
  importNote:SetText("Edit Mode layouts are not included.")
  local importStatus = UI.Text(body, "body", 12, "muted")
  importStatus:SetPoint("TOPLEFT", importButton, "BOTTOMLEFT", 0, -6)
  importStatus:SetWidth(rightWidth)
  importStatus:SetJustifyH("LEFT")
  importButton:SetScript("OnClick", function()
    local name, why = P.Import(import.box:GetText())
    local theme = ns.Theme()
    if name then
      import.box:SetText("")
      import.box:ClearFocus()
      importStatus:SetText(("Imported as %s. Pick it in the list to use it."):format(name))
      importStatus:SetTextColor(UI.Unpack(theme.good))
      RefreshAll()
    else
      importStatus:SetText(why)
      importStatus:SetTextColor(UI.Unpack(theme.warn))
    end
  end)
  body.importBox = import.box
  body.importButton = importButton
  body.importStatus = importStatus

  local about = UI.Text(body, "body", 12, "muted")
  about:SetPoint("TOPLEFT", importStatus, "BOTTOMLEFT", 0, -14)
  about:SetWidth(rightWidth)
  about:SetJustifyH("LEFT")
  about:SetSpacing(2)
  about:SetText("A profile holds Codex's settings: modules on or off, theme, fonts, look, interface parts and "
    .. "module options. Prices, scans, shopping lists, bag contents and window positions are not part of it, "
    .. "so switching never loses them.")

  body.RefreshProfiles = RefreshAll
  if register then
    register(RefreshAll)
  end
  ns.On("PROFILE_CHANGED", RefreshAll)
  RefreshAll()
  body:SetHeight(18 + 8 + 28 + 46 + 18 + 6 + 28 * 6 + 4 + 8 + 24 + 8 + 24 + 30)
end
