program test_build_managerflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  test_temp_paths,
  fpdev.build.cache.types,
  fpdev.build.makeflow,
  fpdev.build.managerflow;

type
  TBuildManagerFlowHarness = class
  private
    FLogLines: TStringList;
    FSummaries: TStringList;
    FStepHistory: array of TBuildStep;
    FMakeRuns: TStringList;
    FEnsuredDirs: TStringList;
    FPerfStarts: TStringList;
    FPerfMetadata: TStringList;
    FPerfEnds: TStringList;
    FSampledDirs: TStringList;
    FCurrentStep: TBuildStep;
    FPolicyCalls: Integer;
    FJSONCalls: Integer;
    FHasMakeCalls: Integer;
    FCanWriteCalls: Integer;
    FEnvCalls: Integer;
    FStrictConfigCalls: Integer;
    FHasMakeResult: Boolean;
    FCanWriteResult: Boolean;
    FNextMakeResult: Boolean;
    FStrictConfigResult: Boolean;
    FSourceRoot: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetStep(AStep: TBuildStep);
    procedure LogLine(const ALine: string);
    procedure LogEnvSnapshot;
    procedure LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
    procedure EnsureDir(const APath: string);
    procedure StartPerf(const AOperation, ACategory: string);
    procedure SetPerfMetadata(const AOperation, AMetadata: string);
    procedure EndPerf(const AOperation: string; ASuccess: Boolean);
    function RunMake(const ASourcePath: string;
      const ATargets: TBuildMakeTargetArray): Boolean;
    function PolicyCheck(const AVersion: string;
      out AStatus, AReason, AMin, ARecommended, ACurrentFpcVersion: string): Boolean;
    function BuildToolchainJSON: string;
    function HasMake: Boolean;
    function CanWriteDir(const APath: string): Boolean;
    function GetSourcePath(const AVersion: string): string;
    function ApplyStrictConfig(const ASandboxDest: string): Boolean;
    procedure LogDirSample(const ADir: string; ALimit: Integer);
    property LogLines: TStringList read FLogLines;
    property Summaries: TStringList read FSummaries;
    property MakeRuns: TStringList read FMakeRuns;
    property EnsuredDirs: TStringList read FEnsuredDirs;
    property PerfStarts: TStringList read FPerfStarts;
    property PerfMetadata: TStringList read FPerfMetadata;
    property PerfEnds: TStringList read FPerfEnds;
    property SampledDirs: TStringList read FSampledDirs;
    property CurrentStep: TBuildStep read FCurrentStep;
    property PolicyCalls: Integer read FPolicyCalls;
    property JSONCalls: Integer read FJSONCalls;
    property HasMakeCalls: Integer read FHasMakeCalls;
    property CanWriteCalls: Integer read FCanWriteCalls;
    property EnvCalls: Integer read FEnvCalls;
    property StrictConfigCalls: Integer read FStrictConfigCalls;
    property HasMakeResult: Boolean read FHasMakeResult write FHasMakeResult;
    property CanWriteResult: Boolean read FCanWriteResult write FCanWriteResult;
    property NextMakeResult: Boolean read FNextMakeResult write FNextMakeResult;
    property StrictConfigResult: Boolean read FStrictConfigResult write FStrictConfigResult;
    property SourceRoot: string read FSourceRoot write FSourceRoot;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TBuildManagerFlowHarness.Create;
begin
  inherited Create;
  FLogLines := TStringList.Create;
  FSummaries := TStringList.Create;
  FMakeRuns := TStringList.Create;
  FEnsuredDirs := TStringList.Create;
  FPerfStarts := TStringList.Create;
  FPerfMetadata := TStringList.Create;
  FPerfEnds := TStringList.Create;
  FSampledDirs := TStringList.Create;
  FCurrentStep := bsIdle;
  FHasMakeResult := True;
  FCanWriteResult := True;
  FNextMakeResult := True;
  FStrictConfigResult := True;
  FSourceRoot := '/src';
end;

destructor TBuildManagerFlowHarness.Destroy;
begin
  FSampledDirs.Free;
  FPerfEnds.Free;
  FPerfMetadata.Free;
  FPerfStarts.Free;
  FEnsuredDirs.Free;
  FMakeRuns.Free;
  FSummaries.Free;
  FLogLines.Free;
  inherited Destroy;
end;

procedure TBuildManagerFlowHarness.SetStep(AStep: TBuildStep);
var
  Index: Integer;
begin
  FCurrentStep := AStep;
  Index := Length(FStepHistory);
  SetLength(FStepHistory, Index + 1);
  FStepHistory[Index] := AStep;
end;

procedure TBuildManagerFlowHarness.LogLine(const ALine: string);
begin
  FLogLines.Add(ALine);
end;

procedure TBuildManagerFlowHarness.LogEnvSnapshot;
begin
  Inc(FEnvCalls);
