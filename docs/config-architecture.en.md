# FPDev Configuration Management Architecture

## Overview

FPDev's configuration management system uses a **modular, interface-driven** architecture design with reference counting for lifecycle management, providing clear separation of responsibilities and easily testable components.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                       │
│  Use TFPDevConfigManager (backward compatible) or interfaces │
├─────────────────────────────────────────────────────────────┤
│                      Interface Layer                         │
│  fpdev.config.interfaces.pas                                 │
│  ┌──────────────┬──────────────┬──────────────┬──────────┐  │
│  │ IConfigMgr   │ IToolchainMgr│ ILazarusMgr  │ ICrossMgr│  │
│  │              │ IRepoMgr     │ ISettingsMgr │          │  │
│  └──────────────┴──────────────┴──────────────┴──────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   Implementation Layer                       │
│  fpdev.config.managers.pas                                   │
│  ┌──────────────┬──────────────┬──────────────┬──────────┐  │
│  │ TConfigMgr   │TToolchainMgr │ TLazarusMgr  │TCrossMgr │  │
│  │              │ TRepoMgr     │ TSettingsMgr │          │  │
│  └──────────────┴──────────────┴──────────────┴──────────┘  │
├─────────────────────────────────────────────────────────────┤
│                  Compatibility Layer                         │
│  fpdev.config.pas                                            │
│  TFPDevConfigManager (deprecated, wraps IConfigManager)      │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Configuration Manager (TConfigManager)

**Responsibility**: Main entry point for configuration management, coordinates all sub-managers

**Interface**: `IConfigManager`

**Key Methods**:
- `LoadConfig()` - Load configuration from JSON file
- `SaveConfig()` - Save configuration to JSON file
- `GetToolchainManager()` - Get toolchain manager
- `GetLazarusManager()` - Get Lazarus manager
- `GetCrossTargetManager()` - Get cross-compilation target manager
- `GetRepositoryManager()` - Get repository manager
- `GetSettingsManager()` - Get settings manager

### 2. Toolchain Manager (TToolchainManager)

**Responsibility**: Manage FPC toolchain versions

**Interface**: `IToolchainManager`

**Key Methods**:
- `AddToolchain(name, info)` - Add toolchain
- `RemoveToolchain(name)` - Remove toolchain
- `GetToolchain(name, out info)` - Get toolchain information
- `SetDefaultToolchain(name)` - Set default toolchain
- `GetDefaultToolchain()` - Get default toolchain
- `ListToolchains()` - List all toolchains

### 3. Lazarus Manager (TLazarusManager)

**Responsibility**: Manage Lazarus IDE versions

**Interface**: `ILazarusManager`

**Key Methods**:
- `AddLazarusVersion(name, info)` - Add Lazarus version
- `RemoveLazarusVersion(name)` - Remove version
- `GetLazarusVersion(name, out info)` - Get version information
- `SetDefaultLazarusVersion(name)` - Set default version
- `GetDefaultLazarusVersion()` - Get default version
- `ListLazarusVersions()` - List all versions

### 4. Cross Target Manager (TCrossTargetManager)

**Responsibility**: Manage cross-compilation target configurations

**Interface**: `ICrossTargetManager`

**Key Methods**:
- `AddCrossTarget(target, info)` - Add cross-compilation target
- `RemoveCrossTarget(target)` - Remove target
- `GetCrossTarget(target, out info)` - Get target information
- `ListCrossTargets()` - List all targets

### 5. Repository Manager (TRepositoryManager)

**Responsibility**: Manage source code repository URLs

**Interface**: `IRepositoryManager`

**Key Methods**:
- `AddRepository(name, url)` - Add repository
- `RemoveRepository(name)` - Remove repository
- `GetRepository(name)` - Get repository URL
- `HasRepository(name)` - Check if repository exists
- `GetDefaultRepository()` - Get default repository
- `ListRepositories()` - List all repositories

### 6. Settings Manager (TSettingsManager)

**Responsibility**: Manage global settings

