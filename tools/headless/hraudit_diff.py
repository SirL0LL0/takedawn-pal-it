#!/usr/bin/env python3
"""hraudit_diff.py <tag>.diff.txt [min pictures]: changed runs by area, the control-free ones first."""
import sys
path = sys.argv[1]; mn = int(sys.argv[2]) if len(sys.argv) > 2 else 1
runs = []; cur = None; head = ''
for line in open(path):
    if line.startswith('#'):
        head += line; continue
    if line.startswith('R '):
        p = line.split()
        cur = dict(va=int(p[1], 16), len=int(p[2]), pic=int(p[3]), idle=int(p[4]), stack='stack' in p, bytes='')
        runs.append(cur)
    elif cur and line.startswith('    '):
        cur['bytes'] = line.strip()
def area(r):
    v = r['va']
    if r['stack']: return 'stack'
    if v >= 0x80000000: return 'contig'
    if v < 0x778200: return 'image'
    return 'heap'
print(head, end='')
tot = {}
for r in runs:
    a = area(r); k = (a, r['idle'] > 0)
    t = tot.setdefault(k, [0, 0]); t[0] += 1; t[1] += r['len']
for k, v in sorted(tot.items()):
    print('# %-6s %-10s runs %5d bytes %9d' % (k[0], 'control' if k[1] else 'pic-only', v[0], v[1]))
for r in runs:
    if r['idle'] or r['stack'] or r['pic'] < mn: continue
    print('%-6s %08X %6d pic %2d  %s' % (area(r), r['va'], r['len'], r['pic'], r['bytes'][:150]))
