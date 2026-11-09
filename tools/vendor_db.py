#!/usr/bin/env python3
"""ProfessionBuddy vendor-price tool.

What a vendor charges for a recipe material, for the price of a craft
(Prices.lua). A vendor-sold material (thread, vials, flux, spices) is
priced at the cheaper of its auction price and this. Which items a vendor
sells lives on Blizzard's servers, so the list comes from the same emulator
databases as the gathering and disenchant data (tools/gather_db.py); the
price comes from each game's own item table (ItemSparse BuyPrice for a
stack of VendorStackCount):

  tbc      cmangos-tbc Full_DB + TBC Anniversary ItemSparse -> Data/VendorPrices.lua
  classic  VMaNGOS db_latest  + WoW: Forever ItemSparse     -> Data/Forever/VendorPrices.lua

Only materials of ProfessionBuddy's recipes (the reagents in Data/*.lua or
Data/Forever/*.lua), sold by some vendor with unlimited stock (maxcount 0)
and for money alone (no ExtendedCost on cmangos), and only by a vendor
the database places in the world: a creature row with its ID (VMaNGOS:
any of id..id5), directly or through its vendor template. cmangos keeps
test vendors that are never placed: 26304 "General Goods Vendor" sells
every primal, Arcane Dust and Void Crystal for gold, 26309 sells raid
drops (2.1.0 TEST-b3: Primal Nether priced at a vendor's 1g 60s). A price PB records at a
vendor in game beats the baked one.

  --check   compare the databases and game builds baked into both files
            with the newest. Exits 0 = up to date, 10 = a newer one exists.
  --regen   rebuild one file (--source tbc|classic); --write writes it.
            --from FILE reads a downloaded dump (TBCDB .sql.gz or VMaNGOS
            db-sqlite .zip); --csv DIR reads ItemSparse.csv from DIR.

Usage:
  python tools/vendor_db.py --check [--addon-dir <path>]
  python tools/vendor_db.py --regen [--source tbc|classic] [--from FILE] [--csv DIR] [--write]
"""
import argparse, csv, glob, gzip, io, json, os, re, sqlite3, sys, tempfile, urllib.request, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gather_db as G

# Anchors: materials trade-goods vendors sell, with their unit price in
# copper from the game's own BuyPrice, so a broken join fails the bake:
# Coarse Thread 10c, Fine Thread 1s, Rune Thread 50s (TBC Anniversary),
# Red Dye 50c (WoW: Forever).
ANCHORS = {2320: 10, 2321: 100, 14341: 5000}
FOREVER_ANCHORS = {2320: 10, 2321: 100, 2604: 50}


def log(m): print(m, flush=True)


def paths(addon_dir):
    return (os.path.join(addon_dir, "Data", "VendorPrices.lua"),
            os.path.join(addon_dir, "Data", "Forever", "VendorPrices.lua"))


def baked_stamp(p, pattern):
    if not os.path.isfile(p): return None
    m = re.search(pattern, open(p, encoding="utf-8").read())
    return m.group(1) if m else None


def reagent_ids(data_dir):
    """Every reagent item ID in the recipe data files directly in data_dir."""
    ids = set()
    for p in glob.glob(os.path.join(data_dir, "*.lua")):
        txt = open(p, encoding="utf-8").read()
        ids |= {int(x) for x in re.findall(r"\{\s*itemID\s*=\s*(\d+),\s*count\s*=", txt)}
    return ids


# ---- which items a vendor sells ----
def sql_rows(sql, table, cols):
    """The rows of a cmangos table's INSERTs, as {column: text}."""
    idx = G.col_index(sql, table, cols)
    for mm in re.finditer(r"INSERT INTO `%s`[^;]*;" % table, sql, re.S):
        for t in re.finditer(r"\(((?:[^()']|'(?:[^'\\]|\\.|'')*')*)\)", G.t_body(mm.group(0))):
            f = G.split_tuple(t.group(1))
            try:
                yield {c: f[idx[c]] for c in cols}
            except IndexError:
                continue


