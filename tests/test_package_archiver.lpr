program test_package_archiver;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpdev.package.archiver;

type
  { TPackageArchiverTest }
  TPackageArchiverTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestDataDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestDirectory(const ADirName: string);
    procedure CreateTestFile(const AFileName, AContent: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for package archiver (Red Phase - these will fail initially)
    procedure TestDetectSourceFiles;
    procedure TestDetectSourceFilesRecursive;
    procedure TestDetectSourceFilesWithIncludes;
    procedure TestExcludeFilesWithFpdevignore;
    procedure TestCreateTarGzArchive;
    procedure TestGenerateSHA256Checksum;
    procedure TestArchiveStructure;
    procedure TestArchiveWithVersion;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageArchiverTest }

constructor TPackageArchiverTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test data directory
  FTestDataDir := 'test_archiver_data';
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);
end;

destructor TPackageArchiverTest.Destroy;
begin
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackageArchiverTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageArchiverTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageArchiverTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageArchiverTest.CreateTestDirectory(const ADirName: string);
var
  FullPath: string;
begin
  FullPath := FTestDataDir + PathDelim + ADirName;
  if not DirectoryExists(FullPath) then
    ForceDirectories(FullPath);
end;

procedure TPackageArchiverTest.CreateTestFile(const AFileName, AContent: string);
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

procedure TPackageArchiverTest.CleanupTestFiles;

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
end;

procedure TPackageArchiverTest.TestDetectSourceFiles;
var
  Archiver: TPackageArchiver;
  Files: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Detect Source Files ===');

  // Clean up first to ensure no leftover files
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test source files directly in root (non-recursive test)
  CreateTestFile('mylib.pas', 'unit mylib; interface implementation end.');
  CreateTestFile('mylib.utils.pas', 'unit mylib.utils; interface implementation end.');

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    Files := Archiver.DetectSourceFiles(False); // Non-recursive
    try
      AssertEqualsInt(2, Files.Count, 'Should detect 2 .pas files in root directory');
    finally
      Files.Free;
    end;
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestDetectSourceFilesRecursive;
var
  Archiver: TPackageArchiver;
  Files: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Detect Source Files Recursively ===');

  // Clean up first to ensure no leftover files
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create nested source files
  CreateTestDirectory('src');
  CreateTestDirectory('src' + PathDelim + 'utils');
  CreateTestFile('src' + PathDelim + 'mylib.pas', 'unit mylib;');
  CreateTestFile('src' + PathDelim + 'utils' + PathDelim + 'helpers.pas', 'unit helpers;');

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    Files := Archiver.DetectSourceFiles(True); // Recursive
    try
      AssertEqualsInt(2, Files.Count, 'Should detect 2 .pas files across nested directories');
    finally
      Files.Free;
    end;
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestDetectSourceFilesWithIncludes;
var
  Archiver: TPackageArchiver;
  Files: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Detect Source Files With Includes ===');

  // Clean up first to ensure no leftover files
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create source files with .inc files directly in root (non-recursive test)
  CreateTestFile('mylib.pas', 'unit mylib;');
  CreateTestFile('config.inc', '{$define DEBUG}');

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    Files := Archiver.DetectSourceFiles(False);
    try
      AssertEqualsInt(2, Files.Count, 'Should detect both .pas and .inc files');
    finally
      Files.Free;
    end;
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestExcludeFilesWithFpdevignore;
var
  Archiver: TPackageArchiver;
  Files: TStringList;
  I: Integer;
  HasTmpFile: Boolean;
