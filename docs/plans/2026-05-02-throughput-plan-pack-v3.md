# Throughput Plan Pack V3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Queue the next FPDev work as three executable helper-wave candidates with clear stop conditions, so implementation can continue without another broad repo re-rank first.

**Architecture:** Split the batch by responsibility seam and blast radius. Wave A targets `src/fpdev.version.registry.pas`, where reload/json/default composition is still mixed with singleton/query API. Wave B targets `src/fpdev.package.registry.pas`, where query reads can be separated from lifecycle/index mutation. Wave C targets `src/fpdev.cross.downloader.pas`, but only the verification slice; manifest refresh and download/install ownership stay in the downloader.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest, Markdown planning files

---

## Wave Queue

1. `docs/plans/2026-05-02-version-registry-loader-wave.md`
   - Priority: highest
   - Reason: `src/fpdev.version.registry.pas` still mixes search-path scan, JSON parsing, embedded defaults, and query API in one singleton
   - Dependency: none

2. `docs/plans/2026-05-02-package-registry-queryflow-wave.md`
   - Priority: high
   - Reason: `src/fpdev.package.registry.pas` has a clean read/query seam that should be extractable without reopening add/remove lifecycle ownership
   - Dependency: none

3. `docs/plans/2026-05-02-cross-downloader-verificationflow-wave.md`
   - Priority: medium-high
   - Reason: `src/fpdev.cross.downloader.pas` still inlines binary verification, version probing, metadata writeback, and JSON reload glue
   - Dependency: start only after a fresh clean-tree checkpoint or in a separate worktree, because it touches a larger stateful runtime surface

## Dependency Notes

- Wave A and Wave B are logically independent.
- Wave C is also logically independent, but it is more stateful; if parallelized, put it in its own worktree.
- Every wave must start with:
  - one Python boundary RED
  - one focused Pascal direct-helper RED
  - a seam audit proving the helper will not widen the public API
- If a wave fails that seam audit, record a no-go checkpoint in `task_plan.md`, `progress.md`, and `findings.md` instead of forcing the extraction.

## Parallel Execution Notes

- Recommended parallel pair: Wave A + Wave B.
- Wave C should run alone unless filenames and write ownership are reserved up front.
- Do not let two waves edit the same root planning files simultaneously in the same worktree; sync those files during closeout only.

## Batch Acceptance

- Each wave must:
  - write RED tests first
  - run focused verification on the new helper and the nearest downstream consumers
  - sync `task_plan.md`, `findings.md`, and `progress.md`
  - give a short review conclusion
  - commit before moving to the next wave
