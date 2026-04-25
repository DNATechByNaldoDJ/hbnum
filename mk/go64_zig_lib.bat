@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@IF NOT DEFINED HBNUM_ZIG_ENABLE SET "HBNUM_ZIG_ENABLE=1"
@SET "HB_ROOT=%~dp0.."
@SET "HB_OUT_DIR=%HB_ROOT%\lib\win\zig"
@IF NOT EXIST "%HB_OUT_DIR%" MKDIR "%HB_OUT_DIR%"

@call "%~dp0tools\go64_zig_build.bat" "%~dp0" "%HB_ROOT%\hbp\hbnum.hbp" "%HB_OUT_DIR%\libhbnum.a" "libhbnum.a"
@endlocal & exit /b %ERRORLEVEL%
