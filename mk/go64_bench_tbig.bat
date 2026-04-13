@setlocal
@REM hbnum: Released to Public Domain.
del .\msvc64\hbnum_bench_tbig.exe
SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64
%HB_BASE_PATH% hbnum_bench_tbig.hbp -comp=msvc64
@endlocal
