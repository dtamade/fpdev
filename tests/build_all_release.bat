@echo off
setlocal EnableDelayedExpansion
set LAZBUILD=lazbuild
set MODE=Release
set STARTDIR=%~dp0
pushd "%STARTDIR%"
set FAILS=
set COUNT=0
for /r %%F in (*.lpi) do (
  set /a COUNT+=1
  echo [%%~nxF] Building in %MODE% ...
  %LAZBUILD% -B "%%~fF" --bm=%MODE%
  if errorlevel 1 (
    echo [%%~nxF] FAIL
    set FAILS=1
  ) else (
    echo [%%~nxF] OK
  )
  echo.
)
popd
if not defined COUNT set COUNT=0
echo Total projects: %COUNT%
if defined FAILS (
  echo === Some builds failed ===
  exit /b 1
) else (
  echo === All builds succeeded ===
  exit /b 0
)

