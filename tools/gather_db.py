#!/usr/bin/env python3
"""ProfessionBuddy gather-data DB tool.

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

Usage:
  python tools/gather_db.py --check [--addon-dir <path>]
  python tools/gather_db.py --regen [--addon-dir <path>] [--write]
"""
import argparse, json, os, re, sys, subprocess, urllib.request, io, gzip

CMANGOS_API = "https://api.github.com/repos/cmangos/tbc-db/contents/Full_DB"
EXCLUDE_SKIN = {7395}  # hand-verified cmangos false-positives (Cockroach)
# known-good validation anchors: npcID -> expected skinnable (True/False)
ANCHORS = {1548: True, 18205: True, 721: True, 4075: False, 2565: False, 7395: False}

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
    return tuple((it, round(pct), mn, mx, q) for it, pct, mn, mx, q in out)

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

def current_ids(addon_dir):
    p=os.path.join(addon_dir,"Data","GatherMobs.lua")
    if not os.path.isfile(p): return None
    txt=open(p,encoding="utf-8").read()
    m=re.search(r"ProfBuddy\.SkinnableMobs = \{(.*?)\n\}", txt, re.S)
    return set(int(x) for x in re.findall(r"\[(\d+)\]=true", m.group(1))) if m else None

def write_gathermobs(addon_dir, version, skin, mine, herb, skinitems, skintables, mob_tbl):
    p=os.path.join(addon_dir,"Data","GatherMobs.lua"); txt=open(p,encoding="utf-8").read()
    def ids(name,arr):
        L=[f"ProfBuddy.{name} = {{"]; row=[]
        for e in arr:
            row.append(f"[{e}]=true,")
            if len(row)==12: L.append("    "+"".join(row)); row=[]
        if row: L.append("    "+"".join(row))
        L.append("}"); return "\n".join(L)
    for name,arr in (("SkinnableMobs",skin),("MineableMobs",mine),("HerbableMobs",herb)):
        txt=re.sub(r"ProfBuddy\.%s = \{.*?\n\}" % name, lambda m, r=ids(name,arr): r, txt, count=1, flags=re.S)
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
    block="\n".join(ib) + "\n\n" + "\n".join(tb) + "\n\n" + "\n".join(lb)
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
    ap.add_argument("--write", action="store_true", help="with --regen, actually write the file")
    a=ap.parse_args()
    cur=current_version(a.addon_dir)
    latest,url=latest_cmangos()
    log("gather DB: baked=%s  latest cmangos=%s" % (cur, latest))
    if a.check or not a.regen:
        if cur==latest:
            log("UP TO DATE -- no gather-data regen needed for release."); sys.exit(0)
        else:
            log("NEWER cmangos DB available (%s -> %s). Run --regen and re-validate before the CurseForge release." % (cur, latest)); sys.exit(10)
    if a.regen:
        if cur==latest and not a.write:
            log("already on latest; --regen would be a no-op (use --write to force-rebuild anyway).")
        regen(a.addon_dir, url, latest, a.write)

if __name__=="__main__":
    main()
