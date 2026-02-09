program test_build_cache_indexio;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, fpdev.build.cache.indexio;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TempDir: string;

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

procedure TestSaveLoadIndexEntries;
var
  IndexPath: string;
  SaveEntries, LoadEntries: TStringList;
  JSONObj: TJSONObject;
begin
  IndexPath := TempDir + 'cache-index.json';

  SaveEntries := TStringList.Create;
  LoadEntries := TStringList.Create;
  try
    // Build entries in version=JSON format
    JSONObj := TJSONObject.Create;
    try
      JSONObj.Add('version', '3.2.2');
      JSONObj.Add('cpu', 'x86_64');
      JSONObj.Add('archive_size', Int64(1000));
      SaveEntries.Add('3.2.2=' + JSONObj.AsJSON);
    finally
      JSONObj.Free;
    end;

    JSONObj := TJSONObject.Create;
    try
      JSONObj.Add('version', '3.0.4');
      JSONObj.Add('cpu', 'i386');
      JSONObj.Add('archive_size', Int64(2000));
      SaveEntries.Add('3.0.4=' + JSONObj.AsJSON);
    finally
      JSONObj.Free;
    end;

    // Save
    BuildCacheSaveIndexEntries(IndexPath, SaveEntries);
    Check(FileExists(IndexPath), 'SaveIndexEntries: File created');

    // Load
    BuildCacheLoadIndexEntries(IndexPath, LoadEntries);
    Check(LoadEntries.Count = 2, 'LoadIndexEntries: Loaded 2 entries');

    // Verify content
    Check(LoadEntries.Values['3.2.2'] <> '', 'LoadIndexEntries: Has 3.2.2 entry');
    Check(LoadEntries.Values['3.0.4'] <> '', 'LoadIndexEntries: Has 3.0.4 entry');
  finally
    SaveEntries.Free;
    LoadEntries.Free;
    if FileExists(IndexPath) then
      DeleteFile(IndexPath);
  end;
end;

procedure TestLoadNonExistent;
var
  Entries: TStringList;
begin
  Entries := TStringList.Create;
  try
    BuildCacheLoadIndexEntries('/nonexistent/index.json', Entries);
    Check(Entries.Count = 0, 'LoadIndexEntries: Non-existent returns empty');
  finally
    Entries.Free;
  end;
end;

procedure TestLoadNilEntries;
begin
  // Should not crash
  BuildCacheLoadIndexEntries('/nonexistent/index.json', nil);
  Check(True, 'LoadIndexEntries: Nil entries does not crash');
end;

procedure TestSaveNilEntries;
begin
  // Should not crash
  BuildCacheSaveIndexEntries(TempDir + 'nil.json', nil);
  Check(not FileExists(TempDir + 'nil.json'), 'SaveIndexEntries: Nil entries creates no file');
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
             'test_indexio_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(TempDir);

  WriteLn('=== Build Cache IndexIO Unit Tests ===');
  WriteLn;

  TestSaveLoadIndexEntries;
  TestLoadNonExistent;
  TestLoadNilEntries;
  TestSaveNilEntries;

  RemoveDir(TempDir);

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
