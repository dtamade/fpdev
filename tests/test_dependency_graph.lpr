program test_dependency_graph;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.cmd.package, fpdev.package.depgraph, fpdev.package.types,
  fpdev.pkg.version;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

{ Helper: Create test package index }
function CreateTestPackageIndex: TPackageArray;
begin
  Initialize(Result);
  SetLength(Result, 5);

  // Package A - no dependencies (leaf)
  Result[0].Name := 'pkgA';
  Result[0].Version := '1.0.0';
  SetLength(Result[0].Dependencies, 0);

  // Package B - depends on A
  Result[1].Name := 'pkgB';
  Result[1].Version := '2.0.0';
  SetLength(Result[1].Dependencies, 1);
  Result[1].Dependencies[0] := 'pkgA:>=1.0.0';

  // Package C - depends on A and B
  Result[2].Name := 'pkgC';
  Result[2].Version := '1.5.0';
  SetLength(Result[2].Dependencies, 2);
  Result[2].Dependencies[0] := 'pkgA:>=1.0.0';
  Result[2].Dependencies[1] := 'pkgB:>=1.0.0';

  // Package D - depends on C (transitive: D -> C -> A, B -> A)
  Result[3].Name := 'pkgD';
  Result[3].Version := '3.0.0';
  SetLength(Result[3].Dependencies, 1);
  Result[3].Dependencies[0] := 'pkgC:>=1.0.0';

  // Package E - no dependencies (isolated)
  Result[4].Name := 'pkgE';
  Result[4].Version := '1.0.0';
  SetLength(Result[4].Dependencies, 0);
end;


function CreateDepDescriptor(const AName, AVersion: string;
  const ADeps: array of string): TPackageDepDescriptor;
var
  I: Integer;
begin
  Initialize(Result);
  Result.Name := AName;
  Result.Version := AVersion;
  SetLength(Result.Dependencies, Length(ADeps));
  for I := 0 to High(ADeps) do
    Result.Dependencies[I] := ADeps[I];
end;

procedure TestResolvePackageDependencyOrderUsesInstalledFallback;
var
  Available: TPackageDepDescriptorArray;
  Installed: TPackageDepDescriptorArray;
  Order: TStringArray;
begin
  WriteLn('');
  WriteLn('=== Test: ResolvePackageDependencyOrder uses installed fallback ===');

  SetLength(Available, 1);
  Available[0] := CreateDepDescriptor('pkgRoot', '1.0.0', ['pkgInstalled>=1.0.0']);

  SetLength(Installed, 1);
  Installed[0] := CreateDepDescriptor('pkgInstalled', '2.0.0', []);

  Order := ResolvePackageDependencyOrderCore(
    'pkgRoot',
    Available,
    Installed,
    @ExtractPackageName
  );

  Assert(Length(Order) = 2, 'Installed fallback order contains root and installed dependency');
  Assert((Length(Order) >= 2) and SameText(Order[0], 'pkgInstalled'),
    'Installed dependency resolves first');
  Assert((Length(Order) >= 2) and SameText(Order[1], 'pkgRoot'),
    'Root package resolves last');
end;

procedure TestResolvePackageDependencyOrderFallsBackToRootOnMissingDependency;
var
  Available: TPackageDepDescriptorArray;
  Installed: TPackageDepDescriptorArray;
  Order: TStringArray;
begin
  WriteLn('');
  WriteLn('=== Test: ResolvePackageDependencyOrder falls back to root on missing dependency ===');

  SetLength(Available, 1);
  Available[0] := CreateDepDescriptor('pkgRoot', '1.0.0', ['pkgMissing>=1.0.0']);
  SetLength(Installed, 0);

  Order := ResolvePackageDependencyOrderCore(
    'pkgRoot',
    Available,
    Installed,
    @ExtractPackageName
  );

  Assert(Length(Order) = 1, 'Missing dependency falls back to root-only result');
  Assert((Length(Order) = 1) and SameText(Order[0], 'pkgRoot'),
    'Fallback result preserves root package name');
end;

procedure TestBuildDependencyInstallPlanCoreBuildsInstallOrder;
var
  Root: TPackageDepDescriptor;
  Available: TPackageDepDescriptorArray;
  Plan: TPackageInstallPlanItemArray;
  Status: TPackageInstallPlanBuildStatus;
  MissingDependency: string;
  ResolveError: string;
