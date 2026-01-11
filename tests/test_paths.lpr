program test_paths;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.paths;

type
  { TPathsTest }
  TPathsTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FSavedDataRoot: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
    procedure AssertNotEmpty(const AValue: string; const AMessage: string);
    procedure AssertContains(const ASubStr, AValue: string; const AMessage: string);
    procedure AssertEndsWith(const ASuffix, AValue: string; const AMessage: string);

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods
    procedure TestGetDataRoot;
    procedure TestGetDataRootEnvOverride;
    procedure TestGetCacheDir;
    procedure TestGetSandboxDir;
    procedure TestGetLogsDir;
    procedure TestGetLocksDir;
    procedure TestGetTempRootDir;
    procedure TestDirectoryCreation;
    procedure TestPathConsistency;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPathsTest }

constructor TPathsTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  // Save current FPDEV_DATA_ROOT if set
  FSavedDataRoot := GetEnvironmentVariable('FPDEV_DATA_ROOT');
end;

destructor TPathsTest.Destroy;
begin
  // Restore FPDEV_DATA_ROOT
  if FSavedDataRoot <> '' then
    SetEnvironmentVariable('FPDEV_DATA_ROOT', PChar(FSavedDataRoot))
  else
    SetEnvironmentVariable('FPDEV_DATA_ROOT', nil);
  inherited Destroy;
end;

procedure TPathsTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure TPathsTest.AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TPathsTest.AssertNotEmpty(const AValue: string; const AMessage: string);
begin
  AssertTrue(AValue <> '', AMessage + ' (got empty string)');
end;

