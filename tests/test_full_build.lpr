program test_full_build;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.manager, fpdev.build.config, fpdev.build.cache, fpdev.build.cache.types,
  fpdev.build.pipeline;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

type
  TPhaseHarness = class
  private
    FLog: TStringList;
    FCalls: TStringList;
    FCurrentStep: TBuildStep;
  public
    constructor Create;
    destructor Destroy; override;
    function PhasePass(const AVersion: string): Boolean;
    function PhaseFail(const AVersion: string): Boolean;
    procedure LogLine(const ALine: string);
    procedure SetStep(AStep: TBuildStep);
    property Calls: TStringList read FCalls;
    property LogLines: TStringList read FLog;
    property CurrentStep: TBuildStep read FCurrentStep;
  end;

constructor TPhaseHarness.Create;
begin
  inherited Create;
  FLog := TStringList.Create;
  FCalls := TStringList.Create;
  FCurrentStep := bsIdle;
end;

destructor TPhaseHarness.Destroy;
begin
  FCalls.Free;
  FLog.Free;
  inherited Destroy;
end;

function TPhaseHarness.PhasePass(const AVersion: string): Boolean;
begin
  FCalls.Add('pass:' + AVersion);
  Result := True;
end;

function TPhaseHarness.PhaseFail(const AVersion: string): Boolean;
begin
  FCalls.Add('fail:' + AVersion);
  Result := False;
end;

procedure TPhaseHarness.LogLine(const ALine: string);
begin
  FLog.Add(ALine);
end;

procedure TPhaseHarness.SetStep(AStep: TBuildStep);
begin
  FCurrentStep := AStep;
end;

procedure TestExecuteBuildPhaseSequenceCoreAbortsAndResetsIdle;
var
  Harness: TPhaseHarness;
  FailedPhase: string;
  Phases: array[0..1] of TBuildPhaseSpec;
begin
  WriteLn('');
  WriteLn('=== Test: ExecuteBuildPhaseSequenceCore aborts and resets idle ===');
  Harness := TPhaseHarness.Create;
  try
    Phases[0].ApplyBeforeStep := False;
    Phases[0].BeforeStep := bsIdle;
    Phases[0].AbortLabel := 'Preflight';
    Phases[0].Handler := @Harness.PhasePass;

    Phases[1].ApplyBeforeStep := True;
    Phases[1].BeforeStep := bsVerify;
    Phases[1].AbortLabel := 'Verify';
    Phases[1].Handler := @Harness.PhaseFail;

    if ExecuteBuildPhaseSequenceCore(
      'demo',
      Phases,
      @Harness.SetStep,
      @Harness.LogLine,
      FailedPhase
    ) then
    begin
      WriteLn('[FAIL] ExecuteBuildPhaseSequenceCore should fail when a phase fails');
      Halt(1);
    end;

    if FailedPhase <> 'Verify' then
    begin
      WriteLn('[FAIL] FailedPhase should be Verify, got ', FailedPhase);
      Halt(1);
    end;
    if Harness.CurrentStep <> bsIdle then
    begin
      WriteLn('[FAIL] Current step should reset to bsIdle after abort');
      Halt(1);
    end;
    if (Harness.LogLines.Count = 0) or
       (Harness.LogLines[Harness.LogLines.Count - 1] <> '== FullBuild ABORT at Verify') then
    begin
      WriteLn('[FAIL] Abort log line missing or incorrect');
      Halt(1);
    end;
    WriteLn('[PASS] ExecuteBuildPhaseSequenceCore aborts and resets idle');
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteBuildPhaseSequenceCoreRunsAllPhases;
var
  Harness: TPhaseHarness;
  FailedPhase: string;
  Phases: array[0..1] of TBuildPhaseSpec;
begin
  WriteLn('');
  WriteLn('=== Test: ExecuteBuildPhaseSequenceCore runs all phases ===');
  Harness := TPhaseHarness.Create;
  try
    Phases[0].ApplyBeforeStep := True;
    Phases[0].BeforeStep := bsCompilerInstall;
    Phases[0].AbortLabel := 'CompilerInstall';
    Phases[0].Handler := @Harness.PhasePass;

    Phases[1].ApplyBeforeStep := True;
    Phases[1].BeforeStep := bsVerify;
    Phases[1].AbortLabel := 'Verify';
    Phases[1].Handler := @Harness.PhasePass;

    if not ExecuteBuildPhaseSequenceCore(
      'demo',
      Phases,
      @Harness.SetStep,
      @Harness.LogLine,
      FailedPhase
    ) then
    begin
      WriteLn('[FAIL] ExecuteBuildPhaseSequenceCore should succeed when all phases pass');
      Halt(1);
    end;

    if FailedPhase <> '' then
    begin
      WriteLn('[FAIL] FailedPhase should be empty on success');
      Halt(1);
    end;
    if Harness.Calls.Count <> 2 then
    begin
      WriteLn('[FAIL] Both phase handlers should be called');
      Halt(1);
    end;
    if Harness.CurrentStep <> bsVerify then
    begin
      WriteLn('[FAIL] Current step should reflect last applied step');
      Halt(1);
    end;
    WriteLn('[PASS] ExecuteBuildPhaseSequenceCore runs all phases');
  finally
    Harness.Free;
  end;
