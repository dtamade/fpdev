# Build Cache CacheStats Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk cache-hit formatting from `TBuildCache.GetCacheStats` into a helper without changing output semantics.

**Architecture:** Keep `GetCacheStats` responsible for reading the live counters on `TBuildCache`, but move total-request and hit-rate formatting into `fpdev.build.cache.cachestats`.

**Tech Stack:** Object Pascal (FPC/Lazarus), tiny pure formatting helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for cache stats helper

**Files:**
- Create: `tests/test_build_cache_cachestats.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - zero requests produce `0.0%%` hit rate
  - non-zero requests format the computed percentage correctly

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cachestats.lpr`
Expected: FAIL because `fpdev.build.cache.cachestats` does not exist yet.

### Task 2: Extract cache stats helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.cachestats.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheFormatCacheStats`.
- Keep `GetCacheStats` as counter lookup plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_cachestats.lpr && ./bin/test_build_cache_cachestats`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Binary cache regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binary.lpr && ./bin/test_build_cache_binary`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
