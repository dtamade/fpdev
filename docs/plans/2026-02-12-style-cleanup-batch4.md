# Style Cleanup Batch 4 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce the currently reported style debt by fixing overlong lines and trailing whitespace in the latest analyzer targets.

**Architecture:** Add a focused Python unittest regression suite for the three files from the current analyzer report, run RED to capture failures, apply minimal formatting-only changes, then run GREEN and full verification.

**Tech Stack:** Python 3 `unittest`, Object Pascal formatting-only edits.

---

### Task 1: Write failing style regression tests for Batch 4

**Files:**
- Create: `tests/test_style_regressions_batch4.py`

**Step 1:** Add tests:
- `src/fpdev.cmd.project.template.update.pas` must not contain lines over 120 chars.
- `src/fpdev.source.pas` must not contain lines over 120 chars.
- `src/fpdev.fpc.verify.pas` must not contain lines over 120 chars.
- `src/fpdev.fpc.verify.pas` must not contain trailing whitespace.

**Step 2:** Run RED command:
- `python3 -m unittest tests/test_style_regressions_batch4.py -v`
- Expected: FAIL on current known style issues.

### Task 2: Apply minimal style fixes

**Files:**
- Modify: `src/fpdev.cmd.project.template.update.pas`
- Modify: `src/fpdev.source.pas`
- Modify: `src/fpdev.fpc.verify.pas`

**Step 1:** Reformat only overlong lines in the three files.
**Step 2:** Remove trailing whitespace in `src/fpdev.fpc.verify.pas`.

**Step 3:** Run GREEN command:
- `python3 -m unittest tests/test_style_regressions_batch4.py -v`
- Expected: PASS.

### Task 3: Verify broader impact

**Step 1:** Run quality analyzer:
- `python3 scripts/analyze_code_quality.py`
- Expected: `code_style` no longer includes this batch's three files.

**Step 2:** Full regression:
- `bash scripts/run_all_tests.sh`
- Expected: all tests pass.

---

## Execution Log (2026-02-12)

### RED
Command:
- `python3 -m unittest tests/test_style_regressions_batch4.py -v`

Output (key lines):
- `FAILED (failures=4)`
- `Trailing whitespace found: [(78, '      '), ... (223, '      ')]`
- `Overlong lines found: [(57, 121), (184, 122)]`
- `Overlong lines found: [(10, 129), (73, 129), (167, 139)]`
- `Overlong lines found: [(29, 125)]`

### GREEN
Code changes:
- `src/fpdev.cmd.project.template.update.pas`: split one overlong one-liner method.
- `src/fpdev.source.pas`: wrapped 3 overlong declarations/assignments.
- `src/fpdev.fpc.verify.pas`: wrapped 2 overlong lines and removed trailing whitespace.

Command:
- `python3 -m unittest tests/test_style_regressions_batch4.py -v`

Output:
- `Ran 4 tests in 0.001s`
- `OK`

### VERIFY
Command:
- `python3 scripts/analyze_code_quality.py`

Output (summary):
- `总问题数: 3`
- `debug_code: 1 个问题`
- `code_style: 1 个问题`
- `hardcoded_constants: 1 个问题`
- `code_style` now reports other files (`fpdev.cmd.package.pas`, `fpdev.config.interfaces.pas`, `fpdev.toml.parser.pas`) and no longer reports this batch's three files.

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
