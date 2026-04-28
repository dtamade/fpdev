program test_lazarus_sourceruntimeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.lazarus.config,
  fpdev.lazarus.commandflow,
  fpdev.lazarus.sourceflow,
  fpdev.lazarus.sourceruntimeflow,
  test_temp_paths;

type
  TSourceRuntimeProbe = class
  public
    ValidSourceResult: Boolean;
    CommandResult: Boolean;
    LaunchResult: Boolean;
    ValidationCalls: Integer;
    CommandCalls: Integer;
    LaunchCalls: Integer;
    LastValidatedPath: string;
    LastExecutable: string;
    LastWorkingDir: string;
    LastLaunchPath: string;
    LastParams: TStringList;
    Logged: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AText: string);
    function IsValidSourceDirectory(const APath: string): Boolean;
    function CoreIsValidSourceDirectory(const APath: string): Boolean;
    function ExecuteCommand(const AExecutable: string;
      const AParams: array of string; const AWorkingDir: string): Boolean;
    function LaunchExecutable(const AExecutablePath: string): Boolean;
  end;

var
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
  Index: Integer;
begin
  ForceDirectories(ExtractFileDir(APath));
  Content := TStringList.Create;
  try
    for Index := Low(ALines) to High(ALines) do
      Content.Add(ALines[Index]);
    Content.SaveToFile(APath);
  finally
    Content.Free;
  end;
  {$IFDEF UNIX}
  FpChmod(APath, &755);
  {$ENDIF}
end;

constructor TSourceRuntimeProbe.Create;
begin
  inherited Create;
  LastParams := TStringList.Create;
  Logged := TStringList.Create;
  ValidSourceResult := True;
  CommandResult := True;
  LaunchResult := True;
end;

destructor TSourceRuntimeProbe.Destroy;
begin
  Logged.Free;
  LastParams.Free;
  inherited Destroy;
end;

procedure TSourceRuntimeProbe.Log(const AText: string);
begin
  Logged.Add(AText);
end;

function TSourceRuntimeProbe.IsValidSourceDirectory(const APath: string): Boolean;
begin
  Inc(ValidationCalls);
  LastValidatedPath := APath;
  Result := ValidSourceResult;
end;

function TSourceRuntimeProbe.CoreIsValidSourceDirectory(const APath: string): Boolean;
begin
  Result := IsValidLazarusLegacySourceTreeCore(APath);
end;

function TSourceRuntimeProbe.ExecuteCommand(const AExecutable: string;
  const AParams: array of string; const AWorkingDir: string): Boolean;
var
  Index: Integer;
begin
  Inc(CommandCalls);
  LastExecutable := AExecutable;
  LastWorkingDir := AWorkingDir;
  LastParams.Clear;
  for Index := Low(AParams) to High(AParams) do
    LastParams.Add(AParams[Index]);
  Result := CommandResult;
end;

function TSourceRuntimeProbe.LaunchExecutable(const AExecutablePath: string): Boolean;
begin
  Inc(LaunchCalls);
  LastLaunchPath := AExecutablePath;
  Result := LaunchResult;
end;

procedure TestConfigureLegacyLazarusCustomFPCIDEWritesConfig;
var
  TempRoot: string;
  ConfigRoot: string;
  SourcePath: string;
  FPCPath: string;
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_sourceruntime_config');
  ConfigRoot := TempRoot + PathDelim + 'config-root';
  SourcePath := TempRoot + PathDelim + 'lazarus-3.0';
  ForceDirectories(SourcePath + PathDelim + 'ide');
  ForceDirectories(SourcePath + PathDelim + 'lcl');
  ForceDirectories(SourcePath + PathDelim + 'packager');

  {$IFDEF MSWINDOWS}
  FPCPath := TempRoot + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCPath := TempRoot + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  WriteExecutableScript(FPCPath, ['#!/bin/sh', 'exit 0']);

  Check('source runtime config helper succeeds for valid custom compiler path',
    ConfigureLegacyLazarusCustomFPCIDECore(
      '3.0', SourcePath, FPCPath, ConfigRoot, '', '', nil
    ),
    'expected config helper success');

  ConfigDir := ResolveLazarusConfigDirCore('3.0', ConfigRoot, '', '');
  IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
  try
    Check('source runtime config helper writes compiler path',
      IDEConfig.GetCompilerPath = FPCPath,
      'compiler=' + IDEConfig.GetCompilerPath);
    Check('source runtime config helper writes source path',
      IDEConfig.GetLibraryPath = SourcePath,
      'library=' + IDEConfig.GetLibraryPath);
    Check('source runtime config helper produces valid config',
      IDEConfig.ValidateConfig,
      'config did not validate');
  finally
    IDEConfig.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestListLegacyLazarusLocalVersionsSkipsInvalidTrees;
