unit fpdev.build.cache.expiredscan;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.build.cache.types;

type
  TBuildCacheExpiredInfoLoader = function(const AVersion: string; out AInfo: TArtifactInfo): Boolean of object;
  TBuildCacheExpiredChecker = function(const AInfo: TArtifactInfo): Boolean of object;

function BuildCacheCollectExpiredVersions(const ACacheDirWithDelim: string;
  AInfoLoader: TBuildCacheExpiredInfoLoader;
  AExpiredChecker: TBuildCacheExpiredChecker): SysUtils.TStringArray;

implementation

uses
  fpdev.build.cache.ttl;

function BuildCacheCollectExpiredVersions(const ACacheDirWithDelim: string;
  AInfoLoader: TBuildCacheExpiredInfoLoader;
  AExpiredChecker: TBuildCacheExpiredChecker): SysUtils.TStringArray;
var
  SR: TSearchRec;
  Info: TArtifactInfo;
  Version: string;
  Count: Integer;
begin
  Result := nil;
  Count := 0;

  if not DirectoryExists(ExcludeTrailingPathDelimiter(ACacheDirWithDelim)) then
    Exit;

  if FindFirst(ACacheDirWithDelim + '*.meta', faAnyFile, SR) = 0 then
  begin
    repeat
      Version := BuildCacheExtractVersionFromFilename(SR.Name);
      if Version <> '' then
        if Assigned(AInfoLoader) and AInfoLoader(Version, Info) then
          if Assigned(AExpiredChecker) and AExpiredChecker(Info) then
          begin
            SetLength(Result, Count + 1);
            Result[Count] := Version;
            Inc(Count);
          end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

end.
