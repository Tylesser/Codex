# Tylesser - Codex

An all-in-one interface for **WoW Forever**: every Tylesser tool in one addon, in the look you like, plus a
restyled game interface, bags, quest windows, ring menus, info bars and more. Each feature is a module you can
switch off; a module that is off does nothing at all.

It is made for WoW Forever only. Found something that doesn't work? Please report it (see Feedback below).

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

The panel on the right of the window tells you what the section or option under your mouse changes. For the parts
of the game Codex restyles it shows the game's own look above Codex's.

The Quests, Unit frames, Chat and Info bars pages have a **Fonts** tab: each kind of text there (quest names,
objectives, unit frame names, chat lines, ...) can get its own font, size, outline and shadow. Anything left on
"Own" stays as Codex draws it.

Home shows a card for each feature with what it is doing right now; click a card to go to its section.

## Modules

- **Buffs**: a row of the buffs you choose (when missing, when active or always), shown only where and when you
  want (places such as dungeons and raids, solo or in a group, primary or secondary talents, your group role, in or
  out of combat;
  for the whole row or per buff; optionally a warning, with a click to remove it, when a buff is on where its rules
  say no), click-to-buff, weapon enchants, and click-to-buff and dispel buttons by your party frames (a camp buff
  that doesn't stack with a class buff counts as having it). Paladins in your group running Codex or Buff Tracker
  share their blessings, so two of you don't give the same one. One key (or `/click CodexBuffsNextBuff`) casts the
  next missing buff. Formerly the Buff Tracker addon.
- **Auction House**: scans the auction house and keeps a price history (up to a year: each day's lowest and highest
  price and how many were up), shows prices, the week's average and the trend in item tooltips, and shops from your
  own lists. Click an item on the Auction prices page, or type `/codex history <item>`, for its price chart. "Below vendor" in the panel beside the auction house lists items on sale for less than a vendor pays, with a Buy button (one click, one purchase). No other auction addon needed. "From Auctionator" copies Auctionator's saved
  shopping lists into Codex while Auctionator is installed. "Upgrades" in the panel lists gear on sale that beats
  what you wear by Stat Delta's score (prices of the last two days), biggest gain first.
- **Bags**: one bag window for all your bags, grouped into categories (small ones side by side; or in bag order) with a search box,
  identical items stacked into one button with the total (shown one by one at the bank, trade, mailbox,
  vendors and auction house); keys shown or hidden with one click (the key button above the bags);
  a bank window and a guild bank window in the same look (bank sort, a Deposit reagents button, guild bank
  tabs, money and log);
  look at your other characters' bags and bank, see everyone's money, and item counts from all characters in
  tooltips. If Baganator is installed, Codex leaves your bags to it.
- **Move windows**: drag any game window (character, spellbook, bags, vendor, mail, auction house and more)
  by its title bar; right-click the title bar to put it back. Positions last for the session, or between
  sessions if you choose.
- **Professions**: the reagent cost, auction value and profit of the selected recipe in the profession window,
  a list of all your recipes sorted by profit, and craft cost and profit in item tooltips (also for items only
  an alt can make). Uses Codex's own auction prices; queued crafts go to a Codex shopping list, with reagents that
  are cheaper to craft replaced by what they are made from. Crafting cooldowns of all your characters (the clock on
  the profit list, the page or `/codex cooldowns`; a cooldown shows after its first use with the profession window
  open), with a chat line when one is ready. Owned free can also count your other characters' reagents (Bags
  module or Syndicator). Recipe tooltips say on how many recent days the item was up for sale, with an "Often
  listed" filter. Formerly Profit Sort.
- **Commerce Authority**: Craftsman's Writs and Waylaid Crates for the Azeroth Commerce Authority and Durotar
  Supply and Logistics. Writ tooltips show the reputation, what the writ asks for, its auction price, the cost per
  100 reputation and who takes it; crate tooltips the Merchant's Favor and the cheapest way to fill them; the
  vendors that take Merchant's Favor mark what you can buy. `/codex commerce` (or `/aca`) opens a window with your
  standing, Merchant's Favor, your writs grouped by who takes them (with waypoints) and the crates you have to fill
  (click one at the auction house to search for what fills it; a result opens with the amount your crates still need), the next standings and the
  cheapest reputation by writ, NPC or zone (Writs tab), every crate by its price plus the cheapest fill (Crates tab), with a
  buy list for the Codex shopping lists; a Commerce Authority tab at the bottom of the auction house opens the window beside it (or it opens by itself: an option); "All NPCs" lists every
  NPC who takes writs, grouped by continent and zone; a ready writ you haven't opened gets a Start button. Route
  puts waypoints on the NPCs who take your writs, nearest first, and the world map shows them; the Characters tab
  lists every character's standing, Favor, writs and crates; an optional alert names crates under a price you set. Codex learns what your turn-ins really give. Uses Codex's own auction prices and the
  Professions module's craft costs. Formerly Tylesser - Commerce Authority.
