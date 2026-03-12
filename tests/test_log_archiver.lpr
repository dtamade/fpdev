program test_log_archiver;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fpdev.logger.structured, fpdev.logger.archiver,
  test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GLogTestRoot: string = '';

function LogTestPath(const ARelative: string): string;
begin
  if GLogTestRoot = '' then
    GLogTestRoot := CreateUniqueTempDir('test_rotation_logs');
  Result := GLogTestRoot;
  if ARelative <> '' then
    Result := Result + PathDelim + ARelative;
end;

procedure CleanupLogTestRoot;
begin
  if GLogTestRoot <> '' then
  begin
    CleanupTempDir(GLogTestRoot);
    GLogTestRoot := '';
  end;
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

procedure TestArchiverCreation;
var
  Archiver: ILogArchiver;
  Config: TArchiveConfig;
begin
  WriteLn('Testing TLogArchiver creation...');

  Config := CreateDefaultArchiveConfig;
  Archiver := TLogArchiver.Create(Config);

  AssertTrue(Archiver <> nil, 'Archiver should be created');
end;

procedure TestArchiveConfigCreation;
var
  Config: TArchiveConfig;
begin
  WriteLn('Testing TArchiveConfig creation...');

  Config := CreateDefaultArchiveConfig;

  AssertTrue(Config.Enabled, 'Archiving should be enabled by default');
  AssertTrue(Config.CompressionLevel >= 0, 'CompressionLevel should be valid');
  AssertTrue(Config.ArchiveDir <> '', 'ArchiveDir should be set');
end;

procedure TestShouldArchive;
var
  Archiver: ILogArchiver;
  Config: TArchiveConfig;
  TestFile: string;
begin
  WriteLn('Testing ShouldArchive...');

  Config := CreateDefaultArchiveConfig;
  Config.Enabled := True;
  Archiver := TLogArchiver.Create(Config);
  TestFile := LogTestPath('archive_test.log.1');

  ForceDirectories(ExtractFileDir(TestFile));

  try
    // Create rotated log file
    CreateTestLogFile(TestFile, 1024);
    AssertTrue(Archiver.ShouldArchive(TestFile), 'Should archive rotated log file');

    // Test with current log file (should not archive)
    AssertTrue(not Archiver.ShouldArchive(LogTestPath('current.log')),
               'Should not archive current log file');
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
  end;
end;

procedure TestArchiveFile;
var
  Archiver: ILogArchiver;
  Config: TArchiveConfig;
  TestFile: string;
  ArchiveFile: string;
begin
  WriteLn('Testing ArchiveFile...');

  Config := CreateDefaultArchiveConfig;
  Config.Enabled := True;
  Config.ArchiveDir := LogTestPath('archive');
  Archiver := TLogArchiver.Create(Config);
  TestFile := LogTestPath('archive_test.log.1');

  ForceDirectories(ExtractFileDir(TestFile));
  ForceDirectories(Config.ArchiveDir);

  try
    // Create test file
    CreateTestLogFile(TestFile, 1024);
    AssertTrue(FileExists(TestFile), 'Test file should exist');

    // Archive file
    ArchiveFile := Archiver.Archive(TestFile);

    // Check that archive was created
    AssertTrue(ArchiveFile <> '', 'Archive path should be returned');
    AssertTrue(FileExists(ArchiveFile), 'Archive file should exist');
    AssertTrue(not FileExists(TestFile), 'Original file should be removed');

    // Check that archive is compressed (smaller than original)
    AssertTrue(GetFileSize(ArchiveFile) < 1024, 'Archive should be compressed');
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
    if FileExists(ArchiveFile) then
      DeleteFile(ArchiveFile);
  end;
end;

procedure TestArchiveDisabled;
var
  Archiver: ILogArchiver;
  Config: TArchiveConfig;
  TestFile: string;
  ArchiveFile: string;
begin
  WriteLn('Testing Archive with disabled config...');

  Config := CreateDefaultArchiveConfig;
  Config.Enabled := False;
  Archiver := TLogArchiver.Create(Config);
  TestFile := LogTestPath('disabled_test.log.1');

  ForceDirectories(ExtractFileDir(TestFile));

  try
    // Create test file
    CreateTestLogFile(TestFile, 1024);

    // Try to archive (should do nothing)
    ArchiveFile := Archiver.Archive(TestFile);

    // Check that no archive was created
    AssertTrue(ArchiveFile = '', 'Archive path should be empty when disabled');
    AssertTrue(FileExists(TestFile), 'Original file should remain when archiving disabled');
  finally
    if FileExists(TestFile) then
      DeleteFile(TestFile);
  end;
