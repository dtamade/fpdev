# FPC Manager Statusflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.fpc.manager.pas`，把 `GetStatus(...)` 的 manager 级状态编排下沉到共享 helper，锁住状态查询边界，并为后续 manager hotspot wave 建立可复用模式。

**Architecture:** 新增 `src/fpdev.fpc.statusflow.pas`，集中承接 FPC status orchestration：默认值初始化、configured/default install path 解析、metadata 到 status 的映射、缺失 executable 的错误收口。`src/fpdev.fpc.manager.pas` 只保留 facade 调度，继续通过现有 manager 方法提供 toolchain lookup、metadata read 与 scope infer callback；不再在 `GetStatus(...)` 中内联 install-path/metadata/verify 细节。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Add boundary RED for manager status delegation

**Files:**
- Create: `tests/test_fpc_manager_status_boundary.py`
- Inspect: `src/fpdev.fpc.manager.pas`

**Step 1: Write the failing boundary test**

- Require `src/fpdev.fpc.manager.pas` to import `fpdev.fpc.statusflow`
- Require `GetStatus(...)` to delegate to `BuildManagedFPCStatusCore(...)`
- Require `GetStatus(...)` to pass manager callbacks for:
  - toolchain lookup
  - metadata read
  - status scope inference

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_fpc_manager_status_boundary -v
```

Expected: FAIL because `fpdev.fpc.statusflow` does not exist yet and `GetStatus(...)` still owns the orchestration inline.

### Task 2: Add direct RED coverage for shared status helper

**Files:**
- Create: `tests/test_fpc_statusflow.lpr`
- Reuse: `tests/test_fpc_status.lpr`

**Step 1: Write focused helper tests**

- `BuildManagedFPCStatusCore(...)` with empty configured default returns success and default unknown state
- configured install path overrides default install path
- metadata drives scope/source/verify mapping
- missing executable returns `False` and reports the managed prefix

**Step 2: Run test to verify it fails**

Run:

```bash
mkdir -p /tmp/fpdev-fpc-statusflow-bin-red /tmp/fpdev-fpc-statusflow-lib-red
fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-fpc-statusflow-bin-red -FU/tmp/fpdev-fpc-statusflow-lib-red tests/test_fpc_statusflow.lpr
/tmp/fpdev-fpc-statusflow-bin-red/test_fpc_statusflow
```

Expected: FAIL because `fpdev.fpc.statusflow` or its symbols do not exist yet.

### Task 3: Implement the shared statusflow helper

**Files:**
- Create: `src/fpdev.fpc.statusflow.pas`

**Step 1: Add minimal helper API**

- `InitializeFPCStatusInfoCore(...)`
- `ResolveManagedFPCStatusInstallPathCore(...)`
- `BuildManagedFPCStatusCore(...)`

**Step 2: Keep helper boundaries clean**

- helper owns status initialization, install-path resolution, metadata mapping, and missing executable error wording
- helper does not access config manager directly; it only uses manager-provided callbacks

### Task 4: Rewire manager GetStatus

**Files:**
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: Delegate status orchestration**

- keep `LookupToolchainInfo(...)`, `ReadMetadata(...)`, `InferStatusScope(...)` as manager-owned callbacks
- make `GetStatus(...)` call `BuildManagedFPCStatusCore(...)`

**Step 2: Avoid boundary regression**

- do not re-inline `ReadFPCMetadata(...)`
- do not re-inline executable existence check
- do not move CLI formatting into manager

### Task 5: Run focused verification

**Files:**
- Reuse: `tests/test_fpc_status.lpr`

**Step 1: Run the new boundary test**

Run:

```bash
python3 -m unittest tests.test_fpc_manager_status_boundary -v
```

Expected: PASS

**Step 2: Run the direct helper test**

Run:

```bash
fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-fpc-statusflow-bin -FU/tmp/fpdev-fpc-statusflow-lib tests/test_fpc_statusflow.lpr
/tmp/fpdev-fpc-statusflow-bin/test_fpc_statusflow
```

Expected: PASS

**Step 3: Run the command-facing status suite**

Run:

```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-status-bin -FU/tmp/fpdev-fpc-status-lib tests/test_fpc_status.lpr
/tmp/fpdev-fpc-status-bin/test_fpc_status
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
