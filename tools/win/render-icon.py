#!/usr/bin/env python3
"""render-icon.py <svg> <out dir>: the icon at the sizes a Windows icon
holds (16 to 256), one PNG each. tools/release/make_ico.py makes the .ico
of them.

The renderer is the resvg_py module, else the resvg or rsvg-convert program
on the PATH: the same three the release scripts use.
"""
import os
import subprocess
import sys

SIZES = (16, 24, 32, 48, 64, 128, 256)


def main(svg, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    try:
        import resvg_py
    except ImportError:
        resvg_py = None

    for s in SIZES:
        png = os.path.join(out_dir, "%d.png" % s)
        if resvg_py is not None:
            data = resvg_py.svg_to_bytes(svg_path=svg, width=s, height=s)
            with open(png, "wb") as f:
                f.write(bytes(data))
            continue
        if subprocess.call(["resvg", "-w", str(s), "-h", str(s), svg, png],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL) == 0:
            continue
        if subprocess.call(["rsvg-convert", "-w", str(s), "-h", str(s), svg,
                            "-o", png],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL) == 0:
            continue
        raise SystemExit("no SVG renderer: install resvg-py in the Python, "
                         "or install resvg or rsvg-convert")
    print("%d PNGs in %s" % (len(SIZES), out_dir))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
