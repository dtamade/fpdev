# FPC Install Commandflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.cmd.fpc.install.pas`，把 `TFPCInstallCommand.Execute(...)` 中仍然内联的参数解析、usage/help、network guard、auto fallback 与 exit-code 映射下沉到独立 commandflow helper，同时保持命令单元只负责 command registration、manager ownership 与最终调用接线。

**Architecture:** 新增 `src/fpdev.fpc.installcommandflow.pas`，承接两层职责：一层负责把 CLI 参数解析成 install plan（含 help/usage、mode/prefix/jobs/offline/no-cache），另一层负责基于 plan 执行 install command runtime（start banner、network guard、auto binary->source fallback、exit-code mapping）。`src/fpdev.cmd.fpc.install.pas` 继续保留 `TFPCManager` 创建/释放与命令注册，不重新吸回 install/runtime 内核。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 commandflow 边界并写 RED

**Files:**
- Modify: `tests/test_fpc_install_cli_boundary.py`
- Create: `tests/test_fpc_installcommandflow.lpr`
- Reuse: `tests/test_fpc_install_cli.lpr`

**Step 1: 扩展 boundary 契约**

- 断言 `src/fpdev.cmd.fpc.install.pas` 引入 `fpdev.fpc.installcommandflow`
- 断言 command `Execute(...)` 调用：
  - `PrepareFPCInstallCommandPlanCore(...)`
  - `ExecuteFPCInstallCommandPlanCore(...)`
- 断言 command 不再内联：
  - `TryStringToInstallMode(...)`
  - `FindUnknownOption(...)`
  - `Attempting binary installation first...`
  - `Binary installation failed, falling back to source installation...`
  - `Both binary and source installation failed`

**Step 2: direct helper RED**

- `PrepareFPCInstallCommandPlanCore(...)`
  - `--help` 返回 `EXIT_OK` 且输出 usage
  - `--jobs=<n>` 更新 settings
  - `--from=invalid` 返回 usage error
  - `--prefix=` 返回 usage error
- `ExecuteFPCInstallCommandPlanCore(...)`
  - auto 模式：binary fail 后 source success，返回 `EXIT_OK`
  - network disabled + 非 offline：返回 `EXIT_IO_ERROR`，且不调用 install callback
  - offline fail：返回 `EXIT_IO_ERROR`
  - source mode success：只调用一次 source install

**Step 3: Run RED**

Run:
- `python3 -m unittest tests.test_fpc_install_cli_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-installcommandflow-bin-red /tmp/fpdev-fpc-installcommandflow-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installcommandflow-bin-red -FU/tmp/fpdev-fpc-installcommandflow-lib-red tests/test_fpc_installcommandflow.lpr`

Expected: FAIL because the new commandflow helper and delegate wiring do not exist yet.

### Task 2: 实现 install commandflow helper

**Files:**
- Create: `src/fpdev.fpc.installcommandflow.pas`

**Step 1: 最小 helper API**

- `TFPCInstallCommandPlan`
- `TFPCInstallCommandInstallFunc`
- `PrepareFPCInstallCommandPlanCore(...)`
- `ExecuteFPCInstallCommandPlanCore(...)`

**Step 2: 保持边界紧凑**

- helper 只负责 CLI parse/runtime orchestration
- 不直接创建 `TFPCManager`
- 不重复实现 install manager / install flow 内核
- settings 变更继续通过 command 层持久化

### Task 3: 回接 command facade

**Files:**
- Modify: `src/fpdev.cmd.fpc.install.pas`

**Step 1: thin command**

- `Execute(...)` 只保留：
  - 读取/写回 settings
  - 创建 `TFPCManager`
  - 调用 commandflow helper
  - command registration

**Step 2: 保持行为契约**

- 不改变 `tests/test_fpc_install_cli.lpr` 已锁定的 stdout/stderr/exit code
- 不改变 offline cache-first 语义
- 不改变 auto 模式 binary->source fallback 语义

### Task 4: Focused Verification

Run:
- `python3 -m unittest tests.test_fpc_install_cli_boundary -v`
- `mkdir -p /tmp/fpdev-fpc-installcommandflow-bin /tmp/fpdev-fpc-installcommandflow-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installcommandflow-bin -FU/tmp/fpdev-fpc-installcommandflow-lib tests/test_fpc_installcommandflow.lpr`
- `/tmp/fpdev-fpc-installcommandflow-bin/test_fpc_installcommandflow`
- `mkdir -p /tmp/fpdev-fpc-install-cli-bin /tmp/fpdev-fpc-install-cli-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-install-cli-bin -FU/tmp/fpdev-fpc-install-cli-lib tests/test_fpc_install_cli.lpr`
- `/tmp/fpdev-fpc-install-cli-bin/test_fpc_install_cli`

Expected: PASS

### Task 5: Broad Verification + Planning Sync

Run:
- `python3 -m unittest discover -s tests -p 'test_*.py'`
- `bash scripts/run_all_tests.sh`

Then update:
- `task_plan.md`
- `findings.md`
- `progress.md`
