unit fpdev.cmd.package.depgraph;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.pkg.deps;

type
  TPackageDepDescriptor = record
    Name: string;
    Version: string;
    Dependencies: TStringArray;
  end;

  TPackageDepDescriptorArray = array of TPackageDepDescriptor;

function BuildPackageDependencyGraph(const ARootPackage: string;
  const APackages: TPackageDepDescriptorArray): TDependencyNodeArray;
function TopologicalSortPackageDependencies(
  const AGraph: TDependencyNodeArray): TStringArray;

implementation

function BuildPackageDependencyGraph(const ARootPackage: string;
  const APackages: TPackageDepDescriptorArray): TDependencyNodeArray;
var
  Visited: TStringList;

  procedure AddPackageAndDeps(const APkgName: string);
  var
    PkgIdx, DepIdx, NodeIdx, Idx: Integer;
    Parts: TStringArray;
    DepNamePart: string;
  begin
    if Visited.IndexOf(APkgName) >= 0 then
      Exit;
    Visited.Add(APkgName);

    PkgIdx := -1;
    for Idx := 0 to High(APackages) do
    begin
      if SameText(APackages[Idx].Name, APkgName) then
      begin
        PkgIdx := Idx;
        Break;
      end;
    end;

    if PkgIdx < 0 then
      Exit;

    NodeIdx := Length(Result);
    SetLength(Result, NodeIdx + 1);
    Result[NodeIdx].Name := APackages[PkgIdx].Name;
    Result[NodeIdx].Version := APackages[PkgIdx].Version;
    SetLength(Result[NodeIdx].Dependencies, Length(APackages[PkgIdx].Dependencies));

    for Idx := 0 to High(APackages[PkgIdx].Dependencies) do
      Result[NodeIdx].Dependencies[Idx] := APackages[PkgIdx].Dependencies[Idx];

    SetLength(Result[NodeIdx].Constraints, 0);
    Result[NodeIdx].Visited := False;
    Result[NodeIdx].InStack := False;

    for DepIdx := 0 to High(APackages[PkgIdx].Dependencies) do
    begin
      Parts := APackages[PkgIdx].Dependencies[DepIdx].Split([':']);
      if Length(Parts) > 0 then
      begin
        DepNamePart := Trim(Parts[0]);
        AddPackageAndDeps(DepNamePart);
      end;
    end;
  end;

begin
  SetLength(Result, 0);
  Visited := TStringList.Create;
  try
    Visited.CaseSensitive := False;
    AddPackageAndDeps(ARootPackage);
  finally
    Visited.Free;
  end;
end;

function TopologicalSortPackageDependencies(
  const AGraph: TDependencyNodeArray): TStringArray;
var
  InDegree: array of Integer;
  Queue: TStringArray;
  QueueHead, QueueTail: Integer;
  i, j, k, Idx, ProcessedCount: Integer;
  DepName: string;
  DepParts: TStringArray;
begin
  Result := nil;
  InDegree := nil;
  Queue := nil;
  DepParts := nil;

  if Length(AGraph) = 0 then
    Exit;

  SetLength(InDegree, Length(AGraph));
  for i := 0 to High(AGraph) do
    InDegree[i] := 0;

  for i := 0 to High(AGraph) do
  begin
    for j := 0 to High(AGraph[i].Dependencies) do
    begin
      DepParts := AGraph[i].Dependencies[j].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := Trim(DepParts[0]);
        for k := 0 to High(AGraph) do
        begin
          if SameText(AGraph[k].Name, DepName) then
          begin
            Inc(InDegree[k]);
            Break;
          end;
        end;
      end;
    end;
  end;

  SetLength(Queue, Length(AGraph));
  QueueHead := 0;
  QueueTail := 0;

  for i := 0 to High(AGraph) do
  begin
    if InDegree[i] = 0 then
    begin
      Queue[QueueTail] := AGraph[i].Name;
      Inc(QueueTail);
    end;
  end;

  SetLength(Result, Length(AGraph));
  ProcessedCount := 0;

  while QueueHead < QueueTail do
  begin
    Result[ProcessedCount] := Queue[QueueHead];
    Idx := -1;

    for i := 0 to High(AGraph) do
    begin
      if SameText(AGraph[i].Name, Queue[QueueHead]) then
      begin
        Idx := i;
        Break;
      end;
    end;

    Inc(QueueHead);
    Inc(ProcessedCount);

    if Idx < 0 then
      Continue;

    for i := 0 to High(AGraph[Idx].Dependencies) do
    begin
      DepParts := AGraph[Idx].Dependencies[i].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := Trim(DepParts[0]);
        for j := 0 to High(AGraph) do
        begin
          if SameText(AGraph[j].Name, DepName) then
          begin
            Dec(InDegree[j]);
            if InDegree[j] = 0 then
            begin
              Queue[QueueTail] := AGraph[j].Name;
              Inc(QueueTail);
            end;
            Break;
          end;
        end;
      end;
    end;
  end;

  SetLength(Result, ProcessedCount);
end;

end.