**Interface**: `ISettingsManager`

**Key Methods**:
- `GetSettings()` - Get current settings
- `SetSettings(settings)` - Update settings

## Lifecycle Management

### Reference Counting

All managers implement `TInterfacedObject`, using Free Pascal's automatic reference counting mechanism:

```pascal
// Interface references automatically manage lifecycle
var
  ConfigMgr: IConfigManager;
begin
  ConfigMgr := TConfigManager.Create('config.json');
  // Use ConfigMgr...
  // No manual Free needed, automatically freed when interface reference goes out of scope
end;
```

### Change Notification

Sub-managers notify the parent manager of configuration changes through the `IConfigChangeNotifier` interface:

```pascal
type
  IConfigChangeNotifier = interface
    procedure NotifyConfigChanged;
  end;

// Sub-manager calls notification
if FNotifier <> nil then
  IConfigChangeNotifier(FNotifier).NotifyConfigChanged;
```

## Usage Examples

### Recommended: Direct Interface Usage

```pascal
uses
  fpdev.config.interfaces,
  fpdev.config.managers;

var
  ConfigMgr: IConfigManager;
  ToolchainMgr: IToolchainManager;
  ToolchainInfo: TToolchainInfo;
begin
  // Create configuration manager
  ConfigMgr := TConfigManager.Create('~/.fpdev/config.json');

  // Load configuration
  if not ConfigMgr.LoadConfig then
    ConfigMgr.CreateDefaultConfig;

  // Get toolchain manager
  ToolchainMgr := ConfigMgr.GetToolchainManager;

  // Add toolchain
  FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
  ToolchainInfo.Version := '3.2.2';
  ToolchainInfo.InstallPath := '/usr/local/fpc/3.2.2';
  ToolchainInfo.ToolchainType := ttRelease;
  ToolchainMgr.AddToolchain('fpc-3.2.2', ToolchainInfo);

  // Set default toolchain
  ToolchainMgr.SetDefaultToolchain('fpc-3.2.2');

  // Save configuration
  ConfigMgr.SaveConfig;

  // Automatic cleanup, no manual Free needed
end;
```

### Backward Compatible (Deprecated)

```pascal
uses
  fpdev.config;

var
  ConfigMgr: TFPDevConfigManager;
  ToolchainInfo: TToolchainInfo;
begin
  ConfigMgr := TFPDevConfigManager.Create('~/.fpdev/config.json');
  try
    if not ConfigMgr.LoadConfig then
      ConfigMgr.CreateDefaultConfig;

    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/usr/local/fpc/3.2.2';
    ConfigMgr.AddToolchain('fpc-3.2.2', ToolchainInfo);

    ConfigMgr.SaveConfig;
  finally
    ConfigMgr.Free;  // Manual Free required
  end;
end;
```

## Deprecation Notice

### ⚠️ TFPDevConfigManager is Deprecated

The `TFPDevConfigManager` class is retained for backward compatibility, but **not recommended for new code**.

**Deprecation Reasons**:
1. Requires manual memory management (calling `Free`)
2. Does not follow interface-driven design principles
3. High code coupling, difficult to test
4. Cannot fully utilize interface reference counting benefits

**Migration Guide**:

Old code:
```pascal
var
  Config: TFPDevConfigManager;
begin
  Config := TFPDevConfigManager.Create;
  try
    Config.AddToolchain('fpc-3.2.2', Info);
  finally
    Config.Free;
  end;
end;
```

New code:
```pascal
var
  Config: IConfigManager;
  ToolchainMgr: IToolchainManager;
begin
  Config := TConfigManager.Create;
  ToolchainMgr := Config.GetToolchainManager;
  ToolchainMgr.AddToolchain('fpc-3.2.2', Info);
  // No Free needed, automatic management
end;
```

## Configuration File Format

Configuration is stored in JSON format at `~/.fpdev/config.json` (Windows: `%APPDATA%\.fpdev\config.json`):

