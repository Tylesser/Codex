local addonName, ns = ...
local L = ns.L

-- Stat Delta module, part 1: saved settings and the stat list. Ported from Tylesser - Stat Delta (same
-- author, MIT), WoW Forever only: Forever uses the original (Classic Era) stat formulas, so Strength,
-- Agility, Stamina and Intellect turn into Attack Power, Health, Mana and so on, and the upgrade score is
-- always available. Nothing here creates frames or registers events.
--
-- CodexDB.statdelta = { enabled, showPrimary, showScore, showArrows }
-- CodexCharDB.statdelta = { preset = nil | preset id | "custom", weights = { [stat key] = points }, edited }

local S = {}
ns.statdelta = S

S.DEFAULTS = {
  enabled = true,     -- the stat changes in item tooltips (while Shift is held)
  showPrimary = true, -- Strength, Agility, Stamina, Intellect, Spirit
  showScore = true,   -- "Upgrade: +4.2%" lines, once a score preset is chosen
  showArrows = true,  -- green arrows on bag and quest reward items, once a score preset is chosen
}

S.CHAR_DEFAULTS = {
  weights = {},
  edited = false,
}

-- A copy of the standalone addon's settings, the first time Codex's copy runs while they are around
-- (the player forced Codex's copy with Stat Delta still installed).
local function Import(target, source, keys)
  if type(source) ~= "table" then
    return
  end
  for _, key in ipairs(keys) do
    local value = source[key]
    if type(value) == "table" then
      local copy = {}
      for k, v in pairs(value) do
        copy[k] = v
      end
      value = copy
    end
    if value ~= nil then
      target[key] = value
    end
  end
end

function S.DB()
  if not (ns.db and ns.char) then
    return nil
  end
  if not ns.db.statdelta then
    ns.db.statdelta = {}
    Import(ns.db.statdelta, StatDeltaDB, { "enabled", "showPrimary", "showScore", "showArrows" })
  end
  if not ns.char.statdelta then
    ns.char.statdelta = {}
    Import(ns.char.statdelta, StatDeltaCharDB, { "preset", "weights", "edited", "talentGroup", "talentScores" })
  end
  S.db = ns.Fill(ns.db.statdelta, S.DEFAULTS)
  S.char = ns.Fill(ns.char.statdelta, S.CHAR_DEFAULTS)
  return S.db, S.char
end

-- Not nil and not a secret value.
function S.Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- Stats that S.WithConversions can change; shown under "Your character".
S.CONVERTED = {
  health = true, mana = true, attackPower = true, rangedAttackPower = true, armor = true,
  crit = true, dodge = true, spellCrit = true,
  -- WoW Forever's talents (Stats.lua TALENTS): stats raised by a percentage, spell damage and healing from a stat
  strength = true, agility = true, stamina = true, intellect = true, spirit = true, spellDamage = true, healing = true,
}

-- Display order. fmt: "int" (default), "pct" or "dec". weightLabel: the module page's name for a percent stat
-- (its points are per 1%).
S.STATS = {
  { key = "health", label = L["Health"] },
  { key = "mana", label = L["Mana"] },
  { key = "attackPower", label = L["Attack Power"] },
  { key = "rangedAttackPower", label = L["Ranged Attack Power"] },
  { key = "feralAttackPower", label = L["Attack Power in forms"] },
  { key = "dps", label = L["Weapon DPS"], fmt = "dec" },
  { key = "spellPower", label = L["Spell Power"] },
  { key = "spellDamage", label = L["Spell Damage"] },
  { key = "arcaneDamage", label = L["Arcane Damage"] },
  { key = "fireDamage", label = L["Fire Damage"] },
  { key = "frostDamage", label = L["Frost Damage"] },
  { key = "holyDamage", label = L["Holy Damage"] },
  { key = "natureDamage", label = L["Nature Damage"] },
  { key = "shadowDamage", label = L["Shadow Damage"] },
  { key = "healing", label = L["Healing"] },
  { key = "crit", label = L["Crit Chance"], weightLabel = L["Crit (1%)"], fmt = "pct" },
  { key = "hit", label = L["Hit Chance"], weightLabel = L["Hit (1%)"], fmt = "pct" },
  { key = "spellCrit", label = L["Spell Crit Chance"], weightLabel = L["Spell Crit (1%)"], fmt = "pct" },
  { key = "spellHit", label = L["Spell Hit Chance"], weightLabel = L["Spell Hit (1%)"], fmt = "pct" },
  { key = "critRating", label = L["Crit Rating"] },
  { key = "hitRating", label = L["Hit Rating"] },
  { key = "spellCritRating", label = L["Spell Crit Rating"] },
  { key = "spellHitRating", label = L["Spell Hit Rating"] },
  { key = "hasteRating", label = L["Haste"] },
  { key = "expertiseRating", label = L["Expertise"] },
  { key = "armorPenetrationRating", label = L["Armor Penetration"] },
  { key = "masteryRating", label = L["Mastery"] },
  { key = "versatility", label = L["Versatility"] },
  { key = "mp5", label = L["Mana per 5 sec"] },
  { key = "hp5", label = L["Health per 5 sec"] },
  { key = "armor", label = L["Armor"] },
  { key = "defense", label = L["Defense"] },
  { key = "defenseRating", label = L["Defense Rating"] },
  { key = "dodge", label = L["Dodge Chance"], weightLabel = L["Dodge (1%)"], fmt = "pct" },
  { key = "dodgeRating", label = L["Dodge Rating"] },
  { key = "parry", label = L["Parry Chance"], weightLabel = L["Parry (1%)"], fmt = "pct" },
  { key = "parryRating", label = L["Parry Rating"] },
  { key = "block", label = L["Block Chance"], weightLabel = L["Block (1%)"], fmt = "pct" },
  { key = "blockRating", label = L["Block Rating"] },
  { key = "blockValue", label = L["Block Value"] },
  { key = "resilienceRating", label = L["Resilience"] },
  { key = "strength", label = L["Strength"], primary = true },
  { key = "agility", label = L["Agility"], primary = true },
  { key = "stamina", label = L["Stamina"], primary = true },
  { key = "intellect", label = L["Intellect"], primary = true },
  { key = "spirit", label = L["Spirit"], primary = true },
  { key = "arcaneResistance", label = L["Arcane Resistance"] },
  { key = "fireResistance", label = L["Fire Resistance"] },
  { key = "frostResistance", label = L["Frost Resistance"] },
  { key = "natureResistance", label = L["Nature Resistance"] },
  { key = "shadowResistance", label = L["Shadow Resistance"] },
}
