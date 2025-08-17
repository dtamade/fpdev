unit fpdev.cmd.lazarus;

{$codepage utf8}

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
  SysUtils, Classes, Process,
  fpdev.config, fpdev.utils, fpdev.terminal, fpdev.lazarus.source;

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
    FConfigManager: TFPDevConfigManager;
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
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 版本管理
    function InstallVersion(const AVersion: string; const AFPCVersion: string = ''; const AFromSource: Boolean = False): Boolean;
    function UninstallVersion(const AVersion: string): Boolean;
    function ListVersions(const AShowAll: Boolean = False): Boolean;
    function SetDefaultVersion(const AVersion: string): Boolean;
    function GetCurrentVersion: string;

    // 源码管理
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // IDE操作
    function ShowVersionInfo(const AVersion: string): Boolean;
    function TestInstallation(const AVersion: string): Boolean;
    function LaunchIDE(const AVersion: string = ''): Boolean;
    function ConfigureIDE(const AVersion: string): Boolean;
  end;

// 主要执行函数
procedure execute(const aParams: array of string);

implementation

const
  LAZARUS_OFFICIAL_REPO = 'https://gitlab.com/freepascal.org/lazarus.git';
  LAZARUS_RELEASES: array[0..4] of TLazarusVersionInfo = (
    (Version: '3.0'; ReleaseDate: '2024-02-18'; GitTag: 'lazarus_3_0'; Branch: 'lazarus_3_0'; FPCVersion: '3.2.2'; Available: True; Installed: False),
    (Version: '2.2.6'; ReleaseDate: '2022-12-25'; GitTag: 'lazarus_2_2_6'; Branch: 'lazarus_2_2'; FPCVersion: '3.2.2'; Available: True; Installed: False),
    (Version: '2.2.4'; ReleaseDate: '2022-09-09'; GitTag: 'lazarus_2_2_4'; Branch: 'lazarus_2_2'; FPCVersion: '3.2.2'; Available: True; Installed: False),
    (Version: '2.0.12'; ReleaseDate: '2021-04-09'; GitTag: 'lazarus_2_0_12'; Branch: 'lazarus_2_0'; FPCVersion: '3.2.0'; Available: True; Installed: False),
    (Version: 'main'; ReleaseDate: 'development'; GitTag: 'main'; Branch: 'main'; FPCVersion: '3.2.2'; Available: True; Installed: False)
  );

{ TLazarusManager }

