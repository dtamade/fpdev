unit fpdev.command.tree;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf;

type
  TCommandFactory = function: ICommand;

  TCommandNode = class
  public
    Name: string;
    Parent: TCommandNode;
    Children: TStringList;
    Factory: TCommandFactory;
    Command: ICommand;
    AliasTarget: TCommandNode;
    constructor Create(const AName: string);
    destructor Destroy; override;
    function FindChild(const AName: string): TCommandNode;
    function EnsureChild(const AName: string): TCommandNode;
    function GetEffectiveNode: TCommandNode;
  end;

implementation

constructor TCommandNode.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Children := TStringList.Create;
  Children.CaseSensitive := False;
  Children.Sorted := False;
  Children.Duplicates := dupIgnore;
  Factory := nil;
  Command := nil;
  AliasTarget := nil;
end;

destructor TCommandNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to Children.Count - 1 do
    TObject(Children.Objects[I]).Free;
  Children.Free;
  inherited Destroy;
end;

function TCommandNode.FindChild(const AName: string): TCommandNode;
var
  Index: Integer;
begin
  Index := Children.IndexOf(AName);
  if Index >= 0 then
    Result := TCommandNode(Children.Objects[Index])
  else
    Result := nil;
end;

function TCommandNode.EnsureChild(const AName: string): TCommandNode;
var
  Child: TCommandNode;
  Index: Integer;
begin
  Child := FindChild(AName);
  if Child <> nil then
    Exit(Child);

  Child := TCommandNode.Create(AName);
  Child.Parent := Self;
  Index := Children.Add(AName);
  Children.Objects[Index] := Child;
  Result := Child;
end;

function TCommandNode.GetEffectiveNode: TCommandNode;
begin
  if Assigned(AliasTarget) then
    Result := AliasTarget
  else
    Result := Self;
end;

end.
