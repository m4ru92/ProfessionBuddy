#!/usr/bin/env python3
"""ProfessionBuddy gather-data DB tool.

Two sources, one per client:
  tbc      cmangos-tbc Full_DB  -> Data/GatherMobs.lua (TBC Anniversary)
  classic  VMaNGOS db_latest    -> Data/Forever/Gather.lua (WoW: Forever)

cmangos-tbc is the source of truth for the gather feature's mob data (which
creatures are skinnable / mineable / herbable). cmangos periodically republishes
its Full_DB under a NEW filename that encodes the version (e.g.
TBCDB_1.11.0_...sql.gz), and can shift the creature_template column layout
between versions. This tool:

  --check   compare the cmangos version baked into Data/GatherMobs.lua against
            the latest cmangos release. RUN THIS AT RELEASE PREP (before a
            CurseForge upload) so we never ship stale gather data. Exits 0 =
            up to date, 10 = a newer DB exists (regen recommended).

  --regen   download the latest cmangos DB, detect the creature_template columns
            DYNAMICALLY (survives schema shifts), regenerate the mob sets,
            PRESERVE the validated node tables, validate known-good anchors, and
            print a diff of what changed for review before writing.

WoW: Forever uses Classic NPC IDs, so its skinnable mobs and skinning loot
come from VMaNGOS, a 1.12 emulator database, read at its 1.12 patch. It
was picked over cmangos' own Classic DB on a check against Wowhead Classic
(2026-10-03): of 20 sampled mobs only VMaNGOS lists as skinnable, Wowhead
shows skinning on 17; of 20 only cmangos-classic lists, on 1. --check
covers both sources; --regen --source classic rewrites the mob and loot
tables of Data/Forever/Gather.lua (keeping its node tables) and writes
Data/Forever/NpcFactions.lua, the side each trainer and vendor serves (its
VMaNGOS faction read in the baked Forever build's FactionTemplate; run it
again after a Forever rebake).

Usage:
  python tools/gather_db.py --check [--addon-dir <path>]
  python tools/gather_db.py --regen [--source tbc|classic] [--addon-dir <path>] [--write]
"""
import argparse, json, os, re, sys, subprocess, urllib.request, io, gzip
import sqlite3, tempfile, zipfile

CMANGOS_API = "https://api.github.com/repos/cmangos/tbc-db/contents/Full_DB"
EXCLUDE_SKIN = {7395}  # hand-verified cmangos false-positives (Cockroach)
# known-good validation anchors: npcID -> expected skinnable (True/False)
ANCHORS = {1548: True, 18205: True, 721: True, 4075: False, 2565: False, 7395: False}

# WoW: Forever (Data/Forever/Gather.lua): VMaNGOS' rolling db_latest release.
CLASSIC_RELEASE_API = "https://api.github.com/repos/vmangos/core/releases/tags/db_latest"
CLASSIC_PATCH = 10   # VMaNGOS patch index of 1.12, Classic Era's last patch
# npcID -> expected skinnable. 3130/3247/4129 skinned and 3113 not, in game
# on Forever (m4ru, 2026-10-02); 4342 yes and 2565 no per Wowhead Classic.
CLASSIC_ANCHORS = {3130: True, 3247: True, 4129: True, 3113: False, 4342: True, 2565: False}
# node name -> an item its Classic loot must hold (Copper Ore, Peacebloom,
# Mithril Ore, Black Lotus)
NODE_ANCHORS = {"Copper Vein": 2770, "Peacebloom": 2447, "Mithril Deposit": 3858, "Black Lotus": 13468}

def log(m): print(m, flush=True)
def die(m): print("ERROR: " + m, file=sys.stderr); sys.exit(1)

def default_addon_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "ProfessionBuddy"))

def pick_latest(entries):
    """Return (version, download_url) for the NEWEST TBCDB archive in a GitHub
    contents listing.

    Split out from the network call so it can be tested with a fixed payload.
    The contents API sorts by filename and filename sort is not version sort
    (TBCDB_1.10.0 sorts before TBCDB_1.9.0), so compare parsed version tuples
    rather than taking the first match. A name that does not carry a version is
    not a candidate at all: returning the raw filename as the "version" made
    --check exit 10 forever with no way to tell that from a real update.
    """
    cands = []
    for f in entries:
        n = f.get("name", "")
        if not n.endswith(".sql.gz"):
            continue
        m = re.search(r"TBCDB[_-](\d+)\.(\d+)\.(\d+)", n)
        if m:
            cands.append((tuple(int(x) for x in m.groups()),
                          "%s.%s.%s" % m.groups(), f.get("download_url")))
    if not cands:
        die("no versioned TBCDB *.sql.gz found in the cmangos Full_DB listing "
            "(archive naming may have changed); nothing to compare against")
    best = max(cands)
    return best[1], best[2]


