# Cross Search Paths Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.cross.search.pas`，先把 prefix candidate 生成与 library path candidate 构建下沉到独立 helper，保持 search 主单元聚焦 binutils layer orchestration、logging 与 diagnose。

**Architecture:** 新增 `src/fpdev.cross.searchpaths.pas`，承接 `GetCrossPrefixCandidatesCore(...)` 与 `BuildCrossLibraryCandidatesCore(...)` 两类纯路径/候选逻辑。`src/fpdev.cross.search.pas` 保留 `TCrossToolchainSearch` 的对象状态、6-layer binutils search、log 缓存与 diagnose 入口，但不再本地维护 CPU/OS prefix 大分支和 library candidate 累加去重细节。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化最小切口

**Files:**
- Inspect: `src/fpdev.cross.search.pas`
- Reuse: `tests/test_cross_search.lpr`
- Reuse: `tests/test_cross_search_libs.lpr`

**Step 1: 明确 helper 公开符号**

- `GetCrossPrefixCandidatesCore(...)`
- `BuildCrossLibraryCandidatesCore(...)`

**Step 2: 锁定必须保持的行为**

- configured `BinutilsPrefix` 仍然优先于默认 prefix 列表
- ARM/AArch64/Win64 仍保留当前 prefix 候选顺序
- configured `LibrariesPath` 仍然排在 library candidate 第一位
- library candidate 仍去重且只返回真实存在目录
- `DiagnoseTarget(...)` 与 `SearchBinutilsWithConfig(...)` 的现有输出契约不漂移

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_cross_search_boundary.py`
- Create: `tests/test_cross_searchpaths.lpr`
- Reference: `tests/test_cross_search.lpr`
- Reference: `tests/test_cross_search_libs.lpr`

**Step 1: 写 boundary 测试**

- 断言 `src/fpdev.cross.search.pas` 引入 `fpdev.cross.searchpaths`
- 断言 `GetPrefixCandidates(...)` 委托 `GetCrossPrefixCandidatesCore(...)`
- 断言 `SearchLibraries(...)` 委托 `BuildCrossLibraryCandidatesCore(...)`
- 断言 `src/fpdev.cross.search.pas` 不再内联 `if CPU = 'arm'` prefix 分支与 `AddCandidate(...)` local procedure

**Step 2: 写 direct helper 测试**

- prefix helper 直接覆盖 ARM Linux / AArch64 Linux / Win64 / configured prefix
- library helper 覆盖 configured path first
- library helper 覆盖 duplicate candidate dedupe
- helper 对 fake target 继续返回空或稳定结果，不崩溃

**Step 3: 运行测试确认 RED**

Run: `python3 -m unittest tests.test_cross_search_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-searchpaths-bin-red /tmp/fpdev-cross-searchpaths-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchpaths-bin-red -FU/tmp/fpdev-cross-searchpaths-lib-red tests/test_cross_searchpaths.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 search

**Files:**
- Create: `src/fpdev.cross.searchpaths.pas`
- Modify: `src/fpdev.cross.search.pas`

**Step 1: 写最小 helper 实现**

- 只承接 prefix 与 library candidate 逻辑
- 不打开 6-layer binutils search 的策略顺序
- 复用现有 `TCrossTarget` 和路径工具函数

**Step 2: 最小化改写 search**

- `GetPrefixCandidates(...)`
- `SearchLibraries(...)`

`TCrossToolchainSearch` 继续保留 `FLog` / `CheckTool(...)` / `SearchLayer*` / `DiagnoseTarget(...)`。

**Step 3: 跑 focused verification**

Run: `python3 -m unittest tests.test_cross_search_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-searchpaths-bin /tmp/fpdev-cross-searchpaths-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchpaths-bin -FU/tmp/fpdev-cross-searchpaths-lib tests/test_cross_searchpaths.lpr`

Run: `bash -lc /tmp/fpdev-cross-searchpaths-bin/test_cross_searchpaths`

Run: `mkdir -p /tmp/fpdev-cross-search-bin /tmp/fpdev-cross-search-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-search-bin -FU/tmp/fpdev-cross-search-lib tests/test_cross_search.lpr`

Run: `bash -lc /tmp/fpdev-cross-search-bin/test_cross_search`

Run: `mkdir -p /tmp/fpdev-cross-search-libs-bin /tmp/fpdev-cross-search-libs-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-search-libs-bin -FU/tmp/fpdev-cross-search-libs-lib tests/test_cross_search_libs.lpr`

Run: `bash -lc /tmp/fpdev-cross-search-libs-bin/test_cross_search_libs`

Expected: PASS.
