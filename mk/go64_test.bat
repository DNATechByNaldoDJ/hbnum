@setlocal EnableExtensions DisableDelayedExpansion
@ECHO OFF
@REM hbnum: Released to Public Domain.

IF EXIST ".\msvc64\hbnum_test.exe" DEL /Q ".\msvc64\hbnum_test.exe"
IF ERRORLEVEL 1 (
   ECHO [HBNum] Could not delete .\msvc64\hbnum_test.exe.
   endlocal & exit /b 1
)
IF EXIST ".\msvc64\hbnum_test.exe" (
   ECHO [HBNum] Could not delete .\msvc64\hbnum_test.exe.
   endlocal & exit /b 1
)

SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64
IF ERRORLEVEL 1 (
   ECHO [HBNum] vcvarsall.bat failed.
   endlocal & exit /b 1
)

%HB_BASE_PATH% hbnum_test.hbp -comp=msvc64
IF ERRORLEVEL 1 (
   ECHO [HBNum] hbnum_test.hbp build failed.
   endlocal & exit /b 1
)

endlocal & exit /b 0
