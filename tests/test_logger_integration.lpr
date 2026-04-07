program test_logger_integration;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DateUtils, test_temp_paths,
  fpdev.logger.intf,
  fpdev.logger.structured,
  fpdev.logger.rotator,
  fpdev.logger.archiver;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

procedure AssertFileDateSet(const APath: string; const ATime: TDateTime; const AMessage: string);
var
  FileDate: LongInt;
begin
  FileDate := DateTimeToFileDate(ATime);
  Assert(FileSetDate(APath, FileDate) = 0, AMessage);
end;

function CreateTestContext(const ASource: string): TLogContext;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Source := ASource;
  Result.CorrelationId := 'test-correlation-id';
  Result.ThreadId := GetCurrentThreadId;
  Result.ProcessId := GetProcessID;
  Result.CustomFields := nil;
end;

{ Test 1: Basic Logger + Rotator Integration }
procedure TestLoggerRotatorIntegration;
var
  LogDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  Logger: IStructuredLogger;
  Rotator: ILogRotator;
  Context: TLogContext;
  i: Integer;
begin
  WriteLn('=== Test 1: Logger + Rotator Integration ===');

  LogDir := CreateUniqueTempDir('test_logger_integration');
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);

    // Configure logger with small rotation size
    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := False;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;
    Config.RotationConfig.MaxFileSize := 1024;  // 1KB for testing
    Config.RotationConfig.RotationInterval := 24;
    Config.RotationConfig.MaxFiles := 3;
    Config.RotationConfig.MaxAge := 7;
    Config.RotationConfig.CompressOld := False;

    Logger := TStructuredLogger.Create(Config);
    Rotator := TLogRotator.Create(Config.RotationConfig);

    Context := CreateTestContext('test.integration');

    // Write logs until rotation is needed
    for i := 1 to 50 do
      Logger.Info('Test message ' + IntToStr(i) + ' - This is a longer message to fill up the log file faster', Context);

    // Check if rotation is needed
    Assert(Rotator.ShouldRotate(LogFile), 'Should need rotation after writing many logs');

    // Perform rotation
    Rotator.Rotate(LogFile);

    // Verify rotated file exists
    Assert(FileExists(LogFile + '.1'), 'Rotated file should exist');

    // Write more logs
    for i := 51 to 100 do
      Logger.Info('Test message ' + IntToStr(i) + ' - More messages after rotation', Context);

    // Verify new log file exists
    Assert(FileExists(LogFile), 'New log file should exist after rotation');

  finally
    CleanupTempDir(LogDir);
  end;
end;

{ Test 2: Logger + Rotator + Archiver Integration }
procedure TestFullLoggingPipeline;
var
  LogDir: string;
  ArchiveDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  ArchiveConfig: TArchiveConfig;
  Logger: IStructuredLogger;
  Rotator: ILogRotator;
  Archiver: ILogArchiver;
  Context: TLogContext;
  i: Integer;
  ArchivedCount: Integer;
begin
  WriteLn('=== Test 2: Full Logging Pipeline (Logger + Rotator + Archiver) ===');

  LogDir := CreateUniqueTempDir('test_full_pipeline');
  ArchiveDir := LogDir + PathDelim + 'archive';
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);

    // Configure logger
    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := False;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;
    Config.RotationConfig.MaxFileSize := 512;  // 512 bytes for testing
    Config.RotationConfig.RotationInterval := 24;
    Config.RotationConfig.MaxFiles := 5;
    Config.RotationConfig.MaxAge := 7;
    Config.RotationConfig.CompressOld := True;

    // Configure archiver
    ArchiveConfig.Enabled := True;
    ArchiveConfig.CompressionLevel := 6;
    ArchiveConfig.ArchiveDir := ArchiveDir;
    ArchiveConfig.MaxArchiveAge := 30;

    Logger := TStructuredLogger.Create(Config);
    Rotator := TLogRotator.Create(Config.RotationConfig);
    Archiver := TLogArchiver.Create(ArchiveConfig);

    Context := CreateTestContext('test.pipeline');

    // Step 1: Write logs
    for i := 1 to 30 do
      Logger.Info('Pipeline test message ' + IntToStr(i) + ' - Testing full integration', Context);

    // Step 2: Rotate logs
    if Rotator.ShouldRotate(LogFile) then
      Rotator.Rotate(LogFile);

    // Step 3: Write more logs to trigger another rotation
    for i := 31 to 60 do
      Logger.Info('Pipeline test message ' + IntToStr(i) + ' - Second batch', Context);

    if Rotator.ShouldRotate(LogFile) then
      Rotator.Rotate(LogFile);

    // Step 4: Archive rotated logs
    ArchivedCount := Archiver.ArchiveAll(LogDir);

    Assert(ArchivedCount > 0, 'Should have archived at least one log file');
    Assert(DirectoryExists(ArchiveDir), 'Archive directory should exist');

    // Verify archived files exist
    Assert(FileExists(ArchiveDir + PathDelim + 'app.log.1.gz') or
           FileExists(ArchiveDir + PathDelim + 'app.log.2.gz'),
           'At least one archived file should exist');

  finally
    CleanupTempDir(LogDir);
  end;
