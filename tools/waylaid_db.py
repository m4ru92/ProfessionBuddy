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
    creates = {}
    for r in read_table("SpellEffect", build, csv_dir):
        if int(r.get("Effect") or 0) == CREATE_ITEM and int(r.get("EffectItemType") or 0) > 0:
            creates.setdefault(int(r["SpellID"]), int(r["EffectItemType"]))

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
    return table, crates, names


def render(table, crates, names, build):
    lines = [
        "-- ProfessionBuddy  --  Data/Forever/Waylaid.lua",
        "-- What each Waylaid Supplies crate takes to fill: the item and count its",
        "-- use spell consumes, and the Supply Shipment it becomes. For the crate's",
        "-- tooltip (Fill cost, UI/TradeSkillFrame.lua). WoW: Forever only.",
        "-- Generated by tools/waylaid_db.py from the game's tables, build %s" % build,
        "-- (ItemXItemEffect, ItemEffect, SpellReagents, SpellEffect). Do not edit by hand.",
        "local addon = ProfBuddy",
        "-- [crate] = { item, count, shipment }",
        "addon.Waylaid = {",
    ]
    for crate in sorted(table):
        item, count, ship, _ = table[crate]
        lines.append("    [%d] = { %d, %d, %d },   -- %s: %d x %s" % (
            crate, item, count, ship, crates[crate], count, names.get(item, "?")))
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
        table, crates, names = bake(build, a.csv)
        text = render(table, crates, names, build)
        log("%d crates from build %s" % (len(table), build))
        if a.write:
            with open(p, "w", encoding="utf-8", newline="\n") as fh: fh.write(text)
            log("wrote " + p)
        else:
            sys.stdout.write(text[:1500])
        return
    ap.print_help()


if __name__ == "__main__":
    main()
