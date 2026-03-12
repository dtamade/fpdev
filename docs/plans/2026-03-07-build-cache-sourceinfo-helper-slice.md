# Build Cache Source Info Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk old-meta to artifact-info mapping from `TBuildCache.GetArtifactInfo` into a helper without changing source cache behavior.

**Architecture:** Keep `GetArtifactInfo` responsible for source meta/archive path lookup and old-meta file loading, but move the `TOldMetaArtifactInfo -> TArtifactInfo` field mapping into `fpdev.build.cache.sourceinfo`.

**Tech Stack:** Object Pascal (FPC/Lazarus), helper function over existing record types, focused Pascal regression tests.

---

### Task 1: Add focused failing test for source info helper

**Files:**
- Create: `tests/test_build_cache_sourceinfo.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - version/cpu/os/source path are copied from old meta
  - archive size and created-at are preserved
  - wrapper-provided archive path is injected into `TArtifactInfo`

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_sourceinfo.lpr`
Expected: FAIL because `fpdev.build.cache.sourceinfo` does not exist yet.

### Task 2: Extract source info helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.sourceinfo.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheCreateSourceArtifactInfo`.
- Keep `GetArtifactInfo` as path/load orchestration plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_sourceinfo.lpr && ./bin/test_build_cache_sourceinfo`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Metadata regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_metadata.lpr && ./bin/test_cache_metadata`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