- **Vendor search**: a search box on the vendor window that filters its own items by name, type or slot (every
  word must match), with "Unknown" (recipes, mounts and pets you don't have), "Usable" and "Can afford" filters, a
  fade mode that keeps the vendor's pages, and marks on the items: how many you have in your bags and bank, and
  "Known" on recipes you've learned and mounts and pets you have. Alt-click a stackable item to buy several stacks
  at once. Buying, tooltips and previews work as usual. Alt-drag the box to move it. Formerly Tylesser - Vendor Search.
- **Action bar visibility**: choose when each action bar (and the micro menu, bags bar and experience bar)
  shows: always, on mouse-over, only in combat, only out of combat, in combat or on mouse-over, or never.
  Faded bars come back while you drag a spell. Every bar starts on Always. `/codex barfade`.
- **Stat Delta**: hold Shift over an item to see what you gain or lose against the gear you wear, green for a
  gain and red for a loss, including what your class gets from other stats (Attack Power from Strength, Health
  from Stamina, ...). Optional upgrade score with rough presets per class and role (one for each talent group), and
  green arrows on upgrades in your bags, on quest rewards and in the auction house lists. "Best in your bags"
  (`/codex statdelta best`) lists, per slot, the bag item that beats what you wear, and a worn item's tooltip names
  a better one. `/codex statdelta`. Formerly the Stat Delta addon.
- **Vendor**: at a merchant, sells your grey items and repairs your gear (guild funds first if you like), with
  one line in chat; "Also sell" and "Never sell" lists, Sell junk and Repair buttons on the merchant window, and
  Shift while opening the merchant skips it. If Leatrix Plus already does either, Codex leaves that to it.
- **Mail** (off until you switch it on): at the mailbox, Open all takes every mail's gold and items (Gold only just
  the gold; Cash on Delivery mails are skipped), a button on the To box offers recent names and your characters,
  and Alt-click on a bag item attaches all of it. Postal users keep Postal's.
