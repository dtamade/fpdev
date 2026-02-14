unit fpdev.fpc.logger;

{$mode objfpc}{$H+}

{
  FPC Logger
  
  改进的日志系统，支持：
  - 日志级别过滤 (Debug, Info, Warn, Error)
  - 文件追加写入（不重新加载整个文件）
  - Exception-safe (does not propagate exceptions to caller)
  - 单例模式
}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  { TLogLevel - 日志级别 }
  TLogLevel = (
    llDebug,   // 调试信息
    llInfo,    // General information
    llWarn,    // 警告
    llError    // 错误
  );

  { TLogger - 日志管理器（单例） }
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
    
    { 初始化日志文件 }
    procedure Initialize(const ALogFile: string);
    
    { 关闭日志文件 }
    procedure Shutdown;
    
    { 记录日志 }
    procedure Log(ALevel: TLogLevel; const AMessage: string);
    procedure Log(ALevel: TLogLevel; const AFormat: string; const AArgs: array of const);
    
    { 便捷方法 }
    procedure Debug(const AMessage: string);
    procedure Debug(const AFormat: string; const AArgs: array of const);
    procedure Info(const AMessage: string);
    procedure Info(const AFormat: string; const AArgs: array of const);
    procedure Warn(const AMessage: string);
    procedure Warn(const AFormat: string; const AArgs: array of const);
    procedure Error(const AMessage: string);
    procedure Error(const AFormat: string; const AArgs: array of const);
    
    { 获取单例实例 }
    class function Instance: TLogger;
    class procedure FreeInstance;
    
    property LogFile: string read FLogFile;
    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

{ 全局便捷函数 }
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
    // 关闭之前的文件
    if Assigned(FFileStream) then
    begin
      FFileStream.Free;
      FFileStream := nil;
    end;
    
    FLogFile := ALogFile;
    
    if FLogFile = '' then
      Exit;
    
    try
      // 确保目录存在
      if not DirectoryExists(ExtractFileDir(FLogFile)) then
        ForceDirectories(ExtractFileDir(FLogFile));
      
      // Open file in append mode
      if FileExists(FLogFile) then
        FFileStream := TFileStream.Create(FLogFile, fmOpenWrite or fmShareDenyNone)
      else
        FFileStream := TFileStream.Create(FLogFile, fmCreate or fmShareDenyNone);
      
      // Move to end of file
      FFileStream.Seek(0, soEnd);
      
      // 写入启动标记
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
        // 忽略写入错误
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

{ 全局便捷函数 }

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