begin
  WriteLn('');
  WriteLn('=== Test: BuildDependencyInstallPlanCore builds install order ===');

  Root := CreateDepDescriptor('pkgRoot', '1.0.0', ['pkgB>=1.0.0', 'pkgA>=1.0.0']);
  SetLength(Available, 2);
  Available[0] := CreateDepDescriptor('pkgA', '1.0.0', []);
  Available[1] := CreateDepDescriptor('pkgB', '2.0.0', ['pkgA>=1.0.0']);

  Status := BuildDependencyInstallPlanCore(
    Root,
    Available,
    @ExtractPackageName,
    Plan,
    MissingDependency,
    ResolveError
  );

  Assert(Status = pipsOk, 'Install plan build returns ok status');
  Assert(Length(Plan) = 2, 'Install plan contains direct dependencies only');
  Assert((Length(Plan) >= 2) and SameText(Plan[0].Name, 'pkgA'),
    'Install plan orders pkgA before pkgB');
  Assert((Length(Plan) >= 2) and SameText(Plan[1].Name, 'pkgB'),
    'Install plan orders pkgB last among direct dependencies');
  Assert((Length(Plan) >= 2) and Plan[1].HasNestedDependencies,
    'Install plan flags dependency that has nested deps');
end;

procedure TestBuildPackageDependencyInstallPlanCoreBuildsPlanFromPackageInfo;
var
  Root: TPackageInfo;
  Available: TPackageArray;
  Plan: TPackageInstallPlanItemArray;
  Status: TPackageInstallPlanBuildStatus;
  MissingDependency: string;
  ResolveError: string;
begin
  WriteLn('');
  WriteLn('=== Test: BuildPackageDependencyInstallPlanCore builds plan from package info ===');

  Initialize(Root);
  Root.Name := 'pkgRoot';
  Root.Version := '1.0.0';
  SetLength(Root.Dependencies, 2);
  Root.Dependencies[0] := 'pkgB>=1.0.0';
  Root.Dependencies[1] := 'pkgA>=1.0.0';

  Initialize(Available);
  SetLength(Available, 2);
  Available[0].Name := 'pkgA';
  Available[0].Version := '1.0.0';
  SetLength(Available[0].Dependencies, 0);
  Available[1].Name := 'pkgB';
  Available[1].Version := '2.0.0';
  SetLength(Available[1].Dependencies, 1);
  Available[1].Dependencies[0] := 'pkgA>=1.0.0';

  Status := BuildPackageDependencyInstallPlanCore(
    Root,
    Available,
    @ExtractPackageName,
    Plan,
    MissingDependency,
    ResolveError
  );

  Assert(Status = pipsOk, 'Package install plan helper returns ok status');
  Assert(Length(Plan) = 2, 'Package install plan helper returns dependency plan');
  Assert((Length(Plan) >= 2) and SameText(Plan[0].Name, 'pkgA'),
    'Package install plan helper orders pkgA before pkgB');
  Assert((Length(Plan) >= 2) and SameText(Plan[1].Name, 'pkgB'),
    'Package install plan helper orders pkgB last');
  Assert((Length(Plan) >= 2) and Plan[1].HasNestedDependencies,
    'Package install plan helper preserves nested dependency flag');
end;

procedure TestBuildPackageDependencyInstallPlanCoreReportsMissingDependency;
var
  Root: TPackageInfo;
  Available: TPackageArray;
  Plan: TPackageInstallPlanItemArray;
  Status: TPackageInstallPlanBuildStatus;
  MissingDependency: string;
  ResolveError: string;
begin
  WriteLn('');
  WriteLn('=== Test: BuildPackageDependencyInstallPlanCore reports missing dependency ===');

  Initialize(Root);
  Root.Name := 'pkgRoot';
  Root.Version := '1.0.0';
  SetLength(Root.Dependencies, 1);
  Root.Dependencies[0] := 'pkgMissing>=1.0.0';

  Initialize(Available);
  SetLength(Available, 0);

  Status := BuildPackageDependencyInstallPlanCore(
    Root,
    Available,
    @ExtractPackageName,
    Plan,
    MissingDependency,
    ResolveError
  );

  Assert(Status = pipsMissingDependency, 'Package install plan helper returns missing-dependency status');
  Assert(SameText(MissingDependency, 'pkgMissing>=1.0.0'),
    'Package install plan helper returns original missing dependency token');
  Assert(Length(Plan) = 0, 'Package install plan helper leaves plan empty on missing dependency');
end;

procedure TestBuildDependencyInstallPlanCoreReportsMissingDependency;
var
  Root: TPackageDepDescriptor;
  Available: TPackageDepDescriptorArray;
  Plan: TPackageInstallPlanItemArray;
  Status: TPackageInstallPlanBuildStatus;
  MissingDependency: string;
  ResolveError: string;
