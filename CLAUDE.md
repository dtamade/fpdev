# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FPDev** is a FreePascal development environment manager (similar to Rust's `rustup`) written in Object Pascal/Free Pascal. It manages FPC (Free Pascal Compiler) and Lazarus IDE installations, versions, cross-compilation targets, and packages across Windows, Linux, and macOS.

**Language**: Object Pascal (FPC 3.2.2+)
**IDE**: Lazarus (optional, for .lpi projects)
**Key Dependencies**: libgit2 (for Git operations)

## Building and Testing

### Build Commands

```powershell
# Build main program (standard approach)
lazbuild -B fpdev.lpi

# Build with specific mode
lazbuild -B --build-mode=Release fpdev.lpi

# Build test
lazbuild -B tests\test_git2_adapter.lpi

# Direct FPC compilation (alternative)
fpc -Fusrc -Fisrc -FEbin -FUlib src\fpdev.lpr
```

**Important**: Use `lazbuild` as the standard build method. The `-B` flag (or `--build-all`) ensures a clean rebuild.

### Running Tests

```powershell
# Build and run a single test
lazbuild -B tests\test_config_management.lpi
.\bin\test_config_management.exe

# Run BuildManager test suite
tests\fpdev.build.manager\run_tests.bat

# Toolchain environment check
scripts\check_toolchain.bat
```

Tests follow TDD (Test-Driven Development) methodology. All new features must have tests written first (red-green-refactor cycle).

## Architecture

### Command Pattern Architecture

FPDev uses a **command registry pattern** with hierarchical command dispatch:

```
fpdev (root)
├── help
├── version
├── fpc
│   ├── install
│   ├── list
│   ├── use
│   ├── current
│   ├── show
│   └── doctor
├── lazarus
│   ├── install
│   ├── list
│   ├── use
│   ├── current
│   └── run
├── repo (source repository management)
├── cross (cross-compilation targets)
├── package
└── project
```

**Command Registration**: Commands register via `GlobalCommandRegistry.RegisterPath()` in their unit's `initialization` section. The main program imports all command units to trigger registration.

**Key Files**:
- `src/fpdev.command.intf.pas` - Command interfaces (`ICommand`, `IContext`)
- `src/fpdev.command.registry.pas` - Command registry and dispatcher
- `src/fpdev.cmd.*.pas` - Root command implementations
- `src/fpdev.cmd.*.<action>.pas` - Sub-command implementations

### Three-Layer Git Integration

Git operations use a **three-layer adapter pattern** to isolate libgit2 dependency:

```
Application Layer (TFPCSourceManager, etc.)
         ↓
Adapter Layer (fpdev.git2.pas - TGitManager/TGitRepository)
         ↓  OR  ↓
Modern Interface (git2.api.pas + git2.impl.pas - IGitManager)
         ↓
C API Binding (libgit2.pas - raw FFI calls)
         ↓
Native Library (git2.dll / libgit2.so / libgit2.dylib)
```

**Recommended for new code**: Use `git2.api.pas` + `git2.impl.pas` (interface-based, easier to test).

**Legacy code**: Can continue using `fpdev.git2.pas` (concrete classes like `TGitManager`).

**Windows Runtime**: Requires `git2.dll` in PATH or executable directory.

### Configuration Management (Refactored to Interfaces)

Configuration system uses **interface-driven design** with reference counting:

- `fpdev.config.interfaces.pas` - Interface definitions
- `fpdev.config.managers.pas` - Implementation classes
- `fpdev.config.pas` - Deprecated backward-compatible wrapper (avoid in new code)

**Interfaces**:
- `IConfigManager` - Main config coordinator
- `IToolchainManager` - FPC toolchain versions
- `ILazarusManager` - Lazarus IDE versions
- `ICrossTargetManager` - Cross-compilation targets
- `IRepositoryManager` - Source repository URLs
- `ISettingsManager` - Global settings

