program test_build_cache_indexstats;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, fpdev.build.cache.indexstats;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure TestInit;
var
  TotalSize: Int64;
  OldestDate, NewestDate: TDateTime;
  OldestVersion, NewestVersion: string;
begin
  BuildCacheIndexStatsInit(TotalSize, OldestDate, NewestDate, OldestVersion, NewestVersion);
  Check(TotalSize = 0, 'Init: TotalSize = 0');
  Check(OldestDate = MaxDateTime, 'Init: OldestDate = MaxDateTime');
  Check(NewestDate = 0, 'Init: NewestDate = 0');
  Check(OldestVersion = '', 'Init: OldestVersion empty');
  Check(NewestVersion = '', 'Init: NewestVersion empty');
end;

procedure TestAccumulate;
var
  TotalSize: Int64;
  OldestDate, NewestDate: TDateTime;
  OldestVersion, NewestVersion: string;
  Date1, Date2, Date3: TDateTime;
begin
  BuildCacheIndexStatsInit(TotalSize, OldestDate, NewestDate, OldestVersion, NewestVersion);

  Date1 := EncodeDate(2026, 1, 1);
  Date2 := EncodeDate(2026, 1, 15);
  Date3 := EncodeDate(2026, 2, 1);

  BuildCacheIndexStatsAccumulate('3.2.0', 1000, Date2,
    TotalSize, OldestDate, NewestDate, OldestVersion, NewestVersion);
  Check(TotalSize = 1000, 'Accumulate1: TotalSize = 1000');
  Check(OldestVersion = '3.2.0', 'Accumulate1: OldestVersion = 3.2.0');
  Check(NewestVersion = '3.2.0', 'Accumulate1: NewestVersion = 3.2.0');

  BuildCacheIndexStatsAccumulate('3.2.2', 2000, Date3,
    TotalSize, OldestDate, NewestDate, OldestVersion, NewestVersion);
  Check(TotalSize = 3000, 'Accumulate2: TotalSize = 3000');
  Check(NewestVersion = '3.2.2', 'Accumulate2: NewestVersion = 3.2.2');

  BuildCacheIndexStatsAccumulate('3.0.4', 500, Date1,
    TotalSize, OldestDate, NewestDate, OldestVersion, NewestVersion);
  Check(TotalSize = 3500, 'Accumulate3: TotalSize = 3500');
  Check(OldestVersion = '3.0.4', 'Accumulate3: OldestVersion = 3.0.4');
  Check(NewestVersion = '3.2.2', 'Accumulate3: NewestVersion still 3.2.2');
end;

procedure TestFinalize;
var
  OldestDate, NewestDate: TDateTime;
begin
  // Test with entries
  OldestDate := EncodeDate(2026, 1, 1);
  NewestDate := EncodeDate(2026, 2, 1);
  BuildCacheIndexStatsFinalize(2, OldestDate, NewestDate);
  Check(OldestDate > 0, 'Finalize: Dates preserved with entries');

  // Test with no entries
  OldestDate := MaxDateTime;
  NewestDate := 0;
  BuildCacheIndexStatsFinalize(0, OldestDate, NewestDate);
  Check(OldestDate = 0, 'Finalize: OldestDate reset to 0 with no entries');
  Check(NewestDate = 0, 'Finalize: NewestDate reset to 0 with no entries');
end;

begin
  WriteLn('=== Build Cache IndexStats Unit Tests ===');
  WriteLn;

  TestInit;
  TestAccumulate;
  TestFinalize;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
