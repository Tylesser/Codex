local addonName, ns = ...
local S = ns.S

-- Menus: the game's dropdown and right-click menus (Blizzard_Menu: every Menu.GetManager() menu, so the damage
-- meter's, unit right-click menus, chat tab menus and the lists of dropdown buttons in windows; submenus too)
-- in the theme, as the round-2 Tooltips board draws them. The theme's panel (fill, rings) is drawn on a frame of
-- ours over the frame that carries Blizzard's dark panel and bronze edge (the menu, or the child frame holding
-- its "dropdown-bg" art), reaching 8 / 6 px past it and anchored to its edges so it follows every size Blizzard
-- gives it (long and scrolling menus too); Blizzard's art is hidden only once that frame has a real size.
-- Right-click menus keep small corner studs; dropdown lists have none. Entries take the theme's body font where
-- the theme has one (at Blizzard's size); radio buttons become the board's 12px ring with an accent dot, the
-- ticked row a select-colour band; "Name [01:23]" entries (the meter's fight list) show the time right-aligned
-- and muted; the hover highlight turns the select colour, thin separators the divider colour, ticked check
-- marks the accent, submenu arrows the button text colour. The old DropDownList frames get the panel too.
--
-- Only post-hooks on the menu manager (OpenMenu / OpenContextMenu, as ElvUI's menu skin hooks them, MIT) and
-- Blizzard's own submenu callback (AddMenuAcquiredCallback). Nothing is moved, sized, shown or hidden, no
-- entry's action or secure unit-menu function is touched, and state lives in weak tables. Menu frames and
-- their textures are pooled: every open looks them over again, and a texture we tinted that comes back as
-- other art (an icon) gets its colours back.

local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local SUBMENU_ARROW = 130940 -- the submenu arrow's file id (as ElvUI's menu skin reads it)
local SCROLL_KEYS = { ScrollBar = true }
local PAD_X, PAD_Y = 8, 6 -- the panel reaches this far past the menu frame

local panels = setmetatable({}, { __mode = "k" }) -- [art frame] = our panel frame
local ours = setmetatable({}, { __mode = "k" }) -- [our panel frame] = true (left out of the entry walk)
local panelCorners = setmetatable({}, { __mode = "k" }) -- [our panel frame] = its corner textures
local entryLooks = setmetatable({}, { __mode = "k" }) -- [entry frame] = our radio / selection / time pieces
local hidden = setmetatable({}, { __mode = "k" }) -- [Blizzard texture] = true while we keep it invisible
local split = setmetatable({}, { __mode = "k" }) -- [entry font string] = the name we left in it
local tinted = setmetatable({}, { __mode = "k" }) -- [Blizzard texture] = true while it carries our colours
local lists = setmetatable({}, { __mode = "k" }) -- [DropDownList] = true

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

local function CornerSize()
  local corner = S.Theme().corner
  return corner and math.max(6, math.floor((corner.size or 16) * 0.6 + 0.5)) or nil
end

local function Atlas(texture)
  local atlas = texture.GetAtlas and texture:GetAtlas()
  return Readable(atlas) and type(atlas) == "string" and atlas:lower() or nil
end

local function IsTexture(region)
  return S.IsRegion(region) and region:GetObjectType() == "Texture"
end

-- Blizzard's menu panel art (MenuStyle1's "common-dropdown-bg" and the like).
local function IsBackground(texture)
  local atlas = Atlas(texture)
  return atlas ~= nil and (atlas:find("dropdown-bg", 1, true) ~= nil
    or (atlas:find("menu", 1, true) ~= nil and atlas:find("bg", 1, true) ~= nil))
end

-- The frame that carries Blizzard's panel art: the menu itself, or a child frame of it holding the art.
local function ArtFrame(menu)
  for _, region in ipairs({ menu:GetRegions() }) do
    if IsTexture(region) and IsBackground(region) then
      return menu
    end
  end
  if menu.GetChildren then
    for _, child in ipairs({ menu:GetChildren() }) do
      if S.Usable(child) and not ours[child] and child.GetRegions then
        for _, region in ipairs({ child:GetRegions() }) do
          if IsTexture(region) and IsBackground(region) then
            return child
          end
        end
      end
    end
  end
  return menu
end

local function HasSize(frame)
  local width, height = frame:GetWidth(), frame:GetHeight()
  return Readable(width) and Readable(height) and type(width) == "number" and type(height) == "number"
    and width > 8 and height > 8
end

-- Blizzard's art on the art frame, hidden only while our panel covers a frame with a real size.
local function HideArt(art)
  if not HasSize(art) then
    return false
  end
  for _, region in ipairs({ art:GetRegions() }) do
    if IsTexture(region) then
      S.Kill(region)
    end
  end
  return true
end

-- Our panel frame over the art frame (once per pooled frame), at its level so the entries stay above it.
-- Studs only on right-click menus: the board's dropdown lists (the meter's segment list) have none.
local function Panel(menu, context)
  if not S.Usable(menu) or not menu.GetRegions then
    return
  end
  local art = ArtFrame(menu)
  local panel = panels[art]
  if not panel then
    panel = CreateFrame("Frame", nil, art)
    ours[panel] = true
    panels[art] = panel
    -- a margin round the entries: radio circles sit right at the frame's left edge, the last row at its bottom
    panel:SetPoint("TOPLEFT", art, "TOPLEFT", -PAD_X, PAD_Y)
    panel:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", PAD_X, -PAD_Y)
    panel:EnableMouse(false)
    panelCorners[panel] = S.Plate(panel, "panel", { corners = true, cornerSize = CornerSize() }).corners
    -- a menu sized after it opened: Blizzard's art goes once the size is there
    panel:SetScript("OnSizeChanged", function()
      S.Run("menus", HideArt, art)
    end)
  end
  local ok, level = pcall(art.GetFrameLevel, art)
  if ok and Readable(level) and type(level) == "number" then
    panel:SetFrameLevel(level)
  end
  for _, corner in ipairs(panelCorners[panel] or {}) do
    corner:SetShown(context and true or false)
  end
  HideArt(art)
