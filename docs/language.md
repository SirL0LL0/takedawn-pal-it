# Languages

Two languages are set apart:

- the **game's language**: the Xbox dashboard's language setting, which the
  game reads at start-up to pick its text, its speech and its films;
- the **interface's language**: the words Takedawn itself shows, the
  settings overlay, the Mixer page and Takedawn's own messages.

Both are on the first page of the settings overlay (Back and Start, or F1:
Display > Interface language, Display > Game language).

## The game's language

`display.language` in `settings.toml` (the overlay writes it), or the
environment variable `RECOMP_XBOX_LANGUAGE`. The names are the dashboard's:
`english`, `french`, `german`, `italian`, `spanish`, `japanese`, `korean`,
`chinese_traditional`, `chinese_simplified`, `portuguese`, `dutch`,
`swedish`.

The game reads it at start-up, so a change shows after a restart (the row
says RESTART, and the foot of the page offers the restart).

### Only the disc's languages

The overlay offers only the languages the disc in use carries
(`src/game/disclang.c`). A language is offered when its text,
`Data/Global<xx>.bin`, is on the disc and the executable has a way to it:

| file | language |
|---|---|
| `GlobalUs.bin`, `GlobalEn.bin` | English |
| `GlobalFr.bin` | French |
| `GlobalGe.bin` | German |
| `GlobalIt.bin` | Italian |
| `GlobalSp.bin` | Spanish |
| `GlobalJa.bin` | Japanese |
| `GlobalDu.bin` | Dutch |
| `GlobalSw.bin` | Swedish |

The European executable picks only German, Italian and, for every other
number, French (`sub_00017470`, below): its disc carries `GlobalUs.bin` too,
but the game never opens it. So the European disc offers French, German and
Italian. The North American executable opens the files of the number it
reads, so there the files decide.

A start the player chose no language for asks for the build's own when the
disc has it (`BO3_LANGUAGE_DEFAULT` in `src/game/region.h`: Italian for the
European build, English for the North American one), else English, else the
first the disc has. The log says what was found:

```
[LANG] the disc's languages: 0x00e (Burnout 3 Takedown/Data)
```

(bit 0 English, 1 French, 2 German, 3 Italian, ... in the order of the list
above).

### The numbers, and why they differ

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

What the game loads for Italian, from the log:

```
[PATH] \Device\CdRom0\Data\GlobalIt.bin      the text
[PATH] \Device\CdRom0\Data\HeadIt.bin        the font
[PATH] \Device\CdRom0\ovid\italia30.xmv      the voices
[PATH] \Device\CdRom0\ovid\Titles30.xmv      the films
```

### How the game finds the number

The PAL executable keeps its own table of languages at `0x3A7BC4` and reads
it through `sub_00017470`, which opens `Data/GlobalGe.bin` and
`Data/HeadGe.bin` for the number 3, `Data/GlobalIt.bin` and
`Data/HeadIt.bin` for the number 6, and the French ones for every other
number. The number itself is read from the EEPROM at the start-up
(`sub_000208E1`, `sub_001B5F60`).

## The interface's language

`interface.language` in `settings.toml`, or `RECOMP_UI_LANGUAGE`: `english`
(the default), `french`, `german` or `italian`, the languages the overlay has
words in. It changes at once, with the overlay open.

The overlay is written in English, and every word a player reads goes
through `TR()` (the toolkit's `src/overlay/xbox_i18n.h`). The translations
are tables in the toolkit, one per language:

```
src/overlay/i18n/fr.inc
src/overlay/i18n/de.inc
src/overlay/i18n/it.inc
```

one `{ "English", "translation" },` pair a line. The English is the key; a
text a table does not have shows in English. `tools/i18n_check.py` (in the
toolkit) lists what each table lacks and checks that a translated format
has the same `%` conversions as its English:

```sh
python3 ../xboxrecomp/tools/i18n_check.py --also src/game/main.c
python3 ../xboxrecomp/tools/i18n_check.py --missing fr
```

The title's own messages that go through it are the fatal messages of a
start that fails after the settings were read (`BO3_TR` in
`src/game/main.c`). The installer's help and the messages of a start that
fails before (the data missing, `src/game/install.c`) stay English: the
settings are not read yet.

The machine-readable parts stay in English in every language: the keys in
`settings.toml` (`nearest`, `linear`, `auto`, ...), the installer's line
protocol (`PROTOCOL`, `STEP`, `LOG`, `RESULT`) and the log lines.

The overlay's fonts cover Latin-1, so the accents show, capitals included
(the labels are drawn in capitals: `caps()` in `overlay_ui.cpp` raises the
Latin-1 letters too).

## Where the code is

| What | Where |
|---|---|
| the EEPROM's answer | toolkit `src/kernel/kernel_xbox.c` (`xbox_SetLanguage`, `xbox_GetLanguage`) |
| the two settings | toolkit `src/overlay/xbox_settings.c` (`XS_DISPLAY_LANGUAGE`, `XS_INTERFACE_LANGUAGE`, `xbox_SettingsSetLanguages`) |
| the rows and the disc's choices | toolkit `src/overlay/overlay_ui.cpp` (`n_language`, `adjust`) |
| the translations | toolkit `src/overlay/xbox_i18n.c`, `src/overlay/i18n/*.inc` |
| the disc's languages, the default | `src/game/disclang.c`, `src/game/main.c` |
| the numbering the game uses | `src/game/region.h` (`BO3_LANGUAGE_ENCODING`, `BO3_LANGUAGE_DEFAULT`) |

The toolkit that carries this is the `takedawn` branch of
[SirL0LL0/xboxrecomp](https://github.com/SirL0LL0/xboxrecomp), a fork of
[xenophobentx/xboxrecomp](https://github.com/xenophobentx/xboxrecomp).
