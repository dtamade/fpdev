# CLI Smoke Acceptance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `fpdev` CLI smoke-testable in a clean/isolated environment: `--help` works consistently, `cross build --dry-run` is non-fatal, and advertised maintenance switches exist.

**Architecture:** Fix help-flag behavior centrally in `TCommandRegistry.DispatchPath` by rewriting only a trailing `--help/-h` into an existing `<prefix> help` command; otherwise preserve flags so leaf commands can handle them. Add regression tests in `tests/test_command_registry.lpr`. Keep `cross build --dry-run` side-effect free. Implement `resolve-version --help` and `fpdev --self-test`.

**Tech Stack:** Free Pascal (objfpc), path-based command registry, contract tests (`tests/test_command_registry.lpr`), Lazarus build (`lazbuild`).

---

### Task 1: Add RED Tests For CLI Help Flags + Dry-Run

**Files:**
- Modify: `tests/test_command_registry.lpr`

**Step 1: Write the failing tests**
- Add a minimal `IContext` with captured output and new tests:
  - `shell-hook --help` exits 0 and prints usage
  - `fpc test --help` exits 0 and prints usage
  - `cross test --help` exits 0 and prints usage
  - `lazarus run --help` exits 0 and prints usage
  - `resolve-version --help` exits 0 and prints usage
  - `cross build --dry-run --source=/tmp/fpdev-sources-missing` exits 0

**Step 2: Run to verify RED**

Run:
```bash
FPDEV_DATA_ROOT=/tmp/fpdev-tests-manual/data FPDEV_LAZARUS_CONFIG_ROOT=/tmp/fpdev-tests-manual/lazarus-config \
  fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_command_registry.lpr && ./bin/test_command_registry
```

Expected: failures for help flags and `cross build --dry-run`.

---

### Task 2: Fix Help Flag Dispatch In Registry

**Files:**
- Modify: `src/fpdev.command.registry.pas`

**Step 1: Implement minimal fix**
- Remove the global normalization that turns `--help/-h` into positional `help`.
- If the last arg is a help flag, rewrite to the nearest existing `<prefix> help` command:
  - `fpc --help` -> `fpc help`
  - `fpc test --help` -> `fpc help test`
  - `lazarus run --help` -> `lazarus help run`
- If no `<prefix> help` exists, keep args unchanged so leaf commands can handle `--help` directly.

**Step 2: Run tests**
Run:
```bash
FPDEV_DATA_ROOT=/tmp/fpdev-tests-manual/data FPDEV_LAZARUS_CONFIG_ROOT=/tmp/fpdev-tests-manual/lazarus-config \
  fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_command_registry.lpr && ./bin/test_command_registry
```
Expected: help-flag tests pass.

---

### Task 3: Implement `resolve-version --help`

**Files:**
- Modify: `src/fpdev.cmd.resolveversion.pas`

**Step 1: Add help output**
- Recognize `--help`/`-h`, print usage, exit 0.

**Step 2: Run tests**
Expected: `resolve-version --help` test passes.

---

### Task 4: Make `cross build --dry-run` Non-Fatal

**Files:**
- Modify: `src/fpdev.cmd.cross.build.pas`

**Step 1: In dry-run, print plan and exit 0**
- Do not call the build engine in `--dry-run`.

**Step 2: Run tests**
Expected: `cross build --dry-run` test passes.

---

### Task 5: Implement `fpdev --self-test`

**Files:**
- Modify: `src/fpdev.lpr`

**Step 1: Add switch**
- Print toolchain report JSON (`BuildToolchainReportJSON`).
- Exit code: 0 unless report contains `"level":"FAIL"`, then 2.

**Step 2: Manual verify**
Run:
```bash
fpc -Fusrc -Fisrc -FEbin -FUlib src/fpdev.lpr
./bin/fpdev --self-test
```

---

### Task 6: Full Verification

Run:
```bash
python3 /tmp/fpdev_cli_smoke.py
bash scripts/run_all_tests.sh
lazbuild -B fpdev.lpi
```

Expected:
- CLI smoke: no unexpected failures (allow non-zero for commands requiring prerequisites in a clean data root).
- Tests: all pass.
- Lazarus build: exit 0.

