local addonName, ns = ...
local S = ns.S

-- Quest tracker as the R2-HUD board draws it: a soft HUD panel (no edge) with room round the text, as tall
-- as what is shown (measured again after each of Blizzard's layout passes, never past the screen's bottom).
-- The top header ("All Objectives · 25 tracked") is a 14 px accent heading over a divider; section headers
-- ("Quests 37/40", "Campaign", ...) are 12 px muted headings. Collapse buttons get the theme's small button
-- with "–" / "+". Quest titles keep Blizzard's difficulty colours with a shadow; objectives are light grey,
-- finished ones darker (the theme's body font only where the theme has one). Quest item buttons get a thin
-- ring; Blizzard's quest icons stay. A quest block shows a soft highlight under the mouse.
-- ObjectiveTrackerFrame is never hidden, moved or reparented (its OnHide runs tainted). Everything we draw
-- lives on a frame of ours in the lowest strata (behind the action bars, chat, ...) or is a texture on
-- Blizzard's blocks; item buttons and measuring wait for the end of a fight.

-- Forever (12.x engine): ObjectiveTrackerFrame.Header plus one module frame per section, each with a
-- .Header; the container also lists its modules in .modules. The names below catch modules that are not
-- in that list yet (load order).
local MODULES = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "AchievementObjectiveTracker",
  "ScenarioObjectiveTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker", "ProfessionsRecipeTracker",
  "MonthlyActivitiesObjectiveTracker", "AdventureObjectiveTracker", "InitiativeTasksObjectiveTracker",
  "UIWidgetObjectiveTracker" }
local BUTTON_FONT = "Fonts\\ARIALN.TTF"
-- R2-HUD tracker: padding 0 10 10, title row 14 px heading font in accent over a divider, section
-- headings 12 px heading font muted, counts 12 px muted, objectives #d8d8d8 and finished ones #7f7f7f.
local PAD = { left = 10, right = 10, top = 2, bottom = 10 } -- panel room round the tracker's content
local TITLE_SIZE, SECTION_SIZE, COUNT_SIZE = 14, 12, 12
-- Blizzard's objective greys (OBJECTIVE_TRACKER_COLOR Normal / Complete) -> the board's greys
local NORMAL_GREY, COMPLETE_GREY = 0.8, 0.6
local OBJECTIVE, FINISHED = { 0.85, 0.85, 0.85 }, { 0.5, 0.5, 0.5 }

local tracker, holder, plate, strip
local buttons = {} -- [minimize button] = { owner = module or tracker, label = font string }
local blocks = setmetatable({}, { __mode = "k" }) -- [block] = highlight texture

local function Number(value)
  return type(value) == "number" and (not canaccessvalue or canaccessvalue(value)) and value or nil
end

local function Shadow(text)
  S.TextShadow(text, 1, -1, 0, 0, 0, 1) -- none on a light theme
end

