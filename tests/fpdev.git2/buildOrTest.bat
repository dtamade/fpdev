@echo off
setlocal
set THIS=%~dp0
pushd "%THIS%"
if not exist lib mkdir lib
if not exist bin mkdir bin

rem Enable heaptrc leak checking
set HEAPTRC=heap-fpdev-git2.log

rem 1) Discover/OID 基础用例
fpc -gh -gl -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.test.exe fpdev.git2.test.lpr
if errorlevel 1 goto :end
if exist %HEAPTRC% del /f /q %HEAPTRC%
bin\fpdev.git2.test.exe
echo === heaptrc log (basic) ===
type %HEAPTRC%

rem 2) Ignored 场景
fpc -gh -gl -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.status_ignore_test.exe fpdev.git2.status_ignore_test.lpr
if errorlevel 1 goto :end
if exist %HEAPTRC% del /f /q %HEAPTRC%
bin\fpdev.git2.status_ignore_test.exe
echo === heaptrc log (ignored) ===
type %HEAPTRC%

rem 3) Index 场景
fpc -gh -gl -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.status_index_test.exe fpdev.git2.status_index_test.lpr
if errorlevel 1 goto :end
if exist %HEAPTRC% del /f /q %HEAPTRC%
bin\fpdev.git2.status_index_test.exe
echo === heaptrc log (index) ===
type %HEAPTRC%

:end
popd
exit /b 0
