# Changelog

## 1.6.1

- Bags: "Combine identical items" no longer stays off after you leave a vendor, bank, mailbox or auction house without its close being noticed: the game is asked whether that window is still open.
- Bags: the two Free boxes say which bags they count, "bags" or "reagent" under the number, with a tooltip.

## 1.6.0

- Proc art: **Top and bottom** as an Art side (also per ability): one proc's art above and below you, a second on the other edge, then left and right.
- Commerce, **Start**: a writ that is ready but not opened yet (your bags hold what it asks for) gets a Start button: in the window's Deliveries (one writ per click) and on its line in the Writ NPCs window. It opens the writ's quest as a right-click on it does; not in a fight, and not while a vendor, bank, mail, trade or auction house window is open (the writ would go there).
- Commerce: **more writ NPCs**: 133 of the 150 writs now know who takes them (20 more Artisan writs: Blasted Lands, Deadwind Pass, Winterspring, Silithus and more). The other 17 are still learned at your first turn-in.
- Commerce, **Writ NPCs window**: zones are grouped under their continents (Eastern Kingdoms, Kalimdor), each folding like a zone; Fold all folds the continents.
- Proc glow, new options: **your own procs** (a buff of yours lights a spell on your bars, with art and sound like the others; pick both from a window of your buffs, gear, bag consumables by type and spells by spellbook tab, no spell IDs needed; in a fight track the buff in the cooldown manager), a **faint glow** while you can't cast the spell yet (no rage or mana, or its cooldown), a **glow style and colour per ability**, **stacking procs building up** (Heating Up and the seal echoes: the inner arc at one stack, both arcs at two, the symbol when the stacks are full), **Move the art** (also while Edit Mode is open), **art only in combat**, **Play** in the preview panel (the proc's art, glow and sound for a few seconds) and the **time between sounds**.
- Professions: opening a reagent from the Reagents search in the auction panel puts the amount the recipe needs into the game's buy view (what you're missing for the crafts in the count box, or all of it when you have enough).
- Proc sounds: the fourteen proc sounds are new, real recordings (blades, shield, axe, fanfare, choir, whispers, fire, chimes, lightning, ...) instead of the synthesised ones.
- Professions: the Reagents button at the auction house searches every reagent of the recipe, also the ones you already have.
- Proc glow options: the per-ability lists (sound, art side, art) show only your class's procs and fold up under a header, and a row lights up under the pointer. The art and side lists have a preview beside them: the art of the proc you point at (or last picked for) on its side. With the art per ability, each ability can also get a colour of its own (the square after its art; right-click goes back to the Art colour). The glow style's preview shows one of your class's buttons. The Art colour has a Reset button (back to each proc's own colour), and "Show all arts" follows colour changes while it is open.

## 1.5.1

- Heating Up: the stack count now comes from Pyroblast's cast time (each stack takes 25 % off it), so a critical strike that gives two stacks at once is counted right, and Pyroblast lights at 3 stacks in combat even when Heating Up isn't tracked in the cooldown manager. `/codex procglow` shows the reading.

## 1.5.0

