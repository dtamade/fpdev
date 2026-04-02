program test_fpc_manager_installmetadata;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.fpc.manager, fpdev.fpc.metadata, fpdev.fpc.types,
  fpdev.paths, fpdev.utils, test_temp_paths;

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

procedure CompileMockFPCBinary(const ATargetPath: string);
var
  MockFPCSource: string;
  CompileProcess: TProcess;
begin
  MockFPCSource := ExpandFileName(
    ExtractFileDir(ParamStr(0)) + PathDelim + '..' + PathDelim + 'tests' +
    PathDelim + 'mock_fpc.pas'
  );

  ForceDirectories(ExtractFileDir(ATargetPath));
  CompileProcess := TProcess.Create(nil);
  try
    CompileProcess.Executable := 'fpc';
    CompileProcess.Parameters.Add('-o' + ATargetPath);
    CompileProcess.Parameters.Add(MockFPCSource);
    CompileProcess.Options := CompileProcess.Options + [poWaitOnExit];
    CompileProcess.Execute;

    if CompileProcess.ExitStatus <> 0 then
      raise Exception.Create('Failed to compile mock FPC executable');
  finally
    CompileProcess.Free;
  end;
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

begin
  WriteLn('=== FPC Manager Install Metadata Tests ===');

  InitTestEnvironment;
  try
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
