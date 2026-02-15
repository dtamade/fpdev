unit fpdev.cmd.package;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd.package

Free Pascal package management system


## Notice

If you redistribute or use this in your own project, please keep this project's copyright notice. Thank you.

fafafaStudio
Email:dtamade@gmail.com
QQ Group:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.config, fpdev.config.interfaces, fpdev.output.intf, fpdev.output.console,
  fpdev.toolchain.fetcher, fpdev.toolchain.extract, fpdev.paths, fpdev.hash,
  fpdev.resource.repo, fpdev.resource.repo.types,
  fpdev.pkg.deps, fpdev.utils.fs, fpdev.utils,
  fpdev.i18n, fpdev.i18n.strings, fpdev.pkg.builder, fpdev.pkg.repository,
  fpdev.package.archiver, fpdev.pkg.version, fpdev.package.types;

type
  { TDependencyGraph - Array-based dependency graph for test compatibility }
  TDependencyGraph = TDependencyNodeArray;

  { TPackageManager }
  TPackageManager = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FPackageRegistry: string;
    FResourceRepo: TResourceRepository;  // fpdev-repo integration
    FBuilder: TPackageBuilder;  // Build service (Facade delegation)
    FRepoService: TPackageRepositoryService;  // Repository service (Facade delegation)

    function GetAvailablePackages: TPackageArray;
    function GetInstalledPackages: TPackageArray;
    function DownloadPackage(const APackageName, AVersion: string): Boolean;
    function InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
    function ValidatePackage(const APackageName: string): Boolean;
    { Dependency resolution }
    function ResolveAndInstallDependencies(const APackageInfo: TPackageInfo; Outp, Errp: IOutput): Boolean;

  function GetPackageInstallPath(const APackageName: string): string;
    function IsPackageInstalled(const APackageName: string): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function ResolveDependencies(const APackageName: string): TStringArray;
    function BuildPackage(const ASourcePath: string): Boolean;

    function WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;

    { Parses local package index JSON file and returns deduplicated packages.
      Selects highest version for each package name. }
    function ParseLocalPackageIndex(const AIndexPath: string): TPackageArray;

  public
    constructor Create(AConfigManager: TFPDevConfigManager); overload;
    constructor Create(AConfigManager: IConfigManager); overload;
    destructor Destroy; override;

    // Settings
    procedure SetKeepBuildArtifacts(const AValue: Boolean);

    // Query methods (for tests and upper layers)
    function GetAvailablePackageList: TPackageArray;
    function GetInstalledPackageList: TPackageArray;

    // Cleanup
    function Clean(
      const Scope: string;
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean; // 'sandbox' | 'cache' | 'all'

    // Package management
    function InstallPackage(
      const APackageName: string;
      const AVersion: string = '';
      Outp: IOutput = nil;
      Errp: IOutput = nil
    ): Boolean;
    function UninstallPackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UpdatePackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListPackages(const AShowAll: Boolean = False; Outp: IOutput = nil): Boolean;
    function SearchPackages(const AQuery: string; Outp: IOutput = nil): Boolean;

    // Package information
    function ShowPackageInfo(const APackageName: string; Outp: IOutput = nil): Boolean;
    function ShowPackageDependencies(const APackageName: string): Boolean;
    function VerifyPackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;

    // Repository management
    function AddRepository(const AName, AURL: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function RemoveRepository(const AName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function UpdateRepositories(Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function ListRepositories(Outp: IOutput = nil): Boolean;

    // Local package management
    function InstallFromLocal(const APackagePath: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function CreatePackage(const APackageName, APath: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
    function PublishPackage(const APackageName: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;
  end;

{ Semantic Version Functions }
function ParseSemanticVersion(const AVersion: string): TSemanticVersion;
function CompareVersions(const AVersion1, AVersion2: string): Integer;
function VersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;

{ Dependency Graph Functions }
function BuildDependencyGraph(const ARootPackage: string; const APackages: TPackageArray): TDependencyNodeArray;
function TopologicalSortDependencies(const AGraph: TDependencyNodeArray): TStringArray;

{ Package Verification Functions }
function VerifyInstalledPackage(const TestDir: string): TPackageVerificationResult;
function VerifyPackageChecksum(const FilePath, Hash: string): Boolean;

{ Package Creation Functions }
function CollectPackageSourceFiles(const SourceDir: string; const ExcludePatterns: TStringArray): TStringArray;
function IsBuildArtifact(const FileName: string): Boolean;
function GeneratePackageMetadataJson(const Options: TPackageCreationOptions): string;
function CreatePackageZipArchive(
  const SourceDir: string;
  const {%H-} Files: TStringArray;
  const OutputPath: string;
  var Err: string
): Boolean;

{ Package Validation Functions }
function ValidatePackageSourcePath(const SourcePath: string): Boolean;
function ValidatePackageMetadata(const MetadataPath: string): Boolean;
function CheckPackageRequiredFiles(const PackageDir: string): TStringArray;

implementation

uses
  fpdev.cmd.package.semver,
  fpdev.cmd.package.depgraph,
  fpdev.cmd.package.verify,
  fpdev.cmd.package.create,
  fpdev.cmd.package.validation;

{ TPackageManager }

constructor TPackageManager.Create(AConfigManager: TFPDevConfigManager);
begin
  Create(AConfigManager.AsConfigManager);
end;

constructor TPackageManager.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
  RepoConfig: TResourceRepoConfig;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';
    {$ENDIF}

    Settings.InstallRoot := FInstallRoot;
    FConfigManager.GetSettingsManager.SetSettings(Settings);
  end;

  FPackageRegistry := FInstallRoot + PathDelim + 'packages';

  // Ensure package directory exists
  EnsureDir(FPackageRegistry);

  // Initialize fpdev-repo integration
  RepoConfig := CreateDefaultConfig;
  FResourceRepo := TResourceRepository.Create(RepoConfig);
  if DirectoryExists(RepoConfig.LocalPath) then
    FResourceRepo.LoadManifest;

  // Initialize build service
  FBuilder := TPackageBuilder.Create;

  // Initialize repository service
  FRepoService := TPackageRepositoryService.Create(FConfigManager, FPackageRegistry);
end;

procedure TPackageManager.SetKeepBuildArtifacts(const AValue: Boolean);
begin
  FBuilder.KeepArtifacts := AValue;
end;

function TPackageManager.Clean(const Scope: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  S: string;
  Ok: Boolean;
  Path: string;
  Existed: Boolean;
  SectionOk: Boolean;
begin
  Result := True;
  S := LowerCase(Trim(Scope));
  Ok := True;
  if (S='sandbox') or (S='all') then
  begin
    Path := GetSandboxDir;
    Existed := DirectoryExists(Path);
    if Existed then
      SectionOk := DeleteDirRecursive(Path)
    else
      SectionOk := True;
    Ok := Ok and SectionOk;
    if Existed then
    begin
      if (Outp <> nil) and SectionOk then
        Outp.WriteLn(_Fmt(MSG_CLEANED, [Path]))
      else if (Errp <> nil) and (not SectionOk) then
        Errp.WriteLn(_Fmt(MSG_CLEAN_FAILED, [Path]));
    end;
  end;
  if (S='cache') or (S='all') then
  begin
    Path := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages';
    Existed := DirectoryExists(Path);
    if Existed then
      SectionOk := DeleteDirRecursive(Path)
    else
      SectionOk := True;
    Ok := Ok and SectionOk;
    if Existed then
    begin
      if (Outp <> nil) and SectionOk then
        Outp.WriteLn(_Fmt(MSG_CLEANED, [Path]))
      else if (Errp <> nil) and (not SectionOk) then
        Errp.WriteLn(_Fmt(MSG_CLEAN_FAILED, [Path]));
    end;
  end;
  Result := Ok;
end;


destructor TPackageManager.Destroy;
begin
  if Assigned(FRepoService) then
    FRepoService.Free;
  if Assigned(FBuilder) then
    FBuilder.Free;
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function TPackageManager.ResolveAndInstallDependencies(const APackageInfo: TPackageInfo; Outp, Errp: IOutput): Boolean;
var
  Graph: fpdev.pkg.deps.TDependencyGraph;
  Avail: TPackageArray;
  i, j, DepIdx: Integer;
  ResolveResult: TResolveResult;
  DepPkg: TPackageInfo;
begin
  Result := False;

  if Length(APackageInfo.Dependencies) = 0 then
  begin
    Result := True;  // No dependencies to resolve
    Exit;
  end;

  // Get all available packages for dependency lookup
  Avail := GetAvailablePackages;

  // Build dependency graph
  Graph := fpdev.pkg.deps.TDependencyGraph.Create;
  try
    // Add root package
    Graph.AddNode(APackageInfo.Name, APackageInfo.Version);

    // Add all dependency nodes and edges
    for i := 0 to High(APackageInfo.Dependencies) do
    begin
      // Find dependency package info
      DepIdx := -1;
      for j := 0 to High(Avail) do
      begin
        if SameText(Avail[j].Name, APackageInfo.Dependencies[i]) then
        begin
          DepIdx := j;
          Break;
        end;
      end;

      if DepIdx < 0 then
      begin
        if Errp <> nil then
          Errp.WriteLn('Error: Dependency package not found: ' + APackageInfo.Dependencies[i]);
        Exit;
      end;

      // Add dependency node
      Graph.AddNode(Avail[DepIdx].Name, Avail[DepIdx].Version);

      // Add edge: root -> dependency
      Graph.AddDependency(APackageInfo.Name, Avail[DepIdx].Name);

      // Recursively add dependency's dependencies
      if Length(Avail[DepIdx].Dependencies) > 0 then
      begin
      if Outp <> nil then
        Outp.WriteLn('Adding dependency: ' + Avail[DepIdx].Name);
        // Note: For now, we only add direct dependencies
        // Recursive dependency resolution would require a more complex algorithm
      end;
    end;

    // Resolve installation order
    ResolveResult := Graph.Resolve;

    if not ResolveResult.Success then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + ResolveResult.ErrorMessage);
      Exit;
    end;

    // Install dependencies in reverse order (dependencies first, root last)
    if Outp <> nil then
      Outp.WriteLn('Installing dependencies...');

    for i := High(ResolveResult.ResolvedOrder) downto 0 do
    begin
      if SameText(ResolveResult.ResolvedOrder[i], APackageInfo.Name) then
        Continue;  // Skip the root package

      // Find dependency package
      DepIdx := -1;
      for j := 0 to High(Avail) do
      begin
        if SameText(Avail[j].Name, ResolveResult.ResolvedOrder[i]) then
        begin
          DepIdx := j;
          Break;
        end;
      end;

      if DepIdx < 0 then
        Continue;

      DepPkg := Avail[DepIdx];

      if Outp <> nil then
        Outp.WriteLn('Installing dependency: ' + DepPkg.Name);

      // Install dependency
      if not InstallPackage(DepPkg.Name, DepPkg.Version, Outp, Errp) then
      begin
        if Errp <> nil then
          Errp.WriteLn('Error: Failed to install dependency: ' + DepPkg.Name);
        Exit;
      end;
    end;

    Result := True;
  finally
    Graph.Free;
  end;
end;

function TPackageManager.GetPackageInstallPath(const APackageName: string): string;
begin
  Result := FPackageRegistry + PathDelim + APackageName;
end;

function TPackageManager.IsPackageInstalled(const APackageName: string): Boolean;
var
  InstallPath: string;
begin
  InstallPath := GetPackageInstallPath(APackageName);
  Result := DirectoryExists(InstallPath);
end;

function TPackageManager.ValidatePackage(const APackageName: string): Boolean;
begin
  // Simple package name validation
  Result := (APackageName <> '') and (Pos(' ', APackageName) = 0) and (Pos('/', APackageName) = 0);
end;

function TPackageManager.GetPackageInfo(const APackageName: string): TPackageInfo;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
begin
  // Initialize package info
  Initialize(Result);
  Result.Name := APackageName;
  Result.Installed := IsPackageInstalled(APackageName);

  if Result.Installed then
  begin
    Result.InstallPath := GetPackageInstallPath(APackageName);
    // Try to read metadata
    MetaPath := IncludeTrailingPathDelimiter(Result.InstallPath) + 'package.json';
    if FileExists(MetaPath) then
    begin
      SL := TStringList.Create;
      try
        SL.LoadFromFile(MetaPath);
        J := GetJSON(SL.Text);
        try
          if J.JSONType=jtObject then
          begin
            O := TJSONObject(J);
            Result.Name := O.Get('name', APackageName);
            Result.Version := O.Get('version', '');
            Result.Description := O.Get('description', '');
            Result.Homepage := O.Get('homepage', '');
            Result.License := O.Get('license', '');
            Result.Repository := O.Get('repository', '');
            Result.SourcePath := O.Get('source_path', '');
          end;
        finally
          J.Free;
        end;
      finally
        SL.Free;
      end;
    end
    else
    begin
      Result.Version := '';
      Result.Description := 'Installed package';
    end;
  end;
end;

function TPackageManager.ParseLocalPackageIndex(const AIndexPath: string): TPackageArray;
var
  JSONData: TJSONData = nil;
  Arr: TJSONArray;
  Obj: TJSONObject;
  i, j, Count: Integer;
  Pkg: TPackageInfo;
  Names: TStringList;
  U: TJSONData;
  K: Integer;

  function TryGetArray(AData: TJSONData): TJSONArray;
  begin
    Result := nil;
    if AData = nil then Exit(nil);
    if AData.JSONType = jtArray then Exit(TJSONArray(AData));
    if (AData.JSONType = jtObject) and Assigned(TJSONObject(AData).Arrays['packages']) then
      Exit(TJSONObject(AData).Arrays['packages']);
  end;

  function HasValidURL(AObj: TJSONObject): Boolean;
  var
    UrlData: TJSONData;
  begin
    UrlData := AObj.Find('url');
    if not Assigned(UrlData) then Exit(False);
    if (UrlData.JSONType = jtString) and (AObj.Get('url', '') = '') then Exit(False);
    if (UrlData.JSONType = jtArray) and (TJSONArray(UrlData).Count = 0) then Exit(False);
    Result := True;
  end;

begin
  Initialize(Result);
  SetLength(Result, 0);

  if not FileExists(AIndexPath) then Exit;

  try
    with TStringList.Create do
    try
      LoadFromFile(AIndexPath);
      JSONData := GetJSON(Text);
    finally
      Free;
    end;

    Arr := TryGetArray(JSONData);
    if Arr = nil then Exit;

    // Filter invalid entries and deduplicate by name (keep highest version)
    Names := TStringList.Create;
    try
      Initialize(Pkg);
      Names.Sorted := True;
      Names.Duplicates := dupIgnore;
      Names.CaseSensitive := False;

      for i := 0 to Arr.Count - 1 do
      begin
        if (Arr.Items[i].JSONType <> jtObject) then Continue;
        Obj := TJSONObject(Arr.Items[i]);
        if Obj.Get('name', '') = '' then Continue;
        if Obj.Get('version', '') = '' then Continue;
        if not HasValidURL(Obj) then Continue;
        Names.Add(Obj.Get('name', ''));
      end;

      Count := 0;
      SetLength(Result, Names.Count);
      for i := 0 to Names.Count - 1 do
      begin
        Finalize(Pkg);
        Initialize(Pkg);
        for j := 0 to Arr.Count - 1 do
        begin
          if Arr.Items[j].JSONType <> jtObject then Continue;
          Obj := TJSONObject(Arr.Items[j]);
          if not SameText(Obj.Get('name', ''), Names[i]) then Continue;
          if Obj.Get('version', '') = '' then Continue;
          if not HasValidURL(Obj) then Continue;

          // Select highest version
          if (Pkg.Name = '') or IsVersionHigher(Obj.Get('version', ''), Pkg.Version) then
          begin
            Pkg.Name := Obj.Get('name', '');
            Pkg.Version := Obj.Get('version', '');
            Pkg.Description := Obj.Get('description', '');
            Pkg.Homepage := Obj.Get('homepage', '');
            Pkg.License := Obj.Get('license', '');
            Pkg.Repository := Obj.Get('repository', '');
            Pkg.Sha256 := Obj.Get('sha256', '');
            SetLength(Pkg.URLs, 0);
            U := Obj.Find('url');
            if Assigned(U) then
            begin
              if U.JSONType = jtString then
              begin
                SetLength(Pkg.URLs, 1);
                Pkg.URLs[0] := U.AsString;
              end
              else if U.JSONType = jtArray then
              begin
                SetLength(Pkg.URLs, TJSONArray(U).Count);
                for K := 0 to TJSONArray(U).Count - 1 do
                  Pkg.URLs[K] := TJSONArray(U).Items[K].AsString;
              end;
            end;
          end;
        end;
        if (Pkg.Name <> '') then
        begin
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
    finally
      Finalize(Pkg);
      Names.Free;
    end;
  finally
    if Assigned(JSONData) then JSONData.Free;
  end;
end;

function TPackageManager.GetAvailablePackages: TPackageArray;
var
  i, Count: Integer;
  Pkg: TPackageInfo;
  RepoPackages: SysUtils.TStringArray;
  RepoInfo: fpdev.resource.repo.TPackageInfo;
begin
  Initialize(Result);
  SetLength(Result, 0);

  // First try to get packages from fpdev-repo
  if Assigned(FResourceRepo) then
  begin
    RepoPackages := FResourceRepo.ListPackages('');
    if Length(RepoPackages) > 0 then
    begin
      SetLength(Result, Length(RepoPackages));
      Count := 0;
      for i := 0 to High(RepoPackages) do
      begin
        // Skip category entries (ending with / or PathDelim)
        if (Length(RepoPackages[i]) > 0) and
           ((RepoPackages[i][Length(RepoPackages[i])] = '/') or
            (RepoPackages[i][Length(RepoPackages[i])] = PathDelim)) then
          Continue;

        Initialize(Pkg);
        if FResourceRepo.GetPackageInfo(RepoPackages[i], '', RepoInfo) then
        begin
          Pkg.Name := RepoInfo.Name;
          Pkg.Version := RepoInfo.Version;
          Pkg.Description := RepoInfo.Description;
          Pkg.Installed := IsPackageInstalled(Pkg.Name);
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
      if Count > 0 then
        Exit;  // Found packages in fpdev-repo
    end;
  end;

  // Fallback to local index.json
  Result := ParseLocalPackageIndex(FPackageRegistry + PathDelim + 'index.json');
end;

function TPackageManager.GetInstalledPackages: TPackageArray;
var
  SearchRec: TSearchRec;
  Count: Integer;
begin
  Initialize(Result);
  SetLength(Result, 0);
  Count := 0;

  if FindFirst(FPackageRegistry + PathDelim + '*', faDirectory, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory <> 0) and
         (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        SetLength(Result, Count + 1);
        Result[Count] := GetPackageInfo(SearchRec.Name);
        Inc(Count);
      end;
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

function TPackageManager.DownloadPackage(const APackageName, AVersion: string): Boolean;
var
  Avail: TPackageArray;
  i, BestIdx: Integer;
  UseVersion, ZipPath, Err: string;
  Opt: TFetchOptions;
  URLs: array of string;

begin
  Result := False;
  URLs := nil;

  if (APackageName = '') then
    Exit;

  // Find package in available index
  Avail := GetAvailablePackages;
  BestIdx := -1;
  for i := 0 to High(Avail) do
  begin
    if SameText(Avail[i].Name, APackageName) then
    begin
      if (AVersion='') then
      begin
        if (BestIdx<0) or IsVersionHigher(Avail[i].Version, Avail[BestIdx].Version) then
          BestIdx := i;
      end
      else if SameText(Avail[i].Version, AVersion) then
        BestIdx := i;
    end;
  end;

  if BestIdx < 0 then
    Exit;  // Package not found in index

  UseVersion := Avail[BestIdx].Version;
  if Length(Avail[BestIdx].URLs) = 0 then
    Exit;  // No download URLs available

  // Construct cache path
  ZipPath := IncludeTrailingPathDelimiter(GetCacheDir) + 'packages' + PathDelim +
             APackageName + '-' + UseVersion + '.zip';
  EnsureDir(ExtractFileDir(ZipPath));

  // Prepare URLs array
  SetLength(URLs, Length(Avail[BestIdx].URLs));
  for i := 0 to High(URLs) do
    URLs[i] := Avail[BestIdx].URLs[i];

  // Setup fetch options
  Opt.DestDir := ExtractFileDir(ZipPath);
  Opt.Hash := Avail[BestIdx].Sha256;
  Opt.HashAlgorithm := haSHA256;
  Opt.HashDigest := Avail[BestIdx].Sha256;
  Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
  Opt.ExpectedSize := 0;

  // Download with mirror fallback and SHA256 verification
  Result := EnsureDownloadedCached(URLs, ZipPath, Opt, Err);
end;

function TPackageManager.BuildPackage(const ASourcePath: string): Boolean;
begin
  // Delegate to build service
  Result := FBuilder.BuildPackage(ASourcePath);
end;



function TPackageManager.InstallPackageFromSource(const APackageName, ASourcePath: string): Boolean;
var
  InstallPath: string;
  Info: TPackageInfo;
begin
  Result := False;

  try
    InstallPath := GetPackageInstallPath(APackageName);

    // Ensure the install directory exists
    if not DirectoryExists(InstallPath) then
      EnsureDir(InstallPath);

    // Copy source to the install directory (to be implemented as a recursive copy later; currently only records the source path)
    Info := GetPackageInfo(APackageName);
    Info.SourcePath := ASourcePath;

    if not BuildPackage(ASourcePath) then
    begin
      Exit;
    end;

    // Write metadata (supplement build tool information)
    Info := GetPackageInfo(APackageName);
    Info.SourcePath := ASourcePath;
    Info.Version := Info.Version; // Keep placeholder logic
    Info.Description := Info.Description;
    if not WritePackageMetadata(InstallPath, Info) then

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ResolveDependencies(const APackageName: string): TStringArray;
var
  Graph: fpdev.pkg.deps.TDependencyGraph;
  ResolveResult: TResolveResult;
  Avail: TPackageArray;
  Visited: TStringList;
  i: Integer;

  procedure BuildDependencyTree(const APkgName: string);
  var
    Idx, k: Integer;
    PkgInfo: TPackageInfo;
    DepName: string;
  begin
    // Avoid infinite recursion
    if Visited.IndexOf(APkgName) >= 0 then
      Exit;
    Visited.Add(APkgName);

    // Find package in available packages
    Idx := -1;
    for k := 0 to High(Avail) do
    begin
      if SameText(Avail[k].Name, APkgName) then
      begin
        Idx := k;
        Break;
      end;
    end;

    if Idx < 0 then
    begin
      // Try to get from installed packages
      PkgInfo := GetPackageInfo(APkgName);
      if PkgInfo.Name = '' then
        Exit;  // Package not found
      Graph.AddNode(APkgName, PkgInfo.Version);
      // Add dependencies from installed package
      for k := 0 to High(PkgInfo.Dependencies) do
      begin
        // Parse version constraint to extract package name
        DepName := ExtractPackageName(PkgInfo.Dependencies[k]);
        if DepName = '' then
          DepName := PkgInfo.Dependencies[k];  // Fallback to original if parsing fails
        Graph.AddDependency(APkgName, DepName);
        BuildDependencyTree(DepName);
      end;
    end
    else
    begin
      // Add node from available packages
      Graph.AddNode(APkgName, Avail[Idx].Version);
      // Add dependencies
      for k := 0 to High(Avail[Idx].Dependencies) do
      begin
        // Parse version constraint to extract package name
        DepName := ExtractPackageName(Avail[Idx].Dependencies[k]);
        if DepName = '' then
          DepName := Avail[Idx].Dependencies[k];  // Fallback to original if parsing fails
        Graph.AddDependency(APkgName, DepName);
        BuildDependencyTree(DepName);
      end;
    end;
  end;

begin
  Initialize(Result);
  SetLength(Result, 0);

  if APackageName = '' then
    Exit;

  // Get all available packages for dependency lookup
  Avail := GetAvailablePackages;

  Graph := fpdev.pkg.deps.TDependencyGraph.Create;
  Visited := TStringList.Create;
  try
    Visited.CaseSensitive := False;

    // Build dependency tree starting from root package
    BuildDependencyTree(APackageName);

    // Resolve dependencies with topological sort
    ResolveResult := Graph.Resolve;

    if ResolveResult.Success then
    begin
      // Copy resolved order to result (dependencies first, then dependents)
      SetLength(Result, Length(ResolveResult.ResolvedOrder));
      for i := 0 to High(ResolveResult.ResolvedOrder) do
        Result[i] := ResolveResult.ResolvedOrder[i];
    end
    else
    begin
      // On failure (e.g., cycle detected), return just the root package
      // and log the error
      if ResolveResult.HasCycle then
      begin
        // Cycle detected - falling back to root package only
      end;
      SetLength(Result, 1);
      Result[0] := APackageName;
    end;
  finally
    Visited.Free;
    Graph.Free;
  end;
end;

function TPackageManager.InstallPackage(
  const APackageName: string;
  const AVersion: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
var
  UseVersion: string;
  Avail: TPackageArray;
  i, BestIdx: Integer;
  ZipPath, TmpDir, Err: string;
  Opt: TFetchOptions;
  URLs: array of string;
  InstalledOK: Boolean;
  LO, LE: IOutput;

begin
  Result := False;
  URLs := nil;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if not ValidatePackage(APackageName) then
  begin
    Exit;
  end;

  if IsPackageInstalled(APackageName) then
  begin
    Exit(True);
  end;

  try
    // Select version from available index
    Avail := GetAvailablePackages;
    BestIdx := -1;
    for i := 0 to High(Avail) do
    begin
      if SameText(Avail[i].Name, APackageName) then
      begin
        if (AVersion='') then
        begin
          if (BestIdx<0) or IsVersionHigher(Avail[i].Version, Avail[BestIdx].Version) then
            BestIdx := i;
        end
        else if SameText(Avail[i].Version, AVersion) then
          BestIdx := i;
      end;
    end;

    if BestIdx < 0 then
    begin
      Exit;
    end;

    // Resolve dependencies before downloading
    if Length(Avail[BestIdx].Dependencies) > 0 then
    begin
      if Outp <> nil then
        Outp.WriteLn('Resolving dependencies...');
      if not ResolveAndInstallDependencies(Avail[BestIdx], Outp, Errp) then
      begin
        Exit;
      end;
    end;

    UseVersion := Avail[BestIdx].Version;

    if Length(Avail[BestIdx].URLs)=0 then
    begin
      Exit;
    end;

    // Download to cached ZIP
    ZipPath := IncludeTrailingPathDelimiter(GetCacheDir)
      + 'packages'
      + PathDelim
      + APackageName
      + '-'
      + UseVersion
      + '.zip';
    EnsureDir(ExtractFileDir(ZipPath));

    SetLength(URLs, Length(Avail[BestIdx].URLs));
    for i := 0 to High(URLs) do URLs[i] := Avail[BestIdx].URLs[i];

    Opt.DestDir := ExtractFileDir(ZipPath);
    Opt.Hash := Avail[BestIdx].Sha256;
    Opt.HashAlgorithm := haSHA256;
    Opt.HashDigest := Avail[BestIdx].Sha256;
    Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
    Opt.ExpectedSize := 0;

    if not EnsureDownloadedCached(URLs, ZipPath, Opt, Err) then
    begin
      Exit;
    end;

    // Extract to temporary directory
    TmpDir := IncludeTrailingPathDelimiter(GetSandboxDir) + 'pkg-' + APackageName + '-' + UseVersion;
    if DirectoryExists(TmpDir) then
      ; // Consider cleanup

    if not ZipExtract(ZipPath, TmpDir, Err) then
    begin
      // Extract failed, error message is in Err
      Exit;
    end;

    // Compile and install
    InstalledOK := InstallPackageFromSource(APackageName, TmpDir);
    if not InstalledOK then
    begin
      Exit(False);
    end
    else
    begin
      // Install succeeded, clean up temp directory if configured
      if not FBuilder.KeepArtifacts then
      begin
        if DirectoryExists(TmpDir) then
        begin
          try
            if not DeleteDirRecursive(TmpDir) then
            begin
              LE.WriteLn(_(MSG_WARNING) + ': ' + _Fmt(MSG_PKG_CLEAN_TMP_FAILED, [TmpDir]));
            end;
          except
            on E: Exception do
          end;
        end;
      end
      else
    end;

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.UninstallPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if not IsPackageInstalled(APackageName) then
  begin
    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_NOT_INSTALLED, [APackageName]));
    Result := True;
    Exit;
  end;

  try
    InstallPath := GetPackageInstallPath(APackageName);

    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_UNINSTALLING, [APackageName]));

    // Delete install directory
    if DirectoryExists(InstallPath) then
    begin
      if not DeleteDirRecursive(InstallPath) then
      begin
        if Errp <> nil then Errp.WriteLn(_Fmt(MSG_PKG_REMOVE_WARNING, [InstallPath]));
      end;
    end;

    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_UNINSTALL_COMPLETE, [APackageName]));
    Result := True;

  except
    on E: Exception do
    begin
      if Errp <> nil then Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_UNINSTALL_FAILED, [E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageManager.UpdatePackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstalledInfo: TPackageInfo;
  Avail: TPackageArray;
  i, BestIdx: Integer;
  InstalledVersion, LatestVersion: string;
  LO, LE: IOutput;

begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Validate package name
  if not ValidatePackage(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_INVALID_NAME, [APackageName]));
    Exit;
  end;

  // Check if package is installed
  if not IsPackageInstalled(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APackageName]));
    LE.WriteLn(_Fmt(MSG_PKG_INSTALL_HINT, [APackageName]));
    Exit;
  end;

  // Get installed package info
  InstalledInfo := GetPackageInfo(APackageName);
  InstalledVersion := InstalledInfo.Version;
  if InstalledVersion = '' then
    InstalledVersion := '0.0.0';

  LO.WriteLn(_Fmt(MSG_PKG_CHECKING_UPDATES, [APackageName]));
  LO.WriteLn(_Fmt(MSG_PKG_INSTALLED_VERSION, [InstalledVersion]));

  // Get available packages from index
  Avail := GetAvailablePackages;
  BestIdx := -1;

  // Find the latest version in available packages
  for i := 0 to High(Avail) do
  begin
    if SameText(Avail[i].Name, APackageName) then
    begin
      if (BestIdx < 0) or IsVersionHigher(Avail[i].Version, Avail[BestIdx].Version) then
        BestIdx := i;
    end;
  end;

  if BestIdx < 0 then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_IN_INDEX, [APackageName]));
    LE.WriteLn(_(MSG_PKG_REPO_UPDATE_HINT));
    Exit;
  end;

  LatestVersion := Avail[BestIdx].Version;
  LO.WriteLn(_Fmt(MSG_PKG_LATEST_VERSION, [LatestVersion]));

  // Check if update is needed
  if not IsVersionHigher(LatestVersion, InstalledVersion) then
  begin
    LO.WriteLn(_Fmt(MSG_PKG_UP_TO_DATE, [APackageName]));
    Result := True;
    Exit;
  end;

  // Perform update: uninstall old, install new
  LO.WriteLn(_Fmt(MSG_PKG_UPDATING, [APackageName, InstalledVersion, LatestVersion]));

  // Uninstall old version
  LO.WriteLn(_(MSG_PKG_REMOVING_OLD));
  if not UninstallPackage(APackageName, nil, LE) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_UNINSTALL_OLD_FAILED));
    Exit;
  end;

  // Install new version
  LO.WriteLn(_(MSG_PKG_INSTALLING_NEW));
  if not InstallPackage(APackageName, LatestVersion, nil, LE) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_INSTALL_NEW_FAILED));
    LE.WriteLn(_(MSG_PKG_REINSTALL_HINT));
    Exit;
  end;

  LO.WriteLn(_Fmt(MSG_PKG_UPDATE_SUCCESS, [APackageName, LatestVersion]));
  Result := True;
