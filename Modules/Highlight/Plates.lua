local addonName, ns = ...

-- Highlights on nameplates. An object (herb, ore, chest, fishing pool, quest object) gets a pulsing glow (a soft
-- disc in its kind's colour), a thin ring and a slowly turning sparkle, with its name under it; a quest object has
-- a "!" in the ring. (The round-2 board's still ring with a glyph was tried in game; the user preferred this pulsing
-- one, 2026-11-18. Its art, Media/NodeRing and the glyphs, stays for now.) A quest mob gets a clean "!" beside its
-- name (not while Questie draws its own nameplate icons).
-- The kind comes from the object's name (Classic herb names, "... Vein" / "... Deposit" for ore, chest and pool
-- names), then from its tooltip (a line naming Herbalism or Mining). Quests: C_QuestLog.UnitIsRelatedToActiveQuest,
-- UnitIsQuestBoss, the tooltip's quest lines (objects) and, when the QoL module has one, its quest objective index.
-- Care (Forever): plates are recycled and values can be secret. Every value is checked before use (H.Ask), every
-- call on the game caught. Only our own frame (one per plate, weak table) is made, shown, hidden; Blizzard's plate
-- itself is never moved, sized, shown, hidden or written to, so this works in combat too.
-- Art: branding/source/highlight-art.py.

local H = ns.highlight
local P = {}
H.platesAPI = P

local MEDIA = "Interface\\AddOns\\Codex\\Modules\\Highlight\\Media\\"
local GLOW = "Interface\\AddOns\\Codex\\Media\\Circle"
local RING = "Interface\\AddOns\\Codex\\Modules\\Buffs\\Media\\Ring"
local SPARKLE = "Interface\\Cooldown\\star4"
-- The "!": our own texture (a font "!" was blurry in game, 2026-11-28), cropped to the glyph's columns so it
-- anchors like text; white with a black edge, tinted with SetVertexColor. Shared with Bags.lua.
H.BANG = { texture = MEDIA .. "Bang", left = 18 / 64, right = 46 / 64, aspect = 28 / 64 }
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local RING_SIZE = 30
local GLOW_SPAN, SPARKLE_SPAN = 1.7, 1.5 -- times the ring
local PULSE_TIME, TURN_TIME = 0.9, 6 -- seconds: glow up (then down again), one full turn of the sparkle

-- The board's colours: herb #6ee06e, ore #ffa04a, treasure #f0c24e, quest "!" #ffd100; pools are ours (blue).
H.COLORS = {
  herb = { 0.43, 0.88, 0.43 },
  ore = { 1, 0.63, 0.29 },
  chest = { 0.94, 0.76, 0.31 },
  fish = { 0.4, 0.75, 1 },
  quest = { 1, 0.82, 0 },
  questmob = { 1, 0.82, 0 },
}

-- Classic herb nodes (English names, from the shared table in Gathering.lua; other languages go by the tooltip).
H.HERBS = {}
for name, node in pairs(ns.GATHER_SKILL or {}) do
  if node.skill == "herbalism" then
    H.HERBS[name] = true
  end
end
local ORE = { " Vein$", " Deposit$", "Obsidian Chunk$" }
local FISH = { " School$", "^Floating Wreckage$", "^Floating Debris$", "^Oil Spill$", "^Patch of Elemental Water$" }
local CHEST = { "Chest$", "Footlocker$", "Strongbox$", "Lockbox$", "Coffer$" }

local function Matches(name, patterns)
  for _, pattern in ipairs(patterns) do
    if name:find(pattern) then
      return true
    end
  end
  return false
end

