# TODO: fpdev fpc v1 — Philosophy, Directories, Commands

## 0) Purpose (Agreed Philosophy)
Prepare a verifiable, switchable, reproducible FPC toolchain with smart reuse (cache/repos), without touching the system environment by default.

- Install target: active data root by default; explicit `--prefix` stays available for custom layouts
- Project-local isolation: opt in by setting `FPDEV_DATA_ROOT` (for example to `$PWD/.fpdev-data`), not by auto-switching data root from `.fpdev/`
- Source: auto (prefer binary mirror; fallback source build)
- Activation: off by default; use `fpdev fpc use <ver>` after install when you want shell/project activation
- Reuse: smart reuse of managed sources/ and caches; skip redundant clone/build
- Verify: mandatory lightweight smoke tests (version check + hello.pas)

---

## 1) Directory Strategy

- Release directory (read-mostly):
  - etc/          → templates and defaults (copied to data etc/ on first run)
  - tools/        → lightweight wrappers and optional bootstraps
  - tmp/          → EMPTY in release; runtime staging only

- Data directory (writable; defaults below; override with `FPDEV_DATA_ROOT`):
  - sources/      → managed source checkouts (fpc/, lazarus/, packages/<name>/)
  - toolchains/   → installed toolchain prefixes (fpc/<version>/)
  - cache/        → binary/source build caches and downloads
  - tmp/          → build staging and scratch (auto-clean)
  - logs/         → operation/build logs
  - etc/          → active configs copied from Release/etc

Platform defaults for data root:
- Portable release: `<install-dir>/data`
- Explicit override: `FPDEV_DATA_ROOT`
- Windows (non-portable): `%APPDATA%\fpdev`
- Linux/macOS (non-portable): `$XDG_DATA_HOME/fpdev`, fallback `~/.fpdev`
- Project-local installs remain possible, but only when the caller explicitly points the data root or prefix into the project

---

## 2) CLI v1 (fpc)

Primary commands to implement now:
- install <version>
  - Current options: `--prefix=<dir>`, `--from-source`, `--from-binary`, `--from=auto|binary|source`, `--jobs=<n>`, `--offline`, `--no-cache`
- use <version>
- list
- status
- verify <version>
- clean [<version>|all]

Deferred (separate epic): repo sub-commands (list/add/update/remove/validate).

---

## 3) Behavior Specs (v1)

### install <version>
- Resolve install prefix:
  - if `--prefix`: use it
  - else: resolve the active data root first, then install to `<data-root>/toolchains/fpc/<version>`
  - active data root resolution follows runtime rules: portable release `data/`, explicit `FPDEV_DATA_ROOT`, Windows `%APPDATA%\fpdev`, Linux/macOS `$XDG_DATA_HOME/fpdev` with `~/.fpdev` fallback
  - project-local installs are an explicit caller choice via `FPDEV_DATA_ROOT` or `--prefix`, not an automatic `.fpdev/` redirect
- Input preparation by source mode:
  - binary: use cache/mirror if available; otherwise error (v1 minimal)
  - source: ensure a managed checkout under `<data-root>/sources/fpc/` exists via smart clone (skip if valid)
  - auto: try binary then source
- Build/Deploy:
  - For v1: wire-through to existing source build path (we already implemented smart clone + step logs). Respect prefix if provided.
- Verify:
  - `fpc -iV` matches version
  - Compile hello.pas (in tmp/) succeeds
- Record metadata:
  - JSON/YAML at `<prefix>/.fpdev-meta.json` with: {version, source_mode, channel, prefix, verify:{ts, ok}, origin:{repo url+commit or binary hash}}
- Activation:
  - Install keeps activation separate; after success, print `fpdev fpc use <version>` as the next-step hint.

### use <version>
- Scope-aware shim activation:
  - project: create `.fpdev/env/activate.(cmd|sh)` and/or `.vscode/settings.json` PATH includes `<prefix>/bin`
  - user: create user-level shim scripts or PATH helpers (without permanently editing global PATH in v1)
- Print the exact commands to activate in current shell.

### list
- Show installed toolchains with prefix, source_mode, verify status.

### status
- Show current effective FPC (resolved on PATH), active scope, and nearest managed prefix.

### verify <version>
- Re-run smoke tests for the specified prefix; update metadata.

### clean [<version>|all]
- Remove tmp/ for current project/data root
- If version provided: remove that prefix’s tmp/build artifacts (not deleting the prefix by default in v1)

---

## 4) Option Parsing (v1)
- Extend `fpdev fpc` command parser to accept long options for `install`.
- Keep the option surface aligned with the current CLI (`--from-source`, `--from-binary`, `--from=`, `--jobs=`, `--prefix=`, `--offline`, `--no-cache`) instead of reintroducing legacy scope flags.
- Store options in a context record passed into the manager (temporary: apply to manager fields).
- Log chosen options visibly before execution.

---

## 5) Manager Integration
- Extend TFPCSourceManager minimally to accept:
  - Install prefix (directory)
  - Effective install root / active data root
  - Source mode enum (auto|binary|source)
  - Offline / no-cache execution flags
- For v1: log + respect prefix directory when writing outputs; keep binary mode as TODO.

---

## 6) Smart Repos (v1 minimal)
- Implement `IsValidSourceDirectory(path)` (done)
- Modify `CloneFPCSource` to skip clone when valid (done)
- Expose higher-level messages; hide raw git

---

## 7) Acceptance Criteria
- `fpdev fpc install 3.2.2` installs into the active data root by default, prints verify result, and does not change system PATH.
- `fpdev fpc install 3.2.2 --prefix C:\toolchains\fpc-3.2.2` installs into that directory and records metadata.
- Re-running install for the same version reuses existing managed sources/cache without re-clone; idempotent packaging to prefix.
- `fpdev fpc list` shows installed versions with prefixes and verify OK/FAIL.
- `fpdev fpc verify 3.2.2` updates metadata.
- No git/source commands are exposed; only high-level outputs.

---

## 8) Milestones
1) CLI: option parsing for `install` + logging chosen plan
2) Manager: accept prefix + respect it; keep current smart clone/build path
3) Verify: implement hello.pas smoke + metadata write
4) list/status/use skeletons printing meaningful info; basic use for project/user activation contexts
5) Clean-up and tests (batch scripts)

---

## 9) Risks / Mitigations
- Binary mirror absence → fallback to source; communicate clearly
- Windows PATH shimming complexity → start with per-shell activation instructions
- Separate system-wide installation flows still need explicit guarding; do not overload the default active-data-root install path

---

## 10) Test Plan (scripts)
- scripts/test_fpc_install_prefix.bat: verifies `--prefix` honored, metadata written
- scripts/test_fpc_idempotent.bat: run install twice; ensure no re-clone; times
- scripts/test_fpc_verify.bat: runs verify and asserts output
- scripts/test_fpc_list_status.bat: confirms list/status formatting

