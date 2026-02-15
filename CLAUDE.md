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
+-- help (h, ?)
+-- version (-v, --version)
+-- doctor
+-- show
+-- default
+-- env
+-- perf
|   +-- report
|   +-- summary
|   +-- clear
|   +-- save
+-- cache
+-- index
+-- shell-hook
+-- resolve-version
+-- config
|   +-- list (ls)
+-- fpc
|   +-- install
|   +-- uninstall
|   +-- list
|   +-- use (default)
|   +-- current
|   +-- show
|   +-- update
|   +-- test
|   +-- doctor
|   +-- help
|   +-- verify
|   +-- auto-install
|   +-- update-manifest
|   +-- cache
|       +-- list
|       +-- stats
|       +-- clean
|       +-- path
+-- lazarus
|   +-- install
|   +-- uninstall
|   +-- list
|   +-- use (default)
|   +-- current
|   +-- show
|   +-- update
|   +-- test
|   +-- doctor
|   +-- help
|   +-- run
|   +-- configure (config)
+-- repo
|   +-- add
|   +-- remove (rm)
|   +-- list (ls)
|   +-- show
|   +-- default
|   +-- versions
|   +-- help
+-- cross (x)
|   +-- build
|   +-- install
|   +-- uninstall
|   +-- list
|   +-- enable
|   +-- disable
|   +-- show
|   +-- configure
|   +-- doctor
|   +-- test
|   +-- help
|   +-- clean
|   +-- update
+-- package (pkg)
|   +-- install
|   +-- install-local
|   +-- uninstall
|   +-- list (ls)
|   +-- search
|   +-- publish
|   +-- info
|   +-- update
|   +-- clean
|   +-- deps (dependencies)
|   +-- why
|   +-- help
|   +-- repo
|       +-- add
|       +-- remove (rm, del)
|       +-- list (ls)
|       +-- update
+-- project (proj)
    +-- new
    +-- build
    +-- run
    +-- test
    +-- clean
    +-- list
    +-- info
    +-- help
    +-- template (tpl)
        +-- list (ls)
        +-- install
        +-- remove (rm)
        +-- update
```

**Command Registration**: Commands register via `GlobalCommandRegistry.RegisterPath()` in their unit's `initialization` section. The main program imports all command units to trigger registration.

**Key Files**:
- `src/fpdev.command.intf.pas` - Command interfaces (`ICommand`, `IContext`)
- `src/fpdev.command.registry.pas` - Command registry and dispatcher
- `src/fpdev.cmd.*.pas` - Root command implementations
- `src/fpdev.cmd.*.<action>.pas` - Sub-command implementations

### Git Integration (Unified Interface Architecture)

**Phase 2 Architecture Refactoring Complete** (2026-01-31): Git operations now use unified `IGitManager` interface with dependency injection pattern.

Git operations use a **three-layer adapter pattern** with interface-driven design:

```
Application Layer (TFPCSourceManager, TGitOperations, etc.)
         ↓
Unified Interface (git2.api.pas - IGitManager, IGitRepository)
         ↓
Implementation Layer (git2.impl.pas - TGitManagerImpl)
         ↓
C API Binding (libgit2.pas - raw FFI calls)
         ↓
Native Library (git2.dll / libgit2.so / libgit2.dylib)
```

**New Code Pattern (Interface-Based)**:
```pascal
uses git2.api, git2.impl;

var
  Mgr: IGitManager;
  Repo: IGitRepository;
begin
  Mgr := NewGitManager();
  Mgr.Initialize;
  Repo := Mgr.OpenRepository('.');
  WriteLn('Current branch: ', Repo.CurrentBranch);
  // No manual Free needed - automatic reference counting
end;
```

**Legacy Code Pattern (Still Supported)**:
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

**Internal Implementation**:
- `fpdev.utils.git.pas` - Uses `IGitManager` internally via `SharedGitManager` (marked `@deprecated`)
- `fpdev.git2.pas` - Legacy `GitManager()` function marked `@deprecated`
- All new code should use `git2.api.pas` + `git2.impl.pas` directly

**Phase 2 Wave 2 Complete** (2026-01-31): `SharedGitManager` global singleton marked `@deprecated` with migration guide. Will be removed in Wave 4.

**Windows Runtime**: Requires `git2.dll` in PATH or executable directory.

### Configuration Management (Interface-Driven Architecture)

**Phase 2 Architecture Refactoring Complete** (2026-01-31): Configuration system now uses interface-driven design with dependency injection.

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

### Build Manager (Interface-Based Architecture)

**Phase 2 Architecture Refactoring Complete** (2026-01-31): Build system now uses interface-driven design with dependency injection.

**Phase 2 Summary**:
- ✅ Wave 1: TBuildManager 接口化 (IBuildLogger, IToolchainChecker, IBuildManager)
- ✅ Wave 2: SharedGitManager 标记为 @deprecated
- ✅ Wave 3: 全局单例迁移（通过接口化完成）
- ✅ Wave 4: 保留 @deprecated 代码（向后兼容策略）

**Architecture Benefits**:
- Automatic reference counting (no manual Free needed)
- Mock-based testing enabled
- Dependency injection pattern
- Zero regression (all existing tests passing)

**Core Interfaces** (`fpdev.build.interfaces.pas`):
- `IBuildLogger` - Logging interface
- `IToolchainChecker` - Toolchain validation interface
- `IBuildManager` - Build management interface

**Implementation Classes**:
- `TBuildLogger` - Implements `IBuildLogger`
- `TBuildToolchainChecker` - Implements `IToolchainChecker`
- `TBuildManager` - Implements `IBuildManager`

**New Code Pattern (Interface-Based)**:
```pascal
uses fpdev.build.interfaces, fpdev.build.logger, fpdev.build.toolchain, fpdev.build.manager;

