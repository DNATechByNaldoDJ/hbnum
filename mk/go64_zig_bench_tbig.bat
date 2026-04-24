@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@IF NOT DEFINED HBNUM_ZIG_ENABLE SET "HBNUM_ZIG_ENABLE=1"
@IF NOT DEFINED HBNUM_ZIG_TBIG_ENABLE SET "HBNUM_ZIG_TBIG_ENABLE=1"

@IF /I "%HBNUM_ZIG_TBIG_ENABLE%"=="1" (
   @call "%~dp0tools\go64_zig_tbig_lib.bat"
   @IF ERRORLEVEL 1 (
      @endlocal & exit /b 1
   )
)

@call "%~dp0tools\go64_zig_build.bat" "%~dp0" "hbnum_bench_tbig.hbp" ".\zig\hbnum_bench_tbig.exe" "hbnum_bench_tbig.exe"
@endlocal & exit /b %ERRORLEVEL%
