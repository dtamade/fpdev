# FPDev Architecture Design Document

## Overview

FPDev is a modular FreePascal and Lazarus development environment management tool, built with a layered architecture design to ensure code maintainability, extensibility, and testability.

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Command Line Interface Layer              │
├─────────────────────────────────────────────────────────────┤
│                   Command Processing Layer                  │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐ │
│  │   fpc   │ lazarus │  cross  │ package │ project │ system  │ │
│  └─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘ │
├─────────────────────────────────────────────────────────────┤
│                   Core Services Layer                       │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│  │   Config    │   Version   │    Build    │     Git     │   │
│  │  Management │  Management │   System    │  Operations │   │
│  └─────────────┴─────────────┴─────────────┴─────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   Infrastructure Layer                      │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│  │ File System │   Process   │   Network   │   System    │   │
│  │             │  Management │  Operations │    Info     │   │
│  └─────────────┴─────────────┴─────────────┴─────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Core Module Design

### 1. Configuration Management Module (fpdev.config)

**Responsibility**: Manage application configuration including toolchains, Lazarus versions, cross-compilation targets, etc.

**Design Principles**:
- Use JSON format for storage, easy for manual editing and version control
- Provide type-safe configuration access interfaces
- Support configuration validation and migration
- Use lazy loading strategy to improve startup performance

**Core Class**:
```pascal
TFPDevConfigManager = class
  // Configuration file operations
  function LoadConfig: Boolean;
  function SaveConfig: Boolean;

  // Toolchain management
  function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
  function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;

  // Settings management
  function GetSettings: TFPDevSettings;
  function SetSettings(const ASettings: TFPDevSettings): Boolean;
end;
```

### 2. Command Processing Framework (fpdev.cmd)

**Responsibility**: Provide unified command registration, command-tree dispatch, and CLI context injection.

**Design Pattern**: Command pattern + registry dispatch

**Core interfaces and types**:
```pascal
IContext = interface
  function Config: IConfigManager;
  function Out: IOutput;
  function Err: IOutput;
  function Logger: ILogger;
  procedure SaveIfModified;
end;

ICommand = interface
  function Name: string;
  function Aliases: TStringArray;
  function FindSub(const AName: string): ICommand;
  function Execute(const AParams: array of string; const Ctx: IContext): Integer;
end;

TCommandRegistry = class
  procedure RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
  function DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
  function ListChildren(const APath: array of string): TStringArray;
end;
```

**Key implementation files**:
- `src/fpdev.command.intf.pas`: `ICommand` / `IContext`
- `src/fpdev.command.tree.pas`: `TCommandNode`
- `src/fpdev.command.registration.pas`: path registration and alias attachment
- `src/fpdev.command.registry.pas`: registry facade and dispatch
- `src/fpdev.command.imports.pas`: imports all command units to trigger `initialization` registration
- `src/fpdev.cli.bootstrap.pas`: default help / context / registry bootstrap
- `src/fpdev.cli.runner.pas`: entry-layer orchestration

**Command Hierarchy**:
```
fpdev
├── fpc
│   ├── install / list / use / current / show
│   ├── test / verify / update / uninstall
│   ├── policy
│   │   └── check
│   └── cache
│       ├── list / stats / clean / path
├── lazarus
│   ├── install / list / use / current / show
│   ├── run / test / doctor / update / uninstall
│   └── configure
├── cross
│   ├── list / show / install / uninstall
│   ├── enable / disable / configure / doctor
│   └── test / update / clean / build
├── package
│   ├── install / uninstall / update / list / search / info
│   ├── publish / clean / install-local / deps / why
│   └── repo
│       ├── add / list / remove / update
├── system
│   ├── help / version / doctor
│   ├── toolchain
│   │   ├── check / self-test
│   ├── repo
│   ├── config
│   ├── env
│   │   ├── data-root / vars / path / export / hook / resolve
│   ├── index
│   ├── cache
│   └── perf
└── project
    ├── new / list / info / build / run / test / clean
    └── template
        ├── list / install / remove / update

The entry layer keeps only `--portable` as a prelude; root help, version, toolchain checks, and policy checks are exposed through the command tree.
```

