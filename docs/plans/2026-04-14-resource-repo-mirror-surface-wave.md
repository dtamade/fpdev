# Resource Repo Mirror Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.resource.repo.pas`，把 mirror 选择与镜像列表读取的 facade-level surface glue 下沉到 shared mirror helper，同时保持缓存、fallback 与错误处理语义不变。

**Architecture:** 复用已有 `src/fpdev.resource.repo.mirrorflow.pas`，不再新开重复 unit。现有 `SelectResourceRepoBestMirrorCore(...)` / `ConvertResourceRepoMirrorsCore(...)` 继续保留为纯逻辑；新增 surface helper 负责 `EnsureManifestLoaded`、candidate latency state 回填、cache 更新时间与 exception wrapper。`src/fpdev.resource.repo.pas` 保留 manifest state、字段 ownership 与 thin delegate。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 mirror surface 最小切口

**Files:**
- Inspect: `src/fpdev.resource.repo.pas`
- Inspect: `src/fpdev.resource.repo.mirrorflow.pas`
- Reuse: `tests/test_resource_repo_boundary.py`
- Reuse: `tests/test_package_resource_flow.lpr`

**Step 1: 锁定必须下沉的职责**

- `SelectBestMirror(...)` 中的 try/except、mirror-latency state 回填、cache 更新时间
- `GetMirrors(...)` 中的 manifest guard + exception wrapper

**Step 2: 锁定不改的边界**

- 不改 mirror candidate 选择算法
- 不改 region detect / latency test callback contract
- 不改 repository config/state ownership 字段

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_resource_repo_boundary.py`
- Create: `tests/test_resource_repo_mirrorsurfaceflow.lpr`

**Step 1: 扩展 boundary 契约**

- 断言 `SelectBestMirror(...)` 使用新的 mirror surface helper
- 断言 `GetMirrors(...)` 使用新的 mirror surface helper
- 断言 repo facade 不再内联 mirror latency 数组映射和 parsed-mirror try/except

**Step 2: 新增 direct helper RED**

- 为新的 mirror surface helper 写 callback probe：
  - manifest 已加载 / 未加载
  - cache-hit
  - fresh selection + state 回填
  - exception fallback

**Step 3: Run test to verify it fails**

Run:
```bash
python3 -m unittest tests.test_resource_repo_boundary -v
mkdir -p /tmp/fpdev-resource-mirror-surface-bin-red /tmp/fpdev-resource-mirror-surface-lib-red
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-mirror-surface-bin-red -FU/tmp/fpdev-resource-mirror-surface-lib-red tests/test_resource_repo_mirrorsurfaceflow.lpr
/tmp/fpdev-resource-mirror-surface-bin-red/test_resource_repo_mirrorsurfaceflow
```

Expected: FAIL，因为新的 surface helper 还不存在。

### Task 3: 实现 mirror surface helper 并回接 repository

**Files:**
- Modify: `src/fpdev.resource.repo.mirrorflow.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: 在 mirrorflow 中补 surface helper API**

- 新增 best-mirror surface helper
- 新增 get-mirrors surface helper
- helper 只接收 plain state + callbacks，不直接拥有 repository 对象

**Step 2: 收缩 repository facade**

- `SelectBestMirror(...)` 收缩为 thin delegate + state sync
- `GetMirrors(...)` 收缩为 thin delegate

### Task 4: Focused Verification

**Files:**
- Reuse: `tests/test_resource_repo_mirror.lpr`
- Reuse: `tests/test_package_resource_flow.lpr`

**Step 1: Run focused suites**

Run:
```bash
python3 -m unittest tests.test_resource_repo_boundary -v
mkdir -p /tmp/fpdev-resource-mirror-surface-bin /tmp/fpdev-resource-mirror-surface-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-mirror-surface-bin -FU/tmp/fpdev-resource-mirror-surface-lib tests/test_resource_repo_mirrorsurfaceflow.lpr
/tmp/fpdev-resource-mirror-surface-bin/test_resource_repo_mirrorsurfaceflow
mkdir -p /tmp/fpdev-resource-mirror-bin /tmp/fpdev-resource-mirror-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-resource-mirror-bin -FU/tmp/fpdev-resource-mirror-lib tests/test_resource_repo_mirror.lpr
/tmp/fpdev-resource-mirror-bin/test_resource_repo_mirror
mkdir -p /tmp/fpdev-package-resource-flow-bin /tmp/fpdev-package-resource-flow-lib
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-resource-flow-bin -FU/tmp/fpdev-package-resource-flow-lib tests/test_package_resource_flow.lpr
/tmp/fpdev-package-resource-flow-bin/test_package_resource_flow
```

Expected: PASS