procedure TPathsTest.AssertContains(const ASubStr, AValue: string; const AMessage: string);
begin
  if Pos(ASubStr, AValue) > 0 then
  begin
    Inc(FTestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('FAIL: ', AMessage, ' (expected to contain "', ASubStr, '", got "', AValue, '")');
  end;
end;

procedure TPathsTest.AssertEndsWith(const ASuffix, AValue: string; const AMessage: string);
var
  Actual: string;
begin
  // Normalize path separators and trailing delimiters
  Actual := ExcludeTrailingPathDelimiter(AValue);
  if (Length(Actual) >= Length(ASuffix)) and
     (Copy(Actual, Length(Actual) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix) then
  begin
    Inc(FTestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('FAIL: ', AMessage, ' (expected to end with "', ASuffix, '", got "', AValue, '")');
  end;
end;

procedure TPathsTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== fpdev.paths Test Suite ===');
  WriteLn('');

  TestGetDataRoot;
  TestGetDataRootEnvOverride;
  TestGetCacheDir;
  TestGetSandboxDir;
  TestGetLogsDir;
  TestGetLocksDir;
  TestGetTempRootDir;
  TestDirectoryCreation;
  TestPathConsistency;

  WriteLn('');
  WriteLn('=== Test Results ===');
  WriteLn('Passed: ', FTestsPassed);
  WriteLn('Failed: ', FTestsFailed);
  WriteLn('Total:  ', FTestsPassed + FTestsFailed);
end;

procedure TPathsTest.TestGetDataRoot;
var
  Root: string;
begin
  WriteLn('-- TestGetDataRoot --');

  // Clear env override for this test
  SetEnvironmentVariable('FPDEV_DATA_ROOT', nil);

  Root := GetDataRoot();
  AssertNotEmpty(Root, 'GetDataRoot() should return non-empty string');

  {$IFDEF MSWINDOWS}
  // On Windows, should be in AppData or USERPROFILE
  AssertTrue(
    (Pos('AppData', Root) > 0) or (Pos('fpdev', Root) > 0),
    'GetDataRoot() on Windows should contain AppData or fpdev'
  );
  {$ELSE}
  // On Unix, should be in home directory or XDG_DATA_HOME
  AssertTrue(
    (Pos('.fpdev', Root) > 0) or (Pos('fpdev', Root) > 0),
    'GetDataRoot() on Unix should contain .fpdev or fpdev'
  );
  {$ENDIF}
end;

procedure TPathsTest.TestGetDataRootEnvOverride;
var
  Root: string;
  TestPath: string;
begin
  WriteLn('-- TestGetDataRootEnvOverride --');

  TestPath := GetTempDir + 'fpdev_test_data_root';
  SetEnvironmentVariable('FPDEV_DATA_ROOT', PChar(TestPath));

  Root := GetDataRoot();
  AssertTrue(Root = TestPath, 'GetDataRoot() should respect FPDEV_DATA_ROOT env var');

  // Clean up
  SetEnvironmentVariable('FPDEV_DATA_ROOT', nil);
end;

procedure TPathsTest.TestGetCacheDir;
var
  Dir: string;
begin
  WriteLn('-- TestGetCacheDir --');
  Dir := GetCacheDir();
  AssertNotEmpty(Dir, 'GetCacheDir() should return non-empty string');
  AssertEndsWith('cache', Dir, 'GetCacheDir() should end with "cache"');
  AssertTrue(DirectoryExists(Dir), 'GetCacheDir() should create directory if not exists');
end;

procedure TPathsTest.TestGetSandboxDir;
var
  Dir: string;
begin
  WriteLn('-- TestGetSandboxDir --');
  Dir := GetSandboxDir();
  AssertNotEmpty(Dir, 'GetSandboxDir() should return non-empty string');
  AssertEndsWith('sandbox', Dir, 'GetSandboxDir() should end with "sandbox"');
  AssertTrue(DirectoryExists(Dir), 'GetSandboxDir() should create directory if not exists');
end;

procedure TPathsTest.TestGetLogsDir;
var
  Dir: string;
begin
  WriteLn('-- TestGetLogsDir --');
  Dir := GetLogsDir();
  AssertNotEmpty(Dir, 'GetLogsDir() should return non-empty string');
  AssertEndsWith('logs', Dir, 'GetLogsDir() should end with "logs"');
  AssertTrue(DirectoryExists(Dir), 'GetLogsDir() should create directory if not exists');
end;

procedure TPathsTest.TestGetLocksDir;
var
  Dir: string;
begin
  WriteLn('-- TestGetLocksDir --');
  Dir := GetLocksDir();
  AssertNotEmpty(Dir, 'GetLocksDir() should return non-empty string');
  AssertEndsWith('locks', Dir, 'GetLocksDir() should end with "locks"');
  AssertTrue(DirectoryExists(Dir), 'GetLocksDir() should create directory if not exists');
end;

procedure TPathsTest.TestGetTempRootDir;
var
  Dir: string;
begin
  WriteLn('-- TestGetTempRootDir --');
  Dir := GetTempRootDir();
  AssertNotEmpty(Dir, 'GetTempRootDir() should return non-empty string');
  AssertEndsWith('tmp', Dir, 'GetTempRootDir() should end with "tmp"');
  AssertTrue(DirectoryExists(Dir), 'GetTempRootDir() should create directory if not exists');
end;

procedure TPathsTest.TestDirectoryCreation;
var
  TestRoot: string;
  CacheDir, SandboxDir, LogsDir: string;
begin
  WriteLn('-- TestDirectoryCreation --');

  // Use a unique test directory
  TestRoot := GetTempDir + 'fpdev_paths_test_' + IntToStr(Random(100000));
  SetEnvironmentVariable('FPDEV_DATA_ROOT', PChar(TestRoot));

  try
    // These calls should create directories
    CacheDir := GetCacheDir();
    SandboxDir := GetSandboxDir();
    LogsDir := GetLogsDir();

    AssertTrue(DirectoryExists(CacheDir), 'GetCacheDir() should auto-create directory');
    AssertTrue(DirectoryExists(SandboxDir), 'GetSandboxDir() should auto-create directory');
    AssertTrue(DirectoryExists(LogsDir), 'GetLogsDir() should auto-create directory');

  finally
    // Cleanup
    SetEnvironmentVariable('FPDEV_DATA_ROOT', nil);
    // Remove test directories
    RemoveDir(CacheDir);
    RemoveDir(SandboxDir);
    RemoveDir(LogsDir);
    RemoveDir(TestRoot + PathDelim + 'locks');
    RemoveDir(TestRoot + PathDelim + 'tmp');
    RemoveDir(TestRoot);
  end;
end;

procedure TPathsTest.TestPathConsistency;
var
  DataRoot: string;
  CacheDir, SandboxDir, LogsDir, LocksDir, TempDir: string;
begin
  WriteLn('-- TestPathConsistency --');

  DataRoot := GetDataRoot();
  CacheDir := GetCacheDir();
  SandboxDir := GetSandboxDir();
  LogsDir := GetLogsDir();
  LocksDir := GetLocksDir();
  TempDir := GetTempRootDir();

  // All subdirectories should be under DataRoot
  AssertTrue(Pos(DataRoot, CacheDir) = 1, 'CacheDir should be under DataRoot');
  AssertTrue(Pos(DataRoot, SandboxDir) = 1, 'SandboxDir should be under DataRoot');
  AssertTrue(Pos(DataRoot, LogsDir) = 1, 'LogsDir should be under DataRoot');
  AssertTrue(Pos(DataRoot, LocksDir) = 1, 'LocksDir should be under DataRoot');
  AssertTrue(Pos(DataRoot, TempDir) = 1, 'TempDir should be under DataRoot');
end;

var
  Test: TPathsTest;
begin
  Randomize;
  Test := TPathsTest.Create;
  try
    Test.RunAllTests;

    if Test.TestsFailed > 0 then
      ExitCode := 1
    else
      ExitCode := 0;
  finally
    Test.Free;
  end;
end.
