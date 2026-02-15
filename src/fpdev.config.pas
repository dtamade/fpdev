unit fpdev.config;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.config

JSON configuration management system - backward compatibility layer

This unit retains the legacy TFPDevConfigManager API for backward compatibility.
New code should use the new architecture in fpdev.config.interfaces and fpdev.config.managers.

## Notice

If you redistribute or use this in your own project, please keep this project's copyright notice. Thank you.

fafafaStudio
Email:dtamade@gmail.com
QQ Group:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.config.managers;

type
  // Re-export type definitions for backward compatibility
  TToolchainType = fpdev.config.interfaces.TToolchainType;
  TToolchainInfo = fpdev.config.interfaces.TToolchainInfo;
  TLazarusInfo = fpdev.config.interfaces.TLazarusInfo;
  TCrossTarget = fpdev.config.interfaces.TCrossTarget;
  TFPDevSettings = fpdev.config.interfaces.TFPDevSettings;

const
  // Backward compatibility constants
  ttRelease = fpdev.config.interfaces.ttRelease;
  ttDevelopment = fpdev.config.interfaces.ttDevelopment;
  ttCustom = fpdev.config.interfaces.ttCustom;

type
  { TFPDevConfigManager - Backward compatibility wrapper }
  { Deprecated: use TConfigManager and related interfaces }
  TFPDevConfigManager = class
  private
    FConfigManager: IConfigManager;  // Use interface reference, auto-managed lifecycle
    function GetModified: Boolean;
    function GetConfigPath: string;

  public
    constructor Create(const AConfigPath: string = '');
    destructor Destroy; override;

    function AsConfigManager: IConfigManager;

    function LoadConfig: Boolean;
    function SaveConfig: Boolean;
    function GetDefaultConfigPath: string;
    function CreateDefaultConfig: Boolean;

    // Toolchain management
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function RemoveToolchain(const AName: string): Boolean;
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
    function SetDefaultToolchain(const AName: string): Boolean;
    function GetDefaultToolchain: string;
    function ListToolchains: TStringArray;

    // Lazarus management
    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
    function RemoveLazarusVersion(const AName: string): Boolean;
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
    function SetDefaultLazarusVersion(const AName: string): Boolean;
    function GetDefaultLazarusVersion: string;
    function ListLazarusVersions: TStringArray;

    // Cross-compilation target management
    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RemoveCrossTarget(const ATarget: string): Boolean;
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function ListCrossTargets: TStringArray;

    // Repository management
    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function GetRepository(const AName: string): string;
    function HasRepository(const AName: string): Boolean;
    function GetDefaultRepository: string;
    function ListRepositories: TStringArray;

    // Settings management
    function GetSettings: TFPDevSettings;
    function SetSettings(const ASettings: TFPDevSettings): Boolean;

    // Properties
    property ConfigPath: string read GetConfigPath;
    property Modified: Boolean read GetModified;
  end;

implementation

{ TFPDevConfigManager }

constructor TFPDevConfigManager.Create(const AConfigPath: string);
begin
  inherited Create;
  FConfigManager := TConfigManager.Create(AConfigPath) as IConfigManager;
end;

destructor TFPDevConfigManager.Destroy;
begin
  // Explicitly clear interface reference, trigger reference count cleanup
  FConfigManager := nil;
  inherited Destroy;
end;

function TFPDevConfigManager.GetModified: Boolean;
begin
  Result := FConfigManager.IsModified;
end;

function TFPDevConfigManager.GetConfigPath: string;
begin
  Result := FConfigManager.GetConfigPath;
end;

function TFPDevConfigManager.GetDefaultConfigPath: string;
begin
  Result := FConfigManager.GetConfigPath;
end;

function TFPDevConfigManager.LoadConfig: Boolean;
begin
  Result := FConfigManager.LoadConfig;
end;

function TFPDevConfigManager.SaveConfig: Boolean;
begin
  Result := FConfigManager.SaveConfig;
end;

function TFPDevConfigManager.CreateDefaultConfig: Boolean;
begin
  Result := FConfigManager.CreateDefaultConfig;
end;

function TFPDevConfigManager.AsConfigManager: IConfigManager;
begin
  Result := FConfigManager;
end;

// Toolchain management methods
function TFPDevConfigManager.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.AddToolchain(AName, AInfo);
end;

function TFPDevConfigManager.RemoveToolchain(const AName: string): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.RemoveToolchain(AName);
end;

function TFPDevConfigManager.GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.GetToolchain(AName, AInfo);
end;

function TFPDevConfigManager.SetDefaultToolchain(const AName: string): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.SetDefaultToolchain(AName);
end;

function TFPDevConfigManager.GetDefaultToolchain: string;
begin
  Result := FConfigManager.GetToolchainManager.GetDefaultToolchain;
end;

function TFPDevConfigManager.ListToolchains: TStringArray;
begin
  Result := FConfigManager.GetToolchainManager.ListToolchains;
end;

// Lazarus management methods
function TFPDevConfigManager.AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.AddLazarusVersion(AName, AInfo);
end;

function TFPDevConfigManager.RemoveLazarusVersion(const AName: string): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.RemoveLazarusVersion(AName);
end;

function TFPDevConfigManager.GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.GetLazarusVersion(AName, AInfo);
end;

function TFPDevConfigManager.SetDefaultLazarusVersion(const AName: string): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.SetDefaultLazarusVersion(AName);
end;

function TFPDevConfigManager.GetDefaultLazarusVersion: string;
begin
  Result := FConfigManager.GetLazarusManager.GetDefaultLazarusVersion;
end;

function TFPDevConfigManager.ListLazarusVersions: TStringArray;
begin
  Result := FConfigManager.GetLazarusManager.ListLazarusVersions;
end;

// Cross-compilation target management methods
function TFPDevConfigManager.AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.AddCrossTarget(ATarget, AInfo);
end;

function TFPDevConfigManager.RemoveCrossTarget(const ATarget: string): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.RemoveCrossTarget(ATarget);
end;

function TFPDevConfigManager.GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
begin
  Result := FConfigManager.GetCrossTargetManager.GetCrossTarget(ATarget, AInfo);
end;

function TFPDevConfigManager.ListCrossTargets: TStringArray;
begin
  Result := FConfigManager.GetCrossTargetManager.ListCrossTargets;
end;

// Repository management methods
function TFPDevConfigManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := FConfigManager.GetRepositoryManager.AddRepository(AName, AURL);
end;

function TFPDevConfigManager.RemoveRepository(const AName: string): Boolean;
begin
  Result := FConfigManager.GetRepositoryManager.RemoveRepository(AName);
end;

function TFPDevConfigManager.GetRepository(const AName: string): string;
begin
  Result := FConfigManager.GetRepositoryManager.GetRepository(AName);
end;

function TFPDevConfigManager.HasRepository(const AName: string): Boolean;
begin
  Result := FConfigManager.GetRepositoryManager.HasRepository(AName);
end;

function TFPDevConfigManager.GetDefaultRepository: string;
begin
  // The default repository is stored in Settings
  Result := FConfigManager.GetSettingsManager.GetSettings.DefaultRepo;
end;

function TFPDevConfigManager.ListRepositories: TStringArray;
begin
  Result := FConfigManager.GetRepositoryManager.ListRepositories;
end;

// Settings management methods
function TFPDevConfigManager.GetSettings: TFPDevSettings;
begin
  Result := FConfigManager.GetSettingsManager.GetSettings;
end;

function TFPDevConfigManager.SetSettings(const ASettings: TFPDevSettings): Boolean;
begin
  Result := FConfigManager.GetSettingsManager.SetSettings(ASettings);
end;

end.
