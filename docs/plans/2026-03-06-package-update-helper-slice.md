# Package Update Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the version-resolution and update-decision logic from `TPackageManager.UpdatePackage` into a dedicated helper unit without changing update behavior.

**Architecture:** Keep uninstall/install orchestration in `TPackageManager.UpdatePackage`, but move the pure “find latest available version for package + compare with installed version + decide whether update is needed” logic into `fpdev.cmd.package.updateplan`. This reduces coordination code while keeping error/output behavior intact.

**Tech Stack:** Object Pascal (FPC/Lazarus), package version comparison via existing helpers, focused Pascal regression tests.

---

### Task 1: Add focused failing test for update plan helper

**Files:**
- Create: `tests/test_package_updateplan.lpr`

**Step 1: Write the failing test**
- Add tests that verify the helper:
  - selects the highest available version for a package
  - reports “no update” when installed version is already latest
  - fails when package is absent from available list

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_updateplan.lpr`
Expected: FAIL because `fpdev.cmd.package.updateplan` does not exist yet.

### Task 2: Extract update decision helper

**Files:**
- Create: `src/fpdev.cmd.package.updateplan.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `BuildPackageUpdatePlanCore` to compute latest version and whether update is needed.
- Keep `TPackageManager.UpdatePackage` as thin orchestration around that plan.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_updateplan.lpr && ./bin/test_package_updateplan`
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
