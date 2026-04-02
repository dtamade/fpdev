# Task Plan: FPDev Project Review

## Goal
审查 FPDev 项目的当前工程状态，识别“最大的问题”并给出有证据支撑的判断。

## Current Phase
Phase 4 complete

## Phases
### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints and requirements
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Repository Review
- [x] Inspect application entrypoints and command registration
- [x] Inspect test layout, tooling, and scripts
- [x] Inspect documentation and maintenance signals
- **Status:** complete

### Phase 3: Roadmap Review
- [x] Locate roadmap or planning documents
- [x] Compare roadmap intent with current codebase reality
- [x] Identify sequencing and dependency risks
- **Status:** complete

### Phase 4: Synthesis
- [x] Summarize findings by severity
- [x] Identify the single biggest current project problem
- [x] Produce concise evidence-backed recommendation set
- **Status:** complete

## Key Questions
1. 当前代码库最影响交付质量的工程问题是什么？
2. 现有测试、脚本和模块边界是否支撑 roadmap 的后续扩展？
3. 路线图是否与当前项目成熟度、依赖和验证能力匹配？
4. “已完成/可发布”的叙事是否和当前可验证状态一致？

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 采用工程审查 + roadmap 评审双视角 | 用户同时请求项目审查、开发建议和路线图评审 |
| 使用仓库内计划文件记录发现 | 任务较复杂，便于持续沉淀上下文 |
| 本轮聚焦“最大问题”而非完整审计 | 用户现在要的是单点判断，不是全量报告 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `mcp__ace_tool__search_context` returned HTTP 499 | 1 | Switched to direct repository inspection via shell commands and file reads |
| `git status --short | python3 - <<'PY' ...` caused `IndentationError` | 1 | Re-ran with `python3 -c` instead of a piped heredoc |

## Notes
- 优先寻找高风险问题、验证缺口和路线图落地阻塞项。
- 若缺少明确 roadmap 文档，需要基于仓库 TODO/docs/issue-like 文本进行推断并明确标注。

## Recommendation Set (2026-04-02)
1. 先做变更收敛，再谈“已完成”：
   - 已将脏工作树保存在 `stabilize/dirty-tree-2026-04-02`
   - 已把可验证改动重放到干净分支 `restage/p0-cleanup-2026-04-02`
2. 把发布叙事建立在自动化证据上：
   - release docs drift 已修复
   - `scripts/update_test_stats.py --check` 已恢复为 release gate
   - `bash scripts/release_acceptance_linux.sh` 已在当前分支通过
3. close-out 线只继续处理新的 focused RED seam：
   - 当前无新的 locally-provable local seam
   - network-gated lane 仅在出现新 RED 或 owner 明确批准时继续
4. 剩余风险明确归类为发布所有权事项，而不是本地代码缺口：
   - Windows/macOS owner checkpoints
   - `SHA256SUMS.txt`
   - 可选的 `--with-install` isolated install lane


## Close-out Update (2026-04-02, --with-install lane)
1. `bash scripts/release_acceptance_linux.sh --with-install` 暴露了一个新的本地可证明 seam：
   - Pascal regression 在 `test_fpc_installer_iobridge` 处失败
   - 失败日志目录：`logs/release_acceptance/20260402_105251`
2. 该 seam 已从偶发症状转成稳定回归证明：
   - 原始 isolated 测试重复通过，说明仅靠一次 broad failure 还不足以下结论
   - 新增 `Server.StartDelayed(900)` 的慢启动用例后，可稳定证明 legacy HTTP bridge retry window 偏短
3. 修复保持在生产接缝而不是 acceptance 脚本：
   - `src/fpdev.fpc.installer.iobridge.pas` 将 `LEGACY_HTTP_GET_MAX_ATTEMPTS` 从 `4` 提升到 `5`
   - `tests/test_fpc_installer_iobridge.lpr` 新增慢启动回归用例
4. 最新验证证据：
   - `bash scripts/run_single_test.sh tests/test_fpc_installer_iobridge.lpr`：通过
   - `bash scripts/release_acceptance_linux.sh --with-install`：通过
   - 最新通过日志目录：`logs/release_acceptance/20260402_111602`
5. 当前剩余风险再次收敛为 owner / publish 事项：
   - Windows/macOS owner checkpoints
   - `SHA256SUMS.txt`

## Close-out Update (2026-04-02, release-notes inventory sync)
1. 本地继续检查发布收口文档时，发现 `RELEASE_NOTES.md` 仍写着 `271 discoverable test_*.lpr programs`，与当前公共基线 `273` 不一致。
2. 修复策略不是手工改单个文档，而是把 `RELEASE_NOTES.md` 纳入 `scripts/update_test_stats.py` 的同步范围，避免后续再次漂移。
3. 扩大同步范围后又暴露了一个真实本地 seam：
   - `python3 scripts/update_test_stats.py --check` 在 `RELEASE_NOTES.md` 已被标准化后仍报错
   - 根因是 release-notes 的匹配模式只接受旧格式，不接受脚本自己写回的规范格式
4. 已完成的修复与验证：
   - `scripts/update_test_stats.py` 新增 `RELEASE_NOTES.md` 同步逻辑，并兼容旧/新两种 release-notes 行格式
   - `tests/test_update_test_stats.py` 新增 release-notes 回归与幂等性覆盖
   - `python3 scripts/update_test_stats.py --check`：通过
   - `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract tests.test_official_docs_cli_contract tests.test_release_scripts_contract`：`27` tests OK
5. 当前剩余发布事项仍主要是 owner / 资产侧动作：
   - Windows/macOS owner checkpoints
   - 在具备全部计划资产后二进制打包与 `SHA256SUMS.txt`

