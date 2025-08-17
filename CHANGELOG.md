# Changelog

All notable changes to this project will be documented in this file.

This project adheres to small, incremental, and safe changes by default. Dates are in YYYY-MM-DD.

## [0.1.1] - 2025-08-17
### Added
- Preflight() environment and path checks (make availability, source path, sandbox/logs writability, sandbox dest when install allowed).
- Dry-run mode via SetDryRun(): log intended make commands without executing them.
- Demo scripts support for --preflight/--dry-run and env vars PREFLIGHT/DRY_RUN.
- Documentation section: Preflight & Dry-run usage, examples, and notes.

### Notes
- Conservative by default: both features are non-destructive and improve safety/diagnosability prior to actual builds.

## [0.1.0] - 2025-08-17
### Added
- BuildManager strict mode with configurable checklist via `build-manager.strict.ini` (sections: `[bin]`, `[lib]`, `[share]`, `[fpc]`, `[include]`, `[doc]`).
- Strict config multi-location search (first match): `SetStrictConfigPath` → project root → `plays/fpdev.build.manager.demo` → sandbox.
- Verbose diagnostics: OS/PATH environment snapshot, full `make` command line logging, directory samples for sandbox `bin/` and `lib/`.
- Phase timing: `elapsed_ms` in BuildCompiler/BuildRTL/Install end logs.
- Failure hints and samples (verbose=1) for strict mode checks.
- Cross-platform demo scripts:
  - Windows: `plays/fpdev.build.manager.demo/buildOrTest.bat` (with `--help`).
  - Linux/macOS: `plays/fpdev.build.manager.demo/buildOrTest.sh` (with `--help`).
- Demo switches and env vars: `--strict/--verbose/--no-install/--test-only` and `DEMO_STRICT/DEMO_VERBOSE/NO_INSTALL/TEST_ONLY` (Windows) or `STRICT/VERBOSE/NO_INSTALL/TEST_ONLY` (Unix).
- Strict checklist template: `plays/fpdev.build.manager.demo/build-manager.strict.ini`.
- Documentation:
  - Logs field guide (Start/End, elapsed_ms, env, make, samples, WARN/FAIL/hint).
  - Strict config template and recommended checklist.
  - Cross-platform notes (PATH delimiter, make behavior).
  - CI examples for self-hosted Windows and Linux.
  - Linux/macOS FPC installation references.

### Changed
- TestResults prioritizes sandbox checks when install is allowed; falls back to source tree checks otherwise.
- Install logs now include destination path and Start/End markers; verbose mode logs environment snapshot.

### Quality & Safety
- Strict mode remains opt-in; default behavior is conservative with WARNs instead of FAILs.
- fpc.cfg lightweight validation: requires existence and non-empty when configured.

[0.1.0]: https://example.com/compare/initial...v0.1.0

