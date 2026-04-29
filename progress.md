# Progress Log

## Session: 2026-04-29 (task tree drain and BuildManager backlog closure)

### Phase 118: Task Tree Drain And BuildManager Backlog Closure
- **Status:** complete
- **Started:** 2026-04-29
- Actions taken:
  - 确认最新提交 `ed349de` 后工作区干净
  - 盘点根 `task_plan.md`、`progress.md`、`findings.md` 与 `todos/*.md`
  - 确认活跃未清项集中在 BuildManager backlog 和历史 stale `in_progress` 记录
  - 创建正式计划 `docs/plans/2026-04-29-task-tree-drain-buildmanager.md`
  - 扩展 RED/focused tests：
    - `tests/test_build_logger.lpr`
    - `tests/test_build_testresultsflow.lpr`
    - `tests/fpdev.build.manager/test_build_manager_make_missing.lpr`
    - `tests/test_build_fullbuildflow.lpr`
    - `tests/test_build_manager_docs_truth_contract.py`
  - RED 结果：
    - docs contract 因 unchecked BuildManager backlog 失败
    - logger focused test 因缺少 `RotateLogs` 无法编译
    - testresults focused test 因缺少 `artifact-manifest.txt` 失败
    - strict focused test 因没有聚合报告所有 section 失败而失败
  - 最小实现：
    - `src/fpdev.build.logger.pas` 新增 `RotateLogs(...)`，默认保留最近 20 个 `build_*.log`
    - `src/fpdev.build.testresultsflow.pas` 在 sandbox success 后写 `artifact-manifest.txt`
    - `src/fpdev.build.strict.pas` 增加 robust bool parse，并聚合所有 configured section failures
    - 新增 `scripts/build_manager_self_hosted_ci.sh`
  - focused GREEN 已通过：
    - `tests/test_build_logger.lpr` → `13/13`
    - `tests/test_build_testresultsflow.lpr` → `34/34`
    - `tests/fpdev.build.manager/test_build_manager_make_missing.lpr` → pass
    - `tests/test_build_fullbuildflow.lpr` → `15/15`
    - `python3 -m unittest tests.test_build_manager_docs_truth_contract -v` → `6/6`
  - 顶层 `scripts/run_all_tests.sh` 首次 fresh 回归时仅 `test_build_manager_strict_fail` 失败
  - 根因定位：
    - 顶层 runner 在隔离 workspace 中执行测试，只链接 `tests/examples/docs/src/.git`
    - `test_build_manager_strict_fail.lpr` / `strict_pass.lpr` 使用相对路径 `plays/fpdev.build.manager.demo/build-manager.strict.ini`
    - 结果 strict config 未命中，`TestResults(...)` 退回到基础沙箱检查并错误返回 success
  - 最小修复：
    - `tests/fpdev.build.manager/test_build_manager_strict_fail.lpr`
    - `tests/fpdev.build.manager/test_build_manager_strict_pass.lpr`
    - 通过 `FPDEV_TEST_PROJECT_ROOT` 解析 demo strict ini 的绝对路径
    - 在 strict ini 缺失或解析失败时直接 `Halt(1)`，避免假阳性
- Verification completed:
  - `bash scripts/build_manager_self_hosted_ci.sh` → pass
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `642/642`
  - `bash scripts/run_all_tests.sh` → `335/335`
  - `lazbuild -B --build-mode=Release fpdev.lpi` → exit `0`
  - `git diff --check` → clean

## Session: 2026-04-29 (continuous repo closeout)

### Phase 117: Continuous Repo Closeout And Test Inventory Truth Sync
- **Status:** complete
- **Started:** 2026-04-29
- Actions taken:
  - 读取 `superpowers:writing-plans`、`planning-with-files`、`verification-before-completion`，按连续收口方式执行
  - 运行 planning catchup：无阻塞输出
  - 确认当前工作树仍然包含大量既有 modified/untracked/deleted 文件，本轮将限制 stage 范围
  - 创建实施计划：`docs/plans/2026-04-29-continuous-repo-closeout.md`
  - 将 `task_plan.md` active goal 切到 Phase 117
  - 复现 test inventory drift：
    - `python3 scripts/update_test_stats.py --check` → failed，列出 README / docs/testing / ROADMAP / MVP acceptance files
    - `python3 scripts/update_test_stats.py --count` → `335`
  - 执行 canonical sync：
    - `python3 scripts/update_test_stats.py --write`
    - `python3 scripts/update_test_stats.py --check` → pass
  - 初次 focused docs contract 失败：
    - `python3 -m unittest tests.test_update_test_stats tests.test_contributor_docs_contract tests.test_release_status_wording -v` → failed，2 个 README release status wording 断言仍硬编码 `275`
  - 修复 `tests/test_release_status_wording.py`：
    - README 断言动态读取 `scripts/update_test_stats.py` 的当前 discoverable count
    - release notes 断言继续保持发布时 `275` 快照
  - 重新验证 focused contracts：
    - `python3 -m unittest tests.test_release_status_wording -v` → `4/4`
    - `python3 -m unittest tests.test_update_test_stats tests.test_contributor_docs_contract -v` → `40/40`
    - `python3 -m unittest tests.test_update_test_stats tests.test_contributor_docs_contract tests.test_release_status_wording -v` → `44/44`
  - facade boundary bundle：
    - `python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v` → `36/36`
  - Python full verification:
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `641/641`
  - Pascal full verification before hint cleanup:
    - `bash scripts/run_all_tests.sh` → `335/335`
  - Release build verification:
    - `lazbuild -B --build-mode=Release fpdev.lpi` → exit `0`
    - Log scan exposed one project-code hint: `fpdev.fpc.installer.lifecycleflow.pas(60,9) Parameter "AVersion" not used`
    - First log scan command used zsh read-only variable `status`; reran with `rc` successfully
  - Hint cleanup:
    - Removed unused `AVersion` parameter from `ExecuteFPCInstallerUninstallCore(...)`
    - Updated `src/fpdev.fpc.installer.pas` and `tests/test_fpc_installer_lifecycleflow.lpr` call sites
    - `python3 -m unittest tests.test_fpc_installer_boundary -v` → `4/4`
    - `tests/test_fpc_installer_lifecycleflow.lpr` → `29/29`
    - `tests/test_fpc_installer.lpr` → `35/35`
    - `lazbuild -B --build-mode=Release fpdev.lpi` → exit `0`; project-code unused-parameter hint gone, remaining hint count is Lazarus/FPC environment output
  - Final full verification after hint cleanup:
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `641/641`
    - `bash scripts/run_all_tests.sh` → `335/335`
  - Pre-commit review conclusion:
    - No blocking issue found in this closeout scope
    - Full current worktree verification passed
    - Commit includes the currently verified integration state because the repository was already a large dirty worktree
- Planned verification:
  - `python3 scripts/update_test_stats.py --check`
  - `python3 -m unittest tests.test_update_test_stats tests.test_contributor_docs_contract tests.test_release_status_wording -v`
  - `python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v`
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
  - `bash scripts/run_all_tests.sh`
  - `lazbuild -B --build-mode=Release fpdev.lpi`

## Session: 2026-04-19 (fresh hotspot re-rank checkpoint after CLI wave pack)

### Phase 116: Fresh Hotspot Re-rank Checkpoint After CLI Wave Pack
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 在 `CLI commandflow wave pack` code + truth sync 都已收口后，没有直接 reopen 新 helper wave，而是先做 fresh ROI re-rank
  - 结合语义搜索与 line-count scan 复核当前剩余大体量单元，最新 top 体量大致为：
    - `src/fpdev.git.operations.impl.pas` → `3128`
    - `src/fpdev.i18n.strings.pas` → `1833`
    - `src/fpdev.git2.pas` → `1501`
    - `src/fpdev.fpc.source.pas` → `871`
    - `src/fpdev.fpc.manager.pas` → `839`
    - `src/fpdev.fpc.builder.pas` → `806`
    - `src/fpdev.build.manager.pas` → `800`
    - `src/fpdev.package.manager.pas` → `763`
    - `src/fpdev.resource.repo.pas` / `src/fpdev.lazarus.manager.pas` → `762`
  - 运行轻量 facade boundary bundle：
    - `python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v`
    - 结果：`36 passed`
  - 将 fresh evidence 与当前源码形态对照后，确认：
    - `build.manager` / `fpc.builder` / `package.manager` / `lazarus.manager` / `fpc.source` / `resource.repo` 这些旧高 ROI facade 面仍保持 helper 化边界，不 reopen
    - 当前更大的 `git` / `i18n` 文件主要是 core logic 或数据表，不符合“3-5 个方法成组、低爆炸半径”的 helper wave 条件
    - 因此这轮 checkpoint 的正确动作是停止继续机械拆 facade，而不是为了保持动作感硬开下一波
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 当前 repo 仍是大 dirty worktree；没有足够证据时继续开 helper wave 的风险高于收益
  - 下一步若继续推进，应改为新的业务/设计目标，或先形成更具体的新实施计划

## Session: 2026-04-19 (CLI commandflow wave pack fresh closure)

### Phase 98: CLI Commandflow Wave Pack Broad Verification + Closure
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 接管已完成但未完全落盘的 5-wave pack，逐项复核当前工作树里的 helper / boundary / direct tests / thin command facade 形态
  - `lazarus install` fresh focused verification 通过：
    - `python3 -m unittest tests.test_lazarus_install_boundary -v` → `5 passed`
    - `tests/test_lazarus_installcommandflow.lpr` → `33 passed`
    - `tests/test_cli_lazarus.lpr` → `143 passed`
    - `tests/test_lazarus_flow.lpr` → `37 passed`
    - 提交：`dee7105` `refactor(lazarus-install): extract commandflow helper`
  - `package install` fresh focused verification 通过：
    - `python3 -m unittest tests.test_package_install_boundary -v` → `2 passed`
    - `tests/test_package_installcommandflow.lpr` → `33 passed`
    - `tests/test_cli_package.lpr` → `234 passed`
    - `tests/test_package_resource_flow.lpr` → `23 passed`
    - 提交：`f6667fe` `refactor(package-install): extract commandflow helper`
  - `fpc use` fresh focused verification 通过：
    - `python3 -m unittest tests.test_fpc_use_boundary -v` → `2 passed`
    - `tests/test_fpc_usecommandflow.lpr` → `32 passed`
    - `tests/test_cli_fpc_info.lpr` → `91 passed`
    - 提交：`3657612` `refactor(fpc-use): extract commandflow helper`
  - `fpc verify` fresh focused verification 通过：
    - `python3 -m unittest tests.test_fpc_verify_boundary -v` → `4 passed`
    - `tests/test_fpc_verifycommandflow.lpr` → `18 passed`
    - `tests/test_fpc_verify.lpr` → pass
    - `tests/test_cli_fpc_diag.lpr` → `158 passed`
    - 提交：`774665d` `refactor(fpc-verify): extract commandflow helper`
  - `cross build` fresh focused verification 通过：
    - `python3 -m unittest tests.test_cross_build_boundary -v` → `2 passed`
    - `tests/test_cross_buildcommandflow.lpr` → `37 passed`
    - `tests/test_cli_cross.lpr` → `146 passed`
    - `tests/test_cmd_cross_build.lpr` → `25 passed`
    - 提交：`41e3576` `refactor(cross-build): extract commandflow helper`
  - broad verification 先发现一处真实 truth-contract drift：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` 初次失败
    - 根因是 `tests/test_build_manager_docs_truth_contract.py` 仍要求旧的 `todos/fpdev.git2.md` 聚合行 `日志分文件/轮转、verbosity 开关`
    - 当前 todo 真相已拆成三条子项：`日志分文件`、`verbosity 开关`、`日志轮转`
    - 以最小修正更新 contract 断言，不修改生产代码或 todo 内容
  - fresh broad verification 最终通过：
    - `python3 -m unittest tests.test_build_manager_docs_truth_contract.BuildManagerDocsTruthContractTests.test_git2_todo_marks_testresults_sandbox_structure_validation_complete -v` → `1 passed`
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `641 passed`
    - `bash scripts/run_all_tests.sh` → `335 passed`
    - `lazbuild -B --build-mode=Release fpdev.lpi` → pass
- Files created/modified:
  - `tests/test_build_manager_docs_truth_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 当前 5-wave pack 已以 fresh focused + broad evidence 完整收口
  - 下一步若继续推进，应先做新的 ROI/业务目标重排，而不是 reopen 已完成的 CLI helper 线
  - 工作树仍存在大量与本轮无关的未提交改动，本轮未回退也未混入这些无关改动

## Session: 2026-04-19 (TFPCInstaller lifecycleflow audit)

### Phase 114: TFPCInstaller Lifecycleflow Test Audit
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 读取 `using-superpowers` 与 `planning-with-files` 技能，按要求先建立本次调研的磁盘计划
  - 用代码搜索确认当前 `TFPCInstaller` 周边已有的边界护栏主要在：
    - `tests/test_fpc_installer_boundary.py`
    - `tests/test_fpc_install_manager_boundary.py`
    - `tests/test_fpc_installer.lpr`
  - 记录当前任务目标：不改业务文件，只输出最小 RED 测试建议，服务于后续抽取 `fpdev.fpc.installer.lifecycleflow`
  - 发现 `planning-with-files` 示例中的 `${CLAUDE_PLUGIN_ROOT}` 在当前会话未定义，已改为绝对路径继续
  - 进一步结构化检查 `src/fpdev.fpc.installer.pas`、`src/fpdev.fpc.installer.lifecycleflow.pas`、`tests/test_fpc_installer_boundary.py`、`tests/test_fpc_installer_lifecycleflow.lpr`、`tests/test_fpc_installer.lpr`
  - 确认当前工作树里 lifecycleflow 抽取已经存在，boundary tests 也已锁住 facade 委托
  - 运行 focused 验证：
    - `python3 -m unittest tests.test_fpc_installer_boundary -v` → `4 passed`
    - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installer-lifecycleflow-bin -FU/tmp/fpdev-fpc-installer-lifecycleflow-lib tests/test_fpc_installer_lifecycleflow.lpr && /tmp/fpdev-fpc-installer-lifecycleflow-bin/test_fpc_installer_lifecycleflow` → `13 checks, 0 failed`
    - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-installer-bin -FU/tmp/fpdev-fpc-installer-lib tests/test_fpc_installer.lpr && /tmp/fpdev-fpc-installer-bin/test_fpc_installer` → `35 passed, 0 failed`
  - 对照旧大测试后识别 residual gaps：helper-focused coverage 还没直接钉住 already-installed error、resolved path wiring、prefix override、download/build failure propagation、uninstall no-op / failure 分支
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 该审计结论已在后续 `Phase 115` 中落实为 lifecycleflow 抽取与 focused/broad verification
  - 本 phase 自身只负责 gap audit 与最小 RED 建议，不单独改动生产代码

## Session: 2026-04-19 (git2 fpcunit follow-up)

### Phase 113: Git2 Fpcunit Conflict Follow-up
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 在 `git2 status conflict coverage` 收口后继续沿同一窄线推进，选定 follow-up 目标为：把 conflict coverage 纳入 fpcunit 聚合套件，而不是只停留在 focused runner
  - 先写 docs/coverage contract RED：
    - 扩展 `tests/test_git2_status_docs_contract.py`
    - 新要求 `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas` 必须包含 `Test_StatusEntries_Conflict_Filtered`
    - 新要求 `docs/history/git2-status-and-tests.md` / `report/fpdev.git2.md` 都明确写出 `TTestCase_Git2Status` 同时覆盖未跟踪过滤与冲突过滤
    - `python3 -m unittest tests.test_git2_status_docs_contract -v` 先失败，命中预期缺口
  - 做最小实现：
    - 在 `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas` 新增：
      - 本地 git CLI helper
      - `PrepareConflictedRepository(...)`
      - `Test_StatusEntries_Conflict_Filtered`
    - 同步 `docs/history/git2-status-and-tests.md` / `report/fpdev.git2.md`
    - 把 `todos/fpdev.git2.md` 的 `文档同步` 汇总项标记为完成
  - fresh focused verification：
    - `python3 -m unittest tests.test_git2_status_docs_contract -v` → `6 passed`
    - `fpc ... tests/fpdev.git2/fpdev.git2.fpcunit.lpr && .../fpdev.git2.fpcunit --all --format=plain` → `3 tests, 0 failures`
- Files created/modified:
  - `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas`
  - `tests/test_git2_status_docs_contract.py`
  - `docs/history/git2-status-and-tests.md`
  - `report/fpdev.git2.md`
  - `todos/fpdev.git2.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 这轮没有继续修改生产代码；目标是让 focused conflict runner 与 fpcunit 聚合 runner 的 coverage 叙事一致
  - 当前 `git2` 这条线更适合停在这里，再往下要重新找新的边界清晰切口

## Session: 2026-04-19 (git2 status conflict coverage)

### Phase 112: Git2 Status Conflict Coverage Closure
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 复核 `todos/fpdev.git2.md` 与现有 `git2` 状态测试，选定当前最小且真实的未收口切口：`StatusEntries` 的冲突场景覆盖
  - 先做 docs contract RED：
    - 更新 `tests/test_git2_status_docs_contract.py`
    - 新要求 `docs/history/git2-status-and-tests.md`、`report/fpdev.git2.md`、`tests/fpdev.git2/buildOrTest.bat`、`todos/fpdev.git2.md` 都要反映 `fpdev.git2.status_conflict_test.lpr`
    - `python3 -m unittest tests.test_git2_status_docs_contract -v` 先失败，命中预期缺口：runner/doc/todo/report 尚未接线
  - 新增 focused runtime RED：
    - 新增 `tests/fpdev.git2/fpdev.git2.status_conflict_test.lpr`
    - 用本地 `git` CLI 在临时仓库里制造真实 merge conflict
    - 初次 focused runner RED 证明默认视图可见 conflict，但 `IndexOnly=True` 会把 conflict 项错误过滤掉
  - 做最小实现：
    - 在 `src/fpdev.git2.pas` 的 `AcceptStatus(...)` 中把 `GIT_STATUS_CONFLICTED` 视作 index/worktree focused view 都可见
    - 把 `tests/fpdev.git2/buildOrTest.bat` 接入新的 conflict runner
    - 同步 `docs/history/git2-status-and-tests.md`、`report/fpdev.git2.md`、`todos/fpdev.git2.md`
  - fresh focused verification：
    - `python3 -m unittest tests.test_git2_status_docs_contract -v` → `5 passed`
    - `fpc ... tests/fpdev.git2/fpdev.git2.status_conflict_test.lpr && .../fpdev.git2.status_conflict_test` → pass
    - `fpc ... tests/fpdev.git2/fpdev.git2.status_index_test.lpr && .../fpdev.git2.status_index_test` → pass
    - `fpc ... tests/fpdev.git2/fpdev.git2.status_entries_test.lpr && .../fpdev.git2.status_entries_test` → pass
- Files created/modified:
  - `src/fpdev.git2.pas`
  - `tests/fpdev.git2/fpdev.git2.status_conflict_test.lpr` (created)
  - `tests/fpdev.git2/buildOrTest.bat`
  - `tests/test_git2_status_docs_contract.py`
  - `docs/history/git2-status-and-tests.md`
  - `report/fpdev.git2.md`
  - `todos/fpdev.git2.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 这轮修的是 `StatusEntries` focused filter 语义，不涉及更大的 `git2` facade 或系统 git runtime 设计
  - 目前 `merge-conflict` 已有真实本地仓库回归；若继续推进 `git2`，更自然的下一刀会转向更细的状态 flags 或更高层 facade 行为，而不是继续把 conflict 记为 TODO

## Session: 2026-04-19 (revalidation checkpoint)

### Phase 111: Revalidation Checkpoint
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 复核当前计划文件与最新 checkpoint 结论，确认这轮更高价值的动作不是再开新 helper wave，而是先验证 FPC/Git 与 facade residual 主线是否仍然成立
  - 运行 FPC/Git + verify/builder boundary bundle：
    - `python3 -m unittest tests.test_git_runtime_boundary tests.test_fpc_builder_boundary tests.test_fpc_manager_verify_boundary tests.test_fpc_binary_verify_boundary -v`
    - 结果：`44 passed`
  - 运行 facade hotspot boundary bundle：
    - `python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v`
    - 结果：`36 passed`
  - 根据 fresh evidence 重新落结论：
    - `fpdev.utils.git` breaking removal、FPC verify consolidation 与主要 facade helperization 均未回退
    - 当前没有出现新的低风险 helper extraction 切口
    - 后续如果要继续推进，应转入新的设计级/业务级目标，而不是继续沿当前 helper-wave 主线机械前进
  - 同步 `task_plan.md`、`findings.md`、`progress.md`，把 stale active goal 收口到当前真实状态
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 这轮没有改动生产代码；动作是 checkpoint close-out 与 fresh evidence sync
  - 当前 dirty worktree 仍很大，后续若进入新目标，应先单独定义目标边界，再做新的 RED -> GREEN

## Session: 2026-04-16

### Phase 110: Project Template Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 基于 Phase 109 完成后的 fresh hotspot recheck，确认当前最高 ROI 已从 `project` 主命令层继续下沉到 `project template` 子命令层：`list/install/remove/update` 4 个命令仍重复持有 help/usage、positional parse 与 exit-code glue
  - 新增 `tests/test_project_template_command_boundary.py`，锁定：
    - 4 个 `project template` 命令单元都必须引入 `fpdev.project.templatecommandflow`
    - `Execute(...)` 必须委托对应 `Prepare...CommandPlanCore(...)` 与 `Execute...CommandPlanCore(...)`
    - 命令单元不再内联 `FindUnknownOption(...)`、`CountPositionalArgs(...)`、`MissingArgError(...)`、`GetPositionalArg(...)` 与 hardcoded usage/help glue
  - 新增 `tests/test_project_templatecommandflow.lpr`，直接覆盖：
    - `list` help / extra arg rejection 与 callback dispatch
    - `install` missing path wording 与 runtime path delegation
    - `remove` missing name wording 与 runtime name delegation
    - `update` extra arg rejection 与 success-failure exit mapping
  - 先跑 RED：
    - `python3 -m unittest tests.test_project_template_command_boundary -v`
    - `fpc ... tests/test_project_templatecommandflow.lpr`
    - 命中的都是预期缺口：`fpdev.project.templatecommandflow` 不存在，4 个命令单元仍保留 parse/help inline glue
  - 新增 `src/fpdev.project.templatecommandflow.pas`，集中承接：
    - `Prepare/ExecuteProjectTemplateListCommandPlanCore(...)`
    - `Prepare/ExecuteProjectTemplateInstallCommandPlanCore(...)`
    - `Prepare/ExecuteProjectTemplateRemoveCommandPlanCore(...)`
    - `Prepare/ExecuteProjectTemplateUpdateCommandPlanCore(...)`
  - 重构 `src/fpdev.cmd.project.template.list.pas` / `install.pas` / `remove.pas` / `update.pas`：
    - 4 个命令都收缩为 thin facade，仅保留 `TProjectManager` ownership、helper 调用、command registration 与 wrapper seam
    - `install` / `remove` 的 missing argument wording 与 single positional parse 下沉到 helper
    - `list` / `update` 的 help/usage 与 unknown-option / extra-arg rejection 下沉到 helper
  - 显式复用了 Phase 109 的安全策略以避免旧坑重演：
    - `ListTemplates` / `InstallTemplate` / `RemoveTemplate` / `UpdateTemplates` 都是 overloaded manager 方法
    - 本轮没有做 unsafe cast，而是在命令单元里补显式 wrapper method，再把 wrapper 传给 helper，避免再次引入运行时栈破坏
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_project_template_command_boundary -v` → `8 / 8`
    - `tests/test_project_templatecommandflow.lpr` → `32 checks`
    - `tests/test_project_template_commands.lpr` → `47 / 47`
    - `tests/test_command_registry.lpr` → `397 / 397`
  - fresh broad verification 全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `632 / 632`
    - `bash scripts/run_all_tests.sh` → `334 / 334`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.project.templatecommandflow.pas` (created)
  - `src/fpdev.cmd.project.template.list.pas`
  - `src/fpdev.cmd.project.template.install.pas`
  - `src/fpdev.cmd.project.template.remove.pas`
  - `src/fpdev.cmd.project.template.update.pas`
  - `tests/test_project_template_command_boundary.py` (created)
  - `tests/test_project_templatecommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 109: Project Main Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 基于 Phase 108 完成后的 fresh hotspot recheck，确认当前最高 ROI 已从 Lazarus 叶子命令层切到 `project` 主命令层：`list/info/build/test/clean/new` 6 个命令仍重复持有 help/usage、parse、JSON/status output 与 exit-code glue
  - 新增 `tests/test_project_command_boundary.py`，锁定：
    - 6 个 `project` 命令单元都必须引入 `fpdev.project.commandflow`
    - `Execute(...)` 必须委托对应 `Prepare...CommandPlanCore(...)` 与 `Execute...CommandPlanCore(...)`
    - 命令单元不再内联 `HasFlag(...)`、`FindUnknownOption(...)`、`CountPositionalArgs(...)`、JSON serialization 与 `build/new` success-failure wording
  - 新增 `tests/test_project_commandflow.lpr`，直接覆盖：
    - `list` help-extra-arg usage error、`--json` parse、JSON payload shape、text path exit-code mapping
    - `info` missing-template wording 与 runtime dispatch
    - `build` default dir/target parse 与 success-failure output
    - `test` / `clean` default dir parse 与 callback-owned output contract
    - `new` derived target dir、missing-argument wording 与 success-failure output
  - 先跑 RED：
    - `python3 -m unittest tests.test_project_command_boundary -v`
    - `fpc ... tests/test_project_commandflow.lpr`
    - 命中的都是预期缺口：`fpdev.project.commandflow` 不存在，6 个命令单元仍保留 parse/help/JSON/output inline glue
  - 新增 `src/fpdev.project.commandflow.pas`，集中承接：
    - `Prepare/ExecuteProjectListCommandPlanCore(...)`
    - `Prepare/ExecuteProjectInfoCommandPlanCore(...)`
    - `Prepare/ExecuteProjectBuildCommandPlanCore(...)`
    - `Prepare/ExecuteProjectTestCommandPlanCore(...)`
    - `Prepare/ExecuteProjectCleanCommandPlanCore(...)`
    - `Prepare/ExecuteProjectNewCommandPlanCore(...)`
  - 重构 `src/fpdev.cmd.project.list.pas` / `info.pas` / `build.pas` / `test.pas` / `clean.pas` / `new.pas`：
    - `list` 命令不再本地生成 JSON，而是委托 helper
    - `build` / `new` 的 success-failure wording 下沉到 helper
    - `test` / `clean` 只保留 manager ownership 与 helper 调用，继续沿用 manager-owned runtime output
  - focused CLI 回归中额外识别出一处真实运行时问题：
    - `list/info/test/clean` 初版通过 unsafe cast 把 overloaded manager 方法塞给 `of object` callback
    - `tests/test_cli_project.lpr` 在 `test` / `clean` no-args 路径命中 `Invalid pointer operation`
    - 修复方式不是 reopen manager，而是在命令单元中补显式 wrapper method，再把 wrapper 传给 helper，保持 facade 薄且消除运行时栈破坏
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_project_command_boundary -v` → `12 / 12`
    - `tests/test_project_commandflow.lpr` → `68 checks`
    - `tests/test_cli_project.lpr` → `83 / 83`
    - `tests/test_project_commands.lpr` → `11 / 11`
  - fresh broad verification 全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `624 / 624`
    - `bash scripts/run_all_tests.sh` → `333 / 333`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.project.commandflow.pas` (created)
  - `src/fpdev.cmd.project.list.pas`
  - `src/fpdev.cmd.project.info.pas`
  - `src/fpdev.cmd.project.build.pas`
  - `src/fpdev.cmd.project.test.pas`
  - `src/fpdev.cmd.project.clean.pas`
  - `src/fpdev.cmd.project.new.pas`
  - `tests/test_project_command_boundary.py` (created)
  - `tests/test_project_commandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 108: Lazarus Leaf Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 基于 Phase 107 完成后的 fresh hotspot recheck，确认当前最高 ROI 已经从 `index` / manager 层切回 Lazarus CLI 叶子命令层：`current/use/show/configure/uninstall/update/test` 7 个命令仍重复持有 help/usage、parse、special-case output 与 exit-code glue
  - 新增 `tests/test_lazarus_leaf_boundary.py`，锁定：
    - 7 个 Lazarus 命令单元都必须引入 `fpdev.lazarus.leafcommandflow`
    - `Execute(...)` 必须委托对应 `Prepare...CommandPlanCore(...)` 与 `Execute...CommandPlanCore(...)`
    - 命令单元不再内联 `HasFlag(...)`、usage/help constant、`current` JSON render、`configure` start banner、`uninstall` generic failed 等 glue
  - 新增 `tests/test_lazarus_leafcommandflow.lpr`，直接覆盖：
    - `current` help / bad args / JSON null semantics / text output
    - `use` missing version / extra positional / callback dispatch
    - `show` missing version / unsupported version `EXIT_NOT_FOUND` / success callback
    - `configure` help / start banner / no extra generic failure
    - `uninstall` generic failed append
    - `update` optional version parse / no-extra-message success-failure
    - `test` unknown option / no-extra-message failure
  - 先跑 RED：
    - `python3 -m unittest tests.test_lazarus_leaf_boundary -v`
    - `fpc ... tests/test_lazarus_leafcommandflow.lpr`
    - 命中的都是预期缺口：`fpdev.lazarus.leafcommandflow` 不存在，7 个命令单元仍保留 parse/help inline glue
  - 新增 `src/fpdev.lazarus.leafcommandflow.pas`，集中承接：
    - `PrepareLazarusCurrentCommandPlanCore(...)`
    - `ExecuteLazarusCurrentCommandPlanCore(...)`
    - `Prepare/ExecuteLazarusUseCommandPlanCore(...)`
    - `Prepare/ExecuteLazarusShowCommandPlanCore(...)`
    - `Prepare/ExecuteLazarusConfigureCommandPlanCore(...)`
    - `Prepare/ExecuteLazarusUninstallCommandPlanCore(...)`
    - `Prepare/ExecuteLazarusUpdateCommandPlanCore(...)`
    - `Prepare/ExecuteLazarusTestCommandPlanCore(...)`
  - 重构 `src/fpdev.cmd.lazarus.current.pas` / `use.pas` / `show.pas` / `configure.pas` / `uninstall.pas` / `update.pas` / `test.pas`：
    - `current` 命令不再本地生成 JSON / text 输出，而是委托 helper
    - `show` 只保留 `TVersionRegistry.Instance.IsLazarusVersionValid` seam 与 manager callback 接线
    - `configure` / `uninstall` / `update` / `test` 都收缩为 thin facade，仅保留 manager ownership 与 helper 调用
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_lazarus_leaf_boundary -v` → `14 / 14`
    - `tests/test_lazarus_leafcommandflow.lpr` → `68 checks`
    - `tests/test_cli_lazarus.lpr` → `143 / 143`
    - `tests/test_lazarus_update.lpr` → `150 / 150`
    - `tests/test_lazarus_configure_workflow.lpr` → `51 / 51`
  - fresh broad verification 全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `612 / 612`
    - `bash scripts/run_all_tests.sh` → `332 / 332`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.lazarus.leafcommandflow.pas` (created)
  - `src/fpdev.cmd.lazarus.current.pas`
  - `src/fpdev.cmd.lazarus.use.pas`
  - `src/fpdev.cmd.lazarus.show.pas`
  - `src/fpdev.cmd.lazarus.configure.pas`
  - `src/fpdev.cmd.lazarus.uninstall.pas`
  - `src/fpdev.cmd.lazarus.update.pas`
  - `src/fpdev.cmd.lazarus.test.pas`
  - `tests/test_lazarus_leaf_boundary.py` (created)
  - `tests/test_lazarus_leafcommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 107: Index Service Cache/Offline Refactor Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 基于 fresh hotspot recheck 后确认的方向，开始收口 `src/fpdev.index.pas` 的 remote/cache glue，而不是继续沿用旧的 `package` 收口目标
  - 新增 `tests/test_index_boundary.py`，锁定：
    - `src/fpdev.index.pas` 必须引入 `fpdev.index.serviceflow`
    - constructor 必须统一走 `GetCacheDir`
    - `Initialize` 必须通过 shared remote/cache helper 加载 index
    - manifest download/version list surface 必须委托 helper 层
    - `src/fpdev.index.commandflow.pas` 必须把 `Ctx.Out` 注入 `Index.Output`
  - 新增 `tests/test_index_serviceflow.lpr`，直接覆盖：
    - remote success -> 写 cache
    - remote fail + cache hit -> 成功并 warning
    - remote fail + cache miss -> 失败并 warning
    - manifest versions / download info 解析
  - 扩展 `tests/test_cmd_index.lpr`，通过 `RunIndexShowWithFactory(...)` / `RunIndexUpdateWithFactory(...)` 注入 fake service，稳定验证 `show/update` 的 cache fallback success path 与 no-cache failure path
  - 先跑 RED：
    - `python3 -m unittest tests.test_index_boundary -v`
    - `fpc ... tests/test_index_serviceflow.lpr`
    - `fpc ... tests/test_cmd_index.lpr`
    - 命中的都是预期缺口：helper 单元不存在、commandflow 缺少 factory seam、`TFPDevIndex` 相关方法不可 override
  - 新增 `src/fpdev.index.serviceflow.pas`，集中承接 index/manifest cache path、remote/cache JSON 加载与 manifest parse helper
  - 重构 `src/fpdev.index.pas`：
    - `TFPDevIndex.Create(...)` 改为统一使用 `GetCacheDir`
    - `Initialize` 改为 remote -> fallback -> cache 流程，成功时写回 cache，失败时使用 cache fallback
    - bootstrap / fpc / lazarus manifest 下载与版本列表改为复用 shared helper，不再在 6 个方法里重复 inline fetch/parse
    - 为 deterministic commandflow tests 将 `Initialize` / query/list surface 标记为 `virtual`
  - 重构 `src/fpdev.index.commandflow.pas`：
    - `RunIndexShow` / `RunIndexUpdate` 统一设置 `Index.Output := Ctx.Out`
    - 新增 `RunIndexShowWithFactory(...)` / `RunIndexUpdateWithFactory(...)`
  - 顺手清掉了新 helper 的 managed-type 初始化 hint：`AMirrors := nil`
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_index_boundary -v` → `6 / 6`
    - `tests/test_index_serviceflow.lpr` → `24 / 24`
    - `tests/test_cmd_index.lpr` → `37 / 37`
    - `python3 -m unittest tests.test_index_boundary tests.test_command_namespace_hygiene tests.test_temp_hygiene -v` → `152 / 152`
    - `tests/test_command_registry.lpr` → `397 / 397`
    - `tests/test_fpc_indexflow.lpr` → `11 / 11`
  - fresh broad verification 全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `598 / 598`
    - `bash scripts/run_all_tests.sh` → `331 / 331`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.index.serviceflow.pas` (created)
  - `src/fpdev.index.pas`
  - `src/fpdev.index.commandflow.pas`
  - `tests/test_index_boundary.py` (created)
  - `tests/test_index_serviceflow.lpr` (created)
  - `tests/test_cmd_index.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 106: Package Deps/Why + Repo + Lifecycle Commandflow Thin-Facade Follow-up Wave Pack
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 延续 Phase 105 的 fresh checkpoint re-ranking，按 ROI 顺序连续收 `src/fpdev.cmd.package.deps.pas` / `src/fpdev.cmd.package.why.pas`、4 个 `package repo` 子命令，以及 `src/fpdev.cmd.package.update.pas` / `src/fpdev.cmd.package.uninstall.pas` / `src/fpdev.cmd.package.install_local.pas`
  - 新增 `tests/test_package_deps_boundary.py` 与 `tests/test_package_why_boundary.py`，锁定 `TPackageDepsCommand.Execute(...)` / `TPackageWhyCommand.Execute(...)` 必须委托新 helper
  - 新增 `tests/test_package_depscommandflow.lpr` 与 `tests/test_package_whycommandflow.lpr`，直接覆盖 help/usage、unknown option、package positional parse、sample output dispatch 与 exit-code mapping
  - 新增 `src/fpdev.package.depscommandflow.pas` 与 `src/fpdev.package.whycommandflow.pas`，落下：
    - `PreparePackageDepsCommandPlanCore(...)`
    - `ExecutePackageDepsCommandPlanCore(...)`
    - `PreparePackageWhyCommandPlanCore(...)`
    - `ExecutePackageWhyCommandPlanCore(...)`
  - 让 `src/fpdev.cmd.package.deps.pas` 与 `src/fpdev.cmd.package.why.pas` 收缩为 thin command facade：只保留 `TPackageManager` ownership、helper 调用与 command registration
  - 新增 `tests/test_package_repo_boundary.py`，锁定 `package repo add/list/remove/update` 必须统一委托 `fpdev.package.repocommandflow`
  - 新增 `tests/test_package_repocommandflow.lpr`，直接覆盖 add/list/remove/update 的 help/usage、unknown option、missing/extra positional、exists/not-found precheck、callback dispatch 与 exit-code mapping
  - 新增 `src/fpdev.package.repocommandflow.pas`，将 4 个 repo 子命令共用的 parse/runtime glue 下沉到共享 helper
  - 让 `src/fpdev.cmd.package.repo.add.pas` / `list.pas` / `remove.pas` / `update.pas` 收缩为 thin command facade：只保留 `TPackageManager` ownership、helper 调用与 command registration
  - 新增 `tests/test_package_lifecycle_boundary.py` 与 `tests/test_package_lifecyclecommandflow.lpr`，锁定并覆盖 `package update` / `package uninstall` / `package install-local` 的 help/usage、unknown option、installed/path preflight、callback dispatch 与 exit-code mapping
  - 新增 `src/fpdev.package.lifecyclecommandflow.pas`，集中承接 lifecycle 子命令的 parse/runtime glue
  - 让 `src/fpdev.cmd.package.update.pas` / `src/fpdev.cmd.package.uninstall.pas` / `src/fpdev.cmd.package.install_local.pas` 收缩为 thin command facade：只保留 manager ownership、runtime path ownership、helper 调用与 command registration
  - broad verification 前先清理可再生产物 `bin/`、`lib/` 与 `/tmp/fpdev-*`，避免上一轮已经出现过的空间噪音重演
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_package_deps_boundary tests.test_package_why_boundary tests.test_package_repo_boundary tests.test_package_lifecycle_boundary -v` → `18 tests OK`
    - `tests/test_package_depscommandflow.lpr` → `35 / 35`
    - `tests/test_package_whycommandflow.lpr` → `25 / 25`
    - `tests/test_package_repocommandflow.lpr` → `78 / 78`
    - `tests/test_package_lifecyclecommandflow.lpr` → `52 / 52`
    - `tests/test_cli_package.lpr` → `234 / 234`
    - `tests/test_command_registry.lpr` → `397 / 397`
    - `tests/test_cli_misc.lpr` → `152 / 152`
  - fresh broad verification 全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `591 / 591`
    - `bash scripts/run_all_tests.sh` → `329 / 329`
    - `lazbuild -B fpdev.lpi` → pass
  - 继续做最小源码噪音清理：把 `src/fpdev.package.repocommandflow.pas` 中 `repo list/update` execute helper 的无用 plan / err 参数去掉，避免本波新引入 unused-parameter hint
  - 基于最新代码再做 checkpoint re-ranking：
    - `package` leaf command surfaces 现已基本完成 thin-facade 收口
    - `package help` / root command 装配层继续保持轻量，不 reopen
    - 若继续推进，更高 ROI 的下一刀大概率转移到 `package` 叶子命令层之外，除非 fresh hotspot scan 证明相反
- Files created/modified:
  - `src/fpdev.package.depscommandflow.pas` (created)
  - `src/fpdev.package.whycommandflow.pas` (created)
  - `src/fpdev.package.repocommandflow.pas` (created)
  - `src/fpdev.package.lifecyclecommandflow.pas` (created)
  - `src/fpdev.cmd.package.deps.pas`
  - `src/fpdev.cmd.package.why.pas`
  - `src/fpdev.cmd.package.repo.add.pas`
  - `src/fpdev.cmd.package.repo.list.pas`
  - `src/fpdev.cmd.package.repo.remove.pas`
  - `src/fpdev.cmd.package.repo.update.pas`
  - `src/fpdev.cmd.package.update.pas`
  - `src/fpdev.cmd.package.uninstall.pas`
  - `src/fpdev.cmd.package.install_local.pas`
  - `tests/test_package_deps_boundary.py` (created)
  - `tests/test_package_why_boundary.py` (created)
  - `tests/test_package_repo_boundary.py` (created)
  - `tests/test_package_lifecycle_boundary.py` (created)
  - `tests/test_package_depscommandflow.lpr` (created)
  - `tests/test_package_whycommandflow.lpr` (created)
  - `tests/test_package_repocommandflow.lpr` (created)
  - `tests/test_package_lifecyclecommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 105: Package List + Clean Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 延续 `package publish` / `package search` / `package info` 的 thin-facade 模式，继续收 `src/fpdev.cmd.package.list.pas` 与 `src/fpdev.cmd.package.clean.pas`
  - 新增 `tests/test_package_list_boundary.py`，锁定 `TPackageListCommand.Execute(...)` 必须委托 `fpdev.package.listcommandflow`
  - 新增 `tests/test_package_listcommandflow.lpr`，直接覆盖 help/usage、unknown option、extra positional、`--all` / `-a` / `--json`、text / JSON dispatch 与 exit-code mapping
  - 先跑 RED：
    - `python3 -m unittest tests.test_package_list_boundary -v` 因 helper 尚未接入而失败
    - `fpc ... tests/test_package_listcommandflow.lpr` 因 `fpdev.package.listcommandflow` 不存在而编译失败
  - 新增 `src/fpdev.package.listcommandflow.pas`，落下：
    - `PreparePackageListCommandPlanCore(...)`
    - `ExecutePackageListCommandPlanCore(...)`
  - 让 `src/fpdev.cmd.package.list.pas` 收缩为 thin command facade：只保留 `TPackageManager` ownership、helper 调用与 command registration
  - 新增 `tests/test_package_clean_boundary.py`，锁定 `TPackageCleanCommand.Execute(...)` 必须委托 `fpdev.package.cleancommandflow`
  - 新增 `tests/test_package_cleancommandflow.lpr`，直接覆盖 help/usage、unknown option、invalid scope / extra positional、`--dry-run`、`--yes`、refusal / success / failure exit-code mapping
  - 先跑 RED：
    - `python3 -m unittest tests.test_package_clean_boundary -v` 因 helper 尚未接入而失败
    - `fpc ... tests/test_package_cleancommandflow.lpr` 因 `fpdev.package.cleancommandflow` 不存在而编译失败
  - 新增 `src/fpdev.package.cleancommandflow.pas`，落下：
    - `PreparePackageCleanCommandPlanCore(...)`
    - `ExecutePackageCleanCommandPlanCore(...)`
  - 让 `src/fpdev.cmd.package.clean.pas` 收缩为 thin command facade：只保留 `TPackageManager` ownership、runtime path 注入、helper 调用与 command registration
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_package_list_boundary tests.test_package_clean_boundary -v`
    - `tests/test_package_listcommandflow.lpr` → `34 / 34`
    - `tests/test_package_cleancommandflow.lpr` → `35 / 35`
    - `tests/test_cli_package.lpr` → `234 / 234`
  - 在 broad verification 前主动清理 `bin/`、`lib/` 与 `/tmp/fpdev-*`，避免重演前一波的 `No space left on device` 环境噪音
  - fresh broad verification 全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `573 / 573`
    - `bash scripts/run_all_tests.sh` → `325 / 325`
    - `lazbuild -B fpdev.lpi` → pass
  - 基于最新代码再做 checkpoint re-ranking：
    - 第一优先：`package deps` / `package why`，两者仍内联 help/parse/输出编排，且已有 CLI 契约护栏
    - 第二优先：`package repo add/list/remove/update`，4 个命令形态一致且测试面已存在，适合成组收口
    - 第三优先：`package update` / `package uninstall` / `package install-local`，仍值得做，但运行时前置检查更多，优先级稍后
- Files created/modified:
  - `src/fpdev.package.listcommandflow.pas` (created)
  - `src/fpdev.cmd.package.list.pas`
  - `tests/test_package_list_boundary.py` (created)
  - `tests/test_package_listcommandflow.lpr` (created)
  - `src/fpdev.package.cleancommandflow.pas` (created)
  - `src/fpdev.cmd.package.clean.pas`
  - `tests/test_package_clean_boundary.py` (created)
  - `tests/test_package_cleancommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 104: Package Info Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 延续 `package publish` / `package search` 的 thin-facade 模式，继续收 `src/fpdev.cmd.package.info.pas`
  - 新增 `tests/test_package_info_boundary.py`，锁定 `TPackageInfoCommand.Execute(...)` 必须委托 `fpdev.package.infocommandflow`
  - 新增 `tests/test_package_infocommandflow.lpr`，直接覆盖 help/usage、unknown option、missing / blank / extra positional、installed package precheck、show-info success / failure exit-code mapping
  - 先跑 RED：
    - `python3 -m unittest tests.test_package_info_boundary -v` 因 helper 尚未接入而失败
    - `fpc ... tests/test_package_infocommandflow.lpr` 因 `fpdev.package.infocommandflow` 不存在而编译失败
  - 新增 `src/fpdev.package.infocommandflow.pas`，落下：
    - `PreparePackageInfoCommandPlanCore(...)`
    - `ExecutePackageInfoCommandPlanCore(...)`
  - 让 `src/fpdev.cmd.package.info.pas` 收缩为 thin command facade：只保留 `TPackageManager` ownership、helper 调用与 command registration
  - focused 验证全部通过：
    - `python3 -m unittest tests.test_package_info_boundary -v`
    - `tests/test_package_infocommandflow.lpr`
    - `tests/test_cli_package.lpr`
  - broad 验证首次命中环境噪音而非生产回归：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` 在 `.tmp-pytest/` 与 `logs/check/` 写入时报告 `No space left on device`
    - 进一步排查确认源于可再生产物占用空间，而不是本波 `package info` 行为变化
  - 清理 `bin/`、`lib/` 与 `/tmp/fpdev-*` 后重新 fresh 验证，全部通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `569 / 569`
    - `bash scripts/run_all_tests.sh` → `323 / 323`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.package.infocommandflow.pas` (created)
  - `src/fpdev.cmd.package.info.pas`
  - `tests/test_package_info_boundary.py` (created)
  - `tests/test_package_infocommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 103: Package Search Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 延续上一波 `package publish` 的 fresh hotspot re-ranking，继续收 `src/fpdev.cmd.package.search.pas`
  - 新增 `tests/test_package_search_boundary.py`，锁定 `TPackageSearchCmd.Execute(...)` 必须委托 `fpdev.package.searchcommandflow`
  - 新增 `tests/test_package_searchcommandflow.lpr`，直接覆盖 help/usage、unknown option、missing / blank / extra positional、`--json` parse、text search success/failure exit-code mapping、JSON output formatting
  - 先跑 RED：
    - `python3 -m unittest tests.test_package_search_boundary -v` 因 helper 尚未接入而失败
    - `fpc ... tests/test_package_searchcommandflow.lpr` 因 `fpdev.package.searchcommandflow` 不存在而编译失败
  - 新增 `src/fpdev.package.searchcommandflow.pas`，落下：
    - `PreparePackageSearchCommandPlanCore(...)`
    - `ExecutePackageSearchCommandPlanCore(...)`
  - 让 `src/fpdev.cmd.package.search.pas` 收缩为 thin command facade：只保留 `TPackageManager` / `TPackageSearchCommand` ownership、helper 调用与 command registration
  - 顺手清理 `src/fpdev.cmd.package.publish.pas` 的未使用 `uses`，把上一波留下的源码 hint 一起收掉
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_package_search_boundary -v`
    - `tests/test_package_searchcommandflow.lpr`
    - `tests/test_cli_package.lpr`
  - fresh broad verification 继续通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `567 / 567`
    - `bash scripts/run_all_tests.sh` → `322 / 322`
    - `lazbuild -B fpdev.lpi` → pass
  - fresh `lazbuild` 现在只剩工具链配置文件读取相关的 2 条 hint；本轮源码未再引入新的编译 hint
