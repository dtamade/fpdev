@echo off
setlocal
set THIS=%~dp0
pushd "%THIS%\..\.."
if not exist bin mkdir bin
if not exist logs mkdir logs

rem build
fpc -Fu.\src -obin\test_bm.exe tests\fpdev.build.manager\test_build_manager.lpr
fpc -Fu.\src -obin\test_bm_fail.exe tests\fpdev.build.manager\test_build_manager_strict_fail.lpr
fpc -Fu.\src -obin\test_bm_pass.exe tests\fpdev.build.manager\test_build_manager_strict_pass.lpr
set ERR=%ERRORLEVEL%
if not %ERR%==0 goto :end

rem run
bin\test_bm.exe
bin\test_bm_fail.exe
bin\test_bm_pass.exe

rem show latest log
echo === latest log ===
for /f "delims=" %%A in ('dir /b /o-d logs\build_*.log 2^>NUL') do (
  type "logs\%%A"
  goto :afterlog
)
echo (no log found)
:afterlog

:end
popd
exit /b %ERR%

