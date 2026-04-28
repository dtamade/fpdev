# Build Manager Runtime Toolchain Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.build.manager.pas`，把 runtime/toolchain surface 中剩余的配置应用、toolchain probe、make execution 和 build stamp glue 下沉到 helper，同时保持 `TBuildManager` 持有真实状态与服务对象。

**Architecture:** 新增 `src/fpdev.build.runtimeflow.pas`，只承接 facade 级别的运行时编排：toolchain checklist 采集、config 字段/数组同步、make 参数组装与执行前探测、build-stamp 写入。`src/fpdev.build.manager.pas` 继续保留字段 ownership、logger/toolchain checker/process executor bridge 与 public facade，不重写已稳定的 `managerflow` / `preflightflow` / `makeflow` 内核。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定 runtime/toolchain 边界并写 RED

**Files:**
- Modify: `tests/test_build_manager_boundary.py`
- Create: `tests/test_build_runtimeflow.lpr`
- Reuse: `tests/test_build_makeflow.lpr`

**Step 1: 扩展 boundary 契约**

- 断言 `src/fpdev.build.manager.pas` 引入 `fpdev.build.runtimeflow`
- 断言以下方法委托到 helper：
  - `CheckToolchain(...)`
  - `ApplyConfig(...)`
  - `RunMake(...)`
  - `CreateBuildStamp(...)`
- 断言 facade 不再内联：
  - toolchain issue collection loop
  - selected/skipped package copy loop
  - make args 组装和 `RunDirect(...)` 调用
  - build stamp CPU/OS + file write 逻辑

**Step 2: direct helper RED**

- 用 callback harness 覆盖：
  - toolchain 全绿 / 缺工具 / verbose issue logging
  - config arrays copy + directory ensure
  - runmake missing source / dry-run / make probe fail / real run fail / verbose args
  - build stamp success / exception swallow + log

**Step 3: Run RED**

Run:
- `python3 -m unittest tests.test_build_manager_boundary -v`
- `mkdir -p /tmp/fpdev-build-runtimeflow-bin-red /tmp/fpdev-build-runtimeflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-runtimeflow-bin-red -FU/tmp/fpdev-build-runtimeflow-lib-red tests/test_build_runtimeflow.lpr`

Expected: 因 helper 尚不存在或 manager 还未委托而失败。

### Task 2: 实现 runtimeflow helper

**Files:**
- Create: `src/fpdev.build.runtimeflow.pas`

**Step 1: 最小 helper API**

- `ExecuteBuildManagerToolchainCheckCore(...)`
- `ApplyBuildManagerConfigCore(...)`
- `ExecuteBuildManagerRunMakeCore(...)`
- `CreateBuildManagerStampCore(...)`

**Step 2: 保持作用域收敛**

- helper 只接 plain state / callbacks
- 不直接持有 `TBuildManager`
- 不重复实现 `ResolveMakeCmd` / `HasTool` / logger service；通过 callback 注入

### Task 3: 回接 BuildManager facade

**Files:**
- Modify: `src/fpdev.build.manager.pas`

**Step 1: delegate target methods**

- 让 `CheckToolchain(...)` / `ApplyConfig(...)` / `RunMake(...)` / `CreateBuildStamp(...)` 委托 helper
- 保留 manager 字段、service bridge 和 public API 不变

**Step 2: 避免连带改动**

- 不碰 `BuildCompiler(...)` / `Preflight(...)` / `FullBuild(...)`
- 不改变 error text 与 log contract，除非 direct tests 明确锁定了更稳定的 wording

### Task 4: Focused Verification

Run:
- `python3 -m unittest tests.test_build_manager_boundary -v`
- `mkdir -p /tmp/fpdev-build-runtimeflow-bin /tmp/fpdev-build-runtimeflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-runtimeflow-bin -FU/tmp/fpdev-build-runtimeflow-lib tests/test_build_runtimeflow.lpr`
- `/tmp/fpdev-build-runtimeflow-bin/test_build_runtimeflow`
- `mkdir -p /tmp/fpdev-build-makeflow-bin /tmp/fpdev-build-makeflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-makeflow-bin -FU/tmp/fpdev-build-makeflow-lib tests/test_build_makeflow.lpr`
- `/tmp/fpdev-build-makeflow-bin/test_build_makeflow`

Expected: PASS
