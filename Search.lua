local addonName, ns = ...
local L = ns.L

-- The search box on top of the sidebar: finds any option by its label, its section's or its page's name. The index
-- is built from the widgets themselves the first time something is searched: every area page and every section's
-- body is built then (hidden), so options in sections the player never opened are found too. A result shows the
-- option and where it lives ("Action bars > Proc glow"); a click opens that page, unfolds the section, scrolls to the
-- option and marks it with a short flash in the theme's accent (Areas.lua, ns.FocusSection).

local UI = ns.UI

local MAX_RESULTS = 40
local ROW = 36

local index -- { { text, lower, words, area, section, widget, kind }, ... }

local function Clean(text)
  if type(text) ~= "string" then
    return nil
  end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("\n", " ")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

-- Lower case also for the accented Latin capitals (UTF-8 C3 80-9E) and Cyrillic ones (А-Я, Ё), which Lua's lower
-- leaves alone: the translated pages (2026-11-27) are found whatever case the player types.
local function Lower(text)
  text = text:lower():gsub("\195([\128-\158])", function(c)
    return c == "\151" and "\195\151" or "\195" .. string.char(c:byte() + 32)
  end)
  text = text:gsub("\208([\128-\175])", function(c)
    local b = c:byte()
    if b == 129 then
      return "\209\145" -- Ё
    elseif b >= 144 and b <= 159 then
      return "\208" .. string.char(b + 32) -- А-П
    elseif b >= 160 then
      return "\209" .. string.char(b - 32) -- Р-Я
    end
    return "\208" .. c
  end)
  return text
end

-- Letters, not bytes (Cyrillic and accents take two bytes each).
local function Length(text)
  return select(2, text:gsub("[^\128-\191]", ""))
end

-- A text worth finding: a name, not a sentence of help, a value or a number.
local function Indexable(text)
  if not text or Length(text) < 3 or Length(text) > 64 then
    return false
  end
  if not text:find("[%a\192-\255]") then
    return false
  end
  if text:find("%.$") or text:find("%. ") then
    return false
  end
  return true
end

local function Skip(frame)
  return frame.codexList or frame.codexPicker or frame.codexPicture or frame.codexNoSearch
end

-- Every shown text under `frame` (the section's body: hidden rows, like a list that only opens with an option, are
-- left out; the body itself may be folded away).
local function Walk(frame, visit, depth)
  if depth > 16 or Skip(frame) or (depth > 0 and frame.IsShown and not frame:IsShown()) then
    return
  end
  -- a button's own text (its font string may hold it, or the button itself)
  if frame.GetObjectType and frame:GetObjectType() == "Button" and type(frame.GetText) == "function" then
    local ok, text = pcall(frame.GetText, frame)
    if ok and type(text) == "string" and text ~= "" then
      visit(frame, text)
    end
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "FontString"
      and not region.codexEmbedded and region:IsShown() then
      visit(region)
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if type(child) == "table" then
      Walk(child, visit, depth + 1)
    end
  end
end

local function AreaName(id)
  local area = ns.AREA_BY_ID[id]
  return area and area.name or id
end

