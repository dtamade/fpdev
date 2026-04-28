program test_build_runtimeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  test_temp_paths,
  fpdev.build.config,
  fpdev.build.runtimeflow,
  fpdev.utils.process;

type
  TBuildRuntimeHarness = class
  public
    ProbeResults: TStringList;
    Logged: TStringList;
    Summaries: TStringList;
    EnsuredDirs: TStringList;
    RunDirectCalls: TStringList;
    WrittenStampLines: TStringList;
    ResolvedMakeCmd: string;
    FindExecutableResult: string;
    VersionProbeSuccess: Boolean;
    VersionProbeError: string;
    RunSuccess: Boolean;
    RunExitCode: Integer;
    RunError: string;
    RaiseOnWrite: Boolean;
    WrittenStampPath: string;
    constructor Create;
    destructor Destroy; override;
    function ProbeTool(const ACmd, AProbeArg: string; out AOk: Boolean; out ALine: string): Boolean;
    procedure LogLine(const ALine: string);
    procedure LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
    procedure EnsureDir(const APath: string);
    function ResolveMakeCmd: string;
    function FindExecutable(const AName: string): string;
    function RunDirect(const AExecutable: string; const AParams: array of string; const AWorkDir: string): TProcessResult;
    procedure WriteStamp(const AFilePath: string; const ALines: TStringArray);
    procedure SetProbeResult(const ACmd: string; AOk: Boolean);
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

constructor TBuildRuntimeHarness.Create;
begin
  inherited Create;
  ProbeResults := TStringList.Create;
  Logged := TStringList.Create;
  Summaries := TStringList.Create;
  EnsuredDirs := TStringList.Create;
  RunDirectCalls := TStringList.Create;
  WrittenStampLines := TStringList.Create;
  ResolvedMakeCmd := 'make';
  VersionProbeSuccess := True;
  RunSuccess := True;
  RunExitCode := 0;
end;

destructor TBuildRuntimeHarness.Destroy;
begin
  WrittenStampLines.Free;
  RunDirectCalls.Free;
  EnsuredDirs.Free;
  Summaries.Free;
  Logged.Free;
  ProbeResults.Free;
  inherited Destroy;
end;

procedure TBuildRuntimeHarness.SetProbeResult(const ACmd: string; AOk: Boolean);
begin
  if AOk then
    ProbeResults.Values[ACmd] := '1'
  else
    ProbeResults.Values[ACmd] := '0';
end;

function TBuildRuntimeHarness.ProbeTool(const ACmd, AProbeArg: string; out AOk: Boolean; out ALine: string): Boolean;
var
  Value: string;
begin
  if AProbeArg = '' then;
  Value := ProbeResults.Values[ACmd];
  AOk := SameText(Value, '1');
  if AOk then
    ALine := '[ OK ] ' + ACmd
  else
    ALine := '[MISS] ' + ACmd;
  Result := AOk;
end;

procedure TBuildRuntimeHarness.LogLine(const ALine: string);
begin
  Logged.Add(ALine);
end;

procedure TBuildRuntimeHarness.LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  Summaries.Add(AVersion + '|' + AContext + '|' + AResult + '|' + IntToStr(AElapsedMs));
end;

procedure TBuildRuntimeHarness.EnsureDir(const APath: string);
begin
  EnsuredDirs.Add(APath);
end;

function TBuildRuntimeHarness.ResolveMakeCmd: string;
begin
  Result := ResolvedMakeCmd;
end;

function TBuildRuntimeHarness.FindExecutable(const AName: string): string;
begin
  if AName = '' then;
  Result := FindExecutableResult;
end;

function JoinParams(const AExecutable, AWorkDir: string; const AParams: array of string): string;
var
  I: Integer;
begin
  Result := AExecutable + '|' + AWorkDir;
  for I := Low(AParams) to High(AParams) do
    Result := Result + '|' + AParams[I];
end;

