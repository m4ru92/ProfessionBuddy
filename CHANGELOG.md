# Changelog

Every ProfessionBuddy release, newest first. Each entry lists what is new, what changed and what was fixed, and whether it works with older versions.

## 2.2.0

The vendor shuffle, asked for by Skeleton: which crafts a vendor pays more for than their materials cost, for your characters, your friends and your guildmates.

**Highlights**

- **Shuffle tab:** a new tab in the main window, and among the profession window's bottom tabs, lists the crafts a vendor pays at least a minimum profit for, best first: the materials' cost, what the vendor pays, the profit, and about how much an hour.
- **Vendor shuffle view:** the profession window's View menu shows the same for one profession.

<!-- more -->

**Added on both clients**

- **Shuffle tab:** one row per craft, with who knows it (you first, then your alts, friends and guildmates) and four figures: Cost, Vendor pays, Profit and Per hour. Profit is what the vendor pays for everything the craft makes, minus the materials' cost, priced as the detail panel prices them; materials you already have count at their price. Per hour is about: the profit over each craft's cast time (at least 1 second) plus 0.5 seconds between casts. A craft with a material that has no price is left out. Filters: Who (everyone, you and your alts, friends, guild), profession, the minimum profit, and "Vendor materials" for crafts whose every material comes from a vendor. Click Profit or Per hour to sort, hover a row for each material's price, and click it to open the recipe: your own in your profession, ready to craft (on TBC Anniversary when that profession is open), anyone else's in their saved list. From a profession window, its Shuffle bottom tab keeps your profession open behind the main window, as the other bottom tabs do.
- **Vendor shuffle view:** in the profession window's View menu while prices show: the known recipes that earn at least the minimum from a vendor, most profit first, each with its profit and per hour.
- **Your own saved list:** opening your current character's saved recipes (the Characters tab's View) shows "Open Cooking from your spellbook to craft" where Request Craft used to be, since there's nobody to request from.
- **Vendor shuffle minimum:** in Settings, under Prices, and in the Shuffle tab: any profit, or from 50c up to 1g. 1s by default.

**Changes**

- **/pb keeps your profession open:** typing /pb or /pb friends with a profession open keeps it open behind the main window, with "Back to Cooking", as the bottom tabs have since 2.1.0. They used to close it.

## 2.1.1 - 2026-11-10

Crafts that make more than one item, reported by Hircus: Smelt Bronze makes two bars, and ProfessionBuddy didn't say so anywhere. Also the crafting station a recipe needs, asked for by Sushicats.

**Highlights**

- **How many a craft makes:** the detail panel shows it on the item's icon, as Blizzard's window does, and after the category ("Makes 2"). "Can make" counts the items too: "Can make: 54 (108)".
- **TBC Anniversary prices and the Material Calculator:** 97 recipes that make more than one were counted as making one, so their sale and profit were too low and the Material Calculator planned too many crafts of them.
- **Crafting stations:** a recipe that needs a Tanning Rack, an Anvil, a Loom or another station says so with its tools.

<!-- more -->

**Changes**

- **Items per craft from the game's own data, on both clients:** 103 recipes on WoW: Forever and 98 on TBC Anniversary make more than one, from 2 Bronze Bars to 200 Crafted Solid Shot.
- **A random amount:** seven explosives make a random number (Coarse Dynamite 1-3, Heavy Dynamite 1-5). The detail panel shows the range, and prices use the middle of it: "Makes 1-3 (priced as 2)".
- **The price line wraps in whole pieces:** when cost, sale and profit don't fit on one line, the profit (or the sale) moves down whole, so an amount never splits across two lines.
- **Crafting stations, asked for by Sushicats:** a recipe that needs a station (a Tanning Rack, an Anvil, a Loom) shows it with its tools: "Tool: Tanning Rack". On WoW: Forever, on the known recipes of your open profession, it's green at one and red "(not nearby)" when you're not, from the game's own check, and the detail panel follows you as you walk. Elsewhere it's white, and always on TBC Anniversary, whose game says you're at a station from any distance. From the game's data, on both clients: 1,039 recipes on WoW: Forever and 639 on TBC Anniversary.
- **The price of one item:** the price line's tooltip says what one item sells for when a craft makes more than one: "One item: 2g 99s 93c at auction, 5c from a vendor".
- **The login line shows with ElvUI:** "ProfessionBuddy v2.1.1 loaded" prints at login. It used to print while the addon loaded, and ElvUI's chat setup dropped it.
- WoW: Forever recipe data is from game build 1.60.1.70888. The recipes are unchanged; Berdun's Trusty Rifle gains disenchant estimates.

**Fixes**

