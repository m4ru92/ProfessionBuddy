#!/usr/bin/env python3
"""ProfessionBuddy release tool.

One command to build a clean, verified addon zip and (optionally) upload it to
CurseForge via the upload API. Reuses the same build + in-zip verification we do
by hand, and REFUSES to ship on a version mismatch -- the .toc "## Version" must
equal Core.lua's addon.version (the class of bug that shipped a 1.0.1 build
reading 1.0.0).

Layout assumption (matches the GitHub repo): this script lives at
<repo>/tools/release.py and the shipped addon folder is <repo>/ProfessionBuddy/.
Override with --addon-dir.

Usage:
  # build + verify only, no upload (safe to run anytime):
  python tools/release.py --dry-run

  # real release to CurseForge (needs a token + project id):
  export CF_API_TOKEN=xxxxxxxx
  python tools/release.py --project-id 123456 --game-version 2.5.6 \
      --release-type release --changelog-file CHANGELOG-1.1.0.md

  # discover the CurseForge game-version id for a flavor:
  python tools/release.py --list-game-versions --game-version 2.5.6
  python tools/release.py --list-game-versions            # print every version

Gates that run before anything is zipped (skip them with --skip-checks):
  tests/run_all.py     both Lua harnesses, on the 5.1 interpreter
  tools/lint_data.py   the static recipe-DB linter
  Core.lua             refuses to build while a dev addon.BUILD stamp is set
  LICENSE              the addon folder's copy is refreshed from the root copy

The zip is reproducible: entries are sorted, timestamps are fixed, and the
permission and host-OS bits are stamped, so two builds of one tree are
byte-identical and a released zip can be checksum-matched to a tag.
"""
import argparse, fnmatch, json, os, re, sys, io, subprocess, zipfile, mimetypes
import urllib.request, urllib.error

ADDON_NAME = "ProfessionBuddy"
CF_HOST = "https://wow.curseforge.com"
# ProfessionBuddy's CurseForge numeric project id (public, from the project's
# "About Project" box). Override with --project-id / CF_PROJECT_ID if needed.
CF_PROJECT_ID_DEFAULT = "1631296"
DEFAULT_GAME_VERSION = "2.5.6"  # TBC Classic Anniversary current build
# Fixed zip entry timestamp. Any constant works; this is the DOS epoch, the
# oldest value the zip format can store (T-1).
ZIP_DATE = (1980, 1, 1, 0, 0, 0)
# Junk that must never ship, on top of whatever .gitignore lists. The Python
# entries matter because tools/ is Python and someone will eventually drop a
# helper script inside the addon folder.
EXTRA_JUNK = ("*.bak", "*.orig", "*.rej", "*.py", "*.pyc", "__pycache__")
BUILD_STAMP_RE = re.compile(r"^\s*addon\.BUILD\s*=")


def log(msg): print(msg, flush=True)
def die(msg): print("ERROR: " + msg, file=sys.stderr); sys.exit(1)


def tools_dir():
    return os.path.dirname(os.path.abspath(__file__))


def repo_root():
    return os.path.normpath(os.path.join(tools_dir(), ".."))


def default_addon_dir():
    return os.path.normpath(os.path.join(repo_root(), ADDON_NAME))


# ---------------------------------------------------------------- version check
def read_toc_version(addon_dir):
    toc = os.path.join(addon_dir, ADDON_NAME + ".toc")
    if not os.path.isfile(toc):
        die("no .toc at " + toc)
    for line in open(toc, encoding="utf-8", errors="replace"):
        if line.strip().lower().startswith("## version:"):
            return line.split(":", 1)[1].strip()
    die("no '## Version:' line in the .toc")


def read_core_version(addon_dir):
    core = os.path.join(addon_dir, "Core.lua")
    if not os.path.isfile(core):
        return None
    for line in open(core, encoding="utf-8", errors="replace"):
        s = line.strip()
        if s.startswith("addon.version"):
            # addon.version = "1.0.1"
            q = s.split("=", 1)[1].strip().strip('"').strip("'")
            return q
    return None


# ----------------------------------------------------------- pre-build gates
def assert_no_build_stamp(addon_dir):
    """addon.BUILD is a dev-slice marker that is written and never read. A tree
    that still sets it is a dev tree, not a release (D-8)."""
    core = os.path.join(addon_dir, "Core.lua")
    if not os.path.isfile(core):
        return
    with open(core, encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh, 1):
            if BUILD_STAMP_RE.match(line):
                die("Core.lua:%d still assigns addon.BUILD; strip the dev stamp "
                    "before releasing" % i)
    log("BUILD stamp: none (OK)")


