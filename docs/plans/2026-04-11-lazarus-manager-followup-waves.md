# Lazarus Manager Follow-up Waves Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.manager.pas`，把 pathflow、install callbacks、runtime/IDE actions 进一步下沉到独立 helper，并同步当前 hotspot 文档与契约。

**Architecture:** 保持现有 Lazarus 分层不回退。`fpdev.lazarus.commandflow` 继续持有 install/update/launch/configure plan core 与用户输出；`fpdev.lazarus.manager` 保留 config access、registry access、外层异常包装与 facade dispatch；新增 helper 只承接路径解析、install callback 实现、runtime action 执行，不把 install 文案或 CLI 叙事重新吸回 manager。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Markdown docs

---

### Task 1: Record Phase 38 in planning files

**Files:**
- Create: `docs/plans/2026-04-11-lazarus-manager-followup-waves.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Set the active goal**

- 记录本轮目标为 Lazarus manager follow-up waves：
  - `pathflow`
  - `install callbacks`
  - `runtime/IDE actions`
  - `docs/contracts`

**Step 2: Record the route and guardrails**

- 明确 CLI/root shell 已不是当前主要问题中心
- 明确 `tests/test_lazarus_configure_workflow.lpr`、`tests/test_lazarus_update.lpr`、`tests/test_cli_lazarus.lpr`、`tests/test_lazarus_management.lpr` 是本轮强护栏

### Task 2: Add RED tests for pathflow extraction

**Files:**
- Create: `tests/test_lazarus_manager_path_boundary.py`
- Create: `tests/test_lazarus_pathflow.lpr`
- Reference: `tests/test_lazarus_configure_workflow.lpr`

**Step 1: Add boundary assertions**

- `src/fpdev.lazarus.manager.pas` 必须引入 `fpdev.lazarus.pathflow`
- manager 必须委托 path helper，而不是继续本地拼：
  - 版本默认安装路径
  - install path -> executable path
  - configured/default install path 解析
  - installed state 判定

**Step 2: Add direct helper coverage**

- `BuildLazarusVersionInstallPathCore(...)`
- `BuildLazarusExecutablePathFromInstallPathCore(...)`
- `ResolveLazarusInstallPathCore(...)`
- `IsLazarusVersionInstalledCore(...)`

重点覆盖：
- configured custom install path 优先于默认路径
- configured executable 缺失但默认路径存在时回退默认路径
- 两边都不存在时仍回退 configured path，保持 config-oriented 行为

**Step 3: Run tests to verify RED**

Run: `python3 -m unittest tests.test_lazarus_manager_path_boundary -v`

Run: `mkdir -p /tmp/fpdev-lazarus-pathflow-bin-red /tmp/fpdev-lazarus-pathflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-pathflow-bin-red -FU/tmp/fpdev-lazarus-pathflow-lib-red tests/test_lazarus_pathflow.lpr`

Run: `/tmp/fpdev-lazarus-pathflow-bin-red/test_lazarus_pathflow`

Expected: FAIL because `fpdev.lazarus.pathflow` or its helpers do not exist yet.

### Task 3: Implement the minimal pathflow slice

**Files:**
- Create: `src/fpdev.lazarus.pathflow.pas`
- Modify: `src/fpdev.lazarus.manager.pas`

**Step 1: Add pure path/install-state helpers**

- 新 helper 只承接：
  - 默认安装路径拼接
  - executable path 拼接
  - configured/default path 解析
  - install-state 判定

**Step 2: Rewire manager**

- `GetVersionInstallPath`
- `GetExecutablePathFromInstallPath`
- `GetResolvedInstallPath`
- `IsVersionInstalled`

最小化改为委托 helper，不改 custom install path 语义。

**Step 3: Run focused verification**

Run: `python3 -m unittest tests.test_lazarus_manager_path_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-pathflow-bin -FU/tmp/fpdev-lazarus-pathflow-lib tests/test_lazarus_pathflow.lpr && /tmp/fpdev-lazarus-pathflow-bin/test_lazarus_pathflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-configure-bin -FU/tmp/fpdev-lazarus-configure-lib tests/test_lazarus_configure_workflow.lpr && /tmp/fpdev-lazarus-configure-bin/test_lazarus_configure_workflow`

Expected: PASS

### Task 4: Add RED tests for install callback extraction

**Files:**
- Create: `tests/test_lazarus_manager_callbacks_boundary.py`
- Create: `tests/test_lazarus_installcallbacks.lpr`
- Reference: `tests/test_lazarus_update.lpr`
- Reference: `tests/test_lazarus_callback_contract.py`

**Step 1: Add boundary assertions**

- manager 必须引入 `fpdev.lazarus.installcallbacks`
- `DownloadSource` / `BuildFromSource` / `SetupEnvironment` 必须委托 helper
- install plan callback wiring 仍必须经过命名 adapter，而不是直接传 overloaded `ConfigureIDE`

**Step 2: Add direct helper coverage**

- 下载逻辑保留 registry git tag / repository URL 优先级
- build 逻辑保留 same-process `PATH` 传递
- setup environment 逻辑保留 `SourceURL` 持久化与 configured install path

**Step 3: Run tests to verify RED**

Run: `python3 -m unittest tests.test_lazarus_manager_callbacks_boundary tests.test_lazarus_callback_contract -v`

Run: `mkdir -p /tmp/fpdev-lazarus-callbacks-bin-red /tmp/fpdev-lazarus-callbacks-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-callbacks-bin-red -FU/tmp/fpdev-lazarus-callbacks-lib-red tests/test_lazarus_installcallbacks.lpr`

Run: `/tmp/fpdev-lazarus-callbacks-bin-red/test_lazarus_installcallbacks`

Expected: FAIL because the callback helper unit or symbols do not exist yet.

### Task 5: Implement the install callback slice

**Files:**
- Create: `src/fpdev.lazarus.installcallbacks.pas`
- Modify: `src/fpdev.lazarus.manager.pas`

**Step 1: Add helper functions**

- 承接：
  - `DownloadSource`
  - `BuildFromSource`
  - `SetupEnvironment`

保持 manager-owned callback signatures 不变。

**Step 2: Keep configure callback wiring stable**

- `RunConfigureIDEWithOutputs` 继续作为 install-plan callback adapter
- 不把 `ConfigureIDE` 的用户文案或 plan core 搬进 installcallbacks

**Step 3: Run focused verification**

Run: `python3 -m unittest tests.test_lazarus_manager_callbacks_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-callbacks-bin -FU/tmp/fpdev-lazarus-callbacks-lib tests/test_lazarus_installcallbacks.lpr && /tmp/fpdev-lazarus-callbacks-bin/test_lazarus_installcallbacks`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr && /tmp/fpdev-lazarus-update-bin/test_lazarus_update`

