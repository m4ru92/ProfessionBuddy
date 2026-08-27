<p align="center">
  <img src="logo/pb-logo.png" width="160" alt="ProfessionBuddy logo">
</p>

<h1 align="center">ProfessionBuddy</h1>

<p align="center">
  An all-in-one profession window for World of Warcraft: Burning Crusade
  Classic (Anniversary realms, 2.5.6). See every character's recipes and
  materials, plan what to gather, and request crafts from friends.
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/professionbuddy"><strong>Download on CurseForge</strong></a>
  &nbsp;&middot;&nbsp;
  <a href="https://github.com/m4ru92/ProfessionBuddy/issues">Report a bug</a>
</p>

## Screenshots

|  |  |
| :---: | :---: |
| ![Main window](media/MainWindow.png) | ![Material Calculator](media/MaterialCalc.png) |
| Recipe browser with difficulty colors from client data | Material calculator: full reagent tree and shopping list |
| ![Recipe detail](media/MainWindowEnchantingDetail.png) | ![Cross-character view](media/AltWindow.png) |
| Recipe details, reagents, and required rod | Every character's professions in one view |
| ![Friends](media/FriendWindow.png) | ![Crafting Orders](media/CraftingOrders.png) |
| Friends' professions and materials, synced | Friend-to-friend crafting orders |
| ![Browse a friend's recipes](media/FriendProfWindow_CraftingOrder.png) | ![Settings](media/Settings.png) |
| Browse a friend's recipes and request a craft | Settings |

## Features

- **Cross-character view.** See every character's professions, known recipes, and bag and bank inventory in one place, without logging in and out.
- **Material calculator.** Resolves the full reagent tree, including intermediate crafts, subtracts what you already own across your characters, and produces a shopping list.
- **Crafting orders.** Request a craft from a friend running ProfessionBuddy. The request, accept, crafted, and received steps run with chat notifications, a queue, and history. If a friend is offline, the order queues and sends the next time you are both online.
- **Friend and group data sharing.** See grouped or contact players' professions, recipes, and materials, over AceComm.
- **Difficulty from client data.** Skill-up colors and skill ranges come from Blizzard's client data, so they match the in-game trainer. See Recipe data below.
- **Alt-aware tooltips.** "Craftable by" shows who can make an item, and "Used in" shows which recipes use a reagent.
- **Cross-character search.** Find items and recipes across all your characters at once.
- **Batch crafting.** Craft 1, 5, 10, 20, or all, with a live countdown and skill-bar updates.
- **State preservation.** Window position, filters, sort, search, and selection persist between sessions.

ProfessionBuddy supports Blacksmithing, Leatherworking, Tailoring, Engineering, Alchemy, Jewelcrafting, Enchanting, Cooking, First Aid, and Mining and Smelting.

## Installation

- **CurseForge or addon managers:** search "ProfessionBuddy" in your addon manager and install it for automatic updates, or download it from the [CurseForge page](https://www.curseforge.com/wow/addons/professionbuddy).
- **Manual:** download the release zip and extract the `ProfessionBuddy` folder into `World of Warcraft/_classic_/Interface/AddOns/`.

## Usage

Open a profession, or type `/pb` (or `/profbuddy`). The gear icon in the window opens settings. Your saved data lives in `WTF/.../SavedVariables/ProfessionBuddy.lua`.

## Recipe data

Skill ranges and difficulty colors come from Blizzard's client DB2 (`SkillLineAbility` and `SpellName`) for the 2.5.6 build, via [wago.tools](https://wago.tools). The generated shape is as follows:

```
skillRange = {learn, trivLow, floor((trivLow+trivHigh)/2), trivHigh}
```

Learn levels (the trainer "requires" value) are absent from DB2 (`MinSkillLineRank` is 1), so those come from the trainer. For a later client build, re-pull and regenerate.

## Bug reports

Install [!BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) and [BugSack](https://www.curseforge.com/wow/addons/bugsack), reproduce the issue, and open an issue with the full Lua error. Run `/pb bug` for a pre-filled report template.

## Build and packaging

The build is a manually assembled zip: a single `ProfessionBuddy/` folder at the repo root, excluding backup files. There is no `.pkgmeta` packager config.

## License

[MIT](LICENSE). Bundled libraries under `Libs/` (LibStub, CallbackHandler-1.0, ChatThrottleLib, and Ace3: AceComm-3.0 and AceSerializer-3.0) retain their own permissive licenses.

## Credits

Created by m4ru. Built on the Ace3 library suite.
