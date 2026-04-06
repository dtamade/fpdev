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
