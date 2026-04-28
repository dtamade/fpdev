# Project Update + Resource Query Follow-Up Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 用一波高效率 follow-up 同时收两处剩余薄弱点：把 `src/fpdev.project.manager.pas` 的 `UpdateTemplates(...)` orchestration 下沉到现有 `templateflow`，并把 `src/fpdev.resource.repo.pas` 中 manifest-guarded query wrappers 统一收进 query helper。`package.manager` 与 release docs 本波只做 checkpoint，不强造额外切片。

**Architecture:** 在 `src/fpdev.project.templateflow.pas` 新增 `ExecuteProjectTemplateUpdateCore(...)`，负责 repo init/update skip/warn、templates dir 检测、sync 结果报告；`src/fpdev.project.manager.pas` 继续负责 repo 创建与异常包装。新增 `src/fpdev.resource.repo.queryflow.pas`，承接 bool / info / string / string-array 这批 manifest-guarded query wrapper 的公共逻辑，`src/fpdev.resource.repo.pas` 只传 manifest、ensure callback 与 log callback。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 project/resource 最小切口

**Files:**
- Inspect: `src/fpdev.project.manager.pas`
- Inspect: `src/fpdev.project.templateflow.pas`
- Inspect: `src/fpdev.resource.repo.pas`
- Reuse: `tests/test_project_templateflow.lpr`
- Reuse: `tests/test_resource_repo_bootstrapquery.lpr`
- Reuse: `tests/test_resource_repo_cross.lpr`

**Step 1: project helper 公开符号**

- `TProjectTemplateRepoInitFunc`
- `TProjectTemplateRepoUpdateFunc`
- `ExecuteProjectTemplateUpdateCore(...)`

**Step 2: resource helper 公开符号**

- `TResourceRepoEnsureManifestLoadedFunc`
- `TResourceRepoLogFmtProc`
- `TResourceRepoBoolQueryFunc`
- `TResourceRepoPlatformInfoQueryFunc`
- `TResourceRepoCrossInfoQueryFunc`
- `TResourceRepoStringQueryFunc`
- `TResourceRepoStringArrayQueryFunc`
- `ExecuteResourceRepoBooleanQueryCore(...)`
- `ExecuteResourceRepoPlatformInfoQueryCore(...)`
- `ExecuteResourceRepoCrossInfoQueryCore(...)`
- `ExecuteResourceRepoStringQueryCore(...)`
- `ExecuteResourceRepoStringArrayQueryCore(...)`

**Step 3: 锁定必须保持的行为**

- project update: repo unavailable 继续 non-fatal skip
- project update: force update 失败仍继续尝试 local templates
- project update: repo 没有 `templates/` 目录时继续 non-fatal skip
- project update: added/updated 计数和 up-to-date 文案保持不变
- resource queries: manifest 未加载时继续返回 safe fallback
- resource queries: helper 继续在异常时 `LogFmt(...)` 并返回 false / empty / fallback string

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_project_manager_boundary.py`
- Modify: `tests/test_project_templateflow.lpr`
- Modify: `tests/test_resource_repo_boundary.py`
- Create: `tests/test_resource_repo_queryflow.lpr`

**Step 1: project RED**

- 边界测试断言 `UpdateTemplates(...)` 调 `ExecuteProjectTemplateUpdateCore(...)`
- direct helper 测试覆盖 repo unavailable / update fail continue / missing templates dir / sync success reporting

**Step 2: resource RED**

- 边界测试断言 `src/fpdev.resource.repo.pas` 引入 `fpdev.resource.repo.queryflow`
- 断言 bootstrap/binary/cross query wrapper 改用 new helper
- direct helper 测试覆盖 manifest missing、exception logging、fallback string、success path

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_project_manager_boundary tests.test_resource_repo_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-templateflow-bin-red /tmp/fpdev-project-templateflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-templateflow-bin-red -FU/tmp/fpdev-project-templateflow-lib-red tests/test_project_templateflow.lpr`

Run: `mkdir -p /tmp/fpdev-resource-queryflow-bin-red /tmp/fpdev-resource-queryflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-queryflow-bin-red -FU/tmp/fpdev-resource-queryflow-lib-red tests/test_resource_repo_queryflow.lpr`

Expected: 至少一项 FAIL，因为 helper 尚未接线。

### Task 3: 实现 project/resource helper 并回接

**Files:**
- Modify: `src/fpdev.project.templateflow.pas`
- Modify: `src/fpdev.project.manager.pas`
- Create: `src/fpdev.resource.repo.queryflow.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: 扩展 project templateflow**

- `ExecuteProjectTemplateUpdateCore(...)` 只承接 repo-update 编排与 reporting
- 继续复用 `SyncProjectTemplatesFromRepositoryCore(...)`
- manager 继续负责 `TResourceRepository.Create(...)` 与外层 exception wrapper

**Step 2: 新增 resource queryflow**

- helper 统一封装 ensure-manifest / try-except / logging / safe fallback
- manager methods 仅保留 thin delegate
- 不重做 parser low-level 逻辑

### Task 4: Focused Verification + Checkpoints

Run: `python3 -m unittest tests.test_project_manager_boundary tests.test_resource_repo_boundary -v`

Run: `mkdir -p /tmp/fpdev-project-templateflow-bin /tmp/fpdev-project-templateflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-templateflow-bin -FU/tmp/fpdev-project-templateflow-lib tests/test_project_templateflow.lpr`

Run: `bash -lc /tmp/fpdev-project-templateflow-bin/test_project_templateflow`

Run: `mkdir -p /tmp/fpdev-project-template-commands-bin /tmp/fpdev-project-template-commands-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-project-template-commands-bin -FU/tmp/fpdev-project-template-commands-lib tests/test_project_template_commands.lpr`

Run: `bash -lc /tmp/fpdev-project-template-commands-bin/test_project_template_commands`

Run: `mkdir -p /tmp/fpdev-resource-queryflow-bin /tmp/fpdev-resource-queryflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-queryflow-bin -FU/tmp/fpdev-resource-queryflow-lib tests/test_resource_repo_queryflow.lpr`

Run: `bash -lc /tmp/fpdev-resource-queryflow-bin/test_resource_repo_queryflow`

Run: `mkdir -p /tmp/fpdev-resource-bootstrapquery-bin /tmp/fpdev-resource-bootstrapquery-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-bootstrapquery-bin -FU/tmp/fpdev-resource-bootstrapquery-lib tests/test_resource_repo_bootstrapquery.lpr`

Run: `bash -lc /tmp/fpdev-resource-bootstrapquery-bin/test_resource_repo_bootstrapquery`

Run: `mkdir -p /tmp/fpdev-resource-cross-bin /tmp/fpdev-resource-cross-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-cross-bin -FU/tmp/fpdev-resource-cross-lib tests/test_resource_repo_cross.lpr`

Run: `bash -lc /tmp/fpdev-resource-cross-bin/test_resource_repo_cross`

Run: `python3 -m unittest tests.test_package_manager_boundary tests.test_release_docs_contract -v`
