program test_lazarus_sourceversionflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.version.registry,
  fpdev.lazarus.sourceversionflow;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function ArrayContains(const AValues: TStringArray; const ANeedle: string): Boolean;
var
  Item: string;
begin
  Result := False;
  for Item in AValues do
    if SameText(Item, ANeedle) then
      Exit(True);
end;

function BuildStaticVersions: TLegacyLazarusStaticVersionArray;
begin
  Result := nil;
  SetLength(Result, 2);
  Result[0].Version := 'main';
  Result[0].Branch := 'main';
  Result[0].Description := 'Development version (unstable)';
  Result[1].Version := '3.0';
  Result[1].Branch := 'lazarus_3_0';
  Result[1].Description := 'Lazarus 3.0 (stable)';
end;

procedure TestRegistryHasLazarusReleasesCore;
var
  Releases: TLazarusReleaseArray;
begin
  Releases := nil;
  Check('registry helper reports empty release list as false',
    not RegistryHasLazarusReleasesCore(Releases),
    'expected false for empty release list');

  SetLength(Releases, 1);
  Releases[0] := Default(TLazarusReleaseInfo);
  Releases[0].Version := '9.9';
  Check('registry helper reports non-empty release list as true',
    RegistryHasLazarusReleasesCore(Releases),
    'expected true for populated release list');
end;

procedure TestResolveLegacyLazarusCloneRefCore;
var
  Releases: TLazarusReleaseArray;
  StaticVersions: TLegacyLazarusStaticVersionArray;
  RefName: string;
begin
  StaticVersions := BuildStaticVersions;

  Releases := nil;
  RefName := ResolveLegacyLazarusCloneRefCore(
    '3.0',
    '',
    '',
    Releases,
    StaticVersions
  );
  Check('clone ref helper falls back to static branch when registry empty',
    RefName = 'lazarus_3_0',
    'got=' + RefName);

  SetLength(Releases, 1);
  Releases[0] := Default(TLazarusReleaseInfo);
  Releases[0].Version := '9.9';
  RefName := ResolveLegacyLazarusCloneRefCore(
    '3.0',
    '',
    '',
    Releases,
    StaticVersions
  );
  Check('clone ref helper keeps static-only version opaque when registry authoritative',
    RefName = '3.0',
    'got=' + RefName);
end;

procedure TestResolveLegacyLazarusDescriptionCore;
var
  Release: TLazarusReleaseInfo;
  Releases: TLazarusReleaseArray;
  StaticVersions: TLegacyLazarusStaticVersionArray;
  Description: string;
begin
  StaticVersions := BuildStaticVersions;
  Release := Default(TLazarusReleaseInfo);

  Releases := nil;
  Description := ResolveLegacyLazarusDescriptionCore(
    '3.0',
    Release,
    Releases,
    StaticVersions
  );
  Check('description helper falls back to static description when registry empty',
    Description = 'Lazarus 3.0 (stable)',
    'got=' + Description);

  SetLength(Releases, 1);
  Releases[0] := Default(TLazarusReleaseInfo);
  Releases[0].Version := '9.9';
  Description := ResolveLegacyLazarusDescriptionCore(
    '3.0',
    Release,
    Releases,
    StaticVersions
  );
  Check('description helper keeps static-only description opaque when registry authoritative',
    Description = '3.0',
    'got=' + Description);

  Release := Default(TLazarusReleaseInfo);
  Release.Version := '9.9';
  Release.Channel := 'stable';
  Description := ResolveLegacyLazarusDescriptionCore(
    '9.9',
    Release,
    Releases,
    StaticVersions
  );
  Check('description helper formats registry release channel',
    Description = 'Lazarus 9.9 (stable)',
    'got=' + Description);
end;

procedure TestResolveLegacyLazarusVersionFromBranchCore;
var
  Releases: TLazarusReleaseArray;
  StaticVersions: TLegacyLazarusStaticVersionArray;
  VersionName: string;
begin
  StaticVersions := BuildStaticVersions;

  Releases := nil;
  VersionName := ResolveLegacyLazarusVersionFromBranchCore(
    'lazarus_3_0',
    Releases,
    StaticVersions
  );
  Check('branch helper resolves static branch when registry empty',
    VersionName = '3.0',
    'got=' + VersionName);

  SetLength(Releases, 1);
  Releases[0] := Default(TLazarusReleaseInfo);
  Releases[0].Version := '9.9';
  VersionName := ResolveLegacyLazarusVersionFromBranchCore(
    'lazarus_3_0',
    Releases,
    StaticVersions
  );
  Check('branch helper keeps static-only branch opaque when registry authoritative',
    VersionName = 'lazarus_3_0',
    'got=' + VersionName);
end;

procedure TestBuildLegacyLazarusAvailableVersionsCore;
var
  Releases: TLazarusReleaseArray;
  StaticVersions: TLegacyLazarusStaticVersionArray;
  Versions: TStringArray;
begin
  StaticVersions := BuildStaticVersions;

  Releases := nil;
  Versions := BuildLegacyLazarusAvailableVersionsCore(Releases, StaticVersions);
  Check('available helper keeps static version when registry empty',
    ArrayContains(Versions, '3.0'),
    'expected static fallback version');

  SetLength(Releases, 2);
  Releases[0] := Default(TLazarusReleaseInfo);
  Releases[0].Version := '9.9';
  Releases[1] := Default(TLazarusReleaseInfo);
  Releases[1].Version := '9.9';
  Versions := BuildLegacyLazarusAvailableVersionsCore(Releases, StaticVersions);
  Check('available helper keeps registry version',
    ArrayContains(Versions, '9.9'),
    'expected registry version');
  Check('available helper excludes static-only version when registry authoritative',
    not ArrayContains(Versions, '3.0'),
    'did not expect static-only version');
end;

begin
  WriteLn('=== Lazarus Sourceversionflow Tests ===');

  TestRegistryHasLazarusReleasesCore;
  TestResolveLegacyLazarusCloneRefCore;
  TestResolveLegacyLazarusDescriptionCore;
  TestResolveLegacyLazarusVersionFromBranchCore;
  TestBuildLegacyLazarusAvailableVersionsCore;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