Expected: PASS

### Task 6: Add RED tests for runtime/IDE action extraction

**Files:**
- Create: `tests/test_lazarus_manager_runtime_boundary.py`
- Create: `tests/test_lazarus_runtimeactions.lpr`
- Reference: `tests/test_lazarus_configure_workflow.lpr`
- Reference: `tests/test_cli_lazarus.lpr`

**Step 1: Add boundary assertions**

- manager 必须引入 `fpdev.lazarus.runtimeactions`
- `TestInstallation` / `LaunchIDE` / `ConfigureIDE` 必须委托 helper
- manager 不得重新内联 `TProcessExecutor.Execute(... '--version' ...)` 或 launch/configure execution logic

**Step 2: Add direct helper coverage**

- TestInstallation 保留 configured custom install path 解析
- LaunchIDE 保留 default configured version missing-from-registry 行为
- ConfigureIDE 保留 configured FPC version override 与 config-root 解析

**Step 3: Run tests to verify RED**

Run: `python3 -m unittest tests.test_lazarus_manager_runtime_boundary -v`

Run: `mkdir -p /tmp/fpdev-lazarus-runtime-bin-red /tmp/fpdev-lazarus-runtime-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-runtime-bin-red -FU/tmp/fpdev-lazarus-runtime-lib-red tests/test_lazarus_runtimeactions.lpr`

Run: `/tmp/fpdev-lazarus-runtime-bin-red/test_lazarus_runtimeactions`

