# Release Packaging Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove duplicated release-asset packaging shell blocks from CI/release lanes by introducing shared script entrypoints that keep release packaging behavior and contract wording aligned.

**Architecture:** Keep `scripts/assemble_release_ready_bundle.sh` as the bundle assembly entrypoint, then extract the repeated per-platform packaging shell blocks into a small shared script so both Linux and matrix packaging flows call the same interface.

**Tech Stack:** Bash, Python unittest, GitHub Actions workflow contracts

---

### Task 1: Add a packaging-step contract

**Files:**
- Create: `tests/test_release_packaging_contract.py`
- Modify: `tests/test_ci_workflow_contract.py`
- Modify: `tests/test_release_scripts_contract.py`

**Step 1: Write the failing test**

- Require CI jobs to call a shared packaging script instead of inlining `rm -rf release-assets` plus `scripts/package_release_assets.py`.
- Keep the existing bundle-assembly script contract intact.

**Step 2: Run RED**

Run:
```bash
python3 -m unittest tests.test_release_packaging_contract tests.test_ci_workflow_contract tests.test_release_scripts_contract -v
```

**Step 3: Refine the assertions**

- Pin only the packaging dedup target, not unrelated workflow wording.

**Step 4: Commit**

```bash
git add tests/test_release_packaging_contract.py tests/test_ci_workflow_contract.py tests/test_release_scripts_contract.py
git commit -m "test(release): add shared packaging step contract"
```

### Task 2: Extract the shared packaging script

**Files:**
- Create: `scripts/package_release_asset.sh`
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/release_acceptance_linux.sh`
- Modify: `docs/MVP_ACCEPTANCE_CRITERIA.md`
- Modify: `docs/MVP_ACCEPTANCE_CRITERIA.en.md`

**Step 1: Implement the shared script**

- Inputs should cover output dir, data dir, and the platform-specific package argument currently passed inline from CI.

**Step 2: Swap CI and release lanes to the shared script**

- Replace duplicated packaging shell blocks.
- Keep artifact names and upload paths unchanged.

**Step 3: Run focused verification**

Run:
```bash
python3 -m unittest tests.test_release_packaging_contract tests.test_ci_workflow_contract tests.test_release_scripts_contract tests.test_release_docs_contract -v
```

Run:
```bash
bash -n scripts/package_release_asset.sh
```

Run:
```bash
bash -n scripts/assemble_release_ready_bundle.sh
```

**Step 4: Commit**

```bash
git add scripts/package_release_asset.sh .github/workflows/ci.yml scripts/release_acceptance_linux.sh docs/MVP_ACCEPTANCE_CRITERIA.md docs/MVP_ACCEPTANCE_CRITERIA.en.md
git commit -m "refactor(release): share release asset packaging entrypoint"
```

### Task 3: Close the lane

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Re-run the focused release lane bundle**

Run:
```bash
python3 -m unittest tests.test_release_packaging_contract tests.test_ci_workflow_contract tests.test_release_scripts_contract tests.test_release_docs_contract -v
```

**Step 2: Run shell syntax checks**

Run:
```bash
bash -n scripts/package_release_asset.sh
```

Run:
```bash
bash -n scripts/assemble_release_ready_bundle.sh
```

Run:
```bash
bash -n scripts/build_release.sh
```

**Step 3: Sync planning files**

- Record the new script entrypoint and where CI/release lanes consume it.

**Step 4: Commit**

```bash
git add task_plan.md progress.md findings.md
git commit -m "docs(plan): close release packaging consolidation wave"
```

