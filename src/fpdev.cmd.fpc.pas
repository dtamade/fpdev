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

  { TVerificationResult }
  TVerificationResult = record
    Verified: Boolean;
    ExecutableExists: Boolean;
    DetectedVersion: string;
    SmokeTestPassed: Boolean;
    ErrorMessage: string;
  end;

  { Installation Scope }
  TInstallScope = (isUser, isProject, isSystem);

  { Source Mode for installation }
  TSourceMode = (smAuto, smBinary, smSource);

  { Verification Info for metadata }
  TVerifyInfo = record
    Timestamp: TDateTime;
    OK: Boolean;
    DetectedVersion: string;
    SmokeTestPassed: Boolean;
  end;

  { Origin Info for metadata }
  TOriginInfo = record
    RepoURL: string;
    Commit: string;
    BuiltFromSource: Boolean;
  end;

  { FPDev Installation Metadata }
  TFPDevMetadata = record
    Version: string;
    Scope: TInstallScope;
    SourceMode: TSourceMode;
    Channel: string;
    Prefix: string;
    Verify: TVerifyInfo;
    Origin: TOriginInfo;
    InstalledAt: TDateTime;
  end;

  { Activation Result }
  TActivationResult = record
    Success: Boolean;
    Scope: TInstallScope;
    ActivationScript: string;  // Main activation script path (.cmd or .sh)
    VSCodeSettings: string;     // VS Code settings.json path (if created)
    ShellCommand: string;       // Shell command to print to user
    ErrorMessage: string;
  end;

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
    function IsVersionInstalled(const AVersion: string): Boolean;
    function RunSmokeTest(const AFPCExe: string; var VerifResult: TVerificationResult): Boolean;

    // Scoped installation support
    function DetectInstallScope(const ACurrentDir: string): TInstallScope;

    // Activation support
    function FindProjectRoot(const AStartDir: string): string;
    function CreateWindowsActivationScript(const AScriptPath, ABinPath: string): Boolean;
    function CreateUnixActivationScript(const AScriptPath, ABinPath: string): Boolean;
    function UpdateVSCodeSettings(const AProjectRoot, ABinPath: string): Boolean;

  public
    constructor Create(AConfigManager: TFPDevConfigManager);
    destructor Destroy; override;

    // 版本管理
    function InstallVersion(const AVersion: string; const AFromSource: Boolean = False; const APrefix: string = ''; const AEnsure: Boolean = False): Boolean;
    function UninstallVersion(const AVersion: string): Boolean;
    function ListVersions(const AShowAll: Boolean = False): Boolean;
    function SetDefaultVersion(const AVersion: string): Boolean;
    function GetCurrentVersion: string;
    function ActivateVersion(const AVersion: string): TActivationResult;

    // 源码管理
    function UpdateSources(const AVersion: string = ''): Boolean;
    function CleanSources(const AVersion: string = ''): Boolean;

    // 工具链操作
    function ShowVersionInfo(const AVersion: string): Boolean;
    function TestInstallation(const AVersion: string): Boolean;
    function VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;

    // Metadata operations (public for testing)
    function WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
    function ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
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
  // WriteLn('i 刷新远端版本索引（联网）');  // 调试代码已注释
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
  // WriteLn('✓ 已更新索引: ', IndexPath);  // 调试代码已注释
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

function TFPCManager.DetectInstallScope(const ACurrentDir: string): TInstallScope;
var
  Dir, FPDevDir: string;
begin
  // Default to user scope
  Result := isUser;

  // Start from current directory and search up
  Dir := ExpandFileName(ACurrentDir);

  while Dir <> '' do
  begin
    FPDevDir := Dir + PathDelim + '.fpdev';
    if DirectoryExists(FPDevDir) then
    begin
      Result := isProject;
      Exit;
    end;

    // Move up to parent directory
    Dir := ExtractFileDir(Dir);

    // Stop at root (when parent == current)
    if Dir = ExtractFileDir(Dir) then
      Break;
  end;
end;

function TFPCManager.FindProjectRoot(const AStartDir: string): string;
var
  Dir: string;
begin
  Result := '';
  Dir := ExpandFileName(AStartDir);

  while Dir <> '' do
  begin
    if DirectoryExists(Dir + PathDelim + '.fpdev') then
    begin
      Result := Dir;
      Exit;
    end;

    // Move up to parent directory
    Dir := ExtractFileDir(Dir);

    // Stop at root (when parent == current)
    if Dir = ExtractFileDir(Dir) then
      Break;
  end;
end;

function TFPCManager.CreateWindowsActivationScript(const AScriptPath, ABinPath: string): Boolean;
var
  Script: TStringList;
begin
  Result := False;

  try
    Script := TStringList.Create;
    try
      Script.Add('@echo off');
      Script.Add('REM FPC Environment Activation Script');
      Script.Add('REM Generated by fpdev');
      Script.Add('');
      Script.Add('SET "PATH=' + ABinPath + ';%PATH%"');
      Script.Add('');
      Script.Add('echo FPC environment activated');
      Script.Add('echo FPC bin directory: ' + ABinPath);

      SafeWriteAllText(AScriptPath, Script.Text);
      Result := True;
    finally
      Script.Free;
    end;
  except
    Result := False;
  end;
end;

