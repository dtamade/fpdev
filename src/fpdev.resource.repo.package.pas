unit fpdev.resource.repo.package;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.resource.repo.types;

function ResourceRepoResolvePackageMetaPath(const ALocalPath, AName: string): string;
function ResourceRepoLoadPackageInfoFromFile(
  const APackageMetaPath, AName: string;
  out AInfo: TRepoPackageInfo
): Boolean;
function ResourceRepoListPackagesCore(const ALocalPath, ACategory: string): SysUtils.TStringArray;

implementation

function ResourceRepoResolvePackageMetaPath(const ALocalPath, AName: string): string;
var
  CandidatePath: string;
begin
  Result := '';

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + AName +
    PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + 'core' +
    PathDelim + AName + PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + 'ui' +
    PathDelim + AName + PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;

  CandidatePath := ALocalPath + PathDelim + 'packages' + PathDelim + 'utils' +
    PathDelim + AName + PathDelim + AName + '.json';
  if FileExists(CandidatePath) then
  begin
    Result := CandidatePath;
    Exit;
  end;
end;



function ResourceRepoLoadPackageInfoFromFile(
  const APackageMetaPath, AName: string;
  out AInfo: TRepoPackageInfo
): Boolean;
var
  MetaContent: string;
  Parser: TJSONParser;
  PackageJSON: TJSONObject;
  DepsArray: TJSONArray;
  Obj: TJSONData;
  Index: Integer;
  SL: TStringList;
begin
  Result := False;
  AInfo := EmptyRepoPackageInfo;
  if not FileExists(APackageMetaPath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APackageMetaPath);
    MetaContent := SL.Text;
  finally
    SL.Free;
  end;

  Parser := TJSONParser.Create(MetaContent, []);
  try
    PackageJSON := Parser.Parse as TJSONObject;
    try
      AInfo.Name := PackageJSON.Get('name', AName);
      AInfo.Version := PackageJSON.Get('version', '');
      AInfo.Description := PackageJSON.Get('description', '');
      AInfo.Category := PackageJSON.Get('category', '');
      AInfo.Archive := PackageJSON.Get('archive', '');
      AInfo.SHA256 := PackageJSON.Get('sha256', '');
      AInfo.FPCMinVersion := PackageJSON.Get('fpc_min', '');

      Obj := PackageJSON.Find('dependencies', jtArray);
      if Assigned(Obj) then
      begin
        DepsArray := TJSONArray(Obj);
        SetLength(AInfo.Dependencies, DepsArray.Count);
        for Index := 0 to DepsArray.Count - 1 do
          AInfo.Dependencies[Index] := DepsArray.Strings[Index];
      end;

      Result := True;
    finally
      PackageJSON.Free;
    end;
  finally
    Parser.Free;
  end;
end;

function ResourceRepoListPackagesCore(const ALocalPath, ACategory: string): SysUtils.TStringArray;
const
  CATEGORY_DIR_SUFFIX = '/';
var
  PackagesDir, CategoryDir: string;
  SearchRec: TSearchRec;
  Count: Integer;
begin
  Result := nil;
  Count := 0;

  PackagesDir := ALocalPath + PathDelim + 'packages';
  if not DirectoryExists(PackagesDir) then
    Exit;

  if ACategory <> '' then
  begin
    CategoryDir := PackagesDir + PathDelim + ACategory;
    if not DirectoryExists(CategoryDir) then
      Exit;

    if FindFirst(CategoryDir + PathDelim + '*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and ((SearchRec.Attr and faDirectory) <> 0) then
        begin
          SetLength(Result, Count + 1);
          Result[Count] := SearchRec.Name;
          Inc(Count);
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
  end
  else
  begin
    if FindFirst(PackagesDir + PathDelim + '*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') and ((SearchRec.Attr and faDirectory) <> 0) then
        begin
          SetLength(Result, Count + 1);
          Result[Count] := SearchRec.Name + CATEGORY_DIR_SUFFIX;
          Inc(Count);
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;
  end;
end;

end.
