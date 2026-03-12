program test_build_cache_sourcepath;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.sourcepath;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  if AExpected = AActual then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage, ' (expected: ', AExpected, ', got: ', AActual, ')');
  end;
end;

begin
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux.tar.gz',
    BuildCacheGetSourceArchivePath('/cache/', 'fpc-3.2.2-x86_64-linux'),
    'source archive path appends .tar.gz');

  AssertEquals('/cache/fpc-3.2.2-x86_64-linux.meta',
    BuildCacheGetSourceMetaPath('/cache/', 'fpc-3.2.2-x86_64-linux'),
    'source meta path appends .meta');

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
