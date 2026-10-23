#!/usr/bin/env python3
"""zbias_report.py <rundir> [--three] [--crops outdir]

For a scenery_scene.sh run made with SCENERY_NOFX=1 (BO-253): the world
stands still under each pause menu while the toolkit's depth offsets
(nv2a_texrep zbias, BO-176 / BO-204) change every 4 flips.

  SCENERY_DEBUG=zbias_ab=4               two pictures: on, off (on when
                                          (flip / 4) is even)
  SCENERY_DEBUG=zbias_ab=4,zbias_all=ab  with --three: off, front faces only
                                          (the BO-253 rule), both faces
                                          (BO-176 as released), by
                                          (flip / 4) % 3; SCENERY_WIN=23

A frame is drawn about a flip before its number, so the middle ones (flip % 4
== 2) are the safe ones. Per pause N (ab.tsv) the pictures are compared:
share of pixels that differ by more than 16, and the box around them.
--crops writes the pictures side by side around that box, enlarged
(<outdir>/<k>_<where>.png) and the whole frames.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load(d, n):
    p = d / "frames" / f"fb_flip_{n:05d}.bmp"
    return Image.open(p).convert("RGB") if p.exists() else None


def diff(a, b):
    m = np.abs(np.asarray(a, dtype=np.int16) - np.asarray(b, dtype=np.int16)).max(axis=2) > 16
    ys, xs = np.nonzero(m)
    box = tuple(int(v) for v in (xs.min(), ys.min(), xs.max(), ys.max())) if len(xs) else None
    return 100.0 * m.mean(), int(m.sum()), box


def strip(ims, box, z=3):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    w = max(160, x1 - x0 + 40)
    h = max(120, y1 - y0 + 30)
    im0 = ims[0]
    r = (max(0, cx - w // 2), max(0, cy - h // 2), min(im0.width, cx + w // 2), min(im0.height, cy + h // 2))
    cs = [i.crop(r).resize(((r[2] - r[0]) * z, (r[3] - r[1]) * z), Image.NEAREST) for i in ims]
    o = Image.new("RGB", (sum(c.width for c in cs) + 4 * (len(cs) - 1), cs[0].height), (255, 0, 255))
    x = 0
    for c in cs:
        o.paste(c, (x, 0))
        x += c.width + 4
    return o


def main():
    d = Path(sys.argv[1])
    three = "--three" in sys.argv
    crops = Path(sys.argv[sys.argv.index("--crops") + 1]) if "--crops" in sys.argv else None
    if crops:
        crops.mkdir(parents=True, exist_ok=True)
    rows = [l.split("\t") for l in (d / "ab.tsv").read_text().split("\n") if l]
    names = ["off", "front", "both"] if three else ["on", "off"]
    print("  #      N  where   frames          " + ("front:off  both:off  both:front" if three else "changed%") + "   box")
    for k, (n, where) in enumerate(rows):
        n = int(n)
        if three:
            f0 = next((f for f in range(n - 1, n + 14) if f % 4 == 2 and (f // 4) % 3 == 0
                       and all(load(d, f + 4 * i) for i in range(3))), None)
            fs = [f0 + 4 * i for i in range(3)] if f0 is not None else None
        else:
            f0 = next((f for f in range(n - 1, n + 8) if f % 4 == 2 and (f // 4) % 2 == 0
                       and load(d, f) and load(d, f + 4)), None)
            fs = [f0, f0 + 4] if f0 is not None else None
        if fs is None:
            print(f"{k:3d} {n:6d}  {where:7s} no set")
            continue
        ims = [load(d, f) for f in fs]
        if three:
            d01, d02, d12 = diff(ims[0], ims[1]), diff(ims[0], ims[2]), diff(ims[1], ims[2])
            box = d02[2] or d01[2]
            print(f"{k:3d} {n:6d}  {where:7s} {fs[0]}+4+4  {d01[0]:9.3f}  {d02[0]:8.3f}  {d12[0]:10.3f}   {box}")
            ch = d02[1] + d01[1] > 3
        else:
            dd = diff(ims[0], ims[1])
            box = dd[2]
            print(f"{k:3d} {n:6d}  {where:7s} {fs[0]}/{fs[1]}  {dd[0]:8.3f}   {box}")
            ch = dd[1] > 3
        if crops:
            for nm, im in zip(names, ims):
                im.save(crops / f"{k}_full_{nm}.png")
            if box and ch:
                strip(ims, box).save(crops / f"{k}_{where}.png")


main()