local function Modules()
  local list, seen = {}, {}
  local function Add(module)
    if S.Usable(module) and not seen[module] then
      seen[module] = true
      list[#list + 1] = module
    end
  end
  for _, module in ipairs(S.Child(tracker, "modules") or {}) do
    Add(module)
  end
  for _, module in pairs(S.Child(S.Get("ObjectiveTrackerManager"), "modules") or {}) do
    Add(module)
  end
  for _, name in ipairs(MODULES) do
    Add(S.Get(name))
  end
  return list
end

-- Collapse buttons -----------------------------------------------------------------------------------------

-- Collapsed? Read from the owner (module or tracker) without touching it.
local function IsCollapsed(owner)
  if type(owner) ~= "table" then
    return false
  end
  if type(owner.IsCollapsed) == "function" then
    local ok, collapsed = pcall(owner.IsCollapsed, owner)
    if ok and type(collapsed) == "boolean" then
      return collapsed
    end
  end
  return owner.isCollapsed == true or owner.collapsed == true
end

local function ButtonState(button)
  local look = buttons[button]
  if look then
    look.label:SetText(IsCollapsed(look.owner) and "+" or "\226\128\147") -- "+" or "–"
  end
end

-- Blizzard's collapse button: its art invisible, the theme's small button drawn on it.
local function SkinButton(button, owner)
  if not S.Usable(button) or not S.Once(button, "trackerbutton") then
    return
  end
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local texture = button[getter] and button[getter](button)
    if S.IsRegion(texture) then
      S.Kill(texture)
    end
  end
  S.KillKeys(button, "NormalTexture", "PushedTexture", "HighlightTexture", "Icon")
  local style = S.Theme().button
  S.Plate(button, { from = style.from, to = style.to, rings = { { inset = 0, color = style.line, size = 1 } } },
    { sublevel = -6 })
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(button)
  S.SetColor(hover, style.hover or { 1, 1, 1, 0.1 })
  local label = button:CreateFontString(nil, "OVERLAY")
  label:SetFont(BUTTON_FONT, 14, "")
  label:SetPoint("CENTER", button, "CENTER", 0, 1)
  label:SetTextColor(style.text[1], style.text[2], style.text[3], 1)
  Shadow(label)
  buttons[button] = { owner = owner, label = label }
  ButtonState(button)
  -- the state flips on a click; the layout pass that follows sets it again
  S.HookScript(button, "OnClick", function()
    ButtonState(button)
  end)
end

-- Headers --------------------------------------------------------------------------------------------------

local function HeaderText(header)
  return S.Region(header, "Text") or S.Region(header, "Title")
end

-- The board's sizes: the heading font at `size` (times the theme's heading scale), in `color`.
local function Heading(text, size, color)
  local path, _, flags = text:GetFont()
  if type(path) == "string" then
    text:SetFont(path, size, type(flags) == "string" and flags or "")
  end
  S.Font(text, "head", color)
  Shadow(text)
end

-- The top header: heading font and accent; its divider is drawn on our panel (see BuildPanel).
local function SkinTitle(header)
  if not S.Usable(header) then
    return
  end
  SkinButton(S.Child(header, "MinimizeButton"), tracker)
  if not S.Once(header, "trackerheader") then
    return
  end
  S.KillKeys(header, "Background")
  local text = HeaderText(header)
  if text then
    Heading(text, TITLE_SIZE, "accent")
  end
end

-- A section header: a small muted heading (the board has no line under it).
local function SkinSection(header, owner)
  if not S.Usable(header) then
    return
  end
  SkinButton(S.Child(header, "MinimizeButton"), owner)
  if not S.Once(header, "trackerheader") then
    return
  end
  S.KillKeys(header, "Background")
  local text = HeaderText(header)
  if not text then
    return
  end
  Heading(text, SECTION_SIZE, "muted")
end

-- Quest blocks ---------------------------------------------------------------------------------------------

local function IsGrey(r, g, b, value)
  return math.abs(r - value) < 0.03 and math.abs(g - value) < 0.03 and math.abs(b - value) < 0.03
end

-- Objectives: Blizzard's normal grey -> the board's light grey, its finished grey -> the darker one. Other colours
-- (failed red, Blizzard's own mouse-over highlight) are left as they are.
local function ColorLine(text)
  if not S.IsRegion(text) or not text.GetTextColor then
    return
  end
  local r, g, b = text:GetTextColor()
  r, g, b = Number(r), Number(g), Number(b)
  if not (r and g and b) then
    return
  end
  local theme = S.Theme()
  local objective, finished = OBJECTIVE, FINISHED
  if theme.light then
    objective, finished = theme.text, theme.muted -- on the light panel: the theme's text and muted colours
  end
  local color = IsGrey(r, g, b, NORMAL_GREY) and objective or IsGrey(r, g, b, COMPLETE_GREY) and finished
  if color then
    text:SetTextColor(color[1], color[2], color[3], 1)
  end
end

-- Light theme: Blizzard colours titles (difficulty), objectives and failed lines again on every update: kept
-- readable on the light panel (S.GameText runs after each of its setters; the greys above become text / muted).
local function Readable(text)
  if S.Theme().light then
    S.GameText(text, "hud")
  end
end

-- Quest titles in the theme's colours (the user's request, 2026-11-19): Blizzard colours each title by difficulty
-- (QuestDifficultyColors; QuestDifficultyHighlightColors on mouse-over) and sets it again on every update, so a
-- post hook on the title's SetTextColor maps those colours to the theme's: impossible = bad, very difficult =
-- between bad and warn, difficult = warn, standard = good, trivial = muted, header = accent (mouse-over a little
-- brighter). The meaning stays; the colours are the theme's.
local DIFFICULTY_TOKEN = { impossible = "bad", verydifficult = "orange", difficult = "warn", standard = "good",
  trivial = "muted", header = "accent", disabled = "muted" }
