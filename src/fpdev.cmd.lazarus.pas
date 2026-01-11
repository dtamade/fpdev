unit fpdev.cmd.lazarus;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.lazarus

Lazarus IDE 版本管理命令


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.output.console, fpdev.config.interfaces,
  fpdev.lazarus.source, fpdev.lazarus.config, fpdev.utils.fs, fpdev.utils.process,
  fpdev.utils.git,
  fpdev.i18n, fpdev.i18n.strings;

type
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

    function GetAvailableVersions: TLazarusVersionArray;
    function GetInstalledVersions: TLazarusVersionArray;
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;
    function BuildFromSource(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
    function SetupEnvironment(const AVersion: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function GetCompatibleFPCVersion(const ALazarusVersion: string): string;

  public
    constructor Create(AConfigManager: IConfigManager);
    destructor Destroy; override;

    // 版本管理
    function InstallVersion(const AVersion: string; const AFPCVersion: string = ''; const AFromSource: Boolean = False): Boolean; overload;
    function InstallVersion(const Outp, Errp: IOutput; const AVersion: string; const AFPCVersion: string; const AFromSource: Boolean): Boolean; overload;
    function UninstallVersion(const AVersion: string): Boolean; overload;
    function UninstallVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function ListVersions(const AShowAll: Boolean = False): Boolean; overload;
    function ListVersions(const Outp: IOutput; const AShowAll: Boolean = False): Boolean; overload;
    function SetDefaultVersion(const AVersion: string): Boolean; overload;
    function SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean; overload;
    function GetCurrentVersion: string;

    // 源码管理
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // IDE操作
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
  fpdev.version.registry;

const
  LAZARUS_OFFICIAL_REPO = 'https://gitlab.com/freepascal.org/lazarus/lazarus.git';

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
    // 默认优先使用程序旁 data 目录，不可写时再由 ConfigManager 回退
    FInstallRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  // 确保安装目录存在
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

function TLazarusManager.IsVersionInstalled(const AVersion: string): Boolean;
var
  InstallPath: string;
  LazarusExe: string;
begin
  InstallPath := GetVersionInstallPath(AVersion);
  {$IFDEF MSWINDOWS}
  LazarusExe := InstallPath + PathDelim + 'lazarus.exe';
  {$ELSE}
  LazarusExe := InstallPath + PathDelim + 'lazarus';
  {$ENDIF}

  Result := FileExists(LazarusExe);
end;

function TLazarusManager.ValidateVersion(const AVersion: string): Boolean;
begin
  Result := TVersionRegistry.Instance.IsLazarusVersionValid(AVersion);
end;

function TLazarusManager.GetCompatibleFPCVersion(const ALazarusVersion: string): string;
begin
  Result := TVersionRegistry.Instance.GetLazarusRecommendedFPC(ALazarusVersion);
end;

function TLazarusManager.GetAvailableVersions: TLazarusVersionArray;
var
  i: Integer;
  Releases: TLazarusReleaseArray;
begin
  Result := nil;
  Releases := TVersionRegistry.Instance.GetLazarusReleases;
  SetLength(Result, Length(Releases));
  for i := 0 to High(Releases) do
  begin
    Result[i].Version := Releases[i].Version;
    Result[i].ReleaseDate := Releases[i].ReleaseDate;
    Result[i].GitTag := Releases[i].GitTag;
    Result[i].Branch := Releases[i].Branch;
    if Length(Releases[i].FPCCompatible) > 0 then
      Result[i].FPCVersion := Releases[i].FPCCompatible[0]
    else
      Result[i].FPCVersion := '3.2.2';
    Result[i].Available := True;
    Result[i].Installed := IsVersionInstalled(Result[i].Version);
  end;
end;

function TLazarusManager.GetInstalledVersions: TLazarusVersionArray;
var
  AllVersions: TLazarusVersionArray;
  i, Count: Integer;
begin
  Result := nil;
  AllVersions := GetAvailableVersions;
  Count := 0;

  // 计算已安装版本数量
  for i := 0 to High(AllVersions) do
    if AllVersions[i].Installed then
      Inc(Count);

  // 创建结果数组
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
end;

function TLazarusManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
var
  Git: TGitOperations;
  GitTag: string;
begin
  Result := False;

  // Get Git tag from registry
  GitTag := TVersionRegistry.Instance.GetLazarusGitTag(AVersion);

  if GitTag = '' then
  begin
    Exit;
  end;

  Git := TGitOperations.Create;
  try
    // Check Git backend availability
    if Git.Backend = gbNone then
      Exit;

    // Ensure parent directory exists (git clone requires target to not exist)
    if not DirectoryExists(ExtractFileDir(ATargetDir)) then
      EnsureDir(ExtractFileDir(ATargetDir));

    // 克隆仓库
    Result := Git.Clone(LAZARUS_OFFICIAL_REPO, ATargetDir, GitTag);

  finally
    Git.Free;
  end;
end;

function TLazarusManager.BuildFromSource(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
var
  LResult: TProcessResult;
  MakeCmd: string;
  Settings: TFPDevSettings;
  FPCPath: string;
  Params: array of string;
  EnvVars: array of string;
begin
  Result := False;

  if not DirectoryExists(ASourceDir) then
  begin
    Exit;
  end;

  try

    // 确保安装目录存在
    if not DirectoryExists(AInstallDir) then
      EnsureDir(AInstallDir);

    Settings := FConfigManager.GetSettingsManager.GetSettings;

    // 设置FPC路径
    FPCPath := Settings.InstallRoot + PathDelim + 'fpc' + PathDelim + AFPCVersion + PathDelim + 'bin';

    {$IFDEF MSWINDOWS}
    MakeCmd := 'make';
    {$ELSE}
    MakeCmd := 'make';
    {$ENDIF}

    // Build parameters array
    Params := nil;
    SetLength(Params, 5);
    Params[0] := 'all';
    Params[1] := 'install';
    Params[2] := 'INSTALL_PREFIX=' + AInstallDir;
    Params[3] := 'FPC=' + FPCPath + PathDelim + 'fpc';
    Params[4] := '-j' + IntToStr(Settings.ParallelJobs);

    // Set environment variables
    EnvVars := nil;
    SetLength(EnvVars, 1);
    EnvVars[0] := 'PATH=' + FPCPath + PathSeparator + GetEnvironmentVariable('PATH');

    // Execute make with custom environment using unified process executor
    LResult := TProcessExecutor.RunDirectWithEnv(MakeCmd, Params, ASourceDir, EnvVars);

    Result := LResult.Success;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusManager.SetupEnvironment(const AVersion: string): Boolean;
var
  LazarusInfo: TLazarusInfo;
  InstallPath: string;
  FPCVersion: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    FPCVersion := GetCompatibleFPCVersion(AVersion);

    // 创建Lazarus信息
    System.Initialize(LazarusInfo);
    try
      LazarusInfo.Version := AVersion;
      LazarusInfo.FPCVersion := 'fpc-' + FPCVersion;
      LazarusInfo.InstallPath := InstallPath;
      LazarusInfo.SourceURL := LAZARUS_OFFICIAL_REPO;
      LazarusInfo.Installed := True;

      // 添加到配置
      Result := FConfigManager.GetLazarusManager.AddLazarusVersion('lazarus-' + AVersion, LazarusInfo);
      if Result then
    finally
      System.Finalize(LazarusInfo);
    end;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusManager.InstallVersion(const AVersion: string; const AFPCVersion: string; const AFromSource: Boolean): Boolean;
begin
  Result := InstallVersion(nil, nil, AVersion, AFPCVersion, AFromSource);
end;

function TLazarusManager.InstallVersion(const Outp, Errp: IOutput; const AVersion: string; const AFPCVersion: string; const AFromSource: Boolean): Boolean;
var
  InstallPath, SourceDir: string;
  FPCVer: string;
begin
  Result := False;

  if Outp = nil then;  // Unused parameter  // Unused parameter

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
    InstallPath := GetVersionInstallPath(AVersion);

    // 确定FPC版本
    if AFPCVersion <> '' then
      FPCVer := AFPCVersion
    else
      FPCVer := GetCompatibleFPCVersion(AVersion);


    if AFromSource then
    begin
      // 从源码安装
      SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + AVersion;

      if not DownloadSource(AVersion, SourceDir) then
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_SOURCE_DOWNLOAD_FAILED));
        Exit;
      end;

      if not BuildFromSource(SourceDir, InstallPath, FPCVer) then
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_SOURCE_BUILD_FAILED));
        Exit;
      end;

      Result := SetupEnvironment(AVersion);
      if (not Result) and (Errp <> nil) then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_ENV_SETUP_FAILED));

    end else
    begin
      // 从预编译包安装 (暂未实现)
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_BINARY_NOT_IMPL));
      Result := False;
    end;

    if Result then

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
begin
  Result := False;

  if Outp = nil then;  // Unused parameter

  if not IsVersionInstalled(AVersion) then
  begin
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);

    // 删除安装目录
    if DirectoryExists(InstallPath) then
      DeleteDirRecursive(InstallPath);

    // 从配置中移除
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
      Result := False;
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
begin
  Result := '';

  try
    DefaultVersion := FConfigManager.GetLazarusManager.GetDefaultLazarusVersion;
    if DefaultVersion <> '' then
      Result := StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll]);

  except
    on E: Exception do
    begin
      Result := '';
    end;
  end;
