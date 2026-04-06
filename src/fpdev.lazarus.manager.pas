unit fpdev.lazarus.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.lazarus

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
  fpdev.build.toolchain,
  fpdev.lazarus.commandflow,
  fpdev.lazarus.source, fpdev.lazarus.config, fpdev.utils, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils.git, fpdev.git.runtime,
  fpdev.i18n, fpdev.i18n.strings;

type
  ILazarusGitClient = interface(ILazarusGitRuntime)
    ['{E7B6E0A1-19D0-4E96-B063-C7C4A4FE0C81}']
    function GetBackend: TGitBackend;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    property Backend: TGitBackend read GetBackend;
  end;

  { TLazarusVersionInfo }
  TLazarusVersionInfo = record
    Version: string;
    ReleaseDate: string;
    GitTag: string;
    Branch: string;
    FPCVersion: string;
    Available: Boolean;
    Installed: Boolean;
  end;

  TLazarusVersionArray = array of TLazarusVersionInfo;

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
    function RunConfigureIDEInstall(const Outp, Errp: IOutput; const AVersion: string): Boolean;
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
  fpdev.version.registry, fpdev.constants;

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
  FGit := TGitRuntime.Create(nil, ACliOnly);
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
  Result := FInstallRoot + PathDelim + 'lazarus' + PathDelim + AVersion;
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
  {$IFDEF MSWINDOWS}
  Result := AInstallPath + PathDelim + 'lazarus.exe';
  {$ELSE}
  Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'lazarus-ide';
  {$ENDIF}
end;

function TLazarusManager.GetResolvedInstallPath(const AVersion: string): string;
var
  ConfiguredPath: string;
begin
  Result := GetVersionInstallPath(AVersion);
  ConfiguredPath := '';

  if TryGetConfiguredInstallPath(AVersion, ConfiguredPath) then
  begin
    if FileExists(GetExecutablePathFromInstallPath(ConfiguredPath)) then
      Exit(ConfiguredPath);
  end;

  if FileExists(GetExecutablePathFromInstallPath(Result)) then
    Exit;

  if ConfiguredPath <> '' then
    Result := ConfiguredPath;
end;

function TLazarusManager.TryGetConfiguredVersionInfo(const AVersion: string;
  out AVersionInfo: TLazarusVersionInfo): Boolean;
var
  LazarusInfo: TLazarusInfo;
  NormalizedFPCVersion: string;
begin
  AVersionInfo := Default(TLazarusVersionInfo);
  Result := False;

  if not FConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-' + AVersion, LazarusInfo) then
    Exit;

  AVersionInfo.Version := AVersion;
  AVersionInfo.ReleaseDate := '';
  AVersionInfo.GitTag := '';
  AVersionInfo.Branch := LazarusInfo.Branch;

  NormalizedFPCVersion := Trim(LazarusInfo.FPCVersion);
  if SameText(Copy(NormalizedFPCVersion, 1, 4), 'fpc-') then
    Delete(NormalizedFPCVersion, 1, 4);
  if NormalizedFPCVersion = '' then
    NormalizedFPCVersion := TVersionRegistry.Instance.GetLazarusRecommendedFPC(AVersion);
  if NormalizedFPCVersion = '' then
    NormalizedFPCVersion := DEFAULT_FPC_VERSION;

  AVersionInfo.FPCVersion := NormalizedFPCVersion;
  AVersionInfo.Available := ValidateVersion(AVersion);
  AVersionInfo.Installed := LazarusInfo.Installed or IsVersionInstalled(AVersion);
  Result := True;
end;

function TLazarusManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := FileExists(GetExecutablePathFromInstallPath(GetResolvedInstallPath(AVersion)));
end;

function TLazarusManager.ValidateVersion(const AVersion: string): Boolean;
begin
  Result := TVersionRegistry.Instance.IsLazarusVersionValid(AVersion);
end;

function TLazarusManager.GetCompatibleFPCVersion(const ALazarusVersion: string): string;
var
  ConfiguredInfo: TLazarusVersionInfo;
begin
  ConfiguredInfo := Default(TLazarusVersionInfo);
  if TryGetConfiguredVersionInfo(ALazarusVersion, ConfiguredInfo) and
     (Trim(ConfiguredInfo.FPCVersion) <> '') then
    Exit(ConfiguredInfo.FPCVersion);

  Result := TVersionRegistry.Instance.GetLazarusRecommendedFPC(ALazarusVersion);
end;