## Close-out Update (2026-04-02, evidence-path sync)
1. 继续审计公开发布文档后，确认还剩两类本地可证明漂移：
   - `CHANGELOG.md` 的 release baseline 仍写 `271` 个 discoverable tests
   - `docs/MVP_ACCEPTANCE_CRITERIA*.md` 与 `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 仍引用 `2026-03-25` 的旧 acceptance evidence path
2. 这轮修复继续遵循“统一来源 + 最小修改”：
   - `CHANGELOG.md` 纳入 `scripts/update_test_stats.py` 的同步范围，避免未来再次漂移
   - release acceptance / owner ledger 文档直接更新到当前最新本地证据：
     - baseline: `logs/release_acceptance/20260402_104133/summary.txt`
     - install: `logs/release_acceptance/20260402_111602/summary.txt`
3. 为避免 evidence path 回退，又新增了 release-doc 契约覆盖：
   - 要求 close-out 文档引用 `2026-04-02` 的最新 evidence
   - 明确拒绝旧的 `2026-03-25` evidence path
4. 已完成验证：
   - `python3 scripts/update_test_stats.py --check`：通过
   - `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract tests.test_official_docs_cli_contract tests.test_release_scripts_contract tests.test_generate_release_checksums tests.test_generate_release_evidence`：`35` tests OK
5. 当前剩余本地不可闭合事项不变：
   - Windows/macOS owner checkpoints
   - 全部计划发布资产到位后的打包、`SHA256SUMS.txt`、正式 release evidence 生成

## Close-out Update (2026-04-02, release packaging verification)
1. 在完成 inventory / evidence path 对齐后，又补跑了完整的 release packaging / handoff 相关 Python 套件。
2. 最新额外验证命令：
   - `python3 -m unittest -v tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_release_scripts_contract tests.test_release_docs_contract tests.test_ci_release_contracts tests.test_release_status_wording`
3. 最新额外验证结果：
   - `25` tests OK
   - 涵盖 release asset packaging、`SHA256SUMS` 生成、release evidence 汇总、owner smoke transcript、release docs / scripts / CI contracts
4. 这轮 sweep 没有暴露新的本地可证明 seam，说明当前本地 close-out 已基本收尽。
5. 仍然剩余的工作全部依赖外部条件：
   - Windows/macOS owner checkpoints
   - 真正的 Windows/macOS 发布资产
   - 资产齐备后的正式 `SHA256SUMS.txt` 与 `RELEASE_EVIDENCE.md`

## Close-out Update (2026-04-02, CI release packaging coverage)
1. 新发现的本地可证明 seam：CI 的 `Run release contract unit tests` 步骤没有覆盖
   - `tests.test_package_release_assets`
   - `tests.test_generate_release_checksums`
2. 这会导致 release packaging / checksum 脚本虽然本地有测试，但 CI 不会在 release lane 中托底这些能力。
3. 已完成的最小修复：
   - `.github/workflows/ci.yml` 的 release-contract unittest 列表补入上述两项
   - `tests/test_ci_release_contracts.py` 升级为要求 CI 必须包含这两项
4. 已完成验证：
   - `python3 -m unittest -v tests.test_ci_release_contracts`：通过
   - `python3 -m unittest -v tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_release_scripts_contract tests.test_release_docs_contract tests.test_ci_release_contracts tests.test_release_status_wording`：`25` tests OK
5. 当前剩余工作仍然回到外部发布前提：
   - Windows/macOS owner checkpoints
   - 真实跨平台发布资产
   - 资产到位后的正式 checksum / release evidence 生成

## Close-out Update (2026-04-02, CI release contract breadth)
1. 在补齐 packaging/checksum 覆盖后，又确认 CI 的 release contract unit tests 仍缺少 3 个直接相关的测试：
   - `tests.test_official_docs_cli_contract`
   - `tests.test_update_test_stats`
   - `tests.test_ci_workflow_contract`
2. 这些测试分别覆盖：
   - 官方公开文档 CLI 契约
   - release inventory sync / doc sync 逻辑
   - CI workflow 本身的 release-lane 结构契约
3. 已完成的最小修复：
   - `.github/workflows/ci.yml` 将上述 3 项加入 release contract unit tests
   - `tests/test_ci_release_contracts.py` 升级为强制 CI 必须包含它们
4. 已完成验证：
   - `python3 -m unittest -v tests.test_ci_release_contracts`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`48` tests OK
5. 当前剩余工作继续是外部条件，而不是 repo-local release coverage 缺口：
   - Windows/macOS owner checkpoints
   - 真实发布资产
   - 正式 checksum / release evidence 产物生成

## Close-out Update (2026-04-02, PowerShell owner-smoke runtime coverage)
1. 新发现的本地 release coverage gap：
   - `record_owner_smoke.sh` 已有真实执行测试
   - `record_owner_smoke.ps1` 之前只有存在性契约，没有对脚本本身做运行覆盖
2. 已完成的最小修复：
   - 新增 `tests/test_record_owner_smoke_ps1.py`
   - 在有 `pwsh` 的环境中真实执行 `scripts/record_owner_smoke.ps1`
   - 在没有 `pwsh` 的环境中显式 skip，避免本地环境差异阻塞
   - `.github/workflows/ci.yml` 的 release contract unit tests 补入 `tests.test_record_owner_smoke_ps1`
   - `tests/test_ci_release_contracts.py` 强制 CI 必须包含该测试
3. 已完成验证：
   - `python3 -m unittest -v tests.test_record_owner_smoke_ps1 tests.test_ci_release_contracts`：通过（本地 `pwsh` 不可用，因此 PowerShell 运行测试为 skip）
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`49` tests OK，`1` skipped
4. 结论：
   - 当前 release contract / helper / doc / CI breadth 已覆盖到 shell 与 PowerShell 两条 owner-smoke 路径
   - 剩余工作继续集中在外部发布资产和 owner sign-off

## Close-out Update (2026-04-02, Windows CI PowerShell owner-smoke execution)
1. 新发现的剩余 repo-local gap：
   - `tests.test_record_owner_smoke_ps1` 已被纳入 Ubuntu release-contract step，但本地/Ubuntu 环境没有 `pwsh`，该测试只会 skip
   - 因此 CI 仍未真正执行 Windows PowerShell owner-smoke runtime path
   - RED 由 `tests.test_ci_workflow_contract.test_ci_windows_job_runs_powershell_owner_smoke_unit_test` 明确暴露
2. 已完成的最小修复：
   - `.github/workflows/ci.yml` 在 `cross-platform-cli-smoke` 中新增 Windows-only 的 `Run PowerShell owner smoke unit test` 步骤
   - `tests/test_record_owner_smoke_ps1.py` 改为按平台生成 fake executable：
     - Windows：`fpdev.cmd`
     - 其他平台：保留 shebang shell stub
   - 同一测试按平台选择 transcript lane：
     - Windows：`windows-x64`
     - 其他平台：`macos-x64`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_ci_workflow_contract`：通过
   - `python3 -m unittest -v tests.test_ci_workflow_contract tests.test_record_owner_smoke_ps1 tests.test_ci_release_contracts`：通过（本地 `pwsh` 不可用，因此 PowerShell runtime test 为 skip）
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`50` tests OK，`1` skipped
4. 结论：
   - 现在 CI 不仅声明 PowerShell owner-smoke contract，还会在 Windows runner 上真实执行对应单测
   - 本地环境仍保持 skip-on-missing-pwsh 的兼容性