end;

procedure TestCleanupOldArchives;
var
  Archiver: ILogArchiver;
  Config: TArchiveConfig;
  ArchiveDir: string;
  i: Integer;
  TestFile: string;
begin
  WriteLn('Testing CleanupOldArchives...');

  Config := CreateDefaultArchiveConfig;
  Config.Enabled := True;
  Config.MaxArchiveAge := 1; // 1 day
  ArchiveDir := LogTestPath('archive_cleanup');
  Config.ArchiveDir := ArchiveDir;
  Archiver := TLogArchiver.Create(Config);

  // Ensure directory exists
  ForceDirectories(ArchiveDir);

  try
    // Create 3 archive files
    for i := 1 to 3 do
    begin
      TestFile := ArchiveDir + PathDelim + Format('test.log.%d.gz', [i]);
      CreateTestLogFile(TestFile, 100);
    end;

    // Cleanup old archives
    Archiver.CleanupOldArchives;

    // Check that files still exist (they're not old enough)
    AssertTrue(FileExists(ArchiveDir + PathDelim + 'test.log.1.gz'), 'Archive 1 should exist');
    AssertTrue(FileExists(ArchiveDir + PathDelim + 'test.log.2.gz'), 'Archive 2 should exist');
    AssertTrue(FileExists(ArchiveDir + PathDelim + 'test.log.3.gz'), 'Archive 3 should exist');
  finally
    // Cleanup test files
    for i := 1 to 3 do
    begin
      TestFile := ArchiveDir + PathDelim + Format('test.log.%d.gz', [i]);
      if FileExists(TestFile) then
        DeleteFile(TestFile);
    end;
  end;
end;

procedure TestArchiveMultipleFiles;
var
  Archiver: ILogArchiver;
  Config: TArchiveConfig;
  LogDir: string;
  i: Integer;
  TestFile: string;
  ArchivedCount: Integer;
begin
  WriteLn('Testing ArchiveMultipleFiles...');

  Config := CreateDefaultArchiveConfig;
  Config.Enabled := True;
  Config.ArchiveDir := LogTestPath('archive_multi');
  Archiver := TLogArchiver.Create(Config);
  LogDir := LogTestPath('multi');

  // Ensure directories exist
  ForceDirectories(LogDir);
  ForceDirectories(Config.ArchiveDir);

  try
    // Create 3 rotated log files
    for i := 1 to 3 do
    begin
      TestFile := LogDir + PathDelim + Format('test.log.%d', [i]);
      CreateTestLogFile(TestFile, 100);
    end;

    // Archive all files
    ArchivedCount := Archiver.ArchiveAll(LogDir);

    // Check that all files were archived
    AssertEquals(3, ArchivedCount, 'Should archive 3 files');
    AssertTrue(not FileExists(LogDir + PathDelim + 'test.log.1'), 'File 1 should be archived');
    AssertTrue(not FileExists(LogDir + PathDelim + 'test.log.2'), 'File 2 should be archived');
    AssertTrue(not FileExists(LogDir + PathDelim + 'test.log.3'), 'File 3 should be archived');
  finally
    // Cleanup test files
    for i := 1 to 3 do
    begin
      TestFile := LogDir + PathDelim + Format('test.log.%d', [i]);
      if FileExists(TestFile) then
        DeleteFile(TestFile);
      TestFile := Config.ArchiveDir + PathDelim + Format('test.log.%d.gz', [i]);
      if FileExists(TestFile) then
        DeleteFile(TestFile);
    end;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Running Log Archiver Tests');
  WriteLn('========================================');
  WriteLn;

  TestArchiveConfigCreation;
  TestArchiverCreation;
  TestShouldArchive;
  TestArchiveFile;
  TestArchiveDisabled;
  TestCleanupOldArchives;
  TestArchiveMultipleFiles;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Results');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn;

  CleanupLogTestRoot;

  if TestsFailed > 0 then
  begin
    WriteLn('FAILED: ', TestsFailed, ' test(s) failed');
    Halt(1);
  end
  else
  begin
    WriteLn('SUCCESS: All tests passed');
    Halt(0);
  end;
end.
