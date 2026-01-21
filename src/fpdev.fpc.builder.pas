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
  fpdev.utils.process, fpdev.utils.git, fpdev.resource.repo, fpdev.constants,
  fpdev.fpc.types, fpdev.fpc.interfaces, fpdev.fpc.version, fpdev.config;

type
  { Bootstrap compiler requirements }
  TBootstrapRequirement = record
    TargetVersion: string;
    RequiredVersion: string;
  end;

  { TFPCBuilder - FPC builder with dependency injection for testing }
  TFPCBuilder = class
  private
    FVersionManager: TFPCVersionManager;
    FConfigManager: TFPDevConfigManager;
    FFileSystem: IFileSystem;
    FProcessRunner: IProcessRunner;

    function GetSourceDir(const AVersion: string): string;
  public
    constructor Create(AVersionManager: TFPCVersionManager;
      AConfigManager: TFPDevConfigManager;
      AFileSystem: IFileSystem;
      AProcessRunner: IProcessRunner);
    destructor Destroy; override;

    { Downloads FPC source code }
    function DownloadSource(const AVersion, ATargetDir: string): TOperationResult;

    { Builds FPC from source }
    function BuildFromSource(const ASourceDir, AInstallDir: string): TOperationResult;

    { Updates FPC sources from repository }
    function UpdateSources(const AVersion: string): TOperationResult;

    { Cleans FPC source directory }
    function CleanSources(const AVersion: string): TOperationResult;

    property VersionManager: TFPCVersionManager read FVersionManager;
    property ConfigManager: TFPDevConfigManager read FConfigManager;
    property FileSystem: IFileSystem read FFileSystem;
    property ProcessRunner: IProcessRunner read FProcessRunner;
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

  public
    constructor Create(AConfigManager: IConfigManager;
      AOut: IOutput = nil; AErr: IOutput = nil);
    destructor Destroy; override;

    { Gets the current FPC version from system PATH. }
    function GetCurrentFPCVersion: string;

    { Gets path to bootstrap compiler for a version. }
    function GetBootstrapCompilerPath(const AVersion: string): string;

    { Checks if bootstrap compiler is locally available. }
    function IsBootstrapAvailable(const AVersion: string): Boolean;

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
  fpdev.i18n, fpdev.i18n.strings, fpdev.output.console,
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
  LResult: fpdev.utils.process.TProcessResult;
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

  // Compare version strings (e.g., "3.2.2" vs "3.0.4")
  // Returns: -1 if V1 < V2, 0 if V1 = V2, 1 if V1 > V2
  function CompareVersions(const V1, V2: string): Integer;
  var
    Parts1, Parts2: TStringArray;
    I, N1, N2: Integer;
  begin
    Result := 0;
    Parts1 := V1.Split(['.']);
    Parts2 := V2.Split(['.']);

    for I := 0 to 2 do
    begin
      if I < Length(Parts1) then
        N1 := StrToIntDef(Parts1[I], 0)
      else
        N1 := 0;

      if I < Length(Parts2) then
        N2 := StrToIntDef(Parts2[I], 0)
      else
        N2 := 0;

      if N1 < N2 then
        Exit(-1)
      else if N1 > N2 then
        Exit(1);
    end;
  end;

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

  // Check if current system FPC is available and sufficient
  CurrentVersion := GetCurrentFPCVersion;
  if CurrentVersion <> '' then
  begin
    FOut.WriteLn('Current system FPC version: ' + CurrentVersion);

    // Accept if system FPC version >= required version
    // Newer FPC versions can typically compile older versions
    if CompareVersions(CurrentVersion, RequiredVersion) >= 0 then
    begin
      FOut.WriteLn('OK: System FPC version ' + CurrentVersion + ' is sufficient (>= ' + RequiredVersion + ')');
      Result := True;
      Exit;
    end
    else
      FOut.WriteLn('System FPC version ' + CurrentVersion + ' is older than required ' + RequiredVersion);
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
  LResult: fpdev.utils.process.TProcessResult;
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

    // Ensure parent directory exists
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

      // Check if directory already exists
      if DirectoryExists(ATargetDir) then
      begin
        // Directory exists - check if it's a git repo and update it
        if DirectoryExists(ATargetDir + PathDelim + '.git') then
        begin
          FOut.WriteLn('Source directory exists, updating to tag: ' + GitTag);

          // Fetch all tags and branches
          LResult := TProcessExecutor.Execute('git', ['fetch', '--all', '--tags'], ATargetDir);
          if not LResult.Success then
          begin
            FErr.WriteLn(_(MSG_ERROR) + ': Git fetch failed');
            Exit;
          end;

          // Checkout the specific tag
          LResult := TProcessExecutor.Execute('git', ['checkout', GitTag], ATargetDir);
          if not LResult.Success then
          begin
            FErr.WriteLn(_(MSG_ERROR) + ': Git checkout failed for tag: ' + GitTag);
            FErr.WriteLn('  ' + LResult.StdErr);
            Exit;
          end;

          FOut.WriteLn('Git checkout completed successfully');
          Result := True;
        end
        else
        begin
          // Directory exists but is not a git repo - remove and clone fresh
          FOut.WriteLn('Directory exists but is not a git repo, removing...');
          TProcessExecutor.Execute('rm', ['-rf', ATargetDir], '');
          FOut.WriteLn('Cloning: ' + FPC_OFFICIAL_REPO + ' -> ' + ATargetDir);
          Result := Git.Clone(FPC_OFFICIAL_REPO, ATargetDir, GitTag);
          if not Result then
            FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_CLONE_FAILED, [Git.LastError]))
          else
            FOut.WriteLn('Git clone completed successfully');
        end;
      end
      else
      begin
        // Directory doesn't exist - clone fresh
        FOut.WriteLn('Cloning: ' + FPC_OFFICIAL_REPO + ' -> ' + ATargetDir);
        Result := Git.Clone(FPC_OFFICIAL_REPO, ATargetDir, GitTag);
        if not Result then
          FErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_CLONE_FAILED, [Git.LastError]))
        else
          FOut.WriteLn('Git clone completed successfully');
      end;

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
  LResult: fpdev.utils.process.TProcessResult;
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

    // Build parameters - include OVERRIDEVERSIONCHECK=1 to allow newer bootstrap compilers
    Params := nil;
    if BootstrapFPC <> '' then
    begin
      SetLength(Params, 6);
      Params[0] := 'all';
      Params[1] := 'install';
      Params[2] := 'PREFIX=' + AInstallDir;
      Params[3] := 'PP=' + BootstrapFPC;
      Params[4] := 'OVERRIDEVERSIONCHECK=1';
      Params[5] := '-j' + IntToStr(Settings.ParallelJobs);
    end
    else
    begin
      SetLength(Params, 5);
      Params[0] := 'all';
      Params[1] := 'install';
      Params[2] := 'PREFIX=' + AInstallDir;
      Params[3] := 'OVERRIDEVERSIONCHECK=1';
      Params[4] := '-j' + IntToStr(Settings.ParallelJobs);
    end;

    FOut.Write('Executing: ' + MakeCmd + ' all install PREFIX=' + AInstallDir);
    if BootstrapFPC <> '' then
      FOut.Write(' PP=' + BootstrapFPC);
    FOut.WriteLn(' OVERRIDEVERSIONCHECK=1 -j' + IntToStr(Settings.ParallelJobs));

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

