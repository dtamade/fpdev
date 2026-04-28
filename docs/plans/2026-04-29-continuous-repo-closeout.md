# Continuous Repo Closeout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 连续收口当前 FPDev 工作树里的验收漂移、计划状态和验证证据，形成可提交的可信状态。

**Architecture:** 不开启新的业务功能或 helper/facade 拆分 wave。先修复已经明确失败的 test inventory drift，再用 focused contract、boundary bundle、Python 全量、Pascal 全量和 Release build 证明当前工作树状态；若验证发现真实失败，按最小修复原则就地处理并重新验证。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Bash, Markdown docs

---

### Task 1: Establish Continuous Closeout Scope

**Files:**
- Create: `docs/plans/2026-04-29-continuous-repo-closeout.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Confirm prior state**

Run:

```bash
git status --porcelain=v1
python3 /home/dtamade/.codex/skills/planning-with-files/scripts/session-catchup.py "$(pwd)"
```

Expected: current large dirty worktree is visible, and no previous-session catchup blocks this pass.

**Step 2: Record the new active phase**

Update root planning files with a new phase focused on continuous closeout:

- test inventory truth sync
- focused contract/boundary verification
- broad Python/Pascal verification
- Release build verification
- pre-commit review and commit

### Task 2: Fix Test Inventory Drift

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `docs/testing.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/MVP_ACCEPTANCE_CRITERIA.md`
- Modify: `docs/MVP_ACCEPTANCE_CRITERIA.en.md`

**Step 1: Reproduce drift**

Run:

```bash
python3 scripts/update_test_stats.py --check
```

Expected before fix: FAIL listing out-of-sync docs.

**Step 2: Apply canonical sync**

Run:

```bash
python3 scripts/update_test_stats.py --write
```

Expected: docs are rewritten from the current discoverable test inventory.

**Step 3: Verify sync**

Run:

```bash
python3 scripts/update_test_stats.py --check
python3 scripts/update_test_stats.py --count
```

Expected: PASS, count prints `335` unless the inventory changes during this session.

### Task 3: Focused Contract And Boundary Verification

**Files:**
- Verify: `tests/test_update_test_stats.py`
- Verify: `tests/test_contributor_docs_contract.py`
- Verify: `tests/test_release_status_wording.py`
- Verify: `tests/test_build_manager_boundary.py`
- Verify: `tests/test_fpc_builder_boundary.py`
- Verify: `tests/test_package_manager_boundary.py`
- Verify: `tests/test_lazarus_manager_version_boundary.py`
- Verify: `tests/test_fpc_source_boundary.py`
- Verify: `tests/test_resource_repo_boundary.py`
- Verify: `tests/test_fpc_manager_bootstrap_boundary.py`

**Step 1: Run focused Python contracts**

Run:

```bash
python3 -m unittest tests.test_update_test_stats tests.test_contributor_docs_contract tests.test_release_status_wording -v
```

Expected: PASS.

**Step 2: Run facade boundary bundle**

Run:

```bash
python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v
```

Expected: PASS.

### Task 4: Broad Verification

**Files:**
- Verify: full Python test suite
- Verify: full Pascal test inventory
- Verify: Release build output

**Step 1: Run Python suite**

Run:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

Expected: PASS.

**Step 2: Run Pascal suite**

Run:

```bash
bash scripts/run_all_tests.sh
```

Expected: PASS for the current discoverable Pascal inventory.

**Step 3: Run Release build**

Run:

```bash
lazbuild -B --build-mode=Release fpdev.lpi
```

Expected: exit code `0`.

### Task 5: Review, Commit, And Close

**Files:**
- Review: all modified files

**Step 1: Inspect final diff**

Run:

```bash
git diff --stat
git diff -- README.md README.en.md docs/testing.md docs/ROADMAP.md docs/MVP_ACCEPTANCE_CRITERIA.md docs/MVP_ACCEPTANCE_CRITERIA.en.md task_plan.md findings.md progress.md docs/plans/2026-04-29-continuous-repo-closeout.md
```

Expected: changes match this closeout scope.

**Step 2: Give pre-commit review conclusion**

State the concise review result before committing, including any residual risk from the already-dirty worktree.

**Step 3: Commit**

Run:

```bash
git add README.md README.en.md docs/testing.md docs/ROADMAP.md docs/MVP_ACCEPTANCE_CRITERIA.md docs/MVP_ACCEPTANCE_CRITERIA.en.md task_plan.md findings.md progress.md docs/plans/2026-04-29-continuous-repo-closeout.md
git commit -m "docs(closeout): sync test inventory truth"
```

Expected: commit succeeds.
