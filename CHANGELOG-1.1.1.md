# ProfessionBuddy 1.1.1

Favorites, a friend-vs-guild badge on orders, and a sync-reliability fix.

**New**

- **Favorite contacts:** pin your go-to friends and guildmates with the star on each row. Favorites sort to the top of the Friends and Guild lists, and the Guild tab gets a favorites-only filter. Account-wide and local to you.
- **Favorite order items:** a star on the Guild Board post box pins the item you typed and lets you quick-fill the field from your pinned items, so re-posting your usual orders is one click. Account-wide and local to you.
- **Order source badge:** every order on the Orders tab is labeled by its counterparty, Friend (a saved contact) or Guild (a guildmate), so a mixed list reads at a glance.

**Fixes**

- A sync or order that arrived before trust was established (for example, before your guild roster finished loading) was dropped with no retry, so a guildmate's data could quietly fail to appear. It is now held briefly and replayed the moment trust resolves.

No protocol change: 1.1.1 is fully compatible with 1.1.0 clients (COMM_REV unchanged).
