@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@pushd "%~dp0" || (
   @ECHO [HBNum] Could not enter mk directory.
   @endlocal & exit /b 1
)

@FOR /F "delims=" %%F IN ('dir /b /a:-d /on "*.bat"') DO (
   @IF /I NOT "%%~nxF"=="%~nx0" (
      @ECHO.
      @ECHO [HBNum] Running %%~nxF
      @cmd /d /q /c "%%~fF"
      @IF ERRORLEVEL 1 (
         @ECHO.
         @ECHO [HBNum] %%~nxF failed.
         @popd
         @endlocal & exit /b 1
      )
   )
)

@ECHO.
@ECHO [HBNum] All batch scripts completed.
@popd
@endlocal & exit /b 0
