# Build Cache Binary Save Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk file-extension/path/size/hash preparation logic from `TBuildCache.SaveBinaryArtifact` into a helper without changing binary cache behavior.

**Architecture:** Keep `SaveBinaryArtifact` responsible for file existence checks, cache directory creation, copy orchestration, and metadata write. Move extension detection, `-binary` path construction, archive size lookup, and SHA256 selection into `fpdev.build.cache.binarysave`.

**Tech Stack:** Object Pascal (FPC/Lazarus), helper records/functions, focused Pascal regression tests.

---

### Task 1: Add focused failing test for binary save helper

**Files:**
- Create: `tests/test_build_cache_binarysave.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - `.tar.gz` is preserved as a compound extension
  - archive/meta paths use the `-binary` suffix
  - archive size is read from the copied file
  - provided SHA256 wins over computed fallback

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binarysave.lpr`
Expected: FAIL because `fpdev.build.cache.binarysave` does not exist yet.

### Task 2: Extract binary save helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.binarysave.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheResolveBinaryFileExt`.
- Add `BuildCacheBuildBinaryArtifactPaths`.
- Add `BuildCacheReadBinaryArchiveSize`.
- Add `BuildCacheResolveBinarySHA256`.
- Keep `SaveBinaryArtifact` as a thin wrapper around those helpers.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binarysave.lpr && ./bin/test_build_cache_binarysave`
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
