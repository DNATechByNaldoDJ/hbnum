@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

IF EXIST ".\msvc64\hbnum.lib" DEL /Q ".\msvc64\hbnum.lib"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Could not delete .\msvc64\hbnum.lib.
   endlocal & exit /b 1
)
IF EXIST ".\msvc64\hbnum.lib" (
   ECHO [HBNum] Could not delete .\msvc64\hbnum.lib.
   endlocal & exit /b 1
)

SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64
IF ERRORLEVEL 1 (
   ECHO [HBNum] vcvarsall.bat failed.
   endlocal & exit /b 1
)

%HB_BASE_PATH% hbnum.hbp -comp=msvc64
IF ERRORLEVEL 1 (
   ECHO [HBNum] hbnum.hbp build failed.
   endlocal & exit /b 1
)

endlocal & exit /b 0
