local addonName, ns = ...

-- The Highlights page: a switch per part, the ring size and the range, and a note when NodeSight is loaded.

local H = ns.highlight
local UI = ns.UI
local view = { rows = {} }

local TOGGLES = {
  { key = "nodes", name = "Herbs and ore",
    desc = "A pulsing ring and the name on the herb or ore you are next to: herbs green, ore orange." },
  { key = "ownOnly", name = "Only for my gathering professions", indent = true,
    desc = "Herbs only with Herbalism, ore only with Mining." },
  { key = "chests", name = "Treasure chests", desc = "Chests, footlockers and strongboxes, in gold." },
  { key = "fish", name = "Fishing pools", desc = "Schools of fish, floating wreckage and the like, in blue." },
  { key = "questPlates", name = "Quest objects and quest mobs",
    desc = "A yellow ring and \"!\" on objects you need for a quest, a \"!\" over the nameplate of quest mobs "
      .. "(enemy nameplates must be on; skipped while Questie draws its own nameplate icons)." },
  { key = "questBags", name = "Quest items in bags",
    desc = "Quest items glow in Codex's bag window and the game's bags; a \"!\" marks items that start a quest." },
  { key = "names", name = "Show the object's name", desc = "Under the ring, in the ring's colour." },
}
H.PAGE_TOGGLES = TOGGLES

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetPoint("RIGHT", 0, 0)
  return text
end

local function SizeText()
  local size = H.DB().size
  for _, choice in ipairs(H.SIZES) do
    if choice.value == size then
      return choice.text
    end
  end
  return tostring(size)
end

function H.NoteText()
  local state = ns.ModuleState("highlight")
  if state == "standalone" then
    return "NodeSight is loaded, so Codex leaves this to it. Turn NodeSight off (or use Codex's copy: the button at the top of this section) to use these."
  end
  if state == "off" then
    return "Highlights are off: switch them on at the top of this section (then reload)."
  end
  if ns.IsAddOnLoaded("NodeSight") then
    return "NodeSight is loaded too: both will mark the same objects."
  end
  return ""
end

function H.RefreshPage()
  if not view.page then
    return
  end
  local db = H.DB()
  view.status:SetText(H.StatusText())
  view.note:SetText(H.NoteText())
  for _, row in ipairs(view.rows) do
    row.check:SetChecked(db[row.toggle.key])
  end
  view.size:SetText("Ring size: " .. SizeText())
  view.range:SetText(("Range: %d yards"):format(db.range))
end

function H.BuildPage(page)
  H.DB()
  view.page = page
  local heading = UI.Heading(page, "Highlights", 20)
  heading:SetPoint("TOPLEFT")
  view.status = Wrap(UI.Text(page, "body", 12, "muted"))
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  local about = Wrap(UI.Text(page, "body", 12, "text"))
  about:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -14)
  about:SetText("The game shows a nameplate for the object you would interact with (the nearest one in range, "
    .. "all round you). Codex turns that on while a herb, ore, chest, pool or quest object switch is on, puts its "
    .. "mark on it, and gives your own settings back when they are all off. Changes work at once.")
  view.note = Wrap(UI.Text(page, "body", 11, "warn"))
  view.note:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -6)

  local anchor, x = view.note, 0
  for _, toggle in ipairs(TOGGLES) do
    local row = { toggle = toggle }
    local indent = toggle.indent and 26 or 0
    row.check = UI.Check(page, toggle.name)
    row.check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -x + indent, -10)
    row.check:SetScript("OnClick", function(self)
      H.Set(toggle.key, self:GetChecked() and true or false)
    end)
    row.desc = Wrap(UI.Text(page, "body", 11, "muted"))
    row.desc:SetPoint("TOPLEFT", row.check, "BOTTOMLEFT", 26, -2)
    row.desc:SetText(toggle.desc)
    view.rows[#view.rows + 1] = row
    anchor, x = row.desc, 26 + indent
  end

  view.size = UI.Button(page, 170, 24, "")
  view.size:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -x, -16)
  view.size:SetScript("OnClick", function(self)
    local items = {}
    for _, choice in ipairs(H.SIZES) do
      items[#items + 1] = { text = choice.text, checked = H.DB().size == choice.value, func = function()
        H.Set("size", choice.value)
      end }
    end
    UI.ShowMenu(self, items)
  end)
  view.range = UI.Button(page, 170, 24, "")
  view.range:SetPoint("LEFT", view.size, "RIGHT", 10, 0)
  view.range:SetScript("OnClick", function(self)
    local items = {}
    for _, yards in ipairs(H.RANGES) do
      items[#items + 1] = { text = ("%d yards"):format(yards), checked = H.DB().range == yards, func = function()
        H.Set("range", yards)
      end }
    end
    UI.ShowMenu(self, items)
  end)
  local rangeNote = Wrap(UI.Text(page, "body", 11, "muted"))
  rangeNote:SetPoint("TOPLEFT", view.size, "BOTTOMLEFT", 0, -6)
  rangeNote:SetText("Range: how far away the game picks the object to show (the game may cap it).")
  H.view = view
  H.RefreshPage()
end
