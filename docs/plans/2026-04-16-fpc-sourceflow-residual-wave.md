# FPC Sourceflow Residual Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.fpc.source.pas`，把 clone/update/switch/list/prereq 这组剩余 lifecycle/query glue 下沉到新 helper，保持 `TFPCSourceManager` 只做 state ownership、dependency wiring 与 low-level source-dir validation。

**Architecture:** 新增 `src/fpdev.fpc.sourceflow.pas`，承接以下 residual surface：
- `CloneFPCSource(...)`
- `UpdateFPCSource(...)`
- `SwitchFPCVersion(...)`
- `ListAvailableVersions(...)`
- `ListLocalVersions(...)`
- `CheckBuildPrerequisites(...)`

`src/fpdev.fpc.source.pas` 继续保留：
- `FSourceRoot` / `FCurrentVersion` / `FBootstrapCompiler`
- `Repo`
- `ExecuteCommand(...)`
- `IsValidSourceDirectory(...)`
- 已完成的 `sourceinstallflow` / `sourcebootstrapflow` / `sourcebuildflow`

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定 residual boundary 与 helper RED

**Files:**
- Modify: `tests/test_fpc_source_boundary.py`
- Create: `tests/test_fpc_sourceflow.lpr`

**Step 1: 写 boundary contract**

- `src/fpdev.fpc.source.pas` 必须引入 `fpdev.fpc.sourceflow`
- `CloneFPCSource(...)` / `UpdateFPCSource(...)` / `SwitchFPCVersion(...)` 必须委托 helper
- `ListAvailableVersions(...)` / `ListLocalVersions(...)` / `CheckBuildPrerequisites(...)` 必须委托 helper
- manager 不再直接持有：
  - update success/fail status 文案
  - local version scan loop
  - prereq `make --version` probe
  - available version merge/fallback 逻辑

**Step 2: 写 direct helper 测试**

- clone：空版本回退 `main`，成功后更新 current version
- update：空参数回退 current version，成功/失败都输出正确状态
- switch：未安装 fail-fast；成功后更新 current version
- available versions：registry 优先；空 registry 时 static fallback
- local versions：仅返回 `fpc-*` 且 validator 认可的目录
- prereq：要求 `make --version` 成功且 bootstrap compiler 非空

**Step 3: 跑 RED**

Run: `python3 -m unittest tests.test_fpc_source_boundary -v`

Run:
`fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-sourceflow-bin-red -FU/tmp/fpdev-fpc-sourceflow-lib-red tests/test_fpc_sourceflow.lpr`

Expected: boundary fail 或 helper unit 不存在。

### Task 2: 实现 residual helper 并回接 manager

**Files:**
- Create: `src/fpdev.fpc.sourceflow.pas`
- Modify: `src/fpdev.fpc.source.pas`

**Step 1: 写最小 helper**

- helper 只承接：
  - version fallback / normalize
  - update success/fail status output 决策
  - switch fail-fast 与 current version 更新
  - available version merge/fallback
  - local version scan/filter
  - build prereq probe

**Step 2: 让 manager 收缩为 thin facade**

- `CloneFPCSource(...)` / `UpdateFPCSource(...)` / `SwitchFPCVersion(...)` 只保留 repo callback wiring 与 state ownership
- `ListAvailableVersions(...)` 改为 thin delegate
- `ListLocalVersions(...)` 改为 thin delegate
- `CheckBuildPrerequisites(...)` 改为 thin delegate

### Task 3: Focused And Broad Verification

Run:
- `python3 -m unittest tests.test_fpc_source_boundary -v`
- `tests/test_fpc_sourceflow.lpr`
- `tests/test_fpc_sourceinstallflow.lpr`
- `tests/test_fpc_sourcebootstrapflow.lpr`
- `tests/test_fpc_sourcebuildflow.lpr`
- `tests/test_fpc_source_repo.lpr`

Then run:
- `bash scripts/run_all_tests.sh`
- `lazbuild -B fpdev.lpi`

Expected: 全部通过，`src/fpdev.fpc.source.pas` 继续保持 thin facade 方向。
