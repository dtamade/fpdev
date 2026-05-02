# Throughput Plan Pack V2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Queue the next FPDev work as three larger executable waves instead of reopening small truth-sync patches one at a time.

**Architecture:** Keep the next batch split by dependency surface. Wave A extends release-path truth into cross-platform CI and owner-proof steps. Wave B closes the explicit remaining Git module documentation/todo backlog. Wave C targets the largest remaining Git hotspot with a narrow identityflow seam instead of a broad rewrite.

**Tech Stack:** Bash, PowerShell, GitHub Actions workflow contracts, Markdown docs, Python unittest, focused Pascal tests

---

## Wave Queue

1. `docs/plans/2026-05-02-cross-platform-release-proof-path-parity-wave.md`
   - Priority: highest
   - Reason: current CI smoke and owner-proof steps still hardcode `bin/fpdev` / `bin/fpdev.exe`
   - Dependency: none

2. `docs/plans/2026-05-02-git-module-closeout-wave.md`
   - Priority: high
   - Reason: explicit unchecked Git module closeout item remains in `todo/git/todo.md`
   - Dependency: none

3. `docs/plans/2026-05-02-git-operations-identityflow-wave.md`
   - Priority: medium-high
   - Reason: `src/fpdev.git.operations.impl.pas` remains the largest active Git hotspot and shows a repeated identity/credential cluster
   - Dependency: should start from a fresh clean tree after Wave A or Wave B commit

## Dependency Notes

- Wave A and Wave B can be implemented independently.
- Wave C should not start with code edits until its focused RED boundary is written and the identityflow seam is confirmed.
- If Wave C audit disproves the seam, record a no-go checkpoint instead of forcing another low-value extraction.

## Batch Acceptance

- Each wave must:
  - write RED tests first
  - run focused verification
  - sync `task_plan.md`, `findings.md`, `progress.md`
  - give a short review conclusion
  - commit before moving to the next wave