end;

function TPackageManager.ListPackages(const AShowAll: Boolean; Outp: IOutput): Boolean;
var
  Packages: TPackageArray;
  i: Integer;
  Line: string;
  LO: IOutput;
begin
  Result := True;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    if AShowAll then
      Packages := GetAvailablePackages
    else
      Packages := GetInstalledPackages;

    if AShowAll then
      LO.WriteLn('Available packages:')
    else
      LO.WriteLn('Installed packages:');

    if Length(Packages) = 0 then
    begin
      if AShowAll then
        LO.WriteLn('  No packages available in index')
      else
        LO.WriteLn('  No packages installed');
    end
    else
    begin
      for i := 0 to High(Packages) do
      begin
        Line := Format('  %-16s  %-10s  %s',
                [Packages[i].Name, Packages[i].Version, Packages[i].Description]);
        LO.WriteLn(Line);
      end;
    end;


  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.SearchPackages(const AQuery: string; Outp: IOutput): Boolean;
var
  Packages: TPackageArray;
  i, Matches: Integer;
  Q: string;
  Line: string;
  LO: IOutput;
  StatusStr: string;
begin
  Result := True;
  Matches := 0;
  Q := LowerCase(Trim(AQuery));
  if Q = '' then
  begin
    Exit(False);
  end;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    // Search in all available packages (including remote index)
    Packages := GetAvailablePackages;


    for i := 0 to High(Packages) do
    begin
      if (Pos(Q, LowerCase(Packages[i].Name)) > 0) or
         (Pos(Q, LowerCase(Packages[i].Description)) > 0) then
      begin
        Inc(Matches);
        if Packages[i].Installed then
          StatusStr := 'Installed'
        else
          StatusStr := 'Available';
        Line := Format('%-16s  %-10s  %-10s  %s',
                [Packages[i].Name, Packages[i].Version, StatusStr, Packages[i].Description]);
        LO.WriteLn(Line);
      end;
    end;

    if Matches = 0 then
      LO.WriteLn('No packages found matching: ' + AQuery);


  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ShowPackageInfo(const APackageName: string; Outp: IOutput): Boolean;