var
  TempRoot: string;
  Versions: TStringArray;
  Probe: TSourceRuntimeProbe;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_sourceruntime_local');
  Probe := TSourceRuntimeProbe.Create;
  try
    ForceDirectories(TempRoot + PathDelim + 'lazarus-main' + PathDelim + 'ide');
    ForceDirectories(TempRoot + PathDelim + 'lazarus-main' + PathDelim + 'lcl');
    ForceDirectories(TempRoot + PathDelim + 'lazarus-main' + PathDelim + 'packager');
    ForceDirectories(TempRoot + PathDelim + 'lazarus-3.0');

    Versions := ListLegacyLazarusLocalVersionsCore(
      TempRoot,
      @Probe.CoreIsValidSourceDirectory
    );

    Check('source runtime local version helper keeps valid tree',
      (Length(Versions) = 1) and (Versions[0] = 'main'),
      'length=' + IntToStr(Length(Versions)));
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestExecuteLegacyLazarusBuildCoreRejectsInvalidSourceTree;
var
  Probe: TSourceRuntimeProbe;
begin
  Probe := TSourceRuntimeProbe.Create;
  try
    Probe.ValidSourceResult := False;

    Check('source runtime build helper rejects invalid source tree',
      not ExecuteLegacyLazarusBuildCore(
        '/tmp/invalid-lazarus', '/tmp/mock-fpc', 4,
        @Probe.IsValidSourceDirectory, @Probe.ExecuteCommand, @Probe.Log
      ),
      'expected failure');
    Check('source runtime build helper skips command execution on invalid tree',
      Probe.CommandCalls = 0,
      'calls=' + IntToStr(Probe.CommandCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLegacyLazarusBuildCoreRunsCommandForValidTree;
var
  Probe: TSourceRuntimeProbe;
begin
  Probe := TSourceRuntimeProbe.Create;
  try
    Probe.ValidSourceResult := True;
    Probe.CommandResult := True;

    Check('source runtime build helper succeeds for valid tree',
      ExecuteLegacyLazarusBuildCore(
        '/tmp/valid-lazarus', '/tmp/mock-fpc', 4,
        @Probe.IsValidSourceDirectory, @Probe.ExecuteCommand, @Probe.Log
      ),
      'expected success');
    Check('source runtime build helper executes make once',
      Probe.CommandCalls = 1,
      'calls=' + IntToStr(Probe.CommandCalls));
    Check('source runtime build helper forwards make executable',
      Probe.LastExecutable = 'make',
      Probe.LastExecutable);
    Check('source runtime build helper forwards working directory',
      Probe.LastWorkingDir = '/tmp/valid-lazarus',
      Probe.LastWorkingDir);
    Check('source runtime build helper includes clean target',
      Probe.LastParams.IndexOf('clean') >= 0,
      Probe.LastParams.Text);
    Check('source runtime build helper includes all target',
      Probe.LastParams.IndexOf('all') >= 0,
      Probe.LastParams.Text);
    Check('source runtime build helper includes parallel jobs',
      Probe.LastParams.IndexOf('-j4') >= 0,
      Probe.LastParams.Text);
    Check('source runtime build helper includes custom compiler path',
      Probe.LastParams.IndexOf('PP=/tmp/mock-fpc') >= 0,
      Probe.LastParams.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLegacyLazarusLaunchCoreRejectsMissingExecutable;
var
  Probe: TSourceRuntimeProbe;
begin
  Probe := TSourceRuntimeProbe.Create;
  try
    Check('source runtime launch helper rejects missing executable',
      not ExecuteLegacyLazarusLaunchCore(
        '/tmp/fpdev-missing-lazarus', @Probe.LaunchExecutable, @Probe.Log
      ),
      'expected failure');
    Check('source runtime launch helper skips launcher callback on missing executable',
      Probe.LaunchCalls = 0,
      'calls=' + IntToStr(Probe.LaunchCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLegacyLazarusLaunchCoreCallsLauncher;
var
  Probe: TSourceRuntimeProbe;
  TempRoot: string;
  ExecutablePath: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_sourceruntime_launch');
  Probe := TSourceRuntimeProbe.Create;
  try
    {$IFDEF MSWINDOWS}
    ExecutablePath := TempRoot + PathDelim + 'lazarus.exe';
    {$ELSE}
    ExecutablePath := TempRoot + PathDelim + 'lazarus';
    {$ENDIF}
    WriteExecutableScript(ExecutablePath, ['#!/bin/sh', 'exit 0']);

    Check('source runtime launch helper calls launcher for existing executable',
      ExecuteLegacyLazarusLaunchCore(
        ExecutablePath, @Probe.LaunchExecutable, @Probe.Log
      ),
      'expected success');
    Check('source runtime launch helper forwards executable path',
      Probe.LastLaunchPath = ExecutablePath,
      Probe.LastLaunchPath);
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestConfigureLegacyLazarusCustomFPCIDEWritesConfig;
  TestListLegacyLazarusLocalVersionsSkipsInvalidTrees;
  TestExecuteLegacyLazarusBuildCoreRejectsInvalidSourceTree;
  TestExecuteLegacyLazarusBuildCoreRunsCommandForValidTree;
  TestExecuteLegacyLazarusLaunchCoreRejectsMissingExecutable;
  TestExecuteLegacyLazarusLaunchCoreCallsLauncher;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
