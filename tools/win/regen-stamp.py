#!/usr/bin/env python3
"""regen-stamp.py: write src/game/recomp/gen/regen.stamp, on Windows.

The stamp is what a release build (-DBO3_RELEASE=ON) checks: the key the
generated code was made with, the hash of the generated files, how many
files there are, how many of the guest patches of config/patches.json went
in, and how many spin waits the generated C has. tools/release/gen.sh writes
it (with the repository's regen.sh); this writes it after the repository's
tools\\win\\regen.bat, with the same rules:

    key <regen key>          cmake/release_info.cmake's hash of the inputs
    tree <sha256>            the generated files ("<sha256>  <name>" a line,
                             sorted by name, hashed)
    files <n>                the files named recomp_*
    patches <in>/<listed>    from the recompiler's own report
    spin_waits <n>           RECOMP_SPIN_WAIT lines in the generated C

Usage: python tools\\win\\regen-stamp.py [--root DIR] [--toolkit DIR]
       [--cmake CMAKE] [--report FILE]

The report is the recompiler's patches.json (build\\xr\\recomp\\patches.json
by default). The key comes from cmake/release_info.cmake, run as a script.
"""
import hashlib
import json
import os
import re
import subprocess
import sys


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def gen_tree_hash(gen_dir):
    """The hash of the generated files: "<sha256>  <name>" a line, sorted by
    name, hashed. The same rule in cmake/release_info.cmake (BO3_RELEASE) and
    in tools/release/common.sh (gen_tree_hash)."""
    names = sorted(n for n in os.listdir(gen_dir)
                   if n.startswith("recomp_") and
                   os.path.isfile(os.path.join(gen_dir, n)))
    text = "".join("%s  %s\n" % (sha256_file(os.path.join(gen_dir, n)), n)
                    for n in names)
    return hashlib.sha256(text.encode("utf-8")).hexdigest(), names


def regen_key(root, toolkit, cmake, region):
    """The key cmake/release_info.cmake computes: the hash of the disc's
    hash and of the recompiler's inputs. The script writes the header with
    the key in it; the header is read back."""
    out = os.path.join(root, "build", "release-info")
    os.makedirs(out, exist_ok=True)
    subprocess.run([cmake,
                    "-DBO3_ROOT=%s" % root,
                    "-DXBOXRECOMP_DIR=%s" % toolkit,
                    "-DBO3_RELEASE_DIR=%s" % out,
                    "-DBO3_REGION=%s" % region,
                    "-P", os.path.join(root, "cmake", "release_info.cmake")],
                   check=True, cwd=root)
    header = open(os.path.join(out, "bo3_release.h"), encoding="utf-8").read()
    m = re.search(r'#define BO3_REGEN_KEY "([0-9a-f]+)"', header)
    if not m:
        raise SystemExit("cmake/release_info.cmake wrote no BO3_REGEN_KEY")
    return m.group(1)


def count_spin_waits(gen_dir, names):
    """The RECOMP_SPIN_WAIT lines in the generated C (the files the shell
    script counts: recomp_0*.c)."""
    n = 0
    for name in names:
        if not name.startswith("recomp_0"):
            continue
        with open(os.path.join(gen_dir, name), encoding="utf-8",
                  errors="replace") as f:
            n += sum(1 for line in f if "RECOMP_SPIN_WAIT" in line)
    return n


def main(argv):
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    toolkit = os.environ.get("XBOXRECOMP_DIR") or os.path.join(root, "..", "xboxrecomp")
    cmake = os.environ.get("CMAKE") or "cmake"
    region = os.environ.get("BO3_REGION") or "NTSC-U"
    report = os.path.join(root, "build", "xr", "recomp", "patches.json")
    args = list(argv[1:])
    while args:
        a = args.pop(0)
        if a == "--root":
            root = os.path.abspath(args.pop(0))
        elif a == "--toolkit":
            toolkit = os.path.abspath(args.pop(0))
        elif a == "--cmake":
            cmake = args.pop(0)
        elif a == "--region":
            region = args.pop(0)
        elif a == "--report":
            report = os.path.abspath(args.pop(0))
        else:
            raise SystemExit(__doc__)

    gen = os.path.join(root, "src", "game", "recomp", "gen")
    if not os.path.isdir(gen):
        raise SystemExit("missing %s -- run the regen first" % gen)

    key = regen_key(root, toolkit, cmake, region)
    tree, names = gen_tree_hash(gen)
    if not names:
        raise SystemExit("%s has no recomp_* file" % gen)

    if not os.path.isfile(report):
        raise SystemExit("missing the recompiler's report %s" % report)
    doc = json.load(open(report, encoding="utf-8"))
    patches = "%d/%d" % (doc["patched_sites"], len(doc["sites"]))
    if doc["patched_sites"] != len(doc["sites"]):
        raise SystemExit("only %s of the guest patches went in" % patches)

    spins = count_spin_waits(gen, names)
    if spins == 0:
        raise SystemExit("the generated C has no RECOMP_SPIN_WAIT")

    stamp = ("key %s\n"
             "tree %s\n"
             "files %d\n"
             "patches %s\n"
             "spin_waits %d\n" % (key, tree, len(names), patches, spins))
    with open(os.path.join(gen, "regen.stamp"), "w", encoding="utf-8",
              newline="\n") as f:
        f.write(stamp)
    for line in stamp.rstrip("\n").split("\n"):
        print("    " + line)


if __name__ == "__main__":
    main(sys.argv)
