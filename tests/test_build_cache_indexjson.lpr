program test_build_cache_indexjson;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, fpdev.build.cache.indexjson;

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

procedure TestBuildIndexEntryJSON;
var
  Entry: string;
  CreatedAt: TDateTime;
begin
  CreatedAt := EncodeDate(2026, 2, 1) + EncodeTime(10, 0, 0, 0);

  Entry := BuildCacheBuildIndexEntryJSON('3.2.2', 'x86_64', 'linux',
    '/cache/fpc.tar.gz', 5000, 'source', 'hash123', 'https://example.com',
    '/opt/fpc', 5, CreatedAt, 0);

  // Should be in format version=JSON
  Check(Pos('3.2.2=', Entry) = 1, 'BuildIndexEntry: Starts with version=');
  Check(Pos('"version"', Entry) > 0, 'BuildIndexEntry: Contains version in JSON');
  Check(Pos('"cpu"', Entry) > 0, 'BuildIndexEntry: Contains CPU in JSON');
  Check(Pos('"access_count"', Entry) > 0, 'BuildIndexEntry: Contains access count');
end;

procedure TestParseIndexEntryJSON;
var
  JSONObj: TJSONObject;
  JSONStr: string;
begin
  JSONStr := '{"version":"3.2.2","cpu":"x86_64","os":"linux"}';

  Check(BuildCacheParseIndexEntryJSON(JSONStr, JSONObj) = True,
        'ParseIndexEntry: Returns True for valid JSON');
  Check(JSONObj.Get('version', '') = '3.2.2', 'ParseIndexEntry: Version extracted');
  JSONObj.Free;
end;

procedure TestNormalizeIndexDate;
begin
  Check(BuildCacheNormalizeIndexDate('2026-02-01T10:00:00') = '2026-02-01 10:00:00',
        'NormalizeDate: Replaces T with space');
  Check(BuildCacheNormalizeIndexDate('2026-02-01 10:00:00') = '2026-02-01 10:00:00',
        'NormalizeDate: Already normalized unchanged');
  Check(BuildCacheNormalizeIndexDate('') = '',
        'NormalizeDate: Empty returns empty');
end;

procedure TestGetIndexEntryJSON;
var
  Entries: TStringList;
begin
  Entries := TStringList.Create;
  try
    Entries.Add('3.2.2={"version":"3.2.2"}');
    Entries.Add('3.0.4={"version":"3.0.4"}');

    Check(Pos('3.2.2', BuildCacheGetIndexEntryJSON(Entries, '3.2.2')) > 0,
          'GetIndexEntry: Finds 3.2.2');
    Check(Pos('3.0.4', BuildCacheGetIndexEntryJSON(Entries, '3.0.4')) > 0,
          'GetIndexEntry: Finds 3.0.4');
    Check(BuildCacheGetIndexEntryJSON(Entries, '4.0.0') = '',
          'GetIndexEntry: Missing version returns empty');
  finally
    Entries.Free;
  end;

  // Nil entries
  Check(BuildCacheGetIndexEntryJSON(nil, '3.2.2') = '',
        'GetIndexEntry: Nil entries returns empty');
end;

procedure TestGetNormalizedIndexDates;
var
  JSONObj: TJSONObject;
  CreatedAt, LastAccessed: string;
begin
  JSONObj := TJSONObject.Create;
  try
    JSONObj.Add('created_at', '2026-02-01T10:00:00');
    JSONObj.Add('last_accessed', '2026-02-09T14:30:00');

    BuildCacheGetNormalizedIndexDates(JSONObj, CreatedAt, LastAccessed);
    Check(CreatedAt = '2026-02-01 10:00:00', 'NormalizedDates: CreatedAt normalized');
    Check(LastAccessed = '2026-02-09 14:30:00', 'NormalizedDates: LastAccessed normalized');
  finally
    JSONObj.Free;
  end;

  // Nil object
  BuildCacheGetNormalizedIndexDates(nil, CreatedAt, LastAccessed);
  Check(CreatedAt = '', 'NormalizedDates: Nil object returns empty CreatedAt');
  Check(LastAccessed = '', 'NormalizedDates: Nil object returns empty LastAccessed');
end;

begin
  WriteLn('=== Build Cache IndexJSON Unit Tests ===');
  WriteLn;

  TestBuildIndexEntryJSON;
  TestParseIndexEntryJSON;
  TestNormalizeIndexDate;
  TestGetIndexEntryJSON;
  TestGetNormalizedIndexDates;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
