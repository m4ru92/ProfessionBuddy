#!/usr/bin/env python3
"""ProfessionBuddy Waylaid Supplies tool (WoW: Forever).

What each Waylaid Supplies crate takes to fill, for the crate's tooltip
("Fill cost", 2.1.0 TEST-c). A crate's use spell ("Replace Supplies")
consumes the requested items and creates the filled Supply Shipment, so
the game data has it all, no in-game harvest:

  ItemSparse        "Waylaid Supplies: <item>" items
  ItemXItemEffect   crate -> its item effect
  ItemEffect        -> the use spell
  SpellReagents     -> the item and count it takes (one reagent each)
  SpellEffect       -> the item it creates (Effect 24, EffectItemType)

And each "Waylaid Crate: <kind>" (2.2.0 TEST-c2, Hircus), which takes any
one bundle from a list. Its use spell ("Stock Crate") has no reagents:
the list is the spell's text, one "- $M<n> <item name>" line per bundle,
where $M<n> is the base points of the spell's effect n-1 (the count):

  Spell             -> the use spell's text (Description_lang)
  SpellEffect       -> each bundle's count (EffectBasePointsF)
  ItemSparse        -> the item by its name; a name two items share is
                       settled by the one a spell takes as a reagent

And the unopened ones (2.2.0 TEST-c5, m4ru): an item whose use spell is
"Read Label" (a plain "Waylaid Crate", which becomes one of the named
ones) or "Open Letter" (a "Sealed ... Writ", which becomes a random writ).
They ask for nothing until used; PB shows what they sell for.

  SpellName         -> the use spell's name

Writes Data/Forever/Waylaid.lua, stamped with the game build it was read
from. That build must be the Forever recipe data's (tools/bake_forever_db2.py).

  --check   is Waylaid.lua baked from the same build as the Forever recipe
            data? Exits 0 = yes, 10 = rebake (--regen --write).
  --regen   read the tables from wago.tools for --build (default: the
            Forever recipe data's build); --write writes the file.
            --csv DIR reads <Table>.csv from DIR instead.

Usage:
  python tools/waylaid_db.py --check [--addon-dir <path>]
  python tools/waylaid_db.py --regen [--build B] [--csv DIR] [--write]
"""
import argparse, csv, io, os, re, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake_forever_db2 as F

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ADDON = os.path.normpath(os.path.join(HERE, "..", "ProfessionBuddy"))
PREFIX = "Waylaid Supplies: "
CREATE_ITEM = 24          # SpellEffect.Effect: create item
# Anchor, from m4ru's /pbt quest probe (2026-11-08): the Copper Bars crate's
# spell 427020 takes 20 Copper Bar (2840) and creates Supply Shipment 211365.
ANCHOR_SPELL = 427020
ANCHOR = (2840, 20, 211365)
EXPECT_MIN = 100          # 104 crates on build 1.60.1.70862
BUNDLE_PREFIX = "Waylaid Crate: "
# Anchor, from Hircus's tooltip (2026-11-13): Earthly Expert Herbs takes
# 20 Liferoot, 10 Fadeleaf, 10 Goldthorn or 10 Khadgar's Whisker
BUNDLE_ANCHOR = (248690, [(3357, 20), (3818, 10), (3821, 10), (3358, 10)])
BUNDLE_EXPECT = 30        # 30 on build 1.60.1.70888
UNOPENED_SPELLS = {"Read Label": "crate", "Open Letter": "writ"}
# Waylaid Crate 248549, Sealed Craftsman's Writ 248206, Sealed Apprentice's,
# Journeyman's, Expert's and Artisan's Writ 262887-262890 (build 70888)
UNOPENED_EXPECT = {248549, 248206, 262887, 262888, 262889, 262890}


def log(m): print(m, flush=True)


def out_path(addon_dir):
    return os.path.join(addon_dir, "Data", "Forever", "Waylaid.lua")


def baked_stamp(p):
    if not os.path.isfile(p): return None
    m = re.search(r"build (\d+\.\d+\.\d+\.\d+)", open(p, encoding="utf-8").read())
    return m.group(1) if m else None


def read_table(name, build, csv_dir):
    if csv_dir:
        with open(os.path.join(csv_dir, name + ".csv"), encoding="utf-8", newline="") as fh:
            return list(csv.DictReader(fh))
    url = "https://wago.tools/db2/%s/csv?build=%s" % (name, build)
    req = urllib.request.Request(url, headers={"User-Agent": "ProfessionBuddy-bake"})
    text = urllib.request.urlopen(req, timeout=300).read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(text)))


