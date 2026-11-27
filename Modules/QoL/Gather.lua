local addonName, ns = ...
local L = ns.L

-- Gathering skill in tooltips: herbs and ore show the skill they need, coloured like Classic's difficulty from
-- your own rank (red = you can't gather it yet, orange, yellow, green, grey = no more skill-ups). Without the
-- profession the line is muted: "Requires Mining 175".
-- - The node itself (world tooltip, Enum.TooltipDataType.Object): one plain line, "Mining 175", below its lines
--   (no "Codex" section heading: it would be heavier than the tooltip it sits in).
-- - The minimap blip (Minimap_OnUpdate re-sets GameTooltip:SetMinimapMouseover() every frame; the game puts one
--   or more node names in a line, several separated by line breaks, with icons/colours around them): the level
--   goes right after each node name, "Mithril Deposit (175)", in the same colours. The game's text is kept as it
--   is; a name that already has our "(175)" no longer matches the table, so a re-set never adds it twice.
-- Names come from the shared table ns.GATHER_SKILL (Gathering.lua, English names only). The player's ranks are read
-- once (GetProfessions / GetProfessionInfo, else the skill lines) and kept until SKILL_LINES_CHANGED / CHAT_MSG_SKILL
-- (G.Rank, shared with the zone levels on the world map, Zones.lua).
-- Secret texts (Forever) are skipped. While the toggle is off nothing is hooked; switched on later, it hooks then.

local Q = ns.qol
local G = {}
Q.gather = G

local KEY = "gatherTooltips"

G.COLORS = {
  red = { 1, 0.1, 0.1 }, -- below the requirement: can't gather it
  orange = { 1, 0.5, 0.25 },
  yellow = { 1, 1, 0 },
  green = { 0.25, 0.75, 0.25 },
  grey = { 0.5, 0.5, 0.5 },
  muted = { 0.62, 0.62, 0.62 }, -- you don't have the profession
}

local function Readable(value)
  if value == nil then
    return false
  end
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end
G.Readable = Readable

local function Pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return Pass(pcall(fn, ...))
end

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

-- Lookup ---------------------------------------------------------------------------------------------------------

-- The bare name in a tooltip text: icons, colour codes and outer spaces removed.
function G.Plain(text)
  if type(text) ~= "string" then
    return nil
  end
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- { skill, level } of a node name, or nil.
function G.Lookup(name)
  local text = Str(name)
  if not text then
    return nil
  end
  return ns.GATHER_SKILL[text] or ns.GATHER_SKILL[G.Plain(text)]
end

-- The player's ranks -----------------------------------------------------------------------------------------------

local skillNames = {}
-- The profession's name in the game's language (English when the game doesn't say).
function G.SkillName(skill)
  if not skillNames[skill] then
    local id = ns.GATHER_SKILL_LINES[skill]
    local name = C_TradeSkillUI and Str(Ask(C_TradeSkillUI.GetTradeSkillDisplayName, id))
    if not name and C_SkillInfo then
      local info = Ask(C_SkillInfo.GetSkillLineInfoByID, id)
      name = Str(type(info) == "table" and info.name or info)
    end
    skillNames[skill] = name or ns.GATHER_SKILL_NAMES[skill] or skill
  end
  return skillNames[skill]
end

local function SkillByName(name)
  name = Str(name)
  if not name then
    return nil
  end
  name = name:lower()
  for skill, english in pairs(ns.GATHER_SKILL_NAMES) do
    if name == english:lower() or name == G.SkillName(skill):lower() then
      return skill
    end
  end
  return nil
end

local function ReadRanks()
  local ranks = {}
  if GetProfessions and GetProfessionInfo then
    local list = { Ask(GetProfessions) }
    for slot = 1, 5 do
      local index = Num(list[slot])
      if index then
        local name, _, rank, _, _, _, line = Ask(GetProfessionInfo, index)
        local skill
        line = Num(line)
        for key, id in pairs(ns.GATHER_SKILL_LINES) do
          if line == id then
            skill = key
          end
        end
        skill = skill or SkillByName(name)
        if skill and Num(rank) then
          ranks[skill] = rank
        end
      end
    end
  end
  local missing = false
  for skill in pairs(ns.GATHER_SKILL_LINES) do
    missing = missing or ranks[skill] == nil
  end
  if missing and GetNumSkillLines and GetSkillLineInfo then
    for index = 1, Num(Ask(GetNumSkillLines)) or 0 do
      local name, isHeader, _, rank = Ask(GetSkillLineInfo, index)
      local skill = not isHeader and SkillByName(name)
      if skill and ranks[skill] == nil and Num(rank) then
        ranks[skill] = rank
      end
    end
  end
  return ranks
end

local ranks
function G.Reset()
  ranks = nil
end

-- The player's rank in "mining" / "herbalism" / "fishing", or nil without the profession. Shared (the zone levels
-- read it too); the events that drop the cache are registered at the first read.
function G.Rank(skill)
  if not G.frame then
    G.frame = CreateFrame("Frame")
    G.frame:SetScript("OnEvent", G.Reset)
    G.frame:RegisterEvent("SKILL_LINES_CHANGED")
    G.frame:RegisterEvent("CHAT_MSG_SKILL")
  end
  if not ranks then
    ranks = ReadRanks()
  end
  return ranks[skill]
end

-- Colours and texts --------------------------------------------------------------------------------------------------

-- "red" / "orange" / "yellow" / "green" / "grey" from the player's rank, "muted" without the profession.
function G.Difficulty(rank, level)
  if not rank then
    return "muted"
  end
  if rank < level then
    return "red"
  elseif rank <= level + 25 then
    return "orange"
  elseif rank <= level + 50 then
    return "yellow"
  elseif rank <= level + 100 then
    return "green"
  end
  return "grey"
end

function G.Color(node)
  local color = G.COLORS[G.Difficulty(G.Rank(node.skill), node.level)]
  return color[1], color[2], color[3]
end

-- The world tooltip's line: "Mining 175", or "Requires Mining 175" without the profession.
function G.LineText(node)
  local text = G.SkillName(node.skill) .. " " .. node.level
  if G.Rank(node.skill) then
    return text
  end
  local requires = Str(ITEM_REQ_SKILL)
  if not (requires and requires:find("%s", 1, true)) then
    requires = "Requires %s"
  end
  return requires:format(text)
end

-- The minimap's tag after a node name: " (175)" in the difficulty colour.
function G.Tag(node)
  local r, g, b = G.Color(node)
  return (" |cff%02x%02x%02x(%d)|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5), node.level)
end

-- A minimap text with the level after every node name it lists (line breaks "\n" or "|n"), or nil when nothing
-- in it is a node (or every node already has its level).
function G.TagText(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local parts, changed, pos = {}, false, 1
  while true do
    local s1, e1 = text:find("\n", pos, true)
    local s2, e2 = text:find("|n", pos, true)
    if s2 and (not s1 or s2 < s1) then
      s1, e1 = s2, e2
    end
    local segment = text:sub(pos, s1 and s1 - 1 or #text)
    local node = ns.GATHER_SKILL[G.Plain(segment)]
    if node then
      segment = segment .. G.Tag(node)
      changed = true
    end
    parts[#parts + 1] = segment
    if not s1 then
      break
    end
    parts[#parts + 1] = text:sub(s1, e1)
    pos = e1 + 1
  end
  return changed and table.concat(parts) or nil
end

-- Tooltips -----------------------------------------------------------------------------------------------------------

local added = setmetatable({}, { __mode = "k" }) -- [tooltip] = node name we added a line for, until it is cleared
local cleared = setmetatable({}, { __mode = "k" })

local function Usable(tooltip)
  if type(tooltip) ~= "table" then
    return false
  end
  if tooltip.IsForbidden and tooltip:IsForbidden() then
    return false
  end
  local name = tooltip.GetName and tooltip:GetName()
  if name ~= nil and (not Readable(name) or name:find("^ShoppingTooltip")) then
    return false
  end
  return true
end

local function Line(tooltip, i)
  local name = Str(tooltip.GetName and tooltip:GetName())
  return name and _G[name .. "TextLeft" .. i] or nil
end

local function FirstLine(tooltip, data)
  local lines = type(data) == "table" and Readable(data.lines) and data.lines
  local first = type(lines) == "table" and lines[1]
  local text = type(first) == "table" and Str(first.leftText)
  if text then
    return text
  end
  local fs = Line(tooltip, 1)
  return fs and fs.GetText and Str(fs:GetText()) or nil
end

-- The node's own tooltip: one line below it. Returns true when a line was added.
function G.OnObject(tooltip, data)
  if not Q.On(KEY) or not Usable(tooltip) then
    return false
  end
  local name = FirstLine(tooltip, data)
  local node = G.Lookup(name)
  if not node then
    return false
  end
  name = G.Plain(name)
  if added[tooltip] == name then
    return false -- the game set it again without clearing: our line is still there
  end
  if not cleared[tooltip] and tooltip.HookScript then
    cleared[tooltip] = true
    tooltip:HookScript("OnTooltipCleared", function(self)
      added[self] = nil
    end)
  end
  added[tooltip] = name
  local r, g, b = G.Color(node)
  tooltip:AddLine(G.LineText(node), r, g, b)
  return true
end

-- The minimap blip's tooltip: the level after each node name, in the game's own lines. True when changed.
function G.OnMinimap(tooltip)
  if not Q.On(KEY) or not Usable(tooltip) then
    return false
  end
  local changed = false
  for i = 1, Num(tooltip.NumLines and tooltip:NumLines()) or 0 do
    local fs = Line(tooltip, i)
    local text = fs and fs.GetText and Str(fs:GetText())
    local tagged = text and G.TagText(text)
    if tagged then
      fs:SetText(tagged)
      changed = true
    end
  end
  return changed
end

local function Safe(fn)
  return function(tooltip, data)
    local ok, err = pcall(fn, tooltip, data)
    if not ok then
      geterrorhandler()(err)
    end
  end
end

-- After the game's own (re)set outside the data processor: the tooltip is resized with Show.
local function AndShow(fn)
  return Safe(function(tooltip, data)
    if fn(tooltip, data) and tooltip.Show then
      tooltip:Show()
    end
  end)
end

G.hooked = false
function G.Hook()
  if G.hooked then
    return
  end
  G.hooked = true
  local types = Enum and Enum.TooltipDataType
  local processor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and types
  -- post calls run before the processor's own Show, so no resize is needed there
  if processor and types.Object ~= nil then
    TooltipDataProcessor.AddTooltipPostCall(types.Object, Safe(G.OnObject))
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnShow", AndShow(G.OnObject))
  end
  if processor and types.MinimapMouseover ~= nil then
    TooltipDataProcessor.AddTooltipPostCall(types.MinimapMouseover, Safe(G.OnMinimap))
  end
  -- also straight after the minimap's own call, in case its data comes without the MinimapMouseover type
  if GameTooltip and type(GameTooltip.SetMinimapMouseover) == "function" then
    hooksecurefunc(GameTooltip, "SetMinimapMouseover", AndShow(G.OnMinimap))
  end
end

function G.Enable()
  if Q.DB()[KEY] then
    G.Hook()
  end
end

function G.Changed(on)
  if on then
    G.Hook()
  end
end

Q.AddToggle({
  key = KEY,
  name = L["Gathering skill in tooltips"],
  desc = L["Herbs and ore show the Herbalism or Mining skill they need, on the node and on the minimap (\"Mithril Deposit (175)\"), coloured from your own skill: red = too low, then orange, yellow, green, grey."],
  order = 30,
  Enable = G.Enable,
  Changed = G.Changed,
})
