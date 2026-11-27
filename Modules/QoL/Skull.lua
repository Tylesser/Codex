local addonName, ns = ...
local L = ns.L
local Q = ns.qol
local UI = ns.UI

-- Skull mark (2026-11-26, the user's request: "mark the mob player attacks with skull mark if role assigned to
-- skull"). Since patch 12.0 SetRaidTarget is protected (forever branch RaidMarkersDocumentation: HasRestrictions;
-- warcraft.wiki.gg API_SetRaidTarget: "#protected", 12.0.0), so an addon can't mark what you attack by itself. What
-- it can do: a secure button (SecureActionButtonTemplate with the "raidtarget" action, forever SecureTemplates.lua;
-- action "set" puts the marker on and never takes it off) that your key or your click runs. The key and the button
-- work only while your group role is the one the skull belongs to (UnitGroupRolesAssigned("player"): TANK, HEALER,
-- DAMAGER or NONE = no role set). Secure frames and override keys change only out of combat: the role is checked
-- then, and again when a fight ends. GetRaidTargetIndex is secret on Forever, so the addon never reads markers.
--   CodexDB.qol: skullMark (on/off), skullRole ("tank" / "healer" / "damage" / "any"), skullNoRole (also with no
--   role set), skullGroupOnly, skullButton (show the button), skullKey ("SHIFT-Q"), skullPos ({ point, x, y })

local KEY = "skullMark"
local BUTTON = "CodexSkullButton"
local SKULL = 8
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local S = {}
Q.skull = S
S.BUTTON = BUTTON

S.ROLES = { { "tank", L["Tank"] }, { "healer", L["Healer"] }, { "damage", L["Damage"] }, { "any", L["Any role"] } }
local ROLE_KEYS = { TANK = "tank", HEALER = "healer", DAMAGER = "damage", NONE = "none" }
local ROLE_NAMES = { tank = L["tank"], healer = L["healer"], damage = L["damage"] }
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local button
local view = {}
S.view = view

