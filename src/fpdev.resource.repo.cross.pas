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
begin
  Result := False;

  if not Assigned(AManifest) then
    Exit;

  CrossToolchains := AManifest.Objects['cross_toolchains'];
  if not Assigned(CrossToolchains) then
    Exit;

  TargetData := CrossToolchains.Objects[ATarget];
  if not Assigned(TargetData) then
    Exit;

  HostPlatforms := TargetData.Objects['host_platforms'];
  if not Assigned(HostPlatforms) then
    Exit;

  Result := HostPlatforms.IndexOfName(AHostPlatform) >= 0;
end;

function ResourceRepoGetCrossToolchainInfo(const AManifest: TJSONObject;
  const ATarget, AHostPlatform: string; out AInfo: TResourceRepoCrossInfo): Boolean;
var
  CrossToolchains: TJSONObject;
  TargetData: TJSONObject;
  HostPlatforms: TJSONObject;
  PlatformData: TJSONObject;
begin
  Result := False;
  Initialize(AInfo);

  if not Assigned(AManifest) then
    Exit;

  CrossToolchains := AManifest.Objects['cross_toolchains'];
  if not Assigned(CrossToolchains) then
    Exit;

  TargetData := CrossToolchains.Objects[ATarget];
  if not Assigned(TargetData) then
    Exit;

  // Get target-level info
  AInfo.TargetName := ATarget;
  AInfo.DisplayName := TargetData.Get('display_name', ATarget);
  AInfo.CPU := TargetData.Get('cpu', '');
  AInfo.OS := TargetData.Get('os', '');
  AInfo.BinutilsPrefix := TargetData.Get('binutils_prefix', '');

  HostPlatforms := TargetData.Objects['host_platforms'];
  if not Assigned(HostPlatforms) then
    Exit;

  PlatformData := HostPlatforms.Objects[AHostPlatform];
  if not Assigned(PlatformData) then
    Exit;

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
  i: Integer;
begin
  Result := nil;

  if not Assigned(AManifest) then
    Exit;

  CrossToolchains := AManifest.Objects['cross_toolchains'];
  if not Assigned(CrossToolchains) then
    Exit;

  SetLength(Result, CrossToolchains.Count);
  for i := 0 to CrossToolchains.Count - 1 do
    Result[i] := CrossToolchains.Names[i];
end;

end.
