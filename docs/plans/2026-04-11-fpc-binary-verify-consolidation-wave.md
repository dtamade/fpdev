# FPC Binary Verify Consolidation Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 收口 binary install 路径的 verify orchestration，删除孤立的旧 verifier 实现，并把 binary verify 边界固化成回归契约。

**Architecture:** `src/fpdev.fpc.binary.pas` 不再直接持有 `TFPCVerifier`，而是改用 `src/fpdev.fpc.verifyflow.pas` 提供的 shared verification flow。孤立且无生产消费者的 `src/fpdev.fpc.verifier.pas` 直接删除，相关测试改为检查 legacy duplicate 已被移除。

**Tech Stack:** Object Pascal (FPC), fpcunit, Python unittest

---

### Task 1: Add Boundary RED For Binary Verify Consolidation

**Files:**
- Create: `tests/test_fpc_binary_verify_boundary.py`
- Inspect: `src/fpdev.fpc.binary.pas`
- Inspect: `src/fpdev.fpc.verifyflow.pas`
- Inspect: `src/fpdev.fpc.verifier.pas`

**Step 1: Write the failing boundary test**

- Require `src/fpdev.fpc.binary.pas` to import `fpdev.fpc.verifyflow`.
- Require `src/fpdev.fpc.binary.pas` to stop storing verifier state and stop calling `VerifyVersion(...)`, `CompileHelloWorld(...)`, `GenerateMetadata(...)` directly.
- Require binary install verification to delegate to shared verifyflow entrypoints.
- Require `src/fpdev.fpc.verifier.pas` to be removed.

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_fpc_binary_verify_boundary -v
```

Expected: FAIL because binary installer still embeds direct verifier orchestration and the legacy verifier file still exists.

### Task 2: Consolidate Binary Verify Flow

**Files:**
- Modify: `src/fpdev.fpc.verifyflow.pas`
- Modify: `src/fpdev.fpc.binary.pas`
- Delete: `src/fpdev.fpc.verifier.pas`
- Modify: `tests/test_style_regressions_batch16.py`

**Step 1: Extend shared verifyflow**

- Add a reusable installed-compiler verification helper that returns `TVerificationResult` without tying behavior to manager output/writers.
- Add a binary metadata writer helper that persists `.fpdev-meta.json` via shared metadata helpers instead of `TFPCVerifier.GenerateMetadata(...)`.

**Step 2: Shrink binary installer responsibilities**

- Remove `FVerifier` field and lifecycle management from `TBinaryInstaller`.
- Change binary install verify path to:
  - run shared verification core
  - map verification failure into `FLastError`
  - persist metadata via shared binary metadata helper
- Keep current user-facing `WriteLn(...)` milestones intact where practical.

**Step 3: Remove the dead duplicate verifier unit**

- Delete `src/fpdev.fpc.verifier.pas`.
- Repoint `tests/test_style_regressions_batch16.py` to assert the duplicate unit is gone instead of style-checking a dead file.

**Step 4: Re-run boundary test**

Run:

```bash
python3 -m unittest tests.test_fpc_binary_verify_boundary -v
```

Expected: PASS

### Task 3: Focused Regression

**Files:**
- Verify: `tests/test_binary_installer_unit.lpr`
- Verify: `tests/test_fpc_install_integration.lpr`
- Verify: `tests/test_fpc_verifier.lpr`
- Verify: `tests/test_style_regressions_batch16.py`

**Step 1: Run focused tests**

Run:

```bash
mkdir -p /tmp/fpdev-test-bin/fpc-binary-verify-wave /tmp/fpdev-test-lib/fpc-binary-verify-wave
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-binary-verify-wave -FU/tmp/fpdev-test-lib/fpc-binary-verify-wave tests/test_binary_installer_unit.lpr
/tmp/fpdev-test-bin/fpc-binary-verify-wave/test_binary_installer_unit
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-binary-verify-wave -FU/tmp/fpdev-test-lib/fpc-binary-verify-wave tests/test_fpc_install_integration.lpr
/tmp/fpdev-test-bin/fpc-binary-verify-wave/test_fpc_install_integration
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-binary-verify-wave -FU/tmp/fpdev-test-lib/fpc-binary-verify-wave tests/test_fpc_verifier.lpr
/tmp/fpdev-test-bin/fpc-binary-verify-wave/test_fpc_verifier
python3 -m unittest tests.test_fpc_binary_verify_boundary tests.test_style_regressions_batch16 -v
```

Expected: all pass.

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

**Step 1: Record the consolidation**

- Record that binary install verify now reuses shared verifyflow.
- Record that legacy `src/fpdev.fpc.verifier.pas` was removed.
- Record focused + full verification evidence.
