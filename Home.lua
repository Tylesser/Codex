local addonName, ns = ...
local L = ns.L

-- Home: one card per module (in sidebar order: area by area) with its state, what it does and a live status line;
-- a click on a card opens its section. The cards sit in a scrolling area, each row as tall as its tallest card; the
-- footer stays put under them. Switching a feature on or off is done with the switch at the top of its section.

local UI = ns.UI
local cards = {}
local layout -- { intro, body, scroll, columns, gap, cardWidth }

local PAD, ICON, GAP_ROW = 12, 28, 10

-- A card's height from what it holds now (the description and status wrap to any number of lines).
local function CardHeight(card)
  local height = PAD + ICON + 6 + (card.desc:GetStringHeight() or 0)
  local status = card.status:GetText()
  if status and status ~= "" then
    height = height + 5 + (card.status:GetStringHeight() or 0)
  end
  if card.action:IsShown() then
    height = height + 8 + (card.action:GetHeight() or 22)
  end
  return math.ceil(height + PAD)
end

-- Places the cards in rows, each row as tall as its tallest card, and sizes the scrolling body to fit.
local function Layout()
  if not layout then
    return
  end
  local y = -14
  local rowStart = 1
  local function CloseRow(last)
    local tallest = 0
    for i = rowStart, last do
      tallest = math.max(tallest, CardHeight(cards[i]))
    end
    for i = rowStart, last do
      cards[i]:SetHeight(tallest)
    end
    return tallest
  end
  for index, card in ipairs(cards) do
    local column = (index - 1) % layout.columns
    if column == 0 and index > 1 then
      y = y - CloseRow(index - 1) - GAP_ROW
      rowStart = index
    end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", layout.intro, "BOTTOMLEFT", column * (layout.cardWidth + layout.gap), y)
  end
  local last = #cards > 0 and CloseRow(#cards) or 0
  local used = 66 + 14 - y + last -- heading + intro (two lines) + cards
  layout.body:SetHeight(math.max(used + 6, 10))
  layout.scroll:Update()
end

local STATE_TEXT = { on = L["On"], off = L["Off"], standalone = L["Using the standalone addon"] }

local function UpdateCard(card)
  local module = card.module
  local theme = ns.Theme()
  local state = ns.ModuleState(module.id)
  card.state:SetText(STATE_TEXT[state])
  card.state:SetTextColor(UI.Unpack(state == "on" and theme.good or (state == "off" and theme.muted or theme.warn)))
  local dim = state ~= "on"
  card.icon:SetDesaturated(state == "off")
  card.icon:SetAlpha(state == "off" and 0.6 or 1)
  card.name:SetTextColor(UI.Unpack(dim and theme.muted or theme.bright))
  card.desc:SetTextColor(UI.Unpack(state == "off" and theme.muted or theme.text))
  local line = ""
  if state == "standalone" then
    line = L["%s is installed on its own, so Codex leaves this to it."]:format(module.standaloneName or module.standalone)
  elseif state == "on" and module.Status then
    local ok, text = pcall(module.Status, module)
    line = ok and text or ""
  elseif module.error then
    line = L["Failed to start: %s"]:format(tostring(module.error))
  end
  card.status:SetText(line or "")
  card.action:SetShown(state ~= "on")
  card.action:SetText(state == "off" and L["Switch on"] or L["Use Codex's instead"])
  card.action:SetWidth(state == "off" and 96 or 150)
end

local function UpdateAll()
  for _, card in ipairs(cards) do
    UpdateCard(card)
  end
  Layout()
end

