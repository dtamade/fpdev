unit fpdev.paths;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GetDataRoot: string;
function GetCacheDir: string;
function GetSandboxDir: string;
function GetLogsDir: string;
function GetLocksDir: string;
function GetTempRootDir: string;

implementation

function EnsureDir(const P: string): string;
begin
  if (P<>'') and (not DirectoryExists(P)) then
    ForceDirectories(P);
  Result := P;
end;

function GetDataRoot: string;
var
  R, Home, AppData: string;
begin
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
      Result := '.fpdev';
  end;
  {$ELSE}
  Home := GetEnvironmentVariable('XDG_DATA_HOME');
  if Home<>'' then
    Result := IncludeTrailingPathDelimiter(Home)+'fpdev'
  else
  begin
    Home := GetEnvironmentVariable('HOME');
    if Home<>'' then
      Result := IncludeTrailingPathDelimiter(Home)+'.fpdev'
    else
      Result := '.fpdev';
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

end.

