# Build Cache Expired Scan Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the `.meta` scan and expiration selection phase from `TBuildCache.CleanExpired` into a helper without changing TTL cleanup behavior.

**Architecture:** Keep `CleanExpired` responsible for the final deletion loop, but move `*.meta` scanning, version extraction, info loading, and `IsExpired` filtering into `fpdev.build.cache.expiredscan`.

**Tech Stack:** Object Pascal (FPC/Lazarus), callback-driven helper over `TArtifactInfo`, focused Pascal regression tests.

---

### Task 1: Add focused failing test for expired scan helper

**Files:**
- Create: `tests/test_build_cache_expiredscan.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - only expired versions are collected
  - extracted version is preserved for binary/source `.meta` names
  - missing directory returns an empty array

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_expiredscan.lpr`
Expected: FAIL because `fpdev.build.cache.expiredscan` does not exist yet.

### Task 2: Extract expired scan helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.expiredscan.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `TBuildCacheExpiredInfoLoader`.
- Add `TBuildCacheExpiredChecker`.
- Add `BuildCacheCollectExpiredVersions`.
- Keep `CleanExpired` as `collect expired versions -> DeleteArtifacts`.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_expiredscan.lpr && ./bin/test_build_cache_expiredscan`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: TTL regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_ttl.lpr && ./bin/test_cache_ttl`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
