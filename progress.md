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
