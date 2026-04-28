# CLI Commandflow Wave Pack Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 收口 5 个高 ROI CLI 命令单元，把厚重的 `Execute(...)` 逻辑下沉到独立 commandflow helper，同时补齐边界契约与 focused/full verification，直到形成可收口的完整证据链。

**Architecture:** 沿用已经完成的 `fpc install commandflow` 模式：命令单元只保留 registration、manager ownership、settings 持久化与最终 helper 调用；新的 helper 单元承接 help/usage、参数解析、runtime orchestration 与 exit-code 映射。每一波都先写 boundary/direct tests，再做最小实现，最后跑 focused 验证后进入下一波。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 规划并执行 `lazarus install` commandflow wave

**Files:**
- Modify: `src/fpdev.cmd.lazarus.install.pas`
- Create: `src/fpdev.lazarus.installcommandflow.pas`
- Modify: `tests/test_lazarus_install_boundary.py`
- Create: `tests/test_lazarus_installcommandflow.lpr`
- Reuse: `tests/test_cli_lazarus.lpr`
- Reuse: `tests/test_lazarus_flow.lpr`

**Step 1: Write the failing test**

- 在 `tests/test_lazarus_install_boundary.py` 锁定命令单元必须引入 `fpdev.lazarus.installcommandflow`
- 断言 `TLazInstallCommand.Execute(...)` 委托新 helper，不再内联 `--from` / `--fpc` / `--jobs` / `--no-configure` 解析与 usage/help 输出
- 新增 `tests/test_lazarus_installcommandflow.lpr`，直接覆盖 help、invalid args、jobs settings update、start banner、source/binary mode dispatch、`--no-configure` wiring

**Step 2: Run test to verify it fails**

Run:
- `python3 -m unittest tests.test_lazarus_install_boundary -v`
- `mkdir -p /tmp/fpdev-laz-installcommandflow-bin-red /tmp/fpdev-laz-installcommandflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-laz-installcommandflow-bin-red -FU/tmp/fpdev-laz-installcommandflow-lib-red tests/test_lazarus_installcommandflow.lpr`

Expected: FAIL because the new helper and delegate wiring do not exist yet.

**Step 3: Write minimal implementation**

- 新增 `src/fpdev.lazarus.installcommandflow.pas`
- helper 负责 parse/install-plan/runtime dispatch
- `src/fpdev.cmd.lazarus.install.pas` 收缩为 thin command facade

**Step 4: Run focused verification**

Run:
- `python3 -m unittest tests.test_lazarus_install_boundary -v`
- `mkdir -p /tmp/fpdev-laz-installcommandflow-bin /tmp/fpdev-laz-installcommandflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-laz-installcommandflow-bin -FU/tmp/fpdev-laz-installcommandflow-lib tests/test_lazarus_installcommandflow.lpr`
- `/tmp/fpdev-laz-installcommandflow-bin/test_lazarus_installcommandflow`
- `mkdir -p /tmp/fpdev-cli-lazarus-bin /tmp/fpdev-cli-lazarus-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-lazarus-bin -FU/tmp/fpdev-cli-lazarus-lib tests/test_cli_lazarus.lpr`
- `/tmp/fpdev-cli-lazarus-bin/test_cli_lazarus`
- `mkdir -p /tmp/fpdev-lazarus-flow-bin /tmp/fpdev-lazarus-flow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr`
- `/tmp/fpdev-lazarus-flow-bin/test_lazarus_flow`

Expected: PASS

### Task 2: 规划并执行 `package install` commandflow wave

**Files:**
- Modify: `src/fpdev.cmd.package.install.pas`
- Create: `src/fpdev.package.installcommandflow.pas`
- Create: `tests/test_package_install_boundary.py`
- Create: `tests/test_package_installcommandflow.lpr`
- Reuse: `tests/test_cli_package.lpr`
- Reuse: `tests/test_package_resource_flow.lpr`

**Step 1: Write the failing test**

- 新增 boundary test，锁定 `TPackageInstallCommand.Execute(...)` 必须委托 helper
- direct helper test 覆盖 help/usage、unknown option、package/version positional parse、`--keep-build-artifacts`、`--no-deps`、`--dry-run`、available package precheck 与 exit-code mapping

**Step 2: Run test to verify it fails**

Run:
- `python3 -m unittest tests.test_package_install_boundary -v`
- `mkdir -p /tmp/fpdev-package-installcommandflow-bin-red /tmp/fpdev-package-installcommandflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-installcommandflow-bin-red -FU/tmp/fpdev-package-installcommandflow-lib-red tests/test_package_installcommandflow.lpr`