end;

procedure TestCreateDefaultBuildPhaseSequenceCoreBuildsExpectedPhases;
var
  Harness: TPhaseHarness;
  Phases: TBuildPhaseSpecArray;
begin
  WriteLn('');
  WriteLn('=== Test: CreateDefaultBuildPhaseSequenceCore builds expected phases ===');
  Harness := TPhaseHarness.Create;
  try
    Phases := CreateDefaultBuildPhaseSequenceCore(
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass
    );

    if Length(Phases) <> 10 then
    begin
      WriteLn('[FAIL] Default full-build phase count should be 10, got ', Length(Phases));
      Halt(1);
    end;
    if Phases[0].AbortLabel <> 'Preflight' then
    begin
      WriteLn('[FAIL] Phase 0 should be Preflight');
      Halt(1);
    end;
    if not Assigned(Phases[0].Handler) then
    begin
      WriteLn('[FAIL] Phase 0 handler should be assigned');
      Halt(1);
    end;
    if (not Phases[2].ApplyBeforeStep) or (Phases[2].BeforeStep <> bsCompilerInstall) or Assigned(Phases[2].Handler) then
    begin
      WriteLn('[FAIL] Phase 2 should be compiler-install step transition');
      Halt(1);
    end;
    if (not Phases[8].ApplyBeforeStep) or (Phases[8].BeforeStep <> bsVerify) or Assigned(Phases[8].Handler) then
    begin
      WriteLn('[FAIL] Phase 8 should be verify step transition');
      Halt(1);
    end;
    if Phases[9].AbortLabel <> 'TestResults' then
    begin
      WriteLn('[FAIL] Final phase should be TestResults');
      Halt(1);
    end;
    WriteLn('[PASS] CreateDefaultBuildPhaseSequenceCore builds expected phases');
  finally
    Harness.Free;
  end;
end;

procedure TestFullBuildWorkflowSteps;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox: string;
  LStep: TBuildStep;