ns.builtinPages.home = {
  name = L["Home"],
  Build = function(_, page)
    local width = ns.AREA_WIDTH or 672
    local scroll, body = UI.ScrollArea(page)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", 0, 48)
    body:SetSize(width, 400)
    local inner = width - 12 -- room for the scroll thumb
    local heading = UI.Heading(body, L["Home"], 22)
    heading:SetPoint("TOPLEFT")
    local intro = UI.Text(body, "body", 13, "muted")
    intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    intro:SetWidth(inner)
    intro:SetJustifyH("LEFT")
    intro:SetText(L["Every Tylesser tool in one place. Click a card to open its options; the switch at the top of each section turns that feature on or off. The search box above the pages finds any option."])

    local columns, gap = 2, 10
    local cardWidth = math.floor((inner - gap) / columns)
    layout = { intro = intro, body = body, scroll = scroll, columns = columns, gap = gap, cardWidth = cardWidth }
    for _, module in ipairs(ns.ModulesInOrder()) do
      local card = UI.Inset(body, CreateFrame("Button", nil, body))
      card.module = module
      local hover = card:CreateTexture(nil, "HIGHLIGHT")
      hover:SetAllPoints()
      UI.SetColor(hover, ns.Theme().accent, 0.06)
      card:SetScript("OnClick", function()
        ns.ShowPage(module.id)
      end)
      card:SetSize(cardWidth, 100)
      card.icon = card:CreateTexture(nil, "ARTWORK")
      card.icon:SetSize(ICON, ICON)
      card.icon:SetPoint("TOPLEFT", PAD, -PAD)
      card.icon:SetTexture(module.icon)
      if card.icon.SetTexCoord then
        card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      card.state = UI.Text(card, "body", 12, "good")
      card.state:SetPoint("RIGHT", card, "TOPRIGHT", -PAD, -PAD - ICON / 2)
      card.name = UI.Text(card, "body", 15, "bright")
      card.name:SetPoint("LEFT", card.icon, "RIGHT", 10, 0)
      card.name:SetPoint("RIGHT", card.state, "LEFT", -8, 0)
      card.name:SetWordWrap(false)
      card.name:SetText(module.name)
      card.desc = UI.Text(card, "body", 13, "text")
      card.desc:SetPoint("TOPLEFT", card.icon, "BOTTOMLEFT", 0, -6)
      card.desc:SetPoint("RIGHT", -PAD, 0)
      card.desc:SetJustifyH("LEFT")
      card.desc:SetText(module.desc or "")
      card.status = UI.Text(card, "body", 12, "muted")
      card.status:SetPoint("TOPLEFT", card.desc, "BOTTOMLEFT", 0, -5)
      card.status:SetPoint("RIGHT", -PAD, 0)
      card.status:SetJustifyH("LEFT")
      card.action = UI.Button(card, 96, 22)
      card.action:SetPoint("TOPLEFT", card.status, "BOTTOMLEFT", 0, -8)
      card.action:SetScript("OnClick", function()
        if ns.ModuleState(module.id) == "off" then
          ns.SetModuleWanted(module.id, true)
        else
          ns.ForceModule(module.id)
        end
        UpdateAll()
      end)
      cards[#cards + 1] = card
    end

    -- footer: a line, the /codex hint, Feedback and More addons
    local line = UI.Divider(page)
    line:SetPoint("BOTTOMLEFT", 0, 38)
    line:SetPoint("BOTTOMRIGHT", -12, 38)
    local footer = UI.Text(page, "body", 12, "muted")
    footer:SetPoint("BOTTOMLEFT", 0, 10)
    footer:SetText(L["Type %s to open this window. Theme: %s"]:format("|cffffffff/codex|r", ns.Theme().name or ""))
    local more = UI.Button(page, 104, 26, L["More addons"])
    more:SetPoint("BOTTOMRIGHT", -12, 4)
    more:SetScript("OnClick", ns.T.ShowMoreAddons)
    local feedback = UI.Button(page, 96, 26, L["Feedback"])
    feedback:SetPoint("RIGHT", more, "LEFT", -8, 0)
    feedback:SetScript("OnClick", ns.T.ShowFeedback)
  end,
  Show = function()
    UpdateAll()
    -- text sizes are only right once the window has drawn: measure again on the next frame
    C_Timer.After(0, Layout)
  end,
}

ns.On("RELOAD_STATE", UpdateAll)
