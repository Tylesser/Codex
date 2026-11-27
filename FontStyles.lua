local addonName, ns = ...
local L = ns.L

-- Font styles per text element (2026-11-24, the user's "do both" after FlareUI's tracker fonts): an element is a
-- kind of text Codex draws (the tracker's quest names, unit frame names, chat lines, ...). Each one can get its own
-- font, size, outline and shadow; whatever is left alone stays as the element draws it (the theme's font, its own
-- size and look). Settings in CodexDB.fontStyles[key] = { font = ns.FONTS key, size = n, outline = key, shadow = key }.
--
-- Drawing code calls ns.RestyleFont(fontString, key) right after it set the font the usual way: the style is laid
-- over what is there (the size scales by size / the element's base size, so an element's smaller texts follow).
-- Codex_Skins reaches it as TylesserCodex.RestyleFont. A change fires ns.Fire("FONT_STYLE", key); drawing code
-- listens with ns.OnFontStyle(fn) (TylesserCodex.OnFontStyle) and draws its texts again.

ns.FONT_ELEMENTS, ns.FONT_ELEMENT_BY_KEY = {}, {}

-- def = { key, group, label, base (size the element draws at), order, note }
function ns.AddFontElement(def)
  assert(type(def) == "table" and def.key and def.group and def.label, "Codex: a font element needs key, group, label")
  if ns.FONT_ELEMENT_BY_KEY[def.key] then
    return ns.FONT_ELEMENT_BY_KEY[def.key]
  end
  def.base = def.base or 12
  def.order = def.order or (#ns.FONT_ELEMENTS + 1)
  ns.FONT_ELEMENTS[#ns.FONT_ELEMENTS + 1] = def
  ns.FONT_ELEMENT_BY_KEY[def.key] = def
  return def
end

ns.FONT_OUTLINES = {
  { key = "none", name = L["None##outline"], flags = "" },
  { key = "thin", name = L["Thin##outline"], flags = "OUTLINE" },
  { key = "thick", name = L["Thick##outline"], flags = "THICKOUTLINE" },
}
ns.FONT_SHADOWS = {
  { key = "none", name = L["None##outline"], x = 0, y = 0, a = 0 },
  { key = "soft", name = L["Soft##shadow"], x = 1, y = -1, a = 0.6 },
  { key = "strong", name = L["Strong"], x = 2, y = -2, a = 1 },
}
ns.FONT_SIZE_MIN, ns.FONT_SIZE_MAX = 9, 24 -- never under 9 px (the game's fonts blur)

local function Find(list, key)
  for _, entry in ipairs(list) do
    if entry.key == key then
      return entry
    end
  end
  return nil
end
ns.FontChoice = Find

-- The element's saved style, or nil when it is all left alone.
function ns.FontStyle(key)
  local all = ns.db and ns.db.fontStyles
  local style = type(all) == "table" and all[key] or nil
  if type(style) ~= "table" or next(style) == nil then
    return nil
  end
  return style
end

function ns.SetFontStyle(key, field, value)
  if type(ns.db.fontStyles) ~= "table" then
    ns.db.fontStyles = {}
  end
  local style = ns.db.fontStyles[key] or {}
  style[field] = value
  ns.db.fontStyles[key] = next(style) and style or nil
  ns.Fire("FONT_STYLE", key)
end

function ns.ResetFontStyle(key)
  if type(ns.db.fontStyles) == "table" then
    ns.db.fontStyles[key] = nil
  end
  ns.Fire("FONT_STYLE", key)
end

function ns.OnFontStyle(fn)
  ns.On("FONT_STYLE", fn)
end

local function FontPath(key)
  if not key or key == "theme" then
    return nil
  end
  local info = ns.FontInfo and ns.FontInfo(key)
  return info and info.key == key and info.path or nil
end

-- The style laid over a font string's current font. Safe to call again: a font string that still has the font we
-- set last starts from what its drawing code set (kept in codexStyleBase), so sizes never compound.
function ns.RestyleFont(fontString, key)
  if type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" or fontString.codexRestyling then
    return false -- (our own SetFont below, seen again by a SetFont hook on the same text)
  end
  fontString.codexRestyling = true
  local done = ns.RestyleFontNow(fontString, key)
  fontString.codexRestyling = nil
  return done
end

function ns.RestyleFontNow(fontString, key)
  local ok, path, size, flags = pcall(fontString.GetFont, fontString)
  if not ok then
    return false
  end
  local last = fontString.codexStyled
  local base = fontString.codexStyleBase
  if not (last and base and last[1] == path and last[2] == size and last[3] == flags) then
    base = { path, size, flags }
    fontString.codexStyleBase = base
  end
  local style = ns.FontStyle(key)
  if not style then
    if last then -- the style went: back to what the drawing code set
      fontString.codexStyled = nil
      pcall(fontString.SetFont, fontString, base[1], base[2], base[3] or "")
      local shadow = fontString.codexStyleShadow
      if shadow then
        pcall(fontString.SetShadowOffset, fontString, shadow[1], shadow[2])
        pcall(fontString.SetShadowColor, fontString, shadow[3], shadow[4], shadow[5], shadow[6])
        fontString.codexStyleShadow = nil
      end
    end
    return false
  end
  local element = ns.FONT_ELEMENT_BY_KEY[key]
  local newPath = FontPath(style.font) or base[1]
  local newSize = type(base[2]) == "number" and base[2] or 12
  if type(style.size) == "number" then
    if element and element.absolute then
      newSize = style.size -- (the chat: one size for every window)
    else
      newSize = math.max(ns.FONT_SIZE_MIN, newSize * style.size / ((element and element.base) or newSize))
    end
  end
  newSize = math.floor(newSize + 0.5)
  local outline = style.outline and Find(ns.FONT_OUTLINES, style.outline)
  local newFlags = outline and outline.flags or base[3] or ""
  -- SetFont answers false for a font file it can't load (a theme folder that isn't installed): keep the face then
  local called, loaded = pcall(fontString.SetFont, fontString, newPath, newSize, newFlags)
  if not called or loaded == false then
    pcall(fontString.SetFont, fontString, base[1], newSize, newFlags)
  end
  local _, p2, s2, f2 = pcall(fontString.GetFont, fontString)
  fontString.codexStyled = { p2, s2, f2 }
  local shadow = style.shadow and Find(ns.FONT_SHADOWS, style.shadow)
  if shadow then
    if not fontString.codexStyleShadow and fontString.GetShadowOffset and fontString.GetShadowColor then
      local okO, x, y = pcall(fontString.GetShadowOffset, fontString)
      local okC, r, g, b, a = pcall(fontString.GetShadowColor, fontString)
      if okO and okC and type(x) == "number" and type(r) == "number" then
        fontString.codexStyleShadow = { x, y, r, g, b, a }
      end
    end
    pcall(fontString.SetShadowOffset, fontString, shadow.x, shadow.y)
    pcall(fontString.SetShadowColor, fontString, 0, 0, 0, shadow.a)
  end
  return true
end

-- What the settings rows show for a field left alone.
function ns.FontStyleValueName(key, field)
  local style = ns.FontStyle(key) or {}
  local value = style[field]
  if field == "font" then
    return value and ns.FontInfo(value).name or L["Element's own"]
  elseif field == "size" then
    local base = (ns.FONT_ELEMENT_BY_KEY[key] or {}).base or 12
    return value and tostring(value) or L["Own (%d)"]:format(math.floor(base + 0.5))
  elseif field == "outline" then
    local entry = value and Find(ns.FONT_OUTLINES, value)
    return entry and entry.name or L["Own"]
  elseif field == "shadow" then
    local entry = value and Find(ns.FONT_SHADOWS, value)
    return entry and entry.name or L["Own"]
  end
  return ""
end

ns.API.RestyleFont = function(fontString, key)
  return ns.RestyleFont(fontString, key)
end
ns.API.OnFontStyle = function(fn)
  ns.OnFontStyle(fn)
end
ns.API.AddFontElement = function(def)
  return ns.AddFontElement(def)
end

-- The elements. Groups are the pages their rows show on (FontStylesUI.lua makes a "Fonts" section per group).
ns.FONT_GROUPS = {
  { id = "quests", area = "quests", title = L["Fonts"], order = 90 },
  { id = "units", area = "units", title = L["Fonts"], order = 90 },
  { id = "chat", area = "chat", title = L["Fonts"], order = 90 },
  { id = "info", area = "info", title = L["Fonts"], order = 90 },
}
for _, def in ipairs({
  { key = "tracker.header", group = "quests", label = L["Tracker header and zones"], base = 13 },
  { key = "tracker.quest", group = "quests", label = L["Quest names"], base = 12 },
  { key = "tracker.objective", group = "quests", label = L["Objectives"], base = 11.5 },
  { key = "dialogue.title", group = "quests", label = L["Quest window titles"], base = 16 },
  { key = "dialogue.text", group = "quests", label = L["Quest window text"], base = 14 },
  { key = "units.name", group = "units", label = L["Unit frame names"], base = 12 },
  { key = "units.bars", group = "units", label = L["Unit frame bar texts"], base = 10 },
  { key = "plates.name", group = "units", label = L["Nameplate names"], base = 10 },
  { key = "plates.health", group = "units", label = L["Nameplate health text"], base = 10 },
  { key = "personal.text", group = "units", label = L["Personal bars text"], base = 10 },
  { key = "chat.text", group = "chat", label = L["Chat text"], base = 14, absolute = true },
  { key = "chat.tabs", group = "chat", label = L["Chat tabs"], base = 12 },
  { key = "infobar.text", group = "info", label = L["Info bar texts"], base = 12 },
}) do
  ns.AddFontElement(def)
end