var
  Logger: IBuildLogger;
  Checker: IToolchainChecker;
  Manager: IBuildManager;
begin
  // Create instances (automatic reference counting)
  Logger := TBuildLogger.Create('logs');
  Checker := TBuildToolchainChecker.Create(False);
  Manager := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  
  // Use interfaces
  Logger.Log('Starting build...');
  if Checker.IsMakeAvailable then
    Logger.Log('Make is available');
  
  if Manager.Preflight then
    Manager.BuildCompiler('main');
  
  // No manual Free needed - automatic cleanup
end;
```

**Legacy Code Pattern (Still Supported)**:
```pascal
uses fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox');
    BM.SetAllowInstall(True);
    
    if not BM.Preflight('main') then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;
    
    WriteLn('Build successful!');
  finally
    BM.Free;
  end;
end;
```

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

**Testing**: Interface isolation enables mock-based testing:
```pascal
// Mock logger for testing
type
  TMockLogger = class(TInterfacedObject, IBuildLogger)
  private
    FMessages: TStringList;
  public
    procedure Log(const AMessage: string);
    function GetMessageCount: Integer;
  end;

// Use mock in tests
var
  MockLogger: TMockLogger;
  Logger: IBuildLogger;
begin
  MockLogger := TMockLogger.Create;
  Logger := MockLogger;
  Logger.Log('Test message');
  Assert(MockLogger.GetMessageCount = 1);
end;
```

**Test Coverage**:
- `tests/test_build_manager.lpr` - Legacy tests (backward compatibility)
- `tests/test_build_interfaces.lpr` - Interface isolation tests
- All tests passing (100% backward compatibility)

### Build Cache System

`fpdev.build.cache.pas` - Manages build artifact caching for fast version switching:

**Cache Structure**:
- Cache directory: `~/.fpdev/cache/` (or `%APPDATA%\.fpdev\cache\` on Windows)
- Archive format: `fpc-{version}-{cpu}-{os}.tar.gz` (platform-aware)
- Metadata files: `fpc-{version}-{cpu}-{os}.meta` (key-value format)

**Core Features**:
- **Binary artifact caching**: Cache downloaded FPC binaries for offline installation
- **Source build caching**: Cache compiled FPC installations for fast switching
- **Offline mode**: Install from cache without network access (`--offline` flag)
- **Cache bypass**: Force fresh download/build (`--no-cache` flag)
- **Automatic cache management**: Save after successful installation, restore before download

**Cache Commands**:
```bash
fpdev fpc cache list          # List all cached versions
fpdev fpc cache stats          # Show cache statistics
fpdev fpc cache clean <ver>    # Clean specific version
fpdev fpc cache clean --all    # Clean all cached versions
fpdev fpc cache path           # Show cache directory path
```

**Installation with Cache**:
```bash
# Normal installation (uses cache if available)
fpdev fpc install 3.2.2

# Offline mode (cache-only, no network)
fpdev fpc install 3.2.2 --offline

# Force fresh download (ignore cache)
fpdev fpc install 3.2.2 --no-cache
```

**Cache Workflow**:
1. Check cache before installation (`HasArtifacts`)
2. If cache hit: restore from cache (`RestoreBinaryArtifact`)
3. If cache miss: download/build normally
4. After successful installation: save to cache (`SaveArtifacts`)

**Key Methods**:
- `SaveBinaryArtifact(version, file)` - Cache downloaded binary
- `RestoreBinaryArtifact(version, dest)` - Restore from cache
- `GetBinaryArtifactInfo(version)` - Get cache metadata
- `HasArtifacts(version)` - Check if version is cached
- `DeleteArtifacts(version)` - Remove from cache

**Implementation Files**:
- `src/fpdev.build.cache.pas` - Core cache management
- `src/fpdev.cmd.fpc.install.pas` - Installation with cache integration
- `src/fpdev.cmd.fpc.cache.*.pas` - Cache management commands
- `tests/test_build_cache_binary.lpr` - Cache system tests

### Cross-Compilation Build Engine (M7)

**M7 Complete** (2026-02-09): Full cross-compilation build engine with 8-step orchestration, intelligent toolchain search, and JSON-driven target definitions.

**Architecture Overview**:
```
TCrossTargetRegistry (21 builtin targets, JSON-driven)
         |
    TCrossTarget record (unified, 9 fields)
         |
   +-----+-----+-----+
   |             |             |