- **Loot text** (off until you switch it on): floating text for what you get. Items show how many you now have (with your other characters too)
  and what they are worth (Codex's auction prices, else what a merchant pays); grey items add up on one Junk line.
  Also money, reputation, experience (with how many more of the same reach the next level), honor, currencies,
  skill-ups and Legacy points, each with its own switch. The same thing again adds to its line. Two looks: floating up from the middle
  of the screen, or a list beside the chat; move it in Edit Mode. Valuable drops (from a price you pick) and purple
  ones glow, with a sound if you like; a watch list of items you farm shows a banner and plays a sound when one
  drops. It can hide the game's own loot toasts, and the info bar's gold tooltip shows what you looted this
  session, its worth per hour and your best drop. `/codex loottext test` shows a sample.
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
  Shadow Bolt with Shadow Trance, Arcane Missiles with Missile Barrage, Pyroblast at 3 stacks of Heating Up;
  Clearcasting shows only its art. What the game already lights keeps its own glow. Pick the glow's style (the game's spell alert, pulsing border, marching sparkles, soft glow, flash or
  ring, with a preview), its colour (gold, theme, class or a fixed colour), pulse speed and thickness. Optional
  sound when one starts: 14 sounds made for procs (or each proc its own) and 14 of the game's, soft or loud, with a Test button, only in combat if you like,
  and a different sound per ability if you want. While an ability procs, art shows on both sides of your
  character as in later expansions: Codex's own art, a piece drawn for each proc it knows (Overpower, Execute,
  Hammer of Wrath, Shadow Trance, Clearcasting and the paladin's Unsealed Wrath echoes, one per seal, at 3 stacks; in a fight, track Unsealed Wrath in the cooldown manager),
  with "Show all arts" to see them; sixteen styles for any proc (flames, runes, feathers, crescent moons,
  lightning, vines, crystal shards, stars, swords, daggers, arrows, claw marks, skulls, snowflakes, rays of light,
  arcane sigils) in each proc's own colour, the glow colour or one you pick; or the spell's icon, or a plain arc, for all procs or
  per ability. Several procs show
  together: two left and right, a third on top, a fourth below; or top and bottom, or all on one side you choose (left,
  right, top or bottom), and each ability can have a side of its own; move the art where you like (also in Edit Mode).
  Stacking procs build up: one arc, two arcs, then the symbol. Add your own procs (a buff of yours lights a spell),
  picked from your buffs, gear, consumables and spells; glow style and colour per ability, a faint glow while you
  can't cast it yet. The art and glow wait while the ability can't be cast (no mana, on its own cooldown; the global cooldown doesn't count). Size, opacity and a
  "Show the art" test button. In combat the game hides your buffs from addons, so buff procs show there only for
  buffs you track in the game's cooldown manager. A warning before a buff proc ends (off by default): its last
  seconds pulse and flash, with a sound if you like. Put new spell ranks on your
  action bars: when you learn a higher rank, buttons with the old one get it (after the fight if you're in one),
  with a line in chat; a lower rank kept beside a higher one, or put back by you, is left alone; macros and items
  are never touched; "Update now" does a pass by hand. Future spells in the spellbook: a tab after the spellbook's school tabs
  lists every spell and rank your class learns that you haven't learned yet, by level (from the game's own data,
  for your race; a talent's higher ranks once you have the talent), with what your class trainer asks for it, what
  you can learn now, what the next level brings and what everything adds up to, next to your money. Codex notes
  the prices when you visit your class trainer (shared by your characters of the same class); until then the
  spells show without prices. Gathering skill in tooltips: herb and ore nodes say the skill they need,
  also on the minimap. Zone levels on the world map: each zone's level range beside its name (WoW Forever's own
  ranges, new zones included), and the herbs and ores
  found there. Addon buttons in a list: the minimap's addon buttons are hidden, and clicking the moon above the
  minimap lists them. Quest tracker order: the quests of the zone you are in go to the top of the quest tracker,
  nearest first, and the others follow grouped by zone. Bind keys by hovering (Action bars > Buttons, or
  `/codex bind`): point at an action button and press a key to bind it, Escape clears it; Done saves, Cancel puts
  your old keys back. Numbers on cooldowns (off until you switch it on): the time left on every cooling-down
  button and buff, in your theme's font with the restyle on. Grey out what you can't use (off until you switch it
  on): buttons out of range, short of mana or not usable turn grey, and the key text keeps its colour instead of
  turning red. Hide empty slots (off until you switch it on): empty action bar slots are hidden, and show again
  while you drag a spell or item, in Edit Mode and while binding keys. Learn all at trainers (Trade > Trainers): a Learn all
  button on the class trainer's window learns every spell you can learn and afford, cheapest first; professions
  are left to you. Skull mark (Unit frames > Skull mark, off until you switch it on, `/codex skull`): a key and a
  small button that put the skull on your target, only while your group role is the one you gave the skull to
  (by default the tank, in a party or raid); the game doesn't let addons mark by themselves, so press the key as
  you pull. Whisper group leaders (Chat > Whisper group leaders): write a message once, and each group in the
  Looking For Group window gets a Whisper button that sends it to the group's leader in one click. `/codex qol`.
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
- **Codex quest tracker**: Codex's own quest tracker in your theme. Your tracked quests sit under a heading per
  zone, the zone you are in first and the nearest quest first; click a zone to fold it, click a quest to open it,
  Shift-click to stop tracking it, right-click for focus, the map and sharing. Quest items have their own button.
  It is as tall as the game's own tracker (or the height you pick), and the mouse wheel scrolls what doesn't fit.
  Move it while Edit Mode is open. While the game's tracker has something besides quests (a dungeon scenario, a
  tracked recipe or achievement), the game's tracker comes back for that time. If another addon already replaces
  the game's tracker, Codex leaves it alone.
- **Quest keys**: Space presses Complete Quest, Continue or Accept and picks quests from an NPC's list, in the
  game's quest windows and in Codex's.

- **Trade Crier** (off until you switch it on): your messages with your profession links in Trade chat (up to 8,
  `<Tailoring>` becomes your Tailoring link), each with its own time in seconds and its own icon (the profession it
  links until you pick one). While you are in a city each message has its own button that lights up when it is
  ready; one click posts it, and a key posts the one that has waited longest. It can also watch Trade chat for
  buyers asking for something you make, and list them with a Whisper button that only fills the chat box. Also its
  own addon, Tylesser - Trade Crier.

