unit fpdev.config.project;

{
  Project-level configuration file parser

  Supports .fpdevrc and fpdev.toml formats
  Implements configuration priority: environment variables > command line > project config > global defaults

  Reference: docs/FPDEVRC_SPEC.md
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  { Configuration source }
  TConfigSource = (
    csDefault,      // System default values
    csGlobal,       // Global config (~/.fpdev/config.json)
    csProject,      // Project config (.fpdevrc / fpdev.toml)
    csCommandLine,  // Command line arguments
    csEnvironment   // Environment variables
  );

  { Project configuration record }
  TProjectConfig = record
    // Toolchain version
    FPCVersion: string;
    LazarusVersion: string;
    Channel: string;           // stable, lts, trunk

    // Cross-compilation target
    CrossTargets: TStringArray;

    // Settings
    Mirror: string;
    AutoInstall: Boolean;

    // Metadata
    ConfigFile: string;        // Configuration file path
    Source: TConfigSource;     // Configuration source
  end;

  { Parsed effective configuration }
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

  { IProjectConfigResolver - Project configuration resolver interface }
  IProjectConfigResolver = interface
    ['{A1B2C3D4-5678-90AB-CDEF-123456789ABC}']
    // Find project configuration file
    function FindProjectConfig(const AStartDir: string = ''): string;

    // Parse project configuration
    function ParseProjectConfig(const AConfigFile: string): TProjectConfig;

    // Parse simple format (version number only)
    function ParseSimpleFormat(const AContent: string): TProjectConfig;

    // Parse TOML format
    function ParseTOMLFormat(const AContent: string): TProjectConfig;

    // Parse version alias
    function ResolveVersionAlias(const AAlias: string): string;

    // Get fully resolved config (merged from all sources)
    function ResolveConfig(const AStartDir: string = ''): TResolvedConfig;

    // Check if project config exists
    function HasProjectConfig(const AStartDir: string = ''): Boolean;
  end;

  { TProjectConfigResolver - Project configuration resolver implementation }
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

    // Properties
    property MaxSearchDepth: Integer read FMaxSearchDepth write FMaxSearchDepth;
  end;

{ Helper functions }
function ConfigSourceToString(ASource: TConfigSource): string;
function GetDefaultFPCVersion: string;
function GetDefaultLazarusVersion: string;

implementation

uses
  fpdev.constants, fpdev.utils;

const
  PROJECT_CONFIG_FILES: array[0..1] of string = ('.fpdevrc', 'fpdev.toml');
  MAX_PARENT_SEARCH = 10;

  // Version alias mapping
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
    // Check each possible configuration file name
    for I := Low(PROJECT_CONFIG_FILES) to High(PROJECT_CONFIG_FILES) do
    begin
      LFile := IncludeTrailingPathDelimiter(LDir) + PROJECT_CONFIG_FILES[I];
      if FileExists(LFile) then
      begin
        Result := LFile;
        Exit;
      end;
    end;

    // Go up one directory level
    LDir := ExtractFileDir(ExcludeTrailingPathDelimiter(LDir));
    Inc(LDepth);

    // Reached root directory
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
  // Simple format: contains only version number (e.g. "3.2.2" or "stable")
  // Does not contain '[' (TOML section) or '=' (TOML key-value)
  Result := (Pos('[', LTrimmed) = 0) and (Pos('=', LTrimmed) = 0);
end;

function TProjectConfigResolver.ParseProjectConfig(const AConfigFile: string): TProjectConfig;
var
  LContent: string;
  LLines: TStringList;
begin
  // Initialize default values
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
  // Initialize
  Result.FPCVersion := '';
  Result.LazarusVersion := '';
  Result.Channel := '';
  SetLength(Result.CrossTargets, 0);
  Result.Mirror := 'auto';
  Result.AutoInstall := False;
  Result.ConfigFile := '';
  Result.Source := csProject;

  LVersion := Trim(AContent);

  // Remove possible comments
  if Pos('#', LVersion) > 0 then
    LVersion := Trim(Copy(LVersion, 1, Pos('#', LVersion) - 1));

  if LVersion = '' then
    Exit;

  // Check if it's an alias
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

  // Remove quotes
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
  Result := nil;
  SetLength(Result, 0);

  LValue := Trim(AValue);

  // Remove square brackets
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
      // Remove quotes
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
  // Initialize
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

      // Skip empty lines and comments
      if (LLine = '') or (LLine[1] = '#') then
        Continue;

      // Check section
      if (Length(LLine) >= 2) and (LLine[1] = '[') and (LLine[Length(LLine)] = ']') then
      begin
        LSection := LowerCase(Copy(LLine, 2, Length(LLine) - 2));
        Continue;
      end;

      // Parse key = value
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
    Result := AAlias;  // Not an alias, return original value
  end;
end;

function TProjectConfigResolver.GetEnvFPCVersion: string;
begin
  Result := get_env('FPDEV_FPC_VERSION');
end;

function TProjectConfigResolver.GetEnvLazarusVersion: string;
begin
  Result := get_env('FPDEV_LAZARUS_VERSION');
end;

function TProjectConfigResolver.ResolveConfig(const AStartDir: string): TResolvedConfig;
var
  LProjectConfigFile: string;
  LProjectConfig: TProjectConfig;
  LEnvFPC, LEnvLazarus: string;
begin
  // Initialize to default values
  Result.FPCVersion := DEFAULT_FPC_VERSION;
  Result.FPCSource := csDefault;
  Result.FPCSourceFile := '';

  Result.LazarusVersion := DEFAULT_LAZARUS_VERSION;
  Result.LazarusSource := csDefault;
  Result.LazarusSourceFile := '';

  SetLength(Result.CrossTargets, 0);
  Result.Mirror := 'auto';
  Result.AutoInstall := False;

  // 1. Apply global defaults (if any)
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

  // 2. Apply project config (if any)
  LProjectConfigFile := FindProjectConfig(AStartDir);
  if LProjectConfigFile <> '' then
  begin
    LProjectConfig := ParseProjectConfig(LProjectConfigFile);

    // Handle channel alias
    if LProjectConfig.Channel <> '' then
    begin
      Result.FPCVersion := ResolveVersionAlias(LProjectConfig.Channel);
      Result.FPCSource := csProject;
      Result.FPCSourceFile := LProjectConfigFile;
    end;

    // Specific version overrides channel
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

    // Other settings
    if Length(LProjectConfig.CrossTargets) > 0 then
      Result.CrossTargets := LProjectConfig.CrossTargets;

    if LProjectConfig.Mirror <> '' then
      Result.Mirror := LProjectConfig.Mirror;

    Result.AutoInstall := LProjectConfig.AutoInstall;
  end;

  // 3. Apply environment variables (highest priority)
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
