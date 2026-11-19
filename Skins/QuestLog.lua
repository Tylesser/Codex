local addonName, ns = ...
local S = ns.S

-- Quest log and world map. On Forever the quest log is QuestMapFrame inside WorldMapFrame (Blizzard_WorldMap,
-- load-on-demand, skinned when it loads):
-- - the map window gets the theme's panel, rings, corners and title bar (its border art lives in
--   WorldMapFrame.BorderFrame), the theme's close and maximise / minimise buttons, and the breadcrumb bar
--   (World > Kalimdor > ...) in the button look on an inset;
-- - the quest list sits on the theme's sidebar shade (board R2-QuestMap): zone headers as light heading
--   text with a thin rule (their gold strips invisible), quest titles and objectives light and readable
--   (difficulty colours kept), track boxes in the theme, the search box inset and as tall as the crumbs;
-- - the quest details lose their parchment: dark text becomes the theme's text colour, headings the
--   accent, buttons the theme's button look; the Rewards heading is heading text with a rule, and the
--   rewards area gets an opaque backing (Blizzard's art did that: without it the scrolling text showed
--   through under the rewards), reward boxes in the light see-through slot look;
-- - the coordinates under the map use the theme's font and text colour; the small map buttons get rings.
-- The map canvas and pins are left alone. The map is never opened or closed from here (refused in combat);
-- everything is built out of combat, the hooks only recolour text.
--
-- Quest text colours: Blizzard colours the shared quest text through QuestFrame_SetTitleTextColor /
-- QuestFrame_SetTextColor (parchment colours) while it lays a quest out, and the same strings show on the
-- NPC quest window's parchment. Each of those calls is followed: a string inside the map is made light, one
-- on an NPC's parchment is left dark. A full pass over the details also runs after each quest is shown and
-- again on the next frame, after anything Blizzard still does in that frame.

-- Backgrounds swapped for the theme (QuestMapFrame and its quest list / details).
local LOG_ART = { "QuestMapFrame.Background", "QuestScrollFrame.Background", "QuestScrollFrame.Edge",
  "QuestScrollFrame.BorderFrame", "QuestScrollFrame.Contents.Separator", "QuestMapFrame.QuestsFrame.Background",
  "QuestMapFrame.DetailsFrame.Bg", "QuestMapFrame.DetailsFrame.SealMaterialBG", "QuestMapFrame.DetailsFrame.BorderFrame",
  "QuestMapFrame.DetailsFrame.BackFrame.BackBg", "QuestMapFrame.DetailsFrame.RewardsFrame.Background" }

-- Quest text headings (accent).
local HEADERS = { "QuestInfoTitleHeader", "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader",
  "QuestInfoRewardsFrame.Header", "QuestInfoRewardsFrame.ItemChooseText", "MapQuestInfoRewardsFrame.Header",
  "QuestProgressTitleText", "QuestProgressRequiredItemsText", "CurrentQuestsText", "AvailableQuestsText" }

local function Readable(...)
  if canaccessallvalues then
    return canaccessallvalues(...) and true or false
  end
  return true
end

local function Lightness(r, g, b)
  return r * 0.3 + g * 0.59 + b * 0.11
end

