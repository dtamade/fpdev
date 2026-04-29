# Task Plan

## Active Goal
把后续推进方式切换成 plan pack：一次生成多条可执行主线，按依赖和风险顺序做更大的实施批次。

## Current Phase
Phase 122 complete

## Active Phases
### Phase 122: Git2 Modern Legacy Test Lane Split
- [x] 复核当前 Git2 focused runners、测试文档与报告，确认 `tests/fpdev.git2/` 同时承担 legacy wrapper 叙事与 modern interface 入口说明
- [x] 新增 `tests/test_git2_lane_contract.py`，锁定：
  - legacy focused runners 必须显式标记为 legacy lane
  - modern-only runner 不得导入 `fpdev.git2`
  - docs/report 必须拆分 legacy / modern lane
- [x] 为现有 legacy runner 补显式定位注释：
  - `tests/fpdev.git2/fpdev.git2.test.lpr`
  - `tests/fpdev.git2/fpdev.git2.testcase.pas`
  - `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas`
- [x] 新增 modern-only focused runner：
  - `tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr`
  - `tests/fpdev.git2.modern/run_tests.sh`
- [x] 同步 `docs/history/git2-status-and-tests.md` 与 `report/fpdev.git2.md`
- [x] 运行 focused/broad verification
- [x] 提交本轮 Lane A 收口
- **Status:** complete

### Phase 121: Throughput Plan Pack Reset
- [x] 复核当前工作树与 planning 状态，确认此前节奏的问题是“微型收口波次过多”
- [x] 基于当前 repo 真相整理下一批主线：
  - Git2 modern/legacy test lane split
  - git2.impl 脱离 `fpdev.git2`
  - release packaging step consolidation
- [x] 在 `docs/plans/` 落盘总计划与 3 份子计划
- [x] 同步根 planning files，作为后续连续执行的入口
- [x] 提交本轮 workflow reset / plan-pack 收口
- **Status:** complete

### Phase 120: Git2 Legacy Entrypoint Docs Correction
- [x] 复核 `fpdev.git2` 当前真实导出，确认并不存在 `GitManager` singleton
- [x] 修正 `docs/GIT2_USAGE*.md` 中过时的 legacy entrypoint 描述
- [x] 同步 `tests/test_official_docs_cli_contract.py`
- [x] 运行 focused/full Python verification
- [x] 提交本轮 Git2 docs follow-up 修复
- **Status:** complete

### Phase 119: Git2 Modern Docs Truth Sync
- [x] 为 Git2 当前公开文档补 docs contract，锁定 modern layer 与 migration 指引
- [x] 同步 `docs/LIBGIT2_INTEGRATION*.md` 到当前 `git2.api + git2.impl` 真相
- [x] 同步 `docs/GIT2_USAGE*.md` 中过时的 `git2.modern -> fpdev.git2` 迁移说法
- [x] 运行 focused/full Python docs verification
- [x] 提交本轮 Git2 docs truth-sync 收口
- **Status:** complete

### Phase 118: Task Tree Drain And BuildManager Backlog Closure
- [x] 新增正式计划：`docs/plans/2026-04-29-task-tree-drain-buildmanager.md`
- [x] 盘点当前任务树：根 `task_plan.md` 已在 Phase 117 complete；剩余 unchecked 项集中在 `todos/fpdev.build.manager.md` 与 `todos/fpdev.git2.md`
- [x] 为 BuildManager backlog 增加 RED/focused contracts：
  - 日志轮转
  - 沙箱 artifact manifest
  - strict 清单聚合失败报告
  - FullBuild preflight gate
  - docs/todos active backlog drain
- [x] 最小实现：
  - `TBuildLogger.RotateLogs(...)`
  - `artifact-manifest.txt` 产物快照
  - strict INI robust bool parse + all-section failure aggregation
  - `scripts/build_manager_self_hosted_ci.sh`
- [x] 同步 `docs/build-manager*.md` 与 `todos/*.md`
- [x] 清理历史 `progress.md` 中被后续 complete phase 覆盖的 stale `in_progress`
- [x] 运行 focused/full verification
- [x] 提交本轮任务树清空收口
- **Status:** complete

### Phase 117: Continuous Repo Closeout And Test Inventory Truth Sync
- [x] 创建连续收口实施计划：`docs/plans/2026-04-29-continuous-repo-closeout.md`
- [x] 确认当前工作树仍是大 dirty tree，且 prior planning state 已停在 Phase 116 checkpoint
- [x] 修复 `scripts/update_test_stats.py --check` 暴露的 335 vs 275 test inventory drift
- [x] 运行 focused docs/test-inventory contracts
- [x] 运行 facade boundary bundle，确认已完成 helper/facade 边界没有回退
- [x] 运行 Python 全量回归
- [x] 运行 Pascal 全量回归：`bash scripts/run_all_tests.sh`
- [x] 运行 Release build：`lazbuild -B --build-mode=Release fpdev.lpi`
- [x] 提交前给出简短 review 结论
- [x] commit 本轮 closeout 改动
- **Status:** complete

### Phase 116: Fresh Hotspot Re-rank Checkpoint After CLI Wave Pack
- [x] 基于最新工作树重新扫描剩余大体量单元与 command/facade/helper 分布
- [x] 运行轻量 boundary bundle：
  - `python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v`
  - 结果：`36/36`
- [x] 结合 line-count scan 与语义复核，确认当前最显著的大文件主要是：
  - `src/fpdev.git.operations.impl.pas`
  - `src/fpdev.i18n.strings.pas`
  - `src/fpdev.git2.pas`
  - 以及已经多轮 helper 化并有边界护栏的 `fpc/build/package/resource/lazarus` manager/source facade
- [x] 记录 checkpoint 结论：
  - 现阶段没有再出现新的“3-5 个方法成组、测试护栏成熟、爆炸半径低”的 helper extraction 切口
  - 若继续推进，应切到新的业务/设计目标，或先形成更具体的新计划，而不是 reopen 已完成 wave
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 115: TFPCInstaller Lifecycleflow Extraction And Truth Reset
- [x] 在 `tests/test_fpc_installer_boundary.py` 补 installer lifecycleflow 边界 RED：
  - `src/fpdev.fpc.installer.pas` 必须引入 `fpdev.fpc.installer.lifecycleflow`
  - `InstallVersion(...)` 必须委托 `ExecuteFPCInstallerInstallCore(...)`
  - `UninstallVersion(...)` 必须委托 `ExecuteFPCInstallerUninstallCore(...)`
  - facade 不得继续内联 validate / source download-build / remove-command glue
- [x] 新增 `tests/test_fpc_installer_lifecycleflow.lpr`，锁定 helper 直测：
  - configured root / `GetDataRoot` fallback
  - invalid version / ensure success
  - fake binary fallback 继续走 source path
  - uninstall remove-command plan 保持平台语义
- [x] 新增 `src/fpdev.fpc.installer.lifecycleflow.pas`，承接：
  - install root resolve
  - version install dir resolve
  - source dir resolve
  - `InstallVersion(...)` orchestration
  - `UninstallVersion(...)` process-plan orchestration
- [x] 重构 `src/fpdev.fpc.installer.pas`：
  - `GetResolvedInstallRoot(...)` / `GetInstallDir(...)` 委托 helper
  - `InstallVersion(...)` / `UninstallVersion(...)` 收缩为 thin delegate
  - 保留 public signatures 与既有 fake binary fallback 语义不变
  - 修正 unit 顶部关于 binary fallback 支持范围的过时说明
- [x] 归一 `todos/fpdev.git2.md` 中 `BuildManager 强化` 的混合条目：
  - `日志分文件（per-run 独立日志文件）` → 已完成
  - `verbosity 开关` → 已完成
  - `日志轮转` → 继续待办
- [x] 完成 focused + broad verification：
  - `python3 -m unittest tests.test_fpc_installer_boundary -v`
  - `tests/test_fpc_installer_lifecycleflow.lpr`
  - `tests/test_fpc_installer.lpr`
  - `bash scripts/run_all_tests.sh`
  - `lazbuild -B --build-mode=Release fpdev.lpi`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 114: TFPCInstaller Lifecycleflow Test Audit
- [x] 复核 `tests/test_fpc_installer.lpr` 与相关 helper/boundary tests
- [x] 识别当前 `TFPCInstaller` 生命周期行为已经被哪些测试锁住，哪些还缺直接护栏
- [x] 给出最小 RED 测试建议：
  - boundary Python tests 该新增哪些断言
  - Pascal `lifecycleflow` focused tests 应覆盖哪些当前行为
- [x] 明确建议保持 public semantics 不变，只锁责任下沉与现有行为
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 113: Git2 Fpcunit Conflict Follow-up
- [x] 先写 RED：
  - 扩展 `tests/test_git2_status_docs_contract.py`
  - 新要求：
    - `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas` 必须包含 `Test_StatusEntries_Conflict_Filtered`
    - `docs/history/git2-status-and-tests.md` / `report/fpdev.git2.md` 必须明确写出 `TTestCase_Git2Status` 同时覆盖未跟踪过滤与冲突过滤
  - `python3 -m unittest tests.test_git2_status_docs_contract -v` → 先红
- [x] 最小实现：
  - 在 `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas` 新增 `Test_StatusEntries_Conflict_Filtered`
  - 为 fpcunit 单元补本地 git 冲突仓库准备 helper
  - 同步 `docs/history/git2-status-and-tests.md` / `report/fpdev.git2.md` / `todos/fpdev.git2.md`
- [x] focused verification：
  - `python3 -m unittest tests.test_git2_status_docs_contract -v` → `6/6`
  - `fpc ... tests/fpdev.git2/fpdev.git2.fpcunit.lpr && .../fpdev.git2.fpcunit --all --format=plain` → `3 tests, 0 failures`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 112: Git2 Status Conflict Coverage Closure
- [x] 为 `git2 status` conflict coverage 写 RED：
  - 更新 `tests/test_git2_status_docs_contract.py`，要求 docs / batch / todo / report 都反映 `fpdev.git2.status_conflict_test.lpr`
  - 新增 `tests/fpdev.git2/fpdev.git2.status_conflict_test.lpr`
  - 先跑 docs contract RED，再跑 focused conflict runner RED，确认当前缺口是：
    - docs / batch / todo / report 尚未接线
    - `GIT_STATUS_CONFLICTED` 会被 `IndexOnly` 过滤错误漏掉
- [x] 做最小实现：
  - 在 `src/fpdev.git2.pas` 的 `AcceptStatus(...)` 中把 `GIT_STATUS_CONFLICTED` 视作 index/worktree focused view 都可见
  - 更新 `tests/fpdev.git2/buildOrTest.bat`
  - 更新 `docs/history/git2-status-and-tests.md`
  - 更新 `report/fpdev.git2.md`
  - 更新 `todos/fpdev.git2.md`
- [x] focused verification：
  - `python3 -m unittest tests.test_git2_status_docs_contract -v` → `5/5`
  - `fpc ... tests/fpdev.git2/fpdev.git2.status_conflict_test.lpr && .../fpdev.git2.status_conflict_test` → pass
  - `fpc ... tests/fpdev.git2/fpdev.git2.status_index_test.lpr && .../fpdev.git2.status_index_test` → pass
  - `fpc ... tests/fpdev.git2/fpdev.git2.status_entries_test.lpr && .../fpdev.git2.status_entries_test` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 111: Revalidation Checkpoint
- [x] 复核 FPC/Git compatibility + verify/builder 边界 bundle：
  - `python3 -m unittest tests.test_git_runtime_boundary tests.test_fpc_builder_boundary tests.test_fpc_manager_verify_boundary tests.test_fpc_binary_verify_boundary -v`
  - 结果：`44/44` 通过
- [x] 复核 facade hotspot boundary bundle：
  - `python3 -m unittest tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_package_manager_boundary tests.test_lazarus_manager_version_boundary tests.test_fpc_source_boundary tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v`
  - 结果：`36/36` 通过
- [x] 明确记录当前结论：
  - `fpdev.utils.git` breaking removal、FPC verify consolidation、builder/source/manager/resource/package/lazarus facade helperization 在当前工作树下仍保持为绿
  - 当前没有再出现新的“3-5 个方法成组、护栏成熟、爆炸半径低”的 helper extraction 切口
  - 若继续推进，应该切换到新的设计级/业务级目标，而不是继续机械 reopen helper-wave 主线
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 110: Project Template Commandflow Thin-Facade Closure
- [x] fresh 复核 `src/fpdev.cmd.project.template.list.pas` / `install.pas` / `remove.pas` / `update.pas` 与 `tests/test_project_template_commands.lpr` / `tests/test_command_registry.lpr`，确认当前最高 ROI 切口是把 4 个 `project template` 子命令中重复的 help/usage、参数解析与 exit-code glue 成组下沉，而不是 reopen `project.manager` / `project.templateflow`
- [x] 先写 RED：
  - 新增 `tests/test_project_template_command_boundary.py`
  - 新增 `tests/test_project_templatecommandflow.lpr`
  - 运行 boundary / helper focused RED，确认命中预期缺口：helper 单元不存在、4 个命令单元仍内联 parse/help/usage glue
- [x] 新增 `src/fpdev.project.templatecommandflow.pas`，承接：
  - `Prepare/ExecuteProjectTemplateListCommandPlanCore(...)`
  - `Prepare/ExecuteProjectTemplateInstallCommandPlanCore(...)`
  - `Prepare/ExecuteProjectTemplateRemoveCommandPlanCore(...)`
  - `Prepare/ExecuteProjectTemplateUpdateCommandPlanCore(...)`
- [x] 重构 `src/fpdev.cmd.project.template.list.pas` / `install.pas` / `remove.pas` / `update.pas`：
  - 命令单元收缩为 thin facade，仅保留 manager ownership、显式 callback wrapper、helper 调用与 command registration
  - `list` / `update` 的 help/usage、unknown-option 与 extra-arg rejection 下沉到 helper
  - `install` / `remove` 的 missing-argument wording、single positional parse 与 runtime dispatch 下沉到 helper
- [x] 显式沿用 Phase 109 的安全策略，避免对 overloaded manager 方法做 unsafe cast：
  - `ListTemplates` / `InstallTemplate` / `RemoveTemplate` / `UpdateTemplates` 都有 overload
  - 命令单元改为提供显式 wrapper method，再把 wrapper 传给 helper，避免重复引入 `Invalid pointer operation` 风险
- [x] fresh focused verification：
  - `python3 -m unittest tests.test_project_template_command_boundary -v` → `8/8`
  - `tests/test_project_templatecommandflow.lpr` → `32 checks`
  - `tests/test_project_template_commands.lpr` → `47/47`
  - `tests/test_command_registry.lpr` → `397/397`
- [x] fresh broad verification：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `632/632`
  - `bash scripts/run_all_tests.sh` → `334/334`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- [x] 完成 fresh checkpoint，确认 `project template` 子命令 surfaces 现已完成一轮 high-ROI thin-facade 收口；若继续推进下一波，应重新做 hotspot re-ranking，而不是 reopen `project.manager`
- **Status:** complete

### Phase 109: Project Main Commandflow Thin-Facade Closure
- [x] fresh 复核 `src/fpdev.cmd.project.list.pas` / `info.pas` / `build.pas` / `test.pas` / `clean.pas` / `new.pas` 与 `tests/test_cli_project.lpr` / `tests/test_project_commands.lpr`，确认当前最高 ROI 切口是把 6 个 `project` 主命令中重复的 help/usage、参数解析、JSON/状态输出与 exit-code glue 成组下沉，而不是 reopen `project.manager`
- [x] 先写 RED：
  - 新增 `tests/test_project_command_boundary.py`
  - 新增 `tests/test_project_commandflow.lpr`
  - 运行 boundary / helper focused RED，确认命中预期缺口：helper 单元不存在、6 个命令单元仍内联 parse/help/JSON/output glue
- [x] 新增 `src/fpdev.project.commandflow.pas`，承接：
  - `Prepare/ExecuteProjectListCommandPlanCore(...)`
  - `Prepare/ExecuteProjectInfoCommandPlanCore(...)`
  - `Prepare/ExecuteProjectBuildCommandPlanCore(...)`
  - `Prepare/ExecuteProjectTestCommandPlanCore(...)`
  - `Prepare/ExecuteProjectCleanCommandPlanCore(...)`
  - `Prepare/ExecuteProjectNewCommandPlanCore(...)`
- [x] 重构 `src/fpdev.cmd.project.list.pas` / `info.pas` / `build.pas` / `test.pas` / `clean.pas` / `new.pas`：
  - 命令单元收缩为 thin facade，仅保留 manager ownership、少量 callback seam 与 helper 调用
  - `list` 的 `--json` parse 与 JSON serialization 下沉到 helper
  - `build` success/failure message、`new` success/failure message、`new` target dir 派生逻辑全部下沉到 helper
  - `test` / `clean` 保持 manager-owned runtime output contract，不追加 generic message
- [x] 在 focused CLI 回归中定位并修复一处真实运行时问题：
  - `list/info/test/clean` 初版通过 unsafe cast 把 overloaded manager 方法塞进 `of object` callback，导致 `test_cli_project.lpr` 命中 `Invalid pointer operation`
  - 改为在命令单元中提供显式 wrapper method，再将 wrapper 传给 helper，保持 facade 薄的同时消除运行时栈破坏
- [x] fresh focused verification：
  - `python3 -m unittest tests.test_project_command_boundary -v` → `12/12`
  - `tests/test_project_commandflow.lpr` → `68 checks`
  - `tests/test_cli_project.lpr` → `83/83`
  - `tests/test_project_commands.lpr` → `11/11`
- [x] fresh broad verification：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `624/624`
  - `bash scripts/run_all_tests.sh` → `333/333`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- [x] 完成 fresh checkpoint，确认 `project` 主命令 surfaces 已完成一轮 high-ROI thin-facade 收口；若继续推进下一波，更自然的候选会转向 `project template` 子命令或其他 residual command surfaces，而不是 reopen `project.manager`
- **Status:** complete

### Phase 108: Lazarus Leaf Commandflow Thin-Facade Closure
- [x] fresh 复核 `src/fpdev.cmd.lazarus.current.pas` / `use.pas` / `show.pas` / `configure.pas` / `uninstall.pas` / `update.pas` / `test.pas` 与 `tests/test_cli_lazarus.lpr`，确认当前最高 ROI 切口是把 7 个 Lazarus 叶子命令中重复的 help/usage、参数解析与 exit-code glue 成组下沉，而不是 reopen `lazarus.manager`
- [x] 先写 RED：
  - 新增 `tests/test_lazarus_leaf_boundary.py`
  - 新增 `tests/test_lazarus_leafcommandflow.lpr`
  - 运行 boundary / helper focused RED，确认命中预期缺口：helper 单元不存在、命令单元仍内联 parse/help/JSON/output glue
- [x] 新增 `src/fpdev.lazarus.leafcommandflow.pas`，承接：
  - `PrepareLazarusCurrentCommandPlanCore(...)`
  - `ExecuteLazarusCurrentCommandPlanCore(...)`
  - `PrepareLazarusUse/Show/Configure/Uninstall/TestCommandPlanCore(...)`
  - `ExecuteLazarusUse/Show/Configure/Uninstall/TestCommandPlanCore(...)`
  - `PrepareLazarusUpdateCommandPlanCore(...)`
  - `ExecuteLazarusUpdateCommandPlanCore(...)`
