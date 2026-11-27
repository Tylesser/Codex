local addonName, ns = ...

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

-- Display order. fmt: "int" (default), "pct" or "dec".
S.STATS = {
  { key = "health", label = "Health" },
  { key = "mana", label = "Mana" },
  { key = "attackPower", label = "Attack Power" },
  { key = "rangedAttackPower", label = "Ranged Attack Power" },
  { key = "feralAttackPower", label = "Attack Power in forms" },
  { key = "dps", label = "Weapon DPS", fmt = "dec" },
  { key = "spellPower", label = "Spell Power" },
  { key = "spellDamage", label = "Spell Damage" },
  { key = "arcaneDamage", label = "Arcane Damage" },
  { key = "fireDamage", label = "Fire Damage" },
  { key = "frostDamage", label = "Frost Damage" },
  { key = "holyDamage", label = "Holy Damage" },
  { key = "natureDamage", label = "Nature Damage" },
  { key = "shadowDamage", label = "Shadow Damage" },
  { key = "healing", label = "Healing" },
  { key = "crit", label = "Crit Chance", fmt = "pct" },
  { key = "hit", label = "Hit Chance", fmt = "pct" },
  { key = "spellCrit", label = "Spell Crit Chance", fmt = "pct" },
  { key = "spellHit", label = "Spell Hit Chance", fmt = "pct" },
  { key = "critRating", label = "Crit Rating" },
  { key = "hitRating", label = "Hit Rating" },
  { key = "spellCritRating", label = "Spell Crit Rating" },
  { key = "spellHitRating", label = "Spell Hit Rating" },
  { key = "hasteRating", label = "Haste" },
  { key = "expertiseRating", label = "Expertise" },
  { key = "armorPenetrationRating", label = "Armor Penetration" },
  { key = "masteryRating", label = "Mastery" },
  { key = "versatility", label = "Versatility" },
  { key = "mp5", label = "Mana per 5 sec" },
  { key = "hp5", label = "Health per 5 sec" },
  { key = "armor", label = "Armor" },
  { key = "defense", label = "Defense" },
  { key = "defenseRating", label = "Defense Rating" },
  { key = "dodge", label = "Dodge Chance", fmt = "pct" },
  { key = "dodgeRating", label = "Dodge Rating" },
  { key = "parry", label = "Parry Chance", fmt = "pct" },
  { key = "parryRating", label = "Parry Rating" },
  { key = "block", label = "Block Chance", fmt = "pct" },
  { key = "blockRating", label = "Block Rating" },
  { key = "blockValue", label = "Block Value" },
  { key = "resilienceRating", label = "Resilience" },
  { key = "strength", label = "Strength", primary = true },
  { key = "agility", label = "Agility", primary = true },
  { key = "stamina", label = "Stamina", primary = true },
  { key = "intellect", label = "Intellect", primary = true },
  { key = "spirit", label = "Spirit", primary = true },
  { key = "arcaneResistance", label = "Arcane Resistance" },
  { key = "fireResistance", label = "Fire Resistance" },
  { key = "frostResistance", label = "Frost Resistance" },
  { key = "natureResistance", label = "Nature Resistance" },
  { key = "shadowResistance", label = "Shadow Resistance" },
}