- Files created/modified:
  - `src/fpdev.package.searchcommandflow.pas` (created)
  - `src/fpdev.cmd.package.search.pas`
  - `src/fpdev.cmd.package.publish.pas`
  - `tests/test_package_search_boundary.py` (created)
  - `tests/test_package_searchcommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 102: Package Publish Commandflow Thin-Facade Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 基于 fresh hotspot re-ranking，确认下一波不 reopen 已经很薄的 `project.manager` / `package.manager`，而是转向仍然厚重的 `src/fpdev.cmd.package.publish.pas`
  - 新增 `tests/test_package_publish_boundary.py`，锁定 `TPackagePublishCmd.Execute(...)` 必须委托 `fpdev.package.publishcommandflow`
  - 新增 `tests/test_package_publishcommandflow.lpr`，直接覆盖 help/usage、unknown option、missing/extra positional、installed package precheck、metadata preflight、publish success / failure exit-code mapping
  - 先跑 RED：
    - `python3 -m unittest tests.test_package_publish_boundary -v` 因 helper 尚未接入而失败
    - `fpc ... tests/test_package_publishcommandflow.lpr` 因 `fpdev.package.publishcommandflow` 不存在而编译失败
  - 新增 `src/fpdev.package.publishcommandflow.pas`，落下：
    - `PreparePackagePublishCommandPlanCore(...)`
    - `ExecutePackagePublishCommandPlanCore(...)`
  - 让 `src/fpdev.cmd.package.publish.pas` 收缩为 thin command facade：只保留 `TPackageManager` ownership、helper 调用与 command registration
  - 在 direct helper 测试中命中一个真实测试程序问题：`TStringOutput` 作为 `TInterfacedObject` 被临时接口引用提前释放，导致成功路径后 AccessViolation；改为 object + interface 双持有后恢复稳定
  - fresh focused verification 全部通过：
    - `python3 -m unittest tests.test_package_publish_boundary -v`
    - `tests/test_package_publishcommandflow.lpr`
    - `tests/test_cli_package.lpr`
  - fresh broad verification 继续通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `565 / 565`
    - `bash scripts/run_all_tests.sh` → `321 / 321`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.package.publishcommandflow.pas` (created)
  - `src/fpdev.cmd.package.publish.pas`
  - `tests/test_package_publish_boundary.py` (created)
  - `tests/test_package_publishcommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 101: Git2 Focused Runner Rehab + Truth Sync Closure
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 重新编译 `tests/fpdev.git2/fpdev.git2.status_test.lpr`、`status_entries_test.lpr`，fresh 复现陈旧 runner 的真实红灯：
    - 依赖已移除的全局 `GitManager`
    - 缺失 `Classes` / `TStringList`
    - 使用当前 FPC mode 不接受的 `for var i := ...`
  - 继续摸底发现同目录其余 focused runner 也有真实残留：
    - `status_ignore_test.lpr` / `status_index_test.lpr` 同样依赖全局 `GitManager`
    - `status_index_test.lpr` 还尝试越过可见性访问 `TGitRepository.FHandle`
    - `fpdev.git2.fpcunit.tests.pas` 仍调用当前 FPC 不支持的 `TrimRight(..., [''\'',''/''])`
    - `fpdev.git2.fpcunit.lpr` 仍使用过时的 `RunRegisteredTests`
  - 对 direct runner 做最小兼容修复：
    - 改用当前 concrete `TGitManager` / `TGitRepository`
    - `status_index_test.lpr` 改为通过 `git_repository_open(...)` + `git_repository_index(...)` 打开原生 handle，不再依赖私有字段
    - Unix 清理路径统一改为 `/bin/rm`
    - `fpdev.git2.fpcunit.lpr` 切换为 `TTestRunner.Initialize/Run`
    - `fpdev.git2.fpcunit.tests.pas` 用 `ExcludeTrailingPathDelimiter(...)` 替代不兼容的 `TrimRight(...)`
  - 通过临时 debug 程序确认 `.gitignore` 场景红灯根因：
    - `TGitRepository.StatusEntries(...)` 已经能在 `IncludeIgnored=True` 时枚举 ignored 项
    - 但 `AcceptStatus(...)` 把 `WorkingTreeOnly` 只认作 WT_* 标志，没有把 `GIT_STATUS_IGNORED` 算作工作区项
  - 最小生产修复：
    - 在 `src/fpdev.git2.pas` 的 `AcceptStatus(...)` 中把 `GIT_STATUS_IGNORED` 纳入 `LHasWt`
    - `status_ignore_test.lpr` 随即 fresh 转绿
  - 新增 truth-sync 契约：
    - `tests/test_git2_status_docs_contract.py` 现在要求 fpcunit runner 文档与 batch 都明确 `fpdev.git2.fpcunit.exe --all --format=plain`
    - fresh RED 后同步 `docs/history/git2-status-and-tests.md`、`report/fpdev.git2.md` 与 `tests/fpdev.git2/buildOrTest.fpcunit.bat`
  - fresh focused verification 全部通过：
    - `tests/fpdev.git2/fpdev.git2.test.lpr`
    - `tests/fpdev.git2/fpdev.git2.status_test.lpr`
    - `tests/fpdev.git2/fpdev.git2.status_entries_test.lpr`
    - `tests/fpdev.git2/fpdev.git2.status_ignore_test.lpr`
    - `tests/fpdev.git2/fpdev.git2.status_index_test.lpr`
    - `tests/fpdev.git2/fpdev.git2.fpcunit.lpr --all --format=plain`
    - `python3 -m unittest tests.test_contributor_docs_contract tests.test_git2_status_docs_contract tests.test_git_runtime_boundary -v` → `71 tests OK`
  - fresh broad verification 继续通过：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `563 / 563`
    - `bash scripts/run_all_tests.sh` → `320 / 320`
    - `bash scripts/check_toolchain.sh` → `missing_required: 0`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `src/fpdev.git2.pas`
  - `tests/fpdev.git2/fpdev.git2.test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_entries_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_ignore_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_index_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.fpcunit.lpr`
  - `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas`
  - `tests/fpdev.git2/buildOrTest.fpcunit.bat`
  - `tests/test_git2_status_docs_contract.py`
  - `docs/history/git2-status-and-tests.md`
  - `report/fpdev.git2.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Session: 2026-04-15

### Phase 99: Hint Burn-down + Fresh Hotspot Recheck Closure
- **Status:** complete
- **Started:** 2026-04-15
- Actions taken:
  - fresh 复跑 `lazbuild -B fpdev.lpi`，确认标准 Lazarus 构建路径已恢复为绿
  - 对当前 `src/` hint list 做最小无行为变化清理：删除未使用 `uses`，并在 managed dynamic array 局部变量上补显式初始化
  - 再次执行 full verification bundle：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `552 / 552`
    - `bash scripts/check_toolchain.sh` → required `0` missing
    - `bash scripts/cli_smoke.sh ./bin/fpdev` → passed
    - `bash scripts/run_all_tests.sh` → `319 / 319`
  - 复核 `src/fpdev.lazarus.source.pas` 与 `src/fpdev.cross.search.pas` 的当前实现，确认此前计划里列作“下一波”的 `sourceflow/sourceruntimeflow/sourcelifecycleflow/sourceversionflow` 与 `searchdiag/searchpaths/searchflow` 已全部在当前树中落地
  - 结论切换为：本轮不 reopen 旧的 `lazarus.source` / `cross.search` 波次，优先把 planning artifacts 同步到 repo 真实状态
- Files created/modified:
  - `src/fpdev.git.operations.impl.pas`
  - `src/fpdev.cmd.package.install.pas`
  - `src/fpdev.cross.manager.pas`
  - `src/fpdev.build.runtimeflow.pas`
  - `src/fpdev.cmd.cross.build.pas`
  - `src/fpdev.cross.searchdiag.pas`
  - `src/fpdev.lazarus.manager.pas`
  - `src/fpdev.cmd.lazarus.install.pas`
  - `src/fpdev.fpc.builder.pas`
  - `src/fpdev.fpc.manager.pas`
  - `src/fpdev.cmd.fpc.verify.pas`
  - `src/fpdev.cmd.fpc.use.pas`
  - `src/fpdev.cmd.fpc.install.pas`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Session: 2026-04-14

### Phase 95: CLI Commandflow Wave Pack Planning
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 复核当前工作树与上一轮 `fpc install commandflow` 落地结果，确认接下来最值得推进的是 CLI commandflow 薄化，而不是继续切 manager/source/repo 小 wrapper
  - 固化 5-wave pack 实施顺序：
    - `lazarus install`
    - `package install`
    - `fpc use`
    - `fpc verify`
    - `cross build`
  - 新增正式总计划 `docs/plans/2026-04-14-cli-commandflow-wave-pack.md`
  - 同步 `task_plan.md` / `findings.md` / `progress.md`，将当前主线切到新的 CLI wave pack
- Files created/modified:
  - `docs/plans/2026-04-14-cli-commandflow-wave-pack.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 98: CLI Commandflow Wave Pack Broad Verification + Closure
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 重新核对 5-wave pack 的 focused 证据链，确认 `lazarus install`、`package install`、`fpc use`、`fpc verify`、`cross build` 五个命令都已经收缩为 thin facade + helper
  - 运行 Python 全量回归：`python3 -m unittest discover -s tests -p 'test_*.py'`
  - 记录 Python 结果：`551 / 551`
  - 运行 Pascal 整仓回归：`bash scripts/run_all_tests.sh`
  - 记录 Pascal 结果：`319 / 319`
  - 同步 `task_plan.md`、`findings.md`、`progress.md` 到最终收口状态
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 97: Cross Build Commandflow Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 新增 `tests/test_cross_build_boundary.py`，锁定 `TCrossBuildCommand.Execute(...)` 必须委托 `fpdev.cross.buildcommandflow`
  - 新增 `tests/test_cross_buildcommandflow.lpr`，直接覆盖 help/usage、target parse、`--dry-run` / `--source` / `--sandbox` / `--version`、source-tree preflight、success/failure exit-code mapping
  - 先跑 RED，确认失败点落在 helper 缺失与 command 未回接
  - 新增 `src/fpdev.cross.buildcommandflow.pas`
  - 让 `src/fpdev.cmd.cross.build.pas` 收缩为 thin command facade，并通过小型 engine bridge 传递 runtime callback
  - focused 验证 fresh 通过：
    - `python3 -m unittest tests.test_cross_build_boundary -v`
    - `tests/test_cross_buildcommandflow.lpr`
    - `tests/test_cmd_cross_build.lpr`
    - `tests/test_cli_cross.lpr`
- Files created/modified:
  - `src/fpdev.cross.buildcommandflow.pas` (created)
  - `src/fpdev.cmd.cross.build.pas`
  - `tests/test_cross_build_boundary.py` (created)
  - `tests/test_cross_buildcommandflow.lpr` (created)

### Phase 96: FPC Verify Commandflow Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_fpc_verify_boundary.py`，锁定 `TFPCVerifyCommand.Execute(...)` 必须委托 `fpdev.fpc.verifycommandflow`
  - 新增 `tests/test_fpc_verifycommandflow.lpr`，直接覆盖 help/usage、single positional version、step-by-step report、metadata wording 与 exit-code mapping
  - 先跑 RED，确认失败点落在 helper 缺失与 command 未回接
  - 新增 `src/fpdev.fpc.verifycommandflow.pas`
  - 让 `src/fpdev.cmd.fpc.verify.pas` 收缩为 thin command facade：只保留 `TFPCManager` ownership、helper 调用与注册
  - focused 验证 fresh 通过：
    - `python3 -m unittest tests.test_fpc_verify_boundary -v`
    - `tests/test_fpc_verifycommandflow.lpr`
    - `tests/test_fpc_verify.lpr`
    - `tests/test_cli_fpc_diag.lpr`
- Files created/modified:
  - `src/fpdev.fpc.verifycommandflow.pas` (created)
  - `src/fpdev.cmd.fpc.verify.pas`
  - `tests/test_fpc_verify_boundary.py`
  - `tests/test_fpc_verifycommandflow.lpr` (created)

### Phase 94: FPC Install Commandflow Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 新增正式计划 `docs/plans/2026-04-14-fpc-install-commandflow-wave.md`
  - 扩展 `tests/test_fpc_install_cli_boundary.py`，锁定 `TFPCInstallCommand.Execute(...)` 必须委托 `fpdev.fpc.installcommandflow`
  - 新增 `tests/test_fpc_installcommandflow.lpr`，直接覆盖 help/usage、jobs settings update、invalid from/prefix、network guard、auto fallback 与 source-mode dispatch
  - 新增 `src/fpdev.fpc.installcommandflow.pas`
  - 让 `src/fpdev.cmd.fpc.install.pas` 收缩为 thin command facade：只保留 settings 持久化、`TFPCManager` 创建/释放、helper 调用与注册
  - 运行 focused 验证并全部通过：Python boundary、新 direct helper、现有 `test_fpc_install_cli.lpr`
  - 运行 broad 验证并全部通过：Python discover `542/542`、整仓 `314/314`
- Files created/modified:
  - `docs/plans/2026-04-14-fpc-install-commandflow-wave.md` (created)
  - `src/fpdev.fpc.installcommandflow.pas` (created)
  - `src/fpdev.cmd.fpc.install.pas`
  - `tests/test_fpc_install_cli_boundary.py`
  - `tests/test_fpc_installcommandflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 84: Lazarus Manager Catalog + Maintenance Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 基于两份新 plan 先补齐 RED：扩展 `tests/test_lazarus_manager_metadata_boundary.py`、`tests/test_lazarus_manager_runtime_boundary.py`，新增 `tests/test_lazarus_catalogflow.lpr`、`tests/test_lazarus_maintenanceflow.lpr`
  - 新增 `src/fpdev.lazarus.catalogflow.pas`，承接 compatible-FPC resolve、available versions inventory、installed-only filter
  - 新增 `src/fpdev.lazarus.maintenanceflow.pas`，承接 uninstall/update-sources/clean-sources facade orchestration
  - 让 `src/fpdev.lazarus.manager.pas` 的 `GetCompatibleFPCVersion(...)`、`GetAvailableVersions(...)`、`GetInstalledVersions(...)`、`UninstallVersion(...)`、`UpdateSources(...)`、`CleanSources(...)` 收缩为 thin delegate
  - 中途修掉两个真实问题：
    - `catalogflow` 对 `lazarus-` 前缀的归一化长度写错，导致 overlay 失败
    - `CreateMaintenanceGitRuntime(...)` 的 interface bridge 方式导致 `UpdateSources(...)` focused suite 初次回归失败，改为直接返回基接口后恢复为绿
  - 重新运行 Lazarus boundary/direct/manager focused suites，全部通过
- Files created/modified:
  - `src/fpdev.lazarus.catalogflow.pas` (created)
  - `src/fpdev.lazarus.maintenanceflow.pas` (created)
  - `src/fpdev.lazarus.manager.pas`
  - `tests/test_lazarus_manager_metadata_boundary.py`
  - `tests/test_lazarus_manager_runtime_boundary.py`
  - `tests/test_lazarus_catalogflow.lpr` (created)
  - `tests/test_lazarus_maintenanceflow.lpr` (created)

### Phase 85: Cross Manager Install-Support Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_cross_manager_boundary.py`，锁定 downloader/environment surface 必须委托 `installsupportflow`
  - 新增 `tests/test_cross_installsupportflow.lpr`，直接覆盖 missing-downloader、manual fallback、config save wiring
  - 新增 `src/fpdev.cross.installsupportflow.pas`
  - 让 `src/fpdev.cross.manager.pas` 的 `DownloadBinutils(...)`、`DownloadLibraries(...)`、`SetupCrossEnvironment(...)` 收缩为 thin delegate，同时保持 `InstallTarget(...)` / `UpdateTarget(...)` 继续复用 `fpdev.cross.managerflow`
  - 主控复核 focused cross suites，确认全部为绿
- Files created/modified:
  - `src/fpdev.cross.installsupportflow.pas` (created)
  - `src/fpdev.cross.manager.pas`
  - `tests/test_cross_manager_boundary.py`
  - `tests/test_cross_installsupportflow.lpr` (created)

### Phase 86: Integration + Focused/Full Verification
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 审阅并集成 worker 结果：Cross worker 直接收口；Lazarus worker 先完成 RED + helper，再由主控完成 `src/fpdev.lazarus.manager.pas` 的最终回接
  - 运行 Python boundary bundle，确认 Lazarus catalog/maintenance 与 Cross install-support 委托边界全部成立
  - 运行 Lazarus focused Pascal suites：`test_lazarus_catalogflow`、`test_lazarus_maintenanceflow`、`test_lazarus_management`、`test_lazarus_update`、`test_lazarus_flow`
  - 运行 Cross focused Pascal suites：`test_cross_installsupportflow`、`test_cross_managerflow`、`test_cross_management`、`test_cross_targetflow`
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `310/310`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 83: 2026-04-14 Lazarus/Cross Follow-up Planning
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 重新读取 `task_plan.md`、`findings.md`、`progress.md` 与最新收口结果，确认上一波完成后仍应继续实扫而不是机械沿用旧排序
  - 复核 `src/fpdev.lazarus.manager.pas` 与 `src/fpdev.cross.manager.pas` 的剩余 inline surface，确认真实下一组 ROI 是：
    - `lazarus.manager` catalog/configured merge surface
    - `lazarus.manager` maintenance/source surface
    - `cross.manager` downloader/environment surface
  - 明确并发约束：由于两条 Lazarus 子波次都会改 `src/fpdev.lazarus.manager.pas`，执行上合并为一个 worker ownership，避免并发冲突
  - 新增三份正式计划文档：
    - `docs/plans/2026-04-14-lazarus-manager-catalog-surface-wave.md`
    - `docs/plans/2026-04-14-lazarus-manager-maintenance-surface-wave.md`
    - `docs/plans/2026-04-14-cross-manager-install-support-wave.md`
  - 同步 `task_plan.md`、`findings.md`、`progress.md` 到 Wave 83–86 新执行目标
- 下一步将拉起 gpt-5.4 Worker A / Worker B 并行实施，再由主控做集成与 focused/full verification
- Files created/modified:
  - `docs/plans/2026-04-14-lazarus-manager-catalog-surface-wave.md` (created)
  - `docs/plans/2026-04-14-lazarus-manager-maintenance-surface-wave.md` (created)
  - `docs/plans/2026-04-14-cross-manager-install-support-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 78: 2026-04-14 Follow-up Wave Pack Planning
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 重新读取 `task_plan.md`、`findings.md`、`progress.md` 与刚完成的 `fpc.source/fpc.builder/build.manager` 收口结果
  - 基于真实源码再次实扫 `src/fpdev.fpc.manager.pas`、`src/fpdev.resource.repo.pas`、`src/fpdev.lazarus.source.pas`、`src/fpdev.lazarus.manager.pas`
  - 发现先前口头排序需要微调：`fpc.manager` 已明显变薄，而 `lazarus.manager` 仍留有 list/default/current/info surface，`resource.repo` 则剩余 mirror facade glue
  - 新增三份 follow-up 正式计划文档：
    - `docs/plans/2026-04-14-fpc-manager-verify-surface-wave.md`
    - `docs/plans/2026-04-14-resource-repo-mirror-surface-wave.md`
    - `docs/plans/2026-04-14-lazarus-manager-version-surface-wave.md`
  - 同步 `task_plan.md`、`findings.md`、`progress.md` 到新的真实执行目标
- 下一步将按这三份计划直接拉起 gpt-5.4 worker 并行实施
- Files created/modified:
  - `docs/plans/2026-04-14-fpc-manager-verify-surface-wave.md` (created)
  - `docs/plans/2026-04-14-resource-repo-mirror-surface-wave.md` (created)
  - `docs/plans/2026-04-14-lazarus-manager-version-surface-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 79: FPC Manager Verify Surface Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_fpc_manager_verify_boundary.py`，锁定 `VerifyInstallation(...)` 必须委托新的 verifyflow surface helper
  - 扩展 `tests/test_fpc_verify.lpr`，补 direct helper 覆盖，确认验证 callback / metadata persistence 组合编排不再留在 manager
  - 在 `src/fpdev.fpc.verifyflow.pas` 新增 `ExecuteManagedFPCVerificationSurfaceCore(...)`
  - 让 `src/fpdev.fpc.manager.pas` 的 `VerifyInstallation(...)` 收缩为 thin delegate
- Files created/modified:
  - `src/fpdev.fpc.verifyflow.pas`
  - `src/fpdev.fpc.manager.pas`
  - `tests/test_fpc_manager_verify_boundary.py`
  - `tests/test_fpc_verify.lpr`

### Phase 80: Resource Repo Mirror Surface Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_resource_repo_boundary.py`，锁定 `SelectBestMirror(...)` / `GetMirrors(...)` 必须委托新的 mirror surface helper
  - 新增 `tests/test_resource_repo_mirrorsurfaceflow.lpr`，直接覆盖 cache hit、fresh selection、state 回填与 exception fallback
  - 在 `src/fpdev.resource.repo.mirrorflow.pas` 新增：
    - `ExecuteResourceRepoSelectBestMirrorSurfaceCore(...)`
    - `ExecuteResourceRepoGetMirrorsSurfaceCore(...)`
  - 让 `src/fpdev.resource.repo.pas` 的 mirror facade 收缩为 thin delegate，同时保留 state ownership
- Files created/modified:
  - `src/fpdev.resource.repo.mirrorflow.pas`
  - `src/fpdev.resource.repo.pas`
  - `tests/test_resource_repo_boundary.py`
  - `tests/test_resource_repo_mirrorsurfaceflow.lpr` (created)

### Phase 81: Lazarus Manager Version Surface Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 新增 `tests/test_lazarus_manager_version_boundary.py`，锁定 manager 必须引入 `fpdev.lazarus.versionflow`
  - 新增 `tests/test_lazarus_versionflow.lpr`，直接覆盖 normalize/list/set-default/show-info surface
  - 新增 `src/fpdev.lazarus.versionflow.pas`
  - 让 `src/fpdev.lazarus.manager.pas` 的 `ListVersions(...)`、`SetDefaultVersion(...)`、`GetCurrentVersion(...)`、`ShowVersionInfo(...)` 收缩为 thin delegate
- Files created/modified:
  - `src/fpdev.lazarus.versionflow.pas` (created)
  - `src/fpdev.lazarus.manager.pas`
  - `tests/test_lazarus_manager_version_boundary.py` (created)
  - `tests/test_lazarus_versionflow.lpr` (created)

