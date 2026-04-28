# Lazarus Source Slicing Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.lazarus.source.pas`，先把 clone/update 的前置编排与共享判定下沉到新 `src/fpdev.lazarus.sourceflow.pas`，保持 legacy source manager 的外部行为不变。

**Architecture:** 本波只做最小高 ROI 切口：`TLazarusSourceManager` 继续持有 `FSourceRoot` / `FCurrentVersion` / `FFPCPath` / `FParallelJobs` 和控制台输出，但把 clone/update 共用的 version/source-path/ref/repository 解析、source tree preflight、make 参数构建收口到新的 `sourceflow` helper。先锁边界，再抽 helper，最后用现有 `tests/test_lazarus_update.lpr` 回归验证旧行为没有漂移。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Markdown docs

---

### Task 1: 固化最小切口与共享语义

**Files:**
- Inspect: `src/fpdev.lazarus.source.pas`
- Reference: `src/fpdev.lazarus.commandflow.pas`
- Reference: `tests/test_lazarus_update.lpr`
- Reference: `tests/test_lazarus_flow.lpr`

**Step 1: 明确本波只切 clone/update/helper，不重开 build/install 大手术**

锁定以下共享语义必须保持：
- 空版本参数：clone 默认 `main`，update 默认 `FCurrentVersion` 再回退 `main`
- clone ref 解析顺序：registry git_tag -> registry branch -> static fallback -> opaque version
- repository URL 优先来自 registry，否则回退 `LAZARUS_GIT_URL`
- source path 始终为 `FSourceRoot + '/lazarus-' + Version`
- invalid source dir 时 update 直接失败且不执行 pull
- clone 成功但目录缺少 `ide/lcl/packager` 时必须失败并保持 `FCurrentVersion` 不变

**Step 2: 记录本波 helper 公开符号**

计划新增：
- `TLazarusLegacySourceClonePlan`
- `TLazarusLegacySourceUpdatePlan`
- `ResolveLazarusLegacySourceVersionCore(...)`
- `BuildLazarusLegacySourcePathCore(...)`
- `CreateLazarusLegacyClonePlanCore(...)`
- `CreateLazarusLegacyUpdatePlanCore(...)`
- `BuildLazarusLegacyMakeParamsCore(...)`

### Task 2: 先写 boundary RED 测试

**Files:**
- Create: `tests/test_lazarus_source_boundary.py`

**Step 1: 写 failing boundary assertions**

边界测试必须锁住：
- `src/fpdev.lazarus.source.pas` 引入 `fpdev.lazarus.sourceflow`
- `CloneLazarusSource(...)` 调用 `CreateLazarusLegacyClonePlanCore(...)`
- `UpdateLazarusSource(...)` 调用 `CreateLazarusLegacyUpdatePlanCore(...)`
- `BuildLazarus(...)` 调用 `BuildLazarusLegacyMakeParamsCore(...)`
- `fpdev.lazarus.source.pas` 不再内联：
  - `Version := 'main'`
  - `SourcePath := GetSourcePath(Version)`
  - `SetLength(MakeParams, Length(MakeParams) + 1)` 那段组装逻辑

**Step 2: 跑 RED**

Run:
```bash
python3 -m unittest tests.test_lazarus_source_boundary -v
```
Expected: FAIL，因为 `fpdev.lazarus.sourceflow` 和对应委托还不存在。

### Task 3: 再写 direct helper RED 测试

**Files:**
- Create: `tests/test_lazarus_sourceflow.lpr`

**Step 1: 写 clone/update/build helper 断言**

