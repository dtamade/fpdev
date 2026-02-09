program test_build_cache_fileops;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, fpdev.build.cache.fileops;

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

procedure TestParseDateTimeString;
var
  DT: TDateTime;
  Y, M, D, H, Mi, S, MS: Word;
begin
  // Valid datetime
  DT := BuildCacheParseDateTimeString('2026-01-16 05:40:00');
  DecodeDateTime(DT, Y, M, D, H, Mi, S, MS);
  Check(Y = 2026, 'ParseDateTime: Year = 2026');
  Check(M = 1, 'ParseDateTime: Month = 1');
  Check(D = 16, 'ParseDateTime: Day = 16');
  Check(H = 5, 'ParseDateTime: Hour = 5');
  Check(Mi = 40, 'ParseDateTime: Minute = 40');
  Check(S = 0, 'ParseDateTime: Second = 0');

  // Invalid/short string
  DT := BuildCacheParseDateTimeString('short');
  Check(DT = 0, 'ParseDateTime: Short string returns 0');

  // Empty string
  DT := BuildCacheParseDateTimeString('');
  Check(DT = 0, 'ParseDateTime: Empty string returns 0');

  // Another valid datetime
  DT := BuildCacheParseDateTimeString('2025-12-31 23:59:59');
  DecodeDateTime(DT, Y, M, D, H, Mi, S, MS);
  Check((Y = 2025) and (M = 12) and (D = 31), 'ParseDateTime: 2025-12-31 parsed correctly');
  Check((H = 23) and (Mi = 59) and (S = 59), 'ParseDateTime: 23:59:59 parsed correctly');
end;

procedure TestFormatDateTimeString;
var
  DT: TDateTime;
  Formatted: string;
begin
  DT := EncodeDate(2026, 2, 9) + EncodeTime(14, 30, 45, 0);
  Formatted := BuildCacheFormatDateTimeString(DT);
  Check(Formatted = '2026-02-09 14:30:45', 'FormatDateTime: Correct format');
end;

procedure TestRoundTrip;
var
  Original, Parsed: TDateTime;
  Formatted: string;
begin
  Original := EncodeDate(2026, 6, 15) + EncodeTime(8, 0, 0, 0);
  Formatted := BuildCacheFormatDateTimeString(Original);
  Parsed := BuildCacheParseDateTimeString(Formatted);
  Check(Abs(Original - Parsed) < (1 / 86400),
        'RoundTrip: Format then parse preserves value');
end;

procedure TestFileCopy;
var
  SrcPath, DstPath: string;
  F: TextFile;
  Content: string;
begin
  SrcPath := TempDir + 'source.txt';
  DstPath := TempDir + 'dest.txt';

  // Create source file
  AssignFile(F, SrcPath);
  Rewrite(F);
  Write(F, 'test content 12345');
  CloseFile(F);

  // Copy
  Check(BuildCacheFileCopy(SrcPath, DstPath) = True, 'FileCopy: Returns True on success');
  Check(FileExists(DstPath), 'FileCopy: Destination file exists');

  // Verify content
  AssignFile(F, DstPath);
  Reset(F);
  ReadLn(F, Content);
  CloseFile(F);
  Check(Content = 'test content 12345', 'FileCopy: Content matches');

  // Cleanup
  DeleteFile(SrcPath);
  DeleteFile(DstPath);
end;

procedure TestFileCopyNonExistent;
begin
  Check(BuildCacheFileCopy('/nonexistent/source.txt', TempDir + 'dest.txt') = False,
        'FileCopy: Returns False for non-existent source');
end;

procedure TestRunCommand;
begin
  // Run a simple command that should succeed
  Check(BuildCacheRunCommand('true', [], '') = True,
        'RunCommand: "true" command returns True');

  // Run a command that should fail
  Check(BuildCacheRunCommand('false', [], '') = False,
        'RunCommand: "false" command returns False');
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
             'test_fileops_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(TempDir);

  WriteLn('=== Build Cache FileOps Unit Tests ===');
  WriteLn;

  TestParseDateTimeString;
  TestFormatDateTimeString;
  TestRoundTrip;
  TestFileCopy;
  TestFileCopyNonExistent;
  TestRunCommand;

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
