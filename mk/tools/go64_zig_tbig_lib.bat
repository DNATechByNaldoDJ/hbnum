@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@where zig.exe >NUL 2>NUL
@IF ERRORLEVEL 1 (
   @ECHO [HBNum/Zig][tBig] zig.exe was not found in PATH.
   @ECHO [HBNum/Zig][tBig] Confirm with: zig version
   @endlocal & exit /b 1
)

@IF NOT DEFINED HB_ZIG_ROOT SET "HB_ZIG_ROOT=C:\GitHub\naldodj-harbour-core"
@IF NOT DEFINED HB_ZIG_TARGET SET "HB_ZIG_TARGET=x86_64-windows-gnu"
@IF NOT DEFINED HB_ZIG_LIBDIR SET "HB_ZIG_LIBDIR=%HB_ZIG_ROOT%\lib\win\mingw64"
@IF NOT DEFINED HB_ZIG_BINDIR SET "HB_ZIG_BINDIR=%HB_ZIG_ROOT%\bin\win\mingw64"
@IF NOT DEFINED HB_ZIG_INCDIR SET "HB_ZIG_INCDIR=%HB_ZIG_ROOT%\include"
@IF NOT DEFINED TBIG_ZIG_ROOT SET "TBIG_ZIG_ROOT=C:\GitHub\tBigNumber"
@IF NOT DEFINED TBIG_ZIG_OUTDIR SET "TBIG_ZIG_OUTDIR=%TBIG_ZIG_ROOT%\lib\win\mingw64"

@SET "HB_ZIG_HBRUN=%HB_ZIG_BINDIR%\hbrun.exe"
@SET "HB_ZIG_HBMK2_PRG=%HB_ZIG_ROOT%\utils\hbmk2\hbmk2.prg"
@SET "TBIG_ZIG_HBP=%TBIG_ZIG_ROOT%\hbp\_tbigNumber.hbp"
@SET "TBIG_ZIG_OUTPUT=%TBIG_ZIG_OUTDIR%\lib_tbigNumber.a"
@SET "TBIG_ZIG_OUTPUT_BASE=%TBIG_ZIG_OUTDIR%\_tbigNumber"

@IF NOT EXIST "%HB_ZIG_HBRUN%" (
   @ECHO [HBNum/Zig][tBig] Missing hbrun.exe: %HB_ZIG_HBRUN%
   @ECHO [HBNum/Zig][tBig] Set HB_ZIG_ROOT to a Harbour checkout with bin\win\mingw64\hbrun.exe.
   @endlocal & exit /b 1
)

@IF NOT EXIST "%HB_ZIG_HBMK2_PRG%" (
   @ECHO [HBNum/Zig][tBig] Missing hbmk2.prg: %HB_ZIG_HBMK2_PRG%
   @ECHO [HBNum/Zig][tBig] Set HB_ZIG_ROOT to a Harbour checkout whose hbmk2.prg supports -comp=zig.
   @endlocal & exit /b 1
)

@IF NOT EXIST "%HB_ZIG_LIBDIR%" (
   @ECHO [HBNum/Zig][tBig] Missing Harbour lib directory: %HB_ZIG_LIBDIR%
   @ECHO [HBNum/Zig][tBig] Set HB_ZIG_LIBDIR to a Harbour lib\win\mingw64-style directory.
   @endlocal & exit /b 1
)

@IF NOT EXIST "%HB_ZIG_INCDIR%" (
   @ECHO [HBNum/Zig][tBig] Missing Harbour include directory: %HB_ZIG_INCDIR%
   @ECHO [HBNum/Zig][tBig] Set HB_ZIG_INCDIR to a Harbour include directory.
   @endlocal & exit /b 1
)

@IF NOT EXIST "%TBIG_ZIG_ROOT%" (
   @ECHO [HBNum/Zig][tBig] Missing tBigNumber root: %TBIG_ZIG_ROOT%
   @ECHO [HBNum/Zig][tBig] Set TBIG_ZIG_ROOT to your tBigNumber checkout.
   @endlocal & exit /b 1
)