def tbc_vendor_items(sql):
    placed = set()
    for r in sql_rows(sql, "creature", ["id"]):
        try: placed.add(int(r["id"]))
        except ValueError: pass
    # npc_vendor_template rows reach a vendor through VendorTemplateId
    users = {}
    for r in sql_rows(sql, "creature_template", ["Entry", "VendorTemplateId"]):
        try: e, v = int(r["Entry"]), int(r["VendorTemplateId"] or 0)
        except ValueError: continue
        if v: users.setdefault(v, set()).add(e)
    items = set()
    for table in ("npc_vendor", "npc_vendor_template"):
        for r in sql_rows(sql, table, ["entry", "item", "maxcount", "ExtendedCost"]):
            try:
                entry, item, mx, ext = int(r["entry"]), int(r["item"]), int(r["maxcount"]), int(r["ExtendedCost"])
            except ValueError:
                continue
            npcs = {entry} if table == "npc_vendor" else users.get(entry, set())
            if mx == 0 and ext == 0 and npcs & placed:
                items.add(item)
    return items


def classic_vendor_items(db):
    c = sqlite3.connect(db)
    placed = set()
    cols = [r[1] for r in c.execute("PRAGMA table_info(creature)")]
    for col in [x for x in ("id", "id2", "id3", "id4", "id5") if x in cols]:
        placed |= {r[0] for r in c.execute("SELECT DISTINCT %s FROM creature WHERE %s > 0" % (col, col))}
    users = {}
    for e, v in c.execute("SELECT entry, vendor_id FROM creature_template WHERE vendor_id > 0"):
        users.setdefault(v, set()).add(e)
    items = set()
    for table in ("npc_vendor", "npc_vendor_template"):
        for entry, item, mx in c.execute("SELECT entry, item, maxcount FROM %s" % table):
            npcs = {entry} if table == "npc_vendor" else users.get(entry, set())
            if mx == 0 and npcs & placed:
                items.add(item)
    c.close()
    return items


# ---- the game's own prices ----
def latest_tbc_build():
    """The newest TBC Anniversary build (2.5.x) on wago.tools."""
    req = urllib.request.Request("https://wago.tools/api/builds", headers={"User-Agent": "ProfessionBuddy-bake"})
    builds = json.loads(urllib.request.urlopen(req, timeout=60).read().decode())
    best = None
    for rows in builds.values():
        for b in rows or []:
            v = str(b.get("version", ""))
            parts = v.split(".")
            if len(parts) == 4 and parts[0] == "2" and parts[1] == "5" and all(p.isdigit() for p in parts):
                key = tuple(int(x) for x in parts)
                if best is None or key > best[0]:
                    best = (key, v)
    return best and best[1]


def item_sparse(csvdir, build):
    p = os.path.join(csvdir, "ItemSparse.csv") if csvdir else None
    if p and os.path.isfile(p):
        rows = csv.DictReader(open(p, encoding="utf-8"))
    else:
        url = "https://wago.tools/db2/ItemSparse/csv?build=%s" % build
        log("  fetching ItemSparse for %s ..." % build)
        raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=300).read()
        rows = csv.DictReader(io.StringIO(raw.decode("utf-8")))
    prices = {}
    for r in rows:
        try:
            iid, buy, stack = int(r["ID"]), int(r["BuyPrice"]), int(r.get("VendorStackCount") or 1)
        except (KeyError, ValueError):
            continue
        if buy > 0:
            prices[iid] = (buy, max(stack, 1))
    return prices


def lua_file(rel, label, build, prices):
    lines = [
        "-- ProfessionBuddy  --  %s" % rel,
        "-- What a vendor charges for a recipe material, in copper per item.",
        "-- Generated by tools/vendor_db.py from %s (which vendor sells it) and" % label,
        "-- the game's item table, build %s (BuyPrice / VendorStackCount)." % build,
        "-- Do not edit by hand; regenerate.",
        "local addon = ProfBuddy",
        "addon.VendorPrices = {",
    ]
    for iid in sorted(prices):
        lines.append("    [%d] = %s," % (iid, fmt(prices[iid])))
    lines.append("}")
    return "\n".join(lines) + "\n"


def fmt(v):
    if v == int(v): return str(int(v))
    return ("%.4f" % v).rstrip("0").rstrip(".")


