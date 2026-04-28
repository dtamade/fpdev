unit fpdev.lazarus.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.lazarus.manager

Lazarus IDE version management commands


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
  fpdev.output.intf, fpdev.output.console, fpdev.config.interfaces,
  fpdev.lazarus.commandflow,
  fpdev.lazarus.installcallbacks,
  fpdev.lazarus.runtimeactions,
  fpdev.lazarus.types,
  fpdev.lazarus.source, fpdev.utils.fs,
  fpdev.utils.process, fpdev.git.types, fpdev.git.runtime,
  fpdev.i18n, fpdev.i18n.strings;

type
  ILazarusGitClient = fpdev.lazarus.installcallbacks.ILazarusInstallGitClient;

  TLazarusVersionInfo = fpdev.lazarus.types.TLazarusVersionInfo;
  TLazarusVersionArray = fpdev.lazarus.types.TLazarusVersionArray;

  { TLazarusManager }
  TLazarusManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    function BuildFromSource(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
    function SetupEnvironment(const AVersion: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;
    function TryGetConfiguredInstallPath(const AVersion: string; out AInstallPath: string): Boolean;
    function TryGetConfiguredVersionInfo(const AVersion: string; out AVersionInfo: TLazarusVersionInfo): Boolean;
    function GetResolvedInstallPath(const AVersion: string): string;
    function GetExecutablePathFromInstallPath(const AInstallPath: string): string;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function IsValidSourceDirectory(const ASourceDir: string): Boolean;
    function GetCompatibleFPCVersion(const ALazarusVersion: string): string;
    function CleanSourceArtifacts(const ASourceDir: string): Integer;
    function LaunchLazarusExecutable(const AExecutable: string): Boolean;
    function SetConfiguredDefaultVersion(const AVersion: string): Boolean;
    function GetRecommendedCompatibleFPC(const AVersion: string): string;
    function GetConfiguredVersionNames: TStringArray;
    function TryGetConfiguredLazarusInfo(const AVersion: string; out ALazarusInfo: TLazarusInfo): Boolean;
    procedure DeleteInstallDirectory(const APath: string);
    procedure RemoveConfiguredVersion(const AVersion: string);
    function CreateMaintenanceGitRuntime(const ACliOnly: Boolean): ILazarusGitRuntime;
    function RunConfigureIDEWithOutputs(const Outp, Errp: IOutput;
      const AVersion: string): Boolean;
  protected
    function CreateGitClient(const ACliOnly: Boolean): ILazarusGitClient; virtual;
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager);
    destructor Destroy; override;

    // Version queries
    function GetAvailableVersions: TLazarusVersionArray;
    function GetInstalledVersions: TLazarusVersionArray;

    // Version management
    function InstallVersion(
      const AVersion: string;
      const AFPCVersion: string = '';
      const AFromSource: Boolean = False;
      const AConfigure: Boolean = True
    ): Boolean; overload;
    function InstallVersion(
      const Outp, Errp: IOutput;
      const AVersion: string;
      const AFPCVersion: string;
      const AFromSource: Boolean;
      const AConfigure: Boolean = True
    ): Boolean; overload;
    function UninstallVersion(const AVersion: string): Boolean; overload;
    function UninstallVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function ListVersions(const AShowAll: Boolean = False): Boolean; overload;
    function ListVersions(const Outp: IOutput; const AShowAll: Boolean = False): Boolean; overload;
    function SetDefaultVersion(const AVersion: string): Boolean; overload;
    function SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function GetCurrentVersion: string;

    // Source management
    function UpdateSources(const AVersion: string = ''): Boolean; overload;
    function UpdateSources(const Outp, Errp: IOutput; const AVersion: string = ''): Boolean; overload;
    function CleanSources(const AVersion: string = ''): Boolean;

    // IDE operations
    function ShowVersionInfo(const AVersion: string): Boolean; overload;
    function ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean; overload;
    function TestInstallation(const AVersion: string): Boolean; overload;
    function TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function LaunchIDE(const AVersion: string = ''): Boolean; overload;
    function LaunchIDE(const Outp: IOutput; const AVersion: string = ''): Boolean; overload;
    function ConfigureIDE(const AVersion: string): Boolean; overload;
    function ConfigureIDE(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
  end;

implementation

uses
  fpdev.version.registry, fpdev.lazarus.metadataflow,
  fpdev.lazarus.catalogflow,
  fpdev.lazarus.maintenanceflow,
  fpdev.lazarus.versionflow,
  fpdev.lazarus.pathflow;

type
  TLazarusGitClient = class(TInterfacedObject, ILazarusGitClient)
  private
    FGit: IGitRuntime;
  public
    constructor Create(const ACliOnly: Boolean);
    destructor Destroy; override;
    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function GetLastError: string;
  end;

constructor TLazarusGitClient.Create(const ACliOnly: Boolean);
begin
  inherited Create;
  FGit := NewGitRuntime(ACliOnly);
end;

destructor TLazarusGitClient.Destroy;
begin
  FGit := nil;
  inherited Destroy;
end;

function TLazarusGitClient.GetBackend: TGitBackend;
begin
  Result := FGit.Backend;
end;

function TLazarusGitClient.BackendAvailable: Boolean;
begin
  Result := FGit.Backend <> gbNone;
end;

function TLazarusGitClient.Clone(const AURL, ALocalPath: string;
  const ABranch: string): Boolean;
begin
  Result := FGit.Clone(AURL, ALocalPath, ABranch);
end;

function TLazarusGitClient.Fetch(const ARepoPath: string;
  const ARemote: string): Boolean;
begin
  Result := FGit.Fetch(ARepoPath, ARemote);
end;

function TLazarusGitClient.Checkout(const ARepoPath, AName: string;
  const Force: Boolean): Boolean;
begin
  Result := FGit.Checkout(ARepoPath, AName, Force);
end;

function TLazarusGitClient.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TLazarusGitClient.HasRemote(const ARepoPath: string): Boolean;
begin
  Result := FGit.HasRemote(ARepoPath);
end;

function TLazarusGitClient.Pull(const ARepoPath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(ARepoPath);
end;

function TLazarusGitClient.GetLastError: string;
begin
  Result := FGit.LastError;
end;

{ TLazarusManager }

constructor TLazarusManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    // Default to data directory next to executable, fallback via ConfigManager if not writable
    FInstallRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  // Ensure install directory exists
  if not DirectoryExists(FInstallRoot) then
    EnsureDir(FInstallRoot);
end;

destructor TLazarusManager.Destroy;
begin
  inherited Destroy;
end;

function TLazarusManager.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := BuildLazarusVersionInstallPathCore(FInstallRoot, AVersion);
end;

function TLazarusManager.TryGetConfiguredInstallPath(const AVersion: string;
  out AInstallPath: string): Boolean;
var
  LazarusInfo: TLazarusInfo;
begin
  AInstallPath := '';
  Result := False;
  if not FConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-' + AVersion, LazarusInfo) then
    Exit;
  AInstallPath := ExcludeTrailingPathDelimiter(Trim(LazarusInfo.InstallPath));
  Result := AInstallPath <> '';
end;

function TLazarusManager.GetExecutablePathFromInstallPath(
  const AInstallPath: string): string;
begin
  Result := BuildLazarusExecutablePathFromInstallPathCore(
    AInstallPath,
    {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
  );
end;

function TLazarusManager.GetResolvedInstallPath(const AVersion: string): string;
var
  ConfiguredPath: string;
begin
  ConfiguredPath := '';

  if not TryGetConfiguredInstallPath(AVersion, ConfiguredPath) then
    ConfiguredPath := '';

  Result := ResolveLazarusInstallPathCore(
    GetVersionInstallPath(AVersion),
    ConfiguredPath,
    {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
  );
end;

function TLazarusManager.TryGetConfiguredVersionInfo(const AVersion: string;
  out AVersionInfo: TLazarusVersionInfo): Boolean;
var
  LazarusInfo: TLazarusInfo;
  RecommendedFPCVersion: string;
begin
  AVersionInfo := Default(TLazarusVersionInfo);
  Result := False;

  if not FConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-' + AVersion, LazarusInfo) then
    Exit;

  RecommendedFPCVersion := TVersionRegistry.Instance.GetLazarusRecommendedFPC(AVersion);
  AVersionInfo := BuildConfiguredLazarusVersionInfoCore(
    AVersion,
    LazarusInfo,
    RecommendedFPCVersion,
    ValidateVersion(AVersion),
    IsVersionInstalled(AVersion)
  );
  Result := True;
end;

function TLazarusManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := IsLazarusVersionInstalledCore(
    GetResolvedInstallPath(AVersion),
    {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
  );
end;

function TLazarusManager.ValidateVersion(const AVersion: string): Boolean;
begin
  Result := TVersionRegistry.Instance.IsLazarusVersionValid(AVersion);
end;

function TLazarusManager.GetCompatibleFPCVersion(const ALazarusVersion: string): string;
begin
  Result := ResolveManagedLazarusCompatibleFPCVersionCore(
    ALazarusVersion,
    GetRecommendedCompatibleFPC(ALazarusVersion),
    @TryGetConfiguredVersionInfo
  );
end;

function TLazarusManager.GetAvailableVersions: TLazarusVersionArray;
begin
  Result := BuildManagedLazarusAvailableVersionsCore(
    TVersionRegistry.Instance.GetLazarusReleases,
    GetConfiguredVersionNames,
    @TryGetConfiguredVersionInfo,
    @IsVersionInstalled
  );
end;

function TLazarusManager.GetInstalledVersions: TLazarusVersionArray;
begin
  Result := FilterManagedInstalledLazarusVersionsCore(GetAvailableVersions);
end;

function TLazarusManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
begin
  Result := DownloadLazarusSourceCore(AVersion, ATargetDir, @CreateGitClient);
end;

function TLazarusManager.BuildFromSource(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
begin
  Result := BuildLazarusFromSourceCore(
    FConfigManager,
    ASourceDir,
    AInstallDir,
    AFPCVersion
  );
end;

function TLazarusManager.SetupEnvironment(const AVersion: string): Boolean;
begin
  Result := SetupLazarusEnvironmentCore(
    FConfigManager,
    AVersion,
    @IsVersionInstalled,
    @GetResolvedInstallPath,
    @GetCompatibleFPCVersion
  );
end;

function TLazarusManager.CleanSourceArtifacts(const ASourceDir: string): Integer;
begin
  Result := CleanBuildArtifacts(ASourceDir, nil, True);
end;

function TLazarusManager.LaunchLazarusExecutable(const AExecutable: string): Boolean;
begin
  Result := TProcessExecutor.Launch(AExecutable, [], '');
end;

function TLazarusManager.SetConfiguredDefaultVersion(const AVersion: string): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.SetDefaultLazarusVersion('lazarus-' + AVersion);
end;

function TLazarusManager.GetRecommendedCompatibleFPC(const AVersion: string): string;
begin
  Result := TVersionRegistry.Instance.GetLazarusRecommendedFPC(AVersion);
end;

function TLazarusManager.GetConfiguredVersionNames: TStringArray;
begin
  Result := FConfigManager.GetLazarusManager.ListLazarusVersions;
end;

function TLazarusManager.TryGetConfiguredLazarusInfo(
  const AVersion: string;
  out ALazarusInfo: TLazarusInfo
): Boolean;
begin
  Result := FConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-' + AVersion, ALazarusInfo);
end;

procedure TLazarusManager.DeleteInstallDirectory(const APath: string);
begin
  DeleteDirRecursive(APath);
end;

procedure TLazarusManager.RemoveConfiguredVersion(const AVersion: string);
begin
  FConfigManager.GetLazarusManager.RemoveLazarusVersion('lazarus-' + AVersion);
end;

function TLazarusManager.CreateMaintenanceGitRuntime(const ACliOnly: Boolean): ILazarusGitRuntime;
begin
  Result := CreateGitClient(ACliOnly);
end;

function TLazarusManager.InstallVersion(
  const AVersion: string;
  const AFPCVersion: string;
  const AFromSource: Boolean;
  const AConfigure: Boolean
): Boolean;
begin
  Result := InstallVersion(nil, nil, AVersion, AFPCVersion, AFromSource, AConfigure);
end;

function TLazarusManager.InstallVersion(
  const Outp, Errp: IOutput;
  const AVersion: string;
  const AFPCVersion: string;
  const AFromSource: Boolean;
  const AConfigure: Boolean
): Boolean;
var
  InstallPlan: TLazarusInstallPlan;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_UNSUPPORTED_VERSION, [AVersion]));
    Exit;
  end;

  if IsVersionInstalled(AVersion) then
  begin
    Result := True;
    Exit;
  end;

  try
    InstallPlan := CreateLazarusInstallPlanCore(
      FInstallRoot,
      AVersion,
      AFPCVersion,
      GetCompatibleFPCVersion(AVersion),
      AFromSource,
      AConfigure
    );

    Result := ExecuteLazarusInstallPlanCore(
      InstallPlan,
      Outp,
      Errp,
      @DownloadSource,
      @BuildFromSource,
      @SetupEnvironment,
      @RunConfigureIDEWithOutputs
    );

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['installation', E.Message]));
      Result := False;
    end;
  end;
end;

function TLazarusManager.RunConfigureIDEWithOutputs(
  const Outp, Errp: IOutput;
  const AVersion: string
): Boolean;
begin
  // Keep install-plan callbacks off the overloaded ConfigureIDE method pointer for FPC 3.2.2.
  Result := ConfigureIDE(Outp, Errp, AVersion);
end;

function TLazarusManager.UninstallVersion(const AVersion: string): Boolean;
begin
  Result := UninstallVersion(nil, nil, AVersion);
end;

function TLazarusManager.UninstallVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  if Outp = nil then;  // Unused parameter

  try
    Result := ExecuteManagedLazarusUninstallCore(
      AVersion,
      @IsVersionInstalled,
      @GetResolvedInstallPath,
      @TryGetConfiguredLazarusInfo,
      @DeleteInstallDirectory,
      @RemoveConfiguredVersion
    );
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['uninstallation', E.Message]));
      Result := False;
    end;
  end;
end;

function TLazarusManager.ListVersions(const AShowAll: Boolean): Boolean;
begin
  Result := ListVersions(nil, AShowAll);
end;

function TLazarusManager.ListVersions(const Outp: IOutput; const AShowAll: Boolean): Boolean;
var
  Versions: TLazarusVersionArray;
  LO: IOutput;
begin
  Result := True;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;
    Result := WriteManagedLazarusVersionListCore(
      Versions,
      FConfigManager.GetLazarusManager.GetDefaultLazarusVersion,
      AShowAll,
      LO
    );

  except
    on E: Exception do
    begin
      LO.WriteLn('ListVersions error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := SetDefaultVersion(nil, nil, AVersion);
end;

function TLazarusManager.SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  try
    Result := SetManagedLazarusDefaultVersionCore(
      AVersion,
      Outp,
      Errp,
      @IsVersionInstalled,
      @SetConfiguredDefaultVersion
    );
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['setting default version', E.Message]));
      Result := False;
    end;
  end;
