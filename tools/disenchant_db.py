#!/usr/bin/env python3
"""ProfessionBuddy disenchant-data tool.

What an item disenchants into, for the item tooltip's "Disenchants into"
section. The game's own files only say which items can be disenchanted and
at what skill; the materials and their chances live on Blizzard's servers,
so they come from the same emulator databases as the gathering data
(tools/gather_db.py):

  tbc      cmangos-tbc Full_DB  -> Data/Disenchant.lua          (TBC Anniversary)
  classic  VMaNGOS db_latest    -> Data/Forever/Disenchant.lua  (WoW: Forever)

Each item that can be disenchanted points to its loot group (item_template's
DisenchantID); each group lists its materials with a chance and a stack range
(disenchant_loot_template, read with gather_db.py's loot rules), and on TBC
Anniversary the Enchanting skill the group needs (the most common
RequiredDisenchantSkill of its items). WoW: Forever needs no Enchanting skill
to disenchant, so its file has none.

  --check   compare the databases baked into both files against the newest
            releases. Exits 0 = up to date, 10 = a newer database exists.
  --regen   rebuild one file (--source tbc|classic), validate known anchors,
            and print what changed; --write writes it. --from FILE reads a
            downloaded dump (TBCDB .sql.gz or VMaNGOS db-sqlite .zip) instead
            of downloading it.

WoW: Forever estimates (--source classic): the 1.12 database does not list
Forever's own new gear, and Forever lets you disenchant some items 1.12 did
not. So the classic bake also reads Forever's own tables (--forever-csv DIR:
Item, ItemSparse and ItemDisenchantLoot for the baked Forever build; any one
missing is fetched from wago.tools). An armor or weapon item of green, blue
or purple quality that VMaNGOS does not list, and that Forever does not flag
as not disenchantable (ItemSparse Flags_0 0x8000), goes in as an estimate:
Forever's own disenchant group for its quality, item level and type picks
it, and the materials are those of the VMaNGOS group most of that Forever
group's listed items use. The tooltip marks these as an estimate. --check
also compares the Forever build the estimates came from with the baked one.

Usage:
  python tools/disenchant_db.py --check [--addon-dir <path>]
  python tools/disenchant_db.py --regen [--source tbc|classic] [--from FILE] [--write]
"""
import argparse, collections, csv, gzip, io, os, re, sqlite3, sys, tempfile, urllib.request, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gather_db as G

# Anchors: (quality, armor 4 / weapon 2, item level) -> a material the item's
# group must give. Strange Dust (low greens), Arcane Dust (Outland greens),
# Void Crystal (Outland epics) on TBC; Strange Dust and Large Brilliant Shard
# (level 60 blues) on Forever.
TBC_ANCHORS = [((2, 4, 18), 10940), ((2, 4, 105), 22445), ((4, 4, 115), 22450)]
CLASSIC_ANCHORS = [((2, 4, 18), 10940), ((3, 4, 60), 14344)]

def log(m): print(m, flush=True)

def paths(addon_dir):
    return (os.path.join(addon_dir, "Data", "Disenchant.lua"),
            os.path.join(addon_dir, "Data", "Forever", "Disenchant.lua"))

def baked_stamp(p, pattern):
    if not os.path.isfile(p): return None
    m = re.search(pattern, open(p, encoding="utf-8").read())
    return m.group(1) if m else None

# ---- TBC Anniversary: cmangos MySQL dump ----
def tbc_tables(sql):
    """(items, loot, meta): items = itemID -> (quality, class, ilvl, group,
    skill); loot = group -> rows; meta = itemID -> (name, quality)."""
    idx = G.col_index(sql, "item_template",
                      ["entry", "class", "name", "Quality", "ItemLevel", "DisenchantID", "RequiredDisenchantSkill"])
    items, meta = {}, {}
    for mm in re.finditer(r"INSERT INTO `item_template`[^;]*;", sql, re.S):
        for t in re.finditer(r"\(((?:[^()']|'(?:[^'\\]|\\.|'')*')*)\)", G.t_body(mm.group(0))):
            f = G.split_tuple(t.group(1))
            try:
                e = int(f[idx["entry"]]); q = int(f[idx["Quality"]])
                meta[e] = (G.unq(f[idx["name"]]), q)
                d = int(f[idx["DisenchantID"]])
                if d > 0:
                    items[e] = (q, int(f[idx["class"]]), int(f[idx["ItemLevel"]]), d,
                                int(f[idx["RequiredDisenchantSkill"]]))
            except (ValueError, IndexError):
                pass
    loot = G.parse_loot(sql, "disenchant_loot_template")
    return items, loot, meta

