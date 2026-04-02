unit fpdev.config.toolchains;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config.interfaces;

type
  TToolchainManager = class(TInterfacedObject, IToolchainManager)
  private
    FNotifier: IConfigChangeNotifier;
    FToolchains: TStringList;
    FDefaultToolchain: string;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function RemoveToolchain(const AName: string): Boolean;
    function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
    function SetDefaultToolchain(const AName: string): Boolean;
    function GetDefaultToolchain: string;
    function ListToolchains: TStringArray;

    procedure Clear;
    procedure LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
    procedure SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
  end;

implementation

uses
  fpdev.config.codec;

constructor TToolchainManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FToolchains := TStringList.Create;
  FDefaultToolchain := '';
end;

destructor TToolchainManager.Destroy;
begin
  FToolchains.Free;
  inherited;
end;

function TToolchainManager.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := ConfigToolchainInfoToJSON(AInfo);
    try
      FToolchains.Values[AName] := JSONObj.AsJSON;
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

function TToolchainManager.RemoveToolchain(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FToolchains.IndexOfName(AName);
    if Index >= 0 then
    begin
      FToolchains.Delete(Index);
      if SameText(FDefaultToolchain, AName) then
        FDefaultToolchain := '';
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TToolchainManager.GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  AInfo := Default(TToolchainInfo);

  try
    JSONStr := FToolchains.Values[AName];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := ConfigJSONToToolchainInfo(TJSONObject(JSONData));
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

function TToolchainManager.SetDefaultToolchain(const AName: string): Boolean;
begin
  Result := False;
  try
    if FToolchains.IndexOfName(AName) >= 0 then
    begin
      FDefaultToolchain := AName;
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TToolchainManager.GetDefaultToolchain: string;
begin
  Result := FDefaultToolchain;
end;

function TToolchainManager.ListToolchains: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(FToolchains) then
    Exit;
  SetLength(Result, FToolchains.Count);
  for I := 0 to FToolchains.Count - 1 do
    Result[I] := FToolchains.Names[I];
end;

procedure TToolchainManager.Clear;
begin
  FToolchains.Clear;
  FDefaultToolchain := '';
end;

procedure TToolchainManager.LoadFromJSON(AToolchains: TJSONObject; const ADefaultToolchain: string);
var
  I: Integer;
  Key: string;
begin
  Clear;
  FDefaultToolchain := ADefaultToolchain;

  if Assigned(AToolchains) then
  begin
    for I := 0 to AToolchains.Count - 1 do
    begin
      Key := AToolchains.Names[I];
      FToolchains.Values[Key] := AToolchains.Items[I].AsJSON;
    end;
  end;

  if (FDefaultToolchain <> '') and (FToolchains.IndexOfName(FDefaultToolchain) < 0) then
    FDefaultToolchain := '';
end;

procedure TToolchainManager.SaveToJSON(out AToolchains: TJSONObject; out ADefaultToolchain: string);
var
  I: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  AToolchains := TJSONObject.Create;
  for I := 0 to FToolchains.Count - 1 do
  begin
    Key := FToolchains.Names[I];
    Value := FToolchains.ValueFromIndex[I];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      AToolchains.Add(Key, JSONData);
    end;
  end;
  ADefaultToolchain := FDefaultToolchain;
end;

end.
