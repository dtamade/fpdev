# FPC Install Output And Boundary Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一 FPC install 栈在 binary/source/cache-hit/offline/no-cache 场景下的用户输出，并补上 manager/installer 边界守卫与文档同步，防止调度逻辑回流到上层。

**Architecture:** 保持现有分层不回退：CLI 只处理参数、mode fallback、network guard、exit code；manager 只做 wiring 和 install-success 后的 verify metadata refresh；installer / installversionflow 各自承接 binary/source 安装流与 offline/cache 契约。输出统一优先采用小型共享 helper，不做过度抽象，先把重复文案、warning 和 next-step 文案收口到单点。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, fpdev install/metadata flow

---

### Task 1: Lock manager and installer boundaries

**Files:**
- Create: `tests/test_fpc_install_manager_boundary.py`
- Create: `tests/test_fpc_installer_boundary.py`
- Reference: `src/fpdev.fpc.manager.pas`
- Reference: `src/fpdev.fpc.installer.pas`
- Reference: `src/fpdev.cmd.fpc.install.pas`

**Step 1: Write the failing tests**

```python
def test_manager_install_does_not_own_cli_fallback_or_exit_code_logic():
    ...

def test_installer_does_not_own_cli_fallback_or_exit_code_logic():
    ...
```

**Step 2: Run tests to verify they fail**

Run: `python3 -m unittest tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary -v`

Expected: FAIL because the new guard files do not exist yet.

**Step 3: Write minimal boundary assertions**

- `manager` 不应重新出现 `Attempting binary installation first`
- `manager` 不应重新出现 `Both binary and source installation failed`
- `manager` 不应重新做 `EXIT_` 决策
- `installer` 不应出现 CLI fallback 文案或 `EXIT_` 决策
- `installer` 不应直接实现 source-install orchestration

**Step 4: Run tests to verify they pass**

Run: `python3 -m unittest tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary -v`

Expected: PASS

### Task 2: Lock output contract with RED tests

**Files:**
- Modify: `tests/test_fpc_install_cli.lpr`
- Modify: `tests/test_fpc_installversionflow.lpr`
- Reference: `src/fpdev.fpc.installer.postinstall.pas`
- Reference: `src/fpdev.fpc.installversionflow.pas`
- Reference: `src/fpdev.fpc.installer.pas`

**Step 1: Write failing tests for shared output expectations**

- offline binary cache-miss / restore-fail 输出要包含统一 fail + hint
- source cache-hit / source build 完成后要包含统一 success banner / next-step
- `--no-cache --offline` 组合要明确以 offline 契约为准
- explicit mode 下失败文案不应漂移

**Step 2: Run focused tests to verify RED**

Run: `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_install_cli.lpr`

Run: `/tmp/fpdev-plan-bin/test_fpc_install_cli`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installversionflow.lpr`

Run: `/tmp/fpdev-plan-bin/test_fpc_installversionflow`

Expected: 新增断言先失败，且失败原因对应输出契约缺口。

**Step 3: Capture minimal target wording**

- cache restore success
- cache restore failure in offline mode
- cache miss in offline mode
- install completed / activation next-step
- warning 不改成功退出码

### Task 3: Implement minimal output unification

**Files:**
- Modify: `src/fpdev.fpc.installer.postinstall.pas`
- Modify: `src/fpdev.fpc.installversionflow.pas`
- Modify: `src/fpdev.fpc.installer.pas`
- Optional Create: `src/fpdev.fpc.installreportflow.pas`

**Step 1: Add the smallest shared helper needed**

- 优先把 fail/hint/success banner 文案收口到现有文件或一个小 helper
- 不把 source/binary orchestration 搬回 manager/CLI

**Step 2: Update source flow**

- source cache-hit 后输出统一 success/activation 信息
- source build 成功后输出统一 success/activation 信息
- 保持 metadata / setup / cache save 时序不变

**Step 3: Update binary flow**

- binary cache-hit / normal install 复用同一成功输出
- offline miss / restore-fail 复用同一 fail/hint 文案
- 不引入新的 exit-code 或 fallback 逻辑

**Step 4: Re-run focused tests**

Run: `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_install_cli.lpr && /tmp/fpdev-plan-bin/test_fpc_install_cli`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installversionflow.lpr && /tmp/fpdev-plan-bin/test_fpc_installversionflow`

Expected: PASS

### Task 4: Sync docs with the new layering

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/FPC_MANAGEMENT.md`
- Modify: `docs/FPC_MANAGEMENT.en.md`
- Optional Modify: `README.md`

**Step 1: Remove stale ownership descriptions**

- 不再写 `fpdev.cmd.fpc.install` 负责 cache restore orchestration
- 不再展示过时的 `TFPCManager.InstallVersion('3.2.2', True)` 示例签名

**Step 2: Update examples**

- 文档示例改成当前 install mode / offline/no-cache 语义
- 如有 API 示例，补齐当前签名或简化为 CLI 示例

**Step 3: Run doc contract tests if impacted**

Run: `python3 -m unittest tests.test_contributor_docs_contract -v`

Expected: PASS

### Task 5: Verify and update planning records

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Run targeted regression batch**

Run: `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary tests.test_style_regressions_batch16 -v`

Expected: PASS

**Step 2: Run focused Pascal suite**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_install_cli.lpr && /tmp/fpdev-plan-bin/test_fpc_install_cli`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_installversionflow.lpr && /tmp/fpdev-plan-bin/test_fpc_installversionflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-plan-bin -FU/tmp/fpdev-plan-lib tests/test_fpc_manager_installmetadata.lpr && /tmp/fpdev-plan-bin/test_fpc_manager_installmetadata`

**Step 3: Run full regression**

Run: `bash scripts/run_all_tests.sh`

Expected: PASS

**Step 4: Update records**

- 在 `task_plan.md` 追加本轮 phase 和 notes
- 在 `progress.md` 记录测试结果与文件变化
- 在 `findings.md` 记录输出统一与 boundary 收紧的设计结论
