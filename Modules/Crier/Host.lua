local addonName, ns = ...

-- Trade Crier in Codex (2026-11-26, the user's request; standalone = TradeCrier): what Crier.lua (the same file as
-- TradeCrier/Crier.lua) needs from its host. Settings in CodexDB.crier (channel, button, key) and
-- CodexCharDB.crier (this character: the messages with their times, paused, the last post).

local C = {}
ns.crier = C

C.BRAND = "Trade Crier"
C.BUTTON_NAME = "CodexCrierButton"
C.COMMAND = "/codex crier"

function C.DB()
  ns.db.crier = type(ns.db.crier) == "table" and ns.db.crier or {}
  return ns.db.crier
end

function C.CharDB()
  ns.char.crier = type(ns.char.crier) == "table" and ns.char.crier or {}
  return ns.char.crier
end

function C.Say(text)
  ns.Say(text)
end

function C.Accent()
  return ns.InkTheme().accent
end

-- The button: an inset box in the theme, like the bag window's slots.
function C.Look(button)
  local UI = ns.UI
  UI.Inset(UIParent, button)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetPoint("TOPLEFT", 2, -2)
  hover:SetPoint("BOTTOMRIGHT", -2, 2)
  UI.SetColor(hover, ns.InkTheme().accent, 0.18)
  button.label:SetTextColor(UI.Unpack(ns.InkTheme().accent))
end

function C.OpenOptions()
  ns.ShowPage("crier")
end