end;

function TLazarusManager.UpdateSources(const AVersion: string): Boolean;
var
  SourceDir: string;
  UseVersion: string;
  Git: TGitOperations;
begin
  Result := False;

  // 确定要更新的版本
  if AVersion <> '' then
    UseVersion := AVersion
  else
    UseVersion := GetCurrentVersion;

  if UseVersion = '' then
  begin
    Exit;
  end;

  // 构造源码目录路径
  SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + UseVersion;

  // 检查源码目录是否存在
  if not DirectoryExists(SourceDir) then
  begin
    Exit;
  end;

  Git := TGitOperations.Create;
  try
    // Check Git backend availability
    if Git.Backend = gbNone then
      Exit;

    // 检查是否是有效的 git 仓库
    if not Git.IsRepository(SourceDir) then
    begin
      Exit;
    end;

    // If no remote configured, repository is already up-to-date (local only)
    if not Git.HasRemote(SourceDir) then
    begin
      // 仓库存在但没有 remote
      // 这仍然算作成功，因为源码目录存在且是 git 仓库
      Result := True;
      Exit;
    end;

    // Execute git pull to update sources
    Result := Git.Pull(SourceDir);

    // Even if pull fails, if the repository exists it's not critical
    if not Result then
      Result := True;

  finally
    Git.Free;
  end;
