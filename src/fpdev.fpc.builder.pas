unit fpdev.fpc.builder;

{
================================================================================
  fpdev.fpc.builder - FPC Source Builder Service
================================================================================

  Provides FPC source code download and compilation capabilities:
  - Download FPC source from GitLab
  - Manage bootstrap compilers
  - Build FPC from source
  - Handle build dependencies

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    Builder := TFPCSourceBuilder.Create(ConfigManager);
    try
      if Builder.EnsureBootstrapCompiler('3.2.2') then
        if Builder.DownloadSource('3.2.2', SourceDir) then
          if Builder.BuildFromSource(SourceDir, InstallDir) then
            WriteLn('Build complete');
    finally
      Builder.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils.git, fpdev.resource.repo, fpdev.constants;

type
  { Bootstrap compiler requirements }
  TBootstrapRequirement = record
    TargetVersion: string;
    RequiredVersion: string;
  end;

  { TFPCSourceBuilder - FPC source compilation service }
  TFPCSourceBuilder = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;
    FOut: IOutput;
    FErr: IOutput;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;

    { Gets the current FPC version from system PATH. }
    function GetCurrentFPCVersion: string;

    { Gets path to bootstrap compiler for a version. }
    function GetBootstrapCompilerPath(const AVersion: string): string;

    { Checks if bootstrap compiler is locally available. }
    function IsBootstrapAvailable(const AVersion: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager;
      AOut: IOutput = nil; AErr: IOutput = nil);
    destructor Destroy; override;

    { Gets the required bootstrap compiler version for building a target version.
      ATargetVersion: FPC version to build
      Returns: Required bootstrap version or empty string if none required }
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;

    { Ensures a bootstrap compiler is available for building the target version.
      Downloads from fpdev-repo if needed.
      ATargetVersion: FPC version to build
      Returns: True if bootstrap compiler is available }
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    { Downloads FPC source code from GitLab.
      AVersion: FPC version to download
      ATargetDir: Directory to clone to
      Returns: True if download succeeded }
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;

    { Builds FPC from source code.
      ASourceDir: Directory containing FPC source
      AInstallDir: Installation destination
      Returns: True if build succeeded }
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;

    { Resource repository accessor for external coordination. }
    property ResourceRepo: TResourceRepository read FResourceRepo;
  end;

const
  { Bootstrap compiler requirements for building from source }
  FPC_BOOTSTRAP_REQUIREMENTS: array[0..2] of TBootstrapRequirement = (
    (TargetVersion: '3.2.2'; RequiredVersion: '3.2.0'),
    (TargetVersion: '3.2.0'; RequiredVersion: '3.0.4'),
    (TargetVersion: '3.0.4'; RequiredVersion: '3.0.2')
  );

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.output.console, fpdev.fpc.version,
  fpdev.version.registry;

{ TFPCSourceBuilder }

constructor TFPCSourceBuilder.Create(AConfigManager: IConfigManager;
  AOut: IOutput; AErr: IOutput);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + FPDEV_CONFIG_DIR;
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + FPDEV_CONFIG_DIR;
    {$ENDIF}
  end;
end;

destructor TFPCSourceBuilder.Destroy;
begin
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TFPCSourceBuilder.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := FInstallRoot + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function TFPCSourceBuilder.GetCurrentFPCVersion: string;
var
  LResult: TProcessResult;
begin
  Result := '';
  try
    LResult := TProcessExecutor.Execute('fpc', ['-iV'], '');
    if LResult.Success then
      Result := Trim(LResult.StdOut);
  except
    Result := '';
  end;
end;

function TFPCSourceBuilder.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
            FPDEV_CONFIG_DIR + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  Result := IncludeTrailingPathDelimiter(GetUserDir) +
            FPDEV_CONFIG_DIR + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
end;

function TFPCSourceBuilder.IsBootstrapAvailable(const AVersion: string): Boolean;
var
  BootstrapPath: string;
begin
  BootstrapPath := GetBootstrapCompilerPath(AVersion);
  Result := FileExists(BootstrapPath);
end;

function TFPCSourceBuilder.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
var
  i: Integer;
begin
  Result := '';

  // First try to use resource repository
  if not Assigned(FResourceRepo) then
  begin
    FResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
    if DirectoryExists(CreateDefaultConfig.LocalPath) then
      FResourceRepo.LoadManifest;
  end;

  if Assigned(FResourceRepo) then
  begin
    Result := FResourceRepo.GetRequiredBootstrapVersion(ATargetVersion);
    if Result <> '' then
      Exit;
  end;

  // Fallback to hardcoded requirements
  for i := 0 to High(FPC_BOOTSTRAP_REQUIREMENTS) do
  begin
    if SameText(FPC_BOOTSTRAP_REQUIREMENTS[i].TargetVersion, ATargetVersion) then
    begin
      Result := FPC_BOOTSTRAP_REQUIREMENTS[i].RequiredVersion;
      Break;
    end;
  end;
end;

function TFPCSourceBuilder.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  RequiredVersion: string;
  BestVersion: string;
  CurrentVersion: string;
  BootstrapPath: string;
  Platform: string;
begin
  Result := False;
  Platform := GetCurrentPlatform;

  RequiredVersion := GetRequiredBootstrapVersion(ATargetVersion);
  if RequiredVersion = '' then
  begin
    FOut.WriteLn('Note: No specific bootstrap compiler required for ' + ATargetVersion);
    Result := True;
    Exit;
  end;

  FOut.WriteLn('Target FPC version ' + ATargetVersion + ' requires bootstrap compiler ' + RequiredVersion);

  // Check if current system FPC matches
  CurrentVersion := GetCurrentFPCVersion;
  if CurrentVersion <> '' then
  begin
    FOut.WriteLn('Current system FPC version: ' + CurrentVersion);
    if SameText(CurrentVersion, RequiredVersion) then
    begin
      FOut.WriteLn('OK: System FPC version matches required bootstrap version');
      Result := True;
      Exit;
    end;
  end
  else
    FOut.WriteLn('No system FPC compiler found');

  // Check if we have the bootstrap compiler downloaded
  if IsBootstrapAvailable(RequiredVersion) then
  begin
    BootstrapPath := GetBootstrapCompilerPath(RequiredVersion);
    FOut.WriteLn('OK: Bootstrap compiler available at: ' + BootstrapPath);
    Result := True;
    Exit;
  end;

  // Try to download from resource repository
  FOut.WriteLn('Bootstrap compiler ' + RequiredVersion + ' not found locally');
  FOut.WriteLn('Attempting to download from resource repository...');
  FOut.WriteLn;

  if not Assigned(FResourceRepo) then
  begin
    FResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
    if not FResourceRepo.Initialize then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_REPO_INIT_FAILED));
      FResourceRepo.Free;
      FResourceRepo := nil;
    end;
  end;

  if Assigned(FResourceRepo) then
  begin
    if FResourceRepo.HasBootstrapCompiler(RequiredVersion, Platform) then
    begin
      FOut.WriteLn('OK: Bootstrap compiler ' + RequiredVersion + ' found in resource repository');
      BootstrapPath := GetBootstrapCompilerPath(RequiredVersion);

      if FResourceRepo.InstallBootstrap(RequiredVersion, Platform, ExtractFileDir(BootstrapPath)) then
      begin
        FOut.WriteLn('OK: Bootstrap compiler downloaded and installed successfully');
        FOut.WriteLn('  Location: ' + BootstrapPath);
        Result := True;
        Exit;
      end
      else
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BOOTSTRAP_INSTALL_FAILED, ['from repository']));
    end
    else
    begin
      FOut.WriteLn('Exact version ' + RequiredVersion + ' not available, searching for alternatives...');
      BestVersion := FResourceRepo.FindBestBootstrapVersion(ATargetVersion, Platform);

      if BestVersion <> '' then
      begin
        FOut.WriteLn('OK: Found alternative bootstrap compiler: ' + BestVersion);
        BootstrapPath := GetBootstrapCompilerPath(BestVersion);

        if FResourceRepo.InstallBootstrap(BestVersion, Platform, ExtractFileDir(BootstrapPath)) then
        begin
          FOut.WriteLn('OK: Bootstrap compiler ' + BestVersion + ' installed successfully');
          FOut.WriteLn('  Location: ' + BootstrapPath);
          Result := True;
          Exit;
        end
        else
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BOOTSTRAP_INSTALL_FAILED, [BestVersion]));
      end
      else
        FErr.WriteLn('No bootstrap compiler available for platform ' + Platform);
    end;
  end;

  // All methods failed - show manual instructions
  FErr.WriteLn;
  FErr.WriteLn('Unable to automatically download bootstrap compiler.');
  FErr.WriteLn('To build FPC ' + ATargetVersion + ' from source, you need FPC ' + RequiredVersion);
  FErr.WriteLn;
  FErr.WriteLn('Options:');
  FErr.WriteLn('  1. Install FPC ' + RequiredVersion + ' system-wide');
  FErr.WriteLn('  2. Contact maintainer to add bootstrap compiler to resource repository');
  FErr.WriteLn('  3. Use binary installation instead of source build');
  FErr.WriteLn;

  Result := False;
