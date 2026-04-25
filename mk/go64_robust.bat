@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

SET "HB_ROOT=%~dp0.."
SET "HB_OUT_DIR=%HB_ROOT%\exe\win\msvc64"
SET "HB_OUT=%HB_OUT_DIR%\hbnum_robust.exe"

IF NOT EXIST "%HB_OUT_DIR%" MKDIR "%HB_OUT_DIR%"
IF EXIST "%HB_OUT%" DEL /Q "%HB_OUT%"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Could not delete %HB_OUT%.
   endlocal & exit /b 1
)
IF EXIST "%HB_OUT%" (
   ECHO [HBNum] Could not delete %HB_OUT%.
   endlocal & exit /b 1
)

SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64
IF ERRORLEVEL 1 (
   ECHO [HBNum] vcvarsall.bat failed.
   endlocal & exit /b 1
)

%HB_BASE_PATH% "%HB_ROOT%\hbp\hbnum_robust.hbp" -comp=msvc64
IF ERRORLEVEL 1 (
   ECHO [HBNum] hbnum_robust.hbp build failed.
   endlocal & exit /b 1
)
endlocal & exit /b 0
