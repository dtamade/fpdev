unit fpdev.resource.repo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DateUtils, fpdev.utils.fs,
  fpdev.utils.process, fpdev.utils.git, fpdev.constants,
  fpdev.output.intf;

type
  { 镜像信息 }
  TMirrorInfo = record
    Name: string;             // 镜像名称
    URL: string;              // 镜像URL
    Region: string;           // 区域（china, europe, us）
    Priority: Integer;        // 优先级（越小越优先）
  end;

  TMirrorArray = array of TMirrorInfo;

  { 资源仓库配置 }
  TResourceRepoConfig = record
    URL: string;              // 主仓库URL
    Mirrors: array of string; // 镜像URL列表（简单格式，向后兼容）
    MirrorInfos: TMirrorArray; // 镜像详细信息
    LocalPath: string;        // 本地克隆路径
    Branch: string;           // 使用的分支（默认main）
    AutoUpdate: Boolean;      // 自动更新
    UpdateIntervalHours: Integer;  // 更新间隔（小时）
  end;

  { 平台信息 - 支持 manifest v2.0 格式 }
  TPlatformInfo = record
    // v2.0 字段（推荐）
    URL: string;              // 主下载 URL（完整 HTTP/HTTPS URL）
    Mirrors: array of string; // 备用镜像 URL 列表（故障转移）
    // v1.0 字段（向后兼容）
    Path: string;             // 资源在仓库中的相对路径（当 URL 为空时使用）
    // 通用字段
    Executable: string;       // 可执行文件相对路径（仅 bootstrap）
    SHA256: string;           // 校验和
    Size: Int64;              // 大小（字节）
    Tested: Boolean;          // 是否经过测试
  end;

  { 交叉编译工具链信息 }
  TCrossToolchainInfo = record
    TargetName: string;       // 目标名称（如 win32, linux-arm）
    DisplayName: string;      // 显示名称
    CPU: string;              // 目标 CPU
    OS: string;               // 目标 OS
    BinutilsPrefix: string;   // binutils 前缀
    BinutilsArchive: string;  // binutils 存档路径
    LibsArchive: string;      // 库文件存档路径
    BinutilsSHA256: string;   // binutils 校验和
    LibsSHA256: string;       // 库文件校验和
  end;

  { 包信息 }
  TPackageInfo = record
    Name: string;             // 包名
    Version: string;          // 版本
    Description: string;      // 描述
    Category: string;         // 分类
    Archive: string;          // 存档路径
    SHA256: string;           // 校验和
    Dependencies: array of string;  // 依赖
    FPCMinVersion: string;    // 最低 FPC 版本
  end;

  { 资源仓库管理器 }
  TResourceRepository = class
  private
    FConfig: TResourceRepoConfig;
    FLocalPath: string;
    FLastUpdateCheck: TDateTime;
    FManifestData: TJSONObject;
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
      // 重新加载清单
      LoadManifest;
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

    // 解析JSON
    if Assigned(FManifestData) then
      FManifestData.Free;

    Parser := TJSONParser.Create(ManifestContent, []);
    try
      FManifestData := Parser.Parse as TJSONObject;
      Result := Assigned(FManifestData);

      if Result then
        LogFmt('Manifest loaded (version: %s)', [GetManifestVersion]);
    finally
      Parser.Free;
    end;

  except
    on E: Exception do
    begin
      LogFmt('Error loading manifest: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

function TResourceRepository.GetManifestVersion: string;
begin
  Result := 'unknown';
  if Assigned(FManifestData) then
    Result := FManifestData.Get('version', 'unknown');
end;

function TResourceRepository.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
var
  BootstrapCompilers: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
begin
  Result := False;

  if not Assigned(FManifestData) then
    Exit;

  try
    BootstrapCompilers := FManifestData.Objects['bootstrap_compilers'];
    if not Assigned(BootstrapCompilers) then
      Exit;

    VersionData := BootstrapCompilers.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    Result := Platforms.IndexOfName(APlatform) >= 0;
  except
    Result := False;
  end;
end;

function TResourceRepository.GetBootstrapInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
var
  BootstrapCompilers: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  if not Assigned(FManifestData) then
    Exit;

  try
    BootstrapCompilers := FManifestData.Objects['bootstrap_compilers'];
    if not Assigned(BootstrapCompilers) then
      Exit;

    VersionData := BootstrapCompilers.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    AInfo.Path := VersionData.Get('path', '');

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    PlatformData := Platforms.Objects[APlatform];
    if not Assigned(PlatformData) then
      Exit;

    // v2.0 fields: url and mirrors
    AInfo.URL := PlatformData.Get('url', '');
    MirrorsArray := PlatformData.Arrays['mirrors'];
    if Assigned(MirrorsArray) then
    begin
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
    Result := False;
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
var
  VersionMap: TJSONObject;
  NormalizedVersion: string;

  function GetHardcodedMapping(const AVersion: string): string;
  var
    NormVer: string;
  begin
    Result := '';
    NormVer := LowerCase(Trim(AVersion));

    if (NormVer = 'main') or (NormVer = '3.3.1') or (NormVer = 'trunk') then
      Result := '3.2.2'
    else if (NormVer = '3.2.4') or (NormVer = '3.2.3') then
      Result := '3.2.2'
    else if NormVer = '3.2.2' then
      Result := '3.2.0'
    else if NormVer = '3.2.0' then
      Result := '3.0.4'
    else if (NormVer = '3.0.5') or (NormVer = '3.0.4') then
      Result := '3.0.2'
    else if (NormVer = '3.0.3') or (NormVer = '3.0.2') or (NormVer = '3.0.1') then
      Result := '3.0.0'
    else if NormVer = '3.0.0' then
      Result := '2.6.4'
    else if (NormVer = '2.6.5') or (NormVer = '2.6.4') then
      Result := '2.6.2'
    else if NormVer = '2.6.2' then
      Result := '2.6.0';
  end;

begin
  Result := '';

  // If no manifest loaded, use hardcoded mapping
  if not Assigned(FManifestData) then
  begin
    Result := GetHardcodedMapping(AFPCVersion);
    Exit;
  end;

  try
    VersionMap := FManifestData.Objects['bootstrap_version_map'];
    if not Assigned(VersionMap) then
    begin
      // Fallback to hardcoded mapping (based on fpcupdeluxe)
      Result := GetHardcodedMapping(AFPCVersion);
      Exit;
    end;

    // Look up in manifest version map
    Result := VersionMap.Get(AFPCVersion, '');

    // If not found, try normalized version
    if Result = '' then
    begin
      NormalizedVersion := LowerCase(Trim(AFPCVersion));
      if NormalizedVersion = 'trunk' then
        Result := VersionMap.Get('main', '');
    end;

    // If still not found, fallback to hardcoded
    if Result = '' then
      Result := GetHardcodedMapping(AFPCVersion);
  except
    Result := GetHardcodedMapping(AFPCVersion);
  end;
end;

function TResourceRepository.GetBootstrapVersionFromMakefile(const ASourcePath: string): string;
var
  MakefilePath: string;
  F: TextFile;
  Line: string;
  RequiredVersion, RequiredVersion2: Integer;
  VersionStr: string;
  Major, Minor, Patch: Integer;
begin
  Result := '';

  MakefilePath := ASourcePath + PathDelim + 'Makefile';
  if not FileExists(MakefilePath) then
  begin
    MakefilePath := ASourcePath + PathDelim + 'Makefile.fpc';
    if not FileExists(MakefilePath) then
      Exit;
  end;

  RequiredVersion := 0;
  RequiredVersion2 := 0;

  try
    AssignFile(F, MakefilePath);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        Line := Trim(Line);

        // Parse REQUIREDVERSION=XXXXX (e.g., 30200 = 3.2.0)
        if Pos('REQUIREDVERSION=', Line) = 1 then
        begin
          VersionStr := Trim(Copy(Line, 17, Length(Line)));
          // Remove any trailing comments
          if Pos('#', VersionStr) > 0 then
            VersionStr := Trim(Copy(VersionStr, 1, Pos('#', VersionStr) - 1));
          Val(VersionStr, RequiredVersion);
        end
        else if Pos('REQUIREDVERSION2=', Line) = 1 then
        begin
          VersionStr := Trim(Copy(Line, 18, Length(Line)));
          if Pos('#', VersionStr) > 0 then
            VersionStr := Trim(Copy(VersionStr, 1, Pos('#', VersionStr) - 1));
          Val(VersionStr, RequiredVersion2);
        end;
      end;
    finally
      CloseFile(F);
    end;

    // Convert numerical version to string (e.g., 30200 -> 3.2.0)
    if RequiredVersion > 0 then
    begin
      Major := RequiredVersion div 10000;
      Minor := (RequiredVersion mod 10000) div 100;
      Patch := RequiredVersion mod 100;
      Result := Format('%d.%d.%d', [Major, Minor, Patch]);

      // Normalize: 3.2.0 -> 3.2.0, but we might use RequiredVersion2 if lower
      if (RequiredVersion2 > 0) and (RequiredVersion2 < RequiredVersion) then
      begin
        Major := RequiredVersion2 div 10000;
        Minor := (RequiredVersion2 mod 10000) div 100;
        Patch := RequiredVersion2 mod 100;
        Result := Format('%d.%d.%d', [Major, Minor, Patch]);
      end;
    end;
  except
    Result := '';
  end;
end;

function TResourceRepository.ListBootstrapVersions: SysUtils.TStringArray;
var
  BootstrapCompilers: TJSONObject;
  i: Integer;
begin
  Result := nil;

  if not Assigned(FManifestData) then
    Exit;

  try
    BootstrapCompilers := FManifestData.Objects['bootstrap_compilers'];
    if not Assigned(BootstrapCompilers) then
      Exit;

    SetLength(Result, BootstrapCompilers.Count);
    for i := 0 to BootstrapCompilers.Count - 1 do
      Result[i] := BootstrapCompilers.Names[i];
  except
    SetLength(Result, 0);
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
var
  BinaryReleases: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
begin
  Result := False;

  if not Assigned(FManifestData) then
    Exit;

  try
    BinaryReleases := FManifestData.Objects['binary_releases'];
    if not Assigned(BinaryReleases) then
      Exit;

    VersionData := BinaryReleases.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    Result := Platforms.IndexOfName(APlatform) >= 0;
  except
    Result := False;
  end;
end;

function TResourceRepository.GetBinaryReleaseInfo(const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
var
  BinaryReleases: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  if not Assigned(FManifestData) then
    Exit;

  try
    // Try fpc_releases first (v2.0 format), then binary_releases (v1.0 format)
    BinaryReleases := FManifestData.Objects['fpc_releases'];
    if not Assigned(BinaryReleases) then
      BinaryReleases := FManifestData.Objects['binary_releases'];
    if not Assigned(BinaryReleases) then
      Exit;

    VersionData := BinaryReleases.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    AInfo.Path := VersionData.Get('path', '');

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    PlatformData := Platforms.Objects[APlatform];
    if not Assigned(PlatformData) then
      Exit;

    // v2.0 fields: url and mirrors
    AInfo.URL := PlatformData.Get('url', '');
    MirrorsArray := PlatformData.Arrays['mirrors'];
    if Assigned(MirrorsArray) then
    begin
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
    AInfo.SHA256 := PlatformData.Get('sha256', '');
    AInfo.Size := PlatformData.Get('size', Int64(0));
    AInfo.Tested := PlatformData.Get('tested', False);

    Result := (AInfo.URL <> '') or (AInfo.Path <> '');
  except
    Result := False;
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
  ArchivePath: string;
  TempFile: string;
  DownloadURL: string;
  i: Integer;
  DownloadSuccess: Boolean;
begin
  Result := False;

  LogFmt('Installing FPC %s binary release for %s...', [AVersion, APlatform]);

  // Get release info
  if not GetBinaryReleaseInfo(AVersion, APlatform, Info) then
  begin
    Log('Error: Binary release info not found');
    Exit;
  end;

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  // Determine archive path - either download from URL or use local file
  if Info.URL <> '' then
  begin
    // v2.0: Download from URL with mirror fallback
    TempFile := GetTempDir + 'fpdev_download_' + IntToStr(GetTickCount64) + ExtractFileExt(Info.URL);
    DownloadSuccess := False;

    // Try primary URL first
    LogFmt('Downloading from: %s', [Info.URL]);
    DownloadSuccess := DownloadFile(Info.URL, TempFile);

    // If primary URL fails, try mirrors
    if not DownloadSuccess then
    begin
      for i := 0 to High(Info.Mirrors) do
      begin
        DownloadURL := Info.Mirrors[i];
        LogFmt('Primary URL failed, trying mirror %d: %s', [i + 1, DownloadURL]);
        DownloadSuccess := DownloadFile(DownloadURL, TempFile);
        if DownloadSuccess then
          Break;
      end;
    end;

    if not DownloadSuccess then
    begin
      Log('Error: Failed to download binary release from all sources');
      if FileExists(TempFile) then
        DeleteFile(TempFile);
      Exit;
    end;

    ArchivePath := TempFile;
    Log('Download completed');
  end
  else if Info.Path <> '' then
  begin
    // v1.0 backward compatibility: use local file from repository
    ArchivePath := FLocalPath + PathDelim + Info.Path;
    if not FileExists(ArchivePath) then
    begin
      LogFmt('Error: Binary release archive not found: %s', [ArchivePath]);
      Exit;
    end;
    TempFile := '';  // No temp file to clean up
  end
  else
  begin
    Log('Error: No URL or archive path specified in manifest');
    Exit;
  end;

  LogFmt('Source: %s', [ArchivePath]);
  LogFmt('Destination: %s', [ADestDir]);

  // Verify checksum
  if Info.SHA256 <> '' then
  begin
    Log('Verifying checksum...');
    if not VerifyChecksum(ArchivePath, Info.SHA256) then
    begin
      Log('Error: Checksum verification failed');
      if TempFile <> '' then
        DeleteFile(TempFile);
      Exit;
    end;
    Log('Checksum verified');
  end;

  // Extract based on file extension
  if (Pos('.tar.gz', LowerCase(ArchivePath)) > 0) or
     (Pos('.tgz', LowerCase(ArchivePath)) > 0) then
  begin
    // tar.gz extraction
    Result := TProcessExecutor.Run('tar', ['-xzf', ArchivePath, '-C', ADestDir], '');
  end
  else if Pos('.tar', LowerCase(ArchivePath)) > 0 then
  begin
    // tar extraction
    Result := TProcessExecutor.Run('tar', ['-xf', ArchivePath, '-C', ADestDir], '');
  end
  else if Pos('.zip', LowerCase(ArchivePath)) > 0 then
  begin
    // zip extraction
    Result := TProcessExecutor.Run('unzip', ['-q', '-o', ArchivePath, '-d', ADestDir], '');
  end
  else
  begin
    LogFmt('Error: Unsupported archive format: %s', [ExtractFileExt(ArchivePath)]);
    if TempFile <> '' then
      DeleteFile(TempFile);
    Exit;
  end;

  // Clean up temp file
  if TempFile <> '' then
    DeleteFile(TempFile);

  if Result then
    Log('Binary release installed successfully')
  else
    Log('Error: Failed to extract archive');
end;

function TResourceRepository.InstallBootstrap(const AVersion, APlatform, ADestDir: string): Boolean;
var
  Info: TPlatformInfo;
  SourceDir: string;
  DestPath: string;
  ExeName: string;
begin
  Result := False;

  LogFmt('Installing bootstrap compiler %s for %s...', [AVersion, APlatform]);

  // 获取信息
  if not GetBootstrapInfo(AVersion, APlatform, Info) then
  begin
    Log('Error: Bootstrap compiler info not found');
    Exit;
  end;

  // 源目录（资源仓库中）
  SourceDir := FLocalPath + PathDelim + Info.Path;
  if not DirectoryExists(SourceDir) then
  begin
    LogFmt('Error: Bootstrap compiler source directory not found: %s', [SourceDir]);
    Exit;
  end;

  // 确保目标目录存在
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  LogFmt('Source: %s', [SourceDir]);
  LogFmt('Destination: %s', [ADestDir]);

  // 复制整个目录
  {$IFDEF MSWINDOWS}
  Result := TProcessExecutor.Run('xcopy', [SourceDir, ADestDir, '/E', '/I', '/Q', '/Y'], '');
  {$ELSE}
  Result := TProcessExecutor.Run('cp', ['-r', SourceDir + PathDelim + '.', ADestDir], '');
  {$ENDIF}

  if not Result then
  begin
    Log('Failed to copy bootstrap compiler files');
    Exit;
  end;

  // 验证可执行文件
  ExeName := ExtractFileName(Info.Executable);
  DestPath := ADestDir + PathDelim + ExeName;

  if not FileExists(DestPath) then
  begin
    LogFmt('Bootstrap compiler executable not found after installation: %s', [DestPath]);
    Exit(False);
  end;

  // 在Unix系统上设置执行权限
  {$IFNDEF MSWINDOWS}
  TProcessExecutor.Run('chmod', ['+x', DestPath], '');

  // 同样处理编译器可执行文件（如ppcx64）
  if FileExists(ADestDir + PathDelim + 'ppcx64') then
    TProcessExecutor.Run('chmod', ['+x', ADestDir + PathDelim + 'ppcx64'], '');
  {$ENDIF}

  // 验证校验和（如果提供）
  if Info.SHA256 <> '' then
  begin
    if not VerifyChecksum(DestPath, Info.SHA256) then
    begin
      Log('Checksum verification failed');
      Exit(False);
    end;
  end;

  Log('Bootstrap compiler installed successfully');
  LogFmt('  Executable: %s', [DestPath]);
  Result := True;
end;

{ Mirror Management }

function TResourceRepository.DetectUserRegion: string;
var
  TZ: string;
begin
  // Simple region detection based on timezone or locale
  // Default to 'us' for international users
  Result := 'us';

  {$IFDEF MSWINDOWS}
  TZ := GetEnvironmentVariable('TZ');
  if TZ = '' then
    TZ := GetEnvironmentVariable('LANG');
  {$ELSE}
  TZ := GetEnvironmentVariable('TZ');
  if TZ = '' then
  begin
    // Try to read timezone from /etc/timezone on Linux
    if FileExists('/etc/timezone') then
    begin
      try
        with TStringList.Create do
        try
          LoadFromFile('/etc/timezone');
          if Count > 0 then
            TZ := Strings[0];
        finally
          Free;
        end;
      except
        TZ := '';
      end;
    end;
  end;
  {$ENDIF}

  // Detect China region
  if (Pos('Asia/Shanghai', TZ) > 0) or
     (Pos('Asia/Beijing', TZ) > 0) or
     (Pos('Asia/Chongqing', TZ) > 0) or
     (Pos('Asia/Hong_Kong', TZ) > 0) or
     (Pos('zh_CN', GetEnvironmentVariable('LANG')) > 0) or
     (Pos('zh_TW', GetEnvironmentVariable('LANG')) > 0) then
  begin
    Result := 'china';
    Exit;
  end;

  // Detect Europe region
  if (Pos('Europe/', TZ) > 0) then
  begin
    Result := 'europe';
    Exit;
  end;
end;

function TResourceRepository.TestMirrorLatency(const AURL: string; ATimeoutMS: Integer): Integer;
var
  LResult: TProcessResult;
  TestURL: string;
begin
  Result := -1;  // -1 表示不可达

  // 构造测试 URL（只测试 HEAD 请求）
  TestURL := AURL;
  // 移除 .git 后缀以测试 web 可达性
  if Pos('.git', TestURL) > 0 then
    TestURL := Copy(TestURL, 1, Pos('.git', TestURL) - 1);

  try
    // 使用 curl 测试延迟（超时设置为秒）
    LResult := TProcessExecutor.Execute('curl',
      ['-s', '-o', '/dev/null', '-w', '%{time_total}',
       '--connect-timeout', IntToStr(ATimeoutMS div 1000),
       '--max-time', IntToStr(ATimeoutMS div 1000),
       '-I', TestURL], '');

    if LResult.Success then
    begin
      // curl 返回的是秒数，转换为毫秒
      Result := Round(StrToFloatDef(Trim(LResult.StdOut), 999) * 1000);
    end;
  except
    Result := -1;
  end;
end;

function TResourceRepository.SelectBestMirror: string;
const
  CACHE_TTL_HOURS = 1;  // 镜像缓存 1 小时
var
  Mirrors: TJSONArray;
  Mirror: TJSONObject;
  Region, MirrorRegion, MirrorURL: string;
  i, Latency, BestLatency: Integer;
  CandidateMirrors: array of string;
  CandidateCount: Integer;
begin
  Result := FConfig.URL;  // Default to primary URL

  // 检查缓存
  if (FCachedBestMirror <> '') and (FMirrorCacheTime > 0) then
  begin
    if HoursBetween(Now, FMirrorCacheTime) < CACHE_TTL_HOURS then
    begin
      Result := FCachedBestMirror;
      Exit;
    end;
  end;

  if not Assigned(FManifestData) then
    Exit;

  // Detect or use configured region
  if FUserRegion <> '' then
    Region := FUserRegion
  else
    Region := DetectUserRegion;

  CandidateMirrors := nil;
  CandidateCount := 0;

  try
    // 第一步：收集同区域的候选镜像
    if FManifestData.Find('repository') <> nil then
    begin
      if TJSONObject(FManifestData.Find('repository')).Find('mirrors') <> nil then
      begin
        Mirrors := TJSONObject(FManifestData.Find('repository')).Arrays['mirrors'];

        for i := 0 to Mirrors.Count - 1 do
        begin
          Mirror := Mirrors.Objects[i];
          MirrorRegion := Mirror.Get('region', '');
          MirrorURL := Mirror.Get('url', '');

          // 优先选择同区域镜像
          if (MirrorRegion = Region) or (Region = '') then
          begin
            SetLength(CandidateMirrors, CandidateCount + 1);
            CandidateMirrors[CandidateCount] := MirrorURL;
            Inc(CandidateCount);
          end;
        end;

        // 如果没有同区域镜像，添加所有镜像
        if CandidateCount = 0 then
        begin
          for i := 0 to Mirrors.Count - 1 do
          begin
            Mirror := Mirrors.Objects[i];
            MirrorURL := Mirror.Get('url', '');
            SetLength(CandidateMirrors, CandidateCount + 1);
            CandidateMirrors[CandidateCount] := MirrorURL;
            Inc(CandidateCount);
          end;
        end;
      end;
    end;

    // 添加主 URL 和配置中的简单镜像列表
    SetLength(CandidateMirrors, CandidateCount + 1);
    CandidateMirrors[CandidateCount] := FConfig.URL;
    Inc(CandidateCount);

    for i := 0 to High(FConfig.Mirrors) do
    begin
      SetLength(CandidateMirrors, CandidateCount + 1);
      CandidateMirrors[CandidateCount] := FConfig.Mirrors[i];
      Inc(CandidateCount);
    end;

    // 第二步：测试延迟并选择最快的
    BestLatency := MaxInt;
    SetLength(FMirrorLatencies, CandidateCount);

    for i := 0 to CandidateCount - 1 do
    begin
      Latency := TestMirrorLatency(CandidateMirrors[i], 3000);  // 3秒超时
      FMirrorLatencies[i].URL := CandidateMirrors[i];
      FMirrorLatencies[i].Latency := Latency;

      if (Latency > 0) and (Latency < BestLatency) then
      begin
        BestLatency := Latency;
        Result := CandidateMirrors[i];
      end;
    end;

    // 缓存结果
    FCachedBestMirror := Result;
    FMirrorCacheTime := Now;

  except
    // Fall back to primary URL on any error
    Result := FConfig.URL;
  end;
end;

function TResourceRepository.GetMirrors: TMirrorArray;
var
  Mirrors: TJSONArray;
  Mirror: TJSONObject;
  i: Integer;
begin
  Result := nil;

  if not Assigned(FManifestData) then
    Exit;

  try
    if FManifestData.Find('repository') <> nil then
    begin
      if TJSONObject(FManifestData.Find('repository')).Find('mirrors') <> nil then
      begin
        Mirrors := TJSONObject(FManifestData.Find('repository')).Arrays['mirrors'];
        SetLength(Result, Mirrors.Count);

        for i := 0 to Mirrors.Count - 1 do
        begin
          Mirror := Mirrors.Objects[i];
          Result[i].Name := Mirror.Get('name', '');
          Result[i].URL := Mirror.Get('url', '');
          Result[i].Region := Mirror.Get('region', '');
          Result[i].Priority := Mirror.Get('priority', 100);
        end;
      end;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TResourceRepository.GetBestMirrorURL: string;
begin
  Result := SelectBestMirror;
end;

{ Cross Toolchain Management }

function TResourceRepository.HasCrossToolchain(const ATarget, AHostPlatform: string): Boolean;
var
  CrossToolchains: TJSONObject;
  TargetData: TJSONObject;
  HostPlatforms: TJSONObject;
begin
  Result := False;

  if not Assigned(FManifestData) then
    Exit;

  try
    CrossToolchains := FManifestData.Objects['cross_toolchains'];
    if not Assigned(CrossToolchains) then
      Exit;

    TargetData := CrossToolchains.Objects[ATarget];
    if not Assigned(TargetData) then
      Exit;

    HostPlatforms := TargetData.Objects['host_platforms'];
    if not Assigned(HostPlatforms) then
      Exit;

    Result := HostPlatforms.IndexOfName(AHostPlatform) >= 0;
  except
    Result := False;
  end;
end;

function TResourceRepository.GetCrossToolchainInfo(const ATarget, AHostPlatform: string; out AInfo: TCrossToolchainInfo): Boolean;
var
  CrossToolchains: TJSONObject;
  TargetData: TJSONObject;
  HostPlatforms: TJSONObject;
  PlatformData: TJSONObject;
begin
  Result := False;
  System.Initialize(AInfo);

  if not Assigned(FManifestData) then
    Exit;

  try
    CrossToolchains := FManifestData.Objects['cross_toolchains'];
    if not Assigned(CrossToolchains) then
      Exit;

    TargetData := CrossToolchains.Objects[ATarget];
    if not Assigned(TargetData) then
      Exit;

    // Get target-level info
    AInfo.TargetName := ATarget;
    AInfo.DisplayName := TargetData.Get('display_name', ATarget);
    AInfo.CPU := TargetData.Get('cpu', '');
    AInfo.OS := TargetData.Get('os', '');
    AInfo.BinutilsPrefix := TargetData.Get('binutils_prefix', '');

    HostPlatforms := TargetData.Objects['host_platforms'];
    if not Assigned(HostPlatforms) then
      Exit;

    PlatformData := HostPlatforms.Objects[AHostPlatform];
    if not Assigned(PlatformData) then
      Exit;

    // Get host-platform specific info
    AInfo.BinutilsArchive := PlatformData.Get('binutils', '');
    AInfo.LibsArchive := PlatformData.Get('libs', '');
    AInfo.BinutilsSHA256 := PlatformData.Get('binutils_sha256', '');
    AInfo.LibsSHA256 := PlatformData.Get('libs_sha256', '');

    Result := (AInfo.BinutilsArchive <> '') or (AInfo.LibsArchive <> '');
  except
    Result := False;
  end;
end;

function TResourceRepository.ListCrossTargets: SysUtils.TStringArray;
var
  CrossToolchains: TJSONObject;
  i: Integer;
begin
  Result := nil;

  if not Assigned(FManifestData) then
    Exit;

  try
    CrossToolchains := FManifestData.Objects['cross_toolchains'];
    if not Assigned(CrossToolchains) then
      Exit;

    SetLength(Result, CrossToolchains.Count);
    for i := 0 to CrossToolchains.Count - 1 do
      Result[i] := CrossToolchains.Names[i];
  except
    SetLength(Result, 0);
  end;
end;

function TResourceRepository.InstallCrossToolchain(const ATarget, AHostPlatform, ADestDir: string): Boolean;
var
  Info: TCrossToolchainInfo;
  BinutilsPath, LibsPath: string;
begin
  Result := False;

  LogFmt('Installing cross toolchain for %s on %s...', [ATarget, AHostPlatform]);

  // Get toolchain info
  if not GetCrossToolchainInfo(ATarget, AHostPlatform, Info) then
  begin
    Log('Error: Cross toolchain info not found');
    Exit;
  end;

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  // Install binutils if specified
  if Info.BinutilsArchive <> '' then
  begin
    BinutilsPath := FLocalPath + PathDelim + Info.BinutilsArchive;
    if not FileExists(BinutilsPath) then
    begin
      LogFmt('Error: Binutils archive not found: %s', [BinutilsPath]);
      Exit;
    end;

    // Verify checksum
    if (Info.BinutilsSHA256 <> '') and not VerifyChecksum(BinutilsPath, Info.BinutilsSHA256) then
    begin
      Log('Error: Binutils checksum verification failed');
      Exit;
    end;

    Log('Extracting binutils...');
    if not TProcessExecutor.Run('tar', ['-xzf', BinutilsPath, '-C', ADestDir], '') then
    begin
      Log('Error: Failed to extract binutils');
      Exit;
    end;
  end;

  // Install libraries if specified
  if Info.LibsArchive <> '' then
  begin
    LibsPath := FLocalPath + PathDelim + Info.LibsArchive;
    if not FileExists(LibsPath) then
    begin
      LogFmt('Error: Libraries archive not found: %s', [LibsPath]);
      Exit;
    end;

    // Verify checksum
    if (Info.LibsSHA256 <> '') and not VerifyChecksum(LibsPath, Info.LibsSHA256) then
    begin
      Log('Error: Libraries checksum verification failed');
      Exit;
    end;

    Log('Extracting libraries...');
    if not TProcessExecutor.Run('tar', ['-xzf', LibsPath, '-C', ADestDir], '') then
    begin
      Log('Error: Failed to extract libraries');
      Exit;
    end;
  end;

  Log('Cross toolchain installed successfully');
  LogFmt('  Target: %s (%s-%s)', [Info.DisplayName, Info.CPU, Info.OS]);
  LogFmt('  Location: %s', [ADestDir]);
  Result := True;
end;

{ Package Management }

function TResourceRepository.HasPackage(const AName, AVersion: string): Boolean;
var
  Packages: TJSONObject;
  Categories: TJSONArray;
  i: Integer;
begin
  Result := False;
  if AName = '' then; // Suppress unused parameter hint
  if AVersion = '' then; // Suppress unused parameter hint

  if not Assigned(FManifestData) then
    Exit;

  try
    // Check packages section
    Packages := FManifestData.Objects['packages'];
    if not Assigned(Packages) then
      Exit;

    // Iterate through categories to find the package
    Categories := Packages.Arrays['categories'];
    if Assigned(Categories) then
    begin
      for i := 0 to Categories.Count - 1 do
      begin
        // Each category could have packages - simplified check via package index
      end;
    end;

    // Alternative: Check package index file if exists
    // For now, return false until package index is implemented
    Result := False;
  except
    Result := False;
  end;
end;

function TResourceRepository.GetPackageInfo(const AName, AVersion: string; out AInfo: TPackageInfo): Boolean;
var
  PackageMetaPath: string;
  MetaContent: string;
  Parser: TJSONParser;
  PackageJSON: TJSONObject;
  DepsArray: TJSONArray;
  i: Integer;
  F: TextFile;
  Line: string;
begin
  Result := False;
  System.Initialize(AInfo);
  if AVersion = '' then; // Suppress hint

  // Try to find package metadata file
  // Expected location: packages/<category>/<name>/<name>.json
  PackageMetaPath := FLocalPath + PathDelim + 'packages' + PathDelim + AName + PathDelim + AName + '.json';

  if not FileExists(PackageMetaPath) then
  begin
    // Try alternative locations
    PackageMetaPath := FLocalPath + PathDelim + 'packages' + PathDelim + 'core' + PathDelim + AName + PathDelim + AName + '.json';
    if not FileExists(PackageMetaPath) then
    begin
      PackageMetaPath := FLocalPath + PathDelim + 'packages' + PathDelim + 'ui' + PathDelim + AName + PathDelim + AName + '.json';
      if not FileExists(PackageMetaPath) then
      begin
        PackageMetaPath := FLocalPath + PathDelim + 'packages' + PathDelim + 'utils' + PathDelim + AName + PathDelim + AName + '.json';
        if not FileExists(PackageMetaPath) then
          Exit;
      end;
    end;
  end;

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
        if PackageJSON.Find('dependencies') <> nil then
        begin
          DepsArray := PackageJSON.Arrays['dependencies'];
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
    Result := False;
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
    // Check if package name contains keyword
    if Pos(Keyword, LowerCase(AllPackages[i])) > 0 then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := AllPackages[i];
      Inc(Count);
    end
    else
    begin
      // Check description if we can get package info
      if GetPackageInfo(AllPackages[i], '', Info) then
      begin
        if Pos(Keyword, LowerCase(Info.Description)) > 0 then
        begin
          SetLength(Result, Count + 1);
          Result[Count] := AllPackages[i];
          Inc(Count);
        end;
      end;
    end;
  end;
end;

function TResourceRepository.InstallPackage(const AName, AVersion, ADestDir: string): Boolean;
var
  Info: TPackageInfo;
  ArchivePath: string;
begin
  Result := False;

  LogFmt('Installing package %s version %s...', [AName, AVersion]);

  // Get package info
  if not GetPackageInfo(AName, AVersion, Info) then
  begin
    LogFmt('Error: Package info not found for %s', [AName]);
    Exit;
  end;

  // Find archive
  if Info.Archive <> '' then
    ArchivePath := FLocalPath + PathDelim + Info.Archive
  else
    ArchivePath := FLocalPath + PathDelim + 'packages' + PathDelim + Info.Category +
                   PathDelim + AName + PathDelim + AName + '-' + Info.Version + '.tar.gz';

  if not FileExists(ArchivePath) then
  begin
    LogFmt('Error: Package archive not found: %s', [ArchivePath]);
    Exit;
  end;

  // Verify checksum
  if (Info.SHA256 <> '') and not VerifyChecksum(ArchivePath, Info.SHA256) then
  begin
    Log('Error: Package checksum verification failed');
    Exit;
  end;

  // Ensure destination directory exists
  if not DirectoryExists(ADestDir) then
    EnsureDir(ADestDir);

  LogFmt('Extracting package to %s...', [ADestDir]);

  // Extract archive
  if TProcessExecutor.Run('tar', ['-xzf', ArchivePath, '-C', ADestDir], '') then
  begin
    Log('Package installed successfully');
    LogFmt('  Name: %s', [Info.Name]);
    LogFmt('  Version: %s', [Info.Version]);
    LogFmt('  Location: %s', [ADestDir]);
    Result := True;
  end
  else
    Log('Error: Failed to extract package archive');
end;

end.