local themedTitles = setmetatable({}, { __mode = "k" })
local mapping = false

local function Near(a, b)
  return math.abs(a[1] - b[1]) < 0.03 and math.abs(a[2] - b[2]) < 0.03 and math.abs(a[3] - b[3]) < 0.03
end

local function ThemeColor(token)
  local theme = S.Theme()
  if token == "orange" then
    local bad, warn = theme.bad, theme.warn
    return { (bad[1] + warn[1]) / 2, (bad[2] + warn[2]) / 2, (bad[3] + warn[3]) / 2 }
  end
  return theme[token]
end

-- The theme colour for a colour Blizzard gave a title, or nil (not a difficulty colour).
local function TitleColor(r, g, b)
  local seen = { r, g, b }
  for _, set in ipairs({ { QuestDifficultyColors, 0 }, { QuestDifficultyHighlightColors, 0.18 } }) do
    local colors, lift = set[1], set[2]
    if type(colors) == "table" then
      for name, color in pairs(colors) do
        local token = DIFFICULTY_TOKEN[name]
        if token and type(color) == "table" and color.r and Near(seen, { color.r, color.g, color.b }) then
          local themed = ThemeColor(token)
          if themed then
            return themed[1] + (1 - themed[1]) * lift, themed[2] + (1 - themed[2]) * lift,
              themed[3] + (1 - themed[3]) * lift
          end
        end
      end
    end
  end
end

local function ThemeTitle(text)
  if mapping or not S.IsRegion(text) or not text.GetTextColor then
    return
  end
  local r, g, b = text:GetTextColor()
  r, g, b = Number(r), Number(g), Number(b)
  if not (r and g and b) then
    return
  end
  local tr, tg, tb = TitleColor(r, g, b)
  if tr then
    mapping = true
    text:SetTextColor(tr, tg, tb, 1)
    mapping = false
  end
end

local function ThemedTitle(text)
  if not S.IsRegion(text) then
    return
  end
  if not themedTitles[text] then
    themedTitles[text] = true
    S.HookMethod(text, "SetTextColor", ThemeTitle)
  end
  ThemeTitle(text)
end

