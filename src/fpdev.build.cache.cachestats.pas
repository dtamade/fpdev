unit fpdev.build.cache.cachestats;

{$mode objfpc}{$H+}

interface

function BuildCacheFormatCacheStats(AEntryCount, ACacheHits,
  ACacheMisses: Integer): string;

implementation

uses
  SysUtils;

function BuildCacheFormatCacheStats(AEntryCount, ACacheHits,
  ACacheMisses: Integer): string;
var
  Total: Integer;
  HitRate: Double;
begin
  Total := ACacheHits + ACacheMisses;
  if Total > 0 then
    HitRate := (ACacheHits * 100.0) / Total
  else
    HitRate := 0;

  Result := Format('Cache: %d entries, %d hits, %d misses (%.1f%% hit rate)',
    [AEntryCount, ACacheHits, ACacheMisses, HitRate]);
end;

end.
