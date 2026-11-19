local addonName, ns = ...
local R = ns.rings
local UI = ns.UI

-- What the player sees of a ring: plain (insecure) frames over the secure ring frame, so they may change in
-- combat. Round slice icons with Buff Tracker's double-line ring, round cooldown swipes, item / reagent counts,
-- red (out of range) and blue (not enough mana) tints, the slice you point at enlarged. Two looks (R.DB().style):
-- "ping" (default, the user's choice 2026-11-19): Blizzard's ping wheel (Blizzard_RadialWheel, Forever's atlases
-- Radial_Wheel_BG / _Select_Pointer / _Select_Close / _Icon_Close, and for exactly 4 slices _Frame_Count_4 and
-- _Select_Wedge_Count_4; Forever has no other counts, so other rings get thin divider lines and our own wedge art
-- Media/Wedge<N>.tga in the same gold), each slice's name beside its icon, the close mark in the hub; "codex": a
-- soft disc in the theme's panel colour, the slice's name in the hub and a line from the hub towards it. Opens with
-- a short scale-and-fade.

local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local RING = "Interface\\AddOns\\Codex\\Modules\\Buffs\\Media\\Ring"
R.CIRCLE, R.RING_ART = CIRCLE, RING
local HOVER = 1.22 -- size of the slice you point at
local UPDATE = 0.2 -- seconds between range / usable checks while a ring is open
local COOLDOWN_EVENTS = { "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "BAG_UPDATE",
  "PLAYER_TARGET_CHANGED" }

-- The rings open over the game world: the theme's ink surfaces (the light-theme rule, Theme.lua).
local function Theme()
  return ns.InkTheme and ns.InkTheme() or ns.Theme()
end

local function Shade(color)
  return (color[1] + color[2] + color[3]) < 0.3
end

-- The theme's main slot ring colour (as Buff Tracker's round icons use).
function R.RingColor()
  for _, ring in ipairs(Theme().slot and Theme().slot.rings or {}) do
    if not Shade(ring.color) then
      return ring.color
    end
  end
  return Theme().accent
end

local function Color(texture, color, alpha)
  texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- A round icon on `frame` (made by the caller): art cut round, the ring over it, a glow under it, a count.
-- withCooldown adds a round cooldown swipe.
function R.DressIcon(frame, withCooldown)
  frame.glow = frame:CreateTexture(nil, "BACKGROUND")
  frame.glow:SetTexture(CIRCLE)
  frame.glow:SetPoint("TOPLEFT", -6, 6)
  frame.glow:SetPoint("BOTTOMRIGHT", 6, -6)
  Color(frame.glow, Theme().accent, 0.35)
  frame.glow:Hide()
  frame.back = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  frame.back:SetTexture(CIRCLE)
  frame.back:SetAllPoints()
  frame.back:SetVertexColor(0, 0, 0, 0.9)
  frame.art = frame:CreateTexture(nil, "ARTWORK")
  frame.art:SetPoint("TOPLEFT", 2, -2)
  frame.art:SetPoint("BOTTOMRIGHT", -2, 2)
  frame.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if frame.CreateMaskTexture then
    local mask = frame:CreateMaskTexture()
    if mask then
      mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(frame.art)
      frame.art:AddMaskTexture(mask)
      frame.mask = mask
    end
  end
  if withCooldown then
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame.art)
    R.Call(cooldown.SetSwipeTexture, cooldown, CIRCLE)
    R.Call(cooldown.SetUseCircularEdge, cooldown, true)
    R.Call(cooldown.SetDrawEdge, cooldown, false)
    R.Call(cooldown.SetDrawBling, cooldown, false)
    R.Call(cooldown.SetSwipeColor, cooldown, 0, 0, 0, 0.7)
    frame.cooldown = cooldown
  end
  -- ring and count above the swipe (a child frame draws over its parent's regions)
  local top = CreateFrame("Frame", nil, frame)
  top:SetAllPoints()
  top:SetFrameLevel(frame:GetFrameLevel() + 3)
  frame.ring = top:CreateTexture(nil, "OVERLAY")
  frame.ring:SetTexture(RING)
  frame.ring:SetAllPoints(frame)
  Color(frame.ring, R.RingColor())
  frame.count = UI.Text(top, "body", 11, "bright")
  frame.count:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 3)
  frame.count:SetJustifyH("RIGHT")
  frame.top = top
  return frame