-- "herb", "ore", "fish", "chest" or nil, from an object's name.
function H.Kind(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if H.HERBS[name] then
    return "herb"
  end
  if Matches(name, ORE) then
    return "ore"
  end
  if Matches(name, FISH) then
    return "fish"
  end
  if Matches(name, CHEST) then
    return "chest"
  end
  return nil
end

-- The player's gathering professions (spells learned with them), read once until the skills change.
local KNOWS = {
  herb = { 2366, 2368, 3570, 11993, 2383 }, -- Herb Gathering ranks, Find Herbs
  ore = { 2575, 2576, 3564, 10248, 2580 }, -- Mining ranks, Find Minerals
}
function H.Knows(kind)
  H.knows = H.knows or {}
  if H.knows[kind] == nil then
    local known = false
    local test = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    for _, id in ipairs(KNOWS[kind] or {}) do
      if H.Ask(test, id) == true then
        known = true
        break
      end
    end
    H.knows[kind] = known
  end
  return H.knows[kind]
end

-- Tooltip ------------------------------------------------------------------------------------------------

local function TooltipLines(unit)
  local data = C_TooltipInfo and H.Ask(C_TooltipInfo.GetUnit, unit)
  local lines = type(data) == "table" and H.Readable(data.lines) and data.lines
  return type(lines) == "table" and lines or {}
end

local function LineText(line)
  local text = type(line) == "table" and line.leftText
  return H.Readable(text) and type(text) == "string" and text or nil
end

local skillNames
local function SkillName(id, english)
  local name
  if C_TradeSkillUI then
    name = H.Ask(C_TradeSkillUI.GetTradeSkillDisplayName, id)
  end
  if type(name) ~= "string" and C_SkillInfo then
    local info = H.Ask(C_SkillInfo.GetSkillLineInfoByID, id)
    name = type(info) == "table" and info.name or info
  end
  return type(name) == "string" and name ~= "" and name or english
end

-- "herb" / "ore" from a tooltip line naming the profession.
function P.TooltipKind(unit)
  skillNames = skillNames or { herb = SkillName(182, "Herbalism"), ore = SkillName(186, "Mining") }
  for _, line in ipairs(TooltipLines(unit)) do
    local text = LineText(line)
    if text then
      for kind, skill in pairs(skillNames) do
        if text:find(skill, 1, true) then
          return kind
        end
      end
    end
  end
  return nil
end

local function QuestLineTypes()
  local types = Enum and Enum.TooltipDataLineType
  if type(types) ~= "table" then
    return {}
  end
  local set = {}
  for _, key in ipairs({ "QuestObjective", "QuestTitle", "QuestPlayer" }) do
    if types[key] ~= nil then
      set[types[key]] = true
    end
  end
  return set
end

local function TooltipQuest(unit)
  local quest = QuestLineTypes()
  for _, line in ipairs(TooltipLines(unit)) do
    local kind = type(line) == "table" and line.type
    if kind ~= nil and H.Readable(kind) and quest[kind] then
      return true
    end
  end
  return false
end

-- The QoL module's quest objective index (names in the quest log's objectives), when it has one.
local function InQuestIndex(name)
  local Q = ns.qol
  if type(name) ~= "string" or not (Q and type(Q.QuestIndex) == "function") then
    return false
  end
  local ok, index = pcall(Q.QuestIndex)
  if not ok or type(index) ~= "table" then
    return false
  end
  -- (the names sit in index.byName, lower case; this looked them up on the index itself and never matched,
  -- found by the 2026-11-27 audit)
  local byName = type(index.byName) == "table" and index.byName or {}
  return (byName[name:lower()] or byName[name]) and true or false
end

function P.IsQuest(unit, object, name)
  local related = C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
  if H.Ask(related, unit) == true then
    return true
  end
  if not object and H.Ask(UnitIsQuestBoss, unit) == true then
    return true
  end
  if object or not related then
    if TooltipQuest(unit) or InQuestIndex(name) then
      return true
    end
  end
  return false
end

-- Questie draws its own quest icons on plates (its option applies live).
local function QuestieIcons()
  local questie = _G.Questie
  local db = type(questie) == "table" and questie.db
  local profile = type(db) == "table" and db.profile
  return type(profile) == "table" and profile.nameplateEnabled == true
end

function P.IsObject(unit)
  local object = H.Ask(UnitIsGameObject, unit)
  if object ~= nil then
    return object == true
  end
  local guid = H.Ask(UnitGUID, unit)
  return type(guid) == "string" and guid:find("^GameObject%-") ~= nil
end

-- What a plate's unit gets: kind (a key of H.COLORS) and name, or nil.
function P.Classify(unit)
  local db = H.DB()
  local name = H.Ask(UnitName, unit)
  if type(name) ~= "string" then
    name = nil
  end
  if P.IsObject(unit) then
    if db.questPlates and P.IsQuest(unit, true, name) then
      return "quest", name
    end
    local kind = H.Kind(name)
    if not kind and db.nodes then
      kind = P.TooltipKind(unit)
    end
    if kind == "herb" or kind == "ore" then
      if not db.nodes or (db.ownOnly and not H.Knows(kind)) then
        return nil
      end
    elseif kind == "chest" and not db.chests or kind == "fish" and not db.fish then
      return nil
    end
    return kind, name
  end
  if db.questPlates and not QuestieIcons() and P.IsQuest(unit, false, name) then
    return "questmob", name
  end
  return nil
