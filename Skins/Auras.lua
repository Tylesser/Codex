local addonName, ns = ...
local S = ns.S

-- Buffs and debuffs (BuffFrame / DebuffFrame): each buff icon gets a thin square ring of our own just outside
-- it (theme line, then black; debuffs none: they keep Blizzard's dispel-colour border, and their empty slots
-- stay clean), and the duration and stack numbers become white Arial with a shadow (debuff timers light red,
-- as on the R2-HUD board). Blizzard keeps placing, sorting and timing the icons.
-- Round icons (the "roundicons" switch, after a reload; R2-HUD board): the icon is cut to a circle with a mask
-- and gets the board's thin ring round it (1 px dark, 1 px line; see ns.Round below). Blizzard's square debuff /
-- weapon enchant borders are made invisible; a debuff's ring takes the border's dispel colour when that colour
-- is readable, else the ring's own colour. A debuff ring is only shown on a slot that surely holds an aura (icon texture
-- readable and set, button and icon shown), so the debuff container's empty slots never get a ring.
-- Icon spacing (CodexDB.skins.iconSpacing, 0-10 px, default 3), round mode only: the circle and its rings sit
-- half of it in from the icon's edge, so neighbours get a gap (only our frame and mask move, never Blizzard's
-- icon; square icons keep Blizzard's own Edit Mode padding).
-- Our frame is a child of the button (it shows and hides with it) one frame level BELOW it, so Blizzard's own
-- icon, stack count and duration always draw over our rings; that is why the rings lie round the icon.
-- Care: Blizzard locks its aura buttons against addon code while auras are secret (on Forever nearly
-- always), and then every call on them fails. So nothing is ever written to a button: our ring is a frame
-- of our own created on it, and the only calls on Blizzard's regions (fonts, the icon's mask and crop, the
-- borders' alpha) are each caught. A button that refuses is tried again on a later pass (one failed try
-- ends a pass). Durations and dispel types are never read.

local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local RING = "Interface\\AddOns\\Codex\\Modules\\Buffs\\Media\\Ring" -- white ring, coloured per theme
local CIRCLE_MASK = "Interface\\AddOns\\Codex\\Media\\Circle" -- smooth 256px circle (TempPortraitAlphaMask looked jagged)
local CROP = 0.08 -- the icon art's own border, cut off in round mode
local CONTAINERS = { BuffFrame = "buff", DebuffFrame = "debuff" }
-- Blizzard's square borders on an aura button (dispel colour, weapon enchant), hidden in round mode
local BORDERS = { "DebuffBorder", "TempEnchantBorder", "Border" }
-- the container's update methods, as named on 10.x-12.x clients (whichever exist are followed)
local UPDATES = { "UpdateAuraButtons", "Update" }
local SQUARE_OUT = 2 -- square: the two ring lines lie just outside the icon
local RING_SHARE = 11 / 128 -- the ring art's width, as a share of its size (Ring.tga)
local DEFAULT_SPACING, MAX_SPACING = 3, 10

local part = "auras"
local round = false -- set when the part starts
-- [button] = { ring = our frame, level, placed (geometry key), lines, circle, dark, mask, masked, cropped, text,
-- tries }
local done = setmetatable({}, { __mode = "k" })

local function Readable(value)
  return not canaccessvalue or canaccessvalue(value) and true or false
end

-- How far our ring frame sits in from the icon's edge: half the icon spacing (round mode), else 0.
local function Inset()
  if not round then
    return 0
  end
  local skins = type(CodexDB) == "table" and CodexDB.skins
  local value = type(skins) == "table" and skins.iconSpacing
  if type(value) ~= "number" then
    value = DEFAULT_SPACING
  end
  return math.max(0, math.min(MAX_SPACING, math.floor(value + 0.5))) / 2
end

