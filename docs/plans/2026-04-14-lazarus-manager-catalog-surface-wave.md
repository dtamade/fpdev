# Lazarus Manager Catalog Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.manager.pas`，把 catalog/configured merge surface 下沉到共享 helper，保持 manager 只持有 config access、registry access 与 facade wiring。

**Architecture:** 新增 `src/fpdev.lazarus.catalogflow.pas`，承接 `GetCompatibleFPCVersion(...)`、`GetAvailableVersions(...)`、`GetInstalledVersions(...)` 这组 catalog surface 的共享装配。helper 复用既有 `fpdev.lazarus.metadataflow` / `fpdev.lazarus.types`，不重新吸回 config I/O、install/runtime 行为；`src/fpdev.lazarus.manager.pas` 继续保留 `TryGetConfiguredVersionInfo(...)`、`IsVersionInstalled(...)`、`GetResolvedInstallPath(...)` 等 manager-owned callback。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 catalog surface 最小切口

**Files:**
- Inspect: `src/fpdev.lazarus.manager.pas`
- Reuse: `src/fpdev.lazarus.metadataflow.pas`
- Reuse: `src/fpdev.lazarus.types.pas`
- Test: `tests/test_lazarus_manager_metadata_boundary.py`
- Test: `tests/test_lazarus_management.lpr`

**Step 1: 锁定本波必须下沉的职责**

- `GetCompatibleFPCVersion(...)` 的 configured-info 优先级与 registry fallback
- `GetAvailableVersions(...)` 的 release -> version info 映射、configured version merge、prefix normalize
- `GetInstalledVersions(...)` 的 installed filter glue

**Step 2: 锁定不改的边界**

- 不改 `TryGetConfiguredVersionInfo(...)` / `TryGetConfiguredLazarusInfo(...)` 的 config 读取实现
- 不改 `metadataflow` 已有 merge/filter helper 的对外契约
- 不改 `ListVersions(...)` / `ShowVersionInfo(...)` / install/runtime helper wiring

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_lazarus_manager_metadata_boundary.py`
- Create: `tests/test_lazarus_catalogflow.lpr`

**Step 1: 扩展 Python boundary**

- 断言 `src/fpdev.lazarus.manager.pas` 引入 `fpdev.lazarus.catalogflow`
- 断言 `GetAvailableVersions(...)` 调用新的 catalog helper，而不是在 manager 内继续保留 release-loop / configured-prefix merge 细节
- 断言 `GetInstalledVersions(...)` 改为通过 shared helper/filter surface 装配，而不是重新拼接数组
- 断言 `GetCompatibleFPCVersion(...)` 改为委托 catalog helper，而不是内联 configured-fallback 逻辑

**Step 2: 新增 direct helper test**

- `tests/test_lazarus_catalogflow.lpr` 直接覆盖：
  - configured FPC version 命中优先于 registry fallback
  - registry release inventory 正常映射到 `TLazarusVersionArray`
  - configured `lazarus-<version>` 前缀被规范化后参与 merge
  - installed-only 过滤复用 metadataflow 契约

**Step 3: 运行 RED 证据**

Run: `python3 -m unittest tests.test_lazarus_manager_metadata_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-catalog-bin-red -FU/tmp/fpdev-lazarus-catalog-lib-red tests/test_lazarus_catalogflow.lpr`

Run: `/tmp/fpdev-lazarus-catalog-bin-red/test_lazarus_catalogflow`

Expected: FAIL，因为 `fpdev.lazarus.catalogflow` 及其 helper 尚不存在，且 manager 仍保留 inline catalog glue。

### Task 3: 实现最小 catalog helper 并回接 manager

**Files:**
- Create: `src/fpdev.lazarus.catalogflow.pas`
- Modify: `src/fpdev.lazarus.manager.pas`
- Test: `tests/test_lazarus_catalogflow.lpr`

**Step 1: 新建 helper 单元**

- 新增 object-method callback types，承接：
  - configured version info lookup
  - installed check
  - registry recommended FPC lookup / release inventory input
- helper 只处理 catalog surface 组装，不直接访问 config manager 或输出设备

**Step 2: 添加最小 core helper**

- 为 `GetCompatibleFPCVersion(...)` 提供统一 fallback helper
- 为 release inventory -> `TLazarusVersionArray` 构建提供 shared helper
- 为 configured versions merge + installed filter 提供 surface helper

**Step 3: 让 manager 收缩为 thin delegate**

- `GetCompatibleFPCVersion(...)`、`GetAvailableVersions(...)`、`GetInstalledVersions(...)` 只保留 state assembly + callback wiring
- 不回退已完成的 `metadataflow` / `versionflow` / `runtimeactions` 结构

### Task 4: Focused Verification

**Files:**
- Verify: `tests/test_lazarus_manager_metadata_boundary.py`
- Verify: `tests/test_lazarus_catalogflow.lpr`
- Verify: `tests/test_lazarus_management.lpr`
- Verify: `tests/test_lazarus_versionflow.lpr`

**Step 1: 跑 boundary 与 direct helper**

Run: `python3 -m unittest tests.test_lazarus_manager_metadata_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-catalog-bin -FU/tmp/fpdev-lazarus-catalog-lib tests/test_lazarus_catalogflow.lpr && /tmp/fpdev-lazarus-catalog-bin/test_lazarus_catalogflow`

**Step 2: 跑 Lazarus focused regression**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-management-bin -FU/tmp/fpdev-lazarus-management-lib tests/test_lazarus_management.lpr && /tmp/fpdev-lazarus-management-bin/test_lazarus_management`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-version-bin -FU/tmp/fpdev-lazarus-version-lib tests/test_lazarus_versionflow.lpr && /tmp/fpdev-lazarus-version-bin/test_lazarus_versionflow`

Expected: 全绿，且 manager 继续保持 thin facade。
