local addonName, ns = ...
local S = ns.S

-- Group loot rolls (board R3-Polish "Loot roll window"). Blizzard's roll frames (GroupLootFrame1-4, made at
-- load; GroupLootContainer stacks them upward from the bottom of the screen) keep their place, their buttons
-- and all of the roll logic: only the look changes.
-- * Panel: Blizzard's toast art made invisible, the theme panel and its rings instead (no corner pieces).
-- * Item: the icon cropped, Blizzard's quality border off, a ring of ours just outside it (black, then the
--   item's quality colour). Quality shows on the ring and the name colour only, never as a glow.
-- * Name: Blizzard colours it by quality; it only gets the theme's body font.
-- * Need / Greed / Pass (and Disenchant / Transmog where the client has them): a theme button plate behind
--   each; Blizzard's glyph art off and the same glyph drawn by us, greyed and tinted in the button text colour
--   (muted while Blizzard has the button disabled); a hover tint.
-- * Timer: Blizzard's bar made invisible; a slim bar of ours (4 units, accent fill, dark back, black line)
--   on its centre line copies its range and value through post-hooks.
-- Frame names from FlareUI (MIT, Modules/LootRolls.lua, Movers.lua); the code is ours. Nothing here is
-- protected; building waits for the end of a fight like every part, later updates only recolour.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BUTTON_KEYS = { "NeedButton", "GreedButton", "DisenchantButton", "TransmogButton", "PassButton" }
local PLATE_INSET = 3 -- the button plate sits this far inside Blizzard's (32 unit) button: 26 units, as the board
local GLYPH_INSET = 7
local BAR_HEIGHT = 4

local rolls = setmetatable({}, { __mode = "k" }) -- [roll frame] = { ring = lines, line = colour, bar = our bar }
local glyphs = setmetatable({}, { __mode = "k" }) -- [button] = our glyph texture

