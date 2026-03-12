unit fpdev.resource.repo.bootstrapquery;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson,
  fpdev.resource.repo.types;

function ResourceRepoHasBootstrapCompiler(const AManifest: TJSONObject;
  const AVersion, APlatform: string): Boolean;
function ResourceRepoGetBootstrapCompilerInfo(const AManifest: TJSONObject;
  const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
function ResourceRepoGetBootstrapExecutablePath(const ARepoRoot,
  AExecutable: string): string;

implementation

function ResourceRepoHasBootstrapCompiler(const AManifest: TJSONObject;
  const AVersion, APlatform: string): Boolean;
var
  BootstrapCompilers: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  Obj: TJSONData;
begin
  Result := False;

  if not Assigned(AManifest) then
    Exit;

  Obj := AManifest.Find('bootstrap_compilers', jtObject);
  if not Assigned(Obj) then
    Exit;
  BootstrapCompilers := TJSONObject(Obj);

  Obj := BootstrapCompilers.Find(AVersion, jtObject);
  if not Assigned(Obj) then
    Exit;
  VersionData := TJSONObject(Obj);

  Obj := VersionData.Find('platforms', jtObject);
  if not Assigned(Obj) then
    Exit;
  Platforms := TJSONObject(Obj);

  Result := Platforms.IndexOfName(APlatform) >= 0;
end;

function ResourceRepoGetBootstrapCompilerInfo(const AManifest: TJSONObject;
  const AVersion, APlatform: string; out AInfo: TPlatformInfo): Boolean;
var
  BootstrapCompilers: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  Obj: TJSONData;
  I: Integer;
begin
  Result := False;
  AInfo := EmptyPlatformInfo;

  if not Assigned(AManifest) then
    Exit;

  Obj := AManifest.Find('bootstrap_compilers', jtObject);
  if not Assigned(Obj) then
    Exit;
  BootstrapCompilers := TJSONObject(Obj);

  Obj := BootstrapCompilers.Find(AVersion, jtObject);
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

  AInfo.URL := PlatformData.Get('url', '');
  Obj := PlatformData.Find('mirrors', jtArray);
  if Assigned(Obj) then
  begin
    MirrorsArray := TJSONArray(Obj);
    SetLength(AInfo.Mirrors, MirrorsArray.Count);
    for I := 0 to MirrorsArray.Count - 1 do
      AInfo.Mirrors[I] := MirrorsArray.Strings[I];
  end
  else
    SetLength(AInfo.Mirrors, 0);

  if AInfo.URL = '' then
    AInfo.Path := PlatformData.Get('archive', AInfo.Path);

  AInfo.Executable := PlatformData.Get('executable', '');
  AInfo.SHA256 := PlatformData.Get('sha256', '');
  AInfo.Size := PlatformData.Get('size', Int64(0));
  AInfo.Tested := PlatformData.Get('tested', False);

  Result := (AInfo.Executable <> '') or (AInfo.URL <> '') or (AInfo.Path <> '');
end;

function ResourceRepoGetBootstrapExecutablePath(const ARepoRoot,
  AExecutable: string): string;
begin
  if AExecutable = '' then
    Exit('');
  Result := IncludeTrailingPathDelimiter(ARepoRoot) + AExecutable;
end;

end.
