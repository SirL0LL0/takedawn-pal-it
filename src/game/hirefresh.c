/*
 * hirefresh.c - pictures between the simulation's steps.
 *
 * graphics.high_refresh (overlay Graphics page, "High refresh rate";
 * RECOMP_GFX_HIGH_REFRESH): frames at the display's refresh rate, the
 * simulation at its own 60 steps a second. Only with graphics.crash_60fps
 * and graphics.split_60fps on as well (the overlay locks the row until they
 * are): the title's own 30 Hz phases would otherwise be run by this clock
 * at 60 while it asks for 30. Active while the game is in its running state
 * (the game object's state, 0x4D53B4, is 5: the front end, races, the pause
 * menu); the other states (loads, the stage's set-up and hand-overs) step
 * once a frame by their own code (Update's jump table, 0x16CC8) and keep
 * flips at 60. The rate is the display's the window is on (the toolkit's
 * xbox_DisplayRate), or RECOMP_FLIP_PACING=host:<Hz> for a run without a
 * display; the toolkit holds each flip to a host grid at it
 * (xbox_FlipHostRate). Five wraps (recomp/recomp_manual.c).
 *
 * 1. The steps of a frame. CB3Game::Update (sub_000165F0) runs the steps
 *    in the word at 0x4D53AC (game object 0x4A71A0 + 0x2E20C), which the
 *    stepper sub_001B58E0 at the end of the previous frame chose: at least
 *    1 (the call site's minimum, 0x16C2D), so a host flipping faster than
 *    60 runs the game fast. The step loop itself (0x16AB6) skips a count
 *    of 0. The title's clock cannot simply be given a minimum of 0: its
 *    period (timer 0x4D5338 + 0x20, 733.33 MHz ticks) is 1/60 s in a stage
 *    but 1/30 s in the front end, where the minimum alone makes 60 steps a
 *    second (with a minimum of 0 the menus ran at 30.00), it counts no time
 *    before its first step (0x1B58FB), and a paused race holds it (+0x34),
 *    when it returns the minimum every frame: the pause menu, which runs in
 *    the steps (the stage's update is skipped while a player has paused,
 *    0x16BA1), ran at 142 steps a second at 175 Hz. So the title's stepper
 *    runs as shipped and its count is not used: at the start of Update the
 *    count is the steps a 1/60 s accumulator on the host clock holds, in
 *    every mode of the title's timer, 0 when it holds none, at most the
 *    frame's maximum (4, 8 at the half rate). The menus' mode 2 keeps the
 *    lag beyond the cap, as the title does; the others drop it. Deciding at
 *    the start of the frame rather than at the end of the last leaves less
 *    than one step of lag at the picture, which is what the interpolation
 *    below needs.
 *
 * 2. The picture between two steps. RenderWare 3.7's _rwFrameSyncDirty
 *    (sub_001E15E0; RwCameraBeginUpdate, sub_001D91B0, calls it before the
 *    device builds the view from the camera frame's LTM) walks the dirty
 *    roots at 0x75935C (each frame's +0x08 link) and brings their LTMs
 *    (+0x50, an RwMatrix: right, flags, up, at, pos) up to date. After it,
 *    the LTM of every frame under those roots is taken as the frame's state
 *    at the global step count (0x4A1EB4), the one before kept; and every
 *    frame that moved at the last step gets, in place, its two states
 *    blended at the picture's time, one step behind the clock: the lag left
 *    after the frame's steps, in steps. Position by lerp, the axes by lerp
 *    and Gram-Schmidt at their lerped lengths. A move of more than
 *    SNAP_DIST a step or an axis turned more than ~45 degrees (a camera
 *    cut, a reset, a frame whose address was reused) is not blended.
 *    Everything the frame draws or reads after that (the camera's view,
 *    the atomics, a particle placed on a car) sees the blend. At the start
 *    of the next Update, before any step, the blends are put back to the
 *    true LTMs, so the simulation never reads one: skipped where the LTM no
 *    longer holds what was written (the frame is gone or was synced again).
 *
 * 3. The HUD (sub_000535E0, stdcall, its one argument the time to advance
 *    by) is updated once a frame with one step's time, MEMF(0x4AE1FC), not
 *    once a step (docs/crash60.md): at 144 flips a second its animations
 *    ran 2.4 times fast. Its time is that value times the frame's wall
 *    time over 1/60 s.
 *
 * Not blended: what is not on a frame (particles, skid marks, the
 * deformed car body's vertices), which moves once a step.
 *
 * The addresses above are the two discs' (region.h): the NTSC-U one first,
 * the PAL one second. The five wraps are in the manual file of the disc:
 * recomp/recomp_manual.c (NTSC-U) and recomp/recomp_manual_pal.c (PAL),
 * where each definition names the NTSC-U function on its line.
 */
