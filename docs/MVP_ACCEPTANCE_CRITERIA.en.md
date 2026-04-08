# FPDev Release Acceptance Criteria (v2.1.0)

## Release Goal

Ship FPDev `v2.1.0` with:
- a reproducible Linux release-acceptance lane
- synchronized release documentation and version markers
- a public CI release-proof bundle for Windows, Linux, and macOS, with local fallback recorders when reruns are needed

This document replaces the older MVP-era checklist with a bounded release close-out matrix.

## Verification Entry Points

| Entry Point | Purpose |
|------------|---------|
| `bash scripts/build_release.sh` | Shared maintainer Release build entrypoint |
| `bash scripts/release_acceptance_linux.sh` | Automated Linux release gate |
| `bash scripts/release_acceptance_linux.sh --with-install` | Optional clean-root binary-install proof on Linux |
| `python3 scripts/update_test_stats.py --check` | Test inventory drift gate |
| `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` | Public CI release-proof bundle + Windows/macOS local fallback checkpoints |

## Current Close-Out Matrix

| Lane | Scope | Status | Evidence |
|------|-------|--------|----------|
| Linux automated baseline | toolchain, inventory sync, Python regression, focused IO bridge stability gate, full Pascal regression, Release build, CLI smoke | pass | `logs/release_acceptance/20260325_204342/summary.txt` |
| Linux isolated binary install | `fpc install/use/current/verify` in an isolated data root | pass | `logs/release_acceptance/20260325_205542/summary.txt` |
| Windows x64 release proof | release asset extraction + CLI smoke transcript | pending | public CI release-proof bundle / fallback ledger |
| macOS x64 release proof | release asset extraction + CLI smoke transcript | pending | public CI release-proof bundle / fallback ledger |
| macOS arm64 release proof | release asset extraction + CLI smoke transcript | pending | public CI release-proof bundle / fallback ledger |

## Mandatory Automated Gates

- [x] Local toolchain baseline is green on Linux
- [x] Test inventory is synchronized at `275` discoverable `test_*.lpr` programs
- [x] Python regression suite is green
- [x] `tests/test_fpc_installer_iobridge.lpr` passes 5 repeated focused runs in the Linux acceptance lane
- [x] Full Pascal regression suite is green
- [x] `bash scripts/build_release.sh` succeeds
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

- [ ] GitHub Actions `release-ready-bundle` is available for the target release commit
- [ ] `owner-proof-windows-x64` is recorded and bundled into `RELEASE_EVIDENCE.md`
- [ ] `owner-proof-macos-x64` is recorded and bundled into `RELEASE_EVIDENCE.md`
- [ ] `owner-proof-macos-arm64` is recorded and bundled into `RELEASE_EVIDENCE.md`
- [ ] `SHA256SUMS.txt` is generated for the published assets

## Release Exit Criteria

Release close-out is complete when:

1. the automated Linux baseline is green
2. the release documents and download URLs are synchronized to `v2.1.0`
3. the public CI release-proof bundle is complete and publishable

## Notes

- The product roadmap itself is already functionally complete; the remaining work is release engineering and public CI proof assembly.
- The canonical owner-checkpoint document is `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`.
- Linux baseline evidence: `logs/release_acceptance/20260325_204342/summary.txt`.
- Linux isolated install evidence: `logs/release_acceptance/20260325_205542/summary.txt`.
