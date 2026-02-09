program test_build_cache_statsreport;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.build.cache.statsreport;

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

procedure TestFormatSize;
begin
  Check(BuildCacheFormatSize(500) = '500 bytes', 'FormatSize: 500 bytes');
  Check(BuildCacheFormatSize(0) = '0 bytes', 'FormatSize: 0 bytes');

  // MB range
  Check(Pos('MB', BuildCacheFormatSize(5 * 1024 * 1024)) > 0,
        'FormatSize: 5 MB shows MB');
  Check(Pos('5.00 MB', BuildCacheFormatSize(5 * 1024 * 1024)) > 0,
        'FormatSize: 5 MB value correct');

  // GB range
  Check(Pos('GB', BuildCacheFormatSize(Int64(2) * 1024 * 1024 * 1024)) > 0,
        'FormatSize: 2 GB shows GB');
  Check(Pos('2.00 GB', BuildCacheFormatSize(Int64(2) * 1024 * 1024 * 1024)) > 0,
        'FormatSize: 2 GB value correct');

  // Boundary: just under 1 MB
  Check(Pos('bytes', BuildCacheFormatSize(1024 * 1024 - 1)) > 0,
        'FormatSize: Just under 1 MB shows bytes');
end;

procedure TestFormatStatsReport;
var
  Report: string;
begin
  Report := BuildCacheFormatStatsReport(5, 10 * 1024 * 1024, 42,
    '3.2.2', 20, '3.0.4', 2);

  Check(Pos('Total entries: 5', Report) > 0, 'StatsReport: Contains total entries');
  Check(Pos('10.00 MB', Report) > 0, 'StatsReport: Contains formatted size');
  Check(Pos('Total accesses: 42', Report) > 0, 'StatsReport: Contains total accesses');
  Check(Pos('3.2.2', Report) > 0, 'StatsReport: Contains most accessed version');
  Check(Pos('20 accesses', Report) > 0, 'StatsReport: Contains most accessed count');
  Check(Pos('3.0.4', Report) > 0, 'StatsReport: Contains least accessed version');
  Check(Pos('2 accesses', Report) > 0, 'StatsReport: Contains least accessed count');
  Check(Pos('Cache Statistics Report', Report) > 0, 'StatsReport: Contains header');
end;

procedure TestFormatStatsReportEmpty;
var
  Report: string;
begin
  Report := BuildCacheFormatStatsReport(0, 0, 0, '', 0, '', 0);
  Check(Pos('Total entries: 0', Report) > 0, 'StatsReportEmpty: Zero entries');
  Check(Pos('0 bytes', Report) > 0, 'StatsReportEmpty: Zero size');
end;

begin
  WriteLn('=== Build Cache StatsReport Unit Tests ===');
  WriteLn;

  TestFormatSize;
  TestFormatStatsReport;
  TestFormatStatsReportEmpty;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
