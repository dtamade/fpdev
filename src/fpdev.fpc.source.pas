unit fpdev.fpc.source;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, fpdev.source.repo, fpdev.build.manager, fpdev.constants;

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

  // Platform information for bootstrap download
  TPlatformInfo = record
    Platform: string;      // 'Win64', 'Linux', 'macOS'
    Architecture: string;  // 'x86_64-win64', 'x86_64-linux', 'aarch64-darwin', etc.
  end;

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

    function GetSourcePath(const AVersion: string): string;
    function GetVersionFromBranch(const ABranch: string): string;
    function ExecuteGitCommand(const ACommand: string; const AWorkingDir: string = ''): Boolean;
    function ExecuteCommand(const AProgram: string; const AArgs: array of string; const AWorkingDir: string = ''): Boolean;
    function IsValidSourceDirectory(const APath: string): Boolean;

    // Platform detection for bootstrap download
    function DetectPlatformArch: TPlatformInfo;

    // Bootstrap compiler management - private helpers
    function FindSystemFPC: string;
    function IsCompatibleBootstrap(const ACompilerPath, ARequiredVersion: string): Boolean;
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    // Step-by-step build process (FPCUpDeluxe-inspired)
    function InitializeInstall(const AVersion: string): Boolean;
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
    function CheckBuildPrerequisites(const AVersion: string): Boolean;

  protected
    function ProtectedIsCacheAvailable(const AVersion: string): Boolean;
    function ProtectedUseCachedBuild(const AVersion: string): Boolean;
    function ProtectedIsValidSourceDirectory(const APath: string): Boolean;

  public
    constructor Create(const ASourceRoot: string = '');
    destructor Destroy; override;

    // 源码管理
    function CloneFPCSource(const AVersion: string = 'main'): Boolean;
    function UpdateFPCSource(const AVersion: string = ''): Boolean;
    function SwitchFPCVersion(const AVersion: string): Boolean;
    // 分离职责：仓库管理器
    function Repo: TSourceRepoManager;
    function BuildFPCSource(const AVersion: string = ''): Boolean;
    function InstallFPCVersion(const AVersion: string): Boolean;
    function ListAvailableVersions: TStringArray;
    function ListLocalVersions: TStringArray;

    // 版本信息
    function GetCurrentVersion: string;
    function IsVersionAvailable(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;

    // 路径管理
    function GetFPCSourcePath(const AVersion: string = ''): string;
    function GetFPCBuildPath(const AVersion: string = ''): string;

    // Bootstrap compiler management (FPCUpDeluxe-inspired) - for testing
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetBootstrapPath(const AVersion: string): string;
    { DEPRECATED: Use fpdev-repo for bootstrap compilers instead }
    function GetBootstrapDownloadURL(const AVersion: string): string; deprecated 'Use fpdev-repo instead';
    function DownloadBootstrapCompiler(const AVersion: string): Boolean; deprecated 'Use fpdev-repo instead';

    // 属性
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property CurrentVersion: string read GetCurrentVersion;
  end;

const
  // FPC Git仓库信息 - 使用中央常量
  FPC_GIT_URL = FPC_OFFICIAL_REPO;

  // 支持的FPC版本分支
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
  fphttpclient, opensslsockets, zipper, fpdev.utils.fs, fpdev.utils.process;

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

  // 确保源码根目录存在
  if not DirectoryExists(FSourceRoot) then
    EnsureDir(FSourceRoot);
end;

function TFPCSourceManager.Repo: TSourceRepoManager;
begin
  // 简单工厂：每次返回一个轻量对象，避免引入持久字段
  Result := TSourceRepoManager.Create(FSourceRoot);
end;

destructor TFPCSourceManager.Destroy;
begin
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

function TFPCSourceManager.GetVersionFromBranch(const ABranch: string): string;
var
  i: Integer;
begin
  Result := ABranch;

  // 从分支名推断版本
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Branch, ABranch) then
    begin
      Result := FPC_VERSIONS[i].Version;
      Break;
    end;
  end;
end;

function TFPCSourceManager.ExecuteGitCommand(const ACommand: string; const AWorkingDir: string): Boolean;
var
  ExitCode: Integer;
  OldDir: string;
