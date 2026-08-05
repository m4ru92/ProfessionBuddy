# ProfessionBuddy 1.0.1

**New**

- **Skill-Up filter — "No Grey":** the Skill Up dropdown gains a *No Grey* option that shows only recipes which can still give a skill-up (orange / yellow / green), hiding trivial grey ones.
- **Skill-up range in "Used in" tooltips:** hovering a reagent now shows each recipe's full skill-up range, colored by difficulty (orange → yellow → green → grey), so you can tell at a glance how far a material's recipes will carry your skill. Toggle it under **Settings → Item Tooltips → Show skill-up range** (on by default).
- **`/pb bug` bug-report helper:** opens a pre-filled, copyable report (addon version, client build, your professions, plus fill-in sections for what happened / steps to reproduce / Lua errors) to paste into a GitHub issue.

**Fixed**

- The main window (Characters / Friends / Orders) now layers above other addons' frames, so stray bars — like a durability "Main-Hand" bar — no longer overlap its bottom edge.
- Skill Up filter no longer hides every row after switching tabs when a filter from the other tab was still selected.
