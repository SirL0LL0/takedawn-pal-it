"""Map the NTSC-U guest addresses the high-refresh code names to the PAL
ones, with the patch lists of the two discs as the evidence.

The PAL patch list (config/pal/patches.json) is the NTSC-U one
(config/patches.json) with every site moved to the PAL default.xbe; each
entry's note carries the NTSC-U address it stands for. The pairs give the
shift of the code at each site; the address a wanted site is at follows from
the shift of the site nearest to it, and the PAL disassembly (the functions
the recompiler found) says whether the answer is a function's start.
"""
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NTSC = os.path.join(sys.argv[1] if len(sys.argv) > 1 else
                    r"C:\Users\lollo\AppData\Local\Temp\opencode\naitrate-takedawn",
                    "config", "patches.json")
PAL = os.path.join(REPO, "config", "pal", "patches.json")


def load(path):
    return json.load(open(path, encoding="utf-8"))["patches"]


def key_of(p):
    return (p.get("setting"), p.get("when"), p.get("value"), p.get("kind"),
            p.get("name"))


def main():
    a = load(NTSC)
    b = load(PAL)
    pairs = []
    used = set()
    for p in a:
        k = key_of(p)
        for i, q in enumerate(b):
            if i in used or key_of(q) != k:
                continue
            used.add(i)
            pairs.append((int(p["va"], 16), int(q["va"], 16), p))
            break
    print("coppie abbinate: %d di %d" % (len(pairs), len(a)))
    pairs.sort(key=lambda t: t[0])

    # The shift at each site, and the biggest jump between neighbours.
    print("\n%differenze di spostamento (PAL - NTSC-U):" % 0)
    deltas = {}
    for n, q, p in pairs:
        d = q - n
        deltas.setdefault(d, 0)
        deltas[d] += 1
    for d, c in sorted(deltas.items(), key=lambda kv: -kv[1]):
        print("  %+6d  (%d siti)" % (d, c))

    # The wanted addresses (the NTSC-U ones the high-refresh code names).
    wanted = [
        ("CB3Game::Update", 0x000165F0, "code"),
        ("_rwFrameSyncDirty", 0x001E15E0, "code"),
        ("RwFrameGetLTM", 0x001DD280, "code"),
        ("the vehicles' draw", 0x000303D0, "code"),
        ("the HUD's update", 0x000535E0, "code"),
        ("the stepper's timer", 0x004D5338, "data"),
        ("the frame's steps", 0x004D53AC, "data"),
        ("the half rate", 0x004D538E, "data"),
        ("the global step counter", 0x004A1EB4, "data"),
        ("the game's state", 0x004D53B4, "data"),
        ("the game object", 0x004A71A0, "data"),
        ("the dirty frame list", 0x0075935C, "data"),
        ("the step time (MEMF)", 0x004AE1FC, "data"),
    ]

    print("\ngli indirizzi cercati:")
    for name, va, kind in wanted:
        near = min(pairs, key=lambda t: abs(t[0] - va))
        d = near[1] - near[0]
        print("  %-24s %#010x -> %#010x  (+%#x, dal sito %s %s)"
              % (name, va, va + d, d, near[2].get("setting"), near[2]["va"]))
        # the neighbours' shifts, to see whether the site is in a stable run
        neigh = [p for p in pairs if abs(p[0] - va) < 0x4000]
        if neigh:
            ds = sorted({p[1] - p[0] for p in neigh})
            print("      i %d siti entro 0x4000 hanno spostamenti: %s"
                  % (len(neigh), ", ".join("%+#x" % x for x in ds)))


if __name__ == "__main__":
    main()
