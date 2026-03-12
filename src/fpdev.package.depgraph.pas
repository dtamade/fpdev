unit fpdev.package.depgraph;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.pkg.deps, fpdev.package.types;

type
  TPackageDepDescriptor = record
    Name: string;
    Version: string;
    Dependencies: TStringArray;
  end;

  TPackageDepDescriptorArray = array of TPackageDepDescriptor;

  TPackageInstallPlanItem = record
    Name: string;
    Version: string;
    HasNestedDependencies: Boolean;
  end;

  TPackageInstallPlanItemArray = array of TPackageInstallPlanItem;

  TPackageInstallPlanBuildStatus = (
    pipsOk,
    pipsMissingDependency,
    pipsResolveError
  );

  TDependencyNameExtractor = function(const ADependency: string): string;

function PackageArrayToDepDescriptorsCore(
  const APackages: TPackageArray): TPackageDepDescriptorArray;
function BuildPackageDependencyGraph(const ARootPackage: string;
  const APackages: TPackageDepDescriptorArray): TDependencyNodeArray;
function ResolvePackageDependencyOrderCore(
  const ARootPackage: string;
  const AAvailablePackages, AInstalledPackages: TPackageDepDescriptorArray;
  AExtractPackageName: TDependencyNameExtractor
): TStringArray;
function BuildDependencyInstallPlanCore(
  const ARootPackage: TPackageDepDescriptor;
  const AAvailablePackages: TPackageDepDescriptorArray;
  AExtractPackageName: TDependencyNameExtractor;
  out APlan: TPackageInstallPlanItemArray;
  out AMissingDependency, AResolveError: string
): TPackageInstallPlanBuildStatus;
function BuildPackageDependencyInstallPlanCore(
  const APackageInfo: TPackageInfo;
  const AAvailablePackages: TPackageArray;
  AExtractPackageName: TDependencyNameExtractor;
  out APlan: TPackageInstallPlanItemArray;
  out AMissingDependency, AResolveError: string
): TPackageInstallPlanBuildStatus;
function TopologicalSortPackageDependencies(
  const AGraph: TDependencyNodeArray): TStringArray;

implementation

function PackageArrayToDepDescriptorsCore(
  const APackages: TPackageArray): TPackageDepDescriptorArray;
var
  I, J: Integer;
begin
  Result := nil;
  SetLength(Result, Length(APackages));
  for I := 0 to High(APackages) do
  begin
    Result[I].Name := APackages[I].Name;
    Result[I].Version := APackages[I].Version;
    SetLength(Result[I].Dependencies, Length(APackages[I].Dependencies));
    for J := 0 to High(APackages[I].Dependencies) do
      Result[I].Dependencies[J] := APackages[I].Dependencies[J];
  end;
end;

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

function ResolvePackageDependencyOrderCore(
  const ARootPackage: string;
  const AAvailablePackages, AInstalledPackages: TPackageDepDescriptorArray;
  AExtractPackageName: TDependencyNameExtractor
): TStringArray;
var
  Graph: fpdev.pkg.deps.TDependencyGraph;
  ResolveResult: TResolveResult;
  Visited: TStringList;
  I: Integer;

  function TryFindDescriptor(const APackageName: string;
    const ADescriptors: TPackageDepDescriptorArray;
    out ADescriptor: TPackageDepDescriptor): Boolean;
  var
    Index: Integer;
  begin
    for Index := 0 to High(ADescriptors) do
    begin
      if SameText(ADescriptors[Index].Name, APackageName) then
      begin
        ADescriptor := ADescriptors[Index];
        Exit(True);
      end;
    end;

    Result := False;
  end;

  function ResolveDependencyName(const ADependency: string): string;
  begin
    Result := '';
    if Assigned(AExtractPackageName) then
      Result := Trim(AExtractPackageName(ADependency));
    if Result = '' then
      Result := Trim(ADependency);
  end;

  procedure BuildDependencyTree(const APkgName: string);
  var
    Descriptor: TPackageDepDescriptor;
    DepName: string;
    K: Integer;
  begin
    if Visited.IndexOf(APkgName) >= 0 then
      Exit;
    Visited.Add(APkgName);

    if not TryFindDescriptor(APkgName, AAvailablePackages, Descriptor) and
       not TryFindDescriptor(APkgName, AInstalledPackages, Descriptor) then
      Exit;

    Graph.AddNode(APkgName, Descriptor.Version);
    for K := 0 to High(Descriptor.Dependencies) do
    begin
      DepName := ResolveDependencyName(Descriptor.Dependencies[K]);
      Graph.AddDependency(APkgName, DepName);
      BuildDependencyTree(DepName);
    end;
  end;
begin
  Initialize(Result);
  SetLength(Result, 0);

  if ARootPackage = '' then
    Exit;

  Graph := fpdev.pkg.deps.TDependencyGraph.Create;
  Visited := TStringList.Create;
  try
    Visited.CaseSensitive := False;
    BuildDependencyTree(ARootPackage);

    ResolveResult := Graph.Resolve;
    if ResolveResult.Success then
    begin
      SetLength(Result, Length(ResolveResult.ResolvedOrder));
      for I := 0 to High(ResolveResult.ResolvedOrder) do
        Result[I] := ResolveResult.ResolvedOrder[I];
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := ARootPackage;
    end;
  finally
    Visited.Free;
    Graph.Free;
  end;
end;

function BuildPackageDependencyInstallPlanCore(
  const APackageInfo: TPackageInfo;
  const AAvailablePackages: TPackageArray;
  AExtractPackageName: TDependencyNameExtractor;
  out APlan: TPackageInstallPlanItemArray;
  out AMissingDependency, AResolveError: string
): TPackageInstallPlanBuildStatus;
var
  RootDescriptor: TPackageDepDescriptor;
  AvailableDescriptors: TPackageDepDescriptorArray;
