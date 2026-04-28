# Lazarus Source Versionflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** 继续削薄 `src/fpdev.lazarus.source.pas`，把 legacy source manager 中 registry/static version resolution、description fallback、branch readback 和 available-version inventory 下沉到 shared helper。

**Architecture:** 新增 `src/fpdev.lazarus.sourceversionflow.pas`，承接以下纯逻辑：registry 是否 authoritative、static fallback 查找、 clone ref 解析、 branch -> version readback、description 解析、available version list 构建。`src/fpdev.lazarus.source.pas` 保留 git runtime、目录扫描、输出和安装/build orchestration。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 固化最小切口

**Files:**
- Inspect: `src/fpdev.lazarus.source.pas`
- Reuse: `tests/test_lazarus_update.lpr`
- Reuse: `tests/test_lazarus_source_boundary.py`

**Step 1: helper 公开符号**

- `RegistryHasLazarusReleasesCore(...)`
- `ResolveLegacyLazarusCloneRefCore(...)`
- `ResolveLegacyLazarusDescriptionCore(...)`
- `ResolveLegacyLazarusVersionFromBranchCore(...)`
- `BuildLegacyLazarusAvailableVersionsCore(...)`

**Step 2: 锁定必须保持的行为**

- registry 有 releases 时，static-only version/branch/description 继续保持 opaque
- registry 为空时，继续回退 `LAZARUS_VERSIONS`
- `ListAvailableVersions(...)` 继续去重
- `GetVersionFromBranch(...)` 继续支持 git_tag / branch / static branch

### Task 2: 先写 RED 测试

**Files:**
- Modify: `tests/test_lazarus_source_boundary.py`
- Create: `tests/test_lazarus_sourceversionflow.lpr`

**Step 1: boundary**

- `src/fpdev.lazarus.source.pas` 必须引入 `fpdev.lazarus.sourceversionflow`
- `GetVersionFromBranch(...)` 必须调用 `ResolveLegacyLazarusVersionFromBranchCore(...)`
- `ListAvailableVersions(...)` 必须调用 `BuildLegacyLazarusAvailableVersionsCore(...)`
- `GetLazarusVersion(...)` 必须调用 `ResolveLegacyLazarusDescriptionCore(...)`
- `src/fpdev.lazarus.source.pas` 不再本地定义 `FindStaticLazarusVersionIndex(...)` / `FindStaticLazarusBranchIndex(...)`

**Step 2: direct helper**

- registry authoritative 时，static-only version description 保持 opaque
- registry empty 时，static description / branch mapping 继续生效
- available version helper 去重且遵守 registry precedence

### Task 3: 实现 helper 并回接 source

**Files:**
- Create: `src/fpdev.lazarus.sourceversionflow.pas`
- Modify: `src/fpdev.lazarus.source.pas`

**Step 1: focused verification**

Run: `python3 -m unittest tests.test_lazarus_source_boundary -v`

Run: `mkdir -p /tmp/fpdev-lazarus-sourceversionflow-bin /tmp/fpdev-lazarus-sourceversionflow-lib`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-sourceversionflow-bin -FU/tmp/fpdev-lazarus-sourceversionflow-lib tests/test_lazarus_sourceversionflow.lpr`

Run: `/tmp/fpdev-lazarus-sourceversionflow-bin/test_lazarus_sourceversionflow`

Run: `fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-lazarus-update-bin -FU/tmp/fpdev-lazarus-update-lib tests/test_lazarus_update.lpr`

Run: `/tmp/fpdev-lazarus-update-bin/test_lazarus_update`
