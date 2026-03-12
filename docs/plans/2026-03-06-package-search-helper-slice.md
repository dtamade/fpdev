# Package Search Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `SearchPackages` matching and text rendering from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing CLI behavior.

**Architecture:** Keep package retrieval and `IOutput` writes in `TPackageManager.SearchPackages`, but move case-insensitive matching, status labeling, and line rendering into `fpdev.cmd.package.searchview`. The helper returns text lines ready to print, including the no-results branch.

**Tech Stack:** Object Pascal (FPC/Lazarus), package type records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for search rendering helper

**Files:**
- Create: `tests/test_package_searchview.lpr`

**Step 1: Write the failing test**
- Add tests that verify the helper:
  - matches by name or description, case-insensitively
  - renders installed/available status labels
  - renders the no-results message when nothing matches

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_searchview.lpr`
Expected: FAIL because `fpdev.cmd.package.searchview` does not exist yet.

### Task 2: Extract search formatting helper

**Files:**
- Create: `src/fpdev.cmd.package.searchview.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `BuildPackageSearchLinesCore` to the helper.
- Keep `TPackageManager.SearchPackages` responsible for retrieving packages and writing output, but use the helper to build the lines.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_searchview.lpr && ./bin/test_package_searchview`
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