TCrossOptBuilder  TCrossCompilerResolver  TCrossToolchainSearch
(CROSSOPT string)  (ppcross* path)         (6-layer strategy)
         |             |             |
         +------+------+------+
                |
       TCrossBuildEngine (7-step orchestration)
                |
          TBuildManager.RunMake
                |
          TFPCCfgManager (fpc.cfg CRUD)
```

**Core Components**:

1. **TCrossTarget** (`src/fpdev.config.interfaces.pas`) - Unified target record
   - 9 fields: Enabled, BinutilsPath, LibrariesPath, CPU, OS, SubArch, ABI, BinutilsPrefix, CrossOpt
   - Backward compatible: old config.json with 3 fields still readable

2. **TCrossBuildEngine** (`src/fpdev.cross.engine.pas`) - 7-step build orchestration
   - CompilerCycle -> CompilerInstall -> RTL -> RTLInstall -> Packages -> PackagesInstall -> Complete
   - Dry-run mode with full command logging
   - Delegates to TBuildManager.RunMake with PP= and CROSSOPT= parameters

3. **TCrossOptBuilder** (`src/fpdev.cross.opts.pas`) - CROSSOPT string construction
   - ABI options: `-CaEABIHF`, `-CaEABI`
   - FPU options: `-CfVFPV3`, `-CfSOFT`
   - SubArch options: `-CpARMV7A`
   - Library path options: `-Fl<path>`

4. **TCrossCompilerResolver** (`src/fpdev.cross.compiler.pas`) - Cross-compiler path resolution
   - CPU to ppcross name mapping (x86_64->ppcrossx64, arm->ppcrossarm, etc.)
   - Compiler existence validation

5. **TFPCCfgManager** (`src/fpdev.cross.fpccfg.pas`) - fpc.cfg section management
   - Insert/Update/Remove cross-compilation sections
   - Uses `# BEGIN fpdev-cross:<cpu>-<os>` / `# END` markers
   - Wraps in `#IFDEF CPU / #IFDEF OS` conditionals

6. **TCrossToolchainSearch** (`src/fpdev.cross.search.pas`) - 6-layer toolchain search
   - Layer 1: fpdev-managed paths
   - Layer 2: System standard paths
   - Layer 3: PATH environment
   - Layer 4: Platform-specific (multiarch/multilib)
   - Layer 5: Linker resolution
   - Layer 6: Config hints

7. **TCrossTargetRegistry** (`src/fpdev.cross.targets.pas`) - JSON-driven target definitions
   - 21 builtin targets (Windows, Linux, macOS, Android, iOS, FreeBSD, MIPS, PowerPC, RISC-V, SPARC)
   - Custom target registration
   - JSON export/import for user extensibility

**CLI Commands** (4 M7 sub-commands):
```bash
fpdev cross build <target> [--dry-run]     # Build cross-compiler for target
fpdev cross doctor <target>                # Diagnose target toolchain
fpdev cross configure <target> [--auto]    # Configure target with search engine
fpdev cross test <target>                  # Test cross-compilation
```

**Usage Example**:
```pascal
uses fpdev.cross.targets, fpdev.cross.opts, fpdev.cross.compiler,
     fpdev.cross.engine, fpdev.config.interfaces, fpdev.build.manager;

var
  Reg: TCrossTargetRegistry;
  Def: TCrossTargetDef;
  Target: TCrossTarget;
  Opts: string;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
begin
  // 1. Get target definition from registry
  Reg := TCrossTargetRegistry.Create;
  try
    Reg.LoadBuiltinTargets;
    Reg.GetTarget('arm-linux', Def);
  finally
    Reg.Free;
  end;

  // 2. Build CROSSOPT and resolve compiler
  Target := Default(TCrossTarget);
  Target.CPU := Def.CPU;
  Target.OS := Def.OS;
  Target.SubArch := Def.SubArch;
  Target.ABI := Def.ABI;
  Opts := TCrossOptBuilder.Build(Target);
  WriteLn('CROSSOPT: ', Opts);
  WriteLn('Compiler: ', TCrossCompilerResolver.GetPPCrossName(Target.CPU));

  // 3. Dry-run build
  BM := TBuildManager.Create('/path/to/fpc/source', 4, False);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(True);
    Engine.BuildCrossCompiler(Target, '/path/to/source', '/path/to/sandbox', 'main');
    WriteLn('Commands logged: ', Engine.GetCommandLogCount);
  finally
    Engine.Free;
  end;
end;
```

