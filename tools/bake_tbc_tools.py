#!/usr/bin/env python3
"""Bake ProfessionBuddy's TBC Anniversary tool requirements (Data/Tools.lua).

    python tools/bake_tbc_tools.py <csvdir> [--build 2.5.6.69795] [--fetch]

<csvdir> holds the TBC Anniversary build's SpellTotems, TotemCategory and
ItemSparse as CSV from wago.tools (product wow_anniversary); --fetch
downloads them. The recipes are the spellIDs in ProfessionBuddy/Data/*.lua.
Every tool a recipe needs other than its Enchanting rod (the hand-kept
`rod` field) goes in, with the items that satisfy each; the rule is
tool_tables in bake_forever_db2.py, shared with WoW: Forever.
"""
import argparse, glob, os, re, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_forever_db2 as bf   # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, ".."))
DATA = os.path.join(REPO, "ProfessionBuddy", "Data")
TABLES = ["SpellTotems", "TotemCategory", "ItemSparse"]


def recipe_spells(data_dir):
    spells = set()
    for path in glob.glob(os.path.join(data_dir, "*.lua")):
        if os.path.basename(path) == "Tools.lua":
            continue
        spells |= {int(x) for x in re.findall(r"spellID\s*=\s*(\d+)", open(path, encoding="utf-8").read())}
    return spells


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("csvdir")
    ap.add_argument("--build", default="2.5.6.69795")
    ap.add_argument("--fetch", action="store_true")
    a = ap.parse_args()
    if a.fetch:
        os.makedirs(a.csvdir, exist_ok=True)
        for t in TABLES:
            url = "https://wago.tools/db2/%s/csv?build=%s" % (t, a.build)
            req = urllib.request.Request(url, headers={"User-Agent": "ProfessionBuddy-bake"})
            with urllib.request.urlopen(req, timeout=120) as r, open(os.path.join(a.csvdir, t + ".csv"), "wb") as fh:
                fh.write(r.read())
            print("fetched", t)
    spells = recipe_spells(DATA)
    rt, cats, inames = bf.tool_tables(a.csvdir, spells)
    out = os.path.join(DATA, "Tools.lua")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(bf.emit_tools(rt, cats, inames, a.build, "Data/Tools.lua",
                               "TBC Anniversary's SpellTotems, TotemCategory and ItemSparse"))
    print("%d of %d recipes need a tool -> %s" % (len(rt), len(spells), out))
    for cid in sorted(cats):
        print("  %-28s %d items satisfy it" % (cats[cid]["name"], len(cats[cid]["items"])))
    for iid in sorted(inames):
        print("  item %-6d %s" % (iid, inames[iid]))


if __name__ == "__main__":
    main()
