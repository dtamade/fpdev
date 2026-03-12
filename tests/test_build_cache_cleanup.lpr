program test_build_cache_cleanup;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.cleanup;

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

procedure TestSelectCleanupVictimsByOldestCreatedAt;
var
  Infos: array of TArtifactInfo;
  Victims: TStringArray;
begin
  SetLength(Infos, 3);
  Infos[0].Version := '3.2.0';
  Infos[0].ArchivePath := '/cache/a.tar.gz';
  Infos[0].ArchiveSize := 600;
  Infos[0].CreatedAt := EncodeDate(2026, 1, 1);

  Infos[1].Version := '3.2.1';
  Infos[1].ArchivePath := '/cache/b.tar.gz';
  Infos[1].ArchiveSize := 600;
  Infos[1].CreatedAt := EncodeDate(2026, 1, 2);

  Infos[2].Version := '3.2.2';
  Infos[2].ArchivePath := '/cache/c.tar.gz';
  Infos[2].ArchiveSize := 600;
  Infos[2].CreatedAt := EncodeDate(2026, 1, 3);

  Victims := BuildCacheSelectCleanupVictims(Infos, 1000);
  AssertTrue(Length(Victims) = 2, 'two victims selected to fit under max size');
  AssertEquals('/cache/a.tar.gz', Victims[0], 'oldest archive is removed first');
  AssertEquals('/cache/b.tar.gz', Victims[1], 'second-oldest archive is removed next');
end;

procedure TestUnlimitedCacheReturnsNoVictims;
var
  Infos: array of TArtifactInfo;
  Victims: TStringArray;
begin
  SetLength(Infos, 1);
  Infos[0].Version := '3.2.0';
  Infos[0].ArchivePath := '/cache/a.tar.gz';
  Infos[0].ArchiveSize := 600;
  Infos[0].CreatedAt := EncodeDate(2026, 1, 1);

  Victims := BuildCacheSelectCleanupVictims(Infos, 0);
  AssertTrue(Length(Victims) = 0, 'unlimited cache returns no victims');
end;

begin
  TestSelectCleanupVictimsByOldestCreatedAt;
  TestUnlimitedCacheReturnsNoVictims;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