def bake(build, csv_dir):
    items = read_table("ItemSparse", build, csv_dir)
    crates = {int(r["ID"]): r["Display_lang"][len(PREFIX):] for r in items
              if (r.get("Display_lang") or "").startswith(PREFIX)}
    names = {int(r["ID"]): r["Display_lang"] for r in items}
    effect_of = {}
    for r in read_table("ItemXItemEffect", build, csv_dir):
        iid = int(r["ItemID"])
        if iid in crates: effect_of.setdefault(iid, []).append(int(r["ItemEffectID"]))
    spell_of_effect = {int(r["ID"]): int(r["SpellID"]) for r in read_table("ItemEffect", build, csv_dir)}
    reagents = {}
    for r in read_table("SpellReagents", build, csv_dir):
        got = []
        for i in range(8):
            rid, n = int(r.get("Reagent_%d" % i) or 0), int(r.get("ReagentCount_%d" % i) or 0)
            if rid > 0 and n > 0: got.append((rid, n))
        if got: reagents[int(r["SpellID"])] = got
    creates, points = {}, {}
    for r in read_table("SpellEffect", build, csv_dir):
        if int(r.get("Effect") or 0) == CREATE_ITEM and int(r.get("EffectItemType") or 0) > 0:
            creates.setdefault(int(r["SpellID"]), int(r["EffectItemType"]))
        points[(int(r["SpellID"]), int(r["EffectIndex"]))] = float(r.get("EffectBasePointsF") or 0)
    bundles = bake_bundles(build, csv_dir, items, spell_of_effect, reagents, points)
    unopened = bake_unopened(build, csv_dir, items, spell_of_effect)

    table, problems = {}, []
    for crate in sorted(crates):
        spells = [spell_of_effect[e] for e in effect_of.get(crate, []) if spell_of_effect.get(e) in reagents]
        if len(spells) != 1:
            problems.append("%d %s: %d use spells with reagents" % (crate, crates[crate], len(spells)))
            continue
        sp = spells[0]
        if len(reagents[sp]) != 1:
            problems.append("%d %s: %d reagents (one expected)" % (crate, crates[crate], len(reagents[sp])))
            continue
        item, count = reagents[sp][0]
        table[crate] = (item, count, creates.get(sp, 0), sp)

    if problems:
        for p in problems: log("PROBLEM " + p)
        sys.exit("waylaid_db: %d crates could not be read" % len(problems))
    anchor = [v for v in table.values() if v[3] == ANCHOR_SPELL]
    if not anchor or anchor[0][:3] != ANCHOR:
        sys.exit("waylaid_db: anchor failed: spell %d should be %s, got %s" % (ANCHOR_SPELL, ANCHOR, anchor))
    if len(table) < EXPECT_MIN:
        sys.exit("waylaid_db: only %d crates (expected at least %d)" % (len(table), EXPECT_MIN))
    return table, crates, names, bundles, unopened


def bake_unopened(build, csv_dir, items, spell_of_effect):
    """{ item: (kind, name) } for each item used through Read Label or Open Letter."""
    spell_name = {int(r["ID"]): r.get("Name_lang") or "" for r in read_table("SpellName", build, csv_dir)}
    names = {int(r["ID"]): r.get("Display_lang") or "" for r in items}
    out = {}
    for r in read_table("ItemXItemEffect", build, csv_dir):
        kind = UNOPENED_SPELLS.get(spell_name.get(spell_of_effect.get(int(r["ItemEffectID"]), 0), ""))
        if kind:
            out[int(r["ItemID"])] = (kind, names.get(int(r["ItemID"]), ""))
    if set(out) != UNOPENED_EXPECT:
        sys.exit("waylaid_db: unopened items %s (expected %s)" % (sorted(out), sorted(UNOPENED_EXPECT)))
    return out


