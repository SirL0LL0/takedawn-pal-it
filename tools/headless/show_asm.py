#!/usr/bin/env python3
"""Show the guest function that holds an address (tools/headless/show_asm.py).

    python3 tools/headless/show_asm.py 0x001B5F60
    python3 tools/headless/show_asm.py 0x001B5F60 0x00017470      # two at once

Reads the disassembly the recompiler made (build/xr/disasm/asm/text.asm) and
prints the whole function each address falls into.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ASM = os.path.join(ROOT, "build", "xr", "disasm", "asm", "text.asm")

FUNC = re.compile(r"^; Function: (\S+)")
START = re.compile(r"^; Start: (0x[0-9A-Fa-f]+)\s+End: (0x[0-9A-Fa-f]+)")
ADDR = re.compile(r"^\s*0x([0-9A-Fa-f]{8})\s")


def functions(path):
    """[(name, start, end, [lines])] for every function in the file."""
    out = []
    name = start = end = None
    body = []
    with open(path, "r", errors="replace") as f:
        for line in f:
            m = FUNC.match(line)
            if m:
                if name is not None:
                    out.append((name, start, end, body))
                name, body = m.group(1), []
                start = end = None
                continue
            m = START.match(line)
            if m and name is not None and start is None:
                start, end = int(m.group(1), 16), int(m.group(2), 16)
                continue
            if name is not None and ADDR.match(line):
                body.append(line.rstrip())
    if name is not None:
        out.append((name, start, end, body))
    return out


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    if not os.path.isfile(ASM):
        print("no disassembly at %s" % ASM)
        return 1
    wants = [int(a, 0) for a in argv[1:]]
    funcs = functions(ASM)
    for want in wants:
        for name, start, end, body in funcs:
            if start is not None and start <= want < end:
                print("; ==== %s (0x%08X - 0x%08X) ====" % (name, start, end))
                print("\n".join(body))
                print()
                break
        else:
            print("; no function holds 0x%08X" % want)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