## Close-out Update (2026-04-02, optional install evidence handoff)
1. 新发现的 release close-out seam：
   - `scripts/generate_release_evidence.py` 强制要求 `--install-summary`
   - 但 `scripts/release_acceptance_linux.sh --with-install` 与 owner-checkpoint 文档都把该 lane 定位为 network-gated / optional
   - 这导致“未执行 install lane 时无法生成 RELEASE_EVIDENCE.md”的仓库内不一致
2. 已完成的最小修复：
   - `scripts/generate_release_evidence.py` 允许省略 `--install-summary`
   - 当未提供 install summary 时，生成的 `Linux isolated install lane` 段落会明确标记 `not provided`，并提示可在执行 network-gated lane 后追加 `--install-summary`
   - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 同步改为：baseline summary 必填，install summary 按需追加
   - 新增/收紧测试覆盖：
     - `tests.test_generate_release_evidence.test_script_allows_missing_optional_install_summary`
     - `tests.test_release_docs_contract.test_owner_checkpoint_doc_marks_install_summary_as_optional_evidence_input`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_generate_release_evidence tests.test_release_docs_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`52` tests OK，`1` skipped
4. 结论：
   - release evidence handoff 现在与 “install lane 可选” 的 close-out 叙事保持一致
   - 剩余工作继续收敛到外部 owner checkpoint / release asset prerequisites

## Close-out Update (2026-04-02, release-evidence publish narrative)
1. 新发现的 repo-local 文档漂移：
   - owner-checkpoint 文档已要求生成并上传 `RELEASE_EVIDENCE.md`
   - 但 `docs/MVP_ACCEPTANCE_CRITERIA*.md` 仍只把 owner checkpoints 与 `SHA256SUMS.txt` 视为剩余 publish-time proof
   - `RELEASE_NOTES.md` 也仍把 remaining publish-time proof 写成 “Windows/macOS owner checkpoints + SHA256SUMS”
2. 已完成的最小修复：
   - `tests/test_release_docs_contract.py` 新增 `test_release_closeout_docs_include_release_evidence_handoff`
   - `docs/MVP_ACCEPTANCE_CRITERIA.md` 与 `docs/MVP_ACCEPTANCE_CRITERIA.en.md` 的 Owner Checkpoints / Release Exit Criteria 补入 `RELEASE_EVIDENCE.md`
   - `RELEASE_NOTES.md` 的 remaining publish-time proof、发布资产清单、owner 动作列表同步补入 `RELEASE_EVIDENCE.md`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_release_docs_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`53` tests OK，`1` skipped
4. 结论：
   - 公开 release 叙事现在与 owner-checkpoint handoff 要求一致，不再遗漏 `RELEASE_EVIDENCE.md`
   - 仓库内剩余工作继续集中在真实资产、checksums 与 owner sign-off 的外部执行

## Close-out Update (2026-04-02, release-notes owner smoke flow)
1. 新发现的 repo-local 文档 seam：
   - `RELEASE_NOTES.md` 已承认还需要 owner checkpoints / checksums / `RELEASE_EVIDENCE.md`
   - 但在“发布前仍需 owner 执行的动作”里，仍然手写 `system version/help`、`fpc --help`、`fpc list --all`
   - 这与 owner-checkpoint 文档已经标准化到 `record_owner_smoke.ps1` / `record_owner_smoke.sh` / `generate_release_evidence.py` 的流程不一致
2. 已完成的最小修复：
   - `tests/test_release_docs_contract.py` 新增 `test_release_notes_use_standard_owner_smoke_recorders`
   - `RELEASE_NOTES.md` 改为直接引用：
     - `scripts/record_owner_smoke.ps1`
     - `scripts/record_owner_smoke.sh`
     - `scripts/generate_release_checksums.py`
     - `scripts/generate_release_evidence.py`
   - 不再在 release notes 中手写 smoke commands 细节
3. 已完成验证：
   - `python3 -m unittest -v tests.test_release_docs_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`54` tests OK，`1` skipped
4. 结论：
   - release notes 的 owner-run 步骤现在与 canonical owner-checkpoint 流程一致
   - 仓库内剩余工作继续更多转向真实资产与外部 sign-off，而不是文档流程漂移

## Close-out Update (2026-04-02, owner-checkpoint exit criteria)
1. 新发现的 canonical 文档 seam：
   - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 的 Publish Sequence 已要求上传 `RELEASE_EVIDENCE.md`
   - 但同一文档的 Release Exit Criteria 仍只要求 `SHA256SUMS.txt` 与 owner sign-off，没有把 `RELEASE_EVIDENCE.md` 列为退出条件
2. 已完成的最小修复：
   - `tests/test_release_docs_contract.py` 新增 `test_owner_checkpoint_exit_criteria_include_release_evidence`
   - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 的 Release Exit Criteria 补入 ``RELEASE_EVIDENCE.md`` 发布要求
3. 已完成验证：
   - `python3 -m unittest -v tests.test_release_docs_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`55` tests OK，`1` skipped
