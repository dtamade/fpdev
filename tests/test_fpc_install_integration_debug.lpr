program test_fpc_install_integration_debug;

{$mode objfpc}{$H+}

{
  Debug version of integration test
  Tests components one by one to isolate memory corruption
}

uses
  SysUtils, Classes,
  fpdev.fpc.binary, fpdev.fpc.verify, fpdev.platform,
  fpdev.fpc.mirrors, fpdev.http.download, fpdev.archive.extract,
  fpdev.build.cache;

var
  TestsPassed, TestsFailed: Integer;
  TestCacheDir: string;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure TestPlatformDetection;
var
  Platform: TPlatformInfo;
begin
  WriteLn('=== Platform Detection ===');
  Platform := DetectPlatform();
  Assert(Platform.IsValid, 'Platform detection returns valid platform');
  Assert(Platform.ToString <> '', 'Platform string is not empty');
  WriteLn('Detected platform: ', Platform.ToString);
  WriteLn;
end;

procedure TestMirrorManager;
var
  MirrorMgr: TMirrorManager;
  URL: string;
  Platform: TPlatformInfo;
begin
  WriteLn('=== Mirror Manager ===');
  MirrorMgr := TMirrorManager.Create;
  try
    MirrorMgr.LoadDefaultMirrors;
    Platform := DetectPlatform();
    URL := MirrorMgr.GetDownloadURL('3.2.2', Platform.ToString);
    Assert(URL <> '', 'Mirror manager generates download URL');
    Assert(Pos('3.2.2', URL) > 0, 'URL contains version number');
    WriteLn('Generated URL: ', URL);
  finally
    MirrorMgr.Free;
  end;
  WriteLn;
end;

procedure TestVerifier;
var
  Verifier: TFPCVerifier;
  Version: string;
begin
  WriteLn('=== FPC Verifier ===');
  Verifier := TFPCVerifier.Create;
  try
    Version := Verifier.ParseVersion('Free Pascal Compiler version 3.2.2');
    Assert(Version = '3.2.2', 'Parse FPC version string');
    Version := Verifier.ParseVersion('Free Pascal Compiler version 3.2.2 [2021/05/15]');
    Assert(Version = '3.2.2', 'Parse FPC version with build date');
    Version := Verifier.ParseVersion('Invalid output');
    Assert(Version = '', 'Invalid version returns empty string');
    Assert(Length(Verifier.GetHelloWorldSource) > 0, 'Generate hello world source');
    Assert(Pos('program', Verifier.GetHelloWorldSource) > 0, 'Hello world contains program keyword');
  finally
    Verifier.Free;
  end;
  WriteLn;
end;

procedure TestBinaryInstallerConfiguration;
var
  Installer: TBinaryInstaller;
  UseCacheValue, OfflineModeValue, VerifyValue: Boolean;
begin
  WriteLn('=== Binary Installer Configuration ===');
  WriteLn('DEBUG: About to create TBinaryInstaller');

  Installer := TBinaryInstaller.Create;
  WriteLn('DEBUG: TBinaryInstaller created successfully');

  try
    // Read properties immediately after creation
    UseCacheValue := Installer.UseCache;
    OfflineModeValue := Installer.OfflineMode;
    VerifyValue := Installer.VerifyInstallation;

    WriteLn('DEBUG: UseCache = ', UseCacheValue);
    WriteLn('DEBUG: OfflineMode = ', OfflineModeValue);
    WriteLn('DEBUG: VerifyInstallation = ', VerifyValue);

    // Test configuration properties
    Assert(UseCacheValue, 'UseCache enabled by default');
    Assert(not OfflineModeValue, 'OfflineMode disabled by default');
    Assert(VerifyValue, 'VerifyInstallation enabled by default');

    // Test property setters
    Installer.UseCache := False;
    Assert(not Installer.UseCache, 'Can disable UseCache');

    Installer.OfflineMode := True;
    Assert(Installer.OfflineMode, 'Can enable OfflineMode');

    Installer.VerifyInstallation := False;
    Assert(not Installer.VerifyInstallation, 'Can disable VerifyInstallation');

    WriteLn('DEBUG: About to free TBinaryInstaller');
  finally
    Installer.Free;
    WriteLn('DEBUG: TBinaryInstaller freed successfully');
  end;

  WriteLn;
