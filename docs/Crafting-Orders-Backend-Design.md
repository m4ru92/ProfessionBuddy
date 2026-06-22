# Crafting Orders, Backend Design Pass

Status: design draft (not yet built). Front-end v1 is complete and solo-tested.
This document covers the networking layer that makes orders travel between two
real players and keeps both sides in agreement.

---

## 1. Goal

Today an order lives only in the requester's SavedVariables. Acting on it solo
(ordering between your own alts) works because both records are on one machine.
The backend makes an order created by Player A appear in Player B's queue, and
keeps the status in sync as either side acts, surviving the realities below.

Scale target is small: a friend group of a handful of people with a handful of
live orders. Optimise for reliability and graceful degradation, not throughput.

---

## 2. What already exists (the seam)

| Layer | File | Role | Backend touches it how |
|---|---|---|---|
| State machine | `Orders.lua` | order records, lifecycle, role/actor checks, queries | add `ApplyRemote*` entry points; fire a local-change hook |
| Transport | `Comm.lua` | AceComm send/recv, dispatcher, contacts | add ORDER_* message types |
| UI | `OrdersPanel.lua` | queues, history, badge | add a "delivery pending" indicator + notifications |

The two logic layers do not know about each other today, and should stay that
way. A new thin bridge (`OrderSync`) connects them so neither gains a hard
dependency on the other.

---

## 3. The constraints that shape everything

WoW addon comms are not a message bus. The design is dictated by these:

1. **No server-side queue.** If the recipient is offline, the message is gone.
   There is no "deliver later" from Blizzard. Persistence has to be our own.
2. **Whisper addon messages are same-realm, same-faction only.** Cross-faction
   never works. Cross-realm whispers do not work for arbitrary names.
3. **Cross-realm only works inside a party/raid**, via PARTY/RAID/INSTANCE
   distribution. So two cross-realm friends can only exchange live messages
   while grouped.
4. **Messages can drop or duplicate.** Retries are normal, so every apply must
   be idempotent.
5. **The sender is trustworthy.** Blizzard authenticates the sender name on an
   addon message; you cannot spoof who it came from. We still validate that the
   sender is a party to the order they are mutating.
6. **Clocks.** `time()` is server epoch (UTC based), consistent enough within a
   realm; cross-realm skew is seconds at most. Good enough for tiebreaks, but we
   pair it with a per-order version counter.

The single most important consequence: **the order records themselves are the
persistent queue.** Both sides keep the full record in SavedVariables. We do not
need a server to "hold" an order; we need the two copies to reconcile whenever
the two players can next talk. That reconciliation (section 6) is what makes the
whole thing robust without infrastructure.

---

## 4. Architecture

```
Orders.lua  (pure state)        OrderSync.lua  (bridge)        Comm.lua (transport)
  Create/Accept/...   --fires--> OnLocalChange(order, action) --sends--> ORDER_* msg
  ApplyRemoteCreate   <--calls-- ApplyRemote(payload)         <--recv--- dispatcher
  ApplyRemoteUpdate
```

- `Orders.lua` stays networking-free. After a successful local transition it
  fires `addon.OrderSync:OnLocalChange(order, action)` (a no-op if the bridge is
  absent). It also gains `ApplyRemoteCreate(payload)` and
  `ApplyRemoteUpdate(delta)` that set state directly (trusting the validated
  remote actor) instead of checking the local player as actor.
- `OrderSync.lua` is the new module. It owns: the outbox, ACK tracking, retry
  triggers, digest reconciliation, conflict rules, and translating between order
  records and wire payloads.
- `Comm.lua` gains ORDER_* cases in its dispatcher that hand off to `OrderSync`.

---

## 5. Wire protocol (new ORDER_* message types)

All ride the existing `Comm:Send` envelope (`_type`, `_ver`, `_from`).

| Type | Direction | Payload | Meaning |
|---|---|---|---|
| `ORDER_NEW` | requester -> crafter | full order record | a new order |
| `ORDER_UPD` | actor -> other party | `{id, status, completedBy, version, updatedAt, actor}` | a transition happened |
| `ORDER_ACK` | receiver -> sender | `{id, version}` | I received your id@version; clear it from your outbox |
| `ORDER_DIG` | either, on sync | `{ [id] = {version, status} }` for shared orders | "here is my view," for reconcile |
| `ORDER_PULL` | either | `{ ids = {...} }` | send me full records for these ids |

`version` is a per-order integer incremented on every local transition by
whoever makes it. `(version, updatedAt)` together resolve ordering and ties.

---

## 6. Delivery and reconciliation (the core)

Two mechanisms, layered. The second is the safety net that makes the first
non-critical for correctness.

### 6a. Active delivery (promptness)
- On any local change, `OrderSync` builds the message and hands it to the
  **outbox**: `db.orderOutbox[target][id] = {payload, version, tries}`.
- Send immediately. Start an ACK watch.
- On `ORDER_ACK` for `id@version`, remove from outbox.
- **Retry triggers** flush the outbox for any target that looks reachable:
  `PLAYER_ENTERING_WORLD` (login), `FRIENDLIST_UPDATE` / `GUILD_ROSTER_UPDATE`
  (a friend/guildie came online), `GROUP_ROSTER_UPDATE` (grouped, enables
  cross-realm), plus a slow periodic sweep. Cap tries; stale items persist in
  the outbox until delivered or the order goes terminal and ages out.