@IF NOT EXIST "%TBIG_ZIG_HBP%" (
   @ECHO [HBNum/Zig][tBig] Missing tBigNumber hbp: %TBIG_ZIG_HBP%
   @endlocal & exit /b 1
)

@IF NOT EXIST "%TBIG_ZIG_OUTDIR%" (
   @ECHO [HBNum/Zig][tBig] Missing tBigNumber output directory: %TBIG_ZIG_OUTDIR%
   @ECHO [HBNum/Zig][tBig] Set TBIG_ZIG_OUTDIR to an existing output directory.
   @endlocal & exit /b 1
)

@pushd "%TBIG_ZIG_ROOT%\mk" || (
   @ECHO [HBNum/Zig][tBig] Could not enter tBigNumber mk directory.
   @endlocal & exit /b 1
)

@IF EXIST "%TBIG_ZIG_OUTPUT%" DEL /Q "%TBIG_ZIG_OUTPUT%"
@IF ERRORLEVEL 1 (
   @ECHO [HBNum/Zig][tBig] Could not delete %TBIG_ZIG_OUTPUT%.
   @popd
   @endlocal & exit /b 1
)
@IF EXIST "%TBIG_ZIG_OUTPUT%" (
   @ECHO [HBNum/Zig][tBig] Could not delete %TBIG_ZIG_OUTPUT%.
   @popd
   @endlocal & exit /b 1
)

@FOR /F "delims=" %%V IN ('zig version') DO @SET "ZIG_VERSION=%%V"
@ECHO [HBNum/Zig][tBig] Zig version: %ZIG_VERSION%
@ECHO [HBNum/Zig][tBig] HB_ZIG_ROOT: %HB_ZIG_ROOT%
@ECHO [HBNum/Zig][tBig] HB_ZIG_TARGET: %HB_ZIG_TARGET%
@ECHO [HBNum/Zig][tBig] HB_ZIG_LIBDIR: %HB_ZIG_LIBDIR%
@ECHO [HBNum/Zig][tBig] TBIG_ZIG_ROOT: %TBIG_ZIG_ROOT%
@ECHO [HBNum/Zig][tBig] TBIG_ZIG_OUTDIR: %TBIG_ZIG_OUTDIR%
@ECHO [HBNum/Zig][tBig] Building external tBigNumber library with Zig

@SET "HB_INSTALL_BIN=%HB_ZIG_BINDIR%"
@SET "HB_INSTALL_LIB=%HB_ZIG_LIBDIR%"
@SET "HB_INSTALL_INC=%HB_ZIG_INCDIR%"
@REM tBigNumber embeds C++ code via BEGINDUMP inside a generated .c unit, so
@REM Zig 0.16 needs the language forced explicitly instead of inferring from .c.
@REM It also expects LDBL_DIG from float.h. Additional warning suppressions
@REM keep the Zig/Clang build quiet around upstream GCC/MinGW-oriented flags.
@"%HB_ZIG_HBRUN%" "%HB_ZIG_HBMK2_PRG%" "%TBIG_ZIG_HBP%" -plat=win -cpu=x86_64 -jobs=10 -cpp -compr=no -comp=zig -xhb "-cflag=-x" "-cflag=c++" "-cflag=-include" "-cflag=float.h" "-cflag=-Wno-unknown-warning-option" "-cflag=-Wno-macro-redefined" "-cflag=-Wno-nullability-completeness" "-i%HB_ZIG_ROOT%\contrib\xhb" "-o%TBIG_ZIG_OUTPUT_BASE%"
@IF ERRORLEVEL 1 (
   @ECHO [HBNum/Zig][tBig] External tBigNumber Zig build failed.
   @popd
   @endlocal & exit /b 1
)

@IF NOT EXIST "%TBIG_ZIG_OUTPUT%" (
   @ECHO [HBNum/Zig][tBig] Build finished but expected output is missing: %TBIG_ZIG_OUTPUT%
   @popd
   @endlocal & exit /b 1
)

@ECHO [HBNum/Zig][tBig] External tBigNumber Zig build completed.
@popd
@endlocal & exit /b 0
