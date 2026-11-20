local addonName, ns = ...

-- Professions module, part 5: the module's page in the Codex window: options, the recipes Codex knows per
-- character, and how it works.

local P = ns.professions
local UI = ns.UI

local view = {}

local OPTIONS = {
  { "block", "Profit block in the profession window", "Reagent cost, AH value and profit under the selected recipe." },
  { "panel", "Profit list beside the profession window", "Every recipe, sorted by profit. Click the block to show or hide it." },
  { "tooltip", "Craft cost and profit in item tooltips", "For items any of your characters can make." },
  { "tooltipValue", "AH value in item tooltips", "Only while the Auction House module's own price line is off." },
  { "craftReagents", "Craft cheaper reagents", "Use a reagent's craft cost when making it is cheaper than buying it." },
}

local HOW = "Open a profession: Codex reads its recipes, prices every reagent and shows the selected recipe's "
  .. "reagent cost, auction value (times the amount made, after the auction house cut) and profit under the "
  .. "reagents. Hover the block for the price of each reagent.\n\n"
  .. "Prices come from Codex's own auction scans (Auction House module): scan at the auction house first. "
  .. "Reagents a vendor sells use the vendor's price once you have visited a vendor that sells them.\n\n"
  .. "Codex remembers the recipes of every character whose profession window you opened, so item tooltips "
  .. "show the craft cost and profit even while the window is closed, and for items only an alt can make.\n\n"
  .. "In the profit list, right-click recipes to queue them, then click Shopping list: the reagents you still "
  .. "need go to the Codex shopping list \"" .. P.LIST_NAME .. "\", ready to search at the auction house."

function P.StatusText()
  local db = P.DB()
  local recipes, chars = 0, 0
  for _, char in pairs(db and db.characters or {}) do
    local count = P.RecipeCount(char)
    if count > 0 then
      recipes, chars = recipes + count, chars + 1
    end
  end
  if recipes == 0 then
    return "No recipes yet: open a profession window once so Codex learns your recipes."
  end
  return ("%d recipes known on %d character%s."):format(recipes, chars, chars == 1 and "" or "s")
end

local function CharacterText()
  local db = P.DB()
  local lines = {}
  for _, key in ipairs(P.CharacterKeys()) do
    local char = db.characters[key]
    local profs = {}
    for prof in pairs(char.profs or {}) do
      profs[#profs + 1] = prof
    end
    table.sort(profs)
    lines[#lines + 1] = ("%s: %d recipes |cff999999(%s)|r"):format(ns.CharacterDisplayName(char, key), P.RecipeCount(char),
      table.concat(profs, ", "))
  end
  if #lines == 0 then
    return "|cff999999None yet.|r"
  end
  return table.concat(lines, "\n")
end

function P.RefreshPage()
  if not view.page then
    return
  end
  local db = P.DB()
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key])
  end
  view.status:SetText(P.StatusText())
  view.cut:SetText(("Auction house cut: %g%%"):format(db.ahCut))
  view.chars:SetText(CharacterText())
end

-- One of the options (also from the Tooltips page's "Prices and stats in tooltips").
function P.SetOption(key, on)
  P.DB()[key] = on and true or false
  if P.active then
    P.Refresh()
  end
  P.RefreshPage()
end

function P.BuildPage(page)
  P.DB()
  view.page = page
  local heading = UI.Heading(page, "Professions", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)

  view.checks = {}
  local anchor
  for _, option in ipairs(OPTIONS) do
    local check = UI.Check(page, option[2])
    check.key = option[1]
    if anchor then
      check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      check:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -14)
    end
    local note = UI.Text(page, "body", 11, "muted")
    note:SetPoint("LEFT", check.label, "RIGHT", 10, 0)
    note:SetPoint("RIGHT", page, "RIGHT", 0, 0) -- bound to the page: a long note wraps
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(option[3])
    check:SetScript("OnClick", function(self)
      P.SetOption(self.key, self:GetChecked())
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  view.cut = UI.Text(page, "body", 12, "text")
  view.cut:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  local less = UI.Button(page, 24, 20, "-")
  less:SetPoint("LEFT", view.cut, "RIGHT", 10, 0)
  local more = UI.Button(page, 24, 20, "+")
  more:SetPoint("LEFT", less, "RIGHT", 4, 0)
  local function SetCut(cut)
    P.DB().ahCut = math.max(0, math.min(15, cut))
    if P.active then
      P.Refresh()
    end
    P.RefreshPage()
  end
  less:SetScript("OnClick", function() SetCut(P.DB().ahCut - 1) end)
  more:SetScript("OnClick", function() SetCut(P.DB().ahCut + 1) end)

  local known = UI.Text(page, "head", 12, "accent")
  known:SetPoint("TOPLEFT", view.cut, "BOTTOMLEFT", 0, -22)
  known:SetText("RECIPES CODEX KNOWS")
  view.chars = UI.Text(page, "body", 12, "text")
  view.chars:SetPoint("TOPLEFT", known, "BOTTOMLEFT", 0, -6)
  view.chars:SetWidth(270)

  local how = UI.Text(page, "head", 12, "accent")
  how:SetPoint("TOPLEFT", known, "TOPLEFT", 300, 0)
  how:SetText("HOW IT WORKS")
  local text = UI.Text(page, "body", 12, "text")
  text:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -6)
  text:SetPoint("RIGHT", 0, 0)
  text:SetWordWrap(true)
  text:SetText(HOW)

  P.RefreshPage()
end
