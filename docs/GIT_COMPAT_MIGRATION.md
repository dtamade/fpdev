# Git Compat Migration

`fpdev.utils.git` used to be the legacy compatibility layer for `TGitOperations` / `IGitCliRunner`.

New code should not add fresh dependencies on its public helper wrappers. Prefer the lightweight shared units instead:

- Backend enum and string conversion: `fpdev.git.types`
- Pull failure classification: `fpdev.git.errors`
- Credential and identity environment helpers: `fpdev.git.env`
- `TGitOperations` / `IGitCliRunner`: `fpdev.git.operations`

Breaking removal completed:

- `fpdev.utils.git.TGitBackend` -> use `fpdev.git.types.TGitBackend`
- `fpdev.utils.git.TGitPullFailureKind` -> use `fpdev.git.errors.TGitPullFailureKind`
- `fpdev.utils.git.gpfkUnknown` / `gpfkDirtyWorktree` / `gpfkDetachedHead` / `gpfkDivergedHistory` -> use `fpdev.git.errors`
- `fpdev.utils.git.GitBackendToString(...)`
- `fpdev.utils.git.ClassifyGitPullFailure(...)`
- `fpdev.utils.git.ResolveGitCredentialEnv(...)`
- `fpdev.utils.git.ResolveGitIdentityEnv(...)`
- `fpdev.utils.git.TGitOperations` -> use `fpdev.git.operations.TGitOperations`
- `fpdev.utils.git.IGitCliRunner` -> use `fpdev.git.operations.IGitCliRunner`

These aliases and helper wrappers have been removed from the `fpdev.utils.git` public surface.
The compatibility shim unit has been deleted.
External callers must switch to `fpdev.git.operations`.

Current repository policy:

- Default production code should use `fpdev.git.types`, `fpdev.git.errors`, or `fpdev.git.env` directly.
- Default tests should cover shared helpers directly.
- `src/fpdev.git.operations.pas` is the default facade for `TGitOperations` / `IGitCliRunner`.
- The concrete `TGitOperations` / `IGitCliRunner` implementation now lives in `src/fpdev.git.operations.impl.pas`.
- `src/fpdev.utils.git.pas` has been removed in this breaking window.

- Retained implementation bridges.
  - `src/fpdev.git.operations.pas` remains the default facade over `src/fpdev.git.operations.impl.pas`.
  - `src/fpdev.fpc.builder.gitruntime.pas` stays builder-specific until a second non-builder caller needs the process-runner clone adapter.
  - `tests/test_git_operations.lpr` stays as the focused contract suite for `fpdev.git.operations`, not as a legacy compat caller.

## Final removal gates

- Repository code and focused tests no longer import `fpdev.utils.git` directly.
- Active docs may mention `fpdev.utils.git` only when explaining migration or compatibility scope.
- The shim unit has been deleted; external callers must switch to `fpdev.git.operations`.
- The breaking release note explicitly lists `TGitOperations` and `IGitCliRunner` removal.
- The boundary suite and migration docs stay green after the final compatibility aliases are deleted.
- The staged execution checklist lives in `docs/plans/2026-04-10-git-compat-breaking-removal.md`.

## Current text-reference buckets

- Active docs
  - `docs/GIT_COMPAT_MIGRATION.md`
  - `docs/GIT2_USAGE.md`
  - `docs/GIT2_USAGE.en.md`
  - `docs/ARCHITECTURE.md`
  - `docs/ARCHITECTURE.en.md`
  - `docs/LIBGIT2_INTEGRATION.md`
  - `docs/LIBGIT2_INTEGRATION.en.md`
- Historical docs and plan snapshots
  - `docs/history/`
  - `docs/plans/`
- Source and focused tests
  - Default repository code now routes through `fpdev.git.operations` or lighter shared units.
  - Repository code and focused tests no longer import `fpdev.utils.git` directly.