def sync_license(root, addon_dir):
    """The zip ships only <ADDON_NAME>/, so the addon folder carries its own
    LICENSE copy. Copy the root one over it at build time so the two cannot
    drift (P-4)."""
    src, dst = os.path.join(root, "LICENSE"), os.path.join(addon_dir, "LICENSE")
    if not os.path.isfile(src):
        die("no LICENSE at " + src)
    with open(src, "rb") as fh:
        want = fh.read()
    have = None
    if os.path.isfile(dst):
        with open(dst, "rb") as fh:
            have = fh.read()
    if want == have:
        log("LICENSE: addon copy already matches the repo root copy")
        return
    with open(dst, "wb") as fh:
        fh.write(want)
    log("LICENSE: refreshed the addon copy from the repo root copy")


def run_gate(path, argv, what):
    if not os.path.isfile(path):
        die("%s is missing at %s" % (what, path))
    log("Gate: %s" % what)
    rc = subprocess.call([sys.executable, path] + argv, cwd=repo_root())
    if rc != 0:
        die("%s failed (exit %d); fix it or pass --skip-checks" % (what, rc))


# ------------------------------------------------------------------- build zip
def junk_patterns(root):
    """Basename globs that must not enter the zip. Derived from .gitignore so
    the two lists cannot drift (D-10)."""
    pats = set(EXTRA_JUNK)
    gi = os.path.join(root, ".gitignore")
    if os.path.isfile(gi):
        with open(gi, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if line and not line.startswith("!"):
                    pats.add(line.strip("/"))
    return sorted(pats)


def build_zip(addon_dir, out_zip, root):
    pats = junk_patterns(root)

    def keep(rel):
        parts = rel.split(os.sep)
        if any(p == ".git" or p == "__pycache__" or p.startswith(".git") for p in parts[:-1]):
            return False
        if rel.startswith(".git"):
            return False
        base = parts[-1]
        return not any(fnmatch.fnmatch(base, p) for p in pats)

    files = []
    for froot, dirs, fnames in os.walk(addon_dir):
        dirs[:] = sorted(d for d in dirs if d not in (".git", "__pycache__"))
        for fn in sorted(fnames):
            full = os.path.join(froot, fn)
            rel = os.path.relpath(full, addon_dir)
            if keep(rel):
                files.append((full, rel))
    files.sort(key=lambda t: t[1])
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for full, rel in files:
            # A fixed date_time, mode and host id make the build reproducible;
            # ZipInfo turns os.sep into "/" for us (T-1).
            info = zipfile.ZipInfo(os.path.join(ADDON_NAME, rel), date_time=ZIP_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            info.create_system = 0
            with open(full, "rb") as fh:
                z.writestr(info, fh.read())
    log("Junk filter: %s" % ", ".join(pats))
    return [r for _, r in files]


# ------------------------------------------------------------------- verify zip
def lua_checker():
    """Return (check_fn, label). The client runs Lua 5.1, and a 5.4/5.5 parser
    accepts `//`, `goto` and bitwise operators that will not load in WoW, so
    prefer the real 5.1 interpreter lupa ships and say which one ran (D-9)."""
    try:
        from lupa.lua51 import LuaRuntime
        flavor = "real 5.1 VM"
    except ImportError:
        try:
            from lupa import LuaRuntime
        except ImportError:
            return None, None
        flavor = "lupa default, NOT a 5.1 check"
    lua = LuaRuntime()
    # loadstring is the 5.1 spelling; load() takes a reader function there.
    chk = lua.execute("local L = loadstring or load\n"
                      "return function(s) local f,e = L(s)\n"
                      "  if f then return true else return e end end")
    return chk, "%s, %s" % (lua.eval("_VERSION"), flavor)


def toc_listed_files(addon_dir):
    """The set of files the .toc loads, as forward-slash relative paths."""
    toc = os.path.join(addon_dir, ADDON_NAME + ".toc")
    out = set()
    if not os.path.isfile(toc):
        return out
    with open(toc, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                out.add(line.replace("\\", "/"))
    return out


def verify_zip(out_zip, addon_dir):
    """Return (problems, lua_label)."""
    problems = []
    listed = toc_listed_files(addon_dir)
    label = None
    with zipfile.ZipFile(out_zip) as z:
        names = z.namelist()
        # 1) single top-level folder == ADDON_NAME
        tops = {n.split("/")[0] for n in names}
        if tops != {ADDON_NAME}:
            problems.append("zip top-level is %s, expected just '%s'" % (sorted(tops), ADDON_NAME))
        # 2) .toc present
        tocname = "%s/%s.toc" % (ADDON_NAME, ADDON_NAME)
        if tocname not in names:
            problems.append("missing " + tocname)
        # 3) every shipped .lua/.xml is either loaded by the .toc or a library.
        #    Catches junk AND a file added to the folder but never to the .toc.
        prefix = ADDON_NAME + "/"
        for n in names:
            if not n.lower().endswith((".lua", ".xml")):
                continue
            rel = n[len(prefix):] if n.startswith(prefix) else n
            if rel in listed or rel.startswith("Libs/"):
                continue
            problems.append("%s is in the zip but not listed in the .toc "
                            "(and not under Libs/)" % n)
        # 4) the shipped LICENSE matches the repo root copy (P-4)
        lic = prefix + "LICENSE"
        root_lic = os.path.normpath(os.path.join(addon_dir, "..", "LICENSE"))
        if lic not in names:
            problems.append("missing " + lic)
        elif os.path.isfile(root_lic):
            with open(root_lic, "rb") as fh:
                if z.read(lic) != fh.read():
                    problems.append("%s differs from the repo root LICENSE" % lic)
        # 5) lua syntax, on 5.1 when lupa has it
        chk, label = lua_checker()
        if chk is None:
            log("  (lupa not installed, skipping the lua syntax check)")
        else:
            for n in names:
                if n.endswith(".lua"):
                    r = chk(z.read(n).decode("utf-8", "replace"))
                    if r is not True:
                        problems.append("lua syntax %s: %s" % (n, r))
    return problems, label


# ------------------------------------------------------------- curseforge api
def cf_get(path, token):
    req = urllib.request.Request(CF_HOST + path, headers={"X-Api-Token": token})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def resolve_game_versions(token, wanted_name):
    versions = cf_get("/api/game/versions", token)
    matches = [v for v in versions if v.get("name") == wanted_name]
    return versions, matches


def multipart(fields, file_field, filename, file_bytes):
    boundary = "----PBRelease7f3a9c2b1d"
    body = io.BytesIO()
    def w(s): body.write(s.encode("utf-8") if isinstance(s, str) else s)
    for k, v in fields.items():
        w("--%s\r\n" % boundary)
        w('Content-Disposition: form-data; name="%s"\r\n\r\n' % k)
        w(v); w("\r\n")
    ctype = mimetypes.guess_type(filename)[0] or "application/zip"
    w("--%s\r\n" % boundary)
    w('Content-Disposition: form-data; name="%s"; filename="%s"\r\n' % (file_field, filename))
    w("Content-Type: %s\r\n\r\n" % ctype)
    w(file_bytes); w("\r\n")
    w("--%s--\r\n" % boundary)
    return "multipart/form-data; boundary=%s" % boundary, body.getvalue()


def cf_upload(token, project_id, zip_path, metadata):
    ctype, body = multipart(
        {"metadata": json.dumps(metadata)},
        "file", os.path.basename(zip_path), open(zip_path, "rb").read())
    url = "%s/api/projects/%s/upload-file" % (CF_HOST, project_id)
    req = urllib.request.Request(url, data=body, method="POST",
                                 headers={"X-Api-Token": token, "Content-Type": ctype})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        die("CurseForge upload failed (HTTP %s): %s" % (e.code, e.read().decode("utf-8", "replace")))


# ------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description="Build, verify, and release ProfessionBuddy.")
    ap.add_argument("--addon-dir", default=default_addon_dir())
    ap.add_argument("--out", default=None, help="output zip path (default: <addon-dir>/../%s.zip)" % ADDON_NAME)
    ap.add_argument("--dry-run", action="store_true", help="build + verify only; no upload")
    ap.add_argument("--project-id", default=os.environ.get("CF_PROJECT_ID", CF_PROJECT_ID_DEFAULT))
    # No default here on purpose: with --list-game-versions, omitting it is the
    # documented way to print every version. The upload path falls back to
    # DEFAULT_GAME_VERSION (T-2).
    ap.add_argument("--game-version", default=None,
                    help="e.g. 2.5.6 (default for an upload: %s)" % DEFAULT_GAME_VERSION)
    ap.add_argument("--release-type", default="release", choices=["release", "beta", "alpha"])
    ap.add_argument("--changelog-file", default=None)
    ap.add_argument("--changelog", default=None)
    ap.add_argument("--changelog-type", default="markdown", choices=["text", "html", "markdown"])
    ap.add_argument("--list-game-versions", action="store_true", help="print matching CF game versions and exit")
    ap.add_argument("--skip-checks", action="store_true",
                    help="skip the harness and data-linter gates (emergencies only)")
    args = ap.parse_args()

    token = os.environ.get("CF_API_TOKEN")

    if args.list_game_versions:
        if not token: die("CF_API_TOKEN not set")
        allv, matches = resolve_game_versions(token, args.game_version)
        if args.game_version:
            log("Matches for %r:" % args.game_version)
            for v in matches: log("  id=%s  name=%s  typeID=%s  slug=%s" % (v.get("id"), v.get("name"), v.get("gameVersionTypeID"), v.get("slug")))
        else:
            for v in allv[:80]: log("  id=%s  name=%s  slug=%s" % (v.get("id"), v.get("name"), v.get("slug")))
        return

    addon_dir = args.addon_dir
    root = os.path.normpath(os.path.join(addon_dir, ".."))
    log("Addon dir: " + addon_dir)

    # version consistency gate
    tocv = read_toc_version(addon_dir)
    corev = read_core_version(addon_dir)
    log("Version: .toc=%s  Core.lua=%s" % (tocv, corev))
    if corev is not None and corev != tocv:
        die("version mismatch: .toc says %s but Core.lua says %s -- bump both before releasing" % (tocv, corev))

    assert_no_build_stamp(addon_dir)
    sync_license(root, addon_dir)

    if args.skip_checks:
        log("Gates: SKIPPED (--skip-checks)")
    else:
        run_gate(os.path.join(root, "tests", "run_all.py"), ["-q"],
                 "tests/run_all.py (Lua harnesses)")
        run_gate(os.path.join(tools_dir(), "lint_data.py"),
                 ["--addon-dir", addon_dir], "tools/lint_data.py (recipe data)")

    out_zip = args.out or os.path.normpath(os.path.join(addon_dir, "..", ADDON_NAME + ".zip"))
    n = build_zip(addon_dir, out_zip, root)
    log("Built %s (%d files)" % (out_zip, len(n)))

    problems, lua_label = verify_zip(out_zip, addon_dir)
    if problems:
        for p in problems: log("  VERIFY FAIL: " + p)
        die("zip verification failed -- not releasing")
    log("Verify: OK (top-level folder, .toc present, every .lua/.xml listed in "
        "the .toc or under Libs/, LICENSE matches the root copy, lua syntax via %s)"
        % (lua_label or "no VM"))

    if args.dry_run:
        log("Dry run -- built + verified v%s, skipping upload." % tocv)
        return

    # ---- upload ----
    if not token: die("CF_API_TOKEN not set")
    if not args.project_id: die("--project-id (or CF_PROJECT_ID) required")
    game_version = args.game_version or DEFAULT_GAME_VERSION
    changelog = args.changelog
    if args.changelog_file:
        changelog = open(args.changelog_file, encoding="utf-8").read()
    if not changelog:
        die("provide --changelog or --changelog-file")

    _, matches = resolve_game_versions(token, game_version)
    if not matches:
        die("no CurseForge game version named %r (try --list-game-versions)" % game_version)
    gv_ids = [m["id"] for m in matches]
    log("Game version %s -> CF ids %s" % (game_version, gv_ids))

    metadata = {
        "changelog": changelog,
        "changelogType": args.changelog_type,
        "displayName": "%s %s" % (ADDON_NAME, tocv),
        "gameVersions": gv_ids,
        "releaseType": args.release_type,
    }
    res = cf_upload(token, args.project_id, out_zip, metadata)
    fid = res.get("id")
    log("Uploaded. CurseForge file id: %s" % fid)
    log("  https://www.curseforge.com/wow/addons/professionbuddy/files/%s" % fid)


if __name__ == "__main__":
    main()
