# FPC Manager Index Cleanup Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.fpc.manager.pas`，把全局 `FPC_UpdateIndex(...)` 与相关文件写入细节下沉到 helper，同时删除 manager 内部未使用的 semver 重复实现。

**Architecture:** 新增 `src/fpdev.fpc.indexflow.pas`，承接 cache/index 文件构建、JSON 文本写入和 update logging。`src/fpdev.fpc.manager.pas` 只保留对外导出的薄 wrapper。manager 内部重复的 `TryParseInt(...)` / `ParseVersion(...)` / `CompareSemVer(...)` / `SameMajorMinor(...)` 直接删除，统一回到已有 shared semver 定义源。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化切口

**Files:**
- Inspect: `src/fpdev.fpc.manager.pas`
- Reference: `src/fpdev.fpc.types.pas`
- Reference: `src/fpdev.cmd.fpc.update.pas`

**Step 1: helper 公开符号**

- `ExecuteFPCUpdateIndexCore(...)`
- `BuildFPCIndexJSONCore(...)`

**Step 2: 锁定必须保持的行为**

- `FPC_UpdateIndex(...)` 继续写到 `<install_root>/cache/fpc/index.json`
- JSON 结构继续包含 `version`, `updated_at`, `items`
- `items[*]` 继续包含 `version`, `tag`, `branch`, `channel`
- command 调用面不变

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_fpc_manager_index_boundary.py`
- Create: `tests/test_fpc_indexflow.lpr`

**Step 1: boundary**

- `src/fpdev.fpc.manager.pas` 必须引入 `fpdev.fpc.indexflow`
- `FPC_UpdateIndex(...)` 必须调用 `ExecuteFPCUpdateIndexCore(...)`
- manager 不再本地定义 `TryParseInt(...)`
- manager 不再本地定义 `CompareSemVer(...)`

**Step 2: direct helper**

- index json helper 生成 `items` 和 channel 字段
- update index helper 在临时 install root 下落出 `cache/fpc/index.json`

### Task 3: 实现 helper 并回接 manager

**Files:**
- Create: `src/fpdev.fpc.indexflow.pas`
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: focused verification**

Run: `python3 -m unittest tests.test_fpc_manager_index_boundary -v`

Run: `mkdir -p /tmp/fpdev-fpc-indexflow-bin /tmp/fpdev-fpc-indexflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-indexflow-bin -FU/tmp/fpdev-fpc-indexflow-lib tests/test_fpc_indexflow.lpr`

Run: `/tmp/fpdev-fpc-indexflow-bin/test_fpc_indexflow`
