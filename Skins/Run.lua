local addonName, ns = ...
local S = ns.S

-- Runs every part the player has switched on (Settings > "Restyle the game's interface"), each in its own
-- pcall, then names the parts that failed in one line. Loaded last. Codex loads this folder at
-- PLAYER_LOGIN; after a /reload in combat everything waits for the end of the fight.

local function RunAll()
  local listed = {}
  for _, part in ipairs(TylesserCodex.SKIN_PARTS or {}) do
    listed[part.id] = true
    local fn = S.parts[part.id]
    if fn and TylesserCodex.SkinPartOn(part.id) then
      S.Run(part.id, fn)
    end
  end
  -- a part file Settings doesn't list yet: SkinPartOn takes an unknown id as on
  local extra = {}
  for id in pairs(S.parts) do
    if not listed[id] then
      extra[#extra + 1] = id
    end
  end
  table.sort(extra)
  for _, id in ipairs(extra) do
    if TylesserCodex.SkinPartOn(id) then
      S.Run(id, S.parts[id])
    end
  end
  S.ready = true
  S.Report()
end

if S.InCombat() then
  S.Defer("run", RunAll)
else
  RunAll()
end
