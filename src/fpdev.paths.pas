unit fpdev.paths;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.constants, fpdev.utils;

// Portable mode control
function IsPortableMode: Boolean;
function GetProgramDir: string;
procedure SetPortableMode(AEnabled: Boolean);

// Path retrieval
function GetDataRoot: string;
function GetCacheDir: string;
function GetSandboxDir: string;
function GetLogsDir: string;
function GetLocksDir: string;
function GetTempRootDir: string;
function GetConfigPath: string;
function GetToolchainsDir: string;

// Install-root derived paths (preferred when Settings.InstallRoot is available)
function BuildToolchainsDirFromInstallRoot(const AInstallRoot: string): string;
function BuildBuildCacheDirFromInstallRoot(const AInstallRoot: string): string;
function BuildFPCInstallDirFromInstallRoot(const AInstallRoot, AVersion: string): string;
function BuildBootstrapCompilerRootDirFromInstallRoot(const AInstallRoot, AVersion: string): string;
function BuildBootstrapCompilerExecutablePathFromInstallRoot(const AInstallRoot, AVersion: string): string;

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
  // Already checked, return cached result directly
  if GPortableModeChecked then
    Exit(GPortableMode);

  GPortableModeChecked := True;

  // 1. Environment variable takes priority
  if GetEnvironmentVariable('FPDEV_PORTABLE') = '1' then
  begin
    GPortableMode := True;
    Exit(True);
  end;

  // 2. Check if .portable marker file exists in program directory
  PortableMarker := GetProgramDir + '.portable';
  if FileExists(PortableMarker) then
  begin
    GPortableMode := True;
    Exit(True);
  end;

  // 3. Check if data directory exists in program directory (existing portable installation)
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
  // Environment variable override takes priority, even over portable auto-detection.
  R := get_env('FPDEV_DATA_ROOT');
  if R <> '' then
    Exit(R);

  // Portable mode: use data subdirectory under program directory
  if IsPortableMode then
    Exit(EnsureDir(GetProgramDir + 'data'));

  {$IFDEF MSWINDOWS}
  AppData := get_env('APPDATA');
  if AppData<>'' then
    Result := IncludeTrailingPathDelimiter(AppData)+'fpdev'
  else
  begin
    Home := get_env('USERPROFILE');
    if Home<>'' then
      Result := IncludeTrailingPathDelimiter(Home)+'AppData'+PathDelim+'Roaming'+PathDelim+'fpdev'
    else
      Result := FPDEV_CONFIG_DIR;
  end;
  {$ELSE}
  Home := get_env('XDG_DATA_HOME');
  if Home<>'' then
    Result := IncludeTrailingPathDelimiter(Home)+'fpdev'
  else
  begin
    Home := get_env('HOME');
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

function NormalizeInstallRootCore(const AInstallRoot: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(Trim(AInstallRoot));
end;

function BuildToolchainsDirFromInstallRoot(const AInstallRoot: string): string;
var
  Root: string;
begin
  Root := NormalizeInstallRootCore(AInstallRoot);
  if Root = '' then
    Exit(GetToolchainsDir);
  Result := EnsureDir(Root + PathDelim + 'toolchains');
end;

function BuildBuildCacheDirFromInstallRoot(const AInstallRoot: string): string;
var
  Root: string;
begin
  Root := NormalizeInstallRootCore(AInstallRoot);
  if Root = '' then
    Result := EnsureDir(GetCacheDir + PathDelim + 'builds')
  else
    Result := EnsureDir(Root + PathDelim + 'cache' + PathDelim + 'builds');
end;

function BuildFPCInstallDirFromInstallRoot(const AInstallRoot, AVersion: string): string;
begin
  Result := BuildToolchainsDirFromInstallRoot(AInstallRoot) + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function BuildBootstrapCompilerRootDirFromInstallRoot(const AInstallRoot, AVersion: string): string;
var
  Root: string;
begin
  Root := NormalizeInstallRootCore(AInstallRoot);
  if Root = '' then
    Root := NormalizeInstallRootCore(GetDataRoot);
  Result := EnsureDir(Root + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion);
end;

function BuildBootstrapCompilerExecutablePathFromInstallRoot(const AInstallRoot, AVersion: string): string;
begin
  Result := BuildBootstrapCompilerRootDirFromInstallRoot(AInstallRoot, AVersion) +
    PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

end.
