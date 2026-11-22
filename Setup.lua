local addonName, ns = ...

-- First-run setup (board R3-Setup): five steps, Welcome > Theme > Interface parts > Action bars > Done.
-- It opens once, a few seconds after the first login with Codex (CodexDB.setupDone; installs from before the
-- setup existed have no flag, so they see it once too), never in combat (a fight hides it until it ends), and
-- /codex setup or Profiles > First-run setup > Run setup again bring it back. Every choice is the same setting as in
-- the Codex window's sections, written the same way. CodexDB.setupStep remembers the step while it is open, so a reload (a new
-- theme) comes back to the same step.

local UI = ns.UI
local WIDTH, HEIGHT = 776, 616
local STEPS = { "Welcome", "Theme", "Interface parts", "Action bars", "Done" }
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"

local S = {}
ns.setup = S
S.STEPS = STEPS

local window
local pages = {}
local builders = {}
local pausedForCombat = false
local waitingForCombat = false

local function Theme()
  return ns.Theme()
end

local function Say(text)
  if ns.Say then
    ns.Say(text)
  end
end

local function Wrapped(parent, size, color, width)
  local text = UI.Text(parent, "body", size, color)
  text:SetWidth(width)
  text:SetJustifyH("LEFT")
  return text
end

-- Reload: ReloadUI is protected on Forever, so a secure /reload macro button (parented to UIParent, never
-- to the setup window) is laid over the Done step's Reload button out of combat, as Window.lua does.
local overlay
local function Overlay()
  if overlay or InCombatLockdown() then
    return overlay
  end
  overlay = CreateFrame("Button", "CodexSetupReloadButton", UIParent, "SecureActionButtonTemplate")
  overlay:SetAttribute("type", "macro")
  overlay:SetAttribute("macrotext", "/stopmacro [combat]\n/reload")
  overlay:RegisterForClicks("AnyUp", "AnyDown")
  local glow = overlay:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints()
  UI.SetColor(glow, ns.Theme().button.hover or { 1, 1, 1, 0.12 })
  overlay:Hide()
  -- a fight hides it (still allowed in PLAYER_REGEN_DISABLED); it comes back with the setup
  overlay:RegisterEvent("PLAYER_REGEN_DISABLED")
  overlay:SetScript("OnEvent", function(self)
    self:Hide()
    self:ClearAllPoints()
  end)
  return overlay
end

function S.PlaceOverlay()
  if InCombatLockdown() then
    return
  end
  local target = window and window:IsShown() and window.reloadButton
  if not (target and target:IsVisible()) then
    target = nil
  end
  local button = target and Overlay() or overlay -- made only when the Done step shows its button
  if not button then
    return
  end
  if target then
    button:ClearAllPoints()
    button:SetAllPoints(target)
    button:SetFrameStrata("FULLSCREEN_DIALOG") -- above the setup window (DIALOG)
    button:Show()
  else
    button:Hide()
    button:ClearAllPoints()
  end
end

-- Step 1: welcome ------------------------------------------------------------------------------------------

