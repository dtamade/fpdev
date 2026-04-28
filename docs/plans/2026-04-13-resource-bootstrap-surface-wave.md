# Resource Bootstrap Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.resource.repo.pas`，把 bootstrap/install/checksum surface 收口到新的 helper，同时保持 package/query/mirror 既有 helper 不变。

**Architecture:** 新增 `src/fpdev.resource.repo.bootstrapflow.pas`，承接 best bootstrap selection、checksum verification、bootstrap install surface 与相邻 executable/log wiring。`src/fpdev.resource.repo.pas` 继续持有 repository state、manifest object、I/O logger 与 thin callback 装配，不再本地维护 bootstrap surface try/except 和 selection/log fan-out。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 resource bootstrap surface 边界

**Files:**
- Modify: `tests/test_resource_repo_boundary.py`

**Step 1: Write the failing test**

- 新增断言：
  - `src/fpdev.resource.repo.pas` 必须 `uses fpdev.resource.repo.bootstrapflow`
  - `FindBestBootstrapVersion(...)` 必须委托新 helper
  - `VerifyChecksum(...)` 必须委托新 helper
  - `InstallBootstrap(...)` 必须委托新 helper

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests.test_resource_repo_boundary -v`
Expected: FAIL on missing import/delegation

### Task 2: 给 bootstrap surface helper 写 direct RED 覆盖

**Files:**
- Create: `tests/test_resource_repo_bootstrapflow.lpr`

**Step 1: Write the failing test**

- 直接覆盖：
  - best bootstrap selection 会返回期望版本并收集 log lines
  - checksum helper 对空 checksum 直接成功
  - checksum helper 在 command 成功/失败时返回正确结果
  - bootstrap install surface 在 info 缺失时写错误并返回 false

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-bootstrapflow-bin-red -FU/tmp/fpdev-resource-bootstrapflow-lib-red tests/test_resource_repo_bootstrapflow.lpr`
Expected: FAIL with `Can't find unit fpdev.resource.repo.bootstrapflow`

### Task 3: 实现 bootstrap surface helper

**Files:**
- Create: `src/fpdev.resource.repo.bootstrapflow.pas`

**Step 1: Write minimal implementation**

- helper 承接：
  - bootstrap version selection + log fan-out
  - checksum command execution + mismatch/error logging
  - install bootstrap surface preflight / info resolve / helper dispatch

**Step 2: Keep scope tight**

- 不重拆 `bootstrapquery` / `install` / `mirrorflow` 已存在的低层 helper
- 不改 package/cross/binary surface

### Task 4: 收口 resource repository facade

**Files:**
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: Delegate target methods**

- 让以下方法变成 thin delegate：
  - `FindBestBootstrapVersion(...)`
  - `VerifyChecksum(...)`
  - `InstallBootstrap(...)`

**Step 2: Avoid regression**

- 保留 `BuildInstallContext(...)`、`Log(...)`、`LogFmt(...)` 和 manifest state ownership
- 不改 binary/cross/package surface 已有 helper wiring

### Task 5: 跑 focused 验证

**Files:**
- Reuse: `tests/test_resource_repo_bootstrap.lpr`
- Reuse: `tests/test_resource_repo_bootstrapquery.lpr`
- Reuse: `tests/test_resource_repo_package.lpr`

**Step 1: Verify focused suites**

Run:
- `python3 -m unittest tests.test_resource_repo_boundary -v`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-bootstrapflow-bin -FU/tmp/fpdev-resource-bootstrapflow-lib tests/test_resource_repo_bootstrapflow.lpr && bash -lc /tmp/fpdev-resource-bootstrapflow-bin/test_resource_repo_bootstrapflow`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-bootstrap-bin -FU/tmp/fpdev-resource-bootstrap-lib tests/test_resource_repo_bootstrap.lpr && bash -lc /tmp/fpdev-resource-bootstrap-bin/test_resource_repo_bootstrap`
- `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-bootstrapquery-bin -FU/tmp/fpdev-resource-bootstrapquery-lib tests/test_resource_repo_bootstrapquery.lpr && bash -lc /tmp/fpdev-resource-bootstrapquery-bin/test_resource_repo_bootstrapquery`

Expected: PASS