var
  PackageInfo: TPackageInfo;
  LO: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  try
    PackageInfo := GetPackageInfo(APackageName);

    LO.WriteLn(_Fmt(MSG_PKG_INFO_NAME, [PackageInfo.Name]));
    LO.WriteLn(_Fmt(MSG_PKG_INFO_VERSION, [PackageInfo.Version]));
    LO.WriteLn(_Fmt(MSG_PKG_INFO_DESC, [PackageInfo.Description]));

    if PackageInfo.Installed then
      LO.WriteLn(_Fmt(MSG_PKG_INFO_PATH, [PackageInfo.InstallPath]));

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.ShowPackageDependencies(const APackageName: string): Boolean;
var
  Dependencies: TStringArray;
  i: Integer;
begin
  Result := False;

  try
    Dependencies := ResolveDependencies(APackageName);


    if Length(Dependencies) = 0 then
    else
    begin
      for i := 0 to High(Dependencies) do
    end;

    Result := True;

  except
    on E: Exception do
      Result := False;
  end;
end;

function TPackageManager.VerifyPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath, MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  ExpectedSha256, ActualSha256: string;
  FilePath: string;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Check if package is installed
  if not IsPackageInstalled(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APackageName]));
    Exit;
  end;

  InstallPath := GetPackageInstallPath(APackageName);
  MetaPath := IncludeTrailingPathDelimiter(InstallPath) + 'package.json';

  // Check if metadata exists
  if not FileExists(MetaPath) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_NOT_FOUND, [MetaPath]));
    Exit;
  end;

  // Validate metadata JSON
  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
    except
      on E: Exception do
      begin
        LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_INVALID, [E.Message]));
        Exit;
      end;
    end;

    try
      if J.JSONType <> jtObject then
      begin
        LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_META_NOT_JSON));
        Exit;
      end;

      O := TJSONObject(J);

      // Verify required fields
      if O.Get('name', '') = '' then
      begin
        LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_NAME_MISSING));
        Exit;
      end;

      if O.Get('version', '') = '' then
      begin
        LO.WriteLn(_(MSG_PKG_VERSION_MISSING));
      end;

      // Verify SHA256 if present
      ExpectedSha256 := O.Get('sha256', '');
      if ExpectedSha256 <> '' then
      begin
        FilePath := O.Get('source_path', '');
        if (FilePath <> '') and FileExists(FilePath) then
        begin
          ActualSha256 := SHA256FileHex(FilePath);
          if not SameText(ExpectedSha256, ActualSha256) then
          begin
            LE.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_CHECKSUM_MISMATCH));
            LE.WriteLn(_Fmt(MSG_PKG_CHECKSUM_EXPECTED, [ExpectedSha256]));
            LE.WriteLn(_Fmt(MSG_PKG_CHECKSUM_ACTUAL, [ActualSha256]));
            Exit;
          end;
          LO.WriteLn(_(MSG_PKG_CHECKSUM_OK));
        end;
      end;

      LO.WriteLn(_Fmt(MSG_PKG_VERIFY_SUCCESS, [APackageName]));
      Result := True;

    finally
      J.Free;
    end;
  finally
    SL.Free;
  end;
