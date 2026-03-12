program test_build_cache_entryquery;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.entryquery;

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

procedure TestNeedsRebuildFromEntryLine;
begin
  AssertTrue(BuildCacheNeedsRebuildFromEntryLine('', 3),
    'missing entry means rebuild is needed');
  AssertTrue(BuildCacheNeedsRebuildFromEntryLine('version=3.2.2;status=2', 3),
    'lower cached status requires rebuild');
  AssertTrue(not BuildCacheNeedsRebuildFromEntryLine('version=3.2.2;status=3', 3),
    'equal cached status does not require rebuild');
  AssertTrue(not BuildCacheNeedsRebuildFromEntryLine('version=3.2.2;status=9', 3),
    'higher cached status does not require rebuild');
end;

procedure TestGetRevisionFromEntryLine;
begin
  AssertEquals('abc123',
    BuildCacheGetRevisionFromEntryLine('version=3.2.2;revision=abc123;status=9'),
    'revision is extracted from entry line');
  AssertEquals('', BuildCacheGetRevisionFromEntryLine('version=3.2.2;status=9'),
    'missing revision returns empty string');
  AssertEquals('', BuildCacheGetRevisionFromEntryLine(''),
    'empty line returns empty revision');
end;

begin
  TestNeedsRebuildFromEntryLine;
  TestGetRevisionFromEntryLine;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