end

-- Our frame on a plate -------------------------------------------------------------------------------------

local marks = setmetatable({}, { __mode = "k" }) -- [plate] = our frame
P.marks = marks
local units = {} -- [nameplate unit token] = true while it has a plate
P.units = units

local function BodyFont()
  local theme = ns.InkTheme and ns.InkTheme() or ns.Theme and ns.Theme()
  local font = type(theme) == "table" and type(theme.font) == "table" and theme.font.body
  return type(font) == "string" and font or FONT
end

-- Our own textures' animations (fine in combat): the glow pulses, the sparkle turns.
local function Animate(texture, build)
  if type(texture.CreateAnimationGroup) ~= "function" then
    return nil
  end
  local ok, group = pcall(texture.CreateAnimationGroup, texture)
  if not ok or type(group) ~= "table" then
    return nil
  end
  pcall(build, group)
  return group
end

local function Build(plate)
  local mark = CreateFrame("Frame", nil, plate)
  mark:EnableMouse(false)
  mark.glow = mark:CreateTexture(nil, "BACKGROUND")
  mark.glow:SetTexture(GLOW)
  if mark.glow.SetBlendMode then
    mark.glow:SetBlendMode("ADD")
  end
  mark.pulse = Animate(mark.glow, function(group)
    group:SetLooping("BOUNCE")
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.2)
    fade:SetToAlpha(0.75)
    fade:SetDuration(PULSE_TIME)
    if fade.SetSmoothing then
      fade:SetSmoothing("IN_OUT")
    end
  end)
  mark.sparkle = mark:CreateTexture(nil, "BORDER")
  mark.sparkle:SetTexture(SPARKLE)
  if mark.sparkle.SetBlendMode then
    mark.sparkle:SetBlendMode("ADD")
  end
  mark.turn = Animate(mark.sparkle, function(group)
    group:SetLooping("REPEAT")
    local spin = group:CreateAnimation("Rotation")
    spin:SetDegrees(-360)
    spin:SetDuration(TURN_TIME)
  end)
  mark.ring = mark:CreateTexture(nil, "ARTWORK")
  mark.ring:SetTexture(RING)
  mark.bang = mark:CreateTexture(nil, "OVERLAY")
  mark.bang:SetTexture(H.BANG.texture)
  mark.bang:SetTexCoord(H.BANG.left, H.BANG.right, 0, 1)
  mark.label = mark:CreateFontString(nil, "OVERLAY")
  mark.label:SetFont(BodyFont(), 13, "OUTLINE")
  mark.label:SetShadowOffset(0, -1)
  mark.label:SetShadowColor(0, 0, 0, 1)
  marks[plate] = mark
  return mark
end

function P.Clear(plate)
  local mark = plate and marks[plate]
  if mark and mark.kind then
    mark.kind = nil
    mark:Hide()
  end
end

-- Where a quest mob's "!" goes: beside the plate's name when Codex's nameplate restyle tells us where that is,
-- else just over the plate. Returns point, region, relativePoint, x, y.
local function MobAnchor(plate)
  local skins = ns.S
  local fn = (type(skins) == "table" and skins.NameplateMarkAnchor)
    or (type(TylesserCodex) == "table" and TylesserCodex.NameplateMarkAnchor)
  if type(fn) == "function" then
    local ok, region, point, relativePoint, x, y = pcall(fn, plate)
    if ok and type(region) == "table" then
      return point or "RIGHT", region, relativePoint or "LEFT", x or -4, y or 0
    end
  end
  return "BOTTOM", plate, "TOP", 0, 2
end

