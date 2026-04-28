# FPC Manager Versionflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.fpc.manager.pas`，把版本列表输出与激活编排下沉到共享 helper，减少 manager 对文本输出和 activation glue 的内联持有。

**Architecture:** 新增 `src/fpdev.fpc.versionflow.pas`，集中承接三类 manager 级职责：默认版本名归一化、文本版版本列表渲染、以及 activate-then-set-default 的 orchestration。`src/fpdev.fpc.manager.pas` 只保留 facade 调度，并继续通过 `TFPCVersionManager` / `TFPCActivationManager` 提供查询与激活依赖；`src/fpdev.fpc.version.pas` 复用 shared normalization helper，避免默认版本解析逻辑再次分叉。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Add boundary RED for manager versionflow delegation

**Files:**
- Create: `tests/test_fpc_manager_version_boundary.py`
- Inspect: `src/fpdev.fpc.manager.pas`

**Step 1: Write the failing boundary test**

- Require `src/fpdev.fpc.manager.pas` to import `fpdev.fpc.versionflow`
- Require `ListVersions(...)` to delegate to `WriteManagedFPCVersionListCore(...)`
- Require `ActivateVersion(...)` to delegate to `ActivateManagedFPCVersionCore(...)`
- Require manager to stop owning the `for i := 0 to High(Versions)` loop and activation glue inline

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_fpc_manager_version_boundary -v
```

Expected: FAIL because `fpdev.fpc.versionflow` does not exist yet and manager still owns list/activation orchestration inline.

### Task 2: Add direct RED coverage for shared versionflow helper

**Files:**
- Create: `tests/test_fpc_versionflow.lpr`
- Reuse: `tests/test_cli_fpc_info.lpr`
- Reuse: `tests/test_fpc_use.lpr`

**Step 1: Write focused helper tests**

- `NormalizeDefaultFPCVersionCore(...)`
- `WriteManagedFPCVersionListCore(...)`
- `ActivateManagedFPCVersionCore(...)`

Cover:
- `fpc-3.2.2` normalizes to `3.2.2`
- list helper marks default installed version with `Installed*`
- activation helper builds `<install>/bin` path and only sets default after activation succeeds
- activation helper fails cleanly when version is not installed

**Step 2: Run test to verify it fails**

Run:

```bash
mkdir -p /tmp/fpdev-fpc-versionflow-bin-red /tmp/fpdev-fpc-versionflow-lib-red
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-versionflow-bin-red -FU/tmp/fpdev-fpc-versionflow-lib-red tests/test_fpc_versionflow.lpr
/tmp/fpdev-fpc-versionflow-bin-red/test_fpc_versionflow
```

Expected: FAIL because `fpdev.fpc.versionflow` or its symbols do not exist yet.

### Task 3: Implement shared versionflow helper

**Files:**
- Create: `src/fpdev.fpc.versionflow.pas`

**Step 1: Add minimal helper API**

- `NormalizeDefaultFPCVersionCore(...)`
- `WriteManagedFPCVersionListCore(...)`
- `ActivateManagedFPCVersionCore(...)`

**Step 2: Keep helper boundaries clean**

- helper owns default-toolchain normalization, textual listing, and activate-then-default orchestration
- helper does not access config manager directly; it only uses callbacks and plain data

### Task 4: Rewire manager and version service

**Files:**
- Modify: `src/fpdev.fpc.manager.pas`
- Modify: `src/fpdev.fpc.version.pas`

**Step 1: Delegate manager responsibilities**

- make `ListVersions(...)` call `WriteManagedFPCVersionListCore(...)`
- make `ActivateVersion(...)` call `ActivateManagedFPCVersionCore(...)`

**Step 2: Reuse shared normalization**

- make `src/fpdev.fpc.version.pas` use `NormalizeDefaultFPCVersionCore(...)` in `GetCurrentVersion(...)` and any matching path

### Task 5: Run focused verification

Run:

```bash
python3 -m unittest tests.test_fpc_manager_version_boundary -v
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-versionflow-bin -FU/tmp/fpdev-fpc-versionflow-lib tests/test_fpc_versionflow.lpr
/tmp/fpdev-fpc-versionflow-bin/test_fpc_versionflow
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-use-bin -FU/tmp/fpdev-fpc-use-lib tests/test_fpc_use.lpr
/tmp/fpdev-fpc-use-bin/test_fpc_use
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-info-bin -FU/tmp/fpdev-fpc-info-lib tests/test_cli_fpc_info.lpr
/tmp/fpdev-fpc-info-bin/test_cli_fpc_info
```

Expected: PASS

### Task 6: Run regression and sync docs

**Files:**
- Modify: `docs/history/B171-large-files-report.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Update hotspot truth**

- sync current `src/fpdev.fpc.manager.pas` line count
- record the new helper unit

**Step 2: Run full regression**

Run:

```bash
bash scripts/run_all_tests.sh
```

Expected: PASS
