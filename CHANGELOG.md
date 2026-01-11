# Changelog

All notable changes to this project will be documented in this file.

This project adheres to small, incremental, and safe changes by default. Dates are in YYYY-MM-DD.

## [2.0.0] - 2026-01-11
### Added
- **Architecture Refactor**
  - Interface-driven design with automatic memory management
  - Three-layer Git integration (Application → Adapter → Native)
  - Unified command registry with hierarchical dispatch

- **Build System**
  - fpdev.build.cache.pas: Build caching for faster rebuilds
  - fpdev.build.config.pas: Configuration management
  - fpdev.build.cross.pas: Cross-compilation support
  - fpdev.build.logger.pas: Structured logging
  - fpdev.build.toolchain.pas: Toolchain management
  - fpdev.fpc.builder.pas: FPC builder
  - fpdev.fpc.installer.pas: Installation manager
  - fpdev.fpc.validator.pas: Validation utilities

- **FPC Management Enhancements**
  - `fpdev fpc uninstall <version>`: Uninstall specific FPC version
  - `fpdev fpc help`: FPC-specific help system
  - Enhanced `fpdev fpc doctor` with detailed diagnostics

- **Lazarus Management Enhancements**
  - `fpdev lazarus configure`: Configure Lazarus installation
  - `fpdev lazarus doctor`: Diagnostic checks for Lazarus
  - `fpdev lazarus install <version>`: Install Lazarus version
  - `fpdev lazarus show <version>`: Show version details
  - `fpdev lazarus test`: Test Lazarus installation
  - `fpdev lazarus uninstall <version>`: Uninstall Lazarus version
  - `fpdev lazarus update`: Update Lazarus sources

- **Cross-Compilation Support**
  - `fpdev cross list [--all]`: List cross-compilation targets
  - `fpdev cross show <target>`: Show target details
  - `fpdev cross enable <target>`: Enable cross-compiler
  - `fpdev cross disable <target>`: Disable cross-compiler
  - `fpdev cross test <target>`: Test cross-compiler
  - `fpdev cross install <target>`: Install cross-compiler
  - `fpdev cross uninstall <target>`: Uninstall cross-compiler
  - `fpdev cross configure`: Configure cross-compilation
  - `fpdev cross doctor`: Diagnose cross-compilation setup

- **Package Management**
  - `fpdev package install <package>`: Install package
  - `fpdev package list [--all]`: List packages
  - `fpdev package search <query>`: Search packages
  - `fpdev package info <package>`: Show package info
  - `fpdev package uninstall <package>`: Uninstall package
  - `fpdev package update <package>`: Update package
  - `fpdev package clean`: Clean package cache
  - `fpdev package install-local <path>`: Install from local
  - `fpdev package create <name>`: Create new package
  - `fpdev package publish <name>`: Publish package
  - `fpdev package repo add <name> <url>`: Add repository
  - `fpdev package repo list`: List repositories
  - `fpdev package repo remove <name>`: Remove repository
  - `fpdev package repo update`: Update repositories

- **Project Management**
  - `fpdev project new <name> [--template]`: Create new project
  - `fpdev project list`: List projects
  - `fpdev project info <name>`: Show project info
  - `fpdev project build [name]`: Build project
  - `fpdev project clean [name]`: Clean project
  - `fpdev project test [name]`: Test project
  - `fpdev project run [name] [args]`: Run project

- **Internationalization**
  - fpc.i18n.pas: Core i18n module
  - fpdev.i18n.pas: Main i18n implementation
  - fpdev.i18n.strings.pas: String resources

- **Logging & Output**
  - fpdev.logger.intf.pas: Logger interface
  - fpdev.logger.console.pas: Console logger
  - fpdev.output.intf.pas: Output interface
  - fpdev.output.console.pas: Console output
  - fpdev.ui.progress.pas: Progress UI

- **Utility Modules**
  - fpdev.utils.fs.pas: Filesystem utilities
  - fpdev.utils.git.pas: Git utilities
  - fpdev.utils.process.pas: Process utilities
  - fpdev.types.pas: Type definitions
  - fpdev.result.pas: Result types
  - fpdev.version.pas: Version management
  - fpdev.version.registry.pas: Version registry

### Changed
- **Core Modules**
  - Updated fpdev.collections.pas: Improved data structures
  - Updated fpdev.command.*.pas: Better command handling
  - Updated fpdev.config.*.pas: Enhanced configuration
  - Updated fpdev.paths.pas: Path utilities
  - Updated fpdev.params.pas: Parameter handling
  - Updated fpdev.terminal.pas: Terminal I/O
  - Updated fpdev.toolchain.*.pas: Toolchain support
  - Updated fpdev.utils.*.pas: Utility functions
  - Updated git2.*.pas: Git API bindings
  - Updated libgit2.pas: libgit2 wrapper

- **Configuration**
  - Updated src/data/config.json: New configuration schema
  - Updated .gitignore: Ignore reference/, .cunzhi-memory/, .vscode/

- **Cross-Platform Compatibility**
  - Fixed hardcoded path separators to use PathDelim constant
  - Improved Windows/Linux/macOS compatibility

### Removed
- Obsolete test .lpi files (26 files)
- Old log files

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

