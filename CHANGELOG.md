# Changelog

Every ProfessionBuddy release, newest first. Each entry lists what is new, what changed and what was fixed, and whether it works with older versions.

## 2.0.0 - 2026-10-16

ProfessionBuddy runs on WoW: Forever as well as TBC Classic Anniversary, from one download. Thanks to Blargle and Shrekcheeks, who assisted greatly in testing every build of this release in game.

**Highlights**

- **WoW: Forever support:** the profession window, crafting, the Material Calculator, alts, friends, crafting orders and the guild board all work on Forever.
- **Show everything or Learn as you go (Forever):** list every recipe in the game, or only the recipes you, your alts or your friends have seen at a trainer, at a vendor or as a recipe item. PB asks the first time a profession opens, and Settings changes it later.
- **Trainers and vendors, shared (Forever):** PB records the trainers and vendors you visit, with learn levels and prices, and shares them with your friends.
- **Gathering tooltips (Forever):** ore veins, herbs and skinnable mobs show the skill they need and what they drop, learned as you and your friends gather.
- **On both clients:** search by material, a Learnable now view, a Share button for recipe links, a minimap button, guild board alerts, every recipe tool in the detail panel, and Battle.net friends as contacts (TBC Anniversary).

<!-- more -->

**WoW: Forever**

- PB's own profession window replaces Blizzard's: your learned recipes with reagents, counts, and the game's difficulty colours and categories. K still opens the profession book.
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
- PB colours a recipe you do not know by its difficulty on learning ("Difficulty when learned").
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

- **Skinning loot on the hover tooltip:** hovering a skinnable mob now shows a "Skins into:" list of every item it yields, with the drop chance for each, quality-coloured and with stack ranges. A Nagrand clefthoof reads Knothide Leather Scraps 65%, Knothide Leather 25%, Thick Clefthoof Leather 10%. Quest-only drops are listed but greyed and deliberately carry no percentage, because the underlying value is the chance while you are on the quest rather than the rate you would actually see. Built from the same cmangos data the gather feature already uses, and shown only if you have Skinning. Toggle it with "Skinning loot" in the options.
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
