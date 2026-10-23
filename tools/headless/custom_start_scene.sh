#!/usr/bin/env bash
# [STEP=menu|pick|race] [...] custom_start_scene.sh <rundir>
#
# BO-230, "Custom music at start": a made folder of three soundtracks
# (Alpha, Beta, Gamma: two tones each, a different pitch per soundtrack), a
# scratch HOME and a scratch settings.toml (never the player's), then:
#
#   STEP=menu     main menu, MENU_SECS (20) of music: which soundtrack's songs
#                 the title opened (the log's [SOUNDTRACK] song ids)
#   STEP=pick     the same, then Driver Details > Settings > EA GAMES TRAX,
#                 X PICKS times (default 2), A: confirm; leave; the settings
#                 file is read for audio.custom_music_soundtrack
#   STEP=race     main menu, Single Event > Race, RACE_SECS (20) in the race
#                 (which soundtrack opened songs there)
#
#   SETTINGS_TOML=<file>   the scratch settings file kept between steps
#                          (default <rundir>/settings.toml, created if absent)
#   FOLDER=none            no music folder at all
#   AT_START=0|1           audio.custom_music_at_start in the file (default: none)
#   STEP=pick tools/headless/custom_start_scene.sh runs/cs1
set -u
source "$(dirname "$0")/scene_lib.sh"
REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RD="$(cd "$REPO" && mkdir -p "$1" && cd "$1" && pwd)"
HOME_DIR="${SCENE_HOME:-$RD/home}"
MUSIC="${MUSIC:-$RD/music}"
SET="${SETTINGS_TOML:-$RD/settings.toml}"
STEP="${STEP:-menu}"
mkdir -p "$HOME_DIR"
if [ ! -d "$MUSIC" ] && [ "${FOLDER:-}" != none ]; then
"${PYTHON:-python3}" - "$MUSIC" <<'PY'
import math, os, struct, sys
root = sys.argv[1]
rate, secs = 8000, 25
for k, name in enumerate(["Alpha", "Beta", "Gamma"]):
    d = os.path.join(root, name)
    os.makedirs(d)
    for j in range(2):
        f = 330 + 110 * k + 55 * j
        pcm = bytes(128 + int(60 * math.sin(2 * math.pi * f * i / rate)) for i in range(rate * secs))
        hdr = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate, 1, 8) \
              + b"data" + struct.pack("<I", len(pcm))
        open(os.path.join(d, "%02d %s.wav" % (j + 1, name)), "wb").write(hdr + pcm)
PY
fi
# The scratch settings file: made once; the game rewrites it.
if [ ! -f "$SET" ]; then
    : > "$SET"
    if [ "${FOLDER:-}" != none ] || [ -n "${AT_START:-}" ]; then
        echo "[audio]" >> "$SET"
        [ "${FOLDER:-}" != none ] && echo "custom_music_dir = \"$MUSIC\"" >> "$SET"
        [ -n "${AT_START:-}" ] && echo "custom_music_at_start = $([ "$AT_START" = 0 ] && echo false || echo true)" >> "$SET"
    fi
fi
scene_start "$RD" HOME="$HOME_DIR" RECOMP_SETTINGS="$SET"
fail=0
bad() { note "FAIL: $*"; fail=1; }
faulted() { grep -aqE '\[FAULT\]|\[HANG\]|SIGSEGV|SIGBUS|a sound bank did not load' "$D/log.txt"; }
# The soundtracks whose songs were opened since line $1 of the log: "1 2".
opened() { tail -n +"${1:-1}" "$D/log.txt" | grep -a '\[SOUNDTRACK\] song ' | sed -E 's/.*song 0*([0-9A-Fa-f]{4})[0-9A-Fa-f]{4}:.*/\1/' | sort -u | tr '\n' ' '; }
loglines() { wc -l < "$D/log.txt"; }

to_main_menu
M0=1
wait_flips $(( ${MENU_SECS:-20} * 60 ))
note "menu: soundtracks opened: [$(opened $M0)]"
grep -a "custom music at start\|chosen in the game\|the title now counts" "$D/log.txt" | head -12 | while IFS= read -r l; do note "$l"; done
if [ "$STEP" = pick ]; then
    M1=$(loglines)
    # Driver Details > Settings > EA GAMES TRAX
    press down:200 20; press down:200 20; press down:200 20; press down:200 20
    press a:400 90
    press down:200 20; press down:200 20; press down:200 20; press down:200 20
    press a:400 90
    press down:200 20; press down:200 20; press down:200 20
    press a:400 150
    for _ in $(seq 1 "${PICKS:-2}"); do press x:300 200; done
    note "screen: soundtracks opened since: [$(opened $M1)]"
    press a:400 200
    wait_flips 240
    press b:300 90; press b:300 120
    wait_flips 120
    note "settings.toml: $(grep -a 'custom_music' "$SET" | tr '\n' ' ')"
    grep -a "chosen in the game" "$D/log.txt" | tail -4 | while IFS= read -r l; do note "$l"; done
fi
if [ "$STEP" = race ]; then
    M1=$(loglines)
    to_single_event
    press a:400 90                          # Race
    press right:200 25; press down:200 20; press right:200 25
    press a:400 150
    wait_log 'CAR1[.]bgv' "car select"
    press a:400 0
    wait_log "$(track_re crash1)" "race begins"
    wait_flips $(( ${RACE_SECS:-20} * 60 ))
    alive
    note "race: soundtracks opened since the menu: [$(opened $M1)]"
fi
faulted && bad "fault in the log"
STOP_AT_END=1 scene_end "custom start $STEP: $([ $fail = 0 ] && echo ok || echo FAILED)"
