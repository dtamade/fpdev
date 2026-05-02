# Lazarus Config Envoptions Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the repeated `environmentoptions.xml` set/get glue from `src/fpdev.lazarus.config.pas` into a helper without reopening backup/import/export/validate behavior.

**Architecture:** Add `src/fpdev.lazarus.config.envoptionsflow.pas` to own XML document load/save, node creation, and single-option read/write for `environmentoptions.xml`. `src/fpdev.lazarus.config.pas` keeps config-root ownership, file-path construction, backup/import/export, validation, and summary behavior.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the envoptions-only seam

**Files:**
- Inspect: `src/fpdev.lazarus.config.pas`
- Reuse: `tests/test_lazarus_ide_config.lpr`
- Reuse: `tests/test_lazarus_configure_workflow.lpr`
- Reuse: `tests/test_temp_hygiene.py`

**Step 1: Lock the helper-owned methods**

- `SetCompilerPath(...)` / `GetCompilerPath`
- `SetLibraryPath(...)` / `GetLibraryPath`
- `SetFPCSourcePath(...)` / `GetFPCSourcePath`
- `SetMakePath(...)` / `GetMakePath`
- `SetDebuggerPath(...)` / `GetDebuggerPath`
- `SetTargetOS(...)` / `GetTargetOS`
- `SetTargetCPU(...)` / `GetTargetCPU`

**Step 2: Lock what stays in `TLazarusIDEConfig`**

- `EnsureConfigDir`
- constructor-owned config paths
- `AddLibrarySearchPath`
- `ExportConfig` / `ImportConfig`
- `BackupConfig` / `RestoreConfig`
- `ValidateConfig` / `GetConfigSummary`

**Step 3: Record the stop condition**

- If extraction would require moving config-root ownership or broadening into backup/import/export logic, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write the RED boundary and focused envoptionsflow test

**Files:**
- Create: `tests/test_lazarus_config_boundary.py`
- Create: `tests/test_lazarus_config_envoptionsflow.lpr`
- Create: `tests/test_lazarus_config_envoptionsflow.lpi`

**Step 1: Add Python boundary RED**

- Require `src/fpdev.lazarus.config.pas` to import `fpdev.lazarus.config.envoptionsflow` only in implementation.
- Require all `environmentoptions.xml` setters/getters to delegate to helper calls.
- Require inline XML load/save and node-creation helpers to leave the class unit.

**Step 2: Add focused Pascal RED**

- Setter creates a fresh `environmentoptions.xml` when missing.
- Getter returns the stored value for a created node.
- Setter updates an existing node without losing stored value semantics.
- Getter returns empty when the file or target node is missing.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_lazarus_config_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_lazarus_config_envoptionsflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and XML envoptions logic is still inline in `TLazarusIDEConfig`.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.lazarus.config.envoptionsflow.pas`
- Modify: `src/fpdev.lazarus.config.pas`

**Step 1: Move only envoptions XML glue**

- Add helper-owned single-option read/write functions for `environmentoptions.xml`.
- Keep `TLazarusIDEConfig` as the public entrypoint and config-path owner.
- Keep backup/import/export and validation behavior in the class unit.

**Step 2: Preserve behavior**

- Preserve `CONFIG` root creation when the file does not exist.
- Preserve `EnvironmentOptions` section usage.
- Preserve empty-string behavior when the file or node is missing.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_lazarus_config_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_lazarus_config_envoptionsflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_lazarus_ide_config.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_lazarus_configure_workflow.lpr
```

Expected: all pass with `TLazarusIDEConfig` ownership intact and envoptions XML glue delegated.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.lazarus.config.envoptionsflow.pas src/fpdev.lazarus.config.pas tests/test_lazarus_config_boundary.py tests/test_lazarus_config_envoptionsflow.lpr tests/test_lazarus_config_envoptionsflow.lpi task_plan.md progress.md findings.md
git commit -m "refactor(lazarus-config): extract envoptionsflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader Lazarus config redesign