4. 结论：
   - canonical owner-checkpoint 文档现在在 Publish Sequence 与 Exit Criteria 两层都把 `RELEASE_EVIDENCE.md` 视为必需发布产物
   - repo-local close-out 叙事进一步收敛到单一一致流程

## Close-out Update (2026-04-02, README/ROADMAP sign-off wording)
1. 新发现的 repo-local 公开叙事 seam：
   - `README.md` / `README.en.md` / `docs/ROADMAP.md` 仍把 release sign-off 描述成仅差 Windows/macOS owner evidence
   - 但 canonical release docs 现在已经明确剩余 publish-time proof 还包括 `SHA256SUMS.txt` 与 `RELEASE_EVIDENCE.md`
2. 已完成的最小修复：
   - `tests/test_release_status_wording.py` 收紧为要求 README / ROADMAP 显式纳入 `SHA256SUMS.txt + RELEASE_EVIDENCE.md`
   - `README.md` / `README.en.md` / `docs/ROADMAP.md` 的 sign-off wording 同步改成：
     - pending Windows/macOS owner evidence + `SHA256SUMS.txt` + `RELEASE_EVIDENCE.md`
   - `docs/ROADMAP.md` 的 baseline 行也同步改为 “owner evidence and publish artifacts still required”
3. 已完成验证：
   - `python3 -m unittest -v tests.test_release_status_wording`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`55` tests OK，`1` skipped
4. 结论：
   - README / README.en / ROADMAP 现在不再低估剩余 publish-time proof
   - repo-local release-closeout 公开叙事进一步与 canonical release docs 对齐

## Close-out Update (2026-04-02, owner-checkpoint planned assets)
1. 新发现的 canonical 文档 seam：
   - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 的 Publish Sequence 与 Exit Criteria 都已要求 `RELEASE_EVIDENCE.md`
   - 但同一文档的 `Planned Release Assets` 表仍漏掉了 `RELEASE_EVIDENCE.md`
2. 已完成的最小修复：
   - `tests/test_release_docs_contract.py` 新增 `test_owner_checkpoint_doc_lists_release_evidence_as_planned_artifact`
   - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 的 `Planned Release Assets` 表补入 `RELEASE_EVIDENCE.md`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_release_docs_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`56` tests OK，`1` skipped
4. 结论：
   - canonical owner-checkpoint 文档现在在资产清单、步骤、退出条件三个层面都完整纳入 `RELEASE_EVIDENCE.md`
   - repo-local close-out 文档进一步达到自洽

## Close-out Update (2026-04-02, changelog release baseline artifacts)
1. 新发现的 repo-local 文档 seam：
   - `CHANGELOG.md` 的 `2.1.0 / Release Baseline` 仍只描述 Linux acceptance、owner checkpoints、版本同步与 test inventory
   - 但当前 canonical release-closeout 叙事已经把标准 owner recorder 流程、`SHA256SUMS.txt` 与 `RELEASE_EVIDENCE.md` 视为剩余 publish-time proof 的一部分
   - 这使得 changelog 成为最后一个仍未完整反映 close-out 资产/证据流的公共发布文档
2. 已完成的最小修复：
   - `tests/test_release_docs_contract.py` 新增 `test_changelog_release_baseline_tracks_release_publish_artifacts`
   - `CHANGELOG.md` 的 `Release Baseline` 补入：
     - `scripts/record_owner_smoke.ps1`
     - `scripts/record_owner_smoke.sh`
     - `scripts/generate_release_checksums.py`
     - `scripts/generate_release_evidence.py`
     - `SHA256SUMS.txt`
     - `RELEASE_EVIDENCE.md`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_release_docs_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`57` tests OK，`1` skipped
4. 结论：
   - `CHANGELOG.md` 现在也与当前 release-closeout 的 recorder / checksum / evidence 资产叙事保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是仓库内文档漂移

## Close-out Update (2026-04-02, installation docs package-manager drift)
1. 新发现的 repo-local 公开文档 seam：
   - `docs/INSTALLATION.md` 与 `docs/INSTALLATION.en.md` 仍把 Homebrew / Chocolatey / Snap / APT 写成 “Method 3 / Package Manager Installation (Planned)”
   - 这些渠道当前并未发布，且它们是公开安装指南里仅剩的“看起来可以直接照做”的假入口
   - `tests/test_official_docs_cli_contract.py` 已经约束其他官方文档不要保留过时的 roadmap/install 叙事，但此前没有覆盖安装指南
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_installation_docs_do_not_advertise_unpublished_package_manager_channels`
   - `docs/INSTALLATION.md` / `docs/INSTALLATION.en.md` 移除未发布的包管理器安装命令
   - 改为明确说明：当前没有已发布的 package-manager 渠道，需使用 GitHub Release 二进制或源码构建
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`58` tests OK，`1` skipped
4. 结论：
   - 官方安装指南现在不再把未发布的 package-manager 渠道伪装成可执行安装路径
   - repo-local 剩余工作继续集中在真实发布资产与 owner sign-off，而不是公开安装入口漂移

## Close-out Update (2026-04-02, installation docs release-layout drift)
1. 新发现的 repo-local 公开文档 seam：
   - `scripts/package_release_assets.py` 与 `tests/test_package_release_assets.py` 明确约束发布资产的内容是：
     - 根目录 `fpdev` / `fpdev.exe`
     - 同级 `data/`
   - `src/fpdev.paths.pas` 也明确：当可执行文件同级存在 `data/` 时会进入 portable mode
   - 但 `docs/INSTALLATION*.md` 仍在教用户：
     - Windows 把不存在的 `C:\\fpdev\\bin` 加到 PATH
     - Linux/macOS 只移动 `fpdev` 到 `/usr/local/bin` 或 `~/.local/bin`
   - 这会破坏发布资产的真实布局，导致公开安装指南与打包/运行时模型不一致
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_installation_docs_preserve_release_asset_layout`
   - `docs/INSTALLATION.md` / `docs/INSTALLATION.en.md` 改为：
     - 明确要求保持 `fpdev` / `fpdev.exe` 与同级 `data/` 一起解压
     - Windows 将 `C:\\fpdev` 本身加入 PATH
     - Linux/macOS 将完整解压目录加入 PATH，而不是只搬运单个二进制
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`59` tests OK，`1` skipped
4. 结论：
   - 官方安装指南现在与发布资产的真实布局、portable mode 触发条件和打包契约保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是安装布局误导

