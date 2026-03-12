unit fpdev.command.lookup;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.tree;

type
  TCommandDispatchLookup = record
    LastNode: TCommandNode;
    MatchedNode: TCommandNode;
    ParentNode: TCommandNode;
    ExecIndex: Integer;
    UnknownCmd: string;
  end;

function HasCommandAtPathCore(const ARoot: TCommandNode; const APath: TStringArray): Boolean;
function FindNodeAtPathCore(const ARoot: TCommandNode; const APath: TStringArray): TCommandNode;
function MatchExecutablePrefixCore(
  const ARoot: TCommandNode;
  const AArgs: TStringArray;
  out AMatch: TCommandDispatchLookup
): Boolean;
function ListChildrenAtPathCore(const ARoot: TCommandNode; const APath: array of string): TStringArray;

implementation

function FindNodeAtPathCore(const ARoot: TCommandNode; const APath: TStringArray): TCommandNode;
var
  Node: TCommandNode;
  Index: Integer;
  Part: string;
begin
  Node := ARoot;
  for Index := 0 to High(APath) do
  begin
    Part := APath[Index];
    if Part = '' then
      Continue;
    Node := Node.FindChild(LowerCase(Part));
    if Node = nil then
      Exit(nil);
    Node := Node.GetEffectiveNode;
  end;
  Result := Node;
end;

function HasCommandAtPathCore(const ARoot: TCommandNode; const APath: TStringArray): Boolean;
var
  Node: TCommandNode;
begin
  Node := FindNodeAtPathCore(ARoot, APath);
  Result := (Node <> nil) and (Assigned(Node.Factory) or Assigned(Node.Command));
end;

function MatchExecutablePrefixCore(
  const ARoot: TCommandNode;
  const AArgs: TStringArray;
  out AMatch: TCommandDispatchLookup
): Boolean;
var
  Index: Integer;
  Node: TCommandNode;
  Child: TCommandNode;
begin
  AMatch := Default(TCommandDispatchLookup);
  Node := ARoot;
  AMatch.ExecIndex := 0;

  Index := 0;
  while (Index <= High(AArgs)) and (Node <> nil) do
  begin
    if (Index > High(AArgs)) or (AArgs[Index] = '') then
      Break;

    Child := Node.FindChild(LowerCase(AArgs[Index]));
    if Child = nil then
    begin
      AMatch.ParentNode := Node;
      AMatch.UnknownCmd := AArgs[Index];
      Break;
    end;

    Node := Child.GetEffectiveNode;
    AMatch.MatchedNode := Node;
    Inc(Index);
    if Assigned(Node.Factory) then
    begin
      AMatch.LastNode := Node;
      AMatch.ExecIndex := Index;
    end;
  end;

  if (AMatch.LastNode = nil) and (AMatch.UnknownCmd = '') and
     (AMatch.MatchedNode <> nil) and Assigned(AMatch.MatchedNode.Command) then
  begin
    AMatch.LastNode := AMatch.MatchedNode;
    AMatch.ExecIndex := Length(AArgs);
  end;

  Result := Assigned(AMatch.LastNode);
end;

function ListChildrenAtPathCore(const ARoot: TCommandNode; const APath: array of string): TStringArray;
var
  Node: TCommandNode;
  Index: Integer;
begin
  Result := nil;
  Node := ARoot;
  for Index := Low(APath) to High(APath) do
  begin
    if APath[Index] = '' then
      Continue;
    Node := Node.FindChild(LowerCase(APath[Index]));
    if Node = nil then
    begin
      SetLength(Result, 0);
      Exit;
    end;
  end;

  if (Node <> nil) and (Node.Children.Count > 0) then
  begin
    SetLength(Result, Node.Children.Count);
    for Index := 0 to Node.Children.Count - 1 do
      Result[Index] := Node.Children[Index];
  end
  else
    SetLength(Result, 0);
end;

end.
