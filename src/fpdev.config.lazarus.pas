unit fpdev.config.lazarus;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config.interfaces;

type
  TLazarusManager = class(TInterfacedObject, ILazarusManager)
  private
    FNotifier: IConfigChangeNotifier;
    FVersions: TStringList;
    FDefaultVersion: string;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
    function RemoveLazarusVersion(const AName: string): Boolean;
    function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
    function SetDefaultLazarusVersion(const AName: string): Boolean;
    function GetDefaultLazarusVersion: string;
    function ListLazarusVersions: TStringArray;

    procedure Clear;
    procedure LoadFromJSON(ALazarus: TJSONObject);
    procedure SaveToJSON(out ALazarus: TJSONObject);
  end;

implementation

uses
  fpdev.config.codec;

constructor TLazarusManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FVersions := TStringList.Create;
  FDefaultVersion := '';
end;

destructor TLazarusManager.Destroy;
begin
  FVersions.Free;
  inherited;
end;

function TLazarusManager.AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := ConfigLazarusInfoToJSON(AInfo);
    try
      FVersions.Values[AName] := JSONObj.AsJSON;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    finally
      JSONObj.Free;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.RemoveLazarusVersion(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FVersions.IndexOfName(AName);
    if Index >= 0 then
    begin
      FVersions.Delete(Index);
      if SameText(FDefaultVersion, AName) then
        FDefaultVersion := '';
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  AInfo := Default(TLazarusInfo);

  try
    JSONStr := FVersions.Values[AName];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := ConfigJSONToLazarusInfo(TJSONObject(JSONData));
          Result := True;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.SetDefaultLazarusVersion(const AName: string): Boolean;
begin
  Result := False;
  try
    if FVersions.IndexOfName(AName) >= 0 then
    begin
      FDefaultVersion := AName;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TLazarusManager.GetDefaultLazarusVersion: string;
begin
  Result := FDefaultVersion;
end;

function TLazarusManager.ListLazarusVersions: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(FVersions) then
    Exit;
  SetLength(Result, FVersions.Count);
  for I := 0 to FVersions.Count - 1 do
    Result[I] := FVersions.Names[I];
end;

procedure TLazarusManager.Clear;
begin
  FVersions.Clear;
  FDefaultVersion := '';
end;

procedure TLazarusManager.LoadFromJSON(ALazarus: TJSONObject);
var
  VersionsJSON: TJSONObject;
  I: Integer;
  Key: string;
begin
  Clear;

  if Assigned(ALazarus) then
  begin
    FDefaultVersion := ALazarus.Get('default_version', '');
    VersionsJSON := ALazarus.Objects['versions'];
    if Assigned(VersionsJSON) then
    begin
      for I := 0 to VersionsJSON.Count - 1 do
      begin
        Key := VersionsJSON.Names[I];
        FVersions.Values[Key] := VersionsJSON.Items[I].AsJSON;
      end;
    end;

    if (FDefaultVersion <> '') and (FVersions.IndexOfName(FDefaultVersion) < 0) then
      FDefaultVersion := '';
  end;
end;

procedure TLazarusManager.SaveToJSON(out ALazarus: TJSONObject);
var
  VersionsJSON: TJSONObject;
  I: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  ALazarus := TJSONObject.Create;
  ALazarus.Add('default_version', FDefaultVersion);

  VersionsJSON := TJSONObject.Create;
  for I := 0 to FVersions.Count - 1 do
  begin
    Key := FVersions.Names[I];
    Value := FVersions.ValueFromIndex[I];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      VersionsJSON.Add(Key, JSONData);
    end;
  end;
  ALazarus.Add('versions', VersionsJSON);
end;

end.
