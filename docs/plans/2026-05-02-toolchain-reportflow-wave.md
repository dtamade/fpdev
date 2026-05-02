# Toolchain Reportflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** Extract the remaining toolchain report/probe cluster from `src/fpdev.toolchain.pas` into a helper without reopening the already-closed `policyflow` seam or changing the report contract consumed by BuildManager strict preflight and CLI checks.

**Architecture:** Add `src/fpdev.toolchain.reportflow.pas` to own tool probing, repo/lazarus root detection, PATH splitting, zero-side-effect writability checks, and report JSON assembly. `src/fpdev.toolchain.pas` keeps the public facade (`BuildToolchainReportJSON`, `GetFPCVersion`, `CheckFPCVersionPolicy`) and continues delegating policy evaluation to `fpdev.toolchain.policyflow`.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the report/probe-only seam

**Files:**
- Inspect: `src/fpdev.toolchain.pas`
- Reuse: `tests/test_toolchain_boundary.py`
- Reuse: `tests/test_toolchain.lpr`
- Reuse: `tests/test_check_toolchain_sh.py`
- Reuse: `tests/test_check_toolchain_bat.py`
- Reuse: `docs/toolchain.md`

**Step 1: Lock the helper-owned cluster**

- tool probing / PATH / repo-root / lazarus-root / JSON report glue:
  - `SplitPathHead(...)`
  - `RunAndCaptureFirstLine(...)`
  - `ResolvePathOf(...)`
  - `ResolveRealPath(...)`
  - `IsLazarusRootDir(...)`
  - `DirIsWritableNoSideEffects(...)`
  - `ParentDirWritableNoSideEffects(...)`
  - `FindRepoRootFromDir(...)`
  - `ResolveRepoRootForToolchain(...)`
  - `ProbeRepoBuildOutput(...)`
  - `ProbeLazarusRoot(...)`
  - `AddTool(...)`
  - `AddIssue(...)`
  - `HasIssueContaining(...)`
  - `ProbeOne(...)`
  - `ProbeFirstAvailable(...)`
  - `ReportToJSON(...)`
  - `BuildToolchainReportJSON(...)` internals

**Step 2: Lock what stays in `fpdev.toolchain`**

- public facade shape:
  - `BuildToolchainReportJSON`
  - `GetFPCVersion`
  - `CheckFPCVersionPolicy`
- `CheckFPCVersionPolicy(...)` continues using `fpdev.toolchain.policyflow`

**Step 3: Record the stop condition**

- If extraction would force script behavior changes or a new shared public types unit, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write RED for boundary and helper behavior

**Files:**
- Modify: `tests/test_toolchain_boundary.py`
- Modify: `tests/test_temp_hygiene.py`
- Create: `tests/test_toolchain_reportflow.lpr`
- Create: `tests/test_toolchain_reportflow.lpi`

**Step 1: Extend Python boundary RED**

- Require `src/fpdev.toolchain.pas` implementation to import `fpdev.toolchain.reportflow`.
- Require `GetFPCVersion(...)` to delegate tool probing to helper.
- Require `BuildToolchainReportJSON(...)` to delegate report assembly to helper.
- Require inline report/probe helpers to leave `src/fpdev.toolchain.pas`.
- Keep policyflow delegation in place.

**Step 2: Add focused Pascal RED**

- helper splits PATH head deterministically.
- helper report uses repo-root override and lazarus-root override fixtures.
- helper marks `repo_bin_writable` / `repo_lib_writable` in JSON.
- helper elevates report level to `FAIL` when repo build outputs are not writable.
- helper `GetToolchainFPCVersionCore(...)` forwards `fpc -iV` through probe callback.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_toolchain_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_toolchain_reportflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and report/probe logic is still inline in `src/fpdev.toolchain.pas`.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.toolchain.reportflow.pas`
- Modify: `src/fpdev.toolchain.pas`

**Step 1: Move only the report/probe cluster**

- Add helper-owned probe/path/writability/report JSON functions.
- Add helper-owned callback-driven report builder for focused tests.
- Keep `fpdev.toolchain` public methods as thin delegates.

**Step 2: Preserve behavior**

- Preserve current report JSON shape from `docs/toolchain.md`.
- Preserve repo root override semantics via `FPDEV_TOOLCHAIN_REPO_ROOT`.
- Preserve lazarus root override semantics via `FPDEV_LAZARUSDIR`.
- Preserve `FAIL` escalation for missing fpc/make/lazarus_root or non-writable repo build outputs.
- Preserve optional treatment of `lazbuild`, `git`, and `openssl`.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_toolchain_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_toolchain_reportflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_toolchain.lpr
```

Run:
```bash
python3 -m unittest tests.test_check_toolchain_sh tests.test_check_toolchain_bat -v
```

Expected: all pass with toolchain report/probe delegated and policyflow behavior unchanged.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.toolchain.reportflow.pas src/fpdev.toolchain.pas tests/test_toolchain_boundary.py tests/test_temp_hygiene.py tests/test_toolchain_reportflow.lpr tests/test_toolchain_reportflow.lpi task_plan.md progress.md findings.md docs/plans/2026-05-02-toolchain-reportflow-wave.md
git commit -m "refactor(toolchain): extract reportflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader script/build-manager redesign