- TBC Anniversary: PB's recipe data had the count per craft for Smelt Bronze alone. Elemental Blasting Powder (4), Fel Iron Shells (200), Goldthorn Tea (4) and 94 more read 1, so their sale and profit were for one item, and the Material Calculator asked for several times the crafts and materials when one of them (Elemental Blasting Powder, Silver Contact, Gold Power Core) was a step in a bigger craft.
- TBC Anniversary: Handful of Copper Bolts and Handful of Fel Iron Bolts make 1, not 2 and 3.
- Your open profession's icon did nothing after you looked at a greyed-out profession or a character's stored recipes (WoW: Forever), or took a second click (TBC Anniversary). Those lists close your open profession now, so its icon opens it with one click.

## 2.1.0 - 2026-11-09

Prices, built from players' requests: what a craft costs, what it sells for, and the profit, from Auctionator, TSM, the auction prices ProfessionBuddy records, and vendor prices. Also: your professions in the main window, a Back button to the profession you were in, window positions and filters that stay after a reload, and guildmates' recipes that are there when you click them.

Thanks to Riddles in the Dark, whose requests shaped this update.

**Highlights**

- **Craft cost and profit:** under "Can make", the detail panel shows what one craft costs, what it sells for, and the profit. Hover the line to see each material's price and where it came from.
- **Material Calculator prices:** Price and Cost columns, and what the materials you still need cost to buy.
- **Profit in the recipe list:** an optional Profit column, a Profit sort, and "Hide crafts at a loss".
- **Your professions in the main window:** the profession icons along its top, and "Back to Leatherworking" after a bottom tab took you away from a profession.

<!-- more -->

**Added on both clients**

- **Prices:** ProfessionBuddy reads Auctionator's and TSM's prices when they're installed, then the auction prices it records itself, then vendor prices. You can switch Auctionator and TSM off in Settings, under Prices. A material a vendor sells is never priced above the vendor's price. A material one of your characters crafts costs whichever is cheaper, buying it or crafting it, and the tooltip shows both prices, the cheaper one bright and the other tan. A price older than 7 days shows gray. A material with no price shows "?", and the cost reads like "Cost: 1g 20s+ (1 material has no price)".
- **Profit:** the auction price minus the 5% auction house cut, minus the cost. Without an auction price, PB uses the vendor's price. The detail panel shows both sale prices ("Sells: 2g 5s, vendor 40s"). With "Only show the better sale price" selected in Settings, it shows the higher of the auction price after the cut and the vendor's price, and profit uses that one. Clear "Show vendor sale price" to leave the vendor's price out everywhere. Enchants show only the cost.
- **Auction prices ProfessionBuddy records:** while you browse the auction house, PB keeps the lowest price it sees for every material and crafted item of its recipes, for your realm and faction. Prices seen at a neutral auction house (Booty Bay, Gadgetzan, Everlook) aren't recorded, and recorded prices older than 30 days are dropped.
- **Scan my materials and Full scan:** on a ProfessionBuddy tab after the auction house's own tabs (it reads "PB" when the tabs don't all fit). "Scan my materials" searches every material and crafted item of the recipes your characters know, one at a time, and you can stop it. "Full scan" reads the whole auction house at once, after a warning: the game can freeze for a few seconds, and it allows one about every 15 minutes. The tab shows only while neither Auctionator nor TSM is installed and switched on in Settings, under Prices; recording while you browse works either way.
- **Recipe list:** "Profit in the recipe list" adds each recipe's profit to its row and a Profit choice to the Sort menu. "Hide crafts at a loss" hides recipes that lose money.
- **Crafts that bind when picked up:** they can't be sold at auction, so their profit uses the vendor's price alone ("Sells: 25c (vendor, BoP)"). In the recipe list they show a gray "BoP" instead of a profit and sort last by Profit. "Hide crafts at a loss" hides the ones that lose money.
- **Materials that bind when picked up:** they never take an auction price. One you craft keeps its craft cost, and one a vendor sells keeps the vendor's price. Otherwise it shows "? (BoP)", the cost line reads "(1 material binds when picked up)" instead of "has no price", and the Material Calculator shows BoP in its price columns.
- **Vendor prices:** built in for every material a vendor sells, from the cmangos (TBC Anniversary) and VMaNGOS (WoW: Forever) vendor lists, counting only vendors placed in the world, and the game's own item prices. When you open a vendor, PB records what it charges you for materials, and that price replaces the built-in one.
- **Material Calculator:** with prices on, the window is wider, with a Price and a Cost column, and "To buy" and "All materials" totals under the summary.
- **Settings, Prices section:** Show prices, Auctionator prices, TSM prices with the TSM price source (DBMarket by default), when prices turn gray, how crafted materials show, the two sale price boxes, the two recipe list boxes, and Clear recorded prices.
- **Profession icons in the main window:** the icons the profession window has, along the top of the main window on every tab. A click opens that profession; one you don't know opens its read-only list. On TBC Anniversary the icons cast the profession, so the main window can't open or close during combat there: it waits until combat ends, with a chat line.
- **Back to your profession:** the profession window's bottom tabs (Characters, Friends, Guild, Orders) keep your profession open behind the main window, and "Back to Leatherworking" brings it back as you left it: selection, filters, scroll, and the Material Calculator. The profession's own icon in the main window does the same. Closing the main window closes that profession too.
- **Keep after a reload or logout:** a box under "Remember window state between opens", on by default. The profession window's filters, sort, search, and selection, and where the profession window and the main window sit, stay for each character after a /reload or logout. A window that would land off a smaller screen moves back onto it. With the box cleared, both windows open in the middle of the screen after a /reload.
- **Guildmates' recipes open by themselves:** clicking a guildmate's profession you have no recipes for asks for them and opens the profession when they arrive. Its tooltip says "Requesting... opens when it arrives" while you wait, and "Recipes from 2h ago" once you have them. If nobody answers in 35 seconds, chat says so.
- **Keep guildmates' recipes up to date:** a box under Friend data, on by default. After you log in, and when guildmates come online, PB asks online guildmates who run it for their recipes, one every 3 seconds, starting with the guildmates PB has no recipes for, so clicking their profession opens it at once. PB skips anyone whose recipes it got in the last 12 hours.

