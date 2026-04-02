# FPDev Release Acceptance Criteria (v2.1.0)

## Release Goal

Ship FPDev `v2.1.0` with:
- a reproducible Linux release-acceptance lane
- synchronized release documentation and version markers
- explicit owner checkpoints for Windows and macOS

This document replaces the earlier MVP-era checklist with a bounded release close-out matrix.

## Verification Entry Points

| Entry Point | Purpose |
|------------|---------|
| `bash scripts/release_acceptance_linux.sh` | Automated Linux release gate |
| `bash scripts/release_acceptance_linux.sh --with-install` | Optional clean-root binary-install proof on Linux |
| `python3 scripts/update_test_stats.py --check` | Test inventory drift gate |
| `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md` | Windows/macOS owner-run checkpoints |

## Current Close-Out Matrix

| Lane | Scope | Status | Evidence |
|------|-------|--------|----------|
| Linux automated baseline | toolchain, inventory sync, Python regression, full Pascal regression, Release build, CLI smoke | pass | `logs/release_acceptance/20260402_104133/summary.txt` |
| Linux isolated binary install | `fpc install/use/current/verify` in an isolated data root | pass | `logs/release_acceptance/20260402_111602/summary.txt` |
| Windows x64 owner checkpoint | release asset extraction + CLI smoke | pending | owner checkpoint ledger |
| macOS x64 owner checkpoint | release asset extraction + CLI smoke | pending | owner checkpoint ledger |
| macOS arm64 owner checkpoint | release asset extraction + CLI smoke | pending | owner checkpoint ledger |

## Mandatory Automated Gates

- [x] Local toolchain baseline is green on Linux
- [x] Test inventory is synchronized at `273` discoverable `test_*.lpr` programs
- [x] Python regression suite is green
- [x] Full Pascal regression suite is green
- [x] `lazbuild -B --build-mode=Release fpdev.lpi` succeeds
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

## Owner Checkpoints

- [ ] Windows x64 release asset is extracted and smoke-tested
- [ ] macOS x64 release asset is extracted and smoke-tested
- [ ] macOS arm64 release asset is extracted and smoke-tested
- [ ] `SHA256SUMS.txt` is generated for the published assets

## Release Exit Criteria

Release close-out is complete when:

1. the automated Linux baseline is green
2. the release documents and download URLs are synchronized to `v2.1.0`
3. the owner checkpoint ledger is fully signed off

## Notes

- The product roadmap itself is already functionally complete; the remaining work is release engineering and cross-platform sign-off.
- The canonical owner-checkpoint document is `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`.
- Linux baseline evidence: `logs/release_acceptance/20260402_104133/summary.txt`.
- Linux isolated install evidence: `logs/release_acceptance/20260402_111602/summary.txt`.
