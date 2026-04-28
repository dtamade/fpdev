# FPC Manager Verify Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.fpc.manager.pas`，把 `VerifyInstallation(...)` 剩余的 manager-level surface glue 完整收进 `verifyflow`，保持验证行为与 metadata 回写语义不变。

**Architecture:** 不重开 verifier/validator 低层实现，只在已有 `src/fpdev.fpc.verifyflow.pas` 上补一个 manager-facing surface helper。`src/fpdev.fpc.manager.pas` 保留 facade 入口与 `FValidatorMgr` 持有；新的 shared helper 负责“执行验证 + 解析 install path + 持久化 metadata”这段组合编排。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 verify surface 最小切口

**Files:**
- Inspect: `src/fpdev.fpc.manager.pas`
- Inspect: `src/fpdev.fpc.verifyflow.pas`
- Reuse: `tests/test_fpc_manager_verify_boundary.py`
- Reuse: `tests/test_fpc_verify.lpr`

**Step 1: 锁定必须下沉的职责**

- `TFPCManager.VerifyInstallation(...)` 不再直接拼 `PersistManagedFPCVerificationResultCore(...)`
- manager 继续只负责持有 `FValidatorMgr` 与 metadata writer callback
- 既有 `RunInstalledFPCVerificationCore(...)` / `PersistManagedFPCVerificationResultCore(...)` 保持可复用，不回退到 manager

**Step 2: 锁定不改的边界**

- 不改 `TFPCValidator` 的公共行为
- 不改 metadata 文件位置解析语义
- 不改 CLI 文案与验证结果结构

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_fpc_manager_verify_boundary.py`
- Modify: `tests/test_fpc_verify.lpr`

**Step 1: 扩展 boundary 契约**

- 断言 `src/fpdev.fpc.manager.pas` 的 `VerifyInstallation(...)` 调用新的 shared surface helper
- 断言 manager 不再直接出现 `PersistManagedFPCVerificationResultCore(` 这段 surface 组合

**Step 2: 为 verifyflow 写 direct RED**

- 在 `tests/test_fpc_verify.lpr` 增加针对新 surface helper 的 probe/callback 覆盖
- 覆盖成功路径：验证完成后回写 metadata
- 覆盖失败路径：验证失败时仍保持既有回写/不回写语义

**Step 3: Run test to verify it fails**

Run:
```bash
python3 -m unittest tests.test_fpc_manager_verify_boundary -v
mkdir -p /tmp/fpdev-fpc-verify-bin-red /tmp/fpdev-fpc-verify-lib-red
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-verify-bin-red -FU/tmp/fpdev-fpc-verify-lib-red tests/test_fpc_verify.lpr
/tmp/fpdev-fpc-verify-bin-red/test_fpc_verify
```

Expected: FAIL，因为新的 manager-facing verify surface helper 还不存在。

### Task 3: 实现 verifyflow surface helper 并回接 manager

**Files:**
- Modify: `src/fpdev.fpc.verifyflow.pas`
- Modify: `src/fpdev.fpc.manager.pas`

**Step 1: 在 verifyflow 中补最小 helper API**

- 新增一个 manager-facing helper，负责：
  - 调用 manager/validator 提供的验证 callback
  - 解析 install path
  - 统一调用 metadata persistence helper

**Step 2: 收缩 manager**

- `TFPCManager.VerifyInstallation(...)` 改为 thin delegate
- manager 继续只传 `@FValidatorMgr.VerifyInstallation` 等必要 callback / state

### Task 4: Focused Verification

**Files:**
- Reuse: `tests/test_fpc_manager_installmetadata.lpr`
- Reuse: `tests/test_cli_fpc_diag.lpr`

**Step 1: Run focused suites**

Run:
```bash
python3 -m unittest tests.test_fpc_manager_verify_boundary tests.test_fpc_verify_boundary -v
mkdir -p /tmp/fpdev-fpc-verify-bin /tmp/fpdev-fpc-verify-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-verify-bin -FU/tmp/fpdev-fpc-verify-lib tests/test_fpc_verify.lpr
/tmp/fpdev-fpc-verify-bin/test_fpc_verify
mkdir -p /tmp/fpdev-fpc-installmetadata-bin /tmp/fpdev-fpc-installmetadata-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installmetadata-bin -FU/tmp/fpdev-fpc-installmetadata-lib tests/test_fpc_manager_installmetadata.lpr
/tmp/fpdev-fpc-installmetadata-bin/test_fpc_manager_installmetadata
```

Expected: PASS
