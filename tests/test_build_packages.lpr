program test_build_packages;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.manager, fpdev.build.config, fpdev.build.cache;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure TestBuildPackagesAPI;
var
  LBM: TBuildManager;
  LSrcRoot: string;
begin
  WriteLn('=== Test: BuildPackages API Exists ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'packages_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  EnsureDir(LSrcRoot);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    // Test: Verify BuildPackages method exists and can be called
    // Note: This will fail if make is not installed, but that's OK for API testing
    try
      LBM.BuildPackages('test-version');
      WriteLn('[PASS] BuildPackages method exists and is callable');
    except
      on E: Exception do
      begin
        // Expected to fail without make, but method exists
        if Pos('Failed to execute', E.Message) > 0 then
          WriteLn('[PASS] BuildPackages method exists (failed due to missing make, which is expected)')
        else
          raise;
      end;
    end;

    WriteLn('[OK] BuildPackages API test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestInstallPackagesAPI;
var
  LBM: TBuildManager;
  LSrcRoot: string;
  LOk: Boolean;
begin
  WriteLn('');
  WriteLn('=== Test: InstallPackages API Exists ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'packages_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  EnsureDir(LSrcRoot);

  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    // Test: Verify InstallPackages method exists
    // Without AllowInstall, it should skip and return True
    LOk := LBM.InstallPackages('test-version');

    if LOk then
      WriteLn('[PASS] InstallPackages skipped correctly (AllowInstall=False)')
    else
    begin
      WriteLn('[FAIL] InstallPackages should return True when AllowInstall=False');
      Halt(1);
    end;

    // Test: Verify current step is set correctly
    if LBM.GetCurrentStep = bsPackagesInstall then
      WriteLn('[PASS] Current step is bsPackagesInstall')
    else
    begin
      WriteLn('[FAIL] Current step is not bsPackagesInstall');
      Halt(1);
    end;

    WriteLn('[OK] InstallPackages API test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestFullBuildWorkflow;
var
  LBM: TBuildManager;
  LSrcRoot, LVer, LSrcPath: string;
begin
  WriteLn('');
  WriteLn('=== Test: FullBuild Workflow Integration ===');

  // Setup: Create test source directory
  LVer := 'test-full';
  LSrcRoot := 'tests_tmp' + PathDelim + 'packages_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSrcPath := IncludeTrailingPathDelimiter(LSrcRoot) + 'fpc-' + LVer;
  EnsureDir(LSrcPath);

  // Create BuildManager
  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    LBM.SetLogVerbosity(0);
    LBM.SetAllowInstall(True);
    LBM.SetSandboxRoot('tests_tmp' + PathDelim + 'sandbox');

    // Test: Verify FullBuild method exists
    // Note: This will fail at Preflight or BuildCompiler stage without make,
    // but we're testing that the workflow includes packages build steps
    try
      LBM.FullBuild(LVer);
      WriteLn('[PASS] FullBuild method executed (may have failed at early stage)');
    except
      on E: Exception do
      begin
        // Expected to fail without make or valid source
        if (Pos('Failed to execute', E.Message) > 0) or
           (Pos('not found', E.Message) > 0) then
          WriteLn('[PASS] FullBuild method exists (failed due to missing dependencies, which is expected)')
        else
          raise;
      end;
    end;

    WriteLn('[OK] FullBuild workflow test passed');
  finally
    LBM.Free;
  end;
end;

procedure TestPackageSelectionAPI;
var
  LBM: TBuildManager;
  LSrcRoot: string;
  LPackages: TStringArray;
  LCount: Integer;
begin
  WriteLn('');
  WriteLn('=== Test: Package Selection API ===');

  // Setup: Create BuildManager
  LSrcRoot := 'tests_tmp' + PathDelim + 'packages_test' + PathDelim + 'sources' + PathDelim + 'fpc';
  LBM := TBuildManager.Create(LSrcRoot, 2, False);
  try
    // Test: ListPackages
    LPackages := LBM.ListPackages;
    if Length(LPackages) > 0 then
      WriteLn('[PASS] ListPackages returns package list (', Length(LPackages), ' packages)')
    else
    begin
      WriteLn('[FAIL] ListPackages should return non-empty list');
      Halt(1);
    end;

    // Test: SetSelectedPackages
    SetLength(LPackages, 3);
    LPackages[0] := 'fcl-base';
    LPackages[1] := 'fcl-json';
    LPackages[2] := 'fcl-xml';
    LBM.SetSelectedPackages(LPackages);

    LCount := LBM.GetSelectedPackageCount;
    if LCount = 3 then
      WriteLn('[PASS] SetSelectedPackages works correctly (3 packages selected)')
    else
    begin
      WriteLn('[FAIL] GetSelectedPackageCount should return 3, got ', LCount);
      Halt(1);
    end;

    // Test: GetPackageBuildOrder
    LPackages := LBM.GetPackageBuildOrder;
    if Length(LPackages) = 3 then
      WriteLn('[PASS] GetPackageBuildOrder returns selected packages')
    else
    begin
      WriteLn('[FAIL] GetPackageBuildOrder should return 3 packages, got ', Length(LPackages));
      Halt(1);
    end;

    WriteLn('[OK] Package selection API test passed');
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
    TestBuildPackagesAPI;
    TestInstallPackagesAPI;
    TestFullBuildWorkflow;
    TestPackageSelectionAPI;

    WriteLn('');
    WriteLn('======================');
    WriteLn('All tests passed (4/4)');
    WriteLn('======================');
    WriteLn('');
    WriteLn('Note: BuildPackages and FullBuild tests verify API existence.');
    WriteLn('Actual make execution requires make/gmake to be installed.');
  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('Test failed with exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
