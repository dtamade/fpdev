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
# Windows
scripts\run_all_tests.bat

# Linux/macOS
scripts/run_all_tests.sh
```

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

Current test coverage (as of 2026-01-31):

| Module | Tests | Status |
|--------|-------|--------|
| Configuration Management | 15 | ✅ 100% passing |
| Git Integration | 12 | ✅ 100% passing |
| Build Manager | 8 | ✅ 100% passing |
| Build Interfaces | 9 | ✅ 100% passing |
| Git2 Status | 6 | ✅ 100% passing |
| **Total** | **50+** | **✅ 100% passing** |

## Continuous Integration

Tests are automatically run on:
- Every commit (pre-commit hook)
- Every pull request (CI pipeline)
- Nightly builds (full test suite)

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

**Cause**: BuildManager test requires `make` in PATH.

**Solution**: Use mock toolchain checker or install `make`:

```bash
# Windows (MinGW)
choco install mingw

# Linux
sudo apt-get install build-essential

# macOS
xcode-select --install
```

### Test Fails with "git2.dll not found"

**Cause**: libgit2 library not in PATH.

**Solution**: Copy `git2.dll` to executable directory or add to PATH:

```bash
# Windows
copy 3rd\libgit2\git2.dll bin\

# Linux/macOS
export LD_LIBRARY_PATH=3rd/libgit2:$LD_LIBRARY_PATH
```

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

**Last Updated**: 2026-01-31  
**Test Framework**: fpcunit  
**Test Coverage**: 50+ tests, 100% passing
