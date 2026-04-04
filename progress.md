# Progress Log

## Session: 2026-03-27

### Phase 1: Requirements & Discovery
- **Status:** in_progress
- **Started:** 2026-03-27
- Actions taken:
  - Read relevant workflow skills for review and roadmap assessment
  - Initialized project-local planning files
  - Attempted semantic codebase retrieval and recorded fallback
- Files created/modified:
  - `task_plan.md` (created)
  - `findings.md` (created)
  - `progress.md` (created)

### Phase 2: Repository Review
- **Status:** complete
- Actions taken:
  - Reviewed entrypoint, CLI bootstrap, command import topology, config manager split, test scripts, roadmap and release docs
  - Ran representative quality and contract checks
  - Built release binary and ran CLI smoke
- Files created/modified:
  - `findings.md`
  - `progress.md`
  - `task_plan.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Tooling discovery | `mcp__ace_tool__search_context` | Return repository map | HTTP 499 | blocked |
| Test inventory sync | `python3 scripts/update_test_stats.py --check` | pass | pass | OK |
| Test stats unit tests | `python3 -m unittest tests.test_update_test_stats` | pass | pass | OK |
| Release docs contract | `python3 -m unittest tests.test_run_all_tests tests.test_release_docs_contract tests.test_official_docs_cli_contract` | pass | 2 failures in `tests.test_release_docs_contract` | FAIL |
| Toolchain baseline | `bash scripts/check_toolchain.sh` | pass | pass | OK |
| Release build | `lazbuild -B --build-mode=Release fpdev.lpi` | pass | pass | OK |
| CLI smoke | `bash scripts/cli_smoke.sh ./bin/fpdev` | pass | pass | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-03-27 | `mcp__ace_tool__search_context` HTTP 499 | 1 | Fallback to shell-based repository inspection |
| 2026-03-27 | `python3 -m pytest ...` failed because `pytest` is unavailable | 1 | Switched to repository-standard `unittest` execution |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4 synthesis |
| Where am I going? | Finalize review findings and prioritized recommendations |
| What's the goal? | Produce project review, development suggestions, and roadmap assessment |
| What have I learned? | Release doc contract drift is the clearest current regression; build/smoke remain healthy |
| What have I done? | Completed repository inspection, ran representative checks, and recorded evidence |

## Session: 2026-04-02

### Phase 4: Synthesis
- **Status:** in_progress
- **Started:** 2026-04-02
- Actions taken:
  - Reused prior repository review context and refreshed planning files for the narrower “biggest problem” question
  - Re-ran semantic codebase retrieval successfully and cross-checked local evidence with exact shell metrics
  - Re-ran `python3 -m unittest tests.test_release_docs_contract -v` and confirmed 2 current failures in release-owner-checkpoint documentation
  - Measured current churn (`279` working tree changes) and identified large migration hotspots in command and git layers
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Release docs contract (current) | `python3 -m unittest tests.test_release_docs_contract -v` | pass | 2 failures (`record_owner_smoke` refs and owner smoke filenames missing) | FAIL |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `git status --short | python3 - <<'PY' ...` caused `IndentationError` | 1 | Re-ran with `python3 -c` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4 synthesis |
| Where am I going? | Finalize the single biggest-problem diagnosis and explain why it outranks other issues |
| What's the goal? | Produce an evidence-backed judgment about FPDev’s biggest current problem |
| What have I learned? | The strongest issue is a mismatch between claimed completion and presently verifiable release/readiness state, amplified by unfinished architecture migration |
| What have I done? | Refreshed evidence, rechecked failing contract tests, and measured current code/working-tree hotspots |

## Session: 2026-04-02 (Continuation)

### Close-out Execution Follow-up
- **Status:** complete
- Actions taken:
  - Preserved the dirty tree on `stabilize/dirty-tree-2026-04-02` and regrouped the preserved work into a clean restage branch
  - Landed four clean regrouping commits on `restage/p0-cleanup-2026-04-02`
  - Pushed the restaged branch to origin
  - Ran the bounded Linux release acceptance lane and captured a new focused RED in `scripts/update_test_stats.py --check`
  - Fixed the README inventory-prefix drift with a minimal `update_test_stats.py` + test update
  - Re-ran focused verification and then the full Linux release acceptance lane to green
- Files created/modified:
  - `scripts/update_test_stats.py`
  - `tests/test_update_test_stats.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Focused RED | `bash scripts/release_acceptance_linux.sh` | pass | failed at `python3 scripts/update_test_stats.py --check` due to README inventory-prefix drift | FAIL |
| Update-test-stats unit tests | `python3 -m unittest -v tests.test_update_test_stats` | pass | pass | OK |
| Inventory sync gate | `python3 scripts/update_test_stats.py --check` | pass | pass | OK |
| Linux release acceptance | `bash scripts/release_acceptance_linux.sh` | pass | pass (`270` Python tests OK, `273/273` Pascal tests pass, release build pass, CLI smoke pass) | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `scripts/update_test_stats.py --check` raised `pattern not found exactly once` for README inventory line | 1 | Updated the script to accept current `[INFO]` inventory lines and added regression coverage |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line complete |
| Where am I going? | Stop local rolling work unless a new focused RED seam appears |
| What's the goal? | Keep release/readiness claims aligned with fresh automated evidence |
| What have I learned? | The remaining local defect was in the release gate itself, not in the runtime command surface |
| What have I done? | Fixed the gate drift and proved the full Linux release acceptance lane green |


## Session: 2026-04-02 (--with-install follow-up)

### Close-out Execution Follow-up 2
- **Status:** complete
- Actions taken:
  - Re-ran the optional network-gated Linux acceptance lane and captured a new RED in `test_fpc_installer_iobridge`
  - Checked the test in isolation, then converted the timing-only symptom into a deterministic slow-start regression using `Server.StartDelayed(900)`
  - Applied the minimal production fix by widening the legacy HTTP bridge retry budget from `4` to `5` attempts
  - Re-ran focused verification and then the full `bash scripts/release_acceptance_linux.sh --with-install` lane to green
- Files created/modified:
  - `src/fpdev.fpc.installer.iobridge.pas`
  - `tests/test_fpc_installer_iobridge.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Optional install lane RED | `bash scripts/release_acceptance_linux.sh --with-install` | pass | failed at Pascal regression `test_fpc_installer_iobridge` | FAIL |
| Focused iobridge regression | `bash scripts/run_single_test.sh tests/test_fpc_installer_iobridge.lpr` | pass | pass | OK |
| Linux release acceptance with install | `bash scripts/release_acceptance_linux.sh --with-install` | pass | pass (`270` Python tests OK, `273/273` Pascal tests pass, release build pass, CLI smoke pass, install lane pass) | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `scripts/release_acceptance_linux.sh --with-install` failed inside `test_fpc_installer_iobridge` under slower startup timing | 1 | Added a deterministic slow-start regression and widened the legacy HTTP bridge retry window from `4` to `5` attempts |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line remains complete after optional install-lane follow-up |
| Where am I going? | Stop local implementation unless a new freshly-proven seam appears |
| What's the goal? | Keep release/readiness claims aligned with current acceptance evidence, including the optional install lane when exercised |
| What have I learned? | The remaining live defect in the optional lane was a retry-budget timing seam in production code, not an acceptance-script false positive |
| What have I done? | Added a stable slow-start regression, fixed the production retry window, and proved `--with-install` green end-to-end |

## Session: 2026-04-02 (release-notes inventory sync)

### Close-out Execution Follow-up 3
- **Status:** complete
- Actions taken:
  - Audited remaining release close-out docs and found `RELEASE_NOTES.md` still advertising `271` discoverable tests while the current public inventory is `273`
  - Extended `scripts/update_test_stats.py` to synchronize `RELEASE_NOTES.md` instead of relying on a one-off manual edit
  - Captured and fixed a second seam where `python3 scripts/update_test_stats.py --check` did not accept the normalized release-notes line written by the same script
  - Re-ran focused script checks and release-doc contract coverage to green
- Files created/modified:
  - `RELEASE_NOTES.md`
  - `scripts/update_test_stats.py`
  - `tests/test_update_test_stats.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Release-notes sync seam | `python3 scripts/update_test_stats.py --check` | pass | failed because `RELEASE_NOTES.md` was out of sync | FAIL |
| Release-notes idempotency seam | `python3 scripts/update_test_stats.py --check` | pass | failed because normalized `RELEASE_NOTES.md` line did not match the script pattern | FAIL |
| Update-test-stats + release doc contracts | `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract tests.test_official_docs_cli_contract tests.test_release_scripts_contract` | pass | `27` tests OK | OK |
| Inventory sync gate | `python3 scripts/update_test_stats.py --check` | pass | pass | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `RELEASE_NOTES.md` still advertised `271` discoverable tests | 1 | Extended `scripts/update_test_stats.py` so release notes are synchronized from the shared inventory source |
| 2026-04-02 | `render_release_notes_md` rejected the already-normalized release-notes line format | 1 | Relaxed the pattern to accept both legacy and normalized formats, then added idempotency coverage |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line remains complete after release-notes sync follow-up |
| Where am I going? | Stop local changes unless a newly-proven publish seam appears or release assets become available |
| What's the goal? | Keep every public release-status document driven by the same provable inventory/evidence sources |
| What have I learned? | Small release docs drift can recur unless every public surface is attached to the same sync mechanism, and sync scripts themselves need idempotency checks |
| What have I done? | Brought `RELEASE_NOTES.md` under the shared inventory sync, fixed the script idempotency seam, and re-verified the release-doc contract suite |

## Session: 2026-04-02 (evidence-path sync)

### Close-out Execution Follow-up 4
- **Status:** complete
- Actions taken:
  - Audited the remaining public release docs and found stale March 25 evidence pointers plus a stale `271` test-inventory line in `CHANGELOG.md`
  - Extended `scripts/update_test_stats.py` so `CHANGELOG.md` now follows the same shared inventory source as README / ROADMAP / RELEASE_NOTES
  - Updated `docs/MVP_ACCEPTANCE_CRITERIA.md`, `docs/MVP_ACCEPTANCE_CRITERIA.en.md`, and `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` to the latest April 2 acceptance evidence
  - Added contract coverage so release close-out docs must reference the latest April 2 evidence and reject the old March 25 paths
  - Re-ran sync and release-doc contract verification to green
- Files created/modified:
  - `CHANGELOG.md`
  - `docs/MVP_ACCEPTANCE_CRITERIA.md`
  - `docs/MVP_ACCEPTANCE_CRITERIA.en.md`
  - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
  - `scripts/update_test_stats.py`
  - `tests/test_update_test_stats.py`
  - `tests/test_release_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Changelog inventory sync seam | `python3 scripts/update_test_stats.py --check` | pass | failed because `CHANGELOG.md` still advertised `271` discoverable tests | FAIL |
| Release evidence doc seam | `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract` | pass | failed because release docs still referenced March 25 evidence instead of April 2 evidence | FAIL |
| Inventory sync gate | `python3 scripts/update_test_stats.py --check` | pass | pass | OK |
| Sync + release-doc suites | `python3 -m unittest -v tests.test_update_test_stats tests.test_release_docs_contract tests.test_official_docs_cli_contract tests.test_release_scripts_contract tests.test_generate_release_checksums tests.test_generate_release_evidence` | pass | `35` tests OK | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `CHANGELOG.md` still advertised `271` discoverable tests | 1 | Extended `scripts/update_test_stats.py` so changelog release baseline uses the shared inventory source |
| 2026-04-02 | Close-out docs still referenced stale `2026-03-25` acceptance summary paths | 1 | Updated acceptance/owner docs to `2026-04-02` evidence and added contract coverage that rejects the stale paths |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line remains complete after evidence-path sync follow-up |
| Where am I going? | Stop local edits unless new publish seams appear or the missing release assets become available |
| What's the goal? | Keep every public release status document aligned with the latest locally proven acceptance evidence |
| What have I learned? | Even after inventory counts are synchronized, evidence pointers can still drift unless they are reviewed and contract-checked explicitly |
| What have I done? | Synced changelog inventory, updated public acceptance evidence pointers to April 2 logs, and added contracts preventing rollback to stale March 25 paths |

## Session: 2026-04-02 (release packaging verification)

### Close-out Verification Sweep
- **Status:** complete
- Actions taken:
  - Re-scanned the repository for stale release refs after the evidence-path sync and found no new locally actionable doc drift
  - Ran the remaining release packaging / checksum / evidence / owner-smoke / CI contract / wording Python suites, including `tests.test_package_release_assets`
  - Confirmed that the local close-out line now ends at external publish prerequisites rather than additional repo-local regressions
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Release packaging verification sweep | `python3 -m unittest -v tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_release_scripts_contract tests.test_release_docs_contract tests.test_ci_release_contracts tests.test_release_status_wording` | pass | `25` tests OK | OK |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out work is exhausted after the packaging/evidence verification sweep |
| Where am I going? | Wait for real release assets or owner-run checkpoints before doing more release work |
| What's the goal? | Keep the branch ready for publish without fabricating evidence that depends on missing cross-platform assets |
| What have I learned? | The remaining release path is now blocked by external publish prerequisites, not by repo-local docs or helper-script drift |
| What have I done? | Verified the remaining release packaging/evidence helper suite end-to-end and confirmed no new local seam remains |

## Session: 2026-04-02 (CI release packaging coverage)

### Close-out Execution Follow-up 5
- **Status:** complete
- Actions taken:
  - Audited the CI release-contract step and proved it did not include `tests.test_package_release_assets` or `tests.test_generate_release_checksums`
  - Captured the gap as a RED by tightening `tests.test_ci_release_contracts`
  - Updated `.github/workflows/ci.yml` so the release contract unittest list now covers package-release-assets and checksum-generation tests
  - Re-ran focused CI-contract verification and then the broader release helper suite to green
- Files created/modified:
  - `.github/workflows/ci.yml`
  - `tests/test_ci_release_contracts.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| CI release contract RED | `python3 -m unittest -v tests.test_ci_release_contracts` | pass | failed because CI omitted package-release-assets/checksum tests | FAIL |
| Focused CI release contract | `python3 -m unittest -v tests.test_ci_release_contracts` | pass | pass | OK |
| Release helper + CI contract suite | `python3 -m unittest -v tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_release_scripts_contract tests.test_release_docs_contract tests.test_ci_release_contracts tests.test_release_status_wording` | pass | `25` tests OK | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | CI release contract step omitted `tests.test_package_release_assets` and `tests.test_generate_release_checksums` | 1 | Added both tests to `.github/workflows/ci.yml` and enforced them via `tests/test_ci_release_contracts.py` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line remains complete after fixing the CI release-packaging coverage gap |
| Where am I going? | Wait for real cross-platform assets or owner-run checkpoints before further release execution |
| What's the goal? | Keep release helper behavior covered not only by local tests but also by the CI release lane |
| What have I learned? | Even when helper scripts and tests exist, CI can still lag behind unless the coverage set is contract-checked explicitly |
| What have I done? | Added package-release-assets and checksum-generation tests to CI's release contract step and proved the updated suite green |

## Session: 2026-04-02 (CI release contract breadth)

### Close-out Execution Follow-up 6
- **Status:** complete
- Actions taken:
  - Audited the release-contract unittest list again and proved it still omitted `tests.test_official_docs_cli_contract`, `tests.test_update_test_stats`, and `tests.test_ci_workflow_contract`
  - Captured the gap as a RED by tightening `tests.test_ci_release_contracts`
  - Updated `.github/workflows/ci.yml` so the release contract step now covers official-doc contracts, update-test-stats unit tests, and CI workflow contract tests
  - Re-ran focused CI-contract verification and then the expanded release contract suite to green