{ TFPCBuilder }

constructor TFPCBuilder.Create(AVersionManager: TFPCVersionManager;
  AConfigManager: TFPDevConfigManager;
  AFileSystem: IFileSystem;
  AProcessRunner: IProcessRunner);
begin
  inherited Create;
  FVersionManager := AVersionManager;
  FConfigManager := AConfigManager;
  FFileSystem := AFileSystem;
  FProcessRunner := AProcessRunner;
end;

destructor TFPCBuilder.Destroy;
begin
  inherited Destroy;
end;

function TFPCBuilder.GetSourceDir(const AVersion: string): string;
var
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettings;
  Result := Settings.InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;
end;

function TFPCBuilder.DownloadSource(const AVersion, ATargetDir: string): TOperationResult;
var
  GitTag: string;
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  // Validate version
  if not FVersionManager.ValidateVersion(AVersion) then
  begin
    Result := OperationError(ecVersionNotFound, 'Version not found: ' + AVersion);
    Exit;
  end;

  // Get Git tag for version
  GitTag := FVersionManager.GetGitTag(AVersion);
  if GitTag = '' then
  begin
    Result := OperationError(ecVersionNotFound, 'No Git tag found for version: ' + AVersion);
    Exit;
  end;

  // Create target directory
  if not FFileSystem.ForceDirectories(ATargetDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Failed to create directory: ' + ATargetDir);
    Exit;
  end;

  // Execute git clone
  ProcResult := FProcessRunner.Execute('git', ['clone', '--branch', GitTag, '--depth', '1',
    FPC_OFFICIAL_REPO, ATargetDir], '');

  if not ProcResult.Success then
  begin
    Result := OperationError(ecDownloadFailed, 'Git clone failed: ' + ProcResult.StdErr);
    Exit;
  end;

  Result := OperationSuccess;
end;

function TFPCBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): TOperationResult;
var
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
  Settings: TFPDevSettings;
