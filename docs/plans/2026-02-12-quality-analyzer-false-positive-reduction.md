# Quality Analyzer False-Positive Reduction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce `scripts/analyze_code_quality.py` debug-code false positives so治理信号可用于真实优先级决策。

**Architecture:** Add explicit regression tests for analyzer behavior, then minimally adjust debug detection rules to ignore known non-debug patterns (`output.console` wrappers and file-handle writes) while preserving real debug output detection.

**Tech Stack:** Python 3 (`unittest`), existing quality script (`scripts/analyze_code_quality.py`).

---

### Task 1: Write Failing Regression Tests For Analyzer False Positives

**Files:**
- Create: `tests/test_analyze_code_quality.py`
- Test: `tests/test_analyze_code_quality.py`

**Step 1: Write the failing test**

Add tests covering:
- `Write(Source, '...')` should not be flagged as debug output.
- `fpdev.output.console.pas` wrapper methods (`Write`/`WriteLn`) should not be flagged as debug output.
- Real `WriteLn('debug')` should still be flagged.

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_analyze_code_quality.py -v`
Expected: FAIL at least on false-positive assertions.

### Task 2: Implement Minimal Analyzer Rule Fixes

**Files:**
- Modify: `scripts/analyze_code_quality.py`
- Test: `tests/test_analyze_code_quality.py`

**Step 1: Write minimal implementation**

In `analyze_temp_files_and_debug_code()`:
- Skip `has_debug_write` detection for `fpdev.output.console.pas`.
- Ignore `write/writeln` calls that target a file handle first argument pattern: `Write(<identifier>, ...)` / `WriteLn(<identifier>, ...)`.
- Keep existing real debug write detection for standard output lines.

**Step 2: Run test to verify it passes**

Run: `python3 -m unittest tests/test_analyze_code_quality.py -v`
Expected: PASS.

### Task 3: Verify Quality Scan Behavior After Fix

**Files:**
- Modify: none
- Test: script runtime behavior

**Step 1: Run quality scan**

Run: `python3 scripts/analyze_code_quality.py`
Expected: no false-positive hits from `fpdev.output.console.pas` and `Write(Source, ...)` sample pattern.

**Step 2: Basic project regression**

Run: `bash scripts/run_all_tests.sh`
Expected: pass; no Pascal behavior change introduced by script-only fix.
