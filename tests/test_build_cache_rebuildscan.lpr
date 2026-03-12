program test_build_cache_rebuildscan;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache.types,
  fpdev.build.cache.rebuildscan;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;


type
  TStubMetadataLoader = class
    function Load(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
  end;

function TStubMetadataLoader.Load(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Initialize(AInfo);
  if AVersion = '3.2.2' then
  begin
    AInfo.Version := AVersion;
    AInfo.ArchiveSize := 1000;
    Exit(True);
  end;
  if AVersion = 'main' then
  begin
    AInfo.Version := AVersion;
    AInfo.ArchiveSize := 2000;
    Exit(True);
  end;
  Result := False;
end;


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


procedure TestCollectRebuildInfos;
var
  Versions: array of string;
  Infos: TBuildCacheRebuildInfoArray;
  Loader: TStubMetadataLoader;
begin
  SetLength(Versions, 3);
  Versions[0] := '3.2.2';
  Versions[1] := '3.0.4';
  Versions[2] := 'main';

  Loader := TStubMetadataLoader.Create;
  try
    Infos := BuildCacheCollectRebuildInfos(Versions, @Loader.Load);
    Check(Length(Infos) = 2, 'CollectRebuildInfos: failed loads are skipped');
    Check(Infos[0].Version = '3.2.2', 'CollectRebuildInfos: first successful version keeps order');
    Check(Infos[1].Version = 'main', 'CollectRebuildInfos: later successful version keeps order');
  finally
    Loader.Free;
  end;
end;

begin
  Randomize;
  WriteLn('=== Build Cache RebuildScan Unit Tests ===');
  WriteLn;

  TestExtractVersionFromMetadataFilename;
  TestListMetadataVersionsNonExistent;
  TestListMetadataVersionsWithFiles;
  TestCollectRebuildInfos;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
