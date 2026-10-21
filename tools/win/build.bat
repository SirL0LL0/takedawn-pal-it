@echo off
rem Build burnout3.exe (Windows x86-64, SDL2 + Vulkan) natively on Windows,
rem without a bash shell. The same CMake options as tools/win/build-mingw.sh
rem (which is the reference).
rem
rem   tools\win\build.bat [extra cmake -D options]
rem
rem Environment:
rem   BO3_WINDEPS    the deps prefix (default %LOCALAPPDATA%\bo3-windeps):
rem                   llvm-mingw\, SDL2\, vulkan\, glslang\
rem                   (tools\win\fetch-deps.sh makes it, from Git Bash or from
rem                   macOS or Linux)
rem   XBOXRECOMP_DIR the toolkit checkout (default ..\xboxrecomp)
rem   BO3_REGION     NTSC-U (default) or PAL (the European disc)
rem   BUILD_DIR      the build folder (default build\win)
rem   JOBS           the parallel jobs (default: the processor count)
rem
rem Output: bin\burnout3.exe, and SDL2.dll beside it.

setlocal EnableDelayedExpansion
set "BO3=%~dp0..\.."
for %%I in ("%BO3%") do set "BO3=%%~fI"

if not defined BO3_WINDEPS set "BO3_WINDEPS=%LOCALAPPDATA%\bo3-windeps"
for %%I in ("%BO3_WINDEPS%") do set "D=%%~fI"

rem The toolkit: XBOXRECOMP_DIR, else a sibling xboxrecomp.
if not defined XBOXRECOMP_DIR set "XBOXRECOMP_DIR=%BO3%\..\xboxrecomp"
for %%I in ("%XBOXRECOMP_DIR%") do set "TK=%%~fI"
if not exist "%TK%\src\kernel\kernel_xbox.c" (
    echo toolkit checkout not found at "%TK%" -- set XBOXRECOMP_DIR >&2
    exit /b 1
)

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

set "B=%BO3%\build\win"
if defined BUILD_DIR (
    for %%I in ("%BUILD_DIR%") do set "B=%%~fI"
)
if not defined JOBS set "JOBS=%NUMBER_OF_PROCESSORS%"

rem The region's option: PAL builds the European disc.
set "REGION=-DBO3_REGION=NTSC-U"
if /i "%BO3_REGION%"=="PAL" set "REGION=-DBO3_REGION=PAL"

"%CMAKE%" -S "%BO3%" -B "%B%" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_TOOLCHAIN_FILE="%BO3%\cmake\llvm-mingw-x86_64.cmake" ^
  -DLLVM_MINGW_ROOT="%D%\llvm-mingw" ^
  -DXBOXRECOMP_DIR="%TK%" ^
  -DCMAKE_MAKE_PROGRAM="%NINJA%" ^
  -DCMAKE_PREFIX_PATH="%D%\SDL2\x86_64-w64-mingw32;%D%\glslang" ^
  -DVulkan_INCLUDE_DIR="%D%\vulkan\include" ^
  -DVulkan_LIBRARY="%D%\vulkan\lib\libvulkan-1.dll.a" ^
  -DXBOXRECOMP_ENHANCE=ON ^
  -DXBOXRECOMP_OVERLAY=ON ^
  -DXBOXRECOMP_BUILD_TESTS=OFF ^
  %REGION% %*
if errorlevel 1 exit /b 1

"%CMAKE%" --build "%B%" --target burnout3 -j%JOBS%
if errorlevel 1 exit /b 1

if not exist "%BO3%\bin" mkdir "%BO3%\bin"
if exist "%D%\SDL2\x86_64-w64-mingw32\bin\SDL2.dll" copy /Y "%D%\SDL2\x86_64-w64-mingw32\bin\SDL2.dll" "%BO3%\bin\" >nul
echo ==^> done: %BO3%\bin\burnout3.exe