- UI shows orders with outbox entries as "delivering...".

### 6b. Digest reconciliation (correctness)
Piggybacks on the existing contact sync. When two clients sync (the current
SYNC_REQ/SYNC_DATA handshake), they also exchange `ORDER_DIG`: a map of
`id -> {version, status}` for every order they share. Each side compares:
- id present remotely but not locally, or remote version newer -> `ORDER_PULL`
  it and apply.
- terminal locally but not remotely -> push the terminal update.

This means **any dropped message, any offline gap, any missed transition heals
the next time the two players are online together and sync.** The order records
are the queue; the digest is the diff. No server required.

If we only ever shipped 6b, orders would still be correct, just slower to
appear (catch up on next sync rather than instantly). 6a is the promptness
layer on top. That gives a natural MVP split (section 10).

---

## 7. Conflict resolution and idempotency

- **Idempotent apply.** Apply an incoming update only if
  `incoming.version > local.version` (or equal version but newer `updatedAt`).
  Re-delivered messages become no-ops.
- **Terminal stickiness.** Completed / Declined / Cancelled are final. An
  incoming non-terminal update never overwrites a terminal local state.
- **Concurrent legal moves.** Most states have exactly one legal actor, so true
  races are rare. The common one (requester Cancels while crafter Accepts, both
  legal from Pending): newer version wins; since Cancel is also legal from
  Accepted, the requester's intent self-heals on the next action. The system
  converges.
- **The genuine race** (requester Cancels vs crafter MarkCrafted from Accepted):
  both want a terminal-ish outcome. Rule: a requester Cancel and a crafter
  Crafted that cross are surfaced as a soft conflict ("heads up, talk to your
  friend") rather than silently picked, because real goods may have changed
  hands. Rare; handled in B5, not the MVP.

---

## 8. Trust and abuse (light, it is a friend tool)

- Validate `sender == order.requester` for requester actions and
  `sender == order.crafter` for crafter actions. Drop otherwise.
- `ORDER_NEW` is only accepted naming you as the crafter, from a known contact,
  or it auto-creates a contact but is rate-limited (cap inbound pending per
  sender) so a buggy or hostile peer cannot flood your queue.
- Never act on an order you are not a party to; never relay someone else's.

---

## 9. UI integration (mostly already there)

- New: a small "delivering..." / "synced" indicator per order, driven by whether
  it has an outbox entry.
- Notifications already have settings (`orderChatMessages`, `orderSoundOnRequest`
  in Core.lua). Wire them: chat line and optional sound on `ORDER_NEW` and on
  status changes that need your attention. The badge already reads
  `GetActionableCount`, which will just start reflecting remote orders for free.

---

## 10. Implementation increments

Each is independently shippable and testable. B2 onward needs a second client
(an alt on a second account, a guildie, or a friend) for true cross-client
testing, but the apply logic is unit-testable solo via `/script`.

- **B1, the seam.** Add `OrderSync` module. Add ORDER_* cases to the Comm
  dispatcher (stubs). Fire `OnLocalChange` from Orders transitions. Add
  `Orders:ApplyRemoteCreate/Update` (version-guarded). No behaviour change yet;
  this just wires the plumbing and is verifiable with print stubs.
- **B2, online-to-online propagation.** ORDER_NEW + ORDER_UPD send and apply.
  With both players online, an order travels and statuses sync. No reliability
  net yet (drop a message and it is lost until B4).
- **B3, outbox + ACK + delivery UI.** Reliable delivery: outbox, ACK, retry on
  online-detection, "delivering..." indicator.
- **B4, digest reconciliation.** Piggyback ORDER_DIG / ORDER_PULL on sync. This
  is the robustness keystone (heals drops and offline gaps).
- **B5, conflict + notifications polish.** Precedence hardening, soft conflict
  warning, toast/sound via existing settings.
- **B6, cross-realm path (conditional).** If the friend group is cross-realm:
  route live delivery through PARTY/RAID when grouped, and lean on B4 reconcile
  otherwise. Skip or shrink if everyone is same-realm.

Recommended MVP = B1 + B2 + B4 (it travels, and it self-heals). B3 and B5 are
the polish that makes it feel instant and friendly.

---

## 11. Open decisions (need your input)

1. **Realm and faction topology of your crafting friends.** This is the big one.
   - Same realm, same faction: whispers work anytime, full design applies, B6 is
     skippable. Simplest and best.
   - Cross-realm: live delivery only works while grouped (constraint 3). The
     design still functions but B6 becomes necessary and "place an order" implies
     "deliver it next time you are grouped or both synced." Worth knowing before
     B2.
   - Cross-faction: not possible over addon comms at all; would need an
     out-of-band fallback (just whisper them). Hopefully not the case.

2. **Delivery ambition for v1.** Recommend MVP = B1+B2+B4 (correct + self-healing)
   and treat B3's instant-delivery polish as a fast follow. Confirm or push for
   full B1 through B5 in one pass.

3. **A second test client.** Cross-client testing past B1 needs one. Do you have
   a second account / a guildie willing to test, or should B2+ be built against
   `/script` simulation until a friend session is available?
