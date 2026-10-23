#!/usr/bin/env python3
"""texup_stats.py <rundir>  (BO-245)

A texup_measure.sh run: the frames after the GO (go_flip.txt) from the
RECOMP_TRACE=frametime CSV: frame_ms p50 / p99 / max, the frames over 1.5
periods (25 ms at 60) and over 17.5 ms, the executor's busy p99, the GPU
time per frame (gpu_ms, three flips late on Metal) p50 / p99, the
upscaler's chunk GPU ms (tu_ms) total and max in a frame, and the last
[TEXUP] line (memory, counts).
"""
import csv
import re
import sys
from pathlib import Path


def pct(v, p):
    v = sorted(v)
    if not v:
        return float('nan')
    return v[min(len(v) - 1, int(len(v) * p / 100))]


def main():
    d = Path(sys.argv[1])
    go = int((d / 'go_flip.txt').read_text().strip() or 0) if (d / 'go_flip.txt').exists() else 0
    rows = []
    with open(d / 'ft.csv', newline='') as f:
        for r in csv.DictReader(f):
            try:
                if int(r['flip']) > go + 10:
                    rows.append(r)
            except (ValueError, KeyError):
                pass
    if len(rows) > 20:
        rows = rows[:-5]   # the stop
    fm = [float(r['frame_ms']) for r in rows]
    iv = [max(1, int(r['iv'])) for r in rows]
    late = sum(int(r['late']) for r in rows)
    # Over budget: a frame later than 1.5 of the interval the title asked
    # for (60 fps racing: 25 ms; a 30 fps crash camera: 50 ms).
    over = sum(f > i * 1000.0 / 60.0 * 1.5 for f, i in zip(fm, iv))
    f60 = [f for f, i in zip(fm, iv) if i == 1]
    busy = [float(r['ex_busy']) for r in rows]
    gpu = [float(r['gpu_ms']) for r in rows if r.get('gpu_ms') and float(r['gpu_ms']) >= 0]
    tu = [float(r['tu_ms']) for r in rows if r.get('tu_ms')]
    print(f'frames {len(fm)} after flip {go}')
    print(f'60 fps frames {len(f60)}: frame_ms p50 {pct(f60, 50):.2f} p99 {pct(f60, 99):.2f}'
          f' p99.9 {pct(f60, 99.9):.2f} max {max(f60) if f60 else 0:.2f}; over 17.5 ms {sum(x > 17.5 for x in f60)}')
    print(f'all frames: over 1.5 x the asked interval {over}, late flips {late}')
    print(f'ex_busy p50 {pct(busy, 50):.2f} p99 {pct(busy, 99):.2f} max {max(busy) if busy else 0:.2f}')
    if gpu:
        print(f'gpu_ms p50 {pct(gpu, 50):.2f} p99 {pct(gpu, 99):.2f} max {max(gpu):.2f}')
    if tu:
        print(f'tu_ms total {sum(tu):.1f} max/frame {max(tu):.3f} frames with chunks {sum(x > 0 for x in tu)}')
    last = None
    for line in open(d / 'log.txt', errors='replace'):
        if line.startswith('[TEXUP] flip'):
            last = line.strip()
    if last:
        print(last)


if __name__ == '__main__':
    main()
