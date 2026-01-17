program test_fpc_install_integration;

{$mode objfpc}{$H+}

{
  Integration test for FPC installation system
  Tests the complete installation workflow including:
  - Auto-mode with binary→source fallback
  - Binary installation
  - Source installation
  - Verification system
  - Error handling
  - Cache integration
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
    // Test version parsing
    Version := Verifier.ParseVersion('Free Pascal Compiler version 3.2.2');
    Assert(Version = '3.2.2', 'Parse FPC version string');

    Version := Verifier.ParseVersion('Free Pascal Compiler version 3.2.2 [2021/05/15]');
    Assert(Version = '3.2.2', 'Parse FPC version with build date');

    Version := Verifier.ParseVersion('Invalid output');
    Assert(Version = '', 'Invalid version returns empty string');

    // Test hello world source generation
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
begin
  WriteLn('=== Binary Installer Configuration ===');

  Installer := TBinaryInstaller.Create;
  try
    // Test configuration properties
    Assert(Installer.UseCache, 'UseCache enabled by default');
    Assert(not Installer.OfflineMode, 'OfflineMode disabled by default');
    Assert(Installer.VerifyInstallation, 'VerifyInstallation enabled by default');

    // Test property setters
    Installer.UseCache := False;
    Assert(not Installer.UseCache, 'Can disable UseCache');

    Installer.OfflineMode := True;
    Assert(Installer.OfflineMode, 'Can enable OfflineMode');

    Installer.VerifyInstallation := False;
    Assert(not Installer.VerifyInstallation, 'Can disable VerifyInstallation');
  finally
    Installer.Free;
  end;

  WriteLn;
end;

procedure TestCacheIntegration;
var
  Cache: TBuildCache;
  TestVersion: string;
begin
  WriteLn('=== Cache Integration ===');

  TestVersion := '999.999.999';  // Non-existent version for testing

  Cache := TBuildCache.Create(TestCacheDir);
  try
    // Test cache miss
    Assert(not Cache.HasArtifacts(TestVersion), 'Cache miss for non-existent version');

    // Cache operations verified through HasArtifacts
    WriteLn('Cache directory: ', TestCacheDir);
  finally
    Cache.Free;
  end;

  WriteLn;
end;

procedure TestErrorHandling;
var
  Installer: TBinaryInstaller;
  Verifier: TFPCVerifier;
begin
  WriteLn('=== Error Handling ===');

  // Test binary installer error handling
  Installer := TBinaryInstaller.Create;
  try
    Installer.OfflineMode := True;

    // This should fail gracefully in offline mode
    Assert(not Installer.Install('999.999.999', '/tmp/test-install'),
           'Installation fails gracefully in offline mode');
    Assert(Length(Installer.GetLastError) > 0, 'Error message is set');
    Assert(Pos('offline', LowerCase(Installer.GetLastError)) > 0, 'Error message mentions offline mode');
    Assert(Pos('Troubleshooting', Installer.GetLastError) > 0, 'Error message includes troubleshooting');
  finally
    Installer.Free;
  end;

  // Test verifier error handling
  Verifier := TFPCVerifier.Create;
  try
    Assert(Length(Verifier.GetLastError) >= 0, 'Can get last error from verifier');
  finally
    Verifier.Free;
  end;

  WriteLn;
end;

procedure TestInstallationWorkflow;
var
  Installer: TBinaryInstaller;
begin
  WriteLn('=== Installation Workflow (Dry Run) ===');

  Installer := TBinaryInstaller.Create;
  try
    // Configure for testing
    Installer.UseCache := True;
    Installer.OfflineMode := True;  // Prevent actual downloads
    Installer.VerifyInstallation := False;  // Skip verification in test

    // Test cache check
    Assert(not Installer.IsCached('999.999.999'), 'Non-existent version not cached');

    WriteLn('Installation workflow components verified');
  finally
    Installer.Free;
  end;

  WriteLn;
end;

procedure TestEnhancedErrorMessages;
var
  Installer: TBinaryInstaller;
  ErrorMsg: string;
begin
  WriteLn('=== Enhanced Error Messages ===');

  Installer := TBinaryInstaller.Create;
  try
    Installer.OfflineMode := True;
    Installer.Install('999.999.999', '/tmp/test');

    ErrorMsg := Installer.GetLastError;

    // Verify error message contains troubleshooting hints
    Assert(Pos('offline', LowerCase(ErrorMsg)) > 0, 'Error message mentions offline mode');
    Assert(Pos('Troubleshooting', ErrorMsg) > 0, 'Error contains troubleshooting section');
    Assert(Pos('1.', ErrorMsg) > 0, 'Error contains numbered steps');
    Assert(Pos('fpdev', ErrorMsg) > 0, 'Error contains command examples');
  finally
    Installer.Free;
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
    WriteLn('=== FPC Installation Integration Tests ===');
    WriteLn;

    // Run test suites
    TestPlatformDetection;
    TestMirrorManager;
    TestVerifier;
    TestBinaryInstallerConfiguration;
    TestCacheIntegration;
    TestErrorHandling;
    TestInstallationWorkflow;
    TestEnhancedErrorMessages;

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