-- The quest bullets (each block's poiButton, ObjectiveTrackerPOIButtonTemplate from Blizzard_POIButton: round art
-- in NormalTexture / PushedTexture / HighlightTexture / Glow and a glyph in Display.Icon, repainted by
-- UpdateButtonStyle) in the theme (the user's request, 2026-11-20): Blizzard's round art made see-through, a disc
-- of ours in the HUD colour with the thin ring in the accent (the selected quest: the bright colour and a soft glow),
-- the glyph tinted: "?" (ready to turn in) in the theme's good colour, "..." in its text colour. Only our own
-- textures and alphas: nothing of Blizzard's is called.
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local RING = "Interface\\AddOns\\Codex\\Modules\\Buffs\\Media\\Ring"
local poiParts = setmetatable({}, { __mode = "k" })

local function Selected(button)
  if type(button.IsSelected) ~= "function" then
    return false
  end
  local ok, on = pcall(button.IsSelected, button)
  return ok and (not canaccessvalue or canaccessvalue(on)) and on == true
end

local function Complete(button)
  local styles = POIButtonUtil and POIButtonUtil.Style
  if not (styles and type(button.GetStyle) == "function") then
    return false
  end
  local ok, style = pcall(button.GetStyle, button)
  return ok and style == styles.QuestComplete
end

local function PaintPoi(button)
  local parts = poiParts[button]
  if not parts then
    return
  end
  for _, region in ipairs({ button:GetRegions() }) do
    if not parts.own[region] and S.IsRegion(region) then
      region:SetAlpha(0)
    end
  end
  local theme = S.Theme()
  local selected = Selected(button)
  parts.ring:SetVertexColor(S.UI.Unpack(selected and theme.bright or theme.accent))
  parts.glow:SetShown(selected)
  local icon = S.Region(S.Child(button, "Display"), "Icon")
  if icon then
    if icon.SetDesaturated then
      icon:SetDesaturated(true)
    end
    local c = Complete(button) and theme.good or theme.text
    icon:SetVertexColor(c[1], c[2], c[3], 1)
  end
end

local function PoiButton(button)
  if not S.Usable(button) then
    return
  end
  if not poiParts[button] then
    local theme = S.Theme()
    local own = {}
    local glow = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(CIRCLE)
    glow:SetPoint("CENTER")
    glow:SetSize(30, 30)
    glow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.3)
    -- a smooth ring: an accent disc with the fill disc on it, both from the 256 px circle (Buff Tracker's ring
    -- texture broke up into dots at this size, the user's screenshot, 2026-11-20)
    local ring = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    ring:SetTexture(CIRCLE)
    ring:SetPoint("CENTER")
    ring:SetSize(22, 22)
    local disc = button:CreateTexture(nil, "BACKGROUND", nil, -5)
    disc:SetTexture(CIRCLE)
    disc:SetPoint("CENTER")
    disc:SetSize(19, 19)
    local fill = theme.hud and theme.hud.fill or theme.panel.from
    disc:SetVertexColor(fill[1], fill[2], fill[3], 1)
    own[glow], own[disc], own[ring] = true, true, true
    poiParts[button] = { glow = glow, disc = disc, ring = ring, own = own }
    S.HookMethod(button, "UpdateButtonStyle", PaintPoi)
    S.HookScript(button, "OnShow", PaintPoi)
  end
  PaintPoi(button)
end

local function BlockLines(block)
  local lines, seen = {}, {}
  local function Add(line)
    local text = S.Region(line, "Text")
    if text and not seen[text] then
      seen[text] = true
      lines[#lines + 1] = text
    end
  end
  for _, line in pairs(S.Child(block, "usedLines") or {}) do
    Add(line)
  end
  if block.GetChildren then
    for _, child in ipairs({ block:GetChildren() }) do
      if S.Usable(child) then
        Add(child)
      end
    end
  end
  return lines
end

local function StyleText(block)
  local body = S.Theme().font.body
  local title = S.Region(block, "HeaderText")
  if title then
    Shadow(title)
    if body then
      S.Font(title, "body", nil, true)
    end
    ThemedTitle(title) -- the theme's difficulty colours (also fine on a light panel)
  end
  for _, text in ipairs(BlockLines(block)) do
    Shadow(text)
    if body then
      S.Font(text, "body", nil, true)
    end
    ColorLine(text)
    Readable(text)
  end
end

-- The quest item button (R2-HUD `roundRingThin`): its frame art off, the icon cropped, a 1-unit black line
-- and a 1-unit line in the slot ring colour round it.
local function ThinRing(button)
  if not S.Usable(button) or not S.Once(button, "trackeritem") then
    return
  end
  local icon = S.IconOf(button)
  if icon and icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  S.SlotArt(button)
  local line = S.Theme().slot.rings[1].color
  S.Outline(button, button, -1, 1, { 0, 0, 0, 1 }, "OVERLAY", 6)
  S.Outline(button, button, -2, 1, line, "OVERLAY", 6)
end

local function ItemButton(block)
  local button = S.Child(block, "ItemButton") or S.Child(block, "itemButton")
  if S.Usable(button) and not S.Done(button, "trackeritem") then
    -- the item button may be secure: textures only, and never in combat
    S.Defer("tracker:item", function()
      ThinRing(button)
    end)
  end
end

-- The whole quest block takes a click, not only its title text. Blizzard's block (ObjectiveTrackerBlockTemplate,
-- Blizzard_ObjectiveTrackerBlock.xml) is a plain frame without mouse; only its HeaderButton (over the title,
-- block level + 1) clicks, and the objective lines (ObjectiveTrackerLineTemplate, hyperlinksEnabled, also
-- block level + 1) sit over the rest. So our click button lies two levels above the block (over the title and
-- the lines) and stops at the block's rightEdgeOffset, where the quest item / group finder buttons are (those
-- are the module's frames at the block's own level, so they stay clickable); the quest map button sits left of
-- the block, outside it. A click calls the block's own OnHeaderClick(mouseButton), which hands it to the
-- module's OnBlockHeaderClick(block, mouseButton): left opens the quest, right is Blizzard's menu, shift / ctrl
-- keep their meaning. Hover runs the block's OnHeaderEnter / OnHeaderLeave (Blizzard's title highlight) and
-- our shade. In combat our button lets the mouse through and Blizzard's title works as before.
local clickFrames = {} -- [block] = our click button