#include "hirefresh.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <time.h>
#endif

#include "recomp_types.h"
#include "platform/recomp_env.h"
#include "kernel/kernel_pacing.h"
#include "region.h"                   /* BO3_VA: the disc's addresses */

#define STEP_S       (1.0 / 60.0)
/* The guest's own addresses, the two discs' (region.h): the NTSC-U one
 * first, the PAL one second. The PAL executable is the same program built
 * again: its data sits a little further on. The shift is not the same
 * everywhere: +0x320 in the game object (the code that calls Update pushes
 * 0x4A74C0 there) and at the end of .data (RenderWare's dirty frame list,
 * the player's car), +0x300 in the rest. Each address was checked against
 * the PAL disassembly: the code that reads it names that address. */
#define TIMER        BO3_VA(0x4D5338u, 0x4D5658u)   /* the stepper's timer object */
#define FRAME_STEPS  BO3_VA(0x4D53ACu, 0x4D56CCu)   /* steps this frame's Update runs */
#define HALF_RATE    BO3_VA(0x4D538Eu, 0x4D56AEu)   /* the half rate in force */
#define STEP_COUNT   BO3_VA(0x4A1EB4u, 0x4A21B4u)   /* global step counter */
#define GAME_STATE   BO3_VA(0x4D53B4u, 0x4D56D4u)   /* the game object's state, 5 running */
#define DIRTY_HEAD   BO3_VA(0x75935Cu, 0x75967Cu)   /* RenderWare's dirty frame list */
#define PLAYER_CAR   BO3_VA(0x0073A1D0u, 0x0073A4F0u)  /* player 1's car */
#define FRAME_LTM    0x50u
#define FRAME_CHILD  0x98u
#define FRAME_NEXT   0x9Cu

#define SNAP_DIST    8.0f          /* world units a step */
#define SNAP_DOT     0.7f          /* cos of the largest turn a step */

#define REC_N        32768u        /* power of two */
#define WALK_MAX     4096u

typedef struct {
    uint32_t key;                  /* the frame's address, 0 free */
    uint32_t sp, sc;               /* the step counts of prev and cur */
    uint32_t put_gen, put;         /* its s_put entry, while put_gen is s_put_gen */
    float    prev[16], cur[16];
} rec_t;

static rec_t    s_rec[REC_N];
static uint32_t s_live[REC_N];     /* records whose cur is the last step's */
static unsigned s_live_n;
static uint32_t s_live_step;
static struct { uint32_t va; float wrote[16], cur[16]; } s_put[REC_N];
static unsigned s_put_n;
static uint32_t s_put_gen = 1;
static unsigned s_rec_used;

static int      s_active;          /* this frame's steps are ours */
static double   s_rate;            /* the flips' rate while active, Hz */
static int      s_rendering;       /* a camera has begun since Update */
static double   s_lag;             /* seconds the clock is ahead of the steps */

static int env_on(recomp_env_id id)
{
    const char *v = recomp_env(id);
    return v && *v && strcmp(v, "0") != 0;
}

/* The rate to draw at, 0 for the title's 60: the setting and the two it
 * needs on, a display faster than 60, and the game in its running state. */
