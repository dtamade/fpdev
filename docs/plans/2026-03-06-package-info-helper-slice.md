# Package Info Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `ShowPackageInfo` text rendering from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing CLI behavior.

**Architecture:** Keep package retrieval in `TPackageManager.ShowPackageInfo`, but move the text line assembly into a pure helper `fpdev.cmd.package.infoview`. The helper returns string arrays so the manager remains responsible for `IOutput` writes.

**Tech Stack:** Object Pascal (FPC/Lazarus), package type records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for info rendering helper

**Files:**
- Create: `tests/test_package_infoview.lpr`

**Step 1: Write the failing test**
- Add tests that verify the helper renders name/version/description, and only includes install path when package is installed.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_infoview.lpr`
Expected: FAIL because `fpdev.cmd.package.infoview` does not exist yet.

### Task 2: Extract info formatting helper

**Files:**
- Create: `src/fpdev.cmd.package.infoview.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `BuildPackageInfoLinesCore` to the helper.
- Keep `TPackageManager.ShowPackageInfo` responsible for retrieving the package and writing output, but use the helper to build lines.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_infoview.lpr && ./bin/test_package_infoview`
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