def regen(addon_dir, source, from_file, csvdir, write, want_build=None):
    tbc_path, classic_path = paths(addon_dir)
    if source == "tbc":
        if from_file:
            version = re.search(r"TBCDB[_-](\d+\.\d+\.\d+)", os.path.basename(from_file)).group(1)
            raw = open(from_file, "rb").read()
        else:
            version, url = G.latest_cmangos()
            log("downloading cmangos TBCDB %s ..." % version)
            raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=300).read()
        sold = tbc_vendor_items(gzip.decompress(raw).decode("utf-8", errors="replace"))
        label, path, rel, anchors = "cmangos TBCDB %s" % version, tbc_path, "Data/VendorPrices.lua", ANCHORS
        build = want_build or latest_tbc_build()
        reagents = reagent_ids(os.path.join(addon_dir, "Data"))
    else:
        if from_file:
            version = re.search(r"db-sqlite-([0-9a-f]+)", os.path.basename(from_file)).group(1)
            raw = open(from_file, "rb").read()
        else:
            version, url = G.latest_classic()
            log("downloading VMaNGOS db %s ..." % version)
            raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=300).read()
        with tempfile.TemporaryDirectory() as tmp:
            zipfile.ZipFile(io.BytesIO(raw)).extract("sqlite-dump/mangos.sqlite", tmp)
            sold = classic_vendor_items(os.path.join(tmp, "sqlite-dump", "mangos.sqlite"))
        label, path, rel, anchors = "VMaNGOS db %s" % version, classic_path, "Data/Forever/VendorPrices.lua", FOREVER_ANCHORS
        import bake_forever_db2
        build = bake_forever_db2.baked_build(os.path.join(addon_dir, "Data", "Forever"))
        if not build: G.die("no baked Forever build in Data/Forever (run tools/bake_forever_db2.py first)")
        reagents = reagent_ids(os.path.join(addon_dir, "Data", "Forever"))
    if not build: G.die("no game build found for %s" % source)
    game = item_sparse(csvdir, build)
    prices = {}
    for iid in reagents & sold:
        if iid in game:
            buy, stack = game[iid]
            prices[iid] = buy / stack
    for iid, want in anchors.items():
        got = prices.get(iid)
        if got != want:
            G.die("anchor failed: item %d priced %s, expected %s" % (iid, got, want))
    log("  anchors OK  |  %s, build %s: %d vendor-sold materials (of %d reagents, %d sold items)"
        % (label, build, len(prices), len(reagents), len(sold)))
    txt = lua_file(rel, label, build, prices)
    if os.path.isfile(path):
        old = open(path, encoding="utf-8").read()
        log("  vs current file: %s" % ("same" if old == txt else "changed (%d -> %d bytes)" % (len(old), len(txt))))
    if not write:
        log("  (dry run -- pass --write to write %s)" % rel)
        return
    open(path, "w", encoding="utf-8", newline="\n").write(txt)
    log("  WROTE %s (%d bytes)" % (rel, len(txt)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--addon-dir", default=G.default_addon_dir())
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--regen", action="store_true")
    ap.add_argument("--source", choices=("tbc", "classic"), default="tbc")
    ap.add_argument("--from", dest="from_file")
    ap.add_argument("--csv", dest="csvdir")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--build", help="game build for prices (default: the newest for tbc, the recipe data's for classic)")
    a = ap.parse_args()
    if a.check or not a.regen:
        tbc_path, classic_path = paths(a.addon_dir)
        cur = baked_stamp(tbc_path, r"cmangos TBCDB (\d+\.\d+\.\d+)")
        ccur = baked_stamp(classic_path, r"VMaNGOS db ([0-9a-f]{7,40})")
        tb = baked_stamp(tbc_path, r"build (2\.5\.\d+\.\d+)")
        fb = baked_stamp(classic_path, r"build (\d+\.\d+\.\d+\.\d+)")
        latest, clatest = G.latest_cmangos()[0], G.latest_classic()[0]
        tlatest = latest_tbc_build()
        import bake_forever_db2
        frecipe = bake_forever_db2.baked_build(os.path.join(a.addon_dir, "Data", "Forever"))
        log("vendor prices (TBC Anniversary): baked=%s, build %s  latest cmangos=%s, build %s" % (cur, tb, latest, tlatest))
        log("vendor prices (WoW: Forever):    baked=%s, build %s  latest VMaNGOS=%s, recipe data build %s"
            % (ccur, fb, clatest, frecipe))
        stale = []
        if cur != latest or tb != tlatest: stale.append("--source tbc")
        if ccur != clatest or fb != frecipe: stale.append("--source classic")
        if not stale:
            log("UP TO DATE -- no vendor-price regen needed for release."); sys.exit(0)
        log("NEWER data available: run --regen %s --write before the CurseForge release."
            % " and --regen ".join(stale)); sys.exit(10)
    regen(a.addon_dir, a.source, a.from_file, a.csvdir, a.write, a.build)


if __name__ == "__main__":
    main()
