@echo off
setlocal
set EXDIR=%~dp0
pushd %EXDIR%
if not exist bin mkdir bin
if not exist lib mkdir lib

set FPC=fpc
set INCLUDES=-Fu..\..\src -Fu.
set OUTUNIT=-FUlib
set OPTS=-gl -gh

%FPC% %INCLUDES% %OUTUNIT% -obin\example_toolchain_check %OPTS% example_toolchain_check.lpr || goto :fail
%FPC% %INCLUDES% %OUTUNIT% -obin\example_policy_check %OPTS% example_policy_check.lpr || goto :fail
%FPC% %INCLUDES% %OUTUNIT% -obin\example_manifest_fetch %OPTS% example_manifest_fetch.lpr || goto :fail

echo === example_toolchain_check ===
bin\example_toolchain_check.exe

echo === example_policy_check (main) ===
bin\example_policy_check.exe main

echo === example_policy_check (3.2.2) ===
bin\example_policy_check.exe 3.2.2

echo === example_manifest_fetch (mock) ===
bin\example_manifest_fetch.exe

popd
exit /b 0
:fail
echo build failed
popd
exit /b 1

