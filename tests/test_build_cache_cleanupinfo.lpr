program test_build_cache_cleanupinfo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.cleanupinfo;

type
  TStubLoaders = class
    function LoadSource(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
    function LoadBinary(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function TStubLoaders.LoadSource(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Initialize(AInfo);
  if AVersion = '3.2.0' then
  begin
    AInfo.Version := AVersion;
    AInfo.SourceType := 'source';
    Exit(True);
  end;
  Result := False;
end;

function TStubLoaders.LoadBinary(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Initialize(AInfo);
  if AVersion = '3.2.2' then
  begin
    AInfo.Version := AVersion;
    AInfo.SourceType := 'binary';
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

procedure TestPrefersSourceWhenAvailable;
var
  Info: TArtifactInfo;
  Loaders: TStubLoaders;
begin
  Loaders := TStubLoaders.Create;
  try
    AssertTrue(BuildCacheLoadCleanupArtifactInfo('3.2.0', @Loaders.LoadSource, @Loaders.LoadBinary, Info),
      'source artifact is accepted');
    AssertTrue(Info.SourceType = 'source', 'source result is preserved');
  finally
    Loaders.Free;
  end;
end;

procedure TestFallsBackToBinary;
var
  Info: TArtifactInfo;
  Loaders: TStubLoaders;
begin
  Loaders := TStubLoaders.Create;
  try
    AssertTrue(BuildCacheLoadCleanupArtifactInfo('3.2.2', @Loaders.LoadSource, @Loaders.LoadBinary, Info),
      'binary artifact is used when source is missing');
    AssertTrue(Info.SourceType = 'binary', 'binary fallback result is preserved');
  finally
    Loaders.Free;
  end;
end;

procedure TestReturnsFalseWhenBothMiss;
var
  Info: TArtifactInfo;
  Loaders: TStubLoaders;
begin
  Loaders := TStubLoaders.Create;
  try
    AssertTrue(not BuildCacheLoadCleanupArtifactInfo('9.9.9', @Loaders.LoadSource, @Loaders.LoadBinary, Info),
      'missing source and binary returns false');
  finally
    Loaders.Free;
  end;
end;

begin
  TestPrefersSourceWhenAvailable;
  TestFallsBackToBinary;
  TestReturnsFalseWhenBothMiss;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