def latest_cmangos():
    """Return (version, download_url) of the newest Full_DB .sql.gz."""
    req = urllib.request.Request(CMANGOS_API, headers={"User-Agent": "pb-gather-db"})
    data = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
    return pick_latest(data)

def current_version(addon_dir):
    p = os.path.join(addon_dir, "Data", "GatherMobs.lua")
    if not os.path.isfile(p):
        die("no Data/GatherMobs.lua at " + p)
    m = re.search(r"TBCDB\s+(\d+\.\d+\.\d+)", open(p, encoding="utf-8").read())
    return m.group(1) if m else None

# ---- MySQL dump helpers (dynamic columns) ----
def split_tuple(s):
    out=[];cur=[];q=False;i=0
    while i < len(s):
        c=s[i]
        if q:
            if c=="\\" and i+1<len(s): cur.append(s[i:i+2]); i+=2; continue
            if c=="'" and i+1<len(s) and s[i+1]=="'": cur.append("''"); i+=2; continue
            if c=="'": q=False; cur.append(c); i+=1; continue
            cur.append(c); i+=1; continue
        if c=="'": q=True; cur.append(c); i+=1; continue
        if c==",": out.append("".join(cur)); cur=[]; i+=1; continue
        cur.append(c); i+=1
    out.append("".join(cur)); return out

def unq(v):
    v=v.strip()
    return v[1:-1].replace("''","'").replace("\\'","'") if len(v)>=2 and v[0]=="'" and v[-1]=="'" else v

def col_index(sql_text, table, colnames):
    """0-based index of each requested column, parsed from CREATE TABLE (so a
    schema shift between DB versions can't silently misalign our parse)."""
    m = re.search(r"CREATE TABLE `%s` \((.*?)\n\)" % table, sql_text, re.S)
    if not m: die("no CREATE TABLE for " + table)
    idx = {}; i = 0
    for line in m.group(1).splitlines():
        cm = re.match(r"\s*`([^`]+)`", line)
        if cm:
            if cm.group(1) in colnames: idx[cm.group(1)] = i
            i += 1
    missing = [c for c in colnames if c not in idx]
    if missing: die("columns not found in %s: %s" % (table, missing))
    return idx

# ---- skinning loot (exact items + drop chance) ----
# The gather tooltip's "Skins into:" block lists every item a skinnable mob's
# skinning loot yields, with a drop percentage, from the real cmangos loot table.
# Baked into three tables in Data/GatherMobs.lua:
#   SkinItems       itemID -> {"English name", quality}          (~90 rows)
#   SkinLootTables  index  -> { {itemID, pct, min, max, quest}, ...}  (dedup, ~670)
#   SkinLoot        npcID  -> table index, for every skinnable mob   (~1350)
# Percentage semantics (cmangos loot_template):
#   groupid 0  -> the row rolls independently at its own chance.
#   groupid >0 -> the group yields exactly ONE item; explicit positive chances are
#                 the odds, and zero-chance rows split whatever those leave to 100.
#   chance < 0 -> quest-only; abs() is the chance, flagged quest.
#   a conditional row (condition_id != 0) is flagged quest too (niche gated drops).
#   min/max (mincountOrRef/maxcount) give the stack range; mincountOrRef < 0 is a
#   reference to reference_loot_template (only a couple of rows use it).
def parse_loot(sql, table):
    """entry -> list of dict(item, ch, gid, mc, mx, cond)."""
    d = {}
    for mm in re.finditer(r"INSERT INTO `%s`[^;]*;" % table, sql, re.S):
        for t in re.finditer(r"\(((?:[^()']|'(?:[^'\\]|\\.|'')*')*)\)", t_body(mm.group(0))):
            f = split_tuple(t.group(1))
            try: d.setdefault(int(f[0]), []).append(
                dict(item=int(f[1]), ch=float(f[2]), gid=int(f[3]), mc=int(f[4]), mx=int(f[5]), cond=int(f[6])))
            except: pass
    return d

