@echo off
setlocal ENABLEDELAYEDEXPANSION
REM Build and run examples for fpdev.build.manager

set EXDIR=%~dp0
pushd %EXDIR%

REM Ensure bin and lib directories exist
if not exist bin mkdir bin
if not exist lib mkdir lib

REM Compile .lpr with search path to ../../src and output to bin/lib
set FPC=fpc
set INCLUDES=-Fu..\..\src -Fu..\..\lib -Fu.
set OUTUNIT=-FUlib
set OPTS=-gl -gh

for %%F in (example_preflight.lpr example_build_dryrun.lpr example_install_sandbox.lpr example_strict_validate.lpr) do (
  echo Building %%F ...
  %FPC% %INCLUDES% %OUTUNIT% -obin\%%~nF %OPTS% %%F || goto :build_fail
)

REM REAL=1 to run real (disable dry-run inside examples)
if "%REAL%"=="1" (
  set RUN_MODE=REAL
) else (
  set RUN_MODE=DRY
)

echo Running examples ...
for %%E in (example_preflight example_build_dryrun example_install_sandbox example_strict_validate) do (
  echo === Running %%E (MODE=!RUN_MODE!) ===
  bin\%%E.exe
)

echo Done.
popd
exit /b 0

:build_fail
echo Build failed.
popd
exit /b 1

