# Build Baseline And Guardrail Closure Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复当前工作树 `bin/` / `lib/` 构建输出目录导致的标准构建阻塞，把“repo 构建输出目录不可写”前移为 toolchain guardrail，并用标准构建、CLI smoke、Python/Pascal focused tests 完成收口。

**Architecture:** 不修改业务功能语义，优先处理环境与 guardrail。先将 root-owned 生成目录从工作树移出并重建为当前用户可写目录，恢复 `lazbuild -B fpdev.lpi` 标准构建路径。然后在 `scripts/check_toolchain.sh` 与 `src/fpdev.toolchain.pas` 中加入 repo build output readiness 检查，让脚本入口和 `fpdev system toolchain check` 都能提前报告 `bin` / `lib` 不可写问题。测试层新增 shell 脚本回归和 Pascal toolchain JSON 回归，最后补做标准构建、CLI smoke、Python 全量与 Pascal 全量验证。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Bash, Lazarus project build

---

### Task 1: 恢复标准构建输出目录

**Files:**
- Runtime only: `/home/dtamade/projects/fpdev/bin`
- Runtime only: `/home/dtamade/projects/fpdev/lib`

**Step 1: 识别根因**

- 确认 `bin/` 与 `lib/` 当前是否为 root-owned 生成目录
- 确认父目录可写，因此可以通过 rename/move 方式非提权修复

**Step 2: 非破坏性修复**

- 将 root-owned `bin/`、`lib/` 挪到 `/tmp/fpdev-owned-artifacts-.../`
- 在仓库根目录重建新的可写 `bin/`、`lib/`
- 不删除备份目录，避免误清理他人产物

**Step 3: 立即验证标准构建**

Run: `lazbuild -B fpdev.lpi`

Expected: PASS

### Task 2: 给脚本和 CLI 加 build-output guardrail

**Files:**
- Modify: `scripts/check_toolchain.sh`
- Modify: `src/fpdev.toolchain.pas`
- Modify: `tests/test_toolchain.lpr`
- Modify: `tests/test_command_registry.lpr`
- Create: `tests/test_check_toolchain_sh.py`

**Step 1: 脚本 guardrail**

- 在 `scripts/check_toolchain.sh` 中新增 repo root build output readiness 检查：
  - `bin/` 存在且可写 -> OK
  - `bin/` 缺失但父目录可写 -> OK（create-on-demand）
  - 其余 -> MISS
  - `lib/` 同理
- 将 build output miss 计入 required failures
- 详细日志中追加 build outputs section

**Step 2: CLI toolchain guardrail**

- 在 `src/fpdev.toolchain.pas` 中给 `BuildToolchainReportJSON` 增加：
  - `repo_bin_writable`
  - `repo_lib_writable`
- 仅当当前工作目录能识别出 repo root（含 `fpdev.lpi`）时启用这两项
- 不引入写文件副作用；仅做路径与可写性探测
- 任一 repo build output 不可写时，将 report `level` 提升到 `FAIL`

**Step 3: 测试护栏**

- `tests/test_toolchain.lpr`
  - 覆盖 repo build dir 可写时 JSON entry 为 `found=true`
  - 覆盖 repo `lib/` 不可写时 JSON entry 为 `found=false` 且 `level=FAIL`
- `tests/test_command_registry.lpr`
  - 锁定 `system toolchain check` 输出中包含 repo build output entry
- `tests/test_check_toolchain_sh.py`
  - 覆盖脚本在可写 repo build dirs 下返回 0
  - 覆盖脚本在只读 `lib/` 下返回 1，并输出明确 miss

### Task 3: fresh hotspot re-ranking

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: 重新评估代码 wave**

- 基于修复后的标准构建基线，再次实扫 `project/package/resource/build/fpc/lazarus`
- 只有在存在“成组方法 + 明确测试护栏 + 低改动爆炸半径”的切口时，才进入下一波代码 helper extraction
- 若没有明确高 ROI 组块，则记录 checkpoint 结论，不强开低价值 wave

### Task 4: 收口验证

**Files:**
- Verify: `tests/test_toolchain.lpr`
- Verify: `tests/test_command_registry.lpr`
- Verify: `tests/test_check_toolchain_sh.py`
- Verify: `scripts/check_toolchain.sh`
- Verify: `fpdev.lpi`

**Step 1: Focused**

Run: `python3 -m unittest tests.test_check_toolchain_sh -v`

Run: `mkdir -p /tmp/fpdev-toolchain-bin /tmp/fpdev-toolchain-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-toolchain-bin -FU/tmp/fpdev-toolchain-lib tests/test_toolchain.lpr`

Run: `/tmp/fpdev-toolchain-bin/test_toolchain`

Run: `mkdir -p /tmp/fpdev-command-registry-bin /tmp/fpdev-command-registry-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-command-registry-bin -FU/tmp/fpdev-command-registry-lib tests/test_command_registry.lpr`

Run: `/tmp/fpdev-command-registry-bin/test_command_registry`

Run: `bash scripts/check_toolchain.sh`

Expected: PASS

**Step 2: Baseline**

Run: `lazbuild -B fpdev.lpi`

Run: `bash scripts/cli_smoke.sh ./bin/fpdev`

Run: `python3 -m unittest discover -s tests -p 'test_*.py'`

Run: `bash scripts/run_all_tests.sh`

Expected: PASS

**Step 3: Update records**

- 更新 `task_plan.md`
- 更新 `findings.md`
- 更新 `progress.md`
- 记录：
  - 目录修复方式
  - guardrail 落点
  - 最新构建 / smoke / Python / Pascal 全量结果
  - fresh hotspot re-ranking 结论
