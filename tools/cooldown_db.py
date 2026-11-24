#!/usr/bin/env python3
"""ProfessionBuddy cooldown tool: every recipe with a cooldown (2.2.4, CD-A).

The game's live read only says how long a recipe has left, and reads 0
both for a cooldown craft that is ready and for a craft with no cooldown.
This tool bakes what the live read cannot give, from each game's own
spell tables (SpellCooldowns, SpellCategories, SpellCategory):

  TBC Anniversary  Data/Cooldowns.lua, at the build Data/VendorPrices.lua
                   was baked from
  WoW: Forever     Data/Forever/Cooldowns.lua, at the recipe data's build

Each entry is a recipe's spellID with its cooldown in seconds and, when
the cooldown is a shared timer (a category cooldown: one transmute locks
every transmute), the category. The category names come along for the
shared timers. The recipes are every spellID in the recipe data files.

The bake stops on a cooldown PB does not handle yet: charges, a weekly
limit, a category flag (the daily reset is one), a recipe with both its
own and a shared cooldown, or more than one row for a spell.

  --check   does each file match the spell tables and the recipe data?
            Exits 0 = yes, 10 = run --regen --write.
  --regen   work both tables out; --write writes them.
  --csv DIR read <Table>_<build>.csv from DIR instead of wago.tools.

Usage:
  python tools/cooldown_db.py --check [--addon-dir <path>]
  python tools/cooldown_db.py --regen [--write] [--csv DIR]
"""
import argparse, csv, glob, io, os, re, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake_forever_db2 as F

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ADDON = os.path.normpath(os.path.join(HERE, "..", "ProfessionBuddy"))
TABLES = ("SpellCooldowns", "SpellCategories", "SpellCategory")
# Anchors, so a broken join fails the bake: Iron to Gold is 20h on the
# shared transmute timer on TBC Anniversary and 1h of its own on WoW:
# Forever; Primal Mooncloth 92h of its own (TBC Anniversary); Legionite
# 47h on the shared transmute timer and Mooncloth 95h of its own (WoW:
# Forever). Data: COOLDOWN-data-2026-11-02.txt.
ANCHORS = {False: {11479: (72000, 310), 26751: (331200, None)},
           True: {11479: (3600, None), 1317279: (169200, 310), 18560: (342000, None)}}
SPELL_ID = re.compile(r"(?m)^\s*spellID\s*=\s*(\d+),")


def log(m): print(m, flush=True)


def tbc_build(addon_dir):
    """The TBC Anniversary build PB's vendor prices were baked from."""
    p = os.path.join(addon_dir, "Data", "VendorPrices.lua")
    m = re.search(r"build (\d+\.\d+\.\d+\.\d+)", open(p, encoding="utf-8").read())
    if not m:
        sys.exit("cooldown_db: no TBC build stamp in " + p)
    return m.group(1)


def read_table(name, build, csv_dir):
    p = csv_dir and os.path.join(csv_dir, "%s_%s.csv" % (name, build))
    if p and os.path.isfile(p):
        return list(csv.DictReader(open(p, encoding="utf-8")))
    url = "https://wago.tools/db2/%s/csv?build=%s" % (name, build)
    log("  fetching %s for %s ..." % (name, build))
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=300).read()
    return list(csv.DictReader(io.StringIO(raw.decode("utf-8"))))


def recipes(addon_dir, forever):
    """{spellID: recipe name} for every recipe file."""
    d = os.path.join(addon_dir, "Data", "Forever") if forever else os.path.join(addon_dir, "Data")
    out = {}
    for p in sorted(glob.glob(os.path.join(d, "*.lua"))):
        txt = open(p, encoding="utf-8").read()
        if "local recipes = {" not in txt:
            continue
        for m in re.finditer(r'(?m)^    \["((?:[^"\\]|\\.)*)"\] = \{\n\s*spellID\s*=\s*(\d+),', txt):
            out[int(m.group(2))] = m.group(1)
        # every spellID line must belong to a recipe the pattern above read
        missing = {int(s) for s in SPELL_ID.findall(txt)} - set(out)
        if missing:
            sys.exit("cooldown_db: %s: spellID %s outside a recipe block" % (p, sorted(missing)[0]))
    return out


def by_spell(rows, what):
    """{spellID: row} for the rows with no difficulty; two rows stop the bake."""
    out = {}
    for r in rows:
        if r.get("DifficultyID", "0") != "0":
            continue
        s = int(r["SpellID"])
        if s in out:
            sys.exit("cooldown_db: spell %d has two %s rows" % (s, what))
        out[s] = r
    return out


