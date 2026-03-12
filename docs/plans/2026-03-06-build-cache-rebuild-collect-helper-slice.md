# Build Cache Rebuild Collect Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the remaining metadata-load loop from `TBuildCache.RebuildIndex` into a helper while preserving the B065 no-old-index-backfill behavior.

**Architecture:** Keep `RebuildIndex` responsible for the B065 state reset (`FIndexEntries.Clear` + `FIndexLoaded := True`) and the final `SaveIndex`, but move the `versions -> LoadMetadataJSON -> TArtifactInfo[]` collection loop into `fpdev.build.cache.rebuildscan`.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` records, object-method callbacks, focused Pascal regression tests.

---

### Task 1: Add focused failing test for rebuild collect helper

**Files:**
- Modify: `tests/test_build_cache_rebuildscan.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - failed metadata loads are skipped
  - successful infos preserve original version order

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_rebuildscan.lpr`
Expected: FAIL because `BuildCacheCollectRebuildInfos` does not exist yet.

### Task 2: Extend rebuild scan helper and thin the wrapper

**Files:**
- Modify: `src/fpdev.build.cache.rebuildscan.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `TBuildCacheRebuildInfoLoader`, `TBuildCacheRebuildInfoArray`, and `BuildCacheCollectRebuildInfos`.
- Keep `RebuildIndex` as `state reset -> list versions -> collect infos -> UpdateIndexEntry loop -> SaveIndex`.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_rebuildscan.lpr && ./bin/test_build_cache_rebuildscan`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache index regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_index.lpr && ./bin/test_cache_index`
Expected: PASS.

**Step 2: Index stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexstats.lpr && ./bin/test_build_cache_indexstats`
Expected: PASS.

**Step 3: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and full suite stays green.
