# Build Cache Entry Query Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk cache-entry query logic from `TBuildCache.NeedsRebuild` and `TBuildCache.GetRevision` into a helper without changing semantics.

**Architecture:** Keep the methods responsible for entry lookup in `FEntries`, but move the actual entry-line query logic into `fpdev.build.cache.entryquery`.

**Tech Stack:** Object Pascal (FPC/Lazarus), small pure helper over existing entry-line parsing helpers, focused Pascal regression tests.

---

### Task 1: Add focused failing test for entry query helper

**Files:**
- Create: `tests/test_build_cache_entryquery.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - missing entry means rebuild is needed
  - lower/equal/higher cached status map to the expected rebuild decision
  - revision extraction is delegated consistently from entry lines

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_entryquery.lpr`
Expected: FAIL because `fpdev.build.cache.entryquery` does not exist yet.

### Task 2: Extract entry query helper and thin the wrappers

**Files:**
- Create: `src/fpdev.build.cache.entryquery.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheNeedsRebuildFromEntryLine`.
- Add `BuildCacheGetRevisionFromEntryLine`.
- Keep `NeedsRebuild` / `GetRevision` as lookup wrappers.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_entryquery.lpr && ./bin/test_build_cache_entryquery`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Entry I/O regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_entryio.lpr && ./bin/test_build_cache_entryio`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
