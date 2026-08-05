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
      --release-type release --changelog-file CHANGELOG-1.0.1.md

  # discover the CurseForge game-version id for a flavor:
  python tools/release.py --list-game-versions --game-version 2.5.6
"""
import argparse, json, os, sys, io, zipfile, mimetypes, urllib.request, urllib.error

ADDON_NAME = "ProfessionBuddy"
CF_HOST = "https://wow.curseforge.com"
# ProfessionBuddy's CurseForge numeric project id (public, from the project's
# "About Project" box). Override with --project-id / CF_PROJECT_ID if needed.
CF_PROJECT_ID_DEFAULT = "1631296"
DEFAULT_GAME_VERSION = "2.5.6"  # TBC Classic Anniversary current build


def log(msg): print(msg, flush=True)
def die(msg): print("ERROR: " + msg, file=sys.stderr); sys.exit(1)


def default_addon_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", ADDON_NAME))


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


# ------------------------------------------------------------------- build zip
def build_zip(addon_dir, out_zip):
    def keep(rel):
        low = rel.lower()
        if low.endswith((".bak", ".zip")):
            return False
        if rel.startswith(".git") or (os.sep + ".git") in rel:
            return False
        return True
    files = []
    for root, dirs, fnames in os.walk(addon_dir):
        dirs[:] = [d for d in dirs if d != ".git"]
        for fn in sorted(fnames):
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, addon_dir)
            if keep(rel):
                files.append((full, rel))
    files.sort(key=lambda t: t[1])
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for full, rel in files:
            with open(full, "rb") as fh:
                z.writestr(os.path.join(ADDON_NAME, rel), fh.read())
    return [r for _, r in files]


# ------------------------------------------------------------------- verify zip
def verify_zip(out_zip, addon_dir):
    problems = []
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
        # 3) lua syntax (best effort -- only if lupa is available)
        try:
            from lupa import LuaRuntime
            lua = LuaRuntime()
            chk = lua.execute("return function(s) local f,e=load(s); if f then return true else return e end end")
            for n in names:
                if n.endswith(".lua"):
                    r = chk(z.read(n).decode("utf-8", "replace"))
                    if r is not True:
                        problems.append("lua syntax %s: %s" % (n, r))
        except ImportError:
            log("  (lupa not installed -- skipping lua syntax check)")
    return problems


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
    ap.add_argument("--game-version", default=DEFAULT_GAME_VERSION, help="e.g. 2.5.6")
    ap.add_argument("--release-type", default="release", choices=["release", "beta", "alpha"])
    ap.add_argument("--changelog-file", default=None)
    ap.add_argument("--changelog", default=None)
    ap.add_argument("--changelog-type", default="markdown", choices=["text", "html", "markdown"])
    ap.add_argument("--list-game-versions", action="store_true", help="print matching CF game versions and exit")
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
    log("Addon dir: " + addon_dir)

    # version consistency gate
    tocv = read_toc_version(addon_dir)
    corev = read_core_version(addon_dir)
    log("Version: .toc=%s  Core.lua=%s" % (tocv, corev))
    if corev is not None and corev != tocv:
        die("version mismatch: .toc says %s but Core.lua says %s -- bump both before releasing" % (tocv, corev))

    out_zip = args.out or os.path.normpath(os.path.join(addon_dir, "..", ADDON_NAME + ".zip"))
    n = build_zip(addon_dir, out_zip)
    log("Built %s (%d files)" % (out_zip, len(n)))

    problems = verify_zip(out_zip, addon_dir)
    if problems:
        for p in problems: log("  VERIFY FAIL: " + p)
        die("zip verification failed -- not releasing")
    log("Verify: OK (top-level folder, .toc present, lua syntax)")

    if args.dry_run:
        log("Dry run -- built + verified v%s, skipping upload." % tocv)
        return

    # ---- upload ----
    if not token: die("CF_API_TOKEN not set")
    if not args.project_id: die("--project-id (or CF_PROJECT_ID) required")
    if not args.game_version: die("--game-version required (e.g. 2.5.6)")
    changelog = args.changelog
    if args.changelog_file:
        changelog = open(args.changelog_file, encoding="utf-8").read()
    if not changelog:
        die("provide --changelog or --changelog-file")

    _, matches = resolve_game_versions(token, args.game_version)
    if not matches:
        die("no CurseForge game version named %r (try --list-game-versions)" % args.game_version)
    gv_ids = [m["id"] for m in matches]
    log("Game version %s -> CF ids %s" % (args.game_version, gv_ids))

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
