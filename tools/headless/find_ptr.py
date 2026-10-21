#!/usr/bin/env python3
"""Find who points at a guest address in the XBE (tools/headless/find_ptr.py).

    python3 tools/headless/find_ptr.py 0x003A92D8

Prints the addresses of the dwords in the XBE that hold the address asked
for, so a string in .rdata can be followed to the table that uses it and
from there to the code that reads the table.
"""

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
XBE = os.path.join(ROOT, "Burnout 3 Takedown", "default.xbe")
TOOLKIT = os.environ.get("XBOXRECOMP_DIR", os.path.join(ROOT, "..", "xboxrecomp-apex"))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    wants = [int(a, 0) for a in argv[2:]]
    sys.path.insert(0, TOOLKIT)
    from tools.xbe_parser.xbe_parser import XBEParser
    p = XBEParser(path)
    f = p.parse()
    data = p.data
    base = f.header.base_address
    for want in wants:
        print("== pointers to 0x%08X ==" % want)
        for s in f.sections:
            end = s.raw_addr + s.raw_size
            off = s.raw_addr
            while off + 4 <= end:
                (v,) = struct.unpack_from("<I", data, off)
                if v == want:
                    print("   %s+0x%X (va 0x%08X)" % (s.name, off - s.raw_addr,
                                                       s.virtual_addr + (off - s.raw_addr)))
                off += 4
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
