# Build Cache Sourceartifactflow Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the source artifact lifecycle glue from `src/fpdev.build.cache.pas` into a helper without reopening the mixed source/binary `HasArtifacts(...)` compatibility surface.

**Architecture:** Add `src/fpdev.build.cache.sourceartifactflow.pas` to own source artifact save/restore/info/delete behavior. `src/fpdev.build.cache.pas` keeps cache directory ownership, mixed source/binary presence detection in `HasArtifacts(...)`, hit/miss counters, and higher-level cache policy state.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the source-artifact-only seam

**Files:**
- Inspect: `src/fpdev.build.cache.pas`
- Reuse: `tests/test_cache_metadata.lpr`
- Reuse: `tests/test_cache_verification.lpr`
- Reuse: `tests/test_fpc_install_cli.lpr`
- Reuse: `tests/test_temp_hygiene.py`

**Step 1: Lock the helper-owned methods**

- `SaveArtifacts(...)`
- `RestoreArtifacts(...)`
- `GetArtifactInfo(...)`
- `DeleteArtifacts(...)`

**Step 2: Lock what stays in `TBuildCache`**

- `HasArtifacts(...)` mixed source/binary compatibility surface
- cache path ownership via `FCacheDir` / `FCacheDirWithDelim`
- `FCacheHits` / `FCacheMisses`
- `FVerifyOnRestore`
- binary artifact methods

**Step 3: Record the stop condition**

- If extraction would force `HasArtifacts(...)` or binary artifact behavior into the same helper, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write the RED boundary and focused sourceartifactflow test

**Files:**
- Create: `tests/test_build_cache_sourceartifact_boundary.py`
- Create: `tests/test_build_cache_sourceartifactflow.lpr`
- Create: `tests/test_build_cache_sourceartifactflow.lpi`

**Step 1: Add Python boundary RED**

- Require `src/fpdev.build.cache.pas` to import `fpdev.build.cache.sourceartifactflow`.
- Require `SaveArtifacts(...)`, `RestoreArtifacts(...)`, `GetArtifactInfo(...)`, and `DeleteArtifacts(...)` to delegate to helper calls.
- Require inline `tar`/`7z`, old-meta load, and delete-file glue to leave those class methods.
- Keep `HasArtifacts(...)` in the class unit.

**Step 2: Add focused Pascal RED**

- source save returns false when install directory is missing
- source info reads `.meta` and injects archive path
- source delete removes archive and meta files
- source restore runs extraction callback with tar-flags semantics

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_build_cache_sourceartifact_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_build_cache_sourceartifactflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and source artifact lifecycle logic is still inline in `TBuildCache`.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.build.cache.sourceartifactflow.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Move only source artifact lifecycle glue**

- Add helper-owned source save/restore/info/delete functions.
- Keep `TBuildCache` as the public entrypoint and path/state owner.
- Do not touch binary artifact save/restore/info code.

**Step 2: Preserve behavior**

- Preserve current tar / 7z fallback behavior.
- Preserve old `.meta` loading for source artifacts.
- Preserve restore verification guard and hit/miss accounting in `TBuildCache`.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_build_cache_sourceartifact_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_build_cache_sourceartifactflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cache_metadata.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cache_verification.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_install_cli.lpr
```

Expected: all pass with `TBuildCache` ownership intact and source artifact lifecycle delegated.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.build.cache.sourceartifactflow.pas src/fpdev.build.cache.pas tests/test_build_cache_sourceartifact_boundary.py tests/test_build_cache_sourceartifactflow.lpr tests/test_build_cache_sourceartifactflow.lpi task_plan.md progress.md findings.md
git commit -m "refactor(build-cache): extract sourceartifactflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader cache redesign
