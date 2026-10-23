#!/usr/bin/env bash
# texup_scene.sh <rundir> [KEY=VALUE...]   (BO-245)
#
# graphics.texture_upscale on one paused frame: Single Event > Race (region
# RACE_REGION, track RACE_TRACK: default 1 and 1, USA Silver Lake
# Southbound), drive RACE_SECS s (default 12), pause, then switch the
# setting live through RECOMP_DEBUG=texup_ctl: MODES (default
# "0 1 2 0": off, FSRCNNX, NNEDI3, off), waiting WAIT flips after each switch
# (default 600: the upscaler fills while the pause menu keeps flipping),
# a shot of the same frame with each (CAPTURE=1). The first and the last
# shot (both off) must be identical. SCALE=4: the modes at 4x. ROADS=1: the
# road surfaces too.
set -u
source "$(dirname "$0")/scene_lib.sh"
RD="$1"; shift
mkdir -p "$RD"; CTL="$(cd "$RD" && pwd)/texup_ctl.txt"
echo "0 ${SCALE:-2} ${ROADS:-0}" > "$CTL"
scene_start "$RD" "$@" "RECOMP_DEBUG=texup_log,texup_ctl=${GAME_PATH_PREFIX:-}$CTL"
to_main_menu
to_single_event
press a:400 90
for (( k = 0; k < ${RACE_REGION:-1}; k++ )); do press right:200 25; done
press down:200 20
for (( k = 0; k < ${RACE_TRACK:-1}; k++ )); do press right:200 25; done
press a:400 90
wait_log 'CAR1[.]bgv' "car select (CAR1.bgv)"
press a:400 0
wait_log "$(track_re crash1)" "race begins (tracks crash1.rws)"
wait_flips 300
press rt:$(( ${RACE_SECS:-12} * 1000 )) 0
sleep "${RACE_SECS:-12}"
wait_flips 30
press start:200 60
n=0
for m in ${MODES:-0 1 2 0}; do
    n=$(( n + 1 ))
    echo "$m ${SCALE:-2} ${ROADS:-0}" > "$CTL"
    wait_flips "${WAIT:-600}"
    a=$(flip)
    shot "m${n}_mode$m" "$a" 150
    [ -n "${SHOT_HOOK:-}" ] && $SHOT_HOOK "$RD/m${n}_mode$m"
done
scene_end "texup: modes on one paused frame"
