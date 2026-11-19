local addonName, ns = ...
local S = ns.S

-- Game windows: every window Blizzard registers as a panel (UIPanelWindows: character, spellbook and
-- talents, friends, merchant, gossip and quest dialogs, mail, bank, trainer, professions, ...) plus the
-- bags and a few others get the theme's panel, rings, corners and title bar in place of their NineSlice
-- border art. Their buttons get the theme's button look, the close button a theme button with a cross,
-- tabs the button look with an accent line on the selected one, search boxes the inset look and item slots
-- (character, bags, merchant, bank) the slot look. Content backgrounds (quest and gossip parchment, the
-- character model) stay, so their text stays readable. Look options: the soft shadow comes with the panel
-- (S.Plate), the decorative strip with S.Window / the detached holder, except on NPC dialogs (NPC_WINDOWS).
--
-- Windows from load-on-demand addons are picked up when those load. Some windows hold secure buttons
-- (spellbook): everything is built out of combat and only textures are drawn; Blizzard's layout code is
-- never called (the bags are followed with post-hooks on their own updates).

-- Windows that are not panels, or come with addons, by name (Forever, 12.x engine).
local EXTRA = { "ContainerFrameCombinedBags", "CharacterFrame", "PlayerSpellsFrame", "ProfessionsFrame",
  "ProfessionsBookFrame", "FriendsFrame", "MerchantFrame", "BankFrame", "GuildBankFrame", "MailFrame", "OpenMailFrame",
  "GossipFrame", "QuestFrame", "TradeFrame", "ClassTrainerFrame", "AuctionHouseFrame", "InspectFrame", "MacroFrame",
  "CommunitiesFrame", "CollectionsJournal", "EncounterJournal", "AchievementFrame", "TabardFrame", "PetitionFrame",
  "GuildRegistrarFrame", "TaxiFrame", "StableFrame", "PetStableFrame", "LFGParentFrame", "PVEFrame",
  "GroupLootHistoryFrame", "DressUpFrame", "ItemTextFrame", "LootFrame", "GameMenuFrame", "TimeManagerFrame",
  "ModelPreviewFrame", "AddonList", "SettingsPanel", "CooldownViewerSettings", "ChannelFrame", "HelpFrame" }

