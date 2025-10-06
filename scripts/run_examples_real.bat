@echo off
setlocal
set ROOT=%~dp0\..
pushd %ROOT%

set LOGDIR=logs\examples\real
if not exist %LOGDIR% mkdir %LOGDIR%

call scripts\check_toolchain.bat || (
  echo Toolchain check failed. See logs\check for details.
  popd & exit /b 1
)

for /d %%D in (examples\*) do (
  if exist "%%D\buildOrTest.bat" (
    echo Running REAL examples in %%D ...
    pushd "%%D"
    set REAL=1
    call :timestamp
    call buildOrTest.bat > "..\..\%LOGDIR%\%%~nD_%TS%.log" 2>&1
    popd
  )
)

goto :eof

:timestamp
for /f "tokens=1-4 delims=/:. " %%a in ("%date% %time%") do (
  set YY=%%a
  set MM=%%b
  set DD=%%c
  set HH=%%d
)
set HH=%time:~0,2%
set HH=%HH: =0%
set TS=%YY%%MM%%DD%_%HH%%time:~3,2%%time:~6,2%

echo All REAL examples executed. Logs in %LOGDIR%
popd
exit /b 0

