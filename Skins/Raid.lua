local addonName, ns = ...
local S = ns.S

-- Blizzard's raid frames and raid-style party frames (CompactUnitFrames) as the R2-Frames board draws them: flat
-- class bars shaded darker towards the bottom (Blizzard still colours them: class and health colours, dispel and
-- aggro highlights, out-of-range fading, role icons and auras stay its own), a dark slot background and the thin
-- round-ring pair (black inside, the theme's line outside), names in the body font; group titles in the head
-- font, muted, with a divider line after them; the raid manager's side panel in the theme panel. The board's
-- 3 px mana strip is Blizzard's power bar at Blizzard's height (sizes are Blizzard's: restyle only).
-- Only frames named as raid or party compact frames are touched (nameplates run the same Blizzard code). Restyle
-- only: textures and fonts, nothing written on Blizzard's frames, no values read (secret health doesn't matter
-- here). Blizzard sets a frame up again on option changes, so the look is put back after each setup (post-hooks);
-- what we draw on a frame is drawn out of combat.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local PATTERNS = { "^CompactRaidFrame%d+$", "^CompactRaidGroup%dMember%d$", "^CompactPartyFrameMember%d$" }
local BORDERS = { "horizTopBorder", "horizBottomBorder", "vertLeftBorder", "vertRightBorder", "horizDivider" }
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local SHADE = 0.38 -- the board's class fill runs from 82 % to 52 % of the class colour: a black shade to .38 at the foot

local function IsCompactFrame(frame)
  local name = S.Name(frame)
  if not name then
    return false
  end
  for _, pattern in ipairs(PATTERNS) do
    if name:find(pattern) then
      return true
    end
  end
  return false
end

-- Blizzard's bar fill swapped for a flat one: the bar's own texture keeps its layer and colour.
local function Flat(bar)
  local fill = S.Usable(bar) and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if S.IsRegion(fill) and fill.SetTexture then
    pcall(fill.SetTexture, fill, WHITE)
  end
end

-- After every setup: flat bars, Blizzard's background and borders invisible, the name in the body font.
local function Restyle(frame)
  Flat(S.Child(frame, "healthBar"))
  Flat(S.Child(frame, "powerBar"))
  S.Kill(S.Child(frame, "background"))
  for _, key in ipairs(BORDERS) do
    S.Kill(S.Child(frame, key))
  end
  local name = S.Child(frame, "name")
  if S.IsRegion(name) and name.SetFont then
    -- the board: the body font (the game's when the theme has none), 11 px, white with a shadow
    local font = S.Theme().font or {}
    name:SetFont(font.body or GAME_FONT, math.floor(11 * (font.body and font.bodySize or 1) + 0.5), "")
    if name.SetShadowOffset then
      name:SetShadowOffset(1, -1)
      name:SetShadowColor(0, 0, 0, 1)
    end
  end
end

-- Once per frame, out of combat: the dark slot fill behind (the board's barBg: the slot fill at .85), the thin ring
-- (the theme's titleLine outside, black inside) and the shade over the health fill.
local function Dress(frame)
  if not S.Once(frame, "raid") then
    return
  end
  local theme = S.Theme()
  local radius = S.Radius("bar") -- raid cells: the corner of the boards' bars
  if radius then
    -- rounded (Dusk, Dawn): the cell's track and one rounded line; the bars' fills cut to the cell's corners by a
    -- mask on each bar (anchored to the whole cell, so the health bar rounds on top and the power bar below)
    S.UI.RoundFill(frame, frame, radius, { theme.slot.fill[1], theme.slot.fill[2], theme.slot.fill[3], 0.85 },
      { sublevel = -8 })
    S.UI.RoundLine(frame, frame, radius, theme.titlebar.line)
  else
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints(frame)
    S.SetColor(fill, theme.slot.fill, 0.85)
    S.Outline(frame, frame, 0, 1, theme.titlebar.line, "BORDER")
    S.Outline(frame, frame, 1, 1, { 0, 0, 0, 1 }, "BORDER")
  end
  local health = S.Child(frame, "healthBar")
  local shade, tone
  if S.Usable(health) and health.CreateTexture then
    shade = health:CreateTexture(nil, "OVERLAY", nil, -8)
    shade:SetAllPoints(health)
    S.UI.Gradient(shade, { 0, 0, 0, SHADE }, { 0, 0, 0, 0 })
    tone = S.ToneOverlay(health, "OVERLAY", -7)
  end
  if radius then
    S.RoundBar(health, { shade, tone }, { box = frame, height = 40 })
    S.RoundBar(S.Child(frame, "powerBar"), nil, { box = frame, height = 40 })
  end
end

local function Style(frame)
  if not IsCompactFrame(frame) then
    return
  end
  Restyle(frame)
  if not S.Done(frame, "raid") then
    S.Defer("raid:" .. S.Name(frame), function()
      Dress(frame)
    end)
  end
end

-- Group titles and borders (raid groups, the compact party), the container's border, the manager panel.
local function StyleGroup(group)
  if not S.Usable(group) then
    return
  end
  local name = S.Name(group)
  local title = S.Child(group, "title") or (name and S.Get(name .. "Title"))
  local text = S.Usable(title) and title.GetFontString and title:GetFontString()
  if S.IsRegion(text) then
    S.Font(text, "head", "muted")
    -- a divider line from the title to the group's right edge (once)
    if S.Once(title, "raid") and title.CreateTexture then
      local line = title:CreateTexture(nil, "ARTWORK")
      line:SetHeight(1)
      line:SetPoint("LEFT", text, "RIGHT", 8, 0)
      line:SetPoint("RIGHT", group, "RIGHT", 0, 0)
      S.SetColor(line, S.Theme().divider)
    end
  end
  S.Kill(S.Child(group, "borderFrame") or (name and S.Get(name .. "BorderFrame")))
end

local function StyleManager()
  local manager = S.Get("CompactRaidFrameManager")
  if not S.Usable(manager) or not S.Once(manager, "raid") then
    return
  end
  -- Blizzard's own art on the panel (its direct textures; the buttons inside keep theirs)
  for _, region in ipairs({ manager:GetRegions() }) do
    if S.Usable(region) and region:GetObjectType() == "Texture" then
      S.Kill(region)
    end
  end
  S.Plate(manager, "panel", { corners = true, cornerSize = 12 })
end

local function Sweep()
  for index = 1, 40 do
    Style(S.Get("CompactRaidFrame" .. index))
  end
  for group = 1, 8 do
    StyleGroup(S.Get("CompactRaidGroup" .. group))
    for member = 1, 5 do
      Style(S.Get("CompactRaidGroup" .. group .. "Member" .. member))
    end
  end
  for member = 1, 5 do
    Style(S.Get("CompactPartyFrameMember" .. member))
  end
  StyleGroup(S.Get("CompactPartyFrame"))
  S.Kill(S.Child(S.Get("CompactRaidFrameContainer"), "BorderFrame"))
  StyleManager()
end

local function HookGroups()
  S.HookGlobal("CompactRaidGroup_InitializeForGroup", function(group)
    StyleGroup(group)
  end)
  S.HookGlobal("CompactRaidGroup_GenerateForGroup", function(index)
    if type(index) == "number" then
      StyleGroup(S.Get("CompactRaidGroup" .. index))
    end
  end)
  S.Defer("raid:sweep", Sweep)
end

S.Part("raidframes", function()
  -- every compact frame setup (raid, party, raid pets); nameplates are skipped by name
  for _, setup in ipairs({ "DefaultCompactUnitFrameSetup", "DefaultCompactMiniFrameSetup", "CompactUnitFrame_SetUpFrame" }) do
    S.HookGlobal(setup, Style)
  end
  -- the raid groups and the manager come with Blizzard_CompactRaidFrames
  if S.AddOnLoaded("Blizzard_CompactRaidFrames") or S.Get("CompactRaidFrameManager") then
    HookGroups()
  else
    S.OnAddOn("Blizzard_CompactRaidFrames", HookGroups)
  end
  Sweep()
  local events = CreateFrame("Frame")
  events:RegisterEvent("GROUP_ROSTER_UPDATE")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", function()
    S.Run("raidframes", function()
      S.Defer("raid:sweep", Sweep)
    end)
  end)
end)