function TLazarusManager.GetAvailableVersions: TLazarusVersionArray;
var
  i: Integer;
  Releases: TLazarusReleaseArray;
  ConfiguredInfo: TLazarusVersionInfo;
  ConfiguredVersions: TStringArray;
  ConfiguredVersion: string;
  ExistingIndex: Integer;
  PrefixLength: Integer;
  Found: Boolean;
begin
  Result := nil;
  ConfiguredInfo := Default(TLazarusVersionInfo);
  Releases := TVersionRegistry.Instance.GetLazarusReleases;
  SetLength(Result, Length(Releases));
  PrefixLength := Length('lazarus-');
  for i := 0 to High(Releases) do
  begin
    Result[i].Version := Releases[i].Version;
    Result[i].ReleaseDate := Releases[i].ReleaseDate;
    Result[i].GitTag := Releases[i].GitTag;
    Result[i].Branch := Releases[i].Branch;
    if Length(Releases[i].FPCCompatible) > 0 then
      Result[i].FPCVersion := Releases[i].FPCCompatible[0]
    else
      Result[i].FPCVersion := DEFAULT_FPC_VERSION;
    Result[i].Available := True;
    Result[i].Installed := IsVersionInstalled(Result[i].Version);

    if Result[i].Installed and
       TryGetConfiguredVersionInfo(Result[i].Version, ConfiguredInfo) and
       ConfiguredInfo.Installed then
    begin
      if Trim(ConfiguredInfo.FPCVersion) <> '' then
        Result[i].FPCVersion := ConfiguredInfo.FPCVersion;
      if Trim(ConfiguredInfo.Branch) <> '' then
        Result[i].Branch := ConfiguredInfo.Branch;
    end;
  end;

  ConfiguredVersions := FConfigManager.GetLazarusManager.ListLazarusVersions;
  for i := 0 to High(ConfiguredVersions) do
  begin
    ConfiguredVersion := ConfiguredVersions[i];
    if SameText(Copy(ConfiguredVersion, 1, PrefixLength), 'lazarus-') then
      Delete(ConfiguredVersion, 1, PrefixLength);
    if ConfiguredVersion = '' then
      Continue;

    Found := False;
    for ExistingIndex := 0 to High(Result) do
    begin
      if SameText(Result[ExistingIndex].Version, ConfiguredVersion) then
      begin
        Found := True;
        Break;
      end;
    end;
    if Found then
      Continue;

    if not TryGetConfiguredVersionInfo(ConfiguredVersion, ConfiguredInfo) then
      Continue;
    if not ConfiguredInfo.Installed then
      Continue;

    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ConfiguredInfo;
  end;
end;

function TLazarusManager.GetInstalledVersions: TLazarusVersionArray;
var
  AllVersions: TLazarusVersionArray;
  ConfiguredVersions: TStringArray;
  ConfiguredVersion: string;
  ConfiguredInfo: TLazarusVersionInfo;
  i, Count, ExistingIndex: Integer;
  PrefixLength: Integer;
  Found: Boolean;
begin
  Result := nil;
  ConfiguredInfo := Default(TLazarusVersionInfo);
  AllVersions := GetAvailableVersions;
  Count := 0;
  PrefixLength := Length('lazarus-');

  // Count installed versions
  for i := 0 to High(AllVersions) do
    if AllVersions[i].Installed then
      Inc(Count);

  // Create result array
  SetLength(Result, Count);
  Count := 0;

  for i := 0 to High(AllVersions) do
  begin
    if AllVersions[i].Installed then
    begin
      Result[Count] := AllVersions[i];
      Inc(Count);
    end;
  end;

  ConfiguredVersions := FConfigManager.GetLazarusManager.ListLazarusVersions;
  for i := 0 to High(ConfiguredVersions) do
  begin
    ConfiguredVersion := ConfiguredVersions[i];
    if SameText(Copy(ConfiguredVersion, 1, PrefixLength), 'lazarus-') then
      Delete(ConfiguredVersion, 1, PrefixLength);
    if ConfiguredVersion = '' then
      Continue;

    Found := False;
    for ExistingIndex := 0 to High(Result) do
    begin
      if SameText(Result[ExistingIndex].Version, ConfiguredVersion) then
      begin
        Found := True;
        Break;
      end;
    end;
    if Found then
      Continue;

    if not TryGetConfiguredVersionInfo(ConfiguredVersion, ConfiguredInfo) then
      Continue;
    if not ConfiguredInfo.Installed then
      Continue;

    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ConfiguredInfo;
  end;
end;

function TLazarusManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
var
  Git: ILazarusGitClient;
  GitTag: string;
  RepositoryURL: string;