end;

function TPackageManager.WritePackageMetadata(const AInstallPath: string; const Info: TPackageInfo): Boolean;
var
  MetaPath: string;
  O: TJSONObject;
  SL: TStringList;
  i: Integer;
begin
  Result := False;
  try
    MetaPath := IncludeTrailingPathDelimiter(AInstallPath) + 'package.json';
    O := TJSONObject.Create;
    try
      O.Add('name', Info.Name);
      O.Add('version', Info.Version);
      O.Add('description', Info.Description);
      O.Add('homepage', Info.Homepage);
      O.Add('license', Info.License);
      O.Add('repository', Info.Repository);
      O.Add('install_path', AInstallPath);
      O.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
      O.Add('source_path', Info.SourcePath);
      if FBuilder.LastBuildTool<>'' then O.Add('build_tool', FBuilder.LastBuildTool);
      if FBuilder.LastBuildLog<>'' then O.Add('build_log', FBuilder.LastBuildLog);
      if Length(Info.URLs)>0 then
      begin
        begin
          // FPC doesn't support local var inline declaration, use temp variable
          // Note: Array creation in nested begin..end block
          // Changed to construct array then add directly
          // To avoid lifecycle issues, construct to temp var then add to object
          // But JSON object takes ownership of lifecycle, manual free may cause double-free
          // Solution: construct first, don't free after O.Add (owned by O); no finally free needed
          // Compatible pattern: construct first, don't manually Free after O.Add
          // Construction note: FPC has no anonymous block local vars, declare at upper level
          // (simplified: add items directly to new array and let O own it)
          // Since inconvenient to introduce upper-level variables,
          // use direct string array serialization (to be improved)
          // Simplified: don't use local variables, create array and attach directly
          // create array
          O.Add('url', TJSONArray.Create);
          for i := 0 to High(Info.URLs) do
            TJSONArray(O.Arrays['url']).Add(Info.URLs[i]);
        end;
      end;
      if Info.Sha256<>'' then O.Add('sha256', Info.Sha256);

      SL := TStringList.Create;
      try
        SL.Text := O.FormatJSON;
        EnsureDir(AInstallPath);
        SL.SaveToFile(MetaPath);
        Result := True;
      finally
        SL.Free;
      end;
    finally
      O.Free;
    end;
  except
    on E: Exception do
      Result := False;
  end;