static double wanted_rate(void)
{
    static double env_hz = -1.0;
    double hz;

    if (!env_on(RENV_GFX_HIGH_REFRESH) || !env_on(RENV_GFX_CRASH_60FPS)
            || !env_on(RENV_GFX_SPLIT_60FPS) || MEM32(GAME_STATE) != 5)
        return 0.0;
    if (env_hz < 0.0) {
        const char *e = recomp_env(RENV_FLIP_PACING);
        env_hz = e && !strncmp(e, "host:", 5) ? atof(e + 5) : 0.0;
    }
    hz = env_hz > 0.0 ? env_hz : xbox_DisplayRate();
    return hz > 61.0 && hz <= 1000.0 ? hz : 0.0;
}

static double host_s(void)
{
#ifdef _WIN32
    LARGE_INTEGER c, f;
    QueryPerformanceCounter(&c);
    QueryPerformanceFrequency(&f);
    return (double)c.QuadPart / (double)f.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
}

static float *ltm(uint32_t frame)
{
    return (float *)(uintptr_t)XBOX_PTR(frame + FRAME_LTM);
}

/* ── 1. The steps ─────────────────────────────────────────── */

static void restore_blends(void)
{
    unsigned i;

    for (i = 0; i < s_put_n; i++) {
        float *m = ltm(s_put[i].va);
        if (!memcmp(m, s_put[i].wrote, sizeof s_put[i].wrote))
            memcpy(m, s_put[i].cur, sizeof s_put[i].cur);
    }
    s_put_n = 0;
    s_put_gen++;
}

/* A frame's time as the pictures will show it. Update runs ahead of the
 * flip that shows its picture by however far the GPU thread is behind,
 * which is not the same every frame (3.7 to 10.6 ms between Updates at
 * 144 Hz): the wall time between Updates moved the car 0.85 to 1.15 times
 * its average a picture. The pictures go out on the flip grid, so the
 * time is taken in whole flip periods, and the difference from the wall
 * clock is carried and given back once it is half a period. */
static double frame_time(double dt, double p, int restart)
{
    static double owe;
    double q;

    if (restart)
        owe = 0.0;
    q = floor(dt / p + 0.5) * p;
    owe += dt - q;
    if (owe > p * 0.5 || owe < -p * 0.5) {
        q += owe;
        owe = 0.0;
    }
    return q > 0.0 ? q : 0.0;
}

void bo3_update(bo3_hirefresh_fn title_fn)
{
    static double last;
    double now = host_s(), rate = wanted_rate(), dt = now - last;
    int steps, was = s_active;
    uint32_t max;

    if (getenv("BO3_HIREFRESH_DEBUG")) {
        static double t0;
        if (t0 == 0.0)
            t0 = now;
        if (now - t0 >= 1.0) {
            t0 = now;
            fprintf(stderr, "[HIREFRESH] state=%u high=%d crash=%d split=%d flip=%s "
                            "display=%d rate=%.1f\n",
                    MEM32(GAME_STATE), env_on(RENV_GFX_HIGH_REFRESH),
                    env_on(RENV_GFX_CRASH_60FPS), env_on(RENV_GFX_SPLIT_60FPS),
                    recomp_env(RENV_FLIP_PACING) ? recomp_env(RENV_FLIP_PACING) : "(none)",
                    xbox_DisplayRate(), rate);
        }
    }

    restore_blends();
    s_rendering = 0;
    xbox_FlipHostRate(rate);
    if (rate != s_rate)
        fprintf(stderr, "[HIREFRESH] %s\n", rate > 0.0 ? "on" : "off");
    if (rate <= 0.0) {
        s_active = 0;
        s_rate = 0.0;
        last = now;
        title_fn();
        return;
    }
    if (!was || rate != s_rate)
        s_lag = STEP_S;                    /* one step at once, then the clock */
    else if (dt > 0.0 && dt < 1.0)        /* a second's stall is no lag */
        s_lag += frame_time(dt, 1.0 / rate, 0);
    if (!was)
        frame_time(0.0, 1.0 / rate, 1);
    s_rate = rate;
    max = MEM8(HALF_RATE) ? 8u : 4u;
    steps = (int)(s_lag / STEP_S);
    if (steps > (int)max) {
        steps = (int)max;
        if (MEM32(TIMER) != 2)
            s_lag = steps * STEP_S + fmod(s_lag, STEP_S);
    }
    s_lag -= steps * STEP_S;
    if (s_lag < 0.0)
        s_lag = 0.0;
    MEM32(FRAME_STEPS) = (uint32_t)steps;
    s_active = 1;
    last = now;
    title_fn();
}

