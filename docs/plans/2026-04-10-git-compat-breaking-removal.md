# Git Compat Breaking Removal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the last `fpdev.utils.git` compatibility shim in a future breaking window without reopening the Git runtime migration or reintroducing repository-local callers.

**Architecture:** Treat this as a bounded breaking change. Delete the shim unit only after the repository code, active docs, and migration contract tests all prove that `fpdev.git.operations` is the only supported entrypoint for `TGitOperations` and `IGitCliRunner`. Keep the release-facing impact explicit through a release-note template and a narrow verification bundle.

**Tech Stack:** Object Pascal unit aliases, Markdown migration docs, Python `unittest` boundary tests, repo-local Prettier wrapper.

---

### Task 1: Freeze the pre-removal boundary

**Files:**

- Modify: `tests/test_git_runtime_boundary.py`
- Verify: `docs/GIT_COMPAT_MIGRATION.md`

**Step 1: Write the failing test**

Add assertions that require:

- the breaking-removal plan doc to exist
- the migration doc to link to it
- the plan doc to carry the release-note template and exact delete target

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- FAIL because the plan doc does not exist yet and the migration doc does not link to it

**Step 3: Write minimal documentation**

Add:

- `docs/plans/2026-04-10-git-compat-breaking-removal.md`
- a pointer from `docs/GIT_COMPAT_MIGRATION.md`

**Step 4: Run test to verify it passes**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- PASS

### Task 2: Delete the compat shim in the breaking window

**Files:**

- Delete: `src/fpdev.utils.git.pas`
- Modify: `tests/test_git_runtime_boundary.py`
- Modify: `docs/GIT_COMPAT_MIGRATION.md`
- Modify: `CHANGELOG.md`

**Step 1: Write the failing test**

Add assertions that require:

- `src/fpdev.utils.git.pas` to be absent
- repository source and focused tests to stay free of `fpdev.utils.git`
- the migration doc to switch from soft-deprecated shim wording to removal-complete wording

**Step 2: Run test to verify it fails**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- FAIL while the shim still exists

**Step 3: Write minimal implementation**

Delete: `src/fpdev.utils.git.pas`

Then:

- remove stale shim references from docs that should now describe removal-complete state
- update `CHANGELOG.md` with the breaking removal note

**Step 4: Run test to verify it passes**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- PASS

### Task 3: Verify no repository caller regresses

**Files:**

- Verify: `tests/test_git_runtime_boundary.py`
- Verify: `tests/test_contributor_docs_contract.py`
- Verify: `tests/test_run_prettier_sh.py`
- Verify: `tests/test_git_operations.lpr`
- Verify: `tests/test_git_facade.lpr`
- Verify: `tests/test_fpc_builder.lpr`

**Step 1: Compile and run the focused Pascal suites**

Run:

```bash
mkdir -p /tmp/fpdev-test-bin/git-ops-remove /tmp/fpdev-test-lib/git-ops-remove
fpc -Fu./src -Fi./src -Fu./tests \
  -FE/tmp/fpdev-test-bin/git-ops-remove \
  -FU/tmp/fpdev-test-lib/git-ops-remove \
  tests/test_git_operations.lpr
FPDEV_TEST_PROJECT_ROOT="$(pwd)" /tmp/fpdev-test-bin/git-ops-remove/test_git_operations
```

Then:

```bash
mkdir -p /tmp/fpdev-test-bin/git-facade-remove /tmp/fpdev-test-lib/git-facade-remove
fpc -Fu./src -Fi./src -Fu./tests \
  -FE/tmp/fpdev-test-bin/git-facade-remove \
  -FU/tmp/fpdev-test-lib/git-facade-remove \
  tests/test_git_facade.lpr
/tmp/fpdev-test-bin/git-facade-remove/test_git_facade
```

Then:

```bash
mkdir -p /tmp/fpdev-test-bin/fpc-builder-remove /tmp/fpdev-test-lib/fpc-builder-remove
fpc -Fu./src -Fi./src -Fu./tests \
  -FE/tmp/fpdev-test-bin/fpc-builder-remove \
  -FU/tmp/fpdev-test-lib/fpc-builder-remove \
  tests/test_fpc_builder.lpr
/tmp/fpdev-test-bin/fpc-builder-remove/test_fpc_builder
```

**Step 2: Run the Python boundary suite**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- PASS

**Step 3: Run the combined Python regression bundle**

Run:

```bash
python3 -m unittest tests.test_run_prettier_sh tests.test_contributor_docs_contract tests.test_git_runtime_boundary -v
```

Expected:

- PASS

### Task 4: Publish the breaking note clearly

**Files:**

- Modify: `CHANGELOG.md`
- Modify: `RELEASE_NOTES.md`

**Step 1: Add the release-note template during staging**

Release-note template:

```markdown
### Breaking impact summary

- Removed `src/fpdev.utils.git.pas`
- Removed the last compatibility aliases for `TGitOperations` and `IGitCliRunner`
- External callers must switch to `fpdev.git.operations`
- Migration path: Use `fpdev.git.operations` instead.
```

**Step 2: Keep the published note explicit**

The breaking release note must name:

- `TGitOperations`
- `IGitCliRunner`
- `fpdev.git.operations`
- the fact that the shim unit was deleted

**Step 3: Verify the docs still format**

Run:

```bash
bash scripts/run_prettier.sh --write docs/GIT_COMPAT_MIGRATION.md CHANGELOG.md RELEASE_NOTES.md
bash scripts/run_prettier.sh --check docs/GIT_COMPAT_MIGRATION.md CHANGELOG.md RELEASE_NOTES.md
```

Expected:

- Prettier succeeds through the repo-local wrapper

## Release-note template

### Breaking impact summary

- Removed `src/fpdev.utils.git.pas`
- Removed the last compatibility aliases for `TGitOperations` and `IGitCliRunner`
- External callers must switch to `fpdev.git.operations`
- Migration path: Use `fpdev.git.operations` instead.
