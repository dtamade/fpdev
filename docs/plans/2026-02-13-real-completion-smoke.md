# FPDev "Real Completion" Smoke Acceptance Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prove FPDev is shippable from a clean environment by running real smoke tests across core commands (build, tests, doctor/self-test, fpc/cross/lazarus/package/project), then fix any blocking issues found.

**Architecture:** Treat this as an acceptance pass on the CLI contract. Run repo-wide scans for obvious gaps (TODOs/stubs), verify build/test toolchain, then run CLI smoke in an isolated `HOME`/`FPDEV_DATA_ROOT`. For any failing smoke item, follow strict TDD: add a regression test first, reproduce RED, implement the minimal fix, re-run GREEN, then full VERIFY.

**Tech Stack:** Free Pascal (objfpc), Lazarus (`lazbuild`), fpcunit tests, shell scripts in `scripts/`, CLI dispatch via `fpdev.command.registry`.

---

### Task 1: Repo-Wide Gap Scan (No Code Changes)

**Files:**
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Scan for obvious stubs / TODOs**

Run:
```bash
cd <repo-root>
rg -n "\\b(TODO|FIXME|HACK|XXX)\\b" src tests docs || true
rg -n "not (yet )?implemented" -S src tests docs || true
```

Expected:
- Document any remaining intentional "not implemented" areas (esp. cross/binary install) in `findings.md`.

**Step 2: Check host toolchain prerequisites**

Run:
```bash
cd <repo-root>
bash scripts/check_toolchain.sh
```

Expected:
- Non-zero is acceptable if it reports missing optional cross tools; record the missing list.

**Step 3: Baseline build + unit tests**

Run:
```bash
cd <repo-root>
lazbuild -B fpdev.lpi
bash scripts/run_all_tests.sh
```

Expected:
- Build exits `0`
- Tests all pass

**Step 4: CLI smoke in isolated HOME/data root**

Run:
```bash
cd <repo-root>
python3 /tmp/fpdev_cli_smoke.py
```

Expected:
- No timeouts
- Any non-zero exits are investigated; fix P0 items that should work in a clean environment.

---

### Task 2 (P0): Make `fpdev fpc test` Smoke-Friendly With No Default Toolchain

**Files:**
- Modify: `tests/test_command_registry.lpr`
- Modify: `src/fpdev.cmd.fpc.test.pas`

**Step 1: Write the failing test (RED)**
- Add a regression test: in a clean config with no default toolchain, `fpdev fpc test` should fall back to testing the system `fpc` in `PATH` and exit `0`.

**Step 2: Run the focused test to verify it fails**

Run:
```bash
cd <repo-root>
FPDEV_DATA_ROOT=/tmp/fpdev-tests-manual/data FPDEV_LAZARUS_CONFIG_ROOT=/tmp/fpdev-tests-manual/lazarus-config \
  fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_command_registry.lpr && ./bin/test_command_registry
```

Expected:
- FAIL on the new assertion (`fpc test` currently exits `2` when no default toolchain).

**Step 3: Implement minimal fallback behavior (GREEN)**
- In `src/fpdev.cmd.fpc.test.pas`, when no version is provided and no default toolchain is set:
  - Try to locate `fpc` via `TProcessExecutor.FindExecutable('fpc')`
  - Run `fpc -i` (or `-iV`) as a fast "system FPC is runnable" check
  - Print a stable message like `Testing system FPC` and exit `0` on success
  - If no system `fpc` exists, print a clear error and exit non-zero

**Step 4: Re-run the focused test**

Run:
```bash
cd <repo-root>
FPDEV_DATA_ROOT=/tmp/fpdev-tests-manual/data FPDEV_LAZARUS_CONFIG_ROOT=/tmp/fpdev-tests-manual/lazarus-config \
  fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_command_registry.lpr && ./bin/test_command_registry
```

Expected:
- PASS

**Step 5: Full verification**

Run:
```bash
cd <repo-root>
lazbuild -B fpdev.lpi
bash scripts/run_all_tests.sh
python3 /tmp/fpdev_cli_smoke.py
```

Expected:
- Smoke shows `ok: 35 fail: 0 timeout: 0`

---

### Task 3: Report Acceptance + Remaining External Prereqs

**Files:**
- Modify: `progress.md`

**Step 1: Capture final outputs and status**
- Record:
  - `check_toolchain.sh` missing tools list (if any)
  - `run_all_tests.sh` summary
  - `lazbuild` exit code
  - `fpdev_cli_smoke.py` summary

**Step 2: State what is "done" vs "blocked by environment"**
- Cross compilation execution is gated by host toolchain availability; dry-run/doctor should remain usable regardless.
