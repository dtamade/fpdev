# Next Wave Package Config Entry Refactors Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Continue shrinking mixed-responsibility units by extracting package pure logic, isolating config path resolution for tests, and narrowing CLI entry preprocessing responsibilities.

**Architecture:** Keep `TPackageManager`, `TConfigManager`, and `src/fpdev.lpr` as orchestration/entry layers. Move pure data/path/argument normalization logic behind focused helpers with regression tests first. Preserve command behavior and existing CLI contracts.

**Tech Stack:** Object Pascal (FPC/Lazarus), fpcunit-style Pascal tests, Lazarus build/test workflow.

---

### Task 1: Package pure helper slice

**Files:**
- Modify: `src/fpdev.cmd.package.pas`
- Modify/Create: helper units near `src/fpdev.cmd.package.*.pas`
- Test: focused existing package tests

**Step 1: Write the failing test**
- Add a focused regression around any still-inline pure create/validate/publish logic.

**Step 2: Run test to verify it fails**
- Run only the focused package test binary.

**Step 3: Write minimal implementation**
- Extract pure logic into a helper and keep manager as orchestration.

**Step 4: Run test to verify it passes**
- Re-run focused package tests.

### Task 2: Config path isolation

**Files:**
- Modify: `src/fpdev.config.managers.pas`
- Modify: config-related tests such as `tests/test_command_registry.lpr`

**Step 1: Write the failing test**
- Add a test proving default config path resolution can be redirected away from the real user directory.

**Step 2: Run test to verify it fails**
- Run the focused config/registry test binary.

**Step 3: Write minimal implementation**
- Add injectable/configurable config path resolution and update tests to use temp roots.

**Step 4: Run test to verify it passes**
- Re-run focused config tests.

### Task 3: CLI entry preprocessing seam

**Files:**
- Modify: `src/fpdev.lpr`
- Modify/Create: focused helper/unit if needed
- Test: registry or CLI smoke tests covering global argument behavior

**Step 1: Write the failing test**
- Add coverage for a global flag/preparse path that currently depends on inline logic.

**Step 2: Run test to verify it fails**
- Run the focused CLI/registry test binary.

**Step 3: Write minimal implementation**
- Extract preparse/normalization into a helper or unify into registry-facing preprocessing.

**Step 4: Run test to verify it passes**
- Re-run focused CLI tests.

### Task 4: Verify the wave

**Files:**
- Verify only

**Step 1: Run targeted tests**
- Run the touched focused suites first.

**Step 2: Run full verification**
- Run `lazbuild -B fpdev.lpi`
- Run `bash scripts/run_all_tests.sh`
