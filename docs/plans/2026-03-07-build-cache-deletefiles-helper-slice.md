# Build Cache Delete Files Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk source artifact file deletion from `TBuildCache.DeleteArtifacts` into a helper without changing current deletion behavior.

**Architecture:** Keep `DeleteArtifacts` responsible for source archive/meta path lookup, but move the final conditional delete operations into `fpdev.build.cache.deletefiles`. Preserve current semantics: missing files count as success and only source archive/meta are considered.

**Tech Stack:** Object Pascal (FPC/Lazarus), tiny filesystem helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for delete helper

**Files:**
- Create: `tests/test_build_cache_deletefiles.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - existing archive and meta are deleted
  - missing files are treated as already deleted

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_deletefiles.lpr`
Expected: FAIL because `fpdev.build.cache.deletefiles` does not exist yet.

### Task 2: Extract delete helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.deletefiles.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheDeleteArtifactFiles`.
- Keep `DeleteArtifacts` as path lookup plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_deletefiles.lpr && ./bin/test_build_cache_deletefiles`
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
