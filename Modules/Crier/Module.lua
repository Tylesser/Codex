local addonName, ns = ...
local L = ns.L

-- Trade Crier: registration. The feature itself is Crier.lua (shared with the standalone TradeCrier).

local C = ns.crier

ns.RegisterModule({
  id = "crier",
  name = "Trade Crier",
  -- its section in the Codex window (Areas.lua)
  area = "chat", sectionOrder = 40, pageEstimate = 680,
  icon = "Interface\\Icons\\INV_Misc_Note_01",
  desc = L["Your messages with your profession links in Trade chat, each again after its own time while you are in a city: a button lights up when it's time and one click (or a key) posts it."],
  standalone = "TradeCrier",
  standaloneName = "Trade Crier",
  default = false,
  order = 41,
  Enable = function()
    C.Start()
  end,
  BuildPage = function(_, page)
    C.BuildPage(page)
  end,
  ShowPage = function()
    C.RefreshPage()
  end,
  Status = function()
    return C.started and C.StatusText() or L["Off."]
  end,
  -- /codex crier post | pause | resume | status | reset
  Slash = function(_, rest)
    if not (C.started and C.Command(rest)) then
      ns.ShowPage("crier")
    end
  end,
})