def plan(addon_dir, forever, build, csv_dir):
    t = {n: read_table(n, build, csv_dir) for n in TABLES}
    cds = by_spell(t["SpellCooldowns"], "SpellCooldowns")
    cats = by_spell(t["SpellCategories"], "SpellCategories")
    catrow = {int(r["ID"]): r for r in t["SpellCategory"]}
    names = recipes(addon_dir, forever)
    table, groups = {}, {}
    for sid, name in names.items():
        c = cats.get(sid)
        if c and int(c["ChargeCategory"] or 0):
            sys.exit("cooldown_db: %s (%d) uses charges" % (name, sid))
        r = cds.get(sid)
        own = int(r["RecoveryTime"] or 0) if r else 0
        shared = int(r["CategoryRecoveryTime"] or 0) if r else 0
        if not (own or shared):
            continue
        if own and shared:
            sys.exit("cooldown_db: %s (%d) has its own and a shared cooldown" % (name, sid))
        group = None
        if shared:
            group = int(c["Category"] or 0) if c else 0
            if not group:
                sys.exit("cooldown_db: %s (%d) has a shared cooldown and no category" % (name, sid))
            g = catrow.get(group)
            if not g:
                sys.exit("cooldown_db: %s (%d): category %d is not in SpellCategory" % (name, sid, group))
            if int(g["Flags"] or 0) or int(g["MaxCharges"] or 0) or int(g["UsesPerWeek"] or 0):
                sys.exit("cooldown_db: category %d (%s) has flags, charges or a weekly limit"
                         % (group, g["Name_lang"]))
            groups[group] = g["Name_lang"]
        table[sid] = ((own or shared) // 1000, group)
    for sid, want in ANCHORS[forever].items():
        if table.get(sid) != want:
            sys.exit("cooldown_db: anchor failed: spell %d is %s, expected %s" % (sid, table.get(sid), want))
    rel, txt = lua_file(forever, build, table, groups, names)
    return rel, txt, len(table), len(names)


def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def lua_file(forever, build, table, groups, names):
    rel = "Data/Forever/Cooldowns.lua" if forever else "Data/Cooldowns.lua"
    lines = [
        "-- ProfessionBuddy  --  %s" % rel,
        "-- Every recipe with a cooldown: { seconds, shared timer }, by spellID. The",
        "-- shared timer is the game's cooldown category (nil = the recipe's own timer):",
        "-- crafting one recipe in it starts the timer for all of them.",
        "-- Generated by tools/cooldown_db.py from the game's spell tables, build %s" % build,
        "-- (SpellCooldowns, SpellCategories, SpellCategory): %d of %d recipes." % (len(table), len(names)),
        "-- Do not edit by hand; regenerate.",
        "local addon = ProfBuddy",
        "addon.Cooldowns = {",
    ]
    for sid in sorted(table, key=lambda s: (names[s], s)):
        secs, group = table[sid]
        lines.append("    [%d] = { %d%s },  -- %s" % (sid, secs, ", %d" % group if group else "", names[sid]))
    lines += ["}", "", "-- The shared timers: the game's name for each category.", "addon.CooldownGroups = {"]
    for g in sorted(groups):
        lines.append("    [%d] = %s," % (g, lua_str(groups[g])))
    lines.append("}")
    return rel, "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--addon-dir", default=DEFAULT_ADDON)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--regen", action="store_true")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--csv")
    a = ap.parse_args()
    if not (a.check or a.regen):
        ap.print_help(); return
    builds = (("TBC Anniversary", False, tbc_build(a.addon_dir)),
              ("WoW: Forever", True, F.baked_build(os.path.join(a.addon_dir, "Data", "Forever"))))
    stale = 0
    for label, forever, build in builds:
        if not build:
            sys.exit("cooldown_db: no %s build" % label)
        rel, txt, n, total = plan(a.addon_dir, forever, build, a.csv)
        path = os.path.join(a.addon_dir, "Data", *rel.split("/")[1:])
        old = open(path, encoding="utf-8").read() if os.path.isfile(path) else None
        same = old == txt
        log("%s (build %s): anchors OK, %d of %d recipes have a cooldown  |  %s %s"
            % (label, build, n, total, rel, "up to date" if same else "differs"))
        if not same:
            stale += 1
            if a.regen and a.write:
                open(path, "w", encoding="utf-8", newline="\n").write(txt)
                log("  WROTE %s (%d bytes)" % (rel, len(txt)))
    if a.check:
        if stale:
            log("REBAKE: python tools/cooldown_db.py --regen --write")
            sys.exit(10)
        log("UP TO DATE")
        sys.exit(0)


if __name__ == "__main__":
    main()
