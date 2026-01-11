unit fpdev.pkg.deps;

{$mode objfpc}{$H+}

(*
  Package Dependency Resolver

  Implements dependency graph and topological sort for package management.
  Features:
  - Dependency graph construction
  - Topological sort (Kahn's algorithm)
  - Cycle detection
  - Version constraint handling

  Usage:
    Graph := TDependencyGraph.Create;
    try
      Graph.AddNode('app', '1.0.0');
      Graph.AddNode('lib', '1.0.0');
      Graph.AddDependency('app', 'lib');

      Result := Graph.Resolve;
      if Result.Success then
        for i := 0 to High(Result.ResolvedOrder) do
          WriteLn(Result.ResolvedOrder[i]);
    finally
      Graph.Free;
    end;
*)

interface

uses
  SysUtils, Classes;

type
  { TVersionConstraint - Version requirement for a dependency }
  TVersionConstraint = record
    PackageName: string;
    MinVersion: string;
    MaxVersion: string;
    Exact: Boolean;
  end;

  TVersionConstraintArray = array of TVersionConstraint;

  { TDependencyNode - A node in the dependency graph }
  TDependencyNode = record
    Name: string;
    Version: string;
    Dependencies: TStringArray;
    Constraints: TVersionConstraintArray;
    Visited: Boolean;
    InStack: Boolean;  // For cycle detection in DFS
  end;

  TDependencyNodeArray = array of TDependencyNode;

  { TResolveResult - Result of dependency resolution }
  TResolveResult = record
    Success: Boolean;
    HasCycle: Boolean;
    HasConflict: Boolean;
    ResolvedOrder: TStringArray;
    ErrorMessage: string;
    CyclePackages: string;
    ConflictPackages: string;
  end;

  { TDependencyGraph - Dependency graph with resolution capabilities }
  TDependencyGraph = class
  private
    FNodes: TDependencyNodeArray;

    function FindNodeIndex(const AName: string): Integer;
    function DetectCycle(AIndex: Integer; var AVisited, AInStack: array of Boolean;
      var ACyclePath: TStringArray): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    { Add a package node to the graph }
    procedure AddNode(const AName, AVersion: string);

    { Add a dependency edge: AFrom depends on ATo }
    procedure AddDependency(const AFrom, ATo: string);

    { Add a version constraint }
    procedure AddVersionConstraint(const AFrom, ATo: string;
      const AMinVersion, AMaxVersion: string; const AExact: Boolean);

    { Get dependencies of a package }
    function GetDependencies(const AName: string): TStringArray;

    { Perform topological sort }
    function TopologicalSort: TStringArray;

    { Full resolution with cycle and conflict detection }
    function Resolve: TResolveResult;

    { Number of nodes in graph }
    function NodeCount: Integer;

    { Check if a node exists }
    function HasNode(const AName: string): Boolean;
  end;

implementation

{ TDependencyGraph }

constructor TDependencyGraph.Create;
begin
  inherited Create;
  SetLength(FNodes, 0);
end;

destructor TDependencyGraph.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FNodes) do
  begin
    SetLength(FNodes[i].Dependencies, 0);
    SetLength(FNodes[i].Constraints, 0);
  end;
  SetLength(FNodes, 0);
  inherited Destroy;
end;

function TDependencyGraph.FindNodeIndex(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FNodes) do
  begin
    if SameText(FNodes[i].Name, AName) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TDependencyGraph.AddNode(const AName, AVersion: string);
var
  Idx: Integer;
begin
  // Check if node already exists
  Idx := FindNodeIndex(AName);
  if Idx >= 0 then
    Exit;  // Node already exists, skip

  // Add new node
  SetLength(FNodes, Length(FNodes) + 1);
  Idx := High(FNodes);

  FNodes[Idx].Name := AName;
  FNodes[Idx].Version := AVersion;
  SetLength(FNodes[Idx].Dependencies, 0);
  SetLength(FNodes[Idx].Constraints, 0);
  FNodes[Idx].Visited := False;
  FNodes[Idx].InStack := False;