-- Parchment text is dark: dark becomes the theme's text colour, grey (finished objectives) the muted
-- colour; coloured text (difficulty, item quality, money, reputation) is left as it is on a dark theme.
local function Lighten(fontString)
  if not S.IsRegion(fontString) or not fontString.GetTextColor then
    return
  end
  local r, g, b = fontString:GetTextColor()
  if not Readable(r, g, b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
    return
  end
  local theme = S.Theme()
  local light = Lightness(r, g, b)
  local spread = math.max(r, g, b) - math.min(r, g, b)
  if light < 0.35 then
    fontString:SetTextColor(S.UI.Unpack(theme.text))
  elseif light < 0.6 and spread < 0.12 then
    fontString:SetTextColor(S.UI.Unpack(theme.muted))
  end
  -- a light theme (Dawn): the bright colours left above (yellow quest names, quality, money, links) and the codes
  -- in the text are darkened too, now and after Blizzard's next setters (S.GameText)
  if theme.light then
    S.GameText(fontString)
  end
end

local function Heading(fontString)
  if S.IsRegion(fontString) then
    S.Font(fontString, "head", "accent")
  end
end

-- The quest windows we restyle (light text on the theme): the map's quest log, the NPC quest and gossip
-- windows, the quest popup. QuestInfoFrame and its strings move between them.
local QUEST_UI = { "QuestMapFrame", "WorldMapFrame", "QuestFrame", "GossipFrame", "QuestLogPopupDetailFrame" }

-- Whether a frame or string is showing inside one of those windows.
local function InMap(object)
  local roots = {}
  for _, name in ipairs(QUEST_UI) do
    local frame = S.Get(name)
    if frame then
      roots[frame] = true
    end
  end
  local parent = object
  for _ = 1, 14 do
    parent = type(parent) == "table" and parent.GetParent and parent:GetParent() or nil
    if not parent then
      return false
    end
    if roots[parent] then
      return true
    end
  end
  return false
end

-- Reward buttons (item, XP, money, ... with Icon and NameFrame): the brown name frame gives way to an
-- inset box beside the icon, the icon gets slot rings. Elsewhere (QuestInfoFrame in a window we don't
-- restyle) Blizzard's art is back and ours hidden.
local rewards = setmetatable({}, { __mode = "k" }) -- [button] = our textures
local REWARD_FRAMES = { "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }
local REWARD_KEYS = { "XPFrame", "MoneyFrame", "HonorFrame", "SkillPointFrame", "TitleFrame", "ArtifactXPFrame" }

-- The map's own reward buttons (board R2-QuestMap): one light see-through box round icon and name.
-- Design token slotBg = the theme's text colour at 7% (an empty slot is light, never black).
local REWARD_PAD = 4
local function SeeThrough()
  local text = S.Theme().text
  return { text[1], text[2], text[3], 0.07 }
end

local function RewardButton(button, show, map)
  local icon = S.Region(button, "Icon") or S.Region(button, "IconTexture")
  local nameFrame = S.Region(button, "NameFrame")
  if not S.Usable(button) or not icon or not nameFrame then
    return
  end
  local parts = rewards[button]
  if show and not parts and not S.InCombat() then
    parts = {}
    local theme = S.Theme()
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    if map then
      -- top and bottom from the icon, the right edge from the button
      fill:SetPoint("TOPLEFT", icon, "TOPLEFT", -REWARD_PAD, REWARD_PAD)
      fill:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -REWARD_PAD, -REWARD_PAD)
      fill:SetPoint("RIGHT", button, "RIGHT", -2, 0)
      S.SetColor(fill, SeeThrough())
    else
      fill:SetPoint("TOPLEFT", icon, "TOPRIGHT", 2, 0)
      fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 1)
      S.SetColor(fill, theme.inset.fill)
    end
    parts[1] = fill
    for _, line in ipairs(S.Outline(button, fill, 0, 1, map and theme.divider or theme.inset.line, "BORDER")) do
      parts[#parts + 1] = line
    end
    local look = S.Look("slot")
    local depth = S.RingDepth(look.rings)
    for _, ring in ipairs(look.rings) do
      for _, line in ipairs(S.Outline(button, icon, (ring.inset or 0) - depth, ring.size, ring.color, "OVERLAY", 1)) do
        parts[#parts + 1] = line
      end
    end
    rewards[button] = parts
  end
  if parts then
    nameFrame:SetAlpha(show and 0 or 1)
    for _, part in ipairs(parts) do
      part:SetShown(show)
    end
  end
end

local function Rewards(show)
  for _, name in ipairs(REWARD_FRAMES) do
    local frame = S.Get(name)
    local map = name == "MapQuestInfoRewardsFrame"
    for _, button in ipairs(S.Child(frame, "RewardButtons") or {}) do
      RewardButton(button, show or map, map)
    end
    for _, key in ipairs(REWARD_KEYS) do
      RewardButton(S.Child(frame, key), show or map, map)
    end
  end
end

-- Colour codes inside the text (gossip, greetings: parchment colours like |cff000000 or dark browns) beat
-- any SetTextColor: a dark code becomes the theme's text colour, a dull grey one the muted colour; bright
-- codes (links, quest names, money) stay.
local function HexOf(c)
  return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end

local recoding = false
local function Recode(object)
  if recoding or not S.Usable(object) or type(object.GetText) ~= "function" or type(object.SetText) ~= "function" then
    return
  end
  local text = object:GetText()
  if type(text) ~= "string" or not Readable(text) or not text:find("|c", 1, true) then
    return
  end
  local theme = S.Theme()
  local changed = 0
  local fixed = text:gsub("|c[fF][fF](%x%x)(%x%x)(%x%x)", function(rr, gg, bb)
    local r, g, b = tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255
    local light = Lightness(r, g, b)
    local spread = math.max(r, g, b) - math.min(r, g, b)
    if light < 0.35 then
      changed = changed + 1
      return "|cff" .. HexOf(theme.text)
    elseif light < 0.6 and spread < 0.12 then
      changed = changed + 1
      return "|cff" .. HexOf(theme.muted)
    end
  end)
  if changed > 0 then
    recoding = true
    pcall(object.SetText, object, fixed)
    recoding = false
  end
end

local function LightenAll(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.Usable(region) and region:GetObjectType() == "FontString" then
      Lighten(region)
      Recode(region)
    end
  end
end

-- Frames whose every string is looked over after a quest or gossip page is shown.
local TEXT_ROOTS = { "QuestMapFrame.DetailsFrame", "QuestFrame", "GossipFrame", "QuestLogPopupDetailFrame" }

-- Every string of the quest windows (the map's details with their scroll child, the NPC quest and gossip
-- windows, QuestInfoFrame wherever it is shown in them), then the headings.
local function QuestText()
  local info = S.Get("QuestInfoFrame")
  local inLog = info and InMap(info) or false
  Rewards(inLog)
  for _, path in ipairs(TEXT_ROOTS) do
    local root = S.Get(path)
    if S.Usable(root) and (path == "QuestMapFrame.DetailsFrame" or (root.IsShown and root:IsShown())) then
      LightenAll(root)
      S.Walk(root, 8, LightenAll)
    end
  end
  if not inLog then
    return
  end
  LightenAll(info)
  S.Walk(info, 6, LightenAll)
  for _, path in ipairs(HEADERS) do
    Heading(S.Get(path))
  end
end

-- After this frame too: Blizzard may still colour or lay out the quest after the call we follow.
local textSoon = false
local function QuestTextSoon()
  QuestText()
  if textSoon then
    return
  end
  textSoon = true
  C_Timer.After(0, function()
    textSoon = false
    S.Run("questlog", QuestText)
  end)
end

-- Blizzard's own colouring of one quest string: followed, and in the map made light.
local function TitleColor(fontString)
  if InMap(fontString) then
    Heading(fontString)
  end
end
local function TextColor(fontString)
  if InMap(fontString) then
    Lighten(fontString)
  end
end

-- A number we may read from a region (width, string width), or nil.
local function Number(region, method)
  if not S.Usable(region) or type(region[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(region[method], region)
  if ok and type(value) == "number" and Readable(value) then
    return value
  end
end

-- Zone headers (board R2-QuestMap): light heading text with a thin rule after it, no gold strip. The
-- header's wide art (strip, highlight) is made invisible, its small pieces (the + / - sign) muted; a hover
-- shade of ours. Built out of combat; the rule follows the name's width on every list update.
--
-- Only header rows: on Forever a quest title button also carries an (empty) ButtonText region spanning
-- the whole button, so a row counts as a header only when that text is a non-empty string and the row has
-- no track box (Checkbox) and no Text region of its own. A row that stops being a header hides its rule.
local HEADER_ART_WIDTH, RULE_GAP, SIGN_ROOM = 30, 8, 24
local zoneRules = setmetatable({}, { __mode = "k" }) -- [header row] = our rule

local function IsZoneHeader(row, label)
  if S.Child(row, "Checkbox") or S.Region(row, "Text") then
    return false
  end
  local text = label.GetText and label:GetText()
  return type(text) == "string" and Readable(text) and text ~= ""
end

local function ZoneHeader(row, label)
  if not IsZoneHeader(row, label) then
    if zoneRules[row] then
      zoneRules[row]:Hide()
    end
    return
  end
  Heading(label)
  if not zoneRules[row] and not S.InCombat() and S.Once(row, "zoneheader") then
    local theme = S.Theme()
    local function Art(frame)
      for _, region in ipairs({ frame:GetRegions() }) do
        if S.IsRegion(region) and region:GetObjectType() == "Texture" then
          local width = Number(region, "GetWidth")
          if width and width > HEADER_ART_WIDTH then
            S.Kill(region)
          elseif width then
            S.Tint(region, theme.muted)
          end
        end
      end
    end
    Art(row)
    local collapse = S.Child(row, "CollapseButton")
    if S.Usable(collapse) and collapse.GetRegions then
      Art(collapse)
    end
    local rule = row:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    S.SetColor(rule, theme.divider)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(row)
    local c = theme.select.from
    hover:SetColorTexture(c[1], c[2], c[3], c[4] or 0.2)
    zoneRules[row] = rule
  end
  local rule = zoneRules[row]
  local width = Number(label, "GetStringWidth")
  if rule and width then
    rule:Show()
    rule:ClearAllPoints()
    -- the top from the name's middle, the right edge short of the + / - sign (the height gives the bottom)
    rule:SetPoint("TOPLEFT", label, "LEFT", width + RULE_GAP, 0)
    local collapse = S.Child(row, "CollapseButton")
    if S.Usable(collapse) then
      rule:SetPoint("RIGHT", collapse, "LEFT", -RULE_GAP, 0)
    else
      rule:SetPoint("RIGHT", row, "RIGHT", -SIGN_ROOM, 0)
    end
  end
end

-- The track box of a quest row (board R2-QuestMap): Blizzard's box art invisible, a small light
-- see-through box of ours with the button line, the tick (checked texture / CheckMark) in the accent.
local TRACK_BOX = 14
local function TrackBox(check)
  if not S.Usable(check) or S.InCombat() or not check.GetRegions or not S.Once(check, "trackbox") then
    return
  end
  local theme = S.Theme()
  local checked = check.GetCheckedTexture and check:GetCheckedTexture()
  local mark = S.Region(check, "CheckMark")
  for _, region in ipairs({ check:GetRegions() }) do
    if S.IsRegion(region) and region:GetObjectType() == "Texture" and region ~= checked and region ~= mark then
      S.Kill(region)
    end
  end
  for _, region in ipairs({ checked or false, mark or false }) do
    if S.IsRegion(region) then
      S.Tint(region, theme.accent)
    end
  end
  local box = check:CreateTexture(nil, "BACKGROUND", nil, -8)
  box:SetSize(TRACK_BOX, TRACK_BOX)
  box:SetPoint("CENTER", check, "CENTER")
  S.SetColor(box, SeeThrough())
  S.Outline(check, box, 0, 1, theme.button.line, "BORDER")
  local hover = check:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(box)
  S.SetColor(hover, theme.button.hover)
end

-- The quest list: zone headers (ButtonText) as headings with a rule, titles and objectives (Text) made
-- readable on the dark shade, track boxes themed. Quest titles keep Blizzard's text ("[45] Title") and
-- difficulty colours.
local function ListText()
  local contents = S.Get("QuestScrollFrame.Contents")
  if not contents then
    return
  end
  S.Walk(contents, 2, function(row)
    local label = S.Region(row, "ButtonText")
    if label then
      ZoneHeader(row, label)
    end
    local text = S.Region(row, "Text")
    if text then
      S.Font(text, "body")
      Lighten(text)
    end
    local check = S.Child(row, "Checkbox")
    if check then
      TrackBox(check)
    end
  end)
end

-- Textures of a frame (not ours: called before we draw on it).
local function KillTextures(frame)
  if not S.Usable(frame) then
    return
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.IsRegion(region) and region:GetObjectType() == "Texture" then
      S.Kill(region)
    end
  end
end

-- The rewards area's backing: opaque, the window's colour at the bottom (the panel's lower colour under the
-- quest list's side shade), the panel's tile too when the theme has one. Blizzard's own art here was
-- opaque and hid the description scrolling underneath; with it invisible the text showed through.
local function Backing()
  local theme = S.Theme()
  local panel, side = theme.panel, theme.side
  local a = side[4] or 1
  local c = { panel.from[1] * (1 - a) + side[1] * a, panel.from[2] * (1 - a) + side[2] * a,
    panel.from[3] * (1 - a) + side[3] * a, 1 }
  return { from = c, to = c, alpha = 1, tile = panel.tile, tileAlpha = panel.tileAlpha, blend = panel.blend, rings = {} }
end

-- The Rewards heading over the rewards (RewardsFrameContainer.RewardsFrame, brown art): its art invisible,
-- the area behind it opaque (Backing), the heading in the heading font and accent with a thin rule after it
-- (board R2-QuestMap: "Rewards" heading, reward boxes below, nothing overlapping).
local function RewardsHeading()
  local container = S.Get("QuestMapFrame.DetailsFrame.RewardsFrameContainer")
  local frame = S.Child(container, "RewardsFrame") or S.Get("QuestMapFrame.DetailsFrame.RewardsFrame")
  if not S.Usable(frame) or not S.Once(frame, "rewardsheading") then
    return
  end
  KillTextures(frame)
  local area = S.Usable(container) and container or frame
  S.Plate(frame, Backing(), { topLeft = area, bottomRight = area })
  local label
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.IsRegion(region) and region:GetObjectType() == "FontString" then
      label = label or region
      Heading(region)
    end
  end
  label = S.Region(frame, "Label") or label
  if label then
    local rule = frame:CreateTexture(nil, "BORDER", nil, 1)
    rule:SetHeight(1)
    S.SetColor(rule, S.Theme().divider)
    -- the top from the label's middle, the right edge at the frame's (the height gives the bottom)
    local width = Number(label, "GetStringWidth")
    if width then
      rule:SetPoint("TOPLEFT", label, "LEFT", width + RULE_GAP, 0)
    else
      rule:SetPoint("TOPLEFT", label, "RIGHT", RULE_GAP, 0)
    end
    rule:SetPoint("RIGHT", frame, "RIGHT", -RULE_GAP, 0)
  end
end

-- Abandon / Share / Track: one button look each (board R2-QuestMap: three equal buttons). Blizzard's
-- extra art on them (the dividers between the buttons) is made invisible before the button look goes on;
-- the highlight texture is left.
local DETAIL_BUTTONS = { "AbandonButton", "ShareButton", "TrackButton" }
local function DetailButtons(details)
  for _, key in ipairs(DETAIL_BUTTONS) do
    local button = S.Child(details, key)
    if S.IsPanelButton(button) and not S.Done(button, "button") then
      local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
      for _, region in ipairs({ button:GetRegions() }) do
        if S.IsRegion(region) and region:GetObjectType() == "Texture" and region ~= highlight then
          S.Kill(region)
        end
      end
      S.Button(button)
    end
  end
end

-- The details' buttons: walked once, and again only when the details frame's child count changes.
local detailsChildren
local function Details()
  local details = S.Get("QuestMapFrame.DetailsFrame")
  if S.Usable(details) then
    local count = select("#", details:GetChildren())
    if count ~= detailsChildren then
      detailsChildren = count
      DetailButtons(details)
      S.WindowButtons(details)
    end
    KillTextures(S.Child(details, "BackFrame"))
  end
  RewardsHeading()
  QuestText()
end

local detailsKey = {} -- one wait for the details' buttons while in combat

-- The quest search row (search box, Forever's quest count, the settings button): one band of one height,
-- laid out again with the map's breadcrumbs (SearchRow, further down).
local SearchRow

local function SkinLog()
  local log = S.Get("QuestMapFrame")
  if not S.Usable(log) or not S.Once(log, "questlog") then
    return
  end
  local theme = S.Theme()
  for _, path in ipairs(LOG_ART) do
    S.Kill(S.Get(path))
  end
  S.Plate(log, { fill = theme.side, rings = {} })
  local separator = S.Get("QuestMapFrame.VerticalSeparator")
  if S.IsRegion(separator) then
    S.Tint(separator, theme.divider)
  end
  SearchRow()
  if ns.SkinScrollBar then
    ns.SkinScrollBar(S.Get("QuestScrollFrame.ScrollBar"))
    ns.SkinScrollBar(S.Get("QuestMapDetailsScrollFrame.ScrollBar"))
  end
  S.HookGlobal("QuestLogQuests_Update", ListText)
  S.HookGlobal("QuestMapFrame_ShowQuestDetails", function()
    -- buttons are built out of combat; the text is only recoloured
    S.Defer(detailsKey, Details)
    QuestTextSoon()
  end)
  S.HookScript(S.Child(log, "DetailsFrame"), "OnShow", QuestTextSoon)
  ListText()
  Details()
end

-- Forever's coordinates under the map (overlay frames with PlayerCoords / CursorCoords rows).
local function Coordinates(map)
  for _, overlay in ipairs(S.Child(map, "overlayFrames") or {}) do
    for _, key in ipairs({ "PlayerCoords", "CursorCoords", "CrosshairCoords" }) do
      local label = S.Region(S.Child(overlay, key), "Label")
      if label and S.Once(label, "coords") then
        S.Font(label, "body", "text")
      end
    end
  end
end

local function ButtonLook()
  local style = S.Theme().button
  return { from = style.from, to = style.to, rings = { { inset = 0, color = style.line, size = 1 } } }
end

-- Positions are only read (never written), and only used when readable.
local function Edge(region, method)
  if not S.Usable(region) or type(region[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(region[method], region)
  if ok and type(value) == "number" and Readable(value) then
    return value
  end
end

local function CenterY(region)
  local top, bottom = Edge(region, "GetTop"), Edge(region, "GetBottom")
  if top and bottom then
    return (top + bottom) / 2
  end
end

-- The small buttons on the map (map pins at the top left, the quest log toggle at the bottom right): the
-- title-bar buttons' look, lighter: the button gradient see-through (MAP_BUTTON_ALPHA) so the parchment shows,
-- one thin button line, a hover shade. Their own icons are kept. (The slot look's black fill was heavy on
-- the map art, the user's feedback 2026-11-18.)
local MAP_BUTTON_ALPHA = 0.55
local function Ringed(button)
  if not S.Usable(button) or not S.Once(button, "ringed") then
    return
  end
  local style = S.Theme().button
  local plate = S.Plate(button, { from = style.from, to = style.to, alpha = MAP_BUTTON_ALPHA,
    rings = { { inset = 0, color = style.line, size = 1 } } }, { ringLayer = "OVERLAY" })
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(plate.fill)
  S.SetColor(hover, style.hover)
end

-- A down arrow of ours (the chat menu's arrow texture turned down), in the accent, centred on `box`.
local function DownArrow(button, box)
  local arrow = button:CreateTexture(nil, "ARTWORK", nil, 7)
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetSize(10, 10)
  arrow:SetPoint("CENTER", box, "CENTER", 0, -1)
  arrow:SetRotation(-math.pi / 2)
  local accent = S.Theme().accent
  arrow:SetVertexColor(accent[1], accent[2], accent[3], 1)
  return arrow
end

-- Maximise / minimise: Blizzard's red art invisible, the same square box as the close button (centred on
-- the close button's height, so the title-bar buttons line up), a small square (maximise) or a bar
-- (minimise) drawn in it.
local function SmallButton(button, glyph, closeButton)
  if not S.Usable(button) or button:GetObjectType() ~= "Button" or not S.Once(button, "small") then
    return
  end
  if ns.KillButtonArt then
    ns.KillButtonArt(button)
  end
  local style = S.Theme().button
  local dy = 0
  local mine, theirs = CenterY(button), CenterY(closeButton)
  if mine and theirs then
    dy = theirs - mine
  end
  local box = ns.SkinSquareBox and ns.SkinSquareBox(button, nil, dy)
  if not box then
    return
  end
  if glyph == "max" then
    local square = button:CreateTexture(nil, "ARTWORK", nil, 6)
    square:SetSize(9, 9)
    square:SetPoint("CENTER", box, "CENTER")
    S.SetColor(square, style.text, 0)
    S.Outline(button, square, 0, 1, style.text, "ARTWORK", 7)
  else
    local bar = button:CreateTexture(nil, "ARTWORK", nil, 7)
    bar:SetSize(9, 2)
    bar:SetPoint("CENTER", box, "CENTER", 0, -3)
    S.SetColor(bar, style.text)
  end
end

-- The breadcrumb bar (NavBar): its art invisible and an inset behind. Each crumb (overflow, home, zones)
-- gets a button-look box of ours: every box spans the bar's inner height (the bar's top and bottom less
-- NAV_INSET) and ends NAV_GAP short of the next crumb, so the boxes share one height and are evenly spaced
-- whatever Blizzard's overlapping crumb shapes are. The current crumb in the accent. The dropdown arrows
-- get a square box of ours with our own arrow. Crumb positions are only read; Blizzard's crumbs never move.
local NAV_INSET, NAV_GAP = 3, 3
local crumbs = setmetatable({}, { __mode = "k" }) -- [crumb] = its box texture
local arrows = setmetatable({}, { __mode = "k" }) -- [arrow button] = its box texture

local function CrumbArrow(arrow)
  if not S.Usable(arrow) or arrows[arrow] then
    return
  end
  if ns.KillButtonArt then
    ns.KillButtonArt(arrow)
  end
  KillTextures(arrow)
  local box = ns.SkinSquareBox and ns.SkinSquareBox(arrow, 16)
  if box then
    DownArrow(arrow, box)
    arrows[arrow] = box
  end
end

local function Crumb(button)
  if not S.Usable(button) or crumbs[button] then
    return
  end
  KillTextures(button)
  local plate = S.Plate(button, ButtonLook(), { left = -1, right = -1, top = -2, bottom = -2 })
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(plate.fill)
  S.SetColor(hover, S.Theme().button.hover)
  crumbs[button] = plate.fill
  CrumbArrow(S.Child(button, "MenuArrowButton"))
end

-- Lays the boxes out from the crumbs' and the bar's current rects (our textures only).
local function LayoutCrumbs(bar, list)
  local barTop, barBottom = Edge(bar, "GetTop"), Edge(bar, "GetBottom")
  local inner = barTop and barBottom and (barTop - barBottom - 2 * NAV_INSET) or nil
  for index, button in ipairs(list) do
    local box = crumbs[button]
    local top, bottom = Edge(button, "GetTop"), Edge(button, "GetBottom")
    if box and barTop and barBottom and top and bottom then
      local nextButton = list[index + 1]
      box:ClearAllPoints()
      box:SetPoint("TOPLEFT", button, "TOPLEFT", 0, (barTop - NAV_INSET) - top)
      local nextBottom = nextButton and Edge(nextButton, "GetBottom")
      if nextButton and nextBottom then
        box:SetPoint("BOTTOMRIGHT", nextButton, "BOTTOMLEFT", -NAV_GAP, (barBottom + NAV_INSET) - nextBottom)
      else
        box:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, (barBottom + NAV_INSET) - bottom)
      end
      -- the arrow's box: square, a little smaller than the crumb, on the crumb box's middle
      local arrow = S.Child(button, "MenuArrowButton")
      local arrowBox = arrows[arrow]
      local arrowMiddle = CenterY(arrow)
      if arrowBox and inner and arrowMiddle then
        local size = math.max(10, inner - 6)
        arrowBox:SetSize(size, size)
        arrowBox:ClearAllPoints()
        arrowBox:SetPoint("CENTER", arrow, "CENTER", 0, (barTop + barBottom) / 2 - arrowMiddle)
      end
    end
  end
end

-- Forever's tracking / filter button beside the bar (an arrow with a red reset badge): its art invisible
-- (the icon by alpha: Blizzard sets its atlas again on clicks), a square box as tall as the crumbs, on
-- the bar's middle, with our arrow. The reset badge (a child button, shown while filters are active) keeps
-- working but its round red art poked out of the box's corner: its textures are made invisible and a small
-- dot of ours (the theme's "bad" colour, thin dark ring) sits inside the box's top-right corner. The dot is a
-- texture of the badge button, so it shows and hides with it.
local BADGE, BADGE_INSET = 8, 3
local tracking = {}

local function ResetBadge(badge, box)
  if not S.Usable(badge) or not box or tracking.badge or not S.Once(badge, "resetbadge") then
    return
  end
  KillTextures(badge)
  if ns.KillButtonArt then
    ns.KillButtonArt(badge)
  end
  local ring = badge:CreateTexture(nil, "OVERLAY", nil, 6)
  ring:SetTexture("Interface\\AddOns\\Codex\\Media\\Circle")
  ring:SetSize(BADGE + 2, BADGE + 2)
  ring:SetPoint("CENTER", box, "TOPRIGHT", -BADGE_INSET - BADGE / 2, -BADGE_INSET - BADGE / 2)
  ring:SetVertexColor(0, 0, 0, 0.8)
  local dot = badge:CreateTexture(nil, "OVERLAY", nil, 7)
  dot:SetTexture("Interface\\AddOns\\Codex\\Media\\Circle")
  dot:SetSize(BADGE, BADGE)
  dot:SetPoint("CENTER", ring, "CENTER")
  local bad = S.Theme().bad or { 1, 0.3, 0.3 }
  dot:SetVertexColor(bad[1], bad[2], bad[3], 1)
  tracking.badge = dot
end
local function TrackingButton(button, bar)
  if not S.Usable(button) then
    return
  end
  if not tracking.box and S.Once(button, "tracking") then
    KillTextures(button)
    if ns.KillButtonArt then
      ns.KillButtonArt(button)
    end
    tracking.box = ns.SkinSquareBox and ns.SkinSquareBox(button)
    if tracking.box then
      DownArrow(button, tracking.box)
    end
  end
  ResetBadge(S.Child(button, "ResetButton"), tracking.box)
  local box = tracking.box
  local barTop, barBottom, middle = Edge(bar, "GetTop"), Edge(bar, "GetBottom"), CenterY(button)
  if box and barTop and barBottom and middle then
    local size = barTop - barBottom - 2 * NAV_INSET
    if size > 0 then
      box:SetSize(size, size)
      box:ClearAllPoints()
      box:SetPoint("CENTER", button, "CENTER", 0, (barTop + barBottom) / 2 - middle)
    end
  end
end

-- The quest search row (board R2-QuestMap; in game the three pieces had three heights and overlapped):
-- one band ROW_HEIGHT tall on the search box's middle. Blizzard's frames stay where they are; only our
-- boxes are laid out, from rects that are only read.
-- - the search box: our inset box spans the band, and ends ROW_GAP short of the quest count's text;
-- - Forever's quest count ("Quests: 28/40", found by its text outside the list and the details): all its
--   art invisible (textures, NineSlice / border frames), the text plain and muted, no box;
-- - the settings (gear) button: the same small square as the title-bar buttons (ns.SMALL_BOX), on the
--   band's middle, kept inside the quest panel's edge (minus the rings) when the gear sits on it.
local ROW_HEIGHT, ROW_GAP, ROW_REACH, GEAR_GAP = 24, 8, 14, 6
local row = {} -- { search = plate, counter = frame, counterText = font string, settings = box, gear = button }

local SKIP = { Contents = true, DetailsFrame = true, ScrollBar = true, ScrollBox = true, ScrollContainer = true,
  NavBar = true }

-- The quest count: a short "<words> 28/40" string (objectives such as "0/3 Roc Gizzard" end in words).
local function IsCount(text)
  if type(text) ~= "string" or not Readable(text) then
    return false
  end
  -- (the length is the plain text's: Blizzard's template colours both numbers, which made it long)
  local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return #plain < 32 and plain:find("^%D*%d+%s*/%s*%d+%s*$") ~= nil
end

local function FindCount(frame, depth, skip)
  if not S.Usable(frame) or depth < 0 or frame == skip then
    return nil
  end
  for _, region in ipairs(frame.GetRegions and { frame:GetRegions() } or {}) do
    if S.IsRegion(region) and region:GetObjectType() == "FontString" and IsCount(region:GetText()) then
      return frame, region
    end
  end
  -- (the quest list, the details and scroll bars hold objective texts like "0/3 ...": not looked into)
  for _, child in ipairs(frame.GetChildren and { frame:GetChildren() } or {}) do
    local skipped = false
    for key in pairs(SKIP) do
      if frame[key] == child then
        skipped = true
      end
    end
    if not skipped then
      local owner, text = FindCount(child, depth - 1, skip)
      if owner then
        return owner, text
      end
    end
  end
end

-- A frame that only draws (no text, no buttons below it): its art, safe to make invisible as a whole.
local function ArtOnly(frame)
  if not S.Usable(frame) or S.Protected(frame) or frame:GetObjectType() ~= "Frame" then
    return false
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.IsRegion(region) and region:GetObjectType() == "FontString" then
      return false
    end
  end
  return select("#", frame:GetChildren()) == 0
end

-- The count's box art: every texture of the frame holding the text (a backdrop's pieces are textures of the
-- frame too) and of its art-only children (NineSlice, border frames); the same one level up when that
-- parent is only the count's box (small, not the quest list or the map).
local COUNT_BOX = 220 -- a parent wider than this is a panel, not the count's box
local function Plain(counter, text)
  local function Strip(frame)
    KillTextures(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
      if ArtOnly(child) or (S.Usable(child) and not S.Protected(child)
        and (S.Child(child, "TopLeftCorner") or S.Child(child, "Center"))) then
        S.Kill(child)
      end
    end
  end
  Strip(counter)
  local parent = counter:GetParent()
  local width = Edge(parent, "GetWidth")
  if S.Usable(parent) and parent ~= S.Get("QuestScrollFrame") and parent ~= S.Get("QuestMapFrame")
    and parent ~= S.Get("WorldMapFrame") and width and width <= COUNT_BOX then
    Strip(parent)
  end
  S.Font(text, "body", "muted")
end

-- The gear: QuestScrollFrame.SettingsDropdown when the client names it so, else a small text-less button
-- right of the search box on its row.
local function FindGear(box, middle)
  local named = S.Get("QuestScrollFrame.SettingsDropdown") or S.Get("QuestMapFrame.SettingsDropdown")
  if S.Usable(named) then
    return named
  end
  local right = Edge(box, "GetRight")
  for _, path in ipairs({ "QuestScrollFrame", "QuestMapFrame" }) do
    local parent = S.Get(path)
    for _, child in ipairs(S.Usable(parent) and { parent:GetChildren() } or {}) do
      if S.Usable(child) and child ~= box and child:GetObjectType() == "Button" then
        local width, height, left = Edge(child, "GetWidth"), Edge(child, "GetHeight"), Edge(child, "GetLeft")
        local text = child.GetFontString and child:GetFontString()
        local mid = CenterY(child)
        if width and height and width <= 32 and height <= 32 and left and right and left >= right and mid and middle
          and math.abs(mid - middle) <= ROW_REACH and not (S.IsRegion(text) and (text:GetText() or "") ~= "") then
          return child
        end
      end
    end
  end
end

function SearchRow()
  local box = S.Get("QuestScrollFrame.SearchBox")
  if S.Usable(box) and S.Region(box, "Middle") and S.Once(box, "search") then
    S.KillKeys(box, "Left", "Middle", "Right")
    row.search = S.Plate(box, "inset", { left = 4 })
  end
  local middle = S.Usable(box) and CenterY(box)
  -- the quest count: plain muted text
  if not row.counter then
    -- Forever's own (Blizzard_UIPanels_Game, QuestMapFrame.xml): the frame QuestLogCount (InputBoxVisualTemplate:
    -- textures Left / Middle / Right, the "common-search-border" art) holding the font string QuestLogQuestCount
    -- (QuestLogQuests_ShowQuestCount fills it); found by its text when the client names it otherwise.
    local counter, text = S.Get("QuestLogCount"), S.Get("QuestLogQuestCount")
    if not (S.Usable(counter) and S.IsRegion(text)) then
      counter, text = FindCount(S.Get("QuestMapFrame"), 5, box)
    end
    if not counter then
      counter, text = FindCount(S.Get("WorldMapFrame"), 4, box) -- Forever may hang it on the map window
    end
    if counter and counter ~= box and S.Once(counter, "questcounter") then
      Plain(counter, text)
      row.counter, row.counterText = counter, text
    end
  end
  -- the gear: a small square on the band, inside the panel
  local gear = row.gear or FindGear(box, middle)
  if gear and not row.settings and ns.SkinSquareBox and S.Once(gear, "questsettings") then
    row.gear, row.settings = gear, ns.SkinSquareBox(gear) -- behind its own gear art, which stays
  end
  local gearMiddle = CenterY(gear)
  local gearBoxLeft -- where our gear square starts (screen x), when it is on the band
  if row.settings and middle and gearMiddle and math.abs(gearMiddle - middle) <= ROW_REACH then
    -- Blizzard anchors the gear (15 x 16) to the list's top-right corner and the count's box to the search
    -- box's right end, so they sit nearly edge to edge: our square starts GEAR_GAP after the count's text
    -- and stays inside the window's rings, shrinking (down to the gear's own width) when it must.
    local size = ns.SMALL_BOX or 20
    local dx = 0
    local gearRight, gearLeft = Edge(gear, "GetRight"), Edge(gear, "GetLeft")
    local edge = Edge(S.Get("WorldMapFrame"), "GetRight")
    local limit = edge and (edge - S.RingDepth(S.Theme().rings) - 2) -- inside the window's rings
    local textRight = Edge(row.counterText, "GetRight")
    if gearRight and gearLeft then
      local middleX = (gearLeft + gearRight) / 2
      local minLeft = textRight and (textRight + GEAR_GAP)
      if minLeft and middleX - size / 2 < minLeft then
        dx = minLeft - (middleX - size / 2)
      end
      if limit and middleX + dx + size / 2 > limit then
        dx = limit - (middleX + size / 2)
        if minLeft and middleX + dx - size / 2 < minLeft then
          -- no room for the full square: as wide as the room between the text and the rings allows
          local room = limit - minLeft
          size = math.max(gearRight - gearLeft + 1, math.floor(room))
          dx = (minLeft + limit) / 2 - middleX
        end
      end
      gearBoxLeft = middleX + dx - size / 2
      row.gearGap = textRight and (gearBoxLeft - textRight) or nil -- (for /dump and the tests)
    end
    row.settings:SetSize(size, size)
    row.settings:ClearAllPoints()
    row.settings:SetPoint("CENTER", gear, "CENTER", dx, middle - gearMiddle)
  end
  -- the search box's box: on the band, ending ROW_GAP before whatever follows it (the count's text, else
  -- the gear's square)
  if row.search then
    local fill = row.search.fill
    local top, bottom, right = Edge(box, "GetTop"), Edge(box, "GetBottom"), Edge(box, "GetRight")
    fill:ClearAllPoints()
    if middle and top and bottom then
      local stop
      local textRight, textWidth = Edge(row.counterText, "GetRight"), Edge(row.counterText, "GetStringWidth")
      if textRight and textWidth then
        stop = textRight - textWidth
      elseif gearBoxLeft then
        stop = gearBoxLeft
      end
      local dx = 0
      if right and stop and stop - ROW_GAP < right then
        dx = (stop - ROW_GAP) - right
      end
      fill:SetPoint("TOPLEFT", box, "TOPLEFT", -4, (middle + ROW_HEIGHT / 2) - top)
      fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", dx, (middle - ROW_HEIGHT / 2) - bottom)
    else
      fill:SetPoint("TOPLEFT", box, "TOPLEFT", -4, 0)
      fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT")
    end
  end
end

local navKey = {} -- one wait for the breadcrumbs while in combat
local function NavBar()
  local bar = S.Get("WorldMapFrame.NavBar")
  if not S.Usable(bar) then
    return
  end
  if S.Once(bar, "navbar") then
    KillTextures(bar)
    KillTextures(S.Child(bar, "overlay"))
    S.Plate(bar, "inset")
  end
  local theme = S.Theme()
  local shown = {}
  local overflow = S.Child(bar, "overflowButton")
  if S.Usable(overflow) and overflow:IsShown() then
    shown[#shown + 1] = overflow
  end
  local list = S.Child(bar, "navList") or {}
  if #list == 0 and S.Child(bar, "homeButton") then
    list = { S.Child(bar, "homeButton") }
  end
  for index, button in ipairs(list) do
    Crumb(button)
    local text = S.Region(button, "text") or (button.GetFontString and button:GetFontString())
    if S.IsRegion(text) then
      local c = index == #list and theme.accent or theme.button.text
      text:SetTextColor(c[1], c[2], c[3], 1)
    end
    if S.Usable(button) and button:IsShown() then
      shown[#shown + 1] = button
    end
  end
  Crumb(overflow)
  LayoutCrumbs(bar, shown)
  TrackingButton(S.Get("WorldMapFrame.WorldMapTrackingOptionsButton"), bar)
  SearchRow()
end

-- Now and on the next frame (Blizzard lays the crumbs out after adding them), out of combat.
local navSoon = false
local function NavBarSoon()
  S.Defer(navKey, NavBar)
  if navSoon then
    return
  end
  navSoon = true
  C_Timer.After(0, function()
    navSoon = false
    S.Run("questlog", S.Defer, navKey, NavBar)
  end)
end

local function MapButtons(map, chrome)
  local close = S.Child(chrome, "CloseButton") or S.Get("WorldMapFrameCloseButton")
  local maxMin = S.Child(chrome, "MaximizeMinimizeFrame") or S.Child(map, "MaximizeMinimizeFrame")
  SmallButton(S.Child(maxMin, "MaximizeButton"), "max", close)
  SmallButton(S.Child(maxMin, "MinimizeButton"), "min", close)
  Ringed(S.Child(map, "SidePanelToggle", "OpenButton"))
  Ringed(S.Child(map, "SidePanelToggle", "CloseButton"))
  Ringed(S.Child(map, "WorldMapTrackingPinButton"))
end

local function SkinMap()
  local map = S.Get("WorldMapFrame")
  if not S.Usable(map) then
    return
  end
  local chrome = S.Child(map, "BorderFrame") or map
  -- the overlay with the rings sits just above the border frame, under the map's own buttons
  local level = (chrome ~= map and chrome:GetFrameLevel() - map:GetFrameLevel() or 0) + 1
  S.Window(map, { chrome = chrome, level = level })
  if ns.SkinCloseButton then
    ns.SkinCloseButton(S.Child(chrome, "CloseButton") or S.Get("WorldMapFrameCloseButton"))
  end
  MapButtons(map, chrome)
  Coordinates(map)
  NavBar()
  -- crumbs are added and reset as the map changes zone; the bar changes size with the map
  for _, name in ipairs({ "NavBar_AddButton", "NavBar_Reset" }) do
    S.HookGlobal(name, function(bar)
      if bar == S.Get("WorldMapFrame.NavBar") then
        NavBarSoon()
      end
    end)
  end
  S.HookScript(map, "OnShow", NavBarSoon)
  S.HookScript(map, "OnSizeChanged", NavBarSoon)
  SkinLog()
end

-- NPC quest and gossip windows ------------------------------------------------------------------------------
-- QuestFrame (detail, progress, reward and greeting panels) and GossipFrame: the parchment art invisible, an
-- inset behind the text, light text and accent headings (the hooks above), rewards in the slot look,
-- themed scroll bars, gossip and greeting lines readable with a hover shade. The window frame and its
-- buttons are the windows part's.

local NPC_PANELS = { "QuestFrameDetailPanel", "QuestFrameGreetingPanel", "QuestFrameProgressPanel",
  "QuestFrameRewardPanel" }
local NPC_SCROLLS = { "QuestDetailScrollFrame", "QuestGreetingScrollFrame", "QuestProgressScrollFrame",
  "QuestRewardScrollFrame" }
local NPC_ART = { "QuestDetailScrollChildFrame", "QuestRewardScrollChildFrame", "QuestProgressScrollChildFrame",
  "QuestGreetingScrollChildFrame" }

-- One gossip / greeting line (a ScrollBox element: greeting text, an option or quest button): every string
-- in it readable (font colour and colour codes), with a hover shade of ours on buttons.
local function TextRow(row)
  if not S.Usable(row) then
    return
  end
  LightenAll(row)
  S.Walk(row, 2, LightenAll)
  if type(row.GetFontString) == "function" then
    Recode(row)
  end
  if row:GetObjectType() == "Button" and S.Once(row, "rowhover") and not S.InCombat() then
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(row)
    local c = S.Theme().select.from
    hover:SetColorTexture(c[1], c[2], c[3], c[4] or 0.2)
  end
end

local function GossipRows(scrollBox)
  if type(scrollBox.ForEachFrame) == "function" then
    local ok, err = pcall(scrollBox.ForEachFrame, scrollBox, TextRow)
    if not ok then
      S.Fail("questlog", "gossip: " .. tostring(err))
    end
  end
end

-- Blizzard sets each element's text and colour when it initialises the element (on every gossip page),
-- possibly after the ScrollBox's own update: looked over now and again on the next frame.
local gossipSoon = false
local function GossipRowsSoon()
  local scrollBox = S.Get("GossipFrame.GreetingPanel.ScrollBox")
  if not S.Usable(scrollBox) then
    return
  end
  GossipRows(scrollBox)
  if gossipSoon then
    return
  end
  gossipSoon = true
  C_Timer.After(0, function()
    gossipSoon = false
    S.Run("questlog", GossipRows, scrollBox)
  end)
end

local gossipOwner = {} -- our key in the ScrollBox's callback list
local function GossipHooks(gossip, scrollBox)
  S.HookMethod(scrollBox, "Update", GossipRowsSoon)
  S.HookMethod(scrollBox, "FullUpdate", GossipRowsSoon)
  -- each element as Blizzard initialises it
  if ScrollUtil and type(ScrollUtil.AddInitializedFrameCallback) == "function" then
    local part = S.part
    pcall(ScrollUtil.AddInitializedFrameCallback, scrollBox, function(_, frame)
      S.Run(part, TextRow, frame)
    end, gossipOwner, true)
  end
  S.HookScript(gossip, "OnShow", GossipRowsSoon)
  local events = CreateFrame("Frame")
  events:RegisterEvent("GOSSIP_SHOW")
  events:SetScript("OnEvent", function()
    S.Run("questlog", GossipRowsSoon)
  end)
end

local function GreetingRows()
  local panel = S.Get("QuestFrameGreetingPanel")
  local pool = S.Child(panel, "titleButtonPool")
  if pool and type(pool.EnumerateActive) == "function" then
    for button in pool:EnumerateActive() do
      TextRow(button)
    end
  end
  QuestTextSoon()
end

local function SkinNPC()
  local quest = S.Get("QuestFrame")
  if S.Usable(quest) and S.Once(quest, "npcquest") then
    for _, name in ipairs(NPC_PANELS) do
      local panel = S.Get(name)
      KillTextures(panel)
      S.HookScript(panel, "OnShow", QuestTextSoon)
    end
    for _, name in ipairs(NPC_ART) do
      KillTextures(S.Get(name))
    end
    S.Kill(S.Get("QuestGreetingFrameHorizontalBreak"))
    for _, name in ipairs(NPC_SCROLLS) do
      local scroll = S.Get(name)
      if S.Usable(scroll) then
        KillTextures(scroll)
        S.Plate(scroll, "inset")
        if ns.SkinScrollBar then
          ns.SkinScrollBar(S.Child(scroll, "ScrollBar"))
        end
      end
    end
    S.HookScript(S.Get("QuestFrameGreetingPanel"), "OnShow", GreetingRows)
    S.HookGlobal("QuestFrameGreetingPanel_OnShow", GreetingRows)
    S.HookGlobal("QuestFrameProgressItems_Update", QuestTextSoon)
  end
  local gossip = S.Get("GossipFrame")
  if S.Usable(gossip) and S.Once(gossip, "npcgossip") then
    S.Kill(S.Region(gossip, "Background"))
    local panel = S.Child(gossip, "GreetingPanel")
    local scrollBox = S.Child(panel, "ScrollBox")
    if S.Usable(scrollBox) then
      S.Plate(scrollBox, "inset")
      GossipHooks(gossip, scrollBox)
      GossipRows(scrollBox)
    end
    if ns.SkinScrollBar then
      ns.SkinScrollBar(S.Child(panel, "ScrollBar"))
    end
  end
end

-- Blizzard's colouring of quest strings and the quest layout, followed wherever they are shown.
local TEXT_HOOKS = { QuestInfo_Display = QuestTextSoon, QuestFrame_SetTitleTextColor = TitleColor,
  QuestFrame_SetTextColor = TextColor }
local hooked = {}
local function TextHooks()
  for name, fn in pairs(TEXT_HOOKS) do
    if not hooked[name] then
      hooked[name] = S.HookGlobal(name, fn)
    end
  end
end

S.Part("questlog", function()
  TextHooks()
  S.OnAddOn("Blizzard_WorldMap", SkinMap)
  -- the NPC windows are part of the game's own interface (or of a Blizzard addon loaded early)
  local function NPC()
    TextHooks()
    S.Defer(nil, SkinNPC)
  end
  NPC()
  S.OnAnyAddOn(NPC)
end)
