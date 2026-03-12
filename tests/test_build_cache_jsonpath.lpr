program test_build_cache_jsonpath;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.jsonpath;

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
  AssertEquals('/cache/fpc-3.2.2-x86_64-linux.json',
    BuildCacheGetJSONMetaPath('/cache/', 'fpc-3.2.2-x86_64-linux'),
    'json meta path appends .json suffix');

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
