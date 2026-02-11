unit fpdev.resource.repo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DateUtils, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils.git, fpdev.constants,
  fpdev.output.intf,
  fpdev.resource.repo.types;  // TMirrorInfo, TResourceRepoConfig, TPlatformInfo, etc.

type
  // Re-export types for backward compatibility
  // Types are now defined in fpdev.resource.repo.types

  { TPackageInfo - Alias for TRepoPackageInfo (backward compatibility)
    Note: TRepoPackageInfo is used in the types unit to avoid collision
    with fpdev.package.types.TPackageInfo }
  TPackageInfo = TRepoPackageInfo;

  { 资源仓库管理器
    B068: 线程安全说明
    - 此类设计为单线程使用（命令行工具的正常场景）
    - 懒加载标志 FManifestLoaded 和共享对象 FManifestData 无同步保护
    - 并发访问可能导致重复加载或竞态读写
    - 如需多线程支持，需添加临界区保护 }
  TResourceRepository = class
  private
    FConfig: TResourceRepoConfig;
    FLocalPath: string;
    FLastUpdateCheck: TDateTime;
    FManifestData: TJSONObject;
    FManifestLoaded: Boolean;         // 懒加载标志
    FUserRegion: string;
    FGitOps: TGitOperations;
    FCachedBestMirror: string;      // 缓存最佳镜像
    FMirrorCacheTime: TDateTime;    // 镜像缓存时间
    FMirrorLatencies: array of record
      URL: string;
      Latency: Integer;  // 毫秒，-1 表示不可达
    end;
    FOutput: IOutput;               // 可选输出接口

    procedure Log(const AMsg: string);
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
    function GitClone(const AURL: string): Boolean;
    function GitPull: Boolean;
    function IsGitRepository: Boolean;
    function GetLastCommitHash: string;
    function NeedsUpdate: Boolean;
    function DetectUserRegion: string;
    function SelectBestMirror: string;
    function TestMirrorLatency(const AURL: string; ATimeoutMS: Integer = 5000): Integer;
    { B066: 懒加载辅助 - 返回 Boolean 因为 manifest 是必需资源
      调用方必须检查返回值：if not EnsureManifestLoaded then Exit;
      与 TBuildCache.EnsureIndexLoaded 不同，manifest 加载失败需要显式处理 }
    function EnsureManifestLoaded: Boolean;

  public
    constructor Create(const AConfig: TResourceRepoConfig);
    destructor Destroy; override;

    // 仓库操作
    function Initialize: Boolean;
    function Update(const AForce: Boolean = False): Boolean;
    function GetStatus: string;

    // 清单操作
    function LoadManifest: Boolean;
    function GetManifestVersion: string;

    // 资源查询 - 引导编译器
    function HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
    function GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
    function GetBootstrapExecutable(const AVersion, APlatform: string): string;

    // 引导编译器版本映射（多版本支持）
    function GetRequiredBootstrapVersion(const AFPCVersion: string): string;
    function GetBootstrapVersionFromMakefile(const ASourcePath: string): string;
    function ListBootstrapVersions: SysUtils.TStringArray;
    function FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;

    // 资源查询 - 二进制发布（FPC/Lazarus 工具链）
    function HasBinaryRelease(const AVersion, APlatform: string): Boolean;
    function GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
    function GetBinaryReleasePath(const AVersion, APlatform: string): string;

    // 资源查询 - 交叉编译工具链
    function HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;
    function GetCrossToolchainInfo(const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
    function ListCrossTargets: SysUtils.TStringArray;

    // 资源查询 - 组件包
    function HasPackage(const AName, AVersion: string): Boolean;
    function GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;
    function ListPackages(const ACategory: string = ''): SysUtils.TStringArray;
    function SearchPackages(const AKeyword: string): SysUtils.TStringArray;

    // 资源提取/安装
    function InstallBootstrap(const AVersion, APlatform, ADestDir: string): Boolean;
    function InstallBinaryRelease(const AVersion, APlatform, ADestDir: string): Boolean;
    function InstallCrossToolchain(const ATarget, AHostPlatform, ADestDir: string): Boolean;
    function InstallPackage(const AName, AVersion, ADestDir: string): Boolean;
    function VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;

    // 镜像管理
    function GetMirrors: TMirrorArray;
    function GetBestMirrorURL: string;
    property UserRegion: string read FUserRegion write FUserRegion;

    // 属性
    property LocalPath: string read FLocalPath;
    property LastUpdateCheck: TDateTime read FLastUpdateCheck;
    property Output: IOutput read FOutput write FOutput;
  end;

  // Use SysUtils.TStringArray instead of local declaration

  { 辅助函数 }
  function GetCurrentPlatform: string;
  function CreateDefaultConfig: TResourceRepoConfig;
  { Creates config based on user mirror settings.
    AMirror: 'auto', 'github', 'gitee', or custom URL
    ACustomURL: Custom repository URL (highest priority, overrides AMirror) }
  function CreateConfigWithMirror(const AMirror: string; const ACustomURL: string = ''): TResourceRepoConfig;

implementation

uses
  fpdev.resource.repo.bootstrap,
  fpdev.resource.repo.mirror,
  fpdev.resource.repo.package,
  fpdev.resource.repo.search,
  fpdev.resource.repo.binary,
  fpdev.resource.repo.cross,
  fpdev.resource.repo.install,
  fpdev.paths;  // 用于GetUserConfigDir等

{ 辅助函数实现 }

function GetCurrentPlatform: string;
begin
  {$IFDEF LINUX}
    {$IFDEF CPUX86_64}
    Result := 'linux-x86_64';
    {$ENDIF}
    {$IFDEF CPUAARCH64}
    Result := 'linux-aarch64';
    {$ENDIF}
    {$IFDEF CPUI386}
    Result := 'linux-i386';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF MSWINDOWS}
    {$IFDEF CPUX86_64}
    Result := 'windows-x86_64';
    {$ENDIF}
    {$IFDEF CPUI386}
    Result := 'windows-i386';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUX86_64}
    Result := 'darwin-x86_64';
    {$ENDIF}
    {$IFDEF CPUAARCH64}
    Result := 'darwin-aarch64';
    {$ENDIF}
  {$ENDIF}

  if Result = '' then
    Result := 'unknown';
