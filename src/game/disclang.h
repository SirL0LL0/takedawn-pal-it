/* disclang.h - the languages the disc in use carries, for the overlay's
 * game language (xbox_SettingsSetLanguages) and the language a start without
 * one asks for.
 *
 * The game picks its text by the dashboard's language (sub_00017470 PAL,
 * docs/language.md): Data/Global<xx>.bin and Data/Head<xx>.bin, the speech
 * and the films of that language. A language is offered when its text file
 * is on the disc and the executable has a way to it: the European one has
 * German (3), Italian (6) and, for every other number, French; the North
 * American one opens the files of the number it reads. */
#ifndef BO3_DISCLANG_H
#define BO3_DISCLANG_H

/* Bit i for the dashboard's language i, in the toolkit's order (english,
 * french, german, italian, spanish, japanese, korean, chinese_traditional,
 * chinese_simplified, portuguese, dutch, swedish). `data_dir` is the
 * disc's Data folder. 0 when it cannot be read: then nothing is limited. */
unsigned bo3_disc_languages(const char *data_dir);

/* The language a start asks for when the player has chosen none: `want` when
 * the disc has it, else English, else the first the disc has; `want` too
 * when the mask is 0 (nothing known). */
const char *bo3_disc_language_default(unsigned mask, const char *want);

#endif
