unit fpdev.build.cache.entryio;

{$mode objfpc}{$H+}

{
  B077: Build entry file I/O helpers for TBuildCache

  Extracts build cache entry file read/write operations.
  Pure functions for loading and saving cache entry lists.
}

interface

uses
  SysUtils, Classes;

{ Load cache entries from text file
  @param AFilePath - Path to cache file
  @param AEntries - StringList to populate
  @return True if file was loaded }
function BuildCacheLoadEntriesFile(const AFilePath: string;
  AEntries: TStringList): Boolean;

{ Save cache entries to text file
  @param AFilePath - Path to cache file
  @param ACacheDir - Cache directory (to ensure exists)
  @param AEntries - StringList to save }
procedure BuildCacheSaveEntriesFile(const AFilePath, ACacheDir: string;
  AEntries: TStringList);

{ Format a build cache entry line
  @param AVersion - Version string
  @param ARevision - Git revision
  @param ABuildTime - Build timestamp
  @param ACPU - CPU architecture
  @param AOS - Operating system
  @param AStatus - Build step status ordinal
  @return Formatted entry line }
function BuildCacheFormatEntryLine(const AVersion, ARevision: string;
  ABuildTime: TDateTime; const ACPU, AOS: string; AStatus: Integer): string;

{ Parse revision from cache entry line
  @param ALine - Entry line
  @return Revision string or empty }
function BuildCacheParseRevision(const ALine: string): string;

{ Parse status from cache entry line
  @param ALine - Entry line
  @return Status ordinal or -1 if not found }
function BuildCacheParseStatus(const ALine: string): Integer;

implementation

uses
  StrUtils;

function BuildCacheLoadEntriesFile(const AFilePath: string;
  AEntries: TStringList): Boolean;
var
  F: TextFile;
  Line: string;
  FileOpened: Boolean;
begin
  Result := False;

  if not FileExists(AFilePath) then
    Exit;

  AssignFile(F, AFilePath);
  FileOpened := False;
  try
    Reset(F);
    FileOpened := True;
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      if Line <> '' then
        AEntries.Add(Line);
    end;
    Result := True;
  finally
    if FileOpened then
      CloseFile(F);
  end;
end;

procedure BuildCacheSaveEntriesFile(const AFilePath, ACacheDir: string;
  AEntries: TStringList);
var
  F: TextFile;
  i: Integer;
  FileOpened: Boolean;
begin
  ForceDirectories(ACacheDir);
  AssignFile(F, AFilePath);
  FileOpened := False;
  try
    Rewrite(F);
    FileOpened := True;
    for i := 0 to AEntries.Count - 1 do
      WriteLn(F, AEntries[i]);
  finally
    if FileOpened then
      CloseFile(F);
  end;
end;

function BuildCacheFormatEntryLine(const AVersion, ARevision: string;
  ABuildTime: TDateTime; const ACPU, AOS: string; AStatus: Integer): string;
begin
  Result := Format('version=%s;revision=%s;time=%s;cpu=%s;os=%s;status=%d',
    [AVersion, ARevision, FormatDateTime('yyyy-mm-dd_hh:nn:ss', ABuildTime),
     ACPU, AOS, AStatus]);
end;

function BuildCacheParseRevision(const ALine: string): string;
var
  RevPos, EndPos: Integer;
begin
  Result := '';

  RevPos := Pos('revision=', ALine);
  if RevPos > 0 then
  begin
    RevPos := RevPos + 9;
    EndPos := PosEx(';', ALine, RevPos);
    if EndPos > RevPos then
      Result := Copy(ALine, RevPos, EndPos - RevPos)
    else
      Result := Copy(ALine, RevPos, Length(ALine));
  end;
end;

function BuildCacheParseStatus(const ALine: string): Integer;
var
  StatusPos: Integer;
  StatusStr: string;
begin
  Result := -1;

  StatusPos := Pos('status=', ALine);
  if StatusPos > 0 then
  begin
    StatusStr := Copy(ALine, StatusPos + 7, 1);
    Result := StrToIntDef(StatusStr, -1);
  end;
end;

end.
