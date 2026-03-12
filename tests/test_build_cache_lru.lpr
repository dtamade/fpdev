program test_build_cache_lru;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.lru;

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

procedure TestNeverAccessedEntriesWin;
var
  Infos: array of TArtifactInfo;
begin
  SetLength(Infos, 3);
  Infos[0].Version := '3.2.0';
  Infos[0].CreatedAt := EncodeDate(2026, 1, 1);
  Infos[0].LastAccessed := EncodeDate(2026, 1, 10);

  Infos[1].Version := '3.2.1';
  Infos[1].CreatedAt := EncodeDate(2026, 1, 2);
  Infos[1].LastAccessed := 0;

  Infos[2].Version := '3.2.2';
  Infos[2].CreatedAt := EncodeDate(2026, 1, 3);
  Infos[2].LastAccessed := 0;

  AssertEquals('3.2.1', BuildCacheSelectLeastRecentlyUsed(Infos),
    'oldest never-accessed entry wins');
end;

procedure TestOldestAccessedWinsWhenAllAccessed;
var
  Infos: array of TArtifactInfo;
begin
  SetLength(Infos, 2);
  Infos[0].Version := '3.2.0';
  Infos[0].LastAccessed := EncodeDate(2026, 1, 5);
  Infos[1].Version := '3.2.1';
  Infos[1].LastAccessed := EncodeDate(2026, 1, 6);

  AssertEquals('3.2.0', BuildCacheSelectLeastRecentlyUsed(Infos),
    'oldest last-accessed entry wins when all were accessed');
end;

procedure TestEmptyInputReturnsEmpty;
var
  Infos: array of TArtifactInfo;
begin
  SetLength(Infos, 0);
  AssertEquals('', BuildCacheSelectLeastRecentlyUsed(Infos),
    'empty input returns empty version');
end;

begin
  TestNeverAccessedEntriesWin;
  TestOldestAccessedWinsWhenAllAccessed;
  TestEmptyInputReturnsEmpty;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