end;

function CreateDefaultConfig: TResourceRepoConfig;
begin
  // Ensure data root is initialized
  GetDataRoot;
  Result.URL := FPDEV_REPO_URL;  // Use central constant
  SetLength(Result.Mirrors, 1);
  Result.Mirrors[0] := FPDEV_REPO_MIRROR;  // Use central constant

  {$IFDEF MSWINDOWS}
  Result.LocalPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
                      FPDEV_CONFIG_DIR + PathDelim + 'resources';
  {$ELSE}
  Result.LocalPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
                      FPDEV_CONFIG_DIR + PathDelim + 'resources';
  {$ENDIF}

  Result.Branch := 'main';
  Result.AutoUpdate := True;
  Result.UpdateIntervalHours := 24;
end;

function CreateConfigWithMirror(const AMirror: string; const ACustomURL: string): TResourceRepoConfig;
begin
  // Start with default config
  Result := CreateDefaultConfig;

  // Custom URL has highest priority
  if ACustomURL <> '' then
  begin
    Result.URL := ACustomURL;
    SetLength(Result.Mirrors, 0);  // No fallback mirrors for custom URL
    Exit;
  end;

  // Handle mirror selection
  if SameText(AMirror, 'github') then
  begin
    Result.URL := FPDEV_REPO_GITHUB;
    SetLength(Result.Mirrors, 1);
    Result.Mirrors[0] := FPDEV_REPO_GITEE;
  end
  else if SameText(AMirror, 'gitee') then
  begin
    Result.URL := FPDEV_REPO_GITEE;
    SetLength(Result.Mirrors, 1);
    Result.Mirrors[0] := FPDEV_REPO_GITHUB;
  end
  else if SameText(AMirror, 'auto') or (AMirror = '') then
  begin
    // Auto-detect: use default (GitHub primary, Gitee fallback)
    // Future: could detect region and swap order for China users
    Result.URL := FPDEV_REPO_GITHUB;
    SetLength(Result.Mirrors, 1);
    Result.Mirrors[0] := FPDEV_REPO_GITEE;
  end
  else
  begin
    // Treat as custom URL
    Result.URL := AMirror;
    SetLength(Result.Mirrors, 0);
  end;
end;

{ TResourceRepository }

procedure TResourceRepository.Log(const AMsg: string);
begin
  if Assigned(FOutput) then
    FOutput.WriteLn(AMsg);
end;

procedure TResourceRepository.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  if Assigned(FOutput) then
    FOutput.WriteLn(Format(AFormat, AArgs));
end;

