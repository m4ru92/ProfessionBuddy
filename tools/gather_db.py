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

def latest_cmangos():
    """Return (version, download_url) of the current Full_DB .sql.gz."""
    req = urllib.request.Request(CMANGOS_API, headers={"User-Agent": "pb-gather-db"})
    data = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
    for f in data:
        n = f.get("name", "")
        if n.endswith(".sql.gz"):
            m = re.search(r"TBCDB[_-](\d+\.\d+\.\d+)", n)
            return (m.group(1) if m else n), f.get("download_url")
    die("no .sql.gz found in cmangos Full_DB")

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

def regen(addon_dir, url, version, write):
    log("downloading cmangos %s ..." % version)
    raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent":"pb"}), timeout=120).read()
    sql = gzip.decompress(raw).decode("utf-8", "replace")
    ci = col_index(sql, "creature_template", ["Entry","CreatureTypeFlags","SkinningLootId"])
    log("  creature_template cols: %s" % ci)
    # skinning_loot_template: which loot ids actually have rows
    skinloot = set()
    for mm in re.finditer(r"INSERT INTO `skinning_loot_template`[^;]*;", sql, re.S):
        for t in re.finditer(r"\(((?:[^()']|'(?:[^'\\]|\\.|'')*')*)\)", t_body(mm.group(0))):
            try: skinloot.add(int(split_tuple(t.group(1))[0]))
            except: pass
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
    # diff vs current
    cur = current_ids(addon_dir)
    if cur is not None:
        added=sorted(skinset-cur); removed=sorted(cur-skinset)
        log("  vs current skinnable: +%d added, -%d removed" % (len(added),len(removed)))
    if not write:
        log("  (dry run -- pass --write to regenerate Data/GatherMobs.lua; nodes are preserved)")
        return
    # preserve node tables from the current file, rewrite mob sets, restamp
    write_gathermobs(addon_dir, version, skin, mine, herb)
    log("  WROTE Data/GatherMobs.lua @ cmangos %s" % version)

def t_body(insert):
    return insert.split("VALUES",1)[1] if "VALUES" in insert else ""

def current_ids(addon_dir):
    p=os.path.join(addon_dir,"Data","GatherMobs.lua")
    if not os.path.isfile(p): return None
    txt=open(p,encoding="utf-8").read()
    m=re.search(r"ProfBuddy\.SkinnableMobs = \{(.*?)\n\}", txt, re.S)
    return set(int(x) for x in re.findall(r"\[(\d+)\]=true", m.group(1))) if m else None

def write_gathermobs(addon_dir, version, skin, mine, herb):
    p=os.path.join(addon_dir,"Data","GatherMobs.lua"); txt=open(p,encoding="utf-8").read()
    def ids(name,arr):
        L=[f"ProfBuddy.{name} = {{"]; row=[]
        for e in arr:
            row.append(f"[{e}]=true,")
            if len(row)==12: L.append("    "+"".join(row)); row=[]
        if row: L.append("    "+"".join(row))
        L.append("}"); return "\n".join(L)
    for name,arr in (("SkinnableMobs",skin),("MineableMobs",mine),("HerbableMobs",herb)):
        txt=re.sub(r"ProfBuddy\.%s = \{.*?\n\}" % name, ids(name,arr), txt, count=1, flags=re.S)
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
