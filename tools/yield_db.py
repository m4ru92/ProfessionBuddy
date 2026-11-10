#!/usr/bin/env python3
"""ProfessionBuddy yield tool: how many items one craft makes (2.1.1).

Reads the game's own spell table (SpellEffect, "create item", effect 24)
and writes each recipe's count into PB's recipe data:

  TBC Anniversary  Data/<Profession>.lua. The count is EffectBasePoints + 1
                   to EffectBasePoints + EffectDieSides (Smelt Bronze: 1 + 1
                   = 2). Until 2.1.1 the data had a count only for Smelt
                   Bronze, and the wrong one for the two bolt recipes.
  WoW: Forever     Data/Forever/<Profession>.lua. tools/bake_forever_db2.py
                   writes `yield` (EffectBasePointsF); this tool checks it
                   and adds the range of a random amount (EffectBasePointsF
                   plus or minus EffectBasePointsF x Variance / 2: Coarse
                   Dynamite 2 +/- 1).

A recipe that makes more than one gets `yield` (the middle of a range, what
prices and the Material Calculator use); a random amount also gets
`yieldMin` and `yieldMax`. Hircus's report (2026-11-10): Smelt Bronze makes
two bars and PB didn't say so.

  --check   is the data's every count the game's? Exits 0 = yes, 10 = run
            --regen --write.
  --regen   work the counts out; --write writes the files.
  --csv DIR read SpellEffect_<build>.csv from DIR instead of wago.tools.

Usage:
  python tools/yield_db.py --check [--addon-dir <path>]
  python tools/yield_db.py --regen [--write] [--csv DIR]
"""
import argparse, csv, io, os, re, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake_forever_db2 as F

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ADDON = os.path.normpath(os.path.join(HERE, "..", "ProfessionBuddy"))
CREATE_ITEM = 24
# Anchors: Smelt Bronze makes 2 on both games (Hircus, image 145), Coarse
# Dynamite 1 to 3, Handful of Copper Bolts 1 (VMaNGOS, Classic Era, retail
# agree; PB's TBC data said 2 until 2.1.1).
ANCHORS = {2659: (2, 2), 3931: (1, 3), 3922: (1, 1)}

BLOCK = re.compile(r'^    \["((?:[^"\\]|\\.)*)"\] = \{\n(.*?)^    \},\n', re.S | re.M)


def log(m): print(m, flush=True)


def tbc_build(addon_dir):
    """The TBC Anniversary build PB's vendor prices were baked from."""
    p = os.path.join(addon_dir, "Data", "VendorPrices.lua")
    m = re.search(r"build (\d+\.\d+\.\d+\.\d+)", open(p, encoding="utf-8").read())
    if not m:
        sys.exit("yield_db: no TBC build stamp in " + p)
    return m.group(1)


def read_effects(build, csv_dir):
    if csv_dir:
        path = os.path.join(csv_dir, "SpellEffect_%s.csv" % build)
        fh = open(path, encoding="utf-8", newline="")
        rows = csv.DictReader(fh)
    else:
        url = "https://wago.tools/db2/SpellEffect/csv?build=%s" % build
        req = urllib.request.Request(url, headers={"User-Agent": "ProfessionBuddy-bake"})
        text = urllib.request.urlopen(req, timeout=600).read().decode("utf-8")
        rows = csv.DictReader(io.StringIO(text))
    out = {}
    for r in rows:
        if (r.get("Effect") or "") != str(CREATE_ITEM):
            continue
        out.setdefault(int(r["SpellID"]), []).append(r)
    return out


def amount(rows, item, forever):
    """(low, high) items one cast makes, or None"""
    pick = [r for r in rows if int(r.get("EffectItemType") or 0) == item] or rows
    if not pick:
        return None
    r = pick[0]
    if forever:
        base = float(r.get("EffectBasePointsF") or 0)
        half = base * float(r.get("Variance") or 0) / 2
        lo, hi = int(round(base - half)), int(round(base + half))
    else:
        base, die = int(float(r.get("EffectBasePoints") or 0)), int(r.get("EffectDieSides") or 0)
        lo, hi = (base + 1, base + die) if die >= 1 else (base, base)
    return max(lo, 1), max(hi, 1)


def wanted(lo, hi):
    """The fields a recipe should carry: {} for one item"""
    w = {}
    if hi > 1:
        w["yield"] = int(round((lo + hi) / 2.0))
    if lo != hi:
        w["yieldMin"], w["yieldMax"] = lo, hi
    return w