-- Every aura button of a container, read from its own lists (plain table reads), else its children.
local function Buttons(container)
  local list = {}
  local frames = S.Child(container, "auraFrames")
  if frames then
    for _, button in pairs(frames) do
      list[#list + 1] = button
    end
    return list
  end
  for _, holder in ipairs({ S.Child(container, "AuraContainer"), container }) do
    if S.Usable(holder) and holder.GetChildren then
      local ok, children = pcall(function()
        return { holder:GetChildren() }
      end)
      if ok then
        for _, child in ipairs(children) do
          list[#list + 1] = child
        end
      end
      if #list > 0 then
        return list
      end
    end
  end
  return list
end

local function Fit(piece, box, depth)
  if piece then
    piece:ClearAllPoints()
    piece:SetPoint("TOPLEFT", box, "TOPLEFT", depth, -depth)
    piece:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -depth, depth)
  end
end

-- Round rings (R2-HUD board, shared with Cooldowns.lua as ns.Round), drawn round the icon's circle, never over
-- it. Big icons (Essential cooldowns, 36 px and up) get Buff Tracker's double-line ring (Ring.tga, the user's
-- choice; board token roundRing) in the theme line colour; smaller ones (buffs, debuffs, Utility) the board's
-- thin ring (roundRingThin): 1 px of the slot line colour outside 1 px of dark. Inside both, 1 px of dark
-- between ring and icon. Colours come from the theme: big = titlebar.line, thin = the first light slot ring,
-- dark = the darkest slot ring. Pieces are textures of `frame` on BACKGROUND, so anything else drawn there
-- (the icon, Blizzard's counts) lies on top.
local R = {}
ns.Round = R
R.BIG_AT = 36

local function Light(c)
  return c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
end

function R.Colors()
  local theme = S.Theme()
  local thin, dark
  for _, ring in ipairs(theme.slot and theme.slot.rings or {}) do
    local c = ring.color
    if not thin and Light(c) > 0.12 then
      thin = c
    end
    if not dark or Light(c) < Light(dark) then
      dark = c
    end
  end
  local line = theme.titlebar.line
  return line, thin or line, dark or { 0, 0, 0 }
end

local function Disc(frame, sublevel, color)
  local disc = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
  disc:SetTexture(CIRCLE_MASK)
  disc:SetVertexColor(color[1], color[2], color[3], 1)
  return disc
end

-- One ring's pieces: `tint` (the coloured ring, which a debuff recolours) and `dark` (the dark disc it lies on).
function R.Build(frame, big)
  local line, thin, dark = R.Colors()
  local ring = { big = big }
  if big then
    ring.dark = Disc(frame, -8, dark)
    ring.tint = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    ring.tint:SetTexture(RING)
    ring.tint:SetVertexColor(line[1], line[2], line[3], 1)
    ring.color = line
  else
    ring.tint = Disc(frame, -8, thin)
    ring.dark = Disc(frame, -7, dark)
    ring.color = thin
  end
  return ring
end

-- The ring for this size from `cache` (made when first needed; the other size is hidden).
function R.Use(cache, frame, big)
  if not cache[big] then
    cache[big] = R.Build(frame, big)
  end
  local other = cache[not big]
  if other then
    other.tint:Hide()
    other.dark:Hide()
  end
  cache[big].tint:Show()
  cache[big].dark:Show()
  return cache[big]
end

-- Anchors a ring in `box`, `inset` in from its edges, for a ring `diameter` px wide; returns how far in from
-- the box's edge the icon's circle starts.
function R.Place(ring, box, inset, diameter)
  local depth = ring.big and math.max(3, math.ceil(diameter * RING_SHARE)) or 2
  Fit(ring.tint, box, inset)
  Fit(ring.dark, box, inset + (ring.big and depth - 1 or 1))
  return inset + depth
end

function R.IsBig(diameter)
  return diameter >= R.BIG_AT
end

-- Our frame on the button, one level under it. Built in steps that are each kept, so a refused step never
-- leaves a second frame behind.
local function IconWidth(icon)
  local ok, width = pcall(icon.GetWidth, icon)
  if not ok or type(width) ~= "number" or not Readable(width) or width <= 0 then
    return 30
  end
  return width
end

-- Anchors our frame (round: half the spacing in from the icon's edge; square: just outside it), the ring and
-- the icon's circle (again when the spacing or the icon's size changed).
local function Place(state, icon)
  local inset = round and Inset() or -SQUARE_OUT
  local diameter = IconWidth(icon) - 2 * inset
  local big = round and R.IsBig(diameter)
  local key = inset .. ":" .. diameter
  if state.placed == key then
    return
  end
  Fit(state.ring, icon, inset)
  if state.rings then
    local ring = R.Use(state.rings, state.ring, big)
    Fit(state.mask, state.ring, R.Place(ring, state.ring, 0, diameter))
    state.tint = ring
  end
  state.placed = key
end

local function Holder(state, button, icon)
  if not state.ring then
    state.ring = CreateFrame("Frame", nil, button)
  end
  if not state.level then
    local level = button:GetFrameLevel() -- refused while the button is locked: tried again later
    if type(level) == "number" and Readable(level) then
      state.ring:SetFrameLevel(math.max(0, level - 1))
    end
    state.level = true
  end
  Place(state, icon)
  return state.ring
end

-- Square ring: 1 px theme line, then 1 px black, just outside the icon.
local function SquareRing(state, button, icon)
  local ring = Holder(state, button, icon)
  if not state.lines then
    S.Outline(ring, ring, 0, 1, S.Theme().titlebar.line, "OVERLAY", 1)
    S.Outline(ring, ring, 1, 1, { 0, 0, 0, 1 }, "OVERLAY", 2)
    state.lines = true
  end
end

-- Round: the icon cut to a circle (mask on the button, or on our frame if the button refuses it), its art's
-- border cropped, and the ring drawn by our frame round it.
local function RoundIcon(state, button, icon)
  local ring = Holder(state, button, icon)
  if not state.mask then
    local ok, mask = pcall(button.CreateMaskTexture, button)
    if not ok or type(mask) ~= "table" then
      mask = ring:CreateMaskTexture()
    end
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(ring)
    state.mask = mask
  end
  if not state.masked then
    icon:AddMaskTexture(state.mask) -- refused while the button is locked: tried again later
    state.masked = true
  end
  if not state.cropped then
    icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    state.cropped = true
  end
  if not state.lines then
    state.rings = {}
    state.placed = nil
    Place(state, icon)
    state.lines = true
  end
end

local DEBUFF_TIME = { 1, 0.54, 0.5 } -- the board's debuff timer (#ff8a80)

local function Numbers(text, size, color)
  if type(text) ~= "table" or type(text.SetFont) ~= "function" then
    return
  end
  color = color or { 1, 1, 1 }
  text:SetFont(NUMBER_FONT, size, "OUTLINE")
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  text:SetTextColor(color[1], color[2], color[3], 1)
end

-- The duration a little away from the icon: Blizzard anchors its top right on the icon's bottom edge, and our ring
-- ran through the digits (the user's "36 m" buff, 2026-11-19). Blizzard anchors it again on every layout
-- (AuraContainerMixin: SetPoint(durationPoint, aura.Icon, durationRelativePoint)), so a post hook on the text's
-- SetPoint moves it on by DURATION_GAP away from the icon, whichever side the layout puts it.
local DURATION_GAP = 3
local shifting = false

local function Away(point)
  if point:find("TOP") then
    return 0, -DURATION_GAP
  elseif point:find("BOTTOM") then
    return 0, DURATION_GAP
  elseif point == "LEFT" then
    return DURATION_GAP, 0
  elseif point == "RIGHT" then
    return -DURATION_GAP, 0
  end
  return 0, 0
end

local function ShiftDuration(text, point, relative, relativePoint, x, y)
  if shifting or type(point) ~= "string" or not Readable(point) then
    return
  end
  if type(relative) == "number" then -- SetPoint(point, x, y): on the parent
    relative, relativePoint, x, y = nil, point, relative, relativePoint
  end
  x, y = x or 0, y or 0
  if type(x) ~= "number" or type(y) ~= "number" or not Readable(x) or not Readable(y) then
    return
  end
  local dx, dy = Away(point)
  if dx == 0 and dy == 0 then
    return
  end
  shifting = true
  pcall(text.SetPoint, text, point, relative or text:GetParent(), relativePoint or point, x + dx, y + dy)
  shifting = false
end

local function DurationGap(text)
  if type(text) ~= "table" or type(text.SetPoint) ~= "function" or type(text.GetPoint) ~= "function" then
    return
  end
  S.HookMethod(text, "SetPoint", ShiftDuration)
  local ok, point, relative, relativePoint, x, y = pcall(text.GetPoint, text, 1)
  if ok then
    ShiftDuration(text, point, relative, relativePoint, x, y)
  end
end

local TEXT_TRIES = 5 -- a duration text that holds a secret refuses font changes: not tried for ever

-- Empty slots (no aura in them) are shown by some containers: no ring there. A texture we can't read counts
-- as an icon (buffs, whose container shows no empty slots).
local function HasIcon(icon)
  local ok, texture = pcall(icon.GetTexture, icon)
  if not ok or not Readable(texture) then
    return true
  end
  return texture ~= nil and texture ~= ""
end

-- Strict: only a slot that surely holds an aura (a debuff's round ring must never sit on an empty slot).
local function Filled(button, icon)
  local ok, texture = pcall(icon.GetTexture, icon)
  if not ok or not Readable(texture) or texture == nil or texture == "" then
    return false
  end
  for _, object in ipairs({ button, icon }) do
    local okShown, shown = pcall(object.IsShown, object)
    if not okShown or not Readable(shown) or not shown then
      return false
    end
  end
  return true
end

-- The colour of Blizzard's debuff border, when it shows and its colour can be read.
local function BorderColor(button)
  for _, key in ipairs(BORDERS) do
    local border = S.Child(button, key)
    if type(border) == "table" and type(border.GetVertexColor) == "function" then
      local okShown, shown = pcall(border.IsShown, border)
      if okShown and Readable(shown) and shown then
        local ok, r, g, b = pcall(border.GetVertexColor, border)
        if ok and Readable(r) and Readable(g) and Readable(b) and type(r) == "number" and type(g) == "number"
          and type(b) == "number" then
          return r, g, b
        end
      end
    end
  end
end

-- Kept up on every pass: which rings show, the debuff ring's colour, Blizzard's square borders hidden.
local function Refresh(state, button, kind)
  local icon = button.Icon or button.icon
  if not state.ring or type(icon) ~= "table" then
    return
  end
  Place(state, icon) -- the icon spacing or size may have changed
  if not round then
    state.ring:SetShown(HasIcon(icon))
    return
  end
  for _, key in ipairs(BORDERS) do
    local border = S.Child(button, key)
    if type(border) == "table" and type(border.SetAlpha) == "function" then
      pcall(border.SetAlpha, border, 0)
    end
  end
  if kind == "debuff" then
    local filled = Filled(button, icon)
    state.ring:SetShown(filled)
    if filled and state.tint then
      local r, g, b = BorderColor(button)
      if not r then
        local c = state.tint.color
        r, g, b = c[1], c[2], c[3]
      end
      state.tint.tint:SetVertexColor(r, g, b, 1)
    end
  else
    state.ring:SetShown(HasIcon(icon))
  end
end

-- One button; errors when it is locked (the caller's pcall catches it).
local function Style(state, button, kind)
  local icon = button.Icon or button.icon
  if type(icon) ~= "table" then
    state.lines, state.text = true, true -- not an aura icon (a collapse button, ...): nothing to do
    return
  end
  if round then
    RoundIcon(state, button, icon)
    Refresh(state, button, kind)
  elseif kind == "buff" then
    SquareRing(state, button, icon)
    Refresh(state, button, kind)
  else
    -- square debuffs keep Blizzard's own dispel-colour border and no ring of ours: the debuff container
    -- keeps empty slots shown, and a ring on those showed as empty boxes in game
    state.lines = true
  end
  if not state.text then
    state.tries = (state.tries or 0) + 1
    if state.tries > TEXT_TRIES then
      state.text = true
      return
    end
    -- Blizzard's own size (small): a bigger duration runs into the icon above it
    Numbers(button.Duration or button.duration, 10, kind == "debuff" and DEBUFF_TIME or nil)
    Numbers(button.Count or button.count, 11)
    DurationGap(button.Duration or button.duration)
    state.text = true
  end
end

local quietUntil = 0
local function Pass()
  if GetTime() < quietUntil then
    return
  end
  for name, kind in pairs(CONTAINERS) do
    local container = S.Get(name)
    if S.Usable(container) then
      for _, button in ipairs(Buttons(container)) do
        if type(button) == "table" then
          local state = done[button] or {}
          done[button] = state
          if state.lines and state.text then
            pcall(Refresh, state, button, kind)
          elseif not pcall(Style, state, button, kind) and not state.lines then
            -- the buttons are locked: one try a second until they let go
            quietUntil = GetTime() + 1
            return
          end
        end
      end
    end
  end
end

local queued = false
local function PassSoon()
  if queued then
    return
  end
  queued = true
  -- after Blizzard's own update, outside its call
  C_Timer.After(0, function()
    queued = false
    S.Run(part, Pass)
  end)
end

local function Setup()
  local found = false
  for name in pairs(CONTAINERS) do
    local container = S.Get(name)
    if S.Usable(container) and S.Once(container, "auras") then
      found = true
      for _, method in ipairs(UPDATES) do
        S.HookMethod(container, method, PassSoon)
      end
    end
  end
  if found and S.Once(CONTAINERS, "events") then
    -- also on our own events, in case the update methods have other names on this client
    local events = CreateFrame("Frame")
    pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
    pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
    pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", PassSoon)
  end
  Pass()
end

S.Part("auras", function()
  -- a flag only (no part of its own): switching it needs a reload
  round = TylesserCodex.SkinPartOn("roundicons") and true or false
  -- TylesserCodex.SetIconSpacing (Cooldowns.lua) calls this after a change
  ns.spacingListeners = ns.spacingListeners or {}
  table.insert(ns.spacingListeners, PassSoon)
  Setup()
  -- the containers come with Blizzard_AuraContainer on some clients
  S.OnAddOn("Blizzard_AuraContainer", Setup)
end)
