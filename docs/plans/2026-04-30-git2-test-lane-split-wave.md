# Git2 Test Lane Split Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separate modern-interface Git2 coverage from legacy-wrapper coverage so future `git2.impl` changes can be made without ambiguous focused runners.

**Architecture:** Keep `tests/fpdev.git2/` as the legacy-focused surface, add an explicit modern-focused runner family, and add Python boundary contracts that make the split intentional and persistent.

**Tech Stack:** Object Pascal / Free Pascal, fpcunit, Python unittest

---

### Task 1: Add the lane contract

**Files:**
- Create: `tests/test_git2_lane_contract.py`
- Modify: `tests/fpdev.git2/fpdev.git2.test.lpr`
- Modify: `tests/fpdev.git2/fpdev.git2.testcase.pas`
- Modify: `tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas`

**Step 1: Write the failing contract**

- Require `tests/fpdev.git2/*` focused runners to be explicitly legacy-oriented when they import `fpdev.git2`.
- Require any new modern-only runner to avoid importing `fpdev.git2`.

**Step 2: Run the RED verification**

Run:
```bash
python3 -m unittest tests.test_git2_lane_contract -v
```

**Step 3: Make the existing legacy intent explicit**

- Add short source comments or naming clarifications in the legacy runners.
- Keep the legacy coverage where it is; do not silently convert it to modern coverage.

**Step 4: Re-run the lane contract**

Run:
```bash
python3 -m unittest tests.test_git2_lane_contract -v
```

**Step 5: Commit**

```bash
git add tests/test_git2_lane_contract.py tests/fpdev.git2/fpdev.git2.test.lpr tests/fpdev.git2/fpdev.git2.testcase.pas tests/fpdev.git2/fpdev.git2.fpcunit.tests.pas
git commit -m "test(git2): codify modern and legacy test lanes"
```

### Task 2: Add a modern-only focused runner

**Files:**
- Create: `tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr`
- Create: `tests/fpdev.git2.modern/run_tests.sh`
- Modify: `docs/history/git2-status-and-tests.md`
- Modify: `report/fpdev.git2.md`

**Step 1: Write the failing modern-only runner**

- Cover `NewGitManager()`, `DiscoverRepository()` fallback, and at least one repository/status path without importing `fpdev.git2`.

**Step 2: Run it RED if helper code or layout is still missing**

Run:
```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-git2-modern-bin -FU/tmp/fpdev-git2-modern-lib tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr
```

**Step 3: Finish the minimal runner and local script**

- Keep it offline by default.
- Make the shell wrapper mirror existing focused-runner conventions.

**Step 4: Run the modern runner**

Run:
```bash
/tmp/fpdev-git2-modern-bin/fpdev.git2.modern.basic
```

**Step 5: Commit**

```bash
git add tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr tests/fpdev.git2.modern/run_tests.sh docs/history/git2-status-and-tests.md report/fpdev.git2.md
git commit -m "test(git2): add modern-only focused runner"
```

### Task 3: Close the lane split with focused and broad verification

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Run focused verification**

Run:
```bash
python3 -m unittest tests.test_git2_lane_contract tests.test_git2_status_docs_contract -v
```

Run:
```bash
fpc -Fusrc -Fisrc -Fu./tests -FE/tmp/fpdev-git2-modern-bin -FU/tmp/fpdev-git2-modern-lib tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr
```

Run:
```bash
/tmp/fpdev-git2-modern-bin/fpdev.git2.modern.basic
```

**Step 2: Run broad verification**

Run:
```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

**Step 3: Sync planning files**

- Mark the lane split complete.
- Record which runners are legacy-only and which runners are modern-only.

**Step 4: Commit**

```bash
git add task_plan.md progress.md findings.md
git commit -m "docs(plan): close git2 lane split wave"
```

