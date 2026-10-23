/* region_map.h - the NTSC-U addresses the upstream's new code names and
 * their PAL twins.
 *
 * The upstream's code is written for the NTSC-U disc; the PAL disc is the
 * same program built again, so every address it names has a twin here.
 * The port's own code writes them as BO3_VA(ntsc, pal) pairs (the
 * NTSC-U one first, the build picks one), and the region's macro lives
 * in region.h.
 *
 * The twins come from the PAL executable itself: each address is
 * checked by the role the PAL code gives it (a count compared with 2, a
 * float, a table walked with a stride, a function the caller calls), and
 * against the shifts the port's own verified pairs show.
 */
#ifndef BO3_REGION_MAP_H
#define BO3_REGION_MAP_H

#include "region.h"

/* The guest's own globals (src/game/hirefresh.c). */
#define HR_TIMER        BO3_VA(0x4D5338u, 0x4D5658u)   /* the stepper's timer object */
#define HR_FRAME_STEPS  BO3_VA(0x4D53ACu, 0x4D56CCu)   /* the steps this frame runs */
#define HR_HALF_ASKED   BO3_VA(0x4D538Du, 0x4D56ADu)   /* the half rate asked for */
#define HR_HALF_RATE    BO3_VA(0x4D538Eu, 0x4D56AEu)   /* the half rate in force */
#define HR_GAME_STATE   BO3_VA(0x4D53B4u, 0x4D56D4u)   /* the game object's state */
#define HR_FRAME_TIME   BO3_VA(0x4D53B0u, 0x4D56D0u)   /* the frame's steps x the step time */
#define HR_STAGE        BO3_VA(0x4D5370u, 0x4D5690u)   /* the stage */
#define HR_STEP_COUNT   BO3_VA(0x4A1EB4u, 0x4A21D4u)   /* the global step counter */
#define HR_PLAYERS      BO3_VA(0x73A1C0u, 0x73A4D0u)   /* the players at once */
#define HR_PLAYER_CAR   BO3_VA(0x73A1D0u, 0x73A4E0u)   /* player 1's car */
#define HR_RACERS       BO3_VA(0x64B38Cu, 0x64B69Cu)   /* the racer table */
#define HR_RACERS_N     BO3_VA(0x73A19Cu, 0x73A4ACu)   /* the racers' number */
#define HR_DIRTY_HEAD   BO3_VA(0x75935Cu, 0x75967Cu)   /* RenderWare's dirty frame list */
#define HR_GAME_RNG     BO3_VA(0x4D1FD8u, 0x4D22F8u)   /* the game's random numbers */
#define HR_PLAYED_PTR   BO3_VA(0x3C838Cu, 0x3C86ACu)   /* the profile's time played */
#define HR_PLAYED_DT    BO3_VA(0x4AE1FCu, 0x4AE51Cu)   /* what the time played gains a step */
#define HR_VIEW_PTR     BO3_VA(0x4D6520u, 0x4D6840u)   /* the view being drawn */
#define HR_RACE_VIEW    BO3_VA(0x4D6200u, 0x4D6520u)   /* the race's view */
#define HR_HIT_PAD      BO3_VA(0x4AE20Cu, 0x4AE52Cu)   /* the pad manager's records */
#define HR_RACE_CLOCK   BO3_VA(0x60EA20u, 0x60ED30u)   /* the race clock, s */
#define HR_STEP_TIME    BO3_VA(0x60EA1Cu, 0x60ED2Cu)   /* a step's time on that clock */
#define HR_SPARK_HIST   BO3_VA(0x5492B0u, 0x5495D0u)   /* the streaks' history, 0x5A0 a player */
#define HR_SPARK_LIFE   BO3_VA(0x418EFCu, 0x41922Cu)   /* the first spark descriptor's life (+ 0x5C) */
#define HR_MARKER       BO3_VA(0x735550u, 0x735860u)   /* the marker object */
#define HR_D3D_PUSH     BO3_VA(0x35FB48u, 0x35FE48u)   /* D3D's push buffer put pointer */