## Close-out Update (2026-04-02, installation docs env/data-root drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 明确支持的数据根覆盖变量是 `FPDEV_DATA_ROOT`
   - 同一单元也明确：portable release 默认把 `<install-dir>/data` 当作数据根，因此配置/日志默认落在 `data/config.json` 与 `data/logs/`
   - 但 `docs/INSTALLATION*.md` 仍在宣传并不存在或未实现的：
     - `FPDEV_HOME`
     - `FPDEV_CONFIG`
     - `FPDEV_PARALLEL_JOBS`
     - `FPDEV_DEBUG`
     - `FPDEV_VERBOSE`
   - 同时还把 portable release 的配置/日志路径写成家目录下的 `~/.fpdev` / `%USERPROFILE%\\.fpdev`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_installation_docs_use_supported_data_root_env_and_paths`
   - `docs/INSTALLATION.md` / `docs/INSTALLATION.en.md` 改为：
     - 明确 `FPDEV_DATA_ROOT` 才是受支持的数据根覆盖变量
     - 明确 portable release 默认配置/日志路径为 `data/config.json` 与 `data/logs/`
     - 删除不受支持的 env var 示例
     - 将性能优化改为通过 `FPDEV_DATA_ROOT` 放置 mutable data，并提示通过 `config.json` 的 `settings.parallel_jobs` 调整并行度
     - 卸载说明同步改为删除完整 portable release 目录，而不是只删单个二进制
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`60` tests OK，`1` skipped
4. 结论：
   - 官方安装指南现在不再宣传未实现的 env toggles，也不再把 portable release 的配置/日志路径写错
   - repo-local 剩余工作进一步收敛到外部发布资产与 owner 执行，而不是安装文档和运行时路径语义失配

## Close-out Update (2026-04-02, quickstart docs config/parallelism drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 明确：portable release 默认把 `<install-dir>/data` 当作数据根，配置路径是 `data/config.json`
   - 同一单元也明确：受支持的数据根覆盖变量是 `FPDEV_DATA_ROOT`
   - `src/data/config.json` 与 `tests/data/config.json` 也说明并行度来自 `settings.parallel_jobs`
   - 但 `docs/QUICKSTART.md` 与 `docs/QUICKSTART.en.md` 仍在宣传：
     - `~/.fpdev/config.json`
     - `%USERPROFILE%\.fpdev\config.json`
     - `FPDEV_PARALLEL_JOBS`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_quickstart_docs_use_supported_config_and_parallelism_guidance`
   - `docs/QUICKSTART.md` / `docs/QUICKSTART.en.md` 改为：
     - 明确 quick-start portable 场景默认配置路径是 `<install-dir>/data/config.json`
     - 明确如需覆盖数据根，应使用 `FPDEV_DATA_ROOT`
     - 将并行度说明改为编辑当前 `config.json` 中的 `settings.parallel_jobs`
     - 删除不受支持的 `FPDEV_PARALLEL_JOBS` 与旧家目录配置路径叙述
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`61` tests OK，`1` skipped
4. 结论：
   - QUICKSTART 文档现在与运行时支持的 config/data-root 模型和并行度配置方式保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是入门文档语义漂移

## Close-out Update (2026-04-02, fpdevrc docs global-config path drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 明确：全局配置路径始终取决于当前数据根，而不是固定写死在 `~/.fpdev/config.json`
   - 运行时支持的全局配置入口包括：
     - portable release：`<install-dir>/data/config.json`
     - 显式覆盖：`FPDEV_DATA_ROOT/config.json`
     - Linux/macOS 非 portable：`$XDG_DATA_HOME/fpdev/config.json`，未设置时回退 `~/.fpdev/config.json`
     - Windows 非 portable：`%APPDATA%\fpdev\config.json`
   - 但 `docs/FPDEVRC_SPEC.md` 与 `docs/FPDEVRC_SPEC.en.md` 仍把全局配置写成单一路径 `~/.fpdev/config.json`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_fpdevrc_docs_describe_active_global_config_paths`
   - `docs/FPDEVRC_SPEC.md` / `docs/FPDEVRC_SPEC.en.md` 改为：
     - 明确全局默认来自当前活动数据根中的 `config.json`
     - 明确 portable release 的 `data/config.json`
     - 明确 `FPDEV_DATA_ROOT`、`XDG_DATA_HOME` 与 `%APPDATA%\fpdev\config.json` 的路径语义
     - 将优先级说明改成“活动 `config.json` 中的 `default_toolchain`”，不再把用户引导到单一旧路径
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`62` tests OK，`1` skipped
4. 结论：
   - FPDEVRC 规范文档现在也与运行时真实的 active data-root / active config 模型保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是项目配置规范漂移

## Close-out Update (2026-04-02, fpc management docs toolchain-layout drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 明确：安装目录布局以当前数据根为核心，FPC 安装路径是 `<data-root>/toolchains/fpc/<version>`
   - `src/fpdev.fpc.installversionflow.pas` 明确：FPC 源码目录是 `<install-root>/sources/fpc/fpc-<version>`
   - `tests/test_fpc_verify.lpr` 也把 `InstallRoot/toolchains/fpc/3.2.2/bin` 作为验证时的 canonical 布局
   - 但 `docs/FPC_MANAGEMENT.md` 与 `docs/FPC_MANAGEMENT.en.md` 仍在宣传：
     - `~/.fpdev/fpc/3.2.2`
     - 扁平的 `sources/fpc-3.2.2`
     - `~/.fpdev/config.json`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_fpc_management_docs_use_data_root_toolchain_layout`
   - `docs/FPC_MANAGEMENT.md` / `docs/FPC_MANAGEMENT.en.md` 改为：
     - 用 `<data-root>/toolchains/fpc/<version>` 和 `<data-root>/sources/fpc/fpc-<version>` 描述真实目录布局
     - 在目录结构与示例 `install_path` 中明确 canonical toolchain path
     - 在诊断段改为说明活动数据根中的 `config.json`，并明确 `data/config.json` / `FPDEV_DATA_ROOT`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`63` tests OK，`1` skipped
