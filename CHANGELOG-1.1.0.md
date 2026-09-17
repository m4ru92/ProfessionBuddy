# ProfessionBuddy 1.1.0

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