end;






function TPackageManager.AddRepository(const AName, AURL: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.AddRepository(AName, AURL, Outp, Errp);
end;

function TPackageManager.RemoveRepository(const AName: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.RemoveRepository(AName, Outp, Errp);
end;

function TPackageManager.UpdateRepositories(Outp: IOutput; Errp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.UpdateRepositories(Outp, Errp);
end;

function TPackageManager.ListRepositories(Outp: IOutput): Boolean;
begin
  // Delegate to repository service
  Result := FRepoService.ListRepositories(Outp);
end;

function TPackageManager.InstallFromLocal(const APackagePath: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  PackageName: string;
begin
  Result := False;

  if not DirectoryExists(APackagePath) then
  begin
    if Errp <> nil then Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_PATH_NOT_FOUND, [APackagePath]));
    Exit;
  end;

  try
    // Extract package name from path
    PackageName := ExtractFileName(APackagePath);
    if PackageName = '' then
      PackageName := 'local_package';

    if Outp <> nil then Outp.WriteLn(_Fmt(MSG_PKG_INSTALL_LOCAL, [APackagePath]));
    Result := InstallPackageFromSource(PackageName, APackagePath);
    if Result and (Outp <> nil) then Outp.WriteLn(_Fmt(MSG_PKG_INSTALL_COMPLETE, [PackageName]));

  except
    on E: Exception do
    begin
      if Errp <> nil then Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_EXCEPTION, ['install-local', E.Message]));
      Result := False;
    end;
  end;
