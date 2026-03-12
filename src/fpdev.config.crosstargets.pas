unit fpdev.config.crosstargets;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config.interfaces;

type
  TCrossTargetManager = class(TInterfacedObject, ICrossTargetManager)
  private
    FNotifier: IConfigChangeNotifier;
    FCrossTargets: TStringList;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RemoveCrossTarget(const ATarget: string): Boolean;
    function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function ListCrossTargets: TStringArray;

    procedure Clear;
    procedure LoadFromJSON(ACrossTargets: TJSONObject);
    procedure SaveToJSON(out ACrossTargets: TJSONObject);
  end;

implementation

uses
  fpdev.config.codec;

constructor TCrossTargetManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FCrossTargets := TStringList.Create;
end;

destructor TCrossTargetManager.Destroy;
begin
  FCrossTargets.Free;
  inherited;
end;

function TCrossTargetManager.AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
var
  JSONObj: TJSONObject;
begin
  Result := False;
  try
    JSONObj := ConfigCrossTargetToJSON(AInfo);
    try
      FCrossTargets.Values[ATarget] := JSONObj.AsJSON;
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

function TCrossTargetManager.RemoveCrossTarget(const ATarget: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FCrossTargets.IndexOfName(ATarget);
    if Index >= 0 then
    begin
      FCrossTargets.Delete(Index);
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TCrossTargetManager.GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
begin
  Result := False;
  AInfo := Default(TCrossTarget);

  try
    JSONStr := FCrossTargets.Values[ATarget];
    if JSONStr <> '' then
    begin
      JSONData := GetJSON(JSONStr);
      try
        if JSONData is TJSONObject then
        begin
          AInfo := ConfigJSONToCrossTarget(TJSONObject(JSONData));
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

function TCrossTargetManager.ListCrossTargets: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(FCrossTargets) then
    Exit;
  SetLength(Result, FCrossTargets.Count);
  for I := 0 to FCrossTargets.Count - 1 do
    Result[I] := FCrossTargets.Names[I];
end;

procedure TCrossTargetManager.Clear;
begin
  FCrossTargets.Clear;
end;

procedure TCrossTargetManager.LoadFromJSON(ACrossTargets: TJSONObject);
var
  I: Integer;
  Key: string;
begin
  Clear;

  if Assigned(ACrossTargets) then
  begin
    for I := 0 to ACrossTargets.Count - 1 do
    begin
      Key := ACrossTargets.Names[I];
      FCrossTargets.Values[Key] := ACrossTargets.Items[I].AsJSON;
    end;
  end;
end;

procedure TCrossTargetManager.SaveToJSON(out ACrossTargets: TJSONObject);
var
  I: Integer;
  Key, Value: string;
  JSONData: TJSONData;
begin
  ACrossTargets := TJSONObject.Create;
  for I := 0 to FCrossTargets.Count - 1 do
  begin
    Key := FCrossTargets.Names[I];
    Value := FCrossTargets.ValueFromIndex[I];
    if Value <> '' then
    begin
      JSONData := GetJSON(Value);
      ACrossTargets.Add(Key, JSONData);
    end;
  end;
end;

end.