end;

function TLazarusManager.GetCurrentVersion: string;
var
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := '';

  try
    Result := NormalizeDefaultLazarusVersionCore(
      FConfigManager.GetLazarusManager.GetDefaultLazarusVersion
    );

  except
    on E: Exception do
    begin
      LOut.WriteLn('GetCurrentVersion error: ' + E.Message);
      Result := '';
    end;
  end;
end;

function TLazarusManager.IsValidSourceDirectory(const ASourceDir: string): Boolean;
begin
  Result := DirectoryExists(ASourceDir) and
    DirectoryExists(ASourceDir + PathDelim + 'ide') and
    DirectoryExists(ASourceDir + PathDelim + 'lcl') and
    DirectoryExists(ASourceDir + PathDelim + 'packager');
end;

function TLazarusManager.UpdateSources(const AVersion: string): Boolean;
begin
  Result := UpdateSources(nil, nil, AVersion);
end;

function TLazarusManager.UpdateSources(
  const Outp, Errp: IOutput;
  const AVersion: string
): Boolean;
begin
  try
    Result := ExecuteManagedLazarusUpdateSourcesCore(
      AVersion,
      FInstallRoot,
      Outp,
      Errp,
      @GetCurrentVersion,
      @IsValidSourceDirectory,
      @CreateMaintenanceGitRuntime
    );
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['updating sources', E.Message]));
      Result := False;
    end;
  end;