**Added on WoW: Forever**

- **Waylaid Supplies and Craftsman's Writs:** their tooltips show the fill cost: what the requested items cost ("Fill cost: 6s", "20 x Copper Bar"), priced the same way as a craft's materials. A writ also shows what the writ itself sells for at auction. Reward details (money, experience, reputation) come in a later update.

**Changes**

- WoW: Forever recipe data is from game build 1.60.1.70862.

**Fixes**

- With TradeSkillMaster's Crafting window open, clicking a recipe, a material, or a Material Calculator row went to TSM and PB didn't select the recipe. A plain click stays with PB; Shift, Ctrl, and Alt clicks still go to the game and to other addons (chat links, the dressing room).
- "Remember window state between opens" lost the View, Skill-up, and Source choices when you closed the profession window with its X button or Escape: only closing it with the profession's own button saved them.
- WoW: Forever: pressing K in combat after opening a profession gave an error and opened nothing. K works in combat. Blizzard's profession book reopens the profession you last had open, in Blizzard's window, and ProfessionBuddy's window takes over when combat ends. The same goes for any profession you open in combat.
- In combat, the game doesn't let an addon open, close, or move the profession window. The bottom tabs (Characters, Friends, Guild, Orders), /pb and its commands, Settings, and opening a friend's or guildmate's recipes gave an error there, or left both windows on screen. They wait for combat to end, with one chat line such as "Characters opens when combat ends.", and dragging the window waits too.
- With a profession window open in combat, a bag change or the game's recipe update redrew the craft bar and gave an error each time. The Enchant button sat on the craft bar, which made the game protect the bar too. The button is placed on the window instead, and it stops taking clicks as combat starts, until combat ends.

## 2.0.2 - 2026-11-07

A follow-up to the WoW: Forever launch, built from players' requests. It adds disenchant results, skill-up ranges at the trainer, a resize grip, a guild right-click menu, and Battle.net friends and a profession link on Forever. It also fixes the surprise reload.

Thanks to the guild members whose requests and reports shaped this update.

**Highlights**

- **Disenchants into:** item tooltips list what an item disenchants into, with each material's count and chance, on every character.
- **Skill-up ranges at the trainer:** each recipe you haven't learned shows the skill levels where it turns yellow, green, and gray.
- **Window size:** drag the grip in a window's bottom-right corner to scale it from 75% to 150%.
- **Battle.net friends on WoW: Forever:** the Battle.net button adds picked friends' Forever characters as contacts, as on TBC Anniversary.
- **Profession link (WoW: Forever):** the chat bubble button beside the skill bar posts your profession's link, as in Blizzard's own window. Guildmates, group members, and ProfessionBuddy friends who run ProfessionBuddy can open it.
- **Guild right-click:** right-click a guildmate on the Guild tab to whisper them or invite them to your group.

<!-- more -->

**Added on both clients**

