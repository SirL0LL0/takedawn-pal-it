Takedawn @VERSION@ for Windows (x64) - the European disc

Windows 10 or 11, 64-bit, and a graphics driver with Vulkan (any current
AMD, Intel or NVIDIA driver). LEGGIMI.txt is this file in Italian.

Game data
  Takedawn needs the game's data from your own disc: a disc image
  (.iso / .xiso) or an extracted disc folder of Burnout 3: Takedown,
  @DISC@. It checks every file and copies them to
  %LOCALAPPDATA%\Takedawn PAL\Game. From a terminal:

      Takedawn.exe --install <image-or-folder>

Languages
  Open the settings (Back and Start, or F1): the first page has two
  languages.
  - Game language: the game's text, speech and films. Only the languages
    on your disc are offered; the European disc has French, German and
    Italian. The game starts in Italian until you choose another. A change
    shows after a restart.
  - Interface language: the settings menu and Takedawn's messages:
    English (the default), French, German or Italian. It changes at once.

Where things are
  %LOCALAPPDATA%\Takedawn PAL    game data, shader cache
  %APPDATA%\Takedawn PAL         saves, settings, logs
  An update (a newer package over this one) leaves both folders alone.

How to update
  1. Close Takedawn.
  2. Extract the new package and copy it over the old one: the program and
     the DLLs are replaced; the saves, the settings, the game data and the
     shader cache (the two folders above) stay.

First start
  Takedawn is not code-signed. When it is started for the first time,
  Windows SmartScreen may say "Windows protected your PC": choose
  "More info", then "Run anyway".

The licences of everything inside are in the licenses folder.
