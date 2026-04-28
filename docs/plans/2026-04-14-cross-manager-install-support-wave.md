# Cross Manager Install-Support Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.cross.manager.pas`，把 `DownloadBinutils(...)`、`DownloadLibraries(...)`、`SetupCrossEnvironment(...)` 这组 install-support surface 下沉到共享 helper，保持 manager 只持有 downloader/config/query wiring 与外层 facade。

**Architecture:** 新增 `src/fpdev.cross.installsupportflow.pas`，承接 downloader output、manual fallback、cross target config assembly 与 save wiring。`src/fpdev.cross.manager.pas` 保留 `FDownloader` / `FQuery` / `FConfigManager` ownership，以及 `InstallTarget(...)` / `UpdateTarget(...)` 对 `managerflow` 的委托，不回退已完成的 `managerflow` thin facade。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 install-support 最小切口

**Files:**
- Inspect: `src/fpdev.cross.manager.pas`
- Reuse: `src/fpdev.cross.managerflow.pas`
- Test: `tests/test_cross_manager_boundary.py`
- Test: `tests/test_cross_management.lpr`

**Step 1: 锁定必须下沉的职责**

- `DownloadBinutils(...)` 的 output fallback、downloader guard、success/fail 文案与 manual fallback
- `DownloadLibraries(...)` 的 output fallback、optional/manual fallback
- `SetupCrossEnvironment(...)` 的 install path resolve、`TCrossTarget` 组装与 config save

**Step 2: 锁定不改的边界**

- 不改 `ExecuteCrossInstallTargetCore(...)` / `ExecuteCrossUpdateTargetCore(...)` 的外部契约
- 不改 `DetectSystemCompilerForTarget(...)`、`SaveCrossTargetConfig(...)`、`RemoveCrossTargetConfig(...)` 的对外行为
- 不改 `cross.query` 里的 target inventory / info schema

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_cross_manager_boundary.py`
- Create: `tests/test_cross_installsupportflow.lpr`

**Step 1: 扩展 Python boundary**

- 断言 manager 引入 `fpdev.cross.installsupportflow`
- 断言 `DownloadBinutils(...)` / `DownloadLibraries(...)` 改为委托 shared helper，而不是在 manager 内保留文案控制流
- 断言 `SetupCrossEnvironment(...)` 改为委托 helper，而不是在 manager 内直接组装 `TCrossTarget`

**Step 2: 新增 direct helper test**

- `tests/test_cross_installsupportflow.lpr` 直接覆盖：
  - downloader 缺失时返回失败并输出错误
  - binutils 下载失败时写入 manual package-manager fallback
  - libraries 下载失败时允许 manual configuration success
  - setup-environment 正确构造 `BinutilsPath` / `LibrariesPath` 并保存 config

**Step 3: 运行 RED 证据**

Run: `python3 -m unittest tests.test_cross_manager_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-cross-installsupport-bin-red -FU/tmp/fpdev-cross-installsupport-lib-red tests/test_cross_installsupportflow.lpr`

Run: `/tmp/fpdev-cross-installsupport-bin-red/test_cross_installsupportflow`

Expected: FAIL，因为 installsupportflow unit/helper 尚未存在，且 manager 仍保留 inline downloader/environment glue。

### Task 3: 实现最小 install-support helper 并回接 manager

**Files:**
- Create: `src/fpdev.cross.installsupportflow.pas`
- Modify: `src/fpdev.cross.manager.pas`
- Test: `tests/test_cross_installsupportflow.lpr`

**Step 1: 新建 helper 单元**

- 定义 downloader、output、install-path、config-save 所需 callback / interface 参数
- helper 只承接 install-support surface，不重写 `managerflow`

**Step 2: 添加最小 core helper**

- `ExecuteCrossDownloadBinutilsSurfaceCore(...)`
- `ExecuteCrossDownloadLibrariesSurfaceCore(...)`
- `ExecuteCrossSetupEnvironmentSurfaceCore(...)`

**Step 3: 让 manager 收缩为 thin delegate**

- `DownloadBinutils(...)` / `DownloadLibraries(...)` / `SetupCrossEnvironment(...)` 只做 dependency wiring
- `InstallTarget(...)` / `UpdateTarget(...)` 继续复用现有 `managerflow`

### Task 4: Focused Verification

**Files:**
- Verify: `tests/test_cross_manager_boundary.py`
- Verify: `tests/test_cross_installsupportflow.lpr`
- Verify: `tests/test_cross_managerflow.lpr`
- Verify: `tests/test_cross_management.lpr`
- Verify: `tests/test_cross_targetflow.lpr`

**Step 1: 跑 boundary 与 direct helper**

Run: `python3 -m unittest tests.test_cross_manager_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-cross-installsupport-bin -FU/tmp/fpdev-cross-installsupport-lib tests/test_cross_installsupportflow.lpr && /tmp/fpdev-cross-installsupport-bin/test_cross_installsupportflow`

**Step 2: 跑 Cross focused regression**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-cross-managerflow-bin -FU/tmp/fpdev-cross-managerflow-lib tests/test_cross_managerflow.lpr && /tmp/fpdev-cross-managerflow-bin/test_cross_managerflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-cross-management-bin -FU/tmp/fpdev-cross-management-lib tests/test_cross_management.lpr && /tmp/fpdev-cross-management-bin/test_cross_management`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-cross-targetflow-bin -FU/tmp/fpdev-cross-targetflow-lib tests/test_cross_targetflow.lpr && /tmp/fpdev-cross-targetflow-bin/test_cross_targetflow`

Expected: 全绿，且 `src/fpdev.cross.manager.pas` 只保留 thin facade + dependency wiring。