end;

function TLazarusManager.CleanSources(const AVersion: string): Boolean;
var
  SourceDir: string;
  UseVersion: string;
begin
  Result := False;

  // Determine version to clean
  if AVersion <> '' then
    UseVersion := AVersion
  else
    UseVersion := GetCurrentVersion;

  if UseVersion = '' then
    Exit;

  // Construct source directory path
  SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + UseVersion;

  // Validate source directory exists
  if not DirectoryExists(SourceDir) then
    Exit;

  try
    // 使用共享清理函数（包含平台可执行文件）
    CleanBuildArtifacts(SourceDir, nil, True);
    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
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
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  if not ValidateVersion(AVersion) then
    Exit;

  try
    // Get version info from releases database
    AllVersions := GetAvailableVersions;
    for i := 0 to High(AllVersions) do
    begin
      if SameText(AllVersions[i].Version, AVersion) then
      begin
        VersionInfo := AllVersions[i];
        Break;
      end;
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
      LO.WriteLn(Format('Install Path: %s', [GetVersionInstallPath(AVersion)]));
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
      Result := False;
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
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    {$IFDEF MSWINDOWS}
    LazarusExe := InstallPath + PathDelim + 'lazarus.exe';
    {$ELSE}
    LazarusExe := InstallPath + PathDelim + 'lazarus';
    {$ENDIF}

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
  LazarusExe: string;
  InstallPath: string;
  UseVersion: string;
