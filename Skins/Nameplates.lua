local addonName, ns = ...
local L = TylesserCodex.L
local S = ns.S

-- Blizzard's nameplates (Blizzard_NamePlates) as on the round-2 board (R2-Frames "Nameplates", R2-HUD):
--   [buffs][elite][level badge] [====== health bar ===== 74%]      raid mark above, then debuffs, then the name
--                               [icon][== cast bar: spell ==]
-- Health bar: Blizzard's own fill made flat, with a soft shade towards the bottom (the board's gradient), on a
-- dark slot with the plate line (1 px dark, 1 px theme line). Hostile red and neutral yellow stay Blizzard's;
-- friendly players get their class colour. The target: the line turns into a 2 px accent ring with a soft
-- accent glow (Blizzard's yellow selection border off); the focus a softer accent. Name centred above the bar,
-- white (bright on the target) in the theme's body font; health text inside the bar on the right, white.
-- Level: an 18 px dark disc with a thin theme ring, left of the bar, the number in its difficulty colour.
-- Cast bar: dark slot and plate line round Blizzard's own fill (its interruptible / not colours stay), the
-- icon with a thin black edge. Debuffs: thin ring (1 px black, 1 px theme line; round with "roundicons"),
-- timer centred under the icon, white Arial. Raid mark above the debuffs. Incoming heals: Blizzard's heal
-- prediction in flat greens when its plate options draw it, else a green bar of ours after the health fill.
-- The quest "!" on quest mobs is Modules/Highlight's: it can sit left of the name through
-- TylesserCodex.NameplateMarkAnchor(plate) (a small frame of ours that follows the name's left end).
--
-- Care (Forever): plates are recycled and updated all the time, in combat too, and enemy values (health, threat,
-- casts, auras, names) can be secret. Nothing reads them: values go straight into Blizzard's own setters, every
-- call on a Blizzard object is caught. The layout moves only unprotected pieces of a plate (as FlareUI does on
-- Forever: the health bar's right end, the level box, raid / classification frames, the name and health texts,
-- the aura timers), each time after Blizzard's own layout (UpdateAnchors post-hook); a unit frame that reports
-- itself protected keeps Blizzard's layout. Our pieces are textures and small frames of ours, made once per
-- frame and kept in weak tables.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle" -- smooth 256px disc
local RING = "Interface\\AddOns\\Codex\\Modules\\Buffs\\Media\\Ring" -- white ring, coloured per theme
local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local CROP = 0.08
local BLACK = { 0, 0, 0 }
local LINE_ALPHA = 0.8 -- the board's plateLine: theme line at .75-.8
local SHADE = 0.38 -- the board's fill gradient: the bottom about a third darker
local BADGE = 18 -- level badge (board: 18 px disc, 1 px ring)
local GLOW = 6 -- target glow reach in px (board: 12px blur at .5)
local CLASS_SHADE = 0.85 -- class colour as the bar's base (the board's gradient starts at 82 %)
local HEAL_MINE = { 0.3, 0.88, 0.4, 0.7 }
local HEAL_OTHER = { 0.18, 0.66, 0.3, 0.6 }
local AURA_ART = { ["ui-hud-cooldownmanager-iconoverlay"] = true } -- the item's frame art (atlas, lower case)
local AURA_LISTS = { "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame" }
-- Blizzard's level frames (Forever's box, the retail one) and the art on them that goes
local LEVEL_FRAMES = { "PlayerLevelDiffFrame", "LevelFrame" }
local LEVEL_ART_KEYS = { "playerLevelDiffIcon", "Icon", "Background", "Bg", "Border", "Frame", "selectedBorder",
  "SelectedBorder", "Selected", "Highlight" }
local LEVEL_ART_ATLAS = { "levelindicator", "icon%-ring", "selected" } -- atlas name patterns (lower case)
local LEVEL_KEEP = { HighLevelTexture = true } -- the skull

local part = "nameplates"
local round = false -- set when the part starts
local plates = setmetatable({}, { __mode = "k" }) -- [unit frame] = our pieces and state
local auraItems = setmetatable({}, { __mode = "k" }) -- [aura item frame] = our pieces
local healCalc -- the game's heal prediction calculator, when it has one
local HealthText -- (below)

local function Readable(value)
  return not canaccessvalue or canaccessvalue(value) and true or false
end

-- A number we may use (sizes; never unit values).
local function Number(value)
  if Readable(value) and type(value) == "number" and value > 0 then
    return value
  end
end

-- A call on a Blizzard object, caught: ok, results...
local function Call(object, method, ...)
  if type(object) == "table" and type(object[method]) == "function" then
    return pcall(object[method], object, ...)
  end
  return false
end

local function Kill(region)
  if type(region) == "table" then
    Call(region, "SetAlpha", 0)
  end
end

-- The board's titleLine / plateLine colour: the title bar line of every theme.
local function Line()
  return S.Theme().titlebar.line
end

-- The dark line inside it (board: #000, Hearthwood #1c0f06): the slot fill.
local function Dark()
  return S.Theme().slot.fill or BLACK
end

local function Paint(textures, color, alpha)
  for _, texture in ipairs(textures or {}) do
    texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
  end
end

local function Gradient(texture, orientation, from, to)
  texture:SetColorTexture(1, 1, 1, 1)
  if not (CreateColor and texture.SetGradient and pcall(texture.SetGradient, texture, orientation,
    CreateColor(from[1], from[2], from[3], from[4]), CreateColor(to[1], to[2], to[3], to[4]))) then
    texture:SetColorTexture(to[1], to[2], to[3], ((from[4] or 1) + (to[4] or 1)) / 2)
  end
end

local function SetupSize(key)
  local setup = type(NamePlateSetupOptions) == "table" and NamePlateSetupOptions or nil
  return setup and Number(setup[key])
end

-- Text: `face` (or the theme's body font; the game's when the theme has none), a shadow, and a colour when
-- given. `size` is Blizzard's own setup height for that text. onDisc: the text sits on our level disc, which is
-- light on a light theme (Dawn): there it gets the theme's shadow (none) and its colour (Blizzard's difficulty
-- colour) is kept readable on the disc (S.GameText). Texts over the world (the name) and on the bars keep their
-- light colour and dark shadow on every theme.
local function Text(text, size, color, face, onDisc)
  if not S.IsRegion(text) then
    return
  end
  local font = S.Theme().font or {}
  local scale = 1
  if not face and font.body then
    face, scale = font.body, font.bodySize or 1
  end
  if face then
    local ok, _, current, flags = Call(text, "GetFont")
    size = Number(size) or (ok and Number(current)) or 10
    flags = ok and Readable(flags) and type(flags) == "string" and flags or ""
    Call(text, "SetFont", face, size * scale, flags)
  end
  if onDisc and S.Theme().light then
    S.GameText(text, "slot")
  else
    Call(text, "SetShadowOffset", 1, -1)
    Call(text, "SetShadowColor", 0, 0, 0, 1)
  end
  if color then
    Call(text, "SetTextColor", color[1], color[2], color[3], 1)
  end
