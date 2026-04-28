# Build Manager Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.build.manager.pas`，把最适合 helper 化的 preflight/build/install/test-result orchestration 收进 shared flow，降低 BuildManager 巨石程度，同时不触碰高风险底层构建细节。

**Architecture:** 新增 `src/fpdev.build.managerflow.pas`，只承接 BuildManager facade surface 的顺序编排与输出 contract；`src/fpdev.build.manager.pas` 继续保留真实 make/process/build-context/state 管理。优先选择已被现有 build/test suites 覆盖的 public 方法，避免一次性打开整个 build core。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 选最小安全切口并写 RED

**Files:**
- Create: `tests/test_build_manager_boundary.py`
- Create: `tests/test_build_managerflow.lpr`
- Reuse: `tests/test_build_manager.lpr`
- Reuse: `tests/test_build_fullbuildflow.lpr`
- Reuse: `tests/test_build_preflightflow.lpr`
- Reuse: `tests/test_build_testresultsflow.lpr`

**Step 1: boundary 测试**

- 锁定 `src/fpdev.build.manager.pas` 引入 `fpdev.build.managerflow`
- 锁定本轮目标 facade 方法改为 delegate

**Step 2: direct helper 测试**

- preflight sequencing
- build step ordering
- install/report finish contract
- common failure propagation

### Task 2: 实现 managerflow helper

**Files:**
- Create: `src/fpdev.build.managerflow.pas`
- Modify: `src/fpdev.build.manager.pas`

**Step 1: helper 最小 API**

- callback-based orchestration core
- 不直接 new low-level process/build objects

**Step 2: facade 改写**

- 只抽边界清晰、测试充分的方法
- 保持 public 行为不变

### Task 3: Focused Verification

Run:
- `python3 -m unittest tests.test_build_manager_boundary -v`
- `tests/test_build_managerflow.lpr`
- `tests/test_build_manager.lpr`
- `tests/test_build_fullbuildflow.lpr`
- `tests/test_build_preflightflow.lpr`
- `tests/test_build_testresultsflow.lpr`

Expected: 全部通过。