**New code pattern**:
```pascal
uses fpdev.config.interfaces, fpdev.config.managers;

var
  Config: IConfigManager;
  ToolchainMgr: IToolchainManager;
begin
  Config := TConfigManager.Create('config.json');
  Config.LoadConfig;
  ToolchainMgr := Config.GetToolchainManager;
  // Use ToolchainMgr...
  // No manual Free needed - automatic reference counting
end;
```

**Config file location**:
- Windows: `%APPDATA%\.fpdev\config.json`
- Linux/macOS: `~/.fpdev/config.json`

See `docs/config-architecture.md` for detailed architecture documentation.

### Build Manager

`fpdev.build.manager.pas` - Manages FPC source compilation with **sandbox isolation**:

**Safety defaults**:
- All builds write to `sandbox/<version>/` directory (never system directories)
- No network operations
- No system config modifications
- Graceful degradation when `make` is unavailable

**Core workflow**:
1. `Preflight()` - Check environment (make, source paths, sandbox writable)
2. `BuildCompiler()` - Compile compiler (`make compiler`)
3. `BuildRTL()` - Compile runtime library (`make rtl`)
4. `Install()` - Install to sandbox (`make install DESTDIR=sandbox`)
5. `TestResults()` - Verify build artifacts

**Logging**: Each build creates `logs/build_yyyymmdd_hhnnss_zzz.log` with timestamps, commands, and artifact samples.

## Development Principles

### Test-Driven Development (TDD)

**Mandatory workflow**: Red-Green-Refactor

1. **🔴 Red**: Write failing test first
2. **🟢 Green**: Implement minimal code to pass
3. **🔵 Refactor**: Improve code while keeping tests green

Tests are in `tests/` directory with `.lpr` extension (Lazarus Program files).

### File Naming Conventions

- **Units**: `fpdev.<module>.pas` (e.g., `fpdev.config.pas`)
- **Commands**: `fpdev.cmd.<command>.pas` (root) or `fpdev.cmd.<command>.<action>.pas` (sub-command)
- **Tests**: `test_<module>.lpr` (e.g., `test_config_management.lpr`)
- **Interfaces**: Use `.intf.pas` suffix (e.g., `fpdev.command.intf.pas`)

### Code Style

- **Mode**: `{$mode objfpc}{$H+}` (Object Pascal with long strings)
- **Encoding**: UTF-8 with BOM for source files containing non-ASCII (use `{$codepage utf8}`)
- **Paths**: Use `PathDelim` constant, never hardcode `\` or `/`
- **Interface references**: Prefer interface-based design for new code (automatic memory management)

## Critical Gotchas

### ⚠️ NEVER Output Chinese or Unicode to Terminal (Windows)

**CRITICAL**: Windows console encoding issues cause Pascal's `WriteLn` to throw "Disk Full" I/O errors when outputting Chinese characters.

```pascal
// ❌ WRONG - Will crash on Windows
WriteLn('错误: 未知命令');

// ✅ CORRECT - Always use English
WriteLn('Error: Unknown command');
```

**Allowed**: UTF-8 in log files and JSON config files is fine. Only terminal output (`WriteLn`, `Write`) must be English.

### Path Separators

Always use `PathDelim` constant for cross-platform compatibility:

```pascal
// ✅ Correct
Result := Base + PathDelim + 'bin' + PathDelim + 'fpdev';

// ❌ Wrong
Result := Base + '\bin\fpdev';  // Windows-only!
```

### libgit2 Initialization

Always pair `Initialize()` with cleanup:

```pascal
Mgr := TGitManager.Create;
try
  if not Mgr.Initialize then Exit;
  // ... use Mgr ...
finally
  Mgr.Free;  // Calls git_libgit2_shutdown internally
end;
```

### Command Registration

Commands must be imported in main program (`src/fpdev.lpr`) to trigger `initialization` section:

```pascal
uses
  fpdev.cmd.fpc,           // Root command
  fpdev.cmd.fpc.install,   // Sub-command
  fpdev.cmd.fpc.list;      // Another sub-command
