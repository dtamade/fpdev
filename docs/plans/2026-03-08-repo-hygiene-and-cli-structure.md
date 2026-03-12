# Repo Hygiene And CLI Structure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix test temp-directory leakage and config isolation, unify published test-count/project-status numbers, and reduce CLI entrypoint duplication without changing external behavior.

**Architecture:** Keep the existing command-registry architecture intact, but pull global flag handling into a small reusable preparse layer so `fpdev.lpr` stops mixing bootstrap flags and command dispatch. Keep documentation and CI synchronized by deriving published counts from the same discovery rules used by the test runner/CI. For test hygiene, move temp assets under system temp or isolated roots and ensure recursive cleanup.

**Tech Stack:** Object Pascal (FPC/Lazarus), shell scripts, GitHub Actions, Markdown docs.

---

### Task 1: Inventory exact integration points

**Files:**
- Modify: `docs/plans/2026-03-08-repo-hygiene-and-cli-structure.md`
- Inspect: `tests/test_project_test.lpr`
- Inspect: `tests/test_command_registry.lpr`
- Inspect: `src/fpdev.lpr`
- Inspect: `src/fpdev.command.registry.pas`
- Inspect: `scripts/run_all_tests.sh`
- Inspect: `.github/workflows/ci.yml`
- Inspect: `README.md`
- Inspect: `README.en.md`
- Inspect: `docs/testing.md`

**Step 1:** Confirm temp-directory creation and cleanup code paths.

**Step 2:** Confirm config-manager default path usage in tests.

**Step 3:** Confirm current test discovery rules in CI and runner.

**Step 4:** Confirm current global-flag flow in `src/fpdev.lpr`.

### Task 2: Write failing regression coverage for test hygiene

**Files:**
- Modify: `tests/test_project_test.lpr`
- Modify: `tests/test_command_registry.lpr`

**Step 1:** Add assertions that temp directories live under temp roots instead of repo root.

**Step 2:** Add assertions that registry-dispatch tests use isolated config paths instead of implicit user config.

**Step 3:** Run focused tests to see failures before implementation.

### Task 3: Implement minimal hygiene fixes

**Files:**
- Modify: `tests/test_project_test.lpr`
- Modify: `tests/test_command_registry.lpr`

**Step 1:** Switch test temp roots to system temp with unique names.

**Step 2:** Implement recursive cleanup for generated directories.

**Step 3:** Inject dedicated temp config paths into registry-dispatch tests.

**Step 4:** Re-run focused tests until green.

### Task 4: Unify published test counts and status wording

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `docs/testing.md`
- Modify: `.github/workflows/ci.yml`

**Step 1:** Compute current test count using CI discovery rules.

**Step 2:** Update docs to the same verified count/date wording.

**Step 3:** Tighten CI threshold so it reflects the documented baseline.

### Task 5: Reduce `fpdev.lpr` branching without changing behavior

**Files:**
- Modify: `src/fpdev.lpr`
- Inspect: `src/fpdev.command.registry.pas`

**Step 1:** Extract helper(s) for global flag preprocessing and argument normalization.

**Step 2:** Keep current flag semantics but remove duplicated version/help/data-root handling.

**Step 3:** Run focused CLI/registry tests to verify no regressions.

### Task 6: Verify end-to-end

**Files:**
- Verify: `tests/test_project_test.lpr`
- Verify: `tests/test_command_registry.lpr`
- Verify: `src/fpdev.lpr`
- Verify: `README.md`
- Verify: `README.en.md`
- Verify: `docs/testing.md`
- Verify: `.github/workflows/ci.yml`

**Step 1:** Run focused tests for the changed Pascal tests.

**Step 2:** Run command-registry test binary.

**Step 3:** Run the main test runner if feasible.

**Step 4:** Summarize results with exact evidence and any remaining follow-ups.