def parse_item_meta(sql):
    """itemID -> (name, quality). Quality is the item_template rarity 0..7."""
    meta = {}
    for mm in re.finditer(r"INSERT INTO `item_template`[^;]*;", sql, re.S):
        for t in re.finditer(r"\(((?:[^()']|'(?:[^'\\]|\\.|'')*')*)\)", t_body(mm.group(0))):
            f = split_tuple(t.group(1))
            try: meta[int(f[0])] = (unq(f[4]), int(f[6]))
            except: pass
    return meta

def skin_loot_of(entry, skinloot, refloot):
    """Resolve one template's rows (expanding the rare reference row) into
    (itemID, pct, min, max, quest) tuples, sorted non-quest first then pct desc."""
    return tuple((it, round(pct), mn, mx, q) for it, pct, mn, mx, q in loot_rows(entry, skinloot, refloot))

def loot_rows(entry, skinloot, refloot):
    """skin_loot_of's rows before the percents are rounded."""
    rows = []
    for r in skinloot.get(entry, []):
        if r["mc"] < 0: rows.extend(refloot.get(r["item"], []))   # reference row
        else: rows.append(r)
    groups = {}
    for r in rows: groups.setdefault(r["gid"], []).append(r)
    out = []
    for gid, grp in groups.items():
        if gid == 0:                                     # independent rolls
            for r in grp:
                out.append((r["item"], abs(r["ch"]), r["mc"], r["mx"], r["ch"] < 0 or r["cond"] != 0))
        else:                                            # one-of-group; zeros split the remainder
            expl = [r for r in grp if r["ch"] > 0]
            zero = [r for r in grp if r["ch"] == 0]
            neg  = [r for r in grp if r["ch"] < 0]
            each = max(0.0, 100.0 - sum(r["ch"] for r in expl)) / len(zero) if zero else 0.0
            for r in expl: out.append((r["item"], r["ch"],  r["mc"], r["mx"], r["cond"] != 0))
            for r in zero: out.append((r["item"], each,     r["mc"], r["mx"], r["cond"] != 0))
            for r in neg:  out.append((r["item"], abs(r["ch"]), r["mc"], r["mx"], True))
    out.sort(key=lambda t: (t[4], -t[1]))
    return out

def node_loot_of(entry, nodeloot, refloot):
    """A node's loot, like skin_loot_of, except that a chance under 0.5%
    (a node's gems, 0.7%) shows as 1%, not 0%."""
    return tuple((it, max(1, round(pct)) if pct > 0 else 0, mn, mx, q)
                 for it, pct, mn, mx, q in loot_rows(entry, nodeloot, refloot))

def skin_loot_tables(skin, cre, skinloot, refloot, meta):
    """Return (items, tables, mob_tbl): items = {itemID:(name,quality)} used;
    tables = list of loot-lists (deduped); mob_tbl = npcID -> 1-based table index."""
    tables, index, mob_tbl, used = [], {}, {}, set()
    for e in skin:
        loot = skin_loot_of(cre[e][1], skinloot, refloot)
        if not loot: continue
        idx = index.get(loot)
        if idx is None:
            tables.append(loot); idx = len(tables); index[loot] = idx
        mob_tbl[e] = idx
        for it, *_ in loot: used.add(it)
    items = {it: meta.get(it, ("item:" + str(it), 1)) for it in used}
    return items, tables, mob_tbl


# ---- WoW: Forever: VMaNGOS (Classic NPC IDs) ----
def pick_latest_classic(release):
    """Return (version, download_url) of the SQLite dump in VMaNGOS'
    db_latest release. The version is the commit the dump was built from
    (asset "db-sqlite-<hash>.zip"); the tag itself never changes."""
    for a in release.get("assets", []):
        m = re.match(r"db-sqlite-([0-9a-f]{7,40})\.zip$", a.get("name", ""))
        if m:
            return m.group(1), a.get("browser_download_url")
    die("no db-sqlite-<hash>.zip asset in VMaNGOS' db_latest release "
        "(asset naming may have changed); nothing to compare against")

def latest_classic():
    req = urllib.request.Request(CLASSIC_RELEASE_API, headers={"User-Agent": "pb-gather-db"})
    return pick_latest_classic(json.loads(urllib.request.urlopen(req, timeout=30).read().decode()))

def forever_path(addon_dir):
    return os.path.join(addon_dir, "Data", "Forever", "Gather.lua")

def current_classic_version(addon_dir):
    p = forever_path(addon_dir)
    if not os.path.isfile(p):
        die("no Data/Forever/Gather.lua at " + p)
    m = re.search(r"VMaNGOS db ([0-9a-f]{7,40})", open(p, encoding="utf-8").read())
    return m.group(1) if m else None

