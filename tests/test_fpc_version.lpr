program test_fpc_version;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCVersionManager

  Tests:
  - GetAvailableVersions: Returns all known FPC versions
  - ValidateVersion: Validates version strings against known releases
  - IsVersionInstalled: Checks if a version is installed locally
  - Version parsing utilities: ParseVersion, CompareSemVer, SameMajorMinor
}

uses
  SysUtils, Classes, fpdev.fpc.version, fpdev.config, fpdev.paths, fpdev.types,
  fpdev.utils, fpdev.version.registry;

var
  TestInstallRoot: string;
  TestWorkingDir: string;
  OriginalCurrentDir: string;
  ConfigManager: TFPDevConfigManager;
  VersionManager: TFPCVersionManager;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function BuildTempRoot(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + APrefix + IntToStr(GetTickCount64);
end;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create temporary install root directory
  if TestInstallRoot = '' then
    TestInstallRoot := BuildTempRoot('test_version_root_');
  ForceDirectories(TestInstallRoot);
  TestWorkingDir := TestInstallRoot + PathDelim + 'user_scope_cwd';
  ForceDirectories(TestWorkingDir);
  SetCurrentDir(TestWorkingDir);

  // Setup config manager to use test directory
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  ConfigManager.SetSettings(Settings);

  WriteLn('[Setup] Created test directory: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
  procedure DeleteDirectory(const DirPath: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if not DirectoryExists(DirPath) then Exit;

    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          FilePath := DirPath + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath)
          else
            DeleteFile(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(DirPath);
  end;

begin
  if OriginalCurrentDir <> '' then
    SetCurrentDir(OriginalCurrentDir);

  if DirectoryExists(TestInstallRoot) then
  begin
    DeleteDirectory(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('  FAILED: ', AMessage);
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TestTempPathsUseSystemTempRoot;
var
  TempRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: temp paths use system temp root');
  WriteLn('==================================================');

  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  AssertTrue(Pos(TempRoot, ExpandFileName(TestInstallRoot)) = 1,
    'Test install root should live under system temp');
  AssertTrue(Pos(TempRoot, ExpandFileName(ConfigManager.ConfigPath)) = 1,
    'Config path should live under system temp');
end;

procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected ', AExpected, ', got ', AActual, ')');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure AssertEqualsStr(const AExpected, AActual, AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected "', AExpected, '", got "', AActual, '")');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

{ Test: GetAvailableVersions returns all known versions }
procedure TestGetAvailableVersions;
var
  Versions: TFPCVersionArray;
  i: Integer;
  Has322, Has320, Has304, HasMain: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetAvailableVersions');
  WriteLn('==================================================');

  Versions := VersionManager.GetAvailableVersions;

  // Should return at least 4 versions (3.2.2, 3.2.0, 3.0.4, main)
  AssertTrue(Length(Versions) >= 4, 'Should return at least 4 versions');

  // Check for specific versions
  Has322 := False;
  Has320 := False;
  Has304 := False;
  HasMain := False;

  for i := 0 to High(Versions) do
  begin
    if Versions[i].Version = '3.2.2' then Has322 := True;
    if Versions[i].Version = '3.2.0' then Has320 := True;
    if Versions[i].Version = '3.0.4' then Has304 := True;
    if Versions[i].Version = 'main' then HasMain := True;
  end;

  AssertTrue(Has322, 'Should include version 3.2.2');
  AssertTrue(Has320, 'Should include version 3.2.0');
  AssertTrue(Has304, 'Should include version 3.0.4');
  AssertTrue(HasMain, 'Should include version main');

  // All versions should be marked as available
  for i := 0 to High(Versions) do
    AssertTrue(Versions[i].Available, 'Version ' + Versions[i].Version + ' should be available');
end;

{ Test: ValidateVersion accepts known versions }
procedure TestValidateVersionKnown;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ValidateVersion - Known versions');
  WriteLn('==================================================');

  AssertTrue(VersionManager.ValidateVersion('3.2.2'), '3.2.2 should be valid');
  AssertTrue(VersionManager.ValidateVersion('3.2.0'), '3.2.0 should be valid');
  AssertTrue(VersionManager.ValidateVersion('3.0.4'), '3.0.4 should be valid');
  AssertTrue(VersionManager.ValidateVersion('main'), 'main should be valid');
  AssertTrue(VersionManager.ValidateVersion('3.3.1'), '3.3.1 should be valid');
end;

{ Test: ValidateVersion rejects unknown versions }
procedure TestValidateVersionUnknown;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ValidateVersion - Unknown versions');
  WriteLn('==================================================');

  AssertFalse(VersionManager.ValidateVersion('9.9.9'), '9.9.9 should be invalid');
  AssertFalse(VersionManager.ValidateVersion(''), 'Empty string should be invalid');
  AssertFalse(VersionManager.ValidateVersion('invalid'), 'invalid should be invalid');
  AssertFalse(VersionManager.ValidateVersion('2.6.4'), '2.6.4 should be invalid (not in list)');
end;

{ Test: ValidateVersion is case-insensitive }
procedure TestValidateVersionCaseInsensitive;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ValidateVersion - Case insensitivity');
  WriteLn('==================================================');

  AssertTrue(VersionManager.ValidateVersion('MAIN'), 'MAIN should be valid (case insensitive)');
  AssertTrue(VersionManager.ValidateVersion('Main'), 'Main should be valid (case insensitive)');
end;

procedure TestGetVersionInstallPathUsesSameProcessHomeFallback;
var
  SavedDir: string;
  SavedHome, SavedAppData, SavedUserProfile: string;
  SavedDataRoot, SavedXDGDataHome: string;
  SavedInstallRoot, ProbeHome, UserDir: string;
  Settings: TFPDevSettings;
  LocalVersionManager: TFPCVersionManager;
  InstallPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetVersionInstallPath - Same-process HOME fallback');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  SavedHome := get_env('HOME');
  SavedAppData := get_env('APPDATA');
  SavedUserProfile := get_env('USERPROFILE');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  LocalVersionManager := nil;

  try
    ProbeHome := TestInstallRoot + PathDelim + 'env_home_probe';
    UserDir := TestInstallRoot + PathDelim + 'env_home_user_scope';
    ForceDirectories(ProbeHome);
    ForceDirectories(UserDir);

    Settings.InstallRoot := '';
    ConfigManager.SetSettings(Settings);
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');

    {$IFDEF MSWINDOWS}
    AssertTrue(set_env('APPDATA', ProbeHome),
      'Should set same-process APPDATA override for version install root fallback');
    AssertTrue(set_env('USERPROFILE', ProbeHome),
      'Should set same-process USERPROFILE override for version install root fallback');
    {$ELSE}
    AssertTrue(set_env('HOME', ProbeHome),
      'Should set same-process HOME override for version install root fallback');
    {$ENDIF}

    AssertTrue(SetCurrentDir(UserDir),
      'Should change into user-scope temp directory for version install root fallback');

    LocalVersionManager := TFPCVersionManager.Create(ConfigManager.AsConfigManager);
    InstallPath := LocalVersionManager.GetVersionInstallPath('3.2.2');

    AssertEqualsStr(
      BuildFPCInstallDirFromInstallRoot(GetDataRoot, '3.2.2'),
      InstallPath,
      'Should resolve version install path from same-process HOME/APPDATA fallback'
    );
  finally
    LocalVersionManager.Free;
    SetCurrentDir(SavedDir);
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    RestoreEnv('HOME', SavedHome);
    RestoreEnv('APPDATA', SavedAppData);
    RestoreEnv('USERPROFILE', SavedUserProfile);
  end;
end;

procedure TestGetVersionInstallPathUsesFPDEVDataRootOverride;
var
  SavedDir: string;
  SavedDataRoot: string;
  SavedInstallRoot: string;
  ProbeRoot: string;
  UserDir: string;
  Settings: TFPDevSettings;
  LocalVersionManager: TFPCVersionManager;
  InstallPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetVersionInstallPath - FPDEV_DATA_ROOT override');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  LocalVersionManager := nil;

  try
    ProbeRoot := TestInstallRoot + PathDelim + 'data_root_probe';
    UserDir := TestInstallRoot + PathDelim + 'data_root_user_scope';
    ForceDirectories(ProbeRoot);
    ForceDirectories(UserDir);

    Settings.InstallRoot := '';
    ConfigManager.SetSettings(Settings);
    SetPortableMode(False);
    AssertTrue(set_env('FPDEV_DATA_ROOT', ProbeRoot),
      'Should set same-process FPDEV_DATA_ROOT override for version install path');
    AssertTrue(SetCurrentDir(UserDir),
      'Should change into user-scope temp directory for FPDEV_DATA_ROOT probe');

    LocalVersionManager := TFPCVersionManager.Create(ConfigManager.AsConfigManager);
    InstallPath := LocalVersionManager.GetVersionInstallPath('3.2.2');

    AssertEqualsStr(
      BuildFPCInstallDirFromInstallRoot(GetDataRoot, '3.2.2'),
      InstallPath,
      'Should resolve version install path from FPDEV_DATA_ROOT override'
    );
  finally
    LocalVersionManager.Free;
    SetCurrentDir(SavedDir);
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
  end;
end;

procedure TestValidateVersionFallsBackToStaticCatalogWhenRegistryEmpty;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ValidateVersion - Empty registry falls back to static catalog');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-version-empty-validate.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty version registry data should reload');

    AssertTrue(VersionManager.ValidateVersion('3.2.2'),
      '3.2.2 should remain valid when registry releases are empty');
    AssertTrue(VersionManager.ValidateVersion('main'),
      'main should remain valid when registry releases are empty');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
  end;
end;

{ Test: IsVersionInstalled returns false for non-installed versions }
procedure TestIsVersionInstalledFalse;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: IsVersionInstalled - Not installed');
  WriteLn('==================================================');

  // No versions are installed in test environment
  AssertFalse(VersionManager.IsVersionInstalled('3.2.2'), '3.2.2 should not be installed');
  AssertFalse(VersionManager.IsVersionInstalled('3.2.0'), '3.2.0 should not be installed');
  AssertFalse(VersionManager.IsVersionInstalled('main'), 'main should not be installed');
end;

{ Test: IsVersionInstalled returns true when FPC executable exists }
procedure TestIsVersionInstalledTrue;
var
  FPCDir, FPCExe: string;
  F: TextFile;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: IsVersionInstalled - Installed');
  WriteLn('==================================================');

  // Create fake FPC installation
  FPCDir := BuildFPCInstallDirFromInstallRoot(TestInstallRoot, '3.2.2') + PathDelim + 'bin';
  ForceDirectories(FPCDir);

  {$IFDEF MSWINDOWS}
  FPCExe := FPCDir + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExe := FPCDir + PathDelim + 'fpc';
  {$ENDIF}

  // Create dummy executable file
  AssignFile(F, FPCExe);
  Rewrite(F);
  WriteLn(F, '#!/bin/sh');
  WriteLn(F, 'echo "mock fpc"');
  CloseFile(F);

  AssertTrue(VersionManager.IsVersionInstalled('3.2.2'), '3.2.2 should be installed after creating executable');
end;

{ Test: GetInstalledVersions returns only installed versions }
procedure TestGetInstalledVersions;
var
  Versions: TFPCVersionArray;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetInstalledVersions');
  WriteLn('==================================================');

  // After TestIsVersionInstalledTrue, 3.2.2 should be installed
  Versions := VersionManager.GetInstalledVersions;

  AssertEquals(1, Length(Versions), 'Should have exactly 1 installed version');
  if Length(Versions) > 0 then
    AssertEqualsStr('3.2.2', Versions[0].Version, 'Installed version should be 3.2.2');
end;

{ Test: GetVersionInfo returns correct info for known version }
procedure TestGetVersionInfo;
var
  Info: TFPCVersionInfo;
  Found: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetVersionInfo');
  WriteLn('==================================================');

  Found := VersionManager.GetVersionInfo('3.2.2', Info);

  AssertTrue(Found, 'Should find info for 3.2.2');
  AssertEqualsStr('3.2.2', Info.Version, 'Version should be 3.2.2');
  AssertEqualsStr('release_3_2_2', Info.GitTag, 'GitTag should be release_3_2_2');
  AssertEqualsStr('fixes_3_2', Info.Branch, 'Branch should be fixes_3_2');
  AssertTrue(Info.Available, 'Should be available');
end;

{ Test: GetVersionInfo returns false for unknown version }
procedure TestGetVersionInfoUnknown;
var
  Info: TFPCVersionInfo;
  Found: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetVersionInfo - Unknown version');
  WriteLn('==================================================');

  Found := VersionManager.GetVersionInfo('9.9.9', Info);

  AssertFalse(Found, 'Should not find info for 9.9.9');
end;

{ Test: GetGitTag returns correct tag }
procedure TestGetGitTag;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetGitTag');
  WriteLn('==================================================');

  AssertEqualsStr('release_3_2_2', VersionManager.GetGitTag('3.2.2'), 'GitTag for 3.2.2');
  AssertEqualsStr('release_3_2_0', VersionManager.GetGitTag('3.2.0'), 'GitTag for 3.2.0');
  AssertEqualsStr('main', VersionManager.GetGitTag('main'), 'GitTag for main');
  AssertEqualsStr('', VersionManager.GetGitTag('9.9.9'), 'GitTag for unknown version');
end;

procedure TestGetGitTagFallsBackToStaticCatalogWhenRegistryEmpty;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetGitTag - Empty registry falls back to static catalog');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-version-empty-gittag.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty version registry data should reload for GetGitTag');

    AssertEqualsStr('release_3_2_2', VersionManager.GetGitTag('3.2.2'),
      'GetGitTag should use static catalog when registry releases are empty');
    AssertEqualsStr('main', VersionManager.GetGitTag('main'),
      'GetGitTag should preserve main git tag when registry releases are empty');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
  end;
