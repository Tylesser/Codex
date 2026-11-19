# Tylesser - Codex

An all-in-one interface for **WoW Forever**: every Tylesser tool in one addon, in the look you like, plus a
restyled game interface, bags, quest windows, ring menus, info bars and more. Each feature is a module you can
switch off; a module that is off does nothing at all.

**Beta:** Codex is new and large. Expect rough edges, and please report what you find (see Feedback below).
It is made for WoW Forever only.

## Finding your options

The Codex window (`/codex`) has one page per part of the game: **Action bars**, **Rings**, **Unit frames**,
**Buffs**, **Bags and items**, **Quests**, **Map**, **Chat**, **Info bars**, **Tooltips** and **Trade**, and under a line
**General**, **Look** and **Profiles**. Each page is one list of sections you can fold open and shut. A section
starts with its feature's on/off switch, and every option of that feature is right under it: no tabs to hunt
through. Codex remembers which sections you folded.

For example, everything about your action bars is on the Action bars page: their look (with the panels behind them
and the spacing check), when each bar shows, the proc glow (also on the cooldown manager, with its sounds and the art beside your character), new
spell ranks, the future spells tab in the spellbook and the cooldown manager's look.

The search box at the top of the sidebar finds any option by its name, or by the name of its section or page:
click a result and Codex opens that page, unfolds the section and points at the option.

Home shows a card for each feature with what it is doing right now; click a card to go to its section.

## Modules

- **Buffs**: a row of the buffs you choose (when missing, when active or always), click-to-buff, weapon
  enchants, and click-to-buff and dispel buttons by your party frames. Formerly the Buff Tracker addon.
- **Auction House**: scans the auction house and keeps a price history, shows prices in item tooltips, and
  shops from your own lists. No other auction addon needed.
- **Bags**: one bag window for all your bags, grouped into categories (small ones side by side; or in bag order) with a search box,
  identical items stacked into one button with the total (shown one by one at the bank, trade, mailbox,
  vendors and auction house);
  a bank window and a guild bank window in the same look (bank sort, a Deposit reagents button, guild bank
  tabs, money and log);
  look at your other characters' bags and bank, see everyone's money, and item counts from all characters in
  tooltips. If Baganator is installed, Codex leaves your bags to it.
- **Move windows**: drag any game window (character, spellbook, bags, vendor, mail, auction house and more)
  by its title bar; right-click the title bar to put it back. Positions last for the session, or between
  sessions if you choose.
- **Professions**: the reagent cost, auction value and profit of the selected recipe in the profession window,
  a list of all your recipes sorted by profit, and craft cost and profit in item tooltips (also for items only
  an alt can make). Uses Codex's own auction prices; queued crafts go to a Codex shopping list. Formerly Profit Sort.
- **Commerce Authority**: Craftsman's Writs and Waylaid Crates for the Azeroth Commerce Authority and Durotar
  Supply and Logistics. Writ tooltips show the reputation, what the writ asks for, its auction price, the cost per
  100 reputation and who takes it; crate tooltips the Merchant's Favor and the cheapest way to fill them; the
  vendors that take Merchant's Favor mark what you can buy. `/codex commerce` (or `/aca`) opens a window with your
  standing, Merchant's Favor, your writs grouped by who takes them (with waypoints), the next standings and the
  cheapest reputation by writ, NPC or zone, with a buy list for the Codex shopping lists; "All NPCs" lists every
  NPC who takes writs. Codex learns what your turn-ins really give. Uses Codex's own auction prices and the
  Professions module's craft costs. Formerly Tylesser - Commerce Authority.
- **Vendor search**: a search box on the vendor window that filters its own items by name, type or slot (every
  word must match), with "Unknown recipes" and "Usable" filters, a fade mode that keeps the vendor's pages, and
  marks on the items: how many you have in your bags and bank, and "Known" on recipes you've learned. Buying,
  tooltips and previews work as usual. Alt-drag the box to move it. Formerly Tylesser - Vendor Search.
- **Action bar visibility**: choose when each action bar (and the micro menu, bags bar and experience bar)
  shows: always, on mouse-over, only in combat, only out of combat, in combat or on mouse-over, or never.
  Faded bars come back while you drag a spell. Every bar starts on Always. `/codex barfade`.
- **Stat Delta**: hold Shift over an item to see what you gain or lose against the gear you wear, green for a
  gain and red for a loss, including what your class gets from other stats (Attack Power from Strength, Health
  from Stamina, ...). Optional upgrade score with rough presets per class and role, and green arrows on upgrades in
  your bags and on quest rewards. `/codex statdelta`. Formerly the Stat Delta addon.
