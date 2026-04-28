# Install Contract, Docs, and Lazarus Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 收口 install 栈最后一批高杠杆缺口：补齐 FPC binary fallback 契约守卫、锁住 Lazarus install manager/flow 边界、同步用户文档到当前 install 语义，并完成 focused 与全量回归。

**Architecture:** 保持现有 install 分层不回退。FPC 继续由 `binaryflow` 负责 manifest/repo/sourceforge 获取顺序契约，由 install/report flow 负责用户级 install 输出；Lazarus 继续由 `fpdev.lazarus.commandflow` 负责 install plan 与执行，`fpdev.lazarus.manager` 只做版本校验、已有安装短路、计划装配与异常包装。文档同步只反映当前真实 CLI 契约，不再保留“默认从源码开始”的旧叙事。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Markdown docs, fpdev install flows

---

### Task 1: Record the current wave in planning files

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`
- Reference: `docs/plans/2026-04-11-fpc-install-output-and-boundary-wave.md`

**Step 1: Append the new active goal and phase stub**

- 记录这轮目标：
  - FPC binary acquisition/fallback contract 守卫
  - Lazarus install boundary/output 守卫
  - README / FAQ / QUICKSTART / MANIFEST-USAGE 同步

**Step 2: Keep implementation notes scoped**

- 明确 FPC output consolidation 已完成，本轮不重复拆 installreportflow
- 明确新增重点是 Lazarus install 分层和用户文档真实性

### Task 2: Lock FPC binary acquisition fallback contract with RED tests

**Files:**
- Modify: `tests/test_fpc_installer_binaryflow.lpr`
- Reference: `src/fpdev.fpc.installer.binaryflow.pas`

**Step 1: Write failing tests**

- 新增断言覆盖：
  - manifest exception 仍继续 repo/sourceforge fallback
  - repo exception 仍继续 sourceforge fallback
  - all-fallback-fail 时输出包含最终统一失败总结
  - sourceforge 成功时不应丢失 manifest/repo 已尝试语义

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installer_binaryflow.lpr`

Run: `/tmp/fpdev-plan-bin/test_fpc_installer_binaryflow`

Expected: FAIL on the new fallback/output assertions.

**Step 3: Write minimal implementation**

- 只在 `src/fpdev.fpc.installer.binaryflow.pas` 收口缺失的 fallback 与 summary
- 不把 install output owner 拉回 manager/CLI

**Step 4: Re-run test to verify it passes**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installer_binaryflow.lpr && /tmp/fpdev-plan-bin/test_fpc_installer_binaryflow`

Expected: PASS

### Task 3: Lock Lazarus install boundary and output with RED tests

**Files:**
- Create: `tests/test_lazarus_install_boundary.py`
- Modify: `tests/test_lazarus_flow.lpr`
- Reference: `src/fpdev.lazarus.manager.pas`
- Reference: `src/fpdev.lazarus.commandflow.pas`

**Step 1: Write failing boundary and flow tests**

- Python boundary assertions:
  - `src/fpdev.lazarus.manager.pas` 必须调用 `CreateLazarusInstallPlanCore(...)`
  - `src/fpdev.lazarus.manager.pas` 必须调用 `ExecuteLazarusInstallPlanCore(...)`
  - manager 不得直接输出 `fallback to source build`
  - manager 不得直接输出 `fpdev lazarus configure`
  - manager 不得直接重写 download/build/setup error wording
- Pascal flow assertions:
  - install flow 成功时输出统一 completion banner
  - install flow 成功时输出 `fpdev lazarus use <version>` next step
  - configure warning 仍然只是 warning，不影响成功返回

**Step 2: Run tests to verify RED**

Run: `python3 -m unittest tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_lazarus_flow.lpr`

Run: `/tmp/fpdev-plan-bin/test_lazarus_flow`

Expected: FAIL on the new boundary/output assertions.

**Step 3: Write minimal implementation**

- 如果需要，共享一个很小的 Lazarus install report helper
- 保持 `commandflow` 为 install output owner，manager 只负责 orchestration

**Step 4: Re-run tests to verify they pass**

Run: `python3 -m unittest tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_lazarus_flow.lpr && /tmp/fpdev-plan-bin/test_lazarus_flow`

Expected: PASS

### Task 4: Sync user-facing install docs to current contract

**Files:**
- Modify: `README.md`
- Modify: `docs/FAQ.md`
- Modify: `docs/FAQ.en.md`
- Modify: `docs/QUICKSTART.md`
- Modify: `docs/QUICKSTART.en.md`
- Modify: `docs/MANIFEST-USAGE.md`
- Optional Modify: `CHANGELOG.md`

**Step 1: Update command examples**

- FPC quickstart 默认示例改为 `fpdev fpc install 3.2.2`
- 把 `--from-source` 明确改成“显式源码模式”而不是默认建议起点
- 补 `--offline` / `--no-cache` / cache-only 恢复语义
- 写清 manifest/repo/sourceforge 是 binary acquisition fallback，不是用户需要手动切换的模式

**Step 2: Update Lazarus wording**

- 写清 Lazarus 当前 install 路径实际为 source build
- 说明默认 install 也会提示 binary path unavailable 并回退源码构建
- 给出 `fpdev lazarus use <version>` / `fpdev lazarus configure <version>` 作为后续步骤

**Step 3: Run docs contract**

Run: `python3 -m unittest tests.test_contributor_docs_contract -v`

Expected: PASS

### Task 5: Focused regression and full verification

**Files:**
- Verify only

**Step 1: Run focused Python suites**

Run: `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract tests.test_contributor_docs_contract -v`

Expected: PASS

**Step 2: Run focused Pascal suites**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installer_binaryflow.lpr && /tmp/fpdev-plan-bin/test_fpc_installer_binaryflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installversionflow.lpr && /tmp/fpdev-plan-bin/test_fpc_installversionflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_lazarus_flow.lpr && /tmp/fpdev-plan-bin/test_lazarus_flow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_lazarus_update.lpr && /tmp/fpdev-plan-bin/test_lazarus_update`

Expected: PASS

**Step 3: Run repository regression**

Run: `bash scripts/run_all_tests.sh`

Expected: PASS

**Step 4: Final planning record update**

- 在 `task_plan.md` 追加本轮 phase 和 notes
- 在 `progress.md` 记录 RED/GREEN 证据与 focused/full 回归结果
- 在 `findings.md` 记录 Lazarus install output owner 与 FPC binary fallback contract 结论
