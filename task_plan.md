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
