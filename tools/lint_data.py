#!/usr/bin/env python3
"""ProfessionBuddy static recipe-DB linter.

Loads every ProfessionBuddy/Data/*.lua through a real Lua interpreter (lupa)
with a stub ProfBuddy.RecipeDB that captures RegisterProfession(prof, recipes),
then applies the schema/consistency checks that RecipeDB.lua + its consumers
(MaterialCalc, TradeSkillFrame, Scanner) actually depend on.

Duplicate table keys cannot be seen after Lua has built the table (the later
literal silently wins), so duplicate recipe keys are found with a separate
text pass over the source at the top-level indent.

Run it from anywhere; --addon-dir defaults to the ProfessionBuddy folder next
to this script's parent, so `python tools/lint_data.py` works from the repo root.

Usage:
  python tools/lint_data.py
  python tools/lint_data.py --addon-dir "<repo>/ProfessionBuddy"

Exit status: 0 when nothing blocking was flagged, 1 when any blocking (P0/P1
class) row was. Sections marked [informational] never fail the run: the id-band
report, the presence anchors, the skillReq-vs-skillRange[1] list, the
cross-profession name and item collisions (RecipeDB keeps every producer), and
the Source-filter reachability note.
"""
import argparse, os, re, sys
from collections import defaultdict, Counter

from lupa import LuaRuntime

# ---------------------------------------------------------------- schema facts
# RecipeDB.lua header comment + TradeSkillFrame.lua SOURCE_COLORS (line 46-56)
VALID_METHODS = {"trainer", "vendor", "drop", "quest", "reputation",
                 "discovery", "automatic", "undetermined"}
# RecipeDB.lua header comment + TradeSkillFrame VisibleSources (line 79-93)
VALID_FACTIONS = {"Alliance", "Horde", "Both"}
# TradeSkillFrame srcMap (line 4835) - the Source filter dropdown. A method
# valid in SOURCE_COLORS but absent here is unreachable by the filter.
FILTERABLE_METHODS = {"trainer", "vendor", "drop", "quest", "reputation",
                      "discovery", "automatic"}

# Fields every crafting recipe record is expected to carry. Derived from what
# the consumers read, not from the (incomplete) header comment:
#   spellID    Scanner.lua:91-95 (locale-stable known-recipe matching)
#   itemID     RecipeDB:RegisterProfession -> itemToRecipe (craftable lookup)
#   skillReq   TradeSkillFrame GetSkillReq / StaticSkillReq
#   sources    TradeSkillFrame RecipeSources / VisibleSources
#   skillRange TradeSkillFrame DiffFromSkillRange / SkillRange*
#   category   TradeSkillFrame category filter + Category sort
#   reagents   MaterialCalc:ResolveTree + RecipeDB reagentUsedIn
REQUIRED_FIELDS = ["spellID", "itemID", "skillReq", "sources",
                   "skillRange", "category", "reagents"]
KNOWN_FIELDS = set(REQUIRED_FIELDS) | {
    "subcategory", "yield", "rod", "source", "sourceDetail", "name", "note",
}

# Files in Data/ that are not recipe registrations.
NON_RECIPE_FILES = {"GatherMobs.lua", "RandomEnchant.lua"}

PLACEHOLDER_RE = re.compile(r"^\s*$|todo|tbd|placeholder|^unknown$|\bxxx\b|fixme",
                            re.IGNORECASE)

# Internal build-pipeline jargon that must never reach the recipe detail panel.
# TradeSkillFrame.lua:2604-2612 prints `detail` verbatim after the method name.
JARGON_RE = re.compile(r"cmangos|DB2|AcquireMethod|auto-confirmed|list gap|"
                       r"MinSkillLineRank|SkillLineAbility|beta only|"
                       r"unconfirmed|unverified|BS plan", re.IGNORECASE)

# ID bands for the 2.5.x client. Anything above these is a retail-era id and is
# either a TBC-Classic-only re-add or contamination -- reported for manual
# GetItemInfo verification, never asserted as a defect.
TBC_MAX_ITEMID = 40000
TBC_MAX_SPELLID = 60000