def bake_bundles(build, csv_dir, items, spell_of_effect, reagents, points):
    """{ crate: (kind, [(item, count), ...]) } for each "Waylaid Crate: <kind>"."""
    kinds = {int(r["ID"]): r["Display_lang"][len(BUNDLE_PREFIX):] for r in items
             if (r.get("Display_lang") or "").startswith(BUNDLE_PREFIX)}
    by_name = {}
    for r in items:
        by_name.setdefault(r.get("Display_lang") or "", []).append(int(r["ID"]))
    used = set(i for got in reagents.values() for i, _ in got)
    effects = {}
    for r in read_table("ItemXItemEffect", build, csv_dir):
        iid = int(r["ItemID"])
        if iid in kinds: effects.setdefault(iid, []).append(int(r["ItemEffectID"]))
    text = {int(r["ID"]): r.get("Description_lang") or "" for r in read_table("Spell", build, csv_dir)}
    out, problems = {}, []
    for crate in sorted(kinds):
        spells = [spell_of_effect[e] for e in effects.get(crate, []) if e in spell_of_effect]
        if len(spells) != 1:
            problems.append("%d %s: %d use spells" % (crate, kinds[crate], len(spells)))
            continue
        sp = spells[0]
        lines = re.findall(r"- \$M(\d+) ([^\n|]+)", text.get(sp, ""))
        got = []
        for m, name in lines:
            name = name.strip()
            count = int(points.get((sp, int(m) - 1), 0))
            ids = by_name.get(name, [])
            if len(ids) > 1: ids = [i for i in ids if i in used]
            if count < 1 or len(ids) != 1:
                problems.append("%d %s: bundle %r count %d items %s" % (crate, kinds[crate], name, count, by_name.get(name)))
                continue
            got.append((ids[0], count))
        if len(got) < 2:
            problems.append("%d %s: %d bundles read" % (crate, kinds[crate], len(got)))
            continue
        out[crate] = (kinds[crate], got)
    if problems:
        for p in problems: log("PROBLEM " + p)
        sys.exit("waylaid_db: %d Waylaid Crates could not be read" % len(problems))
    a_crate, a_bundles = BUNDLE_ANCHOR
    if out.get(a_crate, (None, None))[1] != a_bundles:
        sys.exit("waylaid_db: anchor failed: crate %d should be %s, got %s" % (a_crate, a_bundles, out.get(a_crate)))
    if len(out) != BUNDLE_EXPECT:
        sys.exit("waylaid_db: %d Waylaid Crates (expected %d)" % (len(out), BUNDLE_EXPECT))
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(table, crates, names, build, bundles, unopened):
    lines = [
        "-- ProfessionBuddy  --  Data/Forever/Waylaid.lua",
        "-- What each Waylaid Supplies crate takes to fill: the item and count its",
        "-- use spell consumes, and the Supply Shipment it becomes. For the crate's",
        "-- tooltip (Fill cost, UI/TradeSkillFrame.lua). WoW: Forever only.",
        "-- Generated by tools/waylaid_db.py from the game's tables, build %s" % build,
        "-- (ItemXItemEffect, ItemEffect, SpellReagents, SpellEffect, Spell, SpellName). Do not edit by hand.",
        "local addon = ProfBuddy",
        "-- [crate] = { item, count, shipment, item name (shown until the game",
        "-- has loaded the item) }",
        "addon.Waylaid = {",
    ]
    for crate in sorted(table):
        item, count, ship, _ = table[crate]
        if item not in names:
            sys.exit("waylaid_db: no name for item %d (crate %d)" % (item, crate))
        lines.append("    [%d] = { %d, %d, %d, %s },   -- %s: %d x %s" % (
            crate, item, count, ship, lua_str(names[item]), crates[crate], count, names[item]))
    lines.append("}")
    lines += [
        "-- Each Waylaid Crate takes any ONE bundle from its list (the use spell",
        "-- \"Stock Crate\"; the list is the spell's text, the counts its effects).",
        "-- [crate] = { name = kind, { item, count, item name }, ... } in the game's order",
        "addon.WaylaidBundles = {",
    ]
    for crate in sorted(bundles):
        kind, got = bundles[crate]
        for item, _ in got:
            if item not in names:
                sys.exit("waylaid_db: no name for item %d (crate %d)" % (item, crate))
        parts = ", ".join("{ %d, %d, %s }" % (item, count, lua_str(names[item])) for item, count in got)
        lines.append("    [%d] = { name = %s, %s }," % (crate, lua_str(kind), parts))
    lines.append("}")
    lines += [
        "-- Unopened: a plain Waylaid Crate (Read Label makes it one of the above)",
        "-- and the Sealed writs (Open Letter makes a random writ). They ask for",
        "-- nothing until used, and they sell at auction.",
        "-- [item] = { \"crate\" or \"writ\", item name }",
        "addon.WaylaidUnopened = {",
    ]
    for item in sorted(unopened):
        kind, name = unopened[item]
        lines.append("    [%d] = { %s, %s }," % (item, lua_str(kind), lua_str(name)))
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--addon-dir", default=DEFAULT_ADDON)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--regen", action="store_true")
    ap.add_argument("--build")
    ap.add_argument("--csv")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    data_build = F.baked_build(os.path.join(a.addon_dir, "Data", "Forever"))
    p = out_path(a.addon_dir)
    if a.check:
        baked = baked_stamp(p)
        log("Waylaid crates: baked=%s  Forever recipe data=%s" % (baked, data_build))
        if baked and baked == data_build:
            log("UP TO DATE")
            sys.exit(0)
        log("REBAKE: python tools/waylaid_db.py --regen --write")
        sys.exit(10)
    if a.regen:
        build = a.build or data_build
        table, crates, names, bundles, unopened = bake(build, a.csv)
        text = render(table, crates, names, build, bundles, unopened)
        log("%d crates, %d Waylaid Crates and %d unopened from build %s" % (len(table), len(bundles), len(unopened), build))
        if a.write:
            with open(p, "w", encoding="utf-8", newline="\n") as fh: fh.write(text)
            log("wrote " + p)
        else:
            sys.stdout.write(text[:1500])
        return
    ap.print_help()


if __name__ == "__main__":
    main()