begin
  Result := False;

  if AWorkingDir <> '' then

  OldDir := GetCurrentDir;
  try
    if (AWorkingDir <> '') and DirectoryExists(AWorkingDir) then
      SetCurrentDir(AWorkingDir);

    ExitCode := ExecuteProcess('git', ACommand.Split(' '));
    Result := ExitCode = 0;

  finally
    SetCurrentDir(OldDir);
  end;
end;

function TFPCSourceManager.ExecuteCommand(const AProgram: string; const AArgs: array of string; const AWorkingDir: string): Boolean;
var
  ExitCode: Integer;
  OldDir: string;
  Args: TStringArray;
  i: Integer;
begin
  Result := False;
  Args := nil;

  if AWorkingDir <> '' then

  // 转换参数数组
  SetLength(Args, Length(AArgs));
  for i := 0 to High(AArgs) do
    Args[i] := AArgs[i];

  OldDir := GetCurrentDir;
  try
    if (AWorkingDir <> '') and DirectoryExists(AWorkingDir) then
      SetCurrentDir(AWorkingDir);

    ExitCode := ExecuteProcess(AProgram, Args);
    Result := ExitCode = 0;

  finally
    SetCurrentDir(OldDir);
  end;
end;

function TFPCSourceManager.CloneFPCSource(const AVersion: string): Boolean;
begin
  // 代理到 SourceRepoManager，保持现有日志与行为最小变更
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
  if Result then WriteLn('✓ FPC source updated successfully (fetch)') else WriteLn('✗ FPC source update failed (fetch)');
end;

function TFPCSourceManager.SwitchFPCVersion(const AVersion: string): Boolean;
begin
  if not IsVersionInstalled(AVersion) then
  begin
    Exit(False);
  end;
  Result := Repo.SwitchFPCVersion(AVersion);
  if Result then
  begin
    FCurrentVersion := AVersion;
  end
  else
end;

function TFPCSourceManager.ListAvailableVersions: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FPC_VERSIONS));
  for i := 0 to High(FPC_VERSIONS) do
    Result[i] := FPC_VERSIONS[i].Version;
end;

function TFPCSourceManager.ListLocalVersions: TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName, Version: string;
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
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FPC_VERSIONS) do
  begin
    if SameText(FPC_VERSIONS[i].Version, AVersion) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TFPCSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := DirectoryExists(GetSourcePath(AVersion));
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

  if not DirectoryExists(SourcePath) then
    Exit;

  WriteLn;

  // Build FPC using make (requires bootstrap compiler)
  Result := ExecuteCommand('make', ['clean', 'all'], SourcePath);
end;

function TFPCSourceManager.InstallFPCVersion(const AVersion: string): Boolean;
var
  Version: string;
  CacheDir, CachePath: string;
  CacheMeta: TStringList;
begin
  Result := False;
  Version := AVersion;

  WriteLn;

  // Step 1: Initialize build environment
  FCurrentStep := bsInit;
  if not ReportBuildStep(bsInit, '初始化构建环境') then Exit;
  if not InitializeInstall(Version) then
  begin
    Exit;
  end;

  // Step 2: Ensure bootstrap compiler
  FCurrentStep := bsBootstrap;
  if not ReportBuildStep(bsBootstrap, '检查Bootstrap编译器') then Exit;
  if not EnsureBootstrapCompiler(Version) then
  begin
    Exit;
  end;

  // Step 3: Smart clone source code (only if needed)
  FCurrentStep := bsClone;
  if not ReportBuildStep(bsClone, '智能克隆FPC源码') then Exit;
  if not CloneFPCSource(Version) then
  begin
    Exit;
  end;

  // Optional: reuse cached build if available
  if FUseCache and IsCacheAvailable(Version) then
  begin
    if UseCachedBuild(Version) then
    begin
      FCurrentStep := bsConfig;
      if not ReportBuildStep(bsConfig, '测试构建结果') then Exit;
      if not TestBuildResults(Version) then
      begin
        Exit;
      end;

      // Finished (cache path)
      FCurrentStep := bsFinished;
      ReportBuildStep(bsFinished, 'FPC构建测试完成');

      WriteLn;
      Result := True;
      Exit;
    end;
  end;

  // Step 4: Build compiler
  FCurrentStep := bsCompiler;
  if not ReportBuildStep(bsCompiler, '构建FPC编译器') then Exit;
  if not BuildFPCCompiler(Version) then
  begin
    Exit;
  end;

  // Step 4: Build RTL
  FCurrentStep := bsRTL;
  if not ReportBuildStep(bsRTL, '构建FPC RTL') then Exit;
  if not BuildFPCRTL(Version) then
  begin
    Exit;
  end;

  // Build packages
  FCurrentStep := bsPackages;
  if not ReportBuildStep(bsPackages, '构建FPC包') then Exit;
  if not BuildFPCPackages(Version) then
    Exit;

  // Step 6: Test build results
  FCurrentStep := bsConfig;
  if not ReportBuildStep(bsConfig, '测试构建结果') then Exit;
  if not TestBuildResults(Version) then
  begin
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
  ReportBuildStep(bsFinished, 'FPC构建测试完成');

  WriteLn;
  Result := True;
