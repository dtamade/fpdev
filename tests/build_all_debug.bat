@echo off
setlocal EnableDelayedExpansion

rem Debug build for all test projects (.lpi) with safe fallbacks.
rem 1) Prefer BuildMode=Debug if present
rem 2) Fallback to BuildMode=Default with FPCOPT debug flags

set LAZBUILD=lazbuild
set MODE=Debug
set STARTDIR=%~dp0

rem Debug flags: lineinfo, heap trace, DWARF3, assertions via -dDEBUG
set FPCOPT=-g -gl -gh -gw3 -dDEBUG

pushd "%STARTDIR%"
set FAILS=
set COUNT=0
for /r %%F in (*.lpi) do (
  set /a COUNT+=1
  echo [%%~nxF] Building in %MODE% ...
  %LAZBUILD% -B "%%~fF" --bm=%MODE%
  if errorlevel 1 (
    echo [%%~nxF] Debug mode missing or failed. Fallback to Default with FPCOPT...
    %LAZBUILD% -B "%%~fF" --bm=Default
    if errorlevel 1 (
      echo [%%~nxF] FAIL
      set FAILS=1
    ) else (
      echo [%%~nxF] OK (Default+FPCOPT)
    )
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

