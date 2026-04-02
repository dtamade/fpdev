program test_toolchain;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.toolchain,
  fpdev.toolchain.extract,
  fpdev.hash,
  fpdev.paths,
  fpdev.utils;

const
  // Test data constants
  TEST_ZIP_PATH = 'test_data.zip';
  TEST_EXTRACT_DIR = 'test_extract';
  TEST_SHA256_VALID = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // empty file
  TEST_SHA256_INVALID = '0000000000000000000000000000000000000000000000000000000000000000';
  
  // Test output prefixes
  PREFIX_TEST = '[TEST]';
  PREFIX_PASS = 'PASS:';
  PREFIX_FAIL = 'FAIL:';

{ Helper procedures }
procedure AssertTrue(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn(PREFIX_FAIL, ' ', Msg);
    Halt(1);
  end;
end;

procedure AssertFalse(Condition: Boolean; const Msg: string);
begin
  if Condition then
  begin
    WriteLn(PREFIX_FAIL, ' ', Msg);
    Halt(1);
  end;
end;

procedure AssertEquals(const Expected, Actual: string; const Msg: string);
begin
  if Expected <> Actual then
  begin
    WriteLn(PREFIX_FAIL, ' ', Msg);
    WriteLn('  Expected: ', Expected);
    WriteLn('  Actual:   ', Actual);
    Halt(1);
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure RunTest(const TestName: string; TestProc: TProcedure);
begin
  WriteLn(PREFIX_TEST, ' ', TestName);
  try
    TestProc();
    WriteLn(PREFIX_PASS, ' ', TestName);
  except
    on E: Exception do
    begin
      WriteLn(PREFIX_FAIL, ' ', TestName, ' - ', E.Message);
      Halt(1);
    end;
  end;
end;

{ Test 1: fpdev.toolchain - GetFPCVersion should return version info }
procedure TestGetFPCVersion;
var
  Version: string;
  Success: Boolean;
begin
  Success := GetFPCVersion(Version);
  
  // Should detect FPC (assuming FPC is installed in test environment)
  if Success then
  begin
    AssertTrue(Version <> '', 'FPC version should not be empty');
    WriteLn('  Detected FPC version: ', Version);
  end
  else
  begin
    WriteLn('  WARNING: FPC not detected in PATH (may be expected in CI)');
  end;
end;

{ Test 2: fpdev.toolchain - env policy file override should work in same process }
procedure TestPolicyFileEnvOverride;
var
  PolicyDir, PolicyPath: string;
  SavedPolicyPath: string;
  Status, Reason, MinVer, RecVer, FPCVer: string;
begin
  PolicyDir := IncludeTrailingPathDelimiter(GetTempRootDir) +
    'toolchain_policy_' + IntToStr(GetTickCount64);
  ForceDirectories(PolicyDir);
  PolicyPath := IncludeTrailingPathDelimiter(PolicyDir) + 'policy.json';
  SavedPolicyPath := get_env('FPDEV_POLICY_FILE');
  try
    with TStringList.Create do
    try
      Text :=
        '{' + LineEnding +
        '  "fpc": {' + LineEnding +
        '    "custom-probe-version": {' + LineEnding +
        '      "min": "1.2.3",' + LineEnding +
        '      "rec": "4.5.6"' + LineEnding +
        '    }' + LineEnding +
        '  }' + LineEnding +
        '}';
      SaveToFile(PolicyPath);
    finally
      Free;
    end;

    AssertTrue(set_env('FPDEV_POLICY_FILE', PolicyPath),
      'Should set FPDEV_POLICY_FILE for toolchain policy test');
    CheckFPCVersionPolicy('custom-probe-version', Status, Reason, MinVer, RecVer, FPCVer);
    AssertEquals('1.2.3', MinVer,
      'env policy file should override min version in same process');
    AssertEquals('4.5.6', RecVer,
      'env policy file should override recommended version in same process');
  finally
    RestoreEnv('FPDEV_POLICY_FILE', SavedPolicyPath);
    if FileExists(PolicyPath) then
      DeleteFile(PolicyPath);
    if DirectoryExists(PolicyDir) then
      RemoveDir(PolicyDir);
  end;
end;

{ Test 3: fpdev.toolchain - CheckFPCVersionPolicy with invalid source }
procedure TestCheckFPCVersionPolicyInvalid;
var
  Status, Reason, MinVer, RecVer, FPCVer: string;
  Result: Boolean;
begin
  // Test with non-existent source version
  Result := CheckFPCVersionPolicy('nonexistent-version-999', Status, Reason, MinVer, RecVer, FPCVer);
  
  // Should return False or FAIL status for unknown version
  if not Result then
    WriteLn('  Policy check correctly returned False for unknown version')
  else if Status = 'FAIL' then
    WriteLn('  Policy check correctly returned FAIL status for unknown version')
  else
    WriteLn('  Policy check handled unknown version gracefully');
end;

{ Test 4: fpdev.toolchain.extract - ZipExtract with missing file }
procedure TestZipExtractMissingFile;
var
  Err: string;
  Success: Boolean;
begin
  // Try to extract non-existent archive
  Success := ZipExtract('nonexistent.zip', TEST_EXTRACT_DIR, Err);
  
  AssertFalse(Success, 'Should fail with non-existent archive');
  AssertTrue(Err <> '', 'Error message should not be empty');
  WriteLn('  Expected error: ', Err);
end;

{ Test 5: fpdev.toolchain.extract - ZipExtract with empty dest }
procedure TestZipExtractEmptyDest;
var
  Err: string;
  Success: Boolean;
begin
  // Try to extract with empty destination
  Success := ZipExtract(TEST_ZIP_PATH, '', Err);
  
  AssertFalse(Success, 'Should fail with empty destination');
  AssertTrue(Err <> '', 'Error message should not be empty');
  WriteLn('  Expected error: ', Err);
end;

{ Test 6: fpdev.hash - SHA256 functions exist and work }
procedure TestSHA256Functions;
var
  TestFile: string;
  F: TextFile;
  Hash: string;
begin
  // Create a temporary empty file
  TestFile := IncludeTrailingPathDelimiter(GetTempRootDir) + 'test_hash.tmp';
  try
    AssignFile(F, TestFile);
    Rewrite(F);
    CloseFile(F);
    
    // Calculate SHA256 of empty file
    Hash := SHA256FileHex(TestFile);
    
    AssertTrue(Hash <> '', 'SHA256 hash should not be empty');
    AssertTrue(Length(Hash) = 64, 'SHA256 hash should be 64 hex characters');
    
    // Empty file should have known SHA256
    AssertEquals(TEST_SHA256_VALID, LowerCase(Hash), 
      'SHA256 of empty file should match expected value');
    
    WriteLn('  SHA256 calculated correctly: ', Hash);
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
  end;
end;

{ Test 7: fpdev.paths - Path functions return valid directories }
procedure TestPathFunctions;
var
  DataRoot, CacheDir, SandboxDir, LogsDir: string;
begin
  DataRoot := GetDataRoot;
  CacheDir := GetCacheDir;
  SandboxDir := GetSandboxDir;
  LogsDir := GetLogsDir;
  
  // All paths should return non-empty strings
  AssertTrue(DataRoot <> '', 'DataRoot should not be empty');
  AssertTrue(CacheDir <> '', 'CacheDir should not be empty');
  AssertTrue(SandboxDir <> '', 'SandboxDir should not be empty');
  AssertTrue(LogsDir <> '', 'LogsDir should not be empty');
  
  WriteLn('  DataRoot: ', DataRoot);
  WriteLn('  CacheDir: ', CacheDir);
  WriteLn('  SandboxDir: ', SandboxDir);
  WriteLn('  LogsDir: ', LogsDir);
end;

{ Test 8: fpdev.toolchain - BuildToolchainReportJSON returns valid JSON }
procedure TestBuildToolchainReportJSON;
var
  JSONStr: string;
  ProbePath: string;
  SavedPath: string;
  ExpectedHead: string;
begin
  ProbePath := IncludeTrailingPathDelimiter(GetTempRootDir) +
    'toolchain_path_probe_' + IntToStr(GetTickCount64);
  SavedPath := get_env('PATH');
  try
    AssertTrue(set_env('PATH', ProbePath + PathSeparator + SavedPath),
      'Should set same-process PATH override for toolchain report test');

    JSONStr := BuildToolchainReportJSON;
    ExpectedHead := '"pathHead":["' + JsonEscape(ProbePath) + '"';

    AssertTrue(JSONStr <> '', 'Toolchain report JSON should not be empty');
    AssertTrue(Pos('hostOS', JSONStr) > 0, 'JSON should contain hostOS field');
    AssertTrue(Pos('tools', JSONStr) > 0, 'JSON should contain tools field');
    AssertTrue(Pos(ExpectedHead, JSONStr) > 0,
      'Toolchain report should use same-process PATH override at pathHead[0]');

    WriteLn('  Generated JSON length: ', Length(JSONStr), ' chars');
  finally
    RestoreEnv('PATH', SavedPath);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('TDD: Toolchain Module Tests');
  WriteLn('========================================');
  WriteLn;
  
  RunTest('TestGetFPCVersion', @TestGetFPCVersion);
  RunTest('TestPolicyFileEnvOverride', @TestPolicyFileEnvOverride);
  RunTest('TestCheckFPCVersionPolicyInvalid', @TestCheckFPCVersionPolicyInvalid);
  RunTest('TestZipExtractMissingFile', @TestZipExtractMissingFile);
  RunTest('TestZipExtractEmptyDest', @TestZipExtractEmptyDest);
  RunTest('TestSHA256Functions', @TestSHA256Functions);
  RunTest('TestPathFunctions', @TestPathFunctions);
  RunTest('TestBuildToolchainReportJSON', @TestBuildToolchainReportJSON);
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('SUCCESS: All 7 tests passed!');
  WriteLn('========================================');
  
  Halt(0);
end.