local function Call(object, method, ...)
  if S.InCombat() or type(object) ~= "table" or type(object[method]) ~= "function" then
    return false
  end
  return (pcall(object[method], object, ...))
end

local function BlockClick(block, mouseButton)
  if Call(block, "OnHeaderClick", mouseButton) then
    return true
  end
  -- a block without Blizzard's mixin: its module's handler
  return Call(S.Child(block, "parentModule"), "OnBlockHeaderClick", block, mouseButton)
end

local function ClickMouse(on)
  for _, click in pairs(clickFrames) do
    click:EnableMouse(on)
  end
end

-- After each layout: over the block, left of its right edge frames, above its title and lines.
local function PlaceClick(block)
  local click = clickFrames[block]
  if not click then
    return
  end
  local right = Number(block.rightEdgeOffset) or 0
  click:ClearAllPoints()
  click:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
  click:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", math.min(0, right), 0)
  local level = Number(block.GetFrameLevel and block:GetFrameLevel())
  if level then
    click:SetFrameLevel(level + 2)
  end
end

local function StyleBlock(block)
  if S.Once(block, "trackerblock") then
    local select = S.Theme().select
    local glow = block:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetPoint("TOPLEFT", block, "TOPLEFT", -4, 2)
    glow:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 4, -2)
    S.UI.Gradient(glow, select.to, select.from)
    glow:Hide()
    blocks[block] = glow
    local click = CreateFrame("Button", nil, block)
    click:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    click:EnableMouse(not S.InCombat())
    clickFrames[block] = click
    click:SetScript("OnClick", function(_, mouseButton)
      S.Run("tracker", BlockClick, block, mouseButton)
    end)
    click:SetScript("OnEnter", function()
      glow:Show()
      S.Run("tracker", Call, block, "OnHeaderEnter")
    end)
    click:SetScript("OnLeave", function()
      glow:Hide()
      S.Run("tracker", Call, block, "OnHeaderLeave")
      -- Blizzard put its own colours back as the mouse left
      S.Run("tracker", StyleText, block)
    end)
    -- the title's own hover (in combat, when our button lets the mouse through) shows our shade too
    local header = S.Child(block, "HeaderButton")
    S.HookScript(header, "OnEnter", function()
      glow:Show()
    end)
    S.HookScript(header, "OnLeave", function()
      glow:Hide()
      StyleText(block)
    end)
  end
  PlaceClick(block)
  StyleText(block)
  ItemButton(block)
  PoiButton(S.Child(block, "poiButton"))
end

-- Quest blocks are the frames with a HeaderText, a few levels down each module.
local function StyleBlocks()
  for _, module in ipairs(Modules()) do
    S.Walk(module, 3, function(child)
      if S.Region(child, "HeaderText") then
        StyleBlock(child)
      end
    end)
  end
end

-- Counts ---------------------------------------------------------------------------------------------------
-- "32/40" (quests in the log / the most the log holds) on the Quests heading and "5 tracked" in the title
-- strip, right-aligned before each collapse button. Font strings on frames of ours over the headers.

local counts = {} -- quests = font string, tracked = font string
local countEvents, countPending

-- Real quests in the log (headers and hidden entries left out) and the log's limit.
local function QuestCount()
  local log = C_QuestLog
  if type(log) ~= "table" or not log.GetNumQuestLogEntries or not log.GetInfo then
    return nil
  end
  local entries = Number(log.GetNumQuestLogEntries()) or 0
  local count = 0
  for index = 1, entries do
    local info = log.GetInfo(index)
    if type(info) == "table" and not info.isHeader and not info.isHidden then
      count = count + 1
    end
  end
  local max = log.GetMaxNumQuestsCanAccept and Number(log.GetMaxNumQuestsCanAccept())
  max = max or Number(MAX_QUESTS) or 25
  return count, max
