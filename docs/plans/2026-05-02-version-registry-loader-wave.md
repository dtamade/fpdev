# Version Registry Loader Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the reload/json/default loading surface from `src/fpdev.version.registry.pas` into an internal helper while keeping the singleton/query API stable.

**Architecture:** Add `src/fpdev.version.registry.loadflow.pas` to own search-path scan, JSON section parsing, bootstrap-map parsing, and embedded-default composition. `src/fpdev.version.registry.pas` keeps instance lifecycle, mutable state ownership, and public query methods such as `GetFPCRelease(...)`, `GetLazarusRelease(...)`, and `GetBootstrapVersion(...)`. This wave must not widen the public surface or rewrite downstream consumers.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the loader/default seam

**Files:**
- Inspect: `src/fpdev.version.registry.pas`
- Reuse: `tests/test_fpc_version.lpr`
- Reuse: `tests/test_fpc_indexflow.lpr`
- Reuse: `tests/test_lazarus_catalogflow.lpr`
- Reuse: `tests/test_fpc_source_repo.lpr`

**Step 1: Lock the seam**

- `Reload(...)` should become search-path orchestration plus helper delegation.
- `LoadFromJSON(...)`, `LoadDefaults`, `ParseFPCReleases(...)`, `ParseLazarusReleases(...)`, and `ParseBootstrapMap(...)` are helper-owned candidates.
- `Instance`, `ReleaseInstance`, and all public query methods remain in `src/fpdev.version.registry.pas`.

**Step 2: Lock the no-change boundary**

- Do not rename `TVersionRegistry`.
- Do not change record shapes for `TFPCReleaseInfo` / `TLazarusReleaseInfo`.
- Do not move singleton locking or `DataPath` ownership out of the registry class.

### Task 2: Write the RED boundary and direct-helper test

**Files:**
- Create: `tests/test_version_registry_boundary.py`
- Create: `tests/test_version_registry_loadflow.lpr`

**Step 1: Add Python boundary RED**

- Require `src/fpdev.version.registry.pas` to import `fpdev.version.registry.loadflow`.
- Require `Reload(...)` to delegate loader/default composition through the helper.
- Require inline JSON parse methods to leave `src/fpdev.version.registry.pas`.
- Require the public registry unit to remain the only public surface.

**Step 2: Add focused Pascal RED**

- Cover first-existing search path selection.
- Cover JSON parsing of FPC releases, Lazarus releases, and bootstrap map.
- Cover fallback to embedded defaults when no valid JSON file exists.
- Cover preservation of `SchemaVersion`, `UpdatedAt`, repositories, and default versions.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_version_registry_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_version_registry_loadflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and the registry still owns inline parsing/default logic.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.version.registry.loadflow.pas`
- Modify: `src/fpdev.version.registry.pas`

**Step 1: Add helper-owned APIs**

- Add a minimal result/state carrier for parsed version-registry data.
- Move JSON section parsing and embedded-default composition into the helper.
- Keep `Reload(...)` as the class-owned entrypoint that assigns helper output back into registry state.

**Step 2: Keep downstream contracts stable**

- Preserve current fallback order for `DataPath`.
- Preserve bootstrap fallback-chain semantics.
- Preserve repository fallback to `FPC_OFFICIAL_REPO` and `LAZARUS_OFFICIAL_REPO`.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_version_registry_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_version_registry_loadflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_version.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_indexflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_lazarus_catalogflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_source_repo.lpr
```

Expected: all pass with `src/fpdev.version.registry.pas` reduced to singleton/query ownership.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.version.registry.loadflow.pas src/fpdev.version.registry.pas tests/test_version_registry_boundary.py tests/test_version_registry_loadflow.lpr task_plan.md progress.md findings.md
git commit -m "refactor(version-registry): extract loadflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without forcing a broader registry rewrite
