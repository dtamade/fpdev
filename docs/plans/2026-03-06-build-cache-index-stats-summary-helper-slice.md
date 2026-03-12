# Build Cache Index Stats Summary Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the remaining `GetIndexStatistics` aggregation loop into a helper while preserving the current `TotalEntries` semantics.

**Architecture:** Reuse `fpdev.build.cache.indexcollect` to gather successfully parsed `TArtifactInfo` records, then extend `fpdev.build.cache.indexstats` with a summary helper that accepts both the successful infos and the raw index entry count. Keep `TBuildCache.GetIndexStatistics` as a thin wrapper.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` / `TCacheIndexStats` records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for index stats summary helper

**Files:**
- Modify: `tests/test_build_cache_indexstats.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - `TotalEntries` preserves the raw index count even if only a subset of infos were collected successfully
  - successful infos still drive total size and oldest/newest version selection
  - empty input with zero entries resets dates to zero

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexstats.lpr`
Expected: FAIL because `BuildCacheCalculateIndexStats` does not exist yet.

### Task 2: Extend index stats helper and thin the wrapper

**Files:**
- Modify: `src/fpdev.build.cache.indexstats.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheCalculateIndexStats` to `fpdev.build.cache.indexstats`.
- Keep `GetIndexStatistics` as `EnsureIndexLoaded` -> `BuildCacheCollectIndexInfos` -> `BuildCacheCalculateIndexStats`.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexstats.lpr && ./bin/test_build_cache_indexstats`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache index regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_index.lpr && ./bin/test_cache_index`
Expected: PASS.

**Step 2: Cache stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_stats.lpr && ./bin/test_cache_stats`
Expected: PASS.

**Step 3: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
