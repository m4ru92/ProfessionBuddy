#!/usr/bin/env python3
"""Run every ProfessionBuddy Lua test harness and report one verdict.

Both harnesses stub the WoW API, load the addon out of ProfessionBuddy/, and
error() on the first failed assertion, so "it ran to the end and printed its
PASS line" is the pass condition.

The shipped client is Lua 5.1, so this prefers the real 5.1 interpreter lupa
ships (lupa.lua51) and falls back to lupa's default runtime with the VM named
in the output, never silently.

Usage (from anywhere; paths resolve off this file):
  python tests/run_all.py
  python tests/run_all.py --vm default      # force lupa's default runtime
  python tests/run_all.py -q                # verdict lines only

Exit status: 0 when every harness passed, 1 otherwise.
"""
import argparse, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, ".."))
ADDON = "ProfessionBuddy"

HARNESSES = [
    ("pb_harness.lua", "ALL 66 HARNESS TESTS PASS"),
    ("pb_ghost_harness.lua", "ALL GHOST HARNESS TESTS PASS"),
]


def pick_runtime(which):
    """Return (LuaRuntime class, label)."""
    if which in ("auto", "51"):
        try:
            from lupa.lua51 import LuaRuntime
            return LuaRuntime, "Lua 5.1 (lupa.lua51)"
        except ImportError:
            if which == "51":
                print("ERROR: lupa.lua51 is not available in this lupa build",
                      file=sys.stderr)
                sys.exit(2)
    try:
        from lupa import LuaRuntime
    except ImportError:
        print("ERROR: lupa is not installed. pip install lupa", file=sys.stderr)
        sys.exit(2)
    rt = LuaRuntime(unpack_returned_tuples=True)
    return LuaRuntime, "lupa default (%s)" % rt.eval("_VERSION")


def run(LuaRuntime, path, expect, quiet):
    """Execute one harness in a fresh Lua state. Return (ok, detail)."""
    src = open(path, encoding="utf-8").read()
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().PB_BASE = ADDON
    printed = []

    def capture(*a):
        line = " ".join("" if x is None else str(x) for x in a)
        printed.append(line)
        if not quiet:
            print("    " + line)

    lua.globals().print = capture
    try:
        lua.execute(src)
    except Exception as e:                                       # noqa: BLE001
        if quiet:
            for line in printed[-12:]:
                print("    " + line)
        msg = str(e).strip()
        return False, (msg.splitlines()[-1] if msg else repr(e))
    if not any(expect in p for p in printed):
        return False, "ran to the end but never printed %r" % expect
    return True, expect


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--vm", choices=["auto", "51", "default"], default="auto",
                    help="which Lua interpreter to run under (default: auto)")
    ap.add_argument("-q", "--quiet", action="store_true",
                    help="suppress harness chatter; print verdicts only")
    args = ap.parse_args()

    os.chdir(REPO)                      # harnesses resolve PB_BASE relatively
    LuaRuntime, label = pick_runtime(args.vm)
    print("ProfessionBuddy test harnesses  |  VM: %s  |  repo: %s" % (label, REPO))

    failures = []
    for fn, expect in HARNESSES:
        path = os.path.join(HERE, fn)
        if not os.path.isfile(path):
            failures.append((fn, "missing: " + path))
            print("FAIL  %-22s missing" % fn)
            continue
        if not args.quiet:
            print("\n---- %s ----" % fn)
        ok, detail = run(LuaRuntime, path, expect, args.quiet)
        if ok:
            print("PASS  %-22s %s" % (fn, detail))
        else:
            failures.append((fn, detail))
            print("FAIL  %-22s %s" % (fn, detail))

    print("\n%d/%d harnesses passed" % (len(HARNESSES) - len(failures), len(HARNESSES)))
    if failures:
        for fn, detail in failures:
            print("  FAILED: %s: %s" % (fn, detail))
        return 1
    print("ALL HARNESSES PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
