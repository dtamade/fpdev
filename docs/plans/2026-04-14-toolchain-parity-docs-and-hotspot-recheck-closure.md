# Toolchain Parity, Docs, And Hotspot Recheck Closure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把刚完成的 repo build-output guardrail 做到真正闭环：补齐中英 toolchain 文档、同步 Windows `check_toolchain.bat` parity、收拢 root-owned 隐藏备份目录策略，并在最新工作树上做 fresh hotspot recheck 决定是否继续推进下一波。

**Architecture:** 优先处理高 ROI 的收口缺口，而不是立刻再拆一轮低价值 facade。先把 Unix 已落地的 toolchain/build-output guardrail 同步到文档与 Windows 脚本层，再通过最小测试护栏锁住新行为与本地备份目录策略，最后对 `build/resource/fpc/lazarus/project/package` 做重新排序；只有当 fresh hotspot scan 发现“成组方法 + 低爆炸半径 + 现成测试护栏”的切口时才进入下一波，否则记录 checkpoint 结论直接收口。

**Tech Stack:** Object Pascal, Batch, Bash, Python unittest, Markdown docs

---

### Task 1: 补齐 toolchain 文档闭环

**Files:**
- Modify: `docs/toolchain.md`
- Modify: `docs/toolchain.en.md`

**Step 1: Write the failing doc expectations**

- 明确文档必须反映最新行为：
  - `BuildToolchainReportJSON` 现在在 repo root 场景下会输出 `repo_bin_writable` / `repo_lib_writable`
  - `scripts/check_toolchain.sh` 支持 `FPDEV_TOOLCHAIN_REPO_ROOT`
  - `scripts/check_toolchain.sh` / `fpdev system toolchain check` 会把 repo build output 不可写视为 required failure

**Step 2: Verify current docs are stale**

Run: `grep -n "repo_bin_writable\\|repo_lib_writable\\|FPDEV_TOOLCHAIN_REPO_ROOT" docs/toolchain.md docs/toolchain.en.md`

Expected: no matches before doc update.

**Step 3: Write minimal doc updates**

- 更新中英文文档的：
  - Main API 描述
  - JSON 示例
  - 字段说明
  - 常见问题/建议
- 补充 `FPDEV_TOOLCHAIN_REPO_ROOT` 为测试/override 用法，而不是日常使用入口

**Step 4: Re-run doc expectation check**

Run: `grep -n "repo_bin_writable\\|repo_lib_writable\\|FPDEV_TOOLCHAIN_REPO_ROOT" docs/toolchain.md docs/toolchain.en.md`

Expected: matches found in both docs.

### Task 2: 同步 Windows check_toolchain.bat parity

**Files:**
- Modify: `scripts/check_toolchain.bat`
- Create: `tests/test_check_toolchain_bat.py`

**Step 1: Write the failing contract test**

- 新增 Python contract test 锁定：
  - `.bat` 支持 `FPDEV_TOOLCHAIN_REPO_ROOT`
  - `.bat` 输出/探测 `repo_bin_writable`
  - `.bat` 输出/探测 `repo_lib_writable`
  - `.bat` 把 repo build outputs 计入 required failure 语义

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_check_toolchain_bat -v`

Expected: FAIL because the current batch script lacks repo build-output guardrail parity.

**Step 3: Write minimal implementation**

- 在 `scripts/check_toolchain.bat` 中增加：
  - repo root 解析（优先 `FPDEV_TOOLCHAIN_REPO_ROOT`）
  - `repo_bin_writable` / `repo_lib_writable` 探测
  - detailed log 中的 build outputs section
  - required failure 计数接线

**Step 4: Re-run test to verify it passes**

Run: `python3 -m unittest tests.test_check_toolchain_bat -v`

Expected: PASS.

### Task 3: 收敛 root-owned 隐藏备份目录策略

**Files:**
- Modify: `.gitignore`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Lock ignore strategy**

- 为 `.bin.root-owned-*` / `.lib.root-owned-*` 增加 ignore 规则
- 目标是避免这类本地恢复备份目录继续污染 `git status`

**Step 2: Verify status effect**

Run: `git status --short -- .bin.root-owned-20260414_190837 .lib.root-owned-20260414_190837`

Expected: no untracked entries after ignore rule is in place.

**Step 3: Record residual note**

- 在 planning files 中明确：
  - 目录仍存在
  - 当前无法移出/删除
  - 但已被 ignore，且不再影响标准构建

### Task 4: fresh hotspot recheck

**Files:**
- Modify: `findings.md`
- Modify: `progress.md`
- Modify: `task_plan.md`

**Step 1: Re-scan remaining hotspots**

- 基于最新工作树重新审视：
  - `src/fpdev.build.manager.pas`
  - `src/fpdev.resource.repo.pas`
  - `src/fpdev.fpc.manager.pas`
  - 以及必要时 `lazarus/project/package`
- 只在满足以下条件时才进入下一波：
  - 3-5 个方法能成组
  - 边界测试已存在或可低成本补齐
  - 爆炸半径低

**Step 2: Decide**

- 如果没有明确高 ROI 组块：
  - 在 `findings.md` / `progress.md` / `task_plan.md` 写明“暂不继续开新 wave”
- 如果存在明确组块：
  - 记录唯一优先的下一波目标与原因，但本轮不强行铺开第二轮大改

### Task 5: 收口验证

**Files:**
- Verify: `docs/toolchain.md`
- Verify: `docs/toolchain.en.md`
- Verify: `scripts/check_toolchain.bat`
- Verify: `tests/test_check_toolchain_bat.py`
- Verify: `.gitignore`

**Step 1: Focused**

Run: `python3 -m unittest tests.test_check_toolchain_sh tests.test_check_toolchain_bat -v`

Run: `bash scripts/check_toolchain.sh`

Run: `git status --short -- .bin.root-owned-20260414_190837 .lib.root-owned-20260414_190837`

Expected: PASS, and hidden backup dirs no longer show as untracked.

**Step 2: Broad**

Run: `python3 -m unittest discover -s tests -p 'test_*.py'`

Run: `bash scripts/run_all_tests.sh`

Expected: PASS.

**Step 3: Update records**

- 更新 `task_plan.md`
- 更新 `findings.md`
- 更新 `progress.md`
- 记录：
  - 文档闭环结果
  - Windows parity 落点
  - ignore 策略
  - fresh hotspot recheck 结论
