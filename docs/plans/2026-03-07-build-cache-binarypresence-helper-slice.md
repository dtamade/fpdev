# Build Cache Binary Presence Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk artifact presence detection from `TBuildCache.HasArtifacts` into a helper without changing cache-hit semantics.

**Architecture:** Keep `HasArtifacts` responsible for artifact key lookup and existing source/binary path selection, but move the final `FileExists(source) or FileExists(binary-meta)` decision into `fpdev.build.cache.binarypresence`. Reuse the already-extracted `BuildCacheGetBinaryMetaPath` helper.

**Tech Stack:** Object Pascal (FPC/Lazarus), small filesystem helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for binary presence helper

**Files:**
- Create: `tests/test_build_cache_binarypresence.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - source archive alone counts as cached artifact
  - binary meta alone counts as cached artifact
  - neither file present returns false

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binarypresence.lpr`
Expected: FAIL because `fpdev.build.cache.binarypresence` does not exist yet.

### Task 2: Extract binary presence helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.binarypresence.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheHasArtifactFiles`.
- Keep `HasArtifacts` as artifact-key/path preparation plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_binarypresence.lpr && ./bin/test_build_cache_binarypresence`
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
