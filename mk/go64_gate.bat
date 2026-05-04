@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

SET "HB_ROOT=%~dp0.."
SET "HB_OUT_DIR=%HB_ROOT%\exe\win\msvc64"

IF NOT DEFINED HBNUM_TEST_PROFILE SET "HBNUM_TEST_PROFILE=gate"

ECHO [HBNum] Validation gate started.
ECHO [HBNum] Profile: %HBNUM_TEST_PROFILE%

CALL "%~dp0go64_lib.bat"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Library build failed.
   endlocal & exit /b 1
)

CALL "%~dp0go64_test.bat"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Unit test executable build failed.
   endlocal & exit /b 1
)

CALL "%~dp0go64_robust.bat"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Robustness executable build failed.
   endlocal & exit /b 1
)

CALL "%~dp0go64_bench.bat"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Benchmark executable build failed.
   endlocal & exit /b 1
)

IF /I "%HBNUM_GATE_SKIP_TBIG%"=="1" (
   ECHO [HBNum] Skipping comparative tBigNumber build because HBNUM_GATE_SKIP_TBIG=1.
) ELSE (
   CALL "%~dp0go64_bench_tbig.bat"
   IF ERRORLEVEL 1 (
      ECHO [HBNum] Comparative benchmark executable build failed.
      endlocal & exit /b 1
   )
)

CALL :RunStep "unit tests" "%HB_OUT_DIR%\hbnum_test.exe"
IF ERRORLEVEL 1 (
   endlocal & exit /b 1
)

CALL :RunStep "robustness tests" "%HB_OUT_DIR%\hbnum_robust.exe"
IF ERRORLEVEL 1 (
   endlocal & exit /b 1
)

CALL :RunStep "HBNum benchmark smoke" "%HB_OUT_DIR%\hbnum_bench.exe"
IF ERRORLEVEL 1 (
   endlocal & exit /b 1
)

IF /I "%HBNUM_GATE_SKIP_TBIG%"=="1" (
   ECHO [HBNum] Skipping comparative tBigNumber run because HBNUM_GATE_SKIP_TBIG=1.
) ELSE (
   CALL :RunStep "comparative tBigNumber smoke" "%HB_OUT_DIR%\hbnum_bench_tbig.exe"
   IF ERRORLEVEL 1 (
      endlocal & exit /b 1
   )
)

CALL "%~dp0go64_commit_check.bat"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Commit check failed.
   endlocal & exit /b 1
)

ECHO.
ECHO [HBNum] VALIDATION: PASS
endlocal & exit /b 0

:RunStep
ECHO.
ECHO [HBNum] Running %~1.
IF NOT EXIST "%~2" (
   ECHO [HBNum] Missing executable: %~2
   exit /b 1
)
"%~2"
IF ERRORLEVEL 1 (
   ECHO [HBNum] %~1 failed.
   exit /b 1
)
exit /b 0