function TFPCManager.CreateUnixActivationScript(const AScriptPath, ABinPath: string): Boolean;
var
  Script: TStringList;
begin
  Result := False;

  try
    Script := TStringList.Create;
    try
      Script.Add('#!/bin/sh');
      Script.Add('# FPC Environment Activation Script');
      Script.Add('# Generated by fpdev');
      Script.Add('');
      Script.Add('export PATH="' + ABinPath + ':$PATH"');
      Script.Add('');
      Script.Add('echo "FPC environment activated"');
      Script.Add('echo "FPC bin directory: ' + ABinPath + '"');

      SafeWriteAllText(AScriptPath, Script.Text);
      Result := True;
    finally
      Script.Free;
    end;
  except
    Result := False;
  end;
end;

function TFPCManager.UpdateVSCodeSettings(const AProjectRoot, ABinPath: string): Boolean;
var
  VSCodeDir, SettingsPath, JSONText: string;
  JSON: TJSONObject;
  Parser: TJSONParser;
  EnvObj: TJSONObject;
  PathValue: string;
begin
  Result := False;

  try
    VSCodeDir := AProjectRoot + PathDelim + '.vscode';
    if not DirectoryExists(VSCodeDir) then
      ForceDirectories(VSCodeDir);

    SettingsPath := VSCodeDir + PathDelim + 'settings.json';

    // Read existing settings or create new
    if FileExists(SettingsPath) then
    begin
      JSONText := ReadAllTextIfExists(SettingsPath);
      if JSONText <> '' then
      begin
        Parser := TJSONParser.Create(JSONText);
        try
          JSON := TJSONObject(Parser.Parse);
        finally
          Parser.Free;
        end;
      end
      else
        JSON := TJSONObject.Create;
    end
    else
      JSON := TJSONObject.Create;

    try
      // Update terminal.integrated.env.windows/linux/osx based on platform
      {$IFDEF MSWINDOWS}
      if not JSON.Find('terminal.integrated.env.windows', EnvObj) then
      begin
        EnvObj := TJSONObject.Create;
        JSON.Add('terminal.integrated.env.windows', EnvObj);
      end;
      PathValue := ABinPath + ';%PATH%';
      {$ENDIF}

      {$IFDEF LINUX}
      if not JSON.Find('terminal.integrated.env.linux', EnvObj) then
      begin
        EnvObj := TJSONObject.Create;
        JSON.Add('terminal.integrated.env.linux', EnvObj);
      end;
      PathValue := ABinPath + ':$PATH';
      {$ENDIF}

      {$IFDEF DARWIN}
      if not JSON.Find('terminal.integrated.env.osx', EnvObj) then
      begin
        EnvObj := TJSONObject.Create;
        JSON.Add('terminal.integrated.env.osx', EnvObj);
      end;
      PathValue := ABinPath + ':$PATH';
      {$ENDIF}

      // Set PATH value
      EnvObj.Strings['PATH'] := PathValue;

      // Write settings
      SafeWriteAllText(SettingsPath, JSON.FormatJSON);
      Result := True;
    finally
      JSON.Free;
    end;
  except
    Result := False;
  end;
end;

function TFPCManager.WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
var
  MetaPath: string;
  JSON, VerifyObj, OriginObj: TJSONObject;
  ScopeStr, SourceModeStr: string;
