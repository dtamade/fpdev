unit fpdev.lazarus.sourceversionflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.version.registry;

type
  TLegacyLazarusStaticVersionInfo = record
    Version: string;
    Branch: string;
    Description: string;
  end;

  TLegacyLazarusStaticVersionArray = array of TLegacyLazarusStaticVersionInfo;

function RegistryHasLazarusReleasesCore(
  const AReleases: TLazarusReleaseArray
): Boolean;

function ResolveLegacyLazarusCloneRefCore(
  const AVersion, ARegistryGitTag, ARegistryBranch: string;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): string;

function ResolveLegacyLazarusDescriptionCore(
  const AVersion: string;
  const ARelease: TLazarusReleaseInfo;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): string;

function ResolveLegacyLazarusVersionFromBranchCore(
  const ABranch: string;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): string;

function BuildLegacyLazarusAvailableVersionsCore(
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): TStringArray;

function IsLegacyLazarusVersionAvailableCore(
  const AVersion: string;
  const ARegistryValidVersion: Boolean;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): Boolean;

implementation

function FindStaticVersionIndex(
  const AVersion: string;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AStaticVersions) do
    if SameText(AStaticVersions[I].Version, AVersion) then
      Exit(I);
end;

function FindStaticBranchIndex(
  const ABranch: string;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AStaticVersions) do
    if SameText(AStaticVersions[I].Branch, ABranch) then
      Exit(I);
end;

function BuildLazarusDescription(
  const AVersion, AChannel: string
): string;
begin
  if SameText(AVersion, 'main') or SameText(AChannel, 'development') then
    Exit('Development version (unstable)');

  if Trim(AChannel) <> '' then
    Exit('Lazarus ' + AVersion + ' (' + AChannel + ')');

  Result := 'Lazarus ' + AVersion;
end;

procedure AddUniqueVersion(var AValues: TStringArray; const AVersion: string);
var
  I: Integer;
begin
  if Trim(AVersion) = '' then
    Exit;

  for I := 0 to High(AValues) do
    if SameText(AValues[I], AVersion) then
      Exit;

  SetLength(AValues, Length(AValues) + 1);
  AValues[High(AValues)] := AVersion;
end;

function RegistryHasLazarusReleasesCore(
  const AReleases: TLazarusReleaseArray
): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AReleases) do
    if Trim(AReleases[I].Version) <> '' then
      Exit(True);
end;

function ResolveLegacyLazarusCloneRefCore(
  const AVersion, ARegistryGitTag, ARegistryBranch: string;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): string;
var
  StaticIndex: Integer;
begin
  if ARegistryGitTag <> '' then
    Exit(ARegistryGitTag);

  if ARegistryBranch <> '' then
    Exit(ARegistryBranch);

  if RegistryHasLazarusReleasesCore(AReleases) then
    Exit(AVersion);

  StaticIndex := FindStaticVersionIndex(AVersion, AStaticVersions);
  if StaticIndex >= 0 then
    Exit(AStaticVersions[StaticIndex].Branch);

  Result := AVersion;
end;

function ResolveLegacyLazarusDescriptionCore(
  const AVersion: string;
  const ARelease: TLazarusReleaseInfo;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): string;
var
  StaticIndex: Integer;
begin
  if Trim(ARelease.Version) <> '' then
    Exit(BuildLazarusDescription(ARelease.Version, ARelease.Channel));

  if RegistryHasLazarusReleasesCore(AReleases) then
    Exit(AVersion);

  StaticIndex := FindStaticVersionIndex(AVersion, AStaticVersions);
  if StaticIndex >= 0 then
    Exit(AStaticVersions[StaticIndex].Description);

  Result := AVersion;
end;

function ResolveLegacyLazarusVersionFromBranchCore(
  const ABranch: string;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): string;
var
  I: Integer;
  StaticIndex: Integer;
begin
  Result := ABranch;
  for I := 0 to High(AReleases) do
    if SameText(AReleases[I].GitTag, ABranch) or
       SameText(AReleases[I].Branch, ABranch) then
      Exit(AReleases[I].Version);

  if RegistryHasLazarusReleasesCore(AReleases) then
    Exit(ABranch);

  StaticIndex := FindStaticBranchIndex(ABranch, AStaticVersions);
  if StaticIndex >= 0 then
    Result := AStaticVersions[StaticIndex].Version;
end;

function BuildLegacyLazarusAvailableVersionsCore(
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): TStringArray;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(AReleases) do
    AddUniqueVersion(Result, AReleases[I].Version);

  if RegistryHasLazarusReleasesCore(AReleases) then
    Exit;

  for I := 0 to High(AStaticVersions) do
    AddUniqueVersion(Result, AStaticVersions[I].Version);
end;

function IsLegacyLazarusVersionAvailableCore(
  const AVersion: string;
  const ARegistryValidVersion: Boolean;
  const AReleases: TLazarusReleaseArray;
  const AStaticVersions: array of TLegacyLazarusStaticVersionInfo
): Boolean;
begin
  if ARegistryValidVersion then
    Exit(True);

  if RegistryHasLazarusReleasesCore(AReleases) then
    Exit(False);

  Result := FindStaticVersionIndex(AVersion, AStaticVersions) >= 0;
end;

end.
