# Toolchain Policyflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** Extract the FPC policy/version-decision cluster from `src/fpdev.toolchain.pas` into a helper without widening into the repo-root / lazarus-root / tool probing report surface.

**Architecture:** Add `src/fpdev.toolchain.policyflow.pas` to own policy JSON loading, alias/prefix matching, version normalization/comparison, and source-version policy evaluation. `src/fpdev.toolchain.pas` keeps process probing (`GetFPCVersion`) and the `BuildToolchainReportJSON` host-health report.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the policy-only seam

**Files:**
- Inspect: `src/fpdev.toolchain.pas`
- Reuse: `tests/test_toolchain.lpr`
- Reuse: `tests/test_cli_fpc_policy.lpr`
- Reuse: `tests/test_check_toolchain_sh.py`
- Reuse: `tests/test_check_toolchain_bat.py`

**Step 1: Lock the helper-owned cluster**

- policy JSON loading:
  - `LoadPolicyFromFile(...)`
  - `LoadPolicyAuto(...)`
- policy lookup:
  - `GetExternalPolicy(...)`
  - `GetPolicyForSource(...)`
- version normalization/comparison:
  - `NormalizeVersion(...)`
  - `CmpVersion(...)`
- final policy evaluation inside `CheckFPCVersionPolicy(...)`

**Step 2: Lock what stays in `fpdev.toolchain`**

- `BuildToolchainReportJSON(...)`
- `GetFPCVersion(...)`
- PATH / lazarus-root / repo-root probing helpers
- JSON report assembly

**Step 3: Record the stop condition**

- If extraction would force repo-root writable probes, lazarus-root probing, or report JSON building into the same helper, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write the RED boundary and focused policyflow test

**Files:**
- Create: `tests/test_toolchain_boundary.py`
- Create: `tests/test_toolchain_policyflow.lpr`
- Create: `tests/test_toolchain_policyflow.lpi`
- Modify: `tests/test_temp_hygiene.py`

**Step 1: Add Python boundary RED**

- Require `src/fpdev.toolchain.pas` implementation to import `fpdev.toolchain.policyflow`.
- Require `CheckFPCVersionPolicy(...)` to delegate to a helper-owned evaluation function.
- Require inline policy helpers and policy globals to leave `src/fpdev.toolchain.pas`.
- Keep `GetFPCVersion(...)` and `BuildToolchainReportJSON(...)` in the main unit.

**Step 2: Add focused Pascal RED**

- env policy auto-load honors `FPDEV_POLICY_FILE`
- exact-version rule wins over prefix rule
- `main` / `trunk` alias matching stays intact
- version compare strips suffix labels and compares numerically
- built-in fallback still returns `WARN` / `FAIL` correctly

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_toolchain_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_toolchain_policyflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and policy/version logic is still inline in `src/fpdev.toolchain.pas`.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.toolchain.policyflow.pas`
- Modify: `src/fpdev.toolchain.pas`

**Step 1: Move only policy/version-decision glue**

- Add helper-owned policy state reset/load/lookup functions.
- Add helper-owned version normalization/comparison.
- Add helper-owned policy evaluation from `(source-version, current-fpc-version)`.
- Keep `GetFPCVersion(...)` in the main unit and let it feed the helper.

**Step 2: Preserve behavior**

- Preserve `FPDEV_POLICY_FILE` priority.
- Preserve `main` / `trunk` alias behavior.
- Preserve built-in conservative fallback when no external policy loads.
- Preserve CLI/public API surface of `fpdev.toolchain`.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_toolchain_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_toolchain_policyflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_toolchain.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cli_fpc_policy.lpr
```

Run:
```bash
python3 -m unittest tests.test_check_toolchain_sh tests.test_check_toolchain_bat -v
```

Expected: all pass with policyflow delegated and report/probe logic still owned by `fpdev.toolchain`.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.toolchain.policyflow.pas src/fpdev.toolchain.pas tests/test_toolchain_boundary.py tests/test_toolchain_policyflow.lpr tests/test_toolchain_policyflow.lpi tests/test_temp_hygiene.py task_plan.md progress.md findings.md docs/plans/2026-05-02-toolchain-policyflow-wave.md
git commit -m "refactor(toolchain): extract policyflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader toolchain/report redesign