- Files created/modified:
  - `.github/workflows/ci.yml`
  - `tests/test_ci_release_contracts.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| CI release contract RED | `python3 -m unittest -v tests.test_ci_release_contracts` | pass | failed because CI still omitted official-doc/update-test-stats/ci-workflow tests | FAIL |
| Focused CI release contract | `python3 -m unittest -v tests.test_ci_release_contracts` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `48` tests OK | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | CI release contract step still omitted official-doc CLI contracts, update-test-stats unit tests, and CI workflow contract tests | 1 | Added all three to `.github/workflows/ci.yml` and enforced them via `tests/test_ci_release_contracts.py` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line remains complete after widening CI release-contract coverage |
| Where am I going? | Wait for real release assets or owner-run checkpoints before further release execution |
| What's the goal? | Ensure the CI fail-fast release-contract layer covers every key repo-local release contract surface |
| What have I learned? | Release helper coverage can drift in layers; after packaging/checksum coverage, the next missing layer was official docs + sync logic + CI structure contracts |
| What have I done? | Added those missing tests to CI's release contract step and proved the expanded release contract suite green |

## Session: 2026-04-02 (PowerShell owner-smoke runtime coverage)

### Close-out Execution Follow-up 7
- **Status:** complete
- Actions taken:
  - Audited the owner-smoke coverage shape and found that only the shell recorder had a runtime test while the PowerShell recorder had existence-only coverage
  - Added `tests.test_record_owner_smoke_ps1` with skip-on-missing-pwsh behavior and real transcript assertions when PowerShell is available
  - Updated `.github/workflows/ci.yml` and `tests.test_ci_release_contracts.py` so CI release-contract coverage now includes the PowerShell owner-smoke runtime test
  - Re-ran focused verification and then the expanded release contract suite to green/skip as expected
- Files created/modified:
  - `tests/test_record_owner_smoke_ps1.py`
  - `.github/workflows/ci.yml`
  - `tests/test_ci_release_contracts.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Focused PowerShell owner-smoke coverage | `python3 -m unittest -v tests.test_record_owner_smoke_ps1 tests.test_ci_release_contracts` | pass | pass (`1` test skipped because `pwsh` is unavailable locally) | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `49` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | PowerShell owner-smoke path had existence-only coverage while shell path had real runtime coverage | 1 | Added `tests/test_record_owner_smoke_ps1.py` plus CI inclusion, with skip-on-missing-pwsh behavior for unsupported local environments |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Local close-out line remains complete after adding PowerShell owner-smoke runtime coverage |
| Where am I going? | Wait for real release assets or owner-run checkpoints before further release execution |
| What's the goal? | Keep release-closeout tooling covered symmetrically across shell and PowerShell paths |
| What have I learned? | Helper coverage drift can also appear across platform variants; parity matters for owner-run release steps |
| What have I done? | Added a real PowerShell owner-smoke runtime test (skip when pwsh is absent) and wired it into CI release-contract coverage |

## Session: 2026-04-02 (Windows CI PowerShell owner-smoke execution)

### Close-out Execution Follow-up 8
- **Status:** complete
- Actions taken:
  - Reproduced the new RED in `tests.test_ci_workflow_contract` proving CI still lacked a Windows step that truly runs the PowerShell owner-smoke unit test
  - Updated `tests.test_record_owner_smoke_ps1` to create a platform-appropriate fake executable (`fpdev.cmd` on Windows, shell stub elsewhere) and to assert the platform-appropriate transcript lane
  - Added a Windows-only `Run PowerShell owner smoke unit test` step to `.github/workflows/ci.yml`
  - Re-ran focused verification and the expanded release contract suite to confirm the new CI contract is green locally and still skip-compatible without `pwsh`
- Files created/modified:
  - `tests/test_record_owner_smoke_ps1.py`
  - `.github/workflows/ci.yml`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for Windows owner-smoke CI step | `python3 -m unittest -v tests.test_ci_workflow_contract` | fail before fix | failed on missing `Run PowerShell owner smoke unit test` step | Observed |
| Focused Windows owner-smoke CI verification | `python3 -m unittest -v tests.test_ci_workflow_contract tests.test_record_owner_smoke_ps1 tests.test_ci_release_contracts` | pass | pass (`1` test skipped because `pwsh` is unavailable locally) | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `50` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | CI still only skipped the PowerShell owner-smoke runtime test on Ubuntu, so Windows runtime execution was not truly covered | 1 | Added a Windows-only CI step plus platform-aware fake executable/lane handling in `tests.test_record_owner_smoke_ps1` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Repo-local release close-out coverage now reaches the Windows PowerShell owner-smoke execution path too |
| Where am I going? | Wait for real release assets and owner-run checkpoints to finish the remaining external release work |
| What's the goal? | Keep CI's release-closeout layer symmetric across Linux, shell, and Windows PowerShell owner-smoke paths |
| What have I learned? | CI inclusion is not the same as runtime execution; platform-specific skip behavior can hide real gaps |
| What have I done? | Added the missing Windows CI execution step and made the PowerShell owner-smoke test portable across Windows/POSIX environments |

## Session: 2026-04-02 (optional install evidence handoff)

### Close-out Execution Follow-up 9
- **Status:** complete
- Actions taken:
  - Audited the release-evidence handoff path and found a mismatch: docs described the `--with-install` lane as optional/network-gated, but `scripts/generate_release_evidence.py` still required `--install-summary`
  - Added a failing test proving the script should still generate `RELEASE_EVIDENCE.md` when only the baseline summary is available
  - Relaxed `scripts/generate_release_evidence.py` so `--install-summary` is optional and missing install evidence is rendered explicitly as `not provided`
  - Tightened `tests.test_release_docs_contract` and updated the owner-checkpoint doc so the publish instructions now match the script behavior
  - Re-ran focused verification and the expanded release contract suite to confirm the handoff path stays green
- Files created/modified:
  - `scripts/generate_release_evidence.py`
  - `tests/test_generate_release_evidence.py`
  - `tests/test_release_docs_contract.py`
  - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for optional install evidence | `python3 -m unittest -v tests.test_generate_release_evidence` | fail before fix | failed because omitting `--install-summary` exited with status `2` | Observed |
| RED proof for owner-checkpoint doc sync | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because the doc did not mark install summary as optional evidence input | Observed |
| Focused release-evidence + docs verification | `python3 -m unittest -v tests.test_generate_release_evidence tests.test_release_docs_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `52` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `generate_release_evidence.py` required `--install-summary` even though the install lane is documented as optional/network-gated | 1 | Made install evidence optional, rendered absence explicitly, and synchronized the owner-checkpoint doc contract |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Repo-local release close-out tooling now supports evidence handoff even before the optional install lane has been run |
| Where am I going? | Continue only if another repo-local close-out inconsistency remains; otherwise the next real work is external asset and owner-proof execution |
| What's the goal? | Keep release helper behavior aligned with the documented close-out workflow so publish handoff stays usable at every stage |
| What have I learned? | Optional lanes need optional evidence inputs too; otherwise the toolchain silently hard-codes a stricter process than the docs describe |
| What have I done? | Added regression coverage, relaxed the evidence generator, and synchronized the owner-checkpoint instructions |

## Session: 2026-04-02 (release-evidence publish narrative)

### Close-out Execution Follow-up 10
- **Status:** complete
- Actions taken:
  - Audited the public release narrative after the evidence-helper fix and found that `RELEASE_EVIDENCE.md` was still missing from acceptance docs and release notes even though the owner-checkpoint plan requires it
  - Added a failing contract proving release-closeout docs must explicitly include `RELEASE_EVIDENCE.md`
  - Updated both acceptance-criteria variants and `RELEASE_NOTES.md` so remaining publish-time proof, exit criteria, and owner actions all acknowledge the release-evidence handoff
  - Re-ran the focused docs contract and the expanded release-contract suite to confirm the narrative is now synchronized
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `docs/MVP_ACCEPTANCE_CRITERIA.md`
  - `docs/MVP_ACCEPTANCE_CRITERIA.en.md`
  - `RELEASE_NOTES.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for release-evidence doc drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because acceptance docs omitted `RELEASE_EVIDENCE.md` | Observed |
| Focused release docs verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `53` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | Public release docs still described remaining publish-time proof as only owner checkpoints + `SHA256SUMS.txt`, omitting `RELEASE_EVIDENCE.md` | 1 | Added a doc contract and synchronized acceptance docs plus release notes to include `RELEASE_EVIDENCE.md` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Repo-local release-closeout docs now agree that `RELEASE_EVIDENCE.md` is part of the remaining publish-time proof |
| Where am I going? | Keep looking only for in-repo inconsistencies; the major remaining work is still real assets and owner sign-off outside this workspace |
| What's the goal? | Make the public release narrative match the actual close-out handoff so no publish artifact is silently omitted |
| What have I learned? | Even after helper/tooling fixes, public release docs can lag behind and understate what publish-time evidence is still required |
| What have I done? | Added a regression contract and synchronized acceptance docs plus release notes around `RELEASE_EVIDENCE.md` |

## Session: 2026-04-02 (release-notes owner smoke flow)

### Close-out Execution Follow-up 11
- **Status:** complete
- Actions taken:
  - Audited `RELEASE_NOTES.md` after the release-evidence narrative fix and found that it still described owner actions as manual smoke commands instead of using the standardized recorder/evidence scripts
  - Added a failing contract proving release notes must reference `record_owner_smoke.ps1`, `record_owner_smoke.sh`, and `generate_release_evidence.py`
  - Updated `RELEASE_NOTES.md` so owner-run instructions now point directly to the canonical recorder/checksum/evidence commands rather than inlining raw smoke commands
  - Re-ran the focused docs contract and the expanded release-contract suite to confirm release notes now align with the canonical owner-checkpoint flow
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `RELEASE_NOTES.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for release-notes owner flow drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because `RELEASE_NOTES.md` omitted recorder/evidence scripts and still inlined manual smoke commands | Observed |
| Focused release docs verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `54` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `RELEASE_NOTES.md` still described owner smoke as manual command lists instead of using the standardized recorder/evidence flow | 1 | Added a release-notes doc contract and rewrote the owner actions to reference the canonical recorder/checksum/evidence scripts |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Repo-local release notes now align with the canonical owner-checkpoint recorder/evidence flow |
| Where am I going? | Continue only if another in-repo close-out seam remains; otherwise the meaningful remaining work is external publish execution |
| What's the goal? | Keep every release-facing instruction source pointing to the same owner-run workflow |
| What have I learned? | Even after high-level narrative sync, step-by-step release notes can still drift back to manual instructions and reopen process forks |
| What have I done? | Added regression coverage and rewrote the release-notes owner actions to use the standard recorder/checksum/evidence commands |

## Session: 2026-04-02 (owner-checkpoint exit criteria)

### Close-out Execution Follow-up 12
- **Status:** complete
- Actions taken:
  - Audited the canonical owner-checkpoint plan after aligning release notes and found that its Publish Sequence already required `RELEASE_EVIDENCE.md`, but its Release Exit Criteria still omitted it
  - Added a failing contract proving the exit criteria must explicitly include `RELEASE_EVIDENCE.md`
  - Updated `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` so the canonical release exit criteria now require `RELEASE_EVIDENCE.md` to be published with the release
  - Re-ran the focused docs contract and the expanded release-contract suite to confirm the canonical doc is internally consistent again
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for owner-checkpoint exit criteria drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because `Release Exit Criteria` omitted `RELEASE_EVIDENCE.md` | Observed |
| Focused release docs verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `55` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | Canonical owner-checkpoint doc required `RELEASE_EVIDENCE.md` in Publish Sequence but omitted it from Release Exit Criteria | 1 | Added a docs contract and updated the exit criteria to require `RELEASE_EVIDENCE.md` publication |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Canonical owner-checkpoint guidance is now internally consistent about `RELEASE_EVIDENCE.md` being a required publish artifact |
| Where am I going? | Keep checking only for remaining in-repo close-out drift; otherwise the next meaningful steps are external asset generation and owner sign-off |
| What's the goal? | Eliminate contradictions between release steps and release exit criteria in the canonical handoff document |
| What have I learned? | Even a single canonical doc can drift between its procedure section and its final exit checklist, so both levels need explicit contracts |
| What have I done? | Added regression coverage and aligned the owner-checkpoint exit criteria with the already-required release-evidence publish step |

## Session: 2026-04-02 (README/ROADMAP sign-off wording)

### Close-out Execution Follow-up 13
- **Status:** complete
- Actions taken:
  - Audited the public project-status wording after aligning the canonical release docs and found that README / README.en / ROADMAP still described release sign-off as only pending Windows/macOS owner evidence
  - Added failing wording contracts proving those public status lines must now also mention `SHA256SUMS.txt` and `RELEASE_EVIDENCE.md`
  - Updated README, README.en, and ROADMAP so release sign-off now explicitly includes the remaining publish artifacts in addition to owner evidence
  - Re-ran the focused wording suite and the expanded release-contract suite to confirm the public status narrative is synchronized again
- Files created/modified:
  - `tests/test_release_status_wording.py`
  - `README.md`
  - `README.en.md`
  - `docs/ROADMAP.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for README/ROADMAP sign-off drift | `python3 -m unittest -v tests.test_release_status_wording` | fail before fix | failed because README / ROADMAP omitted `SHA256SUMS.txt` and `RELEASE_EVIDENCE.md` from release sign-off wording | Observed |
| Focused release-status wording verification | `python3 -m unittest -v tests.test_release_status_wording` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `55` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | README / ROADMAP still understated release sign-off as only pending owner evidence after publish artifacts became part of the canonical remaining proof | 1 | Tightened wording contracts and updated README, README.en, and ROADMAP to include `SHA256SUMS.txt` and `RELEASE_EVIDENCE.md` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Public status surfaces now agree that release sign-off still needs both owner evidence and the remaining publish artifacts |
| Where am I going? | Keep looking only for remaining in-repo close-out drift; otherwise the next work is outside the repo on real assets and sign-off |
| What's the goal? | Keep high-level public status wording aligned with the canonical release-closeout proof requirements |
| What have I learned? | Summary/status lines drift more easily than procedural docs, so they need explicit contract coverage too |
| What have I done? | Added wording regressions and synchronized README, README.en, and ROADMAP with the current remaining publish-time proof |

## Session: 2026-04-02 (owner-checkpoint planned assets)

### Close-out Execution Follow-up 14
- **Status:** complete
- Actions taken:
  - Audited the canonical owner-checkpoint document again and found that `RELEASE_EVIDENCE.md` was already required in both Publish Sequence and Release Exit Criteria, but was still missing from the Planned Release Assets table
  - Added a failing docs contract proving the planned-assets table must explicitly include `RELEASE_EVIDENCE.md`
  - Updated the canonical owner-checkpoint asset table so it now lists `RELEASE_EVIDENCE.md` alongside the binaries and `SHA256SUMS.txt`
  - Re-ran the focused docs contract and the expanded release-contract suite to confirm the canonical document is now consistent across inventory, procedure, and exit criteria
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for planned-assets drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because `Planned Release Assets` omitted `RELEASE_EVIDENCE.md` | Observed |
| Focused release docs verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `56` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | Canonical owner-checkpoint doc still omitted `RELEASE_EVIDENCE.md` from its planned-assets inventory even after requiring it later in the workflow | 1 | Added a docs contract and inserted `RELEASE_EVIDENCE.md` into the Planned Release Assets table |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Canonical owner-checkpoint documentation is now consistent across asset inventory, publish steps, and exit criteria |
| Where am I going? | Continue only if another in-repo close-out seam exists; otherwise the meaningful remaining work is external release execution |
| What's the goal? | Eliminate remaining contradictions inside the canonical release handoff doc |
| What have I learned? | Asset inventory tables can drift even after procedure and exit-checklist sections are fixed, so they need explicit contract coverage too |
| What have I done? | Added regression coverage and aligned the planned-assets table with the already-required `RELEASE_EVIDENCE.md` publish flow |

## Session: 2026-04-02 (changelog release baseline artifacts)

