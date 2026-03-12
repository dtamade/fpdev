# Build Cache Source Path Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk source artifact/meta path construction from `TBuildCache.GetArtifactArchivePath` and `TBuildCache.GetArtifactMetaPath` into a helper without changing path semantics.

**Architecture:** Keep both methods responsible for artifact-key lookup, but move the final path concatenation into `fpdev.build.cache.sourcepath`.

**Tech Stack:** Object Pascal (FPC/Lazarus), tiny path helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for source path helper

**Files:**
- Create: `tests/test_build_cache_sourcepath.lpr`

**Step 1: Write the failing test**
- Add tests that verify source archive paths end with `.tar.gz` and source meta paths end with `.meta`.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_sourcepath.lpr`
Expected: FAIL because `fpdev.build.cache.sourcepath` does not exist yet.

### Task 2: Extract source path helper and thin the wrappers

**Files:**
- Create: `src/fpdev.build.cache.sourcepath.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheGetSourceArchivePath`.
- Add `BuildCacheGetSourceMetaPath`.
- Keep `GetArtifactArchivePath` / `GetArtifactMetaPath` as artifact-key lookup plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_sourcepath.lpr && ./bin/test_build_cache_sourcepath`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Metadata regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_metadata.lpr && ./bin/test_cache_metadata`
Expected: PASS.

**Step 2: TTL regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_ttl.lpr && ./bin/test_cache_ttl`
Expected: PASS.

**Step 3: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