end;

function TPackageManager.CreatePackage(const APackageName, APath: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  PackageDir, MetaPath, SourceDir: string;
  O: TJSONObject;
  SL: TStringList;
  LO: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  // Validate package name
  if not ValidatePackage(APackageName) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_INVALID_NAME, [APackageName]));
    Exit;
  end;

  // Determine source directory
  if APath = '' then
    SourceDir := GetCurrentDir
  else
    SourceDir := ExpandFileName(APath);

  if not DirectoryExists(SourceDir) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_SOURCE_NOT_FOUND, [SourceDir]));
    Exit;
  end;

  // Create package directory structure
  PackageDir := SourceDir;
  MetaPath := IncludeTrailingPathDelimiter(PackageDir) + 'package.json';

  // Create package.json if it doesn't exist
  if not FileExists(MetaPath) then
  begin
    O := TJSONObject.Create;
    try
      O.Add('name', APackageName);
      O.Add('version', '1.0.0');
      O.Add('description', 'A FreePascal package');
      O.Add('author', '');
      O.Add('license', 'MIT');
      O.Add('homepage', '');
      O.Add('repository', '');
      O.Add('dependencies', TJSONArray.Create);
      O.Add('keywords', TJSONArray.Create);

      SL := TStringList.Create;
      try
        SL.Text := O.FormatJSON;
        SL.SaveToFile(MetaPath);
        LO.WriteLn(_Fmt(MSG_PKG_CREATED_JSON, [MetaPath]));
      finally
        SL.Free;
      end;
    finally
      O.Free;
    end;
  end
  else
  begin
    LO.WriteLn(_Fmt(MSG_PKG_JSON_EXISTS, [MetaPath]));
  end;

  LO.WriteLn(_Fmt(MSG_PKG_CREATE_SUCCESS, [APackageName]));
  LO.WriteLn('');
  LO.WriteLn(_(MSG_PKG_NEXT_STEPS));
  LO.WriteLn(_(MSG_PKG_STEP_EDIT));
  LO.WriteLn(_(MSG_PKG_STEP_ADD_SOURCE));
  LO.WriteLn(_Fmt(MSG_PKG_STEP_PUBLISH, [APackageName]));

  Result := True;
