# Package List Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `ListPackages` text formatting from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing CLI behavior.

**Architecture:** Keep package retrieval and output writing in `TPackageManager.ListPackages`, but move header/empty-state/item-line rendering into a pure helper `fpdev.cmd.package.listview`. The helper returns string arrays so the manager can remain the place that writes to `IOutput`.

**Tech Stack:** Object Pascal (FPC/Lazarus), package type records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for list rendering helper

**Files:**
- Create: `tests/test_package_listview.lpr`

**Step 1: Write the failing test**
- Add tests that verify the helper:
  - renders installed header + formatted package row
  - renders available header when `--all`
  - renders empty-state line when there are no packages

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_listview.lpr`
Expected: FAIL because `fpdev.cmd.package.listview` does not exist yet.

### Task 2: Extract list formatting helper

**Files:**
- Create: `src/fpdev.cmd.package.listview.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `BuildPackageListLinesCore` to the helper.
- Keep `TPackageManager.ListPackages` responsible for selecting packages and writing output, but use the helper to build all text lines.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_listview.lpr && ./bin/test_package_listview`
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