### Close-out Execution Follow-up 15
- **Status:** complete
- Actions taken:
  - Audited `CHANGELOG.md` after the other release-facing docs were synchronized and found that the `2.1.0 / Release Baseline` section still omitted the standardized owner recorder flow and the remaining publish artifacts
  - Added a failing docs contract proving the changelog baseline must explicitly mention `SHA256SUMS.txt` and `RELEASE_EVIDENCE.md`
  - Updated `CHANGELOG.md` so the `Release Baseline` now references the standardized owner recorder commands plus the checksum/evidence generation flow
  - Re-ran the focused docs contract and the expanded release-contract suite to confirm the changelog no longer lags behind the canonical release-closeout narrative
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `CHANGELOG.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for changelog close-out drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because `CHANGELOG.md` omitted `SHA256SUMS.txt` and `RELEASE_EVIDENCE.md` from the `2.1.0 / Release Baseline` | Observed |
| Focused release docs verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `57` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `CHANGELOG.md` still lagged behind the canonical release-closeout narrative by omitting the standardized owner recorder flow and the remaining publish artifacts | 1 | Added a docs contract and updated the `2.1.0 / Release Baseline` bullets to mention the recorder/checksum/evidence flow |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The changelog now reflects the same recorder/checksum/evidence close-out story as the rest of the release-facing docs |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external asset generation and owner sign-off |
| What's the goal? | Keep every public release document aligned on the same remaining publish-time proof |
| What have I learned? | Even when acceptance docs and release notes are fixed, a high-visibility summary surface like the changelog can still lag behind and reopen narrative drift |
| What have I done? | Added regression coverage and synchronized the changelog release baseline with the current standardized release-closeout artifacts |

## Session: 2026-04-02 (installation docs package-manager drift)

### Close-out Execution Follow-up 16
- **Status:** complete
- Actions taken:
  - Audited the public installation guides after the other release-facing docs were synchronized and found that both `docs/INSTALLATION*.md` files still advertised unpublished package-manager channels as a third installation method
  - Added a failing official-docs contract proving the installation guides must not present Homebrew / Chocolatey / Snap / APT commands as runnable public install paths before those channels exist
  - Updated both installation guides to remove the unpublished commands and replace them with an explicit status note that directs users back to the supported release-binary or source-build flows
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the public installation entrypoints now match the real published state
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/INSTALLATION.md`
  - `docs/INSTALLATION.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for installation-docs package-manager drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/INSTALLATION*.md` still advertised unpublished package-manager channels and commands | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `58` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | Official installation guides still presented unpublished package-manager channels as a public install method | 1 | Added an official-docs contract and replaced the fake package-manager method with an explicit status note that points users to the supported install paths |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The official installation guides now point only to currently supported install paths |
| Where am I going? | Continue only if another repo-local close-out seam remains; otherwise the remaining work is external publish execution |
| What's the goal? | Prevent public installation docs from advertising install channels that do not actually exist yet |
| What have I learned? | Even after release-closeout docs are synchronized, high-traffic user guides can still carry old “planned” pathways that need explicit contract coverage |
| What have I done? | Added regression coverage and removed unpublished package-manager commands from both installation guides |

## Session: 2026-04-02 (installation docs release-layout drift)

### Close-out Execution Follow-up 17
- **Status:** complete
- Actions taken:
  - Compared the public installation guides against the real release packaging contract and found that the guides still broke the packaged layout by pointing Windows users to a nonexistent `bin/` directory and Unix users to workflows that move only the binary away from the bundled `data/` directory
  - Confirmed the runtime consequence by checking `src/fpdev.paths.pas`, which treats a sibling `data/` directory as the portable-mode data root
  - Added a failing official-docs contract proving the installation guides must preserve the packaged release layout
  - Updated both installation guides so they now keep `fpdev` / `fpdev.exe` alongside `data/`, add the extracted directory itself to PATH, and no longer instruct users to move only the executable
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the public install instructions now match the real packaged layout
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/INSTALLATION.md`
  - `docs/INSTALLATION.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for installation-docs release-layout drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the installation guides omitted `data/`, still referenced `C:\\fpdev\\bin`, and still moved only `fpdev` into PATH directories | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `59` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | Official installation guides no longer matched the packaged release layout and would separate the executable from the bundled `data/` directory | 1 | Added an official-docs contract and rewrote the install instructions to preserve the extracted release layout and add that directory itself to PATH |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The public installation guides now match the real release-asset layout and portable-mode expectations |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep public install instructions aligned with the actual packaged release structure |
| What have I learned? | Packaging and runtime-path semantics can drift away from high-level install docs unless the docs are explicitly constrained by tests |
| What have I done? | Added layout-focused official-docs coverage and rewrote the install steps so users keep the release bundle intact |

## Session: 2026-04-02 (installation docs env/data-root drift)

### Close-out Execution Follow-up 18
- **Status:** complete
- Actions taken:
  - Audited the installation guides again after fixing the bundle layout and found that they still documented unsupported environment variables and still described the portable release config/log locations as if they lived under the user home directory
  - Confirmed the runtime truth by checking `src/fpdev.paths.pas`, where `FPDEV_DATA_ROOT` is the supported override and the default portable data root is the sibling `data/` directory next to the executable
  - Added a failing official-docs contract proving the installation guides must mention `FPDEV_DATA_ROOT`, `data/config.json`, and `data/logs/`, while dropping the unsupported env-variable examples
  - Updated both installation guides so they now describe the supported data-root override, the real portable config/log locations, the correct uninstall shape, and the supported way to move mutable data to SSD storage
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the public install docs now match the actual runtime path model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/INSTALLATION.md`
  - `docs/INSTALLATION.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for installation-docs env/data-root drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the installation guides omitted `FPDEV_DATA_ROOT`, omitted `data/config.json` / `data/logs/`, and still documented unsupported env vars | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `60` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | Official installation guides still documented unsupported env toggles and the wrong default config/log locations for the portable release | 1 | Added an official-docs contract and rewrote the env/path guidance around the supported `FPDEV_DATA_ROOT` model |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The installation guides now describe the supported data-root override and the real portable config/log paths |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external publish execution |
| What's the goal? | Keep public installation docs aligned with the runtime data-root semantics actually implemented in the code |
| What have I learned? | Even after layout fixes, docs can still drift at the environment-variable and data-root level unless those semantics are explicitly locked by tests |
| What have I done? | Added env/data-root coverage and rewrote the installation docs around the supported `FPDEV_DATA_ROOT` model |

## Session: 2026-04-02 (quickstart docs config/parallelism drift)

### Close-out Execution Follow-up 19
- **Status:** complete
- Actions taken:
  - Audited the QUICKSTART guides after aligning the installation docs and found that the entry-point docs still taught the old home-directory config paths and the unsupported `FPDEV_PARALLEL_JOBS` environment variable
  - Confirmed the runtime truth in `src/fpdev.paths.pas`, where the portable default config lives at `data/config.json` and `FPDEV_DATA_ROOT` is the supported override
  - Confirmed the parallelism model from the repository config samples, which store the value in `settings.parallel_jobs`
  - Added a failing official-docs contract proving the QUICKSTART guides must mention `FPDEV_DATA_ROOT` and `data/config.json` while dropping the stale path strings and `FPDEV_PARALLEL_JOBS`
  - Updated both QUICKSTART guides so they now describe the real portable config location, the supported data-root override, and the supported config-based parallelism workflow
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the quick-start docs now match the actual runtime/config contract
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/QUICKSTART.md`
  - `docs/QUICKSTART.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for quickstart-docs config/parallelism drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the QUICKSTART guides omitted `FPDEV_DATA_ROOT`, omitted `data/config.json`, and still documented the old home-directory config paths plus `FPDEV_PARALLEL_JOBS` | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `61` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The QUICKSTART guides still documented the wrong portable config paths and the unsupported `FPDEV_PARALLEL_JOBS` override | 1 | Added a QUICKSTART-specific official-docs contract and rewrote the quick-start guidance around `data/config.json`, `FPDEV_DATA_ROOT`, and `settings.parallel_jobs` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The QUICKSTART guides now match the supported data-root and config semantics used by the runtime |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the high-traffic quick-start path aligned with the same runtime contract already enforced in the installation docs |
| What have I learned? | Fixing installation docs is not enough if the quick-start guide still reintroduces stale config-path and env-var advice |
| What have I done? | Added QUICKSTART contract coverage and rewrote both quick-start guides around the supported `FPDEV_DATA_ROOT` + `settings.parallel_jobs` model |

## Session: 2026-04-02 (fpdevrc docs global-config path drift)

### Close-out Execution Follow-up 20
- **Status:** complete
- Actions taken:
  - Audited the FPDEVRC specification docs after aligning INSTALLATION and QUICKSTART, and found that they still hard-coded the global config as `~/.fpdev/config.json`
  - Confirmed the runtime truth in `src/fpdev.paths.pas`, where the active config path follows the active data root, including portable `data/config.json`, `FPDEV_DATA_ROOT`, `XDG_DATA_HOME`, and Windows `%APPDATA%\fpdev\config.json`
  - Confirmed in `src/fpdev.config.project.pas` that project-config resolution consumes higher-level global defaults and does not itself pin the global config to a single home-directory path
  - Added a failing official-docs contract proving the FPDEVRC docs must describe the active data-root-based global config paths
  - Updated both FPDEVRC spec docs so they now describe the supported active `config.json` model instead of a single stale Unix home path
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the FPDEVRC docs now match the runtime path model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/FPDEVRC_SPEC.md`
  - `docs/FPDEVRC_SPEC.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for fpdevrc-docs global-config drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the FPDEVRC docs omitted `FPDEV_DATA_ROOT`, `data/config.json`, `XDG_DATA_HOME`, and `%APPDATA%\fpdev\config.json` | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `62` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The FPDEVRC specification docs still hard-coded the global config path as `~/.fpdev/config.json` instead of following the active data-root model | 1 | Added an FPDEVRC-specific official-docs contract and rewrote the spec around the active `config.json` path semantics |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The FPDEVRC spec docs now match the active data-root and global-config semantics implemented by the runtime |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the project-configuration spec aligned with the same runtime path contract already enforced in installation and quick-start docs |
| What have I learned? | Even after high-traffic user docs are fixed, deeper spec docs can still preserve stale global-path assumptions unless they get explicit contract coverage |
| What have I done? | Added FPDEVRC contract coverage and rewrote both spec docs around the active `config.json` / data-root model |

## Session: 2026-04-02 (fpc management docs toolchain-layout drift)

### Close-out Execution Follow-up 21
- **Status:** complete
- Actions taken:
  - Audited the FPC management docs after fixing the broader data-root guidance and found that the FPC-specific docs still showed the legacy `~/.fpdev/fpc/<version>` layout, a flat `sources/fpc-<version>` layout, and a hard-coded `~/.fpdev/config.json` diagnostic path
  - Confirmed the runtime truth in `src/fpdev.paths.pas`, where installed toolchains live under `<data-root>/toolchains/fpc/<version>`
  - Confirmed the source checkout layout in `src/fpdev.fpc.installversionflow.pas`, where FPC sources live under `<install-root>/sources/fpc/fpc-<version>`
  - Confirmed with `tests/test_fpc_verify.lpr` that verification code already treats `InstallRoot/toolchains/fpc/3.2.2/bin` as the canonical install layout
  - Added a failing official-docs contract proving the FPC management docs must describe the data-root-based toolchain/source layout and the active config path
  - Updated both FPC management docs so they now describe the canonical `toolchains/fpc` and `sources/fpc/fpc-...` layout plus the active `config.json` path semantics
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the FPC docs now match the runtime layout model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/FPC_MANAGEMENT.md`
  - `docs/FPC_MANAGEMENT.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for fpc-management docs toolchain-layout drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the FPC management docs omitted `toolchains/fpc/3.2.2`, `sources/fpc/fpc-3.2.2`, `FPDEV_DATA_ROOT`, and `data/config.json`, while still carrying legacy install/config paths | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `63` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The FPC management docs still described the legacy install/source layout and a hard-coded home-directory config path | 1 | Added an FPC-management-specific official-docs contract and rewrote the directory, install_path, and diagnostics guidance around the canonical data-root layout |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The FPC management docs now match the canonical toolchain/source layout and active config semantics used by the runtime |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the FPC-focused docs aligned with the same data-root contract already enforced elsewhere in the public docs |
| What have I learned? | Even after high-level docs are fixed, product-specific topic docs can preserve older directory structures unless they get their own contract coverage |
| What have I done? | Added FPC-management contract coverage and rewrote both topic docs around the canonical `toolchains/fpc` plus `sources/fpc/fpc-...` layout |

## Session: 2026-04-02 (toolchain docs active-data-root drift)

### Close-out Execution Follow-up 22
- **Status:** complete
- Actions taken:
  - Audited the toolchain topic docs after aligning the FPC docs and found that the offline-mode section still assumed a repo-root `.fpdev/` data root
  - Confirmed the runtime truth in `src/fpdev.paths.pas`, where the data root comes from portable `data/`, `FPDEV_DATA_ROOT`, or the platform default directories instead of a repository-root convention
  - Confirmed in `src/fpdev.source.pas` that `ensure-source` writes into `<data-root>/sandbox/sources/...` and `import-bundle` writes into `<data-root>/cache/toolchain/`
  - Added a failing official-docs contract proving the toolchain docs must describe the active data-root-based cache/sandbox/log/lock paths
  - Updated both toolchain docs so they now describe the active data root, the canonical `<data-root>/cache|sandbox|logs|locks` layout, and the real offline import targets
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the toolchain docs now match the runtime storage model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/toolchain.md`
  - `docs/toolchain.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for toolchain-docs active-data-root drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the toolchain docs still used repo-root `.fpdev/` paths instead of `<data-root>/cache|sandbox|logs|locks` and their derived import locations | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `64` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The toolchain topic docs still assumed a repository-root `.fpdev/` data root and derived all offline paths from that outdated convention | 1 | Added a toolchain-docs contract and rewrote the offline-mode section around the active data-root model used by the runtime |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The toolchain docs now match the active data-root, sandbox, and cache semantics implemented by the runtime |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the offline-toolchain docs aligned with the same active data-root contract already enforced across the rest of the public docs |
| What have I learned? | Topic-specific offline workflows can keep repo-local assumptions alive even after the broader install/config docs are fixed |
| What have I done? | Added toolchain-docs contract coverage and rewrote both toolchain docs around the active `<data-root>` model |

## Session: 2026-04-02 (repo spec mirror-config path drift)

### Close-out Execution Follow-up 23
- **Status:** complete
- Actions taken:
  - Audited the repository-spec docs after aligning the broader config-path story and found that the mirror-configuration section still hard-coded `~/.fpdev/config.json`
  - Confirmed the runtime truth in `src/fpdev.paths.pas`, where the active config path follows the active data root instead of a fixed home-directory path
  - Confirmed in `src/fpdev.config.commandflow.pas` that mirror-related settings are persisted through `GetConfigPath`, so the spec should describe the active `config.json` path rather than a single Unix path
  - Added a failing official-docs contract proving the repo-spec docs must describe the active config path used for mirror settings
  - Updated both repository-spec docs so they now describe the active `config.json` location for portable, `FPDEV_DATA_ROOT`, XDG, and Windows APPDATA scenarios
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the mirror-config docs now match the runtime config-path model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/REPO_SPECIFICATION.md`
  - `docs/REPO_SPECIFICATION.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for repo-spec mirror-config drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the repo-spec docs omitted `FPDEV_DATA_ROOT`, `data/config.json`, `XDG_DATA_HOME`, and `%APPDATA%\\fpdev\\config.json` for mirror configuration | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `65` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The repository-spec docs still hard-coded the mirror-settings path to `~/.fpdev/config.json` instead of following the active config path model | 1 | Added a repo-spec contract and rewrote the mirror-settings section around the active `config.json` location |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The repository-spec docs now match the active config-path model used for mirror configuration |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the repository-spec docs aligned with the same active config-path contract already enforced across the rest of the public docs |
| What have I learned? | Small “user configuration” notes in spec docs can silently reintroduce hard-coded home-directory paths unless they get explicit contract coverage |
| What have I done? | Added repo-spec contract coverage and rewrote both repository-spec docs around the active `config.json` path model |

## Session: 2026-04-02 (config-architecture docs active-config drift)

### Close-out Execution Follow-up 24
- **Status:** complete
- Actions taken:
  - Audited the config-architecture docs after aligning the public config-path story and found that the architecture examples still hard-coded `~/.fpdev/config.json` and `%APPDATA%\.fpdev\config.json`
  - Confirmed the runtime truth in `src/fpdev.paths.pas`, where the active config path follows the active data root, and in `src/fpdev.config.core.pas`, where `TConfigManager.GetDefaultConfigPath` delegates to `GetConfigPath`
  - Added a failing official-docs contract proving the config-architecture docs must describe the active config-path model instead of hard-coded home-directory paths
  - Updated both config-architecture docs so they now show default-path construction through `TConfigManager.Create` / `TFPDevConfigManager.Create` and explain the active `config.json` path for portable, `FPDEV_DATA_ROOT`, XDG, and Windows APPDATA scenarios
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the architecture docs now match the runtime config-path model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/config-architecture.md`
  - `docs/config-architecture.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for config-architecture active-config drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the config-architecture docs still hard-coded `~/.fpdev/config.json` and `%APPDATA%\.fpdev\config.json` instead of the active config-path model | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `66` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The config-architecture docs still taught hard-coded home-directory config paths instead of the runtime active-config model | 1 | Added a config-architecture contract and rewrote the examples plus config-path explanation around the active `config.json` semantics |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The config-architecture docs now match the active config-path semantics implemented by `TConfigManager` |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the architecture docs aligned with the same active config-path contract already enforced across the rest of the public docs |