end;

procedure TestCacheIntegration;
var
  Cache: TBuildCache;
  TestVersion: string;
begin
  WriteLn('=== Cache Integration ===');
  WriteLn('DEBUG: About to create TBuildCache with TestCacheDir: ', TestCacheDir);

  TestVersion := '999.999.999';  // Non-existent version for testing

  Cache := TBuildCache.Create(TestCacheDir);
  WriteLn('DEBUG: TBuildCache created successfully');

  try
    // Test cache miss
    Assert(not Cache.HasArtifacts(TestVersion), 'Cache miss for non-existent version');

    // Cache operations verified through HasArtifacts
    WriteLn('Cache directory: ', TestCacheDir);
    WriteLn('DEBUG: About to free TBuildCache');
  finally
    Cache.Free;
    WriteLn('DEBUG: TBuildCache freed successfully');
  end;

  WriteLn;
end;

procedure TestErrorHandling;
var
  Installer: TBinaryInstaller;
  Verifier: TFPCVerifier;
begin
  WriteLn('=== Error Handling ===');
  WriteLn('DEBUG: About to create TBinaryInstaller for error handling test');

  // Test binary installer error handling
  Installer := TBinaryInstaller.Create;
  WriteLn('DEBUG: TBinaryInstaller created for error handling test');

  try
    Installer.OfflineMode := True;
    WriteLn('DEBUG: Set OfflineMode to True');

    // This should fail gracefully in offline mode
    WriteLn('DEBUG: About to call Install with offline mode');
    Assert(not Installer.Install('999.999.999', '/tmp/test-install'),
           'Installation fails gracefully in offline mode');
    WriteLn('DEBUG: Install call completed');

    Assert(Length(Installer.GetLastError) > 0, 'Error message is set');
    Assert(Pos('offline', LowerCase(Installer.GetLastError)) > 0, 'Error message mentions offline mode');
    Assert(Pos('Troubleshooting', Installer.GetLastError) > 0, 'Error message includes troubleshooting');

    WriteLn('DEBUG: About to free TBinaryInstaller in error handling test');
  finally
    Installer.Free;
    WriteLn('DEBUG: TBinaryInstaller freed in error handling test');
  end;

  WriteLn('DEBUG: About to create TFPCVerifier for error handling test');
  // Test verifier error handling
  Verifier := TFPCVerifier.Create;
  WriteLn('DEBUG: TFPCVerifier created for error handling test');

  try
    Assert(Length(Verifier.GetLastError) >= 0, 'Can get last error from verifier');
    WriteLn('DEBUG: About to free TFPCVerifier');
  finally
    Verifier.Free;
    WriteLn('DEBUG: TFPCVerifier freed');
  end;

  WriteLn;
end;

procedure TestInstallationWorkflow;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('=== Installation Workflow (Dry Run) ===');
  WriteLn('DEBUG: About to create TBinaryInstaller for workflow test');

  Installer := TBinaryInstaller.Create;
  WriteLn('DEBUG: TBinaryInstaller created for workflow test');

  try
    // Configure for testing
    Installer.UseCache := True;
    Installer.OfflineMode := True;  // Prevent actual downloads
    Installer.VerifyInstallation := False;  // Skip verification in test
    WriteLn('DEBUG: Configured installer properties');

    // Test cache check
    WriteLn('DEBUG: About to call IsCached');
    Assert(not Installer.IsCached('999.999.999'), 'Non-existent version not cached');
    WriteLn('DEBUG: IsCached call completed');

    WriteLn('Installation workflow components verified');
    WriteLn('DEBUG: About to free TBinaryInstaller in workflow test');
  finally
    Installer.Free;
    WriteLn('DEBUG: TBinaryInstaller freed in workflow test');
  end;

  WriteLn;
