# Lazarus Manager Maintenance Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.manager.pas`，把 `UninstallVersion(...)`、`UpdateSources(...)`、`CleanSources(...)` 这组 maintenance/source surface 下沉到共享 helper，保持 manager 只做 callback 提供、exception wrapper 与少量状态装配。

**Architecture:** 新增 `src/fpdev.lazarus.maintenanceflow.pas`，承接 uninstall、update-sources、clean-sources 这组 facade 编排。`src/fpdev.lazarus.manager.pas` 保留 `CreateGitClient(...)`、`GetCurrentVersion(...)`、`IsValidSourceDirectory(...)`、`GetResolvedInstallPath(...)`、`CleanSourceArtifacts(...)`、config removal 等 manager-owned callback，不重新打开 install/version surface。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 maintenance/source surface 最小切口

**Files:**
- Inspect: `src/fpdev.lazarus.manager.pas`
- Reuse: `src/fpdev.lazarus.commandflow.pas`
- Reuse: `src/fpdev.lazarus.sourceflow.pas`
- Test: `tests/test_lazarus_manager_runtime_boundary.py`
- Test: `tests/test_lazarus_update.lpr`

**Step 1: 锁定必须下沉的职责**

- `UninstallVersion(...)` 的 install-path / metadata preflight、delete + remove-config orchestration
- `UpdateSources(...)` 的 current-version fallback、source-dir validation、git client wiring
- `CleanSources(...)` 的 current-version fallback、source-dir validation、artifact cleanup delegate

**Step 2: 锁定不改的边界**

- 不改 `CreateLazarusSourcePlanCore(...)`、`ExecuteLazarusUpdatePlanCore(...)`、`ExecuteLazarusCleanPlanCore(...)`
- 不改 `CreateGitClient(...)` / `IsValidSourceDirectory(...)` / `CleanSourceArtifacts(...)` 的底层实现
- 不把 console output / commandflow 文案重新吸回 helper 之外的层

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_lazarus_manager_runtime_boundary.py`
- Create: `tests/test_lazarus_maintenanceflow.lpr`

**Step 1: 扩展 Python boundary**

- 断言 manager 引入 `fpdev.lazarus.maintenanceflow`
- 断言 `UninstallVersion(...)` 改为委托 maintenance helper，而不是内联 `DeleteDirRecursive(...)` / `RemoveLazarusVersion(...)`
- 断言 `UpdateSources(...)` / `CleanSources(...)` 改为委托 maintenance helper，而不是在 manager 内直接装配 source plan 与目录校验控制流

**Step 2: 新增 direct helper test**

- `tests/test_lazarus_maintenanceflow.lpr` 直接覆盖：
  - uninstall 对 “未安装 + 无目录 + 无 metadata” 的 fast-success
  - uninstall 在目录存在时会执行删除并移除 config
  - update-sources 对缺失/非法 source dir 的 guard
  - clean-sources 对 current-version fallback 与 cleanup callback 的 wiring

**Step 3: 运行 RED 证据**

Run: `python3 -m unittest tests.test_lazarus_manager_runtime_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-maintenance-bin-red -FU/tmp/fpdev-lazarus-maintenance-lib-red tests/test_lazarus_maintenanceflow.lpr`

Run: `/tmp/fpdev-lazarus-maintenance-bin-red/test_lazarus_maintenanceflow`

Expected: FAIL，因为 maintenanceflow unit/helper 尚未存在，且 manager 仍保留 inline control flow。

### Task 3: 实现最小 maintenance helper 并回接 manager

**Files:**
- Create: `src/fpdev.lazarus.maintenanceflow.pas`
- Modify: `src/fpdev.lazarus.manager.pas`
- Test: `tests/test_lazarus_maintenanceflow.lpr`

**Step 1: 新建 helper 单元**

- 定义 uninstall/update/clean 所需 callback types
- 只承接 manager-level orchestration，不直接创建 config manager / git client 实例

**Step 2: 添加最小 core helper**

- `ExecuteManagedLazarusUninstallCore(...)`
- `ExecuteManagedLazarusUpdateSourcesCore(...)`
- `ExecuteManagedLazarusCleanSourcesCore(...)`

**Step 3: 让 manager 变为 thin delegate**

- `UninstallVersion(...)`、`UpdateSources(...)`、`CleanSources(...)` 只做 callback wiring 与异常边界
- 保持已有 `commandflow` / `versionflow` / `metadataflow` 结构不回退

### Task 4: Focused Verification

**Files:**
- Verify: `tests/test_lazarus_manager_runtime_boundary.py`
- Verify: `tests/test_lazarus_maintenanceflow.lpr`
- Verify: `tests/test_lazarus_update.lpr`
- Verify: `tests/test_lazarus_flow.lpr`
- Verify: `tests/test_lazarus_management.lpr`

**Step 1: 跑 boundary 与 direct helper**

Run: `python3 -m unittest tests.test_lazarus_manager_runtime_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-maintenance-bin -FU/tmp/fpdev-lazarus-maintenance-lib tests/test_lazarus_maintenanceflow.lpr && /tmp/fpdev-lazarus-maintenance-bin/test_lazarus_maintenanceflow`

**Step 2: 跑 Lazarus focused regression**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr && /tmp/fpdev-lazarus-update-bin/test_lazarus_update`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr && /tmp/fpdev-lazarus-flow-bin/test_lazarus_flow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-management-bin2 -FU/tmp/fpdev-lazarus-management-lib2 tests/test_lazarus_management.lpr && /tmp/fpdev-lazarus-management-bin2/test_lazarus_management`

Expected: 全绿，且 `src/fpdev.lazarus.manager.pas` 在 maintenance/source surface 明显变薄。