end;

function TPackageManager.PublishPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
var
  InstallPath, MetaPath, ArchivePath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  Version, ArchiveName: string;
  Archiver: TPackageArchiver;
  LO, LE: IOutput;
begin
  Result := False;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  // Check if package is installed/created
  if not IsPackageInstalled(APackageName) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_FOUND, [APackageName]));
    Exit;
  end;

  InstallPath := GetPackageInstallPath(APackageName);
  MetaPath := IncludeTrailingPathDelimiter(InstallPath) + 'package.json';

  // Check if metadata exists
  if not FileExists(MetaPath) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_NOT_FOUND, ['Run "fpdev package create" first']));
    Exit;
  end;

  // Read version from metadata
  Version := '1.0.0';
  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
      if J.JSONType = jtObject then
      begin
        O := TJSONObject(J);
        Version := O.Get('version', '1.0.0');
      end;
      J.Free;
    except
      // Use default version
    end;
  finally
    SL.Free;
  end;

  // Create archive name
  ArchiveName := APackageName + '-' + Version + '.tar.gz';
  ArchivePath := IncludeTrailingPathDelimiter(FInstallRoot) + 'publish' + PathDelim + ArchiveName;

  // Ensure publish directory exists
  if not DirectoryExists(ExtractFileDir(ArchivePath)) then
    EnsureDir(ExtractFileDir(ArchivePath));

  LO.WriteLn(_Fmt(MSG_PKG_CREATING_ARCHIVE, [ArchiveName]));

  // Create tar.gz archive using TPackageArchiver
  Archiver := TPackageArchiver.Create(InstallPath);
  try
    if not Archiver.CreateArchive(ArchivePath) then
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_ARCHIVE_FAILED, [Archiver.GetLastError]));
      Exit;
    end;

    // Display archive info with SHA256 checksum
    LO.WriteLn(_Fmt(MSG_PKG_ARCHIVE_CREATED, [ArchivePath]));
    LO.WriteLn('SHA256: ' + Archiver.GetChecksum);
    LO.WriteLn('');
    LO.WriteLn(_Fmt(MSG_PKG_READY_PUBLISH, [APackageName, Version]));
    LO.WriteLn('');
    LO.WriteLn(_(MSG_PKG_TO_PUBLISH));
    LO.WriteLn(_(MSG_PKG_PUBLISH_STEP1));
    LO.WriteLn(_(MSG_PKG_PUBLISH_STEP2));

    Result := True;
  finally
    Archiver.Free;
  end;