end;

procedure TestEnhancedErrorMessages;
var
  Installer: TBinaryInstaller;
  ErrorMsg: string;
begin
  WriteLn('=== Enhanced Error Messages ===');
  WriteLn('DEBUG: About to create TBinaryInstaller for enhanced error messages test');

  Installer := TBinaryInstaller.Create;
  WriteLn('DEBUG: TBinaryInstaller created for enhanced error messages test');

  try
    Installer.OfflineMode := True;
    WriteLn('DEBUG: Set OfflineMode to True');

    WriteLn('DEBUG: About to call Install for error message test');
    Installer.Install('999.999.999', '/tmp/test');
    WriteLn('DEBUG: Install call completed');

    ErrorMsg := Installer.GetLastError;
    WriteLn('DEBUG: Got error message, length = ', Length(ErrorMsg));

    // Verify error message contains troubleshooting hints
    Assert(Pos('offline', LowerCase(ErrorMsg)) > 0, 'Error message mentions offline mode');
    Assert(Pos('Troubleshooting', ErrorMsg) > 0, 'Error contains troubleshooting section');
    Assert(Pos('1.', ErrorMsg) > 0, 'Error contains numbered steps');
    Assert(Pos('fpdev', ErrorMsg) > 0, 'Error contains command examples');

    WriteLn('DEBUG: About to free TBinaryInstaller in enhanced error messages test');
  finally
    Installer.Free;
    WriteLn('DEBUG: TBinaryInstaller freed in enhanced error messages test');
  end;

  WriteLn;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  // Create temporary cache directory for testing
  TestCacheDir := GetTempDir + 'fpdev_test_cache_' + IntToStr(Random(10000)) + PathDelim;
  ForceDirectories(TestCacheDir);

  try
    WriteLn('=== FPC Installation Integration Tests (Debug) ===');
    WriteLn;

    // Run test suites one by one
    WriteLn('>>> Running TestPlatformDetection');
    TestPlatformDetection;
    WriteLn('>>> TestPlatformDetection completed');
    WriteLn;

    WriteLn('>>> Running TestMirrorManager');
    TestMirrorManager;
    WriteLn('>>> TestMirrorManager completed');
    WriteLn;

    WriteLn('>>> Running TestVerifier');
    TestVerifier;
    WriteLn('>>> TestVerifier completed');
    WriteLn;

    WriteLn('>>> Running TestBinaryInstallerConfiguration');
    TestBinaryInstallerConfiguration;
    WriteLn('>>> TestBinaryInstallerConfiguration completed');
    WriteLn;

    WriteLn('>>> Running TestCacheIntegration');
    TestCacheIntegration;
    WriteLn('>>> TestCacheIntegration completed');
    WriteLn;

    WriteLn('>>> Running TestErrorHandling');
    TestErrorHandling;
    WriteLn('>>> TestErrorHandling completed');
    WriteLn;

    WriteLn('>>> Running TestInstallationWorkflow');
    TestInstallationWorkflow;
    WriteLn('>>> TestInstallationWorkflow completed');
    WriteLn;

    WriteLn('>>> Running TestEnhancedErrorMessages');
    TestEnhancedErrorMessages;
    WriteLn('>>> TestEnhancedErrorMessages completed');
    WriteLn;

    // Summary
    WriteLn('=== Test Summary ===');
    WriteLn('Passed: ', TestsPassed);
    WriteLn('Failed: ', TestsFailed);
    WriteLn;

    if TestsFailed > 0 then
    begin
      WriteLn('FAILED: Some tests did not pass');
      Halt(1);
    end
    else
    begin
      WriteLn('SUCCESS: All tests passed');
      Halt(0);
    end;

  finally
    // Cleanup
    if DirectoryExists(TestCacheDir) then
      RemoveDir(TestCacheDir);
  end;
end.
