local addonName, ns = ...
local S = ns.S

-- Blizzard's cooldown manager (Blizzard_CooldownViewer: Essential / Utility cooldowns, tracked buff icons,
-- tracked buff bars) in the theme. Square (default): each icon gets the theme slot look (dark fill, slot
-- rings, icon cropped, Blizzard's round-cornered mask and icon frame art off). Round icons (the "roundicons"
-- switch, after a reload; R2-HUD board): the icon cut to a circle inside the board's ring (Buff Tracker's
-- double-line ring on big icons, the thin 1 px dark + 1 px line ring on small ones; shared with Auras.lua), the
-- countdown sized to the icon as on the board, a round cooldown swipe in Blizzard's own tint (kept round after
-- Blizzard's own cooldown calls) and every other
-- Blizzard texture on the icon cut to the same circle. Tracked bars: a dark slot strip with a thin theme line
-- round it and a flat fill in Blizzard's colour; their icon as above. Cooldown, charge and stack numbers and
-- the bars' name and time become white Arial with a shadow, at Blizzard's own size.
-- Icon spacing (CodexDB.skins.iconSpacing, 0-10 px, default 3): Blizzard places the item frames (Edit Mode's
-- padding); inside each one the icon and its cooldown swipe are anchored that much smaller (half on each side),
-- so neighbours get a gap; our fill, mask and rings follow the icon. TylesserCodex.SetIconSpacing(n) changes it
-- live.
-- Blizzard keeps creating, placing and updating its pooled frames: each is styled as it is acquired
-- (post-hooks only), our pieces are textures on its frames, remembered in a weak table. Its aura and
-- cooldown data is kept from addons, and nothing here reads it (no IDs, icons or durations); every call on
-- a Blizzard object is caught. The frames aren't protected, so styling them in a fight is fine; a protected
-- one would wait for the end of the fight.

local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local CIRCLE_MASK = "Interface\\AddOns\\Codex\\Media\\Circle" -- smooth 256px circle (TempPortraitAlphaMask looked jagged)
local CROP = 0.08
local ICON_ART = { ["UI-HUD-CoolDownManager-IconOverlay"] = true } -- Blizzard's icon frame (atlas)
local ICON_FILES = { [6707800] = true } -- the icon's shadow art (a file)
local BAR_ART = { ["UI-HUD-CoolDownManager-Bar-BG"] = true }
-- a bar whose colour is in its art (tint still white) gets this, close to Blizzard's own orange
local BAR_COLOR = { 1, 0.5, 0.25 }
local DEFAULT_SPACING, MAX_SPACING = 3, 10
local VIEWERS = { EssentialCooldownViewer = "icon", UtilityCooldownViewer = "icon", BuffIconCooldownViewer = "icon",
  BuffBarCooldownViewer = "bar" }

local part = "cooldowns"
local round = false -- set when the part starts
local pieces = setmetatable({}, { __mode = "k" }) -- [Blizzard frame] = our pieces on it

local function Readable(value)
  return not canaccessvalue or canaccessvalue(value) and true or false
end

-- The player's icon spacing in px (a saved variable, read directly).
local function Spacing()
  local skins = type(CodexDB) == "table" and CodexDB.skins
  local value = type(skins) == "table" and skins.iconSpacing
  if type(value) ~= "number" then
    return DEFAULT_SPACING
  end
  return math.max(0, math.min(MAX_SPACING, math.floor(value + 0.5)))
end

-- A call on a Blizzard object, caught: ok, results...
local function Call(object, method, ...)
  if type(object) == "table" and type(object[method]) == "function" then
    return pcall(object[method], object, ...)
  end
  return false
end

local function PiecesOf(frame)
  local list = pieces[frame]
  if not list then
    list = {}
    pieces[frame] = list
  end
  return list
end

-- Blizzard's frame art on `frame` (by atlas or file) made invisible; `keep` is left alone.
local function HideArt(frame, atlases, files, keep)
  local ok, regions = pcall(function()
    return { frame:GetRegions() }
  end)
  if not ok then
    return
  end
  for _, region in ipairs(regions) do
    if region ~= keep and type(region) == "table" then
      local okAtlas, atlas = Call(region, "GetAtlas")
      local okFile, file = Call(region, "GetTexture")
      if (okAtlas and Readable(atlas) and atlas ~= nil and atlases[atlas])
        or (files and okFile and Readable(file) and file ~= nil and files[file]) then
        Call(region, "SetAlpha", 0)
      end
    end
  end
