# FPC Residual Glue Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 对 `src/fpdev.fpc.manager.pas` 剩余 callback glue 做最后一轮高价值收口，把 setup/metadata persistence surface 从 manager 本体继续移出。

**Architecture:** 新增 `src/fpdev.fpc.residualflow.pas`，承接 `SetupEnvironment(...)`、install metadata persistence、verification metadata persistence 与 refresh glue。`src/fpdev.fpc.manager.pas` 继续保留 config manager、version registry 访问、callback 提供者和 facade 入口，但不再本地维护 metadata write try/except 与 setup registration surface。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定 manager residual glue 边界

**Files:**
- Create: `tests/test_fpc_manager_residual_boundary.py`

**Step 1: Write the failing test**

- 断言：
  - `src/fpdev.fpc.manager.pas` 必须 `uses fpdev.fpc.residualflow`
  - `SetupEnvironment(...)` 委托新 helper
  - `WriteInstallMetadata(...)` 委托新 helper
  - `UpdateVerificationMetadata(...)` / `RefreshInstallVerificationMetadata(...)` 委托新 helper

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_fpc_manager_residual_boundary -v`
Expected: FAIL on missing helper import/delegation

### Task 2: 给 residual helper 写 direct RED 覆盖

**Files:**
- Create: `tests/test_fpc_residualflow.lpr`

**Step 1: Write the failing test**

- 直接覆盖：
  - setup environment surface 在有效安装目录下注册 toolchain
  - install metadata persistence 写出 expected metadata
  - verification metadata persistence 保留 origin 并写入 verify 状态
  - refresh helper 调用 verification persistence callback

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-residualflow-bin-red -FU/tmp/fpdev-fpc-residualflow-lib-red tests/test_fpc_residualflow.lpr`
Expected: FAIL with `Can't find unit fpdev.fpc.residualflow`

### Task 3: 实现 residual helper

**Files:**
- Create: `src/fpdev.fpc.residualflow.pas`

**Step 1: Write minimal implementation**

- helper 承接：
  - setup environment surface
  - install metadata persistence
  - verification metadata persistence
  - verification refresh glue

**Step 2: Keep scope tight**

- 不重写 `metadataflow` / `verifyflow` / `installer.environmentflow`
- 只做 facade surface 收口和 callback 组合

### Task 4: 收口 manager target methods

**Files:**
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: Delegate target methods**

- 让以下方法委托 helper：
  - `SetupEnvironment(...)`
  - `WriteInstallMetadata(...)`
  - `UpdateVerificationMetadata(...)`
  - `RefreshInstallVerificationMetadata(...)`

**Step 2: Avoid regression**

- 保留 manager-owned callback：
  - `AddToolchainToConfig(...)`
  - `ResolveMetadataScope(...)`
- 不改 install/maintenance/status/version 已完成的 helper wiring

### Task 5: 跑 focused 验证

**Files:**
- Reuse: `tests/test_fpc_manager_setupenvironment.lpr`
- Reuse: `tests/test_fpc_manager_installmetadata.lpr`
- Reuse: `tests/test_fpc_installsurfaceflow.lpr`

**Step 1: Verify focused suites**

Run:
- `python3 -m unittest tests.test_fpc_manager_residual_boundary -v`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-residualflow-bin -FU/tmp/fpdev-fpc-residualflow-lib tests/test_fpc_residualflow.lpr && bash -lc /tmp/fpdev-fpc-residualflow-bin/test_fpc_residualflow`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-setupenv-bin -FU/tmp/fpdev-fpc-setupenv-lib tests/test_fpc_manager_setupenvironment.lpr && bash -lc /tmp/fpdev-fpc-setupenv-bin/test_fpc_manager_setupenvironment`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installmeta-bin -FU/tmp/fpdev-fpc-installmeta-lib tests/test_fpc_manager_installmetadata.lpr && bash -lc /tmp/fpdev-fpc-installmeta-bin/test_fpc_manager_installmetadata`

Expected: PASS
