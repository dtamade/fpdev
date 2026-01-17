unit fpdev.config.project;

{
  项目级配置文件解析器

  支持 .fpdevrc 和 fpdev.toml 格式
  实现配置优先级: 环境变量 > 命令行 > 项目配置 > 全局默认

  参考: docs/FPDEVRC_SPEC.md
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  { 配置来源 }
  TConfigSource = (
    csDefault,      // 系统默认值
    csGlobal,       // 全局配置 (~/.fpdev/config.json)
    csProject,      // 项目配置 (.fpdevrc / fpdev.toml)
    csCommandLine,  // 命令行参数
    csEnvironment   // 环境变量
  );

  { 项目配置记录 }
  TProjectConfig = record
    // 工具链版本
    FPCVersion: string;
    LazarusVersion: string;
    Channel: string;           // stable, lts, trunk

    // 交叉编译目标
    CrossTargets: TStringArray;

    // 设置
    Mirror: string;
    AutoInstall: Boolean;

    // 元数据
    ConfigFile: string;        // 配置文件路径
    Source: TConfigSource;     // 配置来源
  end;

  { 解析后的有效配置 }
  TResolvedConfig = record
    FPCVersion: string;
    FPCSource: TConfigSource;
    FPCSourceFile: string;

    LazarusVersion: string;
    LazarusSource: TConfigSource;
    LazarusSourceFile: string;

    CrossTargets: TStringArray;
    Mirror: string;
    AutoInstall: Boolean;
  end;

  { IProjectConfigResolver - 项目配置解析器接口 }
  IProjectConfigResolver = interface
    ['{A1B2C3D4-5678-90AB-CDEF-123456789ABC}']
    // 查找项目配置文件
    function FindProjectConfig(const AStartDir: string = ''): string;

    // 解析项目配置
    function ParseProjectConfig(const AConfigFile: string): TProjectConfig;

    // 解析简单格式 (仅版本号)
    function ParseSimpleFormat(const AContent: string): TProjectConfig;

    // 解析 TOML 格式
    function ParseTOMLFormat(const AContent: string): TProjectConfig;

    // 解析版本别名
    function ResolveVersionAlias(const AAlias: string): string;

    // 获取完整解析后的配置 (合并所有来源)
    function ResolveConfig(const AStartDir: string = ''): TResolvedConfig;

    // 检查是否有项目配置
    function HasProjectConfig(const AStartDir: string = ''): Boolean;
  end;

  { TProjectConfigResolver - 项目配置解析器实现 }
  TProjectConfigResolver = class(TInterfacedObject, IProjectConfigResolver)
  private
    FGlobalFPCDefault: string;
    FGlobalLazarusDefault: string;
    FMaxSearchDepth: Integer;

    function IsSimpleFormat(const AContent: string): Boolean;
    function ParseTOMLValue(const ALine: string; out AKey, AValue: string): Boolean;
    function ParseTOMLArray(const AValue: string): TStringArray;
    function GetEnvFPCVersion: string;
    function GetEnvLazarusVersion: string;
  public
    constructor Create;
    constructor Create(const AGlobalFPCDefault, AGlobalLazarusDefault: string);

    // IProjectConfigResolver
    function FindProjectConfig(const AStartDir: string = ''): string;
    function ParseProjectConfig(const AConfigFile: string): TProjectConfig;
    function ParseSimpleFormat(const AContent: string): TProjectConfig;
    function ParseTOMLFormat(const AContent: string): TProjectConfig;
    function ResolveVersionAlias(const AAlias: string): string;
    function ResolveConfig(const AStartDir: string = ''): TResolvedConfig;
    function HasProjectConfig(const AStartDir: string = ''): Boolean;

    // 属性
    property MaxSearchDepth: Integer read FMaxSearchDepth write FMaxSearchDepth;
  end;

{ 辅助函数 }
function ConfigSourceToString(ASource: TConfigSource): string;
function GetDefaultFPCVersion: string;
function GetDefaultLazarusVersion: string;

implementation

uses
  fpdev.constants;

const
  PROJECT_CONFIG_FILES: array[0..1] of string = ('.fpdevrc', 'fpdev.toml');
  MAX_PARENT_SEARCH = 10;

  // 版本别名映射
  ALIAS_STABLE = 'stable';
  ALIAS_LTS = 'lts';
  ALIAS_TRUNK = 'trunk';
  ALIAS_LATEST = 'latest';

function ConfigSourceToString(ASource: TConfigSource): string;
begin
  case ASource of
    csDefault: Result := 'default';
    csGlobal: Result := 'global config';
    csProject: Result := 'project config';
    csCommandLine: Result := 'command line';
    csEnvironment: Result := 'environment variable';
  else
    Result := 'unknown';
  end;
end;

function GetDefaultFPCVersion: string;
begin
  Result := DEFAULT_FPC_VERSION;
end;

function GetDefaultLazarusVersion: string;
begin
  Result := DEFAULT_LAZARUS_VERSION;
end;

{ TProjectConfigResolver }

constructor TProjectConfigResolver.Create;
begin
  inherited Create;
  FGlobalFPCDefault := '';
  FGlobalLazarusDefault := '';
  FMaxSearchDepth := MAX_PARENT_SEARCH;
end;

constructor TProjectConfigResolver.Create(const AGlobalFPCDefault, AGlobalLazarusDefault: string);
begin
  inherited Create;
  FGlobalFPCDefault := AGlobalFPCDefault;
  FGlobalLazarusDefault := AGlobalLazarusDefault;
  FMaxSearchDepth := MAX_PARENT_SEARCH;
end;

function TProjectConfigResolver.FindProjectConfig(const AStartDir: string): string;
var
  LDir, LFile: string;
  LDepth: Integer;
  I: Integer;
begin
  Result := '';

  if AStartDir = '' then
    LDir := GetCurrentDir
  else
    LDir := AStartDir;

  LDir := ExpandFileName(LDir);
  LDepth := 0;

  while (LDir <> '') and (LDepth < FMaxSearchDepth) do
  begin
    // 检查每个可能的配置文件名
    for I := Low(PROJECT_CONFIG_FILES) to High(PROJECT_CONFIG_FILES) do
    begin
      LFile := IncludeTrailingPathDelimiter(LDir) + PROJECT_CONFIG_FILES[I];
      if FileExists(LFile) then
      begin
        Result := LFile;
        Exit;
      end;
    end;

    // 向上一级目录
    LDir := ExtractFileDir(ExcludeTrailingPathDelimiter(LDir));
    Inc(LDepth);

    // 到达根目录
    if (LDir = '') or (LDir = PathDelim) then
      Break;
  end;
end;

function TProjectConfigResolver.HasProjectConfig(const AStartDir: string): Boolean;
begin
  Result := FindProjectConfig(AStartDir) <> '';
end;

function TProjectConfigResolver.IsSimpleFormat(const AContent: string): Boolean;
var
  LTrimmed: string;
begin
  LTrimmed := Trim(AContent);
  // 简单格式: 仅包含版本号 (如 "3.2.2" 或 "stable")
  // 不包含 '[' (TOML section) 或 '=' (TOML key-value)
  Result := (Pos('[', LTrimmed) = 0) and (Pos('=', LTrimmed) = 0);
end;

function TProjectConfigResolver.ParseProjectConfig(const AConfigFile: string): TProjectConfig;
var
  LContent: string;
  LLines: TStringList;
begin
  // 初始化默认值
  Result.FPCVersion := '';
  Result.LazarusVersion := '';
  Result.Channel := '';
  SetLength(Result.CrossTargets, 0);
  Result.Mirror := 'auto';
  Result.AutoInstall := False;
  Result.ConfigFile := AConfigFile;
  Result.Source := csProject;

  if not FileExists(AConfigFile) then
    Exit;

  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AConfigFile);
    LContent := LLines.Text;

    if IsSimpleFormat(LContent) then
      Result := ParseSimpleFormat(LContent)
    else
      Result := ParseTOMLFormat(LContent);

    Result.ConfigFile := AConfigFile;
    Result.Source := csProject;
  finally
    LLines.Free;
  end;
