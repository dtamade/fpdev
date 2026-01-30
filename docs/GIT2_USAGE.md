# FPDev Git2 – Usage and Build Guide

The repository provides a layered Git integration:

- Public OO wrapper over libgit2: `src/fpdev.git2.pas`
- Modern interfaces (recommended for new code): `src/git2.api.pas` + adapter impl `src/git2.impl.pas`
- C API bindings (libgit2): `src/libgit2.pas`

Notes:
- `fpdev.git2` exposes concrete classes (TGitManager/TGitRepository/...) and keeps a compatibility shim `TGit2Manager`.
- New code should prefer `git2.api` + `git2.impl` (interfaces first, easy to replace backends). Existing code can continue to use `fpdev.git2` safely.
- `fpdev.git` (system git command wrapper) is deprecated; libgit2 path is the preferred backend.

---

## Quick Start

- Recommended imports in applications/tests:

  - Preferred: `uses git2.api, git2.impl;` then `NewGitManager()` to obtain `IGitManager`
  - Compatible: `uses fpdev.git2;` then `GitManager` singleton or `TGitManager.Create`
  - Only import `libgit2` when you must call the C API directly

- Build (Lazarus is on PATH):

  - `lazbuild --build-all --no-write-project test_libgit2_simple.lpi`
  - `lazbuild --build-all --no-write-project test_libgit2_complete.lpi`
  - `lazbuild --build-all --no-write-project tests\test_git2_adapter.lpi`
  - `lazbuild --build-all --no-write-project tests\test_ssl_toggle.lpi`
  - `lazbuild --build-all --no-write-project tests\test_offline_repo.lpi`

- Runtime requirement (Windows): Ensure `git2.dll` is discoverable (next to the executable or in PATH).

---

## High‑level API (fpdev.git2)

Exposes modern OO wrappers around libgit2:

- `TGitManager`: lifecycle & helpers (Initialize/Finalize, OpenRepository, CloneRepository, InitRepository, DiscoverRepository, Get/Set config, GetVersion, VerifySSL)
- `TGitRepository`: open/clone, current branch, list branches, refs/commits, fetch, simple status checks
- `TGitCommit`, `TGitReference`, `TGitRemote`, `TGitSignature` and `EGitError`

Minimal example:

```pascal
program example_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git2;

var
  M: TGitManager;
  R: TGitRepository;
  Branches: TStringArray;
  B: string;
begin
  M := TGitManager.Create;
  try
    if not M.Initialize then
      raise Exception.Create('libgit2 init failed');

    // Open current working directory repo (if any)
    R := M.OpenRepository('.');
    try
      Writeln('WorkDir: ', R.WorkDir);
      Writeln('Current: ', R.GetCurrentBranch);

      Writeln('Local branches:');
      Branches := R.ListBranches(GIT_BRANCH_LOCAL);
      for B in Branches do Writeln('  - ', B);
    finally
      R.Free;
    end;
  finally
    M.Free;
  end;
end.
```

Error handling: high‑level methods raise `EGitError` on non‑zero returns from libgit2. Read `E.Message` for details.

---

## C API (libgit2)

Import `libgit2` only when necessary for direct calls. The unit provides:

- Basic handles/types (git_repository, git_reference, git_commit, git_oid, etc.)
- Core functions (git_repository_open/init/head/workdir, git_reference_*, git_commit_*, git_branch_*, git_remote_*, status helpers, options init, credentials, etc.)

Example (opening a repository and reading HEAD):

```pascal
uses SysUtils, libgit2;

var
  Repo: git_repository;
  Head: git_reference;
begin
  if git_libgit2_init < 0 then Halt(1);
  if git_repository_open(Repo, '.') = GIT_OK then
  begin
    try
      if git_repository_head(Head, Repo) = GIT_OK then
        Writeln('HEAD: ', git_reference_name(Head));
    finally
      git_repository_free(Repo);
    end;
  end;
  git_libgit2_shutdown;
end.
```

---

## Migration Notes

- Replace any `uses git2.modern` with `uses fpdev.git2`.
- Replace any `uses libgit2_netstructs` or `libgit2.dynamic` with nothing (types/options are unified in `libgit2.pas`).
- Where old code passed `libgit2.dynamic.git_branch_t(...)`, use plain `GIT_BRANCH_LOCAL/REMOTE/ALL` directly.

---

## Testing

Build tests individually with `lazbuild --build-all --no-write-project <project>.lpi`. The test projects under `tests/` have been cleaned to only import what they use. Warnings/hints are kept minimal by default.

---

## Support Matrix & Notes

- Windows: looks for `git2.dll`
- Linux/macOS: ensure appropriate libgit2 shared library is available (see constants in `libgit2.pas` for default names)
- Compilers: tested with recent FPC trunk; adjust as needed.

---

## Contact / Contributing

- Open issues for missing libgit2 API you need. Prefer adding to `fpdev.git2` first; expose C API only when necessary.
- Keep the one‑unit‑per‑layer rule: high‑level in `fpdev.git2`, C API in `libgit2`.
