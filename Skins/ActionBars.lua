local addonName, ns = ...
local L = TylesserCodex.L
local S = ns.S

-- Action bars: every action button (main bar, the multi-bars, pet, stance, possess, totem bar and the vehicle
-- bar) gets the theme's slot look: a dark fill, the slot rings over the icon's edge, the icon cropped, Blizzard's
-- bronze frame, slot art and dividers made invisible (again after each of Blizzard's art updates), and clean
-- white Arial numbers for hotkeys, counts, macro names and cooldowns.
-- Behind the bars (setting "Panel behind the action bars"): one theme panel per bar, fitted to the buttons
-- the bar shows (not to the bar's Edit Mode box, which is larger), fitted again out of combat after Edit Mode,
-- slot changes and buttons showing or hiding.
-- The gryphons are made invisible, the experience / reputation bars get the slim HUD look, the bag buttons the
-- slot look, the micro menu buttons the slot look in place of their dark backplates, and the bag bar and micro
-- menu lose their border art.
-- Bars and buttons are secure: only our own textures and frames are drawn, Blizzard art only gets alpha 0, and
-- nothing of Blizzard's is moved, sized, shown, hidden or given a field.

local NUMBER_FONT = "Fonts\\ARIALN.TTF"
-- Round-2 HUD board (R2-HUD): a slot with something in it sits on black at 55% under the theme's slot rings
-- ("rgba(0,0,0,.55)" + "slot"); an empty slot is a light see-through shade (design "slotEmpty": the theme's
-- bright colour at 7%) with one thin line (design "slotEmptyLine": the slot's brightest ring at 45%).
local FILLED_ALPHA, EMPTY_ALPHA, EMPTY_LINE_ALPHA = 0.55, 0.07, 0.45
local PANEL_PAD = 7 -- design: 7 px between the panel's edge and the slots
local XP_TEXT = { 0.9, 0.86, 0.94 } -- design "xpText": a pale lavender, nearly the same in every theme
local HOTKEY_COLOR, WHITE = { 0.88, 0.88, 0.88 }, { 1, 1, 1 }

local BUTTONS = {
  { "ActionButton", 12 }, { "MultiBarBottomLeftButton", 12 }, { "MultiBarBottomRightButton", 12 },
  { "MultiBarRightButton", 12 }, { "MultiBarLeftButton", 12 }, { "MultiBar5Button", 12 }, { "MultiBar6Button", 12 },
  { "MultiBar7Button", 12 }, { "PetActionButton", 10 }, { "StanceButton", 10 }, { "PossessButton", 2 },
  { "MultiCastActionButton", 12 },
}
local SINGLE_BUTTONS = { "MultiCastSummonSpellButton", "MultiCastRecallSpellButton" }

-- Bars that get a panel (each its own), with their buttons.
local BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
  "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar", "MultiCastActionBarFrame" }
local BAR_BUTTONS = { MainActionBar = { "ActionButton", 12 }, MultiBarBottomLeft = { "MultiBarBottomLeftButton", 12 },
  MultiBarBottomRight = { "MultiBarBottomRightButton", 12 }, MultiBarRight = { "MultiBarRightButton", 12 },
  MultiBarLeft = { "MultiBarLeftButton", 12 }, MultiBar5 = { "MultiBar5Button", 12 }, MultiBar6 = { "MultiBar6Button", 12 },
  MultiBar7 = { "MultiBar7Button", 12 }, StanceBar = { "StanceButton", 10 }, PetActionBar = { "PetActionButton", 10 },
  PossessActionBar = { "PossessButton", 2 }, MultiCastActionBarFrame = { "MultiCastActionButton", 12 } }
-- Not bars, but on the bottom row with them: a panel each too (design).
local PANEL_EXTRAS = { "MicroMenu", "BagsBar" }
local BAG_SLOTS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
  "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }

local part = "actionbars"

-- Buttons -----------------------------------------------------------------------------------------------------

local small = setmetatable({}, { __mode = "k" }) -- [button] = true for SmallActionButtonMixin buttons (pet, stance)

local function Clean(text, size, color)
  if not S.IsRegion(text) or not text.SetFont then
    return
  end
  text:SetFont(NUMBER_FONT, size, "OUTLINE")
  if text.SetShadowOffset then
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
  end
  if color and text.SetTextColor then
    text:SetTextColor(color[1], color[2], color[3], 1)
  end
end

local function Part(button, key, suffix)
  local name = S.Name(button)
  return S.Region(button, key) or (name and S.Get(name .. suffix))
end

local function ButtonText(button)
  local tiny = small[button]
  Clean(Part(button, "HotKey", "HotKey"), tiny and 10 or 12, HOTKEY_COLOR)
  Clean(Part(button, "Count", "Count"), tiny and 11 or 13, WHITE)
  Clean(Part(button, "Name", "Name"), tiny and 9 or 10, WHITE)
  -- the cooldown numbers belong to the cooldown frame, a child of the button: above our rings
  local name = S.Name(button)
  local cooldown = S.Child(button, "cooldown") or (name and S.Get(name .. "Cooldown"))
  if S.Usable(cooldown) and type(cooldown.GetCountdownFontString) == "function" then
    local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
    if ok then
      Clean(text, tiny and 13 or 17, WHITE)
    end
  end
end

-- Blizzard's art, made invisible again after each of its updates.
local SlotState -- below
local function ButtonArt(button)
  S.SlotArt(button)
  S.KillKeys(button, "RightDivider", "BottomDivider")
  ButtonText(button)
  SlotState(button)
end

-- The slot box every button of the row shares (action, bag, leave): a fill behind `box` and the slot rings over
-- its edge. mode nil: an action slot, filled or empty from whether its icon shows (updated after Blizzard's
-- updates); "bag": always the full rings on the light shade (design: bag buttons); "full": always filled.
local slotParts = setmetatable({}, { __mode = "k" }) -- [button] = { fill, rings, thin, icon, mode }

local function EmptyLine()
  local theme = S.Theme()
  local c = S.LineColor(theme.slot.rings)
  return { c[1], c[2], c[3], EMPTY_LINE_ALPHA }
end

function SlotState(button)
  local parts = slotParts[button]
  if not parts then
    return
  end
  local theme = S.Theme()
  local full = parts.mode ~= nil
  if not parts.mode then
    local ok, shown = false, nil
    if parts.icon and parts.icon.IsShown then
      ok, shown = pcall(parts.icon.IsShown, parts.icon)
    end
    full = ok and (not canaccessvalue or canaccessvalue(shown)) and shown == true
  end
  -- (a rounded slot's fill is a list of pieces; each takes SetColorTexture)
  local fills = parts.fill.round and parts.fill or { parts.fill }
  for _, fill in ipairs(fills) do
    if parts.mode == "bag" or not full then
      S.SetColor(fill, theme.bright, EMPTY_ALPHA)
    else
      S.SetColor(fill, theme.slot.fill, (theme.slot.fill[4] or 1) * FILLED_ALPHA)
    end
  end
  for _, line in ipairs(parts.rings) do
    line:SetShown(full)
  end
  for _, line in ipairs(parts.thin) do
    line:SetShown(not full)
  end
end

local function SlotStates()
  for button in pairs(slotParts) do
    SlotState(button)
  end
end

local function SlotBox(button, box, mode)
  local look = S.Look("slot")
  local radius = S.Radius("slot")
  if radius then
    -- rounded (Dusk, Dawn): the fill, the ring and the faint empty line as rounded pieces round the icon
    local fill = S.UI.RoundFill(button, box, radius, look.fill, { sublevel = -8 })
    local ring = look.rings[1]
    local rings = ring and S.UI.RoundLine(button, box, radius, ring.color, { layer = "OVERLAY", sublevel = 1 }) or {}
    local thin = S.UI.RoundLine(button, box, radius, EmptyLine(), { layer = "OVERLAY", sublevel = 1 })
    slotParts[button] = { fill = fill, rings = rings, thin = thin, icon = box ~= button and box or nil, mode = mode }
    SlotState(button)
    return
  end
  local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints(box)
  local rings = {}
  for _, ring in ipairs(look.rings) do
    for _, line in ipairs(S.Outline(button, box, ring.inset, ring.size, ring.color, "OVERLAY", 1)) do
      rings[#rings + 1] = line
    end
  end
  local thin = S.Outline(button, box, 0, 1, EmptyLine(), "OVERLAY", 1)
  slotParts[button] = { fill = fill, rings = rings, thin = thin, icon = box ~= button and box or nil, mode = mode }
  SlotState(button)
end

local stateQueued = false
local function SlotStatesSoon()
  if stateQueued then
    return
  end
  stateQueued = true
  -- after Blizzard has shown or hidden the icons
  C_Timer.After(0, function()
    stateQueued = false
    S.Run(part, SlotStates)
  end)
end

local function ActionSlot(button, mode)
  if not S.Usable(button) or not S.Once(button, "slot") then
    return false
  end
  -- read before the hook below replaces the method on the button
  if SmallActionButtonMixin and button.UpdateButtonArt ~= nil
    and button.UpdateButtonArt == SmallActionButtonMixin.UpdateButtonArt then
    small[button] = true
  end
  local icon = S.IconOf(button)
  if icon then
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    for _, key in ipairs({ "IconMask", "CircleMask" }) do
      local mask = S.Child(button, key)
      if mask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, mask)
      end
    end
  end
  -- round the icon, not the button: the small buttons' icons are larger than the button
  SlotBox(button, icon or button, mode)
  if icon then
    S.RoundIcon(button, icon) -- a rounded theme: the icon cut to the slot's corners (Blizzard's IconMask is off)
    -- the cooldown swipe over the whole icon: Forever's template (Mainline ActionButtonTemplate.xml) sets the
    -- cooldowns 3 px inside the icon (2 for the charges), which left a grey wedge short of the slot's edges once the
    -- icon fills it (the user's screenshots, 2026-11-22)
    for _, key in ipairs({ "cooldown", "lossOfControlCooldown", "chargeCooldown" }) do
      local cooldown = S.Child(button, key)
      if S.Usable(cooldown) and not (cooldown.IsProtected and cooldown:IsProtected()) then
        pcall(cooldown.ClearAllPoints, cooldown)
        pcall(cooldown.SetAllPoints, cooldown, icon)
      end
    end
  end
  ButtonArt(button)
  S.HookMethod(button, "UpdateButtonArt", ButtonArt)
  S.HookMethod(button, "Update", SlotState)
  return true
end

local function SkinButtons()
  for _, set in ipairs(BUTTONS) do
    for index = 1, set[2] do
      ActionSlot(S.Get(set[1] .. index))
    end
  end
  for _, name in ipairs(SINGLE_BUTTONS) do
    ActionSlot(S.Get(name))
  end
end

-- The vehicle / override bar (its own load-on-demand addon on some clients).
local function SkinOverrideBar()
  local bar = S.Get("OverrideActionBar")
  for index = 1, 6 do
    ActionSlot(S.Child(bar, "SpellButton" .. index))
  end
end

-- Panels -----------------------------------------------------------------------------------------------------

local panels = {} -- [bar] = { host = our frame, plate = S.Plate result }

-- Tight round the buttons: bars sit close together (and the experience bar between them), so a wide edge
-- or big studs would run into the next bar's panel.
local function Pad()
  return PANEL_PAD
end


local function Panel(bar, name)
  if panels[bar] then
    return panels[bar]
  end
  if not S.Usable(bar) then
    return nil
  end
  S.KillKeys(bar, "BorderArt", "Background", "BackgroundArt")
  local host = CreateFrame("Frame", nil, bar)
  -- under everything of the game's interface (bars, experience bar, micro menu), shown and hidden with the bar
  host:SetFrameStrata("BACKGROUND")
  host:SetFrameLevel(1)
  local panel = { host = host, name = name }
  -- design: the bar panels have no studs
  panel.plate = S.Plate(host, "panel", {})
  panels[bar] = panel
  return panel
end

-- Numbers we may compare (positions can be secret on Forever).
local function Plain(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if type(value) ~= "number" or (canaccessvalue and not canaccessvalue(value)) then
      return false
    end
  end
  return true
end

-- A yes / no Blizzard may hand out as a secret: read as no.
local function Yes(value)
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return value == true
end

local function Ask(frame, method)
  if not S.Usable(frame) or type(frame[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(frame[method], frame)
  if ok then
    return value
  end
end

local function IsShownButton(button)
  return Yes(Ask(button, "IsShown"))
end

-- The shown buttons of a bar and their outer edges: edges = { left = button, right, top, bottom } (the button
-- holding each edge) and their values; nil and the reason when none is shown or a position can't be read.
local MicroList -- below

-- The buttons a panel goes round, and whether the panel's frame is one we know the buttons of.
local function ButtonsOf(name)
  local list, set = {}, BAR_BUTTONS[name]
  if set then
    for index = 1, set[2] do
      list[#list + 1] = S.Get(set[1] .. index)
    end
    return list, true
  elseif name == "MicroMenu" then
    return MicroList(), true
  elseif name == "BagsBar" then
    for _, slot in ipairs(BAG_SLOTS) do
      list[#list + 1] = S.Get(slot)
    end
    return list, true
  end
  return list, false
end

local function Edges(name)
  local edges, values
  for _, button in pairs((ButtonsOf(name))) do
    if IsShownButton(button) and button.GetLeft then
      local ok, left, right, top, bottom = pcall(function()
        return button:GetLeft(), button:GetRight(), button:GetTop(), button:GetBottom()
      end)
      if not ok or not Plain(left, right, top, bottom) then
        return nil, nil, "position of " .. tostring(S.Name(button)) .. " unreadable"
      end
      if not edges then
        edges = { left = button, right = button, top = button, bottom = button }
        values = { left = left, right = right, top = top, bottom = bottom }
      else
        if left < values.left then edges.left, values.left = button, left end
        if right > values.right then edges.right, values.right = button, right end
        if top > values.top then edges.top, values.top = button, top end
        if bottom < values.bottom then edges.bottom, values.bottom = button, bottom end
      end
    end
  end
  if not edges then
    return nil, nil, "no button shown"
  end
  return edges, values
end

local function AnyShown(name)
  local list, known = ButtonsOf(name)
  for _, button in pairs(list) do
    if IsShownButton(button) then
      return true
    end
  end
  return not known
end

-- The frame our panel lives on, so it shows and hides with the buttons: the bar, unless the bar itself is
-- not visible or clips what lies outside it while its buttons show (they then sit on another frame: the
-- panel goes on the nearest visible frame above the shown button, or on UIParent as a last resort).
local function Fits(frame)
  return S.Usable(frame) and Yes(Ask(frame, "IsVisible")) and not Yes(Ask(frame, "DoesClipChildren"))
end

local function Holder(bar, button)
  -- buttons hidden with their bar (a vehicle, a bar switched off): the panel stays with the bar
  if Fits(bar) or not button or not Yes(Ask(button, "IsVisible")) then
    return bar
  end
  local parent = Ask(button, "GetParent")
  while parent and parent ~= UIParent and parent ~= bar do
    if Fits(parent) then
      return parent
    end
    parent = Ask(parent, "GetParent")
  end
  return UIParent
end

local function Rehome(host, holder)
  if Ask(host, "GetParent") ~= holder then
    host:SetParent(holder)
    host:SetFrameStrata("BACKGROUND")
    host:SetFrameLevel(1)
  end
end

-- Fits a panel round the buttons its bar shows (round the bar when they can't be measured; hidden when the
-- bar shows none). Out of combat: it is anchored to secure buttons.
local function Fit(bar, panel)
  local host, pad = panel.host, Pad()
  host:ClearAllPoints()
  local edges, values, reason = Edges(panel.name)
  panel.edges, panel.fail = edges and (S.Name(edges.left) .. ".." .. S.Name(edges.right)) or nil, reason
  if not edges then
    if not AnyShown(panel.name) then
      host:Hide()
      return
    end
    Rehome(host, Holder(bar, nil))
    host:SetPoint("TOPLEFT", bar, "TOPLEFT", -pad, pad)
    host:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pad, -pad)
    host:Show()
    return
  end
  Rehome(host, Holder(bar, edges.left))
  -- the buttons' units -> the panel's (Edit Mode's icon size scales the buttons)
  local k = 1
  local ok, own, theirs = pcall(function() return host:GetEffectiveScale(), edges.left:GetEffectiveScale() end)
  if ok and Plain(own, theirs) and own > 0 then
    k = theirs / own
  end
  local leftTop, rightBottom = edges.left:GetTop(), edges.right:GetBottom()
  if not Plain(leftTop, rightBottom) then
    leftTop, rightBottom = values.top, values.bottom
  end
  host:SetPoint("TOPLEFT", edges.left, "TOPLEFT", -pad, (values.top - leftTop) * k + pad)
  host:SetPoint("BOTTOMRIGHT", edges.right, "BOTTOMRIGHT", pad, (values.bottom - rightBottom) * k - pad)
  host:Show()
end

local function FitAll()
  for bar, panel in pairs(panels) do
    -- one bar that can't be fitted must not stop the others
    local ok, err = pcall(Fit, bar, panel)
    panel.error = not ok and tostring(err) or nil
  end
end

-- For a /codex debug command: per bar what the panel did.
TylesserCodex.BarDebug = function()
  local list = {}
  for _, name in ipairs(BARS) do
    local bar = S.Get(name)
    local panel = panels[bar]
    local info = { name = name, bar = bar ~= nil, panel = panel ~= nil }
    if bar then
      info.barShown, info.barVisible = Ask(bar, "IsShown"), Ask(bar, "IsVisible")
      info.barAlpha, info.clips = Ask(bar, "GetEffectiveAlpha"), Ask(bar, "DoesClipChildren")
      local set = BAR_BUTTONS[name]
      local first = set and S.Get(set[1] .. "1")
      local parent = first and Ask(first, "GetParent")
      info.buttonParent = parent and (S.Name(parent) or (parent == bar and name) or "unnamed frame") or nil
    end
    if panel then
      local host = panel.host
      local parent = Ask(host, "GetParent")
      info.hostShown, info.hostVisible = Ask(host, "IsShown"), Ask(host, "IsVisible")
      info.hostParent = parent and (S.Name(parent) or (parent == bar and name) or "unnamed frame") or nil
      info.points = Ask(host, "GetNumPoints")
      info.edges, info.fail, info.error = panel.edges, panel.fail, panel.error
    end
    for key, value in pairs(info) do
      if canaccessvalue and not canaccessvalue(value) then
        info[key] = "secret"
      end
    end
    list[#list + 1] = info
  end
  return list
end

-- Spacing check for the setup guide (Codex Settings > "Check spacing"): which shown panels overlap and how
-- far one would have to move to clear the other. Returns nil when panels are off or can't be measured
-- (in combat), else a list of { a = name, b = name, x = units, y = units } (empty = all clear).
local BAR_NAMES = { MainActionBar = L["Main bar"], MultiBarBottomLeft = L["Bar 2"], MultiBarBottomRight = L["Bar 3"],
  MultiBarRight = L["Bar 4"], MultiBarLeft = L["Bar 5"], MultiBar5 = L["Bar 6"], MultiBar6 = L["Bar 7"], MultiBar7 = L["Bar 8"],
  StanceBar = L["Stance bar"], PetActionBar = L["Pet bar"], PossessActionBar = L["Possess bar"],
  MultiCastActionBarFrame = L["Totem bar"], MicroMenu = L["Micro menu"], BagsBar = L["Bags"] }

local function PanelRect(panel)
  local host = panel.host
  if not host:IsShown() then
    return nil
  end
  local ok, left, bottom, width, height = pcall(host.GetRect, host)
  if not ok or not Plain(left, bottom, width, height) then
    return nil
  end
  local scale = host:GetEffectiveScale()
  return { left = left * scale, bottom = bottom * scale, right = (left + width) * scale,
    top = (bottom + height) * scale, scale = scale }
end

TylesserCodex.BarSpacing = function()
  if not next(panels) or S.InCombat() then
    return nil
  end
  FitAll()
  local list = {}
  for _, name in ipairs(BARS) do
    local panel = panels[S.Get(name)]
    local rect = panel and PanelRect(panel)
    if rect then
      list[#list + 1] = { name = BAR_NAMES[name] or name, rect = rect }
    end
  end
  local found = {}
  for i = 1, #list do
    for j = i + 1, #list do
      local a, b = list[i].rect, list[j].rect
      local x = math.min(a.right, b.right) - math.max(a.left, b.left)
      local y = math.min(a.top, b.top) - math.max(a.bottom, b.bottom)
      if x > 0.5 and y > 0.5 then
        -- in UI units (as Edit Mode shows them)
        local root = UIParent:GetEffectiveScale()
        found[#found + 1] = { a = list[i].name, b = list[j].name, x = math.ceil(x / root), y = math.ceil(y / root) }
      end
    end
  end
  return found
end

local fitQueued = false
local function FitSoon()
  if fitQueued then
    return
  end
  fitQueued = true
  -- after Blizzard's own layout pass, and only out of combat
  C_Timer.After(0, function()
    fitQueued = false
    S.Run(part, function()
      S.Defer("actionbars:fit", FitAll)
    end)
  end)
end

local function WatchFit()
  local events = CreateFrame("Frame")
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID",
    "UPDATE_BONUS_ACTIONBAR", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, event)
  end
  events:SetScript("OnEvent", FitSoon)
  if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", FitSoon, panels)
  end
  -- a button shown or hidden (an empty slot filled, a pet called), a bar switched on
  for bar, panel in pairs(panels) do
    S.HookScript(bar, "OnShow", FitSoon)
    for _, button in pairs((ButtonsOf(panel.name))) do
      if S.Usable(button) then
        S.HookScript(button, "OnShow", FitSoon)
        S.HookScript(button, "OnHide", FitSoon)
      end
    end
  end
end

-- The gryphons: on Forever each one is its own Edit Mode system and ignores the bar's alpha, so each gets alpha
-- 0 (the bar's page number is not part of them and stays).
local function EndCaps()
  local caps = S.Child(S.Get("MainActionBar"), "EndCaps")
  for _, key in ipairs({ "LeftEndCap", "RightEndCap" }) do
    local cap = S.Child(caps, key)
    if S.Usable(cap) and cap.SetAlpha then
      cap:SetAlpha(0)
    end
  end
end

-- Experience, reputation, bags, menu ------------------------------------------------------------------------

-- Experience / reputation bars (MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer, one bar
-- frame each per kind in .bars): Blizzard's art (the rounded track, the segment ticks, the frame) gets alpha 0;
-- each bar gets a dark slot-like track with the thin theme line, and a flat fill in a clear colour taken from
-- the picture Blizzard picks (experience purple, rested blue, honor, the faction's colour); the rested part
-- ahead of the fill a lighter see-through blue. Blizzard's text (shown on hover) in white Arial. These bars are
-- not secure; nothing of theirs is moved or sized, and the look is set again after Blizzard changes it.
-- Codex's bar design (2026-11-22, the user's request "add our designs to rep and exp bars", as the unit frames and
-- Personal bars draw theirs): the fill a vertical gradient (the colour at the top, 60 % of it at the bottom), the
-- rested part the same in see-through blue; a rounded theme (round.bar: Dusk, Dawn) rounds the fill and the track
-- and draws no rings; the rested-level marker (ExhaustionTick, Blizzard's pip picture) becomes a thin upright line
-- in the theme's accent.
local FLAT = "Interface\\Buttons\\WHITE8X8"
local TRACK_ALPHA = 0.85
local FILL_COLORS = { -- by a word in the picture's atlas name, first match wins (muted: the bright ones glared)
  { "Rested", { 0.16, 0.38, 0.68 } }, { "XP", { 0.42, 0.27, 0.72 } }, { "Honor", { 0.75, 0.33, 0.08 } },
  { "Azerite", { 0.7, 0.58, 0.3 } }, { "Artifact", { 0.7, 0.58, 0.3 } }, { "Green", { 0.15, 0.6, 0.2 } },
  { "Red", { 0.65, 0.15, 0.12 } }, { "Orange", { 0.72, 0.38, 0.12 } }, { "Yellow", { 0.78, 0.65, 0.15 } },
  { "Blue", { 0.16, 0.38, 0.68 } }, { "Purple", { 0.42, 0.28, 0.72 } },
}
local RESTED = { 0.3, 0.5, 0.85, 0.35 }

local trackOurs = setmetatable({}, { __mode = "k" }) -- our own textures on the bars
local fillColor = setmetatable({}, { __mode = "k" }) -- [status bar] = colour we hold its fill to, or "faction"

-- The watched faction's colour (the bar picture of a faction may be plain grey, tinted by Blizzard).
local function FactionColor()
  local reaction
  if C_Reputation and C_Reputation.GetWatchedFactionData then
    local ok, data = pcall(C_Reputation.GetWatchedFactionData)
    if ok and type(data) == "table" then
      reaction = data.reaction
    end
  end
  local colors = FACTION_BAR_COLORS
  local c = Plain(reaction) and type(colors) == "table" and colors[reaction]
  if type(c) == "table" and c.r then
    return { c.r, c.g, c.b }
  end
end

-- A texture in the design's vertical gradient of `color` (alpha a): 60 % at the bottom, the colour at the top.
local function Gradient(texture, color, a)
  a = a or 1
  if texture.SetGradient and CreateColor then
    texture:SetVertexColor(1, 1, 1, a)
    local ok = pcall(texture.SetGradient, texture, "VERTICAL",
      CreateColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, a), CreateColor(color[1], color[2], color[3], a))
    if ok then
      return
    end
  end
  texture:SetVertexColor(color[1], color[2], color[3], a)
end

local function HoldColor(status)
  local want = fillColor[status]
  if want == "faction" then
    want = FactionColor()
  end
  local texture = Ask(status, "GetStatusBarTexture")
  if type(want) == "table" and S.IsRegion(texture) then
    Gradient(texture, want)
  end
end

-- After Blizzard sets the bar's picture (asset: what it was given): flat, in the colour that picture stood for.
-- Pictures we don't know stay Blizzard's.
local kindOf = setmetatable({}, { __mode = "k" }) -- [status bar] = "xp" / "rep" (from its picture)
local ShowText -- below

local function FlatFill(status, asset)
  local texture = Ask(status, "GetStatusBarTexture")
  if not S.IsRegion(texture) then
    return
  end
  local atlas = Ask(texture, "GetAtlas")
  if type(atlas) ~= "string" then
    atlas = type(asset) == "string" and asset or nil
  end
  if type(atlas) ~= "string" then
    return
  end
  local want, word
  for _, entry in ipairs(FILL_COLORS) do
    if atlas:find(entry[1], 1, true) then
      want, word = entry[2], entry[1]
      break
    end
  end
  if not want and atlas:find("Reputation", 1, true) then
    want = "faction"
  end
  if word == "XP" or word == "Rested" then
    kindOf[status] = "xp"
  elseif atlas:find("Reputation", 1, true) then
    kindOf[status] = "rep"
  end
  ShowText(status)
  fillColor[status] = want
  if want then
    texture:SetTexture(FLAT)
    HoldColor(status)
  end
end

local function Exhaustion(texture)
  if S.IsRegion(texture) and texture.SetTexture then
    texture:SetTexture(FLAT)
    Gradient(texture, RESTED, RESTED[4])
  end
end

-- The rested-level marker (ExhaustionTick, a button with Blizzard's pip pictures): a thin upright line in the
-- theme's accent, a little taller than the bar; brighter on hover. Its place, size and tooltip stay Blizzard's.
local function TickLine(texture, alpha)
  if not S.IsRegion(texture) then
    return
  end
  local accent = S.Theme().accent
  texture:SetTexture(FLAT)
  texture:ClearAllPoints()
  texture:SetPoint("TOP", texture:GetParent(), "TOP", 0, 0)
  texture:SetPoint("BOTTOM", texture:GetParent(), "BOTTOM", 0, 0)
  texture:SetWidth(2)
  texture:SetVertexColor(accent[1], accent[2], accent[3], alpha)
end

local function RestedTick(tick)
  if not S.Usable(tick) then
    return
  end
  local normal = S.Region(tick, "Normal") or Ask(tick, "GetNormalTexture")
  local highlight = S.Region(tick, "Highlight") or Ask(tick, "GetHighlightTexture")
  TickLine(normal, 0.9)
  TickLine(highlight, 1)
  if S.Once(tick, "tickLine") then
    -- Blizzard sets the pip again (atlas) when it updates the marker
    for _, region in ipairs({ normal, highlight }) do
      if S.IsRegion(region) then
        S.HookMethod(region, "SetAtlas", function(texture)
          TickLine(texture, texture == highlight and 1 or 0.9)
        end)
      end
    end
  end
end

-- Our own text on the experience / reputation bar, always shown: "XP: 132,159 / 135,100 (97.8%) · 12% rested",
-- or "Faction: 4,200 / 12,000 (35.0%)". Blizzard's own text (shown on hover) gets alpha 0 while ours shows.
local barText = setmetatable({}, { __mode = "k" }) -- [status bar] = { text = our font string, bar = bar frame }

local function Num(value)
  return type(value) == "number" and Plain(value) and value or nil
end

local function Big(n)
  n = math.floor(n + 0.5)
  if BreakUpLargeNumbers then
    return BreakUpLargeNumbers(n)
  end
  return tostring(n)
end

local function XPText()
  local cur, max = Num(UnitXP and UnitXP("player")), Num(UnitXPMax and UnitXPMax("player"))
  if not cur or not max or max <= 0 then
    return nil
  end
  local text = ("XP: %s / %s (%.1f%%)"):format(Big(cur), Big(max), cur / max * 100)
  local rested = Num(GetXPExhaustion and GetXPExhaustion())
  if rested and rested > 0 then
    text = text .. (" \194\183 %d%% rested"):format(math.floor(rested / max * 100 + 0.5))
  end
  return text
end

local function RepText()
  local name, low, high, value
  if C_Reputation and C_Reputation.GetWatchedFactionData then
    local ok, data = pcall(C_Reputation.GetWatchedFactionData)
    if ok and type(data) == "table" then
      name, low, high, value = data.name, data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
    end
  end
  low, high, value = Num(low), Num(high), Num(value)
  if type(name) ~= "string" or (canaccessvalue and not canaccessvalue(name)) or not low or not high or not value then
    return nil
  end
  local cur, max = value - low, high - low
  if max <= 0 then
    return name
  end
  return ("%s: %s / %s (%.1f%%)"):format(name, Big(cur), Big(max), cur / max * 100)
end

function ShowText(status)
  local entry = barText[status]
  if not entry then
    return
  end
  local kind = kindOf[status]
  local text = kind == "xp" and XPText() or kind == "rep" and RepText() or nil
  entry.text:SetText(text or "")
  entry.text:SetShown(text ~= nil)
  -- Blizzard's hover text only while ours is off
  local theirs = S.Region(S.Child(entry.bar, "OverlayFrame"), "Text")
  if theirs then
    theirs:SetAlpha(text and 0 or 1)
  end
end

local function ShowTexts()
  for status in pairs(barText) do
    ShowText(status)
  end
end

local function BarText(bar, status)
  if barText[status] then
    return
  end
  local holder = CreateFrame("Frame", nil, bar)
  holder:SetAllPoints(status)
  local level = Ask(bar, "GetFrameLevel")
  if Num(level) then
    holder:SetFrameLevel(level + 10)
  end
  local text = holder:CreateFontString(nil, "OVERLAY")
  text:SetPoint("CENTER", holder, "CENTER", 0, 0)
  Clean(text, 10, XP_TEXT)
  barText[status] = { text = text, bar = bar }
  if S.Once(barText, "events") then
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
      "PLAYER_ENTERING_WORLD" }) do
      pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function()
      S.Run(part, ShowTexts)
    end)
  end
end

-- Calls fn(frame) for `frame` and every frame below it (the segment ticks sit on frames of their own,
-- some made later by Blizzard).
local function Descend(frame, fn, depth)
  if not S.Usable(frame) then
    return
  end
  fn(frame)
  if (depth or 0) >= 6 or not frame.GetChildren then
    return
  end
  local ok, children = pcall(function()
    return { frame:GetChildren() }
  end)
  for _, child in ipairs(ok and children or {}) do
    Descend(child, fn, (depth or 0) + 1)
  end
end

local function Textures(frame)
  local list = {}
  if frame.GetRegions then
    for _, region in ipairs({ frame:GetRegions() }) do
      if S.IsRegion(region) and region:GetObjectType() == "Texture" then
        list[#list + 1] = region
      end
    end
  end
  return list
end

-- Every texture of the bar and of every frame below it (track, ticks, frame), except the fill, the rested
-- part, the rested-level marker and ours. Texts are font strings and stay.
local trackKeep = setmetatable({}, { __mode = "k" }) -- Blizzard textures and frames of the bars that stay

local function KillBelow(frame)
  Descend(frame, function(child)
    if trackKeep[child] then
      return
    end
    for _, texture in ipairs(Textures(child)) do
      if not trackKeep[texture] and not trackOurs[texture] then
        S.Kill(texture)
      end
    end
  end)
end

local function BarArt(bar)
  local status = S.Child(bar, "StatusBar")
  local keep = { Ask(status, "GetStatusBarTexture"), S.Child(status, "ExhaustionLevelFillBar"),
    S.Child(bar, "ExhaustionLevelFillBar"), S.Child(bar, "ExhaustionTick"), S.Child(status, "ExhaustionTick") }
  for index = 1, 5 do
    if keep[index] then
      trackKeep[keep[index]] = true
    end
  end
  KillBelow(bar)
end

-- Blizzard's names for laying out the ticks (whichever exist are followed).
local TICK_UPDATES = { "UpdateTicks", "SetupTicks", "UpdateBarTicks", "LayoutTicks", "Update", "UpdateAll" }

-- For a /codex debug command: every texture below the experience / reputation bars.
TylesserCodex.BarTicksDebug = function()
  local function KeyOf(frame, region)
    for key, value in pairs(frame) do
      if value == region and type(key) == "string" then
        return key
      end
    end
    return "?"
  end
  local list = {}
  for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
    Descend(S.Get(name), function(frame)
      local owner = S.Name(frame) or (Ask(frame, "GetParent") and KeyOf(Ask(frame, "GetParent"), frame)) or "?"
      for _, texture in ipairs(Textures(frame)) do
        local info = { container = name, frame = owner, key = KeyOf(frame, texture),
          atlas = Ask(texture, "GetAtlas"), file = Ask(texture, "GetTexture"), alpha = Ask(texture, "GetAlpha"),
          shown = Ask(texture, "IsShown"), ours = trackOurs[texture] or false }
        for key, value in pairs(info) do
          if canaccessvalue and not canaccessvalue(value) then
            info[key] = "secret"
          end
        end
        list[#list + 1] = info
      end
    end)
  end
  return list
end

local function TrackingBar(bar)
  local status = S.Child(bar, "StatusBar")
  if not S.Usable(status) or not S.Once(status, "track") then
    return
  end
  BarArt(bar)
  -- design: a dark track ("barBg", the slot fill at 85%), 1 px black round the bar, then 1 px of the theme's
  -- divider colour
  local look = S.Look("slot")
  local plate = S.Plate(status, { fill = look.fill, alpha = (look.fill[4] or 1) * TRACK_ALPHA,
    rings = { { inset = 0, color = S.Theme().divider, size = 1 }, { inset = 1, color = { 0, 0, 0, 1 }, size = 1 } } },
    { pad = 2, ringLayer = "OVERLAY" })
  trackOurs[plate.fill] = true
  for _, line in ipairs(plate.lines) do
    trackOurs[line] = true
  end
  local rested = S.Child(status, "ExhaustionLevelFillBar") or S.Child(bar, "ExhaustionLevelFillBar")
  -- a rounded theme: fill, rested part and track cut round, no rings (the boards: a dark see-through track)
  local mask = S.RoundBar(status, { plate.fill, S.IsRegion(rested) and rested or nil })
  if mask then
    for _, line in ipairs(plate.lines) do
      line:SetAlpha(0)
    end
  end
  BarText(bar, status)
  FlatFill(status)
  RestedTick(S.Child(bar, "ExhaustionTick") or S.Child(status, "ExhaustionTick"))
  Exhaustion(rested)
  S.HookMethod(rested, "SetAtlas", Exhaustion)
  S.HookMethod(rested, "SetTexture", function(texture, file)
    -- ours sets WHITE8X8 (no loop): only Blizzard's pictures are swapped
    if file ~= FLAT then
      Exhaustion(texture)
    end
  end)
  -- Blizzard sets the picture and colour again on each update (rested on / off, another faction)
  S.HookMethod(status, "SetStatusBarTexture", FlatFill)
  S.HookMethod(status, "SetStatusBarColor", HoldColor)
  local texture = Ask(status, "GetStatusBarTexture")
  if S.IsRegion(texture) then
    S.HookMethod(texture, "SetAtlas", function(_, atlas)
      FlatFill(status, atlas)
    end)
  end
  local function Again()
    BarArt(bar)
    HoldColor(status)
    RestedTick(S.Child(bar, "ExhaustionTick") or S.Child(status, "ExhaustionTick"))
    ShowText(status)
  end
  -- ticks laid out (again) by Blizzard, on the bar or a tick frame of its own
  for _, holder in ipairs({ bar, status, S.Child(bar, "Ticks"), S.Child(bar, "TickContainer"),
    S.Child(status, "Ticks") }) do
    for _, method in ipairs(TICK_UPDATES) do
      S.HookMethod(holder, method, Again)
    end
  end
  S.HookScript(bar, "OnShow", Again)
  -- Blizzard shows its own text on hover: kept out of sight while ours shows
  S.HookScript(bar, "OnEnter", function()
    ShowText(status)
  end)
  -- the bar's text (shown on hover): white Arial with a shadow
  Clean(S.Region(S.Child(bar, "OverlayFrame"), "Text"), 11, WHITE)
end

local TrackingBars
function TrackingBars()
  for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
    local container = S.Get(name)
    if S.Usable(container) then
      for _, bar in pairs(S.Child(container, "bars") or {}) do
        if S.Usable(bar) then
          TrackingBar(bar)
        end
      end
      -- everything else below the container too (its frame, tick frames of its own)
      KillBelow(container)
      if S.Once(container, "tickHooks") then
        for _, method in ipairs(TICK_UPDATES) do
          S.HookMethod(container, method, TrackingBars)
        end
      end
    end
  end
end

local function BagDividers()
  local bar = S.Get("BagsBar")
  for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
    local pool = S.Child(bar, key)
    if pool and type(pool.EnumerateActive) == "function" then
      local ok, iterator, state, first = pcall(pool.EnumerateActive, pool)
      if ok and type(iterator) == "function" then
        for divider in iterator, state, first do
          S.Kill(divider)
        end
      end
    end
  end
end

-- Micro menu: the brown strip behind the menu and the bags (any texture of the menu's and the bag bar's own
-- frames) goes. Each micro button's picture is its own normal texture (no separate icon) and carries a dark
-- square with a bronze edge: the backplate textures (Background / PushedBackground, where they exist) get
-- alpha 0, and the pictures (normal, pushed, disabled, highlight) are cropped to their middle so the baked-in
-- edge is cut off, again after Blizzard sets them. Then the same slot box as the action buttons goes round each
-- picture. The highlight, the "new" flash and the alert glow stay Blizzard's.
-- Share of the picture cut from each side. Off (0): on Forever the crop showed fragments of the atlas sheet
-- instead of the button picture (in game, 2026-11-17); to be tuned from /codex debug micro.
local MICRO_CROP = 0
local MICRO_NAMES = { "CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton",
  "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton",
  "SocialsMicroButton", "LFDMicroButton", "LFGMicroButton", "PVPMicroButton", "CollectionsMicroButton",
  "EJMicroButton", "WorldMapMicroButton", "StoreMicroButton", "HousingMicroButton", "MainMenuMicroButton",
  "HelpMicroButton" }
local STRIP_FRAMES = { "MicroMenuContainer", "MicroMenu", "MicroButtonAndBagsBar", "BagsBar" }
local micro = {} -- S.Once key for the menu-wide hooks

local function Pictures(button)
  local list = {}
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
    local texture = Ask(button, getter)
    if S.IsRegion(texture) then
      list[#list + 1] = texture
    end
  end
  return list
end

-- The picture's middle, worked out from the atlas's own coordinates each time, so cropping again never cuts more.
local function Crop(texture)
  if MICRO_CROP <= 0 or not S.IsRegion(texture) or not texture.SetTexCoord then
    return
  end
  local left, right, top, bottom = 0, 1, 0, 1
  local atlas = Ask(texture, "GetAtlas")
  if type(atlas) == "string" and C_Texture and C_Texture.GetAtlasInfo then
    local info = C_Texture.GetAtlasInfo(atlas)
    if type(info) == "table" and info.leftTexCoord then
      left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    end
  end
  local dx, dy = (right - left) * MICRO_CROP, (bottom - top) * MICRO_CROP
  texture:SetTexCoord(left + dx, right - dx, top + dy, bottom - dy)
end

local function MicroArt(button)
  S.KillKeys(button, "Background", "PushedBackground")
  for _, texture in ipairs(Pictures(button)) do
    Crop(texture)
  end
end

local function MicroButton(button)
  if not S.Usable(button) or not S.Once(button, "micro") then
    return
  end
  -- design: each micro button is the theme's button (its gradient and a 1 px line), not a slot
  local picture = Ask(button, "GetNormalTexture")
  local box = S.IsRegion(picture) and picture or button
  local style = S.Theme().button
  local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints(box)
  S.UI.Gradient(fill, style.from, style.to)
  S.Outline(button, box, 0, 1, style.line, "OVERLAY", 1)
  MicroArt(button)
  -- Blizzard swaps the pictures and backplates when a button is pressed, its window opens or it is disabled
  for _, method in ipairs({ "SetPushed", "SetNormal", "UpdateMicroButton", "SetNormalAtlas", "SetPushedAtlas",
    "SetDisabledAtlas", "SetHighlightAtlas", "SetNormalTexture", "SetPushedTexture" }) do
    S.HookMethod(button, method, MicroArt)
  end
  for _, texture in ipairs(Pictures(button)) do
    S.HookMethod(texture, "SetAtlas", Crop)
  end
end

function MicroList()
  local list, seen = {}, {}
  local function Add(button)
    if S.Usable(button) and not seen[button] then
      seen[button] = true
      list[#list + 1] = button
    end
  end
  for _, name in ipairs(type(MICRO_BUTTONS) == "table" and MICRO_BUTTONS or {}) do
    Add(S.Get(name))
  end
  for _, name in ipairs(MICRO_NAMES) do
    Add(S.Get(name))
  end
  -- anything else in the menu that is a button with a picture
  local menu = S.Get("MicroMenu")
  if S.Usable(menu) and menu.GetChildren then
    for _, child in ipairs({ menu:GetChildren() }) do
      if S.Usable(child) and child:GetObjectType() == "Button" and S.IsRegion(Ask(child, "GetNormalTexture")) then
        Add(child)
      end
    end
  end
  return list
end

local function MicroButtons()
  for _, button in ipairs(MicroList()) do
    MicroButton(button)
    MicroArt(button)
  end
end

-- The strip behind the menu and the bags: every texture of those frames themselves (their buttons are frames
-- of their own and keep theirs), and their border frames.
local function Strip()
  for _, name in ipairs(STRIP_FRAMES) do
    local frame = S.Get(name)
    if S.Usable(frame) and frame.GetRegions then
      for _, region in ipairs({ frame:GetRegions() }) do
        if S.IsRegion(region) and region:GetObjectType() == "Texture" then
          S.Kill(region)
        end
      end
      S.KillKeys(frame, "BorderArt", "BackgroundArt", "MicroBagBar")
    end
  end
end

-- For a /codex debug command: what the micro menu and the strip are made of.
-- Leave buttons: "Request Stop" on a flight path and leaving a vehicle (MainMenuBarVehicleLeaveButton, its
-- own Edit Mode system), and the vehicle bar's own leave button. The picture (normal / pushed / highlight /
-- disabled textures) stays; every other texture of the button, its border / background frames and the
-- textures of a holder frame that holds only this button get alpha 0, and the slot box goes round the
-- picture. The button is never shown, hidden or moved; the look is set again after Blizzard updates it.
local LEAVE_BUTTONS = { "MainMenuBarVehicleLeaveButton", "OverrideActionBar.LeaveButton" }

local function LeaveArt(button)
  if not S.Usable(button) then
    return
  end
  local keep = {}
  for _, texture in ipairs(Pictures(button)) do
    keep[texture] = true
  end
  if button.GetRegions then
    for _, region in ipairs({ button:GetRegions() }) do
      if S.IsRegion(region) and region:GetObjectType() == "Texture" and not keep[region] and not trackOurs[region] then
        S.Kill(region)
      end
    end
  end
  S.KillKeys(button, "Border", "Background", "Frame", "NineSlice", "BorderArt")
  -- a holder frame of this button alone (not a bar, not UIParent): its art goes too
  local holder = Ask(button, "GetParent")
  if S.Usable(holder) and holder ~= UIParent and not panels[holder] and holder.GetRegions
    and Ask(holder, "GetNumChildren") == 1 then
    for _, region in ipairs({ holder:GetRegions() }) do
      if S.IsRegion(region) and region:GetObjectType() == "Texture" then
        S.Kill(region)
      end
    end
  end
end

local function LeaveButton(button)
  if not S.Usable(button) or not S.Once(button, "leave") then
    return
  end
  local picture = Ask(button, "GetNormalTexture")
  local before = {}
  for _, region in ipairs(button.GetRegions and { button:GetRegions() } or {}) do
    before[region] = true
  end
  SlotBox(button, S.IsRegion(picture) and picture or button, "full")
  -- our box's textures are kept out of LeaveArt
  for _, region in ipairs(button.GetRegions and { button:GetRegions() } or {}) do
    if not before[region] then
      trackOurs[region] = true
    end
  end
  LeaveArt(button)
  for _, method in ipairs({ "Update", "UpdateShownState", "SetNormalTexture", "SetNormalAtlas", "SetPushedTexture",
    "SetPushedAtlas" }) do
    S.HookMethod(button, method, LeaveArt)
  end
  S.HookScript(button, "OnShow", LeaveArt)
end

local function LeaveButtons()
  for _, path in ipairs(LEAVE_BUTTONS) do
    LeaveButton(S.Get(path))
    LeaveArt(S.Get(path))
  end
end

TylesserCodex.MicroDebug = function()
  local function Art(texture)
    local atlas, file = Ask(texture, "GetAtlas"), Ask(texture, "GetTexture")
    return tostring(atlas or file) .. " alpha " .. tostring(Ask(texture, "GetAlpha"))
  end
  local list = {}
  for _, name in ipairs(STRIP_FRAMES) do
    local frame = S.Get(name)
    local info = { name = name, exists = frame ~= nil, regions = {} }
    if S.Usable(frame) and frame.GetRegions then
      for _, region in ipairs({ frame:GetRegions() }) do
        if S.IsRegion(region) then
          info.regions[#info.regions + 1] = Art(region)
        end
      end
    end
    list[#list + 1] = info
  end
  for _, button in ipairs(MicroList()) do
    local info = { name = S.Name(button) or "unnamed", styled = S.Done(button, "micro"), regions = {} }
    info.width, info.height = Ask(button, "GetWidth"), Ask(button, "GetHeight")
    for _, key in ipairs({ "Background", "PushedBackground", "FlashBorder", "FlashContent", "Portrait" }) do
      local region = S.Region(button, key)
      if region then
        info.regions[#info.regions + 1] = key .. ": " .. Art(region)
      end
    end
    local picture = Ask(button, "GetNormalTexture")
    if S.IsRegion(picture) then
      info.regions[#info.regions + 1] = "normal: " .. Art(picture)
    end
    list[#list + 1] = info
  end
  for _, path in ipairs(LEAVE_BUTTONS) do
    local button = S.Get(path)
    local info = { name = path, exists = button ~= nil, styled = button and S.Done(button, "leave"), regions = {} }
    if S.Usable(button) then
      local holder = Ask(button, "GetParent")
      info.holder = holder and (S.Name(holder) or "unnamed frame")
      info.holderChildren = holder and Ask(holder, "GetNumChildren")
      info.width, info.height = Ask(button, "GetWidth"), Ask(button, "GetHeight")
      local picture = Ask(button, "GetNormalTexture")
      for _, region in ipairs(button.GetRegions and { button:GetRegions() } or {}) do
        if S.IsRegion(region) and region:GetObjectType() == "Texture" and not trackOurs[region] then
          info.regions[#info.regions + 1] = (region == picture and "normal: " or "") .. Art(region)
        end
      end
    end
    list[#list + 1] = info
  end
  for _, info in ipairs(list) do
    for key, value in pairs(info) do
      if canaccessvalue and not canaccessvalue(value) then
        info[key] = "secret"
      end
    end
  end
  return list
end

local function BagsAndMenu()
  for _, name in ipairs(BAG_SLOTS) do
    local button = S.Get(name)
    -- the keyring's picture may be its normal texture: only buttons with an icon of their own. The same box
    -- as the action buttons, round the icon.
    if S.Usable(button) and S.IconOf(button) and ActionSlot(button, "bag") then
      S.HookMethod(button, "UpdateTextures", ButtonArt)
    end
  end
  Strip()
  MicroButtons()
  if S.Once(micro, "hooks") then
    S.HookGlobal("UpdateMicroButtons", MicroButtons)
    for _, name in ipairs(STRIP_FRAMES) do
      S.HookMethod(S.Get(name), "Layout", Strip)
    end
  end
  local bags = S.Get("BagsBar")
  BagDividers()
  if S.Usable(bags) and S.Once(bags, "dividers") then
    S.HookMethod(bags, "UpdateDividers", BagDividers)
    S.HookMethod(bags, "Layout", BagDividers)
  end
end

S.Part("actionbars", function()
  SkinButtons()
  SkinOverrideBar()
  S.OnAddOn("Blizzard_OverrideActionBar", SkinOverrideBar)

  -- Blizzard's bar art and the gryphons go in any case
  for _, name in ipairs(BARS) do
    local bar = S.Get(name)
    if S.Usable(bar) then
      S.KillKeys(bar, "BorderArt", "Background", "BackgroundArt")
    end
  end
  EndCaps()
  S.HookMethod(S.Get("MainActionBar"), "UpdateEndCaps", EndCaps)
  -- the panel behind the bars is its own setting (off by default)
  if TylesserCodex.SkinPartOn("barpanels") then
    for _, name in ipairs(BARS) do
      Panel(S.Get(name), name)
    end
    for _, name in ipairs(PANEL_EXTRAS) do
      Panel(S.Get(name), name)
    end
    FitAll()
    if S.Once(panels, "watch") then
      WatchFit()
    end
  end

  -- filled / empty slots after Blizzard's own updates
  if S.Once(slotParts, "events") then
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
      "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PET_BAR_UPDATE",
      "UPDATE_SHAPESHIFT_FORMS", "UPDATE_POSSESS_BAR", "UPDATE_MULTI_CAST_ACTIONBAR" }) do
      pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", SlotStatesSoon)
  end

  TrackingBars()
  S.HookMethod(S.Get("StatusTrackingBarManager"), "UpdateBarsShown", TrackingBars)
  BagsAndMenu()
  LeaveButtons()
  if S.Once(LEAVE_BUTTONS, "hooks") then
    S.HookGlobal("MainMenuBarVehicleLeaveButton_Update", LeaveButtons)
    -- the vehicle bar comes with its own addon on some clients
    S.OnAddOn("Blizzard_OverrideActionBar", LeaveButtons)
  end
end)
