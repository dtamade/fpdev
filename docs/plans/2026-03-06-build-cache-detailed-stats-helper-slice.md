# Build Cache Detailed Stats Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `GetDetailedStats` aggregation logic from `src/fpdev.build.cache.pas` into a dedicated helper unit without changing cache behavior.

**Architecture:** Move the pure detailed-statistics aggregation over `TArtifactInfo` arrays into `fpdev.build.cache.detailedstats`. Keep `TBuildCache.GetDetailedStats` responsible for reading index entries and building the input array, but delegate the aggregation and summary math to the helper.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` / `TCacheDetailedStats` records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for detailed stats helper

**Files:**
- Create: `tests/test_build_cache_detailedstats.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - total entries/size/accesses aggregate correctly
  - most/least accessed versions are selected correctly
  - average entry size is computed correctly
  - empty input resets access counts to 0

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_detailedstats.lpr`
Expected: FAIL because `fpdev.build.cache.detailedstats` does not exist yet.

### Task 2: Extract detailed stats helper

**Files:**
- Create: `src/fpdev.build.cache.detailedstats.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheGetDetailedStatsCore` to the helper.
- Keep `TBuildCache.GetDetailedStats` as a thin wrapper around the helper.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_detailedstats.lpr && ./bin/test_build_cache_detailedstats`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_stats.lpr && ./bin/test_cache_stats`
Expected: PASS.

**Step 2: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.
