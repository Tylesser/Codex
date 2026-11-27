local addonName, ns = ...
local L = ns.L

-- Start-up and the /codex command. Loaded last, after every module has registered itself.

-- A "Codex" button in the game menu (Esc), right after Blizzard's "AddOns". Forever's GameMenuFrame builds its
-- buttons in InitButtons (Blizzard_GameMenu/Shared/GameMenuFrame.lua, forever branch) from a pool laid out by
-- layoutIndex: after it runs, our button is added and given the place just after AddOns (or at the end when
-- that button isn't there). InitButtons resets the menu on every show, so nothing of ours lingers.
function ns.AddGameMenuButton(menu)
  if type(menu) ~= "table" or type(menu.AddButton) ~= "function" or not menu.buttonPool then
    return
  end
  local ok, button = pcall(menu.AddButton, menu, "Codex", function()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    end
    if HideUIPanel then
      pcall(HideUIPanel, menu)
    end
    ns.ToggleWindow()
  end)
  if not ok or type(button) ~= "table" then
    return
  end
  -- the Codex emblem left of the word. Buttons are pooled and come back as other entries next time, so the
  -- emblem is hidden on every button that had one before it shows on ours.
  ns.gameMenuIcons = ns.gameMenuIcons or setmetatable({}, { __mode = "k" })
  for _, icon in pairs(ns.gameMenuIcons) do
    icon:Hide()
  end
  local icon = ns.gameMenuIcons[button]
  if not icon and type(button.CreateTexture) == "function" then
    icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(ns.T and ns.T.EMBLEM or "Interface\\AddOns\\Codex\\Media\\Emblem")
    icon:SetSize(18, 18)
    ns.gameMenuIcons[button] = icon
  end
  if icon then
    icon:ClearAllPoints()
    -- the word is centred on the button (its font string may span the whole width): the emblem goes just left
    -- of where the word starts
    local text = type(button.GetFontString) == "function" and button:GetFontString()
    local width = type(text) == "table" and type(text.GetStringWidth) == "function" and tonumber(text:GetStringWidth()) or 0
    if width > 0 then
      icon:SetPoint("CENTER", button, "CENTER", -(width / 2) - 14, 0)
    else
      icon:SetPoint("LEFT", button, "LEFT", 10, 0)
    end
    icon:Show()
  end
  local label = type(ADDONS) == "string" and ADDONS or "AddOns"
  local after
  for other in menu.buttonPool:EnumerateActive() do
    if other ~= button and type(other.GetText) == "function" and other:GetText() == label then
      after = other
    end
  end
  if after and type(after.layoutIndex) == "number" then
    button.layoutIndex = after.layoutIndex + 0.5
    button.topPadding = nil
  end
  if type(menu.MarkDirty) == "function" then
    menu:MarkDirty()
  elseif type(menu.Layout) == "function" then
    pcall(menu.Layout, menu)
  end
end

local function HookGameMenu()
  local menu = _G.GameMenuFrame
  if type(menu) == "table" and type(menu.InitButtons) == "function" and not ns.gameMenuHooked then
    ns.gameMenuHooked = true
    hooksecurefunc(menu, "InitButtons", ns.AddGameMenuButton)
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" then
    if name == addonName then
      ns.SetupDB()
      if ns.ApplyCharacterProfile then
        ns.ApplyCharacterProfile() -- this character's profile, before the theme loads (Profiles.lua)
      end
      ns.LoadTheme()
      self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    ns.EnableModules()
    ns.CreateMinimapButton()
    if ns.db.skins.enabled then
      if not ns.LoadAddOn("Codex_Skins") then
        ns.Say(L["the game UI restyle (Codex_Skins) could not be loaded: %s"]:format(
          tostring(ns.loadErrors and ns.loadErrors.Codex_Skins)))
      elseif ns.UIOverlap() then
        ns.Say(ns.OVERLAP_NOTE:format(ns.UIOverlap()))
      end
    elseif not ns.db.skins.told then
      -- once: the restyle is off by default, so say where it is
      ns.db.skins.told = true
      ns.Say(L["Codex can restyle your game interface (action bars, chat, quests, minimap, ...) in your theme: /codex settings, then \"Restyle the game's interface\" in General."])
    end
    if ns.themeMissing then
      ns.Say(L["the %s theme (folder %s) is missing or switched off, so a plain look is used."]
        :format(ns.themeMissing.name, ns.themeMissing.folder))
    end
    HookGameMenu()
    ns.T.AddCompartment({ text = ns.TITLE, onClick = function() ns.ToggleWindow() end,
      tooltip = { L["Click to open Codex."] } })
    -- a button on the game's Tylesser page (Options > AddOns) and in Tylesser's settings window that opens the
    -- Codex window (2026-11-28, the user's request: "for Codex keep a separate button that opens the Codex page")
    pcall(ns.T.RegisterLauncher, L["Open Codex"], function()
      if not (ns.window and ns.window:IsShown()) then
        ns.ToggleWindow()
      end
      if ns.window then
        ns.window:Raise() -- (over the game's settings window: same strata)
      end
    end)
    if ns.MaybeShowSetup then
      ns.MaybeShowSetup() -- the first-run setup, once (Setup.lua)
    end
    if ns.MaybeShowWhatsNew then
      ns.MaybeShowWhatsNew() -- once per new version (WhatsNew.lua)
    end
  end
end)

SLASH_CODEX1 = "/codex"
SlashCmdList.CODEX = function(input)
  local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  command = command:lower()
  if command == "" then
    ns.ToggleWindow()
  elseif command == "feedback" then
    ns.T.ShowFeedback()
  elseif command == "whatsnew" or command == "news" or command == "changes" then
    ns.ShowWhatsNew()
  elseif command == "setup" then
    if ns.ShowSetup then
      ns.ShowSetup(1)
    end
  elseif command == "profile" or command == "profiles" then
    ns.ShowSettings("profiles")
  elseif command == "debug" and rest:lower() == "micro" then
    -- what the micro menu and its strip are made of (for tuning the restyle)
    local report = ns.API.MicroDebug
    local ok, list = pcall(type(report) == "function" and report or error, "the action bar look isn't loaded")
    if not ok or type(list) ~= "table" then
      ns.Say("micro debug: " .. tostring(list))
      return
    end
    local function Line(value, depth)
      if type(value) ~= "table" then
        return tostring(value)
      end
      if depth > 1 then
        return "{...}"
      end
      local parts = {}
      for key, item in pairs(value) do
        parts[#parts + 1] = tostring(key) .. "=" .. Line(item, depth + 1)
      end
      return "{" .. table.concat(parts, " ") .. "}"
    end
    for key, value in pairs(list) do
      ns.Say(tostring(key) .. ": " .. Line(value, 0))
    end
  elseif command == "debug" and rest:lower() == "ui" then
    -- which of the game's atlases and files the parts' pictures found (grey stand-ins for the rest)
    ns.ShowSettings("interface")
    ns.BuildAllSections()
    local found, missing = {}, {}
    for name, ok in pairs(ns.UI_PREVIEW_ART or {}) do
      table.insert(ok and found or missing, name)
    end
    table.sort(found)
    table.sort(missing)
    ns.Say(("UI pictures: %d found, %d missing."):format(#found, #missing))
    if #missing > 0 then
      ns.Say("missing: " .. table.concat(missing, ", "))
    end
  elseif command == "debug" and rest:lower() == "bars" then
    -- why a bar has (no) panel: from the skins folder, when it is loaded
    local report = ns.API.BarDebug
    if type(report) ~= "function" then
      ns.Say("the action bar look isn't loaded (General > Restyle the game's interface, and Action bars > Look > the panel behind each bar).")
      return
    end
    local ok, list = pcall(report)
    if not ok or type(list) ~= "table" then
      ns.Say("bar debug failed: " .. tostring(list))
      return
    end
    for _, info in ipairs(list) do
      local parts = {}
      for _, key in ipairs({ "panel", "barShown", "barVisible", "barAlpha", "clips", "buttonParent", "hostShown",
        "hostVisible", "hostParent", "points", "edges", "fail", "error" }) do
        if info[key] ~= nil then
          parts[#parts + 1] = key .. "=" .. tostring(info[key])
        end
      end
      ns.Say(tostring(info.name) .. ": " .. table.concat(parts, " "))
    end
  elseif command == "settings" or command == "home" then
    ns.ShowPage(command)
  elseif ns.modules[command] then
    local module = ns.modules[command]
    if module.Slash and rest ~= "" then
      module.Slash(module, rest) -- the module opens its page itself when the command needs it
    else
      ns.ShowPage(command)
    end
  else
    -- a module may own extra commands (e.g. "/codex scan")
    for _, module in ipairs(ns.moduleList) do
      if module.commands and module.commands[command] and ns.ModuleOn(module.id) then
        module.commands[command](module, rest)
        return
      end
    end
    local names = {}
    for _, module in ipairs(ns.moduleList) do
      names[#names + 1] = module.id
    end
    ns.Say(L["/codex opens the window. /codex <%s|settings> opens a page. /codex setup runs the setup again, /codex whatsnew shows what changed, /codex profile opens the profiles, /codex feedback shows the feedback link."]
      :format(table.concat(names, "|")))
  end
end