- **Disenchants into:** a tooltip section on every item you can disenchant, below Held by: each material, its count, and its chance, from the cmangos (TBC Anniversary) and VMaNGOS (WoW: Forever) databases, the same sources as the gathering data. On TBC Anniversary it also reads "Requires Enchanting N", red when none of your characters has that skill. WoW: Forever needs no Enchanting skill to disenchant, so there is no skill line. On WoW: Forever, gear that the 1.12 database has no disenchant results for, such as items added in Forever, gets an estimate. Forever's own disenchant groups place it by quality, item level, and type, and the section says "estimate". To turn the section off, clear the "Show disenchant results" checkbox in Settings, under the Held by slider.
- **Skill-up ranges at the trainer:** at a profession trainer, each recipe you haven't learned shows the skill levels where it turns orange, yellow, green, and gray. The numbers sit inside the "Requires" line's parentheses, after the learn level the trainer already shows: "Requires: Leatherworking (50 80 95 110)". On WoW: Forever every row shows them; TBC Anniversary's trainer shows "Requires" only for the selected recipe, so they go there. A line too long for one line keeps the trainer's own text. On both clients, the recipe's tooltip lists each color with its skill level. PB marks the color the recipe would have at your current skill. To turn it off, clear the "Show skill-up ranges at trainers" checkbox in Settings, under "Show disenchant results".
- **Window size:** a grip in the bottom-right corner of the main window and the profession window. Drag it to scale the window from 75% to 150%; the window's top-left corner stays put, and the Material Calculator scales with the profession window. Order History, Find a Crafter, dropdown lists, and menus take the size of the window they open from. A window never grows bigger than the screen, and it leaves room beside it for the Material Calculator, Order History, and Find a Crafter. When one of them opens with no room on its right, the window moves left. Dragging the window stops at the screen edge with the open panel beside it. Starting a drag closes an open dropdown list. Right-click the grip to go back to 100%. Each window keeps its size, and the grip does nothing in combat.
- **Guild right-click menu:** right-click a guildmate's row on the Guild tab for Whisper and Invite to group. Both are unavailable for an offline guildmate and for yourself, and Invite is unavailable for someone already in your group.
- **Open ProfessionBuddy beside Blizzard's window:** a checkbox under "Replace default profession window", for when Replace is off. When it's selected, a profession opens both windows, as before. When it's clear, only Blizzard's window opens, and PB still records your recipes. Players who had Replace off keep both windows.

**WoW: Forever**

- The Battle.net button works on WoW: Forever. A picked Battle.net friend's Forever character becomes a contact when they log in, as on TBC Anniversary.
- A profession link button sits right of the skill bar on your own professions: Blizzard's chat bubble, with its tooltip and its "Post in chat" menu for Guild, Party, Raid, and your channels. Clicking it with the chat box open types the link. The skill bar is always shorter by the button's width, so it never changes size.
- WoW: Forever doesn't open other players' profession links, so ProfessionBuddy opens them. Click a profession link from a guildmate, a group member, or a ProfessionBuddy friend, and their recipes open in ProfessionBuddy's window. If ProfessionBuddy doesn't have their recipes yet, it asks them first and opens the window when the recipes arrive. Both players need ProfessionBuddy.

**Changes**

- Shift-clicking a recipe row types the same link Share gives. When the link is still loading, PB says so, as Share does, instead of selecting the recipe.
- In-game text: Gray and Canceled replace Grey and Cancelled. Headings and buttons use sentence case ("Order history", "Item info", "Craft all"), and feature names keep theirs (Material Calculator, Find a Crafter, Guild Board, Request Craft). The difficulty lines read "Orange: will level up". Request Craft says "Requester provides mats", like the Orders tab, and "Split or discuss" replaces "Split / discuss". The skill-up filter and sort read "Skill-up" and "Skill-ups". The Share menu's title reads "Post in chat". The login line reads "ProfessionBuddy v2.0.2 loaded. Type /pb or /profbuddy."

**Fixes**

- Clearing the "Replace default profession window" checkbox reloaded the game at once, without asking. It asks Reload or Later instead, so you can change other settings first.
- The Guild tab's header had a double space ("Guild  (64 members").

**Compatibility**

The addon message version stays 12. 2.0.2 syncs, exchanges orders, and shares the guild board with 2.0.0 and 2.0.1 on both clients.

## 2.0.1 - 2026-11-04

The WoW: Forever launch update adds a Classic look for PB's windows, item counts on tooltips, colorblind markers, and launch build recipe data.

Thanks to Zorden, whose review of PB's windows shaped the Classic look and the quantity buttons, and who reported the Item Info box under ElvUI.

**Highlights**

- **Window style:** a Settings list picks Classic (Blizzard's TBC look) or Modern (PB's look so far, and still the default). A change of style applies after a reload, and PB offers one.
- **Held by:** item tooltips show how many of the item you, your alts, and your friends hold, with bags and bank apart.
- **Colorblind markers:** recipe difficulty, learn levels, and gathering tooltips gain text markers beside their colors. Auto follows the game's own Colorblind Mode.
- **Quantity buttons:** the craft bar and Request Craft gain minus and plus buttons beside the quantity box.
- **WoW: Forever launch data:** recipe data comes from build 1.60.1.70790.

