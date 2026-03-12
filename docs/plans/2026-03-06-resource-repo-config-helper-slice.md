# Resource Repo Config Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract top-level pure helper functions from `src/fpdev.resource.repo.pas` into a dedicated helper unit without changing repository behavior.

**Architecture:** Move `GetCurrentPlatform`, `CreateDefaultConfig`, and `CreateConfigWithMirror` into `fpdev.resource.repo.config`, then keep `fpdev.resource.repo.pas` as thin wrappers. This is a low-risk slice because the functions are stateless, top-level, and already independent from the repository object's runtime state.

**Tech Stack:** Object Pascal (FPC/Lazarus), resource repo constants/types, focused Pascal regression tests.

---

### Task 1: Add focused failing test for config helper

**Files:**
- Create: `tests/test_resource_repo_config.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - current platform helper returns a non-empty known platform id
  - default config sets primary URL, fallback mirror, and branch
  - mirror selection swaps GitHub/Gitee as expected
  - custom URL overrides mirrors

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_config.lpr`
Expected: FAIL because `fpdev.resource.repo.config` does not exist yet.

### Task 2: Extract config helper unit

**Files:**
- Create: `src/fpdev.resource.repo.config.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: Write minimal implementation**
- Add `ResourceRepoGetCurrentPlatform`, `ResourceRepoCreateDefaultConfig`, and `ResourceRepoCreateConfigWithMirror`.
- Keep `fpdev.resource.repo.pas` exported helpers as thin wrappers.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_config.lpr && ./bin/test_resource_repo_config`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Main build verification**
Run: `lazbuild -B fpdev.lpi`
Expected: build succeeds.

**Step 2: Resource repo package regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_package.lpr && ./bin/test_resource_repo_package`
Expected: PASS.
