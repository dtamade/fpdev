# Git Module Closeout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the remaining explicit Git module backlog by writing the current-state module summary docs and syncing `todo/git/todo.md` to the actual repository state.

**Architecture:** Do not reopen Git implementation. This wave is a current-state documentation closeout around the active Git surfaces: `fpdev.git.operations`, `git2.api + git2.impl`, legacy `fpdev.git2`, focused test lanes, and migration cautions. The plan should land a canonical Git operations summary doc and update the explicit TODO record.

**Tech Stack:** Markdown docs, Python unittest

---

### Task 1: Add RED docs contracts for the missing module summary

**Files:**
- Modify: `tests/test_git_runtime_boundary.py`
- Modify: `tests/test_contributor_docs_contract.py`
- Verify: `todo/git/todo.md`

**Step 1: Write the failing test**

- Require a canonical Git operations summary doc:
  - `docs/GIT_OPERATIONS.md`
  - `docs/GIT_OPERATIONS.en.md`
- Require those docs to mention:
  - `fpdev.git.operations`
  - `src/fpdev.git.operations.impl.pas`
  - `git2.api + git2.impl`
  - legacy `fpdev.git2`
  - focused test entrypoints
- Require `todo/git/todo.md` to mark the module summary doc item complete once the docs exist.

**Step 2: Run test to verify it fails**

Run:
```bash
python3 -m unittest tests.test_git_runtime_boundary tests.test_contributor_docs_contract -v
```

### Task 2: Write the module summary docs

**Files:**
- Create: `docs/GIT_OPERATIONS.md`
- Create: `docs/GIT_OPERATIONS.en.md`
- Modify: `docs/GIT2_USAGE.md`
- Modify: `docs/GIT2_USAGE.en.md`

**Step 1: Document the current Git surfaces**

- public entrypoints
- recommended usage by layer
- focused test/program entrypoints
- migration cautions
- when to use system-git facade vs libgit2 facade

### Task 3: Sync the explicit TODO record

**Files:**
- Modify: `todo/git/todo.md`
- Optional: `report/fpdev.git2.md`

**Step 1: Mark closeout status**

- Convert the remaining unchecked module-summary item to done only after docs and contracts are green.
- If the half-checked test-matrix item still needs a narrower note, update its wording to the current truth instead of leaving an ambiguous `[ / ]`.

### Task 4: Verify and close

**Run:**
```bash
python3 -m unittest tests.test_git_runtime_boundary tests.test_contributor_docs_contract -v
```

**Step 2: Commit**

```bash
git add docs/GIT_OPERATIONS.md docs/GIT_OPERATIONS.en.md docs/GIT2_USAGE.md docs/GIT2_USAGE.en.md todo/git/todo.md report/fpdev.git2.md tests/test_git_runtime_boundary.py tests/test_contributor_docs_contract.py
git commit -m "docs(git): close module summary backlog"
```
