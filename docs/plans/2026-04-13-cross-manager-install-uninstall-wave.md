# Cross Manager Install/Uninstall Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.cross.manager.pas`，把 `InstallTarget(...)` / `UninstallTarget(...)` 的 orchestration 下沉到 `src/fpdev.cross.managerflow.pas`，并在 planning 文件里纠正此前把 `resource.repo lifecycle` 与 `package.manager tail` 误判为下一主波次的结论。

**Architecture:** 延续既有 `fpdev.cross.managerflow` 的 façade helper 模式，为 install/uninstall 新增可直接测试的 core helper。`TCrossCompilerManager` 继续保留 query/config/downloader/setup wiring、默认 console output fallback 与少量 wrapper；helper 负责 system compiler shortcut、manual instruction fallback、install/uninstall 输出与 filesystem cleanup，避免在 manager 里继续堆控制流。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 先锁定 RED 边界

**Files:**
- Modify: `tests/test_cross_manager_boundary.py`
- Modify: `tests/test_cross_managerflow.lpr`
- Reference: `src/fpdev.cross.manager.pas`
- Reference: `src/fpdev.cross.managerflow.pas`

**Step 1: 扩展 boundary 测试**

- `InstallTarget(...)` 必须委托 `ExecuteCrossInstallTargetCore(...)`
- `UninstallTarget(...)` 必须委托 `ExecuteCrossUninstallTargetCore(...)`
- `InstallTarget(...)` 段内不再保留 `DetectSystemCrossCompiler(ATarget, ...)` / `GetPackageManagerInstructions(ATarget)` / `MSG_CROSS_INSTALL_STEP1`
- `UninstallTarget(...)` 段内不再保留 `DeleteDirRecursive(InstallPath)` / `RemoveCrossTarget(ATarget)`

**Step 2: 扩展 direct helper 测试**

- install helper:
  - unsupported target rejected
  - already-installed short-circuit returns success
  - system compiler found saves config and prints success
  - binutils download failure prints manual package-manager guidance and returns false
  - normal install path creates setup call and prints success
- uninstall helper:
  - missing target returns success with “not installed” note
  - installed target deletes install dir, removes config, prints success

**Step 3: 运行 RED**

Run: `python3 -m unittest tests.test_cross_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-managerflow-bin-red /tmp/fpdev-cross-managerflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin-red -FU/tmp/fpdev-cross-managerflow-lib-red tests/test_cross_managerflow.lpr`

Run: `bash -lc /tmp/fpdev-cross-managerflow-bin-red/test_cross_managerflow`

Expected: Python suite fail 或 Pascal suite fail，因为 install/uninstall helper 及 manager delegate 尚未完成。

### Task 2: 最小实现 install/uninstall helper 与 manager wrappers

**Files:**
- Modify: `src/fpdev.cross.managerflow.pas`
- Modify: `src/fpdev.cross.manager.pas`

**Step 1: 给 managerflow 新增 install/uninstall core**

- 新增 install 所需 callback contract：
  - validate / installed / target info / install path
  - detect system compiler
  - save/remove cross target config
  - download binutils / libraries
  - setup environment
  - package-manager instructions
- 保持 helper 直接复用现有 i18n 文案，不重写 downloader/platform 逻辑

**Step 2: 给 manager 新增最小 wrapper**

- `DetectSystemCompilerForTarget(...)`
- `GetPackageManagerInstructionsForTarget(...)`
- `RemoveCrossTargetConfig(...)`

**Step 3: 让 manager 只做 thin delegate**

- `InstallTarget(...)`
- `UninstallTarget(...)`

### Task 3: Focused Verification

**Files:**
- Verify: `tests/test_cross_manager_boundary.py`
- Verify: `tests/test_cross_managerflow.lpr`
- Verify: `tests/test_cross_management.lpr`

**Step 1: 跑 focused suites**

Run: `python3 -m unittest tests.test_cross_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-managerflow-bin /tmp/fpdev-cross-managerflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin -FU/tmp/fpdev-cross-managerflow-lib tests/test_cross_managerflow.lpr`

Run: `bash -lc /tmp/fpdev-cross-managerflow-bin/test_cross_managerflow`

Run: `mkdir -p /tmp/fpdev-cross-management-bin /tmp/fpdev-cross-management-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-management-bin -FU/tmp/fpdev-cross-management-lib tests/test_cross_management.lpr`

Run: `bash -lc /tmp/fpdev-cross-management-bin/test_cross_management`

Expected: 全部通过。

### Task 4: Full Regression And Planning Sync

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: 跑整仓回归**

Run: `bash scripts/run_all_tests.sh`

Expected: 全绿。

**Step 2: 回填 planning 文件**

- 记录这轮真正的 ROI 结论：`cross.manager` install/uninstall 才是下一刀
- 记录 `resource.repo lifecycle` 与 `package.manager tail` 已大致 helper 化，因此保持 checkpoint
- 更新 focused/full verification 结果与实际修改文件清单
