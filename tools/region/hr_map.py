"""hr_map.py: the PAL address of an NTSC-U one, from the two patch lists.

The PAL default.xbe is the same program as the NTSC-U one, rebuilt: every
guest address the port names has a PAL twin. The two patch lists
(config/patches.json and config/pal/patches.json) are the same 112 sites,
moved, so their pairs say how far the code and the data moved at each of
them; the address a wanted site is at follows from the shift of the site
nearest to it.

Usage:  python3 tools/region/hr_map.py 0x4D53AC 0x000165F0 ...

With no address it lists the shift at every site, so the regions of the
code and the data can be seen. The tool that found the addresses from the
two executables is xbemap.py; this one needs nothing but the lists.

A warning: the shift is not the same everywhere (the PAL .data moves
+0x320 in the game object and at its end, +0x300 in the rest), and the
nearest site can lie about a function that moved far. The answer here is a
place to start; the address must be checked against the PAL disassembly,
where the code that reads it names it.
"""
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load(path):
    return json.load(open(path, encoding="utf-8"))["patches"]


def key_of(p):
    return (p.get("setting"), p.get("when"), p.get("value"), p.get("kind"),
            p.get("name"))


def pairs(ntsc, pal):
    """The two lists' sites, paired: the NTSC-U one, the PAL one, the site
    itself. The lists are the same, in the same order; the fields that
    name the site are the check."""
    out, used = [], set()
    for p in ntsc:
        k = key_of(p)
        for i, q in enumerate(pal):
            if i in used or key_of(q) != k:
                continue
            used.add(i)
            out.append((int(p["va"], 16), int(q["va"], 16), p))
            break
    out.sort(key=lambda t: t[0])
    return out


def main(argv):
    ntsc = load(os.path.join(REPO, "config", "patches.json"))
    pal = load(os.path.join(REPO, "config", "pal", "patches.json"))
    ps = pairs(ntsc, pal)
    print("coppie abbinate: %d di %d" % (len(ps), len(ntsc)))

    if not argv:
        print("\nlo spostamento a ogni sito:")
        for n, q, p in ps:
            print("  %#010x -> %#010x  (%+#x)  %s" % (n, q, q - n, p.get("setting")))
        return

    print("\ngli indirizzi cercati:")
    for arg in argv:
        va = int(arg, 16)
        near = min(ps, key=lambda t: abs(t[0] - va))
        d = near[1] - near[0]
        near2 = sorted(ps, key=lambda t: abs(t[0] - va))[1] if len(ps) > 1 else near
        agree = (near2[1] - near2[0]) == d
        print("  %#010x -> %#010x  (%+#x, dal sito %s %s%s)"
              % (va, va + d, d, near[2].get("setting"), near[2]["va"],
                 "" if agree else "  [i due siti vicini non concordano]"))


if __name__ == "__main__":
    main(sys.argv[1:])
