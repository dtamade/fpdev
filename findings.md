# Findings & Decisions

## Requirements
- 审查项目整体状态
- 给出开发建议
- 对路线图进行评审
- 识别项目当前“最大的问题”

## Research Findings
- `mcp__ace_tool__search_context` 在本次会话中返回 HTTP 499，当前改用本地文件与脚本直接检查。
- 入口链路清晰：`src/fpdev.lpr` → `src/fpdev.cli.runner.pas` → `src/fpdev.cli.bootstrap.pas` → `src/fpdev.command.imports*.pas` → 全局命令注册表。
- 仓库存在正式 roadmap/status 文档：`docs/ROADMAP.md`；同时保留历史快照 `docs/DEVELOPMENT_ROADMAP.md` 和大量 `docs/plans/*.md`。
- README 与 ROADMAP 强调 `121/121 complete`、`273 discoverable tests`、Linux release acceptance passed，但文档也明确 Windows/macOS 仍需 owner checkpoint，且 `docs/KNOWN_LIMITATIONS.md` 记录部分功能仍未实现。
- `scripts/run_all_tests.sh` 已具备隔离临时目录、默认跳过网络测试、lazbuild 失败后回退到 `fpc`、以及编译状态损坏/瞬时失败自动恢复等能力，测试基础设施成熟度较高。
- 当前工作树非常脏，包含大量源码、文档、测试和脚本修改，以及未跟踪文件；说明项目正处于高变更期，任何“已完成”判断都需要结合变更窗口谨慎看待。
- 代表性验证结果：
  - `python3 -m unittest tests.test_run_all_tests tests.test_release_docs_contract tests.test_official_docs_cli_contract` 失败，且失败集中在 release owner checkpoint 文档契约。
  - `python3 -m unittest tests.test_update_test_stats` 通过。
  - `python3 scripts/update_test_stats.py --check` 通过。
  - `bash scripts/check_toolchain.sh` 通过（必需工具齐全，可选交叉工具缺失）。
  - `lazbuild -B --build-mode=Release fpdev.lpi` 通过。
  - `bash scripts/cli_smoke.sh ./bin/fpdev` 通过。
- 发布文档存在明确漂移：`docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` 未引用测试要求的 `scripts/record_owner_smoke.ps1` / `scripts/record_owner_smoke.sh`，也未包含期望的 owner smoke 证据文件名；对应契约测试为 `tests/test_release_docs_contract.py`。
- 路线图已从“功能开发”切换为“收口/发布证明”阶段，更合适的后续重心应是 release evidence、owner checkpoints、文档一致性和变更收敛，而不是继续扩功能。
- 当前工作树高度活跃：`git status --short` 显示 `238` 个已修改文件和 `41` 个未跟踪文件，共 `279` 个变更项。
- 源码热点集中在少量超大单元：`src/fpdev.utils.git.pas` 3219 行、`src/fpdev.cmd.lazarus.pas` 1166 行、`src/fpdev.fpc.manager.pas` 1138 行、`src/fpdev.cmd.project.pas` 823 行。
- 命令层正在迁移但尚未收口：`src/fpdev.cmd.lazarus.root.pas` / `src/fpdev.cmd.project.root.pas` 已引入 root shell 注册，但大量业务逻辑仍驻留在旧的 `src/fpdev.cmd.lazarus.pas` / `src/fpdev.cmd.project.pas` manager 中，并被新命令单元直接依赖。
- Git 抽象层迁移也未完成：`src/fpdev.git2.pas` 明确标注 deprecated、推荐使用 `git2.api + git2.impl`，但 `src/fpdev.utils.git.pas` 与 `TGitOperations` 仍被多个核心源码单元直接依赖。
- 因此，项目最大的深层问题不是“功能缺失”，而是“完成态叙事、验证证据、架构迁移进度”三者未完全对齐。

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| 优先阅读入口、命令导入、测试脚本、文档与 roadmap 相关文件 | 这是形成工程审查和路线图评审的最小证据集 |
| 将“状态可信度失配”视为首要诊断候选 | 它同时得到文档、契约测试、变更规模和迁移痕迹的交叉支持 |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| 语义检索工具失败 | 退回本地仓库结构化检查 |
| 工作树变更面过大，不能直接把 README/ROADMAP 文案当作当前真实状态 | 以契约测试、源码热点和 git 工作树状态交叉验证 |

