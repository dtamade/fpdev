program test_build_makeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache.types,
  fpdev.build.makeflow;

type
  TMakeFlowHarness = class
  public
    CurrentStep: TBuildStep;
    EnvCalls: Integer;
    MakeCalls: Integer;
    LastSourcePath: string;
    LastTargets: TStringList;
    LogLines: TStringList;
    PerfStarts: TStringList;
    PerfMetadata: TStringList;
    PerfEnds: TStringList;
    EnsuredDirs: TStringList;
    NextMakeResult: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure SetStep(AStep: TBuildStep);
    procedure LogLine(const ALine: string);
    procedure LogEnvSnapshot;
    procedure StartPerf(const AOperation, ACategory: string);
    procedure SetPerfMetadata(const AOperation, AMetadata: string);
    procedure EndPerf(const AOperation: string; ASuccess: Boolean);
    procedure EnsureDir(const APath: string);
    function RunMake(const ASourcePath: string;
      const ATargets: TBuildMakeTargetArray): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TMakeFlowHarness.Create;
begin
  inherited Create;
  CurrentStep := bsIdle;
  LastTargets := TStringList.Create;
  LogLines := TStringList.Create;
  PerfStarts := TStringList.Create;
  PerfMetadata := TStringList.Create;
  PerfEnds := TStringList.Create;
  EnsuredDirs := TStringList.Create;
  NextMakeResult := True;
end;

destructor TMakeFlowHarness.Destroy;
begin
  EnsuredDirs.Free;
  PerfEnds.Free;
  PerfMetadata.Free;
  PerfStarts.Free;
  LogLines.Free;
  LastTargets.Free;
  inherited Destroy;
end;

procedure TMakeFlowHarness.SetStep(AStep: TBuildStep);
begin
  CurrentStep := AStep;
end;

procedure TMakeFlowHarness.LogLine(const ALine: string);
begin
  LogLines.Add(ALine);
end;

procedure TMakeFlowHarness.LogEnvSnapshot;
begin
  Inc(EnvCalls);
end;

procedure TMakeFlowHarness.StartPerf(const AOperation, ACategory: string);
begin
  PerfStarts.Add(AOperation + '|' + ACategory);
end;

procedure TMakeFlowHarness.SetPerfMetadata(const AOperation, AMetadata: string);
begin
  PerfMetadata.Add(AOperation + '|' + AMetadata);
end;

procedure TMakeFlowHarness.EndPerf(const AOperation: string; ASuccess: Boolean);
begin
  if ASuccess then
    PerfEnds.Add(AOperation + '|OK')
  else
    PerfEnds.Add(AOperation + '|FAIL');
end;

procedure TMakeFlowHarness.EnsureDir(const APath: string);
begin
  EnsuredDirs.Add(APath);
end;

function TMakeFlowHarness.RunMake(const ASourcePath: string;
  const ATargets: TBuildMakeTargetArray): Boolean;
var
  I: Integer;
begin
  Inc(MakeCalls);
  LastSourcePath := ASourcePath;
  LastTargets.Clear;
  for I := 0 to High(ATargets) do
    LastTargets.Add(ATargets[I]);
  Result := NextMakeResult;
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

procedure TestCreateInstallPackagesPlanCoreBuildsExpectedTargets;
var
  Plan: TBuildMakeStepPlan;
  Dest: string;
begin
  Dest := '/tmp/fpdev/sandbox/fpc-3.2.2';
  Plan := CreateBuildInstallPackagesStepPlanCore('3.2.2', '/src/fpc-3.2.2', Dest);

  Check('install packages plan applies packages install step',
    Plan.ApplyBeforeStep and (Plan.BeforeStep = bsPackagesInstall),
    'before step mismatch');
  Check('install packages plan requires install allowed',
    Plan.RequiresInstallAllowed,
    'requires install should be true');
  Check('install packages plan keeps dest path',
    Plan.DestPath = Dest,
    'dest=' + Plan.DestPath);
  Check('install packages plan includes package install target',
    (Length(Plan.Targets) = 5) and (Plan.Targets[4] = 'packages_install'),
    'target count=' + IntToStr(Length(Plan.Targets)));
  Check('install packages plan prefixes unit dir',
    Pos('INSTALL_UNITDIR=' + Dest + PathDelim + 'units', Plan.Targets[3]) = 1,
    'unit dir=' + Plan.Targets[3]);