end;

function TProjectConfigResolver.ParseSimpleFormat(const AContent: string): TProjectConfig;
var
  LVersion: string;
begin
  // 初始化
  Result.FPCVersion := '';
  Result.LazarusVersion := '';
  Result.Channel := '';
  SetLength(Result.CrossTargets, 0);
  Result.Mirror := 'auto';
  Result.AutoInstall := False;
  Result.ConfigFile := '';
  Result.Source := csProject;

  LVersion := Trim(AContent);

  // 移除可能的注释
  if Pos('#', LVersion) > 0 then
    LVersion := Trim(Copy(LVersion, 1, Pos('#', LVersion) - 1));

  if LVersion = '' then
    Exit;

  // 检查是否是别名
  if (LVersion = ALIAS_STABLE) or (LVersion = ALIAS_LTS) or
     (LVersion = ALIAS_TRUNK) or (LVersion = ALIAS_LATEST) then
    Result.Channel := LVersion
  else
    Result.FPCVersion := LVersion;
end;

function TProjectConfigResolver.ParseTOMLValue(const ALine: string; out AKey, AValue: string): Boolean;
var
  LEqPos: Integer;
begin
  Result := False;
  AKey := '';
  AValue := '';

  LEqPos := Pos('=', ALine);
  if LEqPos = 0 then
    Exit;

  AKey := Trim(Copy(ALine, 1, LEqPos - 1));
  AValue := Trim(Copy(ALine, LEqPos + 1, Length(ALine)));

  // 移除引号
  if (Length(AValue) >= 2) and (AValue[1] = '"') and (AValue[Length(AValue)] = '"') then
    AValue := Copy(AValue, 2, Length(AValue) - 2);

  Result := True;
