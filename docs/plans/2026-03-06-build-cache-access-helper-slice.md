# Build Cache Access Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the pure access-metadata update logic from `TBuildCache.RecordAccess` into a dedicated helper unit without changing persistence behavior.

**Architecture:** Keep `TBuildCache.RecordAccess` responsible for lookup + persistence (`UpdateIndexEntry` / `SaveMetadataJSON` / `SaveIndex`), but move the deterministic record mutation into `fpdev.build.cache.access`.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for access helper

**Files:**
- Create: `tests/test_build_cache_access.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - helper increments `AccessCount`
  - helper updates `LastAccessed` to the provided timestamp
  - helper preserves unrelated metadata fields
  - helper does not mutate the original input record

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_access.lpr`
Expected: FAIL because `fpdev.build.cache.access` does not exist yet.

### Task 2: Extract access helper

**Files:**
- Create: `src/fpdev.build.cache.access.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheRecordAccessInfo` to the helper.
- Keep `RecordAccess` as a thin wrapper around lookup + persistence.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_access.lpr && ./bin/test_build_cache_access`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_stats.lpr && ./bin/test_cache_stats`
Expected: PASS.

**Step 2: Cache index regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_index.lpr && ./bin/test_cache_index`
Expected: PASS.

**Step 3: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.

**Step 4: Full regression verification**
Run: `bash scripts/run_all_tests.sh`
Expected: full suite passes and new helper test is included.
