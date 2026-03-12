# Build Cache JSON Info Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk JSON metadata record mapping from `TBuildCache.LoadMetadataJSON` into a helper without changing metadata loading behavior.

**Architecture:** Keep `LoadMetadataJSON` responsible for JSON meta-path lookup and the success/failure contract. Move the `TMetaJSONArtifactInfo -> TArtifactInfo` field mapping into `fpdev.build.cache.jsoninfo`.

**Tech Stack:** Object Pascal (FPC/Lazarus), helper function over existing record types, focused Pascal regression tests.

---

### Task 1: Add focused failing test for JSON info helper

**Files:**
- Create: `tests/test_build_cache_jsoninfo.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - JSON helper fields are copied into `TArtifactInfo`
  - archive path, download URL, access count, and last accessed are preserved

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsoninfo.lpr`
Expected: FAIL because `fpdev.build.cache.jsoninfo` does not exist yet.

### Task 2: Extract JSON info helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.jsoninfo.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheCreateJSONArtifactInfo`.
- Keep `LoadMetadataJSON` as load orchestration plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsoninfo.lpr && ./bin/test_build_cache_jsoninfo`
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