end

-- White Arial numbers with an outline (stacks, timers), at Blizzard's size.
local function Numbers(text, fallback)
  if not S.IsRegion(text) then
    return false
  end
  local ok, _, current = Call(text, "GetFont")
  local size = ok and Number(current) or fallback
  local done = Call(text, "SetFont", NUMBER_FONT, size, "OUTLINE")
  Call(text, "SetShadowOffset", 1, -1)
  Call(text, "SetShadowColor", 0, 0, 0, 1)
  Call(text, "SetTextColor", 1, 1, 1, 1)
  return done
end

local function HealthBar(unitFrame)
  return S.Child(unitFrame, "HealthBarsContainer", "healthBar") or S.Child(unitFrame, "healthBar")
end

local function CastBar(unitFrame)
  return S.Child(unitFrame, "CastBarsContainer", "castBar") or S.Child(unitFrame, "castBar")
end

local function LevelFrame(unitFrame)
  for _, key in ipairs(LEVEL_FRAMES) do
    local frame = S.Child(unitFrame, key)
    if S.Usable(frame) then
      return frame
    end
  end
end

local function UnitOf(unitFrame)
  local unit = unitFrame.unit
  if Readable(unit) and type(unit) == "string" and unit:find("^nameplate") then
    return unit
  end
end

local function NameOnly(unitFrame)
  local ok, only = Call(unitFrame, "IsShowOnlyName")
  return ok and Readable(only) and only == true
end

-- Health bar --------------------------------------------------------------------------------------------

local function FlatFill(bar)
  local ok, fill = Call(bar, "GetStatusBarTexture")
  if not ok or not S.IsRegion(fill) then
    fill = S.Region(bar, "barTexture")
  end
  if fill then
    Call(fill, "SetTexture", WHITE)
    Call(fill, "ClearTextureSlice")
  end
  return fill
end

-- Once per unit frame: slot, shade, the plate line (dark + theme line), the target's accent and glow.
local function BuildHealth(state, bar)
  if state.line then
    return
  end
  local theme = S.Theme()
  local slot = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  slot:SetAllPoints(bar)
  S.SetColor(slot, Dark(), 0.85) -- board barBg
  local shade = bar:CreateTexture(nil, "ARTWORK", nil, 7)
  shade:SetAllPoints(bar)
  Gradient(shade, "VERTICAL", { 0, 0, 0, SHADE }, { 0, 0, 0, 0 })
  -- a rounded theme (round.plate: Dusk, Dawn): fill, track and shade cut by a rounded mask, the three lines
  -- round it as rounded pieces (they take Paint / SetColorTexture like the square ones)
  state.mask = S.RoundBar(bar, { slot, shade }, { kind = "plate" })
  local radius = state.mask and state.mask.codexRadius
  local function Ring(inset, color)
    if radius then
      return S.UI.RoundLine(bar, bar, radius + inset, color, { inset = -inset, layer = "OVERLAY", sublevel = 6 })
    end
    return S.Outline(bar, bar, -inset, 1, color, "OVERLAY", 6)
  end
  state.dark = Ring(1, Dark())
  state.line = Ring(2, Line())
  Paint(state.line, Line(), LINE_ALPHA)
  state.accent = Ring(3, theme.accent)
  -- the glow: four soft strips fading out from the ring
  local a = theme.accent
  local strong, clear = { a[1], a[2], a[3], 0.45 }, { a[1], a[2], a[3], 0 }
  local glow = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local strip = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    if side == "TOP" then
      strip:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -3, 3)
      strip:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 3, 3)
      strip:SetHeight(GLOW)
      Gradient(strip, "VERTICAL", strong, clear)
    elseif side == "BOTTOM" then
      strip:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -3, -3)
      strip:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 3, -3)
      strip:SetHeight(GLOW)
      Gradient(strip, "VERTICAL", clear, strong)
    elseif side == "LEFT" then
      strip:SetPoint("TOPRIGHT", bar, "TOPLEFT", -3, 3)
      strip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -3, -3)
      strip:SetWidth(GLOW)
      Gradient(strip, "HORIZONTAL", clear, strong)
    else
      strip:SetPoint("TOPLEFT", bar, "TOPRIGHT", 3, 3)
      strip:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 3, -3)
      strip:SetWidth(GLOW)
      Gradient(strip, "HORIZONTAL", strong, clear)
    end
    glow[#glow + 1] = strip
  end
  state.glow = glow
  for _, texture in ipairs(state.accent) do
    texture:Hide()
  end
  for _, texture in ipairs(glow) do
    texture:Hide()
  end
end

-- Target / focus as Blizzard's bar keeps them (never a secret compared).
local function Selected(unitFrame, bar)
  local function Flag(method, other)
    local ok, value = Call(bar, method)
    if not ok then
      local unit = UnitOf(unitFrame)
      ok, value = false, nil
      if unit and UnitIsUnit then
        ok, value = pcall(UnitIsUnit, unit, other)
      end
    end
    return ok and Readable(value) and value == true
  end
  return Flag("IsTarget", "target"), Flag("IsFocus", "focus")
end

-- The name: white, bright on the target (board); a name-only plate keeps Blizzard's (class / reaction) colour.
local function NameColor(unitFrame, target)
  if NameOnly(unitFrame) then
    return
  end
  local name = S.Region(unitFrame, "name")
  if name then
    -- the name floats over the world, not on a panel: a light theme's dark "bright" would vanish there, so white
    local c = target and not S.Theme().light and S.Theme().bright or { 1, 1, 1 }
    Call(name, "SetTextColor", c[1], c[2], c[3], 1)
  end
end

-- The target's soft glow (CodexDB.skins.nameplateGlow = false: off, the 2 px accent stays; the user's request,
-- 2026-11-22).
local function GlowOn()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  return not (skins and skins.nameplateGlow == false)
end

-- Target: 2 px accent + glow; focus: the line in a softer accent; else the plate line.
local function PaintSelection(unitFrame)
  local state = plates[unitFrame]
  local bar = HealthBar(unitFrame)
  if not state or not state.line or not bar then
    return
  end
  Kill(S.Child(bar, "selectedBorder")) -- Blizzard's yellow / white selection border: ours instead
  local target, focus = Selected(unitFrame, bar)
  local key = target and "target" or focus and "focus" or "none"
  NameColor(unitFrame, target)
  local glow = key == "target" and GlowOn()
  if state.selected == key and state.glowing == glow then
    return
  end
  state.selected, state.glowing = key, glow
  local accent = S.Theme().accent
  if key == "target" then
    Paint(state.line, accent, 1)
  elseif key == "focus" then
    Paint(state.line, accent, 0.65)
  else
    Paint(state.line, Line(), LINE_ALPHA)
  end
  for _, texture in ipairs(state.accent) do
    texture:SetShown(key == "target")
  end
  for _, texture in ipairs(state.glow) do
    texture:SetShown(glow)
  end
