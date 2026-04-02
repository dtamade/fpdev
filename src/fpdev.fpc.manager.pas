unit fpdev.fpc.manager;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.fpc.manager

FPC version management service


## Notice

If you redistribute or use this in your own project, please keep this project's copyright notice. Thanks.

fafafaStudio
Email:dtamade@gmail.com
QQ group: 685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, StrUtils, fpjson, jsonparser,
  fpdev.output.intf, fpdev.config, fpdev.config.interfaces, fpdev.fpc.source,
  fpdev.types, fpdev.fpc.types, fpdev.fpc.metadata, fpdev.resource.repo, fpdev.utils.fs, fpdev.utils.process,
  fpdev.git.runtime, fpdev.i18n, fpdev.i18n.strings,
  fpdev.fpc.activation, fpdev.fpc.validator, fpdev.fpc.version, fpdev.fpc.installer,
  fpdev.fpc.installer.environmentflow, fpdev.fpc.installversionflow,
  fpdev.fpc.runtimeflow,
  fpdev.fpc.builder, fpdev.fpc.verify,
  fpdev.build.cache, fpdev.paths;

type
  { TFPCManager }
  TFPCManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;  // Resource repository manager
    FActivationMgr: TFPCActivationManager;  // Activation service (Facade delegation)
    FValidatorMgr: TFPCValidator;  // Validation service (Facade delegation)
    FVersionMgr: TFPCVersionManager;  // Version service (Facade delegation)
    FInstallerMgr: TFPCBinaryInstaller;  // Binary installation service (Facade delegation)
    FBuilderMgr: TFPCSourceBuilder;  // Source build service (Facade delegation)
    FBuildCache: TBuildCache;  // Build artifact cache for fast version switching

    FOut: IOutput;
    FErr: IOutput;

    function DownloadSource(const AVersion, ATargetDir: string): Boolean;
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function SourceDirExists(const APath: string): Boolean;
    function CleanSourceArtifacts(const ASourceDir: string): Integer;
    function LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
    function ExecuteInstalledFPCInfo(const AExecutable: string): TProcessResult;
    procedure EnsureManagedCompilerLayout(const AVersion, AInstallPath: string);
    function ResolveMetadataScope(const AVersion, AInstallPath: string): TInstallScope;
    function WriteInstallMetadata(const AVersion, AInstallPath: string;
      AFromSource: Boolean): Boolean;
    function UpdateVerificationMetadata(const AVersion, AInstallPath: string;
      const AVerifResult: TVerificationResult): Boolean;
    function RefreshInstallVerificationMetadata(const AVersion,
      AInstallPath: string): Boolean;

    // Bootstrap compiler management (delegated to FBuilderMgr)
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetCurrentFPCVersion: string;
    function GetBootstrapCompilerPath(const AVersion: string): string;
    function IsBootstrapAvailable(const AVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
    function VerifyInstalledExecutableVersion(const AFPCExe, AVersion: string;
      out AError: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager; const AOut: IOutput = nil; const AErr: IOutput = nil);
    destructor Destroy; override;

    // Version management
    function GetAvailableVersions: TFPCVersionArray;
    function GetInstalledVersions: TFPCVersionArray;
    function InstallVersion(
      const AVersion: string;
      const AFromSource: Boolean = False;
      const APrefix: string = '';
      const AEnsure: Boolean = False;
      const ANoCache: Boolean = False
    ): Boolean;
    function UninstallVersion(const AVersion: string): Boolean;
    function ListVersions(const AShowAll: Boolean = False): Boolean; overload;
    function ListVersions(const Outp: IOutput; const AShowAll: Boolean = False): Boolean; overload;
    function SetDefaultVersion(const AVersion: string): Boolean; overload;
    function SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function GetCurrentVersion: string;
    function ActivateVersion(const AVersion: string): TActivationResult;

    // Binary installation
    function GetBinaryDownloadURL(const AVersion: string): string;
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
    function GetBinaryDownloadURLLegacy(const AVersion: string): string;
    function DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
    function VerifyChecksum(const AFilePath, AVersion: string): Boolean;
    function AddToolchainToConfig(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
    function InstallFromBinary(const AVersion: string; const APrefix: string = ''): Boolean;

    // Source management
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // Toolchain operations
    function ShowVersionInfo(const AVersion: string): Boolean; overload;
    function ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean; overload;
    function TestInstallation(const AVersion: string): Boolean; overload;
    function TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;

    // Metadata operations (public for testing)
    function WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
    function ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;

    // Environment setup (public for cache restore)
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
  end;

// Export index update procedure for subcommands to call
procedure FPC_UpdateIndex(const AConfigPath: string = '');

implementation

uses
  fpdev.output.console, fpdev.version.registry, fpdev.fpc.installer.config;

type
  TFPCGitRuntimeAdapter = class(TInterfacedObject, IFPCGitRuntime)
  private
    FGit: IGitRuntime;
  public
    constructor Create(const AGit: IGitRuntime = nil);
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

constructor TFPCGitRuntimeAdapter.Create(const AGit: IGitRuntime);
begin
  inherited Create;
  if AGit <> nil then
    FGit := AGit
  else
    FGit := TGitRuntime.Create;
end;

function TFPCGitRuntimeAdapter.BackendAvailable: Boolean;
begin
  Result := (FGit <> nil) and FGit.BackendAvailable;
end;

function TFPCGitRuntimeAdapter.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TFPCGitRuntimeAdapter.HasRemote(const APath: string): Boolean;
begin
  Result := FGit.HasRemote(APath);
end;

function TFPCGitRuntimeAdapter.Pull(const APath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(APath);
end;

function TFPCGitRuntimeAdapter.GetLastError: string;
begin
  Result := FGit.LastError;
end;

procedure SafeWriteAllText(const APath, AText: string);
var
  Dir: string;
  L: TStringList;
begin
  Dir := ExtractFileDir(APath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    EnsureDir(Dir);
  L := TStringList.Create;
  try
    L.Text := AText;
    L.SaveToFile(APath);
  finally
    L.Free;
  end;
end;

function ReadAllTextIfExists(const APath: string): string;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(APath) then Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(APath);
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

var
  FPDEV_LOGFILE: string = '';

procedure LogLine(const S: string);
begin
  if FPDEV_LOGFILE <> '' then
  begin
    try
      with TStringList.Create do
      try
        if FileExists(FPDEV_LOGFILE) then
          LoadFromFile(FPDEV_LOGFILE);
        Add(S);
        SaveToFile(FPDEV_LOGFILE);
      finally
        Free;
      end;
    except
      // Ignore log write exceptions
    end;
  end;
end;


function TryParseInt(const S: string; out N: Integer): Boolean;
var
  Code: Integer;
begin
  Val(S, N, Code);
  Result := Code = 0;
end;

procedure ParseVersion(const Ver: string; out A, B, C: Integer);
var
  i, p1, p2: Integer;
  s: string;
begin
  A := 0; B := 0; C := 0;
  s := Ver;
  p1 := Pos('.', s);
  if p1 > 0 then
  begin
    if not TryParseInt(Copy(s, 1, p1-1), A) then A := 0;
    Delete(s, 1, p1);
    p2 := Pos('.', s);
    if p2 > 0 then
    begin
      if not TryParseInt(Copy(s, 1, p2-1), B) then B := 0;
      Delete(s, 1, p2);
      // Rest is patch (may contain suffix, take numeric prefix)
      i := 1;
      while (i <= Length(s)) and (s[i] in ['0'..'9']) do Inc(i);
      if i > 1 then
        if not TryParseInt(Copy(s, 1, i-1), C) then C := 0;
    end
    else
    begin
      if not TryParseInt(s, B) then B := 0;
    end;
  end
  else
  begin
    TryParseInt(s, A);
  end;
end;

function CompareSemVer(const V1, V2: string): Integer;
var
  a1,b1,c1,a2,b2,c2: Integer;
begin
  ParseVersion(V1, a1,b1,c1);
  ParseVersion(V2, a2,b2,c2);
  if a1 <> a2 then Exit(Ord(a1 > a2) - Ord(a1 < a2));
  if b1 <> b2 then Exit(Ord(b1 > b2) - Ord(b1 < b2));
  if c1 <> c2 then Exit(Ord(c1 > c2) - Ord(c1 < c2));
  Result := 0;
end;

function SameMajorMinor(const V1, V2: string): Boolean;
var
  a1,b1,c1,a2,b2,c2: Integer;
begin
  ParseVersion(V1, a1,b1,c1);
  ParseVersion(V2, a2,b2,c2);
  Result := (a1=a2) and (b1=b2);
end;

// --- FPC command helpers (no inline vars) ----------------------------------

procedure FPC_UpdateIndex(const AConfigPath: string);
var
  Cfg: TFPDevConfigManager;
  S: TStringList;
  CacheDir, IndexPath, NowIso, Channel: string;
  i: Integer;
  Releases: TFPCReleaseArray;
begin
  LogLine('[update] begin');
  Cfg := TFPDevConfigManager.Create(AConfigPath);
  try
    Cfg.LoadConfig;
    CacheDir := Cfg.GetSettings.InstallRoot + PathDelim + 'cache' + PathDelim + 'fpc';
    EnsureDir(CacheDir);
    IndexPath := CacheDir + PathDelim + 'index.json';
    NowIso := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', Now);
    Releases := TVersionRegistry.Instance.GetFPCReleases;
    S := TStringList.Create;
    try
      S.Add('{');
      S.Add('  "version": "1",');
      S.Add('  "updated_at": "' + NowIso + '",');
      S.Add('  "items": [');
      for i := 0 to High(Releases) do
      begin
        Channel := Releases[i].Channel;
        S.Add('    {');
        S.Add('      "version": "' + Releases[i].Version + '",');
        S.Add('      "tag": "' + Releases[i].GitTag + '",');
        S.Add('      "branch": "' + Releases[i].Branch + '",');
        S.Add('      "channel": "' + Channel + '"');
        if i < High(Releases) then S.Add('    },') else S.Add('    }');
      end;
      S.Add('  ]');
      S.Add('}');
      S.SaveToFile(IndexPath);
      LogLine('[update] index: ' + IndexPath);
    finally
      S.Free;
    end;
  finally
    Cfg.Free;
  end;
  LogLine('[update] done');
end;


{ TFPCManager }

constructor TFPCManager.Create(AConfigManager: IConfigManager; const AOut: IOutput; const AErr: IOutput);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;  // Lazy initialization

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := ExcludeTrailingPathDelimiter(Trim(Settings.InstallRoot));

  // Ensure InstallRoot is resolved before creating sub-services that snapshot it.
  if FInstallRoot = '' then
  begin
    FInstallRoot := ExcludeTrailingPathDelimiter(GetDataRoot);
    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  // Ensure the install directory exists
  if not DirectoryExists(FInstallRoot) then
    EnsureDir(FInstallRoot);

  // Initialize build cache
  FBuildCache := TBuildCache.Create(BuildBuildCacheDirFromInstallRoot(FInstallRoot));

  // Create facade services (after InstallRoot is resolved)
  FActivationMgr := TFPCActivationManager.Create(AConfigManager);  // Activation service
  FValidatorMgr := TFPCValidator.Create(AConfigManager);  // Validation service
  FVersionMgr := TFPCVersionManager.Create(AConfigManager);  // Version service
  FInstallerMgr := TFPCBinaryInstaller.Create(AConfigManager, FOut, FErr);  // Installer service
  FBuilderMgr := TFPCSourceBuilder.Create(AConfigManager, FOut, FErr);  // Builder service

  // Pass cache instance to installer for binary caching
  FInstallerMgr.SetCache(FBuildCache);
end;

destructor TFPCManager.Destroy;
begin
  if Assigned(FBuildCache) then
    FBuildCache.Free;
  if Assigned(FBuilderMgr) then
    FBuilderMgr.Free;
  if Assigned(FInstallerMgr) then
    FInstallerMgr.Free;
  if Assigned(FVersionMgr) then
    FVersionMgr.Free;
  if Assigned(FValidatorMgr) then
    FValidatorMgr.Free;
  if Assigned(FActivationMgr) then
    FActivationMgr.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TFPCManager.WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
begin
  Result := WriteFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': WriteMetadata failed');
end;

function TFPCManager.ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
begin
  Result := ReadFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': ReadMetadata failed');
end;

function TFPCManager.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := FVersionMgr.GetVersionInstallPath(AVersion);
end;

function TFPCManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := FVersionMgr.IsVersionInstalled(AVersion);
end;

function TFPCManager.ValidateVersion(const AVersion: string): Boolean;
begin
  // Delegate to version manager service
  Result := FVersionMgr.ValidateVersion(AVersion);
end;

function TFPCManager.GetAvailableVersions: TFPCVersionArray;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetAvailableVersions;
end;

function TFPCManager.GetInstalledVersions: TFPCVersionArray;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetInstalledVersions;
end;

function TFPCManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.DownloadSource(AVersion, ATargetDir);
end;

{ Bootstrap Compiler Management }

function TFPCManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetRequiredBootstrapVersion(ATargetVersion);
end;

function TFPCManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
begin
  Result := FBuilderMgr.EnsureBootstrapCompiler(ATargetVersion);
  if Result then
    Exit;

  if Assigned(FInstallerMgr) then
  begin
    FOut.WriteLn('Attempting binary bootstrap fallback for FPC ' + ATargetVersion + '...');
    if FInstallerMgr.InstallFromBinary(ATargetVersion) then
    begin
      FOut.WriteLn('Binary bootstrap fallback installed FPC ' + ATargetVersion);
      Result := FBuilderMgr.EnsureBootstrapCompiler(ATargetVersion);
    end;
  end;
end;

function TFPCManager.GetCurrentFPCVersion: string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetCurrentFPCVersion;
end;

function TFPCManager.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  // Delegate to builder service
  Result := FBuilderMgr.GetBootstrapCompilerPath(AVersion);
end;

function TFPCManager.IsBootstrapAvailable(const AVersion: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.IsBootstrapAvailable(AVersion);
end;

function TFPCManager.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
begin
  // Delegate to builder service
  Result := FBuilderMgr.BuildFromSource(ASourceDir, AInstallDir);
end;

function TFPCManager.SourceDirExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

function TFPCManager.CleanSourceArtifacts(const ASourceDir: string): Integer;
begin
  Result := CleanBuildArtifacts(ASourceDir, nil, True);
end;

function TFPCManager.LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.GetToolchain('fpc-' + AVersion, AInfo);
end;

function TFPCManager.ExecuteInstalledFPCInfo(const AExecutable: string): TProcessResult;
begin
  Result := TProcessExecutor.Execute(AExecutable, ['-i'], '');
end;

function TFPCManager.VerifyInstalledExecutableVersion(const AFPCExe, AVersion: string;
  out AError: string): Boolean;
var
  Verifier: TFPCVerifier;
begin
  AError := '';
  Verifier := TFPCVerifier.Create;
  try
    Result := Verifier.VerifyVersion(AFPCExe, AVersion);
    if not Result then
      AError := Verifier.GetLastError;
  finally
    Verifier.Free;
  end;
end;

procedure TFPCManager.EnsureManagedCompilerLayout(const AVersion, AInstallPath: string);
begin
  EnsureManagedFPCInstallLayout(AInstallPath, AVersion, FOut);
end;

function TFPCManager.ResolveMetadataScope(const AVersion, AInstallPath: string): TInstallScope;
var
  ExpectedInstallPath: string;
  NormalizedInstallPath: string;
begin
  Result := isUser;

  NormalizedInstallPath := ExcludeTrailingPathDelimiter(ExpandFileName(AInstallPath));
  ExpectedInstallPath := ExcludeTrailingPathDelimiter(
    ExpandFileName(GetVersionInstallPath(AVersion))
  );

  if SameText(NormalizedInstallPath, ExpectedInstallPath) then
    Result := FActivationMgr.DetectInstallScope(GetCurrentDir);
end;

function TFPCManager.WriteInstallMetadata(const AVersion, AInstallPath: string;
  AFromSource: Boolean): Boolean;
var
  Meta: TFPDevMetadata;
  ReleaseInfo: TFPCReleaseInfo;
begin
  Result := False;

  try
    Meta := Default(TFPDevMetadata);
    Meta.Version := AVersion;
    Meta.Scope := ResolveMetadataScope(AVersion, AInstallPath);
    if AFromSource then
      Meta.SourceMode := smSource
    else
      Meta.SourceMode := smBinary;
    ReleaseInfo := TVersionRegistry.Instance.GetFPCRelease(AVersion);
    Meta.Channel := ReleaseInfo.Channel;
    Meta.Prefix := ExpandFileName(AInstallPath);
    Meta.Origin.BuiltFromSource := AFromSource;
    if AFromSource then
      Meta.Origin.RepoURL := TVersionRegistry.Instance.GetFPCRepository;
    Meta.InstalledAt := Now;

    Result := WriteFPCMetadata(AInstallPath, Meta);
    if not Result then
      FErr.WriteLn('Warning: Failed to write installation metadata');
  except
    on E: Exception do
    begin
      FErr.WriteLn('Warning: Failed to write installation metadata - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.UpdateVerificationMetadata(const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult): Boolean;
var
  Meta: TFPDevMetadata;
  ReleaseInfo: TFPCReleaseInfo;
  MetaLoaded: Boolean;
begin
  Result := False;

  if not DirectoryExists(AInstallPath) then
    Exit(False);

  try
    MetaLoaded := ReadFPCMetadata(AInstallPath, Meta);
    if not MetaLoaded then
      Meta := Default(TFPDevMetadata);

    ReleaseInfo := TVersionRegistry.Instance.GetFPCRelease(AVersion);

    if Meta.Version = '' then
      Meta.Version := AVersion;
    if not MetaLoaded then
      Meta.Scope := ResolveMetadataScope(AVersion, AInstallPath);
    if Meta.Channel = '' then
      Meta.Channel := ReleaseInfo.Channel;
    if Meta.Prefix = '' then
      Meta.Prefix := ExpandFileName(AInstallPath);
    if Meta.InstalledAt = 0 then
      Meta.InstalledAt := Now;

    Meta.Verify.Timestamp := Now;
    Meta.Verify.OK := AVerifResult.Verified;
    Meta.Verify.DetectedVersion := AVerifResult.DetectedVersion;
    Meta.Verify.SmokeTestPassed := AVerifResult.SmokeTestPassed;

    Result := WriteFPCMetadata(AInstallPath, Meta);
    if not Result then
      FErr.WriteLn('Warning: Failed to update verification metadata');
  except
    on E: Exception do
    begin
      FErr.WriteLn('Warning: Failed to update verification metadata - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.RefreshInstallVerificationMetadata(const AVersion,
  AInstallPath: string): Boolean;
var
  Verifier: TFPCVerifier;
  VerifResult: TVerificationResult;
  FPCExe: string;
begin
  Result := False;

  if not DirectoryExists(AInstallPath) then
    Exit(False);

  Initialize(VerifResult);
  FPCExe := BuildFPCInstalledExecutablePathCore(AInstallPath);
  VerifResult.ExecutableExists := FileExists(FPCExe);

  if not VerifResult.ExecutableExists then
  begin
    FErr.WriteLn('Warning: Post-install verification skipped - FPC executable not found: ' + FPCExe);
    UpdateVerificationMetadata(AVersion, AInstallPath, VerifResult);
    Exit(False);
  end;

  Verifier := TFPCVerifier.Create;
  try
    if not Verifier.VerifyVersion(FPCExe, AVersion) then
    begin
      VerifResult.ErrorMessage := Verifier.GetLastError;
      FErr.WriteLn('Warning: Post-install version verification failed - ' +
        VerifResult.ErrorMessage);
    end
    else
    begin
      VerifResult.DetectedVersion := AVersion;
      if not Verifier.CompileHelloWorld(FPCExe) then
      begin
        VerifResult.ErrorMessage := Verifier.GetLastError;
        FErr.WriteLn('Warning: Post-install smoke test failed - ' +
          VerifResult.ErrorMessage);
      end
      else
      begin
        VerifResult.SmokeTestPassed := True;
        VerifResult.Verified := True;
        Result := True;
      end;
    end;
  finally
    Verifier.Free;
  end;

  UpdateVerificationMetadata(AVersion, AInstallPath, VerifResult);
end;

function TFPCManager.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
var
  InstallPath: string;
begin
  if AInstallPath <> '' then
    InstallPath := AInstallPath
  else
    InstallPath := GetVersionInstallPath(AVersion);

  try
    if not EnsureManagedFPCInstallLayout(InstallPath, AVersion, FOut) then
      Exit(False);
    Result := ExecuteFPCEnvironmentRegistrationFlow(AVersion, InstallPath, FErr,
      @AddToolchainToConfig);
  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': SetupEnvironment failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.AddToolchainToConfig(const AName: string; const AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.AddToolchain(AName, AInfo);
end;

function TFPCManager.InstallVersion(
  const AVersion: string;
  const AFromSource: Boolean;
  const APrefix: string;
  const AEnsure: Boolean;
  const ANoCache: Boolean
): Boolean;
var
  InstallPath: string;
  HasCachedArtifacts: TFPCInstallHasArtifactsFunc;
  RestoreCachedArtifacts: TFPCInstallRestoreArtifactsFunc;
  SaveBuildArtifacts: TFPCInstallSaveArtifactsFunc;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    FErr.WriteLn(_Fmt(ERR_INVALID_VERSION, [AVersion]));
    Exit;
  end;

  HasCachedArtifacts := nil;
  RestoreCachedArtifacts := nil;
  SaveBuildArtifacts := nil;
  if Assigned(FBuildCache) then
  begin
    HasCachedArtifacts := @FBuildCache.HasArtifacts;
    RestoreCachedArtifacts := @FBuildCache.RestoreArtifacts;
    SaveBuildArtifacts := @FBuildCache.SaveArtifacts;
  end;

  try
    if Assigned(FInstallerMgr) then
      FInstallerMgr.SetNoCache(ANoCache);

    InstallPath := ResolveFPCInstallPathCore(APrefix, GetVersionInstallPath(AVersion));
    Result := ExecuteFPCInstallVersionCore(
      AVersion,
      FInstallRoot,
      GetVersionInstallPath(AVersion),
      APrefix,
      AFromSource,
      AEnsure,
      IsVersionInstalled(AVersion),
      not ANoCache,
      FOut,
      FErr,
      @VerifyInstalledExecutableVersion,
      HasCachedArtifacts,
      RestoreCachedArtifacts,
      SaveBuildArtifacts,
      @DownloadSource,
      @EnsureBootstrapCompiler,
      @BuildFromSource,
      @WriteInstallMetadata,
      @SetupEnvironment,
      @InstallFromBinary
    );

    if Result then
      RefreshInstallVerificationMetadata(AVersion, InstallPath);
  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': InstallVersion failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.UninstallVersion(const AVersion: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);

    // Delete installation directory
    if DirectoryExists(InstallPath) then
      DeleteDirRecursive(InstallPath);

    // Remove from configuration
    FConfigManager.GetToolchainManager.RemoveToolchain('fpc-' + AVersion);

    Result := True;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': UninstallVersion failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.ListVersions(const AShowAll: Boolean): Boolean;
begin
  Result := ListVersions(nil, AShowAll);
end;

function TFPCManager.ListVersions(const Outp: IOutput; const AShowAll: Boolean): Boolean;
var
  Versions: TFPCVersionArray;
  i: Integer;
  DefaultVersion: string;
  Line: string;
begin
  Result := True;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;

    DefaultVersion := FConfigManager.GetToolchainManager.GetDefaultToolchain;
    if DefaultVersion <> '' then
      DefaultVersion := StringReplace(DefaultVersion, 'fpc-', '', [rfReplaceAll]);

    if AShowAll then
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_LIST_ALL_HEADER))
      else
        FOut.WriteLn(_(CMD_FPC_LIST_ALL_HEADER));
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_LIST_HEADER))
      else
        FOut.WriteLn(_(CMD_FPC_LIST_HEADER));
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
      Line := Line + Versions[i].Branch;

      if Outp <> nil then
        Outp.WriteLn(Line)
      else
        FOut.WriteLn(Line);
    end;

    if DefaultVersion <> '' then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [DefaultVersion]))
      else
        FOut.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [DefaultVersion]));
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_CURRENT_NONE))
      else
        FOut.WriteLn(_(CMD_FPC_CURRENT_NONE));
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := SetDefaultVersion(nil, nil, AVersion);
end;