**Test Coverage** (M7 total):
- `tests/test_cross_engine_types.lpr` - 10 tests (type compatibility)
- `tests/test_cross_opts.lpr` - 15 tests (CROSSOPT builder)
- `tests/test_cross_compiler_resolve.lpr` - 8 tests (compiler resolver)
- `tests/test_cross_engine.lpr` - 29 tests (engine orchestration)
- `tests/test_cross_engine_e2e.lpr` - 28 tests (end-to-end dry-run)
- `tests/test_cross_fpccfg.lpr` - 55 tests (fpc.cfg manager)
- `tests/test_cross_search.lpr` - 44 tests (search engine)
- `tests/test_cross_search_libs.lpr` - 19 tests (library search)
- `tests/test_cross_targets.lpr` - 80 tests (target registry)
- `tests/test_cross_config_extended.lpr` - 50 tests (config serialization)
- `tests/test_cross_cli_integration.lpr` - 27 tests (CLI integration)
- `tests/test_cross_commands.lpr` - 10 tests (command registration)
- `tests/test_cross_integration.lpr` - 94 tests (full pipeline integration)
- `tests/test_cross_regression.lpr` - 22 tests (sub-command regression)
- Total: 491 M7-specific tests across 14 test files

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

### Logging System

**Phase 2 Complete** (2026-01-21): Structured logging system with rotation, archiving, and dual output.

**Core Components**:

1. **TStructuredLogger** (`src/fpdev.logger.structured.pas`) - Main logging interface
   - Structured JSON logging with context (source, correlation ID, thread/process ID)
   - Dual output: file (JSON) + console (formatted text)
   - Independent enable/disable for file and console output
   - Log level filtering (Debug, Info, Warn, Error)
   - Custom context fields support

2. **TLogRotator** (`src/fpdev.logger.rotator.pas`) - Log rotation management
   - Size-based rotation (configurable max file size)
   - Time-based rotation (configurable interval in hours)
   - Dual trigger strategy (whichever condition is met first)
   - Automatic old log cleanup (configurable retention)
   - Rotated file naming: `app.log.1`, `app.log.2`, etc.

3. **TLogArchiver** (`src/fpdev.logger.archiver.pas`) - Log archiving with compression
   - Automatic gzip compression of rotated logs
   - Configurable compression level (0-9)
   - Archive directory management
   - Old archive cleanup (configurable max age)
   - Archive naming: `app.log.1.gz`, `app.log.2.gz`, etc.

**Usage Example**:

```pascal
uses fpdev.logger.intf, fpdev.logger.structured,
     fpdev.logger.rotator, fpdev.logger.archiver;

var
  Config: TLoggerConfig;
  Logger: IStructuredLogger;
  Rotator: ILogRotator;
  Archiver: ILogArchiver;
  Context: TLogContext;
begin
  // Configure logger
  FillChar(Config, SizeOf(Config), 0);
  Config.FileOutputEnabled := True;
  Config.ConsoleOutputEnabled := True;
  Config.LogDir := 'logs';
  Config.LogFileName := 'app.log';
  Config.MinLevel := llInfo;

  // Configure rotation
  Config.RotationConfig.MaxFileSize := 10 * 1024 * 1024;  // 10MB
  Config.RotationConfig.RotationInterval := 24;  // 24 hours
  Config.RotationConfig.MaxFiles := 5;
  Config.RotationConfig.MaxAge := 7;  // 7 days
  Config.RotationConfig.CompressOld := True;

  // Create logger
  Logger := TStructuredLogger.Create(Config);
  Rotator := TLogRotator.Create(Config.RotationConfig);

  // Create log context
  FillChar(Context, SizeOf(Context), 0);
  Context.Source := 'myapp.module';
  Context.CorrelationId := 'request-123';
  Context.ThreadId := GetCurrentThreadId;
  Context.ProcessId := GetProcessID;

  // Log messages
  Logger.Info('Application started', Context);
  Logger.Debug('Debug information', Context);
  Logger.Warn('Warning message', Context);
  Logger.Error('Error occurred', Context, 'Stack trace here');

  // Check if rotation needed
  if Rotator.ShouldRotate('logs/app.log') then
    Rotator.Rotate('logs/app.log');

  // Archive rotated logs
  Archiver := TLogArchiver.Create(CreateDefaultArchiveConfig);
  Archiver.ArchiveAll('logs');
  Archiver.CleanupOldArchives;
end;
```

**Configuration Options**:

```pascal
// Logger configuration
TLoggerConfig = record
  FileOutputEnabled: Boolean;      // Enable file output
  ConsoleOutputEnabled: Boolean;   // Enable console output
  LogDir: string;                  // Log directory
  LogFileName: string;             // Log file name
  MinLevel: TLogLevel;             // Minimum log level
  RotationConfig: TRotationConfig; // Rotation settings
  UseColorOutput: Boolean;         // Console color output
  IncludeThreadId: Boolean;        // Include thread ID
  IncludeProcessId: Boolean;       // Include process ID
end;

// Rotation configuration
TRotationConfig = record
  MaxFileSize: Int64;        // Max file size in bytes
  RotationInterval: Integer; // Rotation interval in hours
  MaxFiles: Integer;         // Number of files to keep
  MaxAge: Integer;           // Max age in days
  CompressOld: Boolean;      // Compress old logs
end;

// Archive configuration
TArchiveConfig = record
  Enabled: Boolean;          // Enable archiving
  CompressionLevel: Integer; // 0-9 (0=none, 9=max)
  ArchiveDir: string;        // Archive directory
  MaxArchiveAge: Integer;    // Days to keep archives
end;
```

