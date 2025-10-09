# Changelog

All notable changes to this project will be documented in this file.

This project adheres to small, incremental, and safe changes by default. Dates are in YYYY-MM-DD.

## [1.1.0] - 2025-01-29
### Added
- **Project Management Enhancements**
  - `fpdev project clean`: Clean build artifacts (*.o, *.ppu, *.exe, etc.)
  - `fpdev project run [args]`: Run built executable with optional arguments
  - `fpdev project test`: Discover and run test executables (test*.exe pattern)

- **FPC Source Management**
  - `fpdev fpc clean <version>`: Clean FPC source build artifacts while preserving Git repository
  - `fpdev fpc update <version>`: Update FPC sources via git pull with rebuild detection

- **Test Coverage (TDD Methodology)**
  - 17 comprehensive tests across 5 modules (100% pass rate)
  - test_project_clean.lpr (3 tests): Clean artifacts, error handling
  - test_project_run.lpr (4 tests): Run executable, argument passing, error cases
  - test_project_test.lpr (4 tests): Test discovery, execution, failure handling
  - test_fpc_clean.lpr (3 tests): Recursive cleanup, repository preservation
  - test_fpc_update.lpr (3 tests): Git pull, rebuild detection, conflict handling

### Changed
- Enhanced README.md with detailed usage examples for new commands
- Added typical workflow documentation for FPC source management
- Updated test coverage badge to reflect 17 passing tests

### Documentation
- Added "FPC 源码管理详解" section in README
- Detailed command explanations with example outputs
- Workflow guide: update → clean → rebuild cycle

### Notes
- All features developed using Test-Driven Development (Red-Green-Refactor)
- Phase 1 completion: 90% (9/10 tasks complete)
- Production-ready code quality maintained throughout

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

