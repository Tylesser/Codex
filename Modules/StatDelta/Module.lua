local addonName, ns = ...

-- Stat Delta module, part 7: events, start-up and registration. Tylesser - Stat Delta ported into Codex:
-- while the standalone Stat Delta addon is loaded Codex leaves this to it (unless the player forces Codex's
-- copy).

local S = ns.statdelta

-- Coalesced refresh: equipment changes fire once per slot (an outfit swap is ~19 events at once), so open
-- tooltips and arrows are rebuilt once, half a second after the first change. Arrow work waits for the end
-- of combat. forget: what the character can use changed (level, new weapon skill).
local pending, pendingForget = false, false

local function RunRefresh()
  pending = false
  if pendingForget then
    pendingForget = false
    S.ForgetUsable()
  end
  S.Refresh()
  if InCombatLockdown() then
    S.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  S.RefreshArrows()
end

function S.QueueRefresh(forget)
  if forget then
    pendingForget = true
  end
  if pending then
    return
  end
  pending = true
  C_Timer.After(0.5, RunRefresh)
end

-- The learned skills (names, not ranks): weapon and defense skills rise every few swings, but only a new
-- skill (e.g. Two-Handed Swords from a trainer) changes what the character can use.
local function SkillSignature()
  if not (GetNumSkillLines and GetSkillLineInfo) then
    return nil
  end
  local names = {}
  for i = 1, GetNumSkillLines() or 0 do
    local name, isHeader = GetSkillLineInfo(i)
    if type(name) == "string" and not isHeader then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return table.concat(names, "|")
end
local skills

local function OnEvent(frame, event, arg)
  if event == "PLAYER_EQUIPMENT_CHANGED" then
    S.QueueRefresh()
  elseif event == "PLAYER_LEVEL_UP" then
    -- UnitLevel may still give the old level now: the delayed refresh reads it later
    S.QueueRefresh(true)
  elseif event == "UNIT_LEVEL" then
    if arg == "player" then
      S.QueueRefresh(true)
    end
  elseif event == "SKILL_LINES_CHANGED" then
    local signature = SkillSignature()
    if skills ~= nil and signature ~= skills then
      S.QueueRefresh(true)
    end
    skills = signature
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    S.SyncTalentScore() -- one upgrade score per talent group (Score.lua)
    S.ForgetTalents() -- talents that turn one stat into another (Stats.lua)
    S.QueueRefresh()
  elseif event == "PLAYER_REGEN_ENABLED" then
    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    S.RefreshArrows()
  end
end

function S.Enable()
  S.DB()
  skills = SkillSignature()
  local events = CreateFrame("Frame")
  for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "UNIT_LEVEL", "SKILL_LINES_CHANGED" }) do
    events:RegisterEvent(event)
  end
  pcall(events.RegisterEvent, events, "ACTIVE_TALENT_GROUP_CHANGED")
  pcall(events.RegisterEvent, events, "PLAYER_TALENT_UPDATE") -- the talents first known after a login
  pcall(events.RegisterEvent, events, "TRAIT_CONFIG_UPDATED") -- talents spent or reset
  events:SetScript("OnEvent", OnEvent)
  S.SyncTalentScore() -- a swap made while the module was off
  S.eventFrame = events
  S.HookTooltips()
  S.HookArrows()
  S.running = true
end

local function OnOff(value)
  return value and "|cff20ff20on|r" or "|cffff4040off|r"
end

ns.RegisterModule({
  id = "statdelta",
  name = "Stat Delta",
  -- its section in the Codex window (Areas.lua)
  area = "items", sectionOrder = 20, folded = true, pageEstimate = 430,
  icon = "Interface\\Icons\\INV_Chest_Plate06",
  desc = "Hold Shift over an item to see the stats you gain or lose against your gear, with an optional upgrade score and arrows.",
  standalone = "StatDelta",
  standaloneName = "Stat Delta",
  order = 37,
  Enable = function()
    S.Enable()
  end,
  BuildPage = function(_, page)
    S.BuildPage(page)
  end,
  ShowPage = function()
    S.RefreshPage()
  end,
  Status = function()
    return S.StatusText()
  end,
  -- /codex statdelta on | off | primary; anything else opens the page
  Slash = function(_, rest)
    rest = rest:lower()
    local db = S.DB()
    if rest == "on" or rest == "off" then
      db.enabled = rest == "on"
      ns.Say("stat changes " .. OnOff(db.enabled) .. ".")
    elseif rest == "primary" then
      db.showPrimary = not db.showPrimary
      ns.Say("Strength, Agility, Stamina, Intellect and Spirit " .. OnOff(db.showPrimary) .. ".")
    else
      ns.ShowPage("statdelta")
      return
    end
    if S.running then
      S.Refresh()
    end
    S.RefreshPage()
  end,
})
