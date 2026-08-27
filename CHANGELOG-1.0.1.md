# ProfessionBuddy 1.0.1

**New**

- **Skill-up filter, No Grey:** the Skill Up dropdown gains a No Grey option that shows only recipes with a skill-up left (orange, yellow, or green) and hides grey ones.
- **Skill-up range in "Used in" tooltips:** hovering a reagent shows each recipe's full skill-up range, colored by difficulty (orange, yellow, green, and grey), so you can tell how far a material's recipes carry your skill. Toggle it under Settings, Item Tooltips, Show skill-up range (on by default).
- **`/pb bug` report helper:** opens a pre-filled, copyable report (addon version, client build, your professions, and fill-in sections for what happened, steps to reproduce, and Lua errors) to paste into a GitHub issue.

**Fixed**

- The main window (Characters, Friends, and Orders) layers above other addons' frames, so stray bars such as a durability Main-Hand bar don't overlap its bottom edge.
- The Skill Up filter doesn't hide every row after you switch tabs while a filter from the other tab is active.
