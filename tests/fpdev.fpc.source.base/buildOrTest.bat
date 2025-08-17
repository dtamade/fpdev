@echo off
setlocal
set LAZBUILD=lazbuild

REM build or test single .lpr in this folder
if "%1"=="" (
  echo Usage: buildOrTest.bat ^<name.lpr^> [Debug^|Release]
  echo Example: buildOrTest.bat fpdev.fpc.source.base.test.lpr Release
  exit /b 1
)

set NAME=%~1
set MODE=%~2
if "%MODE%"=="" set MODE=Default

REM build with Lazarus; outputs to local bin/lib
%LAZBUILD% -B "%NAME%" --bm=%MODE% --pcp="."
if errorlevel 1 exit /b %errorlevel%

endlocal
exit /b 0