builders[1] = function(page, width)
  local heading = UI.Heading(page, "Welcome to Codex", 20)
  heading:SetPoint("TOPLEFT")
  local intro = Wrapped(page, 14, "text", width)
  intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
  intro:SetSpacing(3)
  intro:SetText("Codex brings the Tylesser tools together in one addon. Each feature has its own switch "
    .. "in the Codex window; a feature that is off does nothing at all.\n\nThis short setup picks a theme, which parts of "
    .. "the game's interface Codex restyles, and a tidy layout for your action bars. Nothing here is final: "
    .. "/codex opens the window to change all of it later, and /codex setup brings this window back.")
  local label = UI.Section(page, "What's inside")
  label:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -22)
  local list = ns.ModulesInOrder and ns.ModulesInOrder() or ns.moduleList
  local columns = 3
  local columnWidth = math.floor(width / columns)
  local rows = math.ceil(#list / columns)
  page.moduleRows = {}
  for index, module in ipairs(list) do
    local column, row = math.floor((index - 1) / rows), (index - 1) % rows
    local icon = page:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", label, "BOTTOMLEFT", column * columnWidth, -10 - row * 26)
    icon:SetTexture(module.icon)
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local name = UI.Text(page, "body", 13, "text")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetWidth(columnWidth - 34)
    name:SetWordWrap(false)
    name:SetText(module.name)
    page.moduleRows[#page.moduleRows + 1] = { module = module, icon = icon, name = name }
  end
  page.refresh = function()
    local theme = Theme()
    for _, row in ipairs(page.moduleRows) do
      local on = ns.ModuleState(row.module.id) == "on"
      row.name:SetTextColor(UI.Unpack(on and theme.text or theme.muted))
      row.icon:SetDesaturated(not on)
      local shade = on and 1 or 0.6
      row.icon:SetVertexColor(shade, shade, shade)
    end
  end
end

-- Step 2: theme, accent and a live preview -------------------------------------------------------------------

local function PlayerClass()
  local ok, _, class = pcall(UnitClass, "player")
  if ok and type(class) == "string" then
    return class
  end
end

local function ClassColor()
  local class = PlayerClass()
  local color = class and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
  if not color and class and type(RAID_CLASS_COLORS) == "table" then
    color = RAID_CLASS_COLORS[class]
  end
  if type(color) == "table" and type(color.r) == "number" then
    return { color.r, color.g, color.b }
  end
  if type(ns.PlayerClassColor) == "function" then
    local ok, value = pcall(ns.PlayerClassColor)
    if ok and type(value) == "table" and type(value[1]) == "number" then
      return value
    end
  end
end
S.ClassColor = ClassColor

-- A text of the scene. On a light preview (Dawn) the game's colours (white item name, green loot, yellow money)
-- are darkened as the game's interface darkens them (ns.GameColor on the panel over the world) and there is no
-- shadow; onBar: white numbers on a bar or an icon, which keep their colour and shadow (as in the game).
local function SceneText(parent, p, size, color, onBar)
  local text = parent:CreateFontString(nil, "OVERLAY")
  if not text:SetFont(p.body or GAME_FONT, size, "") then
    text:SetFont(GAME_FONT, size, "")
  end
  if p.light and not onBar then
    local panel = p.panel[1]
    color = ns.GameColor(color, { light = true, text = p.text, muted = p.muted },
      ns.Blend(panel, panel[4] or 1))
    text:SetShadowOffset(0, 0)
    text:SetShadowColor(0, 0, 0, 0)
  else
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 0.9)
  end
  text:SetTextColor(UI.Unpack(color))
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  return text
end

local function Lines(frame, inset, color, layer)
  local lines = ns.T.Outline(frame, inset, color, 1, layer or "BORDER")
  ns.T.ColorLines(lines, color, color[4])
  return lines
end

-- A box filled like the theme's frames, with its first ring (kept for the accent) and a dark inner one.
local function Hud(parent, p, alpha)
  local box = CreateFrame("Frame", nil, parent)
  local fill = box:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  UI.Gradient(fill, { p.panel[1][1], p.panel[1][2], p.panel[1][3], alpha }, { p.panel[2][1], p.panel[2][2], p.panel[2][3], alpha })
  box.line = Lines(box, 0, p.rings[1])
  Lines(box, 1, p.rings[2] or { 0, 0, 0, 0.5 })
  return box
end

local function Hex(color)
  return ("%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
    math.floor(color[3] * 255 + 0.5))
end

local SCENE_HEIGHT = 392 -- the unit frame, tooltip, bar and chat, with room round them
local SCENE_ICONS = { "Interface\\Icons\\Spell_Holy_HolyBolt", "Interface\\Icons\\Spell_Holy_FlashHeal",
  "Interface\\Icons\\Spell_Holy_SealOfMight", "Interface\\Icons\\Spell_Holy_DevotionAura",
  "Interface\\Icons\\INV_Hammer_04" }

-- The live preview of one theme: unit frame, an item tooltip, an action bar and chat. scene:SetAccent(color)
-- repaints what the accent colours (portrait ring, frame line, level, chosen tab, the "Codex:" label).
local function BuildScene(parent, id)
  -- the scene shows the game's interface (unit frame, tooltip, bar, chat) as the game will: a light theme's own
  -- light panels, or its ink surfaces while "Game interface on dark panels" is on
  local preview = ns.THEME_PREVIEW[id]
  local p = preview.ink and ns.LookOption and ns.LookOption("inkHud") == true and preview.ink or preview
  local scene = CreateFrame("Frame", nil, parent)
  scene:SetAllPoints()
  -- a dusk sky behind the frames: a flat gradient, darker at the top, a little warmer at the bottom
  local world = scene:CreateTexture(nil, "BACKGROUND")
  world:SetAllPoints()
  UI.Gradient(world, { 0.2, 0.14, 0.09 }, { 0.09, 0.07, 0.06 })
  Lines(scene, 0, Theme().divider)
  local accentLines, accentCircles, accentTexts = {}, {}, {}
  local text = p.text or p.bright
  local muted = p.muted or p.divider

  -- unit frame: portrait, name over health and mana, level badge
  local unit = CreateFrame("Frame", nil, scene)
  unit:SetSize(264, 70)
  unit:SetPoint("TOPLEFT", 14, -26) -- the portrait ring reaches 4px above the frame
  local hud = Hud(unit, p, 0.86)
  hud:SetPoint("TOPLEFT", 32, -6)
  hud:SetSize(232, 58)
  accentLines[#accentLines + 1] = hud.line
  scene.name = SceneText(hud, p, 13, p.bright)
  scene.name:SetPoint("TOPLEFT", 38, -5)
  scene.name:SetText((UnitName and UnitName("player")) or "Tylesser")
  local health = hud:CreateTexture(nil, "ARTWORK")
  health:SetPoint("TOPLEFT", 38, -23)
  health:SetPoint("RIGHT", -9, 0)
  health:SetHeight(14)
  UI.Gradient(health, { 0.11, 0.54, 0.11 }, { 0.27, 0.84, 0.27 })
  local healthText = SceneText(hud, p, 10, { 1, 1, 1 }, true)
  healthText:SetPoint("CENTER", health, "CENTER")
  healthText:SetText("2,431 / 2,431")
  local mana = hud:CreateTexture(nil, "ARTWORK")
  mana:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -3)
  mana:SetSize(156, 10)
  UI.Gradient(mana, { 0.11, 0.26, 0.66 }, { 0.29, 0.53, 1 })
  local ring = unit:CreateTexture(nil, "ARTWORK", nil, 1)
  ring:SetTexture(CIRCLE)
  ring:SetSize(70, 70)
  ring:SetPoint("TOPLEFT", -2, 4)
  accentCircles[#accentCircles + 1] = ring
  local edge = unit:CreateTexture(nil, "ARTWORK", nil, 2)
  edge:SetTexture(CIRCLE)
  edge:SetSize(68, 68)
  edge:SetPoint("CENTER", ring)
  edge:SetVertexColor(0, 0, 0, 1)
  -- a plain disc in the theme's slot colour, with the class icon on it
  local portrait = unit:CreateTexture(nil, "ARTWORK", nil, 3)
  portrait:SetSize(66, 66)
  portrait:SetPoint("CENTER", ring)
  portrait:SetTexture(CIRCLE)
  portrait:SetVertexColor(p.panel[1][1] * 0.8, p.panel[1][2] * 0.8, p.panel[1][3] * 0.8)
  local class = PlayerClass()
  if class then
    local icon = unit:CreateTexture(nil, "ARTWORK", nil, 4)
    icon:SetSize(44, 44)
    icon:SetPoint("CENTER", ring)
    local ok = icon.SetAtlas and pcall(icon.SetAtlas, icon, "classicon-" .. class:lower())
    if ok then
      local mask = unit.CreateMaskTexture and unit:CreateMaskTexture()
      if mask and mask.SetTexture and icon.AddMaskTexture then
        mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetSize(66, 66)
        mask:SetPoint("CENTER", ring)
        icon:AddMaskTexture(mask)
      end
    else
      icon:Hide()
    end
  end
  local badge = unit:CreateTexture(nil, "OVERLAY", nil, 1)
  badge:SetTexture(CIRCLE)
  badge:SetSize(24, 24)
  badge:SetPoint("TOPLEFT", -4, -47)
  accentCircles[#accentCircles + 1] = badge
  local badgeFill = unit:CreateTexture(nil, "OVERLAY", nil, 2)
  badgeFill:SetTexture(CIRCLE)
  badgeFill:SetSize(22, 22)
  badgeFill:SetPoint("CENTER", badge)
  badgeFill:SetVertexColor(UI.Unpack(p.panel[2]))
  local level = SceneText(unit, p, 11, p.accent)
  level:SetPoint("CENTER", badgeFill, "CENTER", 0, 0)
  level:SetText(tostring((UnitLevel and UnitLevel("player")) or 49))
  accentTexts[#accentTexts + 1] = level

  -- an item tooltip with Codex's line
  local tip = Hud(scene, p, 0.97)
  tip:SetPoint("TOPLEFT", 14, -124)
  tip:SetSize(262, 82)
  local item = SceneText(tip, p, 13, { 1, 1, 1 })
  item:SetPoint("TOPLEFT", 11, -9)
  item:SetText("Mithril Ore")
  local kind = SceneText(tip, p, 12, text)
  kind:SetPoint("TOPLEFT", item, "BOTTOMLEFT", 0, -3)
  kind:SetText("Trade Goods")
  local rule = tip:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", kind, "BOTTOMLEFT", 0, -6)
  rule:SetPoint("RIGHT", -11, 0)
  rule:SetHeight(1)
  UI.SetColor(rule, p.divider)
  scene.rule = rule
  scene.codexLine = SceneText(tip, p, 12, text)
  scene.codexLine:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -6)

  -- an action bar: five buttons and two see-through empty slots
  local bar = CreateFrame("Frame", nil, scene)
  bar:SetPoint("TOPLEFT", 14, -236)
  bar:SetSize(6 + 7 * 28 + 6 * 4 + 6, 40)
  local barFill = bar:CreateTexture(nil, "BACKGROUND")
  barFill:SetAllPoints()
  UI.Gradient(barFill, p.panel[1], p.panel[2])
  for index, color in ipairs(p.rings) do
    Lines(bar, (index - 1) * 2, color)
  end
  for index = 1, 7 do
    local slot = CreateFrame("Frame", nil, bar)
    slot:SetSize(28, 28)
    slot:SetPoint("LEFT", 6 + (index - 1) * 32, 0)
    if SCENE_ICONS[index] then
      local icon = slot:CreateTexture(nil, "ARTWORK")
      icon:SetPoint("TOPLEFT", 2, -2)
      icon:SetPoint("BOTTOMRIGHT", -2, 2)
      icon:SetTexture(SCENE_ICONS[index])
      if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      Lines(slot, 0, p.rings[1])
      Lines(slot, 1, { 0, 0, 0, 1 })
      local key = SceneText(slot, p, 9, { 0.87, 0.87, 0.87 }, true)
      key:SetPoint("TOPRIGHT", -3, -3)
      key:SetText(tostring(index))
    else
      local empty = slot:CreateTexture(nil, "ARTWORK")
      empty:SetAllPoints()
      UI.SetColor(empty, { 1, 0.93, 0.78, 0.07 })
      Lines(slot, 0, { p.rings[1][1], p.rings[1][2], p.rings[1][3], 0.4 })
    end
  end

  -- chat: two tabs and two lines
  local chat = CreateFrame("Frame", nil, scene)
  chat:SetPoint("TOPLEFT", 14, -302)
  chat:SetSize(262, 74)
  local tabs = {}
  for index, name in ipairs({ "General", "Guild" }) do
    local tab = CreateFrame("Frame", nil, chat)
    tab:SetHeight(20)
    local label = SceneText(tab, p, 11, index == 1 and p.accent or muted)
    label:SetPoint("CENTER")
    label:SetText(name)
    tab:SetWidth(label:GetStringWidth() + 18)
    tab:SetPoint("TOPLEFT", tabs[1] or chat, tabs[1] and "TOPRIGHT" or "TOPLEFT", tabs[1] and 3 or 0, 0)
    local fill = tab:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    if index == 1 then
      UI.Gradient(fill, p.title[1], p.title[2])
      local underline = tab:CreateTexture(nil, "ARTWORK")
      underline:SetPoint("BOTTOMLEFT")
      underline:SetPoint("BOTTOMRIGHT")
      underline:SetHeight(2)
      UI.SetColor(underline, p.accent)
      accentLines[#accentLines + 1] = { underline }
      accentTexts[#accentTexts + 1] = label
    else
      UI.SetColor(fill, { p.panel[1][1], p.panel[1][2], p.panel[1][3], 0.85 })
    end
    tabs[index] = tab
  end
  local log = Hud(chat, p, 0.86)
  log:SetPoint("TOPLEFT", 0, -20)
  log:SetSize(262, 52)
  local loot = SceneText(log, p, 12, { 0.24, 0.77, 0.24 })
  loot:SetPoint("TOPLEFT", 9, -8)
  loot:SetText("You receive loot: [Mithril Ore].")
  local money = SceneText(log, p, 12, { 1, 1, 0 })
  money:SetPoint("TOPLEFT", loot, "BOTTOMLEFT", 0, -4)
  money:SetText("Your share of the loot is 1 Silver, 91 Copper.")

  function scene:SetAccent(class)
    local color = class or p.accent
    local line = class or p.rings[1]
    for _, lines in ipairs(accentLines) do
      ns.T.ColorLines(lines, lines == hud.line and line or color, (lines == hud.line and line or color)[4])
    end
    for _, circle in ipairs(accentCircles) do
      circle:SetVertexColor(UI.Unpack(class or p.titleLine))
    end
    -- texts in the class colour: a readable shade of it on a light preview (as the game's interface draws it)
    local textColor = color
    if class and p.light then
      local panel = p.panel[1]
      textColor = ns.GameColor(class, { light = true, text = p.text, muted = p.muted }, ns.Blend(panel, panel[4] or 1))
    end
    for _, label in ipairs(accentTexts) do
      label:SetTextColor(UI.Unpack(textColor))
    end
    self.name:SetTextColor(UI.Unpack(class and textColor or p.bright))
    self.rule:SetColorTexture(color[1], color[2], color[3], class and 0.6 or (p.divider[4] or 0.5))
    self.codexLine:SetText(("|cff%sCodex:|r 34 on your characters"):format(Hex(textColor)))
    self.accent = class and "class" or "theme"
  end
  scene:SetAccent(nil)
  return scene
end
S.BuildScene = BuildScene

local FONT_NAMES = { runestone = "Cinzel and Friz Quadrata", hearthwood = "IM Fell English SC and Friz Quadrata",
  classic = "Friz Quadrata", slate = "Arial Narrow", dusk = "Inter", obsidian = "Inter",
  onyx = "Inter" }

builders[2] = function(page, width)
  local leftWidth = 420
  local heading = UI.Heading(page, "Pick a theme", 17)
  heading:SetPoint("TOPLEFT")
  local intro = Wrapped(page, 13, "muted", leftWidth)
  intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  intro:SetText("Every window, bar and tooltip Codex restyles follows it. You can change it later on the Look page.")

  local gap = 10
  local perRow = 3 -- six themes: two rows of three
  local rows = math.ceil(#ns.THEMES / perRow)
  local cardWidth = math.floor((leftWidth - gap * (perRow - 1)) / perRow)
  local cardHeight = 150 -- preview 72, name row, three lines of description
  page.cards = {}
  for index, info in ipairs(ns.THEMES) do
    local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
    local card = CreateFrame("Button", nil, page)
    card:SetSize(cardWidth, cardHeight)
    card:SetPoint("TOPLEFT", page, "TOPLEFT", column * (cardWidth + gap), -64 - row * (cardHeight + gap))
    local fill = card:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    UI.SetColor(fill, Theme().light and { 0, 0, 0, 0.035 } or { 0, 0, 0, 0.18 })
    card.selected = UI.Selection(card)
    Lines(card, 0, Theme().divider)
    card.ring = Lines(card, 0, Theme().accent, "OVERLAY")
    local hover = card:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    UI.SetColor(hover, Theme().accent, 0.07)
    local preview = ns.ThemePreview(card, info.id, cardWidth - 16, 72)
    preview:SetPoint("TOP", 0, -8)
    card.dotRing = card:CreateTexture(nil, "ARTWORK")
    card.dotRing:SetTexture(CIRCLE)
    card.dotRing:SetSize(13, 13)
    card.dotRing:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)
    card.dotRing:SetVertexColor(UI.Unpack(Theme().button.line))
    card.dot = card:CreateTexture(nil, "ARTWORK", nil, 1)
    card.dot:SetTexture(CIRCLE)
    card.dot:SetSize(11, 11)
    card.dot:SetPoint("CENTER", card.dotRing)
    local name = UI.Text(card, "body", 14, "bright")
    name:SetPoint("LEFT", card.dotRing, "RIGHT", 6, 0)
    name:SetWidth(cardWidth - 74)
    name:SetWordWrap(false)
    name:SetText(info.name)
    card.tag = UI.Text(card, "body", 11, "accent")
    card.tag:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.tag:SetPoint("BOTTOM", name, "BOTTOM", 0, 0)
    -- the full card width, three lines at most
    local desc = Wrapped(card, 12, "muted", cardWidth - 16)
    desc:SetPoint("TOPLEFT", card.dotRing, "BOTTOMLEFT", 0, -5)
    desc:SetHeight(44)
    if desc.SetMaxLines then
      desc:SetMaxLines(3)
    end
    desc:SetText(info.desc)
    card.id = info.id
    card:SetScript("OnClick", function(self)
      ns.SetTheme(self.id)
      page.refresh()
    end)
    page.cards[info.id] = card
  end

  local accentLabel = UI.Text(page, "body", 13, "text")
  accentLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -64 - rows * (cardHeight + gap) - 6)
  accentLabel:SetText("Accent colour")
  page.accent = ns.Segmented(page, ns.ACCENT_CHOICES, function()
    return ns.LookValue("accent")
  end, function(key)
    ns.SetLookValue("accent", key)
    page.refresh()
  end)
  ns.On("LOOK_CHANGED", function()
    if page:IsShown() then
      page.refresh()
    end
  end)
  page.accent:SetPoint("LEFT", accentLabel, "RIGHT", 12, 0)
  page.note = Wrapped(page, 12, "warn", leftWidth)
  page.note:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -16)

  -- live preview of the picked theme
  local previewX = leftWidth + 20
  local previewWidth = width - previewX
  local previewLabel = UI.Text(page, "body", 12, "muted")
  previewLabel:SetPoint("TOPLEFT", page, "TOPLEFT", previewX, 0)
  previewLabel:SetText("Live preview")
  page.fonts = UI.Text(page, "body", 12, "muted")
  page.fonts:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
  page.fonts:SetJustifyH("RIGHT")
  local stage = CreateFrame("Frame", nil, page)
  stage:SetPoint("TOPLEFT", page, "TOPLEFT", previewX, -20)
  stage:SetSize(previewWidth, SCENE_HEIGHT) -- sized to its content, not to the page
  page.stage = stage
  page.scenes = {}

  page.refresh = function()
    local theme = Theme()
    local picked = ns.db.theme or "runestone"
    for id, card in pairs(page.cards) do
      local on = id == picked
      card.selected:SetShown(on)
      for _, line in ipairs(card.ring) do
        line:SetShown(on)
      end
      card.dot:SetVertexColor(UI.Unpack(on and theme.accent or { 0, 0, 0, 0.7 }))
      card.tag:SetText(on and (theme.id == id and "In use" or "After reload") or "")
    end
    page.accent:Refresh()
    if ns.THEME_PREVIEW[picked] then
      if not page.scenes[picked] then
        page.scenes[picked] = BuildScene(stage, picked)
      end
      for id, scene in pairs(page.scenes) do
        scene:SetShown(id == picked)
      end
      page.scenes[picked]:SetAccent(ns.LookValue("accent") == "class" and ClassColor() or nil)
    end
    page.fonts:SetText(FONT_NAMES[picked] or "")
    local info = ns.ThemeInfo(picked)
    if theme.id ~= picked and info then
      page.note:SetText(("%s shows after a reload (the last step offers one)."):format(info.name))
    else
      page.note:SetText("")
    end
  end
end

-- Step 3: the restyle switch and its parts ---------------------------------------------------------------------

builders[3] = function(page, width)
  local heading = UI.Heading(page, "Interface parts", 17)
  heading:SetPoint("TOPLEFT")
  local intro = Wrapped(page, 13, "muted", width)
  intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  intro:SetText("Codex can restyle the game's own frames in your theme. Edit Mode still decides where they sit. "
    .. "Changes here show after a reload.")
  local skins = UI.Check(page, "Restyle the game's interface with this theme")
  UI.Font(skins.label, "body", 13, "bright")
  skins:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", -2, -12)
  skins:SetScript("OnClick", function(self)
    ns.db.skins.enabled = self:GetChecked() and true or false
    if ns.NeedsReload then
      ns.NeedsReload()
    end
    page.refresh()
  end)
  page.skins = skins
  local overlapName = ns.UIOverlap and ns.UIOverlap()
  local top = -8
  if overlapName then
    local overlapText = Wrapped(page, 12, "warn", width - 24)
    overlapText:SetPoint("TOPLEFT", skins, "BOTTOMLEFT", 24, -4)
    overlapText:SetText(ns.OVERLAP_NOTE:format(overlapName))
    top = -50
  end
  local parts = ns.SKIN_PARTS or {}
  local perColumn = math.ceil(#parts / 2)
  local columnWidth = math.floor((width - 24) / 2)
  page.parts = {}
  for index, part in ipairs(parts) do
    local column, row = math.floor((index - 1) / perColumn), (index - 1) % perColumn
    local check = UI.Check(page, part.name)
    check:SetPoint("TOPLEFT", skins, "BOTTOMLEFT", 22 + column * columnWidth, top - row * 22)
    check:SetHitRectInsets(0, -(columnWidth - 50), 0, 0)
    check.label:SetWidth(columnWidth - 50)
    check.label:SetWordWrap(false)
    check.part = part.id
    check:SetScript("OnClick", function(self)
      ns.db.skins.parts[self.part] = self:GetChecked() and true or false
      if ns.NeedsReload then
        ns.NeedsReload()
      end
    end)
    page.parts[part.id] = check
  end
  page.refresh = function()
    local on = ns.db.skins.enabled and true or false
    skins:SetChecked(on)
    for id, check in pairs(page.parts) do
      check:SetChecked(ns.SkinPartWanted(id))
      check:SetEnabled(on)
      check:SetAlpha(on and 1 or 0.5)
    end
  end
end

-- Step 4: the action bar guide and the spacing check --------------------------------------------------------------

builders[4] = function(page, width)
  local heading = UI.Heading(page, "Action bars", 17)
  heading:SetPoint("TOPLEFT")
  local intro = Wrapped(page, 13, "muted", width)
  intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  intro:SetText("Edit Mode moves the bars; Codex can draw a panel behind each one. These steps give a tidy layout.")
  local panels = UI.Check(page, "Panel behind the action bars")
  UI.Font(panels.label, "body", 13, "bright")
  panels:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", -2, -12)
  panels:SetScript("OnClick", function(self)
    ns.db.skins.parts.barpanels = self:GetChecked() and true or false
    if ns.NeedsReload then
      ns.NeedsReload()
    end
  end)
  page.panels = panels
  local panelsNote = Wrapped(page, 12, "muted", width - 24)
  panelsNote:SetPoint("TOPLEFT", panels, "BOTTOMLEFT", 24, -2)
  local guide = Wrapped(page, 13, "text", width)
  guide:SetPoint("TOPLEFT", panels, "BOTTOMLEFT", 2, -30)
  guide:SetSpacing(4)
  guide:SetText(ns.BAR_GUIDE or "")
  local check = UI.Button(page, 140, 26, "Check spacing")
  check:SetPoint("TOPLEFT", guide, "BOTTOMLEFT", 0, -14)
  local result = Wrapped(page, 12, "good", width)
  result:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -8)
  check:SetScript("OnClick", function()
    local text = ns.BarSpacingText and ns.BarSpacingText() or ""
    result:SetText(text)
    local theme = Theme()
    result:SetTextColor(UI.Unpack(text:find("^All clear") and theme.good or theme.text))
  end)
  page.result = result
  page.checkButton = check
  page.refresh = function()
    local on = ns.db.skins.enabled and true or false
    panels:SetChecked(ns.SkinPartWanted("barpanels"))
    panels:SetEnabled(on)
    panels:SetAlpha(on and 1 or 0.5)
    panelsNote:SetText(on and "One panel per bar, fitted to its buttons. Shows after a reload."
      or "Needs \"Restyle the game's interface\" (the step before).")
  end
end

-- Step 5: done ---------------------------------------------------------------------------------------------------

builders[5] = function(page, width)
  local heading = UI.Heading(page, "All set", 20)
  heading:SetPoint("TOPLEFT")
  local summary = Wrapped(page, 14, "text", width)
  summary:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)
  summary:SetSpacing(5)
  page.summary = summary
  local reload = UI.Button(page, 150, 28, "Reload now")
  reload:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -18)
  -- only reached in combat or when the secure button could not be made: the overlay takes the click
  reload:SetScript("OnClick", function()
    Say(InCombatLockdown() and "type /reload after the fight to apply your changes." or "type /reload to apply your changes.")
  end)
  reload:HookScript("OnShow", S.PlaceOverlay)
  reload:HookScript("OnHide", S.PlaceOverlay)
  window.reloadButton = reload
  local reloadNote = Wrapped(page, 12, "muted", width - 170)
  reloadNote:SetPoint("LEFT", reload, "RIGHT", 12, 0)
  page.reloadNote = reloadNote
  local tipsLabel = UI.Section(page, "Good to know")
  tipsLabel:SetPoint("TOPLEFT", reload, "BOTTOMLEFT", 0, -26)
  local tips = Wrapped(page, 13, "text", width)
  tips:SetPoint("TOPLEFT", tipsLabel, "BOTTOMLEFT", 0, -8)
  tips:SetSpacing(4)
  tips:SetText("/codex opens Codex.\n/codex settings changes anything you picked here.\n"
    .. "/codex profile keeps different settings per character, and shares them as text.\n"
    .. "/codex setup runs this setup again.")
  page.refresh = function()
    local info = ns.ThemeInfo(ns.db.theme) or ns.THEMES[1]
    local lines = {}
    lines[#lines + 1] = ("Theme: %s%s"):format(info.name, Theme().id ~= info.id and " (after a reload)" or "")
    lines[#lines + 1] = ("Accent: %s"):format(ns.LookValue("accent") == "class" and "class colour" or "the theme's")
    if ns.db.skins.enabled then
      local on = 0
      for _, part in ipairs(ns.SKIN_PARTS or {}) do
        if ns.SkinPartWanted(part.id) then
          on = on + 1
        end
      end
      lines[#lines + 1] = ("Game interface: restyled, %d of %d parts"):format(on, #(ns.SKIN_PARTS or {}))
    else
      lines[#lines + 1] = "Game interface: left as the game draws it"
    end
    -- the info bar moves the minimap and buffs out of its way (the user's choice, 2026-11-17); done here too so a
    -- fresh install sees it before the first reload (combat: the module repeats it after the fight)
    local makeRoom = ns.API and ns.API.InfoBarMakeRoom
    if makeRoom and ns.ModuleState and ns.ModuleState("infobar") == "on" then
      local moved = makeRoom()
      if type(moved) == "table" and #moved > 0 then
        lines[#lines + 1] = "Info bar: moved out of its way: " .. table.concat(moved, ", ")
      end
    end
    summary:SetText(table.concat(lines, "\n"))
    reload:SetShown(ns.pendingReload and true or false)
    reloadNote:SetText(ns.pendingReload and "Your choices take effect after a reload." or "")
    S.PlaceOverlay()
  end
end

-- The window --------------------------------------------------------------------------------------------------

local function StepMarker(nav, index, x, width)
  local marker = CreateFrame("Frame", nil, nav)
  marker:SetSize(width, 42)
  marker:SetPoint("TOPLEFT", x, 0)
  if index < #STEPS then
    marker.line = nav:CreateTexture(nil, "BORDER")
    marker.line:SetHeight(1)
    marker.line:SetPoint("LEFT", marker, "TOP", 10, -10)
    marker.line:SetWidth(width - 20)
  end
  marker.ring = marker:CreateTexture(nil, "ARTWORK")
  marker.ring:SetTexture(CIRCLE)
  marker.ring:SetSize(22, 22)
  marker.ring:SetPoint("TOP", 0, 1)
  marker.disc = marker:CreateTexture(nil, "ARTWORK", nil, 1)
  marker.disc:SetTexture(CIRCLE)
  marker.disc:SetSize(20, 20)
  marker.disc:SetPoint("CENTER", marker.ring)
  marker.number = UI.Text(marker, "body", 11)
  marker.number:SetPoint("CENTER", marker.disc, "CENTER", 0, 0)
  marker.number:SetText(tostring(index))
  marker.tick = marker:CreateTexture(nil, "OVERLAY")
  marker.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  marker.tick:SetSize(18, 18)
  marker.tick:SetPoint("CENTER", marker.disc, "CENTER", 1, 0)
  marker.label = UI.Text(marker, "body", 12, "muted")
  marker.label:SetPoint("TOP", marker.disc, "BOTTOM", 0, -5)
  marker.label:SetText(STEPS[index])
  return marker
end

local function UpdateNav(step)
  local theme = Theme()
  local dark = { theme.panel.from[1], theme.panel.from[2], theme.panel.from[3], 1 } -- opaque: the ring sits behind
  for index, marker in ipairs(window.markers) do
    local done, current = index < step, index == step
    marker.ring:SetVertexColor(UI.Unpack(current and theme.accent or theme.button.line))
    marker.disc:SetVertexColor(UI.Unpack(current and theme.accent or dark))
    marker.number:SetShown(not done)
    marker.number:SetTextColor(UI.Unpack(current and { 0.07, 0.05, 0.02 } or theme.muted))
    marker.tick:SetShown(done)
    marker.tick:SetVertexColor(UI.Unpack(theme.accent))
    marker.label:SetTextColor(UI.Unpack(current and theme.bright or (done and theme.text or theme.muted)))
    if marker.line then
      UI.SetColor(marker.line, done and theme.titlebar.line or theme.divider)
    end
  end
end

function S.Go(step)
  step = math.max(1, math.min(#STEPS, math.floor(tonumber(step) or 1)))
  window.step = step
  ns.db.setupStep = step
  if step == #STEPS then
    ns.db.setupDone = true -- reaching the end counts, even when the reload button closes it
  end
  for index, page in pairs(pages) do
    page:SetShown(index == step)
  end
  local page = pages[step]
  if not page then
    page = CreateFrame("Frame", nil, window.content)
    page:SetAllPoints()
    pages[step] = page
    local ok, err = pcall(builders[step], page, WIDTH - 40)
    if not ok then
      geterrorhandler()(err)
    end
  end
  page:Show()
  if page.refresh then
    page.refresh()
  end
  UpdateNav(step)
  window.stepText:SetText(("Step %d of %d"):format(step, #STEPS))
  window.back:SetEnabled(step > 1)
  window.skip:SetShown(step < #STEPS)
  window.next:SetText(step < #STEPS and ("Next: " .. STEPS[step + 1]:lower()) or "Finish")
  S.PlaceOverlay()
end

local function CreateWindow()
  if window then
    return window
  end
  local theme = Theme()
  window = CreateFrame("Frame", "CodexSetup", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:Hide()
  UI.Panel(window)
  table.insert(UISpecialFrames, "CodexSetup")

  -- title bar, as on the Codex window
  local barHeight = theme.titlebar.height or 30
  local bar = CreateFrame("Frame", nil, window)
  bar:SetPoint("TOPLEFT", 5, -5)
  bar:SetPoint("TOPRIGHT", -5, -5)
  bar:SetHeight(barHeight)
  local barFill = bar:CreateTexture(nil, "BACKGROUND")
  barFill:SetAllPoints()
  UI.Gradient(barFill, theme.titlebar.from, theme.titlebar.to)
  local barLine = bar:CreateTexture(nil, "BORDER")
  barLine:SetPoint("BOTTOMLEFT")
  barLine:SetPoint("BOTTOMRIGHT")
  barLine:SetHeight(1)
  UI.SetColor(barLine, theme.titlebar.line)
  local emblem = bar:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(ns.T.EMBLEM)
  emblem:SetSize(barHeight - 6, barHeight - 6)
  emblem:SetPoint("LEFT", 6, 0)
  local title = UI.Text(bar, "head", 15, "titleText")
  title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  title:SetText(theme.titlebar.upper and "CODEX SETUP" or "Codex setup")
  local close = UI.CloseButton(window)
  close:SetParent(bar)
  close:SetPoint("RIGHT", -4, 0)

  -- the steps
  local nav = CreateFrame("Frame", nil, window)
  nav:SetPoint("TOPLEFT", 28, -(5 + barHeight + 14))
  nav:SetPoint("TOPRIGHT", -28, -(5 + barHeight + 14))
  nav:SetHeight(42)
  local markerWidth = math.floor((WIDTH - 56) / #STEPS)
  window.markers = {}
  for index = 1, #STEPS do
    window.markers[index] = StepMarker(nav, index, (index - 1) * markerWidth, markerWidth)
  end
  local navRule = UI.Divider(window)
  navRule:SetPoint("TOPLEFT", 20, -(5 + barHeight + 14 + 42 + 12))
  navRule:SetPoint("TOPRIGHT", -20, -(5 + barHeight + 14 + 42 + 12))

  local content = CreateFrame("Frame", nil, window)
  content:SetPoint("TOPLEFT", 20, -(5 + barHeight + 14 + 42 + 12 + 16))
  content:SetPoint("BOTTOMRIGHT", -20, 68)
  window.content = content

  -- footer: Skip setup / Step n of 5 / Back / Next
  local footRule = UI.Divider(window)
  footRule:SetPoint("BOTTOMLEFT", 20, 54)
  footRule:SetPoint("BOTTOMRIGHT", -20, 54)
  local skip = CreateFrame("Button", nil, window)
  skip:SetSize(90, 28)
  skip:SetPoint("BOTTOMLEFT", 20, 13)
  skip.label = UI.Text(skip, "body", 13, "muted")
  skip.label:SetPoint("LEFT", 4, 0)
  skip.label:SetText("Skip setup")
  local underline = skip:CreateTexture(nil, "ARTWORK")
  underline:SetPoint("TOPLEFT", skip.label, "BOTTOMLEFT", 0, -2)
  underline:SetPoint("TOPRIGHT", skip.label, "BOTTOMRIGHT", 0, -2)
  underline:SetHeight(1)
  UI.SetColor(underline, theme.muted, 0.7)
  skip:SetScript("OnEnter", function(self)
    self.label:SetTextColor(UI.Unpack(Theme().text))
  end)
  skip:SetScript("OnLeave", function(self)
    self.label:SetTextColor(UI.Unpack(Theme().muted))
  end)
  skip:SetScript("OnClick", function()
    window:Hide()
  end)
  window.skip = skip
  local nextButton = UI.Button(window, 180, 28, "Next")
  nextButton:SetPoint("BOTTOMRIGHT", -20, 13)
  nextButton:SetScript("OnClick", function()
    if window.step < #STEPS then
      S.Go(window.step + 1)
    else
      window:Hide()
    end
  end)
  window.next = nextButton
  local back = UI.Button(window, 90, 28, "Back")
  back:SetPoint("RIGHT", nextButton, "LEFT", -10, 0)
  back:SetScript("OnClick", function()
    S.Go(window.step - 1)
  end)
  window.back = back
  local stepText = UI.Text(window, "body", 13, "muted")
  stepText:SetPoint("CENTER", window, "BOTTOM", 0, 27)
  window.stepText = stepText

  window:SetScript("OnHide", function()
    if not pausedForCombat then
      ns.db.setupDone = true
      ns.db.setupStep = nil
    end
    S.PlaceOverlay()
  end)
  window:SetScript("OnShow", S.PlaceOverlay)
  -- not in combat: a fight hides it until it ends (checked a few times a second while it is open)
  local since = 0
  window:SetScript("OnUpdate", function(self, elapsed)
    since = since + (elapsed or 0)
    if since < 0.2 then
      return
    end
    since = 0
    if InCombatLockdown() then
      pausedForCombat = true
      self:Hide()
      S.WaitForCombat()
    end
  end)
  ns.On("RELOAD_STATE", function()
    if window:IsShown() and pages[window.step] and pages[window.step].refresh then
      pages[window.step].refresh()
    end
  end)
  ns.setupWindow = window
  return window
end

-- Opens the setup (at a step, default the first). Not in combat. Returns true when it opened.
function ns.ShowSetup(step, quiet)
  if InCombatLockdown() then
    if not quiet then
      Say("the setup opens after the fight.")
    end
    waitingForCombat = true
    S.WaitForCombat()
    return false
  end
  CreateWindow()
  pausedForCombat = false
  waitingForCombat = false
  window:Show()
  S.Go(step or 1)
  return true
end

function ns.HideSetup()
  if window then
    window:Hide()
  end
end

-- Made on first need (never at file load): waits for the loading screen and for the end of a fight.
local watcher
local function Watcher()
  if watcher then
    return watcher
  end
  watcher = CreateFrame("Frame")
  watcher:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then
      if not ns.db.setupDone and not (window and window:IsShown()) then
        ns.ShowSetup(ns.db.setupStep, true)
      end
    elseif pausedForCombat or waitingForCombat then
      local step = window and window.step or ns.db.setupStep
      pausedForCombat = false
      waitingForCombat = false
      ns.ShowSetup(step, true)
    end
  end)
  return watcher
end

function S.WaitForCombat()
  Watcher():RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- At login: once, when the loading screen ends, unless it has been seen.
function ns.MaybeShowSetup()
  if ns.db.setupDone then
    return
  end
  Watcher():RegisterEvent("PLAYER_ENTERING_WORLD")
end
