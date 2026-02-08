unit fpdev.build.cache.rebuildscan;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BuildCacheExtractVersionFromMetadataFilename(const AFileName: string): string;
function BuildCacheListMetadataVersions(const ACacheDirWithDelim: string): SysUtils.TStringArray;

implementation

function BuildCacheExtractVersionFromMetadataFilename(const AFileName: string): string;
var
  DashPos: Integer;
  Version: string;
begin
  Result := '';

  if Pos('fpc-', AFileName) <> 1 then
    Exit;

  Version := Copy(AFileName, 5, Length(AFileName) - 9);
  DashPos := Pos('-', Version);
  if DashPos > 0 then
    Version := Copy(Version, 1, DashPos - 1);

  Result := Version;
end;

function BuildCacheListMetadataVersions(const ACacheDirWithDelim: string): SysUtils.TStringArray;
var
  SR: TSearchRec;
  Count: Integer;
  Version: string;
begin
  Result := nil;
  Count := 0;

  if FindFirst(ACacheDirWithDelim + 'fpc-*.json', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        Version := BuildCacheExtractVersionFromMetadataFilename(SR.Name);
        if Version <> '' then
        begin
          SetLength(Result, Count + 1);
          Result[Count] := Version;
          Inc(Count);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

end.