Expected: FAIL because the helper and delegate wiring do not exist yet.

**Step 3: Write minimal implementation**

- 新增 package install commandflow helper
- command 单元只保留 manager ownership 与 helper 调用

**Step 4: Run focused verification**

Run:
- `python3 -m unittest tests.test_package_install_boundary -v`
- `mkdir -p /tmp/fpdev-package-installcommandflow-bin /tmp/fpdev-package-installcommandflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-installcommandflow-bin -FU/tmp/fpdev-package-installcommandflow-lib tests/test_package_installcommandflow.lpr`
- `/tmp/fpdev-package-installcommandflow-bin/test_package_installcommandflow`
- `mkdir -p /tmp/fpdev-cli-package-bin /tmp/fpdev-cli-package-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-package-bin -FU/tmp/fpdev-cli-package-lib tests/test_cli_package.lpr`
- `/tmp/fpdev-cli-package-bin/test_cli_package`
- `mkdir -p /tmp/fpdev-package-resource-bin /tmp/fpdev-package-resource-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-resource-bin -FU/tmp/fpdev-package-resource-lib tests/test_package_resource_flow.lpr`
- `/tmp/fpdev-package-resource-bin/test_package_resource_flow`

Expected: PASS

### Task 3: 规划并执行 `fpc use` commandflow wave

**Files:**
- Modify: `src/fpdev.cmd.fpc.use.pas`
- Create: `src/fpdev.fpc.usecommandflow.pas`
- Create: `tests/test_fpc_use_boundary.py`
- Create: `tests/test_fpc_usecommandflow.lpr`
- Reuse: `tests/test_cli_fpc_info.lpr`

**Step 1: Write the failing test**

- 锁定 `TFPCUseCommand.Execute(...)` 必须委托 helper
- direct helper test 覆盖 help/usage、project/global default resolve、alias resolve、`--ensure`、not-installed prompt path、auto-install path、activation success/failure report

**Step 2: Run test to verify it fails**

Run:
- `python3 -m unittest tests.test_fpc_use_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-usecommandflow-bin-red /tmp/fpdev-fpc-usecommandflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-usecommandflow-bin-red -FU/tmp/fpdev-fpc-usecommandflow-lib-red tests/test_fpc_usecommandflow.lpr`

Expected: FAIL because the helper and delegate wiring do not exist yet.

**Step 3: Write minimal implementation**

- helper 承接 config resolve / ensure logic / activation output
- command 单元保留 manager creation、resolver injection、registration

**Step 4: Run focused verification**

Run:
- `python3 -m unittest tests.test_fpc_use_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-usecommandflow-bin /tmp/fpdev-fpc-usecommandflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-usecommandflow-bin -FU/tmp/fpdev-fpc-usecommandflow-lib tests/test_fpc_usecommandflow.lpr`
- `/tmp/fpdev-fpc-usecommandflow-bin/test_fpc_usecommandflow`
- `mkdir -p /tmp/fpdev-cli-fpc-info-bin /tmp/fpdev-cli-fpc-info-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-fpc-info-bin -FU/tmp/fpdev-cli-fpc-info-lib tests/test_cli_fpc_info.lpr`
- `/tmp/fpdev-cli-fpc-info-bin/test_cli_fpc_info`

Expected: PASS

### Task 4: 规划并执行 `fpc verify` commandflow wave

**Files:**
- Modify: `src/fpdev.cmd.fpc.verify.pas`
- Create: `src/fpdev.fpc.verifycommandflow.pas`
- Modify: `tests/test_fpc_verify_boundary.py`
- Create: `tests/test_fpc_verifycommandflow.lpr`
- Reuse: `tests/test_fpc_verify.lpr`
- Reuse: `tests/test_cli_fpc_diag.lpr`

**Step 1: Write the failing test**

- 扩展 boundary 契约，锁定 `TFPCVerifyCommand.Execute(...)` 必须委托新 helper
- direct helper test 覆盖 help/usage、single positional version、step-by-step report、metadata result wording 与 exit-code mapping

**Step 2: Run test to verify it fails**

Run:
- `python3 -m unittest tests.test_fpc_verify_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-verifycommandflow-bin-red /tmp/fpdev-fpc-verifycommandflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-verifycommandflow-bin-red -FU/tmp/fpdev-fpc-verifycommandflow-lib-red tests/test_fpc_verifycommandflow.lpr`

