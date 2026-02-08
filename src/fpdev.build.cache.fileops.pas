unit fpdev.build.cache.fileops;

{$mode objfpc}{$H+}

{
  B073: File operation helpers for TBuildCache

  Extracts common file operations and utilities from build.cache.
  Pure functions for file copying, command execution, and date parsing.
}

interface

uses
  SysUtils, Classes, Process, DateUtils;

{ Copy a file from source to destination
  @param ASource - Source file path
  @param ADest - Destination file path
  @return True if copy succeeded }
function BuildCacheFileCopy(const ASource, ADest: string): Boolean;

{ Run an external command
  @param ACmd - Command executable
  @param AArgs - Command arguments
  @param AWorkDir - Working directory (empty for current)
  @return True if command succeeded (exit code 0) }
function BuildCacheRunCommand(const ACmd: string; const AArgs: array of string;
  const AWorkDir: string): Boolean;

{ Parse datetime string in format 'yyyy-mm-dd hh:nn:ss'
  @param ADateStr - Date string to parse
  @return Parsed TDateTime or 0 if invalid }
function BuildCacheParseDateTimeString(const ADateStr: string): TDateTime;

{ Format datetime to string 'yyyy-mm-dd hh:nn:ss'
  @param ADateTime - DateTime to format
  @return Formatted string }
function BuildCacheFormatDateTimeString(ADateTime: TDateTime): string;

implementation

function BuildCacheFileCopy(const ASource, ADest: string): Boolean;
var
  SourceStream, DestStream: TFileStream;
begin
  Result := False;
  try
    SourceStream := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
    try
      DestStream := TFileStream.Create(ADest, fmCreate);
      try
        DestStream.CopyFrom(SourceStream, SourceStream.Size);
        Result := True;
      finally
        DestStream.Free;
      end;
    finally
      SourceStream.Free;
    end;
  except
    on E: Exception do
    begin
      // Silent failure - file copy error
      Result := False;
    end;
  end;
end;

function BuildCacheRunCommand(const ACmd: string; const AArgs: array of string;
  const AWorkDir: string): Boolean;
var
  P: TProcess;
  i: Integer;
begin
  Result := False;
  P := TProcess.Create(nil);
  try
    P.Executable := ACmd;
    for i := Low(AArgs) to High(AArgs) do
      P.Parameters.Add(AArgs[i]);
    if AWorkDir <> '' then
      P.CurrentDirectory := AWorkDir;
    P.Options := [poWaitOnExit, poUsePipes];
    try
      P.Execute;
      Result := (P.ExitStatus = 0);
    except
      on E: Exception do
      begin
        // Silent failure - command execution error
        Result := False;
      end;
    end;
  finally
    P.Free;
  end;
end;

function BuildCacheParseDateTimeString(const ADateStr: string): TDateTime;
var
  Year, Month, Day, Hour, Minute, Second: Word;
begin
  // Parse format: 'yyyy-mm-dd hh:nn:ss'
  // Example: '2026-01-16 05:40:00'
  try
    if Length(ADateStr) >= 19 then
    begin
      Year := StrToInt(Copy(ADateStr, 1, 4));
      Month := StrToInt(Copy(ADateStr, 6, 2));
      Day := StrToInt(Copy(ADateStr, 9, 2));
      Hour := StrToInt(Copy(ADateStr, 12, 2));
      Minute := StrToInt(Copy(ADateStr, 15, 2));
      Second := StrToInt(Copy(ADateStr, 18, 2));
      Result := EncodeDateTime(Year, Month, Day, Hour, Minute, Second, 0);
    end
    else
      Result := 0;  // Invalid format
  except
    on E: Exception do
    begin
      // Silent failure - parsing error
      Result := 0;  // Fallback to epoch if parsing fails
    end;
  end;
end;

function BuildCacheFormatDateTimeString(ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ADateTime);
end;

end.