- [x] 重构 `src/fpdev.cmd.lazarus.current.pas` / `use.pas` / `show.pas` / `configure.pas` / `uninstall.pas` / `update.pas` / `test.pas`：
  - 命令单元收缩为 thin facade，仅保留 manager ownership、`show` 的 version-registry seam 接线、helper 调用与 command registration
  - `current` 的 JSON/text rendering 下沉到 helper
  - `configure` start banner、`uninstall` generic failed、`show` unsupported-version exit code、`update` no-extra-message 语义全部保持不变
- [x] fresh focused verification：
  - `python3 -m unittest tests.test_lazarus_leaf_boundary -v` → `14/14`
  - `tests/test_lazarus_leafcommandflow.lpr` → `68 checks`
  - `tests/test_cli_lazarus.lpr` → `143/143`
  - `tests/test_lazarus_update.lpr` → `150/150`
  - `tests/test_lazarus_configure_workflow.lpr` → `51/51`
- [x] fresh broad verification：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `612/612`
  - `bash scripts/run_all_tests.sh` → `332/332`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- [x] 完成 fresh checkpoint，确认 Lazarus leaf command surfaces 已基本收口；若继续推进下一波，应重新做 hotspot re-ranking，而不是直接 reopen manager/source 大面
- **Status:** complete

### Phase 107: Index Service Cache/Offline Refactor Closure
- [x] fresh 复核 `src/fpdev.index.pas` / `src/fpdev.index.commandflow.pas` / `tests/test_cmd_index.lpr` / `src/fpdev.paths.pas` / `docs/MANIFEST-USAGE.md`，确认本轮切口聚焦在：
  - `TFPDevIndex` 的 index + manifest 远端抓取与 fallback/cache glue
  - `system index show/update` 缓存降级成功路径
  - cache 根目录必须统一走 `GetCacheDir`
- [x] 先写 RED：
  - 新增 `tests/test_index_boundary.py`
  - 新增 `tests/test_index_serviceflow.lpr`
  - 扩展 `tests/test_cmd_index.lpr`
  - 运行 boundary / helper / commandflow focused bundle，确认缺失 `fpdev.index.serviceflow`、factory seam 与 override 接缝
- [x] 新增 `src/fpdev.index.serviceflow.pas`，承接：
  - `BuildIndexCachePathCore(...)`
  - `BuildManifestCachePathCore(...)`
  - `LoadRemoteJSONWithCacheCore(...)`
  - `BuildManifestVersionsCore(...)`
  - `ResolveManifestDownloadCore(...)`
- [x] 重构 `src/fpdev.index.pas`：
  - `TFPDevIndex.Create(...)` 改为使用 `GetCacheDir`
  - `Initialize` 改为通过 shared helper 执行 remote -> fallback -> cache 流程
  - bootstrap / fpc / lazarus manifest 查询与版本列表统一走 helper 驱动的 cache-aware 加载
  - 保持现有 public API 形状不变，仅为 commandflow 测试 seam 将相关查询方法标记为 `virtual`
- [x] 重构 `src/fpdev.index.commandflow.pas`：
  - `RunIndexShow` / `RunIndexUpdate` 显式设置 `Index.Output := Ctx.Out`
  - 新增 `RunIndexShowWithFactory(...)` / `RunIndexUpdateWithFactory(...)` 供离线 deterministic tests 注入 fake service
- [x] 统一 cache 路径约定：
  - `<GetCacheDir>/index.json`
  - `<GetCacheDir>/manifests/bootstrap.json`
  - `<GetCacheDir>/manifests/fpc.json`
  - `<GetCacheDir>/manifests/lazarus.json`
- [x] fresh focused verification：
  - `python3 -m unittest tests.test_index_boundary -v` → `6/6`
  - `tests/test_index_serviceflow.lpr` → `24/24`
  - `tests/test_cmd_index.lpr` → `37/37`
  - `python3 -m unittest tests.test_index_boundary tests.test_command_namespace_hygiene tests.test_temp_hygiene -v` → `152/152`
  - `tests/test_command_registry.lpr` → `397/397`
  - `tests/test_fpc_indexflow.lpr` → `11/11`
- [x] fresh broad verification：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `598/598`
  - `bash scripts/run_all_tests.sh` → `331/331`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 顺手收掉 `src/fpdev.index.serviceflow.pas` 中 `AMirrors` 初始化 hint，确保新 helper 不额外引入源码噪音
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- [x] 完成 fresh checkpoint 记录，确认本轮 `index` 服务缓存/离线化已经闭环；若继续推进下一波，需要重新做 hotspot re-ranking，而不是沿用旧的 `package` phase
- **Status:** complete

### Phase 106: Package Deps/Why + Repo + Lifecycle Commandflow Thin-Facade Follow-up Wave Pack
- [x] 依据 Phase 105 的 fresh checkpoint re-ranking，按 ROI 顺序连续收口：
  - `src/fpdev.cmd.package.deps.pas` + `src/fpdev.cmd.package.why.pas`
  - `src/fpdev.cmd.package.repo.add.pas` / `src/fpdev.cmd.package.repo.list.pas` / `src/fpdev.cmd.package.repo.remove.pas` / `src/fpdev.cmd.package.repo.update.pas`
  - `src/fpdev.cmd.package.update.pas` / `src/fpdev.cmd.package.uninstall.pas` / `src/fpdev.cmd.package.install_local.pas`
- [x] 新增 `tests/test_package_deps_boundary.py` 与 `tests/test_package_why_boundary.py`，锁定 `TPackageDepsCommand.Execute(...)` 与 `TPackageWhyCommand.Execute(...)` 必须委托对应 commandflow helper
- [x] 新增 `tests/test_package_depscommandflow.lpr` 与 `tests/test_package_whycommandflow.lpr`，覆盖 help/usage、unknown option、positional parse、sample output dispatch 与 exit-code mapping
- [x] 新增 `src/fpdev.package.depscommandflow.pas` 与 `src/fpdev.package.whycommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.deps.pas` 与 `src/fpdev.cmd.package.why.pas` 收缩为 thin command facade，仅保留 manager ownership、command registration 与 helper 调用
- [x] 新增 `tests/test_package_repo_boundary.py` 与 `tests/test_package_repocommandflow.lpr`，锁定并覆盖 `package repo add/list/remove/update` 的 help/usage、unknown option、positional parse、exists/not-found precheck、callback dispatch 与 exit-code mapping
- [x] 新增 `src/fpdev.package.repocommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.repo.add.pas` / `src/fpdev.cmd.package.repo.list.pas` / `src/fpdev.cmd.package.repo.remove.pas` / `src/fpdev.cmd.package.repo.update.pas` 收缩为 thin command facade，仅保留 manager ownership、command registration 与 helper 调用
- [x] 新增 `tests/test_package_lifecycle_boundary.py` 与 `tests/test_package_lifecyclecommandflow.lpr`，锁定并覆盖 `package update` / `package uninstall` / `package install-local` 的 help/usage、unknown option、preflight、callback dispatch 与 exit-code mapping
- [x] 新增 `src/fpdev.package.lifecyclecommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.update.pas` / `src/fpdev.cmd.package.uninstall.pas` / `src/fpdev.cmd.package.install_local.pas` 收缩为 thin command facade，仅保留 manager ownership、runtime path ownership、command registration 与 helper 调用
- [x] 在 broad verification 前再次清理可再生产物 `bin/`、`lib/` 与 `/tmp/fpdev-*`，避免环境空间噪音污染全量回归
- [x] fresh 运行 focused 验证：
  - `python3 -m unittest tests.test_package_deps_boundary tests.test_package_why_boundary tests.test_package_repo_boundary tests.test_package_lifecycle_boundary -v` → `18 tests OK`
  - `tests/test_package_depscommandflow.lpr` → `35 passed / 0 failed`
  - `tests/test_package_whycommandflow.lpr` → `25 passed / 0 failed`
  - `tests/test_package_repocommandflow.lpr` → `78 passed / 0 failed`
  - `tests/test_package_lifecyclecommandflow.lpr` → `52 passed / 0 failed`
  - `tests/test_cli_package.lpr` → `234 passed / 0 failed`
  - `tests/test_command_registry.lpr` → `397 passed / 0 failed`
  - `tests/test_cli_misc.lpr` → `152 passed / 0 failed`
- [x] fresh 运行 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `591/591`
  - `bash scripts/run_all_tests.sh` → `329/329`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 顺手收掉 `src/fpdev.package.repocommandflow.pas` 新引入的 unused-parameter hint：`repo list/update` execute helper 改为更精简的签名，不改变行为
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- [x] 完成 fresh checkpoint re-ranking，确认：
  - `package` CLI leaf command surfaces 现已基本完成 thin-facade 收口
  - `package help` 与根命令装配层保持轻量，不 reopen
  - 若继续推进，下一个高 ROI 切口大概率已不在 `package` leaf command 层，除非 fresh hotspot scan 证明相反
- **Status:** complete

### Phase 105: Package List + Clean Commandflow Thin-Facade Closure
- [x] fresh 复核 `package` 命令剩余热点，确认当前最值得连续收口的是 `src/fpdev.cmd.package.list.pas` 与 `src/fpdev.cmd.package.clean.pas`
- [x] 新增 `tests/test_package_list_boundary.py`，锁定 `TPackageListCommand.Execute(...)` 必须委托 `fpdev.package.listcommandflow`
- [x] 新增 `tests/test_package_listcommandflow.lpr`，直接覆盖：
  - help/usage
  - unknown option / extra positional
  - `--all` / `-a`
  - `--json`
  - text / JSON dispatch 与 exit-code mapping
- [x] 新增 `tests/test_package_clean_boundary.py`，锁定 `TPackageCleanCommand.Execute(...)` 必须委托 `fpdev.package.cleancommandflow`
- [x] 新增 `tests/test_package_cleancommandflow.lpr`，直接覆盖：
  - help/usage
  - unknown option / invalid scope / extra positional
  - `--dry-run`
  - `--yes`
  - refusal path / success path / failure exit-code mapping
- [x] 先跑 RED：
  - `python3 -m unittest tests.test_package_list_boundary tests.test_package_clean_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/... -FU/tmp/... tests/test_package_listcommandflow.lpr`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/... -FU/tmp/... tests/test_package_cleancommandflow.lpr`
- [x] 新增 `src/fpdev.package.listcommandflow.pas`
- [x] 新增 `src/fpdev.package.cleancommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.list.pas` 与 `src/fpdev.cmd.package.clean.pas` 收缩为 thin command facade，仅保留 manager/runtime ownership、必要 runtime path 注入与 helper 调用
- [x] fresh 运行 focused 验证：
  - `python3 -m unittest tests.test_package_list_boundary tests.test_package_clean_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-listcommandflow-bin -FU/tmp/fpdev-package-listcommandflow-lib tests/test_package_listcommandflow.lpr`
  - `/tmp/fpdev-package-listcommandflow-bin/test_package_listcommandflow`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-cleancommandflow-bin -FU/tmp/fpdev-package-cleancommandflow-lib tests/test_package_cleancommandflow.lpr`
  - `/tmp/fpdev-package-cleancommandflow-bin/test_package_cleancommandflow`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-package-bin4 -FU/tmp/fpdev-cli-package-lib4 tests/test_cli_package.lpr`
  - `/tmp/fpdev-cli-package-bin4/test_cli_package`
- [x] 清理可再生产物 `bin/`、`lib/` 与 `/tmp/fpdev-*`，避免 broad verification 再次受磁盘空间噪音干扰
- [x] fresh 运行 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `573/573`
  - `bash scripts/run_all_tests.sh` → `325/325`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- [x] 完成 fresh checkpoint re-ranking，确认若继续推进，优先顺序为：
  - `src/fpdev.cmd.package.deps.pas` + `src/fpdev.cmd.package.why.pas`
  - `src/fpdev.cmd.package.repo.add.pas` / `list.pas` / `remove.pas` / `update.pas`
  - `src/fpdev.cmd.package.update.pas` / `src/fpdev.cmd.package.uninstall.pas` / `src/fpdev.cmd.package.install_local.pas`
- **Status:** complete

### Phase 104: Package Info Commandflow Thin-Facade Closure
- [x] fresh 复核 package 命令剩余热点，确认下一刀落在 `src/fpdev.cmd.package.info.pas`
- [x] 新增 `tests/test_package_info_boundary.py`，锁定 `TPackageInfoCommand.Execute(...)` 必须委托 `fpdev.package.infocommandflow`
- [x] 新增 `tests/test_package_infocommandflow.lpr`，直接覆盖：
  - help/usage
  - unknown option
  - missing / blank / extra positional
  - installed package precheck
  - show-info success / failure exit-code mapping
- [x] 先跑 RED：
  - `python3 -m unittest tests.test_package_info_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/... -FU/tmp/... tests/test_package_infocommandflow.lpr`
- [x] 新增 `src/fpdev.package.infocommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.info.pas` 收缩为 thin command facade，仅保留 `TPackageManager` ownership 与 helper 调用
- [x] fresh 运行 focused 验证：
  - `python3 -m unittest tests.test_package_info_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-infocommandflow-bin -FU/tmp/fpdev-package-infocommandflow-lib tests/test_package_infocommandflow.lpr`
  - `/tmp/fpdev-package-infocommandflow-bin/test_package_infocommandflow`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-package-bin3 -FU/tmp/fpdev-cli-package-lib3 tests/test_cli_package.lpr`
  - `/tmp/fpdev-cli-package-bin3/test_cli_package`
- [x] fresh 运行 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `569/569`
  - `bash scripts/run_all_tests.sh` → `323/323`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 处理 broad 验证中的环境噪音：清理可再生 `bin/`、`lib/` 与 `/tmp/fpdev-*` 构建/测试产物后重跑全量验证，确认并非生产回归
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 103: Package Search Commandflow Thin-Facade Closure
- [x] fresh 复核 package 命令剩余热点，确认下一刀落在 `src/fpdev.cmd.package.search.pas`
- [x] 新增 `tests/test_package_search_boundary.py`，锁定 `TPackageSearchCmd.Execute(...)` 必须委托 `fpdev.package.searchcommandflow`
- [x] 新增 `tests/test_package_searchcommandflow.lpr`，直接覆盖：
  - help/usage
  - unknown option
  - missing / blank / extra positional
  - `--json` parse
  - text search success / failure exit-code mapping
  - JSON output formatting与 callback dispatch
- [x] 先跑 RED：
  - `python3 -m unittest tests.test_package_search_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/... -FU/tmp/... tests/test_package_searchcommandflow.lpr`
- [x] 新增 `src/fpdev.package.searchcommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.search.pas` 收缩为 thin command facade，仅保留 `TPackageManager` / `TPackageSearchCommand` ownership 与 helper 调用
- [x] 顺手清理 `src/fpdev.cmd.package.publish.pas` 的未使用 `uses`，消除上波留下的源码 hint
- [x] fresh 运行 focused 验证：
  - `python3 -m unittest tests.test_package_search_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-searchcommandflow-bin-green -FU/tmp/fpdev-package-searchcommandflow-lib-green tests/test_package_searchcommandflow.lpr`
  - `/tmp/fpdev-package-searchcommandflow-bin-green/test_package_searchcommandflow`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-package-bin2 -FU/tmp/fpdev-cli-package-lib2 tests/test_cli_package.lpr`
  - `/tmp/fpdev-cli-package-bin2/test_cli_package`
- [x] fresh 运行 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `567/567`
  - `bash scripts/run_all_tests.sh` → `322/322`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 102: Package Publish Commandflow Thin-Facade Closure
- [x] fresh 复核当前热点，确认下一刀不 reopen `project.manager` / `package.manager`，而是切 `src/fpdev.cmd.package.publish.pas`
- [x] 新增 `tests/test_package_publish_boundary.py`，锁定 `TPackagePublishCmd.Execute(...)` 必须委托 `fpdev.package.publishcommandflow`
- [x] 新增 `tests/test_package_publishcommandflow.lpr`，直接覆盖：
  - help/usage
  - unknown option
  - missing/extra positional
  - installed package precheck
  - metadata preflight
  - publish success / failure exit-code mapping
- [x] 先跑 RED：
  - `python3 -m unittest tests.test_package_publish_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/... -FU/tmp/... tests/test_package_publishcommandflow.lpr`
- [x] 新增 `src/fpdev.package.publishcommandflow.pas`
- [x] 让 `src/fpdev.cmd.package.publish.pas` 收缩为 thin command facade，仅保留 `TPackageManager` ownership 与 helper 调用
- [x] 修正 `tests/test_package_publishcommandflow.lpr` 的 interface lifetime 问题：测试输出对象改为 object + interface 双持有，避免 `TInterfacedObject` 被临时接口提前释放
- [x] fresh 运行 focused 验证：
  - `python3 -m unittest tests.test_package_publish_boundary -v`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-publishcommandflow-bin-green3 -FU/tmp/fpdev-package-publishcommandflow-lib-green3 tests/test_package_publishcommandflow.lpr`
  - `/tmp/fpdev-package-publishcommandflow-bin-green3/test_package_publishcommandflow`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-cli-package-bin -FU/tmp/fpdev-cli-package-lib tests/test_cli_package.lpr`
  - `/tmp/fpdev-cli-package-bin/test_cli_package`
- [x] fresh 运行 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `565/565`
  - `bash scripts/run_all_tests.sh` → `321/321`
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 101: Git2 Focused Runner Rehab + Truth Sync Closure
- [x] 修复 `tests/fpdev.git2/` 下陈旧 direct runners 对已移除全局 `GitManager`、`for var` 语法和私有 `FHandle` 的依赖
- [x] 修复 Unix runner 清理路径：将 `ExecuteProcess('rm', ...)` 改为可执行的 `/bin/rm`
- [x] 修复 `tests/fpdev.git2/fpdev.git2.fpcunit.lpr` 为仓内已验证的 `TTestRunner.Initialize/Run` 模式
- [x] 扩展 `tests/test_git2_status_docs_contract.py`，锁定 fpcunit runner 必须以 `--all --format=plain` 运行
- [x] 同步 `docs/history/git2-status-and-tests.md`、`report/fpdev.git2.md`、`tests/fpdev.git2/buildOrTest.fpcunit.bat` 到当前真实执行方式
- [x] 在 `src/fpdev.git2.pas` 中修正 `AcceptStatus(...)`：将 `GIT_STATUS_IGNORED` 视为 `WorkingTreeOnly` 覆盖的一部分，恢复 `.gitignore` focused runner 绿灯
- [x] fresh 运行 focused 验证：
  - `tests/fpdev.git2/fpdev.git2.test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_entries_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_ignore_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.status_index_test.lpr`
  - `tests/fpdev.git2/fpdev.git2.fpcunit.lpr --all --format=plain`
  - `python3 -m unittest tests.test_contributor_docs_contract tests.test_git2_status_docs_contract tests.test_git_runtime_boundary -v`
- [x] fresh 运行 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `563/563`
  - `bash scripts/run_all_tests.sh` → `320/320`
  - `bash scripts/check_toolchain.sh` → `missing_required: 0`
  - `lazbuild -B fpdev.lpi` → pass
- **Status:** complete

### Phase 100: Architecture / Contract / Planning Sync Closure
- [x] 扩展 `tests/test_contributor_docs_contract.py`，锁定 `docs/ARCHITECTURE.md` / `docs/ARCHITECTURE.en.md` 必须记录当前 worktree 的 facade/helper split
- [x] 更新 `docs/ARCHITECTURE.md` / `docs/ARCHITECTURE.en.md`，补上：
  - `src/fpdev.build.managerflow.pas`
  - `src/fpdev.build.runtimeflow.pas`
  - `src/fpdev.fpc.builderflow.pas`
  - `src/fpdev.fpc.binaryflow.pas`
  - `src/fpdev.fpc.installcommandflow.pas`
  - `src/fpdev.fpc.usecommandflow.pas`
  - `src/fpdev.fpc.verifycommandflow.pas`
- [x] 跑 focused 验证：
  - `python3 -m unittest tests.test_contributor_docs_contract -v`
  - `python3 -m unittest tests.test_fpc_binary_boundary tests.test_fpc_binary_verify_boundary tests.test_build_manager_boundary tests.test_fpc_builder_boundary tests.test_fpc_install_cli_boundary -v`
- [x] 跑 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'` → `557/557`
  - `bash scripts/run_all_tests.sh` → `320/320`
  - `bash scripts/check_toolchain.sh` → required `0` missing
  - `lazbuild -B fpdev.lpi` → pass
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 99: Hint Burn-down + Fresh Hotspot Recheck Closure
- [x] fresh 复跑 `lazbuild -B fpdev.lpi`，确认标准 Lazarus 构建路径通过
- [x] 以最小无行为变化补丁清掉当前 `src/` hint：删除未使用 `uses`，并显式初始化 managed local
- [x] fresh 运行：
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
  - `bash scripts/check_toolchain.sh`
  - `bash scripts/cli_smoke.sh ./bin/fpdev`
  - `bash scripts/run_all_tests.sh`
