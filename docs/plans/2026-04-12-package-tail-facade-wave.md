# Package Tail Facade Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 收口 `src/fpdev.package.manager.pas` 尾部 create/publish facade：继续复用现有 `facadeflow + creation + publishflow`，并把 manager 中仅为 callback 适配而存在的 metadata/publish wrapper 删掉，直接改为传递 core helper。

**Architecture:** `src/fpdev.package.facadeflow.pas` 已经承接 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade 编排；本波只调整 callback contract，使纯 helper callback 不再要求 object method，从而让 `src/fpdev.package.manager.pas` 直接把 `EnsurePackageMetadataFileCore(...)`、`TryResolvePublishMetadataCore(...)`、`HandlePublishMetadataFailureCore(...)`、`CreatePublishArchiveCore(...)` 传入 facadeflow。manager 保留有状态依赖与 install/query path callback，不重复包一层无状态 wrapper。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化 tail facade 切口

**Files:**
- Inspect: `src/fpdev.package.manager.pas`
- Inspect: `src/fpdev.package.facadeflow.pas`
- Inspect: `src/fpdev.package.creation.pas`
- Inspect: `src/fpdev.package.publishflow.pas`
- Reuse: `tests/test_package_facadeflow.lpr`
- Reuse: `tests/test_package_create.lpr`
- Reuse: `tests/test_package_metadata_writer.lpr`

**Step 1: 明确本波收口点**

- `CreatePackage(...)` 继续委托 `ExecutePackageCreateCore(...)`
- `PublishPackage(...)` 继续委托 `ExecutePackagePublishCore(...)`
- manager 不再声明：
  - `EnsurePackageMetadataFile(...)`
  - `ResolvePublishMetadata(...)`
  - `HandlePublishMetadataFailure(...)`
  - `CreatePublishArchive(...)`

**Step 2: 锁定必须保持的行为**

- create 仍保持 invalid-name / missing-source 错误文案
- create 仍保留 metadata created / already exists / next steps 输出
- publish 仍保留 not-installed exit code
- publish 仍保留 metadata failure -> exit code mapping
- publish archive 仍复用现有 publish dir / checksum / ready-to-publish 输出

### Task 2: 先写 RED 测试

**Files:**
- Create: `tests/test_package_tail_boundary.py`
- Modify: `tests/test_package_facadeflow.lpr`

**Step 1: 写 boundary 测试**

- 断言 `src/fpdev.package.manager.pas` 继续委托 `ExecutePackageCreateCore(...)` / `ExecutePackagePublishCore(...)`
- 断言 manager 不再声明上述 4 个纯 wrapper
- 断言 `CreatePackage(...)` 直接传 `@EnsurePackageMetadataFileCore`
- 断言 `PublishPackage(...)` 直接传 `@TryResolvePublishMetadataCore` / `@HandlePublishMetadataFailureCore` / `@CreatePublishArchiveCore`

**Step 2: 调整 direct helper 测试形成 RED**

- `tests/test_package_facadeflow.lpr` 对 create/publish callback contract 切到纯 function callback 形态
- 在 production code 变更前先运行，确认 compile error 或 contract mismatch

**Step 3: 运行测试确认 RED**

Run: `python3 -m unittest tests.test_package_tail_boundary -v`

Run: `mkdir -p /tmp/fpdev-package-facadeflow-bin-red /tmp/fpdev-package-facadeflow-lib-red`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-facadeflow-bin-red -FU/tmp/fpdev-package-facadeflow-lib-red tests/test_package_facadeflow.lpr`

Expected: Python suite FAIL 或 Pascal 编译失败，因为 manager 仍保留 wrapper / callback contract 尚未收紧。

### Task 3: 收紧 callback contract 并瘦身 manager

**Files:**
- Modify: `src/fpdev.package.facadeflow.pas`
- Modify: `src/fpdev.package.manager.pas`
- Modify: `tests/test_package_facadeflow.lpr`

**Step 1: 收紧 facadeflow callback 类型**

- 仅将纯 helper callback 改为 plain function type
- 保留需要 object state 的 package/path/install callback 为 object method

**Step 2: 删除 manager 纯 wrapper**

- 删除 4 个无状态 wrapper 声明与实现
- `CreatePackage(...)` / `PublishPackage(...)` 改为直接传 core helper

**Step 3: 跑 focused verification**

Run: `python3 -m unittest tests.test_package_tail_boundary -v`

Run: `mkdir -p /tmp/fpdev-package-facadeflow-bin /tmp/fpdev-package-facadeflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-facadeflow-bin -FU/tmp/fpdev-package-facadeflow-lib tests/test_package_facadeflow.lpr`

Run: `bash -lc /tmp/fpdev-package-facadeflow-bin/test_package_facadeflow`

Run: `mkdir -p /tmp/fpdev-package-create-bin /tmp/fpdev-package-create-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-create-bin -FU/tmp/fpdev-package-create-lib tests/test_package_create.lpr`

Run: `bash -lc /tmp/fpdev-package-create-bin/test_package_create`

Run: `mkdir -p /tmp/fpdev-package-metadata-writer-bin /tmp/fpdev-package-metadata-writer-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-package-metadata-writer-bin -FU/tmp/fpdev-package-metadata-writer-lib tests/test_package_metadata_writer.lpr`

Run: `bash -lc /tmp/fpdev-package-metadata-writer-bin/test_package_metadata_writer`

Expected: PASS.
