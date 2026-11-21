# Changelog

## 1.0.2

- New, optional: **warn me to remove a buff** that is on where its rules say no (tick it in the "Where buffs show" window). Its icon shows in red with "remove" under it, chat names it once, and a click on the icon removes it (out of combat). Off by default.

## 1.0.1

- Paladin blessings: the party buttons use Greater Blessings only in a raid. In a party (or alone) they cast the normal Blessing, which costs no Symbol of Kings.
- Fixed: a Lua error in a raid ("attempt to compare local 'same' (a secret boolean value)") while the party buttons read who cast a buff. When the game keeps the answer secret, the caster now counts as unknown.

## 1.0.0

Codex leaves beta: the first full release.

- New: **Bind keys by hovering** (Action bars > Buttons, or `/codex bind`). Point at an action button and press a key to bind it; Escape clears the button's keys. Done saves, Cancel puts your old keys back. Not in a fight.
- New: **Numbers on cooldowns** (Action bars > Buttons, off until you switch it on): the time left on every button and buff that is cooling down. Switching it off gives back the game setting you had.
- New: **Learn all at trainers** (Trade > Trainers): a Learn all button on the class trainer's window learns every spell you can learn now and afford, cheapest first. Professions are left to you.
- Info bars: two new things a slot can show. **Experience per hour**, with the time to your next level. **Gear set**: the set you wear; click it to put on another.
- Shopping lists: **From Auctionator** copies Auctionator's saved shopping lists into Codex (exact names stay exact). Lists you already have get only the terms they lack.
- Fixed: on the Rings page the help text ran into the Ring size row.

## 1.0.0-beta5

- Fixed: a Lua error ("calling 'IsShown' on bad self") when a quest window opened in style B or C with "Fade the game's interface" on.

## 1.0.0-beta4

- The Codex window's pages have tabs now: each feature (or a few related ones) on its own tab instead of one long page of folded sections. Your last tab on each page is remembered.
- Loot text: a third look, "Floating down".
- Quest windows: the three style pictures are little painted scenes now (an NPC in a meadow and the window in your theme) instead of flat boxes.
- New: **Loot text** (Bags and items > Loot text, off until you switch it on). Floating text for items (how many you now have, what they are worth), money, reputation, experience, honor, currencies and skill-ups, floating up or as a list beside the chat. Valuable and purple drops glow, a watch list announces the items you farm, the game's loot toasts can be hidden, and the info bar's gold tooltip shows this session's loot.
- Echo of <seal> in combat: the glow and art now wait for the third stack in a fight too (before, the game hid the count, so they showed from the first stack). Codex counts the stacks from the cooldown manager's Unsealed Wrath icon (keep it tracked there, as before) and tells the echoes apart by the seal you have on.
- Fixed: a Lua error at some writ hand-ins ("attempt to compare local 'name'"): when the game keeps the NPC's name hidden, that hand-in simply isn't used to learn where the customer stands.
- **Resurrect the dead.** When a party or raid member dies (and hasn't released), their buff buttons give way to one button with your class's resurrection spell (Resurrection, Redemption, Ancestral Spirit, Rebirth...): click it to raise them. It dims while someone else is already resurrecting them. Like every party button it appears out of combat. Untick **Resurrect the dead** under Buffs > Party buff buttons to turn it off.
- Codex art: the glow round the emblems no longer ends in a hard, square-looking edge (Hammer of Wrath's showed it most); every piece fades out softly towards its edges.

## 1.0.0-beta3

- The fold arrows (Codex window sections, the quest tracker's zones, Commerce Authority's zones) are smooth now instead of jagged.
- Fixed: a character could be listed twice (in the gold list, the bag window's characters and recipe knowledge) when the game gave no realm name for a session, or gave the name with the surname in one session and without it in another. The two records become one; nothing is lost. Character lists now show the full name with the surname. Auction prices stay with your realm in such a session too.
- Fixed: Copy chat showed an empty box: the text is there now (on WoW Forever a text box nested in a scroll area isn't drawn).
- Fixed: Codex quest tracker's quest item buttons couldn't be clicked (the quest's line took the click).
- Fixed: Codex quest tracker put another zone's quests under your zone after you opened the world map on that zone.

## 1.0.0-beta2

- Buffs: choose where and when the tracked buffs show: places (open world, cities and inns, dungeons, raids, battlegrounds and arenas), solo or in a party or raid group, and in or out of combat, for the whole row (Where the row shows) or for one buff (its Where button). For example: hidden in dungeons and raids, shown in a party out in the world.
- New module, **Codex quest tracker** (Quests page, on by default): Codex's own quest tracker in your theme. Your tracked quests sit under a heading per zone, the zone you are in first and the nearest quest first; click a zone to fold it, click a quest to open it, Shift-click to stop tracking, right-click for focus, the map, sharing and more. Quest items have their own button. It is as tall as the game's own tracker (or the height you pick); quests that don't fit scroll with the mouse wheel. Move it while Edit Mode is open. While the game's tracker has something besides quests (a dungeon scenario, a tracked recipe or achievement), it comes back for that time and Codex's steps aside. If another addon already replaces the game's tracker, Codex leaves it alone.
- Quest tracker order (Quests page, on by default): the quests of the zone you are in go to the top of the quest tracker, nearest first, and the others follow grouped by zone. Sorted again when you change zone or subzone, never during a fight.

## 1.0.0-beta1

First beta of Tylesser - Codex, the all-in-one interface for WoW Forever.

- Five themes (Runestone, Hearthwood, Classic, Slate, Dusk) for Codex's windows, and an optional restyle of the game's own interface in the same theme: action bars, unit frames, nameplates, raid frames, minimap, chat, tooltips, quest tracker, quest log, world map, menus, loot rolls, the damage meter and the game's windows.
- The Codex window: one page per part of the game, foldable sections with every option of a feature in one place, a search box for any option, profiles with export and import, and a first-run setup.
- Every Tylesser addon is built in: Buff Tracker, Profit Sort, Vendor Search, Stat Delta and Commerce Authority. If you still have one of them installed, Codex leaves that feature to it.
- New in Codex: its own auction house scans and shopping lists, a bag, bank and guild bank window with your other characters' items, quest windows in three styles with keyboard keys, ring menus in the style of the game's ping wheel, info bars, personal health and power bars, highlights on herbs, ore and quest objects, action bar visibility, moving game windows, junk selling and repairs, and a set of quality-of-life options (faster loot, quest and gathering info in tooltips, map reveal, dungeons and town services on the map, proc glows with Codex's own proc art, new spell ranks on your bars, future spells in the spellbook, the minimap's addon buttons in a list).