至少覆盖：
- `ResolveLazarusLegacySourceVersionCore('', 'current', 'main') = 'current'`
- `ResolveLazarusLegacySourceVersionCore('', '', 'main') = 'main'`
- `BuildLazarusLegacySourcePathCore('/tmp/root', '3.0')` 生成 `/tmp/root/lazarus-3.0`
- `CreateLazarusLegacyClonePlanCore(...)` 保留 version/ref/repository/source path
- `CreateLazarusLegacyUpdatePlanCore(...)` 对空参数 follow `FCurrentVersion`
- `BuildLazarusLegacyMakeParamsCore(4, '')` 包含 `clean`,`all`,`-j4`
- `BuildLazarusLegacyMakeParamsCore(2, '/tmp/fpc')` 额外包含 `PP=/tmp/fpc`
- `BuildLazarusLegacyMakeParamsCore(1, '')` 保留 `clean`,`all`，且不额外注入 `-j1` / `PP=`

**Step 2: 跑 RED**

Run:
```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceflow-bin-red -FU/tmp/fpdev-lazarus-sourceflow-lib-red tests/test_lazarus_sourceflow.lpr
```
Expected: FAIL，提示找不到 `fpdev.lazarus.sourceflow` 或缺失 helper 符号。

### Task 4: 实现最小 helper 并收缩 source manager

**Files:**
- Create: `src/fpdev.lazarus.sourceflow.pas`
- Modify: `src/fpdev.lazarus.source.pas`

**Step 1: 在 helper 中实现纯逻辑**

`src/fpdev.lazarus.sourceflow.pas` 只放纯 helper：
- version fallback
- source path 构建
- clone/update plan record 初始化
- make 参数数组构建

不要在 helper 中放：
- `WriteLn`
- `CreateGitClient`
- `DirectoryExists` 删除动作
- `ExecuteCommand`
- `FCurrentVersion` 状态写入

**Step 2: 让 source manager 委托 helper**

在 `src/fpdev.lazarus.source.pas` 中：
- `CloneLazarusSource(...)` 通过 `CreateLazarusLegacyClonePlanCore(...)` 拿到 `Version/RefName/SourcePath/RepositoryURL`
- `UpdateLazarusSource(...)` 通过 `CreateLazarusLegacyUpdatePlanCore(...)` 拿到 `Version/SourcePath`
- `BuildLazarus(...)` 通过 `BuildLazarusLegacyMakeParamsCore(...)` 生成 `MakeParams`
- 保留所有原有输出文案、git 调用顺序、`FCurrentVersion` 更新时机和错误处理

### Task 5: Focused GREEN 验证

**Files:**
- Reuse: `tests/test_lazarus_source_boundary.py`
- Reuse: `tests/test_lazarus_sourceflow.lpr`
- Reuse: `tests/test_lazarus_update.lpr`
- Reuse: `tests/test_lazarus_flow.lpr`

**Step 1: 跑 boundary + direct helper**

Run:
```bash
python3 -m unittest tests.test_lazarus_source_boundary -v
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceflow-bin -FU/tmp/fpdev-lazarus-sourceflow-lib tests/test_lazarus_sourceflow.lpr
/tmp/fpdev-lazarus-sourceflow-bin/test_lazarus_sourceflow
```
Expected: PASS

**Step 2: 跑 legacy source focused suites**

Run:
```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr
/tmp/fpdev-lazarus-update-bin/test_lazarus_update
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-flow-bin -FU/tmp/fpdev-lazarus-flow-lib tests/test_lazarus_flow.lpr
/tmp/fpdev-lazarus-flow-bin/test_lazarus_flow
```
Expected: PASS

### Task 6: 全量回归并同步 planning files

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: 运行仓库基线**

Run:
```bash
bash scripts/run_all_tests.sh
```
Expected: PASS

**Step 2: 同步当前事实**

必须记录：
- `src/fpdev.lazarus.source.pas` 新的 helper 委托点
- `src/fpdev.lazarus.sourceflow.pas` 新增的纯逻辑职责
- 新增测试文件与 focused/full 验证结果
- 若本波只完成 clone/update/build params 而未继续切 install/build orchestration，也要明确写出这是“本波刻意停点”