end

-- Hovered / normal ring colour.
function R.SetIconHot(icon, hot)
  Color(icon.ring, hot and Theme().accent or R.RingColor())
  icon.glow:SetShown(hot and true or false)
end

function R.CreateDisplay(entry)
  local display = UI.Ink(CreateFrame("Frame", nil, entry.ring))
  display:SetPoint("CENTER")
  display:SetSize(10, 10)
  display:SetFrameLevel(entry.ring:GetFrameLevel() + 2)
  local panel = Theme().panel
  display.back = display:CreateTexture(nil, "BACKGROUND")
  display.back:SetTexture(CIRCLE)
  display.back:SetPoint("CENTER")
  Color(display.back, panel.from, 0.62)
  display.edge = display:CreateTexture(nil, "BORDER")
  display.edge:SetTexture(RING)
  display.edge:SetAllPoints(display.back)
  Color(display.edge, R.RingColor(), 0.35)
  display.hub = display:CreateTexture(nil, "BORDER", nil, 1)
  display.hub:SetTexture(CIRCLE)
  display.hub:SetPoint("CENTER")
  Color(display.hub, panel.to, 0.85)
  display.hubEdge = display:CreateTexture(nil, "ARTWORK")
  display.hubEdge:SetTexture(RING)
  display.hubEdge:SetAllPoints(display.hub)
  Color(display.hubEdge, Theme().accent, 0.5)
  if display.CreateLine then
    display.pointer = display:CreateLine(nil, "ARTWORK", nil, 1)
    if display.pointer then
      display.pointer:SetThickness(2)
      display.pointer:SetColorTexture(UI.Unpack(Theme().accent, 0.8))
      display.pointer:Hide()
    end
  end
  display.tip = display:CreateTexture(nil, "OVERLAY")
  display.tip:SetTexture(CIRCLE)
  display.tip:SetSize(9, 9)
  Color(display.tip, Theme().accent)
  display.tip:Hide()
  -- the name sits on its own frame above the icons
  display.top = CreateFrame("Frame", nil, display)
  display.top:SetAllPoints()
  display.top:SetFrameLevel(display:GetFrameLevel() + 10)
  display.name = UI.Text(display.top, "body", 13, "bright")
  display.name:SetPoint("CENTER", display, "CENTER", 0, 0)
  display.name:SetJustifyH("CENTER")
  if display.name.SetWordWrap then
    display.name:SetWordWrap(true)
  end
  display.icons = {}
  R.CreatePing(display)

  if display.CreateAnimationGroup then
    local group = display:CreateAnimationGroup()
    if group then
      local scale = group:CreateAnimation("Scale")
      if scale then
        if scale.SetScaleFrom then
          scale:SetScaleFrom(0.85, 0.85)
          scale:SetScaleTo(1, 1)
        elseif scale.SetFromScale then
          scale:SetFromScale(0.85, 0.85)
          scale:SetToScale(1, 1)
        end
        scale:SetDuration(0.12)
        R.Call(scale.SetSmoothing, scale, "OUT")
      end
      local fade = group:CreateAnimation("Alpha")
      if fade then
        R.Call(fade.SetFromAlpha, fade, 0)
        R.Call(fade.SetToAlpha, fade, 1)
        fade:SetDuration(0.1)
      end
      display.open = group
    end
  end

  display:SetScript("OnShow", function()
    R.Opened(entry)
  end)
  display:SetScript("OnHide", function(self)
    self:UnregisterAllEvents()
    entry.hover = nil
  end)
  display:SetScript("OnEvent", function()
    R.UpdateIcons(entry)
  end)
  display:SetScript("OnUpdate", function(_, elapsed)
    R.Track(entry, elapsed)
  end)
  entry.display = display
  return display
end


-- Blizzard's ping wheel look -----------------------------------------------------------------------------------

