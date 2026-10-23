/* The PAL build's wrapped functions: recomp_manual.c's, at the PAL
 * default.xbe's addresses (tools/region/xbemap.py; each the same function,
 * of the same size, as the NTSC-U one it stands for). regen.sh hands this
 * file to the recompiler as --exclude-manual when BO3_REGION=PAL, and
 * src/game/CMakeLists.txt compiles it only then. What each one does is in
 * recomp_manual.c. Each definition names its NTSC-U function on its line:
 * tools/region/check.py pairs them. */
#if defined(BO3_REGION_PAL) && BO3_REGION_PAL
#include <stdint.h>
#include "../soundtrack.h"
#include "../dsound_notify.h"
#include "../soundbank.h"

/* Custom music (BO-108): NTSC-U sub_001D0554, sub_0030211F, sub_001537C0. */
extern void sub_001D0874_gen(void);
extern void sub_0030241F_gen(void);
extern void sub_00153A60_gen(void);

void sub_001D0874(void) { bo3_soundtrack_open_song(sub_001D0874_gen); }   /* NTSC-U sub_001D0554 */
void sub_0030241F(void) { bo3_soundtrack_create_decoder(sub_0030241F_gen); }   /* NTSC-U sub_0030211F */
void sub_00153A60(void) { bo3_soundtrack_start_track(sub_00153A60_gen); }   /* NTSC-U sub_001537C0 */

/* The title's "start the music of the source chosen" (BO-230): the one place
 * the chosen soundtrack is read, and the one place a start switches it. */
extern void sub_001556C0_gen(void);

void sub_001556C0(void) { bo3_soundtrack_start_source(sub_001556C0_gen); }   /* NTSC-U sub_00155420 */

/* DirectSound's "voice done" (BO-173): NTSC-U sub_002FAAEF. */
extern void sub_002FADEF_gen(void);

void sub_002FADEF(void) { bo3_dsound_voice_done(sub_002FADEF_gen); }   /* NTSC-U sub_002FAAEF */

/* A sound bank that did not load (BO-218): NTSC-U sub_001F65A0. */
extern void sub_001F6890_gen(void);

void sub_001F6890(void) { bo3_wave_dict_count(sub_001F6890_gen); }   /* NTSC-U sub_001F65A0 */

/* Pictures between the simulation's steps (../hirefresh.c): the frame's
 * steps, RenderWare's frame sync, the vehicles' draw and the HUD's time.
 * As shipped unless graphics.high_refresh is in force. The PAL twins of
 * the NTSC-U functions (each the same function, of the same size). */
#include "../hirefresh.h"

extern void sub_000166B0_gen(void);
extern void sub_001E1900_gen(void);
extern void sub_001DD5A0_gen(void);
extern void sub_00030590_gen(void);
extern void sub_00053790_gen(void);
extern void sub_003510B0_gen(void);
extern void sub_00167BE0_gen(void);
extern void sub_000383C0_gen(void);
extern void sub_00036980_gen(void);
extern void sub_0013F1E0_gen(void);
extern void sub_00188A50_gen(void);

void sub_000166B0(void) { bo3_update(sub_000166B0_gen); }   /* NTSC-U sub_000165F0 */
void sub_001E1900(void) { bo3_frame_sync_dirty(sub_001E1900_gen); }   /* NTSC-U sub_001E15E0 */
void sub_001DD5A0(void) { bo3_frame_get_ltm(sub_001DD5A0_gen); }   /* NTSC-U sub_001DD280 */
void sub_00030590(void) { bo3_draw_vehicle(sub_00030590_gen); }   /* NTSC-U sub_000303D0 */
void sub_00053790(void) { bo3_hud_update(sub_00053790_gen); }   /* NTSC-U sub_000535E0 */
void sub_003510B0(void) { bo3_swap(sub_003510B0_gen); }   /* NTSC-U sub_00350DB0 */
void sub_00167BE0(void) { bo3_player_frame(sub_00167BE0_gen); }   /* NTSC-U sub_00167940 */
void sub_000383C0(void) { bo3_spark_history(sub_000383C0_gen); }   /* NTSC-U sub_00038200 */
void sub_00036980(void) { bo3_spark_draw(sub_00036980_gen); }   /* NTSC-U sub_000367C0 */
void sub_0013F1E0(void) { bo3_race_audio(sub_0013F1E0_gen); }   /* NTSC-U sub_0013EF40 */
void sub_00188A50(void) { bo3_fx_clock(sub_00188A50_gen); }   /* NTSC-U sub_00188750 */
#endif
