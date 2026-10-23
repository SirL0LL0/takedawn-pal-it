#!/usr/bin/env bash
# fe_scene.sh <rundir> [KEY=VALUE...]
#
# The front end's screens, one game process, for display.hud_fix in the menus
# (BO-222, docs/widescreen-hud.md). A shot of each screen (CAPTURE=1) and,
# with BO3_HUD_DUMP=<file> in the environment, a dump of the 2D scenes there
# (its "=== dump <shot>" line names the screen). Run it once with the setting
# and once without (RECOMP_GFX_HUD_FIX=1 / 0, RECOMP_DISPLAY_WIDESCREEN=1,
# RECOMP_DISPLAY_ULTRAWIDE=21:9 for the wide frames) and compare the shots.
#
#   FE_TOUR=race (default)  main menu, Crash Nav (Select Region), Single
#       Event: Select Mode, Select Options, Select Car, the loading screen,
#       the race intro banner (twice), the pause menu (twice).
#   FE_TOUR=crash           main menu, Crash: Junction Selection, the Crash
#       Training screen, the captions, the countdown (fe_ready/ holds flips
#       +20..+180 after A), the crash cam, Crash Results (twice), Replay
#       (twice).
#   FE_TOUR=results         a race the autopilot drives (race_drive.sh's
#       route, RECOMP_DEBUG=autopilot=1): the finish and its results at
#       RES_OFFS flips after the autopilot's result line (default 200 700
#       1400 2200 3000), then Continue: the RACE RESULTS page. About 8
#       minutes.
#
# The same variables as every scene (scene_lib.sh). Shots are frames of the
# 640-wide buffer: show a 16:9 one at 16:9, a wide stage frame (BO3_UW_LOG=1
# says which flips) at its own aspect.
set -u
source "$(dirname "$0")/scene_lib.sh"
tour="${FE_TOUR:-race}"
case "$tour" in race|crash) scene_start "$@" ;;
    results) scene_start "$@" RECOMP_DEBUG="${RECOMP_DEBUG:+$RECOMP_DEBUG,}autopilot=1" ;;
    *) echo "FE_TOUR=$tour: race, crash or results" >&2; exit 2 ;; esac

# dump <tag>: the 2D scenes into $BO3_HUD_DUMP (main.c's hud_dump_thread).
dump() {
    [ -n "${BO3_HUD_DUMP:-}" ] || return 0
    echo "$1" > "$BO3_HUD_DUMP.req"; wait_flips 20; rm -f "$BO3_HUD_DUMP.req"
}
# snap <name> [flips]: a shot of the screen now (a static one) and a dump.
snap() { shot "$1" "$(flip)" "${2:-30}" 0; dump "$1"; }

to_main_menu
snap fe_main 40
case "$tour" in
race)
    press a:400 0               # Burnout 3 World Tour: Crash Nav, Select Region
    wait_flips 240; snap fe_crashnav 10
    press b:400 120
    press down:200 20
    press a:400 90; snap fe_mode            # Single Event: Select Mode
    press a:400 90; snap fe_options         # Race: Select Options
    press right:200 25; press down:200 20; press right:200 25
    press a:400 90
    wait_log 'CAR1[.]bgv' "car select (CAR1.bgv)"
    wait_flips 150; snap fe_car 10
    press a:400 0               # the first car: the loading screen
    wait_flips 40; snap fe_loading 10
    wait_log "$(track_re crash1)" "race begins (tracks crash1.rws)"
    a=$(anchor "$(track_re crash1)")
    shot fe_intro "$a" 60 0; dump fe_intro
    shot fe_intro2 "$a" 180 0; dump fe_intro2
    wait_flip $(( a + 420 ))
    press start:200 60; snap fe_pause 10
    press down:200 20; snap fe_pause2 10
    ;;
crash)
    to_single_event
    press down:200 20; press down:200 20; press down:200 20     # Crash
    press a:400 90; snap fe_junctions
    press down:200 20           # 1. Trailer Trash
    press a:400 90
    wait_log 'CAR1[.]bgv' "car select (CAR1.bgv)"
    press a:400 0
    wait_log 'TrC_ENG[.]xmv' "Crash Training video (TrC_ENG.xmv)"
    wait_flips 120; snap fe_crashload 10
    wait_log 'C3_V1.streamed[.]dat' "junction streamed in"
    wait_log "$(track_re crash2)" "captions (crash2.rws)"
    b=$(anchor "$(track_re crash2)")
    shot fe_caption "$b" 200 0; dump fe_caption
    wait_flip $(( b + 300 ))
    press a:400 0               # the countdown
    shot fe_ready "$(flip)" 100 80; dump fe_ready
    press rt:600000 0
    wait_log 'C3_v1.crash1[.]rws' "impact (C3_v1 crash1.rws)"
    c=$(anchor 'C3_v1.crash1[.]rws')
    shot fe_crashcam "$c" "$(cam_flips 60)" 0; dump fe_crashcam
    shot fe_crashres "$c" "$(cam_flips 900)" 0; dump fe_crashres
    wait_flips 120; snap fe_crashres2 10
    press b:400 0               # Replay
    g=$(flip)
    shot fe_replay "$g" 90 0; dump fe_replay
    shot fe_replay2 "$g" 400 0; dump fe_replay2
    ;;
results)
    to_single_event
    press a:400 90; press right:200 25; press down:200 20; press right:200 25
    press a:400 90
    wait_log 'CAR1[.]bgv' "car select (CAR1.bgv)"
    press a:400 0
    wait_log "$(track_re crash1)" "race begins (tracks crash1.rws)"
    wait_count '\[AUTOPILOT\] engaged' 1
    SCENE_TIMEOUT="${RACE_LIMIT:-900}" wait_count '\[AUTOPILOT\] result' 1
    r=$(anchor '\[AUTOPILOT\] result' 1)
    for off in ${RES_OFFS:-200 700 1400 2200 3000}; do
        shot "fe_res_$off" "$r" "$off" 0; dump "fe_res_$off"
    done
    press a:400 300; snap fe_respage 10     # Continue: RACE RESULTS
    ;;
esac
scene_end "front end ($tour) done"