## Resources
- `/home/dtamade/projects/fpdev/src`
- `/home/dtamade/projects/fpdev/tests`
- `/home/dtamade/projects/fpdev/scripts`
- `/home/dtamade/projects/fpdev/docs`
- `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
- `tests/test_release_docs_contract.py`

## Visual/Browser Findings
- 暂无

## Execution Update (2026-04-02)
- 已完成脏工作树保护与分桶重放：
  - safety branch: `stabilize/dirty-tree-2026-04-02`
  - clean restage branch: `restage/p0-cleanup-2026-04-02`
  - 4 个分桶提交已推送到远端并保持工作树干净
- 新拿到的 focused RED 不是运行时命令缺陷，而是 release gate 自身的 inventory sync 漂移：
  - `bash scripts/release_acceptance_linux.sh`
  - 失败点：`python3 scripts/update_test_stats.py --check`
  - 根因：`README.md` / `README.en.md` 已切换到 `[INFO] Discoverable test programs: ...`，而 `scripts/update_test_stats.py` 仍只接受旧前缀
- 已最小修复该本地 seam：
  - `scripts/update_test_stats.py` 现兼容旧前缀并以 `[INFO]` 作为 README 规范输出
  - `tests/test_update_test_stats.py` 新增并更新回归覆盖
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_update_test_stats`：通过
  - `python3 scripts/update_test_stats.py --check`：通过
  - `bash scripts/release_acceptance_linux.sh`：通过
    - Python regression: `270` tests OK
    - Pascal regression: `273/273` pass
    - release build: pass
    - isolated Linux CLI smoke: pass
- 结论更新：
  - 当前“最大问题”仍然是状态叙事与可验证证据必须持续对齐
  - 但在本地可证明范围内，这条 close-out 线已无新的 live red seam
  - 剩余风险主要是 owner-run / publish-time 证明，不是当前本地代码回归


## Execution Update (2026-04-02, --with-install follow-up)
- 在可选 network-gated lane 中拿到了新的真实本地 RED：
  - `bash scripts/release_acceptance_linux.sh --with-install`
  - 失败点：Pascal regression 内的 `test_fpc_installer_iobridge`
  - 失败日志目录：`logs/release_acceptance/20260402_105251`
- 调查结论：
  - `bash scripts/run_single_test.sh tests/test_fpc_installer_iobridge.lpr` 在隔离环境下可重复通过，说明原始现象带有时序性
  - 生产桥接常量当时为 `LEGACY_HTTP_GET_MAX_ATTEMPTS = 4`、`LEGACY_HTTP_GET_RETRY_DELAY_MS = 250`
  - 新增 `Server.StartDelayed(900)` 的慢启动回归后，可稳定证明 legacy HTTP download bridge 的重试窗口过短
- 已实施的最小修复：
  - `src/fpdev.fpc.installer.iobridge.pas`：将最大重试次数从 `4` 提升到 `5`
  - `tests/test_fpc_installer_iobridge.lpr`：新增 `TestLegacyHTTPDownloadBridgeRetryWhenServerStartupIsSlow`
- 当前最新本地证据：
  - `bash scripts/run_single_test.sh tests/test_fpc_installer_iobridge.lpr`：通过
  - `bash scripts/release_acceptance_linux.sh --with-install`：通过
    - Python regression: `270` tests OK
    - Pascal regression: `273/273` pass
    - release build: pass
    - isolated Linux CLI smoke: pass
    - network-gated isolated install lane: pass
    - 最新通过日志目录：`logs/release_acceptance/20260402_111602`
- 结论更新：
  - close-out 线再次回到“无新的 locally-provable live seam”状态
  - 当前剩余风险主要是 owner-run / publish-time 证明，不是本地代码回归

## Execution Update (2026-04-02, release-notes inventory sync)
- 继续检查发布 close-out 文档时，发现一个新的本地可证明 drift：
  - `RELEASE_NOTES.md` 仍声明 `271 discoverable test_*.lpr programs`
  - 当前 README / ROADMAP / testing 文档与 CI 规则已经统一到 `273`
- 修复决策：
  - 不做一次性手工改字，而是把 `RELEASE_NOTES.md` 纳入 `scripts/update_test_stats.py` 的同步目标
  - 这样后续测试库存变化时，release notes 会和 README / ROADMAP 一样由同一脚本维护
- 实施过程中拿到了额外的本地 RED：
  - `python3 scripts/update_test_stats.py --check` 在 `RELEASE_NOTES.md` 已被脚本标准化后仍失败
  - 根因是 `render_release_notes_md` 只匹配旧格式，不接受自己输出的新格式，属于幂等性缺口