<!-- more -->

**Added on both clients**

- **Window style:** under Colorblind markers in Settings, pick Classic, Modern, or Match the game.
  - Classic draws Blizzard's TBC art: dialog borders and backgrounds, the character sheet skill bar, Blizzard's bottom tabs, plus and minus buttons on headers, a down arrow on lists, and Blizzard's scroll bar knob and arrows on the recipe list. The selected recipe's bar takes its difficulty color, and reagents sit in item slot frames.
  - On TBC Anniversary, Classic also shows the profession's icon, large and faint, in the detail pane.
  - Match the game picks Classic on TBC Anniversary. On WoW: Forever, PB shows the option grey, and its tooltip reads "Coming to WoW: Forever in a later update."
- **Held by:** bag and auction house tooltips list who holds the item. You come first, marked (you), then your alts, then friends under "Friends:", most held first within each. A line reads "Maruwarr 68 (Bags 5, Bank 63)", and a side that holds none drops out. Friends appear only if they share their bags, and guildmates never share bags. A Held by slider caps the list at 1 to 20 or All, 8 by default. The section follows the Show in tooltips checkboxes under Alt Information and Friend Data.
- **Colorblind markers:** a Settings list. Set to On, it adds Blizzard's colorblind prefix to recipe names in the profession window and the Characters tab: [+++] for orange, [++] for yellow, [+] for green, and none for grey. A learn level above your skill reads [35 low]. A gathering line ends with its marker, or with (too low) when your skill is below the requirement. Auto, the default, follows the game's Colorblind Mode under Settings, Accessibility.
- **Quantity buttons:** minus and plus buttons beside the quantity box on the craft bar and on Request Craft step between 1 and 999.
- The AddOns list shows a campfire icon for ProfessionBuddy: Basic Campfire on TBC Anniversary, and Welcoming Campfire on WoW: Forever.

**WoW: Forever**

- Recipe data comes from launch build 1.60.1.70790. Enchanting gains Enchant Boots - Speed, and Leatherworking lists Gray Leather Boots as its own recipe. 38 Alchemy, Blacksmithing, Enchanting, and Leatherworking recipes take their learn level from their recipe, plans, formula, or pattern, and Prefect's Waistguard comes from its Plans, not a trainer. 14 First Aid, Fishing, Herbalism, Mining, and Skinning camp crafts gain skill ranges. The Leatherworking "Shoulder" recipes read "Shoulders", Draught of Predatory Senses reads Potion of Predatory Senses, and four recipes move to the right category. Three Engineering recipes list both of their tools.
- WowUp lists ProfessionBuddy on WoW: Forever, instead of "this game client is not supported yet".
- The grey Battle.net auto-add button's tooltip reads "Coming soon to WoW: Forever."
- Comprehension is gone. On WoW: Forever it is a spellbook skill with no profession window, so PB no longer shows a Comprehension tab, and it drops what 2.0.0 saved for mages.

**Changes**

- The Material Calculator's rows and the detail panel's reagents use the one Held by section. Their own holder list and the In bags and In bank lines are gone.
- The detail panel's Held by list reads like the Held by tooltip: you first, marked (you), then your alts, then friends under "Friends:", most held first, with counts such as "68 (Bags 5, Bank 63)". Viewing someone else's profession no longer lists you as an alt.
- Find a Crafter's "Recipe or item name" hint sits inside the search box.
- In-game text: the main window title reads ProfessionBuddy, and labels that disagreed match. The profession bar reads "Leatherworking 75/150", "Name: Enchanting 113/150" for someone else's, and "Alchemy: Not learned".

**Fixes**

- With ElvUI or another tooltip skin, the detail panel's Item Info box lost its border and background. It keeps the game's tooltip look in both styles, with or without a skin.
- Find a Crafter's hint ran under the Sync guild recipes button, from 1.1.0 on.
- The AddOns list showed a red question mark for ProfessionBuddy.
- The Characters tab said "1 recipes".

**Compatibility**

The addon message version stays 12. 2.0.1 syncs, exchanges orders, and shares the guild board with 2.0.0 on both clients. Friends on 2.0.0 who share their bags show in Held by.

## 2.0.0 - 2026-10-16

ProfessionBuddy runs on WoW: Forever as well as TBC Classic Anniversary, from one download. Major thanks to my friends Blargle and Shrekcheeks, who assisted greatly in testing every build of ProfessionBuddy with me in game on both clients.

**Highlights**

