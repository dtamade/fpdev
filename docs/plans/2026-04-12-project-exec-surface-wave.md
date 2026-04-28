# Project Exec Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成 `src/fpdev.project.manager.pas` 的 execution surface 收口：保留现有 `execflow` 对 build/test/run 的承接，再把仍内联的 clean orchestration 下沉到独立 helper，并补齐 manager boundary 护栏。

**Architecture:** `src/fpdev.project.execflow.pas` 继续承接 `BuildProject` / `TestProject` / `RunProject` 的 executable discovery、参数拆分与 process orchestration；新增 `src/fpdev.project.cleanflow.pas` 承接 clean 的目录校验、artifact 删除与结果输出。`src/fpdev.project.manager.pas` 只保留 console fallback、process runner wiring 与外层 facade。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 execution surface 边界

**Files:**
- Inspect: `src/fpdev.project.manager.pas`
- Inspect: `src/fpdev.project.execflow.pas`
- Reuse: `tests/test_project_execflow.lpr`
- Reuse: `tests/test_project_clean.lpr`
- Reuse: `tests/test_project_run.lpr`
- Reuse: `tests/test_project_test.lpr`

**Step 1: 明确 helper 公开符号**

- 已存在：`ExecuteProjectBuildCore(...)`
- 已存在：`ExecuteProjectTestCore(...)`
- 已存在：`ExecuteProjectRunCore(...)`
- 新增：`ExecuteProjectCleanCore(...)`

**Step 2: 锁定必须保持的行为**

- build 继续优先 `lazbuild`，fallback 到 `fpc` / `make`
- test 继续输出 running message / success / missing-test hint
- run 继续解析空格参数并保留 non-zero exit warning
- clean 继续删除 build artifacts，但保留 source files 且对不存在目录返回现有错误

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_project_exec_boundary.py`
- Create: `tests/test_project_cleanflow.lpr`
- Reference: `tests/test_project_execflow.lpr`

**Step 1: 写 boundary 测试**

- 断言 `src/fpdev.project.manager.pas` 引入 `fpdev.project.execflow`
- 断言 `BuildProject` / `TestProject` / `RunProject` 继续委托 `ExecuteProject*Core(...)`
- 断言 `src/fpdev.project.manager.pas` 新引入 `fpdev.project.cleanflow`
- 断言 `CleanProject(...)` 委托 `ExecuteProjectCleanCore(...)`
- 断言 manager 不再直接调用 `CleanBuildArtifacts(...)`

**Step 2: 写 direct helper 测试**

- clean helper 对不存在目录返回 false 并写错误
- clean helper 对空目录返回 true 且不删除目录本身
- clean helper 删除 `.o/.ppu/.exe|裸可执行文件` 等产物并保留 source files

**Step 3: 运行测试确认 RED**

Run: `python3 -m unittest tests.test_project_exec_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-cleanflow-bin-red /tmp/fpdev-project-cleanflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-cleanflow-bin-red -FU/tmp/fpdev-project-cleanflow-lib-red tests/test_project_cleanflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 clean helper 尚不存在。

### Task 3: 实现 clean helper 并回接 manager

**Files:**
- Create: `src/fpdev.project.cleanflow.pas`
- Modify: `src/fpdev.project.manager.pas`

**Step 1: 写最小 helper 实现**

- 只承接 clean directory validation、artifact cleanup 与输出
- 复用现有 `CleanBuildArtifacts(...)` 与 i18n 常量
- 不重新打开 build/test/run 路径

**Step 2: 最小化改写 manager**

- `CleanProject(const Outp, Errp: IOutput; ...)`

manager 继续保留 default console output fallback 与 exception boundary。

**Step 3: 跑 focused verification**

Run: `python3 -m unittest tests.test_project_exec_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-cleanflow-bin /tmp/fpdev-project-cleanflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-cleanflow-bin -FU/tmp/fpdev-project-cleanflow-lib tests/test_project_cleanflow.lpr`

Run: `bash -lc /tmp/fpdev-project-cleanflow-bin/test_project_cleanflow`

Run: `mkdir -p /tmp/fpdev-project-execflow-bin /tmp/fpdev-project-execflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-execflow-bin -FU/tmp/fpdev-project-execflow-lib tests/test_project_execflow.lpr`

Run: `bash -lc /tmp/fpdev-project-execflow-bin/test_project_execflow`

Run: `mkdir -p /tmp/fpdev-project-run-bin /tmp/fpdev-project-run-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-run-bin -FU/tmp/fpdev-project-run-lib tests/test_project_run.lpr`

Run: `bash -lc /tmp/fpdev-project-run-bin/test_project_run`

Run: `mkdir -p /tmp/fpdev-project-test-bin /tmp/fpdev-project-test-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-test-bin -FU/tmp/fpdev-project-test-lib tests/test_project_test.lpr`

Run: `bash -lc /tmp/fpdev-project-test-bin/test_project_test`

Run: `mkdir -p /tmp/fpdev-project-clean-bin /tmp/fpdev-project-clean-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-clean-bin -FU/tmp/fpdev-project-clean-lib tests/test_project_clean.lpr`

Run: `bash -lc /tmp/fpdev-project-clean-bin/test_project_clean`

Expected: PASS.
