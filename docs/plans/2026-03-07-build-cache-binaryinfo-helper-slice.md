# Build Cache Binary Info Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk binary metadata path and record-mapping logic from `TBuildCache.GetBinaryArtifactInfo` into a helper without changing behavior.

**Architecture:** Keep `GetBinaryArtifactInfo` responsible for lookup orchestration (`GetArtifactKey`, load meta, success contract). Move binary meta-path construction and `TBinaryMetaArtifactInfo -> TArtifactInfo` mapping into `fpdev.build.cache.binaryinfo`.

**Tech Stack:** Object Pascal (FPC/Lazarus), helper functions over existing record types, focused Pascal regression tests.

---

### Task 1: Add focused failing test for binary info helper

**Files:**
- Create: `tests/test_build_cache_binaryinfo.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - meta path uses `-binary.meta`
  - binary meta fields are copied into `TArtifactInfo`
  - archive path uses the stored extension and `-binary` suffix

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binaryinfo.lpr`
Expected: FAIL because `fpdev.build.cache.binaryinfo` does not exist yet.

### Task 2: Extract binary info helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.binaryinfo.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheGetBinaryMetaPath`.
- Add `BuildCacheCreateBinaryArtifactInfo`.
- Keep `GetBinaryArtifactInfo` as a thin wrapper around these helpers.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binaryinfo.lpr && ./bin/test_build_cache_binaryinfo`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Binary artifact regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binary.lpr && ./bin/test_build_cache_binary`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
