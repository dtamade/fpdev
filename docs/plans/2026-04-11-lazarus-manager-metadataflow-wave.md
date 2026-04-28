# Lazarus Manager Metadataflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.lazarus.manager.pas`，把 metadata/version inventory 责任抽到独立 helper 单元，锁住 manager 的委托边界，并同步开发者文档中的 Lazarus hotspot 事实。

**Architecture:** 保持现有 Lazarus 分层不回退。`fpdev.lazarus.commandflow` 继续负责 install/update/launch/configure plan core；`fpdev.lazarus.manager` 保留 config access、外层异常包装与 plan wiring；新增 metadataflow 只承接 version info normalize、configured metadata overlay、installed version merge/filter，不重新吸回 install/update 用户输出。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Markdown docs

---

### Task 1: Record the new wave in planning files

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Set the active goal**

- 记录本轮目标为 Lazarus manager metadata/version inventory 抽离
- 明确 install contract wave 已完成，不重复做 install output cleanup

**Step 2: Record the root-cause judgment**

- 写清当前 CLI/root shell 已不是主要调度问题中心
- 写清真正热点是 `src/fpdev.lazarus.manager.pas`

### Task 2: Add RED tests for metadataflow extraction

**Files:**
- Create: `tests/test_lazarus_manager_metadata_boundary.py`
- Create: `tests/test_lazarus_manager_metadataflow.lpr`
- Reference: `tests/test_lazarus_configure_workflow.lpr`

**Step 1: Add boundary assertions**

- `src/fpdev.lazarus.manager.pas` 必须引入 `fpdev.lazarus.metadataflow`
- manager 必须调用新的 helper，而不是继续本地归一化 configured FPC version
- manager 不得继续在本地拼重复的 configured installed version merge 逻辑

**Step 2: Add direct helper coverage**

- `NormalizeConfiguredLazarusFPCVersionCore(...)`：
  - 去掉 `fpc-` 前缀
  - configured 为空时回退 recommended
  - recommended 为空时回退 `DEFAULT_FPC_VERSION`
- configured metadata overlay helper：
  - installed registry version 应优先使用 configured FPC version / branch
- installed version merge/filter helper：
  - registry 缺失但 config 中 installed 的版本必须被补回结果集中

**Step 3: Run tests to verify RED**

Run: `python3 -m unittest tests.test_lazarus_manager_metadata_boundary -v`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-metadata-bin-red -FU/tmp/fpdev-lazarus-metadata-lib-red tests/test_lazarus_manager_metadataflow.lpr`

Run: `/tmp/fpdev-lazarus-metadata-bin-red/test_lazarus_manager_metadataflow`

Expected: FAIL because the metadataflow unit/helpers do not exist yet.

### Task 3: Implement the minimal metadataflow slice

**Files:**
- Create: `src/fpdev.lazarus.types.pas`
- Create: `src/fpdev.lazarus.metadataflow.pas`
- Modify: `src/fpdev.lazarus.manager.pas`
- Modify: `src/fpdev.cmd.lazarus.pas`

**Step 1: Move the shared version-info types**

- 新建 `src/fpdev.lazarus.types.pas`
- 承接 `TLazarusVersionInfo` / `TLazarusVersionArray`
- 让 manager 与 compat shim 复用新 types unit

**Step 2: Add metadataflow helpers**

- 新 helper 只处理纯装配逻辑：
  - configured FPC version normalize
  - configured metadata overlay
  - installed version merge/filter
- 不把 config I/O、file existence checks、output 写回 metadataflow

**Step 3: Rewire manager**

- `TryGetConfiguredVersionInfo`
- `GetAvailableVersions`
- `GetInstalledVersions`
- `ShowVersionInfo`

最小化改为委托 metadataflow helper，不改现有用户可见行为。

### Task 4: Sync developer docs and contracts

**Files:**
- Modify: `docs/history/B171-large-files-report.md`
- Modify: `tests/test_contributor_docs_contract.py`
- Optional Modify: `CLAUDE.md`

**Step 1: Update the hotspot truth**

- 把 Lazarus manager 的当前行数与角色说明同步到最新状态
- 若需要，补 `fpdev.lazarus.metadataflow.pas` 为新切片落点

**Step 2: Re-run docs contract**

Run: `python3 -m unittest tests.test_contributor_docs_contract -v`

Expected: PASS

### Task 5: Focused and full verification

**Files:**
- Verify only

**Step 1: Run focused Python suites**

Run: `python3 -m unittest tests.test_lazarus_manager_metadata_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract tests.test_contributor_docs_contract -v`

Expected: PASS

**Step 2: Run focused Pascal suites**

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-metadata-bin -FU/tmp/fpdev-lazarus-metadata-lib tests/test_lazarus_manager_metadataflow.lpr && /tmp/fpdev-lazarus-metadata-bin/test_lazarus_manager_metadataflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-configure-bin -FU/tmp/fpdev-lazarus-configure-lib tests/test_lazarus_configure_workflow.lpr && /tmp/fpdev-lazarus-configure-bin/test_lazarus_configure_workflow`

Run: `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-lazarus-cli-bin -FU/tmp/fpdev-lazarus-cli-lib tests/test_cli_lazarus.lpr && /tmp/fpdev-lazarus-cli-bin/test_cli_lazarus`

Expected: PASS

**Step 3: Run repository regression**

Run: `bash scripts/run_all_tests.sh`

Expected: PASS

**Step 4: Final planning record update**

- 在 `task_plan.md` 把 Phase 37 标成 complete
- 在 `findings.md` 记录 metadataflow extraction 结论
- 在 `progress.md` 记录 RED/GREEN 证据和 focused/full 回归结果