| What have I learned? | Even developer-facing architecture examples can preserve stale implementation habits unless they get their own regression coverage |
| What have I done? | Added config-architecture contract coverage and rewrote both architecture docs around the active `config.json` path model |

## Session: 2026-04-02 (manifest-usage active-cache-path drift)

### Close-out Execution Follow-up 25
- **Status:** complete
- Actions taken:
  - Audited `docs/MANIFEST-USAGE.md` after aligning the broader config-path story and found that it still hard-coded `~/.fpdev/cache/manifests/fpc.json` and `~/.fpdev/toolchains/fpc/<version>`
  - Confirmed the runtime truth in `src/fpdev.manifest.cache.pas`, where the default manifest cache dir derives from `GetCacheDir + '/manifests'`, and in `src/fpdev.cmd.fpc.update_manifest.pas`, where the command resolves its cache dir from the active configuration
  - Confirmed in `src/fpdev.paths.pas` that the canonical FPC install directory remains `toolchains/fpc/<version>` under the active root
  - Added a failing official-docs contract proving the manifest usage guide must describe the active manifest-cache and install-path model instead of hard-coded home-directory paths
  - Updated `docs/MANIFEST-USAGE.md` so it now explains the active data-root path selection and rewrites the cache/install examples around `<data-root>/cache/manifests/fpc.json` and `<data-root>/toolchains/fpc/<version>`
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the manifest guide now matches the runtime path model
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/MANIFEST-USAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for manifest-usage active-cache-path drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `MANIFEST-USAGE.md` still hard-coded `~/.fpdev/cache/manifests/fpc.json` and `~/.fpdev/toolchains/fpc/<version>` instead of the active path model | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `67` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `MANIFEST-USAGE.md` still taught hard-coded manifest cache and install paths under `~/.fpdev/` instead of the active root model | 1 | Added a manifest-usage contract and rewrote the path guidance plus shell examples around `<data-root>` semantics |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The manifest usage guide now matches the active manifest-cache and toolchain-install path semantics used by the runtime |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the manifest user guide aligned with the same active path contract already enforced across the rest of the public docs |
| What have I learned? | Topic-specific user guides can reintroduce stale path assumptions even after the broader install/config docs are repaired |
| What have I done? | Added manifest-usage contract coverage and rewrote the guide around the active `<data-root>` cache/install model |

## Session: 2026-04-02 (faq project-local install guidance drift)

### Close-out Execution Follow-up 26
- **Status:** complete
- Actions taken:
  - Audited `docs/FAQ.md` and `docs/FAQ.en.md` after aligning the broader path story and found that the “project-scoped installation” answer still pointed users to `.fpdev/toolchains/`
  - Confirmed the public/runtime truth from the existing path-alignment work: project-local isolation is achieved by pointing `FPDEV_DATA_ROOT` at a project-local directory, while the canonical install layout remains `<data-root>/toolchains/fpc/<version>`
  - Added a failing official-docs contract proving the FAQ must describe project-local isolation through the active data-root model instead of the legacy `.fpdev/toolchains/` convention
  - Updated both FAQ docs so they now show explicit `FPDEV_DATA_ROOT` usage and the resulting `<data-root>/toolchains/fpc/3.2.2` install location
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the FAQ now matches the rest of the public install-path guidance
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/FAQ.md`
  - `docs/FAQ.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for FAQ project-local install drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the FAQ still described project-scoped install output as `.fpdev/toolchains/` instead of the active data-root model | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `68` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The FAQ still taught implicit project-scoped installs under `.fpdev/toolchains/` instead of the active data-root isolation model | 1 | Added a FAQ contract and rewrote the answer around explicit `FPDEV_DATA_ROOT` usage plus the canonical `<data-root>/toolchains/fpc/3.2.2` layout |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The FAQ now matches the active data-root model for project-local install isolation |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep FAQ-level guidance consistent with the same install-path contract already enforced across the rest of the public docs |
| What have I learned? | Short FAQ answers can preserve obsolete workflows long after the deeper technical docs are corrected |
| What have I done? | Added FAQ contract coverage and rewrote the project-local install answer around explicit `FPDEV_DATA_ROOT` isolation |

## Session: 2026-04-02 (roadmap install-path success-metric drift)

### Close-out Execution Follow-up 27
- **Status:** complete
- Actions taken:
  - Audited the live `docs/ROADMAP.md` status document after aligning the public install-path story and found that its Phase 2 success metrics still marked `.fpdev/toolchains/` and `~/.fpdev/fpc/` as achieved installation models
  - Confirmed the current truth from the already-aligned public docs: project-local isolation is now expressed through `FPDEV_DATA_ROOT`, and the canonical install layout is `<data-root>/toolchains/fpc/<version>`
  - Added a failing official-docs contract proving the roadmap success metrics must describe the active install-path model instead of the legacy project/user-scoped path pair
  - Updated `docs/ROADMAP.md` so both the Scope-Aware principle and the Phase 2 success metrics now point at the active data-root install model
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the roadmap no longer reintroduces the old install-path story
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/ROADMAP.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for roadmap install-path success-metric drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `ROADMAP.md` still described Phase 2 install success in terms of `.fpdev/toolchains/` and `~/.fpdev/fpc/` instead of the active data-root model | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `69` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `ROADMAP.md` still treated legacy project/user-scoped install paths as current success metrics | 1 | Added a roadmap contract and rewrote both the Scope-Aware principle and Phase 2 success metrics around the active data-root install model |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The live roadmap now matches the active data-root install-path model used across the rest of the public docs |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the roadmap/status document aligned with the same install-path contract already enforced across the rest of the public docs |
| What have I learned? | Even “success metrics” sections in status docs can silently preserve obsolete architecture assumptions if they are not contract-checked |
| What have I done? | Added roadmap install-path contract coverage and rewrote the relevant roadmap language around the active data-root model |

## Session: 2026-04-02 (todo-fpc-v1 active-install-model drift)

### Close-out Execution Follow-up 28
- **Status:** complete
- Actions taken:
  - Audited `docs/TODO-FPC-v1.md` after aligning `ROADMAP.md` and found that the live philosophy doc still described the legacy install/data-root model (`FPDEV_HOME`, `%LOCALAPPDATA%/fpdev`, implicit `.fpdev/` project mode, and `--scope`)
  - Re-verified the runtime/public truth in `src/fpdev.paths.pas` and `src/fpdev.cmd.fpc.install.pas`: active data root comes from portable `data/`, explicit `FPDEV_DATA_ROOT`, `%APPDATA%\\fpdev`, or `$XDG_DATA_HOME/fpdev` with `~/.fpdev` fallback, and the current install CLI exposes `--from-source`, `--from-binary`, `--from=`, `--jobs=`, `--prefix=`, `--offline`, and `--no-cache`
  - Checked `src/fpdev.fpc.activation.pas` / `src/fpdev.fpc.activator.pas` so the fix would preserve the still-live `.fpdev/env` activation behavior while removing the stale automatic data-root story
  - Added a failing official-docs contract proving `TODO-FPC-v1.md` must use the active data-root install model
  - Updated `docs/TODO-FPC-v1.md` so its philosophy, directory strategy, install options, and default install path now match the active `<data-root>/toolchains/fpc/<version>` model
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the live philosophy doc no longer reintroduces the old scope-driven install path story
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/TODO-FPC-v1.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for TODO-FPC-v1 active-install-model drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `TODO-FPC-v1.md` still described `FPDEV_HOME`, `%LOCALAPPDATA%/fpdev`, implicit `.fpdev/` project mode, and `--scope` instead of the active data-root model | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `70` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `TODO-FPC-v1.md` still taught the legacy scope/data-root install model even though `ROADMAP.md` treats it as a live philosophy source | 1 | Added a TODO-FPC-v1 contract and rewrote the philosophy/install-path language around the active data-root model while preserving the still-live activation script story |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The live `TODO-FPC-v1.md` philosophy doc now matches the active data-root install-path model used across the rest of the public docs |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep even the roadmap-referenced philosophy docs aligned with the same install-path contract already enforced across the rest of the public docs |
| What have I learned? | Live design docs can silently reintroduce stale runtime assumptions even after the user-facing guides are repaired |
| What have I done? | Added TODO-FPC-v1 contract coverage and rewrote the live philosophy/install-path language around the active data-root model |

## Session: 2026-04-02 (roadmap activate-flag drift)

### Close-out Execution Follow-up 29
- **Status:** complete
- Actions taken:
  - Scanned the remaining live docs after the TODO-FPC-v1 alignment and found that `docs/ROADMAP.md` still advertised `--activate` in its Development Philosophy section
  - Re-verified the runtime/help truth in `src/fpdev.cmd.fpc.install.pas`, `src/fpdev.help.details.fpc.pas`, and `src/fpdev.i18n.strings.pas`: the current install CLI exposes `--from-source`, `--from-binary`, `--from=`, `--jobs=`, `--prefix=`, `--offline`, and `--no-cache`, but not `--activate`
  - Added a failing official-docs contract proving the roadmap must not advertise the removed install activate flag
  - Updated `docs/ROADMAP.md` so the activation principle now points users to explicit `fpdev fpc use <version>` after install instead of the removed `--activate`
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the live roadmap/status doc now matches the shipped CLI help surface
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/ROADMAP.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for roadmap activate-flag drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `ROADMAP.md` still contained `` `--activate` `` even though current install help no longer exposes that flag | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `71` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `ROADMAP.md` still advertised the removed `install --activate` path even after the live install philosophy had been updated elsewhere | 1 | Added a roadmap contract and rewrote the activation principle around explicit post-install `use` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The live `ROADMAP.md` document now matches the shipped CLI activation surface as well as the active install-path model |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the roadmap/status document aligned with the real install/activation surface, not just the broader path model |
| What have I learned? | Even after path semantics are fixed, small stale flag references in status docs can still mislead users toward removed CLI behavior |
| What have I done? | Added roadmap activate-flag contract coverage and removed the stale `--activate` guidance from the live roadmap |

## Session: 2026-04-02 (quickstart install-verbose drift)

### Close-out Execution Follow-up 30
- **Status:** complete
- Actions taken:
  - Scanned the remaining live user-facing docs after the roadmap fix and found that `docs/QUICKSTART.md` and `docs/QUICKSTART.en.md` still told users to run `fpdev fpc install 3.2.2 --from-source --verbose` for diagnostics
  - Re-verified the command surface in `src/fpdev.cmd.fpc.install.pas`: unknown options are rejected, and the supported install options remain `--from-source`, `--from-binary`, `--from=`, `--jobs=`, `--prefix=`, `--offline`, and `--no-cache`
  - Added a failing official-docs contract proving the quickstart guides must not advertise the unsupported install verbose flag
  - Updated both quickstart guides so the troubleshooting answer now tells users to re-run the supported install command and inspect the active data root's `logs/` directory
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the quickstart guides now match the shipped install CLI surface
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/QUICKSTART.md`
  - `docs/QUICKSTART.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for quickstart install-verbose drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because both quickstart guides still recommended `fpdev fpc install 3.2.2 --from-source --verbose` even though `install` rejects unknown options | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `72` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The quickstart guides still recommended an unsupported `install --verbose` flag that would send users straight to usage errors | 1 | Added a quickstart contract and rewrote the troubleshooting advice around the supported install command plus the active data-root logs directory |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The quickstart guides now match the shipped `fpdev fpc install` option surface as well as the active data-root diagnostics story |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the user-entry quickstart docs aligned with the real install command surface so copy-paste guidance does not fail immediately |
| What have I learned? | Small troubleshooting snippets in onboarding docs can be just as dangerous as larger architecture drift because users copy them verbatim |
| What have I done? | Added quickstart install-verbose contract coverage and replaced the unsupported flag guidance with a supported diagnostic path |

## Session: 2026-04-02 (quickstart binary-first install drift)

### Close-out Execution Follow-up 31
- **Status:** complete
- Actions taken:
  - Re-read the quickstart install section after removing the unsupported verbose flag and found a larger onboarding drift: the guide still made `--from-source` the default recommended FPC install path
  - Cross-checked the already-aligned user guidance in `docs/FAQ.md` and `docs/FPC_MANAGEMENT.md`, which both describe FPC installation as binary-first with source builds only when needed
  - Added a failing official-docs contract proving the quickstart guides must not recommend source installs as the default path
  - Updated both quickstart guides so the first-run FPC install path is now `fpdev fpc install 3.2.2`, while `--from-source` remains as an explicit alternative for source builds
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the onboarding docs now match the binary-first installation story used elsewhere in the live docs
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/QUICKSTART.md`
  - `docs/QUICKSTART.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for quickstart binary-first install drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because both quickstart guides still paired “recommended version” with `fpdev fpc install 3.2.2 --from-source` | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `73` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The quickstart guides still recommended source builds as the default FPC install path, conflicting with the already-aligned binary-first docs | 1 | Added a quickstart binary-first contract and rewrote the install step to lead with the binary path while keeping source builds as an opt-in fallback |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The quickstart guides now match the binary-first install strategy as well as the active data-root path story and supported flag surface |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the first-run onboarding flow aligned with the same installation strategy already enforced in the rest of the live docs |
| What have I learned? | Onboarding docs can preserve a “works eventually” path that is still the wrong default, even after deeper command references are corrected |
| What have I done? | Added quickstart binary-first contract coverage and rewrote the FPC install step around the default binary path plus explicit source fallback |

## Session: 2026-04-02 (quickstart package-status drift)

