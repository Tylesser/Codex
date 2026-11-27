local addonName, ns = ...
local S = ns.S

-- Tooltips: the pieces of Blizzard's NineSlice border and background made invisible (alpha only), the theme's
-- panel, rings and small corners drawn as textures of that NineSlice frame, so they show and hide with it
-- (an embedded tooltip has its NineSlice hidden and so shows no panel of its own). Headings use the theme's
-- heading font and the lines its body font, through the shared font objects. Item quality shows only in the
-- name's colour (Blizzard's; on a light theme the theme's readable quality colour, ReadableLines), never on the
-- ring (board R2-Tooltips). The comparison tooltips' "Equipped" /
-- "Equipped with" tabs get the title-bar look. TylesserCodex.TooltipSection(tooltip, title) adds a section
-- heading (small heading-font label + thin rule) for the Codex modules' tooltip blocks.
--
-- Forever taint rules (FlareUI Tooltips.lua): never SetBackdrop / SetPadding; never write to the health bar
-- (GameTooltipStatusBar), so it is left exactly as Blizzard draws it; a forbidden tooltip, or one whose
-- width or a child's widget count is a secret value, is not touched at all. Blizzard re-lays out the
-- NineSlice (SharedTooltip_SetBackdropStyle): the pieces are made invisible again after it.

-- Tooltips that exist from the start or come with Blizzard's load-on-demand addons. Any other tooltip is
-- picked up the first time Blizzard styles it.
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1",
  "ItemRefShoppingTooltip2", "EmbeddedItemTooltip", "FriendsTooltip", "AuraButtonTooltip", "SmallTextTooltip",
  "GameSmallHeaderTooltip", "NamePlateTooltip", "ReputationParagonTooltip", "QuestScrollFrame.StoryTooltip",
  "QuestScrollFrame.CampaignTooltip" }

local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
  "LeftEdge", "RightEdge", "Center" }

local plates = setmetatable({}, { __mode = "k" }) -- [tooltip] = our plate (textures of its NineSlice)
local waits = setmetatable({}, { __mode = "k" }) -- [tooltip] = its key while its build waits for the fight's end

-- Secret values (Forever): a value we may not read, compare or do maths with.
local function Secret(value)
  if issecretvalue then
    return issecretvalue(value) and true or false
  end
  if canaccessvalue then
    return not canaccessvalue(value)
  end
  return false
end

local function SecretWidgets(...)
  for index = 1, select("#", ...) do
    local child = select(index, ...)
    if type(child) == "table" and Secret(child.shownWidgetCount) then
      return true
    end
  end
  return false
end

-- A tooltip we may restyle right now.
local function Safe(tooltip)
  if not S.Usable(tooltip) or type(tooltip.GetWidth) ~= "function" then
    return false
  end
  if Secret(tooltip:GetWidth()) then
    return false
  end
  return not (tooltip.GetChildren and SecretWidgets(tooltip:GetChildren()))
end

local function NineOf(tooltip)
  local nine = S.Child(tooltip, "NineSlice")
  return S.Usable(nine) and nine or nil
end

-- Blizzard's border and background pieces: invisible (the NineSlice frame itself stays shown, it holds ours).
local function HidePieces(nine)
  for _, key in ipairs(PIECES) do
    S.Kill(S.Region(nine, key))
  end
end

local function EachTexture(plate, fn)
  if plate.fill then fn(plate.fill) end
  if plate.tile then fn(plate.tile) end
  for _, line in ipairs(plate.lines or {}) do fn(line) end
  for _, corner in ipairs(plate.corners or {}) do fn(corner) end
  for _, piece in ipairs(plate.round or {}) do fn(piece) end
end

-- The unit health bar hangs under the tooltip. It is never written to (taint): our panel grows down round
-- it while it is shown (only our own textures are re-anchored; its IsShown is only read), with a divider
-- line above it, and goes back to the tooltip's edge when it is hidden. Blizzard insets the bar 2 px from
-- the tooltip's sides; the panel ends 3 px below it.
local BAR_SIDE, BAR_BELOW = 2, 3
local dividers = setmetatable({}, { __mode = "k" }) -- [tooltip] = our line above the bar

local function BarOf(tooltip)
  local bar = S.Child(tooltip, "StatusBar") or (S.Name(tooltip) and S.Get(S.Name(tooltip) .. "StatusBar"))
  return S.Usable(bar) and bar or nil