4. 结论：
   - FPC 管理文档现在也与运行时真实的 toolchain/source layout 和 active config path 对齐
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是 FPC 文档路径漂移

## Close-out Update (2026-04-02, toolchain docs active-data-root drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 明确：数据根默认来自 portable `data/` 或平台目录，不是仓库根下的 `.fpdev/`
   - `src/fpdev.source.pas` 明确：`ensure-source` 会把源码复制到 `<data-root>/sandbox/sources/...`
   - 同一单元也明确：`import-bundle` 会把校验通过的 zip 导入 `<data-root>/cache/toolchain/`
   - 但 `docs/toolchain.md` 与 `docs/toolchain.en.md` 仍把离线模式默认数据根写成 repo-root `.fpdev/`，并连带把 cache/sandbox/logs/locks 示例都写死成 `.fpdev/...`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_toolchain_docs_describe_active_data_root_paths`
   - `docs/toolchain.md` / `docs/toolchain.en.md` 改为：
     - 明确数据根由运行时决定，portable release 默认使用 `data/`
     - 用 `<data-root>/cache/`、`<data-root>/sandbox/`、`<data-root>/logs/`、`<data-root>/locks/` 描述真实目录
     - 将 `ensure-source` / `import-bundle` 的行为说明改成 `<data-root>/sandbox/...` 与 `<data-root>/cache/toolchain/`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`64` tests OK，`1` skipped
4. 结论：
   - toolchain 文档现在也与 active data-root、sandbox 和 cache 的真实运行时模型保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是离线工具链文档的 repo-root 假设

## Close-out Update (2026-04-02, repo spec mirror-config path drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 明确：镜像配置所在的 `config.json` 取决于当前活动数据根，而不是固定的 `~/.fpdev/config.json`
   - `src/fpdev.config.commandflow.pas` 也围绕 `GetConfigPath` 读写配置项，包括 `settings.mirror` 与 `settings.custom_repo_url`
   - 但 `docs/REPO_SPECIFICATION.md` 与 `docs/REPO_SPECIFICATION.en.md` 在镜像源选择章节仍把用户配置路径写死为 `~/.fpdev/config.json`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_repo_spec_docs_describe_active_config_path_for_mirror_settings`
   - `docs/REPO_SPECIFICATION.md` / `docs/REPO_SPECIFICATION.en.md` 改为：
     - 明确镜像配置写入当前活动数据根中的 `config.json`
     - 补入 portable release 的 `data/config.json`
     - 补入 `FPDEV_DATA_ROOT`、`XDG_DATA_HOME` 与 `%APPDATA%\fpdev\config.json` 的路径语义
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`65` tests OK，`1` skipped
4. 结论：
   - REPO_SPECIFICATION 文档现在也与活动配置路径和镜像配置的真实落点保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是仓库规范文档中的固定 home-path 假设

## Close-out Update (2026-04-02, config-architecture docs active-config drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.paths.pas` 与 `src/fpdev.config.core.pas` 明确：`TConfigManager` 默认使用 `GetConfigPath`，而该路径来自当前活动数据根
   - 但 `docs/config-architecture.md` 与 `docs/config-architecture.en.md` 的示例代码和配置文件格式说明仍把路径写死为：
     - `~/.fpdev/config.json`
     - `%APPDATA%\.fpdev\config.json`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_config_architecture_docs_describe_active_config_paths`
   - `docs/config-architecture.md` / `docs/config-architecture.en.md` 改为：
     - 推荐示例直接用 `TConfigManager.Create` / `TFPDevConfigManager.Create` 的默认路径解析
     - 明确活动 `config.json` 来自 portable release 的 `data/config.json`，或 `FPDEV_DATA_ROOT` / `XDG_DATA_HOME` / `%APPDATA%\fpdev\config.json`
     - 删除旧的 `%APPDATA%\.fpdev\config.json` 叙述
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`66` tests OK，`1` skipped
4. 结论：
   - config-architecture 文档现在也与 `TConfigManager` 的真实默认路径解析模型保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是架构文档里的硬编码 home-path 示例

## Close-out Update (2026-04-02, manifest-usage active-cache-path drift)
1. 新发现的 repo-local 公开文档 seam：
   - `src/fpdev.manifest.cache.pas` 明确：manifest 缓存目录默认来自 `GetCacheDir + '/manifests'`
   - `src/fpdev.cmd.fpc.update_manifest.pas` 也通过当前配置解析 manifest cache dir，而不是固定写死到 `~/.fpdev/cache/manifests`
   - `src/fpdev.paths.pas` 的 `BuildFPCInstallDirFromInstallRoot` 明确 FPC 安装落点是 `toolchains/fpc/<version>`
   - 但 `docs/MANIFEST-USAGE.md` 仍把 manifest 缓存与安装目录写死为：
     - `~/.fpdev/cache/manifests/fpc.json`
     - `~/.fpdev/toolchains/fpc/<version>`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_manifest_usage_doc_describes_active_manifest_cache_and_install_paths`
   - `docs/MANIFEST-USAGE.md` 改为：
     - 明确 manifest 缓存和安装目录跟随当前活动数据根
     - 补入 `FPDEV_DATA_ROOT`、`XDG_DATA_HOME`、`%APPDATA%\\fpdev\\`、`<data-root>/cache/manifests/fpc.json` 与 `<data-root>/toolchains/fpc/<version>`
     - 删除旧的 `~/.fpdev/cache/manifests/fpc.json` 与 `~/.fpdev/toolchains/fpc/<version>` 叙述
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`67` tests OK，`1` skipped
4. 结论：
   - `MANIFEST-USAGE` 文档现在也与 manifest 缓存和 toolchain 安装的活动路径模型保持一致
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是 manifest 使用文档里的旧 home-path 假设