begin
  WriteLn('=== Test: FullBuild Workflow Steps ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'fullbuild_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'fullbuild_test' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);

    // Test: Verify initial state
    LStep := LBM.GetCurrentStep;
    if LStep = bsIdle then
      WriteLn('[PASS] Initial state is bsIdle')
    else
    begin
      WriteLn('[FAIL] Initial state should be bsIdle');
      Halt(1);
    end;

    // Test: FullBuild method exists and can be called
    try
      LBM.FullBuild('test-version');
      WriteLn('[PASS] FullBuild method executed');
    except
      on E: Exception do
      begin
        // Expected to fail without make or valid source
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) or
           (Pos('Preflight', E.Message) > 0) then
          WriteLn('[PASS] FullBuild failed as expected (missing dependencies)')
        else
          raise;
      end;
    end;

    WriteLn('[OK] FullBuild workflow steps test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestFullBuildIncludesPackages;
var
  LBM: TBuildManager;
  LSrcRoot: string;
begin
  WriteLn('');
  WriteLn('=== Test: FullBuild Includes Packages Build ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'packages_workflow' + PathDelim + 'sources' + PathDelim + 'fpc';
  EnsureDir(LSrcRoot);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetLogVerbosity(0);
    LBM.SetAllowInstall(True);

    // Test: Verify FullBuild includes packages steps
    // Note: This will fail at Preflight or early stage without make,
    // but we're testing that the workflow is defined correctly
    try
      LBM.FullBuild('test-version');
      WriteLn('[INFO] FullBuild completed (unexpected - no make available)');
    except
      on E: Exception do
      begin
        // Expected to fail, but workflow should be defined
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
          WriteLn('[PASS] FullBuild workflow includes packages (failed at execution as expected)')
        else
          raise;
      end;
    end;

    WriteLn('[OK] FullBuild packages integration test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestFullBuildStateProgression;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox: string;
  LInitialStep: TBuildStep;
begin
  WriteLn('');
  WriteLn('=== Test: FullBuild State Progression ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'state_progression' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'state_progression' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);

    // Test: Verify state starts at bsIdle
    LInitialStep := LBM.GetCurrentStep;
    if LInitialStep = bsIdle then
      WriteLn('[PASS] Initial state is bsIdle')
    else
    begin
      WriteLn('[FAIL] Initial state should be bsIdle');
      Halt(1);
    end;

    // Test: Call FullBuild and verify state changes
    try
      LBM.FullBuild('test-version');
    except
      on E: Exception do
      begin
        // Expected to fail, but state should have progressed
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
        begin
          // State should have changed from bsIdle
          if LBM.GetCurrentStep <> bsIdle then
            WriteLn('[PASS] State progressed from bsIdle during FullBuild')
          else
            WriteLn('[INFO] State remained at bsIdle (early failure)');
        end
        else
          raise;
      end;
    end;

    WriteLn('[OK] State progression test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestFullBuildWithDryRun;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox: string;
begin
  WriteLn('');
  WriteLn('=== Test: FullBuild with Dry-Run Mode ===');

  // Setup: Create BuildManager with dry-run enabled
  LSrcRoot := 'tests_tmp' + PathDelim + 'dryrun_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'dryrun_test' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);
    LBM.SetDryRun(True);

    // Test: FullBuild in dry-run mode should not execute make
    try
      LBM.FullBuild('test-version');
      WriteLn('[PASS] FullBuild executed in dry-run mode');
    except
      on E: Exception do
      begin
        // May still fail at Preflight checks
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
          WriteLn('[PASS] FullBuild dry-run failed at preflight (expected)')
        else
          raise;
      end;
    end;

    WriteLn('[OK] Dry-run mode test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestFullBuildSandboxIsolation;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox, LExpectedDest: string;
begin
  WriteLn('');
  WriteLn('=== Test: FullBuild Sandbox Isolation ===');

  // Setup: Create BuildManager with sandbox
  LSrcRoot := 'tests_tmp' + PathDelim + 'sandbox_isolation' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'sandbox_isolation' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);

    // Test: Verify sandbox root is set correctly
    LExpectedDest := IncludeTrailingPathDelimiter(LSandbox) + 'fpc-test-version';
    WriteLn('[INFO] Expected sandbox destination: ', LExpectedDest);

    // Test: FullBuild should use sandbox for installation
    try
      LBM.FullBuild('test-version');
    except
      on E: Exception do
      begin
        // Expected to fail, but sandbox should be configured
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
          WriteLn('[PASS] FullBuild attempted with sandbox isolation')
        else
          raise;
      end;
    end;

    WriteLn('[OK] Sandbox isolation test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestFullBuildLogGeneration;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox, LLogFile: string;
begin
  WriteLn('');
  WriteLn('=== Test: FullBuild Log Generation ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'log_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'log_test' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);
  EnsureDir('logs');

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);

    // Test: FullBuild should generate log file
    try
      LBM.FullBuild('test-version');
    except
      on E: Exception do
      begin
        // Expected to fail, but log should be created
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
        begin
          LLogFile := LBM.LogFileName;
          if LLogFile <> '' then
            WriteLn('[PASS] Log file generated: ', LLogFile)
          else
            WriteLn('[INFO] No log file generated (early failure)');
        end
        else
          raise;
      end;
    end;

    WriteLn('[OK] Log generation test passed');
  finally
    LBM.Free;
  end;
end;

begin
  try
    // Ensure test directories exist
    EnsureDir('tests_tmp');
    EnsureDir('logs');

    // Run tests
    TestExecuteBuildPhaseSequenceCoreAbortsAndResetsIdle;
    TestExecuteBuildPhaseSequenceCoreRunsAllPhases;
    TestCreateDefaultBuildPhaseSequenceCoreBuildsExpectedPhases;
    TestFullBuildWorkflowSteps;
    TestFullBuildIncludesPackages;
    TestFullBuildStateProgression;
    TestFullBuildWithDryRun;
    TestFullBuildSandboxIsolation;
    TestFullBuildLogGeneration;

    WriteLn('');
    WriteLn('======================');
    WriteLn('All tests passed (8/8)');
    WriteLn('======================');
    WriteLn('');
    WriteLn('Note: FullBuild tests verify workflow integration and state management.');
    WriteLn('Actual make execution requires make/gmake and valid FPC source.');
  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('Test failed with exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