begin
  WriteLn;
  WriteLn('=== Test: Exclude Files With .fpdevignore ===');

  // Clean up first to ensure no leftover files
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package files with .fpdevignore directly in root (non-recursive test)
  CreateTestFile('mylib.pas', 'unit mylib;');
  CreateTestFile('test.tmp', 'temporary file');
  CreateTestFile('.fpdevignore', '*.tmp' + LineEnding + 'bin/' + LineEnding + 'lib/');

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    Files := Archiver.DetectSourceFiles(False);
    try
      // Check that .tmp file is not in the list
      HasTmpFile := False;
      for I := 0 to Files.Count - 1 do
      begin
        if Pos('.tmp', Files[I]) > 0 then
        begin
          HasTmpFile := True;
          Break;
        end;
      end;
      AssertTrue(not HasTmpFile, 'Should exclude .tmp files from file list');
      AssertEqualsInt(1, Files.Count, 'Should only detect mylib.pas (not test.tmp)');
    finally
      Files.Free;
    end;
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestCreateTarGzArchive;
var
  Archiver: TPackageArchiver;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Create Tar.gz Archive ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package files
  CreateTestFile('mylib.pas', 'unit mylib;');
  CreateTestFile('README.md', '# MyLib');

  ArchivePath := FTestDataDir + PathDelim + 'mylib-1.0.0.tar.gz';

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    AssertTrue(Archiver.CreateArchive(ArchivePath), 'Should create tar.gz archive');
    AssertTrue(FileExists(ArchivePath), 'Archive file should exist');

    // Clean up archive
    if FileExists(ArchivePath) then
      DeleteFile(ArchivePath);
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestGenerateSHA256Checksum;
var
  Archiver: TPackageArchiver;
  ArchivePath: string;
  Checksum: string;
begin
  WriteLn;
  WriteLn('=== Test: Generate SHA256 Checksum ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package files
  CreateTestFile('mylib.pas', 'unit mylib;');

  ArchivePath := FTestDataDir + PathDelim + 'mylib-1.0.0.tar.gz';

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    AssertTrue(Archiver.CreateArchive(ArchivePath), 'Should create archive');

    Checksum := Archiver.GetChecksum;
    AssertTrue(Length(Checksum) = 64, 'SHA256 checksum should be 64 hex characters');
    AssertTrue(Checksum <> '', 'Checksum should not be empty');

    // Clean up archive
    if FileExists(ArchivePath) then
      DeleteFile(ArchivePath);
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestArchiveStructure;
var
  Archiver: TPackageArchiver;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Archive Structure ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package files
  CreateTestDirectory('src');
  CreateTestFile('package.json', '{"name":"mylib","version":"1.0.0"}');
  CreateTestFile('src' + PathDelim + 'mylib.pas', 'unit mylib;');
  CreateTestFile('README.md', '# MyLib');

  ArchivePath := FTestDataDir + PathDelim + 'mylib-1.0.0.tar.gz';

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    AssertTrue(Archiver.CreateArchive(ArchivePath), 'Should create archive');
    AssertTrue(FileExists(ArchivePath), 'Archive file should exist');

    // Note: Full archive structure validation would require extracting and inspecting
    // For now, we verify the archive was created successfully
    AssertTrue(Archiver.GetChecksum <> '', 'Archive should have checksum');

    // Clean up archive
    if FileExists(ArchivePath) then
      DeleteFile(ArchivePath);
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.TestArchiveWithVersion;
var
  Archiver: TPackageArchiver;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Archive With Version ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package files
  CreateTestFile('mylib.pas', 'unit mylib;');

  // Test with version 2.5.3 in archive name
  ArchivePath := FTestDataDir + PathDelim + 'mylib-2.5.3.tar.gz';

  Archiver := TPackageArchiver.Create(FTestDataDir);
  try
    AssertTrue(Archiver.CreateArchive(ArchivePath), 'Should create archive with version in name');
    AssertTrue(FileExists(ArchivePath), 'Archive mylib-2.5.3.tar.gz should exist');

    // Clean up archive
    if FileExists(ArchivePath) then
      DeleteFile(ArchivePath);
  finally
    Archiver.Free;
  end;
end;

procedure TPackageArchiverTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Archiver Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestDetectSourceFiles;
  TestDetectSourceFilesRecursive;
  TestDetectSourceFilesWithIncludes;
  TestExcludeFilesWithFpdevignore;
  TestCreateTarGzArchive;
  TestGenerateSHA256Checksum;
  TestArchiveStructure;
  TestArchiveWithVersion;

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
    WriteLn('RED PHASE: All tests are expected to fail.');
    WriteLn('Next step: Implement package archiver features (Green Phase)');
  end;
end;

var
  Test: TPackageArchiverTest;
begin
  Test := TPackageArchiverTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
