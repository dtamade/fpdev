# Package Registry Queryflow Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the pure query/read surface from `src/fpdev.package.registry.pas` into an internal helper while keeping index mutation and lifecycle ownership in the registry class.

**Architecture:** Add `src/fpdev.package.registry.queryflow.pas` to own metadata cloning, version enumeration, existence checks, archive-path resolution, listing, and search over the loaded JSON index. `src/fpdev.package.registry.pas` keeps `LoadIndex`, `SaveIndex`, `Initialize`, `ExtractPackageInfo`, `AddPackage`, and `RemovePackage`, plus registry path ownership and error state.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the queryflow seam

**Files:**
- Inspect: `src/fpdev.package.registry.pas`
- Reuse: `tests/test_package_registry.lpr`
- Reuse: `tests/test_package_search.lpr`
- Reuse: `tests/test_package_publish.lpr`
- Reuse: `tests/test_integration_e2e.lpr`

**Step 1: Lock the helper-owned methods**

- `GetPackageMetadata(...)`
- `GetPackageVersions(...)`
- `HasPackage(...)`
- `HasPackageVersion(...)`
- `GetPackageArchive(...)`
- `ListPackages`
- `SearchPackages(...)`

**Step 2: Lock what stays in the class**

- `LoadIndex`, `SaveIndex`, `Initialize`
- `ExtractPackageInfo`
- `AddPackage`, `RemovePackage`
- `RegistryPath` and `FLastError` ownership

### Task 2: Write the RED boundary and focused query test

**Files:**
- Create: `tests/test_package_registry_boundary.py`
- Create: `tests/test_package_registry_queryflow.lpr`

**Step 1: Add Python boundary RED**

- Require `src/fpdev.package.registry.pas` to import `fpdev.package.registry.queryflow`.
- Require all query methods to delegate into the helper.
- Require add/remove/index lifecycle code to remain class-owned.

**Step 2: Add focused Pascal RED**

- Metadata reads return clones rather than the live JSON node.
- Version enumeration is copied into a new `TStringList`.
- `HasPackageVersion(...)` works through the shared query helper.
- Archive lookup returns empty when the version is absent or the archive file is missing.
- Search remains case-insensitive across package name and description.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_package_registry_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_package_registry_queryflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and query methods are still inline on the registry class.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.package.registry.queryflow.pas`
- Modify: `src/fpdev.package.registry.pas`

**Step 1: Move only pure reads**

- Build helper functions around `TJSONObject` index data and registry-path callbacks.
- Keep helper APIs internal; do not expose a new public registry facade.
- Avoid moving `AddPackage(...)` / `RemovePackage(...)` into this wave.

**Step 2: Keep behavior stable**

- Preserve current empty-list / nil-return semantics.
- Preserve package listing and search behavior.
- Preserve archive path format `<name>-<version>.tar.gz`.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_package_registry_boundary -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_package_registry_queryflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_package_registry.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_package_search.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_package_publish.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_integration_e2e.lpr
```

Expected: all pass with query methods reduced to thin delegates.

### Task 5: Commit or no-go checkpoint

- If the helper lands cleanly:
```bash
git add src/fpdev.package.registry.queryflow.pas src/fpdev.package.registry.pas tests/test_package_registry_boundary.py tests/test_package_registry_queryflow.lpr task_plan.md progress.md findings.md
git commit -m "refactor(package-registry): extract queryflow helper"
```

- If the seam fails the audit:
  - record the blocker in `task_plan.md`, `progress.md`, and `findings.md`
  - stop without pulling `AddPackage(...)` or `RemovePackage(...)` into a larger rewrite
