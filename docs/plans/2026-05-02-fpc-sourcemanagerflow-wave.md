# FPC Sourcemanagerflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** Extract the private build-manager bridge and cache-marker cluster from `src/fpdev.fpc.source.pas` into a callback-driven helper, without reopening the already-closed `sourceflow` / `sourcebuildflow` / `sourceinstallflow` / `sourcebootstrapflow` seams.

**Architecture:** Add `src/fpdev.fpc.sourcemanagerflow.pas` to own create/execute/free orchestration for build-manager-backed private steps and cache-marker persistence. `src/fpdev.fpc.source.pas` keeps `CreateBuildManager(...)`, low-level build-manager configuration, source-root/state ownership, and the existing public facade/install/build flows.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the manager-bridge-only seam

**Files:**
- Inspect: `src/fpdev.fpc.source.pas`
- Reuse: `src/fpdev.fpc.sourcebuildflow.pas`
- Reuse: `tests/test_fpc_source_boundary.py`
- Reuse: `tests/test_fpc_sourcebuildflow.lpr`
- Reuse: `tests/test_fpc_sourceinstallflow.lpr`

**Step 1: Lock the helper-owned cluster**

- build-manager create/execute/free bridge:
  - `BuildCompilerWithManager(...)`
  - `BuildRTLWithManager(...)`
  - `BuildPackagesWithManager(...)`
  - `InstallBinariesWithManager(...)`
  - `ConfigureEnvironmentWithManager(...)`
  - `TestBuildResultsWithManager(...)`
- cache marker persistence:
  - `WriteCacheMarker(...)`

**Step 2: Lock what stays in `fpdev.fpc.source`**

- `CreateBuildManager(...)`
- `ExecuteCommand(...)`
- `BuildFPCCompiler(...)` / `BuildFPCRTL(...)` / `BuildFPCPackages(...)`
- `InstallFPCBinaries(...)` / `ConfigureFPCEnvironment(...)` / `TestBuildResults(...)`
- `sourceflow` / `sourcebuildflow` / `sourceinstallflow` / `sourcebootstrapflow` wiring

**Step 3: Record the stop condition**

- If extraction would require real `TBuildManager` execution in direct tests or would reopen public build/install steps, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write RED for boundary and helper behavior

**Files:**
- Modify: `tests/test_fpc_source_boundary.py`
- Modify: `tests/test_temp_hygiene.py`
- Create: `tests/test_fpc_sourcemanagerflow.lpr`
- Create: `tests/test_fpc_sourcemanagerflow.lpi`

**Step 1: Extend Python boundary RED**

- Require `src/fpdev.fpc.source.pas` to import `fpdev.fpc.sourcemanagerflow`.
- Require all `*WithManager(...)` private methods to delegate to callback-driven helper execution.
- Require `WriteCacheMarker(...)` to delegate cache file persistence to helper.
- Keep `CreateBuildManager(...)` and the public managed-build wrappers in the main unit.

**Step 2: Add focused Pascal RED**

- helper creates manager with the expected `AllowInstall` flag.
- helper forwards version to execute callback and always frees the manager.
- helper returns false when manager creation fails.
- cache marker helper writes `version=` and `built_at=` lines under `<sourceRoot>/cache/`.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_fpc_source_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_sourcemanagerflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and `src/fpdev.fpc.source.pas` still owns the bridge inline.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.fpc.sourcemanagerflow.pas`
- Modify: `src/fpdev.fpc.source.pas`

**Step 1: Move only bridge/persistence glue**

- Add helper-owned callback-driven create/execute/free orchestration.
- Add helper-owned cache-marker file write.
- Keep `TFPCSourceManager` methods as thin delegates so class structure and public flow wiring stay stable.

**Step 2: Preserve behavior**

- Preserve `AllowInstall=False` for compiler/rtl/packages steps.
- Preserve `AllowInstall=True` for install/configure/test-results steps.
- Preserve cache-marker path shape: `<sourceRoot>/cache/fpc-<version>.cache`.
- Preserve best-effort timestamp line in cache marker.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_fpc_source_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_sourcemanagerflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_sourcebuildflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_sourceinstallflow.lpr
```

Expected: all pass with bridge/persistence delegated and existing source/build/install behavior unchanged.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.fpc.sourcemanagerflow.pas src/fpdev.fpc.source.pas tests/test_fpc_source_boundary.py tests/test_temp_hygiene.py tests/test_fpc_sourcemanagerflow.lpr tests/test_fpc_sourcemanagerflow.lpi task_plan.md progress.md findings.md docs/plans/2026-05-02-fpc-sourcemanagerflow-wave.md
git commit -m "refactor(fpc-source): extract sourcemanagerflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader `fpc.source` / `build.manager` redesign