begin
  Result := False;

  // Get Git tag from registry
  GitTag := TVersionRegistry.Instance.GetLazarusGitTag(AVersion);
  RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;

  if GitTag = '' then
  begin
    Exit;
  end;

  if RepositoryURL = '' then
    RepositoryURL := LAZARUS_OFFICIAL_REPO;

  Git := CreateGitClient(False);

  // Check Git backend availability
  if (Git = nil) or (Git.Backend = gbNone) then
    Exit;

  // Ensure parent directory exists (git clone requires target to not exist)
  if not DirectoryExists(ExtractFileDir(ATargetDir)) then
    EnsureDir(ExtractFileDir(ATargetDir));

  if DirectoryExists(ATargetDir) then
  begin
    if DirectoryExists(ATargetDir + PathDelim + '.git') then
    begin
      if not Git.Fetch(ATargetDir, 'origin') then
        Exit(False);
      Result := Git.Checkout(ATargetDir, GitTag, True);
    end
    else
    begin
      DeleteDirRecursive(ATargetDir);
      Result := Git.Clone(RepositoryURL, ATargetDir, GitTag);
    end;
  end
  else
    Result := Git.Clone(RepositoryURL, ATargetDir, GitTag);
end;

function TLazarusManager.BuildFromSource(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
var
  LResult: TProcessResult;
  MakeCmd: string;
  Settings: TFPDevSettings;
  ToolchainChecker: TBuildToolchainChecker;
  BuildPlan: TLazarusBuildPlan;
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := False;

  if not DirectoryExists(ASourceDir) then
  begin
    Exit;
  end;

  try

    // Ensure install directory exists
    if not DirectoryExists(AInstallDir) then
      EnsureDir(AInstallDir);

    Settings := FConfigManager.GetSettingsManager.GetSettings;

    ToolchainChecker := TBuildToolchainChecker.Create(False);
    try
      MakeCmd := ToolchainChecker.ResolveMakeCmd;
    finally
      ToolchainChecker.Free;
    end;

    BuildPlan := CreateLazarusBuildPlanCore(
      ASourceDir,
      AInstallDir,
      Settings.InstallRoot,
      AFPCVersion,
      Settings.ParallelJobs,
      MakeCmd,
      GetEnvironmentVariable('PATH'),
      {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
    );

    // Execute make with custom environment using unified process executor
    LResult := TProcessExecutor.RunDirectWithEnv(
      BuildPlan.MakeCommand,
      BuildPlan.Params,
      BuildPlan.SourceDir,
      BuildPlan.EnvVars
    );

    Result := LResult.Success;

  except
    on E: Exception do
    begin
      LOut.WriteLn('BuildFromSource error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.SetupEnvironment(const AVersion: string): Boolean;
var
  LazarusInfo: TLazarusInfo;
  InstallPath: string;
  FPCVersion: string;
  RepositoryURL: string;
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    Exit;
  end;

  try
    InstallPath := GetResolvedInstallPath(AVersion);
    FPCVersion := GetCompatibleFPCVersion(AVersion);
    RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;
    if RepositoryURL = '' then
      RepositoryURL := LAZARUS_OFFICIAL_REPO;

    LazarusInfo := Default(TLazarusInfo);
    LazarusInfo.Version := AVersion;
    LazarusInfo.FPCVersion := 'fpc-' + FPCVersion;
    LazarusInfo.InstallPath := InstallPath;
    LazarusInfo.SourceURL := RepositoryURL;
    LazarusInfo.Installed := True;

    Result := FConfigManager.GetLazarusManager.AddLazarusVersion('lazarus-' + AVersion, LazarusInfo);
    if not Result then
      LOut.WriteLn('SetupEnvironment: failed to add version to config');

  except
    on E: Exception do
    begin
      LOut.WriteLn('SetupEnvironment error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.CleanSourceArtifacts(const ASourceDir: string): Integer;
begin
  Result := CleanBuildArtifacts(ASourceDir, nil, True);
end;

function TLazarusManager.LaunchLazarusExecutable(const AExecutable: string): Boolean;
begin
  Result := TProcessExecutor.Launch(AExecutable, [], '');
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
      @RunConfigureIDEInstall
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

function TLazarusManager.UninstallVersion(const AVersion: string): Boolean;
begin
  Result := UninstallVersion(nil, nil, AVersion);
end;

function TLazarusManager.UninstallVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
var
  InstallPath: string;
  LazarusInfo: TLazarusInfo;
  HasMetadata: Boolean;
begin
  Result := False;

  if Outp = nil then;  // Unused parameter

  HasMetadata := FConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-' + AVersion, LazarusInfo);
  InstallPath := GetResolvedInstallPath(AVersion);

  if (not IsVersionInstalled(AVersion)) and
     (not DirectoryExists(InstallPath)) and
     (not HasMetadata) then
  begin
    Result := True;
    Exit;
  end;

  try
    // Delete install directory
    if DirectoryExists(InstallPath) then
      DeleteDirRecursive(InstallPath);

    // Remove from configuration
    FConfigManager.GetLazarusManager.RemoveLazarusVersion('lazarus-' + AVersion);

    Result := True;

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
  i: Integer;
  DefaultVersion: string;
  Line: string;
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

    DefaultVersion := FConfigManager.GetLazarusManager.GetDefaultLazarusVersion;
    if DefaultVersion <> '' then
      DefaultVersion := StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll]);

    if AShowAll then
    begin
      // No header needed for --all, just show versions
    end
    else
    begin
      LO.WriteLn(_(CMD_LAZARUS_LIST_HEADER));
      if Length(Versions) = 0 then
        LO.WriteLn(_(CMD_LAZARUS_LIST_EMPTY));
    end;


    for i := 0 to High(Versions) do
    begin
      Line := Format('%-8s  ', [Versions[i].Version]);

      if Versions[i].Installed then
      begin
        if SameText(Versions[i].Version, DefaultVersion) then
          Line := Line + 'Installed*  '
        else
          Line := Line + 'Installed   ';
      end
      else
        Line := Line + 'Available   ';

      Line := Line + Format('%-10s  ', [Versions[i].ReleaseDate]);
      Line := Line + Format('%-7s  ', [Versions[i].FPCVersion]);
      Line := Line + Versions[i].Branch;

      LO.WriteLn(Line);
    end;

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
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit;
  end;

  try
    Result := FConfigManager.GetLazarusManager.SetDefaultLazarusVersion('lazarus-' + AVersion);
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_LAZARUS_USE_SET, [AVersion]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_USE_FAILED));
    end;

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
  DefaultVersion: string;
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := '';

  try
    DefaultVersion := FConfigManager.GetLazarusManager.GetDefaultLazarusVersion;
    if DefaultVersion <> '' then
      Result := StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll]);

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
var
  SourcePlan: TLazarusSourcePlan;
  Git: ILazarusGitClient;
