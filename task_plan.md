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