function TBuildRuntimeHarness.RunDirect(const AExecutable: string; const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  RunDirectCalls.Add(JoinParams(AExecutable, AWorkDir, AParams));
  Result := Default(TProcessResult);
  if (Length(AParams) = 1) and (AParams[0] = '--version') then
  begin
    Result.Success := VersionProbeSuccess;
    if not VersionProbeSuccess then
    begin
      Result.ExitCode := 1;
      Result.ErrorMessage := VersionProbeError;
    end;
    Exit;
  end;

  Result.Success := RunSuccess;
  Result.ExitCode := RunExitCode;
  Result.ErrorMessage := RunError;
end;

procedure TBuildRuntimeHarness.WriteStamp(const AFilePath: string; const ALines: TStringArray);
var
  I: Integer;
begin
  if RaiseOnWrite then
    raise Exception.Create('stamp write boom');

  WrittenStampPath := AFilePath;
  WrittenStampLines.Clear;
  for I := 0 to High(ALines) do
    WrittenStampLines.Add(ALines[I]);
end;

procedure TestExecuteBuildManagerToolchainCheckCoreSuccess;
var
  Harness: TBuildRuntimeHarness;
  OK: Boolean;
begin
  Harness := TBuildRuntimeHarness.Create;
  try
    Harness.SetProbeResult('fpc', True);
    Harness.SetProbeResult('lazbuild', True);
    Harness.SetProbeResult('gmake', True);
    Harness.SetProbeResult('git', True);
    Harness.SetProbeResult('openssl', True);

    OK := ExecuteBuildManagerToolchainCheckCore(
      1,
      @Harness.ProbeTool,
      @Harness.LogLine,
      @Harness.LogSummary
    );

    Check('toolchain runtimeflow returns true when required tools exist', OK, 'expected success');
    Check('toolchain runtimeflow logs start banner',
      Pos('== Toolchain Check START', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
    Check('toolchain runtimeflow logs end ok banner',
      Pos('== Toolchain Check END OK', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
    Check('toolchain runtimeflow records summary',
      Pos('n/a|toolchain|OK|', Harness.Summaries.Text) > 0,
      Harness.Summaries.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerToolchainCheckCoreFailureLogsIssues;
var
  Harness: TBuildRuntimeHarness;
  OK: Boolean;
begin
  Harness := TBuildRuntimeHarness.Create;
  try
    Harness.SetProbeResult('fpc', False);
    Harness.SetProbeResult('lazbuild', True);
    Harness.SetProbeResult('gmake', False);
    Harness.SetProbeResult('make', False);
    Harness.SetProbeResult('git', True);
    Harness.SetProbeResult('openssl', False);

    OK := ExecuteBuildManagerToolchainCheckCore(
      1,
      @Harness.ProbeTool,
      @Harness.LogLine,
      @Harness.LogSummary
    );

    Check('toolchain runtimeflow returns false when required tools missing', not OK, 'expected failure');
    Check('toolchain runtimeflow logs fail banner',
      Pos('== Toolchain Check END FAIL issues=', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
    Check('toolchain runtimeflow logs missing tool details in verbose mode',
      Pos('issue: [MISS] fpc', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
    Check('toolchain runtimeflow records fail summary',
      Pos('n/a|toolchain|FAIL|', Harness.Summaries.Text) > 0,
      Harness.Summaries.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestApplyBuildManagerConfigCoreCopiesArraysAndEnsuresDirs;
var
  Config: TBuildConfig;
  State: TBuildRuntimeConfigState;
  Harness: TBuildRuntimeHarness;
begin
  Harness := TBuildRuntimeHarness.Create;
  try
    Config := TBuildConfig.Default;
    Config.SourceRoot := '/tmp/source-root';
    Config.SandboxRoot := '/tmp/build-sandbox';
    Config.LogDir := '/tmp/build-logs';
    Config.ParallelJobs := 8;
    Config.Verbose := True;
    Config.AllowInstall := True;
    Config.DryRun := True;
    Config.StrictResults := True;
    Config.StrictConfigPath := '/tmp/strict.ini';
    Config.ToolchainStrict := True;
    Config.LogVerbosity := 1;
    Config.MakeCmd := 'gmake';
    Config.CpuTarget := 'x86_64';
    Config.OsTarget := 'linux';
    Config.Prefix := '/opt/fpc';
    Config.InstallPrefix := '/opt/fpc/install';
    SetLength(Config.SelectedPackages, 2);
    Config.SelectedPackages[0] := 'rtl';
    Config.SelectedPackages[1] := 'fcl-base';
    SetLength(Config.SkippedPackages, 1);
    Config.SkippedPackages[0] := 'fcl-web';

    State := Default(TBuildRuntimeConfigState);
    ApplyBuildManagerConfigCore(Config, State, @Harness.EnsureDir, @Harness.LogLine);

    Check('apply config runtimeflow updates source root', State.SourceRoot = Config.SourceRoot, State.SourceRoot);
    Check('apply config runtimeflow updates sandbox root', State.SandboxRoot = Config.SandboxRoot, State.SandboxRoot);
    Check('apply config runtimeflow updates log dir', State.LogDir = Config.LogDir, State.LogDir);
    Check('apply config runtimeflow copies selected packages', Length(State.SelectedPackages) = 2,
      'selected count=' + IntToStr(Length(State.SelectedPackages)));
    Check('apply config runtimeflow copies skipped packages', Length(State.SkippedPackages) = 1,
      'skipped count=' + IntToStr(Length(State.SkippedPackages)));
    Check('apply config runtimeflow ensures sandbox root', Harness.EnsuredDirs.IndexOf('/tmp/build-sandbox') >= 0,
      Harness.EnsuredDirs.Text);
    Check('apply config runtimeflow ensures log dir', Harness.EnsuredDirs.IndexOf('/tmp/build-logs') >= 0,
      Harness.EnsuredDirs.Text);
    Check('apply config runtimeflow logs completion',
      Pos('Configuration applied from TBuildConfig', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerRunMakeCoreDryRun;
var
  Harness: TBuildRuntimeHarness;
  TempRoot: string;
  Jobs: Integer;
  LastError: string;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('build-runtimeflow-dryrun');
  Harness := TBuildRuntimeHarness.Create;
  try
    Jobs := 4;
    OK := ExecuteBuildManagerRunMakeCore(
      TempRoot,
      ['compiler'],
      Jobs,
      '',
      '',
      '',
      '',
      '',
      '',
      False,
      True,
      1,
      'logs/build.log',
      @Harness.ResolveMakeCmd,
      @Harness.FindExecutable,
      @Harness.RunDirect,
      @Harness.LogLine,
      LastError
    );

    Check('runmake runtimeflow dry-run returns true', OK, 'expected success');
    Check('runmake runtimeflow dry-run skips process execution', Harness.RunDirectCalls.Count = 0,
      'calls=' + IntToStr(Harness.RunDirectCalls.Count));
    Check('runmake runtimeflow dry-run logs skip',
      Pos('dry-run: skipped make execution', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerRunMakeCoreReportsProbeFailure;
var
  Harness: TBuildRuntimeHarness;
  TempRoot: string;
  Jobs: Integer;
  LastError: string;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('build-runtimeflow-probe-fail');
  Harness := TBuildRuntimeHarness.Create;
  try
    Jobs := 2;
    Harness.FindExecutableResult := '/usr/bin/make';
    Harness.VersionProbeSuccess := False;
    Harness.VersionProbeError := 'permission denied';

    OK := ExecuteBuildManagerRunMakeCore(
      TempRoot,
      ['compiler'],
      Jobs,
      '',
      '',
      '',
      '',
      '',
      '',
      False,
      False,
      1,
      'logs/build.log',
      @Harness.ResolveMakeCmd,
      @Harness.FindExecutable,
      @Harness.RunDirect,
      @Harness.LogLine,
      LastError
    );

    Check('runmake runtimeflow returns false when version probe fails', not OK, 'expected failure');
    Check('runmake runtimeflow surfaces probe error message',
      Pos('Failed to execute make (/usr/bin/make): permission denied', LastError) = 1,
      LastError);
    Check('runmake runtimeflow only runs probe when probe fails', Harness.RunDirectCalls.Count = 1,
      'calls=' + IntToStr(Harness.RunDirectCalls.Count));
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerRunMakeCoreExecutesVerboseArgs;
var
  Harness: TBuildRuntimeHarness;
  TempRoot: string;
  Jobs: Integer;
  LastError: string;
  OK: Boolean;
  RunLine: string;
begin
  TempRoot := CreateUniqueTempDir('build-runtimeflow-run');
  Harness := TBuildRuntimeHarness.Create;
  try
    Jobs := 32;
    Harness.FindExecutableResult := '/usr/bin/gmake';
    Harness.ResolvedMakeCmd := 'gmake';

    OK := ExecuteBuildManagerRunMakeCore(
      TempRoot,
      ['clean', 'compiler'],
      Jobs,
      'x86_64',
      'linux',
      '/opt/fpc',
      '/opt/fpc/install',
      '/tmp/bootstrap/fpc',
      '-XPx86_64-linux-',
      True,
      False,
      1,
      'logs/build.log',
      @Harness.ResolveMakeCmd,
      @Harness.FindExecutable,
      @Harness.RunDirect,
      @Harness.LogLine,
      LastError
    );

    RunLine := Harness.RunDirectCalls[Harness.RunDirectCalls.Count - 1];
    Check('runmake runtimeflow succeeds with real execution', OK, LastError);
    Check('runmake runtimeflow clamps parallel jobs to 16', Jobs = 16,
      'jobs=' + IntToStr(Jobs));
    Check('runmake runtimeflow probes and runs make', Harness.RunDirectCalls.Count = 2,
      'calls=' + IntToStr(Harness.RunDirectCalls.Count));
    Check('runmake runtimeflow forwards -C working dir arg',
      Pos('|-C|' + TempRoot + '|-j16|', RunLine) > 0,
      RunLine);
    Check('runmake runtimeflow forwards target variables',
      (Pos('|CPU_TARGET=x86_64|', RunLine) > 0) and
      (Pos('|OS_TARGET=linux|', RunLine) > 0) and
      (Pos('|PREFIX=/opt/fpc|', RunLine) > 0) and
      (Pos('|INSTALL_PREFIX=/opt/fpc/install|', RunLine) > 0) and
      (Pos('|PP=/tmp/bootstrap/fpc|', RunLine) > 0) and
      (Pos('|CROSSOPT=-XPx86_64-linux-|', RunLine) > 0),
      RunLine);
    Check('runmake runtimeflow appends verbose args',
      (Pos('|VERBOSE=1|', RunLine) > 0) and (Pos('|OPT="-O2"', RunLine) > 0),
      RunLine);
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

procedure TestCreateBuildManagerStampCoreWritesStampAndLogs;
var
  Harness: TBuildRuntimeHarness;
  TempRoot: string;
begin
  TempRoot := CreateUniqueTempDir('build-runtimeflow-stamp');
  Harness := TBuildRuntimeHarness.Create;
  try
    CreateBuildManagerStampCore(
      TempRoot,
      '3.2.2',
      EncodeDateTime(2026, 4, 14, 9, 30, 0, 0),
      @Harness.EnsureDir,
      @Harness.WriteStamp,
      @Harness.LogLine
    );

    Check('stamp runtimeflow writes path', Harness.WrittenStampPath <> '', 'path missing');
    Check('stamp runtimeflow ensures sandbox dir', Harness.EnsuredDirs.IndexOf(TempRoot) >= 0,
      Harness.EnsuredDirs.Text);
    Check('stamp runtimeflow writes version line',
      Harness.WrittenStampLines.IndexOf('version=3.2.2') >= 0,
      Harness.WrittenStampLines.Text);
    Check('stamp runtimeflow writes timestamp line',
      Harness.WrittenStampLines.IndexOf('timestamp=2026-04-14 09:30:00') >= 0,
      Harness.WrittenStampLines.Text);
    Check('stamp runtimeflow logs created path',
      Pos('Created build stamp: ', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

procedure TestCreateBuildManagerStampCoreSwallowsWriterException;
var
  Harness: TBuildRuntimeHarness;
  TempRoot: string;
begin
  TempRoot := CreateUniqueTempDir('build-runtimeflow-stamp-fail');
  Harness := TBuildRuntimeHarness.Create;
  try
    Harness.RaiseOnWrite := True;

    CreateBuildManagerStampCore(
      TempRoot,
      '3.2.2',
      EncodeDateTime(2026, 4, 14, 9, 30, 0, 0),
      @Harness.EnsureDir,
      @Harness.WriteStamp,
      @Harness.LogLine
    );

    Check('stamp runtimeflow logs write failure',
      Pos('Failed to create build stamp: stamp write boom', Harness.Logged.Text) > 0,
      Harness.Logged.Text);
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

begin
  TestExecuteBuildManagerToolchainCheckCoreSuccess;
  TestExecuteBuildManagerToolchainCheckCoreFailureLogsIssues;
  TestApplyBuildManagerConfigCoreCopiesArraysAndEnsuresDirs;
  TestExecuteBuildManagerRunMakeCoreDryRun;
  TestExecuteBuildManagerRunMakeCoreReportsProbeFailure;
  TestExecuteBuildManagerRunMakeCoreExecutesVerboseArgs;
  TestCreateBuildManagerStampCoreWritesStampAndLogs;
  TestCreateBuildManagerStampCoreSwallowsWriterException;

  WriteLn;
  WriteLn('Pass: ', PassCount, ' Fail: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