## Close-out Update (2026-04-02, faq project-local install guidance drift)
1. 新发现的 repo-local 公开文档 seam：
   - `docs/FAQ.md` 与 `docs/FAQ.en.md` 仍把“项目作用域安装”写成在项目目录执行安装后自动落到 `.fpdev/toolchains/`
   - 但当前公开路径模型已经统一到活动数据根，由 `FPDEV_DATA_ROOT` 或运行时默认数据根决定
   - `docs/FPC_MANAGEMENT.md` 也已明确 canonical 安装目录是 `<data-root>/toolchains/fpc/<version>`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_faq_docs_describe_project_local_isolation_via_active_data_root`
   - `docs/FAQ.md` / `docs/FAQ.en.md` 改为：
     - 用显式 `FPDEV_DATA_ROOT` 描述项目本地隔离安装
     - 将安装落点明确写成 `<data-root>/toolchains/fpc/3.2.2`
     - 删除旧的 `.fpdev/toolchains/` 叙述
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`68` tests OK，`1` skipped
4. 结论：
   - FAQ 文档现在也与活动数据根路径模型保持一致，不再宣传隐式的 `.fpdev/toolchains/` 项目作用域安装
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是 FAQ 中的旧安装路径叙事

## Close-out Update (2026-04-02, roadmap install-path success-metric drift)
1. 新发现的 repo-local 公开文档 seam：
   - `docs/ROADMAP.md` 的 Phase 2 success metrics 仍把以下旧路径模型写成“ALL ACHIEVED”：
     - `Project-scoped installation (.fpdev/toolchains/)`
     - `User-scoped installation (~/.fpdev/fpc/)`
   - 同文件的 Development Philosophy 也仍写着 `Project-level (if .fpdev exists) → User-level`
   - 但当前公开路径模型已经统一到活动数据根，由 `FPDEV_DATA_ROOT` 或运行时默认数据根决定，canonical 安装目录是 `<data-root>/toolchains/fpc/<version>`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_roadmap_success_metrics_use_active_install_path_model`
   - `docs/ROADMAP.md` 改为：
     - 将 Scope-Aware 原则改成 `FPDEV_DATA_ROOT` / active data root 模型
     - 将旧的 project/user scoped install success metrics 改成 active install layout 与 project-local isolation via `FPDEV_DATA_ROOT`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`69` tests OK，`1` skipped
4. 结论：
   - `ROADMAP.md` 现在也与活动数据根安装路径模型保持一致，不再把旧的 `.fpdev/toolchains/` / `~/.fpdev/fpc/` 当成当前成功标准
   - repo-local 剩余工作继续收敛到外部 owner 执行与真实发布资产，而不是 roadmap 中的旧安装路径叙事

