local addonName, ns = ...
local R = ns.rings

-- Rings (off by default; standalone = OPie, so while OPie is loaded Codex leaves rings to it unless forced):
-- hold a key and a ring of spells, items, macros, mounts or raid markers opens round the mouse; point at one
-- and let go to use it. Works in combat (see Secure.lua). Premade rings: Mounts, Travel, Professions (filled
-- from what each character knows and carries) and Markers; none has a key until the player sets one.

-- "/codex ring <name>": open or close a ring at the mouse (out of combat), for trying it out.
local function RingCommand(_, rest)
  local name = strtrim(rest or "")
  if name == "" then
    ns.ShowPage("rings")
    return
  end
  local ring = R.FindByName(name)
  if not ring then
    local names = {}
    for _, each in ipairs(R.Rings()) do
      names[#names + 1] = each.name
    end
    ns.Say(("No ring called %s. Rings: %s."):format(name, #names > 0 and table.concat(names, ", ") or "none"))
    return
  end
  local ok, why = R.ToggleAtCursor(ring)
  if not ok and why then
    ns.Say(why)
  end
end

ns.RegisterModule({
  id = "rings",
  name = "Rings",
  -- its section in the Codex window (Areas.lua)
  area = "ringmenus", sectionOrder = 10, pageEstimate = 470,
  icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
  desc = "Hold a key and a ring of spells, items, mounts or markers opens round the mouse; point and let go.",
  standalone = "OPie",
  default = false,
  order = 32,
  Enable = function()
    R.Enable()
  end,
  BuildPage = function(_, page)
    R.BuildPage(page)
  end,
  ShowPage = function()
    R.RefreshPage()
  end,
  Status = function()
    return R.StatusText()
  end,
  commands = {
    ring = RingCommand,
  },
})
