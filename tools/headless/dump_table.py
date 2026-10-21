#!/usr/bin/env python3
"""List the pointers of a table in the XBE (tools/headless/dump_table.py).

    python3 tools/headless/dump_table.py 0x00383900 16

Prints each dword of the table and, for the ones that point into .rdata, the
string there. A table of language file names reads like this.
"""

import os
import struct
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
    want = int(argv[2], 0)
    count = int(argv[3], 0)
    sys.path.insert(0, TOOLKIT)
    from tools.xbe_parser.xbe_parser import XBEParser
    p = XBEParser(path)
    f = p.parse()
    data = p.data
    secs = [(s.name, s.virtual_addr, s.virtual_size, s.raw_addr, s.raw_size) for s in f.sections]

    def off_of(va):
        for name, vaddr, vsize, roff, rsize in secs:
            if vaddr <= va < vaddr + max(vsize, rsize):
                return roff + (va - vaddr)
        return None

    def cstr(va):
        off = off_of(va)
        if off is None:
            return None
        end = data.find(b"\0", off)
        return data[off:end].decode("ascii", "replace")

    for i in range(count):
        va = want + i * 4
        off = off_of(va)
        if off is None:
            print("%08X  (not in the image)" % va)
            continue
        (v,) = struct.unpack_from("<I", data, off)
        s = cstr(v)
        print("%08X  %08X  %s" % (va, v, s if s is not None else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
