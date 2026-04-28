# Cross Search Diagnose Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.cross.search.pas`，先把诊断输出与 search log 格式化下沉到 shared helper，保持 6-layer 搜索顺序和对象态日志缓存不变。

**Architecture:** 新增 `src/fpdev.cross.searchdiag.pas`，承接 `GetSearchLog(...)` 与 `DiagnoseTarget(...)` 的纯格式化逻辑。`src/fpdev.cross.search.pas` 继续持有 `FLog`、`AddLog(...)`、`SearchLayer*` 和 `SearchBinutilsWithConfig(...)` 的策略顺序，只把字符串拼装与最终 lines 构建交给 helper。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化最小切口

**Files:**
- Inspect: `src/fpdev.cross.search.pas`
- Reuse: `tests/test_cross_search.lpr`
- Reuse: `tests/test_cross_search_libs.lpr`

**Step 1: helper 公开符号**

- `BuildCrossSearchLogLinesCore(...)`
- `BuildCrossDiagnoseLinesCore(...)`

**Step 2: 锁定必须保持的行为**

- `GetSearchLog(...)` 继续输出 `[Lx:name] path prefix=... => FOUND/miss`
- `DiagnoseTarget(...)` 继续输出 target line、binutils 状态、libraries 状态、search log section
- `SearchBinutilsWithConfig(...)` 的层级顺序和 configured shortcut 不改变

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_cross_search_boundary.py`
- Create: `tests/test_cross_searchdiag.lpr`

**Step 1: 写 boundary 测试**

- `src/fpdev.cross.search.pas` 必须引入 `fpdev.cross.searchdiag`
- `DiagnoseTarget(...)` 必须调用 `BuildCrossDiagnoseLinesCore(...)`
- `GetSearchLog(...)` 必须调用 `BuildCrossSearchLogLinesCore(...)`
- `src/fpdev.cross.search.pas` 不再内联 `StatusStr := 'FOUND'` 和 diagnose 本地 `AddLine(...)`

**Step 2: 写 direct helper 测试**

- log helper 覆盖 found/miss 两种状态
- diagnose helper 覆盖 found binutils + libraries
- diagnose helper 覆盖 missing binutils + empty libraries

### Task 3: 实现 helper 并回接 search

**Files:**
- Create: `src/fpdev.cross.searchdiag.pas`
- Modify: `src/fpdev.cross.search.pas`

**Step 1: helper 只做格式化**

- 不持有对象状态
- 不执行文件系统探测
- 不改变 layer orchestration

**Step 2: focused verification**

Run: `python3 -m unittest tests.test_cross_search_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-searchdiag-bin /tmp/fpdev-cross-searchdiag-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchdiag-bin -FU/tmp/fpdev-cross-searchdiag-lib tests/test_cross_searchdiag.lpr`

Run: `/tmp/fpdev-cross-searchdiag-bin/test_cross_searchdiag`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-search-bin -FU/tmp/fpdev-cross-search-lib tests/test_cross_search.lpr`

Run: `/tmp/fpdev-cross-search-bin/test_cross_search`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-search-libs-bin -FU/tmp/fpdev-cross-search-libs-lib tests/test_cross_search_libs.lpr`

Run: `/tmp/fpdev-cross-search-libs-bin/test_cross_search_libs`