constructor TLazarusManager.Create(AConfigManager: TFPDevConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    // 默认优先使用程序旁 data 目录，不可写时再由 ConfigManager 回退
    FInstallRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
    Settings.InstallRoot := FInstallRoot;
    FConfigManager.SetSettings(Settings);
  end;

  // 确保安装目录存在
  if not DirectoryExists(FInstallRoot) then
    ForceDirectories(FInstallRoot);
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
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(LAZARUS_RELEASES) do
  begin
    if SameText(LAZARUS_RELEASES[i].Version, AVersion) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TLazarusManager.GetCompatibleFPCVersion(const ALazarusVersion: string): string;
var
  i: Integer;
begin
  Result := '3.2.2'; // 默认版本
  for i := 0 to High(LAZARUS_RELEASES) do
  begin
    if SameText(LAZARUS_RELEASES[i].Version, ALazarusVersion) then
    begin
      Result := LAZARUS_RELEASES[i].FPCVersion;
      Break;
    end;
  end;
end;

function TLazarusManager.GetAvailableVersions: TLazarusVersionArray;
var
  i: Integer;
begin
  SetLength(Result, Length(LAZARUS_RELEASES));
  for i := 0 to High(LAZARUS_RELEASES) do
  begin
    Result[i] := LAZARUS_RELEASES[i];
    Result[i].Installed := IsVersionInstalled(Result[i].Version);
  end;
end;

function TLazarusManager.GetInstalledVersions: TLazarusVersionArray;
var
  AllVersions: TLazarusVersionArray;
  i, Count: Integer;
begin
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
  Process: TProcess;
  GitTag: string;
  i: Integer;
begin
  Result := False;

  // 查找对应的Git标签
  GitTag := '';
  for i := 0 to High(LAZARUS_RELEASES) do
  begin
    if SameText(LAZARUS_RELEASES[i].Version, AVersion) then
    begin
      GitTag := LAZARUS_RELEASES[i].GitTag;
      Break;
    end;
  end;

  if GitTag = '' then
  begin
    WriteLn('错误: 未知的Lazarus版本 ', AVersion);
    Exit;
  end;

  try
    WriteLn('正在下载Lazarus ', AVersion, ' 源码...');

    // 确保目标目录存在
    if not DirectoryExists(ATargetDir) then
      ForceDirectories(ATargetDir);

    // 克隆仓库
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('clone');
      Process.Parameters.Add('--depth');
      Process.Parameters.Add('1');
      Process.Parameters.Add('--branch');
      Process.Parameters.Add(GitTag);
      Process.Parameters.Add(LAZARUS_OFFICIAL_REPO);
      Process.Parameters.Add(ATargetDir);
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      Process.Execute;

      Result := Process.ExitStatus = 0;
      if not Result then
        WriteLn('错误: Git克隆失败，退出代码: ', Process.ExitStatus);

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 下载源码时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.BuildFromSource(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
var
  Process: TProcess;
  MakeCmd: string;
  Settings: TFPDevSettings;
  FPCPath: string;
begin
  Result := False;

  if not DirectoryExists(ASourceDir) then
  begin
    WriteLn('错误: 源码目录不存在: ', ASourceDir);
    Exit;
  end;

  try
    WriteLn('正在编译Lazarus源码...');

    // 确保安装目录存在
    if not DirectoryExists(AInstallDir) then
      ForceDirectories(AInstallDir);

    Settings := FConfigManager.GetSettings;

    // 设置FPC路径
    FPCPath := Settings.InstallRoot + PathDelim + 'fpc' + PathDelim + AFPCVersion + PathDelim + 'bin';

    {$IFDEF MSWINDOWS}
    MakeCmd := 'make';
    {$ELSE}
    MakeCmd := 'make';
    {$ENDIF}

    // 编译Lazarus
    Process := TProcess.Create(nil);
    try
      Process.CurrentDirectory := ASourceDir;
      Process.Executable := MakeCmd;
      Process.Parameters.Add('all');
      Process.Parameters.Add('install');
      Process.Parameters.Add('INSTALL_PREFIX=' + AInstallDir);
      Process.Parameters.Add('FPC=' + FPCPath + PathDelim + 'fpc');
      Process.Parameters.Add('-j' + IntToStr(Settings.ParallelJobs));
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      // 设置环境变量
      Process.Environment.Add('PATH=' + FPCPath + PathSeparator + GetEnvironmentVariable('PATH'));

      WriteLn('执行命令: ', Process.Executable, ' ', Process.Parameters.Text);
      Process.Execute;

      Result := Process.ExitStatus = 0;
      if not Result then
        WriteLn('错误: 编译失败，退出代码: ', Process.ExitStatus);

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 编译源码时发生异常: ', E.Message);
      Result := False;
    end;
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
    WriteLn('错误: Lazarus版本 ', AVersion, ' 未安装');
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    FPCVersion := GetCompatibleFPCVersion(AVersion);

    // 创建Lazarus信息
    FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
    LazarusInfo.Version := AVersion;
    LazarusInfo.FPCVersion := 'fpc-' + FPCVersion;
    LazarusInfo.InstallPath := InstallPath;
    LazarusInfo.SourceURL := LAZARUS_OFFICIAL_REPO;
    LazarusInfo.Installed := True;

    // 添加到配置
    Result := FConfigManager.AddLazarusVersion('lazarus-' + AVersion, LazarusInfo);
    if Result then
      WriteLn('✓ Lazarus ', AVersion, ' 环境配置完成');

  except
    on E: Exception do
    begin
      WriteLn('错误: 设置环境时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.InstallVersion(const AVersion: string; const AFPCVersion: string; const AFromSource: Boolean): Boolean;
var
  InstallPath, SourceDir: string;
  FPCVer: string;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    WriteLn('错误: 不支持的Lazarus版本: ', AVersion);
    Exit;
  end;

  if IsVersionInstalled(AVersion) then
  begin
    WriteLn('Lazarus ', AVersion, ' 已经安装');
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    WriteLn('安装Lazarus ', AVersion, ' 到: ', InstallPath);

    // 确定FPC版本
    if AFPCVersion <> '' then
      FPCVer := AFPCVersion
    else
      FPCVer := GetCompatibleFPCVersion(AVersion);

    WriteLn('使用FPC版本: ', FPCVer);

    if AFromSource then
    begin
      // 从源码安装
      SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + AVersion;

      WriteLn('步骤 1/3: 下载源码');
      if not DownloadSource(AVersion, SourceDir) then
      begin
        WriteLn('错误: 下载源码失败');
        Exit;
      end;

      WriteLn('步骤 2/3: 编译源码');
      if not BuildFromSource(SourceDir, InstallPath, FPCVer) then
      begin
        WriteLn('错误: 编译源码失败');
        Exit;
      end;

      WriteLn('步骤 3/3: 配置环境');
      Result := SetupEnvironment(AVersion);

    end else
    begin
      // 从预编译包安装 (暂未实现)
      WriteLn('错误: 预编译包安装暂未实现，请使用 --from-source 选项');
      Result := False;
    end;

    if Result then
      WriteLn('✓ Lazarus ', AVersion, ' 安装完成');

  except
    on E: Exception do
    begin
      WriteLn('错误: 安装过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.UninstallVersion(const AVersion: string): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('Lazarus ', AVersion, ' 未安装');
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);

    WriteLn('正在卸载Lazarus ', AVersion, '...');

    // 删除安装目录
    if DirectoryExists(InstallPath) then
    begin
      try
        {$IFDEF MSWINDOWS}
        // Windows下使用rmdir命令
        with TProcess.Create(nil) do
        try
          Executable := 'cmd';
          Parameters.Add('/c');
          Parameters.Add('rmdir');
          Parameters.Add('/s');
          Parameters.Add('/q');
          Parameters.Add(InstallPath);
          Options := Options + [poWaitOnExit];
          Execute;
          if ExitStatus <> 0 then
            WriteLn('警告: 无法完全删除安装目录: ', InstallPath);
        finally
          Free;
        end;
        {$ELSE}
        // Unix下使用rm命令
        with TProcess.Create(nil) do
        try
          Executable := 'rm';
          Parameters.Add('-rf');
          Parameters.Add(InstallPath);
          Options := Options + [poWaitOnExit];
          Execute;
          if ExitStatus <> 0 then
            WriteLn('警告: 无法完全删除安装目录: ', InstallPath);
        finally
          Free;
        end;
        {$ENDIF}
      except
        WriteLn('警告: 删除安装目录时发生异常: ', InstallPath);
      end;
    end;

    // 从配置中移除
    FConfigManager.RemoveLazarusVersion('lazarus-' + AVersion);

    WriteLn('✓ Lazarus ', AVersion, ' 卸载完成');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 卸载过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.ListVersions(const AShowAll: Boolean): Boolean;
var
  Versions: TLazarusVersionArray;
  i: Integer;
  DefaultVersion: string;
begin
  Result := True;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;

    DefaultVersion := FConfigManager.GetDefaultLazarusVersion;
    if DefaultVersion <> '' then
      DefaultVersion := StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll]);

    if AShowAll then
      WriteLn('可用的Lazarus版本:')
    else
      WriteLn('已安装的Lazarus版本:');

    WriteLn('');
    WriteLn('版本      状态    发布日期    FPC版本  分支');
    WriteLn('------------------------------------------------');

    for i := 0 to High(Versions) do
    begin
      Write(Format('%-8s  ', [Versions[i].Version]));

      if Versions[i].Installed then
      begin
        if SameText(Versions[i].Version, DefaultVersion) then
          Write('已安装*  ')
        else
          Write('已安装   ');
      end else
        Write('可用     ');

      Write(Format('%-10s  ', [Versions[i].ReleaseDate]));
      Write(Format('%-7s  ', [Versions[i].FPCVersion]));
      WriteLn(Versions[i].Branch);
    end;

    WriteLn('');
    if DefaultVersion <> '' then
      WriteLn('默认版本: ', DefaultVersion, ' (标记为 *)')
    else
      WriteLn('未设置默认版本');

  except
    on E: Exception do
    begin
      WriteLn('错误: 列出版本时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('错误: Lazarus版本 ', AVersion, ' 未安装');
    Exit;
  end;

  try
    Result := FConfigManager.SetDefaultLazarusVersion('lazarus-' + AVersion);
    if Result then
      WriteLn('✓ 默认Lazarus版本设置为: ', AVersion)
    else
      WriteLn('错误: 设置默认版本失败');

  except
    on E: Exception do
    begin
      WriteLn('错误: 设置默认版本时发生异常: ', E.Message);
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
    DefaultVersion := FConfigManager.GetDefaultLazarusVersion;
    if DefaultVersion <> '' then
      Result := StringReplace(DefaultVersion, 'lazarus-', '', [rfReplaceAll]);

  except
    on E: Exception do
    begin
      WriteLn('错误: 获取当前版本时发生异常: ', E.Message);
      Result := '';
    end;
  end;
end;

function TLazarusManager.UpdateSources(const AVersion: string): Boolean;
begin
  Result := False;
  WriteLn('更新源码功能暂未实现');
  // TODO: 实现源码更新功能
end;

function TLazarusManager.CleanSources(const AVersion: string): Boolean;
begin
  Result := False;
  WriteLn('清理源码功能暂未实现');
  // TODO: 实现源码清理功能
end;

function TLazarusManager.ShowVersionInfo(const AVersion: string): Boolean;
var
  LazarusInfo: TLazarusInfo;
  InstallPath: string;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    WriteLn('错误: 不支持的Lazarus版本: ', AVersion);
    Exit;
  end;

  try
    WriteLn('Lazarus版本信息: ', AVersion);
    WriteLn('');

    if IsVersionInstalled(AVersion) then
    begin
      InstallPath := GetVersionInstallPath(AVersion);
      WriteLn('状态: 已安装');
      WriteLn('安装路径: ', InstallPath);
      WriteLn('兼容FPC版本: ', GetCompatibleFPCVersion(AVersion));

      if FConfigManager.GetLazarusVersion('lazarus-' + AVersion, LazarusInfo) then
      begin
        WriteLn('关联FPC版本: ', LazarusInfo.FPCVersion);
        WriteLn('源码URL: ', LazarusInfo.SourceURL);
      end;
    end else
    begin
      WriteLn('状态: 未安装');
      WriteLn('兼容FPC版本: ', GetCompatibleFPCVersion(AVersion));
    end;

    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 显示版本信息时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.TestInstallation(const AVersion: string): Boolean;
var
  Process: TProcess;
  LazarusExe: string;
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('错误: Lazarus版本 ', AVersion, ' 未安装');
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    {$IFDEF MSWINDOWS}
    LazarusExe := InstallPath + PathDelim + 'lazarus.exe';
    {$ELSE}
    LazarusExe := InstallPath + PathDelim + 'lazarus';
    {$ENDIF}

    WriteLn('测试Lazarus ', AVersion, ' 安装...');

    Process := TProcess.Create(nil);
    try
      Process.Executable := LazarusExe;
      Process.Parameters.Add('--version');
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      Process.Execute;

      Result := Process.ExitStatus = 0;
      if Result then
        WriteLn('✓ Lazarus ', AVersion, ' 安装测试通过')
      else
        WriteLn('✗ Lazarus ', AVersion, ' 安装测试失败');

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 测试安装时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.LaunchIDE(const AVersion: string): Boolean;
var
  Process: TProcess;
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
    WriteLn('错误: 未指定版本且未设置默认版本');
    Exit;
  end;

  if not IsVersionInstalled(UseVersion) then
  begin
    WriteLn('错误: Lazarus版本 ', UseVersion, ' 未安装');
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(UseVersion);
    {$IFDEF MSWINDOWS}
    LazarusExe := InstallPath + PathDelim + 'lazarus.exe';
    {$ELSE}
    LazarusExe := InstallPath + PathDelim + 'lazarus';
    {$ENDIF}

    WriteLn('启动Lazarus ', UseVersion, '...');

    Process := TProcess.Create(nil);
    try
      Process.Executable := LazarusExe;
      // 不等待进程完成，让IDE在后台运行

      Process.Execute;

      WriteLn('✓ Lazarus ', UseVersion, ' 已启动');
      Result := True;

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('错误: 启动IDE时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TLazarusManager.ConfigureIDE(const AVersion: string): Boolean;
begin
  Result := False;
  WriteLn('IDE配置功能暂未实现');
  // TODO: 实现IDE配置功能
  // - 配置编译器路径
  // - 配置库路径
  // - 配置包路径
  // - 导入/导出配置
end;

// 主要执行函数
procedure execute(const aParams: array of string);
  procedure PrintHelp;
  begin
    WriteLn('Lazarus版本管理');
    WriteLn('');
    WriteLn('用法:');
    WriteLn('  fpdev lazarus install <version> [--from=source] [--fpc=<version>] [--jobs=N]');
    WriteLn('  fpdev lazarus uninstall <version>');
    WriteLn('  fpdev lazarus list [--all]');
    WriteLn('  fpdev lazarus use <version>');
    WriteLn('  fpdev lazarus default <version>');
    WriteLn('  fpdev lazarus show <version>');
    WriteLn('  fpdev lazarus current');
    WriteLn('  fpdev lazarus test <version>');
    WriteLn('  fpdev lazarus run [version]');
    WriteLn('');
    WriteLn('示例:');
    WriteLn('  fpdev lazarus install 3.0 --from=source --jobs=8');
    WriteLn('  fpdev lazarus use 3.0');
    WriteLn('  fpdev lazarus run');
  end;

  function HasFlag(const Params: array of string; const Flag: string): Boolean;
  var i: Integer;
  begin
    Result := False;
    for i := Low(Params) to High(Params) do
      if SameText(Params[i], '--' + Flag) or SameText(Params[i], '-' + Flag) then
        Exit(True);
  end;

  function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;
  var i, p: Integer; s, k: string;
  begin
    Result := False; Value := '';
    k := '--' + Key + '=';
    for i := Low(Params) to High(Params) do
    begin
      s := Params[i]; p := Pos(k, s);
      if p = 1 then begin Value := Copy(s, Length(k) + 1, MaxInt); Exit(True); end;
    end;
  end;
var
  Cmd: string;
  Cfg: TFPDevConfigManager;
  Manager: TLazarusManager;
  Ok: Boolean;
  Ver, S, Jobs, FPCVer: string;
  FromSource: Boolean;
  Settings: TFPDevSettings;
begin
  if Length(aParams) = 0 then
  begin
    PrintHelp;
    Exit;
  end;

  Cmd := LowerCase(aParams[0]);

  Cfg := TFPDevConfigManager.Create('');
  try
    Cfg.LoadConfig;

    Manager := TLazarusManager.Create(Cfg);
    try
      if (Cmd = 'help') then
      begin
        PrintHelp;
      end
      else if (Cmd = 'install') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev lazarus install 3.0');
          Exit;
        end;
        Ver := aParams[1];
        FromSource := HasFlag(aParams, 'from-source') or (GetFlagValue(aParams, 'from', S) and SameText(S, 'source'));
        if GetFlagValue(aParams, 'fpc', FPCVer) then ; // optional override
        if GetFlagValue(aParams, 'jobs', Jobs) then
        begin
          Settings := Cfg.GetSettings;
          if TryStrToInt(Jobs, Settings.ParallelJobs) then
            Cfg.SetSettings(Settings);
        end;
        Ok := Manager.InstallVersion(Ver, FPCVer, FromSource);
        if Ok and Cfg.Modified then Cfg.SaveConfig;
      end
      else if (Cmd = 'uninstall') or (Cmd = 'remove') or (Cmd = 'purge') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev lazarus uninstall 3.0');
          Exit;
        end;
        Ver := aParams[1];
        Ok := Manager.UninstallVersion(Ver);
        if Ok and Cfg.Modified then Cfg.SaveConfig;
      end
      else if (Cmd = 'list') then
      begin
        Ok := Manager.ListVersions(HasFlag(aParams, 'all') or HasFlag(aParams, 'remote'));
      end
      else if (Cmd = 'use') or (Cmd = 'default') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev lazarus use 3.0');
          Exit;
        end;
        Ver := aParams[1];
        Ok := Manager.SetDefaultVersion(Ver);
        if Ok and Cfg.Modified then Cfg.SaveConfig;
      end
      else if (Cmd = 'current') then
      begin
        Ver := Manager.GetCurrentVersion;
        if Ver <> '' then
          WriteLn('当前Lazarus版本: ', Ver)
        else
          WriteLn('未设置默认Lazarus版本');
      end
      else if (Cmd = 'show') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev lazarus show 3.0');
          Exit;
        end;
        Ver := aParams[1];
        Manager.ShowVersionInfo(Ver);
      end
      else if (Cmd = 'test') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev lazarus test 3.0');
          Exit;
        end;
        Ver := aParams[1];
        Manager.TestInstallation(Ver);
      end
      else if (Cmd = 'run') then
      begin
        Ver := '';
        if Length(aParams) > 1 then Ver := aParams[1];
        Manager.LaunchIDE(Ver);
      end
      else
      begin
        PrintHelp;
      end;
    finally
      Manager.Free;
    end;
  finally
    if Cfg.Modified then Cfg.SaveConfig;
    Cfg.Free;
  end;
end;

end.