end;

procedure TBuildManagerFlowHarness.LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  FSummaries.Add(AVersion + '|' + AContext + '|' + AResult + '|' + IntToStr(AElapsedMs));
end;

procedure TBuildManagerFlowHarness.EnsureDir(const APath: string);
begin
  FEnsuredDirs.Add(APath);
end;

procedure TBuildManagerFlowHarness.StartPerf(const AOperation, ACategory: string);
begin
  FPerfStarts.Add(AOperation + '|' + ACategory);
end;

procedure TBuildManagerFlowHarness.SetPerfMetadata(const AOperation, AMetadata: string);
begin
  FPerfMetadata.Add(AOperation + '|' + AMetadata);
end;

procedure TBuildManagerFlowHarness.EndPerf(const AOperation: string; ASuccess: Boolean);
begin
  if ASuccess then
    FPerfEnds.Add(AOperation + '|OK')
  else
    FPerfEnds.Add(AOperation + '|FAIL');
end;

function TBuildManagerFlowHarness.RunMake(const ASourcePath: string;
  const ATargets: TBuildMakeTargetArray): Boolean;
var
  I: Integer;
  Line: string;
begin
  Line := ASourcePath;
  for I := 0 to High(ATargets) do
    Line := Line + '|' + ATargets[I];
  FMakeRuns.Add(Line);
  Result := FNextMakeResult;
end;

function TBuildManagerFlowHarness.PolicyCheck(const AVersion: string;
  out AStatus, AReason, AMin, ARecommended, ACurrentFpcVersion: string): Boolean;
begin
  Inc(FPolicyCalls);
  AStatus := 'WARN';
  AReason := 'policy warning';
  AMin := '3.2.0';
  ARecommended := '3.2.2';
  ACurrentFpcVersion := '3.2.2';
  Result := True;
end;

function TBuildManagerFlowHarness.BuildToolchainJSON: string;
begin
  Inc(FJSONCalls);
  Result := '{"level":"OK"}';
end;

function TBuildManagerFlowHarness.HasMake: Boolean;
begin
  Inc(FHasMakeCalls);
  Result := FHasMakeResult;
end;

function TBuildManagerFlowHarness.CanWriteDir(const APath: string): Boolean;
begin
  Inc(FCanWriteCalls);
  Result := FCanWriteResult;
end;

function TBuildManagerFlowHarness.GetSourcePath(const AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FSourceRoot) + 'fpc-' + AVersion;
end;

function TBuildManagerFlowHarness.ApplyStrictConfig(const ASandboxDest: string): Boolean;
begin
  Inc(FStrictConfigCalls);
  FLogLines.Add('strict:' + ASandboxDest);
  Result := FStrictConfigResult;
end;

procedure TBuildManagerFlowHarness.LogDirSample(const ADir: string; ALimit: Integer);
begin
  FSampledDirs.Add(ADir + '|' + IntToStr(ALimit));
end;

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

procedure WriteTextFile(const APath, AText: string);
var
  Handle: TextFile;
begin
  AssignFile(Handle, APath);
  Rewrite(Handle);
  try
    WriteLn(Handle, AText);
  finally
    CloseFile(Handle);
  end;
end;

function PathExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

procedure TestExecuteBuildManagerPreflightCoreSuccess;
var
  Harness: TBuildManagerFlowHarness;
  RootDir, SourcePath, SandboxRoot, LogDir: string;
  OK: Boolean;
