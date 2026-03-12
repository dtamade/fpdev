# Package Index Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract local package index parsing from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing package CLI behavior.

**Architecture:** Follow the existing helper extraction pattern used by `semver`, `depgraph`, `verify`, `create`, and `validation`: move pure parsing logic into a new `fpdev.cmd.package.index` unit, then keep `TPackageManager.ParseLocalPackageIndex` as a thin wrapper. Add a focused regression test for deduplication and invalid-entry filtering so the extracted helper preserves behavior.

**Tech Stack:** Object Pascal (FPC/Lazarus), manual Pascal regression tests, existing package type definitions.

---

### Task 1: Add focused failing test for package index parsing

**Files:**
- Create: `tests/test_package_index_parser.lpr`

**Step 1: Write the failing test**
- Create a small test program that imports `fpdev.cmd.package.index` and verifies: invalid entries are skipped, duplicate package names keep the highest version, and object-wrapped `{ "packages": [...] }` indexes are accepted.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_index_parser.lpr`
Expected: FAIL because `fpdev.cmd.package.index` does not exist yet.

### Task 2: Extract parser helper

**Files:**
- Create: `src/fpdev.cmd.package.index.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `ParseLocalPackageIndexCore(const AIndexPath: string): TPackageArray` to the new helper unit.
- Move the existing parsing logic there.
- Keep `TPackageManager.ParseLocalPackageIndex` as a thin wrapper calling the helper.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_index_parser.lpr && ./bin/test_package_index_parser`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Build main program**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.

**Step 2: Package search regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_search.lpr && ./bin/test_package_search`
Expected: PASS.

**Step 3: Package registry regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_registry.lpr && ./bin/test_package_registry`
Expected: PASS.
