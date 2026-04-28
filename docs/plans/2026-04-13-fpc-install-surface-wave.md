# FPC Install Surface Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.fpc.manager.pas`，把 `InstallVersion(...)` 里 manager 仍保留的 validation gate、installer flag wiring、build-cache callback wiring、install path resolve 与 post-success verification refresh 编排下沉到独立 helper，同时继续复用现有 `fpdev.fpc.installversionflow` 作为核心安装流程。

**Architecture:** 新增 `src/fpdev.fpc.installsurfaceflow.pas`，承接 manager 级 install surface orchestration。`src/fpdev.fpc.manager.pas` 继续持有真实依赖对象与 callback 方法，但 `InstallVersion(...)` 本身收缩为 state assembly + thin delegate。`src/fpdev.fpc.installversionflow.pas` 不重复打开，只作为下游 core。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化本波最小切口

**Files:**
- Inspect: `src/fpdev.fpc.manager.pas`
- Reuse: `src/fpdev.fpc.installversionflow.pas`
- Reuse: `tests/test_fpc_installversionflow.lpr`
- Reuse: `tests/test_fpc_manager_installmetadata.lpr`

**Step 1: 明确 helper 公开符号**

- `TFPCInstallSurfaceState`
- `TFPCInstallConfigureInstallerProc`
- `TFPCInstallValidateVersionFunc`
- `TFPCInstallRefreshMetadataFunc`
- `TFPCInstallSurfaceCallbacks`
- `ExecuteManagedFPCInstallSurfaceCore(...)`

**Step 2: 锁定必须保持的行为**

- 非 offline 且版本非法时继续报 `ERR_INVALID_VERSION`
- offline 模式继续跳过早期 `ValidateVersion(...)` gate
- `SetNoCache(...)` / `SetOfflineMode(...)` 继续在 core 执行前调用
- 安装成功后继续用 resolved install path 调 `RefreshInstallVerificationMetadata(...)`
- 安装失败时不做 refresh

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_fpc_install_manager_boundary.py`
- Create: `tests/test_fpc_installsurfaceflow.lpr`

**Step 1: 补 Python 边界测试**

- 断言 `src/fpdev.fpc.manager.pas` 引入 `fpdev.fpc.installsurfaceflow`
- 断言 `InstallVersion(...)` 调用 `ExecuteManagedFPCInstallSurfaceCore(...)`
- 断言 `InstallVersion(...)` section 不再保留 inline validation / installer flag wiring / direct core call

**Step 2: 补 Pascal direct helper 测试**

- 非 offline + invalid version -> fail fast，且不触发 core
- offline -> 跳过 validate 并继续调用 core
- configure installer 事件早于 core 执行
- success -> refresh metadata 收到 resolved install path
- fail -> refresh metadata 不执行

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_fpc_install_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-fpc-installsurfaceflow-bin-red /tmp/fpdev-fpc-installsurfaceflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installsurfaceflow-bin-red -FU/tmp/fpdev-fpc-installsurfaceflow-lib-red tests/test_fpc_installsurfaceflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 manager

**Files:**
- Create: `src/fpdev.fpc.installsurfaceflow.pas`
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: 写最小 install surface helper**

- helper 只负责 manager 层 orchestration
- 继续调用 `ExecuteFPCInstallVersionCore(...)`
- 不重复实现 source/binary install 内核

**Step 2: 最小化改写 manager**

- `InstallVersion(...)` 只组 state/callbacks 再 delegate
- 保留异常包装与真实 manager methods
- 保留 `RefreshInstallVerificationMetadata(...)` 作为 manager-owned callback

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_fpc_install_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-fpc-installsurfaceflow-bin /tmp/fpdev-fpc-installsurfaceflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installsurfaceflow-bin -FU/tmp/fpdev-fpc-installsurfaceflow-lib tests/test_fpc_installsurfaceflow.lpr`

Run: `bash -lc /tmp/fpdev-fpc-installsurfaceflow-bin/test_fpc_installsurfaceflow`

Run: `mkdir -p /tmp/fpdev-fpc-installversionflow-bin /tmp/fpdev-fpc-installversionflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installversionflow-bin -FU/tmp/fpdev-fpc-installversionflow-lib tests/test_fpc_installversionflow.lpr`

Run: `bash -lc /tmp/fpdev-fpc-installversionflow-bin/test_fpc_installversionflow`

Run: `mkdir -p /tmp/fpdev-fpc-installmetadata-bin /tmp/fpdev-fpc-installmetadata-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installmetadata-bin -FU/tmp/fpdev-fpc-installmetadata-lib tests/test_fpc_manager_installmetadata.lpr`

Run: `bash -lc /tmp/fpdev-fpc-installmetadata-bin/test_fpc_manager_installmetadata`