def field(body, name):
    m = re.search(r"^\s+%s\s*=\s*(\d+),\s*$" % name, body, re.M)
    return int(m.group(1)) if m else None


def files(addon_dir, forever):
    d = os.path.join(addon_dir, "Data", "Forever") if forever else os.path.join(addon_dir, "Data")
    skip = {"VendorPrices.lua", "Disenchant.lua", "Waylaid.lua", "Writs.lua", "Tools.lua",
            "RandomStats.lua", "GatherMobs.lua", "GatherNodes.lua"}
    for f in sorted(os.listdir(d)):
        if f.endswith(".lua") and f not in skip:
            yield os.path.join(d, f)


def plan(addon_dir, forever, effects):
    """{path: [(name, have, want)]} for every recipe whose fields differ"""
    changes, problems, seen = {}, [], {}
    for path in files(addon_dir, forever):
        text = open(path, encoding="utf-8").read()
        for m in BLOCK.finditer(text):
            name, body = m.group(1), m.group(2)
            sp, item = field(body, "spellID"), field(body, "itemID")
            if not sp or not item:
                continue
            got = amount(effects.get(sp, []), item, forever)
            if not got:
                continue
            want = wanted(*got)
            have = {k: field(body, k) for k in ("yield", "yieldMin", "yieldMax")}
            have = {k: v for k, v in have.items() if v is not None}
            seen[sp] = got
            if forever and want.get("yield", 1) != have.get("yield", 1):
                problems.append("%s %s: the bake wrote yield %s, the game's table says %s; rebake"
                                % (os.path.basename(path), name, have.get("yield", 1), want.get("yield", 1)))
                continue
            if have != want:
                changes.setdefault(path, []).append((name, have, want))
    for sp, (lo, hi) in ANCHORS.items():
        if sp in seen and seen[sp] != (lo, hi):
            problems.append("anchor spell %d makes %s, expected %s" % (sp, seen[sp], (lo, hi)))
    return changes, problems


def rewrite(path, items, forever):
    text = open(path, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    text = text.replace("\r\n", "\n")
    todo = {name: want for name, _, want in items}

    def fix(m):
        name, body = m.group(1), m.group(2)
        if name not in todo:
            return m.group(0)
        want = todo[name]
        body = re.sub(r"^\s+yield(Min|Max)?\s*=\s*\d+,\s*\n", "", body, flags=re.M)
        if forever:
            # after itemID, as the bake writes it; the bake keeps yield
            lines = []
            if "yield" in want:
                lines.append("        yield      = %d,\n" % want["yield"])
            if "yieldMin" in want:
                lines.append("        yieldMin   = %d,\n" % want["yieldMin"])
                lines.append("        yieldMax   = %d,\n" % want["yieldMax"])
            body = re.sub(r"(^        itemID\s*=\s*\d+,\n)", lambda x: x.group(1) + "".join(lines), body, count=1, flags=re.M)
        else:
            lines = []
            if "yield" in want:
                lines.append("        yield = %d,\n" % want["yield"])
            if "yieldMin" in want:
                lines.append("        yieldMin = %d,\n" % want["yieldMin"])
                lines.append("        yieldMax = %d,\n" % want["yieldMax"])
            if re.search(r"^        reagents = \{", body, re.M):
                body = re.sub(r"(^        reagents = \{)", lambda x: "".join(lines) + x.group(1), body, count=1, flags=re.M)
            else:
                body = body + "".join(lines)
        return '    ["%s"] = {\n%s    },\n' % (name, body)

    text = BLOCK.sub(fix, text)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text.replace("\n", nl))


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
    total, bad = 0, []
    for label, forever, build in builds:
        effects = read_effects(build, a.csv)
        changes, problems = plan(a.addon_dir, forever, effects)
        n = sum(len(v) for v in changes.values())
        total += n
        bad += problems
        log("%s (build %s): %d recipes to change" % (label, build, n))
        for path, items in changes.items():
            for name, have, want in items:
                log("  %s / %s: %s -> %s" % (os.path.basename(path)[:-4], name, have or "{}", want or "{}"))
            if a.regen and a.write:
                rewrite(path, items, forever)
    for p in bad:
        log("PROBLEM " + p)
    if bad:
        sys.exit("yield_db: %d problems" % len(bad))
    if a.check:
        if total:
            log("REBAKE: python tools/yield_db.py --regen --write")
            sys.exit(10)
        log("UP TO DATE")
        sys.exit(0)
    if a.regen and a.write:
        log("wrote %d recipes" % total)


if __name__ == "__main__":
    main()