/* ── 2. The picture between steps ─────────────────────────── */

/* BO3_HIREFRESH_STATS=1: a line a second of what was blended. */
static struct { unsigned syncs, blended, live; double umin, umax, t0; uint32_t step0; } s_stat
    = { 0, 0, 0, 1.0, 0.0, 0.0, 0 };

static void stats(uint32_t step)
{
    static int on = -1;
    double now;

    if (on < 0)
        on = getenv("BO3_HIREFRESH_STATS") != NULL;
    if (!on)
        return;
    s_stat.syncs++;
    if (s_live_n > s_stat.live)
        s_stat.live = s_live_n;
    now = host_s();
    if (s_stat.t0 == 0.0) {
        s_stat.t0 = now;
        s_stat.step0 = step;
    }
    if (now - s_stat.t0 >= 1.0) {
        fprintf(stderr, "[HIREFRESH] %.0f syncs/s, %u steps, moving frames <= %u, blends %u,"
                        " u %.2f..%.2f, records %u\n", s_stat.syncs / (now - s_stat.t0),
                step - s_stat.step0, s_stat.live, s_stat.blended,
                s_stat.blended ? s_stat.umin : 0.0, s_stat.umax, s_rec_used);
        memset(&s_stat, 0, sizeof s_stat);
        s_stat.umin = 1.0;
        s_stat.t0 = now;
        s_stat.step0 = step;
    }
}

static rec_t *rec_get(uint32_t va)
{
    uint32_t h = (va >> 2) * 2654435761u, i, n;

    for (n = 0; n < REC_N; n++) {
        i = (h + n) & (REC_N - 1);
        if (s_rec[i].key == va)
            return &s_rec[i];
        if (s_rec[i].key == 0) {
            if (s_rec_used >= REC_N / 4 * 3)
                return NULL;
            s_rec_used++;
            s_rec[i].key = va;
            return &s_rec[i];
        }
    }
    return NULL;
}

/* Frames come and go with every stage: the table is started again when
 * three quarters full, at a step's first sync (a picture of no blends). */
static void rec_reset_if_full(void)
{
    if (s_rec_used < REC_N / 4 * 3 - WALK_MAX)
        return;
    memset(s_rec, 0, sizeof s_rec);
    s_rec_used = 0;
    s_live_n = 0;
}

static void capture(uint32_t va, uint32_t step)
{
    rec_t *r = rec_get(va);
    const float *m = ltm(va);

    if (!r)
        return;
    /* A root synced again without its LTMs (0x1E1595) still holds the
     * blend written into it: that is no new state. */
    if (r->put_gen == s_put_gen && !memcmp(m, s_put[r->put].wrote, sizeof r->cur))
        return;
    if (r->sc == 0 && r->sp == 0) {
        memcpy(r->prev, m, sizeof r->prev);
        r->sp = step;
    } else if (r->sc != step) {
        memcpy(r->prev, r->cur, sizeof r->prev);
        r->sp = r->sc;
    }
    if (r->sc != step && s_live_n < REC_N)
        s_live[s_live_n++] = (uint32_t)(r - s_rec);
    memcpy(r->cur, m, sizeof r->cur);
    r->sc = step;
}

static void walk(uint32_t root, uint32_t step)
{
    uint32_t stack[64], f;
    unsigned sp = 0, n = 0;

    capture(root, step);
    if ((f = MEM32(root + FRAME_CHILD)) != 0)
        stack[sp++] = f;
    while (sp && n++ < WALK_MAX) {
        f = stack[--sp];
        capture(f, step);
        if (MEM32(f + FRAME_NEXT) && sp < 64)
            stack[sp++] = MEM32(f + FRAME_NEXT);
        if (MEM32(f + FRAME_CHILD) && sp < 64)
            stack[sp++] = MEM32(f + FRAME_CHILD);
    }
}

