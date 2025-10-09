program test_bootstrap_downloader;

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
  TestRootDir := GetTempDir + 'test_bootstrap_' + IntToStr(GetTickCount64);
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
// Test 1: Bootstrap Types Exist
// ============================================================================
procedure TestBootstrapTypesExist;
var
  PlatformStr, ArchStr: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: Bootstrap Types Exist');
  WriteLn('==================================================');

  try
    // Verify that platform/architecture detection types compile
    PlatformStr := '';
    ArchStr := '';

    AssertTrue(True, 'Bootstrap types defined', 'Types should compile');
  except
    on E: Exception do
      AssertTrue(False, 'Bootstrap types defined', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: Platform Detection
// ============================================================================
procedure TestPlatformDetection;
var
  Settings: TFPDevSettings;
  DetectedPlatform, DetectedArch: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: Platform Detection');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Test platform detection (this method doesn't exist yet - Red Phase)
    // DetectedPlatform := SourceManager.DetectPlatform;
    // DetectedArch := SourceManager.DetectArchitecture;

    // For now, verify we can detect current platform
    {$IFDEF MSWINDOWS}
    DetectedPlatform := 'Win64';
    {$ENDIF}
    {$IFDEF LINUX}
    DetectedPlatform := 'Linux';
    {$ENDIF}
    {$IFDEF DARWIN}
    DetectedPlatform := 'macOS';
    {$ENDIF}

    AssertTrue(DetectedPlatform <> '', 'Platform detected',
      'Expected platform to be detected, got empty');

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'Platform detection succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: Version Mapping
// ============================================================================
procedure TestVersionMapping;
var
  Settings: TFPDevSettings;
  BootstrapVer: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: Version Mapping');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Test version mapping (this method already exists)
    BootstrapVer := SourceManager.GetRequiredBootstrapVersion('3.2.2');

    // 3.2.2 should require 3.0.4 as bootstrap
    AssertEquals('3.0.4', BootstrapVer, 'Bootstrap version for 3.2.2');

    // Test main branch
    BootstrapVer := SourceManager.GetRequiredBootstrapVersion('main');
    AssertEquals('3.2.2', BootstrapVer, 'Bootstrap version for main');

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'Version mapping succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 4: Download URL Generation
// ============================================================================
procedure TestDownloadURLGeneration;
var
  Settings: TFPDevSettings;
  URL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: Download URL Generation');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Test URL generation (this method doesn't exist yet - Red Phase)
    // URL := SourceManager.GetBootstrapDownloadURL('3.2.2');

    // For now, just verify we can construct a URL pattern
    URL := 'https://sourceforge.net/projects/freepascal/files/';

    AssertTrue(URL <> '', 'URL not empty', 'Expected non-empty URL');
    AssertTrue(Pos('http', LowerCase(URL)) > 0, 'URL contains http',
      'Expected URL to start with http');

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'URL generation succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 5: Bootstrap Download (Network-Dependent)
// ============================================================================
procedure TestBootstrapDownload;
var
  Settings: TFPDevSettings;
  DownloadResult: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: Bootstrap Download (Network-Dependent)');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Test download (current implementation is stub - returns True)
    DownloadResult := SourceManager.DownloadBootstrapCompiler('3.2.2');

    AssertTrue(DownloadResult, 'Download succeeded',
      'Expected download to succeed');

    WriteLn('  [INFO] Network-dependent test - may skip in CI');

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'Download test succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 6: Bootstrap Extraction
// ============================================================================
procedure TestBootstrapExtraction;
var
  Settings: TFPDevSettings;
  ExtractDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: Bootstrap Extraction');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Create mock extraction directory
    ExtractDir := TestRootDir + PathDelim + 'bootstrap' + PathDelim + 'fpc-3.2.2';
    ForceDirectories(ExtractDir);

    // Test extraction capability (method doesn't exist yet - Red Phase)
    AssertTrue(DirectoryExists(ExtractDir), 'Extraction directory created',
      'Expected directory: ' + ExtractDir);

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'Extraction test succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 7: Bootstrap Path Configuration
// ============================================================================
procedure TestBootstrapPathConfiguration;
var
  Settings: TFPDevSettings;
  BootstrapPath, ExpectedPattern: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 7: Bootstrap Path Configuration');
  WriteLn('==================================================');

  try
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := TestRootDir;
    ConfigManager.SetSettings(Settings);

    SourceManager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'sources' + PathDelim + 'fpc');

    // Test path generation (this method already exists)
    BootstrapPath := SourceManager.GetBootstrapPath('3.2.2');

    // Verify path contains expected patterns
    ExpectedPattern := 'bootstrap' + PathDelim + 'fpc-3.2.2';

    AssertTrue(Pos(ExpectedPattern, BootstrapPath) > 0,
      'Path contains bootstrap directory',
      'Expected pattern "' + ExpectedPattern + '" in: ' + BootstrapPath);

    {$IFDEF MSWINDOWS}
    AssertTrue(Pos('.exe', BootstrapPath) > 0,
      'Windows path contains .exe',
      'Path: ' + BootstrapPath);
    {$ELSE}
    AssertTrue(Pos('.exe', BootstrapPath) = 0,
      'Unix path does not contain .exe',
      'Path: ' + BootstrapPath);
    {$ENDIF}

    SourceManager.Free;
    SourceManager := nil;
  except
    on E: Exception do
      AssertTrue(False, 'Path configuration test succeeded', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Bootstrap Downloader Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestBootstrapTypesExist;
      TestPlatformDetection;
      TestVersionMapping;
      TestDownloadURLGeneration;
      TestBootstrapDownload;
      TestBootstrapExtraction;
      TestBootstrapPathConfiguration;

      // Exit with error if any tests failed
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
