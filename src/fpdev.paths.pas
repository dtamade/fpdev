unit fpdev.paths;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.constants;

// 便携模式控制
function IsPortableMode: Boolean;
function GetProgramDir: string;
procedure SetPortableMode(AEnabled: Boolean);

// 路径获取
function GetDataRoot: string;
function GetCacheDir: string;
function GetSandboxDir: string;
function GetLogsDir: string;
function GetLocksDir: string;
function GetTempRootDir: string;
function GetConfigPath: string;
function GetToolchainsDir: string;

implementation

var
  GPortableMode: Boolean = False;
  GPortableModeChecked: Boolean = False;

function EnsureDir(const P: string): string;
begin
  if (P<>'') and (not DirectoryExists(P)) then
    ForceDirectories(P);
  Result := P;
end;

function GetProgramDir: string;
begin
  Result := ExtractFileDir(ParamStr(0));
  if Result = '' then
    Result := GetCurrentDir;
  Result := IncludeTrailingPathDelimiter(Result);
end;

function IsPortableMode: Boolean;
var
  PortableMarker: string;
begin
  // 已经检查过，直接返回缓存结果
  if GPortableModeChecked then
    Exit(GPortableMode);

  GPortableModeChecked := True;

  // 1. 环境变量优先
  if GetEnvironmentVariable('FPDEV_PORTABLE') = '1' then
  begin
    GPortableMode := True;
    Exit(True);
  end;

  // 2. 检查程序目录下是否有 .portable 标记文件
  PortableMarker := GetProgramDir + '.portable';
  if FileExists(PortableMarker) then
  begin
    GPortableMode := True;
    Exit(True);
  end;

  // 3. 检查程序目录下是否有 data 目录（已有便携安装）
  if DirectoryExists(GetProgramDir + 'data') then
  begin
    GPortableMode := True;
    Exit(True);
  end;

  GPortableMode := False;
  Result := False;
end;

procedure SetPortableMode(AEnabled: Boolean);
begin
  GPortableMode := AEnabled;
  GPortableModeChecked := True;
end;

function GetDataRoot: string;
var
  R, Home: string;
  {$IFDEF MSWINDOWS}
  AppData: string;
  {$ENDIF}
begin
  // 便携模式：使用程序目录下的 data 子目录
  if IsPortableMode then
    Exit(EnsureDir(GetProgramDir + 'data'));

  // 优先环境变量覆盖
  R := GetEnvironmentVariable('FPDEV_DATA_ROOT');
  if R<>'' then Exit(R);

  {$IFDEF MSWINDOWS}
  AppData := GetEnvironmentVariable('APPDATA');
  if AppData<>'' then
    Result := IncludeTrailingPathDelimiter(AppData)+'fpdev'
  else
  begin
    Home := GetEnvironmentVariable('USERPROFILE');
    if Home<>'' then
      Result := IncludeTrailingPathDelimiter(Home)+'AppData'+PathDelim+'Roaming'+PathDelim+'fpdev'
    else
      Result := FPDEV_CONFIG_DIR;
  end;
  {$ELSE}
  Home := GetEnvironmentVariable('XDG_DATA_HOME');
  if Home<>'' then
    Result := IncludeTrailingPathDelimiter(Home)+'fpdev'
  else
  begin
    Home := GetEnvironmentVariable('HOME');
    if Home<>'' then
      Result := IncludeTrailingPathDelimiter(Home)+FPDEV_CONFIG_DIR
    else
      Result := FPDEV_CONFIG_DIR;
  end;
  {$ENDIF}
end;

function GetCacheDir: string;
begin
  Result := EnsureDir(IncludeTrailingPathDelimiter(GetDataRoot)+'cache');
end;

function GetSandboxDir: string;
begin
  Result := EnsureDir(IncludeTrailingPathDelimiter(GetDataRoot)+'sandbox');
end;

function GetLogsDir: string;
begin
  Result := EnsureDir(IncludeTrailingPathDelimiter(GetDataRoot)+'logs');
end;

function GetLocksDir: string;
begin
  Result := EnsureDir(IncludeTrailingPathDelimiter(GetDataRoot)+'locks');
end;

function GetTempRootDir: string;
begin
  Result := EnsureDir(IncludeTrailingPathDelimiter(GetDataRoot)+'tmp');
end;

function GetConfigPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataRoot) + 'config.json';
end;

function GetToolchainsDir: string;
begin
  Result := EnsureDir(IncludeTrailingPathDelimiter(GetDataRoot) + 'toolchains');
end;

end.

