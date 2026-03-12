# Package Available Query Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract available package query logic from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing package CLI behavior.

**Architecture:** Move the repo-listing + fallback-to-local-index logic into a new `fpdev.cmd.package.query.available` helper. Keep `TPackageManager.GetAvailablePackages` as a thin wrapper that passes repo callbacks, install-status callback, and local-index parser callback into the helper.

**Tech Stack:** Object Pascal (FPC/Lazarus), callback-based helper extraction, Pascal regression tests.

---

### Task 1: Add focused failing tests for available package query

**Files:**
- Create: `tests/test_package_available_query.lpr`

**Step 1: Write the failing test**
- Add tests for two paths:
  - repo packages path: skips category entries and marks installed packages via callback
  - fallback path: when repo list is empty, uses the local index parser callback

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_available_query.lpr`
Expected: FAIL because `fpdev.cmd.package.query.available` does not exist yet.

### Task 2: Extract available query helper

**Files:**
- Create: `src/fpdev.cmd.package.query.available.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `GetAvailablePackagesCore` to the helper.
- Keep `TPackageManager.GetAvailablePackages` as a wrapper calling the helper with callbacks.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_available_query.lpr && ./bin/test_package_available_query`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.

**Step 2: CLI package regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cli_package.lpr && ./bin/test_cli_package`
Expected: PASS.

**Step 3: Index validation regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_index_validation.lpr && ./bin/test_package_index_validation`
Expected: PASS.
