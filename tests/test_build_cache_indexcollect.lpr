program test_build_cache_indexcollect;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.cache.types,
  fpdev.build.cache.indexcollect;

type
  TStubLookup = class
    function Lookup(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function TStubLookup.Lookup(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
begin
  Initialize(AInfo);
  if AVersion = '3.2.0' then
  begin
    AInfo.Version := AVersion;
    AInfo.AccessCount := 1;
    AInfo.CreatedAt := EncodeDate(2026, 1, 1);
    Exit(True);
  end;
  if AVersion = '3.2.2' then
  begin
    AInfo.Version := AVersion;
    AInfo.AccessCount := 3;
    AInfo.CreatedAt := EncodeDate(2026, 1, 3);
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

procedure TestCollectIndexInfosFiltersFailedLookups;
var
  Entries: TStringList;
  Lookup: TStubLookup;
  Infos: TBuildCacheIndexInfoArray;
begin
  Entries := TStringList.Create;
  Lookup := TStubLookup.Create;
  try
    Entries.Add('3.2.0={"version":"3.2.0"}');
    Entries.Add('3.2.1={"version":"3.2.1"}');
    Entries.Add('3.2.2={"version":"3.2.2"}');

    Infos := BuildCacheCollectIndexInfos(Entries, @Lookup.Lookup);

    AssertTrue(Length(Infos) = 2, 'only successful lookups are collected');
    AssertEquals('3.2.0', Infos[0].Version, 'first successful entry keeps order');
    AssertEquals('3.2.2', Infos[1].Version, 'later successful entry keeps order');
  finally
    Lookup.Free;
    Entries.Free;
  end;
end;

procedure TestCollectIndexInfosHandlesEmptyInput;
var
  Entries: TStringList;
  Lookup: TStubLookup;
  Infos: TBuildCacheIndexInfoArray;
begin
  Entries := TStringList.Create;
  Lookup := TStubLookup.Create;
  try
    Infos := BuildCacheCollectIndexInfos(Entries, @Lookup.Lookup);
    AssertTrue(Length(Infos) = 0, 'empty entries return empty info array');
  finally
    Lookup.Free;
    Entries.Free;
  end;
end;

begin
  TestCollectIndexInfosFiltersFailedLookups;
  TestCollectIndexInfosHandlesEmptyInput;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
