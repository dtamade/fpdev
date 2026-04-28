# Manager Hotspot Roadmap

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 以最高开发效率继续削薄当前 remaining managers，先收 `src/fpdev.fpc.manager.pas`，再沿同一套 boundary/direct/focused/full 方法推进其他热点单元。

**Architecture:** 不再继续追已经基本收口的 `src/fpdev.lazarus.manager.pas`，而是转向仍然厚重且具备成熟 helper/test 护栏的 manager/source 单元。执行顺序按收益、风险和上下文复用排序：`FPC manager -> Lazarus source -> Project manager -> Package/Resource -> Cross manager/search`。每一波都坚持同一分层策略：manager 保留 facade/config/registry/exception wrapper，shared flow/helper 承接纯 orchestration 与可复用逻辑。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Markdown docs

---

### Task 1: FPC Manager Statusflow Wave

**Files:**
- Modify: `src/fpdev.fpc.manager.pas`
- Create: `src/fpdev.fpc.statusflow.pas`
- Create: `tests/test_fpc_manager_status_boundary.py`
- Create: `tests/test_fpc_statusflow.lpr`
- Reuse: `tests/test_fpc_status.lpr`

**Step 1: Add RED tests**

- 锁 `GetStatus(...)` 必须委托 `fpdev.fpc.statusflow`
- direct helper 覆盖：
  - no configured default
  - configured custom install path
  - metadata-owned scope/source/verify
  - missing executable error

**Step 2: Implement shared helper**

- `BuildManagedFPCStatusCore(...)`
- `ResolveManagedFPCStatusInstallPathCore(...)`
- `InitializeFPCStatusInfoCore(...)`

**Step 3: Verify**

- `python3 -m unittest tests.test_fpc_manager_status_boundary -v`
- `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-fpc-statusflow-bin -FU/tmp/fpdev-fpc-statusflow-lib tests/test_fpc_statusflow.lpr`
- `/tmp/fpdev-fpc-statusflow-bin/test_fpc_statusflow`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-status-bin -FU/tmp/fpdev-fpc-status-lib tests/test_fpc_status.lpr`
- `/tmp/fpdev-fpc-status-bin/test_fpc_status`

### Task 2: Lazarus Source Manager Slicing

**Files:**
- Modify: `src/fpdev.lazarus.source.pas`
- Reuse: current Lazarus update/build tests

**Step 1: Re-scan remaining responsibilities**

- 锁定仍在 source manager 内部的 clone/update/build/config orchestration
- 复用最近刚完成的 Lazarus manager helper 边界模式

**Step 2: Extract the next smallest helper**

- 优先切 source/update plan wiring，而不是重新打开 CLI/root shell

**Step 3: Verify**

- 跑 Lazarus source/update focused suites

### Task 3: Project Manager Slicing

**Files:**
- Modify: `src/fpdev.project.manager.pas`
- Add boundary/direct tests as needed

**Step 1: Identify facade-vs-helper cut**

- 保留 config/project state access
- 下沉 init/list/status/query 类 helper

**Step 2: Verify**

- 跑 project-focused Pascal/Python suites

### Task 4: Package Manager / Resource Repo Wave

**Files:**
- Modify: `src/fpdev.package.manager.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: Group by reusable flow/query/helper**

- 先做最纯的 metadata/query/orchestration 抽离

**Step 2: Verify**

- 跑 package/resource focused suites

### Task 5: Cross Manager/Search Wave

**Files:**
- Modify: `src/fpdev.cross.manager.pas`
- Modify: `src/fpdev.cross.search.pas`

**Step 1: Isolate search/resolve logic**

- manager 保留 facade
- search/resolve 下沉 helper

**Step 2: Verify**

- 跑 cross-focused suites