end;

function TProjectConfigResolver.ParseTOMLArray(const AValue: string): TStringArray;
var
  LValue, LItem: string;
  LItems: TStringList;
  I: Integer;
begin
  SetLength(Result, 0);

  LValue := Trim(AValue);

  // 移除方括号
  if (Length(LValue) >= 2) and (LValue[1] = '[') and (LValue[Length(LValue)] = ']') then
    LValue := Copy(LValue, 2, Length(LValue) - 2);

  LItems := TStringList.Create;
  try
    LItems.Delimiter := ',';
    LItems.StrictDelimiter := True;
    LItems.DelimitedText := LValue;

    SetLength(Result, LItems.Count);
    for I := 0 to LItems.Count - 1 do
    begin
      LItem := Trim(LItems[I]);
      // 移除引号
      if (Length(LItem) >= 2) and (LItem[1] = '"') and (LItem[Length(LItem)] = '"') then
        LItem := Copy(LItem, 2, Length(LItem) - 2);
      Result[I] := LItem;
    end;
  finally
    LItems.Free;
  end;
end;

function TProjectConfigResolver.ParseTOMLFormat(const AContent: string): TProjectConfig;
var
  LLines: TStringList;
  LLine, LSection, LKey, LValue: string;
  I: Integer;
begin
  // 初始化
  Result.FPCVersion := '';
  Result.LazarusVersion := '';
  Result.Channel := '';
  SetLength(Result.CrossTargets, 0);
  Result.Mirror := 'auto';
  Result.AutoInstall := False;
  Result.ConfigFile := '';
  Result.Source := csProject;

  LLines := TStringList.Create;
  try
    LLines.Text := AContent;
    LSection := '';

    for I := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[I]);

      // 跳过空行和注释
      if (LLine = '') or (LLine[1] = '#') then
        Continue;

      // 检查 section
      if (Length(LLine) >= 2) and (LLine[1] = '[') and (LLine[Length(LLine)] = ']') then
      begin
        LSection := LowerCase(Copy(LLine, 2, Length(LLine) - 2));
        Continue;
      end;

      // 解析 key = value
      if ParseTOMLValue(LLine, LKey, LValue) then
      begin
        LKey := LowerCase(LKey);

        if LSection = 'toolchain' then
        begin
          if LKey = 'fpc' then
            Result.FPCVersion := LValue
          else if LKey = 'lazarus' then
            Result.LazarusVersion := LValue
          else if LKey = 'channel' then
            Result.Channel := LValue;
        end
        else if LSection = 'cross' then
        begin
          if LKey = 'targets' then
            Result.CrossTargets := ParseTOMLArray(LValue);
        end
        else if LSection = 'settings' then
        begin
          if LKey = 'mirror' then
            Result.Mirror := LValue
          else if LKey = 'auto_install' then
            Result.AutoInstall := LowerCase(LValue) = 'true';
        end;
      end;
    end;
  finally
    LLines.Free;
  end;
