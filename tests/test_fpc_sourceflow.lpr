program test_fpc_sourceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.types,
  fpdev.fpc.sourceflow,
  test_temp_paths;

type
  TSourceFlowProbe = class
  public
    CloneResult: Boolean;
    UpdateResult: Boolean;
    SwitchResult: Boolean;
    CommandResult: Boolean;
    ValidSourceResult: Boolean;
    UseCompilerDirCheck: Boolean;
    CloneCalls: Integer;
    UpdateCalls: Integer;
    SwitchCalls: Integer;
    CommandCalls: Integer;
    Statuses: TStringList;
    LastCloneVersion: string;
    LastUpdateVersion: string;
    LastSwitchVersion: string;
    LastCommandProgram: string;
    LastCommandArg0: string;
    constructor Create;
    destructor Destroy; override;
    function CloneSource(const AVersion: string): Boolean;
    function UpdateSource(const AVersion: string): Boolean;
    function SwitchVersion(const AVersion: string): Boolean;
    function ExecuteCommand(
      const AProgram: string;
      const AArgs: array of string;
      const AWorkingDir: string
    ): Boolean;
    function IsValidSourceDirectory(const APath: string): Boolean;
    procedure WriteStatus(const AText: string);
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

constructor TSourceFlowProbe.Create;
begin
  inherited Create;
  CloneResult := True;
  UpdateResult := True;
  SwitchResult := True;
  CommandResult := True;
  ValidSourceResult := True;
  Statuses := TStringList.Create;
end;

destructor TSourceFlowProbe.Destroy;
begin
  Statuses.Free;
  inherited Destroy;
end;

function TSourceFlowProbe.CloneSource(const AVersion: string): Boolean;
begin
  Inc(CloneCalls);
  LastCloneVersion := AVersion;
  Result := CloneResult;
end;

function TSourceFlowProbe.UpdateSource(const AVersion: string): Boolean;
begin
  Inc(UpdateCalls);
  LastUpdateVersion := AVersion;
  Result := UpdateResult;
end;

function TSourceFlowProbe.SwitchVersion(const AVersion: string): Boolean;
begin
  Inc(SwitchCalls);
  LastSwitchVersion := AVersion;
  Result := SwitchResult;
end;

function TSourceFlowProbe.ExecuteCommand(
  const AProgram: string;
  const AArgs: array of string;
  const AWorkingDir: string
): Boolean;
begin
  if AWorkingDir <> '' then;
  Inc(CommandCalls);
  LastCommandProgram := AProgram;
  if Length(AArgs) > 0 then
    LastCommandArg0 := AArgs[0]
  else
    LastCommandArg0 := '';
  Result := CommandResult;
end;

function TSourceFlowProbe.IsValidSourceDirectory(const APath: string): Boolean;
begin
  if UseCompilerDirCheck then
    Exit(DirectoryExists(APath + PathDelim + 'compiler'));
  if APath <> '' then;
  Result := ValidSourceResult;
end;

procedure TSourceFlowProbe.WriteStatus(const AText: string);
begin
  Statuses.Add(AText);
end;

