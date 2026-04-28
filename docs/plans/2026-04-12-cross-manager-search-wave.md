# Cross Manager Search Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.cross.manager.pas`，优先把 list/info/update/clean 这批 facade 侧 orchestration 下沉到 helper，保持 cross manager 只做 config/query/wrapper；本波不重新打开 install/search 算法本体，以最高效率先收最稳的一刀。

**Architecture:** 复用现有 `src/fpdev.cross.targetflow.pas` 模式，新增 `src/fpdev.cross.managerflow.pas` 承接 manager 级输出格式化、update wiring、clean path 解析与文件清理编排。`src/fpdev.cross.search.pas` 本波只作为现有回归护栏，不做大改，避免同时打开两个复杂热点导致节奏变慢。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化最小高 ROI 切口

**Files:**
- Inspect: `src/fpdev.cross.manager.pas`
- Reference: `src/fpdev.cross.targetflow.pas`
- Reuse: `tests/test_cross_targetflow.lpr`
- Reuse: `tests/test_cross_management.lpr`
- Reuse: `tests/test_cross_query.lpr`

**Step 1: 明确 helper 公开符号**

- `ExecuteCrossListTargetsCore(...)`
- `ExecuteCrossShowTargetInfoCore(...)`
- `ExecuteCrossUpdateTargetCore(...)`
- `ResolveCrossCleanPathsCore(...)`
- `ExecuteCrossCleanTargetCore(...)`

**Step 2: 锁定必须保持的行为**

- `cross list` 继续区分 `--all` 与 installed-only 头部文案
- `cross show` 继续输出 display/cpu/os/prefix，已安装目标继续输出 install path
- `cross update` 对 binutils/libraries 下载失败继续保留 warning 而不是 hard fail
- `cross clean` 继续支持 configured path 覆盖默认 `bin/lib` 路径，并清理 archive/test artifacts

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_cross_manager_boundary.py`
- Create: `tests/test_cross_managerflow.lpr`
- Reference: `tests/test_cross_targetflow.lpr`

**Step 1: 写 boundary 测试**

- `src/fpdev.cross.manager.pas` 必须引入 `fpdev.cross.managerflow`
- `ListTargets` 委托 `ExecuteCrossListTargetsCore(...)`
- `ShowTargetInfo` 委托 `ExecuteCrossShowTargetInfoCore(...)`
- `UpdateTarget` 委托 `ExecuteCrossUpdateTargetCore(...)`
- `CleanTarget` 不再内联 archive/test artifact 删除清单

**Step 2: 写 direct helper 测试**

- list core 在 empty/available/installed 三种场景下输出正确 header 与 total
- show core 对 unsupported target 返回错误，对 installed target 输出 install path
- update core 在 binutils/libraries 失败时保留 warning contract
- clean path resolver 优先使用 configured bin/lib 路径
- clean core 删除 bin/lib 目录与 archive/test artifacts，并输出现有完成文案

**Step 3: 运行测试确认 RED**

Run: `python3 -m unittest tests.test_cross_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-managerflow-bin-red /tmp/fpdev-cross-managerflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin-red -FU/tmp/fpdev-cross-managerflow-lib-red tests/test_cross_managerflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 manager

**Files:**
- Create: `src/fpdev.cross.managerflow.pas`
- Modify: `src/fpdev.cross.manager.pas`

**Step 1: 实现最小 manager helper**

- list/info/update/clean only
- 不重构 install 流与 search strategy
- 复用现有 `IOutput` 与 i18n 常量

**Step 2: 最小化改写 manager**

- `ListTargets`
- `ShowTargetInfo`
- `UpdateTarget`
- `CleanTarget`

manager 继续保留 `FQuery` / `FConfigManager` / downloader / exception wrapper。

**Step 3: 跑 focused verification**

Run: `python3 -m unittest tests.test_cross_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-managerflow-bin /tmp/fpdev-cross-managerflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin -FU/tmp/fpdev-cross-managerflow-lib tests/test_cross_managerflow.lpr`

Run: `bash -lc /tmp/fpdev-cross-managerflow-bin/test_cross_managerflow`

Run: `mkdir -p /tmp/fpdev-cross-targetflow-bin /tmp/fpdev-cross-targetflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-targetflow-bin -FU/tmp/fpdev-cross-targetflow-lib tests/test_cross_targetflow.lpr`

Run: `bash -lc /tmp/fpdev-cross-targetflow-bin/test_cross_targetflow`

Run: `mkdir -p /tmp/fpdev-cross-management-bin /tmp/fpdev-cross-management-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-management-bin -FU/tmp/fpdev-cross-management-lib tests/test_cross_management.lpr`

Run: `bash -lc /tmp/fpdev-cross-management-bin/test_cross_management`

Expected: PASS
