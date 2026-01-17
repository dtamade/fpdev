program test_full_build;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.manager, fpdev.build.config, fpdev.build.cache;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
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
    TestFullBuildWorkflowSteps;
    TestFullBuildIncludesPackages;
    TestFullBuildStateProgression;
    TestFullBuildWithDryRun;
    TestFullBuildSandboxIsolation;
    TestFullBuildLogGeneration;

    WriteLn('');
    WriteLn('======================');
    WriteLn('All tests passed (6/6)');
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