function P.Show(plate, kind, name)
  local mark = marks[plate] or Build(plate)
  local db = H.DB()
  local size = tonumber(db.size) or 1
  local color = H.COLORS[kind]
  local r, g, b = color[1], color[2], color[3]
  mark:ClearAllPoints()
  mark.bang:ClearAllPoints()
  mark.bang:SetVertexColor(r, g, b, 1)
  if kind == "questmob" then
    -- the board's "!": #ffd100, black edge; no disc behind it
    local s = math.floor(18 * size + 0.5)
    mark:SetSize(s, s)
    mark:SetPoint(MobAnchor(plate))
    mark.bang:SetSize(s * H.BANG.aspect, s)
    mark.bang:SetPoint("CENTER", mark, "CENTER", 0, 0)
    mark.bang:Show()
    mark.ring:Hide()
    mark.glow:Hide()
    mark.sparkle:Hide()
    if mark.pulse then mark.pulse:Stop() end
    if mark.turn then mark.turn:Stop() end
    mark.label:Hide()
  else
    local ring = RING_SIZE * size
    mark:SetSize(ring, ring)
    mark:SetPoint("CENTER", plate, "BOTTOM", 0, 0)
    for _, part in ipairs({ { mark.glow, GLOW_SPAN, 0.75 }, { mark.sparkle, SPARKLE_SPAN, 0.9 }, { mark.ring, 1, 1 } }) do
      local texture, span = part[1], part[2] * ring
      texture:ClearAllPoints()
      texture:SetPoint("CENTER", mark, "CENTER", 0, 0)
      texture:SetSize(span, span)
      texture:SetVertexColor(r, g, b, part[3])
      texture:Show()
    end
    if mark.pulse and not mark.pulse:IsPlaying() then mark.pulse:Play() end
    if mark.turn and not mark.turn:IsPlaying() then mark.turn:Play() end
    if kind == "quest" then -- a quest object: "!" in the ring
      local s = math.floor(20 * size + 0.5)
      mark.bang:SetSize(s * H.BANG.aspect, s)
      mark.bang:SetPoint("CENTER", mark, "CENTER", 0, 0)
      mark.bang:Show()
    else
      mark.bang:Hide()
    end
    mark.label:ClearAllPoints()
    mark.label:SetPoint("TOP", mark, "BOTTOM", 0, -5)
    mark.label:SetFont(BodyFont(), math.floor(13 * size + 0.5), "OUTLINE")
    mark.label:SetTextColor(r, g, b, 1)
    mark.label:SetText(name or "")
    mark.label:SetShown(db.names and name and true or false)
  end
  mark.kind = kind
  mark:Show()
  return mark
end

-- Plates -------------------------------------------------------------------------------------------------

local function PlateFor(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return nil
  end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" then
    return nil
  end
  local okForbidden, forbidden = pcall(plate.IsForbidden, plate)
  if okForbidden and forbidden then
    return nil
  end
  return plate
end
P.PlateFor = PlateFor

local function UsableUnit(unit)
  return unit ~= nil and H.Readable(unit) and type(unit) == "string"
end

function P.Update(unit)
  if not UsableUnit(unit) then
    return
  end
  local plate = PlateFor(unit)
  if not plate then
    return
  end
  local ok, kind, name = pcall(P.Classify, unit)
  if ok and kind then
    P.Show(plate, kind, name)
  else
    P.Clear(plate)
  end
end

function H.RefreshPlates()
  if not H.running then
    return
  end
  for unit in pairs(units) do
    P.Update(unit)
  end
end

local queued = false
local function RefreshSoon()
  if queued then
    return
  end
  queued = true
  C_Timer.After(0, function()
    queued = false
    H.RefreshPlates()
  end)
end

local function OnEvent(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then
    if UsableUnit(unit) then
      units[unit] = true
      P.Update(unit)
    end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    if UsableUnit(unit) then
      units[unit] = nil
      P.Clear(PlateFor(unit))
    end
  elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
    -- the object you would interact with changed: its plate (when it already had one) is looked at again
    for token in pairs(units) do
      if H.Ask(UnitIsUnit, token, "softinteract") == true then
        P.Update(token)
      end
    end
  elseif event == "SKILL_LINES_CHANGED" then
    H.knows = nil
    RefreshSoon()
  else -- quest log changes come in bursts: one pass on the next frame
    RefreshSoon()
  end
end

function H.EnablePlates()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", OnEvent)
  for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_SOFT_INTERACT_CHANGED",
    "QUEST_LOG_UPDATE", "SKILL_LINES_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
  end
  pcall(events.RegisterUnitEvent, events, "UNIT_QUEST_LOG_CHANGED", "player")
  P.events = events
  -- plates already on screen
  local list = C_NamePlate and H.Ask(C_NamePlate.GetNamePlates)
  for _, plate in ipairs(type(list) == "table" and list or {}) do
    local unit = type(plate) == "table" and (plate.namePlateUnitToken or plate.unitToken)
    if UsableUnit(unit) then
      units[unit] = true
      P.Update(unit)
    end
  end
end
