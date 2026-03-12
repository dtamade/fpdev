unit fpdev.build.cache.detailedstats;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

function BuildCacheGetDetailedStatsCore(const AInfos: array of TArtifactInfo): TCacheDetailedStats;

implementation

function BuildCacheGetDetailedStatsCore(const AInfos: array of TArtifactInfo): TCacheDetailedStats;
var
  Index: Integer;
begin
  Initialize(Result);
  Result.TotalEntries := Length(AInfos);
  Result.TotalSize := 0;
  Result.TotalAccesses := 0;
  Result.MostAccessedCount := -1;
  Result.LeastAccessedCount := MaxInt;

  for Index := Low(AInfos) to High(AInfos) do
  begin
    Result.TotalSize := Result.TotalSize + AInfos[Index].ArchiveSize;
    Result.TotalAccesses := Result.TotalAccesses + AInfos[Index].AccessCount;

    if AInfos[Index].AccessCount > Result.MostAccessedCount then
    begin
      Result.MostAccessedCount := AInfos[Index].AccessCount;
      Result.MostAccessedVersion := AInfos[Index].Version;
    end;

    if AInfos[Index].AccessCount < Result.LeastAccessedCount then
    begin
      Result.LeastAccessedCount := AInfos[Index].AccessCount;
      Result.LeastAccessedVersion := AInfos[Index].Version;
    end;
  end;

  if Result.TotalEntries > 0 then
    Result.AverageEntrySize := Result.TotalSize div Result.TotalEntries
  else
    Result.AverageEntrySize := 0;

  if Result.TotalEntries = 0 then
  begin
    Result.MostAccessedCount := 0;
    Result.LeastAccessedCount := 0;
  end;
end;

end.