- [x] 重新核对 `src/fpdev.lazarus.source.pas` 与 `src/fpdev.cross.search.pas`，确认原先计划中的下一波 target 已在当前树中落地，不 reopen 旧波次
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到最新真实状态
- **Status:** complete

### Phase 95: CLI Commandflow Wave Pack Planning
- [x] 新增正式计划：`docs/plans/2026-04-14-cli-commandflow-wave-pack.md`
- [x] 基于真实源码确认 5-wave ROI 顺序：
  - `src/fpdev.cmd.lazarus.install.pas`
  - `src/fpdev.cmd.package.install.pas`
  - `src/fpdev.cmd.fpc.use.pas`
  - `src/fpdev.cmd.fpc.verify.pas`
  - `src/fpdev.cmd.cross.build.pas`
- [x] 固定统一实施模式：boundary test + direct helper test + thin command facade + focused verification
- [x] 开始第一波 `lazarus install` RED -> GREEN
- [x] 进入后续 `package install` / `fpc use` / `fpc verify` / `cross build`
- [x] 跑全量验证并同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 98: CLI Commandflow Wave Pack Broad Verification + Closure
- [x] 重新汇总 5-wave pack 的 focused 证据链，确认 `lazarus install`、`package install`、`fpc use`、`fpc verify`、`cross build` 全部已转为 thin command facade
- [x] 在当前工作树 fresh 复核并分别提交 5 个波次：
  - `dee7105` `refactor(lazarus-install): extract commandflow helper`
  - `f6667fe` `refactor(package-install): extract commandflow helper`
  - `3657612` `refactor(fpc-use): extract commandflow helper`
  - `774665d` `refactor(fpc-verify): extract commandflow helper`
  - `41e3576` `refactor(cross-build): extract commandflow helper`
- [x] 修正 `tests/test_build_manager_docs_truth_contract.py` 中过时的 todo 聚合断言，使 Python discover 与当前 `todos/fpdev.git2.md` 真相一致
- [x] 跑 Python 全量回归 `python3 -m unittest discover -s tests -p 'test_*.py'`
- [x] 跑 Pascal 整仓回归 `bash scripts/run_all_tests.sh`
- [x] 跑 `lazbuild -B --build-mode=Release fpdev.lpi`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到最终收口状态
- [x] 记录 fresh checkpoint 结论：下一步应先做新的 ROI/目标重排，不 reopen 已完成的 5-wave helper 线
- **Status:** complete

### Phase 97: Cross Build Commandflow Wave
- [x] 执行 `docs/plans/2026-04-14-cli-commandflow-wave-pack.md` 的 `cross build` 子任务
- [x] 新增 `tests/test_cross_build_boundary.py`，锁定 `TCrossBuildCommand.Execute(...)` 必须委托 `fpdev.cross.buildcommandflow`
- [x] 新增 `tests/test_cross_buildcommandflow.lpr`，直接覆盖 help/usage、target parse、`--dry-run` / `--source` / `--sandbox` / `--version`、source-tree preflight、success/failure exit-code mapping
- [x] 新增 `src/fpdev.cross.buildcommandflow.pas`
- [x] 让 `src/fpdev.cmd.cross.build.pas` 收缩为 thin command facade，仅保留 build-manager / engine ownership、bridge 与 helper 调用
- [x] 跑 focused 验证：
  - `python3 -m unittest tests.test_cross_build_boundary -v`
  - `tests/test_cross_buildcommandflow.lpr`
  - `tests/test_cmd_cross_build.lpr`
  - `tests/test_cli_cross.lpr`
- **Status:** complete

### Phase 96: FPC Verify Commandflow Wave
- [x] 执行 `docs/plans/2026-04-14-cli-commandflow-wave-pack.md` 的 `fpc verify` 子任务
- [x] 扩展 `tests/test_fpc_verify_boundary.py`，锁定 `TFPCVerifyCommand.Execute(...)` 必须委托 `fpdev.fpc.verifycommandflow`
- [x] 新增 `tests/test_fpc_verifycommandflow.lpr`，直接覆盖 help/usage、version positional、step-by-step report、metadata wording 与 exit-code mapping
- [x] 新增 `src/fpdev.fpc.verifycommandflow.pas`
- [x] 让 `src/fpdev.cmd.fpc.verify.pas` 收缩为 thin command facade，仅保留 `TFPCManager` ownership 与 helper 调用
- [x] 跑 focused 验证：
  - `python3 -m unittest tests.test_fpc_verify_boundary -v`
  - `tests/test_fpc_verifycommandflow.lpr`
  - `tests/test_fpc_verify.lpr`
  - `tests/test_cli_fpc_diag.lpr`
- **Status:** complete

### Phase 94: FPC Install Commandflow Wave
- [x] 执行 `docs/plans/2026-04-14-fpc-install-commandflow-wave.md`
- [x] 扩展 `tests/test_fpc_install_cli_boundary.py`，锁定 `TFPCInstallCommand.Execute(...)` 必须委托新 commandflow helper
- [x] 新增 `tests/test_fpc_installcommandflow.lpr`，先跑 RED
- [x] 新增 `src/fpdev.fpc.installcommandflow.pas`
- [x] 让 `src/fpdev.cmd.fpc.install.pas` 收缩为 thin command facade
- [x] 跑 focused 验证：
  - `python3 -m unittest tests.test_fpc_install_cli_boundary -v`
  - `tests/test_fpc_installcommandflow.lpr`
  - `tests/test_fpc_install_cli.lpr`
- [x] 跑 broad 验证：
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
  - `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 93: Toolchain Parity / Docs / Hotspot Recheck Closure
- [x] 执行 `docs/plans/2026-04-14-toolchain-parity-docs-and-hotspot-recheck-closure.md`
- [x] 更新 `docs/toolchain.md` / `docs/toolchain.en.md`，补齐 `repo_bin_writable` / `repo_lib_writable` 与 `FPDEV_TOOLCHAIN_REPO_ROOT`
- [x] 为 `scripts/check_toolchain.bat` 增加 repo build-output guardrail parity
- [x] 新增 `tests/test_check_toolchain_bat.py` 并完成 RED → GREEN
- [x] 在 `.gitignore` 中忽略 `.bin.root-owned-*` / `.lib.root-owned-*`
- [x] 验证隐藏备份目录不再污染 `git status`
- [x] 做 fresh hotspot recheck，并记录“若继续推进，唯一优先下一波仍是 build.manager runtime/toolchain residual；本轮不强开新 wave”
- [x] 跑 focused + broad verification：
  - `python3 -m unittest tests.test_check_toolchain_sh tests.test_check_toolchain_bat -v`
  - `bash scripts/check_toolchain.sh`
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
  - `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 92: Build Baseline Guardrail Closure
- [x] 执行 `docs/plans/2026-04-14-build-baseline-guardrail-closure-wave.md`
- [x] 通过非破坏性重命名 root-owned 旧 `bin/` / `lib/` 并重建可写目录，恢复标准 `lazbuild -B fpdev.lpi`
- [x] 在 `scripts/check_toolchain.sh` 新增 `repo_bin_writable` / `repo_lib_writable` required guardrail
- [x] 在 `src/fpdev.toolchain.pas` 的 `BuildToolchainReportJSON` 新增对应 JSON entry，并在 repo build output 不可写时提升为 `FAIL`
- [x] 新增 `tests/test_check_toolchain_sh.py`，并扩展 `tests/test_toolchain.lpr`、`tests/test_command_registry.lpr`
- [x] 跑 focused 验证：
  - `python3 -m unittest tests.test_check_toolchain_sh -v`
  - `tests/test_toolchain.lpr`
  - `tests/test_command_registry.lpr`
  - `bash scripts/check_toolchain.sh`
- [x] 跑全量验证：
  - `lazbuild -B fpdev.lpi`
  - `bash scripts/cli_smoke.sh ./bin/fpdev`
  - `python3 -m unittest discover -s tests -p 'test_*.py'`
  - `bash scripts/run_all_tests.sh`
- [x] 记录残留环境说明：旧 root-owned 备份目录当前仍以隐藏目录形式留在仓库根（`.bin.root-owned-20260414_190837` / `.lib.root-owned-20260414_190837`）；多次原子移出尝试均被权限拒绝，但不再影响新的 `bin/` / `lib` 构建路径
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 87: 2026-04-14 Runtime/Lifecycle/Bootstrap Wave Pack Planning
- [x] 新增正式计划：
  - `docs/plans/2026-04-14-build-manager-runtime-toolchain-wave.md`
  - `docs/plans/2026-04-14-resource-repo-repoio-lifecycle-wave.md`
  - `docs/plans/2026-04-14-fpc-manager-bootstrap-residual-wave.md`
- [x] 基于真实源码重排当前 ROI：锁定 `build.manager` runtime/toolchain、`resource.repo` repo-io/lifecycle、`fpc.manager` bootstrap residual
- [x] 明确并发策略：3 个波次文件写入范围互不冲突，可并行推进
- [x] 尝试拉起 `gpt-5.4` 团队并行实施；外部 API 返回 `401 API_KEY_DISABLED` 后切回本地主控实施
- **Status:** complete

### Phase 88: Build Manager Runtime Toolchain Wave
- [x] 执行 `docs/plans/2026-04-14-build-manager-runtime-toolchain-wave.md`
- [x] 扩展/新增 BuildManager runtime boundary + direct tests
- [x] 新增 `src/fpdev.build.runtimeflow.pas`
- [x] 让 `src/fpdev.build.manager.pas` 的 runtime/toolchain surface 收缩为 thin delegate
- **Status:** complete

### Phase 89: Resource Repo Repo-IO Lifecycle Wave
- [x] 执行 `docs/plans/2026-04-14-resource-repo-repoio-lifecycle-wave.md`
- [x] 扩展/新增 resource repo lifecycle boundary + direct tests
- [x] 新增 `src/fpdev.resource.repo.lifecycleflow.pas`
- [x] 让 `src/fpdev.resource.repo.pas` 的 repo-io/lifecycle surface 收缩为 thin delegate
- **Status:** complete

### Phase 90: FPC Manager Bootstrap Residual + Verification
- [x] 执行 `docs/plans/2026-04-14-fpc-manager-bootstrap-residual-wave.md`
- [x] 扩展/新增 FPC bootstrap boundary + direct tests
- [x] 新增 `src/fpdev.fpc.bootstrapflow.pas`
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `EnsureBootstrapCompiler(...)` 收缩为 thin delegate
- [x] 跑 focused suites 与整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 91: Broad Verification Closure
- [x] 重新评估当前剩余热点，确认暂不强开低 ROI 单函数 helper wave
- [x] 跑 Python 全量回归 `python3 -m unittest discover -s tests -p 'test_*.py'`
- [x] 跑 `bash scripts/check_toolchain.sh`
- [x] 跑 `lazbuild -B fpdev.lpi`，确认本地环境是否支持标准构建路径
- [x] 在 `lazbuild` 被 `lib/` 属主阻塞后，用 `fpc -Fusrc -Fisrc -FE/tmp/... -FU/tmp/... src/fpdev.lpr` 做 fallback 主程序编译验证
- [x] 跑 `bash scripts/cli_smoke.sh /tmp/fpdev-main-bin/fpdev`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 83: 2026-04-14 Lazarus/Cross Follow-up Planning
- [x] 新增正式计划：
  - `docs/plans/2026-04-14-lazarus-manager-catalog-surface-wave.md`
  - `docs/plans/2026-04-14-lazarus-manager-maintenance-surface-wave.md`
  - `docs/plans/2026-04-14-cross-manager-install-support-wave.md`
- [x] 基于真实源码重排当前 ROI：锁定 `lazarus.manager` catalog surface、`lazarus.manager` maintenance surface、`cross.manager` install-support surface
- [x] 明确并发策略：Lazarus 两个子波次合并交给同一个 worker，避免并发改写 `src/fpdev.lazarus.manager.pas`
- [x] 拉起 gpt-5.4 团队并行实施
- **Status:** complete

### Phase 84: Lazarus Manager Catalog + Maintenance Wave
- [x] 执行
  - `docs/plans/2026-04-14-lazarus-manager-catalog-surface-wave.md`
  - `docs/plans/2026-04-14-lazarus-manager-maintenance-surface-wave.md`
- [x] 扩展/新增 Lazarus boundary + direct tests
- [x] 新增 `src/fpdev.lazarus.catalogflow.pas`、`src/fpdev.lazarus.maintenanceflow.pas`
- [x] 让 `src/fpdev.lazarus.manager.pas` 的 catalog/maintenance surface 收缩为 thin delegate
- **Status:** complete

### Phase 85: Cross Manager Install-Support Wave
- [x] 执行 `docs/plans/2026-04-14-cross-manager-install-support-wave.md`
- [x] 扩展 `tests/test_cross_manager_boundary.py`
- [x] 新增 `tests/test_cross_installsupportflow.lpr` 与 `src/fpdev.cross.installsupportflow.pas`
- [x] 让 `src/fpdev.cross.manager.pas` 的 downloader/environment surface 收缩为 thin delegate
- **Status:** complete

### Phase 86: Integration + Focused/Full Verification
- [x] 集成 worker 结果（Cross worker 直接收口；Lazarus worker 的 partial handoff 由主控完成最终回接）
- [x] 跑 Python boundary bundle
- [x] 跑 Lazarus / Cross focused Pascal suites
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 78: 2026-04-14 Follow-up Wave Pack Planning
- [x] 新增正式计划：
  - `docs/plans/2026-04-14-fpc-manager-verify-surface-wave.md`
  - `docs/plans/2026-04-14-resource-repo-mirror-surface-wave.md`
  - `docs/plans/2026-04-14-lazarus-manager-version-surface-wave.md`
- [x] 基于真实源码重排当前 ROI：从原先的 `fpc.manager/resource.repo/lazarus.source` 微调为 `fpc.manager verify surface`、`resource.repo mirror surface`、`lazarus.manager version surface`
- [x] 拉起 gpt-5.4 团队并行实施
- **Status:** complete

### Phase 79: FPC Manager Verify Surface Wave
- [x] 执行 `docs/plans/2026-04-14-fpc-manager-verify-surface-wave.md`
- [x] 扩展 boundary/direct tests
- [x] 收口 `src/fpdev.fpc.manager.pas` 的 `VerifyInstallation(...)`
- **Status:** complete

### Phase 80: Resource Repo Mirror Surface Wave
- [x] 执行 `docs/plans/2026-04-14-resource-repo-mirror-surface-wave.md`
- [x] 扩展 boundary/direct tests
- [x] 收口 `src/fpdev.resource.repo.pas` 的 mirror surface
- **Status:** complete

### Phase 81: Lazarus Manager Version Surface Wave
- [x] 执行 `docs/plans/2026-04-14-lazarus-manager-version-surface-wave.md`
- [x] 新增 `src/fpdev.lazarus.versionflow.pas`
- [x] 收口 `src/fpdev.lazarus.manager.pas` 的 list/default/current/info surface
- **Status:** complete

### Phase 82: Integration + Full Verification
- [x] 集成 worker 结果
- [x] 跑 focused suites
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 73: 2026-04-14 Wave Pack Planning
- [x] 新增正式计划：
  - `docs/plans/2026-04-14-fpc-source-surface-wave.md`
  - `docs/plans/2026-04-14-fpc-builder-surface-wave.md`
  - `docs/plans/2026-04-14-build-manager-surface-wave.md`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到 2026-04-14 新排序
- [x] 拉起 gpt-5.4 团队并行实施
- **Status:** complete

### Phase 74: FPC Source Wave
- [x] 执行 `docs/plans/2026-04-14-fpc-source-surface-wave.md`
- [x] 新增 boundary/direct tests
- [x] 新增 `sourceinstallflow` / `sourcebootstrapflow` / `sourcebuildflow`
- [x] 让 `src/fpdev.fpc.source.pas` 目标方法委托到 helper
- **Status:** complete

### Phase 75: FPC Builder Wave
- [x] 执行 `docs/plans/2026-04-14-fpc-builder-surface-wave.md`
- [x] 新增 boundary/direct tests
- [x] 新增 `src/fpdev.fpc.builderflow.pas`
- [x] 让 `src/fpdev.fpc.builder.pas` 目标方法委托到 helper
- **Status:** complete

### Phase 76: Build Manager Wave
- [x] 执行 `docs/plans/2026-04-14-build-manager-surface-wave.md`
- [x] 新增 boundary/direct tests
- [x] 新增 `src/fpdev.build.managerflow.pas`
- [x] 让 `src/fpdev.build.manager.pas` 目标方法委托到 helper
- **Status:** complete

### Phase 77: Integration + Full Verification
- [x] 集成 worker 结果
- [x] 跑 focused suites
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 69: Cross Manager Install/Uninstall Plan Sync
- [x] 新增正式计划：`docs/plans/2026-04-13-cross-manager-install-uninstall-wave.md`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到新的真实 ROI 结论
- [x] 进入 install/uninstall 的 TDD cycle
- **Status:** complete

### Phase 70: Cross Manager Install/Uninstall RED + GREEN
- [x] 扩展 `tests/test_cross_manager_boundary.py`
- [x] 扩展 `tests/test_cross_managerflow.lpr`
- [x] 先运行 RED 证据
- [x] 扩展 `src/fpdev.cross.managerflow.pas`
- [x] 让 `src/fpdev.cross.manager.pas` 的 `InstallTarget(...)` / `UninstallTarget(...)` 委托到 shared helper
- **Status:** complete

### Phase 71: Cross Focused Verification
- [x] 跑 `python3 -m unittest tests.test_cross_manager_boundary -v`
- [x] 跑 `tests/test_cross_managerflow.lpr`
- [x] 跑 `tests/test_cross_management.lpr`
- **Status:** complete

### Phase 72: Full Regression + Planning Sync
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 64: 2026-04-13 Next Hotspot Plan Pack
- [x] 新增正式计划：
  - `docs/plans/2026-04-13-lazarus-source-runtime-config-wave.md`
  - `docs/plans/2026-04-13-resource-bootstrap-surface-wave.md`
  - `docs/plans/2026-04-13-fpc-residual-glue-wave.md`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到新的执行目标
