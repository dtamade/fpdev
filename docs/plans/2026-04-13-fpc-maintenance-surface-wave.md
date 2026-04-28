# FPC Maintenance Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.fpc.manager.pas`，把 `UninstallVersion(...)`、`UpdateSources(...)`、`CleanSources(...)` 这组 maintenance surface 下沉到共享 helper，保持 manager 只做依赖装配、exception wrapper 与真实 callback 提供。

**Architecture:** 新增 `src/fpdev.fpc.maintenanceflow.pas`，集中承接 managed uninstall/source update/source clean 三类 facade 编排。`src/fpdev.fpc.manager.pas` 保留 `GetCurrentVersion(...)`、`GetVersionInstallPath(...)`、`SourceDirExists(...)`、`CleanSourceArtifacts(...)`、toolchain removal 等 manager-owned callback，不重复打开已稳定的 `statusflow` / `versionflow` / `installsurfaceflow`。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 maintenance 最小切口

**Files:**
- Inspect: `src/fpdev.fpc.manager.pas`
- Reuse: `src/fpdev.fpc.statusflow.pas`
- Reuse: `src/fpdev.fpc.installsurfaceflow.pas`
- Reuse: `tests/test_fpc_update.lpr`
- Reuse: `tests/test_fpc_clean.lpr`
- Reuse: `tests/test_fpc_management.lpr`

**Step 1: 明确 helper 公开符号**

- `TFPCMaintenanceCurrentVersionFunc`
- `TFPCMaintenanceGetInstallPathFunc`
- `TFPCMaintenanceIsInstalledFunc`
- `TFPCMaintenanceDeleteDirProc`
- `TFPCMaintenanceRemoveToolchainProc`
- `TFPCMaintenanceSourceDirExistsFunc`
- `TFPCMaintenanceCleanArtifactsFunc`
- `TFPCMaintenanceGitRuntimeFactory`
- `ExecuteManagedFPCUninstallCore(...)`
- `ExecuteManagedFPCUpdateSourcesCore(...)`
- `ExecuteManagedFPCCleanSourcesCore(...)`

**Step 2: 锁定必须保持的行为**

- uninstall: 未安装版本继续返回 `True`
- uninstall: 已安装版本继续删除 install dir，并移除 `fpc-<version>` toolchain
- update/clean: 空版本参数继续先读 `GetCurrentVersion(...)`
- update/clean: source plan 继续基于 `CreateFPCSourcePlanCore(...)`
- update/clean: 现有输出文案与 callback 顺序保持不变

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_fpc_manager_maintenance_boundary.py`
- Create: `tests/test_fpc_maintenanceflow.lpr`

**Step 1: 写 boundary 测试**

- 断言 `src/fpdev.fpc.manager.pas` 引入 `fpdev.fpc.maintenanceflow`
- 断言 `UninstallVersion(...)` 调 `ExecuteManagedFPCUninstallCore(...)`
- 断言 `UpdateSources(...)` 调 `ExecuteManagedFPCUpdateSourcesCore(...)`
- 断言 `CleanSources(...)` 调 `ExecuteManagedFPCCleanSourcesCore(...)`
- 断言上述 section 不再内联 `DeleteDirRecursive` / `CreateFPCSourcePlanCore` / `ExecuteFPCUpdatePlanCore` / `ExecuteFPCCleanPlanCore`

**Step 2: 写 direct helper 测试**

- uninstall: not installed -> success，且不删目录、不移除 toolchain
- uninstall: installed -> 删除 install path，并移除 `fpc-<version>`
- update: 空版本参数走 current version fallback，再调用 update core
- clean: 空版本参数走 current version fallback，再调用 clean core

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_fpc_manager_maintenance_boundary -v`

Run: `mkdir -p /tmp/fpdev-fpc-maintenanceflow-bin-red /tmp/fpdev-fpc-maintenanceflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-maintenanceflow-bin-red -FU/tmp/fpdev-fpc-maintenanceflow-lib-red tests/test_fpc_maintenanceflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 manager

**Files:**
- Create: `src/fpdev.fpc.maintenanceflow.pas`
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: 写最小 helper**

- helper 只承接 uninstall/update/clean facade orchestration
- 继续复用 `CreateFPCSourcePlanCore(...)`、`ExecuteFPCUpdatePlanCore(...)`、`ExecuteFPCCleanPlanCore(...)`
- 不重开 `ShowVersionInfo(...)` 与 `TestInstallation(...)`

**Step 2: 最小化改写 manager**

- manager 继续保留 callback methods 与异常包装
- `UninstallVersion(...)` / `UpdateSources(...)` / `CleanSources(...)` 收缩成 thin delegate

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_fpc_manager_maintenance_boundary -v`

Run: `mkdir -p /tmp/fpdev-fpc-maintenanceflow-bin /tmp/fpdev-fpc-maintenanceflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-maintenanceflow-bin -FU/tmp/fpdev-fpc-maintenanceflow-lib tests/test_fpc_maintenanceflow.lpr`

Run: `bash -lc /tmp/fpdev-fpc-maintenanceflow-bin/test_fpc_maintenanceflow`

Run: `mkdir -p /tmp/fpdev-fpc-update-bin /tmp/fpdev-fpc-update-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-update-bin -FU/tmp/fpdev-fpc-update-lib tests/test_fpc_update.lpr`

Run: `bash -lc /tmp/fpdev-fpc-update-bin/test_fpc_update`

Run: `mkdir -p /tmp/fpdev-fpc-clean-bin /tmp/fpdev-fpc-clean-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-clean-bin -FU/tmp/fpdev-fpc-clean-lib tests/test_fpc_clean.lpr`

Run: `bash -lc /tmp/fpdev-fpc-clean-bin/test_fpc_clean`

Run: `mkdir -p /tmp/fpdev-fpc-management-bin /tmp/fpdev-fpc-management-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-management-bin -FU/tmp/fpdev-fpc-management-lib tests/test_fpc_management.lpr`

Run: `bash -lc /tmp/fpdev-fpc-management-bin/test_fpc_management`
