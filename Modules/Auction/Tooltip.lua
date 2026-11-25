local addonName, ns = ...

-- Auction house module, part 3: the "Auction" line in item tooltips (with its age; the stack total while
-- Shift is held), the game's "Sell Price:" line turned into one item's price (the stack with Shift), and a
-- "Vendor" line when the game doesn't show a sell price itself.

local A = ns.auction

-- How many items the hovered button holds (bag and bank slots set .count; others show a Count text).
local function StackCount(tooltip)
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  if type(owner) ~= "table" then
    return 1
  end
  -- a bag or bank slot: the stack size straight from the game (Codex's bag window shows counts in its own text
  -- and leaves the button's count at 0, so .count alone saw every stack as one item)
  local count
  local getInfo = C_Container and C_Container.GetContainerItemInfo
  if getInfo and type(owner.GetBagID) == "function" and type(owner.GetID) == "function" then
    local okBag, bag = pcall(owner.GetBagID, owner)
    local okSlot, slot = pcall(owner.GetID, owner)
    if okBag and okSlot and type(bag) == "number" and type(slot) == "number" then
      local okInfo, info = pcall(getInfo, bag, slot)
      if okInfo and type(info) == "table" and type(info.stackCount) == "number" then
        count = info.stackCount
      end
    end
  end
  count = count or tonumber(owner.count)
  if (not count or count < 1) and type(owner.Count) == "table" and owner.Count.GetText then
    count = tonumber(owner.Count:GetText())
  end
  if (not count or count < 1) and type(owner.codexCount) == "table" and owner.codexCount.GetText then
    count = tonumber(owner.codexCount:GetText())
  end
  return math.max(1, math.floor(count or 1))
end

-- The game already shows a sell price (modern tooltip data, or its money line).
local function GameShowsSellPrice(tooltip, data)
  local lineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice
  if lineType and data and data.lines then
    for _, line in ipairs(data.lines) do
      if line.type == lineType then
        return true
      end
    end
  end
  return (tonumber(tooltip.shownMoneyFrames) or 0) > 0
end

local function ItemOf(tooltip, data)
  local link
  if tooltip.GetItem then
    link = select(2, tooltip:GetItem())
  end
  if not link and data then
    link = data.hyperlink or data.id
  end
  return link
end

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- Money as the game writes it in tooltips (coin icons), else Codex's own format.
local function GameMoney(copper)
  local util = _G.MoneyFormatterUtil
  if util and util.FormatMoney and _G.GameTooltipMoneyFormat then
    local ok, text = pcall(util.FormatMoney, copper, _G.GameTooltipMoneyFormat)
    if ok and type(text) == "string" then
      return text
    end
  end
  return ns.Money(copper)
end

-- The game's "Sell Price:" line is the whole stack's price (Forever writes it as a plain text line,
-- GameTooltip_OnTooltipAddMoney). For a stack it becomes the price of one, and the stack's total while Shift is
-- held. Only that line's text changes; a min / max price (two lines) is left alone.
local function SellPriceLine(tooltip, item, count, shift)
  local label = type(SELL_PRICE) == "string" and SELL_PRICE or nil
  local name = tooltip.GetName and tooltip:GetName()
  if not label or not name or count <= 1 or not tooltip.NumLines then
    return
  end
  local getInfo = A.ItemApi("GetItemInfo")
  local unit = getInfo and select(11, getInfo(item))
  if type(unit) ~= "number" or unit <= 0 then
    return
  end
  local prefix = label .. ": "
  for index = 1, tooltip:NumLines() do
    local line = _G[name .. "TextLeft" .. index]
    local text = line and line.GetText and line:GetText()
    if Readable(text) and type(text) == "string" and text:sub(1, #prefix) == prefix then
      if shift then
        line:SetText(prefix .. GameMoney(unit * count) .. " |cff999999(x" .. count .. ")|r")
      else
        line:SetText(prefix .. GameMoney(unit))
      end
      return
    end
  end
end

-- Shift changes what the lines show: the hovered item's tooltip is built again (once per frame at most).
local shiftWatch
local function WatchShift()
  if shiftWatch or not CreateFrame then
    return
  end
  shiftWatch = CreateFrame("Frame")
  shiftWatch:RegisterEvent("MODIFIER_STATE_CHANGED")
  shiftWatch:SetScript("OnEvent", function(_, _, key)
    if type(key) ~= "string" or not key:find("SHIFT") then
      return
    end
    local tooltip = GameTooltip
    if not (tooltip and tooltip.IsShown and tooltip:IsShown() and tooltip.GetItem and tooltip:GetItem()) then
      return
    end
    -- straight away: RefreshDataNextUpdate is only honoured when neither the owner nor the tooltip has an
    -- UpdateTooltip of its own (GameTooltip_OnUpdate on Forever), so it never happened over some bag buttons
    if tooltip.RefreshData then
      pcall(tooltip.RefreshData, tooltip)
    elseif tooltip.RefreshDataNextUpdate then
      tooltip:RefreshDataNextUpdate()
    end
  end)
end
A.WatchShift = WatchShift

-- Under the "Auction" line (2026-11-25): the past week's average daily low with today's price against it, and
-- with Shift the lowest price of the last few days (newest first).
local SHIFT_DAYS = 5
function A.AddHistoryLines(tooltip, item, price, shift, r, g, b, theme)
  local average = A.WeekAverage(A.Record(item))
  if average then
    local text, color = A.TrendText(price / average - 1, theme)
    local trend = text ~= "" and (" |cff" .. ns.Hex(color) .. text .. "|r") or ""
    tooltip:AddDoubleLine("Week average", ns.Money(average) .. trend, r, g, b, 1, 1, 1)
  end
  if not shift then
    return
  end
  local history = A.GetHistory(item)
  local shown = 0
  for index = #history, 1, -1 do
    local point = history[index]
    if point.week or shown >= SHIFT_DAYS then
      break
    end
    shown = shown + 1
    tooltip:AddDoubleLine("  " .. date("%a %d %b", point.time), ns.Money(point.price), 0.7, 0.7, 0.7, 1, 1, 1)
  end
end

function A.AddTooltipLines(tooltip, data)
  local db = A.db
  if not db or not (db.tooltip or db.vendor) then
    return
  end
  if tooltip.IsForbidden and tooltip:IsForbidden() then
    return
  end
  local name = tooltip.GetName and tooltip:GetName()
  if name and name:find("^ShoppingTooltip") then
    return -- the comparison tooltips beside the main one
  end
  local item = ItemOf(tooltip, data)
  if not item then
    return
  end
  local theme = ns.InkTheme() -- the game's tooltip: ink
  local r, g, b = theme.accent[1], theme.accent[2], theme.accent[3]
  -- under the tooltip skin's "Codex" heading the labels are muted (board R2-Tooltips); without it, accent
  local sectioned
  local function Heading()
    if sectioned == nil then
      sectioned = ns.API.TooltipSection and ns.API.TooltipSection(tooltip, "Codex") or false
      if sectioned then
        r, g, b = theme.muted[1], theme.muted[2], theme.muted[3]
      end
    end
  end
  local count = StackCount(tooltip)
  local shift = IsShiftKeyDown()
  if db.vendor then
    SellPriceLine(tooltip, item, count, shift)
  end
  if db.tooltip then
    local price, seen = A.GetPrice(item)
    if price then
      Heading()
      tooltip:AddDoubleLine("Auction", ns.Money(price) .. " |cff999999(" .. ns.Age(seen) .. ")|r", r, g, b, 1, 1, 1)
      if count > 1 and shift then
        tooltip:AddDoubleLine("Auction x" .. count, ns.Money(price * count), r, g, b, 1, 1, 1)
      end
      if db.tooltipHistory then
        A.AddHistoryLines(tooltip, item, price, shift, r, g, b, theme)
      end
    end
  end
  if db.vendor and not GameShowsSellPrice(tooltip, data) then
    local getInfo = A.ItemApi("GetItemInfo")
    local sell = getInfo and select(11, getInfo(item))
    if sell and sell > 0 then
      local text = ns.Money(sell)
      if count > 1 then
        text = shift and (ns.Money(sell * count) .. " |cff999999(x" .. count .. ")|r") or text
      end
      Heading()
      tooltip:AddDoubleLine("Vendor", text, r, g, b, 1, 1, 1)
    end
  end
end

local function Safe(tooltip, data)
  local ok, err = pcall(A.AddTooltipLines, tooltip, data)
  if not ok then
    geterrorhandler()(err)
  end
end

-- Called once from Enable.
function A.InstallTooltip()
  WatchShift()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Safe)
    A.tooltipHook = "processor"
  else
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tooltip and tooltip.HookScript then
        tooltip:HookScript("OnTooltipSetItem", function(self)
          Safe(self)
        end)
      end
    end
    A.tooltipHook = "script"
  end
end
