@echo off
setlocal enabledelayedexpansion

rem Run all top-level FPDev tests on Windows.
rem Builds tests under tests\test_*.lpr and executes resulting binaries in bin\.

cd /d "%~dp0\.."

if not exist bin mkdir bin
if not exist lib mkdir lib

set TOTAL=0
set PASSED=0
set FAILED=0
set SKIPPED=0

set "FAILED_TESTS="

rem Offline-by-default: be explicit for CI reproducibility
set FPDEV_SKIP_NETWORK_TESTS=1

echo ========================================
echo Running All FPDev Tests (Windows)
echo ========================================
echo.

for %%F in (tests\test_*.lpr) do (
  set /a TOTAL+=1
  set "TEST_NAME=%%~nF"
  set "TEST_LPR=%%F"
  set "TEST_LPI=tests\!TEST_NAME!.lpi"
  set "TEST_BIN=bin\!TEST_NAME!.exe"

  <nul set /p="[%TOTAL%] Testing !TEST_NAME!... "

  rem Build
  set BUILD_OK=0
  if exist "!TEST_LPI!" (
    lazbuild -B "!TEST_LPI!" >nul 2>&1 && set BUILD_OK=1
    if "!BUILD_OK!"=="0" (
      fpc -Fusrc -Fisrc -FEbin -FUlib "!TEST_LPR!" >nul 2>&1 && set BUILD_OK=1
    )
  ) else (
    fpc -Fusrc -Fisrc -FEbin -FUlib "!TEST_LPR!" >nul 2>&1 && set BUILD_OK=1
  )

  if "!BUILD_OK!"=="0" (
    echo BUILD FAILED
    set /a FAILED+=1
    set "FAILED_TESTS=!FAILED_TESTS! !TEST_NAME!"
  ) else (
    if exist "!TEST_BIN!" (
      "!TEST_BIN!" >nul 2>&1
      if errorlevel 1 (
        echo FAILED
        set /a FAILED+=1
        set "FAILED_TESTS=!FAILED_TESTS! !TEST_NAME!"
      ) else (
        echo PASSED
        set /a PASSED+=1
      )
    ) else (
      echo SKIPPED ^(no binary^)
      set /a SKIPPED+=1
    )
  )
)

echo.
echo ========================================
echo Test Results Summary
echo ========================================
echo Total:   %TOTAL%
echo Passed:  %PASSED%
echo Failed:  %FAILED%
echo Skipped: %SKIPPED%
echo.

if not "%FAILED_TESTS%"=="" (
  echo Failed Tests:%FAILED_TESTS%
)

if %FAILED% GTR 0 (
  exit /b 1
) else (
  echo All tests passed!
  exit /b 0
)

