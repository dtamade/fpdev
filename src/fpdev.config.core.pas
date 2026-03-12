unit fpdev.config.core;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.config.repositories,
  fpdev.config.settings,
  fpdev.config.toolchains,
  fpdev.config.lazarus,
  fpdev.config.crosstargets;

function GetDefaultConfigPathOverride: string;
procedure SetDefaultConfigPathOverride(const AConfigPath: string);
procedure ClearDefaultConfigPathOverride;

type
  TConfigChangeNotifier = class(TInterfacedObject, IConfigChangeNotifier)
  private
    FOwner: Pointer;
  public
    constructor Create(AOwner: Pointer);
    procedure Detach;
    procedure NotifyConfigChanged;
  end;

  TConfigManager = class(TInterfacedObject, IConfigManager, IConfigChangeNotifier)
  private
    FConfigPath: string;
    FModified: Boolean;
    FVersion: string;
    FNotifierObj: TObject;
    FNotifier: IConfigChangeNotifier;
    FToolchainManager: IToolchainManager;
    FLazarusManager: ILazarusManager;
    FCrossTargetManager: ICrossTargetManager;
    FRepositoryManager: IRepositoryManager;
    FSettingsManager: ISettingsManager;
    function GetDefaultConfigPath: string;
  public
    constructor Create(const AConfigPath: string = '');
    destructor Destroy; override;
    function LoadConfig: Boolean;
    function SaveConfig: Boolean;
    function GetConfigPath: string;
    function CreateDefaultConfig: Boolean;
    function GetToolchainManager: IToolchainManager;
    function GetLazarusManager: ILazarusManager;
    function GetCrossTargetManager: ICrossTargetManager;
    function GetRepositoryManager: IRepositoryManager;
    function GetSettingsManager: ISettingsManager;
    function IsModified: Boolean;
    procedure NotifyConfigChanged;
  end;

implementation

uses
  fpdev.paths,
  fpdev.utils.fs,
  fpdev.constants,
  fpdev.config.persistence;

const
  CONFIG_VERSION = '1.0';

var
  GDefaultConfigPathOverride: string = '';

function GetDefaultConfigPathOverride: string;
begin
  Result := GDefaultConfigPathOverride;
end;

procedure SetDefaultConfigPathOverride(const AConfigPath: string);
begin
  GDefaultConfigPathOverride := AConfigPath;
end;

procedure ClearDefaultConfigPathOverride;
begin
  GDefaultConfigPathOverride := '';
end;

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
  if GDefaultConfigPathOverride <> '' then
    Result := GDefaultConfigPathOverride
  else
    Result := fpdev.paths.GetConfigPath;
end;

function TConfigManager.CreateDefaultConfig: Boolean;
var
  ConfigDir: string;
  Settings: TFPDevSettings;
begin
  Result := False;
  try
    ConfigDir := ExtractFileDir(FConfigPath);
    if (ConfigDir <> '') and not DirectoryExists(ConfigDir) then
      EnsureDir(ConfigDir);

    FRepositoryManager.AddRepository('official_fpc', DEFAULT_FPC_REPO);
    FRepositoryManager.AddRepository('official_lazarus', DEFAULT_LAZARUS_REPO);

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
      Result := False;
  end;
end;

function TConfigManager.LoadConfig: Boolean;
begin
  Result := False;

  if not FileExists(FConfigPath) then
  begin
    Result := CreateDefaultConfig;
    Exit;
  end;

  Result := LoadConfigFromFileCore(
    FConfigPath,
    CONFIG_VERSION,
    FToolchainManager,
    FLazarusManager,
    FCrossTargetManager,
    FRepositoryManager,
    FSettingsManager,
    FVersion
  );
  if Result then
    FModified := False;
end;

function TConfigManager.SaveConfig: Boolean;
begin
  Result := SaveConfigToFileCore(
    FConfigPath,
    FVersion,
    FToolchainManager,
    FLazarusManager,
    FCrossTargetManager,
    FRepositoryManager,
    FSettingsManager
  );
  if Result then
    FModified := False;
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