# ---- WoW: Forever: VMaNGOS sqlite at 1.12 ----
def classic_tables(db):
    c = sqlite3.connect(db)
    items, meta = {}, {}
    for e, cl, name, q, il, d in c.execute(
            "SELECT entry, class, name, quality, item_level, disenchant_id FROM item_template "
            "WHERE patch <= ? ORDER BY entry, patch", (G.CLASSIC_PATCH,)):
        meta[e] = (name, q)
        if d and d > 0: items[e] = (q, cl, il, d, 0)
        else: items.pop(e, None)
    loot = {}
    for e, it, ch, gid, mc, mx, cond in c.execute(
            "SELECT entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition_id "
            "FROM disenchant_loot_template WHERE patch_min <= ? AND ? <= patch_max",
            (G.CLASSIC_PATCH, G.CLASSIC_PATCH)):
        loot.setdefault(e, []).append(dict(item=it, ch=float(ch), gid=gid, mc=mc, mx=mx, cond=cond))
    c.close()
    return items, loot, meta

NO_DISENCHANT = 0x8000   # ItemSparse Flags_0, as TrinityCore's ITEM_FLAG_NO_DISENCHANT

def forever_table(csvdir, build, name):
    p = os.path.join(csvdir, name + ".csv") if csvdir else None
    if p and os.path.isfile(p):
        return list(csv.DictReader(open(p, encoding="utf-8")))
    url = "https://wago.tools/db2/%s/csv?build=%s" % (name, build)
    log("  fetching %s for %s ..." % (name, build))
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=120).read()
    return list(csv.DictReader(io.StringIO(raw.decode("utf-8"))))

def forever_estimates(groups, csvdir, build):
    """{vmangos group: [itemID, ...]} for Forever's disenchantable armor and
    weapons that VMaNGOS does not list, by Forever's own disenchant groups."""
    cls = {int(r["ID"]): int(r["ClassID"]) for r in forever_table(csvdir, build, "Item")}
    idl = [{k: int(v) for k, v in r.items()} for r in forever_table(csvdir, build, "ItemDisenchantLoot")]
    def fgroup(q, c, il):
        for g in idl:
            if g["Quality"] == q and g["Class"] == c and g["MinLevel"] <= il <= g["MaxLevel"]:
                return g["ID"]
    listed = {}
    for d, g in groups.items():
        for e in g["items"]: listed[e] = d
    cand = []
    for r in forever_table(csvdir, build, "ItemSparse"):
        e, q, il = int(r["ID"]), int(r["OverallQualityID"]), int(r["ItemLevel"])
        c = cls.get(e)
        if c not in (2, 4) or not 2 <= q <= 4: continue
        fg = fgroup(q, c, il)
        if fg is None: continue
        cand.append((e, fg, (int(r["Flags_0"]) & 0xffffffff) & NO_DISENCHANT != 0))
    # Forever group -> the VMaNGOS group most of its listed items use
    votes = collections.defaultdict(collections.Counter)
    for e, fg, _ in cand:
        if e in listed: votes[fg][listed[e]] += 1
    to_vm = {fg: v.most_common(1)[0][0] for fg, v in votes.items()}
    est, unmapped = collections.defaultdict(list), 0
    for e, fg, flagged in cand:
        if e in listed or flagged: continue
        d = to_vm.get(fg)
        if d is None: unmapped += 1; continue
        est[d].append(e)
    for d in est: est[d].sort()
    return est, unmapped

def build(items, loot, meta, with_skill):
    """groups = group -> {skill, loot, items}; materials = itemID -> (name, q)."""
    groups, used = {}, set()
    skills = collections.defaultdict(collections.Counter)
    for e, (q, cl, il, d, sk) in items.items():
        if d not in loot: continue
        g = groups.setdefault(d, {"items": [], "loot": None, "skill": None})
        g["items"].append(e)
        if sk > 0: skills[d][sk] += 1
    for d, g in groups.items():
        rows = G.loot_rows(d, loot, {})
        g["loot"] = [(it, max(1, round(p)), mn, mx) for it, p, mn, mx, quest in rows if not quest and p > 0]
        g["items"].sort()
        if with_skill and skills[d]:
            g["skill"] = skills[d].most_common(1)[0][0]
        for it, *_ in g["loot"]: used.add(it)
    groups = {d: g for d, g in groups.items() if g["loot"]}
    materials = {it: meta.get(it, ("item:%d" % it, 1)) for it in used}
    return groups, materials

def check_anchors(items, groups, anchors):
    bad = []
    for (q, cl, il), mat in anchors:
        hits = [d for e, (iq, icl, iil, d, _) in items.items()
                if iq == q and icl == cl and iil == il and d in groups]
        if not hits: bad.append(((q, cl, il), "no item")); continue
        d = collections.Counter(hits).most_common(1)[0][0]
        if mat not in [t[0] for t in groups[d]["loot"]]: bad.append(((q, cl, il), mat))
    if bad: G.die("anchor validation FAILED: %s" % bad)