```

Without imports, commands won't register and will show "unknown command" errors.

### BuildManager AllowInstall

Installation is disabled by default for safety:

```pascal
LBM := TBuildManager.Create('sources/fpc/fpc-main', 2, False);
LBM.SetSandboxRoot('sandbox');
LBM.SetAllowInstall(True);  // Must explicitly enable
LBM.Install('main');
```

### Windows Make Detection

`TBuildManager.Preflight()` checks for `make` availability. If not found, it prints a message and returns `True` (graceful degradation). Test environment may not have `make` - this is intentional behavior.

## Project Structure

```
fpdev/
├── src/                    # Source code
│   ├── fpdev.lpr          # Main program entry
│   ├── fpdev.*.pas        # Core modules
│   ├── fpdev.cmd.*.pas    # Command implementations
│   ├── git2.*.pas         # Git integration (modern)
│   └── libgit2.pas        # Git C API binding
├── tests/                  # Test programs (.lpr files)
│   ├── test_*.lpr         # Unit/integration tests
│   └── fpdev.build.manager/  # BuildManager test suite
├── docs/                   # Documentation
│   ├── config-architecture.md  # Config system design
│   └── WARP.md            # Comprehensive project documentation
├── sources/                # FPC/Lazarus source code
│   └── fpc/
│       ├── fpc-main/
│       └── fpc-3.2.2/
├── sandbox/                # Build artifacts (never commit)
├── logs/                   # Build logs (never commit)
├── 3rd/libgit2/           # Third-party libgit2 binding
├── bin/                    # Compiled executables (never commit)
├── lib/                    # Compiled units (.ppu, .o) (never commit)
└── scripts/                # Build/test automation scripts
```

## Common Tasks

### Adding a New Command

1. Create unit: `src/fpdev.cmd.mycommand.myaction.pas`
2. Define class implementing `ICommand` interface
3. Register in `initialization` section:
   ```pascal
   initialization
     GlobalCommandRegistry.RegisterPath(['mycommand', 'myaction'], @CreateMyActionCommand, []);
   ```
4. Import in `src/fpdev.lpr` to trigger registration
5. Write tests in `tests/test_mycommand.lpr` (TDD: test first!)

### Reading Config in Commands

```pascal
uses fpdev.config.interfaces, fpdev.config.managers;

procedure TMyCommand.Execute(const AParams: array of string; const Ctx: IContext);
var
  Config: IConfigManager;
  ToolchainMgr: IToolchainManager;
begin
  Config := TConfigManager.Create(GetConfigPath);
  Config.LoadConfig;
  ToolchainMgr := Config.GetToolchainManager;
  // Use ToolchainMgr...
end;
```

### Using Git Operations

**Modern approach (recommended)**:
```pascal
uses git2.api, git2.impl;

var
  Mgr: IGitManager;
  Repo: IGitRepository;
begin
  Mgr := NewGitManager();
  Mgr.Initialize;
  Repo := Mgr.OpenRepository('.');
  WriteLn('Current branch: ', Repo.GetCurrentBranch);
end;
```

**Legacy approach (existing code)**:
```pascal
uses fpdev.git2;

var
  Repo: TGitRepository;
begin
  Repo := GitManager.OpenRepository('.');
  try
    WriteLn('Current branch: ', Repo.GetCurrentBranch);
  finally
    Repo.Free;
  end;
end;
```

### Build Management

```pascal
uses fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox');
    BM.SetAllowInstall(True);

    if not BM.Preflight then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;
    if not BM.TestResults('main') then Exit;

    WriteLn('Build successful! Log: ', BM.LogFileName);
  finally
    BM.Free;
  end;
end;
```

## Important Documentation

- **README.md** - Quick start and usage guide
- **WARP.md** - Comprehensive technical documentation (architecture, TDD, build system)
- **docs/config-architecture.md** - Configuration system design (interfaces, managers, lifecycle)
- **CHANGELOG.md** - Release history

## External References

- Free Pascal Docs: https://www.freepascal.org/docs.html
- Lazarus Wiki: https://wiki.freepascal.org/
- libgit2 API: https://libgit2.org/docs/

---

**Last Updated**: 2025-01-28
**Branch**: refactor/architecture-improvement
**Status**: Active development (config refactoring to interface-based design)