**Test Coverage** (Phase 2):
- `tests/test_structured_logger.lpr` - 50 tests for structured logging
- `tests/test_log_rotation.lpr` - 23 tests for log rotation
- `tests/test_log_archiver.lpr` - 20 tests for log archiving
- `tests/test_logger_integration.lpr` - 21 tests for full pipeline integration
- **Total**: 114/114 tests passing (100% pass rate)

**Key Features**:
- Cross-platform support (Windows, Linux, macOS)
- Thread-safe logging operations
- Automatic rotation and archiving
- Configurable retention policies
- Zero compiler warnings
- Production-ready

### Lazarus IDE Configuration

**Phase 3.4 Complete**: Lazarus IDE configuration is fully implemented with comprehensive test coverage.

```pascal
uses fpdev.config.interfaces, fpdev.config.managers, fpdev.cmd.lazarus;

var
  Config: IConfigManager;
  LazarusMgr: TLazarusManager;
begin
  Config := TConfigManager.Create('');
  Config.LoadConfig;

  LazarusMgr := TLazarusManager.Create(Config);
  try
    // Configure IDE for version 3.0
    if LazarusMgr.ConfigureIDE('3.0') then
      WriteLn('IDE configured successfully')
    else
      WriteLn('IDE configuration failed');
  finally
    LazarusMgr.Free;
  end;
end;
```

**ConfigureIDE functionality** (`src/fpdev.cmd.lazarus.pas:890`):
- Automatically detects installed Lazarus version
- Finds corresponding FPC compiler path
- Updates `environmentoptions.xml` configuration file
- Sets compiler path, library path, and FPC source path
- Creates timestamped backups before modification
- Cross-platform support (Windows/Linux/macOS)

**TLazarusIDEConfig class** (`src/fpdev.lazarus.config.pas`):
- XML configuration file parsing and modification
- Backup and restore mechanisms
- Path normalization and validation
- Configuration summary generation

**Test coverage** (Phase 3.4):
- `tests/test_lazarus_ide_config.lpr` - 11 test scenarios for TLazarusIDEConfig class
- `tests/test_lazarus_configure_workflow.lpr` - 4 test scenarios for ConfigureIDE workflow
- All 15 tests passing (100% pass rate)

### Package Authoring System

**Week 9 Complete**: Package authoring system is fully implemented with comprehensive test coverage, enabling developers to create, test, and validate packages for distribution.

**Core Components**:

1. **TPackageArchiver** (`src/fpdev.package.archiver.pas`) - Package creation and archiving
   - Automatic source file detection (`.pas`, `.pp`, `.inc`, `.lpr`)
   - `.fpdevignore` support for file exclusion
   - tar.gz archive creation with proper structure
   - SHA256 checksum generation for integrity verification
   - Version-based archive naming

2. **TPackageTestCommand** (`src/fpdev.cmd.package.test.pas`) - Package testing in isolated environments
   - Extract package archives to temporary directories
   - Load and validate package metadata
   - Install package dependencies (stub for Week 8 integration)
   - Run test scripts from package.json
   - Automatic cleanup of temporary directories
   - Cross-platform shell support (Windows: cmd.exe, Unix: /bin/sh)

3. **TPackageValidator** (`src/fpdev.cmd.package.validate.pas`) - Comprehensive package validation
   - Validate package metadata (required fields, version format)
   - Validate files existence
   - Validate dependencies format
   - Validate LICENSE file
   - Validate README.md file (warning if missing)
   - Detect sensitive files (.env, credentials, etc.)
   - Three-level validation messages (Error, Warning, Info)

**Usage Examples**:

```pascal
// Create package archive
uses fpdev.package.archiver;

var
  Archiver: TPackageArchiver;
begin
  Archiver := TPackageArchiver.Create('/path/to/package');
  try
    if Archiver.CreateArchive('mylib', '1.0.0') then
      WriteLn('Archive created: ', Archiver.ArchivePath)
    else
      WriteLn('Error: ', Archiver.GetLastError);
  finally
    Archiver.Free;
  end;
end;

// Test package
uses fpdev.cmd.package.test;

var
  TestCmd: TPackageTestCommand;
  TempDir: string;
begin
  TestCmd := TPackageTestCommand.Create;
  try
    TempDir := TestCmd.ExtractToTempDir('mylib-1.0.0.tar.gz');
    if TempDir <> '' then
    begin
      TestCmd.InstallDependencies(TempDir);
      if TestCmd.RunTests(TempDir) then
        WriteLn('Tests passed')
      else
        WriteLn('Tests failed: ', TestCmd.GetLastError);
    end;
  finally
    TestCmd.Free;
  end;
end;

// Validate package
uses fpdev.cmd.package.validate;

var
  Validator: TPackageValidator;
begin
  Validator := TPackageValidator.Create('/path/to/package');
  try
    if Validator.Validate then
      WriteLn('Package is valid')
    else
      WriteLn('Validation errors: ', Validator.GetErrors);
  finally
    Validator.Free;
  end;
end;
```

