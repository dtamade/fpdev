# Index Metadataflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** Extract the remaining low-blast-radius URL selection and index metadata parsing cluster from `src/fpdev.index.pas` into a helper, without reopening the already-closed remote/cache/serviceflow seam.

**Architecture:** Add `src/fpdev.index.metadataflow.pas` to own raw-URL conversion, primary/fallback mirror selection, and repo/channel metadata extraction from `index.json`. Keep `src/fpdev.index.pas` owning HTTP fetch, cache directory, serviceflow orchestration, manifest loading, and public query/download surface.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the metadata-only seam

**Files:**
- Inspect: `src/fpdev.index.pas`
- Reuse: `src/fpdev.index.serviceflow.pas`
- Reuse: `tests/test_index_boundary.py`
- Reuse: `tests/test_index_serviceflow.lpr`
- Reuse: `tests/test_cmd_index.lpr`

**Step 1: Lock the helper-owned cluster**

- URL conversion and mirror choice:
  - `GetRawURL(...)`
  - `SelectPrimaryURL(...)`
  - `SelectFallbackURL(...)`
- repo/channel metadata extraction from `index.json`:
  - `GetRepoInfo(...)` inner JSON parsing
  - `GetChannelInfo(...)` inner JSON parsing

**Step 2: Lock what stays in `fpdev.index`**

- `FetchJSON(...)`
- `LoadManifestData(...)`
- `ResolveRepoDownloadInfo(...)`
- `ListRepoVersions(...)`
- `Initialize(...)`
- cache dir / output ownership
- `RepoTypeToString(...)` may stay local if moving it would force broader shared-type reshaping

**Step 3: Record the stop condition**

- If extraction would force a new shared public types unit or reopen `serviceflow`, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write RED for boundary and helper behavior

**Files:**
- Modify: `tests/test_index_boundary.py`
- Create: `tests/test_index_metadataflow.lpr`
- Create: `tests/test_index_metadataflow.lpi`

**Step 1: Extend Python boundary RED**

- Require `src/fpdev.index.pas` implementation to import `fpdev.index.metadataflow`.
- Require `GetRawURL(...)`, `SelectPrimaryURL(...)`, and `SelectFallbackURL(...)` to delegate to helper-owned functions.
- Require `GetRepoInfo(...)` and `GetChannelInfo(...)` to delegate metadata extraction to helper-owned functions.
- Keep `FetchJSON(...)`, `Initialize(...)`, and serviceflow delegation in the main unit.

**Step 2: Add focused Pascal RED**

- GitHub `.git` repo URL converts to raw content URL.
- Gitee repo URL converts to raw content URL.
- mirror preference selects expected primary and fallback URL.
- repo metadata parsing returns name/github/gitee values from `repositories`.
- channel metadata parsing returns refs from `channels`.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_index_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_index_metadataflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and the metadata/url logic is still inline in `src/fpdev.index.pas`.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.index.metadataflow.pas`
- Modify: `src/fpdev.index.pas`

**Step 1: Move only the metadata/url cluster**

- Add helper-owned raw URL conversion and mirror selection.
- Add helper-owned repo metadata extraction from `repositories`.
- Add helper-owned channel metadata extraction from `channels`.
- Keep `TFPDevIndex` methods as thin delegates so the class API shape stays intact.

**Step 2: Preserve behavior**

- Preserve `github` default preference when both mirrors are available and preference is `auto`.
- Preserve `gitee` / `china` priority semantics.
- Preserve empty-result behavior when index JSON is missing sections or entries.
- Preserve existing `TRepoInfo` / `TChannelInfo` public result shape.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_index_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_index_metadataflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_index_serviceflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cmd_index.lpr
```

Expected: all pass with metadata/url parsing delegated and remote/cache behavior still owned by `fpdev.index` + `fpdev.index.serviceflow`.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.index.metadataflow.pas src/fpdev.index.pas tests/test_index_boundary.py tests/test_index_metadataflow.lpr tests/test_index_metadataflow.lpi task_plan.md progress.md findings.md docs/plans/2026-05-02-index-metadataflow-wave.md
git commit -m "refactor(index): extract metadataflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without turning this into a broader index/types redesign
