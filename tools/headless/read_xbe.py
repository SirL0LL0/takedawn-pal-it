#!/usr/bin/env python3
"""Read the game's XBE bytes at a guest address (tools/headless/read_xbe.py).

    python3 tools/headless/read_xbe.py 0x001B5FB4:64

The address is the one the disassembly prints (the .text section's virtual
address). The XBE's sections are read from the file, so the bytes are the
ones the game runs. The toolkit's own parser (tools/xbe_parser) reads the
header, so this works on any XBE the port accepts.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
XBE = os.path.join(ROOT, "Burnout 3 Takedown", "default.xbe")
TOOLKIT = os.environ.get("XBOXRECOMP_DIR", os.path.join(ROOT, "..", "xboxrecomp-apex"))


def load(path):
    """(bytes, [(name, vaddr, vsize, raw_off, raw_size)]) of an XBE."""
    sys.path.insert(0, TOOLKIT)
    from tools.xbe_parser.xbe_parser import XBEParser
    p = XBEParser(path)
    f = p.parse()
    secs = [(s.name, s.virtual_addr, s.virtual_size, s.raw_addr, s.raw_size)
            for s in f.sections]
    return p.data, secs


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    if not os.path.isfile(path):
        print("no XBE at %s" % path)
        return 1
    data, secs = load(path)
    for arg in argv[2:]:
        addr, _, count = arg.partition(":")
        want = int(addr, 0)
        count = int(count, 0) if count else 64
        for name, vaddr, vsize, roff, rsize in secs:
            if not (vaddr <= want < vaddr + max(vsize, rsize)):
                continue
            off = roff + (want - vaddr)
            blob = data[off:off + count]
            print("%s 0x%08X (%s+0x%X):" % (path, want, name, want - vaddr))
            for i in range(0, len(blob), 16):
                chunk = blob[i:i + 16]
                hexs = " ".join("%02X" % b for b in chunk)
                txt = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
                print("  %08X  %-47s  %s" % (want + i, hexs, txt))
            break
        else:
            print("0x%08X is in no section" % want)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
