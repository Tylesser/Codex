# Tylesser - Codex

The all-in-one Tylesser addon (started 2026-11-17). Every feature is a **module** that can be switched off;
the look comes from one of five **themes**; restyling the game's own interface is a separate **skins** folder.
Workspace conventions are in `E:/Games/Wow/CLAUDE.md`. Public repo Tylesser/Codex, CurseForge 1817747, Wago kNMP9RGz;
first beta v1.0.0-beta1 on 2026-11-20, **1.0.0 (out of beta) on 2026-11-21** (the user's choice). A tag with "beta"
(`v1.0.0-beta2`) is a beta on both stores and a GitHub pre-release, a plain tag (`v1.0.1`) a release; the changelog
heading is the version without the "v" (`## 1.0.1`).

**Forever only** (the user's decision, 2026-11-17): every .toc says `## Interface: 16001` and the code needs no
fallbacks for other clients. `ReloadUI` is protected on Forever: reloads go through the secure `/reload` macro
button `CodexReloadButton` (Window.lua), laid over the banner's button out of combat.

## Folders (one repo, several game addons)

| Folder | Game addon | Loaded |
| --- | --- | --- |
| `.` | `Codex` | always |
| `Themes/Runestone`, `Themes/Hearthwood`, `Themes/Classic`, `Themes/Slate`, `Themes/Dusk` | `Codex_<Name>` | only the theme the player picked (`CodexDB.theme`), at Codex's ADDON_LOADED |
| `Skins` | `Codex_Skins` | at PLAYER_LOGIN, only when "Restyle the game's interface" is on (`CodexDB.skins.enabled`) |

Skins restyle Blizzard's frames (positions stay with Edit Mode) except `UnitFrames.lua`, which builds Codex's own
player/target/ToT/pet/focus frames (movable while Edit Mode is open, `CodexDB.skins.frames`) and parks Blizzard's.
Frame style `CodexDB.skins.frameStyle`: "compact" (default since 2026-11-17, the user's request: no backdrop, bars hang
off the portrait ring, party rows 70 apart) or "panel" (the board look); `ns.FrameStyle()`, `TylesserCodex.RefreshFrameStyle()`.
Forever facts used (from FlareUI, MIT): never hide ObjectiveTrackerFrame; never write to GameTooltipStatusBar; each
gryphon is its own Edit Mode system; chat: post-hooks only, never call FCF_Tab_OnClick; minimap is not protected.
Chat tabs (2026-11-26, the user's wish): a post-hook on `FCFDock_UpdateTabs` (Skins/Chat.lua `FitTabs`) gives every
docked tab one width when Blizzard shows the dock's overflow button (min 28; under that Blizzard's scrolling stays),
sets only numbers (whisper tab names can be secret), hides the overflow button and sets `scrollFrame.dynTabSize` so
Blizzard's scroll-to-tab stays at 0. Test in `codex_skins_test.lua`; bench `codex_chattabs` (real dock, 9 whispers).
Tests per group: `codex_ui_bars_test`, `codex_ui_unitframes_test`, `codex_ui_hud_test`, `codex_ui_windows_test`,
`codex_ui_damagemeter_test`, `codex_ui_cooldowns_test`, `codex_ui_loot_test` (loot roll part `lootroll`),
`codex_ui_menus_test`, `codex_ui_nameplates_test`, `codex_ui_raid_test`. Minimap shape `CodexDB.skins.minimapShape`
(round / square / header, nil = theme default; square sets the global `GetMinimapShape`). Opt-in parts (default off): `barpanels` (one panel per bar,
fitted to its shown buttons; Action bars > Look has the Edit Mode guide and the spacing check) and
`roundicons`. Part defaults live in `ns.SKIN_PARTS` (`default = false`), read through `ns.SkinPartWanted`.

`.pkgmeta` moves the subfolders out to their own addon folders in the release zip. For testing in game each
subfolder has its own junction in `_forever_/Interface/AddOns` (`Codex_Runestone` -> `Codex/Themes/Runestone`, ...; created 2026-11-17;
`Codex_Dusk` added 2026-11-19, `Codex_Obsidian` and `Codex_Onyx` 2026-11-22 (Dusk's structure in near-black, from the
preview artifact https://claude.ai/artifact/XiQ6Ax18bUzvJk5Krzxkb5; Inter from Codex_Dusk/Media), the user creates them: `New-Item -ItemType Junction -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Codex_Dusk" -Target "E:\Games\Wow\Addons\Codex\Themes\Dusk"`; the old `Codex_Dawn` junction can be deleted).
The user asked to be told whenever another part should get its own load-on-demand folder.

## Core files (load order = Codex.toc)

- `Tylesser.lua`: the shared Tylesser file (identical in every addon; feedback window, `T.Prefix`, `T.Outline`).
- `Core.lua`: `CodexDB` (account) / `CodexCharDB` (character) defaults, `ns.RegisterModule`, `ns.ModuleState`
  (`on`/`off`/`standalone`), `ns.On`/`ns.Fire` event bus, `ns.Money`, `ns.Age`, `ns.LoadAddOn`. Defines the one
  global, `TylesserCodex` (= `ns.API`), for the load-on-demand folders.
- `Theme.lua`: theme registry (`TylesserCodex.RegisterTheme(def)`, token format documented at the top),
  `ns.LoadTheme`, `ns.Theme()`, a plain fallback when the theme folder is missing. Themes change after a reload.
- `Widgets.lua`: `ns.UI` (= `TylesserCodex.UI`): Panel, Text, Heading, Inset, Divider, Button, CloseButton, Check,
  EditBox, NavButton, Tabs, List (pooled scrolling rows), ShowMenu. Build all Codex UI with these.
- `Window.lua`: `CodexWindow` (920x610; "Window size" scales it 70-140 %, the layout itself never changes): title
  bar, sidebar (the search box, then the pages of `ns.AREAS`: Home, Action bars, Rings, Unit frames, Buffs, Bags and
  items, Quests, Map, Chat, Info bars, Tooltips, Trade, a line, General, Look, Profiles; area ids `ringmenus` and
  `info` so they never clash with the module ids `rings` / `infobar`), pages built lazily
  (`ns.EnsurePage(id)` builds one hidden). `ns.ShowPage(id, widget)`: an area id, or a module / section id (its area
  opens at that section: unfolded, scrolled to, flashed; `window.current` = the area, `window.section` = the
  section), or an old name (`settings` -> General; `ns.ShowSettings("modules"/"look"/"interface"/"profiles")` ->
  Home / Look / General / Profiles, `ns.PAGE_ALIASES`); unknown -> Home. `ns.AREA_WIDTH` (672) is a whole page,
  `ns.PAGE_WIDTH` (640) what a module's page gets inside its section (module builders read it). `ns.ToggleWindow()`,
  reload banner (`ns.pendingReload` + "RELOAD_STATE").
- `Areas.lua` (2026-11-19, the user's "I need to go to multiple tabs to change all options on my action bar"; they
  picked this layout from options; **tabs since 2026-11-21**, the user of a page of folded sections: "this is not good
  design, can we make collapsible panels tabs? keep collapsible panels in tabs if they are related"): each page has a
  row of tabs (`ns.AREA_TABS`: { title, section ids }; unlisted sections get a tab of their own at the end; a page
  with one section has none), `page.tabs`, `page.tabOf[id]`, `page.tab`, `page.SelectTab(id, keepScroll)`; a section
  alone in its tab is `single` (open, no fold arrow, header click does nothing), related ones fold as before; the tab
  per page is kept in `CodexDB.areaTabs[area]` (by title, in Profiles' SKIP_TOP); `ns.FocusSection` (ShowPage, search)
  selects the section's tab first; `codex_areas_test` 4 checks every section is in one tab and every tab row fits.
  Within a tab the page is a scroll of **foldable sections**; a section's
  header has a drawn fold arrow (`UI.FoldArrow`, the smooth Media/FoldArrow.tga, never a letter), the name (never upper-cased), a tag
  and the feature's on/off **switch** (`UI.Switch`, a CheckButton); the body holds every option of that feature (no
  tabs, no sub-pages). Registry `ns.AddSection(area, { id, title, order, module | switch = { get, set, enabled },
  build(holder, width, section) -> { Height, Refresh }, height (fixed: pages whose lists fill their area) |
  estimate, refresh, show, notice -> text, buttonText, onClick, tag, folded, aliases, keywords })`. Modules declare
  their place in RegisterModule (`area`, `sectionOrder`, `sectionTitle`, `pageHeight`, `pageEstimate`, `folded`,
  `BuildSection`); every module gets its section from that (module switch, `ns.ModuleState` notices: standalone with
  "Use Codex's instead", switched on/off until a reload), its `BuildPage(module, holder)` builds the body
  (`ns.embedding` is set meanwhile: `UI.Heading` hides the page's own title, height 1), `ShowPage` runs when its page
  shows or the section opens. Body height: fixed `height`, else `Height()`, else a module page's own `UI.ScrollArea`
  body height, else the game's layout (`ns.MeasureExtent`: lowest shown descendant, a scroll frame's child counted,
  not the frame), else `estimate`; laid out on show and again next frame. Folded state `CodexDB.folded[id]` (never
  in a profile: Profiles' `SKIP_TOP`). `ns.FocusSection(id, widget)` unfolds, scrolls (the widget's `GetTop` next
  frame) and flashes (accent band, fades in 1.6 s). `ns.BuildAllSections()` builds every page and body hidden
  (search, `/codex debug ui`, tests). `ns.RefreshSections()` after any change (RELOAD_STATE too). A
  `UI.ScrollArea` with nothing to scroll hands the wheel to the scroll area round it (`UI.ForwardWheel`; Buffs'
  `ScrollBody` too).
- `Info.lua` (2026-11-24, the user's request after FlareUI's settings window): the info panel, a column right of the
  page (`ns.INFO_WIDTH` 262, set in Window.lua, which adds it and a 14 px gap to the window: 1196 wide; the pages
  keep `ns.AREA_WIDTH`). `ns.InfoHover(section, widget)` (section headers and switches, and every Button /
  CheckButton / EditBox / Slider / picker in a body, hooked once by `ns.InfoWatch` after the body is built),
  `ns.InfoForPage(page)` (ShowPage, SelectTab: the tab's first section), `ns.ShowInfo(subject)`, `ns.RefreshInfo()`.
  A section's words: `def.desc` (text or function), else its module's desc, its skins part's `ns.UI_PART_TEXT`, its
  small switch's desc; its preview: `def.preview(holder, width)`, else a part card's picture: inside the window
  `card.pictureInPanel` (SettingsUI.lua), the card is one column and the panel takes `card.picture` (sides one above
  the other, scaled to the panel). An option's name: `UI.Describe(widget, text | { title, text })`, `codexLabel`
  (Settings' LabelRow / PickerRow), a check's label, its row's one text, a button's text.
- `FontStyles.lua` / `FontStylesUI.lua` (2026-11-24, the user's "do both": FlareUI's per-text font rows for the
  tracker, then the same for every part): elements `ns.AddFontElement({ key, group, label, base, absolute })`
  (`ns.FONT_ELEMENTS`; groups `ns.FONT_GROUPS` quests / units / chat / info, each a "Fonts" section `fonts-<group>`,
  its own tab), style `CodexDB.fontStyles[key] = { font = ns.FONTS key, size, outline = none/thin/thick, shadow =
  none/soft/strong }` (left out = "Own"). Drawing code calls `ns.RestyleFont(fs, key)` (`TylesserCodex.RestyleFont`,
  Skins' `S.RestyleFont`) right after it set its font: the size scales by size / base (`absolute` = the chat: the
  size itself), never under 9; it keeps the drawing code's font in `fs.codexStyleBase` (no compounding, back on
  Reset) and guards against a SetFont hook on the same text (`codexRestyling`). `UI.FontRole(frame, headKey,
  bodyKey)`: UI.Font on any text inside restyles it (the quest windows). Changes fire "FONT_STYLE" (`ns.OnFontStyle`):
  the tracker (`QT.Restyle`), quest windows (`D.Refresh`), unit frames (`RefreshFrameStyle`), nameplates, personal
  bars (`R.Refresh`), chat windows / tabs and info bar slots draw again. Test `codex_fonts_test.lua`.
- `Search.lua`: the sidebar's search box. Index (built once, on the first search) from the widgets of every built
  section: page names, section names (+ `keywords`), shown font strings and button texts that are names (3-64
  characters, a letter, not ending in a full stop); skips `codexPicker` (picker / stepper values), `codexList` (list
  rows), `codexPicture` (sample texts in pictures), `codexNoSearch`, hidden rows. Every word must be in the label,
  its section, its page or the keywords; labels that start with the query come first. Results replace the page list
  (label + "Page > Section", 12 / 10 px); a click = `ns.ShowPage(section, widget)`. `ns.SearchOptions(query)`,
  `ns.SetSearch(text)`, `ns.OpenSearchResult(entry)`.
- `Home.lua` (a card per module in sidebar order; a click opens its section), `Settings.lua` (skins parts
  `ns.SKIN_PARTS` and their values: unit text formats, frame styles, minimap shape, `CodexDB.look`; theme previews;
  layout helpers `ns.UIStack` / `ns.UIWrapping` / `ns.UIWrapCheck` / `ns.UITextHeight` / `ns.UILabelRow`; the
  sections of Look (Theme, Fonts, Accent colour, Effects: `ns.lookSections`), General's "Codex window" (minimap
  button, window size), Tooltips' "Prices and stats in tooltips" (the auction / vendor / craft cost / stat change
  lines: the same settings as in those modules, through `A/P/S.SetOption`) and Profiles (Profiles, First-run setup)),
  `SettingsUI.lua` (one section per skins part on its page, `ns.PART_SECTIONS` = area / order / title / folded, id
  `part-<id>` (`ns.PartSectionId`; the areas "chat" and "tooltips" share names with parts); the switch is the
  part's, greyed with a "Restyle it" notice while the restyle is off; the body is `ns.BuildPartCard`
  (`ns.partCards[id]`): a plain description `ns.UI_PART_TEXT`, the part's own options and beside them (on top under
  560 px) a "Game default > Codex" picture (`ns.UI_PICTURES`, 303 px; game side drawn only with the game's own
  atlases/files, each atlas checked with `C_Texture.GetAtlasInfo`, grey stand-in when missing; Codex side from the
  theme's tokens; picture texts bound to the room from their anchor to the edge of what they hang on). The options:
  frame style + unit texts under Player, target, pet and focus, nameplate text, round icons + icon spacing under
  Buffs and debuffs look and round icons again under Cooldown manager (one setting, both kept in step), minimap
  shape, bar panels + the Edit Mode guide under Action bars > Look; `ns.UI_OPTION_PARTS` = parts shown as an option,
  not a section. General's "Restyle the game's interface" section holds the master switch),
  `Profiles.lua` (settings snapshots in `CodexDB.profiles`, per character or shared, export/import string
  `CDX1:<base64>:<crc>` with its own parser, never loadstring; data tables are never part of a profile),
  `Setup.lua` (5-step first-run window, `CodexDB.setupDone`, `/codex setup`, Profiles > First-run setup, own secure
  reload button),
  `Minimap.lua` (`CodexMinimapButton`, right-click quick menu), `Events.lua` (start-up, `/codex`, `/codex profile`).
- Look options (round 3, 2026-11-17): `ns.LookOption(key)` / `ns.ApplyLook()`; accent "class" swaps the accent
  tokens for the class colour in `ns.AccentTheme` (reload); shadows = `Media/Shadow.tga` (`branding/source/shadow.py`)
  behind panels via `UI.Shadow` / `S.Shadow`; strips = theme token `strip` via `UI.Strip` / `S.Strip`, never on
  NPC windows (neither the game's nor Codex's own, `Modules/Dialogue`). Tests `codex_look_test.lua`, `codex_setup_test.lua`. Floating text (skins part `floatingtext`,
  default on): `ns.ApplyFloatingTextFont` at the end of `ns.LoadTheme` (Codex's ADDON_LOADED, not the Skins folder:
  the game reads it when the world loads) sets the global `DAMAGE_TEXT_FONT` (the one allowed global write) and
  re-fonts `CombatTextFont` / `CombatTextFontOutline` (size and flags kept, again when Blizzard_CombatText loads)
  to theme token `font.damage` (Runestone Cinzel, Hearthwood IM Fell, Dusk/Dawn Inter SemiBold; Classic/Slate none =
  game's). Only while the restyle and the part are on; shows after a reload.
- **Dawn removed (2026-11-20, the user: "the worst view I have ever seen", then "remove dawn theme completely").**
  It was Dusk's light sister (`Themes/Dawn`, Codex_Dawn). A saved `CodexDB.theme = "dawn"` becomes "dusk" in
  `ns.SetupDB`. The light-theme machinery below (`light`, `inkPanel`, `ns.InkTheme`, `ns.GameColor`, `ns.Readable`,
  `UI.GameText` / `S.GameText`, the "Game interface on dark panels" option) is still in the code but idle: no theme
  has `light` or a non-empty `inkPanel`. Don't bring a light theme back unasked. The notes on Dawn below are history.
- **Bronze** (2026-11-24, `Themes/Bronze`, `Codex_Bronze`, the user's "a new calm theme" after comparing Codex
  with FlareUI): warm dark brown and bronze like the game's own frames, one thin line per box (no studs, double
  rings, bevels, strip caps), square, see-through panels (window 92 %, HUD 72 %), the game's Friz Quadrata never in
  capitals, gold only for titles / selected / focus. No media of its own. Contrast checked in `codex_look_test`.
  The user creates its junction for the game (`Codex_Bronze` -> `Codex/Themes/Bronze`).
- **Dusk** (2026-11-19, the user's friend liked the "Dusk" canvas `calm/project`):
  flat, see-through panels (94 / 95 %), one hairline, no studs / double rings / bevels, Inter (`Themes/Dusk/Media`,
  SIL OFL 1.1, `Inter-OFL.txt` = the v4.1 release's LICENSE.txt, unmodified, must ship; Dawn reads the fonts from
  `Codex_Dusk/Media`), headings semibold in normal case (`titlebar.upper = false`, `sectionCaps = false`), teal
  accent only for focus / selected / tracked / procs. Tokens added for them: in every theme file and the fallback `textShadow`, `sectionCaps`, `inkPanel`; optional
  (nil elsewhere) `round` (corner
  radii; nine pieces from `Media/Round.tga` + `RoundLine.tga`, `UI.RoundFill` / `UI.RoundLine`, used by UI.Panel,
  UI.Button, UI.Inset, UI.Picker, S.Plate("panel"), S.Button; a rounded plate keeps `plate.fill` as a see-through
  anchor, the pieces are in `plate.round` / `plate.lines`, `S.PlatePieces`), `select.mark` / `select.text`,
  `quality` (`ns.QualityColor`), `status` (unit frame / personal bar colours), `classTone` (`ns.ToneClass`), `light`. Line colours in Dusk/Dawn are opaque mixes (white/black 6-14 % over the window): several skins draw
  lines with alpha 1, a translucent token would turn into a bright line. Title bands start `S.BandInset` in so their
  square corners stay inside rounded windows. Minimap shape: both round.
  Round 2 (2026-11-19, the user's list): **rounded slots** (`round.slot` 6): `S.Slot` / ActionBars `SlotBox` draw
  rounded fill and ring and `S.RoundIcon` cuts the icon (plus hover / pushed / checked / flash art) with our mask and
  sets the cooldown swipe to `Media/RoundMask6`; Blizzard's own `IconMask` (Mainline ActionButtonTemplate, used on
  Forever) is still removed from the icon, nothing protected is touched. ItemButton (bag buttons, Codex's bag
  window) has its own `Mask` (common-iconmask, added to icon / normal / pushed in ItemButtonMixin:OnLoad): it comes
  off too (`S.Slot`, Bags `SlotLook`); left on under our nine-sliced mask the icons drew as specks on black (2026-11-19). Codex's bag window slots and the quest reward
  icons (`D.ItemIcon`) are rounded too. **Rounded bars** (`round.bar` 6, `round.plate` 3): `UI.RoundMask` = a
  MaskTexture with `Media/RoundMask<r>` (2/3/4/6) nine-sliced by `SetTextureSliceMargins` (TextureBase on Forever:
  Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation); bars only take it when it slices
  (`sliced = true`), `square = { top/bottom/left/right }` reaches past edges that stay square (health over power).
  Used by UnitFrames `Bar()` (`S.roundBars`, no black line then; cast bar icon + one rounded line), Nameplates health
  and cast bars (lines as RoundLine pieces), Raid cells (mask anchored to the whole cell), personal bars
  (`UI.SetMaskRadius` per row height). Rounded pieces take `SetColorTexture` (a quarter's is replaced by a tint), so
  they stand in for square line lists (`T.ColorLines`, `Paint`). **Nameplate colours:** `S.NameplateStatusColor(unit)`:
  theme `status` hostile / neutral / friendly / tapped from UnitReaction / UnitIsTapDenied (each value Readable-checked;
  unreadable = Blizzard's), friendly players keep the class colour; old themes untouched. **Money:** theme token
  `money` (Dusk #D9C48F, Dawn #64490F, Dawn's ink Dusk's gold): `ns.Money`, `P.ShortMoney`, the info bar's `I.Coins`
  (coin icons kept) write the amount in `ns.MoneyHex()` (`ns.InkTheme()`'s: Dawn's own gold by default, Dusk's gold
  with "Game interface on dark panels"), `ns.Readable` swaps it for the light theme's own on light panels. **Dawn retune** (the user: "too bright, more transparent and light, no white"):
  window #D5DBE2 at 82 %, raised #E6EAEF at 80 %, boxes #CBD2DA, band #CDD3DB, hairline black 10 %, no pure white;
  text colours darkened (muted #464E58, accent #1D5650, gold #64490F, good/bad/qualities) so every text token reads
  4.5:1 on its surface drawn over a mid-grey world #6E7378 (`ns.WORLD`, `ns.Blend`, `ns.Ground`; the look test blends
  too). Sidebar / `UI.ScrollArea` in rounded themes: 1 px track, 4 px rounded thumb (`codexTrack`, `codexThumb`).
- **The light-theme rule (Dawn; rewritten 2026-11-19 after the user's "dawn is not updating game UI": they chose
  "make the game interface light and darken the game's text colours on it"):** a light theme is light everywhere.
  `ns.InkTheme()` is `ns.Theme()` (so `S.Theme()` in Codex_Skins, the HUD modules, `UI.Ink` frames, Settings'
  "Codex" pictures and Setup's scene all draw Dawn's light tokens). Look option **"Game interface on dark panels"**
  (`CodexDB.look.inkHud`, off by default, Look > Effects, shown only when `ns.HasInkPanel()`: a theme with
  an inkPanel = Dawn; read at `ns.LoadTheme` into `ns.lookApplied.inkHud`, a change asks for a reload) brings the old
  dark HUD back: then `ns.InkTheme()` is the theme with its `inkPanel` keys swapped in (not light, nothing darkened)
  and Setup uses `THEME_PREVIEW[id].ink`. Dark themes: `ns.InkTheme()` is always `ns.Theme()`, nothing changes.
  Game text on light ground reads 4.5:1 on its surface blended over `ns.WORLD`, hue kept, no text shadow:
  `ns.GameColor(color, theme, ground)` (already readable stays; `ITEM_QUALITY_COLORS` -> the theme's `quality`; white /
  light greys -> `text`, mid greys -> `muted`; else `ns.ReadableColor`), `ns.Readable(text, theme, ground)` (|cff codes
  via GameColor, `|cnIQn:`, other `|cn<GLOBAL_COLOR>:`), `ns.Ground(theme, "hud" / "slot")`, `ns.Plain(v)` (not
  secret). `UI.GameText(fs, opts)` / `S.GameText(fs, kind)`: post-hooks (hooksecurefunc) on a font string's
  SetTextColor / SetVertexColor / SetText / SetFormattedText / SetFontObject (edit boxes: colour only, their text is
  never written), repaint guarded against recursion, never on compositor regions, secret colours / texts left as they
  are. `UI.ReadableNow` = one pass without hooks. Where: tooltip lines after Show / AddLine / AddDoubleLine / SetText
  (the game fills lines in C), chat lines through `frame:AddOnDisplayRefreshedCallback` (ScrollingMessageFrame,
  forever branch: the secure mixin's addon hook, runs via secureexecuterange after each RefreshDisplay; history
  untouched; AddMessage never replaced), the chat edit box header and typed text, tracker titles / objectives,
  quest log and quest texts (`Lighten`), loot roll names, unit frame names and levels (`ReadableTextColor`), the
  nameplate level on its light disc, Blizzard menu entries (compositor: a coloured font object of ours through
  SetFontObject only), `S.GameFonts()` (the game's non-outline `GameFont*` objects, windows part) and every font
  string of a skinned window when it opens (Windows.lua `GameTexts`), the info bar tooltip's game colours (`ColorOf`).
  Left light on purpose: texts over the world (nameplate names, also the target's; floating combat text, timers /
  counts on icons, Highlight's labels) and outlined white numbers on bars (they read on fill and track); raid cell
  names and damage meter rows stay Blizzard's (on the coloured fill / the meter's dark track). `S.TextShadow` (the
  theme's on light ground, else the given shadow) replaces hard-coded black shadows on light surfaces. New UI: never
  hard-code white text or `{ 0, 0, 0, 0.9 }` shadows on Codex panels; use tokens, and game colours through
  `ns.GameColor`.
- **Calmer class colours (Dusk / Dawn, 2026-11-19, the user's "nameplate colors are too bright"):** theme token
  `classTone = { mix = 0.33, toward = <dark track>, desaturate = 0.2 }` (optional, nil = full strength in the older
  themes), `ns.ToneClass(color, theme)`. Applied to Codex unit frames' class / reaction health (`Tone` in
  HealthColors; names keep the full colour), friendly players on nameplates (instead of x0.85), Settings' previews,
  and from outside on Blizzard-coloured bars: `S.ToneOverlay(bar)`, a see-through texture of ours in `toward` at `mix`
  over the fill (raid / party cells, damage meter rows; DamageMeterEntryMixin:SetStatusBarColor keeps
  `self.statusBarColor`, so its setters are never called). An overlay mixes but can't desaturate.

## Modules

`Modules/<Name>/<Name>.xml` lists the module's files (Codex.toc includes the xml). A module registers with
`ns.RegisterModule({ id, name, icon, desc, standalone, default, order, Enable, BuildPage, ShowPage, Status,
commands, area, sectionOrder, sectionTitle, pageHeight, pageEstimate, folded, BuildSection })` (the last ones place
its section, Areas.lua). Pages that had tabs are sections now: Buffs = Buff tracker / Party buff buttons
(`buffs-party`) / Dispel buttons (`buffs-dispel`; `ns.buffs.OpenOptions(tab)` opens them), Auction = Auction house
(options + full scan) / Shopping lists (`auction-lists`) / Auction prices (`auction-prices`). A note beside a check's
label is bound to the page's right edge and wraps (it ran past the window before). `Enable` runs once at PLAYER_LOGIN only when the module is on; until then the module must not
register events, hook anything or create frames. `standalone` = the old Tylesser addon of the same feature:
while it is loaded Codex leaves the feature to it (the player can force Codex's copy).

- `Modules/Buffs`: Buff Tracker ported in (standalone = `BuffTracker`). Conditions.lua / ConditionsOptions.lua
  (2026-11-20): where and when the row shows (places, group, combat; per row or per buff), the same body as
  Buff Tracker's (see its CLAUDE.md); the window is on Codex widgets (`CodexBuffConditions`).
- `Modules/Auction`: Codex's own auction house engine (scans, price database, tooltips, shopping lists). No
  dependency on Auctionator/TSM/Auctioneer. Forever uses the modern `C_AuctionHouse` API. "From Auctionator" (2026-11-21,
  `A.ImportAuctionator`): reads only the data global `AUCTIONATOR_SHOPPING_LISTS` (`{ name, items, isTemporary }`,
  an item = search string, first field before ";" is the term, quoted = exact); temporary lists skipped, same-name
  lists get only missing terms; the button beside "Lists" shows only while there is something to import.
  Price history (2026-11-25, the user's request; data format at the top of Data.lua): per day `h` low, `x` highest
  low (only when higher), `q` most up; `days` from `A.DAY_CHOICES` (7-365), days past `A.DAILY` (90) fold into weeks
  (`w` / `wx` / `wq`, week = floor(day / 7)) in `Trim`. `A.GetHistory` (entries with `high`, `count`, `week`; also
  `TylesserCodex.GetAuctionHistory`), `A.HistorySince`, `A.HistoryStats`, `A.WeekAverage`. History.lua: the window
  `CodexPriceHistory` (`A.ShowHistory(item)`: prices-page row click, Shift-click on a panel result,
  `/codex history <link|ID|name>`), chart from pooled Lines (guarded: `CreateLine`), dots, low-high spans, supply
  bars, hover frames per entry. Tooltip.lua `A.AddHistoryLines` (option `tooltipHistory`, also in Tooltips' list).
  Bench scenario `codex_history` draws it (the renderer leaves out Line objects).
  **Prices are per item** (2026-11-26, the user saw 1g 99s 99c x5 counted as 40s each): `GetReplicateItemInfo`'s
  `buyoutPrice` and `GetItemSearchResultInfo`'s `buyoutAmount` are ONE item's price, `count`/`quantity` how many
  (Forever shows identical auctions as one row; its sell frame charges quantity x price, `GetTotalPrice` in
  Blizzard_AuctionHouseItemSellFrame, and copies `buyoutAmount` into the per-item price box). Never divide them.
  `A.RepairPerItem` (Enable, once per realm, `realm.perItem`) dropped the below list and the last scan's
  divided prices; new realms start with `perItem = true`.
  Below vendor (Below.lua, 2026-11-26, the user's request): the full scan's `A.NoteBelow` keeps auctions under
  `A.SellPrice` (GetItemInfo's 11th value; gear by its link) per item in `realm.below = { t, items = { [itemID] = { l, s,
  u, p } } }` (`u` nil = seen while browsing, not counted); items whose data loads late are settled at the end and
  every 3 s (5 tries). Commodity / item searches replace an item's entry (`A.SearchBelow`), browse results add or drop
  it (`A.BrowseBelow`; gear never dropped by one row). Panel mode "vendor" (`panel.mode`, button "Below vendor",
  a list click goes back to "shop"): `A.AllBelow()` = the scan list plus every saved `realm.items[key].m` under the vendor price (`seen = rec.t`, no `u`; sell prices cached per session, unloaded items asked once + a redraw after 2 s; the panel also redraws on PRICES_UPDATED in vendor mode), `A.BelowRows()` (by `A.BelowSort()`, `db.belowSort` "total" = `p` or "each" = `s - l`, then the other one; button `panel.sort` in the Stop button's place; the row shows `+profit` instead of a price, `result.itemKey` from
  `C_AuctionHouse.MakeItemKey`; gear has no result and opens through the search box), `A.BelowText()`. Tests at
  `codex_auction_test` 9b.
  Buy button (Buy.lua, 2026-11-27, the user's request; before it Codex never bought anything): `panel.buy` +
  `panel.buyText` under the list in vendor mode (the list's bottom moves up, `PlaceResults`). `A.PrepareBuy()` (from
  RefreshPanel) searches the first non-gear, non-skipped row with `SendSearchQuery(itemKey, {Buyout, Bid}, false)`
  like Blizzard's buy views; Scan.lua's result handlers call `A.BuyCommodityResults` / `A.BuyItemResults` after the
  list update. Offer: commodities = every unit under the vendor price minus `numOwnerItems`, capped by GetMoney;
  items = the cheapest `buyoutAmount` under it, not `containsOwnerItem`. `panel.stacks` toggles `db.buyStacks`
  (`A.BuyStacksOnly`): Target skips rows whose GetItemKeyInfo `isCommodity` (else GetItemInfo stack size > 1) is false, and
  an item-kind search answer is skipped. Nothing to buy = `buy.skip[key]` until the
  AH closes. The click (`A.BuyNext`, a hardware event: forever docs mark `PlaceBid` and `StartCommoditiesPurchase`
  HasRestrictions) calls `StartCommoditiesPurchase(itemID, qty, unit)` as AuctionHouseFrameMixin does, then on
  COMMODITY_PRICE_UPDATED(unit, total) confirms only while `total < sell * qty` and affordable (else
  CancelCommoditiesPurchase); items `PlaceBid(auctionID, buyoutAmount)` like BUYOUT_AUCTION's OnAccept, done on
  AUCTION_HOUSE_PURCHASE_COMPLETED(auctionID) / AUCTION_HOUSE_SHOW_ERROR. 10 s timeouts. Never loop purchases
  without a click. Tests at `codex_auction_test` 9d. Not yet confirmed in game (ConfirmCommoditiesPurchase from an
  event: no restriction in the docs).
- `Modules/Bags`: Codex's bag window (standalone = `Baganator`; never read or copy Baganator/Syndicator, they are
  All Rights Reserved). Data per character in `CodexDB.bags.characters["Realm-Name"]` (slots as
  `{ link, count, quality }`, bank from the last visit, equipped, money). Own bags are
  `ContainerFrameItemButtonTemplate` buttons under holder frames whose ID is the bag; made/placed/shown only
  out of combat (in combat they are only refilled). The game's bag windows still open and close as normal
  but are parked off screen with alpha 0 (Blizzard.lua); the Codex window follows them. Forever's
  `Enum.BagIndex` (from the `forever` branch of Gethe/wow-ui-source): Characterbanktab -2 (bank bag slots),
  Keyring -1, ReagentBag 5, CharacterBankTab_1..9 = 6..14, AccountBankTab_1..9 = 15..23; no `Bank` index.
  Layout pieces are shared (Window.lua `B.NewLiveSet`, `B.PlaceLive`, `B.PlaceBlocks`, `B.Pack`, `B.TitleBar`,
  `B.SearchBox`, `B.Footer`, `B.NewWindow`). Bank.lua: `CodexBankFrame` at BANKFRAME_OPENED / BankFrame OnShow
  (option `bankWindow`), its own live set (holders = `C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)`),
  categories or one section per tab, `bankColumns`, sort `C_Container.SortBank(bankType)`. BankFrame must stay
  **shown** (parked with `B.ParkPanel`, points kept, re-parked after `UpdateUIPanelPositions`): the game's
  right-click asks `BankFrame:GetActiveBankType()`; buying tabs / bank bags stays in the game's window (header
  button unparks it). Opened in combat with buttons missing: the game's window that visit. Closing ours =
  `HideUIPanel(BankFrame)` (its OnHide calls `C_Bank.CloseBankFrame`). Deposit.lua: `C_Bank.AutoDepositItemsIntoBank`
  when `DoesBankTypeSupportAutoDeposit(Character)`, else UseContainerItem(bag, slot, nil, bankType) 6 per 0.2 s
  (crafting reagent flag, class 7, or the reagent bag; never quest/gear/ammo/keys), stops on close/combat.
  GuildBank.lua: `CodexGuildBankFrame` (option `guildBankWindow`; Blizzard_GuildBankUI loads on Forever, the
  Mainline one), plain buttons (guild bank API isn't protected), the game's popups for money, Log = the game's
  window unparked. Tests in `codex_bags_test.lua` sections 11-13.
- `Modules/BarFade`: per-bar visibility (always / mouse-over / combat / never), alpha only, nothing runs while every bar is "Always".
- `Modules/QuestKeys`: Space presses Complete / Continue / Accept in quest windows (override binding, never in combat).
  Only for the game's own windows: while Codex's quest windows show, `QK.Target` returns nil (state "codex") and
  `Modules/Dialogue/Keys.lua` does Space with this module's on/off and `pickQuests` (`QK.Choose` is shared).
  Tests that check the game's windows load with `dialogue = false`.
- `Modules/Dialogue` ("Quest windows", default on; standalone = `DialogueUI`): **Codex draws the NPC windows** (the
  user's decision 2026-11-18, reversing the old rule "leave QuestFrame/GossipFrame alone"): gossip, greeting,
  quest offer / progress / reward, boards R4-Gossip / R4-Quest / R4-Options. Styles `CodexDB.dialogue.style`:
  "a" Codex window (default in every theme, `CodexDialogueFrame`, draggable, height = content), "b" subtitle bar
  (`CodexDialogueBar` + `CodexDialogueSide`, text in parts), "c" book page (`CodexDialogueBook`, ink palette). All
  three are frames of ours, chosen over restyling in place so one data model (Data.lua `D.Read(kind)`), one key
  handler and one layout (Window.lua `D.NewContent`: blocks stacked with measured heights, laid out again next frame)
  serve all styles. QuestFrame / GossipFrame stay **shown** but parked (Blizzard.lua: off screen, alpha 0, points
  kept and put back on hide, re-parked after `UpdateUIPanelPositions`), so the talk, Escape and the game's popups
  keep working; closing ours = `CloseQuest` / `C_GossipInfo.CloseGossip`; if drawing fails (`D.GiveBack`) or an
  auto action does nothing for a second, the game's window / ours comes back: never an invisible window.
  Actions mirror Blizzard's (QuestFrame.lua): PvP accept and costly hand-in go through the game's StaticPopups
  (`CONFIRM_ACCEPT_PVP_QUEST`, `CONFIRM_COMPLETE_EXPENSIVE_QUEST` with `QuestInfoFrame.itemChoice` set first),
  Decline / Escape-back on a quest picked from a list = `DeclineQuest()` (the server shows the list again).
  Keys.lua: one keyboard frame (`CodexDialogueKeys`, EnableKeyboard + SetPropagateKeyboardInput per key, both only
  out of combat; PLAYER_REGEN_DISABLED = propagate on, keyboard off): 1-9 rows (keycaps), Space, Tab rewards,
  Escape back. Auto.lua (off by default; Shift talks normally; a quest auto-picked once is skipped for 60 s so
  declining never loops): auto accept (not repeatable/grey/PvP), auto hand-in (not repeatable, gold, BG marks
  20558-20560, currencies, several rewards), the only service (Banker/Taxi/Trainer/Vendor gossip icons, never the
  innkeeper). Fade (B/C, `fade`): every shown UIParent child but ours, tooltips, popups and DIALOG+ strata to alpha 0
  with our own OnUpdate (never UIFrameFade, never Hide), back 0.3 s after the talk (no flash between pages) or at
  once when a fight starts. "Write the text in" = CVar `instantQuestText` (our own SetAlphaGradient reveal at the
  game's 70 cps; Space finishes it). Reputation: `RepData.lua` (generated, `tools/data/quest_rep.py`, see
  that folder's README), names from `C_Reputation.GetFactionDataByID` first. Theme tokens
  `dialogue = { npcRing, rule, primary, key, rowHover, selLine, sub, page, ink, ... }` (Theme.lua docs, every theme
  file, fallback `ns.FALLBACK_THEME`). Stat Delta lines/arrows via `ns.statdelta.BuildComparisons` / `SetArrow`.
  Left out on purpose: the board's drop cap on the book page (game text can't flow round a letter) and the camera
  turn (style C). Page.lua (fixed 2026-11-19, "texts are colliding"): scroll area, items stacked by measured
  heights (`D.LayoutPage`, record in `D.pageView.placed`), two columns 30 px apart (one below 620 px, style cards one
  under the other below 420), every text bound to its column, notes on their own line under their control, window
  size as a picker. Test `codex_dialogue_test.lua` (its own delayed timers: `Advance(s)`; page overlap / width checks).
- `Modules/StatDelta`: Stat Delta ported in (standalone = `StatDelta`; its settings are copied once when forced).
  Tooltip block only while Shift is held, post call added one frame after Enable so it sits below the other
  modules' lines. Settings `CodexDB.statdelta`, score preset/weights per character `CodexCharDB.statdelta`.
  Arrows: Blizzard bags, quest rewards, Baganator; Codex's bag window can call `ns.statdelta.SetArrow(button, link)`.
  Forever talents that turn one stat into another (Mental Dexterity...; 2026-11-27, StatDelta issue #2):
  `TALENTS` in Stats.lua, the same block as StatDelta's Stats.lua (see its CLAUDE.md for the C_Traits walk).
  Test `codex_statdelta_test.lua`; tests that count hooks/events/post calls load with `statdelta = false`.
- `Modules/Vendor`: sells junk (`C_Container.UseContainerItem`, 6 per 0.2 s, slot re-read before each use, one more
  pass for refused items, stops on close/combat) and repairs (guild funds first, rest own gold) at MERCHANT_SHOW;
  Shift skips; leaves a part to Leatrix Plus when `LeaPlusDB.AutoSellJunk`/`AutoRepairGear` == "On". Test `codex_vendor_test.lua`.
- `Modules/QoL`: a list of toggles in `CodexDB.qol` (`Q.AddToggle({ key, name, desc, default, Enable, Elsewhere, Changed, options })`,
  one file per toggle; each toggle is a section of its own on its page (`Q.SECTIONS`: proc glow and spell ranks on
  Action bars, faster loot on Bags and items, quest / gathering tooltips on Tooltips, reveal / zone levels / map
  extras on Map; id `qol-<key>`, the toggle's key opens it; `Q.BuildToggle`, rows in `Q.view.rows`,
  `Q.RowOf(key)`; switching one on while the module is off switches the module on), the module's own section in
  General holds the switch for all of them and where each one lives; options `kind` "check" (default) / "choice" (picker, `choices` with `{ title = }` headings,
  optional `button` and `preview(holder)` beside it) / "stepper" (`values`) / "button" (`Click`, nothing saved) /
  "custom" (`Build`, `Refresh`); `Disabled()` greys an option with a reason; the page scrolls). Faster loot (Loot.lua): LootSlot every slot at LOOT_READY when auto-loot applies; leaves locked, master-loot,
  group BoP-green and no-bag-space slots; stops on LOOT_BIND_CONFIRM; idle while FasterLoot or `LeaPlusDB.FasterLooting`
  == "On". Quest info in tooltips (Quests.lua): no quest DB; objective texts of the quest log indexed by lower-case
  name (`ns.qol.QuestIndex()`, shared; rebuilt lazily after QUEST_LOG_UPDATE), lines added at the end of Unit/Item
  tooltips, skipped when the game's data has quest line types or the name is secret. Test `codex_qol_test.lua`;
  tests that count tooltip post calls (or hooks) load with `qol = false`. A toggle may have `Changed(on)` (run by
  `Q.Set`): Gather/Zones hook nothing while off and hook when switched on.
  Gathering skill in tooltips (Gather.lua): node requirements from `ns.GATHER_SKILL` (root `Gathering.lua`, loaded
  after Core; Highlight's `H.HERBS` is built from it), ranks via `Q.gather.Rank` (GetProfessions, skill-line
  fallback, cached until SKILL_LINES_CHANGED / CHAT_MSG_SKILL); a plain line on Object tooltips (post call), and
  " (175)" after each node name in the minimap blip text (post call MinimapMouseover = 21 plus a
  `hooksecurefunc(GameTooltip, "SetMinimapMouseover")` fallback; a tagged name no longer matches, so never twice).
  Test `codex_gather_test.lua`. Zone levels on the world map (Zones.lua): `ns.ZONE_LEVELS` / `ns.GATHER_ZONES`
  (uiMapIDs; node lists from `tools/data/gather_zones.py`, level ranges from `tools/data/zone_levels.py`: Forever's
  own group finder ranges since 2026-11-22, new zones included); our own child frame + OnUpdate
  on the AreaLabelDataProvider's label (found in `WorldMapFrame.dataProviders`), nothing of Blizzard's hooked;
  idle while Leatrix Maps has ShowZoneLevels on. Test `codex_zones_test.lua`.
  Reveal unexplored areas (Reveal.lua, option `revealTint` via the toggle's `options` list, shown under it on the page): our own
  data provider on WorldMapFrame / BattlefieldMapFrame (removed when off) draws the unexplored pieces of `ns.MAP_REVEAL`
  (RevealData.lua, by UiMapArtID, generated by `tools/data/map_reveal.py` from Forever's DB2 tables on wago.tools) on a
  frame one level under Blizzard's exploration pin, 256 px tiles as the game cuts them; idle while OpenMap's world map
  (unexplored not "hide"), `LeaMapsDB.RevealMap` == "On" or Mapster's FogClear reveals. Test `codex_reveal_test.lua`.
  Dungeons and town services on the map (MapExtras.lua, `mapExtras`, 2026-11-19): our own data provider on
  WorldMapFrame only (never FlightMapFrame / BattlefieldMapFrame; removed when off), pins = frames of ours on the
  canvas (holder + pin scaled 1/canvas scale, spread when overlapping), hover only (`SetMouseClickEnabled(false)`,
  no click scripts), no new frames in combat (`host.waiting`, redrawn at PLAYER_REGEN_ENABLED). Levels: zone maps at
  `GetValidFrameLevel("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")` (over map art / explored areas, under flight points,
  area POIs and quest pins), continents canvas + 58 (Codex's QuestPins overlay is canvas + 60). Dungeons on zone and
  continent maps (`C_Map.GetMapRectOnMap`; instances at one spot merged into one pin, wings listed), services on
  zone maps only, only `spot.faction` B or the player's. Groups `CodexDB.qol.mapExtrasShow` (custom grid option,
  `M.GROUPS` defaults: dungeons, inns, flight, banks, auction, mail on; classTrainers, profTrainers, vendors,
  repair, stable, others off), pickers `mapExtrasClasses` mine/all, `mapExtrasProfs` all/mine (skill lines),
  custom note line. Filter button: our own (MapIcons funnel) left of `WorldMapFrame.WorldMapTrackingOptionsButton`,
  `UI.ShowMenu`. Idle per group: game (CVar `showDungeonEntrancesOnMap` + `C_EncounterJournal.GetDungeonEntrancesForMap`;
  `C_TaxiMap.ShouldMapShowTaxiNodes` + nodes), Leatrix Maps (`ShowPointsOfInterest` + `ShowDungeonIcons` /
  `ShowFlightPoints` / `ShowSpiritHealers`), OpenMap (`OpenMapDB.worldmap` `icons` / `flight` / `townsfolk[kind]`).
  Forever facts (forever branch): DungeonEntranceDataProvider is added but Camelot hides its filter and Forever has
  no JournalInstance tables (wago.tools), so it shows nothing; the world map tracking menu has only quest filters;
  the minimap tracking is minimap only. Data `MapExtrasData.lua` (`ns.MAP_INSTANCES`, `ns.MAP_SERVICES` strings
  parsed per map, `ns.MAP_NPC_NAMES`) from `tools/data/map_pois.py`; art `Modules/QoL/Media/MapIcons.tga`
  (`branding/source/map-art.py`). Test `codex_mapextras_test.lua`; the windows test counts its provider apart.
  Glow on proc abilities (ProcGlow.lua, `procGlow`): reactive spells `P.REACTIVE` (IDs per rank + names, the client's
  name from the first ID) lit while `C_ActionBar.IsUsableAction(button.action)` is true; buff procs `P.AURAS` (Shadow
  Trance, Clearcasting per class) from the player's buffs. Buttons ActionButton / MultiBar*Button 1-12, re-scanned a
  frame after slot / page / bonus bar events. Skipped while the game's own alert is on (IsSpellOverlayed or
  `ActionButtonSpellAlertManager:HasAlert`). The glow is our frame on the button (`P.MakeGlow(button, style, round)`),
  style `procGlowStyle` (`P.STYLES`: auto = alert with the restyle off / border with it on; alert =
  `ActionButtonSpellAlertTemplate`, border, sparkles = `AutoCastOverlayTemplate` (Forever's pet autocast ants), else
  our dots on an OnUpdate, soft = halo tga, flash = additive layer, ring = a double square line); square in the four
  older looks (action buttons are square there, "Round icons" doesn't round them; decided 2026-11-18). Rounded
  themes (round.slot, with the action bars restyled: `P.Rounded()`) use keys "<style>:round" (`P.Wanted`): border /
  ring = 1-3 rounded lines per thickness (`ShowSets`), sparkles = always our dots on a rounded path
  (`P.RoundedPoint`), flash = masked; soft and the alert stay as they are (2026-11-19). Alert falls back to border when its template is missing. `procGlowColor` (`P.COLORS`, class via C_ClassColor), `procGlowSpeed` / `procGlowThickness`
  (stepper options); colour and speed don't apply to the alert, thickness only to border/ring (`Disabled()` hints).
  Changes repaint lit glows and the page preview at once (`P.Repaint`). Sounds: `procSound` (off), `procSoundKit`
  (`P.SOUNDS` = 14 SOUNDKIT names checked against Forever's file + IDs, grouped soft/loud), `procSoundCombat`,
  `procSoundMaster`, `procSoundEach` + `procSoundFor[name]` (per proc: ability or buff name; custom page list);
  once per proc going lit, `P.SOUND_GAP` 1.5 s apart. Cooldown manager (option `procGlowCDM`, default on):
  Essential / Utility / BuffIcon viewers' pooled items (`itemFramePool:EnumerateActive`), spell = `C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)` overrideSpellID or spellID (read only),
  usable = `C_Spell.IsSpellUsable`; post hooks on OnAcquireItemFrame / RefreshLayout / RefreshData re-scan (only
  while the option is on: no hooks before); the glow anchors to `item.Icon` (`P.anchors`). Blizzard's items show
  the game's own alert themselves (RefreshOverlayGlow -> ActionButtonSpellAlertManager:ShowAlert, a square child
  frame `item.SpellActivationAlert` 1.4x the item). Option `procGlowCDMGame` (default on, 2026-11-19: the square
  alert doesn't fit the round / rounded icons): every item is watched (unlisted spells as `entry.game`, lit only
  while the game lights them), a game-lit item gets our glow and the alert frame's alpha 0 (post hook on the
  manager's ShowAlert / HideAlert; alpha only, `activeAlerts` never written, the frame never shown / hidden), alpha 1
  again when the alert ends, the option goes off or the glow stops. Off: skipped like buttons. `/codex procglow`
  (`P.Report`) prints per item: spell, listed, usable, game alert, watched, glow. Shape `P.CDMShape()`: ":circle"
  with the cooldowns restyle + `roundicons` (circle variants: GlowRing1-3, Buffs' Ring.tga, GlowRound, Circle,
  dots on a circle; alert -> round border), ":round" with a rounded theme's slot radius, else square. Tests
  `codex_procglow_test.lua`, `codex_procglow_styles_test.lua`, `codex_procglow_cdm_test.lua`;
  tests counting UNIT_AURA frames load with `qol = false`. Art beside your character (ProcArt.lua, `P.art`, options
  `procArt` default on, `procArtLook` game / icon / arc, `procArtSize`, `procArtAlpha`, "Show the art" = `A.Test()`, 3 s):
  Forever has Blizzard_FrameXML/SpellActivationOverlay (SPELL_ACTIVATION_OVERLAY_SHOW with a FileDataID) but its
  spell data sends that for next to nothing, so Codex draws the art for every lit proc: Codex's lit keys from
  `P.Update` (`order`), then the spells the game lights (GLOW_SHOW / _HIDE spell IDs in `A.gameLit`, in the order
  they lit; IsSpellOverlayed false drops one); spells the game's own frame shows (`A.gameArt`) are skipped. Art per
  name `P.ART` -> `A.FILES` (FileDataIDs of textures/spellactivationoverlays/*.blp; 128x256 files go left + right,
  the right mirrored, 256x128 above; sizes read from the BLP headers, which wago.tools serves at
  `/api/casc/<fileDataID>?download`), else Codex's `Modules/QoL/Media/ProcSide.tga` arc (glow-art.py) tinted in the glow colour,
  ADD blend. Icon look (and "game"'s fallback before the bare arc): `A.IconFor(name, id)` (the game-lit spell ID,
  else the proc glow's aura / reactive IDs, else the name; `C_Spell.GetSpellTexture`, secret = none) three times
  per side on the arc (`A.SPOTS` in the 128x256 file: y, size, alpha; x = just inside the arc's circle round
  (230, 128) r 190), BORDER layer under the arc, `Modules/QoL/Media/ProcIconMask.tga` (soft disc, glow-art.py) as a plain
  mask (never nine-sliced), right side mirrored with tex coords. A stretched icon in a crescent mask was tried
  first and was unreadable. Geometry and timings as the game's frame (204.8 box at the centre, 0.8 x 128x256, 0.2 s in, 1.08
  pulse per 0.5 s, 0.1 s out); several procs share the places by count (2026-11-22, the user's request; replaced the 2-second rotation): one = both sides, two = left / right, three = + top, four = + bottom (`A.MAX` 4, `A.Corners` turns side art a quarter for top / bottom). ManifestInterfaceData doesn't
  list the overlay art (not even MoP Classic's), and wago.tools' file search ignores the build, so whether Forever
  ships a file can't be read there: the "arc" look is the way out if the game's art doesn't show. Test
  `codex_procart_test.lua`. Spell ranks (Ranks.lua, `spellRanks`): on LEARNED_SPELL_IN_SKILL_LINE (+ SPELLS_CHANGED or
  a 1 s timer) the learned names' slots with the top rank on the bars get the spellbook's highest rank
  (`C_Spell.PickupSpell` + `C_ActionBar.PutActionInSlot` + ClearCursor), out of combat and with an empty cursor only;
  `CodexCharDB.ranks.upgraded` / `.pinned` (slot the player put a lower rank back on). "Update now" = `Q.ranks.UpdateNow()`.
  Test `codex_ranks_test.lua`. Future spells in the spellbook (FutureSpells.lua, `futureSpells`, `Q.future`, default
  on, section on Action bars): **Forever's spellbook and talents are separate windows** (Camelot
  `PlayerSpellsFrameMixin:IsTabSystemAvailable()` returns false: the bottom tab row is never shown; a first try put
  our tab there and its page showed over the talents, 2026-11-19). The book is `PlayerSpellsFrame.SpellBookFrame`;
  its school tabs are icon tabs in `.CategoryTabSystem` (TabSystemTemplate layout frame at TOPLEFT 70,-26),
  removed and made again by Camelot's `CreateCategoryMixins` on every `UpdateAllSpellData` (each show and
  SPELLS_CHANGED), which also calls the book's own SetTab. Our tab: a button of our own on
  TabSystemButtonArtTemplate, child of the book, TOPLEFT to the tab row's TOPRIGHT (+1), 44x32, `isTabOnTop` +
  HandleRotation, the square look set up by hand (`SquareLook`): **never `SetSquareMode`**, it writes the tab file's
  local `TabSideExtraSpacing`, which Blizzard's tab Init reads inside UpdateAllSpellData (taint would reach the
  book's spell buttons). The page is a Codex panel in the book over `PagedSpellsFrame` (frame level book + 400).
  Hidden by a post hook on the tab row's SetTab (only a click / the gamepad calls it, not the book's refresh),
  `SelectNextTab`, `EnableSearchResultsMode`, OnMouseDown hooks on the school tabs and the book's OnHide; a post hook
  on `ResizeSearchBox` narrows the search box by our tab's overlap (`F.FitSearch`). Restyled windows:
  Skins/Windows.lua's school tab look, through the shared API (`TylesserCodex.SchoolTabLook`, set by Codex_Skins;
  `TylesserCodex.FutureSpellsTab()` lets the skin style our tab when it loads first). **Codex_Skins is its own
  addon with its own `ns`: core code never sees `ns.S`**; the first version called `ns.S.SchoolTabLook`, which never
  ran, and the tab kept Blizzard's orange frame next to the ringed school tabs (2026-11-19). Spells: `ns.CLASS_SPELLS[class]` (ClassSpellsData.lua,
  generated by `tools/data/class_spells.py` from Forever's DB2 tables: `{ spellID, level, rank, talent, raceMask }`),
  names / icons / rank text from C_Spell; race mask against `UnitRace`'s ID; `talent = 1` rows (a talent's higher
  ranks, and spells the tables tie to nothing: Voice of Truth) only when a spell of that name is in the book; a rank
  at or under the highest known rank of that name counts as known, a spell without ranks is known by its name (two
  Summon Warhorse spells, one per race). **Class mounts are in the mount journal, not the spellbook**: collected
  mounts (C_MountJournal.GetMountIDs / GetMountInfoByID, 11th return isCollected; GetMountFromSpell by ID) count as
  known (the first name fix only looked in the book and Summon Warhorse still showed, 2026-11-19). The first table listed talents and runes as trainer spells (the user's
  Retribution paladin, 2026-11-19): Forever's talents are trait trees (TraitDefinition via SkillLineXTraitTree),
  not the Talent table; runes come from the "Engrave ..." spells' descriptions. Prices: none on the
  client (no Trainer DB2 on wago.tools); at a class trainer (C_Trainer.GetTrainerType() == Enum.TrainerType.General)
  GetNumTrainerServices / GetTrainerServiceInfo (name, type, icon, level, rank) / GetTrainerServiceCost and the
  spell ID from `C_TooltipInfo.GetTrainerService(i).id`, read on TRAINER_SHOW (a frame later) with the
  "unavailable" filter switched on (SetTrainerServiceTypeFilter) and off again a frame later when it was off, and
  on TRAINER_UPDATE; kept in `CodexDB.trainerSpells[class]` (`{ seen, spells = { ["id:<spellID>"] = { name, rank,
  level, cost, icon, id } } }`, in Profiles' SKIP_TOP: data, not a setting). Merge (`F.List`): the trainer's list,
  the spellbook's FutureSpell items, then the game's data (all of it before a visit, after one only above the
  trainer's highest level). Known = IsPlayerSpell / IsSpellKnown / C_SpellBook.IsSpellKnown by ID, else name + rank
  in the book. Test `codex_futurespells_test.lua`.
  **2026-11-21 round (the user's "DO ALL" of the suggestion list), test `codex_qol_extras_test.lua`:** Numbers on
  cooldowns (CooldownNumbers.lua, `cooldownNumbers`, default off): CVar `countdownForCooldowns` (forever
  Blizzard_SettingsDefinitions_Frame/ActionBars.lua) to "1", the player's value in `cooldownNumbersBefore`, given back
  when off; queued to PLAYER_REGEN_ENABLED in a fight. Bind keys by hovering (HoverBind.lua, `hoverBind`, `Q.hoverBind`,
  `/codex bind`, option button "Start binding"): **Forever's Quick Keybind mode is not opened from addon code** (its
  OnShow runs ActionButtonUtil.ShowAllActionButtonGrids on the secure buttons from our stack). Our own mode: banner
  `CodexHoverBindBanner` (Done = SaveBindings(GetCurrentBindingSet()), Cancel = LoadBindings), a cover button of ours
  `CodexHoverBindCover` laid over the hovered frame with a `commandName` (GetMouseFoci; ActionBar.lua sets
  commandName = commandNamePrefix .. "BUTTON" .. i), keys / extra mouse buttons / wheel through
  GetConvertedKeyOrButton, IsKeyPressIgnoredForBinding, CreateKeyChordStringUsingMetaKeyState and
  SetBinding(key, action, C_KeyBindings.GetBindingContextForAction(action)), as Blizzard_Settings_Shared/
  Blizzard_Keybindings.lua does; Escape clears every key of the command; PLAYER_REGEN_DISABLED ends it and saves.
  Learn all at trainers (Trainer.lua, `trainerAll`, `Q.trainer`, section on Trade > Trainers): a UI.Button of ours on
  ClassTrainerFrame left of ClassTrainerTrainButton (made at ADDON_LOADED Blizzard_TrainerUI / TRAINER_SHOW);
  `TA.Plan(money)` = "available" services from GetTrainerServiceInfo (Forever returns name, type, icon, level,
  subtext, category), not professions (GetTrainerServiceCost's isProfession), cheapest first within the money;
  bought in the click from the highest index down (indices never shift mid-click). Whether BuyTrainerService takes
  several calls in one click is not tested in game yet: if only one is learned per click, the button still counts down.
- `Modules/LootText` (`loottext`, "Loot text", area items, sectionOrder 35, default off (the user's choice); 2026-11-21, the user's
  request after a look at BattleText Forever, ScrollingLoot, Lootline, Loot Pro and MSBT, none of whose code was
  used; they picked every line kind, both looks, value + glow, watch list, hiding toasts and the session summary).
  `ns.loottext` (LT), settings `CodexDB.loottext`; looks `style` float / down (added at the user's request) / list. Core.lua: sources checked in the forever API docs (ChatInfo /
  CurrencyInfo documentation): items from CHAT_MSG_LOOT (own lines only, patterns built from the client's
  LOOT_ITEM_*SELF* strings by `LT.Pattern`), money = PLAYER_MONEY rises (merchant / mail / AH / trade / guild bank
  open: only with `otherMoney`, never in the session), reputation CHAT_MSG_COMBAT_FACTION_CHANGE
  (FACTION_STANDING_*), XP = UnitXP rises (across a level too), honor CHAT_MSG_COMBAT_HONOR_GAIN, Legacy points
  MAJOR_FACTION_RENOWN_LEVEL_CHANGED for faction 2802 (kind `legacy`, 2026-11-22), currencies
  CURRENCY_DISPLAY_UPDATE's quantityChange, skills CHAT_MSG_SKILL (SecretInChatMessagingLockdown: secret text
  skipped). Worth = `ns.auction.GetPrice`, else the sell price; counts = GetItemCount + other characters from
  `ns.bags.ItemCounts`. Glow: `glowValue`, `glowEpic`, watched. Toasts: CVar `enableLootToasts`
  (AlertFrameSystems.lua: LootAlertSystem ignores alerts while it is 0), player's value in `savedToasts`, put back
  when the option or the module goes off (RELOAD_STATE). Display.lua: holder `CodexLootText`, pooled lines (icon,
  outlined body font, GlowSquare glow), float (rise 150 px, never overlapping) or list (`maxLines`, newest at the
  bottom); the same key merges (float only in a line's first second); banner `CodexLootTextBanner` for watched
  items; Edit Mode mover like the personal bars (`posFloat` / `posList`). Page.lua: section, watch list (Shift-click
  into the box), session (`LT.Session()`, also in InfoBar's gold tooltip). Test `codex_loottext_test.lua`; the
  buffs test loads with `loottext = false` (its Edit Mode stand-in keeps one hook per script).
- `Modules/Highlight` (default off; standalone = `NodeSight`, which has no licence, so only its API names were looked at):
  marks on the game's soft-target interact plate (CVars SoftTargetInteract/Arc/Range/NameplateInteract/IconGameObject set
  while an object part is on; the player's values in `CodexDB.highlight.saved`, put back when the parts or the module go off,
  via RELOAD_STATE), pulsing markers (Circle glow with an alpha bounce, Buff Tracker's Ring, turning star4 sparkle, name; the user preferred them to the R2-Frames still ring + glyph, 2026-11-18),
  "!" on quest mobs (beside the name via `TylesserCodex.NameplateMarkAnchor(plate)` when the skin offers it), quest item
  corner mark in the theme's quest colour (`ns.highlight.QuestMark(button, bag, slot)`, called from Bags'
  FillLive; Blizzard bags via UpdateItems). On Codex's own buttons a quest starter also gets our "!" (ARIALN, 18 px on a 40 px slot, top right, `mark.bang`; 2026-11-27, the user's
  wish): dimming IconQuestTexture there also hid the game's "!" (UpdateQuestItem puts TEXTURE_ITEM_QUEST_BANG on it). Blizzard's buttons keep theirs. Test `codex_highlight_test.lua` (loads with `statdelta = false`).
- `Modules/MoveWindows`: drag strips over game windows' title bars (positions per session, optionally saved).
- `Modules/InfoBar` (default on): full-width screen bar (top/bottom, BACKGROUND strata). "Make room" (default on, the
  user's choice 2026-11-17) shifts the Blizzard frames in its strip (minimap, buffs, ...) by SetPointBase, session only,
  re-done after Edit Mode closes, never C_EditMode; `TylesserCodex.InfoBarMakeRoom()` (also run from Setup's Done step),
  "Put them back"; the fit-beside option is off by default and a panel under ChatFrame1 with data texts (gold across characters from
  `CodexDB.bags.characters`, bags, location, XP, reputation, professions, clock, fps/ms, guild, friends, durability,
  ammo); right-click a slot = "Show in this slot"; hide chat (alpha only) and copy chat (`/codex copychat`).
  Settings `CodexDB.infobar`; icons from `branding/source/infobar-art.js`. Test `codex_infobar_test.lua`.
  Texts added 2026-11-21: `xprate` (`I.XPRate()`: session XP summed at each look, across a level up; per hour from at
  least a minute; `I.Duration`) and `gearset` (`I.GearSets()` from C_EquipmentSet, Forever's character window has the
  equipment manager; click = `UI.ShowMenu` of sets, `I.WearSet(id)` out of combat). Tested in `codex_qol_extras_test`.
  Added 2026-11-22: a set per talent group (`CodexCharDB.talentSets[group]`, picked in the same menu, put on by
  `I.WearTalentSet(curr, prev)` from the module's own ACTIVE_TALENT_GROUP_CHANGED watcher (Bar.lua `I.Enable`), shown
  slot or not, only when curr ~= prev), and `legacy` (`I.Legacy()`: renown of faction 2802 = account points, the Legacy trees' trait currency =
  unspent, the next renown level with a reward).
- `Modules/Resource` (default off, "Personal bars"): health/power under the character, five-second-rule spark,
  mana/energy tick, druid mana, combo pips, seal timer, swing timers (PLAYER_SWING / PLAYER_SWING_RANGE_UPDATE /
  UNIT_ATTACK_SPEED; there is no combat log for addons on Forever). Settings `CodexDB.resource`, mover while Edit
  Mode is open. Text on health/power/druid mana: `text` none / value / percent / both (default both, "1,234 · 75%";
  amount = current value, short numbers from `CodexDB.skins.unitText.short`, percent from UnitHealthPercent /
  UnitPowerPercent, secrets only through SetFormattedText; replaced the old `numbers` flag, 2026-11-18). `layout`
  under (default) / beside: health upright left, power right, druid mana outside it, `sideGap` 160 / `sideHeight`
  150 / `sideWidth` 10; texts outside the bar ends (druid's under its bottom), sparks climb; combo pips and timer
  rows stay flat under them; own place `posBeside` (top centre). `arc` (2026-11-22): the beside places drawn as arcs
  (`SetArc`: Media/Arc*.tga from `branding/source/arc_textures.py`, frame 4 x the band, `ArcX` puts sparks on the
  curve; keep its constants in step with the script). Health in class colours with `ns.ClassHealth()` (the unit
  frames' setting; SettingsUI calls `R.RefreshHealthColor`). `show` always / combat / notfull (2026-11-22: health,
  power, druid mana each only while not at rest: full, or empty for rage / runic power. UnitHealth is always secret
  on Forever (the first version compared it and never hid anything, the user's screenshot), so the row's alpha is
  `UnitHealthPercent` / `UnitPowerPercent` with a Step curve (C_CurveUtil), handed straight to SetAlpha; `R.AtRest`
  only without the curve API). Test `codex_resource_test.lua`.
- Interface scale (Settings.lua, General section `uiscale`, 2026-11-22): `CodexDB.uiScale` nil = the game's own,
  untouched; else 0.5-1.15. CVars `useUiScale` 1 + `uiScale` (the game's floor 0.64) and `UIParent:SetScale` below
  that, again at PLAYER_ENTERING_WORLD / UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED; waits for PLAYER_REGEN_ENABLED in a
  fight. `ns.SetUIScale`, `ns.UIScale`, `ns.PixelPerfectScale` (768 / physical height). Tested in `codex_test`.
- Proc glow twin (2026-11-22): the standalone `Addons/ProcGlow` (Tylesser - Proc Glow) uses `Modules/QoL/ProcGlow.lua` and `ProcArt.lua` byte for byte; copy them there after every change (`pg_test.lua` fails otherwise). They read media paths / names from `ns.PROC_*` (nil in Codex). The toggle's `Elsewhere` leaves the feature to the standalone while it is loaded.
- What's new (WhatsNew.lua + generated WhatsNewData.lua, 2026-11-22): `python branding/source/whats_new.py .`
  after every CHANGELOG change and **before each release tag** (codex_test fails when the data's first section
  doesn't match CHANGELOG.md). `CodexDB.whatsNewSeen` (in Profiles' SKIP_TOP) = last version shown; at login + 4 s,
  out of combat, once per version: not on a first install (setup), not in a dev copy (`@project-version@`), not with
  `CodexDB.whatsNew == false`; lists every version newer than the seen one. `ns.WhatsNewDecision`,
  `ns.WhatsNewFor`, `ns.CompareVersions`, `/codex whatsnew`, a check + button in General > Codex window.
- Hide empty slots (Modules/QoL/HideEmpty.lua, `hideEmpty`, default off): alpha 0 on bar buttons without an action
  (`C_ActionBar.HasAction`), back while the "showgrid" attribute has the EVENT / SPELLCOLLECTION reasons, the cursor
  holds something, Edit Mode is open or hover-binding runs. A toggle's `Enable` runs at the module's start even
  while it is off: check `Q.On(key)` there (hooking Edit Mode while off broke the buffs test's one-hook stand-in).
- Personal bars cast cost (`castCost`, default on): a band of cost / max on the power fill's moving edge (anchored
  to `GetStatusBarTexture()`, clipped by a frame), UNIT_SPELLCAST_START shows it, STOP / FAILED / INTERRUPTED /
  SUCCEEDED hide it; cost from `C_Spell.GetSpellPowerCost` (not secret); not on the arc layout.
- Grey out what you can't use (Modules/QoL/GreyOut.lua, `greyOut`, default off, Action bars > Buttons): post hooks on
  each bar button's `UpdateUsable` and the global `ActionButton_UpdateRangeIndicator` (forever
  Blizzard_ActionBar/Shared/ActionButton.lua); the key text gets `ACTIONBAR_HOTKEY_FONT_COLOR` back (the range dot
  "●" keeps its red), the icon is desaturated and dimmed while out of range / no mana / unusable; secrets = usable.
  Test in `codex_qol_extras_test`.
- Nameplate size (Skins/Nameplates.lua `SizeBars`, 2026-11-22): `CodexDB.skins.plateWidth` / `plateHeight` (0.5-1.6 /
  0.5-2.5, nil = the game's). Forever has no Edit Mode nameplate system (one CVar `nameplateSize`), and
  `C_NamePlate.SetNamePlateSize` is restricted; never write `NamePlateSetupOptions`. Applied in Layout, after the
  game's anchoring (NamePlateUnitFrameMixin): CastBarsContainer re-anchored with a centred inset, the
  HealthBarsContainer's height = `healthBarHeight` x height. Edit Mode box `CodexNameplateSizer` (wheel = width,
  Shift + wheel = height, Shift + right-click = reset), pickers in the Nameplates section; `TylesserCodex.SetNameplateSize`,
  `RefreshPlateSize`. The nameplate test's mock allows those two containers (`movable` / `sizable`).
- Unit frame width / height (2026-11-22, the user's screenshot of the Player mover: "still no width or height
  option"): `CodexDB.skins.frameShape[unit] = { w, h }` (party = "party"), Shift + wheel / Ctrl + wheel on the mover,
  Shift + right-click resets size, width and height. `SizedSpec(f)` (a copy over the spec) feeds Layout and
  Geometry: dx more bar width; a right-side portrait moves dx with it through `f.origin` (every portrait piece is
  anchored to it, never to the button); height = `barScale` on the bars (party step grows by `partyExtra`).
  `S.SetUnitFrameShape`, `S.UnitFrameShape`; Profiles skip `skins.frameShape`.
- Action button cooldowns (Skins/ActionBars.lua ActionSlot): `cooldown` / `lossOfControlCooldown` / `chargeCooldown`
  SetAllPoints(icon); Forever's template insets them 3 px (2 for charges), which left the swipe short of the slot.
- **Skins/UnitFrames.lua is at Lua's 200-local limit** for its main chunk (2026-11-22): new helpers go into a table
  (`CastBar`, `Shape`), never new top-level locals. `node tools/harness/check.js` reports "too many local variables".
- Player cast bar (`CastBar.Style`, run from the unit frames' Build): PlayerCastingBarFrame keeps its logic, place and
  size (bottom-managed Edit Mode system: never resized); art in `CastBar.ART` hidden (and on Show), our fill after
  `UpdateBarFillTexture` (accent / CAST_LOCKED / bad by `barType`), `Text` inside the bar after `SetLook`, time ours
  from `value` / `maxValue` on OnUpdate. Test 3d2 in `codex_ui_unitframes_test`.
- Never use a game global as a fallback colour (`HOSTILE or {...}`: HOSTILE is the string "Hostile"); the nameplate
  test's mock SetColorTexture is strict now.
- Unit frame bar gradient (`CodexDB.skins.barGradient` "horizontal" / nil): `Paint` reads it; `TylesserCodex.RepaintBars`.
- Bags in combat (2026-11-22, the user's "bags is not opening in combat"): a fight only refills placed buttons, so
  `B.PrepareForCombat` lays out the closed window at PLAYER_REGEN_DISABLED (still out of lockdown) and 3 s after the
  window is made. Test at the end of `codex_bags_test`.
- Proc glow `artOnly` (Clearcasting: art and sound, no button glow); Heating Up 400625 at 3 stacks lights Pyroblast
  (notIDs 400624 passive, 460878 boss aura), art `heating_up`.
- Hover-bind cover: the union of the button, its icon and every drawn region of it and its children up to 1.4x its
  size (a restyle's ring sits outside the button).
- Loot roll glyphs (Skins/LootRoll.lua) keep the game's colours (2026-11-22, the user's request); only a disabled
  button greys and dims its glyph.
- `Modules/Rings` (default off; standalone = `OPie`, whose code and art were not used): OPie-style ring menus. Data.lua
  (`CodexDB.rings`: radius, iconSize, nextID, list of rings `{ id, name, enabled, key, auto, preset, slices }`; account
  wide, no per-character copies; slices `{ kind = spell/item/macro/mount/marker/toy/action, id }`; premade Mounts /
  Travel / Professions are `auto` rings filled from what the character knows and carries each time they are laid out,
  Markers = 8 icons + clear; changing a slot copies the list, "Fill from what you know" puts `auto` back), Secure.lua
  (one SecureHandlerBaseTemplate controller owning the keys, the one named frame `CodexRingButton`
  (SecureActionButtonTemplate, `useOnKeyDown` false, AnyDown+AnyUp) clicked by every ring key with the mouse button
  `ring<id>` / `close` (Escape), its OnClick wrapped by `R.TRIGGER_SNIPPET`; one 2000x2000 SecureHandlerBaseTemplate
  per ring with 12 SecureActionButtonTemplate slices; built at Enable only for rings that are on, only out of combat,
  queued in `R.pending` until PLAYER_REGEN_ENABLED), Display.lua (plain frames over the ring: disc, round icons with
  Buff Tracker's Ring.tga, round swipes, counts, red/blue tints, hover = bigger + accent ring + name in the hub +
  pointer line; `R.PickIndex` = the snippet's sums: wedge by direction, nothing inside `R.DeadZone()` or beyond `R.OuterLimit()`;
  two looks, `CodexDB.rings.style`: nil = "ping" (default since 2026-11-19, the user's request: Blizzard's ping wheel,
  Blizzard_RadialWheel's atlases scaled by radius / 80, names beside the icons by its quadrant rule, `R.LayoutPing` /
  `R.PingHover` / `R.PingPointer`; 4 slices use Radial_Wheel_Frame_Count_4 + _Select_Wedge_Count_4, other counts
  Line dividers + Media/Wedge<N>.tga) or "codex" (the disc with the name in the hub); a check on the Rings page), Page.lua (list, key capture with conflicts from
  `GetBindingAction`, 12 slots: drop from cursor, right-click clear, drag to swap, click opens the slot picker
(Picker.lua, `CodexRingPicker`, 2026-11-22: `R.CHOICE_KINDS` spells / items / mounts / toys / macros / markers /
actions / windows / rings, `R.Choices(kind, ring)`, search, a click = `R.SetSlice`); rings in rings: slice kind
`ring` (attribute `subring`, the trigger snippet opens it at the cursor; a ring can't hold itself); preview;
  sizes; editing refused in combat). `/codex rings`, `/codex ring <name>` (out of combat). Test `codex_rings_test.lua`
  (runs the snippets in a stand-in restricted environment).
- Whisper group leaders (Modules/QoL/GroupWhisper.lua, `lfgWhisper`, default on, message `lfgWhisperText`, Chat >
  Whisper group leaders; 2026-11-27, the user's request): Forever's LFG window is Blizzard_GroupFinder_VanillaStyle
  (load on demand, Mainline family for camelot). `hooksecurefunc("LFGBrowseSearchEntry_Update", ...)` (hooked at
  Enable or on its ADDON_LOADED) adds a `UI.Button` "Whisper" at the row's BOTTOMRIGHT; rows are recycled ScrollBox
  frames, so the button is kept in a weak table (nothing written on Blizzard's frames) and re-read from
  `entry.resultID` every update. Leader = `C_LFGList.GetSearchResultInfo(id).leaderName` (SecretInChatMessagingLockdown:
  never used while `issecretvalue`); no button for solo players, delisted groups or your own listing. Sent only from
  the click (`SendChatMessage` HasRestrictions) with `C_ChatInfo.SendChatMessage or SendChatMessage`, as Crier does;
  the same leader again after 120 s. Tests at the end of `codex_qol_extras_test`. Button placement not yet seen in game.
- Skull mark (Modules/QoL/Skull.lua, `skullMark`, default off, Unit frames > Skull mark, `/codex skull`, `Q.skull`;
  2026-11-26, the user's "mark the mob player attacks with skull if role assigned to skull"): **SetRaidTarget is
  protected since 12.0** (forever RaidMarkersDocumentation HasRestrictions; wiki "#protected"), and
  GetRaidTargetIndex is SecretReturns, so nothing marks by itself and markers are never read. `CodexSkullButton` =
  SecureActionButtonTemplate, `type1` "raidtarget" (only while allowed), `marker` 8, `action` "set" (never toggles
  off), `unit` "target", `useOnKeyDown` false, AnyDown+AnyUp; key `skullKey` = SetOverrideBindingClick(button, ...,
  "LeftButton"), cleared while not allowed. Allowed (`S.Blocked()` = the reason, or nil): in a group unless
  `skullGroupOnly` is off, and UnitGroupRolesAssigned("player") = `skullRole` (tank / healer / damage / any; NONE
  only with `skullNoRole`; secret = allowed). `S.Apply()` out of combat only (pending to PLAYER_REGEN_ENABLED);
  GROUP_ROSTER_UPDATE / PLAYER_ROLES_ASSIGNED / PLAYER_ENTERING_WORLD apply. Right-click = its section, right-drag
  moves it (`skullPos`). Test `codex_skull_test.lua` (runs the secure action like SecureTemplates); bench
  `codex_roles`.
- `Modules/Buffs` role condition (2026-11-26): see BuffTracker/CLAUDE.md (Conditions.lua is the same file); the
  Codex window's `ROLES_HEIGHT` is 90.
- `Modules/Crier` (`crier`, "Trade Crier", area chat, default off; standalone = `TradeCrier`, 2026-11-26, the user's
  request): `Crier.lua` is TradeCrier's file byte for byte (`tc_test.lua` checks; see TradeCrier/CLAUDE.md for the
  design: a post only from the button's click, its override-binding key or a typed command, since channel chat needs
  a hardware event). Host.lua: `CodexDB.crier`, `CodexCharDB.crier`, button `CodexCrierButton`; Page.lua its section
  (own tab on Chat). Test `codex_crier_test.lua`; bench scenario `codex_crier`. Messages (2026-11-26, the user's
  wish): `CharDB.messages = { { text, every (seconds, C.MIN_EVERY 30 .. 1 day), off, icon, last } }`, at most
  `C.MAX_MESSAGES` 8; `C.NextMessage()` = the ready one whose time comes first (longest wait on a tie); a press
  before its time posts nothing. 1.0's `message` + account `interval` (minutes) move into the list in
  `C.Messages()` (`interval` stays for other characters). Icon: `message.icon` or `C.AutoIcon` (first linked
  profession code); `C.ShowIconPicker` is a plain grid in Crier.lua so both hosts share it. Buttons (same day):
  one per message with something to post (`C.BUTTON_NAME`, then `..2` ...; message 1's button stays as a placeholder
  when nothing is written) in the bar `..Bar` (keeps `pos`, scale; any button drags it; `column` stacks them);
  `C.Post(index)` posts that message; the key binds to the invisible `..Key` button (alpha 0, no mouse, shown so the
  binding's click reaches it), which posts `C.NextMessage()`.
  Cities (2026-11-27, TradeCrier issue #1): `message.city`, the city picker and the teleport icons; see
  TradeCrier/CLAUDE.md. Page.lua's rows use `C.CityButton` like TradeCrier's Options.lua.
- `Modules/Professions`: Profit Sort ported in (standalone = `ProfitSort`). Prices only from Codex: auction
  `ns.auction.GetPrice`, vendor prices recorded at merchants (`CodexDB.professions.vendor`, the lowest unit price seen: the Black Market
  sells the same reagents far dearer); a reagent costs the cheaper of vendor and auction. Forever opens the
  modern `ProfessionsFrame`; the classic TradeSkill/Craft providers are kept. The block sits in
  `CraftingPage.SchematicForm` under `.Reagents` (selection via `hooksecurefunc(form, "Init")`), the profit
  list docks right of the window. Recipes per character in `CodexDB.professions.characters["Realm-Name"]`
  (only your own window, not linked ones). Tooltip adds Craft cost/profit; "AH value" only while the Auction
  module's own line is off. Queued reagents go to the Codex shopping list "Professions". While the AH is open the
  block has Search / Reagents buttons: `A.SearchList` on a temporary (unsaved) list, results in the Codex AH panel.
- **2026-11-28 batch** (the user asked for competitor features; built by parallel workers, untested in game):
  - `Modules/Mail` (`mail`, area trade, sectionOrder 60, default off; `Locales/Mail.lua`): built from Blizzard's
    forever mail code. Open all / Gold only replace the game's Open All Mail button (hidden while ours show, an
    OnShow hook keeps it hidden). Each step finds the first takeable mail again (emptied mails move the rest up);
    3 tries per pickup, a run stops after 2000 steps and 5 waits for more mail. Recent names: hook on `SendMail`,
    kept on `MAIL_SEND_SUCCESS`; characters in `CodexDB.mail.characters[realm|faction]`. Alt-click attach: hook on
    `HandleModifiedItemClick` when the click passes a bag location. Postal loaded = all three parts step aside.
  - `Modules/Crier/CrierWatch.lua`: buyers in Trade chat, shared byte for byte with TradeCrier (notes in
    `TradeCrier/CLAUDE.md`); texts in `CrierLocales.lua`.
  - `Modules/Professions/Cooldowns.lua` + `provider.Cooldowns()` (`C_TradeSkillUI.GetRecipeCooldown`, as the forever
    recipe form does); `P.PlanReagent` (the saved queue holds a plain copy of the plan, never scan tables);
    `P.AltOwned` (Bags module first, then Syndicator); `P.ListedDays` / `A.DaysListed` (Auction History.lua:
    "scanned days" = days on which any item has a price, recounted at most once a minute). `Locales/Professions.lua`.
  - `Modules/StatDelta/Best.lua` (`S.UpgradeChoices` / `S.BestUpgrade`, `.slot` / `.altSlot` on each comparison; AH
    row hooks, see `StatDelta/CLAUDE.md`); `Modules/Auction/Upgrades.lua`: panel mode `upgrades`, `A.UpgradeRows()`
    scores about 150 new items per refresh and redraws after 0.3 s while some are left. `Locales/Upgrades.lua`.
  - `Modules/Commerce/Route.lua`, `Characters.lua`: same design as the standalone (`CommerceAuthority/CLAUDE.md`), on
    `C.*`; `CodexDB.commerce.characters` stays out of profiles through `SKIP_ANY.characters`; the Deliveries heading
    line ends 166 px short of the right edge for Route beside All NPCs.
  - `Modules/VendorSearch/Buy.lua` (Alt-click Buy window; shares `V.BulkInfo` / `BuyPlan` / `BuyBulk` with the
    standalone, only its `Look` table differs); Core.lua is the standalone's Core with `ns` -> `V`.
    `Locales/VendorSearch.lua` (the retired "Unknown recipes" texts were removed from Ports.lua).
  - `Modules/Buffs/Share.lua` / `NextBuff.lua`: byte-identical with Buff Tracker's (each detects Codex; notes in
    `BuffTracker/CLAUDE.md`); the next-buff key is an override binding like the Crier's post key. Page height 488,
    party section 820. `Locales/Blessings.lua`.
  - Proc glow ending warning: `P.Endings` (end-time rules), `P.HookRefresh` (hooks the cooldown manager item's
    `OnUnitAuraUpdatedEvent`), a `duration` field on each buff list entry; detail in the comment above
    `P.ViewerAuras`.

## Forever pitfalls (each one cost a round trip with the user, 2026-11-17/18)

- `Modules/VendorSearch` (`vendorsearch`, area trade, sectionOrder 32): Tylesser - Vendor Search ported in
  (standalone = `VendorSearch`; its twin). On `ns.vendorsearch` (`V`). Core.lua / Filter.lua are the standalone's
  with `ns.` -> `V.`, `VendorSearchDB` -> `V.db` (`CodexDB.vendorsearch`, copied once from `VendorSearchDB`;
  `boxOffset` in Profiles' SKIP_PATH); the box is SearchBoxTemplate (`CodexVendorSearchBox`) with its art made
  invisible and `UI.Inset` behind it, the check boxes `UI.Check`. Core.lua keeps the item API as locals at load
  (tests set their mocks before LoadCodex). `/codex vendorsearch [reset|help|options]`, `/vsearch` only while the
  standalone isn't loaded. Test `codex_vendorsearch_test.lua` (also drives the vendor grid on a mock window).
- `Modules/Commerce` (`commerce`, area trade, sectionOrder 25): Tylesser - Commerce Authority ported in
  (standalone = `CommerceAuthority`; its twin, so a fix to one goes into the other). Everything lives on
  `ns.commerce` (`C`), never on `ns` (Codex's `ns` has its own Money/Say/...). Data, Core, Learn, Quests, Tooltip,
  Vendor are the standalone files with `ns.` -> `C.` and `CommerceAuthorityDB` -> `C.db` (ported by a script,
  2026-11-19); Settings.lua is new: `CodexDB.commerce` (`C.DB()`, account-wide; the standalone's
  `CommerceAuthorityDB` copied once, positions left out; `learned`/`factionIDs`/positions in Profiles' SKIP_PATH),
  prices = Codex's `ns.auction.GetPrice` (link, then ID; one source "Codex", tooltips show its age), craft cost =
  `ns.professions.CraftInfo` (not when `missing`; an alt's recipe is named), `C.Money` = `ns.Money` ("--" for nil).
  Shopping.lua: the buy list is the Codex shopping list "Commerce Authority" (replaced each time, terms exact, no
  quantities); `C.SearchWrits` runs `A.SearchList` on a temporary list + `A.ShowPanel` while Codex's AH is open,
  else the game's search box. Window.lua / NPCs.lua: the two windows on Codex widgets (`C.NewWindow`: UI.Panel,
  title, close, Esc, place in `C.db.position` / `npcPosition`); `C.Tone` swaps the standalone's colour codes for
  the theme's muted/good/warn/accent/bright. Page.lua: options (no "all sources" option: one source). Module.lua:
  events, `/codex commerce [npcs|buy|options|debug]`, `/codex writs`, and `/aca` `/commerce` only while the
  standalone isn't loaded. Test `codex_commerce_test.lua` (ported from `ca_test.lua`). 2026-11-28 (twins of the
  standalone): Dock.lua (the window docked beside the AH, right of the Codex auction panel; `auctionDock`;
  `C.DockWindow`, `C.EnsureWindow`, `C.RestoreWindowPosition`; events from Module.lua) and the crate ranking
  (`C.CheapestCrates`, `C.SearchRankedCrate` with term quantities, `C.CreateRankedCrateBuyList`). The window has two
  tabs (same day, the user's "writs and crates are not the same thing"): `window.panes.writs` / `.crates` (each
  SetAllPoints the window; parts keep window coordinates), `window.tabs` (UI.Button + accent `mark`),
  `C.SelectWindowTab(key)`, saved in `windowTab`. Writs: faction, bar, writ bags, deliveries (writs only), next
  standings, cheapest reputation by writ / NPC / zone (`C.CheapestMode` maps anything else to writ). Crates:
  Favor, `C.CrateBagsText`, `window.fills` (crates to fill), `window.rankRows` (the ranking, `rankList` rows scroll
  with the wheel; `window.rankHint` "%d-%d of %d"), `window.rankBuy`.
- **Read Blizzard's Forever code before naming a frame.** `forever` branch of Gethe/wow-ui-source (see the workspace
  CLAUDE.md). Guessed names failed twice in a row on the quest log's count box (real: `QuestScrollFrame.SearchBox`,
  `QuestLogCount` with `.Left/.Middle/.Right` border, `QuestLogQuestCount` text, `QuestScrollFrame.SettingsDropdown`)
  and once on the tracker click. If the source doesn't settle it, ask the user for a `/fstack` name.
- **Menus (Blizzard_Menu) are built by the compositor.** On entry frames and their regions, even *looking up*
  `SetFont`, `CreateTexture`, `CreateFontString`, `CreateMaskTexture`, `CreateAnimationGroup` or `CreateLine`
  reports an error (and floods "AddOns are experiencing a large number of errors"). Tell compositor regions apart by
  a function `__index` in their metatable (`Composed()` in Skins/Menus.lua), use `SetFontObject` with a font object
  of ours, and draw our pieces on frames of ours (`CreateFrame(..., entry)`), never on the entry.
- **Secret values:** never compare, test or concat what a formatting helper returns for a possibly secret number
  (`BreakUpLargeNumbers` on a secret gives a secret string; `== ""` on it errors and the whole text update dies).
  Call helpers in pcall and pass the result straight to `SetFormattedText`/`SetText`. Wrap per-unit text updates in pcall.
- **Taint:** never call Blizzard setters on secure-ish windows that read secret values later (damage meter
  `SetSession*`, `SetMinimized`, `UpdateShownState`): a value we write is tainted and their next refresh breaks. Change
  such state only through Blizzard's own UI (its menu), or say it can't be done. Blizzard mixin methods on a frame
  of ours are fine only when they touch nothing but that frame: `TabSystemButtonArtMixin:SetSquareMode` writes a
  file-local of the tab file (read again by Blizzard's own tabs), so it is never called (Future spells' tab).
- **Forbidden frames:** some UIParent children are forbidden to addon code; on them even `IsShown` / `GetAlpha` error
  ("Attempt to access forbidden object"). Walking `UIParent:GetChildren()` (Dialogue's fade): call `IsForbidden` first,
  each check in pcall (`FadeCandidate`, 2026-11-21, the user's error in beta4).
- **`UnitIsUnit` can return a secret boolean** (forever UnitDocumentation: `SecretWhenUnitComparisonRestricted`),
  e.g. an aura's `sourceUnit` against "player" in a raid; `== true`, `not` or `if` on it errors (the user's report,
  2026-11-21, Buffs ReadBuffs). Compare units only through `ns.SameUnit(a, b)` (Buffs Core.lua and Buff Tracker's:
  true / false / nil = unknown) or `H.Ask` + `== true`; decide what "unknown" means at each call.
- **Race masks are 64-bit, and a race's bit is ChrRaces.PlayableRaceBit** (2026-11-22). Forever's Skyborne are race
  95 (High Order, Alliance) and 96 (Windshaper, Horde) with bits 32 and 33, so `1 << (raceID - 1)` is wrong for them
  and the DB2's `RaceMasks_0` alone misses their bits (`RaceMasks_1` holds them). Use `ns.RACE_BITS`
  (ClassSpellsData.lua, generated).
- **Dual spec is two talent groups, not specializations** (2026-11-22). Forever's talent frame (PlayerSpells
  Camelot/ClassTalents) uses `C_SpecializationInfo.GetActiveSpecGroup()` (1 / 2), `GetNumSpecGroups()` and
  `ACTIVE_TALENT_GROUP_CHANGED`; read the group only once `C_SpecializationInfo.IsInitialized()` is true (early in a
  login it says 1) and act again on `PLAYER_TALENT_UPDATE`. `C_EquipmentSet`'s spec calls are Retail's
  specializations: Forever's gear manager can't tie a set to talents (Codex keeps `CodexCharDB.talentSets`).
- **Camp buffs and Legacy** (2026-11-22): camp features give "Boosted ..." auras that don't stack with the matching
  class buff; two different ones are both "Boosted Stats", so they are matched by spell ID (`ns.CAMP_BUFFS`, Buffs
  Party.lua). Legacy points are the renown of the Legacy reward track (`Constants.LegacyConsts`
  `LEGACY_REWARD_TRACK_FACTION_ID` 2802, `C_MajorFactions`); unspent points are the Legacy trees' trait currency.
- **A zone's `C_QuestLog.GetQuestsOnMap` lists quests that stand in a neighbouring zone** (2026-11-22, the user's
  screenshot: continent-map clusters mixing zones). Never take the listing zone as the quest's zone; Skins/QuestPins.lua
  asks `C_Map.GetMapInfoAtPosition` on the wide map where the quest's spot is (`S.QuestZoneAt`).
- **Text with colour codes:** strip `|c........` / `|r` before measuring or matching length (the quest count's
  numbers are colour-coded).
- **Sell price** on Forever is a plain text line (`GameTooltip_OnTooltipAddMoney`: "Sell Price: <money>"), not a
  money frame; it shows the stack's total.
- **Stack size of a hovered item:** read it from the slot (`owner:GetBagID()`, `owner:GetID()`,
  `C_Container.GetContainerItemInfo(...).stackCount`). Codex's bag window keeps `button.count` at 0 and shows
  counts in its own `codexCount` text, so `.count` alone made every stack look like one item (sell price fix failed).
  Test tooltip features over Codex's bag window too, not only Blizzard's bag buttons.
- **Professions book bars:** `StatusBar.Fill` stays 441 px wide; use the bar frame's width / `overrideWidth`.
- **`DAMAGE_TEXT_FONT`** is read when the world loads: set it at Codex's ADDON_LOADED, not from the Skins folder.
- **`isFromPlayerOrPlayerPet == true`** means cast by *any* player, never "cast by me". Only a readable caster that
  is the player counts as mine; unknown stays unknown.
- **Layout in our own UI:** a child frame always draws over its parent's regions (text drawn on a parent under a
  child panel is invisible: put texts on their own frame above the box). Font strings measure 0 before their first
  draw: lay out again on show / next frame, and bind every text's width to its column so it wraps. No text under
  9 px (the game's fonts blur). Pictures in Settings use only the game's own atlases (checked with
  `C_Texture.GetAtlasInfo`) or plain stand-ins, never imitated Blizzard art.
- **Restricted snippets (checked in Blizzard_RestrictedAddOnEnvironment, forever branch):** the header handle is
  `owner` (also `control`); globals written in a snippet live in the header's environment. Handle methods used by
  Rings: `SetPoint(point, "$cursor")` (moves to the mouse, in combat), `GetMousePosition()` (0-1 inside the frame's
  rect, nil outside: make the frame big), `IsUnderMouse`, `Show/Hide/IsShown`, `Get/SetAttribute`, `GetFrameRef`,
  `GetParent`, `GetWidth/GetHeight`, `SetBindingClick/ClearBindings`, `CallMethod`. No `GetCursorPosition` in the
  scope; `math.*`, `floor`, `strmatch` are there. A wrapped OnClick's pre snippet returning `false` cancels the click,
  its second return is the post snippet's message (post runs only when it is not nil). SecureActionButton attribute
  `useOnKeyDown = false` makes the action run on release; plain attributes (`type`, `spell`) work for any mouse button
  name (`ring3`). Forever's secure actions include `raidtarget` (`marker`, `action` toggle/set/clear/clear-all),
  `toy`, `worldmarker`, `macro` + `macrotext`. `C_ToyBox` on Forever has no `GetToyInfo` (toys are used as items);
  `C_MountJournal` is documented but Forever's journal hides favourites (`BLIZZARD_COLLECTIONS_MOUNT_JOURNAL_SHOW_FAVORITES = false`).
- **Action bars (forever branch, Blizzard_ActionBar):** the usable signal is `ACTION_USABLE_CHANGED` (payload: a list
  of `{ slot, usable, noMana }`); Blizzard's buttons commented out ACTIONBAR_UPDATE_USABLE. `IsUsableAction`,
  `GetActionTexture`, `HasAction` ... are globals only with the deprecation fallbacks (CVar `loadDeprecationFallbacks`):
  use `C_ActionBar.*`; `GetActionInfo`, `PickupAction`, `PlaceAction`, `GetCursorInfo` are still globals. Placing:
  `C_ActionBar.PutActionInSlot(slot)`; picking up: `C_Spell.PickupSpell(id)`; ranks: `C_ActionBar.IsHighestSpellRank`,
  `C_SpellBook.IsSpellBookItemLowRank`, spellbook `subName` "Rank n". Learning fires LEARNED_SPELL_IN_SKILL_LINE
  (no LEARNED_SPELL_IN_TAB). Proc glows: the buttons handle SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE themselves through
  `ActionButtonSpellAlertManager`; never call its ShowAlert from addon code (it writes `activeAlerts` that Blizzard's
  button updates read: taint). Build `ActionButtonSpellAlertTemplate` on a frame of ours instead. Sounds:
  `SOUNDKIT` comes from Blizzard_SharedXML/Mainline/SoundKitConstants.lua (the Family file on Forever).
- **Before saying "fixed":** a test must reproduce the real structure (e.g. the compositor metatable, colour-coded
  text, an unreadable caster); a mock that is friendlier than the game passed every time the game failed.
- **NPC windows (QuestFrame, GossipFrame):** UI panels (area "left"); the talk lives as long as they are *shown*
  (their OnHide calls CloseQuest / C_GossipInfo.CloseGossip), so drawing our own means parking theirs, never hiding
  them. QuestFrame_OnEvent itself skips QUEST_DETAIL with a quest-start item ID, area-trigger auto quests and
  adventure-map quests; GossipFrame selects a lone `selectOptionWhenOnlyOption` option without showing. Selecting
  options and quests, AcceptQuest, DeclineQuest, CompleteQuest and GetQuestReward are not protected. The offer
  gives no Classic faction reputation (only `C_QuestOffer.GetQuestOfferMajorFactionReputationRewards`): Codex uses
  its own table. Secret strings answer `type()` with "string": test them with `canaccessvalue` / `issecretvalue`
  before any `==`, `#` or `..`; show them only through SetText (Modules/Dialogue `D.Raw`, `D.Str`, `D.HasText`).
  Keyboard frames: SetPropagateKeyboardInput / EnableKeyboard only out of combat (set at PLAYER_REGEN_DISABLED).
- **Aura durations:** Blizzard anchors `Duration` with its top right on the icon's bottom edge
  (AuraContainerMixin, again on every layout), so a ring of ours round the icon runs through the digits (the
  user's "36 m" buff, 2026-11-19). Skins/Auras.lua `DurationGap`: a post hook on the text's SetPoint moves it 3 px
  away from the icon, whichever side the layout puts it.
- **Character sheet stats:** Forever shows `CharacterStatsPaneScrollBox` (and `CharacterStatsPanePetScrollBox`):
  .ScrollBox (rows: Background + Title for headings, Background + Label + Value), .ScrollBar, .Border,
  .ClassBackground. `CharacterStatsPane` exists but stays hidden; the skin first styled only it (names from ElvUI,
  not Blizzard's source), so the stats kept Blizzard's art (2026-11-19). Mode side tabs: LargeSideTabButtonTemplate
  (Background, Icon + Mask, SelectedTexture, TabGlow; `SetChecked` from SidePanelTabButtonMixin).
- **Section heights:** Areas.lua sizes a section's holder to its content height every layout, also when the
  height is fixed; a `pageHeight` given as a function used to leave the holder at the first estimate (200), so
  Buffs' lists, anchored to its bottom, were one row tall (2026-11-19).
- **Auction buy views:** Blizzard's ItemBuyFrame / CommoditiesBuyFrame search for their item when shown, and
  `SetDisplayMode` returns early when the mode doesn't change; `A.OpenResult` goes back to
  `AuctionHouseFrameDisplayMode.Buy` first when a buy view is open (a second result kept the first item's prices,
  2026-11-19).
- **Tracker background:** Blizzard's own `ObjectiveTrackerFrame.NineSlice` gets its alpha back from Edit Mode's
  background opacity (`SetBackgroundAlpha`): a post hook kills it again. Quest titles: a post hook on each title's
  SetTextColor maps QuestDifficultyColors / HighlightColors to the theme's bad / warn / good / muted / accent.
- **Dawn's HUD:** `look.inkHud` defaults to true since 2026-11-20 (the light HUD over the world was a grey haze);
  tests of the light HUD load with `look = { inkHud = false }`.
- **Addon buttons (Modules/QoL/AddonButtons.lua, `addonButtons`):** LibDBIcon's `lib.objects` and Minimap /
  MinimapBackdrop children named like addon buttons (not Blizzard's, see BLIZZARD) are hidden, a post hook on
  Show keeps them hidden; the moon (`MinimapCluster.DielFrame`, a plain Frame from Camelot Diel.lua) gets the mouse
  and opens `CodexAddonButtonList`; rows call the LDB object's OnClick on the row, else the button's OnClick.
  Test `codex_addonbuttons_test.lua`.
- **Your own buffs in combat are secret** (2026-11-20, Echo of Command showed only out of combat): a buff off
  Blizzard's allow list returns `spellId`, `name` and `applications` as secrets from GetAuraDataByIndex in a fight, and
  `GetPlayerAuraBySpellID` is `RequiresNonSecretAura` (UnitAuraDocumentation, forever). An addon can't turn a secret
  count into a decision: `SetAlpha` takes secrets but curve `Evaluate` only from untainted code. What stays readable:
  the cooldown manager's buff items (`BuffIconCooldownViewer` / `BuffBarCooldownViewer` `itemFramePool`): their
  spell from `C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)` (spellID / overrideSpellID /
  linkedSpellIDs) and a plain `item.isActive`. ProcGlow's `P.ViewerAuras` reads those; an unreadable count counts as
  reached only for entries with `secretStacks`. So a buff proc works in combat only when the player tracks that buff
  in the cooldown manager. **Counting hidden stacks (2026-11-21):** Blizzard's viewer routes UNIT_AURA by the aura's
  own instance (CooldownViewerMixin:OnUnitAura -> the item's `OnUnitAuraUpdatedEvent` for an update,
  `OnUnitAuraRemovedEvent` when it goes; the UNIT_AURA payload itself is `SecretWhenAurasRestricted`). Per-item post
  hooks (`P.HookStacks`) count: new buff 1, each update +1 up to `stacks` (one per GetTime: icon and bar of the same
  buff both get the call), removed / inactive 0; a readable count always replaces the guess (`P.SeenStacks`);
  `P.StacksReached`; no hooks = the old "active = reached". `/codex procglow` prints the counts and the seal.
  Forever's cooldown manager has no item per echo: one **"Unsealed Wrath"** item (spell 1310735) is linked to every
  Echo of <seal> (the user's report). `ViewerMatch` resolves such a multi-echo item to the echo of `P.lastSeal`
  (`P.NoteSeal`: a readable seal buff in `P.ActiveAuras`, or a readable `UNIT_SPELLCAST_SUCCEEDED` spell; a seal
  without an echo, the Crusader, clears it), unknown seal = nothing; a removal zeroes every echo. A pasted idea
  counted every player UNIT_AURA in a fight, which counts every other buff and debuff too.
  **Stacks from a cast time (2026-11-23, a crit gives Heating Up two stacks in one change):** an entry's `castTime =
  { spell, ref, step }` reads the count from `C_Spell.GetSpellInfo(spell).castTime / ...(ref).castTime` (no secret
  flag; the ref spell cancels haste) against that ratio learned at a known 0 (`P.LearnCast`: a fully readable buff
  list without it, or the viewer item off); `P.CastStacks` overrides the counted guess in `P.ActiveAuras` and works
  without the cooldown manager. Never learned from a count above 0 (only checked: a readable count that reads 0
  sets `P.castWorks = false`); a 0 is trusted only after a drop was seen. Counting now dedupes per item
  (`guess.item`): two updates of one item in a frame count twice. The tooltip's cast time drops with the stacks (the
  user, 2026-11-23); `/codex procglow` prints the reading.
  **The cast time lags the buff in game** (2026-11-24, Heating Up only after the fight with the build-up off):
  the ratio without the buff is the longest one seen at a known 0 (a stale short reading right after the drop can't
  lower it), `P.castWorks = false` only when two readings `P.CAST_DOUBT` (0.5 s) apart disagree with a known count
  (`P.castDoubt`, a re-check timer), and `P.ForgetCast()` relearns on talent changes (PLAYER_TALENT_UPDATE,
  TRAIT_CONFIG_UPDATED, ACTIVE_TALENT_GROUP_CHANGED, out of combat).
  **Per-ability lists (2026-11-23, the user's request):** `EachList` (ProcGlow.lua) lists `P.ClassKeys()` (the
  player's class: `class` on P.REACTIVE entries and class auras, `listClass` = list only, Shadow Trance;
  `P.SoundKeys()` without a class is every proc), under a header button (`sub.header`, `UI.FoldArrow`, "<Class>
  procs (n)") that folds it (`CodexDB.qol.procEachFolded[eachKey]`, `P.SetEachFolded`). Since 2026-11-28 (the user's request: one preview, not one per
  setting; then "put preview to side panel") the page has **one preview**, in a side column: the toggle's
  `sidePreview` -> `P.BuildPreview(parent)` (made once, moved to the new parent) = ProcArt's `A.PreviewPanel`
  (160x218: art on the proc's side, `panel.button` in the middle = `P.preview`, lit with the proc's own glow style and
  colour, lines name / art / side / glow, Play). Codex: Modules/QoL/Page.lua gives the section `preview` +
  `previewFirst`, Info.lua then lays the preview under the title and the words after it. Proc Glow: Options.lua's
  `panel.side` column right of the scroll. `P.PreviewProc(name)`: hovered row of any list, else `P.previewPicked`
  (marked in every list), else the class's first. `codexNoSearch` on it (the search would take its proc name for an
  option). EachList's sixth argument is unused. The art list's seventh argument (`Swatch`) adds a colour square per
  row: `A.ColorFor` / `A.SetColorFor` (`procArtColorFor[name]`, only while `procArtLookEach`), `A.PickColor(name)`,
  right-click or the row's reset button (`row.reset`, UI-RefreshButton, shown only with an own colour) clears;
  `A.TintFor` takes it first; dimmed when the art isn't tinted (Codex art pieces). Art colour row: `button2`
  Reset (`A.ResetColor`; both pages support `button2`); `A.PaintGallery` re-tints the gallery on show, on
  `A.Refresh` and on `P.Repaint`. Proc Glow's Options.lua places the returned preview frame itself (it never
  did, so the glow style preview never showed there until 2026-11-24); it shows the hovered row, else `sub.selected` (first row, then the last picker clicked;
  marked in the accent). One hovered row per list (`sub.hovered`, `SetHover`): a `hover` band, kept while the
  pointer is on its picker / buttons (HookScript + IsMouseOver), and the box's OnUpdate drops it when the pointer
  left without a leave event (a band stayed lit, 2026-11-24). The selected row's `mark` is a 3 px accent bar,
  shown only once the player picked on a row (`sub.picked`), never for the default first row. The standalone's Shim has its
  own `UI.FoldArrow` (Media/FoldArrow.tga copied).
- **Proc glow, the suggestion list (2026-11-24, the user's "do all"):** your own procs (`procCustom` = { buff = ID
  or name, spell, class }; `P.CustomAura` makes P.AURAS-like tables kept per saved entry, `P.CustomList(class)`,
  `P.AddCustom` / `P.RemoveCustom` / `P.CustomChanged` (lookup reset + Scan); in the lookup, the per-ability lists
  and `P.ButtonIcon`; page: `BuildCustom` / `RefreshCustom`, edit boxes `ns.UI.EditBox`, the standalone's Shim has
  one; Pick buttons open `P.OpenPicker("buff" | "spell", onPick)`: `P.PickerCategories` = buffs on you now, gear
  with a use spell, bag consumables by GetItemInfoInstant's sub type, other bag items, spells by spellbook tab (no
  passives); a pick writes "Name (ID)", `P.BoxValue` reads the ID; spells are saved by name, every rank lights).
  Build-up counts: readable counts, the cast time, and in a fight the cooldown manager's counted stacks, but not an
  echo's right after a seal change (`P.sealChanged`, set by `P.NoteSeal`, cleared when the item updates, goes or
  shows inactive): the one Unsealed Wrath item may still show the old seal's echoes (a first step with no echo,
  the user's screenshot); dropping the counted stacks entirely stopped the build-up in fights ("stacking procs
  not working"). Faint glow `procGlowDim` (default on, `P.DIM` 0.35): `P.Lit`'s 4th return for a reactive ability whose
  slot is "no mana" (`P.Usable` returns usable, noMana), and buff procs whose spell isn't castable; `SetDim` puts
  it in the tinted textures' colour alpha (our glows pulse their frame's alpha) or the alert frame's alpha; a faint
  reactive one gives no sound or art. Glow per ability `procGlowEach` / `procGlowStyleFor` / `procGlowColorFor`:
  `P.StyleFor`, `P.ColorFor`, `Wanted(target, proc)`, glows remember `proc`; EachList with a Swatch. Build-up
  `procArtBuild` (default on): `active.counts[aura]` (readable, counted, cast time) -> `A.Update(order, build,
  stacks)`, Codex art pieces in steps (`A.STAGED`, `A.StageArt`: `<key>_s1` the inner arc,
  `_s2` both arcs, from proc-codex-art.py's STAGED; the round stack marks were dropped, the user disliked them), other
  looks faint (`A.FaintAlpha` on the texture, the piece's own alpha is its fade). `procArtCombat` (PLAYER_REGEN_DISABLED added). Mover `procArtPos` offset: `A.Mover` /
  `A.ToggleMover` / the option button, and EventRegistry "EditMode.Enter" / "EditMode.Exit" (never hook
  EditModeManagerFrame: the buffs test's stand-in takes one hook). `P.TestProc(name)` = the panel's Play (glow via
  `P.testProc`, art `A.Test(name)`, sound). `procSoundGap` stepper (`P.SoundGap`).
- **Reagent amounts (2026-11-24):** the Reagents search's terms carry `quantity` (`P.ReagentNames`' third return:
  missing for `P.CraftCount()` crafts, CraftingPage.CreateMultipleInputBox, else the full need); `A.OpenResult`
  sets it in CommoditiesBuyFrame.BuyDisplay like typing (QuantityInput:SetQuantity + the frame's
  CommoditiesQuantitySelectionChanged event), again once after COMMODITY_SEARCH_RESULTS_UPDATED for that item.
- **Codex quest tracker (Modules/QuestTracker, module `questtracker`, area quests, 2026-11-20, the user's "show the
  zone names as groups", option 2 = our own tracker):** Data.lua (`ns.questtracker` = QT: `QT.Groups()` from
  `ns.QuestOrder.Sorted()` (root QuestOrder.lua, shared with TrackerSort), `QT.Rows`, `QT.Shape`; objectives
  `GetQuestLogLeaderBoard(i, logIndex, true)`, items `GetQuestLogSpecialItemInfo`, difficulty token from
  `GetQuestDifficultyColor` vs `QuestDifficultyColors`), Window.lua (`CodexQuestTracker`, rows = Buttons of ours,
  item buttons `CodexQuestTrackerItem<n>` = SecureActionButtonTemplate type item / "item:<id>" on UIParent anchored
  to their row, frame level = the tracker's + 20 and the quest row's hit rect stops short of it (a row under it took the
  clicks, 2026-11-21), made / moved / shown only out of combat; in a fight rows of the same `QT.Shape` are refilled in place,
  anything else waits for PLAYER_REGEN_ENABLED; Edit Mode handle via EditModeManagerFrame OnShow / OnHide; place
  `CodexDB.questtracker.point`, first from Blizzard's tracker's spot), Module.lua (settings width / background /
  yield / foldOthers / collapsed, folds per character `CodexCharDB.questtracker.folded[zone]`, clicks as Blizzard's
  OnBlockHeaderClick, menu via `UI.ShowMenu`, starts 1 s after login). Height: `QT.MaxHeight()` = `db.height`, else Blizzard's tracker's own height times
  its scale (it is its Edit Mode Height when moved, down to the screen bottom in its default place: forever
  ObjectiveTrackerContainerMixin:UpdateHeight), never past the screen bottom; rows are measured, placed from
  `QT.scrollRow` until it runs out, the rest hidden with "More above / below" lines; the mouse wheel (frame, header,
  rows) scrolls 2 rows a step, out of combat only (in a fight the shown range is part of the shape: no reflow); the
  user's first in-game look filled the whole screen (2026-11-20). **Blizzard's tracker is parked, never hidden
  or re-parented** (FlareUI's comment, forever: Hide / SetParent run its OnHide tainted and its next update fails on
  secret auras): `SetScaleBase` (Edit Mode's override keeps the widget's own) 0.001 + alpha 0, post hooks on its
  SetScale / SetAlpha park it again a frame later. `UseQuestLogSpecialItem` is protected, so items never go through
  Blizzard's buttons. Steps aside (`QT.Yielding`) when another addon parked the tracker first (scale < 0.01 at our
  start: FlareUI's tracker) or, with `yield`, while a non-quest module has `hasContents` (QT.OTHER_MODULES; a 2 s
  ticker watches): Unpark + hide ours. Switching the module needs a reload. Test `codex_questtracker_test.lua`; the
  mock's `LoadCodex` keeps the module off unless `opts.questTracker` (it parks Blizzard's tracker and refreshes on
  many events, which other tests count).
- **Quest tracker order (Modules/QoL/TrackerSort.lua, `trackerSort`, 2026-11-20):** Blizzard's tracker shows the
  watch list in watch-index order (QuestObjectiveTrackerMixin:BuildQuestWatchInfos; callings first) and calls
  `C_QuestLog.SortQuestWatches()` on zone changes, which left Forever's list in no zone order. Codex reorders the
  watch list itself (RemoveQuestWatch / AddQuestWatch from the first quest out of place, same frame, so no "new
  quest" glow), 0.3 s after zone / subzone / watch changes, never in combat, ignoring its own events for 1 s.
  "Here" = the quest log header is the zone's name, or `isOnMap`. Nothing of the tracker is hooked (its item buttons
  are secure). Test `codex_trackersort_test.lua`.
- **Realm and surname in character keys (2026-11-21):** the user's money tooltip listed their character twice: the
  new record was "-Tylesser" because Forever's `GetRealmName()` returned "" for that session (the first guess,
  "Tylesser Valerius" from a surname in `UnitName`, was the user's hint and is handled too). Every realm read is
  `ns.RealmName()` (GetRealmName, else `CodexDB.lastRealm`, else the realm of the newest bag record, which is then
  kept for the session; never "" or "?"), every character key `ns.CharacterKey()` (realm + `ns.PlayerName()`, the
  name's first word / UnitName's first value; on Forever UnitName returns name and surname as **two values**: print
  shows them with a space, which first looked like one value; `#UnitName("player")` was 8), shown
  with `ns.CharacterDisplayName(record, key)` (`fullName` = `ns.PlayerFullName()`: both values joined with
  `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR`, as Skins/UnitFrames.lua FullName; stored by
  Bags and Professions: the user wants the surname in lists), compared through `ns.NormalizeCharacterKey` (empty or "?" realm = this realm); Bags and Professions merge other spellings once per session
  (`ns.MergeCharacterRecords`: the newer record by `updated` kept, the older fills the gaps, hidden flags move).
  Bags records also store `guid`. Test `codex_characters_test.lua`.
- **The quest system's map is not always yours:** while the world map is open, Blizzard sets it to the shown map
  (forever QuestLogMixin:SyncQuestSystemWithCurrentMap -> `C_QuestLog.SetMapForQuestPOIs`), and `isOnMap` /
  `IsOnMap` answer for that map. QuestOrder trusts them only when `GetMapForQuestPOIs()` is the player's map (the
  user's Un'Goro quests went under Desolace, 2026-11-21).
- **Edit boxes in scroll areas:** an EditBox one frame below a ScrollFrame's scroll child draws no text on Forever
  (Copy chat, 2026-11-21: the user's /run checks showed text, font, colour, size and visibility all right; moved onto
  the window, or made the scroll child, the text showed). A scrolling edit box is the scroll child itself:
  `UI.ScrollArea(parent, "EditBox")` (Profiles' TextArea already did this).
- **Two namespaces:** Codex_Skins (and each theme folder) is its own addon with its own `ns`. Core code reaches
  skin code only through `TylesserCodex` (e.g. `TylesserCodex.SchoolTabLook`), never through `ns.S`.

## The user's design choices (2026-11-18; keep them unless the user changes them)

- Unit frames "compact" (default): bars grow out of the portrait (ring drawn over their left end), health 50 % and
  power 25 % of the portrait, touching with one shared line, name and numbers inside the bars (like FlareUI's card).
  Option: health bars in class colours (NPCs by reaction). Styles are picked from preview cards.
- Damage meter: no minimize button (back only while minimized); segment button shows a glyph (swords / sigma).
- Gathering-node marker: the pulsing glow + ring + turning sparkle, not the still ring with a glyph.
- The Codex window by part of the game, with a tab row per page (tabs added 2026-11-21) (2026-11-19, replaces Settings and its tabs; Rings, Quests / Map and Chat / Info bars got pages of their own the same day, the user found the combined pages too much): sidebar = search box, Home,
  Action bars, Rings, Unit frames, Buffs, Bags and items, Quests, Map, Chat, Info bars, Tooltips, Trade | General,
  Look, Profiles; each page one scroll of foldable sections, the feature's switch in its header, all its options
  inside; each skins part's "Game default → Codex" picture inside its section.
- Tooltips: the game's sell price shows one item's price, the stack's total only with Shift.
- Nameplates: level and health text centred; health text Amount · Percent by default.
- Quest windows (round 4): all three styles as options, style A (Codex window) the default in every theme; number
  keys shown as small keycaps (never "[1]" text), Space as a tiny key icon on the main button (no "[Space]"); auto
  accept / hand-in / the only service live in the module's own options (not Quality of life), all off by default.

## Tests

`E:/Games/Wow/tools/harness`: `codex_mock.lua` (WoW mock + `LoadCodex(opts)` that reads Codex.toc and the xml
includes, loads theme/skins folders through a mocked `C_AddOns.LoadAddOn`; any missing method whose name starts
upper-case is a function there, so test for a widget's own method with `rawget`); its `SetParent` moves a frame from the old parent's children to the new one's, as the game does (2026-11-24), `codex_test.lua` (core),
`codex_areas_test.lua` (every module / part / toggle in its section, search into folded sections and unopened
pages, ShowPage landing, folded state saved, headers, and no text past its column at the smallest window size in
all five themes: rects resolved from the anchors, natural text width = half the font size per character),
`codex_buffs_test.lua`, `codex_rings_test.lua`, `codex_auction_test.lua`, `codex_bags_test.lua`, `codex_professions_test.lua`, `codex_skins_test.lua`. Tests that count tooltip
post calls load with the other tooltip modules off (`professions = false`).
Run: `node run.js codex_test.lua E:/Games/Wow/Addons/Codex`. Note fengari is Lua 5.3: `%d` needs integers.
Theme loops in the UI tests cover all five themes; skin expectations read `TylesserCodex.InkTheme()`. Light game text
(`codex_ui_lighttext_test`, deleted with Dawn on 2026-11-20, tested: GameColor / Readable, tooltip lines filled in C, chat lines through the display callback,
secret lines, edit box, game fonts, the dark-panel option, dark themes untouched); Dawn level / name and toned class
colours in `codex_ui_nameplates_test` 14, toned health in `codex_ui_unitframes_test` 3n, overlays in the raid and
damage meter tests; `codex_setup_test` 7 measures a light picture's text against the box / bar under it. Dusk/Dawn
checks: `codex_test` (every token in the theme files, .toc, .pkgmeta, licence), `codex_look_test` section 7
(WCAG contrast of every text token on its surface blended over #6E7378, ink surfaces, rounded pieces, ns.Readable)
and section 8 (money colours, rounded bag / reward icons, scroll); rounded slots in `codex_skins_test` 6, bars in
`codex_ui_unitframes_test` 9, `codex_ui_nameplates_test` 14 (also status colours), `codex_ui_raid_test` 7,
`codex_resource_test` (end), rounded glows at the end of `codex_procglow_styles_test`. The mock records masks
(`AddMaskTexture`, `SetTextureSliceMargins`, `SetSwipeTexture`; `RoundMaskOf(texture)`).

## Art

`branding/source/circles.py <codexDir>` (Pillow) renders `Media/Circle.tga` (smooth 256px circle, used for every round
mask, disc and swipe instead of Blizzard's jagged TempPortraitAlphaMask) only. `Modules/Buffs/Media/Ring.tga` stays Buff Tracker's original double-line ring (the user's choice).

`branding/source/proc-codex-art.py <codexDir> [sheet.png]` (Pillow, no numpy) renders `Modules/QoL/Media/ProcArt/<key>.tga`:
the "Codex art" proc look (default since 2026-11-20, the user's request), one original 128x256 coloured left-side
piece per proc of ProcGlow's own list (the arc in the proc's colours, a drawn emblem, particles); keys and gallery
order in ProcArt.lua `A.CODEX` (Clearcasting per class); the gallery is `A.Gallery()` ("Show all arts"). Every piece
fades to 0 over 16 px towards the inner (right) edge and 6 px at the outer one (`edge_mask`), and emblems sit at x 70:
a glow reaching the texture edge was cut there in a straight line (the user's "glow is cut and looks square",
Hammer of Wrath, 2026-11-21).

`branding/source/proc-art-styles.py <codexDir> [sheet.png]` (Pillow; imports proc-codex-art.py's helpers) renders
`Modules/QoL/Media/ProcArt/style_<key>.tga`: sixteen white side pieces for any proc (2026-11-23; the second eight game
themes), tinted (ADD) by `A.TintFor`: `procArtColor` proc (default: `A.COLORS` = the Codex pieces' glow colours,
`A.COLOR_LIKE`, else the class colour) / glow / custom (`procArtCustom`, the game's ColorPickerFrame via `A.PickColor`); keys in ProcArt.lua `A.STYLES`, looks `style:<key>`, per ability `procArtLookEach` / `procArtLookFor`.

The fourteen proc sounds (`P.SOUNDS` group "codex", `file`; "match" = each proc its own: `P.PROC_SOUNDS`,
`P.MatchSound`) in `Modules/QoL/Media/Sounds/` (and ProcGlow's `Media/Sounds/`) are public-domain (CC0) recordings since
2026-11-24 (the user: the synthesised ones were "terrible", find royalty-free ones): picked, trimmed and evened out
with the workspace's `tools/sounds` (README there: which recording per name and how to swap one). Keep them CC0 or
public domain (nothing that needs credits). `branding/source/proc-sounds.py` (the old synthesiser) is superseded:
don't regenerate from it. Played with PlaySoundFile from `P.SOUND_DIR`.

`branding/source/arrow-art.py <codexDir>` (Pillow) renders `Media/FoldArrow.tga`: the smooth fold arrow of `UI.FoldArrow`
(32 px white triangle, drawn at 8x, shown at 18 px and turned a quarter with SetRotation for "open"; it replaced
arrows drawn from 1 px columns, which stepped: the user's "arrows are low quality", 2026-11-21).

`branding/source/dialogue-art.py <codexDir>` (Pillow) renders `Modules/Dialogue/Media/PreviewScene.tga` (512x256
evening meadow) and `PreviewNpc.tga` (robed figure, quest mark): the backdrop of the Quest windows page's style
pictures (Page.lua `DrawPreview`; the windows on it stay drawn in the theme's colours; they replaced flat boxes,
the user's screenshot, 2026-11-21).

`branding/source/wedge-art.py <codexDir>` (Pillow) renders `Modules/Rings/Media/Wedge2-12.tga`: the ping-wheel look's
selected-slice wedge per slice count (white, tinted gold; square so SetRotation keeps the shape). Forever's atlases
only have the 4-slice set (`Radial_Wheel_*_Count_4`, checked in UiTextureAtlasMember on wago.tools).

`branding/source/glow-art.py <codexDir>` (Pillow) renders the proc glow textures in `Modules/QoL/Media` (GlowSquare
/ GlowRound halos, GlowDot, GlowRing1-3 for round cooldown icons; white, tinted in game).

`branding/source/map-art.py <codexDir>` (Pillow) renders `Modules/QoL/Media/MapIcons.tga` (512x256, 8x4 cells of
64 px: dungeon, raid, inn, flight, bank, auction, mail, trainers, repair, vendor, stable, others, disc, ring, filter
funnel, food, reagent; white glyphs tinted in game; cell order in the script's docstring and `M.ICON`).

`branding/source/round-art.py <codexDir>` (Pillow) renders `Media/Round.tga` / `Media/RoundLine.tga` (64 px disc and
ring, quarters = rounded corners for Dusk/Dawn) and `Media/RoundMask2/3/4/6.tga` (32 px rounded-rect alpha masks with
an r px corner, nine-sliced in game).

`branding/source/theme-art.js <depsDir> <repoDir>` renders the Hearthwood wood and rivet and the Slate corner
dot (resvg-js). Hearthwood's font is IM Fell English SC (OFL, `Themes/Hearthwood/Media/IMFellEnglishSC-OFL.txt`,
must ship with it, unmodified). Classic and Slate use the game's own fonts. Dusk/Dawn: Inter 4.1 Regular +
SemiBold (static TTFs from the rsms/inter release zip, `extras/ttf`) with `Inter-OFL.txt`.
