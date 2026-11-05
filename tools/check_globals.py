#!/usr/bin/env python3
"""ProfessionBuddy global-write gate.

Parses every .lua file the addon loads (every toc; Libs/ excluded: the
bundled libraries own their globals) and lists each assignment to a global
variable: `x = 1` or `function x() end` where `x` is not a local in scope.
Field writes (`ProfBuddy.x = 1`, `UIPanelWindows[name] = nil`) are not
global writes and are not listed.

A global PB means to own goes in ALLOWED below. Anything else fails the run:
a stray global leaks into every other addon's namespace (a missing `local`
is the usual cause) and can taint Blizzard code that reads the same name.

Usage:  python tools/check_globals.py [--addon-dir ProfessionBuddy]
Needs:  pip install luaparser
Exit:   0 = no unexpected global writes, 1 = some, 2 = a file did not parse,
        3 = luaparser is not installed.
"""
import argparse, contextlib, io, os, sys

try:
    from luaparser import ast, astnodes
except ImportError:
    print("ERROR: luaparser is not installed. pip install luaparser", file=sys.stderr)
    sys.exit(3)

# Globals ProfessionBuddy owns on purpose, and why.
ALLOWED = {
    "ProfBuddy":        "the addon table (every module hangs off it)",
    "ProfBuddyDB":      "SavedVariables, declared in the tocs",
    "SLASH_PROFBUDDY1": "slash command /pb (Blizzard reads SLASH_<NAME><n>)",
    "SLASH_PROFBUDDY2": "slash command /profbuddy",
}


def default_addon_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "ProfessionBuddy"))


def addon_files(addon_dir):
    """Every .lua file any toc loads, outside Libs/ (libs.xml pulls those)."""
    files = []
    for toc in sorted(f for f in os.listdir(addon_dir) if f.endswith(".toc")):
        for line in open(os.path.join(addon_dir, toc), encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or not line.lower().endswith(".lua"):
                continue
            rel = line.replace("\\", "/")
            if rel.startswith("Libs/"):
                continue
            if rel not in files:
                files.append(rel)
    return files


class Walker:
    """Walk one chunk with a stack of local scopes; record global writes."""

    def __init__(self):
        self.scopes = [set()]
        self.writes = []          # (name, line)
        self.cur = None           # line of the statement being walked

    def is_local(self, name):
        return any(name in s for s in self.scopes)

    def push(self, names=()):
        self.scopes.append(set(names))

    def pop(self):
        self.scopes.pop()

    def write(self, node, line):
        if isinstance(node, astnodes.Name) and not self.is_local(node.id):
            self.writes.append((node.id, line))

    def visit_list(self, items):
        for n in items or []:
            self.visit(n)

    def visit_function(self, args, body, extra=()):
        names = list(extra)
        for a in args or []:
            if isinstance(a, astnodes.Name):
                names.append(a.id)
        self.push(names)
        self.visit(body)
        self.pop()

    def visit(self, node):
        if node is None:
            return
        if isinstance(node, list):
            self.visit_list(node)
            return
        if not isinstance(node, astnodes.Node):
            return
        # luaparser keeps a token on statements, not on every name: carry
        # the nearest statement's line down to the names inside it.
        tok = getattr(node, "_first_token", None)
        if tok is not None and getattr(tok, "line", None):
            self.cur = tok.line
        if isinstance(node, astnodes.Chunk):
            self.visit(node.body)
        elif isinstance(node, astnodes.Block):
            self.push()
            self.visit_list(node.body)
            self.pop()
        elif isinstance(node, astnodes.LocalAssign):
            self.visit_list(node.values)          # values first: `local x = x`
            for t in node.targets:
                if isinstance(t, astnodes.Name):
                    self.scopes[-1].add(t.id)
        elif isinstance(node, astnodes.Assign):
            line = self.cur                       # before a value's body moves it
            self.visit_list(node.values)
            for t in node.targets:
                if isinstance(t, astnodes.Name):
                    self.write(t, line)
                else:
                    self.visit(t)
        elif isinstance(node, astnodes.LocalFunction):
            self.scopes[-1].add(node.name.id)
            self.visit_function(node.args, node.body)
        elif isinstance(node, astnodes.Method):
            self.visit(node.source)
            self.visit_function(node.args, node.body, extra=("self",))
        elif isinstance(node, astnodes.Function):
            if isinstance(node.name, astnodes.Name):
                self.write(node.name, self.cur)
            else:
                self.visit(node.name)
            self.visit_function(node.args, node.body)
        elif isinstance(node, astnodes.AnonymousFunction):
            self.visit_function(node.args, node.body)
        elif isinstance(node, astnodes.Fornum):
            self.visit(node.start); self.visit(node.stop); self.visit(node.step)
            self.push([node.target.id])
            self.visit(node.body)
            self.pop()
        elif isinstance(node, astnodes.Forin):
            self.visit_list(node.iter)
            self.push([t.id for t in node.targets if isinstance(t, astnodes.Name)])
            self.visit(node.body)
            self.pop()
        else:
            for key, val in vars(node).items():
                if key in ("first_token", "last_token", "comments", "parent"):
                    continue
                if isinstance(val, (astnodes.Node, list)):
                    self.visit(val)


def check_file(path):
    src = open(path, encoding="utf-8").read()
    with contextlib.redirect_stdout(io.StringIO()):   # luaparser prints its tree
        tree = ast.parse(src)
    w = Walker()
    w.visit(tree)
    return [(name, line or "?") for name, line in w.writes]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--addon-dir", default=default_addon_dir())
    a = ap.parse_args()
    bad, parse_fail, seen = [], [], {}
    files = addon_files(a.addon_dir)
    for rel in files:
        path = os.path.join(a.addon_dir, rel)
        try:
            writes = check_file(path)
        except Exception as e:                       # noqa: BLE001
            parse_fail.append("%s: %s" % (rel, str(e).splitlines()[0][:160]))
            continue
        for name, line in writes:
            seen.setdefault(name, []).append("%s:%s" % (rel, line))
            if name not in ALLOWED:
                bad.append("%s:%s  writes global %r" % (rel, line, name))
    print("Checked %d files (all tocs, Libs/ excluded)." % len(files))
    for name in sorted(seen):
        tag = "allowed" if name in ALLOWED else "UNEXPECTED"
        print("  %-22s %-10s %s" % (name, tag, ", ".join(seen[name][:4]) + (" ..." if len(seen[name]) > 4 else "")))
    if parse_fail:
        print("PARSE FAIL:")
        for p in parse_fail:
            print("  " + p)
        sys.exit(2)
    if bad:
        print("GLOBALS FAIL: %d unexpected global write(s):" % len(bad))
        for b in bad:
            print("  " + b)
        print("Add `local`, or list the name in ALLOWED with the reason PB owns it.")
        sys.exit(1)
    print("GLOBALS OK: PB writes only the globals it owns (%s)." % ", ".join(sorted(ALLOWED)))


if __name__ == "__main__":
    main()
