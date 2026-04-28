# Resource Repo Repo-IO Lifecycle Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.resource.repo.pas`，把 repo-io/lifecycle 尾部的 clone/pull/manifest/version/package surface 收进 helper，降低 repository facade 中的低层 I/O glue。

**Architecture:** 新增 `src/fpdev.resource.repo.lifecycleflow.pas`，承接 git backend guard、parent-dir ensure、manifest load/store、manifest version read 与 package availability wrapper。`src/fpdev.resource.repo.pas` 继续保留 manifest state、`FGitOps` ownership、config 字段和 higher-level initialize/update/query facade，不重复打开已稳定的 bootstrap/mirror/package/query helper。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定 repo-io/lifecycle 切口并写 RED

**Files:**
- Modify: `tests/test_resource_repo_boundary.py`
- Create: `tests/test_resource_repo_lifecyclesurfaceflow.lpr`
- Reuse: `tests/test_resource_repo_lifecycleflow.lpr`

**Step 1: 扩展 boundary 契约**

- 断言 `src/fpdev.resource.repo.pas` 引入 `fpdev.resource.repo.lifecycleflow`
- 断言以下方法委托 helper：
  - `GitClone(...)`
  - `GitPull(...)`
  - `LoadManifest(...)`
  - `GetManifestVersion(...)`
  - `HasPackage(...)`
- 断言 facade 不再内联：
  - backend availability guard
  - parent dir ensure
  - manifest path / FreeAndNil / loaded-state 赋值
  - `EnsureManifestLoaded` + `FManifestData.Get(...)`
  - `try/except` 包装 `ResourceRepoHasPackageCore(...)`

**Step 2: direct helper RED**

- callback harness 覆盖：
  - clone success / backend missing / clone fail
  - pull success / backend missing / pull fail
  - manifest load success / parse fail / nil manifest handoff
  - manifest version success / manifest missing
  - package query success / exception fallback

**Step 3: Run RED**

Run:
- `python3 -m unittest tests.test_resource_repo_boundary -v`
- `mkdir -p /tmp/fpdev-resource-lifecycle-surface-bin-red /tmp/fpdev-resource-lifecycle-surface-lib-red`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-lifecycle-surface-bin-red -FU/tmp/fpdev-resource-lifecycle-surface-lib-red tests/test_resource_repo_lifecyclesurfaceflow.lpr`

Expected: FAIL，因为 lifecycle surface helper 还不存在。

### Task 2: 实现 lifecycleflow helper

**Files:**
- Create: `src/fpdev.resource.repo.lifecycleflow.pas`

**Step 1: 最小 helper API**

- `ExecuteResourceRepoGitCloneCore(...)`
- `ExecuteResourceRepoGitPullCore(...)`
- `LoadResourceRepoManifestSurfaceCore(...)`
- `GetResourceRepoManifestVersionSurfaceCore(...)`
- `ExecuteResourceRepoHasPackageSurfaceCore(...)`

**Step 2: 保持边界紧凑**

- helper 只接收 plain callbacks / state
- 不直接拥有 repository 对象
- 不重复实现 initialize/update 核心流程

### Task 3: 回接 repository facade

**Files:**
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: delegate target methods**

- repo facade 只保留字段 ownership 和 helper bridge
- `LoadManifest(...)` 负责把 helper 输出回写到 `FManifestData` / `FManifestLoaded`

**Step 2: 避免重复改动**

- 不改 `Initialize(...)` / `Update(...)`
- 不改已完成的 `mirrorflow` / `packageflow` / `queryflow` 结构

### Task 4: Focused Verification

Run:
- `python3 -m unittest tests.test_resource_repo_boundary -v`
- `mkdir -p /tmp/fpdev-resource-lifecycle-surface-bin /tmp/fpdev-resource-lifecycle-surface-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-lifecycle-surface-bin -FU/tmp/fpdev-resource-lifecycle-surface-lib tests/test_resource_repo_lifecyclesurfaceflow.lpr`
- `/tmp/fpdev-resource-lifecycle-surface-bin/test_resource_repo_lifecyclesurfaceflow`
- `mkdir -p /tmp/fpdev-resource-lifecycle-bin /tmp/fpdev-resource-lifecycle-lib`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-lifecycle-bin -FU/tmp/fpdev-resource-lifecycle-lib tests/test_resource_repo_lifecycleflow.lpr`
- `/tmp/fpdev-resource-lifecycle-bin/test_resource_repo_lifecycleflow`

Expected: PASS
