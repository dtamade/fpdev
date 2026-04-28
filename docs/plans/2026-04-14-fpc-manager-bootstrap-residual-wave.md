# FPC Manager Bootstrap Residual Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 对 `src/fpdev.fpc.manager.pas` 剩余的 bootstrap fallback glue 做最后一轮高价值收口，把 `EnsureBootstrapCompiler(...)` 的 manager 级二段式兜底编排移出本体。

**Architecture:** 新增 `src/fpdev.fpc.bootstrapflow.pas`，承接 manager 级 bootstrap ensure surface：先尝试 builder ensure，再在 installer 可用时执行 binary fallback，最后二次回探 builder。`src/fpdev.fpc.manager.pas` 继续保留 `FBuilderMgr` / `FInstallerMgr` ownership、输出对象和 facade 入口，不重写 builder/source 侧已完成的 bootstrap helper。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定 bootstrap residual 边界并写 RED

**Files:**
- Create: `tests/test_fpc_manager_bootstrap_boundary.py`
- Create: `tests/test_fpc_bootstrapflow.lpr`
- Reuse: `tests/test_fpc_installer_binaryflow.lpr`
- Reuse: `tests/test_fpc_sourcebootstrapflow.lpr`

**Step 1: boundary 契约**

- 断言 `src/fpdev.fpc.manager.pas` 引入 `fpdev.fpc.bootstrapflow`
- 断言 `EnsureBootstrapCompiler(...)` 委托 helper
- 断言 manager facade 不再内联：
  - 首次 `FBuilderMgr.EnsureBootstrapCompiler(...)`
  - binary fallback 输出文案
  - fallback 后二次 ensure

**Step 2: direct helper RED**

- callback harness 覆盖：
  - builder 首次成功
  - builder 失败且 installer 缺失
  - builder 失败 + binary fallback 成功 + 二次 ensure 成功
  - binary fallback 成功但二次 ensure 仍失败
  - fallback 安装失败

**Step 3: Run RED**

Run:
- `python3 -m unittest tests.test_fpc_manager_bootstrap_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-bootstrapflow-bin-red /tmp/fpdev-fpc-bootstrapflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-bootstrapflow-bin-red -FU/tmp/fpdev-fpc-bootstrapflow-lib-red tests/test_fpc_bootstrapflow.lpr`

Expected: FAIL，因为新的 bootstrap helper 还不存在。

### Task 2: 实现 bootstrapflow helper

**Files:**
- Create: `src/fpdev.fpc.bootstrapflow.pas`

**Step 1: 最小 helper API**

- `ExecuteManagedFPCBootstrapEnsureCore(...)`

**Step 2: 保持 scope 紧凑**

- helper 只接 ensure/install/write callbacks
- 不直接持有 manager 或重写 builder/source bootstrap 内核

### Task 3: 回接 FPC manager

**Files:**
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: delegate target method**

- `EnsureBootstrapCompiler(...)` 改为 helper delegate

**Step 2: keep ownership**

- manager 继续提供 builder ensure callback
- installer binary fallback 通过 callback bridge 注入
- 保持原有输出 wording 稳定

### Task 4: Focused Verification

Run:
- `python3 -m unittest tests.test_fpc_manager_bootstrap_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-bootstrapflow-bin /tmp/fpdev-fpc-bootstrapflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-bootstrapflow-bin -FU/tmp/fpdev-fpc-bootstrapflow-lib tests/test_fpc_bootstrapflow.lpr`
- `/tmp/fpdev-fpc-bootstrapflow-bin/test_fpc_bootstrapflow`
- `mkdir -p /tmp/fpdev-fpc-installer-binaryflow-bin /tmp/fpdev-fpc-installer-binaryflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installer-binaryflow-bin -FU/tmp/fpdev-fpc-installer-binaryflow-lib tests/test_fpc_installer_binaryflow.lpr`
- `/tmp/fpdev-fpc-installer-binaryflow-bin/test_fpc_installer_binaryflow`

Expected: PASS
