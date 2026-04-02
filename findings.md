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

