# The dashboard's language

The Xbox dashboard had a language setting, and the game reads it at start-up
to pick its text, its speech and its films. Takedawn can answer it.

This checkout is the Italian one: the game's own text comes from the
European disc in Italian, and the interface Takedawn draws over it (the
settings overlay, the mixer's page, the installer's messages) is in Italian
too.

## The setting

`display.language` in `enhance.toml` (beside the program) names it:

```toml
[display]
language = "italian"
```

The names are the dashboard's: `english`, `french`, `german`, `italian`,
`spanish`, `japanese`, `korean`, `chinese_traditional`,
`chinese_simplified`, `portuguese`, `dutch`, `swedish`. The setting is in the
in-game overlay too (Back and Start, or F1: the Display page), and the
environment variable `RECOMP_XBOX_LANGUAGE` overrides the file.

The game reads the setting at start-up, so a change shows after a restart.

## The numbers, and why they differ

The console's EEPROM carries a number, not a name. The game reads the number
and looks it up in its own table, so the number that means "Italian" is the
one the game's table knows, and the two discs do not number the languages the
same way:

| code | NTSC-U (the console) | PAL (the European disc) |
|---|---|---|
| 0 | Japanese | - |
| 1 | English | English |
| 2 | German | Japanese |
| 3 | French | German |
| 4 | Spanish | French |
| 5 | **Italian** | Spanish |
| 6 | Korean | **Italian** |
| 7 | Chinese (traditional) | Korean |
| 8 | Chinese (simplified) | English |
| 9 | Portuguese | Portuguese |
| 10 | - | Dutch |
| 11 | - | Swedish |

The toolkit has the console's table, and a second one for the titles that
renumber the languages. The build says which one the game uses with
`RECOMP_XBOX_LANGUAGE_ENCODING` (`ntsc`, the console's, by default; `pal`, a
title that renumbers them). The PAL build sets it in `src/game/region.h`:

```c
#define BO3_LANGUAGE_ENCODING "pal"
```

Without it the toolkit would answer 5 (Italian in the console's numbering)
and the European game would look for Italian and find none, and fall back to
its own default, French.

## The European disc has no English

The PAL disc carries French, German and Italian. `Data/GlobalUs.bin` and
`Data/HeadUs.bin` are not on it. Asking for `english` on that disc makes the
game fall back to its default, the French one, because the file it would
open is not there.

What the game loads for Italian, from the log:

```
[PATH] \Device\CdRom0\Data\GlobalIt.bin      the text
[PATH] \Device\CdRom0\Data\HeadIt.bin        the font
[PATH] \Device\CdRom0\ovid\italia30.xmv      the voices
[PATH] \Device\CdRom0\ovid\Titles30.xmv      the films
```

## The interface

The words Takedawn draws are in Italian in this checkout: the settings
overlay (its pages, the rows and their descriptions, the choices, the notes
under the rows, the footer's key hints), the mixer's page, the update
check's messages, the shader pre-build's progress, the installer's help and
errors, and the fatal messages the game shows when it cannot start.

The machine-readable parts stay in English: the keys in `settings.toml`
(`nearest`, `linear`, `auto`, ...), the installer's line protocol
(`PROTOCOL`, `STEP`, `LOG`, `RESULT`) and the log lines. Those are formats
that a program parses, not words the player reads.

The toolkit carries the interface's Italian in
`src/overlay/overlay_ui.cpp`, `src/overlay/overlay_mixer.inc` and
`src/overlay/xbox_update.c`; the title's own messages are in
`src/game/install.c` and `src/game/main.c`.

## Where the code is

| What | Where |
|---|---|
| the EEPROM's answer | toolkit `src/kernel/kernel_xbox.c` (`xbox_SetLanguage`, `xbox_GetLanguage`) |
| the setting's name in the enhancements layer | toolkit `src/enhance/enhance_cfg.c` (`display.language`) |
| the setting in the in-game overlay | toolkit `src/overlay/xbox_settings.c` (`XS_DISPLAY_LANGUAGE`) |
| the game reads it and picks the files | `src/game/main.c` (`host_enhance_init`) |
| the numbering the game uses | `src/game/region.h` (`BO3_LANGUAGE_ENCODING`) |

The toolkit that carries this is the `takedawn` branch of
[SirL0LL0/xboxrecomp](https://github.com/SirL0LL0/xboxrecomp), a fork of
[xenophobentx/xboxrecomp](https://github.com/xenophobentx/xboxrecomp) with
the language added on top of `takedawn-0.2.0` (the tag
`takedawn-0.2.0-it`).

## How the game finds the number

The PAL executable keeps its own table of languages at `0x3A7BC4` and reads
it through `sub_00017470`, which opens `Data/GlobalIt.bin` and
`Data/HeadIt.bin` for the number 6 and the French ones for every other
number. The number itself is read from the EEPROM at the start-up
(`sub_000208E1`, `sub_001B5F60`).
