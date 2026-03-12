unit fpdev.package.indexparser;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.package.types,
  fpdev.utils;

function ParseLocalPackageIndexCore(const AIndexPath: string): TPackageArray;

implementation

function ParseLocalPackageIndexCore(const AIndexPath: string): TPackageArray;
var
  JSONData: TJSONData = nil;
  Arr: TJSONArray;
  Obj: TJSONObject;
  i, j, Count: Integer;
  Pkg: TPackageInfo;
  Names: TStringList;
  U: TJSONData;
  K: Integer;

  function TryGetArray(AData: TJSONData): TJSONArray;
  begin
    Result := nil;
    if AData = nil then Exit(nil);
    if AData.JSONType = jtArray then Exit(TJSONArray(AData));
    if (AData.JSONType = jtObject) and Assigned(TJSONObject(AData).Arrays['packages']) then
      Exit(TJSONObject(AData).Arrays['packages']);
  end;

  function HasValidURL(AObj: TJSONObject): Boolean;
  var
    UrlData: TJSONData;
  begin
    UrlData := AObj.Find('url');
    if not Assigned(UrlData) then Exit(False);
    if (UrlData.JSONType = jtString) and (AObj.Get('url', '') = '') then Exit(False);
    if (UrlData.JSONType = jtArray) and (TJSONArray(UrlData).Count = 0) then Exit(False);
    Result := True;
  end;

begin
  Initialize(Result);
  SetLength(Result, 0);

  if not FileExists(AIndexPath) then Exit;

  try
    with TStringList.Create do
    try
      LoadFromFile(AIndexPath);
      JSONData := GetJSON(Text);
    finally
      Free;
    end;

    Arr := TryGetArray(JSONData);
    if Arr = nil then Exit;

    Names := TStringList.Create;
    try
      Initialize(Pkg);
      Names.Sorted := True;
      Names.Duplicates := dupIgnore;
      Names.CaseSensitive := False;

      for i := 0 to Arr.Count - 1 do
      begin
        if (Arr.Items[i].JSONType <> jtObject) then Continue;
        Obj := TJSONObject(Arr.Items[i]);
        if Obj.Get('name', '') = '' then Continue;
        if Obj.Get('version', '') = '' then Continue;
        if not HasValidURL(Obj) then Continue;
        Names.Add(Obj.Get('name', ''));
      end;

      Count := 0;
      SetLength(Result, Names.Count);
      for i := 0 to Names.Count - 1 do
      begin
        Finalize(Pkg);
        Initialize(Pkg);
        for j := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[j].JSONType <> jtObject then Continue;
          Obj := TJSONObject(Arr.Items[j]);
          if not SameText(Obj.Get('name', ''), Names[i]) then Continue;
          if Obj.Get('version', '') = '' then Continue;
          if not HasValidURL(Obj) then Continue;

          if (Pkg.Name = '') or IsVersionHigher(Obj.Get('version', ''), Pkg.Version) then
          begin
            Pkg.Name := Obj.Get('name', '');
            Pkg.Version := Obj.Get('version', '');
            Pkg.Description := Obj.Get('description', '');
            Pkg.Homepage := Obj.Get('homepage', '');
            Pkg.License := Obj.Get('license', '');
            Pkg.Repository := Obj.Get('repository', '');
            Pkg.Sha256 := Obj.Get('sha256', '');
            SetLength(Pkg.URLs, 0);
            U := Obj.Find('url');
            if Assigned(U) then
            begin
              if U.JSONType = jtString then
              begin
                SetLength(Pkg.URLs, 1);
                Pkg.URLs[0] := U.AsString;
              end
              else if U.JSONType = jtArray then
              begin
                SetLength(Pkg.URLs, TJSONArray(U).Count);
                for K := 0 to TJSONArray(U).Count - 1 do
                  Pkg.URLs[K] := TJSONArray(U).Items[K].AsString;
              end;
            end;
          end;
        end;
        if (Pkg.Name <> '') then
        begin
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
    finally
      Finalize(Pkg);
      Names.Free;
    end;
  finally
    if Assigned(JSONData) then JSONData.Free;
  end;
end;

end.