-- Left alone: the world map is the quest log part's; Edit Mode's window belongs to Edit Mode.
local EXCLUDED = { WorldMapFrame = true, EditModeManagerFrame = true, CalendarFrame = true } -- (the calendar: its own pass below)
-- NPC dialogs: no decorative strip (Look options) on them. Codex may draw these windows itself now (the Quest
-- windows module, Modules/Dialogue, the user's decision 2026-11-18): while it does, QuestFrame and GossipFrame are
-- parked off the screen at alpha 0 (still shown) and this restyle only shows when the player keeps the game's own.
local NPC_WINDOWS = { QuestFrame = true, GossipFrame = true }

local CHARACTER_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
  "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }

local keys = setmetatable({}, { __mode = "k" }) -- [frame] = { [kind] = S.Defer key }: one wait per frame and job
local function KeyOf(frame, kind)
  keys[frame] = keys[frame] or {}
  keys[frame][kind] = keys[frame][kind] or {}
  return keys[frame][kind]
end

-- Pieces (also used by the quest log part through ns) -------------------------------------------------------

local function ButtonLook()
  local style = S.Theme().button
  return { from = style.from, to = style.to, rings = { { inset = 0, color = style.line, size = 1 } } }
end

-- Small title-bar buttons (close, maximise / minimise) share one square box size, centred on the button,
-- so they line up whatever size Blizzard gives each button.
local SMALL_BOX = 20

-- A square button-look box of ours centred on `button` (dy moves it up / down to line up with another
-- button); returns the box texture (glyphs are anchored to it).
local function SquareBox(button, size, dy)
  local style = S.Theme().button
  local box = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  box:SetSize(size or SMALL_BOX, size or SMALL_BOX)
  box:SetPoint("CENTER", button, "CENTER", 0, dy or 0)
  S.UI.Gradient(box, style.from, style.to)
  S.Outline(button, box, 0, 1, style.line, "BORDER")
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(box)
  S.SetColor(hover, style.hover)
  return box
end
ns.SkinSquareBox = SquareBox
ns.SMALL_BOX = SMALL_BOX

local function KillButtonArt(button)
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
    if type(button[getter]) == "function" then
      S.Kill(button[getter](button))
    end
  end
end

-- The window's close button (UIPanelCloseButton): Blizzard's red art invisible, a theme box with a cross
-- drawn instead. The button itself is untouched.
local function CloseButton(button)
  if not S.Usable(button) or button:GetObjectType() ~= "Button" then
    return
  end
  -- a "Close" text button (the Options window's SettingsPanel.CloseButton) keeps the general button look:
  -- the cross went over its word
  local text = type(button.GetText) == "function" and button:GetText()
  if text ~= nil and (not canaccessvalue or canaccessvalue(text)) and type(text) == "string" and text:find("%S") then
    return
  end
  if not S.Once(button, "close") then
    return
  end
  KillButtonArt(button)
  local style = S.Theme().button
  local box = SquareBox(button)
  for _, angle in ipairs({ 45, -45 }) do
    local bar = button:CreateTexture(nil, "ARTWORK", nil, 7)
    S.SetColor(bar, style.text)
    bar:SetSize(11, 2)
    bar:SetPoint("CENTER", box, "CENTER")
    bar:SetRotation(math.rad(angle))
  end
end
ns.SkinCloseButton = CloseButton
ns.KillButtonArt = KillButtonArt

-- A search box (SearchBoxTemplate: Left / Middle / Right art): the inset look instead.
local function SearchBox(box)
  if not S.Usable(box) or not S.Region(box, "Middle") or not S.Once(box, "search") then
    return
  end
  S.KillKeys(box, "Left", "Middle", "Right")
  S.Plate(box, "inset", { left = 4 })
end
ns.SkinSearchBox = SearchBox

-- A button whose art is its icon (bag cleanup, keyring): slot rings round it, its art kept.
local function Ringed(button)
  if not S.Usable(button) or not S.Once(button, "ringed") then
    return
  end
  local look = S.Look("slot")
  S.Plate(button, { fill = look.fill, rings = look.rings }, { pad = S.RingDepth(look.rings), ringLayer = "OVERLAY" })
end

-- Tabs (PanelTabButtonTemplate: Left / Middle / Right and the Active or Disabled set): all of Blizzard's
-- art invisible, the button look, and on the selected tab the select shade with an accent line.
local tabs = setmetatable({}, { __mode = "k" }) -- [tab] = { shade, line }

local function IsTab(button)
  return S.IsPanelButton(button) and (S.Region(button, "LeftActive") or S.Region(button, "LeftDisabled")) ~= nil
end

local function Selected(tab)
  local active = S.Region(tab, "LeftActive")
  if active then
    return active:IsShown() and true or false
  end
  return tab.IsEnabled and not tab:IsEnabled() or false
end

local function PaintTab(tab, selected)
  local parts = tabs[tab]
  if not parts then
    return
  end
  if selected == nil then
    selected = Selected(tab)
  end
  parts.shade:SetShown(selected)
  parts.line:SetShown(selected)
  local text = tab.GetFontString and tab:GetFontString()
  if S.IsRegion(text) then
    local c = selected and S.Theme().accent or S.Theme().muted
    text:SetTextColor(c[1], c[2], c[3], 1)
  end
end

local function Tab(tab)
  if not IsTab(tab) or tabs[tab] then
    return
  end
  S.Once(tab, "button") -- not a plain panel button
  S.KillKeys(tab, "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftDisabled",
    "MiddleDisabled", "RightDisabled", "LeftHighlight", "MiddleHighlight", "RightHighlight")
  local theme = S.Theme()
  local plate = S.Plate(tab, ButtonLook(), { left = -4, right = -4, top = -2, bottom = -2 })
  local shade = tab:CreateTexture(nil, "BACKGROUND", nil, -6)
  shade:SetAllPoints(plate.fill)
  S.UI.Gradient(shade, theme.select.from, theme.select.to)
  local line = tab:CreateTexture(nil, "BORDER", nil, 2)
  line:SetPoint("BOTTOMLEFT", plate.fill, "BOTTOMLEFT", 1, 1)
  line:SetPoint("BOTTOMRIGHT", plate.fill, "BOTTOMRIGHT", -1, 1)
  line:SetHeight(2)
  S.SetColor(line, theme.accent)
  tabs[tab] = { shade = shade, line = line }
  -- tab systems (spellbook / talents, professions) mark their tab themselves
  S.HookMethod(tab, "SetTabSelected", function(self, selected)
    PaintTab(self, selected and true or false)
  end)
  PaintTab(tab)
end

-- A dialog header (GameMenuFrame.Header: LeftBG / CenterBG / RightBG and Text): the title bar look.
local function Header(frame)
  local header = S.Child(frame, "Header")
  local text = S.Region(header, "Text")
  if not text or not S.Region(header, "CenterBG") or not S.Once(header, "header") then
    return
  end
  S.KillKeys(header, "LeftBG", "CenterBG", "RightBG")
  local bar = S.Theme().titlebar
  S.Plate(header, { from = bar.from, to = bar.to, rings = { { inset = 0, color = bar.line, size = 1 } } },
    { left = -8, right = -8, top = -6, bottom = -6 })
  S.Font(text, "head", "titleText")
end

-- Item slots ----------------------------------------------------------------------------------------------

local function ItemSlot(button)
  if S.Slot(button) then
    -- the paper doll's slot frame art
    S.KillNamed(S.Name(button), "Frame")
  elseif S.Usable(button) then
    -- Blizzard sets the slot's frame art again on updates
    S.SlotArt(button)
  end
end

-- The item buttons of a bag window (or the bank panel).
local function BagItems(frame)
  if type(frame.EnumerateValidItems) == "function" then
    local ok = pcall(function()
      for _, button in frame:EnumerateValidItems() do
        ItemSlot(button)
      end
    end)
    if ok then
      return
    end
  end
  for _, button in ipairs(S.Child(frame, "Items") or {}) do
    ItemSlot(button)
  end
end

local function MoneyBox(frame)
  local border = S.Child(frame, "MoneyFrame", "Border")
  if S.Usable(border) and S.Region(border, "Middle") and S.Once(border, "money") then
    S.KillKeys(border, "Left", "Middle", "Right")
    S.Plate(border, "inset")
  end
end

-- Buttons of other Blizzard templates ----------------------------------------------------------------------

-- Three-slice buttons (the red Create / Create All: Left / Center / Right art).
local function IsThreeSlice(button)
  return S.Usable(button) and button:GetObjectType() == "Button" and S.Region(button, "Left") ~= nil
    and S.Region(button, "Center") ~= nil and S.Region(button, "Right") ~= nil
end

local function ThemeButtonText(button)
  local text = button.GetFontString and button:GetFontString()
  text = S.IsRegion(text) and text or S.Region(button, "Text")
  if not text then
    return
  end
  local theme = S.Theme()
  local enabled = not button.IsEnabled or button:IsEnabled()
  local c = enabled and theme.button.text or theme.muted
  text:SetTextColor(c[1], c[2], c[3], enabled and 1 or 0.6)
end

-- The theme's button look on a button whose art pieces are `keys` (made invisible).
local function ThemeButton(button, keys)
  if not S.Usable(button) or not S.Once(button, "button") then
    return
  end
  for _, key in ipairs(keys) do
    S.Kill(S.Region(button, key))
  end
  local plate = S.Plate(button, ButtonLook(), { left = -1, right = -1, top = -1, bottom = -1 })
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(plate.fill)
  S.SetColor(hover, S.Theme().button.hover)
  ThemeButtonText(button)
  S.HookScript(button, "OnEnable", ThemeButtonText)
  S.HookScript(button, "OnDisable", ThemeButtonText)
end

local THREE_SLICE = { "Left", "Center", "Right" }
-- UIMenuButtonStretchTemplate (nine pieces) and the newer filter dropdown (Background)
local STRETCH = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight",
  "BottomMiddle", "MiddleMiddle", "Left", "Center", "Middle", "Right", "Background" }

-- A minimal scroll bar (Track / Thumb with Begin / Middle / End art): an inset track and an accent thumb.
local function ScrollBar(bar)
  local track = S.Child(bar, "Track")
  if not S.Usable(track) or not S.Once(bar, "scrollbar") then
    return
  end
  S.KillKeys(track, "Begin", "Middle", "End")
  S.Plate(track, "inset")
  local thumb = S.Child(track, "Thumb")
  if S.Usable(thumb) then
    S.KillKeys(thumb, "Begin", "Middle", "End")
    local fill = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
    fill:SetPoint("TOPLEFT", thumb, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -1, 1)
    S.SetColor(fill, S.Theme().accent, 0.6)
  end
end
ns.SkinScrollBar = ScrollBar

-- Shared round-2 pieces (boards R2-Character, R2-Professions, R2-Bags) --------------------------------------

-- A number we may read (positions, sizes, bar values): nil when missing or secret.
local function ReadNum(region, method, ...)
  if not S.Usable(region) or type(region[method]) ~= "function" then
    return nil
  end
  local ok, value, second = pcall(region[method], region, ...)
  if not ok or type(value) ~= "number" then
    return nil
  end
  if canaccessvalue and not canaccessvalue(value) then
    return nil
  end
  return value, second
end

-- Theme icon tabs (side tabs with an icon: LargeSideTabButtonTemplate, the character sidebar tabs): the
-- tab's art invisible (its icon kept), a box of ours behind it. Selected (design `sel`): the title bar
-- gradient with a title-line ring; others (design `panel` / `btnLine`): the panel colour with a button-line
-- ring. The selected state follows Blizzard's SetChecked / SetTabSelected.
local iconTabs = setmetatable({}, { __mode = "k" }) -- [tab] = { fill, lines }

local function IconTabSelected(tab)
  if type(tab.GetChecked) == "function" then
    local ok, checked = pcall(tab.GetChecked, tab)
    if ok and checked ~= nil then
      return checked and true or false
    end
  end
  local selected = S.Region(tab, "SelectedTexture")
  if selected then
    return selected:IsShown() and true or false
  end
  return tab.isSelected and true or false
end

local function PaintIconTab(tab, selected)
  local parts = iconTabs[tab]
  if not parts then
    return
  end
  if selected == nil then
    selected = IconTabSelected(tab)
  end
  local theme = S.Theme()
  if selected then
    S.UI.Gradient(parts.fill, theme.titlebar.to, theme.titlebar.from)
  else
    local c = theme.panel.from
    parts.fill:SetColorTexture(c[1], c[2], c[3], 0.95)
  end
  local line = selected and theme.titlebar.line or theme.button.line
  for _, piece in ipairs(parts.lines) do
    S.SetColor(piece, line)
  end
  local icon = S.Region(tab, "Icon")
  if icon and icon.SetDesaturated then
    icon:SetDesaturated(not selected)
  end
end

-- The usual icon trim (0.08-0.92), only for a whole icon file: an atlas, or an icon cut from a sheet of icons
-- with its own tex coords, stays as Blizzard set it. The character sheet's Titles and Equipment Manager tabs take
-- their icons from one sheet (PAPERDOLL_SIDEBARS[i].icon + texCoords); the trim showed slices of the whole sheet
-- (the user's screenshot, 2026-11-19).
local function CropWholeIcon(icon)
  if not (S.IsRegion(icon) and icon.SetTexCoord and icon.GetTexCoord) then
    return
  end
  if icon.GetAtlas then
    local ok, atlas = pcall(icon.GetAtlas, icon)
    if not ok or (atlas ~= nil and atlas ~= "") then
      return
    end
  end
  local ok, ulx, uly, _, _, _, _, lrx, lry = pcall(icon.GetTexCoord, icon)
  if not ok then
    return
  end
  for _, value in ipairs({ ulx, uly, lrx, lry }) do
    if type(value) ~= "number" or (canaccessvalue and not canaccessvalue(value)) then
      return
    end
  end
  local whole = math.abs(ulx) < 0.001 and math.abs(uly) < 0.001 and math.abs(lrx - 1) < 0.001
    and math.abs(lry - 1) < 0.001
  if whole then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

local function IconTab(tab)
  if not S.Usable(tab) or iconTabs[tab] then
    return
  end
  local icon = S.Region(tab, "Icon")
  for _, region in ipairs({ tab:GetRegions() }) do
    if region ~= icon and S.IsRegion(region) and region:GetObjectType() == "Texture" then
      S.Kill(region)
    end
  end
  CropWholeIcon(icon)
  local fill = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints(tab)
  iconTabs[tab] = { fill = fill, lines = S.Outline(tab, tab, 0, 1, S.Theme().button.line, "BORDER") }
  local hover = tab:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(tab)
  S.SetColor(hover, S.Theme().button.hover)
  S.HookMethod(tab, "SetChecked", function(self, checked)
    PaintIconTab(self, checked and true or false)
  end)
  S.HookMethod(tab, "SetTabSelected", function(self, selected)
    PaintIconTab(self, selected and true or false)
  end)
  PaintIconTab(tab)
end
ns.SkinIconTab = IconTab

-- A heading rule: a line of ours from just after `label`'s text to `right`'s edge (design: section headings
-- are the accent heading text followed by a thin rule). Re-placed on every call (the text changes).
local rules = setmetatable({}, { __mode = "k" }) -- [label] = line
local function Rule(owner, label, right, rightPoint, gap)
  if not S.IsRegion(label) or not S.Usable(right) then
    return
  end
  local line = rules[label]
  if not line then
    line = owner:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    S.SetColor(line, S.Theme().divider)
    rules[label] = line
  end
  local width = ReadNum(label, "GetStringWidth") or 0
  line:ClearAllPoints()
  line:SetPoint("LEFT", label, "LEFT", width + 8, 0)
  line:SetPoint("RIGHT", right, rightPoint or "RIGHT", -(gap or 4), 0)
  local text = label.GetText and label:GetText()
  line:SetShown(type(text) == "string" and text ~= "")
end

-- Professions (ProfessionsFrame, Blizzard_Professions; board R2-Professions) --------------------------------
-- The recipe list on an inset (category headings: accent text and a rule; recipe rows with the theme's hover /
-- selected colours, difficulty colours kept), the skill bar slim (a dark 8 px track with an accent fill of
-- ours, sized from the bar's value), search / filter / quantity in the inset and button looks, the recipe page
-- plain with a divider line on its left and reagents in slots, Create in the primary look, the profession tabs
-- as theme icon tabs, and the professions overview (book page) without its card art. Codex's own profit block
-- and list (the Professions module) are Codex widgets: untouched.

local FLAT = "Interface\\Buttons\\WHITE8X8"

-- Blizzard's own status bar fill made flat and recoloured: Blizzard keeps sizing it from the real value.
-- Re-applied after Blizzard's updates (it may set its own art again). False when `bar` is no StatusBar.
local function FlatFill(bar, color)
  if not S.Usable(bar) or bar:GetObjectType() ~= "StatusBar" then
    return false
  end
  pcall(bar.SetStatusBarTexture, bar, FLAT)
  pcall(bar.SetStatusBarColor, bar, color[1], color[2], color[3], color[4] or 1)
  return true
end

local function Textures(frame, keep, fn)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region ~= keep and S.IsRegion(region) and region:GetObjectType() == "Texture" then
      fn(region)
    end
  end
end

-- A slim skill bar of ours over a Blizzard rank bar (bar.Fill is the StatusBar; .Background / .Border /
-- .Flare its art): Blizzard's fill made invisible (it stays the one that knows the value), a dark track
-- (design `barBg`, `line`) as wide as Blizzard's fill bar and 8 px tall on its middle, and an accent fill
-- (design `fill`: accent to a deeper accent) as wide as the value says. Values are only read.
local SLIM = 8
local slims = setmetatable({}, { __mode = "k" }) -- [bar] = { track, fill }

local function SlimWidth(bar, fill)
  local own = ReadNum(bar, "GetWidth")
  local override = bar.overrideWidth
  if type(override) == "number" and (not canaccessvalue or canaccessvalue(override)) and override > 0 then
    own = own and math.min(own, override) or override
  end
  local fillWidth = ReadNum(fill, "GetWidth")
  if own and fillWidth then
    return math.min(own, fillWidth)
  end
  return own or fillWidth
end

local function SlimUpdate(bar)
  local parts = slims[bar]
  local fill = S.Child(bar, "Fill")
  if not parts or not S.Usable(fill) then
    return
  end
  FlatFill(fill, { 0, 0, 0, 0 })
  -- our track spans the bar's own width: the narrower of the bar frame (on the book's cards also its
  -- overrideWidth) and its Fill, which Blizzard leaves at 441 px on the cards
  local width = SlimWidth(bar, fill)
  parts.track:ClearAllPoints()
  if width then
    parts.track:SetPoint("LEFT", fill, "LEFT")
    parts.track:SetWidth(width)
  else
    parts.track:SetPoint("LEFT", bar, "LEFT")
    parts.track:SetPoint("RIGHT", bar, "RIGHT")
  end
  local value = ReadNum(fill, "GetValue")
  local low, high = ReadNum(fill, "GetMinMaxValues")
  if not (value and low and high and width) or high <= low then
    parts.fill:Hide()
    return
  end
  local ratio = math.max(0, math.min(1, (value - low) / (high - low)))
  parts.fill:SetWidth(math.max(1, width * ratio))
  parts.fill:SetShown(ratio > 0)
end

local function SlimBar(bar)
  if not S.Usable(bar) then
    return
  end
  local fill = S.Child(bar, "Fill")
  if not slims[bar] and S.Usable(fill) then
    local theme = S.Theme()
    S.KillKeys(bar, "Background", "Border", "Flare")
    local track = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
    track:SetHeight(SLIM)
    track:SetPoint("LEFT", fill, "LEFT")
    track:SetColorTexture(0, 0, 0, 0.5)
    S.Outline(bar, track, 0, 1, theme.inset.line, "BORDER")
    local bright = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    bright:SetHeight(SLIM - 2)
    bright:SetPoint("LEFT", track, "LEFT", 1, 0)
    local a = theme.accent
    S.UI.Gradient(bright, { a[1] * 0.75, a[2] * 0.6, a[3] * 0.35 }, { a[1], a[2], a[3] })
    slims[bar] = { track = track, fill = bright }
    local text = S.Region(S.Child(bar, "Rank"), "Text") or S.Region(bar, "Text")
    if text then
      S.Font(text, "body", "bright")
    end
    -- Blizzard updates the bar (value and its own fill art)
    for _, method in ipairs({ "Update", "UpdateRank", "SetProfessionInfo" }) do
      S.HookMethod(bar, method, function()
        SlimUpdate(bar)
      end)
    end
    for _, method in ipairs({ "SetValue", "SetMinMaxValues" }) do
      S.HookMethod(fill, method, function()
        SlimUpdate(bar)
      end)
    end
  end
  SlimUpdate(bar)
end
ns.SkinSlimBar = SlimBar

-- A category heading (Forever: a row with a CollapseButton and a small RankBar, drawn as a gold-framed red
-- bar): all of the row's and the bar's art invisible, the name in the heading font and accent followed by a
-- rule up to the collapse button, the collapse mark muted.
local function CategoryRow(row)
  local theme = S.Theme()
  local rankBar = S.Child(row, "RankBar")
  local fillTexture = S.Usable(rankBar) and rankBar.GetStatusBarTexture and rankBar:GetStatusBarTexture() or nil
  if S.Once(row, "category") then
    Textures(row, nil, S.Kill)
    if S.Usable(rankBar) then
      Textures(rankBar, fillTexture, S.Kill)
      S.KillKeys(rankBar, "BorderLeft", "BorderMid", "BorderRight")
    end
  end
  FlatFill(rankBar, { 0, 0, 0, 0 })
  local label = S.Region(row, "Label") or S.Region(rankBar, "Rank") or S.Region(S.Child(rankBar, "Rank"), "Text")
  S.Font(label, "head", "accent")
  local collapse = S.Child(row, "CollapseButton")
  Rule(row, label, S.Usable(collapse) and collapse or row, S.Usable(collapse) and "LEFT" or "RIGHT", 6)
  if S.Usable(collapse) then
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
      local texture = type(collapse[getter]) == "function" and collapse[getter](collapse)
      if S.IsRegion(texture) and texture.SetVertexColor then
        if texture.SetDesaturated then
          texture:SetDesaturated(true)
        end
        texture:SetVertexColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
      end
    end
  end
end

-- One pooled row of the recipe list: a category heading or a recipe (Label + overlays).
local function RecipeRow(row)
  if not S.Usable(row) then
    return
  end
  if S.Child(row, "CollapseButton") then
    CategoryRow(row)
    return
  end
  local label = S.Region(row, "Label")
  if not label then
    return
  end
  local theme = S.Theme()
  S.Font(label, "body")
  for key, alpha in pairs({ SelectedOverlay = 0.32, HighlightOverlay = 0.16 }) do
    local overlay = S.Region(row, key)
    if overlay and overlay.SetVertexColor then
      if overlay.SetDesaturated then
        overlay:SetDesaturated(true)
      end
      overlay:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], alpha)
    end
  end
