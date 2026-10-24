/* disclang.c - the languages the disc in use carries; see disclang.h. */
#include "disclang.h"
#include "region.h"

#include <ctype.h>
#include <dirent.h>
#include <string.h>

/* The toolkit's order (xbox_settings.c's k_language). */
enum { L_ENGLISH, L_FRENCH, L_GERMAN, L_ITALIAN, L_SPANISH, L_JAPANESE, L_KOREAN,
       L_CHINESE_T, L_CHINESE_S, L_PORTUGUESE, L_DUTCH, L_SWEDISH, L_COUNT };
static const char *const k_name[L_COUNT] = {
    "english", "french", "german", "italian", "spanish", "japanese", "korean",
    "chinese_traditional", "chinese_simplified", "portuguese", "dutch", "swedish"
};

/* The two letters of Data/Global<xx>.bin, as the executables name them
 * (the table at 0x3AA6D8 PAL): Us and En are English. */
static const struct { char s[3]; int lang; } k_suffix[] = {
    { "us", L_ENGLISH }, { "en", L_ENGLISH }, { "fr", L_FRENCH }, { "ge", L_GERMAN },
    { "it", L_ITALIAN }, { "sp", L_SPANISH }, { "ja", L_JAPANESE }, { "du", L_DUTCH },
    { "sw", L_SWEDISH },
};

/* What the executable can pick: the European one has German, Italian and
 * French (its fallback) only, whatever else is on the disc (its English
 * files are there, unread). */
#if defined(BO3_REGION_PAL) && BO3_REGION_PAL
#define REACHABLE ((1u << L_FRENCH) | (1u << L_GERMAN) | (1u << L_ITALIAN))
#else
#define REACHABLE (~0u)
#endif

unsigned bo3_disc_languages(const char *data_dir)
{
    DIR *d = opendir(data_dir);
    struct dirent *e;
    unsigned mask = 0;
    size_t i;

    if (!d)
        return 0;
    while ((e = readdir(d)) != NULL) {
        const char *n = e->d_name;
        char low[16];
        size_t k;
        /* Global<xx>.bin, any case: 12 characters. */
        if (strlen(n) != 12)
            continue;
        for (k = 0; k < 12; k++)
            low[k] = (char)tolower((unsigned char)n[k]);
        low[12] = 0;
        if (strncmp(low, "global", 6) || strcmp(low + 8, ".bin"))
            continue;
        for (i = 0; i < sizeof k_suffix / sizeof k_suffix[0]; i++)
            if (low[6] == k_suffix[i].s[0] && low[7] == k_suffix[i].s[1])
                mask |= 1u << k_suffix[i].lang;
    }
    closedir(d);
    return mask & REACHABLE;
}

const char *bo3_disc_language_default(unsigned mask, const char *want)
{
    int i;

    if (!mask)
        return want;
    for (i = 0; want && i < L_COUNT; i++)
        if (!strcmp(want, k_name[i]) && (mask & (1u << i)))
            return want;
    if (mask & (1u << L_ENGLISH))
        return k_name[L_ENGLISH];
    for (i = 0; i < L_COUNT; i++)
        if (mask & (1u << i))
            return k_name[i];
    return want;
}