local function Add(entry)
  entry.lower = Lower(entry.text)
  index[#index + 1] = entry
end

-- Builds the index (once; ns.ResetSearch() forgets it).
function ns.SearchIndex()
  if index then
    return index
  end
  index = {}
  ns.BuildAllSections()
  for areaOrder, area in ipairs(ns.AREAS) do
    if area.id ~= "home" then
      Add({ text = area.name, area = area.id, kind = "page", order = areaOrder * 1000 })
      local page = ns.areaPages[area.id]
      for sectionOrder, section in ipairs(page and page.sections or {}) do
        local def = section.def
        local order = areaOrder * 1000 + sectionOrder * 10
        local extra = {}
        for _, word in ipairs(def.keywords or {}) do
          if type(word) == "string" then
            extra[#extra + 1] = Lower(word)
          end
        end
        -- a page with one section of its own name (Rings, Info bars) lists once, as the page
        if Lower(def.title) ~= Lower(area.name) then
          Add({ text = def.title, area = area.id, section = def.id, widget = section.header, kind = "section",
            order = order, extra = table.concat(extra, " ") })
        end
        local seen = { [Lower(def.title)] = true }
        if section.holder then
          Walk(section.holder, function(fontString, own)
            local text = Clean(own or fontString:GetText())
            if Indexable(text) and not seen[Lower(text)] then
              seen[Lower(text)] = true
              Add({ text = text, area = area.id, section = def.id, widget = fontString, kind = "option",
                order = order + 1 })
            end
          end, 0)
        end
      end
    end
  end
  return index
end

function ns.ResetSearch()
  index = nil
end

local function SectionTitle(id)
  local def = id and ns.sectionById[id]
  return def and def.title or nil
end

-- The results for a query: every word must be in the option's label, its section's name, its page's name or the
-- feature's own words; labels that start with the query come first. Returns a list of index entries.
function ns.SearchOptions(query)
  query = Clean(query or "")
  if not query or query == "" then
    return {}
  end
  local words = {}
  for word in Lower(query):gmatch("%S+") do
    words[#words + 1] = word
  end
  local whole = Lower(query)
  local results = {}
  for _, entry in ipairs(ns.SearchIndex()) do
    local where = entry.lower .. " " .. Lower(SectionTitle(entry.section) or "") .. " "
      .. Lower(AreaName(entry.area)) .. " " .. (entry.extra or "")
    local all = true
    for _, word in ipairs(words) do
      if not where:find(word, 1, true) then
        all = false
        break
      end
    end
    if all then
      local score
      if entry.lower:sub(1, #whole) == whole then
        score = 0
      elseif entry.lower:find(whole, 1, true) then
        score = 1
      else
        score = 2
      end
      if entry.kind == "page" then
        score = score - 0.5
      elseif entry.kind == "section" then
        score = score - 0.25
      end
      results[#results + 1] = { entry = entry, score = score }
    end
  end
  table.sort(results, function(a, b)
    if a.score ~= b.score then
      return a.score < b.score
    end
    return a.entry.order < b.entry.order
  end)
  local out = {}
  for i = 1, math.min(MAX_RESULTS, #results) do
    out[i] = results[i].entry
  end
  return out
end

-- Where a result lives, for its second line: "Action bars > Proc glow".
function ns.SearchPath(entry)
  local area = AreaName(entry.area)
  if entry.kind == "page" then
    return L["Page"]
  end
  if entry.kind == "section" then
    return area
  end
  return area .. " > " .. (SectionTitle(entry.section) or "")
end

-- Opens a result: the page, the section unfolded, scrolled to the option, a flash on it.
function ns.OpenSearchResult(entry)
  if entry.section then
    ns.ShowPage(entry.section, entry.kind == "option" and entry.widget or nil)
  else
    ns.ShowPage(entry.area)
  end
end

-- The sidebar part ------------------------------------------------------------------------------------------------

local search -- { box, hint, clear, scroll, body, rows, empty }

local function ShowResults(list)
  local nav = ns.window and ns.window.navScroll
  local searching = search.box:GetText() ~= nil and search.box:GetText() ~= ""
  if nav then
    nav:SetShown(not searching)
  end
  search.scroll:SetShown(searching)
  search.clear:SetShown(searching)
  if not searching then
    return
  end
  local width = search.width
  for i, entry in ipairs(list) do
    local row = search.rows[i]
    if not row then
      row = CreateFrame("Button", nil, search.body)
      row:SetSize(width, ROW - 2)
      local hover = row:CreateTexture(nil, "HIGHLIGHT")
      hover:SetAllPoints()
      UI.SetColor(hover, ns.Theme().accent, 0.1)
      row.label = UI.Text(row, "body", 12, "bright")
      row.label:SetPoint("TOPLEFT", 8, -4)
      row.label:SetWidth(width - 14)
      row.label:SetJustifyH("LEFT")
      row.label:SetWordWrap(false)
      row.path = UI.Text(row, "body", 10, "muted")
      row.path:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
      row.path:SetWidth(width - 14)
      row.path:SetJustifyH("LEFT")
      row.path:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        if self.entry then
          ns.OpenSearchResult(self.entry)
        end
      end)
      search.rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", search.body, "TOPLEFT", 0, -(i - 1) * ROW)
    row.entry = entry
    row.label:SetText(entry.text)
    row.path:SetText(ns.SearchPath(entry))
    row:Show()
  end
  for i = #list + 1, #search.rows do
    search.rows[i]:Hide()
  end
  search.empty:SetShown(#list == 0)
  search.body:SetHeight(math.max(10, #list * ROW))
  search.scroll:SetVerticalScroll(0)
  search.scroll:Update()
  search.results = list
end

-- Runs a search from the box's text (or `text`): the results replace the page list until the box is empty.
function ns.SetSearch(text)
  if not search then
    return {}
  end
  if text ~= nil and search.box:GetText() ~= text then
    search.box:SetText(text)
  end
  local query = search.box:GetText() or ""
  search.hint:SetShown(query == "" and not search.focused)
  local list = query ~= "" and ns.SearchOptions(query) or {}
  ShowResults(list)
  return list
end

function ns.ClearSearchFocus()
  if search and search.box.ClearFocus then
    search.box:ClearFocus()
  end
end

-- Builds the box at the top of the sidebar (Window.lua calls it); returns the height it takes.
function ns.BuildSearch(window, side, sideWidth)
  local width = sideWidth - 16
  search = { rows = {}, width = width }
  local box = UI.EditBox(side, width, 24)
  box:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -8)
  box:SetTextInsets(8, 24, 0, 0)
  box:SetMaxLetters(40)
  search.box = box
  local hint = UI.Text(box, "body", 12, "muted")
  hint:SetPoint("LEFT", 8, 0)
  hint:SetPoint("RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(false)
  hint:SetText(L["Search options..."])
  search.hint = hint
  local clear = UI.Button(box, 18, 18, "x")
  clear:SetPoint("RIGHT", -3, 0)
  clear:SetScript("OnClick", function()
    box:SetText("")
    box:ClearFocus()
    ns.SetSearch("")
  end)
  clear:Hide()
  search.clear = clear
  box:SetScript("OnTextChanged", function()
    ns.SetSearch()
  end)
  box:SetScript("OnEditFocusGained", function()
    search.focused = true
    hint:Hide()
  end)
  box:SetScript("OnEditFocusLost", function()
    search.focused = false
    hint:SetShown((box:GetText() or "") == "")
  end)
  box:SetScript("OnEscapePressed", function(self)
    if (self:GetText() or "") ~= "" then
      self:SetText("")
      ns.SetSearch("")
    end
    self:ClearFocus()
  end)
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local first = search.results and search.results[1]
    if first then
      ns.OpenSearchResult(first)
    end
  end)

  local top = 8 + 24 + 8
  local scroll, body = UI.ScrollArea(side)
  scroll:SetPoint("TOPLEFT", 0, -top)
  scroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -2, 8)
  body:SetWidth(sideWidth - 2)
  scroll:Hide()
  search.scroll, search.body = scroll, body
  local empty = UI.Text(body, "body", 12, "muted")
  empty:SetPoint("TOPLEFT", 8, -6)
  empty:SetWidth(width - 8)
  empty:SetJustifyH("LEFT")
  empty:SetText(L["No options match."])
  empty:Hide()
  search.empty = empty
  window.search = search
  return top
end
