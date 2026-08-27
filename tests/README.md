# Tests

## pb_harness.lua, headless comm/order logic harness

Stubs the WoW API, loads `Core/DataStore/Orders/Comm.lua`, and drives the
real message handlers end to end (13 assertions: trust gate, cross-realm
spoof refusal, SYNC_DATA/HELLO ingress sanitization, full order lifecycle
with ack clearing, forged-completedBy/role checks, auto-push suppression,
the shareData kill switch, and the auto-add-mates gate).

**This is a dev tool. It is NOT shipped in the addon.** Keep it out of the
packaged zip (and out of the `ProfessionBuddy/` folder).

### Run it

This harness needs a Lua runtime. The Python `lupa` bridge takes the fewest
steps:

```
pip install lupa
python - <<'PY'
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().PB_BASE = "ProfessionBuddy"        # path to the addon folder
lua.execute(open("tests/pb_harness.lua").read())
PY
```

Expected output ends with `ALL 13 HARNESS TESTS PASS`.

### When you touch Comm.lua / Orders.lua

Re-run the harness. It catches the class of bug where a file-local
`local function` helper is referenced above its definition (compiles to a
nil global, silently swallowed by the pcall dispatch). Keep file-local
helpers defined ABOVE their first use.

### Two copies of this file exist ON PURPOSE (keep in sync)

`repo-files/tests-pb_harness.lua` (this one) is the copy that goes into the
GitHub repo as `tests/pb_harness.lua`. An identical working copy lives at the
project-wrapper root as `pb_harness.lua`, the one run in the
Drive workspace (cwd = the `ProfessionBuddy/` wrapper, `PB_BASE = "ProfessionBuddy"`).
They are byte-identical and MUST be updated together. When you change the harness, update
BOTH (or re-copy root to repo-files at commit time). The tester harness
`pbt_harness.lua` has NO repo copy: the tester is dev-only, never committed/shipped.