### Phase 82: Integration + Full Verification
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 复核 3 条 worker 改动的 helper/facade section，确认 `fpc.manager`、`resource.repo`、`lazarus.manager` 均按计划收缩
  - 运行 focused verification bundle，覆盖 boundary、direct helper、manager regression 与 CLI/Facade 相关 suite
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `307/307`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Session: 2026-04-13

### Phase 64: 2026-04-13 Next Hotspot Plan Pack
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 将 active goal 切到 `lazarus.source` runtime/config、`resource.repo` bootstrap surface、`fpc.manager` residual glue 这组三连 wave
  - 新增三份正式计划文档，固定实施顺序和 focused verification 清单
  - 同步 `task_plan.md`、`findings.md`、`progress.md`，把本轮从 checkpoint 重新切回 execution mode
- Files created/modified:
  - `docs/plans/2026-04-13-lazarus-source-runtime-config-wave.md` (created)
  - `docs/plans/2026-04-13-resource-bootstrap-surface-wave.md` (created)
  - `docs/plans/2026-04-13-fpc-residual-glue-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 65: Lazarus Source Runtime Config Wave
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 扩展 `tests/test_lazarus_source_boundary.py`，锁定 `fpdev.lazarus.source` 必须引入并委托 `fpdev.lazarus.sourceruntimeflow`
  - 新增 `tests/test_lazarus_sourceruntimeflow.lpr`，直接覆盖 runtime/config surface helper
  - 新增 `src/fpdev.lazarus.sourceruntimeflow.pas`
  - 让 `src/fpdev.lazarus.source.pas` 的 `ConfigureCustomFPCIDE(...)`、`ListLocalVersions(...)`、`BuildLazarus(...)`、`LaunchLazarus(...)` 收缩为 thin delegate
  - 跑通 focused 验证：boundary、direct helper、`test_lazarus_update.lpr`、`test_lazarus_flow.lpr`
- Files created/modified:
  - `src/fpdev.lazarus.sourceruntimeflow.pas` (created)
  - `src/fpdev.lazarus.source.pas`
  - `tests/test_lazarus_source_boundary.py`
  - `tests/test_lazarus_sourceruntimeflow.lpr` (created)

### Phase 66: Resource Bootstrap Surface Wave
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 扩展 `tests/test_resource_repo_boundary.py`，锁定 bootstrap/checksum/install surface 必须委托 `fpdev.resource.repo.bootstrapflow`
  - 新增 `tests/test_resource_repo_bootstrapflow.lpr`，直接覆盖 best-bootstrap selection、checksum helper 与 install surface preflight
  - 新增 `src/fpdev.resource.repo.bootstrapflow.pas`
  - 让 `src/fpdev.resource.repo.pas` 的 `FindBestBootstrapVersion(...)`、`VerifyChecksum(...)`、`InstallBootstrap(...)` 委托到 helper
  - 修复遗漏的 `InstallBootstrapWithInfo(...)` private bridge，消除 FPC focused suite 编译阻塞
  - 跑通 focused 验证：boundary、bootstrapflow、bootstrap、bootstrapquery
- Files created/modified:
  - `src/fpdev.resource.repo.bootstrapflow.pas` (created)
  - `src/fpdev.resource.repo.pas`
  - `tests/test_resource_repo_boundary.py`
  - `tests/test_resource_repo_bootstrapflow.lpr` (created)

### Phase 67: FPC Residual Glue Wave
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 新增 `tests/test_fpc_manager_residual_boundary.py`，锁定 `fpdev.fpc.manager` 必须委托 `fpdev.fpc.residualflow`
  - 新增 `tests/test_fpc_residualflow.lpr`，直接覆盖 setup environment 与 metadata persistence glue
  - 新增 `src/fpdev.fpc.residualflow.pas`
  - 让 `src/fpdev.fpc.manager.pas` 的 `SetupEnvironment(...)`、`WriteInstallMetadata(...)`、`UpdateVerificationMetadata(...)`、`RefreshInstallVerificationMetadata(...)` 改为 thin delegate
  - 跑通 focused 验证：boundary、direct helper、`test_fpc_manager_setupenvironment.lpr`、`test_fpc_manager_installmetadata.lpr`
- Files created/modified:
  - `src/fpdev.fpc.residualflow.pas` (created)
  - `src/fpdev.fpc.manager.pas`
  - `tests/test_fpc_manager_residual_boundary.py` (created)
  - `tests/test_fpc_residualflow.lpr` (created)

### Phase 68: Focused + Full Regression
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 重跑 resource 与 FPC focused suites，确认本轮 helper extraction 后 facade 行为保持稳定
  - 首次运行 `tests/test_fpc_installsurfaceflow.lpr` 时命中新 `/tmp` 输出目录缺失，补建目录后重新运行恢复为绿
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `300/300`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `src/fpdev.resource.repo.pas`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 61: Project Create Surface Wave
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 扩展 `tests/test_project_manager_boundary.py`，先用 RED 锁定 `project.manager` 仍未引入 `createflow` 且 `CreateFromTemplate(...)` / `CreateProject(...)` 仍保留 inline glue
  - 新增 `tests/test_project_createflow.lpr`，覆盖 template missing、目标目录创建、invalid-name rejection、setup warning success contract
  - 新增 `src/fpdev.project.createflow.pas`，承接 create-from-template 与 create orchestration
  - 让 `src/fpdev.project.manager.pas` 的 `CreateFromTemplate(...)` 与 `CreateProject(...)` 收缩为 thin delegate
- Files created/modified:
  - `docs/plans/2026-04-13-project-create-surface-wave.md` (created)
  - `src/fpdev.project.createflow.pas` (created)
  - `src/fpdev.project.manager.pas`
  - `tests/test_project_createflow.lpr` (created)
  - `tests/test_project_manager_boundary.py`

### Phase 62: Project Checkpoint + Final Regression
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 运行 project focused 验证：boundary、createflow direct helper、`test_project_management.lpr`、`test_project_commands.lpr`
  - 运行 `package.manager` 与 `cross.search` checkpoint，继续确认这两块仍适合作为 checkpoint 而非主切口
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `297/297`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 57: 2026-04-13 Follow-up Plan Pack
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 基于最新 helper 落地情况重新排序剩余 ROI，确认本轮最值得继续推进的是 `fpc.manager` maintenance surface、`lazarus.source` lifecycle、`resource.repo` package surface
  - 将 `package.manager` 与 `cross.search` 降为 checkpoint，避免对已明显变薄的 facade 机械继续深拆
  - 新增三份正式计划文档，并同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `docs/plans/2026-04-13-fpc-maintenance-surface-wave.md` (created)
  - `docs/plans/2026-04-13-lazarus-source-lifecycle-wave.md` (created)
  - `docs/plans/2026-04-13-resource-package-surface-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 58: FPC Maintenance + Lazarus Source Lifecycle Wave
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 延续本轮已开始的 FPC maintenance surface 实现，完成 `src/fpdev.fpc.maintenanceflow.pas` 提取，并让 `src/fpdev.fpc.manager.pas` 的 uninstall/update/clean 入口委托到 shared helper
  - 完成 `src/fpdev.lazarus.sourcelifecycleflow.pas` 提取，并让 `src/fpdev.lazarus.source.pas` 的 clone/update/switch/install 入口收缩为 thin delegate
  - 修复 `tests/test_lazarus_sourcelifecycleflow.lpr` 中过时的 `gbGit` 枚举引用，改为当前有效的 `gbCommandLine`，消除 direct helper 编译阻塞
  - 重新运行 Lazarus boundary/direct/regression，并在最终整仓回归中再次覆盖 `test_fpc_maintenanceflow` 与 `test_lazarus_sourcelifecycleflow`
- Files created/modified:
  - `src/fpdev.fpc.maintenanceflow.pas` (created)
  - `src/fpdev.fpc.manager.pas`
  - `src/fpdev.lazarus.sourcelifecycleflow.pas` (created)
  - `src/fpdev.lazarus.source.pas`
  - `tests/test_fpc_manager_maintenance_boundary.py` (created)
  - `tests/test_fpc_maintenanceflow.lpr` (created)
  - `tests/test_lazarus_source_boundary.py`
  - `tests/test_lazarus_sourcelifecycleflow.lpr` (created)

### Phase 59: Resource Package Surface + Package Checkpoint
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 先扩展 `tests/test_resource_repo_boundary.py` 并新增 `tests/test_resource_repo_packagesurfaceflow.lpr`，用 RED 锁定 `packageflow` helper 缺失与 facade 仍保留 inline glue 的事实
  - 新增 `src/fpdev.resource.repo.packageflow.pas`，承接 package info/list/search 的 repo-level facade orchestration
  - 让 `src/fpdev.resource.repo.pas` 的 `GetPackageInfo(...)` / `ListPackages(...)` / `SearchPackages(...)` 委托到 `ExecuteResourceRepoPackage*SurfaceCore(...)`
  - 运行 `package.manager` checkpoint，确认 install/update/dependency surface 继续保持 thin，不额外重开低 ROI helper
  - 为新 helper 与 direct test 补 `Result := nil` 初始化，清掉 managed-result warning
- Files created/modified:
  - `src/fpdev.resource.repo.packageflow.pas` (created)
  - `src/fpdev.resource.repo.pas`
  - `tests/test_resource_repo_boundary.py`
  - `tests/test_resource_repo_packagesurfaceflow.lpr` (created)

### Phase 60: Cross / Package / Release Checkpoint + Final Regression
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 运行 checkpoint：`python3 -m unittest tests.test_package_manager_boundary tests.test_resource_repo_boundary tests.test_cross_search_boundary tests.test_release_docs_contract -v`
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `296/296`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 52: Next Hotspot Re-Evaluation
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 重新读取 planning files、热点源码与 boundary tests，校验上一轮“下一步”假设是否仍然成立
  - 复核当前真实热点行数与剩余 inline 面，确认 `package.manager` 已明显变薄、release docs contract 已转绿
  - 将本轮实际切口重排为 `cross.search` orchestration、`fpc.manager` install surface、`project.UpdateTemplates`、`resource.repo` queryflow
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 53: 2026-04-13 Hotspot Plan Pack
- **Status:** complete
- **Started:** 2026-04-13
- Actions taken:
  - 新增三份正式计划文档，覆盖 cross / fpc / project+resource 三条执行线
  - 将 `package.manager` 与 release docs 明确降为 checkpoint，避免为“全部推进”打开低收益伪切口
  - 同步 `task_plan.md`、`findings.md`、`progress.md`，把本轮真实排序与 checkpoint 范围固定下来
- Files created/modified:
  - `docs/plans/2026-04-13-cross-search-orchestration-wave.md` (created)
  - `docs/plans/2026-04-13-fpc-install-surface-wave.md` (created)
  - `docs/plans/2026-04-13-project-resource-followup-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 54: Cross Search + FPC Install Surface Wave
- **Status:** complete
- Actions taken:
  - 为 `cross.search` 新增 `tests/test_cross_search_boundary.py` 与 `tests/test_cross_searchflow.lpr`，先用 RED 锁定 helper 缺失和委托边界
  - 新增 `src/fpdev.cross.searchflow.pas`，并让 `src/fpdev.cross.search.pas` 的 `SearchBinutilsWithConfig(...)` 委托到 `ExecuteCrossBinutilsSearchCore(...)`
  - 为 `fpc.manager` 新增 `tests/test_fpc_install_manager_boundary.py` 与 `tests/test_fpc_installsurfaceflow.lpr`，先用 RED 固化 install surface contract
  - 新增 `src/fpdev.fpc.installsurfaceflow.pas`，并让 `src/fpdev.fpc.manager.pas` 的 `InstallVersion(...)` 委托到 `ExecuteManagedFPCInstallSurfaceCore(...)`
  - 将 `tests/test_fpc_mock_helpers.pas` 在 Unix 上改为直接生成可执行 shell-script mock compiler，去掉对真实 `fpc` 的隐式依赖，稳定 `tests/test_fpc_manager_installmetadata.lpr`
  - 跑通 cross/fpc focused 验证与回归
- Files created/modified:
  - `src/fpdev.cross.searchflow.pas` (created)
  - `src/fpdev.cross.search.pas`
  - `src/fpdev.fpc.installsurfaceflow.pas` (created)
  - `src/fpdev.fpc.manager.pas`
  - `tests/test_cross_search_boundary.py`
  - `tests/test_cross_searchflow.lpr` (created)
  - `tests/test_fpc_install_manager_boundary.py`
  - `tests/test_fpc_installsurfaceflow.lpr` (created)
  - `tests/test_fpc_mock_helpers.pas`

### Phase 55: Project Update + Resource Query Follow-Up
- **Status:** complete
- Actions taken:
  - 扩展 `src/fpdev.project.templateflow.pas`，新增 `ExecuteProjectTemplateUpdateCore(...)`，把 `UpdateTemplates(...)` 的 repo update / local fallback / reporting orchestration 下沉到 shared flow
  - 让 `src/fpdev.project.manager.pas` 的 `UpdateTemplates(...)` 收缩为 thin delegate，并保持 repo 创建与异常包装仍在 manager
  - 新增 `src/fpdev.resource.repo.queryflow.pas`，统一承接 manifest-guarded bool / info / string / string-array query wrapper
  - 让 `src/fpdev.resource.repo.pas` 的 bootstrap / binary / cross queries 改为 thin delegate 到 query helper
  - 跑通 project/resource focused tests，并把 `package.manager` + release docs 作为 checkpoint 继续保持为绿
- Files created/modified:
  - `src/fpdev.project.templateflow.pas`
  - `src/fpdev.project.manager.pas`
  - `src/fpdev.resource.repo.queryflow.pas` (created)
  - `src/fpdev.resource.repo.pas`
  - `tests/test_project_manager_boundary.py`
  - `tests/test_project_templateflow.lpr`
  - `tests/test_resource_repo_boundary.py`
  - `tests/test_resource_repo_queryflow.lpr` (created)

### Phase 56: Package / Release Checkpoint + Final Regression
- **Status:** complete
- Actions taken:
  - 复核 `src/fpdev.package.manager.pas` 当前已足够 thin，本轮不为了“全部做好”再强开低收益 helper
  - 运行 checkpoint：`python3 -m unittest tests.test_package_manager_boundary tests.test_release_docs_contract -v`
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `293/293`，并同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Session: 2026-04-12

### Phase 49: Next Hotspot Re-Evaluation
- **Status:** complete
- **Started:** 2026-04-12
- Actions taken:
  - 重新读取 planning files 与当前热点源码，确认上一轮假设已经过时
  - 校验 `fpc.manager` 的 source/info facade 与 `lazarus.source` 的首刀 `sourceflow` 已提前落地，不重复打开旧切口
  - 将本轮真实切口重排为 `cross.search` diagnose/log、`fpc.manager` index cleanup、`lazarus.source` versionflow
  - 新增三份正式 plan 文档，供本轮直接执行
- Files created/modified:
  - `docs/plans/2026-04-12-cross-search-diagnose-wave.md` (created)
  - `docs/plans/2026-04-12-fpc-manager-index-cleanup-wave.md` (created)
  - `docs/plans/2026-04-12-lazarus-source-versionflow-wave.md` (created)

### Phase 50: Cross Search Diagnose / FPC Index / Lazarus Source Versionflow Wave
- **Status:** complete
- Actions taken:
  - 为 `cross.search` 新增 `tests/test_cross_searchdiag.lpr`，并让 `src/fpdev.cross.search.pas` 的 diagnose/log helper 委托到 `src/fpdev.cross.searchdiag.pas`
  - 为 `fpc.manager` 新增 `tests/test_fpc_manager_index_boundary.py` 与 `tests/test_fpc_indexflow.lpr`，通过 RED/GREEN 提取 `src/fpdev.fpc.indexflow.pas`
  - 删除 `src/fpdev.fpc.manager.pas` 中与 index/update 流程相关的 dead duplicate helper 和私有日志常量
  - 为 `lazarus.source` 新增 `tests/test_lazarus_sourceversionflow.lpr`，并让 `src/fpdev.lazarus.source.pas` 的 static version/description/available-version 逻辑委托到 `src/fpdev.lazarus.sourceversionflow.pas`
  - 修复 `LAZARUS_VERSIONS` 静态数组常量与 helper dynamic-array 形参不兼容的问题，改为 open-array contract
  - 为 `tests/test_lazarus_sourceversionflow.lpr` 的 `BuildStaticVersions` 补 `Result := nil`，清掉 managed-result warning
- Files created/modified:
  - `src/fpdev.cross.searchdiag.pas` (created)
  - `src/fpdev.cross.search.pas`
  - `src/fpdev.fpc.indexflow.pas` (created)
  - `src/fpdev.fpc.manager.pas`
  - `src/fpdev.lazarus.sourceversionflow.pas` (created)
  - `src/fpdev.lazarus.source.pas`
  - `tests/test_cross_search_boundary.py`
  - `tests/test_cross_searchdiag.lpr` (created)
  - `tests/test_fpc_manager_index_boundary.py` (created)
  - `tests/test_fpc_indexflow.lpr` (created)
  - `tests/test_lazarus_source_boundary.py`
  - `tests/test_lazarus_sourceversionflow.lpr` (created)

### Phase 51: Final Regression & Planning Sync
- **Status:** complete
- Actions taken:
  - 重新运行 `tests.test_lazarus_source_boundary`、`tests/test_lazarus_sourceversionflow.lpr` 与 `tests/test_lazarus_update.lpr`，确认 open-array 修复后 focused 验证全部通过
  - 运行 `bash scripts/run_all_tests.sh`
  - 记录整仓结果 `290/290`
  - 同步 `task_plan.md`、`findings.md`、`progress.md` 到当前真实状态
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 47: Next Hotspot Selection
- **Status:** complete
- **Started:** 2026-04-12
- Actions taken:
  - 重新读取 planning files 与当前热点源码，确认上一轮 `project/package` 的部分 helper 已提前落地
  - 将原先的 follow-up 假设改写为当前真实状态下的三刀：`cross.search`、`project execution surface`、`package tail facade`
  - 新增三份正式 plan 文档，供本轮直接执行
- Files created/modified:
  - `docs/plans/2026-04-12-cross-search-paths-wave.md` (created)
  - `docs/plans/2026-04-12-project-exec-surface-wave.md` (created)
  - `docs/plans/2026-04-12-package-tail-facade-wave.md` (created)

### Phase 48: Cross Search / Project Exec / Package Tail Wave
- **Status:** complete
- Actions taken:
  - 为 `cross.search` 新增 `tests/test_cross_search_boundary.py` 与 `tests/test_cross_searchpaths.lpr`，先用 RED 锁定 helper 缺失与委托边界
  - 新增 `src/fpdev.cross.searchpaths.pas`，承接 prefix candidate 与 library candidate 构建；`src/fpdev.cross.search.pas` 改为 thin delegate
  - 为 `project` 新增 `tests/test_project_exec_boundary.py` 与 `tests/test_project_cleanflow.lpr`，先用 RED 锁定 clean helper 缺失
  - 新增 `src/fpdev.project.cleanflow.pas`，并让 `src/fpdev.project.manager.pas` 的 `CleanProject(...)` 委托到 `ExecuteProjectCleanCore(...)`
  - 为 `package` 新增 `tests/test_package_tail_boundary.py`，并把 `tests/test_package_facadeflow.lpr` 改成 plain-function shim callback 形态，先用编译失败确认 RED
  - 收紧 `src/fpdev.package.facadeflow.pas` 的纯 helper callback contract，删除 `src/fpdev.package.manager.pas` 中 4 个纯 wrapper，并直接传 core helper
  - 跑通 cross/project/package focused 验证与整仓回归
- Files created/modified:
  - `src/fpdev.cross.searchpaths.pas` (created)
  - `src/fpdev.cross.search.pas`
  - `src/fpdev.project.cleanflow.pas` (created)
  - `src/fpdev.project.manager.pas`
  - `src/fpdev.package.facadeflow.pas`
  - `src/fpdev.package.manager.pas`
  - `tests/test_cross_search_boundary.py` (created)
  - `tests/test_cross_searchpaths.lpr` (created)
  - `tests/test_project_exec_boundary.py` (created)
  - `tests/test_project_cleanflow.lpr` (created)
  - `tests/test_package_tail_boundary.py` (created)
  - `tests/test_package_facadeflow.lpr`

### Phase 44: Project Manager Slicing Wave
- **Status:** complete
- **Started:** 2026-04-12
- Actions taken:
  - 承接已有 plan 和上一轮已完成的 project wave 实现结果，确认本轮 project 切口保持在 template lifecycle/presentation
  - 校验 `src/fpdev.project.templateflow.pas` 已承接 template list/info/install/remove/update-sync
  - 复核 `tests/test_project_manager_boundary.py`、`tests/test_project_templateflow.lpr` 与 `tests/test_project_template_commands.lpr` 的 focused 通过状态
- Files created/modified:
  - `src/fpdev.project.templateflow.pas`
  - `src/fpdev.project.manager.pas`
  - `tests/test_project_manager_boundary.py`
  - `tests/test_project_templateflow.lpr`

### Phase 45: Package Resource Hotspot Wave
- **Status:** complete
- Actions taken:
  - 先运行 `tests.test_package_manager_boundary` / `tests.test_resource_repo_boundary` 与 `tests/test_package_resource_flow.lpr`，确认 helper 接线后的真实失败面
  - 为 `src/fpdev.package.managerflow.pas` 补上 direct helper 兼容 overload，保持 manager callback 版本与 direct test 版本同时可用
  - 为 `src/fpdev.resource.repo.mirrorflow.pas` 补初始化，消除 managed result warning
  - 跑通 package/resource focused 验证与回归
- Files created/modified:
  - `src/fpdev.package.managerflow.pas`
  - `src/fpdev.resource.repo.mirrorflow.pas`
  - `src/fpdev.package.manager.pas`
  - `src/fpdev.resource.repo.pas`
  - `tests/test_package_manager_boundary.py`
  - `tests/test_resource_repo_boundary.py`
  - `tests/test_package_resource_flow.lpr`

### Phase 46: Cross Manager Flow Wave
- **Status:** complete
- Actions taken:
  - 先新增 `tests/test_cross_manager_boundary.py` 与 `tests/test_cross_managerflow.lpr`
  - 通过 RED 证据确认 `fpdev.cross.managerflow` 缺失且 manager 仍保留 inline list/show/update/clean orchestration
  - 新增 `src/fpdev.cross.managerflow.pas`
  - 让 `src/fpdev.cross.manager.pas` 的 `ListTargets(...)` / `ShowTargetInfo(...)` / `UpdateTarget(...)` / `CleanTarget(...)` 委托到 shared helper，同时保留默认 console output fallback
  - 重新编译 direct helper 测试并清理 `tests/test_cross_managerflow.lpr` 中的 managed result warning
  - 跑通 focused 验证与现有 cross 回归
- Files created/modified:
  - `src/fpdev.cross.managerflow.pas` (created)
  - `src/fpdev.cross.manager.pas`
  - `tests/test_cross_manager_boundary.py` (created)
  - `tests/test_cross_managerflow.lpr` (created)

### Phase 47: Final Regression & Planning Sync
- **Status:** complete
- Actions taken:
  - 运行 `bash scripts/run_all_tests.sh`
  - 记录整仓结果 `285/285`
  - 同步 `task_plan.md`、`findings.md`、`progress.md` 到当前真实状态
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Lazarus source boundary | `python3 -m unittest tests.test_lazarus_source_boundary -v` | pass after versionflow delegation | 7 tests, OK | OK |
| Lazarus sourceversionflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceversionflow-bin -FU/tmp/fpdev-lazarus-sourceversionflow-lib tests/test_lazarus_sourceversionflow.lpr && /tmp/fpdev-lazarus-sourceversionflow-bin/test_lazarus_sourceversionflow` | pass | 12 passed, 0 failed | OK |
| Lazarus update regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr && /tmp/fpdev-lazarus-update-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 290 passed, 0 failed | OK |
| Cross search boundary RED | `python3 -m unittest tests.test_cross_search_boundary -v` | fail before helper extraction | 3 failures: missing `fpdev.cross.searchpaths` and missing delegation | FAIL |
| Cross searchpaths RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchpaths-bin-red -FU/tmp/fpdev-cross-searchpaths-lib-red tests/test_cross_searchpaths.lpr` | fail before helper extraction | `Can't find unit fpdev.cross.searchpaths` | FAIL |
| Cross search boundary GREEN | `python3 -m unittest tests.test_cross_search_boundary -v` | pass | 3 tests, OK | OK |
| Cross searchpaths direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-searchpaths-bin -FU/tmp/fpdev-cross-searchpaths-lib tests/test_cross_searchpaths.lpr && bash -lc /tmp/fpdev-cross-searchpaths-bin/test_cross_searchpaths` | pass | 12 passed, 0 failed | OK |
| Cross search regressions | `tests/test_cross_search.lpr` + `tests/test_cross_search_libs.lpr` | pass | 50 passed, 0 failed / 25 passed, 0 failed | OK |
| Project exec boundary RED | `python3 -m unittest tests.test_project_exec_boundary -v` | fail before clean helper extraction | 2 failures: missing `fpdev.project.cleanflow` and missing clean delegation | FAIL |
| Project cleanflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-cleanflow-bin-red -FU/tmp/fpdev-project-cleanflow-lib-red tests/test_project_cleanflow.lpr` | fail before clean helper extraction | `Can't find unit fpdev.project.cleanflow` | FAIL |
| Project exec boundary GREEN | `python3 -m unittest tests.test_project_exec_boundary -v` | pass | 3 tests, OK | OK |
| Project cleanflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-cleanflow-bin -FU/tmp/fpdev-project-cleanflow-lib tests/test_project_cleanflow.lpr && bash -lc /tmp/fpdev-project-cleanflow-bin/test_project_cleanflow` | pass | 13 passed, 0 failed | OK |
| Project exec regressions | `tests/test_project_execflow.lpr` / `tests/test_project_run.lpr` / `tests/test_project_test.lpr` / `tests/test_project_clean.lpr` | pass | 26 passed, 0 failed / passed with skips / passed / passed | OK |
| Package tail boundary RED | `python3 -m unittest tests.test_package_tail_boundary -v` | fail before wrapper removal | 2 failures: manager still declares wrapper and does not pass core helpers directly | FAIL |
| Package facadeflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-facadeflow-bin-red -FU/tmp/fpdev-package-facadeflow-lib-red tests/test_package_facadeflow.lpr` | fail before callback contract change | 5 callback type mismatch errors (`of object` vs plain function) | FAIL |
| Package tail boundary GREEN | `python3 -m unittest tests.test_package_tail_boundary -v` | pass | 3 tests, OK | OK |
| Package facadeflow GREEN | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-facadeflow-bin -FU/tmp/fpdev-package-facadeflow-lib tests/test_package_facadeflow.lpr && bash -lc /tmp/fpdev-package-facadeflow-bin/test_package_facadeflow` | pass | 25 passed, 0 failed | OK |
| Package create + metadata writer | `tests/test_package_create.lpr` / `tests/test_package_metadata_writer.lpr` | pass | 39 passed, 0 failed / 55 assertions passed | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 287 passed, 0 failed | OK |
| Package/resource boundary | `python3 -m unittest tests.test_package_manager_boundary tests.test_resource_repo_boundary -v` | pass after helper wiring | 6 tests, OK | OK |
| Package/resource direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-resource-bin -FU/tmp/fpdev-package-resource-lib tests/test_package_resource_flow.lpr && bash -lc /tmp/fpdev-package-resource-bin/test_package_resource_flow` | pass | 23 passed, 0 failed | OK |
| Package manager regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-installupdate-bin -FU/tmp/fpdev-package-installupdate-lib tests/test_package_manager_installupdateflow.lpr && bash -lc /tmp/fpdev-package-installupdate-bin/test_package_manager_installupdateflow` | pass | 27 passed, 0 failed | OK |
| Resource repo mirror regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-mirror-bin -FU/tmp/fpdev-resource-mirror-lib tests/test_resource_repo_mirror.lpr && bash -lc /tmp/fpdev-resource-mirror-bin/test_resource_repo_mirror` | pass | 34 passed, 0 failed | OK |
| Lazarus source boundary | `python3 -m unittest tests.test_lazarus_source_boundary -v` | pass after lifecycle delegation | 9 tests, OK | OK |
| Lazarus sourcelifecycleflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourcelifecycleflow-bin -FU/tmp/fpdev-lazarus-sourcelifecycleflow-lib tests/test_lazarus_sourcelifecycleflow.lpr && bash -lc /tmp/fpdev-lazarus-sourcelifecycleflow-bin/test_lazarus_sourcelifecycleflow` | pass | 18 passed, 0 failed | OK |
| Lazarus update regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr && bash -lc /tmp/fpdev-lazarus-update-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| Lazarus flow regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr && bash -lc /tmp/fpdev-lazarus-flow-bin/test_lazarus_flow` | pass | 37 passed, 0 failed | OK |
| Resource package boundary RED | `python3 -m unittest tests.test_resource_repo_boundary -v` | fail before helper extraction | 2 failures: missing `fpdev.resource.repo.packageflow` and missing package surface delegation | FAIL |
| Resource packagesurfaceflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-packagesurfaceflow-bin-red -FU/tmp/fpdev-resource-packagesurfaceflow-lib-red tests/test_resource_repo_packagesurfaceflow.lpr` | fail before helper extraction | `Can't find unit fpdev.resource.repo.packageflow` | FAIL |
| Resource/package boundary GREEN | `python3 -m unittest tests.test_resource_repo_boundary tests.test_package_manager_boundary -v` | pass | 11 tests, OK | OK |
| Resource packagesurfaceflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-packagesurfaceflow-bin -FU/tmp/fpdev-resource-packagesurfaceflow-lib tests/test_resource_repo_packagesurfaceflow.lpr && bash -lc /tmp/fpdev-resource-packagesurfaceflow-bin/test_resource_repo_packagesurfaceflow` | pass | 11 passed, 0 failed | OK |
| Resource repo query regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-query-bin -FU/tmp/fpdev-resource-query-lib tests/test_resource_repo_query.lpr && bash -lc /tmp/fpdev-resource-query-bin/test_resource_repo_query` | pass | 9 passed, 0 failed | OK |
| Final checkpoint suite | `python3 -m unittest tests.test_package_manager_boundary tests.test_resource_repo_boundary tests.test_cross_search_boundary tests.test_release_docs_contract -v` | pass | 30 tests, OK | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 296 passed, 0 failed | OK |
| Project manager boundary RED | `python3 -m unittest tests.test_project_manager_boundary -v` | fail before helper extraction | 2 failures: missing `fpdev.project.createflow` and missing create surface delegation | FAIL |
| Project createflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-createflow-bin-red -FU/tmp/fpdev-project-createflow-lib-red tests/test_project_createflow.lpr` | fail before helper extraction | `Can't find unit fpdev.project.createflow` | FAIL |
| Project manager boundary GREEN | `python3 -m unittest tests.test_project_manager_boundary -v` | pass | 5 tests, OK | OK |
| Project createflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-createflow-bin -FU/tmp/fpdev-project-createflow-lib tests/test_project_createflow.lpr && bash -lc /tmp/fpdev-project-createflow-bin/test_project_createflow` | pass | 12 passed, 0 failed | OK |
| Project management regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-management-bin -FU/tmp/fpdev-project-management-lib tests/test_project_management.lpr && bash -lc /tmp/fpdev-project-management-bin/test_project_management` | pass | 14 passed, 0 failed | OK |
| Project commands regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-commands-bin -FU/tmp/fpdev-project-commands-lib tests/test_project_commands.lpr && bash -lc /tmp/fpdev-project-commands-bin/test_project_commands` | pass | 11 passed, 0 failed | OK |
| Project/package/cross checkpoint | `python3 -m unittest tests.test_project_manager_boundary tests.test_package_manager_boundary tests.test_cross_search_boundary -v` | pass | 16 tests, OK | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 297 passed, 0 failed | OK |
| Cross manager boundary RED | `python3 -m unittest tests.test_cross_manager_boundary -v` | fail before helper extraction | 3 failures: missing `fpdev.cross.managerflow` and missing delegation | FAIL |
| Cross managerflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin-red -FU/tmp/fpdev-cross-managerflow-lib-red tests/test_cross_managerflow.lpr` | fail before helper extraction | `Can't find unit fpdev.cross.managerflow` | FAIL |
| Cross manager boundary GREEN | `python3 -m unittest tests.test_cross_manager_boundary -v` | pass | 3 tests, OK | OK |
| Cross managerflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin -FU/tmp/fpdev-cross-managerflow-lib tests/test_cross_managerflow.lpr && bash -lc /tmp/fpdev-cross-managerflow-bin/test_cross_managerflow` | pass | 36 passed, 0 failed | OK |
| Cross targetflow regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-targetflow-bin -FU/tmp/fpdev-cross-targetflow-lib tests/test_cross_targetflow.lpr && bash -lc /tmp/fpdev-cross-targetflow-bin/test_cross_targetflow` | pass | 25 passed, 0 failed | OK |
| Cross management regression | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-management-bin -FU/tmp/fpdev-cross-management-lib tests/test_cross_management.lpr && bash -lc /tmp/fpdev-cross-management-bin/test_cross_management` | pass | 32 passed, 0 failed | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 285 passed, 0 failed | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-12 | `tests/test_lazarus_update.lpr` compile failed because `LAZARUS_VERSIONS` is a static array constant while `fpdev.lazarus.sourceversionflow` initially expected a dynamic array | 1 | Changed the helper signatures in `src/fpdev.lazarus.sourceversionflow.pas` to open-array parameters so both static constants and dynamic test arrays are accepted |
| 2026-04-12 | `tests/test_cross_searchpaths.lpr` 初版把 dedupe 断言写成 `Length(Libs) = 1`，在宿主机存在额外 system cross libs 时失败 | 1 | 收紧为“shared dir 排第一且只出现一次”，保留真实 contract |
| 2026-04-12 | `tests/test_package_facadeflow.lpr` compile failed because shim callbacks were plain functions while `facadeflow` 仍要求 `of object` | 1 | 将 `src/fpdev.package.facadeflow.pas` 中纯 helper callback 改为 plain function，并删除 manager 尾部 wrapper |
| 2026-04-12 | `tests/test_package_resource_flow.lpr` compile failed because `ExecutePackageInstallFromSourceCore(...)` lacked the direct-test overload | 1 | Added a simplified overload in `src/fpdev.package.managerflow.pas` while keeping the manager callback version |
| 2026-04-12 | `fpc ... tests/test_cross_managerflow.lpr` initially failed because `fpdev.cross.managerflow` did not exist | 1 | Implemented `src/fpdev.cross.managerflow.pas` and rewired `src/fpdev.cross.manager.pas` |
| 2026-04-13 | `tests/test_lazarus_sourcelifecycleflow.lpr` compile failed because it still used removed enum value `gbGit` | 1 | Replaced the stale enum usage with `gbCommandLine` and reran the helper/regression suite |
| 2026-04-13 | `tests/test_resource_repo_boundary.py` / `tests/test_resource_repo_packagesurfaceflow.lpr` failed because `fpdev.resource.repo.packageflow` did not exist and package facade glue was still inline | 1 | Added `src/fpdev.resource.repo.packageflow.pas`, rewired `src/fpdev.resource.repo.pas`, and reran focused + full verification |

## Session: 2026-03-27

### Phase 1: Requirements & Discovery
- **Status:** complete (superseded by later review/closeout phases)
- **Started:** 2026-03-27
- Actions taken:
  - Read relevant workflow skills for review and roadmap assessment
  - Initialized project-local planning files
  - Attempted semantic codebase retrieval and recorded fallback
- Files created/modified:
  - `task_plan.md` (created)
  - `findings.md` (created)
  - `progress.md` (created)

### Phase 2: Repository Review
- **Status:** complete
- Actions taken:
  - Reviewed entrypoint, CLI bootstrap, command import topology, config manager split, test scripts, roadmap and release docs
  - Ran representative quality and contract checks
  - Built release binary and ran CLI smoke
- Files created/modified:
  - `findings.md`
  - `progress.md`
  - `task_plan.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Tooling discovery | `mcp__ace_tool__search_context` | Return repository map | HTTP 499 | blocked |
