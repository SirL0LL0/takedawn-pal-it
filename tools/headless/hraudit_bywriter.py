#!/usr/bin/env python3
"""hraudit_bywriter.py <sum.txt>...: runs grouped by their main writer (phase writer<caller)."""
import sys, re, collections
g = collections.OrderedDict()
for path in sys.argv[1:]:
    for line in open(path):
        m = re.match(r'(\S+)\s+(\d+) pic\s*(\d+) w\s*(\d+)\s+(.*)', line)
        if not m: continue
        va, ln, pic, w, rest = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), m.group(5).strip()
        first = rest.split(';')[0].rsplit(' x', 1)[0] if rest != '(none)' else '(none)'
        k = first
        e = g.setdefault(k, dict(runs=[], bytes=0, maxpic=0, w=0))
        e['runs'].append(va); e['bytes'] += ln; e['maxpic'] = max(e['maxpic'], pic); e['w'] += w
for k, e in sorted(g.items(), key=lambda kv: kv[0]):
    print('%-48s runs %3d bytes %6d maxpic %2d writes %7d  %s' % (k, len(e['runs']), e['bytes'], e['maxpic'], e['w'], ' '.join(e['runs'][:6])))