end

-- The glow setting changed (Settings): every plate painted again.
TylesserCodex.RefreshPlateGlow = function()
  S.Run(part, function()
    for unitFrame in pairs(plates) do
      PaintSelection(unitFrame)
    end
  end)
end

-- Friendly players in their class colour (Blizzard's pale friendly colour otherwise); every value checked.
local function ClassColor(unitFrame)
  local unit = UnitOf(unitFrame)
  local bar = HealthBar(unitFrame)
  if not unit or not bar or not UnitIsPlayer or not UnitClass then
    return
  end
  local okPlayer, player = pcall(UnitIsPlayer, unit)
  if not (okPlayer and Readable(player) and player == true) then
    return
  end
  if UnitCanAttack then
    local okEnemy, enemy = pcall(UnitCanAttack, "player", unit)
    if not okEnemy or not Readable(enemy) or enemy then
      return
    end
  end
  local okClass, _, class = pcall(UnitClass, unit)
  if not (okClass and Readable(class) and type(class) == "string") then
    return
  end
  local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
    or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if type(color) == "table" and Readable(color.r) and type(color.r) == "number" then
    local tone = S.Theme().classTone and TylesserCodex.ToneClass
    if tone then
      -- Dusk / Dawn: toned down toward the dark track and a little greyer (ns.ToneClass), the hue kept
      local c = tone({ color.r, color.g, color.b }, S.Theme())
      Call(bar, "SetStatusBarColor", c[1], c[2], c[3])
    else
      Call(bar, "SetStatusBarColor", color.r * CLASS_SHADE, color.g * CLASS_SHADE, color.b * CLASS_SHADE)
    end
    return true
  end
end

-- A theme with status colours (Dusk, Dawn): the other plates in them instead of Blizzard's bright red / yellow /
-- green: tapped grey, else by reaction (hostile, neutral, friendly). Friendly players keep their class colour (or
-- Blizzard's). Every value is checked before it is compared; anything unreadable leaves Blizzard's colour.
local TAPPED_STATUS = { 0.45, 0.47, 0.5 }
local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if ok and Readable(value) then
    return value
  end
end

function S.NameplateStatusColor(unit)
  local status = S.Theme().status
  if type(status) ~= "table" or type(unit) ~= "string" then
    return nil
  end
  if Ask(UnitIsTapDenied, unit) == true then
    return status.tapped or TAPPED_STATUS
  end
  if Ask(UnitIsPlayer, unit) == true and Ask(UnitCanAttack, "player", unit) ~= true then
    return nil
  end
  local reaction = Ask(UnitReaction, unit, "player")
  if type(reaction) ~= "number" then
    return nil
  end
  if reaction <= 3 then
    return status.hostile
  elseif reaction == 4 then
    return status.neutral
  end
  return status.friendly
end

-- The bar's colour after Blizzard's: class colour for friendly players, else the theme's status colours.
local function BarColor(unitFrame)
  if ClassColor(unitFrame) then
    return
  end
  local unit, bar = UnitOf(unitFrame), HealthBar(unitFrame)
  if not unit or not bar then
    return
  end
  local color = S.NameplateStatusColor(unit)
  if type(color) == "table" and type(color[1]) == "number" then
    Call(bar, "SetStatusBarColor", color[1], color[2], color[3])
  end
end

-- Level badge -------------------------------------------------------------------------------------------

local function IsLevelArt(region)
  local ok, atlas = Call(region, "GetAtlas")
  if ok and Readable(atlas) and type(atlas) == "string" then
    atlas = atlas:lower()
    for _, pattern in ipairs(LEVEL_ART_ATLAS) do
      if atlas:find(pattern) then
        return true
      end
    end
  end
  return false
end

-- Textures drawn where they are (no rounding to the pixel grid), so the ring and the disc keep one centre.
local function Smooth(texture)
  Call(texture, "SetSnapToPixelGrid", false)
  Call(texture, "SetTexelSnappingBias", 0)
end

-- The level number (or skull) on the disc's own centre. Digits sit a little low in their line box, so the
-- number goes up by a twentieth of its size (half a pixel at 10). Blizzard may place, justify or re-font
-- it again later (level updates): post-hooks on those calls put it back.
local function CenterOnDisc(mine, region)
  if mine.centering or S.Protected(region) then
    return
  end
  mine.centering = true
  pcall(function()
    if Call(region, "ClearAllPoints") then
      local nudge = 0
      if region:GetObjectType() == "FontString" then
        local ok, _, size = Call(region, "GetFont")
        nudge = (ok and Number(size) or 10) * 0.05
      end
      Call(region, "SetPoint", "CENTER", mine.disc, "CENTER", 0, nudge)
    end
    if region:GetObjectType() == "FontString" then
      Call(region, "SetJustifyH", "CENTER")
      Call(region, "SetJustifyV", "MIDDLE")
    end
  end)
  mine.centering = false
end

local CENTER_CALLS = { "SetPoint", "SetAllPoints", "SetJustifyH", "SetJustifyV", "SetFontObject", "SetText",
  "SetFormattedText" }

local function KeepCentred(mine, region)
  CenterOnDisc(mine, region)
  mine.watched = mine.watched or setmetatable({}, { __mode = "k" })
  if mine.watched[region] then
    return
  end
  mine.watched[region] = true
  for _, method in ipairs(CENTER_CALLS) do
    S.HookMethod(region, method, function(self)
      if method == "SetFontObject" and not mine.centering then
        Text(self, nil, nil, NUMBER_FONT, true) -- a new font object: Arial again
      end
      CenterOnDisc(mine, self)
    end)
  end
end

local function StyleLevel(state, frame)
  if not S.Usable(frame) then
    return
  end
  state.levels = state.levels or {}
  local mine = state.levels[frame]
  if not mine then
    -- board: an 18 px disc, rgba(0,0,0,.75), with a 1 px theme line round it
    local ring = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetTexture(CIRCLE)
    local line = Line()
    ring:SetVertexColor(line[1], line[2], line[3], 1)
    local disc = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    disc:SetTexture(CIRCLE)
    local dark = Dark()
    disc:SetVertexColor(dark[1], dark[2], dark[3], 0.92)
    disc:SetSize(BADGE, BADGE)
    disc:SetPoint("CENTER", frame, "CENTER", 0, 0)
    -- the ring on the disc's own centre (even sizes: 18 and 20), both unsnapped: concentric
    ring:SetSize(BADGE + 2, BADGE + 2)
    ring:SetPoint("CENTER", disc, "CENTER", 0, 0)
    Smooth(disc)
    Smooth(ring)
    mine = { disc = disc, ring = ring }
    state.levels[frame] = mine
  end
  -- Blizzard's box (and its selection art) off: by key, and by atlas for art without a key
  local keep = {}
  for key in pairs(LEVEL_KEEP) do
    local region = S.Child(frame, key)
    if region then
      keep[region] = true
      if S.IsRegion(region) then
        KeepCentred(mine, region)
      end
    end
  end
  for _, key in ipairs(LEVEL_ART_KEYS) do
    local region = S.Region(frame, key)
    if region and region:GetObjectType() == "Texture" and not keep[region] then
      Kill(region)
    end
  end
  local ok, regions = pcall(function()
    return { frame:GetRegions() }
  end)
  for _, region in ipairs(ok and regions or {}) do
    if region ~= mine.disc and region ~= mine.ring and not keep[region] and type(region) == "table" then
      local okType, kind = Call(region, "GetObjectType")
      if okType and kind == "Texture" and IsLevelArt(region) then
        Kill(region)
      elseif okType and kind == "FontString" then
        Text(region, nil, nil, NUMBER_FONT, true) -- Arial, Blizzard's size; its difficulty colour (readable on Dawn)
        KeepCentred(mine, region)
      end
    end
  end
end

-- Cast bar ----------------------------------------------------------------------------------------------

local function BuildCast(state, cast)
  if state.cast == cast then
    return
  end
  state.cast = cast
  local slot = cast:CreateTexture(nil, "BACKGROUND", nil, -8)
  slot:SetAllPoints(cast)
  S.SetColor(slot, Dark(), 0.85)
  local mask = S.RoundBar(cast, { slot }, { kind = "plate" }) -- rounded themes: as the health bar
  if mask then
    local radius = mask.codexRadius
    S.UI.RoundLine(cast, cast, radius + 1, Dark(), { inset = -1, layer = "OVERLAY", sublevel = 6 })
    Paint(S.UI.RoundLine(cast, cast, radius + 2, Line(), { inset = -2, layer = "OVERLAY", sublevel = 6 }), Line(), LINE_ALPHA)
  else
    S.Outline(cast, cast, -1, 1, Dark(), "OVERLAY", 6)
    Paint(S.Outline(cast, cast, -2, 1, Line(), "OVERLAY", 6), Line(), LINE_ALPHA)
  end
  local icon = S.Region(cast, "Icon")
  if icon then
    -- board: the icon with a 1 px black edge (Blizzard's shield for casts that can't be interrupted sits there)
    S.Outline(cast, icon, -1, 1, BLACK, "OVERLAY", 6)
  end
end

local function RestyleCast(cast)
  Kill(S.Child(cast, "Background"))
  Kill(S.Child(cast, "Border")) -- the classic-style frame, when Blizzard shows it
  local icon = S.Region(cast, "Icon")
  if icon then
    Call(icon, "SetTexCoord", CROP, 1 - CROP, CROP, 1 - CROP)
  end
  local size = SetupSize("castBarFontHeight")
  Text(S.Region(cast, "Text"), size, { 1, 1, 1 }, NUMBER_FONT)
  Text(S.Region(cast, "CastTargetNameText"), size, nil, NUMBER_FONT)
end

-- Auras -------------------------------------------------------------------------------------------------

-- Blizzard's own masks on the icon (its rounded corners) off; ours stays.
local function DropMasks(icon, keep)
  local ok, count = Call(icon, "GetNumMaskTextures")
  if not ok or not Number(count) then
    return
  end
  for index = count, 1, -1 do
    local okMask, mask = Call(icon, "GetMaskTexture", index)
    if okMask and type(mask) == "table" and mask ~= keep then
      Call(icon, "RemoveMaskTexture", mask)
    end
  end
end

local function HideAuraArt(item, icon)
  local ok, regions = pcall(function()
    return { item:GetRegions() }
  end)
  for _, region in ipairs(ok and regions or {}) do
    if region ~= icon and type(region) == "table" then
      local okAtlas, atlas = Call(region, "GetAtlas")
      if okAtlas and Readable(atlas) and type(atlas) == "string" and AURA_ART[atlas:lower()] then
        Kill(region)
      end
    end
  end
end

-- Our frame over the item (above its cooldown swipe) that carries the rings.
local function Holder(mine, item, icon, cooldown)
  if not mine.holder then
    local holder = CreateFrame("Frame", nil, item)
    holder:SetAllPoints(icon)
    local okLevel, level = Call(cooldown or item, "GetFrameLevel")
    if okLevel and Number(level) then
      holder:SetFrameLevel(level + 1)
    end
    holder:EnableMouse(false)
    mine.holder = holder
  end
  return mine.holder
end

-- board roundRingThin: 1 px black, then 1 px theme line, outside the icon
local function SquareAura(mine, item, icon, cooldown)
  local holder = Holder(mine, item, icon, cooldown)
  S.Outline(holder, holder, -1, 1, BLACK, "OVERLAY", 1)
  S.Outline(holder, holder, -2, 1, Line(), "OVERLAY", 1)
end

local function RoundAura(mine, item, icon, cooldown)
  local holder = Holder(mine, item, icon, cooldown)
  local ok, mask = Call(item, "CreateMaskTexture")
  if not ok or type(mask) ~= "table" then
    mask = holder:CreateMaskTexture()
  end
  mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(holder)
  mine.mask = mask
  local ring = holder:CreateTexture(nil, "OVERLAY", nil, 1)
  ring:SetTexture(RING)
  ring:SetAllPoints(holder)
  local line = Line()
  ring:SetVertexColor(line[1], line[2], line[3], 1)
end

-- One aura item, once (each step kept, so a refused call is tried again on a later refresh, a few times).
local function StyleAura(item)
  if not S.Usable(item) then
    return
  end
  local mine = auraItems[item]
  if mine and mine.done then
    return
  end
  local icon = S.Region(item, "Icon")
  if not icon or not S.Child(item, "Cooldown") and not S.Child(item, "CountFrame") then
    auraItems[item] = { done = true } -- not one of Blizzard's aura items
    return
  end
  mine = mine or { tries = 0 }
  auraItems[item] = mine
  mine.tries = mine.tries + 1
  local cooldown = S.Child(item, "Cooldown")
  HideAuraArt(item, icon)
  DropMasks(icon, mine.mask)
  if not mine.built then
    mine.built = pcall(round and RoundAura or SquareAura, mine, item, icon, cooldown)
  end
  if round and mine.mask and not mine.masked then
    mine.masked = Call(icon, "AddMaskTexture", mine.mask)
  end
  local cropped = Call(icon, "SetTexCoord", CROP, 1 - CROP, CROP, 1 - CROP)
  if cooldown then
    Call(cooldown, "SetSwipeTexture", round and CIRCLE or WHITE)
    Call(cooldown, "SetSwipeColor", 0, 0, 0, 0.6)
    local okText, countdown = Call(cooldown, "GetCountdownFontString")
    if okText and Numbers(countdown, 10) and not mine.timer then
      -- board: the timer centred under the icon's bottom edge
      if Call(countdown, "ClearAllPoints") then
        mine.timer = Call(countdown, "SetPoint", "CENTER", item, "BOTTOM", 0, 1)
      end
    end
  end
  local counted = Numbers(S.Region(S.Child(item, "CountFrame"), "Count"), 10)
  local ready = mine.built and cropped and (counted or not S.Child(item, "CountFrame")) and (mine.masked or not round)
  mine.done = ready or mine.tries >= 5
end

local function StyleAuraList(list)
  if not S.Usable(list) then
    return
  end
  local ok, children = pcall(function()
    return { list:GetChildren() }
  end)
  for _, child in ipairs(ok and children or {}) do
    StyleAura(child)
  end
end

local function StyleAuras(auras)
  for _, key in ipairs(AURA_LISTS) do
    StyleAuraList(S.Child(auras, key))
  end
  StyleAura(S.Child(auras, "LossOfControlFrame", "AuraItemFrame"))
end

-- Layout ------------------------------------------------------------------------------------------------

-- A piece of the plate we may place: there, not forbidden, not protected.
local function Placeable(object)
  return S.Usable(object) and not S.Protected(object)
end

local function Place(object, ...)
  if not Placeable(object) then
    return false
  end
  return Call(object, "SetPoint", ...)
end

local function Anchored(object, ...)
  if not Placeable(object) or not Call(object, "ClearAllPoints") then
    return false
  end
  local ok = true
  local points = { ... }
  for _, point in ipairs(points) do
    ok = Call(object, "SetPoint", (unpack or table.unpack)(point)) and ok
  end
  return ok
end

local function NameStyle()
  local setup = type(NamePlateSetupOptions) == "table" and NamePlateSetupOptions or nil
  local constants = type(NamePlateConstants) == "table" and NamePlateConstants or nil
  local styles = constants and type(constants.NAME_ANCHOR_STYLES) == "table" and constants.NAME_ANCHOR_STYLES or nil
  if not setup or not styles then
    return "above"
  end
  local style = setup.unitNameAnchorStyle
  if style ~= nil and style == styles.InsideHealthBar then
    return "inside"
  end
  return "above"
end

-- The quest mark's spot: a small frame of ours just left of the name's text (Highlight's "!" goes in it).
local function PlaceMark(state, unitFrame)
  local mark = state.mark
  local name = S.Region(unitFrame, "name")
  if not mark or not name then
    return
  end
  mark:ClearAllPoints()
  local ok, width = Call(name, "GetUnboundedStringWidth")
  if not (ok and Number(width)) then
    ok, width = Call(name, "GetStringWidth")
  end
  width = ok and Number(width)
  if width and (state.centred or NameOnly(unitFrame)) then
    mark:SetPoint("RIGHT", name, "CENTER", -(width / 2) - 2, 0)
  else
    mark:SetPoint("RIGHT", name, "LEFT", -2, 0)
  end
end

-- Width and height of the bars (2026-11-22, the user's "in edit mode allow user to adjust just width or height"):
-- CodexDB.skins.plateWidth / plateHeight, fractions of the game's own (nil = 1). Forever has no Edit Mode system
-- for nameplates and only one size slider (CVar nameplateSize); C_NamePlate.SetNamePlateSize is restricted and
-- NamePlateSetupOptions is Blizzard's table (writing it would taint every plate). So the size is applied here,
-- after Blizzard's own layout (NamePlateUnitFrameMixin's anchoring: the cast bar container from the plate's
-- insetWidth, the health container above it at healthBarHeight): both containers get a centred width, the health
-- container a height. The click area stays the game's.
local PLATE_LIMITS = { width = { 0.5, 1.6 }, height = { 0.5, 2.5 } }
local function PlateSize(key)
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  local value = skins and tonumber(skins[key == "width" and "plateWidth" or "plateHeight"])
  local limits = PLATE_LIMITS[key]
  return value and math.max(limits[1], math.min(limits[2], value)) or 1
end
TylesserCodex.NameplateSize = PlateSize
TylesserCodex.NAMEPLATE_SIZE_LIMITS = PLATE_LIMITS

local function SizeBars(state, unitFrame, container, casts)
  local width, height = PlateSize("width"), PlateSize("height")
  if width == 1 and height == 1 and not state.sized then
    return -- Blizzard's own sizes, untouched
  end
  state.sized = not (width == 1 and height == 1) or nil
  local inset = SetupSize("insetWidth") or 12
  local ok, plateWidth = Call(unitFrame, "GetWidth")
  plateWidth = ok and Number(plateWidth)
  if plateWidth and S.Usable(casts) then
    local extra = (1 - width) * math.max(0, plateWidth - 2 * inset) / 2
    Anchored(casts, { "BOTTOMLEFT", unitFrame, "BOTTOMLEFT", inset + extra, 0 },
      { "BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -inset - extra, 0 })
  end
  local base = SetupSize("healthBarHeight")
  if base then
    Call(container, "SetHeight", math.max(2, math.floor(base * height + 0.5)))
  end
end

-- After Blizzard's layout: the board's arrangement. Nothing when the unit frame is protected or shows only
-- its name (Blizzard's own name-only layout stays).
local function Layout(state, unitFrame)
  if S.Protected(unitFrame) or NameOnly(unitFrame) then
    return
  end
  local container = S.Child(unitFrame, "HealthBarsContainer")
  local casts = S.Child(unitFrame, "CastBarsContainer")
  local bar = HealthBar(unitFrame)
  if not S.Usable(container) or not S.Usable(bar) then
    return
  end
  SizeBars(state, unitFrame, container, casts)
  -- the bar to the plate's right end (Forever stops it short of the level box, which moves to the left)
  if S.Usable(casts) then
    Place(container, "BOTTOMRIGHT", casts, "TOPRIGHT", 0, SetupSize("castBarToHealthBarSpacing") or 2)
  end
  local auras = S.Child(unitFrame, "AurasFrame")
  for _, key in ipairs({ "CrowdControlListFrame", "LossOfControlFrame" }) do
    Place(S.Child(auras, key), "LEFT", container, "RIGHT", 5, 0)
  end
  -- level badge left of the bar, then the elite icon (and Blizzard's enemy buffs, which follow it)
  local level = LevelFrame(unitFrame)
  local left = container
  if level and Anchored(level, { "RIGHT", container, "LEFT", -5, 0 }) then
    left = level
  end
  Anchored(S.Child(unitFrame, "ClassificationFrame"), { "RIGHT", left, "LEFT", -2, 0 })
  -- name centred above the bar (the health text is ours, inside the bar)
  local name = S.Region(unitFrame, "name")
  state.centred = false
  if name and NameStyle() == "above" then
    local gap = SetupSize("healthBarToNameAboveSpacing") or 2
    state.centred = Anchored(name, { "BOTTOMLEFT", container, "TOPLEFT", 0, gap },
      { "BOTTOMRIGHT", container, "TOPRIGHT", 0, gap })
    Call(name, "SetJustifyH", "CENTER")
  end
  -- raid mark above the debuffs (Blizzard's debuff row sits on the name)
  local raid = S.Child(unitFrame, "RaidTargetFrame")
  local debuffs = S.Child(auras, "DebuffListFrame")
  if S.Usable(debuffs) then
    Anchored(raid, { "BOTTOM", debuffs, "TOP", 0, 2 })
  elseif name then
    Anchored(raid, { "BOTTOM", name, "TOP", 0, 2 })
  end
  PlaceMark(state, unitFrame)
end

-- The width or height changed (Settings, the Edit Mode box): every plate laid out again.
TylesserCodex.RefreshPlateSize = function()
  S.Run(part, function()
    for unitFrame, state in pairs(plates) do
      if S.Usable(unitFrame) then
        Layout(state, unitFrame)
      end
    end
  end)
end

-- Health text -------------------------------------------------------------------------------------------
-- The player's format (Settings, CodexDB.skins.unitText.nameplate): "value" (1,612), "percent" (100%), "both"
-- (1,612 · 100%, the default) or "none"; CodexDB.skins.unitText.short: 1.6K instead of full amounts. Values go
-- into SetFormattedText as the game gives them (a secret amount shows its full digits); the percent is the
-- game's own (UnitHealthPercent, secret-safe). Shown when Blizzard would show its health text.

local TEXT_MODES = { value = true, percent = true, both = true, none = true }

local function TextOptions()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  local options = skins and type(skins.unitText) == "table" and skins.unitText or {}
  local mode = TEXT_MODES[options.nameplate] and options.nameplate or "both"
  return mode, options.short == true
end

-- The amount for "%s", as the unit frames show it: "1,612" when readable, "1.6K" (the game's abbreviation,
-- which takes secrets) when short, else the value itself (a secret shows its full digits, no separator: the
-- secret-safe way; the game's separator function is still tried on it, in case this client's takes secrets).
-- Never compared: the game's helpers return secret strings for secret input, and comparing one (even with
-- "" or nil) is an error, which once left every plate without its text.
local function Amount(value, short)
  if short and AbbreviateNumbers then
    local ok, text = pcall(AbbreviateNumbers, value)
    if ok and (not Readable(text) or type(text) == "string") then
      return text
    end
  end
  if type(BreakUpLargeNumbers) == "function" then
    local ok, text = pcall(BreakUpLargeNumbers, value)
    if ok and (not Readable(text) or type(text) == "string") then
      return text
    end
  end
  return value
end

-- The game's 0-100 health percent, or a readable one worked out here; nil when neither.
local function Percent(unit, current)
  local curve = CurveConstants and CurveConstants.ScaleTo100
  if UnitHealthPercent and curve then
    local ok, percent = pcall(UnitHealthPercent, unit, true, curve)
    if ok and (not Readable(percent) or percent ~= nil) then
      return percent
    end
  end
  if not UnitHealthMax then
    return nil
  end
  local okMax, max = pcall(UnitHealthMax, unit)
  if Readable(current) and type(current) == "number" and okMax and Readable(max) and type(max) == "number" and max > 0 then
    return math.floor(current / max * 100 + 0.5)
  end
end

local function BuildHealthText(state, bar)
  if state.text then
    return
  end
  local text = bar:CreateFontString(nil, "OVERLAY", nil, 2)
  -- centred in the bar, and never past its ends on a narrow plate
  text:SetPoint("LEFT", bar, "LEFT", 2, 0)
  text:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  text:SetWordWrap(false)
  text:SetFont(NUMBER_FONT, SetupSize("healthBarFontHeight") or 10, "")
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  text:SetTextColor(1, 1, 1, 1)
  S.RestyleFont(text, "plates.health")
  state.text = text
end

local function WriteHealthText(unitFrame, text)
  local mode, short = TextOptions()
  local unit = UnitOf(unitFrame)
  local okShow, show = Call(HealthBar(unitFrame), "ShouldTextBeShown")
  if okShow and Readable(show) and show == false then
    mode = "none" -- Blizzard's own rule (name hidden, a simplified plate that isn't the target)
  end
  if mode == "none" or not unit or not UnitHealth then
    text:SetText("")
    return
  end
  local okHealth, current = pcall(UnitHealth, unit)
  if not okHealth then
    text:SetText("")
    return
  end
  local percent
  if mode ~= "value" then
    percent = Percent(unit, current)
  end
  local hasPercent = not Readable(percent) or percent ~= nil
  if mode == "percent" and hasPercent and pcall(text.SetFormattedText, text, "%.0f%%", percent) then
    return
  end
  if mode == "both" and hasPercent
    and pcall(text.SetFormattedText, text, "%s \194\183 %.0f%%", Amount(current, short), percent) then
    return
  end
  if not pcall(text.SetFormattedText, text, "%s", Amount(current, short)) then
    text:SetText("")
  end
end

-- Whatever goes wrong with one unit's values, the plate keeps going (and shows what it can).
function HealthText(unitFrame)
  local state = plates[unitFrame]
  local text = state and state.text
  if not text then
    return
  end
  if not pcall(WriteHealthText, unitFrame, text) then
    pcall(text.SetText, text, "")
  end
end

-- Incoming heals ----------------------------------------------------------------------------------------

-- Blizzard draws them itself when its plate options say so (and the textures exist).
local function BlizzardHeals(unitFrame)
  local options = S.Child(unitFrame, "optionTable")
  local on = options and options.displayHealPrediction
  return Readable(on) and on == true and S.IsRegion(S.Child(unitFrame, "myHealPrediction")) and true or false
end

local function FlatHeals(unitFrame)
  for key, color in pairs({ myHealPrediction = HEAL_MINE, otherHealPrediction = HEAL_OTHER }) do
    local texture = S.Region(unitFrame, key) or S.Region(HealthBar(unitFrame), key)
    if texture then
      Call(texture, "SetTexture", WHITE)
      Call(texture, "SetVertexColor", color[1], color[2], color[3], color[4])
    end
  end
end

-- Our heal bar: a StatusBar the width of the health bar, starting at the health fill's right end, clipped
-- to the health bar. Values go in as the game gives them.
local function BuildHeal(state, bar, fill)
  if state.heal then
    return state.heal
  end
  local clip = CreateFrame("Frame", nil, bar)
  clip:SetAllPoints(bar)
  clip:SetClipsChildren(true)
  clip:EnableMouse(false)
  local heal = CreateFrame("StatusBar", nil, clip)
  heal:SetStatusBarTexture(WHITE)
  heal:SetStatusBarColor(HEAL_MINE[1], HEAL_MINE[2], HEAL_MINE[3], HEAL_MINE[4])
  heal:SetMinMaxValues(0, 1)
  heal:SetValue(0)
  heal:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
  heal:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
  local ok, width = Call(bar, "GetWidth")
  heal:SetWidth(ok and Number(width) or 100)
  clip:SetScript("OnSizeChanged", function(_, w)
    if Number(w) then
      heal:SetWidth(w)
    end
  end)
  state.clip, state.heal = clip, heal
  return heal
end

local function UpdateHeal(state, unit)
  local heal = state.heal
  if not heal or not unit then
    return
  end
  if not (UnitHealthMax and pcall(function()
    heal:SetMinMaxValues(0, UnitHealthMax(unit))
  end)) then
    heal:SetMinMaxValues(0, 1)
  end
  if healCalc and UnitGetDetailedHealPrediction and pcall(UnitGetDetailedHealPrediction, unit, "player", healCalc) then
    local ok, amount = Call(healCalc, "GetIncomingHeals")
    if ok and pcall(heal.SetValue, heal, amount) then
      return
    end
  end
  if not (UnitGetIncomingHeals and pcall(function()
    heal:SetValue(UnitGetIncomingHeals(unit))
  end)) then
    heal:SetValue(0)
  end
end

local function Heals(state, unitFrame, bar, fill)
  if BlizzardHeals(unitFrame) then
    FlatHeals(unitFrame)
    if state.clip then
      state.clip:Hide()
    end
    return
  end
  if not fill then
    return
  end
  BuildHeal(state, bar, fill)
  state.clip:Show()
  UpdateHeal(state, UnitOf(unitFrame))
end

-- One plate ---------------------------------------------------------------------------------------------

-- After every Blizzard layout: its art off again, our fill, fonts and layout back.
local function Restyle(unitFrame)
  local state = plates[unitFrame]
  if not state then
    return
  end
  local bar = HealthBar(unitFrame)
  local fill
  if S.Usable(bar) then
    BuildHealth(state, bar)
    fill = FlatFill(bar)
    Kill(S.Child(bar, "bgTexture"))
    Kill(S.Child(bar, "selectedBorder"))
    local size = SetupSize("healthBarFontHeight")
    for _, key in ipairs({ "Text", "LeftText", "RightText" }) do
      Kill(S.Child(bar, key)) -- ours instead (the player's format), so they never show twice
    end
    BuildHealthText(state, bar)
    Text(S.Region(unitFrame, "name"), size)
    S.RestyleFont(S.Region(unitFrame, "name"), "plates.name")
    BarColor(unitFrame)
  end
  local cast = CastBar(unitFrame)
  if S.Usable(cast) then
    BuildCast(state, cast)
    RestyleCast(cast)
  end
  for _, key in ipairs(LEVEL_FRAMES) do
    StyleLevel(state, S.Child(unitFrame, key))
  end
  Layout(state, unitFrame)
  PaintSelection(unitFrame)
  HealthText(unitFrame)
  if S.Usable(bar) then
    Heals(state, unitFrame, bar, fill)
  end
end

-- A plate's unit frame: hooked once, restyled on every unit it gets.
local function Style(unitFrame)
  if not S.Usable(unitFrame) or not S.Child(unitFrame, "HealthBarsContainer") then
    return
  end
  local state = plates[unitFrame]
  if not state then
    state = {}
    plates[unitFrame] = state
    state.mark = CreateFrame("Frame", nil, unitFrame)
    state.mark:SetSize(12, 16)
    state.mark:EnableMouse(false)
    S.HookMethod(unitFrame, "UpdateAnchors", Restyle)
    local bar = HealthBar(unitFrame)
    if S.Usable(bar) then
      S.HookMethod(bar, "UpdateSelectionBorder", function()
        PaintSelection(unitFrame)
      end)
      S.HookMethod(bar, "UpdateTextDisplay", function()
        HealthText(unitFrame)
      end)
    end
    local auras = S.Child(unitFrame, "AurasFrame")
    if S.Usable(auras) then
      S.HookMethod(auras, "RefreshList", function(_, list)
        StyleAuraList(list)
      end)
      S.HookMethod(auras, "RefreshLossOfControl", function(self)
        StyleAura(S.Child(self, "LossOfControlFrame", "AuraItemFrame"))
      end)
    end
  end
  state.selected = nil -- a new unit: paint the selection afresh
  Restyle(unitFrame)
  StyleAuras(S.Child(unitFrame, "AurasFrame"))
end

local function PlateOf(unit)
  if not (Readable(unit) and type(unit) == "string" and unit:find("^nameplate")) then
    return
  end
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return
  end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if ok and S.Usable(plate) then
    return plate
  end
end

local function StylePlate(plate, retry)
  local unitFrame = S.Child(plate, "UnitFrame")
  if unitFrame then
    Style(unitFrame)
  elseif retry then
    -- Blizzard hands the plate its unit frame in its own handler of the same event
    C_Timer.After(0, function()
      S.Run(part, StylePlate, plate, false)
    end)
  end
end

local function AllPlates(fn)
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then
    return
  end
  local ok, list = pcall(C_NamePlate.GetNamePlates)
  for _, plate in ipairs(ok and type(list) == "table" and list or {}) do
    if S.Usable(plate) then
      fn(plate)
    end
  end
end

local repaintQueued = false
local function RepaintSoon()
  if repaintQueued then
    return
  end
  repaintQueued = true
  -- after Blizzard's plates have taken the new target
  C_Timer.After(0, function()
    repaintQueued = false
    S.Run(part, AllPlates, function(plate)
      local unitFrame = S.Child(plate, "UnitFrame")
      if unitFrame and plates[unitFrame] then
        PaintSelection(unitFrame)
      end
    end)
  end)
end

local function OnEvent(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then
    local plate = PlateOf(unit)
    if plate then
      StylePlate(plate, true)
    end
  elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
    RepaintSoon()
  else
    local plate = PlateOf(unit)
    local unitFrame = plate and S.Child(plate, "UnitFrame")
    local state = unitFrame and plates[unitFrame]
    if not state then
      return
    end
    if event == "UNIT_HEALTH" then
      HealthText(unitFrame)
    elseif state.heal and state.clip:IsShown() then -- heal prediction (max health read again each time)
      UpdateHeal(state, unit)
    end
  end
end

-- The quest mark's spot on a plate, for Modules/Highlight's "!": region, point, relPoint, x, y (it does
-- SetPoint(point, region, relPoint, x, y)); nil when the plate isn't ours. Just left of the name's text, clear
-- of the level badge (left of the bar) and the raid mark (above the debuffs).
function S.NameplateMarkAnchor(plate)
  local unitFrame = S.Child(plate, "UnitFrame")
  local state = unitFrame and plates[unitFrame]
  if state and state.mark then
    return state.mark, "RIGHT", "RIGHT", 0, 0
  end
end

-- Settings changed the nameplate text format: every plate's text again, now.
local function RefreshText()
  S.Run(part, AllPlates, function(plate)
    local unitFrame = S.Child(plate, "UnitFrame")
    if unitFrame and plates[unitFrame] then
      HealthText(unitFrame)
    end
  end)
end

-- Edit Mode: a sample plate to size them (the nameplates have no Edit Mode system of their own on Forever).
-- Mouse wheel = width, Shift + mouse wheel = height, Shift + right-click = the game's size again.
local sizer
local SIZE_STEP = 0.05

local function SetPlateSize(key, value)
  CodexDB.skins = CodexDB.skins or {}
  local field = key == "width" and "plateWidth" or "plateHeight"
  if value then
    local limits = PLATE_LIMITS[key]
    value = math.floor(math.max(limits[1], math.min(limits[2], value)) / SIZE_STEP + 0.5) * SIZE_STEP
  end
  CodexDB.skins[field] = (value and math.abs(value - 1) > 0.001) and value or nil
  TylesserCodex.RefreshPlateSize()
  if sizer then
    sizer.Fit()
  end
end
TylesserCodex.SetNameplateSize = SetPlateSize

local function SizerText()
  return L["Nameplates  ·  width %d%%  ·  height %d%%"]:format(math.floor(PlateSize("width") * 100 + 0.5),
    math.floor(PlateSize("height") * 100 + 0.5))
end

local function BuildSizer()
  local theme = S.Theme()
  sizer = CreateFrame("Frame", "CodexNameplateSizer", UIParent)
  sizer:SetFrameStrata("DIALOG")
  sizer:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  sizer:SetSize(300, 60)
  sizer:EnableMouse(true)
  sizer:EnableMouseWheel(true)
  local back = sizer:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints(sizer)
  S.SetColor(back, theme.accent, 0.18)
  local label = sizer:CreateFontString(nil, "OVERLAY")
  label:SetFont(NUMBER_FONT, 12, "OUTLINE")
  label:SetPoint("TOP", sizer, "TOP", 0, -6)
  local bar = sizer:CreateTexture(nil, "ARTWORK")
  S.SetColor(bar, { 0.75, 0.25, 0.2 }, 1) -- (never a global name here: HOSTILE is the game's text "Hostile")
  local line = sizer:CreateTexture(nil, "OVERLAY")
  S.SetColor(line, theme.accent, 1)
  line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
  line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  line:SetHeight(1)
  function sizer.Fit()
    local width = 150 * PlateSize("width")
    local height = math.max(2, (SetupSize("healthBarHeight") or 10) * PlateSize("height"))
    bar:ClearAllPoints()
    bar:SetPoint("TOP", label, "BOTTOM", 0, -8)
    bar:SetSize(width, height)
    sizer:SetSize(math.max(300, width + 40), height + 44)
    label:SetText(SizerText())
  end
  sizer:SetScript("OnMouseWheel", function(_, delta)
    S.Run(part, function()
      local key = (IsShiftKeyDown and IsShiftKeyDown()) and "height" or "width"
      SetPlateSize(key, PlateSize(key) + (delta > 0 and SIZE_STEP or -SIZE_STEP))
    end)
  end)
  sizer:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
      S.Run(part, function()
        SetPlateSize("width", nil)
        SetPlateSize("height", nil)
      end)
    end
  end)
  sizer:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Nameplates"])
    GameTooltip:AddLine(L["Mouse wheel: width. Shift + mouse wheel: height."], 1, 1, 1, true)
    GameTooltip:AddLine(L["Shift + right-click: the game's size again. The game's Nameplate Size option (Options > Nameplates) still scales them all."], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)
  sizer:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  sizer:Hide()
end

local function HookPlateEditMode()
  local manager = S.Get("EditModeManagerFrame")
  if not S.Usable(manager) or not S.Once(manager, "nameplates") then
    return
  end
  S.HookScript(manager, "OnShow", function()
    if not sizer then
      BuildSizer()
    end
    sizer.Fit()
    sizer:Show()
  end)
  S.HookScript(manager, "OnHide", function()
    if sizer then
      sizer:Hide()
    end
  end)
end

S.Part("nameplates", function()
  -- a flag only (no part of its own): switching it needs a reload
  round = TylesserCodex.SkinPartOn("roundicons") and true or false
  TylesserCodex.NameplateMarkAnchor = S.NameplateMarkAnchor
  TylesserCodex.RefreshNameplateText = RefreshText
  -- Unit frames > Fonts changed a nameplate style: every plate's name and health text again
  if type(TylesserCodex.OnFontStyle) == "function" then
    TylesserCodex.OnFontStyle(function(key)
      if type(key) == "string" and key:find("^plates%.") then
        S.Run(part, AllPlates, function(plate)
          local unitFrame = S.Child(plate, "UnitFrame")
          local state = unitFrame and plates[unitFrame]
          if state then
            S.RestyleFont(S.Region(unitFrame, "name"), "plates.name")
            S.RestyleFont(state.text, "plates.health")
          end
        end)
      end
    end)
  end
  if CreateUnitHealPredictionCalculator then
    local ok, calc = pcall(CreateUnitHealPredictionCalculator)
    healCalc = ok and calc or nil
  end
  -- Blizzard writes the name (and its colour) here: ours again after it, and the mark follows the text
  S.HookGlobal("CompactUnitFrame_UpdateName", function(frame)
    local state = type(frame) == "table" and plates[frame]
    if state then
      local bar = HealthBar(frame)
      NameColor(frame, bar and (Selected(frame, bar)))
      PlaceMark(state, frame)
    end
  end)
  -- max health changed (Blizzard's update for it): the text again
  S.HookGlobal("CompactUnitFrame_UpdateMaxHealth", function(frame)
    if type(frame) == "table" and plates[frame] then
      HealthText(frame)
    end
  end)
  -- Blizzard colours the bar here: friendly players back to their class colour
  S.HookGlobal("CompactUnitFrame_UpdateHealthColor", function(frame)
    if type(frame) == "table" and plates[frame] then
      BarColor(frame)
    end
  end)
  local events = CreateFrame("Frame")
  for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "UNIT_HEAL_PREDICTION", "UNIT_HEALTH" }) do
    pcall(events.RegisterEvent, events, event)
  end
  events:SetScript("OnEvent", function(...)
    S.Run(part, OnEvent, ...)
  end)
  -- plates already on screen
  AllPlates(function(plate)
    StylePlate(plate, false)
  end)
  if S.Get("EditModeManagerFrame") then
    HookPlateEditMode()
  else
    S.OnAddOn("Blizzard_EditMode", HookPlateEditMode)
  end
end)
