unit fpdev.config.managers;

{
================================================================================
  fpdev.config.managers - Configuration Manager Implementations
================================================================================

  This unit provides the concrete implementations of the configuration
  management system for FPDev. It splits the original TFPDevConfigManager
  into multiple single-responsibility managers following the SOLID principles.

  Sub-managers:
    - TToolchainManager: FPC toolchain version management
    - TLazarusManager: Lazarus IDE version management
    - TCrossTargetManager: Cross-compilation target management
    - TRepositoryManager: Git repository URL management
    - TSettingsManager: Application settings management
    - TConfigManager: Central coordinator for all sub-managers

  Usage:
    Config := TConfigManager.Create(GetConfigPath);
    Config.LoadConfig;
    ToolchainMgr := Config.GetToolchainManager;
    // No need to Free - interface reference counting handles cleanup

  Author: fafafaStudio
  Email: dtamade@gmail.com
  QQ Group: 685403987  QQ: 179033731
================================================================================
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, DateUtils,
  fpdev.config.interfaces, fpdev.paths, fpdev.utils.fs, fpdev.constants;

type
  TConfigChangeNotifier = class(TInterfacedObject, IConfigChangeNotifier)
  private
    FOwner: Pointer;
  public
    constructor Create(AOwner: Pointer);
    procedure Detach;
    procedure NotifyConfigChanged;
  end;

  { TRepositoryManager - Git repository URL management
    Manages the list of git repositories used for FPC/Lazarus source code.
    Supports adding, removing, and querying repository URLs.
  }
  TRepositoryManager = class(TInterfacedObject, IRepositoryManager)
  private
    FNotifier: IConfigChangeNotifier;
    FRepositories: TStringList;
    FDefaultRepo: string;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    { Adds a new repository with the given name and URL.
      Returns True if successful, False if an error occurred. }
    function AddRepository(const AName, AURL: string): Boolean;

    { Removes a repository by name.
      Returns True if the repository was found and removed. }
    function RemoveRepository(const AName: string): Boolean;

    { Gets the URL for a repository by name.
      Returns empty string if not found. }
    function GetRepository(const AName: string): string;

    { Checks if a repository with the given name exists. }
    function HasRepository(const AName: string): Boolean;

    { Gets the name of the default repository. }
    function GetDefaultRepository: string;

    { Lists all registered repository names. }
    function ListRepositories: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
    procedure SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
  end;

  { TSettingsManager - Application settings management
    Manages global FPDev settings like parallel build jobs, log level, etc.
  }
  TSettingsManager = class(TInterfacedObject, ISettingsManager)
  private
    FNotifier: IConfigChangeNotifier;
    FSettings: TFPDevSettings;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);

    { Gets the current application settings. }
    function GetSettings: TFPDevSettings;

    { Updates the application settings.
      Returns True if settings were saved successfully. }
    function SetSettings(const ASettings: TFPDevSettings): Boolean;
    
    // 内部方法
    procedure LoadFromJSON(ASettings: TJSONObject);
    procedure SaveToJSON(out ASettings: TJSONObject);
  end;

  { TToolchainManager - FPC toolchain version management
    Manages installed FPC compiler toolchains, tracking versions,
    installation paths, and which version is the default.
  }
  TToolchainManager = class(TInterfacedObject, IToolchainManager)
  private
    FNotifier: IConfigChangeNotifier;
    FToolchains: TStringList;
    FDefaultToolchain: string;

    function ToolchainTypeToString(AType: TToolchainType): string;
    function StringToToolchainType(const AStr: string): TToolchainType;
    function ToolchainInfoToJSON(const AInfo: TToolchainInfo): TJSONObject;
    function JSONToToolchainInfo(AJSON: TJSONObject): TToolchainInfo;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    { Adds or updates a toolchain entry.
      AName: Version identifier (e.g., '3.2.2')
      AInfo: Toolchain metadata including path and installation mode }
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;

    { Removes a toolchain entry by name.
      Returns True if the toolchain was found and removed. }
    function RemoveToolchain(const AName: string): Boolean;

    { Gets toolchain information by name.
      Returns True if found, with AInfo populated. }
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;

    { Sets the default toolchain version to use.
      The toolchain must already be registered. }
    function SetDefaultToolchain(const AName: string): Boolean;

    { Gets the name of the default toolchain. }
    function GetDefaultToolchain: string;

    { Lists all registered toolchain version names. }
    function ListToolchains: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
    procedure SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
  end;

  { TLazarusManager - Lazarus IDE version management
    Manages installed Lazarus IDE versions, tracking versions,
    installation paths, and FPC associations.
  }
  TLazarusManager = class(TInterfacedObject, ILazarusManager)
  private
    FNotifier: IConfigChangeNotifier;
    FVersions: TStringList;
    FDefaultVersion: string;

    function LazarusInfoToJSON(const AInfo: TLazarusInfo): TJSONObject;
    function JSONToLazarusInfo(AJSON: TJSONObject): TLazarusInfo;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    { Adds or updates a Lazarus version entry.
      AName: Version identifier (e.g., '3.0')
      AInfo: Lazarus metadata including path and FPC version }
    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;

    { Removes a Lazarus version entry by name.
      Returns True if found and removed. }
    function RemoveLazarusVersion(const AName: string): Boolean;

    { Gets Lazarus version information by name.
      Returns True if found, with AInfo populated. }
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;

    { Sets the default Lazarus version to use.
      The version must already be registered. }
    function SetDefaultLazarusVersion(const AName: string): Boolean;

    { Gets the name of the default Lazarus version. }
    function GetDefaultLazarusVersion: string;

    { Lists all registered Lazarus version names. }
    function ListLazarusVersions: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(ALazarus: TJSONObject);
    procedure SaveToJSON(out ALazarus: TJSONObject);
  end;

  { TCrossTargetManager - Cross-compilation target management
    Manages cross-compilation targets like win64, linux-arm64, etc.
    Tracks binutils paths, library paths, and enabled status.
  }
  TCrossTargetManager = class(TInterfacedObject, ICrossTargetManager)
  private
    FNotifier: IConfigChangeNotifier;
    FCrossTargets: TStringList;

    function CrossTargetToJSON(const ATarget: TCrossTarget): TJSONObject;
    function JSONToCrossTarget(AJSON: TJSONObject): TCrossTarget;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    { Adds or updates a cross-compilation target.
      ATarget: Target identifier (e.g., 'win64', 'linux-arm64')
      AInfo: Target metadata including paths and enabled status }
    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;

    { Removes a cross-compilation target by name.
      Returns True if found and removed. }
    function RemoveCrossTarget(const ATarget: string): Boolean;

    { Gets cross-compilation target information.
      Returns True if found, with AInfo populated. }
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;

    { Lists all registered cross-compilation targets. }
    function ListCrossTargets: TStringArray;
    
    // 内部方法
    procedure Clear;
    procedure LoadFromJSON(ACrossTargets: TJSONObject);
    procedure SaveToJSON(out ACrossTargets: TJSONObject);
  end;

  { TConfigManager - Central configuration coordinator
    Main entry point for all configuration operations. Coordinates
    sub-managers and handles JSON persistence to config.json.

    Usage:
      Config := TConfigManager.Create;  // Uses default path
      Config.LoadConfig;
      // Access sub-managers via interface
      ToolchainMgr := Config.GetToolchainManager;
      // No need to Free - interface reference counting handles cleanup
  }
  TConfigManager = class(TInterfacedObject, IConfigManager, IConfigChangeNotifier)
  private
    FConfigPath: string;
    FModified: Boolean;
    FVersion: string;

    FNotifierObj: TObject;
    FNotifier: IConfigChangeNotifier;

    // Sub-managers with interface references for automatic cleanup
    FToolchainManager: IToolchainManager;
    FLazarusManager: ILazarusManager;
    FCrossTargetManager: ICrossTargetManager;
    FRepositoryManager: IRepositoryManager;
    FSettingsManager: ISettingsManager;

    function GetDefaultConfigPath: string;
  public
    constructor Create(const AConfigPath: string = '');
    destructor Destroy; override;

    { Loads configuration from config.json file.
      Creates default config if file doesn't exist. }
    function LoadConfig: Boolean;

    { Saves current configuration to config.json file.
      Only writes if configuration has been modified. }
    function SaveConfig: Boolean;

    { Gets the path to the configuration file. }
    function GetConfigPath: string;

    { Creates a default configuration file with sensible defaults. }
    function CreateDefaultConfig: Boolean;

    { Gets the toolchain manager for FPC version operations. }
    function GetToolchainManager: IToolchainManager;

    { Gets the Lazarus manager for IDE version operations. }
    function GetLazarusManager: ILazarusManager;

    { Gets the cross-target manager for cross-compilation operations. }
    function GetCrossTargetManager: ICrossTargetManager;

    { Gets the repository manager for git URL operations. }
    function GetRepositoryManager: IRepositoryManager;

    { Gets the settings manager for global settings. }
    function GetSettingsManager: ISettingsManager;

    { Returns True if configuration has unsaved changes. }
    function IsModified: Boolean;

    { Called by sub-managers when configuration changes.
      Marks config as modified for later save. }
    procedure NotifyConfigChanged;
  end;

const
  CONFIG_VERSION = '1.0';
  DEFAULT_PARALLEL_JOBS = 4;
  // Note: DEFAULT_FPC_REPO and DEFAULT_LAZARUS_REPO are defined in fpdev.constants

implementation

{ TConfigChangeNotifier }

constructor TConfigChangeNotifier.Create(AOwner: Pointer);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TConfigChangeNotifier.Detach;
begin
  FOwner := nil;
end;

procedure TConfigChangeNotifier.NotifyConfigChanged;
begin
  if FOwner <> nil then
    TConfigManager(FOwner).NotifyConfigChanged;
end;

{ TRepositoryManager }

constructor TRepositoryManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FRepositories := TStringList.Create;
  FDefaultRepo := '';
end;

destructor TRepositoryManager.Destroy;
begin
  FRepositories.Free;
  inherited;
end;

function TRepositoryManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := False;
  try
    FRepositories.Values[AName] := AURL;
    if Assigned(FNotifier) then
      FNotifier.NotifyConfigChanged;
    Result := True;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TRepositoryManager.RemoveRepository(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FRepositories.IndexOfName(AName);
    if Index >= 0 then
    begin
      FRepositories.Delete(Index);
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TRepositoryManager.GetRepository(const AName: string): string;
begin
  Result := FRepositories.Values[AName];
end;

function TRepositoryManager.HasRepository(const AName: string): Boolean;
begin
  if Assigned(FRepositories) then
    Result := FRepositories.IndexOfName(AName) >= 0
  else
    Result := False;
end;

function TRepositoryManager.GetDefaultRepository: string;
begin
  // Return local fallback value, actual default repo is stored in Settings
  Result := FDefaultRepo;
end;

function TRepositoryManager.ListRepositories: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(FRepositories) then Exit;
  SetLength(Result, FRepositories.Count);
  for i := 0 to FRepositories.Count - 1 do
    Result[i] := FRepositories.Names[i];
end;

procedure TRepositoryManager.Clear;
begin
  FRepositories.Clear;
  FDefaultRepo := '';
end;

procedure TRepositoryManager.LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
var
  i: Integer;
  Key: string;
begin
  Clear;
  FDefaultRepo := ADefaultRepo;
  
  if Assigned(ARepos) then
  begin
    for i := 0 to ARepos.Count - 1 do
    begin
      Key := ARepos.Names[i];
      FRepositories.Values[Key] := ARepos.Strings[Key];
    end;
  end;
end;

procedure TRepositoryManager.SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
var
  i: Integer;
  Key, Value: string;
begin
  ARepos := TJSONObject.Create;
  for i := 0 to FRepositories.Count - 1 do
  begin
    Key := FRepositories.Names[i];
    Value := FRepositories.ValueFromIndex[i];
    ARepos.Add(Key, Value);
  end;
  ADefaultRepo := FDefaultRepo;
end;

{ TSettingsManager }

constructor TSettingsManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;

  // 设置默认值
  FSettings.AutoUpdate := False;
  FSettings.ParallelJobs := DEFAULT_PARALLEL_JOBS;
  FSettings.KeepSources := True;
  FSettings.InstallRoot := '';
  FSettings.DefaultRepo := '';
  FSettings.Mirror := 'auto';        // Default to auto-detect
  FSettings.CustomRepoURL := '';     // No custom repo by default
end;

function TSettingsManager.GetSettings: TFPDevSettings;
begin
  Result := FSettings;
end;

function TSettingsManager.SetSettings(const ASettings: TFPDevSettings): Boolean;
begin
  Result := False;
  try
    FSettings := ASettings;
    if Assigned(FNotifier) then
      FNotifier.NotifyConfigChanged;
    Result := True;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

procedure TSettingsManager.LoadFromJSON(ASettings: TJSONObject);
begin
  if Assigned(ASettings) then
  begin
    FSettings.AutoUpdate := ASettings.Get('auto_update', False);
    FSettings.ParallelJobs := ASettings.Get('parallel_jobs', DEFAULT_PARALLEL_JOBS);
    FSettings.KeepSources := ASettings.Get('keep_sources', True);
    FSettings.InstallRoot := ExcludeTrailingPathDelimiter(ASettings.Get('install_root', ''));
    FSettings.DefaultRepo := ASettings.Get('default_repo', '');
    // Mirror configuration
    FSettings.Mirror := ASettings.Get('mirror', 'auto');
    FSettings.CustomRepoURL := ASettings.Get('custom_repo_url', '');
  end;
end;

procedure TSettingsManager.SaveToJSON(out ASettings: TJSONObject);
begin
  ASettings := TJSONObject.Create;
  ASettings.Add('auto_update', FSettings.AutoUpdate);
  ASettings.Add('parallel_jobs', FSettings.ParallelJobs);
  ASettings.Add('keep_sources', FSettings.KeepSources);
  ASettings.Add('install_root', FSettings.InstallRoot);
  ASettings.Add('default_repo', FSettings.DefaultRepo);
  // Mirror configuration
  ASettings.Add('mirror', FSettings.Mirror);
  ASettings.Add('custom_repo_url', FSettings.CustomRepoURL);
end;

{ TToolchainManager }

constructor TToolchainManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FToolchains := TStringList.Create;
  FDefaultToolchain := '';
end;

destructor TToolchainManager.Destroy;
begin
  FToolchains.Free;
  inherited;
end;

function TToolchainManager.ToolchainTypeToString(AType: TToolchainType): string;
begin
  Result := 'release';
  case AType of
    ttRelease: Result := 'release';
    ttDevelopment: Result := 'development';
    ttCustom: Result := 'custom';
  end;
end;

function TToolchainManager.StringToToolchainType(const AStr: string): TToolchainType;
begin
  if SameText(AStr, 'development') then
    Result := ttDevelopment
  else if SameText(AStr, 'custom') then
    Result := ttCustom
  else
    Result := ttRelease;
end;

function TToolchainManager.ToolchainInfoToJSON(const AInfo: TToolchainInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('type', ToolchainTypeToString(AInfo.ToolchainType));
    Result.Add('version', AInfo.Version);
    Result.Add('install_path', AInfo.InstallPath);
    Result.Add('source_url', AInfo.SourceURL);
    Result.Add('branch', AInfo.Branch);
    Result.Add('installed', AInfo.Installed);
    if AInfo.InstallDate > 0 then
      Result.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AInfo.InstallDate));
  except
    Result.Free;
    raise;
  end;
end;

function TToolchainManager.JSONToToolchainInfo(AJSON: TJSONObject): TToolchainInfo;
var
  DateStr: string;
begin
  Result := Default(TToolchainInfo);
  
  Result.ToolchainType := StringToToolchainType(AJSON.Get('type', 'release'));
  Result.Version := AJSON.Get('version', '');
  Result.InstallPath := AJSON.Get('install_path', '');
  Result.SourceURL := AJSON.Get('source_url', '');
  Result.Branch := AJSON.Get('branch', '');
  Result.Installed := AJSON.Get('installed', False);
  
  DateStr := AJSON.Get('install_date', '');
  if DateStr <> '' then
  begin
    try
      // Parse ISO 8601 format: 2025-12-23T14:13:01Z
      DateStr := StringReplace(DateStr, 'T', ' ', [rfReplaceAll]);
      DateStr := StringReplace(DateStr, 'Z', '', [rfReplaceAll]);
      Result.InstallDate := ScanDateTime('yyyy-mm-dd hh:nn:ss', DateStr);
    except
      Result.InstallDate := 0;
    end;
  end;
end;

function TToolchainManager.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := ToolchainInfoToJSON(AInfo);
    try
      FToolchains.Values[AName] := JSONObj.AsJSON;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TToolchainManager.RemoveToolchain(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FToolchains.IndexOfName(AName);
    if Index >= 0 then
    begin
      FToolchains.Delete(Index);
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TToolchainManager.GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  AInfo := Default(TToolchainInfo);
  
  try
    JSONStr := FToolchains.Values[AName];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := JSONToToolchainInfo(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TToolchainManager.SetDefaultToolchain(const AName: string): Boolean;
begin
  Result := False;
  try
    if FToolchains.IndexOfName(AName) >= 0 then
    begin
      FDefaultToolchain := AName;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TToolchainManager.GetDefaultToolchain: string;
begin
  Result := FDefaultToolchain;
end;

function TToolchainManager.ListToolchains: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(FToolchains) then Exit;
  SetLength(Result, FToolchains.Count);
  for i := 0 to FToolchains.Count - 1 do
    Result[i] := FToolchains.Names[i];
end;

procedure TToolchainManager.Clear;
begin
  FToolchains.Clear;
  FDefaultToolchain := '';
end;

procedure TToolchainManager.LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
var
  i: Integer;
  Key: string;
begin
  Clear;
  FDefaultToolchain := ADefaultToolchain;
  
  if Assigned(AToolchains) then
  begin
    for i := 0 to AToolchains.Count - 1 do
    begin
      Key := AToolchains.Names[i];
      FToolchains.Values[Key] := AToolchains.Items[i].AsJSON;
    end;
  end;
end;

procedure TToolchainManager.SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
var
  i: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  AToolchains := TJSONObject.Create;
  for i := 0 to FToolchains.Count - 1 do
  begin
    Key := FToolchains.Names[i];
    Value := FToolchains.ValueFromIndex[i];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      AToolchains.Add(Key, JSONData);
    end;
  end;
  ADefaultToolchain := FDefaultToolchain;
end;

{ TLazarusManager }

constructor TLazarusManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FVersions := TStringList.Create;
  FDefaultVersion := '';
end;

destructor TLazarusManager.Destroy;
begin
  FVersions.Free;
  inherited;
end;

function TLazarusManager.LazarusInfoToJSON(const AInfo: TLazarusInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('version', AInfo.Version);
    Result.Add('fpc_version', AInfo.FPCVersion);
    Result.Add('install_path', AInfo.InstallPath);
    Result.Add('source_url', AInfo.SourceURL);
    Result.Add('branch', AInfo.Branch);
    Result.Add('installed', AInfo.Installed);
  except
    Result.Free;
    raise;
  end;
end;

function TLazarusManager.JSONToLazarusInfo(AJSON: TJSONObject): TLazarusInfo;
begin
  Result := Default(TLazarusInfo);
  
  Result.Version := AJSON.Get('version', '');
  Result.FPCVersion := AJSON.Get('fpc_version', '');
  Result.InstallPath := AJSON.Get('install_path', '');
  Result.SourceURL := AJSON.Get('source_url', '');
  Result.Branch := AJSON.Get('branch', '');
  Result.Installed := AJSON.Get('installed', False);
end;

function TLazarusManager.AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := LazarusInfoToJSON(AInfo);
    try
      FVersions.Values[AName] := JSONObj.AsJSON;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.RemoveLazarusVersion(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FVersions.IndexOfName(AName);
    if Index >= 0 then
    begin
      FVersions.Delete(Index);
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  AInfo := Default(TLazarusInfo);
  
  try
    JSONStr := FVersions.Values[AName];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := JSONToLazarusInfo(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.SetDefaultLazarusVersion(const AName: string): Boolean;
begin
  Result := False;
  try
    if FVersions.IndexOfName(AName) >= 0 then
    begin
      FDefaultVersion := AName;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.GetDefaultLazarusVersion: string;
begin
  Result := FDefaultVersion;
end;

function TLazarusManager.ListLazarusVersions: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(FVersions) then Exit;
  SetLength(Result, FVersions.Count);
  for i := 0 to FVersions.Count - 1 do
    Result[i] := FVersions.Names[i];
end;

procedure TLazarusManager.Clear;
begin
  FVersions.Clear;
  FDefaultVersion := '';
end;

procedure TLazarusManager.LoadFromJSON(ALazarus: TJSONObject);
var
  VersionsJSON: TJSONObject;
  i: Integer;
  Key: string;
begin
  Clear;
  
  if Assigned(ALazarus) then
  begin
    FDefaultVersion := ALazarus.Get('default_version', '');
    VersionsJSON := ALazarus.Objects['versions'];
    if Assigned(VersionsJSON) then
    begin
      for i := 0 to VersionsJSON.Count - 1 do
      begin
        Key := VersionsJSON.Names[i];
        FVersions.Values[Key] := VersionsJSON.Items[i].AsJSON;
      end;
    end;
  end;
end;

procedure TLazarusManager.SaveToJSON(out ALazarus: TJSONObject);
var
  VersionsJSON: TJSONObject;
  i: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  ALazarus := TJSONObject.Create;
  ALazarus.Add('default_version', FDefaultVersion);
  
  VersionsJSON := TJSONObject.Create;
  for i := 0 to FVersions.Count - 1 do
  begin
    Key := FVersions.Names[i];
    Value := FVersions.ValueFromIndex[i];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      VersionsJSON.Add(Key, JSONData);
    end;
  end;
  ALazarus.Add('versions', VersionsJSON);
end;

{ TCrossTargetManager }

constructor TCrossTargetManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FCrossTargets := TStringList.Create;
end;

destructor TCrossTargetManager.Destroy;
begin
  FCrossTargets.Free;
  inherited;
end;

function TCrossTargetManager.CrossTargetToJSON(const ATarget: TCrossTarget): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('enabled', ATarget.Enabled);
    Result.Add('binutils_path', ATarget.BinutilsPath);
    Result.Add('libraries_path', ATarget.LibrariesPath);
    // Extended fields (only write if non-empty)
    if ATarget.CPU <> '' then
      Result.Add('cpu', ATarget.CPU);
    if ATarget.OS <> '' then
      Result.Add('os', ATarget.OS);
    if ATarget.SubArch <> '' then
      Result.Add('sub_arch', ATarget.SubArch);
    if ATarget.ABI <> '' then
      Result.Add('abi', ATarget.ABI);
    if ATarget.BinutilsPrefix <> '' then
      Result.Add('binutils_prefix', ATarget.BinutilsPrefix);
    if ATarget.CrossOpt <> '' then
      Result.Add('cross_opt', ATarget.CrossOpt);
  except
    Result.Free;
    raise;
  end;
end;

function TCrossTargetManager.JSONToCrossTarget(AJSON: TJSONObject): TCrossTarget;
begin
  Result := Default(TCrossTarget);

  Result.Enabled := AJSON.Get('enabled', False);
  Result.BinutilsPath := AJSON.Get('binutils_path', '');
  Result.LibrariesPath := AJSON.Get('libraries_path', '');
  // Extended fields (backward-compatible: missing keys default to '')
  Result.CPU := AJSON.Get('cpu', '');
  Result.OS := AJSON.Get('os', '');
  Result.SubArch := AJSON.Get('sub_arch', '');
  Result.ABI := AJSON.Get('abi', '');
  Result.BinutilsPrefix := AJSON.Get('binutils_prefix', '');
  Result.CrossOpt := AJSON.Get('cross_opt', '');
end;

function TCrossTargetManager.AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := CrossTargetToJSON(AInfo);
    try
      FCrossTargets.Values[ATarget] := JSONObj.AsJSON;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TCrossTargetManager.RemoveCrossTarget(const ATarget: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FCrossTargets.IndexOfName(ATarget);
    if Index >= 0 then
    begin
      FCrossTargets.Delete(Index);
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TCrossTargetManager.GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  AInfo := Default(TCrossTarget);
  
  try
    JSONStr := FCrossTargets.Values[ATarget];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := JSONToCrossTarget(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TCrossTargetManager.ListCrossTargets: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  if not Assigned(FCrossTargets) then Exit;
  SetLength(Result, FCrossTargets.Count);
  for i := 0 to FCrossTargets.Count - 1 do
    Result[i] := FCrossTargets.Names[i];
end;

procedure TCrossTargetManager.Clear;
begin
  FCrossTargets.Clear;
end;

procedure TCrossTargetManager.LoadFromJSON(ACrossTargets: TJSONObject);
var
  i: Integer;
  Key: string;
begin
  Clear;
  
  if Assigned(ACrossTargets) then
  begin
    for i := 0 to ACrossTargets.Count - 1 do
    begin
      Key := ACrossTargets.Names[i];
      FCrossTargets.Values[Key] := ACrossTargets.Items[i].AsJSON;
    end;
  end;
end;

procedure TCrossTargetManager.SaveToJSON(out ACrossTargets: TJSONObject);
var
  i: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  ACrossTargets := TJSONObject.Create;
  for i := 0 to FCrossTargets.Count - 1 do
  begin
    Key := FCrossTargets.Names[i];
    Value := FCrossTargets.ValueFromIndex[i];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      ACrossTargets.Add(Key, JSONData);
    end;
  end;
end;

{ TConfigManager }

constructor TConfigManager.Create(const AConfigPath: string);
begin
  inherited Create;

  FNotifierObj := TConfigChangeNotifier.Create(Self);
  FNotifier := TConfigChangeNotifier(FNotifierObj) as IConfigChangeNotifier;
  
  if AConfigPath = '' then
    FConfigPath := GetDefaultConfigPath
  else
    FConfigPath := AConfigPath;
    
  FModified := False;
  FVersion := CONFIG_VERSION;
  
  // Create sub-managers using interface references, fully embrace reference counting
  FToolchainManager := TToolchainManager.Create(FNotifier);
  FLazarusManager := TLazarusManager.Create(FNotifier);
  FCrossTargetManager := TCrossTargetManager.Create(FNotifier);
  FRepositoryManager := TRepositoryManager.Create(FNotifier);
  FSettingsManager := TSettingsManager.Create(FNotifier);
end;

destructor TConfigManager.Destroy;
begin
  if FNotifierObj <> nil then
    TConfigChangeNotifier(FNotifierObj).Detach;
  FNotifier := nil;
  FNotifierObj := nil;
  inherited Destroy;
end;

function TConfigManager.GetDefaultConfigPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataRoot) + 'config.json';
end;

function TConfigManager.CreateDefaultConfig: Boolean;
var
  ConfigDir: string;
  Settings: TFPDevSettings;
begin
  Result := False;
  try
    // 创建配置目录
    ConfigDir := ExtractFileDir(FConfigPath);
    if (ConfigDir <> '') and not DirectoryExists(ConfigDir) then
      EnsureDir(ConfigDir);
      
    // 设置默认仓库
    FRepositoryManager.AddRepository('official_fpc', DEFAULT_FPC_REPO);
    FRepositoryManager.AddRepository('official_lazarus', DEFAULT_LAZARUS_REPO);
    
    // 设置默认安装根目录
    Settings := FSettingsManager.GetSettings;
    if Settings.InstallRoot = '' then
    begin
      Settings.InstallRoot := IncludeTrailingPathDelimiter(ExtractFileDir(FConfigPath));
      FSettingsManager.SetSettings(Settings);
    end;
    
    FModified := True;
    Result := SaveConfig;
  except
    on E: Exception do
    begin
      { Error logged via return value }
      Result := False;
    end;
  end;
end;

function TConfigManager.LoadConfig: Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
  ConfigJSON: TJSONObject;
begin
  Result := False;
  
  if not FileExists(FConfigPath) then
  begin
    // 创建默认配置
    Result := CreateDefaultConfig;
    Exit;
  end;
  
  try
    // 读取配置文件
    with TStringList.Create do
    try
      LoadFromFile(FConfigPath);
      JSONStr := Text;
    finally
      Free;
    end;
    
    // 解析JSON
    JSONData := GetJSON(JSONStr);
    try
      if not (JSONData is TJSONObject) then
        Exit;
        
      ConfigJSON := TJSONObject(JSONData);
      
      // 读取版本
      FVersion := ConfigJSON.Get('version', CONFIG_VERSION);
      
      // 加载各子管理器数据
      FToolchainManager.LoadFromJSON(
        ConfigJSON.Objects['toolchains'],
        ConfigJSON.Get('default_toolchain', '')
      );
      
      FLazarusManager.LoadFromJSON(ConfigJSON.Objects['lazarus']);
      
      FCrossTargetManager.LoadFromJSON(ConfigJSON.Objects['cross_targets']);
      
      FRepositoryManager.LoadFromJSON(
        ConfigJSON.Objects['repositories'],
        ConfigJSON.Get('default_repo', '')
      );
      
      FSettingsManager.LoadFromJSON(ConfigJSON.Objects['settings']);
      
      FModified := False;
      Result := True;
      
    finally
      JSONData.Free;
    end;
    
  except
    on E: Exception do
    begin
      { Error logged via return value }
      Result := False;
    end;
  end;
end;

function TConfigManager.SaveConfig: Boolean;
var
  ConfigJSON: TJSONObject;
  ToolchainsJSON, LazarusJSON, CrossTargetsJSON, ReposJSON, SettingsJSON: TJSONObject;
  DefaultToolchain, DefaultRepo: string;
begin
  Result := False;
  
  try
    ConfigJSON := TJSONObject.Create;
    try
      // 基本信息
      ConfigJSON.Add('version', FVersion);
      
      // 保存各子管理器数据
      FToolchainManager.SaveToJSON(ToolchainsJSON, DefaultToolchain);
      ConfigJSON.Add('default_toolchain', DefaultToolchain);
      ConfigJSON.Add('toolchains', ToolchainsJSON);
      
      FLazarusManager.SaveToJSON(LazarusJSON);
      ConfigJSON.Add('lazarus', LazarusJSON);
      
      FCrossTargetManager.SaveToJSON(CrossTargetsJSON);
      ConfigJSON.Add('cross_targets', CrossTargetsJSON);
      
      FRepositoryManager.SaveToJSON(ReposJSON, DefaultRepo);
      ConfigJSON.Add('repositories', ReposJSON);
      
      FSettingsManager.SaveToJSON(SettingsJSON);
      ConfigJSON.Add('settings', SettingsJSON);
      
      // 保存到文件
      with TStringList.Create do
      try
        Text := ConfigJSON.FormatJSON;
        SaveToFile(FConfigPath);
        FModified := False;
        Result := True;
      finally
        Free;
      end;
      
    finally
      ConfigJSON.Free;
    end;
    
  except
    on E: Exception do
    begin
      { Error logged via return value }
      Result := False;
    end;
  end;
end;

function TConfigManager.GetConfigPath: string;
begin
  Result := FConfigPath;
end;

function TConfigManager.GetToolchainManager: IToolchainManager;
begin
  Result := FToolchainManager;
end;

function TConfigManager.GetLazarusManager: ILazarusManager;
begin
  Result := FLazarusManager;
end;

function TConfigManager.GetCrossTargetManager: ICrossTargetManager;
begin
  Result := FCrossTargetManager;
end;

function TConfigManager.GetRepositoryManager: IRepositoryManager;
begin
  Result := FRepositoryManager;
end;

function TConfigManager.GetSettingsManager: ISettingsManager;
begin
  Result := FSettingsManager;
end;

function TConfigManager.IsModified: Boolean;
begin
  Result := FModified;
end;

procedure TConfigManager.NotifyConfigChanged;
begin
  FModified := True;
end;

end.
