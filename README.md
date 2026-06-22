# ProfessionBuddy

A modern all-in-one profession window for World of Warcraft: Burning
Crusade Classic (Anniversary realms, 2.5.5). See every character's
recipes and materials at a glance, calculate exactly what to gather,
and request crafts from friends.

## Features

- **Cross-character view** — every alt's professions, known recipes,
  and bag/bank inventory in one place, no logging in and out.
- **Material Calculator** — resolves the full reagent tree (including
  intermediate crafts), subtracts what you already own across your
  characters, and produces a shopping list.
- **Crafting Orders** — request a craft from a friend running
  ProfessionBuddy. Full lifecycle (request → accept → crafted →
  received) with chat notifications, a queue, and history. Offline
  friends are handled: the order is queued and auto-delivers when you
  are next both online.
- **Friend / group data sharing** — see grouped or contact players'
  professions, recipes, and materials (AceComm-based).
- **Accurate difficulty** — skill-up colors and skill ranges are
  built from Blizzard's client data (see *Recipe data* below), so
  they match the in-game trainer.
- **Alt-aware tooltips** — "Craftable by" (who can make this) and
  "Used in" (which recipes use this reagent).
- **Cross-character search** — items and recipes across all alts at
  once.
- **Batch crafting** — 1 / 5 / 10 / 20 / All with a live countdown
  and skill-bar updates.
- **State preservation** — window position, filters, sort, search,
  and selection persist.

Supported: Blacksmithing, Leatherworking, Tailoring, Engineering,
Alchemy, Jewelcrafting, Enchanting, Cooking, First Aid, and
Mining/Smelting.

## Installation

- **CurseForge / addon managers:** search "ProfessionBuddy" and
  install (recommended — auto-updates).
- **Manual:** download the latest release zip and extract the
  `ProfessionBuddy` folder into
  `World of Warcraft/_classic_/Interface/AddOns/`.

## Usage

Open any profession, or type `/pb` (or `/profbuddy`). The gear icon
in the window opens settings. Your saved data lives in
`WTF/.../SavedVariables/ProfessionBuddy.lua`.

## Recipe data

Skill ranges and difficulty colors are generated from Blizzard's
client DB2 (`SkillLineAbility` + `SpellName`) for the current build
via [wago.tools](https://wago.tools), as
`skillRange = {learn, trivLow, floor((trivLow+trivHigh)/2), trivHigh}`.
Learn levels (the trainer "requires" value) are not present in DB2
(`MinSkillLineRank` is 1), so those are trainer-sourced. On a new
client build, re-pull and regenerate.

## Reporting bugs

Install [!BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber)
and [BugSack](https://www.curseforge.com/wow/addons/bugsack),
reproduce the issue, and open an issue with the full Lua error. A
bug-report template is provided.

## Building / packaging

Currently released as a manually built zip (single `ProfessionBuddy/`
folder at the root, excluding backup files). A `.pkgmeta` for the
CurseForge GitHub packager is planned.

## License

[MIT](LICENSE). Bundled libraries under `Libs/` (LibStub,
CallbackHandler-1.0, ChatThrottleLib, Ace3: AceComm-3.0,
AceSerializer-3.0) retain their own permissive licenses.

## Credits

Created by m4ru. Built on the Ace3 library suite.