end;

function TFPCSourceBuilder.DownloadSource(const AVersion, ATargetDir: string): Boolean;
var
  Git: TGitOperations;
  GitTag: string;
begin
  Result := False;

  // Find Git tag for version using registry
  GitTag := TVersionRegistry.Instance.GetFPCGitTag(AVersion);

  if GitTag = '' then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_UNKNOWN_VERSION, [AVersion]));
    Exit;
  end;

  try
    FOut.WriteLn(_Fmt(CMD_FPC_INSTALL_DOWNLOADING, [AVersion]) + ' (tag: ' + GitTag + ')...');

    // Ensure parent directory exists (but NOT target - git clone requires it to not exist)
    if not DirectoryExists(ExtractFileDir(ATargetDir)) then
      EnsureDir(ExtractFileDir(ATargetDir));

    Git := TGitOperations.Create;
    try
      if Git.Backend = gbNone then
      begin
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_NO_GIT_BACKEND));
        Exit;
      end;

      FOut.WriteLn('Using backend: ' + GitBackendToString(Git.Backend));
      FOut.WriteLn('Cloning: ' + FPC_OFFICIAL_REPO + ' -> ' + ATargetDir);

      Result := Git.Clone(FPC_OFFICIAL_REPO, ATargetDir, GitTag);

      if not Result then
        FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_CLONE_FAILED, [Git.LastError]))
      else
        FOut.WriteLn('Git clone completed successfully');

    finally
      Git.Free;
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': DownloadSource failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCSourceBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
var
  LResult: TProcessResult;
  MakeCmd: string;
  Settings: TFPDevSettings;
  BootstrapFPC: string;
  CurrentFPC: string;
  Params: array of string;