end

-- Blizzard's own masks on an icon (its rounded corners) off; ours stays.
local function DropMasks(icon, keep)
  local ok, count = Call(icon, "GetNumMaskTextures")
  if not ok or type(count) ~= "number" or not Readable(count) then
    return
  end
  for index = count, 1, -1 do
    local okMask, mask = Call(icon, "GetMaskTexture", index)
    if okMask and type(mask) == "table" and mask ~= keep then
      Call(icon, "RemoveMaskTexture", mask)
    end
  end
end

-- White Arial with a shadow, at the text's own size (or `exact`).
local function Clean(text, fallback, exact)
  if not S.IsRegion(text) then
    return
  end
  local size = fallback
  local ok, _, current = Call(text, "GetFont")
  if exact then
    size = exact
  elseif ok and type(current) == "number" and Readable(current) and current > 0 then
    size = current
  end
  Call(text, "SetFont", NUMBER_FONT, size, "OUTLINE")
  Call(text, "SetShadowOffset", 1, -1)
  Call(text, "SetShadowColor", 0, 0, 0, 1)
  Call(text, "SetTextColor", 1, 1, 1, 1)
end

-- The text of an Applications / ChargeCount holder (a frame holding the text, or the text itself).
local function TextOf(holder, key)
  if S.IsRegion(holder) then
    return holder
  end
  return S.Region(holder, key)
end

-- Our rings' draw layer: the icon's own layer, just above it, so Blizzard's texts on the same frame (a bar
-- icon's stack count; in a higher layer) stay on top. Texts in child frames are above us anyway.
local LAYER_ORDER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4 }
local function RingLayer(icon)
  local ok, layer, sublevel = Call(icon, "GetDrawLayer")
  if not ok or not Readable(layer) or not LAYER_ORDER[layer] then
    return "ARTWORK", 6
  end
  if type(sublevel) ~= "number" or not Readable(sublevel) then
    sublevel = 0
  end
  return layer, math.min(7, sublevel + 2) -- room for the black ring at +1
end

-- Square: the slot look on the icon's own box (fill behind it, rings over its edge).
local function SquareIcon(holder, icon, mine)
  if not mine.built then
    local look = S.Look("slot")
    local fill = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints(icon)
    S.SetColor(fill, look.fill)
    local layer, sublevel = RingLayer(icon)
    for _, ring in ipairs(look.rings or {}) do
      S.Outline(holder, icon, ring.inset, ring.size, ring.color, layer, sublevel)
    end
    mine.built = true
  end
end

-- Round (R2-HUD board): the icon masked to a circle, the board's ring round it (ns.Round, Auras.lua: Buff
-- Tracker's double-line ring on big icons, the thin ring on small ones), drawn under the icon so Blizzard's
-- counts stay on top. Returns how far in from the item frame's edge the icon's circle starts.
local function RoundIcon(holder, icon, mine, inset)
  local R = ns.Round
  if not mine.built then
    local mask = holder:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    mine.mask = mask
    mine.rings = {}
    mine.own = { [mask] = true }
    mine.art = setmetatable({}, { __mode = "k" }) -- Blizzard textures already masked
    mine.built = true
  end
  local ok, width = Call(holder, "GetWidth")
  if not ok or type(width) ~= "number" or not Readable(width) or width <= 0 then
    width = 40
  end
  local diameter = width - 2 * inset
  local ring = R.Use(mine.rings, holder, R.IsBig(diameter))
  mine.own[ring.tint], mine.own[ring.dark] = true, true
  mine.ring = ring
  if not mine.masked and Call(icon, "AddMaskTexture", mine.mask) then
    mine.masked = true
  end
  return R.Place(ring, holder, inset, diameter), width
end