**Test Coverage** (Week 9):
- `tests/test_package_archiver.lpr` - 15 test scenarios for TPackageArchiver
- `tests/test_package_test.lpr` - 16 test scenarios for TPackageTestCommand
- `tests/test_package_validate.lpr` - 22 test scenarios for TPackageValidator
- Total: 53/53 tests passing (100% pass rate)

**Key Features**:
- TDD methodology (Red-Green-Refactor cycle)
- Cross-platform support (Windows, Linux, macOS)
- Comprehensive error handling with GetLastError methods
- Security features (sensitive file detection)
- Performance optimization (cached path delimiters, efficient file scanning)

See `docs/WEEK9-SUMMARY.md` for detailed implementation documentation.

### Package Publishing System

**Week 10 Complete**: Package publishing system is fully implemented with comprehensive test coverage, enabling developers to publish, search, and discover packages through a local registry.

**Core Components**:

1. **TPackageRegistry** (`src/fpdev.package.registry.pas`) - Core registry management
   - Local file-based registry with JSON index (`~/.fpdev/registry/`)
   - Package metadata management (add, remove, query)
   - Version tracking and listing
   - Package search functionality
   - Registry initialization and validation

2. **TPackagePublishCommand** (`src/fpdev.cmd.package.publish.pas`) - Package publishing
   - Archive validation (format, existence)
   - Package name validation (lowercase, alphanumeric, hyphens, underscores)
   - Semantic version validation (major.minor.patch)
   - Metadata extraction and validation
   - File copying to registry (archive, checksum, metadata)
   - Registry index updates
   - Dry-run mode (validation only)
   - Force mode (overwrite existing versions)

3. **TPackageSearchCommand** (`src/fpdev.cmd.package.search.pas`) - Package discovery
   - Search by package name or description
   - Case-insensitive partial matching
   - List all packages in registry
   - Detailed package information with all versions
   - Formatted output with description, author, versions

**Usage Examples**:

```pascal
// Publish package
uses fpdev.cmd.package.publish;

var
  Publisher: TPackagePublishCommand;
begin
  Publisher := TPackagePublishCommand.Create('~/.fpdev/registry');
  try
    if Publisher.Publish('mylib-1.0.0.tar.gz') then
      WriteLn('Package published successfully')
    else
      WriteLn('Error: ', Publisher.GetLastError);
  finally
    Publisher.Free;
  end;
end;

// Search packages
uses fpdev.cmd.package.search;

var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  Search := TPackageSearchCommand.Create('~/.fpdev/registry');
  try
    Results := Search.Search('json');
    try
      // Process results
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

// Get package info
var
  Info: string;
begin
  Search := TPackageSearchCommand.Create('~/.fpdev/registry');
  try
    Info := Search.GetInfo('mylib');
    WriteLn(Info);
  finally
    Search.Free;
  end;
end;
```

**Command Line Interface**:

```bash
# Publish package
fpdev package publish mylib-1.0.0.tar.gz
fpdev package publish mylib-1.0.0.tar.gz --dry-run
fpdev package publish mylib-1.0.0.tar.gz --force

# Search packages
fpdev package search json
fpdev package search "parsing library"

# List all packages
fpdev package search

# Get package info
fpdev package info mylib
```

**Test Coverage** (Week 10):
- `tests/test_package_registry.lpr` - 35 test scenarios for TPackageRegistry
- `tests/test_package_publish.lpr` - 26 test scenarios for TPackagePublishCommand
- `tests/test_package_search.lpr` - 24 test scenarios for TPackageSearchCommand
- `tests/test_integration_e2e.lpr` - 24 integration test scenarios
- Total: 109/109 tests passing (100% pass rate)

**Key Features**:
- TDD methodology (Red-Green-Refactor cycle)
- Cross-platform support (Windows, Linux, macOS)
- Comprehensive error handling with GetLastError methods
- Case-insensitive search with partial matching
- Version management and duplicate prevention
- Dry-run and force modes for publishing
- End-to-end integration testing

**Complete Workflow** (Week 8 + 9 + 10):
1. **Create**: `fpdev package create` (Week 9)
2. **Test**: `fpdev package test` (Week 9)
3. **Validate**: `fpdev package validate` (Week 9)
4. **Publish**: `fpdev package publish` (Week 10)
5. **Search**: `fpdev package search` (Week 10)
6. **Install**: `fpdev package install` (Week 8)

See `docs/WEEK10-SUMMARY.md` for detailed implementation documentation.

### Package Lock File System

**Feature Complete** (2026-01-31): Package version locking system ensures reproducible builds across environments.

**Core Components**:

1. **TPackageLockFile** (`src/fpdev.package.lockfile.pas`) - Lock file management
   - JSON-based lock file format (`fpdev-lock.json`)
   - Package version locking with integrity checksums
   - Dependency tree snapshot
   - Automatic generation during package resolution
   - Load/save operations with validation

2. **TPackageResolver Integration** - Automatic lock file generation
   - Generates lock file after successful dependency resolution
   - Records exact versions of all resolved packages
   - Includes resolved paths and SHA256 checksums
   - Supports `SetUseLockFile()` to enable/disable