function TFPCManager.SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_Fmt(CMD_FPC_USE_NOT_FOUND, [AVersion]));
    Exit;
  end;

  try
    Result := FConfigManager.GetToolchainManager.SetDefaultToolchain('fpc-' + AVersion);
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_FPC_USE_ACTIVATED, [AVersion]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_FAILED) + ': set default version');
    end;

  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.GetCurrentVersion: string;
begin
  // Delegate to version manager service
  Result := FVersionMgr.GetCurrentVersion;
end;

function TFPCManager.ActivateVersion(const AVersion: string): TActivationResult;
var
  InstallPath, BinPath: string;
begin
  // Initialize result
  Initialize(Result);
  Result.Success := False;

  // Check if version is installed
  if not IsVersionInstalled(AVersion) then
  begin
    Result.ErrorMessage := 'FPC version ' + AVersion + ' is not installed';
    Exit;
  end;

  // Get install path and bin path
  InstallPath := GetVersionInstallPath(AVersion);
  BinPath := InstallPath + PathDelim + 'bin';

  // Delegate to activation manager service
  Result := FActivationMgr.ActivateVersion(AVersion, BinPath);
  if not Result.Success then
    Exit;

  // Set as default version
  if not SetDefaultVersion(AVersion) then
  begin
    Result.ErrorMessage := 'Failed to set default version';
    Result.Success := False;
    Exit;
  end;
