program test_fpc_manager_installmetadata;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.fpc.manager, fpdev.fpc.metadata, fpdev.fpc.metadataflow, fpdev.fpc.types,
  fpdev.types, fpdev.paths, fpdev.utils, test_temp_paths, test_fpc_mock_helpers;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  FPCManager: TFPCManager;
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;


procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  TestRootDir := CreateUniqueTempDir('test_fpc_manager_installmetadata');
  set_env('FPDEV_DATA_ROOT', TestRootDir);

  ConfigManager := TConfigManager.Create(TestRootDir + PathDelim + 'config.json');
  ConfigManager.CreateDefaultConfig;
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);

  FPCManager := TFPCManager.Create(ConfigManager);
end;

procedure CleanupTestEnvironment;
begin
  if Assigned(FPCManager) then
    FreeAndNil(FPCManager);
  ConfigManager := nil;
  unset_env('FPDEV_DATA_ROOT');
  if TestRootDir <> '' then
    CleanupTempDir(TestRootDir);
end;

procedure TestInstallVersionRefreshesMetadataForExistingInstall;
var
  InstallDir: string;
  FPCExecutable: string;
  MetaPath: string;
  Meta: TFPDevMetadata;
begin
  InstallDir := BuildFPCInstallDirFromInstallRoot(TestRootDir, '3.2.2');
  ForceDirectories(InstallDir + PathDelim + 'bin');

  {$IFDEF MSWINDOWS}
  FPCExecutable := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExecutable := InstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  CompileMockFPCBinary(FPCExecutable);

  MetaPath := GetMetadataPath(InstallDir);
  if FileExists(MetaPath) then
    DeleteFile(MetaPath);

  Check('install short-circuit succeeds',
    FPCManager.InstallVersion('3.2.2'),
    'InstallVersion returned false for existing compiler');
  Check('install short-circuit writes metadata', FileExists(MetaPath),
    'missing ' + MetaPath);
  Check('install short-circuit metadata is readable',
    FPCManager.ReadMetadata(InstallDir, Meta),
    'ReadMetadata returned false');
  Check('install short-circuit metadata verify ok',
    Meta.Verify.OK,
    'verify.ok was false');
  Check('install short-circuit metadata detected version',
    Meta.Verify.DetectedVersion = '3.2.2',
    'detected=' + Meta.Verify.DetectedVersion);
  Check('install short-circuit metadata smoke test passed',
    Meta.Verify.SmokeTestPassed,
    'smoke test flag was false');
  Check('install short-circuit metadata timestamp set',
    Meta.Verify.Timestamp > 0,
    'timestamp was zero');
end;

procedure TestBuildInstallMetadataCoreCapturesSourceOrigin;
var
  Meta: TFPDevMetadata;
  InstalledAt: TDateTime;
begin
  InstalledAt := EncodeDateTime(2026, 4, 10, 12, 30, 0, 0);
  Meta := BuildFPCInstallMetadataCore(
    '3.2.2',
    TestRootDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2',
    'stable',
    'https://gitlab.example/fpc.git',
    True,
    isProject,
    InstalledAt
  );

  Check('metadata core stores version',
    Meta.Version = '3.2.2',
    'version=' + Meta.Version);
  Check('metadata core stores scope',
    Meta.Scope = isProject,
    'scope mismatch');
  Check('metadata core stores source mode',
    Meta.SourceMode = smSource,
    'source mode mismatch');
  Check('metadata core stores channel',
    Meta.Channel = 'stable',
    'channel=' + Meta.Channel);
  Check('metadata core stores expanded prefix',
    Meta.Prefix = ExpandFileName(TestRootDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2'),
    'prefix=' + Meta.Prefix);
  Check('metadata core stores source origin repo',
    Meta.Origin.RepoURL = 'https://gitlab.example/fpc.git',
    'repo=' + Meta.Origin.RepoURL);
  Check('metadata core marks source origin',
    Meta.Origin.BuiltFromSource,
    'built_from_source was false');
  Check('metadata core keeps install timestamp',
    Meta.InstalledAt = InstalledAt,
    'timestamp mismatch');
end;

procedure TestApplyVerificationMetadataCoreFillsMissingFields;
var
  ExistingMeta: TFPDevMetadata;
  UpdatedMeta: TFPDevMetadata;
  VerifResult: TVerificationResult;
  VerifyTimestamp: TDateTime;
  InstallPath: string;
begin
  InstallPath := TestRootDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';
  VerifyTimestamp := EncodeDateTime(2026, 4, 10, 13, 45, 0, 0);

  Initialize(ExistingMeta);
  ExistingMeta.Origin.RepoURL := 'https://gitlab.example/fpc.git';
  ExistingMeta.Origin.BuiltFromSource := True;

  Initialize(VerifResult);
  VerifResult.Verified := True;
  VerifResult.DetectedVersion := '3.2.2';
  VerifResult.SmokeTestPassed := True;

  UpdatedMeta := ApplyFPCVerificationMetadataCore(
    ExistingMeta,
    False,
    '3.2.2',
    InstallPath,
    'stable',
    isUser,
    VerifResult,
    VerifyTimestamp
  );

  Check('verification core fills version',
    UpdatedMeta.Version = '3.2.2',
    'version=' + UpdatedMeta.Version);
  Check('verification core fills scope when metadata missing',
    UpdatedMeta.Scope = isUser,
    'scope mismatch');
  Check('verification core fills channel when metadata missing',
    UpdatedMeta.Channel = 'stable',
    'channel=' + UpdatedMeta.Channel);
  Check('verification core fills prefix when metadata missing',
    UpdatedMeta.Prefix = ExpandFileName(InstallPath),
    'prefix=' + UpdatedMeta.Prefix);
  Check('verification core preserves existing origin repo',
    UpdatedMeta.Origin.RepoURL = 'https://gitlab.example/fpc.git',
    'repo=' + UpdatedMeta.Origin.RepoURL);
  Check('verification core preserves existing source flag',
    UpdatedMeta.Origin.BuiltFromSource,
    'built_from_source was false');
  Check('verification core writes verify timestamp',
    UpdatedMeta.Verify.Timestamp = VerifyTimestamp,
    'verify timestamp mismatch');
  Check('verification core writes verify ok flag',
    UpdatedMeta.Verify.OK,
    'verify.ok was false');
  Check('verification core writes detected version',
    UpdatedMeta.Verify.DetectedVersion = '3.2.2',
    'detected=' + UpdatedMeta.Verify.DetectedVersion);
  Check('verification core writes smoke test status',
    UpdatedMeta.Verify.SmokeTestPassed,
    'smoke test flag was false');
end;

begin
  WriteLn('=== FPC Manager Install Metadata Tests ===');

  InitTestEnvironment;
  try
    TestBuildInstallMetadataCoreCapturesSourceOrigin;
    TestApplyVerificationMetadataCoreFillsMissingFields;
    TestInstallVersionRefreshesMetadataForExistingInstall;
  finally
    CleanupTestEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
