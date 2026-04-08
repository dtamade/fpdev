# FPDev Close-Out Roadmap

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the remaining locally-provable live defects quickly without reopening broad product epics.

**Architecture:** Continue the 2026-03-24 wave model. Each wave must prove a real public seam first, land the minimal fix if red, and stop immediately when the seam is disproved or fully closed. Treat stale roadmap documents as reference only; current execution truth lives in this file plus `task_plan.md`, `findings.md`, and `progress.md`.

**Tech Stack:** Object Pascal (FPC/Lazarus), fpcunit-style CLI tests, Python regression, shell verification.

---

## Execution Update (2026-03-25)
- 已关闭 live seam：
  - `project info` unknown option / extra positional usage-error contract
  - `project test` / `project clean` extra positional usage-error contract
  - `project template update` unknown option / extra positional usage-error contract
- 本轮已完成的 `project` namespace contract parity 收口：
  - `project new` unknown option / extra positional
  - `project build` unknown option
  - `project test` unknown option
  - `project clean` unknown option
  - `project template list` extra positional / unknown option
  - `project template install` extra positional / unknown option
  - `project template remove` extra positional / unknown option
  - `project template update` extra positional / unknown option
- 已证伪相邻候选：
  - `package info` 当前已经在 CLI / registry 两层显式拒绝 unknown option / extra positional
  - `package publish` 的同进程 `FPDEV_DATA_ROOT` 归属已经由
    `tests/test_cli_package_publish.inc` 中的
    `TestPublishUsesFPDEVDataRootArchiveRoot` 覆盖，不是当前未验证缺口
- 已明确保留的边界：
  - `project run` 是显式 variadic contract：`[dir] [args...]`
  - `project template update` 的入口 contract 已关闭，而且 deeper local-positive path
    已被本地 harness 证明：
    - 预置本地 `resources` git repo + `templates/...`
    - 覆盖 `Settings.InstallRoot`
    - 在 local-only update warning 后仍会复制模板到 install root
  - 剩余未激活的边界只剩 remote ownership / clone semantics，不是当前 live seam
- 当前 active queue 以最新 RED/GREEN 证据为准，优先级已调整为：
  1. 当前没有新的 locally-provable `project` contract seam
  2. resource-repo 的 remote ownership / clone semantics 仅在出现新的 focused RED 后继续
  3. 若没有新的 focused RED，本 close-out 线保持关闭，不再开放式滚动
- 执行规则保持不变：
  - 不把代码观察直接当 defect
  - 每一波必须先拿 focused RED
  - 共享 `-FUlib` 的 focused Pascal 编译保持串行
  - 每一波必须以“证伪 / 修复并全量验证 / 明确延后”之一结束，避免无边界续做

## Route

### Wave 0: Project Namespace Local Contract Closure
- 状态：completed
- 已用一次广审 + 一次聚合 RED/GREEN 收口本地可证明的 `project` leaf seams：
  - `new`
  - `build`
  - `test`
  - `clean`
  - `template list`
  - `template install`
  - `template remove`
  - `template update`
- `project run` 被保留为 variadic contract，不纳入这一波收紧。

### Wave A: Project Template Update Deeper Acceptance
- 状态：completed
- Target the real CLI path:
  - `TProjectTemplateUpdateCommand.Execute(...)`
  - `TProjectManager.UpdateTemplates(...)`
  - `TResourceRepository.Initialize(...)`
  - `TResourceRepository.Update(...)`
- Outcome:
  - 入口 contract 已通过本地 harness 关闭
  - deeper local-positive acceptance 也已通过 focused probe 证明为绿
  - 预置本地 `resources/templates/...` 时，模板会复制到 `Settings.InstallRoot/templates/...`
  - `Repo.Update(True)` 的 local-only failure 在该路径上是 non-fatal
  - 这轮没有触发任何 production edit

### Wave B: Remote Ownership / Network-Gated Lane
- 状态：idle
- Only enter this wave if a new focused RED proves a clone/pull/bootstrap defect beyond the now-covered local-positive path.
- If Wave B changes production code, run adjacent regressions.
- Always run:
  - focused `project` / resource-repo regression
  - Python suite
  - full Pascal suite

### Wave C: Queue Closure
- Update `task_plan.md`, `findings.md`, and `progress.md` with:
  - outcome
  - evidence
  - remaining risk
  - next-wave recommendation
- If no new local red seam remains, close the current close-out line.
- Defer network-gated ownership questions unless they can be reproduced with a stable local harness or explicitly approved.

## Priority Queue
1. no open locally-provable `project` contract seam in the current close-out line
2. network-gated resource-repo acceptance only when locally reproducible or explicitly approved
3. no new wave unless出现新的 focused RED seam

## Stop Conditions
- The focused probe is green without production edits.
- The focused probe is red, the minimal fix lands, and all acceptance gates are green.
- The seam cannot be proven locally and would require network-dependent or speculative changes.
