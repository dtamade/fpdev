program test_fpc_manager_setupenvironment;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, BaseUnix,
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.fpc.manager, fpdev.fpc.types, fpdev.utils, fpdev.utils.fs,
  fpdev.utils.process, fpdev.fpc.installer.config,
  test_temp_paths;

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

procedure WriteExecutableScript(const APath: string; const ALines: array of string);
var
  Content: TStringList;
  I: Integer;
begin
  ForceDirectories(ExtractFileDir(APath));
  Content := TStringList.Create;
  try
    for I := Low(ALines) to High(ALines) do
      Content.Add(ALines[I]);
    Content.SaveToFile(APath);
  finally
    Content.Free;
  end;
  FpChmod(APath, &755);
end;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  TestRootDir := CreateUniqueTempDir('test_fpc_manager_setupenv');
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

procedure TestSetupEnvironmentRepairsRawSourceInstallLayout;
var
  InstallDir: string;
  BinDir: string;
  LibDir: string;
  CompilerName: string;
  ResultInfo: TToolchainInfo;
  ProcResult: TProcessResult;
  WrapperContent: string;
  Content: TStringList;
begin
  InstallDir := TestRootDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';
  BinDir := InstallDir + PathDelim + 'bin';
  LibDir := InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2';
  CompilerName := GetNativeCompilerName;

  ForceDirectories(BinDir);
  ForceDirectories(LibDir);

  WriteExecutableScript(BinDir + PathDelim + 'fpc', [
    '#!/bin/sh',
    'echo "raw source fpc"'
  ]);
  WriteExecutableScript(LibDir + PathDelim + CompilerName, [
    '#!/bin/sh',
    'for arg in "$@"; do',
    '  if [ "$arg" = "-iV" ]; then',
    '    echo "3.2.2"',
    '    exit 0',
    '  fi',
    'done',
    'echo "fake compiler"',
    'exit 0'
  ]);

  Check('setup environment succeeds on raw source layout',
    FPCManager.SetupEnvironment('3.2.2', InstallDir), 'SetupEnvironment returned false');
  Check('setup environment creates compiler symlink',
    FileExists(BinDir + PathDelim + CompilerName),
    'missing ' + CompilerName + ' under bin');
  Check('setup environment creates fpc.cfg',
    FileExists(BinDir + PathDelim + 'fpc.cfg'), 'missing fpc.cfg');
  Check('setup environment preserves original fpc as backup',
    FileExists(BinDir + PathDelim + 'fpc.orig'), 'missing fpc.orig');

  Content := TStringList.Create;
  try
    Content.LoadFromFile(BinDir + PathDelim + 'fpc');
    WrapperContent := Content.Text;
  finally
    Content.Free;
  end;
  Check('setup environment replaces fpc with wrapper script',
    Pos('#!/bin/sh', WrapperContent) > 0, 'wrapper script missing shebang');
  Check('setup environment wrapper points at generated config',
    Pos('fpc.cfg', WrapperContent) > 0, 'wrapper missing fpc.cfg reference');
  Check('setup environment wrapper points at native compiler',
    Pos(CompilerName, WrapperContent) > 0, 'wrapper missing native compiler');

  ProcResult := TProcessExecutor.Execute(BinDir + PathDelim + 'fpc', ['-iV'], '');
  Check('repaired wrapper resolves to managed compiler',
    ProcResult.Success and (Trim(ProcResult.StdOut) = '3.2.2'),
    'stdout=' + Trim(ProcResult.StdOut) + ' stderr=' + Trim(ProcResult.StdErr));

  Check('setup environment registers toolchain',
    ConfigManager.GetToolchainManager.GetToolchain('fpc-3.2.2', ResultInfo),
    'toolchain not registered');
  if ResultInfo.Version <> '' then
  begin
    Check('registered toolchain keeps expected version',
      ResultInfo.Version = '3.2.2', 'version=' + ResultInfo.Version);
    Check('registered toolchain keeps install path',
      ResultInfo.InstallPath = InstallDir, 'path=' + ResultInfo.InstallPath);
  end;
end;

procedure TestSetupEnvironmentRepairsRawLayoutWhenBinCompilerAlreadyExists;
var
  InstallDir: string;
  BinDir: string;
  LibDir: string;
  CompilerName: string;
  ProcResult: TProcessResult;
  WrapperContent: string;
  Content: TStringList;
begin
  InstallDir := TestRootDir + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.3';
  BinDir := InstallDir + PathDelim + 'bin';
  LibDir := InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.3';
  CompilerName := GetNativeCompilerName;

  ForceDirectories(BinDir);
  ForceDirectories(LibDir);

  WriteExecutableScript(BinDir + PathDelim + 'fpc', [
    '#!/bin/sh',
    'echo "raw source fpc"'
  ]);
  WriteExecutableScript(BinDir + PathDelim + CompilerName, [
    '#!/bin/sh',
    'echo "stale bin compiler"'
  ]);
  WriteExecutableScript(LibDir + PathDelim + CompilerName, [
    '#!/bin/sh',
    'for arg in "$@"; do',
    '  if [ "$arg" = "-iV" ]; then',
    '    echo "3.2.3"',
    '    exit 0',
    '  fi',
    'done',
    'echo "managed compiler"',
    'exit 0'
  ]);

  Check('setup environment succeeds when bin compiler already exists',
    FPCManager.SetupEnvironment('3.2.3', InstallDir), 'SetupEnvironment returned false');
  Check('setup environment creates backup even when bin compiler already exists',
    FileExists(BinDir + PathDelim + 'fpc.orig'), 'missing fpc.orig');
  Check('setup environment creates config even when bin compiler already exists',
    FileExists(BinDir + PathDelim + 'fpc.cfg'), 'missing fpc.cfg');

  Content := TStringList.Create;
  try
    Content.LoadFromFile(BinDir + PathDelim + 'fpc');
    WrapperContent := Content.Text;
  finally
    Content.Free;
  end;
  Check('setup environment still replaces fpc with wrapper when bin compiler already exists',
    Pos('fpc.cfg', WrapperContent) > 0,
    'wrapper missing managed config reference');
  Check('setup environment wrapper still points at native compiler when bin compiler already exists',
    Pos(CompilerName, WrapperContent) > 0,
    'wrapper missing native compiler reference');

  ProcResult := TProcessExecutor.Execute(BinDir + PathDelim + 'fpc', ['-iV'], '');
  Check('repaired wrapper overrides stale bin compiler and resolves managed compiler',
    ProcResult.Success and (Trim(ProcResult.StdOut) = '3.2.3'),
    'stdout=' + Trim(ProcResult.StdOut) + ' stderr=' + Trim(ProcResult.StdErr));
end;

begin
  WriteLn('=== FPC Manager SetupEnvironment Tests ===');

  InitTestEnvironment;
  try
    TestSetupEnvironmentRepairsRawSourceInstallLayout;
    TestSetupEnvironmentRepairsRawLayoutWhenBinCompilerAlreadyExists;
  finally
    CleanupTestEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