### Close-out Execution Follow-up 32
- **Status:** complete
- Actions taken:
  - Re-scanned the live quickstart after the install-path fixes and found that the Chinese package-management section still labeled `fpdev package search` and `fpdev package install` as “功能开发中”
  - Re-verified the runtime surface: package search/install commands are registered, have help text, and are covered by CLI/registry tests
  - Added a failing official-docs contract proving the quickstart must not mark those package commands as “in development”
  - Updated `docs/QUICKSTART.md` to remove the stale status labels so it matches the English quickstart and the actual CLI surface
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the quickstart status wording now matches the implemented package-command surface
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/QUICKSTART.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for quickstart package-status drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/QUICKSTART.md` still contained `功能开发中` beside `fpdev package search` and `fpdev package install` | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `74` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The Chinese quickstart still marked implemented package commands as “in development,” creating a cross-language status mismatch | 1 | Added a quickstart package-status contract and removed the stale labels from the Chinese onboarding doc |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The quickstart docs now align on the implemented package-command surface as well as the install strategy and supported flags |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the first-run onboarding docs free of stale status labels that contradict the shipped CLI surface |
| What have I learned? | Even after command examples are correct, stale “status” labels can still distort user expectations about what exists today |
| What have I done? | Added quickstart package-status contract coverage and removed the stale “功能开发中” labels from the Chinese quickstart |

## Session: 2026-04-02 (quickstart backup-path drift)

### Close-out Execution Follow-up 33
- **Status:** complete
- Actions taken:
  - Re-scanned the quickstart tips after the package-status cleanup and found that both the Chinese and English guides still told users to back up a `.fpdev` directory
  - Cross-checked the already-aligned path guidance in the same quickstart docs: configuration and mutable state are now described in terms of the active data root, with portable releases using `data/` and explicit overrides using `FPDEV_DATA_ROOT`
  - Added a failing official-docs contract proving the quickstart backup guidance must describe the active data root instead of a legacy `.fpdev` directory
  - Updated both quickstart guides so the backup tip now points to the active data root, explicitly naming the portable `data/` directory and `FPDEV_DATA_ROOT`
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the onboarding docs no longer reintroduce the legacy `.fpdev` backup path
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/QUICKSTART.md`
  - `docs/QUICKSTART.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for quickstart backup-path drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because both quickstart guides still recommended backing up `.fpdev` instead of the active data root | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | pass | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `75` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The quickstart guides still described backups in terms of a legacy `.fpdev` directory instead of the active data-root model | 1 | Added a quickstart backup-path contract and rewrote the backup tip around `data/` and `FPDEV_DATA_ROOT` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The quickstart guides now align on supported flags, install strategy, package-command status, and active data-root backup guidance |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep even the small operational tips in onboarding docs aligned with the same active data-root model as the rest of the live docs |
| What have I learned? | Legacy path assumptions can survive in “tips” sections long after the main install/config guidance is repaired |
| What have I done? | Added quickstart backup-path contract coverage and rewrote the backup tip around the active data root |

## Session: 2026-04-02 (manifest migration dry-run drift)

### Close-out Execution Follow-up 34
- **Status:** complete
- Actions taken:
  - Re-scanned remaining live maintenance docs after the quickstart cleanup and found that `docs/MANIFEST-MIGRATION.md` still advertised three unsupported install dry-run commands
  - Re-verified the current command surface in `src/fpdev.cmd.fpc.install.pas`, `src/fpdev.cmd.lazarus.install.pas`, `src/fpdev.cmd.cross.install.pas`, and `src/fpdev.cmd.cross.build.pas`: only `cross build --dry-run` is a valid dry-run entrypoint
  - Added a failing official-docs contract proving the manifest migration guide must not advertise `install --dry-run` for FPC, Lazarus, or cross installs
  - Updated `docs/MANIFEST-MIGRATION.md` so it now points maintainers at the primary parser contract, supported `install --help` checks, and the real `cross build --dry-run` path
  - Re-ran the focused official-docs suite and the expanded release-contract suite to confirm the migration guide now matches the shipped install/build CLI surface
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/MANIFEST-MIGRATION.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for manifest migration dry-run drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/MANIFEST-MIGRATION.md` still contained three unsupported `install --dry-run` examples and lacked the supported verification commands required by the new contract | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `24` tests OK | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `76` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/MANIFEST-MIGRATION.md` still advertised unsupported `fpc/lazarus/cross install --dry-run` examples | 1 | Added a manifest-migration docs contract and rewrote the guide around `test_manifest_parser`, supported `install --help`, and `cross build --dry-run` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The manifest migration guide now aligns with the shipped install/build CLI surface as well as the parser contract |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep even historical migration docs aligned with the real command surface so maintainers are not sent into usage errors by copy-paste examples |
| What have I learned? | Historical maintenance docs can preserve removed CLI flags long after the primary onboarding docs are repaired, so they need the same contract treatment |
| What have I done? | Added manifest-migration dry-run contract coverage and replaced the stale install dry-run examples with supported verification commands |

## Session: 2026-04-02 (roadmap scope-flag drift)

### Close-out Execution Follow-up 35
- **Status:** complete
- Actions taken:
  - Re-scanned the live roadmap after the manifest migration cleanup and found that `docs/ROADMAP.md` still described Phase 2.1 as `Scoped Installation` and still claimed `Implement --scope (project/user/system)`
  - Re-verified the current public install surface in `src/fpdev.cmd.fpc.install.pas`, `src/fpdev.help.details.fpc.pas`, and `src/fpdev.i18n.strings.pas`: the shipped install model still exposes `--prefix` and explicit data-root control, but not `install --scope`
  - Cross-checked `src/fpdev.fpc.activation.pas` and `src/fpdev.fpc.activator.pas` so the fix would preserve the still-live project/user activation artifact story instead of flattening everything into a single scope-less description
  - Added a failing official-docs contract proving the roadmap must not advertise the removed install scope flag
  - Updated `docs/ROADMAP.md` so Phase 2.1 now describes custom install roots plus activation artifacts, and re-ran the focused and expanded release-contract suites to green
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/ROADMAP.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for roadmap scope-flag drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/ROADMAP.md` still contained `2.1 Scoped Installation` / `Implement --scope (project/user/system)` and had not been rewritten around `FPDEV_DATA_ROOT` or `--prefix` | Observed |
| Focused official docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `25` tests OK | OK |
| Expanded release contract suite | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `77` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/ROADMAP.md` still advertised the removed `install --scope` path even after the live install model had been aligned elsewhere | 1 | Added a roadmap scope-flag contract and rewrote Phase 2.1 around `FPDEV_DATA_ROOT`, `--prefix`, and scope-aware activation artifacts |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The live roadmap now aligns with the shipped install surface as well as the still-real activation-scope artifacts |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the status/roadmap layer from reintroducing removed install switches after the lower-level docs have already been repaired |
| What have I learned? | Roadmap summaries can preserve outdated “completed feature” labels that no longer match the current public CLI contract, even when the detailed docs are fixed |
| What have I done? | Added roadmap scope-flag contract coverage and rewrote Phase 2.1 around custom install roots plus activation artifacts |

## Session: 2026-04-02 (contributor docs data-root drift)

### Close-out Execution Follow-up 36
- **Status:** complete
- Actions taken:
  - Re-scanned contributor-facing repository docs after the roadmap cleanup and found that `AGENTS.md` and `WARP.md` still hard-coded the old Windows `.fpdev` path and missed the active data-root model
  - Re-verified the source of truth in `src/fpdev.paths.pas`: the current runtime resolves state via `FPDEV_DATA_ROOT`, portable `data/`, Windows `%APPDATA%\\fpdev`, and XDG/fallback semantics
  - Added a failing contributor-doc contract proving the repo guidance must describe the active data-root paths instead of the stale Windows `.fpdev` layout
  - Updated `AGENTS.md` and `WARP.md` so both now describe portable, override, Windows, and XDG/fallback path semantics consistently
  - Re-ran the focused contributor-doc suite and a broader close-out regression bundle to confirm the new contributor contract did not regress the release/doc contract surfaces
- Files created/modified:
  - `tests/test_contributor_docs_contract.py`
  - `AGENTS.md`
  - `WARP.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for contributor-doc data-root drift | `python3 -m unittest -v tests.test_contributor_docs_contract` | fail before fix | failed because `AGENTS.md` lacked `FPDEV_DATA_ROOT` / XDG guidance and still advertised `%APPDATA%\\.fpdev\\`; `WARP.md` still hard-coded `%APPDATA%\\.fpdev\\config.json` | Observed |
| Focused contributor-doc verification | `python3 -m unittest -v tests.test_contributor_docs_contract` | pass | `3` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `80` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `AGENTS.md` and `WARP.md` still taught contributor-facing path semantics using the stale Windows `.fpdev` layout | 1 | Added a contributor-doc data-root contract and rewrote both docs around the active data-root model from `src/fpdev.paths.pas` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Contributor-facing repository docs now align with the same active data-root semantics used by the runtime and user-facing docs |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep repository guidance from reintroducing stale path assumptions that would contaminate future code, tests, or docs |
| What have I learned? | Contributor docs can lag behind user docs and quietly re-seed obsolete path conventions back into the codebase if they are not contract-checked |
| What have I done? | Added contributor-doc data-root contract coverage and rewrote `AGENTS.md` plus `WARP.md` around the active data-root model |

## Session: 2026-04-02 (legacy release-notes version-command drift)

### Close-out Execution Follow-up 37
- **Status:** complete
- Actions taken:
  - Re-scanned top-level public markdown after the contributor-doc cleanup and found that `RELEASE_NOTES_v1.1.md` still told users to verify upgrades with `fpdev version`
  - Re-verified the current version-command source of truth in `src/fpdev.cmd.system.version.pas`, `src/fpdev.help.rootview.pas`, `src/fpdev.help.usage.pas`, and `tests/test_command_registry.lpr`: the shipped CLI now exposes `fpdev system version`
  - Added a failing release-doc contract proving the legacy release notes must use the current public version command
  - Updated both upgrade instruction blocks in `RELEASE_NOTES_v1.1.md` so they now use `fpdev system version`
  - Re-ran the focused release-doc suite and the broader close-out regression bundle to confirm the legacy release note no longer advertises the removed top-level version command
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `RELEASE_NOTES_v1.1.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for legacy release-notes version drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because `RELEASE_NOTES_v1.1.md` still used `fpdev version` and lacked `fpdev system version` in its upgrade instructions | Observed |
| Focused release-doc verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | `14` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `81` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `RELEASE_NOTES_v1.1.md` still advertised the removed top-level `fpdev version` command in public upgrade instructions | 1 | Added a release-doc contract and rewrote both upgrade verification examples to use `fpdev system version` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Historical top-level release notes now align with the shipped public version command as well as the current release and contributor docs |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep public upgrade instructions from reintroducing removed top-level commands, even in historical release-note files |
| What have I learned? | Historical release notes can quietly preserve old copy-paste commands long after the main docs are corrected, so they also need contract coverage when they remain top-level docs |
| What have I done? | Added legacy release-note version-command contract coverage and replaced `fpdev version` with `fpdev system version` in `RELEASE_NOTES_v1.1.md` |

## Session: 2026-04-02 (legacy release-layout drift)

### Close-out Execution Follow-up 38
- **Status:** complete
- Actions taken:
  - Re-read the same `RELEASE_NOTES_v1.1.md` upgrade section after fixing the version command and found that the Linux/macOS steps still split out a single `fpdev` binary with `sudo mv`, contradicting the current portable release layout guidance
  - Cross-checked the source of truth in `docs/INSTALLATION.md` and `docs/INSTALLATION.en.md`, which now require keeping `fpdev` beside the bundled `data/` directory
  - Added a failing release-doc contract proving the legacy release notes must preserve the portable release layout and use explicit executable paths
  - Updated `RELEASE_NOTES_v1.1.md` so the upgrade instructions now replace the extracted release directory as a whole, use explicit executable paths on Windows and Linux/macOS, and no longer suggest moving a detached binary into `/usr/local/bin`
  - Re-ran the focused release-doc suite and the broader close-out regression bundle to confirm the legacy release note now matches the current portable-release story
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `RELEASE_NOTES_v1.1.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for legacy release-layout drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because `RELEASE_NOTES_v1.1.md` still lacked explicit executable paths, did not mention the bundled `data/` layout, and still contained `sudo mv fpdev /usr/local/bin/` | Observed |
| Focused release-doc verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | `15` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `82` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `RELEASE_NOTES_v1.1.md` still advertised the old detached-binary install pattern via `sudo mv fpdev /usr/local/bin/` | 1 | Added a release-layout contract and rewrote the legacy upgrade instructions around preserving the extracted release directory plus explicit executable paths |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Historical top-level release notes now align with both the current version command and the current portable release layout |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep public upgrade instructions from silently reintroducing obsolete asset-layout assumptions after the main install docs have been repaired |
| What have I learned? | Historical release docs can preserve not just old commands but also old installation topology, so release-layout contracts need to cover both when those files remain public |
| What have I done? | Added legacy release-layout contract coverage and rewrote the v1.1 upgrade instructions around preserving the extracted release directory |

## Session: 2026-04-02 (known-limitations lazarus-fpc-flag drift)

### Close-out Execution Follow-up 39
- **Status:** complete
- Actions taken:
  - Re-ran a low-cost scan across the remaining uncovered live docs and found that `docs/KNOWN_LIMITATIONS.md` still used the unsupported `--fpc-version` flag in its Lazarus source-install workaround
  - Re-verified the current command surface in `src/fpdev.cmd.lazarus.install.pas`: the shipped install command accepts `--fpc=` and rejects unknown flags with a usage error
  - Added a failing official-docs contract proving the known-limitations doc must use the supported Lazarus FPC selector flag
  - Updated `docs/KNOWN_LIMITATIONS.md` so the workaround now uses `--fpc=3.2.2`
  - Re-ran the focused official-docs suite and the broader close-out regression bundle to confirm this was an isolated live-doc seam
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/KNOWN_LIMITATIONS.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for known-limitations Lazarus flag drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/KNOWN_LIMITATIONS.md` still used `--fpc-version 3.2.2` instead of the supported `--fpc=3.2.2` | Observed |
| Focused official-docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `26` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `83` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/KNOWN_LIMITATIONS.md` still advertised the removed `--fpc-version` flag in a user-facing workaround | 1 | Added a known-limitations doc contract and rewrote the workaround around the supported `--fpc=` flag |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The remaining live workaround docs now align with the shipped Lazarus install flag surface as well as the broader public docs and release notes |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep even secondary workaround docs from sending users into usage errors when they are looking for escape hatches around missing features |
| What have I learned? | Lower-traffic docs like limitations/workaround pages can still contain high-impact stale flags because users often copy them only when already blocked |
| What have I done? | Added known-limitations Lazarus-flag contract coverage and replaced `--fpc-version` with `--fpc=` in `docs/KNOWN_LIMITATIONS.md` |

## Session: 2026-04-02 (fpdev-toml workflow-command drift)

### Close-out Execution Follow-up 40
- **Status:** complete
- Actions taken:
  - Continued scanning uncovered public spec docs after the known-limitations cleanup and found that `docs/FPDEV_TOML_SPEC.md` plus `docs/FPDEV_TOML_SPEC.en.md` still advertised unimplemented workflow commands (`fpdev init`, `fpdev auto-switch`, `fpdev init -`, `fpdev system config validate`)
  - Re-verified the current source of truth in `src/fpdev.cmd.fpc.autoinstall.pas`, `src/fpdev.help.details.fpc.pas`, `src/fpdev.help.catalog.pas`, `tests/test_command_registry.lpr`, and `tests/test_fpc_commands.lpr`: the supported project-config workflow is `fpdev fpc auto-install` plus explicit `fpdev fpc use <version>` / `fpdev fpc current`
  - Added a failing official-docs contract proving the TOML spec docs must stop advertising those unimplemented workflow commands and must describe the explicit activation path
  - Updated both TOML spec docs so the workflow now uses manual `.fpdev.toml` creation, `fpdev fpc auto-install`, explicit `fpdev fpc use 3.2.2`, and `fpdev fpc current`
  - Re-ran the focused official-docs suite and the broader close-out regression bundle to confirm the TOML spec cleanup did not regress the previously-restaged release/doc contracts
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/FPDEV_TOML_SPEC.md`
  - `docs/FPDEV_TOML_SPEC.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for fpdev-toml workflow-command drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the TOML spec docs still advertised `fpdev init --fpc=3.2.2`, `fpdev auto-switch`, `fpdev init -`, `fpdev system config validate`, and lacked explicit `fpdev fpc use 3.2.2` workflow guidance | Observed |
| Focused official-docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `27` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `84` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/FPDEV_TOML_SPEC*.md` still presented future `.fpdev.toml` workflow commands as if they were public CLI surface | 1 | Added a TOML-spec workflow contract and rewrote both docs around the currently supported manual-create + auto-install + explicit-use flow |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The public `.fpdev.toml` spec docs now align with the shipped project-config workflow instead of a future command model |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep spec documents from acting like roadmap drafts when users are likely to copy their command examples verbatim |
| What have I learned? | Configuration-spec docs are high-risk drift surfaces because they look authoritative and easily preserve future-command examples long after the runtime surface settles |
| What have I done? | Added TOML-spec workflow contract coverage and rewrote both spec docs around `fpdev fpc auto-install`, explicit `fpdev fpc use`, and `fpdev fpc current` |

## Session: 2026-04-02 (historical development-roadmap install-path drift)

### Close-out Execution Follow-up 41
- **Status:** complete
- Actions taken:
  - Continued scanning non-archived public docs after the TOML-spec cleanup and found that `docs/DEVELOPMENT_ROADMAP.md` plus `docs/DEVELOPMENT_ROADMAP.en.md` still embedded copy-paste install and integration-test commands hard-coded to `~/.fpdev/fpc/3.2.2`
  - Re-verified the current source of truth in the already-restaged live docs: the active install model is `FPDEV_DATA_ROOT` / runtime-resolved `<data-root>/toolchains/fpc/<version>`, not a fixed home-directory path
  - Added a failing official-docs contract proving the historical development roadmap must use the active data-root install model if it continues to expose runnable command examples
  - Updated both historical roadmap docs so their acceptance-criteria paths now use `<data-root>/toolchains/fpc/3.2.2`, and their integration-test example explicitly sets `FPDEV_DATA_ROOT=/tmp/fpdev-mvp-test`
  - Re-ran the focused official-docs suite and the broader close-out regression bundle to confirm the historical-roadmap cleanup did not regress the current release/doc contract lane
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/DEVELOPMENT_ROADMAP.md`
  - `docs/DEVELOPMENT_ROADMAP.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for historical development-roadmap install-path drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the historical development roadmap docs still hard-coded `~/.fpdev/fpc/3.2.2`, lacked `FPDEV_DATA_ROOT`, and lacked `<data-root>/toolchains/fpc/3.2.2` guidance | Observed |
| Focused official-docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `28` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `85` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/DEVELOPMENT_ROADMAP*.md` still exposed copy-paste install examples hard-coded to the legacy `~/.fpdev/fpc/...` layout | 1 | Added a historical-roadmap install-path contract and rewrote both docs around `<data-root>` plus an explicit `FPDEV_DATA_ROOT` integration-test example |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The non-archived historical development roadmap docs now align with the current active data-root install model whenever they show runnable path examples |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep even historical-but-public roadmap snapshots from reintroducing obsolete install layouts through copy-paste shell examples |
| What have I learned? | Marking a doc as “historical” is not enough when it still exposes runnable commands; path-model drift still needs contract coverage if the file remains in the public docs tree |
| What have I done? | Added historical-roadmap install-path contract coverage and rewrote both roadmap snapshots around `<data-root>` plus explicit `FPDEV_DATA_ROOT` usage |

