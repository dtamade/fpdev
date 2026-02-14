# Style Cleanup Batch 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce current style debt reported by analyzer by fixing overlong lines and trailing whitespace in the remaining low-risk files.

**Architecture:** Add a focused Python unittest regression suite for the three files reported by analyzer, run RED to lock failures, apply minimal non-behavioral formatting edits, then run GREEN plus project-wide verification.

**Tech Stack:** Python 3 `unittest`, Object Pascal formatting-only edits.

---

### Task 1: Write failing style regression tests for Batch 2

**Files:**
- Create: `tests/test_style_regressions_batch2.py`

**Step 1:** Add tests:
- `src/fpdev.cmd.lazarus.pas` must not contain lines over 120 chars.
- `src/fpdev.cmd.params.pas` must not contain trailing whitespace.
- `src/fpdev.cross.cache.pas` must not contain trailing whitespace.

**Step 2:** Run RED command:
- `python3 -m unittest tests/test_style_regressions_batch2.py -v`
- Expected: FAIL on current known style issues.

### Task 2: Apply minimal style fixes

**Files:**
- Modify: `src/fpdev.cmd.lazarus.pas`
- Modify: `src/fpdev.cmd.params.pas`
- Modify: `src/fpdev.cross.cache.pas`

**Step 1:** Reformat only overlong lines in lazarus command file.
**Step 2:** Remove trailing whitespace in params and cross cache files.

**Step 3:** Run GREEN command:
- `python3 -m unittest tests/test_style_regressions_batch2.py -v`
- Expected: PASS.

### Task 3: Verify broader impact

**Step 1:** Run quality analyzer:
- `python3 scripts/analyze_code_quality.py`
- Expected: `code_style` issue list no longer includes the three fixed files.

**Step 2:** Full regression:
- `bash scripts/run_all_tests.sh`
- Expected: all tests pass.

---

## Execution Log (2026-02-12)

### RED
Command:
- `python3 -m unittest tests/test_style_regressions_batch2.py -v`

Output (key lines):
- `FAILED (failures=3)`
- `Overlong lines found: [(77, 173), (78, 187), (353, 155), (358, 182), (450, 131), (1017, 122)]`
- `Trailing whitespace found: [(7, '  ')]`
- `Trailing whitespace found: [(22, '    '), ...]`

### GREEN
Code changes:
- `src/fpdev.cmd.lazarus.pas`: reformatted 6 overlong lines into wrapped multi-line declarations/calls.
- `src/fpdev.cmd.params.pas`: removed trailing whitespace.
- `src/fpdev.cross.cache.pas`: removed trailing whitespace.

Command:
- `python3 -m unittest tests/test_style_regressions_batch2.py -v`

Output:
- `Ran 3 tests in 0.001s`
- `OK`

### VERIFY
Command:
- `python3 scripts/analyze_code_quality.py`

Output (summary):
- `总问题数: 3`
- `debug_code: 1 个问题`
- `code_style: 1 个问题`
- `hardcoded_constants: 1 个问题`
- `code_style` now reports other files (`fpdev.build.interfaces.pas`, `fpdev.collections.pas`, `fpdev.cmd.project.template.remove.pas`) and no longer reports this batch's three files.

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

### Post-fix normalization
- Normalized Pascal line endings to repository-consistent CRLF for touched files.
- Re-ran all verification commands after normalization:
  - `python3 -m unittest tests/test_style_regressions_batch2.py -v` => `OK`
  - `python3 scripts/analyze_code_quality.py` => `总问题数: 3`
  - `bash scripts/run_all_tests.sh` => `176/176` pass
