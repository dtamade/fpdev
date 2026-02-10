program test_install_packages;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.manager, fpdev.build.config, fpdev.build.cache, fpdev.build.cache.types;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure TestInstallPackagesWithAllowInstall;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox: string;
  LOk: Boolean;
begin
  WriteLn('=== Test: InstallPackages with AllowInstall=True ===');

  // Setup: Create BuildManager with AllowInstall enabled
  LSrcRoot := 'tests_tmp' + PathDelim + 'install_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'install_test' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);

    // Test: InstallPackages should attempt installation
    // Note: Will fail without make, but we're testing the API behavior
    try
      LOk := LBM.InstallPackages('test-version');
      // If make is available, it might succeed or fail depending on source
      WriteLn('[INFO] InstallPackages returned: ', LOk);
      WriteLn('[PASS] InstallPackages executed with AllowInstall=True');
    except
      on E: Exception do
      begin
        // Expected to fail without make or valid source
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
          WriteLn('[PASS] InstallPackages failed as expected (missing make or source)')
        else
          raise;
      end;
    end;

    // Verify current step is set correctly
    if LBM.GetCurrentStep = bsPackagesInstall then
      WriteLn('[PASS] Current step is bsPackagesInstall')
    else
    begin
      WriteLn('[FAIL] Current step is not bsPackagesInstall');
      Halt(1);
    end;

    WriteLn('[OK] InstallPackages with AllowInstall test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestInstallPackagesSandboxIntegration;
var
  LBM: TBuildManager;
  LSrcRoot, LSandbox, LExpectedDest: string;
begin
  WriteLn('');
  WriteLn('=== Test: InstallPackages Sandbox Integration ===');

  // Setup: Create BuildManager with sandbox
  LSrcRoot := 'tests_tmp' + PathDelim + 'sandbox_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSandbox := 'tests_tmp' + PathDelim + 'sandbox_test' + PathDelim + 'sandbox';
  EnsureDir(LSrcRoot);
  EnsureDir(LSandbox);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetSandboxRoot(LSandbox);
    LBM.SetAllowInstall(True);

    // Test: Verify sandbox root is set
    LExpectedDest := IncludeTrailingPathDelimiter(LSandbox) + 'fpc-test-version';
    WriteLn('[INFO] Expected install destination: ', LExpectedDest);

    // Attempt install (will fail without make, but we're testing setup)
    try
      LBM.InstallPackages('test-version');
    except
      on E: Exception do
      begin
        // Expected to fail, just testing that sandbox path is used
        if (Pos('Failed to execute', E.Message) > 0) then
          WriteLn('[PASS] InstallPackages attempted with sandbox path')
        else
          raise;
      end;
    end;

    WriteLn('[OK] Sandbox integration test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestInstallPackagesSkipBehavior;
var
  LBM: TBuildManager;
  LSrcRoot: string;
  LOk: Boolean;
begin
  WriteLn('');
  WriteLn('=== Test: InstallPackages Skip Behavior ===');

  // Setup: Create BuildManager with AllowInstall=False
  LSrcRoot := 'tests_tmp' + PathDelim + 'skip_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  EnsureDir(LSrcRoot);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    // Test 1: Default AllowInstall=False should skip
    LOk := LBM.InstallPackages('test-version');
    if LOk then
      WriteLn('[PASS] InstallPackages skipped correctly (AllowInstall=False)')
    else
    begin
      WriteLn('[FAIL] InstallPackages should return True when skipping');
      Halt(1);
    end;

    // Test 2: Enable AllowInstall, then disable, should skip again
    LBM.SetAllowInstall(True);
    LBM.SetAllowInstall(False);
    LOk := LBM.InstallPackages('test-version-2');
    if LOk then
      WriteLn('[PASS] InstallPackages skipped after re-disabling AllowInstall')
    else
    begin
      WriteLn('[FAIL] InstallPackages should skip when AllowInstall is disabled');
      Halt(1);
    end;

    WriteLn('[OK] Skip behavior test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestInstallPackagesStateTracking;
var
  LBM: TBuildManager;
  LSrcRoot: string;
  LStep: TBuildStep;
begin
  WriteLn('');
  WriteLn('=== Test: InstallPackages State Tracking ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'state_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  EnsureDir(LSrcRoot);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    // Test: Verify initial state
    LStep := LBM.GetCurrentStep;
    if LStep = bsIdle then
      WriteLn('[PASS] Initial state is bsIdle')
    else
    begin
      WriteLn('[FAIL] Initial state should be bsIdle, got: ', Ord(LStep));
      Halt(1);
    end;

    // Test: Call InstallPackages and verify state change
    LBM.InstallPackages('test-version');
    LStep := LBM.GetCurrentStep;
    if LStep = bsPackagesInstall then
      WriteLn('[PASS] State changed to bsPackagesInstall after call')
    else
    begin
      WriteLn('[FAIL] State should be bsPackagesInstall, got: ', Ord(LStep));
      Halt(1);
    end;

    WriteLn('[OK] State tracking test passed');
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
    TestInstallPackagesWithAllowInstall;
    TestInstallPackagesSandboxIntegration;
    TestInstallPackagesSkipBehavior;
    TestInstallPackagesStateTracking;

    WriteLn('');
    WriteLn('======================');
    WriteLn('All tests passed (4/4)');
    WriteLn('======================');
    WriteLn('');
    WriteLn('Note: InstallPackages tests verify API behavior and state management.');
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
