# Package Install Flow Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the post-download install pipeline from `TPackageManager.InstallPackage` into a dedicated helper unit without changing package install behavior.

**Architecture:** Move the “extract cached zip to sandbox temp dir → invoke install-from-source callback → optionally clean temp dir” flow into `fpdev.cmd.package.installflow`. Keep `InstallPackage` responsible for dependency resolution and download-plan preparation, but delegate the post-download pipeline to the new helper and handle the warning message if cleanup fails.

**Tech Stack:** Object Pascal (FPC/Lazarus), callback-based helper extraction, `ZipExtract` + `DeleteDirRecursive` filesystem workflow.

---

### Task 1: Add focused failing test for install flow helper

**Files:**
- Create: `tests/test_package_install_flow_helper.lpr`

**Step 1: Write the failing test**
- Add a test that stubs archive extraction and install-from-source callbacks, then verifies the helper:
  - builds temp dir as `<sandbox>/pkg-<name>-<version>`
  - invokes the installer callback with that temp dir
  - removes temp dir when `KeepArtifacts=False`
  - keeps temp dir when `KeepArtifacts=True`

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_install_flow_helper.lpr`
Expected: FAIL because `fpdev.cmd.package.installflow` does not exist yet.

### Task 2: Extract install flow helper

**Files:**
- Create: `src/fpdev.cmd.package.installflow.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `InstallPackageArchiveCore` to the helper and keep `InstallPackage` as a thin orchestration layer.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_install_flow_helper.lpr && ./bin/test_package_install_flow_helper`
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
