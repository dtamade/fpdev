@echo off
setlocal
set THIS=%~dp0
pushd "%THIS%"
if not exist lib mkdir lib
if not exist bin mkdir bin

rem fpcunit build (include FPCUnit path via Lazarus packages if needed)
fpc -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.fpcunit.exe fpdev.git2.fpcunit.lpr
set ERR=%ERRORLEVEL%
if not %ERR%==0 goto :end

bin\fpdev.git2.fpcunit.exe --format=plain

:end
popd
exit /b %ERR%
