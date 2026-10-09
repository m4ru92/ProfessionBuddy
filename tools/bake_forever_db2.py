#!/usr/bin/env python3
"""Bake ProfessionBuddy's WoW: Forever recipe data from Blizzard's DB2 tables.

    python tools/bake_forever_db2.py <csvdir> [--build 1.60.1.70009]

<csvdir> holds the Forever build's DB2 tables as CSV, from wago.tools
(https://wago.tools/db2/<Table>/csv?build=<build>): SkillLineAbility,
SkillLine, SpellName, SpellEffect, SpellReagents, TradeSkillCategory,
ItemSparse, Item, ItemEffect, ItemXItemEffect. `--fetch` downloads them.

Writes ProfessionBuddy/Data/Forever/<Profession>.lua, one file per
profession, in PB's RecipeDB format (keyed by recipe name), and prints a
report. Forever is its own game version: no TBC data is read.

teachItems lists the items that teach a recipe (Pattern, Plans, Recipe
and so on), so PB can tell which recipe a vendor's or a bag's item
teaches (Knowledge.lua).

Data/Forever/Tools.lua lists every other tool a recipe needs (Blacksmith
Hammer, Arclight Spanner, Philosopher's Stone, Flint and Tinder and so on),
from SpellTotems, with the items that satisfy each (tool_tables).

rod names the Enchanting rod a recipe needs, as on TBC Anniversary: a
required totem category (SpellTotems) of type 3 (TotemCategory). The rods
themselves (ProfBuddy.EnchantingRods, written at the end of
Enchanting.lua) are the items carrying those categories (ItemSparse
TotemCategoryID), with the category's cumulative mask.

Data/Forever/RandomStats.lua lists the crafted items that roll random
stats ("<Random additional stats>"): Forever gives them an item bonus tree
(ItemXBonusTree). TBC Anniversary's Data/RandomEnchant.lua is the same
list from cmangos.

  --check   compare the build baked into Data/Forever with the newest
            Forever (1.60.x) build on wago.tools. Run it at release prep.
            Exits 0 = up to date, 10 = a newer build exists (rebake).

Learn level (orange), first match wins:
  1. learned automatically with the profession (SkillLineAbility
     AcquireMethod 1 or 2): the ability's MinSkillLineRank, at least 1.
     This beats a trainer's listing: Basic Campfire comes with Cooking at
     1 though the Cooking trainer lists it at 20 (m4ru had it at Cooking 1)
  2. m4ru's trainer captures (tools/forever/trainer_captures.json)
  3. taught by a recipe item: the lowest RequiredSkillRank of its teaching
     items in Forever's ItemSparse
  4. item recipe missing there: Classic Era's item rank, shifted by how far
     Forever moved the recipe's yellow from Era's
  5. trainer recipe: the cMaNGOS classic trainer level, shifted the same way
     (tools/forever/era_learn_inputs.json; Era data only, no TBC data)
  6. otherwise unknown: skillReq absent, skillRange[1] = false
Yellow and grey come from SkillLineAbility; green = floor((yellow + grey) / 2),
verified against all 2,115 TBCCA recipes.

Rows left out, each counted in the report:
  - a spell that makes no item and takes no reagents: Tanning and
    Gardening open the Skinning and Herbalism windows; they are not
    recipes and the game does not list them
  - no spell name (retired or placeholder, including the 27 Adaptive recipes
    stripped in build 70009)
  - the profession's own rank spells (a row named after the profession)
  - a Season of Discovery ID (400000-499999) whose crafted item is not in
    ItemSparse: 38 of 38 such recipes in m4ru's harvest were unknown to the
    game
  - a recipe whose crafted item the game did not recognise in m4ru's harvest
    (tools/forever/game_unknown_items.json)
  - a second recipe of the same name in the same profession (67 names). PB
    keys recipes by name, so one is kept, in this order: its crafted item is
    in ItemSparse, or for an enchant its teaching item is (56 of the 67
    pairs are decided here); m4ru captured it at
    a trainer; a Forever ID (1,000,000 and up) over a Classic ID over a
    Season of Discovery ID; the lower ID.
"""
import argparse, csv, json, math, os, re, sys, urllib.request
from collections import defaultdict, Counter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, ".."))
INPUTS = os.path.join(HERE, "forever")
OUT_DIR = os.path.join(REPO, "ProfessionBuddy", "Data", "Forever")
TABLES = ["SkillLineAbility", "SkillLine", "SpellName", "SpellEffect", "SpellReagents",
          "SpellTotems", "TotemCategory", "ItemXBonusTree",
          "TradeSkillCategory", "ItemSparse", "Item", "ItemEffect", "ItemXItemEffect"]

