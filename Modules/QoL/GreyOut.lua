local addonName, ns = ...
local L = ns.L

-- Grey out what you can't use (2026-11-22, the user's request: "spells in action bar greyed out when they are not
-- available (mana, range etc) instead of making their keybind text red"). Forever's buttons (forever branch,
-- Blizzard_ActionBar/Shared/ActionButton.lua): ActionBarActionButtonMixin:UpdateUsable tints the icon (blue without
-- mana, dark grey when unusable) and the global ActionButton_UpdateRangeIndicator(self, checksRange, inRange) turns
-- the key text red out of range. With this on, post hooks (hooksecurefunc: nothing of Blizzard's replaced, nothing
-- secure touched, so it works in combat) put the key text's colour back (ACTIONBAR_HOTKEY_FONT_COLOR, the in-range
-- one) and grey the icon instead: desaturated and dimmed while the button is out of range, short of mana or
-- unusable. A secret answer counts as usable / in range (nothing is greyed on a guess).

local Q = ns.qol
local KEY = "greyOut"
local BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local DIM = 0.55

local G = {}
Q.greyOut = G
local hooked = setmetatable({}, { __mode = "k" })
local outOfRange = setmetatable({}, { __mode = "k" }) -- [button] = true while the game says out of range

local function Plain(value)
  if value == nil or (issecretvalue and issecretvalue(value)) then
    return nil
  end
  return value
end

local function HotkeyBack(button)
  local hotkey = button.HotKey
  local color = ACTIONBAR_HOTKEY_FONT_COLOR
  if hotkey and hotkey.SetVertexColor and color and color.GetRGB then
    hotkey:SetVertexColor(color:GetRGB())
  end
end

-- The icon's look for the button's state now: greyed or as the game has it.
function G.Paint(button)
  local icon = button and button.icon
  if not (icon and icon.SetDesaturated and button.action) then
    return
  end
  local usable, noMana
  if C_ActionBar and C_ActionBar.IsUsableAction then
    local ok, a, b = pcall(C_ActionBar.IsUsableAction, button.action)
    if ok then
      usable, noMana = Plain(a), Plain(b)
    end
  end
  local grey = outOfRange[button] or usable == false or noMana == true
  if grey then
    icon:SetDesaturated(true)
    icon:SetVertexColor(DIM, DIM, DIM)
  else
    local locked = C_LevelLink and C_LevelLink.IsActionLocked and Plain(select(2, pcall(C_LevelLink.IsActionLocked, button.action)))
    icon:SetDesaturated(locked == true)
    icon:SetVertexColor(1, 1, 1)
  end
end

local function AfterUsable(button)
  if Q.On(KEY) then
    G.Paint(button)
  end
end

local function AfterRange(button, checksRange, inRange)
  if not (Q.On(KEY) and hooked[button]) then
    return
  end
  checksRange, inRange = Plain(checksRange), Plain(inRange)
  local before = outOfRange[button]
  outOfRange[button] = (checksRange == true and inRange == false) or nil
  -- the range dot (no key bound) keeps the game's red: that is all it shows
  if button.HotKey and button.HotKey.GetText and button.HotKey:GetText() ~= RANGE_INDICATOR then
    HotkeyBack(button)
  end
  if before ~= outOfRange[button] then
    G.Paint(button)
  end
end

function G.Hook()
  for _, prefix in ipairs(BUTTONS) do
    for index = 1, 12 do
      local button = _G[prefix .. index]
      if type(button) == "table" and not hooked[button] and type(button.UpdateUsable) == "function" then
        hooked[button] = true
        hooksecurefunc(button, "UpdateUsable", AfterUsable)
      end
    end
  end
  if not G.rangeHooked and type(ActionButton_UpdateRangeIndicator) == "function" then
    G.rangeHooked = true
    hooksecurefunc("ActionButton_UpdateRangeIndicator", AfterRange)
  end
end

-- Every hooked button again (switched on: greyed now; off: the game's own look back).
function G.Refresh()
  for button in pairs(hooked) do
    if Q.On(KEY) then
      G.Paint(button)
    else
      outOfRange[button] = nil
      if type(button.UpdateUsable) == "function" then
        pcall(button.UpdateUsable, button)
      end
      if button.icon and button.icon.SetDesaturated then
        button.icon:SetDesaturated(false)
      end
    end
  end
end

Q.AddToggle({
  key = KEY,
  name = L["Grey out what you can't use"],
  desc = L["Action buttons you can't use right now (out of range, not enough mana, rage or energy, or not usable) turn grey, and the key text keeps its colour instead of turning red."],
  default = false,
  order = 29,
  Enable = function()
    if Q.On(KEY) then -- every toggle's Enable runs at the module's start; nothing is hooked while off
      G.Hook()
      G.Refresh()
    end
  end,
  Changed = function(on)
    if on then
      G.Hook()
    end
    G.Refresh()
  end,
})
