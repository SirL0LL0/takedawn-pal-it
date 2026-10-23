#!/usr/bin/env python3
"""hraudit_sym.py <executable> <tag>.watch.txt [--short]: the BO-275 audit's
write chains (offsets in the executable) as function names (nm), innermost
first. The executable must be the run's, unstripped. Non-PIE (Linux release):
an offset is added to the exe base the report names."""
import bisect, re, subprocess, sys

exe, path = sys.argv[1], sys.argv[2]
short = '--short' in sys.argv
syms = []
for line in subprocess.run(['nm', '-n', '--defined-only', exe], capture_output=True, text=True).stdout.splitlines():
    p = line.split()
    if len(p) == 3 and p[1] in 'tTwW':
        syms.append((int(p[0], 16), p[2]))
addrs = [a for a, _ in syms]
base = 0
def name(a):
    i = bisect.bisect_right(addrs, a) - 1
    if i < 0:
        return hex(a)
    s = syms[i][1]
    return s if short else '%s+%x' % (s, a - syms[i][0])
for line in open(path):
    m = re.search(r'exe base (0x[0-9a-f]+|\(nil\))', line)
    if m:
        base = 0 if m.group(1) == '(nil)' else int(m.group(1), 16)
        if base == 0x400000:      # non-PIE: nm's addresses are absolute
            pass
    if line.lstrip().startswith('W ') and ':' in line:
        head, chain = line.rstrip('\n').split(' : ', 1) if ' : ' in line else line.rstrip('\n').split(':', 1)
        names = [name(int(x, 16) + base) for x in chain.split()]
        print(head + ' : ' + ' < '.join(names))
    else:
        print(line, end='')
