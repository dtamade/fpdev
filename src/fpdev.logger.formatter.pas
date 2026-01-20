unit fpdev.logger.formatter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.logger.intf, fpdev.logger.writer;

type
  { ILogFormatter - Log formatter interface }
  ILogFormatter = interface
    ['{5C0D1E2F-7A8B-9C0D-1E2F-3A4B5C6D7E8F}']
    function Format(const AEntry: TLogEntry): string;
  end;

  { TJsonLogFormatter - JSON log formatter }
  TJsonLogFormatter = class(TInterfacedObject, ILogFormatter)
  public
    function Format(const AEntry: TLogEntry): string;
  end;

  { TConsoleLogFormatter - Console log formatter }
  TConsoleLogFormatter = class(TInterfacedObject, ILogFormatter)
  private
    FUseColor: Boolean;
    FIncludeThreadId: Boolean;
    FIncludeProcessId: Boolean;
  public
    constructor Create(AUseColor: Boolean; AIncludeThreadId: Boolean; AIncludeProcessId: Boolean);
    function Format(const AEntry: TLogEntry): string;
  end;

implementation

{ TJsonLogFormatter }

function TJsonLogFormatter.Format(const AEntry: TLogEntry): string;
var
  Timestamp: string;
  Level: string;
  i: Integer;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    // Format timestamp
    Timestamp := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AEntry.Timestamp);

    // Format level
    case AEntry.Level of
      llDebug: Level := 'debug';
      llInfo: Level := 'info';
      llWarn: Level := 'warn';
      llError: Level := 'error';
    else
      Level := 'unknown';
    end;

    // Build JSON
    Lines.Add('{');
    Lines.Add('  "timestamp": "' + Timestamp + '",');
    Lines.Add('  "level": "' + Level + '",');
    Lines.Add('  "message": "' + AEntry.Message + '",');
    Lines.Add('  "source": "' + AEntry.Source + '",');
    Lines.Add('  "correlation_id": "' + AEntry.CorrelationId + '",');
    Lines.Add('  "thread_id": ' + IntToStr(AEntry.ThreadId) + ',');
    Lines.Add('  "process_id": ' + IntToStr(AEntry.ProcessId) + ',');

    // Add custom fields
    if (AEntry.CustomFields <> nil) and (AEntry.CustomFields.Count > 0) then
    begin
      Lines.Add('  "context": {');
      for i := 0 to AEntry.CustomFields.Count - 1 do
      begin
        if i < AEntry.CustomFields.Count - 1 then
          Lines.Add('    "' + AEntry.CustomFields.Names[i] + '": "' + AEntry.CustomFields.ValueFromIndex[i] + '",')
        else
          Lines.Add('    "' + AEntry.CustomFields.Names[i] + '": "' + AEntry.CustomFields.ValueFromIndex[i] + '"');
      end;
      Lines.Add('  },');
    end
    else
      Lines.Add('  "context": {},');

    // Add stack trace
    if AEntry.StackTrace <> '' then
      Lines.Add('  "stack_trace": "' + AEntry.StackTrace + '"')
    else
      Lines.Add('  "stack_trace": null');

    Lines.Add('}');

    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

{ TConsoleLogFormatter }

constructor TConsoleLogFormatter.Create(AUseColor: Boolean; AIncludeThreadId: Boolean; AIncludeProcessId: Boolean);
begin
  inherited Create;
  FUseColor := AUseColor;
  FIncludeThreadId := AIncludeThreadId;
  FIncludeProcessId := AIncludeProcessId;
end;

function TConsoleLogFormatter.Format(const AEntry: TLogEntry): string;
var
  Timestamp: string;
  Prefix: string;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    // Format timestamp
    Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss', AEntry.Timestamp);
    Parts.Add(Timestamp);

    // Format level prefix
    case AEntry.Level of
      llDebug: Prefix := '[DEBUG]';
      llInfo: Prefix := '[INFO]';
      llWarn: Prefix := '[WARN]';
      llError: Prefix := '[ERROR]';
    else
      Prefix := '[UNKNOWN]';
    end;
    Parts.Add(Prefix);

    // Add source
    Parts.Add('[' + AEntry.Source + ']');

    // Add thread/process ID if enabled
    if FIncludeThreadId then
      Parts.Add('[T:' + IntToStr(AEntry.ThreadId) + ']');
    if FIncludeProcessId then
      Parts.Add('[P:' + IntToStr(AEntry.ProcessId) + ']');

    // Add message
    Parts.Add(AEntry.Message);

    // Join parts with space
    Result := Parts.DelimitedText;
    Result := StringReplace(Result, ',', ' ', [rfReplaceAll]);
    Result := StringReplace(Result, '"', '', [rfReplaceAll]);
  finally
    Parts.Free;
  end;
end;

end.
