local addonName, ns = ...

-- Loot text, part 2: the lines on screen. One holder `CodexLootText` (moved in Edit Mode like the personal bars;
-- each look keeps its own place), lines from a pool: icon, text in the theme's body font with an outline (they sit
-- over the world), and a glow behind lines worth more than the player's price, epic and better, or watched.
--   float: a new line starts at the holder and rises (RISE px over the duration), fading out over its last second;
--          lines never overlap: each sits at least one line above the newer one under it.
--   down:  the same falling (the user's request, 2026-11-21): a new line starts at the holder's top and sinks,
--          each at least one line under the newer one above it.
--   list:  lines stack upward from the holder, newest at the bottom, at most `maxLines`; each fades after the
--          duration.
-- The same thing again while its line shows adds to that line (a float line only in its first second, so it
-- doesn't jump back down): "Linen Cloth x3", money, XP, reputation, junk.
-- Watched items also get a banner in the middle of the screen and the watch sound.

local LT = ns.loottext
local UI = ns.UI
local T = ns.T

local RISE, FADE_IN, FADE_OUT, MERGE_FLOAT = 150, 0.15, 1, 1
local WIDTH = 420
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"

LT.ICONS = {
  money = "Interface\\Icons\\INV_Misc_Coin_01",
  junk = "Interface\\Icons\\INV_Misc_Bag_10",
  xp = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  reputation = "Interface\\Icons\\INV_Scroll_03",
  skill = "Interface\\Icons\\INV_Misc_Book_11",
  honor = "Interface\\Icons\\INV_BannerPVP_02",
  currency = "Interface\\Icons\\INV_Misc_Coin_17",
  legacy = "Interface\\Icons\\INV_Misc_Book_09",
}

-- The game's own sounds (SOUNDKIT names and IDs from Blizzard_SharedXML/Mainline/SoundKitConstants.lua).
LT.SOUNDS = {
  { "coin", "Loot coin", "LOOT_WINDOW_COIN_SOUND", 120 },
  { "toast", "Friend toast", "UI_BNET_TOAST", 18019 },
  { "questdone", "Quest complete", "IG_QUEST_LIST_COMPLETE", 878 },
  { "ping", "Map ping", "MAP_PING", 3175 },
  { "raidwarning", "Raid warning", "RAID_WARNING", 8959 },
  { "readycheck", "Ready check", "READY_CHECK", 8960 },
  { "epicloot", "Epic loot", "UI_EPICLOOT_TOAST", 31578 },
  { "none", "None" },
}

function LT.PlaySound(key)
  for _, sound in ipairs(LT.SOUNDS) do
    if sound[1] == key and sound[3] then
      local kit = (SOUNDKIT and SOUNDKIT[sound[3]]) or sound[4]
      if kit and type(PlaySound) == "function" then
        pcall(PlaySound, kit, "SFX")
      end
      return
    end
  end
end

local holder, mover, banner
local active = {} -- shown lines, newest first
local pool = {}
LT.active = active -- (for the test)

local function Theme()
  return ns.InkTheme and ns.InkTheme() or ns.Theme()
end

local function Hex(token, fallback)
  local color = Theme()[token]
  return type(color) == "table" and ns.Hex(color) or fallback
end

-- 1g 20s 5c with the game's coin icons.
function LT.Coins(copper)
  copper = math.floor((copper or 0) + 0.5)
  local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or gold) .. COIN:format("Gold")
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. COIN:format("Silver")
  end
  if rest > 0 or #parts == 0 then
    parts[#parts + 1] = rest .. COIN:format("Copper")
  end
  return table.concat(parts, " ")
end

local function QualityHex(quality)
  local color = ns.QualityColor and ns.QualityColor(quality)
  if type(color) == "table" then
    return ns.Hex(color)
  end
  local game = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
  return game and game.hex and game.hex:sub(5) or "ffffff"
end

local function Number(value)
  return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

-- The text and icon of a line's data.
function LT.LineText(data)
  local db = LT.DB()
  local muted = Hex("muted", "a0a0a0")
  local kind = data.kind
  if kind == "item" then
    local text = ("|cff%s%s|r"):format(QualityHex(data.info.quality), data.info.name)
    if data.amount > 1 then
      text = text .. ("|cff%s x%d|r"):format(Hex("bright", "ffffff"), data.amount)
    end
    local own, others = LT.Totals(data.info.id)
    if own and own > 0 then
      text = text .. ("|cff%s (%s%s)|r"):format(muted, Number(own),
        others > 0 and (" · " .. Number(own + others) .. " all") or "")
    end
    if data.value and data.value > 0 then
      text = text .. ("|cff%s · |r"):format(muted) .. LT.Coins(data.value)
    end
    return text, data.info.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
  elseif kind == "junk" then
    local text = ("|cff%sJunk x%d|r"):format(QualityHex(0), data.amount)
    if data.value and data.value > 0 then
      text = text .. ("|cff%s · |r"):format(muted) .. LT.Coins(data.value)
    end
    return text, LT.ICONS.junk
  elseif kind == "money" then
    return "+" .. LT.Coins(data.amount), LT.ICONS.money
  elseif kind == "reputation" then
    local good = data.amount > 0
    return ("|cff%s%s%s %s|r"):format(Hex(good and "good" or "bad", good and "40c040" or "e04040"),
      good and "+" or "-", Number(math.abs(data.amount)), data.name), LT.ICONS.reputation
  elseif kind == "xp" then
    local text = ("|cff%s+%s XP|r"):format(Hex("accent", "b080ff"), Number(data.amount))
    if data.left and db.xp then
      text = text .. ("|cff%s (%s more to level)|r"):format(muted, Number(data.left))
    end
    return text, LT.ICONS.xp
  elseif kind == "honor" then
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return ("|cff%s+%s Honor|r"):format(Hex("warn", "ffb040"), Number(data.amount)),
      faction == "Horde" and "Interface\\Icons\\INV_BannerPVP_01" or LT.ICONS.honor
  elseif kind == "currency" then
    return ("|cff%s+%s %s|r"):format(Hex("bright", "ffffff"), Number(data.amount), data.name),
      data.icon or LT.ICONS.currency
  elseif kind == "skill" then
    return ("|cff%s%s %d|r"):format(Hex("accent", "80c0ff"), data.name, data.rank or 0), LT.ICONS.skill
  elseif kind == "legacy" then
    local text = ("|cff%s+%s Legacy %s|r"):format(Hex("good", "40c040"), Number(data.amount),
      data.amount == 1 and "point" or "points")
    if data.total then
      text = text .. ("|cff%s (%s in all)|r"):format(muted, Number(data.total))
    end
    return text, LT.ICONS.legacy
  end
  return tostring(data.name or ""), nil
end

-- Lines -------------------------------------------------------------------------------------------------------

local function LineHeight()
  return LT.DB().size + 8
end

local function StyleLine(line)
  local size = LT.DB().size
  UI.Font(line.text, "body", size, "bright")
  local font, fontSize = line.text:GetFont()
  if font then
    line.text:SetFont(font, fontSize or size, "OUTLINE")
  end
  line.text:SetShadowOffset(1, -1)
  line.text:SetShadowColor(0, 0, 0, 0.8)
  line.icon:SetSize(size + 4, size + 4)
  line:SetHeight(LineHeight())
end

local function NewLine()
  local line = table.remove(pool)
  if line then
    return line
  end
  line = CreateFrame("Frame", nil, holder)
  line:SetSize(WIDTH, 20)
  line.glow = line:CreateTexture(nil, "BACKGROUND")
  line.glow:SetTexture("Interface\\AddOns\\Codex\\Modules\\QoL\\Media\\GlowSquare")
  line.glow:SetBlendMode("ADD")
  line.icon = line:CreateTexture(nil, "ARTWORK")
  line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  line.text = line:CreateFontString(nil, "OVERLAY")
  line.text:SetWordWrap(false)
  StyleLine(line)
  return line
end

-- Icon and text centred (float) or from the left edge (list); the glow round both.
local function LayOut(line)
  local float = LT.DB().style ~= "list"
  local size = LT.DB().size
  line.icon:ClearAllPoints()
  line.text:ClearAllPoints()
  local width = math.min((line.text:GetStringWidth() or 0) + 1, WIDTH - size - 10)
  line.text:SetWidth(width)
  if float then
    local total = size + 4 + 6 + width
    line.icon:SetPoint("LEFT", line, "CENTER", -total / 2, 0)
  else
    line.icon:SetPoint("LEFT", line, "LEFT", 0, 0)
  end
  line.text:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
  line.glow:ClearAllPoints()
  line.glow:SetPoint("TOPLEFT", line.icon, "TOPLEFT", -14, 10)
  line.glow:SetPoint("BOTTOMRIGHT", line.text, "BOTTOMRIGHT", 14, -10)
end

local function Fill(line)
  local text, icon = LT.LineText(line.data)
  line.text:SetText(text)
  line.icon:SetTexture(icon)
  line.icon:SetShown(icon ~= nil)
  local accent = line.data.watched and Theme().accent or { 1, 0.82, 0.3 }
  line.glow:SetVertexColor(accent[1], accent[2], accent[3])
  line.glow:SetShown(line.data.glow == true)
  LayOut(line)
end

local function Release(index)
  local line = table.remove(active, index)
  line:Hide()
  line.data = nil
  pool[#pool + 1] = line
end

local function Place()
  local db = LT.DB()
  local height, duration = LineHeight(), db.duration
  if db.style == "list" then
    for index = #active, db.maxLines + 1, -1 do
      Release(index)
    end
    for index, line in ipairs(active) do
      line:ClearAllPoints()
      line:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, (index - 1) * height)
    end
  elseif db.style == "down" then
    local above
    for _, line in ipairs(active) do
      local y = -line.age / duration * RISE
      if above then
        y = math.min(y, above - height)
      end
      above = y
      line:ClearAllPoints()
      line:SetPoint("TOP", holder, "TOP", 0, y)
    end
  else
    local below
    for _, line in ipairs(active) do
      local y = line.age / duration * RISE
      if below then
        y = math.max(y, below + height)
      end
      below = y
      line:ClearAllPoints()
      line:SetPoint("BOTTOM", holder, "BOTTOM", 0, y)
    end
  end
end

local function Tick(_, elapsed)
  local db = LT.DB()
  local duration = db.duration
  for index = #active, 1, -1 do
    local line = active[index]
    line.age = line.age + elapsed
    if line.age >= duration then
      Release(index)
    else
      local alpha = 1
      if line.age < FADE_IN then
        alpha = line.age / FADE_IN
      elseif line.age > duration - FADE_OUT then
        alpha = (duration - line.age) / FADE_OUT
      end
      line:SetAlpha(math.max(0, math.min(1, alpha)))
      if line.data.glow then
        line.glow:SetAlpha(0.45 + 0.35 * math.sin(line.age * 5))
      end
    end
  end
  Place()
  if #active == 0 and not LT.editing then
    holder:SetScript("OnUpdate", nil)
  end
end

local function Merge(old, new)
  if new.replace then
    old.rank = new.rank
    return
  end
  old.amount = (old.amount or 0) + (new.amount or 0)
  if new.value then
    old.value = (old.value or 0) + new.value
  end
  if new.left then
    old.left = new.left
  end
  if new.total then
    old.total = new.total -- Legacy points: the newest total
  end
  old.glow = old.glow or new.glow
  old.watched = old.watched or new.watched
end

-- A line for `data` (Core.lua's events), or more on the line that already shows it.
function LT.Show(data)
  if not holder then
    return
  end
  local db = LT.DB()
  local float = db.style ~= "list"
  for _, line in ipairs(active) do
    if line.data.key == data.key and (not float or line.age < MERGE_FLOAT) then
      Merge(line.data, data)
      if not float then
        line.age = math.min(line.age, FADE_IN)
      end
      Fill(line)
      LT.Alert(data)
      return line
    end
  end
  local line = NewLine()
  line.data, line.age = data, 0
  line:SetAlpha(0)
  Fill(line)
  line:Show()
  table.insert(active, 1, line)
  Place()
  holder:SetScript("OnUpdate", Tick)
  -- totals change a moment later (the bag update comes after the loot line)
  if data.kind == "item" and C_Timer then
    C_Timer.After(0.6, function()
      if line.data == data then
        Fill(line)
      end
    end)
  end
  LT.Alert(data)
  return line
end

-- Sounds and the watch banner.
function LT.Alert(data)
  local db = LT.DB()
  if data.sample then
    return -- the samples (Edit Mode, the page's button) stay quiet
  end
  if data.watched then
    LT.ShowBanner(data)
    LT.PlaySound(db.watchSound)
  elseif data.glow then
    LT.PlaySound(db.glowSound)
  end
end

function LT.ShowBanner(data)
  if not banner then
    banner = CreateFrame("Frame", "CodexLootTextBanner", UIParent)
    banner:SetSize(600, 60)
    banner:SetPoint("TOP", UIParent, "TOP", 0, -180)
    banner:SetFrameStrata("HIGH")
    banner:EnableMouse(false)
    banner.title = banner:CreateFontString(nil, "OVERLAY")
    banner.title:SetPoint("TOP")
    banner.icon = banner:CreateTexture(nil, "ARTWORK")
    banner.icon:SetSize(32, 32)
    banner.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    banner.text = banner:CreateFontString(nil, "OVERLAY")
    banner.text:SetPoint("TOP", banner.title, "BOTTOM", 18, -6)
    banner.icon:SetPoint("RIGHT", banner.text, "LEFT", -8, 0)
  end
  UI.Font(banner.title, "head", 14, "accent")
  UI.Font(banner.text, "body", 20, "bright")
  for _, fs in ipairs({ banner.title, banner.text }) do
    local font, size = fs:GetFont()
    if font then
      fs:SetFont(font, size, "OUTLINE")
    end
  end
  banner.title:SetText("Watched item")
  local text, icon = LT.LineText(data)
  banner.text:SetText(text)
  banner.icon:SetTexture(icon)
  banner.age = 0
  banner:SetAlpha(1)
  banner:Show()
  banner:SetScript("OnUpdate", function(self, elapsed)
    self.age = self.age + elapsed
    if self.age > 4 then
      self:Hide()
      self:SetScript("OnUpdate", nil)
    elseif self.age > 3 then
      self:SetAlpha(4 - self.age)
    end
  end)
end
LT.Banner = function() return banner end -- (for the test)

-- Place and mover ---------------------------------------------------------------------------------------------

LT.DEFAULT_POS = {
  float = { "BOTTOM", "CENTER", 0, 60 },
  list = { "BOTTOMLEFT", "BOTTOMLEFT", 40, 260 },
}

local function PosKey()
  return LT.DB().style == "list" and "posList" or "posFloat"
end

local function SavedPosition()
  local pos = LT.DB()[PosKey()]
  if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string" and type(pos[3]) == "number"
    and type(pos[4]) == "number" then
    return pos
  end
  return LT.DEFAULT_POS[LT.DB().style == "list" and "list" or "float"]
end

local function PlaceHolder()
  local pos = SavedPosition()
  holder:ClearAllPoints()
  holder:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  holder:SetSize(WIDTH, LT.DB().style == "list" and LineHeight() * LT.DB().maxLines or RISE + LineHeight())
end

local function SavePosition()
  local left, bottom, width = holder:GetLeft(), holder:GetBottom(), holder:GetWidth()
  if type(left) == "number" and type(bottom) == "number" then
    if LT.DB().style == "list" then
      LT.DB()[PosKey()] = { "BOTTOMLEFT", "BOTTOMLEFT", math.floor(left + 0.5), math.floor(bottom + 0.5) }
    else
      LT.DB()[PosKey()] = { "BOTTOM", "BOTTOMLEFT", math.floor(left + (width or WIDTH) / 2 + 0.5),
        math.floor(bottom + 0.5) }
    end
  end
  PlaceHolder()
end

function LT.ResetPosition()
  LT.DB()[PosKey()] = nil
  if holder then
    PlaceHolder()
  end
end

local function BuildMover()
  local theme = Theme()
  mover = CreateFrame("Frame", nil, holder)
  mover:SetFrameStrata("DIALOG")
  mover:SetAllPoints(holder)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  local fill = mover:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(mover)
  fill:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.25)
  T.Outline(mover, 0, theme.accent, 1, "BORDER")
  local label = mover:CreateFontString(nil, "OVERLAY")
  UI.Font(label, "body", 12, "bright")
  label:SetPoint("BOTTOM", mover, "TOP", 0, 3)
  label:SetText("Loot text")
  mover:SetScript("OnDragStart", function()
    holder:StartMoving()
  end)
  mover:SetScript("OnDragStop", function()
    holder:StopMovingOrSizing()
    SavePosition()
  end)
  mover:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      holder:StopMovingOrSizing()
      LT.ResetPosition()
    end
  end)
  mover:Hide()
end

local function ShowMover()
  LT.editing = true
  if not mover then
    BuildMover()
  end
  mover:Show()
  LT.Test()
end

local function HideMover()
  LT.editing = false
  if mover then
    mover:Hide()
  end
  holder:StopMovingOrSizing()
end

local function HookEditMode()
  local manager = _G.EditModeManagerFrame
  if LT.editHooked or type(manager) ~= "table" or not manager.HookScript then
    return
  end
  LT.editHooked = true
  manager:HookScript("OnShow", ShowMover)
  manager:HookScript("OnHide", HideMover)
end

-- Size or look changed: every line restyled, the holder placed for the look.
function LT.Relayout()
  if not holder then
    return
  end
  PlaceHolder()
  for _, line in ipairs(active) do
    StyleLine(line)
    Fill(line)
  end
  for _, line in ipairs(pool) do
    StyleLine(line)
  end
  Place()
end

-- A few sample lines (the page's button, Edit Mode, /codex loottext test).
function LT.Test()
  if not holder then
    return
  end
  local samples = {
    { key = "test:money", kind = "money", amount = 12345 },
    { key = "test:item", kind = "item", amount = 3, link = "item:2589",
      info = { id = 2589, name = "Linen Cloth", quality = 1, icon = 132889 }, value = 60 },
    { key = "test:rare", kind = "item", amount = 1, link = "item:4306",
      info = { id = 4306, name = "Silk Cloth", quality = 2, icon = 132905 }, value = 25000, glow = true },
    { key = "test:rep", kind = "reputation", name = "Stormwind", amount = 250 },
    { key = "test:xp", kind = "xp", amount = 340, left = 12 },
  }
  for _, data in ipairs(samples) do
    data.sample = true
    LT.Show(data)
  end
end

function LT.BuildDisplay()
  if holder then
    return
  end
  holder = CreateFrame("Frame", "CodexLootText", UIParent)
  holder:SetFrameStrata("MEDIUM")
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  holder:EnableMouse(false)
  LT.holder = holder
  PlaceHolder()
  HookEditMode()
end
