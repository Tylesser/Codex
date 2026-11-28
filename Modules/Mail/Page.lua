local addonName, ns = ...
local L = ns.L

-- The Mail page: heading + status, the about text, one check per part (each with its words for the info panel),
-- a note while Postal does the job, and the recent names on this realm with a button to forget them.

local M = ns.mail
local UI = ns.UI
local view = {}

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetPoint("RIGHT", 0, 0)
  return text
end

local PARTS = {
  { key = "openAll", label = L["Open all and Gold only buttons in the inbox"],
    info = L["Two buttons take the place of the game's Open All Mail: Open all takes the gold and items from every mail, Gold only just the gold. Mails with Cash on Delivery and mails from a Game Master are left for you. With full bags the gold is still taken. One line in chat tells what you got."] },
  { key = "recent", label = L["Recent names beside the To box"],
    info = L["A small button at the end of the To box lists the names you sent mail to on this realm and your other characters here. Click one to put it in the To box."] },
  { key = "altAttach", label = L["Alt-click a bag item to attach every stack of it"],
    info = L["While the Send Mail tab is open, Alt-click an item in your bags and every stack of it goes into the letter, up to its 12 slots. Soulbound items stay in your bags."] },
}

function M.RefreshPage()
  if not view.page then
    return
  end
  local db = M.DB()
  view.status:SetText(M.StatusText())
  local postal = M.PostalLoaded()
  for _, part in ipairs(PARTS) do
    local check = view.checks[part.key]
    check:SetChecked(db[part.key] and true or false)
    check:SetEnabled(not postal)
  end
  view.postal:SetShown(postal)
  local count = #M.Recents()
  view.recent:SetText(count > 0 and L["Recent names on this realm: %d."]:format(count)
    or L["No recent names on this realm yet."])
  view.forget:SetEnabled(count > 0)
end

function M.BuildPage(page)
  M.DB()
  view.page = page
  local heading = UI.Heading(page, L["Mail"], 20)
  heading:SetPoint("TOPLEFT")
  view.status = Wrap(UI.Text(page, "body", 12, "muted"))
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)

  local about = Wrap(UI.Text(page, "body", 12, "text"))
  about:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -14)
  about:SetText(L["At the mailbox Codex takes all your mail at once (or only the gold), remembers the names you send mail to, and attaches every stack of an item with one Alt-click. Nothing is sent by itself: you still press Send."])

  view.checks = {}
  local anchor = about
  for index, part in ipairs(PARTS) do
    local check = UI.Check(page, part.label)
    UI.Font(check.label, "body", 13)
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, index == 1 and -16 or -8)
    check.codexInfo = part.info
    check:SetScript("OnClick", function(self)
      M.DB()[part.key] = self:GetChecked() and true or false
      if M.RefreshButtons then
        M.RefreshButtons()
      end
      M.RefreshPage()
    end)
    view.checks[part.key] = check
    anchor = check
  end

  view.postal = Wrap(UI.Text(page, "body", 12, "warn"))
  view.postal:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
  view.postal:SetText(L["Postal is loaded: it does these jobs, so Codex leaves the mailbox to it."])

  view.recent = UI.Text(page, "body", 12, "muted")
  view.recent:SetPoint("TOPLEFT", view.postal, "BOTTOMLEFT", 0, -14)
  view.forget = UI.Button(page, 190, 24, L["Forget the recent names"])
  view.forget:SetPoint("LEFT", view.recent, "RIGHT", 12, 0)
  view.forget.codexInfo = L["Clears the list of names you sent mail to on this realm. Your characters stay."]
  view.forget:SetScript("OnClick", function()
    M.ClearRecents()
    M.RefreshPage()
  end)
  M.RefreshPage()
end