def classic_tables(db):
    """Read a VMaNGOS mangos.sqlite at CLASSIC_PATCH. Every table keeps one
    row per patch a record changed in; the newest row at or below the patch
    wins, and a loot row counts when the patch is inside its range.
    Returns (skin, cre, skinloot, meta) in the shapes the TBC path uses."""
    c = sqlite3.connect(db)
    cre = {}
    for e, sl in c.execute("SELECT entry, skinning_loot_id FROM creature_template "
                           "WHERE patch <= ? ORDER BY entry, patch", (CLASSIC_PATCH,)):
        cre[e] = (0, sl)
    skinloot = {}
    for e, it, ch, gid, mc, mx, cond in c.execute(
            "SELECT entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, "
            "condition_id FROM skinning_loot_template WHERE patch_min <= ? AND ? <= patch_max",
            (CLASSIC_PATCH, CLASSIC_PATCH)):
        skinloot.setdefault(e, []).append(
            dict(item=it, ch=float(ch), gid=gid, mc=mc, mx=mx, cond=cond))
    meta = {}
    for it, name, q in c.execute("SELECT entry, name, quality FROM item_template "
                                 "WHERE patch <= ? ORDER BY entry, patch", (CLASSIC_PATCH,)):
        meta[it] = (name, q)
    skin = sorted(e for e, (_, sl) in cre.items() if sl > 0 and sl in skinloot)
    # Nodes (gameobject type 3, a chest: data1 is its loot id). One name
    # has several entries, often with different loot (Copper Vein: three
    # tables); the loot id with the most world spawns speaks for the name.
    gobs = {}
    for e, name, typ, lid in c.execute("SELECT entry, name, type, data1 FROM gameobject_template "
                                       "WHERE patch <= ? ORDER BY entry, patch", (CLASSIC_PATCH,)):
        gobs[e] = (name, typ, lid)
    spawns = {}
    for e, n in c.execute("SELECT id, count(*) FROM gameobject WHERE patch_min <= ? AND ? <= patch_max "
                          "GROUP BY id", (CLASSIC_PATCH, CLASSIC_PATCH)):
        spawns[e] = n
    nodeloot, refloot = {}, {}
    for table, out in (("gameobject_loot_template", nodeloot), ("reference_loot_template", refloot)):
        for e, it, ch, gid, mc, mx, cond in c.execute(
                "SELECT entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition_id "
                "FROM %s WHERE patch_min <= ? AND ? <= patch_max" % table, (CLASSIC_PATCH, CLASSIC_PATCH)):
            out.setdefault(e, []).append(dict(item=it, ch=float(ch), gid=gid, mc=mc, mx=mx, cond=cond))
    c.close()
    return skin, cre, skinloot, meta, (gobs, spawns, nodeloot, refloot)

def node_names(addon_dir):
    """The node names in Data/Forever/Gather.lua's MiningNodes and HerbNodes."""
    txt = open(forever_path(addon_dir), encoding="utf-8").read()
    names = []
    for table in ("MiningNodes", "HerbNodes"):
        m = re.search(r"ProfBuddy\.%s = \{(.*?)\n\}" % table, txt, re.S)
        if not m: die("no %s table in Data/Forever/Gather.lua" % table)
        names += re.findall(r'\["([^"]+)"\]=\d+', m.group(1))
    return names

def node_loot_tables(names, nodes, meta):
    """Return (items, tables, node_tbl, missing): node_tbl = name -> 1-based
    table index, for each name whose most-spawned loot id has rows."""
    gobs, spawns, nodeloot, refloot = nodes
    tables, index, node_tbl, used, missing = [], {}, {}, set(), []
    for name in sorted(names):
        weight = {}
        for e, (n, typ, lid) in gobs.items():
            if n == name and typ == 3 and lid and lid in nodeloot:
                weight[lid] = weight.get(lid, 0) + spawns.get(e, 0)
        if not weight:
            missing.append(name); continue
        lid = max(sorted(weight), key=lambda k: weight[k])
        loot = node_loot_of(lid, nodeloot, refloot)
        if not loot:
            missing.append(name); continue
        idx = index.get(loot)
        if idx is None:
            tables.append(loot); idx = len(tables); index[loot] = idx
        node_tbl[name] = idx
        for it, *_ in loot: used.add(it)
    items = {it: meta.get(it, ("item:" + str(it), 1)) for it in used}
    return items, tables, node_tbl, missing

