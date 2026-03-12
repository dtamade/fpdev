# Package Metadata Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract package metadata writing from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing install-local or publish behavior.

**Architecture:** Follow the same thin-wrapper pattern used for previous package helper slices: move the pure JSON write logic into `fpdev.cmd.package.metadata`, then keep `TPackageManager.WritePackageMetadata` as a delegating wrapper that passes build metadata strings through. Guard the change with a focused writer test plus CLI package regression.

**Tech Stack:** Object Pascal (FPC/Lazarus), JSON helpers from `fpjson/jsonparser`, Pascal CLI regression tests.

---

### Task 1: Add focused failing test for metadata writing

**Files:**
- Create: `tests/test_package_metadata_writer.lpr`

**Step 1: Write the failing test**
- Add a small test that calls `WritePackageMetadataCore` and verifies persisted JSON fields.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_metadata_writer.lpr`
Expected: FAIL because `fpdev.cmd.package.metadata` does not exist yet.

### Task 2: Extract metadata writer helper

**Files:**
- Create: `src/fpdev.cmd.package.metadata.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Move JSON write logic to `WritePackageMetadataCore`.
- Keep `TPackageManager.WritePackageMetadata` as a thin wrapper.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_metadata_writer.lpr && ./bin/test_package_metadata_writer`
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