static float dot3(const float *a, const float *b)
{
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

/* m = prev..cur at u: lerped axes made orthogonal again (Gram-Schmidt in
 * the order right, up, at) at their lerped lengths; 0 when it should snap. */
static int blend(const rec_t *r, float u, float *m)
{
    float ax[3][3], len[3];
    int a, k;

    {
        float d[3] = { r->cur[12] - r->prev[12], r->cur[13] - r->prev[13],
                       r->cur[14] - r->prev[14] };
        float lim = SNAP_DIST * (float)(r->sc - r->sp);
        if (dot3(d, d) > lim * lim)
            return 0;
    }
    for (a = 0; a < 3; a++) {
        const float *p = r->prev + a * 4, *c = r->cur + a * 4;
        float lp = sqrtf(dot3(p, p)), lc = sqrtf(dot3(c, c));
        if (lp < 1e-6f || lc < 1e-6f || dot3(p, c) < SNAP_DOT * lp * lc)
            return 0;
        for (k = 0; k < 3; k++)
            ax[a][k] = p[k] + (c[k] - p[k]) * u;
        len[a] = lp + (lc - lp) * u;
    }
    for (a = 0; a < 3; a++) {
        int b;
        float l;
        for (b = 0; b < a; b++) {
            float d = dot3(ax[a], ax[b]);
            for (k = 0; k < 3; k++)
                ax[a][k] -= d * ax[b][k];
        }
        l = sqrtf(dot3(ax[a], ax[a]));
        if (l < 1e-6f)
            return 0;
        for (k = 0; k < 3; k++)
            ax[a][k] /= l;
    }
    memcpy(m, r->cur, 16 * sizeof *m);    /* flags and pads as they are */
    for (a = 0; a < 3; a++)
        for (k = 0; k < 3; k++)
            m[a * 4 + k] = ax[a][k] * len[a];
    for (k = 0; k < 3; k++)
        m[12 + k] = r->prev[12 + k] + (r->cur[12 + k] - r->prev[12 + k]) * u;
    return 1;
}

/* Write the record's blend at the picture's time (one step behind the
 * clock) into its frame's LTM, if it moved at the last step. */
/* m = the record's state at the picture's time (one step behind the
 * clock); 0 when it did not move at the last step or should snap. */
static int blend_now(const rec_t *r, uint32_t step, float *m)
{
    double t = (double)step - 1.0 + s_lag / STEP_S, u;

    if (r->sc != step || r->sp >= r->sc || r->sc - r->sp > 4)
        return 0;
    u = (t - (double)r->sp) / (double)(r->sc - r->sp);
    if (u >= 1.0)
        return 0;
    if (u < 0.0)
        u = 0.0;
    if (!blend(r, (float)u, m))
        return 0;
    s_stat.blended++;
    if (u < s_stat.umin) s_stat.umin = u;
    if (u > s_stat.umax) s_stat.umax = u;
    return 1;
}

static void apply(rec_t *r, uint32_t step)
{
    float m[16];
    unsigned k;

    if (!blend_now(r, step, m))
        return;
    if (r->put_gen == s_put_gen) {
        k = r->put;
    } else {
        if (s_put_n == REC_N)
            return;
        k = s_put_n++;
        r->put_gen = s_put_gen;
        r->put = k;
        s_put[k].va = r->key;
    }
    memcpy(s_put[k].cur, r->cur, sizeof r->cur);
    memcpy(ltm(r->key), m, sizeof m);
    memcpy(s_put[k].wrote, m, sizeof m);
}

static void step_changed(uint32_t step)
{
    if (step != s_live_step) {
        s_live_n = 0;
        s_live_step = step;
        rec_reset_if_full();
    }
}

void bo3_frame_sync_dirty(bo3_hirefresh_fn title_fn)
{
    uint32_t roots[WALK_MAX], l, step;
    unsigned n = 0, i;

    if (!s_active) {
        title_fn();
        return;
    }
    for (l = MEM32(DIRTY_HEAD); l != DIRTY_HEAD && l && n < WALK_MAX; l = MEM32(l))
        roots[n++] = l - 8;
    title_fn();

    step = MEM32(STEP_COUNT);
    step_changed(step);
    s_rendering = 1;
    for (i = 0; i < n; i++)
        walk(roots[i], step);
    if (!s_active) {
        stats(step);
        return;
    }

    for (i = 0; i < s_live_n; i++)
        apply(&s_rec[s_live[i]], step);
    stats(step);
}

/* RwFrameGetLTM (sub_001DD280, cdecl, the frame): what the render
 * pipelines ask for. The cars are posed by writing their LTMs, not through
 * the dirty list, so they are taken and blended here, when drawn. Only
 * while a picture is drawn: the simulation's own calls get the truth. */
void bo3_frame_get_ltm(bo3_hirefresh_fn title_fn)
{
    uint32_t frame = MEM32(g_esp + 4), step;
    rec_t *r;

    title_fn();
    if (!s_active || !s_rendering || !frame)
        return;
    step = MEM32(STEP_COUNT);
    step_changed(step);
    capture(frame, step);
    r = rec_get(frame);
    if (r)
        apply(r, step);
}

/* sub_000303D0 (stdcall: draw context, matrix, model), the vehicles' draw:
 * CB3RaceCar::Draw (sub_0018DE00) and CB3TrafficSystem::Draw (sub_001A4710)
 * hand it the vehicle's own world matrix (car + 0x10, the RwMatrix layout;
 * the LOD test reads its position at + 0x30). The vehicles are not frames:
 * they are taken and blended here, the blend written for the one call and
 * the true matrix put back after it, as the title itself does when it draws
 * a car with another matrix (+0x19AB, 0x18DEF2). */
/* BO3_HIREFRESH_TRACE=<file>: player 1's car as drawn, once a picture
 * (host time, step count, position), to see the motion between steps. */
static void trace_car(uint32_t mat, const float *m)
{
    static FILE *f;
    static int on = -1;
    static uint32_t last_flip_step;
    static double last_t;
    double now;

    if (on < 0) {
        const char *e = getenv("BO3_HIREFRESH_TRACE");
        on = e && *e && (f = fopen(e, "w")) != NULL;
        if (on)
            setvbuf(f, NULL, _IOLBF, 0);
    }
    if (!on || mat != PLAYER_CAR + 0x10u)
        return;
    now = host_s();
    if (now - last_t < 0.002 && last_flip_step == MEM32(STEP_COUNT))
        return;              /* the same picture's other passes */
    last_t = now;
    last_flip_step = MEM32(STEP_COUNT);
    fprintf(f, "%.6f %u %.4f %.4f %.4f\n", now, MEM32(STEP_COUNT), m[12], m[13], m[14]);
}

void bo3_draw_vehicle(bo3_hirefresh_fn title_fn)
{
    uint32_t mat = MEM32(g_esp + 8), step;
    float m[16], keep[16], *g;
    rec_t *r;

    if (!s_active || !mat) {
        title_fn();
        return;
    }
    step = MEM32(STEP_COUNT);
    step_changed(step);
    g = (float *)(uintptr_t)XBOX_PTR(mat);
    {
        /* capture() keys an LTM at frame + 0x50; this one is the matrix. */
        uint32_t key = mat - FRAME_LTM;
        capture(key, step);
        r = rec_get(key);
    }
    if (!r || !blend_now(r, step, m)) {
        trace_car(mat, g);
        title_fn();
        return;
    }
    memcpy(keep, g, sizeof keep);
    memcpy(g, m, sizeof m);
    trace_car(mat, m);
    title_fn();
    if (!memcmp(g, m, sizeof m))
        memcpy(g, keep, sizeof keep);
}

/* ── 3. The HUD ───────────────────────────────────────────── */

void bo3_hud_update(bo3_hirefresh_fn title_fn)
{
    static double last;
    double now, dt;

    if (s_active) {
        now = host_s();
        dt = last > 0.0 ? now - last : STEP_S;
        last = now;
        if (dt > 0.1)          /* a load or a stall: one step's time, as shipped */
            dt = STEP_S;
        MEMF(g_esp + 4) = (float)(MEMF(g_esp + 4) * dt * 60.0);
    }
    title_fn();
}
