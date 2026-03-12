# Build Cache JSON Path Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk JSON metadata path construction from `TBuildCache.GetJSONMetaPath` into a helper without changing path semantics.

**Architecture:** Keep `GetJSONMetaPath` as a tiny wrapper around the artifact key lookup, but move the final `ACacheDirWithDelim + AArtifactKey + '.json'` composition into `fpdev.build.cache.jsonpath`.

**Tech Stack:** Object Pascal (FPC/Lazarus), tiny path helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for JSON path helper

**Files:**
- Create: `tests/test_build_cache_jsonpath.lpr`

**Step 1: Write the failing test**
- Add a test that verifies the helper appends `.json` to the artifact key inside the cache directory.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsonpath.lpr`
Expected: FAIL because `fpdev.build.cache.jsonpath` does not exist yet.

### Task 2: Extract JSON path helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.jsonpath.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheGetJSONMetaPath`.
- Keep `GetJSONMetaPath` as artifact-key lookup plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_jsonpath.lpr && ./bin/test_build_cache_jsonpath`
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
