local addonName, ns = ...
local L = ns.L

-- The Vendor page (board R2-CodexModule, page "vendor"): icon + heading + status, the about text, three
-- options (guild funds indented, dimmed while repair is off), the Also sell / Never sell lists side by side
-- (input + Add, rows with icon, name in quality colour and "remove") and the last visit along the bottom.
-- An item gets into a list's box by Shift-clicking it while the box has the cursor, by dragging it onto the box,
-- or by typing its item ID.

local V = ns.vendor
local UI = ns.UI
local T = ns.T
local view = {}

local LIST_GAP = 32 -- board: grid gap between the two lists
local ROW_HEIGHT = 30

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetPoint("RIGHT", 0, 0)
  return text
end

local LIST_INFO = {
  alsoSell = { title = L["ALSO SELL"], desc = L["Sold with the junk, whatever its quality."] },
  neverSell = { title = L["NEVER SELL"], desc = L["Kept even when it is grey."] },
}

-- Shift-click puts the link into the box that has the cursor.
local hooked = false
local function OnInsertLink(link)
  local box = view.focus
  if box and box:HasFocus() and type(link) == "string" and link:find("item:", 1, true) then
    box:SetText(link) -- replaced, not added: the hook may run twice for one click
  end
end
local function HookLinks()
  if hooked then
    return
  end
  hooked = true
  if type(_G.ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
  end
  if type(_G.ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
  end
end

local function ItemLook(id)
  local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
  local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
  local color = ns.QualityColor(quality) -- the theme's (readable on a light theme)
  color = color and { r = color[1], g = color[2], b = color[3] }
  return icon or "Interface\\Icons\\INV_Misc_QuestionMark", color
end

local function BuildList(page, which, left)
  local info = LIST_INFO[which]
  local col = {}
  col.title = UI.Text(page, "head", 13, "accent")
  col.title:SetText(info.title)
  col.title:SetPoint("TOP", view.listTop, "BOTTOM", 0, -18)
  if left then
    col.title:SetPoint("LEFT", page, "LEFT", 0, 0)
  else
    col.title:SetPoint("LEFT", page, "CENTER", LIST_GAP / 2, 0)
  end
  col.desc = UI.Text(page, "body", 13, "muted")
  col.desc:SetText(info.desc)
  col.desc:SetPoint("TOPLEFT", col.title, "BOTTOMLEFT", 0, -2)

  col.add = UI.Button(page, 56, 28, L["Add"])
  UI.Font(col.add.label, "body", 14)
  col.add:SetPoint("TOP", col.desc, "BOTTOM", 0, -8)
  if left then
    col.add:SetPoint("RIGHT", page, "CENTER", -LIST_GAP / 2, 0)
  else
    col.add:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  end
  col.box = UI.EditBox(page, 160, 28)
  UI.Font(col.box, "body", 14, "bright")
  col.box:SetPoint("TOPLEFT", col.desc, "BOTTOMLEFT", 0, -8)
  col.box:SetPoint("RIGHT", col.add, "LEFT", -6, 0)
  col.hint = UI.Text(col.box, "body", 13, "muted")
  col.hint:SetPoint("LEFT", 10, 0)
  col.hint:SetText(L["Shift-click an item or type its ID"])
  local function Hint()
    col.hint:SetShown(col.box:GetText() == "" and not col.box:HasFocus())
  end

  local function Add()
    local text = col.box:GetText()
    if V.AddToList(which, text) then
      col.box:SetText("")
    elseif text ~= "" then
      ns.Say(L["Shift-click an item, drag it here or type its item ID."])
    end
    col.box:ClearFocus()
    Hint()
  end
  col.add:SetScript("OnClick", Add)
  col.box:SetScript("OnEnterPressed", Add)
  col.box:SetScript("OnEditFocusGained", function(self)
    view.focus = self
    Hint()
  end)
  col.box:SetScript("OnEditFocusLost", Hint)
  col.box:SetScript("OnTextChanged", Hint)
  col.box:SetScript("OnReceiveDrag", function()
    local kind, itemID, link = GetCursorInfo()
    if kind == "item" and itemID then
      V.AddToList(which, link or itemID)
      ClearCursor()
    end
  end)
  col.box:SetScript("OnMouseDown", function(self)
    if GetCursorInfo() == "item" then
      self:GetScript("OnReceiveDrag")(self)
    end
  end)
  col.box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(info.desc)
    GameTooltip:AddLine(L["Click here, then Shift-click an item; or drag an item here; or type its item ID."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  col.box:SetScript("OnLeave", GameTooltip_Hide)

  col.list = UI.List(page, {
    rowHeight = ROW_HEIGHT,
    CreateRow = function(row)
      -- board: 20px icon, dark inner line, 1px ring in the item's quality colour
      row.iconFrame = CreateFrame("Frame", nil, row)
      row.iconFrame:SetSize(22, 22)
      row.iconFrame:SetPoint("LEFT", 7, 0)
      row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
      row.icon:SetPoint("TOPLEFT", 2, -2)
      row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
      row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.ring = T.Outline(row.iconFrame, 0, { 0.6, 0.6, 0.6 }, 1, "OVERLAY")
      T.Outline(row.iconFrame, 1, { 0, 0, 0 }, 1, "OVERLAY")
      row.remove = CreateFrame("Button", nil, row)
      row.remove:SetSize(60, 24)
      row.remove:SetPoint("RIGHT", -6, 0)
      row.remove.label = UI.Text(row.remove, "body", 13, "muted")
      row.remove.label:SetPoint("CENTER")
      row.remove.label:SetText(L["remove"])
      local hover = row.remove:CreateTexture(nil, "HIGHLIGHT")
      hover:SetAllPoints()
      UI.SetColor(hover, ns.Theme().accent, 0.12)
      row.remove:SetScript("OnClick", function()
        if row.item then
          V.RemoveFromList(which, row.item.id)
        end
      end)
      row.text = UI.Text(row, "body", 14, "text")
      row.text:SetPoint("LEFT", row.iconFrame, "RIGHT", 8, 0)
      row.text:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)
      row.text:SetWordWrap(false)
      row:SetScript("OnEnter", function(self)
        if self.item and GameTooltip.SetItemByID then
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetItemByID(self.item.id)
          GameTooltip:Show()
        end
      end)
      row:SetScript("OnLeave", GameTooltip_Hide)
    end,
    UpdateRow = function(row, item)
      local icon, color = ItemLook(item.id)
      row.icon:SetTexture(icon)
      row.text:SetText(item.name)
      local rgb = color and { color.r, color.g, color.b } or ns.Theme().text
      row.text:SetTextColor(UI.Unpack(rgb))
      T.ColorLines(row.ring, rgb)
    end,
  })
  col.list:SetPoint("TOPLEFT", col.box, "BOTTOMLEFT", 0, -8)
  col.list:SetPoint("RIGHT", col.add, "RIGHT", 0, 0)
  col.list:SetPoint("BOTTOM", view.rule, "TOP", 0, 14)
  col.Hint = Hint
  return col
end

-- accent: a colour hex for "Last visit" (the page), nil for plain text.
function V.LastText(accent)
  local last = V.DB().last
  if not last then
    return L["No merchant visit yet."]
  end
  local where = last.merchant and L["at %s, %s ago"]:format(last.merchant, ns.Age(last.time)) or L["%s ago"]:format(ns.Age(last.time))
  local parts = {}
  if (last.sold or 0) > 0 then
    parts[#parts + 1] = last.sold == 1 and L["sold 1 junk item for %s"]:format(ns.Money(last.soldValue))
      or L["sold %d junk items for %s"]:format(last.sold, ns.Money(last.soldValue))
  end
  if (last.left or 0) > 0 then
    parts[#parts + 1] = L["%d left unsold"]:format(last.left)
  end
  if (last.repair or 0) > 0 then
    local text = last.guild == "all" and L["repaired for %s (guild)"] or last.guild == "part"
      and L["repaired for %s (partly guild)"] or L["repaired for %s"]
    parts[#parts + 1] = text:format(ns.Money(last.repair))
  end
  if last.noGold then
    parts[#parts + 1] = L["not enough gold to repair (%s)"]:format(ns.Money(last.noGold))
  end
  if #parts == 0 then
    parts[1] = L["nothing to sell or repair"]
  end
  local label = accent and ("|cff" .. accent .. L["Last visit"] .. "|r") or L["Last visit"]
  return label .. " (" .. where .. "): " .. table.concat(parts, "; ") .. "."
end

local function Hex(color)
  return ("%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
    math.floor(color[3] * 255 + 0.5))
end

function V.RefreshPage()
  if not view.page then
    return
  end
  local db = V.DB()
  view.status:SetText(V.StatusText())
  view.sell:SetChecked(db.sellJunk)
  view.repair:SetChecked(db.repair)
  view.guild:SetChecked(db.guildFunds)
  view.guild:SetEnabled(db.repair or false)
  view.guild:SetAlpha(db.repair and 1 or 0.45) -- board: guildOpacity
  local notes = {}
  if V.LeatrixDoes("sell") then
    notes[#notes + 1] = L["Leatrix Plus has \"Sell junk automatically\" on, so Codex leaves selling to it."]
  end
  if V.LeatrixDoes("repair") then
    notes[#notes + 1] = L["Leatrix Plus has \"Repair automatically\" on, so Codex leaves repairing to it."]
  end
  if #notes > 0 then
    notes[#notes + 1] = L["Turn it off there to use Codex's (the buttons under the merchant window always work)."]
  end
  view.leatrix:SetText(table.concat(notes, " "))
  view.also.list:SetItems(V.ListItems("alsoSell"))
  view.never.list:SetItems(V.ListItems("neverSell"))
  view.also.Hint()
  view.never.Hint()
  local text = V.LastText(Hex(ns.Theme().accent))
  view.last:SetText(text)
end

function V.BuildPage(page)
  V.DB()
  HookLinks()
  view.page = page

  -- header: icon tile, heading 24, status
  local tile = CreateFrame("Frame", nil, page)
  tile:SetSize(38, 38)
  tile:SetPoint("TOPLEFT")
  local icon = tile:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(ns.modules.vendor.icon)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  T.Outline(tile, 0, { 0, 0, 0, 0.55 }, 1, "OVERLAY")
  local heading = UI.Heading(page, L["Vendor"], 24)
  heading:SetPoint("TOPLEFT", tile, "TOPRIGHT", 12, 1)
  view.status = Wrap(UI.Text(page, "body", 14, "muted"))
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3)

  local about = Wrap(UI.Text(page, "body", 14, "text"))
  about:SetPoint("TOPLEFT", tile, "BOTTOMLEFT", 0, -14)
  if about.SetSpacing then
    about:SetSpacing(4) -- board: line-height 1.45
  end
  about:SetText(L["When you talk to a merchant, Codex sells your grey items (a few at a time, so the server keeps up) and repairs your gear, with one line in chat for each. Hold Shift while opening the merchant to skip both. The merchant window gets Sell junk and Repair buttons for doing it by hand."])

  view.sell = UI.Check(page, L["Sell junk automatically"])
  view.sell:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -14)
  view.sell:SetScript("OnClick", function(self)
    V.DB().sellJunk = self:GetChecked() and true or false
    V.RefreshPage()
  end)
  view.repair = UI.Check(page, L["Repair automatically"])
  view.repair:SetPoint("TOPLEFT", view.sell, "BOTTOMLEFT", 0, -8)
  view.repair:SetScript("OnClick", function(self)
    V.DB().repair = self:GetChecked() and true or false
    V.RefreshPage()
  end)
  view.guild = UI.Check(page, L["Use guild funds first (when your rank may)"])
  view.guild:SetPoint("TOPLEFT", view.repair, "BOTTOMLEFT", 28, -8)
  view.guild:SetScript("OnClick", function(self)
    V.DB().guildFunds = self:GetChecked() and true or false
    V.RefreshPage()
  end)
  for _, check in ipairs({ view.sell, view.repair, view.guild }) do
    UI.Font(check.label, "body", 14)
  end

  view.leatrix = Wrap(UI.Text(page, "body", 12, "warn"))
  view.leatrix:SetPoint("TOPLEFT", view.guild, "BOTTOMLEFT", -28, -8)
  view.listTop = view.leatrix

  -- last visit along the bottom, under a divider
  view.last = Wrap(UI.Text(page, "body", 14, "text"))
  view.last:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
  view.rule = UI.Divider(page)
  view.rule:SetPoint("BOTTOMLEFT", view.last, "TOPLEFT", 0, 10)
  view.rule:SetPoint("RIGHT", page, "RIGHT", 0, 0)

  view.also = BuildList(page, "alsoSell", true)
  view.never = BuildList(page, "neverSell", false)

  V.RefreshPage()
end
