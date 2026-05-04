# FPDev Git Operations Guide

This guide shows the current Git module boundaries in FPDev, the default entrypoints, and the smallest focused test entrypoints to use before changing them.

Start with this:

- Use `fpdev.git.operations` for the default system-git facade
- Use `git2.api + git2.impl` for the default libgit2 modern interface
- Use `fpdev.git2` only when you need the legacy concrete wrapper
- Use [Git Compat Migration](GIT_COMPAT_MIGRATION.md) for migration-only context

## Use `fpdev.git.operations` as the default system-git facade

`fpdev.git.operations` is the current default entrypoint for system-git-backed repository work.

- public facade: `src/fpdev.git.operations.pas`
- concrete implementation: `src/fpdev.git.operations.impl.pas`
- supporting helper units:
  - `src/fpdev.git.types.pas`
  - `src/fpdev.git.errors.pas`
  - `src/fpdev.git.env.pas`
  - `src/fpdev.git.operations.coreflow.pas`
  - `src/fpdev.git.operations.identityflow.pas`
  - `src/fpdev.git.operations.transportflow.pas`
  - `src/fpdev.git.operations.queryflow.pas`
  - `src/fpdev.git.operations.mutationflow.pas`
  - `src/fpdev.git.operations.syncflow.pas`
  - `src/fpdev.git.operations.probeflow.pas`
  - `src/fpdev.git.runtime.pas`
  - `src/fpdev.git.runtime.impl.pas`

Use this layer when you need:

- clone / fetch / pull / checkout / push style repository operations
- one default backend-selection surface
- the current `TGitOperations` / `IGitCliRunner` workflow

If you're wiring new production code to the system-git path, start here instead of trying to revive the removed compatibility shim.

## Use `git2.api + git2.impl` as the default libgit2 modern interface

`git2.api + git2.impl` is the current recommended modern libgit2 layer.

- interfaces: `src/git2.api.pas`
- implementation adapter: `src/git2.impl.pas`
- shared backend core: `src/git2.core.pas`

Use this layer when you need:

- new libgit2-backed repository features
- interface-first code that can swap backends later
- direct access to `IGitManager` / `IGitRepository`

If you want a concrete wrapper without dropping back to the legacy surface, `git2.modern` is still the right bridge.

## Use `fpdev.git2` only for the legacy concrete wrapper

`fpdev.git2` is still tracked in the current worktree, but its role is now narrower.

- unit: `src/fpdev.git2.pas`
- internal note: it is now a compatibility re-export over the shared `git2.core` backend

It is still safe for existing callers, but it should not be the default place to grow new code.

The default order is:

1. `fpdev.git.operations` for the system-git facade
2. `git2.api + git2.impl` for the modern libgit2 interface
3. `fpdev.git2` for the legacy concrete wrapper

## Run these focused tests before changing Git code

There are two focused test groups.

### System-git facade focused tests

- `tests/test_git_operations.lpr`
- `tests/test_git_operations_coreflow.lpr`
- `tests/test_git_operations_identityflow.lpr`
- `tests/test_git_operations_transportflow.lpr`
- `tests/test_git_operations_queryflow.lpr`
- `tests/test_git_operations_mutationflow.lpr`
- `tests/test_git_operations_syncflow.lpr`
- `tests/test_git_operations_probeflow.lpr`
- `tests/test_git_env_identity.lpr`
- `tests/test_git_env_credentials.lpr`

These lock:

- the default `fpdev.git.operations` facade behavior
- the current internal libgit2 repo/index/remote/tree/checkout helper behavior
- the current internal identity/signature helper behavior
- the current internal transport credential/options helper behavior
- the current internal query/read helper behavior
- the current internal mutation-surface helper behavior
- the current internal sync-surface helper behavior
- the current internal probe-surface helper behavior
- environment-based credential and identity resolution
- the lightweight shared helper surfaces

### libgit2 focused lanes

- `tests/fpdev.git2/` for the legacy concrete-wrapper lane
- `tests/fpdev.git2.modern/` for the modern interface lane

The most important current entrypoints are:

- `tests/fpdev.git2/fpdev.git2.fpcunit.lpr`
- `tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr`

If you only need one focused run, prefer these tracked entrypoints instead of inventing a temporary script.

## Choose the surface before you edit

If your change is about:

- backend detection, clone, fetch, pull, checkout, or push:
  - start with `fpdev.git.operations`
- libgit2 interface design:
  - start with `git2.api + git2.impl`
- compatibility for older callers:
  - confirm whether you really need `fpdev.git2`

If your first instinct is to look for the old compat entrypoint, you're looking at an old model. That compatibility shim is gone, and the migration-only explanation lives in [Git Compat Migration](GIT_COMPAT_MIGRATION.md).

## Related docs

- [Git2 Usage](GIT2_USAGE.en.md)
- [Git Compat Migration](GIT_COMPAT_MIGRATION.md)
- [libgit2 Integration](LIBGIT2_INTEGRATION.en.md)