end;


function TPackageManager.GetAvailablePackageList: TPackageArray;
begin
  Result := GetAvailablePackages;
end;

function TPackageManager.GetInstalledPackageList: TPackageArray;
begin
  Result := GetInstalledPackages;
end;

{ Semantic Version Functions Implementation }

function ParseSemanticVersion(const AVersion: string): TSemanticVersion;
var
  Parsed: TPackageSemanticVersion;
begin
  Parsed := ParsePackageSemanticVersion(AVersion);
  Result.Valid := Parsed.Valid;
  Result.Major := Parsed.Major;
  Result.Minor := Parsed.Minor;
  Result.Patch := Parsed.Patch;
  Result.PreRelease := Parsed.PreRelease;
end;

function CompareVersions(const AVersion1, AVersion2: string): Integer;
begin
  Result := ComparePackageVersions(AVersion1, AVersion2);
end;

function VersionSatisfiesConstraint(const AVersion, AConstraint: string): Boolean;
begin
  Result := PackageVersionSatisfiesConstraint(AVersion, AConstraint);
end;

{ Dependency Graph Functions }

function BuildDependencyGraph(const ARootPackage: string; const APackages: TPackageArray): TDependencyNodeArray;
var
  PackageDescriptors: TPackageDepDescriptorArray;
  i, j: Integer;
begin
  PackageDescriptors := nil;
  SetLength(PackageDescriptors, Length(APackages));
  for i := 0 to High(APackages) do
  begin
    PackageDescriptors[i].Name := APackages[i].Name;
    PackageDescriptors[i].Version := APackages[i].Version;
    SetLength(PackageDescriptors[i].Dependencies, Length(APackages[i].Dependencies));
    for j := 0 to High(APackages[i].Dependencies) do
      PackageDescriptors[i].Dependencies[j] := APackages[i].Dependencies[j];
  end;

  Result := BuildPackageDependencyGraph(ARootPackage, PackageDescriptors);
end;

function TopologicalSortDependencies(const AGraph: TDependencyNodeArray): TStringArray;
begin
  Result := TopologicalSortPackageDependencies(AGraph);
end;

{ Package Verification Functions Implementation }

function VerifyInstalledPackage(const TestDir: string): TPackageVerificationResult;
var
  VerifyResult: TPackageVerifyResult;
  i: Integer;
begin
  VerifyResult := VerifyInstalledPackageCore(TestDir);

  case VerifyResult.Status of
    pvsValid:
      Result.Status := vsValid;
    pvsMissingFiles:
      Result.Status := vsMissingFiles;
    pvsMetadataError:
      Result.Status := vsMetadataError;
  else
    Result.Status := vsInvalid;
  end;

  Result.PackageName := VerifyResult.PackageName;
  Result.Version := VerifyResult.Version;
  SetLength(Result.MissingFiles, Length(VerifyResult.MissingFiles));
  for i := 0 to High(VerifyResult.MissingFiles) do
    Result.MissingFiles[i] := VerifyResult.MissingFiles[i];
end;

function VerifyPackageChecksum(const FilePath, Hash: string): Boolean;
begin
  Result := VerifyPackageChecksumCore(FilePath, Hash);
end;

{ Package Creation Functions Implementation }

function IsBuildArtifact(const FileName: string): Boolean;
begin
  Result := IsBuildArtifactCore(FileName);
end;

function CollectPackageSourceFiles(const SourceDir: string; const ExcludePatterns: TStringArray): TStringArray;
begin
  Result := CollectPackageSourceFilesCore(SourceDir, ExcludePatterns);
end;

function GeneratePackageMetadataJson(const Options: TPackageCreationOptions): string;
var
  CreateOptions: TPackageCreateOptions;
  i: Integer;
begin
  CreateOptions.Name := Options.Name;
  CreateOptions.Version := Options.Version;
  CreateOptions.SourcePath := Options.SourcePath;
  SetLength(CreateOptions.ExcludePatterns, Length(Options.ExcludePatterns));
  for i := 0 to High(Options.ExcludePatterns) do
    CreateOptions.ExcludePatterns[i] := Options.ExcludePatterns[i];

  Result := GeneratePackageMetadataJsonCore(CreateOptions);
end;

function CreatePackageZipArchive(
  const SourceDir: string;
  const {%H-} Files: TStringArray;
  const OutputPath: string;
  var Err: string
): Boolean;
begin
  Result := CreatePackageZipArchiveCore(SourceDir, Files, OutputPath, Err);
end;

{ Package Validation Functions Implementation }

function ValidatePackageSourcePath(const SourcePath: string): Boolean;
begin
  Result := ValidatePackageSourcePathCore(SourcePath);
end;

function ValidatePackageMetadata(const MetadataPath: string): Boolean;
begin
  Result := ValidatePackageMetadataCore(MetadataPath);
end;

function CheckPackageRequiredFiles(const PackageDir: string): TStringArray;
begin
  Result := CheckPackageRequiredFilesCore(PackageDir);
end;

end.
