# Build Cache LRU Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `GetLeastRecentlyUsed` selection logic from `src/fpdev.build.cache.pas` into a dedicated helper unit without changing cache behavior.

**Architecture:** Move the pure LRU selection algorithm into `fpdev.build.cache.lru`, operating on an array of `TArtifactInfo`. Keep `TBuildCache.GetLeastRecentlyUsed` responsible for reading entries from the index and feeding them into the helper.

**Tech Stack:** Object Pascal (FPC/Lazarus), `TArtifactInfo` metadata records, focused Pascal regression tests.

---

### Task 1: Add focused failing test for LRU helper

**Files:**
- Create: `tests/test_build_cache_lru.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - never-accessed entries win over accessed entries
  - among never-accessed entries, oldest `CreatedAt` wins
  - when all entries were accessed, oldest `LastAccessed` wins

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_lru.lpr`
Expected: FAIL because `fpdev.build.cache.lru` does not exist yet.

### Task 2: Extract LRU helper

**Files:**
- Create: `src/fpdev.build.cache.lru.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheSelectLeastRecentlyUsed` to the helper.
- Keep `TBuildCache.GetLeastRecentlyUsed` as a thin wrapper that loads index metadata and delegates selection.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_lru.lpr && ./bin/test_build_cache_lru`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache stats regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_stats.lpr && ./bin/test_cache_stats`
Expected: PASS.

**Step 2: Cache space regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_space.lpr && ./bin/test_cache_space`
Expected: PASS.

**Step 3: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.
