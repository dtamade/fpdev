unit fpdev.build.logger;

{
================================================================================
  fpdev.build.logger - Build Process Logger Service
================================================================================

  Handles build logging with timestamp, environment snapshots, and directory
  sampling. Extracted from TBuildManager as part of Facade pattern refactoring.

  Usage:
    Logger := TBuildLogger.Create('/path/to/logs');
    Logger.Verbosity := 1;  // Enable verbose logging
    Logger.Log('Build started');
    Logger.LogEnvSnapshot;
    Logger.Free;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TBuildLogger - Build process logging service }
  TBuildLogger = class
  private
    FLogDir: string;
    FLogFileName: string;
    FVerbosity: Integer;  // 0=normal, 1=verbose

    function GetLogFileName: string;

  public
    constructor Create(const ALogDir: string);

    { Core logging method - writes timestamped line to log file }
    procedure Log(const ALine: string);

    { Logs sample of directory contents (up to ALimit entries) }
    procedure LogDirSample(const ADir: string; ALimit: Integer);

    { Logs environment snapshot (OS, PATH entries) }
    procedure LogEnvSnapshot;

    { Logs test summary with version, context, result and elapsed time }
    procedure LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);

    { Log file path }
    property LogFileName: string read GetLogFileName;

    { Verbosity level: 0=normal, 1=verbose }
    property Verbosity: Integer read FVerbosity write FVerbosity;
  end;

implementation

{ TBuildLogger }

constructor TBuildLogger.Create(const ALogDir: string);
begin
  inherited Create;
  FLogDir := ALogDir;
  FLogFileName := '';
  FVerbosity := 0;

  // Ensure log directory exists
  if (FLogDir <> '') and (not DirectoryExists(FLogDir)) then
    ForceDirectories(FLogDir);
end;

function TBuildLogger.GetLogFileName: string;
var
  LStamp: string;
begin
  if FLogFileName <> '' then
    Exit(FLogFileName);

  LStamp := FormatDateTime('yyyymmdd_hhnnss_zzz', Now);
  FLogFileName := IncludeTrailingPathDelimiter(FLogDir) + 'build_' + LStamp + '.log';
  Result := FLogFileName;
end;

procedure TBuildLogger.Log(const ALine: string);
var
  LLogPath: string;
  F: TextFile;
begin
  LLogPath := GetLogFileName;
  AssignFile(F, LLogPath);
  try
    if FileExists(LLogPath) then
      Append(F)
    else
      Rewrite(F);
    WriteLn(F, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), ' ', ALine);
  finally
    CloseFile(F);
  end;
end;

procedure TBuildLogger.LogDirSample(const ADir: string; ALimit: Integer);
var
  SR: TSearchRec;
  LCount: Integer;
  LBase: string;
begin
  if FVerbosity = 0 then Exit;

  if not DirectoryExists(ADir) then
  begin
    Log('dir not exists: ' + ADir);
    Exit;
  end;

  LBase := IncludeTrailingPathDelimiter(ADir);
  LCount := 0;

  if FindFirst(LBase + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Log(' - ' + SR.Name);
        Inc(LCount);
        if (ALimit > 0) and (LCount >= ALimit) then Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

procedure TBuildLogger.LogEnvSnapshot;
var
  LOS, LPath: string;
  i, LCount, LMax: Integer;
  LParts: TStringList;
begin
  if FVerbosity = 0 then Exit;

  {$IFDEF MSWINDOWS}
  LOS := 'Windows';
  {$ELSE}
  LOS := 'Unix-like';
  {$ENDIF}
  Log('env: OS=' + LOS);

  // PATH fragments
  LPath := GetEnvironmentVariable('PATH');
  LParts := TStringList.Create;
  try
    {$IFDEF MSWINDOWS}
    LParts.Delimiter := ';';
    {$ELSE}
    LParts.Delimiter := ':';
    {$ENDIF}
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := LPath;

    LCount := LParts.Count;
    LMax := 5;
    if LCount < LMax then LMax := LCount;

    for i := 0 to LMax - 1 do
      Log('env: PATH[' + IntToStr(i) + ']=' + LParts[i]);
  finally
    LParts.Free;
  end;
end;

procedure TBuildLogger.LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  Log('Summary: version=' + AVersion + ' context=' + AContext + ' result=' + AResult + ' elapsed_ms=' + IntToStr(AElapsedMs));
end;

end.
