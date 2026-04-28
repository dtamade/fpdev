# Lazarus Source Lifecycle Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.source.pas`，把 clone/update/switch/install 这组 lifecycle orchestration 下沉到 helper，保持 source manager 继续持有 git client 创建、目录执行能力与少量状态字段。

**Architecture:** 新增 `src/fpdev.lazarus.sourcelifecycleflow.pas`，承接 legacy source lifecycle 的计划执行与步骤编排：git backend preflight、clone/pull/checkout 顺序、目录校验、install 时的 clone -> build -> configure -> activate 流程。`src/fpdev.lazarus.source.pas` 继续保留 `CreateGitClient(...)`、`BuildLazarus(...)`、`ConfigureCustomFPCIDE(...)`、`ExecuteCommand(...)` 与当前输出设备。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 lifecycle 最小切口

**Files:**
- Inspect: `src/fpdev.lazarus.source.pas`
- Reuse: `src/fpdev.lazarus.sourceflow.pas`
- Reuse: `src/fpdev.lazarus.sourceversionflow.pas`
- Reuse: `tests/test_lazarus_update.lpr`
- Reuse: `tests/test_lazarus_flow.lpr`

**Step 1: 明确 helper 公开符号**

- `TLazarusSourceStatusProc`
- `TLazarusSourceGitClientProvider`
- `TLazarusSourceBuildFunc`
- `TLazarusSourceConfigureIDEFunc`
- `TLazarusSourceSwitchFunc`
- `ExecuteLazarusLegacyCloneCore(...)`
- `ExecuteLazarusLegacyUpdateCore(...)`
- `ExecuteLazarusLegacySwitchCore(...)`
- `ExecuteLazarusLegacyInstallCore(...)`

**Step 2: 锁定必须保持的行为**

- clone: registry repo URL 优先，空版本继续 fallback 到 `main`
- clone: 旧目录存在时继续先删除，再 clone
- update: 空版本参数继续 `FCurrentVersion -> main`
- switch: 未安装版本继续触发 clone fallback
- install: 继续保持 clone -> build -> optional IDE config -> activate 顺序
- install: 任一步失败时继续恢复 `PreviousVersion`

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_lazarus_source_boundary.py`
- Create: `tests/test_lazarus_sourcelifecycleflow.lpr`

**Step 1: 扩展 boundary 测试**

- 断言 `src/fpdev.lazarus.source.pas` 引入 `fpdev.lazarus.sourcelifecycleflow`
- 断言 `CloneLazarusSource(...)` / `UpdateLazarusSource(...)` / `SwitchLazarusVersion(...)` / `InstallLazarusVersion(...)` 调用 new helper
- 断言这些 section 不再内联 `Git.Clone` / `Git.Pull` / `Git.Checkout` / install step banners

**Step 2: 写 direct helper 测试**

- clone: backend unavailable -> fail fast
- clone: success path 会更新 current version
- update: invalid source dir -> fail fast 且不 pull
- switch: already installed + checkout success -> update current version
- install: build/configure/activate 任一失败时恢复 previous version

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_lazarus_source_boundary -v`

Run: `mkdir -p /tmp/fpdev-lazarus-sourcelifecycleflow-bin-red /tmp/fpdev-lazarus-sourcelifecycleflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourcelifecycleflow-bin-red -FU/tmp/fpdev-lazarus-sourcelifecycleflow-lib-red tests/test_lazarus_sourcelifecycleflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 source manager

**Files:**
- Create: `src/fpdev.lazarus.sourcelifecycleflow.pas`
- Modify: `src/fpdev.lazarus.source.pas`

**Step 1: 写最小 lifecycle helper**

- helper 只承接 clone/update/switch/install 编排
- 继续复用 `CreateLazarusLegacyClonePlanCore(...)` / `CreateLazarusLegacyUpdatePlanCore(...)`
- 不重开 `BuildLazarus(...)` / `LaunchLazarus(...)` 内部实现

**Step 2: 最小化改写 source manager**

- `CloneLazarusSource(...)` / `UpdateLazarusSource(...)` / `SwitchLazarusVersion(...)` / `InstallLazarusVersion(...)` 收缩为 state assembly + thin delegate
- 保持 `CreateGitClient(...)`、`BuildLazarus(...)`、`ConfigureCustomFPCIDE(...)` 为 manager-owned callback

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_lazarus_source_boundary -v`

Run: `mkdir -p /tmp/fpdev-lazarus-sourcelifecycleflow-bin /tmp/fpdev-lazarus-sourcelifecycleflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourcelifecycleflow-bin -FU/tmp/fpdev-lazarus-sourcelifecycleflow-lib tests/test_lazarus_sourcelifecycleflow.lpr`

Run: `bash -lc /tmp/fpdev-lazarus-sourcelifecycleflow-bin/test_lazarus_sourcelifecycleflow`

Run: `mkdir -p /tmp/fpdev-lazarus-update-bin /tmp/fpdev-lazarus-update-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr`

Run: `bash -lc /tmp/fpdev-lazarus-update-bin/test_lazarus_update`

Run: `mkdir -p /tmp/fpdev-lazarus-flow-bin /tmp/fpdev-lazarus-flow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr`

Run: `bash -lc /tmp/fpdev-lazarus-flow-bin/test_lazarus_flow`
