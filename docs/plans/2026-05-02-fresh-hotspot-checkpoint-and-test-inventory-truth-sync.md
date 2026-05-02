# Fresh Hotspot Re-rank Checkpoint And Test Inventory Truth Sync

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 `build cache binaryartifactflow` 收口后，不机械重开新 helper wave；先确认当前是否还存在新的低 blast-radius seam，再把 discoverable test inventory 的公共文案同步回真实状态，并用 Python/Pascal/Release 证据链收口。

**Architecture:** 先对当前剩余大单元做 fresh re-rank；若没有新的 “3-5 个方法成组、测试护栏成熟、爆炸半径低” seam，则把动作收缩为 closeout checkpoint。发现 `scripts/update_test_stats.py` 维护的 discoverable test inventory 与 README/ROADMAP/MVP acceptance 文案漂移时，统一通过脚本修复，再用 focused docs contract、Python 全量、Pascal 全量和 Release build 证明没有引入回退。

**Tech Stack:** Object Pascal / Free Pascal, Python unittest, Bash, Markdown

---

### Task 1: Confirm No New Helper Wave

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

**Step 1: Re-rank the current tree**

Run:

```bash
git status --porcelain=v1
rg -n "^- \[ \]" task_plan.md
```

Expected:
- recent wave is already committed
- `task_plan.md` has no unchecked root tasks
- no new low-risk helper seam is obvious enough to justify another wave

### Task 2: Reproduce And Fix Test Inventory Drift

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `docs/testing.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/MVP_ACCEPTANCE_CRITERIA.md`
- Modify: `docs/MVP_ACCEPTANCE_CRITERIA.en.md`

**Step 1: Reproduce**

Run:

```bash
python3 scripts/update_test_stats.py --count
python3 scripts/update_test_stats.py --check
```

Expected:
- count reflects the current discoverable `test_*.lpr` inventory
- `--check` fails if public docs still lag behind that count

**Step 2: Apply canonical sync**

Run:

```bash
python3 scripts/update_test_stats.py --write
python3 scripts/update_test_stats.py --check
```

Expected:
- tracked docs are rewritten from the canonical inventory source
- `--check` passes after the rewrite

### Task 3: Verification Bundle

Run:

```bash
python3 -m unittest tests.test_release_status_wording tests.test_update_test_stats tests.test_contributor_docs_contract -v
python3 -m unittest discover -s tests -p 'test_*.py'
bash scripts/run_all_tests.sh
lazbuild -B --build-mode=Release fpdev.lpi
```

Expected:
- focused docs/release wording contracts pass
- Python full suite passes
- Pascal full suite passes
- release build succeeds

### Task 4: Sync Planning Truth And Commit

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`
- Modify: `findings.md`

Update the root planning files so they record:
- this was a checkpoint, not a new helper wave
- the canonical discoverable test inventory count observed in this session
- the exact verification evidence used for closeout

Before commit, run:

```bash
git diff --check
git status --short
```

Then commit the batch with a closeout-oriented message.
