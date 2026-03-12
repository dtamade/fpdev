# Package Installed Query Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract installed package directory scanning from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing package CLI behavior.

**Architecture:** Start with the lower-risk half of the query layer: move the pure filesystem scan for installed packages into `fpdev.cmd.package.query.installed`, and keep `TPackageManager.GetInstalledPackages` as a thin wrapper that passes a package-info reader callback. This preserves current behavior while shrinking the manager and setting up a later slice for `GetAvailablePackages`.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TSearchRec` directory scanning, Pascal regression tests.

---

### Task 1: Add focused failing test for installed package scanning

**Files:**
- Create: `tests/test_package_installed_query.lpr`

**Step 1: Write the failing test**
- Add a small test that creates package directories plus a non-directory file, then verifies the helper returns only package directories and delegates name resolution through a reader method.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_installed_query.lpr`
Expected: FAIL because `fpdev.cmd.package.query.installed` does not exist yet.

### Task 2: Extract installed query helper

**Files:**
- Create: `src/fpdev.cmd.package.query.installed.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `GetInstalledPackagesCore` to the new helper unit.
- Keep `TPackageManager.GetInstalledPackages` as a wrapper calling the helper with `@GetPackageInfo`.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_installed_query.lpr && ./bin/test_package_installed_query`
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
