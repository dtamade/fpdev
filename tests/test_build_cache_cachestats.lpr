program test_build_cache_cachestats;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.cachestats;

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

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure TestFormatsZeroHitRate;
begin
  AssertEquals('Cache: 5 entries, 0 hits, 0 misses (0.0% hit rate)',
    BuildCacheFormatCacheStats(5, 0, 0),
    'zero total requests yields 0.0 hit rate');
end;

procedure TestFormatsComputedHitRate;
begin
  AssertEquals('Cache: 7 entries, 3 hits, 1 misses (75.0% hit rate)',
    BuildCacheFormatCacheStats(7, 3, 1),
    'non-zero hit rate is formatted as percentage');
end;

begin
  TestFormatsZeroHitRate;
  TestFormatsComputedHitRate;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
