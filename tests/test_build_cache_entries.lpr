program test_build_cache_entries;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.build.cache.entries;

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

procedure TestGetCacheFilePath;
begin
  Check(BuildCacheGetCacheFilePath('/tmp/cache/') = '/tmp/cache/build-cache.txt',
        'GetCacheFilePath: Appends build-cache.txt');
  Check(BuildCacheGetCacheFilePath('') = 'build-cache.txt',
        'GetCacheFilePath: Empty dir produces just filename');
end;

procedure TestGetEntryCount;
var
  List: TStringList;
begin
  // Nil list
  Check(BuildCacheGetEntryCount(nil) = 0, 'GetEntryCount: Nil list returns 0');

  // Empty list
  List := TStringList.Create;
  try
    Check(BuildCacheGetEntryCount(List) = 0, 'GetEntryCount: Empty list returns 0');

    List.Add('entry1');
    Check(BuildCacheGetEntryCount(List) = 1, 'GetEntryCount: Single entry returns 1');

    List.Add('entry2');
    List.Add('entry3');
    Check(BuildCacheGetEntryCount(List) = 3, 'GetEntryCount: Three entries returns 3');
  finally
    List.Free;
  end;
end;

procedure TestFindEntry;
var
  List: TStringList;
begin
  // Nil list
  Check(BuildCacheFindEntry(nil, '3.2.2') = -1, 'FindEntry: Nil list returns -1');

  List := TStringList.Create;
  try
    // Empty list
    Check(BuildCacheFindEntry(List, '3.2.2') = -1, 'FindEntry: Empty list returns -1');

    // Add entries
    List.Add('version=3.2.0;revision=abc123;status=9');
    List.Add('version=3.2.2;revision=def456;status=5');
    List.Add('version=main;revision=ghi789;status=2');

    Check(BuildCacheFindEntry(List, '3.2.2') = 1, 'FindEntry: Finds 3.2.2 at index 1');
    Check(BuildCacheFindEntry(List, '3.2.0') = 0, 'FindEntry: Finds 3.2.0 at index 0');
    Check(BuildCacheFindEntry(List, 'main') = 2, 'FindEntry: Finds main at index 2');
    Check(BuildCacheFindEntry(List, '4.0.0') = -1, 'FindEntry: Missing version returns -1');

    // Partial match should not match
    Check(BuildCacheFindEntry(List, '3.2') = -1,
          'FindEntry: Partial version does not match');
  finally
    List.Free;
  end;
end;

begin
  WriteLn('=== Build Cache Entries Unit Tests ===');
  WriteLn;

  TestGetCacheFilePath;
  TestGetEntryCount;
  TestFindEntry;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
