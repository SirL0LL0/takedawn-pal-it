/*
 * hirefresh.h - pictures between the simulation's steps (hirefresh.c).
 */
#ifndef BO3_HIREFRESH_H
#define BO3_HIREFRESH_H

typedef void (*bo3_hirefresh_fn)(void);

/* The wraps of recomp/recomp_manual.c; each runs the title's body as
 * shipped unless graphics.high_refresh is in force (hirefresh.c). */

/* sub_000165F0, CB3Game::Update: the blends of the last picture put back,
 * then the frame's steps by a 1/60 s clock (0 allowed). */
void bo3_update(bo3_hirefresh_fn title_fn);

/* sub_001E15E0, RenderWare's _rwFrameSyncDirty: the LTMs of what moved
 * taken, and blended in place between the last two steps. */
void bo3_frame_sync_dirty(bo3_hirefresh_fn title_fn);

/* sub_001DD280, RwFrameGetLTM: the frames the pipelines draw taken, and
 * blended, while a picture is drawn. */
void bo3_frame_get_ltm(bo3_hirefresh_fn title_fn);

/* sub_000303D0, the vehicles' draw: each vehicle's matrix blended for the
 * call. */
void bo3_draw_vehicle(bo3_hirefresh_fn title_fn);

/* sub_000535E0, the HUD's update: its time follows the frame's wall time. */
void bo3_hud_update(bo3_hirefresh_fn title_fn);

#endif