# NPC faction sides (Data/Forever/NpcFactions.lua). An NPC is a trainer or a
# vendor when its npc_flags hold 0x10 or 0x4 (VMaNGOS, 1.12). Its faction
# template (creature_template.faction) is read in WoW: Forever's own
# FactionTemplate table: EnemyGroup bit 2 = hostile to Alliance players, bit
# 4 = to Horde players; the Enemies_ / Friend_ lists name single factions and
# win over the group masks (the emulators' IsHostileTo rule). Player race
# factions: Alliance 1, 3, 4, 115; Horde 2, 5, 6, 116.
NPC_FLAGS_TRAINER_VENDOR = 0x10 | 0x4
ALLIANCE_RACE_FACTIONS = {1, 3, 4, 115}
HORDE_RACE_FACTIONS = {2, 5, 6, 116}
# npcID -> expected side: Mak (Thunder Bluff), Shandrina (Ashenvale),
# Jutak (Booty Bay), Evie Whirlbrew (Everlook)
NPC_SIDE_ANCHORS = {3008: "H", 3955: "A", 2843: "N", 11188: "N"}

def hostile_to(tpl, group_bit, race_factions):
    enemies = {int(tpl.get("Enemies_%d" % i) or 0) for i in range(8)}
    friends = {int(tpl.get("Friend_%d" % i) or 0) for i in range(8)}
    if enemies & race_factions:
        return True
    if friends & race_factions:
        return False
    return (int(tpl.get("EnemyGroup") or 0) & group_bit) != 0

def npc_sides(db, templates):
    """npcID -> "A" (Alliance only), "H" (Horde only) or "N" (both), for
    every trainer and vendor; an NPC hostile to both sides is left out."""
    c = sqlite3.connect(db)
    npcs = {}
    for e, flags, fac in c.execute("SELECT entry, npc_flags, faction FROM creature_template "
                                   "WHERE patch <= ? ORDER BY entry, patch", (CLASSIC_PATCH,)):
        npcs[e] = (flags, fac)
    c.close()
    sides = {}
    for e, (flags, fac) in npcs.items():
        if not (flags & NPC_FLAGS_TRAINER_VENDOR):
            continue
        tpl = templates.get(fac)
        if tpl is None:
            continue
        ha = hostile_to(tpl, 2, ALLIANCE_RACE_FACTIONS)
        hh = hostile_to(tpl, 4, HORDE_RACE_FACTIONS)
        if ha and hh:
            continue
        sides[e] = "H" if ha else ("A" if hh else "N")
    return sides

def faction_templates(build):
    """WoW: Forever's FactionTemplate rows by ID, from wago.tools."""
    import csv
    url = "https://wago.tools/db2/FactionTemplate/csv?build=%s" % build
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=120).read()
    return {int(r["ID"]): r for r in csv.DictReader(io.StringIO(raw.decode("utf-8")))}

def write_npc_sides(addon_dir, version, build, sides):
    p = os.path.join(addon_dir, "Data", "Forever", "NpcFactions.lua")
    L = ["-" * 70,
         "-- ProfessionBuddy  --  Data/Forever/NpcFactions.lua",
         "-- Which side each trainer and vendor serves, for the Source line's",
         "-- \"Hide opposite-faction trainers and vendors\" (Knowledge.lua):",
         "-- \"A\" Alliance only, \"H\" Horde only, \"N\" both. The NPC's faction from",
         "-- VMaNGOS db %s, read in WoW: Forever's FactionTemplate (build %s)." % (version, build),
         "-- An NPC not listed (new on Forever) goes by the faction PB saw in game.",
         "--",
         "-- GENERATED by tools/gather_db.py --regen --source classic. Do not hand-edit.",
         "-" * 70,
         "ProfBuddy = ProfBuddy or {}",
         "ProfBuddy.NpcSides = {"]
    row = []
    for e in sorted(sides):
        row.append('[%d]="%s",' % (e, sides[e]))
        if len(row) == 10:
            L.append("    " + "".join(row)); row = []
    if row:
        L.append("    " + "".join(row))
    L.append("}")
    open(p, "w", encoding="utf-8").write("\n".join(L) + "\n")

