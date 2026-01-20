unit fpdev.logger.structured;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.logger.intf;

type
  { TLogContext - Log context information }
  TLogContext = record
    Source: string;           // Module name (e.g., 'fpdev.fpc.installer')
    CorrelationId: string;    // Correlation ID (for request tracing)
    ThreadId: Cardinal;       // Thread ID
    ProcessId: Cardinal;      // Process ID
    CustomFields: TStringList; // Custom key-value pairs
  end;

  { TRotationConfig - Log rotation configuration }
  TRotationConfig = record
    MaxFileSize: Int64;        // Maximum file size in bytes (e.g., 10MB)
    RotationInterval: Integer; // Rotation interval in hours (e.g., 24)
    MaxFiles: Integer;         // Number of files to keep (e.g., 5)
    MaxAge: Integer;           // Maximum age in days (e.g., 7)
    CompressOld: Boolean;      // Whether to compress old logs
  end;

  { TLoggerConfig - Logger configuration }
  TLoggerConfig = record
    // Output control
    FileOutputEnabled: Boolean;
    ConsoleOutputEnabled: Boolean;

    // File configuration
    LogDir: string;
    LogFileName: string;  // Optional, auto-generated if empty

    // Rotation configuration
    RotationConfig: TRotationConfig;

    // Log level filtering
    MinLevel: TLogLevel;  // Minimum log level (e.g., llInfo)

    // Formatting options
    UseColorOutput: Boolean;  // Console color output
    IncludeThreadId: Boolean;
    IncludeProcessId: Boolean;
  end;

  { IStructuredLogger - Structured logger interface }
  IStructuredLogger = interface
    ['{3F8A9B2C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    // Core logging methods
    procedure Log(const ALevel: TLogLevel; const AMessage: string;
                  const AContext: TLogContext);
    procedure Debug(const AMessage: string; const AContext: TLogContext);
    procedure Info(const AMessage: string; const AContext: TLogContext);
    procedure Warn(const AMessage: string; const AContext: TLogContext);
    procedure Error(const AMessage: string; const AContext: TLogContext;
                    const AStackTrace: string = '');

    // Output control
    procedure SetFileOutput(AEnabled: Boolean);
    procedure SetConsoleOutput(AEnabled: Boolean);
    function IsFileOutputEnabled: Boolean;
    function IsConsoleOutputEnabled: Boolean;
  end;

  { TStructuredLogger - Structured logger implementation }
  TStructuredLogger = class(TInterfacedObject, IStructuredLogger)
  private
    FConfig: TLoggerConfig;
    FFileOutputEnabled: Boolean;
    FConsoleOutputEnabled: Boolean;

    procedure WriteToFile(const ALevel: TLogLevel; const AMessage: string;
                          const AContext: TLogContext; const AStackTrace: string);
    procedure WriteToConsole(const ALevel: TLogLevel; const AMessage: string;
                             const AContext: TLogContext);
    function LevelToString(const ALevel: TLogLevel): string;
  public
    constructor Create(const AConfig: TLoggerConfig);
    destructor Destroy; override;

    // IStructuredLogger implementation
    procedure Log(const ALevel: TLogLevel; const AMessage: string;
                  const AContext: TLogContext);
    procedure Debug(const AMessage: string; const AContext: TLogContext);
    procedure Info(const AMessage: string; const AContext: TLogContext);
    procedure Warn(const AMessage: string; const AContext: TLogContext);
    procedure Error(const AMessage: string; const AContext: TLogContext;
                    const AStackTrace: string = '');

    procedure SetFileOutput(AEnabled: Boolean);
    procedure SetConsoleOutput(AEnabled: Boolean);
    function IsFileOutputEnabled: Boolean;
    function IsConsoleOutputEnabled: Boolean;
  end;

{ Helper functions }
function CreateLogContext(const ASource: string; const ACorrelationId: string = ''): TLogContext;
procedure FreeLogContext(var AContext: TLogContext);
function CreateDefaultLoggerConfig: TLoggerConfig;

implementation

uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  DateUtils;

{ Helper functions }

function CreateLogContext(const ASource: string; const ACorrelationId: string): TLogContext;
begin
  Result.Source := ASource;
  Result.CorrelationId := ACorrelationId;
  Result.ThreadId := GetCurrentThreadId;
  {$IFDEF UNIX}
  Result.ProcessId := FpGetpid;
  {$ELSE}
  Result.ProcessId := GetCurrentProcessId;
  {$ENDIF}
  Result.CustomFields := TStringList.Create;
end;

procedure FreeLogContext(var AContext: TLogContext);
begin
  if AContext.CustomFields <> nil then
  begin
    AContext.CustomFields.Free;
    AContext.CustomFields := nil;
  end;
end;

function CreateDefaultLoggerConfig: TLoggerConfig;
begin
  Result.FileOutputEnabled := True;
  Result.ConsoleOutputEnabled := True;
  Result.LogDir := 'logs';
  Result.LogFileName := '';
  Result.MinLevel := llInfo;
  Result.UseColorOutput := True;
  Result.IncludeThreadId := True;
  Result.IncludeProcessId := True;

  // Default rotation config
  Result.RotationConfig.MaxFileSize := 10 * 1024 * 1024;  // 10MB
  Result.RotationConfig.RotationInterval := 24;  // 24 hours
  Result.RotationConfig.MaxFiles := 5;
  Result.RotationConfig.MaxAge := 7;  // 7 days
  Result.RotationConfig.CompressOld := False;
end;

{ TStructuredLogger }

constructor TStructuredLogger.Create(const AConfig: TLoggerConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FFileOutputEnabled := AConfig.FileOutputEnabled;
  FConsoleOutputEnabled := AConfig.ConsoleOutputEnabled;

  // Ensure log directory exists
  if FFileOutputEnabled and (FConfig.LogDir <> '') then
  begin
    if not DirectoryExists(FConfig.LogDir) then
      ForceDirectories(FConfig.LogDir);
  end;
end;

destructor TStructuredLogger.Destroy;
begin
  inherited Destroy;
end;

function TStructuredLogger.LevelToString(const ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug: Result := 'debug';
    llInfo: Result := 'info';
    llWarn: Result := 'warn';
    llError: Result := 'error';
  end;
end;

procedure TStructuredLogger.WriteToFile(const ALevel: TLogLevel; const AMessage: string;
                                        const AContext: TLogContext; const AStackTrace: string);
var
  LogFile: TextFile;
  LogPath: string;
  Timestamp: string;
  i: Integer;
begin
  if not FFileOutputEnabled then
    Exit;

  // Generate log file path
  if FConfig.LogFileName <> '' then
    LogPath := IncludeTrailingPathDelimiter(FConfig.LogDir) + FConfig.LogFileName
  else
    LogPath := IncludeTrailingPathDelimiter(FConfig.LogDir) + 'fpdev.log';

  // Format timestamp
  Timestamp := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', Now);

  // Write JSON log entry
  AssignFile(LogFile, LogPath);
  try
    if FileExists(LogPath) then
      Append(LogFile)
    else
      Rewrite(LogFile);

    WriteLn(LogFile, '{');
    WriteLn(LogFile, '  "timestamp": "', Timestamp, '",');
    WriteLn(LogFile, '  "level": "', LevelToString(ALevel), '",');
    WriteLn(LogFile, '  "message": "', AMessage, '",');
    WriteLn(LogFile, '  "source": "', AContext.Source, '",');
    WriteLn(LogFile, '  "correlation_id": "', AContext.CorrelationId, '",');
    WriteLn(LogFile, '  "thread_id": ', AContext.ThreadId, ',');
    WriteLn(LogFile, '  "process_id": ', AContext.ProcessId, ',');

    // Write custom fields
    if (AContext.CustomFields <> nil) and (AContext.CustomFields.Count > 0) then
    begin
      WriteLn(LogFile, '  "context": {');
      for i := 0 to AContext.CustomFields.Count - 1 do
      begin
        if i < AContext.CustomFields.Count - 1 then
          WriteLn(LogFile, '    "', AContext.CustomFields.Names[i], '": "', AContext.CustomFields.ValueFromIndex[i], '",')
        else
          WriteLn(LogFile, '    "', AContext.CustomFields.Names[i], '": "', AContext.CustomFields.ValueFromIndex[i], '"');
      end;
      WriteLn(LogFile, '  },');
    end
    else
      WriteLn(LogFile, '  "context": {},');

    // Write stack trace
    if AStackTrace <> '' then
      WriteLn(LogFile, '  "stack_trace": "', AStackTrace, '"')
    else
      WriteLn(LogFile, '  "stack_trace": null');

    WriteLn(LogFile, '}');
  finally
    CloseFile(LogFile);
  end;
end;

procedure TStructuredLogger.WriteToConsole(const ALevel: TLogLevel; const AMessage: string;
                                           const AContext: TLogContext);
var
  Prefix: string;
  Timestamp: string;
begin
  if not FConsoleOutputEnabled then
    Exit;

  Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);

  case ALevel of
    llDebug: Prefix := '[DEBUG]';
    llInfo: Prefix := '[INFO]';
    llWarn: Prefix := '[WARN]';
    llError: Prefix := '[ERROR]';
  end;

  WriteLn(Timestamp, ' ', Prefix, ' [', AContext.Source, '] ', AMessage);
end;

procedure TStructuredLogger.Log(const ALevel: TLogLevel; const AMessage: string;
                                const AContext: TLogContext);
begin
  // Filter by minimum level
  if ALevel < FConfig.MinLevel then
    Exit;

  WriteToFile(ALevel, AMessage, AContext, '');
  WriteToConsole(ALevel, AMessage, AContext);
end;

procedure TStructuredLogger.Debug(const AMessage: string; const AContext: TLogContext);
begin
  Log(llDebug, AMessage, AContext);
end;

procedure TStructuredLogger.Info(const AMessage: string; const AContext: TLogContext);
begin
  Log(llInfo, AMessage, AContext);
end;

procedure TStructuredLogger.Warn(const AMessage: string; const AContext: TLogContext);
begin
  Log(llWarn, AMessage, AContext);
end;

procedure TStructuredLogger.Error(const AMessage: string; const AContext: TLogContext;
                                  const AStackTrace: string);
begin
  WriteToFile(llError, AMessage, AContext, AStackTrace);
  WriteToConsole(llError, AMessage, AContext);
end;

procedure TStructuredLogger.SetFileOutput(AEnabled: Boolean);
begin
  FFileOutputEnabled := AEnabled;
end;

procedure TStructuredLogger.SetConsoleOutput(AEnabled: Boolean);
begin
  FConsoleOutputEnabled := AEnabled;
end;

function TStructuredLogger.IsFileOutputEnabled: Boolean;
begin
  Result := FFileOutputEnabled;
end;

function TStructuredLogger.IsConsoleOutputEnabled: Boolean;
begin
  Result := FConsoleOutputEnabled;
end;

end.