- Quest windows: a long gossip option goes on to a new line (up to three) instead of being cut off with "...".
- Gathering skill in tooltips: Heavy Thorium Vein shows that it needs 300 Mining.
- Proc art: a new **Art side** option shows the art on both sides of your character (as before), or only on one side: left, right, top or bottom. With one side, a second proc goes further out on that side, a third and fourth on the two sides next to it.
- Proc art: **Choose the side per ability** gives each proc a side of its own (both, left, right, top or bottom); the others keep following Art side.
- Proc sounds: fourteen new sounds, each made for a kind of proc: blades clash (Overpower), shield bash (Revenge), axe blow (Execute), victory horn, parry (Riposte, Counterattack), beast snap (Mongoose Bite), holy hammer (Hammer of Wrath), holy echo (the paladin's echoes), shadow whisper (Shadow Trance), arcane shimmer, nature chimes and lightning crackle (Clearcasting for mages, druids and shamans), arcane missiles (Missile Barrage) and fire catching (Heating Up). Pick **Each proc's own sound** and every proc plays the one made for it.
- Proc art: sixteen new art styles for any proc: flames, runes, feathers, crescent moons, lightning, vines, crystal shards, stars, and game themes: swords, daggers, arrows, claw marks, skulls, snowflakes, rays of light and arcane sigils. Pick one for every proc under **Art**, or turn on **Choose the art per ability** to give each proc its own; "Show all arts" shows them too.
- Proc art colour: styles and the arc now show in each proc's own colour (fire orange for Heating Up, purple for Shadow Trance, gold for Hammer of Wrath, ...). **Art colour** switches to the glow colour, or to any colour you pick in the game's colour picker (**Pick**). The drawn pieces keep their own colours.
- Proc art: the "game's art" look is gone. Whoever had it chosen gets the drawn art; procs without a drawn piece show their icon.
- Proc glow and art stay lit through the global cooldown after another spell (Heating Up's art used to blink out after every Fireball). A proc still goes dark while its spell is on its own cooldown or you lack the mana.

## 1.4.0

- Commerce Authority: the **Waylaid Crates** you still have to fill show in the window under Deliveries, with the cheapest way to fill each. At the auction house a click searches for everything that fills it; elsewhere it puts the cheapest fill on the Codex buy list.
- Commerce Authority: when a writ's item is cheaper to craft than to buy, a click at the auction house searches for its **materials** instead of the item, and the buy list holds the materials.
- Proc glow is also its own addon now, **Tylesser - Proc Glow**, for players who don't use Codex. While it is loaded, Codex leaves proc glow to it.
- The game's **cast bar** in Codex's look (with the unit frame restyle): a flat fill in your theme's accent (grey when the cast can't be interrupted, red when interrupted), the spell's name inside the bar and the **time left** on its right. Its place and size stay with Edit Mode.

## 1.3.0

- Unit frames: set the **width and height apart** in Edit Mode: Shift + mouse wheel over a frame's box for the width, Ctrl + wheel for the height (the plain wheel still sizes the whole frame). Shift + right-click puts all three back.
- Fixed: the **cooldown swipe** on restyled action buttons now covers the whole icon (it stopped short of the edges).
- Proc art: **several procs show together** instead of taking turns. Two go left and right, a third on top, a fourth below.
- Nameplates: set the **bar width and height** apart: in Edit Mode turn the mouse wheel over the new Nameplates box (Shift + wheel for the height), or pick them in the Nameplates options.
- Proc glow: **Heating Up** at 3 stacks lights Pyroblast, with its own Codex art.
- Proc glow: **Clearcasting** now shows only its art beside your character, no glow on the action buttons.
- Fixed: **Bind keys by hovering** now covers the whole button, also the frame the restyle draws round it.
- Fixed: the **bag window didn't open in a fight** when it hadn't been opened since logging in, or since your bags changed. It now gets ready when the fight starts.
- Unit frames: a new **Bar gradient** choice, top to bottom (as before) or left to right.

## 1.2.0

- New: **What's new** opens once after Codex is updated, with what changed since the version you had. Open it any time with `/codex whatsnew` or from General; switch it off there or in the window.
- Personal bars: **what the cast will spend**. While you cast, the end of the power bar darkens by the spell's cost, with a line where your power will be. On by default; not on the arc layout.
- New: **Hide empty slots** (Action bars > Buttons, off until you switch it on). Empty slots come back while you drag a spell, in Edit Mode and while binding keys.
- New: **Grey out what you can't use** (Action bars > Buttons, off until you switch it on): buttons out of range, short of mana or not usable turn grey, and the key text keeps its colour instead of turning red.
- New: **Interface scale** (General): the game's interface from 50 % to 115 %, below the game's own 64 % too, or pixel perfect for your screen.
- Loot rolls: Need, Greed and Pass keep their own colours on Codex's buttons.
- Rings: **click a slot to choose** what goes in it from a list (spells, items, mounts, toys, macros, raid markers, actions, windows and your other rings), with a search box. Dragging still works.
- Rings: **rings inside rings**. Put another ring in a slot; choosing it opens that ring where you let go. Works in combat.
- Unit frames: incoming heals show in the health bar's own colour, faded, instead of green.
- Fixed: the quest tracker tried to change a row's click area during a fight, which the game blocks.
- Two new themes, darker than Dusk: **Obsidian** (near-black with a warm gold accent) and **Onyx** (cool black with a soft teal). Pick one in Settings > Theme.
- Unit frames: mana and energy fill smoothly while they regenerate (as Personal bars do); with class-coloured health the name inside the bar is white so it can be read; a stronger gradient on the health bars.
- Rings: slices can now **open windows**: character, spellbook, talents, professions, Legacy, quest log, guild, group finder, collections, bags, world map and the game menu ("Open a window" in a slot's menu). They work in combat, like the game's own buttons.
- Unit frames: choose where the **auras** go for the target, focus and party frames: below (as before), above, right or left of the frame.
- Fixed: the highlight of **Bind keys by hovering** now covers the whole button, icon included.
- Nameplates: the target's glow is now optional (**Glow round the target's nameplate**); the accent line stays.
- Proc glow: **Missile Barrage** lights Arcane Missiles, with its own Codex art.
- Unit frames: **resize them in Edit Mode**. Turn the mouse wheel over a frame's box (5 % a notch, 50 to 200 %); Shift + right-click puts it back to 100 %. The party frames resize together.
- Unit frames: a new option, **Players by first name only (no surname)**.
- Experience and reputation bars in Codex's bar design: a gradient fill like the unit frames and Personal bars, rounded on the Dusk theme, and the rested marker as a thin line in the theme's colour.
- Fixed: Codex's drop-down menus (the pickers on the pages, the Info bar's slot menus, the minimap menu) didn't close on a click elsewhere the first time one was opened after a login or reload.
- Personal bars: a new layout, **arcs beside the character**. Health curves on the left, power on the right, filling from the bottom; the five-second rule and tick sparks follow the curve. Pick it under Layout; Side gap, height and width work as for the upright bars.
- Personal bars: a new Show choice, **When not full**. Each bar shows only while it isn't full: health while you're hurt, mana and energy while they're below their max, rage while you have some. Edit Mode still shows them all.
- Personal bars: with **Health bars in class colours** (Unit frames) on, the health bar takes your class colour.