- **WoW: Forever support:** the profession window, crafting, the Material Calculator, alts, friends, crafting orders and the guild board all work on Forever.
- **Show everything or Learn as you go (Forever):** list every recipe in the game, or only the recipes you, your alts or your friends have seen at a trainer, at a vendor or as a recipe item. PB asks the first time a profession opens, and Settings changes it later.
- **Trainers and vendors, shared (Forever):** PB records the trainers and vendors you visit, with learn levels and prices, and shares them with your friends.
- **Gathering tooltips (Forever):** ore veins, herbs and skinnable mobs show the skill they need and what they drop, learned as you and your friends gather.
- **On both clients:** search by material, a Learnable now view, a Share button for recipe links, a minimap button, guild board alerts, every recipe tool in the detail panel, and Battle.net friends as contacts (TBC Anniversary).

<!-- more -->

**WoW: Forever**

- PB's own profession window replaces Blizzard's: your learned recipes with reagents, counts, and the game's difficulty colors and categories. K still opens the profession book.
- Crafting from PB's window: Craft, Craft All and the quantity box, which counts down as each craft finishes.
- Recipe data for every profession comes from the game's own files (build 1.60.1.70338), with learn levels from trainers. A recipe you know shows "Learned at".
- Trainers and vendors: opening a trainer records every recipe it teaches and its learn level. Opening a vendor records the recipe items it sells, with price and stock, and a recipe item in your bags counts too. The Source line names them, those in your current zone first. Friends, group members and guildmates share what they recorded, and the tooltip marks theirs "(from <name>)".
- Show everything or Learn as you go, with "Keep alts separate" for Learn as you go.
- Item tooltips show "Used in" and "Craftable by".
- Ore veins, herbs, skinnable mobs and their corpses show "Requires <profession> (N)" and your skill. Their loot list starts from Classic data and switches to what you and your friends gathered once you have gathered a node or mob 10 times together. "Unlearned too" shows loot for professions you do not have.
- Enchanting rods, recipe tools and the <Random additional stats> line.
- Comprehension for mages: a tab with Study and the Comprehend Scroll abilities. PB never shares it.
- Forever's "First Surname" names and connected realms work for contacts, orders and the guild board. PB moves saved names once at load, and `/pb realmkeys restore` puts them back.
- The reagent bag and the bank tabs count in PB's bag and bank copies.
- The minimap's addon compartment lists PB.
- PB greys out the Battle.net button ("Coming soon"): the Forever beta gives addons no Battle.net friend list.

**Added on both clients**

- **Search by material:** the Search box also matches material names, so "Copper Bar" lists every recipe that uses one.
- **Learnable now:** a View that lists the recipes you can learn at your current skill and level. The Source filter still applies, so Trainer plus Learnable now shows what to buy at the trainer.
- **Share:** a button beside the recipe name opens Guild, Party, Raid or Say with the recipe's link typed, and you press Enter.
- **Minimap button and launcher:** a minimap button and a data broker launcher. Left click opens PB, right click opens Settings. "Show minimap button" in Settings turns the button off.
- **Guild board alerts:** a chat line when a guildmate posts something you can make. Settings, Crafting Order Notifications, picks which posts alert.
- **Every recipe tool:** hammers, spanners, the Philosopher's Stone, a Jeweler's Kit and the rest show in the detail panel and recipe tooltips, green when a character has one and red "(missing)" when not.
- **Battle.net friends (TBC Anniversary):** pick Battle.net friends, and their characters in this game become contacts as they log in. "Also trust them" covers every contact added this way.
- **Show opposite faction friends:** its own setting under Friend Data, off by default. "Show opposite faction alts" covers alts only.
- Skill Up and Source are two filters. A selected recipe stays selected across views and filters.
- PB colors a recipe you do not know by its difficulty on learning ("Difficulty when learned").
- The Friends tab shows up to seven professions per contact, and Settings scrolls.
- `/pb bug` includes the last gathering tooltip PB drew, and the report scrolls.

**Changes**

- A guild board post reaches a guildmate who logs in or joins the guild after the post went up.
- A profession you learn reaches your guildmates' Guild tab without a reload. PB removes a profession you unlearn from your record and from your friends' and guildmates' copies, and chat says "Removed <profession>: no longer learned."
- Auto-sync sends updates only to contacts heard from this session, and PB hides the server's "No player named" lines for its own whispers. A whisper you typed still shows its line.
- PB's copy of the bank refreshes when you move an item into or out of a bank bag.
- The Battle.net window notes that an added contact's data can take a minute or two to arrive.

**Fixes**

- Every receiver dropped a guild board post from a character with an accented name.
- A second quick cancel reported an online friend as offline.
- The TBC Anniversary trainer scan read the wrong value as the learn level, so trainer corrections never stuck.
- A friend typed as Name-Realm with the realm in another case became a contact that never synced. PB also ignores spaces around the hyphen.
- `/pb sync` within 30 seconds of a sync said the friend did not respond. It says when to try again.
- The Guild Board drew one row below the window.
- A friend's recipe or a recipe you do not know showed no tool line.

