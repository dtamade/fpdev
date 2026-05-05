# FPDev Release Acceptance Criteria (v2.1.0)

> Status snapshot: `v2.1.0` was published on 2026-04-08. This document now records the published acceptance state and the evidence entrypoints maintainers should use for later audits or reruns.

## Release Goal

Ship FPDev `v2.1.0` with:
- a reproducible Linux release-acceptance lane
- synchronized release documentation and version markers
- a public CI release-proof bundle for Windows, Linux, and macOS, with local fallback recorders when reruns are needed

This document replaces the earlier MVP-era checklist with a bounded release close-out matrix.

## Verification Entry Points

| Entry Point | Purpose |
|------------|---------|
| `bash scripts/build_release.sh` | Shared maintainer Release build entrypoint |
| `bash scripts/package_release_asset.sh --output-dir <asset-dir> --data-dir src/data --linux-bin <binary>` | Shared release asset packaging entrypoint |
| `bash scripts/release_acceptance_linux.sh` | Automated Linux release gate |
| `bash scripts/release_acceptance_linux.sh --with-install` | Optional clean-root binary-install proof on Linux |
| `python3 scripts/update_test_stats.py --check` | Test inventory drift gate |
| `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` | Public CI release-proof bundle + Windows/macOS local fallback checkpoints |

## Published Close-Out Matrix

| Lane | Scope | Status | Evidence |
|------|-------|--------|----------|
| Linux automated baseline | toolchain, inventory sync, Python regression, focused IO bridge stability gate, full Pascal regression, Release build, shared Linux asset packaging, CLI smoke | pass | `logs/release_acceptance/20260325_204342/summary.txt` |
| Linux isolated binary install | `fpc install/use/current/verify` in an isolated data root | pass | `logs/release_acceptance/20260325_205542/summary.txt` |
| Windows x64 release proof | release asset extraction + CLI smoke transcript | pass | published `RELEASE_EVIDENCE.md` + owner-proof ledger (`windows-x64-owner-smoke.txt`) |
| macOS x64 release proof | release asset extraction + CLI smoke transcript | pass | published `RELEASE_EVIDENCE.md` + owner-proof ledger (`macos-x64-owner-smoke.txt`) |
| macOS arm64 release proof | release asset extraction + CLI smoke transcript | pass | published `RELEASE_EVIDENCE.md` + owner-proof ledger (`macos-arm64-owner-smoke.txt`) |

## Mandatory Automated Gates

- [x] Local toolchain baseline is green on Linux
- [x] Test inventory is synchronized at `353` discoverable `test_*.lpr` programs
- [x] Python regression suite is green
- [x] `tests/test_fpc_installer_iobridge.lpr` passes 5 repeated focused runs in the Linux acceptance lane
- [x] Full Pascal regression suite is green
- [x] `bash scripts/build_release.sh` succeeds
- [x] `bash scripts/package_release_asset.sh --output-dir <asset-dir> --data-dir src/data --linux-bin <binary>` succeeds for the Linux release binary
- [x] `fpdev system help` exits `0` and shows the registered command surface
- [x] `fpdev system version` exits `0`
- [x] `fpdev fpc --help` exits `0` and shows the FPC namespace
- [x] `fpdev fpc list --all` exits `0` and includes `3.2.2`
- [x] `fpdev system toolchain check` exits `0`
- [x] `fpdev fpc test` exits `0`
- [x] Linux smoke output contains no CJK characters

## Network-Gated Linux Gate

- [x] `fpdev fpc install 3.2.2` succeeds in an isolated data root
- [x] `fpdev fpc use 3.2.2` succeeds in the same isolated data root
- [x] `fpdev fpc current` returns `3.2.2`
- [x] `fpdev fpc verify 3.2.2` succeeds

## Cross-Platform Release Proof

- [x] GitHub Actions `release-ready-bundle` is available for the published release commit
- [x] `owner-proof-windows-x64` is recorded and bundled into `RELEASE_EVIDENCE.md`
- [x] `owner-proof-macos-x64` is recorded and bundled into `RELEASE_EVIDENCE.md`
- [x] `owner-proof-macos-arm64` is recorded and bundled into `RELEASE_EVIDENCE.md`
- [x] `SHA256SUMS.txt` is generated and published with the release assets

## Release Exit Criteria

Release close-out is complete when:

1. the automated Linux baseline is green
2. the release documents and download URLs are synchronized to `v2.1.0`
3. the public CI release-proof bundle is complete and published

## Published Evidence Pointers

- GitHub release page: `https://github.com/dtamade/fpdev/releases/tag/v2.1.0`
- Published at: `2026-04-08T18:42:46Z`
- Public CI handoff: `release-ready-bundle` from the green release workflow run used for the merged release line
- Published proof assets:
  - `fpdev-linux-x64.tar.gz`
  - `fpdev-windows-x64.zip`
  - `fpdev-macos-x64.tar.gz`
  - `fpdev-macos-arm64.tar.gz`
  - `SHA256SUMS.txt`
  - `RELEASE_EVIDENCE.md`

## Notes

- The product roadmap itself is already functionally complete, and the `v2.1.0` release line is published.
- If maintainers need to re-audit or rerun any owner proof, start from the canonical owner-checkpoint document instead of reopening this checklist as an active work queue.
- The canonical owner-checkpoint document is `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`.
- Linux baseline evidence: `logs/release_acceptance/20260325_204342/summary.txt`.
- Linux isolated install evidence: `logs/release_acceptance/20260325_205542/summary.txt`.