## Session: 2026-04-02 (installation-doc test-runner drift)

### Close-out Execution Follow-up 42
- **Status:** complete
- Actions taken:
  - Continued scanning public install/onboarding docs after the historical-roadmap cleanup and found that `docs/INSTALLATION.md` plus `docs/INSTALLATION.en.md` still taught a bespoke `cd fpdev/src && fpc -Fu.` test path instead of the repo-standard test runners
  - Re-verified the current source of truth in `docs/testing.md`, `AGENTS.md`, and `CLAUDE.md`: the standard regression entrypoints are `scripts/run_all_tests.sh` for the full baseline and `lazbuild -B tests/test_config_management.lpi` plus `./bin/test_config_management` for a focused installation check
  - Added a failing official-docs contract proving the installation docs must use those standard test-runner commands if they tell source users how to validate the checkout
  - Updated both installation docs so the test section now points to `scripts/run_all_tests.sh` and the focused `test_config_management` Lazarus-project build/run path
  - Removed the generated `tests/test_config_management` binary left behind by an earlier manual verification so the worktree returned to a clean tracked-file state
  - Re-ran the focused official-docs suite and the broader close-out regression bundle to confirm the installation-doc cleanup stayed within the existing release/doc contract envelope
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/INSTALLATION.md`
  - `docs/INSTALLATION.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for installation-doc test-runner drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because the installation docs still lacked `scripts/run_all_tests.sh` and `lazbuild -B tests/test_config_management.lpi`, while still advertising `cd fpdev/src` plus `fpc -Fu. ../tests/test_config_management.lpr` | Observed |
| Focused official-docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `29` tests OK | OK |
| Contributor + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `86` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/INSTALLATION*.md` still recommended a bespoke `cd fpdev/src && fpc -Fu.` validation path instead of the repo-standard test runners | 1 | Added an installation-doc test-runner contract and rewrote both docs around `scripts/run_all_tests.sh` plus the focused `test_config_management` Lazarus-project path |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The public installation docs now align with the repository’s standard test entrypoints instead of a one-off fallback compile path |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the first-source-build experience aligned with the same test runners and recovery logic the repository already standardizes elsewhere |
| What have I learned? | Even when a fallback command technically works, public install docs should not drift away from the repository’s standardized validation paths because users will treat them as the canonical workflow |
| What have I done? | Added installation-doc test-runner contract coverage, rewrote both install guides around standard test commands, and removed the generated test binary from the worktree |

## Session: 2026-04-02 (testing-doc full-suite runner drift)

### Close-out Execution Follow-up 43
- **Status:** complete
- Actions taken:
  - Switched this round to parallel exploration and dispatched three explorer agents across public docs, contributor docs, and remaining historical docs to surface the next high-confidence seams faster
  - Used the returned evidence plus local verification to confirm that `docs/testing.md` still advertised a nonexistent `scripts\\run_all_tests.bat` full-suite runner
  - Re-verified the canonical runner path in `scripts/release_acceptance_linux.sh`, `AGENTS.md`, and `CLAUDE.md`: the maintained Pascal full-suite entrypoint is `bash scripts/run_all_tests.sh`
  - Added a failing official-docs contract proving the testing guide must use that supported full-suite runner
  - Updated `docs/testing.md` so the “Run All Tests” section now points to `bash scripts/run_all_tests.sh`
  - Re-ran the focused official-docs suite and then the broader close-out regression bundle, now including `tests.test_developer_docs_cli_contract`, to confirm the testing-guide cleanup stays aligned with contributor and release guidance
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/testing.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for testing-doc full-suite runner drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/testing.md` lacked `bash scripts/run_all_tests.sh` and still advertised `scripts\\run_all_tests.bat` | Observed |
| Focused official-docs verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `30` tests OK | OK |
| Contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `89` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/testing.md` still pointed readers at a nonexistent `scripts\\run_all_tests.bat` full-suite runner | 1 | Added a testing-doc contract and rewrote the full-suite guidance to the supported `bash scripts/run_all_tests.sh` entrypoint |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The dedicated testing guide now uses the same full-suite runner as release acceptance and contributor guidance |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep all testing guidance converged on the same maintained top-level runners so users do not hit missing scripts or partial validation paths |
| What have I learned? | Parallel explorers are useful here because the remaining seams are smaller and scattered, but they still need the same red-green proof before any edit lands |
| What have I done? | Used multi-agent scanning to identify the next seam, added testing-guide full-suite runner contract coverage, and rewrote `docs/testing.md` to the supported runner |

## Session: 2026-04-02 (claude-doc python-test-runner drift)

### Close-out Execution Follow-up 43
- **Status:** complete
- Actions taken:
  - Continued scanning contributor/developer docs after the installation-doc cleanup and found that `CLAUDE.md` still advertised `python3 -m pytest tests -q` as part of the “full test baselines”
  - Re-verified the current Python regression entrypoint by running `python3 -m unittest discover -s tests -p 'test_*.py'`, which passed end-to-end in this worktree
  - Added a failing developer-doc contract proving `CLAUDE.md` must use the repository-standard unittest command rather than `pytest`
  - Updated `CLAUDE.md` so the baseline test block now uses `python3 -m unittest discover -s tests -p 'test_*.py'` alongside the existing Pascal baseline and focused Pascal test runner
  - Re-ran the focused developer-doc suite and a broader close-out regression bundle that now includes `tests.test_developer_docs_cli_contract`
- Files created/modified:
  - `tests/test_developer_docs_cli_contract.py`
  - `CLAUDE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Python regression entrypoint proof | `python3 -m unittest discover -s tests -p 'test_*.py'` | pass | `312` tests OK, `1` skipped | OK |
| RED proof for CLAUDE.md python test-runner drift | `python3 -m unittest -v tests.test_developer_docs_cli_contract` | fail before fix | failed because `CLAUDE.md` still used `python3 -m pytest tests -q` and lacked the repository-standard unittest discover command | Observed |
| Focused developer-doc verification | `python3 -m unittest -v tests.test_developer_docs_cli_contract` | pass | `2` tests OK | OK |
| Contributor + developer + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `88` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `CLAUDE.md` still advertised `pytest` as the baseline Python regression command even though the repository now standardizes on `unittest` | 1 | Added a developer-doc contract and rewrote the baseline command to `python3 -m unittest discover -s tests -p 'test_*.py'` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Contributor and developer docs now align more closely with the repository’s actual Python and Pascal validation entrypoints |
| Where am I going? | Continue only if another repo-local close-out seam appears; otherwise the remaining work is external release execution |
| What's the goal? | Keep the first contributor workflow from teaching a toolchain prerequisite (`pytest`) that the repository does not actually require as its baseline |
| What have I learned? | Developer docs can drift independently from public docs, and once they do, contributors start standardizing on the wrong local verification commands even if the codebase itself has already moved on |
| What have I done? | Proved the unittest-discover baseline works, added a developer-doc contract for it, and replaced the stale pytest command in `CLAUDE.md` |

## Session: 2026-04-02 (WARP contributor-doc sync)

### Close-out Execution Follow-up 44
- **Status:** complete
- Actions taken:
  - Continued the docs-contract cleanup loop against `WARP.md`, using parallel explorers plus local CLI/help verification to pin down the next contributor-doc seam
  - Added focused RED coverage proving `WARP.md` must use the repository-standard test/build entrypoints, current root command surface, and current command-registration architecture
  - Updated `WARP.md` so quickstart, test strategy, and common command blocks now align with `scripts/run_all_tests.sh`, `scripts/run_single_test.sh`, `src/fpdev.lpr`, and the `system` maintenance namespace
  - Re-ran the focused contributor-doc suite and a broader docs/release/CI contract regression bundle to green
- Files created/modified:
  - `WARP.md`
  - `tests/test_contributor_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for WARP contributor-doc drift | `python3 -m unittest -v tests.test_contributor_docs_contract` | fail before fix | failed because `WARP.md` still used BuildManager-only test runners, stale root/source CLI examples, wrong FPC entrypoint, and old `fpdev.lpr` import guidance | Observed |
| Focused contributor-doc verification | `python3 -m unittest -v tests.test_contributor_docs_contract` | pass | `6` tests OK | OK |
| Contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `95` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `WARP.md` was still outside the contributor-doc contract net, so it kept stale BuildManager-only test commands, nonexistent `source` examples, wrong `fpdev.lpr` fallback guidance, and old lpr-import registration instructions | 1 | Added WARP-specific contributor contracts and rewrote the document around the current repo-standard commands plus bootstrap/import registration model |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The WARP contributor-doc seam is closed and under automated contract coverage |
| Where am I going? | Commit and push this focused docs-contract cleanup |
| What's the goal? | Keep contributor-facing documentation aligned with the registry-backed CLI surface and repo-standard validation entrypoints |
| What have I learned? | Smaller contributor-doc drift keeps reappearing on surfaces that were not yet under contract, so the highest leverage move is to expand the contract net rather than rely on manual spot checks |
| What have I done? | Added WARP contributor contracts, updated the document, and verified the broader docs/release/CI contract bundle stays green |

## Session: 2026-04-02 (archive final-summary command drift)

### Close-out Execution Follow-up 45
- **Status:** complete
- Actions taken:
  - Continued the docs-contract cleanup into `docs/archive/` and bounded the next seam to two high-visibility final-summary docs: `FINAL_REPORT.md` and `FPDEV_FINAL_INTEGRATION.md`
  - Verified locally that the current root command surface is `fpc/lazarus/cross/package/project/system`, that `fpdev system help` / `fpdev system version` are the maintained maintenance entrypoints, and that `scripts/run_all_tests.sh` is the only top-level Pascal full-suite runner
  - Added a new archive-doc contract suite proving those two archive summaries must stop advertising removed root commands, nonexistent runners, old `upgrade/default/launch` command names, and the pre-bootstrap help/version architecture model
  - Updated both archive docs to the current help/version command names, current toolchain command names, and current CLI bootstrap/imports architecture
  - Re-ran the focused archive-doc suite and then a broader docs/release/CI regression bundle to green
- Files created/modified:
  - `tests/test_archive_docs_contract.py`
  - `docs/archive/FINAL_REPORT.md`
  - `docs/archive/FPDEV_FINAL_INTEGRATION.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for archive final-summary command drift | `python3 -m unittest -v tests.test_archive_docs_contract` | fail before fix | failed because the archive final summaries still used root `fpdev help/version`, stale `default/launch/upgrade` command names, nonexistent `scripts/run_all_tests.bat`, and pre-bootstrap architecture references | Observed |
| Focused archive-doc verification | `python3 -m unittest -v tests.test_archive_docs_contract` | pass | `5` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `100` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/archive/FINAL_REPORT.md` and `docs/archive/FPDEV_FINAL_INTEGRATION.md` still exposed removed root commands, stale toolchain verbs, nonexistent runner names, and old help/version architecture references | 1 | Added archive-doc contract coverage and rewrote the two archive summaries around the current command surface, runner set, and bootstrap/imports architecture |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The archive final-summary command seam is closed and under automated coverage |
| Where am I going? | Commit and push this archive-doc cleanup checkpoint |
| What's the goal? | Keep even archived summary docs from leaking removed commands and nonexistent runners back into copy-paste workflows |
| What have I learned? | Archive docs still need selective contract coverage when they remain prominent and example-heavy; “archived” alone is not enough to prevent drift from misleading users |
| What have I done? | Added archive-doc contracts, updated the two high-visibility archive summaries, and re-verified the broader docs/release/CI regression bundle |

## Session: 2026-04-02 (contributor-contract tightening)

### Close-out Execution Follow-up 46
- **Status:** complete
- Actions taken:
  - Folded in a follow-up contributor-doc seam uncovered by parallel exploration: `AGENTS.md` still exposed a BuildManager subdir runner, while `WARP.md` still contained a hidden `Usage: fpdev help` string and a `run_tests.bat` tree leaf
  - Tightened `tests/test_contributor_docs_contract.py` so repo-standard test-command expectations now apply to `AGENTS.md` as well, and so WARP’s embedded legacy tokens are rejected instead of only a few exact tree lines
  - Updated `AGENTS.md` to use the focused standard runner and updated the remaining WARP hidden tokens to `fpdev system help` / `run_tests.sh`
  - Re-ran the focused contributor-doc suite and the full docs/release/CI contract bundle to confirm the tighter contract remains green
- Files created/modified:
  - `AGENTS.md`
  - `WARP.md`
  - `tests/test_contributor_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for contributor-contract tightening seam | `python3 -m unittest -v tests.test_contributor_docs_contract` | fail before fix | failed because `AGENTS.md` still used the BuildManager subdir runner and `WARP.md` still contained `Usage: fpdev help` plus `run_tests.bat` | Observed |
| Focused contributor-doc verification | `python3 -m unittest -v tests.test_contributor_docs_contract` | pass | `6` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `100` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The contributor-doc contract still missed hidden legacy examples in `AGENTS.md` and `WARP.md`, even after the earlier WARP workflow cleanup | 1 | Expanded the contributor contract to cover AGENTS and embedded WARP tokens, then updated both docs to the current standard runner/help strings |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The contributor-doc contract is tighter and both AGENTS/WARP are back under it |
| Where am I going? | Commit and push this combined archive + contributor-doc cleanup checkpoint |
| What's the goal? | Stop contributor-facing docs from leaking old subdir runners or hidden root-help examples back into the repo workflow |
| What have I learned? | Exact-token bans are useful for a first pass, but scattered legacy strings need broader contributor contracts or they survive in code snippets and tree diagrams |
| What have I done? | Tightened the contributor-doc contract, updated AGENTS/WARP, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-02 (archive data-root path drift)

### Close-out Execution Follow-up 47
- **Status:** complete
- Actions taken:
  - Continued the archive-doc cleanup from command-surface drift into path-semantics drift, focusing on the still copyable Week 10 / completion summaries that hard-coded `~/.fpdev/...`
  - Confirmed the current runtime truth from `src/fpdev.paths.pas` and `src/fpdev.cmd.package.publish.pas`: registry and user-scoped installs are rooted in the active data root, with `FPDEV_DATA_ROOT` override and portable/platform defaults
  - Extended `tests/test_archive_docs_contract.py` so archive docs must describe `<data-root>/registry/` and `<data-root>/toolchains/fpc/<version>/` instead of stale home-directory literals
  - Updated `WEEK10-PLAN.md`, `WEEK10-SUMMARY.md`, and `COMPLETION_SUMMARY.md` to the active data-root model and re-ran focused plus broad regression coverage
