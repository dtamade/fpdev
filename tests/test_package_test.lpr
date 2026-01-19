program test_package_test;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, Process, fpjson, jsonparser, fpdev.cmd.package.test;

type
  { TPackageTestTest }
  TPackageTestTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestDataDir: string;
    FTempDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestDirectory(const ADirName: string);
    procedure CreateTestFile(const AFileName, AContent: string);
    procedure CreateTestArchive(const AArchiveName: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for package testing (Red Phase - these will fail initially)
    procedure TestExtractPackageToTempDir;
    procedure TestExtractInvalidArchive;
    procedure TestLoadPackageMetadata;
    procedure TestInstallDependencies;
    procedure TestRunTestScript;
    procedure TestCleanupTempDir;
    procedure TestTestFailureHandling;
    procedure TestMissingTestScript;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageTestTest }

constructor TPackageTestTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test data directory
  FTestDataDir := 'test_package_test_data';
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);
end;

destructor TPackageTestTest.Destroy;
begin
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackageTestTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageTestTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageTestTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageTestTest.CreateTestDirectory(const ADirName: string);
var
  FullPath: string;
begin
  FullPath := FTestDataDir + PathDelim + ADirName;
  if not DirectoryExists(FullPath) then
    ForceDirectories(FullPath);
end;

procedure TPackageTestTest.CreateTestFile(const AFileName, AContent: string);
var
  F: TextFile;
  FullPath: string;
begin
  FullPath := FTestDataDir + PathDelim + AFileName;
  AssignFile(F, FullPath);
  try
    Rewrite(F);
    Write(F, AContent);
  finally
    CloseFile(F);
  end;
end;

procedure TPackageTestTest.CreateTestArchive(const AArchiveName: string);
var
  ArchivePath: string;
  Process: TProcess;
begin
  // Create a simple test package structure
  CreateTestDirectory('testpkg-1.0.0');
  CreateTestDirectory('testpkg-1.0.0' + PathDelim + 'src');
  CreateTestFile('testpkg-1.0.0' + PathDelim + 'package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test package"}');
  CreateTestFile('testpkg-1.0.0' + PathDelim + 'src' + PathDelim + 'testpkg.pas',
    'unit testpkg; interface implementation end.');

  // Create tar.gz archive
  ArchivePath := FTestDataDir + PathDelim + AArchiveName;
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'tar';
    Process.Parameters.Add('-czf');
    Process.Parameters.Add(ArchivePath);
    Process.Parameters.Add('-C');
    Process.Parameters.Add(FTestDataDir);
    Process.Parameters.Add('testpkg-1.0.0');
    Process.Options := [poWaitOnExit];
    Process.Execute;
  finally
    Process.Free;
  end;
end;

