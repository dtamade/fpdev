# Legacy Boundary Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove stale legacy backup units from `src/` and make the repository quality analyzer report such files before they drift back in.

**Architecture:** Keep runtime behavior unchanged by only removing an unused historical copy file and extending the analyzer with a focused repository-content rule for `src/*.old`. Guard the change with Python unit tests so cleanup rules stay enforced.

**Tech Stack:** Object Pascal source tree layout, Python `unittest`, Git-backed repository hygiene checks.

---

### Task 1: Add failing analyzer coverage for legacy source backup files

**Files:**
- Modify: `tests/test_analyze_code_quality.py`
- Modify: `scripts/analyze_code_quality.py`

**Step 1: Write the failing test**
- Add a unit test that creates `src/fpdev.config.pas.old` inside a temporary Git repo and expects the analyzer to report it.

**Step 2: Run test to verify it fails**
Run: `python3 -m unittest discover -s tests -p 'test_analyze_code_quality.py'`
Expected: FAIL because legacy source backup files are not yet reported.

**Step 3: Write minimal implementation**
- Extend the analyzer with a `legacy_source_backup` rule for files like `src/*.old`.

**Step 4: Run test to verify it passes**
Run: `python3 -m unittest discover -s tests -p 'test_analyze_code_quality.py'`
Expected: PASS.

### Task 2: Remove stale legacy backup from source tree

**Files:**
- Delete: `src/fpdev.config.pas.old`

**Step 1: Verify no callers**
Run: `rg -n "fpdev\.config\.pas\.old|config\.pas\.old" src tests scripts`
Expected: no live references.

**Step 2: Remove the file**
- Delete `src/fpdev.config.pas.old` from the repository.

### Task 3: Final verification

**Files:**
- Verify only

**Step 1: Analyzer verification**
Run: `python3 scripts/analyze_code_quality.py`
Expected: no issues from tracked legacy backups.

**Step 2: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.

**Step 3: Command registry regression verification**
Run: `lazbuild -B tests/test_command_registry.lpi && ./bin/test_command_registry --all`
Expected: PASS.