- Files created/modified:
  - `tests/test_archive_docs_contract.py`
  - `docs/archive/WEEK10-PLAN.md`
  - `docs/archive/WEEK10-SUMMARY.md`
  - `docs/archive/COMPLETION_SUMMARY.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for archive data-root path drift | `python3 -m unittest -v tests.test_archive_docs_contract` | fail before fix | failed because the Week 10 archive docs still hard-coded `~/.fpdev/registry` and `COMPLETION_SUMMARY.md` still hard-coded `~/.fpdev/fpc/<version>/` | Observed |
| Focused archive-doc verification | `python3 -m unittest -v tests.test_archive_docs_contract` | pass | `7` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `102` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | `docs/archive/WEEK10-PLAN.md`, `docs/archive/WEEK10-SUMMARY.md`, and `docs/archive/COMPLETION_SUMMARY.md` still taught stale home-directory paths instead of the active data-root model | 1 | Added archive data-root contract coverage and rewrote the affected registry/install path guidance around `<data-root>` plus `FPDEV_DATA_ROOT` / portable / platform defaults |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The archive-doc contract now covers both command-surface drift and data-root path drift |
| Where am I going? | Commit and push this archive data-root cleanup checkpoint, then move to the next uncovered doc surface |
| What's the goal? | Keep archived but still-referenceable docs aligned with current path semantics so they do not reintroduce old installation/registry assumptions |
| What have I learned? | Once command names are fixed, the next high-value drift tends to be path semantics; archive docs can stay misleading long after live docs are corrected unless they also enter the contract net |
| What have I done? | Added two archive data-root assertions, updated three archive docs to active data-root wording, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-02 (fpdev-md CLI surface drift)

### Close-out Execution Follow-up 48
- **Status:** complete
- Actions taken:
  - Reused parallel exploration output to bound the next seam to `fpdev.md`, a top-level command reference that still advertised removed root commands and stale subcommands
  - Confirmed the current source of truth in the live registry/import units: help/version now live under `system`, update verbs are namespaced, `project add/remove/upgrade` are not registered, and database refresh is `system index update`
  - Extended `tests/test_contributor_docs_contract.py` with `fpdev.md` coverage, including a small refinement from substring-based heading checks to exact line checks after the first GREEN attempt exposed that `### version` would otherwise false-positive
  - Rewrote `fpdev.md` into a current namespaced command reference and re-ran focused plus broad contract verification
- Files created/modified:
  - `tests/test_contributor_docs_contract.py`
  - `fpdev.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for `fpdev.md` CLI drift | `python3 -m unittest -v tests.test_contributor_docs_contract` | fail before fix | failed because `fpdev.md` still exposed root `version/help/update`, stale `upgrade` subcommands, and unregistered project verbs | Observed |
| Focused contributor-doc verification | `python3 -m unittest -v tests.test_contributor_docs_contract` | pass | `9` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `105` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The first GREEN attempt still failed because `assertNotIn('## version', text)` also matched the valid `### version` heading in the rewritten `system` section | 1 | Tightened the contract to compare exact lines for banned root headings, then re-ran the focused suite to green |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | `fpdev.md` is now under contributor-doc contract and aligned to the current CLI namespace model |
| Where am I going? | Commit and push this `fpdev.md` cleanup checkpoint, then continue to the next uncovered top-level or archive doc seam |
| What's the goal? | Prevent top-level command references from reintroducing removed root commands or stale verb names after the live docs have already been corrected |
| What have I learned? | Top-level short reference docs drift differently from long guides: they need heading-level assertions, and those assertions must be precise enough to avoid matching valid nested headings |
| What have I done? | Added `fpdev.md` contract coverage, rewrote the file to current namespaced commands, handled one false-positive in the contract, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-02 (libgit2 docs missing-artifact drift)

### Close-out Execution Follow-up 49
- **Status:** complete
- Actions taken:
  - Continued from the next highest-value top-level doc seam and bounded it to the libgit2 technical docs that still referenced missing helper scripts, loader units, and an old smoke-test path
  - Re-verified the current source of truth locally: the active binding is `src/libgit2.pas`, the modern wrapper no longer switches through `libgit2.dynamic`, and the current smoke test is `tests/fpdev.core.misc/test_dyn_loader.lpr`
  - Extended `tests/test_official_docs_cli_contract.py` with focused libgit2 assertions covering both the integration docs and the dynamic/hardening docs
  - Updated the affected libgit2 docs to current repo artifacts and re-ran the focused official-doc suite plus the broad docs/release/CI regression bundle
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/LIBGIT2_INTEGRATION.md`
  - `docs/LIBGIT2_INTEGRATION.en.md`
  - `docs/LIBGIT2_DYNAMIC.md`
  - `docs/M1_GIT_HARDENING.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for libgit2 missing-artifact drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because libgit2 docs still referenced removed helper scripts / loader units and omitted current `src/libgit2.pas` plus `tests/fpdev.core.misc/test_dyn_loader.lpr` | Observed |
| Focused official-doc verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `32` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `107` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | libgit2 technical docs still described missing helper scripts/loader units rather than the current unified binding and smoke-test locations | 1 | Added focused official-doc contract coverage and rewrote the affected docs around `src/libgit2.pas`, current test directories, and manual `3rd/libgit2` CMake guidance |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The libgit2 technical docs are now under official-doc contract coverage and aligned to current repo artifacts |
| Where am I going? | Commit and push this libgit2 docs cleanup checkpoint, then continue to the next uncovered doc surface |
| What's the goal? | Keep technical reference docs from teaching removed helper scripts or nonexistent source files after the implementation has been consolidated |
| What have I learned? | Technical subsystem docs drift toward missing file paths as the implementation consolidates; path-existence contracts catch that class of drift well |
| What have I done? | Added libgit2 official-doc assertions, updated four libgit2 docs to current artifacts, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-02 (test-infra doc layout drift)

### Close-out Execution Follow-up 50
- **Status:** complete
- Actions taken:
  - Continued to the next repo-local doc seam surfaced earlier: the Chinese test-infra guideline still described `buildOrTest.bat` and subdir-local `bin/lib` as universal structure
  - Re-verified the current source of truth from `tests/fpdev.build.manager/run_tests.bat`, `tests/fpdev.build.manager/run_tests.sh`, and `tests/fpdev.build.manager/test_build_manager.lpi`: maintained tests can build from the repo root into top-level `bin/` and `lib/`
  - Added a focused official-doc contract for `docs/测试基建规范.md`
  - Rewrote the guideline around current runner/output patterns and re-ran focused plus broad regression coverage
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/测试基建规范.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for test-infra layout drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/测试基建规范.md` still taught universal `buildOrTest.bat` and local `bin/lib` outputs, while omitting current root-runner/root-output patterns | Observed |
| Focused official-doc verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `33` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `108` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The test-infra guideline still generalized a legacy `buildOrTest.bat` + local `bin/lib` layout that no longer matches the maintained build-manager test subtree | 1 | Added focused official-doc contract coverage and rewrote the guideline around current root runners, explicit project runners, and repo-root output paths |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The test-infra guideline is now under official-doc contract and aligned to maintained runner/output patterns |
| Where am I going? | Commit and push this test-infra docs checkpoint, then continue to the next uncovered public doc seam |
| What's the goal? | Prevent engineering-guideline docs from standardizing obsolete local layouts that the maintained test projects no longer use |
| What have I learned? | “规范” 文档 drift 的破坏性更强，因为它会把少数遗留模式重新合法化； targeted contract checks are worth adding as soon as such a doc is found |
| What have I done? | Added one focused official-doc assertion, rewrote `docs/测试基建规范.md` to current runner/output truth, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-02 (testing-doc suite-runner drift)

### Close-out Execution Follow-up 51
- **Status:** complete
- Actions taken:
  - Moved to the next nearby official-doc seam in `docs/testing.md`, which still showed old `cd ... && runner` style suite examples
  - Re-verified the current runner truth from `scripts/run_single_test.sh`, `tests/fpdev.build.manager/run_tests.bat`, `tests/fpdev.build.manager/run_tests.sh`, and `tests/fpdev.git2/buildOrTest.fpcunit.bat`
  - Added one focused official-doc contract for current suite-runner command forms
  - Updated the testing guide to use explicit runner paths plus the standard focused runner, then re-ran focused and broad regression coverage
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/testing.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for testing-guide runner drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/testing.md` still used `cd tests\\...` suite examples and omitted the standard focused runner | Observed |
| Focused official-doc verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `34` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `109` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-02 | The testing guide still used old `cd`-into-subdir suite commands and did not show the standard focused runner | 1 | Added a focused official-doc contract and rewrote the runner examples to explicit current command paths |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The testing guide is now under official-doc contract for suite-runner examples |
| Where am I going? | Commit and push this testing-guide cleanup checkpoint, then continue to the next uncovered public doc seam |
| What's the goal? | Keep the testing guide aligned with the maintained runner entrypoints so copy-paste instructions stay valid |
| What have I learned? | Even when a document already references the right scripts, the invocation style can still drift; explicit command-path assertions are useful for that class of issue |
| What have I done? | Added a new testing-guide runner assertion, updated `docs/testing.md`, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-03 (build-manager doc workflow-artifact drift)

### Close-out Execution Follow-up 52
- **Status:** complete
- Actions taken:
  - Continued to the next nearby official-doc seam in `docs/build-manager.md`, where the CI section still presented two nonexistent `build-manager-demo*.yml` workflow files as if they were checked into the repo
  - Re-verified the current source of truth from `.github/workflows/ci.yml` and the existing demo artifacts under `plays/fpdev.build.manager.demo/`
  - Added one focused official-doc contract for stale workflow-file claims in the build-manager doc
  - Reworded the CI section to mark the YAML as inline documentation examples and point readers to the actual demo scripts/config plus the real `ci.yml` reference pattern
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/build-manager.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for build-manager workflow drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because `docs/build-manager.md` still advertised `.github/workflows/build-manager-demo.yml` and `.github/workflows/build-manager-demo-linux.yml` as if those files existed | Observed |
| Focused official-doc verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `35` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `110` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-03 | The build-manager doc still named two nonexistent workflow files, which could send contributors searching for repo artifacts that are not checked in | 1 | Added a focused official-doc contract and rewrote the section to distinguish inline YAML examples from actual checked-in demo artifacts |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The build-manager technical doc is now under official-doc contract for workflow-file path claims |
| Where am I going? | Commit and push this checkpoint, then continue to the next uncovered doc seam with the updated 110-test baseline |
| What's the goal? | Keep technical docs from turning inline examples into fake repository file contracts |
| What have I learned? | Path-existence drift is especially dangerous in CI examples because it looks authoritative and is easy to cargo-cult into automation |
| What have I done? | Added one build-manager path-existence assertion, rewrote the CI section wording, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-03 (WARP clean-build example drift)

### Close-out Execution Follow-up 53
- **Status:** complete
- Actions taken:
  - Continued into the contributor-doc layer and isolated a new seam in `WARP.md`: the file already had the right `-B` entrypoints, but still mixed in copy-pastable plain `lazbuild` examples in sections that read like standard repo workflow
  - Re-verified the current build truth from `AGENTS.md`, `CLAUDE.md`, and `scripts/run_all_tests.sh`
  - Added one focused contributor-doc contract for clean-build command consistency in `WARP.md`
  - Normalized the standard build flow, cross-compile example, and unit-test command examples to the clean rebuild form
- Files created/modified:
  - `tests/test_contributor_docs_contract.py`
  - `WARP.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for WARP clean-build drift | `python3 -m unittest -v tests.test_contributor_docs_contract` | fail before fix | failed because `WARP.md` still mixed bare `lazbuild fpdev.lpi`, bare `lazbuild <test>.lpi`, and a non-`-B` cross-build example into contributor-facing workflow sections | Observed |
| Focused contributor-doc verification | `python3 -m unittest -v tests.test_contributor_docs_contract` | pass | `10` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `111` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-03 | `WARP.md` still mixed clean rebuild guidance with copy-pastable plain `lazbuild` examples, weakening the contributor build contract | 1 | Added a focused contributor-doc assertion and normalized the examples to `lazbuild -B` |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | `WARP.md` is now under explicit contributor-doc contract for clean-build example consistency |
| Where am I going? | Commit and push this contributor-doc checkpoint, then continue to the next uncovered seam with the updated 111-test baseline |
| What's the goal? | Keep contributor-facing build examples aligned with the repository’s standard clean rebuild workflow |
| What have I learned? | Partial doc cleanup is not enough; once a document contains both old and new command forms, contributors will copy the shortest one unless the contract forbids it |
| What have I done? | Added one WARP clean-build assertion, rewrote the remaining plain `lazbuild` examples, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-03 (architecture-review nonexistent-symbol drift)

### Close-out Execution Follow-up 54
- **Status:** complete
- Actions taken:
  - Continued into the developer-doc layer and isolated an uncovered seam in `docs/ARCHITECTURE_REVIEW.md`, which still described several nonexistent files and interface names as if they were current codebase facts
  - Re-verified the current source of truth from `src/fpdev.command.intf.pas`, `src/fpdev.command.context.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.config.core.pas`, and the live Git stack files
  - Added one focused developer-doc contract for nonexistent-symbol drift in the architecture review doc
  - Rewrote the affected sections to use the real `IContext` / `ICommand` / `IConfigManager` / `TConfigManager` / `git2.api + git2.impl + libgit2` naming surface
- Files created/modified:
  - `tests/test_developer_docs_cli_contract.py`
  - `docs/ARCHITECTURE_REVIEW.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for architecture-review symbol drift | `python3 -m unittest -v tests.test_developer_docs_cli_contract` | fail before fix | failed because `docs/ARCHITECTURE_REVIEW.md` still named nonexistent files/types such as `fpdev.cmd.fpc.root2.pas`, `IFpdevCommand`, and `ICommandContext` as current codebase reality | Observed |
| Focused developer-doc verification | `python3 -m unittest -v tests.test_developer_docs_cli_contract` | pass | `3` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `112` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-03 | `docs/ARCHITECTURE_REVIEW.md` still treated removed or nonexistent file/type names as current architecture facts, weakening trust in the developer-facing review document | 1 | Added a focused developer-doc assertion and rewrote the affected naming examples to the live command/config/git surfaces |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | `docs/ARCHITECTURE_REVIEW.md` is now under developer-doc contract for current symbol/path existence |
| Where am I going? | Commit and push this developer-doc checkpoint, then continue to the next uncovered seam with the updated 112-test baseline |
| What's the goal? | Keep design-review documentation grounded in the actual code that exists today, not in old or hypothetical symbol names |
| What have I learned? | Architecture review docs can drift just as badly as user docs; once they cite nonexistent symbols as “current,” they actively damage code navigation and design discussions |
| What have I done? | Added one architecture-review symbol-existence assertion, corrected the stale naming examples, and re-verified the full docs/release/CI bundle |

## Session: 2026-04-03 (official FPC source-maintenance doc drift)

### Close-out Execution Follow-up 55
- **Status:** complete
- Actions taken:
  - Continued into the next public-doc seam and verified that the live FPC CLI surface exposes `update` but not `clean`, using `src/fpdev.command.imports.fpc.pas`, FPC help surfaces, and both shell completion scripts
  - Added a focused official-doc contract for FPC source-maintenance guidance in FAQ/FPC management docs
  - Updated the affected docs to stop advertising `fpdev fpc clean` as a runnable command and replaced that guidance with an explicit “no dedicated subcommand” note plus manual cleanup/rebuild wording
  - Narrowed the new contract after the first focused run showed it was also matching explanatory “this command does not exist” prose
