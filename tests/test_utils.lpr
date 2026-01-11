program test_utils;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.utils;

type
  { TUtilsTest }
  TUtilsTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTempDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
    procedure AssertNotEmpty(const AValue: string; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertGreaterThan(const AValue, AMin: Int64; const AMessage: string);

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods
    procedure TestExePath;
    procedure TestCwd;
    procedure TestChdir;
    procedure TestGetHomeDir;
    procedure TestGetTmpDir;
    procedure TestGetEnv;
    procedure TestSetEnv;
    procedure TestUnsetEnv;
    procedure TestUname;
    procedure TestGetHostname;
    procedure TestGetCpuCount;
    procedure TestGetPid;
    procedure TestGetPpid;
    procedure TestHrtime;
    procedure TestUptime;
    procedure TestGetFreeMemory;
    procedure TestGetTotalMemory;
    procedure TestSafeWriteAllText;
    procedure TestReadAllTextIfExists;
    procedure TestAvailableParallelism;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TUtilsTest }

constructor TUtilsTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  FTempDir := GetTempDir + 'fpdev_test_utils' + PathDelim;
  if not DirectoryExists(FTempDir) then
    ForceDirectories(FTempDir);
end;

destructor TUtilsTest.Destroy;
begin
  // Cleanup temp directory
  if DirectoryExists(FTempDir) then
  begin
    // Simple cleanup - delete test files
    DeleteFile(FTempDir + 'test_write.txt');
    RemoveDir(FTempDir);
  end;
  inherited Destroy;
end;

procedure TUtilsTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TUtilsTest.AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TUtilsTest.AssertNotEmpty(const AValue: string; const AMessage: string);
begin
  AssertTrue(AValue <> '', AMessage + ' (got empty string)');
end;

