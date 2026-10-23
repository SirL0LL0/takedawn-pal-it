#!/usr/bin/env bash
# soundtrack_restart_scene.sh <rundir> [KEY=VALUE...]
#
# GitHub #17 / BO-221: race loading screens with a short custom soundtrack.
# A made folder of SONGS songs (default 3, SONG_SECS long each, default 20),
# the reporter's settings (SETTINGS=<settings.toml>, its custom_music_dir
# replaced by the made folder; default: none), the soundtrack chosen in
# Driver Details > Settings > EA GAMES TRAX, then Single Event > Race and
# RESTARTS times: RACE_SECS (12) in the race, Start, RESTART, YES: a new loading
# screen each time (ROAD_RAGE=n: then quit the race and restart Road Rage n times in the same process). Fails on a fault or a hang in the log; prints the [HANDLE] stale lines (a closed
# handle's token used again, with the guest caller) and their count.
set -u
source "$(dirname "$0")/scene_lib.sh"
REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RD="$(cd "$REPO" && mkdir -p "$1" && cd "$1" && pwd)"
HOME_DIR="${SCENE_HOME:-$RD/home}"
MUSIC="$RD/music"
rm -rf "$HOME_DIR"; mkdir -p "$HOME_DIR"
rm -rf "$MUSIC"; mkdir -p "$MUSIC/Custom Soundtrack"
if [ -n "${MUSIC_SRC:-}" ]; then cp "$MUSIC_SRC"/* "$MUSIC/Custom Soundtrack/"; else   # MUSIC_SRC: a folder of real songs instead
"${PYTHON:-python3}" - "$MUSIC/Custom Soundtrack" "${SONGS:-3}" "${SONG_SECS:-20}" <<'PY'
import math, os, struct, sys
d, n, secs = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rate = 8000
for k in range(n):
    f = 330 + 110 * k
    pcm = bytes(128 + int(60 * math.sin(2 * math.pi * f * i / rate)) for i in range(rate * secs))
    hdr = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate, 1, 8) \
          + b"data" + struct.pack("<I", len(pcm))
    open(os.path.join(d, "%02d tone.wav" % (k + 1)), "wb").write(hdr + pcm)
PY
fi
SET=none
if [ -n "${SETTINGS:-}" ]; then
    SET="$RD/settings.toml"
    sed -e "s|^custom_music_dir = .*|custom_music_dir = \"$MUSIC\"|" "$SETTINGS" > "$SET"
fi
scene_start "$@" HOME="$HOME_DIR" RECOMP_SETTINGS="$SET" RECOMP_AUDIO_MUSIC_DIR="$MUSIC"
fail=0
bad() { note "FAIL: $*"; fail=1; }
faulted() { grep -aqE '\[FAULT\]|\[HANG\]|SIGSEGV|SIGBUS|a sound bank did not load' "$D/log.txt"; }

to_main_menu
# Driver Details > Settings > EA GAMES TRAX; the soundtrack chosen (as custom_music_scene.sh step 3).
press down:200 20; press down:200 20; press down:200 20; press down:200 20
press a:400 90
press down:200 20; press down:200 20; press down:200 20; press down:200 20
press a:400 90
press down:200 20; press down:200 20; press down:200 20
press a:400 150
press x:300 200
press a:400 200
press b:300 90; press b:300 120
press up:200 20; press up:200 20; press up:200 20
press a:400 90                              # Single Event
press a:400 90                              # Race
press right:200 25; press down:200 20; press right:200 25
press a:400 150
wait_log 'CAR1[.]bgv' "car select"
press a:400 0
wait_log "$(track_re crash1)" "race begins"
# restarts <count> <label>: race, Start, RESTART, YES: a new loading screen each time.
restarts() {
    local n=0 mark t
    while [ "$n" -lt "$1" ]; do
        n=$((n + 1))
        press rt:$(( ${RACE_SECS:-12} * 1000 )) 0
        wait_flips $(( ${RACE_SECS:-12} * 60 ))
        alive
        faulted && return
        mark=$(( $(wc -l < "$D/events.txt") + 1 ))
        press start:300 60
        press down:200 30                       # RESTART
        press a:400 120                         # "Are you sure", on NO
        press up:300 40                         # YES
        press a:400 0
        t=$(date +%s)
        until tail -n +"$mark" "$D/events.txt" | grep -aqE "$(track_re "crash[0-9]+")"; do
            faulted && return
            kill -0 "$(cat "$D/pid")" 2>/dev/null || { bad "game exited in $2 restart $n"; return; }
            [ $(( $(date +%s) - t )) -gt 180 ] && { bad "$2 restart $n: no race start in 180 s"; return; }
            sleep 1
        done
        note "$2 restart $n: race on (race loads so far: $(grep -acE "$(track_re "crash[0-9]+")" "$D/events.txt"))"
    done
}
restarts "${RESTARTS:-10}" race
n=$(( ${RESTARTS:-10} + ${ROAD_RAGE:-0} ))
if [ "${ROAD_RAGE:-0}" != 0 ] && ! faulted && [ $fail = 0 ]; then
    # The same process goes on: pause > QUIT > YES, Single Event > Road Rage with the defaults, then
    # ROAD_RAGE restarts of it (a loading screen each).
    press rt:6000 0                         # the countdown is over before the pause
    wait_flips 400
    press start:300 60
    press down:200 30; press down:200 30; press down:200 30; press down:200 30; press down:200 30   # QUIT
    press a:400 120                         # "Are you sure", on NO
    press up:300 40                         # YES
    press a:400 0
    wait_flips 600
    note "left the race"
    press down:200 20; press down:200 20    # Road Rage
    mark=$(( $(wc -l < "$D/events.txt") + 1 ))
    press a:400 90                          # its options
    press a:400 90                          # the defaults: Select Car
    until tail -n +"$mark" "$D/events.txt" | grep -aq 'CAR1[.]bgv'; do alive; sleep 0.5; done
    press a:400 0
    until tail -n +"$mark" "$D/events.txt" | grep -aqE "$(track_re "crash[0-9]+")"; do
        faulted && break
        alive
        sleep 1
    done
    note "road rage on (race loads so far: $(grep -acE "$(track_re "crash[0-9]+")" "$D/events.txt"))"
    restarts "${ROAD_RAGE:-3}" "road rage"
fi
faulted && bad "fault: $(grep -aE '\[FAULT\]|\[HANG\]|a sound bank did not load|#1 |#2 |#3 ' "$D/log.txt" | head -5 | tr '\n' ' ')"
# A tagged handle token that names no object (BO-221): printed, not a failure by itself.
grep -a '\[HANDLE\]' "$D/log.txt" | head -10 | while IFS= read -r l; do note "$l"; done
note "stale handle lines: $(grep -ac '\[HANDLE\] stale' "$D/log.txt")"
note "songs opened: $(grep -ac '\[SOUNDTRACK\] song ' "$D/log.txt"); restarts: $n"
STOP_AT_END=1 scene_end "soundtrack restarts: $([ $fail = 0 ] && echo ok || echo FAILED)"
exit $fail
