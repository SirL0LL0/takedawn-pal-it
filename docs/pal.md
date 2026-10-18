# The PAL (Europe) build

Takedawn translates one exact `default.xbe`. Besides the North America
(NTSC-U) retail disc it can be built for the European (PAL) retail disc:

| Build | default.xbe SHA-256 | Manifest |
|---|---|---|
| `ntsc-u-retail` (default) | `9f497acd…4d13f9` | `config/disc/ntsc-u-retail.manifest` (716 files) |
| `pal-retail` | `6f7f6b46…7afa2` | `config/disc/pal-retail.manifest` (786 files) |

Both have the title id `0x4541005B`, so a profile moves between them as it
does between machines (copy `UDATA`). The PAL build keeps per-user folders
of its own, `Takedawn PAL` (`%APPDATA%\Takedawn PAL`, `%LOCALAPPDATA%\Takedawn
PAL\Game` on Windows), so it never mistakes the NTSC-U build's installed data
for its own and both can be installed side by side; it does not move the
port's old-name folders (`Burnout3`), which are NTSC-U's. The PAL disc carries the French,
German and Italian text, speech and films beside the English.

## Building it

```sh
BO3_REGION=PAL XBOXRECOMP_DIR=../xboxrecomp ./regen.sh --disasm
tools/win/build-mingw.sh -DBO3_REGION=PAL          # or any cmake build with -DBO3_REGION=PAL
```

with the PAL disc's `default.xbe` at `Burnout 3 Takedown/default.xbe`.
A release: `BO3_REGION=PAL tools/release/gen.sh`, then
`BO3_REGION=PAL tools/release/build-windows.sh` (and the other platforms'
scripts). The setup window names the PAL disc, and the Inno Setup script
takes `/DRegion=PAL`: "Takedawn PAL", its own folder, uninstall entry and
`Takedawn-<version>-pal-windows-x64-setup.exe`.
`regen.sh` then reads `config/pal/` and hands the recompiler
`src/game/recomp/recomp_manual_pal.c`; the build compiles in the PAL
manifest and picks the PAL addresses of the C (below).

## How the addresses were found

The PAL executable is the NTSC-U program built again: the same libraries,
the same game code, a few hundred bytes further on (`.text` +0x2F0 by its
end, the XDK sections +0x300, `.data` +0x320 with a few local differences,
and one function moved). `tools/region/xbemap.py` finds every address's
twin from the two executables alone:

- `.text`: both disassembled, each instruction reduced to its mnemonic and
  operands with absolute addresses blanked, the two lists aligned with
  `diff`. A matched instruction maps byte for byte. Branch targets of matched
  `call`/`jmp`/`jcc` pairs outvote the alignment (that is how the moved
  function, NTSC 0x1A8B0 = PAL 0x1B030, was found).
- data and bss: the absolute operands of matched instruction pairs (NTSC A
  was PAL B); an address nothing references takes the shift of its
  neighbours when both agree.
- the XDK sections moved as blocks.

`tools/region/port_config.py` writes `config/pal/*.json` from `config/*.json`
with it and checks each code site: the six instructions from the site must
read the same in both builds, with their absolute operands and branch
targets each other's translation. It reports anything that does not hold;
one site was read by hand (`REVIEWED` in the script).

```sh
python3 -m tools.region.port_config NTSC/default.xbe PAL/default.xbe
python3 -m tools.region.xbemap NTSC/default.xbe PAL/default.xbe 0x4D5370 0x1D2879
```

In the C, every guest address is written once with both values, NTSC-U
first (`src/game/region.h`):

```c
#define CTL_PADS  BO3_VA(0x004AE20Cu, 0x004AE52Cu)
BO3_SUB(sub_001D2879, sub_001D2B99)();
```

The notes and comments everywhere keep speaking of the NTSC-U addresses.
A change to `config/*.json` or to an address in `src/game` wants
`port_config.py` run again (or the PAL value written beside the new one).

## What stays the same

`Data/Global.txd`, `Data/Frontend.txd`, `sound/Fe.awd` and
`sound/Generic.awd` are the same files on both discs, and the menu fonts are
at the same offsets of both executables, so the overlay's art, sounds,
fonts and button prompts work unchanged.
