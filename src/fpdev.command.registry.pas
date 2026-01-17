unit fpdev.command.registry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf;

type
  TCommandFactory = function: ICommand;

  { TCommandNode }
  TCommandNode = class
  public
    Name: string;
    Parent: TCommandNode;
    Children: TStringList; // name -> TObject(TCommandNode)
    Factory: TCommandFactory;
    Command: ICommand;
    AliasTarget: TCommandNode;  // If set, this node is an alias to another node
    constructor Create(const AName: string);
    destructor Destroy; override;
    function FindChild(const AName: string): TCommandNode;
    function EnsureChild(const AName: string): TCommandNode;
    function GetEffectiveNode: TCommandNode;  // Returns AliasTarget if set, else Self
  end;

type
  { TCommandRegistry }
  TCommandRegistry = class
  private
    FRoot: TCommandNode;    // path-based root
  public
    constructor Create;
    destructor Destroy; override;
    // Single-level API
    procedure Register(const ACmd: ICommand);
    function Resolve(const AName: string): ICommand;
    function Dispatch(const AArgs: array of string; const Ctx: IContext): Integer; reintroduce;
    // Path-based API
    procedure RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
    function DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
    // List subcommand names under specified path; empty path means root
    function ListChildren(const APath: array of string): TStringArray;
  end;

function GlobalCommandRegistry: TCommandRegistry;

implementation

{ TCommandNode }

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
var i: Integer;
begin
  for i := 0 to Children.Count-1 do
    TObject(Children.Objects[i]).Free;
  Children.Free;
  inherited Destroy;
end;

function TCommandNode.FindChild(const AName: string): TCommandNode;
var idx: Integer;
begin
  idx := Children.IndexOf(AName);
  if idx >= 0 then
    Result := TCommandNode(Children.Objects[idx])
  else
    Result := nil;
end;

function TCommandNode.EnsureChild(const AName: string): TCommandNode;
var C: TCommandNode; idx: Integer;
begin
  C := FindChild(AName);
  if C <> nil then Exit(C);
  C := TCommandNode.Create(AName);
  C.Parent := Self;
  idx := Children.Add(AName);
  Children.Objects[idx] := C;
  Result := C;
end;

function TCommandNode.GetEffectiveNode: TCommandNode;
begin
  if Assigned(AliasTarget) then
    Result := AliasTarget
  else
    Result := Self;
end;

var
  GRegistry: TCommandRegistry = nil;

{ Calculate Levenshtein distance between two strings for fuzzy matching }
function LevenshteinDistance(const S1, S2: string): Integer;
var
  D: array of array of Integer;
  I, J, Cost: Integer;
  Len1, Len2: Integer;
begin
  Len1 := Length(S1);
  Len2 := Length(S2);

  // Handle edge cases
  if Len1 = 0 then Exit(Len2);
  if Len2 = 0 then Exit(Len1);

  // Initialize distance matrix
  SetLength(D, Len1 + 1, Len2 + 1);

  for I := 0 to Len1 do
    D[I, 0] := I;
  for J := 0 to Len2 do
    D[0, J] := J;

  // Calculate distances
  for I := 1 to Len1 do
    for J := 1 to Len2 do
    begin
      if LowerCase(S1[I]) = LowerCase(S2[J]) then
        Cost := 0
      else
        Cost := 1;

      D[I, J] := D[I - 1, J] + 1;  // Deletion
      if D[I, J - 1] + 1 < D[I, J] then
        D[I, J] := D[I, J - 1] + 1;  // Insertion
      if D[I - 1, J - 1] + Cost < D[I, J] then
        D[I, J] := D[I - 1, J - 1] + Cost;  // Substitution
    end;

  Result := D[Len1, Len2];
end;

{ Find the most similar command from available commands }
function FindSimilarCommand(const AInput: string; const ACommands: TStringArray): string;
var
  I, Dist, MinDist: Integer;
  BestMatch: string;
  MaxDist: Integer;
begin
  Result := '';
  if Length(ACommands) = 0 then Exit;

  BestMatch := '';
  MinDist := MaxInt;

  // Maximum distance threshold: allow up to 40% of the input length or 3 chars
  MaxDist := Length(AInput) * 2 div 5;
  if MaxDist < 2 then MaxDist := 2;
  if MaxDist > 4 then MaxDist := 4;

  for I := 0 to High(ACommands) do
  begin
    Dist := LevenshteinDistance(AInput, ACommands[I]);
    if (Dist < MinDist) and (Dist <= MaxDist) then
    begin
      MinDist := Dist;
      BestMatch := ACommands[I];
    end;
  end;

  Result := BestMatch;
end;

{ TCommandRegistry }

constructor TCommandRegistry.Create;
begin
  inherited Create;
  FRoot := TCommandNode.Create('');
end;

destructor TCommandRegistry.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;
procedure TCommandRegistry.RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
var
  i: Integer;
  Node, AliasNode: TCommandNode;
begin
  Node := FRoot;
  for i := Low(APath) to High(APath) do
    Node := Node.EnsureChild(LowerCase(APath[i]));
  Node.Factory := AFactory;
  // 别名注册为同级子节点，指向原节点（支持命名空间别名）
  if Assigned(Node.Parent) then
    for i := Low(Aliases) to High(Aliases) do
    begin
      AliasNode := Node.Parent.EnsureChild(LowerCase(Aliases[i]));
      AliasNode.AliasTarget := Node;
      AliasNode.Factory := AFactory;
    end;
end;

