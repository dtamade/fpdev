# FPDev Testing Guide

This document provides guidance on running tests in the FPDev project.

## Test Framework

FPDev uses **fpcunit** (Free Pascal Unit Testing Framework) for all tests. Tests are organized as Lazarus Program files (`.lpr`) in the `tests/` directory.

## Test Structure

```
tests/
├── test_config_management.lpr      # Configuration system tests
├── test_git2_adapter.lpr           # Git integration tests
├── test_build_manager.lpr          # Build manager tests
├── fpdev.build.manager/            # BuildManager test suite
│   ├── run_tests.bat               # Windows test runner
│   └── *.lpr                       # Individual test programs
└── fpdev.git2/                     # Git2 test suite
    ├── buildOrTest.fpcunit.bat     # Windows test runner
    └── *.lpr                       # Individual test programs
```

## Running Tests

### Build and Run Single Test

```bash
# Windows
lazbuild -B tests\test_config_management.lpi
.\bin\test_config_management.exe

# Linux/macOS
lazbuild -B tests/test_config_management.lpi
./bin/test_config_management
```

### Run Test Suite

```bash
# BuildManager test suite
cd tests\fpdev.build.manager
run_tests.bat

# Git2 test suite
cd tests\fpdev.git2
buildOrTest.fpcunit.bat
```

### Run All Tests

```bash
# Windows (Git Bash / WSL)
bash scripts/run_all_tests.sh

# Linux/macOS
scripts/run_all_tests.sh
```

No dedicated `scripts\run_all_tests.bat` wrapper is tracked in this repository.

## Test-Driven Development (TDD)

FPDev follows the **Red-Green-Refactor** cycle:

1. **🔴 Red**: Write failing test first
   ```pascal
   procedure TTestMyFeature.TestNewFeature;
   begin
     AssertEquals('Expected behavior', ExpectedValue, ActualValue);
   end;
   ```

2. **🟢 Green**: Implement minimal code to pass
   ```pascal
   function MyFeature: Integer;
   begin
     Result := ExpectedValue;  // Minimal implementation
   end;
   ```

3. **🔵 Refactor**: Improve code while keeping tests green
   ```pascal
   function MyFeature: Integer;
   begin
     // Improved implementation with better design
     Result := CalculateValue();
   end;
   ```

## Writing Tests

### Test Case Structure

```pascal
unit test_my_feature;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  fpdev.my_feature;  // Unit under test

type
  TTestMyFeature = class(TTestCase)
  published
    procedure TestBasicFunctionality;
    procedure TestEdgeCases;
    procedure TestErrorHandling;
  end;

implementation

procedure TTestMyFeature.TestBasicFunctionality;
var
  Feature: TMyFeature;
begin
  Feature := TMyFeature.Create;
  try
    AssertEquals('Basic test', ExpectedValue, Feature.DoSomething);
  finally
    Feature.Free;
  end;
end;

procedure TTestMyFeature.TestEdgeCases;
begin
  // Test edge cases
  AssertTrue('Edge case 1', Condition1);
  AssertFalse('Edge case 2', Condition2);
end;

procedure TTestMyFeature.TestErrorHandling;
begin
  // Test error handling
  try
    RaiseException;
    Fail('Expected exception not raised');
  except
    on E: EMyException do
      AssertEquals('Error message', 'Expected message', E.Message);
  end;
end;

initialization
  RegisterTest(TTestMyFeature);
end.
```

### Common Assertions

```pascal
// Equality checks
AssertEquals('Message', Expected, Actual);
AssertNotEquals('Message', NotExpected, Actual);

// Boolean checks
AssertTrue('Message', Condition);
AssertFalse('Message', Condition);

// Null checks
AssertNull('Message', Pointer);
AssertNotNull('Message', Pointer);

// Exception checks
AssertException('Message', EMyException, @ProcedureThatRaises);

// Failure
Fail('Explicit failure message');
```

## Offline Mode (Default)

**All tests run in offline mode by default** to avoid network dependencies and ensure reproducibility.

### Git2 Tests

Git2 tests use **local test repositories** instead of remote URLs:

```pascal
// ✅ Correct - Local test repository
const
  TEST_REPO_PATH = 'tests/fixtures/test_repo';

procedure TTestGit2.SetUp;
begin
  // Create local test repository
  CreateTestRepository(TEST_REPO_PATH);
end;

// ❌ Wrong - Network dependency
const
  TEST_REPO_URL = 'https://github.com/example/repo.git';
```

