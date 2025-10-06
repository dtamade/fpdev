@echo off
setlocal ENABLEDELAYEDEXPANSION

set STATUS_OK=0
set STATUS_MISS=0

call :check make
call :check gmake
call :check mingw32-make
call :check fpc
call :check lazbuild
call :check git
call :check openssl

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

