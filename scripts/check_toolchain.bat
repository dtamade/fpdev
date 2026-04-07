@echo off
setlocal ENABLEDELAYEDEXPANSION

set STATUS_OK=0
set STATUS_MISS=0
set LAZARUS_ROOT_STATUS=MISSING
set "LAZARUS_ROOT_PATH="

call :check make
call :check gmake
call :check mingw32-make
call :check fpc
call :check lazbuild
call :check git
call :check openssl
call :check_lazarus_root

REM try some fpc driver names
call :check ppc386
call :check ppcx64
call :check ppcarm

set TS=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set OUTDIR=logs\check
if not exist %OUTDIR% mkdir %OUTDIR%
set OUT=%OUTDIR%\toolchain_%TS%.txt

echo Toolchain Check @ %date% %time% > %OUT%
echo ================================== >> %OUT%
for %%C in (make gmake mingw32-make fpc lazbuild git openssl ppc386 ppcx64 ppcarm) do (
  call :probe %%C >> %OUT%
)
call :probe_lazarus_root >> %OUT%

type %OUT%

if %STATUS_MISS% GTR 0 (
  echo Missing tools: %STATUS_MISS%
  exit /b 1
) else (
  echo All required tools seem available.
  exit /b 0
)

:check
where %1 >nul 2>nul
if errorlevel 1 (
  echo [MISS] %1
  set /a STATUS_MISS+=1
) else (
  echo [ OK ] %1
  set /a STATUS_OK+=1
)
exit /b 0

:check_lazarus_root
set LAZARUS_ROOT_STATUS=MISSING
set "LAZARUS_ROOT_PATH="

if defined FPDEV_LAZARUSDIR (
  if exist "%FPDEV_LAZARUSDIR%\lcl\" (
    set LAZARUS_ROOT_STATUS=found
    set "LAZARUS_ROOT_PATH=%FPDEV_LAZARUSDIR%"
    echo [ OK ] lazarus_root: %FPDEV_LAZARUSDIR%
    set /a STATUS_OK+=1
  ) else (
    set LAZARUS_ROOT_STATUS=invalid_env
    echo [MISS] lazarus_root ^(FPDEV_LAZARUSDIR does not contain lcl^\)
    set /a STATUS_MISS+=1
  )
  exit /b 0
)

for /f "usebackq delims=" %%P in (`where lazbuild 2^>nul`) do (
  if not defined LAZARUS_ROOT_PATH set "LAZARUS_ROOT_PATH=%%~dpP"
)

if defined LAZARUS_ROOT_PATH (
  if exist "%LAZARUS_ROOT_PATH%lcl\" (
    set LAZARUS_ROOT_STATUS=found
    echo [ OK ] lazarus_root: %LAZARUS_ROOT_PATH%
    set /a STATUS_OK+=1
    exit /b 0
  )
)

set LAZARUS_ROOT_STATUS=missing
echo [MISS] lazarus_root ^(set FPDEV_LAZARUSDIR to a Lazarus root containing lcl^\)
set /a STATUS_MISS+=1
exit /b 0

:probe
set CMD=%1
where %CMD% >nul 2>nul
if errorlevel 1 (
  echo %-15s %CMD% : MISSING
) else (
  for /f "usebackq delims=" %%P in (`where %CMD%`) do set PATH_%CMD%=%%P
  set V=
  if "%CMD%"=="git" (
    for /f "tokens=3" %%v in ('git --version') do set V=%%v
  ) else if "%CMD%"=="openssl" (
    for /f "tokens=2" %%v in ('openssl version') do set V=%%v
  ) else if "%CMD%"=="fpc" (
    for /f "tokens=2" %%v in ('fpc -iV') do set V=%%v
  ) else if "%CMD%"=="lazbuild" (
    for /f "tokens=*" %%v in ('lazbuild --version ^| findstr /r /c:"[0-9]"') do set V=%%v
  ) else (
    set V=found
  )
  echo %-15s %CMD% : OK  !V!
)
exit /b 0

:probe_lazarus_root
if /I "%LAZARUS_ROOT_STATUS%"=="found" (
  echo %-15s lazarus_root : %LAZARUS_ROOT_PATH%
) else if /I "%LAZARUS_ROOT_STATUS%"=="invalid_env" (
  echo %-15s lazarus_root : MISSING ^(FPDEV_LAZARUSDIR does not contain lcl/^\)
) else (
  echo %-15s lazarus_root : MISSING ^(set FPDEV_LAZARUSDIR to a Lazarus root containing lcl/^\)
)
exit /b 0