local PING_SPACING = 80 -- Blizzard's slices sit 80 px from the centre; the atlases are scaled to our radius
local PING_WEDGE_OUT = 20 -- and its 4-slice wedge 20 px out along the slice
local WEDGE_ART = "Interface\\AddOns\\Codex\\Modules\\Rings\\Media\\Wedge%d"
local GOLD = { 1, 0.82, 0.2 }
local LINE = { 0.85, 0.85, 0.85, 0.22 }

function R.PingStyle()
  return R.DB().style ~= "codex"
end

-- Sets an atlas at `scale` of its own size (fallback: a square of `fallback` px). Returns the size.
local function Atlas(texture, atlas, scale, fallback)
  local width, height = fallback, fallback
  local info = C_Texture and C_Texture.GetAtlasInfo and R.Call(C_Texture.GetAtlasInfo, atlas)
  if type(info) == "table" and type(info.width) == "number" and info.width > 0 then
    width, height = info.width, info.height
  end
  if not pcall(texture.SetAtlas, texture, atlas) then
    texture:SetTexture(CIRCLE)
  end
  texture:SetSize(width * scale, height * scale)
  return width * scale, height * scale
end

function R.CreatePing(display)
  local ping = {}
  ping.bg = display:CreateTexture(nil, "BACKGROUND", nil, 2)
  ping.bg:SetPoint("CENTER")
  ping.frame = display:CreateTexture(nil, "BORDER", nil, 2)
  ping.frame:SetPoint("CENTER")
  ping.wedge = display:CreateTexture(nil, "ARTWORK", nil, 2)
  ping.wedge:SetPoint("CENTER")
  ping.pointer = display:CreateTexture(nil, "OVERLAY", nil, 2)
  ping.pointer:SetPoint("CENTER")
  ping.closeSelected = display.top:CreateTexture(nil, "ARTWORK")
  ping.closeSelected:SetPoint("CENTER")
  ping.close = display.top:CreateTexture(nil, "OVERLAY")
  ping.close:SetPoint("CENTER")
  ping.lines = {}
  display.ping = ping
end

local PING_PARTS = { "bg", "frame", "wedge", "pointer", "closeSelected", "close" }
local CODEX_PARTS = { "back", "edge", "hub", "hubEdge", "tip" }

-- The slice's angle (radians, counter-clockwise from +x, 0..2pi): slice 1 at the top, then clockwise.
function R.SliceAngle(index, count)
  return math.rad(90 - (index - 1) * 360 / count) % (2 * math.pi)
end

-- A slice's name outside its icon, on the side facing away from the centre (Blizzard's quadrant rule).
local function PlaceLabel(icon, angle)
  local label = icon.label
  label:ClearAllPoints()
  local quarter = 0.25 * math.pi
  if angle > quarter and angle <= math.pi - quarter then
    label:SetPoint("BOTTOM", icon, "TOP", 0, 6)
  elseif angle > math.pi - quarter and angle <= math.pi + quarter then
    label:SetPoint("RIGHT", icon, "LEFT", -6, 0)
  elseif angle > math.pi + quarter and angle <= 2 * math.pi - quarter then
    label:SetPoint("TOP", icon, "BOTTOM", 0, -6)
  else
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  end
end

