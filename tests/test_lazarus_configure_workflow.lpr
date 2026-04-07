program test_lazarus_configure_workflow;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.output.intf, fpdev.config.interfaces, fpdev.config.managers, fpdev.lazarus.manager, fpdev.utils,
  fpdev.paths, fpdev.version.registry, fpdev.lazarus.config, test_temp_paths;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  LazarusManager: fpdev.lazarus.manager.TLazarusManager;
  OriginalLazarusConfigRoot: string;
  TestsPassed: Integer;
  TestsFailed: Integer;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
    FOwnsBuffer: Boolean;
  public
    constructor Create(ABuffer: TStringList = nil);
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

constructor TStringOutput.Create(ABuffer: TStringList);
begin
  inherited Create;
  if Assigned(ABuffer) then
  begin
    FBuffer := ABuffer;
    FOwnsBuffer := False;
  end
  else
  begin
    FBuffer := TStringList.Create;
    FOwnsBuffer := True;
  end;
end;

destructor TStringOutput.Destroy;
begin
  if FOwnsBuffer then
    FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create test root directory in temp
  TestRootDir := CreateUniqueTempDir('test_lazarus_configure_workflow');
  if not PathUsesSystemTempRoot(TestRootDir) then
    raise Exception.Create('Test root dir should use system temp root');

  OriginalLazarusConfigRoot := GetEnvironmentVariable('FPDEV_LAZARUS_CONFIG_ROOT');
  if not set_env('FPDEV_LAZARUS_CONFIG_ROOT',
    IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root') then
    raise Exception.Create('Failed to set isolated Lazarus config root');

  // Initialize config manager (interface-based)
  ConfigManager := CreateIsolatedConfigManager;

  // Override install root to test directory
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  // Create Lazarus manager
  LazarusManager := fpdev.lazarus.manager.TLazarusManager.Create(ConfigManager);

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
begin
  if Assigned(LazarusManager) then
    LazarusManager.Free;
  ConfigManager := nil;  // Interface will be freed automatically

  CleanupTempDir(TestRootDir);

  if OriginalLazarusConfigRoot <> '' then
    set_env('FPDEV_LAZARUS_CONFIG_ROOT', OriginalLazarusConfigRoot)
  else
    unset_env('FPDEV_LAZARUS_CONFIG_ROOT');

  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  WriteLn('========================================');
end;

procedure AssertTrue(const Condition: Boolean; const TestName, Message: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  ', Message);
    Inc(TestsFailed);
  end;
end;

procedure AssertFalse(const Condition: Boolean; const TestName, Message: string);
begin
  AssertTrue(not Condition, TestName, Message);
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('Failed to mark executable: ' + APath);
  {$ENDIF}
end;

procedure WriteMockExecutable(const APath, ALabel: string);
begin
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('echo "' + ALabel + '"');
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;

procedure WriteMockLaunchExecutable(const APath, ALabel, AMarkerPath: string);
begin
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('printf "%s" "' + ALabel + '" > "' + AMarkerPath + '"');
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;

function WaitForFile(const APath: string; const ATimeoutMs: Integer = 1000): Boolean;
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + QWord(ATimeoutMs);
  repeat
    if FileExists(APath) then
      Exit(True);
    Sleep(50);
  until GetTickCount64 >= Deadline;
  Result := FileExists(APath);
end;

procedure CreateMockLazarusInstall(const AVersion: string; out AInstallPath, AExecutablePath: string);
begin
  AInstallPath := TestRootDir + PathDelim + 'lazarus' + PathDelim + AVersion;
  {$IFDEF MSWINDOWS}
  ForceDirectories(AInstallPath);
  AExecutablePath := AInstallPath + PathDelim + 'lazarus.exe';
  {$ELSE}
  ForceDirectories(AInstallPath + PathDelim + 'bin');
  AExecutablePath := AInstallPath + PathDelim + 'bin' + PathDelim + 'lazarus-ide';
  {$ENDIF}
  WriteMockExecutable(AExecutablePath, 'Mock Lazarus');
end;

procedure CreateMockLazarusInstallAtPath(const AInstallPath: string; out AExecutablePath: string);
begin
  {$IFDEF MSWINDOWS}
  ForceDirectories(AInstallPath);
  AExecutablePath := AInstallPath + PathDelim + 'lazarus.exe';
  {$ELSE}
  ForceDirectories(AInstallPath + PathDelim + 'bin');
  AExecutablePath := AInstallPath + PathDelim + 'bin' + PathDelim + 'lazarus-ide';
  {$ENDIF}
  WriteMockExecutable(AExecutablePath, 'Mock Lazarus');
end;

procedure CreateMockFPCInstall(const AVersion: string; out AExecutablePath: string);
var
  InstallPath: string;
begin
  InstallPath := BuildFPCInstallDirFromInstallRoot(TestRootDir, AVersion);
  ForceDirectories(InstallPath + PathDelim + 'bin');
  {$IFDEF MSWINDOWS}
  AExecutablePath := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  AExecutablePath := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  WriteMockExecutable(AExecutablePath, 'Mock FPC');
end;

function GetRecommendedFPCVersion(const ALazarusVersion: string): string;
begin
  Result := TVersionRegistry.Instance.GetLazarusRecommendedFPC(ALazarusVersion);
end;

procedure RegisterLazarusInstall(const AVersion, AInstallPath: string);
var
  Info: TLazarusInfo;
begin
  Info := Default(TLazarusInfo);
  Info.Version := AVersion;
  Info.FPCVersion := 'fpc-' + GetRecommendedFPCVersion(AVersion);
  Info.InstallPath := AInstallPath;
  Info.SourceURL := 'https://example.invalid/lazarus-' + AVersion + '.git';
  Info.Installed := True;
  if not ConfigManager.GetLazarusManager.AddLazarusVersion('lazarus-' + AVersion, Info) then
    raise Exception.Create('Failed to register Lazarus version lazarus-' + AVersion);
end;

procedure RegisterLazarusInstallWithFPC(const AVersion, AFPCVersion, AInstallPath: string);
var
  Info: TLazarusInfo;
begin
  Info := Default(TLazarusInfo);
  Info.Version := AVersion;
  Info.FPCVersion := 'fpc-' + AFPCVersion;
  Info.InstallPath := AInstallPath;
  Info.SourceURL := 'https://example.invalid/lazarus-' + AVersion + '.git';
  Info.Installed := True;
  if not ConfigManager.GetLazarusManager.AddLazarusVersion('lazarus-' + AVersion, Info) then
    raise Exception.Create('Failed to register Lazarus version lazarus-' + AVersion);
end;

procedure WriteCustomRegistryWithoutVersion(const APath: string);
begin
  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "lazarus_3_6",');
    Add('        "branch": "lazarus_3_6",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(APath);
  finally
    Free;
  end;
end;

procedure TestConfigManagerUsesIsolatedDefaultConfigPath;
var
  ConfigPath: string;
  TempRoot: string;
  ExpectedPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Config Manager Uses Isolated Config Path');
  WriteLn('==================================================');

  try
    ConfigPath := ExpandFileName(ConfigManager.GetConfigPath);
    TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
    ExpectedPath := ExpandFileName(GetIsolatedDefaultConfigPath);

    AssertTrue(Pos(TempRoot, ConfigPath) = 1,
      'Config path uses system temp root',
      'Expected config path under temp root "' + TempRoot + '", got "' + ConfigPath + '"');

    AssertTrue(ConfigPath = ExpectedPath,
      'Config path uses isolated default override',
      'Expected config path "' + ExpectedPath + '", got "' + ConfigPath + '"');
  except
    on E: Exception do
      AssertTrue(False, 'Config path isolation check',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 1: ConfigureIDE fails when Lazarus not installed
// ============================================================================
procedure TestConfigureIDEFailsWhenNotInstalled;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: ConfigureIDE Fails When Not Installed');
  WriteLn('==================================================');

  try
    // Execute: Call ConfigureIDE on non-existent version
    Success := LazarusManager.ConfigureIDE('99.99');

    // Assert: Should fail because version is not installed
    AssertFalse(Success, 'ConfigureIDE fails for non-existent version',
      'ConfigureIDE should return False when Lazarus version is not installed');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE handles missing version', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: ConfigureIDE succeeds when Lazarus is installed
// ============================================================================
procedure TestConfigureIDESucceedsWhenInstalled;
var
  LazarusPath: string;
  LazarusExe: string;
  FPCExe: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: ConfigureIDE Succeeds When Installed');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus installation
    CreateMockLazarusInstall('3.0', LazarusPath, LazarusExe);

    // Setup: Create mock FPC installation
    CreateMockFPCInstall(GetRecommendedFPCVersion('3.0'), FPCExe);

    // Execute: Call ConfigureIDE
    Success := LazarusManager.ConfigureIDE('3.0');

    AssertTrue(Success, 'ConfigureIDE succeeds for installed version',
      'ConfigureIDE should return True for current installed layout');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE succeeds when installed', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: ConfigureIDE creates config directory
// ============================================================================
procedure TestConfigureIDECreatesConfigDir;
var
  LazarusPath: string;
  LazarusExe: string;
  FPCExe: string;
  ConfigDir: string;
  ConfigRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: ConfigureIDE Creates Config Directory');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus installation
    CreateMockLazarusInstall('3.1', LazarusPath, LazarusExe);
    CreateMockFPCInstall(GetRecommendedFPCVersion('3.1'), FPCExe);

    {$IFDEF MSWINDOWS}
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + 'lazarus-3.1';
    {$ELSE}
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + '.lazarus-3.1';
    {$ENDIF}

    // Execute: Call ConfigureIDE
    LazarusManager.ConfigureIDE('3.1');

    // Assert: Config directory should be created
    AssertTrue(DirectoryExists(ConfigDir), 'ConfigureIDE creates config directory',
      'ConfigureIDE should create Lazarus config directory');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE creates config dir', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 4: ConfigureIDE creates backup
// ============================================================================
procedure TestConfigureIDECreatesBackup;
var
  LazarusPath: string;
  LazarusExe: string;
  FPCExe: string;
  ConfigDir: string;
  EnvOptionsFile: string;
  BackupDir: string;
  ConfigRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: ConfigureIDE Creates Backup');
  WriteLn('==================================================');

  try
    // Setup: Create mock Lazarus installation
    CreateMockLazarusInstall('3.2', LazarusPath, LazarusExe);
    CreateMockFPCInstall(GetRecommendedFPCVersion('3.2'), FPCExe);

    {$IFDEF MSWINDOWS}
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + 'lazarus-3.2';
    {$ELSE}
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + '.lazarus-3.2';
    {$ENDIF}

    ForceDirectories(ConfigDir);

    // Create existing config file
    EnvOptionsFile := ConfigDir + PathDelim + 'environmentoptions.xml';
    with TStringList.Create do
    try
      Add('<?xml version="1.0" encoding="UTF-8"?>');
      Add('<CONFIG>');
      Add('  <EnvironmentOptions>');
      Add('    <CompilerFilename Value="/old/path/fpc"/>');
      Add('  </EnvironmentOptions>');
      Add('</CONFIG>');
      SaveToFile(EnvOptionsFile);
    finally
      Free;
    end;

    // Execute: Call ConfigureIDE
    LazarusManager.ConfigureIDE('3.2');

    // Assert: Backup directory should be created
    BackupDir := ConfigDir + PathDelim + 'backups';
    AssertTrue(DirectoryExists(BackupDir), 'ConfigureIDE creates backup directory',
      'ConfigureIDE should create backup directory');

  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE creates backup', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 5: ConfigureIDE honors configured custom install path
// ============================================================================
procedure TestConfigureIDEUsesConfiguredCustomInstallPath;
var
  CustomInstallPath: string;
  LazarusExe: string;
  FPCExe: string;
  Success: Boolean;
  ConfigRoot: string;
  ConfigDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: ConfigureIDE Uses Configured Custom Install Path');
  WriteLn('==================================================');

  try
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.3';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.3', CustomInstallPath);
    CreateMockFPCInstall(GetRecommendedFPCVersion('3.3'), FPCExe);

    Success := LazarusManager.ConfigureIDE('3.3');

    AssertTrue(Success, 'ConfigureIDE uses configured custom install path',
      'ConfigureIDE should succeed when config points to an installed custom Lazarus path');

    {$IFDEF MSWINDOWS}
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + 'lazarus-3.3';
    {$ELSE}
    ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root';
    ConfigDir := ExcludeTrailingPathDelimiter(ConfigRoot) + PathDelim + '.lazarus-3.3';
    {$ENDIF}

    AssertTrue(FileExists(ConfigDir + PathDelim + 'environmentoptions.xml'),
      'ConfigureIDE writes config for configured custom install path',
      'Expected environmentoptions.xml under "' + ConfigDir + '"');
  except
    on E: Exception do
      AssertTrue(False, 'ConfigureIDE honors configured custom install path',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 5b: ConfigureIDE honors same-process HOME/APPDATA when config root is unset
// ============================================================================
procedure TestConfigureIDEUsesSameProcessHomeWhenConfigRootUnset;
var
  CustomInstallPath: string;
  LazarusExe: string;
  FPCExe: string;
  Success: Boolean;
  SavedConfigRoot: string;
  SavedHome: string;
  SavedAppData: string;
  ProbeConfigBase: string;
  ConfigDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5b: ConfigureIDE Uses Same-Process HOME/APPDATA When Config Root Is Unset');
  WriteLn('==================================================');

  SavedConfigRoot := get_env('FPDEV_LAZARUS_CONFIG_ROOT');
  SavedHome := get_env('HOME');
  SavedAppData := get_env('APPDATA');
  try
    try
      unset_env('FPDEV_LAZARUS_CONFIG_ROOT');

      ProbeConfigBase := IncludeTrailingPathDelimiter(TestRootDir) + 'same-process-config-home';
      ForceDirectories(ProbeConfigBase);

      {$IFDEF MSWINDOWS}
      AssertTrue(set_env('APPDATA', ProbeConfigBase),
        'ConfigureIDE test sets same-process APPDATA',
        'Expected APPDATA to be set to "' + ProbeConfigBase + '"');
      ConfigDir := ExcludeTrailingPathDelimiter(ProbeConfigBase) + PathDelim + 'lazarus-3.3';
      {$ELSE}
      AssertTrue(set_env('HOME', ProbeConfigBase),
        'ConfigureIDE test sets same-process HOME',
        'Expected HOME to be set to "' + ProbeConfigBase + '"');
      ConfigDir := ExcludeTrailingPathDelimiter(ProbeConfigBase) + PathDelim + '.lazarus-3.3';
      {$ENDIF}

      CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.3-home-env';
      CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
      RegisterLazarusInstall('3.3', CustomInstallPath);
      CreateMockFPCInstall(GetRecommendedFPCVersion('3.3'), FPCExe);

      Success := LazarusManager.ConfigureIDE('3.3');

      AssertTrue(Success, 'ConfigureIDE succeeds with same-process HOME/APPDATA override',
        'Expected ConfigureIDE(3.3) to succeed when config root is unset');
      AssertTrue(FileExists(ConfigDir + PathDelim + 'environmentoptions.xml'),
        'ConfigureIDE writes config under same-process HOME/APPDATA override',
        'Expected environmentoptions.xml under "' + ConfigDir + '"');
    except
      on E: Exception do
        AssertTrue(False, 'ConfigureIDE uses same-process HOME/APPDATA when config root is unset',
          'Exception: ' + E.Message);
    end;
  finally
    RestoreEnv('FPDEV_LAZARUS_CONFIG_ROOT', SavedConfigRoot);
    RestoreEnv('HOME', SavedHome);
    RestoreEnv('APPDATA', SavedAppData);
  end;
end;

// ============================================================================
// Test 6: UninstallVersion removes configured custom install path
// ============================================================================
procedure TestUninstallVersionUsesConfiguredCustomInstallPath;
var
  CustomInstallPath: string;
  LazarusExe: string;
  Success: Boolean;
  Info: TLazarusInfo;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: UninstallVersion Uses Configured Custom Install Path');
  WriteLn('==================================================');

  try
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.4';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.4', CustomInstallPath);

    Success := LazarusManager.UninstallVersion('3.4');

    AssertTrue(Success, 'UninstallVersion succeeds for configured custom install path',
      'UninstallVersion should succeed when config points to an installed custom Lazarus path');
    AssertFalse(DirectoryExists(CustomInstallPath),
      'UninstallVersion removes configured custom install directory',
      'Expected custom install path "' + CustomInstallPath + '" to be deleted');
    AssertFalse(ConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-3.4', Info),
      'UninstallVersion removes configured custom install metadata',
      'Expected lazarus-3.4 entry to be removed from config');
  except
    on E: Exception do
      AssertTrue(False, 'UninstallVersion uses configured custom install path',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 7: UninstallVersion removes stale configured metadata
// ============================================================================
procedure TestUninstallVersionRemovesStaleConfiguredMetadata;
var
  MissingInstallPath: string;
  Success: Boolean;
  Info: TLazarusInfo;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 7: UninstallVersion Removes Stale Configured Metadata');
  WriteLn('==================================================');

  try
    MissingInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'missing-lazarus-3.5';
    RegisterLazarusInstall('3.5', MissingInstallPath);

    Success := LazarusManager.UninstallVersion('3.5');

    AssertTrue(Success, 'UninstallVersion succeeds for stale configured metadata',
      'UninstallVersion should still succeed when config exists but install path is already gone');
    AssertFalse(ConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-3.5', Info),
      'UninstallVersion removes stale configured metadata',
      'Expected lazarus-3.5 entry to be removed from config even when install path is missing');
  except
    on E: Exception do
      AssertTrue(False, 'UninstallVersion removes stale configured metadata',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 8: UninstallVersion clears removed default version
// ============================================================================
procedure TestUninstallVersionClearsDefaultVersion;
var
  CustomInstallPath: string;
  LazarusExe: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 8: UninstallVersion Clears Default Version');
  WriteLn('==================================================');

  try
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.6-default';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.6', CustomInstallPath);
    AssertTrue(ConfigManager.GetLazarusManager.SetDefaultLazarusVersion('lazarus-3.6'),
      'Setup default Lazarus version for uninstall test',
      'Expected lazarus-3.6 to become default before uninstall');

    Success := LazarusManager.UninstallVersion('3.6');

    AssertTrue(Success, 'UninstallVersion succeeds for default version',
      'UninstallVersion should succeed when removing the current default Lazarus version');
    AssertTrue(ConfigManager.GetLazarusManager.GetDefaultLazarusVersion = '',
      'UninstallVersion clears removed default version',
      'Expected default_version to be cleared after removing lazarus-3.6');
  except
    on E: Exception do
      AssertTrue(False, 'UninstallVersion clears removed default version',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 9: ListVersions keeps installed version when registry omits it
// ============================================================================
procedure TestListVersionsIncludesInstalledVersionMissingFromRegistry;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 9: ListVersions Includes Installed Version Missing From Registry');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-registry-missing.json';
  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    WriteCustomRegistryWithoutVersion(VersionsJSONPath);
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus registry without installed version reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.7-hidden';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.7', CustomInstallPath);

    Success := LazarusManager.ListVersions(Outp, False);

    AssertTrue(Success, 'ListVersions succeeds when installed version is missing from registry',
      'Expected ListVersions(False) to succeed');
    AssertTrue(Pos('3.7', OutBuf.Text) > 0,
      'ListVersions includes installed version missing from registry',
      OutBuf.Text);
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 10: ShowVersionInfo supports installed version missing from registry
// ============================================================================
procedure TestShowVersionInfoSupportsInstalledVersionMissingFromRegistry;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 10: ShowVersionInfo Supports Installed Version Missing From Registry');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-show-missing.json';
  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    WriteCustomRegistryWithoutVersion(VersionsJSONPath);
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus show registry without installed version reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.7-show';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.7', CustomInstallPath);

    Success := LazarusManager.ShowVersionInfo(Outp, '3.7');

    AssertTrue(Success, 'ShowVersionInfo succeeds for installed version missing from registry',
      'Expected ShowVersionInfo(3.7) to succeed when version is installed from existing config');
    AssertTrue(Pos('Version:      3.7', OutBuf.Text) > 0,
      'ShowVersionInfo prints installed version missing from registry',
      OutBuf.Text);
    AssertTrue(Pos('Install Path: ' + CustomInstallPath, OutBuf.Text) > 0,
      'ShowVersionInfo prints resolved install path for registry-missing installed version',
      OutBuf.Text);
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 11: ConfigureIDE prefers configured FPC version for registry-missing install
// ============================================================================
procedure TestConfigureIDEPrefersConfiguredFPCVersionWhenRegistryMissing;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomInstallPath: string;
  LazarusExe: string;
  ExpectedFPCExe: string;
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 11: ConfigureIDE Prefers Configured FPC Version When Registry Missing');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-configure-missing.json';
  try
    WriteCustomRegistryWithoutVersion(VersionsJSONPath);
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus configure registry without installed version reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.7-configure';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstallWithFPC('3.7', '3.0.4', CustomInstallPath);
    CreateMockFPCInstall('3.0.4', ExpectedFPCExe);

    Success := LazarusManager.ConfigureIDE('3.7');

    AssertTrue(Success, 'ConfigureIDE succeeds for registry-missing install with configured FPC version',
      'Expected ConfigureIDE(3.7) to succeed using configured FPC metadata');

    {$IFDEF MSWINDOWS}
    ConfigDir := ExcludeTrailingPathDelimiter(
      IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root'
    ) + PathDelim + 'lazarus-3.7';
    {$ELSE}
    ConfigDir := ExcludeTrailingPathDelimiter(
      IncludeTrailingPathDelimiter(TestRootDir) + 'lazarus-config-root'
    ) + PathDelim + '.lazarus-3.7';
    {$ENDIF}

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      AssertTrue(IDEConfig.GetCompilerPath = ExpectedFPCExe,
        'ConfigureIDE uses configured FPC version when registry omits version',
        'Expected compiler path "' + ExpectedFPCExe + '", got "' + IDEConfig.GetCompilerPath + '"');
    finally
      IDEConfig.Free;
    end;
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
  end;
end;

// ============================================================================
// Test 12: ListVersions prefers configured FPC version for installed registry version
// ============================================================================
procedure TestListVersionsPrefersConfiguredFPCVersionForInstalledVersion;
var
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 12: ListVersions Prefers Configured FPC Version For Installed Version');
  WriteLn('==================================================');

  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.6-list-fpc';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstallWithFPC('3.6', '9.9.9', CustomInstallPath);

    Success := LazarusManager.ListVersions(Outp, False);

    AssertTrue(Success, 'ListVersions succeeds for installed version with configured FPC metadata',
      'Expected ListVersions(False) to succeed for installed registry version');
    AssertTrue(Pos('3.6', OutBuf.Text) > 0,
      'ListVersions includes installed registry version with configured FPC metadata',
      OutBuf.Text);
    AssertTrue(Pos('9.9.9', OutBuf.Text) > 0,
      'ListVersions prints configured FPC version for installed registry version',
      OutBuf.Text);
  finally
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 13: ShowVersionInfo prefers configured FPC version for installed registry version
// ============================================================================
procedure TestShowVersionInfoPrefersConfiguredFPCVersionForInstalledVersion;
var
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13: ShowVersionInfo Prefers Configured FPC Version For Installed Version');
  WriteLn('==================================================');

  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.6-show-fpc';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstallWithFPC('3.6', '9.9.9', CustomInstallPath);

    Success := LazarusManager.ShowVersionInfo(Outp, '3.6');

    AssertTrue(Success, 'ShowVersionInfo succeeds for installed registry version with configured FPC metadata',
      'Expected ShowVersionInfo(3.6) to succeed');
    AssertTrue(Pos('Version:      3.6', OutBuf.Text) > 0,
      'ShowVersionInfo prints installed registry version',
      OutBuf.Text);
    AssertTrue(Pos('FPC Version:  9.9.9', OutBuf.Text) > 0,
      'ShowVersionInfo prints configured FPC version for installed registry version',
      OutBuf.Text);
  finally
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 14: ListVersions --all includes installed version missing from registry
// ============================================================================
procedure TestListAllIncludesInstalledVersionMissingFromRegistry;
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 14: ListVersions --all Includes Installed Version Missing From Registry');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-list-all-missing.json';
  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    WriteCustomRegistryWithoutVersion(VersionsJSONPath);
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus list-all registry without installed version reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.7-list-all';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.7', CustomInstallPath);

    Success := LazarusManager.ListVersions(Outp, True);

    AssertTrue(Success, 'ListVersions --all succeeds when installed version is missing from registry',
      'Expected ListVersions(True) to succeed');
    AssertTrue(Pos('3.7', OutBuf.Text) > 0,
      'ListVersions --all includes installed version missing from registry',
      OutBuf.Text);
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 15: ShowVersionInfo uses configured custom install path
// ============================================================================
procedure TestShowVersionInfoUsesConfiguredCustomInstallPath;
var
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 15: ShowVersionInfo Uses Configured Custom Install Path');
  WriteLn('==================================================');

  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.8-show-runtime';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.8', CustomInstallPath);

    Success := LazarusManager.ShowVersionInfo(Outp, '3.8');

    AssertTrue(Success, 'ShowVersionInfo succeeds for configured custom install path',
      'Expected ShowVersionInfo(3.8) to succeed for a configured custom install path');
    AssertTrue(Pos('Install Path: ' + CustomInstallPath, OutBuf.Text) > 0,
      'ShowVersionInfo prints configured custom install path',
      OutBuf.Text);
  finally
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 16: TestInstallation uses configured custom install path
// ============================================================================
procedure TestTestInstallationUsesConfiguredCustomInstallPath;
{$IFDEF UNIX}
var
  CustomInstallPath: string;
  LazarusExe: string;
  OutBuf: TStringList;
  ErrBuf: TStringList;
  Outp: IOutput;
  Errp: IOutput;
  Success: Boolean;
{$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16: TestInstallation Uses Configured Custom Install Path');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True, 'TestInstallation configured custom install path skipped on non-UNIX',
    'Runtime executable contract is only exercised on UNIX in this suite');
  Exit;
  {$ENDIF}

  OutBuf := TStringList.Create;
  ErrBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    Errp := TStringOutput.Create(ErrBuf);
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-3.9-test-runtime';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    RegisterLazarusInstall('3.9', CustomInstallPath);

    Success := LazarusManager.TestInstallation(Outp, Errp, '3.9');

    AssertTrue(Success, 'TestInstallation succeeds for configured custom install path',
      'Expected TestInstallation(3.9) to execute the configured custom install path');
    AssertTrue(Pos('3.9', OutBuf.Text) > 0,
      'TestInstallation reports configured custom install path version',
      OutBuf.Text);
    AssertTrue(Trim(ErrBuf.Text) = '',
      'TestInstallation keeps error output empty for configured custom install path',
      ErrBuf.Text);
  finally
    Outp := nil;
    Errp := nil;
    OutBuf.Free;
    ErrBuf.Free;
  end;
end;

// ============================================================================
// Test 17: LaunchIDE uses configured custom install path
// ============================================================================
procedure TestLaunchIDEUsesConfiguredCustomInstallPath;
{$IFDEF UNIX}
var
  CustomInstallPath: string;
  LazarusExe: string;
  LaunchMarkerPath: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
{$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 17: LaunchIDE Uses Configured Custom Install Path');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True, 'LaunchIDE configured custom install path skipped on non-UNIX',
    'Runtime executable contract is only exercised on UNIX in this suite');
  Exit;
  {$ENDIF}

  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-4.0-launch-runtime';
    LaunchMarkerPath := IncludeTrailingPathDelimiter(TestRootDir) + 'launch-4.0.marker';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    WriteMockLaunchExecutable(LazarusExe, 'Mock Lazarus Launch', LaunchMarkerPath);
    RegisterLazarusInstall('4.0', CustomInstallPath);

    Success := LazarusManager.LaunchIDE(Outp, '4.0');

    AssertTrue(Success, 'LaunchIDE succeeds for configured custom install path',
      'Expected LaunchIDE(4.0) to start the configured custom executable');
    AssertTrue(WaitForFile(LaunchMarkerPath),
      'LaunchIDE executes configured custom install path',
      'Expected launch marker file "' + LaunchMarkerPath + '" to be created');
    AssertTrue(Pos('4.0', OutBuf.Text) > 0,
      'LaunchIDE reports configured custom install path version',
      OutBuf.Text);
  finally
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Test 18: LaunchIDE uses default configured version missing from registry
// ============================================================================
procedure TestLaunchIDEUsesDefaultConfiguredVersionMissingFromRegistry;
{$IFDEF UNIX}
var
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomInstallPath: string;
  LazarusExe: string;
  LaunchMarkerPath: string;
  OutBuf: TStringList;
  Outp: IOutput;
  Success: Boolean;
{$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 18: LaunchIDE Uses Default Configured Version Missing From Registry');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True, 'LaunchIDE default configured version skipped on non-UNIX',
    'Runtime executable contract is only exercised on UNIX in this suite');
  Exit;
  {$ENDIF}

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-launch-default-missing.json';
  OutBuf := TStringList.Create;
  try
    Outp := TStringOutput.Create(OutBuf);
    WriteCustomRegistryWithoutVersion(VersionsJSONPath);
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus launch-default registry without installed version reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    CustomInstallPath := IncludeTrailingPathDelimiter(TestRootDir) + 'custom-lazarus-4.1-default-launch';
    LaunchMarkerPath := IncludeTrailingPathDelimiter(TestRootDir) + 'launch-4.1-default.marker';
    CreateMockLazarusInstallAtPath(CustomInstallPath, LazarusExe);
    WriteMockLaunchExecutable(LazarusExe, 'Mock Lazarus Default Launch', LaunchMarkerPath);
    RegisterLazarusInstall('4.1', CustomInstallPath);
    AssertTrue(ConfigManager.GetLazarusManager.SetDefaultLazarusVersion('lazarus-4.1'),
      'Setup default Lazarus version for launch test',
      'Expected lazarus-4.1 to become default before LaunchIDE('''')');

    Success := LazarusManager.LaunchIDE(Outp, '');

    AssertTrue(Success, 'LaunchIDE succeeds for default configured version missing from registry',
      'Expected LaunchIDE('''') to use the configured default version even when registry omits it');
    AssertTrue(WaitForFile(LaunchMarkerPath),
      'LaunchIDE executes default configured version missing from registry',
      'Expected launch marker file "' + LaunchMarkerPath + '" to be created');
    AssertTrue(Pos('4.1', OutBuf.Text) > 0,
      'LaunchIDE reports default configured version missing from registry',
      OutBuf.Text);
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Outp := nil;
    OutBuf.Free;
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Lazarus Configure Workflow Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestConfigManagerUsesIsolatedDefaultConfigPath;
      TestConfigureIDEFailsWhenNotInstalled;
      TestConfigureIDESucceedsWhenInstalled;
      TestConfigureIDECreatesConfigDir;
      TestConfigureIDECreatesBackup;
      TestConfigureIDEUsesConfiguredCustomInstallPath;
      TestConfigureIDEUsesSameProcessHomeWhenConfigRootUnset;
      TestUninstallVersionUsesConfiguredCustomInstallPath;
      TestUninstallVersionRemovesStaleConfiguredMetadata;
      TestUninstallVersionClearsDefaultVersion;
      TestListVersionsIncludesInstalledVersionMissingFromRegistry;
      TestShowVersionInfoSupportsInstalledVersionMissingFromRegistry;
      TestConfigureIDEPrefersConfiguredFPCVersionWhenRegistryMissing;
      TestListVersionsPrefersConfiguredFPCVersionForInstalledVersion;
      TestShowVersionInfoPrefersConfiguredFPCVersionForInstalledVersion;
      TestListAllIncludesInstalledVersionMissingFromRegistry;
      TestShowVersionInfoUsesConfiguredCustomInstallPath;
      TestTestInstallationUsesConfiguredCustomInstallPath;
      TestLaunchIDEUsesConfiguredCustomInstallPath;
      TestLaunchIDEUsesDefaultConfiguredVersionMissingFromRegistry;

      // Exit with error if any tests failed
      if TestsFailed > 0 then
        ExitCode := 1
      else
        ExitCode := 0;

    finally
      CleanupTestEnvironment;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite crashed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
