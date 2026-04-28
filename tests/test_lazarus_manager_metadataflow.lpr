program test_lazarus_manager_metadataflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.constants,
  fpdev.config.interfaces,
  fpdev.lazarus.types,
  fpdev.lazarus.metadataflow;

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

procedure TestNormalizeConfiguredLazarusFPCVersionCore;
begin
  Check(
    'normalize configured FPC strips prefix',
    NormalizeConfiguredLazarusFPCVersionCore('fpc-3.2.2', '3.2.0') = '3.2.2',
    'expected fpc- prefix to be removed'
  );
  Check(
    'normalize configured FPC falls back to recommended',
    NormalizeConfiguredLazarusFPCVersionCore('', '3.2.0') = '3.2.0',
    'expected recommended version fallback'
  );
  Check(
    'normalize configured FPC falls back to default constant',
    NormalizeConfiguredLazarusFPCVersionCore('', '') = DEFAULT_FPC_VERSION,
    'expected DEFAULT_FPC_VERSION fallback'
  );
end;

procedure TestOverlayConfiguredLazarusVersionInfoCore;
var
  BaseInfo: TLazarusVersionInfo;
  ConfiguredInfo: TLazarusVersionInfo;
  MergedInfo: TLazarusVersionInfo;
begin
  BaseInfo := Default(TLazarusVersionInfo);
  BaseInfo.Version := '3.0';
  BaseInfo.ReleaseDate := '2024-01-01';
  BaseInfo.GitTag := 'lazarus_3_0';
  BaseInfo.Branch := 'lazarus_3_0';
  BaseInfo.FPCVersion := '3.2.0';
  BaseInfo.Available := True;
  BaseInfo.Installed := True;

  ConfiguredInfo := Default(TLazarusVersionInfo);
  ConfiguredInfo.Version := '3.0';
  ConfiguredInfo.Branch := 'feature/custom';
  ConfiguredInfo.FPCVersion := '3.2.2';
  ConfiguredInfo.Installed := True;

  MergedInfo := OverlayConfiguredLazarusVersionInfoCore(BaseInfo, ConfiguredInfo);

  Check(
    'overlay keeps release date',
    MergedInfo.ReleaseDate = '2024-01-01',
    'release date changed unexpectedly'
  );
  Check(
    'overlay prefers configured branch',
    MergedInfo.Branch = 'feature/custom',
    'branch=' + MergedInfo.Branch
  );
  Check(
    'overlay prefers configured FPC version',
    MergedInfo.FPCVersion = '3.2.2',
    'fpc=' + MergedInfo.FPCVersion
  );
end;

procedure TestMergeConfiguredInstalledLazarusVersionsCore;
var
  BaseVersions: TLazarusVersionArray;
  ConfiguredInfo: TLazarusVersionInfo;
  MergedVersions: TLazarusVersionArray;
begin
  SetLength(BaseVersions, 1);
  BaseVersions[0] := Default(TLazarusVersionInfo);
  BaseVersions[0].Version := '3.0';
  BaseVersions[0].Installed := True;

  ConfiguredInfo := Default(TLazarusVersionInfo);
  ConfiguredInfo.Version := '3.7';
  ConfiguredInfo.FPCVersion := '3.2.2';
  ConfiguredInfo.Branch := 'lazarus_3_7';
  ConfiguredInfo.Installed := True;

  MergedVersions := MergeConfiguredInstalledLazarusVersionsCore(BaseVersions, ConfiguredInfo);

  Check(
    'merge appends config-only installed version',
    Length(MergedVersions) = 2,
    'len=' + IntToStr(Length(MergedVersions))
  );
  Check(
    'merge appends config-only version at tail',
    MergedVersions[High(MergedVersions)].Version = '3.7',
    'version=' + MergedVersions[High(MergedVersions)].Version
  );
end;

procedure TestFilterInstalledLazarusVersionsCore;
var
  AllVersions: TLazarusVersionArray;
  InstalledVersions: TLazarusVersionArray;
begin
  SetLength(AllVersions, 3);

  AllVersions[0] := Default(TLazarusVersionInfo);
  AllVersions[0].Version := '3.0';
  AllVersions[0].Installed := True;

  AllVersions[1] := Default(TLazarusVersionInfo);
  AllVersions[1].Version := '3.1';
  AllVersions[1].Installed := False;

  AllVersions[2] := Default(TLazarusVersionInfo);
  AllVersions[2].Version := '3.2';
  AllVersions[2].Installed := True;

  InstalledVersions := FilterInstalledLazarusVersionsCore(AllVersions);

  Check(
    'filter keeps only installed entries',
    Length(InstalledVersions) = 2,
    'len=' + IntToStr(Length(InstalledVersions))
  );
  Check(
    'filter keeps first installed version',
    InstalledVersions[0].Version = '3.0',
    'version=' + InstalledVersions[0].Version
  );
  Check(
    'filter keeps second installed version',
    InstalledVersions[1].Version = '3.2',
    'version=' + InstalledVersions[1].Version
  );
end;

begin
  WriteLn('=== Lazarus Manager Metadataflow Tests ===');

  TestNormalizeConfiguredLazarusFPCVersionCore;
  TestOverlayConfiguredLazarusVersionInfoCore;
  TestMergeConfiguredInstalledLazarusVersionsCore;
  TestFilterInstalledLazarusVersionsCore;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