# Expected per-profession recipe totals for TBC 2.5.x.
# INTENTIONALLY EMPTY. There is no offline source in this tree to check against
# and no authoritative published per-profession recipe count for the 2.5.x
# client that this linter can verify, so the linter reports the ACTUAL counts
# and the skill-band distribution and does not compare against guessed totals.
# Supply real numbers here (with the source) to turn the gap report on.
EXPECTED_TOTALS = {}   # profName -> (count, "source")

# Presence anchors: recipe names that must exist if a profession's TBC tier is
# complete. Source: reviewer knowledge of TBC 2.5.x trade skills, used ONLY to
# surface suspicious absences for manual verification -- a miss here is a
# "check this", not an asserted defect.
ANCHORS = {
    "Alchemy":        ["Super Mana Potion", "Flask of Relentless Assault",
                       "Transmute: Primal Might", "Elixir of Major Agility"],
    "Blacksmithing":  ["Felsteel Longblade", "Khorium Belt", "Fel Iron Plate Gloves",
                       "Adamantite Rod"],
    "Cooking":        ["Spicy Hot Talbuk", "Golden Fish Sticks", "Warp Burger"],
    "Enchanting":     ["Enchant Weapon - Mongoose", "Enchant Gloves - Major Strength",
                       "Enchant Cloak - Greater Agility"],
    "Engineering":    ["Field Repair Bot 110G", "Adamantite Rifle", "Fel Iron Bomb"],
    "First Aid":      ["Netherweave Bandage", "Heavy Netherweave Bandage"],
    "Jewelcrafting":  ["Delicate Blood Garnet", "Bold Living Ruby",
                       "Runed Living Ruby", "Brilliant Glass"],
    "Leatherworking": ["Drums of Battle", "Felscale Breastplate", "Knothide Armor Kit"],
    "Smelting":       ["Smelt Fel Iron", "Smelt Adamantite", "Smelt Hardened Adamantite",
                       "Smelt Khorium", "Smelt Eternium"],
    "Tailoring":      ["Primal Mooncloth", "Bolt of Netherweave", "Spellcloth",
                       "Imbued Netherweave Bag"],
}


# ------------------------------------------------------------------- lua load
def lua_to_py(v):
    """Recursively convert a lupa table to a python dict/list."""
    if type(v).__name__ != "_LuaTable":
        return v
    keys = list(v.keys())
    is_array = keys and all(isinstance(k, int) for k in keys) and \
        sorted(keys) == list(range(1, len(keys) + 1))
    if is_array:
        return [lua_to_py(v[k]) for k in sorted(keys)]
    return {k: lua_to_py(v[k]) for k in keys}


