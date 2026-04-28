# Cross Search Orchestration Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.cross.search.pas`，把 `SearchBinutilsWithConfig(...)` 中的 configured shortcut 与 6-layer 顺序编排下沉到独立 helper，保持 layer 实现、对象态日志缓存和 pure path/diagnose helper 继续留在现有单元。

**Architecture:** 新增 `src/fpdev.cross.searchflow.pas`，承接 manager-style orchestration：清空日志、优先验证 configured path、按 L1→L6 顺序调用 layer callback、命中即停。`src/fpdev.cross.search.pas` 继续持有 `CheckTool(...)`、`AddLog(...)` 和 `SearchLayer1..6(...)` 的细节实现，但 `SearchBinutilsWithConfig(...)` 本身收缩成 thin delegate。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化本波最小切口

**Files:**
- Inspect: `src/fpdev.cross.search.pas`
- Reuse: `src/fpdev.cross.searchpaths.pas`
- Reuse: `src/fpdev.cross.searchdiag.pas`
- Reuse: `tests/test_cross_search.lpr`
- Reuse: `tests/test_cross_install_flow.lpr`

**Step 1: 明确 helper 公开符号**

- `TCrossSearchLayerFunc`
- `TCrossSearchConfigLayerFunc`
- `TCrossSearchCheckToolFunc`
- `TCrossSearchLogProc`
- `TCrossSearchClearLogProc`
- `TCrossSearchCallbacks`
- `ExecuteCrossBinutilsSearchCore(...)`

**Step 2: 锁定必须保持的行为**

- configured path 命中时继续返回 `Layer = 0` / `LayerName = 'configured'`
- configured path 失效时继续记录 layer 0 miss，再进入 layer 1..6
- layer 顺序保持 `fpdev-managed -> system-paths -> env-path -> platform-specific -> linker-discovery -> config-hints`
- 首个成功 layer 继续 short-circuit，后续 layer 不再执行

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_cross_search_boundary.py`
- Create: `tests/test_cross_searchflow.lpr`

**Step 1: 补 Python 边界测试**

- 断言 `src/fpdev.cross.search.pas` 引入 `fpdev.cross.searchflow`
- 断言 `SearchBinutilsWithConfig(...)` 调用 `ExecuteCrossBinutilsSearchCore(...)`
- 断言该 section 不再内联 configured shortcut 和 `SearchLayer1..6` 顺序代码

**Step 2: 补 Pascal direct helper 测试**

- configured path 命中时 helper 不调用 layer callback
- configured path miss 后按顺序执行 layer，并在命中后停止
- 全 miss 时 helper 返回 layer 6 结果并且只 reset 一次 log

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_cross_search_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-searchflow-bin-red /tmp/fpdev-cross-searchflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchflow-bin-red -FU/tmp/fpdev-cross-searchflow-lib-red tests/test_cross_searchflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 search

**Files:**
- Create: `src/fpdev.cross.searchflow.pas`
- Modify: `src/fpdev.cross.search.pas`

**Step 1: 写最小 orchestration helper**

- helper 只负责 configured shortcut、log reset 与 layer sequencing
- 不重复抽 layer 实现、不碰 prefix/library/diagnose helper
- 保持 callback contract 足够小，便于 direct helper 测试

**Step 2: 最小化改写 search 单元**

- interface / implementation 引入新 helper
- `SearchBinutilsWithConfig(...)` 收缩为 single delegate
- 其他 public API 保持不变

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_cross_search_boundary -v`

Run: `mkdir -p /tmp/fpdev-cross-searchflow-bin /tmp/fpdev-cross-searchflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchflow-bin -FU/tmp/fpdev-cross-searchflow-lib tests/test_cross_searchflow.lpr`

Run: `bash -lc /tmp/fpdev-cross-searchflow-bin/test_cross_searchflow`

Run: `mkdir -p /tmp/fpdev-cross-search-bin /tmp/fpdev-cross-search-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-search-bin -FU/tmp/fpdev-cross-search-lib tests/test_cross_search.lpr`

Run: `bash -lc /tmp/fpdev-cross-search-bin/test_cross_search`

Run: `mkdir -p /tmp/fpdev-cross-install-flow-bin /tmp/fpdev-cross-install-flow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-install-flow-bin -FU/tmp/fpdev-cross-install-flow-lib tests/test_cross_install_flow.lpr`

Run: `bash -lc /tmp/fpdev-cross-install-flow-bin/test_cross_install_flow`