end;

function TProjectConfigResolver.ResolveVersionAlias(const AAlias: string): string;
begin
  case LowerCase(AAlias) of
    ALIAS_STABLE, ALIAS_LATEST:
      Result := DEFAULT_FPC_VERSION;
    ALIAS_LTS:
      Result := FALLBACK_FPC_VERSION;
    ALIAS_TRUNK:
      Result := 'main';
  else
    Result := AAlias;  // 不是别名，返回原值
  end;
end;

function TProjectConfigResolver.GetEnvFPCVersion: string;
begin
  Result := GetEnvironmentVariable('FPDEV_FPC_VERSION');
end;

function TProjectConfigResolver.GetEnvLazarusVersion: string;
begin
  Result := GetEnvironmentVariable('FPDEV_LAZARUS_VERSION');
end;

function TProjectConfigResolver.ResolveConfig(const AStartDir: string): TResolvedConfig;
var
  LProjectConfigFile: string;
  LProjectConfig: TProjectConfig;
  LEnvFPC, LEnvLazarus: string;
begin
  // 初始化为默认值
  Result.FPCVersion := DEFAULT_FPC_VERSION;
  Result.FPCSource := csDefault;
  Result.FPCSourceFile := '';

  Result.LazarusVersion := DEFAULT_LAZARUS_VERSION;
  Result.LazarusSource := csDefault;
  Result.LazarusSourceFile := '';

  SetLength(Result.CrossTargets, 0);
  Result.Mirror := 'auto';
  Result.AutoInstall := False;

  // 1. 应用全局默认 (如果有)
  if FGlobalFPCDefault <> '' then
  begin
    Result.FPCVersion := FGlobalFPCDefault;
    Result.FPCSource := csGlobal;
  end;

  if FGlobalLazarusDefault <> '' then
  begin
    Result.LazarusVersion := FGlobalLazarusDefault;
    Result.LazarusSource := csGlobal;
  end;

  // 2. 应用项目配置 (如果有)
  LProjectConfigFile := FindProjectConfig(AStartDir);
  if LProjectConfigFile <> '' then
  begin
    LProjectConfig := ParseProjectConfig(LProjectConfigFile);

    // 处理 channel 别名
    if LProjectConfig.Channel <> '' then
    begin
      Result.FPCVersion := ResolveVersionAlias(LProjectConfig.Channel);
      Result.FPCSource := csProject;
      Result.FPCSourceFile := LProjectConfigFile;
    end;

    // 具体版本覆盖 channel
    if LProjectConfig.FPCVersion <> '' then
    begin
      Result.FPCVersion := ResolveVersionAlias(LProjectConfig.FPCVersion);
      Result.FPCSource := csProject;
      Result.FPCSourceFile := LProjectConfigFile;
    end;

    if LProjectConfig.LazarusVersion <> '' then
    begin
      Result.LazarusVersion := ResolveVersionAlias(LProjectConfig.LazarusVersion);
      Result.LazarusSource := csProject;
      Result.LazarusSourceFile := LProjectConfigFile;
    end;

    // 其他设置
    if Length(LProjectConfig.CrossTargets) > 0 then
      Result.CrossTargets := LProjectConfig.CrossTargets;

    if LProjectConfig.Mirror <> '' then
      Result.Mirror := LProjectConfig.Mirror;

    Result.AutoInstall := LProjectConfig.AutoInstall;
  end;

  // 3. 应用环境变量 (最高优先级)
  LEnvFPC := GetEnvFPCVersion;
  if LEnvFPC <> '' then
  begin
    Result.FPCVersion := ResolveVersionAlias(LEnvFPC);
    Result.FPCSource := csEnvironment;
    Result.FPCSourceFile := 'FPDEV_FPC_VERSION';
  end;

  LEnvLazarus := GetEnvLazarusVersion;
  if LEnvLazarus <> '' then
  begin
    Result.LazarusVersion := ResolveVersionAlias(LEnvLazarus);
    Result.LazarusSource := csEnvironment;
    Result.LazarusSourceFile := 'FPDEV_LAZARUS_VERSION';
  end;
end;

end.
