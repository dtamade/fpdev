# Build Cache Cleanup Scan Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the archive scanning phase of `CleanupLRU` from `src/fpdev.build.cache.pas` into a dedicated helper unit without changing cleanup behavior.

**Architecture:** Move the “scan `*.tar.gz` files and build `TArtifactInfo` entries with version, size, archive path, and created time fallback” logic into `fpdev.build.cache.cleanupscan`. Keep `CleanupLRU` responsible for orchestrating scan → victim selection → deletion.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo`, cache scan helper reuse, focused Pascal regression tests.

---

### Task 1: Add focused failing test for cleanup scan helper

**Files:**
- Create: `tests/test_build_cache_cleanupscan.lpr`

**Step 1: Write the failing test**
- Add a test that creates cache archives, ignores non-archive files, and verifies metadata loader values are preferred over file timestamps.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cleanupscan.lpr`
Expected: FAIL because `fpdev.build.cache.cleanupscan` does not exist yet.

### Task 2: Extract cleanup scan helper

**Files:**
- Create: `src/fpdev.build.cache.cleanupscan.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheCollectCleanupEntries` to the helper.
- Keep `CleanupLRU` as a wrapper around scan helper + cleanup helper + file deletion.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cleanupscan.lpr && ./bin/test_build_cache_cleanupscan`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache space regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_space.lpr && ./bin/test_cache_space`
Expected: PASS.

**Step 2: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.