begin
  Harness := TBuildManagerFlowHarness.Create;
  RootDir := CreateUniqueTempDir('build-managerflow-preflight-ok');
  try
    SourcePath := RootDir + PathDelim + 'sources' + PathDelim + 'fpc-demo';
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    LogDir := RootDir + PathDelim + 'logs';
    ForceDirectories(SourcePath);
    Harness.SourceRoot := RootDir + PathDelim + 'sources';

    OK := ExecuteBuildManagerPreflightCore(
      'demo',
      Harness.SourceRoot,
      SourcePath,
      SandboxRoot,
      LogDir,
      1,
      False,
      False,
      @Harness.PolicyCheck,
      @Harness.BuildToolchainJSON,
      @Harness.HasMake,
      @Harness.CanWriteDir,
      @Harness.SetStep,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf,
      @Harness.LogSummary
    );

    Check('preflight core success returns true', OK, 'expected success');
    Check('preflight core sets preflight step', Harness.CurrentStep = bsPreflight,
      'step=' + IntToStr(Ord(Harness.CurrentStep)));
    Check('preflight core logs start banner',
      Pos('== Preflight START version=demo srcRoot=' + Harness.SourceRoot, Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('preflight core logs end ok banner',
      Pos('== Preflight END OK', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('preflight core logs env snapshot in verbose mode', Harness.EnvCalls = 1,
      'env calls=' + IntToStr(Harness.EnvCalls));
    Check('preflight core probes make once in non-strict mode', Harness.HasMakeCalls = 1,
      'make calls=' + IntToStr(Harness.HasMakeCalls));
    Check('preflight core skips policy/json in non-strict mode',
      (Harness.PolicyCalls = 0) and (Harness.JSONCalls = 0),
      'policy=' + IntToStr(Harness.PolicyCalls) + ' json=' + IntToStr(Harness.JSONCalls));
    Check('preflight core records perf start and end',
      (Harness.PerfStarts.Count = 1) and
      (Harness.PerfStarts[0] = 'Preflight|Build') and
      (Harness.PerfEnds.Count = 1) and
      (Harness.PerfEnds[0] = 'Preflight|OK'),
      Harness.PerfStarts.Text + Harness.PerfEnds.Text);
    Check('preflight core records summary',
      (Harness.Summaries.Count = 1) and
      (Pos('demo|preflight|OK|', Harness.Summaries[0]) = 1),
      Harness.Summaries.Text);
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerPreflightCoreFailure;
var
  Harness: TBuildManagerFlowHarness;
  RootDir, SourcePath, SandboxRoot, LogDir: string;
  OK: Boolean;
begin
  Harness := TBuildManagerFlowHarness.Create;
  RootDir := CreateUniqueTempDir('build-managerflow-preflight-fail');
  try
    SourcePath := RootDir + PathDelim + 'missing' + PathDelim + 'fpc-demo';
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    LogDir := RootDir + PathDelim + 'logs';
    Harness.SourceRoot := RootDir + PathDelim + 'missing';
    Harness.HasMakeResult := False;
    Harness.CanWriteResult := False;

    OK := ExecuteBuildManagerPreflightCore(
      'demo',
      Harness.SourceRoot,
      SourcePath,
      SandboxRoot,
      LogDir,
      1,
      False,
      True,
      @Harness.PolicyCheck,
      @Harness.BuildToolchainJSON,
      @Harness.HasMake,
      @Harness.CanWriteDir,
      @Harness.SetStep,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf,
      @Harness.LogSummary
    );

    Check('preflight core failure returns false', not OK, 'expected failure');
    Check('preflight core logs failure banner',
      Pos('== Preflight END FAIL issues=', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('preflight core logs source missing issue',
      Pos('issue: source not found: ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('preflight core logs make missing issue',
      Pos('issue: make not available', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('preflight core records failed summary',
      (Harness.Summaries.Count = 1) and
      (Pos('demo|preflight|FAIL|', Harness.Summaries[0]) = 1),
      Harness.Summaries.Text);
    Check('preflight core records perf failure',
      (Harness.PerfEnds.Count = 1) and (Harness.PerfEnds[0] = 'Preflight|FAIL'),
      Harness.PerfEnds.Text);
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerMakeOperationCoreOrdersBuildSteps;
var
  Harness: TBuildManagerFlowHarness;
  OK: Boolean;
begin
  Harness := TBuildManagerFlowHarness.Create;
  try
    OK := ExecuteBuildManagerMakeOperationCore(
      bmmBuildCompiler,
      'demo',
      '/src/fpc-demo',
      '/tmp/fpdev-sandbox',
      True,
      1,
      @Harness.SetStep,
      @Harness.EnsureDir,
      @Harness.RunMake,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf
    );
    OK := OK and ExecuteBuildManagerMakeOperationCore(
      bmmBuildRTL,
      'demo',
      '/src/fpc-demo',
      '/tmp/fpdev-sandbox',
      True,
      0,
      @Harness.SetStep,
      @Harness.EnsureDir,
      @Harness.RunMake,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf
    );
    OK := OK and ExecuteBuildManagerMakeOperationCore(
      bmmBuildPackages,
      'demo',
      '/src/fpc-demo',
      '/tmp/fpdev-sandbox',
      True,
      0,
      @Harness.SetStep,
      @Harness.EnsureDir,
      @Harness.RunMake,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf
    );

    Check('make operation sequence returns true', OK, 'expected success');
    Check('make operation records compiler step first',
      (Length(Harness.FStepHistory) >= 3) and (Harness.FStepHistory[0] = bsCompiler),
      'step history length=' + IntToStr(Length(Harness.FStepHistory)));
    Check('make operation records rtl step second',
      (Length(Harness.FStepHistory) >= 3) and (Harness.FStepHistory[1] = bsRTL),
      'step history length=' + IntToStr(Length(Harness.FStepHistory)));
    Check('make operation records packages step third',
      (Length(Harness.FStepHistory) >= 3) and (Harness.FStepHistory[2] = bsPackages),
      'step history length=' + IntToStr(Length(Harness.FStepHistory)));
    Check('make operation records compiler targets',
      Pos('/src/fpc-demo|clean|compiler', Harness.MakeRuns[0]) = 1,
      Harness.MakeRuns.Text);
    Check('make operation records rtl target',
      Pos('/src/fpc-demo|rtl', Harness.MakeRuns[1]) = 1,
      Harness.MakeRuns.Text);
    Check('make operation records packages target',
      Pos('/src/fpc-demo|packages', Harness.MakeRuns[2]) = 1,
      Harness.MakeRuns.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerMakeOperationCoreInstallContract;
var
  Harness: TBuildManagerFlowHarness;
  OK: Boolean;
  Dest: string;
begin
  Harness := TBuildManagerFlowHarness.Create;
  try
    Dest := '/tmp/fpdev-sandbox/fpc-demo';

    OK := ExecuteBuildManagerMakeOperationCore(
      bmmInstallPackages,
      'demo',
      '/src/fpc-demo',
      '/tmp/fpdev-sandbox',
      False,
      0,
      @Harness.SetStep,
      @Harness.EnsureDir,
      @Harness.RunMake,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf
    );
    Check('install packages skip returns true', OK, 'skip should succeed');
    Check('install packages skip avoids runmake', Harness.MakeRuns.Count = 0,
      Harness.MakeRuns.Text);
    Check('install packages skip logs message',
      Pos('InstallPackages skipped (FAllowInstall=False)', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);

    Harness.LogLines.Clear;
    Harness.EnsuredDirs.Clear;
    Harness.NextMakeResult := True;

    OK := ExecuteBuildManagerMakeOperationCore(
      bmmInstall,
      'demo',
      '/src/fpc-demo',
      '/tmp/fpdev-sandbox',
      True,
      0,
      @Harness.SetStep,
      @Harness.EnsureDir,
      @Harness.RunMake,
      @Harness.LogLine,
      @Harness.LogEnvSnapshot,
      @Harness.StartPerf,
      @Harness.SetPerfMetadata,
      @Harness.EndPerf
    );

    Check('install operation returns true', OK, 'expected success');
    Check('install operation ensures sandbox dest',
      (Harness.EnsuredDirs.Count = 1) and (Harness.EnsuredDirs[0] = Dest),
      Harness.EnsuredDirs.Text);
    Check('install operation forwards install targets',
      (Harness.MakeRuns.Count = 1) and
      (Pos('/src/fpc-demo|DESTDIR=' + Dest + '|PREFIX=' + Dest +
        '|INSTALL_PREFIX=' + Dest + '|install', Harness.MakeRuns[0]) = 1),
      Harness.MakeRuns.Text);
    Check('install operation logs start/end banners',
      (Pos('== Install START version=demo src=/src/fpc-demo dest=' + Dest, Harness.LogLines.Text) > 0) and
      (Pos('== Install END OK elapsed_ms=', Harness.LogLines.Text) > 0),
      Harness.LogLines.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteBuildManagerTestResultsCoreWrapsSandboxChecks;
var
  Harness: TBuildManagerFlowHarness;
  RootDir, SandboxRoot, BinDir, LibDir: string;
  OK: Boolean;
begin
  Harness := TBuildManagerFlowHarness.Create;
  RootDir := CreateUniqueTempDir('build-managerflow-testresults');
  try
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    BinDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'bin';
    LibDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'lib' + PathDelim + 'fpc';
    ForceDirectories(BinDir);
    ForceDirectories(LibDir);
    WriteTextFile(BinDir + PathDelim + 'fpc', 'demo');
    WriteTextFile(LibDir + PathDelim + 'placeholder', 'demo');
    Harness.SourceRoot := RootDir + PathDelim + 'sources';

    OK := ExecuteBuildManagerTestResultsCore(
      'demo',
      SandboxRoot,
      True,
      True,
      1,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @PathExists,
      @PathExists,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('testresults wrapper returns true', OK, 'expected success');
    Check('testresults wrapper applies strict config once', Harness.StrictConfigCalls = 1,
      'strict calls=' + IntToStr(Harness.StrictConfigCalls));
    Check('testresults wrapper records sandbox summary',
      (Harness.Summaries.Count = 1) and
      (Pos('demo|sandbox|OK|', Harness.Summaries[0]) = 1),
      Harness.Summaries.Text);
    Check('testresults wrapper logs sandbox ok',
      Pos('TestResults: sandbox OK at ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('testresults wrapper samples bin and lib', Harness.SampledDirs.Count = 2,
      Harness.SampledDirs.Text);
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

begin
  TestExecuteBuildManagerPreflightCoreSuccess;
  TestExecuteBuildManagerPreflightCoreFailure;
  TestExecuteBuildManagerMakeOperationCoreOrdersBuildSteps;
  TestExecuteBuildManagerMakeOperationCoreInstallContract;
  TestExecuteBuildManagerTestResultsCoreWrapsSandboxChecks;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
