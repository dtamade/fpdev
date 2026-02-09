program test_build_cache_rebuildscan;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.build.cache.rebuildscan;

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

procedure TestExtractVersionFromMetadataFilename;
begin
  Check(BuildCacheExtractVersionFromMetadataFilename('fpc-3.2.2-x86_64-linux.json') = '3.2.2',
        'ExtractVersion: fpc-3.2.2-x86_64-linux.json -> 3.2.2');
  Check(BuildCacheExtractVersionFromMetadataFilename('fpc-3.0.4-i386-win64.json') = '3.0.4',
        'ExtractVersion: fpc-3.0.4-i386-win64.json -> 3.0.4');
  Check(BuildCacheExtractVersionFromMetadataFilename('fpc-main-x86_64-linux.json') = 'main',
        'ExtractVersion: fpc-main-x86_64-linux.json -> main');

  // Invalid
  Check(BuildCacheExtractVersionFromMetadataFilename('lazarus-3.0.json') = '',
        'ExtractVersion: Invalid prefix returns empty');
  Check(BuildCacheExtractVersionFromMetadataFilename('') = '',
        'ExtractVersion: Empty returns empty');
end;

procedure TestListMetadataVersionsNonExistent;
var
  Versions: SysUtils.TStringArray;
begin
  Versions := BuildCacheListMetadataVersions('/nonexistent/dir/');
  Check((Versions = nil) or (Length(Versions) = 0),
        'ListMetadataVersions: Non-existent dir returns empty');
end;

procedure TestListMetadataVersionsWithFiles;
var
  Dir: string;
  F: TFileStream;
  Versions: SysUtils.TStringArray;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
         'test_rebuildscan_' + IntToStr(Random(100000)) + PathDelim;
  ForceDirectories(Dir);
  try
    // Create fake .json metadata files
    F := TFileStream.Create(Dir + 'fpc-3.2.2-x86_64-linux.json', fmCreate);
    F.Free;
    F := TFileStream.Create(Dir + 'fpc-3.0.4-i386-linux.json', fmCreate);
    F.Free;

    Versions := BuildCacheListMetadataVersions(Dir);
    Check(Length(Versions) = 2, 'ListMetadataVersions: Found 2 versions');
  finally
    DeleteFile(Dir + 'fpc-3.2.2-x86_64-linux.json');
    DeleteFile(Dir + 'fpc-3.0.4-i386-linux.json');
    RemoveDir(Dir);
  end;
end;

begin
  Randomize;
  WriteLn('=== Build Cache RebuildScan Unit Tests ===');
  WriteLn;

  TestExtractVersionFromMetadataFilename;
  TestListMetadataVersionsNonExistent;
  TestListMetadataVersionsWithFiles;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
