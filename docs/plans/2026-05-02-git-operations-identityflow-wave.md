# Git Operations Identityflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract a narrow identityflow helper from `src/fpdev.git.operations.impl.pas` if the repeated config/env/signature logic can be moved without widening the Git surface.

**Architecture:** Start from the repeated identity/signature logic already visible in `CommitWithLibgit2` and `PullWithLibgit2`. Keep transport/credential callback wiring in place for now; this wave is only about resolving author/committer identity and creating signatures through one shared helper surface. If the seam proves too coupled during RED audit, stop and record a no-go checkpoint instead of forcing extraction.

**Tech Stack:** Object Pascal, Python unittest, focused Pascal test runner

---

### Task 1: Confirm the seam and write the boundary RED

**Files:**
- Modify: `tests/test_git_runtime_boundary.py`
- Verify: `src/fpdev.git.operations.impl.pas`

**Step 1: Write the failing test**

- Require a dedicated helper unit:
  - `src/fpdev.git.operations.identityflow.pas`
- Require `CommitWithLibgit2` and `PullWithLibgit2` to delegate identity/signature preparation through the helper.
- Keep `fpdev.git.operations.pas` as the only public facade; the helper must remain internal.

**Step 2: Run test to verify it fails**

Run:
```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

### Task 2: Add a focused Pascal regression for helper-owned behavior

**Files:**
- Create: `tests/test_git_operations_identityflow.lpr`

**Step 1: Cover current behavior**

- config-based `user.name` / `user.email`
- environment fallback via `fpdev.git.env.ResolveGitIdentityEnv`
- committer fallback to author when committer env is absent
- failure when neither config nor env provides a usable identity

**Step 2: Run test to verify it fails**

Run:
```bash
bash scripts/run_single_test.sh tests/test_git_operations_identityflow.lpr
```

### Task 3: Implement the helper

**Files:**
- Create: `src/fpdev.git.operations.identityflow.pas`
- Modify: `src/fpdev.git.operations.impl.pas`

**Step 1: Move only the helper-owned logic**

- repo/default config identity lookup
- local `.git/config` fallback when needed
- env fallback
- author/committer normalization
- signature creation helpers

Do not move clone/fetch/push credential transport wiring in this wave.

### Task 4: Verify or stop cleanly

**Run:**
```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

**Run:**
```bash
bash scripts/run_single_test.sh tests/test_git_operations_identityflow.lpr
```

**Run:**
```bash
bash scripts/run_single_test.sh tests/test_git_operations.lpr
```

**Step 4: Commit or no-go checkpoint**

- If the helper lands cleanly:
```bash
git add src/fpdev.git.operations.identityflow.pas src/fpdev.git.operations.impl.pas tests/test_git_runtime_boundary.py tests/test_git_operations_identityflow.lpr
git commit -m "refactor(git): extract identityflow helper"
```
- If the seam fails the audit, update `task_plan.md`, `findings.md`, and `progress.md` with the no-go reason and stop without forcing the refactor.
