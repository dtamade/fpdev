unit fpdev.fpc.version;

{
================================================================================
  fpdev.fpc.version - FPC Version Management Service
================================================================================

  Provides FPC version listing and status checking capabilities:
  - List available FPC versions (from release database)
  - List installed FPC versions
  - Check installation status
  - Version validation
  - Installation path resolution

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    VersionMgr := TFPCVersionManager.Create(ConfigManager);
    try
      Versions := VersionMgr.GetAvailableVersions;
      for i := 0 to High(Versions) do
        WriteLn(Versions[i].Version, ': ', Versions[i].ReleaseDate);
    finally
      VersionMgr.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs, fpdev.constants,
  fpdev.manifest.cache, fpdev.manifest;

type
  { TFPCVersionInfo - Information about an FPC version }
  TFPCVersionInfo = record
    Version: string;
    ReleaseDate: string;
    GitTag: string;
    Branch: string;
    Available: Boolean;
    Installed: Boolean;
  end;

  TFPCVersionArray = array of TFPCVersionInfo;

  { TFPCVersionManager - FPC version management service }
  TFPCVersionManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;

    { Checks if a version is valid (in known releases list). }
    function ValidateVersionInternal(const AVersion: string): Boolean;

    { Checks if a version is installed by checking executable existence. }
    function CheckVersionInstalled(const AVersion: string): Boolean;

  public
    constructor Create(AConfigManager: IConfigManager);

    { Gets the installation path for a given FPC version.
      AVersion: FPC version string
      Returns: Full path to version installation directory }
    function GetVersionInstallPath(const AVersion: string): string;

    { Gets all available FPC versions (from release database).
      Returns: Array of version info records with installation status }
    function GetAvailableVersions: TFPCVersionArray;

    { Gets only installed FPC versions.
      Returns: Array of version info records for installed versions only }
    function GetInstalledVersions: TFPCVersionArray;

    { Validates that a version string is a known FPC version.
      AVersion: Version string to validate
      Returns: True if version is in known releases list }
    function ValidateVersion(const AVersion: string): Boolean;

    { Checks if a specific version is installed.
      AVersion: Version string to check
      Returns: True if version is installed }
    function IsVersionInstalled(const AVersion: string): Boolean;

    { Lists versions to output stream.
      AShowAll: True to show all available, False for installed only
      Outp: Optional output stream
      Returns: True on success }
    function ListVersions(const AShowAll: Boolean = False; Outp: IOutput = nil): Boolean;

    { Gets the current default FPC version.
      Returns: Version string or empty if none set }
    function GetCurrentVersion: string;

    { Sets the default FPC version.
      AVersion: Version to set as default
      Returns: True if successful }
    function SetDefaultVersion(const AVersion: string): Boolean;
  end;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.version.registry;

{ TFPCVersionManager }

constructor TFPCVersionManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + FPDEV_CONFIG_DIR;
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + FPDEV_CONFIG_DIR;
    {$ENDIF}
  end;
end;

function TFPCVersionManager.GetVersionInstallPath(const AVersion: string): string;
begin
  // Default to user scope installation path
  Result := FInstallRoot + PathDelim + 'fpc' + PathDelim + AVersion;
end;

function TFPCVersionManager.CheckVersionInstalled(const AVersion: string): Boolean;
var
  InstallPath: string;
  FPCExe: string;
  ToolchainInfo: TToolchainInfo;
  ProjectRoot: string;
begin
  // First check if registered in config
  if FConfigManager.GetToolchainManager.GetToolchain('fpc-' + AVersion, ToolchainInfo) then
  begin
    if ToolchainInfo.Installed and (ToolchainInfo.InstallPath <> '') then
    begin
      {$IFDEF MSWINDOWS}
      FPCExe := ToolchainInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
      {$ELSE}
      FPCExe := ToolchainInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
      {$ENDIF}
      if FileExists(FPCExe) then
        Exit(True);
    end;
  end;

  // Check project-level installation (.fpdev/toolchains/fpc/)
  ProjectRoot := GetCurrentDir;
  {$IFDEF MSWINDOWS}
  FPCExe := ProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := ProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + AVersion + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  if FileExists(FPCExe) then
    Exit(True);

  // Fallback: check default user installation path
  InstallPath := GetVersionInstallPath(AVersion);
  {$IFDEF MSWINDOWS}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  Result := FileExists(FPCExe);
end;

function TFPCVersionManager.ValidateVersionInternal(const AVersion: string): Boolean;
begin
  Result := TVersionRegistry.Instance.IsFPCVersionValid(AVersion);
end;

function TFPCVersionManager.GetAvailableVersions: TFPCVersionArray;
var
  i: Integer;
  Releases: TFPCReleaseArray;
  Cache: TManifestCache;
  Manifest: TManifestParser;
  ManifestVersions: TStringArray;
begin
  Initialize(Result);

  // Try to load versions from manifest first
  Cache := TManifestCache.Create('');
  try
    if Cache.LoadCachedManifest('fpc', Manifest, False) then
    begin
      try
        ManifestVersions := Manifest.ListVersions('fpc');
        SetLength(Result, Length(ManifestVersions));
        for i := 0 to High(ManifestVersions) do
        begin
          Result[i].Version := ManifestVersions[i];
          Result[i].ReleaseDate := '';  // Manifest doesn't have release dates
          Result[i].GitTag := '';
          Result[i].Branch := '';
          Result[i].Available := True;
          Result[i].Installed := CheckVersionInstalled(Result[i].Version);
        end;
        Exit;
      finally
        Manifest.Free;
      end;
    end;
  finally
    Cache.Free;
  end;

  // Fallback to hardcoded version registry if manifest not available
  Releases := TVersionRegistry.Instance.GetFPCReleases;
  SetLength(Result, Length(Releases));
  for i := 0 to High(Releases) do
  begin
    Result[i].Version := Releases[i].Version;
    Result[i].ReleaseDate := Releases[i].ReleaseDate;
    Result[i].GitTag := Releases[i].GitTag;
    Result[i].Branch := Releases[i].Branch;
    Result[i].Available := True;
    Result[i].Installed := CheckVersionInstalled(Result[i].Version);
  end;
end;

function TFPCVersionManager.GetInstalledVersions: TFPCVersionArray;
var
  AllVersions: TFPCVersionArray;
  i, Count: Integer;
begin
  Initialize(Result);
  AllVersions := GetAvailableVersions;
  Count := 0;

  // Count installed versions
  for i := 0 to High(AllVersions) do
    if AllVersions[i].Installed then
      Inc(Count);

  // Create result array
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

function TFPCVersionManager.ValidateVersion(const AVersion: string): Boolean;
begin
  Result := ValidateVersionInternal(AVersion);
end;

function TFPCVersionManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := CheckVersionInstalled(AVersion);
end;

function TFPCVersionManager.ListVersions(const AShowAll: Boolean; Outp: IOutput): Boolean;
var
  Versions: TFPCVersionArray;
  i: Integer;
  DefaultVersion: string;
  Line: string;
begin
  Result := True;

  try
    if AShowAll then
      Versions := GetAvailableVersions
    else
      Versions := GetInstalledVersions;

    DefaultVersion := FConfigManager.GetToolchainManager.GetDefaultToolchain;
    if DefaultVersion <> '' then
      DefaultVersion := StringReplace(DefaultVersion, 'fpc-', '', [rfReplaceAll]);

    if AShowAll then
    begin
      if Outp <> nil then
        Outp.WriteLn(_(HELP_FPC_SUBCOMMANDS));
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_LIST_HEADER));
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
      Line := Line + Versions[i].Branch;

      if Outp <> nil then
        Outp.WriteLn(Line);
    end;

    if DefaultVersion <> '' then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [DefaultVersion]));
    end
    else
    begin
      if Outp <> nil then
        Outp.WriteLn(_(CMD_FPC_CURRENT_NONE));
    end;

  except
    on E: Exception do
    begin
      if Outp <> nil then
        Outp.WriteLn(_(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

function TFPCVersionManager.GetCurrentVersion: string;
var
  DefaultToolchain: string;
begin
  Result := '';

  try
    DefaultToolchain := FConfigManager.GetToolchainManager.GetDefaultToolchain;
    if DefaultToolchain <> '' then
      Result := StringReplace(DefaultToolchain, 'fpc-', '', [rfReplaceAll]);
  except
    Result := '';
  end;
end;

function TFPCVersionManager.SetDefaultVersion(const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
    Exit;

  try
    Result := FConfigManager.GetToolchainManager.SetDefaultToolchain('fpc-' + AVersion);
  except
    Result := False;
  end;
end;

end.