Expected: FAIL because the new helper and delegate wiring do not exist yet.

**Step 3: Write minimal implementation**

- 新增 `fpdev.fpc.verifycommandflow`
- command 单元只保留 manager ownership 与 helper 调用

**Step 4: Run focused verification**

Run:
- `python3 -m unittest tests.test_fpc_verify_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-verifycommandflow-bin /tmp/fpdev-fpc-verifycommandflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-verifycommandflow-bin -FU/tmp/fpdev-fpc-verifycommandflow-lib tests/test_fpc_verifycommandflow.lpr`
- `/tmp/fpdev-fpc-verifycommandflow-bin/test_fpc_verifycommandflow`
- `mkdir -p /tmp/fpdev-fpc-verify-bin /tmp/fpdev-fpc-verify-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-verify-bin -FU/tmp/fpdev-fpc-verify-lib tests/test_fpc_verify.lpr`
- `/tmp/fpdev-fpc-verify-bin/test_fpc_verify`
- `mkdir -p /tmp/fpdev-cli-fpc-diag-bin /tmp/fpdev-cli-fpc-diag-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-fpc-diag-bin -FU/tmp/fpdev-cli-fpc-diag-lib tests/test_cli_fpc_diag.lpr`
- `/tmp/fpdev-cli-fpc-diag-bin/test_cli_fpc_diag`

Expected: PASS

### Task 5: 规划并执行 `cross build` commandflow wave

**Files:**
- Modify: `src/fpdev.cmd.cross.build.pas`
- Create: `src/fpdev.cross.buildcommandflow.pas`
- Create: `tests/test_cross_build_boundary.py`
- Create: `tests/test_cross_buildcommandflow.lpr`
- Reuse: `tests/test_cli_cross.lpr`
- Reuse: `tests/test_cmd_cross_build.lpr`

**Step 1: Write the failing test**

- 锁定 `TCrossBuildCommand.Execute(...)` 必须委托 helper
- direct helper test 覆盖 help/usage、target parse、`--dry-run` / `--source` / `--sandbox` / `--version`、source-tree preflight、dry-run report、engine success/failure 与 exit-code mapping

**Step 2: Run test to verify it fails**

Run:
- `python3 -m unittest tests.test_cross_build_boundary -v`
- `mkdir -p /tmp/fpdev-cross-buildcommandflow-bin-red /tmp/fpdev-cross-buildcommandflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-buildcommandflow-bin-red -FU/tmp/fpdev-cross-buildcommandflow-lib-red tests/test_cross_buildcommandflow.lpr`

Expected: FAIL because the new helper and delegate wiring do not exist yet.

**Step 3: Write minimal implementation**

- helper 承接 target parse、options、dry-run report、preflight 与 engine result mapping
- command 单元保留 build-manager/engine ownership 与 registration

**Step 4: Run focused verification**

Run:
- `python3 -m unittest tests.test_cross_build_boundary -v`
- `mkdir -p /tmp/fpdev-cross-buildcommandflow-bin /tmp/fpdev-cross-buildcommandflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-buildcommandflow-bin -FU/tmp/fpdev-cross-buildcommandflow-lib tests/test_cross_buildcommandflow.lpr`
- `/tmp/fpdev-cross-buildcommandflow-bin/test_cross_buildcommandflow`
- `mkdir -p /tmp/fpdev-cli-cross-bin /tmp/fpdev-cli-cross-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-cross-bin -FU/tmp/fpdev-cli-cross-lib tests/test_cli_cross.lpr`
- `/tmp/fpdev-cli-cross-bin/test_cli_cross`
- `mkdir -p /tmp/fpdev-cmd-cross-build-bin /tmp/fpdev-cmd-cross-build-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cmd-cross-build-bin -FU/tmp/fpdev-cmd-cross-build-lib tests/test_cmd_cross_build.lpr`
- `/tmp/fpdev-cmd-cross-build-bin/test_cmd_cross_build`

Expected: PASS

### Task 6: Broad Verification + Planning Sync

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Run full verification**

Run:
- `python3 -m unittest discover -s tests -p 'test_*.py'`
- `bash scripts/run_all_tests.sh`

Expected: PASS

**Step 2: Update records**

- 同步 `task_plan.md`
- 同步 `findings.md`
- 同步 `progress.md`
- 记录本轮 5-wave pack 的 focused/full verification 证据与残留风险
