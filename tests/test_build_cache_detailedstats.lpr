program test_build_cache_detailedstats;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.detailedstats;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure TestDetailedStatsAggregation;
var
  Infos: array of TArtifactInfo;
  Stats: TCacheDetailedStats;
begin
  SetLength(Infos, 3);
  Infos[0].Version := '3.2.0';
  Infos[0].ArchiveSize := 10000000;
  Infos[0].AccessCount := 1;

  Infos[1].Version := '3.2.1';
  Infos[1].ArchiveSize := 20000000;
  Infos[1].AccessCount := 3;

  Infos[2].Version := '3.2.2';
  Infos[2].ArchiveSize := 30000000;
  Infos[2].AccessCount := 2;

  Stats := BuildCacheGetDetailedStatsCore(Infos);
  AssertTrue(Stats.TotalEntries = 3, 'total entries aggregate correctly');
  AssertTrue(Stats.TotalSize = 60000000, 'total size aggregates correctly');
  AssertTrue(Stats.TotalAccesses = 6, 'total accesses aggregate correctly');
  AssertTrue(Stats.MostAccessedVersion = '3.2.1', 'most accessed version is selected');
  AssertTrue(Stats.MostAccessedCount = 3, 'most accessed count is selected');
  AssertTrue(Stats.LeastAccessedVersion = '3.2.0', 'least accessed version is selected');
  AssertTrue(Stats.LeastAccessedCount = 1, 'least accessed count is selected');
  AssertTrue(Stats.AverageEntrySize = 20000000, 'average entry size is computed');
end;

procedure TestDetailedStatsEmptyInput;
var
  Infos: array of TArtifactInfo;
  Stats: TCacheDetailedStats;
begin
  SetLength(Infos, 0);
  Stats := BuildCacheGetDetailedStatsCore(Infos);
  AssertTrue(Stats.TotalEntries = 0, 'empty input has zero entries');
  AssertTrue(Stats.TotalAccesses = 0, 'empty input has zero accesses');
  AssertTrue(Stats.MostAccessedCount = 0, 'empty input resets most accessed count');
  AssertTrue(Stats.LeastAccessedCount = 0, 'empty input resets least accessed count');
end;

begin
  TestDetailedStatsAggregation;
  TestDetailedStatsEmptyInput;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