end;

{ Test: GetBranch returns correct branch }
procedure TestGetBranch;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetBranch');
  WriteLn('==================================================');

  AssertEqualsStr('fixes_3_2', VersionManager.GetBranch('3.2.2'), 'Branch for 3.2.2');
  AssertEqualsStr('fixes_3_2', VersionManager.GetBranch('3.2.0'), 'Branch for 3.2.0');
  AssertEqualsStr('fixes_3_0', VersionManager.GetBranch('3.0.4'), 'Branch for 3.0.4');
  AssertEqualsStr('main', VersionManager.GetBranch('main'), 'Branch for main');
  AssertEqualsStr('', VersionManager.GetBranch('9.9.9'), 'Branch for unknown version');
end;

{ Test: ParseVersion utility function }
procedure TestParseVersion;
var
  Major, Minor, Patch: Integer;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: ParseVersion utility');
  WriteLn('==================================================');

  ParseVersion('3.2.2', Major, Minor, Patch);
  AssertEquals(3, Major, 'Major version of 3.2.2');
  AssertEquals(2, Minor, 'Minor version of 3.2.2');
  AssertEquals(2, Patch, 'Patch version of 3.2.2');

  ParseVersion('3.0.4', Major, Minor, Patch);
  AssertEquals(3, Major, 'Major version of 3.0.4');
  AssertEquals(0, Minor, 'Minor version of 3.0.4');
  AssertEquals(4, Patch, 'Patch version of 3.0.4');

  ParseVersion('10.20.30', Major, Minor, Patch);
  AssertEquals(10, Major, 'Major version of 10.20.30');
  AssertEquals(20, Minor, 'Minor version of 10.20.30');
  AssertEquals(30, Patch, 'Patch version of 10.20.30');

  // Edge cases
  ParseVersion('3.2', Major, Minor, Patch);
  AssertEquals(3, Major, 'Major version of 3.2');
  AssertEquals(2, Minor, 'Minor version of 3.2');
  AssertEquals(0, Patch, 'Patch version of 3.2 (missing)');

  ParseVersion('3', Major, Minor, Patch);
  AssertEquals(3, Major, 'Major version of 3');
  AssertEquals(0, Minor, 'Minor version of 3 (missing)');
  AssertEquals(0, Patch, 'Patch version of 3 (missing)');
