# Cross Downloader Verificationflow Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the verification-specific surface from `src/fpdev.cross.downloader.pas` into a helper without reopening manifest refresh or download/install orchestration.

**Architecture:** Add `src/fpdev.cross.verifyflow.pas` to own required-binary verification, `ld --version` probing, verification metadata writeback, and JSON reload for existing metadata files. `src/fpdev.cross.downloader.pas` keeps manifest loading, host detection, toolchain selection, download/install operations, and state ownership for `FManifest`, `FCache`, `FOptions`, and `FLastError`.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the verification-only seam

**Files:**
- Inspect: `src/fpdev.cross.downloader.pas`
- Reuse: `tests/test_cross_downloader.lpr`
- Reuse: `tests/test_cli_cross.lpr`
- Reuse: `tests/test_temp_hygiene.py`

**Step 1: Lock the helper-owned methods**

- `VerifyInstallation(...)`
- `ExecuteVersionCheck(...)`
- `UpdateVerificationMetadata(...)`
- `LoadJSONFromFile(...)`

**Step 2: Lock what stays in the downloader**

- `LoadManifest`, `RefreshManifest`
- `DetectHostPlatform`
- `SelectToolchainVariant`
- `DownloadBinutils`, `DownloadLibraries`, `InstallToolchain`

**Step 3: Record the stop condition**

- If verification cannot be extracted without moving manifest-refresh or downloader state ownership, stop and record a no-go checkpoint instead of broadening the wave.

### Task 2: Write the RED boundary and focused verifyflow test

**Files:**
- Create: `tests/test_cross_downloader_boundary.py`
- Create: `tests/test_cross_verifyflow.lpr`

**Step 1: Add Python boundary RED**

- Require `src/fpdev.cross.downloader.pas` to import `fpdev.cross.verifyflow`.
- Require `VerifyInstallation(...)` to delegate verification orchestration to the helper.
- Require version probing and metadata writeback helpers to leave the downloader unit.
- Keep manifest refresh and target selection in the downloader unit.

**Step 2: Add focused Pascal RED**

- Missing binaries are collected and reported together.
- Version probe returns the first line of `--version` output.
- Metadata writer creates a new JSON file when none exists.
- Metadata writer recovers from invalid existing JSON by recreating a valid object.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_cross_downloader_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cross_verifyflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and verification logic is still inline on the downloader.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.cross.verifyflow.pas`
- Modify: `src/fpdev.cross.downloader.pas`

**Step 1: Move only verification glue**

- Add helper-owned verification functions that accept downloader-provided callbacks or pre-resolved inputs.
- Keep public `TCrossToolchainDownloader.VerifyInstallation(...)` as the class-owned entrypoint.
- Keep `FLastError` and manifest ownership inside the downloader.

**Step 2: Preserve behavior**

- Preserve target-prefix mapping for required binaries.
- Preserve optional version-probe semantics when execution fails.
- Preserve metadata file path `.fpdev-cross-meta.json`.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_cross_downloader_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cross_verifyflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cross_downloader.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cli_cross.lpr
```

Expected: all pass with downloader ownership intact and verification glue delegated.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.cross.verifyflow.pas src/fpdev.cross.downloader.pas tests/test_cross_downloader_boundary.py tests/test_cross_verifyflow.lpr task_plan.md progress.md findings.md
git commit -m "refactor(cross): extract verifyflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader downloader/manifest refactor
