# Package Resource Hotspot Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 联动削薄 `src/fpdev.package.manager.pas` 与 `src/fpdev.resource.repo.pas`，把 package 本地源码安装/依赖展示 与 resource repo mirror orchestration 下沉到 helper，继续压缩 manager/repo facade 的内联逻辑。

**Architecture:** `src/fpdev.package.manager.pas` 保留 builder、repo service、config 和 facade 入口；新增 `src/fpdev.package.managerflow.pas` 承接本地源码安装与 dependency list 输出。`src/fpdev.resource.repo.pas` 保留 manifest/load/install 入口；新增 `src/fpdev.resource.repo.mirrorflow.pas` 承接 best-mirror 选择与 mirror record 映射。两边都只做最小 helper 抽离，不重开 install/publish 主流程。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化本波 helper 边界

**Files:**
- Inspect: `src/fpdev.package.manager.pas`
- Inspect: `src/fpdev.resource.repo.pas`
- Reference: `src/fpdev.package.lifecycle.pas`
- Reference: `src/fpdev.resource.repo.mirror.pas`
- Reuse: `tests/test_package_manager_installupdateflow.lpr`
- Reuse: `tests/test_resource_repo_mirror.lpr`

**Step 1: 明确 package helper 公开符号**

- `ExecutePackageInstallFromSourceCore(...)`
- `BuildPackageDependencyLinesCore(...)`

**Step 2: 明确 resource helper 公开符号**

- `SelectResourceRepoBestMirrorCore(...)`
- `ConvertResourceRepoMirrorsCore(...)`

**Step 3: 锁定必须保持的行为**

- package 本地源码安装仍按 `prepare -> build -> metadata` 顺序执行
- prepare 失败时必须短路
- dependency list 顺序继续跟随 `ResolvePackageDependencyOrderCore(...)`
- mirror cache 命中时不重新测延迟
- mirror 选择继续回填 latency 数组并在异常时回退 primary URL
- `GetMirrors` 继续把 parsed mirror records 原样映射回 public `TMirrorArray`

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_package_manager_boundary.py`
- Create: `tests/test_resource_repo_boundary.py`
- Create: `tests/test_package_resource_flow.lpr`
- Reference: `tests/test_package_manager_installupdateflow.lpr`
- Reference: `tests/test_resource_repo_mirror.lpr`

**Step 1: 写 boundary 测试**

- package manager 必须引入 `fpdev.package.managerflow`
- `InstallPackageFromSource` 必须委托 `ExecutePackageInstallFromSourceCore(...)`
- `ShowPackageDependencies` 不再保留空循环
- resource repo 必须引入 `fpdev.resource.repo.mirrorflow`
- `SelectBestMirror` / `GetMirrors` 必须委托 mirror helper

**Step 2: 写 direct helper 测试**

- package install core 在 `Prepare...` 失败时返回 False 且不继续 build
- package install core 成功路径会调用 build 与 metadata writer
- dependency lines 对空依赖返回 empty，对非空依赖保留顺序
- mirror core 在 cache hit 时直接返回缓存值
- mirror core 在 manifest + candidate 成功时记录 latencies 并选择最优镜像
- mirror conversion 正确复制 `name/url/region/priority`

**Step 3: 运行测试确认 RED**

Run: `python3 -m unittest tests.test_package_manager_boundary tests.test_resource_repo_boundary -v`

Run: `mkdir -p /tmp/fpdev-package-resource-bin-red /tmp/fpdev-package-resource-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-resource-bin-red -FU/tmp/fpdev-package-resource-lib-red tests/test_package_resource_flow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 helper 尚不存在。

### Task 3: 实现 helper 并回接 facade

**Files:**
- Create: `src/fpdev.package.managerflow.pas`
- Create: `src/fpdev.resource.repo.mirrorflow.pas`
- Modify: `src/fpdev.package.manager.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: 实现 package helper**

- 只抽本地源码安装与 dependency list 输出
- 不重新打开 publish/install 主流程

**Step 2: 实现 resource mirror helper**

- 承接 cache/mirror candidate/latency/public mirror mapping
- repo 本体继续保留 manifest load、region callback、latency callback 与字段存储

**Step 3: 跑 focused verification**

Run: `python3 -m unittest tests.test_package_manager_boundary tests.test_resource_repo_boundary -v`

Run: `mkdir -p /tmp/fpdev-package-resource-bin /tmp/fpdev-package-resource-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-resource-bin -FU/tmp/fpdev-package-resource-lib tests/test_package_resource_flow.lpr`

Run: `bash -lc /tmp/fpdev-package-resource-bin/test_package_resource_flow`

Run: `mkdir -p /tmp/fpdev-package-installupdate-bin /tmp/fpdev-package-installupdate-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-installupdate-bin -FU/tmp/fpdev-package-installupdate-lib tests/test_package_manager_installupdateflow.lpr`

Run: `bash -lc /tmp/fpdev-package-installupdate-bin/test_package_manager_installupdateflow`

Run: `mkdir -p /tmp/fpdev-resource-mirror-bin /tmp/fpdev-resource-mirror-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-mirror-bin -FU/tmp/fpdev-resource-mirror-lib tests/test_resource_repo_mirror.lpr`

Run: `bash -lc /tmp/fpdev-resource-mirror-bin/test_resource_repo_mirror`

Expected: PASS