- **Status:** complete

### Phase 65: Lazarus Source Runtime Config Wave
- [x] 执行 `docs/plans/2026-04-13-lazarus-source-runtime-config-wave.md`
- [x] 扩展 `tests/test_lazarus_source_boundary.py`
- [x] 新增 `tests/test_lazarus_sourceruntimeflow.lpr`
- [x] 新增 `src/fpdev.lazarus.sourceruntimeflow.pas`
- [x] 让 `src/fpdev.lazarus.source.pas` 的 runtime/config surface 委托到 helper
- **Status:** complete

### Phase 66: Resource Bootstrap Surface Wave
- [x] 执行 `docs/plans/2026-04-13-resource-bootstrap-surface-wave.md`
- [x] 扩展 `tests/test_resource_repo_boundary.py`
- [x] 新增 `tests/test_resource_repo_bootstrapflow.lpr`
- [x] 新增 `src/fpdev.resource.repo.bootstrapflow.pas`
- [x] 让 `src/fpdev.resource.repo.pas` 的 bootstrap/checksum surface 委托到 helper
- **Status:** complete

### Phase 67: FPC Residual Glue Wave
- [x] 执行 `docs/plans/2026-04-13-fpc-residual-glue-wave.md`
- [x] 新增 `tests/test_fpc_manager_residual_boundary.py`
- [x] 新增 `tests/test_fpc_residualflow.lpr`
- [x] 新增 `src/fpdev.fpc.residualflow.pas`
- [x] 让 `src/fpdev.fpc.manager.pas` 的 residual glue surface 委托到 helper
- **Status:** complete

### Phase 68: Focused + Full Regression
- [x] 跑 Lazarus / resource / FPC focused suites
- [x] 跑 Python boundary bundle
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 63: Post-Project Hotspot Re-Evaluation
- [x] 重新核对 `src/fpdev.resource.repo.pas`、`src/fpdev.lazarus.source.pas`、`src/fpdev.fpc.manager.pas` 的剩余 inline surface
- [x] 复核 `src/fpdev.project.manager.pas`、`src/fpdev.package.manager.pas`、`src/fpdev.cross.search.pas` 是否仍应保持 checkpoint
- [x] 基于真实方法体量、helper 复用度、现有测试护栏和实施爆炸半径重排下一波 ROI
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 61: Project Create Surface Wave
- [x] 执行 `docs/plans/2026-04-13-project-create-surface-wave.md`
- [x] 扩展 `tests/test_project_manager_boundary.py`
- [x] 新增 `tests/test_project_createflow.lpr`
- [x] 新增 `src/fpdev.project.createflow.pas`
- [x] 让 `src/fpdev.project.manager.pas` 的 `CreateFromTemplate(...)` / `CreateProject(...)` 委托到 helper
- **Status:** complete

### Phase 62: Project Checkpoint + Final Regression
- [x] 跑 `python3 -m unittest tests.test_project_manager_boundary tests.test_package_manager_boundary tests.test_cross_search_boundary -v`
- [x] 跑 focused project regressions
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 57: 2026-04-13 Follow-up Plan Pack
- [x] 新增正式计划：
  - `docs/plans/2026-04-13-fpc-maintenance-surface-wave.md`
  - `docs/plans/2026-04-13-lazarus-source-lifecycle-wave.md`
  - `docs/plans/2026-04-13-resource-package-surface-wave.md`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到本轮真实优先级与 checkpoint 范围
- **Status:** complete

### Phase 58: FPC Maintenance + Lazarus Source Lifecycle Wave
- [x] 执行 `docs/plans/2026-04-13-fpc-maintenance-surface-wave.md`
- [x] 执行 `docs/plans/2026-04-13-lazarus-source-lifecycle-wave.md`
- [x] 新增 `tests/test_fpc_manager_maintenance_boundary.py`、`tests/test_fpc_maintenanceflow.lpr`
- [x] 新增 `tests/test_lazarus_sourcelifecycleflow.lpr` 并扩展 `tests/test_lazarus_source_boundary.py`
- [x] 新增 `src/fpdev.fpc.maintenanceflow.pas`、`src/fpdev.lazarus.sourcelifecycleflow.pas`
- [x] 让 `src/fpdev.fpc.manager.pas` 与 `src/fpdev.lazarus.source.pas` 的目标方法委托到 shared helper
- **Status:** complete

### Phase 59: Resource Package Surface + Package Checkpoint
- [x] 执行 `docs/plans/2026-04-13-resource-package-surface-wave.md`
- [x] 新增 `tests/test_resource_repo_packagesurfaceflow.lpr` 并扩展 `tests/test_resource_repo_boundary.py`
- [x] 新增 `src/fpdev.resource.repo.packageflow.pas`
- [x] 让 `src/fpdev.resource.repo.pas` 的 package info/list/search facade 委托到 helper
- [x] 跑 `package.manager` checkpoint，确认 install/update/dependency surface 继续保持 thin
- **Status:** complete

### Phase 60: Cross / Package / Release Checkpoint + Final Regression
- [x] 跑 `python3 -m unittest tests.test_package_manager_boundary tests.test_resource_repo_boundary tests.test_cross_search_boundary tests.test_release_docs_contract -v`
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 53: 2026-04-13 Hotspot Plan Pack
- [x] 新增正式计划：
  - `docs/plans/2026-04-13-cross-search-orchestration-wave.md`
  - `docs/plans/2026-04-13-fpc-install-surface-wave.md`
  - `docs/plans/2026-04-13-project-resource-followup-wave.md`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到本轮真实排序与 checkpoint 范围
- **Status:** complete

### Phase 54: Cross Search + FPC Install Surface Wave
- [x] 执行 `docs/plans/2026-04-13-cross-search-orchestration-wave.md`
- [x] 执行 `docs/plans/2026-04-13-fpc-install-surface-wave.md`
- [x] 新增 `tests/test_cross_searchflow.lpr`、`tests/test_fpc_installsurfaceflow.lpr`
- [x] 新增 `src/fpdev.cross.searchflow.pas`、`src/fpdev.fpc.installsurfaceflow.pas`
- [x] 让 `src/fpdev.cross.search.pas` 的 `SearchBinutilsWithConfig(...)` 委托到 shared helper
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `InstallVersion(...)` 委托到 install surface helper
- **Status:** complete

### Phase 55: Project Update + Resource Query Follow-Up
- [x] 执行 `docs/plans/2026-04-13-project-resource-followup-wave.md`
- [x] 扩展 `src/fpdev.project.templateflow.pas`，承接 `UpdateTemplates(...)` orchestration
- [x] 新增 `src/fpdev.resource.repo.queryflow.pas`
- [x] 让 `src/fpdev.resource.repo.pas` 的 bootstrap/binary/cross manifest queries 委托到 query helper
- [x] 跑 project/resource focused tests
- **Status:** complete

### Phase 56: Package / Release Checkpoint + Final Regression
- [x] 复核 `src/fpdev.package.manager.pas` 保持 thin，不为了“全部”强造新 helper
- [x] 跑 `python3 -m unittest tests.test_package_manager_boundary tests.test_release_docs_contract -v`
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 52: Next Hotspot Re-Evaluation
- [x] 基于 `src/fpdev.cross.search.pas` / `src/fpdev.fpc.manager.pas` / `src/fpdev.project.manager.pas` / `src/fpdev.resource.repo.pas` 的真实行数与剩余 inline 面，重新排序本轮 ROI 最高切口
- [x] 确认 `package.manager` 已较薄、release docs contract 当前为绿，不再重复打开伪热点
- [x] 锁定本轮切口为 `cross.search` orchestration、`fpc.manager` install surface、`project.UpdateTemplates`、`resource.repo` queryflow
- **Status:** complete

### Phase 51: Final Regression & Planning Sync
- [x] 跑 `python3 -m unittest tests.test_lazarus_source_boundary -v`
- [x] 跑 `tests/test_lazarus_sourceversionflow.lpr`
- [x] 跑 `tests/test_lazarus_update.lpr`
- [x] 跑整仓回归 `bash scripts/run_all_tests.sh`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md` 到当前真实状态
- **Status:** complete

### Phase 50: Cross Search Diagnose / FPC Index / Lazarus Source Versionflow Wave
- [x] 执行 `docs/plans/2026-04-12-cross-search-diagnose-wave.md`
- [x] 执行 `docs/plans/2026-04-12-fpc-manager-index-cleanup-wave.md`
- [x] 执行 `docs/plans/2026-04-12-lazarus-source-versionflow-wave.md`
- [x] 新增 `tests/test_cross_searchdiag.lpr`、`tests/test_fpc_indexflow.lpr`、`tests/test_lazarus_sourceversionflow.lpr`
- [x] 新增 `src/fpdev.cross.searchdiag.pas`、`src/fpdev.fpc.indexflow.pas`、`src/fpdev.lazarus.sourceversionflow.pas`
- [x] 让 `src/fpdev.cross.search.pas` 的 diagnose/log helper 委托到 shared flow
- [x] 让 `src/fpdev.fpc.manager.pas` 的 index update helper 委托到 shared flow，并删除重复 dead helper
- [x] 让 `src/fpdev.lazarus.source.pas` 的 static version/description/available-version 逻辑委托到 shared flow
- [x] 修复 `LAZARUS_VERSIONS` 静态数组常量与 helper dynamic-array 形参不兼容的问题，改为 open-array contract
- [x] 跑 focused tests 与整仓回归 `290/290`
- **Status:** complete

### Phase 49: Next Hotspot Re-Evaluation
- [x] 基于 `src/fpdev.cross.search.pas` / `src/fpdev.fpc.manager.pas` / `src/fpdev.lazarus.source.pas` 本轮收口后的真实状态，重新排序下一个 ROI 最高的切口
- [x] 确认 `fpc.manager` source/info facade 与 `lazarus.source` 首刀 sourceflow 已经存在，不重复打开旧切口
- [x] 选择本轮新切口为 `cross.search` diagnose/log、`fpc.manager` index cleanup、`lazarus.source` versionflow
- [x] 新增三份正式 plan 并进入新的 TDD cycle
- **Status:** complete
### Phase 48: Cross Search / Project Exec / Package Tail Wave
- [x] 执行 `docs/plans/2026-04-12-cross-search-paths-wave.md`
- [x] 执行 `docs/plans/2026-04-12-project-exec-surface-wave.md`
- [x] 执行 `docs/plans/2026-04-12-package-tail-facade-wave.md`
- [x] 新增 `tests/test_cross_search_boundary.py`、`tests/test_cross_searchpaths.lpr` 与 `src/fpdev.cross.searchpaths.pas`
- [x] 让 `src/fpdev.cross.search.pas` 的 `GetPrefixCandidates(...)` / `SearchLibraries(...)` 委托到 shared helper
- [x] 新增 `tests/test_project_exec_boundary.py`、`tests/test_project_cleanflow.lpr` 与 `src/fpdev.project.cleanflow.pas`
- [x] 让 `src/fpdev.project.manager.pas` 的 `CleanProject(...)` 委托到 `ExecuteProjectCleanCore(...)`
- [x] 新增 `tests/test_package_tail_boundary.py` 并收紧 `tests/test_package_facadeflow.lpr` callback contract
- [x] 让 `src/fpdev.package.facadeflow.pas` 的纯 helper callback 改为 plain function，并删除 `src/fpdev.package.manager.pas` 中 4 个纯 wrapper
- [x] 跑 cross/project/package focused tests 与整仓回归 `287/287`
- **Status:** complete

### Phase 47: Next Hotspot Selection
- [x] 重新评估 2026-04-12 wave pack 之后的最大 ROI 热点
- [x] 确认 `project.execflow` / `package facadeflow` 已存在，不重复打开旧切口
- [x] 选择本轮新切口为 `cross.search` / `project execution surface` / `package tail facade`
- [x] 新增三份正式 plan 并进入新的 TDD cycle
- **Status:** complete

### Phase 46: Cross Manager Flow Wave
- [x] 执行 `docs/plans/2026-04-12-cross-manager-search-wave.md` 中 list/info/update/clean 这一刀
- [x] 新增 `tests/test_cross_manager_boundary.py` 与 `tests/test_cross_managerflow.lpr`
- [x] 新增 `src/fpdev.cross.managerflow.pas`
- [x] 让 `src/fpdev.cross.manager.pas` 的 `ListTargets(...)` / `ShowTargetInfo(...)` / `UpdateTarget(...)` / `CleanTarget(...)` 委托到 shared flow
- [x] 跑 `tests.test_cross_manager_boundary`、`tests/test_cross_managerflow.lpr`、`tests/test_cross_targetflow.lpr`、`tests/test_cross_management.lpr` 与全量回归
- **Status:** complete

### Phase 45: Package Resource Hotspot Wave
- [x] 执行 `docs/plans/2026-04-12-package-resource-hotspot-wave.md`
- [x] 新增 `tests/test_package_manager_boundary.py`、`tests/test_resource_repo_boundary.py`、`tests/test_package_resource_flow.lpr`
- [x] 新增 `src/fpdev.package.managerflow.pas` 与 `src/fpdev.resource.repo.mirrorflow.pas`
- [x] 让 `src/fpdev.package.manager.pas` 与 `src/fpdev.resource.repo.pas` 委托到 shared flow
- [x] 跑 `tests.test_package_manager_boundary`、`tests.test_resource_repo_boundary`、`tests/test_package_resource_flow.lpr`、`tests/test_package_manager_installupdateflow.lpr`、`tests/test_resource_repo_mirror.lpr` 与全量回归
- **Status:** complete

### Phase 44: Project Manager Slicing Wave
- [x] 执行 `docs/plans/2026-04-12-project-manager-slicing-wave.md`
- [x] 新增 `tests/test_project_manager_boundary.py` 与 `tests/test_project_templateflow.lpr`
- [x] 新增 `src/fpdev.project.templateflow.pas`
- [x] 让 `src/fpdev.project.manager.pas` 的 template list/info/install/remove/update-sync 逻辑委托到 shared flow
- [x] 跑 `tests.test_project_manager_boundary`、`tests/test_project_templateflow.lpr`、`tests/test_project_template_commands.lpr` 与后续全量回归
- **Status:** complete

### Phase 43: Lazarus Source Slicing Wave
- [x] 执行 `docs/plans/2026-04-12-lazarus-source-slicing-wave.md`
- [x] 新增 `tests/test_lazarus_source_boundary.py`，锁定 source manager 对 `fpdev.lazarus.sourceflow` 的委托边界
- [x] 新增 `tests/test_lazarus_sourceflow.lpr`，为 sourceflow helper 补 direct RED/GREEN 覆盖
- [x] 新增 `src/fpdev.lazarus.sourceflow.pas`，承接 version/path/plan/make-params/source-tree helper
- [x] 让 `src/fpdev.lazarus.source.pas` 的 clone/update/build/source-path 逻辑委托到 shared helper
- [x] 跑 `tests.test_lazarus_source_boundary`、`tests/test_lazarus_sourceflow.lpr`、`tests/test_lazarus_update.lpr`、`tests/test_lazarus_flow.lpr` 与全量回归
- **Status:** complete

### Phase 41: Remaining Hotspot Plan Pack
- [x] 新增 `docs/plans/2026-04-12-fpc-manager-versionflow-wave.md`
- [x] 新增 `docs/plans/2026-04-12-lazarus-source-slicing-wave.md`
- [x] 新增 `docs/plans/2026-04-12-project-manager-slicing-wave.md`
- [x] 新增 `docs/plans/2026-04-12-package-resource-hotspot-wave.md`
- [x] 新增 `docs/plans/2026-04-12-cross-manager-search-wave.md`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 42: FPC Manager Versionflow Wave
- [x] 新增 `tests/test_fpc_manager_version_boundary.py`
- [x] 新增 `tests/test_fpc_versionflow.lpr`
- [x] 新增 `src/fpdev.fpc.versionflow.pas`
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `ListVersions(...)` / `ActivateVersion(...)` 委托到 shared flow
- [x] 让 `src/fpdev.fpc.version.pas` 复用 shared flow 的 default version normalization
- [x] 跑 focused tests 与全量回归
- **Status:** complete

### Phase 39: Manager Hotspot Roadmap Reset
- [x] 新增总路线图 `docs/plans/2026-04-11-manager-hotspot-roadmap.md`
- [x] 记录当前 hotspot 排序与切换理由，不再继续优先追 `src/fpdev.lazarus.manager.pas`
- [x] 同步 `task_plan.md`、`findings.md`、`progress.md`
- **Status:** complete

### Phase 40: FPC Manager Statusflow Wave
- [x] 新增正式计划 `docs/plans/2026-04-11-fpc-manager-statusflow-wave.md`
- [x] 新增 `tests/test_fpc_manager_status_boundary.py`，锁定 `src/fpdev.fpc.manager.pas` 对 `fpdev.fpc.statusflow` 的委托边界
- [x] 新增 `tests/test_fpc_statusflow.lpr`，为 `BuildManagedFPCStatusCore(...)` 写 direct helper RED 覆盖
- [x] 新增 `src/fpdev.fpc.statusflow.pas`，承接 manager 级 status orchestration
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `GetStatus(...)` 委托到 shared flow
- [x] 跑 `tests/test_fpc_manager_status_boundary.py`、`tests/test_fpc_statusflow.lpr`、`tests/test_fpc_status.lpr` 与全量回归
- [x] 更新 hotspot 文档与 planning files
- **Status:** complete

### Phase 1: Red Test Setup
- [x] 在现有 `tests/test_fpc_runtimeflow.lpr` 中补 focused helper 语义断言
- [x] 用 `Can't find unit fpdev.git.errors` 编译失败确认 RED
- **Status:** complete

### Phase 2: Minimal Extraction
- [x] 创建 `src/fpdev.git.errors.pas`
- [x] 让 `fpdev.fpc.runtimeflow` 与 `fpdev.lazarus.commandflow` 直接改用新 helper
- [x] 让 `fpdev.utils.git` 保留兼容入口但内部转发到新 helper
- **Status:** complete

### Phase 3: Verification
- [x] 跑新的 focused helper 测试
- [x] 跑 `test_fpc_runtimeflow`
- [x] 跑 `test_lazarus_runtimeflow`
- [x] 跑 `test_lazarus_update` 确认 `lazarus.manager -> git.runtime -> utils.git` 链路仍可编译并通过
- [x] 更新 planning files 记录结果
- **Status:** complete

### Phase 4: Shared Normalizer Extraction
- [x] 在 `tests/test_fpc_runtimeflow.lpr` 中新增对 `NormalizeGitPullErrorDetail` 的 direct helper 断言
- [x] 用缺失符号 `Identifier not found "NormalizeGitPullErrorDetail"` 确认 RED
- [x] 将 `NormalizeGitPullErrorDetail` 抽到 `src/fpdev.git.errors.pas`
- [x] 删除 `src/fpdev.fpc.runtimeflow.pas` 与 `src/fpdev.lazarus.commandflow.pas` 中的重复实现
- [x] 跑 `test_fpc_runtimeflow`、`test_lazarus_runtimeflow`、`test_lazarus_update`
- **Status:** complete