def lua_file(path_label, source_label, groups, materials, with_skill, estimates=None, fbuild=None):
    def qesc(s): return s.replace("\\", "\\\\").replace('"', '\\"')
    L = ["-- ProfessionBuddy  --  %s" % path_label,
         "-- Generated by tools/disenchant_db.py from %s: do not edit." % source_label,
         "-- What an item disenchants into, for the item tooltip. groups[n].items",
         "-- are the item IDs in loot group n; loot rows are { itemID, chance %, min, max }"
         + ("; skill is the Enchanting skill the group needs." if with_skill else "."),
         "-- materials[itemID] = { English name, quality }, used until the client",
         "-- has the item's own name."]
    if estimates is not None:
        L += ["-- estimates: Forever items the database does not list, placed by Forever's",
              "-- own disenchant groups (Forever build %s); the tooltip says estimate." % fbuild]
    L += [
         "ProfBuddy.Disenchant = {",
         '    source = "%s",' % qesc(source_label),
         "    materials = {"]
    for it in sorted(materials):
        n, q = materials[it]
        L.append('        [%d] = { "%s", %d },' % (it, qesc(n), q))
    L.append("    },")
    L.append("    groups = {")
    for d in sorted(groups):
        g = groups[d]
        loot = ", ".join("{ %d, %d, %d, %d }" % t for t in g["loot"])
        head = "        [%d] = { " % d + ("skill = %d, " % g["skill"] if with_skill and g["skill"] else "")
        L.append(head + "loot = { %s }," % loot)
        ids = g["items"]
        L.append("            items = {")
        for i in range(0, len(ids), 12):
            L.append("                " + ", ".join(str(x) for x in ids[i:i + 12]) + ",")
        L.append("            },")
        est = (estimates or {}).get(d)
        if est:
            L.append("            estimates = {")
            for i in range(0, len(est), 12):
                L.append("                " + ", ".join(str(x) for x in est[i:i + 12]) + ",")
            L.append("            },")
        L.append("        },")
    L.append("    },")
    L.append("}")
    return "\n".join(L) + "\n"

def regen(addon_dir, source, from_file, write, forever_csv=None):
    tbc_path, classic_path = paths(addon_dir)
    if source == "tbc":
        if from_file:
            version = re.search(r"TBCDB[_-](\d+\.\d+\.\d+)", os.path.basename(from_file)).group(1)
            raw = open(from_file, "rb").read()
        else:
            version, url = G.latest_cmangos()
            log("downloading cmangos TBCDB %s ..." % version)
            raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=300).read()
        sql = gzip.decompress(raw).decode("utf-8", errors="replace")
        items, loot, meta = tbc_tables(sql)
        label, path, anchors, with_skill, rel = "cmangos TBCDB %s" % version, tbc_path, TBC_ANCHORS, True, "Data/Disenchant.lua"
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
            items, loot, meta = classic_tables(os.path.join(tmp, "sqlite-dump", "mangos.sqlite"))
        label, path, anchors, with_skill, rel = "VMaNGOS db %s" % version, classic_path, CLASSIC_ANCHORS, False, "Data/Forever/Disenchant.lua"
    groups, materials = build(items, loot, meta, with_skill)
    check_anchors(items, groups, anchors)
    n = sum(len(g["items"]) for g in groups.values())
    log("  anchors OK  |  %s: %d items in %d groups, %d materials" % (label, n, len(groups), len(materials)))
    estimates, fbuild = None, None
    if source == "classic":
        import bake_forever_db2
        fbuild = bake_forever_db2.baked_build(os.path.join(addon_dir, "Data", "Forever"))
        if not fbuild: G.die("no baked Forever build in Data/Forever (run tools/bake_forever_db2.py first)")
        estimates, unmapped = forever_estimates(groups, forever_csv, fbuild)
        log("  Forever estimates (build %s): %d items in %d groups, %d with no Forever group match"
            % (fbuild, sum(len(v) for v in estimates.values()), len(estimates), unmapped))
    txt = lua_file(rel, label, groups, materials, with_skill, estimates, fbuild)
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
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--forever-csv", help="with --source classic: a folder with Forever's Item, ItemSparse "
                    "and ItemDisenchantLoot CSVs (else fetched from wago.tools)")
    a = ap.parse_args()
    if a.check or not a.regen:
        tbc_path, classic_path = paths(a.addon_dir)
        cur = baked_stamp(tbc_path, r"cmangos TBCDB (\d+\.\d+\.\d+)")
        ccur = baked_stamp(classic_path, r"VMaNGOS db ([0-9a-f]{7,40})")
        latest, clatest = G.latest_cmangos()[0], G.latest_classic()[0]
        import bake_forever_db2
        fb = bake_forever_db2.baked_build(os.path.join(a.addon_dir, "Data", "Forever"))
        efb = baked_stamp(classic_path, r"Forever build ([0-9.]+)\)")
        log("disenchant data (TBC Anniversary): baked=%s  latest cmangos=%s" % (cur, latest))
        log("disenchant data (WoW: Forever):    baked=%s  latest VMaNGOS=%s" % (ccur, clatest))
        log("Forever estimates:                 from build %s  recipe data build %s" % (efb, fb))
        stale = []
        if cur != latest: stale.append("--source tbc")
        if ccur != clatest or efb != fb: stale.append("--source classic")
        if not stale:
            log("UP TO DATE -- no disenchant-data regen needed for release."); sys.exit(0)
        log("NEWER DB available: run --regen %s --write before the CurseForge release."
            % " and --regen ".join(stale)); sys.exit(10)
    regen(a.addon_dir, a.source, a.from_file, a.write, a.forever_csv)

if __name__ == "__main__":
    main()
