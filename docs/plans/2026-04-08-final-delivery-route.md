# FPDev Final Delivery Route

**Date**: 2026-04-08
**Scope**: v2.1.0 release close-out
**Audience**: maintainers preparing the final merge, tag, and release publish

---

## Verified Starting Point

As of 2026-04-08, the release branch / PR path is in a mergeable state:

- PR: `#3` (`stabilize/dirty-tree-2026-04-02` -> `main`)
- Merge state: `CLEAN`
- Latest verified public CI run: `24113915296`
- Verified lanes in that run:
  - `compile-check`
  - `release-acceptance-linux`
  - cross-platform CLI smoke for Windows x64, macOS x64, and macOS arm64
  - `Assemble release-ready bundle`

If a newer commit is pushed after this document, treat the latest equivalent green CI run as the new handoff baseline.

## Canonical Release Inputs

- Public status / roadmap: `docs/ROADMAP.md`
- Release acceptance matrix: `docs/MVP_ACCEPTANCE_CRITERIA.md`
- Owner checkpoint handoff: `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
- Release notes: `RELEASE_NOTES.md`

## Final Finish-Line Sequence

### 1. Keep the release branch green

- Do not merge on stale CI.
- If any follow-up commit lands, rerun the relevant doc / contract / release checks first.
- Prefer the current public CI bundle over ad-hoc local proof when both are available.

### 2. Review and merge the green release branch

- Confirm the PR still targets `main`.
- Confirm the latest green CI run belongs to the exact merge commit being approved.
- Merge only when the release branch and public docs still match the intended `v2.1.0` payload.

### 3. Pull the public release-proof handoff

- Download `release-ready-bundle` from GitHub Actions for the release commit.
- Confirm the bundle contains:
  - the four planned release assets
  - `SHA256SUMS.txt`
  - `RELEASE_EVIDENCE.md`
  - Linux release acceptance logs
  - owner-proof transcripts for Windows x64, macOS x64, and macOS arm64

### 4. Create the release tag from the merged commit

Recommended flow:

```bash
git checkout main
git pull
git tag -a v2.1.0 -m "FPDev v2.1.0"
git push origin v2.1.0
```

Tag only after the merged `main` commit matches the verified release-proof bundle.

### 5. Publish the GitHub release payload

- Use the merged/tagged commit as the release source.
- Attach the planned platform assets.
- Publish `SHA256SUMS.txt`.
- Publish `RELEASE_EVIDENCE.md`.
- Use `RELEASE_NOTES.md` as the release note baseline, trimming only if a storefront-specific summary is needed.

### 6. Run a post-publish sanity pass

- Confirm the GitHub release page exposes the expected assets and checksums.
- Confirm `README.md`, `README.en.md`, `docs/ROADMAP.md`, and `RELEASE_NOTES.md` still describe the same release state.
- Spot-check at least one download/install instruction path against the published assets.

## Stop Conditions

Do not publish if any of the following is true:

- the latest PR / merge commit does not have a green `release-ready-bundle`
- release assets differ from the filenames required by the owner-checkpoint doc
- `SHA256SUMS.txt` or `RELEASE_EVIDENCE.md` is missing
- public docs and release payload disagree on version or publish state

## Definition Of Done

The v2.1.0 close-out is complete when:

1. the green release branch has been merged to `main`
2. tag `v2.1.0` points at that merged commit
3. the GitHub release includes assets, checksums, and release evidence
4. the public docs still align with the published release
