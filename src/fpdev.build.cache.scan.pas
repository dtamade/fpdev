unit fpdev.build.cache.scan;

{$mode objfpc}{$H+}

{
  B076: Directory scanning helpers for TBuildCache

  Extracts cache directory scanning and size calculation from build.cache.
  Pure functions for listing and measuring cache contents.
}

interface

uses
  SysUtils, Classes;

{ Calculate total size of cache archives
  @param ACacheDir - Cache directory path
  @return Total size in bytes }
function BuildCacheGetTotalSize(const ACacheDir: string): Int64;

{ List all cached versions from archive files
  @param ACacheDir - Cache directory path
  @return Array of version strings }
function BuildCacheListVersions(const ACacheDir: string): TStringArray;

{ Extract version from archive filename
  @param AFileName - Filename like "fpc-3.2.2-x86_64-linux.tar.gz"
  @return Version string like "3.2.2" or empty if invalid }
function BuildCacheExtractVersion(const AFileName: string): string;

implementation

function BuildCacheGetTotalSize(const ACacheDir: string): Int64;
var
  SR: TSearchRec;
  CacheDirWithDelim: string;
begin
  Result := 0;

  if not DirectoryExists(ACacheDir) then
    Exit;

  CacheDirWithDelim := IncludeTrailingPathDelimiter(ACacheDir);

  if FindFirst(CacheDirWithDelim + '*.tar.gz', faAnyFile, SR) = 0 then
  begin
    repeat
      Result := Result + SR.Size;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function BuildCacheExtractVersion(const AFileName: string): string;
var
  i, DashPos, LastDashPos: Integer;
begin
  Result := '';

  // Expected format: fpc-X.Y.Z-cpu-os.tar.gz or fpc-X.Y.Z-cpu-os-binary.tar.gz
  if Pos('fpc-', AFileName) <> 1 then
    Exit;

  // Find second dash (after version)
  DashPos := Pos('-', AFileName);
  if DashPos <= 0 then
    Exit;

  // Scan for the dash that separates version from platform
  // Version part: digits and dots (e.g. 3.2.2)
  // Platform part starts at first dash followed by non-digit
  LastDashPos := 0;
  for i := DashPos + 1 to Length(AFileName) do
  begin
    if AFileName[i] = '-' then
    begin
      // Check if next char is digit (still in version) or not (platform)
      if (i < Length(AFileName)) and (AFileName[i + 1] in ['0'..'9']) then
        Continue  // Part of version (e.g. version segments)
      else
      begin
        LastDashPos := i;
        Break;
      end;
    end;
  end;

  // Extract version: from after first dash to before platform dash
  if LastDashPos > DashPos then
    Result := Copy(AFileName, DashPos + 1, LastDashPos - DashPos - 1)
  else if Pos('.tar', AFileName) > DashPos then
    Result := Copy(AFileName, DashPos + 1, Pos('.tar', AFileName) - DashPos - 1)
  else
    Result := '';
end;

function BuildCacheListVersions(const ACacheDir: string): TStringArray;
var
  SR: TSearchRec;
  Version: string;
  List: TStringList;
  CacheDirWithDelim: string;
  i: Integer;
begin
  Result := nil;

  if not DirectoryExists(ACacheDir) then
    Exit;

  CacheDirWithDelim := IncludeTrailingPathDelimiter(ACacheDir);

  List := TStringList.Create;
  try
    List.Sorted := True;
    List.Duplicates := dupIgnore;

    if FindFirst(CacheDirWithDelim + 'fpc-*.tar.gz', faAnyFile, SR) = 0 then
    begin
      repeat
        Version := BuildCacheExtractVersion(SR.Name);
        if Version <> '' then
          List.Add(Version);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    // Convert to array
    SetLength(Result, List.Count);
    for i := 0 to List.Count - 1 do
      Result[i] := List[i];
  finally
    List.Free;
  end;
end;

end.
