local addonName, ns = ...
local L = ns.L

-- Numbers on cooldowns (2026-11-21): the game's own countdown numbers on action buttons and buffs (CVar
-- countdownForCooldowns, the "Show Numbers for Cooldowns" box in the game's Action Bars settings, forever branch
-- Blizzard_SettingsDefinitions_Frame/ActionBars.lua). Codex switches the CVar on and gives the player's own value
-- back when switched off; with the restyle on, the numbers are already in the theme's font (Skins/ActionBars.lua,
-- Skins/Cooldowns.lua). Never in a fight: a change waits for its end.

local Q = ns.qol
local KEY = "cooldownNumbers"
local CVAR = "countdownForCooldowns"

local waiting -- a frame that applies the value after combat

local function GetValue()
  if C_CVar and C_CVar.GetCVar then
    local ok, value = pcall(C_CVar.GetCVar, CVAR)
    if ok then
      return value
    end
  end
  if GetCVar then
    local ok, value = pcall(GetCVar, CVAR)
    if ok then
      return value
    end
  end
  return nil
end

local function SetValue(value)
  if C_CVar and C_CVar.SetCVar then
    return pcall(C_CVar.SetCVar, CVAR, value)
  elseif SetCVar then
    return pcall(SetCVar, CVAR, value)
  end
  return false
end

local function InCombat()
  return InCombatLockdown and InCombatLockdown()
end

-- Brings the CVar in line with the toggle: on = "1" (the player's value kept to give back), off = that value back.
local function Apply()
  if InCombat() then
    if not waiting then
      waiting = CreateFrame("Frame")
      waiting:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Apply()
      end)
    end
    waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  local db = Q.DB()
  if Q.On(KEY) then
    local now = GetValue()
    if now ~= "1" then
      db.cooldownNumbersBefore = now or "0"
      SetValue("1")
    end
  elseif db.cooldownNumbersBefore ~= nil then
    SetValue(db.cooldownNumbersBefore)
    db.cooldownNumbersBefore = nil
  end
end
Q.ApplyCooldownNumbers = Apply

Q.AddToggle({
  key = KEY,
  name = L["Numbers on cooldowns"],
  desc = L["The time left as a number on every action button and buff that is cooling down (the game's own countdown). With the restyle on, the numbers are in your theme's font. Switching it off gives back the game setting you had before."],
  default = false,
  order = 28,
  Enable = function()
    Apply()
  end,
  Changed = function()
    Apply()
  end,
})