end

local function RecipeRows(scrollBox)
  if type(scrollBox.ForEachFrame) ~= "function" then
    return
  end
  local ok, err = pcall(scrollBox.ForEachFrame, scrollBox, RecipeRow)
  if not ok then
    S.Fail("windows", "recipe list: " .. tostring(err))
  end
end

local function RecipeList(list)
  if not S.Usable(list) or not S.Once(list, "recipes") then
    return
  end
  S.KillKeys(list, "BackgroundNineSlice", "Background")
  S.Plate(list, "inset")
  SearchBox(S.Child(list, "SearchBox"))
  ThemeButton(S.Child(list, "FilterButton") or S.Child(list, "FilterDropdown"), STRETCH)
  ScrollBar(S.Child(list, "ScrollBar"))
  local scrollBox = S.Child(list, "ScrollBox")
  if S.Usable(scrollBox) then
    -- rows are pooled: looked over after each of the list's updates (text and our own textures only)
    S.HookMethod(scrollBox, "Update", RecipeRows)
    RecipeRows(scrollBox)
  end
end

local function Reagent(slot)
  local button = S.Child(slot, "Button")
  if S.Usable(button) then
    ItemSlot(button)
  end
end

local function ReagentSlots(form)
  for _, list in pairs(S.Child(form, "reagentSlots") or {}) do
    if type(list) == "table" then
      for _, slot in ipairs(list) do
        Reagent(slot)
      end
    end
  end
  S.Walk(S.Child(form, "Reagents"), 1, Reagent)
end

-- The recipe page: Blizzard's background art invisible, no box of its own (design), a divider line on its
-- left edge between the list and the page.
local schematicKey = {} -- one wait for the reagent slots while in combat
local function Schematic(form)
  if not S.Usable(form) then
    return
  end
  if S.Once(form, "schematic") then
    S.KillKeys(form, "Background", "MinimalBackground", "NineSlice")
    local line = form:CreateTexture(nil, "BORDER")
    line:SetWidth(1)
    line:SetPoint("TOPLEFT", form, "TOPLEFT")
    line:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT")
    S.SetColor(line, S.Theme().divider)
    -- a recipe is shown through Init: its reagent slots are (re)built then
    S.HookMethod(form, "Init", function()
      S.Defer(schematicKey, function()
        ReagentSlots(form)
      end)
    end)
  end
  ReagentSlots(form)
end