```json
{
  "version": "1.0",
  "toolchains": {
    "fpc-3.2.2": {
      "type": "release",
      "version": "3.2.2",
      "install_path": "/usr/local/fpc/3.2.2",
      "source_url": "https://gitlab.com/freepascal.org/fpc/source.git",
      "branch": "fixes_3_2",
      "installed": true,
      "install_date": "2025-01-15T10:30:00",
      "default": true
    }
  },
  "lazarus_installs": {
    "lazarus-3.0": {
      "version": "3.0",
      "fpc_version": "fpc-3.2.2",
      "install_path": "/usr/local/lazarus",
      "source_url": "https://gitlab.com/freepascal.org/lazarus.git",
      "branch": "lazarus_3_0",
      "installed": true,
      "default": true
    }
  },
  "cross_targets": {
    "win64": {
      "enabled": true,
      "binutils_path": "/usr/local/cross/win64/bin",
      "libraries_path": "/usr/local/cross/win64/lib"
    }
  },
  "repositories": {
    "fpc": "https://gitlab.com/freepascal.org/fpc/source.git",
    "lazarus": "https://gitlab.com/freepascal.org/lazarus.git"
  },
  "settings": {
    "default_repo": "fpc",
    "auto_update": false,
    "parallel_jobs": 4,
    "keep_sources": true,
    "install_root": "/opt/fpdev"
  }
}
```

## Testing

### Test Suite

The configuration management system includes a complete test suite:

1. **wrapper_test.lpr** - Test backward compatible wrapper
2. **submgr_test.lpr** - Test sub-manager interfaces
3. **test_config_management.lpr** - Full functionality test (29 test cases)

### Running Tests

```bash
# Compile tests
fpc -Fusrc -Fisrc -FEbin -FUlib tests/wrapper_test.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests/submgr_test.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_config_management.lpr

# Run tests
./bin/wrapper_test
./bin/submgr_test
./bin/test_config_management
```

### Test Coverage

- ✅ Configuration creation and loading
- ✅ Toolchain management (add, remove, query, default)
- ✅ Lazarus version management
- ✅ Cross-compilation target management
- ✅ Repository management
- ✅ Settings management
- ✅ Configuration persistence
- ✅ Backward compatibility
- ✅ Interface reference counting lifecycle

## Design Principles

### 1. Single Responsibility Principle (SRP)

Each manager is responsible for a single domain of configuration management with clear responsibilities.

### 2. Interface Segregation Principle (ISP)

Functionality is exposed through interfaces, hiding implementation details for easy testing and replacement.

### 3. Dependency Injection

Sub-managers receive notifiers through interfaces rather than depending on concrete types directly.

### 4. Open-Closed Principle (OCP)

Functionality can be extended by implementing new interfaces without modifying existing code.

### 5. Automated Lifecycle

Interface reference counting automatically manages memory, preventing memory leaks.

## Future Improvements

### Planned Features

1. **Configuration Templates** - Predefined configuration templates (development, production, CI/CD)
2. **Configuration Validation** - JSON Schema validation for configuration file validity
3. **Configuration Migration** - Automatic migration from old version configurations
4. **Configuration Import/Export** - Export configurations for use on other machines
5. **Environment Variable Support** - Configuration paths support environment variable expansion

### Performance Optimization

1. Lazy loading of sub-managers
2. Configuration caching strategies
3. Batch configuration updates

## References

- **Source Files**:
  - `src/fpdev.config.interfaces.pas` - Interface definitions
  - `src/fpdev.config.managers.pas` - Implementation code
  - `src/fpdev.config.pas` - Backward compatibility layer

- **Test Files**:
  - `tests/wrapper_test.lpr`
  - `tests/submgr_test.lpr`
  - `tests/test_config_management.lpr`

- **Related Documentation**:
  - `warp.md` - Project overview documentation
  - `README.md` - Quick start guide

---

**Last Updated**: 2026-02-10
**Maintainer**: FPDev Team
**Status**: ✅ Implemented and tested
