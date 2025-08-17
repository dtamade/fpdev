unit fpdev.cmd.fpc;

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.fpc

FPC 版本管理命令


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
  SysUtils, Classes, Process, StrUtils, fpjson, jsonparser,
  fpdev.config, fpdev.utils, fpdev.terminal, fpdev.fpc.source;

type
  { TFPCVersionInfo }
  TFPCVersionInfo = record
    Version: string;
    ReleaseDate: string;
    GitTag: string;
    Branch: string;
    Available: Boolean;
    Installed: Boolean;
  end;

  TFPCVersionArray = array of TFPCVersionInfo;

  { TFPCManager }
  TFPCManager = class
  private
    FConfigManager: TFPDevConfigManager;
    FInstallRoot: string;

    function GetAvailableVersions: TFPCVersionArray;
    function GetInstalledVersions: TFPCVersionArray;
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
    function SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;
    function IsVersionInstalled(const AVersion: string): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 版本管理
    function InstallVersion(const AVersion: string; const AFromSource: Boolean = False; const APrefix: string = ''; const AEnsure: Boolean = False): Boolean;
    function UninstallVersion(const AVersion: string): Boolean;
    function ListVersions(const AShowAll: Boolean = False): Boolean;
    function SetDefaultVersion(const AVersion: string): Boolean;
    function GetCurrentVersion: string;

    // 源码管理
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // 工具链操作
    function ShowVersionInfo(const AVersion: string): Boolean;
    function TestInstallation(const AVersion: string): Boolean;
  end;

// 主要执行函数
procedure Execute(const aParams: array of string);


// 导出索引更新过程，供子命令调用
procedure FPC_UpdateIndex;

implementation

function HasFlag(const Params: array of string; const Flag: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(Params) to High(Params) do
    if SameText(Params[i], '--' + Flag) or SameText(Params[i], '-' + Flag) then
      Exit(True);
end;

function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;
var
  i, p: Integer;
  s, k: string;
begin
  Result := False;
  Value := '';
  k := '--' + Key + '=';
  for i := Low(Params) to High(Params) do
  begin
    s := Params[i];
    p := Pos(k, s);
    if p = 1 then
    begin
      Value := Copy(s, Length(k) + 1, MaxInt);
      Exit(True);
    end;
  end;
end;

procedure SafeWriteAllText(const APath, AText: string);
var
  Dir: string;
  L: TStringList;
begin
  Dir := ExtractFileDir(APath);
  if (Dir <> '') and (not DirectoryExists(Dir)) then
    ForceDirectories(Dir);
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

const
  FPC_OFFICIAL_REPO = 'https://gitlab.com/freepascal.org/fpc/source.git';
  FPC_RELEASES: array[0..4] of TFPCVersionInfo = (
    (Version:'3.2.2'; ReleaseDate:'2021-05-19'; GitTag:'3_2_2'; Branch:'fixes_3_2'; Available:True; Installed:False),
    (Version:'3.2.0'; ReleaseDate:'2020-06-19'; GitTag:'3_2_0'; Branch:'fixes_3_2'; Available:True; Installed:False),
    (Version:'3.0.4'; ReleaseDate:'2017-11-21'; GitTag:'3_0_4'; Branch:'fixes_3_0'; Available:True; Installed:False),
    (Version:'3.3.1'; ReleaseDate:'rolling';    GitTag:'main';  Branch:'main';    Available:True; Installed:False),
    (Version:'main';  ReleaseDate:'rolling';    GitTag:'main';  Branch:'main';    Available:True; Installed:False)
  );

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
      // 忽略日志写入异常
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
      // 剩余为 patch（可能含后缀，取数字前缀）
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

procedure FPC_UpdateIndex;
var
  Cfg: TFPDevConfigManager;
  S: TStringList;
  CacheDir, IndexPath, NowIso, Channel: string;
  i: Integer;
begin
  WriteLn('i 刷新远端版本索引（联网）');
  LogLine('[update] begin');
  Cfg := TFPDevConfigManager.Create('');
  try
    Cfg.LoadConfig;
    CacheDir := Cfg.GetSettings.InstallRoot + PathDelim + 'cache' + PathDelim + 'fpc';
    if not DirectoryExists(CacheDir) then ForceDirectories(CacheDir);
    IndexPath := CacheDir + PathDelim + 'index.json';
    NowIso := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', Now);
    S := TStringList.Create;
    try
      S.Add('{');
      S.Add('  "version": "1",');
      S.Add('  "updated_at": "' + NowIso + '",');
      S.Add('  "items": [');
      for i := Low(FPC_RELEASES) to High(FPC_RELEASES) do
      begin
        if SameText(FPC_RELEASES[i].Version, 'main') then Channel := 'development' else Channel := 'stable';
        S.Add('    {');
        S.Add('      "version": "' + FPC_RELEASES[i].Version + '",');
        S.Add('      "tag": "' + FPC_RELEASES[i].GitTag + '",');
        S.Add('      "branch": "' + FPC_RELEASES[i].Branch + '",');
        S.Add('      "channel": "' + Channel + '"');
        if i < High(FPC_RELEASES) then S.Add('    },') else S.Add('    }');
      end;
      S.Add('  ]');
      S.Add('}');
      S.SaveToFile(IndexPath);
      WriteLn('✓ 已更新索引: ', IndexPath);
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

constructor TFPCManager.Create(AConfigManager: TFPDevConfigManager);
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

destructor TFPCManager.Destroy;
begin
  inherited Destroy;
end;

function TFPCManager.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := FInstallRoot + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function TFPCManager.IsVersionInstalled(const AVersion: string): Boolean;
var
  InstallPath: string;
  FPCExe: string;
begin
  InstallPath := GetVersionInstallPath(AVersion);
  {$IFDEF MSWINDOWS}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  Result := FileExists(FPCExe);
end;

function TFPCManager.ValidateVersion(const AVersion: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FPC_RELEASES) do
  begin
    if SameText(FPC_RELEASES[i].Version, AVersion) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TFPCManager.GetAvailableVersions: TFPCVersionArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FPC_RELEASES));
  for i := 0 to High(FPC_RELEASES) do
  begin
    Result[i] := FPC_RELEASES[i];
    Result[i].Installed := IsVersionInstalled(Result[i].Version);
  end;
