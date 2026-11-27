local addonName, ns = ...
local L = ns.L

-- Move windows module, part 2: its page in the Codex window and registration.

local MW = ns.movewindows
local UI = ns.UI

local view = {}

function MW.StatusText()
  if not MW.running then
    return L["Off: the game's windows stay where the game puts them."]
  end
  local moved = MW.MovedCount()
  return (MW.WindowCount() == 1 and L["%d window can be dragged; %d moved"] or L["%d windows can be dragged; %d moved"])
    :format(MW.WindowCount(), moved)
end

local function RefreshPage()
  if not view.page then
    return
  end
  view.status:SetText(MW.StatusText())
  view.remember:SetChecked(MW.DB().remember)
end
MW.RefreshPage = RefreshPage

function MW.BuildPage(page)
  MW.DB()
  view.page = page
  local heading = UI.Heading(page, L["Move windows"], 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)

  local about = UI.Text(page, "body", 12, "text")
  about:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -14)
  about:SetPoint("RIGHT", 0, 0)
  about:SetJustifyH("LEFT")
  about:SetText(L["Drag any game window (character, spellbook, bags, vendor, mail, auction house, professions, quests and more) by its title bar. Right-click the title bar to put that window back. Windows the game protects (like the spellbook) can't be moved during a fight. The world map and Edit Mode's frames stay where the game puts them."])

  view.remember = UI.Check(page, L["Remember positions between sessions"])
  view.remember:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
  local note = UI.Text(page, "body", 11, "muted")
  note:SetPoint("LEFT", view.remember.label, "RIGHT", 10, 0)
  note:SetPoint("RIGHT", page, "RIGHT", 0, 0) -- bound to the page: a long note wraps
  note:SetJustifyH("LEFT")
  note:SetWordWrap(true)
  note:SetText(L["Off: windows go back to their usual places after a reload or log-out."])
  view.remember:SetScript("OnClick", function(self)
    MW.SetRemember(self:GetChecked())
  end)

  local reset = UI.Button(page, 160, 22, L["Reset all positions"])
  reset:SetPoint("TOPLEFT", view.remember, "BOTTOMLEFT", 0, -16)
  reset:SetScript("OnClick", function()
    MW.ResetAll()
    ns.Say(L["Every window goes back to its usual place."])
  end)
  view.reset = reset

  ns.On("MOVEWINDOWS_CHANGED", function()
    if view.page:IsVisible() then
      RefreshPage()
    end
  end)
  RefreshPage()
end

ns.RegisterModule({
  id = "movewindows",
  name = L["Move windows"],
  -- its section in the Codex window (Areas.lua)
  area = "general", sectionOrder = 50, folded = true, pageEstimate = 170,
  icon = "Interface\\Icons\\INV_Misc_Map_01",
  desc = L["Drag any game window by its title bar; right-click it to put it back."],
  order = 90,
  Enable = function()
    MW.Enable()
  end,
  BuildPage = function(_, page)
    MW.BuildPage(page)
  end,
  ShowPage = function()
    RefreshPage()
  end,
  Status = function()
    return MW.StatusText()
  end,
  -- /codex movewindows reset
  Slash = function(_, rest)
    if rest:lower() == "reset" then
      MW.ResetAll()
      ns.Say(L["Every window goes back to its usual place."])
    else
      ns.ShowPage("movewindows")
    end
  end,
})