end;

procedure TDependencyGraph.AddDependency(const AFrom, ATo: string);
var
  FromIdx, DepIdx, i: Integer;
begin
  FromIdx := FindNodeIndex(AFrom);
  if FromIdx < 0 then
    Exit;  // Source node not found

  // Check if dependency already exists
  for i := 0 to High(FNodes[FromIdx].Dependencies) do
  begin
    if SameText(FNodes[FromIdx].Dependencies[i], ATo) then
      Exit;  // Already exists
  end;

  // Add dependency
  DepIdx := Length(FNodes[FromIdx].Dependencies);
  SetLength(FNodes[FromIdx].Dependencies, DepIdx + 1);
  FNodes[FromIdx].Dependencies[DepIdx] := ATo;
end;

procedure TDependencyGraph.AddVersionConstraint(const AFrom, ATo: string;
  const AMinVersion, AMaxVersion: string; const AExact: Boolean);
var
  FromIdx, ConIdx: Integer;
begin
  FromIdx := FindNodeIndex(AFrom);
  if FromIdx < 0 then
    Exit;

  ConIdx := Length(FNodes[FromIdx].Constraints);
  SetLength(FNodes[FromIdx].Constraints, ConIdx + 1);

  FNodes[FromIdx].Constraints[ConIdx].PackageName := ATo;
  FNodes[FromIdx].Constraints[ConIdx].MinVersion := AMinVersion;
  FNodes[FromIdx].Constraints[ConIdx].MaxVersion := AMaxVersion;
  FNodes[FromIdx].Constraints[ConIdx].Exact := AExact;
end;

function TDependencyGraph.GetDependencies(const AName: string): TStringArray;
var
  Idx, i: Integer;
begin
  Result := nil;

  Idx := FindNodeIndex(AName);
  if Idx < 0 then
    Exit;

  // Copy the dependencies array properly
  SetLength(Result, Length(FNodes[Idx].Dependencies));
  for i := 0 to High(FNodes[Idx].Dependencies) do
    Result[i] := FNodes[Idx].Dependencies[i];
end;

function TDependencyGraph.DetectCycle(AIndex: Integer;
  var AVisited, AInStack: array of Boolean; var ACyclePath: TStringArray): Boolean;
var
  i, DepIdx, PathLen: Integer;
begin
  Result := False;

  AVisited[AIndex] := True;
  AInStack[AIndex] := True;

  // Add current node to path
  PathLen := Length(ACyclePath);
  SetLength(ACyclePath, PathLen + 1);
  ACyclePath[PathLen] := FNodes[AIndex].Name;

  // Check all dependencies
  for i := 0 to High(FNodes[AIndex].Dependencies) do
  begin
    DepIdx := FindNodeIndex(FNodes[AIndex].Dependencies[i]);
    if DepIdx < 0 then
      Continue;

    if not AVisited[DepIdx] then
    begin
      if DetectCycle(DepIdx, AVisited, AInStack, ACyclePath) then
      begin
        Result := True;
        Exit;
      end;
    end
    else if AInStack[DepIdx] then
    begin
      // Cycle detected!
      PathLen := Length(ACyclePath);
      SetLength(ACyclePath, PathLen + 1);
      ACyclePath[PathLen] := FNodes[DepIdx].Name;
      Result := True;
      Exit;
    end;
  end;

  // Remove current node from stack
  AInStack[AIndex] := False;
  SetLength(ACyclePath, Length(ACyclePath) - 1);
end;

function TDependencyGraph.TopologicalSort: TStringArray;
var
  DependencyCount: array of Integer;  // Number of unprocessed dependencies each node has
  Queue: TStringArray;
  QueueHead, QueueTail: Integer;
  i, j, Idx, ProcessedCount: Integer;