end;

{ Test 3: Multiple Rotation Cycles }
procedure TestMultipleRotationCycles;
var
  LogDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  Logger: IStructuredLogger;
  Rotator: ILogRotator;
  Context: TLogContext;
  i, cycle: Integer;
begin
  WriteLn('=== Test 3: Multiple Rotation Cycles ===');

  LogDir := CreateUniqueTempDir('test_multi_rotation');
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);

    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := False;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;
    Config.RotationConfig.MaxFileSize := 256;  // Very small for testing
    Config.RotationConfig.RotationInterval := 24;
    Config.RotationConfig.MaxFiles := 3;
    Config.RotationConfig.MaxAge := 7;
    Config.RotationConfig.CompressOld := False;

    Logger := TStructuredLogger.Create(Config);
    Rotator := TLogRotator.Create(Config.RotationConfig);

    Context := CreateTestContext('test.multi');

    // Perform multiple rotation cycles
    for cycle := 1 to 4 do
    begin
      // Write logs
      for i := 1 to 20 do
        Logger.Info('Cycle ' + IntToStr(cycle) + ' message ' + IntToStr(i), Context);

      // Rotate if needed
      if Rotator.ShouldRotate(LogFile) then
        Rotator.Rotate(LogFile);
    end;

    // Verify rotation files exist (should have .1, .2, .3 due to MaxFiles=3)
    Assert(FileExists(LogFile + '.1'), 'First rotated file should exist');
    Assert(FileExists(LogFile + '.2'), 'Second rotated file should exist');
    Assert(FileExists(LogFile + '.3'), 'Third rotated file should exist');

    // Fourth rotation should have been deleted (MaxFiles=3)
    Assert(not FileExists(LogFile + '.4'), 'Fourth rotated file should not exist (MaxFiles=3)');

  finally
    CleanupTempDir(LogDir);
  end;
end;

{ Test 4: Log Levels with Rotation }
procedure TestLogLevelsWithRotation;
var
  LogDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  Logger: IStructuredLogger;
  Rotator: ILogRotator;
  Context: TLogContext;
  i: Integer;
begin
  WriteLn('=== Test 4: Log Levels with Rotation ===');

  LogDir := CreateUniqueTempDir('test_levels_rotation');
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);

    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := False;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;
    Config.RotationConfig.MaxFileSize := 512;
    Config.RotationConfig.RotationInterval := 24;
    Config.RotationConfig.MaxFiles := 2;
    Config.RotationConfig.MaxAge := 7;
    Config.RotationConfig.CompressOld := False;

    Logger := TStructuredLogger.Create(Config);
    Rotator := TLogRotator.Create(Config.RotationConfig);

    Context := CreateTestContext('test.levels');

    // Write logs at different levels
    for i := 1 to 10 do
    begin
      Logger.Debug('Debug message ' + IntToStr(i), Context);
      Logger.Info('Info message ' + IntToStr(i), Context);
      Logger.Warn('Warning message ' + IntToStr(i), Context);
      Logger.Error('Error message ' + IntToStr(i), Context, 'Stack trace here');
    end;

    // Rotate
    if Rotator.ShouldRotate(LogFile) then
      Rotator.Rotate(LogFile);

    // Write more logs after rotation to create new log file
    for i := 11 to 15 do
      Logger.Info('Post-rotation message ' + IntToStr(i), Context);

    Assert(FileExists(LogFile), 'Log file should exist');
    Assert(FileExists(LogFile + '.1'), 'Rotated log file should exist');

  finally
    CleanupTempDir(LogDir);
  end;
end;

{ Test 5: Archive Cleanup }
procedure TestArchiveCleanup;
var
  LogDir: string;
  ArchiveDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  ArchiveConfig: TArchiveConfig;
  Logger: IStructuredLogger;
  Rotator: ILogRotator;
  Archiver: ILogArchiver;
  Context: TLogContext;
  i: Integer;
  OldArchive: string;