procedure TestCloneUsesMainFallbackAndUpdatesCurrentVersion;
var
  Probe: TSourceFlowProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TSourceFlowProbe.Create;
  try
    CurrentVersion := '';
    OK := ExecuteFPCSourceCloneCore('', CurrentVersion, @Probe.CloneSource);

    Check('sourceflow clone succeeds with default main', OK, 'expected success');
    Check('sourceflow clone forwards normalized version',
      Probe.LastCloneVersion = 'main', Probe.LastCloneVersion);
    Check('sourceflow clone updates current version',
      CurrentVersion = 'main', CurrentVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestUpdateUsesCurrentVersionAndWritesSuccessStatus;
var
  Probe: TSourceFlowProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TSourceFlowProbe.Create;
  try
    CurrentVersion := '3.2.2';
    OK := ExecuteFPCSourceUpdateCore(
      '',
      CurrentVersion,
      @Probe.UpdateSource,
      @Probe.WriteStatus
    );

    Check('sourceflow update succeeds with current version fallback', OK, 'expected success');
    Check('sourceflow update forwards current version',
      Probe.LastUpdateVersion = '3.2.2', Probe.LastUpdateVersion);
    Check('sourceflow update keeps current version',
      CurrentVersion = '3.2.2', CurrentVersion);
    Check('sourceflow update writes success status',
      Probe.Statuses.IndexOf('[OK] FPC source updated successfully') >= 0,
      Probe.Statuses.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestUpdateFailureWritesFailureStatus;
var
  Probe: TSourceFlowProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TSourceFlowProbe.Create;
  try
    Probe.UpdateResult := False;
    CurrentVersion := 'main';

    OK := ExecuteFPCSourceUpdateCore(
      '3.2.0',
      CurrentVersion,
      @Probe.UpdateSource,
      @Probe.WriteStatus
    );

    Check('sourceflow update failure returns false', not OK, 'expected failure');
    Check('sourceflow update failure does not change current version',
      CurrentVersion = 'main', CurrentVersion);
    Check('sourceflow update failure writes failure status',
      Probe.Statuses.IndexOf('[FAIL] FPC source update failed') >= 0,
      Probe.Statuses.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestSwitchFailsFastWhenVersionNotInstalled;
var
  Probe: TSourceFlowProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TSourceFlowProbe.Create;
  try
    CurrentVersion := 'main';
    OK := ExecuteFPCSourceSwitchCore(
      '3.2.2',
      CurrentVersion,
      False,
      @Probe.SwitchVersion
    );

    Check('sourceflow switch rejects missing installed version', not OK, 'expected failure');
    Check('sourceflow switch skips repo switch when version missing',
      Probe.SwitchCalls = 0, IntToStr(Probe.SwitchCalls));
    Check('sourceflow switch keeps current version on failure',
      CurrentVersion = 'main', CurrentVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestSwitchUpdatesCurrentVersionOnSuccess;
var
  Probe: TSourceFlowProbe;
  CurrentVersion: string;
  OK: Boolean;
begin
  Probe := TSourceFlowProbe.Create;
  try
    CurrentVersion := 'main';
    OK := ExecuteFPCSourceSwitchCore(
      '3.2.2',
      CurrentVersion,
      True,
      @Probe.SwitchVersion
    );

    Check('sourceflow switch succeeds for installed version', OK, 'expected success');
    Check('sourceflow switch calls repo switch once',
      Probe.SwitchCalls = 1, IntToStr(Probe.SwitchCalls));
    Check('sourceflow switch updates current version',
      CurrentVersion = '3.2.2', CurrentVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestAvailableVersionsMergeRegistryAndFallback;
var
  Releases: TFPCReleaseArray;
  Versions: TStringArray;
begin
  SetLength(Releases, 2);
  Releases[0].Version := '3.2.2';
  Releases[1].Version := 'main';

  Versions := BuildAvailableFPCSourceVersionsCore(Releases);

  Check('sourceflow available versions keeps registry entry 1',
    (Length(Versions) >= 2) and (Versions[0] = '3.2.2'), 'unexpected first value');
  Check('sourceflow available versions keeps registry entry 2',
    (Length(Versions) >= 2) and (Versions[1] = 'main'), 'unexpected second value');
end;

procedure TestAvailableVersionsFallsBackToStaticWhenRegistryEmpty;
var
  Releases: TFPCReleaseArray;
  Versions: TStringArray;
begin
  SetLength(Releases, 0);
  Versions := BuildAvailableFPCSourceVersionsCore(Releases);

  Check('sourceflow available versions static fallback not empty',
    Length(Versions) > 0, 'expected static fallback');
  Check('sourceflow available versions static fallback includes main',
    (Length(Versions) > 0) and (Versions[0] = 'main'), 'first=' + Versions[0]);
end;

procedure TestLocalVersionsFilterValidSourceDirectories;
var
  TempRoot: string;
  Versions: TStringArray;
  Probe: TSourceFlowProbe;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourceflow_local_versions');
  Probe := TSourceFlowProbe.Create;
  try
    ForceDirectories(TempRoot + PathDelim + 'fpc-3.2.2' + PathDelim + 'compiler');
    ForceDirectories(TempRoot + PathDelim + 'fpc-main' + PathDelim + 'compiler');
    ForceDirectories(TempRoot + PathDelim + 'fpc-broken');
    ForceDirectories(TempRoot + PathDelim + 'docs');
    Probe.UseCompilerDirCheck := True;

    Versions := ListLocalFPCSourceVersionsCore(
      TempRoot,
      @Probe.IsValidSourceDirectory
    );

    Check('sourceflow local versions returns matching prefixes',
      Length(Versions) >= 2, 'count=' + IntToStr(Length(Versions)));
    Check('sourceflow local versions includes valid 3.2.2 tree',
      (Length(Versions) > 0) and ((Versions[0] = '3.2.2') or (Versions[1] = '3.2.2')),
      'missing 3.2.2');
    Check('sourceflow local versions filters invalid source tree',
      (Length(Versions) = 2), 'count=' + IntToStr(Length(Versions)));
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestCheckBuildPrerequisitesRequiresMakeAndBootstrap;
var
  Probe: TSourceFlowProbe;
  OK: Boolean;
begin
  Probe := TSourceFlowProbe.Create;
  try
    OK := CheckFPCSourceBuildPrerequisitesCore(
      '3.2.2',
      '/usr/bin/fpc',
      @Probe.ExecuteCommand
    );

    Check('sourceflow prereq succeeds when make and bootstrap exist', OK, 'expected success');
    Check('sourceflow prereq probes make version once',
      (Probe.CommandCalls = 1) and (Probe.LastCommandProgram = 'make') and
      (Probe.LastCommandArg0 = '--version'),
      Probe.LastCommandProgram + ' ' + Probe.LastCommandArg0);

    Probe.CommandResult := False;
    OK := CheckFPCSourceBuildPrerequisitesCore(
      '3.2.2',
      '/usr/bin/fpc',
      @Probe.ExecuteCommand
    );
    Check('sourceflow prereq fails when make probe fails', not OK, 'expected failure');

    OK := CheckFPCSourceBuildPrerequisitesCore(
      '3.2.2',
      '',
      @Probe.ExecuteCommand
    );
    Check('sourceflow prereq fails when bootstrap compiler missing', not OK, 'expected failure');
  finally
    Probe.Free;
  end;
end;

begin
  TestCloneUsesMainFallbackAndUpdatesCurrentVersion;
  TestUpdateUsesCurrentVersionAndWritesSuccessStatus;
  TestUpdateFailureWritesFailureStatus;
  TestSwitchFailsFastWhenVersionNotInstalled;
  TestSwitchUpdatesCurrentVersionOnSuccess;
  TestAvailableVersionsMergeRegistryAndFallback;
  TestAvailableVersionsFallsBackToStaticWhenRegistryEmpty;
  TestLocalVersionsFilterValidSourceDirectories;
  TestCheckBuildPrerequisitesRequiresMakeAndBootstrap;

  if FailCount > 0 then
    Halt(1);
end.
