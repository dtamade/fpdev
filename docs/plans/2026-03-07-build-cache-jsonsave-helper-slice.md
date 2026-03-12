# Build Cache JSON Save Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk `TArtifactInfo -> JSON helper args` mapping from `TBuildCache.SaveMetadataJSON` into a helper without changing metadata write behavior.

**Architecture:** Keep `SaveMetadataJSON` responsible for resolving the JSON metadata path and invoking `BuildCacheSaveMetadataJSON`. Move the record-to-record argument preparation into `fpdev.build.cache.jsonsave`.

**Tech Stack:** Object Pascal (FPC/Lazarus), helper record mapping, focused Pascal regression tests.

---

### Task 1: Add focused failing test for JSON save helper

**Files:**
- Create: `tests/test_build_cache_jsonsave.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - all relevant `TArtifactInfo` fields are copied to the JSON helper record
  - archive path, download URL, access count, and last accessed are preserved

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsonsave.lpr`
Expected: FAIL because `fpdev.build.cache.jsonsave` does not exist yet.

### Task 2: Extract JSON save helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.jsonsave.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheCreateMetaJSONArtifactInfo`.
- Keep `SaveMetadataJSON` as path lookup plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsonsave.lpr && ./bin/test_build_cache_jsonsave`
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