**Compatibility**

The addon message version goes from 7 to 12. On TBC Anniversary, 2.0.0 syncs, exchanges orders and shares the guild board with 1.1.x. A 1.1.x client still drops board posts from accented names and keeps professions a friend unlearned; updating fixes both. On WoW: Forever, every player needs 2.0.0.

## 1.1.5 - 2026-09-24

Rogues get full Poisons support.

**New**

- **Poisons tab for rogues:** all 25 poisons, grouped by family (Instant, Deadly, Wound, Crippling, Mind-numbing, and Anesthetic). Missing and From Trainer now count the poisons you have not learned yet, and each one shows the character level a rogue trainer needs to teach it.
- Poisons stays with the rogue who has it. ProfessionBuddy does not show it for your other characters, your friends, or your guild, and does not send it to them.

**Fixes**

- On non-English clients, ProfessionBuddy saved Poisons under its translated name. It now saves it as Poisons and removes the translated entry the next time the rogue opens Poisons.

No protocol change: 1.1.5 is fully compatible with 1.1.0 through 1.1.4 clients (COMM_REV unchanged).

## 1.1.4 - 2026-09-24

Hunters get their Beast Training window back.

**Fixes**

- On a hunter, opening Beast Training showed ProfessionBuddy's window, labelled as Enchanting and listing pet abilities, instead of Blizzard's Beast Training window. ProfessionBuddy now leaves Beast Training to Blizzard's window and only takes over Enchanting.

No protocol change: 1.1.4 is fully compatible with 1.1.0, 1.1.1, 1.1.2, and 1.1.3 clients (COMM_REV unchanged).

## 1.1.3 - 2026-09-23

Switching between Enchanting and your other profession now works properly.

**Fixes**

- With Enchanting and a second crafting profession (Tailoring, for example), switching between the two misbehaved. The other profession could replace the Enchanting window whenever your bags changed, switching back could close ProfessionBuddy instead of opening the profession, and closing ProfessionBuddy could leave a profession's action bar icon lit. Opening one now closes the other, so only one is ever open at a time.

**Under the hood**

- The code that reads profession windows was reorganised. Nothing you see changes.

No protocol change: 1.1.3 is fully compatible with 1.1.0, 1.1.1, and 1.1.2 clients (COMM_REV unchanged).

## 1.1.2 - 2026-09-21

Skinning loot on mob tooltips, a mail recipient picker, and two filters that stop showing you things you cannot use.

**New**

- **Skinning loot on the hover tooltip:** hovering a skinnable mob now shows a "Skins into:" list of every item it yields, with the drop chance for each, quality-colored and with stack ranges. A Nagrand clefthoof reads Knothide Leather Scraps 65%, Knothide Leather 25%, Thick Clefthoof Leather 10%. Quest-only drops are listed but greyed and deliberately carry no percentage, because the underlying value is the chance while you are on the quest rather than the rate you would actually see. Built from the same cmangos data the gather feature already uses, and shown only if you have Skinning. Toggle it with "Skinning loot" in the options.
- **Mail recipient picker:** a "PB" button beside the mail To field opens your saved contacts, favorites first, and fills the recipient in one click.
- **Order source: board vs direct.** Orders claimed from the guild board now carry a "board" tag next to the existing Friend and Guild badge, so you can tell a board claim from an order somebody sent you directly.

**Fixes**

- The reagent tooltip listed recipes only the opposite faction can obtain. On a Horde character, Tender Crocolisk Meat offered Crocolisk Gumbo, which is Alliance-only. The recipe browser had always hidden these; the tooltip never did. Both now follow one rule, and a new "Hide opposite-faction recipes" option turns it off if you want to see the other side's recipes.
- The mail button sat at the wrong height under ElvUI.
- The login profession scan no longer errors on clients that have no skill-line API.

No protocol change: 1.1.2 is fully compatible with 1.1.0 and 1.1.1 clients (COMM_REV unchanged).

## 1.1.1 - 2026-09-19

Favorites, a friend-vs-guild badge on orders, and a sync-reliability fix.

**New**

- **Favorite contacts:** pin your go-to friends and guildmates with the star on each row. Favorites sort to the top of the Friends and Guild lists, and the Guild tab gets a favorites-only filter. Account-wide and local to you.
- **Favorite order items:** a star on the Guild Board post box pins the item you typed and lets you quick-fill the field from your pinned items, so re-posting your usual orders is one click. Account-wide and local to you.
- **Order source badge:** every order on the Orders tab is labeled by its counterparty, Friend (a saved contact) or Guild (a guildmate), so a mixed list reads at a glance.

**Fixes**