begin
  Result := False;

  try
    MetaPath := AInstallPath + PathDelim + '.fpdev-meta.json';

    // Convert enum to string
    case AMeta.Scope of
      isUser: ScopeStr := 'user';
      isProject: ScopeStr := 'project';
      isSystem: ScopeStr := 'system';
    end;

    case AMeta.SourceMode of
      smAuto: SourceModeStr := 'auto';
      smBinary: SourceModeStr := 'binary';
      smSource: SourceModeStr := 'source';
    end;

    // Build JSON object
    JSON := TJSONObject.Create;
    try
      JSON.Add('version', AMeta.Version);
      JSON.Add('scope', ScopeStr);
      JSON.Add('source_mode', SourceModeStr);
      JSON.Add('channel', AMeta.Channel);
      JSON.Add('prefix', AMeta.Prefix);

      // Verify object
      VerifyObj := TJSONObject.Create;
      VerifyObj.Add('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AMeta.Verify.Timestamp));
      VerifyObj.Add('ok', AMeta.Verify.OK);
      VerifyObj.Add('detected_version', AMeta.Verify.DetectedVersion);
      VerifyObj.Add('smoke_test_passed', AMeta.Verify.SmokeTestPassed);
      JSON.Add('verify', VerifyObj);

      // Origin object
      OriginObj := TJSONObject.Create;
      OriginObj.Add('repo_url', AMeta.Origin.RepoURL);
      OriginObj.Add('commit', AMeta.Origin.Commit);
      OriginObj.Add('built_from_source', AMeta.Origin.BuiltFromSource);
      JSON.Add('origin', OriginObj);

      JSON.Add('installed_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AMeta.InstalledAt));

      // Write to file
      SafeWriteAllText(MetaPath, JSON.FormatJSON);
      Result := True;
    finally
      JSON.Free;
    end;

  except
    on E: Exception do
    begin
      // Silent failure for now
      Result := False;
    end;
  end;
end;

function TFPCManager.ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
var
  MetaPath, JSONText, ScopeStr, SourceModeStr: string;
  JSON, VerifyObj, OriginObj: TJSONObject;
  Parser: TJSONParser;
begin
  Result := False;
  FillChar(AMeta, SizeOf(AMeta), 0);

  try
    MetaPath := AInstallPath + PathDelim + '.fpdev-meta.json';

    if not FileExists(MetaPath) then
      Exit;

    JSONText := ReadAllTextIfExists(MetaPath);
    if JSONText = '' then
      Exit;

    Parser := TJSONParser.Create(JSONText);
    try
      JSON := TJSONObject(Parser.Parse);
      try
        // Read basic fields
        AMeta.Version := JSON.Get('version', '');
        ScopeStr := JSON.Get('scope', 'user');
        SourceModeStr := JSON.Get('source_mode', 'auto');
        AMeta.Channel := JSON.Get('channel', '');
        AMeta.Prefix := JSON.Get('prefix', '');

        // Parse scope
        if ScopeStr = 'project' then
          AMeta.Scope := isProject
        else if ScopeStr = 'system' then
          AMeta.Scope := isSystem
        else
          AMeta.Scope := isUser;

        // Parse source mode
        if SourceModeStr = 'binary' then
          AMeta.SourceMode := smBinary
        else if SourceModeStr = 'source' then
          AMeta.SourceMode := smSource
        else
          AMeta.SourceMode := smAuto;

        // Read verify object
        if JSON.Find('verify', VerifyObj) then
        begin
          AMeta.Verify.OK := VerifyObj.Get('ok', False);
          AMeta.Verify.DetectedVersion := VerifyObj.Get('detected_version', '');
          AMeta.Verify.SmokeTestPassed := VerifyObj.Get('smoke_test_passed', False);
          // Note: Timestamp parsing omitted for simplicity in v1
        end;

        // Read origin object
        if JSON.Find('origin', OriginObj) then
        begin
          AMeta.Origin.RepoURL := OriginObj.Get('repo_url', '');
          AMeta.Origin.Commit := OriginObj.Get('commit', '');
          AMeta.Origin.BuiltFromSource := OriginObj.Get('built_from_source', False);
        end;

        // Note: InstalledAt parsing omitted for simplicity in v1

        Result := True;
      finally
        JSON.Free;
      end;
    finally
      Parser.Free;
    end;

  except
    on E: Exception do
    begin
      // Silent failure
      Result := False;
    end;
  end;
end;

function TFPCManager.GetVersionInstallPath(const AVersion: string): string;
var
  Scope: TInstallScope;
  ProjectRoot: string;
begin
  // Detect current scope
  Scope := DetectInstallScope(GetCurrentDir);

  if Scope = isProject then
  begin
    // Find project root by searching for .fpdev
    ProjectRoot := GetCurrentDir;
    while ProjectRoot <> '' do
    begin
      if DirectoryExists(ProjectRoot + PathDelim + '.fpdev') then
      begin
        Result := ProjectRoot + PathDelim + '.fpdev' + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + AVersion;
        Exit;
      end;
      ProjectRoot := ExtractFileDir(ProjectRoot);
      if ProjectRoot = ExtractFileDir(ProjectRoot) then
        Break;
    end;
  end;

  // Default to user scope
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
  // WriteLn('错误: 未知的FPC版本 ', AVersion);  // 调试代码已注释
    Exit;
  end;

  try
  // WriteLn('正在下载FPC ', AVersion, ' 源码...');  // 调试代码已注释

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
  // WriteLn('错误: Git克隆失败，退出代码: ', Process.ExitStatus);  // 调试代码已注释

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 下载源码时发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('错误: 源码目录不存在: ', ASourceDir);  // 调试代码已注释
    Exit;
  end;

  try
  // WriteLn('正在编译FPC源码...');  // 调试代码已注释

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

  // WriteLn('执行命令: ', Process.Executable, ' ', Process.Parameters.Text);  // 调试代码已注释
      Process.Execute;

      Result := Process.ExitStatus = 0;
      if not Result then
  // WriteLn('错误: 编译失败，退出代码: ', Process.ExitStatus);  // 调试代码已注释

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 编译源码时发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('错误: 版本号不能为空');  // 调试代码已注释
    Exit;
  end;

  if AInstallPath <> '' then
    InstallPath := AInstallPath
  else
    InstallPath := GetVersionInstallPath(AVersion);

  if not DirectoryExists(InstallPath) then
  begin
  // WriteLn('错误: 安装路径不存在: ', InstallPath);  // 调试代码已注释
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
  // WriteLn('✓ FPC ', AVersion, ' 环境配置完成');  // 调试代码已注释

  except
    on E: Exception do
    begin
  // WriteLn('错误: 设置环境时发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('错误: 不支持的FPC版本: ', AVersion);  // 调试代码已注释
    Exit;
  end;

  if IsVersionInstalled(AVersion) and (APrefix = '') then
  begin
  // WriteLn('FPC ', AVersion, ' 已经安装');  // 调试代码已注释
    Result := True;
    Exit;
  end;

  try
    if APrefix <> '' then
      InstallPath := ExpandFileName(APrefix)
    else
      InstallPath := GetVersionInstallPath(AVersion);

  // WriteLn('安装FPC ', AVersion, ' 到: ', InstallPath);  // 调试代码已注释

    if AFromSource then
    begin
      // 从源码安装
      SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-' + AVersion;

  // WriteLn('步骤 1/3: 下载源码');  // 调试代码已注释
      if not DownloadSource(AVersion, SourceDir) then
      begin
  // WriteLn('错误: 下载源码失败');  // 调试代码已注释
        Exit;
      end;

  // WriteLn('步骤 2/3: 编译源码');  // 调试代码已注释
      if not BuildFromSource(SourceDir, InstallPath) then
      begin
  // WriteLn('错误: 编译源码失败');  // 调试代码已注释
        Exit;
      end;

  // WriteLn('步骤 3/3: 配置环境');  // 调试代码已注释
      Result := SetupEnvironment(AVersion, InstallPath);

    end else
    begin
      // 从预编译包安装 (暂未实现)
  // WriteLn('错误: 预编译包安装暂未实现，请使用 --from-source 选项');  // 调试代码已注释
      Result := False;
    end;

    if Result then
  // WriteLn('✓ FPC ', AVersion, ' 安装完成');  // 调试代码已注释

  except
    on E: Exception do
    begin
  // WriteLn('错误: 安装过程中发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('FPC ', AVersion, ' 未安装');  // 调试代码已注释
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);

  // WriteLn('正在卸载FPC ', AVersion, '...');  // 调试代码已注释

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
  // WriteLn('警告: 无法完全删除安装目录: ', InstallPath);  // 调试代码已注释
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
  // WriteLn('警告: 无法完全删除安装目录: ', InstallPath);  // 调试代码已注释
        finally
          Free;
        end;
        {$ENDIF}
      except
  // WriteLn('警告: 删除安装目录时发生异常: ', InstallPath);  // 调试代码已注释
      end;
    end;

    // 从配置中移除
    FConfigManager.RemoveToolchain('fpc-' + AVersion);

  // WriteLn('✓ FPC ', AVersion, ' 卸载完成');  // 调试代码已注释
    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 卸载过程中发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('可用的FPC版本:')  // 调试代码已注释
    else
  // WriteLn('已安装的FPC版本:');  // 调试代码已注释

  // WriteLn('');  // 调试代码已注释
  // WriteLn('版本      状态    发布日期    分支');  // 调试代码已注释
  // WriteLn('----------------------------------------');  // 调试代码已注释

    for i := 0 to High(Versions) do
    begin
      Write(Format('%-8s  ', [Versions[i].Version]));

      if Versions[i].Installed then
      begin
        if SameText(Versions[i].Version, DefaultVersion) then
          Write('Installed*  ')
        else
          Write('Installed   ');
      end else
        Write('Available   ');

      Write(Format('%-10s  ', [Versions[i].ReleaseDate]));
      WriteLn(Versions[i].Branch);
    end;

  // WriteLn('');  // 调试代码已注释
    if DefaultVersion <> '' then
    begin
      // WriteLn('默认版本: ', DefaultVersion, ' (标记为 *)')  // 调试代码已注释
    end
    else
    begin
      // WriteLn('未设置默认版本');  // 调试代码已注释
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 列出版本时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TFPCManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
  // WriteLn('错误: FPC版本 ', AVersion, ' 未安装');  // 调试代码已注释
    Exit;
  end;

  try
    Result := FConfigManager.SetDefaultToolchain('fpc-' + AVersion);
    if Result then
    begin
      // WriteLn('✓ 默认FPC版本设置为: ', AVersion)  // 调试代码已注释
    end
    else
    begin
      // WriteLn('错误: 设置默认版本失败');  // 调试代码已注释
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 设置默认版本时发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('错误: 获取当前版本时发生异常: ', E.Message);  // 调试代码已注释
      Result := '';
    end;
  end;
end;

function TFPCManager.ActivateVersion(const AVersion: string): TActivationResult;
var
  Scope: TInstallScope;
  ProjectRoot, InstallPath, BinPath, EnvDir: string;
  ActivateCmd, ActivateSh, VSCodeSettingsPath: string;
begin
  // Initialize result
  FillChar(Result, SizeOf(Result), 0);
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

  // Detect scope
  Scope := DetectInstallScope(GetCurrentDir);
  Result.Scope := Scope;

  if Scope = isProject then
  begin
    // Project scope: create scripts in .fpdev/env
    ProjectRoot := FindProjectRoot(GetCurrentDir);
    if ProjectRoot = '' then
    begin
      Result.ErrorMessage := 'Cannot find project root (.fpdev directory)';
      Exit;
    end;

    EnvDir := ProjectRoot + PathDelim + '.fpdev' + PathDelim + 'env';
    if not DirectoryExists(EnvDir) then
      ForceDirectories(EnvDir);

    // Create activation scripts
    ActivateCmd := EnvDir + PathDelim + 'activate.cmd';
    ActivateSh := EnvDir + PathDelim + 'activate.sh';

    if not CreateWindowsActivationScript(ActivateCmd, BinPath) then
    begin
      Result.ErrorMessage := 'Failed to create Windows activation script';
      Exit;
    end;

    if not CreateUnixActivationScript(ActivateSh, BinPath) then
    begin
      Result.ErrorMessage := 'Failed to create Unix activation script';
      Exit;
    end;

    Result.ActivationScript := ActivateCmd; // Primary script for current platform

    // Optional: Update VS Code settings (non-fatal if fails)
    if UpdateVSCodeSettings(ProjectRoot, BinPath) then
    begin
      VSCodeSettingsPath := ProjectRoot + PathDelim + '.vscode' + PathDelim + 'settings.json';
      Result.VSCodeSettings := VSCodeSettingsPath;
    end;

    // Generate shell command
    {$IFDEF MSWINDOWS}
    Result.ShellCommand := '.fpdev\env\activate.cmd';
    {$ELSE}
    Result.ShellCommand := 'source .fpdev/env/activate.sh';
    {$ENDIF}
  end
  else
  begin
    // User scope: create scripts in ~/.fpdev/env
    EnvDir := ExtractFileDir(FConfigManager.ConfigPath) + PathDelim + 'env';
    if not DirectoryExists(EnvDir) then
      ForceDirectories(EnvDir);

    ActivateCmd := EnvDir + PathDelim + 'activate-' + AVersion + '.cmd';
    ActivateSh := EnvDir + PathDelim + 'activate-' + AVersion + '.sh';

    if not CreateWindowsActivationScript(ActivateCmd, BinPath) then
    begin
      Result.ErrorMessage := 'Failed to create Windows activation script';
      Exit;
    end;

    if not CreateUnixActivationScript(ActivateSh, BinPath) then
    begin
      Result.ErrorMessage := 'Failed to create Unix activation script';
      Exit;
    end;

    Result.ActivationScript := ActivateCmd;

    // Generate shell command
    {$IFDEF MSWINDOWS}
    Result.ShellCommand := EnvDir + PathDelim + 'activate-' + AVersion + '.cmd';
    {$ELSE}
    Result.ShellCommand := 'source ' + EnvDir + PathDelim + 'activate-' + AVersion + '.sh';
    {$ENDIF}
  end;

  // Set as default version
  if not SetDefaultVersion(AVersion) then
  begin
    Result.ErrorMessage := 'Failed to set default version';
    Exit;
  end;

  Result.Success := True;
end;

function TFPCManager.UpdateSources(const AVersion: string): Boolean;
var
  SourceDir: string;
  GitDir: string;
  Process: TProcess;
  OutputLines: TStringList;
  HasRemote: Boolean;
begin
  Result := False;

  // Determine source directory
  if AVersion = '' then
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-main'
  else
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;

  // Validate source directory exists
  if not DirectoryExists(SourceDir) then
  begin
    WriteLn('Error: FPC source directory does not exist: ', SourceDir);
    Exit;
  end;

  // Check if it's a git repository
  GitDir := SourceDir + PathDelim + '.git';
  if not DirectoryExists(GitDir) then
  begin
    WriteLn('Error: Directory is not a git repository: ', SourceDir);
    Exit;
  end;

  try
    // Check if remote is configured by reading git remote output
    HasRemote := False;
    OutputLines := TStringList.Create;
    try
      Process := TProcess.Create(nil);
      try
        Process.Executable := 'git';
        Process.Parameters.Add('remote');
        Process.CurrentDirectory := SourceDir;
        Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

        Process.Execute;

        // Read output to check if any remotes are configured
        if Process.ExitStatus = 0 then
        begin
          OutputLines.LoadFromStream(Process.Output);
          HasRemote := OutputLines.Count > 0;
        end;
      finally
        Process.Free;
      end;
    finally
      OutputLines.Free;
    end;

    // If no remote configured, repository is already up-to-date (local only)
    if not HasRemote then
    begin
      WriteLn('FPC source is local-only (no remote configured): ', SourceDir);
      Result := True;
      Exit;
    end;

    // Execute git pull to update sources
    Process := TProcess.Create(nil);
    try
      Process.Executable := 'git';
      Process.Parameters.Add('pull');
      Process.CurrentDirectory := SourceDir;
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      Process.Execute;

      Result := Process.ExitStatus = 0;
      if Result then
        WriteLn('Updated FPC source: ', SourceDir)
      else
        WriteLn('Error: git pull failed (exit code: ', Process.ExitStatus, ')');

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('Error updating FPC sources: ', E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.CleanSources(const AVersion: string): Boolean;
const
  // 编译产物扩展名
  {$IFDEF MSWINDOWS}
  CLEANABLE_EXTENSIONS: array[0..6] of string = (
    '.o',        // Object files
    '.ppu',      // Compiled Pascal units
    '.a',        // Static libraries
    '.dll',      // Dynamic libraries (Windows)
    '.exe',      // Executables (Windows)
    '.compiled', // Lazarus state files
    '.res'       // Resource files
  );
  {$ELSE}
  CLEANABLE_EXTENSIONS: array[0..6] of string = (
    '.o',        // Object files
    '.ppu',      // Compiled Pascal units
    '.a',        // Static libraries
    '.so',       // Shared libraries (Linux)
    '.dylib',    // Dynamic libraries (macOS)
    '.compiled', // Lazarus state files
    '.res'       // Resource files
  );
  {$ENDIF}

var
  SourceDir: string;
  DeletedCount: Integer;

  function CleanDirectory(const ADir: string): Integer;
  var
    SR: TSearchRec;
    FilePath, FileExt: string;
    I: Integer;
    ShouldDelete: Boolean;
  begin
    Result := 0;

    if not DirectoryExists(ADir) then
      Exit;

    // 扫描目录中的所有文件和子目录
    if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        // 跳过特殊目录
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;

        FilePath := ADir + PathDelim + SR.Name;

        // 递归处理子目录
        if (SR.Attr and faDirectory) <> 0 then
        begin
          Result := Result + CleanDirectory(FilePath);
          Continue;
        end;

        // 检查文件扩展名是否应该被清理
        FileExt := LowerCase(ExtractFileExt(SR.Name));
        ShouldDelete := False;

        for I := 0 to High(CLEANABLE_EXTENSIONS) do
        begin
          if FileExt = CLEANABLE_EXTENSIONS[I] then
          begin
            ShouldDelete := True;
            Break;
          end;
        end;

        // 删除匹配的文件
        if ShouldDelete then
        begin
          if DeleteFile(FilePath) then
            Inc(Result);
        end;

      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  end;

begin
  Result := False;

  // 确定源码目录
  if AVersion = '' then
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-main'
  else
    SourceDir := FInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;

  // 验证源码目录存在
  if not DirectoryExists(SourceDir) then
  begin
    WriteLn('Error: FPC source directory does not exist: ', SourceDir);
    Exit;
  end;

  try
    // 清理目录
    DeletedCount := CleanDirectory(SourceDir);
    WriteLn('Cleaned ', DeletedCount, ' build artifact(s) from FPC source: ', SourceDir);
    Result := True;

  except
    on E: Exception do
    begin
      WriteLn('Error cleaning FPC sources: ', E.Message);
      Result := False;
    end;
  end;
end;

function TFPCManager.ShowVersionInfo(const AVersion: string): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;

  if not ValidateVersion(AVersion) then
  begin
  // WriteLn('错误: 不支持的FPC版本: ', AVersion);  // 调试代码已注释
    Exit;
  end;

  try
  // WriteLn('FPC版本信息: ', AVersion);  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释

    if IsVersionInstalled(AVersion) then
    begin
      InstallPath := GetVersionInstallPath(AVersion);
  // WriteLn('状态: 已安装');  // 调试代码已注释
  // WriteLn('安装路径: ', InstallPath);  // 调试代码已注释

      if FConfigManager.GetToolchain('fpc-' + AVersion, ToolchainInfo) then
      begin
        WriteLn('Install Date: ', DateTimeToStr(ToolchainInfo.InstallDate));
        WriteLn('Source URL: ', ToolchainInfo.SourceURL);
      end;
    end else
    begin
  // WriteLn('状态: 未安装');  // 调试代码已注释
    end;

    Result := True;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 显示版本信息时发生异常: ', E.Message);  // 调试代码已注释
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
  // WriteLn('错误: FPC版本 ', AVersion, ' 未安装');  // 调试代码已注释
    Exit;
  end;

  try
    InstallPath := GetVersionInstallPath(AVersion);
    {$IFDEF MSWINDOWS}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}


  // WriteLn('测试FPC ', AVersion, ' 安装...');  // 调试代码已注释

    Process := TProcess.Create(nil);
    try
      Process.Executable := FPCExe;
      Process.Parameters.Add('-i');
      Process.Options := Process.Options + [poWaitOnExit, poUsePipes];

      Process.Execute;

      Result := Process.ExitStatus = 0;
      if Result then
      begin
        // WriteLn('✓ FPC ', AVersion, ' 安装测试通过')  // 调试代码已注释
      end
      else
      begin
        // WriteLn('✗ FPC ', AVersion, ' 安装测试失败');  // 调试代码已注释
      end;

    finally
      Process.Free;
    end;

  except
    on E: Exception do
    begin
  // WriteLn('错误: 测试安装时发生异常: ', E.Message);  // 调试代码已注释
      Result := False;
    end;
  end;
end;

function TFPCManager.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
var
  Process: TProcess;
  FPCExe: string;
  InstallPath: string;
  OutputLines: TStringList;
  DetectedVer: string;
begin
  // Initialize result record
  FillChar(VerifResult, SizeOf(VerifResult), 0);
  VerifResult.Verified := False;
  VerifResult.ExecutableExists := False;
  VerifResult.DetectedVersion := '';
  VerifResult.SmokeTestPassed := False;
  VerifResult.ErrorMessage := '';

  // Get install path
  InstallPath := GetVersionInstallPath(AVersion);
  {$IFDEF MSWINDOWS}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  // Check if executable exists
  if not FileExists(FPCExe) then
  begin
    VerifResult.ErrorMessage := 'FPC executable not found: ' + FPCExe;
    Exit(False);
  end;

  VerifResult.ExecutableExists := True;

  try
    // Run fpc -iV to get version
    OutputLines := TStringList.Create;
    try
      Process := TProcess.Create(nil);
      try
        Process.Executable := FPCExe;
        Process.Parameters.Add('-iV');
        Process.Options := Process.Options + [poWaitOnExit, poUsePipes];
        Process.Execute;

        if Process.ExitStatus = 0 then
        begin
          // Read output using LoadFromStream
          OutputLines.LoadFromStream(Process.Output);
          if OutputLines.Count > 0 then
          begin
            DetectedVer := Trim(OutputLines[0]);
            VerifResult.DetectedVersion := DetectedVer;

            // Verify version matches
            if not SameText(DetectedVer, AVersion) then
            begin
              VerifResult.ErrorMessage := 'Version mismatch: expected ' + AVersion + ', detected ' + DetectedVer;
              Exit(False);
            end;
          end else begin
            VerifResult.ErrorMessage := 'No version output from fpc -iV';
            Exit(False);
          end;
        end else begin
          VerifResult.ErrorMessage := 'fpc -iV failed with exit code: ' + IntToStr(Process.ExitStatus);
          Exit(False);
        end;
      finally
        Process.Free;
      end;
    finally
      OutputLines.Free;
    end;

    // Run smoke test: compile and execute hello world
    if not RunSmokeTest(FPCExe, VerifResult) then
    begin
      VerifResult.Verified := False;
      Exit(False);
    end;

    // Verification successful
    VerifResult.Verified := True;
    Exit(True);

  except
    on E: Exception do
    begin
      VerifResult.ErrorMessage := 'Exception during verification: ' + E.Message;
      Exit(False);
    end;
  end;
end;

function TFPCManager.RunSmokeTest(const AFPCExe: string; var VerifResult: TVerificationResult): Boolean;
var
  TempDir, HelloPas, HelloExe: string;
  HelloFile: TextFile;
  CompileProcess, RunProcess: TProcess;
  OutputLines: TStringList;
  Output: string;
begin
  Result := False;
  VerifResult.SmokeTestPassed := False;

  try
    // Create temporary directory for smoke test
    TempDir := GetTempDir + 'fpdev_smoke_' + IntToStr(GetTickCount64);
    ForceDirectories(TempDir);

    HelloPas := TempDir + PathDelim + 'hello.pas';
    {$IFDEF MSWINDOWS}
    HelloExe := TempDir + PathDelim + 'hello.exe';
    {$ELSE}
    HelloExe := TempDir + PathDelim + 'hello';
    {$ENDIF}

    // Create hello.pas
    AssignFile(HelloFile, HelloPas);
    try
      Rewrite(HelloFile);
      WriteLn(HelloFile, 'program hello;');
      WriteLn(HelloFile, 'begin');
      WriteLn(HelloFile, '  WriteLn(''Hello, World!'');');
      WriteLn(HelloFile, 'end.');
      CloseFile(HelloFile);
    except
      on E: Exception do
      begin
        VerifResult.ErrorMessage := 'Failed to create hello.pas: ' + E.Message;
        Exit(False);
      end;
    end;

    // Compile hello.pas
    CompileProcess := TProcess.Create(nil);
    try
      CompileProcess.Executable := AFPCExe;
      CompileProcess.Parameters.Add('-o' + HelloExe);
      CompileProcess.Parameters.Add(HelloPas);
      CompileProcess.Options := CompileProcess.Options + [poWaitOnExit, poUsePipes];
      CompileProcess.Execute;

      if CompileProcess.ExitStatus <> 0 then
      begin
        VerifResult.ErrorMessage := 'Smoke test: Failed to compile hello.pas (exit code: ' + IntToStr(CompileProcess.ExitStatus) + ')';
        Exit(False);
      end;
    finally
      CompileProcess.Free;
    end;

    // Check if executable was created
    if not FileExists(HelloExe) then
    begin
      VerifResult.ErrorMessage := 'Smoke test: Compiled executable not found: ' + HelloExe;
      Exit(False);
    end;

    // Run hello.exe and check output
    RunProcess := TProcess.Create(nil);
    OutputLines := TStringList.Create;
    try
      {$IFDEF MSWINDOWS}
      // On Windows, check if a .bat file exists (mock environment)
      if FileExists(ChangeFileExt(HelloExe, '.bat')) then
      begin
        RunProcess.Executable := 'cmd.exe';
        RunProcess.Parameters.Add('/c');
        RunProcess.Parameters.Add(ChangeFileExt(HelloExe, '.bat'));
      end
      else
      begin
        RunProcess.Executable := HelloExe;
      end;
      {$ELSE}
      RunProcess.Executable := HelloExe;
      {$ENDIF}

      RunProcess.Options := RunProcess.Options + [poWaitOnExit, poUsePipes];
      RunProcess.Execute;

      if RunProcess.ExitStatus <> 0 then
      begin
        VerifResult.ErrorMessage := 'Smoke test: hello program failed (exit code: ' + IntToStr(RunProcess.ExitStatus) + ')';
        Exit(False);
      end;

      // Check output
      OutputLines.LoadFromStream(RunProcess.Output);
      if OutputLines.Count > 0 then
        Output := Trim(OutputLines[0])
      else
        Output := '';

      if Output <> 'Hello, World!' then
      begin
        VerifResult.ErrorMessage := 'Smoke test: Unexpected output. Expected ''Hello, World!'', got: ''' + Output + '''';
        Exit(False);
      end;

      // Smoke test passed!
      VerifResult.SmokeTestPassed := True;
      Result := True;

    finally
      RunProcess.Free;
      OutputLines.Free;

      // Cleanup temporary files
      try
        if FileExists(HelloExe) then DeleteFile(HelloExe);
        if FileExists(HelloPas) then DeleteFile(HelloPas);
        RemoveDir(TempDir);
      except
        // Ignore cleanup errors
      end;
    end;

  except
    on E: Exception do
    begin
      VerifResult.ErrorMessage := 'Smoke test exception: ' + E.Message;
      Exit(False);
    end;
  end;
end;

// 主要执行函数
procedure execute(const aParams: array of string);
  procedure PrintHelp;
  begin
  // WriteLn('FPC版本管理');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释
  // WriteLn('用法:');  // 调试代码已注释
  // WriteLn('  fpdev fpc update');  // 调试代码已注释
  // WriteLn('  fpdev fpc install <version> [--from=source] [--jobs=N]');  // 调试代码已注释
  // WriteLn('  fpdev fpc uninstall <version>');  // 调试代码已注释
  // WriteLn('  fpdev fpc list [--all]');  // 调试代码已注释
  // WriteLn('  fpdev fpc use <version>');  // 调试代码已注释
  // WriteLn('  fpdev fpc default <version>');  // 调试代码已注释
  // WriteLn('  fpdev fpc show <version>');  // 调试代码已注释
  // WriteLn('  fpdev fpc current');  // 调试代码已注释
  // WriteLn('  fpdev fpc test <version>');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释
  // WriteLn('示例:');  // 调试代码已注释
  // WriteLn('  fpdev fpc update');  // 调试代码已注释
  // WriteLn('  fpdev fpc install 3.2.2 --from=source --jobs=8');  // 调试代码已注释
  // WriteLn('  fpdev fpc use 3.2.2');  // 调试代码已注释
  end;
var
  Cmd: string;
  Cfg: TFPDevConfigManager;
  Manager: TFPCManager;
  Ok: Boolean;
  Ver, S, Jobs: string;
  FromSource: Boolean;
  Settings: TFPDevSettings;
  VerifResult: TVerificationResult;
  ActivResult: TActivationResult;
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
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc install 3.2.2');  // 调试代码已注释
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
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc uninstall 3.2.2');  // 调试代码已注释
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
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc use 3.2.2');  // 调试代码已注释
          Exit;
        end;
        Ver := aParams[1];
        // --ensure: 若未安装则自动安装（从源码）
        if HasFlag(aParams, 'ensure') then
        begin
          if not Manager.IsVersionInstalled(Ver) then
          begin
  // WriteLn('未安装版本 ', Ver, '，自动安装 (--ensure) ...');  // 调试代码已注释
            if not Manager.InstallVersion(Ver, True {from source}, '' {prefix}, True {ensure}) then
            begin
  // WriteLn('错误: 自动安装失败，无法切换');  // 调试代码已注释
              Exit;
            end;
          end;
        end;

        // Use new activation system
        ActivResult := Manager.ActivateVersion(Ver);
        if ActivResult.Success then
        begin
          WriteLn('FPC ', Ver, ' activated successfully');
          WriteLn('');
          WriteLn('Activation script created: ', ActivResult.ActivationScript);
          if ActivResult.VSCodeSettings <> '' then
            WriteLn('VS Code settings updated: ', ActivResult.VSCodeSettings);
          WriteLn('');
          WriteLn('To activate in your current shell, run:');
          WriteLn('  ', ActivResult.ShellCommand);
          if Cfg.Modified then Cfg.SaveConfig;
        end
        else
        begin
          WriteLn('Error: Failed to activate FPC ', Ver);
          WriteLn('  ', ActivResult.ErrorMessage);
        end;
      end
      else if (Cmd = 'current') then
      begin
        Ver := Manager.GetCurrentVersion;
        if Ver <> '' then
  // WriteLn('当前FPC版本: ', Ver)  // 调试代码已注释
        else
  // WriteLn('未设置默认FPC版本');  // 调试代码已注释
      end
      else if (Cmd = 'show') then
      begin
        if Length(aParams) < 2 then
        begin
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc show 3.2.2');  // 调试代码已注释
          Exit;
        end;
        Ver := aParams[1];
        Manager.ShowVersionInfo(Ver);
      end
      else if (Cmd = 'test') then
      begin
        if Length(aParams) < 2 then
        begin
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc test 3.2.2');  // 调试代码已注释
          Exit;
        end;
        Ver := aParams[1];
        Manager.TestInstallation(Ver);
      end
      else if (Cmd = 'verify') then
      begin
        if Length(aParams) < 2 then
        begin
          WriteLn('Error: Version number required. Example: fpdev fpc verify 3.2.2');
          Exit;
        end;
        Ver := aParams[1];

        WriteLn('Verifying FPC ', Ver, ' installation...');
        WriteLn;

        if Manager.VerifyInstallation(Ver, VerifResult) then
        begin
          WriteLn('Verification passed:');
          WriteLn('  Executable: Found');
          WriteLn('  Version: ', VerifResult.DetectedVersion);
          WriteLn('  Status: OK');
        end
        else
        begin
          WriteLn('Verification failed:');
          WriteLn('  Executable exists: ', VerifResult.ExecutableExists);
          if VerifResult.DetectedVersion <> '' then
            WriteLn('  Detected version: ', VerifResult.DetectedVersion);
          WriteLn('  Error: ', VerifResult.ErrorMessage);
        end;
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