### Phase 5: Backend Type Extraction
- [x] 新建 `src/fpdev.git.types.pas` 承载 `TGitBackend` 与 `GitBackendToString`
- [x] 让 `src/fpdev.lazarus.manager.pas`、`src/fpdev.lazarus.source.pas`、`src/fpdev.fpc.builder.pas`、`src/fpdev.resource.repo.pas` 和 `tests/test_lazarus_update.lpr` 改用轻量类型单元
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.git.runtime` 对轻量类型单元的显式依赖断言
- [x] 用 `tests/test_git_runtime_boundary.py` RED 和 `test_fpc_builder.lpr` 的 `Identifier not found "gbNone"` 编译失败确认断点
- [x] 修复 `src/fpdev.git.runtime.pas`，显式引入 `fpdev.git.types`
- [x] 跑 `tests/test_git_runtime_boundary.py`、`test_lazarus_update`、`test_fpc_builder`、`test_resource_repo_bootstrap`
- **Status:** complete

### Phase 6: Runtime Contract Slimming
- [x] 盘点 `fpdev.git.runtime` 仍从 `fpdev.utils.git` 暴露的类型与构造依赖
- [x] 选择更小的下一刀：先收缩 `TGitRuntime` 的业务侧创建面，不立即抽 `IGitCliRunner`
- [x] 在 `tests/test_git_runtime_boundary.py` 中补业务模块不得直接 `TGitRuntime.Create` 的断言
- [x] 用 `tests/test_git_runtime_boundary.py` RED 确认直接构造回归
- [x] 在 `src/fpdev.git.runtime.pas` 新增 `NewGitRuntime(...)`
- [x] 将 `src/fpdev.source.repo.pas`、`src/fpdev.fpc.builder.pas`、`src/fpdev.lazarus.source.pas`、`src/fpdev.resource.repo.pas`、`src/fpdev.fpc.manager.pas`、`src/fpdev.lazarus.manager.pas` 切到 runtime factory
- [x] 跑 `tests/test_git_runtime_boundary.py`、`test_lazarus_update`、`test_fpc_builder`、`test_resource_repo_bootstrap`、`test_fpc_source_repo`、`test_fpc_update`
- **Status:** complete

### Phase 7: Runtime Interface Sealing
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.git.runtime` interface 不再泄漏 `fpdev.utils.git` contract 的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 `fpdev.git.runtime` interface 仍暴露 `fpdev.utils.git`、`TGitOperations`、`IGitCliRunner`
- [x] 将 `src/fpdev.git.runtime.pas` 的 interface uses 收缩到 `fpdev.git.types`
- [x] 将 `TGitRuntime` 实现类及其对 `TGitOperations` / `IGitCliRunner` 的依赖缩回 `implementation`
- [x] 跑 `tests/test_git_runtime_boundary.py`、`test_lazarus_update`、`test_fpc_builder`、`test_resource_repo_bootstrap`、`test_fpc_source_repo`、`test_fpc_update`
- **Status:** complete

### Phase 8: Runtime Runner Cleanup
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.git.runtime` 不再提及 `IGitCliRunner` 的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 runtime 文件仍残留 `IGitCliRunner`
- [x] 删除 `src/fpdev.git.runtime.pas` 中仅剩的 runner-based constructor 路径
- [x] 保持公开接口仍为 `IGitRuntime + NewGitRuntime(...)`
- [x] 跑 `tests/test_git_runtime_boundary.py`、`test_lazarus_update`、`test_fpc_builder`、`test_fpc_source_repo`、`test_fpc_update`
- **Status:** complete

### Phase 9: Git Runner Contract Re-Evaluation
- [x] 重新评估 `IGitCliRunner` 是否还有必要从 `fpdev.utils.git` 继续外提
- [x] 确认单独抽 runner contract 的收益不足以覆盖 `fpdev.utils.process.TProcessResult` 的额外耦合
- [x] 转向下一个更有收益的 `fpdev.utils.git` 纯兼容残留：抽取 Git env helper 到 `fpdev.git.env`
- [x] 让 `tests/test_git_env_credentials.lpr` 与 `tests/test_git_env_identity.lpr` 直接依赖轻量 env 单元
- [x] 修复 `tests/test_git_operations.lpr` 对 backend enum 的隐式依赖，显式引入 `fpdev.git.types`
- **Status:** complete

### Phase 10: Legacy Git Facade Runtime Migration
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.git.pas` 不再直绑 `fpdev.utils.git` / `TGitOperations` 的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认旧 facade 仍直接依赖 `TGitOperations`
- [x] 扩展 `src/fpdev.git.runtime.pas`，补齐 compat facade 需要的最小 pass-through 方法
- [x] 为 merge-capable update 单独提供 runtime 入口，避免改变现有 ff-only `Pull` 语义
- [x] 将 `src/fpdev.git.pas` 改为依赖 `IGitRuntime` / `NewGitRuntime`
- [x] 跑 `tests/test_git_runtime_boundary.py`、`test_git_facade.lpr` 和 `tests/fpdev.git2.adapter/test_git.lpr` 编译验证
- **Status:** complete

### Phase 11: FPC Builder DI Git Runtime Bridge
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.fpc.builder.di.pas` 不再直绑 `fpdev.utils.git` contract 的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 `builder.di` 仍残留 `fpdev.utils.git` 文本依赖
- [x] 新增 `src/fpdev.fpc.builder.gitruntime.pas`，承接 builder 专用的 process-runner -> git clone bridge
- [x] 将 `src/fpdev.fpc.builder.di.pas` 改为调用 `CloneRepositoryWithProcessRunner(...)`
- [x] 清理 `builder.di` 中残留的 `fpdev.utils.git` 注释文本，收紧到真实代码边界
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_fpc_builder.lpr` 和 `tests.test_style_regressions_batch19`
- **Status:** complete

### Phase 12: Business Module Git Narrative Cleanup
- [x] 在 `tests/test_git_runtime_boundary.py` 中补业务单元不再直接提及 `TGitOperations` 叙事的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认旧注释仍残留 `TGitOperations`
- [x] 清理 `src/fpdev.resource.repo.pas`、`src/fpdev.fpc.builder.pas`、`src/fpdev.lazarus.source.pas` 中对 legacy concrete type 的描述
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_fpc_builder.lpr`、`tests/test_resource_repo_bootstrap.lpr`、`tests/test_lazarus_update.lpr`
- **Status:** complete

### Phase 13: Shared Pull Failure Type Reuse
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.utils.git` 复用共享 pull failure enum 的断言
- [x] 在 `tests/test_git_operations.lpr` 中补 legacy `ClassifyGitPullFailure` 兼容断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 `fpdev.utils.git` 仍本地重复定义 `TGitPullFailureKind`
- [x] 将 `src/fpdev.utils.git.pas` 改为复用 `fpdev.git.errors.TGitPullFailureKind`，并重导出同名常量
- [x] 将 `ClassifyGitPullFailure(...)` 收敛为直接转发到共享 helper
- [x] 跑 `tests/test_git_runtime_boundary.py` 与 `tests/test_git_operations.lpr`
- **Status:** complete

### Phase 14: Compat Wrapper Internal Call Cleanup
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.utils.git` 内部逻辑直连共享 helper 的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认内部逻辑仍通过 compat wrapper 自调用
- [x] 将 `src/fpdev.utils.git.pas` 中内部 credential / identity / pull-failure 调用改为直连 `fpdev.git.env` / `fpdev.git.errors`
- [x] 保留 compat wrapper 作为对外入口，但不再让内部逻辑依赖这些 wrapper
- [x] 跑 `tests/test_git_runtime_boundary.py` 与 `tests/test_git_operations.lpr`
- **Status:** complete

### Phase 15: Shared-By-Default Compat Test Cleanup
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `tests/test_git_operations.lpr` 对 shared helper / compat helper 的显式意图断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 `test_git_operations` 还没有区分 shared-by-default 与 legacy compatibility 调用
- [x] 将 `tests/test_git_operations.lpr` 改为默认调用 `fpdev.git.types.GitBackendToString(...)`
- [x] 为 `fpdev.utils.git.GitBackendToString(...)` 与 `fpdev.utils.git.ClassifyGitPullFailure(...)` 补显式 legacy compatibility case
- [x] 在 `src/fpdev.utils.git.pas` compat helper 区域补用途说明，明确其仅为外部兼容入口
- [x] 跑 `tests/test_git_runtime_boundary.py` 与 `tests/test_git_operations.lpr`
- **Status:** complete

### Phase 16: Shared-By-Default Env Compat Test Cleanup
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 env focused tests 对 shared helper / compat helper 的显式意图断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 env tests 还没有区分 shared-by-default 与 legacy compatibility 调用
- [x] 将 `tests/test_git_env_credentials.lpr` 与 `tests/test_git_env_identity.lpr` 改为默认显式调用 `fpdev.git.env`
- [x] 为 `fpdev.utils.git.ResolveGitCredentialEnv(...)` 与 `fpdev.utils.git.ResolveGitIdentityEnv(...)` 补显式 legacy compatibility case
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_git_env_credentials.lpr`、`tests/test_git_env_identity.lpr`
- **Status:** complete

### Phase 17: Compat Consumer Boundary Codification
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 repo 内 compat helper 显式消费者白名单断言
- [x] 用当前仓库内搜索结果确认 compat helper 只剩 legacy tests 与 runtime/builder bridge 的直接依赖面
- [x] 为 `tests/test_git_operations.lpr`、`tests/test_git_env_credentials.lpr`、`tests/test_git_env_identity.lpr` 的 legacy case 补直白说明，标注它们是显式 compat coverage
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_git_operations.lpr`、`tests/test_git_env_credentials.lpr`、`tests/test_git_env_identity.lpr`
- **Status:** complete

### Phase 18: Public Compat Surface Staging
- [x] 在 `tests/test_git_runtime_boundary.py` 中把 compat helper 白名单收紧到 dedicated legacy suite，并为迁移文档/legacy surface 标识补断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认当前 inline compat coverage 与缺失文档会触发失败
- [x] 将 `tests/test_git_operations.lpr`、`tests/test_git_env_credentials.lpr`、`tests/test_git_env_identity.lpr` 改回 shared-only 默认覆盖
- [x] 新增 `tests/test_git_compat_legacy.lpr`，集中承载 compat helper 的 legacy compatibility coverage
- [x] 在 `src/fpdev.utils.git.pas` interface 中明确标注 legacy compatibility surface，并新增 `docs/GIT_COMPAT_MIGRATION.md`
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_git_operations.lpr`、`tests/test_git_env_credentials.lpr`、`tests/test_git_env_identity.lpr`、`tests/test_git_compat_legacy.lpr`
- **Status:** complete

### Phase 19: Runtime Impl Unit Split
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 runtime contract/impl 分离断言，要求 `src/fpdev.git.runtime.impl.pas` 承载 `TGitRuntime`
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认当前 runtime 文件仍同时承载 contract 与实现
- [x] 新增 `src/fpdev.git.runtime.impl.pas`，承接 `TGitRuntime` 和 `TGitOperations` 依赖
- [x] 将 `src/fpdev.git.runtime.pas` 收敛为 `IGitRuntime + NewGitRuntime(...)` + factory forwarding
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_git_facade.lpr`、`tests/test_fpc_builder.lpr`、`tests/test_lazarus_update.lpr`、`tests/test_fpc_source_repo.lpr`
- **Status:** complete

### Phase 20: Compat Alias Boundary Codification
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `TGitBackend` / `TGitPullFailureKind` / `gpfk*` 兼容 alias/常量的 explicit legacy-consumer 边界断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 dedicated legacy suite 和迁移文档尚未覆盖这些 compat alias/常量
- [x] 在 `tests/test_git_compat_legacy.lpr` 中补 alias/常量兼容覆盖
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md` 与 `src/fpdev.utils.git.pas`，把 alias/常量 compat 面说明补齐
- [x] 跑 `tests/test_git_runtime_boundary.py` 与 `tests/test_git_compat_legacy.lpr`
- **Status:** complete

### Phase 21: Default Operations Entrypoint Migration
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.git.operations` 默认入口断言，并要求 runtime impl / builder bridge / `test_git_operations` 停止直连 `fpdev.utils.git`
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 `src/fpdev.git.operations.pas` 尚不存在，且 runtime impl 仍直连 `fpdev.utils.git`
- [x] 新增 `src/fpdev.git.operations.pas`，桥接 `TGitOperations` / `IGitCliRunner`
- [x] 将 `src/fpdev.git.runtime.impl.pas`、`src/fpdev.fpc.builder.gitruntime.pas`、`tests/test_git_operations.lpr` 切到 `fpdev.git.operations`
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`，把 `TGitOperations` / `IGitCliRunner` 的默认入口写为 `fpdev.git.operations`
- [x] 跑 `tests/test_git_runtime_boundary.py`、`tests/test_git_operations.lpr`、`tests/test_fpc_builder.lpr`、`tests/test_git_facade.lpr`
- **Status:** complete

### Phase 22: Operations Facade Narrative Hardening
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `fpdev.utils.git` direct import 白名单，并要求 `src/fpdev.git.operations.pas` / `src/fpdev.utils.git.pas` 补默认入口与迁移提示文案
- [x] 承接上一轮 RED，把 `src/fpdev.git.operations.pas` 与 `src/fpdev.utils.git.pas` 的缺失叙事注释补齐
- [x] 跑 `python3 -m unittest tests.test_git_runtime_boundary -v`
- **Status:** complete

