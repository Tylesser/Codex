local addonName, ns = ...
local L = ns.L

-- Minimap button: click opens Codex, right-click shows the quick menu, drag moves it around the minimap.

local UI = ns.UI
local button

local function Place()
  local angle = math.rad(ns.db.minimap.angle or 225)
  local radius = (Minimap:GetWidth() / 2) + 8
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  ns.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
  Place()
end

local function QuickMenu()
  local items = { { text = "Tylesser Codex", title = true } }
  for _, module in ipairs(ns.moduleList) do
    local state = ns.ModuleState(module.id)
    items[#items + 1] = {
      text = module.name .. (state == "standalone" and L[" (addon)"] or ""),
      checked = state == "on",
      func = function()
        ns.ShowPage(module.id)
      end,
    }
  end
  items[#items + 1] = { text = L["Open Codex"], func = function() ns.ShowPage("home") end }
  items[#items + 1] = { text = L["General"], func = function() ns.ShowPage("general") end }
  items[#items + 1] = { text = L["Look"], func = function() ns.ShowPage("look") end }
  items[#items + 1] = { text = L["Hide this button"], func = function()
    ns.db.minimap.hide = true
    ns.UpdateMinimapButton()
    ns.Say(L["minimap button hidden. Type /codex to open the window, and show it again in General > Codex window."])
  end }
  UI.ShowMenu(button, items)
end

function ns.CreateMinimapButton()
  if button or not Minimap then
    return
  end
  button = CreateFrame("Button", "CodexMinimapButton", Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ns.T.EMBLEM)
  icon:SetSize(22, 22)
  icon:SetPoint("CENTER", 0, 1)
  button.icon = icon -- (the addon button list reads it)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      QuickMenu()
    else
      UI.HideMenu()
      ns.ToggleWindow()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Tylesser Codex")
    local on, off = 0, 0
    for _, module in ipairs(ns.moduleList) do
      if ns.ModuleOn(module.id) then
        on = on + 1
      else
        off = off + 1
      end
    end
    GameTooltip:AddLine(L["%d modules on, %d off"]:format(on, off), 0.85, 0.85, 0.85)
    GameTooltip:AddLine(L["Click: open Codex"], 0.25, 1, 0.25)
    GameTooltip:AddLine(L["Right-click: quick menu"], 0.25, 1, 0.25)
    GameTooltip:AddLine(L["Drag: move around the minimap"], 0.25, 1, 0.25)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  Place()
  ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
  if button then
    button:SetShown(not ns.db.minimap.hide)
  end
end
