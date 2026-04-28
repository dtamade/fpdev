# Project Create Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.project.manager.pas`，把 `CreateFromTemplate(...)` / `SetupProjectEnvironment(...)` / `CreateProject(...)` 这段 project creation surface 下沉到独立 helper，同时保持 CLI 行为不漂移。

**Architecture:** 复用现有 `src/fpdev.project.templateflow.pas`、`src/fpdev.project.execflow.pas` 与 `FGenerator.GenerateProjectFiles(...)`。新增 `src/fpdev.project.createflow.pas` 承接项目创建编排、目标目录准备、setup warning 与成功/失败语义；`src/fpdev.project.manager.pas` 只保留 template lookup、generator wiring、console fallback 与外层异常包装。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 project create 最小切口

**Files:**
- Inspect: `src/fpdev.project.manager.pas`
- Inspect: `src/fpdev.project.templateflow.pas`
- Reuse: `tests/test_project_manager_boundary.py`
- Reuse: `tests/test_project_commands.lpr`
- Reuse: `tests/test_project_management.lpr`

**Step 1: 明确 helper 公开符号**

- `ExecuteProjectCreateFromTemplateCore(...)`
- `ExecuteProjectCreateCore(...)`

**Step 2: 锁定必须保持的行为**

- `CreateFromTemplate(...)` 继续负责基于模板与 project name 调用 generator
- `CreateProject(...)` 继续先校验 project name，再创建，再执行 setup
- `SetupProjectEnvironment(...)` 目前仍保持 placeholder 成功语义，不硬塞新功能
- setup 失败时继续只输出 warning，不把整个 create flow 变成失败

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_project_manager_boundary.py`
- Create: `tests/test_project_createflow.lpr`

**Step 1: 扩展 boundary 测试**

- 断言 `src/fpdev.project.manager.pas` 引入 `fpdev.project.createflow`
- 断言 `CreateFromTemplate(...)` / `CreateProject(...)` 改为 helper delegate
- 断言 manager section 不再内联目录准备与 create orchestration glue

**Step 2: 写 direct helper 测试**

- create-from-template: 模板不存在时返回 false
- create-from-template: 目标目录不存在时会先创建目录
- create-core: project name 校验失败时直接 false
- create-core: create 成功但 setup 失败时仍返回 true 且输出 warning

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_project_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-createflow-bin-red /tmp/fpdev-project-createflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-createflow-bin-red -FU/tmp/fpdev-project-createflow-lib-red tests/test_project_createflow.lpr`

Expected: 至少一项 FAIL，因为 helper 尚未接线。

### Task 3: 实现 create helper 并回接 manager

**Files:**
- Create: `src/fpdev.project.createflow.pas`
- Modify: `src/fpdev.project.manager.pas`

**Step 1: 写最小 helper 实现**

- helper 只承接 create/setup 编排
- 保持 `EnsureDir(...)`、template lookup 结果与 warning 语义不变
- 不重新打开 build/run/test/clean/template list/info 这些已稳定切口

**Step 2: 最小化改写 manager**

- `CreateFromTemplate(...)` 收缩为 thin delegate
- `CreateProject(...)` 收缩为 thin delegate
- `SetupProjectEnvironment(...)` 视 helper 需要保留在 manager 或改为 callback，但不要扩功能

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_project_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-createflow-bin /tmp/fpdev-project-createflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-createflow-bin -FU/tmp/fpdev-project-createflow-lib tests/test_project_createflow.lpr`

Run: `bash -lc /tmp/fpdev-project-createflow-bin/test_project_createflow`

Run: `mkdir -p /tmp/fpdev-project-management-bin /tmp/fpdev-project-management-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-management-bin -FU/tmp/fpdev-project-management-lib tests/test_project_management.lpr`

Run: `bash -lc /tmp/fpdev-project-management-bin/test_project_management`

Run: `mkdir -p /tmp/fpdev-project-commands-bin /tmp/fpdev-project-commands-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-commands-bin -FU/tmp/fpdev-project-commands-lib tests/test_project_commands.lpr`

Run: `bash -lc /tmp/fpdev-project-commands-bin/test_project_commands`

### Task 5: Final Checkpoint

**Files:**
- Inspect: `src/fpdev.package.manager.pas`
- Inspect: `src/fpdev.cross.search.pas`
- Update: `task_plan.md`
- Update: `findings.md`
- Update: `progress.md`

**Step 1: 运行 checkpoint**

Run: `python3 -m unittest tests.test_package_manager_boundary tests.test_cross_search_boundary -v`

Expected: PASS，说明这两个区域继续维持 checkpoint 策略即可。

**Step 2: 视 focused 结果决定是否进入下一波**

- 若 project create wave 全绿，就把下一波候选排序更新到 planning files
- 若暴露新的更厚 seam，再据实重排，不机械沿用旧热点结论