| Test inventory sync | `python3 scripts/update_test_stats.py --check` | pass | pass | OK |
| Test stats unit tests | `python3 -m unittest tests.test_update_test_stats` | pass | pass | OK |
| Release docs contract | `python3 -m unittest tests.test_run_all_tests tests.test_release_docs_contract tests.test_official_docs_cli_contract` | pass | 2 failures in `tests.test_release_docs_contract` | FAIL |
| Toolchain baseline | `bash scripts/check_toolchain.sh` | pass | pass | OK |
| Release build | `lazbuild -B --build-mode=Release fpdev.lpi` | pass | pass | OK |
| CLI smoke | `bash scripts/cli_smoke.sh ./bin/fpdev` | pass | pass | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-03-27 | `mcp__ace_tool__search_context` HTTP 499 | 1 | Fallback to shell-based repository inspection |
| 2026-03-27 | `python3 -m pytest ...` failed because `pytest` is unavailable | 1 | Switched to repository-standard `unittest` execution |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4 synthesis |
| Where am I going? | Finalize review findings and prioritized recommendations |
| What's the goal? | Produce project review, development suggestions, and roadmap assessment |
| What have I learned? | Release doc contract drift is the clearest current regression; build/smoke remain healthy |
| What have I done? | Completed repository inspection, ran representative checks, and recorded evidence |

## Session: 2026-04-02

### Phase 4: Synthesis
- **Status:** complete (superseded by later implementation/closeout phases)
- **Started:** 2026-04-02
- Actions taken:
  - Reused prior repository review context and refreshed planning files for the narrower “biggest problem” question
  - Re-ran semantic codebase retrieval successfully and cross-checked local evidence with exact shell metrics
  - Re-ran `python3 -m unittest tests.test_release_docs_contract -v` and confirmed 2 current failures in release-owner-checkpoint documentation
  - Measured current churn (`279` working tree changes) and identified large migration hotspots in command and git layers
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Release docs contract (current) | `python3 -m unittest tests.test_release_docs_contract -v` | pass | 2 failures (`record_owner_smoke` refs and owner smoke filenames missing) | FAIL |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `git status --short | python3 - <<'PY' ...` caused `IndentationError` | 1 | Re-ran with `python3 -c` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4 synthesis |
| Where am I going? | Finalize the single biggest-problem diagnosis and explain why it outranks other issues |
| What's the goal? | Produce an evidence-backed judgment about FPDev’s biggest current problem |
| What have I learned? | The strongest issue is a mismatch between claimed completion and presently verifiable release/readiness state, amplified by unfinished architecture migration |
| What have I done? | Refreshed evidence, rechecked failing contract tests, and measured current code/working-tree hotspots |

## Session: 2026-04-09

### Phase 1: Recovery & Diagnosis
- **Status:** complete
- **Started:** 2026-04-09
- Actions taken:
  - Read `using-superpowers`, `planning-with-files`, `test-driven-development`, and `systematic-debugging` skills to recover the correct workflow
  - Ran session catch-up, re-read `task_plan.md`, `findings.md`, and `progress.md`
  - Inspected current diffs in `tests/test_ci_workflow_contract.py` and `tests/test_release_scripts_contract.py`
  - Reproduced focused failures with `python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract -v`
  - Confirmed the shared bundle assembly script is missing and CI still contains the old inline assembly/evidence logic
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Implementation
- **Status:** complete
- Actions taken:
  - Added `scripts/assemble_release_ready_bundle.sh` as the shared bundle assembly entrypoint
  - Moved the existing CI inline release bundle logic into the new script
  - Updated `.github/workflows/ci.yml` to call the shared script instead of duplicating checksum/evidence steps inline
  - Adjusted the new script to use explicit baseline/install summary lookup so it matches the contract wording
- Files created/modified:
  - `scripts/assemble_release_ready_bundle.sh` (created)
  - `.github/workflows/ci.yml`

## Session: 2026-04-11

### Phase 39: Hotspot Roadmap Reset
- **Status:** complete
- **Started:** 2026-04-11
- Actions taken:
  - Re-read workflow skills and当前 planning files，确认需要从已收口的 Lazarus manager 线切换到新的 hotspot 主线
  - 重新扫描 `src/` 大文件与 FPC manager 现有 helper 复用面
  - 确认 `GetStatus(...)` 是 `src/fpdev.fpc.manager.pas` 当前最值得抽离的下一刀
  - 新增总路线图与 FPC manager statusflow 详细计划文档
- Files created/modified:
  - `docs/plans/2026-04-11-manager-hotspot-roadmap.md` (created)
  - `docs/plans/2026-04-11-fpc-manager-statusflow-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 40: FPC Manager Statusflow Wave
- **Status:** complete
- Actions taken:
  - 新增 `tests/test_fpc_manager_status_boundary.py`，先把 `fpdev.fpc.manager` 必须委托 `fpdev.fpc.statusflow` 的边界锁红
  - 新增 `tests/test_fpc_statusflow.lpr`，为 status helper 写 direct RED 覆盖
  - 新增 `src/fpdev.fpc.statusflow.pas`
  - 将 `src/fpdev.fpc.manager.pas` 的 `GetStatus(...)` 改为委托 `BuildManagedFPCStatusCore(...)`
  - 新增静默 callback `TryReadStatusMetadata(...)`，避免 status 命令在 metadata 缺失时产生额外错误输出
  - 更新 `docs/history/B171-large-files-report.md` 与 `tests/test_contributor_docs_contract.py`
- Files created/modified:
  - `src/fpdev.fpc.statusflow.pas` (created)
  - `src/fpdev.fpc.manager.pas`
  - `tests/test_fpc_manager_status_boundary.py` (created)
  - `tests/test_fpc_statusflow.lpr` (created)
  - `docs/history/B171-large-files-report.md`
  - `tests/test_contributor_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Manager status boundary RED | `python3 -m unittest tests.test_fpc_manager_status_boundary -v` | fail before helper extraction | 3 failures: missing `fpdev.fpc.statusflow`, missing shared flow call, and inline status orchestration still present | FAIL |
| Statusflow helper RED | `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-fpc-statusflow-bin-red -FU/tmp/fpdev-fpc-statusflow-lib-red tests/test_fpc_statusflow.lpr` | fail before helper extraction | `Can't find unit fpdev.fpc.statusflow` | FAIL |
| Manager status boundary GREEN | `python3 -m unittest tests.test_fpc_manager_status_boundary -v` | pass | 3 tests, OK | OK |
| Statusflow direct helper | `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-fpc-statusflow-bin -FU/tmp/fpdev-fpc-statusflow-lib tests/test_fpc_statusflow.lpr && /tmp/fpdev-fpc-statusflow-bin/test_fpc_statusflow` | pass | 19 passed, 0 failed | OK |
| Status command focused suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-status-bin -FU/tmp/fpdev-fpc-status-lib tests/test_fpc_status.lpr && /tmp/fpdev-fpc-status-bin/test_fpc_status` | pass | 26 passed, 0 failed | OK |
| Contributor docs contract | `python3 -m unittest tests.test_contributor_docs_contract -v` | pass | 29 tests, OK | OK |
| B171 formatting | `bash scripts/run_prettier.sh --check docs/history/B171-large-files-report.md` | pass | all matched files use Prettier code style | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 280 passed, 0 failed | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-11 | `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/session-catchup.py` failed because `CLAUDE_PLUGIN_ROOT` is unset in this environment | 1 | Fell back to reading `task_plan.md` / `findings.md` / `progress.md` and checking `git diff --stat` manually |

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran `python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract -v`
  - Ran `bash -n scripts/assemble_release_ready_bundle.sh`
  - Reviewed the focused diff to confirm the workflow now calls the shared script and no unrelated release logic changed
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Release bundle contracts | `python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract -v` | pass | 4 failures tied to missing `scripts/assemble_release_ready_bundle.sh` and stale CI inline logic | FAIL |
| Release bundle contracts (after fix) | `python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract -v` | pass | 37 tests passed | OK |
| Shell syntax | `bash -n scripts/assemble_release_ready_bundle.sh` | pass | pass | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-09 | `sed -n '1,260p' scripts/assemble_release_ready_bundle.sh` failed: file missing | 1 | Confirmed as root cause for focused contract failures |
| 2026-04-09 | Focused contract suite still failed after first implementation because the script used parameterized `grep` text | 1 | Replaced with explicit baseline/install summary helpers and re-ran tests |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 2 implementation for release bundle recovery |
| Where am I going? | Ready to hand off or expand verification if needed |
| What's the goal? | Restore green release bundle contract coverage with minimal behavior-preserving changes |
| What have I learned? | The workflow logic already existed; extracting it to a shared script was sufficient |
| What have I done? | Recovered context, implemented the shared script, repointed CI, and re-ran focused verification successfully |

## Session: 2026-04-09 (post-release docs truth sync)

### Phase 1: Scope Confirmation
- **Status:** complete
- Actions taken:
  - Re-checked `docs/ROADMAP.md`, `docs/MVP_ACCEPTANCE_CRITERIA*.md`, and `docs/KNOWN_LIMITATIONS.md`
  - Confirmed the public roadmap already says `v2.1.0 Released`, while the acceptance matrix still reported Windows/macOS proof as `pending`
  - Confirmed `docs/KNOWN_LIMITATIONS.md` still used `版本 1.0.0` and an older pre-release framing
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Documentation Update
- **Status:** complete
- Actions taken:
  - Updated `docs/MVP_ACCEPTANCE_CRITERIA.md` and `docs/MVP_ACCEPTANCE_CRITERIA.en.md` to reflect published release proof state
  - Added published evidence pointers for the GitHub release assets and release-proof bundle handoff
  - Updated `docs/KNOWN_LIMITATIONS.md` to `v2.1.0` terminology and separated a resolved historical limitation from active ones
- Files created/modified:
  - `docs/MVP_ACCEPTANCE_CRITERIA.md`
  - `docs/MVP_ACCEPTANCE_CRITERIA.en.md`
  - `docs/KNOWN_LIMITATIONS.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Ran the release/contributor/docs taxonomy/readme contract suites
  - Reviewed the resulting diff to confirm the edits stayed within documentation truth sync scope
  - Recorded the `prettier` path-resolution issue and treated it as non-blocking after successful contract validation
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Docs contracts | `python3 -m unittest tests.test_release_docs_contract tests.test_contributor_docs_contract tests.test_docs_taxonomy_contract tests.test_readme_testing_contract -v` | pass | 42 tests passed | OK |

## Session: 2026-04-12

### Phase 41: Remaining Hotspot Plan Pack
- **Status:** complete
- **Started:** 2026-04-12
- Actions taken:
  - 新增 `docs/plans/2026-04-12-fpc-manager-versionflow-wave.md`
  - 新增 `docs/plans/2026-04-12-lazarus-source-slicing-wave.md`
  - 新增 `docs/plans/2026-04-12-project-manager-slicing-wave.md`
  - 新增 `docs/plans/2026-04-12-package-resource-hotspot-wave.md`
  - 新增 `docs/plans/2026-04-12-cross-manager-search-wave.md`
  - 将 manager hotspot 主线按下一批执行顺序写入 planning files
- Files created/modified:
  - `docs/plans/2026-04-12-fpc-manager-versionflow-wave.md` (created)
  - `docs/plans/2026-04-12-lazarus-source-slicing-wave.md` (created)
  - `docs/plans/2026-04-12-project-manager-slicing-wave.md` (created)
  - `docs/plans/2026-04-12-package-resource-hotspot-wave.md` (created)
  - `docs/plans/2026-04-12-cross-manager-search-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 42: FPC Manager Versionflow Wave
- **Status:** complete
- Actions taken:
  - 新增 `tests/test_fpc_manager_version_boundary.py` 锁定 `fpdev.fpc.manager` 对 `fpdev.fpc.versionflow` 的委托边界
  - 新增 `tests/test_fpc_versionflow.lpr`，为 version/default/activation helper 写 direct RED 覆盖
  - 新增 `src/fpdev.fpc.versionflow.pas`
  - 将 `src/fpdev.fpc.manager.pas` 的 `ListVersions(...)`、`SetDefaultVersion(...)`、`ActivateVersion(...)` 委托到 shared flow
  - 将 `src/fpdev.fpc.version.pas` 的 default toolchain normalization 复用到 shared helper
  - 追到真实编译阻塞点并做最小修复：把 `src/fpdev.fpc.version.pas` 与 `src/fpdev.fpc.activation.pas` 的重复类型改为 shared alias
  - 更新 `docs/history/B171-large-files-report.md` 记录 manager 最新行数与 `versionflow` helper
- Files created/modified:
  - `src/fpdev.fpc.versionflow.pas` (created)
  - `tests/test_fpc_manager_version_boundary.py` (created)
  - `tests/test_fpc_versionflow.lpr` (created)
  - `src/fpdev.fpc.manager.pas`
  - `src/fpdev.fpc.version.pas`
  - `src/fpdev.fpc.activation.pas`
  - `docs/history/B171-large-files-report.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Manager version boundary | `python3 -m unittest tests.test_fpc_manager_version_boundary -v` | pass | 4 tests, OK | OK |
| Versionflow direct helper | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-versionflow-bin -FU/tmp/fpdev-fpc-versionflow-lib tests/test_fpc_versionflow.lpr && /tmp/fpdev-fpc-versionflow-bin/test_fpc_versionflow` | pass | 17 passed, 0 failed | OK |
| FPC use focused suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-use-bin -FU/tmp/fpdev-fpc-use-lib tests/test_fpc_use.lpr && /tmp/fpdev-fpc-use-bin/test_fpc_use` | pass | 29 passed, 0 failed | OK |
| CLI FPC info focused suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-info-bin -FU/tmp/fpdev-fpc-info-lib tests/test_cli_fpc_info.lpr && /tmp/fpdev-fpc-info-bin/test_cli_fpc_info` | pass | 91 passed, 0 failed | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 281 passed, 0 failed | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-12 | `fpdev.fpc.manager.pas` 编译失败：`fpdev.fpc.version.TFPCVersionArray` / `fpdev.fpc.types.TFPCVersionArray` 不兼容 | 1 | 将 `src/fpdev.fpc.version.pas` 的版本类型改为 shared alias |
| 2026-04-12 | `fpdev.fpc.manager.pas` 编译失败：activation callback 的 `TActivationResult` 与 `versionflow` 期望类型不兼容 | 1 | 将 `src/fpdev.fpc.activation.pas` 的 `TActivationResult` 改为 shared alias |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 42 complete，进入下一波待执行状态 |
| Where am I going? | 切到 `docs/plans/2026-04-12-lazarus-source-slicing-wave.md` |
| What's the goal? | 继续削薄 manager/source hotspot，按既定 roadmap 前进 |
| What have I learned? | 当前更容易出问题的不是 helper 提取本身，而是历史重复类型在 facade/helper 交界处的编译边界漂移 |
| What have I done? | 完成 versionflow helper、修平共享类型边界、更新 hotspot 文档并跑通 281/281 全量回归 |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-09 | `yarn prettier --write docs/...` returned “No files matching the pattern were found” | 1 | Skipped formatter as a blocker and relied on passing docs contract tests plus diff review |

## Session: 2026-04-09 (cli flags split wave)

### Phase 1: Red Test Setup
- **Status:** complete
- Actions taken:
  - Re-read `docs/plans/2026-03-08-cli-flags-split-wave.md`
  - Inspected the current `fpdev.cli.global`, `fpdev.cli.runner`, and `tests/test_cli_misc.lpr` code paths
  - Added `fpdev.cli.flags` to `tests/test_cli_misc.lpr`
  - Verified RED with `Fatal: Can't find unit fpdev.cli.flags used by test_cli_misc`
- Files created/modified:
  - `tests/test_cli_misc.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Minimal Extraction
- **Status:** complete
- Actions taken:
  - Added `src/fpdev.cli.flags.pas` to own the remaining `--portable` preparse logic
  - Removed `ApplyPortableModeFromArgs` from `src/fpdev.cli.global.pas`
  - Updated `src/fpdev.cli.runner.pas` to use `fpdev.cli.flags`
  - Moved the flag-focused tests into `tests/test_cli_flags.inc`
- Files created/modified:
  - `src/fpdev.cli.flags.pas` (created)
  - `src/fpdev.cli.global.pas`
  - `src/fpdev.cli.runner.pas`
  - `tests/test_cli_flags.inc` (created)
  - `tests/test_cli_misc.lpr`

## Session: 2026-04-10 (final git compat shim removal)

### Phase 1: Red Boundary Update
- **Status:** complete
- Actions taken:
  - Re-read the breaking-removal plan and current `tests/test_git_runtime_boundary.py`
  - Updated the boundary suite so removal-complete state now requires:
    - `src/fpdev.utils.git.pas` to be absent
    - changelog and release notes to publish the breaking impact summary
    - migration and architecture docs to stop describing the shim as soft-deprecated
  - Re-ran `python3 -m unittest tests.test_git_runtime_boundary -v` and confirmed 13 focused failures before implementation
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Breaking Removal Implementation
- **Status:** complete
- Actions taken:
  - Deleted `src/fpdev.utils.git.pas`
  - Updated `docs/GIT_COMPAT_MIGRATION.md` to removal-complete wording
  - Added the breaking impact summary to `CHANGELOG.md` and `RELEASE_NOTES.md`
  - Updated `CLAUDE.md`, active docs, and selected history docs so their current-worktree notes now describe the shim as removed
  - Updated `tests/test_style_regressions_batch19.py` to stop referencing the deleted unit
- Files created/modified:
  - `src/fpdev.utils.git.pas` (deleted)
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `CHANGELOG.md`
  - `RELEASE_NOTES.md`
  - `CLAUDE.md`
  - `docs/ARCHITECTURE.md`
  - `docs/ARCHITECTURE.en.md`
  - `docs/GIT2_USAGE.md`
  - `docs/GIT2_USAGE.en.md`
  - `docs/LIBGIT2_INTEGRATION.md`
  - `docs/LIBGIT2_INTEGRATION.en.md`
  - `docs/history/B166-deprecated-cleanup.md`
  - `docs/history/DEPRECATED_CODE_AUDIT.md`

## Session: 2026-04-11 (lazarus manager follow-up waves)

### Phase 1: Planning & Rediscovery
- **Status:** complete
- **Started:** 2026-04-11
- Actions taken:
  - Re-read `writing-plans`, `executing-plans`, `planning-with-files`, `test-driven-development`, and `systematic-debugging`
  - Ran session catch-up and refreshed `task_plan.md`, `findings.md`, and `progress.md`
  - Re-scanned `src/fpdev.lazarus.manager.pas` and the existing Lazarus guardrail tests
  - Confirmed the next fixed route is `pathflow -> install callbacks -> runtime/IDE actions -> docs/contracts`
  - Wrote the formal follow-up plan to `docs/plans/2026-04-11-lazarus-manager-followup-waves.md`
- Files created/modified:
  - `docs/plans/2026-04-11-lazarus-manager-followup-waves.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Pathflow RED/GREEN
- **Status:** complete
- Actions taken:
  - Added `tests/test_lazarus_manager_path_boundary.py` and `tests/test_lazarus_pathflow.lpr`
  - Verified RED with missing-unit compile failure for `fpdev.lazarus.pathflow`
  - Created `src/fpdev.lazarus.pathflow.pas`
  - Switched `GetVersionInstallPath` / `GetExecutablePathFromInstallPath` / `GetResolvedInstallPath` / `IsVersionInstalled` to delegate to helper
  - Re-ran focused Python + Pascal + `tests/test_lazarus_configure_workflow.lpr`
- Files created/modified:
  - `src/fpdev.lazarus.pathflow.pas` (created)
  - `src/fpdev.lazarus.manager.pas`
  - `tests/test_lazarus_manager_path_boundary.py` (created)
  - `tests/test_lazarus_pathflow.lpr` (created)

### Phase 3: Install Callbacks RED/GREEN
- **Status:** complete
- Actions taken:
  - Added `tests/test_lazarus_manager_callbacks_boundary.py` and `tests/test_lazarus_installcallbacks.lpr`
  - Verified RED with missing-unit compile failure for `fpdev.lazarus.installcallbacks`
  - Created `src/fpdev.lazarus.installcallbacks.pas`
  - Moved `DownloadSource` / `BuildFromSource` / `SetupEnvironment` core logic to helper while keeping `RunConfigureIDEWithOutputs` as named callback adapter
  - Re-ran boundary suites, direct helper suite, and `tests/test_lazarus_update.lpr`
- Files created/modified:
  - `src/fpdev.lazarus.installcallbacks.pas` (created)
  - `src/fpdev.lazarus.manager.pas`
  - `tests/test_lazarus_manager_callbacks_boundary.py` (created)
  - `tests/test_lazarus_installcallbacks.lpr` (created)

### Phase 4: Runtime Actions RED/GREEN
- **Status:** complete
- Actions taken:
  - Added `tests/test_lazarus_manager_runtime_boundary.py` and `tests/test_lazarus_runtimeactions.lpr`
  - Verified RED with missing-unit compile failure for `fpdev.lazarus.runtimeactions`
  - Created `src/fpdev.lazarus.runtimeactions.pas`
  - Moved `TestInstallation` / `LaunchIDE` / `ConfigureIDE` execution logic to helper and left manager with thin wrappers plus callback adapter
  - Re-ran runtime boundary suite, direct helper suite, `tests/test_lazarus_configure_workflow.lpr`, and `tests/test_cli_lazarus.lpr`
- Files created/modified:
  - `src/fpdev.lazarus.runtimeactions.pas` (created)
  - `src/fpdev.lazarus.manager.pas`
  - `tests/test_lazarus_manager_runtime_boundary.py` (created)
  - `tests/test_lazarus_runtimeactions.lpr` (created)

### Phase 5: Docs Sync And Regression
- **Status:** complete
- Actions taken:
  - Updated `docs/history/B171-large-files-report.md` with the new Lazarus helper layout and current line counts
  - Updated `tests/test_contributor_docs_contract.py` to lock the new B171 truth
  - Ran `bash scripts/run_prettier.sh --write/--check docs/history/B171-large-files-report.md`
  - Re-ran focused Python suites, focused Pascal suites, docs contract, and full repository regression
- Files created/modified:
  - `docs/history/B171-large-files-report.md`
  - `tests/test_contributor_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 6: Final Verification Snapshot
- **Status:** complete
- Actions taken:
  - Confirmed `src/fpdev.lazarus.manager.pas` line count is now `841`
  - Confirmed focused verification is green across pathflow/installcallbacks/runtimeactions/docs contracts
  - Ran `bash scripts/run_all_tests.sh` and confirmed `279/279`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Git boundary suite
  - Ran the combined Python regression bundle for docs/tooling/runtime boundaries
  - Ran `tests.test_style_regressions_batch19`
  - Ran `bash scripts/run_prettier.sh --write ...` and `--check ...` sequentially
  - Compiled and ran focused Pascal suites in `/tmp`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary RED check | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail before removal | 13 failures covering shim existence, docs wording, and missing release-note summary | OK |
| Git boundary GREEN | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 35 tests passed | OK |
| Python regression bundle | `python3 -m unittest tests.test_run_prettier_sh tests.test_contributor_docs_contract tests.test_git_runtime_boundary -v` | pass | 64 tests passed | OK |
| Style regression batch 19 | `python3 -m unittest tests.test_style_regressions_batch19 -v` | pass | 3 tests passed | OK |
| Docs formatting write | `bash scripts/run_prettier.sh --write ...` | pass | pass | OK |
| Docs formatting check | `bash scripts/run_prettier.sh --check ...` | pass | pass | OK |
| Focused Pascal suite | `tests/test_git_operations.lpr` via `/tmp` build dirs | pass | 254 passed, 0 failed | OK |
| Focused Pascal suite | `tests/test_git_facade.lpr` via `/tmp` build dirs | pass | 124 passed, 0 failed | OK |
| Focused Pascal suite | `tests/test_fpc_builder.lpr` via `/tmp` build dirs | pass | 90 passed, 0 failed | OK |

## Session: 2026-04-10 (release status wording contract resync)

### Phase 1: Failure Triage
- **Status:** complete
- Actions taken:
  - Ran `python3 -m unittest discover -s tests -p 'test_*.py'`
  - Isolated 4 failures in `tests/test_release_status_wording.py`
  - Confirmed the failures were caused by stale expectations (`pending`, `required before publish`, `274 tests`) rather than document regressions
- Files created/modified:
  - `findings.md`
  - `progress.md`
  - `task_plan.md`

### Phase 2: Contract Update
- **Status:** complete
- Actions taken:
  - Updated `tests/test_release_status_wording.py` to match the current published release state in README, README.en, ROADMAP, and RELEASE_NOTES
- Files created/modified:
  - `tests/test_release_status_wording.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Ran `python3 -m unittest tests.test_release_status_wording -v`
  - Re-ran `python3 -m unittest discover -s tests -p 'test_*.py'`
- Files created/modified:
  - `findings.md`
  - `progress.md`
  - `task_plan.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Release status wording | `python3 -m unittest tests.test_release_status_wording -v` | pass | 4 tests passed | OK |
| Full Python discover | `python3 -m unittest discover -s tests -p 'test_*.py'` | pass | 408 tests passed | OK |

## Session: 2026-04-10 (full Pascal regression)

### Phase 1: Broad Verification
- **Status:** complete
- Actions taken:
  - Ran the repository-standard Pascal regression entrypoint `bash scripts/run_all_tests.sh`
  - Watched the full suite through to completion after the Git compat removal and release wording contract fixes
- Files created/modified:
  - `findings.md`
  - `progress.md`
  - `task_plan.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Ran focused `test_cli_misc` and `test_cli_runner` builds using writable temp `-FE/-FU` outputs
  - Attempted `lazbuild -B fpdev.lpi` and recorded the repo-local `lib/` permission blocker
  - Ran `bash scripts/run_all_tests.sh` and observed a full green baseline
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| CLI flags RED | `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cli_misc.lpr` | fail because `fpdev.cli.flags` is missing | `Can't find unit fpdev.cli.flags` | OK |
| Focused misc regression | `fpc -Fusrc -Fisrc -FE/tmp/fpdev-cli-flags-bin -FU/tmp/fpdev-cli-flags-lib tests/test_cli_misc.lpr && /tmp/fpdev-cli-flags-bin/test_cli_misc` | pass | 152 passed, 0 failed | OK |
| Focused runner regression | `fpc -Fusrc -Fisrc -FE/tmp/fpdev-cli-flags-bin -FU/tmp/fpdev-cli-flags-lib tests/test_cli_runner.lpr && /tmp/fpdev-cli-flags-bin/test_cli_runner` | pass | 16 passed, 0 failed | OK |
| Main Lazarus build | `lazbuild -B fpdev.lpi` | pass | failed with `Permission denied` writing `lib/fpdev.compiled` | BLOCKED |
| Full repository regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-09 | Focused `fpc ... -FUlib` build failed because `lib/` is root-owned | 1 | Switched focused verification to `/tmp` `-FE/-FU` directories |
| 2026-04-09 | `lazbuild -B fpdev.lpi` failed writing `lib/fpdev.compiled` | 1 | Treated as environment blocker; relied on full `run_all_tests.sh` green baseline for code-level regression evidence |

## Session: 2026-04-09 (git pull error helper extraction)

### Phase 1: Screening & Scope Selection
- **Status:** complete
- **Started:** 2026-04-09
- Actions taken:
  - Re-screened remaining plan files against current code tree instead of assuming docs were still live
  - Confirmed quality-analyzer, repo-maintenance, cross-platform hardening, and remote-registry plans are already represented in `src/` and `tests/`
  - Re-ran focused Python and Pascal suites to validate that these candidate plans are already green
  - Identified `fpdev.utils.git.pas` as the remaining oversized compatibility layer and selected Git pull error classification extraction as the smallest next cut
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Red & Minimal Extraction
- **Status:** complete
- Actions taken:
  - Added direct helper assertions to `tests/test_fpc_runtimeflow.lpr` and verified RED with missing-unit compile failure
  - Created `src/fpdev.git.errors.pas` as the new pure Git pull failure classifier unit
  - Switched `src/fpdev.fpc.runtimeflow.pas` and `src/fpdev.lazarus.commandflow.pas` to use the new helper directly
  - Kept `src/fpdev.utils.git.pas` API-compatible by delegating its legacy classifier entrypoint to the new helper
- Files created/modified:
  - `src/fpdev.git.errors.pas` (created)
  - `src/fpdev.fpc.runtimeflow.pas`
  - `src/fpdev.lazarus.commandflow.pas`
  - `src/fpdev.utils.git.pas`
  - `tests/test_fpc_runtimeflow.lpr`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran `test_fpc_runtimeflow` with writable temp `-FE/-FU` outputs
  - Re-ran `test_lazarus_runtimeflow` with writable temp `-FE/-FU` outputs
  - Re-ran `test_lazarus_update` to ensure the manager/runtime/utils.git compatibility chain still compiles and passes
  - Updated planning files with final evidence
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 4: Shared Normalizer Extraction
- **Status:** complete
- Actions taken:
  - Added direct helper assertions for `NormalizeGitPullErrorDetail` to `tests/test_fpc_runtimeflow.lpr`
  - Verified RED with `Identifier not found "NormalizeGitPullErrorDetail"`
  - Added `NormalizeGitPullErrorDetail` to `src/fpdev.git.errors.pas`
  - Removed duplicated local normalizer functions from `src/fpdev.fpc.runtimeflow.pas` and `src/fpdev.lazarus.commandflow.pas`
  - Re-ran focused runtimeflow and manager-chain regressions
- Files created/modified:
  - `src/fpdev.git.errors.pas`
  - `src/fpdev.fpc.runtimeflow.pas`
  - `src/fpdev.lazarus.commandflow.pas`
  - `tests/test_fpc_runtimeflow.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Quality analyzer suite | `python3 -m unittest tests.test_analyze_code_quality -v` | pass | 22 tests passed | OK |
| Remote registry focused regression | `mkdir -p /tmp/fpdev-registry-bin /tmp/fpdev-registry-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-registry-bin -FU/tmp/fpdev-registry-lib tests/test_registry_client_remote.lpr && /tmp/fpdev-registry-bin/test_registry_client_remote` | pass | 6 passed, 0 failed | OK |
| Package registry focused regression | `mkdir -p /tmp/fpdev-registry-bin /tmp/fpdev-registry-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-registry-bin -FU/tmp/fpdev-registry-lib tests/test_package_registry.lpr && /tmp/fpdev-registry-bin/test_package_registry` | pass | 35 passed, 0 failed | OK |
| Package publish focused regression | `mkdir -p /tmp/fpdev-registry-bin /tmp/fpdev-registry-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-registry-bin -FU/tmp/fpdev-registry-lib tests/test_package_publish.lpr && /tmp/fpdev-registry-bin/test_package_publish` | pass | 26 passed, 0 failed | OK |
| Git helper RED | `mkdir -p /tmp/fpdev-git-errors-bin /tmp/fpdev-git-errors-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-errors-bin -FU/tmp/fpdev-git-errors-lib tests/test_fpc_runtimeflow.lpr` | fail because `fpdev.git.errors` is missing | `Can't find unit fpdev.git.errors` | OK |
| FPC runtimeflow regression | `mkdir -p /tmp/fpdev-git-errors-fpc-bin /tmp/fpdev-git-errors-fpc-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-errors-fpc-bin -FU/tmp/fpdev-git-errors-fpc-lib tests/test_fpc_runtimeflow.lpr && /tmp/fpdev-git-errors-fpc-bin/test_fpc_runtimeflow` | pass | 56 passed, 0 failed | OK |
| Lazarus runtimeflow regression | `mkdir -p /tmp/fpdev-git-errors-laz-bin /tmp/fpdev-git-errors-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-errors-laz-bin -FU/tmp/fpdev-git-errors-laz-lib tests/test_lazarus_runtimeflow.lpr && /tmp/fpdev-git-errors-laz-bin/test_lazarus_runtimeflow` | pass | 31 passed, 0 failed | OK |
| Lazarus manager compatibility regression | `mkdir -p /tmp/fpdev-git-errors-mgr-bin /tmp/fpdev-git-errors-mgr-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-errors-mgr-bin -FU/tmp/fpdev-git-errors-mgr-lib tests/test_lazarus_update.lpr && /tmp/fpdev-git-errors-mgr-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| Git normalizer RED | `mkdir -p /tmp/fpdev-git-norm-red-bin /tmp/fpdev-git-norm-red-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-norm-red-bin -FU/tmp/fpdev-git-norm-red-lib tests/test_fpc_runtimeflow.lpr` | fail because `NormalizeGitPullErrorDetail` is missing | `Identifier not found "NormalizeGitPullErrorDetail"` | OK |
| FPC runtimeflow regression (after normalizer extraction) | `mkdir -p /tmp/fpdev-git-norm-fpc-bin /tmp/fpdev-git-norm-fpc-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-norm-fpc-bin -FU/tmp/fpdev-git-norm-fpc-lib tests/test_fpc_runtimeflow.lpr && /tmp/fpdev-git-norm-fpc-bin/test_fpc_runtimeflow` | pass | 60 passed, 0 failed | OK |
| Lazarus runtimeflow regression (after normalizer extraction) | `mkdir -p /tmp/fpdev-git-norm-laz-bin /tmp/fpdev-git-norm-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-norm-laz-bin -FU/tmp/fpdev-git-norm-laz-lib tests/test_lazarus_runtimeflow.lpr && /tmp/fpdev-git-norm-laz-bin/test_lazarus_runtimeflow` | pass | 31 passed, 0 failed | OK |
| Lazarus manager compatibility regression (after normalizer extraction) | `mkdir -p /tmp/fpdev-git-norm-mgr-bin /tmp/fpdev-git-norm-mgr-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-norm-mgr-bin -FU/tmp/fpdev-git-norm-mgr-lib tests/test_lazarus_update.lpr && /tmp/fpdev-git-norm-mgr-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-09 | Focused `fpc -FE/tmp/... -FU/tmp/...` build failed because target directories did not exist | 1 | Added `mkdir -p` ahead of focused builds; treated as environment setup detail |

## Session: 2026-04-09 (git backend types slice)