## 1.1.1

- Fixed: quest pins on the continent map grouped quests of different zones into one pin that sat between them. Each quest now counts for the zone where it stands, so a pin's count is that zone's quests only.
- Dungeons on the map: added **Alcaz Prison** (Dustwallow Marsh, in the keep's basement on Alcaz Island) and **Blackmaw Hold** (Azshara, at the tunnel's entrance). Every WoW Forever dungeon now has its entrance on the map.

## 1.1.0

- New: **talents in "Where buffs show"**. Show a tracked buff only with your primary or your secondary talents (dual spec). Switching talents updates the row.
- New: **one upgrade score for each talent group** (Stat Delta). Switching talents brings back that group's preset and points; the first switch starts from a copy. The score line says which talents it is for.
- New: **a gear set for your talents** (Info bars, Gear set slot). Click the slot to pick a set for your primary and for your secondary talents; switching talents puts it on (out of combat).
- New Info bar slot: **Legacy points**. Your account's points, what this character has left to spend, and the next reward.
- Loot text: a line when you earn **Legacy points** (with its own switch).
- Party buttons: a member with a **camp buff** (Boosted Stamina from a First Aid Kit, Boosted Intellect, Boosted Attack Power...) already has the class buff it stands in for, as the two don't stack, so no button offers that buff.
- Zone levels on the world map use **WoW Forever's own level ranges** (as its Looking for Group tool shows them) instead of Classic's, and include Riverglades, Mount Hyjal and Zephras Isle.
- Dungeons on the map: added **Krol'dok Stronghold, The Drowned City and The Shaper's Terrace**; town services updated.
- Fixed: Future spells for **Skyborne** characters. Spells for some races only (such as the mage's city teleports and portals) were missing or wrong for them.

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