## Close-out Update (2026-04-02, todo-fpc-v1 active-install-model drift)
1. 新发现的 repo-local live-design seam：
   - `docs/ROADMAP.md` 已经声明 “Following the TODO-FPC-v1.md philosophy”，所以 `docs/TODO-FPC-v1.md` 仍然是 live design input，而不是单纯历史草稿
   - 但该文档仍把 install/data-root 模型写成旧版本：
     - `FPDEV_HOME`
     - `%LOCALAPPDATA%/fpdev`
     - `~/.local/share/fpdev`
     - 自动 `.fpdev/` project-mode data root
     - `--scope user|project|system`
     - `project: .fpdev/toolchains/fpc/<version>` / `user: <DATA_ROOT>/toolchains/fpc/<version>`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_todo_fpc_v1_uses_active_data_root_install_model`
   - `docs/TODO-FPC-v1.md` 改为：
     - 使用 `FPDEV_DATA_ROOT` 与活动 data root 作为默认安装模型
     - 平台默认路径改为 `%APPDATA%\fpdev`、`$XDG_DATA_HOME/fpdev` 与 `~/.fpdev`
     - install 选项清单改成当前 CLI 实际支持的 `--from-source` / `--from-binary` / `--from=` / `--jobs=` / `--prefix=` / `--offline` / `--no-cache`
     - 默认安装路径改成 `<data-root>/toolchains/fpc/<version>`
     - 保留 `use` 的 project/user activation 语义，不再把 `.fpdev/` 描述成自动 data-root 切换
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`70` tests OK，`1` skipped
4. 结论：
   - `TODO-FPC-v1.md` 现在也与公开活动数据根安装模型保持一致，不再把旧的 scope/data-root 叙事重新引回 roadmap 哲学层
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, roadmap activate-flag drift)
1. 新发现的 repo-local live-status seam：
   - `docs/ROADMAP.md` 的 Development Philosophy 仍写着 `Activation: Off by default (explicit use or --activate)`
   - 但当前 `fpdev fpc install` 的帮助和参数解析已经没有 `--activate`，激活应通过安装后的 `fpdev fpc use <version>` 完成
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_roadmap_does_not_advertise_removed_install_activate_flag`
   - `docs/ROADMAP.md` 将该原则改成“需要 shell/project activation 时，安装后显式执行 `use`”
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`71` tests OK，`1` skipped
4. 结论：
   - `ROADMAP.md` 现在不再宣传已移除的 `install --activate` 参数，live status 文档与当前 CLI 帮助面再次保持一致
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, quickstart install-verbose drift)
1. 新发现的 repo-local live-user-guide seam：
   - `docs/QUICKSTART.md` 与 `docs/QUICKSTART.en.md` 的常见问题仍建议运行 `fpdev fpc install 3.2.2 --from-source --verbose`
   - 但当前 `fpdev fpc install` 命令并不支持 `--verbose`，用户照抄会触发 unknown-option usage error
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_quickstart_docs_do_not_advertise_unsupported_install_verbose_flag`
   - `docs/QUICKSTART.md` / `docs/QUICKSTART.en.md` 将该建议改为重跑 `fpdev fpc install 3.2.2 --from-source` 并检查当前数据根中的 `logs/`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`72` tests OK，`1` skipped
4. 结论：
   - Quickstart 文档现在不再建议不存在的 `--verbose` flag，用户照着入门文档执行也不会被带到 usage error
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, quickstart binary-first install drift)
1. 新发现的 repo-local live-onboarding seam：
   - `docs/QUICKSTART.md` 与 `docs/QUICKSTART.en.md` 仍把 `fpdev fpc install 3.2.2 --from-source` 写成“推荐版本 FPC”的默认安装命令
   - 但已对齐的 FAQ / FPC 管理文档都明确：FPC 默认应先走二进制安装，源码构建只作为需要时的备选路径
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_quickstart_docs_do_not_recommend_source_install_as_default`
   - `docs/QUICKSTART.md` / `docs/QUICKSTART.en.md` 改为：
     - 默认命令使用 `fpdev fpc install 3.2.2`
     - 保留 `--from-source` 作为“需要源码构建时”的显式备选
     - 备注改成“binary-first 更快，source build 按需使用”
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`73` tests OK，`1` skipped
4. 结论：
   - Quickstart 文档现在也与 binary-first 的当前安装策略保持一致，不再把更慢、更脆弱的源码构建写成首次上手默认路径
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, quickstart package-status drift)
1. 新发现的 repo-local live-onboarding seam：
   - 中文 `docs/QUICKSTART.md` 的包管理段仍把 `fpdev package search` 和 `fpdev package install` 标成“功能开发中”
   - 但这些命令已经存在于当前 CLI：命令已注册，帮助/用法字符串存在，且有对应测试覆盖
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_quickstart_docs_do_not_mark_package_commands_as_in_development`
   - `docs/QUICKSTART.md` 删除两处“功能开发中”状态标签，保持与英文 quickstart 和实际命令面一致
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`74` tests OK，`1` skipped
4. 结论：
   - 中文 Quickstart 现在不再把已存在的 package commands 错标为“功能开发中”，中英文入门文档的状态叙事重新一致
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, quickstart backup-path drift)
1. 新发现的 repo-local live-onboarding seam：
   - `docs/QUICKSTART.md` / `docs/QUICKSTART.en.md` 的 tips 仍建议备份 `.fpdev` 目录
   - 但当前公开路径模型已经统一为活动数据根：portable release 默认 `data/`，也可由 `FPDEV_DATA_ROOT` 覆盖
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_quickstart_docs_describe_backup_via_active_data_root`
   - `docs/QUICKSTART.md` / `docs/QUICKSTART.en.md` 将备份建议改成“备份当前活动数据根”，并明确举例 `data/` 与 `FPDEV_DATA_ROOT`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`75` tests OK，`1` skipped
4. 结论：
   - Quickstart 文档现在也与活动数据根备份模型保持一致，不再把 `.fpdev` 当成默认状态目录
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, manifest migration dry-run drift)
1. 新发现的 repo-local live-doc seam：
   - `docs/MANIFEST-MIGRATION.md` 仍把 `fpc install`、`lazarus install`、`cross install` 都写成支持 `--dry-run`
   - 但当前 CLI 只有 `cross build --dry-run` 是真实支持的 dry-run 路径；三个 install 命令都不接受这些示例里的 flag 组合
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_manifest_migration_doc_does_not_advertise_unsupported_install_dry_run_flags`
   - `docs/MANIFEST-MIGRATION.md`：
     - 删掉三个不存在的 `install --dry-run` 示例
     - 改为使用 `./bin/test_manifest_parser`
     - 改为使用受支持的 `./bin/fpdev fpc install --help`、`./bin/fpdev lazarus install --help`
     - 改为使用真实支持 dry-run 的 `./bin/fpdev cross build aarch64-linux --dry-run`
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：先 RED，修复后通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`76` tests OK，`1` skipped
4. 结论：
   - `MANIFEST-MIGRATION.md` 现在也与当前 install/build help surface 保持一致，不再鼓励用户复制不存在的 `install --dry-run`
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产

## Close-out Update (2026-04-02, roadmap scope-flag drift)
1. 新发现的 repo-local live-status seam：
   - `docs/ROADMAP.md` 仍保留 `2.1 Scoped Installation` 与 `Implement --scope (project/user/system)`
   - 但当前公开 install 模型已经统一为显式 `FPDEV_DATA_ROOT` / `--prefix`，不再对外宣传 `install --scope`
2. 已完成的最小修复：
   - `tests/test_official_docs_cli_contract.py` 新增 `test_roadmap_does_not_advertise_removed_install_scope_flag`
   - `docs/ROADMAP.md`：
     - `2.1 Scoped Installation` 改成 `2.1 Custom Install Roots & Activation`
     - `Implement --scope (project/user/system)` 改成 `Support project-local isolation via FPDEV_DATA_ROOT or --prefix`
     - `Implement scope-aware activation` 改成 `Implement scope-aware activation artifacts`
     - Phase 2 progress summary 同步改名
3. 已完成验证：
   - `python3 -m unittest -v tests.test_official_docs_cli_contract`：先 RED，修复后通过
   - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`77` tests OK，`1` skipped
4. 结论：
   - `ROADMAP.md` 现在不再把安装入口描述成 `install --scope`，同时保留仍真实存在的 activation scope 叙事
   - repo-local 可证明的 seam 继续减少，剩余工作继续收敛到外部 owner 执行与真实发布资产