begin
  Result := False;

  SourcePlan := CreateLazarusSourcePlanCore(FInstallRoot, AVersion, GetCurrentVersion);
  if (SourcePlan.Version = '') or (not DirectoryExists(SourcePlan.SourceDir)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_SOURCE_DIR_NOT_FOUND, [SourcePlan.SourceDir]));
    Exit;
  end;
  if not IsValidSourceDirectory(SourcePlan.SourceDir) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_INVALID_SOURCE_DIR, [SourcePlan.SourceDir]));
    Exit;
  end;

  Git := CreateGitClient(False);
  Result := ExecuteLazarusUpdatePlanCore(SourcePlan, Outp, Errp, Git);
end;

function TLazarusManager.CreateGitClient(
  const ACliOnly: Boolean): ILazarusGitClient;
begin
  Result := TLazarusGitClient.Create(ACliOnly);
end;

function TLazarusManager.CleanSources(const AVersion: string): Boolean;
var
  SourcePlan: TLazarusSourcePlan;
  LOut: IOutput;
begin
  LOut := TConsoleOutput.Create(True) as IOutput;
  Result := False;

  SourcePlan := CreateLazarusSourcePlanCore(FInstallRoot, AVersion, GetCurrentVersion);
  if (SourcePlan.Version = '') or (not DirectoryExists(SourcePlan.SourceDir)) then
    Exit;
  if not IsValidSourceDirectory(SourcePlan.SourceDir) then
    Exit;

  Result := ExecuteLazarusCleanPlanCore(SourcePlan, LOut, @CleanSourceArtifacts);
end;

function TLazarusManager.ShowVersionInfo(const AVersion: string): Boolean;
begin
  Result := ShowVersionInfo(nil, AVersion);
end;