procedure TUtilsTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  if AExpected = AActual then
  begin
    Inc(FTestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('FAIL: ', AMessage, ' (expected "', AExpected, '", got "', AActual, '")');
  end;
end;

procedure TUtilsTest.AssertGreaterThan(const AValue, AMin: Int64; const AMessage: string);
begin
  if AValue > AMin then
  begin
    Inc(FTestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('FAIL: ', AMessage, ' (expected > ', AMin, ', got ', AValue, ')');
  end;
end;

procedure TUtilsTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== fpdev.utils Test Suite ===');
  WriteLn('');

  TestExePath;
  TestCwd;
  TestChdir;
  TestGetHomeDir;
  TestGetTmpDir;
  TestGetEnv;
  TestSetEnv;
  TestUnsetEnv;
  TestUname;
  TestGetHostname;
  TestGetCpuCount;
  TestGetPid;
  TestGetPpid;
  TestHrtime;
  TestUptime;
  TestGetFreeMemory;
  TestGetTotalMemory;
  TestSafeWriteAllText;
  TestReadAllTextIfExists;
  TestAvailableParallelism;

  WriteLn('');
  WriteLn('=== Test Results ===');
  WriteLn('Passed: ', FTestsPassed);
  WriteLn('Failed: ', FTestsFailed);
  WriteLn('Total:  ', FTestsPassed + FTestsFailed);
end;

procedure TUtilsTest.TestExePath;
var
  Path: string;
begin
  WriteLn('-- TestExePath --');
  Path := exepath();
  AssertNotEmpty(Path, 'exepath() should return non-empty string');
  AssertTrue(FileExists(Path), 'exepath() should return existing file path');
end;

procedure TUtilsTest.TestCwd;
var
  Dir: string;
begin
  WriteLn('-- TestCwd --');
  Dir := cwd();
  AssertNotEmpty(Dir, 'cwd() should return non-empty string');
  AssertTrue(DirectoryExists(Dir), 'cwd() should return existing directory');
end;

procedure TUtilsTest.TestChdir;
var
  OrigDir, NewDir: string;
begin
  WriteLn('-- TestChdir --');
  OrigDir := cwd();

  // Change to temp directory
  AssertTrue(chdir(FTempDir), 'chdir() should succeed for valid directory');
  NewDir := cwd();
  AssertTrue(Pos('fpdev_test_utils', NewDir) > 0, 'cwd() should reflect directory change');

  // Change back
  AssertTrue(chdir(OrigDir), 'chdir() should succeed returning to original directory');

  // Try invalid directory
  AssertFalse(chdir('/nonexistent_directory_12345'), 'chdir() should fail for invalid directory');
end;

procedure TUtilsTest.TestGetHomeDir;
var
  Home: string;
begin
  WriteLn('-- TestGetHomeDir --');
  Home := get_home_dir();
  AssertNotEmpty(Home, 'get_home_dir() should return non-empty string');
  AssertTrue(DirectoryExists(Home), 'get_home_dir() should return existing directory');
end;

procedure TUtilsTest.TestGetTmpDir;
var
  Tmp: string;
begin
  WriteLn('-- TestGetTmpDir --');
  Tmp := get_tmp_dir();
  AssertNotEmpty(Tmp, 'get_tmp_dir() should return non-empty string');
  AssertTrue(DirectoryExists(Tmp), 'get_tmp_dir() should return existing directory');
end;

procedure TUtilsTest.TestGetEnv;
var
  Value: string;
  Found: Boolean;
begin
  WriteLn('-- TestGetEnv --');

  // Test PATH environment variable (should exist on all systems)
  Value := get_env('PATH');
  AssertNotEmpty(Value, 'get_env(PATH) should return non-empty string');

  // Test with output parameter
  Found := get_env('PATH', Value);
  AssertTrue(Found, 'get_env(PATH, Value) should return True');
  AssertNotEmpty(Value, 'get_env(PATH, Value) should set non-empty value');

  // Test non-existent variable
  Found := get_env('FPDEV_NONEXISTENT_VAR_12345', Value);
  AssertFalse(Found, 'get_env() should return False for non-existent variable');
end;

procedure TUtilsTest.TestSetEnv;
var
  Value: string;
begin
  WriteLn('-- TestSetEnv --');

  // Set a test variable
  AssertTrue(set_env('FPDEV_TEST_VAR', 'test_value_123'), 'set_env() should succeed');

  // Verify it was set
  Value := get_env('FPDEV_TEST_VAR');
  AssertEquals('test_value_123', Value, 'get_env() should return set value');

  // Clean up
  unset_env('FPDEV_TEST_VAR');
end;

procedure TUtilsTest.TestUnsetEnv;
var
  Value: string;
  Found: Boolean;
begin
  WriteLn('-- TestUnsetEnv --');

  // Set a variable first
  set_env('FPDEV_TEST_UNSET', 'to_be_removed');

  // Unset it
  AssertTrue(unset_env('FPDEV_TEST_UNSET'), 'unset_env() should succeed');

  // Verify it was removed
  Found := get_env('FPDEV_TEST_UNSET', Value);
  AssertFalse(Found, 'get_env() should return False after unset_env()');
end;

procedure TUtilsTest.TestUname;
var
  Info: utsname_t;
begin
  WriteLn('-- TestUname --');
  AssertTrue(uname(@Info), 'uname() should succeed');
  AssertTrue(Info.sysname[0] <> #0, 'uname() should set sysname');
  AssertTrue(Info.machine[0] <> #0, 'uname() should set machine');
end;

procedure TUtilsTest.TestGetHostname;
var
  Host: string;
begin
  WriteLn('-- TestGetHostname --');
  Host := get_hostname();
  AssertNotEmpty(Host, 'get_hostname() should return non-empty string');
end;

procedure TUtilsTest.TestGetCpuCount;
var
  Count: UInt32;
begin
  WriteLn('-- TestGetCpuCount --');
  Count := get_cpu_count();
  AssertGreaterThan(Count, 0, 'get_cpu_count() should return > 0');
end;

procedure TUtilsTest.TestGetPid;
var
  Pid: pid_t;
begin
  WriteLn('-- TestGetPid --');
  Pid := get_pid();
  AssertGreaterThan(Pid, 0, 'get_pid() should return > 0');
end;

procedure TUtilsTest.TestGetPpid;
var
  Ppid: pid_t;
begin
  WriteLn('-- TestGetPpid --');
  Ppid := get_ppid();
  AssertGreaterThan(Ppid, 0, 'get_ppid() should return > 0');
end;

procedure TUtilsTest.TestHrtime;
var
  T1, T2: UInt64;
begin
  WriteLn('-- TestHrtime --');
  T1 := hrtime();
  Sleep(10); // Sleep 10ms
  T2 := hrtime();
  AssertGreaterThan(T2, T1, 'hrtime() should increase over time');
end;

procedure TUtilsTest.TestUptime;
var
  Up: Integer;
begin
  WriteLn('-- TestUptime --');
  Up := uptime();
  AssertGreaterThan(Up, 0, 'uptime() should return > 0');
end;

procedure TUtilsTest.TestGetFreeMemory;
var
  Mem: UInt64;
begin
  WriteLn('-- TestGetFreeMemory --');
  Mem := get_free_memory();
  AssertGreaterThan(Mem, 0, 'get_free_memory() should return > 0');
end;

procedure TUtilsTest.TestGetTotalMemory;
var
  Mem: UInt64;
begin
  WriteLn('-- TestGetTotalMemory --');
  Mem := get_total_memory();
  AssertGreaterThan(Mem, 0, 'get_total_memory() should return > 0');
  AssertGreaterThan(Mem, get_free_memory(), 'get_total_memory() should be >= get_free_memory()');
end;

procedure TUtilsTest.TestSafeWriteAllText;
var
  TestFile: string;
  Content: string;
begin
  WriteLn('-- TestSafeWriteAllText --');
  TestFile := FTempDir + 'test_write.txt';
  Content := 'Hello, World!' + LineEnding + 'Line 2';

  // Write file
  SafeWriteAllText(TestFile, Content);
  AssertTrue(FileExists(TestFile), 'SafeWriteAllText() should create file');

  // Verify content
  AssertEquals(Content + LineEnding, ReadAllTextIfExists(TestFile), 'File content should match written content');
end;

procedure TUtilsTest.TestReadAllTextIfExists;
var
  Content: string;
begin
  WriteLn('-- TestReadAllTextIfExists --');

  // Test non-existent file
  Content := ReadAllTextIfExists('/nonexistent_file_12345.txt');
  AssertEquals('', Content, 'ReadAllTextIfExists() should return empty for non-existent file');

  // Test existing file (created in previous test)
  Content := ReadAllTextIfExists(FTempDir + 'test_write.txt');
  AssertTrue(Pos('Hello', Content) > 0, 'ReadAllTextIfExists() should return file content');
end;

procedure TUtilsTest.TestAvailableParallelism;
var
  P: UInt32;
begin
  WriteLn('-- TestAvailableParallelism --');
  P := available_parallelism();
  AssertGreaterThan(P, 0, 'available_parallelism() should return > 0');
end;

var
  Test: TUtilsTest;
begin
  Test := TUtilsTest.Create;
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
