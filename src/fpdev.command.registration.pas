unit fpdev.command.registration;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.tree;

procedure RegisterCommandPathCore(
  const ARoot: TCommandNode;
  const APath: array of string;
  AFactory: TCommandFactory;
  const Aliases: array of string
);
procedure RegisterSingletonCommandPathCore(
  const ARoot: TCommandNode;
  const APath: array of string;
  const ACommand: ICommand;
  const Aliases: array of string
);

implementation

procedure RegisterCommandPathCore(
  const ARoot: TCommandNode;
  const APath: array of string;
  AFactory: TCommandFactory;
  const Aliases: array of string
);
var
  Index: Integer;
  Node: TCommandNode;
  AliasNode: TCommandNode;
begin
  Node := ARoot;
  for Index := Low(APath) to High(APath) do
    Node := Node.EnsureChild(LowerCase(APath[Index]));

  Node.Factory := AFactory;

  if Assigned(Node.Parent) then
    for Index := Low(Aliases) to High(Aliases) do
    begin
      AliasNode := Node.Parent.EnsureChild(LowerCase(Aliases[Index]));
      AliasNode.AliasTarget := Node;
      AliasNode.Factory := AFactory;
    end;
end;

procedure RegisterSingletonCommandPathCore(
  const ARoot: TCommandNode;
  const APath: array of string;
  const ACommand: ICommand;
  const Aliases: array of string
);
var
  Index: Integer;
  Node: TCommandNode;
  AliasNode: TCommandNode;
begin
  Node := ARoot;
  for Index := Low(APath) to High(APath) do
    Node := Node.EnsureChild(LowerCase(APath[Index]));

  Node.Command := ACommand;
  Node.Factory := nil;

  if Assigned(Node.Parent) then
    for Index := Low(Aliases) to High(Aliases) do
    begin
      AliasNode := Node.Parent.EnsureChild(LowerCase(Aliases[Index]));
      AliasNode.AliasTarget := Node;
      AliasNode.Command := ACommand;
      AliasNode.Factory := nil;
    end;
end;

end.
