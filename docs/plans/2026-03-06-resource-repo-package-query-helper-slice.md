# Resource Repo Package Query Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `resource.repo` package query logic from `src/fpdev.resource.repo.pas` into helper modules without changing behavior.

**Architecture:** Reuse the existing helper split by extending `fpdev.resource.repo.package` and `fpdev.resource.repo.search`. Move package metadata file parsing and package directory listing into `package`, and move the “filter package names by keyword using metadata callback” logic into `search`. Keep `TResourceRepository.GetPackageInfo`, `ListPackages`, and `SearchPackages` as thin wrappers.

**Tech Stack:** Object Pascal (FPC/Lazarus), resource repo package metadata types, focused Pascal regression tests.

---

### Task 1: Add focused failing test for package query helpers

**Files:**
- Create: `tests/test_resource_repo_query.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - metadata JSON parsing from a file into `TRepoPackageInfo`
  - list packages in a category returns package names
  - list all packages returns category names with `/` suffix (current behavior)
  - search helper filters names by description through callback

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_query.lpr`
Expected: FAIL because the new helper functions do not exist yet.

### Task 2: Extract package query helpers

**Files:**
- Modify: `src/fpdev.resource.repo.package.pas`
- Modify: `src/fpdev.resource.repo.search.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: Write minimal implementation**
- Add metadata parsing + list-packages helpers to `package`.
- Add callback-based search helper to `search`.
- Convert `TResourceRepository.GetPackageInfo`, `ListPackages`, and `SearchPackages` to wrappers.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_query.lpr && ./bin/test_resource_repo_query`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Resource repo helper regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_package.lpr && ./bin/test_resource_repo_package`
Expected: PASS.

**Step 2: Resource repo search regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_search.lpr && ./bin/test_resource_repo_search`
Expected: PASS.

**Step 3: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.
