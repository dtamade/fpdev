# Task Tree Drain And BuildManager Backlog Closure Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把当前仍然挂在 `todos/` 与历史 planning artifacts 里的可执行 BuildManager 任务树清空，并用 focused tests、docs contracts 与全量验证证明这些节点不是简单删待办。

**Architecture:** 不重新打开 facade/helper 大拆分。只处理当前任务树中能低风险闭环的 BuildManager backlog：日志轮转、沙箱产物 manifest、严格清单聚合失败报告、自托管 runner 脚本、FullBuild preflight gate truth-sync，以及陈旧 `in_progress` 记录归档。

**Tech Stack:** Object Pascal, Python unittest, Bash, Markdown docs

---

### Task 1: Inventory Remaining Task Tree

**Files:**
- Read: `task_plan.md`
- Read: `progress.md`
- Read: `findings.md`
- Read: `todos/*.md`

**Steps:**
- Confirm latest commit and clean baseline.
- Identify remaining unchecked checklist items.
- Separate real backlog from historical/non-active candidate notes.

### Task 2: Add RED Contracts

**Files:**
- Modify: `tests/test_build_logger.lpr`
- Modify: `tests/test_build_testresultsflow.lpr`
- Modify: `tests/fpdev.build.manager/test_build_manager_make_missing.lpr`
- Modify: `tests/test_build_fullbuildflow.lpr`
- Modify: `tests/test_build_manager_docs_truth_contract.py`

**Steps:**
- Add focused tests for log rotation, artifact manifest, strict aggregate failure reporting, and FullBuild preflight gate.
- Add docs/todos contract that fails while active BuildManager backlog still has unchecked items.

### Task 3: Minimal Implementation

**Files:**
- Modify: `src/fpdev.build.logger.pas`
- Modify: `src/fpdev.build.testresultsflow.pas`
- Modify: `src/fpdev.build.strict.pas`
- Add: `scripts/build_manager_self_hosted_ci.sh`

**Steps:**
- Implement bounded BuildManager log rotation.
- Emit sandbox `artifact-manifest.txt` with relative path, size, and SHA256.
- Make strict INI bool parsing robust for `true/false/yes/no/1/0`.
- Continue strict validation across configured sections and report all failures.
- Add local self-hosted CI script for focused BuildManager checks.

### Task 4: Truth Sync

**Files:**
- Modify: `docs/build-manager.md`
- Modify: `docs/build-manager.en.md`
- Modify: `todos/fpdev.build.manager.md`
- Modify: `todos/fpdev.git2.md`
- Modify: `todos/测试工程后续优化.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Steps:**
- Mark implemented BuildManager backlog items complete.
- Move broad test-project cleanup notes out of the active task tree.
- Close stale historical `in_progress` status entries that were superseded by later complete phases.

### Task 5: Verify And Commit

Run focused tests, docs contracts, full Python tests, full Pascal tests, and Release build. Then give a short pre-commit review conclusion and commit.
