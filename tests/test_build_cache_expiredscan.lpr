program test_build_cache_expiredscan;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_temp_paths,
  fpdev.build.cache.types,
  fpdev.build.cache.expiredscan;

type
  TStubExpiredLoader = class
    function Load(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
    function IsExpired(const AInfo: TArtifactInfo): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function BuildTempDir: string;
begin
  Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir('fpdev-expiredscan'));
end;

function TStubExpiredLoader.Load(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Initialize(AInfo);
  if AVersion = '3.2.0' then
  begin
    AInfo.Version := AVersion;
    Exit(True);
  end;
  if AVersion = '3.2.2' then
  begin
    AInfo.Version := AVersion;
    Exit(True);
  end;
  Result := False;
end;

function TStubExpiredLoader.IsExpired(const AInfo: TArtifactInfo): Boolean;
begin
  Result := AInfo.Version = '3.2.2';
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

procedure TestCollectExpiredVersionsScansMetaFiles;
var
  Dir: string;
  Loader: TStubExpiredLoader;
  Meta: TStringList;
  Versions: TStringArray;
begin
  try
    Dir := BuildTempDir;
    AssertTrue(PathUsesSystemTempRoot(Dir), 'temp expiredscan dir uses system temp root');

    Meta := TStringList.Create;
    try
      Meta.Add('dummy');
      Meta.SaveToFile(Dir + 'fpc-3.2.0-x86_64-linux.meta');
      Meta.SaveToFile(Dir + 'fpc-3.2.2-x86_64-linux-binary.meta');
      Meta.SaveToFile(Dir + 'notes.txt');
    finally
      Meta.Free;
    end;

    Loader := TStubExpiredLoader.Create;
    try
      Versions := BuildCacheCollectExpiredVersions(Dir, @Loader.Load, @Loader.IsExpired);
      AssertTrue(Length(Versions) = 1, 'only expired versions are collected');
      AssertEquals('3.2.2', Versions[0], 'expired version keeps extracted version');
    finally
      Loader.Free;
    end;
  finally
    CleanupTempDir(Dir);
  end;
end;

procedure TestCollectExpiredVersionsSkipsMissingDirectory;
var
  Loader: TStubExpiredLoader;
  Versions: TStringArray;
begin
  Loader := TStubExpiredLoader.Create;
  try
    Versions := BuildCacheCollectExpiredVersions('/nonexistent/fpdev-expired/',
      @Loader.Load, @Loader.IsExpired);
    AssertTrue(Length(Versions) = 0, 'missing directory returns empty array');
  finally
    Loader.Free;
  end;
end;

begin
  Randomize;
  TestCollectExpiredVersionsScansMetaFiles;
  TestCollectExpiredVersionsSkipsMissingDirectory;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
