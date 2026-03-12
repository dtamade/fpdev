# Package Download Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `DownloadPackage` core logic from `src/fpdev.cmd.package.pas` into a dedicated helper unit without changing download behavior.

**Architecture:** Move the “select best available version + build cache zip path + prepare fetch options + invoke downloader callback” flow into `fpdev.cmd.package.fetch`. Keep `TPackageManager.DownloadPackage` as a thin wrapper that passes `GetAvailablePackages`, `GetCacheDir`, and `EnsureDownloadedCached` into the helper.

**Tech Stack:** Object Pascal (FPC/Lazarus), callback-based helper extraction, `TFetchOptions` from `fpdev.toolchain.fetcher`.

---

### Task 1: Add focused failing tests for package download helper

**Files:**
- Create: `tests/test_package_fetch.lpr`

**Step 1: Write the failing test**
- Add tests proving the helper:
  - selects the highest available version when no explicit version is provided
  - builds the cache path under `<cache>/packages`
  - passes SHA256 and timeout into the downloader callback
  - skips calling the downloader when package is missing or has no URLs

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_fetch.lpr`
Expected: FAIL because `fpdev.cmd.package.fetch` does not exist yet.

### Task 2: Extract download helper

**Files:**
- Create: `src/fpdev.cmd.package.fetch.pas`
- Modify: `src/fpdev.cmd.package.pas`

**Step 1: Write minimal implementation**
- Add `DownloadPackageCore` to the helper and keep `TPackageManager.DownloadPackage` as a thin wrapper.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_fetch.lpr && ./bin/test_package_fetch`
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
