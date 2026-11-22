local addonName, ns = ...

-- Quest items in the bags (round-2 design, board R2-Bags): a small triangle in the slot's top-left corner, 9px on a
-- 40px slot, 3px in, in the theme's quest colour (C_Container.GetContainerItemQuestInfo; items that start a quest
-- get it too, Blizzard's own "!" stays on those). Blizzard's bag windows through a post-hook on each container
-- frame's UpdateItems; Codex's own bag window calls H.QuestMark(button, bag, slot) from its FillLive. On Codex's own
-- buttons the game's heavy quest border (IconQuestTexture) goes to alpha 0 while the corner shows; Blizzard's
-- buttons are left as they are. Only alpha and textures of ours (one per button, weak table): fine in combat.
-- Art: branding/source/highlight-art.py (Corner.tga).

local H = ns.highlight

local CORNER = "Interface\\AddOns\\Codex\\Modules\\Highlight\\Media\\Corner"
local SLOT, MARK, INSET = 40, 9, 3 -- the board's slot, mark and inset (px)
-- The board's questMark token per theme (not in the theme files yet): the accent, except Slate's blue accent.
local QUEST_COLORS = {
  runestone = { 0.94, 0.76, 0.31 }, -- #f0c24e
  classic = { 1, 0.82, 0 }, -- #ffd100
  hearthwood = { 0.94, 0.73, 0.33 }, -- #f0b955
  slate = { 0.91, 0.75, 0.38 }, -- #e8c060
  dusk = { 0.498, 0.722, 0.690 }, -- #7fb8b0 the teal accent (the tracked quest colour of the Dusk boards)
  obsidian = { 0.784, 0.635, 0.353 }, -- #C8A25A its gold accent
  onyx = { 0.435, 0.698, 0.659 }, -- #6FB2A8 its teal accent
}

local marks = setmetatable({}, { __mode = "k" }) -- [item button] = our corner
H.bagMarks = marks

function H.QuestColor()
  local color = ns.db and QUEST_COLORS[ns.db.theme]
  if not color then
    local theme = ns.Theme and ns.Theme()
    color = type(theme) == "table" and type(theme.accent) == "table" and theme.accent or QUEST_COLORS.runestone
  end
  return color
end

local function Build(button)
  local corner = button:CreateTexture(nil, "OVERLAY", nil, 6)
  corner:SetTexture(CORNER)
  local mark = { corner = corner }
  marks[button] = mark
  return mark
end

-- The game's quest border on Codex's own buttons (made by the Bags module, so ours to dim).
local function OwnBorder(button, shown)
  if button.codexCount == nil then
    return
  end
  local border = button.IconQuestTexture
  if type(border) == "table" and border.SetAlpha then
    pcall(border.SetAlpha, border, shown and 1 or 0)
  end
end

local function Hide(button, mark)
  if not mark or not mark.state then
    return
  end
  mark.state = nil
  mark.corner:Hide()
  OwnBorder(button, true)
end

-- "starts" (begins a quest you don't have), "item" (belongs to a quest) or nil.
function H.QuestState(bag, slot)
  if not (bag and slot and C_Container and C_Container.GetContainerItemQuestInfo) then
    return nil
  end
  local info = H.Ask(C_Container.GetContainerItemQuestInfo, bag, slot)
  if type(info) ~= "table" then
    return nil
  end
  local questID = H.Readable(info.questID) and info.questID or nil
  local isQuest = H.Readable(info.isQuestItem) and info.isQuestItem or false
  local active = H.Readable(info.isActive) and info.isActive or false
  if questID and not active then
    return "starts"
  end
  if isQuest or questID then
    return "item"
  end
  return nil
end

-- Marks (or clears) one item button. bag, slot: where its item is (nil for an empty or offline slot).
-- Marks (or clears) one item button. bag, slot: where its item is (nil for an empty or offline slot).
function H.QuestMark(button, bag, slot)
  if type(button) ~= "table" then
    return
  end
  local state = H.running and H.DB().questBags and H.QuestState(bag, slot) or nil
  local mark = marks[button]
  if not state then
    Hide(button, mark)
    return
  end
  mark = mark or Build(button)
  mark.state = state
  local ok, width = pcall(button.GetWidth, button)
  width = ok and H.Readable(width) and type(width) == "number" and width > 0 and width or 37
  local scale = width / SLOT
  local corner = mark.corner
  corner:ClearAllPoints()
  corner:SetPoint("TOPLEFT", button, "TOPLEFT", INSET * scale, -INSET * scale)
  corner:SetSize(MARK * scale, MARK * scale)
  local color = H.QuestColor()
  corner:SetVertexColor(color[1], color[2], color[3], 1)
  corner:Show()
  OwnBorder(button, false)
end

-- Blizzard's bags ------------------------------------------------------------------------------------------

local function ButtonPlace(button)
  local okBag, bag = pcall(button.GetBagID, button)
  local okSlot, slot = pcall(button.GetID, button)
  bag = okBag and H.Readable(bag) and bag or nil
  slot = okSlot and H.Readable(slot) and slot or nil
  return bag, slot
end

local function UpdateFrame(frame)
  if type(frame.EnumerateValidItems) ~= "function" then
    return
  end
  local ok, err = pcall(function()
    for _, button in frame:EnumerateValidItems() do
      H.QuestMark(button, ButtonPlace(button))
    end
  end)
  if not ok and err then
    H.bagError = err
  end
end

local function ContainerFrames()
  local list = { _G.ContainerFrameCombinedBags }
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    list[#list + 1] = _G["ContainerFrame" .. i]
  end
  return list
end

function H.EnableBags()
  for _, frame in pairs(ContainerFrames()) do
    if type(frame) == "table" and type(frame.UpdateItems) == "function" and frame.EnumerateValidItems then
      hooksecurefunc(frame, "UpdateItems", UpdateFrame)
    end
  end
end

-- After a switch: the bag windows that are open, and the buttons that carry a mark.
function H.RefreshBags()
  for _, frame in pairs(ContainerFrames()) do
    if type(frame) == "table" and frame.IsShown and frame:IsShown() then
      UpdateFrame(frame)
    end
  end
  if not (H.running and H.DB().questBags) then
    for button, mark in pairs(marks) do
      Hide(button, mark)
    end
  end
end