### BuildManager Tests

BuildManager tests use **mock toolchain checkers** to avoid `make` dependency:

```pascal
// ✅ Correct - Mock toolchain checker
var
  Checker: IToolchainChecker;
begin
  Checker := TMockToolchainChecker.Create(True);  // Always available
  Manager := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
end;

// ❌ Wrong - Real toolchain dependency
var
  Checker: IToolchainChecker;
begin
  Checker := TBuildToolchainChecker.Create(False);  // Requires real make
end;
```

## Test Coverage

<!-- TEST-INVENTORY-COVERAGE:BEGIN -->
Current discoverable test-program inventory:

- Discoverable `test_*.lpr` programs: 275
- Shared discovery rules: CI and `scripts/run_all_tests.sh` use the same inventory source
- Default exclusions: `examples`, `fpdev.git2.adapter`, `fpdev.libgit2.base`, `fpdev.core.misc`, `migrated`
- Sync command: `python3 scripts/update_test_stats.py --write`
- Verification command: `python3 scripts/update_test_stats.py --check`
<!-- TEST-INVENTORY-COVERAGE:END -->

## Continuous Integration

Verification entrypoints include:
- Pushes to `main` / `develop`
- Pull requests targeting `main`
- Manual/local release verification before publishing

Tracked workflow entrypoints:
- `.github/workflows/ci.yml` `release-acceptance-linux`
- `.github/workflows/ci.yml` `compile-check`
- `.github/workflows/ci.yml` `cross-platform-cli-smoke`

## Troubleshooting

### Test Fails with "Disk Full" Error

**Cause**: Windows console encoding issue with Unicode output.

**Solution**: Ensure all test output uses English only (no Chinese characters).

```pascal
// ❌ Wrong
WriteLn('错误: 测试失败');

// ✅ Correct
WriteLn('Error: Test failed');
```

### Test Fails with "make not found"

**Cause**: Real integration/build-oriented flows may invoke `make`/`gmake`, even though the default mock-based BuildManager unit tests avoid that dependency.

**Solution**: Prefer the existing mock toolchain checkers for unit tests, or install `make` when you intentionally run real build-oriented flows:

```bash
# Windows (MinGW)
choco install mingw

# Linux
sudo apt-get install build-essential

# macOS
xcode-select --install
```

### Test Fails to Load libgit2 at Runtime

**Cause**: The platform-specific libgit2 shared library is not discoverable at runtime.

**Solution**: Match the runtime library name used by `src/libgit2.pas` and make that artifact visible to the platform loader:

- **Windows**: ensure `git2.dll` is next to the executable or in `PATH`. A typical local bundle path is `3rd\libgit2\install\bin\git2.dll`.
- **Linux**: ensure `libgit2.so` is installed or expose your local build output, for example `LD_LIBRARY_PATH=3rd/libgit2/install/lib:$LD_LIBRARY_PATH`.
- **macOS**: ensure `libgit2.1.dylib` is installed or expose your local build output, for example `DYLD_LIBRARY_PATH=3rd/libgit2/install/lib:$DYLD_LIBRARY_PATH`.

If you prefer system packages, that is also fine; the important part is that the platform-specific shared library name expected by `src/libgit2.pas` is discoverable when the test executable starts.

## Best Practices

1. **Write tests first** (TDD Red-Green-Refactor)
2. **Keep tests isolated** (no shared state between tests)
3. **Use descriptive test names** (`TestFeatureWithEdgeCase`)
4. **Test one thing per test** (single assertion focus)
5. **Avoid network dependencies** (use local fixtures)
6. **Clean up resources** (use try-finally blocks)
7. **Run tests frequently** (after every change)
8. **Keep tests fast** (< 1 second per test)

## References

- [fpcunit Documentation](https://wiki.freepascal.org/fpcunit)
- [TDD Best Practices](https://wiki.freepascal.org/Test_Driven_Development)
- [FPDev WARP.md](../WARP.md) - Comprehensive project documentation

---

**Last Updated**: 2026-04-05
**Test Framework**: fpcunit
<!-- TEST-INVENTORY-FOOTER:BEGIN -->
**Test Inventory**: 275 discoverable test programs (same rules as CI)
<!-- TEST-INVENTORY-FOOTER:END -->
