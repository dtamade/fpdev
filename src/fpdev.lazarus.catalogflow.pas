unit fpdev.lazarus.catalogflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.version.registry,
  fpdev.lazarus.types;

type
  TLazarusCatalogConfiguredVersionLookup = function(
    const AVersion: string;
    out AVersionInfo: TLazarusVersionInfo
  ): Boolean of object;
  TLazarusCatalogInstalledChecker = function(const AVersion: string): Boolean of object;

function ResolveManagedLazarusCompatibleFPCVersionCore(
  const ALazarusVersion, ARecommendedFPCVersion: string;
  ALookupConfiguredVersion: TLazarusCatalogConfiguredVersionLookup
): string;

function BuildManagedLazarusAvailableVersionsCore(
  const AReleases: TLazarusReleaseArray;
  const AConfiguredVersions: TStringArray;
  ALookupConfiguredVersion: TLazarusCatalogConfiguredVersionLookup;
  AIsVersionInstalled: TLazarusCatalogInstalledChecker
): TLazarusVersionArray;

function FilterManagedInstalledLazarusVersionsCore(
  const AAvailableVersions: TLazarusVersionArray
): TLazarusVersionArray;

implementation

uses
  fpdev.constants,
  fpdev.lazarus.metadataflow;

function NormalizeManagedConfiguredLazarusVersionCore(
  const AConfiguredVersion: string
): string;
begin
  Result := Trim(AConfiguredVersion);
  if SameText(Copy(Result, 1, Length('lazarus-')), 'lazarus-') then
    Delete(Result, 1, Length('lazarus-'));
end;

function BuildManagedRegistryLazarusVersionInfoCore(
  const ARelease: TLazarusReleaseInfo;
  AInstalled: Boolean
): TLazarusVersionInfo;
begin
  Result := Default(TLazarusVersionInfo);
  Result.Version := ARelease.Version;
  Result.ReleaseDate := ARelease.ReleaseDate;
  Result.GitTag := ARelease.GitTag;
  Result.Branch := ARelease.Branch;
  if Length(ARelease.FPCCompatible) > 0 then
    Result.FPCVersion := ARelease.FPCCompatible[0]
  else
    Result.FPCVersion := DEFAULT_FPC_VERSION;
  Result.Available := True;
  Result.Installed := AInstalled;
end;

function ResolveManagedLazarusCompatibleFPCVersionCore(
  const ALazarusVersion, ARecommendedFPCVersion: string;
  ALookupConfiguredVersion: TLazarusCatalogConfiguredVersionLookup
): string;
var
  ConfiguredInfo: TLazarusVersionInfo;
begin
  ConfiguredInfo := Default(TLazarusVersionInfo);
  if Assigned(ALookupConfiguredVersion) and
     ALookupConfiguredVersion(ALazarusVersion, ConfiguredInfo) and
     (Trim(ConfiguredInfo.FPCVersion) <> '') then
    Exit(ConfiguredInfo.FPCVersion);

  Result := ARecommendedFPCVersion;
end;

function BuildManagedLazarusAvailableVersionsCore(
  const AReleases: TLazarusReleaseArray;
  const AConfiguredVersions: TStringArray;
  ALookupConfiguredVersion: TLazarusCatalogConfiguredVersionLookup;
  AIsVersionInstalled: TLazarusCatalogInstalledChecker
): TLazarusVersionArray;
var
  I: Integer;
  ConfiguredVersion: string;
  ConfiguredInfo: TLazarusVersionInfo;
begin
  Result := nil;
  SetLength(Result, Length(AReleases));
  for I := 0 to High(AReleases) do
    Result[I] := BuildManagedRegistryLazarusVersionInfoCore(
      AReleases[I],
      Assigned(AIsVersionInstalled) and AIsVersionInstalled(AReleases[I].Version)
    );

  ConfiguredInfo := Default(TLazarusVersionInfo);
  for I := 0 to High(AConfiguredVersions) do
  begin
    ConfiguredVersion := NormalizeManagedConfiguredLazarusVersionCore(AConfiguredVersions[I]);
    if ConfiguredVersion = '' then
      Continue;
    if not Assigned(ALookupConfiguredVersion) then
      Continue;
    if not ALookupConfiguredVersion(ConfiguredVersion, ConfiguredInfo) then
      Continue;
    Result := MergeConfiguredInstalledLazarusVersionsCore(Result, ConfiguredInfo);
  end;
end;

function FilterManagedInstalledLazarusVersionsCore(
  const AAvailableVersions: TLazarusVersionArray
): TLazarusVersionArray;
begin
  Result := FilterInstalledLazarusVersionsCore(AAvailableVersions);
end;

end.
