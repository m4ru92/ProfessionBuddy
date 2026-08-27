# ProfessionBuddy design notes

Rationale and sourcing that would otherwise clutter inline comments. The code
references these by feature name (for example, `-- see DESIGN-NOTES.md`).

## Gather skill-up colour bands

The gather tooltip colours the "Requires <Prof> (N)" line by how likely a
gather is to give a skill point, on the same red/orange/yellow/green/grey scale
the game uses for crafting recipes.

For a node/mob whose required skill is **R**, vs your current skill:

| Colour | Skill range | Meaning |
|--------|-------------|---------|
| Red    | `< R`       | can't gather |
| Orange | `R .. R+24` | always skills up |
| Yellow | `R+25 .. R+49` | good chance |
| Green  | `R+50 .. R+99` | small chance |
| Grey   | `>= R+100`  | never skills up |

**Source:** cmangos-tbc `src/game/Entities/Player.cpp`, `UpdateGatherSkill`,
`SkillGainChance(SkillValue, R+100, R+50, R+25)`. The band offsets are +25/+50/
+100 for herbalism, mining, and skinning alike. (Mining and skinning additionally
bit-shift the skill-up *chance* down at high skill, but that changes the odds,
not the colour band.)

**No R==1 special case.** cmangos bumps `RedLevel` from 1 to 5 ("stop at 105 not
101"), but that's a cmangos-only deviation; the real game greys out R=1 gathers
(Copper, Peacebloom) at **101**, confirmed by in-game reports. So the code uses a
plain +25/+50/+100 with no bump. This lands the R=1 boundaries exactly on the
observed orange 1-25, yellow 26-50, green 51-100, and grey 101+.

**Consequence:** a cap-level TBC gather like Mana Thistle (R=375) stays orange
forever, since your skill can't exceed 375 while the yellow boundary is 400.

**cmangos is authoritative for _which_ mobs are gatherable, not for skill-up
curves.** The curve was cross-checked against player-observed data, not taken
from cmangos on faith.

## Required gather skill by mob level (corpse gather)

Skinning/mining/herbing a corpse uses a level-based required skill:

- `L <= 10`, 1
- `11..19`, `(L - 10) * 10`
- `L >= 20`, `L * 5`

The skinning curve is verified vs wow-professions and icy-veins. Mining and
herbing corpses use the same corpse-gather mechanic (Outland mobs are lvl 60-67,
so `L*5`), confirmed in-game against the game's own "Requires <skill> (N)" corpse
line.

## Live skill read

`PlayerGatherSkill` reads the live rank from the skill lines
(`GetSkillLineInfo`) rather than DataStore's cached `skillLevel`, because the
cache only refreshes on a rescan and so lags while you're actively gaining skill
(the "Your Mining line / band colour doesn't update while mining" bug). It falls
back to the DataStore cache only if the live line isn't visible (collapsed
skill-window header, or a non-enUS client where the English name won't match).
Note: `GetSkillLineInfo` returns base rank, not effective (it ignores +skill
tool/glove modifiers). This matches the prior cache behaviour, so there's no
regression.

## World node tooltips

World herb/ore nodes are GameObjects, not units, so `OnTooltipSetUnit` never
fires for them. The client also (re)builds their tooltip over several frames
after it shows, and can rebuild it again mid-hover, which wipes an appended line.
A one-shot read or a "once per node" guard fails intermittently ("just the
name"). The reliable approach: on a throttled `OnUpdate` (~20 Hz), if the hovered
object is a known node and our line isn't present, (re)append it. It's
idempotent, so it survives the client's rebuilds and never duplicates. When the
node is too high to gather, the game draws its own red "Requires <prof> (N)"
line, which we overwrite in place (rather than adding a second one).

Node required skills come from the client `Lock.db2` joined to cmangos
`gameobject_template` names; the mob sets come from cmangos `creature_template`.

## Gather data generation (Data/GatherMobs.lua)

`tools/gather_db.py` regenerates this from cmangos-tbc (TBCDB 1.11.0). A
creature is **skinnable** if it has a `skinning_loot_template` row AND is not
flagged mining (0x200) / herb (0x100) / engineering (0x400); mineable/herbable
are the same loot presence gated on the mining/herb flag. Hand-excluded false
positives live in `EXCLUDE_SKIN` (7395 Cockroach). The 1.11.0 re-source
removed ~35 false positives the 1.10.0 data carried (spiders like Giant
Plains Creeper, scarabs, "Human Skull", NPC/trigger entries, special-entry cats/
boars lacking skin loot); all skinnable categories stayed intact. The tool
detects `creature_template` columns dynamically so a schema shift between DB
versions can't misalign the parse, validates known-good anchors, and preserves
the node tables.

**Minimap is an incidental surface.** The Anniversary client routes
minimap node-blip tooltips through `GameTooltip`, so the node hook appends to
them too when it can. This is a bonus, not a designed surface: it can be
flaky (rebuild race), and the feature is built and validated against world-node
and unit tooltips.

## Random-enchant crafted items ("<Random enchantment>")

Random-property crafted results (for example, Aquamarine Signet) show a green
`<Random enchantment>` line. In 2.5.x that line is a **crafting-preview**
artifact: the game only renders it via the trade-skill result path
(`SetTradeSkillItem`), never from an item ID or item link. `SetItemByID` and
`SetHyperlink("item:"..id)` both build the plain base tooltip (fixed stats only).
PB shows recipes from static data, including missing ones not in the live
trade-skill window, so it can't use `SetTradeSkillItem`, and therefore **appends
the line itself** for known random-property items (`TSF:AppendRandomEnchantLine`,
idempotent so it never doubles a natively-shown line).

The set `ProfBuddy.RandomEnchantItems` (Data/RandomEnchant.lua) is the crafted
result itemIDs whose cmangos-tbc `item_template` has a non-zero `RandomProperty`
or `RandomSuffix` (validated: 20964 Aquamarine Signet, RandomProperty 3482).
There are 13 items across BS/LW/Eng/JC (the Wild Leather set, Gemmed Copper
Gauntlets, Dark Iron Boots, Green Lens, Cogspinner Goggles, Heavy Silver Ring,
Aquamarine/Sapphire Signet).

## Static skill requirements (crafting)

Static `skillReq` values are treated as authoritative (cross-checked vs cmangos
`npc_trainer`; only a few Cooking edge cases were hand-corrected). The trainer
scan reconciles live-scanned requirements against the static table and stores any
correction, but the announcement is gated behind a setting (default off) so it's
a silent safety net.
</content>
</invoke>