end

local function FitBar(tooltip)
  local plate, nine, bar = plates[tooltip], NineOf(tooltip), BarOf(tooltip)
  if not plate or not nine or not bar then
    return
  end
  local shown = bar:IsShown()
  if Secret(shown) then
    return
  end
  -- the player asked for no health bar under unit tooltips: hidden (Hide is the one safe call on that bar on
  -- Forever; writing anything else to it taints). Blizzard shows it again for each unit: hidden again here.
  if shown then
    pcall(bar.Hide, bar)
    shown = false
  end
  local fill = plate.fill
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", nine, "TOPLEFT")
  if shown then
    fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", BAR_SIDE, -BAR_BELOW)
  else
    fill:SetPoint("BOTTOMRIGHT", nine, "BOTTOMRIGHT")
  end
  if dividers[tooltip] then
    dividers[tooltip]:SetShown(shown and fill:IsShown() and true or false)
  end
end

-- Now and on the next frame (Blizzard shows or hides the bar while it fills a unit tooltip).
local fitWaits = setmetatable({}, { __mode = "k" })
local function FitBarSoon(tooltip)
  FitBar(tooltip)
  if fitWaits[tooltip] then
    return
  end
  fitWaits[tooltip] = true
  C_Timer.After(0, function()
    fitWaits[tooltip] = nil
    S.Run("tooltips", FitBar, tooltip)
  end)
end

-- Comparison tabs ------------------------------------------------------------------------------------------
-- The shopping (comparison) tooltips carry a tab over their top edge ("Equipped", "Equipped with"): its art
-- invisible, the title bar's gradient and line drawn in its place (open at the bottom, into the tooltip), its
-- label in the heading font and accent (design token `sel` = the title bar colours, `titleLine` = its line).
-- The tab frame is found by its key (CompareHeader on this client; any "...Header" frame of a shopping
-- tooltip): keys are only read.
local function CompareTab(tooltip)
  local name = S.Name(tooltip)
  if not name or not name:find("Shopping") then
    return
  end
  for key, header in pairs(tooltip) do
    if type(key) == "string" and key:find("Header") and S.Usable(header) and not S.IsRegion(header)
      and header.GetRegions and header.CreateTexture and S.Once(header, "comparetab") then
      local label
      for _, region in ipairs({ header:GetRegions() }) do
        if S.IsRegion(region) then
          if region:GetObjectType() == "Texture" then
            S.Kill(region)
          elseif region:GetObjectType() == "FontString" then
            label = label or region
          end
        end
      end
      local bar = S.Theme().titlebar
      local fill = header:CreateTexture(nil, "BACKGROUND", nil, -8)
      fill:SetAllPoints(header)
      S.UI.Gradient(fill, bar.from, bar.to)
      local lines = S.Outline(header, fill, 0, 1, bar.line, "BORDER")
      lines[2]:Hide() -- no line at the bottom: the tab opens into the tooltip
      if label then
        S.Font(label, "head", "accent")
      end
    end
  end
end