begin
  Result := False;

  // 确定要启动的版本
  if AVersion <> '' then
    UseVersion := AVersion
  else
    UseVersion := GetCurrentVersion;

  if UseVersion = '' then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_RUN_NO_VERSION));
    Exit;
  end;

  if not IsVersionInstalled(UseVersion) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_RUN_NOT_INSTALLED, [UseVersion]));
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(UseVersion);
    {$IFDEF MSWINDOWS}
    LazarusExe := InstallPath + PathDelim + 'lazarus.exe';
    {$ELSE}
    LazarusExe := InstallPath + PathDelim + 'lazarus';
    {$ENDIF}

    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_LAZARUS_RUN_START, [UseVersion]));

    // Launch IDE using unified process executor (non-blocking)
    if TProcessExecutor.Launch(LazarusExe, [], '') then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_LAZARUS_RUN_LAUNCHED, [UseVersion]));
      Result := True;
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_RUN_FAILED));
    end;

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

function TLazarusManager.ConfigureIDE(const Outp, Errp: IOutput; const AVersion: string): Boolean;
var
  InstallPath: string;
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  FPCVersion: string;
  FPCPath: string;
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
    InstallPath := GetVersionInstallPath(AVersion);
    FPCVersion := GetCompatibleFPCVersion(AVersion);
    Settings := FConfigManager.GetSettingsManager.GetSettings;

    // Determine config directory
    {$IFDEF MSWINDOWS}
    ConfigDir := GetEnvironmentVariable('APPDATA') + PathDelim + 'lazarus-' + AVersion;
    {$ELSE}
    ConfigDir := GetEnvironmentVariable('HOME') + PathDelim + '.lazarus-' + AVersion;
    {$ENDIF}

    LO.WriteLn(_Fmt(MSG_LAZARUS_CONFIGURING, [AVersion]));
    LO.WriteLn(_Fmt(MSG_LAZARUS_INSTALL_PATH, [InstallPath]));
    LO.WriteLn(_Fmt(MSG_LAZARUS_CONFIG_DIR, [ConfigDir]));

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      // Set FPC compiler path
      FPCPath := Settings.InstallRoot + PathDelim + 'fpc' + PathDelim + FPCVersion +
                 PathDelim + 'bin' + PathDelim + 'fpc';
      {$IFDEF MSWINDOWS}
      FPCPath := FPCPath + '.exe';
      {$ENDIF}

      if FileExists(FPCPath) then
      begin
        if IDEConfig.SetCompilerPath(FPCPath) then
          LO.WriteLn(_Fmt(MSG_LAZARUS_COMPILER_SET, [FPCPath]))
        else
          LE.WriteLn(_(MSG_LAZARUS_COMPILER_WARN));
      end
      else
        LE.WriteLn(_Fmt(MSG_LAZARUS_FPC_NOT_FOUND, [FPCPath]));

      // Set Lazarus directory
      if IDEConfig.SetLibraryPath(InstallPath) then
        LO.WriteLn(_Fmt(MSG_LAZARUS_DIR_SET, [InstallPath]))
      else
        LE.WriteLn(_(MSG_LAZARUS_DIR_WARN));

      // Set FPC source path if available
      if DirectoryExists(Settings.InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-' + FPCVersion) then
      begin
        if IDEConfig.SetFPCSourcePath(Settings.InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-' + FPCVersion) then
          LO.WriteLn(_(MSG_LAZARUS_FPC_SRC_SET));
      end;

      // Set make path
      {$IFDEF MSWINDOWS}
      if IDEConfig.SetMakePath('make.exe') then
        LO.WriteLn(_Fmt(MSG_LAZARUS_MAKE_SET, ['make.exe']));
      {$ELSE}
      if IDEConfig.SetMakePath('/usr/bin/make') then
        LO.WriteLn(_Fmt(MSG_LAZARUS_MAKE_SET, ['/usr/bin/make']));
      {$ENDIF}

      // Validate configuration
      if IDEConfig.ValidateConfig then
      begin
        LO.WriteLn('');
        LO.WriteLn(_(CMD_LAZARUS_CONFIG_DONE));
        LO.WriteLn('');
        LO.WriteLn(_(MSG_LAZARUS_CONFIG_SUMMARY));
        LO.WriteLn(IDEConfig.GetConfigSummary);
        Result := True;
      end
      else
      begin
        LO.WriteLn('');
        LE.WriteLn(_(MSG_WARNING) + ': ' + _(CMD_LAZARUS_CONFIG_INCOMPLETE));
        LE.WriteLn(_(CMD_LAZARUS_CONFIG_VERIFY));
        Result := True;  // Still return true as we did configure what we could
      end;

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