end

local function UpdateCounts()
  countPending = false
  local theme = S.Theme()
  if counts.quests then
    local count, max = QuestCount()
    if count then
      counts.quests:SetText(("%d/%d"):format(count, max))
      local color = count >= max and theme.bad or theme.muted
      counts.quests:SetTextColor(color[1], color[2], color[3], 1)
    else
      counts.quests:SetText("")
    end
  end
  if counts.tracked then
    local watches = C_QuestLog and C_QuestLog.GetNumQuestWatches and Number(C_QuestLog.GetNumQuestWatches())
    counts.tracked:SetText(watches and watches > 0 and ("%d tracked"):format(watches) or "")
  end
end

local function CountsSoon()
  if countPending then
    return
  end
  countPending = true
  C_Timer.After(0.2, function()
    S.Run("tracker", UpdateCounts)
  end)
end

-- A font string of ours over `header`, ending just left of its collapse button.
local function CountText(header, size)
  local over = CreateFrame("Frame", nil, header)
  over:SetAllPoints(header)
  over:SetFrameLevel(header:GetFrameLevel() + 2)
  over:EnableMouse(false)
  local text = over:CreateFontString(nil, "OVERLAY")
  text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
  S.Font(text, "body", "muted", true) -- board: 12 px body text, muted
  Shadow(text)
  local button = S.Child(header, "MinimizeButton")
  if S.Usable(button) then
    text:SetPoint("RIGHT", button, "LEFT", -6, 0)
  else
    text:SetPoint("RIGHT", header, "RIGHT", -6, 0)
  end
  text:SetJustifyH("RIGHT")
  return text
end

local function BuildCounts()
  if S.InCombat() then
    return
  end
  -- (the Quests module may come later than the first pass: looked for again until found)
  local title, quests = S.Child(tracker, "Header"), S.Child(S.Get("QuestObjectiveTracker"), "Header")
  if not counts.quests and S.Usable(quests) then
    counts.quests = CountText(quests, COUNT_SIZE)
  end
  if not counts.tracked and S.Usable(title) then
    counts.tracked = CountText(title, COUNT_SIZE)
  end
  if countEvents then
    return
  end
  countEvents = CreateFrame("Frame")
  for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
    countEvents:RegisterEvent(event)
  end
  countEvents:SetScript("OnEvent", CountsSoon)
  UpdateCounts()
end

local function SkinHeaders()
  SkinTitle(S.Child(tracker, "Header"))
  for _, module in ipairs(Modules()) do
    SkinSection(S.Child(module, "Header"), module)
  end
  for button in pairs(buttons) do
    ButtonState(button)
  end
  BuildCounts()
  CountsSoon()
end

-- Panel ----------------------------------------------------------------------------------------------------

local function BuildPanel()
  local theme = S.Theme()
  local fill = theme.hud.fill
  -- our own frame in the lowest strata, so the panel is behind every other HUD element
  holder = CreateFrame("Frame", nil, tracker)
  holder:SetAllPoints(tracker)
  holder:SetFrameStrata("BACKGROUND")
  holder:SetFrameLevel(1)
  holder:EnableMouse(false)
  -- R2-HUD `hudSoft`: the HUD fill at lower alpha, no edge
  plate = S.Plate(holder, { fill = fill, alpha = S.Look("soft").alpha, rings = {} },
    { left = PAD.left, right = PAD.right, top = PAD.top, bottom = PAD.bottom, topLeft = tracker, bottomRight = tracker })
  -- the divider under the title row
  local header = S.Child(tracker, "Header")
  if S.Usable(header) then
    strip = holder:CreateTexture(nil, "BACKGROUND", nil, -5)
    strip:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    strip:SetPoint("RIGHT", plate.fill, "RIGHT", -PAD.right, 0)
    strip:SetHeight(1)
    S.SetColor(strip, theme.divider)
  end
end