end;

{ Test: CompareSemVer utility function }
procedure TestCompareSemVer;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CompareSemVer utility');
  WriteLn('==================================================');

  AssertEquals(0, CompareSemVer('3.2.2', '3.2.2'), '3.2.2 = 3.2.2');
  AssertEquals(1, CompareSemVer('3.2.2', '3.2.0'), '3.2.2 > 3.2.0');
  AssertEquals(-1, CompareSemVer('3.2.0', '3.2.2'), '3.2.0 < 3.2.2');
  AssertEquals(1, CompareSemVer('3.2.2', '3.0.4'), '3.2.2 > 3.0.4');
  AssertEquals(-1, CompareSemVer('3.0.4', '3.2.2'), '3.0.4 < 3.2.2');
  AssertEquals(1, CompareSemVer('4.0.0', '3.2.2'), '4.0.0 > 3.2.2');
  AssertEquals(-1, CompareSemVer('3.2.2', '4.0.0'), '3.2.2 < 4.0.0');
end;

{ Test: SameMajorMinor utility function }
procedure TestSameMajorMinor;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: SameMajorMinor utility');
  WriteLn('==================================================');

  AssertTrue(SameMajorMinor('3.2.2', '3.2.0'), '3.2.2 and 3.2.0 have same major.minor');
  AssertTrue(SameMajorMinor('3.2.2', '3.2.4'), '3.2.2 and 3.2.4 have same major.minor');
  AssertFalse(SameMajorMinor('3.2.2', '3.0.4'), '3.2.2 and 3.0.4 have different minor');
  AssertFalse(SameMajorMinor('3.2.2', '4.2.2'), '3.2.2 and 4.2.2 have different major');
