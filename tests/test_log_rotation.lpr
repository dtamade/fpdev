program test_log_rotation;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DateUtils, test_temp_paths, fpdev.logger.structured, fpdev.logger.rotator;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GRotationTestRoot: string = '';

function GetRotationTestRoot: string;
begin
  if GRotationTestRoot = '' then
    GRotationTestRoot := CreateUniqueTempDir('test_rotation_logs');
  Result := GRotationTestRoot;
end;

function BuildRotationTestPath(const ARelativePath: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetRotationTestRoot) + ARelativePath;
end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + Format(' (Expected: %d, Got: %d)', [AExpected, AActual]));
end;

procedure AssertEquals(const AExpected, AActual: Int64; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + Format(' (Expected: %d, Got: %d)', [AExpected, AActual]));
end;

{ Helper function to create test log file }
procedure CreateTestLogFile(const APath: string; ASizeBytes: Int64);
var
  F: File of Byte;
  Buffer: array[0..1023] of Byte;
  Written: Int64;
  ToWrite: Integer;
begin
  AssignFile(F, APath);
  Rewrite(F);
  try
    Written := 0;
    FillChar(Buffer, SizeOf(Buffer), 65); // Fill with 'A'

    while Written < ASizeBytes do
    begin
      ToWrite := SizeOf(Buffer);
      if Written + ToWrite > ASizeBytes then
        ToWrite := ASizeBytes - Written;

      BlockWrite(F, Buffer, ToWrite);
      Written := Written + ToWrite;
    end;
  finally
    CloseFile(F);
  end;
end;

