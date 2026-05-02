# Release Build Path Reporting Truth-Sync Wave

> **For Codex:** Keep this wave narrow. The goal is not another packaging refactor; it is to make the shared release build entrypoint expose one stable binary-path truth that docs and scripts can consume without assuming `./bin/fpdev`.

**Goal:** Turn `scripts/build_release.sh` into a stable source of truth for the built release binary path, then sync current public source-build docs to that path-reporting contract.

**Architecture:** Keep `scripts/build_release.sh` as the shared maintainer release build entrypoint. Add one canonical report file in the repo log tree for the resolved binary path, keep `FPDEV_RELEASE_BIN_PATH_FILE` as an override for callers like `scripts/release_acceptance_linux.sh`, and update public docs to consume the reported path instead of assuming `./bin/fpdev`.

**Tech Stack:** Bash, Markdown docs, Python unittest contract tests

---

## Task 1: Add RED contracts for path reporting and docs truth

**Files:**
- Modify: `tests/test_release_scripts_contract.py`
- Modify: `tests/test_official_docs_cli_contract.py`
- Modify: `tests/test_release_docs_contract.py`

**Steps:**
1. Require `scripts/build_release.sh` to mention a canonical default report file in addition to `FPDEV_RELEASE_BIN_PATH_FILE`.
2. Require current public source-build docs to show how to read the reported release binary path instead of calling `./bin/fpdev` directly after `bash scripts/build_release.sh`.
3. Require release notes to follow the same contract.

## Task 2: Implement canonical path reporting in the shared build entrypoint

**Files:**
- Modify: `scripts/build_release.sh`

**Steps:**
1. Add a stable default report file under the repo log tree.
2. Make `write_release_bin_path(...)` always write the canonical file.
3. Preserve `FPDEV_RELEASE_BIN_PATH_FILE` as an additional caller-specific output file.
4. Keep current build-root fallback behavior unchanged.

## Task 3: Sync public source-build docs

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `FAQ.md`
- Modify: `docs/FAQ.md`
- Modify: `docs/FAQ.en.md`
- Modify: `docs/INSTALLATION.md`
- Modify: `docs/INSTALLATION.en.md`
- Modify: `RELEASE_NOTES.md`

**Steps:**
1. Replace stale `./bin/fpdev ...` post-build examples with the reported-path flow.
2. Keep the shared `bash scripts/build_release.sh` entrypoint wording.
3. Briefly explain that the path file may point either to `./bin/fpdev` or to a writable fallback build root.

## Task 4: Verify and close

**Run:**
```bash
python3 -m unittest tests.test_release_scripts_contract tests.test_official_docs_cli_contract tests.test_release_docs_contract -v
```

**Run:**
```bash
bash -n scripts/build_release.sh
```

**Then:**
1. Sync `task_plan.md`, `findings.md`, and `progress.md`.
2. Give a short review conclusion.
3. Commit the wave with a Conventional Commit message.
