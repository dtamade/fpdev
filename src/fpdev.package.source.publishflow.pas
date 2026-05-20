unit fpdev.package.source.publishflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.output.intf;

type
  TPackageSourcePublishPlan = record
    IndexPath: string;
    PackageName: string;
    Version: string;
    Description: string;
    Author: string;
    License: string;
    Homepage: string;
    URL: string;
    Sha256: string;
    Dependencies: TStringArray;
  end;

function ExecutePackageSourcePublishCore(
  const APlan: TPackageSourcePublishPlan;
  const AOut, AErr: IOutput
): Integer;

implementation

uses
  Classes, fpjson, jsonparser,
  fpdev.i18n, fpdev.i18n.strings;

function ExecutePackageSourcePublishCore(
  const APlan: TPackageSourcePublishPlan;
  const AOut, AErr: IOutput
): Integer;
var
  SL: TStringList;
  JSONData: TJSONData = nil;
  RootObj: TJSONObject;
  Arr: TJSONArray;
  Pkg: TJSONObject;
  DepArr: TJSONArray;
  I: Integer;
  Existing: TJSONObject;
begin
  Result := 1;

  if not FileExists(APlan.IndexPath) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': index.json not found: ' + APlan.IndexPath);
    Exit(1);
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APlan.IndexPath);
    try
      JSONData := GetJSON(SL.Text);
    except
      on E: Exception do
      begin
        if AErr <> nil then
          AErr.WriteLn(_(MSG_ERROR) + ': invalid JSON: ' + E.Message);
        Exit(1);
      end;
    end;

    if JSONData.JSONType <> jtObject then
    begin
      if AErr <> nil then
        AErr.WriteLn(_(MSG_ERROR) + ': index.json root must be an object');
      JSONData.Free;
      Exit(1);
    end;

    RootObj := TJSONObject(JSONData);
    if RootObj.Find('packages') = nil then
      RootObj.Add('packages', TJSONArray.Create);

    Arr := RootObj.Arrays['packages'];

    for I := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[I].JSONType <> jtObject then Continue;
      Existing := TJSONObject(Arr.Items[I]);
      if SameText(Existing.Get('name', ''), APlan.PackageName) and
         (Existing.Get('version', '') = APlan.Version) then
      begin
        if AErr <> nil then
          AErr.WriteLn(_(MSG_ERROR) + ': ' +
            _Fmt(MSG_PKG_SOURCE_ALREADY_EXISTS, [APlan.PackageName, APlan.Version]));
        JSONData.Free;
        Exit(1);
      end;
    end;

    Pkg := TJSONObject.Create;
    Pkg.Add('name', APlan.PackageName);
    Pkg.Add('version', APlan.Version);
    if APlan.Description <> '' then
      Pkg.Add('description', APlan.Description);
    if APlan.Author <> '' then
      Pkg.Add('author', APlan.Author);
    if APlan.License <> '' then
      Pkg.Add('license', APlan.License);
    if APlan.Homepage <> '' then
      Pkg.Add('homepage', APlan.Homepage);
    Pkg.Add('type', 'source');
    Pkg.Add('url', APlan.URL);
    if APlan.Sha256 <> '' then
      Pkg.Add('sha256', APlan.Sha256);

    DepArr := TJSONArray.Create;
    for I := 0 to High(APlan.Dependencies) do
      DepArr.Add(APlan.Dependencies[I]);
    Pkg.Add('dependencies', DepArr);

    Arr.Add(Pkg);

    SL.Text := RootObj.FormatJSON;
    SL.SaveToFile(APlan.IndexPath);

    JSONData.Free;

    if AOut <> nil then
      AOut.WriteLn(_Fmt(MSG_PKG_SOURCE_PUBLISH_OK, [
        APlan.PackageName, APlan.Version, APlan.IndexPath]));

    Result := 0;
  finally
    SL.Free;
  end;
end;

end.