-- Section headings -----------------------------------------------------------------------------------------
-- A heading inside a tooltip (board R2-Tooltips: "Quest", "Codex", "Stat Delta"): the tooltip gets a blank
-- line, and a label of ours (heading font, small, accent) sits on it with a thin rule (the theme's divider)
-- running to the tooltip's right edge. Blizzard's line is only anchored to, never written to. Each title
-- once per tooltip until it is cleared, so several modules can share one "Codex" heading. Labels are made out
-- of combat (two per tooltip when it is skinned); in combat without a free one the caller's plain line is used.
local SECTION_SIZE, SECTION_GAP, TIP_PAD = 11, 6, 10
local sections = setmetatable({}, { __mode = "k" }) -- [tooltip] = { pool = { { label, rule } }, used, titles }

local function SectionFont()
  local theme = S.Theme()
  local head = theme.font and theme.font.head
  if head then
    return head
  end
  local object = S.Get("GameFontNormal")
  local path = object and object.GetFont and object:GetFont()
  return type(path) == "string" and path or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
end

local function ClearSections(tooltip)
  local state = sections[tooltip]
  if not state then
    return
  end
  for _, piece in ipairs(state.pool) do
    piece.label:Hide()
    piece.rule:Hide()
  end
  state.used, state.titles = 0, {}
end

local function StateOf(tooltip)
  local state = sections[tooltip]
  if not state then
    state = { pool = {}, used = 0, titles = {} }
    sections[tooltip] = state
    S.HookScript(tooltip, "OnTooltipCleared", ClearSections)
  end
  return state
end

local function NewSectionPiece(tooltip, state)
  local theme = S.Theme()
  local label = tooltip:CreateFontString(nil, "ARTWORK")
  label:SetFont(SectionFont(), SECTION_SIZE, "")
  label:SetTextColor(S.UI.Unpack(theme.accent))
  label:Hide()
  local rule = tooltip:CreateTexture(nil, "ARTWORK")
  rule:SetHeight(1)
  S.SetColor(rule, theme.divider)
  rule:Hide()
  local piece = { label = label, rule = rule }
  state.pool[#state.pool + 1] = piece
  return piece
end

-- Labels made ahead (out of combat), so tooltips shown in a fight have some.
local function Sections(tooltip, count)
  if not S.Name(tooltip) or S.InCombat() then
    return
  end
  local state = StateOf(tooltip)
  while #state.pool < count do
    NewSectionPiece(tooltip, state)
  end
end

local function Readable(value)
  return value ~= nil and not Secret(value)
end

-- true when the tooltip has the heading now (added, or already there since it was last cleared).
local function Section(tooltip, title)
  if type(title) ~= "string" or not S.Usable(tooltip) or not plates[tooltip] or not Safe(tooltip) then
    return false
  end
  local name = S.Name(tooltip)
  if not name or type(tooltip.AddLine) ~= "function" or type(tooltip.NumLines) ~= "function" then
    return false
  end
  local state = StateOf(tooltip)
  if state.titles[title] then
    return true
  end
  local piece = state.pool[state.used + 1]
  if not piece then
    if S.InCombat() then
      return false
    end
    piece = NewSectionPiece(tooltip, state)
  end
  local count = tooltip:NumLines()
  if not Readable(count) or type(count) ~= "number" then
    return false
  end
  tooltip:AddLine(" ")
  local line = S.Get(name .. "TextLeft" .. (count + 1))
  if not S.IsRegion(line) then
    return true -- the blank line stays as a gap; nothing more we can do
  end
  state.used = state.used + 1
  state.titles[title] = true
  local label, rule = piece.label, piece.rule
  label:SetText(title)
  label:ClearAllPoints()
  label:SetPoint("LEFT", line, "LEFT", 0, 0)
  label:Show()
  rule:ClearAllPoints()
  -- the top from the label's middle, the width to the tooltip's edge (TOPLEFT + RIGHT: the height decides
  -- the bottom, RIGHT only the right edge)
  rule:SetPoint("TOPLEFT", label, "RIGHT", SECTION_GAP, 0)
  rule:SetPoint("RIGHT", tooltip, "RIGHT", -TIP_PAD, 0)
  rule:Show()
  return true
end

-- Light theme (Dawn): the tooltip is a light panel, so every line's colour (white, yellow, quality names, red
-- requirements, green set bonuses) and the colour codes in its text go through S.GameText (darkened, hue kept,
-- the theme's quality colours for item names, no shadow). The game fills lines in C (AddLine / AddDoubleLine /
-- SetText, and the tooltip data processor ends with Show), so the lines are gone over after those calls
-- (post-hooks); later SetTextColor / SetText calls on a line are caught by the line's own hooks. A secret line
-- count, colour or text (a unit in combat) is left exactly as the game set it.
local function ReadableLines(tooltip, from)
  if not plates[tooltip] or not S.Theme().light or type(tooltip.NumLines) ~= "function" then
    return
  end
  local name = S.Name(tooltip)
  local ok, count = pcall(tooltip.NumLines, tooltip)
  if not name or not ok or Secret(count) or type(count) ~= "number" then
    return
  end
  for index = math.max(1, from or 1), count do
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
      local line = S.Get(name .. side .. index)
      if S.IsRegion(line) then
        S.GameText(line)
      end
    end
  end
end
S.ReadableTooltipLines = ReadableLines

local function LastLine(tooltip)
  local ok, count = pcall(tooltip.NumLines, tooltip)
  if ok and not Secret(count) and type(count) == "number" then
    ReadableLines(tooltip, count)
  end
end

local function WatchLines(tooltip)
  if not S.Theme().light then
    return
  end
  S.HookMethod(tooltip, "Show", ReadableLines)
  S.HookMethod(tooltip, "AddLine", LastLine)
  S.HookMethod(tooltip, "AddDoubleLine", LastLine)
  S.HookMethod(tooltip, "SetText", ReadableLines)
  S.HookScript(tooltip, "OnShow", ReadableLines)
  ReadableLines(tooltip)
end

local function Build(tooltip)
  local nine = NineOf(tooltip)
  if not nine or not Safe(tooltip) or not S.Once(tooltip, "tooltip") then
    return
  end
  HidePieces(nine)
  -- small corner pieces: tooltips are only a few lines tall
  local corner = S.Theme().corner
  plates[tooltip] = S.Plate(nine, "panel", { corners = true,
    cornerSize = corner and math.floor((corner.size or 16) * 0.7 + 0.5), ringLayer = "BACKGROUND", ringSublevel = -6 })
  CompareTab(tooltip)
  Sections(tooltip, 2)
  WatchLines(tooltip)
  local bar = BarOf(tooltip)
  if bar then
    local line = nine:CreateTexture(nil, "BORDER", nil, 2)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 2)
    S.SetColor(line, S.Theme().divider)
    dividers[tooltip] = line
    S.HookScript(tooltip, "OnShow", FitBarSoon)
    S.HookScript(tooltip, "OnTooltipCleared", FitBarSoon)
    FitBar(tooltip)
  end