- **Rings** (off until you switch it on): hold a key and a ring of spells, items, macros, mounts or raid markers opens
  around your mouse; point at one and let go to use it, or click it. Works in combat. Ready-made rings for mounts,
  travel (Hearthstone, teleports and portals), professions (and herb and mineral tracking) and raid markers, filled
  from what each character knows; make your own with up to 12 slices: click a slot to pick from a list (spells,
  items, mounts, toys, macros, raid markers, actions, windows such as the character panel, or another ring, which
  opens where you let go), with a search box, or drag spells, items and macros onto it. Each ring gets its own key, and Codex tells you when the key is already used. Rings can only be
  changed out of combat. Two looks: the game's ping wheel (the default) or a Codex disc. If OPie is installed, Codex
  leaves rings to it. `/codex rings`, `/codex ring <name>`.
- **Info bars**: a bar along the top or bottom of the screen and a panel under the chat with what you want to keep an
  eye on: gold (across your characters), bag space, location, experience, reputation, professions, clock, frame
  rate and latency, guild and friends online, durability, ammo, experience per hour (with the time to your next
  level), Legacy points (with what you can spend and the next reward) and your gear set (click it to put on another,
  or to pick a set for each talent group: switching talents puts it on). Right-click a slot to choose what it shows. The
  chat panel's corner buttons hide the chat and copy its recent lines. Moves the game's frames out of the bar's way.
- **Personal bars** (off until you switch it on): health and power under your character, with the five-second
  rule, the mana and energy tick, druid mana, combo points, your seal's time and swing timers; under the character,
  upright beside it, or as arcs beside it; always, only in combat, or each bar only while it isn't full. With
  "Health bars in class colours" the health bar takes your class colour. While you cast, the end of the power bar
  darkens by what the spell will cost.
- **What's new**: after an update, a window lists what changed since your version, once per version.
  `/codex whatsnew` opens it again.

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
- **Obsidian** and **Onyx**: Dusk's look in near-black, with a warm gold or a soft teal accent.
- **Bronze**: the calm one. Warm dark brown close to the game's own frames, one thin bronze line, panels you can
  see the world through, and the game's own font; gold only for titles and what is selected.

Dusk also tones down class and reaction colours on health bars (your frames, nameplates, raid frames and
the damage meter), so they are calmer while each class keeps its colour.

Codex can also restyle the game's own interface in your theme: action bars, player and target frames,
minimap, chat, quest tracker, quest log and world map, tooltips and game windows. Switch it on with "Restyle the
game's interface" on the General page; each part then has its own switch on its page (the action bars' look on
Action bars, the chat on Chat, and so on). The restyled chat keeps every tab in view: when a new whisper tab would
not fit, all tabs get narrower. Restyled nameplates can have their bar width and height set apart (in
Edit Mode: the mouse wheel over the Nameplates box), and the unit frame bars shade top to bottom or left to right.
Codex's unit frames move in Edit Mode; over a frame's box the mouse wheel sizes it, Shift + wheel sets just its
width and Ctrl + wheel just its height.

## Use

- `/codex` opens the window; `/codex <module>` (for example `/codex rings`) opens the page and section of that
  feature; `/codex settings` opens General, `/codex profile` Profiles and `/codex setup` the first-run setup.
- The minimap button: click to open, right-click for a quick menu, drag to move it.
- Interface scale (General): the size of the whole game interface, from 50 % to 115 % (smaller than the game's own
  64 % too), or Pixel perfect for your screen. "Game's own" hands it back to the game's setting.

Languages: English, German, French, Spanish (Spain and Mexico), Russian and Brazilian Portuguese, following your game client.

## Feedback

Found a bug or have an idea? Tell us at https://tylesser.com/feedback/ (in game: `/codex feedback`).

No GitHub account? Join the [Tylesser Discord](https://discord.gg/n2rEB6mRxF) and post in #bug-reports or #ideas with the addon's tag; each post is copied to GitHub and the bot answers with the link.

## Releasing (maintainers)

Tag `vX.Y.Z` after moving the changes into a `## X.Y.Z` section of CHANGELOG.md. The packager builds one zip
with `Codex` and its load-on-demand folders (`Codex_Runestone`, `Codex_Hearthwood`, `Codex_Classic`,
`Codex_Slate`, `Codex_Dusk`, `Codex_Obsidian`, `Codex_Onyx`, `Codex_Bronze`, `Codex_Skins`).

## License

MIT. Hearthwood's font, IM Fell English SC by Igino Marini, is under the SIL Open Font License
(`Themes/Hearthwood/Media/IMFellEnglishSC-OFL.txt`); Cinzel is under the SIL Open Font License too. Dusk uses
Inter by The Inter Project Authors (https://github.com/rsms/inter), under the SIL Open Font License 1.1
(`Themes/Dusk/Media/Inter-OFL.txt`).
