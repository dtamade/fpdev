# FPC Manager Verify Orchestration Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续收缩 FPC verify 链路，把 `TFPCManager` 中剩余的 verify orchestration 抽到独立 flow，避免 manager 再次直接持有 runtime verification 细节。

**Architecture:** 新增 `src/fpdev.fpc.verifyflow.pas`，集中承接两段 manager 级 verify orchestration：安装后 refresh verify、以及显式 `VerifyInstallation(...)` 后的 metadata 回写。`TFPCManager` 只保留 facade/dispatch 职责，继续通过 `TFPCValidator` 做显式验证，通过 metadata writer 回写结果；不再直接 new `TFPCVerifier`，也不再在 manager 内拼接 post-install verify 分支。

**Tech Stack:** Object Pascal (FPC), fpcunit, Python unittest

---

### Task 1: Add Boundary RED For Manager Verify Orchestration

**Files:**
- Create: `tests/test_fpc_manager_verify_boundary.py`
- Inspect: `src/fpdev.fpc.manager.pas`
- Inspect: `src/fpdev.fpc.verify.pas`
- Inspect: `src/fpdev.fpc.installversionflow.pas`

**Step 1: Write the failing boundary test**

- Require `src/fpdev.fpc.manager.pas` to import `fpdev.fpc.verifyflow`.
- Require `src/fpdev.fpc.manager.pas` to stop instantiating `TFPCVerifier` directly inside manager-level verify orchestration.
- Require `RefreshInstallVerificationMetadata(...)` and `VerifyInstallation(...)` to delegate to `fpdev.fpc.verifyflow` entrypoints instead of re-implementing the orchestration inline.

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_fpc_manager_verify_boundary -v
```

Expected: FAIL because `src/fpdev.fpc.verifyflow.pas` does not exist yet and `src/fpdev.fpc.manager.pas` still owns direct `TFPCVerifier` orchestration.

### Task 2: Extract Shared Manager Verify Flow

**Files:**
- Create: `src/fpdev.fpc.verifyflow.pas`
- Modify: `src/fpdev.fpc.manager.pas`
- Reuse: `src/fpdev.fpc.verify.pas`
- Reuse: `src/fpdev.fpc.installversionflow.pas`

**Step 1: Add the flow unit**

- Add `PersistManagedFPCVerificationResultCore(...)` to resolve the real install path from the preferred managed path and write verification metadata only when the resolved install dir exists.
- Add `RefreshInstalledFPCVerificationCore(...)` to:
  - build the installed `fpc` executable path
  - run `fpdev.fpc.verify.TFPCVerifier`
  - populate `TVerificationResult`
  - emit warnings through `IOutput`
  - always attempt metadata backfill through the supplied writer callback

**Step 2: Shrink manager responsibilities**

- Keep `UpdateVerificationMetadata(...)` as the manager-owned metadata writer callback.
- Change `RefreshInstallVerificationMetadata(...)` to delegate to `RefreshInstalledFPCVerificationCore(...)`.
- Change `VerifyInstallation(...)` to:
  - keep `FValidatorMgr.VerifyInstallation(...)`
  - delegate metadata persistence to `PersistManagedFPCVerificationResultCore(...)`
- Remove manager-local direct `TFPCVerifier.Create`, `VerifyVersion(...)`, and `CompileHelloWorld(...)` orchestration from the manager unit.

**Step 3: Re-run boundary test**

Run:

```bash
python3 -m unittest tests.test_fpc_manager_verify_boundary -v
```

Expected: PASS

### Task 3: Lock Behavior With Focused Regression

**Files:**
- Verify: `tests/test_fpc_verify.lpr`
- Verify: `tests/test_cli_fpc_diag.lpr`
- Verify: `tests/test_fpc_manager_installmetadata.lpr`
- Verify: `tests/test_fpc_validator_runtimeflow.lpr`

**Step 1: Run focused Pascal suites in `/tmp`**

Run:

```bash
mkdir -p /tmp/fpdev-test-bin/fpc-manager-verify-wave /tmp/fpdev-test-lib/fpc-manager-verify-wave
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-manager-verify-wave -FU/tmp/fpdev-test-lib/fpc-manager-verify-wave tests/test_fpc_manager_installmetadata.lpr
/tmp/fpdev-test-bin/fpc-manager-verify-wave/test_fpc_manager_installmetadata
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-manager-verify-wave -FU/tmp/fpdev-test-lib/fpc-manager-verify-wave tests/test_fpc_verify.lpr
/tmp/fpdev-test-bin/fpc-manager-verify-wave/test_fpc_verify
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-manager-verify-wave -FU/tmp/fpdev-test-lib/fpc-manager-verify-wave tests/test_fpc_validator_runtimeflow.lpr
/tmp/fpdev-test-bin/fpc-manager-verify-wave/test_fpc_validator_runtimeflow
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-manager-verify-wave -FU/tmp/fpdev-test-lib/fpc-manager-verify-wave tests/test_cli_fpc_diag.lpr
/tmp/fpdev-test-bin/fpc-manager-verify-wave/test_cli_fpc_diag
```

Expected: all pass, and metadata backfill behavior remains unchanged for legacy path, configured path, and CLI verify entrypoints.

**Step 2: Run repository-standard regression**

Run:

```bash
bash scripts/run_all_tests.sh
```

Expected: current all-green total remains green.

### Task 4: Planning Sync

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Record the extraction**

- Record that manager-level verify orchestration moved into `src/fpdev.fpc.verifyflow.pas`.
- Record that `TFPCManager` now delegates both post-install refresh and explicit verify-result persistence.
- Record verification evidence from the new Python boundary suite, focused Pascal suites, and `scripts/run_all_tests.sh`.

**Step 2: Note the next likely cleanup**

- Record that `src/fpdev.fpc.verifier.pas` is now an isolated duplicate implementation candidate and should be evaluated separately after this wave, not folded into the same patch unless new evidence requires it.
