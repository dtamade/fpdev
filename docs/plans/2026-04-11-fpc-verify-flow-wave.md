# FPC Verify Flow Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 收缩 FPC verify 链路的职责边界，统一 mock FPC 测试 helper，并为重复类型/脆弱测试路径补防回归契约。

**Architecture:** `TFPCValidator` 继续负责安装路径与配置解析，但把“可执行文件版本检查 + hello world smoke test”委托给已有的 `fpdev.fpc.verify.TFPCVerifier`。测试侧新增共享 `test_fpc_mock_helpers` 单元，统一编译 `tests/mock_fpc.pas`，并用 Python 边界测试禁止回到局部 helper 和 `ParamStr(0)` 拼路径。

**Tech Stack:** Object Pascal (FPC), fpcunit, Python unittest

---

### Task 1: Add Boundary RED For Verify Flow And Mock Helper Reuse

**Files:**
- Create: `tests/test_fpc_verify_boundary.py`
- Inspect: `src/fpdev.fpc.validator.pas`
- Inspect: `tests/test_fpc_verify.lpr`
- Inspect: `tests/test_fpc_manager_installmetadata.lpr`
- Inspect: `tests/test_cli_fpc_diag.lpr`

**Step 1: Write the failing boundary test**

- Require `src/fpdev.fpc.validator.pas` to delegate executable verification to `fpdev.fpc.verify`.
- Require the validator unit to stop declaring its own `RunSmokeTest`.
- Require the three Pascal tests to import a shared `test_fpc_mock_helpers` unit instead of local `CompileMockFPC*` procedures.
- Require the same three Pascal tests to avoid direct `ParamStr(0)`-based `mock_fpc.pas` path reconstruction.

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_fpc_verify_boundary -v
```

Expected: FAIL because `test_fpc_mock_helpers` does not exist yet and `src/fpdev.fpc.validator.pas` still contains inline executable verification logic.

### Task 2: Extract Shared Mock FPC Test Helper

**Files:**
- Create: `tests/test_fpc_mock_helpers.pas`
- Modify: `tests/test_fpc_verify.lpr`
- Modify: `tests/test_fpc_manager_installmetadata.lpr`
- Modify: `tests/test_cli_fpc_diag.lpr`

**Step 1: Write minimal shared helper**

- Add `CompileMockFPCBinary(const ATargetPath: string)` to `tests/test_fpc_mock_helpers.pas`.
- Reuse `ResolveTestAssetPath('tests' + PathDelim + 'mock_fpc.pas')`.
- Ensure the target directory exists before invoking `fpc`.

**Step 2: Switch callers**

- Remove the three local `CompileMockFPC*` procedures.
- Import and use `test_fpc_mock_helpers`.

**Step 3: Verify focused compile**

Run:

```bash
mkdir -p /tmp/fpdev-test-bin/mock-helper /tmp/fpdev-test-lib/mock-helper
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/mock-helper -FU/tmp/fpdev-test-lib/mock-helper tests/test_fpc_manager_installmetadata.lpr
```

Expected: compile succeeds with the shared helper unit.

### Task 3: Refactor TFPCValidator Verify Flow

**Files:**
- Modify: `src/fpdev.fpc.validator.pas`
- Reuse: `src/fpdev.fpc.verify.pas`

**Step 1: Shrink validator responsibilities**

- Keep install path and executable path resolution in `TFPCValidator`.
- Add a small private helper to initialize `TVerificationResult`.
- Add a small private helper to delegate executable verification to `fpdev.fpc.verify.TFPCVerifier`.

**Step 2: Remove duplicate runtime verification logic**

- Remove validator-local `RunSmokeTest`.
- Remove validator-local direct `fpc -iV` parsing path.
- Map verifier failures back into shared `TVerificationResult`.

**Step 3: Re-run boundary test**

Run:

```bash
python3 -m unittest tests.test_fpc_verify_boundary -v
```

Expected: PASS

### Task 4: Focused Regression And Planning Sync

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Run focused Pascal suites**

Run:

```bash
mkdir -p /tmp/fpdev-test-bin/fpc-verify-wave /tmp/fpdev-test-lib/fpc-verify-wave
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-verify-wave -FU/tmp/fpdev-test-lib/fpc-verify-wave tests/test_fpc_manager_installmetadata.lpr
/tmp/fpdev-test-bin/fpc-verify-wave/test_fpc_manager_installmetadata
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-verify-wave -FU/tmp/fpdev-test-lib/fpc-verify-wave tests/test_fpc_verify.lpr
/tmp/fpdev-test-bin/fpc-verify-wave/test_fpc_verify
fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-verify-wave -FU/tmp/fpdev-test-lib/fpc-verify-wave tests/test_cli_fpc_diag.lpr
/tmp/fpdev-test-bin/fpc-verify-wave/test_cli_fpc_diag
```

Expected: all pass.

**Step 2: Run repository-standard regression**

Run:

```bash
bash scripts/run_all_tests.sh
```

Expected: `275 passed, 0 failed, 0 skipped` or updated all-green total.

**Step 3: Update planning files**

- Record the new verify-boundary contract.
- Record the shared mock helper extraction.
- Record the validator/verifier responsibility split and verification evidence.
