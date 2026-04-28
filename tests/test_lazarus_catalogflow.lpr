program test_lazarus_catalogflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.constants,
  fpdev.version.registry,
  fpdev.lazarus.types,
  fpdev.lazarus.catalogflow;

type
  TCatalogProbe = class
  public
    InstalledVersion: string;
    ConfiguredHitVersion: string;
    ConfiguredFPCVersion: string;
    ConfiguredBranch: string;
    ConfiguredInstalled: Boolean;
    LookupCalls: Integer;
    InstalledCalls: Integer;
    function LookupConfiguredVersion(
      const AVersion: string;
      out AVersionInfo: TLazarusVersionInfo
    ): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;
  end;

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

function TCatalogProbe.LookupConfiguredVersion(
  const AVersion: string;
  out AVersionInfo: TLazarusVersionInfo
): Boolean;
begin
  Inc(LookupCalls);
  AVersionInfo := Default(TLazarusVersionInfo);
  Result := SameText(AVersion, ConfiguredHitVersion);
  if Result then
  begin
    AVersionInfo.Version := AVersion;
    AVersionInfo.Branch := ConfiguredBranch;
    AVersionInfo.FPCVersion := ConfiguredFPCVersion;
    AVersionInfo.Installed := ConfiguredInstalled;
  end;
end;

function TCatalogProbe.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Inc(InstalledCalls);
  Result := SameText(AVersion, InstalledVersion);
end;

procedure TestResolveCompatibleFPCUsesConfiguredVersion;
var
  Probe: TCatalogProbe;
begin
  Probe := TCatalogProbe.Create;
  try
    Probe.ConfiguredHitVersion := '3.0';
    Probe.ConfiguredFPCVersion := '3.2.4';
    Probe.ConfiguredInstalled := True;

    Check(
      'catalogflow uses configured fpc version before fallback',
      ResolveManagedLazarusCompatibleFPCVersionCore(
        '3.0',
        '3.2.2',
        @Probe.LookupConfiguredVersion
      ) = '3.2.4',
      'expected configured fpc version'
    );
  finally
    Probe.Free;
  end;
end;

procedure TestResolveCompatibleFPCFallsBackToRecommendedVersion;
var
  Probe: TCatalogProbe;
begin
  Probe := TCatalogProbe.Create;
  try
    Probe.ConfiguredHitVersion := '9.9';
    Probe.ConfiguredFPCVersion := '3.2.4';
    Probe.ConfiguredInstalled := True;

    Check(
      'catalogflow falls back to recommended fpc version',
      ResolveManagedLazarusCompatibleFPCVersionCore(
        '3.0',
        '3.2.2',
        @Probe.LookupConfiguredVersion
      ) = '3.2.2',
      'expected recommended fallback'
    );
  finally
    Probe.Free;
  end;
end;

procedure TestBuildAvailableVersionsMapsRegistryAndMergesConfiguredInfo;
var
  Releases: TLazarusReleaseArray;
  Versions: TLazarusVersionArray;
  ConfiguredVersions: TStringArray;
  Probe: TCatalogProbe;
begin
  Probe := TCatalogProbe.Create;
  try
    SetLength(Releases, 2);
    Releases[0].Version := '3.0';
    Releases[0].ReleaseDate := '2024-01-01';
    Releases[0].GitTag := 'lazarus_3_0_0';
    Releases[0].Branch := 'lazarus_3_0';
    SetLength(Releases[0].FPCCompatible, 1);
    Releases[0].FPCCompatible[0] := '3.2.2';
    Releases[1].Version := 'main';
    Releases[1].ReleaseDate := 'rolling';
    Releases[1].GitTag := 'main';
    Releases[1].Branch := 'main';

    SetLength(ConfiguredVersions, 1);
    ConfiguredVersions[0] := 'lazarus-3.0';

    Probe.ConfiguredHitVersion := '3.0';
    Probe.ConfiguredFPCVersion := '3.2.4';
    Probe.ConfiguredBranch := 'custom_branch';
    Probe.ConfiguredInstalled := True;

    Versions := BuildManagedLazarusAvailableVersionsCore(
      Releases,
      ConfiguredVersions,
      @Probe.LookupConfiguredVersion,
      @Probe.IsVersionInstalled
    );

    Check('catalogflow keeps registry release count after merge',
      Length(Versions) = 2,
      'count=' + IntToStr(Length(Versions)));
    Check('catalogflow preserves release version ordering',
      Versions[0].Version = '3.0',
      'version=' + Versions[0].Version);
    Check('catalogflow overlays configured branch after prefix normalization',
      Versions[0].Branch = 'custom_branch',
      'branch=' + Versions[0].Branch);
    Check('catalogflow overlays configured fpc version',
      Versions[0].FPCVersion = '3.2.4',
      'fpc=' + Versions[0].FPCVersion);
    Check('catalogflow marks merged version as installed',
      Versions[0].Installed,
      'expected installed');
    Check('catalogflow uses default fpc version when registry compatibility is empty',
      Versions[1].FPCVersion = DEFAULT_FPC_VERSION,
      'fpc=' + Versions[1].FPCVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestFilterInstalledVersionsReturnsInstalledEntriesOnly;
var
  Versions: TLazarusVersionArray;
  InstalledOnly: TLazarusVersionArray;
begin
  SetLength(Versions, 3);
  Versions[0].Version := '3.0';
  Versions[0].Installed := True;
  Versions[1].Version := '4.0';
  Versions[1].Installed := False;
  Versions[2].Version := 'main';
  Versions[2].Installed := True;

  InstalledOnly := FilterManagedInstalledLazarusVersionsCore(Versions);

  Check('catalogflow installed filter keeps only installed entries',
    Length(InstalledOnly) = 2,
    'count=' + IntToStr(Length(InstalledOnly)));
  Check('catalogflow installed filter preserves first installed version',
    InstalledOnly[0].Version = '3.0',
    'version=' + InstalledOnly[0].Version);
  Check('catalogflow installed filter preserves second installed version',
    InstalledOnly[1].Version = 'main',
    'version=' + InstalledOnly[1].Version);
end;

begin
  TestResolveCompatibleFPCUsesConfiguredVersion;
  TestResolveCompatibleFPCFallsBackToRecommendedVersion;
  TestBuildAvailableVersionsMapsRegistryAndMergesConfiguredInfo;
  TestFilterInstalledVersionsReturnsInstalledEntriesOnly;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
