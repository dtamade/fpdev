unit fpdev.resource.repo.cross;

{$mode objfpc}{$H+}

{
  B069: Cross toolchain query helpers for TResourceRepository

  Extracts cross toolchain lookup logic from manifest JSON.
  These are pure functions that don't depend on TResourceRepository state.
}

interface

uses
  SysUtils, fpjson;

type
  { Cross toolchain info - matches TCrossToolchainInfo structure }
  TResourceRepoCrossInfo = record
    TargetName: string;
    DisplayName: string;
    CPU: string;
    OS: string;
    BinutilsPrefix: string;
    BinutilsArchive: string;
    LibsArchive: string;
    BinutilsSHA256: string;
    LibsSHA256: string;
  end;

{ Check if cross toolchain exists in manifest }
function ResourceRepoHasCrossToolchain(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string): Boolean;

{ Get cross toolchain info from manifest }
function ResourceRepoGetCrossToolchainInfo(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string; out AInfo: TResourceRepoCrossInfo): Boolean;

{ List all cross targets from manifest }
function ResourceRepoListCrossTargets(const AManifest: TJSONObject): TStringArray;

implementation

function ResourceRepoHasCrossToolchain(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string): Boolean;
var
  CrossToolchains: TJSONObject;
  TargetData: TJSONObject;
  HostPlatforms: TJSONObject;
  Obj: TJSONData;
begin
  Result := False;

  if not Assigned(AManifest) then
    Exit;

  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifest.Find('cross_toolchains', jtObject);
  if not Assigned(Obj) then
    Exit;
  CrossToolchains := TJSONObject(Obj);

  Obj := CrossToolchains.Find(ATarget, jtObject);
  if not Assigned(Obj) then
    Exit;
  TargetData := TJSONObject(Obj);

  Obj := TargetData.Find('host_platforms', jtObject);
  if not Assigned(Obj) then
    Exit;
  HostPlatforms := TJSONObject(Obj);

  Result := HostPlatforms.IndexOfName(AHostPlatform) >= 0;
end;

function ResourceRepoGetCrossToolchainInfo(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string; out AInfo: TResourceRepoCrossInfo): Boolean;
var
  CrossToolchains: TJSONObject;
  TargetData: TJSONObject;
  HostPlatforms: TJSONObject;
  PlatformData: TJSONObject;
  Obj: TJSONData;
begin
  Result := False;
  Initialize(AInfo);

  if not Assigned(AManifest) then
    Exit;

  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifest.Find('cross_toolchains', jtObject);
  if not Assigned(Obj) then
    Exit;
  CrossToolchains := TJSONObject(Obj);

  Obj := CrossToolchains.Find(ATarget, jtObject);
  if not Assigned(Obj) then
    Exit;
  TargetData := TJSONObject(Obj);

  // Get target-level info
  AInfo.TargetName := ATarget;
  AInfo.DisplayName := TargetData.Get('display_name', ATarget);
  AInfo.CPU := TargetData.Get('cpu', '');
  AInfo.OS := TargetData.Get('os', '');
  AInfo.BinutilsPrefix := TargetData.Get('binutils_prefix', '');

  Obj := TargetData.Find('host_platforms', jtObject);
  if not Assigned(Obj) then
    Exit;
  HostPlatforms := TJSONObject(Obj);

  Obj := HostPlatforms.Find(AHostPlatform, jtObject);
  if not Assigned(Obj) then
    Exit;
  PlatformData := TJSONObject(Obj);

  // Get host-platform specific info
  AInfo.BinutilsArchive := PlatformData.Get('binutils', '');
  AInfo.LibsArchive := PlatformData.Get('libs', '');
  AInfo.BinutilsSHA256 := PlatformData.Get('binutils_sha256', '');
  AInfo.LibsSHA256 := PlatformData.Get('libs_sha256', '');

  Result := (AInfo.BinutilsArchive <> '') or (AInfo.LibsArchive <> '');
end;

function ResourceRepoListCrossTargets(const AManifest: TJSONObject): TStringArray;
var
  CrossToolchains: TJSONObject;
  Obj: TJSONData;
  i: Integer;
begin
  Result := nil;

  if not Assigned(AManifest) then
    Exit;

  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifest.Find('cross_toolchains', jtObject);
  if not Assigned(Obj) then
    Exit;
  CrossToolchains := TJSONObject(Obj);

  SetLength(Result, CrossToolchains.Count);
  for i := 0 to CrossToolchains.Count - 1 do
    Result[i] := CrossToolchains.Names[i];
end;

end.
