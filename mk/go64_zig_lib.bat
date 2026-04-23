@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@IF /I NOT "%HBNUM_ZIG_ENABLE%"=="1" (
   @ECHO [HBNum/Zig] Experimental Zig build skipped. Set HBNUM_ZIG_ENABLE=1 to run it.
   @endlocal & exit /b 0
)

@where zig.exe >NUL 2>NUL
@IF ERRORLEVEL 1 (
   @ECHO [HBNum/Zig] zig.exe was not found in PATH.
   @ECHO [HBNum/Zig] Confirm with: zig version
   @endlocal & exit /b 1
)

@IF NOT DEFINED HB_ZIG_ROOT SET "HB_ZIG_ROOT=C:\GitHub\naldodj-harbour-core"
@IF NOT DEFINED HB_ZIG_TARGET SET "HB_ZIG_TARGET=x86_64-windows-gnu"

@SET "HB_ZIG_HBRUN=%HB_ZIG_ROOT%\bin\win\mingw64\hbrun.exe"
@SET "HB_ZIG_HBMK2_PRG=%HB_ZIG_ROOT%\utils\hbmk2\hbmk2.prg"

@IF NOT EXIST "%HB_ZIG_HBRUN%" (
   @ECHO [HBNum/Zig] Missing hbrun.exe: %HB_ZIG_HBRUN%
   @ECHO [HBNum/Zig] Set HB_ZIG_ROOT to a Harbour checkout with bin\win\mingw64\hbrun.exe.
   @endlocal & exit /b 1
)

@IF NOT EXIST "%HB_ZIG_HBMK2_PRG%" (
   @ECHO [HBNum/Zig] Missing hbmk2.prg: %HB_ZIG_HBMK2_PRG%
   @ECHO [HBNum/Zig] Set HB_ZIG_ROOT to a Harbour checkout whose hbmk2.prg supports -comp=zig.
   @endlocal & exit /b 1
)

@pushd "%~dp0" || (
   @ECHO [HBNum/Zig] Could not enter mk directory.
   @endlocal & exit /b 1
)

@FOR /F "delims=" %%V IN ('zig version') DO @SET "ZIG_VERSION=%%V"
@ECHO [HBNum/Zig] Zig version: %ZIG_VERSION%
@ECHO [HBNum/Zig] HB_ZIG_ROOT: %HB_ZIG_ROOT%
@ECHO [HBNum/Zig] HB_ZIG_TARGET: %HB_ZIG_TARGET%

@"%HB_ZIG_HBRUN%" "%HB_ZIG_HBMK2_PRG%" hbnum.hbp -comp=zig
@IF ERRORLEVEL 1 (
   @ECHO [HBNum/Zig] Experimental Zig library build failed.
   @popd
   @endlocal & exit /b 1
)

@ECHO [HBNum/Zig] Experimental Zig library build completed.
@popd
@endlocal & exit /b 0
