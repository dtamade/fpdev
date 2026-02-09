program test_build_cache_entryio;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.build.cache.entryio;

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

procedure TestFormatEntryLine;
var
  Line: string;
  DT: TDateTime;
begin
  DT := EncodeDate(2026, 2, 1) + EncodeTime(10, 30, 0, 0);
  Line := BuildCacheFormatEntryLine('3.2.2', 'abc123', DT, 'x86_64', 'linux', 9);

  Check(Pos('version=3.2.2', Line) > 0, 'FormatEntryLine: Contains version');
  Check(Pos('revision=abc123', Line) > 0, 'FormatEntryLine: Contains revision');
  Check(Pos('cpu=x86_64', Line) > 0, 'FormatEntryLine: Contains CPU');
  Check(Pos('os=linux', Line) > 0, 'FormatEntryLine: Contains OS');
  Check(Pos('status=9', Line) > 0, 'FormatEntryLine: Contains status');
  Check(Pos('time=2026-02-01_10:30:00', Line) > 0, 'FormatEntryLine: Contains formatted time');
end;

procedure TestParseRevision;
begin
  Check(BuildCacheParseRevision('version=3.2.2;revision=abc123;status=9') = 'abc123',
        'ParseRevision: Extracts revision from middle');
  Check(BuildCacheParseRevision('version=3.2.2;revision=def;status=5') = 'def',
        'ParseRevision: Extracts short revision');
  Check(BuildCacheParseRevision('version=3.2.2;status=5') = '',
        'ParseRevision: Returns empty if no revision field');
  Check(BuildCacheParseRevision('') = '',
        'ParseRevision: Returns empty for empty string');
end;

procedure TestParseStatus;
begin
  Check(BuildCacheParseStatus('version=3.2.2;status=9') = 9,
        'ParseStatus: Parses status 9');
  Check(BuildCacheParseStatus('version=3.2.2;status=0') = 0,
        'ParseStatus: Parses status 0');
  Check(BuildCacheParseStatus('version=3.2.2;status=5') = 5,
        'ParseStatus: Parses status 5');
  Check(BuildCacheParseStatus('version=3.2.2') = -1,
        'ParseStatus: Returns -1 if no status field');
  Check(BuildCacheParseStatus('') = -1,
        'ParseStatus: Returns -1 for empty string');
end;

procedure TestLoadSaveEntriesFile;
var
  FilePath: string;
  Entries, Loaded: TStringList;
begin
  FilePath := TempDir + 'test_entries.txt';

  Entries := TStringList.Create;
  Loaded := TStringList.Create;
  try
    Entries.Add('version=3.2.2;revision=abc;status=9');
    Entries.Add('version=3.2.0;revision=def;status=5');

    // Save
    BuildCacheSaveEntriesFile(FilePath, TempDir, Entries);
    Check(FileExists(FilePath), 'SaveEntriesFile: File created');

    // Load
    Check(BuildCacheLoadEntriesFile(FilePath, Loaded) = True,
          'LoadEntriesFile: Returns True for existing file');
    Check(Loaded.Count = 2, 'LoadEntriesFile: Loads 2 entries');
    Check(Pos('version=3.2.2', Loaded[0]) > 0, 'LoadEntriesFile: First entry correct');
    Check(Pos('version=3.2.0', Loaded[1]) > 0, 'LoadEntriesFile: Second entry correct');
  finally
    Entries.Free;
    Loaded.Free;
    if FileExists(FilePath) then
      DeleteFile(FilePath);
  end;
end;

procedure TestLoadNonExistentFile;
var
  Loaded: TStringList;
begin
  Loaded := TStringList.Create;
  try
    Check(BuildCacheLoadEntriesFile('/nonexistent/file.txt', Loaded) = False,
          'LoadEntriesFile: Returns False for non-existent file');
    Check(Loaded.Count = 0, 'LoadEntriesFile: No entries loaded');
  finally
    Loaded.Free;
  end;
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
             'test_entryio_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(TempDir);

  WriteLn('=== Build Cache EntryIO Unit Tests ===');
  WriteLn;

  TestFormatEntryLine;
  TestParseRevision;
  TestParseStatus;
  TestLoadSaveEntriesFile;
  TestLoadNonExistentFile;

  // Cleanup
  RemoveDir(TempDir);

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
