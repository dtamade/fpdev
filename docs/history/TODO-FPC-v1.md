# TODO: fpdev fpc v1 — Philosophy, Directories, Commands

> 2026-04-06 更新：本文是早期 `fpdev fpc v1` 计划草案，不是当前工作树状态说明。
> 当前工作树中的命令边界、交付状态和验证入口应以 `README.md`、`docs/ROADMAP.md`、活跃测试项目以及现行契约测试结果为准。
> 文中早期 draft 提到的 `.bat` 测试 wrappers 目前在仓库中未跟踪；若需要当前可执行入口，请优先使用 `scripts/run_single_test.sh` 配合现有 `.lpi` 测试项目。

## 0) Purpose (Agreed Philosophy)
Prepare a verifiable, switchable, reproducible FPC toolchain with smart reuse (cache/repos), without touching the system environment by default.

- Scope: project (if .fpdev) else user; system only with explicit consent
- Source: auto (prefer binary mirror; fallback source build)
- Activation: off by default (use `fpdev fpc use <ver>` or `--activate`)
- Reuse: smart reuse of repositorys/ and caches; skip redundant clone/build
- Verify: mandatory lightweight smoke tests (version check + hello.pas)

---

## 1) Directory Strategy

- Release directory (read-mostly):
  - etc/          → templates and defaults (copied to data etc/ on first run)
  - tools/        → lightweight wrappers and optional bootstraps
  - tmp/          → EMPTY in release; runtime staging only

- Data directory (writable; defaults below; override with FPDEV_HOME):
  - repositorys/  → source repos (fpc/, lazarus/, packages/<name>/)
  - toolchains/   → installed toolchain prefixes (fpc/<version>/)
  - cache/        → binary/source build caches and downloads
  - tmp/          → build staging and scratch (auto-clean)
  - logs/         → operation/build logs
  - etc/          → active configs copied from Release/etc

Platform defaults for data root:
- Windows: %LOCALAPPDATA%/fpdev
- Linux: $XDG_DATA_HOME/fpdev or ~/.local/share/fpdev
- macOS: ~/Library/Application Support/fpdev
- Project mode: if `.fpdev/` present → use `.fpdev/` as data root

---

## 2) CLI v1 (fpc)

Primary commands to implement now:
- install <version>
  - Options: `--prefix DIR`, `--scope user|project|system`, `--source auto|binary|source`, `--activate`, `--cache use|refresh|only`, `--offline`, `--channel stable|fixes|main`
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
  - else by scope:
    - project: `.fpdev/toolchains/fpc/<version>`
    - user: `<DATA_ROOT>/toolchains/fpc/<version>`
    - system: guarded; require confirmation flag (not in v1)
- Input preparation by source mode:
  - binary: use cache/mirror if available; otherwise error (v1 minimal)
  - source: ensure repositorys/fpc/<chan-or-ver> exists via smart clone (skip if valid)
  - auto: try binary then source
- Build/Deploy:
  - For v1: wire-through to existing source build path (we already implemented smart clone + step logs). Respect prefix if provided.
- Verify:
  - `fpc -iV` matches version
  - Compile hello.pas (in tmp/) succeeds
- Record metadata:
  - JSON/YAML at `<prefix>/.fpdev-meta.json` with: {version, scope, source_mode, channel, prefix, verify:{ts, ok}, origin:{repo url+commit or binary hash}}
- Activation:
  - If `--activate`: run `use <version>` in selected scope; otherwise print activation hint.

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
- Store options in a context record passed into the manager (temporary: apply to manager fields).
- Log chosen options visibly before execution.

---

## 5) Manager Integration
- Extend TFPCSourceManager minimally to accept:
  - Install prefix (directory)
  - Scope hint
  - Source mode enum (auto|binary|source)
  - Cache mode enum (use|refresh|only)
- For v1: log + respect prefix directory when writing outputs; keep binary mode as TODO.

---

## 6) Smart Repos (v1 minimal)
- Implement `IsValidSourceDirectory(path)` (done)
- Modify `CloneFPCSource` to skip clone when valid (done)
- Expose higher-level messages; hide raw git

---

## 7) Acceptance Criteria
- `fpdev fpc install 3.2.2` installs into user scope by default, prints verify result, does not change system PATH.
- `fpdev fpc install 3.2.2 --prefix C:\toolchains\fpc-3.2.2` installs into that directory and records metadata.
- Re-running install for the same version reuses existing repositorys without re-clone; idempotent packaging to prefix.
- `fpdev fpc list` shows installed versions with prefixes and verify OK/FAIL.
- `fpdev fpc verify 3.2.2` updates metadata.
- No git/source commands are exposed; only high-level outputs.

---

## 8) Milestones
1) CLI: option parsing for `install` + logging chosen plan
2) Manager: accept prefix + respect it; keep current smart clone/build path
3) Verify: implement hello.pas smoke + metadata write
4) list/status/use skeletons printing meaningful info; basic use for project scope
5) Clean-up and tests (batch scripts)

---

## 9) Risks / Mitigations
- Binary mirror absence → fallback to source; communicate clearly
- Windows PATH shimming complexity → start with per-shell activation instructions
- Permissions on system scope → defer to later guarded implementation

---

## 10) Test Plan (planned coverage placeholders)
- Current executable entrypoint: `scripts/run_single_test.sh`
- Closest active install/verify coverage:
  - `bash scripts/run_single_test.sh tests/test_fpc_install_cli.lpr`
  - `bash scripts/run_single_test.sh tests/test_fpc_management.lpr`
  - `bash scripts/run_single_test.sh tests/test_fpc_verify.lpr`
  - `bash scripts/run_single_test.sh tests/test_fpc_current.lpr`
- The earlier `scripts/test_fpc_*.bat` names in this plan are placeholders from the draft, not tracked files in the current worktree.
