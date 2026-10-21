#!/usr/bin/env python3
"""List the strings of the XBE's .rdata in a range (tools/headless/strings_at.py).

    python3 tools/headless/strings_at.py 0x003AA6C0 0x003AA820

Prints every null-terminated string with its address, so a table of file
names can be read with the addresses the code uses.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
XBE = os.path.join(ROOT, "Burnout 3 Takedown", "default.xbe")
TOOLKIT = os.environ.get("XBOXRECOMP_DIR", os.path.join(ROOT, "..", "xboxrecomp-apex"))


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    path = argv[1]
    lo, hi = int(argv[2], 0), int(argv[3], 0)
    sys.path.insert(0, TOOLKIT)
    from tools.xbe_parser.xbe_parser import XBEParser
    p = XBEParser(path)
    f = p.parse()
    data = p.data
    for s in f.sections:
        if s.name != ".rdata":
            continue
        off = s.raw_addr + (lo - s.virtual_addr)
        end = s.raw_addr + (hi - s.virtual_addr)
        while off < end:
            stop = data.find(b"\0", off, end)
            if stop < 0:
                break
            blob = data[off:stop]
            if blob:
                va = s.virtual_addr + (off - s.raw_addr)
                try:
                    txt = blob.decode("ascii")
                except UnicodeDecodeError:
                    txt = repr(blob)
                print("0x%08X  %s" % (va, txt))
            off = stop + 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