end;

function TFPCManager.UpdateSources(const AVersion: string): Boolean;
var
  Plan: TFPCSourcePlan;
  GitRuntime: IFPCGitRuntime;
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := GetCurrentVersion;
  Plan := CreateFPCSourcePlanCore(FInstallRoot, Version);
  GitRuntime := TFPCGitRuntimeAdapter.Create;
  Result := ExecuteFPCUpdatePlanCore(Plan, FOut, FErr, @SourceDirExists, GitRuntime);
end;

function TFPCManager.CleanSources(const AVersion: string): Boolean;
var
  Plan: TFPCSourcePlan;
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := GetCurrentVersion;
  Plan := CreateFPCSourcePlanCore(FInstallRoot, Version);
  Result := ExecuteFPCCleanPlanCore(Plan, FOut, FErr, @SourceDirExists, @CleanSourceArtifacts);
end;

function TFPCManager.ShowVersionInfo(const AVersion: string): Boolean;
begin
  Result := ShowVersionInfo(nil, AVersion);
end;

function TFPCManager.ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean;
var
  InfoOut: IOutput;
  ErrorOut: IOutput;
begin
  if Outp <> nil then
  begin
    InfoOut := Outp;
    ErrorOut := Outp;
  end
  else
  begin
    InfoOut := FOut;
    ErrorOut := FErr;
  end;

  Result := ExecuteFPCShowVersionInfoCore(
    AVersion, InfoOut, ErrorOut,
    @ValidateVersion, @IsVersionInstalled, @GetVersionInstallPath, @LookupToolchainInfo
  );
