@echo off
rem Regenerate the recompiled C from default.xbe with the xboxrecomp toolkit,
rem on Windows, without a bash shell. The same stages, the same order and the
rem same options as regen.sh (which is the reference).
rem
rem   xbe_parser    section layout -> build\xr\analysis.json
rem   disasm        ALL code sections, never --text-only
rem   func_id       library-function identification (CRT, XDK)
rem   abi_analysis  calling convention / params / return type
rem   recomp        emits the C into src\game\recomp\gen (gitignored)
rem
rem Nothing here is committed output: build\ and gen\ are regenerable from the
rem user's own default.xbe.
rem
rem Usage: tools\win\regen.bat [--disasm]
rem
rem Environment:
rem   XBOXRECOMP_DIR  the toolkit checkout (default ..\xboxrecomp)
rem   BO3_REGION      NTSC-U (default) or PAL (the European disc)
rem   PYTHON          the Python to use (default: py -3, else python)
rem   PATCHES         the patch list (default config\patches.json; empty: none)
rem   SPIN_WAITS      the spin-wait list (default config\spin_waits.json)
rem
rem BO3_REGION=PAL translates the European disc's default.xbe instead: the
rem seed, spin-wait and patch lists of config\pal\ and
rem src\game\recomp\recomp_manual_pal.c. Build it with -DBO3_REGION=PAL.

setlocal EnableDelayedExpansion
set "BO3=%~dp0..\.."
for %%I in ("%BO3%") do set "BO3=%%~fI"

rem The toolkit: XBOXRECOMP_DIR, else a sibling xboxrecomp.
if not defined XBOXRECOMP_DIR set "XBOXRECOMP_DIR=%BO3%\..\xboxrecomp"
for %%I in ("%XBOXRECOMP_DIR%") do set "XBOXRECOMP_DIR=%%~fI"
if not exist "%XBOXRECOMP_DIR%\tools\recomp" (
    echo missing the toolkit at "%XBOXRECOMP_DIR%" -- set XBOXRECOMP_DIR >&2
    exit /b 1
)

rem The Python: the launcher, else python.
if not defined PYTHON (
    where py >nul 2>&1 && set "PYTHON=py -3" || set "PYTHON=python"
)

set "XBE=%BO3%\Burnout 3 Takedown\default.xbe"
if not exist "%XBE%" (
    echo missing "%XBE%" -- extract it from your own disc image >&2
    exit /b 1
)

rem The region's lists.
set "CFG=%BO3%\config"
set "MANUAL=%BO3%\src\game\recomp\recomp_manual.c"
if /i "%BO3_REGION%"=="PAL" (
    set "CFG=%BO3%\config\pal"
    set "MANUAL=%BO3%\src\game\recomp\recomp_manual_pal.c"
) else if not "%BO3_REGION%"=="" if /i not "%BO3_REGION%"=="NTSC-U" if /i not "%BO3_REGION%"=="ntsc-u" if /i not "%BO3_REGION%"=="ntsc" if /i not "%BO3_REGION%"=="ntsc" (
    echo BO3_REGION must be NTSC-U or PAL >&2
    exit /b 1
)

set "OUT=%BO3%\build\xr"
if not exist "%OUT%" mkdir "%OUT%"

rem The optional lists: the seeds, the spin waits, the patches.
set "SEEDS="
if exist "%CFG%\seed_functions.json" set "SEEDS=--seed-functions "%CFG%\seed_functions.json""
if not defined SPIN_WAITS set "SPIN_WAITS=%CFG%\spin_waits.json"
set "SPIN="
if not "%SPIN_WAITS%"=="" if exist "%SPIN_WAITS%" set "SPIN=--spin-waits "%SPIN_WAITS%""
if not defined PATCHES set "PATCHES=%CFG%\patches.json"
set "PATCH="
if not "%PATCHES%"=="" if exist "%PATCHES%" set "PATCH=--patches "%PATCHES%""

rem The stages run from the toolkit dir: its tools are the package.
pushd "%XBOXRECOMP_DIR%"

if "%~1"=="--disasm" if not exist "%OUT%\disasm\functions.json" goto :disasm
if not exist "%OUT%\disasm\functions.json" goto :disasm
goto :func_id

:disasm
echo ==^> xbe_parser
%PYTHON% -m tools.xbe_parser "%XBE%" --json "%OUT%\analysis.json" --quiet || goto :fail

echo ==^> disasm
%PYTHON% -m tools.disasm "%XBE%" --analysis-json "%OUT%\analysis.json" %SEEDS% -o "%OUT%\disasm" -v > "%OUT%\disasm.log" 2>&1
if errorlevel 1 (
    type "%OUT%\disasm.log"
    goto :fail
)

:func_id
echo ==^> func_id
%PYTHON% -m tools.func_id "%XBE%" --functions "%OUT%\disasm\functions.json" --strings "%OUT%\disasm\strings.json" --xrefs "%OUT%\disasm\xrefs.json" -o "%OUT%\func_id" || goto :fail

echo ==^> abi_analysis
%PYTHON% -m tools.abi_analysis "%XBE%" --functions "%OUT%\disasm\functions.json" --identified "%OUT%\func_id\identified_functions.json" --output-dir "%OUT%\abi" || goto :fail

echo ==^> recomp
%PYTHON% -m tools.recomp "%XBE%" --all --split 1000 --disasm-dir "%OUT%\disasm" --func-id-dir "%OUT%\func_id" --abi-dir "%OUT%\abi" --exclude-manual "%MANUAL%" %SPIN% %PATCH% --gen-dir "%BO3%\src\game\recomp\gen" -o "%OUT%\recomp" > "%OUT%\recomp.log" 2>&1
if errorlevel 1 (
    echo !! recomp failed -- gen\ is now STALE >&2
    type "%OUT%\recomp.log" >&2
    goto :fail
)

popd
echo ==^> done. Now: tools\win\build.bat
exit /b 0

:fail
popd
exit /b 1