-- Lowest bottom edge of what the tracker shows (nil when nothing can be measured).
local function ContentBottom()
  local lowest
  local nineSlice = S.Child(tracker, "NineSlice")
  local function Consider(frame)
    if not S.Usable(frame) or frame == nineSlice or frame == holder or not frame.IsShown or not frame:IsShown() then
      return
    end
    local bottom = Number(frame.GetBottom and frame:GetBottom())
    local height = Number(frame.GetHeight and frame:GetHeight())
    if bottom and height and height > 1 then
      lowest = lowest and math.min(lowest, bottom) or bottom
    end
  end
  for _, child in ipairs({ tracker:GetChildren() }) do
    Consider(child)
  end
  for _, module in ipairs(Modules()) do
    if module.GetParent and module:GetParent() ~= tracker then
      Consider(module)
    end
  end
  return lowest
end

local function Measure()
  if not plate then
    return
  end
  if S.InCombat() then
    -- measuring is left until after the fight
    S.Defer("tracker:measure", Measure)
    return
  end
  local top = Number(tracker.GetTop and tracker:GetTop())
  local bottom = ContentBottom()
  plate.fill:ClearAllPoints()
  plate.fill:SetPoint("TOPLEFT", tracker, "TOPLEFT", -PAD.left, PAD.top)
  if top and bottom and top > bottom then
    -- a list longer than the screen: the panel stops at the screen's bottom edge
    bottom = math.max(bottom - PAD.bottom, 4)
    plate.fill:SetPoint("RIGHT", tracker, "RIGHT", PAD.right, 0)
    plate.fill:SetHeight(top + PAD.top - bottom)
  else
    plate.fill:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", PAD.right, -PAD.bottom)
  end
end

-- The background can be switched off (Codex window, Quest tracker section: TylesserCodex.TrackerPanelOn).
local function PanelOn()
  local on = TylesserCodex and TylesserCodex.TrackerPanelOn
  if type(on) ~= "function" then
    return true
  end
  local ok, value = pcall(on)
  return not ok or value ~= false
end

local function ShowPanel()
  if holder then
    holder:SetShown(PanelOn())
  end
end
TylesserCodex.SetTrackerPanel = ShowPanel

local pending = false
local function Update()
  SkinHeaders()
  if pending then
    return
  end
  pending = true
  -- after Blizzard's layout has finished this frame
  C_Timer.After(0, function()
    pending = false
    S.Run("tracker", StyleBlocks)
    S.Run("tracker", Measure)
  end)
end

S.Part("tracker", function()
  tracker = S.Get("ObjectiveTrackerFrame")
  if not S.Usable(tracker) then
    return
  end
  if S.Once(tracker, "tracker") then
    S.Kill(S.Child(tracker, "NineSlice"))
    -- Edit Mode's background opacity sets Blizzard's own tracker background again
    -- (ObjectiveTrackerContainerMixin:SetBackgroundAlpha -> NineSlice:SetAlpha), which showed through with our
    -- panel switched off (the user's screenshot, 2026-11-19)
    S.HookMethod(tracker, "SetBackgroundAlpha", function(self)
      S.Kill(S.Child(self, "NineSlice"))
    end)
    S.Kill(S.Region(tracker, "Background"))
    BuildPanel()
    ShowPanel()
  end
  Update()
  -- the click frames let the mouse through while fighting (their call would be refused)
  local combat = CreateFrame("Frame")
  combat:RegisterEvent("PLAYER_REGEN_DISABLED")
  combat:RegisterEvent("PLAYER_REGEN_ENABLED")
  combat:SetScript("OnEvent", function(_, event)
    ClickMouse(event == "PLAYER_REGEN_ENABLED")
  end)
  -- Blizzard's layout passes: the container, the manager and each module; collapsing a section
  S.HookMethod(tracker, "Update", Update)
  S.HookMethod(tracker, "SetCollapsed", Update)
  S.HookMethod(S.Get("ObjectiveTrackerManager"), "UpdateAll", Update)
  for _, module in ipairs(Modules()) do
    S.HookMethod(module, "SetCollapsed", Update)
    S.HookMethod(module, "Update", Update)
    -- each block right after Blizzard has laid it out (its height and right edge frames are known then)
    S.HookMethod(module, "LayoutBlock", function(_, block)
      if S.Usable(block) and S.Region(block, "HeaderText") then
        StyleBlock(block)
      end
    end)
  end
  S.HookScript(tracker, "OnShow", Update)
end)