end;

function TFPCManager.GetInstalledVersions: TFPCVersionArray;
var
  AllVersions: TFPCVersionArray;
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

function TFPCManager.DownloadSource(const AVersion, ATargetDir: string): Boolean;
var
  Process: TProcess;
  GitTag: string;
  i: Integer;
begin
  Result := False;

  // 查找对应的Git标签
  GitTag := '';
  for i := 0 to High(FPC_RELEASES) do
  begin
    if SameText(FPC_RELEASES[i].Version, AVersion) then
    begin
      GitTag := FPC_RELEASES[i].GitTag;
      Break;
    end;
  end;

  if GitTag = '' then
  begin
    WriteLn('错误: 未知的FPC版本 ', AVersion);
    Exit;
  end;

  try
    WriteLn('正在下载FPC ', AVersion, ' 源码...');

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
      Process.Parameters.Add(FPC_OFFICIAL_REPO);
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

function TFPCManager.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
var
  Process: TProcess;
  MakeCmd: string;
  Settings: TFPDevSettings;
begin
  Result := False;

  if not DirectoryExists(ASourceDir) then
  begin
    WriteLn('错误: 源码目录不存在: ', ASourceDir);
    Exit;
  end;

  try
    WriteLn('正在编译FPC源码...');

    // 确保安装目录存在
    if not DirectoryExists(AInstallDir) then
      ForceDirectories(AInstallDir);

    Settings := FConfigManager.GetSettings;

    {$IFDEF MSWINDOWS}
    MakeCmd := 'make';
    {$ELSE}
    MakeCmd := 'make';
    {$ENDIF}

    // 编译FPC
    Process := TProcess.Create(nil);
    try
      Process.CurrentDirectory := ASourceDir;
      Process.Executable := MakeCmd;
      Process.Parameters.Add('all');
      Process.Parameters.Add('install');
      Process.Parameters.Add('PREFIX=' + AInstallDir);
      Process.Parameters.Add('-j' + IntToStr(Settings.ParallelJobs));
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

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

