unit fpdev.fpc.source;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

interface

uses
  SysUtils, Classes, StrUtils, fpdev.source.repo, fpdev.build.manager, fpdev.constants,
  fpdev.fpc.bootstrap, fpdev.utils.process;

type
  // FPCUpDeluxe-inspired build steps
  TFPCBuildStep = (
    bsInit,           // Initialize environment
    bsBootstrap,      // Ensure bootstrap compiler
    bsClone,          // Clone source code
    bsCompiler,       // Build compiler
    bsRTL,            // Build RTL
    bsPackages,       // Build packages
    bsInstall,        // Install binaries
    bsConfig,         // Configure environment
    bsFinished        // Finished
  );

  { TFPCSourceManager }
  TFPCSourceManager = class
  private
    FSourceRoot: string;
    FCurrentVersion: string;
    FBootstrapCompiler: string;
    FCurrentStep: TFPCBuildStep;
    FParallelJobs: Integer;
    FUseCache: Boolean;
    FVerboseOutput: Boolean;
    FBootstrap: TBootstrapManager;  // Bootstrap helper

    function GetSourcePath(const AVersion: string): string;
    function GetSandboxRoot: string;
    function GetVersionFromBranch(const ABranch: string): string;
    function CreateBuildManager(const AAllowInstall: Boolean): TBuildManager;
    function ExecuteCommand(
      const AProgram: string;
      const AArgs: array of string;
      const AWorkingDir: string = ''
    ): Boolean;
    function IsValidSourceDirectory(const APath: string): Boolean;

    // Bootstrap compiler management - private helpers
    function DownloadBootstrapCompilerInternal(const AVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    // Step-by-step build process (FPCUpDeluxe-inspired)
    function InitializeInstall(const {%H-} AVersion: string): Boolean;
    function BuildFPCCompiler(const AVersion: string): Boolean;
    function BuildFPCRTL(const AVersion: string): Boolean;
    function BuildFPCPackages(const AVersion: string): Boolean;
    function InstallFPCBinaries(const AVersion: string): Boolean;
    function ConfigureFPCEnvironment(const AVersion: string): Boolean;
    function TestBuildResults(const AVersion: string): Boolean;
    function ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;

    // Performance optimization methods
    function GetOptimalJobCount: Integer;
    function IsCacheAvailable(const AVersion: string): Boolean;
    function UseCachedBuild(const AVersion: string): Boolean;
    function OptimizeBuildCommand(const ABaseCommand: string): string;
    function CheckBuildPrerequisites(const {%H-} AVersion: string): Boolean;

  protected
    function ProtectedIsCacheAvailable(const AVersion: string): Boolean;
    function ProtectedUseCachedBuild(const AVersion: string): Boolean;
    function ProtectedIsValidSourceDirectory(const APath: string): Boolean;
    function ProtectedGetVersionFromBranch(const ABranch: string): string;
    function ProtectedBuildFPCCompiler(const AVersion: string): Boolean;
    function ProtectedBuildFPCRTL(const AVersion: string): Boolean;
    function ProtectedBuildFPCPackages(const AVersion: string): Boolean;

  public
    constructor Create(const ASourceRoot: string = '');
    destructor Destroy; override;

    // Source management
    function CloneFPCSource(const AVersion: string = 'main'): Boolean;
    function UpdateFPCSource(const AVersion: string = ''): Boolean;
    function SwitchFPCVersion(const AVersion: string): Boolean;
    // Separation of concerns: repository manager
    function Repo: TSourceRepoManager;
    function BuildFPCSource(const AVersion: string = ''): Boolean;
    function InstallFPCVersion(const AVersion: string): Boolean;
    function ListAvailableVersions: TStringArray;
    function ListLocalVersions: TStringArray;

    // Version information
    function GetCurrentVersion: string;
    function IsVersionAvailable(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;

    // Path management
    function GetFPCSourcePath(const AVersion: string = ''): string;
    function GetFPCBuildPath(const AVersion: string = ''): string;

    // Bootstrap compiler management (FPCUpDeluxe-inspired) - for testing
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetBootstrapPath(const AVersion: string): string;
    { DEPRECATED: Use fpdev-repo for bootstrap compilers instead }
    function GetBootstrapDownloadURL(const AVersion: string): string; deprecated 'Use fpdev-repo instead';
    function DownloadBootstrapCompiler(const AVersion: string): Boolean; deprecated 'Use fpdev-repo instead';

    // Properties
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property CurrentVersion: string read GetCurrentVersion;
  end;

const
  // FPC Git repository information - using central constants
  FPC_GIT_URL = FPC_OFFICIAL_REPO;

  // Supported FPC version branches
  FPC_VERSIONS: array[0..6] of record
    Version: string;
    Branch: string;
    Description: string;
  end = (
    (Version: 'main'; Branch: 'main'; Description: 'Development version (unstable)'),
    (Version: '3.2.2'; Branch: 'fixes_3_2'; Description: 'FPC 3.2.2 (stable)'),
    (Version: '3.2.0'; Branch: 'fixes_3_2'; Description: 'FPC 3.2.0 (stable)'),
    (Version: '3.0.4'; Branch: 'release_3_0_4'; Description: 'FPC 3.0.4 (legacy)'),
    (Version: '3.0.2'; Branch: 'release_3_0_2'; Description: 'FPC 3.0.2 (legacy)'),
    (Version: '2.6.4'; Branch: 'release_2_6_4'; Description: 'FPC 2.6.4 (legacy)'),
    (Version: '2.6.2'; Branch: 'release_2_6_2'; Description: 'FPC 2.6.2 (legacy)')
  );

implementation

uses
  fphttpclient, opensslsockets, zipper, fpdev.fpc.types, fpdev.utils.fs,
  fpdev.version.registry;

function FindStaticFPCVersionIndex(const AVersion: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Version, AVersion) then
      Exit(i);
  end;
end;

function FindStaticFPCBranchIndex(const ABranch: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Branch, ABranch) then
      Exit(i);
  end;
end;

function ResolveStaticFPCVersionFromRef(const ARef: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(FPC_RELEASES) do
  begin
    if SameText(FPC_RELEASES[i].GitTag, ARef) or SameText(FPC_RELEASES[i].Branch, ARef) then
      Exit(FPC_RELEASES[i].Version);
  end;
end;

function RegistryHasFPCReleases(const AReleases: TFPCReleaseArray): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AReleases) do
  begin
    if Trim(AReleases[i].Version) <> '' then
      Exit(True);
  end;
end;

{ TFPCSourceManager }

constructor TFPCSourceManager.Create(const ASourceRoot: string);
begin
  inherited Create;

  if ASourceRoot <> '' then
    FSourceRoot := ASourceRoot
  else
    FSourceRoot := 'sources' + PathDelim + 'fpc';

  FCurrentVersion := '';

  // Performance optimization initialization
  FParallelJobs := GetOptimalJobCount;
  FUseCache := True;
  FVerboseOutput := False;

  // Initialize bootstrap helper
  FBootstrap := TBootstrapManager.Create(FSourceRoot);

  // Ensure source root directory exists
  if not DirectoryExists(FSourceRoot) then
    EnsureDir(FSourceRoot);
end;

function TFPCSourceManager.Repo: TSourceRepoManager;
begin
  // Simple factory: return a lightweight object each time, avoiding persistent fields
  Result := TSourceRepoManager.Create(FSourceRoot);
end;

destructor TFPCSourceManager.Destroy;
begin
  if Assigned(FBootstrap) then
    FBootstrap.Free;
  inherited Destroy;
end;

function TFPCSourceManager.GetSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  if AVersion = '' then
    Version := 'main'
  else
    Version := AVersion;

  Result := FSourceRoot + PathDelim + 'fpc-' + Version;
end;

function TFPCSourceManager.GetSandboxRoot: string;
begin
  Result := FSourceRoot + PathDelim + 'sandbox';
end;

function TFPCSourceManager.GetVersionFromBranch(const ABranch: string): string;
var
  Releases: TFPCReleaseArray;
  i: Integer;
begin
  Result := ABranch;

  Releases := TVersionRegistry.Instance.GetFPCReleases;
  for i := 0 to High(Releases) do
  begin
    if SameText(Releases[i].GitTag, ABranch) or SameText(Releases[i].Branch, ABranch) then
      Exit(Releases[i].Version);
  end;

  if not RegistryHasFPCReleases(Releases) then
  begin
    Result := ResolveStaticFPCVersionFromRef(ABranch);
    if Result <> '' then
      Exit;
  end;

  Result := ABranch;
end;

function TFPCSourceManager.CreateBuildManager(
  const AAllowInstall: Boolean
): TBuildManager;
begin
  Result := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  Result.SetSandboxRoot(GetSandboxRoot);
  Result.SetAllowInstall(AAllowInstall);
end;

function TFPCSourceManager.ExecuteCommand(
  const AProgram: string;
  const AArgs: array of string;
  const AWorkingDir: string
): Boolean;
var
  CommandResult: TProcessResult;
  ExecutablePath: string;
begin
  ExecutablePath := TProcessExecutor.FindExecutable(AProgram);
  if ExecutablePath = '' then
    ExecutablePath := AProgram;

  CommandResult := TProcessExecutor.RunDirect(ExecutablePath, AArgs, AWorkingDir);
  Result := CommandResult.Success;
end;

function TFPCSourceManager.CloneFPCSource(const AVersion: string): Boolean;
begin
  // Delegate to SourceRepoManager, keeping existing logs and behavior with minimal changes
  Result := Repo.CloneFPCSource(AVersion);
  if Result then FCurrentVersion := IfThen(AVersion<>'', AVersion, 'main');
end;

function TFPCSourceManager.UpdateFPCSource(const AVersion: string): Boolean;
var
  LVersion: string;
begin
  LVersion := AVersion;
  if LVersion = '' then LVersion := FCurrentVersion;
  if LVersion = '' then LVersion := 'main';
  Result := Repo.UpdateFPCSource(LVersion);
  if Result then
  begin
    FCurrentVersion := LVersion;
    WriteLn('[OK] FPC source updated successfully');
  end
  else
    WriteLn('[FAIL] FPC source update failed');
end;

function TFPCSourceManager.SwitchFPCVersion(const AVersion: string): Boolean;
begin
  if not IsVersionInstalled(AVersion) then
  begin
    Exit(False);
  end;
  Result := Repo.SwitchFPCVersion(AVersion);
  if Result then
    FCurrentVersion := AVersion;
end;

function TFPCSourceManager.ListAvailableVersions: TStringArray;
var
  Releases: TFPCReleaseArray;
  Values: TStringList;
  i: Integer;
  UseStaticFallback: Boolean;
begin
  Result := nil;
  Values := TStringList.Create;
  try
    Releases := TVersionRegistry.Instance.GetFPCReleases;
    UseStaticFallback := not RegistryHasFPCReleases(Releases);
    for i := 0 to High(Releases) do
    begin
      if (Trim(Releases[i].Version) <> '') and (Values.IndexOf(Releases[i].Version) < 0) then
        Values.Add(Releases[i].Version);
    end;

    if UseStaticFallback then
      for i := 0 to High(FPC_VERSIONS) do
      begin
        if Values.IndexOf(FPC_VERSIONS[i].Version) < 0 then
          Values.Add(FPC_VERSIONS[i].Version);
      end;

    SetLength(Result, Values.Count);
    for i := 0 to Values.Count - 1 do
      Result[i] := Values[i];
  finally
    Values.Free;
  end;
end;

function TFPCSourceManager.ListLocalVersions: TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName, Version, SourcePath: string;
  i: Integer;
begin
  Result := nil;
  VersionList := TStringList.Create;
  try
    if FindFirst(FSourceRoot + PathDelim + 'fpc-*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          DirName := SearchRec.Name;
          if Pos('fpc-', DirName) = 1 then
          begin
            SourcePath := FSourceRoot + PathDelim + DirName;
            if not IsValidSourceDirectory(SourcePath) then
              Continue;
            Version := Copy(DirName, 5, Length(DirName) - 4);
            VersionList.Add(Version);
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;

    SetLength(Result, VersionList.Count);
    for i := 0 to VersionList.Count - 1 do
      Result[i] := VersionList[i];

  finally
    VersionList.Free;
  end;
end;

function TFPCSourceManager.GetCurrentVersion: string;
begin
  Result := FCurrentVersion;
end;

function TFPCSourceManager.IsVersionAvailable(const AVersion: string): Boolean;
var
  Releases: TFPCReleaseArray;
begin
  if TVersionRegistry.Instance.IsFPCVersionValid(AVersion) then
    Exit(True);

  Releases := TVersionRegistry.Instance.GetFPCReleases;
  if RegistryHasFPCReleases(Releases) then
    Exit(False);

  Result := FindStaticFPCVersionIndex(AVersion) >= 0;
end;

function TFPCSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := IsValidSourceDirectory(GetSourcePath(AVersion));
end;

function TFPCSourceManager.GetFPCSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  Result := GetSourcePath(Version);
end;

function TFPCSourceManager.GetFPCBuildPath(const AVersion: string): string;
begin
  Result := GetFPCSourcePath(AVersion) + PathDelim + 'build';
end;

function TFPCSourceManager.BuildFPCSource(const AVersion: string): Boolean;
var
  Version, SourcePath: string;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  SourcePath := GetFPCSourcePath(Version);

  if not IsValidSourceDirectory(SourcePath) then
  begin
    WriteLn('[FAIL] Invalid FPC source directory: ', SourcePath);
    Exit;
  end;

  WriteLn;

  // Build FPC using make (requires bootstrap compiler)
  Result := ExecuteCommand('make', ['clean', 'all'], SourcePath);
end;

function TFPCSourceManager.InstallFPCVersion(const AVersion: string): Boolean;
var
  Version: string;
  PreviousVersion: string;
  CacheDir, CachePath: string;
  CacheMeta: TStringList;
  function CompleteInstallAndValidation: Boolean;
  begin
    FCurrentStep := bsInstall;
    if not ReportBuildStep(bsInstall, 'Install FPC binaries') then
      Exit(False);
    if not InstallFPCBinaries(Version) then
      Exit(False);

    FCurrentStep := bsConfig;
    if not ReportBuildStep(bsConfig, 'Configure FPC environment') then
      Exit(False);
    if not ConfigureFPCEnvironment(Version) then
      Exit(False);

    if not ReportBuildStep(bsConfig, 'Test build results') then
      Exit(False);
    Result := TestBuildResults(Version);
  end;
begin
  Result := False;
  Version := AVersion;
  PreviousVersion := FCurrentVersion;

  WriteLn;

  // Step 1: Initialize build environment
  FCurrentStep := bsInit;
  if not ReportBuildStep(bsInit, 'Initialize build environment') then Exit;
  if not InitializeInstall(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  // Step 2: Ensure bootstrap compiler
  FCurrentStep := bsBootstrap;
  if not ReportBuildStep(bsBootstrap, 'Check Bootstrap Compiler') then Exit;
  if not EnsureBootstrapCompiler(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  // Step 3: Smart clone source code (only if needed)
  FCurrentStep := bsClone;
  if not ReportBuildStep(bsClone, 'Clone FPC sources') then Exit;
  if not CloneFPCSource(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  // Optional: reuse cached build if available
  if FUseCache and IsCacheAvailable(Version) then
  begin
    if UseCachedBuild(Version) then
    begin
      if not CompleteInstallAndValidation then
      begin
        FCurrentVersion := PreviousVersion;
        Exit;
      end;

      // Finished (cache path)
      FCurrentStep := bsFinished;
      ReportBuildStep(bsFinished, 'FPC build/test completed');

      WriteLn;
      Result := True;
      Exit;
    end;
  end;

  // Step 4: Build compiler
  FCurrentStep := bsCompiler;
  if not ReportBuildStep(bsCompiler, 'Build FPC Compiler') then Exit;
  if not BuildFPCCompiler(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  // Step 4: Build RTL
  FCurrentStep := bsRTL;
  if not ReportBuildStep(bsRTL, 'Build FPC RTL') then Exit;
  if not BuildFPCRTL(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  // Build packages
  FCurrentStep := bsPackages;
  if not ReportBuildStep(bsPackages, 'Build FPC packages') then Exit;
  if not BuildFPCPackages(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  if not CompleteInstallAndValidation then
  begin
    FCurrentVersion := PreviousVersion;
    Exit;
  end;

  // Write build cache marker
  CacheDir := FSourceRoot + PathDelim + 'cache';
  if not DirectoryExists(CacheDir) then
    EnsureDir(CacheDir);
  CachePath := CacheDir + PathDelim + 'fpc-' + Version + '.cache';
  CacheMeta := TStringList.Create;
  try
    CacheMeta.Add('version=' + Version);
    CacheMeta.Add('built_at=' + DateTimeToStr(Now));
    CacheMeta.SaveToFile(CachePath);
  finally
    CacheMeta.Free;
  end;

  // Finished
  FCurrentStep := bsFinished;
  ReportBuildStep(bsFinished, 'FPC build/test completed');

  WriteLn;
  Result := True;
end;

// Bootstrap compiler management - delegate to FBootstrap helper
function TFPCSourceManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  Result := FBootstrap.GetRequiredBootstrapVersion(ATargetVersion);
end;

function TFPCSourceManager.GetBootstrapPath(const AVersion: string): string;
begin
  Result := FBootstrap.GetBootstrapPath(AVersion);
end;

function TFPCSourceManager.GetBootstrapDownloadURL(const AVersion: string): string;
begin
  Result := FBootstrap.GetBootstrapDownloadURL(AVersion);
end;

function TFPCSourceManager.DownloadBootstrapCompilerInternal(const AVersion: string): Boolean;
var
  URL, TempFile, TempDir, BootstrapRoot, BootstrapPath: string;
  HTTPClient: TFPHTTPClient;
  FileStream: TFileStream;
  Unzipper: TUnZipper;
begin
  Result := False;

  try
    // Get download URL
    URL := FBootstrap.GetBootstrapDownloadURL(AVersion);
    if URL = '' then
    begin
      WriteLn('Error: Failed to construct download URL for version ', AVersion);
      Exit;
    end;

    // Create temp directory for download
    TempDir := GetTempDir + 'fpdev_bootstrap_' + IntToStr(GetTickCount64);
    if not DirectoryExists(TempDir) then
      EnsureDir(TempDir);

    // Generate temp file name
    TempFile := TempDir + PathDelim + 'fpc-bootstrap-' + AVersion + '.zip';

    WriteLn('Downloading bootstrap compiler ', AVersion, ' from:');
    WriteLn('  ', URL);
    WriteLn('To: ', TempFile);
    WriteLn;

    // Download file
    HTTPClient := TFPHTTPClient.Create(nil);
    try
      HTTPClient.AllowRedirect := True;
      FileStream := TFileStream.Create(TempFile, fmCreate);
      try
        HTTPClient.Get(URL, FileStream);
        WriteLn('Download completed: ', FileStream.Size, ' bytes');
      finally
        FileStream.Free;
      end;
    finally
      HTTPClient.Free;
    end;

    // Extract archive to bootstrap directory
    BootstrapRoot := FSourceRoot + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion;
    if not DirectoryExists(BootstrapRoot) then
      EnsureDir(BootstrapRoot);

    WriteLn('Extracting bootstrap compiler to: ', BootstrapRoot);

    Unzipper := TUnZipper.Create;
    try
      Unzipper.FileName := TempFile;
      Unzipper.OutputPath := BootstrapRoot;
      Unzipper.Examine;
      WriteLn('  Files in archive: ', Unzipper.Entries.Count);
      Unzipper.UnZipAllFiles;
      WriteLn('Extraction completed successfully');
    finally
      Unzipper.Free;
    end;

    // Verify that fpc executable exists
    BootstrapPath := GetBootstrapPath(AVersion);
    if FileExists(BootstrapPath) then
    begin
      WriteLn('Bootstrap compiler verified: ', BootstrapPath);
      Result := True;
    end
    else
    begin
      WriteLn('Warning: Bootstrap compiler executable not found at expected path: ', BootstrapPath);
      Result := False;
    end;

    // Cleanup temp files
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    if DirectoryExists(TempDir) then
      RemoveDir(TempDir);

  except
    on E: Exception do
    begin
      WriteLn('Error downloading bootstrap compiler: ', E.Message);
      Result := False;

      // Cleanup on error
      if FileExists(TempFile) then
        DeleteFile(TempFile);
      if DirectoryExists(TempDir) then
        RemoveDir(TempDir);
    end;
  end;
end;

function TFPCSourceManager.DownloadBootstrapCompiler(const AVersion: string): Boolean;
begin
  Result := DownloadBootstrapCompilerInternal(AVersion);
end;

function TFPCSourceManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  RequiredVersion, SystemFPC, BootstrapPath: string;
begin
  RequiredVersion := FBootstrap.GetRequiredBootstrapVersion(ATargetVersion);

  // Check system FPC
  SystemFPC := FBootstrap.FindSystemFPC;
  if FBootstrap.IsCompatibleBootstrap(SystemFPC, RequiredVersion) then
  begin
    FBootstrapCompiler := SystemFPC;
    Exit(True);
  end;

  // Check downloaded bootstrap
  BootstrapPath := FBootstrap.GetBootstrapPath(RequiredVersion);
  if FileExists(BootstrapPath) then
  begin
    FBootstrapCompiler := BootstrapPath;
    Exit(True);
  end;

  // Download bootstrap compiler
  Result := DownloadBootstrapCompilerInternal(RequiredVersion);
  if Result then
  begin
    FBootstrapCompiler := FBootstrap.GetBootstrapPath(RequiredVersion);
  end;
end;

// Step-by-step build process (FPCUpDeluxe-inspired)
function TFPCSourceManager.InitializeInstall(const {%H-} AVersion: string): Boolean;
begin
  // AVersion parameter reserved for future use
  if AVersion <> '' then;
  // Create necessary directories
  EnsureDir(FSourceRoot);
  EnsureDir(FSourceRoot + PathDelim + 'bootstrap');
  Result := True;
end;

function TFPCSourceManager.BuildFPCCompiler(const AVersion: string): Boolean;
var
  LSourcePath: string;
  LBM: TBuildManager;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  if not IsValidSourceDirectory(LSourcePath) then
  begin
    WriteLn('[FAIL] Invalid FPC source directory: ', LSourcePath);
    Exit(False);
  end;

  // Delegate to BuildManager for consistent build behavior and log output.
  LBM := CreateBuildManager(False);
  try
    Result := LBM.BuildCompiler(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.BuildFPCRTL(const AVersion: string): Boolean;
var
  LSourcePath: string;
  LBM: TBuildManager;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  if not IsValidSourceDirectory(LSourcePath) then
  begin
    WriteLn('[FAIL] Invalid FPC source directory: ', LSourcePath);
    Exit(False);
  end;

  LBM := CreateBuildManager(False);
  try
    Result := LBM.BuildRTL(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.BuildFPCPackages(const AVersion: string): Boolean;
var
  LSourcePath: string;
  LBM: TBuildManager;
begin
  LSourcePath := GetFPCSourcePath(AVersion);
  if not IsValidSourceDirectory(LSourcePath) then
  begin
    WriteLn('[FAIL] Invalid FPC source directory: ', LSourcePath);
    Exit(False);
  end;

  LBM := CreateBuildManager(False);
  try
    Result := LBM.BuildPackages(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.InstallFPCBinaries(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  LBM := CreateBuildManager(True);
  try
    Result := LBM.Install(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.ConfigureFPCEnvironment(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  LBM := CreateBuildManager(True);
  try
    Result := LBM.Configure(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.TestBuildResults(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  LBM := CreateBuildManager(True);
  try
    Result := LBM.TestResults(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.ReportBuildStep(const AStep: TFPCBuildStep; const AMessage: string): Boolean;
begin
  // Suppress unused parameter hints
  if AStep = bsFinished then; // Step type available for future logging
  if AMessage <> '' then;     // Message available for future logging
  Result := True;
end;

// Performance optimization methods
function TFPCSourceManager.GetOptimalJobCount: Integer;
begin
  // Use environment variable if available
  Result := StrToIntDef(GetEnvironmentVariable('NUMBER_OF_PROCESSORS'), 0);

  // Fallback to reasonable default
  if Result <= 0 then
    Result := 4;

  // Limit to reasonable range
  if Result < 1 then Result := 1;
  if Result > 16 then Result := 16;

end;

function TFPCSourceManager.IsCacheAvailable(const AVersion: string): Boolean;
var
  CachePath: string;
begin
  CachePath := FSourceRoot + PathDelim + 'cache' + PathDelim + 'fpc-' + AVersion + '.cache';
  Result := FileExists(CachePath);
end;

function TFPCSourceManager.UseCachedBuild(const AVersion: string): Boolean;
var
  SourcePath, CachePath, CompilerDir, RTLDir: string;
  CacheMeta: TStringList;
  CachedVersion: string;
  i: Integer;
begin
  Result := False;
  SourcePath := GetFPCSourcePath(AVersion);

  // Check if source directory is valid
  if not IsValidSourceDirectory(SourcePath) then
    Exit;

  // Check if cache file exists
  CachePath := FSourceRoot + PathDelim + 'cache' + PathDelim + 'fpc-' + AVersion + '.cache';
  if not FileExists(CachePath) then
    Exit;

  // Read and validate cache metadata
  CacheMeta := TStringList.Create;
  try
    CacheMeta.LoadFromFile(CachePath);

    // Extract cached version
    CachedVersion := '';
    for i := 0 to CacheMeta.Count - 1 do
    begin
      if Pos('version=', CacheMeta[i]) = 1 then
      begin
        CachedVersion := Copy(CacheMeta[i], 9, Length(CacheMeta[i]) - 8);
        Break;
      end;
    end;

    // Verify version matches
    if not SameText(CachedVersion, AVersion) then
      Exit;
  finally
    CacheMeta.Free;
  end;

  // Check if build artifacts exist
  CompilerDir := SourcePath + PathDelim + 'compiler';
  RTLDir := SourcePath + PathDelim + 'rtl';

  if not DirectoryExists(CompilerDir) then
    Exit;
  if not DirectoryExists(RTLDir) then
    Exit;

  // Check for compiled compiler executable
  {$IFDEF MSWINDOWS}
  if not FileExists(CompilerDir + PathDelim + 'ppc386.exe') and
     not FileExists(CompilerDir + PathDelim + 'ppcx64.exe') then
    Exit;
  {$ELSE}
  if not FileExists(CompilerDir + PathDelim + 'ppc386') and
     not FileExists(CompilerDir + PathDelim + 'ppcx64') and
     not FileExists(CompilerDir + PathDelim + 'ppca64') then
    Exit;
  {$ENDIF}

  // All checks passed, cache is valid and usable
  Result := True;
end;

function TFPCSourceManager.ProtectedIsCacheAvailable(const AVersion: string): Boolean;
begin
  Result := IsCacheAvailable(AVersion);
end;

function TFPCSourceManager.ProtectedUseCachedBuild(const AVersion: string): Boolean;
begin
  Result := UseCachedBuild(AVersion);
end;

function TFPCSourceManager.ProtectedIsValidSourceDirectory(const APath: string): Boolean;
begin
  Result := IsValidSourceDirectory(APath);
end;

function TFPCSourceManager.ProtectedGetVersionFromBranch(const ABranch: string): string;
begin
  Result := GetVersionFromBranch(ABranch);
end;

function TFPCSourceManager.ProtectedBuildFPCCompiler(const AVersion: string): Boolean;
begin
  Result := BuildFPCCompiler(AVersion);
end;

function TFPCSourceManager.ProtectedBuildFPCRTL(const AVersion: string): Boolean;
begin
  Result := BuildFPCRTL(AVersion);
end;

function TFPCSourceManager.ProtectedBuildFPCPackages(const AVersion: string): Boolean;
begin
  Result := BuildFPCPackages(AVersion);
end;

function TFPCSourceManager.OptimizeBuildCommand(const ABaseCommand: string): string;
begin
  Result := ABaseCommand;

  // Add parallel jobs
  if FParallelJobs > 1 then
    Result := Result + ' -j' + IntToStr(FParallelJobs);

  // Add optimization flags
  Result := Result + ' OPT="-O2"';

  // Reduce verbosity if not needed
  if not FVerboseOutput then
    Result := Result + ' VERBOSE=0';

end;

function TFPCSourceManager.CheckBuildPrerequisites(const {%H-} AVersion: string): Boolean;
begin
  // AVersion parameter reserved for future use
  if AVersion <> '' then;

  // Check if make is available
  if not ExecuteCommand('make', ['--version'], '') then
  begin
    Exit(False);
  end;

  // Check if bootstrap compiler is available
  if FBootstrapCompiler = '' then
  begin
    Exit(False);
  end;

  Result := True;
end;

function TFPCSourceManager.IsValidSourceDirectory(const APath: string): Boolean;
var
  CompilerPath, RTLPath, MakefilePath: string;
begin
  Result := False;

  // Check basic directory structure
  if not DirectoryExists(APath) then
    Exit;

  // Check key directories and files
  CompilerPath := APath + PathDelim + 'compiler';
  RTLPath := APath + PathDelim + 'rtl';
  MakefilePath := APath + PathDelim + 'Makefile';

  // Validate source directory integrity
  if DirectoryExists(CompilerPath) and
     DirectoryExists(RTLPath) and
     FileExists(MakefilePath) then
  begin
    Result := True;
  end
  else
  begin
    if not DirectoryExists(CompilerPath) then
    if not DirectoryExists(RTLPath) then
    if not FileExists(MakefilePath) then
  end;
end;

end.