Expected: FAIL because the runtime helper unit or symbols do not exist yet.

### Task 7: Implement the runtime/IDE action slice

**Files:**
- Create: `src/fpdev.lazarus.runtimeactions.pas`
- Modify: `src/fpdev.lazarus.manager.pas`

**Step 1: Add helper functions**

- 承接：
  - `TestInstallation`
  - `LaunchIDE`
  - `ConfigureIDE`

**Step 2: Rewire manager**

- manager 保留 config/settings access、exception wrapper、callback adapter
- helper 接受已解析的 plan/config/runtime 依赖，不重新访问 manager state

**Step 3: Run focused verification**

Run: `python3 -m unittest tests.test_lazarus_manager_runtime_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-runtime-bin -FU/tmp/fpdev-lazarus-runtime-lib tests/test_lazarus_runtimeactions.lpr && /tmp/fpdev-lazarus-runtime-bin/test_lazarus_runtimeactions`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-configure2-bin -FU/tmp/fpdev-lazarus-configure2-lib tests/test_lazarus_configure_workflow.lpr && /tmp/fpdev-lazarus-configure2-bin/test_lazarus_configure_workflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-cli-bin -FU/tmp/fpdev-lazarus-cli-lib tests/test_cli_lazarus.lpr && /tmp/fpdev-lazarus-cli-bin/test_cli_lazarus`

Expected: PASS

### Task 8: Sync hotspot docs and contracts

**Files:**
- Modify: `docs/history/B171-large-files-report.md`
- Modify: `tests/test_contributor_docs_contract.py`

**Step 1: Update current worktree truth**

- 同步 `src/fpdev.lazarus.manager.pas` 新行数
- 同步新增 helper：
  - `src/fpdev.lazarus.pathflow.pas`
  - `src/fpdev.lazarus.installcallbacks.pas`
  - `src/fpdev.lazarus.runtimeactions.pas`

**Step 2: Re-run docs contract**

Run: `python3 -m unittest tests.test_contributor_docs_contract -v`

Expected: PASS

### Task 9: Focused and full regression

**Files:**
- Verify only

**Step 1: Run focused Python suites**

Run: `python3 -m unittest tests.test_lazarus_manager_path_boundary tests.test_lazarus_manager_callbacks_boundary tests.test_lazarus_manager_runtime_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract tests.test_contributor_docs_contract -v`

Expected: PASS

**Step 2: Run focused Pascal suites**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-pathflow-final-bin -FU/tmp/fpdev-lazarus-pathflow-final-lib tests/test_lazarus_pathflow.lpr && /tmp/fpdev-lazarus-pathflow-final-bin/test_lazarus_pathflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-callbacks-final-bin -FU/tmp/fpdev-lazarus-callbacks-final-lib tests/test_lazarus_installcallbacks.lpr && /tmp/fpdev-lazarus-callbacks-final-bin/test_lazarus_installcallbacks`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-runtime-final-bin -FU/tmp/fpdev-lazarus-runtime-final-lib tests/test_lazarus_runtimeactions.lpr && /tmp/fpdev-lazarus-runtime-final-bin/test_lazarus_runtimeactions`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-update-final-bin -FU/tmp/fpdev-lazarus-update-final-lib tests/test_lazarus_update.lpr && /tmp/fpdev-lazarus-update-final-bin/test_lazarus_update`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-configure-final-bin -FU/tmp/fpdev-lazarus-configure-final-lib tests/test_lazarus_configure_workflow.lpr && /tmp/fpdev-lazarus-configure-final-bin/test_lazarus_configure_workflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-cli-final-bin -FU/tmp/fpdev-lazarus-cli-final-lib tests/test_cli_lazarus.lpr && /tmp/fpdev-lazarus-cli-final-bin/test_cli_lazarus`

Expected: PASS

**Step 3: Run repository regression**

Run: `bash scripts/run_all_tests.sh`

Expected: PASS

**Step 4: Final planning record update**

- 在 `task_plan.md` 把 Phase 38 标成 complete
- 在 `findings.md` 记录三个新 helper 单元的边界与保留职责
- 在 `progress.md` 记录 RED/GREEN 与 full regression 结果
