unit fpdev.resource.repo.binary;

{$mode objfpc}{$H+}

{
  B067: Binary release query helpers for TResourceRepository

  Extracts binary release lookup logic from manifest JSON.
  These are pure functions that don't depend on TResourceRepository state.
}

interface

uses
  SysUtils, fpjson;

type
  { Binary release platform info - matches TPlatformInfo structure }
  TBinaryReleaseInfo = record
    Path: string;
    URL: string;
    SHA256: string;
    Size: Int64;
    Tested: Boolean;
    Mirrors: array of string;
  end;

{ Check if binary release exists in manifest }
function ResourceRepoHasBinaryRelease(const AManifest: TJSONObject;
  const AVersion, APlatform: string): Boolean;

{ Get binary release info from manifest }
function ResourceRepoGetBinaryReleaseInfo(const AManifest: TJSONObject;
  const AVersion, APlatform: string; out AInfo: TBinaryReleaseInfo): Boolean;

implementation

function ResourceRepoHasBinaryRelease(const AManifest: TJSONObject;
  const AVersion, APlatform: string): Boolean;
var
  BinaryReleases: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
begin
  Result := False;

  if not Assigned(AManifest) then
    Exit;

  // Try fpc_releases first (v2.0), then binary_releases (v1.0)
  BinaryReleases := AManifest.Objects['fpc_releases'];
  if not Assigned(BinaryReleases) then
    BinaryReleases := AManifest.Objects['binary_releases'];
  if not Assigned(BinaryReleases) then
    Exit;

  VersionData := BinaryReleases.Objects[AVersion];
  if not Assigned(VersionData) then
    Exit;

  Platforms := VersionData.Objects['platforms'];
  if not Assigned(Platforms) then
    Exit;

  Result := Platforms.IndexOfName(APlatform) >= 0;
end;

function ResourceRepoGetBinaryReleaseInfo(const AManifest: TJSONObject;
  const AVersion, APlatform: string; out AInfo: TBinaryReleaseInfo): Boolean;
var
  BinaryReleases: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  i: Integer;
begin
  Result := False;
  Initialize(AInfo);

  if not Assigned(AManifest) then
    Exit;

  // Try fpc_releases first (v2.0 format), then binary_releases (v1.0 format)
  BinaryReleases := AManifest.Objects['fpc_releases'];
  if not Assigned(BinaryReleases) then
    BinaryReleases := AManifest.Objects['binary_releases'];
  if not Assigned(BinaryReleases) then
    Exit;

  VersionData := BinaryReleases.Objects[AVersion];
  if not Assigned(VersionData) then
    Exit;

  AInfo.Path := VersionData.Get('path', '');

  Platforms := VersionData.Objects['platforms'];
  if not Assigned(Platforms) then
    Exit;

  PlatformData := Platforms.Objects[APlatform];
  if not Assigned(PlatformData) then
    Exit;

  // v2.0 fields: url and mirrors
  AInfo.URL := PlatformData.Get('url', '');
  MirrorsArray := PlatformData.Arrays['mirrors'];
  if Assigned(MirrorsArray) then
  begin
    SetLength(AInfo.Mirrors, MirrorsArray.Count);
    for i := 0 to MirrorsArray.Count - 1 do
      AInfo.Mirrors[i] := MirrorsArray.Strings[i];
  end
  else
    SetLength(AInfo.Mirrors, 0);

  // v1.0 backward compatibility: archive field
  if AInfo.URL = '' then
    AInfo.Path := PlatformData.Get('archive', AInfo.Path);

  // Common fields
  AInfo.SHA256 := PlatformData.Get('sha256', '');
  AInfo.Size := PlatformData.Get('size', Int64(0));
  AInfo.Tested := PlatformData.Get('tested', False);

  Result := (AInfo.URL <> '') or (AInfo.Path <> '');
end;

end.