def regen_classic(addon_dir, url, version, write):
    log("downloading VMaNGOS db %s ..." % version)
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "pb"}), timeout=300).read()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import bake_forever_db2
    build = bake_forever_db2.baked_build(os.path.join(addon_dir, "Data", "Forever"))
    if not build: die("no baked Forever build in Data/Forever (run tools/bake_forever_db2.py first)")
    with tempfile.TemporaryDirectory() as tmp:
        zipfile.ZipFile(io.BytesIO(raw)).extract("sqlite-dump/mangos.sqlite", tmp)
        db = os.path.join(tmp, "sqlite-dump", "mangos.sqlite")
        skin, cre, skinloot, meta, nodes = classic_tables(db)
        sides = npc_sides(db, faction_templates(build))
    badside = [(n, exp, sides.get(n)) for n, exp in NPC_SIDE_ANCHORS.items() if sides.get(n) != exp]
    if badside: die("NPC side anchors FAILED: %s" % badside)
    log("  NPC side anchors OK  |  trainers and vendors: %d (A %d, H %d, N %d), Forever build %s"
        % (len(sides), sum(v == "A" for v in sides.values()), sum(v == "H" for v in sides.values()),
           sum(v == "N" for v in sides.values()), build))
    skinset = set(skin)
    bad = [(n, exp) for n, exp in CLASSIC_ANCHORS.items() if (n in skinset) != exp]
    if bad: die("anchor validation FAILED: %s" % bad)
    skinitems, skintables, mob_tbl = skin_loot_tables(skin, cre, skinloot, {}, meta)
    log("  anchors OK  |  skinnable=%d  |  skin-loot: %d loot tables, %d items"
        % (len(skin), len(skintables), len(skinitems)))
    nodeitems, nodetables, node_tbl, missing = node_loot_tables(node_names(addon_dir), nodes, meta)
    for name, item in NODE_ANCHORS.items():
        loot = nodetables[node_tbl[name] - 1] if name in node_tbl else ()
        if item not in [t[0] for t in loot]: die("node anchor FAILED: %s has no %d" % (name, item))
    log("  node anchors OK  |  node-loot: %d nodes over %d loot tables, %d items%s"
        % (len(node_tbl), len(nodetables), len(nodeitems),
           ("  |  no loot: " + ", ".join(missing)) if missing else ""))
    cur = current_ids(addon_dir, forever_path(addon_dir))
    if cur is not None:
        log("  vs current skinnable: +%d added, -%d removed" % (len(skinset - cur), len(cur - skinset)))
    if not write:
        log("  (dry run -- pass --write to regenerate Data/Forever/Gather.lua; nodes are preserved)")
        return
    write_forever_gather(addon_dir, version, skin, skinitems, skintables, mob_tbl,
                         (nodeitems, nodetables, node_tbl))
    write_npc_sides(addon_dir, version, build, sides)
    log("  WROTE Data/Forever/Gather.lua @ VMaNGOS db %s" % version)

GEN_MARK = "-- Generated by tools/gather_db.py --regen --source classic: do not edit"

def write_forever_gather(addon_dir, version, skin, skinitems, skintables, mob_tbl, node=None):
    """Rewrite the generated block (everything from GEN_MARK on) and the
    version stamp; the header and the node tables above it stay."""
    p = forever_path(addon_dir); txt = open(p, encoding="utf-8").read()
    cut = txt.find("\n" + GEN_MARK)
    if cut >= 0: txt = txt[:cut + 1]
    block = "\n".join([
        GEN_MARK,
        "-- below this line by hand.",
        'ProfBuddy.SkinLootSource = "Classic"',
        "",
        ids_block("SkinnableMobs", skin), "",
        loot_block(skinitems, skintables, mob_tbl), ""]
        + ([node_block(*node), ""] if node else []))
    txt = txt.rstrip("\n") + "\n\n" + block
    txt = re.sub(r"VMaNGOS db [0-9a-f]{7,40}", "VMaNGOS db %s" % version, txt)
    open(p, "w", encoding="utf-8").write(txt)