- Files created/modified:
  - `tests/test_official_docs_cli_contract.py`
  - `docs/FAQ.md`
  - `docs/FAQ.en.md`
  - `docs/FPC_MANAGEMENT.md`
  - `docs/FPC_MANAGEMENT.en.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Focused official-doc verification (attempt 1) | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass after initial edit | failed because the first contract version also matched explanatory “`fpdev fpc clean` does not exist” prose | FAIL |
| Focused official-doc verification (final) | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `36` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `113` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-03 | The first `fpc clean` docs contract over-banned any mention of the string and therefore also rejected the new explanatory “no such subcommand” prose | 1 | Tightened the assertion to reject runnable examples/workflow claims only, while requiring an explicit unsupported-command notice |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The official FPC source-maintenance docs are now under contract for the missing `fpc clean` command seam |
| Where am I going? | Commit and push this checkpoint, then continue to the next uncovered public-doc seam beyond FPC source-maintenance |
| What's the goal? | Keep public CLI docs aligned with the live registered command surface so users never get copy-paste instructions for commands that do not exist |
| What have I learned? | For negative capability docs, the contract has to distinguish between “advertising a command” and “explicitly stating that the command is unsupported” |
| What have I done? | Verified the live FPC command surface, added a new official-doc contract, corrected FAQ/FPC management guidance, and re-verified the 113-test docs/release/CI bundle |

## Session: 2026-04-05 (project template webapp surface drift)

### Close-out Execution Follow-up 56
- **Status:** complete
- Actions taken:
  - Followed the next strongest seam from parallel-agent findings and mapped `webapp` across quickstart docs, built-in templates, generator branches, shell completions, and runtime CLI behavior
  - Chose to withdraw `webapp` from the current available template surface instead of inventing an unreviewed scaffold
  - Added focused regression coverage for quickstart docs, project-template completions, and `project new/list/info` runtime behavior
  - Updated the manager availability filter, aligned completion suggestions, and replaced quickstart `webapp` examples with `library`
- Files created/modified:
  - `src/fpdev.project.manager.pas`
  - `scripts/completions/fpdev.bash`
  - `scripts/completions/_fpdev`
  - `QUICKSTART.md`
  - `docs/QUICKSTART.md`
  - `docs/QUICKSTART.en.md`
  - `tests/test_official_docs_cli_contract.py`
  - `tests/test_cli_surface_consistency.py`
  - `tests/test_cli_project.lpr`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for quickstart webapp drift | `python3 -m unittest -v tests.test_official_docs_cli_contract` | fail before fix | failed because quickstart docs still advertised `fpdev project new webapp` | Observed |
| RED proof for project-template completion drift | `python3 -m unittest -v tests.test_cli_surface_consistency` | fail before fix | failed because `project new` completion suggestions drifted from the manager template surface (`daemon` stale, `game` missing, `webapp` still surfaced) | Observed |
| RED proof for runtime template availability drift | `bash scripts/run_single_test.sh tests/test_cli_project.lpr` | fail before fix | failed because `project new/list/info` still treated `webapp` as available | Observed |
| Focused official-doc verification | `python3 -m unittest -v tests.test_official_docs_cli_contract` | pass | `37` tests OK | OK |
| Focused completion verification | `python3 -m unittest -v tests.test_cli_surface_consistency` | pass | `4` tests OK | OK |
| Focused runtime CLI verification | `bash scripts/run_single_test.sh tests/test_cli_project.lpr` | pass | PASSED | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `115` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | The first zsh completion parser for `project_templates` assumed a multi-line array and failed against the current single-line array format | 1 | Relaxed the parser to accept any `array=(...)` layout before re-running the focused completion suite |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The `webapp` template seam is now closed across docs, completion, and runtime CLI availability |
| Where am I going? | Commit and push this checkpoint, then continue to the next uncovered project-surface drift after template alignment |
| What's the goal? | Keep template discovery surfaces honest so every advertised starter maps to a current supported runtime path |
| What have I learned? | Template drift is worse than a normal docs typo because it spans docs, completion, list/info discovery, and generation semantics; treating it as one surface is the right unit of repair |
| What have I done? | Added three focused regression layers, withdrew `webapp` from the current available template surface, aligned completions and quickstarts, and re-verified the 115-test docs/release/CI bundle plus the focused Pascal CLI suite |

## Session: 2026-04-05 (changelog project-command signature drift)

### Close-out Execution Follow-up 57
- **Status:** complete
- Actions taken:
  - Followed the next release-doc seam after the template cleanup and compared `CHANGELOG.md` project command inventory against the live help/runtime signatures
  - Added a focused release-doc contract that requires the current template-oriented and directory-oriented project command signatures
  - Updated the changelog `Project Management` block to match the real CLI surface instead of the older `<name> [--template]` / `List projects` wording
- Files created/modified:
  - `tests/test_release_docs_contract.py`
  - `CHANGELOG.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for changelog project-command drift | `python3 -m unittest -v tests.test_release_docs_contract` | fail before fix | failed because the changelog still advertised old `project` command signatures and project-oriented wording | Observed |
| Focused release-doc verification | `python3 -m unittest -v tests.test_release_docs_contract` | pass | `16` tests OK | OK |
| Release/docs/CI regression bundle | `python3 -m unittest -v tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts` | pass | `92` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | `CHANGELOG.md` kept the older project command inventory long after help/runtime had switched to template-oriented and directory-oriented signatures | 1 | Added a release-doc contract for the current signatures and updated the changelog block to the live CLI surface |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The changelog inventory no longer lags behind the live `project` command surface |
| Where am I going? | Commit and push this checkpoint, then continue to the next public-contract seam outside the project command cluster |
| What's the goal? | Keep release-facing documentation honest so historical release notes do not teach users outdated command signatures |
| What have I learned? | Release docs can preserve stale CLI signatures even after help, runtime, completions, and quickstarts are corrected; changelog inventory needs its own contract |
| What have I done? | Added one focused release-doc contract, corrected the changelog project command signatures, and re-verified the 92-test release/docs/CI bundle |

## Session: 2026-04-05 (project info completion coverage gap)

### Close-out Execution Follow-up 58
- **Status:** complete
- Actions taken:
  - Recovered a half-finished completion seam left dirty by the interrupted session and first verified that the on-disk changes matched the live `project info <template>` semantics
  - Adopted the completion change only after fresh focused verification and a full docs/release/CI/completion regression bundle both passed
  - Extended project-template completion coverage so `fpdev project info` now reuses the same template suggestions as `fpdev project new`
- Files created/modified:
  - `scripts/completions/fpdev.bash`
  - `scripts/completions/_fpdev`
  - `tests/test_cli_surface_consistency.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Focused completion verification | `python3 -m unittest -v tests.test_cli_surface_consistency` | pass | `5` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `116` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | The interrupted session left uncommitted completion/test changes, so the first task was to distinguish “valid unfinished work” from “stale dirty state” before adopting anything | 1 | Re-read the exact diff, confirmed it matched live `project info <template>` semantics, then required fresh focused and broad verification before keeping it |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | `project info` is now covered by the same template completion surface and consistency tests as `project new` |
| Where am I going? | Commit and push this checkpoint, then continue to the next remaining contract seam after the project-template cluster |
| What's the goal? | Keep user-facing discovery surfaces ergonomic and truthful so command signatures and shell assistance do not drift apart |
| What have I learned? | Interrupted sessions can leave good work dirty; the right response is not to discard it, but to validate it rigorously before adoption |
| What have I done? | Verified and adopted the pending `project info` completion support, expanded the completion contract, and re-verified the 116-test docs/release/CI/completion bundle |

## Session: 2026-04-05 (shared config fixture path contamination)

### Close-out Execution Follow-up 59
- **Status:** complete
- Actions taken:
  - Switched from the project-command cluster to a higher-severity runtime artifact seam after confirming that repo-shared config fixtures still embedded developer-machine absolute paths
  - Added a focused release/data contract so shared config artifacts cannot hardcode `install_root` or local `file://` repositories
  - Sanitized both shipped and test config fixtures back to portable defaults, letting runtime derive install roots dynamically as intended
- Files created/modified:
  - `tests/test_package_release_assets.py`
  - `src/data/config.json`
  - `tests/data/config.json`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for shared config contamination | `python3 -m unittest -v tests.test_package_release_assets` | fail before fix | failed because `src/data/config.json` still hardcoded a developer-machine `install_root` | Observed |
| Focused release/data verification | `python3 -m unittest -v tests.test_package_release_assets` | pass | `3` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `117` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | Shared config fixtures were still carrying machine-local absolute paths even though runtime defaults now derive install roots from the active data root | 1 | Added a package/data contract and replaced the embedded paths with portable empty defaults |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Shared config fixtures no longer leak developer-machine paths into repo or release data |
| Where am I going? | Commit and push this checkpoint, then continue to the next remaining public-contract or portable-data seam |
| What's the goal? | Keep shipped defaults and repo fixtures portable, reproducible, and free of developer-local state |
| What have I learned? | Public docs can be correct while shipped data is still wrong; release/data artifacts need their own explicit contract layer |
| What have I done? | Added one focused package/data contract, sanitized shared config fixtures, and re-verified the 117-test docs/release/CI bundle |

## Session: 2026-04-05 (root test-repo config path contamination)

### Close-out Execution Follow-up 60
- **Status:** complete
- Actions taken:
  - Continued the portable-data cleanup one layer outward after the shared config fix and found two root-level tracked test repo configs still tied to `/home/dtamade/...`
  - Extended the same package/data hygiene contract to cover those root-level fixtures
  - Replaced the machine-specific local repo URLs with `REPLACE_ME` placeholders and cleared their baked-in install roots
- Files created/modified:
  - `tests/test_package_release_assets.py`
  - `tests_repo_config.json`
  - `tests_repo_config_invalid.json`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for root-level repo fixture contamination | `python3 -m unittest -v tests.test_package_release_assets` | fail before fix | failed because `tests_repo_config.json` still hardcoded `/home/dtamade/...` as `install_root` | Observed |
| Focused package/data verification | `python3 -m unittest -v tests.test_package_release_assets` | pass | `4` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `python3 -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `118` tests OK，`1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | Two root-level tracked test repo configs were no longer used by core tests, so their machine-local paths had silently survived earlier cleanups | 1 | Folded them into the existing package/data hygiene contract and replaced the paths with neutral defaults/placeholders |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Root-level test repo configs now follow the same portable fixture hygiene as the rest of the shared config artifacts |
| Where am I going? | Commit and push this checkpoint, then continue to the next remaining public-contract or portable-fixture seam |
| What's the goal? | Keep every tracked shared fixture safe to copy, package, and inspect on any machine without leaking a developer-specific path |
| What have I learned? | Old tracked test fixtures can outlive the tests that once depended on them; hygiene contracts need to cover dormant artifacts too |
| What have I done? | Extended the package/data contract to root-level repo configs, replaced machine-local URLs with placeholders, and re-verified the 118-test docs/release/CI bundle |

## Session: 2026-04-05 (tracked docs workspace-path contamination)

### Close-out Execution Follow-up 61
- **Status:** complete
- Actions taken:
  - Followed a focused archive/docs seam after a fresh rerun exposed that tracked plans and archive reports still embedded personal workspace paths and stale `.fpdev` path models
  - Re-read the on-disk archive contract module and found that three intended path-hygiene tests had been dropped during the interrupted session, so restored the missing coverage before trusting any green result
  - Replaced the remaining personal workspace/home-path examples with `<repo-root>`, `<workspace>`, and `<data-root>` placeholders across the affected tracked plan and archive docs
- Files created/modified:
  - `docs/plans/2026-02-13-real-completion-smoke.md`
  - `docs/archive/WEEK4-SUMMARY.md`
  - `docs/archive/WEEK5-PLAN.md`
  - `docs/archive/WEEK5-COMPLETION.md`
  - `docs/archive/WEEK5-PROGRESS.md`
  - `docs/archive/WEEK5-FINAL-REPORT.md`
  - `docs/archive/WEEK5-SUMMARY.md`
  - `docs/archive/WEEK5-INTEGRATION-TEST-REPORT.md`
  - `docs/archive/WEEK6-PLAN.md`
  - `docs/archive/WEEK6-ISSUES.md`
  - `docs/archive/WEEK6-PROGRESS.md`
  - `docs/archive/WEEK7-PLAN.md`
  - `docs/archive/WEEK7-PROGRESS.md`
  - `docs/archive/WEEK7-SUMMARY.md`
  - `docs/archive/CODE-IMPROVEMENTS-SUMMARY.md`
  - `tests/test_archive_docs_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| RED proof for tracked docs path contamination | `python3 -B -m unittest -v tests.test_archive_docs_contract tests.test_developer_docs_cli_contract` | fail before fix | failed because `docs/archive/WEEK6-PROGRESS.md` still embedded `/home/dtamade/projects/...` | Observed |
| Focused archive/developer verification | `python3 -B -m unittest -v tests.test_archive_docs_contract tests.test_developer_docs_cli_contract` | pass | `13` tests OK | OK |
| Archive + contributor/developer + close-out regression bundle | `TMPDIR=/tmp FPDEV_TEST_TMPDIR=/tmp python3 -B -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `121` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | The interrupted session had left the archive path-hygiene seam split across dirty docs edits and a test file whose three new contract methods were no longer present on disk | 1 | Re-read the live module, restored the missing archive tests, then required a fresh focused and broad rerun using `python3 -B` before accepting the seam |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The tracked plan/archive docs now use portable workspace and data-root placeholders instead of personal machine paths |
| Where am I going? | Commit and push this checkpoint, then continue to the next highest-value repo-local contract seam |
| What's the goal? | Keep every tracked shared document safe to copy and execute without leaking developer-local topology or teaching stale path models |
| What have I learned? | Interrupted sessions can drop tests as easily as they leave dirty docs; the only safe response is to re-read the exact on-disk state and re-establish coverage before trusting a green bundle |
| What have I done? | Restored the missing archive hygiene contracts, sanitized the remaining tracked docs path examples, and re-verified the 121-test docs/release/CI bundle |

## Session: 2026-04-05 (stale missing `fpdev fpc clean` leakage)

### Close-out Execution Follow-up 62
- **Status:** complete
- Actions taken:
  - Switched to a higher-severity seam after confirming that runtime recovery messages were still teaching users to run the missing `fpdev fpc clean` command
  - Extended the contract layer across runtime recovery text, changelog, roadmap, archive docs, and the repo-root `RELEASE_NOTES_v1.1.md`
  - Normalized every affected public surface to the same supported workflow: manual cleanup under `<data-root>/sources/fpc/fpc-<version>`, optional rebuild via `fpdev fpc install <version> --from-source`, and `fpdev fpc update <version>` as the supported source-maintenance command
- Files created/modified:
  - `src/fpdev.errors.recovery.pas`
  - `CHANGELOG.md`
  - `RELEASE_NOTES_v1.1.md`
  - `docs/ROADMAP.md`
  - `docs/archive/COMPLETION_SUMMARY.md`
  - `docs/archive/WEEK8-PLAN.md`
  - `tests/test_errors_recovery.lpr`
  - `tests/test_release_docs_contract.py`
  - `tests/test_archive_docs_contract.py`
  - `tests/test_official_docs_cli_contract.py`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Focused runtime recovery verification | `lazbuild -B tests/test_errors_recovery.lpi && ./bin/test_errors_recovery` | pass | `41` passed | OK |
| Focused release/archive/official docs verification | `python3 -B -m unittest -v tests.test_release_docs_contract tests.test_archive_docs_contract tests.test_official_docs_cli_contract` | pass | `67` tests OK | OK |
| Broad docs/release/CI contract bundle | `TMPDIR=/tmp FPDEV_TEST_TMPDIR=/tmp python3 -B -m unittest -v tests.test_archive_docs_contract tests.test_contributor_docs_contract tests.test_developer_docs_cli_contract tests.test_release_docs_contract tests.test_release_scripts_contract tests.test_package_release_assets tests.test_generate_release_checksums tests.test_generate_release_evidence tests.test_record_owner_smoke_sh tests.test_record_owner_smoke_ps1 tests.test_official_docs_cli_contract tests.test_release_status_wording tests.test_update_test_stats tests.test_ci_workflow_contract tests.test_ci_release_contracts tests.test_cli_surface_consistency` | pass | `125` tests OK, `1` skipped | OK |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-04-05 | The first focused Python rerun still failed because the new contract text had only been applied partially and `RELEASE_NOTES_v1.1.md` was still advertising `fpdev fpc clean` plus stale test counts | 1 | Re-read the exact public docs, extended the seam to the repo-root legacy release notes, and synchronized the remaining wording/count residue before rerunning the focused and broad bundles |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | The missing `fpdev fpc clean` command is no longer leaked through runtime recovery or public release/roadmap/archive docs |
| Where am I going? | Commit and push this seam, then continue from the next highest-value repo-local drift instead of reopening the same command-survival issue |
| What's the goal? | Keep every user-visible recovery and release narrative aligned with the actual registered CLI surface |
| What have I learned? | Stale command drift is rarely isolated to one file; once a command becomes invalid, runtime hints, release notes, roadmap text, and inventory counts all need to be treated as one consistency seam |
| What have I done? | Added regression coverage for runtime/docs leakage, normalized the remaining public surfaces, and re-verified the 125-test contract bundle plus the focused Pascal recovery suite |
