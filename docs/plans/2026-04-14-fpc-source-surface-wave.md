# FPC Source Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.fpc.source.pas`，把 source install/bootstrap/build/cache 这组仍然厚重的 orchestration 下沉到 shared helper，保持 `TFPCSourceManager` 只做 facade、状态字段持有与 callback/依赖装配。

**Architecture:** 以最小风险拆成三块 helper：`sourceinstallflow` 负责 `InstallFPCVersion(...)` 的总编排，`sourcebootstrapflow` 负责 bootstrap compiler acquisition/ensure，`sourcebuildflow` 负责 build pipeline + cache 判定。`src/fpdev.fpc.source.pas` 继续保留 `FSourceRoot` / `FCurrentVersion` / `FBootstrapCompiler` / `FCurrentStep`、`CreateBuildManager(...)`、`ExecuteCommand(...)` 与现有 low-level path/state helper。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定 boundary 与 direct RED

**Files:**
- Create: `tests/test_fpc_source_boundary.py`
- Create: `tests/test_fpc_sourceinstallflow.lpr`
- Create: `tests/test_fpc_sourcebootstrapflow.lpr`
- Create: `tests/test_fpc_sourcebuildflow.lpr`
- Reuse: `tests/test_fpc_source_repo.lpr`
- Reuse: `tests/test_bootstrap_downloader.lpr`

**Step 1: 写 boundary 测试**

- `src/fpdev.fpc.source.pas` 必须引入：
  - `fpdev.fpc.sourceinstallflow`
  - `fpdev.fpc.sourcebootstrapflow`
  - `fpdev.fpc.sourcebuildflow`
- `InstallFPCVersion(...)` 必须委托 install helper
- `DownloadBootstrapCompilerInternal(...)` / `EnsureBootstrapCompiler(...)` 必须委托 bootstrap helper
- `BuildFPCSource(...)`、`BuildFPCCompiler(...)`、`BuildFPCRTL(...)`、`BuildFPCPackages(...)`、`InstallFPCBinaries(...)`、`ConfigureFPCEnvironment(...)`、`TestBuildResults(...)`、`IsCacheAvailable(...)`、`UseCachedBuild(...)` 必须委托 build/cache helper

**Step 2: 写 direct helper 测试**

- install helper：
  - initialize/bootstrap/clone/build/cache/complete 路径顺序
  - cached build success path
  - cached build validate failure path
  - failure rollback to previous version
- bootstrap helper：
  - system compiler compatible short-circuit
  - downloaded bootstrap short-circuit
  - download success path
  - download failure path
- build/cache helper：
  - invalid source dir rejected
  - build manager callbacks invoked
  - cache metadata mismatch rejected
  - cache artifact presence accepted

**Step 3: 跑 RED**

Run: `python3 -m unittest tests.test_fpc_source_boundary -v`

Run:
`fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-sourceinstallflow-bin-red -FU/tmp/fpdev-fpc-sourceinstallflow-lib-red tests/test_fpc_sourceinstallflow.lpr`

Run:
`fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-sourcebootstrapflow-bin-red -FU/tmp/fpdev-fpc-sourcebootstrapflow-lib-red tests/test_fpc_sourcebootstrapflow.lpr`

Run:
`fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-fpc-sourcebuildflow-bin-red -FU/tmp/fpdev-fpc-sourcebuildflow-lib-red tests/test_fpc_sourcebuildflow.lpr`

Expected: boundary fail 或 helper compile fail，因为新 helper 尚不存在。

### Task 2: 实现 sourceinstallflow

**Files:**
- Create: `src/fpdev.fpc.sourceinstallflow.pas`
- Modify: `src/fpdev.fpc.source.pas`

**Step 1: 写最小 install surface helper**

- helper 只负责：
  - step sequencing
  - previous-version rollback
  - cache hit decision branch
  - success finish marker
- helper 不负责：
  - HTTP 下载细节
  - BuildManager 具体调用
  - metadata file具体读写

**Step 2: 改写 manager facade**

- `InstallFPCVersion(...)` 改为 single delegate + callback wiring

### Task 3: 实现 sourcebootstrapflow + sourcebuildflow

**Files:**
- Create: `src/fpdev.fpc.sourcebootstrapflow.pas`
- Create: `src/fpdev.fpc.sourcebuildflow.pas`
- Modify: `src/fpdev.fpc.source.pas`

**Step 1: bootstrap helper**

- 承接：
  - required-version resolve
  - system/downloaded bootstrap probe
  - download/extract/cleanup 编排

**Step 2: build/cache helper**

- 承接：
  - `BuildFPCSource(...)`
  - `BuildFPCCompiler(...)`
  - `BuildFPCRTL(...)`
  - `BuildFPCPackages(...)`
  - `InstallFPCBinaries(...)`
  - `ConfigureFPCEnvironment(...)`
  - `TestBuildResults(...)`
  - `IsCacheAvailable(...)`
  - `UseCachedBuild(...)`

### Task 4: Focused Verification

Run: `python3 -m unittest tests.test_fpc_source_boundary -v`

Run all new helper suites:
- `tests/test_fpc_sourceinstallflow.lpr`
- `tests/test_fpc_sourcebootstrapflow.lpr`
- `tests/test_fpc_sourcebuildflow.lpr`

Run focused regression:
- `tests/test_fpc_source_repo.lpr`
- `tests/test_bootstrap_downloader.lpr`

Expected: 全部通过。
