# Build Cache Binary Restore Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk restore-path decision logic from `TBuildCache.RestoreBinaryArtifact` into a helper without changing binary restore behavior.

**Architecture:** Keep `RestoreBinaryArtifact` responsible for metadata lookup, integrity verification, destination directory creation, and command execution. Move file-extension fallback, archive path construction, and tar flag selection into `fpdev.build.cache.binaryrestore`.

**Tech Stack:** Object Pascal (FPC/Lazarus), helper record/functions, focused Pascal regression tests.

---

### Task 1: Add focused failing test for binary restore helper

**Files:**
- Create: `tests/test_build_cache_binaryrestore.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - empty file extension falls back to `.tar.gz`
  - archive path uses the `-binary` suffix and effective extension
  - `.tar` selects `-xf`
  - `.tgz` and fallback paths select `-xzf`

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binaryrestore.lpr`
Expected: FAIL because `fpdev.build.cache.binaryrestore` does not exist yet.

### Task 2: Extract binary restore helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.binaryrestore.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `TBuildCacheBinaryRestorePlan`.
- Add `BuildCacheBuildBinaryRestorePlan`.
- Keep `RestoreBinaryArtifact` as a thin wrapper around the plan.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binaryrestore.lpr && ./bin/test_build_cache_binaryrestore`
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