end;

// Platform detection for bootstrap download
function TFPCSourceManager.DetectPlatformArch: TPlatformInfo;
begin
  // Initialize result
  Result.Platform := '';
  Result.Architecture := '';

  // Detect platform
  {$IFDEF MSWINDOWS}
    {$IFDEF CPU64}
    Result.Platform := 'Win64';
    Result.Architecture := 'x86_64-win64';
    {$ELSE}
    Result.Platform := 'Win32';
    Result.Architecture := 'i386-win32';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPU64}
    Result.Platform := 'Linux';
    Result.Architecture := 'x86_64-linux';
    {$ELSE}
    Result.Platform := 'Linux';
    Result.Architecture := 'i386-linux';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUAARCH64}
    Result.Platform := 'macOS';
    Result.Architecture := 'aarch64-darwin';
    {$ELSE}
    Result.Platform := 'macOS';
    Result.Architecture := 'x86_64-darwin';
    {$ENDIF}
  {$ENDIF}
end;

// Bootstrap compiler management (FPCUpDeluxe-inspired)
function TFPCSourceManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  // Based on FPCUpDeluxe logic: determine required bootstrap version
  if (ATargetVersion = 'main') or (ATargetVersion = '3.3.1') then
    Result := '3.2.2'
  else if (ATargetVersion = '3.2.2') or (ATargetVersion = '3.2.0') then
    Result := '3.0.4'
  else if (ATargetVersion = '3.0.4') or (ATargetVersion = '3.0.2') then
    Result := '2.6.4'
  else
    Result := '3.2.2'; // Default to stable version
end;

function TFPCSourceManager.FindSystemFPC: string;
begin
  Result := '';
  // Try to find system FPC compiler
  if ExecuteCommand('fpc', ['-v'], '') then
    Result := 'fpc'; // System FPC available
end;

function TFPCSourceManager.IsCompatibleBootstrap(const ACompilerPath, ARequiredVersion: string): Boolean;
var
  LResult: TProcessResult;
  DetectedVersion: string;
  ReqMajor, ReqMinor, DetMajor, DetMinor: Integer;

  procedure ParseVersion(const Ver: string; out Major, Minor: Integer);
  var
    P: Integer;
    S: string;
  begin
    Major := 0;
    Minor := 0;
    S := Ver;
    P := Pos('.', S);
    if P > 0 then
    begin
      TryStrToInt(Copy(S, 1, P - 1), Major);
      Delete(S, 1, P);
      P := Pos('.', S);
      if P > 0 then
        TryStrToInt(Copy(S, 1, P - 1), Minor)
      else
        TryStrToInt(S, Minor);
    end;
  end;

begin
  Result := False;

  // Basic check: file must exist
  if (ACompilerPath = '') or (not FileExists(ACompilerPath)) then
    Exit;

  // If no required version specified, just check existence
  if ARequiredVersion = '' then
  begin
    Result := True;
    Exit;
  end;

  // Execute compiler to get version
  LResult := TProcessExecutor.Execute(ACompilerPath, ['-iV'], '');
  if LResult.Success then
  begin
    DetectedVersion := Trim(LResult.StdOut);
    // Handle multi-line output - take first line
    if Pos(LineEnding, DetectedVersion) > 0 then
      DetectedVersion := Trim(Copy(DetectedVersion, 1, Pos(LineEnding, DetectedVersion) - 1));
  end
  else
    Exit;

  if DetectedVersion = '' then
    Exit;

  // Parse and compare versions (major.minor must match or be compatible)
  ParseVersion(ARequiredVersion, ReqMajor, ReqMinor);
  ParseVersion(DetectedVersion, DetMajor, DetMinor);

  // Bootstrap compiler must be same major version and same or higher minor
  // For example: 3.2.0 can build 3.2.2, but 3.0.4 cannot build 3.2.2
  Result := (DetMajor = ReqMajor) and (DetMinor >= ReqMinor);