end;

{ Test: GetVersionInstallPath returns correct path }
procedure TestGetVersionInstallPath;
var
  Path: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetVersionInstallPath');
  WriteLn('==================================================');

  Path := VersionManager.GetVersionInstallPath('3.2.2');
  AssertTrue(Pos('fpc', Path) > 0, 'Path should contain "fpc"');
  AssertTrue(Pos('3.2.2', Path) > 0, 'Path should contain version "3.2.2"');
end;

procedure TestGetVersionInstallPathUsesConfiguredCustomPrefix;
var
  SavedDir: string;
  Info: TToolchainInfo;
  CustomPath: string;
  Path: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetVersionInstallPath honors configured custom prefix');
  WriteLn('==================================================');

  SavedDir := GetCurrentDir;
  try
    SetCurrentDir(TestInstallRoot);
    CustomPath := TestInstallRoot + PathDelim + 'custom-fpc-3.3.1';
    ForceDirectories(CustomPath + PathDelim + 'bin');

    Initialize(Info);
    Info.Version := '3.3.1';
    Info.InstallPath := CustomPath;
    Info.Installed := True;
    ConfigManager.AddToolchain('fpc-3.3.1', Info);

    Path := VersionManager.GetVersionInstallPath('3.3.1');
    AssertEqualsStr(CustomPath, Path, 'Configured install path should override default');

    {$IFDEF MSWINDOWS}
    AssertEqualsStr(CustomPath + PathDelim + 'bin' + PathDelim + 'fpc.exe',
      VersionManager.GetFPCExecutablePath('3.3.1'),
      'Executable path should be derived from configured custom prefix');
    {$ELSE}
    AssertEqualsStr(CustomPath + PathDelim + 'bin' + PathDelim + 'fpc',
      VersionManager.GetFPCExecutablePath('3.3.1'),
      'Executable path should be derived from configured custom prefix');
    {$ENDIF}
  finally
    SetCurrentDir(SavedDir);
  end;
