@echo off
setlocal
set THIS=%~dp0
pushd "%THIS%"
if not exist lib mkdir lib
if not exist bin mkdir bin
if not exist logs mkdir logs
rem help
if /I "%1"=="help" goto :help
if /I "%1"=="--help" goto :help
if /I "%1"=="-h" goto :help
if /I "%1"=="/?" goto :help

:help
@echo Usage: buildOrTest.bat [strict^|-s] [--no-install] [--verbose] [--preflight] [--dry-run]
@echo   strict or -s     Enable --strict and --verbose
@echo   --no-install     Skip Install() stage
@echo   --verbose        Enable verbose logs
@echo Env vars:
@echo   DEMO_STRICT=1    Append --strict
@echo   DEMO_VERBOSE=1   Append --verbose
@echo   TEST_ONLY=1      Append --test-only (skip Build/Install/Configure)
@echo   NO_INSTALL=1     Append --no-install
@echo Examples:
@echo   buildOrTest.bat strict
@echo   buildOrTest.bat --preflight --dry-run --no-install
@echo   set TEST_ONLY=1 ^& set NO_INSTALL=1 ^& set PREFLIGHT=1 ^& set DRY_RUN=1 ^& buildOrTest.bat
if /I "%1"=="help" goto :end
if /I "%TEST_ONLY%"=="1" set DEMO_ARGS=%DEMO_ARGS% --test-only

if /I "%1"=="--help" goto :end
if /I "%1"=="-h" goto :end
if /I "%1"=="/?" goto :end


rem build demo
fpc -Fu..\..\src -obin\demo.exe demo.lpr
set ERR=%ERRORLEVEL%
if not %ERR%==0 goto :end

rem resolve run args: default normal; "strict" or -s enables strict+verbose
set DEMO_ARGS=
if /I "%1"=="strict" set DEMO_ARGS=--strict --verbose
if /I "%1"=="-s" set DEMO_ARGS=--strict --verbose
if not defined DEMO_ARGS set DEMO_ARGS=%*%

rem env overrides (append)
if /I "%DEMO_STRICT%"=="1" set DEMO_ARGS=%DEMO_ARGS% --strict
if /I "%DEMO_VERBOSE%"=="1" set DEMO_ARGS=%DEMO_ARGS% --verbose
if /I "%DRY_RUN%"=="1" set DEMO_ARGS=%DEMO_ARGS% --dry-run
if /I "%PREFLIGHT%"=="1" set DEMO_ARGS=%DEMO_ARGS% --preflight

if /I "%NO_INSTALL%"=="1" set DEMO_ARGS=%DEMO_ARGS% --no-install

echo Running: bin\demo.exe %DEMO_ARGS%
bin\demo.exe %DEMO_ARGS%

rem show latest log file (if any)
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