### Phase 1: Boundary Diagnosis
- **Status:** complete
- Actions taken:
  - Reused the in-progress `git.types` extraction state from the previous session instead of restarting discovery
  - Read `src/fpdev.git.runtime.pas`, `src/fpdev.git.types.pas`, and `src/fpdev.utils.git.pas` to trace enum visibility
  - Confirmed `gbNone` compilation failure is isolated to `fpdev.git.runtime.pas` still relying on `fpdev.utils.git` for enum symbol visibility
  - Added a Python boundary assertion to catch missing `fpdev.git.types` imports in `fpdev.git.runtime.pas`
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Minimal Repair
- **Status:** complete
- Actions taken:
  - Verified RED with `python3 -m unittest tests.test_git_runtime_boundary -v`
  - Fixed `src/fpdev.git.runtime.pas` by explicitly importing `fpdev.git.types`
  - Kept `fpdev.utils.git` compatibility facade unchanged; no behavior logic was modified
- Files created/modified:
  - `src/fpdev.git.runtime.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python boundary suite
  - Re-ran focused `test_lazarus_update`, `test_fpc_builder`, and `test_resource_repo_bootstrap` builds using writable temp `-FE/-FU` outputs
  - Updated planning files with the new evidence and the next runtime-contract route
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git runtime boundary RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.git.runtime` does not yet import `fpdev.git.types` | 1 failure in `test_git_runtime_imports_lightweight_backend_types` | OK |
| Git runtime boundary GREEN | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 4 tests passed | OK |
| Lazarus update regression | `mkdir -p /tmp/fpdev-git-types-laz-bin /tmp/fpdev-git-types-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-types-laz-bin -FU/tmp/fpdev-git-types-laz-lib tests/test_lazarus_update.lpr && /tmp/fpdev-git-types-laz-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-git-types-fpc-bin /tmp/fpdev-git-types-fpc-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-types-fpc-bin -FU/tmp/fpdev-git-types-fpc-lib tests/test_fpc_builder.lpr && /tmp/fpdev-git-types-fpc-bin/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Resource repo bootstrap regression | `mkdir -p /tmp/fpdev-git-types-repo-bin /tmp/fpdev-git-types-repo-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-types-repo-bin -FU/tmp/fpdev-git-types-repo-lib tests/test_resource_repo_bootstrap.lpr && /tmp/fpdev-git-types-repo-bin/test_resource_repo_bootstrap` | pass | 31 passed, 0 failed | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-09 | `fpdev.git.runtime.pas(77,29) Error: Identifier not found "gbNone"` during focused builder compile | 1 | Explicitly imported `fpdev.git.types` in `fpdev.git.runtime.pas` and added a boundary test to prevent silent enum-visibility regressions |

## Session: 2026-04-09 (git runtime factory slice)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Inspected remaining `TGitRuntime.Create` call sites in business modules after the backend-type extraction
  - Confirmed there are direct constructor calls in `source.repo`, `fpc.builder`, `lazarus.source`, `resource.repo`, `fpc.manager`, and `lazarus.manager`
  - Added a Python boundary assertion that business modules should not construct `TGitRuntime` directly
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Minimal Factory Extraction
- **Status:** complete
- Actions taken:
  - Verified RED with `python3 -m unittest tests.test_git_runtime_boundary -v`
  - Added `NewGitRuntime(const ACliOnly: Boolean = False): IGitRuntime` to `src/fpdev.git.runtime.pas`
  - Repointed 6 business call sites from `TGitRuntime.Create...` to `NewGitRuntime(...)`
- Files created/modified:
  - `src/fpdev.git.runtime.pas`
  - `src/fpdev.source.repo.pas`
  - `src/fpdev.fpc.builder.pas`
  - `src/fpdev.lazarus.source.pas`
  - `src/fpdev.resource.repo.pas`
  - `src/fpdev.fpc.manager.pas`
  - `src/fpdev.lazarus.manager.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python boundary suite
  - Re-ran focused `test_lazarus_update`, `test_fpc_builder`, `test_resource_repo_bootstrap`, `test_fpc_source_repo`, and `test_fpc_update`
  - Updated planning files with the new factory-boundary evidence and next route
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git runtime factory RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because business modules still contain `TGitRuntime.Create` | 1 failure in `test_business_modules_stop_constructing_tgitruntime_directly` | OK |
| Git runtime factory GREEN | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 5 tests passed | OK |
| Lazarus update regression | `mkdir -p /tmp/fpdev-git-runtime-factory-laz-bin /tmp/fpdev-git-runtime-factory-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-factory-laz-bin -FU/tmp/fpdev-git-runtime-factory-laz-lib tests/test_lazarus_update.lpr && /tmp/fpdev-git-runtime-factory-laz-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-git-runtime-factory-fpc-bin /tmp/fpdev-git-runtime-factory-fpc-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-factory-fpc-bin -FU/tmp/fpdev-git-runtime-factory-fpc-lib tests/test_fpc_builder.lpr && /tmp/fpdev-git-runtime-factory-fpc-bin/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Resource repo bootstrap regression | `mkdir -p /tmp/fpdev-git-runtime-factory-repo-bin /tmp/fpdev-git-runtime-factory-repo-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-factory-repo-bin -FU/tmp/fpdev-git-runtime-factory-repo-lib tests/test_resource_repo_bootstrap.lpr && /tmp/fpdev-git-runtime-factory-repo-bin/test_resource_repo_bootstrap` | pass | 31 passed, 0 failed | OK |
| FPC source repo regression | `mkdir -p /tmp/fpdev-git-runtime-factory-src-bin /tmp/fpdev-git-runtime-factory-src-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-factory-src-bin -FU/tmp/fpdev-git-runtime-factory-src-lib tests/test_fpc_source_repo.lpr && /tmp/fpdev-git-runtime-factory-src-bin/test_fpc_source_repo` | pass | 159 passed, 0 failed | OK |
| FPC update regression | `mkdir -p /tmp/fpdev-git-runtime-factory-update-bin /tmp/fpdev-git-runtime-factory-update-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-factory-update-bin -FU/tmp/fpdev-git-runtime-factory-update-lib tests/test_fpc_update.lpr && /tmp/fpdev-git-runtime-factory-update-bin/test_fpc_update` | pass | all tests passed | OK |

## Session: 2026-04-09 (git runtime interface sealing)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-checked repo-wide `TGitRuntime` references and confirmed no external unit still depends on the concrete class type
  - Added a Python boundary assertion that `fpdev.git.runtime` interface should not leak `fpdev.utils.git`, `TGitOperations`, or `IGitCliRunner`
  - Verified RED with the current interface-level `fpdev.utils.git` dependency
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Minimal Interface Shrink
- **Status:** complete
- Actions taken:
  - Removed `fpdev.utils.git` from the interface uses of `src/fpdev.git.runtime.pas`
  - Moved `TGitRuntime` and its `TGitOperations` / `IGitCliRunner` dependencies into the `implementation` section
  - Kept the public surface stable as `IGitRuntime + NewGitRuntime(...)`
- Files created/modified:
  - `src/fpdev.git.runtime.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python boundary suite
  - Re-ran focused `test_lazarus_update`, `test_fpc_builder`, `test_resource_repo_bootstrap`, `test_fpc_source_repo`, and `test_fpc_update`
  - Updated planning files with the sealed-interface evidence and the next runner-contract route
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git runtime interface RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.git.runtime` interface still leaks `fpdev.utils.git` contracts | 1 failure in `test_git_runtime_interface_stops_leaking_utils_git_contracts` | OK |
| Git runtime interface GREEN | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 6 tests passed | OK |
| Lazarus update regression | `mkdir -p /tmp/fpdev-git-runtime-intf-laz-bin /tmp/fpdev-git-runtime-intf-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-intf-laz-bin -FU/tmp/fpdev-git-runtime-intf-laz-lib tests/test_lazarus_update.lpr && /tmp/fpdev-git-runtime-intf-laz-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-git-runtime-intf-fpc-bin /tmp/fpdev-git-runtime-intf-fpc-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-intf-fpc-bin -FU/tmp/fpdev-git-runtime-intf-fpc-lib tests/test_fpc_builder.lpr && /tmp/fpdev-git-runtime-intf-fpc-bin/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Resource repo bootstrap regression | `mkdir -p /tmp/fpdev-git-runtime-intf-repo-bin /tmp/fpdev-git-runtime-intf-repo-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-intf-repo-bin -FU/tmp/fpdev-git-runtime-intf-repo-lib tests/test_resource_repo_bootstrap.lpr && /tmp/fpdev-git-runtime-intf-repo-bin/test_resource_repo_bootstrap` | pass | 31 passed, 0 failed | OK |
| FPC source repo regression | `mkdir -p /tmp/fpdev-git-runtime-intf-src-bin /tmp/fpdev-git-runtime-intf-src-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-intf-src-bin -FU/tmp/fpdev-git-runtime-intf-src-lib tests/test_fpc_source_repo.lpr && /tmp/fpdev-git-runtime-intf-src-bin/test_fpc_source_repo` | pass | 159 passed, 0 failed | OK |
| FPC update regression | `mkdir -p /tmp/fpdev-git-runtime-intf-update-bin /tmp/fpdev-git-runtime-intf-update-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-intf-update-bin -FU/tmp/fpdev-git-runtime-intf-update-lib tests/test_fpc_update.lpr && /tmp/fpdev-git-runtime-intf-update-bin/test_fpc_update` | pass | all tests passed | OK |

## Session: 2026-04-09 (git runtime runner cleanup)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-checked the remaining `IGitCliRunner` mentions after runtime interface sealing
  - Confirmed `fpdev.git.runtime` no longer needs a public or internal runner-based entrypoint for any current caller
  - Added a Python boundary assertion that the runtime file should no longer mention `IGitCliRunner`
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Minimal Constructor Shrink
- **Status:** complete
- Actions taken:
  - Verified RED with `python3 -m unittest tests.test_git_runtime_boundary -v`
  - Simplified `TGitRuntime` to a single `Create(const ACliOnly: Boolean = False)` constructor
  - Updated `NewGitRuntime(...)` to call the simplified constructor
- Files created/modified:
  - `src/fpdev.git.runtime.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python boundary suite
  - Re-ran focused `test_lazarus_update`, `test_fpc_builder`, `test_fpc_source_repo`, and `test_fpc_update`
  - Updated planning files with the new no-runner-runtime evidence and next-route re-evaluation
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git runtime no-runner RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.git.runtime` still mentions `IGitCliRunner` | 1 failure in `test_git_runtime_stops_mentioning_igitclirunner` | OK |
| Git runtime no-runner GREEN | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 7 tests passed | OK |
| Lazarus update regression | `mkdir -p /tmp/fpdev-git-runtime-norunner-laz-bin /tmp/fpdev-git-runtime-norunner-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-norunner-laz-bin -FU/tmp/fpdev-git-runtime-norunner-laz-lib tests/test_lazarus_update.lpr && /tmp/fpdev-git-runtime-norunner-laz-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-git-runtime-norunner-fpc-bin /tmp/fpdev-git-runtime-norunner-fpc-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-norunner-fpc-bin -FU/tmp/fpdev-git-runtime-norunner-fpc-lib tests/test_fpc_builder.lpr && /tmp/fpdev-git-runtime-norunner-fpc-bin/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| FPC source repo regression | `mkdir -p /tmp/fpdev-git-runtime-norunner-src-bin /tmp/fpdev-git-runtime-norunner-src-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-norunner-src-bin -FU/tmp/fpdev-git-runtime-norunner-src-lib tests/test_fpc_source_repo.lpr && /tmp/fpdev-git-runtime-norunner-src-bin/test_fpc_source_repo` | pass | 159 passed, 0 failed | OK |
| FPC update regression | `mkdir -p /tmp/fpdev-git-runtime-norunner-update-bin /tmp/fpdev-git-runtime-norunner-update-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-git-runtime-norunner-update-bin -FU/tmp/fpdev-git-runtime-norunner-update-lib tests/test_fpc_update.lpr && /tmp/fpdev-git-runtime-norunner-update-bin/test_fpc_update` | pass | all tests passed | OK |

## Session: 2026-04-09 (git runner re-evaluation and env helper extraction)

### Phase 1: Re-Evaluation
- **Status:** complete
- Actions taken:
  - Re-checked the remaining `IGitCliRunner` consumers in `fpdev.utils.git`, `fpdev.fpc.builder.di`, and `tests/test_git_operations.lpr`
  - Confirmed extracting the runner contract would also drag `fpdev.utils.process.TProcessResult` into a new boundary with little net reduction in coupling
  - Selected `ResolveGitCredentialEnv` and `ResolveGitIdentityEnv` as the next smaller pure-compatibility slice
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Minimal Extraction
- **Status:** complete
- Actions taken:
  - Switched `tests/test_git_env_credentials.lpr` and `tests/test_git_env_identity.lpr` to `fpdev.git.env` and confirmed RED
  - Added `src/fpdev.git.env.pas`
  - Repointed `src/fpdev.utils.git.pas` env helper wrappers to the new lightweight unit
  - Added boundary assertions for the focused env tests and for `tests/test_git_operations.lpr` using `fpdev.git.types`
  - Fixed the discovered backend-enum import gap in `tests/test_git_operations.lpr`
- Files created/modified:
  - `src/fpdev.git.env.pas` (created)
  - `src/fpdev.utils.git.pas`
  - `tests/test_git_env_credentials.lpr`
  - `tests/test_git_env_identity.lpr`
  - `tests/test_git_operations.lpr`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `test_git_env_credentials`, `test_git_env_identity`, and `test_git_operations`
  - Updated planning files with the runner re-evaluation decision and the env-helper extraction evidence
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git env helper RED (credentials) | `mkdir -p /tmp/fpdev-test-env-cred-bin /tmp/fpdev-test-env-cred-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-env-cred-bin -FU/tmp/fpdev-test-env-cred-lib tests/test_git_env_credentials.lpr` | fail because `fpdev.git.env` does not exist yet | `Fatal: Can't find unit fpdev.git.env used by test_git_env_credentials` | OK |
| Git env helper RED (identity) | `mkdir -p /tmp/fpdev-test-env-id-bin /tmp/fpdev-test-env-id-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-env-id-bin -FU/tmp/fpdev-test-env-id-lib tests/test_git_env_identity.lpr` | fail because `fpdev.git.env` does not exist yet | `Fatal: Can't find unit fpdev.git.env used by test_git_env_identity` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 9 tests passed | OK |
| Git env credentials regression | `mkdir -p /tmp/fpdev-test-env-cred-bin /tmp/fpdev-test-env-cred-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-env-cred-bin -FU/tmp/fpdev-test-env-cred-lib tests/test_git_env_credentials.lpr && /tmp/fpdev-test-env-cred-bin/test_git_env_credentials` | pass | 15 passed, 0 failed | OK |
| Git env identity regression | `mkdir -p /tmp/fpdev-test-env-id-bin /tmp/fpdev-test-env-id-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-env-id-bin -FU/tmp/fpdev-test-env-id-lib tests/test_git_env_identity.lpr && /tmp/fpdev-test-env-id-bin/test_git_env_identity` | pass | 12 passed, 0 failed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-gitops-bin /tmp/fpdev-test-gitops-lib && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-gitops-bin -FU/tmp/fpdev-test-gitops-lib tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-gitops-bin/test_git_operations` | pass | 251 passed, 0 failed | OK |
| Style regression batch 19 | `python3 -m unittest tests.test_style_regressions_batch19 -v` | pass | 3 tests passed | OK |

## Session: 2026-04-09 (legacy git facade runtime migration)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-checked the remaining direct `TGitOperations` consumers and selected `src/fpdev.git.pas` as the next compat-facade slice
  - Added a Python boundary assertion that `fpdev.git.pas` should stop binding directly to `fpdev.utils.git` / `TGitOperations`
  - Verified RED with the existing direct dependency
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Runtime Pass-Through Expansion
- **Status:** complete
- Actions taken:
  - Extended `src/fpdev.git.runtime.pas` with the minimum facade-facing pass-through methods
  - Added `PullWithMerge(...)` instead of changing the existing ff-only `Pull(...)` behavior
  - Migrated `src/fpdev.git.pas` from `TGitOperations` to `IGitRuntime` / `NewGitRuntime`
- Files created/modified:
  - `src/fpdev.git.runtime.pas`
  - `src/fpdev.git.pas`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_git_facade.lpr`
  - Re-compiled `tests/fpdev.git2.adapter/test_git.lpr` with the correct test search path
  - Re-ran the style regression batch for touched Pascal files
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git facade boundary RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.git.pas` still depends on `fpdev.utils.git` / `TGitOperations` | 1 failure in `test_git_compat_facade_stops_binding_to_utils_git` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 10 tests passed | OK |
| Git facade regression | `mkdir -p /tmp/fpdev-test-git-facade-bin /tmp/fpdev-test-git-facade-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-git-facade-bin -FU/tmp/fpdev-test-git-facade-lib tests/test_git_facade.lpr && /tmp/fpdev-test-git-facade-bin/test_git_facade` | pass | 124 passed, 0 failed | OK |
| Legacy git adapter compile | `mkdir -p /tmp/fpdev-test-git-legacy-bin /tmp/fpdev-test-git-legacy-lib && fpc -Fusrc -Fisrc -Futests -FE/tmp/fpdev-test-git-legacy-bin -FU/tmp/fpdev-test-git-legacy-lib tests/fpdev.git2.adapter/test_git.lpr` | pass | compile passed | OK |
| Style regression batch 19 | `python3 -m unittest tests.test_style_regressions_batch19 -v` | pass | 3 tests passed | OK |

## Session: 2026-04-09 (fpc builder di git runtime bridge)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-checked the remaining business-side `fpdev.utils.git` consumers after the compat-facade migration
  - Confirmed `src/fpdev.fpc.builder.di.pas` was the next small slice because it still carried the CLI clone fallback bridge
  - Used the Python boundary suite to verify RED and then traced the final failing occurrence to a comment-level `fpdev.utils.git` literal
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Builder-Specific Bridge Extraction
- **Status:** complete
- Actions taken:
  - Added `src/fpdev.fpc.builder.gitruntime.pas` to host the builder-only `IProcessRunner -> IGitCliRunner -> TGitOperations` clone bridge
  - Switched `src/fpdev.fpc.builder.di.pas` to use `CloneRepositoryWithProcessRunner(...)` instead of binding to `fpdev.utils.git` directly
  - Reworded the checkout fallback comment so the boundary test now reflects real code dependencies rather than stale text
- Files created/modified:
  - `src/fpdev.fpc.builder.gitruntime.pas` (created)
  - `src/fpdev.fpc.builder.di.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_fpc_builder.lpr` with `/tmp` outputs
  - Re-ran the style regression batch for the touched Pascal files
  - Updated planning files with the builder-bridge evidence and the residual-route questions
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| FPC builder DI boundary RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.fpc.builder.di.pas` still contains a direct `fpdev.utils.git` reference | 1 failure in `test_fpc_builder_di_stops_binding_to_utils_git_contracts` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 11 tests passed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-test-fpc-builder-bin /tmp/fpdev-test-fpc-builder-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-test-fpc-builder-bin -FU/tmp/fpdev-test-fpc-builder-lib tests/test_fpc_builder.lpr && /tmp/fpdev-test-fpc-builder-bin/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Style regression batch 19 | `python3 -m unittest tests.test_style_regressions_batch19 -v` | pass | 3 tests passed | OK |

## Session: 2026-04-09 (business module git narrative cleanup)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned business modules after the builder bridge slice and found the remaining `TGitOperations` mentions were comment-only
  - Added a Python boundary assertion that migrated business modules should stop describing themselves in terms of the legacy concrete git type
  - Verified RED with the current stale comments
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Narrative Cleanup
- **Status:** complete
- Actions taken:
  - Reworded `src/fpdev.resource.repo.pas` comments to describe the unified git runtime/backend instead of `TGitOperations`
  - Reworded `src/fpdev.fpc.builder.pas` and `src/fpdev.lazarus.source.pas` comments to the same runtime-centered vocabulary
  - Kept behavior unchanged; this slice only aligned code narrative with the already-completed structural refactor
- Files created/modified:
  - `src/fpdev.resource.repo.pas`
  - `src/fpdev.fpc.builder.pas`
  - `src/fpdev.lazarus.source.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_fpc_builder.lpr`, `tests/test_resource_repo_bootstrap.lpr`, and `tests/test_lazarus_update.lpr`
  - Updated planning files with the narrative-cleanup evidence and next residual questions
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Business module narrative RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because migrated business modules still mention `TGitOperations` text | 1 failure in `test_business_modules_stop_describing_tgitoperations_directly` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 12 tests passed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-phase12-builder-bin /tmp/fpdev-phase12-builder-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase12-builder-bin -FU/tmp/fpdev-phase12-builder-lib tests/test_fpc_builder.lpr && /tmp/fpdev-phase12-builder-bin/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Resource repo bootstrap regression | `mkdir -p /tmp/fpdev-phase12-repo-bin /tmp/fpdev-phase12-repo-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase12-repo-bin -FU/tmp/fpdev-phase12-repo-lib tests/test_resource_repo_bootstrap.lpr && /tmp/fpdev-phase12-repo-bin/test_resource_repo_bootstrap` | pass | 31 passed, 0 failed | OK |
| Lazarus update regression | `mkdir -p /tmp/fpdev-phase12-laz-bin /tmp/fpdev-phase12-laz-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase12-laz-bin -FU/tmp/fpdev-phase12-laz-lib tests/test_lazarus_update.lpr && /tmp/fpdev-phase12-laz-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |

## Session: 2026-04-09 (shared pull failure type reuse)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned `fpdev.utils.git` for pure compatibility leftovers after the runtime and narrative cleanup slices
  - Selected `TGitPullFailureKind` as the next small target because it was still duplicated locally despite already having a shared helper home
  - Added a Python boundary assertion for shared type reuse and a Pascal regression for legacy wrapper compatibility
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `tests/test_git_operations.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Shared Type Reuse
- **Status:** complete
- Actions taken:
  - Updated `src/fpdev.utils.git.pas` to alias `fpdev.git.errors.TGitPullFailureKind`
  - Re-exported the `gpfk*` constants from the shared helper unit to preserve compatibility at old call sites
  - Simplified `ClassifyGitPullFailure(...)` to a direct wrapper around the shared helper
- Files created/modified:
  - `src/fpdev.utils.git.pas`
  - `tests/test_git_runtime_boundary.py`
  - `tests/test_git_operations.lpr`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_git_operations.lpr` with `/tmp` outputs and project-root env
  - Confirmed the new legacy compatibility assertions pass while the structural boundary stays green
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Shared pull failure type RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.utils.git` still redefines `TGitPullFailureKind` locally | 1 failure in `test_utils_git_reuses_shared_pull_failure_type` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 13 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-phase13-gitops-bin /tmp/fpdev-phase13-gitops-lib && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase13-gitops-bin -FU/tmp/fpdev-phase13-gitops-lib tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-phase13-gitops-bin/test_git_operations` | pass | 254 passed, 0 failed | OK |

## Session: 2026-04-09 (compat wrapper internal call cleanup)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned `fpdev.utils.git` after the shared-type slice and identified remaining internal calls that still routed through compat wrappers
  - Added Python boundary assertions to require internal logic to call shared helpers directly
  - Verified RED with the current self-referential compat-wrapper usage
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Internal Helper Direct Wiring
- **Status:** complete
- Actions taken:
  - Changed `LoadCredentialPayloadFromEnv(...)` to call `fpdev.git.env.ResolveGitCredentialEnv(...)` directly
  - Changed the pull-failure gate to call `fpdev.git.errors.ClassifyGitPullFailure(...)` directly
  - Changed both internal identity-loading paths to call `fpdev.git.env.ResolveGitIdentityEnv(...)` directly
- Files created/modified:
  - `src/fpdev.utils.git.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_git_operations.lpr` with `/tmp` outputs and project-root env
  - Confirmed compat entrypoints still behave the same while internal wiring now points straight at the shared helper units
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Compat-wrapper internal-call RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `fpdev.utils.git` internal logic still routes through compat wrappers | 1 failure in `test_utils_git_reuses_shared_pull_failure_type` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 13 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-phase14-gitops-bin /tmp/fpdev-phase14-gitops-lib && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase14-gitops-bin -FU/tmp/fpdev-phase14-gitops-lib tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-phase14-gitops-bin/test_git_operations` | pass | 254 passed, 0 failed | OK |

## Session: 2026-04-09 (shared-by-default compat test cleanup)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-checked how `tests/test_git_operations.lpr` was using shared helpers versus compat wrappers after the previous structural cleanup
  - Added Python boundary assertions requiring the test suite to use shared helpers by default and compat wrappers only in explicit legacy coverage
  - Verified RED with the current mixed, unqualified helper usage
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Intent Clarification
- **Status:** complete
- Actions taken:
  - Switched normal backend-helper checks in `tests/test_git_operations.lpr` to `fpdev.git.types.GitBackendToString(...)`
  - Added a dedicated `TestLegacyGitBackendToStringCompatibility`
  - Changed the legacy pull-failure compatibility test to call `fpdev.utils.git.ClassifyGitPullFailure(...)` explicitly
  - Added a compat-helper comment in `src/fpdev.utils.git.pas` so the code surface matches the new test intent
- Files created/modified:
  - `src/fpdev.utils.git.pas`
  - `tests/test_git_operations.lpr`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_git_operations.lpr` with `/tmp` outputs and project-root env
  - Confirmed both shared-by-default checks and explicit legacy compatibility checks pass
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Shared-by-default compat test RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `test_git_operations` still uses helper wrappers without explicit shared/legacy intent | 1 failure in `test_git_operations_test_imports_lightweight_backend_types` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 13 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-phase15-gitops-bin /tmp/fpdev-phase15-gitops-lib && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase15-gitops-bin -FU/tmp/fpdev-phase15-gitops-lib tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-phase15-gitops-bin/test_git_operations` | pass | 257 passed, 0 failed | OK |

## Session: 2026-04-09 (shared-by-default env compat test cleanup)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-checked the focused env tests after the `test_git_operations` intent cleanup
  - Added Python boundary assertions requiring those env tests to call shared env helpers by default and compat env wrappers only in explicit legacy cases
  - Verified RED with the current unqualified/shared-only usage
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Env Test Intent Clarification
- **Status:** complete
- Actions taken:
  - Switched normal env-helper checks in `tests/test_git_env_credentials.lpr` and `tests/test_git_env_identity.lpr` to explicit `fpdev.git.env.*` calls
  - Added one explicit legacy compatibility case per file using `fpdev.utils.git.ResolveGitCredentialEnv(...)` / `ResolveGitIdentityEnv(...)`
  - Kept behavior coverage unchanged while making shared-vs-compat intent explicit
- Files created/modified:
  - `tests/test_git_env_credentials.lpr`
  - `tests/test_git_env_identity.lpr`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_git_env_credentials.lpr` and `tests/test_git_env_identity.lpr` with `/tmp` outputs
  - Confirmed shared-by-default env checks and explicit legacy compatibility checks both pass
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Env shared-by-default RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because env focused tests still do not distinguish shared helpers from compat wrappers explicitly | 1 failure in `test_git_env_focused_tests_use_lightweight_env_unit` | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 13 tests passed | OK |
| Git env credentials regression | `mkdir -p /tmp/fpdev-phase16-env-cred-bin /tmp/fpdev-phase16-env-cred-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase16-env-cred-bin -FU/tmp/fpdev-phase16-env-cred-lib tests/test_git_env_credentials.lpr && /tmp/fpdev-phase16-env-cred-bin/test_git_env_credentials` | pass | 21 passed, 0 failed | OK |
| Git env identity regression | `mkdir -p /tmp/fpdev-phase16-env-id-bin /tmp/fpdev-phase16-env-id-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase16-env-id-bin -FU/tmp/fpdev-phase16-env-id-lib tests/test_git_env_identity.lpr && /tmp/fpdev-phase16-env-id-bin/test_git_env_identity` | pass | 20 passed, 0 failed | OK |

## Session: 2026-04-09 (compat consumer boundary codification)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned repo-wide `fpdev.utils.git` references after the shared-by-default test cleanups
  - Confirmed that explicit compat helper consumers were already reduced to a tiny set of legacy tests
  - Added Python boundary assertions to codify that consumer whitelist
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Legacy Consumer Annotation
- **Status:** complete
- Actions taken:
  - Added concise comments to the legacy helper cases in `tests/test_git_operations.lpr`
  - Added concise comments to the legacy env helper cases in `tests/test_git_env_credentials.lpr` and `tests/test_git_env_identity.lpr`
  - Kept behavior unchanged; this slice was about fixing and freezing the allowed compat-consumer set
- Files created/modified:
  - `tests/test_git_operations.lpr`
  - `tests/test_git_env_credentials.lpr`
  - `tests/test_git_env_identity.lpr`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Re-ran focused `tests/test_git_operations.lpr`, `tests/test_git_env_credentials.lpr`, and `tests/test_git_env_identity.lpr`
  - Confirmed the explicit compat-consumer whitelist and all legacy coverage cases remain green
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 14 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-phase17-gitops-bin /tmp/fpdev-phase17-gitops-lib && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase17-gitops-bin -FU/tmp/fpdev-phase17-gitops-lib tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-phase17-gitops-bin/test_git_operations` | pass | 257 passed, 0 failed | OK |
| Git env credentials regression | `mkdir -p /tmp/fpdev-phase17-env-cred-bin /tmp/fpdev-phase17-env-cred-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase17-env-cred-bin -FU/tmp/fpdev-phase17-env-cred-lib tests/test_git_env_credentials.lpr && /tmp/fpdev-phase17-env-cred-bin/test_git_env_credentials` | pass | 21 passed, 0 failed | OK |
| Git env identity regression | `mkdir -p /tmp/fpdev-phase17-env-id-bin /tmp/fpdev-phase17-env-id-lib && fpc -Fusrc -Fisrc -FE/tmp/fpdev-phase17-env-id-bin -FU/tmp/fpdev-phase17-env-id-lib tests/test_git_env_identity.lpr && /tmp/fpdev-phase17-env-id-bin/test_git_env_identity` | pass | 20 passed, 0 failed | OK |

## Session: 2026-04-09 (public compat surface staging)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Tightened the Python boundary suite so `fpdev.utils.git` helper wrappers are only allowed in a dedicated legacy compat suite
  - Added explicit checks for a legacy-surface marker in `src/fpdev.utils.git.pas`
  - Added an existence/content check for `docs/GIT_COMPAT_MIGRATION.md`
  - Verified RED with the current inline compat usage and missing artifacts
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Compat Surface Consolidation
- **Status:** complete
- Actions taken:
  - Removed inline compat-helper coverage from `tests/test_git_operations.lpr`
  - Removed inline compat-helper coverage from `tests/test_git_env_credentials.lpr` and `tests/test_git_env_identity.lpr`
  - Added `tests/test_git_compat_legacy.lpr` as the dedicated compat wrapper suite
  - Marked the helper wrapper surface in `src/fpdev.utils.git.pas` as legacy-only and added `docs/GIT_COMPAT_MIGRATION.md`
- Files created/modified:
  - `tests/test_git_operations.lpr`
  - `tests/test_git_env_credentials.lpr`
  - `tests/test_git_env_identity.lpr`
  - `tests/test_git_compat_legacy.lpr`
  - `src/fpdev.utils.git.pas`
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Recompiled focused Pascal tests to `/tmp` output directories
  - Re-ran `test_git_operations` with `FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev` so its repo self-checks point at the real project root
  - Confirmed shared-only focused tests and the dedicated legacy compat suite all pass
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Public compat surface RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because default tests still inline-call compat wrappers and legacy artifacts are missing | 3 failures + 2 errors across boundary/doc checks | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 16 tests passed | OK |
| Git env credentials regression | `mkdir -p /tmp/fpdev-test-bin/git-env-cred /tmp/fpdev-test-lib/git-env-cred && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-env-cred -FU/tmp/fpdev-test-lib/git-env-cred tests/test_git_env_credentials.lpr && /tmp/fpdev-test-bin/git-env-cred/test_git_env_credentials` | pass | 15 passed, 0 failed | OK |
| Git env identity regression | `mkdir -p /tmp/fpdev-test-bin/git-env-id /tmp/fpdev-test-lib/git-env-id && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-env-id -FU/tmp/fpdev-test-lib/git-env-id tests/test_git_env_identity.lpr && /tmp/fpdev-test-bin/git-env-id/test_git_env_identity` | pass | 12 passed, 0 failed | OK |
| Git compat legacy regression | `mkdir -p /tmp/fpdev-test-bin/git-compat-legacy /tmp/fpdev-test-lib/git-compat-legacy && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-compat-legacy -FU/tmp/fpdev-test-lib/git-compat-legacy tests/test_git_compat_legacy.lpr && /tmp/fpdev-test-bin/git-compat-legacy/test_git_compat_legacy` | pass | 20 passed, 0 failed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops /tmp/fpdev-test-lib/git-ops && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops -FU/tmp/fpdev-test-lib/git-ops tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops/test_git_operations` | pass | 254 passed, 0 failed | OK |

## Session: 2026-04-09 (git runtime impl unit split)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned the remaining `fpdev.utils.git` dependency surface after Phase 18
  - Added Python boundary assertions requiring `fpdev.git.runtime` to stay contract-only and delegate construction to a dedicated impl unit
  - Verified RED with the current in-file `TGitRuntime` implementation
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Runtime Impl Extraction
- **Status:** complete
- Actions taken:
  - Added `src/fpdev.git.runtime.impl.pas`
  - Moved `TGitRuntime` and its `TGitOperations` forwarding implementation into the impl unit
  - Reduced `src/fpdev.git.runtime.pas` to the `IGitRuntime` contract and a small factory forwarder
- Files created/modified:
  - `src/fpdev.git.runtime.impl.pas`
  - `src/fpdev.git.runtime.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Recompiled focused Pascal runtime consumers to `/tmp` output directories
  - Re-ran git facade, FPC builder, Lazarus update, and FPC source repo regression suites
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Runtime impl split RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `src/fpdev.git.runtime.impl.pas` is missing and `fpdev.git.runtime.pas` still contains `TGitRuntime` | 1 failure + 1 error in runtime impl boundary tests | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 17 tests passed | OK |
| Git facade regression | `mkdir -p /tmp/fpdev-test-bin/git-facade /tmp/fpdev-test-lib/git-facade && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-facade -FU/tmp/fpdev-test-lib/git-facade tests/test_git_facade.lpr && /tmp/fpdev-test-bin/git-facade/test_git_facade` | pass | 124 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-test-bin/fpc-builder /tmp/fpdev-test-lib/fpc-builder && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-builder -FU/tmp/fpdev-test-lib/fpc-builder tests/test_fpc_builder.lpr && /tmp/fpdev-test-bin/fpc-builder/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Lazarus update regression | `mkdir -p /tmp/fpdev-test-bin/lazarus-update /tmp/fpdev-test-lib/lazarus-update && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/lazarus-update -FU/tmp/fpdev-test-lib/lazarus-update tests/test_lazarus_update.lpr && /tmp/fpdev-test-bin/lazarus-update/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| FPC source repo regression | `mkdir -p /tmp/fpdev-test-bin/fpc-source-repo /tmp/fpdev-test-lib/fpc-source-repo && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-source-repo -FU/tmp/fpdev-test-lib/fpc-source-repo tests/test_fpc_source_repo.lpr && /tmp/fpdev-test-bin/fpc-source-repo/test_fpc_source_repo` | pass | 159 passed, 0 failed | OK |

## Session: 2026-04-09 (compat alias boundary codification)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned `fpdev.utils.git` alias/constant compat symbols after the runtime impl split
  - Added Python boundary assertions requiring those compat aliases/constants to appear only in the dedicated legacy compat suite
  - Added migration-doc assertions so the remaining compat surface is documented explicitly
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Alias/Constant Legacy Coverage
- **Status:** complete
- Actions taken:
  - Added a legacy type/constant compatibility case to `tests/test_git_compat_legacy.lpr`
  - Updated `docs/GIT_COMPAT_MIGRATION.md` to cover alias and constant compat symbols
  - Added a small legacy-constants comment in `src/fpdev.utils.git.pas`
- Files created/modified:
  - `tests/test_git_compat_legacy.lpr`
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `src/fpdev.utils.git.pas`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Recompiled the dedicated legacy compat suite to `/tmp`
  - Re-ran the dedicated legacy compat suite and confirmed alias/constant checks pass
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Compat alias RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because alias/constants are not yet covered in the legacy suite or migration doc | 2 failures in alias/doc boundary checks | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 18 tests passed | OK |
| Git compat legacy regression | `mkdir -p /tmp/fpdev-test-bin/git-compat-legacy-2 /tmp/fpdev-test-lib/git-compat-legacy-2 && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-compat-legacy-2 -FU/tmp/fpdev-test-lib/git-compat-legacy-2 tests/test_git_compat_legacy.lpr && /tmp/fpdev-test-bin/git-compat-legacy-2/test_git_compat_legacy` | pass | 26 passed, 0 failed | OK |

## Session: 2026-04-09 (default operations entrypoint migration)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Re-scanned default `TGitOperations` consumers after the runtime impl split
  - Added Python boundary assertions requiring a new `fpdev.git.operations` facade unit
  - Required `fpdev.git.runtime.impl.pas`, `fpdev.fpc.builder.gitruntime.pas`, and `tests/test_git_operations.lpr` to stop importing `fpdev.utils.git` directly
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Operations Facade Migration
- **Status:** complete
- Actions taken:
  - Added `src/fpdev.git.operations.pas`
  - Switched `src/fpdev.git.runtime.impl.pas` to use `fpdev.git.operations`
  - Switched `src/fpdev.fpc.builder.gitruntime.pas` to use `fpdev.git.operations`
  - Switched `tests/test_git_operations.lpr` to use `fpdev.git.operations`
  - Updated `docs/GIT_COMPAT_MIGRATION.md` to point new `TGitOperations`/`IGitCliRunner` consumers at the facade unit
- Files created/modified:
  - `src/fpdev.git.operations.pas`
  - `src/fpdev.git.runtime.impl.pas`
  - `src/fpdev.fpc.builder.gitruntime.pas`
  - `tests/test_git_operations.lpr`
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Recompiled focused Pascal tests to `/tmp`
  - Re-ran `test_git_operations`, `test_fpc_builder`, and `test_git_facade`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Operations facade RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because `src/fpdev.git.operations.pas` is missing and default consumers still import `fpdev.utils.git` | 2 failures + 1 error in operations-entrypoint boundary checks | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 19 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops-3 /tmp/fpdev-test-lib/git-ops-3 && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops-3 -FU/tmp/fpdev-test-lib/git-ops-3 tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops-3/test_git_operations` | pass | 254 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-test-bin/fpc-builder-2 /tmp/fpdev-test-lib/fpc-builder-2 && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-builder-2 -FU/tmp/fpdev-test-lib/fpc-builder-2 tests/test_fpc_builder.lpr && /tmp/fpdev-test-bin/fpc-builder-2/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Git facade regression | `mkdir -p /tmp/fpdev-test-bin/git-facade-2 /tmp/fpdev-test-lib/git-facade-2 && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-facade-2 -FU/tmp/fpdev-test-lib/git-facade-2 tests/test_git_facade.lpr && /tmp/fpdev-test-bin/git-facade-2/test_git_facade` | pass | 124 passed, 0 failed | OK |

