program test_bootstrap_integration;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, opensslsockets, fpdev.fpc.source, fpdev.config;

var
  TestRootDir: string;
  ConfigManager: TFPDevConfigManager;
  SourceManager: TFPCSourceManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
begin
  // Create test root directory in temp
  TestRootDir := GetTempDir + 'test_bootstrap_integration_' + IntToStr(GetTickCount64);
  ForceDirectories(TestRootDir);

  // Initialize config manager
  ConfigManager := TFPDevConfigManager.Create;
  ConfigManager.LoadConfig;

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
  procedure DeleteDirectory(const DirPath: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if not DirectoryExists(DirPath) then Exit;

    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          FilePath := DirPath + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath)
          else
            DeleteFile(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(DirPath);
  end;

begin
  if DirectoryExists(TestRootDir) then
    DeleteDirectory(TestRootDir);

  if Assigned(SourceManager) then
    SourceManager.Free;
  if Assigned(ConfigManager) then
    ConfigManager.Free;

  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  WriteLn('========================================');
end;

procedure AssertTrue(const Condition: Boolean; const TestName, Message: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  ', Message);
    Inc(TestsFailed);
  end;
end;

procedure AssertEquals(const Expected, Actual, TestName: string);
begin
  if Expected = Actual then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  Expected: "', Expected, '"');
    WriteLn('  Actual:   "', Actual, '"');
    Inc(TestsFailed);
  end;
end;

// ============================================================================
// Test 1: EnsureBootstrapCompiler Integration (Mock System)
// ============================================================================
procedure TestEnsureBootstrapIntegration;
var
  Settings: TFPDevSettings;
  BootstrapPath, RequiredVer: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: EnsureBootstrapCompiler Integration');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Test bootstrap requirement detection
    RequiredVer := SourceManager.GetRequiredBootstrapVersion('3.2.2');
    AssertEquals('3.0.4', RequiredVer, 'Bootstrap version requirement correct');

    // Test bootstrap path generation
    BootstrapPath := SourceManager.GetBootstrapPath('3.0.4');
    AssertTrue(Pos('bootstrap', BootstrapPath) > 0, 'Bootstrap path contains "bootstrap"',
      'Path: ' + BootstrapPath);

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'EnsureBootstrap integration succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: Bootstrap Download URL Correctness
// ============================================================================
procedure TestBootstrapURLCorrectness;
var
  Settings: TFPDevSettings;
  URL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: Bootstrap Download URL Correctness');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Generate download URL
    URL := SourceManager.GetBootstrapDownloadURL('3.0.4');

    // Verify URL structure
    AssertTrue(Pos('sourceforge.net', URL) > 0, 'URL contains sourceforge.net',
      'URL: ' + URL);
    AssertTrue(Pos('3.0.4', URL) > 0, 'URL contains version 3.0.4',
      'URL: ' + URL);
    {$IFDEF MSWINDOWS}
    AssertTrue(Pos('Win', URL) > 0, 'URL contains Windows platform',
      'URL: ' + URL);
    {$ENDIF}

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'URL correctness test succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: Bootstrap Path After Download (Simulated)
// ============================================================================
procedure TestBootstrapPathAfterDownload;
var
  Settings: TFPDevSettings;
  BootstrapDir, BootstrapBinDir, BootstrapExe: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: Bootstrap Path After Download (Simulated)');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Simulate bootstrap directory structure
    BootstrapDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'bootstrap' + PathDelim + 'fpc-3.0.4';
    BootstrapBinDir := BootstrapDir + PathDelim + 'bin';
    ForceDirectories(BootstrapBinDir);

    // Create mock fpc executable
    {$IFDEF MSWINDOWS}
    BootstrapExe := BootstrapBinDir + PathDelim + 'fpc.exe';
    {$ELSE}
    BootstrapExe := BootstrapBinDir + PathDelim + 'fpc';
    {$ENDIF}

    // Create mock file
    with TStringList.Create do
    try
      Add('#!/bin/sh');
      Add('echo "Mock FPC 3.0.4"');
      SaveToFile(BootstrapExe);
    finally
      Free;
    end;

    // Verify bootstrap path detection
    AssertTrue(FileExists(BootstrapExe), 'Mock bootstrap executable created',
      'Path: ' + BootstrapExe);

    AssertTrue(SourceManager.GetBootstrapPath('3.0.4') = BootstrapExe,
      'GetBootstrapPath returns correct path',
      'Expected: ' + BootstrapExe + ', Got: ' + SourceManager.GetBootstrapPath('3.0.4'));

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'Bootstrap path test succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 4: End-to-End Bootstrap Download (Network-Dependent)
// ============================================================================
procedure TestEndToEndBootstrapDownload;
var
  Settings: TFPDevSettings;
  DownloadResult: Boolean;
  BootstrapPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: End-to-End Bootstrap Download (Network-Dependent)');
  WriteLn('==================================================');
  WriteLn('  [INFO] This test requires network access to SourceForge');
  WriteLn('  [INFO] May fail in CI or restricted environments');
  WriteLn;

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Attempt to download bootstrap (use older version to reduce download time)
    WriteLn('  Attempting to download bootstrap compiler 2.6.4...');
    WriteLn('  (Using older version to reduce download time)');
    WriteLn;

    DownloadResult := SourceManager.DownloadBootstrapCompiler('2.6.4');

    if DownloadResult then
    begin
      WriteLn('  Download succeeded!');

      // Verify bootstrap executable exists
      BootstrapPath := SourceManager.GetBootstrapPath('2.6.4');
      AssertTrue(FileExists(BootstrapPath), 'Bootstrap executable exists after download',
        'Path: ' + BootstrapPath);
    end
    else
    begin
      WriteLn('  Download failed (expected in CI or restricted networks)');
      WriteLn('  [INFO] Test marked as skipped');
    end;

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
    begin
      WriteLn('  Download exception: ', E.Message);
      WriteLn('  [INFO] Test marked as skipped (network-dependent)');
    end;
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Bootstrap Integration Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestEnsureBootstrapIntegration;
      TestBootstrapURLCorrectness;
      TestBootstrapPathAfterDownload;
      TestEndToEndBootstrapDownload;

      // Exit with error if any critical tests failed
      // Note: Test 4 (network-dependent) doesn't fail the suite
      if TestsFailed > 0 then
        ExitCode := 1
      else
        ExitCode := 0;

    finally
      CleanupTestEnvironment;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite crashed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