-- Round: every other texture Blizzard has on the item and its art frames (shadow, frame art, the cooldown
-- flash, out-of-range or other overlays; some come back after we hide them) is cut to the same circle, so
-- nothing square can show round the icon, whatever Blizzard does with its alpha.
local function MaskArt(holder, icon, cooldown, mine)
  local ok, regions = pcall(function()
    local list = { holder:GetRegions() }
    for _, child in ipairs({ holder:GetChildren() }) do
      if child ~= cooldown then
        for _, region in ipairs({ child:GetRegions() }) do
          list[#list + 1] = region
        end
      end
    end
    return list
  end)
  for _, region in ipairs(ok and regions or {}) do
    if region ~= icon and type(region) == "table" and not mine.own[region] and not mine.art[region] then
      local okType, kind = Call(region, "GetObjectType")
      if okType and kind == "Texture" and Call(region, "AddMaskTexture", mine.mask) then
        mine.art[region] = true
      end
    end
  end
end

-- Round swipe: Blizzard sets its cooldowns' swipe (and bling) again as cooldowns start, so ours is put back
-- after every such call. Post-hooks on the Cooldown widget's shared methods (as cooldown-text addons do: no
-- field is written on Blizzard's frames); they act only on the cooldowns in `roundSwipes`.
local roundSwipes = setmetatable({}, { __mode = "k" })
local SWIPE_CALLS = { "SetCooldown", "SetCooldownDuration", "SetCooldownFromDurationObject", "SetCooldownFromExpirationTime",
  "SetCooldownUNIX", "SetSwipeTexture", "SetDrawBling", "SetUseCircularEdge", "SetDrawSwipe" }
local hookedMethods = {}
local applying = false

local function RoundSwipe(cooldown)
  applying = true
  Call(cooldown, "SetSwipeTexture", CIRCLE_MASK)
  Call(cooldown, "SetUseCircularEdge", true)
  Call(cooldown, "SetDrawBling", false) -- the end-of-cooldown flash is a square burst
  applying = false
end

local function WatchSwipe(cooldown)
  roundSwipes[cooldown] = true
  local okMeta, meta = pcall(getmetatable, cooldown)
  local methods = okMeta and type(meta) == "table" and meta.__index
  if type(methods) == "table" and not hookedMethods[methods] then
    hookedMethods[methods] = true
    for _, name in ipairs(SWIPE_CALLS) do
      if type(methods[name]) == "function" then
        hooksecurefunc(methods, name, function(self)
          if not applying and roundSwipes[self] then
            RoundSwipe(self)
          end
        end)
      end
    end
  end
  RoundSwipe(cooldown)
end

-- `region` (the icon, its cooldown) anchored inside `holder`, `inset` in from each edge. The item frames aren't
-- protected (FlareUI re-anchors their icons too); applied again on every acquire and layout.
local function Fit(region, holder, inset)
  if Call(region, "ClearAllPoints") then
    Call(region, "SetPoint", "TOPLEFT", holder, "TOPLEFT", inset, -inset)
    Call(region, "SetPoint", "BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
  end
end

-- One icon: `holder` the frame it sits in, `icon` its texture.
local function StyleIcon(holder, icon, cooldown)
  if not S.Usable(holder) or not S.IsRegion(icon) then
    return
  end
  local mine = PiecesOf(holder)
  local inset = Spacing() / 2
  local countSize
  HideArt(holder, ICON_ART, ICON_FILES, icon)
  DropMasks(icon, mine.mask)
  Call(icon, "SetTexCoord", CROP, 1 - CROP, CROP, 1 - CROP)
  if round then
    -- the icon (and its swipe) inside the ring
    local depth, width = RoundIcon(holder, icon, mine, inset)
    inset = depth
    -- the board's countdown: 16 px on a 40 px icon, 11 px on 28 px
    countSize = math.max(9, math.min(20, math.floor((width - 2 * depth) * 0.4 + 0.5)))
    MaskArt(holder, icon, cooldown, mine)
    if S.Usable(cooldown) then
      WatchSwipe(cooldown)
    end
  else
    SquareIcon(holder, icon, mine)
  end
  Fit(icon, holder, inset)
  if S.Usable(cooldown) then
    Fit(cooldown, holder, inset)
    local ok, countdown = Call(cooldown, "GetCountdownFontString")
    if ok then
      Clean(countdown, 14, countSize)
    end
  end
end

-- A tracked buff bar: dark strip, thin theme line, flat fill, clean name and time.
local function StyleBar(bar)
  if not S.Usable(bar) then
    return
  end
  local mine = PiecesOf(bar)
  Call(S.Child(bar, "BarBG"), "SetAlpha", 0)
  HideArt(bar, BAR_ART)
  local ok, fill = Call(bar, "GetStatusBarTexture")
  if ok and S.IsRegion(fill) then
    Call(fill, "SetTexture", FLAT)
    Call(fill, "ClearTextureSlice")
    Call(fill, "SetTextureSliceMode", 0)
  end
  -- Blizzard's colour stays; a white tint means the colour was in the art we just replaced
  local okColor, r, g, b = Call(bar, "GetStatusBarColor")
  if okColor and Readable(r) and Readable(g) and Readable(b) and type(r) == "number" and type(g) == "number"
    and type(b) == "number" and r > 0.95 and g > 0.95 and b > 0.95 then
    Call(bar, "SetStatusBarColor", BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3])
  end
  if not mine.plate then
    local slot = S.Look("slot")
    mine.plate = S.Plate(bar, { fill = slot.fill, alpha = 0.85,
      rings = { { inset = 0, size = 1, color = S.Theme().titlebar.line } } }, { pad = 1, ringLayer = "OVERLAY" })
  end
  Clean(S.Region(bar, "Name"), 12)
  Clean(S.Region(bar, "Duration"), 12)
end

-- One item frame of a viewer (pooled: styled again on every acquire; our pieces are made once).
local function StyleItem(item, kind)
  if not S.Usable(item) then
    return
  end
  local icon = S.Child(item, "Icon")
  if kind == "bar" or S.Child(item, "Bar") then
    StyleBar(S.Child(item, "Bar"))
    if icon and not S.IsRegion(icon) then
      StyleIcon(icon, S.Child(icon, "Icon"), S.Child(icon, "Cooldown"))
      Clean(TextOf(S.Child(icon, "Applications"), "Applications"), 12)
    end
  else
    StyleIcon(item, icon, S.Child(item, "Cooldown"))
    Clean(TextOf(S.Child(item, "Applications"), "Applications"), 12)
    Clean(TextOf(S.Child(item, "ChargeCount"), "Current"), 14)
  end
end

local function Item(item, kind)
  if S.InCombat() and S.Protected(item) then
    S.Defer(item, function()
      StyleItem(item, kind)
    end)
    return
  end
  local ok, err = pcall(StyleItem, item, kind)
  if not ok then
    S.Fail(part, err)
  end
end

-- The viewer's frames in use, from its pool (else its children that look like items).
local function Items(viewer)
  local list = {}
  local pool = S.Child(viewer, "itemFramePool")
  if pool and type(pool.EnumerateActive) == "function" then
    local ok = pcall(function()
      for item in pool:EnumerateActive() do
        list[#list + 1] = item
      end
    end)
    if ok then
      return list
    end
    list = {}
  end
  local ok, children = pcall(function()
    return { viewer:GetChildren() }
  end)
  for _, child in ipairs(ok and children or {}) do
    if type(child) == "table" and (S.Child(child, "Icon") or S.Child(child, "Bar")) then
      list[#list + 1] = child
    end
  end
  return list
end

local function StyleAll()
  for name, kind in pairs(VIEWERS) do
    local viewer = S.Get(name)
    if S.Usable(viewer) then
      for _, item in ipairs(Items(viewer)) do
        Item(item, kind)
      end
    end
  end
end

local queued = false
local function StyleSoon()
  if queued then
    return
  end
  queued = true
  -- after Blizzard's own layout, outside its call
  C_Timer.After(0, function()
    queued = false
    S.Run(part, StyleAll)
  end)
end

local function Setup()
  for name, kind in pairs(VIEWERS) do
    local viewer = S.Get(name)
    if S.Usable(viewer) and S.Once(viewer, "cooldowns") then
      S.HookMethod(viewer, "OnAcquireItemFrame", function(_, item)
        Item(item, kind)
      end)
      S.HookMethod(viewer, "RefreshLayout", StyleSoon)
    end
  end
  StyleAll()
end

-- Live change of the icon spacing (Settings' +/- buttons): stores it and re-fits every styled icon (cooldown
-- manager, round buffs and debuffs). Nothing here is protected, so it works in a fight too.
ns.spacingListeners = ns.spacingListeners or {}
TylesserCodex.SetIconSpacing = function(value)
  if type(value) ~= "number" or type(CodexDB) ~= "table" or type(CodexDB.skins) ~= "table" then
    return
  end
  CodexDB.skins.iconSpacing = math.max(0, math.min(MAX_SPACING, math.floor(value + 0.5)))
  for _, listener in ipairs(ns.spacingListeners) do
    listener()
  end
end

S.Part("cooldowns", function()
  -- a flag only (no part of its own): switching it needs a reload
  round = TylesserCodex.SkinPartOn("roundicons") and true or false
  ns.spacingListeners = ns.spacingListeners or {}
  table.insert(ns.spacingListeners, StyleSoon)
  Setup()
  S.OnAddOn("Blizzard_CooldownViewer", Setup)
end)
