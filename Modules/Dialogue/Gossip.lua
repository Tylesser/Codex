local addonName, ns = ...
local L = ns.L

-- Lists: a gossip window (C_GossipInfo) and a quest giver's greeting (QuestFrame's greeting panel). Board
-- R4-Gossip: the NPC's text, then "Quests" with a line, rows of quests (mark "!" new / "?" yours, gold, blue for
-- repeatables, grey while not done; "[48]" in the difficulty colour when "Show quest levels" is on; a muted tag on
-- the right: Ready, Repeatable, Low level, 3/12), then the NPC's own options with the game's gossip icons. With
-- "Number keys" on, rows 1 to 9 carry a small keycap; the keys pick them (Keys.lua).

local D = ns.dialogue
local UI = ns.UI

local ROW_HEIGHT = { a = 26, b = 30, c = 28 }
local GAME_FONT = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")

local function Color(texture, color, alpha)
  texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function NewRow(content)
  local row = CreateFrame("Button", nil, content.parent)
  row:SetHeight(26)
  row.hover = row:CreateTexture(nil, "HIGHLIGHT")
  row.hover:SetAllPoints()
  row.key = D.Keycap(row)
  -- the quest's mark: the game's own quest icon ("!" new, "?" yours, blue for repeatable), as Blizzard's gossip
  -- window shows it (QuestUtil, forever Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua). It replaced a "?" / "!" in
  -- outlined text, which looked crude on the light paper (the user's screenshot, 2026-11-24).
  row.mark = row:CreateTexture(nil, "ARTWORK")
  row.mark:SetSize(16, 16)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.level = D.Text(row, "body", 14)
  row.level:SetWordWrap(false)
  row.title = D.Text(row, "body", 14)
  -- a long option goes on to a new line, the row grows with it (2026-11-23, the user's screenshot: options cut
  -- with "..."); at most 3 lines
  row.title:SetWordWrap(true)
  if row.title.SetMaxLines then
    row.title:SetMaxLines(3)
  end
  row.tag = D.Text(row, "body", 12)
  row.tag:SetJustifyH("RIGHT")
  row.tag:SetWordWrap(false)
  if row.title.SetJustifyV then
    for _, text in ipairs({ row.level, row.title, row.tag }) do
      text:SetJustifyV("MIDDLE")
    end
  end
  row:SetScript("OnClick", function(self)
    if self.data then
      D.SelectRow(self.data)
    end
  end)
  row:SetScript("OnEnter", function(self)
    local data = self.data
    if data and data.spellID and GameTooltip.SetSpellByID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(GameTooltip.SetSpellByID, GameTooltip, data.spellID)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  -- the row's height: one line, or what the wrapped title needs (its width = the row's less the keycap / mark /
  -- icon / level on the left and the tag on the right). Secret texts (pcall) stay one line.
  function row:Measure(width)
    local base = self.rowHeight or 26
    width = width or self:GetWidth()
    if type(width) ~= "number" or width <= 0 then
      return base
    end
    local tagWidth = 0
    local okTag, w = pcall(self.tag.GetStringWidth, self.tag)
    if okTag and type(w) == "number" and (not issecretvalue or not issecretvalue(w)) and w > 0 then
      tagWidth = math.ceil(w) + 6
    end
    local titleWidth = math.max(40, width - (self.titleX or 0) - tagWidth - 8)
    self.title:SetWidth(titleWidth)
    local ok, height = pcall(D.TextHeight, self.title, titleWidth, self.size or 14, self.raw)
    if ok and type(height) == "number" and (not issecretvalue or not issecretvalue(height)) then
      -- one line keeps the row's own height; each further line adds its height
      local line = math.ceil((self.size or 14) * 1.3)
      if height > line * 1.5 then
        return base + math.ceil(height - line)
      end
    end
    return base
  end
  return row
end

-- One list row (quest or option), number `index` in the order shown.
function D.ListRow(content, data, index)
  local palette, style = content.palette, content.style
  local row = content:Get("row", NewRow, 1)
  row.data = data
  row.rowHeight = ROW_HEIGHT[style] or 26
  Color(row.hover, palette.hover)
  local size = D.FontSize(style == "b" and -0.5 or 0)
  size = math.floor(size + 0.5)
  local x = 6
  local numbers = D.DB().numbers and index <= 9
  row.key:ClearAllPoints()
  if numbers then
    row.key:Set(tostring(index), palette)
    row.key:SetPoint("LEFT", x, 0)
    row.key:Show()
    x = x + 16 + 7
  else
    row.key:Hide()
  end
  row.mark:ClearAllPoints()
  row.icon:ClearAllPoints()
  local levelShown = false
  if data.kind == "quest" then
    row.icon:Hide()
    D.QuestIcon(row.mark, data)
    row.mark:SetPoint("LEFT", x, 0)
    row.mark:Show()
    x = x + 16 + 7
    if D.DB().levels and data.level then
      UI.Font(row.level, "body", size, D.DiffColor(palette, data.difficulty))
      row.level:SetText("[" .. data.level .. "]")
      levelShown = true
    end
  else
    row.mark:Hide()
    if data.icon then
      row.icon:SetTexture(data.icon)
      row.icon:SetPoint("LEFT", x, 0)
      row.icon:Show()
      x = x + 16 + 7
    else
      row.icon:Hide()
    end
  end
  row.level:ClearAllPoints()
  row.level:SetShown(levelShown)
  if levelShown then
    row.level:SetPoint("LEFT", x, 0)
    local w = row.level:GetStringWidth()
    x = x + ((type(w) == "number" and w > 0) and math.ceil(w) or 28) + 6
  end
  local trivial = data.kind == "quest" and data.trivial
  UI.Font(row.title, "body", size, trivial and palette.muted or palette.text)
  D.SetText(row.title, data.title)
  row.titleX, row.size, row.raw = x, size, D.Str(data.title)
  UI.Font(row.tag, "body", D.FontSize(-2), data.tagColor == "good" and palette.good or palette.muted)
  row.tag:SetText(data.tag or "")
  row.tag:ClearAllPoints()
  row.tag:SetPoint("RIGHT", -8, 0)
  row.title:ClearAllPoints()
  row.title:SetPoint("LEFT", x, 0) -- (its width comes from Measure: wrapped lines need one)
  row.title:SetJustifyH("LEFT")
  D.rowsShown[#D.rowsShown + 1] = data
  return row
end

-- The list pages' content. withText = false for style B (the bar holds the text; the side panel only the rows).
function D.FillList(content, page, withText)
  if withText and D.HasText(page.text) then
    D.mainTextBlock = content:Text(page.text, { size = D.FontSize(0.5), gap = 10 })
  end
  local quests, options = {}, {}
  for _, row in ipairs(page.rows or {}) do
    if row.kind == "quest" then
      quests[#quests + 1] = row
    else
      options[#options + 1] = row
    end
  end
  local index = 0
  if #quests > 0 then
    if withText then
      content:Section(L["Quests"])
    end
    for _, row in ipairs(quests) do
      index = index + 1
      D.ListRow(content, row, index)
    end
    if #options > 0 then
      content.blocks[#content.blocks].gap = 8
    end
  end
  for _, row in ipairs(options) do
    index = index + 1
    D.ListRow(content, row, index)
  end
end

-- Picks a row: an option, or a quest from a gossip or greeting list.
function D.SelectRow(data)
  if not data then
    return
  end
  if data.kind == "option" then
    if C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
      pcall(C_GossipInfo.SelectOptionByIndex, data.index)
    end
    return
  end
  D.picked = true
  D.pickedRow = data
  if data.from == "gossip" then
    local select = C_GossipInfo and (data.active and C_GossipInfo.SelectActiveQuest or C_GossipInfo.SelectAvailableQuest)
    if select then
      pcall(select, data.id)
    end
  else
    local select = data.active and _G.SelectActiveQuest or _G.SelectAvailableQuest
    if type(select) == "function" then
      pcall(select, data.index)
    end
  end
end

-- Row number `n` as shown (1-9 keys).
function D.RowAt(n)
  return D.rowsShown and D.rowsShown[n]
end

-- The page's content, by kind.
function D.Fill(content, page, withText)
  D.afterText = {}
  D.mainTextBlock = nil
  if page.kind == "gossip" or page.kind == "greeting" then
    D.FillList(content, page, withText)
  else
    D.FillQuest(content, page, withText)
  end
end

local function Global(name, fallback)
  local value = D.Str(_G[name])
  return value and value ~= "" and value or fallback
end

-- The buttons at the bottom: { primary, secondary } (board: one row, the main one first).
function D.ButtonSpecs(page)
  local space = ns.ModuleOn and ns.ModuleOn("questkeys") or false
  if page.kind == "gossip" or page.kind == "greeting" then
    return { { text = Global("GOODBYE", "Goodbye"), action = D.Close } }
  elseif page.kind == "detail" then
    local specs = { { primary = true, space = space, text = Global("ACCEPT", "Accept"), action = D.Accept, wanted = true } }
    if not page.autoAccept then
      specs[2] = { text = Global("DECLINE", "Decline"), action = D.Decline }
    end
    return specs
  elseif page.kind == "progress" then
    return {
      { primary = true, space = space, text = Global("CONTINUE", "Continue"), action = D.Continue,
        enabled = page.completable, wanted = page.completable },
      { text = Global("CANCEL", "Cancel"), action = D.Close },
    }
  elseif page.kind == "reward" then
    local ready = not D.NeedsChoice(page)
    return {
      { primary = true, space = space, text = Global("COMPLETE_QUEST", "Complete Quest"), action = D.Complete,
        enabled = ready, wanted = ready },
      { text = Global("CANCEL", "Cancel"), action = D.Close },
    }
  end
  return {}
end
