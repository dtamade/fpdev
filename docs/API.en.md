# FPDev API Documentation

## Configuration Management API (fpdev.config)

### TFPDevConfigManager Class

The core class for configuration management, handling all configuration-related operations.

#### Constructor

```pascal
constructor Create(const AConfigPath: string = '');
```

- `AConfigPath`: Configuration file path. If empty, uses the default path.

#### Configuration File Operations

```pascal
function LoadConfig: Boolean;
function SaveConfig: Boolean;
function CreateDefaultConfig: Boolean;
function GetDefaultConfigPath: string;
```

- `LoadConfig`: Load configuration from file
- `SaveConfig`: Save configuration to file
- `CreateDefaultConfig`: Create default configuration file
- `GetDefaultConfigPath`: Get the default configuration file path

#### Toolchain Management

```pascal
function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
function RemoveToolchain(const AName: string): Boolean;
function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
function SetDefaultToolchain(const AName: string): Boolean;
function GetDefaultToolchain: string;
function ListToolchains: TStringArray;
```

- `AddToolchain`: Add a new toolchain
- `RemoveToolchain`: Remove the specified toolchain
- `GetToolchain`: Get toolchain information
- `SetDefaultToolchain`: Set the default toolchain
- `GetDefaultToolchain`: Get the default toolchain name
- `ListToolchains`: List all toolchains

#### Lazarus Management

```pascal
function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
function RemoveLazarusVersion(const AName: string): Boolean;
function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
function SetDefaultLazarusVersion(const AName: string): Boolean;
function GetDefaultLazarusVersion: string;
function ListLazarusVersions: TStringArray;
```

#### Cross-Compilation Target Management

```pascal
function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
function RemoveCrossTarget(const ATarget: string): Boolean;
function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
function ListCrossTargets: TStringArray;
```

#### Repository Management

```pascal
function AddRepository(const AName, AURL: string): Boolean;
function RemoveRepository(const AName: string): Boolean;
function GetRepository(const AName: string): string;
function ListRepositories: TStringArray;
```

#### Settings Management

```pascal
function GetSettings: TFPDevSettings;
function SetSettings(const ASettings: TFPDevSettings): Boolean;
```

### Data Structures

#### TToolchainType

```pascal
TToolchainType = (ttRelease, ttDevelopment, ttCustom);
```

Toolchain type enumeration:
- `ttRelease`: Release version
- `ttDevelopment`: Development version
- `ttCustom`: Custom version

#### TToolchainInfo

```pascal
TToolchainInfo = record
  ToolchainType: TToolchainType;
  Version: string;
  InstallPath: string;
  SourceURL: string;
  Branch: string;
  Installed: Boolean;
  InstallDate: TDateTime;
end;
```

Toolchain information record:
- `ToolchainType`: Toolchain type
- `Version`: Version number
- `InstallPath`: Installation path
- `SourceURL`: Source repository URL
- `Branch`: Git branch
- `Installed`: Whether installed
- `InstallDate`: Installation date

#### TLazarusInfo

```pascal
TLazarusInfo = record
  Version: string;
  FPCVersion: string;
  InstallPath: string;
  SourceURL: string;
  Branch: string;
  Installed: Boolean;
end;
```

Lazarus information record:
- `Version`: Lazarus version
- `FPCVersion`: Corresponding FPC version
- `InstallPath`: Installation path
- `SourceURL`: Source repository URL
- `Branch`: Git branch
- `Installed`: Whether installed

#### TCrossTarget

```pascal
TCrossTarget = record
  Enabled: Boolean;
  BinutilsPath: string;
  LibrariesPath: string;
end;
```

Cross-compilation target record:
- `Enabled`: Whether enabled
- `BinutilsPath`: Binary tools path
- `LibrariesPath`: Libraries path

#### TFPDevSettings

```pascal
TFPDevSettings = record
  AutoUpdate: Boolean;
  ParallelJobs: Integer;
  KeepSources: Boolean;
  InstallRoot: string;
end;
```

FPDev settings record:
- `AutoUpdate`: Whether to auto-update
- `ParallelJobs`: Number of parallel compilation jobs
- `KeepSources`: Whether to keep source code
- `InstallRoot`: Installation root directory

## Command Processing API (fpdev.cmd)

### `ICommand` interface

The current command system is built around the `ICommand` interface and a command registry, rather than the old inheritance-based command model.

```pascal
ICommand = interface
  function Name: string;
  function Aliases: TStringArray;
  function FindSub(const AName: string): ICommand;
  function Execute(const AParams: array of string; const Ctx: IContext): Integer;
end;
```

- `Name`: Returns the command name
- `Aliases`: Returns command aliases
- `FindSub`: Looks up a subcommand
- `Execute`: Runs the command with an `IContext`

### `TCommandRegistry`

```pascal
TCommandRegistry = class
  procedure RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
  function DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
  function ListChildren(const APath: array of string): TStringArray;
end;
```

- `RegisterPath`: Registers a command path
- `DispatchPath`: Dispatches a command by path
- `ListChildren`: Lists available subcommands under a node

## Utility Functions API (fpdev.utils)

### System Information Functions

```pascal
function exepath: string;
function cwd: string;
function get_hostname: String;
function get_cpu_count: UInt32;
function get_pid: pid_t;
function get_ppid: pid_t;
```

### Memory Management Functions

```pascal
function get_free_memory: UInt64;
function get_total_memory: UInt64;
function resident_set_memory(aRss: PSizeUInt): Boolean;
```

### Time Functions

```pascal
function hrtime: uint64;
function uptime: Integer;
function get_timeofday(aTimeSpec: ptimeval64_t): Boolean;
```

## Usage Examples

### Configuration Management Example

```pascal
var
  ConfigManager: TFPDevConfigManager;
  ToolchainInfo: TToolchainInfo;
begin
  ConfigManager := TFPDevConfigManager.Create;
  try
    // Load configuration
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;

    // Add toolchain
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/usr/local/fpc/3.2.2';
    ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
    ToolchainInfo.Branch := 'fixes_3_2';
    ToolchainInfo.Installed := True;

    ConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo);
    ConfigManager.SetDefaultToolchain('fpc-3.2.2');

    // Save configuration
    ConfigManager.SaveConfig;
  finally
    ConfigManager.Free;
  end;
end;
```

### Command Processing Example

```pascal
var
  Registry: TCommandRegistry;
  Ctx: IContext;
begin
  Registry := GlobalCommandRegistry;
  Ctx := TDefaultCommandContext.Create;
  Registry.DispatchPath(['fpc', 'list'], Ctx);
end;
```
