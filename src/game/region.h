/* region.h - the build's disc: North America (NTSC-U, the default) or
 * Europe (PAL, -DBO3_REGION=PAL).
 *
 * The two default.xbe are one program built twice: the PAL code sits a few
 * hundred bytes further on, its data a little more. Every guest address
 * the port's own C names is written once with both values,
 *
 *     #define CTL_PADS  BO3_VA(0x004AE20Cu, 0x004AE52Cu)
 *     BO3_SUB(sub_001D2879, sub_001D2B99)();
 *
 * the NTSC-U one first (the one the notes and comments speak of), and the
 * build picks one; both are constants, so they stay usable in static
 * initialisers. The PAL values come from tools/region/xbemap.py (the two
 * executables aligned, each site checked), as do config/pal/. */
#ifndef BO3_REGION_H
#define BO3_REGION_H

#if defined(BO3_REGION_PAL) && BO3_REGION_PAL
#define BO3_VA(ntsc, pal)  (pal)
#define BO3_SUB(ntsc, pal) pal
#define BO3_REGION_NAME    "PAL"
/* The EEPROM's language number, in the numbering the PAL executable uses.
 *
 * The two executables number the languages differently: the NTSC-U one
 * reads the console's encoding (0=Japanese, 1=English, 2=German, 3=French,
 * 4=Spanish, 5=Italian, ...), the PAL one its own (2=Japanese, 3=German,
 * 4=French, 5=Spanish, 6=Italian, ...). The title looks the number up in
 * its own table, so the number the EEPROM carries has to be the one the
 * title's table knows. */
#define BO3_LANGUAGE_ENCODING "pal"
/* The game's language a start asks for when the player has chosen none and
 * the disc has it (disclang.h): this build is the Italian one. */
#define BO3_LANGUAGE_DEFAULT  "italian"
#else
#define BO3_VA(ntsc, pal)  (ntsc)
#define BO3_SUB(ntsc, pal) ntsc
#define BO3_REGION_NAME    "NTSC-U"
#define BO3_LANGUAGE_ENCODING "ntsc"
#define BO3_LANGUAGE_DEFAULT  "english"
#endif

#endif