/* The effects manager and the race world (src/game/hirefresh.c, the
 * sparks' descriptors and the effects' systems). */
#define HR_EFFECTS      BO3_VA(0x5A9A00u, 0x5A9D10u)   /* the effects manager (+4 a duration, +8 a mode) */
#define HR_WORLD        BO3_VA(0x60EA00u, 0x60ED10u)   /* the race world (the marker is at + 0x126B50) */
#define HR_AUDIT_TABLE  BO3_VA(0x3B1684u, 0x3B19A4u)   /* the race end's duration, s */

/* The rival marker's distances and slots (src/game/main.c). */
#define HR_RIVAL_NEAR   BO3_VA(0x60E560u, 0x60E870u)   /* the marker's near distance */
#define HR_RIVAL_FAR    BO3_VA(0x60E540u, 0x60E850u)   /* the marker's far distance */
#define HR_RIVAL_SLOTS  BO3_VA(0x5A3758u, 0x5A3A78u)   /* the marker's slots */

/* The scenes and the HUD (src/game/main.c). */
#define HR_SCENE_FE     BO3_VA(0x557A20u, 0x557D40u)   /* the front end's scene */
#define HR_SCENE_TRAX   BO3_VA(0x45BAD0u, 0x45BDF0u)   /* the EA Trax scene */
#define HR_HUD_SCENE_1  BO3_VA(0x54F914u, 0x54FC34u)   /* player 1's HUD scene */
#define HR_HUD_SCENE_2  BO3_VA(0x54F984u, 0x54FCA4u)   /* player 2's HUD scene */
#define HR_TRACK        BO3_VA(0x7397B4u, 0x739AC4u)   /* the track in play */

/* The guest functions the upstream's new code calls or names. */
#define HR_FN_SWAP       BO3_SUB(sub_00350DB0, sub_003510B0)  /* D3D's swap */
#define HR_FN_PLAYER_FRM BO3_SUB(sub_00167940, sub_00167BE0)  /* a player's cameras */
#define HR_FN_SPARK_HIST BO3_SUB(sub_00038200, sub_000383C0)  /* the sparks' history */
#define HR_FN_SPARK_DRAW BO3_SUB(sub_000367C0, sub_00036980)  /* a spark system's streaks */
#define HR_FN_RACE_AUDIO BO3_SUB(sub_0013EF40, sub_0013F1E0)  /* the race audio */
#define HR_FN_FX_CLOCK   BO3_SUB(sub_00188750, sub_00188A50)  /* the effects clock */

/* The guest functions the upstream's main.c compares a callback
 * against (each the same function of the same size). The callback is a
 * guest address, so the pair is a pair of addresses. */
#define HR_CB_2D_OBJECT  BO3_VA(0x000F9CE0u, 0x000FA040u)
#define HR_CB_CRASH_NAV  BO3_VA(0x000D77A0u, 0x000D7B00u)
#define HR_CB_FRONT_END  BO3_VA(0x000FB900u, 0x000FBC60u)
#define HR_CB_NAV_MARK   BO3_VA(0x0005AC20u, 0x0005ADD0u)
#define HR_CB_OBJECT     BO3_VA(0x001C0790u, 0x001C0AB0u)
#define HR_CB_FE_OBJECT  BO3_VA(0x001C1A60u, 0x001C1D80u)
#define HR_CB_2D_SCENE   BO3_VA(0x001C51A0u, 0x001C54C0u)
#define HR_CB_HUD        BO3_VA(0x001C5330u, 0x001C5650u)

/* The soundtrack's start source (src/game/recomp/recomp_manual.c). */
#define HR_FN_SOUND_SRC  BO3_SUB(sub_00155420, sub_001556C0)

#endif
