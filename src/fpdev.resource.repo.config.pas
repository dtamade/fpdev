unit fpdev.resource.repo.config;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.resource.repo.types;

function ResourceRepoGetCurrentPlatform: string;
function ResourceRepoCreateDefaultConfig: TResourceRepoConfig;
function ResourceRepoCreateConfigWithMirror(const AMirror: string; const ACustomURL: string = ''): TResourceRepoConfig;

implementation

uses
  fpdev.constants,
  fpdev.paths;

function ResourceRepoGetCurrentPlatform: string;
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

function ResourceRepoCreateDefaultConfig: TResourceRepoConfig;
begin
  GetDataRoot;
  Result.URL := FPDEV_REPO_URL;
  SetLength(Result.Mirrors, 1);
  Result.Mirrors[0] := FPDEV_REPO_MIRROR;

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

function ResourceRepoCreateConfigWithMirror(const AMirror: string; const ACustomURL: string): TResourceRepoConfig;
begin
  Result := ResourceRepoCreateDefaultConfig;

  if ACustomURL <> '' then
  begin
    Result.URL := ACustomURL;
    SetLength(Result.Mirrors, 0);
    Exit;
  end;

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
    Result.URL := FPDEV_REPO_GITHUB;
    SetLength(Result.Mirrors, 1);
    Result.Mirrors[0] := FPDEV_REPO_GITEE;
  end
  else
  begin
    Result.URL := AMirror;
    SetLength(Result.Mirrors, 0);
  end;
end;

end.