end;

function TLazarusManager.CreateGitClient(
  const ACliOnly: Boolean): ILazarusGitClient;
begin
  Result := TLazarusGitClient.Create(ACliOnly);
end;

function TLazarusManager.CleanSources(const AVersion: string): Boolean;
var
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  try
    Result := ExecuteManagedLazarusCleanSourcesCore(
      AVersion,
      FInstallRoot,
      LOut,
      @GetCurrentVersion,
      @IsValidSourceDirectory,
      @CleanSourceArtifacts
    );
  except
    on E: Exception do
    begin
      LOut.WriteLn('CleanSources error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.ShowVersionInfo(const AVersion: string): Boolean;
begin
  Result := ShowVersionInfo(nil, AVersion);
end;

function TLazarusManager.ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean;
var
  LO: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    Result := ShowManagedLazarusVersionInfoCore(
      AVersion,
      LO,
      GetAvailableVersions,
      @TryGetConfiguredVersionInfo,
      @IsVersionInstalled,
      @GetResolvedInstallPath,
      @TryGetConfiguredLazarusInfo
    );
  except
    on E: Exception do
    begin
      LO.WriteLn('ShowVersionInfo error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.TestInstallation(const AVersion: string): Boolean;
begin
  Result := TestInstallation(nil, nil, AVersion);
end;

function TLazarusManager.TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Result := TestLazarusInstallationCore(
    Outp,
    Errp,
    AVersion,
    @IsVersionInstalled,
    @GetResolvedInstallPath,
    @GetExecutablePathFromInstallPath
  );
end;

function TLazarusManager.LaunchIDE(const AVersion: string): Boolean;
begin
  Result := LaunchIDE(nil, AVersion);
end;

function TLazarusManager.LaunchIDE(const Outp: IOutput; const AVersion: string): Boolean;
begin
  Result := LaunchLazarusIDECore(
    FInstallRoot,
    AVersion,
    GetCurrentVersion,
    Outp,
    @GetResolvedInstallPath,
    @GetExecutablePathFromInstallPath,
    @IsVersionInstalled,
    @LaunchLazarusExecutable
  );
end;

function TLazarusManager.ConfigureIDE(const AVersion: string): Boolean;
begin
  Result := ConfigureIDE(nil, nil, AVersion);
end;

function TLazarusManager.ConfigureIDE(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Result := ConfigureLazarusIDECore(
    FConfigManager,
    Outp,
    Errp,
    AVersion,
    @IsVersionInstalled,
    @GetResolvedInstallPath,
    @GetCompatibleFPCVersion
  );
end;

end.
