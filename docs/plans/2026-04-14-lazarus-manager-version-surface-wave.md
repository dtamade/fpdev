# Lazarus Manager Version Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.manager.pas`，把版本列表输出、默认版本切换、当前版本解析以及版本信息展示 surface 下沉到 shared helper，保持 manager 只持有 config access 与 facade wiring。

**Architecture:** 新增 `src/fpdev.lazarus.versionflow.pas`，复用现有 `metadataflow` 类型与查找 helper，不重开 install/runtime 逻辑。新的 helper 负责 list/default/current/info 这组 manager-level version surface；`src/fpdev.lazarus.manager.pas` 保留 config manager、installed/configured lookups 与异常边界。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 version surface 最小切口

**Files:**
- Inspect: `src/fpdev.lazarus.manager.pas`
- Reuse: `src/fpdev.lazarus.metadataflow.pas`
- Reuse: `tests/test_lazarus_manager_metadata_boundary.py`
- Reuse: `tests/test_lazarus_management.lpr`

**Step 1: 锁定必须下沉的职责**

- `ListVersions(...)` 的文本渲染与 default-version normalization
- `SetDefaultVersion(...)` 的 installed guard + set-default output glue
- `GetCurrentVersion(...)` 的 default-name normalization
- `ShowVersionInfo(...)` 的版本查找/输出 surface

**Step 2: 锁定不改的边界**

- 不改 `GetAvailableVersions(...)` / `TryGetConfiguredVersionInfo(...)` / `TryGetConfiguredVersionInfo(...)` 的底层来源
- 不改 runtimeactions / installcallbacks 已有 helper wiring
- 不改用户可见版本命名规范 `lazarus-<version>`

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_lazarus_manager_version_boundary.py`
- Create: `tests/test_lazarus_versionflow.lpr`

**Step 1: 扩展 boundary 契约**

- 断言 manager 引入 `fpdev.lazarus.versionflow`
- 断言 `ListVersions(...)` / `SetDefaultVersion(...)` / `GetCurrentVersion(...)` / `ShowVersionInfo(...)` 调用 shared helper
- 断言 manager 不再内联版本列表文本拼接与 default-prefix 归一化

**Step 2: 新增 direct helper RED**

- 为 list/default/current/info helper 写最小 probe 测试
- 覆盖 default-name strip、installed-only guard、show-info fallback 到 configured version 的行为

**Step 3: Run test to verify it fails**

Run:
```bash
python3 -m unittest tests.test_lazarus_manager_version_boundary -v
mkdir -p /tmp/fpdev-lazarus-versionflow-bin-red /tmp/fpdev-lazarus-versionflow-lib-red
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-versionflow-bin-red -FU/tmp/fpdev-lazarus-versionflow-lib-red tests/test_lazarus_versionflow.lpr
/tmp/fpdev-lazarus-versionflow-bin-red/test_lazarus_versionflow
```

Expected: FAIL，因为 `fpdev.lazarus.versionflow` 与对应 helper 符号还不存在。

### Task 3: 实现 versionflow 并回接 manager

**Files:**
- Create: `src/fpdev.lazarus.versionflow.pas`
- Modify: `src/fpdev.lazarus.manager.pas`

**Step 1: 在 helper 中实现最小 API**

- list surface helper
- default/current normalization helper
- version info surface helper

**Step 2: 收缩 manager**

- `ListVersions(...)` / `SetDefaultVersion(...)` / `GetCurrentVersion(...)` / `ShowVersionInfo(...)` 改为 thin delegate
- manager 继续持有 config lookup 与 configured version info callback

### Task 4: Focused Verification

**Files:**
- Reuse: `tests/test_lazarus_manager_metadataflow.lpr`
- Reuse: `tests/test_lazarus_management.lpr`
- Reuse: `tests/test_cli_lazarus.lpr`

**Step 1: Run focused suites**

Run:
```bash
python3 -m unittest tests.test_lazarus_manager_version_boundary tests.test_lazarus_manager_metadata_boundary tests.test_lazarus_manager_runtime_boundary -v
mkdir -p /tmp/fpdev-lazarus-versionflow-bin /tmp/fpdev-lazarus-versionflow-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-versionflow-bin -FU/tmp/fpdev-lazarus-versionflow-lib tests/test_lazarus_versionflow.lpr
/tmp/fpdev-lazarus-versionflow-bin/test_lazarus_versionflow
mkdir -p /tmp/fpdev-lazarus-metadataflow-bin /tmp/fpdev-lazarus-metadataflow-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-metadataflow-bin -FU/tmp/fpdev-lazarus-metadataflow-lib tests/test_lazarus_manager_metadataflow.lpr
/tmp/fpdev-lazarus-metadataflow-bin/test_lazarus_manager_metadataflow
mkdir -p /tmp/fpdev-lazarus-management-bin /tmp/fpdev-lazarus-management-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-management-bin -FU/tmp/fpdev-lazarus-management-lib tests/test_lazarus_management.lpr
/tmp/fpdev-lazarus-management-bin/test_lazarus_management
```

Expected: PASS