end

local function Skin(tooltip)
  if not S.Usable(tooltip) or S.Done(tooltip, "tooltip") or not NineOf(tooltip) then
    return
  end
  waits[tooltip] = waits[tooltip] or {}
  S.Defer(waits[tooltip], function()
    Build(tooltip)
  end)
end

local function SkinAll()
  for _, path in ipairs(TOOLTIPS) do
    Skin(S.Get(path))
  end
end

-- After Blizzard styles a tooltip: its pieces invisible again, our panel only when the tooltip draws its
-- own frame (not when embedded in another).
local function Restyle(tooltip, style, embedded)
  if not plates[tooltip] then
    Skin(tooltip)
    return
  end
  if not Safe(tooltip) then
    return
  end
  local nine = NineOf(tooltip)
  if nine then
    HidePieces(nine)
  end
  local plate = plates[tooltip]
  local inside = embedded or (type(style) == "table" and style.isEmbedded)
  EachTexture(plate, function(texture)
    texture:SetShown(not inside)
  end)
  FitBar(tooltip)
end

-- The tooltip's first line is a name (unit, item): the theme's body font at Blizzard's own header size, or
-- the game's font when the theme has none. Never the heading font: Cinzel has capitals only, so names would
-- read upper-case. Blizzard's colours (reaction, quality) stay.
local function HeaderFont()
  local object = S.Get("GameTooltipHeaderText")
  local body = S.Theme().font and S.Theme().font.body
  if not object or not body or not object.SetFont or not object.GetFont then
    return
  end
  local _, size, flags = object:GetFont()
  object:SetFont(body, type(size) == "number" and size > 0 and size or 14, type(flags) == "string" and flags or "")
end

S.Part("tooltips", function()
  SkinAll()
  HeaderFont()
  S.FontObject("GameTooltipText", "body")
  S.FontObject("GameTooltipTextSmall", "body")
  S.HookGlobal("SharedTooltip_SetBackdropStyle", Restyle)
  S.HookGlobal("GameTooltip_SetDefaultAnchor", function(tooltip)
    local nine = plates[tooltip] and Safe(tooltip) and NineOf(tooltip)
    if nine then
      HidePieces(nine)
    end
  end)
  local part = S.part
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
    and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
      if plates[tooltip] then
        S.Run(part, FitBarSoon, tooltip)
      end
    end)
  end
  -- the section heading for the Codex modules' blocks (they fall back to a plain line without it)
  TylesserCodex.TooltipSection = function(tooltip, title)
    local ok, done = pcall(Section, tooltip, title)
    return ok and done or false
  end
  -- tooltips that come with load-on-demand addons (the world map's quest tooltips, ...)
  S.OnAnyAddOn(SkinAll)
end)
