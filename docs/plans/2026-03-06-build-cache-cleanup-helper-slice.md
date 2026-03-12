# Build Cache Cleanup Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `CleanupLRU` victim-selection logic from `src/fpdev.build.cache.pas` into a dedicated helper unit without changing cache cleanup behavior.

**Architecture:** Keep `TBuildCache.CleanupLRU` responsible for scanning files and deleting archives/meta files, but move the size-based victim selection loop into `fpdev.build.cache.cleanup`. The helper will operate on `TArtifactInfo` arrays and return archive paths to evict.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` metadata records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for cleanup helper

**Files:**
- Create: `tests/test_build_cache_cleanup.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - when total size exceeds limit, helper selects oldest archives until under limit
  - when max size is 0 (unlimited), helper returns no victims

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cleanup.lpr`
Expected: FAIL because `fpdev.build.cache.cleanup` does not exist yet.

### Task 2: Extract cleanup helper

**Files:**
- Create: `src/fpdev.build.cache.cleanup.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheSelectCleanupVictims` to the helper.
- Keep `CleanupLRU` as a thin wrapper around file scanning + deletion.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cleanup.lpr && ./bin/test_build_cache_cleanup`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache space regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_space.lpr && ./bin/test_cache_space`
Expected: PASS.

**Step 2: Cache stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_stats.lpr && ./bin/test_cache_stats`
Expected: PASS.

**Step 3: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.