{ Helper function to get file size }
function GetFileSize(const APath: string): Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(APath, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
  end;
end;

{ Helper function to set file modification time }
procedure SetFileTime(const APath: string; ATime: TDateTime);
var
  FileDate: LongInt;
begin
  FileDate := DateTimeToFileDate(ATime);
  AssertTrue(FileSetDate(APath, FileDate) = 0, 'Set file time for ' + ExtractFileName(APath));
end;

procedure TestRotationConfigCreation;
var
  Config: TRotationConfig;
begin
  WriteLn('Testing TRotationConfig creation...');

  Config := CreateDefaultRotationConfig;

  AssertTrue(Config.MaxFileSize > 0, 'MaxFileSize should be positive');
  AssertTrue(Config.RotationInterval > 0, 'RotationInterval should be positive');
  AssertTrue(Config.MaxFiles > 0, 'MaxFiles should be positive');
  AssertTrue(Config.MaxAge > 0, 'MaxAge should be positive');
end;

procedure TestLogRotatorCreation;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
begin
  WriteLn('Testing TLogRotator creation...');

  Config := CreateDefaultRotationConfig;
  Rotator := TLogRotator.Create(Config);

  AssertTrue(Rotator <> nil, 'Rotator should be created');
end;

procedure TestShouldRotateBySize;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
  TestFile: string;
begin
  WriteLn('Testing ShouldRotate by size...');

  // Create config with 1KB max size
  Config := CreateDefaultRotationConfig;
  Config.MaxFileSize := 1024;
  Config.RotationInterval := 24 * 365; // Very long interval

  Rotator := TLogRotator.Create(Config);
  TestFile := BuildRotationTestPath('size_test.log');

  // Ensure directory exists
  ForceDirectories(GetRotationTestRoot);

  try
    // Create small file (500 bytes)
    CreateTestLogFile(TestFile, 500);
    AssertTrue(not Rotator.ShouldRotate(TestFile), 'Should not rotate small file');

    // Create large file (2KB)
    CreateTestLogFile(TestFile, 2048);
    AssertTrue(Rotator.ShouldRotate(TestFile), 'Should rotate large file');
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
  end;
end;

procedure TestShouldRotateByTime;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
  TestFile: string;
  OldTime: TDateTime;
begin
  WriteLn('Testing ShouldRotate by time...');

  // Create config with 1 hour interval
  Config := CreateDefaultRotationConfig;
  Config.MaxFileSize := 1024 * 1024 * 1024; // Very large size
  Config.RotationInterval := 1; // 1 hour

  Rotator := TLogRotator.Create(Config);
  TestFile := BuildRotationTestPath('time_test.log');

  // Ensure directory exists
  ForceDirectories(GetRotationTestRoot);

  try
    // Create recent file
    CreateTestLogFile(TestFile, 100);
    AssertTrue(not Rotator.ShouldRotate(TestFile), 'Should not rotate recent file');

    // Set file time to 2 hours ago
    OldTime := Now - (2 / 24); // 2 hours ago
    SetFileTime(TestFile, OldTime);
    AssertTrue(Rotator.ShouldRotate(TestFile), 'Should rotate old file');
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
  end;
end;

procedure TestRotateFile;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
  TestFile: string;
  RotatedFile: string;
begin
  WriteLn('Testing Rotate file...');

  Config := CreateDefaultRotationConfig;
  Rotator := TLogRotator.Create(Config);
  TestFile := BuildRotationTestPath('rotate_test.log');

  // Ensure directory exists
  ForceDirectories(GetRotationTestRoot);

  try
    // Create test file
    CreateTestLogFile(TestFile, 1024);
    AssertTrue(FileExists(TestFile), 'Test file should exist');

    // Rotate file
    Rotator.Rotate(TestFile);

    // Check that original file is gone or empty
    AssertTrue(not FileExists(TestFile) or (GetFileSize(TestFile) = 0),
               'Original file should be rotated');

    // Check that rotated file exists
    RotatedFile := TestFile + '.1';
    AssertTrue(FileExists(RotatedFile), 'Rotated file should exist');
    AssertEquals(Int64(1024), GetFileSize(RotatedFile), 'Rotated file size should match');
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
    if FileExists(RotatedFile) then
      DeleteFile(RotatedFile);
  end;
end;

procedure TestCleanupOldLogs;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
  LogDir: string;
  i: Integer;
  TestFile: string;
begin
  WriteLn('Testing CleanupOldLogs...');

  // Create config to keep only 3 files
  Config := CreateDefaultRotationConfig;
  Config.MaxFiles := 3;

  Rotator := TLogRotator.Create(Config);
  LogDir := BuildRotationTestPath('cleanup');

  // Ensure directory exists
  ForceDirectories(LogDir);

  try
    // Create 5 rotated log files
    for i := 1 to 5 do
    begin
      TestFile := LogDir + PathDelim + Format('test.log.%d', [i]);
      CreateTestLogFile(TestFile, 100);
    end;

    // Cleanup old logs
    Rotator.CleanupOldLogs(LogDir);

    // Check that only 3 files remain
    AssertTrue(FileExists(LogDir + PathDelim + 'test.log.1'), 'File 1 should exist');
    AssertTrue(FileExists(LogDir + PathDelim + 'test.log.2'), 'File 2 should exist');
    AssertTrue(FileExists(LogDir + PathDelim + 'test.log.3'), 'File 3 should exist');
    AssertTrue(not FileExists(LogDir + PathDelim + 'test.log.4'), 'File 4 should be deleted');
    AssertTrue(not FileExists(LogDir + PathDelim + 'test.log.5'), 'File 5 should be deleted');
  finally
    // Cleanup test files
    for i := 1 to 5 do
    begin
      TestFile := LogDir + PathDelim + Format('test.log.%d', [i]);
      if FileExists(TestFile) then
        DeleteFile(TestFile);
    end;
  end;
end;

procedure TestRotationWithMaxFiles;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
  TestFile: string;
  i: Integer;
begin
  WriteLn('Testing rotation with MaxFiles limit...');

  // Create config to keep only 2 files
  Config := CreateDefaultRotationConfig;
  Config.MaxFiles := 2;
  Config.MaxFileSize := 100;

  Rotator := TLogRotator.Create(Config);
  TestFile := BuildRotationTestPath('maxfiles_test.log');

  // Ensure directory exists
  ForceDirectories(GetRotationTestRoot);

  try
    // Rotate 3 times
    for i := 1 to 3 do
    begin
      CreateTestLogFile(TestFile, 200);
      Rotator.Rotate(TestFile);
    end;

    // Check that only 2 rotated files exist
    AssertTrue(FileExists(TestFile + '.1'), 'File 1 should exist');
    AssertTrue(FileExists(TestFile + '.2'), 'File 2 should exist');
    AssertTrue(not FileExists(TestFile + '.3'), 'File 3 should not exist');
  finally
    // Cleanup
    if FileExists(TestFile) then
      DeleteFile(TestFile);
    for i := 1 to 3 do
      if FileExists(TestFile + '.' + IntToStr(i)) then
        DeleteFile(TestFile + '.' + IntToStr(i));
  end;
end;

procedure TestCleanupByAge;
var
  Rotator: ILogRotator;
  Config: TRotationConfig;
  LogDir: string;
  OldFile, NewFile: string;
  OldTime: TDateTime;
begin
  WriteLn('Testing cleanup by age...');

  // Create config to keep files for 1 day
  Config := CreateDefaultRotationConfig;
  Config.MaxAge := 1; // 1 day

  Rotator := TLogRotator.Create(Config);
  LogDir := BuildRotationTestPath('age');

  // Ensure directory exists
  ForceDirectories(LogDir);

  try
    // Create old file (3 days ago)
    OldFile := LogDir + PathDelim + 'old.log.1';
    CreateTestLogFile(OldFile, 100);
    OldTime := Now - 3; // 3 days ago
    SetFileTime(OldFile, OldTime);

    // Create new file (today)
    NewFile := LogDir + PathDelim + 'new.log.1';
    CreateTestLogFile(NewFile, 100);

    // Cleanup old logs
    Rotator.CleanupOldLogs(LogDir);

    // Check that old file is deleted and new file remains
    AssertTrue(not FileExists(OldFile), 'Old file should be deleted');
    AssertTrue(FileExists(NewFile), 'New file should remain');
  finally
    if FileExists(OldFile) then
      DeleteFile(OldFile);
    if FileExists(NewFile) then
      DeleteFile(NewFile);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Running Log Rotation Tests');
  WriteLn('========================================');
  WriteLn;

  TestRotationConfigCreation;
  TestLogRotatorCreation;
  TestShouldRotateBySize;
  TestShouldRotateByTime;
  TestRotateFile;
  TestCleanupOldLogs;
  TestRotationWithMaxFiles;
  TestCleanupByAge;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Results');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn;

  if TestsFailed > 0 then
  begin
    WriteLn('FAILED: ', TestsFailed, ' test(s) failed');
    if GRotationTestRoot <> '' then
      CleanupTempDir(GRotationTestRoot);
    Halt(1);
  end
  else
  begin
    WriteLn('SUCCESS: All tests passed');
    if GRotationTestRoot <> '' then
      CleanupTempDir(GRotationTestRoot);
    Halt(0);
  end;
end.