end

-- Entries ------------------------------------------------------------------------------------------------

local function Tint(texture, color, alpha)
  S.Tint(texture, color, alpha)
  tinted[texture] = true
end

local function Untint(texture)
  if tinted[texture] then
    tinted[texture] = nil
    if texture.SetDesaturated then
      texture:SetDesaturated(false)
    end
    texture:SetVertexColor(1, 1, 1, 1)
  end
end

-- Menu entries on Forever are built by Blizzard's compositor (Blizzard_Menu/Compositor.lua): their font strings
-- refuse SetFont and the frames refuse CreateTexture / CreateFontString (even looking those keys up reports an
-- error), so nothing of ours is made on them. A compositor region's metatable has a function __index (a normal
-- widget's is a table): that tells them apart without touching a refused key.
local function Composed(object)
  local mt = getmetatable(object)
  return type(mt) == "table" and type(mt.__index) == "function"
end

-- Font objects of ours, one per face / size / flags / colour (a compositor font string takes SetFontObject). A
-- colour (light themes) is the readable shade of the entry's own colour, with the theme's text shadow (none).
local fontObjects = {}
local fontCount = 0
local function FontObject(path, size, flags, color)
  local key = path .. "|" .. size .. "|" .. flags
  if color then
    key = key .. "|" .. ("%.3f,%.3f,%.3f"):format(color[1], color[2], color[3])
  end
  local object = fontObjects[key]
  if not object and CreateFont then
    fontCount = fontCount + 1
    object = CreateFont("CodexMenuFont" .. fontCount)
    object:SetFont(path, size, flags)
    if color then
      object:SetTextColor(color[1], color[2], color[3], 1)
      local x, y, r, g, b, a = S.UI.TextShadow(S.Theme())
      object:SetShadowOffset(x, y)
      object:SetShadowColor(r, g, b, a)
    end
    fontObjects[key] = object
  end
  return object
