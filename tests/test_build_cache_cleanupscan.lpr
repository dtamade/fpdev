program test_build_cache_cleanupscan;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_temp_paths,
  fpdev.build.cache.types,
  fpdev.build.cache.cleanupscan;

type
  TStubInfoLoader = class
    function LoadInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function BuildTempDir: string;
begin
  Result := CreateUniqueTempDir('fpdev-cache-cleanupscan');
end;

function TStubInfoLoader.LoadInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Initialize(AInfo);
  if AVersion = '3.2.0' then
  begin
    AInfo.Version := AVersion;
    AInfo.CreatedAt := EncodeDate(2026, 1, 1);
    Exit(True);
  end;
  Result := False;
end;

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

procedure TestCollectCleanupEntriesScansArchives;
var
  TempDir: string;
  SL: TStringList;
  Loader: TStubInfoLoader;
  Infos: TBuildCacheArtifactInfoArray;
  Index: Integer;
  Found320: Boolean;
  Found321: Boolean;
begin
  TempDir := BuildTempDir;
  try
    AssertTrue(PathUsesSystemTempRoot(TempDir),
      'temp dir uses system temp root');

    SL := TStringList.Create;
    try
      SL.Add('dummy');
      SL.SaveToFile(TempDir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz');
      SL.SaveToFile(TempDir + PathDelim + 'fpc-3.2.1-x86_64-linux.tar.gz');
      SL.SaveToFile(TempDir + PathDelim + 'notes.txt');
    finally
      SL.Free;
    end;

    Loader := TStubInfoLoader.Create;
    try
      Infos := BuildCacheCollectCleanupEntries(IncludeTrailingPathDelimiter(TempDir), @Loader.LoadInfo);
      AssertTrue(Length(Infos) = 2, 'only tar.gz archives are collected');

      Found320 := False;
      Found321 := False;
      for Index := 0 to High(Infos) do
      begin
        if Infos[Index].Version = '3.2.0' then
        begin
          Found320 := True;
          AssertEquals(IncludeTrailingPathDelimiter(TempDir) + 'fpc-3.2.0-x86_64-linux.tar.gz', Infos[Index].ArchivePath,
            'archive path is preserved for 3.2.0');
          AssertTrue(Infos[Index].CreatedAt = EncodeDate(2026, 1, 1), 'metadata loader created-at overrides file timestamp');
        end;
        if Infos[Index].Version = '3.2.1' then
        begin
          Found321 := True;
          AssertTrue(Infos[Index].CreatedAt > 0, 'file timestamp is used as fallback when metadata loader misses');
        end;
      end;
      AssertTrue(Found320, '3.2.0 entry is collected');
      AssertTrue(Found321, '3.2.1 entry is collected');
    finally
      Loader.Free;
    end;
  finally
    CleanupTempDir(TempDir);
  end;
end;

begin
  TestCollectCleanupEntriesScansArchives;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
