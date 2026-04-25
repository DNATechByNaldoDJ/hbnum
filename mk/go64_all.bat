@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

@pushd "%~dp0" || (
   @ECHO [HBNum] Could not enter mk directory.
   @endlocal & exit /b 1
)

@FOR /F "delims=" %%F IN ('dir /b /a:-d /on "*.bat"') DO (
   @IF /I NOT "%%~nxF"=="%~nx0" (
      @IF /I "%%~nF"=="go64_zig_lib" (
         @IF /I NOT "%HBNUM_ZIG_ENABLE%"=="1" (
            @ECHO.
            @ECHO [HBNum] Skipping %%~nxF because HBNUM_ZIG_ENABLE is not 1.
         ) ELSE (
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
      ) ELSE @IF /I "%%~nF"=="go64_zig_test" (
         @IF /I NOT "%HBNUM_ZIG_ENABLE%"=="1" (
            @ECHO.
            @ECHO [HBNum] Skipping %%~nxF because HBNUM_ZIG_ENABLE is not 1.
         ) ELSE (
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
      ) ELSE @IF /I "%%~nF"=="go64_zig_robust" (
         @IF /I NOT "%HBNUM_ZIG_ENABLE%"=="1" (
            @ECHO.
            @ECHO [HBNum] Skipping %%~nxF because HBNUM_ZIG_ENABLE is not 1.
         ) ELSE (
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
      ) ELSE @IF /I "%%~nF"=="go64_zig_bench" (
         @IF /I NOT "%HBNUM_ZIG_ENABLE%"=="1" (
            @ECHO.
            @ECHO [HBNum] Skipping %%~nxF because HBNUM_ZIG_ENABLE is not 1.
         ) ELSE (
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
      ) ELSE @IF /I "%%~nF"=="go64_zig_bench_tbig" (
         @IF /I NOT "%HBNUM_ZIG_ENABLE%"=="1" (
            @ECHO.
            @ECHO [HBNum] Skipping %%~nxF because HBNUM_ZIG_ENABLE is not 1.
         ) ELSE (
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
      ) ELSE (
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
)
@ECHO.
@ECHO [HBNum] All batch scripts completed.
@popd
@endlocal & exit /b 0
