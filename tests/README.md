# Tests

Two headless Lua harnesses. Both stub the WoW API, load the real addon files
out of `ProfessionBuddy/`, and `error()` on the first failed assertion, so
reaching the final `PASS` line is the pass condition.

**These are dev tools. They are NOT shipped in the addon.** Keep them out of
the packaged zip (and out of the `ProfessionBuddy/` folder).

## Run both

```
pip install lupa
python tests/run_all.py
```

`run_all.py` runs each harness in its own Lua state on the real Lua 5.1
interpreter lupa ships (`lupa.lua51`), which is the language version the 2.5.6
client runs. If that build is missing it falls back to lupa's default runtime
and names the VM it used. It exits non-zero when either harness fails, and
`tools/release.py` runs it before it builds a zip.

To run one by hand instead:

```
python -c "from lupa.lua51 import LuaRuntime; lua=LuaRuntime(unpack_returned_tuples=True); lua.globals().PB_BASE='ProfessionBuddy'; lua.execute(open('tests/pb_harness.lua',encoding='utf-8').read())"
```

`PB_BASE` is the path to the addon folder, relative to the working directory.

## pb_harness.lua, single instance, hand-fed payloads

Loads `Core`, `DataStore`, `Orders`, `Comm`, `RecipeDB`, `Scanner`,
`MaterialCalc` and four `Data/` files, and drives the real message handlers and
the real profession-window scans end to end. 54 assertions, in four arcs:

* **T1-T23, comm and orders.** The trust gate, cross-realm spoof refusal,
  SYNC_DATA and HELLO ingress sanitization, the full order lifecycle with ack
  clearing, forged `completedBy` and role checks, auto-push suppression, the
  `shareData` kill switch, the guild board model, terminal-order pruning, and
  the INCR delta path (send and suppress, profession change forces a full sync,
  add and change and remove applied, gap and wrong-epoch resync, malformed
  payload rejected).
* **T24-T29, canonical keys and scope.** The realm stub is "Test Realm", so
  every key crosses the normalization boundary: RoleFor on a raw-realm record,
  the self-echo filter on our own guild broadcast, contact lookup after a
  `/pb sync`. Then the distribution gate (a directed message on GUILD is
  dropped), the recipes-only serve a guild-tier peer gets, a partial payload
  keeping the stored inventory, an unsolicited guild push dropped until we ask,
  and the deferred once-per-60 s guild HELLO ack.
* **T30-T44, board lifecycle and delta hardening.** Order ids bound to their
  poster (hijack and squat), the 20-per-requester / 200-total board caps and
  the 5 s post cooldown, the board TTL sweep, OPEN expiry with
  ORDER_CLOSED{expired}, a claim on an order we no longer hold, status
  regression, cancel after a claim, NaN ingress, epoch reseeding after a
  reload, the resync throttle, ChatThrottleLib priorities, the quantity clamp,
  ack-on-refusal, the offline back-off, and `ForgetPeer`.
* **T45-T54, Scanner, RecipeDB and MaterialCalc.** A linked window and a pet
  trainer write nothing, a filtered or collapsed recipe list skips the persist,
  the bank is only scanned while it is open, BAG_UPDATE throttles to one
  leading plus one trailing scan, collapsed skill headers are restored by name,
  the reverse maps are multi-valued and itemID 0 is never registered, cycle
  detection over the real recipe graph, and the calculator buying a cyclic
  primal while expanding a known smelt with the right yield rounding.

T12 and T24-T54 each print a `PASS` line; the output ends with
`ALL 54 HARNESS TESTS PASS`.

## pb_ghost_harness.lua, two instances talking to each other

Loads two fully isolated ProfessionBuddy instances in one Lua state, each with
its own `ProfBuddy`, `ProfBuddyDB`, and API stubs, and wires a router between
their AceComm send and receive. That turns a real cross-client conversation
into something you can drive and assert without a second game client, which is
what the multi-round flows need and `pb_harness.lua` cannot express. 12 groups:
HELLO handshake, sync, stranger refusal, spoof refusal, guild trust and sync,
incremental auto-push, the directed order loop, the board claim race, board
lifecycle, board anti-spoof, delta plus gap recovery, and the whole board flow
re-run on the multi-word realm "Old Blanchy" (`makeInstance` takes the realm,
so the winner of that claim race is asserted to recognize itself as the
crafter through `RoleFor`, `GetIncoming` and `LegalActions`).

Expected output ends with `ALL GHOST HARNESS TESTS PASS`.

## Data

The static recipe database has its own checker, `python tools/lint_data.py`.
It loads every `Data/*.lua` through a Lua interpreter and applies the schema
and consistency rules the addon's consumers depend on. It exits non-zero on any
blocking finding; sections it marks `[informational]` do not fail the run.
`tools/release.py` runs it alongside the harnesses.

## When you touch Comm.lua / Orders.lua

Re-run both harnesses. They catch the class of bug where a file-local
`local function` helper is referenced above its definition (it compiles to a
nil global and is silently swallowed by the pcall dispatch). Keep file-local
helpers defined ABOVE their first use.

## Two copies of pb_harness.lua exist ON PURPOSE (keep in sync)

`tests/pb_harness.lua` is the copy that lives in this repo. An identical
working copy sits at the project-wrapper root, which is the one run from the
author's working directory (cwd = the `ProfessionBuddy/` wrapper,
`PB_BASE = "ProfessionBuddy"`). They are byte-identical and MUST be updated
together. When you change the harness, update both, or re-copy the root one
into `tests/` at commit time.
