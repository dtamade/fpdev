# Lazarus Source Runtime Config Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.source.pas`，把 legacy source runtime/config surface 下沉到独立 helper，同时保持 clone/update/switch/install 行为不变。

**Architecture:** 新增 `src/fpdev.lazarus.sourceruntimeflow.pas`，承接 custom FPC IDE configure、local source version inventory、legacy source build orchestration 和 launch orchestration。`src/fpdev.lazarus.source.pas` 保留对象态字段、Git client factory、thin callback wiring 与 facade 入口，不重新吸回目录扫描、IDE config apply、build/launch plan 细节。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定新的 source runtime/config 边界

**Files:**
- Modify: `tests/test_lazarus_source_boundary.py`

**Step 1: Write the failing test**

- 新增断言：
  - `src/fpdev.lazarus.source.pas` 必须 `uses fpdev.lazarus.sourceruntimeflow`
  - `ConfigureCustomFPCIDE(...)` 必须委托新的 helper
  - `ListLocalVersions(...)` 必须委托新的 helper
  - `BuildLazarus(...)` 必须委托新的 helper
  - `LaunchLazarus(...)` 必须委托新的 helper

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_lazarus_source_boundary -v`
Expected: FAIL on missing helper import/delegation

### Task 2: 给 new source runtime helper 写 direct RED 覆盖

**Files:**
- Create: `tests/test_lazarus_sourceruntimeflow.lpr`

**Step 1: Write the failing test**

- 直接覆盖以下行为：
  - local version listing 只返回有效 source tree
  - custom FPC path configure 写入正确 IDE 配置
  - build helper 对 invalid source tree 返回 false
  - build helper 对 valid source tree 返回 true
  - launch helper 对缺失 executable 返回 false

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceruntimeflow-bin-red -FU/tmp/fpdev-lazarus-sourceruntimeflow-lib-red tests/test_lazarus_sourceruntimeflow.lpr`
Expected: FAIL with `Can't find unit fpdev.lazarus.sourceruntimeflow`

### Task 3: 实现 runtime/config helper

**Files:**
- Create: `src/fpdev.lazarus.sourceruntimeflow.pas`

**Step 1: Write minimal implementation**

- 提供 helper 承接：
  - custom FPC IDE config apply
  - local version directory scan/filter
  - build preflight + make params + command execute wiring
  - launch preflight + runtime launch wiring

**Step 2: Keep scope tight**

- 不重拆 Git clone/update/switch/install lifecycle
- 不改 `TLazarusSourceManager` public API
- 不扩大用户文案或行为语义

### Task 4: 收口 source manager facade

**Files:**
- Modify: `src/fpdev.lazarus.source.pas`

**Step 1: Delegate target methods**

- 让以下方法变成 thin delegate：
  - `ConfigureCustomFPCIDE(...)`
  - `ListLocalVersions(...)`
  - `BuildLazarus(...)`
  - `LaunchLazarus(...)`

**Step 2: Avoid regression**

- 保留 `CreateGitClient(...)`、`WriteStatus(...)`、`ExecuteCommand(...)` 等对象接口
- 不改 clone/update/switch/install 已完成的 sourcelifecycleflow wiring

### Task 5: 跑 focused 验证

**Files:**
- Reuse: `tests/test_lazarus_update.lpr`
- Reuse: `tests/test_lazarus_flow.lpr`

**Step 1: Verify focused suites**

Run:
- `python3 -m unittest tests.test_lazarus_source_boundary -v`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceruntimeflow-bin -FU/tmp/fpdev-lazarus-sourceruntimeflow-lib tests/test_lazarus_sourceruntimeflow.lpr && bash -lc /tmp/fpdev-lazarus-sourceruntimeflow-bin/test_lazarus_sourceruntimeflow`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr && bash -lc /tmp/fpdev-lazarus-update-bin/test_lazarus_update`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr && bash -lc /tmp/fpdev-lazarus-flow-bin/test_lazarus_flow`

Expected: PASS
