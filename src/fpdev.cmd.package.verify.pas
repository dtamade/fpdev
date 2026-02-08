unit fpdev.cmd.package.verify;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, fpdev.hash;

type
  TPackageVerifyStatus = (pvsValid, pvsInvalid, pvsMissingFiles, pvsMetadataError);

  TPackageVerifyResult = record
    Status: TPackageVerifyStatus;
    PackageName: string;
    Version: string;
    MissingFiles: TStringArray;
  end;

function VerifyInstalledPackageCore(const TestDir: string): TPackageVerifyResult;
function VerifyPackageChecksumCore(const FilePath, Hash: string): Boolean;

implementation

function VerifyInstalledPackageCore(const TestDir: string): TPackageVerifyResult;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  FilesArray: TJSONArray;
  i: Integer;
  FilePath: string;
begin
  Result.Status := pvsInvalid;
  Result.PackageName := '';
  Result.Version := '';
  SetLength(Result.MissingFiles, 0);

  MetaPath := IncludeTrailingPathDelimiter(TestDir) + 'package.json';
  if not FileExists(MetaPath) then
  begin
    Result.Status := pvsMetadataError;
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
      if J.JSONType = jtObject then
      begin
        O := TJSONObject(J);
        Result.PackageName := O.Get('name', '');
        Result.Version := O.Get('version', '');

        if O.Find('files') <> nil then
        begin
          FilesArray := O.Arrays['files'];
          for i := 0 to FilesArray.Count - 1 do
          begin
            FilePath := IncludeTrailingPathDelimiter(TestDir) + FilesArray.Strings[i];
            if not FileExists(FilePath) then
            begin
              SetLength(Result.MissingFiles, Length(Result.MissingFiles) + 1);
              Result.MissingFiles[High(Result.MissingFiles)] := FilesArray.Strings[i];
            end;
          end;
        end;

        if (Result.PackageName = '') or (Result.Version = '') then
          Result.Status := pvsMetadataError
        else if Length(Result.MissingFiles) > 0 then
          Result.Status := pvsMissingFiles
        else
          Result.Status := pvsValid;
      end
      else
        Result.Status := pvsMetadataError;
      J.Free;
    except
      Result.Status := pvsMetadataError;
    end;
  finally
    SL.Free;
  end;
end;

function VerifyPackageChecksumCore(const FilePath, Hash: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  if not FileExists(FilePath) then
    Exit;

  ActualHash := SHA256FileHex(FilePath);
  Result := SameText(ActualHash, Hash);
end;

end.
