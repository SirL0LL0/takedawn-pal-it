#!/usr/bin/env python3
"""hraudit_sum.py <tag>.watch.sym.txt: per watched run, writers folded to (Update phase, innermost title function, its caller)."""
import re, sys, collections
LIB = 0x2CC200
def addr(n):
    m = re.match(r'sub_([0-9A-F]{8})', n)
    return int(m.group(1), 16) if m else None
out = []
run = None
for line in open(sys.argv[1]):
    if line.startswith('R '):
        p = line.split(); run = dict(va=p[1], len=int(p[2]), pic=int(p[3]), w=collections.Counter(), n=0); out.append(run)
    elif line.lstrip().startswith('W ') and run is not None:
        head, chain = line.split(' : ', 1)
        h = head.split(); cnt = int(h[1]); thr = h[2]
        names = [x.strip() for x in chain.split(' < ')]
        phase = '?'
        for i, n in enumerate(names):
            if n.startswith('sub_000165F0'):
                phase = names[i - 1] if i > 0 else 'Update'
                break
        if thr == 'other': phase = 'OTHER:' + (names[-1] if names else '?')
        title = [n for n in names if addr(n) is not None and addr(n) < LIB and not n.startswith('sub_000165F0')]
        hr = [n for n in names if n.startswith('bo3_') and n != 'bo3_update']
        w = title[0] if title else (names[0] if names else '?')
        c = title[1] if len(title) > 1 else ''
        key = (phase, w, c, hr[0] if hr else '')
        run['w'][key] += cnt; run['n'] += cnt
    elif 'no write seen' in line and run is not None:
        run['none'] = 1
for r in out:
    top = r['w'].most_common(4)
    s = '; '.join('%s %s<%s%s x%d' % (k[0].replace('sub_000',''), k[1].replace('sub_00',''), k[2].replace('sub_00',''), (' ['+k[3]+']') if k[3] else '', v) for k, v in top)
    print('%s %5d pic%2d w%6d  %s' % (r['va'], r['len'], r['pic'], r['n'], s if s else '(none)'))
