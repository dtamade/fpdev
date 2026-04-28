@echo off
setlocal ENABLEDELAYEDEXPANSION

set STATUS_OK=0
set STATUS_MISS=0
set LAZARUS_ROOT_STATUS=MISSING
set "LAZARUS_ROOT_PATH="
set REPO_BUILD_OUTPUTS_ENABLED=0
set "REPO_ROOT="
set "REPO_BIN_PATH="
set "REPO_BIN_STATUS=SKIPPED"
set "REPO_BIN_NOTES="
set "REPO_LIB_PATH="
set "REPO_LIB_STATUS=SKIPPED"
set "REPO_LIB_NOTES="
set "REPO_OUTPUT_LAST_STATUS="
set "REPO_OUTPUT_LAST_NOTES="

if defined FPDEV_TOOLCHAIN_REPO_ROOT (
  set "REPO_ROOT=%FPDEV_TOOLCHAIN_REPO_ROOT%"
) else (
  for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"
)

set "REPO_BIN_PATH=%REPO_ROOT%\bin"
set "REPO_LIB_PATH=%REPO_ROOT%\lib"

call :check make
call :check gmake
call :check mingw32-make
call :check fpc
call :check lazbuild
call :check git
call :check openssl
call :check_lazarus_root
call :check_repo_build_outputs

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
call :probe_repo_build_outputs >> %OUT%

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

:check_repo_build_outputs
if exist "%REPO_ROOT%\fpdev.lpi" (
  set REPO_BUILD_OUTPUTS_ENABLED=1
  call :check_repo_build_output repo_bin_writable "%REPO_BIN_PATH%"
  call :check_repo_build_output repo_lib_writable "%REPO_LIB_PATH%"
) else (
  set REPO_BUILD_OUTPUTS_ENABLED=0
  set "REPO_BIN_STATUS=SKIPPED"
  set "REPO_BIN_NOTES="
  set "REPO_LIB_STATUS=SKIPPED"
  set "REPO_LIB_NOTES="
)
exit /b 0

:check_repo_build_output
set "OUTPUT_NAME=%~1"
set "OUTPUT_PATH=%~2"
set "REPO_OUTPUT_LAST_STATUS=MISSING"
set "REPO_OUTPUT_LAST_NOTES="

if exist "%OUTPUT_PATH%\" (
  call :path_is_writable "%OUTPUT_PATH%"
  if errorlevel 1 (
    set "REPO_OUTPUT_LAST_NOTES=directory exists but is not writable"
    echo [MISS] %OUTPUT_NAME%: %OUTPUT_PATH% ^(!REPO_OUTPUT_LAST_NOTES!^)
    set /a STATUS_MISS+=1
  ) else (
    set "REPO_OUTPUT_LAST_STATUS=found"
    echo [ OK ] %OUTPUT_NAME%: %OUTPUT_PATH%
    set /a STATUS_OK+=1
  )
) else (
  call :parent_is_writable "%OUTPUT_PATH%"
  if errorlevel 1 (
    set "REPO_OUTPUT_LAST_NOTES=parent directory is not writable"
    echo [MISS] %OUTPUT_NAME%: %OUTPUT_PATH% ^(!REPO_OUTPUT_LAST_NOTES!^)
    set /a STATUS_MISS+=1
  ) else (
    set "REPO_OUTPUT_LAST_STATUS=found"
    set "REPO_OUTPUT_LAST_NOTES=creatable"
    echo [ OK ] %OUTPUT_NAME%: %OUTPUT_PATH% ^(!REPO_OUTPUT_LAST_NOTES!^)
    set /a STATUS_OK+=1
  )
)

if /I "%OUTPUT_NAME%"=="repo_bin_writable" (
  set "REPO_BIN_STATUS=!REPO_OUTPUT_LAST_STATUS!"
  set "REPO_BIN_NOTES=!REPO_OUTPUT_LAST_NOTES!"
) else if /I "%OUTPUT_NAME%"=="repo_lib_writable" (
  set "REPO_LIB_STATUS=!REPO_OUTPUT_LAST_STATUS!"
  set "REPO_LIB_NOTES=!REPO_OUTPUT_LAST_NOTES!"
)
exit /b 0

:path_is_writable
set "TARGET_DIR=%~1"
set "TEST_FILE=%TARGET_DIR%\.fpdev_write_test_%RANDOM%%RANDOM%.tmp"
(> "%TEST_FILE%" echo ok) >nul 2>nul
if exist "%TEST_FILE%" (
  del /f /q "%TEST_FILE%" >nul 2>nul
  exit /b 0
)
exit /b 1

:parent_is_writable
for %%I in ("%~1\..") do set "PARENT_DIR=%%~fI"
if not exist "!PARENT_DIR!\" exit /b 1
call :path_is_writable "!PARENT_DIR!"
exit /b %ERRORLEVEL%

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

:probe_repo_build_outputs
echo Build outputs:
if "%REPO_BUILD_OUTPUTS_ENABLED%"=="1" (
  echo   repo_root : %REPO_ROOT%
  echo   repo_bin_writable : %REPO_BIN_STATUS% %REPO_BIN_PATH% %REPO_BIN_NOTES%
  echo   repo_lib_writable : %REPO_LIB_STATUS% %REPO_LIB_PATH% %REPO_LIB_NOTES%
) else (
  echo   skipped : repo root not detected ^(%REPO_ROOT%\fpdev.lpi missing^)
)
exit /b 0