**Lock File Format** (`fpdev-lock.json`):
```json
{
  "name": "myproject",
  "version": "1.0.0",
  "lockfileVersion": 1,
  "packages": {
    "": {
      "name": "myproject",
      "version": "1.0.0"
    },
    "libfoo": {
      "version": "1.2.3",
      "resolved": "~/.fpdev/registry/packages/libfoo/1.2.3/libfoo-1.2.3.tar.gz",
      "integrity": "sha256-...",
      "dependencies": {
        "libbar": ">=2.0.0"
      }
    }
  }
}
```

**Usage Example**:
```pascal
uses fpdev.package.resolver, fpdev.package.lockfile;

var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
begin
  Resolver := TPackageResolver.Create('/packages', '/project');
  try
    Resolver.SetUseLockFile(True);  // Enable lock file generation
    
    Result := Resolver.Resolve('mypackage');
    if Result.Success then
    begin
      WriteLn('Dependencies resolved');
      WriteLn('Lock file generated: fpdev-lock.json');
    end;
  finally
    Resolver.Free;
  end;
end;
```

**Key Features**:
- Reproducible builds (exact version locking)
- Integrity verification (SHA256 checksums)
- Dependency tree snapshot
- Automatic generation during resolution
- Cross-platform support (Windows, Linux, macOS)

**Test Coverage**:
- `tests/test_package_lockfile.lpr` - 23 test scenarios for TPackageLockFile
- All tests passing (100% pass rate)

See `docs/PACKAGE-LOCK-DESIGN.md` for detailed design documentation.

### Logging System (Phase 2)

**Phase 2 Complete**: Production-ready structured logging system with rotation, archiving, and comprehensive test coverage.

**Core Components**:

1. **TStructuredLogger** (`src/fpdev.logger.structured.pas`) - Core logging with dual output
   - Structured JSON logging for file output
   - Formatted text logging for console output
   - Log level filtering (Debug, Info, Warning, Error)
   - Context management (source, correlation ID, thread/process ID)
   - Custom fields support
   - Independent file/console enable/disable

2. **TLogRotator** (`src/fpdev.logger.rotator.pas`) - Automatic log rotation
   - Size-based rotation (configurable max file size)
   - Time-based rotation (configurable interval)
   - Dual trigger strategy (size OR time)
   - Automatic file renaming (app.log → app.log.1 → app.log.2)
   - Configurable retention (max files, max age)
   - Old log cleanup

3. **TLogArchiver** (`src/fpdev.logger.archiver.pas`) - Log compression and archiving
   - Automatic gzip compression
   - Configurable compression level (0-9)
   - Archive directory management
   - Old archive cleanup (configurable max age)
   - SHA256 checksum generation

**Usage Example**:

```pascal
uses fpdev.logger.structured, fpdev.logger.rotator, fpdev.logger.archiver;

var
  Logger: TStructuredLogger;
  Rotator: TLogRotator;
  Archiver: TLogArchiver;
begin
  // Create logger with dual output
  Logger := TStructuredLogger.Create('app.log');
  try
    Logger.SetMinLevel(llInfo);
    Logger.SetFileOutputEnabled(True);
    Logger.SetConsoleOutputEnabled(True);

    // Add context
    Logger.SetSource('MyApp');
    Logger.SetCorrelationID('req-12345');

    // Log messages
    Logger.Info('Application started');
    Logger.Warning('Configuration file not found, using defaults');
    Logger.Error('Failed to connect to database');

    // Log with custom fields
    Logger.LogWithFields(llInfo, 'User login', ['username', 'john', 'ip', '192.168.1.1']);
  finally
    Logger.Free;
  end;

  // Configure log rotation
  Rotator := TLogRotator.Create('app.log');
  try
    Rotator.SetMaxFileSize(10 * 1024 * 1024);  // 10 MB
    Rotator.SetRotationInterval(24 * 60 * 60);  // 24 hours
    Rotator.SetMaxFiles(7);  // Keep 7 rotated files
    Rotator.SetMaxAge(30 * 24 * 60 * 60);  // 30 days

    if Rotator.ShouldRotate then
      Rotator.Rotate;
  finally
    Rotator.Free;
  end;

  // Configure log archiving
  Archiver := TLogArchiver.Create('logs', 'archives');
  try
    Archiver.SetCompressionLevel(6);  // Balanced compression
    Archiver.SetMaxArchiveAge(90 * 24 * 60 * 60);  // 90 days

    Archiver.ArchiveLog('app.log.1');
    Archiver.CleanupOldArchives;
  finally
    Archiver.Free;
  end;
end;
```

**Configuration Options**:

```pascal
// Logger configuration
Logger.SetMinLevel(llDebug);           // Set minimum log level
Logger.SetFileOutputEnabled(True);     // Enable file output
Logger.SetConsoleOutputEnabled(True);  // Enable console output
Logger.SetSource('MyApp');             // Set source identifier
Logger.SetCorrelationID('req-123');    // Set correlation ID

// Rotator configuration
Rotator.SetMaxFileSize(10485760);      // 10 MB max file size
Rotator.SetRotationInterval(86400);    // 24 hours rotation interval
Rotator.SetMaxFiles(7);                // Keep 7 rotated files
Rotator.SetMaxAge(2592000);            // 30 days max age

// Archiver configuration
Archiver.SetCompressionLevel(6);       // Compression level (0-9)
Archiver.SetMaxArchiveAge(7776000);    // 90 days max archive age
```

**Test Coverage** (Phase 2):
- `tests/test_structured_logger.lpr` - 50 test scenarios for TStructuredLogger
- `tests/test_log_rotation.lpr` - 23 test scenarios for TLogRotator
- `tests/test_log_archiver.lpr` - 20 test scenarios for TLogArchiver
- `tests/test_logger_integration.lpr` - 21 integration test scenarios
- Total: 114/114 tests passing (100% pass rate)

**Key Features**:
- TDD methodology (Red-Green-Refactor cycle)
- Cross-platform support (Windows, Linux, macOS)
- Thread-safe operations
- Comprehensive error handling
- Zero compiler warnings
- Production-ready with extensive test coverage

See `SLEEP_MODE_SUMMARY.md` for detailed Phase 2 implementation documentation.

## Important Documentation

- **README.md** - Quick start and usage guide
- **WARP.md** - Comprehensive technical documentation (architecture, TDD, build system)
- **docs/config-architecture.md** - Configuration system design (interfaces, managers, lifecycle)
- **CHANGELOG.md** - Release history

## External References

- Free Pascal Docs: https://www.freepascal.org/docs.html
- Lazarus Wiki: https://wiki.freepascal.org/
- libgit2 API: https://libgit2.org/docs/

### Enhanced Error Handling System

**Phase 1 Complete** (2026-01-20): Enhanced error messages and progress feedback system.

**Core Components**:

1. **TEnhancedError** (`src/fpdev.errors.pas`) - Rich error handling infrastructure
   - 14 error codes covering common failure scenarios
   - Context information (key-value pairs)
   - Recovery suggestions with commands and descriptions
   - Formatted display with color-coded output
   - Error registry for centralized error management

2. **Error Recovery System** (`src/fpdev.errors.recovery.pas`) - Pre-configured error creation
   - 11 specialized error creation functions
   - Smart recovery suggestions for common scenarios
   - Network errors (timeout, connection failed)
   - File system errors (not found, permission denied)
   - Build errors (compilation failed, installation failed)
   - Configuration errors (invalid config, checksum mismatch)

3. **Progress Feedback System** (`src/fpdev.ui.progress.enhanced.pas`) - Multi-stage progress tracking
   - **TMultiStageProgress**: Multi-stage operations with ETA calculation
   - **TDownloadProgress**: Download tracking with speed and ETA
   - **TBuildProgress**: Build tracking with unit counting
   - Stage status tracking (waiting, running, completed, failed, skipped)
   - Progress bars and percentage display
   - Time estimation and duration formatting

**Usage Examples**:

```pascal
// Enhanced error handling
uses fpdev.errors.recovery;

var
  Err: TEnhancedError;
begin
  Err := CreateNetworkTimeoutError('https://example.com/file.tar.gz', 30);
  try
    Err.Display;  // Shows formatted error with recovery suggestions
  finally
    Err.Free;
  end;
end;

// Multi-stage progress
uses fpdev.ui.progress.enhanced;

var
  Progress: TMultiStageProgress;
begin
  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.AddStage('Extract');
    Progress.AddStage('Install');

    Progress.StartStage(0, 'Downloading FPC 3.2.2...');
    Progress.UpdateStage(0, 50, 'Half done');
    Progress.CompleteStage(0, 'Download complete');

    Progress.Display;  // Shows all stages with progress bars
  finally
    Progress.Free;
  end;
end;

// Download progress with speed
var
  Download: TDownloadProgress;
begin
  Download := TDownloadProgress.Create(1024 * 1024);  // 1 MB
  try
    Download.Update(512 * 1024);  // 512 KB downloaded
    Download.Display;  // Shows speed, ETA, progress bar
  finally
    Download.Free;
  end;
end;
```

**Test Coverage** (Phase 1):
- `tests/test_errors.lpr` - 45 test scenarios for TEnhancedError and TErrorRegistry
- `tests/test_errors_recovery.lpr` - 33 test scenarios for error recovery functions
- `tests/test_progress_enhanced.lpr` - 50 test scenarios for progress tracking
- Total: 128/128 tests passing (100% pass rate)
- Overall test suite: 79/83 passing (95.2% pass rate, +3 tests from baseline)

**Key Features**:
- TDD methodology (Red-Green-Refactor cycle)
- Cross-platform support (Windows, Linux, macOS)
- Comprehensive error context and recovery suggestions
- Real-time progress tracking with ETA calculation
- Formatted output with progress bars and status symbols
- No regressions (maintained 4 known failures from baseline)

---

**Last Updated**: 2026-02-15
**Branch**: main
**Status**: Phase 7 in progress (194/202 tests compile successfully, 2 hints)