## Session: 2026-04-09 (operations facade narrative hardening)

### Phase 1: Boundary Follow-through
- **Status:** complete
- Actions taken:
  - Re-checked the existing operations-facade boundary follow-up after the import whitelist assertion was added
  - Confirmed the remaining gap was narrative only: missing default-entrypoint and migration-routing comments
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Narrative Alignment
- **Status:** complete
- Actions taken:
  - Added a default-entrypoint comment to `src/fpdev.git.operations.pas`
  - Added an explicit migration hint in `src/fpdev.utils.git.pas` telling operations consumers to use `fpdev.git.operations`
- Files created/modified:
  - `src/fpdev.git.operations.pas`
  - `src/fpdev.utils.git.pas`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite after the comment-only changes
  - Confirmed the expanded narrative/import-whitelist boundary now passes end-to-end
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 21 tests passed | OK |

## Session: 2026-04-09 (compat surface soft deprecation)

### Phase 1: Boundary Setup
- **Status:** complete
- Actions taken:
  - Added Python boundary coverage requiring the remaining compat aliases/helpers in `fpdev.utils.git` to carry migration-facing `deprecated` markers
  - Extended the migration-doc contract so the doc must state that the compat surface is soft-deprecated and emits compiler warnings
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Deprecation Staging
- **Status:** complete
- Actions taken:
  - Added `deprecated` guidance to the compat aliases, constants, and helper wrappers in `src/fpdev.utils.git.pas`
  - Updated `src/fpdev.utils.git.pas` internals to use shared type/const paths so the unit no longer warns on its default operations code path
  - Updated `docs/GIT_COMPAT_MIGRATION.md` to describe the soft-deprecation stage and compiler-warning behavior