begin
  Result := False;

  if not DirectoryExists(ASourceDir) then
  begin
    FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [ASourceDir]));
    Exit;
  end;

  try
    FOut.WriteLn('Building FPC from source...');
    FOut.WriteLn('Source directory: ' + ASourceDir);
    FOut.WriteLn('Install directory: ' + AInstallDir);

    if not DirectoryExists(AInstallDir) then
      EnsureDir(AInstallDir);

    Settings := FConfigManager.GetSettingsManager.GetSettings;

    // Detect bootstrap compiler
    BootstrapFPC := GetVersionInstallPath('3.2.2') + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'ppcx64';
    {$IFDEF CPU386}
    BootstrapFPC := GetVersionInstallPath('3.2.2') + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'ppc386';
    {$ENDIF}
    if FileExists(BootstrapFPC) then
    begin
      FOut.WriteLn('Using installed FPC 3.2.2 as bootstrap compiler');
      FOut.WriteLn('Bootstrap compiler: ' + BootstrapFPC);
    end
    else
    begin
      CurrentFPC := GetCurrentFPCVersion;
      if CurrentFPC <> '' then
      begin
        FOut.WriteLn('Using system FPC ' + CurrentFPC + ' as bootstrap compiler');
        BootstrapFPC := 'fpc';
      end
      else
      begin
        FErr.WriteLn('Warning: No FPC compiler found');
        FErr.WriteLn('Build will likely fail without a bootstrap compiler');
        BootstrapFPC := '';
      end;
    end;

    MakeCmd := 'make';

    // Build parameters
    Params := nil;
    if BootstrapFPC <> '' then
    begin
      SetLength(Params, 5);
      Params[0] := 'all';
      Params[1] := 'install';
      Params[2] := 'PREFIX=' + AInstallDir;
      Params[3] := 'PP=' + BootstrapFPC;
      Params[4] := '-j' + IntToStr(Settings.ParallelJobs);
    end
    else
    begin
      SetLength(Params, 4);
      Params[0] := 'all';
      Params[1] := 'install';
      Params[2] := 'PREFIX=' + AInstallDir;
      Params[3] := '-j' + IntToStr(Settings.ParallelJobs);
    end;

    FOut.Write('Executing: ' + MakeCmd + ' all install PREFIX=' + AInstallDir);
    if BootstrapFPC <> '' then
      FOut.Write(' PP=' + BootstrapFPC);
    FOut.WriteLn(' -j' + IntToStr(Settings.ParallelJobs));

    LResult := TProcessExecutor.RunDirect(MakeCmd, Params, ASourceDir);

    Result := LResult.Success;
    if not Result then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BUILD_FAILED, [LResult.ExitCode]));
      FErr.WriteLn;
      FErr.WriteLn('Common causes:');
      FErr.WriteLn('  1. Wrong bootstrap compiler version (FPC builds require specific FPC versions)');
      FErr.WriteLn('  2. Missing build dependencies (make, binutils, etc.)');
      FErr.WriteLn;
      FErr.WriteLn('To diagnose the issue, try running manually:');
      FErr.WriteLn('  cd ' + ASourceDir);
      FErr.WriteLn('  make all');
      FErr.WriteLn;
      FErr.WriteLn('Note: Building from source requires a compatible bootstrap FPC compiler.');
      FErr.WriteLn('      Consider using binary installation if available.');
    end;

  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': BuildFromSource failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
