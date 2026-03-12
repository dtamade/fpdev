# Build Cache ArtifactMeta Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk source artifact metadata file writing from `TBuildCache.SaveArtifactMetadata` into a helper without changing cleanup metadata behavior.

**Architecture:** Keep `SaveArtifactMetadata` responsible for source meta path lookup and host CPU/OS selection, but move the actual key=value file writing into `fpdev.build.cache.artifactmeta`.

**Tech Stack:** Object Pascal (FPC/Lazarus), tiny file writer helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for artifact metadata helper

**Files:**
- Create: `tests/test_build_cache_artifactmeta.lpr`

**Step 1: Write the failing test**
- Add tests that verify written `.meta` files contain version/cpu/os/archive_path/created_at fields.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_artifactmeta.lpr`
Expected: FAIL because `fpdev.build.cache.artifactmeta` does not exist yet.

### Task 2: Extract artifact metadata helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.artifactmeta.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheSaveArtifactMeta`.
- Keep `SaveArtifactMetadata` as path/CPU/OS lookup plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_artifactmeta.lpr && ./bin/test_build_cache_artifactmeta`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Cache space regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_space.lpr && ./bin/test_cache_space`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