### Phase 23: Compat Surface Soft Deprecation
- [x] 在 `tests/test_git_runtime_boundary.py` 中新增 compat alias/helper 的 soft-deprecation staging 断言，并要求迁移文档声明 compiler warnings
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 `fpdev.utils.git` 和 `docs/GIT_COMPAT_MIGRATION.md` 尚未带 deprecation 提示
- [x] 在 `src/fpdev.utils.git.pas` 为 compat alias/const/helper 加上 `deprecated` 提示，并让内部实现改用 shared type/const 避免自触发 warning
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`，明确 compat public surface 已进入 soft-deprecated 状态
- [x] 跑 `python3 -m unittest tests.test_git_runtime_boundary -v`、`tests/test_git_compat_legacy.lpr`、`tests/test_git_operations.lpr`
- **Status:** complete

### Phase 24: Removal Staging And Bridge Decisions
- [x] 重新扫描 `fpdev.utils.git` deprecated public surface 的仓库内 Pascal caller，并按 A/B/C 组整理 removal staging
- [x] 在 `tests/test_git_runtime_boundary.py` 中把 compat alias/helper 的 caller 白名单扩大到全仓 `src/*.pas` + `tests/*.pas` + `tests/*.lpr`
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`，写清楚 next breaking window candidate removal 清单、保留的实现桥接面，以及 builder/test 结构决策
- [x] 在 `src/fpdev.fpc.builder.gitruntime.pas` 和 `tests/test_git_operations.lpr` 补结构定位注释，并用 boundary test 固化
- [x] 跑 `python3 -m unittest tests.test_git_runtime_boundary -v`、`tests/test_git_compat_legacy.lpr`、`tests/test_git_operations.lpr`、`tests/test_fpc_builder.lpr`
- **Status:** complete

### Phase 25: Breaking Removal Of Compat Helpers
- [x] 从 `src/fpdev.utils.git.pas` 删除 A 组 compat alias/helper public surface
- [x] 删除 `tests/test_git_compat_legacy.lpr`，并把 boundary/doc 从 staging 语义切换到 removal-complete
- [x] 跑 `python3 -m unittest tests.test_git_runtime_boundary -v`、`tests/test_git_operations.lpr`、`tests/test_fpc_builder.lpr`，并额外验证 `tests/test_git_compat_legacy.lpr` 已不存在
- **Status:** complete

### Phase 26: Final Git Compat Shim Removal
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 `src/fpdev.utils.git.pas` 必须不存在、release notes/changelog 必须发布 breaking summary 的断言
- [x] 用 `python3 -m unittest tests.test_git_runtime_boundary -v` RED 确认 shim 仍存在且文档仍是 soft-deprecated 口径
- [x] 删除 `src/fpdev.utils.git.pas`
- [x] 将 `docs/GIT_COMPAT_MIGRATION.md` 切到 removal-complete 叙事
- [x] 更新 `CHANGELOG.md`、`RELEASE_NOTES.md`、`CLAUDE.md` 以及 active/history docs 中关于 compat shim 的当前工作树说明
- [x] 跑 `python3 -m unittest tests.test_run_prettier_sh tests.test_contributor_docs_contract tests.test_git_runtime_boundary -v`
- [x] 跑 `python3 -m unittest tests.test_style_regressions_batch19 -v`
- [x] 使用 `bash scripts/run_prettier.sh --write/--check` 校验相关文档
- [x] 跑 `/tmp` 下的 focused Pascal suites：`tests/test_git_operations.lpr`、`tests/test_git_facade.lpr`、`tests/test_fpc_builder.lpr`
- **Status:** complete

### Phase 27: Release Status Wording Contract Resync
- [x] 跑 `python3 -m unittest discover -s tests -p 'test_*.py'` 复查全量 Python discover
- [x] 定位 `tests/test_release_status_wording.py` 对旧发布口径的 4 个失配
- [x] 将 release wording 契约同步到当前已发布状态
- [x] 跑 `python3 -m unittest tests.test_release_status_wording -v`
- [x] 重新跑 `python3 -m unittest discover -s tests -p 'test_*.py'`
- **Status:** complete

### Phase 28: Full Pascal Regression After Git Compat Removal
- [x] 跑 `bash scripts/run_all_tests.sh`
- [x] 确认仓库标准 Pascal 回归为 `275/275`
- **Status:** complete

## Key Questions
1. 已决：`src/fpdev.fpc.builder.gitruntime.pas` 继续保留为 builder 专用兼容缝，直到出现第二个非 builder caller 再考虑抽通用 CLI clone adapter。
2. 已决：`tests/test_git_operations.lpr` 保持为 `fpdev.git.operations` 默认入口的 focused contract suite，不再视为 compat layer direct consumer。
3. 已决：`fpdev.utils.git` 已在本轮 breaking removal 中整体删除；仓库内 Pascal caller 已归零，legacy compat suite 也已删除。

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 不继续追逐已落地或已过期的 2/3 月计划 | 当前代码树里质量分析器、repo maintenance、cross-platform hardening、remote registry 等计划都已基本落地 |
| 选择 Git pull 错误分类作为下一刀 | 它是纯逻辑、调用面小、收益明确，适合作为 `fpdev.utils.git` 解耦的第一步 |
| 紧接着抽取错误文案归一化，而不是立即动更大的 Git runtime/API 面 | 这一步仍然是纯逻辑，风险低，且可以顺手消除两个 flow 单元的重复实现 |
| 把 backend enum/string helper 单独收口到 `fpdev.git.types` | 这组符号被多个业务单元消费，但本身不该强绑到 `fpdev.utils.git` 巨石 |
| 为 `fpdev.git.runtime` 增加轻量类型 import 的 boundary test | 这类回归本质是接口可见性断裂，Python 文本契约能比大编译更早给出定位 |
| 在抽更深 contract 之前，先让业务模块改走 `NewGitRuntime(...)` 工厂 | 这一步改动面小、风险低，并且先把构造细节从业务侧收回到 runtime 单元 |
| 对 `fpdev.git.runtime` 继续采用“隐藏实现类”而不是“新建更多 facade” | 直接把 `TGitRuntime` 收回 `implementation`，可以最小代价去掉 interface 层对 `fpdev.utils.git` 的依赖 |
| runtime 文件里若已无外部 runner 调用面，就继续删掉 `IGitCliRunner` 痕迹 | 这比马上抽新单元更小，也先把 runtime 单元彻底收口 |
| 不继续把 `IGitCliRunner` 单独抽成新 contract unit | 当前只剩 `fpdev.fpc.builder.di` 和 `tests/test_git_operations.lpr` 两处 runner 消费，继续抽会把 `fpdev.utils.process.TProcessResult` 耦合整体搬家，净收益偏低 |
| Phase 9 改为抽取 Git env helper，而不是继续拆 runner | `ResolveGitCredentialEnv` / `ResolveGitIdentityEnv` 是纯逻辑、调用面极小，更适合作为下一刀纯兼容残留 |
| 继续把 `fpdev.git.pas` 旧 facade 改走 `IGitRuntime` | 这是兼容层，不该继续直绑 `TGitOperations`；改走 runtime 可以继续缩小 `fpdev.utils.git` 的直接消费面 |
| 不修改现有 `runtime.Pull` 的 ff-only 语义 | `src/fpdev.fpc.runtimeflow.pas` 与 `src/fpdev.lazarus.commandflow.pas` 现有调用已建立在该语义上，compat facade 需要的 merge-capable update 另开明确入口更安全 |
| 对 `fpdev.fpc.builder.di.pas` 采用 builder-specific helper，而不是继续扩 public runtime contract | builder 只需要一条 CLI clone fallback bridge，把 `IProcessRunner`/`IGitCliRunner` 适配留在专用 helper 内更小、更稳 |
| 业务单元的注释和边界测试也要与新架构一致 | 旧 concrete type 名称即使只出现在注释里，也会误导后续迁移并削弱文本边界测试的信号 |
| 对 `fpdev.utils.git` 中仍保留的兼容 helper，优先做“共享类型复用”而不是继续复制 enum/mapping | 这类收口不改行为，却能减少重复定义和后续漂移风险 |
| compat wrapper 可以保留，但 `fpdev.utils.git` 内部实现不应继续走这些 wrapper | 这样能把 wrapper 明确限制为外部兼容入口，避免内部逻辑再次绑定到兼容层 |
| 对 compat helper 的仓库内测试也要区分“shared-by-default”与“legacy compatibility” | 这样能避免测试自己继续充当隐性 compat 消费者，同时保留明确的回归覆盖 |
| env focused tests 也应遵循 shared-by-default / legacy-explicit 的同一原则 | 这样 `fpdev.utils.git` 剩余 env wrapper 的仓库内消费面会被清楚限定在显式 compat case 中 |
| 当 compat helper 的仓库内消费者已经稳定时，应把白名单固化成 boundary test | 这样后续任何新的隐性 compat 依赖都会第一时间暴露，而不是再靠手工盘点 |
| 继续用 focused Pascal 编译 + `/tmp` 输出目录做验证 | 仓库根 `lib/` 仍有权限噪音，不能让环境问题干扰结构改动判断 |
| 对 public compat surface 采用“分阶段收口”而不是立即删除 | 先把仓库默认入口与显式 legacy coverage 分开，可以在不破坏外部调用的前提下稳定边界 |
| 新增 dedicated legacy compat suite 是值得的 | 这次需要把 compat helper 从默认 focused tests 中迁走，否则 public compat 面无法被清晰治理 |
| `fpdev.git.runtime` 值得继续收成 contract-only 单元 | 这样能把 `TGitOperations` 的具体依赖进一步压回实现单元，同时不改任何 public interface |
| compat alias/常量也应和 helper wrappers 一样被 dedicated legacy suite 承接 | 否则 `fpdev.utils.git` interface 上剩余的 compatibility surface 仍有灰区，后续 deprecate/remove 没有稳定边界 |
| 先引入 `fpdev.git.operations` facade，再考虑更深的实现搬迁 | 这一步能先把默认入口从 compat unit 挪开，风险比直接移动 `TGitOperations` 大实现体更低 |
| `fpdev.utils.git` 暂保留兼容 wrapper | 先解除 flow 单元对巨石的纯读依赖，再考虑后续 API 面收缩 |
| `src/fpdev.fpc.builder.gitruntime.pas` 继续保持 builder-specific helper | 仓库内 Pascal caller 扫描显示它当前只有 `src/fpdev.fpc.builder.di.pas` 一个真实消费者，提前抽通用 adapter 收益不足 |
| `tests/test_git_operations.lpr` 应继续保留为 `fpdev.git.operations` focused contract suite | 它验证默认 facade 入口与 `TGitOperations` 行为，但并不再直连 compat layer，本轮不把它误归类为 legacy direct consumer |
| deprecated compat alias/helper 现在可以进入 next breaking window candidate removal 清单 | 全仓 Pascal caller 扫描显示这些 symbol 只剩 `tests/test_git_compat_legacy.lpr`，说明默认代码已经完全脱离 |
| A 组 compat alias/helper 直接在本轮 breaking removal 中删除 | 全仓 Pascal caller 已归零，继续保留只会增加 public surface 与 boundary 负担，没有仓库内收益 |
| dedicated legacy compat suite 在 breaking removal 后一起删除 | compat public surface 已不存在，再保留 suite 只会制造过期契约与编译目标 |
| `TGitOperations` 的具体实现应迁到 `fpdev.git.operations` 侧，而不是继续留在 `fpdev.utils.git` | helper removal 完成后，剩余的结构性耦合已经从 public surface 转成 implementation ownership；继续让 compat unit 承载实现会让默认入口与 legacy shim 的边界再次混淆 |

### Phase 22: Operations Implementation Relocation
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求新增 `src/fpdev.git.operations.impl.pas`
- [x] 在 boundary 中要求 `src/fpdev.git.operations.pas` 不再 alias `fpdev.utils.git`
- [x] 在 boundary 中要求 `src/fpdev.utils.git.pas` 退化为 legacy compatibility shim
- [x] 将 `TGitOperations` / `IGitCliRunner` 具体实现整体迁到 `src/fpdev.git.operations.impl.pas`
- [x] 将 `src/fpdev.git.operations.pas` 改为默认 facade over `src/fpdev.git.operations.impl.pas`
- [x] 将 `src/fpdev.utils.git.pas` 改为只保留 compat alias shim
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`
- [x] 运行 `tests.test_git_runtime_boundary`、`tests/test_git_operations.lpr`、`tests/test_fpc_builder.lpr`、`tests/test_git_facade.lpr`、`tests.test_style_regressions_batch19`
- **Status:** complete

### Phase 23: Compat Shim Soft Deprecation
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `fpdev.utils.git.TGitOperations` / `IGitCliRunner` 带 `deprecated` 标记
- [x] 调整 boundary，允许 compat shim 为剩余 alias 携带 `deprecated`，但默认 `fpdev.git.operations` 入口不得带该标记
- [x] 在 `src/fpdev.utils.git.pas` 为两个 alias 补 `deprecated 'Use fpdev.git.operations instead'`
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`，把 compat shim 的 soft-deprecated 状态写清楚
- [x] 运行 `tests.test_git_runtime_boundary`、`tests/test_git_operations.lpr`、`tests.test_style_regressions_batch19`
- [x] 用临时编译样例验证 `fpdev.utils.git` caller 会收到 deprecation warning
- [x] 将 deprecation warning 行为固化为自动 boundary test
- **Status:** complete

### Phase 24: Conservative Doc Cleanup For Compat Shim
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求历史 roadmap 不再把 `fpdev.utils.git` / `TGitOperations.Clone` 写成当前推荐入口
- [x] 更新 `docs/history/DEVELOPMENT_ROADMAP.md`
- [x] 更新 `docs/history/DEVELOPMENT_ROADMAP.en.md`
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `docs/history/B166-deprecated-cleanup.md` 标明 `fpdev.utils.git` 已被后续迁移 supersede
- [x] 更新 `docs/history/B166-deprecated-cleanup.md`
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `CLAUDE.md` 把 Git 新代码入口指向 `fpdev.git.operations` / `fpdev.git.operations.impl`
- [x] 更新 `CLAUDE.md`
- [x] 运行 `tests.test_git_runtime_boundary`
- **Status:** complete

### Phase 25: Conservative Doc Cleanup For Changelog And Audit
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `CHANGELOG.md` 把当前 Git 入口写成 `fpdev.git.operations` / `fpdev.git.operations.impl`
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `docs/history/DEPRECATED_CODE_AUDIT.md` 标明 `fpdev.utils.git` 已被后续迁移 supersede
- [x] 更新 `CHANGELOG.md`
- [x] 更新 `docs/history/DEPRECATED_CODE_AUDIT.md`
- [x] 运行 `tests.test_git_runtime_boundary`
- **Status:** complete

### Phase 26: Conservative Guide Cleanup For Git2 Usage Docs
- [x] 检查 `README.md` 是否仍有旧 Git 入口叙事（结论：无需改动）
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `docs/GIT2_USAGE.md` / `.en.md` 标明 `fpdev.git.operations` 是当前默认 system-git facade
- [x] 更新 `docs/GIT2_USAGE.md`
- [x] 更新 `docs/GIT2_USAGE.en.md`
- [x] 运行 `tests.test_git_runtime_boundary`
- [x] 尝试按 docs workflow 跑 prettier（记录当前仓库下 `yarn prettier` 对这两份文件的 pattern 解析失败）
- **Status:** complete

### Phase 27: Conservative Active Doc Cleanup For Architecture And Libgit2 Guides
- [x] 重新扫描活跃文档，确认 `INSTALLATION` / `QUICKSTART` / `README` 不需要补 Git 入口迁移说明
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `docs/ARCHITECTURE.md` / `.en.md` 标明 system-git 默认入口已切到 `fpdev.git.operations`
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `docs/LIBGIT2_INTEGRATION.md` / `.en.md` 说明这份文档只覆盖 libgit2 路径，并把 system-git facade 指回 `fpdev.git.operations` / `src/fpdev.git.operations.impl.pas`
- [x] 更新 `docs/ARCHITECTURE.md`
- [x] 更新 `docs/ARCHITECTURE.en.md`
- [x] 更新 `docs/LIBGIT2_INTEGRATION.md`
- [x] 更新 `docs/LIBGIT2_INTEGRATION.en.md`
- [x] 运行 `tests.test_git_runtime_boundary`
- [x] 再次尝试按 docs workflow 跑 prettier（结果仍是当前仓库下 `No files matching the pattern were found`）
- **Status:** complete

### Phase 28: Docs Formatter Entrypoint Recovery
- [x] 按 root-cause 方式复现 `yarn prettier` 与直接 `prettier` 二进制的行为差异
- [x] 确认问题来自 `yarn` 包装层，而不是 `prettier` 二进制本身或 Markdown 文件内容
- [x] 先写 RED 回归测试，要求新增一个不依赖上级 yarn workspace 的仓库内格式化脚本
- [x] 新增 `scripts/run_prettier.sh`
- [x] 让该脚本支持 `--check` / `--write` 和相对/绝对路径透传
- [x] 用该脚本实际格式化 `docs/ARCHITECTURE*` 与 `docs/LIBGIT2_INTEGRATION*`
- [x] 运行 `tests.test_run_prettier_sh`、`tests.test_git_runtime_boundary` 与 `bash -n scripts/run_prettier.sh`
- **Status:** complete

### Phase 29: Doc Tooling And Git Compat Closure
- [x] 写入正式实施计划 `docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md`
- [x] 在 `tests/test_contributor_docs_contract.py` 中补 RED，要求 `CLAUDE.md` 与 `docs/testing.md` 使用 `scripts/run_prettier.sh`
- [x] 在 `tests/test_contributor_docs_contract.py` 中补 RED，要求 contributor docs 以 `unittest` 作为 Python baseline，并把 focused Pascal `/tmp` 输出模式写清楚
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 `docs/GIT_COMPAT_MIGRATION.md` 定义 final removal gates 与 current text-reference buckets
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 active docs whitelist，限制 `fpdev.utils.git` 只出现在 migration / compat-scope guides
- [x] 更新 `CLAUDE.md`
- [x] 更新 `docs/testing.md`
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`
- [x] 用 `bash scripts/run_prettier.sh --write ...` 格式化本轮改动的 Markdown 文件
- [x] 运行 `tests.test_contributor_docs_contract`、`tests.test_git_runtime_boundary`、`tests.test_run_prettier_sh` 与 `bash -n scripts/run_prettier.sh`
- **Status:** complete

### Phase 30: Git Compat Breaking Removal Staging
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 migration doc 链接 breaking removal plan
- [x] 在 `tests/test_git_runtime_boundary.py` 中补 RED，要求 breaking removal plan 包含 release-note template、delete target 与组合验证入口
- [x] 写入 `docs/plans/2026-04-10-git-compat-breaking-removal.md`
- [x] 更新 `docs/GIT_COMPAT_MIGRATION.md`，把 final removal gates 指向 breaking removal plan
- [x] 运行 `tests.test_git_runtime_boundary`
- [x] 用 `bash scripts/run_prettier.sh --write ...` 格式化本轮新增计划文档
- [x] 串行运行 `bash scripts/run_prettier.sh --check ...`
- [x] 运行 `tests.test_run_prettier_sh`、`tests.test_contributor_docs_contract`、`tests.test_git_runtime_boundary`
- **Status:** complete

### Phase 31: FPC Metadataflow Extraction
- [x] 在 `tests/test_fpc_manager_installmetadata.lpr` 中补 RED，要求存在 `fpdev.fpc.metadataflow`
- [x] 新增 `src/fpdev.fpc.metadataflow.pas`，承接：
  - `ResolveFPCMetadataScopeCore`
  - `InferFPCStatusScopeCore`
  - `BuildFPCInstallMetadataCore`
  - `ApplyFPCVerificationMetadataCore`
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `ResolveMetadataScope`、`InferStatusScope`、`WriteInstallMetadata`、`UpdateVerificationMetadata` 委托到新 helper
- [x] 删除 `src/fpdev.fpc.validator.pas` 中重复的 `TVerificationResult`，统一改用 `src/fpdev.fpc.types.pas`
- [x] 修复 `tests/test_fpc_manager_installmetadata.lpr` 的 `DateUtils` / `fpdev.types` 缺失
- [x] 修复 `src/fpdev.cmd.fpc.verify.pas` 与 `tests/test_fpc_verify.lpr` 对旧 `fpdev.fpc.validator.TVerificationResult` 的残留引用
- [x] 在 `tests/test_temp_paths.pas` 新增 `ResolveTestAssetPath`，并让 `test_fpc_manager_installmetadata`、`test_fpc_verify`、`test_cli_fpc_diag` 用它定位 `tests/mock_fpc.pas`
- [x] 跑 focused Pascal 验证：
  - `tests/test_fpc_manager_installmetadata.lpr`
  - `tests/test_fpc_scoped_install.lpr`
  - `tests/test_fpc_verify.lpr`
  - `tests/test_cli_fpc_diag.lpr`
- [x] 跑 `bash scripts/run_all_tests.sh`
- [x] 更新 planning files
- **Status:** complete

### Phase 32: FPC Verify Flow Boundary And Mock Helper Consolidation
- [x] 写入 `docs/plans/2026-04-11-fpc-verify-flow-wave.md`
- [x] 新增 `tests/test_fpc_verify_boundary.py`，先让 validator/runtime boundary 与共享 mock helper 契约进入 RED
- [x] 新增 `tests/test_fpc_mock_helpers.pas`
- [x] 让 `tests/test_fpc_verify.lpr`、`tests/test_fpc_manager_installmetadata.lpr`、`tests/test_cli_fpc_diag.lpr` 改用共享 mock helper
- [x] 让 `src/fpdev.fpc.validator.pas` 继续负责路径/配置解析，但将可执行文件验证委托给 `fpdev.fpc.verify.TFPCVerifier`
- [x] 删除 validator 本地 `RunSmokeTest` 与直接 `fpc -iV` 调用
- [x] 跑 `python3 -m unittest tests.test_fpc_verify_boundary -v`
- [x] 跑 focused Pascal 验证：
  - `tests/test_fpc_manager_installmetadata.lpr`
  - `tests/test_fpc_verify.lpr`
  - `tests/test_fpc_validator_runtimeflow.lpr`
  - `tests/test_cli_fpc_diag.lpr`
- [x] 跑 `bash scripts/run_all_tests.sh`
- [x] 更新 planning files
- **Status:** complete

### Phase 33: FPC Manager Verify Orchestration Wave
- [x] 写入 `docs/plans/2026-04-11-fpc-manager-verify-orchestration-wave.md`
- [x] 新增 `tests/test_fpc_manager_verify_boundary.py`，先让 manager-level verify orchestration 契约进入 RED
- [x] 新增 `src/fpdev.fpc.verifyflow.pas`
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `VerifyInstalledExecutableVersion`、`RefreshInstallVerificationMetadata`、`VerifyInstallation` 委托到共享 verify flow
- [x] 跑 `python3 -m unittest tests.test_fpc_manager_verify_boundary tests.test_fpc_verify_boundary -v`
- [x] 跑 focused Pascal 验证：
  - `tests/test_fpc_manager_installmetadata.lpr`
  - `tests/test_fpc_verify.lpr`
  - `tests/test_fpc_validator_runtimeflow.lpr`
  - `tests/test_cli_fpc_diag.lpr`
- [x] 跑 `bash scripts/run_all_tests.sh`
- [x] 更新 planning files
- **Status:** complete

### Phase 34: FPC Binary Verify Consolidation Wave
- [x] 写入 `docs/plans/2026-04-11-fpc-binary-verify-consolidation-wave.md`
- [x] 新增 `tests/test_fpc_binary_verify_boundary.py`，锁定 binary install verify 必须复用共享 verifyflow 且 legacy verifier 已移除
- [x] 扩展 `src/fpdev.fpc.verifyflow.pas`，新增 binary install 可复用的 verification core 与 metadata writer helper
- [x] 让 `src/fpdev.fpc.binary.pas` 的安装后验证改为委托 shared verifyflow，并补 `fpdev.fpc.types` 显式依赖修复 `TVerificationResult` 编译错误
- [x] 删除 `src/fpdev.fpc.verifier.pas`
- [x] 更新 `tests/test_style_regressions_batch16.py`，改为断言 legacy verifier 已移除
- [x] 跑 `python3 -m unittest tests.test_fpc_binary_verify_boundary tests.test_style_regressions_batch16 -v`
- [x] 跑 focused Pascal 验证：
  - `tests/test_binary_installer_unit.lpr`
  - `tests/test_fpc_install_integration.lpr`
  - `tests/test_fpc_verifier.lpr`
- [x] 跑 `bash scripts/run_all_tests.sh`
- [x] 更新 planning files
- **Status:** complete

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| planning-with-files skill 示例中的 `${CLAUDE_PLUGIN_ROOT}` 在当前会话未展开，导致模板与 catchup 脚本路径解析失败 | 1 | 改用 `/home/dtamade/.codex/skills/planning-with-files/...` 绝对路径继续执行 |
| `fpc -Fusrc -Fisrc -FE/tmp/...` 在目标目录不存在时直接失败 | 1 | 先 `mkdir -p` 再运行 focused Pascal build，记录为环境细节而非代码问题 |
| `fpdev.git.runtime.pas(77,29) Error: Identifier not found "gbNone"` | 1 | 确认 enum 已拆到 `fpdev.git.types` 后，给 `fpdev.git.runtime.pas` 补显式 import 并补 boundary test 防回归 |
| `tests/test_git_operations.lpr` 编译时报 `Identifier not found "gbLibgit2"` 等 enum 标识符 | 1 | 确认是 backend type 抽取后的隐式依赖残留，给 focused 测试补显式 `fpdev.git.types` import |
| `tests/fpdev.git2.adapter/test_git.lpr` 初次编译失败：`Can't find unit test_pause_control` | 1 | 这是编译命令缺少测试单元搜索路径，补 `-Futests` 后通过 |
| `tests.test_git_runtime_boundary` 仍报 `fpdev.utils.git` 残留 | 1 | 根因不是实现依赖，而是 `src/fpdev.fpc.builder.di.pas` 一条注释还包含该字面量；改写注释后恢复全绿 |
| `tests.test_git_runtime_boundary` 新增 `TGitOperations` narrative 边界后失败 | 1 | 根因是 `src/fpdev.resource.repo.pas`、`src/fpdev.fpc.builder.pas`、`src/fpdev.lazarus.source.pas` 仍有旧注释；清理描述后恢复全绿 |
| `tests.test_git_runtime_boundary` 新增共享 pull failure type 边界后失败 | 1 | 根因是 `src/fpdev.utils.git.pas` 仍本地重复定义 `TGitPullFailureKind`；切到共享 alias 并重导出常量后恢复全绿 |
| `tests.test_git_runtime_boundary` 新增“内部直连共享 helper”边界后失败 | 1 | 根因是 `src/fpdev.utils.git.pas` 内部逻辑仍调用 compat wrapper；改为直连 `fpdev.git.env` / `fpdev.git.errors` 后恢复全绿 |
| `tests.test_git_runtime_boundary` 新增 shared-by-default 测试意图边界后失败 | 1 | 根因是 `tests/test_git_operations.lpr` 还没有显式区分 shared helper 与 compat wrapper 的用途；改成 shared-by-default + legacy case 后恢复全绿 |
| `tests.test_git_runtime_boundary` 新增 env shared-by-default 边界后失败 | 1 | 根因是 `tests/test_git_env_credentials.lpr` 与 `tests/test_git_env_identity.lpr` 还没有显式区分 shared helper 与 compat wrapper 的用途；改成 shared-by-default + legacy case 后恢复全绿 |
| `tests/test_git_operations.lpr` 在 `/tmp` 产物目录下运行时自检失败 | 1 | 失败点不是 Git 行为，而是测试默认把可执行目录推断成项目根；运行时显式传入 `FPDEV_TEST_PROJECT_ROOT=/home/dtamade/projects/fpdev` 后恢复全绿 |
| runtime impl split 的 RED 边界立即失败 | 1 | 根因是 `src/fpdev.git.runtime.impl.pas` 尚不存在，且 `src/fpdev.git.runtime.pas` 仍直接承载 `TGitRuntime` / `TGitOperations`；新增 impl unit 并把 factory 改成 forwarding 后恢复全绿 |
| compat alias/常量边界的 RED 失败 | 1 | 根因是 `tests/test_git_compat_legacy.lpr` 尚未显式覆盖 `fpdev.utils.git.TGitBackend` / `TGitPullFailureKind` / `gpfk*`，且迁移文档也未写明；补 dedicated legacy coverage 与文档后恢复全绿 |
| default operations entrypoint 的 RED 失败 | 1 | 根因是 `src/fpdev.git.operations.pas` 尚不存在，且 `src/fpdev.git.runtime.impl.pas` / `src/fpdev.fpc.builder.gitruntime.pas` / `tests/test_git_operations.lpr` 仍直连 `fpdev.utils.git`；新增 facade unit 并切默认消费者后恢复全绿 |
| `yarn prettier --write docs/...` / `./docs/...` 仍报 `No files matching the pattern were found` | 2 | 记录为当前仓库文档格式化入口问题；本轮以 focused boundary test 通过作为内容验收，不继续扩面排查 formatter |
| `tests/test_run_prettier_sh.py` 初版把 `PATH` 清空后连 `bash` 也一起隐藏了 | 1 | 改成在测试侧固定使用已解析的 `bash` 可执行路径，只让脚本内部去感知 `prettier`/`node` 缺失 |
| `tests/test_contributor_docs_contract` 新增 contributor-doc 断言后失败 | 1 | 根因是 `CLAUDE.md` 仍引用 `pytest`，`docs/testing.md` 也还没写 repo-local prettier wrapper 与 `/tmp` focused Pascal 模式；更新两份文档后恢复全绿 |
| `tests/test_git_runtime_boundary` 新增 migration gate 断言后失败 | 1 | 根因是 `docs/GIT_COMPAT_MIGRATION.md` 还没有 final removal gates 与 text-reference buckets；补 policy section 后恢复全绿 |
| 并行执行 `bash scripts/run_prettier.sh --write ...` 与 `--check ...` 导致格式化证据无效 | 1 | 改为串行先 `--write` 再 `--check`，以顺序验证作为最终验收证据 |
| `tests.test_git_runtime_boundary` 新增 breaking removal plan 断言后失败 | 1 | 根因是计划文档尚不存在，且 migration doc 还没有计划入口；新增 `docs/plans/2026-04-10-git-compat-breaking-removal.md` 并补链接后恢复全绿 |
| `tests/test_fpc_manager_installmetadata.lpr` 编译失败：`EncodeDateTime` / `isProject` / `isUser` 未解析 | 1 | 给测试补 `DateUtils` 与 `fpdev.types` 直接依赖，保持 RED 测试意图不变 |
| `/tmp` 下运行 `test_fpc_manager_installmetadata` / `test_fpc_verify` 时找不到 `tests/mock_fpc.pas` | 1 | 在 `tests/test_temp_paths.pas` 新增 `ResolveTestAssetPath`，统一从工作目录与可执行路径向上定位测试资产 |

| `python3 -m unittest tests.test_fpc_verify_boundary -v` 初次失败 2 项 | 1 | 符合预期 RED：当时 `test_fpc_mock_helpers` 尚未接入，且 `src/fpdev.fpc.validator.pas` 仍保留本地 runtime verification 逻辑 |
| `tests/test_binary_installer_unit.lpr` 编译失败：`Identifier not found "TVerificationResult"` | 1 | `src/fpdev.fpc.binary.pas` 在切到 shared verifyflow 后遗漏 `fpdev.fpc.types` import；补显式依赖后 focused 与全量回归恢复全绿 |
| 本轮 `apply_patch` 工具持续返回 `ENOENT` | 1 | 改用受控 shell 写文件与小范围脚本替换继续推进，完成后再用编译/测试结果兜底验证 |

## Notes
- `src/fpdev.fpc.verifyflow.pas` 现在同时承接 manager / binary 两类共享 verify orchestration：
  - `VerifyInstalledExecutableVersionCore`
  - `RefreshInstalledFPCVerificationCore`
  - `PersistManagedFPCVerificationResultCore`
  - `RunInstalledFPCVerificationCore`
  - `WriteBinaryInstallVerificationMetadataCore`
- `src/fpdev.fpc.manager.pas` 现在只保留 facade dispatch 与 metadata writer，不再直接 new `fpdev.fpc.verify.TFPCVerifier`。
- 新增 `tests/test_fpc_manager_verify_boundary.py`，锁定 manager 必须复用 `fpdev.fpc.verifyflow`。
- `src/fpdev.fpc.binary.pas` 现在不再持有 `TFPCVerifier` 状态，安装后验证与 metadata 回写都委托到 `fpdev.fpc.verifyflow`。
- `src/fpdev.fpc.verifier.pas` 已删除；`tests/test_fpc_binary_verify_boundary.py` 与 `tests/test_style_regressions_batch16.py` 共同锁定该 duplicate unit 不得回归。
- 新增 `tests/test_fpc_verify_boundary.py`，约束 validator 必须复用 `fpdev.fpc.verify`，并约束 verify 相关 Pascal 测试必须共享 `test_fpc_mock_helpers`。
- 新增 `tests/test_fpc_mock_helpers.pas`，统一编译 `tests/mock_fpc.pas` 到目标安装目录。
- `src/fpdev.fpc.validator.pas` 现在把可执行文件版本检查与 hello-world smoke test 委托给 `src/fpdev.fpc.verify.pas`。
- 本轮目标是结构收口，不是用户可见功能扩展。
- 现阶段不重开 release / close-out 线；那条线在当前代码树与公开状态中已经关闭。
- 当前实现新增 `src/fpdev.git.errors.pas`，并让 `fpdev.fpc.runtimeflow` / `fpdev.lazarus.commandflow` 直接依赖它。
- 当前 helper 已同时承载：
  - `TGitPullFailureKind`
  - `ClassifyGitPullFailure`
  - `NormalizeGitPullErrorDetail`
- 当前实现还新增 `src/fpdev.git.types.pas`，承载：
  - `TGitBackend`
  - `GitBackendToString`
- `fpdev.utils.git` 仍对外保留 `ClassifyGitPullFailure`，但内部已转发到新 helper。
- `fpdev.utils.git` 仍对外保留 `TGitBackend` / `GitBackendToString` 兼容入口，但内部已委托到 `fpdev.git.types`。
- `src/fpdev.git.env.pas` 已新增，并承载：
  - `ResolveGitCredentialEnv`
  - `ResolveGitIdentityEnv`
- `fpdev.utils.git` 仍对外保留同名 env helper，但内部已转发到 `fpdev.git.env`。
- `fpdev.fpc.runtimeflow` 与 `fpdev.lazarus.commandflow` 已不再保留本地 `NormalizeGitPullErrorDetail` 副本。
- 新增 `src/fpdev.fpc.metadataflow.pas`，承接 FPC install / verify metadata 的 scope 推导与 record 组装逻辑。
- `src/fpdev.fpc.validator.pas` 现在只使用 `src/fpdev.fpc.types.pas.TVerificationResult`，不再维护重复 record。
- `tests/test_temp_paths.pas` 现在额外承载 `ResolveTestAssetPath`，用于稳定 `/tmp` focused Pascal 运行时的测试资产定位。
- `fpdev.git.runtime` 现在已显式依赖 `fpdev.git.types`，不再隐式假设 enum 标识符会从 `fpdev.utils.git` 泄漏进来。
- 业务模块现在统一改走 `NewGitRuntime(...)`，不再直接 `TGitRuntime.Create`。
- `fpdev.git.runtime` 的 interface 现在也不再 `uses fpdev.utils.git`；`TGitRuntime` 实现类已经缩回 `implementation`。
- `fpdev.git.runtime` 文件现在也不再提及 `IGitCliRunner`；runtime construction 只剩 `ACliOnly` 这个业务开关。
- `tests/test_git_env_credentials.lpr` 与 `tests/test_git_env_identity.lpr` 现在直接依赖 `fpdev.git.env`。
- `tests/test_git_operations.lpr` 现在也显式引入 `fpdev.git.types`，不再隐式依赖 `fpdev.utils.git` 泄漏 enum 标识符。
- `src/fpdev.git.runtime.pas` 现在额外承载 compat facade 所需的 pass-through：
  - `PullWithMerge`
  - `GetRemoteURL`
  - `GetCurrentBranch`
  - `ListBranches`
  - `Add`
  - `Commit`
  - `Push`
  - `GetVersion`
- `src/fpdev.git.pas` 现在已改为依赖 `fpdev.git.runtime`，不再直持有 `TGitOperations`。
- `src/fpdev.fpc.builder.gitruntime.pas` 现在承接 builder 专用 CLI clone fallback bridge。
- `src/fpdev.fpc.builder.di.pas` 现在通过 builder-specific helper 走 CLI fallback，不再直提 `fpdev.utils.git` / `IGitCliRunner` / `TGitOperations.Create`。
- `src/fpdev.resource.repo.pas`、`src/fpdev.fpc.builder.pas`、`src/fpdev.lazarus.source.pas` 现在也不再用注释把业务单元描述成 `TGitOperations` 直连面。
- `src/fpdev.utils.git.pas` 现在复用 `fpdev.git.errors.TGitPullFailureKind`，不再维护一份本地重复 enum。
- `src/fpdev.utils.git.pas` 的内部逻辑现在也直接调用 `fpdev.git.env` / `fpdev.git.errors`，compat wrapper 仅保留给外部入口。
- `tests/test_git_operations.lpr` 现在只保留 shared helper 默认覆盖，不再 inline 保留 compat wrapper case。
- `tests/test_git_env_credentials.lpr` 与 `tests/test_git_env_identity.lpr` 现在也只保留 shared env helper 默认覆盖。
- 新增 `tests/test_git_compat_legacy.lpr`，集中承载 public compat helper 的 legacy compatibility coverage。
- `src/fpdev.utils.git.pas` interface 现在明确把 helper wrappers 标成 legacy compatibility surface。
- 新增 `docs/GIT_COMPAT_MIGRATION.md`，把 shared helper 的默认入口与 compat 层定位写清楚。
- repo 内对 `fpdev.utils.git` compat helper 的显式消费面现在已经被 boundary test 收紧到 dedicated legacy suite。
- `src/fpdev.git.runtime.pas` 现在已经缩成 contract-only 单元，不再直接承载 `TGitRuntime` / `TGitOperations` 实现。
- 新增 `src/fpdev.git.runtime.impl.pas`，承接 runtime concrete implementation 与 `fpdev.utils.git` 的依赖。
- `tests/test_git_compat_legacy.lpr` 现在也显式覆盖 `fpdev.utils.git.TGitBackend`、`TGitPullFailureKind` 与 `gpfk*` 常量的 compatibility contract。
- `docs/GIT_COMPAT_MIGRATION.md` 现在已把 alias/常量 compat 面和对应 shared helper 的替代入口写清楚。
- 新增 `src/fpdev.git.operations.pas`，作为 `TGitOperations` / `IGitCliRunner` 的默认 facade 入口。
- `src/fpdev.git.runtime.impl.pas`、`src/fpdev.fpc.builder.gitruntime.pas` 与 `tests/test_git_operations.lpr` 现在默认依赖 `fpdev.git.operations`，不再直连 `fpdev.utils.git`。
- `docs/ARCHITECTURE.md` / `.en.md` 现在也显式说明：
  - system-git 新代码默认从 `src/fpdev.git.operations.pas` 进入
  - `src/fpdev.git.operations.impl.pas` 承载具体实现
  - `src/fpdev.utils.git.pas` 只剩 soft-deprecated compatibility shim 角色
- `docs/LIBGIT2_INTEGRATION.md` / `.en.md` 现在明确把 scope 限定在 libgit2 路径，并把 system-git facade 指回 `fpdev.git.operations`
- 新增 `scripts/run_prettier.sh`，作为仓库内稳定的 Prettier 入口：
  - 不再依赖 `yarn prettier`
  - 优先使用 `PATH` 上的 `prettier`
  - 否则回退到 `${HOME}/node_modules/.bin/prettier`
  - 再不行时尝试用 `node require.resolve(...)` 定位 `prettier`
- 新增正式实施计划 `docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md`，把本轮 8 项收口工作拆成可执行任务。
- `CLAUDE.md` 现在把 Python baseline 写成 `python3 -m unittest discover -s tests -p 'test_*.py'`，并补了 repo-local doc formatting 与 `/tmp` focused Pascal compile 示例。
- `docs/testing.md` 现在新增：
  - 高频本地命令索引
  - `scripts/run_prettier.sh` 入口
  - `/tmp/fpdev-test-bin` / `/tmp/fpdev-test-lib` focused Pascal 编译模式
  - `FPDEV_TEST_PROJECT_ROOT=` 的运行时提示
- `docs/GIT_COMPAT_MIGRATION.md` 现在新增：
  - final removal gates
  - current text-reference buckets
  - active docs 对 `fpdev.utils.git` 的引用边界说明
- 新增 `docs/plans/2026-04-10-git-compat-breaking-removal.md`，把最终 breaking remove 的删除目标、release-note template 和组合验证入口写成可执行计划。
- `docs/GIT_COMPAT_MIGRATION.md` 现在把 staged execution checklist 指向 breaking removal plan，而不只是停留在原则层。


### Phase 34: FPC Install Offline Cache Orchestration Downshift
- [x] 新增 `tests/test_fpc_install_cli_boundary.py`，先把 CLI 不得继续持有 cache-restore orchestration 的边界锁成 RED
- [x] 修复 `src/fpdev.fpc.installversionflow.pas` 的 overload 中间态，并给 source install flow 补齐 offline cache-miss / restore-fail 契约
- [x] 在 `src/fpdev.fpc.installer.pas` 为 `TFPCBinaryInstaller` 新增 offline mode 状态，并把 binary cache-restore / offline miss / restore-fail 逻辑下沉到 installer 内部
- [x] 让 `src/fpdev.fpc.manager.pas` 的 `InstallVersion(...)` 透传 `AOfflineMode`，并保持 install 成功后的 verify metadata 回补仍由 manager 统一处理
- [x] 收缩 `src/fpdev.cmd.fpc.install.pas` 到参数解析、mode fallback、network guard 与 exit-code 映射；删除命令层手写 cache restore / setup / verify
- [x] 扩充 `tests/test_fpc_install_cli.lpr`：覆盖 offline cache-hit + custom prefix、offline cache-hit 后 verify warning 仍成功
- [x] 扩充 `tests/test_fpc_mock_helpers.pas`：新增 `CompileVersionMismatchMockFPCBinary(...)` 以构造 verify-warning cache-hit 场景
- [x] 跑 focused 验证与 `bash scripts/run_all_tests.sh`

## Notes
- `src/fpdev.cmd.fpc.install.pas` 现在不再直接 new `TBuildCache`，也不再直接出现 `RestoreArtifacts(...)`、`SetupEnvironment(...)`、`VerifyInstallation(...)`。
- `src/fpdev.fpc.installversionflow.pas` 现在保留两组 `ExecuteFPCInstallVersionCore(...)`：
  - 旧签名 wrapper：兼容现有 call sites
  - 新签名：显式透传 `AOfflineMode`
- `src/fpdev.fpc.installer.pas` 现在承担 binary install 的 cache-hit / restore-fail / offline miss 用户输出与行为分支。
- `src/fpdev.fpc.manager.pas` 为保持既有 CLI 契约，offline 模式下会先走 cache-only 安装流，再决定结果，不会在进入流之前因为版本校验直接短路。
- 新增 CLI 行为契约后，offline cache-hit 现在明确覆盖：
  - 默认 install root 恢复
  - `--prefix` 恢复
  - verify warning 仅告警、不改变成功退出码


### Phase 35: FPC Install Output And Boundary Wave
- [x] 新增正式计划 `docs/plans/2026-04-11-fpc-install-output-and-boundary-wave.md`，把 output unify / boundary / docs / verification 拆成执行任务
- [x] 新增 `tests/test_fpc_install_manager_boundary.py` 与 `tests/test_fpc_installer_boundary.py`，锁定 manager / installer 不得吸回 CLI fallback 与 exit-code 逻辑
- [x] 扩充 `tests/test_fpc_install_cli.lpr`：补 `--offline --no-cache`、`--from=binary --offline`、`--from=source --offline` 与 cache-hit activation hint 契约
- [x] 扩充 `tests/test_fpc_installversionflow.lpr`：补 source/binary install success banner 与 activation next-step 契约
- [x] 调整 `tests/test_fpc_installer_postinstall.lpr`：锁定 completion summary 已上移到 installversionflow，postinstall 只保留 layout / env / cache 职责
- [x] 新增 `src/fpdev.fpc.installreportflow.pas`，统一 offline cache miss、offline restore fail 与 install success banner 输出
- [x] 收口 `src/fpdev.fpc.installversionflow.pas` 与 `src/fpdev.fpc.installer.pas` 的重复文案，并从 `src/fpdev.fpc.installer.postinstall.pas` 删除重复 completion summary
- [x] 同步 `CHANGELOG.md`、`docs/FPC_MANAGEMENT.md`、`docs/FPC_MANAGEMENT.en.md`
- [x] 跑 focused、Python bundle 与全量 `bash scripts/run_all_tests.sh`

## Notes
- `src/fpdev.fpc.installversionflow.pas` 现在拥有 install success banner 的唯一输出职责；binary/source/cache-hit 都走同一 activation next-step 文案。
- `src/fpdev.fpc.installer.postinstall.pas` 现在只负责 managed layout repair、environment setup 与 cache save，不再自己打印 completion summary。
- `src/fpdev.fpc.installreportflow.pas` 现在集中承载：
  - `WriteFPCOfflineCacheMissReport`
  - `WriteFPCOfflineCacheRestoreFailureReport`
  - `WriteFPCInstallSuccessReport`
- 新增的 Python boundary tests 把 manager / installer 的职责边界再锁了一层，避免 CLI fallback / exit-code 决策回流。
- install CLI 契约现在额外覆盖：
  - `--offline --no-cache`
  - `--from=binary --offline`
  - `--from=source --offline`
  - cache-hit success output 的 activation hint


### Phase 36: Install Contract Docs And Lazarus Wave
- [x] 新增正式计划 `docs/plans/2026-04-11-install-contract-docs-and-lazarus-wave.md`
- [x] 扩充 `tests/test_fpc_installer_binaryflow.lpr`：补 manifest/repo exception 仍继续 fallback 与最终失败总结契约
- [x] 新增 `tests/test_lazarus_install_boundary.py`，锁定 Lazarus manager 只做 plan wiring，不得重新吸回 install flow 用户文案
- [x] 扩充 `tests/test_lazarus_flow.lpr`：补 install success completion banner 与 `fpdev lazarus use <version>` activation hint
- [x] 收口 `src/fpdev.fpc.installer.binaryflow.pas`：manifest/repo 异常按阶段容错继续 fallback，并在整条链路耗尽时输出统一失败总结
- [x] 收口 `src/fpdev.lazarus.commandflow.pas`：统一承接 install success banner / activation next-step 输出
- [x] 同步 `README.md`、`FAQ.md`、`docs/FAQ.md`、`docs/FAQ.en.md`、`QUICKSTART.md`、`docs/QUICKSTART.md`、`docs/QUICKSTART.en.md`、`docs/MANIFEST-USAGE.md`
- [x] 扩充 `tests/test_contributor_docs_contract.py`，锁定 binary-first / offline / no-cache / explicit source 文档契约
- [x] 跑 focused Python / Pascal suites 与全量 `bash scripts/run_all_tests.sh`

## Notes
- `src/fpdev.fpc.installer.binaryflow.pas` 现在不会因为 manifest 或 fpdev-repo 某一跳抛异常就直接终止整条 binary acquisition 链；只有 SourceForge terminal path 仍保留 generic exception fail contract。
- `src/fpdev.lazarus.commandflow.pas` 现在拥有 Lazarus install flow 的用户级输出职责：source fallback warning、manual configure hint、success banner、activation command。
- `src/fpdev.lazarus.manager.pas` 继续保持为 install plan assembly / callback wiring / exception wrapper，不重新持有 `fallback to source build` 或 `fpdev lazarus use/configure` 文案。
- 用户文档现在统一表达：
  - FPC 默认是 binary-first
  - `--offline` 是 cache-only 路径
  - `--no-cache` 是强制重新拉取二进制
  - `--from-source` 是显式源码模式
  - Lazarus 当前默认 install 路径会提示 binary path unavailable，并回退到源码构建


### Phase 37: Lazarus Manager Metadataflow Slice
- [x] 新增正式计划 `docs/plans/2026-04-11-lazarus-manager-metadataflow-wave.md`
- [x] 新增 `tests/test_lazarus_manager_metadata_boundary.py`，锁定 `src/fpdev.lazarus.manager.pas` 对 metadataflow helper 的委托边界
- [x] 新增 `tests/test_lazarus_manager_metadataflow.lpr`，为 version info 归一化 / merge helper 写 direct RED 覆盖
- [x] 新增 `src/fpdev.lazarus.types.pas`，承接 `TLazarusVersionInfo` / `TLazarusVersionArray`
- [x] 新增 `src/fpdev.lazarus.metadataflow.pas`，承接 configured FPC version normalize、configured metadata overlay、installed version merge/filter
- [x] 让 `src/fpdev.lazarus.manager.pas` 改为委托 metadataflow，并更新 `src/fpdev.cmd.lazarus.pas` 的类型别名来源
- [x] 同步 `docs/history/B171-large-files-report.md` 与 `tests/test_contributor_docs_contract.py` 的 Lazarus hotspot/current line-count truth
- [x] 跑 focused Python / Pascal suites 与全量 `bash scripts/run_all_tests.sh`

## Notes
- 当前 CLI/root shell 已不是 Lazarus 调度问题中心：
  - `src/fpdev.cmd.lazarus.root.pas` 已只负责 singleton root shell 注册
  - `src/fpdev.cmd.lazarus.pas` 已收缩为 compatibility shim
  - `src/fpdev.command.imports.lazarus.pas` 也只聚合 root + action units
- 本轮已经把 `src/fpdev.lazarus.manager.pas` 中的 metadata/version inventory 责任下沉到：
  - `src/fpdev.lazarus.types.pas`
  - `src/fpdev.lazarus.metadataflow.pas`
- 现有行为契约已由 `tests/test_lazarus_configure_workflow.lpr` 锁住：
  - registry 缺失但已安装版本仍应出现在 `ListVersions`
  - configured FPC version / custom install path 需要覆盖 registry 默认值
- manager 当前已从 `1177` 行降到 `1060` 行，且 `tests/test_lazarus_configure_workflow.lpr`、`tests/test_lazarus_update.lpr`、`tests/test_cli_lazarus.lpr`、`tests/test_lazarus_management.lpr` 与全量 `bash scripts/run_all_tests.sh` 全部通过


### Phase 38: Lazarus Manager Follow-up Waves
- [x] 新增正式计划 `docs/plans/2026-04-11-lazarus-manager-followup-waves.md`
- [x] 更新 `task_plan.md` / `findings.md` / `progress.md`，把 active goal 切到 Lazarus manager follow-up waves
- [x] 新增 `tests/test_lazarus_manager_path_boundary.py` 与 `tests/test_lazarus_pathflow.lpr`，完成 pathflow RED/GREEN
- [x] 新增 `src/fpdev.lazarus.pathflow.pas`，承接 install path / executable path / resolved path / install-state helper
- [x] 新增 `tests/test_lazarus_manager_callbacks_boundary.py` 与 `tests/test_lazarus_installcallbacks.lpr`，完成 install callbacks RED/GREEN
- [x] 新增 `src/fpdev.lazarus.installcallbacks.pas`，承接 `DownloadSource` / `BuildFromSource` / `SetupEnvironment`
- [x] 新增 `tests/test_lazarus_manager_runtime_boundary.py` 与 `tests/test_lazarus_runtimeactions.lpr`，完成 runtime/IDE actions RED/GREEN
- [x] 新增 `src/fpdev.lazarus.runtimeactions.pas`，承接 `TestInstallation` / `LaunchIDE` / `ConfigureIDE`
- [x] 同步 `docs/history/B171-large-files-report.md` 与 `tests/test_contributor_docs_contract.py`
- [x] 跑 focused Python / Pascal suites、docs contract、Prettier check 与全量 `bash scripts/run_all_tests.sh`

## Notes
- 本轮不回头处理 CLI/root shell；它们已不是 Lazarus 调度问题中心。
- 本轮切片顺序固定为：
  - pathflow
  - install callbacks
  - runtime/IDE actions
  - docs/contracts
- `src/fpdev.lazarus.commandflow.pas` 继续保留 install/update/launch/configure plan core 与用户输出职责。
- `src/fpdev.lazarus.manager.pas` 目标是继续收缩到 config/registry access、callback wiring、异常包装与 facade dispatch。
- Focused Pascal 编译继续使用独立 `/tmp` 输出目录，避免仓库内编译产物互踩。
- `src/fpdev.lazarus.manager.pas` 本轮已从 `1060` 行进一步降到 `841` 行。
- 新 helper 落点已稳定为：
  - `src/fpdev.lazarus.pathflow.pas`
  - `src/fpdev.lazarus.installcallbacks.pas`
  - `src/fpdev.lazarus.runtimeactions.pas`
- 关键回归结果：
  - `python3 -m unittest tests.test_lazarus_manager_path_boundary tests.test_lazarus_manager_callbacks_boundary tests.test_lazarus_manager_runtime_boundary tests.test_lazarus_install_boundary tests.test_lazarus_callback_contract tests.test_contributor_docs_contract -v` 通过
  - `bash scripts/run_prettier.sh --check docs/history/B171-large-files-report.md` 通过
  - `bash scripts/run_all_tests.sh` 通过，结果为 `279/279`


### Phase 95: FPC Sourceflow Residual Wave
- [x] 新增正式计划 `docs/plans/2026-04-16-fpc-sourceflow-residual-wave.md`
- [x] 扩充 `tests/test_fpc_source_boundary.py`，锁定 `src/fpdev.fpc.source.pas` 对 `fpdev.fpc.sourceflow` 的委托边界
- [x] 新增 `tests/test_fpc_sourceflow.lpr`，为 clone/update/switch/list/prereq helper 写 direct RED/GREEN 覆盖
- [x] 新增 `src/fpdev.fpc.sourceflow.pas`，承接 `CloneFPCSource(...)` / `UpdateFPCSource(...)` / `SwitchFPCVersion(...)` / `ListAvailableVersions(...)` / `ListLocalVersions(...)` / `CheckBuildPrerequisites(...)` 的 residual glue
- [x] 让 `src/fpdev.fpc.source.pas` 改为 thin delegate，并补上 registry version-name wrapper 以保持 boundary clean
- [x] 跑 focused Python / Pascal suites、`bash scripts/run_all_tests.sh` 与 `lazbuild -B fpdev.lpi`

## Notes
- 本轮不重开已经完成的 `sourceinstallflow` / `sourcebootstrapflow` / `sourcebuildflow`；目标只锁定 `src/fpdev.fpc.source.pas` 里剩余的 lifecycle/query/prereq glue。
- `src/fpdev.fpc.sourceflow.pas` 当前稳定承接：
  - clone 的默认版本归一化与 current version 更新
  - update 的 empty-arg fallback 与 success/fail status
  - switch 的 installed gate 与 current version 更新
  - available version merge / static fallback
  - local version scan / validator filter
  - build prereq 的 `make --version` + bootstrap compiler gate
- `src/fpdev.fpc.source.pas` 继续保留：
  - `FSourceRoot` / `FCurrentVersion` / `FBootstrapCompiler`
  - `Repo`
  - `ExecuteCommand(...)`
  - `IsValidSourceDirectory(...)`
- 关键回归结果：
  - `python3 -m unittest tests.test_fpc_source_boundary -v` 通过，`5/5`
  - `tests/test_fpc_sourceflow.lpr` 通过，`27` 个 direct checks 全绿
  - `tests/test_fpc_sourceinstallflow.lpr` / `tests/test_fpc_sourcebootstrapflow.lpr` / `tests/test_fpc_sourcebuildflow.lpr` 全部通过
  - `tests/test_fpc_source_repo.lpr` 通过，`159/159`
  - `bash scripts/run_all_tests.sh` 通过，`330/330`
  - `lazbuild -B fpdev.lpi` 通过


### Phase 96: Fresh Hotspot Recheck Checkpoint
- [x] 新增正式计划 `docs/plans/2026-04-16-fresh-hotspot-recheck-checkpoint.md`
- [x] 重新扫描当前大体量 facade/service 文件，确认 `build.manager`、`fpc.builder`、`fpc.manager`、`fpc.source`、`resource.repo`、`package.manager`、`lazarus.manager` 的真实现状
- [x] 运行轻量 boundary bundle，验证先前高 ROI facade 面现在仍然保持 thin delegate 形态
- [x] 同步 `task_plan.md` / `findings.md` / `progress.md`，明确记录“当前暂不继续开新 helper wave”的 checkpoint 结论

## Notes
- 这轮不是再开一波新 helper，而是对“是否还值得继续拆”做 fresh re-rank，避免沿用已经过期的排序。
- 当前大体量 facade/service 文件里，已明确保持 helper 化边界的包括：
  - `src/fpdev.build.manager.pas` → `managerflow` + `runtimeflow`
  - `src/fpdev.fpc.builder.pas` → `builderflow`
  - `src/fpdev.fpc.source.pas` → `sourceinstallflow` + `sourcebootstrapflow` + `sourcebuildflow` + `sourceflow`
  - `src/fpdev.fpc.manager.pas` → `installsurfaceflow` + `maintenanceflow` + `residualflow` + `runtimeflow` + `verifyflow` + `statusflow` + `versionflow` + `bootstrapflow` + `indexflow`
  - `src/fpdev.resource.repo.pas` → `lifecycleflow` + `queryflow` + `packageflow` + `mirrorflow` + `bootstrapflow` + `statusflow` + `distributionflow`
  - `src/fpdev.package.manager.pas` → `managerflow` + `facadeflow` + `installflow` + `publishflow` + `queryflow`
  - `src/fpdev.lazarus.manager.pas` → `metadataflow` + `catalogflow` + `maintenanceflow` + `versionflow` + `pathflow`
- 当前仍然偏大的文件，如 `src/fpdev.index.pas`、`src/fpdev.fpc.installer.pas`、`src/fpdev.lazarus.config.pas`，更接近核心业务/服务实现面，而不是低风险 thin-facade cut。
- 关键验证结果：
  - `python3 -m unittest tests.test_build_manager_boundary -v` → `5/5`
  - `python3 -m unittest tests.test_fpc_builder_boundary -v` → `3/3`
  - `python3 -m unittest tests.test_package_manager_boundary -v` → `3/3`
  - `python3 -m unittest tests.test_lazarus_manager_version_boundary -v` → `5/5`
  - `python3 -m unittest tests.test_fpc_source_boundary -v` → `5/5`
  - `python3 -m unittest tests.test_resource_repo_boundary tests.test_fpc_manager_bootstrap_boundary -v` → `15/15`
- checkpoint 结论：
  - 当前没有再发现一个新的“3-5 个方法成组、测试护栏成熟、爆炸半径低”的明显 helper extraction wave
  - 后续如果继续推进，应重新围绕核心业务层做新的设计级规划，而不是继续对现有 facade 层做机械拆分


### Phase 97: BuildManager TestResults Docs/Todo Truth Sync
- [x] 新增 `tests/test_build_manager_docs_truth_contract.py`，锁定 BuildManager 文档、报告与 todo 必须反映当前 `TestResults` 真相
- [x] 先运行新增 docs contract，确认当前工作树在旧 placeholder 文案、report 缺失、todo 未勾选三处稳定 RED
- [x] 更新 `docs/build-manager.md` 与 `docs/build-manager.en.md` 顶部摘要，移除“仅检查目录存在”的陈旧描述
- [x] 更新 `report/fpdev.build.manager.md`，补上 `src/fpdev.build.testresultsflow.pas` / `tests/test_build_testresultsflow.lpr` 的当前职责与覆盖
- [x] 更新 `todos/fpdev.git2.md`，仅勾掉已完成的 `TestResults 校验沙箱输出结构（允许安装时）` 子项，保留 `BuildManager 强化` 父项与日志子项未完成
- [x] 跑 focused docs/Pascal 验证并同步 `task_plan.md` / `findings.md` / `progress.md`

## Notes
- 本轮不是 reopen `BuildManager` 代码逻辑，只处理“实现/测试已是现状，但文档/报告/todo 仍停留在旧描述”的 truth-sync 漂移。
- `TestResults` 当前真实契约已稳定为：
  - 允许安装时优先校验沙箱根、`bin/` / `lib/` 结构与 strict mode
  - 未允许安装时回退检查源码目录 `compiler/` 与 `rtl/`
- 关键验证结果：
  - `python3 -m unittest tests.test_contributor_docs_contract tests.test_build_manager_docs_truth_contract -v` → `34/34`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-testresultsflow-bin -FU/tmp/fpdev-build-testresultsflow-lib tests/test_build_testresultsflow.lpr && /tmp/fpdev-build-testresultsflow-bin/test_build_testresultsflow` → `29/29`


### Phase 98: BuildManager Todo Short-Term Truth Sync
- [x] 扩展 `tests/test_build_manager_docs_truth_contract.py`，锁定 `todos/fpdev.build.manager.md` 的短期项必须反映当前文档与示例现状
- [x] 先运行新增单测，确认 runbook 与 API 示例两项在 todo 中仍是稳定 RED
- [x] 更新 `todos/fpdev.build.manager.md`，仅勾掉已完成的 runbook 与 `SetTarget/SetPrefix/SetMakeCmd` 示例项，保留 Windows 时间戳零填充未完成
- [x] 跑 `tests.test_build_manager_docs_truth_contract` 与组合 docs suite，并同步 `task_plan.md` / `findings.md` / `progress.md`

## Notes
- 这一段仍是 truth-sync，不改 `BuildManager` 代码；目标只是清掉 `todos/fpdev.build.manager.md` 里已经完成却未勾选的短期项。
- 当前短期项的真实状态：
  - Runbook / 脚本清单 / 参数说明：已在 `docs/build-manager.md` 落地
  - `SetMakeCmd` / `SetTarget` / `SetPrefix` 示例：已在文档与交叉编译示例中落地
  - Windows 时间戳零填充：仍未完成，保持待办
- 关键验证结果：
  - `python3 -m unittest tests.test_build_manager_docs_truth_contract -v` → `4/4`
  - `python3 -m unittest tests.test_contributor_docs_contract tests.test_build_manager_docs_truth_contract -v` → `35/35`


### Phase 99: BuildManager Zero-Padded Log Timestamp Truth Sync
- [x] 扩展 `tests/test_build_manager_docs_truth_contract.py`，锁定文档与 `todos/fpdev.build.manager.md` 必须反映“日志文件名已使用零填充时间戳”的当前事实
- [x] 先运行新增单测，确认中文文档仍保留“Windows 日志时间戳可能含空格”的旧说法并稳定 RED
- [x] 更新 `docs/build-manager.md` 与 `todos/fpdev.build.manager.md`，把零填充时间戳项同步到当前真实状态
- [x] 扩展 `tests/test_build_logger.lpr`，为 `build_yyyymmdd_hhnnss_zzz.log` 文件名格式补直接护栏
- [x] 跑 docs truth suite、组合 docs suite 与 `tests/test_build_logger.lpr`，并同步 `task_plan.md` / `findings.md` / `progress.md`

## Notes
- 本轮没有修改 `src/fpdev.build.logger.pas` 逻辑；代码里原本就使用 `FormatDateTime('yyyymmdd_hhnnss_zzz', Now)`，问题在于文档和 todo 仍停留在旧认知。
- 新增 `tests/test_build_logger.lpr` 护栏后，当前已经有直接证据表明日志文件名：
  - 不含空格
  - 固定宽度
  - 日期/时间/毫秒段都为数字
- 关键验证结果：
  - `python3 -m unittest tests.test_build_manager_docs_truth_contract tests.test_contributor_docs_contract -v` → `36/36`
  - `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-build-logger-bin -FU/tmp/fpdev-build-logger-lib tests/test_build_logger.lpr && /tmp/fpdev-build-logger-bin/test_build_logger` → `10/10`
