program test_structured_logger;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, test_temp_paths, fpdev.logger.intf, fpdev.logger.structured,
  fpdev.logger.writer, fpdev.logger.formatter;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GTestLogDir: string = '';

function GetTestLogDir: string;
begin
  if GTestLogDir = '' then
    GTestLogDir := CreateUniqueTempDir('test_logs');
  Result := GTestLogDir;
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

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + Format(' (Expected: "%s", Got: "%s")', [AExpected, AActual]));
end;

procedure TestLogContextCreation;
var
  Context: TLogContext;
begin
  WriteLn('Testing TLogContext creation...');

  Context := CreateLogContext('test.module');
  try
    AssertTrue(Context.Source = 'test.module', 'Source should be set');
    AssertTrue(Context.CorrelationId = '', 'CorrelationId should be empty by default');
    AssertTrue(Context.ThreadId > 0, 'ThreadId should be set');
    AssertTrue(Context.ProcessId > 0, 'ProcessId should be set');
    AssertTrue(Context.CustomFields <> nil, 'CustomFields should be initialized');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestLogContextWithCorrelationId;
var
  Context: TLogContext;
begin
  WriteLn('Testing TLogContext with correlation ID...');

  Context := CreateLogContext('test.module', 'req-123');
  try
    AssertEquals('test.module', Context.Source, 'Source should match');
    AssertEquals('req-123', Context.CorrelationId, 'CorrelationId should match');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestLogContextCustomFields;
var
  Context: TLogContext;
begin
  WriteLn('Testing TLogContext custom fields...');

  Context := CreateLogContext('test.module');
  try
    Context.CustomFields.Values['key1'] := 'value1';
    Context.CustomFields.Values['key2'] := 'value2';

    AssertEquals('value1', Context.CustomFields.Values['key1'], 'Custom field key1 should match');
    AssertEquals('value2', Context.CustomFields.Values['key2'], 'Custom field key2 should match');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestStructuredLoggerCreation;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
