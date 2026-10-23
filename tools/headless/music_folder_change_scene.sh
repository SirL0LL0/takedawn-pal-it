#!/usr/bin/env bash
# [KEY=VALUE...] music_folder_change_scene.sh <rundir>
#
# BO-243: the custom music folder changed in the overlay while the game runs,
# together with "custom music at start" (BO-230). In a window (the overlay
# needs one). Made folders of tones under a scratch HOME:
#
#   home/zene/Acid, home/zene/Rave, home/zene/Techno Pick   two songs each
#   home/other/Xeno One, home/other/Xeno Two                 two songs each
#
# The scratch settings.toml starts on START_DIR (default home/zene/Techno
# Pick: one soundtrack, "Techno Pick"), custom_music_at_start on, and
# custom_music_soundtrack = REMEMBER (default "Techno Pick"; "-" for no key).
#
#   1. Main menu, MENU_SECS (12) of music: the start switch (the log's
#      "custom music at start" line), the soundtracks the title opened.
#   2. The overlay, Audio page, Custom music folder, the folder list:
#      PICK=parent (default) "Current folder" is entered, ".." once, "Use
#      this folder" (the parent: home/zene); PICK=home: Home > zene > Use;
#      PICK=other: Home > other > Use; PICK=none: no change. The list's rows
#      (state files browser_*.txt) and the row's line after it are noted.
#   3. Driver Details > Settings > EA GAMES TRAX: X XS times (default 4),
#      the soundtracks previewed (ids, the high half of a song's id), A, out.
#   4. VISITS (default 0) more visits of the screen with X XS times each
#      (the main menu keeps its row, the submenus do not always: a later
#      visit can land on another page; SHOTS=1 shows where it went).
#
#   SHOTS=1   window shots of each screen step (visit<n>_*.bmp)
#
# Pass: the line under the row, the "title now counts" line after the
# overlay is closed, and the soundtracks previewed in the first visit (the
# new folder's: 0001 0002 0003 for PICK=parent).
#
# The run's settings file is <rundir>/settings.toml (kept after the run, for
# a second run with SETTINGS_TOML=... to see the next start).
#   PICK=parent tools/headless/music_folder_change_scene.sh runs/mfc1
set -u
source "$(dirname "$0")/scene_lib.sh"
REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RD="$(cd "$REPO" && mkdir -p "$1" && cd "$1" && pwd)"
HOME_DIR="$RD/home"
SET="${SETTINGS_TOML:-$RD/settings.toml}"
START_DIR="${START_DIR:-$HOME_DIR/zene/Techno Pick}"
REMEMBER="${REMEMBER:-Techno Pick}"
PICK="${PICK:-parent}"
mkdir -p "$HOME_DIR"
if [ ! -d "$HOME_DIR/zene" ]; then
"${PYTHON:-python3}" - "$HOME_DIR" <<'PY'
import math, os, struct, sys
root = sys.argv[1]
rate, secs = 8000, 25
sets = [("zene", ["Acid", "Rave", "Techno Pick"]), ("other", ["Xeno One", "Xeno Two"])]
k = 0
for top, names in sets:
    for name in names:
        d = os.path.join(root, top, name)
        os.makedirs(d)
        for j in range(2):
            f = 330 + 60 * k + 30 * j
            pcm = bytes(128 + int(60 * math.sin(2 * math.pi * f * i / rate)) for i in range(rate * secs))
            hdr = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " \
                  + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate, 1, 8) + b"data" + struct.pack("<I", len(pcm))
            open(os.path.join(d, "%02d %s.wav" % (j + 1, name)), "wb").write(hdr + pcm)
        k += 1
PY
fi
if [ ! -f "$SET" ]; then
    {
        echo "[audio]"
        echo "custom_music_dir = \"$START_DIR\""
        echo "custom_music_at_start = true"
        [ "$REMEMBER" != - ] && echo "custom_music_soundtrack = \"$REMEMBER\""
    } > "$SET"
