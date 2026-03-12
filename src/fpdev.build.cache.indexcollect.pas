unit fpdev.build.cache.indexcollect;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  fpdev.build.cache.types;

type
  TBuildCacheIndexInfoLookup = function(const AVersion: string; out AInfo: TArtifactInfo): Boolean of object;
  TBuildCacheIndexInfoArray = array of TArtifactInfo;

function BuildCacheCollectIndexInfos(const AIndexEntries: TStringList;
  AInfoLookup: TBuildCacheIndexInfoLookup): TBuildCacheIndexInfoArray;

implementation

function BuildCacheCollectIndexInfos(const AIndexEntries: TStringList;
  AInfoLookup: TBuildCacheIndexInfoLookup): TBuildCacheIndexInfoArray;
var
  Count: Integer;
  Index: Integer;
  Info: TArtifactInfo;
begin
  Result := nil;
  if not Assigned(AIndexEntries) then
    Exit;

  Count := 0;
  SetLength(Result, AIndexEntries.Count);
  for Index := 0 to AIndexEntries.Count - 1 do
    if Assigned(AInfoLookup) and AInfoLookup(AIndexEntries.Names[Index], Info) then
    begin
      Result[Count] := Info;
      Inc(Count);
    end;

  SetLength(Result, Count);
end;

end.
