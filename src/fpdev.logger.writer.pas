unit fpdev.logger.writer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.logger.intf;

type
  { TLogEntry - Log entry record }
  TLogEntry = record
    Timestamp: TDateTime;
    Level: TLogLevel;
    Message: string;
    Source: string;
    CorrelationId: string;
    ThreadId: Cardinal;
    ProcessId: Cardinal;
    CustomFields: TStringList;
    StackTrace: string;
  end;

  { ILogWriter - Log writer interface }
  ILogWriter = interface
    ['{4A9B0C1D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    procedure Write(const AEntry: TLogEntry);
    procedure Flush;
    procedure Close;
  end;

  { TFileLogWriter - File-based log writer }
  TFileLogWriter = class(TInterfacedObject, ILogWriter)
  private
    FLogPath: string;
    FFormatter: TObject;  // Will be ILogFormatter after we create it
  public
    constructor Create(const ALogPath: string);
    destructor Destroy; override;

    procedure Write(const AEntry: TLogEntry);
    procedure Flush;
    procedure Close;
  end;

  { TConsoleLogWriter - Console-based log writer }
  TConsoleLogWriter = class(TInterfacedObject, ILogWriter)
  private
    FFormatter: TObject;  // Will be ILogFormatter after we create it
    FUseColor: Boolean;
  public
    constructor Create(AUseColor: Boolean);
    destructor Destroy; override;

    procedure Write(const AEntry: TLogEntry);
    procedure Flush;
    procedure Close;
  end;

implementation

{ TFileLogWriter }

constructor TFileLogWriter.Create(const ALogPath: string);
begin
  inherited Create;
  FLogPath := ALogPath;
  FFormatter := nil;
end;

destructor TFileLogWriter.Destroy;
begin
  inherited Destroy;
end;

procedure TFileLogWriter.Write(const AEntry: TLogEntry);
var
  LogFile: TextFile;
  Timestamp: string;
  i: Integer;
begin
  // Format timestamp
  Timestamp := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AEntry.Timestamp);

  // Write JSON log entry
  AssignFile(LogFile, FLogPath);
  try
    if FileExists(FLogPath) then
      Append(LogFile)
    else
      Rewrite(LogFile);

    WriteLn(LogFile, '{');
    WriteLn(LogFile, '  "timestamp": "', Timestamp, '",');

    case AEntry.Level of
      llDebug: WriteLn(LogFile, '  "level": "debug",');
      llInfo: WriteLn(LogFile, '  "level": "info",');
      llWarn: WriteLn(LogFile, '  "level": "warn",');
      llError: WriteLn(LogFile, '  "level": "error",');
    end;

    WriteLn(LogFile, '  "message": "', AEntry.Message, '",');
    WriteLn(LogFile, '  "source": "', AEntry.Source, '",');
    WriteLn(LogFile, '  "correlation_id": "', AEntry.CorrelationId, '",');
    WriteLn(LogFile, '  "thread_id": ', AEntry.ThreadId, ',');
    WriteLn(LogFile, '  "process_id": ', AEntry.ProcessId, ',');

    // Write custom fields
    if (AEntry.CustomFields <> nil) and (AEntry.CustomFields.Count > 0) then
    begin
      WriteLn(LogFile, '  "context": {');
      for i := 0 to AEntry.CustomFields.Count - 1 do
      begin
        if i < AEntry.CustomFields.Count - 1 then
          WriteLn(LogFile, '    "', AEntry.CustomFields.Names[i], '": "', AEntry.CustomFields.ValueFromIndex[i], '",')
        else
          WriteLn(LogFile, '    "', AEntry.CustomFields.Names[i], '": "', AEntry.CustomFields.ValueFromIndex[i], '"');
      end;
      WriteLn(LogFile, '  },');
    end
    else
      WriteLn(LogFile, '  "context": {},');

    // Write stack trace
    if AEntry.StackTrace <> '' then
      WriteLn(LogFile, '  "stack_trace": "', AEntry.StackTrace, '"')
    else
      WriteLn(LogFile, '  "stack_trace": null');

    WriteLn(LogFile, '}');
  finally
    CloseFile(LogFile);
  end;
end;

procedure TFileLogWriter.Flush;
begin
  // File is flushed on each write
end;

procedure TFileLogWriter.Close;
begin
  // Nothing to close for file-based writer
end;

{ TConsoleLogWriter }

constructor TConsoleLogWriter.Create(AUseColor: Boolean);
begin
  inherited Create;
  FUseColor := AUseColor;
  FFormatter := nil;
end;

destructor TConsoleLogWriter.Destroy;
begin
  inherited Destroy;
end;

procedure TConsoleLogWriter.Write(const AEntry: TLogEntry);
var
  Prefix: string;
  Timestamp: string;
begin
  Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss', AEntry.Timestamp);

  case AEntry.Level of
    llDebug: Prefix := '[DEBUG]';
    llInfo: Prefix := '[INFO]';
    llWarn: Prefix := '[WARN]';
    llError: Prefix := '[ERROR]';
  else
    Prefix := '[UNKNOWN]';
  end;

  WriteLn(Timestamp, ' ', Prefix, ' [', AEntry.Source, '] ', AEntry.Message);
end;

procedure TConsoleLogWriter.Flush;
begin
  // Console is flushed automatically
end;

procedure TConsoleLogWriter.Close;
begin
  // Nothing to close for console writer
end;

end.