begin
  WriteLn('Testing TStructuredLogger creation...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;

  Logger := TStructuredLogger.Create(Config);
  AssertTrue(Logger <> nil, 'Logger should be created');
  AssertTrue(Logger.IsFileOutputEnabled, 'File output should be enabled by default');
  AssertTrue(Logger.IsConsoleOutputEnabled, 'Console output should be enabled by default');
end;

procedure TestStructuredLoggerOutputControl;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
begin
  WriteLn('Testing TStructuredLogger output control...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;

  Logger := TStructuredLogger.Create(Config);

  // Test disabling file output
  Logger.SetFileOutput(False);
  AssertTrue(not Logger.IsFileOutputEnabled, 'File output should be disabled');
  AssertTrue(Logger.IsConsoleOutputEnabled, 'Console output should still be enabled');

  // Test disabling console output
  Logger.SetConsoleOutput(False);
  AssertTrue(not Logger.IsFileOutputEnabled, 'File output should still be disabled');
  AssertTrue(not Logger.IsConsoleOutputEnabled, 'Console output should be disabled');

  // Test enabling both
  Logger.SetFileOutput(True);
  Logger.SetConsoleOutput(True);
  AssertTrue(Logger.IsFileOutputEnabled, 'File output should be enabled');
  AssertTrue(Logger.IsConsoleOutputEnabled, 'Console output should be enabled');
end;

procedure TestStructuredLoggerInfoLevel;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
  Context: TLogContext;
begin
  WriteLn('Testing TStructuredLogger Info level...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;
  Config.ConsoleOutputEnabled := False;  // Disable console for test

  Logger := TStructuredLogger.Create(Config);
  Context := CreateLogContext('test.module');
  try
    Logger.Info('Test info message', Context);
    AssertTrue(True, 'Info logging should not throw exception');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestStructuredLoggerDebugLevel;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
  Context: TLogContext;
begin
  WriteLn('Testing TStructuredLogger Debug level...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;
  Config.ConsoleOutputEnabled := False;

  Logger := TStructuredLogger.Create(Config);
  Context := CreateLogContext('test.module');
  try
    Logger.Debug('Test debug message', Context);
    AssertTrue(True, 'Debug logging should not throw exception');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestStructuredLoggerWarnLevel;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
  Context: TLogContext;
begin
  WriteLn('Testing TStructuredLogger Warn level...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;
  Config.ConsoleOutputEnabled := False;

  Logger := TStructuredLogger.Create(Config);
  Context := CreateLogContext('test.module');
  try
    Logger.Warn('Test warning message', Context);
    AssertTrue(True, 'Warn logging should not throw exception');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestStructuredLoggerErrorLevel;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
  Context: TLogContext;
begin
  WriteLn('Testing TStructuredLogger Error level...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;
  Config.ConsoleOutputEnabled := False;

  Logger := TStructuredLogger.Create(Config);
  Context := CreateLogContext('test.module');
  try
    Logger.Error('Test error message', Context, 'Stack trace here');
    AssertTrue(True, 'Error logging should not throw exception');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestStructuredLoggerWithCustomFields;
var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
  Context: TLogContext;
begin
  WriteLn('Testing TStructuredLogger with custom fields...');

  Config := CreateDefaultLoggerConfig;
  Config.LogDir := GetTestLogDir;
  Config.ConsoleOutputEnabled := False;

  Logger := TStructuredLogger.Create(Config);
  Context := CreateLogContext('test.module');
  try
    Context.CustomFields.Values['version'] := '3.2.2';
    Context.CustomFields.Values['target'] := 'x86_64-linux';

    Logger.Info('Installation started', Context);
    AssertTrue(True, 'Logging with custom fields should not throw exception');
  finally
    FreeLogContext(Context);
  end;
end;

procedure TestLoggerConfigDefaults;
var
  Config: TLoggerConfig;
begin
  WriteLn('Testing TLoggerConfig defaults...');

  Config := CreateDefaultLoggerConfig;

  AssertTrue(Config.FileOutputEnabled, 'File output should be enabled by default');
  AssertTrue(Config.ConsoleOutputEnabled, 'Console output should be enabled by default');
  AssertTrue(Config.LogDir <> '', 'LogDir should have default value');
  AssertTrue(Config.MinLevel = llInfo, 'MinLevel should be Info by default');
  AssertTrue(Config.UseColorOutput, 'UseColorOutput should be true by default');
end;

procedure TestFileLogWriterCreation;
var
  Writer: ILogWriter;
begin
  WriteLn('Testing TFileLogWriter creation...');

  Writer := TFileLogWriter.Create(GetTestLogDir + PathDelim + 'test.log');
  AssertTrue(Writer <> nil, 'FileLogWriter should be created');
end;

procedure TestConsoleLogWriterCreation;
var
  Writer: ILogWriter;
begin
  WriteLn('Testing TConsoleLogWriter creation...');

  Writer := TConsoleLogWriter.Create(True);
  AssertTrue(Writer <> nil, 'ConsoleLogWriter should be created');
end;

procedure TestJsonLogFormatterCreation;
var
  Formatter: ILogFormatter;
begin
  WriteLn('Testing TJsonLogFormatter creation...');

  Formatter := TJsonLogFormatter.Create;
  AssertTrue(Formatter <> nil, 'JsonLogFormatter should be created');
end;

procedure TestConsoleLogFormatterCreation;
var
  Formatter: ILogFormatter;
begin
  WriteLn('Testing TConsoleLogFormatter creation...');

  Formatter := TConsoleLogFormatter.Create(True, True, True);
  AssertTrue(Formatter <> nil, 'ConsoleLogFormatter should be created');
end;

procedure TestJsonLogFormatterFormat;
var
  Formatter: ILogFormatter;
  Entry: TLogEntry;
  Output: string;
begin
  WriteLn('Testing TJsonLogFormatter.Format...');

  Formatter := TJsonLogFormatter.Create;

  Entry.Timestamp := Now;
  Entry.Level := llInfo;
  Entry.Message := 'Test message';
  Entry.Source := 'test.module';
  Entry.CorrelationId := 'req-123';
  Entry.ThreadId := 12345;
  Entry.ProcessId := 67890;
  Entry.CustomFields := TStringList.Create;
  try
    Entry.CustomFields.Values['key1'] := 'value1';
    Entry.StackTrace := '';

    Output := Formatter.Format(Entry);

    AssertTrue(Pos('"level": "info"', Output) > 0, 'Output should contain level');
    AssertTrue(Pos('"message": "Test message"', Output) > 0, 'Output should contain message');
    AssertTrue(Pos('"source": "test.module"', Output) > 0, 'Output should contain source');
  finally
    Entry.CustomFields.Free;
  end;
end;

procedure TestConsoleLogFormatterFormat;
var
  Formatter: ILogFormatter;
  Entry: TLogEntry;
  Output: string;
begin
  WriteLn('Testing TConsoleLogFormatter.Format...');

  Formatter := TConsoleLogFormatter.Create(False, True, True);

  Entry.Timestamp := Now;
  Entry.Level := llInfo;
  Entry.Message := 'Test message';
  Entry.Source := 'test.module';
  Entry.CorrelationId := 'req-123';
  Entry.ThreadId := 12345;
  Entry.ProcessId := 67890;
  Entry.CustomFields := nil;
  Entry.StackTrace := '';

  Output := Formatter.Format(Entry);

  AssertTrue(Pos('[INFO]', Output) > 0, 'Output should contain level prefix');
  AssertTrue(Pos('test.module', Output) > 0, 'Output should contain source');
  AssertTrue(Pos('Test message', Output) > 0, 'Output should contain message');
end;

begin
  WriteLn('========================================');
  WriteLn('Running Structured Logger Tests');
  WriteLn('========================================');
  WriteLn;

  TestLogContextCreation;
  TestLogContextWithCorrelationId;
  TestLogContextCustomFields;
  TestStructuredLoggerCreation;
  TestStructuredLoggerOutputControl;
  TestStructuredLoggerInfoLevel;
  TestStructuredLoggerDebugLevel;
  TestStructuredLoggerWarnLevel;
  TestStructuredLoggerErrorLevel;
  TestStructuredLoggerWithCustomFields;
  TestLoggerConfigDefaults;
  TestFileLogWriterCreation;
  TestConsoleLogWriterCreation;
  TestJsonLogFormatterCreation;
  TestConsoleLogFormatterCreation;
  TestJsonLogFormatterFormat;
  TestConsoleLogFormatterFormat;

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
    if GTestLogDir <> '' then
      CleanupTempDir(GTestLogDir);
    Halt(1);
  end
  else
  begin
    WriteLn('SUCCESS: All tests passed');
    if GTestLogDir <> '' then
      CleanupTempDir(GTestLogDir);
    Halt(0);
  end;
end.
