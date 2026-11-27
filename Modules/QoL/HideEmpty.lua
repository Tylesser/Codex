local addonName, ns = ...
local L = ns.L

-- Hide empty slots (2026-11-22, the user's request: "for action bars add option to hide empty slots"). Forever's
-- bars (forever branch, Blizzard_ActionBar/Shared/ActionBar.lua UpdateShownButtons) already hide an empty button
-- when Edit Mode's "Always show buttons" is off, but not on every bar and not with that box on. Codex does it
-- with alpha only (SetAlpha is allowed on secure buttons in combat; nothing shown / hidden, no attribute written):
-- a button without an action (C_ActionBar.HasAction) goes to alpha 0, with the restyle's slot box on it. All
-- empty slots come back while something is dragged (the button's "showgrid" attribute carries the game's
-- EVENT / SPELLCOLLECTION reasons, ACTION_BUTTON_SHOW_GRID_REASON_*), while Edit Mode is open and while keys are
-- bound by hovering, so there is always somewhere to drop a spell.

local Q = ns.qol
local KEY = "hideEmpty"
local BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_SHOWGRID",
  "ACTIONBAR_HIDEGRID", "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "CURSOR_CHANGED" }

local H = {}
Q.hideEmpty = H
local hooked = setmetatable({}, { __mode = "k" })
local hidden = setmetatable({}, { __mode = "k" }) -- [button] = true while we hold it at alpha 0
local frame, pending

local function Plain(value)
  if value == nil or (issecretvalue and issecretvalue(value)) then
    return nil
  end
  return value
end

local function Buttons()
  local list = {}
  for _, prefix in ipairs(BUTTONS) do
    for index = 1, 12 do
      local button = _G[prefix .. index]
      if type(button) == "table" and button.GetAlpha then
        list[#list + 1] = button
      end
    end
  end
  return list
end

-- The game is showing the grid for a drag (not for the "Always show buttons" setting).
local function Dragging(button)
  local value = button.GetAttribute and Plain(button:GetAttribute("showgrid"))
  if type(value) ~= "number" then
    return false
  end
  local reasons = (ACTION_BUTTON_SHOW_GRID_REASON_EVENT or 2) + (ACTION_BUTTON_SHOW_GRID_REASON_SPELLCOLLECTION or 4)
  return bit and bit.band and bit.band(value, reasons) ~= 0 or false
end

local function ShowAll()
  if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
    return true
  end
  if Q.hoverBind and Q.hoverBind.Active and Q.hoverBind.Active() then
    return true
  end
  return GetCursorInfo and GetCursorInfo() ~= nil or false
end

function H.IsEmpty(button)
  local action = button and Plain(button.action)
  if not (action and C_ActionBar and C_ActionBar.HasAction) then
    return false
  end
  local ok, has = pcall(C_ActionBar.HasAction, action)
  return ok and Plain(has) == false
end

function H.Update()
  pending = false
  local on, all = Q.On(KEY), ShowAll()
  for _, button in ipairs(Buttons()) do
    local hide = on and not all and not Dragging(button) and H.IsEmpty(button)
    if hide and not hidden[button] then
      hidden[button] = true
      button:SetAlpha(0)
    elseif not hide and hidden[button] then
      hidden[button] = nil
      button:SetAlpha(1)
    end
  end
end

-- One pass a frame later (several events come together; the action of a new page is set after its event).
local function Queue()
  if pending then
    return
  end
  pending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0, H.Update)
  else
    H.Update()
  end
end
H.Queue = Queue

local function Start()
  if not frame then
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", Queue)
    if EditModeManagerFrame and EditModeManagerFrame.HookScript then
      EditModeManagerFrame:HookScript("OnShow", Queue)
      EditModeManagerFrame:HookScript("OnHide", Queue)
    end
  end
  for _, event in ipairs(EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  for _, button in ipairs(Buttons()) do
    if not hooked[button] and button.HookScript then
      hooked[button] = true
      -- the game writes "showgrid" when a drag starts and ends; the button's own updates may reset its alpha
      button:HookScript("OnAttributeChanged", function(_, name)
        if name == "showgrid" or name == "action" then
          Queue()
        end
      end)
      button:HookScript("OnShow", Queue)
    end
  end
  H.Update()
end

local function Stop()
  if frame then
    frame:UnregisterAllEvents()
  end
  H.Update() -- every held button back to alpha 1
end

Q.AddToggle({
  key = KEY,
  name = L["Hide empty slots"],
  desc = L["Action bar slots with nothing in them are hidden. They show again while you drag a spell or item, while Edit Mode is open and while you bind keys by hovering, so there is always somewhere to put it."],
  default = false,
  order = 30,
  Enable = function()
    if Q.On(KEY) then -- every toggle's Enable runs at the module's start; nothing is hooked while off
      Start()
    end
  end,
  Changed = function(on)
    if on then
      Start()
    else
      Stop()
    end
  end,
})
