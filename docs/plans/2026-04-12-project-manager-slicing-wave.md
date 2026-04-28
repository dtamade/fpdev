# Project Manager Templateflow Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.project.manager.pas`，把 template list/info/install/remove/update-sync 相关 orchestration 下沉到独立 helper，保持 manager 只做 facade、repo wiring 与异常包装。

**Architecture:** `src/fpdev.project.manager.pas` 继续持有 `FTemplatesRoot`、`TResourceRepository` 创建与 `GetTemplateInfo/GetAvailableTemplates` 等本地状态访问；新增 `src/fpdev.project.templateflow.pas` 负责模板输出格式化、自定义模板安装/删除以及从资源仓库模板目录同步到本地模板目录的纯编排逻辑。先锁边界，再抽 helper，最后用现有 project-template 命令回归验证行为不漂移。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化本波最小切口

**Files:**
- Inspect: `src/fpdev.project.manager.pas`
- Reuse: `tests/test_project_template_commands.lpr`
- Reuse: `tests/test_cli_project.lpr`

**Step 1: 明确本波 helper 公开符号**

- `FormatProjectTemplateListLineCore(...)`
- `ExecuteProjectTemplateListCore(...)`
- `ExecuteProjectTemplateInfoCore(...)`
- `ExecuteProjectTemplateInstallCore(...)`
- `ExecuteProjectTemplateRemoveCore(...)`
- `SyncProjectTemplatesFromRepositoryCore(...)`

**Step 2: 锁定必须保持的行为**

- `project template list` 继续输出对齐表格
- `project info <template>` 对未知模板继续走现有错误文案
- `project template install <path>` 继续接受目录并复制模板树
- 内置模板仍不可删除
- `project template update` 继续只同步带 `template.json` 的模板目录，并报告 `added/updated` 计数

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_project_manager_boundary.py`
- Create: `tests/test_project_templateflow.lpr`
- Reference: `tests/test_project_template_commands.lpr`

**Step 1: 写 boundary 测试**

- 断言 `src/fpdev.project.manager.pas` 引入 `fpdev.project.templateflow`
- 断言 `ListTemplates` 委托 `ExecuteProjectTemplateListCore(...)`
- 断言 `ShowTemplateInfo` 委托 `ExecuteProjectTemplateInfoCore(...)`
- 断言 `InstallTemplate` / `RemoveTemplate` / `UpdateTemplates` 不再内联 `FindFirst`/`template.json`/builtin 删除判定细节

**Step 2: 写 direct helper 测试**

- 列表格式化保留现有 type label 与 description
- info 输出保留 `Name/Display/Description/Type`
- install helper 复制嵌套目录
- remove helper 拒绝 builtin、删除 custom 模板目录
- sync helper 只同步带 `template.json` 的目录，并正确累计 `added/updated`

**Step 3: 运行测试确认 RED**

Run: `python3 -m unittest tests.test_project_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-templateflow-bin-red /tmp/fpdev-project-templateflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-templateflow-bin-red -FU/tmp/fpdev-project-templateflow-lib-red tests/test_project_templateflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 manager

**Files:**
- Create: `src/fpdev.project.templateflow.pas`
- Modify: `src/fpdev.project.manager.pas`

**Step 1: 写最小 helper 实现**

- 只承接模板输出和目录同步逻辑
- 不重新吸回 `TResourceRepository` 创建与 repo 初始化
- 复用现有 `IOutput` 与 i18n 文案常量

**Step 2: 最小化改写 manager**

- `ListTemplates`
- `ShowTemplateInfo`
- `InstallTemplate`
- `RemoveTemplate`
- `UpdateTemplates`

manager 只保留参数准备、repo 初始化、helper 调用与外层异常包装。

**Step 3: 跑 focused verification**

Run: `python3 -m unittest tests.test_project_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-templateflow-bin /tmp/fpdev-project-templateflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-templateflow-bin -FU/tmp/fpdev-project-templateflow-lib tests/test_project_templateflow.lpr`

Run: `bash -lc /tmp/fpdev-project-templateflow-bin/test_project_templateflow`

Run: `mkdir -p /tmp/fpdev-project-template-commands-bin /tmp/fpdev-project-template-commands-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-template-commands-bin -FU/tmp/fpdev-project-template-commands-lib tests/test_project_template_commands.lpr`

Run: `bash -lc /tmp/fpdev-project-template-commands-bin/test_project_template_commands`

Expected: PASS
