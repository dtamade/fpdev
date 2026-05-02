# Cross-Platform Release Proof Path Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stop hardcoding `bin/fpdev` and `bin/fpdev.exe` inside cross-platform CI smoke, owner-proof, and packaging steps by writing and consuming a reported built-binary path.

**Architecture:** Mirror the local `build_release.sh` truth surface inside the cross-platform CI lane. After each platform build, write the resolved executable path to a small path file via shared helper scripts; then make smoke, owner-proof, and packaging steps read that file instead of assuming a fixed output location.

**Tech Stack:** Bash, PowerShell, GitHub Actions, Python unittest

---

### Task 1: Add failing CI/path-parity contracts

**Files:**
- Modify: `tests/test_ci_workflow_contract.py`
- Modify: `tests/test_release_scripts_contract.py`
- Verify: `.github/workflows/ci.yml`

**Step 1: Write the failing test**

- Require a shared Unix helper script and a shared PowerShell helper script for reporting the built CLI binary path.
- Require the cross-platform workflow to stop inlining `./bin/fpdev` and `.\bin\fpdev.exe` in smoke/owner-proof/package steps.
- Require the workflow to read a path file before calling `cli_smoke` and `record_owner_smoke`.

**Step 2: Run test to verify it fails**

Run:
```bash
python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract -v
```

### Task 2: Add shared built-binary path reporters

**Files:**
- Create: `scripts/report_cli_binary_path.sh`
- Create: `scripts/report_cli_binary_path.ps1`

**Step 1: Write minimal implementation**

- `scripts/report_cli_binary_path.sh`
  - accept `<binary-path> <output-file>`
  - fail if binary path is empty
  - create parent directory for the output file
  - write the exact path as a single line
- `scripts/report_cli_binary_path.ps1`
  - accept `-ExecutablePath` and `-OutputFile`
  - mirror the same behavior on Windows

**Step 2: Run shell syntax / PowerShell shape checks**

Run:
```bash
bash -n scripts/report_cli_binary_path.sh
```

### Task 3: Wire CI smoke, owner-proof, and packaging to the path file

**Files:**
- Modify: `.github/workflows/ci.yml`

**Step 1: After each build, emit a path file**

- Unix lane: report `./bin/fpdev`
- Windows lane: report `.\bin\fpdev.exe`

**Step 2: Update consumers**

- `Run CLI smoke commands`
- `Run CLI smoke commands on Windows`
- `Record owner smoke transcript`
- `Record owner smoke transcript on Windows`
- `Package release asset`

All of them should read the emitted path file first instead of repeating a hardcoded path.

### Task 4: Verify and close

**Run:**
```bash
python3 -m unittest tests.test_ci_workflow_contract tests.test_release_scripts_contract tests.test_ci_release_contracts -v
```

**Run:**
```bash
bash -n scripts/report_cli_binary_path.sh
```

**Step 3: Commit**

```bash
git add .github/workflows/ci.yml scripts/report_cli_binary_path.sh scripts/report_cli_binary_path.ps1 tests/test_ci_workflow_contract.py tests/test_release_scripts_contract.py
git commit -m "fix(ci): share cross-platform built binary path reporting"
```