- 已实施的最小修复：
  - `scripts/update_test_stats.py`：新增 `RELEASE_NOTES.md` target 与 `render_release_notes_md`，并让模式兼容 legacy/normalized 两种行格式
  - `tests/test_update_test_stats.py`：新增 release notes 更新与幂等性回归测试
  - `RELEASE_NOTES.md`：当前 test inventory 已同步为 `273 discoverable test_*.lpr programs (same inventory rules as CI)`
- 当前最新本地证据：
  - `python3 scripts/update_test_stats.py --check`：通过
  - `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract tests.test_official_docs_cli_contract tests.test_release_scripts_contract`：`27` tests OK
- 结论更新：
  - 文档叙事与自动化证据对齐仍然是 close-out 期间最容易复发的本地 seam
  - 但这次 drift 已重新纳入统一同步脚本，局部风险已收敛

## Execution Update (2026-04-02, evidence-path sync)
- 继续做 release close-out 审计时，发现两个新的本地文档 drift：
  - `CHANGELOG.md` 的 v2.1.0 release baseline 仍写 `271` discoverable tests
  - `docs/MVP_ACCEPTANCE_CRITERIA.md`、`docs/MVP_ACCEPTANCE_CRITERIA.en.md` 与 owner ledger 仍指向 `2026-03-25` 的旧 acceptance summary 路径
- 修复策略：
  - 将 `CHANGELOG.md` 纳入 `scripts/update_test_stats.py` 的共享 test-inventory 同步目标
  - 将 release acceptance / owner ledger 文档中的 evidence path 更新为当前最新的 `2026-04-02` 本地通过日志：
    - baseline: `logs/release_acceptance/20260402_104133/summary.txt`
    - install: `logs/release_acceptance/20260402_111602/summary.txt`
- 已实施的最小修复：
  - `scripts/update_test_stats.py`：新增 `CHANGELOG.md` 同步逻辑
  - `tests/test_update_test_stats.py`：新增 changelog 更新与幂等性回归
  - `tests/test_release_docs_contract.py`：新增 release close-out docs 必须引用最新 2026-04-02 evidence、不得回退到 2026-03-25 evidence 的契约
  - `CHANGELOG.md`、`docs/MVP_ACCEPTANCE_CRITERIA*.md`、`docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`：同步到当前基线
- 当前最新本地证据：
  - `python3 scripts/update_test_stats.py --check`：通过
  - `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract tests.test_official_docs_cli_contract tests.test_release_scripts_contract tests.test_generate_release_checksums tests.test_generate_release_evidence`：`35` tests OK
- 结论更新：
  - 本地 close-out seam 仍然主要集中在“公开发布叙事是否持续指向当前真实证据”
  - 这次已把 changelog inventory 与 acceptance evidence path 一并重新对齐，局部发布叙事更稳定

## Execution Update (2026-04-02, release packaging verification)
- 继续做 release close-out 验证时，补跑了完整的发布资产/证据/owner-smoke Python 套件：
  - `tests.test_package_release_assets`
  - `tests.test_generate_release_checksums`
  - `tests.test_generate_release_evidence`
  - `tests.test_record_owner_smoke_sh`
  - `tests.test_release_scripts_contract`
  - `tests.test_release_docs_contract`
  - `tests.test_ci_release_contracts`
  - `tests.test_release_status_wording`
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_release_scripts_contract tests.test_release_docs_contract tests.test_ci_release_contracts tests.test_release_status_wording`：`25` tests OK
- 结论更新：
  - 当前本地不仅文档叙事与 evidence pointer 已对齐，连 release packaging / checksum / evidence handoff 辅助脚本也都在回归覆盖内保持 green
  - 本地 close-out 线已没有新的可证明 live seam；剩余事项依赖真实跨平台资产和 owner-run sign-off

## Execution Update (2026-04-02, CI release packaging coverage)
- 继续做 release close-out 审计时，发现 CI 覆盖存在一个新的真实缺口：
  - `.github/workflows/ci.yml` 的 release-contract unittest 步骤没有运行 `tests.test_package_release_assets`
  - 也没有运行 `tests.test_generate_release_checksums`
- 该缺口的影响：
  - release asset packaging 与 checksum generation 虽然本地有测试和辅助脚本，但 CI release lane 不会自动托底这些能力
- 已实施的最小修复：
  - `.github/workflows/ci.yml`：将 `tests.test_package_release_assets` 与 `tests.test_generate_release_checksums` 加入 release contract unit tests
  - `tests/test_ci_release_contracts.py`：新增这两项的强制契约
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_ci_release_contracts`：通过
  - `python3 -m unittest -v tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_release_scripts_contract tests.test_release_docs_contract tests.test_ci_release_contracts tests.test_release_status_wording`：`25` tests OK
