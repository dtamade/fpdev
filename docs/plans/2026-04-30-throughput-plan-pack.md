# FPDev Throughput Plan Pack

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement each selected plan task-by-task.

**Goal:** Replace low-throughput micro closeouts with a plan-pack cadence that supports larger execution batches in `fpdev`.

**Architecture:** Use one master routing plan plus three executable subplans. Keep the Git2 architecture lane split into a prerequisite test-lane wave and a dependent decoupling wave, while letting the release-packaging lane proceed independently.

**Tech Stack:** Object Pascal / Free Pascal, Lazarus, Python unittest, Bash release scripts, GitHub Actions workflow contracts

---

## Why the previous cadence was slow

1. The recent work closed real drift, but in units that were too small.
2. Planning lived mostly inside `task_plan.md` phases instead of reusable execution plans under `docs/plans/`.
3. The next meaningful architecture wave (`git2.impl` decoupling) was recognized, but not converted into an executable backlog with prerequisites and gates.

## Plan Pack

### Lane A: Git2 Modern/Legacy Test Lane Split

- **Plan file:** `docs/plans/2026-04-30-git2-test-lane-split-wave.md`
- **ROI:** High
- **Risk:** Low to medium
- **Purpose:** Stop mixing modern-interface coverage and legacy-wrapper coverage in the same focused runners.
- **Why first:** It creates the safety net needed for the real `git2.impl` decoupling wave.

### Lane B: Git2.impl Decoupling From fpdev.git2

- **Plan file:** `docs/plans/2026-04-30-git2-impl-decoupling-wave.md`
- **ROI:** High
- **Risk:** Medium to high
- **Depends on:** Lane A
- **Purpose:** Remove the current `src/git2.impl.pas -> src/fpdev.git2.pas` dependency so the “modern interface” path stops being a thin adapter over the deprecated concrete wrapper.

### Lane C: Release Packaging Step Consolidation

- **Plan file:** `docs/plans/2026-04-30-release-packaging-consolidation-wave.md`
- **ROI:** Medium
- **Risk:** Low to medium
- **Depends on:** None
- **Purpose:** Collapse duplicated release-asset packaging shell blocks into shared script entrypoints so the release lane can evolve without repeated YAML/script drift.

## Execution Order

1. Execute Lane A immediately.
2. Execute Lane C in the next parallel-safe slot or right after Lane A.
3. Execute Lane B after Lane A is green.

## Commit cadence

1. One commit per lane closeout.
2. No more one-commit-per-tiny-doc-fix unless the change is a true blocker discovered mid-wave.

## Acceptance model

### Lane A minimum gate

- `python3 -m unittest tests.test_official_docs_cli_contract tests.test_contributor_docs_contract -v`
- `python3 -m unittest discover -s tests -p 'test_*.py'`
- selected Pascal focused Git2 runners from the plan

### Lane B minimum gate

- `python3 -m unittest discover -s tests -p 'test_*.py'`
- `bash scripts/run_all_tests.sh`
- `lazbuild -B --build-mode=Release fpdev.lpi`

### Lane C minimum gate

- `python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract tests.test_release_docs_contract -v`
- `bash -n scripts/assemble_release_ready_bundle.sh`
- `bash -n scripts/build_release.sh`