- A sync or order that arrived before trust was established (for example, before your guild roster finished loading) was dropped with no retry, so a guildmate's data could quietly fail to appear. It is now held briefly and replayed the moment trust resolves.

No protocol change: 1.1.1 is fully compatible with 1.1.0 clients (COMM_REV unchanged).

## 1.1.0 - 2026-09-16

The guild update: crafting orders now reach your whole guild, plus a lighter inventory sync and a broad reliability pass.

**New**

- **Guild order board:** post a crafting request to your guild, browse and claim what others post, and finish a claimed request through a request-and-grant handoff. Works directed (whisper) or across the shared board.
- **Find a Crafter:** search by recipe or item and send a directed order to a guildmate who can make it.
- **Board filters:** narrow the guild board by item or profession, case-insensitive.
- **Guild tab:** see guildmates' shared professions with search and a profession filter, real enchant icons for remote characters, and a `/pb guild` command. Guild discovery runs on login and reload.
- **Incremental inventory sync:** inventory changes now send only what changed instead of your whole character, with an automatic full resync after a reload or a dropped update so counts never drift.

**Wire (comm)**

- COMM_REV 7: adds incremental (delta) inventory messages alongside the existing full SYNC_DATA, so older clients keep full syncs and stay compatible. Adds the guild order board messages (open, claim, closed) and Find a Crafter directed orders. Deltas carry an epoch and sequence, so a reload or a gap forces a clean full resync instead of applying onto a stale baseline.

**Fixes**

- Fixed a Lua error at specialization and profession trainers (Armorsmith, Weaponsmith, Mining rank-ups) and at large multi-category trainers.
- Fixed Enchanting single-craft behavior (Enchanting has no batch chaining in TBC).
- Fixed the "Held by" section drawing half width on four-reagent recipes.
- Find a Crafter now respects the cross-faction alts setting and fits the panel.
- Reliability pass on data sharing: message ordering and per-sender rate limits, payload size caps, order ids bound to the requester, timestamp and token validation, and a floor on repeated refusal replies.

## 1.0.3 - 2026-08-26

**New**

- **Crafting order history and expiry:** the Order History window keeps your last 50 finished orders and adds a sort toggle for newest or oldest first. A pending order left untouched for 14 days moves to an "Expired" state so the list stays current.
- **Decline with a reason:** turn down a crafting order with an optional note, and the requester sees why.
- **Order delivery status:** each update you send shows whether it reached the other player or is waiting to send because they are offline.
- **Friend cooldowns:** a friend's on-cooldown recipes show the time remaining, the same as your own characters.
- **Enchanting icons for friends:** a friend's enchanting recipes show their spell icon instead of a blank square.
- The *<Random enchantment>* line also appears on chat links, bag items, and Auction House tooltips, not only in the recipe window.

**Fixed**

- Viewing a friend's professions no longer throws an error when their synced data has no recipe list.

**Security**

- Only trusted contacts and current group members can request your profession and inventory data, and ProfessionBuddy validates incoming data before storing it.

## 1.0.2 - 2026-08-20

**New**

- **Gathering skill on tooltips:** hovering an ore vein, herb, or a skinnable, mineable, or herbable creature shows the required gathering skill, colored on the skill-up scale (orange, yellow, green, and grey) against your skill level. Toggle it under Settings, Item Tooltips, Gather skill on tooltips (on by default), with an option to show it for gathering professions you haven't learned.
- **Shift-click materials:** shift-click a material in a recipe's details panel or the Material Calculator to link it in chat, or drop it into the Auction House search box, the same way the recipe list on the left works.

**Fixed**

- Crafted items that roll a random enchantment, such as Aquamarine Signet, show the <Random enchantment> line in the recipe window. Before, only their fixed stats appeared.

## 1.0.1 - 2026-08-05

**New**

- **Skill-up filter, No Grey:** the Skill Up dropdown gains a No Grey option that shows only recipes with a skill-up left (orange, yellow, or green) and hides grey ones.
- **Skill-up range in "Used in" tooltips:** hovering a reagent shows each recipe's full skill-up range, colored by difficulty (orange, yellow, green, and grey), so you can tell how far a material's recipes carry your skill. Toggle it under Settings, Item Tooltips, Show skill-up range (on by default).
- **`/pb bug` report helper:** opens a pre-filled, copyable report (addon version, client build, your professions, and fill-in sections for what happened, steps to reproduce, and Lua errors) to paste into a GitHub issue.

**Fixed**

- The main window (Characters, Friends, and Orders) layers above other addons' frames, so stray bars such as a durability Main-Hand bar don't overlap its bottom edge.
- The Skill Up filter doesn't hide every row after you switch tabs while a filter from the other tab is active.

## 1.0.0 - 2026-07-30

First release on CurseForge.