fi
ov="$RD/ovtest.txt"; : > "$ov"
WINDOW=1 scene_start "$RD" HOME="$HOME_DIR" RECOMP_SETTINGS="$SET" RECOMP_OVERLAY_TEST="$ov"
trap 'kill "$(cat "$D/pid" 2>/dev/null)" 2>/dev/null' EXIT    # never left running
fail=0
bad() { note "FAIL: $*"; fail=1; }
faulted() { grep -aqE '\[FAULT\]|\[HANG\]|SIGSEGV|SIGBUS|a sound bank did not load' "$D/log.txt"; }
opened() { tail -n +"${1:-1}" "$D/log.txt" | grep -a '\[SOUNDTRACK\] song ' | sed -E 's/.*song 0*([0-9A-Fa-f]{4})[0-9A-Fa-f]{4}:.*/\1/' | sort -u | tr '\n' ' '; }
loglines() { echo $(( $(wc -l < "$D/log.txt") )); }
ovl() { echo "$1" >> "$ov"; sleep 0.4; }
st() {
    local k=0
    rm -f "$RD/ovstate.txt"
    echo "state $RD/ovstate.txt" >> "$ov"
    until [ -s "$RD/ovstate.txt" ] || [ $k -gt 100 ]; do sleep 0.1; k=$((k + 1)); done
    cat "$RD/ovstate.txt" 2>/dev/null
}
body() { st | grep -v '^\(open\|page\|offer\|paused\|browser\) '; }
row_of() { body | grep -n -- "$1" | head -n 1 | cut -d: -f1; }
sel_row() { body | grep -n '^>' | head -n 1 | cut -d: -f1; }
to_row() {
    local want cur k=0; want=$(row_of "$1"); [ -n "$want" ] || { bad "no row '$1'"; return 1; }
    cur=$(sel_row)
    while [ "${cur:-0}" != "$want" ]; do
        [ "${cur:-0}" -lt "$want" ] && ovl "pad down" || ovl "pad up"
        cur=$(sel_row); k=$((k + 1))
        [ $k -gt 60 ] && { bad "could not reach row '$1'"; return 1; }
    done
    return 0
}
pick() { to_row "$1" && ovl "pad a" && sleep 0.5; }
shot_state() { st > "$RD/$1.txt"; note "$1: $(head -n 4 "$RD/$1.txt" | tr '\n' '|')"; }
# Driver Details > Settings > EA GAMES TRAX, X $1 times; prints the ids previewed.
trax_visit() {
    local m; m=$(loglines)
    VISIT=$(( ${VISIT:-0} + 1 ))
    # The title keeps the main menu's row (Driver Details) after a visit.
    [ "$VISIT" = 1 ] && { press down:200 20; press down:200 20; press down:200 20; press down:200 20; }
    press a:400 90
    [ "${SHOTS:-0}" = 1 ] && { echo "shot $RD/visit${VISIT}_dd.bmp" >> "$ov"; sleep 1; }
    [ "$VISIT" = 1 ] && { press down:200 20; press down:200 20; press down:200 20; press down:200 20; }
    press a:400 90
    [ "${SHOTS:-0}" = 1 ] && { echo "shot $RD/visit${VISIT}_set.bmp" >> "$ov"; sleep 1; }
    [ "$VISIT" = 1 ] && { press down:200 20; press down:200 20; press down:200 20; }
    press a:400 150
    [ "${SHOTS:-0}" = 1 ] && { echo "shot $RD/visit${VISIT}_x0.bmp" >> "$ov"; sleep 1; }
    for i in $(seq 1 "$1"); do
        press x:300 200
        [ "${SHOTS:-0}" = 1 ] && { echo "shot $RD/visit${VISIT}_x$i.bmp" >> "$ov"; sleep 1; }
    done
    note "screen: soundtracks previewed: [$(opened $m)]"
    press a:400 200
    wait_flips 120
    press b:300 90; press b:300 120
    wait_flips 120
}

to_main_menu
wait_flips $(( ${MENU_SECS:-12} * 60 ))
note "menu: soundtracks opened: [$(opened 1)]"
grep -a "custom music at start\|the title now counts" "$D/log.txt" | head -6 | while IFS= read -r l; do note "$l"; done

if [ "$PICK" != none ]; then
    M1=$(loglines)
    ovl "pad back+start"; sleep 1
    k=0
    until st | grep -q '^page Audio'; do ovl "pad rb"; k=$((k + 1)); [ $k -gt 8 ] && { bad "no Audio page"; break; }; done
    pick 'Custom music folder'
    shot_state browser_open
    case "$PICK" in
        parent) pick 'Current folder'; shot_state browser_current; pick ': \.\.$'; shot_state browser_up ;;
        home)   pick 'place: Home'; pick 'dir: zene' ;;
        other)  pick 'place: Home'; pick 'dir: other' ;;
    esac
    shot_state browser_before_use
    grep -q "^browser $HOME_DIR/$([ "$PICK" = other ] && echo other || echo zene)\$" "$RD/browser_before_use.txt" \
        || bad "the list is not in the folder to choose"
    pick 'use: '
    sleep 3
    st > "$RD/page_after.txt"
    note "row: $(grep -a 'Custom music folder' "$RD/page_after.txt") | $(grep -a '^  info' "$RD/page_after.txt" | head -2 | tr '\n' '|')"
    ovl "pad b"; sleep 1
    wait_flips 120
    tail -n +"$M1" "$D/log.txt" | grep -a "music folder:\|SOUNDTRACK\] .*soundtrack\|next start\|title now counts\|library in use" | head -12 \
        | while IFS= read -r l; do note "$l"; done
fi

trax_visit "${XS:-4}"
for v in $(seq 1 "${VISITS:-0}"); do trax_visit "${XS:-4}"; done
note "settings.toml: $(grep -a 'custom_music' "$SET" | tr '\n' ' ')"
tail -n +1 "$D/log.txt" | grep -a "chosen in the game\|title now counts\|custom music at start\|folder change" | tail -8 \
    | while IFS= read -r l; do note "$l"; done
faulted && bad "fault in the log"
STOP_AT_END=1 scene_end "music folder change $PICK: $([ $fail = 0 ] && echo ok || echo FAILED)"
exit $fail