- 结论更新：
  - 当前本地 close-out 不仅脚本与文档对齐，连 release packaging/checksum helper 的 CI 托底也已补齐
  - 剩余阻塞继续集中在外部 publish prerequisites，而非仓库内 coverage drift

## Execution Update (2026-04-02, CI release contract breadth)
- 在补齐 package-release-assets / checksum tests 的 CI 覆盖后，又发现 release contract step 仍遗漏了 3 个与 release close-out 直接相关的测试：
  - `tests.test_official_docs_cli_contract`
  - `tests.test_update_test_stats`
  - `tests.test_ci_workflow_contract`
- 该缺口的影响：
  - 官方文档 CLI 契约、inventory sync render 逻辑、以及 CI release-lane 结构本身没有在 CI 的 fail-fast release-contract step 中被提前托底
- 已实施的最小修复：
  - `.github/workflows/ci.yml`：将这 3 项加入 release contract unit tests
  - `tests/test_ci_release_contracts.py`：新增这 3 项的强制契约
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_ci_release_contracts`：通过
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`48` tests OK
- 结论更新：
  - 当前 CI 的 release-contract step 已覆盖 release docs / scripts / packaging / checksums / evidence / official docs / sync logic / CI structure 的关键契约面
  - 本地剩余阻塞更加明确地收敛到外部发布前提，而不是仓库内 release-test selection drift

## Execution Update (2026-04-02, PowerShell owner-smoke runtime coverage)
- 继续扩大 release close-out 覆盖时，发现 shell / PowerShell owner-smoke coverage 不对称：
  - `tests.test_record_owner_smoke_sh` 已对 `scripts/record_owner_smoke.sh` 做真实执行验证
  - `scripts/record_owner_smoke.ps1` 之前只有 `tests.test_release_scripts_contract` 的存在性契约
- 已实施的最小修复：
  - 新增 `tests/test_record_owner_smoke_ps1.py`
  - 测试在 `pwsh` 可用时真实执行 `scripts/record_owner_smoke.ps1`，验证 transcript 文件名和核心 smoke 输出
  - 若 `pwsh` 不可用则显式 skip，以保持本地环境兼容性
  - `.github/workflows/ci.yml` 与 `tests/test_ci_release_contracts.py` 同步纳入该测试
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_record_owner_smoke_ps1 tests.test_ci_release_contracts`：通过（`pwsh` 不可用，本地为 skip）
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`49` tests OK，`1` skipped
- 结论更新：
  - 当前 release close-out 契约覆盖已经从“脚本存在”升级到“PowerShell owner-smoke 在支持环境中会被真实执行验证”
  - 剩余阻塞继续是外部 publish prerequisites，不是 repo-local release tooling drift

## Execution Update (2026-04-02, Windows CI PowerShell owner-smoke execution)
- 在把 `tests.test_record_owner_smoke_ps1` 纳入 CI 后，又确认这还不等于真正覆盖 Windows runtime path：
  - Ubuntu release-contract lane 没有 `pwsh`，因此该测试只会 skip
  - 换言之，CI 里仍缺少真正执行 `scripts/record_owner_smoke.ps1` 的 Windows 托底点
- RED 证据：
  - `python3 -m unittest -v tests.test_ci_workflow_contract` 失败
  - 失败点为新增契约 `test_ci_windows_job_runs_powershell_owner_smoke_unit_test`，指出 `.github/workflows/ci.yml` 缺少 `Run PowerShell owner smoke unit test` 步骤
