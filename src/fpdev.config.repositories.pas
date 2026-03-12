unit fpdev.config.repositories;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson,
  fpdev.config.interfaces;

type
  TRepositoryManager = class(TInterfacedObject, IRepositoryManager)
  private
    FNotifier: IConfigChangeNotifier;
    FRepositories: TStringList;
    FDefaultRepo: string;
  public
    constructor Create(ANotifier: IConfigChangeNotifier);
    destructor Destroy; override;

    function AddRepository(const AName, AURL: string): Boolean;
    function RemoveRepository(const AName: string): Boolean;
    function GetRepository(const AName: string): string;
    function HasRepository(const AName: string): Boolean;
    function GetDefaultRepository: string;
    function ListRepositories: TStringArray;

    procedure Clear;
    procedure LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
    procedure SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
  end;

implementation

constructor TRepositoryManager.Create(ANotifier: IConfigChangeNotifier);
begin
  inherited Create;
  FNotifier := ANotifier;
  FRepositories := TStringList.Create;
  FDefaultRepo := '';
end;

destructor TRepositoryManager.Destroy;
begin
  FRepositories.Free;
  inherited;
end;

function TRepositoryManager.AddRepository(const AName, AURL: string): Boolean;
begin
  Result := False;
  try
    FRepositories.Values[AName] := AURL;
    if Assigned(FNotifier) then
      FNotifier.NotifyConfigChanged;
    Result := True;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TRepositoryManager.RemoveRepository(const AName: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  try
    Index := FRepositories.IndexOfName(AName);
    if Index >= 0 then
    begin
      FRepositories.Delete(Index);
      if Assigned(FNotifier) then
        FNotifier.NotifyConfigChanged;
      Result := True;
    end;
  except
    on E: Exception do
      { Error logged via return value }
  end;
end;

function TRepositoryManager.GetRepository(const AName: string): string;
begin
  Result := FRepositories.Values[AName];
end;

function TRepositoryManager.HasRepository(const AName: string): Boolean;
begin
  if Assigned(FRepositories) then
    Result := FRepositories.IndexOfName(AName) >= 0
  else
    Result := False;
end;

function TRepositoryManager.GetDefaultRepository: string;
begin
  Result := FDefaultRepo;
end;

function TRepositoryManager.ListRepositories: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(FRepositories) then
    Exit;
  SetLength(Result, FRepositories.Count);
  for I := 0 to FRepositories.Count - 1 do
    Result[I] := FRepositories.Names[I];
end;

procedure TRepositoryManager.Clear;
begin
  FRepositories.Clear;
  FDefaultRepo := '';
end;

procedure TRepositoryManager.LoadFromJSON(ARepos: TJSONObject; const ADefaultRepo: string);
var
  I: Integer;
  Key: string;
begin
  Clear;
  FDefaultRepo := ADefaultRepo;

  if Assigned(ARepos) then
  begin
    for I := 0 to ARepos.Count - 1 do
    begin
      Key := ARepos.Names[I];
      FRepositories.Values[Key] := ARepos.Strings[Key];
    end;
  end;
end;

procedure TRepositoryManager.SaveToJSON(out ARepos: TJSONObject; out ADefaultRepo: string);
var
  I: Integer;
  Key, Value: string;
begin
  ARepos := TJSONObject.Create;
  for I := 0 to FRepositories.Count - 1 do
  begin
    Key := FRepositories.Names[I];
    Value := FRepositories.ValueFromIndex[I];
    ARepos.Add(Key, Value);
  end;
  ADefaultRepo := FDefaultRepo;
end;

end.
