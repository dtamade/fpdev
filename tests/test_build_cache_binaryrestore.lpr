program test_build_cache_binaryrestore;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.binaryrestore;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

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

procedure TestDefaultFallbackUsesTarGz;
var
  Plan: TBuildCacheBinaryRestorePlan;
begin
  Plan := BuildCacheBuildBinaryRestorePlan('/cache/', 'fpc-3.2.2-x86_64-linux', '');
  AssertEquals('.tar.gz', Plan.FileExt, 'empty file extension falls back to .tar.gz');
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux-binary.tar.gz', Plan.ArchivePath,
    'archive path uses fallback extension');
  AssertEquals('-xzf', Plan.TarFlags, 'fallback extension uses gzipped tar flags');
end;

procedure TestPlainTarUsesXf;
var
  Plan: TBuildCacheBinaryRestorePlan;
begin
  Plan := BuildCacheBuildBinaryRestorePlan('/cache/', 'fpc-3.2.0-x86_64-linux', '.tar');
  AssertEquals('.tar', Plan.FileExt, 'plain tar extension is preserved');
  AssertEquals('-xf', Plan.TarFlags, 'plain tar uses -xf flags');
end;

procedure TestTgzUsesXzf;
var
  Plan: TBuildCacheBinaryRestorePlan;
begin
  Plan := BuildCacheBuildBinaryRestorePlan('/cache/', 'fpc-main-x86_64-linux', '.tgz');
  AssertEquals('.tgz', Plan.FileExt, 'tgz extension is preserved');
  AssertEquals('-xzf', Plan.TarFlags, 'tgz uses gzipped tar flags');
end;

procedure TestUnknownExtensionDefaultsToGzipFlags;
var
  Plan: TBuildCacheBinaryRestorePlan;
begin
  Plan := BuildCacheBuildBinaryRestorePlan('/cache/', 'fpc-zip-x86_64-linux', '.zip');
  AssertEquals('.zip', Plan.FileExt, 'unknown extension is preserved');
  AssertEquals('/cache/fpc-zip-x86_64-linux-binary.zip', Plan.ArchivePath,
    'archive path uses provided extension');
  AssertEquals('-xzf', Plan.TarFlags, 'unknown extension defaults to gzipped tar flags');
end;

begin
  TestDefaultFallbackUsesTarGz;
  TestPlainTarUsesXf;
  TestTgzUsesXzf;
  TestUnknownExtensionDefaultsToGzipFlags;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