- 已实施的最小修复：
  - `.github/workflows/ci.yml`：在 `cross-platform-cli-smoke` job 中新增 Windows-only 的 PowerShell owner-smoke unit-test step
  - `tests/test_record_owner_smoke_ps1.py`：改为按平台创建 fake executable（Windows 用 `.cmd`，POSIX 保持 shell stub），并按平台选择 `windows-x64` / `macos-x64` lane
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_ci_workflow_contract tests.test_record_owner_smoke_ps1 tests.test_ci_release_contracts`：通过（`pwsh` 不可用，本地为 skip）
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`50` tests OK，`1` skipped
- 结论更新：
  - 当前 CI 已明确具备 Windows runner 上真实执行 PowerShell owner-smoke 单测的入口
  - repo-local 剩余阻塞继续收敛到外部 owner checkpoint / release asset prerequisites

## Execution Update (2026-04-02, optional install evidence handoff)
- 在继续审计 release close-out helper 时，发现 `scripts/generate_release_evidence.py` 与发布文档对 install lane 的定位不一致：
  - `scripts/release_acceptance_linux.sh --with-install` 明确是 network-gated 的附加 lane
  - owner checkpoint 文档也把它描述成“需要时再运行”
  - 但 `scripts/generate_release_evidence.py` 却把 `--install-summary` 做成了必填参数
- 这会导致一个真实仓库内问题：
  - 如果只完成 baseline lane、尚未执行 install lane，就无法先生成一份中间态的 `RELEASE_EVIDENCE.md` handoff
  - 文档与工具行为在“install lane 是否可选”这一点上互相打架
- RED 证据：
  - `python3 -m unittest -v tests.test_generate_release_evidence` 失败
  - 新增测试 `test_script_allows_missing_optional_install_summary` 因 CLI 缺少 `--install-summary` 而报错退出
  - `python3 -m unittest -v tests.test_release_docs_contract` 失败
  - 新增契约 `test_owner_checkpoint_doc_marks_install_summary_as_optional_evidence_input` 证明 owner-checkpoint 文档尚未把该参数标成 optional
- 已实施的最小修复：
  - `scripts/generate_release_evidence.py`：`--install-summary` 改为 optional
  - 未提供时，`Linux isolated install lane` 段落会输出 `not provided` 状态和补充提示
  - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`：改为 baseline summary 必填、install summary 按需追加
  - `tests/test_generate_release_evidence.py` / `tests/test_release_docs_contract.py`：补齐相应 RED→GREEN 契约
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_generate_release_evidence tests.test_release_docs_contract`：通过
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`52` tests OK，`1` skipped
- 结论更新：
  - release evidence helper 与 release close-out 文档现在对 install lane 的 optional 性达成一致
  - repo-local 剩余阻塞继续集中在真实资产与 owner sign-off，而不是 handoff 工具约束过严

## Execution Update (2026-04-02, release-evidence publish narrative)
- 在修复 handoff helper 后继续检查公开发布叙事，发现还有一层文档漂移：
  - owner-checkpoint 文档已经要求生成/上传 `RELEASE_EVIDENCE.md`
  - 但 `docs/MVP_ACCEPTANCE_CRITERIA*.md` 的 Owner Checkpoints 仍只列出 owner smoke + `SHA256SUMS.txt`
  - `RELEASE_NOTES.md` 也把 remaining publish-time proof 写成 “Windows/macOS owner checkpoints + SHA256SUMS”
- 这会造成对外发布叙事低估剩余收口物：
  - release handoff 实际还需要 `RELEASE_EVIDENCE.md`
  - 但 acceptance / release notes 会让人误以为只差 checksums 和 owner smoke
- RED 证据：
  - `python3 -m unittest -v tests.test_release_docs_contract` 失败
  - 新增契约 `test_release_closeout_docs_include_release_evidence_handoff` 证明 acceptance docs 与 release notes 尚未纳入 `RELEASE_EVIDENCE.md`
- 已实施的最小修复：
  - `docs/MVP_ACCEPTANCE_CRITERIA.md` / `.en.md`：Owner Checkpoints 与 Release Exit Criteria 补入 `RELEASE_EVIDENCE.md`
  - `RELEASE_NOTES.md`：remaining publish-time proof、计划发布资产、owner-run 动作同步补入 `RELEASE_EVIDENCE.md`
  - `tests/test_release_docs_contract.py`：新增并收紧对应文档契约
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_release_docs_contract`：通过
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`53` tests OK，`1` skipped
- 结论更新：
  - 公开发布说明、acceptance checklist 与 owner-checkpoint handoff 现在都明确把 `RELEASE_EVIDENCE.md` 视为剩余 publish-time proof 的一部分
  - repo-local 剩余 seam 继续减少，更多转向真实发布资产与 owner 执行

