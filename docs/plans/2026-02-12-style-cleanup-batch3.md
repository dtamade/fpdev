# Style Cleanup Batch 3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Continue low-risk style debt reduction by fixing the currently reported style issues in three files.

**Architecture:** Add a focused Python unittest regression suite for the three currently reported files, run RED to capture existing style failures, apply minimal formatting-only edits, then run GREEN and broad verification.

**Tech Stack:** Python 3 `unittest`, Object Pascal formatting-only edits.

---

### Task 1: Write failing style regression tests for Batch 3

**Files:**
- Create: `tests/test_style_regressions_batch3.py`

**Step 1:** Add tests:
- `src/fpdev.build.interfaces.pas` must not contain trailing whitespace.
- `src/fpdev.collections.pas` must not contain lines over 120 chars.
- `src/fpdev.cmd.project.template.remove.pas` must not contain lines over 120 chars.

**Step 2:** Run RED command:
- `python3 -m unittest tests/test_style_regressions_batch3.py -v`
- Expected: FAIL on known style issues.

### Task 2: Apply minimal style fixes

**Files:**
- Modify: `src/fpdev.build.interfaces.pas`
- Modify: `src/fpdev.collections.pas`
- Modify: `src/fpdev.cmd.project.template.remove.pas`

**Step 1:** Remove trailing whitespace in build interfaces file.
**Step 2:** Reformat only overlong lines in collections and template remove files.

**Step 3:** Run GREEN command:
- `python3 -m unittest tests/test_style_regressions_batch3.py -v`
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
- `python3 -m unittest tests/test_style_regressions_batch3.py -v`

Output (key lines):
- `FAILED (failures=3)`
- `Trailing whitespace found: [(33, '    '), ... (119, '    ')]`
- `Overlong lines found: [(59, 171), (60, 181), (62, 128), (63, 130), (64, 151), (102, 163)]`
- `Overlong lines found: [(29, 125)]`

### GREEN
Code changes:
- `src/fpdev.build.interfaces.pas`: removed trailing whitespace.
- `src/fpdev.collections.pas`: wrapped six overlong declarations/signatures.
- `src/fpdev.cmd.project.template.remove.pas`: split one overlong one-liner method.

Command:
- `python3 -m unittest tests/test_style_regressions_batch3.py -v`

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
- `code_style` now reports other files (`fpdev.cmd.project.template.update.pas`, `fpdev.source.pas`, `fpdev.fpc.verify.pas`) and no longer reports this batch's three files.

Command:
- `bash scripts/run_all_tests.sh`

Output (summary):
- `Total:   176`
- `Passed:  176`
- `Failed:  0`
- `Skipped: 0`

### Post-fix normalization
- Normalized `src/fpdev.collections.pas` line endings back to CRLF to avoid mixed newline noise.
- Re-ran verification after normalization:
  - `python3 -m unittest tests/test_style_regressions_batch3.py -v` => `OK`
  - `python3 scripts/analyze_code_quality.py` => `总问题数: 3`
  - `bash scripts/run_all_tests.sh` => `176/176` pass

### Status
- [x] Task 1 complete
- [x] Task 2 complete
- [x] Task 3 complete