function TCommandRegistry.DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
var
  i, ExecIndex: Integer;
  Node, Child, LastNode, MatchedNode, EffNode, ParentNode: TCommandNode;
  Rest: array of string;
  Cmd: ICommand;
  j: Integer;
  SubCmds: TStringArray;
  Suggestion, UnknownCmd: string;
begin
  Result := 0;
  Rest := nil;
  Node := FRoot;
  LastNode := nil;
  MatchedNode := nil;
  ParentNode := nil;
  ExecIndex := 0;
  // Longest executable prefix matching: match to the nearest node with Factory, rest as parameters
  i := 0;
  while (i <= High(AArgs)) and (Node <> nil) do
  begin
    if (i > High(AArgs)) or (AArgs[i] = '') then Break;
    Child := Node.FindChild(LowerCase(AArgs[i]));
    if Child = nil then
    begin
      // Command not found at this level - save context for suggestion
      ParentNode := Node;
      UnknownCmd := AArgs[i];
      Break;
    end;
    // If it's an alias node, use its target node
    Node := Child.GetEffectiveNode;
    MatchedNode := Node;  // Track the last matched node
    Inc(i);
    if Assigned(Node.Factory) then
    begin
      LastNode := Node;
      ExecIndex := i; // Parameter start index after execution point
    end;
  end;

  if (LastNode <> nil) then
  begin
    if Assigned(LastNode.Command) then
      Cmd := LastNode.Command
    else
      Cmd := LastNode.Factory();
    SetLength(Rest, Length(AArgs) - ExecIndex);
    for j := 0 to High(Rest) do
      Rest[j] := AArgs[ExecIndex + j];
    Result := Cmd.Execute(Rest, Ctx);
    if Result = 0 then
      Ctx.SaveIfModified;
  end
  else if (ParentNode <> nil) and (UnknownCmd <> '') then
  begin
    // Command not found - try to suggest a similar command (prioritize over showing subcommands)
    SubCmds := nil;
    SetLength(SubCmds, ParentNode.Children.Count);
    for j := 0 to ParentNode.Children.Count - 1 do
      SubCmds[j] := ParentNode.Children[j];

    Suggestion := FindSimilarCommand(UnknownCmd, SubCmds);
    if Suggestion <> '' then
    begin
      Ctx.Err.WriteLn('Unknown command: ' + UnknownCmd);
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Did you mean "' + Suggestion + '"?');
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Run "fpdev help" for available commands.');
    end
    else
    begin
      // No similar command found, show available subcommands
      Ctx.Err.WriteLn('Unknown command: ' + UnknownCmd);
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Available commands:');
      for j := 0 to High(SubCmds) do
        Ctx.Err.WriteLn('  ' + SubCmds[j]);
    end;
    Result := 1;
  end
  else if (MatchedNode <> nil) then
  begin
    // Get effective node (may be alias target)
    EffNode := MatchedNode.GetEffectiveNode;
    if EffNode.Children.Count > 0 then
    begin
      // Node matched but has no factory - show available subcommands
      Ctx.Out.WriteLn('Usage: fpdev ' + EffNode.Name + ' <command>');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Available commands:');
      SubCmds := nil;
      SetLength(SubCmds, EffNode.Children.Count);
      for j := 0 to EffNode.Children.Count - 1 do
        SubCmds[j] := EffNode.Children[j];
      for j := 0 to High(SubCmds) do
        Ctx.Out.WriteLn('  ' + SubCmds[j]);
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Use "fpdev ' + EffNode.Name + ' <command> --help" for more information.');
      Result := 0;
    end
    else
      Result := 1;
  end
  else
  begin
    // No match found: return non-zero, let upper layer output help/error
    Result := 1;
  end;
end;

function TCommandRegistry.ListChildren(const APath: array of string): TStringArray;
var
  Node: TCommandNode;
  i: Integer;
begin
  Result := nil;
  Node := FRoot;
  for i := Low(APath) to High(APath) do
  begin
    if (APath[i] = '') then Continue;
    Node := Node.FindChild(LowerCase(APath[i]));
    if Node = nil then
    begin
      SetLength(Result, 0);
      Exit;
    end;
  end;
  if (Node <> nil) and (Node.Children.Count > 0) then
  begin
    SetLength(Result, Node.Children.Count);
    for i := 0 to Node.Children.Count-1 do
      Result[i] := Node.Children[i];
  end
  else
    SetLength(Result, 0);
end;


procedure TCommandRegistry.Register(const ACmd: ICommand);
var
  i: Integer;
  LNames: TStringArray;
  Node: TCommandNode;
begin
  if ACmd = nil then Exit;
  // 主名
  Node := FRoot.EnsureChild(LowerCase(ACmd.Name));
  Node.Command := ACmd;
  // 别名
  LNames := ACmd.Aliases;
  for i := 0 to High(LNames) do
  begin
    Node := FRoot.EnsureChild(LowerCase(LNames[i]));
    Node.Command := ACmd;
  end;
end;

function TCommandRegistry.Resolve(const AName: string): ICommand;
var
  Node: TCommandNode;
begin
  Result := nil;
  Node := FRoot.FindChild(LowerCase(AName));
  if Node = nil then Exit;
  if Assigned(Node.Command) then
    Exit(Node.Command);
  if Assigned(Node.Factory) then
    Exit(Node.Factory());
end;
function TCommandRegistry.Dispatch(const AArgs: array of string; const Ctx: IContext): Integer;
begin
  // 兼容旧接口：直接走路径分发
  Result := DispatchPath(AArgs, Ctx);
end;

function GlobalCommandRegistry: TCommandRegistry;
begin
  if GRegistry = nil then
    GRegistry := TCommandRegistry.Create;
  Result := GRegistry;
end;

finalization
  GRegistry.Free;

end.

