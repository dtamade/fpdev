unit fpdev.build.cache.rebuildscan;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.build.cache.types;

type
  TBuildCacheRebuildInfoLoader = function(const AVersion: string; out AInfo: TArtifactInfo): Boolean of object;
  TBuildCacheRebuildInfoArray = array of TArtifactInfo;

function BuildCacheExtractVersionFromMetadataFilename(const AFileName: string): string;
function BuildCacheListMetadataVersions(const ACacheDirWithDelim: string): SysUtils.TStringArray;
function BuildCacheCollectRebuildInfos(const AVersions: array of string;
  AInfoLoader: TBuildCacheRebuildInfoLoader): TBuildCacheRebuildInfoArray;

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

function BuildCacheCollectRebuildInfos(const AVersions: array of string;
  AInfoLoader: TBuildCacheRebuildInfoLoader): TBuildCacheRebuildInfoArray;
var
  Count: Integer;
  Index: Integer;
  Info: TArtifactInfo;
begin
  Result := nil;
  if not Assigned(AInfoLoader) then
    Exit;

  Count := 0;
  SetLength(Result, Length(AVersions));
  for Index := 0 to High(AVersions) do
    if AInfoLoader(AVersions[Index], Info) then
    begin
      Result[Count] := Info;
      Inc(Count);
    end;

  SetLength(Result, Count);
end;

end.
