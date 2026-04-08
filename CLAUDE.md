# CLAUDE.md

This file is the short contributor index for FPDev. Keep it focused on high-frequency guidance. Put detailed design notes in `docs/`.

## Project Overview

FPDev is a Free Pascal development environment manager for FPC, Lazarus, cross-compilers, packages, and project workflows across Windows, Linux, and macOS.

- Language: Object Pascal (`{$mode objfpc}{$H+}`)
- Primary build tool: `lazbuild`
- Optional fallback compiler: `fpc`
- Git backend: `libgit2`

## Start Here

### Build the main program

```bash
lazbuild -B fpdev.lpi
```

### Build a release binary

```bash
lazbuild -B --build-mode=Release fpdev.lpi
```

### Run the full test baselines

```bash
python3 -m pytest tests -q
bash scripts/run_all_tests.sh
```

### Run one Pascal test quickly

```bash
bash scripts/run_single_test.sh tests/test_config_management.lpr
```

### Check local toolchain prerequisites

```bash
scripts/check_toolchain.sh
```

Use `lazbuild -B` as the standard build path. Use direct `fpc` compilation only when the Lazarus project is not the right tool for the job.

## Repository Map

- `src/`: main program, CLI commands, core managers, flows, and adapters
- `tests/`: `fpcunit` test programs plus a small Python regression layer
- `scripts/`: test runners, maintenance helpers, acceptance scripts
- `docs/`: architecture, specs, setup, migration notes, and release plans
- `bin/`, `lib/`: generated artifacts, ignored by git

## Codebase Hotspots

### Command registration and dispatch

FPDev uses a command tree plus registry pattern.

- `src/fpdev.command.intf.pas`: `ICommand`, `IContext`
- `src/fpdev.command.tree.pas`: command tree nodes
- `src/fpdev.command.registration.pas`: path registration and aliases
- `src/fpdev.command.registry.pas`: registry facade and dispatch
- `src/fpdev.command.imports.pas`: domain import aggregation for command registration
- `src/fpdev.cli.bootstrap.pas`: help/context/bootstrap wiring
- `src/fpdev.lpr`: thin executable entry that delegates to the CLI runner

Command units follow these naming patterns:

- Root commands: `src/fpdev.cmd.<domain>.pas`
- Subcommands: `src/fpdev.cmd.<domain>.<action>.pas`

### Git integration

Prefer the interface-based Git stack for new code:

- `git2.api.pas`
- `git2.impl.pas`

Compatibility layers still exist, but treat them as legacy:

- `src/fpdev.git2.pas`
- `src/fpdev.utils.git.pas`
- `src/fpdev.git.pas`

### Configuration and toolchains

Look here first:

- `src/fpdev.config.*.pas`
- `src/fpdev.fpc.*.pas`
- `src/fpdev.lazarus.*.pas`
- `src/fpdev.cross.*.pas`

### Package and registry flows

Local package registry paths must be data-root based, not hard-coded home-directory paths.

- Correct pattern: `GetDataRoot + PathDelim + 'registry'`
- Avoid: `~/.fpdev/registry`

## Working Rules

### Write tests first for behavior changes

FPDev follows red-green-refactor. For a bugfix or feature:

1. Add or tighten a focused failing test.
2. Make the smallest production change that turns it green.
3. Re-run focused tests, then broader baselines.

Keep tests offline and deterministic when possible.

### Register new commands in two places

When adding a command:

1. Create `src/fpdev.cmd.<domain>.<action>.pas`
2. Register it in the unit `initialization` section with `GlobalCommandRegistry.RegisterPath(...)`
3. Add the unit to the relevant `src/fpdev.command.imports.<domain>.pas` aggregator so bootstrap can load it
4. Add focused CLI or registry coverage under `tests/`

### Prefer interface-driven code

New code should prefer the interface-based layers instead of deprecated global facades or shared singletons when a modern interface already exists.

### Keep user data paths portable

Use project helpers such as `GetDataRoot`, `GetConfigPath`, and `PathDelim`. Do not bake OS-specific home paths into code, examples, or docs.

## Critical Gotchas

### Avoid Unicode terminal output on Windows

Keep CLI output ASCII-safe unless the code path is already explicitly Unicode-aware. Windows console handling is still a common source of test and runtime noise.

### Use `PathDelim` and path helpers

Do not hard-code `/` or `\` in Pascal path-building logic. Prefer `PathDelim`, `IncludeTrailingPathDelimiter`, `ExtractFileDir`, and related helpers.

### Be explicit about libgit2 lifecycle

If you touch lower-level Git manager code, make sure initialization and shutdown are paired correctly. The interface-based manager handles this more safely than the raw facade.

## Common Contribution Paths

### Add a new CLI command

Start from:

- `src/fpdev.cmd.fpc.list.pas`
- `src/fpdev.cmd.project.new.pas`
- `tests/test_command_registry.lpr`

### Add or tighten a CLI contract test

Look at:

- `tests/test_command_registry.lpr`
- `tests/test_cli_project.lpr`
- `tests/test_cli_package.lpr`
- `tests/test_cli_lazarus.lpr`
- `tests/test_cli_cross.lpr`

### Work on FPC and Lazarus install flows

Relevant areas:

- `src/fpdev.fpc.installer.*.pas`
- `src/fpdev.fpc.manager.pas`
- `src/fpdev.lazarus.source.pas`
- `tests/test_fpc_installer*.lpr`
- `tests/test_lazarus*.lpr`

## Docs Map

Use these as the canonical detailed references:

- `docs/ARCHITECTURE.md`: architecture and command-system overview
- `docs/ARCHITECTURE.en.md`: English architecture reference
- `docs/testing.md`: test layout, TDD conventions, and test-running examples
- `docs/GIT2_USAGE.md`: Git adapter usage and integration notes
- `docs/config-architecture.md`: configuration architecture details
- `docs/build-manager.md`: build manager usage and API guidance
- `docs/ERROR_HANDLING_GUIDE.md`: logging, diagnostics, and recovery patterns
- `docs/FPC_MANAGEMENT.md`: FPC lifecycle behavior and command reference
- `docs/INSTALLATION.md`: environment setup, logging, and troubleshooting
- `docs/history/PACKAGE_CREATION_DESIGN.md`: historical package authoring proposal and metadata rules
- `docs/history/PACKAGE_DEPENDENCY_SPEC.md`: historical dependency and lockfile design reference
- `docs/ROADMAP.md`: roadmap and release status

## Keep This File Small

If a section needs long examples, detailed architecture diagrams, or historical implementation notes, move that content into `docs/` and leave only a short pointer here.
