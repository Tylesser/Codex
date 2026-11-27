local addonName, ns = ...

-- Areas: the sidebar is organised by part of the game (the user's choice, 2026-11-19: "I need to go to multiple tabs
-- to change all options on my action bar"). A section starts with its feature's on/off switch and holds every option
-- of that feature. Since 2026-11-21 (the user, of a page of folded sections: "this is not good design, can we make
-- collapsible panels tabs? keep collapsible panels in tabs if they are related") each page has a row of tabs
-- (ns.AREA_TABS): a tab holds one section, shown open without a fold arrow, or a few related ones, foldable as
-- before. A page with one section has no tab row. Sections no tab lists get a tab of their own (at the end).
--
-- Sections come from a registry: ns.AddSection(areaId, def). def:
--   id        unique; a module's section uses the module's id, so ns.ShowPage(moduleId) lands on it
--   title     the header's name (never upper-cased)
--   order     place on the page (low first)
--   module    a module id: the header switch is the module's on/off, the body is the module's own page
--   switch    { get(), set(on), enabled() } for any other switch (a skins part, a quality of life toggle)
--   build(holder, width, section)  fills the body (built the first time it is unfolded, or for the search);
--             may return { Height = fn, Refresh = fn }
--   height    a fixed body height (a page that fills its area: lists to the bottom), or a function
--   estimate  a body height before the game has drawn it (font strings measure 0 until then)
--   refresh(section), show(section)   on every refresh / when its page shows
--   notice(section)  returns text, buttonText, onClick for a line at the top of the body (or nil)
--   folded    folded by default (CodexDB.folded[id] keeps the player's choice)
--   keywords  extra words the search matches (the feature's description)
-- Modules declare where they go: RegisterModule({ area = "trade", sectionOrder = 10, pageHeight, pageEstimate,
-- folded, sectionTitle, BuildSection }); every module without an area lands in General.

local L = ns.L
local UI = ns.UI

local EMBLEM = "Interface\\AddOns\\Codex\\Media\\Emblem"
ns.AREAS = {
  { id = "home", name = L["Home"], icon = EMBLEM },
  { id = "bars", name = L["Action bars"], icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
    desc = L["How your bars look, when they show, glowing procs, new spell ranks and the cooldown manager."] },
  { id = "ringmenus", name = L["Rings"], icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
    desc = L["Ring menus of spells, items, mounts or markers that open round the mouse while you hold a key."] },
  { id = "units", name = L["Unit frames"], icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
    desc = L["Your own frames, the party and the raid, nameplates and the bars under your character."] },
  { id = "auras", name = L["Buffs"], icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
    desc = L["The buffs you track, click-to-buff and dispel buttons, and how buffs and debuffs look."] },
  { id = "items", name = L["Bags and items"], icon = "Interface\\Icons\\INV_Misc_Bag_08",
    desc = L["Bags, bank and guild bank, stat changes on gear, looting and loot rolls."] },
  { id = "quests", name = L["Quests"], icon = "Interface\\Icons\\INV_Misc_Book_08",
    desc = L["Quest windows and keys, the quest tracker and the quest log."] },
  { id = "map", name = L["Map"], icon = "Interface\\Icons\\INV_Misc_Map_01",
    desc = L["The minimap, the world map, quest pins and highlights near you."] },
  { id = "chat", name = L["Chat"], icon = "Interface\\Icons\\INV_Misc_Note_01",
    desc = L["The chat box and the damage meter."] },
  { id = "info", name = L["Info bars"], icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    desc = L["The info bars along the screen edge and under the chat."] },
  { id = "tooltips", name = L["Tooltips"], icon = "Interface\\Icons\\INV_Misc_Book_09",
    desc = L["How tooltips look and what Codex adds to them."] },
  { id = "trade", name = L["Trade"], icon = "Interface\\Icons\\INV_Misc_Coin_01",
    desc = L["The auction house, professions and merchants."] },
  { id = "general", name = L["General"], icon = "Interface\\Icons\\INV_Misc_Gear_01", lower = true,
    desc = L["Restyling the game's interface, game windows and menus, and the Codex window itself."] },
  { id = "look", name = L["Look"], icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_01", lower = true,
    desc = L["The theme, fonts, accent colour and effects."] },
  { id = "profiles", name = L["Profiles"], icon = "Interface\\Icons\\INV_Scroll_03", lower = true,
    desc = L["Saved sets of settings, sharing them, and the first-run setup."] },
}
ns.AREA_BY_ID = {}
for _, area in ipairs(ns.AREAS) do
  ns.AREA_BY_ID[area.id] = area
end

-- The tabs of each page: { title, section ids, shown name } in order. Related features share a tab (and fold there).
-- The title stays English: the chosen tab is saved by it (CodexDB.areaTabs); the third value is what the tab shows
-- (addon names stay as they are).
ns.AREA_TABS = {
  bars = {
    { "Look", { "part-actionbars" }, L["Look"] }, { "Visibility", { "barfade" }, L["Visibility"] },
    { "Proc glow", { "qol-procGlow" }, L["Proc glow"] },
    { "Spells", { "qol-spellRanks", "qol-futureSpells" }, L["Spells"] },
    { "Cooldown manager", { "part-cooldowns" }, L["Cooldown manager"] },
    { "Buttons", { "qol-hoverBind", "qol-cooldownNumbers", "qol-greyOut", "qol-hideEmpty" }, L["Buttons"] },
  },
  units = {
    { "Player and target", { "part-unitframes" }, L["Player and target"] }, { "Party", { "part-partyframes" }, L["Party"] },
    { "Raid", { "part-raidframes" }, L["Raid"] }, { "Nameplates", { "part-nameplates" }, L["Nameplates"] },
    { "Personal bars", { "resource" }, L["Personal bars"] }, { "Skull mark", { "qol-skullMark" }, L["Skull mark"] },
  },
  auras = {
    { "Buff tracker", { "buffs" }, L["Buff tracker"] },
    { "Party buttons", { "buffs-party", "buffs-dispel" }, L["Party buttons"] },
    { "Look", { "part-auras" }, L["Look"] },
  },
  items = {
    { "Bags", { "bags" }, L["Bags"] }, { "Stat Delta", { "statdelta" } },
    { "Looting", { "qol-fasterLoot", "loottext", "part-lootroll" }, L["Looting"] },
  },
  quests = {
    { "Quest windows", { "dialogue", "questkeys" }, L["Quest windows"] },
    { "Tracker", { "questtracker", "part-tracker", "qol-trackerSort" }, L["Tracker"] },
    { "Quest log", { "part-questlog" }, L["Quest log"] },
  },
  map = {
    { "Minimap", { "part-minimap", "qol-addonButtons" }, L["Minimap"] },
    { "World map", { "qol-revealMap", "qol-zoneLevels", "qol-mapExtras", "part-questpins" }, L["World map"] },
    { "Highlights", { "highlight" }, L["Highlights"] },
  },
  chat = {
    { "Chat", { "part-chat" }, L["Chat"] }, { "Damage meter", { "part-damagemeter" }, L["Damage meter"] },
    { "Trade Crier", { "crier" } },
  },
  tooltips = {
    { "Look", { "part-tooltips" }, L["Look"] },
    { "Extra lines", { "qol-questTooltips", "qol-gatherTooltips", "tooltipextras" }, L["Extra lines"] },
  },
  trade = {
    { "Auction house", { "auction", "auction-lists", "auction-prices" }, L["Auction house"] },
    { "Professions", { "professions" }, L["Professions"] },
    { "Commerce Authority", { "commerce" } }, { "Merchants", { "vendor", "vendorsearch" }, L["Merchants"] },
    { "Trainers", { "qol-trainerAll" }, L["Trainers"] },
  },
  general = {
    { "Restyle", { "restyle", "part-windows", "part-menus", "part-floatingtext" }, L["Restyle"] },
    { "Move windows", { "movewindows" }, L["Move windows"] }, { "Quality of life", { "qol" }, L["Quality of life"] },
    { "Codex window", { "codexwindow" }, L["Codex window"] },
  },
  look = {
    { "Theme", { "theme" }, L["Theme"] }, { "Fonts", { "fonts" }, L["Fonts"] },
    { "Accent colour", { "accent" }, L["Accent colour"] }, { "Effects", { "effects" }, L["Effects"] },
  },
  profiles = { { "Profiles", { "profiles" }, L["Profiles"] }, { "First-run setup", { "setup" }, L["First-run setup"] } },
}

-- Old page names that still open something: Settings and its tabs (ns.ShowSettings).
local PAGE_ALIASES = { settings = "general", modules = "home", interface = "general", ui = "general" }
ns.PAGE_ALIASES = PAGE_ALIASES

ns.sections, ns.sectionById = {}, {}
local sectionAlias = {} -- module id / other names -> section id

function ns.AddSection(areaId, def)
  assert(type(def) == "table" and def.id and def.title, "Codex: a section needs an id and a title")
  if ns.sectionById[def.id] then
    return ns.sectionById[def.id]
  end
  def.area = ns.AREA_BY_ID[areaId] and areaId or "general"
  def.order = def.order or 100
  ns.sections[#ns.sections + 1] = def
  ns.sectionById[def.id] = def
  for _, alias in ipairs(def.aliases or {}) do
    sectionAlias[alias] = def.id
  end
  if def.module then
    sectionAlias[def.module] = def.id
  end
  return def
end

-- A module's on/off as a header switch.
local function ModuleWanted(id)
  local module = ns.modules[id]
  local wanted = ns.db and ns.db.modules[id]
  if wanted == nil then
    wanted = module and module.default
  end
  return wanted and true or false
end
ns.ModuleWanted = ModuleWanted

local function ModuleNotice(section)
  local module = ns.modules[section.def.module]
  if not module then
    return nil
  end
  local state = ns.ModuleState(module.id)
  if state == "standalone" then
    return L["%s is installed on its own, so Codex leaves this to it."]:format(module.standaloneName or module.standalone),
      L["Use Codex's instead"], function()
        ns.ForceModule(module.id)
      end
  end
  if module.error then
    return L["Failed to start: %s"]:format(tostring(module.error))
  end
  if state == "on" and not module.running then
    return L["Switched on: it starts after a reload."]
  end
  if state == "off" and module.running then
    return L["Switched off: it stops after a reload."]
  end
  return nil
end

-- One section per module, made when the sections are first asked for (every module has registered by then).
local function ModuleSections()
  for _, module in ipairs(ns.moduleList) do
    if not ns.sectionById[module.id] and not sectionAlias[module.id] then
      local id = module.id
      ns.AddSection(module.area or "general", {
        id = id,
        module = id,
        title = module.sectionTitle or module.name,
        order = module.sectionOrder or module.order,
        height = module.pageHeight,
        estimate = module.pageEstimate,
        folded = module.folded,
        keywords = { module.name, module.desc },
        desc = module.desc,
        switch = {
          get = function()
            return ModuleWanted(id)
          end,
          set = function(on)
            ns.SetModuleWanted(id, on)
          end,
        },
        notice = ModuleNotice,
        build = function(holder, width, section)
          if module.BuildSection then
            return module.BuildSection(module, holder, width, section)
          end
          if module.BuildPage then
            module.BuildPage(module, holder)
          end
        end,
        show = function(section)
          if module.ShowPage and section.holder then
            module.ShowPage(module, section.holder)
          end
        end,
      })
    end
  end
end

local function SortedSections(areaId)
  ModuleSections()
  local list = {}
  for _, def in ipairs(ns.sections) do
    if def.area == areaId then
      list[#list + 1] = def
    end
  end
  table.sort(list, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.title < b.title
  end)
  return list
end
ns.SectionsOf = SortedSections

function ns.AllSections()
  ModuleSections()
  return ns.sections
end

-- A page or section name -> area id, section id (nil for a whole page). Unknown -> nil.
function ns.ResolvePage(id)
  if type(id) ~= "string" then
    return nil
  end
  id = PAGE_ALIASES[id] or id
  if ns.AREA_BY_ID[id] then
    return id, nil
  end
  ModuleSections()
  local sectionId = ns.sectionById[id] and id or sectionAlias[id]
  local def = sectionId and ns.sectionById[sectionId]
  if def then
    return def.area, def.id
  end
  return nil
end

-- The modules in sidebar order (Home's cards): area by area, section by section.
function ns.ModulesInOrder()
  local list, seen = {}, {}
  for _, area in ipairs(ns.AREAS) do
    for _, def in ipairs(SortedSections(area.id)) do
      local module = def.module and ns.modules[def.module]
      if module and not seen[module] then
        seen[module] = true
        list[#list + 1] = module
      end
    end
  end
  for _, module in ipairs(ns.moduleList) do
    if not seen[module] then
      list[#list + 1] = module
    end
  end
  return list
end

-- Folding ---------------------------------------------------------------------------------------------------------

function ns.SectionFolded(id)
  local def = ns.sectionById[id]
  local saved
  if ns.db and type(ns.db.folded) == "table" then
    saved = ns.db.folded[id]
  end
  if saved == nil then
    return def and def.folded and true or false
  end
  return saved and true or false
end

-- A section alone in its tab is always open (it has no fold arrow).
local function IsFolded(section)
  return not section.single and ns.SectionFolded(section.def.id)
end

local pages = {} -- [areaId] = the area page (built)
ns.areaPages = pages
local EnsureBody, RefreshSection -- defined with the sections below

function ns.SetSectionFolded(id, folded)
  if type(ns.db.folded) ~= "table" then
    ns.db.folded = {}
  end
  ns.db.folded[id] = folded and true or false
  local def = ns.sectionById[id]
  local page = def and pages[def.area]
  if page then
    local section = page.byId[id]
    if section and not folded then
      -- opened: built now if it never was, then read again like a page that shows
      EnsureBody(section)
      RefreshSection(section)
      if def.show then
        local ok, err = pcall(def.show, section)
        if not ok then
          geterrorhandler()(err)
        end
      end
    end
    page.Layout()
    C_Timer.After(0, page.Layout)
  end
end

-- Measuring -------------------------------------------------------------------------------------------------------

-- How far below `holder`'s top its shown content reaches, from the game's own layout (nil before the first draw, and
-- in the test mock). A page's own scroll frame doesn't count, its content does.
local function Extent(holder)
  if type(holder.GetTop) ~= "function" then
    return nil
  end
  local top = holder:GetTop()
  if type(top) ~= "number" then
    return nil
  end
  local lowest
  local function Note(region)
    local ok, bottom = pcall(region.GetBottom, region)
    if ok and type(bottom) == "number" and (not lowest or bottom < lowest) then
      lowest = bottom
    end
  end
  local function Visit(frame, depth)
    if depth > 14 then
      return
    end
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:IsShown() and not region.codexEmbedded then
        Note(region)
      end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
      if child:IsShown() and not child.codexMeasureSkip then
        if child:GetObjectType() == "ScrollFrame" then
          local inner = type(child.GetScrollChild) == "function" and child:GetScrollChild()
          if inner then
            Note(inner)
            Visit(inner, depth + 1)
          end
        else
          Note(child)
          Visit(child, depth + 1)
        end
      end
    end
  end
  Visit(holder, 0)
  if not lowest or lowest >= top then
    return nil
  end
  return math.ceil(top - lowest + 4)
end
ns.MeasureExtent = Extent

local function ContentHeight(section)
  local def, holder = section.def, section.holder
  local fixed = def.height
  if type(fixed) == "function" then
    local ok, value = pcall(fixed, section)
    fixed = ok and value or nil
  end
  if type(fixed) == "number" then
    return fixed, true
  end
  local result = section.result
  if result and type(result.Height) == "function" then
    local ok, value = pcall(result.Height)
    if ok and type(value) == "number" then
      return math.max(1, value)
    end
  end
  -- a module page with its own scroll area: as tall as that area's content (its own layout sets it)
  for _, child in ipairs({ holder:GetChildren() }) do
    if type(child) == "table" and child.codexScrollArea and child.body then
      local height = child.body:GetHeight()
      if type(height) == "number" and height > 1 then
        return math.ceil(height)
      end
    end
  end
  local measured = Extent(holder)
  if measured then
    section.measured = measured
    return measured
  end
  return section.measured or def.estimate or 240
end

-- Sections --------------------------------------------------------------------------------------------------------

local HEADER, PAD_TOP, PAD_BOTTOM, GAP = 30, 8, 16, 6
local INDENT = 16 -- the body starts under the title, past the fold arrow
ns.SECTION_HEADER = HEADER

local function SectionOn(def)
  if def.switch then
    local ok, on = pcall(def.switch.get)
    return ok and on and true or false
  end
  return true
end

local function SwitchEnabled(def)
  if def.switch and def.switch.enabled then
    local ok, on = pcall(def.switch.enabled)
    return ok and on and true or false
  end
  return true
end

local function RefreshHeader(section)
  local def, theme = section.def, ns.Theme()
  local on = SectionOn(def)
  if section.switch then
    section.switch:SetChecked(on)
    section.switch:SetEnabled(SwitchEnabled(def))
  end
  section.title:SetTextColor(UI.Unpack((on and SwitchEnabled(def)) and theme.bright or theme.muted))
  local tag = ""
  if def.tag then
    local ok, text = pcall(def.tag, section)
    tag = ok and text or ""
  elseif def.module then
    local state = ns.ModuleState(def.module)
    tag = state == "standalone" and L["addon"] or ""
  end
  section.tag:SetText(tag or "")
  section.arrow:SetOpen(not IsFolded(section))
end

-- The line at the top of a body (why the feature waits, a button that fixes it).
local function RefreshNotice(section)
  local notice = section.notice
  if not notice then
    return 0
  end
  local text, buttonText, onClick
  if section.def.notice then
    local ok, a, b, c = pcall(section.def.notice, section)
    if ok then
      text, buttonText, onClick = a, b, c
    end
  end
  if not text or text == "" then
    notice:Hide()
    return 0
  end
  notice:Show()
  notice.text:SetText(text)
  notice.button:SetShown(buttonText ~= nil)
  if buttonText then
    notice.button:SetText(buttonText)
    notice.button:SetWidth(math.max(90, math.min(170, notice.button.label:GetStringWidth() + 24)))
    notice.button:SetScript("OnClick", function()
      onClick()
      ns.RefreshSections()
    end)
    notice.text:SetPoint("RIGHT", notice.button, "LEFT", -10, 0)
  else
    notice.text:SetPoint("RIGHT", notice, "RIGHT", -8, 0)
  end
  local measured = notice.text.GetStringHeight and notice.text:GetStringHeight()
  local textHeight = type(measured) == "number" and measured > 1 and measured
    or (ns.UITextHeight and ns.UITextHeight(notice.text, 12, notice.textWidth) or 16)
  local height = math.max(buttonText and 30 or 24, math.ceil(textHeight) + 12)
  notice:SetHeight(height)
  return height
end

local function Notice(section)
  local notice = CreateFrame("Frame", nil, section.body)
  notice:SetPoint("TOPLEFT")
  notice:SetPoint("TOPRIGHT")
  notice:SetHeight(28)
  UI.Inset(section.body, notice)
  notice.button = UI.Button(notice, 140, 22, "")
  notice.button:SetPoint("RIGHT", -4, 0)
  notice.text = UI.Text(notice, "body", 12, "warn")
  notice.text:SetPoint("LEFT", 8, 0)
  notice.text:SetPoint("RIGHT", notice.button, "LEFT", -10, 0)
  notice.text:SetJustifyH("LEFT")
  notice.text:SetWordWrap(true)
  notice.textWidth = section.inner - 170
  notice.codexNoSearch = true
  notice:Hide()
  section.notice = notice
end

-- Builds the section's body (once): the notice line and the feature's own options.
function EnsureBody(section)
  if section.built then
    return
  end
  section.built = true
  local def = section.def
  Notice(section)
  local holder = CreateFrame("Frame", nil, section.body)
  holder:SetPoint("TOPLEFT")
  holder:SetSize(section.inner, type(def.height) == "number" and def.height or def.estimate or 200)
  section.holder = holder
  section.refreshers = {}
  function section.Register(item)
    section.refreshers[#section.refreshers + 1] = item
    return item
  end
  if def.build then
    ns.embedding = true -- UI.Heading hides a module page's own title: the header names it
    local ok, result = pcall(def.build, holder, section.inner, section)
    ns.embedding = nil
    if ok then
      section.result = type(result) == "table" and result or nil
    else
      local text = UI.Text(holder, "body", 12, "bad")
      text:SetPoint("TOPLEFT")
      text:SetWidth(section.inner)
      text:SetJustifyH("LEFT")
      text:SetText(L["This section failed to load: %s"]:format(tostring(result)))
      section.result = { Height = function() return 40 end }
      geterrorhandler()(result)
    end
  end
  if type(ns.InfoWatch) == "function" then
    ns.InfoWatch(section, holder)
  end
end
ns.EnsureSectionBody = EnsureBody

function RefreshSection(section)
  RefreshHeader(section)
  if not section.built then
    return
  end
  for _, item in ipairs(section.refreshers) do
    if type(item) == "function" then
      pcall(item)
    elseif type(item) == "table" and type(item.refresh) == "function" then
      local ok, err = pcall(item.refresh, item)
      if not ok then
        geterrorhandler()(err)
      end
    end
  end
  if section.result and type(section.result.Refresh) == "function" then
    pcall(section.result.Refresh)
  end
  if section.def.refresh then
    local ok, err = pcall(section.def.refresh, section)
    if not ok then
      geterrorhandler()(err)
    end
  end
end

-- Places the body and returns the section's full height (header only while folded).
local function MeasureSection(section)
  local folded = IsFolded(section)
  section.arrow:SetOpen(not folded)
  if folded then
    section.body:Hide() -- the line under the header stays: it parts the folded sections
    return HEADER
  end
  EnsureBody(section)
  section.body:Show()
  local noticeHeight = RefreshNotice(section)
  local top = noticeHeight > 0 and noticeHeight + 10 or 0
  section.holder:ClearAllPoints()
  section.holder:SetPoint("TOPLEFT", section.body, "TOPLEFT", 0, -top)
  local content = ContentHeight(section)
  -- also a fixed height: one given as a function (Buffs' pageHeight) left the holder at its first estimate
  -- (200), and lists anchored to its bottom were one row tall (the user's screenshot, 2026-11-19)
  section.holder:SetHeight(math.max(1, content))
  section.body:SetHeight(top + content)
  section.bodyHeight = top + content
  return HEADER + PAD_TOP + top + content + PAD_BOTTOM
end

local function BuildSectionFrame(page, def, width)
  local section = CreateFrame("Frame", nil, page.body)
  section.def = def
  section:SetWidth(width)
  section.inner = width - INDENT - 2
  local theme = ns.Theme()

  local header = CreateFrame("Button", nil, section)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(HEADER)
  local hover = header:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, theme.accent, 0.06)
  section.header = header

  section.arrow = UI.FoldArrow(header, theme.muted)
  section.arrow:SetPoint("LEFT", header, "LEFT", 3, 0)

  local right = header
  if def.switch then
    section.switch = UI.Switch(header)
    section.switch:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    section.switch:SetScript("OnClick", function(self)
      local ok, err = pcall(def.switch.set, self:GetChecked() and true or false)
      if not ok then
        geterrorhandler()(err)
      end
      ns.RefreshSections()
    end)
    right = section.switch
  end
  section.tag = UI.Text(header, "body", 11, "muted")
  section.tag:SetPoint("RIGHT", right, right == header and "RIGHT" or "LEFT", right == header and -8 or -8, 0)
  section.tag:SetJustifyH("RIGHT")
  section.tag:SetWordWrap(false)
  section.title = UI.Text(header, "head", 14, "bright")
  section.title:SetPoint("LEFT", header, "LEFT", INDENT, 0)
  section.title:SetPoint("RIGHT", header, "RIGHT", def.switch and -130 or -90, 0)
  section.title:SetJustifyH("LEFT")
  section.title:SetWordWrap(false)
  section.title:SetText(def.title)
  -- the switch reads as the title's: a click on the header (not on the switch) folds or opens the section
  header:SetScript("OnClick", function()
    if not section.single then
      ns.SetSectionFolded(def.id, not ns.SectionFolded(def.id))
    end
  end)

  section.line = UI.Divider(section)
  section.line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", INDENT, 0)
  section.line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)

  section.body = CreateFrame("Frame", nil, section)
  section.body:SetPoint("TOPLEFT", section, "TOPLEFT", INDENT, -(HEADER + PAD_TOP))
  section.body:SetSize(section.inner, 10)
  section.body:Hide()
  -- the info panel (Info.lua) follows the mouse: the header and the switch name the section
  local function Hover()
    if type(ns.InfoHover) == "function" then
      ns.InfoHover(section)
    end
  end
  header:HookScript("OnEnter", Hover)
  if section.switch then
    section.switch:HookScript("OnEnter", Hover)
  end
  RefreshHeader(section)
  return section
end

-- The page of one area: its name, one line about it, then the sections in a scroll area.
local function BuildAreaPage(area, page)
  local width = ns.AREA_WIDTH or 672
  page.area = area.id
  local heading = UI.Heading(page, area.name, 22)
  heading:SetPoint("TOPLEFT")
  local intro = UI.Text(page, "body", 12, "muted")
  intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  intro:SetWidth(width - 14)
  intro:SetJustifyH("LEFT")
  intro:SetWordWrap(false)
  intro:SetText(area.desc or "")
  page.heading, page.intro = heading, intro
  local scroll, body = UI.ScrollArea(page)
  scroll:SetPoint("BOTTOMRIGHT")
  body:SetWidth(width)
  page.scroll, page.body = scroll, body
  page.sections, page.byId = {}, {}
  local sectionWidth = width - 14 -- room for the scroll thumb; a section's body is ns.PAGE_WIDTH wide
  page.sectionWidth = sectionWidth
  for _, def in ipairs(SortedSections(area.id)) do
    local section = BuildSectionFrame(page, def, sectionWidth)
    page.sections[#page.sections + 1] = section
    page.byId[def.id] = section
  end
  if #page.sections == 0 then
    local empty = UI.Text(body, "body", 12, "muted")
    empty:SetPoint("TOPLEFT")
    empty:SetText(L["Nothing here yet."])
  end
  -- the tabs: ns.AREA_TABS' groups that have sections here, then a tab for each section none of them lists
  page.tabs, page.tabOf = {}, {}
  local listed = {}
  for index, spec in ipairs(ns.AREA_TABS[area.id] or {}) do
    local tab = { id = area.id .. ":" .. index, title = spec[1], text = spec[3] or spec[1], sections = {} }
    for _, id in ipairs(spec[2]) do
      local section = page.byId[id]
      if section and not listed[id] then
        listed[id] = true
        tab.sections[#tab.sections + 1] = section
      end
    end
    if #tab.sections > 0 then
      page.tabs[#page.tabs + 1] = tab
    end
  end
  for _, section in ipairs(page.sections) do
    if not listed[section.def.id] then
      -- saved by the section id: its title may be translated (an older save holds the English title: see below)
      page.tabs[#page.tabs + 1] = { id = section.def.id, title = section.def.id, text = section.def.title,
        sections = { section } }
    end
  end
  for _, tab in ipairs(page.tabs) do
    for _, section in ipairs(tab.sections) do
      page.tabOf[section.def.id] = tab
      section.tab = tab.id
      section.single = #tab.sections == 1
      section.arrow:SetShown(not section.single)
    end
  end
  if #page.tabs > 1 then
    local list = {}
    for _, tab in ipairs(page.tabs) do
      list[#list + 1] = { id = tab.id, text = tab.text }
    end
    page.tabBar = UI.Tabs(page, list, function(id)
      page.SelectTab(id)
    end)
    page.tabBar:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
    page.tabBar:SetPoint("RIGHT", page, "RIGHT", -14, 0)
    scroll:SetPoint("TOPLEFT", page.tabBar, "BOTTOMLEFT", 0, -10)
  else
    scroll:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -12)
  end
  function page.Layout()
    local y = 0
    for _, section in ipairs(page.sections) do
      if page.tab and section.tab ~= page.tab then
        section:Hide()
      else
        section:Show()
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        local height = MeasureSection(section)
        section:SetHeight(height)
        section.y = y
        y = y + height + GAP
      end
    end
    body:SetHeight(math.max(10, y))
    scroll:Update()
  end
  -- a tab chosen: its sections refreshed and shown, from the top (the choice is kept per page, not in profiles)
  local function MarkTab(id)
    if not page.tabBar then
      return
    end
    page.tabBar.current = id
    local theme = ns.Theme()
    for tabID, button in pairs(page.tabBar.buttons) do
      local on = tabID == id
      button.underline:SetShown(on)
      button.label:SetTextColor(UI.Unpack(on and UI.SelectedText(theme) or theme.muted))
    end
  end
  function page.SelectTab(id, keepScroll)
    local found
    for _, tab in ipairs(page.tabs) do
      if tab.id == id then
        found = tab
      end
    end
    found = found or page.tabs[1]
    if not found then
      return
    end
    page.tab = found.id
    if type(ns.db.areaTabs) ~= "table" then
      ns.db.areaTabs = {}
    end
    ns.db.areaTabs[area.id] = found.title
    MarkTab(found.id)
    for _, section in ipairs(found.sections) do
      RefreshSection(section)
      if not IsFolded(section) then
        EnsureBody(section)
        if section.def.show then
          local ok, err = pcall(section.def.show, section)
          if not ok then
            geterrorhandler()(err)
          end
        end
      end
    end
    if not keepScroll then
      scroll:SetVerticalScroll(0)
    end
    page.Layout()
    C_Timer.After(0, page.Layout)
    if not keepScroll and type(ns.InfoForPage) == "function" then
      ns.InfoForPage(page)
    end
  end
  local saved = type(ns.db.areaTabs) == "table" and ns.db.areaTabs[area.id]
  local first = page.tabs[1]
  for _, tab in ipairs(page.tabs) do
    if tab.title == saved or (tab.title == tab.id and tab.text == saved) then
      first = tab
    end
  end
  page.tab = first and first.id or nil
  if first then
    MarkTab(first.id)
  end
  -- the flash that marks what the search (or ShowPage) went to: the theme's accent, fading out
  local flash = CreateFrame("Frame", nil, body)
  flash:SetFrameLevel((body:GetFrameLevel() or 1) + 40)
  local fill = flash:CreateTexture(nil, "OVERLAY")
  fill:SetAllPoints()
  UI.SetColor(fill, ns.Theme().accent, 0.16)
  local lines = ns.T.Outline(flash, 0, ns.Theme().accent, 1, "OVERLAY")
  ns.T.ColorLines(lines, ns.Theme().accent, 0.9)
  flash.codexNoSearch = true
  flash.codexMeasureSkip = true
  flash:Hide()
  page.flash = flash
  pages[area.id] = page
  page.Layout()
end

local function ShowAreaPage(page)
  for _, section in ipairs(page.sections) do
    RefreshSection(section)
    local here = not page.tab or section.tab == page.tab
    if here and not IsFolded(section) then
      EnsureBody(section)
    end
    if here and section.built and section.def.show and not IsFolded(section) then
      local ok, err = pcall(section.def.show, section)
      if not ok then
        geterrorhandler()(err)
      end
    end
  end
  page.Layout()
  -- texts only measure once drawn: lay out again on the next frame
  C_Timer.After(0, page.Layout)
end

for _, area in ipairs(ns.AREAS) do
  if area.id ~= "home" then
    ns.builtinPages[area.id] = {
      name = area.name,
      area = area,
      Build = function(_, page)
        BuildAreaPage(area, page)
      end,
      Show = function(_, page)
        ShowAreaPage(page)
      end,
    }
  end
end

-- Refreshes every built section (switches, notices, options): after any change that others may show.
function ns.RefreshSections()
  for _, page in pairs(pages) do
    for _, section in ipairs(page.sections) do
      RefreshSection(section)
    end
    if page:IsShown() then
      page.Layout()
    end
  end
end

-- Builds every area page and every section's body (hidden), for the search and the tests.
function ns.BuildAllSections()
  for _, area in ipairs(ns.AREAS) do
    if area.id ~= "home" and type(ns.EnsurePage) == "function" then
      local page = ns.EnsurePage(area.id)
      if page and page.sections then
        for _, section in ipairs(page.sections) do
          EnsureBody(section)
          RefreshSection(section)
          ContentHeight(section) -- lays the body out (a folded one too), so what it holds has its place
        end
      end
    end
  end
  return pages
end

-- The built section frame of a section id (its page built first), or nil.
function ns.SectionFrame(id)
  local def = ns.sectionById[id]
  if not def or type(ns.EnsurePage) ~= "function" then
    return nil
  end
  local page = ns.EnsurePage(def.area)
  return page and page.byId and page.byId[id], page
end

-- Flash: an accent band over the widget (the whole width of its section), fading out.
local function Flash(page, section, widget)
  local flash = page.flash
  flash:ClearAllPoints()
  local target = widget or section.header
  flash:SetPoint("LEFT", section, "LEFT", INDENT - 6, 0)
  flash:SetPoint("RIGHT", section, "RIGHT", 2, 0)
  flash:SetPoint("TOP", target, "TOP", 0, 4)
  flash:SetPoint("BOTTOM", target, "BOTTOM", 0, -4)
  flash.target = target
  flash.left = 1.6
  flash:SetAlpha(1)
  flash:Show()
  flash:SetScript("OnUpdate", function(self, elapsed)
    self.left = self.left - (elapsed or 0)
    if self.left <= 0 then
      self:Hide()
      self:SetScript("OnUpdate", nil)
    elseif self.left < 0.8 then
      self:SetAlpha(self.left / 0.8)
    end
  end)
end

-- Scrolls the page so the section (or the widget inside it) sits near the top.
local function ScrollTo(page, section, widget)
  local function Go()
    local scroll, body = page.scroll, page.body
    local y = (section.y or 0)
    local bodyTop = body.GetTop and body:GetTop()
    local target = widget and widget.GetTop and widget:GetTop()
    if type(bodyTop) == "number" and type(target) == "number" then
      y = bodyTop - target - 36
    end
    local range = math.max(0, (body:GetHeight() or 0) - (scroll:GetHeight() or 0))
    scroll:SetVerticalScroll(math.max(0, math.min(range, y)))
    scroll:Update()
  end
  Go()
  C_Timer.After(0, function()
    page.Layout()
    Go()
  end)
end

-- Opens a section on its page: unfolds it, scrolls to it (or to `widget` in it) and marks it with a flash.
-- Window.lua's ShowPage calls it for a module or section id.
function ns.FocusSection(id, widget, flash)
  local section, page = ns.SectionFrame(id)
  if not section then
    return nil
  end
  if section.tab and page.tab ~= section.tab and page.SelectTab then
    page.SelectTab(section.tab, true)
  end
  if ns.SectionFolded(id) then
    if type(ns.db.folded) ~= "table" then
      ns.db.folded = {}
    end
    ns.db.folded[id] = false
  end
  page.Layout()
  if section.built and section.def.show then
    pcall(section.def.show, section)
  end
  ScrollTo(page, section, widget)
  if flash ~= false then
    Flash(page, section, widget)
  end
  page.focused = id
  return section
end

ns.On("RELOAD_STATE", function()
  ns.RefreshSections()
end)
