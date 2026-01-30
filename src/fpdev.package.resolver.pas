unit fpdev.package.resolver;

{$mode objfpc}{$H+}

(*
  High-Level Package Dependency Resolver

  Integrates package metadata parsing with dependency graph resolution.

  Features:
  - Load package metadata from JSON files
  - Recursively resolve dependencies
  - Build dependency graph
  - Detect circular dependencies
  - Generate installation order

  Usage:
    Resolver := TPackageResolver.Create('/path/to/packages');
    try
      Result := Resolver.Resolve('mypackage');
      if Result.Success then
        for i := 0 to High(Result.InstallOrder) do
          WriteLn('Install: ', Result.InstallOrder[i]);
    finally
      Resolver.Free;
    end;
*)

interface

uses
  SysUtils, Classes,
  fpdev.package.metadata,
  fpdev.pkg.deps,
  fpdev.package.lockfile;

type
  { TPackageResolveResult - Result of package dependency resolution }
  TPackageResolveResult = record
    Success: Boolean;
    InstallOrder: TStringArray;
    ErrorMessage: string;
    HasCircularDependency: Boolean;
    CircularPath: string;
  end;

  { TPackageResolver - High-level package dependency resolver }
  TPackageResolver = class
  private
    FPackageDir: string;
    FGraph: TDependencyGraph;
    FLoadedPackages: TStringList;  // Track loaded packages to avoid duplicates
    FLockFile: TPackageLockFile;
    FProjectDir: string;
    FUseLockFile: Boolean;

    function GetPackageMetadataPath(const APackageName: string): string;
    function LoadPackageMetadata(const APackageName: string): TPackageMetadata;
    procedure BuildDependencyGraph(const APackageName: string);
    function GetLockFilePath: string;
    procedure GenerateLockFile(const AResolveResult: TPackageResolveResult);

  public
    constructor Create(const APackageDir: string; const AProjectDir: string = '');
    destructor Destroy; override;

    { Resolve dependencies for a package and return installation order }
    function Resolve(const APackageName: string): TPackageResolveResult;

    { Enable/disable lock file usage }
    procedure SetUseLockFile(AUse: Boolean);

    { Get the dependency graph (for testing/debugging) }
    property Graph: TDependencyGraph read FGraph;

    { Get lock file instance (for testing) }
    property LockFile: TPackageLockFile read FLockFile;
  end;

implementation

{ TPackageResolver }

constructor TPackageResolver.Create(const APackageDir: string; const AProjectDir: string = '');
begin
  inherited Create;
  FPackageDir := APackageDir;
  FProjectDir := AProjectDir;
  if FProjectDir = '' then
    FProjectDir := GetCurrentDir;
  FGraph := TDependencyGraph.Create;
  FLoadedPackages := TStringList.Create;
  FLoadedPackages.Sorted := True;
  FLoadedPackages.Duplicates := dupIgnore;
  FLockFile := TPackageLockFile.Create(GetLockFilePath);
  FUseLockFile := True;
end;

destructor TPackageResolver.Destroy;
begin
  FLockFile.Free;
  FGraph.Free;
  FLoadedPackages.Free;
  inherited Destroy;
end;

function TPackageResolver.GetPackageMetadataPath(const APackageName: string): string;
begin
  Result := FPackageDir + PathDelim + APackageName + '.json';
end;

function TPackageResolver.LoadPackageMetadata(const APackageName: string): TPackageMetadata;
var
  MetadataPath: string;
begin
  MetadataPath := GetPackageMetadataPath(APackageName);

  if not FileExists(MetadataPath) then
    raise Exception.CreateFmt('Package metadata not found: %s', [APackageName]);

  Result := fpdev.package.metadata.LoadMetadata(MetadataPath);
end;

procedure TPackageResolver.BuildDependencyGraph(const APackageName: string);
var
  Meta: TPackageMetadata;
  I: Integer;
  DepName: string;
begin
  // Check if already loaded
  if FLoadedPackages.IndexOf(APackageName) >= 0 then
    Exit;

  // Load metadata first (can raise exception)
  Meta := LoadPackageMetadata(APackageName);
  try
    // Mark as loaded only after successful metadata load
    FLoadedPackages.Add(APackageName);

    // Add node to graph
    FGraph.AddNode(APackageName, Meta.Version);

    // Process dependencies recursively
    for I := 0 to Meta.Dependencies.Count - 1 do
    begin
      DepName := Meta.Dependencies.Keys[I];

      // Recursively load dependency
      BuildDependencyGraph(DepName);

      // Add edge to graph
      FGraph.AddDependency(APackageName, DepName);
    end;

  finally
    Meta.Free;
  end;
end;

function TPackageResolver.Resolve(const APackageName: string): TPackageResolveResult;
var
  GraphResult: TResolveResult;
  Meta: TPackageMetadata;
begin
  Initialize(Result);
  Result.Success := False;
  SetLength(Result.InstallOrder, 0);
  Result.ErrorMessage := '';
  Result.HasCircularDependency := False;
  Result.CircularPath := '';

  // Clear previous state
  FLoadedPackages.Clear;

  // Free old graph and create new one
  FGraph.Free;
  FGraph := TDependencyGraph.Create;

  try
    // Load project metadata for lock file
    if FUseLockFile then
    begin
      Meta := LoadPackageMetadata(APackageName);
      try
        FLockFile.SetProjectInfo(Meta.Name, Meta.Version);
      finally
        Meta.Free;
      end;
    end;

    // Build dependency graph recursively
    BuildDependencyGraph(APackageName);

    // Resolve using graph algorithm
    GraphResult := FGraph.Resolve;

    // Convert result
    Result.Success := GraphResult.Success;
    Result.InstallOrder := GraphResult.ResolvedOrder;
    Result.ErrorMessage := GraphResult.ErrorMessage;
    Result.HasCircularDependency := GraphResult.HasCycle;
    Result.CircularPath := GraphResult.CyclePackages;

    // Generate lock file if successful
    if Result.Success and FUseLockFile then
      GenerateLockFile(Result);

  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TPackageResolver.GetLockFilePath: string;
begin
  Result := FProjectDir + PathDelim + LOCKFILE_NAME;
end;

procedure TPackageResolver.GenerateLockFile(const AResolveResult: TPackageResolveResult);
var
  i: Integer;
  PkgName: string;
  Meta: TPackageMetadata;
  Deps: TStringList;
  j: Integer;
begin
  FLockFile.Clear;

  // Add all resolved packages to lock file
  for i := 0 to High(AResolveResult.InstallOrder) do
  begin
    PkgName := AResolveResult.InstallOrder[i];
    
    try
      Meta := LoadPackageMetadata(PkgName);
      try
        // Convert dependencies to string list
        Deps := TStringList.Create;
        try
          for j := 0 to Meta.Dependencies.Count - 1 do
            Deps.Add(Meta.Dependencies.Keys[j] + '=' + Meta.Dependencies.Data[j]);

          // Add package to lock file
          FLockFile.AddPackage(
            Meta.Name,
            Meta.Version,
            GetPackageMetadataPath(PkgName),  // Resolved path
            'sha256-placeholder',  // TODO: Calculate actual checksum
            Deps
          );
        finally
          Deps.Free;
        end;
      finally
        Meta.Free;
      end;
    except
      // Skip packages that fail to load
      Continue;
    end;
  end;

  // Save lock file
  FLockFile.Save;
end;

procedure TPackageResolver.SetUseLockFile(AUse: Boolean);
begin
  FUseLockFile := AUse;
end;

end.