## Execution Update (2026-04-02, release-notes owner smoke flow)
- 继续审计 release-closeout 公开叙事时，又发现 `RELEASE_NOTES.md` 还有一层流程漂移：
  - 它已经承认剩余 publish-time proof 包括 owner checkpoints、`SHA256SUMS.txt` 与 `RELEASE_EVIDENCE.md`
  - 但在“发布前仍需 owner 执行的动作”里，仍在手写 `system version/help`、`fpc --help`、`fpc list --all`
  - 与 canonical owner-checkpoint 文档已经明确要求使用 `record_owner_smoke.ps1` / `record_owner_smoke.sh` 的 recorder 流程不一致
- 这个问题的影响：
  - release notes 仍可能把 owner 执行路径重新分叉回“手工逐条 smoke command”
  - 这会削弱前面刚收敛好的 transcript / evidence 标准化流程
- RED 证据：
  - `python3 -m unittest -v tests.test_release_docs_contract` 失败
  - 新增契约 `test_release_notes_use_standard_owner_smoke_recorders` 指出 `RELEASE_NOTES.md` 缺少 `record_owner_smoke.ps1` / `record_owner_smoke.sh` / `generate_release_evidence.py`
- 已实施的最小修复：
  - `RELEASE_NOTES.md` 的 owner-run 动作改为直接引用标准 recorder 与 evidence 脚本
  - `tests/test_release_docs_contract.py`：新增并收紧对应 release-notes 契约
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_release_docs_contract`：通过
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`54` tests OK，`1` skipped
- 结论更新：
  - release notes 现在不再重新发明 owner smoke 流程，而是复用仓库内标准 recorder / evidence 工具链
  - repo-local release-closeout 流程进一步收敛到单一路径

## Execution Update (2026-04-02, owner-checkpoint exit criteria)
- 继续检查 canonical owner-checkpoint 文档时，又发现最后一层细小但真实的收口漂移：
  - Publish Sequence 已明确要求上传 `RELEASE_EVIDENCE.md`
  - 但同一文档的 `Release Exit Criteria` 仍只写了 `SHA256SUMS.txt` 与 owner sign-off
  - 这意味着同一份 canonical 文档内部，步骤层与退出条件层对 `RELEASE_EVIDENCE.md` 的重要性判断不一致
- RED 证据：
  - `python3 -m unittest -v tests.test_release_docs_contract` 失败
  - 新增契约 `test_owner_checkpoint_exit_criteria_include_release_evidence` 直接指出 Exit Criteria 缺少 `RELEASE_EVIDENCE.md`
- 已实施的最小修复：
  - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`：在 Release Exit Criteria 中补入 ``RELEASE_EVIDENCE.md`` 发布要求
  - `tests/test_release_docs_contract.py`：补齐对应契约
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_release_docs_contract`：通过
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`55` tests OK，`1` skipped
- 结论更新：
  - canonical owner-checkpoint 文档现在在步骤与退出条件两个层面都一致要求 `RELEASE_EVIDENCE.md`
  - repo-local release-closeout 流程进一步趋于闭合

## Execution Update (2026-04-02, README/ROADMAP sign-off wording)
- 在 canonical release docs 已经把 `SHA256SUMS.txt` 与 `RELEASE_EVIDENCE.md` 纳入剩余 publish-time proof 之后，又发现 README / ROADMAP 层还有一层公开叙事漂移：
  - `README.md` / `README.en.md` 的 `Release sign-off` 仍写成只差 Windows/macOS owner evidence
  - `docs/ROADMAP.md` 也仍写成 owner evidence still required / owner sign-off pending
  - 这些公开状态文本已经落后于当前 canonical release-closeout 叙事
- RED 证据：
  - `python3 -m unittest -v tests.test_release_status_wording` 失败
  - 3 个失败点都表明 README / ROADMAP 没有把 `SHA256SUMS.txt` 与 `RELEASE_EVIDENCE.md` 计入剩余 sign-off proof
- 已实施的最小修复：
  - `tests/test_release_status_wording.py`：收紧 README / ROADMAP wording 契约
  - `README.md` / `README.en.md`：`Release sign-off` 改为 pending Windows/macOS owner evidence + `SHA256SUMS.txt` + `RELEASE_EVIDENCE.md`
  - `docs/ROADMAP.md`：同步将 baseline / sign-off wording 改为 owner evidence and publish artifacts still required
- 当前最新本地证据：
  - `python3 -m unittest -v tests.test_release_status_wording`：通过
  - `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts`：`55` tests OK，`1` skipped
- 结论更新：
  - README / README.en / ROADMAP 现在与 canonical release-closeout 文档对“还差什么”这一点保持一致
  - repo-local 对外状态叙事继续收敛，不再低估剩余 publish-time proof