begin
  WriteLn('=== Test 5: Archive Cleanup ===');

  LogDir := CreateUniqueTempDir('test_archive_cleanup');
  ArchiveDir := LogDir + PathDelim + 'archive';
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);
    ForceDirectories(ArchiveDir);

    // Configure
    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := False;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;
    Config.RotationConfig.MaxFileSize := 512;
    Config.RotationConfig.RotationInterval := 24;
    Config.RotationConfig.MaxFiles := 2;
    Config.RotationConfig.MaxAge := 7;
    Config.RotationConfig.CompressOld := True;

    ArchiveConfig.Enabled := True;
    ArchiveConfig.CompressionLevel := 6;
    ArchiveConfig.ArchiveDir := ArchiveDir;
    ArchiveConfig.MaxArchiveAge := 1;  // 1 day for testing

    Logger := TStructuredLogger.Create(Config);
    Rotator := TLogRotator.Create(Config.RotationConfig);
    Archiver := TLogArchiver.Create(ArchiveConfig);

    Context := CreateTestContext('test.cleanup');

    // Create an old archive file
    OldArchive := ArchiveDir + PathDelim + 'old.log.gz';
    with TFileStream.Create(OldArchive, fmCreate) do
      Free;

    // Set file date to 2 days ago
    AssertFileDateSet(OldArchive, Now - 2, 'Old archive timestamp should be set');

    Assert(FileExists(OldArchive), 'Old archive should exist before cleanup');

    // Cleanup old archives
    Archiver.CleanupOldArchives;

    // Verify old archive was deleted
    Assert(not FileExists(OldArchive), 'Old archive should be deleted after cleanup');

  finally
    CleanupTempDir(LogDir);
  end;
end;

{ Test 6: Concurrent Logging (Stress Test) }
procedure TestConcurrentLogging;
var
  LogDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  Logger: IStructuredLogger;
  Context: TLogContext;
  i: Integer;
begin
  WriteLn('=== Test 6: Concurrent Logging (Stress Test) ===');

  LogDir := CreateUniqueTempDir('test_concurrent');
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);

    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := False;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;
    Config.RotationConfig.MaxFileSize := 10 * 1024;  // 10KB
    Config.RotationConfig.RotationInterval := 24;
    Config.RotationConfig.MaxFiles := 5;
    Config.RotationConfig.MaxAge := 7;
    Config.RotationConfig.CompressOld := False;

    Logger := TStructuredLogger.Create(Config);
    Context := CreateTestContext('test.concurrent');

    // Write many logs rapidly
    for i := 1 to 500 do
      Logger.Info('Stress test message ' + IntToStr(i) + ' - Testing concurrent writes', Context);

    Assert(FileExists(LogFile), 'Log file should exist after stress test');

  finally
    CleanupTempDir(LogDir);
  end;
end;

{ Test 7: File and Console Output Toggle }
procedure TestOutputToggle;
var
  LogDir: string;
  LogFile: string;
  Config: TLoggerConfig;
  Logger: IStructuredLogger;
  Context: TLogContext;
begin
  WriteLn('=== Test 7: File and Console Output Toggle ===');

  LogDir := CreateUniqueTempDir('test_output_toggle');
  LogFile := LogDir + PathDelim + 'app.log';

  try
    // Setup
    ForceDirectories(LogDir);

    FillChar(Config, SizeOf(Config), 0);
    Config.FileOutputEnabled := True;
    Config.ConsoleOutputEnabled := True;
    Config.LogDir := LogDir;
    Config.LogFileName := 'app.log';
    Config.MinLevel := llDebug;

    Logger := TStructuredLogger.Create(Config);
    Context := CreateTestContext('test.toggle');

    // Test initial state
    Assert(Logger.IsFileOutputEnabled, 'File output should be enabled initially');
    Assert(Logger.IsConsoleOutputEnabled, 'Console output should be enabled initially');

    // Disable file output
    Logger.SetFileOutput(False);
    Assert(not Logger.IsFileOutputEnabled, 'File output should be disabled');

    // Disable console output
    Logger.SetConsoleOutput(False);
    Assert(not Logger.IsConsoleOutputEnabled, 'Console output should be disabled');

    // Re-enable both
    Logger.SetFileOutput(True);
    Logger.SetConsoleOutput(True);
    Assert(Logger.IsFileOutputEnabled, 'File output should be re-enabled');
    Assert(Logger.IsConsoleOutputEnabled, 'Console output should be re-enabled');

  finally
    CleanupTempDir(LogDir);
  end;
end;

begin
  Randomize;
  WriteLn('========================================');
  WriteLn('Logger Integration Tests');
  WriteLn('========================================');
  WriteLn;

  TestLoggerRotatorIntegration;
  WriteLn;

  TestFullLoggingPipeline;
  WriteLn;

  TestMultipleRotationCycles;
  WriteLn;

  TestLogLevelsWithRotation;
  WriteLn;

  TestArchiveCleanup;
  WriteLn;

  TestConcurrentLogging;
  WriteLn;

  TestOutputToggle;
  WriteLn;

  WriteLn('========================================');
  WriteLn('Test Results');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
