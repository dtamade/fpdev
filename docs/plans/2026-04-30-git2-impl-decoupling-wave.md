# Git2 Impl Decoupling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the direct dependency from `src/git2.impl.pas` to deprecated `src/fpdev.git2.pas` while keeping the public `IGitManager` / `IGitRepository` surface stable.

**Architecture:** Extract shared libgit2-facing core behavior into a non-deprecated `git2.*` unit, then make `git2.impl` use that core directly. After that, downgrade `fpdev.git2` to a legacy OO wrapper over the same core instead of being the backend for `git2.impl`.

**Tech Stack:** Object Pascal / Free Pascal, Lazarus, libgit2 bindings, Python boundary tests

---

### Task 1: Lock the decoupling boundary in Python

**Files:**
- Create: `tests/test_git2_impl_boundary.py`
- Modify: `tests/test_official_docs_cli_contract.py`
- Modify: `docs/GIT2_USAGE.md`
- Modify: `docs/GIT2_USAGE.en.md`

**Step 1: Write the failing boundary**

- Require `src/git2.impl.pas` to stop importing `fpdev.git2`.
- Require the docs to keep describing `git2.impl` as the preferred modern implementation.
- Require legacy docs/examples to keep `fpdev.git2` clearly on the compatibility side.

**Step 2: Run RED**

Run:
```bash
python3 -m unittest tests.test_git2_impl_boundary -v
```

**Step 3: Keep only the assertions that correspond to the target end-state**

- Do not change production code yet.
- Make the boundary precise enough that the implementation wave has a real definition of done.

**Step 4: Commit**

```bash
git add tests/test_git2_impl_boundary.py tests/test_official_docs_cli_contract.py docs/GIT2_USAGE.md docs/GIT2_USAGE.en.md
git commit -m "test(git2): add impl decoupling boundary"
```

### Task 2: Extract a shared non-deprecated libgit2 core

**Files:**
- Create: `src/git2.core.pas`
- Modify: `src/git2.impl.pas`
- Modify: `src/fpdev.git2.pas`

**Step 1: Move shared low-level helpers into `git2.core.pas`**

- Candidate surfaces:
  - OID/time helper functions
  - pure-Pascal `DiscoverRepository()` fallback
  - status mapping/filter helpers
  - shared libgit2 result/error helpers

**Step 2: Run focused compile/test checks**

Run:
```bash
python3 -m unittest tests.test_git2_impl_boundary tests.test_git_runtime_boundary -v
```

**Step 3: Update both sides to use the shared core**

- `git2.impl` should depend on `git2.core` + `libgit2` + `git2.types`, not `fpdev.git2`.
- `fpdev.git2` should reuse the same core for legacy OO behavior.

**Step 4: Re-run focused Pascal Git2 checks**

Run:
```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-git-ops-bin -FU/tmp/fpdev-git-ops-lib tests/test_git_operations.lpr
```

Run:
```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-git2-modern-bin -FU/tmp/fpdev-git2-modern-lib tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr
```

**Step 5: Commit**

```bash
git add src/git2.core.pas src/git2.impl.pas src/fpdev.git2.pas tests/test_git2_impl_boundary.py tests/test_git_operations.lpr
git commit -m "refactor(git2): decouple impl from legacy wrapper"
```

### Task 3: Close the wave with full verification

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Run focused verification**

Run:
```bash
python3 -m unittest tests.test_git2_impl_boundary tests.test_git_runtime_boundary tests.test_git2_status_docs_contract -v
```

**Step 2: Run broad repository verification**

Run:
```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

Run:
```bash
bash scripts/run_all_tests.sh
```

Run:
```bash
lazbuild -B --build-mode=Release fpdev.lpi
```

**Step 3: Sync planning files**

- Record the final dependency shape.
- Note whether any tests remain intentionally legacy-only.

**Step 4: Commit**

```bash
git add task_plan.md progress.md findings.md
git commit -m "docs(plan): close git2 impl decoupling wave"
```