def regen(addon_dir, url, version, write):
    log("downloading cmangos %s ..." % version)
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent":"pb"}), timeout=120).read()
    sql = gzip.decompress(raw).decode("utf-8", "replace")
    ci = col_index(sql, "creature_template", ["Entry","CreatureTypeFlags","SkinningLootId"])
    log("  creature_template cols: %s" % ci)
    # skinning_loot_template: entry -> loot rows (also serves as the "has rows" set)
    skinloot = parse_loot(sql, "skinning_loot_template")
    cre={}
    for mm in re.finditer(r"INSERT INTO `creature_template`[^;]*;", sql, re.S):
        for t in re.finditer(r"\(((?:[^()']|'(?:[^'\\]|\\.|'')*')*)\)", t_body(mm.group(0))):
            f=split_tuple(t.group(1))
            if len(f) <= ci["SkinningLootId"]: continue
            try: cre[int(f[ci["Entry"]])]=(int(f[ci["CreatureTypeFlags"]]), int(f[ci["SkinningLootId"]]))
            except: pass
    hl=lambda sl: sl>0 and sl in skinloot
    skin=sorted(e for e,(fl,sl) in cre.items() if hl(sl) and not(fl&0x100 or fl&0x200 or fl&0x400) and e not in EXCLUDE_SKIN)
    mine=sorted(e for e,(fl,sl) in cre.items() if hl(sl) and (fl&0x200))
    herb=sorted(e for e,(fl,sl) in cre.items() if hl(sl) and (fl&0x100))
    skinset=set(skin)
    # validate anchors
    bad=[(n,exp) for n,exp in ANCHORS.items() if (n in skinset)!=exp]
    if bad: die("anchor validation FAILED: %s" % bad)
    log("  anchors OK  |  skinnable=%d mineable=%d herbable=%d" % (len(skin),len(mine),len(herb)))
    # skinning loot: exact items + drop chance (needs reference loot + item meta)
    refloot  = parse_loot(sql, "reference_loot_template")
    itemmeta = parse_item_meta(sql)
    skinitems, skintables, mob_tbl = skin_loot_tables(skin, cre, skinloot, refloot, itemmeta)
    log("  skin-loot: %d mobs over %d loot tables, %d items" % (len(mob_tbl), len(skintables), len(skinitems)))
    # diff vs current
    cur = current_ids(addon_dir)
    if cur is not None:
        added=sorted(skinset-cur); removed=sorted(cur-skinset)
        log("  vs current skinnable: +%d added, -%d removed" % (len(added),len(removed)))
    if not write:
        log("  (dry run -- pass --write to regenerate Data/GatherMobs.lua; nodes are preserved)")
        return
    # preserve node tables from the current file, rewrite mob sets, restamp
    write_gathermobs(addon_dir, version, skin, mine, herb, skinitems, skintables, mob_tbl)
    log("  WROTE Data/GatherMobs.lua @ cmangos %s" % version)

def t_body(insert):
    return insert.split("VALUES",1)[1] if "VALUES" in insert else ""

def current_ids(addon_dir, p=None):
    p=p or os.path.join(addon_dir,"Data","GatherMobs.lua")
    if not os.path.isfile(p): return None
    txt=open(p,encoding="utf-8").read()
    m=re.search(r"ProfBuddy\.SkinnableMobs = \{(.*?)\n\}", txt, re.S)
    return set(int(x) for x in re.findall(r"\[(\d+)\]=true", m.group(1))) if m else None

def ids_block(name, arr):
    L=[f"ProfBuddy.{name} = {{"]; row=[]
    for e in arr:
        row.append(f"[{e}]=true,")
        if len(row)==12: L.append("    "+"".join(row)); row=[]
    if row: L.append("    "+"".join(row))
    L.append("}"); return "\n".join(L)

def loot_block(skinitems, skintables, mob_tbl):
    """SkinItems, SkinLootTables and SkinLoot, as Lua source."""
    def qesc(s): return s.replace("\\", "\\\\").replace('"', '\\"')
    # SkinItems: itemID -> {"name", quality}
    ib=["ProfBuddy.SkinItems = {"]
    for it in sorted(skinitems):
        nm, q = skinitems[it]
        ib.append('    [%d]={"%s",%d},' % (it, qesc(nm), q))
    ib.append("}")
    # SkinLootTables: index -> { {itemID,pct,min,max[,true]}, ... } (already sorted)
    tb=["ProfBuddy.SkinLootTables = {"]
    for i, loot in enumerate(skintables, 1):
        entries = []
        for it, pct, mn, mx, quest in loot:
            entries.append("{%d,%d,%d,%d%s}" % (it, pct, mn, mx, ",true" if quest else ""))
        tb.append("    [%d]={%s}," % (i, ",".join(entries)))
    tb.append("}")
    # SkinLoot: npcID -> table index
    lb=["ProfBuddy.SkinLoot = {"]; row=[]
    for e in sorted(mob_tbl):
        row.append("[%d]=%d," % (e, mob_tbl[e]))
        if len(row)==12: lb.append("    "+"".join(row)); row=[]
    if row: lb.append("    "+"".join(row))
    lb.append("}")
    return "\n".join(ib) + "\n\n" + "\n".join(tb) + "\n\n" + "\n".join(lb)

