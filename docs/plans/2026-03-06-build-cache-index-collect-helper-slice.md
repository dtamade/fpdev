# Build Cache Index Collect Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the duplicated index-info collection logic from `TBuildCache.GetDetailedStats` and `TBuildCache.GetLeastRecentlyUsed` into a dedicated helper unit without changing cache behavior.

**Architecture:** Keep the `TBuildCache` methods responsible for ensuring the index is loaded and for delegating to downstream helpers, but move the repeated `FIndexEntries` + `LookupIndexEntry` collection loop into `fpdev.build.cache.indexcollect`.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` dynamic arrays, object-method callbacks, focused Pascal regression tests.

---

### Task 1: Add focused failing test for index collect helper

**Files:**
- Create: `tests/test_build_cache_indexcollect.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - only successful lookups are collected
  - successful entries preserve original index order
  - empty input returns an empty array

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexcollect.lpr`
Expected: FAIL because `fpdev.build.cache.indexcollect` does not exist yet.

### Task 2: Extract index collect helper

**Files:**
- Create: `src/fpdev.build.cache.indexcollect.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheCollectIndexInfos` and the small callback/array types to the helper.
- Keep `GetDetailedStats` / `GetLeastRecentlyUsed` as thin wrappers around the helper.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexcollect.lpr && ./bin/test_build_cache_indexcollect`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Detailed stats helper regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_detailedstats.lpr && ./bin/test_build_cache_detailedstats`
Expected: PASS.

**Step 2: LRU helper regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_lru.lpr && ./bin/test_build_cache_lru`
Expected: PASS.

**Step 3: Cache stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_stats.lpr && ./bin/test_cache_stats`
Expected: PASS.

**Step 4: Cache index regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_index.lpr && ./bin/test_cache_index`
Expected: PASS.

**Step 5: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and full suite stays green.
