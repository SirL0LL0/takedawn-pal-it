#!/usr/bin/env bash
# texup_measure.sh <rundir> [KEY=VALUE...]   (BO-245)
#
# graphics.texture_upscale's frame-time measurement: race_drive.sh's race
# (Single Event > Race, USA, Silver Lake Southbound, the title's AI driving
# from the GO) with RECOMP_TRACE=frametime (executor columns only, no
# sampler) and RECOMP_DEBUG=texup_log, MODE (off, fsrcnnx, nnedi3; SCALE 2
# or 4) set from the start, for SECS seconds after the GO (default 90);
# then the game is stopped and tools/perf/texup_stats.py summarises the
# frames after the GO into <rundir>/stats.txt.
#
#   COLD=1   empty the upscaler's disk cache (TEXUP_DIR, default <shader
#            cache>/texup) first; the shader cache itself stays warm, so
#            pipeline builds do not enter the numbers. On Linux the cache is
#            $XDG_CACHE_HOME/<executable>/texup: give TEXUP_DIR.
# One instance at a time; the other variables are race_drive.sh's.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
[ $# -ge 1 ] || { echo "usage: $0 <rundir> [KEY=VALUE...]" >&2; exit 2; }
rundir=$1; shift
REPO="${REPO:-$(cd "$here/../.." && pwd)}"
D="$(cd "$REPO" && mkdir -p "$rundir" && cd "$rundir" && pwd)"
secs=${SECS:-90}
mode=${MODE:-off}
sc="${RECOMP_RENDER_SHADER_CACHE:-$REPO/build/shader-cache}"
[ "${COLD:-0}" = 1 ] && rm -rf "${TEXUP_DIR:-$sc/texup}"
STOP_AT_END=1 RECOMP_DEBUG="${RECOMP_DEBUG:+$RECOMP_DEBUG,}texup_log" \
    bash "$here/race_drive.sh" "$rundir" \
    RECOMP_TRACE="frametime=$D/ft.csv,frametime_us=0" \
    RECOMP_GFX_TEXTURE_UPSCALE="$mode" RECOMP_GFX_TEXTURE_UPSCALE_SCALE="${SCALE:-2}x" "$@" \
    > "$D/drive.out" 2>&1 &
drv=$!
t=$(date +%s)
until grep -aq '\[AUTOPILOT\] engaged' "$D/log.txt" 2>/dev/null; do
    kill -0 $drv 2>/dev/null || break
    [ $(( $(date +%s) - t )) -gt 900 ] && break
    sleep 1
done
go=$(grep -a '\[GPU\] flip' "$D/log.txt" 2>/dev/null | tail -1 | sed -n 's/.*flip \([0-9]*\).*/\1/p')
echo "${go:-0}" > "$D/go_flip.txt"
t=$(date +%s)
while kill -0 $drv 2>/dev/null && [ $(( $(date +%s) - t )) -lt "$secs" ]; do sleep 2; done
pkill -P $drv 2>/dev/null
kill $drv 2>/dev/null
[ -f "$D/pid" ] && kill "$(cat "$D/pid")" 2>/dev/null
sleep 2
[ -f "$D/pid" ] && kill -9 "$(cat "$D/pid")" 2>/dev/null
wait $drv 2>/dev/null
python3 "$REPO/tools/perf/texup_stats.py" "$D" > "$D/stats.txt"
cat "$D/stats.txt"