def node_block(items, tables, node_tbl):
    """NodeItems, NodeLootTables and NodeLoot (node name -> table index),
    the node twins of the skinning tables, as Lua source."""
    def qesc(s): return s.replace("\\", "\\\\").replace('"', '\\"')
    ib = ["ProfBuddy.NodeItems = {"]
    for it in sorted(items):
        nm, q = items[it]
        ib.append('    [%d]={"%s",%d},' % (it, qesc(nm), q))
    ib.append("}")
    tb = ["ProfBuddy.NodeLootTables = {"]
    for i, loot in enumerate(tables, 1):
        tb.append("    [%d]={%s}," % (i, ",".join("{%d,%d,%d,%d%s}" % (it, pct, mn, mx, ",true" if q else "")
                                                for it, pct, mn, mx, q in loot)))
    tb.append("}")
    lb = ["ProfBuddy.NodeLoot = {"]
    for name in sorted(node_tbl):
        lb.append('    ["%s"]=%d,' % (qesc(name), node_tbl[name]))
    lb.append("}")
    return "\n".join(ib) + "\n\n" + "\n".join(tb) + "\n\n" + "\n".join(lb)

def write_gathermobs(addon_dir, version, skin, mine, herb, skinitems, skintables, mob_tbl):
    p=os.path.join(addon_dir,"Data","GatherMobs.lua"); txt=open(p,encoding="utf-8").read()
    for name,arr in (("SkinnableMobs",skin),("MineableMobs",mine),("HerbableMobs",herb)):
        txt=re.sub(r"ProfBuddy\.%s = \{.*?\n\}" % name, lambda m, r=ids_block(name,arr): r, txt, count=1, flags=re.S)
    block=loot_block(skinitems, skintables, mob_tbl)
    # drop any prior skinning tables (this format or the retired SkinYield ones)
    for name in ("SkinItems","SkinLootTables","SkinLoot","SkinYieldProfiles","SkinYield"):
        txt=re.sub(r"\nProfBuddy\.%s = \{.*?\n\}\n" % name, "\n", txt, count=1, flags=re.S)
    # insert the fresh block after the HerbableMobs table
    txt=re.sub(r"(ProfBuddy\.HerbableMobs = \{.*?\n\})",
               lambda m: m.group(1)+"\n\n"+block, txt, count=1, flags=re.S)
    txt=re.sub(r"TBCDB\s+\d+\.\d+\.\d+", "TBCDB %s" % version, txt)
    open(p,"w",encoding="utf-8").write(txt)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--addon-dir", default=default_addon_dir())
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--regen", action="store_true")
    ap.add_argument("--source", choices=("tbc", "classic"), default="tbc",
                    help="with --regen: tbc = Data/GatherMobs.lua, classic = Data/Forever/Gather.lua")
    ap.add_argument("--write", action="store_true", help="with --regen, actually write the file")
    a=ap.parse_args()
    if a.check or not a.regen:
        # both sources, so a release never ships either client's data stale
        cur, latest = current_version(a.addon_dir), latest_cmangos()[0]
        ccur, clatest = current_classic_version(a.addon_dir), latest_classic()[0]
        log("gather DB (TBC Anniversary): baked=%s  latest cmangos=%s" % (cur, latest))
        log("gather DB (WoW: Forever):    baked=%s  latest VMaNGOS=%s" % (ccur, clatest))
        stale = []
        if cur != latest: stale.append("--source tbc (%s -> %s)" % (cur, latest))
        if ccur != clatest: stale.append("--source classic (%s -> %s)" % (ccur, clatest))
        if not stale:
            log("UP TO DATE -- no gather-data regen needed for release."); sys.exit(0)
        log("NEWER DB available: run --regen %s and re-validate before the CurseForge release."
            % " and --regen ".join(stale)); sys.exit(10)
    if a.source == "classic":
        cur=current_classic_version(a.addon_dir); latest,url=latest_classic()
        log("gather DB (WoW: Forever): baked=%s  latest VMaNGOS=%s" % (cur, latest))
        regen_classic(a.addon_dir, url, latest, a.write)
        return
    cur=current_version(a.addon_dir)
    latest,url=latest_cmangos()
    log("gather DB: baked=%s  latest cmangos=%s" % (cur, latest))
    if cur==latest and not a.write:
        log("already on latest; --regen would be a no-op (use --write to force-rebuild anyway).")
    regen(a.addon_dir, url, latest, a.write)

if __name__=="__main__":
    main()
