unit fpdev.config.interfaces;

{
Configuration management interface definitions

Split the original TFPDevConfigManager into multiple single-responsibility manager interfaces:
- IToolchainManager: Toolchain management
- ILazarusManager: Lazarus version management
- ICrossTargetManager: Cross-compilation target management
- IRepositoryManager: Repository management
- ISettingsManager: Settings management
- IConfigManager: Main entry point, coordinates all sub-managers
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

type
  { IConfigChangeNotifier - Configuration change notification interface }
  { Sub-managers notify parent manager of configuration changes through this interface }
  IConfigChangeNotifier = interface
    ['{91A2B3C4-D5E6-789F-0ABC-DEF123456789}']
    procedure NotifyConfigChanged;
  end;

  // Toolchain type
  TToolchainType = (ttRelease, ttDevelopment, ttCustom);

  // Toolchain information
  TToolchainInfo = record
    ToolchainType: TToolchainType;
    Version: string;
    InstallPath: string;
    SourceURL: string;
    Branch: string;
    Installed: Boolean;
    InstallDate: TDateTime;
  end;

  // Lazarus information
  TLazarusInfo = record
    Version: string;
    FPCVersion: string;
    InstallPath: string;
    SourceURL: string;
    Branch: string;
    Installed: Boolean;
  end;

  // Cross-compilation target
  TCrossTarget = record
    Enabled: Boolean;
    BinutilsPath: string;
    LibrariesPath: string;
    // Extended fields for cross-compilation build engine (optional, backward-compatible)
    CPU: string;               // arm, aarch64, i386, x86_64
    OS: string;                // linux, win32, win64, darwin, android
    SubArch: string;           // armv6, armv7, armv8
    ABI: string;               // eabi, eabihf, musl
    BinutilsPrefix: string;    // arm-linux-gnueabihf-
    CrossOpt: string;          // -CfVFPV3 -CaEABIHF
  end;

  // FPDev settings
  TFPDevSettings = record
    AutoUpdate: Boolean;
    ParallelJobs: Integer;
    KeepSources: Boolean;
    InstallRoot: string;
    DefaultRepo: string;
    // Mirror configuration for fpdev-repo
    Mirror: string;           // 'auto', 'github', 'gitee', or custom URL
    CustomRepoURL: string;    // Custom repository URL (highest priority)
  end;

  { IToolchainManager - Toolchain management interface }
  IToolchainManager = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function RemoveToolchain(const AName: string): Boolean;
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
    function SetDefaultToolchain(const AName: string): Boolean;
    function GetDefaultToolchain: string;
    function ListToolchains: TStringArray;

    // Serialization methods
    procedure LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
    procedure SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
    procedure Clear;
  end;

  { ILazarusManager - Lazarus version management interface }
  ILazarusManager = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
    function RemoveLazarusVersion(const AName: string): Boolean;
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
    function SetDefaultLazarusVersion(const AName: string): Boolean;
    function GetDefaultLazarusVersion: string;
    function ListLazarusVersions: TStringArray;

    // Serialization methods
    procedure LoadFromJSON(ALazarus: TJSONObject);
    procedure SaveToJSON(out ALazarus: TJSONObject);
    procedure Clear;
  end;

  { ICrossTargetManager - Cross-compilation target management interface }
  ICrossTargetManager = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RemoveCrossTarget(const ATarget: string): Boolean;
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function ListCrossTargets: TStringArray;

    // Serialization methods
    procedure LoadFromJSON(ACrossTargets: TJSONObject);
    procedure SaveToJSON(out ACrossTargets: TJSONObject);
    procedure Clear;
  end;

  { IRepositoryManager - Repository management interface }
  IRepositoryManager = interface
    ['{D4E5F6A7-B8C9-0123-DEF1-234567890123}']
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function GetRepository(const AName: string): string;
    function HasRepository(const AName: string): Boolean;
    function GetDefaultRepository: string;
    function ListRepositories: TStringArray;

    // Serialization methods
    procedure LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
    procedure SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
    procedure Clear;
  end;

  { ISettingsManager - Settings management interface }
  ISettingsManager = interface
    ['{E5F6A7B8-C9D0-1234-EF12-345678901234}']
    function GetSettings: TFPDevSettings;
    function SetSettings(const ASettings: TFPDevSettings): Boolean;

    // Serialization methods
    procedure LoadFromJSON(ASettings: TJSONObject);
    procedure SaveToJSON(out ASettings: TJSONObject);
  end;

  { IConfigManager - Main entry point for configuration management }
  IConfigManager = interface
    ['{F6A7B8C9-D0E1-2345-F123-456789012345}']
    // Basic configuration operations
    function LoadConfig: Boolean;
    function SaveConfig: Boolean;
    function GetConfigPath: string;
    function CreateDefaultConfig: Boolean;

    // Access sub-managers
    function GetToolchainManager: IToolchainManager;
    function GetLazarusManager: ILazarusManager;
    function GetCrossTargetManager: ICrossTargetManager;
    function GetRepositoryManager: IRepositoryManager;
    function GetSettingsManager: ISettingsManager;

    // Configuration state
    function IsModified: Boolean;
  end;

implementation

end.