### 3. Utility Library (fpdev.utils)

**Responsibility**: Provide cross-platform system operation interfaces including file operations, process management, system information retrieval, etc.

**Design Principles**:
- Unified cross-platform interfaces
- Platform-specific implementation separation
- Error handling and exception safety

**Functional Modules**:
- System Info: CPU, memory, hostname, etc.
- Process Management: Process creation, monitoring, termination
- File Operations: Path handling, file permissions, directory operations
- Time Functions: High-precision time, system uptime

### 4. Terminal Output Management (fpdev.terminal)

**Responsibility**: Manage terminal output formatting, supporting colored output, progress bars, tables, etc.

**Features**:
- Cross-platform colored output support
- Progress bars and status indicators
- Table-formatted output
- Log level management

## Data Flow Design

### Configuration Data Flow

```
User Input → Command Parsing → Config Manager → JSON File
                ↓
            Config Validation → Memory Cache → Business Logic
```

### Build Data Flow

```
Build Request → Version Check → Source Fetch → Dependency Resolution → Compile → Output Result
```

## Error Handling Strategy

### 1. Layered Error Handling

- **User Layer**: Friendly error messages and suggestions
- **Business Layer**: Business logic errors and recovery strategies
- **System Layer**: System call errors and resource management

### 2. Error Types

```pascal
type
  TFPDevErrorType = (
    etConfigError,     // Configuration error
    etNetworkError,    // Network error
    etFileSystemError, // File system error
    etCompileError,    // Compilation error
    etRuntimeError     // Runtime error
  );
```

### 3. Error Recovery Mechanisms

- Automatic retry mechanism
- Rollback operation support
- User confirmation mechanism
- Log recording and diagnostics

## Extensibility Design

### 1. Plugin Architecture

Reserved plugin interfaces for third-party extensions:

```pascal
IFPDevPlugin = interface
  function GetName: string;
  function GetVersion: string;
  procedure Initialize(const AContext: IFPDevContext);
  procedure Execute(const AParams: TStringArray);
end;
```

### 2. Configuration Extension

Support for custom configuration fields and validation rules:

```json
{
  "extensions": {
    "custom_plugin": {
      "enabled": true,
      "config": {
        "custom_field": "value"
      }
    }
  }
}
```

## Performance Optimization

### 1. Caching Strategy

- Configuration file caching
- Version information caching
- Network request caching

### 2. Concurrent Processing

- Asynchronous file operations
- Parallel compilation support
- Background task management

### 3. Resource Management

- Memory pool management
- File handle reuse
- Network connection pool

## Security Considerations

### 1. Input Validation

- Command-line argument validation
- Configuration file format validation
- URL and path security checks

### 2. Permission Management

- Principle of least privilege
- File permission checks
- Execution permission verification

### 3. Data Protection

- Sensitive information encryption
- Temporary file cleanup
- Secure default configuration

## Testing Strategy

### 1. Unit Testing

- Independent testing for each module
- Mocking dependencies and external services
- Boundary conditions and exception testing

### 2. Integration Testing

- Inter-module interaction testing
- End-to-end functional testing
- Performance and stress testing

### 3. Test Coverage

- Code coverage > 80%
- Branch coverage > 70%
- 100% coverage for critical paths

## Deployment and Maintenance

### 1. Build System

- Automated build process
- Multi-platform cross-compilation
- Version management and releases

### 2. Monitoring and Diagnostics

- Performance monitoring
- Error reporting
- Usage statistics

### 3. Update Mechanism

- Automatic update checking
- Incremental update support
- Rollback mechanism

## Future Roadmap

### Short-term Goals (3 months)

- Complete core feature development
- Implement basic FPC/Lazarus management
- Add cross-compilation support

### Mid-term Goals (6 months)

- Improve package management system
- Add GUI interface
- Support more platforms

### Long-term Goals (1 year)

- Plugin ecosystem
- Cloud sync functionality
- Enterprise-level feature support