-- Create in the primary look (design `primary`: the title bar's gradient, an accent line, bright text).
local function PrimaryButton(button)
  if not IsThreeSlice(button) and not S.IsPanelButton(button) then
    return
  end
  if not S.Once(button, "button") then
    return
  end
  local theme = S.Theme()
  for _, key in ipairs({ "Left", "Center", "Middle", "Right" }) do
    S.Kill(S.Region(button, key))
  end
  local plate = S.Plate(button, { from = theme.titlebar.from, to = theme.titlebar.to,
    rings = { { inset = 0, color = theme.accent, size = 1 } } }, { left = -1, right = -1, top = -1, bottom = -1 })
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(plate.fill)
  S.SetColor(hover, theme.button.hover)
  local function Color(self)
    local text = self.GetFontString and self:GetFontString()
    if S.IsRegion(text) then
      local enabled = not self.IsEnabled or self:IsEnabled()
      local c = enabled and theme.bright or theme.muted
      text:SetTextColor(c[1], c[2], c[3], enabled and 1 or 0.6)
    end
  end
  Color(button)
  S.HookScript(button, "OnEnable", Color)
  S.HookScript(button, "OnDisable", Color)
end

-- The professions overview (Forever's book page): card art invisible, profession names in the accent heading
-- font, slim skill bars, spell buttons in the slot look with light text.
local PROFESSION_CARDS = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1",
  "SecondaryProfession2", "SecondaryProfession3" }

local function ProfessionSpellText(button)
  local theme = S.Theme()
  for key, color in pairs({ spellString = theme.text, subSpellString = theme.muted }) do
    local text = S.Region(button, key)
    if text then
      text:SetTextColor(color[1], color[2], color[3], 1)
    end
  end
end

local function ProfessionSpell(button)
  if not S.Usable(button) or not S.Once(button, "profspell") then
    return
  end
  -- one look only: marked as a done slot so no other pass (the slot look of the bars and bags) dresses it again
  S.Once(button, "slot")
  local icon = S.Region(button, "IconTexture") or S.Region(button, "icon")
  -- Blizzard's own frame round the icon: the overlay ring, the slot frame (normal texture), the spell glow
  S.KillKeys(button, "IconTextureOverlay", "SpellHighlightTexture", "Border", "NormalTexture")
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if S.IsRegion(normal) and normal ~= icon then
    S.Kill(normal)
  end
  if icon then
    local mask = S.Child(button, "OutlineMask")
    if mask and icon.RemoveMaskTexture then
      pcall(icon.RemoveMaskTexture, icon, mask)
    end
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- a single thin ring tight round the icon (the slot look's line colour)
    S.Outline(button, icon, -1, 1, S.LineColor(S.Look("slot").rings), "OVERLAY", 1)
  end
  ProfessionSpellText(button)
  S.HookMethod(button, "UpdateButton", ProfessionSpellText)
end

local function ProfessionCard(card)
  if not S.Usable(card) then
    return
  end
  if S.Once(card, "profcard") then
    Textures(card, nil, S.Kill)
    for _, key in ipairs({ "ProfessionName", "professionName", "Name" }) do
      local name = S.Region(card, key)
      if name then
        S.Font(name, "head", "accent")
      end
    end
  end
  SlimBar(S.Child(card, "StatusBar"))
  for _, button in ipairs(S.Child(card, "spellButtons") or {}) do
    ProfessionSpell(button)
  end
end

local function Overview(frame)
  local book = S.Child(frame, "BookPage")
  if not S.Usable(book) then
    return
  end
  local content = S.Child(book, "ProfessionsContentFrame")
  if S.Once(book, "overview") then
    Textures(book, nil, S.Kill)
    if S.Usable(content) then
      Textures(content, nil, S.Kill)
    end
    S.HookScript(book, "OnShow", function()
      Overview(frame)
    end)
  end
  for _, key in ipairs(PROFESSION_CARDS) do
    ProfessionCard(S.Child(content, key))
  end
end

local function Professions(frame)
  local page = S.Child(frame, "CraftingPage")
  if page then
    RecipeList(S.Child(page, "RecipeList"))
    SlimBar(S.Child(page, "RankBar"))
    Schematic(S.Child(page, "SchematicForm"))
    SearchBox(S.Child(page, "CreateMultipleInputBox"))
    PrimaryButton(S.Child(page, "CreateButton"))
    for _, key in ipairs({ "CreateAllButton", "ViewGuildCraftersButton" }) do
      local button = S.Child(page, key)
      if IsThreeSlice(button) then
        ThemeButton(button, THREE_SLICE)
      elseif S.IsPanelButton(button) then
        S.Button(button)
      end
    end
  end
  Overview(frame)
  IconTab(S.Child(frame, "ProfessionsOverviewTab"))
  for _, tab in ipairs(S.Child(frame, "rightProfessionTabs") or {}) do
    IconTab(tab)
  end
  -- the top tab system (when shown) marks its selected tab itself
  local tabSystem = S.Child(frame, "TabSystem")
  if S.Usable(tabSystem) and S.Once(tabSystem, "tabsystem") then
    S.HookMethod(tabSystem, "SetTabVisuallySelected", function()
      S.Walk(tabSystem, 1, function(tab)
        PaintTab(tab)
      end)
    end)
  end
end

-- Mail (MailFrame: inbox and send pages; OpenMailFrame: the letter) ----------------------------------------
-- Parchment and stationery invisible, the letter on an inset with light text, attachment / item slots in the
-- slot look (icons cropped), money boxes as insets with their coin icons, the radios tinted, the separator
-- bars as theme divider lines, the money-on-hand box as an inset, the page arrows ringed.

local function Textures(frame, keep, fn)
  if not S.Usable(frame) then
    return
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    if not (keep and keep[region]) and S.IsRegion(region) and region:GetObjectType() == "Texture" then
      fn(region)
    end
  end
end

local function Crop(icon)
  if S.IsRegion(icon) and icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

-- An attachment / mail item slot: its slot art invisible (the icon, quality border and highlight kept), the
-- theme slot fill and rings; the icon cropped on every update (Blizzard sets it again).
local function MailSlot(button, icon)
  if not S.Usable(button) then
    return
  end
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  normal = S.IsRegion(normal) and normal or nil
  icon = icon or S.Region(button, "icon") or S.Region(button, "Icon") or normal
  if S.Once(button, "mailslot") then
    local keep = {}
    if icon then
      keep[icon] = true
    end
    local border = S.Region(button, "IconBorder")
    if border then
      keep[border] = true
    end
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if S.IsRegion(highlight) then
      keep[highlight] = true
    end
    Textures(button, keep, S.Kill)
    local look = S.Look("slot")
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetAllPoints(button)
    -- see-through (design token `empty`: the text colour at 7 %) so an empty slot reads light, not black
    local text = S.Theme().text
    fill:SetColorTexture(text[1], text[2], text[3], 0.07)
    for _, ring in ipairs(look.rings) do
      S.Outline(button, button, ring.inset, ring.size, ring.color, "OVERLAY", 1)
    end
  end
  Crop(icon)
end

-- A money input (gold / silver / copper): Left / Middle / Right art (by key or name) invisible, an inset.
local function MoneyInput(box)
  if not S.Usable(box) or not S.Once(box, "moneyinput") then
    return
  end
  local name = S.Name(box)
  for _, key in ipairs({ "Left", "Middle", "Right" }) do
    S.Kill(S.Region(box, key) or (name and S.Get(name .. key)))
  end
  S.Plate(box, "inset", { left = 4, right = -12 })
end

local function Radio(button)
  if not S.Usable(button) or not S.Once(button, "radio") then
    return
  end
  local theme = S.Theme()
  S.Tint(button.GetNormalTexture and button:GetNormalTexture(), theme.button.line)
  S.Tint(button.GetCheckedTexture and button:GetCheckedTexture(), theme.accent)
end

-- A theme divider line across `frame` at the top or bottom edge of `anchor` (the attachment row).
local function Divider(frame, anchor, edge, offset)
  local line = frame:CreateTexture(nil, "ARTWORK", nil, 1)
  line:SetHeight(1)
  line:SetPoint("LEFT", frame, "LEFT", 6, 0)
  line:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
  line:SetPoint(edge, anchor, edge, 0, offset)
  S.SetColor(line, S.Theme().divider)
end

-- The letter text (body and invoices) in the theme's text colour; Blizzard sets it through these font
-- objects and on the strings themselves, so both are set after its updates.
local function LetterText()
  local theme = S.Theme()
  for _, name in ipairs({ "MailTextFontNormal", "InvoiceTextFontNormal" }) do
    local font = S.Get(name)
    if font and font.SetTextColor then
      font:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)
    end
  end
  for _, path in ipairs({ "SendMailBodyEditBox", "MailEditBox.ScrollBox.EditBox", "OpenMailBodyText" }) do
    local text = S.Get(path)
    if S.Usable(text) and text.SetTextColor then
      local ok, kind = pcall(text.GetObjectType, text)
      if ok and kind == "SimpleHTML" then
        -- Forever's OpenMailBodyText is a SimpleHTML (MailFrame.xml): its colours and fonts are per tag
        -- (SetTextColor(textType, r, g, b)); the plain call broke the whole windows part (the user's chat, 2026-11-20)
        for _, tag in ipairs({ "P", "H1", "H2", "H3" }) do
          pcall(text.SetTextColor, text, tag, theme.text[1], theme.text[2], theme.text[3], 1)
        end
      else
        text:SetTextColor(theme.text[1], theme.text[2], theme.text[3], 1)
        S.Font(text, "body")
      end
    end
  end
end

local function Letter(scroll)
  if not S.Usable(scroll) or not S.Once(scroll, "letter") then
    return
  end
  Textures(scroll, nil, S.Kill)
  S.Plate(scroll, "inset")
  ScrollBar(S.Child(scroll, "ScrollBar"))
end

-- Send attachments show their item as the button's normal texture; an empty slot shows only our slot look
-- (if Blizzard gives the empty slot an emblem as its normal texture, that is made invisible).
local function SendAttachments()
  for index = 1, (type(ATTACHMENTS_MAX_SEND) == "number" and ATTACHMENTS_MAX_SEND or 12) do
    local button = S.Get("SendMailAttachment" .. index)
    if S.Usable(button) then
      local normal = button.GetNormalTexture and button:GetNormalTexture()
      local hasItem = true
      if GetSendMailItem then
        local name, itemID, texture = GetSendMailItem(index)
        hasItem = (name or itemID or texture) ~= nil
      end
      if S.IsRegion(normal) then
        normal:SetAlpha(hasItem and 1 or 0)
      end
      MailSlot(button, S.IsRegion(normal) and normal or nil)
    end
  end
  LetterText()
end

local function OpenAttachments()
  for index = 1, (type(ATTACHMENTS_MAX_RECEIVE) == "number" and ATTACHMENTS_MAX_RECEIVE or 16) do
    MailSlot(S.Get("OpenMailAttachmentButton" .. index))
  end
  MailSlot(S.Get("OpenMailLetterButton"), S.Get("OpenMailLetterButtonIconTexture"))
  MailSlot(S.Get("OpenMailMoneyButton"), S.Get("OpenMailMoneyButtonIconTexture"))
  LetterText()
end

local function InboxItems()
  local count = type(INBOXITEMS_TO_DISPLAY) == "number" and INBOXITEMS_TO_DISPLAY or 7
  for index = 1, count do
    local item = S.Get("MailItem" .. index)
    if S.Usable(item) and S.Once(item, "mailitem") then
      Textures(item, nil, S.Kill)
    end
    local button = S.Child(item, "Button") or S.Get("MailItem" .. index .. "Button")
    MailSlot(button, S.Region(button, "Icon"))
  end
end

-- The window's inset (MailFrame.Inset, an art-only frame: Blizzard's own code never puts content in it) made
-- invisible: the inbox list and the letter have insets of their own, and two insets on top of each other read
-- as solid black; without it the band under the title is the plain panel, like the board's windows.
local function OwnInsetOff(inset)
  S.Kill(inset)
end

-- A page arrow (inbox Prev / Next): Blizzard's art invisible, the small square button of ours with our arrow,
-- on the middle height of `beside` (Open All) so the row lines up.
local function PageArrow(button, rotation, beside)
  if not S.Usable(button) or not S.Once(button, "pagearrow") then
    return
  end
  KillButtonArt(button)
  local dy = 0
  local mine = ReadNum(button, "GetTop")
  local mineBottom = ReadNum(button, "GetBottom")
  local theirs, theirsBottom = ReadNum(beside, "GetTop"), ReadNum(beside, "GetBottom")
  if mine and mineBottom and theirs and theirsBottom then
    dy = (theirs + theirsBottom) / 2 - (mine + mineBottom) / 2
  end
  local box = SquareBox(button, 22, dy)
  local arrow = button:CreateTexture(nil, "ARTWORK", nil, 7)
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetSize(10, 10)
  arrow:SetPoint("CENTER", box, "CENTER")
  arrow:SetRotation(rotation)
  local accent = S.Theme().accent
  arrow:SetVertexColor(accent[1], accent[2], accent[3], 1)
end

local function Mail(frame)
  if S.Once(frame, "mail") then
    OwnInsetOff(S.Child(frame, "Inset"))
    -- inbox
    local inbox = S.Get("InboxFrame")
    Textures(inbox, nil, S.Kill)
    local first = S.Get("MailItem1")
    local last = S.Get("MailItem" .. (type(INBOXITEMS_TO_DISPLAY) == "number" and INBOXITEMS_TO_DISPLAY or 7))
    if S.Usable(inbox) and first and last then
      S.Plate(inbox, "inset", { topLeft = first, bottomRight = last })
    end
    local openAll = S.Get("OpenAllMail")
    PageArrow(S.Child(inbox, "PrevPageButton") or S.Get("InboxPrevPageButton"), math.pi, openAll)
    PageArrow(S.Child(inbox, "NextPageButton") or S.Get("InboxNextPageButton"), 0, openAll)
    -- send page
    local send = S.Get("SendMailFrame")
    Textures(send, nil, S.Kill)
    S.KillKeys(_G, "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight", "SendMailMoneyBg")
    Letter(S.Get("SendMailScrollFrame"))
    for _, name in ipairs({ "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do
      MoneyInput(S.Get(name))
    end
    Radio(S.Get("SendMailSendMoneyButton"))
    Radio(S.Get("SendMailCODButton"))
    local moneyBox = S.Get("SendMailMoneyInset")
    if S.Usable(moneyBox) then
      Textures(moneyBox, nil, S.Kill)
      S.Plate(moneyBox, "inset")
    end
    local attachment = S.Get("SendMailAttachment1")
    if S.Usable(send) and attachment then
      Divider(send, attachment, "TOP", 6)
      Divider(send, attachment, "BOTTOM", -6)
    end
    -- Blizzard's own updates (slots refilled, letter text coloured)
    S.HookGlobal("SendMailFrame_Update", SendAttachments)
    if not S.HookMethod(inbox, "Update", InboxItems) then
      S.HookGlobal("InboxFrame_Update", InboxItems)
    end
  end
  InboxItems()
  SendAttachments()
end

local function OpenMail(frame)
  if S.Once(frame, "openmail") then
    S.KillKeys(_G, "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight", "OpenMailArithmeticLine")
    Letter(S.Get("OpenMailScrollFrame"))
    if not S.HookMethod(frame, "Update", OpenAttachments) then
      S.HookGlobal("OpenMail_Update", OpenAttachments)
    end
  end
  OpenAttachments()
end

-- Books, letters and plaques you read (ItemTextFrame, Forever Mainline ItemTextFrame.xml): the parchment
-- (ItemTextFramePageBg, the four ItemTextMaterial* pieces) and the book icon on the corner (an unnamed OVERLAY -1
-- texture) invisible, the page on our inset, the scroll bar and Prev / Next in our look. The text is a SimpleHTML
-- (ItemTextPageText) whose colours Blizzard sets per tag on every page (OnEvent, from the item's material): set
-- again after it, P in the text colour, H1-H3 in the accent. The user's screenshot, 2026-11-19.
local function ItemTextColors()
  local text = S.Get("ItemTextPageText")
  if not (S.Usable(text) and text.SetTextColor) then
    return
  end
  local theme = S.Theme()
  pcall(text.SetTextColor, text, "P", theme.text[1], theme.text[2], theme.text[3])
  for _, tag in ipairs({ "H1", "H2", "H3" }) do
    pcall(text.SetTextColor, text, tag, theme.accent[1], theme.accent[2], theme.accent[3])
  end
  local page = S.Get("ItemTextCurrentPage")
  if S.IsRegion(page) then
    page:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  end
end

local function BookIcon(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.IsRegion(region) and region:GetObjectType() == "Texture" and not S.Name(region)
      and type(region.GetDrawLayer) == "function" then
      local ok, layer, sublevel = pcall(region.GetDrawLayer, region)
      if ok and layer == "OVERLAY" and sublevel == -1 then
        S.Kill(region)
      end
    end
  end
end

local function ItemText(frame)
  if S.Once(frame, "itemtext") then
    BookIcon(frame)
    S.KillKeys(_G, "ItemTextFramePageBg", "ItemTextMaterialTopLeft", "ItemTextMaterialTopRight",
      "ItemTextMaterialBotLeft", "ItemTextMaterialBotRight")
    Letter(S.Get("ItemTextScrollFrame"))
    PageArrow(S.Get("ItemTextPrevPageButton"), math.pi)
    PageArrow(S.Get("ItemTextNextPageButton"), 0)
    S.HookScript(frame, "OnEvent", ItemTextColors)
  end
  ItemTextColors()
end

-- Extra content per window, run each time it opens.
local CONTENT = {
  ProfessionsFrame = Professions,
  MailFrame = Mail,
  OpenMailFrame = OpenMail,
  ItemTextFrame = ItemText,
  CharacterFrame = function()
    for _, slot in ipairs(CHARACTER_SLOTS) do
      ItemSlot(S.Get("Character" .. slot .. "Slot"))
    end
  end,
  MerchantFrame = function()
    for index = 1, 12 do
      ItemSlot(S.Get("MerchantItem" .. index .. "ItemButton"))
    end
    ItemSlot(S.Get("MerchantBuyBackItemItemButton"))
  end,
  BankFrame = function(frame)
    local panel = S.Child(frame, "BankPanel") or S.Get("BankPanel")
    if panel then
      BagItems(panel)
    end
    for index = 1, 28 do
      ItemSlot(S.Get("BankFrameItem" .. index))
    end
  end,
}

local function IsBag(name)
  return name and (name == "ContainerFrameCombinedBags" or name:match("^ContainerFrame%d+$")) and true or false
end

-- Bag pieces: the search box and cleanup button are shared and move to whichever bag shows them.
local function BagPieces(frame)
  BagItems(frame)
  MoneyBox(frame)
  SearchBox(S.Get("BagItemSearchBox"))
  Ringed(S.Get("BagItemAutoSortButton"))
  Ringed(S.Get("KeyRingButton"))
end

-- Tabs and panel buttons, found by walking the window's child frames. That walk is the costly part, so it
-- runs once per window and again only when the window's own child count has changed (new content).
local dressed = setmetatable({}, { __mode = "k" }) -- [frame] = child count at the last walk
local function DressChild(child)
  Tab(child)
  if S.IsPanelButton(child) then
    S.Button(child)
  elseif IsThreeSlice(child) then
    ThemeButton(child, THREE_SLICE)
  end
end
local function Dress(frame)
  local count = select("#", frame:GetChildren())
  if dressed[frame] == count then
    return
  end
  dressed[frame] = count
  S.Walk(frame, 5, DressChild)
end

-- Light theme (Dawn): every text in the window at the time it opens is kept readable on the light panel
-- (S.GameText: its colour and colour codes now and after Blizzard's later setters, e.g. a stat turning green or a
-- red "Requires level"). Texts without a colour of their own already follow the recoloured game fonts
-- (S.GameFonts). Rows a list makes later use those fonts too. Nothing on a dark theme.
local TEXT_DEPTH = 6
local function GameTexts(frame)
  if not S.Theme().light then
    return
  end
  local function Regions(owner)
    if not owner.GetRegions then
      return
    end
    for _, region in ipairs({ owner:GetRegions() }) do
      if S.IsRegion(region) and region:GetObjectType() == "FontString" then
        S.GameText(region)
      end
    end
  end
  Regions(frame)
  S.Walk(frame, TEXT_DEPTH, Regions)
end
S.WindowTexts = GameTexts

local function Content(frame)
  -- the window's own pieces first (they claim special buttons, e.g. Create in the primary look), then
  -- every other tab and button in the general look
  local name = S.Name(frame)
  if CONTENT[name] then
    CONTENT[name](frame)
  end
  Dress(frame)
  CloseButton(S.Child(frame, "CloseButton") or (S.Name(frame) and S.Get(S.Name(frame) .. "CloseButton")))
  Header(frame)
  if IsBag(name) then
    BagPieces(frame)
  end
  GameTexts(frame)
end

local function Later(frame)
  S.Defer(KeyOf(frame, "content"), function()
    Content(frame)
  end)
end

-- Bags fill and re-lay out after they open: their own update methods are followed. These fire often and
-- together, so the bag pieces are looked over once per bag on the next frame (out of combat).
local soon = setmetatable({}, { __mode = "k" }) -- [frame] = true while a pass is queued
local function BagSoon(frame)
  if soon[frame] then
    return
  end
  soon[frame] = true
  C_Timer.After(0, function()
    soon[frame] = nil
    S.Run("windows", S.Defer, KeyOf(frame, "bag"), function()
      BagPieces(frame)
    end)
  end)
end

local function HookBag(frame)
  for _, method in ipairs({ "UpdateItems", "UpdateSearchBox", "UpdateItemLayout", "UpdateFrameSize" }) do
    S.HookMethod(frame, method, function()
      BagSoon(frame)
    end)
  end
end

-- Layout frames (ResizeLayoutFrame and the like) size themselves from their children and regions: art
-- reaching outside them (corner studs) or a child overlay could make them grow. Their look is drawn on a
-- frame of ours, parented to UIParent and laid over the window just below it, shown and hidden with it.
local function Secret(value)
  if issecretvalue then
    return issecretvalue(value) and true or false
  end
  if canaccessvalue then
    return not canaccessvalue(value)
  end
  return false
end

-- (BaseLayoutMixin:IsLayoutFrame returns true)
local function IsLayoutFrame(frame)
  return type(frame.IsLayoutFrame) == "function" and frame:IsLayoutFrame() == true
end

-- Windows whose box is much larger than what they show (Forever's game menu): our panel is fitted round
-- their shown buttons instead, with this padding; the top follows the header plate's middle when it has
-- one (the header sits over the panel's top edge like a title tab).
local FIT = { GameMenuFrame = { side = 12, bottom = 10, top = 18 } }
local holders = setmetatable({}, { __mode = "k" }) -- [window] = our panel frame

local function Edge(region, method)
  if type(region[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(region[method], region)
  if ok and type(value) == "number" and not Secret(value) then
    return value
  end
end

-- Anchors the panel round the window's shown buttons (positions only read, never written); the whole
-- window box when nothing can be measured.
local function FitHolder(frame)
  local holder, pad = holders[frame], FIT[S.Name(frame) or ""]
  if not holder or not pad then
    return
  end
  local left, right, top, bottom
  local function Take(button)
    if S.Usable(button) and button:GetObjectType() == "Button" and button:IsShown() then
      local l, r, t, b = Edge(button, "GetLeft"), Edge(button, "GetRight"), Edge(button, "GetTop"), Edge(button, "GetBottom")
      if l and r and t and b then
        left, right = math.min(left or l, l), math.max(right or r, r)
        top, bottom = math.max(top or t, t), math.min(bottom or b, b)
      end
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    Take(child)
  end
  local pool = S.Child(frame, "buttonPool")
  if pool and type(pool.EnumerateActive) == "function" then
    pcall(function()
      for button in pool:EnumerateActive() do
        Take(button)
      end
    end)
  end
  local fl, fr, ft, fb = Edge(frame, "GetLeft"), Edge(frame, "GetRight"), Edge(frame, "GetTop"), Edge(frame, "GetBottom")
  local fs, hs = Edge(frame, "GetEffectiveScale"), Edge(holder, "GetEffectiveScale")
  holder:ClearAllPoints()
  if not (left and fl and fr and ft and fb and fs and hs and hs > 0) then
    holder:SetAllPoints(frame)
    return
  end
  local scale = fs / hs
  local topEdge = top + pad.top
  local header = S.Child(frame, "Header")
  if S.Usable(header) and header:IsShown() then
    local ht, hb = Edge(header, "GetTop"), Edge(header, "GetBottom")
    if ht and hb then
      topEdge = (ht + hb) / 2
    end
  end
  holder:SetPoint("TOPLEFT", frame, "TOPLEFT", (left - pad.side - fl) * scale, (topEdge - ft) * scale)
  holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", (right + pad.side - fr) * scale, (bottom - pad.bottom - fb) * scale)
end

-- Fitted again each time the window shows (its buttons differ) and once more on the next frame, after
-- Blizzard has laid them out; out of combat.
local function Refit(frame)
  if not FIT[S.Name(frame) or ""] then
    return
  end
  S.Defer(KeyOf(frame, "fit"), function()
    FitHolder(frame)
  end)
  C_Timer.After(0, function()
    S.Run("windows", S.Defer, KeyOf(frame, "fit"), function()
      FitHolder(frame)
    end)
  end)
end

local function DetachedWindow(frame)
  local border = S.Child(frame, "Border")
  if not S.Child(frame, "NineSlice") and not S.Child(border, "TopLeftCorner") then
    return false
  end
  S.Once(frame, "window")
  S.KillKeys(frame, "NineSlice", "Border", "Bg")
  local holder = CreateFrame("Frame", nil, UIParent)
  holders[frame] = holder
  holder:SetAllPoints(frame)
  holder:EnableMouse(false)
  local strata = frame:GetFrameStrata()
  if type(strata) == "string" and not Secret(strata) then
    holder:SetFrameStrata(strata)
  end
  local level = frame:GetFrameLevel()
  if type(level) == "number" and not Secret(level) then
    holder:SetFrameLevel(math.max(0, level - 1))
  end
  local plate = S.Plate(holder, "panel", { corners = true })
  if not NPC_WINDOWS[S.Name(frame) or ""] then
    S.Strip(holder, plate.fill, { caps = not plate.corners and "both" or false })
  end
  holder:SetShown(frame:IsShown() and true or false)
  S.HookScript(frame, "OnShow", function()
    holder:Show()
    Refit(frame)
  end)
  S.HookScript(frame, "OnHide", function()
    holder:Hide()
  end)
  if frame:IsShown() then
    Refit(frame)
  end
  return true
end

-- Round 2: character sheet, spellbook, talents and the bank (boards R2-Character, R2-Bags) -------------------
-- Forever's frame names were read from ElvUI's Forever skin (names only, no code copied).

-- Dark text (parchment colours) made the theme's text colour; coloured text stays.
local function Light(fontString, color)
  if not S.IsRegion(fontString) or not fontString.GetTextColor then
    return
  end
  local r, g, b = fontString:GetTextColor()
  if type(r) ~= "number" or (canaccessvalue and not canaccessvalue(r)) then
    return
  end
  if r * 0.3 + g * 0.59 + b * 0.11 < 0.35 then
    local c = color or S.Theme().text
    fontString:SetTextColor(c[1], c[2], c[3], 1)
  end
end

local function LightAll(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.IsRegion(region) and region:GetObjectType() == "FontString" then
      Light(region)
    end
  end
end

-- Character sheet (Forever: two panes and side tabs) --------------------------------------------------------

-- The stats list (a ScrollBox): category headings as accent heading text with a rule (no Blizzard bars),
-- rows without the alternating stripes, labels muted.
local function StatRow(row)
  if not S.Usable(row) then
    return
  end
  S.Kill(S.Region(row, "Background"))
  local title = S.Region(row, "Title")
  if title then
    S.Font(title, "head", "accent")
    Rule(row, title, row, "RIGHT", 4)
    return
  end
  local label = S.Region(row, "Label")
  if label then
    local muted = S.Theme().muted
    label:SetTextColor(muted[1], muted[2], muted[3], 1)
  end
end

local function StatRows(scrollBox)
  if type(scrollBox.ForEachFrame) == "function" then
    local ok, err = pcall(scrollBox.ForEachFrame, scrollBox, StatRow)
    if not ok then
      S.Fail("windows", "stats: " .. tostring(err))
    end
  end
end

local function StatsPane(pane)
  if not S.Usable(pane) or not S.Once(pane, "stats") then
    return
  end
  Textures(pane, nil, S.Kill)
  S.Kill(S.Region(pane, "ClassBackground"))
  ScrollBar(S.Child(pane, "ScrollBar"))
  local box = S.Child(pane, "ScrollBox")
  if S.Usable(box) then
    S.HookMethod(box, "Update", StatRows)
    StatRows(box)
  end
end

-- The model's area: the race art invisible, a soft backdrop of ours (design `backdrop`: a dark gradient with
-- a faint accent glow in the middle) and an inset line.
local function ModelScene(scene)
  if not S.Usable(scene) or not S.Once(scene, "model") then
    return
  end
  S.KillKeys(scene, "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight",
    "BackgroundOverlay")
  local theme = S.Theme()
  local back = scene:CreateTexture(nil, "BACKGROUND", nil, -8)
  back:SetAllPoints(scene)
  S.UI.Gradient(back, { theme.panel.from[1] * 0.7, theme.panel.from[2] * 0.7, theme.panel.from[3] * 0.7, 1 },
    { theme.panel.to[1], theme.panel.to[2], theme.panel.to[3], 1 })
  local glow = scene:CreateTexture(nil, "BACKGROUND", nil, -7)
  glow:SetPoint("TOPLEFT", scene, "TOPLEFT", 20, -20)
  glow:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", -20, 60)
  local a = theme.accent
  S.UI.Gradient(glow, { a[1], a[2], a[3], 0 }, { a[1], a[2], a[3], 0.12 })
  S.Outline(scene, scene, 0, 1, theme.inset.line, "BORDER")
end

local function CharacterSheet(frame)
  local theme = S.Theme()
  if S.Once(frame, "sheet") then
    Textures(S.Child(frame, "LeftPaneHost") or {}, nil, S.Kill)
    local right = S.Child(frame, "RightPaneHost")
    if S.Usable(right) then
      Textures(right, nil, S.Kill)
      S.Kill(S.Region(right, "StoneBg")) -- (Blizzard shows it again with SetShown: alpha stays 0)
      local strip = right.GetChildren and (right:GetChildren())
      if S.Usable(strip) then
        Textures(strip, nil, S.Kill)
      end
      S.Plate(right, { fill = theme.side, rings = {} })
      local line = right:CreateTexture(nil, "BORDER")
      line:SetWidth(1)
      line:SetPoint("TOPLEFT", right, "TOPLEFT")
      line:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT")
      S.SetColor(line, theme.divider)
    end
    ModelScene(S.Get("CharacterModelScene"))
    -- Forever's stats list is CharacterStatsPaneScrollBox (and ...PetScrollBox for a pet): a frame with .ScrollBox,
    -- .ScrollBar, .Border and .ClassBackground (Camelot CharacterFrame.xml). CharacterStatsPane is an older pane
    -- that stays hidden; styling only it left the shown list in Blizzard's art (the user's screenshot, 2026-11-19).
    for _, name in ipairs({ "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox", "CharacterStatsPane",
      "CharacterStatsPanePet" }) do
      StatsPane(S.Get(name))
    end
    Ringed(S.Child(frame, "RightPaneToggleButton"))
    S.HookMethod(frame, "UpdateTabLayout", function(self)
      for _, tab in ipairs(S.Child(self, "ModeTabs", "Tabs") or {}) do
        IconTab(tab)
      end
    end)
  end
  for _, tab in ipairs(S.Child(frame, "ModeTabs", "Tabs") or {}) do
    IconTab(tab)
  end
  for index = 1, 4 do
    IconTab(S.Get("PaperDollSidebarTab" .. index))
  end
  -- equipment slots: see-through (design `empty` for empty slots), slot rings, icons cropped
  for _, slot in ipairs(CHARACTER_SLOTS) do
    local button = S.Get("Character" .. slot .. "Slot")
    if S.Usable(button) then
      MailSlot(button)
      S.KillNamed(S.Name(button), "Frame")
    end
  end
end

-- Spellbook and talents (PlayerSpellsFrame) ------------------------------------------------------------------

-- The school tabs (square icon tabs): their square backgrounds invisible, slot rings round the icon and an
-- accent ring of ours on the selected one.
local schoolTabs = setmetatable({}, { __mode = "k" }) -- [tab] = our selected ring lines

local function PaintSchool(tab, selected)
  local lines = schoolTabs[tab]
  if not lines then
    return
  end
  if selected == nil then
    selected = tab.isSelected and true or false
  end
  for _, line in ipairs(lines) do
    line:SetShown(selected and true or false)
  end
  local icon = S.Region(tab, "Icon")
  if icon then
    icon:SetAlpha(selected and 1 or 0.7)
  end
end

local function SchoolTab(tab)
  if not S.Usable(tab) or schoolTabs[tab] then
    return
  end
  S.KillKeys(tab, "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow")
  local icon = S.Region(tab, "Icon")
  if not icon then
    return
  end
  local mask = S.Child(tab, "IconMask")
  if mask and icon.RemoveMaskTexture then
    pcall(icon.RemoveMaskTexture, icon, mask)
  end
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local look = S.Look("slot")
  local depth = S.RingDepth(look.rings)
  for _, ring in ipairs(look.rings) do
    S.Outline(tab, icon, (ring.inset or 0) - depth, ring.size, ring.color, "OVERLAY", 1)
  end
  schoolTabs[tab] = S.Outline(tab, icon, -depth - 2, 1, S.Theme().accent, "OVERLAY", 2)
  S.HookMethod(tab, "SetTabSelected", PaintSchool)
  PaintSchool(tab)
end

-- Codex's own tab after the school tabs (Future spells, made by the Codex addon, whose namespace this one can't
-- see): styled here when the book is, or by Codex itself through TylesserCodex.SchoolTabLook when it comes later.
TylesserCodex.SchoolTabLook = SchoolTab

local function FutureSpellsTab()
  local get = TylesserCodex.FutureSpellsTab
  local ok, tab = false, nil
  if type(get) == "function" then
    ok, tab = pcall(get)
  end
  if ok and S.Usable(tab) then
    SchoolTab(tab)
  end
end

local function SchoolTabs(system)
  if not S.Usable(system) then
    return
  end
  for _, tab in ipairs({ system:GetChildren() }) do
    SchoolTab(tab)
  end
end

-- The book's text (spell names, ranks, page number) readable on the dark panel.
-- One spell of the book (an element frame with spell data): the brush-stroke backplate behind its text
-- invisible; its name and rank in the theme's text colour, or muted while Blizzard shows it unusable /
-- not yet learned (its icon desaturated, or its text greyed), the icon then a little dimmed but visible.
local function Grey(fontString)
  if not S.IsRegion(fontString) or not fontString.GetTextColor then
    return false
  end
  local r, g, b = fontString:GetTextColor()
  if type(r) ~= "number" or (canaccessvalue and not canaccessvalue(r)) then
    return false
  end
  -- Blizzard's normal spell text is light here; unusable / not yet learned spells get a dark grey
  return math.max(r, g, b) - math.min(r, g, b) < 0.08 and r * 0.3 + g * 0.59 + b * 0.11 < 0.5
end

local function Unusable(item)
  for _, key in ipairs({ "isUnlearned", "isDisabled", "isOffSpec" }) do
    if item[key] == true then
      return true
    end
  end
  local info = item.spellBookItemInfo
  local types = Enum and Enum.SpellBookItemType
  return type(info) == "table" and types and types.FutureSpell ~= nil and info.itemType == types.FutureSpell or false
end

local spellGreyed = setmetatable({}, { __mode = "k" }) -- [spell element] = Blizzard had greyed its name

-- Whether a string shows one of our two spell colours (text or muted), i.e. we set it last.
local function OurColour(fontString)
  if not S.IsRegion(fontString) or not fontString.GetTextColor then
    return false
  end
  local r, g, b = fontString:GetTextColor()
  if type(r) ~= "number" or (canaccessvalue and not canaccessvalue(r)) then
    return false
  end
  local theme = S.Theme()
  for _, c in ipairs({ theme.text, theme.muted }) do
    if math.abs(r - c[1]) < 0.01 and math.abs(g - c[2]) < 0.01 and math.abs(b - c[3]) < 0.01 then
      return true
    end
  end
  return false
end

local function SpellItem(item)
  S.KillKeys(item, "Backplate", "TextBackground", "Background")
  local icon = S.Region(S.Child(item, "Button"), "Icon") or S.Region(item, "Icon")
  local disabled = false
  if icon and type(icon.IsDesaturated) == "function" then
    local ok, desaturated = pcall(icon.IsDesaturated, icon)
    disabled = ok and desaturated == true
  end
  local name, sub = S.Region(item, "Name"), S.Region(item, "SubName")
  -- Blizzard's colour tells; once we have recoloured the name it is ours, so the last verdict is kept until
  -- Blizzard colours the name again
  local greyed = spellGreyed[item]
  if greyed == nil or not OurColour(name) then
    greyed = Grey(name)
    spellGreyed[item] = greyed
  end
  disabled = disabled or Unusable(item) or greyed
  local theme = S.Theme()
  for _, text in ipairs({ name, sub }) do
    if text then
      local c = disabled and theme.muted or (text == sub and theme.muted or theme.text)
      text:SetTextColor(c[1], c[2], c[3], disabled and 0.85 or 1)
    end
  end
  if icon then
    icon:SetAlpha(disabled and 0.75 or 1)
  end
end

-- A heading between the spells (a frame without spell data): its banner art invisible, its text in the
-- accent heading font with a rule.
local function SpellHeader(header)
  Textures(header, nil, S.Kill)
  local text = S.Region(header, "Text") or S.Region(header, "Name")
  if text then
    S.Font(text, "head", "accent")
    Rule(header, text, header, "RIGHT", 4)
  end
end

local spellItems = setmetatable({}, { __mode = "k" }) -- [element frame] = true once its update is followed

local function SpellFrames(paged)
  if type(paged.EnumerateFrames) ~= "function" then
    return
  end
  pcall(function()
    for _, frame in paged:EnumerateFrames() do
      if S.Usable(frame) then
        local isSpell = false
        if type(frame.HasValidData) == "function" then
          local ok, valid = pcall(frame.HasValidData, frame)
          isSpell = ok and valid and true or false
        end
        if isSpell then
          SpellItem(frame)
          if not spellItems[frame] then
            spellItems[frame] = true
            -- Blizzard colours the spell again on every update
            S.HookMethod(frame, "UpdateVisuals", SpellItem)
          end
        else
          SpellHeader(frame)
        end
      end
    end
  end)
end

local function SpellText(book)
  local paged = S.Child(book, "PagedSpellsFrame")
  if S.Usable(paged) then
    SpellFrames(paged)
    LightAll(paged)
    S.Walk(paged, 5, LightAll)
  end
  local page = S.Region(S.Child(paged, "PagingControls"), "PageText")
  if page then
    local muted = S.Theme().muted
    page:SetTextColor(muted[1], muted[2], muted[3], 1)
  end
end

local spellKey = {}
local function SpellTextSoon(book)
  C_Timer.After(0, function()
    S.Run("windows", S.Defer, spellKey, function()
      SpellText(book)
    end)
  end)
end

local function SpellBook(book)
  if not S.Usable(book) then
    return
  end
  if S.Once(book, "spellbook") then
    -- the parchment book: its bar, corner flip and page art invisible
    S.KillKeys(book, "TopBar", "BookCornerFlipbook")
    Textures(book, nil, S.Kill)
    local paged = S.Child(book, "PagedSpellsFrame")
    if S.Usable(paged) then
      Textures(paged, nil, S.Kill)
      for _, key in ipairs({ "View1", "View2" }) do
        local view = S.Child(paged, key)
        if S.Usable(view) then
          Textures(view, nil, S.Kill)
        end
      end
      local controls = S.Child(paged, "PagingControls")
      PageArrow(S.Child(controls, "PrevPageButton"), math.pi)
      PageArrow(S.Child(controls, "NextPageButton"), 0)
      for _, key in ipairs({ "PrevPageButton", "NextPageButton" }) do
        S.HookScript(S.Child(controls, key), "OnClick", function()
          SpellTextSoon(book)
        end)
      end
      -- a new page or school: its spells and headings are looked over (next frame, after Blizzard's layout)
      for _, method in ipairs({ "SetDataProvider", "DisplayViewsForCurrentPage", "SetCurrentPage" }) do
        S.HookMethod(paged, method, function()
          SpellTextSoon(book)
        end)
      end
    end
    SearchBox(S.Child(book, "SearchBox"))
    local system = S.Child(book, "CategoryTabSystem")
    S.HookMethod(system, "AddTab", function()
      SchoolTabs(system)
    end)
    S.HookScript(book, "OnShow", function()
      SpellTextSoon(book)
    end)
  end
  SchoolTabs(S.Child(book, "CategoryTabSystem"))
  FutureSpellsTab()
  SpellText(book)
end

-- Talent buttons: Blizzard's shadow and state borders invisible, the icon square with slot rings whose outer
-- ring takes the state colour Blizzard gives (maxed, partly spent, available, locked).
local talentRings = setmetatable({}, { __mode = "k" }) -- [button] = outer ring lines

local function TalentState(button, visualState)
  local lines = talentRings[button]
  if not lines then
    return
  end
  S.Kill(S.Region(button, "BorderSheen"))
  local util = _G.TalentButtonUtil
  local color = S.LineColor(S.Theme().slot.rings)
  if visualState ~= nil and type(util) == "table" and type(util.GetColorForBaseVisualState) == "function" then
    local ok, c = pcall(util.GetColorForBaseVisualState, visualState)
    if ok and type(c) == "table" and c.GetRGB then
      local r, g, b = c:GetRGB()
      color = { r, g, b }
    end
  end
  for _, line in ipairs(lines) do
    S.SetColor(line, color)
  end
end

local function TalentButton(_, button)
  if not S.Usable(button) or talentRings[button] then
    return
  end
  S.KillKeys(button, "Shadow", "StateBorder", "StateBorderHover")
  local icon = S.Region(button, "Icon")
  if not icon then
    return
  end
  for _, key in ipairs({ "IconMask" }) do
    local mask = S.Child(button, key)
    if mask and icon.RemoveMaskTexture then
      pcall(icon.RemoveMaskTexture, icon, mask)
    end
  end
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local look = S.Look("slot")
  local depth = S.RingDepth(look.rings)
  local outer
  for index, ring in ipairs(look.rings) do
    local lines = S.Outline(button, icon, (ring.inset or 0) - depth, ring.size, ring.color, "OVERLAY", 1)
    if index == 1 then
      outer = lines
    end
  end
  talentRings[button] = outer or {}
  S.HookMethod(button, "UpdateStateBorder", TalentState)
  local ok, state = pcall(function()
    return button.GetVisualState and button:GetVisualState()
  end)
  TalentState(button, ok and state or nil)
end

local function TalentHeaders(talents)
  for _, header in pairs(S.Child(talents, "treeHeaders") or {}) do
    if S.Usable(header) then
      S.KillKeys(header, "Divider", "TextBackground")
      S.Font(S.Region(header, "Name"), "head", "bright")
      local text = S.Region(header, "Text")
      if text then
        local accent = S.Theme().accent
        text:SetTextColor(accent[1], accent[2], accent[3], 1)
      end
    end
  end
end

local function Talents(talents)
  if not S.Usable(talents) or not S.Once(talents, "talents") then
    return
  end
  local theme = S.Theme()
  S.KillKeys(talents, "Background", "BackgroundBorder", "DividerHorizontalLeft", "DividerHorizontalRight")
  -- the lines between the trees stay, in the theme's divider colour
  for _, key in ipairs({ "DividerVerticalLeft", "DividerVerticalRight" }) do
    S.Tint(S.Region(talents, key), theme.divider)
  end
  local currency = S.Child(talents, "ClassCurrencyDisplay")
  S.Kill(S.Region(currency, "Border"))
  local amount = S.Child(currency, "CurrentAmountContainer")
  if S.Usable(amount) then
    S.Plate(amount, "inset")
  end
  SearchBox(S.Child(talents, "SearchBox"))
  S.HookMethod(talents, "RefreshTreeHeaders", TalentHeaders)
  S.HookMethod(talents, "UpdateButtonFrameLevel", TalentButton)
  TalentHeaders(talents)
  local tabs = S.Child(talents, "TabSystem")
  if S.Usable(tabs) then
    for _, tab in ipairs({ tabs:GetChildren() }) do
      Tab(tab)
    end
  end
end

local function PlayerSpells(frame)
  SpellBook(S.Child(frame, "SpellBookFrame"))
  Talents(S.Child(frame, "TalentsFrame"))
  local system = S.Child(frame, "TabSystem")
  if S.Usable(system) then
    for _, tab in ipairs({ system:GetChildren() }) do
      Tab(tab)
    end
  end
end

-- Bank (Forever: BankFrame with BankPanel) ------------------------------------------------------------------
-- The dark wood background and panel art invisible, every item and bag slot (purchasable ones included) in
-- the see-through slot look, the page tabs as theme icon tabs, search box and money box insets. Re-applied
-- after Blizzard builds the slots (GenerateItemSlotsForSelectedTab, RefreshBagButtons, RefreshPageTabs) and
-- on BANKFRAME_OPENED.

local function BankSlot(button)
  if not S.Usable(button) then
    return
  end
  S.Kill(S.Region(button, "Background"))
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  local icon = S.Region(button, "icon") or S.Region(button, "Icon")
  if S.IsRegion(normal) and normal ~= icon then
    S.Kill(normal) -- the slot frame atlas Blizzard sets on every refresh (alpha stays 0)
  end
  MailSlot(button, icon)
end

local function Pool(owner, key, fn)
  local pool = S.Child(owner, key)
  if pool and type(pool.EnumerateActive) == "function" then
    pcall(function()
      for button in pool:EnumerateActive() do
        fn(button)
      end
    end)
  end
end

local function BankSlots()
  local frame, panel = S.Get("BankFrame"), S.Get("BankPanel")
  Pool(panel, "itemButtonPool", BankSlot)
  Pool(frame, "itemButtonBagPool", BankSlot)
  Pool(frame, "bankPageTabPool", IconTab)
  for index = 1, 28 do
    BankSlot(S.Get("BankFrameItem" .. index))
  end
end

local bankWait = false
local function BankSoon()
  if bankWait then
    return
  end
  bankWait = true
  C_Timer.After(0, function()
    bankWait = false
    S.Run("windows", S.Defer, KeyOf(S.Get("BankFrame") or {}, "bank"), BankSlots)
  end)
end

local function Bank(frame)
  if S.Once(frame, "bank") then
    S.KillKeys(frame, "Background")
    local panel = S.Get("BankPanel") or S.Child(frame, "BankPanel")
    if S.Usable(panel) then
      Textures(panel, nil, S.Kill)
      S.Kill(S.Child(panel, "EdgeShadows"))
      local money = S.Child(panel, "MoneyFrame")
      if S.Usable(money) then
        S.Kill(S.Child(money, "Border"))
        S.Plate(money, "inset")
      end
      local prompt = S.Child(panel, "PurchasePrompt")
      if S.Usable(prompt) then
        Textures(prompt, nil, S.Kill)
      end
      Ringed(S.Child(panel, "AutoSortButton"))
      for _, method in ipairs({ "GenerateItemSlotsForSelectedTab", "RefreshBankTabs" }) do
        S.HookMethod(panel, method, BankSoon)
      end
    end
    SearchBox(S.Get("BankItemSearchBox"))
    for _, method in ipairs({ "RefreshBagButtons", "RefreshPageTabs" }) do
      S.HookMethod(frame, method, BankSoon)
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("BANKFRAME_OPENED")
    events:SetScript("OnEvent", function()
      BankSoon()
    end)
  end
  BankSlots()
end

CONTENT.CharacterFrame = CharacterSheet
CONTENT.PlayerSpellsFrame = PlayerSpells
CONTENT.BankFrame = Bank

-- Trade window (TradeFrame, Blizzard_UIPanels_Game; names from the forever branch of the game's UI source) ---
-- The window title "Trade" in our title bar; Blizzard's two names on the title bar and the partner's portrait
-- (RecipientOverlay, half above the window) made invisible, and instead a header of ours over each column: a
-- round portrait (Circle mask, accent ring) and the name in full. The column insets in the inset look; the
-- partner side's extra frame art (TradeRecipientBG / LeftBorder / BotLeftCorner, TradeRecipientMoneyBg)
-- invisible; item slots see-through with a thin line (SlotTexture hidden), the name boxes (NameFrame) a light
-- inset; "Will not be traded" a muted heading. The money input (TradePlayerInputMoneyFrame) is a forbidden
-- frame: never touched, only the inset behind it is ours. Trade / Cancel keep Blizzard's behaviour (the button
-- look comes from the window pass).

local TRADE_INSETS = { "TradePlayerItemsInset", "TradeRecipientItemsInset", "TradePlayerEnchantInset",
  "TradeRecipientEnchantInset", "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset" }
local TRADE_ART = { "TradeRecipientBotLeftCorner", "TradeRecipientLeftBorder", "TradeRecipientBG" }
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local trade = {} -- our pieces: headers[side] = { ring, portrait, name }

local function TradeHeader(frame, side, inset)
  local theme = S.Theme()
  local holder = CreateFrame("Frame", nil, frame)
  holder:SetHeight(26)
  holder:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 2, 3)
  holder:SetPoint("BOTTOMRIGHT", inset, "TOPRIGHT", -2, 3)
  local ring = holder:CreateTexture(nil, "ARTWORK", nil, 1)
  ring:SetTexture(CIRCLE)
  ring:SetSize(26, 26)
  ring:SetPoint("LEFT", holder, "LEFT")
  ring:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  local portrait = holder:CreateTexture(nil, "ARTWORK", nil, 2)
  portrait:SetSize(22, 22)
  portrait:SetPoint("CENTER", ring, "CENTER")
  local mask = holder:CreateMaskTexture()
  mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(portrait)
  portrait:AddMaskTexture(mask)
  local name = holder:CreateFontString(nil, "ARTWORK")
  name:SetFontObject(GameFontNormal)
  name:SetPoint("LEFT", ring, "RIGHT", 6, 0)
  name:SetPoint("RIGHT", holder, "RIGHT", -2, 0)
  name:SetJustifyH("LEFT")
  if name.SetWordWrap then
    name:SetWordWrap(false)
  end
  S.Font(name, "body")
  local c = side == "player" and theme.bright or theme.text
  name:SetTextColor(c[1], c[2], c[3], 1)
  trade[side] = { holder = holder, portrait = portrait, name = name }
end

-- After Blizzard's own update (names and portraits): copied into our headers (read only).
local function TradeNames()
  for side, source in pairs({ player = "TradeFramePlayerNameText", recipient = "TradeFrameRecipientNameText" }) do
    local header = trade[side]
    if header then
      local blizzard = S.Get(source)
      local text = S.IsRegion(blizzard) and blizzard.GetText and blizzard:GetText()
      if type(text) == "string" and (not canaccessvalue or canaccessvalue(text)) then
        header.name:SetText(text)
      end
      if SetPortraitTexture then
        pcall(SetPortraitTexture, header.portrait, side == "player" and "player" or "NPC")
      end
    end
  end
end

local function TradeItem(item)
  if not S.Usable(item) or not S.Once(item, "tradeitem") then
    return
  end
  local name = S.Name(item)
  local theme = S.Theme()
  S.Kill(S.Region(item, "SlotTexture") or (name and S.Get(name .. "SlotTexture")))
  local nameFrame = name and S.Get(name .. "NameFrame")
  S.Kill(nameFrame)
  local button = name and S.Get(name .. "ItemButton")
  if S.Usable(button) then
    MailSlot(button)
    -- the name box: a light inset beside the slot
    local box = item:CreateTexture(nil, "BACKGROUND", nil, -6)
    box:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, 0)
    box:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    local fill = theme.inset.fill
    box:SetColorTexture(fill[1], fill[2], fill[3], (fill[4] or 1) * 0.6)
    S.Outline(item, box, 0, 1, theme.inset.line, "BORDER")
  end
  local text = name and S.Get(name .. "Name")
  if S.IsRegion(text) then
    S.Font(text, "body")
  end
end

local function Trade(frame)
  if S.Once(frame, "trade") then
    local theme = S.Theme()
    for _, key in ipairs(TRADE_ART) do
      S.Kill(S.Get(key))
    end
    local moneyBg = S.Get("TradeRecipientMoneyBg")
    if S.Usable(moneyBg) then
      Textures(moneyBg, nil, S.Kill)
      S.Kill(S.Child(moneyBg, "NineSlice"))
    end
    -- the partner's portrait over the title bar, and Blizzard's names there: invisible (ours are below)
    local overlay = S.Child(frame, "RecipientOverlay")
    S.KillKeys(overlay or {}, "portrait", "portraitFrame")
    S.Kill(S.Get("TradeFramePlayerNameText"))
    S.Kill(S.Get("TradeFrameRecipientNameText"))
    for _, key in ipairs(TRADE_INSETS) do
      local inset = S.Get(key)
      if S.Usable(inset) and S.Child(inset, "NineSlice") then
        S.Inset(inset)
      elseif S.Usable(inset) then
        S.KillKeys(inset, "Bg")
        S.Plate(inset, "inset")
      end
    end
    -- the title: "Trade" when Blizzard gives the window none
    local title = S.TitleOf(frame)
    local current = S.IsRegion(title) and title.GetText and title:GetText()
    if S.IsRegion(title) and (type(current) ~= "string" or current == "") then
      local ours = frame:CreateFontString(nil, "OVERLAY")
      ours:SetFontObject(GameFontNormal)
      ours:SetPoint("CENTER", title, "CENTER")
      ours:SetText(TRADE or "Trade")
      S.Font(ours, "head", "titleText")
    end
    -- the column headers (portrait and full name) above each side's money row
    TradeHeader(frame, "player", S.Get("TradePlayerInputMoneyInset") or frame)
    TradeHeader(frame, "recipient", S.Get("TradeRecipientMoneyInset") or frame)
    for _, key in ipairs({ "TradeFramePlayerEnchantText", "TradeFrameRecipientEnchantText" }) do
      local text = S.Get(key)
      if S.IsRegion(text) then
        S.Font(text, "head")
        text:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
      end
    end
    S.HookGlobal("TradeFrame_Update", TradeNames)
  end
  for index = 1, 7 do
    TradeItem(S.Get("TradePlayerItem" .. index))
    TradeItem(S.Get("TradeRecipientItem" .. index))
  end
  TradeNames()
end

CONTENT.TradeFrame = Trade

-- Windows whose title is a name (a character, an NPC): the heading font may have capitals only (Cinzel), so
-- their title uses the theme's body font, or the game's own font, at its size. Names are never upper-cased.
local NAME_TITLES = { CharacterFrame = true, InspectFrame = true, QuestFrame = true, GossipFrame = true,
  MerchantFrame = true, ClassTrainerFrame = true, TabardFrame = true, PetStableFrame = true, StableFrame = true,
  TradeFrame = true, OpenMailFrame = true, ItemTextFrame = true }

local function NameTitle(frame)
  local name = S.Name(frame)
  local title = name and NAME_TITLES[name] and S.TitleOf(frame)
  if not S.IsRegion(title) or not title.SetFont or not title.GetFont then
    return
  end
  local font = S.Theme().font and S.Theme().font.body
  if not font and GameFontNormal and GameFontNormal.GetFont then
    font = GameFontNormal:GetFont()
  end
  font = type(font) == "string" and font or STANDARD_TEXT_FONT
  local _, size, flags = title:GetFont()
  if type(font) == "string" then
    title:SetFont(font, type(size) == "number" and size > 0 and size or 12, type(flags) == "string" and flags or "")
  end
end

local function SkinWindow(frame)
  if not S.Usable(frame) or S.Done(frame, "window") or S.Done(frame, "notwindow") then
    return
  end
  local name = S.Name(frame)
  if name and EXCLUDED[name] then
    return
  end
  local skinned
  if IsLayoutFrame(frame) or (name and FIT[name]) then
    skinned = DetachedWindow(frame)
  else
    skinned = S.Window(frame, { strip = not (name and NPC_WINDOWS[name]) })
  end
  if not skinned then
    -- no NineSlice border art: left as it is
    S.Once(frame, "notwindow")
    return
  end
  NameTitle(frame)
  if name and NAME_TITLES[name] then
    -- Blizzard sets the name on every show (SetTitle): its font is put back right after
    for _, method in ipairs({ "SetTitle", "SetTitleFormatted" }) do
      S.HookMethod(frame, method, NameTitle)
    end
    S.HookScript(frame, "OnShow", NameTitle)
  end
  -- content is built late (and bags fill on open): looked over each time the window opens
  S.HookScript(frame, "OnShow", function()
    Later(frame)
  end)
  if IsBag(name) then
    HookBag(frame)
  end
  if frame.IsShown and frame:IsShown() then
    Content(frame)
  end
end

local function Scan()
  local names = {}
  if type(UIPanelWindows) == "table" then
    for name in pairs(UIPanelWindows) do
      if type(name) == "string" then
        names[#names + 1] = name
      end
    end
  end
  for _, name in ipairs(EXTRA) do
    names[#names + 1] = name
  end
  for index = 1, (type(NUM_CONTAINER_FRAMES) == "number" and NUM_CONTAINER_FRAMES or 13) do
    names[#names + 1] = "ContainerFrame" .. index
  end
  -- one window that fails (changed on this client) must not stop the others
  for _, name in ipairs(names) do
    local ok, err = pcall(SkinWindow, S.Get(name))
    if not ok then
      S.Fail("windows", name .. ": " .. tostring(err))
    end
  end
end

-- Calendar (Blizzard_Calendar, load-on-demand) --------------------------------------------------------------
-- The window: its frame art invisible, the theme panel, rings, corners and a title bar with the month and
-- year (heading font, the text as Blizzard writes it); the month arrows and close button as our small
-- buttons, Filters as our dropdown button. The weekday strip a thin muted heading row with a rule; each day a
-- see-through theme slot with a thin line, its number in the body font, days of other months dimmed, today
-- with an accent ring, the selected day with an accent line; the holiday / event art kept (it carries
-- information), the parchment, shadows and today glow art dropped; event lines in the body font, muted for
-- other months. The event popups get the theme panel through the window skin. Region names from
-- Blizzard_Calendar (Mainline): CalendarFrame<Top|Left|Right|Bottom...>Texture, CalendarWeekday<N>Background /
-- Name, CalendarMonthBackground / Name, CalendarYearBackground / Name, CalendarDayButton<N> with its
-- DateFrameDate / DateFrameBackground / DarkFrameTop / DarkFrameBottom / EventTexture / OverlayFrameTexture
-- and EventButton<M>Text1 / Text2, CalendarTodayFrame (CalendarTodayTexture / Glow), CalendarLastDayDarkTexture,
-- CalendarWeekdaySelectedTexture, CalendarPrevMonthButton / CalendarNextMonthButton / CalendarCloseButton,
-- CalendarFrame.FilterButton. Every lookup is guarded (Forever may differ).

local CALENDAR_ART = { "TopLeft", "TopMiddle", "TopRight", "LeftTop", "LeftMiddle", "LeftBottom", "RightTop",
  "RightMiddle", "RightBottom", "BottomLeft", "BottomMiddle", "BottomRight" }
local CALENDAR_DAYS, CALENDAR_EVENTS = 42, 4
local CALENDAR_POPUPS = { "CalendarViewHolidayFrame", "CalendarViewRaidFrame", "CalendarViewEventFrame",
  "CalendarCreateEventFrame", "CalendarTexturePickerFrame", "CalendarMassInviteFrame", "CalendarEventPickerFrame" }

local dayMarks = setmetatable({}, { __mode = "k" }) -- [day button] = { fill, today, selected }

local function DayButton(index)
  local button = S.Get("CalendarDayButton" .. index)
  return S.Usable(button) and button or nil
end

local function CalendarDay(button)
  if not button or dayMarks[button] then
    return
  end
  local name = S.Name(button)
  local theme = S.Theme()
  -- the parchment day, its shadows and the date plate (the holiday art stays)
  S.Kill(button.GetNormalTexture and button:GetNormalTexture())
  S.KillNamed(name, "DateFrameBackground", "DarkFrameTop", "DarkFrameBottom")
  local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
  if S.IsRegion(highlight) then
    S.Tint(highlight, theme.accent) -- Blizzard sets its alpha (hover / selected): the colour is ours
  end
  local text = theme.text
  local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  fill:SetColorTexture(text[1], text[2], text[3], 0.05) -- see-through (design token `empty`)
  local frame = S.Outline(button, fill, 0, 1, theme.inset.line, "BORDER")
  local today = S.Outline(button, fill, 1, 2, theme.accent, "OVERLAY", 6)
  local selected = button:CreateTexture(nil, "OVERLAY", nil, 6)
  selected:SetHeight(2)
  selected:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 2, 2)
  selected:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -2, 2)
  S.SetColor(selected, theme.accent)
  for _, line in ipairs(today) do
    line:Hide()
  end
  selected:Hide()
  dayMarks[button] = { fill = fill, frame = frame, today = today, selected = selected }
end

-- One day after Blizzard's update: number in the body font, dimmed when it belongs to another month.
local function CalendarDayLook(button)
  local marks = dayMarks[button]
  if not marks then
    return
  end
  local theme = S.Theme()
  local other = type(button.monthOffset) == "number" and button.monthOffset ~= 0
  local name = S.Name(button)
  local date = name and S.Get(name .. "DateFrameDate")
  if S.IsRegion(date) then
    S.Font(date, "body")
    local c = other and theme.muted or theme.text
    date:SetTextColor(c[1], c[2], c[3], other and 0.55 or 1)
  end
  marks.fill:SetAlpha(other and 0.4 or 1)
  for index = 1, CALENDAR_EVENTS do
    for _, key in ipairs({ "Text1", "Text2" }) do
      local line = name and S.Get(name .. "EventButton" .. index .. key)
      if S.IsRegion(line) then
        S.Font(line, "body")
        if other then
          line:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 0.7)
        end
      end
    end
  end
end

local function MarkToday(button)
  for day, marks in pairs(dayMarks) do
    for _, line in ipairs(marks.today) do
      line:SetShown(day == button)
    end
  end
end

local function MarkSelected(button)
  for day, marks in pairs(dayMarks) do
    marks.selected:SetShown(day == button)
  end
end

local function CalendarTitle()
  local theme = S.Theme()
  S.Font(S.Get("CalendarMonthName"), "head", "titleText")
  local year = S.Get("CalendarYearName")
  if S.IsRegion(year) then
    S.Font(year, "body")
    year:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  end
end

local function CalendarDaysPass()
  for index = 1, CALENDAR_DAYS do
    local button = DayButton(index)
    CalendarDay(button)
    CalendarDayLook(button)
  end
  CalendarTitle()
end

local function MonthArrow(button, rotation)
  if S.Usable(button) then
    PageArrow(button, rotation)
  end
end

local function SkinCalendar()
  local frame = S.Get("CalendarFrame")
  if not S.Usable(frame) or not S.Once(frame, "calendar") then
    return
  end
  local theme = S.Theme()
  local name = S.Name(frame) or "CalendarFrame"
  for _, piece in ipairs(CALENDAR_ART) do
    S.Kill(S.Get(name .. piece .. "Texture"))
  end
  S.Kill(S.Get("CalendarMonthBackground"))
  S.Kill(S.Get("CalendarYearBackground"))
  S.Empty(S.Get("CalendarLastDayDarkTexture"))
  -- today's glow is animated by Blizzard with SetAlpha: emptied instead (our accent ring marks today)
  S.Empty(S.Get("CalendarTodayTexture"))
  S.Empty(S.Get("CalendarTodayTextureGlow"))
  S.Tint(S.Get("CalendarWeekdaySelectedTexture"), theme.accent)
  -- the window: panel, rings, corners, a title bar down to the month name
  local overlay = S.Overlay(frame, 30)
  S.Plate(frame, "panel", { ringsOn = overlay, corners = true })
  local depth = S.BandInset(theme)
  local band = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
  band:SetPoint("TOPLEFT", frame, "TOPLEFT", depth, -depth)
  band:SetPoint("RIGHT", frame, "RIGHT", -depth, 0)
  local month = S.Get("CalendarMonthName")
  if S.IsRegion(month) then
    band:SetPoint("BOTTOM", month, "BOTTOM", 0, -6)
  else
    band:SetHeight(theme.titlebar.height or 28)
  end
  S.UI.Gradient(band, theme.titlebar.from, theme.titlebar.to)
  local bandLine = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
  bandLine:SetHeight(1)
  bandLine:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
  bandLine:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
  S.SetColor(bandLine, theme.titlebar.line)
  -- the weekday strip: muted names, no backgrounds, a rule under the row
  for index = 1, 7 do
    S.Kill(S.Get("CalendarWeekday" .. index .. "Background"))
    local day = S.Get("CalendarWeekday" .. index .. "Name")
    if S.IsRegion(day) then
      S.Font(day, "body")
      day:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
    end
  end
  local first, last = S.Get("CalendarWeekday1Background"), S.Get("CalendarWeekday7Background")
  if S.IsRegion(first) and S.IsRegion(last) then
    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", first, "BOTTOMLEFT", 0, 1)
    rule:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 0, 1)
    S.SetColor(rule, theme.divider)
  end
  -- buttons
  MonthArrow(S.Get("CalendarPrevMonthButton"), math.pi)
  MonthArrow(S.Get("CalendarNextMonthButton"), 0)
  CloseButton(S.Get("CalendarCloseButton"))
  ThemeButton(S.Child(frame, "FilterButton"), STRETCH)
  -- days: built now, looked over after Blizzard's own updates (post-hooks; its layout is never called)
  CalendarDaysPass()
  S.HookGlobal("CalendarFrame_UpdateDay", function(index)
    local button = DayButton(index)
    CalendarDay(button)
    CalendarDayLook(button)
  end)
  S.HookGlobal("CalendarFrame_UpdateDayEvents", function(index)
    CalendarDayLook(DayButton(index))
  end)
  S.HookGlobal("CalendarFrame_SetToday", MarkToday)
  S.HookGlobal("CalendarFrame_SetSelectedDay", MarkSelected)
  S.HookGlobal("CalendarFrame_UpdateTitle", CalendarTitle)
  S.HookScript(frame, "OnShow", function()
    S.Defer(KeyOf(frame, "calendar"), CalendarDaysPass)
  end)
  -- the popups (event, holiday, raid, create): the theme panel through the window skin (NineSlice borders)
  for _, popup in ipairs(CALENDAR_POPUPS) do
    local window = S.Get(popup)
    if S.Usable(window) then
      pcall(SkinWindow, window)
      Header(window)
    end
  end
end

-- Tab state follows Blizzard's own select / deselect.
local function TabHooks()
  S.HookGlobal("PanelTemplates_SelectTab", function(tab)
    PaintTab(tab, true)
  end)
  S.HookGlobal("PanelTemplates_DeselectTab", function(tab)
    PaintTab(tab, false)
  end)
end

S.Part("windows", function()
  S.GameFonts() -- light theme: the game's window fonts in readable shades
  TabHooks()
  Scan()
  S.OnAnyAddOn(Scan)
  -- the calendar is load-on-demand (now when it is already loaded)
  S.OnAddOn("Blizzard_Calendar", SkinCalendar)
end)