def load_data(data_dir):
    """Return {profName: {recipeName: record}} plus the file each prof came from."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("ProfBuddy = { RecipeDB = { _captured = {} } }\n"
                "function ProfBuddy.RecipeDB:RegisterProfession(p, r)\n"
                "  self._captured[p] = r\nend\n")
    origin = {}
    files = sorted(f for f in os.listdir(data_dir) if f.endswith(".lua"))
    for fn in files:
        path = os.path.join(data_dir, fn)
        src = open(path, encoding="utf-8").read()
        before = set(lua.eval("ProfBuddy.RecipeDB._captured").keys())
        try:
            lua.execute(src)
        except Exception as e:                                   # noqa: BLE001
            print("LOAD FAIL %s: %s" % (fn, e))
            continue
        after = set(lua.eval("ProfBuddy.RecipeDB._captured").keys())
        for p in after - before:
            origin[p] = fn
    caps = lua.eval("ProfBuddy.RecipeDB._captured")
    data = {p: lua_to_py(caps[p]) for p in caps.keys()}
    return data, origin, files


# ------------------------------------------------- duplicate keys (text pass)
TOP_KEY_RE = re.compile(r'^    \["([^"]*)"\]\s*=\s*\{')


def dup_keys(path):
    seen, dups = Counter(), []
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        m = TOP_KEY_RE.match(line.rstrip("\n"))
        if m:
            k = m.group(1)
            seen[k] += 1
            if seen[k] > 1:
                dups.append((k, i, seen[k]))
    return dups, seen


# ------------------------------------------------------------------- checking
class Report:
    def __init__(self):
        self.sections = []

    def add(self, title, rows, note=None, fatal=True):
        """fatal=True marks a P0/P1-class check: any row fails the run."""
        self.sections.append((title, rows, note, fatal))

    def dump(self):
        """Print every section. Return the number of blocking rows."""
        total = blocking = 0
        worst = []
        for title, rows, note, fatal in self.sections:
            tag = "" if fatal else "   [informational]"
            print("\n== %s: %d ==%s" % (title, len(rows), tag))
            if note:
                print("   (%s)" % note)
            for r in rows:
                print("   " + r)
            total += len(rows)
            if fatal and rows:
                blocking += len(rows)
                worst.append("%s (%d)" % (title, len(rows)))
        print("\n== TOTAL FLAGGED ROWS: %d   blocking: %d   informational: %d =="
              % (total, blocking, total - blocking))
        if blocking:
            print("LINT FAIL: " + "; ".join(worst))
        else:
            print("LINT OK: no blocking rows")
        return blocking


def isint(x):
    return isinstance(x, int) or (isinstance(x, float) and float(x).is_integer())


def default_addon_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "ProfessionBuddy"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--addon-dir", default=default_addon_dir())
    a = ap.parse_args()
    if not os.path.isdir(os.path.join(a.addon_dir, "Data")):
        print("ERROR: no Data/ under " + a.addon_dir, file=sys.stderr)
        sys.exit(2)
    data_dir = os.path.join(a.addon_dir, "Data")
    data, origin, files = load_data(data_dir)
    rep = Report()

    print("Data/ files: %d  (%s)" % (len(files), ", ".join(files)))
    print("Professions registered: %d" % len(data))
    for p in sorted(data):
        print("   %-16s %5d recipes   (%s)" % (p, len(data[p]), origin.get(p, "?")))
    print("Files with no RegisterProfession: %s" %
          ", ".join(sorted(set(files) - set(origin.values()))))

    # ---------------------------------------------------- 1. duplicate keys
    rows = []
    for fn in files:
        if fn in NON_RECIPE_FILES:
            continue
        dups, seen = dup_keys(os.path.join(data_dir, fn))
        for k, line, n in dups:
            rows.append("%s:%d  duplicate recipe key %r (occurrence %d; the "
                        "last literal silently wins)" % (fn, line, k, n))
        # sanity: text key count vs loaded table count
        prof = [p for p, f in origin.items() if f == fn]
        if prof:
            n_text = sum(seen.values())
            n_tab = len(data[prof[0]])
            if n_text != n_tab + len(dups):
                rows.append("%s: PARSER MISMATCH text keys=%d loaded=%d dups=%d "
                            "(linter's top-level key regex may be missing entries)"
                            % (fn, n_text, n_tab, len(dups)))
    rep.add("Duplicate recipe keys within a file", rows)

    # ---------------------------------------- 2. same recipe in two professions
    byname = defaultdict(list)
    for prof, recs in data.items():
        for name in recs:
            byname[name].append(prof)
    rows = ["%r registered under: %s  (RDB.nameToRecipe keeps only one; "
            "RecipeDB.lua:78 comment claims names are unique)"
            % (n, ", ".join(sorted(ps)))
            for n, ps in sorted(byname.items()) if len(ps) > 1]
    rep.add("Recipe name registered under two professions", rows,
            "RecipeDB keeps every profession that registers a name (Gordok Ogre "
            "Suit is a distinct spell in Tailoring and in Leatherworking)",
            fatal=False)

    # ------------------------------------------------------ 3/4. field checks
    missing_field = defaultdict(list)
    bad_itemid, unknown_fields, bad_types = [], [], []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            if not isinstance(r, dict):
                bad_types.append("%s / %r: record is not a table" % (prof, name))
                continue
            for f in REQUIRED_FIELDS:
                if f not in r:
                    missing_field[f].append("%s / %r" % (prof, name))
            for f in r:
                if f not in KNOWN_FIELDS:
                    unknown_fields.append("%s / %r: unknown field %r = %r"
                                          % (prof, name, f, r[f]))
            iid = r.get("itemID")
            if iid is None:
                bad_itemid.append("%s / %r: itemID MISSING" % (prof, name))
            elif not isint(iid):
                bad_itemid.append("%s / %r: itemID not an integer (%r)" % (prof, name, iid))
            elif iid <= 0 and prof != "Enchanting":
                bad_itemid.append("%s / %r: itemID = %d (only Enchanting may produce "
                                  "no item)" % (prof, name, int(iid)))
    rows = []
    for f in REQUIRED_FIELDS:
        lst = missing_field[f]
        if lst:
            rows.append("field %r missing on %d record(s): %s%s"
                        % (f, len(lst), "; ".join(lst[:8]),
                           " ... +%d more" % (len(lst) - 8) if len(lst) > 8 else ""))
    rep.add("Records missing a required schema field", rows,
            "required set derived from consumers, see REQUIRED_FIELDS")
    rep.add("itemID missing / non-integer / <= 0 outside Enchanting",
            ["%s (and %d more)" % (bad_itemid[0], len(bad_itemid) - 1)]
            if len(bad_itemid) > 40 else bad_itemid,
            "collapsed" if len(bad_itemid) > 40 else None)
    # itemID<=0 breakdown by profession, since Enchanting is expected to be 0
    zero_by_prof = Counter()
    for prof in data:
        for name, r in data[prof].items():
            iid = r.get("itemID")
            if isinstance(iid, (int, float)) and iid <= 0:
                zero_by_prof[prof] += 1
    rep.add("itemID <= 0 by profession",
            ["%-16s %d" % (p, n) for p, n in sorted(zero_by_prof.items())],
            "itemID 0 means the recipe produces no item, which is correct for "
            "every enchant; RegisterProfession skips these when building "
            "itemToRecipe",
            fatal=False)
    rep.add("Unknown/undocumented record fields", unknown_fields)
    rep.add("Malformed records", bad_types)

    # ---------------------------------------------------- 5/6. reagent checks
    produced = set()
    for prof in data:
        for r in data[prof].values():
            iid = r.get("itemID")
            if isinstance(iid, (int, float)) and iid > 0:
                produced.add(int(iid))
    reagent_ids = set()
    bad_count, no_name, no_itemid, orphan = [], [], [], []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            rgs = r.get("reagents")
            if rgs is None:
                continue
            if not isinstance(rgs, list):
                bad_count.append("%s / %r: reagents is not an array (%r)" % (prof, name, rgs))
                continue
            if not rgs:
                bad_count.append("%s / %r: reagents = {} (empty)" % (prof, name))
            for i, g in enumerate(rgs, 1):
                if not isinstance(g, dict):
                    bad_count.append("%s / %r reagent %d: not a table" % (prof, name, i))
                    continue
                iid = g.get("itemID")
                c = g.get("count")
                if iid is None:
                    no_itemid.append("%s / %r reagent %d: no itemID" % (prof, name, i))
                else:
                    reagent_ids.add(int(iid))
                if c is None:
                    bad_count.append("%s / %r reagent %d (item %s): count MISSING "
                                     "(MaterialCalc.lua:85 defaults to 1)"
                                     % (prof, name, i, iid))
                elif not isint(c) or c <= 0:
                    bad_count.append("%s / %r reagent %d (item %s): count = %r"
                                     % (prof, name, i, iid, c))
                if not g.get("name"):
                    entry = "%s / %r reagent %d (item %s): no name" % (prof, name, i, iid)
                    no_name.append(entry)
                    if iid is not None and int(iid) not in produced:
                        orphan.append(entry + " AND itemID is never produced by any "
                                              "recipe (MaterialCalc shows '???')")
    rep.add("Reagent quantity missing / zero / non-integer", bad_count)
    rep.add("Reagents with no itemID", no_itemid)
    rep.add("Reagents with no name field", no_name)
    rep.add("Reagents with no name AND an itemID nothing produces", orphan)

    # ------------------------------------------------------- 7. skill ranges
    bad_shape, nonmono, zeros, orange_one, req_mismatch = [], [], [], [], []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            sr = r.get("skillRange")
            if sr is None:
                continue
            if not isinstance(sr, list) or len(sr) != 4 or not all(isint(x) for x in sr):
                bad_shape.append("%s / %r: skillRange is not a 4-integer array (%r)"
                                 % (prof, name, sr))
                continue
            o, y, g, gr = [int(x) for x in sr]
            if not (o <= y <= g <= gr):
                nonmono.append("%s / %r: skillRange {%d,%d,%d,%d} not monotonic "
                               "(orange<=yellow<=green<=grey)" % (prof, name, o, y, g, gr))
            if 0 in (o, y, g, gr):
                zeros.append("%s / %r: skillRange {%d,%d,%d,%d} has a zero threshold "
                             "(SkillRangeDetailed prints 'Orange: 0 ...')"
                             % (prof, name, o, y, g, gr))
            sreq = r.get("skillReq")
            if isint(sreq):
                if o == 1 and int(sreq) > 1:
                    orange_one.append("%s / %r: skillRange[1]=1 with skillReq=%d "
                                      "(DB2 MinSkillLineRank=1 leaked into orange; "
                                      "detail panel prints 'Orange: 1')"
                                      % (prof, name, int(sreq)))
                elif int(sreq) != o:
                    req_mismatch.append("%s / %r: skillReq=%d vs skillRange[1]=%d"
                                        % (prof, name, int(sreq), o))
    rep.add("skillRange malformed shape", bad_shape)
    rep.add("skillRange NOT monotonic (orange<=yellow<=green<=grey)", nonmono)
    rep.add("skillRange contains a zero threshold", zeros)
    rep.add("skillRange orange stuck at 1 while skillReq > 1", orange_one)
    rep.add("skillReq differs from skillRange[1]", req_mismatch,
            "expected for some recipes: the README says learn levels come from the "
            "trainer while the range comes from DB2; review individually",
            fatal=False)

    # --------------------------------------------------- 8. source/rod values
    rows, unfilterable = [], []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            srcs = r.get("sources")
            if srcs is None:
                if r.get("source"):
                    rows.append("%s / %r: legacy `source` only, no sources[]" % (prof, name))
                continue
            if not isinstance(srcs, list):
                rows.append("%s / %r: sources is not an array (%r)" % (prof, name, srcs))
                continue
            if not srcs:
                rows.append("%s / %r: sources = {} (empty; TradeSkillFrame "
                            "RecipeSources returns nil -> no source line)" % (prof, name))
            for i, s in enumerate(srcs, 1):
                if not isinstance(s, dict):
                    rows.append("%s / %r source %d: not a table" % (prof, name, i))
                    continue
                m = s.get("method")
                f = s.get("faction")
                if m is None:
                    rows.append("%s / %r source %d: no method" % (prof, name, i))
                elif m not in VALID_METHODS:
                    rows.append("%s / %r source %d: method %r not in the accepted set"
                                % (prof, name, i, m))
                elif m not in FILTERABLE_METHODS:
                    unfilterable.append("%s / %r source %d: method %r has no entry in "
                                        "the TradeSkillFrame srcMap filter (line 4835)"
                                        % (prof, name, i, m))
                if f is None:
                    rows.append("%s / %r source %d: no faction" % (prof, name, i))
                elif f not in VALID_FACTIONS:
                    rows.append("%s / %r source %d: faction %r not in %s"
                                % (prof, name, i, f, sorted(VALID_FACTIONS)))
                for k in s:
                    if k not in ("method", "faction", "detail"):
                        rows.append("%s / %r source %d: unknown key %r" % (prof, name, i, k))
    rep.add("source/method/faction values outside the accepted set", rows)
    rep.add("method valid but unreachable from the Source filter", unfilterable,
            "TradeSkillFrame srcMap owns this; the record itself is well formed",
            fatal=False)

    # rod values
    rows = []
    rods = set()
    ench_src = os.path.join(data_dir, "Enchanting.lua")
    if os.path.isfile(ench_src):
        rods = set(re.findall(r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*itemID',
                              open(ench_src, encoding="utf-8").read()))
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            rod = r.get("rod")
            if rod is not None and rods and rod not in rods:
                rows.append("%s / %r: rod %r not in ProfBuddy.EnchantingRods.list"
                            % (prof, name, rod))
    rep.add("rod values not in the EnchantingRods list", rows)

    # yield
    rows = []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            y = r.get("yield")
            if y is None:
                continue
            if not isint(y) or y <= 0:
                rows.append("%s / %r: yield = %r (MaterialCalc.lua:103 divides by it)"
                            % (prof, name, y))
    rep.add("yield values that would break MaterialCalc", rows)

    # --------------------------------------------- 9. itemID / spellID collisions
    by_item = defaultdict(list)
    by_spell = defaultdict(list)
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            iid = r.get("itemID")
            if isinstance(iid, (int, float)) and iid > 0:
                by_item[int(iid)].append((prof, name))
            sid = r.get("spellID")
            if isinstance(sid, (int, float)) and sid > 0:
                by_spell[int(sid)].append((prof, name))
    cross, within = [], []
    for iid, lst in sorted(by_item.items()):
        if len(lst) > 1:
            profs = {p for p, _ in lst}
            line = "item %d produced by %d recipes: %s" % (
                iid, len(lst), "; ".join("%s/%r" % t for t in lst))
            (cross if len(profs) > 1 else within).append(line)
    rep.add("Produced itemID collides ACROSS professions", cross,
            "itemToRecipe is multi-valued; GetRecipesForItem returns all of them",
            fatal=False)
    rep.add("Produced itemID collides WITHIN one profession", within, None,
            fatal=False)
    rep.add("spellID collisions", ["spell %d: %s" % (s, "; ".join("%s/%r" % t for t in l))
                                   for s, l in sorted(by_spell.items()) if len(l) > 1])
    nospell = ["%s / %r" % (p, n) for p in sorted(data) for n, r in sorted(data[p].items())
               if not r.get("spellID")]
    rep.add("Records with no spellID (Scanner cannot locale-match them)", nospell)

    # ------------------------------------------------------- 10. placeholders
    rows = []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            if PLACEHOLDER_RE.search(name or ""):
                rows.append("%s / %r: placeholder-looking recipe name" % (prof, name))
            iid = r.get("itemID")
            stub = (isinstance(iid, (int, float)) and iid == 0
                    and prof != "Enchanting"
                    and not r.get("reagents"))
            if stub:
                rows.append("%s / %r: STUB (itemID=0, no reagents, skillRange=%r)"
                            % (prof, name, r.get("skillRange")))
            for g in (r.get("reagents") or []):
                if isinstance(g, dict) and g.get("name") and \
                        PLACEHOLDER_RE.search(str(g["name"])):
                    rows.append("%s / %r: placeholder reagent name %r"
                                % (prof, name, g["name"]))
            d = r.get("sourceDetail")
            if isinstance(d, str) and PLACEHOLDER_RE.search(d):
                rows.append("%s / %r: placeholder sourceDetail %r" % (prof, name, d))
            for s in (r.get("sources") or []):
                if isinstance(s, dict) and isinstance(s.get("detail"), str) and \
                        PLACEHOLDER_RE.search(s["detail"]):
                    rows.append("%s / %r: placeholder source detail %r" % (prof, name, s["detail"]))
    rep.add("Placeholder / stub entries", rows)

    # ------------------------------------- 10b. self-reference, jargon, ID band
    rows = []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            iid = r.get("itemID")
            if not (isinstance(iid, (int, float)) and iid > 0):
                continue
            for g in (r.get("reagents") or []):
                if isinstance(g, dict) and g.get("itemID") == iid:
                    rows.append("%s / %r: produces item %d and ALSO lists item %d as "
                                "its own reagent (MaterialCalc expands one bogus extra "
                                "layer before the seen[] guard stops it)"
                                % (prof, name, int(iid), int(iid)))
    rep.add("Recipe lists its own output as a reagent", rows)

    rows, jar = [], Counter()
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            for s in (r.get("sources") or []):
                if not isinstance(s, dict):
                    continue
                d = s.get("detail")
                if isinstance(d, str) and JARGON_RE.search(d):
                    jar[(prof, d)] += 1
                m = s.get("method")
                if isinstance(d, str) and isinstance(m, str) and \
                        d.lower().startswith(m.lower()):
                    rows.append("%s / %r: detail %r restates the method, so the UI "
                                "prints '%s - %s'" % (prof, name, d, m.capitalize(), d))
    rep.add("Internal pipeline jargon in a user-visible source detail",
            ["%s x%d: %r" % (p, n, d) for (p, d), n in sorted(jar.items())],
            "TradeSkillFrame.lua:2604-2612 concatenates `detail` verbatim into the "
            "recipe detail panel")
    rep.add("source detail restates the method word (quest excluded: the UI "
            "already strips a leading 'Quest:')", rows[:3] +
            (["... +%d more" % (len(rows) - 3)] if len(rows) > 3 else []),
            None, fatal=False)

    rows = []
    for prof in sorted(data):
        for name, r in sorted(data[prof].items()):
            iid, sid = r.get("itemID"), r.get("spellID")
            if isinstance(iid, (int, float)) and iid > TBC_MAX_ITEMID:
                rows.append("%s / %r: itemID %d is outside the 2.5.x id band" % (prof, name, int(iid)))
            if isinstance(sid, (int, float)) and sid > TBC_MAX_SPELLID:
                rows.append("%s / %r: spellID %d is outside the 2.5.x id band" % (prof, name, int(sid)))
            for g in (r.get("reagents") or []):
                gi = g.get("itemID") if isinstance(g, dict) else None
                if isinstance(gi, (int, float)) and gi > TBC_MAX_ITEMID:
                    rows.append("%s / %r: reagent itemID %d outside the 2.5.x id band"
                                % (prof, name, int(gi)))
    rep.add("IDs outside the 2.5.x band (VERIFY in client, not asserted)", rows,
            None, fatal=False)

    # ------------------------------------------------ 11. counts + skill bands
    print("\n== Recipe counts per profession ==")
    print("   (expected-total comparison: EXPECTED_TOTALS is empty on purpose; "
          "no verifiable offline source for per-profession TBC 2.5.x totals)")
    for prof in sorted(data):
        recs = data[prof]
        bands = Counter()
        for r in recs.values():
            s = r.get("skillReq")
            s = int(s) if isinstance(s, (int, float)) else -1
            if s < 0:
                bands["?"] += 1
            elif s <= 300:
                bands["classic(<=300)"] += 1
            elif s <= 375:
                bands["tbc(301-375)"] += 1
            else:
                bands[">375"] += 1
        exp = EXPECTED_TOTALS.get(prof)
        extra = ""
        if exp:
            extra = "   expected %d (%s) -> gap %d" % (exp[0], exp[1], exp[0] - len(recs))
        print("   %-16s %5d   %s%s" % (prof, len(recs), dict(bands), extra))
    print("   %-16s %5d" % ("TOTAL", sum(len(v) for v in data.values())))

    rows = []
    for prof, names in sorted(ANCHORS.items()):
        if prof not in data:
            rows.append("profession %r is not registered at all" % prof)
            continue
        have = set(data[prof])
        for n in names:
            if n not in have:
                near = [h for h in have if n.split()[-1].lower() in h.lower()][:3]
                rows.append("%s: anchor %r not present (near: %s)" % (prof, n, near or "none"))
    rep.add("Presence anchors not found (VERIFY, reviewer-knowledge list, not authoritative)",
            rows, None, fatal=False)

    return rep.dump()


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
