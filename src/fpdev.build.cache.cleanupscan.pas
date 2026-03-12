unit fpdev.build.cache.cleanupscan;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.build.cache.types;

type
  TBuildCacheArtifactInfoLoader = function(const AVersion: string; out AInfo: TArtifactInfo): Boolean of object;
  TBuildCacheArtifactInfoArray = array of TArtifactInfo;

function BuildCacheCollectCleanupEntries(const ACacheDirWithDelim: string;
  AInfoLoader: TBuildCacheArtifactInfoLoader): TBuildCacheArtifactInfoArray;

implementation

uses
  fpdev.build.cache.scan;

function BuildCacheCollectCleanupEntries(const ACacheDirWithDelim: string;
  AInfoLoader: TBuildCacheArtifactInfoLoader): TBuildCacheArtifactInfoArray;
var
  SR: TSearchRec;
  Count: Integer;
  Version: string;
  TempInfo: TArtifactInfo;
begin
  Result := nil;
  Count := 0;

  if FindFirst(ACacheDirWithDelim + '*.tar.gz', faAnyFile, SR) = 0 then
  begin
    repeat
      SetLength(Result, Count + 1);
      Initialize(Result[Count]);
      Result[Count].ArchivePath := ACacheDirWithDelim + SR.Name;
      Result[Count].ArchiveSize := SR.Size;

      Version := BuildCacheExtractVersion(SR.Name);
      if Version <> '' then
      begin
        Result[Count].Version := Version;
        if Assigned(AInfoLoader) and AInfoLoader(Version, TempInfo) then
          Result[Count].CreatedAt := TempInfo.CreatedAt
        else
          Result[Count].CreatedAt := SR.TimeStamp;
      end
      else
        Result[Count].CreatedAt := SR.TimeStamp;

      Inc(Count);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

end.
