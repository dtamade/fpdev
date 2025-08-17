@echo off
setlocal
set LAZBUILD=lazbuild

if "%1"=="" (
  echo Usage: buildOrTest.bat ^<name.lpr^> [Debug^|Release]
  exit /b 1
)
set NAME=%~1
set MODE=%~2
if "%MODE%"=="" set MODE=Default
%LAZBUILD% -B "%NAME%" --bm=%MODE% --pcp="."
endlocal