end;

function TFPCSourceManager.GetBootstrapPath(const AVersion: string): string;
begin
  Result := FSourceRoot + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function TFPCSourceManager.GetBootstrapDownloadURL(const AVersion: string): string;
var
  PlatformInfo: TPlatformInfo;
begin
  // DEPRECATED: This function uses SourceForge URLs which are no longer supported.
  // Bootstrap compilers should be downloaded from fpdev-repo instead.
  // See docs/REPO_SPECIFICATION.md for the new repository format.

  // Detect platform and architecture
  PlatformInfo := DetectPlatformArch;

  // Legacy SourceForge download URL (kept for backward compatibility)
  // Format: https://sourceforge.net/projects/freepascal/files/{Platform}/{Version}/fpc-{Version}.{Arch}.zip/download
  Result := Format('https://sourceforge.net/projects/freepascal/files/%s/%s/fpc-%s.%s.zip/download',
    [PlatformInfo.Platform, AVersion, AVersion, PlatformInfo.Architecture]);
end;

function TFPCSourceManager.DownloadBootstrapCompiler(const AVersion: string): Boolean;
var
  URL, TempFile, TempDir, BootstrapRoot, BootstrapPath: string;
  HTTPClient: TFPHTTPClient;
  FileStream: TFileStream;
  Unzipper: TUnZipper;
begin
  Result := False;

  try
    // Get download URL
    URL := GetBootstrapDownloadURL(AVersion);
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

function TFPCSourceManager.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  RequiredVersion, SystemFPC, BootstrapPath: string;
begin
  RequiredVersion := GetRequiredBootstrapVersion(ATargetVersion);

  // Check system FPC
  SystemFPC := FindSystemFPC;
  if IsCompatibleBootstrap(SystemFPC, RequiredVersion) then
  begin
    FBootstrapCompiler := SystemFPC;
    Exit(True);
  end;

  // Check downloaded bootstrap
  BootstrapPath := GetBootstrapPath(RequiredVersion);
  if FileExists(BootstrapPath) then
  begin
    FBootstrapCompiler := BootstrapPath;
    Exit(True);
  end;

  // Download bootstrap compiler
  Result := DownloadBootstrapCompiler(RequiredVersion);
  if Result then
  begin
    FBootstrapCompiler := GetBootstrapPath(RequiredVersion);
  end;
end;

// Step-by-step build process (FPCUpDeluxe-inspired)
function TFPCSourceManager.InitializeInstall(const AVersion: string): Boolean;
begin
  // AVersion parameter reserved for future use
  // Create necessary directories
  EnsureDir(FSourceRoot);
  EnsureDir(FSourceRoot + PathDelim + 'bootstrap');
  Result := True;
end;

function TFPCSourceManager.BuildFPCCompiler(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin

  // 代理到 BuildManager（目前为占位实现，后续逐步迁移真实逻辑）
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.BuildCompiler(AVersion);
    WriteLn('Log file: ', LBM.LogFileName);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.BuildFPCRTL(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
  try
    Result := LBM.BuildRTL(AVersion);
  finally
    LBM.Free;
  end;
end;

function TFPCSourceManager.BuildFPCPackages(const AVersion: string): Boolean;
var
  LBM: TBuildManager;
begin
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
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
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
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
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
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
  LBM := TBuildManager.Create(FSourceRoot, FParallelJobs, FVerboseOutput);
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

function TFPCSourceManager.CheckBuildPrerequisites(const AVersion: string): Boolean;
begin
  // AVersion parameter reserved for future use

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

  // 检查基本目录结构
  if not DirectoryExists(APath) then
    Exit;

  // 检查关键目录和文件
  CompilerPath := APath + PathDelim + 'compiler';
  RTLPath := APath + PathDelim + 'rtl';
  MakefilePath := APath + PathDelim + 'Makefile';

  // 验证源码目录的完整性
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