-- Values Blizzard may hand out as secret: only plain ones are used.
local function Open(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- frame.key, or the older global name (GroupLootFrame1Timer, ...).
local function Part(frame, key)
  local child = S.Child(frame, key)
  if child then
    return child
  end
  local name = S.Name(frame)
  return name and S.Get(name .. key) or nil
end

local function Textures(frame, except)
  local list = {}
  if S.Usable(frame) and frame.GetRegions then
    for _, region in ipairs({ frame:GetRegions() }) do
      if region ~= except and S.IsRegion(region) and region:GetObjectType() == "Texture" then
        list[#list + 1] = region
      end
    end
  end
  return list
end

-- The item's quality colour, from the roll's own item info.
local function QualityColor(frame)
  local id = frame.rollID
  if not (Open(id) and type(id) == "number" and GetLootRollItemInfo) then
    return nil
  end
  local ok, _, _, _, quality = pcall(GetLootRollItemInfo, id)
  if not ok or not Open(quality) or type(quality) ~= "number" then
    return nil
  end
  if C_Item and C_Item.GetItemQualityColor then
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
      return { r, g, b, 1 }
    end
  end
  local color = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[quality]
  if type(color) == "table" and type(color.r) == "number" then
    return { color.r, color.g, color.b, 1 }
  end
end

-- Item -------------------------------------------------------------------------------------------------------

local function SkinIcon(frame, mine)
  local holder = Part(frame, "IconFrame")
  local icon = holder and (S.Region(holder, "Icon") or S.IconOf(holder)) or Part(frame, "IconFrameIcon")
  if not S.IsRegion(icon) then
    return
  end
  local owner = S.Usable(holder) and holder or frame
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  -- Blizzard's quality border and any other art round the icon
  for _, texture in ipairs(Textures(holder, icon)) do
    S.Kill(texture)
  end
  local back = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
  back:SetAllPoints(icon)
  S.SetColor(back, S.Theme().slot.fill)
  S.Outline(owner, icon, -1, 1, { 0, 0, 0, 1 }, "OVERLAY", 6)
  mine.ring = S.Outline(owner, icon, -2, 1, mine.line, "OVERLAY", 6)
end

-- Buttons ----------------------------------------------------------------------------------------------------

-- The glyph Blizzard shows on a button: its atlas, else its file.
local function GlyphOf(button)
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if not S.IsRegion(normal) then
    return nil
  end
  local atlas = normal.GetAtlas and normal:GetAtlas()
  if type(atlas) == "string" and atlas ~= "" and Open(atlas) then
    return "atlas", atlas
  end
  local file = normal.GetTexture and normal:GetTexture()
  if file ~= nil and Open(file) then
    return "file", file
  end
end

local function GlyphState(button)
  local glyph = glyphs[button]
  if not glyph then
    return
  end
  local style = S.Theme().button
  local enabled = not button.IsEnabled or button:IsEnabled()
  local c = enabled and style.text or S.Theme().muted
  glyph:SetVertexColor(c[1], c[2], c[3], enabled and 1 or 0.6)
end

local function SkinButton(button)
  if not S.Usable(button) or not S.Once(button, "lootrollbutton") then
    return
  end
  local kind = button:GetObjectType()
  if kind ~= "Button" and kind ~= "CheckButton" then
    return
  end
  local style = S.Theme().button
  local glyphKind, art = GlyphOf(button)
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    if type(button[getter]) == "function" then
      S.Kill(button[getter](button))
    end
  end
  local plate = S.Plate(button, { from = style.from, to = style.to, rings = { { inset = 0, color = style.line, size = 1 } } },
    { left = -PLATE_INSET, right = -PLATE_INSET, top = -PLATE_INSET, bottom = -PLATE_INSET })
  if glyphKind then
    local glyph = button:CreateTexture(nil, "ARTWORK", nil, 7)
    glyph:SetPoint("TOPLEFT", button, "TOPLEFT", GLYPH_INSET, -GLYPH_INSET)
    glyph:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -GLYPH_INSET, GLYPH_INSET)
    if glyphKind == "atlas" then
      glyph:SetAtlas(art)
    else
      glyph:SetTexture(art)
    end
    if glyph.SetDesaturated then
      glyph:SetDesaturated(true)
    end
    glyphs[button] = glyph
  end
  if style.hover then
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(plate.fill)
    S.SetColor(hover, style.hover)
  end
  S.HookScript(button, "OnEnable", GlyphState)
  S.HookScript(button, "OnDisable", GlyphState)
  GlyphState(button)
end

-- Timer ------------------------------------------------------------------------------------------------------

-- Blizzard's range and value onto our bar (passed straight through, never compared).
local function Follow(timer, bar)
  if not S.Usable(timer) or not bar then
    return
  end
  if timer.GetMinMaxValues then
    local low, high = timer:GetMinMaxValues()
    if low and high then
      bar:SetMinMaxValues(low, high)
    end
  end
  if timer.GetValue then
    local value = timer:GetValue()
    if value then
      bar:SetValue(value)
    end
  end
end

local function SkinTimer(frame, mine)
  local timer = Part(frame, "Timer")
  if not S.Usable(timer) or S.Protected(timer) then
    return
  end
  local theme = S.Theme()
  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetPoint("LEFT", timer, "LEFT", 1, 0)
  bar:SetPoint("RIGHT", timer, "RIGHT", -1, 0)
  bar:SetHeight(BAR_HEIGHT)
  bar:EnableMouse(false)
  bar:SetStatusBarTexture(WHITE)
  local accent = theme.accent
  bar:SetStatusBarColor(accent[1], accent[2], accent[3], 1)
  local back = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  back:SetAllPoints(bar)
  local fill = theme.slot.fill
  S.SetColor(back, { fill[1], fill[2], fill[3], 0.85 })
  S.Outline(bar, bar, -1, 1, { 0, 0, 0, 1 }, "BACKGROUND", -7)
  mine.bar = bar
  S.Kill(timer)
  S.HookMethod(timer, "SetMinMaxValues", function(_, low, high)
    if low and high then
      bar:SetMinMaxValues(low, high)
    end
  end)
  S.HookMethod(timer, "SetValue", function(_, value)
    if value then
      bar:SetValue(value)
    end
  end)
  Follow(timer, bar)
end

-- Roll frame -------------------------------------------------------------------------------------------------

-- Each time Blizzard shows a roll: the ring in the new item's quality colour, the bar on its time.
local function Refresh(frame)
  local mine = rolls[frame]
  if not mine then
    return
  end
  local color = QualityColor(frame) or mine.line
  for _, line in ipairs(mine.ring or {}) do
    S.SetColor(line, color)
  end
  Follow(Part(frame, "Timer"), mine.bar)
end

local function SkinRoll(frame)
  if not S.Usable(frame) or rolls[frame] or S.Protected(frame) then
    return
  end
  local theme = S.Theme()
  local mine = { line = S.LineColor(theme.slot.rings) }
  rolls[frame] = mine
  -- Blizzard's toast background and border
  for _, texture in ipairs(Textures(frame)) do
    S.Kill(texture)
  end
  S.Kill(S.Child(frame, "NineSlice"))
  S.Plate(frame, "panel")
  SkinIcon(frame, mine)
  local name = Part(frame, "Name")
  if S.IsRegion(name) then
    S.Font(name, "body")
    S.GameText(name) -- light theme: the item's quality colour in the theme's readable shade, after every roll
  end
  local container = Part(frame, "LootButtonContainer")
  for _, key in ipairs(BUTTON_KEYS) do
    SkinButton(Part(container, key) or Part(frame, key))
  end
  SkinTimer(frame, mine)
  S.HookScript(frame, "OnShow", Refresh)
  Refresh(frame)
end

S.Part("lootroll", function()
  local count = type(NUM_GROUP_LOOT_FRAMES) == "number" and NUM_GROUP_LOOT_FRAMES or 4
  for index = 1, count do
    SkinRoll(S.Get("GroupLootFrame" .. index))
  end
  -- any roll frame the container takes on later (a client that makes them as needed)
  S.HookGlobal("GroupLootContainer_AddFrame", function(_, frame)
    if S.Usable(frame) and not rolls[frame] then
      S.Defer(nil, function()
        SkinRoll(frame)
      end)
    end
  end)
end)
