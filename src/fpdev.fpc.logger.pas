unit fpdev.fpc.logger;

{$mode objfpc}{$H+}

{
  FPC Logger
  
  Improved logging system with support for:
  - Log level filtering (Debug, Info, Warn, Error)
  - Append writes to file (does not reload the entire file)
  - Exception-safe (does not propagate exceptions to caller)
  - Singleton pattern
}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  { TLogLevel - Log level }
  TLogLevel = (
    llDebug,   // Debug information
    llInfo,    // General information
    llWarn,    // Warning
    llError    // Error
  );

  { TLogger - Log manager (singleton) }
  TLogger = class
  private
    FLogFile: string;
    FMinLevel: TLogLevel;
    FEnabled: Boolean;
    FLock: TCriticalSection;
    FFileStream: TFileStream;
    
    class var FInstance: TLogger;
    
    procedure WriteToFile(const AMessage: string);
    function FormatLogMessage(ALevel: TLogLevel; const AMessage: string): string;
    function LevelToString(ALevel: TLogLevel): string;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    { Initialize log file }
    procedure Initialize(const ALogFile: string);
    
    { Shutdown log file }
    procedure Shutdown;
    
    { Write log entry }
    procedure Log(ALevel: TLogLevel; const AMessage: string);
    procedure Log(ALevel: TLogLevel; const AFormat: string; const AArgs: array of const);
    
    { Convenience methods }
    procedure Debug(const AMessage: string);
    procedure Debug(const AFormat: string; const AArgs: array of const);
    procedure Info(const AMessage: string);
    procedure Info(const AFormat: string; const AArgs: array of const);
    procedure Warn(const AMessage: string);
    procedure Warn(const AFormat: string; const AArgs: array of const);
    procedure Error(const AMessage: string);
    procedure Error(const AFormat: string; const AArgs: array of const);
    
    { Get singleton instance }
    class function Instance: TLogger;
    class procedure FreeInstance;
    
    property LogFile: string read FLogFile;
    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

{ Global convenience functions }
procedure InitLogger(const ALogFile: string);
procedure ShutdownLogger;
procedure LogDebug(const AMessage: string);
procedure LogInfo(const AMessage: string);
procedure LogWarn(const AMessage: string);
procedure LogError(const AMessage: string);
procedure SetLogLevel(ALevel: TLogLevel);
procedure EnableLogging(AEnabled: Boolean);

implementation

{ TLogger }

constructor TLogger.Create;
begin
  inherited Create;
  FLogFile := '';
  FMinLevel := llInfo;
  FEnabled := True;
  FLock := TCriticalSection.Create;
  FFileStream := nil;
end;

destructor TLogger.Destroy;
begin
  Shutdown;
  FLock.Free;
  inherited Destroy;
end;

procedure TLogger.Initialize(const ALogFile: string);
begin
  FLock.Enter;
  try
    // Close previous file
    if Assigned(FFileStream) then
    begin
      FFileStream.Free;
      FFileStream := nil;
    end;
    
    FLogFile := ALogFile;
    
    if FLogFile = '' then
      Exit;
    
    try
      // Ensure directory exists
      if not DirectoryExists(ExtractFileDir(FLogFile)) then
        ForceDirectories(ExtractFileDir(FLogFile));
      
      // Open file in append mode
      if FileExists(FLogFile) then
        FFileStream := TFileStream.Create(FLogFile, fmOpenWrite or fmShareDenyNone)
      else
        FFileStream := TFileStream.Create(FLogFile, fmCreate or fmShareDenyNone);
      
      // Move to end of file
      FFileStream.Seek(0, soEnd);
      
      // Write startup marker
      WriteToFile('=== Logger initialized at ' + DateTimeToStr(Now) + ' ===');
    except
      // Ignore file open errors, disable logging
      FFileStream := nil;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.Shutdown;
begin
  FLock.Enter;
  try
    if Assigned(FFileStream) then
    begin
      try
        WriteToFile('=== Logger shutdown at ' + DateTimeToStr(Now) + ' ===');
      except
        // Ignore write errors
      end;
      
      FFileStream.Free;
      FFileStream := nil;
    end;
    
    FLogFile := '';
  finally
    FLock.Leave;
  end;
end;

function TLogger.LevelToString(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
  else
    Result := 'UNKNOWN';
  end;
end;

function TLogger.FormatLogMessage(ALevel: TLogLevel; const AMessage: string): string;
begin
  Result := Format('[%s] [%s] %s', [
    FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
    LevelToString(ALevel),
    AMessage
  ]);
end;

procedure TLogger.WriteToFile(const AMessage: string);
var
  Line: string;
  Bytes: TBytes;
begin
  if not Assigned(FFileStream) then
    Exit;
  
  try
    Line := AMessage + LineEnding;
    Bytes := TEncoding.UTF8.GetBytes(Line);
    FFileStream.Write(Bytes[0], Length(Bytes));
  except
    // Ignore write errors, do not propagate exceptions to caller
  end;
end;

procedure TLogger.Log(ALevel: TLogLevel; const AMessage: string);
begin
  if not FEnabled then
    Exit;
  
  if Ord(ALevel) < Ord(FMinLevel) then
    Exit;
  
  FLock.Enter;
  try
    WriteToFile(FormatLogMessage(ALevel, AMessage));
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.Log(ALevel: TLogLevel; const AFormat: string; const AArgs: array of const);
begin
  Log(ALevel, Format(AFormat, AArgs));
end;

procedure TLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TLogger.Debug(const AFormat: string; const AArgs: array of const);
begin
  Log(llDebug, AFormat, AArgs);
end;

procedure TLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TLogger.Info(const AFormat: string; const AArgs: array of const);
begin
  Log(llInfo, AFormat, AArgs);
end;

procedure TLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TLogger.Warn(const AFormat: string; const AArgs: array of const);
begin
  Log(llWarn, AFormat, AArgs);
end;

procedure TLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

procedure TLogger.Error(const AFormat: string; const AArgs: array of const);
begin
  Log(llError, AFormat, AArgs);
end;

class function TLogger.Instance: TLogger;
begin
  if not Assigned(FInstance) then
    FInstance := TLogger.Create;
  Result := FInstance;
end;

class procedure TLogger.FreeInstance;
begin
  if Assigned(FInstance) then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

{ Global convenience functions }

procedure InitLogger(const ALogFile: string);
begin
  TLogger.Instance.Initialize(ALogFile);
end;

procedure ShutdownLogger;
begin
  TLogger.Instance.Shutdown;
end;

procedure LogDebug(const AMessage: string);
begin
  TLogger.Instance.Debug(AMessage);
end;

procedure LogInfo(const AMessage: string);
begin
  TLogger.Instance.Info(AMessage);
end;

procedure LogWarn(const AMessage: string);
begin
  TLogger.Instance.Warn(AMessage);
end;

procedure LogError(const AMessage: string);
begin
  TLogger.Instance.Error(AMessage);
end;

procedure SetLogLevel(ALevel: TLogLevel);
begin
  TLogger.Instance.MinLevel := ALevel;
end;

procedure EnableLogging(AEnabled: Boolean);
begin
  TLogger.Instance.Enabled := AEnabled;
end;

initialization
  TLogger.FInstance := nil;

finalization
  TLogger.FreeInstance;

end.
