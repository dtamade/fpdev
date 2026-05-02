unit fpdev.package.registry.queryflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

function GetPackageMetadataCore(AIndex: TJSONObject; const AName: string): TJSONObject;
function GetPackageVersionsCore(AIndex: TJSONObject; const AName: string): TStringList;
function HasPackageCore(AIndex: TJSONObject; const AName: string): Boolean;
function HasPackageVersionCore(AIndex: TJSONObject; const AName, AVersion: string): Boolean;
function GetPackageArchiveCore(
  const ARegistryPath: string;
  AIndex: TJSONObject;
  const AName, AVersion: string
): string;
function ListPackagesCore(AIndex: TJSONObject): TStringList;
function SearchPackagesCore(AIndex: TJSONObject; const AQuery: string): TStringList;

implementation

function GetPackagesObject(AIndex: TJSONObject): TJSONObject;
begin
  Result := nil;
  if AIndex = nil then
    Exit;
  if AIndex.Find('packages') = nil then
    Exit;
  Result := AIndex.Objects['packages'];
end;

function BuildPackagePathCore(const ARegistryPath, AName, AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ARegistryPath) + 'packages' + PathDelim
    + AName + PathDelim + AVersion;
end;

function HasPackageCore(AIndex: TJSONObject; const AName: string): Boolean;
var
  Packages: TJSONObject;
begin
  Result := False;
  Packages := GetPackagesObject(AIndex);
  if Packages = nil then
    Exit;
  Result := Packages.Find(AName) <> nil;
end;

function GetPackageMetadataCore(AIndex: TJSONObject; const AName: string): TJSONObject;
var
  Packages: TJSONObject;
begin
  Result := nil;
  if not HasPackageCore(AIndex, AName) then
    Exit;
  Packages := GetPackagesObject(AIndex);
  Result := TJSONObject(Packages.Objects[AName].Clone);
end;

function GetPackageVersionsCore(AIndex: TJSONObject; const AName: string): TStringList;
var
  Packages: TJSONObject;
  PackageInfo: TJSONObject;
  Versions: TJSONArray;
  I: Integer;
begin
  Result := TStringList.Create;
  if not HasPackageCore(AIndex, AName) then
    Exit;

  Packages := GetPackagesObject(AIndex);
  PackageInfo := Packages.Objects[AName];
  Versions := PackageInfo.Arrays['versions'];

  for I := 0 to Versions.Count - 1 do
    Result.Add(Versions.Strings[I]);
end;

function HasPackageVersionCore(AIndex: TJSONObject; const AName, AVersion: string): Boolean;
var
  Versions: TStringList;
begin
  Result := False;
  Versions := GetPackageVersionsCore(AIndex, AName);
  try
    Result := Versions.IndexOf(AVersion) >= 0;
  finally
    Versions.Free;
  end;
end;

function GetPackageArchiveCore(
  const ARegistryPath: string;
  AIndex: TJSONObject;
  const AName, AVersion: string
): string;
var
  PackagePath: string;
begin
  Result := '';
  if not HasPackageVersionCore(AIndex, AName, AVersion) then
    Exit;

  PackagePath := BuildPackagePathCore(ARegistryPath, AName, AVersion);
  Result := PackagePath + PathDelim + AName + '-' + AVersion + '.tar.gz';
  if not FileExists(Result) then
    Result := '';
end;

function ListPackagesCore(AIndex: TJSONObject): TStringList;
var
  Packages: TJSONObject;
  I: Integer;
begin
  Result := TStringList.Create;
  Packages := GetPackagesObject(AIndex);
  if Packages = nil then
    Exit;

  for I := 0 to Packages.Count - 1 do
    Result.Add(Packages.Names[I]);
end;

function SearchPackagesCore(AIndex: TJSONObject; const AQuery: string): TStringList;
var
  Packages: TJSONObject;
  PackageInfo: TJSONObject;
  I: Integer;
  Name, Description: string;
  LowerQuery: string;
begin
  Result := TStringList.Create;
  Packages := GetPackagesObject(AIndex);
  if Packages = nil then
    Exit;

  LowerQuery := LowerCase(AQuery);
  for I := 0 to Packages.Count - 1 do
  begin
    Name := Packages.Names[I];
    PackageInfo := Packages.Objects[Name];
    Description := PackageInfo.Get('description', '');

    if (Pos(LowerQuery, LowerCase(Name)) > 0) or
       (Pos(LowerQuery, LowerCase(Description)) > 0) then
      Result.Add(Name);
  end;
end;

end.
