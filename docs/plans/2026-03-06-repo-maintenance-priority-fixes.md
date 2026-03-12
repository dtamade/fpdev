# Repo Maintenance Priority Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce command-registration drift, tighten repository hygiene, and expand local quality checks for generated artifacts.

**Architecture:** Extract the command-registration import list into a single Pascal aggregation unit so both the main program and the registry contract test trigger the exact same `initialization` side effects. Extend the Python quality analyzer with repository-level hygiene checks driven by focused unit tests, and align `.gitignore` with those checks so generated Python bytecode is not tracked again.

**Tech Stack:** Object Pascal (Free Pascal/Lazarus), Python `unittest`, shell-based build/test commands.

---

### Task 1: Add command import aggregation unit

**Files:**
- Create: `src/fpdev.cmd.imports.pas`
- Modify: `src/fpdev.lpr`
- Modify: `tests/test_command_registry.lpr`

**Step 1: Write the failing test**
- Create a focused Pascal test program that imports only the new aggregation unit plus registry interfaces, then asserts representative commands resolve from the global registry.

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_command_imports.lpr`
Expected: FAIL because `fpdev.cmd.imports` does not exist yet.

**Step 3: Write minimal implementation**
- Add `src/fpdev.cmd.imports.pas` containing the existing command-unit `uses` list.
- Replace duplicated command-unit imports in `src/fpdev.lpr` and `tests/test_command_registry.lpr` with the new unit.

**Step 4: Run test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_command_imports.lpr && ./bin/test_command_imports`
Expected: PASS with representative commands resolving.

### Task 2: Expand analyzer hygiene coverage

**Files:**
- Modify: `scripts/analyze_code_quality.py`
- Modify: `tests/test_analyze_code_quality.py`

**Step 1: Write the failing test**
- Add Python unit tests proving the analyzer reports tracked/generated Python artifacts such as `scripts/__pycache__/x.pyc` and ignores clean repos.

**Step 2: Run test to verify it fails**
Run: `python3 -m unittest tests.test_analyze_code_quality.AnalyzeCodeQualityTests.test_tracked_python_cache_is_reported`
Expected: FAIL because analyzer has no repository hygiene check yet.

**Step 3: Write minimal implementation**
- Add a repository hygiene analysis function that scans tracked/generated files outside `src/` and returns structured issues.
- Include this analysis in the main report flow without disturbing existing issue types.

**Step 4: Run test to verify it passes**
Run: `python3 -m unittest tests.test_analyze_code_quality`
Expected: PASS for the updated analyzer suite.

### Task 3: Align ignore rules with hygiene policy

**Files:**
- Modify: `.gitignore`

**Step 1: Implement minimal ignore coverage**
- Add `__pycache__/` and `*.pyc` ignore rules so generated Python bytecode stays out of Git.

**Step 2: Verify behavior**
Run: `git check-ignore -v scripts/__pycache__/example.pyc`
Expected: matched by the new `.gitignore` rules.

### Task 4: Final verification

**Files:**
- Verify only

**Step 1: Focused Pascal verification**
Run: `lazbuild -B tests/test_command_registry.lpi && ./bin/test_command_registry --all`
Expected: PASS.

**Step 2: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.

**Step 3: Python verification**
Run: `python3 -m unittest tests.test_analyze_code_quality`
Expected: PASS.
