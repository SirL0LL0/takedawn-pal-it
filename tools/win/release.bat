@echo off
rem A release build on Windows, without a bash shell: the same steps as
rem tools/release/build-windows.sh, in the order it does them.
rem
rem   1. the icon (assets/icon/takedawn.svg -> takedawn.ico), for the
rem      executable's resource and for the package
rem   2. the stamp of the generated code (src/game/recomp/gen/regen.stamp),
rem      which a release build refuses a tree without
rem   3. the configure and the build, with -DBO3_RELEASE=ON
rem
rem The program folder and the zip are made by tools\win\package.py.
rem
rem Environment:
rem   BO3_WINDEPS     the deps prefix (default %LOCALAPPDATA%\bo3-windeps)
rem   XBOXRECOMP_DIR  the toolkit checkout (default ..\xboxrecomp)
rem   BO3_REGION      NTSC-U (default) or PAL (the European disc)
rem   PYTHON          the Python to use (default: py -3, else python)
rem   BUILD_DIR       the build folder (default build\release)
rem   JOBS            the parallel jobs (default: the processor count)
rem
rem Output: <BUILD_DIR>\bin\Takedawn.exe

setlocal EnableDelayedExpansion
set "BO3=%~dp0..\.."
for %%I in ("%BO3%") do set "BO3=%%~fI"

if not defined BO3_WINDEPS set "BO3_WINDEPS=%LOCALAPPDATA%\bo3-windeps"
for %%I in ("%BO3_WINDEPS%") do set "D=%%~fI"

if not defined XBOXRECOMP_DIR set "XBOXRECOMP_DIR=%BO3%\..\xboxrecomp"
for %%I in ("%XBOXRECOMP_DIR%") do set "TK=%%~fI"
if not exist "%TK%\src\kernel\kernel_xbox.c" (
    echo toolkit checkout not found at "%TK%" -- set XBOXRECOMP_DIR >&2
    exit /b 1
)

if not defined PYTHON (
    where py >nul 2>&1 && set "PYTHON=py -3" || set "PYTHON=python"
)
rem The renderer for the icon and for the button prompts: a Python that has
rem the resvg_py module, or the resvg program on the PATH. A release build
rem stops without one.
set "RENDERER="
for %%P in ("%PYTHON%" python python3 py) do (
    if not defined RENDERER (
        for /f "usebackq delims=" %%E in (`%%P -c "import resvg_py,sys; print(sys.executable)" 2^>nul`) do set "RENDERER=%%E"
    )
)
if not defined RENDERER (
    echo no SVG renderer: install resvg-py in the Python ^(pip install resvg-py^) >&2
    echo or install resvg or rsvg-convert, or set PYTHON to a Python that has it >&2
    exit /b 1
)
echo ==^> renderer: %RENDERER%
if not defined BO3_REGION set "BO3_REGION=NTSC-U"
if not defined BUILD_DIR set "BUILD_DIR=%BO3%\build\release"
for %%I in ("%BUILD_DIR%") do set "B=%%~fI"
if not defined JOBS set "JOBS=%NUMBER_OF_PROCESSORS%"

rem The tools: cmake and ninja, in the deps prefix or on the PATH.
set "CMAKE="
set "NINJA="
if exist "%D%\cmake\bin\cmake.exe" set "CMAKE=%D%\cmake\bin\cmake.exe"
if exist "%D%\ninja\ninja.exe" set "NINJA=%D%\ninja\ninja.exe"
if not defined CMAKE for %%C in (cmake.exe) do if not "%%~$PATH:C"=="" set "CMAKE=%%~$PATH:C"
if not defined NINJA for %%N in (ninja.exe) do if not "%%~$PATH:N"=="" set "NINJA=%%~$PATH:N"
if not defined CMAKE (echo cmake not found; set BO3_WINDEPS or put it on the PATH >&2 & exit /b 1)
if not defined NINJA (echo ninja not found; set BO3_WINDEPS or put it on the PATH >&2 & exit /b 1)
if not exist "%D%\llvm-mingw\bin\x86_64-w64-mingw32-clang.exe" (
    echo the toolchain is not at "%D%\llvm-mingw" -- run tools\win\fetch-deps.sh >&2
    exit /b 1
)

rem 1. The icon: the SVG at the sizes an icon holds, then the .ico.
echo ==^> icon
if not exist "%B%\icon" mkdir "%B%\icon"
"%RENDERER%" "%BO3%\tools\win\render-icon.py" "%BO3%\assets\icon\takedawn.svg" "%B%\icon" || exit /b 1
%PYTHON% "%BO3%\tools\release\make_ico.py" "%B%\takedawn.ico" ^
    "%B%\icon\16.png" "%B%\icon\24.png" "%B%\icon\32.png" "%B%\icon\48.png" ^
    "%B%\icon\64.png" "%B%\icon\128.png" "%B%\icon\256.png" || exit /b 1

rem 2. The stamp of the generated code.
echo ==^> stamp
set "XBOXRECOMP_DIR=%TK%"
set "CMAKE=%CMAKE%"
set "BO3_REGION=%BO3_REGION%"
%PYTHON% "%BO3%\tools\win\regen-stamp.py" --root "%BO3%" --toolkit "%TK%" ^
    --cmake "%CMAKE%" --region "%BO3_REGION%" || exit /b 1

rem 3. The configure and the build.
echo ==^> configure
"%CMAKE%" -S "%BO3%" -B "%B%\build" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DBO3_RELEASE=ON -DBO3_REGION="%BO3_REGION%" ^
  -DCMAKE_TOOLCHAIN_FILE="%BO3%\cmake\llvm-mingw-x86_64.cmake" ^
  -DLLVM_MINGW_ROOT="%D%\llvm-mingw" ^
  -DXBOXRECOMP_DIR="%TK%" ^
  -DBO3_BIN_DIR="%B%\bin" -DBO3_WIN_ICON="%B%\takedawn.ico" ^
  -DCMAKE_MAKE_PROGRAM="%NINJA%" ^
  -DCMAKE_PREFIX_PATH="%D%\SDL2\x86_64-w64-mingw32;%D%\glslang" ^
  -DVulkan_INCLUDE_DIR="%D%\vulkan\include" ^
  -DVulkan_LIBRARY="%D%\vulkan\lib\libvulkan-1.dll.a" ^
  -DXBOXRECOMP_ENHANCE=ON ^
  -DXBOXRECOMP_OVERLAY=ON ^
  -DXBOXRECOMP_BUILD_TESTS=OFF ^
  -DBO3_GLYPHS_PYTHON="%RENDERER%"
if errorlevel 1 exit /b 1

echo ==^> build
"%CMAKE%" --build "%B%\build" --target burnout3 -j%JOBS%
if errorlevel 1 exit /b 1

echo ==^> done: %B%\bin\Takedawn.exe
