# Style Cleanup Batch 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce low-risk style debt in a testable way by fixing trailing whitespace and a long single-line implementation.

**Architecture:** Add a small Python regression test that checks file formatting constraints for selected files, then minimally edit Pascal files to satisfy constraints without behavior changes.

**Tech Stack:** Python 3 `unittest`, Object Pascal source formatting.

---

### Task 1: Write failing style regression tests

**Files:**
- Create: `tests/test_style_regressions.py`

**Step 1:** Add tests:
- `src/fpdev.package.lockfile.pas` must not contain trailing whitespace.
- `src/fpdev.cmd.package.repo.list.pas` must not contain lines over 120 chars.

**Step 2:** Run RED command:
- `python3 -m unittest tests/test_style_regressions.py -v`
- Expected: FAIL on current style issues.

### Task 2: Apply minimal style fixes

**Files:**
- Modify: `src/fpdev.package.lockfile.pas`
- Modify: `src/fpdev.cmd.package.repo.list.pas`

**Step 1:** Remove trailing whitespace in lockfile file.
**Step 2:** Reformat long one-line alias function in repo list file.

**Step 3:** Run GREEN command:
- `python3 -m unittest tests/test_style_regressions.py -v`
- Expected: PASS.

### Task 3: Verify broader impact

**Step 1:** Run quality analyzer:
- `python3 scripts/analyze_code_quality.py`
- Expected: code_style findings reduced for fixed files.

**Step 2:** Full regression:
- `bash scripts/run_all_tests.sh`
- Expected: all tests pass.

---

## Execution Log (2026-02-12)

### RED
Command:
- `python3 -m unittest tests/test_style_regressions.py -v`

Output (key lines):
- `FAILED (failures=2)`
- `Trailing whitespace found: [(7, '  '), (13, '  '), (42, '  '), (73, '    '), (210, '  ')]`
- `Overlong lines found: [(26, 121)]`

### GREEN
Code changes:
- `src/fpdev.package.lockfile.pas`: removed trailing whitespace.
- `src/fpdev.cmd.package.repo.list.pas`: split `Aliases` one-liner into multi-line implementation.

Command:
- `python3 -m unittest tests/test_style_regressions.py -v`

Output:
- `Ran 2 tests in 0.000s`
- `OK`

### VERIFY
Command:
- `python3 scripts/analyze_code_quality.py`

Output (summary):
- `总问题数: 3`
- `debug_code: 1 个问题`
- `code_style: 1 个问题`
- `hardcoded_constants: 1 个问题`
- `code_style` section no longer reports:
  - `src/fpdev.package.lockfile.pas`
  - `src/fpdev.cmd.package.repo.list.pas`

Command:
- `bash scripts/run_all_tests.sh`

Output (summary):
- `Total:   176`
- `Passed:  176`
- `Failed:  0`
- `Skipped: 0`

### Status
- [x] Task 1 complete
- [x] Task 2 complete
- [x] Task 3 complete