begin
  // Check source directory exists
  if not FFileSystem.DirectoryExists(ASourceDir) then
  begin
    Result := OperationError(ecBuildFailed, 'Source directory does not exist: ' + ASourceDir);
    Exit;
  end;

  // Create install directory
  if not FFileSystem.ForceDirectories(AInstallDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Failed to create install directory: ' + AInstallDir);
    Exit;
  end;

  // Get parallel jobs setting
  Settings := FConfigManager.GetSettings;

  // Execute make
  ProcResult := FProcessRunner.Execute('make', ['all', 'install',
    'PREFIX=' + AInstallDir, '-j' + IntToStr(Settings.ParallelJobs)], ASourceDir);

  if not ProcResult.Success then
  begin
    Result := OperationError(ecBuildFailed, 'Build failed with exit code: ' + IntToStr(ProcResult.ExitCode));
    Exit;
  end;

  Result := OperationSuccess;
end;

function TFPCBuilder.UpdateSources(const AVersion: string): TOperationResult;
var
  SourceDir, GitDir: string;
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  SourceDir := GetSourceDir(AVersion);

  // Check if source directory exists
  if not FFileSystem.DirectoryExists(SourceDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Source directory does not exist: ' + SourceDir);
    Exit;
  end;

  // Check if it's a git repository
  GitDir := SourceDir + PathDelim + '.git';
  if not FFileSystem.DirectoryExists(GitDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Source directory is not a git repository: ' + SourceDir);
    Exit;
  end;

  // Execute git pull
  ProcResult := FProcessRunner.Execute('git', ['pull'], SourceDir);

  if not ProcResult.Success then
  begin
    Result := OperationError(ecDownloadFailed, 'Git pull failed: ' + ProcResult.StdErr);
    Exit;
  end;

  Result := OperationSuccess;
end;

function TFPCBuilder.CleanSources(const AVersion: string): TOperationResult;
var
  SourceDir: string;
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  SourceDir := GetSourceDir(AVersion);

  // Check if source directory exists
  if not FFileSystem.DirectoryExists(SourceDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Source directory does not exist: ' + SourceDir);
    Exit;
  end;

  // Execute make clean
  ProcResult := FProcessRunner.Execute('make', ['clean'], SourceDir);

  if not ProcResult.Success then
  begin
    Result := OperationError(ecBuildFailed, 'Clean failed: ' + ProcResult.StdErr);
    Exit;
  end;

  Result := OperationSuccess;
end;

end.
