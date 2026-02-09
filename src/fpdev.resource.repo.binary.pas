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
  Obj: TJSONData;
begin
  Result := False;

  if not Assigned(AManifest) then
    Exit;

  // Try fpc_releases first (v2.0), then binary_releases (v1.0)
  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifest.Find('fpc_releases', jtObject);
  if Assigned(Obj) then
    BinaryReleases := TJSONObject(Obj)
  else
  begin
    Obj := AManifest.Find('binary_releases', jtObject);
    if Assigned(Obj) then
      BinaryReleases := TJSONObject(Obj)
    else
      Exit;
  end;

  Obj := BinaryReleases.Find(AVersion, jtObject);
  if not Assigned(Obj) then
    Exit;
  VersionData := TJSONObject(Obj);

  Obj := VersionData.Find('platforms', jtObject);
  if not Assigned(Obj) then
    Exit;
  Platforms := TJSONObject(Obj);

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
  Obj: TJSONData;
  i: Integer;
begin
  Result := False;
  Initialize(AInfo);

  if not Assigned(AManifest) then
    Exit;

  // Try fpc_releases first (v2.0 format), then binary_releases (v1.0 format)
  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifest.Find('fpc_releases', jtObject);
  if Assigned(Obj) then
    BinaryReleases := TJSONObject(Obj)
  else
  begin
    Obj := AManifest.Find('binary_releases', jtObject);
    if Assigned(Obj) then
      BinaryReleases := TJSONObject(Obj)
    else
      Exit;
  end;

  Obj := BinaryReleases.Find(AVersion, jtObject);
  if not Assigned(Obj) then
    Exit;
  VersionData := TJSONObject(Obj);

  AInfo.Path := VersionData.Get('path', '');

  Obj := VersionData.Find('platforms', jtObject);
  if not Assigned(Obj) then
    Exit;
  Platforms := TJSONObject(Obj);

  Obj := Platforms.Find(APlatform, jtObject);
  if not Assigned(Obj) then
    Exit;
  PlatformData := TJSONObject(Obj);

  // v2.0 fields: url and mirrors
  AInfo.URL := PlatformData.Get('url', '');
  Obj := PlatformData.Find('mirrors', jtArray);
  if Assigned(Obj) then
  begin
    MirrorsArray := TJSONArray(Obj);
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