local function Plain(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if canaccessvalue and not canaccessvalue(value) then
    return nil
  end
  return value
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    return nil
  end
  return Plain(value)
end

local function Combat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

-- Your group role: "tank", "healer", "damage" or "none"; nil when the game doesn't say.
function S.Role()
  local role = Ask(UnitGroupRolesAssigned, "player")
  return type(role) == "string" and ROLE_KEYS[role] or nil
end

function S.InGroup()
  return Ask(IsInGroup) == true
end

-- Why the skull key doesn't work right now (a sentence), or nil when it does.
function S.Blocked()
  local db = Q.DB()
  if not Q.On(KEY) then
    return L["Skull mark is off."]
  end
  if db.skullGroupOnly ~= false and not S.InGroup() then
    return L["Only in a group, and you are not in one."]
  end
  local want = db.skullRole or "tank"
  if want == "any" then
    return nil
  end
  local role = S.Role()
  if role == nil or role == want then
    return nil -- (a role the game doesn't tell: the key works)
  end
  if role == "none" then
    if db.skullNoRole ~= false then
      return nil
    end
    return L["You have no group role, and the skull is the %s's."]:format(ROLE_NAMES[want] or want)
  end
  return L["Your role is %s; the skull is the %s's."]:format(ROLE_NAMES[role] or role, ROLE_NAMES[want] or want)
end

function S.KeyText(key)
  if not key then
    return L["No key"]
  end
  local text = GetBindingText and Ask(GetBindingText, key)
  return (type(text) == "string" and text ~= "") and text or key
end

-- The button -------------------------------------------------------------------------------------------------

local function SavePlace()
  local point, _, _, x, y = button:GetPoint(1)
  Q.DB().skullPos = { point or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
end

local function Place()
  local pos = Q.DB().skullPos
  button:ClearAllPoints()
  if type(pos) == "table" then
    button:SetPoint(pos[1] or "CENTER", UIParent, pos[1] or "CENTER", pos[2] or 0, pos[3] or 0)
  else
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
  end
end

local function ShowTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Skull mark"])
  local blocked = S.Blocked()
  if blocked then
    GameTooltip:AddLine(blocked, 1, 0.5, 0.4, true)
  else
    GameTooltip:AddLine(L["Click: the skull on your target."], 1, 1, 1, true)
  end
  local key = Q.DB().skullKey
  if key then
    GameTooltip:AddLine(L["Key: %s"]:format(S.KeyText(key)), 0.7, 0.7, 0.7)
  end
  GameTooltip:AddLine(L["Right-click: options. Right-drag: move it (out of combat)."], 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end

local function Build()
  button = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
  button:SetSize(36, 36)
  button:SetFrameStrata("MEDIUM")
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:RegisterForDrag("RightButton")
  -- the action: left button (and the key, which clicks "LeftButton") only; on release
  button:SetAttribute("useOnKeyDown", false)
  button:SetAttribute("unit", "target")
  button:SetAttribute("marker", SKULL)
  button:SetAttribute("action", "set")
  UI.Inset(UIParent, button)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 4, -4)
  button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  button.icon:SetTexture(ICON)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetPoint("TOPLEFT", 2, -2)
  hover:SetPoint("BOTTOMRIGHT", -2, 2)
  UI.SetColor(hover, ns.InkTheme().accent, 0.18)
  button:HookScript("OnClick", function(self, mouse, down)
    if mouse == "RightButton" and not down then
      if self.dragged then
        self.dragged = nil -- the release that ends a right-drag is no click
      elseif not Combat() then
        ns.ShowPage("qol-" .. KEY)
      end
    end
  end)
  button:SetScript("OnDragStart", function(self)
    if not Combat() then
      self.dragged = true
      self:StartMoving()
    end
  end)
  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePlace()
  end)
  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:Hide()
  Place()
  S.button = button
end

-- Brings the button, its action and the key in step with the settings and your role. Out of combat only.
function S.Apply()
  if Combat() then
    S.pending = true
    return false
  end
  S.pending = false
  local on = Q.On(KEY)
  if on and not button then
    Build()
  end
  if not button then
    return true
  end
  local db = Q.DB()
  local active = on and not S.Blocked()
  button:SetAttribute("type1", active and "raidtarget" or nil)
  ClearOverrideBindings(button)
  if active and db.skullKey then
    SetOverrideBindingClick(button, true, db.skullKey, BUTTON, "LeftButton")
  end
  local grouped = db.skullGroupOnly == false or S.InGroup()
  button:SetShown(on and db.skullButton ~= false and grouped and true or false)
  button.icon:SetDesaturated(not active)
  button:SetAlpha(active and 1 or 0.5)
  return true
end

function S.ResetPlace()
  Q.DB().skullPos = nil
  if button and not Combat() then
    Place()
  end
end

-- Key capture on the options page -----------------------------------------------------------------------------

function S.StopCapture()
  if not view.capturing then
    return
  end
  view.capturing = false
  if view.key then
    view.key:EnableKeyboard(false)
  end
end

function S.CaptureKey(key)
  if not view.capturing or MODIFIER_KEYS[key] then
    return false
  end
  S.StopCapture()
  if key ~= "ESCAPE" then
    local prefix = ""
    if IsAltKeyDown and IsAltKeyDown() then
      prefix = prefix .. "ALT-"
    end
    if IsControlKeyDown and IsControlKeyDown() then
      prefix = prefix .. "CTRL-"
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
      prefix = prefix .. "SHIFT-"
    end
    S.SetKey(prefix .. key)
  elseif Q.RefreshPage then
    Q.RefreshPage()
  end
  return true
end

function S.SetKey(key)
  if Combat() then
    ns.Say(L["The skull key can only be changed out of combat."])
    return false
  end
  Q.DB().skullKey = key
  S.Apply()
  if Q.RefreshPage then
    Q.RefreshPage()
  end
  return true
end

local function BuildKeyRow(body, last, sub)
  local holder = CreateFrame("Frame", nil, body)
  holder:SetHeight(24)
  holder:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
  holder:SetPoint("RIGHT", 0, 0)
  sub.label = UI.Text(holder, "body", 12, "text")
  sub.label:SetPoint("LEFT", 0, 0)
  sub.label:SetText(L["Key"])
  local key = UI.Button(holder, 160, 22, "")
  key:SetPoint("LEFT", 120, 0)
  key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  key:SetScript("OnClick", function(_, mouse)
    if view.capturing then
      S.StopCapture()
    elseif mouse == "RightButton" then
      S.SetKey(nil)
      return
    elseif Combat() then
      ns.Say(L["The skull key can only be changed out of combat."])
    else
      view.capturing = true
      key:EnableKeyboard(true)
      pcall(key.SetPropagateKeyboardInput, key, false)
    end
    if Q.RefreshPage then
      Q.RefreshPage()
    end
  end)
  key:SetScript("OnKeyDown", function(_, pressed)
    S.CaptureKey(pressed)
  end)
  key:SetScript("OnMouseDown", function(_, mouse)
    if view.capturing and MOUSE_KEYS[mouse] then
      S.CaptureKey(MOUSE_KEYS[mouse])
    end
  end)
  view.key = key
  sub.button = key -- greyed with the rest while Skull mark is off
  sub.hint = UI.Text(holder, "body", 11, "muted")
  sub.hint:SetPoint("LEFT", key, "RIGHT", 10, 0)
  sub.hint:SetPoint("RIGHT", 0, 0)
  sub.hint:SetJustifyH("LEFT")
  sub.status = UI.Text(body, "body", 11, "muted")
  sub.status:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -6)
  sub.status:SetPoint("RIGHT", 0, 0)
  sub.status:SetJustifyH("LEFT")
  return sub.status
end

local function RefreshKeyRow(sub, on)
  local db = Q.DB()
  if view.key then
    view.key:SetText(view.capturing and L["Press a key..."] or S.KeyText(db.skullKey))
  end
  sub.hint:SetText(L["Click, then press a key. Right-click to clear."])
  local blocked = S.Blocked()
  if not on then
    sub.status:SetText("")
  elseif blocked then
    sub.status:SetText(L["Not now: %s"]:format(blocked))
  else
    sub.status:SetText(L["Ready: your key and the button put the skull on your target."])
  end
end

-- Events ------------------------------------------------------------------------------------------------------

local function Enable()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      S.StopCapture()
    elseif event ~= "PLAYER_REGEN_ENABLED" or S.pending then
      S.Apply()
    end
    if Q.RefreshPage then
      Q.RefreshPage()
    end
  end)
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    pcall(events.RegisterEvent, events, event)
  end
  S.events = events
  S.Apply()
end

local function Changed()
  S.Apply()
end

Q.AddToggle({
  key = KEY,
  name = L["Skull mark"],
  desc = L["A key (and a button) that puts the skull on your target, only while your group role is the one the skull belongs to. The game doesn't let addons mark on their own, so it marks when you press the key: press it as you pull. It never takes the skull off."],
  default = false,
  order = 60,
  Enable = Enable,
  Changed = Changed,
  options = {
    { key = "skullRole", kind = "choice", name = L["Skull is for"], default = "tank", choices = S.ROLES,
      Changed = Changed },
    { key = "skullNoRole", name = L["Also when you have no group role"], Changed = Changed },
    { key = "skullGroupOnly", name = L["Only in a party or raid"], Changed = Changed },
    { key = "skullButton", name = L["Show the skull button"], Changed = Changed },
    { key = "skullKeyRow", kind = "custom", Build = BuildKeyRow, Refresh = RefreshKeyRow },
    { key = "skullReset", kind = "button", name = L["Put the button back"], Click = S.ResetPlace },
  },
})

-- /codex skull: its section
local module = ns.modules and ns.modules.qol
if module then
  module.commands = module.commands or {}
  module.commands.skull = function()
    ns.ShowPage("qol-" .. KEY)
  end
end