-- Lays the ping parts out for `count` slices at `radius` (or hides them in the Codex look).
function R.LayoutPing(display, count, radius)
  local ping = display.ping
  local on = R.PingStyle()
  for _, key in ipairs(PING_PARTS) do
    ping[key]:SetShown(on)
  end
  for _, key in ipairs(CODEX_PARTS) do
    if display[key] then
      display[key]:SetShown(not on and key ~= "tip")
    end
  end
  if display.pointer and on then
    display.pointer:Hide()
  end
  display.name:SetShown(not on)
  for _, line in ipairs(ping.lines) do
    line:Hide()
  end
  if not on then
    return
  end
  local scale = radius / PING_SPACING
  ping.scale = scale
  local wheel = Atlas(ping.bg, "Radial_Wheel_BG", scale, 290)
  ping.radius = wheel * 0.5
  Atlas(ping.pointer, "Radial_Wheel_Select_Pointer", scale, 120)
  ping.pointer:Hide()
  Atlas(ping.closeSelected, "Radial_Wheel_Select_Close", scale, 48)
  local closeSize = Atlas(ping.close, "Radial_Wheel_Icon_Close", scale, 28)
  ping.hubRadius = math.max(closeSize, 24 * scale) * 0.75
  ping.count = count
  if count == 4 then
    -- Blizzard's own frame and wedge (slices on the axes, the dividers on the diagonals)
    Atlas(ping.frame, "Radial_Wheel_Frame_Count_4", scale, 290)
    ping.frame:Show()
    local width, height = Atlas(ping.wedge, "Radial_Wheel_Select_Wedge_Count_4", scale, 160)
    ping.wedgeSize = { width, height }
    ping.ownWedge = false
  else
    ping.frame:Hide()
    ping.ownWedge = count >= 2
    if ping.ownWedge then
      ping.wedge:SetTexture(WEDGE_ART:format(math.min(count, R.MAX_SLICES)))
      ping.wedge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
      ping.wedge:SetSize(wheel, wheel)
      ping.wedge:ClearAllPoints()
      ping.wedge:SetPoint("CENTER")
    end
    -- thin lines between the slices, from the hub to the wheel's edge
    if count >= 2 and display.CreateLine then
      local step = 2 * math.pi / count
      for index = 1, count do
        local line = ping.lines[index]
        if not line then
          line = display:CreateLine(nil, "BORDER", nil, 3)
          ping.lines[index] = line
        end
        if line then
          local angle = R.SliceAngle(index, count) + step * 0.5
          local ux, uy = math.cos(angle), math.sin(angle)
          local from, to = ping.hubRadius + 4, ping.radius * 0.92
          line:SetThickness(1.5)
          line:SetColorTexture(LINE[1], LINE[2], LINE[3], LINE[4])
          line:SetStartPoint("CENTER", display, ux * from, uy * from)
          line:SetEndPoint("CENTER", display, ux * to, uy * to)
          line:Show()
        end
      end
    end
  end
  ping.wedge:Hide()
  ping.closeSelected:Show()
end

-- The ping look's part of the hover: the wedge on the slice, its name bright, the others' plain.
function R.PingHover(display, index)
  local ping = display.ping
  if not R.PingStyle() then
    return
  end
  local theme = Theme()
  for _, icon in ipairs(display.icons) do
    if icon.label then
      icon.label:SetTextColor(UI.Unpack(icon == display.icons[index] and theme.bright or theme.text))
    end
  end
  if not index or not ping.count or ping.count < 1 then
    ping.wedge:Hide()
    ping.closeSelected:Show()
    return
  end
  ping.closeSelected:Hide()
  local angle = R.SliceAngle(index, ping.count)
  if ping.count == 4 then
    local out = PING_WEDGE_OUT * (ping.scale or 1)
    ping.wedge:ClearAllPoints()
    ping.wedge:SetPoint("CENTER", display, "CENTER", math.cos(angle) * out, math.sin(angle) * out)
  end
  if ping.count == 4 or ping.ownWedge then
    ping.wedge:SetRotation(angle)
    ping.wedge:Show()
  end
end

-- The pointer follows the cursor (Blizzard's wheel turns it to the cursor's angle); hidden in the hub.
function R.PingPointer(display, dx, dy, inHub)
  local ping = display.ping
  if not R.PingStyle() then
    return
  end
  if inHub then
    ping.pointer:Hide()
    return
  end
  ping.pointer:SetRotation((math.atan2 or math.atan)(dy, dx))
  ping.pointer:Show()
end

local function Icon(entry, index)
  local display = entry.display
  local icon = display.icons[index]
  if not icon then
    icon = CreateFrame("Frame", nil, display)
    icon:SetFrameLevel(display:GetFrameLevel() + 3)
    R.DressIcon(icon, true)
    icon.label = UI.Text(display.top, "body", 13, "text")
    icon.label:SetJustifyH("CENTER")
    display.icons[index] = icon
  end
  return icon
end

