# Fresh Hotspot Recheck Checkpoint

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 `fpc.sourceflow` 收口之后，不延续过期排序，重新基于当前工作树判断是否还存在新的高 ROI thin-facade/helper extraction wave；若没有，则把“暂不继续开新 wave”的 checkpoint 明确写回 planning artifacts。

**Architecture:** 这不是新功能波次，而是一次 fresh hotspot re-rank。优先复核已经被多轮 helper 化的 manager/source/repo facade 是否还残留“3-5 个方法成组、低爆炸半径、现成测试护栏”的切口。若未发现明确切口，则停止继续拆分，避免在大 dirty worktree 上为保持动作感而硬开低价值改动。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 重新核对当前真实热点

**Files:**
- Inspect: `src/fpdev.build.manager.pas`
- Inspect: `src/fpdev.fpc.builder.pas`
- Inspect: `src/fpdev.fpc.manager.pas`
- Inspect: `src/fpdev.fpc.source.pas`
- Inspect: `src/fpdev.resource.repo.pas`
- Inspect: `src/fpdev.package.manager.pas`
- Inspect: `src/fpdev.lazarus.manager.pas`

**Step 1: 重新看文件体量**

- 记录当前较大的 manager/source/repo 文件
- 只把 facade/helper 风格文件列为候选，不把纯业务/核心实现误判成下一波拆分面

**Step 2: 看是否还存在成组 residual surface**

- 必须同时满足：
  - 3-5 个方法能成组
  - 现成 boundary/direct tests 已存在或可低成本补齐
  - helper 模式可直接复用
  - blast radius 低

### Task 2: 用边界测试验证当前 facade 现状

**Files:**
- Verify: `tests/test_build_manager_boundary.py`
- Verify: `tests/test_fpc_builder_boundary.py`
- Verify: `tests/test_package_manager_boundary.py`
- Verify: `tests/test_lazarus_manager_version_boundary.py`
- Verify: `tests/test_fpc_source_boundary.py`
- Verify: `tests/test_resource_repo_boundary.py`
- Verify: `tests/test_fpc_manager_bootstrap_boundary.py`

**Step 1: 运行轻量 boundary bundle**

- 如果这些边界全绿，说明先前高 ROI facade 面现在已基本 helper 化
- 若有一组边界暴露新的 residual inline surface，再单独开新计划

### Task 3: Decide And Sync

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: 若没有明确切口**

- 明确记录：
  - 当前暂不继续开新的 helper wave
  - 大文件剩余内容以 state ownership / service bridge / core business logic 为主
  - 后续如要继续推进，必须重新证明存在新的低风险组块

**Step 2: 若有明确切口**

- 只记录唯一优先目标和原因，不在同一轮同时打开第二个大改波次
