# Resource Package Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.resource.repo.pas` 的 package surface，把 package info/list/search facade 收进 helper；`src/fpdev.package.manager.pas` 本波只做 checkpoint，确认 install/update/dependency surface 已足够薄，不再机械开新 helper。

**Architecture:** 复用现有 `src/fpdev.resource.repo.package.pas`、`src/fpdev.resource.repo.search.pas` 与 `src/fpdev.resource.repo.distributionflow.pas`，新增 repo-level package surface helper，承接 exception-safe info/list/search orchestration。`src/fpdev.resource.repo.pas` 继续保留 repo state、日志函数与安装入口；`src/fpdev.package.manager.pas` 仅复核已有 `managerflow` / `lifecycle` delegation，不做低 ROI 深拆。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 resource/package 最小切口

**Files:**
- Inspect: `src/fpdev.resource.repo.pas`
- Inspect: `src/fpdev.resource.repo.package.pas`
- Inspect: `src/fpdev.resource.repo.search.pas`
- Reuse: `src/fpdev.resource.repo.distributionflow.pas`
- Reuse: `tests/test_resource_repo_query.lpr`
- Reuse: `tests/test_package_manager_boundary.py`
- Reuse: `tests/test_package_manager_installupdateflow.lpr`

**Step 1: 明确 helper 公开符号**

- `TResourceRepoPackageLogFmtProc`
- `ExecuteResourceRepoPackageInfoSurfaceCore(...)`
- `ExecuteResourceRepoPackageListSurfaceCore(...)`
- `ExecuteResourceRepoPackageSearchSurfaceCore(...)`

**Step 2: 锁定必须保持的行为**

- `GetPackageInfo(...)` 异常时继续 `LogFmt(...)` 并返回 false
- `ListPackages(...)` 继续返回 low-level helper 的真实结果
- `SearchPackages(...)` 继续先拿 `ListPackages('')`，再按 metadata/description filter
- `InstallPackage(...)` 继续复用 distributionflow，不重开
- `package.manager` install/update/dependency surface 继续只做 checkpoint，不额外造 helper

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_resource_repo_boundary.py`
- Create: `tests/test_resource_repo_packagesurfaceflow.lpr`

**Step 1: 扩展 boundary 测试**

- 断言 `src/fpdev.resource.repo.pas` 引入 package surface helper 单元
- 断言 `GetPackageInfo(...)` / `ListPackages(...)` / `SearchPackages(...)` 改为 helper delegate
- 断言 repo section 不再内联 `try/except` package query glue

**Step 2: 写 direct helper 测试**

- info query: exception -> log + false
- list query: 直接透传 low-level helper 结果
- search query: keyword filter 继续基于 package metadata description

**Step 3: 跑 RED 验证**

Run: `python3 -m unittest tests.test_resource_repo_boundary -v`

Run: `mkdir -p /tmp/fpdev-resource-packagesurfaceflow-bin-red /tmp/fpdev-resource-packagesurfaceflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-packagesurfaceflow-bin-red -FU/tmp/fpdev-resource-packagesurfaceflow-lib-red tests/test_resource_repo_packagesurfaceflow.lpr`

Expected: 至少一项 FAIL，因为 helper 尚未接线。

### Task 3: 实现 resource helper 并复核 package checkpoint

**Files:**
- Create: `src/fpdev.resource.repo.packageflow.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: 写最小 resource package helper**

- helper 只承接 repo-level info/list/search facade
- 继续复用 `ResourceRepoGetPackageInfoCore(...)`、`ResourceRepoListPackagesCore(...)`、`ResourceRepoSearchPackagesCore(...)`
- 不重开 package install/distributionflow

**Step 2: 最小化改写 repo**

- `GetPackageInfo(...)` / `ListPackages(...)` / `SearchPackages(...)` 收缩为 thin delegate
- `HasPackage(...)` 与 `InstallPackage(...)` 维持现状或只做薄整理

**Step 3: 跑 package checkpoint**

- `python3 -m unittest tests.test_package_manager_boundary -v`
- `tests/test_package_manager_installupdateflow.lpr`

Expected: 继续保持为绿，说明 package manager 当前不需要新切口。

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_resource_repo_boundary tests.test_package_manager_boundary -v`

Run: `mkdir -p /tmp/fpdev-resource-packagesurfaceflow-bin /tmp/fpdev-resource-packagesurfaceflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-packagesurfaceflow-bin -FU/tmp/fpdev-resource-packagesurfaceflow-lib tests/test_resource_repo_packagesurfaceflow.lpr`

Run: `bash -lc /tmp/fpdev-resource-packagesurfaceflow-bin/test_resource_repo_packagesurfaceflow`

Run: `mkdir -p /tmp/fpdev-resource-query-bin /tmp/fpdev-resource-query-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-query-bin -FU/tmp/fpdev-resource-query-lib tests/test_resource_repo_query.lpr`

Run: `bash -lc /tmp/fpdev-resource-query-bin/test_resource_repo_query`

Run: `mkdir -p /tmp/fpdev-package-installupdate-bin /tmp/fpdev-package-installupdate-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-installupdate-bin -FU/tmp/fpdev-package-installupdate-lib tests/test_package_manager_installupdateflow.lpr`

Run: `bash -lc /tmp/fpdev-package-installupdate-bin/test_package_manager_installupdateflow`
