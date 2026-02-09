program test_build_cache_metajson;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, fpdev.build.cache.metajson;

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

procedure TestMetaJSONFormatDateTime;
var
  DT: TDateTime;
  Formatted: string;
begin
  DT := EncodeDate(2026, 2, 9) + EncodeTime(14, 30, 45, 0);
  Formatted := MetaJSONFormatDateTime(DT);
  Check(Formatted = '2026-02-09T14:30:45', 'FormatDateTime: ISO 8601 format');
end;

procedure TestMetaJSONParseDateTime;
var
  DT: TDateTime;
  Y, M, D, H, Mi, S, MS: Word;
begin
  // With T separator
  DT := MetaJSONParseDateTime('2026-02-09T14:30:45');
  DecodeDateTime(DT, Y, M, D, H, Mi, S, MS);
  Check((Y = 2026) and (M = 2) and (D = 9), 'ParseDateTime: Date part correct (T separator)');
  Check((H = 14) and (Mi = 30) and (S = 45), 'ParseDateTime: Time part correct (T separator)');

  // With space separator
  DT := MetaJSONParseDateTime('2026-01-15 08:00:00');
  DecodeDateTime(DT, Y, M, D, H, Mi, S, MS);
  Check((Y = 2026) and (M = 1) and (D = 15), 'ParseDateTime: Date part correct (space separator)');

  // Empty
  Check(MetaJSONParseDateTime('') = 0, 'ParseDateTime: Empty returns 0');

  // Short
  Check(MetaJSONParseDateTime('short') = 0, 'ParseDateTime: Short string returns 0');
end;

procedure TestSaveLoadMetadataJSON;
var
  MetaPath: string;
  Info: TMetaJSONArtifactInfo;
  CreatedAt: TDateTime;
begin
  MetaPath := TempDir + 'test.json';
  CreatedAt := EncodeDate(2026, 2, 1) + EncodeTime(10, 0, 0, 0);

  BuildCacheSaveMetadataJSON(MetaPath, '3.2.2', 'x86_64', 'linux',
    '/cache/fpc-3.2.2.tar.gz', 5000000, CreatedAt,
    'source', 'sha256hash', 'https://example.com', '/opt/fpc', 3, CreatedAt);

  Check(FileExists(MetaPath), 'SaveMetadataJSON: File created');

  Check(BuildCacheLoadMetadataJSON(MetaPath, Info) = True, 'LoadMetadataJSON: Returns True');
  Check(Info.Version = '3.2.2', 'LoadMetadataJSON: Version correct');
  Check(Info.CPU = 'x86_64', 'LoadMetadataJSON: CPU correct');
  Check(Info.OS = 'linux', 'LoadMetadataJSON: OS correct');
  Check(Info.ArchiveSize = 5000000, 'LoadMetadataJSON: ArchiveSize correct');
  Check(Info.SourceType = 'source', 'LoadMetadataJSON: SourceType correct');
  Check(Info.SHA256 = 'sha256hash', 'LoadMetadataJSON: SHA256 correct');
  Check(Info.DownloadURL = 'https://example.com', 'LoadMetadataJSON: DownloadURL correct');
  Check(Info.SourcePath = '/opt/fpc', 'LoadMetadataJSON: SourcePath correct');
  Check(Info.AccessCount = 3, 'LoadMetadataJSON: AccessCount correct');

  DeleteFile(MetaPath);
end;

procedure TestLoadMetadataJSONNonExistent;
var
  Info: TMetaJSONArtifactInfo;
begin
  Check(BuildCacheLoadMetadataJSON('/nonexistent/file.json', Info) = False,
        'LoadMetadataJSON: Non-existent returns False');
end;

procedure TestHasMetadataJSON;
var
  MetaPath: string;
  F: TFileStream;
begin
  MetaPath := TempDir + 'exists.json';
  F := TFileStream.Create(MetaPath, fmCreate);
  F.Free;

  Check(BuildCacheHasMetadataJSON(MetaPath) = True, 'HasMetadataJSON: Existing file True');
  Check(BuildCacheHasMetadataJSON('/nonexistent.json') = False, 'HasMetadataJSON: Missing file False');

  DeleteFile(MetaPath);
end;

begin
  Randomize;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
             'test_metajson_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(TempDir);

  WriteLn('=== Build Cache MetaJSON Unit Tests ===');
  WriteLn;

  TestMetaJSONFormatDateTime;
  TestMetaJSONParseDateTime;
  TestSaveLoadMetadataJSON;
  TestLoadMetadataJSONNonExistent;
  TestHasMetadataJSON;

  RemoveDir(TempDir);

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