end;

function TFPCManager.TestInstallation(const AVersion: string): Boolean;
begin
  Result := TestInstallation(nil, nil, AVersion);
end;

function TFPCManager.TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Result := ExecuteFPCTestInstallationCore(
    AVersion, Outp, Errp, @IsVersionInstalled, @GetVersionInstallPath, @ExecuteInstalledFPCInfo
  );
end;

function TFPCManager.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
var
  InstallPath: string;
begin
  // Delegate to validator service
  Result := FValidatorMgr.VerifyInstallation(AVersion, VerifResult);

  InstallPath := ResolveInstalledFPCInstallPathCore(
    GetVersionInstallPath(AVersion),
    AVersion
  );
  if DirectoryExists(InstallPath) then
    UpdateVerificationMetadata(AVersion, InstallPath, VerifResult);
end;

// ============================================================================
// Binary Installation Methods - Delegated to FInstallerMgr
// ============================================================================

function TFPCManager.GetBinaryDownloadURL(const AVersion: string): string;
begin
  Result := FInstallerMgr.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCManager.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstallerMgr.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCManager.GetBinaryDownloadURLLegacy(const AVersion: string): string;
begin
  Result := FInstallerMgr.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCManager.DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstallerMgr.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCManager.VerifyChecksum(const AFilePath, AVersion: string): Boolean;
begin
  Result := FInstallerMgr.VerifyChecksum(AFilePath, AVersion);
end;

function TFPCManager.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
begin
  Result := FInstallerMgr.ExtractArchive(AArchivePath, ADestPath);
end;

function TFPCManager.InstallFromBinary(const AVersion: string; const APrefix: string): Boolean;
begin
  Result := FInstallerMgr.InstallFromBinary(AVersion, APrefix);
end;

end.