function TLazarusManager.ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean;
var
  LazarusInfo: TLazarusInfo;
  LO: IOutput;
  VersionInfo: TLazarusVersionInfo;
  i: Integer;
  AllVersions: TLazarusVersionArray;
  Found: Boolean;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    VersionInfo := Default(TLazarusVersionInfo);
    Found := False;

    // Get version info from releases database
    AllVersions := GetAvailableVersions;
    for i := 0 to High(AllVersions) do
    begin
      if SameText(AllVersions[i].Version, AVersion) then
      begin
        VersionInfo := AllVersions[i];
        Found := True;
        Break;
      end;
    end;

    if not Found then
    begin
      if not TryGetConfiguredVersionInfo(AVersion, VersionInfo) then
        Exit;
      Found := True;
    end;

    // Show basic version info
    LO.WriteLn(Format('Version:      %s', [VersionInfo.Version]));
    LO.WriteLn(Format('Release Date: %s', [VersionInfo.ReleaseDate]));
    LO.WriteLn(Format('Git Tag:      %s', [VersionInfo.GitTag]));
    LO.WriteLn(Format('Branch:       %s', [VersionInfo.Branch]));
      LO.WriteLn(Format('FPC Version:  %s', [VersionInfo.FPCVersion]));

    if IsVersionInstalled(AVersion) then
    begin
      LO.WriteLn(_(MSG_LAZARUS_STATUS_INSTALLED));
      LO.WriteLn(Format('Install Path: %s', [GetResolvedInstallPath(AVersion)]));
      if FConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-' + AVersion, LazarusInfo) then
      begin
        if LazarusInfo.SourceURL <> '' then
          LO.WriteLn(Format('Source URL:   %s', [LazarusInfo.SourceURL]));
      end;
    end
    else
      LO.WriteLn(_(MSG_LAZARUS_STATUS_NOT_INSTALLED));

    Result := True;

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
var
  LResult: TProcessResult;
  LazarusExe: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit;
  end;

  try
    LazarusExe := GetExecutablePathFromInstallPath(GetResolvedInstallPath(AVersion));

    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_LAZARUS_TEST_START, [AVersion]));

    LResult := TProcessExecutor.Execute(LazarusExe, ['--version'], '');
    Result := LResult.Success;

    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_LAZARUS_TEST_PASSED, [AVersion]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_Fmt(CMD_LAZARUS_TEST_FAILED, [AVersion]))
      else if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_LAZARUS_TEST_FAILED, [AVersion]));
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['testing installation', E.Message]));
      Result := False;
    end;
  end;
end;

function TLazarusManager.LaunchIDE(const AVersion: string): Boolean;
begin
  Result := LaunchIDE(nil, AVersion);
end;

function TLazarusManager.LaunchIDE(const Outp: IOutput; const AVersion: string): Boolean;
var
  LaunchPlan: TLazarusLaunchPlan;
begin
  Result := False;

  try
    LaunchPlan := CreateLazarusLaunchPlanCore(FInstallRoot, AVersion, GetCurrentVersion);
    if LaunchPlan.Version <> '' then
      LaunchPlan.ExecutablePath := GetExecutablePathFromInstallPath(
        GetResolvedInstallPath(LaunchPlan.Version)
      );
    Result := ExecuteLazarusLaunchPlanCore(
      LaunchPlan,
      Outp,
      @IsVersionInstalled,
      @LaunchLazarusExecutable
    );
  except
    on E: Exception do
    begin
      if Outp <> nil then
        Outp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['launching IDE', E.Message]));
      Result := False;
    end;
  end;
end;

function TLazarusManager.ConfigureIDE(const AVersion: string): Boolean;
begin
  Result := ConfigureIDE(nil, nil, AVersion);
end;

function TLazarusManager.RunConfigureIDEInstall(const Outp, Errp: IOutput;
  const AVersion: string): Boolean;
begin
  Result := ConfigureIDE(Outp, Errp, AVersion);
end;

function TLazarusManager.ConfigureIDE(const Outp, Errp: IOutput; const AVersion: string): Boolean;
var
  ConfigurePlan: TLazarusConfigurePlan;
  IDEConfig: TLazarusIDEConfig;
  Settings: TFPDevSettings;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if not IsVersionInstalled(AVersion) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit;
  end;

  try
    Settings := FConfigManager.GetSettingsManager.GetSettings;
    ConfigurePlan := CreateLazarusConfigurePlanCore(
      AVersion,
      GetResolvedInstallPath(AVersion),
      Settings.InstallRoot,
      GetCompatibleFPCVersion(AVersion),
      get_env('FPDEV_LAZARUS_CONFIG_ROOT'),
      get_env('HOME'),
      get_env('APPDATA')
    );

    IDEConfig := TLazarusIDEConfig.Create(ConfigurePlan.ConfigDir);
    try
      Result := ApplyLazarusConfigurePlanCore(ConfigurePlan, LO, LE, IDEConfig);
    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['IDE configuration', E.Message]));
      Result := False;
    end;
  end;
end;

end.