- **Vendor**: at a merchant, sells your grey items and repairs your gear (guild funds first if you like), with
  one line in chat; "Also sell" and "Never sell" lists, Sell junk and Repair buttons on the merchant window, and
  Shift while opening the merchant skips it. If Leatrix Plus already does either, Codex leaves that to it.
- **Quality of life**: small options, each with its own switch. Faster loot: with auto-loot on, everything is
  taken at once so the loot window barely flashes (items that need a roll, a confirmation or a free bag slot
  stay in the window). If FasterLoot or Leatrix Plus's faster loot is on, Codex leaves it to them. Quest info in
  tooltips: mobs and items your quests need show the quest and your progress, and bag items that start a quest
  say so. Reveal unexplored areas: zone maps (and the small zone map) show the parts you haven't explored yet,
  a little darker and bluer so you can still tell (switch the tint off to see them plain); if OpenMap, Leatrix
  Maps or Mapster already reveals the map, Codex leaves it to them. Dungeons and town services on the map:
  dungeon and raid entrances on zone and continent maps (hover one for its name, level range, size and zone,
  including WoW Forever's own dungeons), and your faction's innkeepers, flight masters, banks, auction houses and
  mailboxes on zone maps; trainers (your class or every class, your professions or all), vendors (general goods,
  food and drink, reagents), repair, stable masters and others (battlemasters, spirit healers, guild masters,
  weapon masters, riding trainers, barbers) can be switched on. A small funnel button at the top of the world map
  picks what shows. The icons never take a click, so quest pins and the map work as before. If OpenMap or Leatrix
  Maps already shows a group (dungeons, flight masters, spirit healers, OpenMap's townsfolk), Codex leaves that
  group to it. Glow on proc abilities: action buttons glow
  while Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite or Hammer of Wrath can be used, and
  Shadow Bolt with Shadow Trance or your big spells with Clearcasting; what the game already lights keeps its own
  glow. Pick the glow's style (the game's spell alert, pulsing border, marching sparkles, soft glow, flash or
  ring, with a preview), its colour (gold, theme, class or a fixed colour), pulse speed and thickness. Optional
  sound when one starts: 14 of the game's sounds, soft or loud, with a Test button, only in combat if you like,
  and a different sound per ability if you want. While an ability procs, art shows on both sides of your
  character as in later expansions: Codex's own art, a piece drawn for each proc it knows (Overpower, Execute,
  Hammer of Wrath, Shadow Trance, Clearcasting and the paladin's Unsealed Wrath echoes, one per seal, at 3 stacks),
  with "Show all arts" to see them; or the game's own art, the spell's icon, or a plain arc. Several procs at once
  take turns. The art and glow wait while the ability can't be cast (no mana, on cooldown). Size, opacity and a
  "Show the art" test button. In combat the game hides your buffs from addons, so buff procs show there only for
  buffs you track in the game's cooldown manager. Put new spell ranks on your
  action bars: when you learn a higher rank, buttons with the old one get it (after the fight if you're in one),
  with a line in chat; a lower rank kept beside a higher one, or put back by you, is left alone; macros and items
  are never touched; "Update now" does a pass by hand. Future spells in the spellbook: a tab after the spellbook's school tabs
  lists every spell and rank your class learns that you haven't learned yet, by level (from the game's own data,
  for your race; a talent's higher ranks once you have the talent), with what your class trainer asks for it, what
  you can learn now, what the next level brings and what everything adds up to, next to your money. Codex notes
  the prices when you visit your class trainer (shared by your characters of the same class); until then the
  spells show without prices. Gathering skill in tooltips: herb and ore nodes say the skill they need,
  also on the minimap. Zone levels on the world map: each zone's level range beside its name, and the herbs and ores
  found there. Addon buttons in a list: the minimap's addon buttons are hidden, and clicking the moon above the
  minimap lists them. `/codex qol`.
- **Highlights** (off until you switch it on): a pulsing ring and the name on the herb, ore, chest or fishing pool
  you are next to (green, orange, gold, blue), a "!" on quest objects and quest mobs, and glowing quest items in
  your bags. Sets the game's interact-target options while on and gives yours back when off. If NodeSight is
  installed, Codex leaves this to it. `/codex highlight`.

- **Quest windows**: Codex draws the windows you get when you talk to an NPC (greeting, quests, rewards) in
  your theme, in one of three styles: a window as tall as its content (the default), a subtitle bar at the bottom
  of the screen with the NPC in view, or a book page at the side. Number keys 1 to 9 pick the choices (small keys
  beside them), Space accepts, continues and completes, Tab moves to the next reward, and Escape on a quest you
  opened from the NPC's list takes you back to it. Quest levels, reputation rewards ("+75 Booty Bay") and Stat
  Delta's stat changes on reward items. Optional: accept and hand in quests by themselves (not repeatables, quests
  that cost gold or marks, or when a reward must be chosen), open a lone vendor, banker, trainer or flight master at
  once, fade the game's interface while you talk; hold Shift to talk normally. Off keeps the game's own windows.
  If DialogueUI is installed, Codex leaves the NPC windows to it.
- **Quest keys**: Space presses Complete Quest, Continue or Accept and picks quests from an NPC's list, in the
  game's quest windows and in Codex's.

- **Rings** (off until you switch it on): hold a key and a ring of spells, items, macros, mounts or raid markers opens
  around your mouse; point at one and let go to use it, or click it. Works in combat. Ready-made rings for mounts,
  travel (Hearthstone, teleports and portals), professions (and herb and mineral tracking) and raid markers, filled
  from what each character knows; make your own with up to 12 slices by dragging spells, items and macros onto the
  ring's slots. Each ring gets its own key, and Codex tells you when the key is already used. Rings can only be
  changed out of combat. Two looks: the game's ping wheel (the default) or a Codex disc. If OPie is installed, Codex
  leaves rings to it. `/codex rings`, `/codex ring <name>`.
- **Info bars**: a bar along the top or bottom of the screen and a panel under the chat with what you want to keep an
  eye on: gold (across your characters), bag space, location, experience, reputation, professions, clock, frame
  rate and latency, guild and friends online, durability and ammo. Right-click a slot to choose what it shows. The
  chat panel's corner buttons hide the chat and copy its recent lines. Moves the game's frames out of the bar's way.
- **Personal bars** (off until you switch it on): health and power under your character, with the five-second
  rule, the mana and energy tick, druid mana, combo points, your seal's time and swing timers; under the character
  or upright beside it.

If you still have one of the separate Tylesser addons installed, Codex leaves that feature to it, so nothing
shows twice.

## Themes

Pick a look on the Look page; only the theme you pick is loaded:

- **Runestone**: dark stone, gold borders and studs.
- **Hearthwood**: warm wood with brass rivets.
- **Classic**: close to the game's own colours.
- **Slate**: flat, quiet and minimal.
- **Dusk**: calm blue-grey windows you can see the world through, rounded corners, one soft teal accent and the
  Inter font. Easy on the eyes.

Dusk also tones down class and reaction colours on health bars (your frames, nameplates, raid frames and
the damage meter), so they are calmer while each class keeps its colour.

Codex can also restyle the game's own interface in your theme: action bars, player and target frames,
minimap, chat, quest tracker, quest log and world map, tooltips and game windows. Switch it on with "Restyle the
game's interface" on the General page; each part then has its own switch on its page (the action bars' look on
Action bars, the chat on Chat, and so on).

## Use

- `/codex` opens the window; `/codex <module>` (for example `/codex rings`) opens the page and section of that
  feature; `/codex settings` opens General, `/codex profile` Profiles and `/codex setup` the first-run setup.
- The minimap button: click to open, right-click for a quick menu, drag to move it.

## Feedback

Found a bug or have an idea? Tell us at https://tylesser.com/feedback/ (in game: `/codex feedback`).

## Releasing (maintainers)

Tag `vX.Y.Z` after moving the changes into a `## X.Y.Z` section of CHANGELOG.md. The packager builds one zip
with `Codex` and its load-on-demand folders (`Codex_Runestone`, `Codex_Hearthwood`, `Codex_Classic`,
`Codex_Slate`, `Codex_Dusk`, `Codex_Skins`).

## License

MIT. Hearthwood's font, IM Fell English SC by Igino Marini, is under the SIL Open Font License
(`Themes/Hearthwood/Media/IMFellEnglishSC-OFL.txt`); Cinzel is under the SIL Open Font License too. Dusk uses
Inter by The Inter Project Authors (https://github.com/rsms/inter), under the SIL Open Font License 1.1
(`Themes/Dusk/Media/Inter-OFL.txt`).