# skill lines that are test/prototype content, not shipped professions
EXCLUDE_SKILL_LINES = {2933, 3012}
SOD_IDS = range(400000, 500000)
ROD_TYPE = 3   # TotemCategoryType of the Runed X Rods
csv.field_size_limit(10_000_000)


def I(x):
    try:
        return int(float(x or 0))
    except ValueError:
        return 0


def read(csvdir, name):
    with open(os.path.join(csvdir, name + ".csv"), encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def fetch(csvdir, build):
    os.makedirs(csvdir, exist_ok=True)
    for t in TABLES:
        url = "https://wago.tools/db2/%s/csv?build=%s" % (t, build)
        req = urllib.request.Request(url, headers={"User-Agent": "ProfessionBuddy-bake"})
        with urllib.request.urlopen(req, timeout=120) as r, \
                open(os.path.join(csvdir, t + ".csv"), "wb") as fh:
            fh.write(r.read())
        print("fetched", t)


def load_inputs():
    def j(name):
        with open(os.path.join(INPUTS, name), encoding="utf-8") as fh:
            return json.load(fh)
    era = {int(k): v for k, v in j("era_learn_inputs.json")["spells"].items()}
    caps = {int(k): v for k, v in j("trainer_captures.json")["captures"].items()}
    unknown = set(j("game_unknown_items.json")["recipes"])
    return era, caps, unknown


def teaching_items(csvdir):
    """recipe spell -> set of items that teach it. Moved from the 2026-09-23
    research (classify.py): an item effect with TriggerType 6 (learn) on the
    recipe spell, or an item whose spell teaches it (SpellEffect 36)."""
    learns = defaultdict(set)
    for r in read(csvdir, "SpellEffect"):
        if I(r["Effect"]) == 36:
            learns[I(r["SpellID"])].add(I(r["EffectTriggerSpell"]))
    ie = read(csvdir, "ItemEffect")
    item_of_effect = defaultdict(set)
    if "ParentItemID" in ie[0]:
        for r in ie:
            item_of_effect[I(r["ID"])].add(I(r["ParentItemID"]))
    for r in read(csvdir, "ItemXItemEffect"):
        item_of_effect[I(r["ItemEffectID"])].add(I(r["ItemID"]))
    teach = defaultdict(set)
    for r in ie:
        sid = I(r["SpellID"])
        for it in item_of_effect.get(I(r["ID"]), ()):
            if I(r["TriggerType"]) == 6:
                teach[sid].add(it)
            for t in learns.get(sid, ()):
                teach[t].add(it)
    return teach


def build(csvdir):
    era, caps, game_unknown = load_inputs()
    names = {I(r["ID"]): r["Name_lang"] for r in read(csvdir, "SpellName")}
    skill = {I(r["ID"]): (r["DisplayName_lang"] or r["NeutralDisplayName"])
             for r in read(csvdir, "SkillLine")}
    cats = {I(r["ID"]): r["Name_lang"] for r in read(csvdir, "TradeSkillCategory")}
    items = {}
    for r in read(csvdir, "ItemSparse"):
        items[I(r["ID"])] = (r.get("Display_lang") or "", I(r["RequiredSkillRank"]))
    teach = teaching_items(csvdir)

    reagents = defaultdict(list)
    rrows = read(csvdir, "SpellReagents")
    ritem = sorted(c for c in rrows[0] if c.startswith("Reagent_"))
    rcnt = sorted(c for c in rrows[0] if c.startswith("ReagentCount_"))
    for r in rrows:
        for ic, cc in zip(ritem, rcnt):
            iid, n = I(r[ic]), I(r[cc])
            if iid > 0 and n > 0:
                reagents[I(r["SpellID"])].append((iid, n))

    # Enchanting rods: totem categories of type 3, cumulative masks
    totem = {I(r["ID"]): (r["Name_lang"], I(r["TotemCategoryType"]), I(r["TotemCategoryMask"]))
             for r in read(csvdir, "TotemCategory")}
    rod_of = {}
    for r in read(csvdir, "SpellTotems"):
        for col in ("RequiredTotemCategoryID_0", "RequiredTotemCategoryID_1"):
            t = totem.get(I(r.get(col)))
            if t and t[1] == ROD_TYPE:
                rod_of[I(r["SpellID"])] = t[0]
    rods = []
    for r in read(csvdir, "ItemSparse"):
        t = totem.get(I(r.get("TotemCategoryID")))
        if t and t[1] == ROD_TYPE:
            rods.append((t[2], t[0], I(r["ID"])))
    rods.sort()
    bonus_items = {I(r["ItemID"]) for r in read(csvdir, "ItemXBonusTree")}

    created = {}
    for r in read(csvdir, "SpellEffect"):
        if I(r["Effect"]) == 24 and I(r.get("EffectItemType")):
            created[I(r["SpellID"])] = (I(r["EffectItemType"]), max(I(r.get("EffectBasePointsF")), 1))

    report = Counter()
    per_line = defaultdict(list)
    seen = set()
    for r in read(csvdir, "SkillLineAbility"):
        spell, line, cat = I(r["Spell"]), I(r["SkillLine"]), I(r["TradeSkillCategoryID"])
        if not cat or line in EXCLUDE_SKILL_LINES or (line, spell) in seen:
            continue
        seen.add((line, spell))
        name = names.get(spell)
        prof = skill.get(line) or "SkillLine%d" % line
        out = created.get(spell)
        if not name:
            report["dropped: no spell name"] += 1
            continue
        if name == prof:
            report["dropped: profession rank spell"] += 1
            continue
        if spell in SOD_IDS and out and out[0] not in items:
            report["dropped: Season of Discovery ID, crafted item not in ItemSparse"] += 1
            continue
        if spell in game_unknown:
            report["dropped: crafted item unknown to the game (harvest)"] += 1
            continue
        if not out and not reagents.get(spell):
            # Tanning (Skinning) and Gardening (Herbalism): the spells that
            # open the profession window, not recipes; the game does not
            # list them, so PB would show them as never learned
            report["dropped: no item and no reagents (opens a profession window)"] += 1
            continue

        yellow, grey = I(r["TrivialSkillLineRankLow"]), I(r["TrivialSkillLineRankHigh"])
        acquire = I(r["AcquireMethod"])
        tinv = sorted(teach.get(spell, ()))
        e = era.get(spell, {})
        cap = caps.get(spell)

        learn, learn_from = None, None
        if acquire in (1, 2):
            learn, learn_from = max(I(r["MinSkillLineRank"]), 1), "automatic"
        elif cap:
            learn, learn_from = cap["rank"], "trainer capture"
        elif tinv:
            ranks = [items[i][1] for i in tinv if i in items and items[i][1] > 0]
            if ranks:
                learn, learn_from = min(ranks), "recipe item"
            elif "eraItemRank" in e and "eraYellow" in e and yellow:
                learn, learn_from = e["eraItemRank"] + (yellow - e["eraYellow"]), "Era item, shifted"
        elif "eraTrainer" in e and "eraYellow" in e and yellow:
            learn, learn_from = e["eraTrainer"] + (yellow - e["eraYellow"]), "Era trainer, shifted"
        if learn is not None and learn_from.startswith("Era"):
            # A shifted value outside 1..yellow is not trustworthy.
            if learn < 1 or (yellow and learn > yellow):
                report["learn level: Era shift out of range, left unknown"] += 1
                learn, learn_from = None, None
        report["learn level: " + (learn_from or "unknown")] += 1

        if acquire in (1, 2):
            sources = [{"method": "automatic"}]
        elif cap or not tinv:
            sources = [{"method": "trainer"}]
        else:
            nm = next((items[i][0] for i in tinv if i in items and items[i][0]), None)
            sources = [{"method": "undetermined", "detail": nm}] if nm else [{"method": "undetermined"}]

        per_line[prof].append({
            "spell": spell, "name": name,
            "itemID": out[0] if out else 0,
            "itemKnown": bool(out and out[0] in items),
            "teachKnown": any(i in items for i in tinv),
            "teachItems": tinv,
            "yield": out[1] if out else 1,
            "skillReq": learn,
            "learnFrom": learn_from,
            "skillRange": [learn if learn is not None else False, yellow,
                           math.floor((yellow + grey) / 2), grey] if grey else None,
            "category": cats.get(cat),
            "sources": sources,
            "captured": bool(cap),
            "rod": rod_of.get(spell),
            "reagents": [(iid, n, items.get(iid, ("", 0))[0]) for iid, n in reagents.get(spell, [])],
        })

    def keep_order(rec):
        s = rec["spell"]
        band = 0 if s >= 1000000 else (2 if s in SOD_IDS else 1)
        known = rec["itemKnown"] if rec["itemID"] else rec["teachKnown"]
        return (not known, not rec["captured"], band, s)

    final = {}
    for prof, recs in per_line.items():
        by_name = defaultdict(list)
        for rec in recs:
            by_name[rec["name"]].append(rec)
        kept = []
        for name, group in by_name.items():
            group.sort(key=keep_order)
            kept.append(group[0])
            report["dropped: second recipe of the same name"] += len(group) - 1
        final[prof] = sorted(kept, key=lambda x: x["name"])
    random = sorted({(rec["itemID"], rec["name"]) for recs in final.values() for rec in recs
                     if rec["itemID"] in bonus_items})
    for recs in final.values():
        report["tool: an Enchanting rod"] += sum(1 for rec in recs if rec["rod"])
    report["random stats: crafted items with an item bonus tree"] = len(random)
    return final, report, rods, random


def tool_tables(csvdir, spells):
    """Every tool the recipes in `spells` require, other than Enchanting
    rods (those are the recipe's `rod` field). Returns (recipe_tools, cats,
    item_names):
      recipe_tools  spell -> [ category ID, or -item ID for one specific item ]
      cats          category ID -> { name, items = [ item IDs that satisfy it ] }
      item_names    item ID -> name, for the specific items
    An item satisfies a required category when its own category has the same
    type and covers every bit of the required mask: Alchemist's Stones count
    as a Philosopher's Stone, a Gnomish Army Knife as a hammer or a spanner.
    Shared with tools/bake_tbc_tools.py."""
    totem = {I(r["ID"]): (r["Name_lang"], I(r["TotemCategoryType"]), I(r["TotemCategoryMask"]))
             for r in read(csvdir, "TotemCategory")}
    names, carriers = {}, []
    for r in read(csvdir, "ItemSparse"):
        names[I(r["ID"])] = r.get("Display_lang") or ""
        t = totem.get(I(r.get("TotemCategoryID")))
        if t:
            carriers.append((I(r["ID"]), t[1], t[2]))
    recipe_tools, used_cats, used_items = {}, set(), set()
    for r in read(csvdir, "SpellTotems"):
        spell = I(r["SpellID"])
        if spell not in spells:
            continue
        need = []
        for col in ("RequiredTotemCategoryID_0", "RequiredTotemCategoryID_1"):
            cid = I(r.get(col))
            if cid and cid in totem and totem[cid][1] != ROD_TYPE and cid not in need:
                need.append(cid); used_cats.add(cid)
        for col in ("Totem_0", "Totem_1"):
            iid = I(r.get(col))
            if iid and -iid not in need:
                need.append(-iid); used_items.add(iid)
        if need:
            recipe_tools[spell] = need
    cats = {}
    for cid in used_cats:
        name, typ, mask = totem[cid]
        ok = sorted(i for i, t, m in carriers if t == typ and (m & mask) == mask)
        cats[cid] = {"name": name, "items": ok}
    return recipe_tools, cats, {i: names.get(i) or ("item:%d" % i) for i in used_items}


def emit_tools(recipe_tools, cats, item_names, build_id, path_label, source):
    """Lua source for a Tools.lua file."""
    L = ["-" * 70,
         "-- ProfessionBuddy  --  %s" % path_label,
         "-- Tools a recipe requires, other than Enchanting rods (the recipe's",
         "-- `rod` field). From %s," % source,
         "-- build %s." % build_id,
         "--   RecipeTools[spellID]  = { category ID, or -item ID for one item }",
         "--   ToolCategories[ID]    = { name, items = { items that satisfy it } }",
         "--   ToolItemNames[itemID] = name of a specific required item",
         "--",
         "-- GENERATED. Do not hand-edit.",
         "-" * 70,
         "ProfBuddy = ProfBuddy or {}",
         "ProfBuddy.ToolCategories = {"]
    for cid in sorted(cats):
        c = cats[cid]
        L.append("    [%d] = { name = %s, items = { %s } }," % (
            cid, lua_str(c["name"]), ", ".join(str(i) for i in c["items"])))
    L += ["}", "ProfBuddy.ToolItemNames = {"]
    for iid in sorted(item_names):
        L.append("    [%d] = %s," % (iid, lua_str(item_names[iid])))
    L += ["}", "ProfBuddy.RecipeTools = {"]
    for spell in sorted(recipe_tools):
        L.append("    [%d] = { %s }," % (spell, ", ".join(str(x) for x in recipe_tools[spell])))
    L.append("}")
    return "\n".join(L) + "\n"


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(prof, recs, build_id, rods=()):
    L = ["-" * 70,
         "-- ProfessionBuddy  --  Data/Forever/%s.lua" % prof.replace(" ", ""),
         "-- %s recipe data for WoW: Forever, build %s." % (prof, build_id),
         "--",
         "-- GENERATED by tools/bake_forever_db2.py. Do not hand-edit.",
         "-- Keyed by recipe name, like the TBC data. skillRange[1] is false",
         "-- where the learn level is not known yet. learnFrom says where each",
         "-- learn level came from.",
         "-" * 70, "",
         "local recipes = {"]
    for r in recs:
        L.append("    [%s] = {" % lua_str(r["name"]))
        L.append("        spellID    = %d," % r["spell"])
        L.append("        itemID     = %d," % r["itemID"])
        if r["yield"] > 1:
            L.append("        yield      = %d," % r["yield"])
        if r["skillReq"] is not None:
            L.append("        skillReq   = %d," % r["skillReq"])
            L.append("        learnFrom  = %s," % lua_str(r["learnFrom"]))
        if r["skillRange"]:
            sr = r["skillRange"]
            L.append("        skillRange = { %s, %d, %d, %d }," % (
                "false" if sr[0] is False else str(sr[0]), sr[1], sr[2], sr[3]))
        if r["category"]:
            L.append("        category   = %s," % lua_str(r["category"]))
        if r["teachItems"]:
            L.append("        teachItems = { %s }," % ", ".join(str(i) for i in r["teachItems"]))
        if r.get("rod"):
            L.append("        rod        = %s," % lua_str(r["rod"]))
        src = []
        for s in r["sources"]:
            parts = ['method = %s' % lua_str(s["method"]), 'faction = "Both"']
            if s.get("detail"):
                parts.append("detail = %s" % lua_str(s["detail"]))
            src.append("{ " + ", ".join(parts) + " }")
        L.append("        sources    = { %s }," % ", ".join(src))
        if r["reagents"]:
            L.append("        reagents   = {")
            for iid, n, nm in r["reagents"]:
                L.append("            { itemID = %d, count = %d, name = %s }," % (iid, n, lua_str(nm or ("item:%d" % iid))))
            L.append("        },")
        L.append("    },")
    L += ["}", ""]
    if prof == "Enchanting" and rods:
        L += ["-- Enchanting rods (the `rod` field above), from the items carrying a",
              "-- rod totem category. mask is CUMULATIVE: a rod satisfies a",
              "-- requirement when rod.mask >= the required rod's mask.",
              "ProfBuddy.EnchantingRods = {",
              "    list = {"]
        for mask, name, item in rods:
            L.append("        { name = %s, itemID = %d, mask = %d }," % (lua_str(name), item, mask))
        L += ["    },", "    byName = {},", "}",
              "for _, r in ipairs(ProfBuddy.EnchantingRods.list) do",
              "    ProfBuddy.EnchantingRods.byName[r.name] = r",
              "end", ""]
    L += ["ProfBuddy.RecipeDB:RegisterProfession(%s, recipes)" % lua_str(prof)]
    return "\n".join(L) + "\n"


def emit_random(random, build_id):
    L = ["-" * 70,
         "-- ProfessionBuddy  --  Data/Forever/RandomStats.lua",
         "-- Crafted items that roll random stats on WoW: Forever, build %s." % build_id,
         "-- The game shows \"<Random additional stats>\" (ITEM_RANDOM_ENCHANT) only",
         "-- on the trade-skill result, so PB appends it for these items, as it",
         "-- does on TBC Anniversary (Data/RandomEnchant.lua). An item rolls",
         "-- random stats when Forever gives it an item bonus tree (ItemXBonusTree).",
         "--",
         "-- GENERATED by tools/bake_forever_db2.py. Do not hand-edit.",
         "-" * 70,
         "ProfBuddy = ProfBuddy or {}",
         "ProfBuddy.RandomEnchantItems = {"]
    for item, name in random:
        L.append("    [%d] = true, -- %s" % (item, name))
    L.append("}")
    return "\n".join(L) + "\n"


def baked_build(out_dir=OUT_DIR):
    """The build the Data/Forever files say they were baked from."""
    path = os.path.join(out_dir, "Alchemy.lua")
    if not os.path.isfile(path):
        return None
    for line in open(path, encoding="utf-8"):
        m = re.search(r"build (\d+\.\d+\.\d+\.\d+)", line)
        if m:
            return m.group(1)
    return None


def pick_latest_forever(builds):
    """The newest Forever build (version 1.60 or later in the 1.x line)
    in a wago.tools /api/builds payload, whatever product carries it."""
    best = None
    for rows in builds.values():
        for b in rows or []:
            v = str(b.get("version", ""))
            parts = v.split(".")
            if len(parts) == 4 and parts[0] == "1" and parts[1].isdigit() and int(parts[1]) >= 60:
                key = tuple(int(x) for x in parts)
                if best is None or key > best[0]:
                    best = (key, v)
    return best and best[1]


def check():
    req = urllib.request.Request("https://wago.tools/api/builds", headers={"User-Agent": "ProfessionBuddy-bake"})
    latest = pick_latest_forever(json.loads(urllib.request.urlopen(req, timeout=60).read().decode()))
    baked = baked_build()
    print("Forever recipe data: baked=%s  latest build=%s" % (baked, latest))
    if not latest:
        print("ERROR: no Forever build found on wago.tools", file=sys.stderr)
        sys.exit(1)
    if baked == latest:
        print("UP TO DATE -- no Forever rebake needed for release.")
        sys.exit(0)
    print("NEWER Forever build available (%s -> %s). Rebake with --fetch --build %s, "
          "diff, and re-validate before the CurseForge release." % (baked, latest, latest))
    sys.exit(10)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("csvdir", nargs="?")
    ap.add_argument("--build", default="1.60.1.70009")
    ap.add_argument("--fetch", action="store_true", help="download the tables into csvdir first")
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--check", action="store_true", help="is the baked build the newest? (release prep)")
    a = ap.parse_args()
    if a.check:
        check()
    if not a.csvdir:
        ap.error("csvdir is required unless --check")
    if a.fetch:
        fetch(a.csvdir, a.build)
    final, report, rods, random = build(a.csvdir)
    os.makedirs(a.out, exist_ok=True)
    files, total = [], 0
    for prof in sorted(final):
        fn = prof.replace(" ", "") + ".lua"
        with open(os.path.join(a.out, fn), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(emit(prof, final[prof], a.build, rods))
        files.append(fn)
        total += len(final[prof])
        print("%-16s %4d recipes" % (prof, len(final[prof])))
    with open(os.path.join(a.out, "RandomStats.lua"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(emit_random(random, a.build))
    print("RandomStats.lua  %4d items" % len(random))
    spells = {rec["spell"] for recs in final.values() for rec in recs}
    rt, cats, inames = tool_tables(a.csvdir, spells)
    with open(os.path.join(a.out, "Tools.lua"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(emit_tools(rt, cats, inames, a.build, "Data/Forever/Tools.lua",
                            "WoW: Forever's SpellTotems, TotemCategory and ItemSparse"))
    print("Tools.lua        %4d recipes need a tool" % len(rt))
    print("\n%d recipes in %d files -> %s" % (total, len(files), a.out))
    for k in sorted(report):
        print("  %-66s %5d" % (k, report[k]))


if __name__ == "__main__":
    main()