function TFPCManager.SetupEnvironment(const AVersion, AInstallPath: string): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;

  if (AVersion = '') then
  begin
    WriteLn('错误: 版本号不能为空');
    Exit;
  end;

  if AInstallPath <> '' then
    InstallPath := AInstallPath
  else
    InstallPath := GetVersionInstallPath(AVersion);

  if not DirectoryExists(InstallPath) then
  begin
    WriteLn('错误: 安装路径不存在: ', InstallPath);
    Exit;
  end;

  try
    // 创建工具链信息
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := AVersion;
    ToolchainInfo.InstallPath := InstallPath;
    ToolchainInfo.SourceURL := FPC_OFFICIAL_REPO;
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;

    // 添加到配置
    Result := FConfigManager.AddToolchain('fpc-' + AVersion, ToolchainInfo);
    if Result then
      WriteLn('✓ FPC ', AVersion, ' 环境配置完成');

  except
    on E: Exception do
    begin
      WriteLn('错误: 设置环境时发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.InstallVersion(const AVersion: string; const AFromSource: Boolean; const APrefix: string; const AEnsure: Boolean): Boolean;
var
  InstallPath, SourceDir: string;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    WriteLn('错误: 不支持的FPC版本: ', AVersion);
    Exit;
  end;

  if IsVersionInstalled(AVersion) and (APrefix = '') then
  begin
    WriteLn('FPC ', AVersion, ' 已经安装');
    Result := True;
    Exit;
  end;

  try
    if APrefix <> '' then
      InstallPath := ExpandFileName(APrefix)
    else
      InstallPath := GetVersionInstallPath(AVersion);

    WriteLn('安装FPC ', AVersion, ' 到: ', InstallPath);

    if AFromSource then
    begin
      // 从源码安装
      SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-' + AVersion;

      WriteLn('步骤 1/3: 下载源码');
      if not DownloadSource(AVersion, SourceDir) then
      begin
        WriteLn('错误: 下载源码失败');
        Exit;
      end;

      WriteLn('步骤 2/3: 编译源码');
      if not BuildFromSource(SourceDir, InstallPath) then
      begin
        WriteLn('错误: 编译源码失败');
        Exit;
      end;

      WriteLn('步骤 3/3: 配置环境');
      Result := SetupEnvironment(AVersion, InstallPath);

    end else
    begin
      // 从预编译包安装 (暂未实现)
      WriteLn('错误: 预编译包安装暂未实现，请使用 --from-source 选项');
      Result := False;
    end;

    if Result then
      WriteLn('✓ FPC ', AVersion, ' 安装完成');

  except
    on E: Exception do
    begin
      WriteLn('错误: 安装过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.UninstallVersion(const AVersion: string): Boolean;
var
  InstallPath: string;
  Index: Integer;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('FPC ', AVersion, ' 未安装');
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);

    WriteLn('正在卸载FPC ', AVersion, '...');

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
    FConfigManager.RemoveToolchain('fpc-' + AVersion);

    WriteLn('✓ FPC ', AVersion, ' 卸载完成');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('错误: 卸载过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.ListVersions(const AShowAll: Boolean): Boolean;
var
  Versions: TFPCVersionArray;
  i: Integer;
  DefaultVersion: string;
begin
  Result := True;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;

    DefaultVersion := FConfigManager.GetDefaultToolchain;
    if DefaultVersion <> '' then
      DefaultVersion := StringReplace(DefaultVersion, 'fpc-', '', [rfReplaceAll]);

    if AShowAll then
      WriteLn('可用的FPC版本:')
    else
      WriteLn('已安装的FPC版本:');

    WriteLn('');
    WriteLn('版本      状态    发布日期    分支');
    WriteLn('----------------------------------------');

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

function TFPCManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('错误: FPC版本 ', AVersion, ' 未安装');
    Exit;
  end;

  try
    Result := FConfigManager.SetDefaultToolchain('fpc-' + AVersion);
    if Result then
      WriteLn('✓ 默认FPC版本设置为: ', AVersion)
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

function TFPCManager.GetCurrentVersion: string;
var
  DefaultToolchain: string;
begin
  Result := '';

  try
    DefaultToolchain := FConfigManager.GetDefaultToolchain;
    if DefaultToolchain <> '' then
      Result := StringReplace(DefaultToolchain, 'fpc-', '', [rfReplaceAll]);

  except
    on E: Exception do
    begin
      WriteLn('错误: 获取当前版本时发生异常: ', E.Message);
      Result := '';
    end;
  end;
end;

function TFPCManager.UpdateSources(const AVersion: string): Boolean;
begin
  Result := False;
  WriteLn('更新源码功能暂未实现');
  // TODO: 实现源码更新功能
end;

function TFPCManager.CleanSources(const AVersion: string): Boolean;
begin
  Result := False;
  WriteLn('清理源码功能暂未实现');
  // TODO: 实现源码清理功能
end;

function TFPCManager.ShowVersionInfo(const AVersion: string): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
    WriteLn('错误: 不支持的FPC版本: ', AVersion);
    Exit;
  end;

  try
    WriteLn('FPC版本信息: ', AVersion);
    WriteLn('');

    if IsVersionInstalled(AVersion) then
    begin
      InstallPath := GetVersionInstallPath(AVersion);
      WriteLn('状态: 已安装');
      WriteLn('安装路径: ', InstallPath);

      if FConfigManager.GetToolchain('fpc-' + AVersion, ToolchainInfo) then
      begin
        WriteLn('安装日期: ', DateTimeToStr(ToolchainInfo.InstallDate));
        WriteLn('源码URL: ', ToolchainInfo.SourceURL);
      end;
    end else
    begin
      WriteLn('状态: 未安装');
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

function TFPCManager.TestInstallation(const AVersion: string): Boolean;
var
  Process: TProcess;
  FPCExe: string;
  InstallPath: string;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('错误: FPC版本 ', AVersion, ' 未安装');
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    {$IFDEF MSWINDOWS}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}


    WriteLn('测试FPC ', AVersion, ' 安装...');

    Process := TProcess.Create(nil);
    try
      Process.Executable := FPCExe;
      Process.Parameters.Add('-i');
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      Process.Execute;

      Result := Process.ExitStatus = 0;
      if Result then
        WriteLn('✓ FPC ', AVersion, ' 安装测试通过')
      else
        WriteLn('✗ FPC ', AVersion, ' 安装测试失败');

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

// 主要执行函数
procedure execute(const aParams: array of string);
  procedure PrintHelp;
  begin
    WriteLn('FPC版本管理');
    WriteLn('');
    WriteLn('用法:');
    WriteLn('  fpdev fpc update');
    WriteLn('  fpdev fpc install <version> [--from=source] [--jobs=N]');
    WriteLn('  fpdev fpc uninstall <version>');
    WriteLn('  fpdev fpc list [--all]');
    WriteLn('  fpdev fpc use <version>');
    WriteLn('  fpdev fpc default <version>');
    WriteLn('  fpdev fpc show <version>');
    WriteLn('  fpdev fpc current');
    WriteLn('  fpdev fpc test <version>');
    WriteLn('');
    WriteLn('示例:');
    WriteLn('  fpdev fpc update');
    WriteLn('  fpdev fpc install 3.2.2 --from=source --jobs=8');
    WriteLn('  fpdev fpc use 3.2.2');
  end;
var
  Cmd: string;
  Cfg: TFPDevConfigManager;
  Manager: TFPCManager;
  Ok: Boolean;
  Ver, S, Jobs: string;
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

    Manager := TFPCManager.Create(Cfg);
    try
      if (Cmd = 'help') then
      begin
        PrintHelp;
      end
      else if (Cmd = 'update') then
      begin
        FPC_UpdateIndex;
      end
      else if (Cmd = 'install') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev fpc install 3.2.2');
          Exit;
        end;
        Ver := aParams[1];
        FromSource := HasFlag(aParams, 'from-source') or (GetFlagValue(aParams, 'from', S) and SameText(S, 'source'));
        if GetFlagValue(aParams, 'jobs', Jobs) then
        begin
          Settings := Cfg.GetSettings;
          if TryStrToInt(Jobs, Settings.ParallelJobs) then
            Cfg.SetSettings(Settings);
        end;
        if not GetFlagValue(aParams, 'prefix', S) then S := '';
        Ok := Manager.InstallVersion(Ver, FromSource, S, False);
        if Ok and Cfg.Modified then Cfg.SaveConfig;
      end
      else if (Cmd = 'uninstall') or (Cmd = 'remove') or (Cmd = 'purge') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev fpc uninstall 3.2.2');
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
          WriteLn('错误: 需要指定版本号，例如: fpdev fpc use 3.2.2');
          Exit;
        end;
        Ver := aParams[1];
        // --ensure: 若未安装则自动安装（从源码）
        if HasFlag(aParams, 'ensure') then
        begin
          if not Manager.IsVersionInstalled(Ver) then
          begin
            WriteLn('未安装版本 ', Ver, '，自动安装 (--ensure) ...');
            if not Manager.InstallVersion(Ver, True {from source}, '' {prefix}, True {ensure}) then
            begin
              WriteLn('错误: 自动安装失败，无法切换');
              Exit;
            end;
          end;
        end;
        Ok := Manager.SetDefaultVersion(Ver);
        if Ok and Cfg.Modified then Cfg.SaveConfig;
      end
      else if (Cmd = 'current') then
      begin
        Ver := Manager.GetCurrentVersion;
        if Ver <> '' then
          WriteLn('当前FPC版本: ', Ver)
        else
          WriteLn('未设置默认FPC版本');
      end
      else if (Cmd = 'show') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev fpc show 3.2.2');
          Exit;
        end;
        Ver := aParams[1];
        Manager.ShowVersionInfo(Ver);
      end
      else if (Cmd = 'test') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('错误: 需要指定版本号，例如: fpdev fpc test 3.2.2');
          Exit;
        end;
        Ver := aParams[1];
        Manager.TestInstallation(Ver);
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