constructor TResourceRepository.Create(const AConfig: TResourceRepoConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FLocalPath := AConfig.LocalPath;
  FLastUpdateCheck := 0;
  FManifestData := nil;
  FManifestLoaded := False;
  FGitOps := TGitOperations.Create;
  FCachedBestMirror := '';
  FMirrorCacheTime := 0;
  SetLength(FMirrorLatencies, 0);
end;

destructor TResourceRepository.Destroy;
begin
  if Assigned(FGitOps) then
    FGitOps.Free;
  if Assigned(FManifestData) then
    FManifestData.Free;
  inherited Destroy;
end;

function TResourceRepository.IsGitRepository: Boolean;
begin
  // Use TGitOperations for more accurate detection (supports libgit2)
  Result := FGitOps.IsRepository(FLocalPath);
end;

function TResourceRepository.GitClone(const AURL: string): Boolean;
var
  ParentDir: string;
begin
  Result := False;

  // Check if git backend is available
  if FGitOps.Backend = gbNone then
  begin
    Log('Error: No Git backend available (neither libgit2 nor git command found)');
    Exit;
  end;

  LogFmt('Cloning resource repository from %s...', [AURL]);
  LogFmt('  Using backend: %s', [GitBackendToString(FGitOps.Backend)]);

  // 确保父目录存在
  ParentDir := ExtractFileDir(FLocalPath);
  if not DirectoryExists(ParentDir) then
    EnsureDir(ParentDir);

  // 克隆仓库 - 使用 TGitOperations
  Result := FGitOps.Clone(AURL, FLocalPath, FConfig.Branch);

  if Result then
    Log('Resource repository cloned successfully')
  else
    LogFmt('Failed to clone from %s: %s', [AURL, FGitOps.LastError]);
end;

function TResourceRepository.GitPull: Boolean;
begin
  // Check if git backend is available
  if FGitOps.Backend = gbNone then
  begin
    Log('Warning: No Git backend available, skipping update');
    Exit(False);
  end;

  Log('Updating resource repository...');
  Result := FGitOps.Pull(FLocalPath);

  if Result then
    Log('Resource repository updated')
  else
    LogFmt('Warning: Failed to update (using cached version): %s', [FGitOps.LastError]);
end;

function TResourceRepository.GetLastCommitHash: string;
var
  LResult: TProcessResult;
begin
  if not IsGitRepository then
    Exit('unknown');
  LResult := TProcessExecutor.Execute('git', ['rev-parse', '--short', 'HEAD'], FLocalPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else
    Result := 'unknown';
end;

function TResourceRepository.NeedsUpdate: Boolean;
var
  HoursSinceUpdate: Double;
begin
  if not FConfig.AutoUpdate then
    Exit(False);

  if FLastUpdateCheck = 0 then
    Exit(True);

  HoursSinceUpdate := HoursBetween(Now, FLastUpdateCheck);
  Result := HoursSinceUpdate >= FConfig.UpdateIntervalHours;
end;

function TResourceRepository.Initialize: Boolean;
var
  i: Integer;
  Success: Boolean;
begin
  Result := False;

  // 检查是否已经克隆
  if IsGitRepository then
  begin
    LogFmt('Resource repository already exists at: %s', [FLocalPath]);
    LogFmt('Commit: %s', [GetLastCommitHash]);

    // 如果需要更新
    if NeedsUpdate then
    begin
      GitPull;  // 更新失败也不影响使用
      FLastUpdateCheck := Now;
    end;

    Result := True;
  end
  else
  begin
    // 首次克隆 - 尝试主URL和所有镜像
    Success := GitClone(FConfig.URL);

    if not Success then
    begin
      Log('Failed to clone from primary URL, trying mirrors...');
      for i := 0 to High(FConfig.Mirrors) do
      begin
        LogFmt('Trying mirror %d: %s', [i + 1, FConfig.Mirrors[i]]);
        Success := GitClone(FConfig.Mirrors[i]);
        if Success then
          Break;
      end;
    end;

    if Success then
    begin
      FLastUpdateCheck := Now;
      Result := True;
    end
    else
    begin
      Log('Failed to clone resource repository from any source');
      Result := False;
    end;
  end;

  // 加载清单
  if Result then
    Result := LoadManifest;
end;

function TResourceRepository.Update(const AForce: Boolean): Boolean;
begin
  if not IsGitRepository then
  begin
    Log('Error: Resource repository not initialized');
    Exit(False);
  end;

  if AForce or NeedsUpdate then
  begin
    Result := GitPull;
    if Result then
    begin
      FLastUpdateCheck := Now;
      // B064: 重新加载清单并检查返回值
      if not LoadManifest then
        Log('Warning: Git pull succeeded but manifest reload failed');
    end;
  end
  else
  begin
    LogFmt('Resource repository is up to date (last check: %s)', [DateTimeToStr(FLastUpdateCheck)]);
    Result := True;
  end;
end;

function TResourceRepository.GetStatus: string;
begin
  if not IsGitRepository then
    Exit('Not initialized');

  Result := 'Initialized at: ' + FLocalPath + LineEnding +
            'Commit: ' + GetLastCommitHash + LineEnding +
            'Last update check: ' + DateTimeToStr(FLastUpdateCheck);
end;

function TResourceRepository.LoadManifest: Boolean;
var
  ManifestPath: string;
  ManifestContent: string;
  Parser: TJSONParser;
  F: TextFile;
  Line: string;
begin
  Result := False;

  ManifestPath := FLocalPath + PathDelim + 'manifest.json';
  if not FileExists(ManifestPath) then
  begin
    Log('Warning: manifest.json not found in resource repository');
    // B064: 确保状态一致
    FManifestLoaded := False;
    FreeAndNil(FManifestData);
    Exit;
  end;

  try
    // 读取文件
    AssignFile(F, ManifestPath);
    Reset(F);
    try
      ManifestContent := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        ManifestContent := ManifestContent + Line;
      end;
    finally
      CloseFile(F);
    end;

    // 解析JSON - B064: 使用 FreeAndNil 避免悬垂指针
    FreeAndNil(FManifestData);

    Parser := TJSONParser.Create(ManifestContent, []);
    try
      FManifestData := Parser.Parse as TJSONObject;
      Result := Assigned(FManifestData);
      FManifestLoaded := Result;

      if Result then
        LogFmt('Manifest loaded (version: %s)', [GetManifestVersion])
      else
      begin
        // B064: 解析返回 nil 时确保状态一致
        FManifestLoaded := False;
        Log('Warning: Failed to parse manifest.json');
      end;
    finally
      Parser.Free;
    end;

  except
    on E: Exception do
    begin
      LogFmt('Error loading manifest: %s', [E.Message]);
      // B064: 异常时确保状态一致
      FManifestLoaded := False;
      FreeAndNil(FManifestData);
      Result := False;
    end;
  end;
end;

function TResourceRepository.EnsureManifestLoaded: Boolean;
begin
  if FManifestLoaded and Assigned(FManifestData) then
    Exit(True);
  Result := LoadManifest;
end;

{ B226: Build install context for delegation to fpdev.resource.repo.install }
function BuildInstallContext(ARepo: TResourceRepository): TRepoInstallContext;
begin
  Result.LocalPath := ARepo.LocalPath;
  Result.Log := @ARepo.Log;
  Result.LogFmt := @ARepo.LogFmt;
  Result.VerifyChecksum := @ARepo.VerifyChecksum;
end;

function TResourceRepository.GetManifestVersion: string;
begin
  Result := 'unknown';
  if not EnsureManifestLoaded then
    Exit;
  Result := FManifestData.Get('version', 'unknown');
end;

function TResourceRepository.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
var
  BootstrapCompilers: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  Obj: TJSONData;
begin
  Result := False;

  if not EnsureManifestLoaded then
    Exit;

  try
    // Use Find() instead of Objects[] to avoid EJSON exception on missing key
    Obj := FManifestData.Find('bootstrap_compilers', jtObject);
    if not Assigned(Obj) then
      Exit;
    BootstrapCompilers := TJSONObject(Obj);

    Obj := BootstrapCompilers.Find(AVersion, jtObject);
    if not Assigned(Obj) then
      Exit;
    VersionData := TJSONObject(Obj);

    Obj := VersionData.Find('platforms', jtObject);
    if not Assigned(Obj) then
      Exit;
    Platforms := TJSONObject(Obj);

    Result := Platforms.IndexOfName(APlatform) >= 0;
  except
    on E: Exception do
    begin
      LogFmt('Error checking bootstrap compiler: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
var
  BootstrapCompilers: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  Obj: TJSONData;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  if not EnsureManifestLoaded then
    Exit;

  try
    // Use Find() instead of Objects[] to avoid EJSON exception on missing key
    Obj := FManifestData.Find('bootstrap_compilers', jtObject);
    if not Assigned(Obj) then
      Exit;
    BootstrapCompilers := TJSONObject(Obj);

    Obj := BootstrapCompilers.Find(AVersion, jtObject);
    if not Assigned(Obj) then
      Exit;
    VersionData := TJSONObject(Obj);

    AInfo.Path := VersionData.Get('path', '');

    Obj := VersionData.Find('platforms', jtObject);
    if not Assigned(Obj) then
      Exit;
    Platforms := TJSONObject(Obj);

    Obj := Platforms.Find(APlatform, jtObject);
    if not Assigned(Obj) then
      Exit;
    PlatformData := TJSONObject(Obj);

    // v2.0 fields: url and mirrors
    AInfo.URL := PlatformData.Get('url', '');
    Obj := PlatformData.Find('mirrors', jtArray);
    if Assigned(Obj) then
    begin
      MirrorsArray := TJSONArray(Obj);
      SetLength(AInfo.Mirrors, MirrorsArray.Count);
      for i := 0 to MirrorsArray.Count - 1 do
        AInfo.Mirrors[i] := MirrorsArray.Strings[i];
    end
    else
      SetLength(AInfo.Mirrors, 0);

    // v1.0 backward compatibility: archive field
    if AInfo.URL = '' then
      AInfo.Path := PlatformData.Get('archive', AInfo.Path);

    // Common fields
    AInfo.Executable := PlatformData.Get('executable', '');
    AInfo.SHA256 := PlatformData.Get('sha256', '');
    AInfo.Size := PlatformData.Get('size', Int64(0));
    AInfo.Tested := PlatformData.Get('tested', False);

    Result := (AInfo.Executable <> '') or (AInfo.URL <> '') or (AInfo.Path <> '');
  except
    on E: Exception do
    begin
      LogFmt('Error getting bootstrap info: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetBootstrapExecutable(const AVersion, APlatform: string): string;
var
  Info: TPlatformInfo;
begin
  Result := '';
  if GetBootstrapInfo(AVersion, APlatform, Info) then
    Result := FLocalPath + PathDelim + Info.Executable;
end;

function TResourceRepository.GetRequiredBootstrapVersion(const AFPCVersion: string): string;
begin
  // B064: 检查返回值，失败时使用 fallback
  if not EnsureManifestLoaded then
  begin
    Result := ResourceRepoGetRequiredBootstrapVersion(nil, AFPCVersion);
    Exit;
  end;
  try
    Result := ResourceRepoGetRequiredBootstrapVersion(FManifestData, AFPCVersion);
  except
    on E: Exception do
    begin
      LogFmt('Error getting bootstrap version from manifest: %s', [E.Message]);
      Result := ResourceRepoGetRequiredBootstrapVersion(nil, AFPCVersion);
    end;
  end;
end;

function TResourceRepository.GetBootstrapVersionFromMakefile(const ASourcePath: string): string;
begin
  try
    Result := ResourceRepoGetBootstrapVersionFromMakefile(ASourcePath);
  except
    on E: Exception do
    begin
      LogFmt('Error parsing bootstrap version from Makefile: %s', [E.Message]);
      Result := '';
    end;
  end;
end;

function TResourceRepository.ListBootstrapVersions: SysUtils.TStringArray;
begin
  Result := nil;  // B064: 初始化 managed type
  // B064: 检查返回值，失败时返回空数组
  if not EnsureManifestLoaded then
    Exit;
  try
    Result := ResourceRepoListBootstrapVersions(FManifestData);
  except
    on E: Exception do
    begin
      LogFmt('Error listing bootstrap versions: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

function TResourceRepository.FindBestBootstrapVersion(const AFPCVersion, APlatform: string): string;
var
  RequiredVersion: string;
  AvailableVersions: SysUtils.TStringArray;
  i: Integer;
  VersionChain: array of string;
  ChainIdx: Integer;
begin
  Result := '';

  // First, get the required bootstrap version from mapping
  RequiredVersion := GetRequiredBootstrapVersion(AFPCVersion);
  if RequiredVersion = '' then
  begin
    LogFmt('Warning: No bootstrap version mapping found for FPC %s', [AFPCVersion]);
    // Default to 3.2.2 for unknown versions
    RequiredVersion := '3.2.2';
  end;

  // Check if this exact version is available for this platform
  if HasBootstrapCompiler(RequiredVersion, APlatform) then
  begin
    Result := RequiredVersion;
    Exit;
  end;

  // Build version fallback chain (try older versions)
  VersionChain := nil;
  SetLength(VersionChain, 8);
  VersionChain[0] := '3.2.2';
  VersionChain[1] := '3.2.0';
  VersionChain[2] := '3.0.4';
  VersionChain[3] := '3.0.2';
  VersionChain[4] := '3.0.0';
  VersionChain[5] := '2.6.4';
  VersionChain[6] := '2.6.2';
  VersionChain[7] := '2.6.0';

  // Find the position of required version in chain
  ChainIdx := -1;
  for i := 0 to High(VersionChain) do
  begin
    if VersionChain[i] = RequiredVersion then
    begin
      ChainIdx := i;
      Break;
    end;
  end;

  // If not found in chain, start from the beginning
  if ChainIdx < 0 then
    ChainIdx := 0;

  // Try each version in the chain starting from required version
  for i := ChainIdx to High(VersionChain) do
  begin
    if HasBootstrapCompiler(VersionChain[i], APlatform) then
    begin
      if VersionChain[i] <> RequiredVersion then
        LogFmt('Note: Using bootstrap %s instead of %s (fallback due to availability)',
               [VersionChain[i], RequiredVersion]);
      Result := VersionChain[i];
      Exit;
    end;
  end;

  // Last resort: try any available version
  AvailableVersions := ListBootstrapVersions;
  for i := 0 to High(AvailableVersions) do
  begin
    if HasBootstrapCompiler(AvailableVersions[i], APlatform) then
    begin
      LogFmt('Warning: Using bootstrap %s (only available version for platform %s)',
             [AvailableVersions[i], APlatform]);
      Result := AvailableVersions[i];
      Exit;
    end;
  end;

  LogFmt('Error: No bootstrap compiler available for platform %s', [APlatform]);
end;

function TResourceRepository.VerifyChecksum(const AFile, AExpectedSHA256: string): Boolean;
var
  LResult: TProcessResult;
  ActualSHA256: string;
begin
  Result := False;

  if AExpectedSHA256 = '' then
  begin
    Log('Warning: No checksum provided, skipping verification');
    Exit(True);  // 没有校验和要求，认为通过
  end;

  LResult := TProcessExecutor.Execute('sha256sum', [AFile], '');
  if LResult.Success then
  begin
    // 提取哈希值（第一个字段）
    ActualSHA256 := Trim(Copy(LResult.StdOut, 1, Pos(' ', LResult.StdOut) - 1));

    Result := SameText(ActualSHA256, AExpectedSHA256);

    if Result then
      LogFmt('Checksum verified: %s', [AFile])
    else
    begin
      LogFmt('Checksum mismatch for: %s', [AFile]);
      LogFmt('  Expected: %s', [AExpectedSHA256]);
      LogFmt('  Got:      %s', [ActualSHA256]);
    end;
  end
  else if LResult.ErrorMessage <> '' then
    LogFmt('Error verifying checksum: %s', [LResult.ErrorMessage]);
end;

function TResourceRepository.HasBinaryRelease(const AVersion, APlatform: string): Boolean;
begin
  Result := False;

  if not EnsureManifestLoaded then
    Exit;

  try
    // B067: 使用 helper 函数
    Result := ResourceRepoHasBinaryRelease(FManifestData, AVersion, APlatform);
  except
    on E: Exception do
    begin
      LogFmt('Error checking binary release: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
var
  BinaryInfo: TBinaryReleaseInfo;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  if not EnsureManifestLoaded then
    Exit;

  try
    // B067: 使用 helper 函数
    if not ResourceRepoGetBinaryReleaseInfo(FManifestData, AVersion, APlatform, BinaryInfo) then
      Exit;

    // 转换 TBinaryReleaseInfo -> TPlatformInfo
    AInfo.Path := BinaryInfo.Path;
    AInfo.URL := BinaryInfo.URL;
    AInfo.SHA256 := BinaryInfo.SHA256;
    AInfo.Size := BinaryInfo.Size;
    AInfo.Tested := BinaryInfo.Tested;
    SetLength(AInfo.Mirrors, Length(BinaryInfo.Mirrors));
    for i := 0 to High(BinaryInfo.Mirrors) do
      AInfo.Mirrors[i] := BinaryInfo.Mirrors[i];

    Result := True;
  except
    on E: Exception do
    begin
      LogFmt('Error getting binary release info: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetBinaryReleasePath(const AVersion, APlatform: string): string;
var
  Info: TPlatformInfo;
begin
  Result := '';
  if GetBinaryReleaseInfo(AVersion, APlatform, Info) then
    Result := FLocalPath + PathDelim + Info.Executable;
end;

function TResourceRepository.InstallBinaryRelease(const AVersion, APlatform, ADestDir: string): Boolean;
var
  Info: TPlatformInfo;
begin
  Result := False;

  // Get release info
  if not GetBinaryReleaseInfo(AVersion, APlatform, Info) then
  begin
    Log('Error: Binary release info not found');
    Exit;
  end;

  // B226: Delegate to install helper
  Result := RepoInstallBinaryRelease(BuildInstallContext(Self), Info, AVersion, APlatform, ADestDir);
end;

function TResourceRepository.InstallBootstrap(const AVersion, APlatform, ADestDir: string): Boolean;
var
  Info: TPlatformInfo;
begin
  Result := False;

  // Get bootstrap info
  if not GetBootstrapInfo(AVersion, APlatform, Info) then
  begin
    Log('Error: Bootstrap compiler info not found');
    Exit;
  end;

  // B226: Delegate to install helper
  Result := RepoInstallBootstrapCompiler(BuildInstallContext(Self), Info, AVersion, APlatform, ADestDir);
end;

{ Mirror Management }

function TResourceRepository.DetectUserRegion: string;
begin
  Result := ResourceRepoDetectUserRegion(@Log);
end;

function TResourceRepository.TestMirrorLatency(const AURL: string; ATimeoutMS: Integer): Integer;
begin
  Result := ResourceRepoTestMirrorLatency(AURL, ATimeoutMS, @Log);
end;

function TResourceRepository.SelectBestMirror: string;
const
  CACHE_TTL_HOURS = 1;  // 镜像缓存 1 小时
var
  Region: string;
  i: Integer;
  CandidateMirrors: array of string;
  CandidateLatencies: TResourceRepoMirrorLatencyArray;
  CandidateCount: Integer;
  BestMirror: string;
begin
  Result := FConfig.URL;  // Default to primary URL

  // 检查缓存
  if ResourceRepoTryGetCachedMirror(FCachedBestMirror, FMirrorCacheTime,
    CACHE_TTL_HOURS, Now, Result) then
    Exit;

  if not EnsureManifestLoaded then
    Exit;

  // Detect or use configured region
  if FUserRegion <> '' then
    Region := FUserRegion
  else
    Region := DetectUserRegion;

  CandidateMirrors := nil;
  CandidateLatencies := nil;

  try
    CandidateMirrors := ResourceRepoBuildCandidateMirrors(
      FManifestData, Region, FConfig.URL, FConfig.Mirrors);

    BestMirror := ResourceRepoSelectBestMirrorFromCandidates(
      CandidateMirrors, @TestMirrorLatency, 3000, CandidateLatencies);

    CandidateCount := Length(CandidateMirrors);
    SetLength(FMirrorLatencies, CandidateCount);

    for i := 0 to CandidateCount - 1 do
    begin
      FMirrorLatencies[i].URL := CandidateMirrors[i];
      if i <= High(CandidateLatencies) then
        FMirrorLatencies[i].Latency := CandidateLatencies[i]
      else
        FMirrorLatencies[i].Latency := -1;
    end;

    if BestMirror <> '' then
      Result := BestMirror;

    // 缓存结果
    ResourceRepoSetCachedMirror(Result, Now, FCachedBestMirror, FMirrorCacheTime);

  except
    on E: Exception do
    begin
      LogFmt('Error selecting best mirror: %s', [E.Message]);
      // Fall back to primary URL on any error
      Result := FConfig.URL;
    end;
  end;
end;

function TResourceRepository.GetMirrors: TMirrorArray;
var
  ParsedMirrors: TResourceRepoMirrorInfoArray;
  i: Integer;
begin
  Result := nil;

  if not EnsureManifestLoaded then
    Exit;

  try
    ParsedMirrors := ResourceRepoGetMirrorsFromManifest(FManifestData);
    SetLength(Result, Length(ParsedMirrors));

    for i := 0 to High(ParsedMirrors) do
    begin
      Result[i].Name := ParsedMirrors[i].Name;
      Result[i].URL := ParsedMirrors[i].URL;
      Result[i].Region := ParsedMirrors[i].Region;
      Result[i].Priority := ParsedMirrors[i].Priority;
    end;
  except
    on E: Exception do
    begin
      LogFmt('Error getting mirrors: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

function TResourceRepository.GetBestMirrorURL: string;
begin
  Result := SelectBestMirror;
end;

{ Cross Toolchain Management }

function TResourceRepository.HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;
begin
  Result := False;

  if not EnsureManifestLoaded then
    Exit;

  try
    // B069: 使用 helper 函数
    Result := ResourceRepoHasCrossToolchain(FManifestData, ATarget, AHostPlatform);
  except
    on E: Exception do
    begin
      LogFmt('Error checking cross toolchain: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetCrossToolchainInfo(const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
var
  CrossInfo: TResourceRepoCrossInfo;
begin
  Result := False;
  System.Initialize(AInfo);

  if not EnsureManifestLoaded then
    Exit;

  try
    // B069: 使用 helper 函数
    if not ResourceRepoGetCrossToolchainInfo(FManifestData, ATarget, AHostPlatform, CrossInfo) then
      Exit;

    // 转换 TResourceRepoCrossInfo -> TCrossToolchainInfo
    AInfo.TargetName := CrossInfo.TargetName;
    AInfo.DisplayName := CrossInfo.DisplayName;
    AInfo.CPU := CrossInfo.CPU;
    AInfo.OS := CrossInfo.OS;
    AInfo.BinutilsPrefix := CrossInfo.BinutilsPrefix;
    AInfo.BinutilsArchive := CrossInfo.BinutilsArchive;
    AInfo.LibsArchive := CrossInfo.LibsArchive;
    AInfo.BinutilsSHA256 := CrossInfo.BinutilsSHA256;
    AInfo.LibsSHA256 := CrossInfo.LibsSHA256;

    Result := True;
  except
    on E: Exception do
    begin
      LogFmt('Error getting cross toolchain info: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.ListCrossTargets: SysUtils.TStringArray;
begin
  Result := nil;

  if not EnsureManifestLoaded then
    Exit;

  try
    // B069: 使用 helper 函数
    Result := ResourceRepoListCrossTargets(FManifestData);
  except
    on E: Exception do
    begin
      LogFmt('Error listing cross targets: %s', [E.Message]);
      SetLength(Result, 0);
    end;
  end;
end;

function TResourceRepository.InstallCrossToolchain(const ATarget, AHostPlatform, ADestDir: string): Boolean;
var
  Info: TCrossToolchainInfo;
begin
  Result := False;

  // Get toolchain info
  if not GetCrossToolchainInfo(ATarget, AHostPlatform, Info) then
  begin
    Log('Error: Cross toolchain info not found');
    Exit;
  end;

  // B226: Delegate to install helper
  Result := RepoInstallCrossToolchain(BuildInstallContext(Self), Info, ATarget, ADestDir);
end;

{ Package Management }

function TResourceRepository.HasPackage(const AName, AVersion: string): Boolean;
var
  Packages: TJSONObject;
  Categories: TJSONArray;
  Obj: TJSONData;
  i: Integer;
begin
  Result := False;
  if AName = '' then; // Suppress unused parameter hint
  if AVersion = '' then; // Suppress unused parameter hint

  if not EnsureManifestLoaded then
    Exit;

  try
    // Check packages section
    // Use Find() instead of Objects[] to avoid EJSON exception on missing key
    Obj := FManifestData.Find('packages', jtObject);
    if not Assigned(Obj) then
      Exit;
    Packages := TJSONObject(Obj);

    // Iterate through categories to find the package
    Obj := Packages.Find('categories', jtArray);
    if Assigned(Obj) then
    begin
      Categories := TJSONArray(Obj);
      for i := 0 to Categories.Count - 1 do
      begin
        // Each category could have packages - simplified check via package index
      end;
    end;

    // Alternative: Check package index file if exists
    // For now, return false until package index is implemented
    Result := False;
  except
    on E: Exception do
    begin
      LogFmt('Error checking package availability: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;
var
  PackageMetaPath: string;
  MetaContent: string;
  Parser: TJSONParser;
  PackageJSON: TJSONObject;
  DepsArray: TJSONArray;
  Obj: TJSONData;
  i: Integer;
  F: TextFile;
  Line: string;
begin
  Result := False;
  System.Initialize(AInfo);
  if AVersion = '' then; // Suppress hint

  // Try to find package metadata file
  PackageMetaPath := ResourceRepoResolvePackageMetaPath(FLocalPath, AName);
  if PackageMetaPath = '' then
    Exit;

  try
    // Read package metadata
    AssignFile(F, PackageMetaPath);
    Reset(F);
    try
      MetaContent := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        MetaContent := MetaContent + Line;
      end;
    finally
      CloseFile(F);
    end;

    // Parse JSON
    Parser := TJSONParser.Create(MetaContent, []);
    try
      PackageJSON := Parser.Parse as TJSONObject;
      try
        AInfo.Name := PackageJSON.Get('name', AName);
        AInfo.Version := PackageJSON.Get('version', '');
        AInfo.Description := PackageJSON.Get('description', '');
        AInfo.Category := PackageJSON.Get('category', '');
        AInfo.Archive := PackageJSON.Get('archive', '');
        AInfo.SHA256 := PackageJSON.Get('sha256', '');
        AInfo.FPCMinVersion := PackageJSON.Get('fpc_min', '');

        // Parse dependencies array
        // Use Find() with type check instead of Arrays[] to avoid potential exceptions
        Obj := PackageJSON.Find('dependencies', jtArray);
        if Assigned(Obj) then
        begin
          DepsArray := TJSONArray(Obj);
          SetLength(AInfo.Dependencies, DepsArray.Count);
          for i := 0 to DepsArray.Count - 1 do
            AInfo.Dependencies[i] := DepsArray.Strings[i];
        end;

        Result := True;
      finally
        PackageJSON.Free;
      end;
    finally
      Parser.Free;
    end;
  except
    on E: Exception do
    begin
      LogFmt('Error checking package availability: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.ListPackages(const ACategory: string): SysUtils.TStringArray;
var
  PackagesDir, CategoryDir: string;
  SR: TSearchRec;
  Count: Integer;
begin
  Result := nil;
  Count := 0;

  PackagesDir := FLocalPath + PathDelim + 'packages';
  if not DirectoryExists(PackagesDir) then
    Exit;

  if ACategory <> '' then
  begin
    // List packages in specific category
    CategoryDir := PackagesDir + PathDelim + ACategory;
    if not DirectoryExists(CategoryDir) then
      Exit;

    if FindFirst(CategoryDir + PathDelim + '*', faDirectory, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
        begin
          SetLength(Result, Count + 1);
          Result[Count] := SR.Name;
          Inc(Count);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end
  else
  begin
    // List all packages from all categories
    if FindFirst(PackagesDir + PathDelim + '*', faDirectory, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
        begin
          // This is a category directory, scan its contents
          CategoryDir := PackagesDir + PathDelim + SR.Name;
          // Recursively add packages from this category
          // For simplicity, just add category names for now
          SetLength(Result, Count + 1);
          Result[Count] := SR.Name + '/';  // Indicate it's a category
          Inc(Count);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end;
end;

function TResourceRepository.SearchPackages(const AKeyword: string): SysUtils.TStringArray;
var
  AllPackages: SysUtils.TStringArray;
  Info: TPackageInfo;
  i, Count: Integer;
  Keyword: string;
begin
  Result := nil;
  Count := 0;
  Keyword := LowerCase(AKeyword);

  // Get all packages and filter by keyword
  AllPackages := ListPackages('');

  for i := 0 to High(AllPackages) do
  begin
    // Get description for matching
    Info.Description := '';
    GetPackageInfo(AllPackages[i], '', Info);

    // Use helper for matching
    if ResourceRepoPackageMatchesKeyword(AllPackages[i], Info.Description, Keyword) then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := AllPackages[i];
      Inc(Count);
    end;
  end;
end;

function TResourceRepository.InstallPackage(const AName, AVersion, ADestDir: string): Boolean;
var
  Info: TPackageInfo;
begin
  Result := False;

  // Get package info
  if not GetPackageInfo(AName, AVersion, Info) then
  begin
    LogFmt('Error: Package info not found for %s', [AName]);
    Exit;
  end;

  // B226: Delegate to install helper
  Result := RepoInstallPackage(BuildInstallContext(Self), Info, AName, AVersion, ADestDir);
end;

end.
