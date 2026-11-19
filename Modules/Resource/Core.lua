local addonName, ns = ...

-- Personal bars (module "resource", off by default), part 1: settings and the timers behind the bars, with no
-- frames (Bars.lua draws them, Page.lua is the module's page). Under the character: health, power (mana, rage or
-- energy), a druid's mana while in a form, combo points (rogues, druids in cat form), a paladin's seal and the
-- swing timers (main hand, off hand, ranged). Text on the bars (none / amount / percentage / both) and the
-- layout (under the character, or upright beside it) are settings here too; Bars.lua draws them.
--
-- Five-second rule: spirit regeneration stops for five seconds after mana is spent. A spend is a cast that
-- succeeded (UNIT_SPELLCAST_SUCCEEDED) and a mana drop within PAIR seconds of it, either order; only while
-- UnitPower can be read (a secret value is skipped, no maths on it). Regeneration ticks: mana and energy come
-- every TICK seconds on the server's beat; an increase near the expected beat (or the first after a quiet spell)
-- sets the beat, other increases (potions) are ignored. Seals: the aura from C_UnitAuras while it can be read,
-- else the time from the seal cast we saw (seals last 30 s). Swings: PLAYER_SWING (duration, swing type),
-- PLAYER_SWING_RANGE_UPDATE (swing type, in range, range checked), UNIT_ATTACK_SPEED (haste changes the time left).

local R = {}
ns.resource = R