end;

procedure TestExecuteBuildMakeStepCoreRunsCompilerStep;
var
  Harness: TMakeFlowHarness;
  Plan: TBuildMakeStepPlan;
  OK: Boolean;
begin
  Harness := TMakeFlowHarness.Create;
  try
    Plan := CreateBuildCompilerStepPlanCore('3.2.2', '/src/fpc-3.2.2');

    OK := ExecuteBuildMakeStepCore(
      Plan,
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

    Check('compiler makeflow returns true', OK, 'expected success');
    Check('compiler makeflow sets current step', Harness.CurrentStep = bsCompiler,
      'step=' + IntToStr(Ord(Harness.CurrentStep)));
    Check('compiler makeflow calls runmake once', Harness.MakeCalls = 1,
      'calls=' + IntToStr(Harness.MakeCalls));
    Check('compiler makeflow forwards source path', Harness.LastSourcePath = '/src/fpc-3.2.2',
      'source=' + Harness.LastSourcePath);
    Check('compiler makeflow forwards clean/compiler targets',
      (Harness.LastTargets.Count = 2) and
      (Harness.LastTargets[0] = 'clean') and
      (Harness.LastTargets[1] = 'compiler'),
      'targets=' + Harness.LastTargets.Text);
    Check('compiler makeflow logs env snapshot in verbose mode', Harness.EnvCalls = 1,
      'env=' + IntToStr(Harness.EnvCalls));
    Check('compiler makeflow logs start banner',
      Pos('== BuildCompiler START version=3.2.2 src=/src/fpc-3.2.2', Harness.LogLines.Text) > 0,
      'start banner missing');
    Check('compiler makeflow logs end ok banner',
      Pos('== BuildCompiler END OK elapsed_ms=', Harness.LogLines.Text) > 0,
      'end banner missing');
    Check('compiler makeflow records perf start',
      (Harness.PerfStarts.Count = 1) and
      (Harness.PerfStarts[0] = 'BuildCompiler|Build'),
      'perf start=' + Harness.PerfStarts.Text);
    Check('compiler makeflow records perf metadata',
      (Harness.PerfMetadata.Count = 1) and
      (Harness.PerfMetadata[0] = 'BuildCompiler|version=3.2.2'),
      'perf metadata=' + Harness.PerfMetadata.Text);
    Check('compiler makeflow records perf end',
      (Harness.PerfEnds.Count = 1) and
      (Harness.PerfEnds[0] = 'BuildCompiler|OK'),
      'perf end=' + Harness.PerfEnds.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteBuildMakeStepCoreSkipsInstallWhenDisabled;
var
  Harness: TMakeFlowHarness;
  Plan: TBuildMakeStepPlan;
  OK: Boolean;
begin
  Harness := TMakeFlowHarness.Create;
  try
    Plan := CreateBuildInstallStepPlanCore('3.2.2', '/src/fpc-3.2.2', '/tmp/fpdev/sandbox/fpc-3.2.2');

    OK := ExecuteBuildMakeStepCore(
      Plan,
      False,
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

    Check('install makeflow skip returns true', OK, 'skip should succeed');
    Check('install makeflow skip avoids runmake', Harness.MakeCalls = 0,
      'calls=' + IntToStr(Harness.MakeCalls));
    Check('install makeflow skip avoids ensure dir', Harness.EnsuredDirs.Count = 0,
      'ensured=' + IntToStr(Harness.EnsuredDirs.Count));
    Check('install makeflow skip logs message',
      Pos('Install skipped (FAllowInstall=False)', Harness.LogLines.Text) > 0,
      'skip log missing');
    Check('install makeflow skip avoids perf',
      (Harness.PerfStarts.Count = 0) and (Harness.PerfEnds.Count = 0),
      'perf should not run');
  finally
    Harness.Free;
  end;
end;

begin
  TestCreateInstallPackagesPlanCoreBuildsExpectedTargets;
  TestExecuteBuildMakeStepCoreRunsCompilerStep;
  TestExecuteBuildMakeStepCoreSkipsInstallWhenDisabled;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
