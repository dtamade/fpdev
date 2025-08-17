@echo off
setlocal
set THIS=%~dp0
pushd "%THIS%"
if not exist lib mkdir lib
if not exist bin mkdir bin

rem 默认离线；设置 FPDEV_ONLINE=1 可联网
if "%FPDEV_ONLINE%"=="1" (
  set FPDEV_OFFLINE=
) else (
  set FPDEV_OFFLINE=1
)

rem Enable heaptrc leak checking
fpc -gh -gl -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\test_git_basic.exe test_git_basic.lpr
set ERR=%ERRORLEVEL%
if not %ERR%==0 goto :end

bin\test_git_basic.exe --pause

:end
popd
exit /b %ERR%