end

-- A face on a font string: SetFont on our own, a font object on Blizzard's compositor ones (with `color`: a
-- coloured font object, the one way to recolour a compositor string; our own strings take S.GameText instead).
local function ApplyFont(fontString, path, size, flags, color)
  flags = type(flags) == "string" and flags or ""
  if Composed(fontString) then
    local object = FontObject(path, size, flags, color)
    if object then
      pcall(fontString.SetFontObject, fontString, object)
    end
  else
    pcall(fontString.SetFont, fontString, path, size, flags)
  end
end

-- An entry's colour made readable on a light theme's menu panel (nil: dark theme, unchanged or not readable).
local function LightColor(fontString)
  local theme = S.Theme()
  if not theme.light or type(TylesserCodex.GameColor) ~= "function" then
    return nil
  end
  local ok, r, g, b = pcall(function()
    return fontString:GetTextColor()
  end)
  if not ok or not (Readable(r) and Readable(g) and Readable(b)) or type(r) ~= "number" or type(g) ~= "number"
    or type(b) ~= "number" then
    return nil
  end
  local c = TylesserCodex.GameColor({ r, g, b }, theme)
  if c[1] == r and c[2] == g and c[3] == b then
    return nil
  end
  return c
end

-- The theme's body face at Blizzard's size (themes without one keep the game's). On a light theme (Dawn) the
-- entry's colour (white, yellow titles, grey disabled entries, red) in a readable shade too: a compositor string
-- through a coloured font object of ours (SetFontObject only), one of ours / an old DropDownList string through
-- S.GameText.
local function BodyFont(fontString)
  local body = S.Theme().font.body
  if type(fontString.GetFont) ~= "function" then
    return
  end
  local composed = Composed(fontString)
  local color = composed and LightColor(fontString) or nil
  if not composed and S.Theme().light then
    S.GameText(fontString)
  end
  if not body and not color then
    return
  end
  local path, size, flags = fontString:GetFont()
  if not (Readable(size) and type(size) == "number" and size > 0) or type(path) ~= "string" then
    return
  end
  if (body and path ~= body) or color then
    ApplyFont(fontString, body or path, size, flags, color)
  end
end

-- A separator line: only a few pixels high.
local function Thin(texture)
  local height = texture.GetHeight and texture:GetHeight()
  return Readable(height) and type(height) == "number" and height > 0 and height <= 6
end

local function Gradient(texture, from, to)
  texture:SetColorTexture(1, 1, 1, 1)
  if CreateColor and texture.SetGradient then
    pcall(texture.SetGradient, texture, "HORIZONTAL", CreateColor(from[1], from[2], from[3], from[4] or 1),
      CreateColor(to[1], to[2], to[3], to[4] or 1))
  end
end

local function Disc(holder, size, color, sublevel)
  local disc = holder:CreateTexture(nil, "ARTWORK", nil, sublevel)
  disc:SetTexture(CIRCLE)
  disc:SetSize(size, size)
  disc:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  return disc
end

-- Our pieces for an entry (once per pooled entry), on two frames of ours that are children of the entry, so they
-- show, hide and scroll with it: one a level under it (the ticked row's band, behind Blizzard's text) and one
-- over it (the radio ring with its dot, the right-aligned time). The entry itself gets nothing new.
local function EntryLook(frame)
  local look = entryLooks[frame]
  if look ~= nil then
    return look or nil
  end
  local okLevel, level = pcall(frame.GetFrameLevel, frame)
  local okBack, back = pcall(CreateFrame, "Frame", nil, frame)
  local okFront, front = pcall(CreateFrame, "Frame", nil, frame)
  if not (okLevel and okBack and okFront and back and front) then
    entryLooks[frame] = false -- not again for this entry
    return nil
  end
  ours[back], ours[front] = true, true
  for _, holder in ipairs({ back, front }) do
    holder:SetAllPoints(frame)
    holder:EnableMouse(false)
  end
  if type(level) == "number" then
    back:SetFrameLevel(math.max(0, level - 1))
    front:SetFrameLevel(level + 2)
  end
  local theme = S.Theme()
  local panel = theme.panel.from
  look = { back = back, front = front }
  -- the board's radio: a 12px circle with a 1px ring (titleLine), dark inside, an accent dot when ticked
  look.ring = Disc(front, 12, theme.titlebar.line, 1)
  look.hole = Disc(front, 10, { panel[1] * 0.55, panel[2] * 0.55, panel[3] * 0.55, 1 }, 2)
  look.dot = Disc(front, 6, theme.accent, 3)
  -- the ticked row (design token selRow: the select colour fading to the right)
  look.band = back:CreateTexture(nil, "BACKGROUND", nil, -8)
  look.band:SetAllPoints(back)
  Gradient(look.band, theme.select.from, theme.select.to)
  look.time = front:CreateFontString(nil, "OVERLAY")
  look.time:SetPoint("RIGHT", front, "RIGHT", -8, 0)
  look.time:SetJustifyH("RIGHT")
  entryLooks[frame] = look
  return look
end

local function HideLook(look)
  if look then
    for _, key in ipairs({ "ring", "hole", "dot", "band", "time" }) do
      look[key]:Hide()
    end
  end
end

-- "Name [01:23]" (the meter's fight list): the name stays in Blizzard's text, the time goes right-aligned.
local function Time(frame, fontString)
  local text = fontString.GetText and fontString:GetText()
  if not Readable(text) or type(text) ~= "string" then
    return nil
  end
  local known = split[fontString]
  if known and known.name == text then
    return known.time
  end
  local name, time = text:match("^(.-)%s*%[(%d+:%d%d)%]$")
  if not name or name == "" then
    split[fontString] = nil
    return nil
  end
  fontString:SetText(name)
  split[fontString] = { name = name, time = time }
  return time
end

local function StyleEntry(frame)
  local theme = S.Theme()
  local textures, strings = {}, {}
  for _, region in ipairs({ frame:GetRegions() }) do
    if S.IsRegion(region) then
      local kind = region:GetObjectType()
      if kind == "FontString" then
        strings[#strings + 1] = region
        BodyFont(region)
      elseif kind == "Texture" then
        textures[#textures + 1] = region
      end
    end
  end
  local select = theme.select.from
  local circle, ticked
  for _, texture in ipairs(textures) do
    local atlas = Atlas(texture)
    local blend = texture.GetBlendMode and texture:GetBlendMode()
    local file = texture.GetTexture and texture:GetTexture()
    local radio = atlas and (atlas:find("tickradial", 1, true) or atlas:find("radialtick", 1, true))
    if radio then
      -- Blizzard's radio circle and tick: our ring and dot instead
      if atlas:find("radialtick", 1, true) then
        ticked = ticked or texture:IsShown()
      else
        circle = texture
      end
      Untint(texture)
      S.Kill(texture)
      hidden[texture] = true
    else
      if hidden[texture] then -- a pooled texture now other art
        hidden[texture] = nil
        texture:SetAlpha(1)
      end
      if atlas and atlas:find("checkmark", 1, true) then
        Tint(texture, theme.accent, 1) -- the mark of a ticked check box
      elseif blend == "ADD" then
        Tint(texture, { select[1], select[2], select[3] }, 0.6) -- the hover highlight
      elseif Readable(file) and file == SUBMENU_ARROW then
        Tint(texture, theme.button.text, 1)
      elseif #strings == 0 and #textures == 1 and Thin(texture) then
        Tint(texture, theme.divider) -- a separator: one thin line, no text
      else
        Untint(texture) -- other art (icons, check boxes): Blizzard's own colours
      end
    end
  end

  local time
  for _, fontString in ipairs(strings) do
    time = time or Time(frame, fontString)
  end
  if not circle and not time then
    HideLook(entryLooks[frame])
    return
  end
  local look = EntryLook(frame)
  if not look then
    return
  end
  if circle then
    for _, key in ipairs({ "ring", "hole", "dot" }) do
      look[key]:ClearAllPoints()
      look[key]:SetPoint("CENTER", circle, "CENTER")
    end
    look.ring:Show()
    look.hole:Show()
  else
    look.ring:Hide()
    look.hole:Hide()
  end
  look.dot:SetShown(circle ~= nil and ticked and true or false)
  look.band:SetShown(circle ~= nil and ticked and true or false)
  if time then
    local source = strings[1]
    local path, size = source:GetFont()
    if type(path) == "string" and Readable(size) and type(size) == "number" and size > 1 then
      ApplyFont(look.time, path, size - 1, "")
    end
    local muted = theme.muted
    look.time:SetTextColor(muted[1], muted[2], muted[3], 1)
    S.TextShadow(look.time, 1, -1, 0, 0, 0, 1) -- none on a light theme
    look.time:SetText(time)
    look.time:Show()
  else
    look.time:Hide()
  end
end

-- A child frame that only carries Blizzard's panel art (never an entry).
local function IsArt(frame)
  return panels[frame] ~= nil
end

-- Every entry frame under a menu (its scroll box and rows), not its scroll bar.
local function Entries(frame, depth)
  if depth <= 0 or not frame.GetChildren then
    return
  end
  local skip = {}
  for key in pairs(SCROLL_KEYS) do
    local bar = S.Child(frame, key)
    if bar then
      skip[bar] = true
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if S.Usable(child) and not skip[child] and not ours[child] and not IsArt(child) then
      StyleEntry(child)
      Entries(child, depth - 1)
    end
  end
end

local function StyleMenu(menu, context)
  if not S.Usable(menu) then
    return
  end
  Panel(menu, context)
  Entries(menu, 4)
end

-- Now, and once more a frame later (entries set up after the menu frame was acquired).
local function StyleSoon(menu, context)
  StyleMenu(menu, context)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      S.Run("menus", StyleMenu, menu, context)
    end)
  end
end

local function Opened(manager, description, context)
  local ok, menu = pcall(manager.GetOpenMenu, manager)
  if ok then
    StyleSoon(menu, context)
  end
  -- submenus: Blizzard calls this for each menu it acquires for the description
  if type(description) == "table" and type(description.AddMenuAcquiredCallback) == "function"
    and S.Once(description, "menus") then
    pcall(description.AddMenuAcquiredCallback, description, function(sub)
      S.Run("menus", StyleSoon, sub, context)
    end)
  end
end

local function HookManager()
  local menu = S.Get("Menu")
  if not menu or type(menu.GetManager) ~= "function" then
    return false
  end
  local ok, manager = pcall(menu.GetManager)
  if not ok or type(manager) ~= "table" then
    return false
  end
  if S.Once(manager, "menus") then
    S.HookMethod(manager, "OpenMenu", function(self, owner, description)
      Opened(self, description, false)
    end)
    S.HookMethod(manager, "OpenContextMenu", function(self, owner, description)
      Opened(self, description, true)
    end)
  end
  return true
end

-- The old dropdown lists (UIDropDownMenu), still used by some addons.
local function OldLists()
  for level = 1, (UIDROPDOWNMENU_MAXLEVELS or 3) do
    local list = S.Get("DropDownList" .. level)
    if list and not lists[list] then
      lists[list] = true
      S.KillKeys(list, "Backdrop", "MenuBackdrop")
      S.KillNamed(S.Name(list), "Backdrop", "MenuBackdrop")
      S.Plate(list, "panel", { corners = true, cornerSize = CornerSize() })
    end
  end
end

S.Part("menus", function()
  OldLists()
  if not HookManager() then
    S.OnAddOn("Blizzard_Menu", HookManager)
  end
end)
