# CLI Flags Split Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move remaining global flag handling out of `src/fpdev.cli.global.pas` into a dedicated unit so `cli.global` only owns argument normalization helpers.

**Architecture:** Keep public behavior stable by preserving the existing callback-based flag helpers and moving them wholesale into `src/fpdev.cli.flags.pas`. Update the entrypoint and tests to import the new unit, then trim `tests/test_cli_misc.lpr` by moving flag-focused coverage into an include file.

**Tech Stack:** Object Pascal, FPC/Lazarus, fpcunit-style CLI regression tests.

---

### Task 1: Create red test dependency on `fpdev.cli.flags`

**Files:**
- Modify: `tests/test_cli_misc.lpr`

**Step 1:** Add `fpdev.cli.flags` to `uses`.
**Step 2:** Run `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cli_misc.lpr` and verify it fails because the unit does not exist.

### Task 2: Extract `cli.flags` unit

**Files:**
- Create: `src/fpdev.cli.flags.pas`
- Modify: `src/fpdev.cli.global.pas`
- Modify: `src/fpdev.lpr`

**Step 1:** Move callback types and helpers for `--help`, `--version`, `--portable`, `--data-root`, `--check-toolchain`, `--self-test`, and `--check-policy`.
**Step 2:** Keep `TryHandleGlobalFlag` as orchestration in the new unit.
**Step 3:** Reduce `src/fpdev.cli.global.pas` to argument normalization/build-dispatch only.

### Task 3: Slim flag tests

**Files:**
- Create: `tests/test_cli_flags.inc`
- Modify: `tests/test_cli_misc.lpr`

**Step 1:** Move flag stubs and tests into the include.
**Step 2:** Keep call order and test count stable.

### Task 4: Verify

**Files:**
- Verify only

**Step 1:** Run `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cli_misc.lpr && ./bin/test_cli_misc`.
**Step 2:** Run `lazbuild -B fpdev.lpi`.
**Step 3:** Run `bash scripts/run_all_tests.sh`.
