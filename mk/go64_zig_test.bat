@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@IF NOT DEFINED HBNUM_ZIG_ENABLE SET "HBNUM_ZIG_ENABLE=1"

@call "%~dp0tools\go64_zig_build.bat" "%~dp0" "hbnum_test.hbp" ".\zig\hbnum_test.exe" "hbnum_test.exe"
@endlocal & exit /b %ERRORLEVEL%