begin
  WriteLn('');
  WriteLn('=== Test: BuildDependencyInstallPlanCore reports missing dependency ===');

  Root := CreateDepDescriptor('pkgRoot', '1.0.0', ['pkgMissing>=1.0.0']);
  SetLength(Available, 0);

  Status := BuildDependencyInstallPlanCore(
    Root,
    Available,
    @ExtractPackageName,
    Plan,
    MissingDependency,
    ResolveError
  );

  Assert(Status = pipsMissingDependency, 'Install plan build returns missing-dependency status');
  Assert(SameText(MissingDependency, 'pkgMissing>=1.0.0'),
    'Install plan build returns original missing dependency token');
  Assert(Length(Plan) = 0, 'Install plan remains empty on missing dependency');
end;

procedure TestBuildDependencyGraph;
var
  Index: TPackageArray;
  Graph: TDependencyGraph;
  j, k, m: Integer;
  DepName: string;
  DepParts: TStringArray;
  DepFound: Boolean;
  AllDepsIncluded: Boolean;
begin
  WriteLn('');
  WriteLn('=== Test: BuildDependencyGraph ===');

  Index := CreateTestPackageIndex;

  // Test with package D (has transitive dependencies)
  Graph := BuildDependencyGraph('pkgD', Index);

  // Verify: graph should contain pkgD, pkgC, pkgB, pkgA
  Assert(Length(Graph) = 4, 'Graph contains 4 packages');

  // Verify: all dependencies of each node are also in the graph
  AllDepsIncluded := True;
  for j := 0 to High(Graph) do
  begin
    for k := 0 to High(Graph[j].Dependencies) do
    begin
      DepParts := Graph[j].Dependencies[k].Split([':']);
      if Length(DepParts) > 0 then
      begin
        DepName := DepParts[0];
        DepFound := False;

        // Check if dependency is in graph
        for m := 0 to High(Graph) do
        begin
          if SameText(Graph[m].Name, DepName) then
          begin
            DepFound := True;
            Break;
          end;
        end;

        if not DepFound then
        begin
          AllDepsIncluded := False;
          WriteLn('  Missing dependency: ', DepName, ' for package ', Graph[j].Name);
        end;
      end;
    end;
  end;

  Assert(AllDepsIncluded, 'All dependencies included in graph');

  // Test with package E (no dependencies)
  Graph := BuildDependencyGraph('pkgE', Index);
  Assert(Length(Graph) = 1, 'Graph for pkgE contains only 1 package');
  Assert(SameText(Graph[0].Name, 'pkgE'), 'Graph contains pkgE');
end;

procedure TestTopologicalSort;
var
  Index: TPackageArray;
  Graph: TDependencyGraph;
  SortedOrder: TStringArray;
  i, j: Integer;
  HasDuplicates: Boolean;
begin
  WriteLn('');
  WriteLn('=== Test: TopologicalSortDependencies ===');

  Index := CreateTestPackageIndex;
  Graph := BuildDependencyGraph('pkgD', Index);
  SortedOrder := TopologicalSortDependencies(Graph);

  // Verify: sorted order contains all nodes
  Assert(Length(SortedOrder) = Length(Graph), 'Sorted order includes all nodes');

  // Verify: no duplicates in sorted order
  HasDuplicates := False;
  for i := 0 to High(SortedOrder) do
  begin
    for j := i + 1 to High(SortedOrder) do
    begin
      if SameText(SortedOrder[i], SortedOrder[j]) then
      begin
        HasDuplicates := True;
        Break;
      end;
    end;
    if HasDuplicates then Break;
  end;
  Assert(not HasDuplicates, 'Sorted order has no duplicates');

  // Verify: dependencies come before dependents
  // pkgA should come before pkgB, pkgC, pkgD
  // pkgB should come before pkgC, pkgD
  // pkgC should come before pkgD
  WriteLn('  Sorted order: ');
  for i := 0 to High(SortedOrder) do
    WriteLn('    ', i + 1, '. ', SortedOrder[i]);
end;

begin
  WriteLn('========================================');
  WriteLn('Dependency Graph Tests');
  WriteLn('========================================');

  TestBuildDependencyGraph;
  TestTopologicalSort;
  TestResolvePackageDependencyOrderUsesInstalledFallback;
  TestResolvePackageDependencyOrderFallsBackToRootOnMissingDependency;
  TestBuildDependencyInstallPlanCoreBuildsInstallOrder;
  TestBuildDependencyInstallPlanCoreReportsMissingDependency;
  TestBuildPackageDependencyInstallPlanCoreBuildsPlanFromPackageInfo;
  TestBuildPackageDependencyInstallPlanCoreReportsMissingDependency;

  WriteLn('');
  WriteLn('========================================');
  WriteLn('Test Results: ', TestsPassed, '/', TestsPassed + TestsFailed, ' passed');
  if TestsFailed > 0 then
    WriteLn('FAILED: ', TestsFailed, ' tests failed')
  else
    WriteLn('SUCCESS: All tests passed');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