R.DEFAULTS = {
  health = true, power = true, fsr = true, ticks = true, druidMana = true, combo = true, seal = true,
  swing = true, ranged = true, standStill = true,
  text = "both", -- on the health, power and druid mana bars: "none", "value", "percent" or "both" (R.TEXT_MODES)
  layout = "under", -- "under" the character (rows) or "beside" it (health left, power right, upright)
  width = 150, show = "always", -- "always" or "combat"
  fade = true, -- out of combat the bars fade to FADED (with show = "always")
  sideGap = 160, sideHeight = 150, sideWidth = 10, -- "beside": the space between the bars, their height, width
}
-- Each size setting's range and step (the page's - and + buttons).
R.SIZES = {
  width = { 100, 320, 10 },
  sideGap = { 60, 400, 10 },
  sideHeight = { 80, 320, 10 },
  sideWidth = { 4, 24, 2 },
}
R.WIDTH_MIN, R.WIDTH_MAX, R.WIDTH_STEP = R.SIZES.width[1], R.SIZES.width[2], R.SIZES.width[3]
R.FADED = 0.35
R.DEFAULT_POS = { "TOP", "CENTER", 0, -120 } -- under the character (point, UIParent's point, x, y)
R.DEFAULT_POS_BESIDE = { "TOP", "CENTER", 0, 60 } -- the upright bars' tops, either side of the character

-- The text on the bars. Amount is the current value ("4,820", or "4.8K" with Settings' short numbers).
R.TEXT_MODES = {
  { key = "none", name = "None" },
  { key = "value", name = "Amount" },
  { key = "percent", name = "Percentage" },
  { key = "both", name = "Amount and percentage" },
}
R.LAYOUTS = {
  { key = "under", name = "Under the character" },
  { key = "beside", name = "Beside the character" },
}

local FSR, PAIR, TICK, TICK_SLACK, TICK_QUIET = 5, 0.6, 2, 0.35, 4.5
local SEAL_TIME = 30
R.FSR, R.TICK, R.SEAL_TIME = FSR, TICK, SEAL_TIME
R.SWING_HOLD = 1 -- a finished swing's row stays this long for the next swing (auto attack)
R.STAND_STILL = 0.5 -- the ranged swing's last half second: Auto Shot and wands need you standing still

local PT = Enum and Enum.PowerType or {}
R.MANA, R.RAGE, R.ENERGY, R.COMBO = PT.Mana or 0, PT.Rage or 1, PT.Energy or 3, PT.ComboPoints or 4

local SWING = Enum and Enum.PlayerSwingType or { MainHand = 0, OffHand = 1, Ranged = 2 }
R.SWING_KEYS = { "main", "off", "ranged" }
local SWING_OF = {}
if SWING.MainHand ~= nil then SWING_OF[SWING.MainHand] = "main" end
if SWING.OffHand ~= nil then SWING_OF[SWING.OffHand] = "off" end
if SWING.Ranged ~= nil then SWING_OF[SWING.Ranged] = "ranged" end

-- Settings ------------------------------------------------------------------------------------------------------

function R.DB()
  local db = ns.Fill(type(ns.db.resource) == "table" and ns.db.resource or {}, R.DEFAULTS)
  db.numbers = nil -- (the old on/off for numbers, before the text setting)
  ns.db.resource = db
  return db
end

local function Choice(list, value, fallback)
  for _, item in ipairs(list) do
    if item.key == value then
      return value
    end
  end
  return fallback
end

-- A size setting (R.SIZES), on its step and within its range.
function R.Size(key)
  local range = R.SIZES[key]
  local value = tonumber(R.DB()[key]) or R.DEFAULTS[key]
  value = math.floor(value / range[3] + 0.5) * range[3]
  return math.max(range[1], math.min(range[2], value))
end

function R.Width()
  return R.Size("width")
end

function R.TextMode()
  return Choice(R.TEXT_MODES, R.DB().text, R.DEFAULTS.text)
end

function R.Beside()
  return Choice(R.LAYOUTS, R.DB().layout, R.DEFAULTS.layout) == "beside"
end

-- A change from the page: saved, then the bars follow at once.
function R.Set(key, value)
  R.DB()[key] = value
  if R.running and R.Refresh then
    R.Refresh()
  end
  ns.Fire("RESOURCE_CHANGED")
end

-- Secret values -------------------------------------------------------------------------------------------------

function R.CanRead(value)
  return type(canaccessvalue) ~= "function" or canaccessvalue(value) and true or false
end
local CanRead = R.CanRead

function R.Readable(value)
  if CanRead(value) then
    return value
  end
end
local Readable = R.Readable

function R.Class()
  local _, class = UnitClass("player")
  return Readable(class)
end

-- The player's power type, readable or nil.
function R.PowerType()
  local powerType = UnitPowerType("player")
  return Readable(powerType)
end

-- State ---------------------------------------------------------------------------------------------------------

local st = { last = {}, tickAt = {}, swings = {}, out = {} }
R.state = st

local function Now()
  return GetTime()
end

-- Five-second rule ----------------------------------------------------------------------------------------------

local function StartFsr(now)
  st.fsrStart = now
  st.castAt, st.dropAt = nil, nil
  if R.Wake then
    R.Wake()
  end
end

-- How far the five seconds have run (0-1), or nil when they don't.
function R.FsrPhase(now)
  local start = st.fsrStart
  if not start then
    return nil
  end
  local run = (now or Now()) - start
  if run < 0 or run >= FSR then
    st.fsrStart = nil
    return nil
  end
  return run / FSR
end

-- A cast of ours succeeded (spellID may be secret).
function R.SpellSucceeded(spellID)
  local now = Now()
  st.castAt = now
  if st.dropAt and now - st.dropAt <= PAIR then
    StartFsr(now)
  end
  R.SealCast(spellID)
end

-- Mana or energy changed: a drop pairs with a cast (five-second rule), a rise near the beat is a tick.
function R.PowerChanged(kind)
  local value = Readable(UnitPower("player", kind))
  if type(value) ~= "number" then
    st.last[kind] = nil
    return
  end
  local last = st.last[kind]
  st.last[kind] = value
  if type(last) ~= "number" or value == last then
    return
  end
  local now = Now()
  if value < last then
    if kind == R.MANA then
      st.dropAt = now
      if st.castAt and now - st.castAt <= PAIR then
        StartFsr(now)
      end
    end
    return
  end
  local at = st.tickAt[kind]
  local since = at and now - at
  local beat = since and since % TICK
  if not at or since > TICK_QUIET or beat <= TICK_SLACK or beat >= TICK - TICK_SLACK then
    st.tickAt[kind] = now
    if R.Wake then
      R.Wake()
    end
  end
end

-- The first readable mana and energy, so the first change after login counts.
function R.SeedPower()
  for _, kind in ipairs({ R.MANA, R.ENERGY }) do
    if st.last[kind] == nil then
      local value = Readable(UnitPower("player", kind))
      if type(value) == "number" then
        st.last[kind] = value
      end
    end
  end
end

-- Where the next tick is coming (0-1 of the TICK seconds), or nil: no beat known yet, the power full or
-- unreadable, or (mana) the five-second rule running.
function R.TickPhase(kind, now)
  local at = st.tickAt[kind]
  if not at then
    return nil
  end
  now = now or Now()
  if kind == R.MANA and R.FsrPhase(now) then
    return nil
  end
  local current, max = Readable(UnitPower("player", kind)), Readable(UnitPowerMax("player", kind))
  if type(current) ~= "number" or type(max) ~= "number" or max <= 0 or current >= max then
    return nil
  end
  return ((now - at) % TICK) / TICK
end

-- Seals ---------------------------------------------------------------------------------------------------------
-- The seals' spell IDs (each seal's first rank, then its other ranks). Game data, as FlareUI lists them.

R.SEALS = {
  { 20154, 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 27155 }, -- Righteousness
  { 20162, 20305, 20306, 20307, 20308, 21082, 27158 }, -- the Crusader
  { 20375, 20915, 20918, 20919, 20920, 27170 }, -- Command
  { 20164 }, -- Justice
  { 20165, 20347, 20348, 20349, 27160 }, -- Light
  { 20166, 20356, 20357, 27166 }, -- Wisdom
  { 20163, 20419, 20421, 20422, 20423, 1311649, 1311656 }, -- Fury
  { 407798 }, -- Martyrdom
}

local sealIDs, sealNames
local function SealLists()
  if sealIDs then
    return
  end
  sealIDs, sealNames = {}, {}
  local nameOf = C_Spell and C_Spell.GetSpellName or GetSpellInfo
  for _, ranks in ipairs(R.SEALS) do
    for _, id in ipairs(ranks) do
      sealIDs[id] = true
    end
    if type(nameOf) == "function" then
      local ok, name = pcall(nameOf, ranks[1])
      name = ok and Readable(name)
      if type(name) == "string" and name ~= "" then
        sealNames[name] = true
      end
    end
  end
end

-- Is this spell (readable ID or name) a seal?
function R.IsSeal(spellID, name)
  SealLists()
  return spellID ~= nil and sealIDs[spellID] or name ~= nil and sealNames[name] or false
end

local function SpellIcon(spellID)
  local iconOf = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
  if type(iconOf) == "function" then
    local ok, icon = pcall(iconOf, spellID)
    if ok then
      return icon
    end
  end
end

-- A seal cast we saw: 30 s from now (an aura read later puts the real times in).
function R.SealCast(spellID)
  if R.Class() ~= "PALADIN" then
    return
  end
  local id = Readable(spellID)
  if id == nil or not R.IsSeal(id) then
    return
  end
  st.seal = { start = Now(), duration = SEAL_TIME, icon = SpellIcon(id), cast = true }
  if R.Wake then
    R.Wake()
  end
end

-- Reads the player's buffs for a seal. Found and readable: its own times. Found but secret: the client
-- times the bar (aura instance, SetTimerDuration), the cast's time stays for the text. Not found while every
-- buff could be read: no seal. Not found while some were secret: the cast's guess stands until it runs out.
function R.ScanSeal()
  if R.Class() ~= "PALADIN" then
    st.seal = nil
    return
  end
  local read = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if type(read) ~= "function" then
    return
  end
  local found, blind = nil, false
  for index = 1, 40 do
    local ok, aura = pcall(read, "player", index, "HELPFUL")
    if not ok or type(aura) ~= "table" then
      break
    end
    local id, name = Readable(aura.spellId), Readable(aura.name)
    if id == nil and name == nil then
      blind = true
    elseif R.IsSeal(id, name) then
      found = aura
      break
    end
  end
  if not found then
    local seal = st.seal
    if not blind then
      st.seal = nil
    elseif seal and seal.instance ~= nil and C_UnitAuras.GetAuraDataByAuraInstanceID then
      -- secret buffs: the seal's own aura asked by its instance (nil once it is gone, even in a fight)
      local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", seal.instance)
      if ok and type(data) ~= "table" then
        st.seal = nil
      end
    end
    return
  end
  local expires, duration = Readable(found.expirationTime), Readable(found.duration)
  local guess = st.seal
  if type(expires) == "number" and type(duration) == "number" and duration > 0 then
    st.seal = { start = expires - duration, duration = duration, icon = found.icon }
  else
    st.seal = { start = guess and guess.start, duration = guess and guess.duration, icon = found.icon,
      instance = found.auraInstanceID, timer = true }
  end
  if R.Wake then
    R.Wake()
  end
end

-- The seal's time: fraction left (0-1) and seconds left, or nil when unknown (secret, no cast seen). A guess
-- that ran out ends the seal.
function R.SealLeft(now)
  local seal = st.seal
  if not seal or not seal.start or not seal.duration then
    return nil
  end
  local left = seal.start + seal.duration - (now or Now())
  if left <= 0 then
    if not seal.timer then
      st.seal = nil
    else
      seal.start, seal.duration = nil, nil
    end
    return nil
  end
  return math.min(1, left / seal.duration), left
end

-- Swings --------------------------------------------------------------------------------------------------------

function R.SwingKey(swingType)
  return SWING_OF[Readable(swingType)]
end

function R.StartSwing(swingType, duration)
  local key = R.SwingKey(swingType)
  duration = Readable(duration)
  if not key or type(duration) ~= "number" or duration <= 0 then
    return
  end
  st.swings[key] = { start = Now(), duration = duration, speed = duration }
  if R.Wake then
    R.Wake()
  end
  return key
end

-- PLAYER_SWING_RANGE_UPDATE: out of range only when the game checked and said so.
function R.SwingRange(swingType, inRange, checked)
  local key = R.SwingKey(swingType)
  if key then
    st.out[key] = Readable(checked) == true and Readable(inRange) == false or nil
  end
end

-- The attack speeds of each hand (readable ones only).
function R.Speeds()
  local main, off, ranged = UnitAttackSpeed("player")
  if ranged == nil and type(UnitRangedDamage) == "function" then
    ranged = UnitRangedDamage("player")
  end
  return { main = Readable(main), off = Readable(off), ranged = Readable(ranged) }
end

-- UNIT_ATTACK_SPEED: haste gained or lost mid-swing scales the time left (the next swing corrects it anyway).
function R.RescaleSwings()
  local speeds, now = R.Speeds(), Now()
  for key, swing in pairs(st.swings) do
    local new = speeds[key]
    if not swing.ended and type(new) == "number" and new > 0 and math.abs(new - swing.speed) > 0.001 then
      local done = math.min(1, (now - swing.start) / swing.duration)
      swing.duration = swing.duration * new / swing.speed
      swing.start = now - done * swing.duration
      swing.speed = new
    end
  end
end

function R.EndSwings()
  local now = Now()
  for _, swing in pairs(st.swings) do
    if not swing.ended then
      swing.ended = now
    end
  end
end

-- A swing's fill (0-1) and seconds left; nil when none runs. "held": a finished swing still within its hold;
-- a swing past its hold is forgotten.
function R.SwingPhase(key, now)
  local swing = st.swings[key]
  if not swing then
    return nil
  end
  now = now or Now()
  local left = swing.start + swing.duration - now
  if not swing.ended and left <= 0 then
    swing.ended = swing.start + swing.duration
  end
  if swing.ended then
    if now - swing.ended >= R.SWING_HOLD then
      st.swings[key] = nil
      return nil
    end
    return nil, nil, true
  end
  return math.max(0, math.min(1, (now - swing.start) / swing.duration)), left
end

function R.SwingDuration(key)
  local swing = st.swings[key]
  return swing and swing.duration
end