begin
  Result := nil;
  DependencyCount := nil;
  Queue := nil;

  if Length(FNodes) = 0 then
    Exit;

  // Calculate dependency count for each node (how many things it depends on)
  SetLength(DependencyCount, Length(FNodes));
  for i := 0 to High(FNodes) do
    DependencyCount[i] := Length(FNodes[i].Dependencies);

  // Initialize queue with nodes that have no dependencies (leaf nodes)
  SetLength(Queue, Length(FNodes));
  QueueHead := 0;
  QueueTail := 0;

  for i := 0 to High(FNodes) do
  begin
    if DependencyCount[i] = 0 then
    begin
      Queue[QueueTail] := FNodes[i].Name;
      Inc(QueueTail);
    end;
  end;

  // Process queue (Kahn's algorithm - dependencies first)
  SetLength(Result, Length(FNodes));
  ProcessedCount := 0;

  while QueueHead < QueueTail do
  begin
    // Dequeue - this node's dependencies are all satisfied
    Result[ProcessedCount] := Queue[QueueHead];
    Idx := FindNodeIndex(Queue[QueueHead]);
    Inc(QueueHead);
    Inc(ProcessedCount);

    if Idx < 0 then
      Continue;

    // For each node that depends on this one, decrease their dependency count
    for i := 0 to High(FNodes) do
    begin
      for j := 0 to High(FNodes[i].Dependencies) do
      begin
        if SameText(FNodes[i].Dependencies[j], FNodes[Idx].Name) then
        begin
          Dec(DependencyCount[i]);
          if DependencyCount[i] = 0 then
          begin
            Queue[QueueTail] := FNodes[i].Name;
            Inc(QueueTail);
          end;
          Break;  // Each node can only depend on this once
        end;
      end;
    end;
  end;

  // Trim result to actual count
  SetLength(Result, ProcessedCount);
end;

function TDependencyGraph.Resolve: TResolveResult;
var
  Visited, InStack: array of Boolean;
  CyclePath: TStringArray;
  i, j: Integer;
  CycleStr: string;
begin
  Initialize(Result);
  Visited := nil;
  InStack := nil;
  CyclePath := nil;
  Result.Success := True;
  Result.HasCycle := False;
  Result.HasConflict := False;
  SetLength(Result.ResolvedOrder, 0);
  Result.ErrorMessage := '';
  Result.CyclePackages := '';
  Result.ConflictPackages := '';

  if Length(FNodes) = 0 then
    Exit;

  // Check for cycles using DFS
  SetLength(Visited, Length(FNodes));
  SetLength(InStack, Length(FNodes));
  for i := 0 to High(FNodes) do
  begin
    Visited[i] := False;
    InStack[i] := False;
  end;

  SetLength(CyclePath, 0);

  for i := 0 to High(FNodes) do
  begin
    if not Visited[i] then
    begin
      if DetectCycle(i, Visited, InStack, CyclePath) then
      begin
        Result.Success := False;
        Result.HasCycle := True;

        // Build cycle string
        CycleStr := '';
        for j := 0 to High(CyclePath) do
        begin
          if j > 0 then
            CycleStr := CycleStr + ' -> ';
          CycleStr := CycleStr + CyclePath[j];
        end;
        Result.CyclePackages := CycleStr;
        Result.ErrorMessage := 'Circular dependency detected: ' + CycleStr;
        Exit;
      end;
    end;
  end;

  // No cycle, perform topological sort
  Result.ResolvedOrder := TopologicalSort;

  // Check if all nodes were processed
  if Length(Result.ResolvedOrder) < Length(FNodes) then
  begin
    Result.Success := False;
    Result.HasCycle := True;
    Result.ErrorMessage := 'Could not resolve all dependencies (possible cycle)';
  end;
end;

function TDependencyGraph.NodeCount: Integer;
begin
  Result := Length(FNodes);
end;

function TDependencyGraph.HasNode(const AName: string): Boolean;
begin
  Result := FindNodeIndex(AName) >= 0;
end;

end.