begin
  Initialize(RootDescriptor);
  RootDescriptor.Name := APackageInfo.Name;
  RootDescriptor.Version := APackageInfo.Version;
  RootDescriptor.Dependencies := Copy(APackageInfo.Dependencies);

  AvailableDescriptors := PackageArrayToDepDescriptorsCore(AAvailablePackages);
  Result := BuildDependencyInstallPlanCore(
    RootDescriptor,
    AvailableDescriptors,
    AExtractPackageName,
    APlan,
    AMissingDependency,
    AResolveError
  );
end;

function BuildDependencyInstallPlanCore(
  const ARootPackage: TPackageDepDescriptor;
  const AAvailablePackages: TPackageDepDescriptorArray;
  AExtractPackageName: TDependencyNameExtractor;
  out APlan: TPackageInstallPlanItemArray;
  out AMissingDependency, AResolveError: string
): TPackageInstallPlanBuildStatus;
var
  Graph: fpdev.pkg.deps.TDependencyGraph;
  ResolveResult: TResolveResult;
  Descriptor: TPackageDepDescriptor;
  PlanIndex: Integer;
  I: Integer;

  function TryFindDescriptor(const APackageName: string;
    out ADescriptor: TPackageDepDescriptor): Boolean;
  var
    Index: Integer;
  begin
    for Index := 0 to High(AAvailablePackages) do
    begin
      if SameText(AAvailablePackages[Index].Name, APackageName) then
      begin
        ADescriptor := AAvailablePackages[Index];
        Exit(True);
      end;
    end;

    Result := False;
  end;

  function ResolveDependencyName(const ADependency: string): string;
  begin
    Result := '';
    if Assigned(AExtractPackageName) then
      Result := Trim(AExtractPackageName(ADependency));
    if Result = '' then
      Result := Trim(ADependency);
  end;
begin
  Initialize(APlan);
  SetLength(APlan, 0);
  AMissingDependency := '';
  AResolveError := '';

  if Length(ARootPackage.Dependencies) = 0 then
    Exit(pipsOk);

  Graph := fpdev.pkg.deps.TDependencyGraph.Create;
  try
    Graph.AddNode(ARootPackage.Name, ARootPackage.Version);

    for I := 0 to High(ARootPackage.Dependencies) do
    begin
      if not TryFindDescriptor(
        ResolveDependencyName(ARootPackage.Dependencies[I]),
        Descriptor
      ) then
      begin
        AMissingDependency := ARootPackage.Dependencies[I];
        Exit(pipsMissingDependency);
      end;

      Graph.AddNode(Descriptor.Name, Descriptor.Version);
      Graph.AddDependency(ARootPackage.Name, Descriptor.Name);
    end;

    ResolveResult := Graph.Resolve;
    if not ResolveResult.Success then
    begin
      AResolveError := ResolveResult.ErrorMessage;
      Exit(pipsResolveError);
    end;

    for I := High(ResolveResult.ResolvedOrder) downto 0 do
    begin
      if SameText(ResolveResult.ResolvedOrder[I], ARootPackage.Name) then
        Continue;

      if not TryFindDescriptor(ResolveResult.ResolvedOrder[I], Descriptor) then
        Continue;

      PlanIndex := Length(APlan);
      SetLength(APlan, PlanIndex + 1);
      APlan[PlanIndex].Name := Descriptor.Name;
      APlan[PlanIndex].Version := Descriptor.Version;
      APlan[PlanIndex].HasNestedDependencies :=
        Length(Descriptor.Dependencies) > 0;
    end;

    Result := pipsOk;
  finally
    Graph.Free;
  end;
end;

function TopologicalSortPackageDependencies(
  const AGraph: TDependencyNodeArray): TStringArray;
var
  InDegree: array of Integer;
  Queue: TStringArray;
  QueueHead, QueueTail: Integer;
  I, J, K, Idx, ProcessedCount: Integer;
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
  for I := 0 to High(AGraph) do
    InDegree[I] := 0;

  for I := 0 to High(AGraph) do
  begin
    for J := 0 to High(AGraph[I].Dependencies) do
    begin
      DepParts := AGraph[I].Dependencies[J].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := Trim(DepParts[0]);
        for K := 0 to High(AGraph) do
        begin
          if SameText(AGraph[K].Name, DepName) then
          begin
            Inc(InDegree[K]);
            Break;
          end;
        end;
      end;
    end;
  end;

  SetLength(Queue, Length(AGraph));
  QueueHead := 0;
  QueueTail := 0;

  for I := 0 to High(AGraph) do
  begin
    if InDegree[I] = 0 then
    begin
      Queue[QueueTail] := AGraph[I].Name;
      Inc(QueueTail);
    end;
  end;

  SetLength(Result, Length(AGraph));
  ProcessedCount := 0;

  while QueueHead < QueueTail do
  begin
    Result[ProcessedCount] := Queue[QueueHead];
    Idx := -1;

    for I := 0 to High(AGraph) do
    begin
      if SameText(AGraph[I].Name, Queue[QueueHead]) then
      begin
        Idx := I;
        Break;
      end;
    end;

    Inc(QueueHead);
    Inc(ProcessedCount);

    if Idx < 0 then
      Continue;

    for I := 0 to High(AGraph[Idx].Dependencies) do
    begin
      DepParts := AGraph[Idx].Dependencies[I].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := Trim(DepParts[0]);
        for J := 0 to High(AGraph) do
        begin
          if SameText(AGraph[J].Name, DepName) then
          begin
            Dec(InDegree[J]);
            if InDegree[J] = 0 then
            begin
              Queue[QueueTail] := AGraph[J].Name;
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