- Files created/modified:
  - `src/fpdev.utils.git.pas`
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `tests/test_git_runtime_boundary.py`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite after the deprecation markers landed
  - Recompiled and ran the dedicated legacy compat suite from `/tmp`
  - Recompiled and ran the default git operations suite from `/tmp`, confirming the normal path no longer self-triggers compat warnings
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Compat soft-deprecation RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail because compat public surface and migration doc do not yet carry deprecation staging text | 2 failures in deprecation/doc boundary checks | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 22 tests passed | OK |
| Git compat legacy regression | `mkdir -p /tmp/fpdev-test-bin/git-compat-legacy-depr2 /tmp/fpdev-test-lib/git-compat-legacy-depr2 && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-compat-legacy-depr2 -FU/tmp/fpdev-test-lib/git-compat-legacy-depr2 tests/test_git_compat_legacy.lpr && /tmp/fpdev-test-bin/git-compat-legacy-depr2/test_git_compat_legacy` | pass with deprecation warnings | 26 passed, 0 failed; 17 warnings issued | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops-depr2 /tmp/fpdev-test-lib/git-ops-depr2 && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops-depr2 -FU/tmp/fpdev-test-lib/git-ops-depr2 tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops-depr2/test_git_operations` | pass without compat self-warnings | 254 passed, 0 failed | OK |

## Session: 2026-04-10 (removal staging and bridge decisions)

### Phase 1: Caller Scan And Decision Framing
- **Status:** complete
- Actions taken:
  - Re-scanned all Pascal repository callers for the deprecated `fpdev.utils.git` public surface across `src/*.pas`, `tests/*.pas`, and `tests/*.lpr`
  - Confirmed every deprecated alias/helper now has only one repository Pascal caller: `tests/test_git_compat_legacy.lpr`
  - Re-scanned builder bridge consumers and confirmed `src/fpdev.fpc.builder.gitruntime.pas` is only imported by `src/fpdev.fpc.builder.di.pas`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Removal Staging Contracts
- **Status:** complete
- Actions taken:
  - Expanded the git boundary suite so compat helper/alias caller checks scan the full Pascal repo set
  - Added boundary coverage for builder bridge single-consumer policy and for `tests/test_git_operations.lpr` staying a focused default-facade suite
  - Updated migration docs and file comments so A/B/C removal staging and the two structure decisions are explicit in the codebase
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `src/fpdev.fpc.builder.gitruntime.pas`
  - `tests/test_git_operations.lpr`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite after the removal-staging changes
  - Recompiled and ran the dedicated legacy compat suite from `/tmp`
  - Recompiled and ran the default git operations suite from `/tmp`
  - Recompiled and ran the FPC builder suite from `/tmp`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 24 tests passed | OK |
| Git compat legacy regression | `mkdir -p /tmp/fpdev-test-bin/git-compat-removal-stage /tmp/fpdev-test-lib/git-compat-removal-stage && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-compat-removal-stage -FU/tmp/fpdev-test-lib/git-compat-removal-stage tests/test_git_compat_legacy.lpr && /tmp/fpdev-test-bin/git-compat-removal-stage/test_git_compat_legacy` | pass with deprecation warnings | 26 passed, 0 failed; 17 warnings issued | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops-removal-stage /tmp/fpdev-test-lib/git-ops-removal-stage && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops-removal-stage -FU/tmp/fpdev-test-lib/git-ops-removal-stage tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops-removal-stage/test_git_operations` | pass | 254 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-test-bin/fpc-builder-removal-stage /tmp/fpdev-test-lib/fpc-builder-removal-stage && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-builder-removal-stage -FU/tmp/fpdev-test-lib/fpc-builder-removal-stage tests/test_fpc_builder.lpr && /tmp/fpdev-test-bin/fpc-builder-removal-stage/test_fpc_builder` | pass | 90 passed, 0 failed | OK |

## Session: 2026-04-10 (breaking removal of compat helpers)

### Phase 1: Public Surface Removal
- **Status:** complete
- Actions taken:
  - Removed the deprecated compat aliases, constants, and helper wrappers from `src/fpdev.utils.git.pas`
  - Deleted `tests/test_git_compat_legacy.lpr` now that the removed symbols no longer exist
- Files created/modified:
  - `src/fpdev.utils.git.pas`
  - `tests/test_git_runtime_boundary.py`
  - `docs/GIT_COMPAT_MIGRATION.md`

### Phase 2: Boundary And Docs Rewrite
- **Status:** complete
- Actions taken:
  - Rewrote the git boundary suite from soft-deprecation staging to removal-complete assertions
  - Updated the migration doc to describe the breaking removal as completed while keeping the retained implementation bridges explicit
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`
  - `docs/GIT_COMPAT_MIGRATION.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite after the breaking removal
  - Recompiled and ran the default git operations suite from `/tmp`
  - Recompiled and ran the FPC builder suite from `/tmp`
  - Verified that `tests/test_git_compat_legacy.lpr` no longer exists
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 24 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops-breaking-remove /tmp/fpdev-test-lib/git-ops-breaking-remove && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops-breaking-remove -FU/tmp/fpdev-test-lib/git-ops-breaking-remove tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops-breaking-remove/test_git_operations` | pass | 254 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-test-bin/fpc-builder-breaking-remove /tmp/fpdev-test-lib/fpc-builder-breaking-remove && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-builder-breaking-remove -FU/tmp/fpdev-test-lib/fpc-builder-breaking-remove tests/test_fpc_builder.lpr && /tmp/fpdev-test-bin/fpc-builder-breaking-remove/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Legacy compat suite removal | `test ! -e tests/test_git_compat_legacy.lpr` | file absent | exit 0 | OK |

## Session: 2026-04-10 (operations implementation relocation)

### Phase 1: RED Boundary Upgrade
- **Status:** complete
- Actions taken:
  - Expanded `tests/test_git_runtime_boundary.py` to require `src/fpdev.git.operations.impl.pas`
  - Tightened the boundary so `src/fpdev.git.operations.pas` can no longer alias `fpdev.utils.git`
  - Tightened the boundary so `src/fpdev.utils.git.pas` must be a legacy compatibility shim instead of the concrete implementation home
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Implementation Relocation
- **Status:** complete
- Actions taken:
  - Moved the concrete `TGitOperations` / `IGitCliRunner` implementation into `src/fpdev.git.operations.impl.pas`
  - Rewrote `src/fpdev.git.operations.pas` to expose the default facade over the new impl unit
  - Rewrote `src/fpdev.utils.git.pas` into a compatibility alias shim over `fpdev.git.operations`
  - Updated the migration doc to describe the new implementation ownership
- Files created/modified:
  - `src/fpdev.git.operations.impl.pas`
  - `src/fpdev.git.operations.pas`
  - `src/fpdev.utils.git.pas`
  - `docs/GIT_COMPAT_MIGRATION.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite after the relocation
  - Recompiled and ran the default git operations suite from `/tmp`
  - Recompiled and ran the FPC builder suite from `/tmp`
  - Recompiled and ran the git facade suite from `/tmp`
  - Re-ran the style regression batch that covers `src/fpdev.utils.git.pas`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 24 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops-impl-move /tmp/fpdev-test-lib/git-ops-impl-move && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops-impl-move -FU/tmp/fpdev-test-lib/git-ops-impl-move tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops-impl-move/test_git_operations` | pass | 254 passed, 0 failed | OK |
| FPC builder regression | `mkdir -p /tmp/fpdev-test-bin/fpc-builder-impl-move /tmp/fpdev-test-lib/fpc-builder-impl-move && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/fpc-builder-impl-move -FU/tmp/fpdev-test-lib/fpc-builder-impl-move tests/test_fpc_builder.lpr && /tmp/fpdev-test-bin/fpc-builder-impl-move/test_fpc_builder` | pass | 90 passed, 0 failed | OK |
| Git facade regression | `mkdir -p /tmp/fpdev-test-bin/git-facade-impl-move /tmp/fpdev-test-lib/git-facade-impl-move && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-facade-impl-move -FU/tmp/fpdev-test-lib/git-facade-impl-move tests/test_git_facade.lpr && /tmp/fpdev-test-bin/git-facade-impl-move/test_git_facade` | pass | 124 passed, 0 failed | OK |
| Style regression batch 19 | `python3 -m unittest tests.test_style_regressions_batch19 -v` | pass | 3 tests passed | OK |

## Session: 2026-04-10 (compat shim soft deprecation)

### Phase 1: Boundary RED
- **Status:** complete
- Actions taken:
  - Tightened the git boundary suite so `src/fpdev.utils.git.pas` must carry deprecation markers on its remaining alias exports
  - Tightened the suite so `src/fpdev.git.operations.pas` remains the clean default entrypoint without the compat deprecation marker
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Shim Deprecation Markers
- **Status:** complete
- Actions taken:
  - Added `deprecated 'Use fpdev.git.operations instead'` to the `IGitCliRunner` and `TGitOperations` aliases in `src/fpdev.utils.git.pas`
  - Updated the migration doc to record the soft-deprecated status of the compat shim aliases
- Files created/modified:
  - `src/fpdev.utils.git.pas`
  - `docs/GIT_COMPAT_MIGRATION.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python git boundary suite
  - Recompiled and ran the default git operations suite from `/tmp`
  - Re-ran the style regression batch that covers `src/fpdev.utils.git.pas`
  - Compiled a temporary `/tmp` Pascal sample that imports `fpdev.utils.git` to verify the deprecation warning is emitted
  - Promoted that warning check into the Python boundary suite so it is enforced automatically
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 25 tests passed | OK |
| Git operations regression | `mkdir -p /tmp/fpdev-test-bin/git-ops-shim-depr /tmp/fpdev-test-lib/git-ops-shim-depr && fpc -Fu./src -Fi./src -Fu./tests -FE/tmp/fpdev-test-bin/git-ops-shim-depr -FU/tmp/fpdev-test-lib/git-ops-shim-depr tests/test_git_operations.lpr && FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev /tmp/fpdev-test-bin/git-ops-shim-depr/test_git_operations` | pass | 254 passed, 0 failed | OK |
| Style regression batch 19 | `python3 -m unittest tests.test_style_regressions_batch19 -v` | pass | 3 tests passed | OK |
| Compat shim warning sample | `fpc -Fu./src -Fi./src -FE/tmp -FU/tmp /tmp/test_utils_git_deprecated.lpr` | compile succeeds and emits deprecation warnings | compile succeeded; warnings emitted for `TGitOperations` and `IGitCliRunner` with message `Use fpdev.git.operations instead` | OK |

## Session: 2026-04-10 (conservative doc cleanup for compat shim)

### Phase 1: Historical Doc RED
- **Status:** complete
- Actions taken:
  - Added boundary coverage requiring the historical development roadmap docs to point current Git work at `fpdev.git.operations` / `fpdev.git.operations.impl`
  - Added boundary coverage requiring `docs/history/B166-deprecated-cleanup.md` to mark its old `fpdev.utils.git` internals as superseded by later migration work
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Historical Doc Rewrite
- **Status:** complete
- Actions taken:
  - Updated `docs/history/DEVELOPMENT_ROADMAP.md` and `.en.md` so their current-worktree Git notes reference `fpdev.git.operations`, `fpdev.git.operations.impl`, and `src/fpdev.fpc.builder.gitruntime.pas`
  - Updated `docs/history/B166-deprecated-cleanup.md` so its `SharedGitManager` description is explicitly scoped as historical and the current worktree note points to the soft-deprecated compatibility shim
  - Updated `CLAUDE.md` so its Git integration guidance points new code at `src/fpdev.git.operations.pas` and `src/fpdev.git.operations.impl.pas`
- Files created/modified:
  - `docs/history/DEVELOPMENT_ROADMAP.md`
  - `docs/history/DEVELOPMENT_ROADMAP.en.md`
  - `docs/history/B166-deprecated-cleanup.md`
  - `CLAUDE.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the targeted historical-doc boundary tests
  - Re-ran the full Python git boundary suite after the doc cleanup
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git historical roadmap doc boundary | `python3 -m unittest tests.test_git_runtime_boundary.GitRuntimeBoundaryTests.test_historical_roadmaps_point_git_work_at_operations_units -v` | pass | 1 test passed | OK |
| Git historical deprecated-cleanup doc boundary | `python3 -m unittest tests.test_git_runtime_boundary.GitRuntimeBoundaryTests.test_historical_deprecated_cleanup_doc_marks_utils_git_as_superseded -v` | pass | 1 test passed | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 28 tests passed | OK |

## Session: 2026-04-10 (conservative doc cleanup for changelog and audit)

### Phase 1: Doc Boundary RED
- **Status:** complete
- Actions taken:
  - Added boundary coverage requiring `CHANGELOG.md` to point current Git guidance at `fpdev.git.operations` / `fpdev.git.operations.impl`
  - Added boundary coverage requiring `docs/history/DEPRECATED_CODE_AUDIT.md` to mark `fpdev.utils.git` as superseded by later migration work
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Doc Rewrite
- **Status:** complete
- Actions taken:
  - Updated `CHANGELOG.md` so its current-worktree Git notes identify `fpdev.git.operations` as the default entrypoint and `fpdev.utils.git` as a soft-deprecated compatibility shim
  - Updated `docs/history/DEPRECATED_CODE_AUDIT.md` so its older `SharedGitManager` conclusions are explicitly scoped as historical and superseded by the later Git migration
- Files created/modified:
  - `CHANGELOG.md`
  - `docs/history/DEPRECATED_CODE_AUDIT.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the targeted changelog boundary test
  - Re-ran the targeted historical audit boundary test
  - Re-ran the full Python git boundary suite after the doc cleanup
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git changelog doc boundary | `python3 -m unittest tests.test_git_runtime_boundary.GitRuntimeBoundaryTests.test_changelog_marks_utils_git_as_legacy_path -v` | pass | 1 test passed | OK |
| Git deprecated-audit doc boundary | `python3 -m unittest tests.test_git_runtime_boundary.GitRuntimeBoundaryTests.test_historical_deprecated_code_audit_marks_utils_git_as_superseded -v` | pass | 1 test passed | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 30 tests passed | OK |

## Session: 2026-04-10 (conservative guide cleanup for Git2 usage docs)

### Phase 1: Guide Boundary RED
- **Status:** complete
- Actions taken:
  - Confirmed `README.md` no longer carries stale `fpdev.utils.git` guidance
  - Added boundary coverage requiring `docs/GIT2_USAGE.md` and `docs/GIT2_USAGE.en.md` to describe the current system-git facade path
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Guide Rewrite
- **Status:** complete
- Actions taken:
  - Updated `docs/GIT2_USAGE.md` with a current-worktree note pointing system-git consumers at `fpdev.git.operations`, `fpdev.git.operations.impl`, and the soft-deprecated `fpdev.utils.git` shim
  - Updated `docs/GIT2_USAGE.en.md` with the same current-worktree note
- Files created/modified:
  - `docs/GIT2_USAGE.md`
  - `docs/GIT2_USAGE.en.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the targeted Git2 usage guide boundary test
  - Re-ran the full Python git boundary suite after the guide cleanup
  - Attempted to run `yarn prettier --write ./docs/GIT2_USAGE.md ./docs/GIT2_USAGE.en.md`; current repo tooling returned `No files matching the pattern were found`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git2 usage guide boundary | `python3 -m unittest tests.test_git_runtime_boundary.GitRuntimeBoundaryTests.test_git2_usage_guides_point_system_git_facade_at_operations_units -v` | pass | 1 test passed | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 31 tests passed | OK |
| Docs prettier attempt | `yarn prettier --write ./docs/GIT2_USAGE.md ./docs/GIT2_USAGE.en.md` | format docs | failed with `No files matching the pattern were found` | Recorded |

## Session: 2026-04-10 (conservative active doc cleanup for architecture and libgit2 guides)

### Phase 1: Boundary RED
- **Status:** complete
- Actions taken:
  - Re-scanned active docs and confirmed `README`, `QUICKSTART`, and `INSTALLATION` do not need Git entrypoint rewrites
  - Added boundary coverage requiring `docs/ARCHITECTURE.md` and `.en.md` to describe the current system-git default entrypoint
  - Added boundary coverage requiring `docs/LIBGIT2_INTEGRATION.md` and `.en.md` to clarify their libgit2-only scope and point system-git readers at `fpdev.git.operations`
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Doc Rewrite
- **Status:** complete
- Actions taken:
  - Updated `docs/ARCHITECTURE.md` and `.en.md` with Git service notes that point new system-git code at `src/fpdev.git.operations.pas` and `src/fpdev.git.operations.impl.pas`
  - Updated `docs/LIBGIT2_INTEGRATION.md` and `.en.md` with scope notes that keep this guide focused on libgit2 while routing the system-git facade to `fpdev.git.operations`
- Files created/modified:
  - `docs/ARCHITECTURE.md`
  - `docs/ARCHITECTURE.en.md`
  - `docs/LIBGIT2_INTEGRATION.md`
  - `docs/LIBGIT2_INTEGRATION.en.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the full Python git boundary suite after the active-doc cleanup
  - Attempted the repository docs workflow with both `docs/...` and `./docs/...` prettier paths; both failed with the same pattern-resolution error
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 33 tests passed | OK |
| Docs prettier attempt | `yarn prettier --write docs/ARCHITECTURE.md docs/ARCHITECTURE.en.md docs/LIBGIT2_INTEGRATION.md docs/LIBGIT2_INTEGRATION.en.md` | format docs | failed with `No files matching the pattern were found` | Recorded |
| Docs prettier attempt (prefixed paths) | `yarn prettier --write ./docs/ARCHITECTURE.md ./docs/ARCHITECTURE.en.md ./docs/LIBGIT2_INTEGRATION.md ./docs/LIBGIT2_INTEGRATION.en.md` | format docs | failed with `No files matching the pattern were found` | Recorded |

## Session: 2026-04-10 (docs formatter entrypoint recovery)

### Phase 1: Root-Cause Reproduction
- **Status:** complete
- Actions taken:
  - Confirmed the repo has no local `package.json` / `.prettier*` files
  - Verified direct `/home/dtamade/node_modules/.bin/prettier` calls can resolve repo markdown files
  - Verified `yarn run prettier` still fails with `No files matching the pattern were found`
  - Confirmed the active Yarn package comes from `/home/dtamade/package.json`, not this repo
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: RED Test And Wrapper
- **Status:** complete
- Actions taken:
  - Added `tests/test_run_prettier_sh.py` as a regression suite for a repo-local prettier wrapper
  - Verified RED while `scripts/run_prettier.sh` did not yet exist
  - Added `scripts/run_prettier.sh`
  - Made the wrapper resolve `prettier` from `PATH`, `${HOME}/node_modules/.bin/prettier`, or `node require.resolve(...)`
  - Ensured the wrapper works with both relative and absolute markdown paths
- Files created/modified:
  - `tests/test_run_prettier_sh.py`
  - `scripts/run_prettier.sh`

### Phase 3: Verification And Real Formatting
- **Status:** complete
- Actions taken:
  - Re-ran the focused prettier-wrapper regression suite
  - Used the new wrapper to format the architecture/libgit2 docs touched in the previous phase
  - Re-ran the git boundary suite after formatting
  - Ran `bash -n scripts/run_prettier.sh`
- Files created/modified:
  - `docs/ARCHITECTURE.md`
  - `docs/ARCHITECTURE.en.md`
  - `docs/LIBGIT2_INTEGRATION.md`
  - `docs/LIBGIT2_INTEGRATION.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Prettier wrapper RED | `python3 -m unittest tests.test_run_prettier_sh -v` | fail while wrapper is missing | failed: missing `scripts/run_prettier.sh` and wrapper invocations returned 127 | FAIL |
| Prettier wrapper suite | `python3 -m unittest tests.test_run_prettier_sh -v` | pass | 4 tests passed | OK |
| Prettier wrapper on real docs | `bash scripts/run_prettier.sh --write docs/ARCHITECTURE.md docs/ARCHITECTURE.en.md docs/LIBGIT2_INTEGRATION.md docs/LIBGIT2_INTEGRATION.en.md` | format docs successfully | completed successfully | OK |
| Prettier wrapper check on real docs | `bash scripts/run_prettier.sh --check docs/ARCHITECTURE.md docs/ARCHITECTURE.en.md docs/LIBGIT2_INTEGRATION.md docs/LIBGIT2_INTEGRATION.en.md` | all targeted docs already formatted | `All matched files use Prettier code style!` | OK |
| Shell syntax | `bash -n scripts/run_prettier.sh` | pass | pass | OK |
| Combined regression | `python3 -m unittest tests.test_run_prettier_sh tests.test_git_runtime_boundary -v` | pass | 37 tests passed | OK |

## Session: 2026-04-10 (doc tooling and git compat closure)

### Phase 1: Plan And RED
- **Status:** complete
- Actions taken:
  - Wrote the formal implementation plan at `docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md`
  - Added contributor-doc contract coverage for the repo-local prettier wrapper, the `unittest` Python baseline, and `/tmp` focused Pascal compile guidance
  - Added Git boundary coverage for final removal gates, current text-reference buckets, and the active-doc whitelist for `fpdev.utils.git`
  - Re-ran the focused suites to confirm RED before changing docs
- Files created/modified:
  - `docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md`
  - `tests/test_contributor_docs_contract.py`
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Doc Rewrite
- **Status:** complete
- Actions taken:
  - Updated `CLAUDE.md` to use `unittest`, the repo-local prettier wrapper, and the `/tmp` focused Pascal compile pattern
  - Updated `docs/testing.md` with a high-frequency command index, repo-local doc-formatting commands, and explicit `/tmp` + `FPDEV_TEST_PROJECT_ROOT` focused Pascal guidance
  - Updated `docs/GIT_COMPAT_MIGRATION.md` with final removal gates and current text-reference buckets
- Files created/modified:
  - `CLAUDE.md`
  - `docs/testing.md`
  - `docs/GIT_COMPAT_MIGRATION.md`

### Phase 3: Formatting And Verification
- **Status:** complete
- Actions taken:
  - Formatted the touched markdown files with `bash scripts/run_prettier.sh --write ...`
  - Re-ran the contributor-doc contract suite
  - Re-ran the Git runtime boundary suite
  - Re-ran the combined wrapper + docs + boundary regression bundle
  - Re-checked the touched markdown files with `bash scripts/run_prettier.sh --check ...`
  - Ran `bash -n scripts/run_prettier.sh`
- Files created/modified:
  - `CLAUDE.md`
  - `docs/testing.md`
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Contributor docs RED | `python3 -m unittest tests.test_contributor_docs_contract -v` | fail before doc rewrite | 2 failures: stale `pytest` guidance and missing repo-local formatter / `/tmp` guidance | FAIL |
| Git migration doc RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail before migration-doc rewrite | 1 failure: missing `Final removal gates` and `Current text-reference buckets` | FAIL |
| Contributor docs contract | `python3 -m unittest tests.test_contributor_docs_contract -v` | pass | 25 tests passed | OK |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 35 tests passed | OK |
| Markdown formatting | `bash scripts/run_prettier.sh --write CLAUDE.md docs/testing.md docs/GIT_COMPAT_MIGRATION.md docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md` | format touched docs successfully | completed successfully | OK |
| Markdown format check | `bash scripts/run_prettier.sh --check CLAUDE.md docs/testing.md docs/GIT_COMPAT_MIGRATION.md docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md` | all targeted docs already formatted | `All matched files use Prettier code style!` | OK |
| Shell syntax | `bash -n scripts/run_prettier.sh` | pass | pass | OK |
| Combined regression | `python3 -m unittest tests.test_run_prettier_sh tests.test_contributor_docs_contract tests.test_git_runtime_boundary -v` | pass | 64 tests passed | OK |

## Session: 2026-04-10 (git compat breaking removal staging)

### Phase 1: Boundary RED
- **Status:** complete
- Actions taken:
  - Added Git boundary coverage requiring a breaking-removal plan doc for `fpdev.utils.git`
  - Added coverage requiring the migration doc to point to that plan
  - Added plan-content assertions for the delete target, release-note template, and combined verification entrypoints
- Files created/modified:
  - `tests/test_git_runtime_boundary.py`

### Phase 2: Plan And Migration Doc Update
- **Status:** complete
- Actions taken:
  - Added `docs/plans/2026-04-10-git-compat-breaking-removal.md`
  - Updated `docs/GIT_COMPAT_MIGRATION.md` so the final-removal gates point to the staged execution checklist
- Files created/modified:
  - `docs/plans/2026-04-10-git-compat-breaking-removal.md`
  - `docs/GIT_COMPAT_MIGRATION.md`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Git boundary suite after adding the plan and migration-doc link
  - Formatted the touched markdown files with `bash scripts/run_prettier.sh --write ...`
  - Re-ran `bash scripts/run_prettier.sh --check ...` sequentially after formatting
  - Re-ran the combined wrapper + contributor-doc + boundary regression bundle
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Breaking removal staging RED | `python3 -m unittest tests.test_git_runtime_boundary -v` | fail before plan doc and migration link exist | 2 failures: missing plan doc and missing migration-doc link | FAIL |
| Git boundary suite | `python3 -m unittest tests.test_git_runtime_boundary -v` | pass | 36 tests passed | OK |
| Markdown formatting | `bash scripts/run_prettier.sh --write docs/GIT_COMPAT_MIGRATION.md docs/plans/2026-04-10-git-compat-breaking-removal.md` | format touched docs successfully | completed successfully | OK |
| Markdown format check | `bash scripts/run_prettier.sh --check docs/GIT_COMPAT_MIGRATION.md docs/plans/2026-04-10-git-compat-breaking-removal.md` | all targeted docs already formatted | `All matched files use Prettier code style!` | OK |
| Combined regression | `python3 -m unittest tests.test_run_prettier_sh tests.test_contributor_docs_contract tests.test_git_runtime_boundary -v` | pass | 65 tests passed | OK |

## Session: 2026-04-10 (fpc metadataflow extraction)

### Phase 1: Residual Compile Fixes
- **Status:** complete
- Actions taken:
  - Fixed `tests/test_fpc_manager_installmetadata.lpr` to import `DateUtils` and `fpdev.types`
  - Switched `src/fpdev.cmd.fpc.verify.pas` to shared `fpdev.fpc.types.TVerificationResult`
  - Removed the remaining old-type references from `tests/test_fpc_verify.lpr`
  - Confirmed no residual `fpdev.fpc.validator.TVerificationResult` references remain under `src/` and `tests/`
- Files created/modified:
  - `src/fpdev.cmd.fpc.verify.pas`
  - `tests/test_fpc_manager_installmetadata.lpr`
  - `tests/test_fpc_verify.lpr`

### Phase 2: Focused Runtime Path Hardening
- **Status:** complete
- Actions taken:
  - Reproduced `/tmp` runtime failures in `test_fpc_manager_installmetadata` and `test_fpc_verify`
  - Added `ResolveTestAssetPath` to `tests/test_temp_paths.pas`
  - Repointed `test_fpc_manager_installmetadata`, `test_fpc_verify`, and `test_cli_fpc_diag` to the shared asset resolver for `tests/mock_fpc.pas`
- Files created/modified:
  - `tests/test_temp_paths.pas`
  - `tests/test_fpc_manager_installmetadata.lpr`
  - `tests/test_fpc_verify.lpr`
  - `tests/test_cli_fpc_diag.lpr`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Ran focused `/tmp` Pascal builds and executables for metadataflow-related suites
  - Re-ran `test_cli_fpc_diag` to compile and execute the `fpdev.cmd.fpc.verify` path after the shared-type change
  - Ran the repository-standard Pascal regression entrypoint
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Metadataflow focused suite | `fpc ... tests/test_fpc_manager_installmetadata.lpr && /tmp/.../test_fpc_manager_installmetadata` | pass | 25 passed, 0 failed | OK |
| Scoped install focused suite | `fpc ... tests/test_fpc_scoped_install.lpr && /tmp/.../test_fpc_scoped_install` | pass | 9 passed, 0 failed | OK |
| Verify focused suite | `fpc ... tests/test_fpc_verify.lpr && /tmp/.../test_fpc_verify` | pass | `All tests passed` | OK |
| CLI diag focused suite | `fpc ... tests/test_cli_fpc_diag.lpr && /tmp/.../test_cli_fpc_diag` | pass | 158 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Session: 2026-04-11 (fpc verify flow boundary and mock helper consolidation)

### Phase 1: Plan And RED
- **Status:** complete
- Actions taken:
  - Wrote the execution plan at `docs/plans/2026-04-11-fpc-verify-flow-wave.md`
  - Added `tests/test_fpc_verify_boundary.py` to lock validator/runtime delegation and shared mock-helper expectations
  - Ran the new Python boundary suite and confirmed RED before implementation
- Files created/modified:
  - `docs/plans/2026-04-11-fpc-verify-flow-wave.md`
  - `tests/test_fpc_verify_boundary.py`

### Phase 2: Shared Mock Helper And Validator Refactor
- **Status:** complete
- Actions taken:
  - Added `tests/test_fpc_mock_helpers.pas` with shared `CompileMockFPCBinary`
  - Repointed `test_fpc_verify`, `test_fpc_manager_installmetadata`, and `test_cli_fpc_diag` to the shared helper
  - Refactored `src/fpdev.fpc.validator.pas` so executable-level verification delegates to `fpdev.fpc.verify.TFPCVerifier`
  - Removed validator-local `RunSmokeTest` and direct `fpc -iV` execution path
- Files created/modified:
  - `tests/test_fpc_mock_helpers.pas`
  - `tests/test_fpc_verify.lpr`
  - `tests/test_fpc_manager_installmetadata.lpr`
  - `tests/test_cli_fpc_diag.lpr`
  - `src/fpdev.fpc.validator.pas`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran `tests.test_fpc_verify_boundary`
  - Ran focused `/tmp` Pascal suites for manager/verify/validator/CLI paths
  - Re-ran the repository-standard Pascal regression suite
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Verify boundary RED | `python3 -m unittest tests.test_fpc_verify_boundary -v` | fail before helper extraction and validator refactor | 2 failures: missing shared helper adoption and missing `fpdev.fpc.verify` delegation | FAIL |
| Verify boundary suite | `python3 -m unittest tests.test_fpc_verify_boundary -v` | pass | 3 tests passed | OK |
| Install metadata focused suite | `fpc ... tests/test_fpc_manager_installmetadata.lpr && /tmp/.../test_fpc_manager_installmetadata` | pass | 25 passed, 0 failed | OK |
| Verify focused suite | `fpc ... tests/test_fpc_verify.lpr && /tmp/.../test_fpc_verify` | pass | `All tests passed` | OK |
| Validator runtimeflow focused suite | `fpc ... tests/test_fpc_validator_runtimeflow.lpr && /tmp/.../test_fpc_validator_runtimeflow` | pass | 24 passed, 0 failed | OK |
| CLI diag focused suite | `fpc ... tests/test_cli_fpc_diag.lpr && /tmp/.../test_cli_fpc_diag` | pass | 158 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Session: 2026-04-11 (fpc manager verify orchestration wave)

### Phase 1: Plan And RED
- **Status:** complete
- Actions taken:
  - Wrote the execution plan at `docs/plans/2026-04-11-fpc-manager-verify-orchestration-wave.md`
  - Added `tests/test_fpc_manager_verify_boundary.py` to lock manager-level verifyflow delegation
  - Ran the new manager boundary suite and confirmed RED before extraction
- Files created/modified:
  - `docs/plans/2026-04-11-fpc-manager-verify-orchestration-wave.md`
  - `tests/test_fpc_manager_verify_boundary.py`

### Phase 2: Verifyflow Extraction
- **Status:** complete
- Actions taken:
  - Added `src/fpdev.fpc.verifyflow.pas` for manager-level verify orchestration
  - Repointed `TFPCManager.VerifyInstalledExecutableVersion(...)` to shared verifyflow helper
  - Repointed `TFPCManager.RefreshInstallVerificationMetadata(...)` to shared verifyflow helper
  - Repointed `TFPCManager.VerifyInstallation(...)` metadata persistence to shared verifyflow helper
- Files created/modified:
  - `src/fpdev.fpc.verifyflow.pas`
  - `src/fpdev.fpc.manager.pas`

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran `tests.test_fpc_manager_verify_boundary` together with `tests.test_fpc_verify_boundary`
  - Ran focused `/tmp` Pascal suites for manager/verify/validator/CLI paths
  - Re-ran the repository-standard Pascal regression suite
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Manager verify boundary RED | `python3 -m unittest tests.test_fpc_manager_verify_boundary -v` | fail before verifyflow extraction | 3 failures: missing `fpdev.fpc.verifyflow`, missing shared flow calls, and remaining direct verifier construction | FAIL |
| Combined verify boundary suite | `python3 -m unittest tests.test_fpc_manager_verify_boundary tests.test_fpc_verify_boundary -v` | pass | 6 tests passed | OK |
| Install metadata focused suite | `fpc ... tests/test_fpc_manager_installmetadata.lpr && /tmp/.../test_fpc_manager_installmetadata` | pass | 25 passed, 0 failed | OK |
| Verify focused suite | `fpc ... tests/test_fpc_verify.lpr && /tmp/.../test_fpc_verify` | pass | `All tests passed` | OK |
| Validator runtimeflow focused suite | `fpc ... tests/test_fpc_validator_runtimeflow.lpr && /tmp/.../test_fpc_validator_runtimeflow` | pass | 24 passed, 0 failed | OK |
| CLI diag focused suite | `fpc ... tests/test_cli_fpc_diag.lpr && /tmp/.../test_cli_fpc_diag` | pass | 158 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Session: 2026-04-11 (fpc binary verify consolidation wave)

### Phase 1: Plan And Boundary Guardrails
- **Status:** complete
- Actions taken:
  - Added the execution plan at `docs/plans/2026-04-11-fpc-binary-verify-consolidation-wave.md`
  - Added `tests/test_fpc_binary_verify_boundary.py` to lock binary verifyflow delegation and legacy verifier removal
  - Re-ran the Python boundary/style bundle and confirmed the current tree satisfies the boundary contract
- Files created/modified:
  - `docs/plans/2026-04-11-fpc-binary-verify-consolidation-wave.md`
  - `tests/test_fpc_binary_verify_boundary.py`
  - `tests/test_style_regressions_batch16.py`

### Phase 2: Binary Verify Consolidation
- **Status:** complete
- Actions taken:
  - Extended `src/fpdev.fpc.verifyflow.pas` with binary-install verification and metadata helpers
  - Repointed `src/fpdev.fpc.binary.pas` to the shared verifyflow helpers instead of direct verifier orchestration
  - Removed `src/fpdev.fpc.verifier.pas`
  - Fixed the focused Pascal compile break by adding `fpdev.fpc.types` to `src/fpdev.fpc.binary.pas`
- Files created/modified:
  - `src/fpdev.fpc.verifyflow.pas`
  - `src/fpdev.fpc.binary.pas`
  - `src/fpdev.fpc.verifier.pas` (deleted)

### Phase 3: Verification
- **Status:** complete
- Actions taken:
  - Re-ran `tests.test_fpc_binary_verify_boundary` together with `tests.test_style_regressions_batch16`
  - Compiled and ran focused `/tmp` Pascal suites for binary installer and verifier paths
  - Re-ran the repository-standard Pascal regression suite
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Binary verify boundary + style suite | `python3 -m unittest tests.test_fpc_binary_verify_boundary tests.test_style_regressions_batch16 -v` | pass | 6 tests passed | OK |
| Binary installer unit suite | `fpc ... tests/test_binary_installer_unit.lpr` then `/tmp/.../test_binary_installer_unit` | pass | 24 passed, 0 failed | OK |
| Install integration focused suite | `fpc ... tests/test_fpc_install_integration.lpr` then `/tmp/.../test_fpc_install_integration` | pass | 27 passed, 0 failed | OK |
| Verifier focused suite | `fpc ... tests/test_fpc_verifier.lpr` then `/tmp/.../test_fpc_verifier` | pass | 7 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-11 | `tests/test_binary_installer_unit.lpr` compile failed with `Identifier not found "TVerificationResult"` in `src/fpdev.fpc.binary.pas` | 1 | Added explicit `fpdev.fpc.types` import after the verifyflow refactor to restore type visibility |


## Session: 2026-04-11 (fpc install offline cache orchestration downshift)

### Phase 1: Root Cause And Boundary Lock
- **Status:** complete
- Actions taken:
  - Reproduced `tests.test_fpc_install_cli_boundary` RED and confirmed CLI still owned `TBuildCache.Create` + manual restore/setup/verify orchestration
  - Confirmed `src/fpdev.fpc.installversionflow.pas` was in a compile-broken overload mismatch state
  - Added source offline cache-miss / restore-fail assertions in `tests/test_fpc_installversionflow.lpr`
- Files created/modified:
  - `tests/test_fpc_install_cli_boundary.py`
  - `tests/test_fpc_installversionflow.lpr`
  - `src/fpdev.fpc.installversionflow.pas`

### Phase 2: Shared Flow And Binary Installer Downshift
- **Status:** complete
- Actions taken:
  - Restored `src/fpdev.fpc.installversionflow.pas` to a valid overloaded API and threaded `AOfflineMode` through source install flow
  - Added `FOfflineMode` + `SetOfflineMode(...)` to `TFPCBinaryInstaller`
  - Moved binary cache-hit restore / offline miss / restore-fail handling into `src/fpdev.fpc.installer.pas`
- Files created/modified:
  - `src/fpdev.fpc.installversionflow.pas`
  - `src/fpdev.fpc.installer.pas`

### Phase 3: Manager And CLI Shrink
- **Status:** complete
- Actions taken:
  - Extended `TFPCManager.InstallVersion(...)` with optional `AOfflineMode`
  - Threaded offline mode into installer + shared install flow while preserving manager-owned verify metadata refresh
  - Removed command-layer cache object creation and manual restore/setup/verify from `src/fpdev.cmd.fpc.install.pas`
  - Preserved offline cache-first CLI behavior by skipping upfront version validation when `AOfflineMode=True`
- Files created/modified:
  - `src/fpdev.fpc.manager.pas`
  - `src/fpdev.cmd.fpc.install.pas`

### Phase 4: Behavior Coverage And Verification
- **Status:** complete
- Actions taken:
  - Added CLI coverage for offline cache-hit with `--prefix`
  - Added CLI coverage proving cache-hit verify warnings remain non-fatal and still backfill metadata
  - Added `CompileVersionMismatchMockFPCBinary(...)` helper for deterministic verify-warning setup
  - Re-ran focused boundary/Pascal suites and the repository-wide regression script
- Files created/modified:
  - `tests/test_fpc_mock_helpers.pas`
  - `tests/test_fpc_install_cli.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| CLI install boundary RED | `python3 -m unittest tests.test_fpc_install_cli_boundary -v` | fail before downshift | 1 failure on `TBuildCache.Create` in CLI | FAIL |
| CLI install boundary GREEN | `python3 -m unittest tests.test_fpc_install_cli_boundary -v` | pass | 1 test passed | OK |
| Shared install flow suite | `fpc ... tests/test_fpc_installversionflow.lpr && /tmp/.../test_fpc_installversionflow` | pass | 51 passed, 0 failed | OK |
| CLI install suite | `fpc ... tests/test_fpc_install_cli.lpr && /tmp/.../test_fpc_install_cli` | pass | 102 passed, 0 failed | OK |
| Install metadata suite | `fpc ... tests/test_fpc_manager_installmetadata.lpr && /tmp/.../test_fpc_manager_installmetadata` | pass | 25 passed, 0 failed | OK |
| Verify suite | `fpc ... tests/test_fpc_verify.lpr && /tmp/.../test_fpc_verify` | pass | `All tests passed` | OK |
| Install integration suite | `fpc ... tests/test_fpc_install_integration.lpr && /tmp/.../test_fpc_install_integration` | pass | 27 passed, 0 failed | OK |
| Boundary/style Python bundle | `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_binary_verify_boundary tests.test_style_regressions_batch16 -v` | pass | 7 tests passed | OK |
| Full regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-11 | `src/fpdev.fpc.installversionflow.pas` duplicated overload declarations and referenced `AOfflineMode` from the wrong signature | 1 | Re-split wrapper/new overload signatures and recompiled the unit before touching the rest of the chain |
| 2026-04-11 | `tests/test_fpc_install_cli.lpr` offline miss assertions regressed after CLI shrink because manager still validated version before offline cache lookup | 1 | Changed `TFPCManager.InstallVersion(...)` to preserve cache-first behavior in offline mode and re-ran focused CLI coverage |


## Session: 2026-04-11 (fpc install output and boundary wave)

### Phase 1: Plan And RED Coverage
- **Status:** complete
- Actions taken:
  - Wrote the execution plan at `docs/plans/2026-04-11-fpc-install-output-and-boundary-wave.md`
  - Added manager/installer boundary guards in `tests/test_fpc_install_manager_boundary.py` and `tests/test_fpc_installer_boundary.py`
  - Extended install CLI / flow tests to lock activation hint and offline/no-cache matrix behavior
- Files created/modified:
  - `docs/plans/2026-04-11-fpc-install-output-and-boundary-wave.md`
  - `tests/test_fpc_install_manager_boundary.py`
  - `tests/test_fpc_installer_boundary.py`
  - `tests/test_fpc_install_cli.lpr`
  - `tests/test_fpc_installversionflow.lpr`

### Phase 2: Output Ownership Consolidation
- **Status:** complete
- Actions taken:
  - Added `src/fpdev.fpc.installreportflow.pas` for shared fail/hint/success reporting
  - Moved the completion summary ownership to `src/fpdev.fpc.installversionflow.pas`
  - Shrunk `src/fpdev.fpc.installer.postinstall.pas` to layout/env/cache-only responsibilities
- Files created/modified:
  - `src/fpdev.fpc.installreportflow.pas`
  - `src/fpdev.fpc.installversionflow.pas`
  - `src/fpdev.fpc.installer.pas`
  - `src/fpdev.fpc.installer.postinstall.pas`
  - `tests/test_fpc_installer_postinstall.lpr`

### Phase 3: Docs Sync And Verification
- **Status:** complete
- Actions taken:
  - Updated `CHANGELOG.md` and both FPC management docs to reflect the current layering and API signature
  - Re-ran boundary/style/docs Python tests, focused Pascal suites, and the full repository regression script
  - Fixed the only regression found in the first full pass by updating the postinstall unit test to the new ownership boundary
- Files created/modified:
  - `CHANGELOG.md`
  - `docs/FPC_MANAGEMENT.md`
  - `docs/FPC_MANAGEMENT.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Install boundary/style/docs bundle | `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary tests.test_style_regressions_batch16 tests.test_contributor_docs_contract -v` | pass | 31 tests passed | OK |
| Shared install flow suite | `fpc ... tests/test_fpc_installversionflow.lpr && /tmp/.../test_fpc_installversionflow` | pass | 57 passed, 0 failed | OK |
| Install CLI suite | `fpc ... tests/test_fpc_install_cli.lpr && /tmp/.../test_fpc_install_cli` | pass | 111 passed, 0 failed | OK |
| Post-install suite | `fpc ... tests/test_fpc_installer_postinstall.lpr && /tmp/.../test_fpc_installer_postinstall` | pass | 28 passed, 0 failed | OK |
| Install metadata suite | `fpc ... tests/test_fpc_manager_installmetadata.lpr && /tmp/.../test_fpc_manager_installmetadata` | pass | 25 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-11 | First full regression run failed in `test_fpc_installer_postinstall` because the unit test still expected postinstall to print `Installation completed!` after the summary ownership moved to `installversionflow` | 1 | Updated `tests/test_fpc_installer_postinstall.lpr` to lock the new boundary: postinstall handles layout/env/cache only, while completion summary comes from `src/fpdev.fpc.installversionflow.pas` |


## Session: 2026-04-11 (install contract docs and lazarus wave)

### Phase 1: Plan And RED Coverage
- **Status:** complete
- Actions taken:
  - Wrote the execution plan at `docs/plans/2026-04-11-install-contract-docs-and-lazarus-wave.md`
  - Extended `tests/test_fpc_installer_binaryflow.lpr` with manifest/repo exception fallback and final fail-summary assertions
  - Added `tests/test_lazarus_install_boundary.py` and extended `tests/test_lazarus_flow.lpr` with success/activation output expectations
  - Extended `tests/test_contributor_docs_contract.py` to lock binary-first quickstarts, FAQ cache-mode guidance, README install wording, and manifest usage wording
- Files created/modified:
  - `docs/plans/2026-04-11-install-contract-docs-and-lazarus-wave.md`
  - `tests/test_fpc_installer_binaryflow.lpr`
  - `tests/test_lazarus_install_boundary.py`
  - `tests/test_lazarus_flow.lpr`
  - `tests/test_contributor_docs_contract.py`

### Phase 2: Minimal Implementation
- **Status:** complete
- Actions taken:
  - Updated `src/fpdev.fpc.installer.binaryflow.pas` so manifest/repo exceptions no longer short-circuit the fallback chain
  - Added a final binary acquisition failure summary when the entire FPC binary chain is exhausted
  - Added a Lazarus install success banner plus activation next-step output in `src/fpdev.lazarus.commandflow.pas`
- Files created/modified:
  - `src/fpdev.fpc.installer.binaryflow.pas`
  - `src/fpdev.lazarus.commandflow.pas`

### Phase 3: Docs Sync And Full Verification
- **Status:** complete
- Actions taken:
  - Synced root/docs quickstarts and FAQs to binary-first / offline / no-cache / explicit source wording
  - Updated `README.md` and `docs/MANIFEST-USAGE.md` to reflect current FPC/Lazarus install contract
  - Re-ran boundary/docs Python suites, focused Pascal suites, and the full repository regression script
- Files created/modified:
  - `README.md`
  - `FAQ.md`
  - `docs/FAQ.md`
  - `docs/FAQ.en.md`
  - `QUICKSTART.md`
  - `docs/QUICKSTART.md`
  - `docs/QUICKSTART.en.md`
  - `docs/MANIFEST-USAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| FPC binaryflow RED | `fpc ... tests/test_fpc_installer_binaryflow.lpr && /tmp/.../test_fpc_installer_binaryflow` | fail before fallback fix | 6 failures across manifest/repo exception fallback and final failure summary | FAIL |
| Lazarus install boundary RED | `python3 -m unittest tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract -v` | fail before success-output wiring | 1 failure (`fpdev lazarus use` ownership missing in commandflow) | FAIL |
| Lazarus flow RED | `fpc ... tests/test_lazarus_flow.lpr && /tmp/.../test_lazarus_flow` | fail before success banner | 3 failures on completion/activation output | FAIL |
| Contributor docs RED | `python3 -m unittest tests.test_contributor_docs_contract -v` | fail before doc sync | 4 failures across quickstart/FAQ/README/MANIFEST usage wording | FAIL |
| Boundary/docs Python bundle | `python3 -m unittest tests.test_fpc_install_cli_boundary tests.test_fpc_install_manager_boundary tests.test_fpc_installer_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract tests.test_contributor_docs_contract -v` | pass | 37 tests passed | OK |
| FPC binaryflow suite | `fpc ... tests/test_fpc_installer_binaryflow.lpr && /tmp/.../test_fpc_installer_binaryflow` | pass | 42 passed, 0 failed | OK |
| FPC install flow suite | `fpc ... tests/test_fpc_installversionflow.lpr && /tmp/.../test_fpc_installversionflow` | pass | 57 passed, 0 failed | OK |
| Lazarus flow suite | `fpc ... tests/test_lazarus_flow.lpr && /tmp/.../test_lazarus_flow` | pass | 37 passed, 0 failed | OK |
| Lazarus update suite | `fpc ... tests/test_lazarus_update.lpr && /tmp/.../test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 275 passed, 0 failed, 0 skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-11 | First parallel focused run reused the same `/tmp/fpdev-plan-bin` output directory, causing `test_lazarus_flow` compilation to fail with a missing output path | 1 | Re-ran each focused Pascal suite with its own `/tmp/fpdev-*-bin` and `/tmp/fpdev-*-lib` directory |
| 2026-04-11 | New contributor-doc assertions accidentally inherited two unrelated assertions after being inserted into `test_manifest_usage_mentions_binary_acquisition_fallback_and_cache_modes` | 1 | Removed the stray `/tmp/fpdev-test-bin` / `pytest` assertions from the new manifest test and re-ran the suite |

## Session: 2026-04-11 (lazarus manager metadataflow wave)

### Phase 1: Re-screen And Plan
- **Status:** complete
- Actions taken:
  - Re-read `using-superpowers`, `planning-with-files`, `systematic-debugging`, `brainstorming`, and `test-driven-development`
  - Ran session catch-up and re-read `task_plan.md`, `findings.md`, and `progress.md`
  - Re-checked the latest completed install wave and confirmed Phase 36 is already done in the current tree
  - Inspected `src/fpdev.cmd.lazarus.root.pas`, `src/fpdev.cmd.lazarus.install.pas`, `src/fpdev.command.imports.lazarus.pas`, and `src/fpdev.cmd.lazarus.pas`
  - Confirmed Lazarus CLI/root shell is no longer the main dispatch hotspot; the next real hotspot is `src/fpdev.lazarus.manager.pas`
  - Inspected manager responsibilities plus existing Lazarus workflow tests to pick `metadata/version inventory` as the next minimum slice
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: RED Tests And Minimal Slice
- **Status:** complete
- Actions taken:
  - Added `tests/test_lazarus_manager_metadata_boundary.py` to lock the new metadataflow delegation boundary
  - Added `tests/test_lazarus_manager_metadataflow.lpr` for direct helper coverage
  - Verified RED with 3 Python failures and `Fatal: Can't find unit fpdev.lazarus.types`
  - Added `src/fpdev.lazarus.types.pas` and `src/fpdev.lazarus.metadataflow.pas`
  - Rewired `src/fpdev.lazarus.manager.pas` to delegate configured metadata normalize/merge/filter work to metadataflow helpers
  - Updated `src/fpdev.cmd.lazarus.pas` to alias version-info types from the new types unit
- Files created/modified:
  - `tests/test_lazarus_manager_metadata_boundary.py`
  - `tests/test_lazarus_manager_metadataflow.lpr`
  - `src/fpdev.lazarus.types.pas`
  - `src/fpdev.lazarus.metadataflow.pas`
  - `src/fpdev.lazarus.manager.pas`
  - `src/fpdev.cmd.lazarus.pas`

### Phase 3: Docs Sync And Verification
- **Status:** complete
- Actions taken:
  - Synced `docs/history/B171-large-files-report.md` to the new 2026-04-11 Lazarus hotspot truth
  - Updated `tests/test_contributor_docs_contract.py` for the new manager line count and metadataflow helper row
  - Ran `scripts/run_prettier.sh --write/--check` for `docs/history/B171-large-files-report.md`
  - Re-ran focused Python boundary/docs suites and focused Pascal Lazarus suites
  - Re-ran the full repository regression script and confirmed `276/276` pass
- Files created/modified:
  - `docs/history/B171-large-files-report.md`
  - `tests/test_contributor_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Route re-screen | `search_context` + source inspection | identify next highest-leverage unfinished slice | install wave already complete; next hotspot is `src/fpdev.lazarus.manager.pas` metadata/version inventory | OK |
| Lazarus metadata boundary RED | `python3 -m unittest tests.test_lazarus_manager_metadata_boundary -v` | fail before metadataflow extraction | 3 failures on missing metadataflow/types/helper delegation | FAIL |
| Lazarus metadataflow RED | `fpc ... tests/test_lazarus_manager_metadataflow.lpr` | fail before new units exist | `Fatal: Can't find unit fpdev.lazarus.types` | FAIL |
| Lazarus metadata boundary GREEN | `python3 -m unittest tests.test_lazarus_manager_metadata_boundary -v` | pass | 3 tests passed | OK |
| Lazarus metadataflow suite | `fpc ... tests/test_lazarus_manager_metadataflow.lpr && /tmp/.../test_lazarus_manager_metadataflow` | pass | 11 passed, 0 failed | OK |
| Lazarus boundary/docs Python bundle | `python3 -m unittest tests.test_lazarus_manager_metadata_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract tests.test_contributor_docs_contract -v` | pass | 37 tests passed | OK |
| Lazarus configure workflow suite | `fpc ... tests/test_lazarus_configure_workflow.lpr && /tmp/.../test_lazarus_configure_workflow` | pass | 51 passed, 0 failed | OK |
| Lazarus update suite | `fpc ... tests/test_lazarus_update.lpr && /tmp/.../test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| Lazarus CLI suite | `fpc ... tests/test_cli_lazarus.lpr && /tmp/.../test_cli_lazarus` | pass | 143 passed, 0 failed | OK |
| Lazarus management suite | `fpc ... tests/test_lazarus_management.lpr && /tmp/.../test_lazarus_management` | pass | 23 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 276 passed, 0 failed, 0 skipped | OK |
| Large-file report prettier check | `bash scripts/run_prettier.sh --check docs/history/B171-large-files-report.md` | pass | pass after `--write` | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-11 | First attempt to append Phase 37 to `task_plan.md` failed because the tail context differed from the cached summary | 1 | Re-read the actual tail of `task_plan.md` and patched against the live file |
| 2026-04-11 | First RED compile for `test_lazarus_manager_metadataflow.lpr` failed on missing `/tmp` output directory instead of the missing unit itself | 1 | Created dedicated `/tmp/fpdev-lazarus-metadata-*-red` directories and re-ran until the failure returned to `Can't find unit fpdev.lazarus.types` |
| 2026-04-11 | `tests.test_contributor_docs_contract` failed after running Prettier because the table assertions depended on raw spacing rather than content | 1 | Switched those assertions to regex-based spacing-agnostic matches, then re-ran the Python bundle successfully |


## Session: 2026-04-12 (Lazarus source slicing wave)

### Phase 43: Planning & Discovery
- **Status:** complete
- **Started:** 2026-04-12
- Actions taken:
  - Re-read active roadmap, planning files, and the existing `docs/plans/2026-04-12-lazarus-source-slicing-wave.md`
  - Re-scanned `src/fpdev.lazarus.source.pas` plus current Lazarus helper units and focused tests
  - Chose the smallest next cut: extract clone/update preflight + build make-param assembly into new `fpdev.lazarus.sourceflow`
  - Rewrote `docs/plans/2026-04-12-lazarus-source-slicing-wave.md` into a detailed executable plan
- Files created/modified:
  - `docs/plans/2026-04-12-lazarus-source-slicing-wave.md`
  - `findings.md`
  - `progress.md`

### Phase 43: RED, GREEN, And Verification
- **Status:** complete
- Actions taken:
  - Added `tests/test_lazarus_source_boundary.py` to lock `fpdev.lazarus.source` -> `fpdev.lazarus.sourceflow` delegation
  - Added `tests/test_lazarus_sourceflow.lpr` for direct helper coverage
  - Verified RED first with 4 Python boundary failures and then with `Fatal: Can't find unit fpdev.lazarus.sourceflow`
  - Added `src/fpdev.lazarus.sourceflow.pas`
  - Rewired `src/fpdev.lazarus.source.pas` to delegate source-path, source-tree validation, clone/update plans, and build make params to the new helper unit
  - Re-ran focused boundary/direct/source suites and the full repository regression baseline
- Files created/modified:
  - `src/fpdev.lazarus.sourceflow.pas`
  - `src/fpdev.lazarus.source.pas`
  - `tests/test_lazarus_source_boundary.py`
  - `tests/test_lazarus_sourceflow.lpr`
  - `docs/plans/2026-04-12-lazarus-source-slicing-wave.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Lazarus source boundary RED | `python3 -m unittest tests.test_lazarus_source_boundary -v` | fail before helper extraction | 4 failures on missing sourceflow import/delegation | FAIL |
| Lazarus sourceflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceflow-bin-red -FU/tmp/fpdev-lazarus-sourceflow-lib-red tests/test_lazarus_sourceflow.lpr` | fail before helper extraction | `Fatal: Can't find unit fpdev.lazarus.sourceflow` | FAIL |
| Lazarus source boundary GREEN | `python3 -m unittest tests.test_lazarus_source_boundary -v` | pass | 4 tests passed | OK |
| Lazarus sourceflow suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceflow-bin -FU/tmp/fpdev-lazarus-sourceflow-lib tests/test_lazarus_sourceflow.lpr && bash -lc /tmp/fpdev-lazarus-sourceflow-bin/test_lazarus_sourceflow` | pass | 18 passed, 0 failed | OK |
| Lazarus update suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr && bash -lc /tmp/fpdev-lazarus-update-bin/test_lazarus_update` | pass | 150 passed, 0 failed | OK |
| Lazarus flow suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr && bash -lc /tmp/fpdev-lazarus-flow-bin/test_lazarus_flow` | pass | 37 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | 282 passed, 0 failed, 0 skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-12 | First RED compile for `tests/test_lazarus_sourceflow.lpr` failed on missing `/tmp/fpdev-lazarus-sourceflow-bin-red` output directory instead of the missing unit itself | 1 | Created dedicated `/tmp/fpdev-lazarus-sourceflow-*-red` directories and re-ran until the failure returned to `Can't find unit fpdev.lazarus.sourceflow` |
| 2026-04-12 | Running `/tmp/fpdev-lazarus-sourceflow-bin/test_lazarus_sourceflow` directly through `zsh` returned `no such file or directory` despite a successful link step | 1 | Verified the binary existed and executed it successfully with `bash -lc /tmp/fpdev-lazarus-sourceflow-bin/test_lazarus_sourceflow` |


## Session: 2026-04-13 (post-project hotspot re-evaluation)

### Phase 63: Re-Ranking The Next Highest-ROI Wave
- **Status:** complete
- Actions taken:
  - Re-read `task_plan.md`、`findings.md`、`progress.md` 与当前 2026-04-13 wave closure
  - Recomputed current hotspot line counts for `fpc.manager`、`resource.repo`、`lazarus.source`、`project.manager`、`package.manager`、`cross.search`
  - Inspected remaining method bodies in `src/fpdev.lazarus.source.pas`、`src/fpdev.resource.repo.pas`、`src/fpdev.fpc.manager.pas`
  - Cross-checked `src/fpdev.project.manager.pas`、`src/fpdev.package.manager.pas`、`src/fpdev.cross.search.pas` to confirm whether they still justify a new wave
  - Re-ranked the next wave by real ROI:
    - `lazarus.source` runtime/config surface
    - `resource.repo` bootstrap/install/checksum surface
    - `fpc.manager` residual callback glue
  - Confirmed `project.manager`、`package.manager`、`cross.search` remain checkpoint-only for now
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Hotspot re-evaluation | source inspection + method/line recount | identify next highest-ROI unfinished slices | ranking settled as `lazarus.source` -> `resource.repo` -> `fpc.manager`; project/package/cross remain checkpoints | OK |

## Notes
- 本阶段是 planning-only sync，没有修改业务代码，因此没有重新跑 focused / full regression。

## Session: 2026-04-13 (cross manager install/uninstall wave)

### Phase 69: Plan Sync And RED Coverage
- **Status:** complete
- Actions taken:
  - Wrote the execution plan at `docs/plans/2026-04-13-cross-manager-install-uninstall-wave.md`
  - Re-screened the current tree and corrected the hotspot ranking:
    - `resource.repo lifecycle` already mostly lives in `resource.repo.lifecycle/statusflow`
    - `package.manager tail` already mostly lives in `package.facadeflow`
    - the true next highest-ROI cut is `src/fpdev.cross.manager.pas` install/uninstall orchestration
  - Extended `tests/test_cross_manager_boundary.py` to lock install/uninstall delegation
  - Extended `tests/test_cross_managerflow.lpr` with direct install/uninstall helper coverage
  - Verified RED with the new boundary and helper tests
- Files created/modified:
  - `docs/plans/2026-04-13-cross-manager-install-uninstall-wave.md`
  - `tests/test_cross_manager_boundary.py`
  - `tests/test_cross_managerflow.lpr`
  - `task_plan.md`

### Phase 70: Minimal Implementation
- **Status:** complete
- Actions taken:
  - Added `ExecuteCrossInstallTargetCore(...)` and `ExecuteCrossUninstallTargetCore(...)` to `src/fpdev.cross.managerflow.pas`
  - Added wrapper callbacks in `src/fpdev.cross.manager.pas` for system compiler detection, package-manager instructions, and config removal
  - Rewired `InstallTarget(...)` and `UninstallTarget(...)` so `TCrossCompilerManager` is now a thin delegate over managerflow
- Files created/modified:
  - `src/fpdev.cross.managerflow.pas`
  - `src/fpdev.cross.manager.pas`

### Phase 71: Focused Verification
- **Status:** complete
- Actions taken:
  - Re-ran the Python boundary suite for cross manager delegation
  - Compiled and ran `tests/test_cross_managerflow.lpr`
  - Compiled and ran `tests/test_cross_management.lpr`
- Files created/modified:
  - `task_plan.md`

### Phase 72: Full Regression And Planning Sync
- **Status:** complete
- Actions taken:
  - Re-ran `bash scripts/run_all_tests.sh`
  - Synced `task_plan.md`, `findings.md`, and `progress.md` to the corrected hotspot conclusion and final verification evidence
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Cross manager boundary RED | `python3 -m unittest tests.test_cross_manager_boundary -v` | fail before install/uninstall delegate extraction | 1 failure: `InstallTarget(...)` still lacked `ExecuteCrossInstallTargetCore(...)` delegation | FAIL |
| Cross managerflow RED | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin-red -FU/tmp/fpdev-cross-managerflow-lib-red tests/test_cross_managerflow.lpr` | fail before new helper implementation | 7 compile errors on missing `ExecuteCrossInstallTargetCore` / `ExecuteCrossUninstallTargetCore` | FAIL |
| Cross manager boundary GREEN | `python3 -m unittest tests.test_cross_manager_boundary -v` | pass | 4 tests passed | OK |
| Cross managerflow suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-managerflow-bin -FU/tmp/fpdev-cross-managerflow-lib tests/test_cross_managerflow.lpr && bash -lc /tmp/fpdev-cross-managerflow-bin/test_cross_managerflow` | pass | 71 passed, 0 failed | OK |
| Cross management suite | `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cross-management-bin -FU/tmp/fpdev-cross-management-lib tests/test_cross_management.lpr && bash -lc /tmp/fpdev-cross-management-bin/test_cross_management` | pass | 32 passed, 0 failed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | Total: 300 / Passed: 300 / Failed: 0 / Skipped: 0 | OK |

## Session: 2026-04-14 (next wave pack planning)

### Phase 73: 2026-04-14 Wave Pack Planning
- **Status:** complete (superseded by later completed wave pack phases)
- **Started:** 2026-04-14
- Actions taken:
  - 重新读取 `task_plan.md`、`findings.md`、`progress.md` 与上一轮 `cross.manager` 收口结果
  - 结合当前真实行数重新排序下一组 ROI 最高切口，确认本轮应优先推进：
    - `src/fpdev.fpc.source.pas`
    - `src/fpdev.fpc.builder.pas`
    - `src/fpdev.build.manager.pas`
  - 新增三份正式计划文档：
    - `docs/plans/2026-04-14-fpc-source-surface-wave.md`
    - `docs/plans/2026-04-14-fpc-builder-surface-wave.md`
    - `docs/plans/2026-04-14-build-manager-surface-wave.md`
  - 将 `fpc.manager` / `resource.repo` / `package.manager` / `lazarus.source` / `cross.*` 统一降为 checkpoint 或后续波次
  - 启动前同步 `findings.md` / `progress.md`，为接下来的 gpt-5.4 并行实施留出清晰 ownership 边界
  - 已拉起 3 个 `gpt-5.4` worker 并行实施：
    - Worker 1：`fpc.source`
    - Worker 2：`fpc.builder`
    - Worker 3：`build.manager`
- Files created/modified:
  - `docs/plans/2026-04-14-fpc-source-surface-wave.md` (created)
  - `docs/plans/2026-04-14-fpc-builder-surface-wave.md` (created)
  - `docs/plans/2026-04-14-build-manager-surface-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Wave-pack re-ranking | planning file review + hotspot recount | identify next highest-ROI unfinished slices | ranking settled as `fpc.source` -> `fpc.builder` -> `build.manager`; remaining units downgraded to checkpoints | OK |

## Notes
- 本阶段先做 planning sync；下一步直接拉起 3 个 `gpt-5.4` worker 并行实施各自 wave，再回到主控做集成与验证。

### Phase 74: FPC Source Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 由 `gpt-5.4` worker 起草并落地 `sourceinstallflow` / `sourcebootstrapflow` / `sourcebuildflow`
  - 主控复核并保留最小 helper 边界：
    - install sequencing / rollback / cache-hit branch
    - bootstrap ensure + download/extract orchestration
    - build/cache validation + reuse
  - 将 `src/fpdev.fpc.source.pas` 的 install/bootstrap/build/cache surface 全部回接到新 helper
  - 独立重跑 source focused suites，确认 worker 回报不是“口头完成”
- Files created/modified:
  - `src/fpdev.fpc.source.pas`
  - `src/fpdev.fpc.sourceinstallflow.pas` (created)
  - `src/fpdev.fpc.sourcebootstrapflow.pas` (created)
  - `src/fpdev.fpc.sourcebuildflow.pas` (created)
  - `tests/test_fpc_source_boundary.py` (created)
  - `tests/test_fpc_sourceinstallflow.lpr` (created)
  - `tests/test_fpc_sourcebootstrapflow.lpr` (created)
  - `tests/test_fpc_sourcebuildflow.lpr` (created)

### Phase 75: FPC Builder Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 接管并收口 `builderflow` helper 草稿，补齐 facade 回接与 callback wrapper
  - 新增 `src/fpdev.fpc.builderflow.pas`，承接：
    - bootstrap ensure orchestration
    - build-from-source sequencing
  - 为 builder facade 增补最小 wrapper：
    - resource repo ensure/query/install bridge
    - source tree prepare
    - build plan resolve / execute
  - 新增 boundary/direct tests 并修正 direct helper 断言到真实错误文本
- Files created/modified:
  - `src/fpdev.fpc.builder.pas`
  - `src/fpdev.fpc.builderflow.pas` (created)
  - `tests/test_fpc_builder_boundary.py` (created)
  - `tests/test_fpc_builderflow.lpr` (created)

### Phase 76: Build Manager Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 接管并完成 `build.managerflow` 回接
  - 新增 `src/fpdev.build.managerflow.pas`，承接：
    - make-operation wrapper
    - preflight wrapper
    - test-results wrapper
  - 将 `src/fpdev.build.manager.pas` 的 make/test/preflight surface 改为 delegate
  - 纠正 focused verification 中的真实主 suite 路径：`tests/fpdev.build.manager/test_build_manager.lpr`
- Files created/modified:
  - `src/fpdev.build.manager.pas`
  - `src/fpdev.build.managerflow.pas` (created)
  - `tests/test_build_manager_boundary.py` (created)
  - `tests/test_build_managerflow.lpr` (created)

### Phase 77: Integration + Full Verification
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 主控汇总 3 个 worker 产物并在本地完成剩余回接/修补
  - 先跑 source / builder / build-manager focused suites
  - 再跑整仓回归：`bash scripts/run_all_tests.sh`
  - 记录 baseline 升级为 `305/305`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Source boundary | `python3 -m unittest tests.test_fpc_source_boundary -v` | pass | 4 tests passed | OK |
| Source installflow | `tests/test_fpc_sourceinstallflow.lpr` | pass | 12 passed, 0 failed | OK |
| Source bootstrapflow | `tests/test_fpc_sourcebootstrapflow.lpr` | pass | 12 passed, 0 failed | OK |
| Source buildflow | `tests/test_fpc_sourcebuildflow.lpr` | pass | 8 passed, 0 failed | OK |
| Source repo regression | `tests/test_fpc_source_repo.lpr` | pass | 159 passed, 0 failed | OK |
| Bootstrap downloader | `tests/test_bootstrap_downloader.lpr` | pass | 9 passed, 0 failed, network test skipped as designed | OK |
| Builder boundary | `python3 -m unittest tests.test_fpc_builder_boundary -v` | pass | 3 tests passed | OK |
| Builder flow | `tests/test_fpc_builderflow.lpr` | pass | 15 passed, 0 failed | OK |
| Builder regressions | `tests/test_fpc_builder.lpr`, `tests/test_fpc_builder_bootstrapcompat.lpr`, `tests/test_fpc_builder_buildplan.lpr` | pass | 90 passed / 13 passed / 6 passed | OK |
| Build manager boundary | `python3 -m unittest tests.test_build_manager_boundary tests.test_build_manager_callback_contract -v` | pass | 5 tests passed | OK |
| Build manager flow | `tests/test_build_managerflow.lpr` | pass | 34 passed, 0 failed | OK |
| Build manager regressions | `tests/fpdev.build.manager/test_build_manager.lpr`, `tests/test_build_fullbuildflow.lpr`, `tests/test_build_preflightflow.lpr`, `tests/test_build_testresultsflow.lpr` | pass | OK / 12 passed / 21 passed / 29 passed | OK |
| Full Pascal regression | `bash scripts/run_all_tests.sh` | pass | Total: 305 / Passed: 305 / Failed: 0 / Skipped: 0 | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-14 | Several focused `fpc` compile commands failed immediately because `/tmp/...-bin` / `/tmp/...-lib` output directories did not exist yet | 1 | Created the target `/tmp` directories with `mkdir -p` before rerunning the compile+execute commands |
| 2026-04-14 | `tests/test_fpc_builderflow.lpr` first failed because direct helper assertion expected `Source directory not found`, while actual message was `Source directory does not exist` | 1 | Relaxed the assertion to match the stable `Source directory` prefix and reran the direct helper suite successfully |

### Phase 87: Runtime/Lifecycle/Bootstrap Wave Pack Planning
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 重新核对 `src/fpdev.build.manager.pas`、`src/fpdev.resource.repo.pas`、`src/fpdev.fpc.manager.pas` 的剩余 inline surface
  - 新增三份正式计划文档：
    - `docs/plans/2026-04-14-build-manager-runtime-toolchain-wave.md`
    - `docs/plans/2026-04-14-resource-repo-repoio-lifecycle-wave.md`
    - `docs/plans/2026-04-14-fpc-manager-bootstrap-residual-wave.md`
  - 将当前 wave pack 的并发 ownership 固定为：
    - Worker 1：`build.manager`
    - Worker 2：`resource.repo`
    - Worker 3：`fpc.manager`
  - 尝试拉起 `gpt-5.4` worker 时，外部 API 返回 `401 API_KEY_DISABLED`
  - 因此切回本地主控分波实施，同时继续保留 planning files ownership，并负责最终验证收口
- Files created/modified:
  - `docs/plans/2026-04-14-build-manager-runtime-toolchain-wave.md` (created)
  - `docs/plans/2026-04-14-resource-repo-repoio-lifecycle-wave.md` (created)
  - `docs/plans/2026-04-14-fpc-manager-bootstrap-residual-wave.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 88: Build Manager Runtime Toolchain Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_build_manager_boundary.py`，锁定 `CheckToolchain(...)`、`ApplyConfig(...)`、`RunMake(...)`、`CreateBuildStamp(...)` 必须委托新的 runtime helper
  - 新增 `tests/test_build_runtimeflow.lpr`，直接覆盖 toolchain probe、process execution、config 应用、stamp 写入等 runtime/toolchain glue
  - 新增 `src/fpdev.build.runtimeflow.pas`
  - 让 `src/fpdev.build.manager.pas` 的 runtime/toolchain surface 收缩为 thin delegate，同时保留 manager state ownership
  - focused 验证通过：`tests/test_build_runtimeflow.lpr`、`tests/test_build_makeflow.lpr`、`tests/test_build_managerflow.lpr`、`tests/fpdev.build.manager/test_build_manager.lpr`
- Files created/modified:
  - `src/fpdev.build.runtimeflow.pas` (created)
  - `src/fpdev.build.manager.pas`
  - `tests/test_build_manager_boundary.py`
  - `tests/test_build_runtimeflow.lpr` (created)

### Phase 89: Resource Repo Repo-IO Lifecycle Wave
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_resource_repo_boundary.py`，锁定 `GitClone(...)`、`GitPull(...)`、`LoadManifest(...)`、`GetManifestVersion(...)`、`HasPackage(...)` 必须委托 lifecycle helper
  - 新增 `tests/test_resource_repo_lifecyclesurfaceflow.lpr` 与 `src/fpdev.resource.repo.lifecycleflow.pas`
  - 让 `src/fpdev.resource.repo.pas` 的 repo-io/lifecycle surface 收缩为 thin delegate，同时保持 git backend / manifest state ownership
  - 补出 `ApplyLoadedResourceRepoManifestStateCore(...)`，把 manifest state 回填从 repo facade 进一步收口到 helper 路径
  - focused 验证通过：`tests/test_resource_repo_lifecyclesurfaceflow.lpr`、`tests/test_resource_repo_lifecycleflow.lpr`、`tests/test_package_resource_flow.lpr`
- Files created/modified:
  - `src/fpdev.resource.repo.lifecycleflow.pas` (created)
  - `src/fpdev.resource.repo.pas`
  - `tests/test_resource_repo_boundary.py`
  - `tests/test_resource_repo_lifecyclesurfaceflow.lpr` (created)

### Phase 90: FPC Manager Bootstrap Residual + Verification
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 扩展 `tests/test_fpc_manager_bootstrap_boundary.py`，锁定 `EnsureBootstrapCompiler(...)` 必须委托新的 bootstrap surface helper
  - 新增 `tests/test_fpc_bootstrapflow.lpr` 与 `src/fpdev.fpc.bootstrapflow.pas`
  - 让 `src/fpdev.fpc.manager.pas` 的 `EnsureBootstrapCompiler(...)` 收缩为 thin delegate，并通过 wrapper callback 保留 builder/installer ownership
  - focused 验证通过：`python3 -m unittest tests.test_build_manager_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v`、`tests/test_fpc_bootstrapflow.lpr`、`tests/test_fpc_installer_binaryflow.lpr`、`tests/test_fpc_sourcebootstrapflow.lpr`
  - 运行整仓回归：`bash scripts/run_all_tests.sh`
  - 记录整仓结果 `313/313`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `src/fpdev.fpc.bootstrapflow.pas` (created)
  - `src/fpdev.fpc.manager.pas`
  - `tests/test_fpc_manager_bootstrap_boundary.py` (created)
  - `tests/test_fpc_bootstrapflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 91: Broad Verification Closure
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 重新评估当前剩余热点，确认 `project/package/resource/build/fpc/lazarus` 当前公开 surface 大多已变成 thin delegate 或低风险 wrapper，继续硬拆单个小方法的 ROI 明显下降
  - 运行 Python 全量回归：`python3 -m unittest discover -s tests -p 'test_*.py'`
  - 记录 Python 结果 `533/533`
  - 运行工具链检查：`bash scripts/check_toolchain.sh`
  - 记录工具链状态：required 全部可用，optional 缺 `mingw32-make` / `ppc386` / `ppcarm`
  - 运行标准主程序构建：`lazbuild -B fpdev.lpi`
  - 命中真实环境阻塞：仓库 `lib/` 目录属主为 `root:root`，`lazbuild` 无法写入 `lib/fpdev.compiled`
  - 在不能无密码提权修复属主的前提下，改用 fallback 编译验证：
    - `mkdir -p /tmp/fpdev-main-lib /tmp/fpdev-main-bin`
    - `fpc -Fusrc -Fisrc -Fu./src -FE/tmp/fpdev-main-bin -FU/tmp/fpdev-main-lib src/fpdev.lpr`
  - 记录 fallback 编译结果：主程序完整编译并链接成功，仅 1 条 warning，无编译错误
  - 运行 CLI smoke：`bash scripts/cli_smoke.sh /tmp/fpdev-main-bin/fpdev`
  - 记录 CLI smoke 结果通过
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 92: Build Baseline Guardrail Closure
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 读取 `docs/plans/2026-04-14-build-baseline-guardrail-closure-wave.md` 并按其顺序实施
  - 先对 root-owned 旧 `bin/` / `lib/` 做仓库内隐藏重命名备份，再重建新的当前用户可写 `bin/` / `lib/`
  - 重新运行标准构建，确认 `lazbuild -B fpdev.lpi` 已恢复通过，不再命中 `lib/fpdev.compiled` 权限阻塞
  - 扩展 `scripts/check_toolchain.sh`，新增 `repo_bin_writable` / `repo_lib_writable` required guardrail 与 `FPDEV_TOOLCHAIN_REPO_ROOT` 测试 override
  - 扩展 `src/fpdev.toolchain.pas`，让 `BuildToolchainReportJSON` 在识别到 repo root 时输出 repo build output readiness，并在不可写时提升 `level=FAIL`
  - 先做 TDD RED：
    - `tests/test_check_toolchain_sh.py` 初次运行 2 个失败
    - `tests/test_toolchain.lpr` 初次失败在缺少 temp dir helper，随后修正测试夹具后稳定 RED 到缺失 `repo_bin_writable`
    - `tests/test_command_registry.lpr` 稳定 RED 到缺失 repo build output entry
  - 新增/扩展测试：
    - `tests/test_check_toolchain_sh.py`
    - `tests/test_toolchain.lpr`
    - `tests/test_command_registry.lpr`
  - 跑 focused 验证：
    - `python3 -m unittest tests.test_check_toolchain_sh -v` → `2 passed`
    - `tests/test_toolchain.lpr` → `12 passed`
    - `tests/test_command_registry.lpr` → `397 passed`
    - `bash scripts/check_toolchain.sh` → required `0 miss`, optional `3 miss`
  - 跑 broad verification：
    - `lazbuild -B fpdev.lpi` → pass
    - `bash scripts/cli_smoke.sh ./bin/fpdev` → pass
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `535 passed`
    - `bash scripts/run_all_tests.sh` → `313 passed`
  - 重新评估当前 ROI：本轮 closure 之后，没有比“恢复标准构建基线并将环境问题 guardrail 化”更高 ROI 的立即后续切口，下一波应重新 scan
- Files created/modified:
  - `scripts/check_toolchain.sh`
  - `src/fpdev.toolchain.pas`
  - `tests/test_toolchain.lpr`
  - `tests/test_command_registry.lpr`
  - `tests/test_check_toolchain_sh.py` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 旧 root-owned 备份目录当前仍保留在仓库根：
    - `.bin.root-owned-20260414_190837`
    - `.lib.root-owned-20260414_190837`
  - 多次尝试将它们移到 `/tmp`、`$HOME/.cache`、仓库上级目录都返回 `Permission denied`
  - 这些隐藏备份目录不再影响新的 `bin/` / `lib` 构建路径

### Phase 93: Toolchain Parity / Docs / Hotspot Recheck Closure
- **Status:** complete
- **Started:** 2026-04-14
- Actions taken:
  - 新增正式计划：`docs/plans/2026-04-14-toolchain-parity-docs-and-hotspot-recheck-closure.md`
  - 先验证文档确实过期：
    - `grep -n "repo_bin_writable\\|repo_lib_writable\\|FPDEV_TOOLCHAIN_REPO_ROOT" docs/toolchain.md docs/toolchain.en.md`
    - 结果：无匹配
  - 按 TDD 先新增 Windows parity contract test：`tests/test_check_toolchain_bat.py`
  - 跑 RED：
    - `python3 -m unittest tests.test_check_toolchain_bat -v`
    - 结果：`4` 个失败，确认 `.bat` 尚未包含 `FPDEV_TOOLCHAIN_REPO_ROOT` / `repo_bin_writable` / `repo_lib_writable` / `Build outputs:`
  - 实现收口改动：
    - 更新 `scripts/check_toolchain.bat`
    - 更新 `docs/toolchain.md`
    - 更新 `docs/toolchain.en.md`
    - 更新 `.gitignore`
  - 跑 focused 验证：
    - `python3 -m unittest tests.test_check_toolchain_bat -v` → `5 passed`
    - `grep -n "repo_bin_writable\\|repo_lib_writable\\|FPDEV_TOOLCHAIN_REPO_ROOT" docs/toolchain.md docs/toolchain.en.md` → 中英文文档均命中新字段
    - `git status --short -- .bin.root-owned-20260414_190837 .lib.root-owned-20260414_190837` → 空输出，说明 ignore 生效
  - 做 fresh hotspot recheck：
    - 重新扫描 `build.manager`、`resource.repo`、`fpc.manager`、`lazarus/project/package`
    - 结合最新行数和剩余方法分组，确认若下一轮继续推进，唯一仍明确成组的高 ROI 候选是 `build.manager` residual runtime/toolchain surface
    - 本轮不继续强开新 wave，改为把重排结论收口进 planning files
  - 跑最终验证：
    - `python3 -m unittest tests.test_check_toolchain_sh tests.test_check_toolchain_bat -v` → `7 passed`
    - `bash scripts/check_toolchain.sh` → pass，required `0 miss`
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `540 passed`
    - `bash scripts/run_all_tests.sh` → `313 passed`
- Files created/modified:
  - `docs/plans/2026-04-14-toolchain-parity-docs-and-hotspot-recheck-closure.md` (created)
  - `scripts/check_toolchain.bat`
  - `docs/toolchain.md`
  - `docs/toolchain.en.md`
  - `.gitignore`
  - `tests/test_check_toolchain_bat.py` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - Windows batch parity 本轮通过静态 contract test 收口；当前 Linux 环境没有直接执行 `.bat` 的验证通道
  - 若下一轮继续推进，应直接以 `src/fpdev.build.manager.pas` 的 residual runtime/toolchain surface 为唯一优先目标，而不是并发 reopen 多个管理器单元

### Phase 94: Architecture / Contract / Planning Sync Closure
- **Status:** complete
- **Started:** 2026-04-15
- Actions taken:
  - 重新核对 `docs/ARCHITECTURE.md`、`docs/ARCHITECTURE.en.md` 与当前 worktree 中已经落地的 facade/helper split，确认架构总览文档尚未覆盖 `build.manager` / `fpc.builder` / `fpc.binary` / `fpc install-use-verify commandflow` 的最新 helper 拆分
  - 先做 TDD RED：扩展 `tests/test_contributor_docs_contract.py`，要求中英文架构文档必须新增当前 split section，并显式提到 `src/fpdev.build.managerflow.pas`、`src/fpdev.build.runtimeflow.pas`、`src/fpdev.fpc.builderflow.pas`、`src/fpdev.fpc.binaryflow.pas`、`src/fpdev.fpc.installcommandflow.pas`、`src/fpdev.fpc.usecommandflow.pas`、`src/fpdev.fpc.verifycommandflow.pas`
  - 运行 `python3 -m unittest tests.test_contributor_docs_contract -v`，确认新增 contract 在文档未同步前稳定 RED
  - 更新 `docs/ARCHITECTURE.md` 与 `docs/ARCHITECTURE.en.md`，新增 `2026-04` current-worktree facade/helper split section，把 command facade 与 service facade 的对应关系写实落盘
  - 复跑 docs contract，确认 contributor docs suite 转绿
  - 运行 focused Python boundary bundle，确认 `build.manager` / `fpc.builder` / `fpc.binary` / `fpc install CLI` 的既有 thin-facade contract 仍然成立
  - 运行 broad verification：
    - `python3 -m unittest discover -s tests -p 'test_*.py'` → `557 passed`
    - `bash scripts/run_all_tests.sh` → `320 passed`
    - `bash scripts/check_toolchain.sh` → required `0` missing
    - `lazbuild -B fpdev.lpi` → pass
  - 同步 `task_plan.md`、`findings.md`、`progress.md`，把 architecture/contract/planning closure 与最新 green baseline 一次性写回
- Files created/modified:
  - `tests/test_contributor_docs_contract.py`
  - `docs/ARCHITECTURE.md`
  - `docs/ARCHITECTURE.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 本轮目标是“架构文档真相同步 + contract 锁定 + 基线复核”，不额外打开新的 helper extraction wave
  - 若后续继续推进，应重新基于当时工作树做 fresh ROI 排序，而不是继续依赖过期的 architecture 文档假设

### Phase 95: FPC Sourceflow Residual Wave
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 新增正式计划：`docs/plans/2026-04-16-fpc-sourceflow-residual-wave.md`
  - 先按 TDD 复核 RED 输入：
    - `tests/test_fpc_source_boundary.py` 已扩充为要求 `src/fpdev.fpc.source.pas` 引入 `fpdev.fpc.sourceflow`
    - `tests/test_fpc_sourceflow.lpr` 已新增 clone/update/switch/list/prereq direct helper 契约
  - 实现收口改动：
    - 新增 `src/fpdev.fpc.sourceflow.pas`
    - 更新 `src/fpdev.fpc.source.pas`
  - 新 helper 当前承接：
    - clone/update 的版本 fallback 与 current-version update
    - update success/fail status 文案
    - switch installed gate
    - available versions merge / fallback
    - local version scan / validator filter
    - build prerequisites probe
  - `src/fpdev.fpc.source.pas` 当前保持 manager-owned 的只剩：
    - `FSourceRoot` / `FCurrentVersion` / `FBootstrapCompiler`
    - `Repo`
    - `ExecuteCommand(...)`
    - `IsValidSourceDirectory(...)`
  - 跑 focused verification：
    - `python3 -m unittest tests.test_fpc_source_boundary -v` → `5 passed`
    - `tests/test_fpc_sourceflow.lpr` → `27` checks 全绿
    - `tests/test_fpc_sourceinstallflow.lpr` → `12/12`
    - `tests/test_fpc_sourcebootstrapflow.lpr` → `12/12`
    - `tests/test_fpc_sourcebuildflow.lpr` → `8/8`
    - `tests/test_fpc_source_repo.lpr` → `159/159`
  - 跑 broad verification：
    - `bash scripts/run_all_tests.sh` → `330 passed`
    - `lazbuild -B fpdev.lpi` → pass
- Files created/modified:
  - `docs/plans/2026-04-16-fpc-sourceflow-residual-wave.md` (created)
  - `src/fpdev.fpc.sourceflow.pas` (created)
  - `src/fpdev.fpc.source.pas`
  - `tests/test_fpc_source_boundary.py`
  - `tests/test_fpc_sourceflow.lpr` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 本轮刻意不重开 install/bootstrap/build 大块 helper；只做 `fpc.source` 的 residual glue 收口
  - 这轮完成后，`src/fpdev.fpc.source.pas` 的剩余代码已经以 state/path/validation helper 为主；若要继续推进，应重新按最新工作树做 fresh ROI 排序

### Phase 96: Fresh Hotspot Recheck Checkpoint
- **Status:** complete
- **Started:** 2026-04-16
- Actions taken:
  - 新增正式计划：`docs/plans/2026-04-16-fresh-hotspot-recheck-checkpoint.md`
  - 重新扫描当前大体量 facade/service 文件，记录当前 top 体量：
    - `src/fpdev.fpc.source.pas` `870`
    - `src/fpdev.fpc.manager.pas` `838`
    - `src/fpdev.fpc.builder.pas` `805`
    - `src/fpdev.build.manager.pas` `799`
    - `src/fpdev.package.manager.pas` `762`
    - `src/fpdev.resource.repo.pas` `761`
    - `src/fpdev.lazarus.manager.pas` `761`
  - 对这些文件逐一核对 flow/helper 落点，确认先前高 ROI facade 面当前都已 helper 化：
    - `build.manager` → `managerflow` + `runtimeflow`
    - `fpc.builder` → `builderflow`
    - `fpc.source` → `sourceinstallflow` + `sourcebootstrapflow` + `sourcebuildflow` + `sourceflow`
    - `fpc.manager` → `installsurfaceflow` / `maintenanceflow` / `residualflow` / `runtimeflow` / `verifyflow` / `statusflow` / `versionflow` / `bootstrapflow` / `indexflow`
    - `resource.repo` → `lifecycleflow` / `queryflow` / `packageflow` / `mirrorflow` / `bootstrapflow` / `statusflow` / `distributionflow`
    - `package.manager` → `managerflow` / `facadeflow` / `installflow` / `publishflow` / `queryflow`
    - `lazarus.manager` → `metadataflow` / `catalogflow` / `maintenanceflow` / `versionflow` / `pathflow`
  - 跑 lightweight boundary verification：
    - `python3 -m unittest tests.test_build_manager_boundary -v` → `5 passed`
    - `python3 -m unittest tests.test_fpc_builder_boundary -v` → `3 passed`
    - `python3 -m unittest tests.test_package_manager_boundary -v` → `3 passed`
    - `python3 -m unittest tests.test_lazarus_manager_version_boundary -v` → `5 passed`
    - `python3 -m unittest tests.test_fpc_source_boundary -v` → `5 passed`
    - `python3 -m unittest tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v` → `15 passed`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`，把当前 checkpoint 结论写实落盘
- Files created/modified:
  - `docs/plans/2026-04-16-fresh-hotspot-recheck-checkpoint.md` (created)
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 这轮没有继续打开新的代码 wave，因为 fresh re-rank 后没有再发现新的“3-5 个方法成组、护栏成熟、爆炸半径低”的 helper extraction 切口
  - 如果后续还要继续推进，应该从新的设计级/业务级目标重新立项，而不是继续沿 facade 层做机械切片

### Phase 97: BuildManager TestResults Docs/Todo Truth Sync
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 先复核当前 `BuildManager.TestResults` 真相来源：
    - `src/fpdev.build.testresultsflow.pas`
    - `tests/test_build_testresultsflow.lpr`
  - 识别到三处 drift：
    - `docs/build-manager.md` 顶部仍写“TestResults 仅检查目录是否存在（占位）”
    - `docs/build-manager.en.md` 顶部仍写 “TestResults only checks if directory exists (placeholder)”
    - `report/fpdev.build.manager.md` 未记录 `TestResults` 当前 helper/coverage，`todos/fpdev.git2.md` 未勾掉已完成子项
  - 按 TDD 先在 `tests/test_contributor_docs_contract.py` 中验证 RED，确认三处 drift 都能被契约稳定击中
  - 发现 `tests/test_contributor_docs_contract.py` 本身还带有其他未提交改动后，将本段新增断言抽出到独立文件 `tests/test_build_manager_docs_truth_contract.py`，只保留本轮需要提交的最小契约
  - 新独立契约锁定三条事实：
    - 文档不得保留旧 placeholder 描述
    - BuildManager report 必须提到 `src/fpdev.build.testresultsflow.pas` 与 `tests/test_build_testresultsflow.lpr`
    - todo 必须把 `TestResults 校验沙箱输出结构（允许安装时）` 标为完成，同时保留其他未完成项
  - 运行 RED：
    - `python3 -m unittest tests.test_contributor_docs_contract.ContributorDocsContractTests.test_build_manager_docs_do_not_describe_testresults_as_directory_only_placeholder tests.test_contributor_docs_contract.ContributorDocsContractTests.test_build_manager_report_mentions_current_testresults_validation_slice tests.test_contributor_docs_contract.ContributorDocsContractTests.test_git2_todo_marks_testresults_sandbox_structure_validation_complete -v`
    - 结果：`3` 个失败，分别命中文档 placeholder、report 缺失、todo 未勾选
  - 做最小 GREEN：
    - 更新 `docs/build-manager.md`
    - 更新 `docs/build-manager.en.md`
    - 更新 `report/fpdev.build.manager.md`
    - 更新 `todos/fpdev.git2.md`
  - 运行 focused/full verification：
    - `python3 -m unittest tests.test_contributor_docs_contract tests.test_build_manager_docs_truth_contract -v` → `34 passed`
    - `mkdir -p /tmp/fpdev-build-testresultsflow-bin /tmp/fpdev-build-testresultsflow-lib`
    - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-testresultsflow-bin -FU/tmp/fpdev-build-testresultsflow-lib tests/test_build_testresultsflow.lpr && /tmp/fpdev-build-testresultsflow-bin/test_build_testresultsflow` → `29 passed`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `tests/test_build_manager_docs_truth_contract.py`
  - `docs/build-manager.md`
  - `docs/build-manager.en.md`
  - `report/fpdev.build.manager.md`
  - `todos/fpdev.git2.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 本轮未变更 `BuildManager` 运行逻辑，只同步 truth artifacts；focused Pascal runner 仍证明当前 `TestResults` 行为保持绿态
  - `BuildManager 强化` 父项继续保持未完成，因为 `日志分文件/轮转、verbosity 开关` 仍是未收口项

### Phase 98: BuildManager Todo Short-Term Truth Sync
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 复核 `todos/fpdev.build.manager.md` 的短期项与当前文档现状，确认两处 drift：
    - `docs/build-manager.md` 已包含 “全工具链真实演练 Runbook、脚本清单与参数说明”，但 todo 仍未勾选
    - 文档已实际演示 `SetMakeCmd` / `SetTarget` / `SetPrefix`，但 “示例增强” 项仍未勾选
  - 通过 `rg` 直接命中现状证据：
    - `## 全工具链真实演练 Runbook（快速上手）`
    - `scripts\\check_toolchain.bat` / `bash scripts/check_toolchain.sh`
    - `scripts\\run_examples_real.bat` / `bash scripts/run_examples_real.sh`
    - `SetMakeCmd` / `SetTarget` / `SetPrefix`
  - 按 TDD 先扩展 `tests/test_build_manager_docs_truth_contract.py`，新增 `test_build_manager_todo_marks_runbook_and_api_examples_complete`
  - 运行 RED：
    - `python3 -m unittest tests.test_build_manager_docs_truth_contract.BuildManagerDocsTruthContractTests.test_build_manager_todo_marks_runbook_and_api_examples_complete -v`
    - 结果：`1` 个失败，命中 `todos/fpdev.build.manager.md` 仍把 runbook 项保留为未完成
  - 做最小 GREEN：
    - 更新 `todos/fpdev.build.manager.md`
    - 仅将 runbook 项与 API 示例项标记为完成
    - 保留 `日志优化：Windows 时间戳零填充（避免空格）` 为未完成
  - 运行 focused/full verification：
    - `python3 -m unittest tests.test_build_manager_docs_truth_contract -v` → `4 passed`
    - `python3 -m unittest tests.test_contributor_docs_contract tests.test_build_manager_docs_truth_contract -v` → `35 passed`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `tests/test_build_manager_docs_truth_contract.py`
  - `todos/fpdev.build.manager.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 本轮仍未变更 `BuildManager` 代码；只是把短期 todo 调整到和当前文档真相一致
  - `日志优化：Windows 时间戳零填充（避免空格）` 仍缺实现证据，因此继续保留待办

### Phase 99: BuildManager Zero-Padded Log Timestamp Truth Sync
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 复核 `src/fpdev.build.logger.pas`，确认日志文件名生成逻辑已经使用 `FormatDateTime('yyyymmdd_hhnnss_zzz', Now)`，并非真实实现缺口
  - 识别到两处 drift：
    - `docs/build-manager.md` 仍提示“Windows 日志时间戳可能含空格（小时 < 10）”
    - `todos/fpdev.build.manager.md` 仍把零填充时间戳项保留为未完成
  - 按 TDD 先扩展 `tests/test_build_manager_docs_truth_contract.py`，新增 `test_build_manager_docs_and_todo_capture_zero_padded_log_timestamp_truth`
  - 运行 RED：
    - `python3 -m unittest tests.test_build_manager_docs_truth_contract.BuildManagerDocsTruthContractTests.test_build_manager_docs_and_todo_capture_zero_padded_log_timestamp_truth -v`
    - 结果：`1` 个失败，命中文档仍缺少“当前已零填充”说明
  - 做最小 GREEN：
    - 更新 `docs/build-manager.md`
    - 更新 `todos/fpdev.build.manager.md`
  - 为当前事实补运行时护栏：
    - 扩展 `tests/test_build_logger.lpr`
    - 新增 `TestLogFileNameUsesZeroPaddedTimestampWithoutSpaces`
  - 运行 focused/full verification：
    - `python3 -m unittest tests.test_build_manager_docs_truth_contract tests.test_contributor_docs_contract -v` → `36 passed`
    - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-logger-bin -FU/tmp/fpdev-build-logger-lib tests/test_build_logger.lpr && /tmp/fpdev-build-logger-bin/test_build_logger` → `10 passed`
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `docs/build-manager.md`
  - `todos/fpdev.build.manager.md`
  - `tests/test_build_manager_docs_truth_contract.py`
  - `tests/test_build_logger.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 本轮仍未修改 `src/fpdev.build.logger.pas` 生产逻辑；只是把已有零填充行为写实到文档/todo，并补上直接测试证据
  - 当前 `todos/fpdev.build.manager.md` 的短期项已全部收口，后续 BuildManager 方向应转向中期项或更高层设计/实现问题

### Phase 100: TFPCInstaller Lifecycleflow Extraction And Truth Reset
- **Status:** complete
- **Started:** 2026-04-19
- Actions taken:
  - 先按 TDD 扩展 `tests/test_fpc_installer_boundary.py`：
    - 要求 `src/fpdev.fpc.installer.pas` 引入 `fpdev.fpc.installer.lifecycleflow`
    - 要求 `InstallVersion(...)` / `UninstallVersion(...)` 必须委托 helper
    - 禁止 facade 继续内联 validate / source download-build / remove-command glue
  - 新增 `tests/test_fpc_installer_lifecycleflow.lpr`，把 install root resolve、invalid version、ensure success、fake binary fallback、uninstall process plan 直接锁进 focused helper tests
  - 运行 RED：
    - `python3 -m unittest tests.test_fpc_installer_boundary -v` → `3` 个失败，命中 lifecycleflow import/delegate 缺口
    - `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-installer-lifecycleflow-bin-red -FU/tmp/fpdev-installer-lifecycleflow-lib-red tests/test_fpc_installer_lifecycleflow.lpr` → 因 helper unit 不存在而失败
  - 做最小 GREEN：
    - 新增 `src/fpdev.fpc.installer.lifecycleflow.pas`
    - 在 helper 中承接：
      - install root / install dir / source dir resolve
      - `InstallVersion(...)` orchestration 与 `TOperationResult` 映射
      - uninstall remove-command plan 与 `TOperationResult` 映射
    - 重构 `src/fpdev.fpc.installer.pas`，让 `GetResolvedInstallRoot(...)`、`GetInstallDir(...)`、`InstallVersion(...)`、`UninstallVersion(...)` 全部收缩为 thin delegate
    - 为 `IFileSystem` / `IProcessRunner` 提供 facade-local wrapper，稳定 callback wiring
    - 修正 `src/fpdev.fpc.installer.pas` 顶部关于 SourceForge fallback 的过时说明
  - 同步 backlog truth：
    - 更新 `todos/fpdev.git2.md`
    - 将 `BuildManager 强化` 中的混合条目拆成：
      - `日志分文件（per-run 独立日志文件）` → 完成
      - `verbosity 开关` → 完成
      - `日志轮转` → 未完成
  - 运行 focused/broad verification：
    - `python3 -m unittest tests.test_fpc_installer_boundary -v` → `4 passed`
    - `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-installer-lifecycleflow-bin -FU/tmp/fpdev-installer-lifecycleflow-lib tests/test_fpc_installer_lifecycleflow.lpr && /tmp/fpdev-installer-lifecycleflow-bin/test_fpc_installer_lifecycleflow` → `13 passed`
    - `fpc -Fusrc -Fisrc -Fu. -FE/tmp/fpdev-installer-bin -FU/tmp/fpdev-installer-lib tests/test_fpc_installer.lpr && /tmp/fpdev-installer-bin/test_fpc_installer` → `35 passed`
    - `bash scripts/run_all_tests.sh` → `335 passed`
    - `lazbuild -B --build-mode=Release fpdev.lpi` → pass
  - 同步 `task_plan.md`、`findings.md`、`progress.md`
- Files created/modified:
  - `src/fpdev.fpc.installer.lifecycleflow.pas`
  - `src/fpdev.fpc.installer.pas`
  - `tests/test_fpc_installer_boundary.py`
  - `tests/test_fpc_installer_lifecycleflow.lpr`
  - `todos/fpdev.git2.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- Residual notes:
  - 本轮没有改变 `TFPCInstaller` public API，也没有把 fake binary fallback 改成真实 binary install
  - uninstall 仍保持当前宽松语义：缺目录即成功、继续用 shell remove command、不做 metadata/toolchain cleanup
  - `BuildManager` 方向只做 truth reset；`日志轮转` 继续留在 backlog，不被这轮误标完成
