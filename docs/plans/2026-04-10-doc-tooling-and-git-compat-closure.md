# Doc Tooling And Git Compat Closure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Standardize the repo-local docs tooling entrypoint, tighten contributor guidance around focused Pascal test workflows, and document the final removal gates for `fpdev.utils.git` without reopening large code migrations.

**Architecture:** Keep the changes documentation-first and test-driven. Reuse the new `scripts/run_prettier.sh` wrapper as the only documented formatting entrypoint, codify the guidance through contributor-doc and Git-boundary contract tests, and extend `docs/GIT_COMPAT_MIGRATION.md` with explicit final-removal gates plus a classification of the remaining intentional `fpdev.utils.git` references.

**Tech Stack:** Markdown docs, Python `unittest` contract tests, small POSIX shell wrapper usage.

---

### Task 1: Tighten contributor guidance for docs formatting and focused Pascal tests

**Files:**

- Modify: `CLAUDE.md`
- Modify: `docs/testing.md`

**Step 1: Write the failing doc-contract expectations**

Target expectations:

- `CLAUDE.md` should point doc formatting at `bash scripts/run_prettier.sh --check ...`
- `CLAUDE.md` should stop recommending `python3 -m pytest tests -q`
- `docs/testing.md` should document the repo-local prettier wrapper
- `docs/testing.md` should document the `/tmp` output pattern for manual focused Pascal compiles

**Step 2: Run the targeted doc-contract tests and verify they fail**

Run:

```bash
python3 -m unittest tests.test_contributor_docs_contract -v
```

Expected:

- FAIL on new assertions for formatter entrypoint and `/tmp` focused-test guidance

**Step 3: Write the minimal documentation changes**

Update:

- `CLAUDE.md`
- `docs/testing.md`

Required content:

- repo-local formatter entrypoint: `bash scripts/run_prettier.sh ...`
- Python regression baseline via `python3 -m unittest discover -s tests -p 'test_*.py'`
- preferred single-test path: `bash scripts/run_single_test.sh ...`
- manual fallback compile pattern that writes outputs to `/tmp`
- short high-frequency command index so contributors can copy working commands quickly

**Step 4: Re-run the targeted doc-contract tests**

Run:

```bash
python3 -m unittest tests.test_contributor_docs_contract -v
```

Expected:

- PASS

### Task 2: Codify the repo-local formatter entrypoint in contributor-doc contract tests

**Files:**

- Modify: `tests/test_contributor_docs_contract.py`

**Step 1: Add failing tests**

Add assertions that:

- `CLAUDE.md` contains `scripts/run_prettier.sh`
- `docs/testing.md` contains `scripts/run_prettier.sh`
- `docs/testing.md` contains `/tmp`-based focused Pascal compile guidance
- `CLAUDE.md` does not contain `python3 -m pytest tests -q`

**Step 2: Run only this suite and verify RED**

Run:

```bash
python3 -m unittest tests.test_contributor_docs_contract -v
```

Expected:

- FAIL on the new assertions

**Step 3: Keep the tests minimal and specific**

Do not add broad regexes. Assert the exact repo-local entrypoints that contributors should copy.

**Step 4: Re-run after doc changes**

Run:

```bash
python3 -m unittest tests.test_contributor_docs_contract -v
```

Expected:

- PASS

### Task 3: Extend the Git compat migration doc with final-removal gates and reference buckets

**Files:**

- Modify: `docs/GIT_COMPAT_MIGRATION.md`

**Step 1: Add failing assertions for the missing migration policy**

Add assertions that the migration doc must now include:

- final removal gates for deleting `fpdev.utils.git`
- explicit buckets for the remaining intentional references
- a statement that active docs should only mention the shim when explaining migration or compat scope

**Step 2: Run the focused Git boundary suite and verify RED**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- FAIL on the new migration-policy assertions

**Step 3: Update the migration doc minimally**

Add:

- final removal checklist / gates
- current text-reference buckets
- active-doc policy for `fpdev.utils.git`

Do not change code-level migration decisions.

**Step 4: Re-run the boundary suite**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- PASS

### Task 4: Lock active-doc `fpdev.utils.git` references to a small whitelist

**Files:**

- Modify: `tests/test_git_runtime_boundary.py`

**Step 1: Add a failing whitelist test**

Whitelist the active docs that intentionally mention `fpdev.utils.git`:

- `docs/GIT_COMPAT_MIGRATION.md`
- `docs/GIT2_USAGE.md`
- `docs/GIT2_USAGE.en.md`
- `docs/ARCHITECTURE.md`
- `docs/ARCHITECTURE.en.md`
- `docs/LIBGIT2_INTEGRATION.md`
- `docs/LIBGIT2_INTEGRATION.en.md`

**Step 2: Run the suite and verify RED if the whitelist/doc text is incomplete**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- FAIL until the whitelist and migration doc language match

**Step 3: Keep the boundary narrow**

The test should guard active docs only. It should not scan `docs/history/` or `docs/plans/`.

**Step 4: Re-run after doc updates**

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
```

Expected:

- PASS

### Task 5: Format the touched docs and run the final verification bundle

**Files:**

- Use: `scripts/run_prettier.sh`
- Verify: `tests/test_run_prettier_sh.py`
- Verify: `tests/test_contributor_docs_contract.py`
- Verify: `tests/test_git_runtime_boundary.py`

**Step 1: Format the touched markdown files**

Run:

```bash
bash scripts/run_prettier.sh --write CLAUDE.md docs/testing.md docs/GIT_COMPAT_MIGRATION.md docs/plans/2026-04-10-doc-tooling-and-git-compat-closure.md
```

Expected:

- Prettier formats the files successfully without relying on `yarn prettier`

**Step 2: Verify the wrapper and contract suites**

Run:

```bash
bash -n scripts/run_prettier.sh
python3 -m unittest tests.test_run_prettier_sh tests.test_contributor_docs_contract tests.test_git_runtime_boundary -v
```

Expected:

- All suites pass

**Step 3: Update planning files**

Update:

- `task_plan.md`
- `findings.md`
- `progress.md`

Record:

- the root cause of the old `yarn prettier` failure
- the new contributor guidance
- the new final-removal gate policy for `fpdev.utils.git`

**Step 4: Do not commit unless explicitly requested**

This session should stop after verified local changes and a concise handoff summary.