procedure TPackageTestTest.CleanupTestFiles;

  procedure DeleteDirectory(const ADir: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            FilePath := ADir + PathDelim + SR.Name;
            if (SR.Attr and faDirectory) <> 0 then
              DeleteDirectory(FilePath)
            else
              DeleteFile(FilePath);
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    RemoveDir(ADir);
  end;

begin
  if DirectoryExists(FTestDataDir) then
    DeleteDirectory(FTestDataDir);

  // Clean up temp directory if it exists
  if (FTempDir <> '') and DirectoryExists(FTempDir) then
    DeleteDirectory(FTempDir);
end;

procedure TPackageTestTest.TestExtractPackageToTempDir;
var
  Cmd: TPackageTestCommand;
  ArchivePath: string;
  ExtractedDir: string;
begin
  WriteLn;
  WriteLn('=== Test: Extract Package To Temp Dir ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test archive
  CreateTestArchive('testpkg-1.0.0.tar.gz');
  ArchivePath := FTestDataDir + PathDelim + 'testpkg-1.0.0.tar.gz';

  Cmd := TPackageTestCommand.Create;
  try
    ExtractedDir := Cmd.ExtractToTempDir(ArchivePath);
    AssertTrue(ExtractedDir <> '', 'Should return extracted directory path');
    AssertTrue(DirectoryExists(ExtractedDir), 'Extracted directory should exist');

    // Store temp dir for cleanup
    FTempDir := ExtractedDir;
  finally
    Cmd.Free;
  end;
end;

procedure TPackageTestTest.TestExtractInvalidArchive;
var
  Cmd: TPackageTestCommand;
  InvalidPath: string;
  ExtractedDir: string;
begin
  WriteLn;
  WriteLn('=== Test: Extract Invalid Archive ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create invalid archive (just a text file)
  CreateTestFile('invalid.tar.gz', 'This is not a valid tar.gz file');
  InvalidPath := FTestDataDir + PathDelim + 'invalid.tar.gz';

  Cmd := TPackageTestCommand.Create;
  try
    ExtractedDir := Cmd.ExtractToTempDir(InvalidPath);
    AssertTrue(ExtractedDir = '', 'Should return empty string for invalid archive');
    AssertTrue(Cmd.GetLastError <> '', 'Should set error message for invalid archive');
  finally
    Cmd.Free;
  end;
end;

procedure TPackageTestTest.TestLoadPackageMetadata;
var
  MetaPath: string;
  J: TJSONData;
  O: TJSONObject;
begin
  WriteLn;
  WriteLn('=== Test: Load Package Metadata ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test package.json
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test package","scripts":{"test":"echo test"}}');

  MetaPath := FTestDataDir + PathDelim + 'package.json';

  // Load and validate metadata
  try
    J := GetJSON(TFileStream.Create(MetaPath, fmOpenRead or fmShareDenyWrite));
    try
      if J is TJSONObject then
      begin
        O := TJSONObject(J);
        AssertEquals('testpkg', O.Get('name', ''), 'Should load package name');
        AssertEquals('1.0.0', O.Get('version', ''), 'Should load package version');
        AssertTrue(O.Find('scripts') <> nil, 'Should have scripts section');
      end
      else
        AssertTrue(False, 'package.json should be a JSON object');
    finally
      J.Free;
    end;
  except
    on E: Exception do
      AssertTrue(False, 'Should load package.json: ' + E.Message);
  end;
end;

procedure TPackageTestTest.TestInstallDependencies;
var
  Cmd: TPackageTestCommand;
begin
  WriteLn;
  WriteLn('=== Test: Install Dependencies ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test package with dependencies
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","dependencies":{"libfoo":">=1.0.0"}}');

  Cmd := TPackageTestCommand.Create;
  try
    AssertTrue(Cmd.InstallDependencies(FTestDataDir), 'Should install package dependencies');
  finally
    Cmd.Free;
  end;
end;

procedure TPackageTestTest.TestRunTestScript;
var
  Cmd: TPackageTestCommand;
begin
  WriteLn;
  WriteLn('=== Test: Run Test Script ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test package with test script
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","scripts":{"test":"echo Test passed"}}');

  Cmd := TPackageTestCommand.Create;
  try
    AssertTrue(Cmd.RunTests(FTestDataDir), 'Should run test script from package.json');
  finally
    Cmd.Free;
  end;
end;

procedure TPackageTestTest.TestCleanupTempDir;
var
  Cmd: TPackageTestCommand;
  F: TextFile;
  TestFile: string;
begin
  WriteLn;
  WriteLn('=== Test: Cleanup Temp Dir ===');

  // Create a temporary directory
  FTempDir := GetTempDir + 'fpdev-test-' + IntToStr(Random(99999));
  ForceDirectories(FTempDir);

  // Create some test files in temp dir (directly, not using CreateTestFile)
  TestFile := FTempDir + PathDelim + 'test.txt';
  AssignFile(F, TestFile);
  try
    Rewrite(F);
    Write(F, 'test');
  finally
    CloseFile(F);
  end;

  AssertTrue(DirectoryExists(FTempDir), 'Temp directory should exist before cleanup');

  Cmd := TPackageTestCommand.Create;
  try
    AssertTrue(Cmd.CleanupTempDir(FTempDir), 'Should cleanup temporary directory');
    AssertTrue(not DirectoryExists(FTempDir), 'Temp directory should not exist after cleanup');
  finally
    Cmd.Free;
  end;

  // Clear FTempDir since it's been cleaned up
  FTempDir := '';
end;

procedure TPackageTestTest.TestTestFailureHandling;
var
  Cmd: TPackageTestCommand;
begin
  WriteLn;
  WriteLn('=== Test: Test Failure Handling ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test package with failing test script
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","scripts":{"test":"exit 1"}}');

  Cmd := TPackageTestCommand.Create;
  try
    AssertTrue(not Cmd.RunTests(FTestDataDir), 'Should return false for failing test');
    AssertTrue(Cmd.GetLastError <> '', 'Should set error message for failing test');
  finally
    Cmd.Free;
  end;
end;

procedure TPackageTestTest.TestMissingTestScript;
var
  Cmd: TPackageTestCommand;
begin
  WriteLn;
  WriteLn('=== Test: Missing Test Script ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test package without test script
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0"}');

  Cmd := TPackageTestCommand.Create;
  try
    AssertTrue(not Cmd.RunTests(FTestDataDir), 'Should return false for missing test script');
    AssertTrue(Cmd.GetLastError <> '', 'Should set error message for missing test script');
  finally
    Cmd.Free;
  end;
end;

procedure TPackageTestTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Test Command Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestExtractPackageToTempDir;
  TestExtractInvalidArchive;
  TestLoadPackageMetadata;
  TestInstallDependencies;
  TestRunTestScript;
  TestCleanupTempDir;
  TestTestFailureHandling;
  TestMissingTestScript;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Summary:');
  WriteLn('  Passed: ', FTestsPassed);
  WriteLn('  Failed: ', FTestsFailed);
  WriteLn('  Total:  ', FTestsPassed + FTestsFailed);
  WriteLn('========================================');

  if FTestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('RED PHASE: Tests are expected to fail.');
    WriteLn('Next step: Implement package testing features (Green Phase)');
  end;
end;

var
  Test: TPackageTestTest;
begin
  Randomize;
  Test := TPackageTestTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