-- Sizes and places the visuals for entry.infos (from R.Layout; any time, these frames aren't secure).
function R.LayoutDisplay(entry)
  local display = entry.display
  if not display then
    return
  end
  local db = R.DB()
  local radius, size = db.radius, db.iconSize
  local infos = entry.infos or {}
  local outer = 2 * (radius + size * 0.5 * HOVER + 10)
  display:SetSize(outer, outer)
  display.back:SetSize(outer, outer)
  local hub = math.max(56, math.floor(radius * 1.05))
  display.hub:SetSize(hub, hub)
  display.hubSize = hub
  display.name:SetWidth(hub - 12)
  R.LayoutPing(display, #infos, radius)
  local ping = R.PingStyle()
  if ping then
    -- room for the names outside the wheel
    local wide = 2 * (math.max(display.ping.radius or 0, radius + size) + 90)
    display:SetSize(wide, wide)
  end
  for index, info in ipairs(infos) do
    local icon = Icon(entry, index)
    local x, y = R.SlicePosition(index, #infos, radius)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", display, "CENTER", x, y)
    icon:SetSize(size, size)
    icon.x, icon.y = x, y
    icon.art:SetTexture(info.icon)
    icon.info = info
    R.SetIconHot(icon, false)
    icon:Show()
    icon.label:SetText(ping and (info.name or "") or "")
    icon.label:SetShown(ping)
    if ping then
      PlaceLabel(icon, R.SliceAngle(index, #infos))
    end
  end
  for index = #infos + 1, #display.icons do
    display.icons[index].info = nil
    display.icons[index]:Hide()
    display.icons[index].label:Hide()
  end
  entry.hover = nil
  R.SetHover(entry, nil)
end

-- The slice pointed at: bigger, accent ring, its name in the hub, the pointer line towards it.
function R.SetHover(entry, index)
  local display = entry.display
  local db = R.DB()
  local previous = entry.hover and display.icons[entry.hover]
  if previous then
    previous:SetSize(db.iconSize, db.iconSize)
    R.SetIconHot(previous, false)
  end
  entry.hover = index
  local icon = index and display.icons[index]
  R.PingHover(display, icon and icon.info and index or nil)
  if icon and icon.info and R.PingStyle() then
    icon:SetSize(db.iconSize * HOVER, db.iconSize * HOVER)
    R.SetIconHot(icon, true)
  elseif icon and icon.info then
    icon:SetSize(db.iconSize * HOVER, db.iconSize * HOVER)
    R.SetIconHot(icon, true)
    display.name:SetText(icon.info.name or "")
    display.name:SetTextColor(UI.Unpack(Theme().bright))
    local length = math.sqrt(icon.x * icon.x + icon.y * icon.y)
    if length > 0 then
      local ux, uy = icon.x / length, icon.y / length
      local from = (display.hubSize or 60) * 0.5
      local to = length - db.iconSize * HOVER * 0.5 - 2
      display.tip:ClearAllPoints()
      display.tip:SetPoint("CENTER", display, "CENTER", ux * from, uy * from)
      display.tip:Show()
      if display.pointer and to > from then
        display.pointer:SetStartPoint("CENTER", display, ux * from, uy * from)
        display.pointer:SetEndPoint("CENTER", display, ux * to, uy * to)
        display.pointer:Show()
      end
    end
  else
    display.name:SetText(entry.name or "")
    display.name:SetTextColor(UI.Unpack(Theme().muted))
    display.tip:Hide()
    if display.pointer then
      display.pointer:Hide()
    end
  end
end

-- Follows the cursor while the ring is open (the secure snippet does the same sums on release).
function R.Track(entry, elapsed)
  local display = entry.display
  entry.since = (entry.since or 0) + (elapsed or 0)
  if entry.since >= UPDATE then
    entry.since = 0
    R.UpdateIcons(entry)
  end
  local cx, cy = display:GetCenter()
  if not cx then
    return
  end
  local x, y = GetCursorPosition()
  local scale = display:GetEffectiveScale()
  local dx, dy = x / scale - cx, y / scale - cy
  R.PingPointer(display, dx, dy, dx * dx + dy * dy < R.DeadZone() * R.DeadZone())
  local pick = R.PickIndex(dx, dy, #(entry.infos or {}), R.DeadZone(), R.OuterLimit())
  if pick ~= entry.hover then
    R.SetHover(entry, pick)
  end
end

function R.Opened(entry)
  local display = entry.display
  for _, event in ipairs(COOLDOWN_EVENTS) do
    pcall(display.RegisterEvent, display, event)
  end
  entry.since = 0
  entry.hover = nil
  R.SetHover(entry, nil)
  R.UpdateIcons(entry)
  if display.open then
    display.open:Stop()
    display.open:Play()
  end
end

-- Usable state of a slice now: "range", "mana", "off" or nil (fine).
function R.State(info)
  local target = UnitExists and UnitExists("target")
  if info.spell then
    local spell = info.spell
    if C_Spell and C_Spell.IsSpellUsable then
      local usable, noMana = R.Call(C_Spell.IsSpellUsable, spell)
      if R.Readable(noMana) and noMana then
        return "mana"
      end
      if R.Readable(usable) and not usable then
        return "off"
      end
    end
    if target and C_Spell and C_Spell.IsSpellInRange then
      local inRange = R.Call(C_Spell.IsSpellInRange, spell, "target")
      if R.Readable(inRange) and inRange == false then
        return "range"
      end
    end
  elseif info.item then
    if R.ItemCount(info.item) == 0 and info.attrs.type == "item" then
      return "off"
    end
    if C_Item and C_Item.IsUsableItem then
      local usable, noMana = R.Call(C_Item.IsUsableItem, info.item)
      if R.Readable(noMana) and noMana then
        return "mana"
      end
      if R.Readable(usable) and not usable then
        return "off"
      end
    end
    if target and C_Item and C_Item.IsItemInRange then
      local inRange = R.Call(C_Item.IsItemInRange, info.item, "target")
      if R.Readable(inRange) and inRange == false then
        return "range"
      end
    end
  elseif info.marker and not target then
    return "off"
  elseif info.missing then
    return "off"
  end
  return nil
end

local TINT = { range = { 1, 0.3, 0.3 }, mana = { 0.4, 0.4, 1 }, off = { 0.6, 0.6, 0.6 } }

function R.Tint(icon, state)
  local color = TINT[state] or { 1, 1, 1 }
  icon.art:SetVertexColor(color[1], color[2], color[3])
  icon.art:SetDesaturated(state == "off")
end

-- The count shown on an icon: items you carry, a spell's reagents; nil = none.
function R.CountText(info)
  if info.item and info.attrs.type == "item" then
    local count = R.ItemCount(info.item)
    if count ~= 1 then
      return count
    end
  elseif info.spell and C_Spell and C_Spell.GetSpellCastCount then
    local count = R.Call(C_Spell.GetSpellCastCount, info.spell)
    if R.Readable(count) and type(count) == "number" and count > 0 then
      return count
    end
  end
  return nil
end

function R.SetCooldown(cooldown, info)
  if not cooldown then
    return
  end
  if info.spell and C_Spell then
    if C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
      local duration = R.Call(C_Spell.GetSpellCooldownDuration, info.spell)
      if duration ~= nil and pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration) then
        return
      end
    end
    local cd = C_Spell.GetSpellCooldown and R.Call(C_Spell.GetSpellCooldown, info.spell)
    if type(cd) == "table" and pcall(cooldown.SetCooldown, cooldown, cd.startTime, cd.duration) then
      return
    end
  elseif info.item then
    local get = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown)
    local start, duration = R.Call(get, info.item)
    if start ~= nil and pcall(cooldown.SetCooldown, cooldown, start, duration) then
      return
    end
  end
  R.Call(cooldown.Clear, cooldown)
end

-- Tints, counts and cooldowns of every icon (on open, every UPDATE seconds and on cooldown events).
function R.UpdateIcons(entry)
  for _, icon in ipairs(entry.display and entry.display.icons or {}) do
    local info = icon.info
    if info and icon:IsShown() then
      R.Tint(icon, R.State(info))
      local count = R.CountText(info)
      icon.count:SetText(count and tostring(count) or "")
      if count == 0 then
        icon.count:SetTextColor(UI.Unpack(Theme().bad))
      else
        icon.count:SetTextColor(UI.Unpack(Theme().bright))
      end
      R.SetCooldown(icon.cooldown, info)
    end
  end
end
