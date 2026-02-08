unit fpdev.cmd.package.validation;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

function ValidatePackageSourcePathCore(const SourcePath: string): Boolean;
function ValidatePackageMetadataCore(const MetadataPath: string): Boolean;
function CheckPackageRequiredFilesCore(const PackageDir: string): TStringArray;

implementation

function ValidatePackageSourcePathCore(const SourcePath: string): Boolean;
var
  SearchRec: TSearchRec;
  HasLpk, HasMakefile: Boolean;
begin
  Result := False;

  if not DirectoryExists(SourcePath) then
    Exit;

  HasLpk := False;
  HasMakefile := False;

  if FindFirst(IncludeTrailingPathDelimiter(SourcePath) + '*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        if LowerCase(ExtractFileExt(SearchRec.Name)) = '.lpk' then
          HasLpk := True;
        if LowerCase(SearchRec.Name) = 'makefile' then
          HasMakefile := True;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  Result := HasLpk or HasMakefile;
end;

function ValidatePackageMetadataCore(const MetadataPath: string): Boolean;
var
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  Name, Version: string;
begin
  Result := False;

  if not FileExists(MetadataPath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetadataPath);

    if SL.Text = '' then
      Exit;

    try
      J := GetJSON(SL.Text);
      try
        if J.JSONType = jtObject then
        begin
          O := TJSONObject(J);
          Name := O.Get('name', '');
          Version := O.Get('version', '');
          Result := (Name <> '') and (Version <> '');
        end;
      finally
        J.Free;
      end;
    except
      Result := False;
    end;
  finally
    SL.Free;
  end;
end;

function CheckPackageRequiredFilesCore(const PackageDir: string): TStringArray;
var
  HasPackageJson, HasLpk, HasMakefile: Boolean;
  SearchRec: TSearchRec;
  MissingCount: Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  MissingCount := 0;

  HasPackageJson := FileExists(IncludeTrailingPathDelimiter(PackageDir) + 'package.json');

  HasLpk := False;
  HasMakefile := False;

  if FindFirst(IncludeTrailingPathDelimiter(PackageDir) + '*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        if LowerCase(ExtractFileExt(SearchRec.Name)) = '.lpk' then
          HasLpk := True;
        if LowerCase(SearchRec.Name) = 'makefile' then
          HasMakefile := True;
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  if not HasPackageJson then
  begin
    SetLength(Result, MissingCount + 1);
    Result[MissingCount] := 'package.json';
    Inc(MissingCount);
  end;

  if not (HasLpk or HasMakefile) then
  begin
    SetLength(Result, MissingCount + 1);
    Result[MissingCount] := '.lpk or Makefile';
    Inc(MissingCount);
  end;
end;

end.