end;

{ Test: GetFPCExecutablePath returns correct path }
procedure TestGetFPCExecutablePath;
var
  Path: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetFPCExecutablePath');
  WriteLn('==================================================');

  Path := VersionManager.GetFPCExecutablePath('3.2.2');
  AssertTrue(Pos('bin', Path) > 0, 'Path should contain "bin"');
  {$IFDEF MSWINDOWS}
  AssertTrue(Pos('fpc.exe', Path) > 0, 'Path should contain "fpc.exe" on Windows');
  {$ELSE}
  AssertTrue(Pos('fpc', Path) > 0, 'Path should contain "fpc"');
  {$ENDIF}
end;

procedure TestGetAvailableVersionsFallsBackToStaticCatalogWhenRegistryEmpty;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  Versions: TFPCVersionArray;
  i: Integer;
  Has322: Boolean;
  HasMain: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetAvailableVersions - Empty registry falls back to static catalog');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-version-empty-list.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty version registry data should reload for GetAvailableVersions');

    Versions := VersionManager.GetAvailableVersions;
    Has322 := False;
    HasMain := False;
    for i := 0 to High(Versions) do
    begin
      if Versions[i].Version = '3.2.2' then Has322 := True;
      if Versions[i].Version = 'main' then HasMain := True;
    end;

    AssertTrue(Length(Versions) >= 4,
      'GetAvailableVersions should not become empty when registry releases are empty');
    AssertTrue(Has322, 'GetAvailableVersions should include 3.2.2 from static catalog');
    AssertTrue(HasMain, 'GetAvailableVersions should include main from static catalog');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCVersionManager Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    OriginalCurrentDir := GetCurrentDir;
    TestInstallRoot := BuildTempRoot('test_version_root_');
    ForceDirectories(TestInstallRoot);
    ConfigManager := TFPDevConfigManager.Create(IncludeTrailingPathDelimiter(TestInstallRoot) + 'config.json');
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      // Setup test environment
      SetupTestEnvironment;
      try
        TestTempPathsUseSystemTempRoot;
        // Create version manager
        VersionManager := TFPCVersionManager.Create(ConfigManager.AsConfigManager);
        try
          // Run tests
          TestGetAvailableVersions;
          TestValidateVersionKnown;
          TestValidateVersionUnknown;
          TestValidateVersionCaseInsensitive;
          TestGetVersionInstallPathUsesSameProcessHomeFallback;
          TestGetVersionInstallPathUsesFPDEVDataRootOverride;
          TestValidateVersionFallsBackToStaticCatalogWhenRegistryEmpty;
          TestIsVersionInstalledFalse;
          TestIsVersionInstalledTrue;
          TestGetInstalledVersions;
          TestGetVersionInfo;
          TestGetVersionInfoUnknown;
          TestGetGitTag;
          TestGetGitTagFallsBackToStaticCatalogWhenRegistryEmpty;
          TestGetBranch;
          TestParseVersion;
          TestCompareSemVer;
          TestSameMajorMinor;
          TestGetVersionInstallPath;
          TestGetVersionInstallPathUsesConfiguredCustomPrefix;
          TestGetFPCExecutablePath;
          TestGetAvailableVersionsFallsBackToStaticCatalogWhenRegistryEmpty;

          // Summary
          WriteLn;
          WriteLn('========================================');
          WriteLn('  Test Summary');
          WriteLn('========================================');
          WriteLn('  Passed: ', TestsPassed);
          WriteLn('  Failed: ', TestsFailed);
          WriteLn('  Total:  ', TestsPassed + TestsFailed);
          WriteLn;

          if TestsFailed > 0 then
          begin
            WriteLn('  SOME TESTS FAILED');
            ExitCode := 1;
          end
          else
          begin
            WriteLn('  ALL TESTS PASSED');
            ExitCode := 0;
          end;

        finally
          VersionManager.Free;
        end;
      finally
        TeardownTestEnvironment;
      end;
    finally
      ConfigManager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite failed with exception');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
