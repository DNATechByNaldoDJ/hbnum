@setlocal
@REM hbnum: Released to Public Domain.

@REM Prefer Git for Windows over Cygwin Git to avoid hook/check issues on Windows.
@SET "PATH=C:\Program Files\Git\cmd;%PATH%"
@SET HB_RUN_PATH="F:\harbour_msvc\bin\win\msvc64\hbrun.exe"

@%HB_RUN_PATH% ..\bin\commit.hb --check-only
@IF ERRORLEVEL 1 (
   @ECHO [HBNum] Harbour commit check failed.
   @endlocal & exit /b 1
)

@ECHO [HBNum] Harbour commit check passed.
@endlocal & exit /b 0
